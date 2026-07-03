import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/bulletin_recap_model.dart';

class BulletinRecapService {
  static final _db = FirebaseFirestore.instance;
  static CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('bulletins_recap');

  static Stream<BulletinRecapModel?> stream({
    required String classeId,
    required int trimestre,
    required int anneeScol,
  }) {
    final id = BulletinRecapModel.docId(
        classeId: classeId, trimestre: trimestre, anneeScol: anneeScol);
    return _col.doc(id).snapshots().map((snap) {
      if (!snap.exists) return null;
      return BulletinRecapModel.fromFirestore(snap);
    });
  }

  static Future<void> save(BulletinRecapModel recap) async {
    final id = BulletinRecapModel.docId(
        classeId: recap.classeId,
        trimestre: recap.trimestre,
        anneeScol: recap.anneeScol);
    await _col.doc(id).set(recap.toMap(), SetOptions(merge: true));
  }
}
