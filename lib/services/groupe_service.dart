import 'dart:io';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../models/groupe_model.dart';

/// Service Firestore pour la gestion des groupes d'étude SCOLAR AI Educative.
///
/// Collection : `scolar_groupes/{groupeId}`
/// Sous-collections : `membres/{uid}`, `documents/{docId}`, `objectifs/{objId}`
/// RTDB (chat) : `messages/{chatName}/{messageKey}`
class GroupeService {
  static final _db = FirebaseFirestore.instance;
  static final _storage = FirebaseStorage.instanceFor(
      bucket: 'gs://ilyasapp-4762c.firebasestorage.app');
  static final _rtdb = FirebaseDatabase.instance;

  static String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';
  static String get _email => FirebaseAuth.instance.currentUser?.email ?? '';
  static String get _nom =>
      FirebaseAuth.instance.currentUser?.displayName ??
      _email.split('@').first;

  static CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('scolar_groupes');

  // ── Création ──────────────────────────────────────────────────────────────

  static Future<String> creerGroupe({
    required String nom,
    String description = '',
    String matiere = '',
    String niveau = '',
    GroupeType type = GroupeType.public,
    String? classeId,
    String? classeNom,
  }) async {
    final uid = _uid;
    if (uid.isEmpty) throw Exception('Non authentifié');

    final ref = _col.doc();
    final batch = _db.batch();

    batch.set(ref, {
      'nom':         nom,
      'description': description,
      'matiere':     matiere,
      'niveau':      niveau,
      'type':        type.value,
      if (classeId != null) 'classeId': classeId,
      if (classeNom != null) 'classeNom': classeNom,
      'creatorUid':   uid,
      'creatorEmail': _email,
      'memberCount': 1,
      'createdAt':   FieldValue.serverTimestamp(),
      'updatedAt':   FieldValue.serverTimestamp(),
    });

    // Ajouter le créateur comme admin
    batch.set(ref.collection('membres').doc(uid), {
      'email':    _email,
      'nom':      _nom,
      'role':     'admin',
      'joinedAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
    return ref.id;
  }

  // ── Rejoindre / Quitter ───────────────────────────────────────────────────

  static Future<void> rejoindreGroupe(String groupeId) async {
    final uid = _uid;
    if (uid.isEmpty) return;
    final membreRef = _col.doc(groupeId).collection('membres').doc(uid);
    final existing = await membreRef.get();
    if (existing.exists) return;

    final batch = _db.batch();
    batch.set(membreRef, {
      'email':    _email,
      'nom':      _nom,
      'role':     'membre',
      'joinedAt': FieldValue.serverTimestamp(),
    });
    batch.update(_col.doc(groupeId), {
      'memberCount': FieldValue.increment(1),
      'updatedAt':   FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }

  static Future<void> quitterGroupe(String groupeId) async {
    final uid = _uid;
    if (uid.isEmpty) return;
    final batch = _db.batch();
    batch.delete(_col.doc(groupeId).collection('membres').doc(uid));
    batch.update(_col.doc(groupeId), {
      'memberCount': FieldValue.increment(-1),
      'updatedAt':   FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }

  // ── Invitation par email ──────────────────────────────────────────────────

  static Future<void> inviterParEmail(
      String groupeId, String targetEmail) async {
    if (targetEmail.isEmpty) return;
    try {
      // Chercher l'uid de l'utilisateur cible dans Firestore
      final snap = await _db
          .collection('users')
          .where('email', isEqualTo: targetEmail)
          .limit(1)
          .get();

      String targetUid;
      String targetNom;
      if (snap.docs.isNotEmpty) {
        final d = snap.docs.first.data();
        targetUid = d['uid'] as String? ?? snap.docs.first.id;
        targetNom = d['displayName'] as String? ?? targetEmail.split('@').first;
      } else {
        // Profil non trouvé : ajouter quand même avec uid = email encodé
        targetUid = targetEmail.replaceAll('.', '_').replaceAll('@', '__at__');
        targetNom = targetEmail.split('@').first;
      }

      final membreRef =
          _col.doc(groupeId).collection('membres').doc(targetUid);
      final existing = await membreRef.get();
      if (existing.exists) return;

      final batch = _db.batch();
      batch.set(membreRef, {
        'email':    targetEmail,
        'nom':      targetNom,
        'role':     'membre',
        'joinedAt': FieldValue.serverTimestamp(),
      });
      batch.update(_col.doc(groupeId), {
        'memberCount': FieldValue.increment(1),
        'updatedAt':   FieldValue.serverTimestamp(),
      });
      await batch.commit();

      // Notifier via RTDB
      _notifyMembre(targetEmail,
          'Invitation groupe', 'Vous avez été invité à rejoindre un groupe');
    } catch (_) {}
  }

  static Future<void> changerRole(
      String groupeId, String targetUid, GroupeRole role) async {
    await _col
        .doc(groupeId)
        .collection('membres')
        .doc(targetUid)
        .update({'role': role == GroupeRole.admin ? 'admin' : 'membre'});
  }

  static Future<void> supprimerMembre(
      String groupeId, String targetUid) async {
    final batch = _db.batch();
    batch.delete(
        _col.doc(groupeId).collection('membres').doc(targetUid));
    batch.update(_col.doc(groupeId), {
      'memberCount': FieldValue.increment(-1),
      'updatedAt':   FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }

  // ── Documents ─────────────────────────────────────────────────────────────

  static Future<void> ajouterDocument({
    required String groupeId,
    required String titre,
    String type = 'fiche',
    String contenu = '',
    File? fichier,
    String? nomFichier,
  }) async {
    final uid = _uid;
    if (uid.isEmpty) return;

    String? fileUrl;
    String? fileName;
    if (fichier != null) {
      fileUrl = await _uploadGroupFile(groupeId, fichier, nomFichier);
      fileName = nomFichier ?? fichier.path.split('/').last.split('\\').last;
    }

    await _col.doc(groupeId).collection('documents').add({
      'titre':       titre,
      'type':        type,
      'contenu':     contenu,
      if (fileUrl != null) 'fileUrl': fileUrl,
      if (fileName != null) 'fileName': fileName,
      'auteurUid':   uid,
      'auteurEmail': _email,
      'auteurNom':   _nom,
      'createdAt':   FieldValue.serverTimestamp(),
    });

    await _col.doc(groupeId).update({
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> supprimerDocument(
      String groupeId, String docId) async {
    await _col.doc(groupeId).collection('documents').doc(docId).delete();
  }

  // ── Upload fichier groupe ─────────────────────────────────────────────────

  static Future<String?> _uploadGroupFile(
      String groupeId, File file, String? name) async {
    try {
      final token = _generateToken();
      final ext = file.path.split('.').last.toLowerCase();
      final nomFichier = name ??
          '${DateTime.now().millisecondsSinceEpoch}.$ext';
      final ref = _storage.ref().child('groupe_files/$groupeId/$nomFichier');
      final bytes = await file.readAsBytes();
      final task = await ref.putData(
        bytes,
        SettableMetadata(
          customMetadata: {'firebaseStorageDownloadTokens': token},
        ),
      );
      if (task.state == TaskState.success) {
        final bucket = task.ref.bucket;
        final encoded = Uri.encodeComponent(task.ref.fullPath);
        return 'https://firebasestorage.googleapis.com/v0/b/$bucket/o/$encoded?alt=media&token=$token';
      }
    } catch (_) {}
    return null;
  }

  // ── Streams ───────────────────────────────────────────────────────────────

  /// Tous les groupes publics, triés par date.
  static Stream<List<GroupeModel>> groupesPublicsStream() {
    return _col
        .where('type', isEqualTo: 'public')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map(GroupeModel.fromFirestore).toList());
  }

  /// Groupes où l'utilisateur courant est membre.
  static Stream<List<GroupeModel>> mesGroupesStream() {
    final uid = _uid;
    if (uid.isEmpty) return const Stream.empty();
    return _col
        .orderBy('createdAt', descending: true)
        .snapshots()
        .asyncMap((snap) async {
      final result = <GroupeModel>[];
      for (final doc in snap.docs) {
        final memSnap = await _col
            .doc(doc.id)
            .collection('membres')
            .doc(uid)
            .get();
        if (memSnap.exists) result.add(GroupeModel.fromFirestore(doc));
      }
      return result;
    });
  }

  /// Tous les groupes (publics + groupes dont je suis membre).
  static Stream<List<GroupeModel>> tousGroupesStream() {
    return _col
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map(GroupeModel.fromFirestore).toList());
  }

  static Stream<List<GroupeMembre>> membresStream(String groupeId) {
    return _col
        .doc(groupeId)
        .collection('membres')
        .orderBy('joinedAt')
        .snapshots()
        .map((s) => s.docs.map(GroupeMembre.fromFirestore).toList());
  }

  static Stream<List<GroupeDocument>> documentsStream(String groupeId) {
    return _col
        .doc(groupeId)
        .collection('documents')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map(GroupeDocument.fromFirestore).toList());
  }

  /// Vérifie si l'utilisateur courant est membre d'un groupe.
  static Future<bool> estMembre(String groupeId) async {
    final uid = _uid;
    if (uid.isEmpty) return false;
    final snap =
        await _col.doc(groupeId).collection('membres').doc(uid).get();
    return snap.exists;
  }

  /// Rôle de l'utilisateur courant dans le groupe.
  static Future<GroupeRole?> monRole(String groupeId) async {
    final uid = _uid;
    if (uid.isEmpty) return null;
    final snap =
        await _col.doc(groupeId).collection('membres').doc(uid).get();
    if (!snap.exists) return null;
    return GroupeRoleX.fromString(snap.data()?['role'] as String?);
  }

  // ── Notification RTDB ────────────────────────────────────────────────────

  static void _notifyMembre(String email, String title, String body) {
    try {
      final key = email.replaceAll('.', ',');
      _rtdb.ref('notifications/$key').push().set({
        'title': title,
        'body':  body,
        'ts':    ServerValue.timestamp,
      });
    } catch (_) {}
  }

  static String _generateToken() {
    const chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rng = Random.secure();
    return List.generate(36, (_) => chars[rng.nextInt(chars.length)]).join();
  }
}
