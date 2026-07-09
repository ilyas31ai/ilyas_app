import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/invitation_model.dart';
import '../models/user_model.dart';

class InvitationService {
  static final _db = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  // Jeu de caractères sans ambiguité (pas de 0/O, 1/I/L)
  static const _chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  static const _codeLength = 8;

  static String _generateCode() {
    final rng = Random.secure();
    return List.generate(
      _codeLength,
      (_) => _chars[rng.nextInt(_chars.length)],
    ).join();
  }

  /// Génère un code unique et le stocke dans Firestore.
  /// Appelé par le directeur depuis [DirectionInviterEnseignantPage].
  static Future<TeacherInvitation> genererInvitation({
    required String teacherUid,
    required String teacherEmail,
    required String teacherName,
    int validityDays = 7,
  }) async {
    final director = _auth.currentUser;
    if (director == null) throw Exception('Session expirée, reconnectez-vous.');
    final dirDoc = await _db.collection('users').doc(director.uid).get();
    final dirData = dirDoc.data() ?? {};
    final schoolId = dirData['schoolId'] as String? ?? director.uid;

    String schoolNom = '';
    try {
      final schoolDoc = await _db.collection('schools').doc(schoolId).get();
      schoolNom = (schoolDoc.data()?['nom'] as String?) ?? '';
    } catch (_) {}

    // Génère un code unique (collision très improbable, boucle de sécurité)
    String code;
    bool isUnique = false;
    do {
      code = _generateCode();
      final existing = await _db
          .collection('teacher_invitations')
          .where('code', isEqualTo: code)
          .where('used', isEqualTo: false)
          .where('revoked', isEqualTo: false)
          .get();
      isUnique = existing.docs.isEmpty;
    } while (!isUnique);

    final expiresAt = DateTime.now().add(Duration(days: validityDays));
    final docRef = _db.collection('teacher_invitations').doc();

    final invitation = TeacherInvitation(
      id: docRef.id,
      code: code,
      schoolId: schoolId,
      schoolNom: schoolNom,
      directorUid: director.uid,
      teacherUid: teacherUid,
      teacherEmail: teacherEmail,
      teacherName: teacherName,
      expiresAt: expiresAt,
      createdAt: DateTime.now(),
    );

    await docRef.set(invitation.toMap());
    return invitation;
  }

  /// L'enseignant saisit son code. Le système vérifie et active le compte.
  ///
  /// Deux systèmes de code coexistent et sont acceptés ici :
  /// 1. Code nominatif (`teacher_invitations`) généré depuis l'onglet
  ///    "Rechercher" de [DirectionInviterEnseignantPage] pour un enseignant
  ///    déjà inscrit (teacherStatus = 'limited').
  /// 2. Code générique de l'établissement (`schools/{id}.codeInvitation`),
  ///    celui affiché en évidence sur le tableau de bord Direction et déjà
  ///    utilisé par les élèves pour rejoindre une école. C'est le code que
  ///    la Direction copie/partage naturellement — il doit donc aussi
  ///    fonctionner pour un enseignant.
  static Future<void> utiliserCode(String code) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Session expirée, reconnectez-vous.');
    final trimmed = code.trim().toUpperCase();
    if (trimmed.isEmpty) {
      throw Exception('Code invalide ou déjà utilisé.');
    }

    final query = await _db
        .collection('teacher_invitations')
        .where('code', isEqualTo: trimmed)
        .where('used', isEqualTo: false)
        .where('revoked', isEqualTo: false)
        .get();

    if (query.docs.isNotEmpty) {
      final doc = query.docs.first;
      final inv = TeacherInvitation.fromDoc(doc);

      if (inv.isExpired) {
        throw Exception(
          'Ce code a expiré le ${_formatDate(inv.expiresAt)}.',
        );
      }

      // Si le code est nominatif, vérifier que c'est bien ce professeur
      if (inv.teacherUid.isNotEmpty && inv.teacherUid != user.uid) {
        throw Exception("Ce code n'est pas destiné à votre compte.");
      }

      final batch = _db.batch();

      batch.update(doc.reference, {
        'used': true,
        'usedAt': FieldValue.serverTimestamp(),
        'teacherUid': user.uid,
      });

      batch.update(_db.collection('users').doc(user.uid), {
        'teacherStatus': 'active',
        'linkedSchoolNom': inv.schoolNom,
        'schoolId': inv.schoolId,
        'statut': 'actif',
      });

      await batch.commit();
      return;
    }

    // Repli : code générique de l'établissement (mêmes codes que les élèves).
    final schoolSnap = await _db
        .collection('schools')
        .where('codeInvitation', isEqualTo: trimmed)
        .where('statut', isEqualTo: 'actif')
        .limit(1)
        .get();

    if (schoolSnap.docs.isEmpty) {
      throw Exception('Code invalide ou déjà utilisé.');
    }

    final schoolDoc = schoolSnap.docs.first;
    final schoolNom = (schoolDoc.data()['nom'] as String?) ?? '';

    await _db.collection('users').doc(user.uid).update({
      'teacherStatus': 'active',
      'linkedSchoolNom': schoolNom,
      'schoolId': schoolDoc.id,
      'statut': 'actif',
    });
  }

  /// Révoque une invitation non encore utilisée.
  static Future<void> revoquerInvitation(String invitationId) async {
    await _db.collection('teacher_invitations').doc(invitationId).update({
      'revoked': true,
      'revokedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Stream des invitations émises par l'école du directeur courant.
  static Stream<List<TeacherInvitation>> invitationsEcoleStream(
      String schoolId) {
    return _db
        .collection('teacher_invitations')
        .where('schoolId', isEqualTo: schoolId)
        .snapshots()
        .map((q) {
      final list = q.docs.map(TeacherInvitation.fromDoc).toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  /// Enseignants non rattachés (teacherStatus == 'limited').
  static Stream<List<UserModel>> enseignantsSansEcoleStream() {
    return _db
        .collection('users')
        .where('role', isEqualTo: 'professeur')
        .where('teacherStatus', isEqualTo: 'limited')
        .snapshots()
        .map((q) {
      final list = q.docs.map(UserModel.fromDoc).toList();
      list.sort((a, b) => a.displayName.compareTo(b.displayName));
      return list;
    });
  }

  /// Migration des enseignants existants vers le nouveau système.
  /// - en_attente + professeur  → actif + teacherStatus: limited
  /// - actif + professeur + pas de teacherStatus → teacherStatus: active
  static Future<void> migrerEnseignantsExistants() async {
    final batch = _db.batch();

    // Anciens "en attente" → limité
    final pending = await _db
        .collection('users')
        .where('role', isEqualTo: 'professeur')
        .where('statut', isEqualTo: 'en_attente')
        .get();
    for (final doc in pending.docs) {
      batch.update(doc.reference, {
        'statut': 'actif',
        'teacherStatus': 'limited',
      });
    }

    // Actifs sans teacherStatus → marqués actifs (rétrocompatibilité)
    final active = await _db
        .collection('users')
        .where('role', isEqualTo: 'professeur')
        .where('statut', isEqualTo: 'actif')
        .get();
    for (final doc in active.docs) {
      final data = doc.data();
      if (data['teacherStatus'] == null) {
        batch.update(doc.reference, {'teacherStatus': 'active'});
      }
    }

    await batch.commit();
  }

  static String _formatDate(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}/'
      '${dt.month.toString().padLeft(2, '0')}/'
      '${dt.year}';
}
