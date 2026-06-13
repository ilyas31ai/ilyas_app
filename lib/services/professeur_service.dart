import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import '../models/classe_model.dart';
import '../models/devoir_model.dart';
import '../models/document_model.dart';
import '../models/note_model.dart';
import '../models/presence_model.dart';
import '../models/user_model.dart';

class ProfesseurService {
  static final _db = FirebaseFirestore.instance;
  static final _storage = FirebaseStorage.instance;

  static String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  static CollectionReference<Map<String, dynamic>> get _classes =>
      _db.collection('classes');
  static CollectionReference<Map<String, dynamic>> get _presences =>
      _db.collection('presences');
  static CollectionReference<Map<String, dynamic>> get _notes =>
      _db.collection('notes');
  static CollectionReference<Map<String, dynamic>> get _devoirs =>
      _db.collection('devoirs');
  static CollectionReference<Map<String, dynamic>> get _documents =>
      _db.collection('documents_prof');
  static CollectionReference<Map<String, dynamic>> get _emplois =>
      _db.collection('emplois_du_temps');

  // ── Classes ───────────────────────────────────────────────────────────────

  static Stream<List<ClasseModel>> classesStream() {
    return _classes
        .where('professeurId', isEqualTo: _uid)
        .snapshots()
        .map((s) {
      final list = s.docs.map(ClasseModel.fromFirestore).toList();
      list.sort((a, b) => a.nom.compareTo(b.nom));
      return list;
    });
  }

  static Future<String> addClass({
    required String nom,
    required String niveau,
  }) async {
    final uid = _uid;
    if (uid.isEmpty) {
      throw Exception('Utilisateur non authentifié (uid vide)');
    }
    try {
      final doc = await _classes.add({
        'nom': nom,
        'niveau': niveau,
        'professeurId': uid,
        'eleveIds': <String>[],
        'anneeScol': DateTime.now().year,
      });
      return doc.id;
    } catch (e) {
      debugPrint('[ProfService] addClass: ERREUR — $e');
      rethrow;
    }
  }

  static Future<void> deleteClass(String id) async {
    await _classes.doc(id).delete();
  }

  static Future<void> addEleveToClasse(String classeId, String eleveId) async {
    await _classes.doc(classeId).update({
      'eleveIds': FieldValue.arrayUnion([eleveId]),
    });
  }

  static Future<void> removeEleveFromClasse(
      String classeId, String eleveId) async {
    await _classes.doc(classeId).update({
      'eleveIds': FieldValue.arrayRemove([eleveId]),
    });
  }

  // ── Emploi du temps ───────────────────────────────────────────────────────

  static Stream<List<EmploiSlot>> emploiStream() {
    return _emplois
        .where('professeurId', isEqualTo: _uid)
        .snapshots()
        .map((s) {
      final list = s.docs.map(EmploiSlot.fromFirestore).toList();
      list.sort((a, b) {
        final j = a.jour.compareTo(b.jour);
        if (j != 0) return j;
        return a.heureDebut.compareTo(b.heureDebut);
      });
      return list;
    });
  }

  static Future<void> addSlot({
    required int jour,
    required String heureDebut,
    required String heureFin,
    required String matiere,
    required String classeNom,
    required String classeId,
    required String salle,
  }) async {
    await _emplois.add({
      'jour': jour,
      'heureDebut': heureDebut,
      'heureFin': heureFin,
      'matiere': matiere,
      'classeNom': classeNom,
      'classeId': classeId,
      'salle': salle,
      'professeurId': _uid,
    });
  }

  static Future<void> deleteSlot(String id) async {
    await _emplois.doc(id).delete();
  }

  // ── Élèves (issus de la collection Direction) ─────────────────────────────

  static Stream<List<Map<String, dynamic>>> elevesParClasseStream(
      String classeNom) {
    if (classeNom.isEmpty) return Stream.value(const []);
    return _db
        .collection('eleves')
        .where('classe', isEqualTo: classeNom)
        .snapshots()
        .map((s) => s.docs.map((d) => {'id': d.id, ...d.data()}).toList()
          ..sort((a, b) {
            final na = '${a['prenom']} ${a['nom']}';
            final nb = '${b['prenom']} ${b['nom']}';
            return na.compareTo(nb);
          }));
  }

