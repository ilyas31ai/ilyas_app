import 'package:cloud_firestore/cloud_firestore.dart';

/// Gère la gamification pour SCOLAR Connect.
/// Collection Firestore : scolar_gamification/{uid}
/// Champs : xp, level, badges, streak, weeklyXp, lastActivity
class ScolarGamificationService {
  static final _db = FirebaseFirestore.instance;
  static const _collection = 'scolar_gamification';

  static const int xpPerMessage = 5;
  static const int xpPerGroup = 20;
  static const int xpPerPartage = 15;

  // ── Stream ────────────────────────────────────────────────────────────────

  static Stream<Map<String, dynamic>> statsStream(String uid) {
    if (uid.isEmpty) {
      return Stream.value({
        'xp': 0,
        'level': 1,
        'badges': <String>[],
        'streak': 0,
        'weeklyXp': 0,
      });
    }
    return _db
        .collection(_collection)
        .doc(uid)
        .snapshots()
        .map<Map<String, dynamic>>((snap) {
          if (!snap.exists || snap.data() == null) {
            return {
              'xp': 0,
              'level': 1,
              'badges': <String>[],
              'streak': 0,
              'weeklyXp': 0,
            };
          }
          return snap.data()!;
        })
        .asBroadcastStream();
  }

  // ── XP ────────────────────────────────────────────────────────────────────

  /// Ajoute [amount] XP à l'utilisateur [uid] pour la raison [reason].
  static Future<void> addXP(String uid, int amount, String reason) async {
    if (uid.isEmpty) return;
    final ref = _db.collection(_collection).doc(uid);
    final snap = await ref.get();
    final data = snap.data() ?? {};
    final currentXp = (data['xp'] as int? ?? 0) + amount;
    final newLevel = levelFromXP(currentXp);
    final weeklyXp = (data['weeklyXp'] as int? ?? 0) + amount;
    await ref.set({
      'xp': currentXp,
      'level': newLevel,
      'weeklyXp': weeklyXp,
      'lastXpReason': reason,
      'lastActivity': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Formule niveau : level = floor(xp / 100) + 1
  static int levelFromXP(int xp) => (xp / 100).floor() + 1;

  // ── Badges ────────────────────────────────────────────────────────────────

  /// Ajoute le badge [badge] au profil de l'utilisateur [uid].
  static Future<void> awardBadge(String uid, String badge) async {
    if (uid.isEmpty || badge.isEmpty) return;
    await _db.collection(_collection).doc(uid).set({
      'badges': FieldValue.arrayUnion([badge]),
    }, SetOptions(merge: true));
  }

  // ── Activité / Streak ────────────────────────────────────────────────────

  /// Met à jour lastActivity et calcule le streak journalier.
  static Future<void> recordActivity(String uid) async {
    if (uid.isEmpty) return;
    final ref = _db.collection(_collection).doc(uid);
    final snap = await ref.get();
    final data = snap.data() ?? {};
    final lastActivity = (data['lastActivity'] as Timestamp?)?.toDate();
    final now = DateTime.now();

    int streak = data['streak'] as int? ?? 0;
    if (lastActivity != null) {
      final lastDay = DateTime(lastActivity.year, lastActivity.month, lastActivity.day);
      final today = DateTime(now.year, now.month, now.day);
      final diff = today.difference(lastDay).inDays;
      if (diff == 1) {
        streak += 1;
      } else if (diff > 1) {
        streak = 1;
      }
      // diff == 0 → même jour, streak inchangé
    } else {
      streak = 1;
    }

    await ref.set({
      'lastActivity': FieldValue.serverTimestamp(),
      'streak': streak,
    }, SetOptions(merge: true));
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// Liste de tous les badges possibles.
  static const List<String> allBadges = [
    'Explorateur',
    'Communicateur',
    'Connecté',
    'Partageur',
    'Leader',
    'Studieux',
    'Persévérant',
    'Expert',
  ];

  /// Emoji associé à chaque badge.
  static String badgeEmoji(String badge) {
    const map = {
      'Explorateur': '🌟',
      'Communicateur': '💬',
      'Connecté': '🤝',
      'Partageur': '📚',
      'Leader': '🏆',
      'Studieux': '📖',
      'Persévérant': '🔥',
      'Expert': '🎓',
    };
    return map[badge] ?? '⭐';
  }

  /// Couleur associée à chaque badge.
  static int badgeColorValue(String badge) {
    const map = {
      'Explorateur': 0xFFD97706,
      'Communicateur': 0xFF2563EB,
      'Connecté': 0xFF6C47FF,
      'Partageur': 0xFF0D9488,
      'Leader': 0xFFEC4899,
      'Studieux': 0xFF16A34A,
      'Persévérant': 0xFFDC2626,
      'Expert': 0xFF7C3AED,
    };
    return map[badge] ?? 0xFF6C47FF;
  }
}
