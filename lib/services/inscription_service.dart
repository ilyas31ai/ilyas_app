import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/inscription_model.dart';
import '../models/school_model.dart';

/// Gère les dossiers d'inscription scolaire pour l'Espace Direction :
/// brouillons issus de l'import PDF, vérification, création
/// élève/parent(s)/matricule, décisions et recherche.
class InscriptionService {
  static final _db = FirebaseFirestore.instance;

  static String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  static CollectionReference<Map<String, dynamic>> get _inscriptions =>
      _db.collection('inscriptions');
  static CollectionReference<Map<String, dynamic>> get _eleves =>
      _db.collection('eleves');
  static CollectionReference<Map<String, dynamic>> get _parents =>
      _db.collection('parents');

  static const _statutsFinalises = [
    'en_attente',
    'validee',
    'refusee',
  ];

  // ── Import PDF → brouillon ────────────────────────────────────────────────

  static Future<String> createDraft({
    required String pdfUrl,
    required String pdfName,
    required EleveInfo eleve,
    required ParentInfo parent1,
    ParentInfo? parent2,
    required ContactUrgence urgence,
  }) async {
    final doc = await _inscriptions.add({
      'schoolId': kDefaultSchoolId,
      'pdfUrl': pdfUrl,
      'pdfName': pdfName,
      'eleve': eleve.toMap(),
      'parent1': parent1.toMap(),
      if (parent2 != null && !parent2.isEmpty) 'parent2': parent2.toMap(),
      'urgence': urgence.toMap(),
      'matricule': '',
      'statut': InscriptionStatut.brouillon.value,
      'commentaire': '',
      'dateImport': FieldValue.serverTimestamp(),
      'createdBy': _uid,
    });
    return doc.id;
  }

  /// Historique de tous les PDF importés, du plus récent au plus ancien.
  static Stream<List<Inscription>> historyStream({int limit = 30}) {
    return _inscriptions
        .orderBy('dateImport', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs.map(Inscription.fromFirestore).toList());
  }

  // ── Vérification manuelle ─────────────────────────────────────────────────

  /// Brouillons en attente de vérification (aucun élève créé pour l'instant).
  static Stream<List<Inscription>> draftsStream() {
    return _inscriptions
        .where('statut', isEqualTo: InscriptionStatut.brouillon.value)
        .snapshots()
        .map((snap) {
      final list = snap.docs.map(Inscription.fromFirestore).toList();
      list.sort((a, b) => b.dateImport.compareTo(a.dateImport));
      return list;
    });
  }

  static Future<void> updateDraft(
    String id, {
    required EleveInfo eleve,
    required ParentInfo parent1,
    ParentInfo? parent2,
    required ContactUrgence urgence,
  }) async {
    await _inscriptions.doc(id).update({
      'eleve': eleve.toMap(),
      'parent1': parent1.toMap(),
      'parent2': (parent2 != null && !parent2.isEmpty)
          ? parent2.toMap()
          : FieldValue.delete(),
      'urgence': urgence.toMap(),
    });
  }

  /// Annule l'import : aucun élève n'ayant été créé, on supprime le brouillon.
  static Future<void> cancelDraft(String id) async {
    await _inscriptions.doc(id).delete();
  }

  static Future<String> _generateMatricule() {
    final year = DateTime.now().year;
    final counterRef = _db.collection('compteurs').doc('matricule_$year');
    return _db.runTransaction<String>((tx) async {
      final snap = await tx.get(counterRef);
      final current = (snap.data()?['valeur'] as num?)?.toInt() ?? 0;
      final next = current + 1;
      tx.set(counterRef, {'valeur': next}, SetOptions(merge: true));
      return 'MAT-$year-${next.toString().padLeft(4, '0')}';
    });
  }

