import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/xp_model.dart';

class XpService {
  static final _db = FirebaseFirestore.instance;

  static String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  static Future<void> gainXP(int amount) async {
    final uid = _uid;
    if (uid.isEmpty) return;
    try {
      final ref = _db.collection('users').doc(uid);
      await _db.runTransaction((tx) async {
        final snap = await tx.get(ref);
        final current = (snap.data()?['xp'] as num?)?.toInt() ?? 0;
        final newXp = current + amount;
        tx.update(ref, {
          'xp': newXp,
          'level': (newXp / 200).floor() + 1,
        });
      });
    } catch (_) {}
  }

  static Future<void> earnBadge(String badgeId) async {
    final uid = _uid;
    if (uid.isEmpty) return;
    try {
      await _db.collection('users').doc(uid).update({
        'badges': FieldValue.arrayUnion([badgeId]),
      });
    } catch (_) {}
  }

  static Stream<XpModel?> currentXpStream() {
    final uid = _uid;
    if (uid.isEmpty) return Stream.value(null);
    return _db
        .collection('users')
        .doc(uid)
        .snapshots()
        .map<XpModel?>((snap) => snap.exists ? XpModel.fromDoc(snap) : null)
        .asBroadcastStream();
  }

  static Stream<List<XpModel>> leaderboardStream() {
    return _db
        .collection('users')
        .orderBy('xp', descending: true)
        .limit(20)
        .snapshots()
        .map<List<XpModel>>(
          (snap) => snap.docs.map((d) => XpModel.fromDoc(d)).toList(),
        )
        .asBroadcastStream();
  }
}
