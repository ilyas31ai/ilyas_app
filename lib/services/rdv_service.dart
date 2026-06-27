import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/rdv_model.dart';

/// Service côté professeur pour gérer les RDV.
class RdvService {
  static final _db = FirebaseFirestore.instance;
  static String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  // ── Flux RDV du professeur connecté ──────────────────────────────────────

  static Stream<List<RdvModel>> rdvProfesseurStream() {
    final uid = _uid;
    if (uid.isEmpty) return Stream.value([]);
    return _db
        .collection('rdv')
        .where('professeurId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map(RdvModel.fromFirestore).toList());
  }

  // ── Accepter un RDV ───────────────────────────────────────────────────────

  static Future<void> accepter(String rdvId, {String notesProfesseur = ''}) async {
    final data = <String, dynamic>{
      'statut': RdvStatut.accepte.value,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (notesProfesseur.isNotEmpty) data['notesProfesseur'] = notesProfesseur;
    await _db.collection('rdv').doc(rdvId).update(data);
  }

  // ── Refuser un RDV ────────────────────────────────────────────────────────

  static Future<void> refuser(String rdvId, {String notesProfesseur = ''}) async {
    final data = <String, dynamic>{
      'statut': RdvStatut.refuse.value,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (notesProfesseur.isNotEmpty) data['notesProfesseur'] = notesProfesseur;
    await _db.collection('rdv').doc(rdvId).update(data);
  }

  // ── Proposer une autre date ───────────────────────────────────────────────

  static Future<void> proposerAutreDate(
    String rdvId,
    DateTime nouvelleDate, {
    String notesProfesseur = '',
  }) async {
    final data = <String, dynamic>{
      'statut': RdvStatut.proposeAutreDate.value,
      'contrePropositionDate': nouvelleDate,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (notesProfesseur.isNotEmpty) data['notesProfesseur'] = notesProfesseur;
    await _db.collection('rdv').doc(rdvId).update(data);
  }
}