  /// Confirme les données vérifiées : crée automatiquement l'élève, le ou les
  /// parents, la relation parent ↔ élève, le matricule unique et la date
  /// d'inscription. Le dossier passe alors au statut "en attente" de décision.
  static Future<void> confirmInscription(Inscription draft) async {
    final matricule = await _generateMatricule();
    final now = DateTime.now();
    final batch = _db.batch();

    final eleveRef = _eleves.doc();
    final parentIds = <String>[];

    final p1Ref = _parents.doc();
    parentIds.add(p1Ref.id);
    batch.set(p1Ref, {
      'schoolId': draft.schoolId,
      ...draft.parent1.toMap(),
      'enfantIds': [eleveRef.id],
      'createdAt': FieldValue.serverTimestamp(),
    });

    if (draft.parent2 != null && !draft.parent2!.isEmpty) {
      final p2Ref = _parents.doc();
      parentIds.add(p2Ref.id);
      batch.set(p2Ref, {
        'schoolId': draft.schoolId,
        ...draft.parent2!.toMap(),
        'enfantIds': [eleveRef.id],
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    batch.set(eleveRef, {
      'schoolId': draft.schoolId,
      'matricule': matricule,
      ...draft.eleve.toMap(),
      'classe': draft.eleve.classeDemandee,
      if (draft.eleve.emailEleve.isNotEmpty) 'email': draft.eleve.emailEleve,
      'parentIds': parentIds,
      'urgence': draft.urgence.toMap(),
      'dateInscription': Timestamp.fromDate(now),
      'statutInscription': InscriptionStatut.enAttente.value,
      'inscriptionId': draft.id,
    });

    batch.update(_inscriptions.doc(draft.id), {
      'matricule': matricule,
      'statut': InscriptionStatut.enAttente.value,
      'dateInscription': Timestamp.fromDate(now),
      'eleveId': eleveRef.id,
    });

    await batch.commit();
  }

  // ── Validation des inscriptions (décision de la Direction) ───────────────

  /// Dossiers vérifiés, en attente de la décision finale de la Direction.
  static Stream<List<Inscription>> pendingStream() {
    return _inscriptions
        .where('statut', isEqualTo: InscriptionStatut.enAttente.value)
        .snapshots()
        .map((snap) {
      final list = snap.docs.map(Inscription.fromFirestore).toList();
      list.sort((a, b) {
        final ad = a.dateInscription ?? a.dateImport;
        final bd = b.dateInscription ?? b.dateImport;
        return bd.compareTo(ad);
      });
      return list;
    });
  }

  static Future<void> setDecision(
    Inscription inscription, {
    required bool accepted,
    String? commentaire,
    String? classeId,
    String? classeNom,
    String? niveau,
  }) async {
    final statut =
        accepted ? InscriptionStatut.validee : InscriptionStatut.refusee;
    final batch = _db.batch();
    batch.update(_inscriptions.doc(inscription.id), {
      'statut': statut.value,
      if (commentaire != null) 'commentaire': commentaire,
      if (accepted && classeId != null) 'classeId': classeId,
    });
    if (inscription.eleveId.isNotEmpty) {
      final eleveUpdate = <String, dynamic>{
        'statutInscription': statut.value,
      };
      if (accepted && classeId != null) {
        eleveUpdate['classeId'] = classeId;
        eleveUpdate['classeNom'] = classeNom ?? '';
        eleveUpdate['niveau'] = niveau ?? '';
      }
      batch.update(_eleves.doc(inscription.eleveId), eleveUpdate);
    }
    await batch.commit();

    // If accepted with a class, link existing Firebase Auth account (best-effort)
    if (accepted && classeId != null && inscription.eleve.emailEleve.isNotEmpty) {
      try {
        final usersSnap = await _db
            .collection('users')
            .where('email', isEqualTo: inscription.eleve.emailEleve)
            .limit(1)
            .get();
        // FIX : ne jamais écraser le rôle d'un compte existant qui n'est pas
        // déjà 'eleve'. Sans cette garde, un email d'inscription élève
        // coïncidant avec un compte professeur/direction/parent existant
        // (doublon, faute de frappe) reclassait silencieusement ce compte
        // en 'eleve' — il disparaissait alors de son vrai rôle et apparaissait
        // à tort dans la liste des élèves.
        final existingRole =
            usersSnap.docs.isNotEmpty ? usersSnap.docs.first.data()['role'] as String? : null;
        if (usersSnap.docs.isNotEmpty &&
            (existingRole == null || existingRole == 'eleve')) {
          final userRef = usersSnap.docs.first.reference;
          final uid = usersSnap.docs.first.id;
          final oldClasseId = usersSnap.docs.first.data()['classeId'] as String?;
          final linkBatch = _db.batch();
          linkBatch.update(userRef, {
            'classeId': classeId,
            'classeNom': classeNom ?? '',
            'niveau': niveau ?? '',
            'role': 'eleve',
          });
          if (oldClasseId != null && oldClasseId.isNotEmpty && oldClasseId != classeId) {
            linkBatch.update(_db.collection('classes').doc(oldClasseId), {
              'eleveIds': FieldValue.arrayRemove([uid]),
            });
          }
          linkBatch.update(_db.collection('classes').doc(classeId), {
            'eleveIds': FieldValue.arrayUnion([uid]),
          });
          await linkBatch.commit();
        }
      } catch (_) {
        // Student may not have registered yet — syncProfile() will handle it later
      }
    }
  }

  // ── Tableau de bord ───────────────────────────────────────────────────────

  /// Total des dossiers traités (hors brouillons en cours de vérification).
  static Stream<int> totalInscriptionsStream() {
    return _inscriptions
        .where('statut', whereIn: _statutsFinalises)
        .snapshots()
        .map((snap) => snap.docs.length);
  }

  static Stream<int> countByStatut(InscriptionStatut statut) {
    return _inscriptions
        .where('statut', isEqualTo: statut.value)
        .snapshots()
        .map((snap) => snap.docs.length);
  }

  static Stream<int> totalElevesStream() {
    return _eleves.snapshots().map((snap) => snap.docs.length);
  }

  static Stream<List<Inscription>> recentInscriptionsStream({int limit = 5}) {
    return _inscriptions
        .orderBy('dateInscription', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs.map(Inscription.fromFirestore).toList());
  }

  // ── Recherche ─────────────────────────────────────────────────────────────
  // Recherche par nom/prénom élève, matricule, nom ou téléphone parent.

  static Stream<List<Inscription>> search(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return Stream.value(const []);
    return _inscriptions
        .where('statut', whereIn: _statutsFinalises)
        .snapshots()
        .map((snap) {
      final all = snap.docs.map(Inscription.fromFirestore).toList();
      return all.where((i) {
        return i.eleve.nom.toLowerCase().contains(q) ||
            i.eleve.prenom.toLowerCase().contains(q) ||
            i.matricule.toLowerCase().contains(q) ||
            i.parent1.nomComplet.toLowerCase().contains(q) ||
            i.parent1.telephone.contains(q) ||
            (i.parent2?.nomComplet.toLowerCase().contains(q) ?? false) ||
            (i.parent2?.telephone.contains(q) ?? false);
      }).toList()
        ..sort((a, b) => (b.dateInscription ?? b.dateImport)
            .compareTo(a.dateInscription ?? a.dateImport));
    });
  }
}