  // ── Présences ─────────────────────────────────────────────────────────────

  static Stream<List<PresenceRecord>> presencesParJourStream(
      String classeId, DateTime date) {
    final debut = DateTime(date.year, date.month, date.day);
    final fin = debut.add(const Duration(days: 1));
    return _presences
        .where('classeId', isEqualTo: classeId)
        .where('date',
            isGreaterThanOrEqualTo: Timestamp.fromDate(debut),
            isLessThan: Timestamp.fromDate(fin))
        .snapshots()
        .map((s) => s.docs.map(PresenceRecord.fromFirestore).toList());
  }

  static Stream<List<PresenceRecord>> historiquePresencesStream(
      String classeId) {
    return _presences
        .where('classeId', isEqualTo: classeId)
        .orderBy('date', descending: true)
        .limit(50)
        .snapshots()
        .map((s) => s.docs.map(PresenceRecord.fromFirestore).toList());
  }

  static Future<void> saveAppel({
    required String classeId,
    required String classeNom,
    required DateTime date,
    required List<Map<String, dynamic>> eleves, // [{id, nom, prenom}]
    required Map<String, PresenceStatut> statuts,
    required Map<String, String> motifs,
  }) async {
    final batch = _db.batch();
    for (final eleve in eleves) {
      final eid = eleve['id'] as String;
      final ref = _presences.doc('${classeId}_${eid}_${date.toIso8601String().substring(0, 10)}');
      batch.set(ref, {
        'eleveId': eid,
        'eleveNom': eleve['nom'] as String? ?? '',
        'elevePrenom': eleve['prenom'] as String? ?? '',
        'classeId': classeId,
        'classeNom': classeNom,
        'professeurId': _uid,
        'date': Timestamp.fromDate(date),
        'statut': (statuts[eid] ?? PresenceStatut.present).value,
        'motif': motifs[eid] ?? '',
      });
    }
    await batch.commit();
  }

  // ── Notes ─────────────────────────────────────────────────────────────────

  static Stream<List<NoteModel>> notesStream(
      String classeId, String matiere) {
    var query = _notes
        .where('classeId', isEqualTo: classeId)
        .where('professeurId', isEqualTo: _uid);
    if (matiere.isNotEmpty) {
      query = query.where('matiere', isEqualTo: matiere);
    }
    return query.snapshots().map((s) {
      final list = s.docs.map(NoteModel.fromFirestore).toList();
      list.sort((a, b) => b.date.compareTo(a.date));
      return list;
    });
  }

  static Future<void> addNote({
    required String eleveId,
    required String eleveNom,
    required String elevePrenom,
    required String classeId,
    required String classeNom,
    required String matiere,
    required double note,
    required double bareme,
    required String intitule,
  }) async {
    await _notes.add({
      'eleveId': eleveId,
      'eleveNom': eleveNom,
      'elevePrenom': elevePrenom,
      'classeId': classeId,
      'classeNom': classeNom,
      'matiere': matiere,
      'professeurId': _uid,
      'note': note,
      'bareme': bareme,
      'intitule': intitule,
      'date': FieldValue.serverTimestamp(),
      'publie': false,
    });
  }

  static Future<void> updateNote(
    String id, {
    required double note,
    String? intitule,
  }) async {
    await _notes.doc(id).update({
      'note': note,
      if (intitule != null) 'intitule': intitule,
    });
  }

  static Future<void> publierNotes(String classeId, String matiere) async {
    final snap = await _notes
        .where('classeId', isEqualTo: classeId)
        .where('matiere', isEqualTo: matiere)
        .where('professeurId', isEqualTo: _uid)
        .get();
    final batch = _db.batch();
    for (final doc in snap.docs) {
      batch.update(doc.reference, {'publie': true});
    }
    await batch.commit();
  }

  static Future<void> deleteNote(String id) async {
    await _notes.doc(id).delete();
  }

  // ── Devoirs ───────────────────────────────────────────────────────────────

