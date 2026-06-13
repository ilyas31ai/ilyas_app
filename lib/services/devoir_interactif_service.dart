import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import '../models/copie_model.dart';
import '../models/devoir_model.dart';
import '../models/question_model.dart';

class DevoirInteractifService {
  static final _db = FirebaseFirestore.instance;
  static final _storage = FirebaseStorage.instance;
  static String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  // ── Professeur ───────────────────────────────────────────────────────────────

  static Future<String> creerDevoir({
    required String titre,
    required String description,
    required String matiere,
    required String classeId,
    required String classeNom,
    required String categorie,
    required List<QuestionModel> questions,
    DateTime? dateLimite,
    File? pdfFile,
    String? pdfNom,
    bool estExamen = false,
    bool aiActive = true,
    int? dureeMinutes,
  }) async {
    String fichierUrl = '';
    String fichierNom = '';

    if (pdfFile != null && pdfNom != null) {
      final ref = _storage.ref(
          'devoirs/$_uid/${DateTime.now().millisecondsSinceEpoch}_$pdfNom');
      await ref.putFile(pdfFile);
      fichierUrl = await ref.getDownloadURL();
      fichierNom = pdfNom;
    }

    final doc = await _db.collection('devoirs').add({
      'titre': titre,
      'description': description,
      'matiere': matiere,
      'classeId': classeId,
      'classeNom': classeNom,
      if (categorie.isNotEmpty) 'categorie': categorie,
      'professeurId': _uid,
      'dateEnvoi': FieldValue.serverTimestamp(),
      if (dateLimite != null) 'dateLimite': Timestamp.fromDate(dateLimite),
      'fichierUrl': fichierUrl,
      'fichierNom': fichierNom,
      'questions': questions.map((q) => q.toMap()).toList(),
      'estExamen': estExamen,
      'aiActive': aiActive,
      if (dureeMinutes != null) 'dureeMinutes': dureeMinutes,
    });

    return doc.id;
  }

  static Stream<List<DevoirModel>> devoirsProfStream() {
    return _db
        .collection('devoirs')
        .where('professeurId', isEqualTo: _uid)
        .orderBy('dateEnvoi', descending: true)
        .snapshots()
        .handleError((Object e) {
      debugPrint('[DevoirInteractif] devoirsProfStream ERROR: $e');
      throw e;
    }).map((s) => s.docs.map(DevoirModel.fromFirestore).toList());
  }

  // ── Élève ────────────────────────────────────────────────────────────────────

  static Stream<List<DevoirModel>> devoirsEleveStream(String classeNom) {
    if (classeNom.isEmpty) return const Stream.empty();
    return _db
        .collection('devoirs')
        .where('classeNom', isEqualTo: classeNom)
        .orderBy('dateEnvoi', descending: true)
        .snapshots()
        .handleError((Object e) {
      debugPrint('[DevoirInteractif] devoirsEleveStream ERROR: $e');
      throw e;
    }).map((s) => s.docs.map(DevoirModel.fromFirestore).toList());
  }

  static Future<CopieModel?> getCopie(String devoirId) async {
    final uid = _uid;
    if (uid.isEmpty) return null;
    try {
      final snap = await _db
          .collection('copies')
          .where('devoirId', isEqualTo: devoirId)
          .where('eleveId', isEqualTo: uid)
          .limit(1)
          .get();
      if (snap.docs.isEmpty) return null;
      return CopieModel.fromFirestore(snap.docs.first);
    } catch (_) {
      return null;
    }
  }

  static Stream<CopieModel?> copieStream(String devoirId) {
    final uid = _uid;
    if (uid.isEmpty) return Stream.value(null);
    return _db
        .collection('copies')
        .where('devoirId', isEqualTo: devoirId)
        .where('eleveId', isEqualTo: uid)
        .limit(1)
        .snapshots()
        .map((s) =>
            s.docs.isEmpty ? null : CopieModel.fromFirestore(s.docs.first));
  }

  /// Creates a new draft or updates an existing one. Returns the copieId.
  static Future<String> sauvegarderCopie({
    required String devoirId,
    required String classeId,
    required String eleveNom,
    required String professeurId,
    required Map<String, dynamic> reponses,
    required bool soumettre,
    String? copieId,
  }) async {
    final uid = _uid;
    final now = DateTime.now();

    final data = <String, dynamic>{
      'devoirId': devoirId,
      'eleveId': uid,
      'eleveNom': eleveNom,
      'classeId': classeId,
      'professeurId': professeurId,
      'reponses': reponses,
      'statut': soumettre ? 'soumis' : 'brouillon',
      if (soumettre) 'dateSoumission': Timestamp.fromDate(now),
    };

    if (copieId != null) {
      await _db.collection('copies').doc(copieId).update(data);
      return copieId;
    } else {
      data['dateDebut'] = Timestamp.fromDate(now);
      final doc = await _db.collection('copies').add(data);
      return doc.id;
    }
  }

  static Future<String> uploadPhotoReponse(
      File photo, String devoirId) async {
    final uid = _uid;
    final ts = DateTime.now().millisecondsSinceEpoch;
    final ref =
        _storage.ref('copies/$uid/$devoirId/${ts}_photo.jpg');
    await ref.putFile(photo);
    return ref.getDownloadURL();
  }

  // ── Professeur : corrections ─────────────────────────────────────────────────

  static Stream<List<CopieModel>> copiesParDevoirStream(String devoirId) {
    return _db
        .collection('copies')
        .where('devoirId', isEqualTo: devoirId)
        .where('statut', whereIn: ['soumis', 'corrige'])
        .snapshots()
        .map((s) => s.docs.map(CopieModel.fromFirestore).toList());
  }

  static Future<void> noterCopie({
    required String copieId,
    required double note,
    required double noteSur,
    String? commentaire,
    Map<String, dynamic>? corrections,
  }) async {
    await _db.collection('copies').doc(copieId).update({
      'statut': 'corrige',
      'note': note,
      'noteSur': noteSur,
      if (commentaire != null) 'commentaire': commentaire,
      if (corrections != null) 'corrections': corrections,
    });
  }

  // ── Stats for student dashboard ───────────────────────────────────────────────

  static Stream<int> devoirsEnAttenteInteractifStream(
      String classeNom) {
    if (classeNom.isEmpty) return Stream.value(0);
    final uid = _uid;
    return _db
        .collection('devoirs')
        .where('classeNom', isEqualTo: classeNom)
        .snapshots()
        .asyncMap((devoirSnap) async {
      if (devoirSnap.docs.isEmpty) return 0;
      final copiesSnap = await _db
          .collection('copies')
          .where('eleveId', isEqualTo: uid)
          .where('statut', whereIn: ['soumis', 'corrige']).get();
      final submittedIds =
          copiesSnap.docs.map((d) => d.data()['devoirId'] as String).toSet();
      return devoirSnap.docs
          .map(DevoirModel.fromFirestore)
          .where((d) => d.estInteractif && !submittedIds.contains(d.id))
          .length;
    });
  }
}
