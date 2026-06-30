import 'package:cloud_firestore/cloud_firestore.dart';

// ─── Rareté ───────────────────────────────────────────────────────────────────

enum BadgeRarity { commun, rare, epique, legendaire }

extension BadgeRarityX on BadgeRarity {
  String get label {
    switch (this) {
      case BadgeRarity.commun:     return 'Commun';
      case BadgeRarity.rare:       return 'Rare';
      case BadgeRarity.epique:     return 'Épique';
      case BadgeRarity.legendaire: return 'Légendaire';
    }
  }

  int get colorValue {
    switch (this) {
      case BadgeRarity.commun:     return 0xFF6B7280;
      case BadgeRarity.rare:       return 0xFF2563EB;
      case BadgeRarity.epique:     return 0xFF6C47FF;
      case BadgeRarity.legendaire: return 0xFFF59E0B;
    }
  }

  int get glowColorValue {
    switch (this) {
      case BadgeRarity.commun:     return 0x006B7280;
      case BadgeRarity.rare:       return 0x332563EB;
      case BadgeRarity.epique:     return 0x336C47FF;
      case BadgeRarity.legendaire: return 0x33F59E0B;
    }
  }
}

// ─── Métadonnées badge ────────────────────────────────────────────────────────

class BadgeInfo {
  final String name;
  final String emoji;
  final int colorValue;
  final BadgeRarity rarity;
  final String description;
  final int xpRequired; // XP minimum pour débloquer (0 = autre condition)

  const BadgeInfo({
    required this.name,
    required this.emoji,
    required this.colorValue,
    required this.rarity,
    required this.description,
    this.xpRequired = 0,
  });
}

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

  /// Catalogue complet des badges, groupés par rareté.
  static const Map<String, BadgeInfo> badgeCatalogue = {
    // ── Commun ────────────────────────────────────────────────────
    'Premier Pas': BadgeInfo(
      name: 'Premier Pas', emoji: '👋', colorValue: 0xFF9CA3AF,
      rarity: BadgeRarity.commun,
      description: 'Bienvenue sur SCOLAR Connect !',
    ),
    'Curieux': BadgeInfo(
      name: 'Curieux', emoji: '🔍', colorValue: 0xFF6B7280,
      rarity: BadgeRarity.commun,
      description: 'Vous avez exploré votre profil.',
    ),
    'Explorateur': BadgeInfo(
      name: 'Explorateur', emoji: '🌟', colorValue: 0xFFD1D5DB,
      rarity: BadgeRarity.commun,
      description: 'Premier message envoyé.', xpRequired: 5,
    ),
    'Actif': BadgeInfo(
      name: 'Actif', emoji: '⚡', colorValue: 0xFF9CA3AF,
      rarity: BadgeRarity.commun,
      description: 'Connecté 3 jours de suite.', xpRequired: 15,
    ),
    // ── Rare ──────────────────────────────────────────────────────
    'Communicateur': BadgeInfo(
      name: 'Communicateur', emoji: '💬', colorValue: 0xFF2563EB,
      rarity: BadgeRarity.rare,
      description: '50 messages envoyés.', xpRequired: 100,
    ),
    'Connecté': BadgeInfo(
      name: 'Connecté', emoji: '🤝', colorValue: 0xFF3B82F6,
      rarity: BadgeRarity.rare,
      description: '10 connexions établies.', xpRequired: 150,
    ),
    'Partageur': BadgeInfo(
      name: 'Partageur', emoji: '📚', colorValue: 0xFF0D9488,
      rarity: BadgeRarity.rare,
      description: '5 fiches partagées.', xpRequired: 200,
    ),
    'Studieux': BadgeInfo(
      name: 'Studieux', emoji: '📖', colorValue: 0xFF16A34A,
      rarity: BadgeRarity.rare,
      description: '10 sessions de révision.', xpRequired: 250,
    ),
    // ── Épique ────────────────────────────────────────────────────
    'Leader': BadgeInfo(
      name: 'Leader', emoji: '🏆', colorValue: 0xFF6C47FF,
      rarity: BadgeRarity.epique,
      description: 'Créateur de 3 groupes actifs.', xpRequired: 500,
    ),
    'Persévérant': BadgeInfo(
      name: 'Persévérant', emoji: '🔥', colorValue: 0xFFDC2626,
      rarity: BadgeRarity.epique,
      description: 'Streak de 30 jours consécutifs.', xpRequired: 600,
    ),
    'Collaborateur': BadgeInfo(
      name: 'Collaborateur', emoji: '🧑‍🤝‍🧑', colorValue: 0xFF7C3AED,
      rarity: BadgeRarity.epique,
      description: 'Participation active dans 5 groupes.', xpRequired: 700,
    ),
    'Animateur': BadgeInfo(
      name: 'Animateur', emoji: '🎤', colorValue: 0xFFEC4899,
      rarity: BadgeRarity.epique,
      description: '100 messages dans les groupes.', xpRequired: 800,
    ),
    // ── Légendaire ────────────────────────────────────────────────
    'Expert': BadgeInfo(
      name: 'Expert', emoji: '🎓', colorValue: 0xFFF59E0B,
      rarity: BadgeRarity.legendaire,
      description: 'Niveau 20 atteint.', xpRequired: 2000,
    ),
    'Maître': BadgeInfo(
      name: 'Maître', emoji: '👑', colorValue: 0xFFD97706,
      rarity: BadgeRarity.legendaire,
      description: 'Tous les badges Épiques débloqués.', xpRequired: 3000,
    ),
    'Champion': BadgeInfo(
      name: 'Champion', emoji: '🥇', colorValue: 0xFFFBBF24,
      rarity: BadgeRarity.legendaire,
      description: 'Top 1 du classement hebdomadaire.', xpRequired: 4000,
    ),
    'Légende': BadgeInfo(
      name: 'Légende', emoji: '⭐', colorValue: 0xFFEF4444,
      rarity: BadgeRarity.legendaire,
      description: 'Niveau 50 atteint — statut ultime.', xpRequired: 5000,
    ),
  };

  /// Liste ordonnée : communs en premier, légendaires en dernier.
  static List<String> get allBadges => badgeCatalogue.keys.toList();

  /// Badges filtrés par rareté.
  static List<String> badgesByRarity(BadgeRarity rarity) => badgeCatalogue.entries
      .where((e) => e.value.rarity == rarity)
      .map((e) => e.key)
      .toList();

  /// Infos complètes d'un badge.
  static BadgeInfo? badgeInfo(String badge) => badgeCatalogue[badge];

  /// Emoji associé à chaque badge (rétrocompatible).
  static String badgeEmoji(String badge) =>
      badgeCatalogue[badge]?.emoji ?? '⭐';

  /// Couleur associée à chaque badge (rétrocompatible).
  static int badgeColorValue(String badge) =>
      badgeCatalogue[badge]?.colorValue ?? 0xFF6C47FF;

  /// Rareté d'un badge.
  static BadgeRarity badgeRarity(String badge) =>
      badgeCatalogue[badge]?.rarity ?? BadgeRarity.commun;
}
