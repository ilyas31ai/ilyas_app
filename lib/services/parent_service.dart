import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/devoir_model.dart';
import '../models/document_model.dart';
import '../models/note_model.dart';
import '../models/rdv_model.dart';
import '../models/user_model.dart';

/// Service pour l'espace parent : lit les données des enfants liés.
/// Toutes les queries respectent les règles Firestore (isParentOf / isParentInClass).
class ParentService {
  static final _db = FirebaseFirestore.instance;
  static String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  // ── Profil enfant ──────────────────────────────────────────────────────────

  static Stream<UserModel?> enfantStream(String enfantUid) {
    return _db
        .collection('users')
        .doc(enfantUid)
        .snapshots()
        .map((s) => s.exists ? UserModel.fromDoc(s) : null);
  }

  // ── Notes publiées de l'enfant ────────────────────────────────────────────

  static Stream<List<NoteModel>> notesEnfantStream(String enfantUid) {
    return _db
        .collection('notes')
        .where('eleveId', isEqualTo: enfantUid)
        .where('publie', isEqualTo: true)
        .orderBy('date', descending: true)
        .snapshots()
        .map((s) => s.docs.map(NoteModel.fromFirestore).toList());
  }

  // ── Devoirs de la classe de l'enfant ────────────────────────────────────

  static Stream<List<DevoirModel>> devoirsEnfantStream(String classeNom) {
    if (classeNom.isEmpty) return Stream.value([]);
    return _db
        .collection('devoirs')
        .where('classeNom', isEqualTo: classeNom)
        .orderBy('dateEnvoi', descending: true)
        .snapshots()
        .map((s) => s.docs.map(DevoirModel.fromFirestore).toList());
  }

  // ── Emploi du temps de la classe de l'enfant ────────────────────────────

  static Stream<List<Map<String, dynamic>>> emploiEnfantStream(String classeId) {
    if (classeId.isEmpty) return Stream.value([]);
    return _db
        .collection('emplois_du_temps')
        .where('classeId', isEqualTo: classeId)
        .snapshots()
        .map((s) => s.docs
            .map((d) => {'id': d.id, ...d.data()})
            .toList()
          ..sort((a, b) {
            const order = ['Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi'];
            final da = order.indexOf((a['jour'] as String?) ?? '');
            final db = order.indexOf((b['jour'] as String?) ?? '');
            if (da != db) return da.compareTo(db);
            return ((a['heureDebut'] as String?) ?? '')
                .compareTo((b['heureDebut'] as String?) ?? '');
          }));
  }

  // ── Présences de l'enfant ────────────────────────────────────────────────

  static Stream<List<Map<String, dynamic>>> presencesEnfantStream(String enfantUid) {
    if (enfantUid.isEmpty) return Stream.value([]);
    return _db
        .collection('presences')
        .where('eleveId', isEqualTo: enfantUid)
        .orderBy('date', descending: true)
        .limit(30)
        .snapshots()
        .map((s) => s.docs.map((d) => {'id': d.id, ...d.data()}).toList());
  }

  // ── RDV de ce parent ─────────────────────────────────────────────────────

  static Stream<List<RdvModel>> rdvStream() {
    final uid = _uid;
    if (uid.isEmpty) return Stream.value([]);
    return _db
        .collection('rdv')
        .where('parentUid', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map(RdvModel.fromFirestore).toList());
  }

  // ── Demander un RDV ───────────────────────────────────────────────────────

