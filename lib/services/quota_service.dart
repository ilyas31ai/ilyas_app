import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/user_model.dart';

class QuotaExceededException implements Exception {
  final String message;
  const QuotaExceededException(this.message);
  @override
  String toString() => message;
}

/// Quotas journaliers par rôle.
const Map<String, int> _kLimits = {
  'eleve': 20,
  'professeur': 50,
  'admin': -1, // illimité
  'parent': 10,
};

class QuotaService {
  static final _db = FirebaseFirestore.instance;

  static String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';
  static String get _today {
    final now = DateTime.now();
    final y = now.year.toString().padLeft(4, '0');
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return '$y$m$d';
  }

  static String _docId(String uid) => '${uid}_$_today';

  /// Vérifie si l'utilisateur peut encore appeler l'IA,
  /// incrémente le compteur et retourne le nombre de requêtes restantes.
  /// Lance [QuotaExceededException] si le quota est atteint.
  static Future<int> checkAndIncrement(UserRole role) async {
    final uid = _uid;
    if (uid.isEmpty) throw const QuotaExceededException('Non authentifié.');

    // Admins : illimité
    if (role == UserRole.admin) return 9999;

    final limit = _kLimits[role.value] ?? 10;
    final docRef = _db.collection('quotas').doc(_docId(uid));

    return _db.runTransaction((tx) async {
      final snap = await tx.get(docRef);
      final current = snap.exists ? (snap.data()?['count'] as num?)?.toInt() ?? 0 : 0;

      if (current >= limit) {
        throw QuotaExceededException(
          'Quota IA atteint ($current/$limit requêtes aujourd\'hui).',
        );
      }

      final next = current + 1;
      if (snap.exists) {
        tx.update(docRef, {
          'count': next,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        tx.set(docRef, {
          'uid': uid,
          'role': role.value,
          'date': _today,
          'count': next,
          'limit': limit,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      return limit - next; // requêtes restantes
    });
  }

  /// Retourne le nombre de requêtes utilisées aujourd'hui (sans incrémentation).
  static Future<Map<String, int>> status(UserRole role) async {
    final uid = _uid;
    if (uid.isEmpty) return {'used': 0, 'limit': 0, 'remaining': 0};

    if (role == UserRole.admin) {
      return {'used': 0, 'limit': -1, 'remaining': 9999};
    }

    final limit = _kLimits[role.value] ?? 10;
    final snap = await _db.collection('quotas').doc(_docId(uid)).get();
    final used = snap.exists ? (snap.data()?['count'] as num?)?.toInt() ?? 0 : 0;

    return {
      'used': used,
      'limit': limit,
      'remaining': (limit - used).clamp(0, limit),
    };
  }
}