  static Stream<List<DevoirModel>> devoirsStream() {
    return _devoirs
        .where('professeurId', isEqualTo: _uid)
        .orderBy('dateEnvoi', descending: true)
        .snapshots()
        .map((s) => s.docs.map(DevoirModel.fromFirestore).toList());
  }

  static Future<void> sendDevoir({
    required String titre,
    required String description,
    required String matiere,
    required String classeId,
    required String classeNom,
    DateTime? dateLimite,
    File? fichier,
    String? fichierNom,
  }) async {
    String fichierUrl = '';
    String nom = '';

    if (fichier != null && fichierNom != null) {
      final ref = _storage
          .ref('devoirs/$_uid/${DateTime.now().millisecondsSinceEpoch}_$fichierNom');
      await ref.putFile(fichier);
      fichierUrl = await ref.getDownloadURL();
      nom = fichierNom;
    }

    await _devoirs.add({
      'titre': titre,
      'description': description,
      'matiere': matiere,
      'classeId': classeId,
      'classeNom': classeNom,
      'professeurId': _uid,
      'dateEnvoi': FieldValue.serverTimestamp(),
      if (dateLimite != null) 'dateLimite': Timestamp.fromDate(dateLimite),
      'fichierUrl': fichierUrl,
      'fichierNom': nom,
    });
  }

  static Future<void> deleteDevoir(String id) async {
    await _devoirs.doc(id).delete();
  }

  // ── Documents pédagogiques ────────────────────────────────────────────────

  static Stream<List<DocumentPedagogique>> documentsStream() {
    return _documents
        .where('professeurId', isEqualTo: _uid)
        .orderBy('dateDepot', descending: true)
        .snapshots()
        .map((s) => s.docs.map(DocumentPedagogique.fromFirestore).toList());
  }

  static Future<void> addDocument({
    required String titre,
    required String description,
    required String matiere,
    required String classeId,
    required String classeNom,
    required String type,
    File? fichier,
    String? fichierNom,
  }) async {
    String fichierUrl = '';
    String nom = '';

    if (fichier != null && fichierNom != null) {
      final ref = _storage
          .ref('documents_prof/$_uid/${DateTime.now().millisecondsSinceEpoch}_$fichierNom');
      await ref.putFile(fichier);
      fichierUrl = await ref.getDownloadURL();
      nom = fichierNom;
    }

    await _documents.add({
      'titre': titre,
      'description': description,
      'matiere': matiere,
      'classeId': classeId,
      'classeNom': classeNom,
      'professeurId': _uid,
      'fichierUrl': fichierUrl,
      'fichierNom': nom,
      'dateDepot': FieldValue.serverTimestamp(),
      'type': type,
    });
  }

  static Future<void> deleteDocument(String id) async {
    await _documents.doc(id).delete();
  }

  // ── Statistiques tableau de bord ──────────────────────────────────────────

  static Stream<int> totalClassesStream() {
    return _classes
        .where('professeurId', isEqualTo: _uid)
        .snapshots()
        .map((s) => s.docs.length);
  }

  static Stream<int> totalElevesStream() {
    return _classes
        .where('professeurId', isEqualTo: _uid)
        .snapshots()
        .map((s) => s.docs.fold<int>(
            0,
            (sum, doc) =>
                sum +
                ((doc.data()['eleveIds'] as List?)?.length ?? 0)));
  }

  static Stream<int> totalDevoirsStream() {
    return _devoirs
        .where('professeurId', isEqualTo: _uid)
        .snapshots()
        .map((s) => s.docs.length);
  }

  static Stream<int> totalDocumentsStream() {
    return _documents
        .where('professeurId', isEqualTo: _uid)
        .snapshots()
        .map((s) => s.docs.length);
  }

  // ── Communication — contacts autorisés (Direction uniquement) ────────────

  static Stream<List<UserModel>> contactsAutorises() {
    return _db
        .collection('users')
        .where('role', isEqualTo: UserRole.admin.value)
        .snapshots()
        .map((s) => s.docs
            .map((d) => UserModel.fromDoc(d))
            .where((u) => u.uid != _uid)
            .toList());
  }
}