  static Future<void> demanderRdv({
    required String professeurId,
    required String professeurNom,
    required String classeNom,
    required String eleveUid,
    required String eleveNom,
    required DateTime dateHeure,
    required String motif,
    int dureeMinutes = 30,
    String notesParent = '',
  }) async {
    final uid = _uid;
    if (uid.isEmpty) {
      throw Exception('Utilisateur non connecté.');
    }

    final parentDoc = await _db.collection('users').doc(uid).get();
    final parentNom = parentDoc.data()?['displayName'] as String? ?? '';

    await _db.collection('rdv').add({
      'parentUid': uid,
      'parentNom': parentNom,
      'professeurId': professeurId,
      'professeurNom': professeurNom,
      'classeNom': classeNom,
      'eleveUid': eleveUid,
      'eleveNom': eleveNom,
      'dateHeure': dateHeure,
      'dureeMinutes': dureeMinutes,
      'motif': motif,
      'statut': 'demande',
      if (notesParent.isNotEmpty) 'notesParent': notesParent,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ── Annuler un RDV (par le parent) ───────────────────────────────────────

  static Future<void> annulerRdv(String rdvId) async {
    await _db.collection('rdv').doc(rdvId).update({
      'statut': 'annule',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ── Confirmer la contre-proposition du prof ───────────────────────────────

  static Future<void> confirmerContreProposition(String rdvId) async {
    await _db.collection('rdv').doc(rdvId).update({
      'statut': 'confirme',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ── Documents publiés pour la classe de l'enfant ─────────────────────────
  //
  // BUG CORRIGÉ : cette méthode interrogeait la collection `documents_pedagogiques`,
  // qui n'est alimentée par aucun écran Professeur (les documents sont déposés
  // dans `documents_prof` — voir ProfesseurService._documents et
  // EtudiantService.documentsStream). Résultat : l'onglet Documents du parent
  // était systématiquement vide, quel que soit le contenu réel de la classe.
  // On aligne désormais sur la même collection et le même filtrage (par
  // classeNom, tri fait côté client) que le côté Élève, pour éviter de
  // dépendre d'un index composite Firestore non garanti.
  static Stream<List<DocumentPedagogique>> documentsEnfantStream(String classeNom) {
    if (classeNom.isEmpty) return Stream.value([]);
    return _db
        .collection('documents_prof')
        .where('classeNom', isEqualTo: classeNom)
        .snapshots()
        .map((s) {
      final list = s.docs.map(DocumentPedagogique.fromFirestore).toList();
      list.sort((a, b) => b.dateDepot.compareTo(a.dateDepot));
      return list;
    });
  }

  // ── Maternelle : Cahier de vie ─────────────────────────────────────────

  static Stream<List<Map<String, dynamic>>> cahierVieEnfantStream(String enfantUid) {
    if (enfantUid.isEmpty) return Stream.value([]);
    return _db
        .collection('cahier_vie')
        .where('eleveId', isEqualTo: enfantUid)
        .orderBy('date', descending: true)
        .limit(20)
        .snapshots()
        .map((s) => s.docs.map((d) => {'id': d.id, ...d.data()}).toList());
  }

  // ── Maternelle : Repas ────────────────────────────────────────────────

  static Stream<List<Map<String, dynamic>>> repasEnfantStream(String enfantUid) {
    if (enfantUid.isEmpty) return Stream.value([]);
    return _db
        .collection('repas_maternelle')
        .where('eleveId', isEqualTo: enfantUid)
        .orderBy('date', descending: true)
        .limit(10)
        .snapshots()
        .map((s) => s.docs.map((d) => {'id': d.id, ...d.data()}).toList());
  }

  // ── Maternelle : Sieste ───────────────────────────────────────────────

  static Stream<List<Map<String, dynamic>>> siesteEnfantStream(String enfantUid) {
    if (enfantUid.isEmpty) return Stream.value([]);
    return _db
        .collection('sieste_maternelle')
        .where('eleveId', isEqualTo: enfantUid)
        .orderBy('date', descending: true)
        .limit(10)
        .snapshots()
        .map((s) => s.docs.map((d) => {'id': d.id, ...d.data()}).toList());
  }

  // ── Maternelle : Compétences (Acquis / En cours / Non acquis) ─────────

  static Stream<List<Map<String, dynamic>>> competencesEnfantStream(String enfantUid) {
    if (enfantUid.isEmpty) return Stream.value([]);
    return _db
        .collection('competences_maternelle')
        .where('eleveId', isEqualTo: enfantUid)
        .snapshots()
        .map((s) => s.docs.map((d) => {'id': d.id, ...d.data()}).toList());
  }

  // ── Maternelle : Galerie de la classe ────────────────────────────────

  static Stream<List<Map<String, dynamic>>> galerieEnfantStream(String classeNom) {
    if (classeNom.isEmpty) return Stream.value([]);
    return _db
        .collection('galerie_photos')
        .where('classeNom', isEqualTo: classeNom)
        .limit(12)
        .snapshots()
        .map((s) => s.docs.map((d) => {'id': d.id, ...d.data()}).toList());
  }
}
