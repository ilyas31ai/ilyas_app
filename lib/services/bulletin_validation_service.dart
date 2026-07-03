import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/bulletin_validation_model.dart';

class BulletinValidationService {
  static final _db = FirebaseFirestore.instance;
  static final _col = _db.collection('bulletin_validations');

  static String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  // ── Lecture ───────────────────────────────────────────────────────────────

  /// Stream du statut de publication pour une classe/trimestre.
  /// Retourne `null` si aucun document n'existe encore (= non publié).
  static Stream<BulletinValidationModel?> stream({
    required String classeId,
    required int trimestre,
    required int anneeScol,
  }) {
    final id = BulletinValidationModel.docId(
        classeId: classeId, trimestre: trimestre, anneeScol: anneeScol);
    return _col.doc(id).snapshots().map((snap) {
      if (!snap.exists) return null;
      return BulletinValidationModel.fromFirestore(snap);
    });
  }

  /// Stream de toutes les validations d'une année scolaire.
  static Stream<List<BulletinValidationModel>> streamAll(int anneeScol) {
    return _col
        .where('anneeScol', isEqualTo: anneeScol)
        .snapshots()
        .map((s) => s.docs
            .map(BulletinValidationModel.fromFirestore)
            .toList());
  }

  /// Vérifie si un bulletin est publié (one-shot).
  static Future<bool> isPublished({
    required String classeId,
    required int trimestre,
    required int anneeScol,
  }) async {
    final id = BulletinValidationModel.docId(
        classeId: classeId, trimestre: trimestre, anneeScol: anneeScol);
    final doc = await _col.doc(id).get();
    if (!doc.exists) return false;
    return (doc.data()?['publie'] as bool?) ?? false;
  }

  // ── Écriture (Direction uniquement) ──────────────────────────────────────

  /// Publie ou dépublie le bulletin d'une classe pour un trimestre.
  static Future<void> publish({
    required String classeId,
    required String classeNom,
    required int trimestre,
    required int anneeScol,
    required bool publie,
    String? directionNom,
    String? note,
    String schoolId = 'ecole_default',
  }) async {
    final uid = _uid;
    final id = BulletinValidationModel.docId(
        classeId: classeId, trimestre: trimestre, anneeScol: anneeScol);

    await _col.doc(id).set(
      {
        'schoolId': schoolId,
        'classeId': classeId,
        'classeNom': classeNom,
        'trimestre': trimestre,
        'anneeScol': anneeScol,
        'publie': publie,
        'datePub': publie ? FieldValue.serverTimestamp() : null,
        'directionUid': uid,
        'directionNom': directionNom ?? '',
        if (note != null) 'note': note,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }
}
