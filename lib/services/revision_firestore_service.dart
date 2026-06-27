import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Persiste les sessions de révision et la progression par matière dans Firestore.
///
/// Collection : `revision_sessions/{uid}/sessions/{docId}`
/// Document   : `revision_stats/{uid}` (compteurs cumulatifs)
class RevisionFirestoreService {
  static final _db  = FirebaseFirestore.instance;
  static String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  // ── Sessions ───────────────────────────────────────────────────────────────

  /// Enregistre une session de révision (cours généré, quiz, fiche, flashcards…).
  static Future<void> saveSession({
    required String matiere,
    required String categorie,
    required String type, // 'cours' | 'fiche' | 'flashcards' | 'quiz' | 'exercices' | 'bac' | 'grand_oral' | 'partiel'
    int? score,           // score quiz : 0-100
    int? nbCards,         // nb flashcards vues
    String? contenu,      // résumé court (max 200 chars)
  }) async {
    if (_uid.isEmpty) return;
    try {
      final batch = _db.batch();

      // 1. Ajoute une session
      final sessionRef = _db
          .collection('revision_sessions')
          .doc(_uid)
          .collection('sessions')
          .doc();
      batch.set(sessionRef, {
        'matiere'  : matiere,
        'categorie': categorie,
        'type'     : type,
        'score'    : score,
        'nbCards'  : nbCards,
        'contenu'  : contenu?.substring(0, contenu.length > 200 ? 200 : contenu.length),
        'date'     : FieldValue.serverTimestamp(),
      });

      // 2. Met à jour les compteurs dans revision_stats
      final statsRef = _db.collection('revision_stats').doc(_uid);
      final Map<String, dynamic> stats = {
        'totalSessions'  : FieldValue.increment(1),
        'lastActivity'   : FieldValue.serverTimestamp(),
        'categorie'      : categorie,
      };
      if (score != null) {
        stats['totalQuiz'] = FieldValue.increment(1);
        stats['sumScores'] = FieldValue.increment(score);
      }
      if (type == 'fiche') stats['totalFiches'] = FieldValue.increment(1);
      if (type == 'flashcards') stats['totalFlashcards'] = FieldValue.increment(nbCards ?? 1);

      // Progression par matière
      final mKey = matiere.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_');
      stats['matieres.$mKey.sessions'] = FieldValue.increment(1);
      if (score != null) {
        stats['matieres.$mKey.lastScore'] = score;
        stats['matieres.$mKey.sumScores'] = FieldValue.increment(score);
        stats['matieres.$mKey.nbQuiz']    = FieldValue.increment(1);
      }

      batch.set(statsRef, stats, SetOptions(merge: true));
      await batch.commit();
    } catch (e) {
      debugPrint('[RevisionFirestoreService] saveSession error: $e');
    }
  }

  // ── Stats globales ─────────────────────────────────────────────────────────

  static Stream<Map<String, dynamic>> statsStream() {
    if (_uid.isEmpty) return const Stream.empty();
    return _db
        .collection('revision_stats')
        .doc(_uid)
        .snapshots()
        .map((s) => s.data() ?? {});
  }

  // ── Historique des sessions ────────────────────────────────────────────────

  static Stream<List<Map<String, dynamic>>> historyStream({int limit = 20}) {
    if (_uid.isEmpty) return const Stream.empty();
    return _db
        .collection('revision_sessions')
        .doc(_uid)
        .collection('sessions')
        .orderBy('date', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => <String, dynamic>{'id': d.id, ...d.data()})
            .toList());
  }

  // ── Progression par matière ────────────────────────────────────────────────

  static Future<Map<String, Map<String, dynamic>>> progressionParMatiere() async {
    if (_uid.isEmpty) return {};
    try {
      final snap = await _db.collection('revision_stats').doc(_uid).get();
      if (!snap.exists) return {};
      final data = snap.data() ?? {};
      final matieres = data['matieres'] as Map<String, dynamic>? ?? {};
      return matieres.map((k, v) =>
          MapEntry(k, Map<String, dynamic>.from(v as Map)));
    } catch (e) {
      debugPrint('[RevisionFirestoreService] progressionParMatiere error: $e');
      return {};
    }
  }

  // ── Temps de révision cumulé (en minutes) ─────────────────────────────────

  static Future<void> addTempsRevision(int minutes) async {
    if (_uid.isEmpty || minutes <= 0) return;
    try {
      await _db.collection('revision_stats').doc(_uid).set(
        {'tempsTotal': FieldValue.increment(minutes), 'lastActivity': FieldValue.serverTimestamp()},
        SetOptions(merge: true),
      );
    } catch (e) {
      debugPrint('[RevisionFirestoreService] addTempsRevision error: $e');
    }
  }
}
