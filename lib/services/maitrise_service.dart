import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/maitrise_model.dart';

/// Firestore path : users/{uid}/maitrise/{notionId}
class MaitriseService {
  static final _db = FirebaseFirestore.instance;

  static String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  static CollectionReference<Map<String, dynamic>>? _col(String uid) =>
      _db.collection('users').doc(uid).collection('maitrise');

  // ── Lecture ─────────────────────────────────────────────────────────────────

  /// Stream de toutes les notions de l'élève, triées par date décroissante.
  static Stream<List<MaitriseModel>> stream() {
    final uid = _uid;
    if (uid == null) return Stream.value([]);
    return _db
        .collection('users')
        .doc(uid)
        .collection('maitrise')
        .orderBy('derniereEval', descending: true)
        .snapshots()
        .map((s) => s.docs
            .map((d) => MaitriseModel.fromFirestore(d.data()))
            .toList());
  }

  // ── Écriture ────────────────────────────────────────────────────────────────

  /// Enregistre une liste de notions évaluées en Firestore.
  /// Chaque notion est upsertée avec un score pondéré (70 % nouveau, 30 % ancien).
  static Future<void> enregistrer({
    required List<Map<String, dynamic>> notions, // [{id, label, score, erreurs}]
    required String matiere,
    required String categorie,
    required String sourceType,
    required String sourceTitre,
  }) async {
    final uid = _uid;
    if (uid == null || notions.isEmpty) return;

    final col = _col(uid)!;
    final now = DateTime.now();

    for (final n in notions) {
      try {
        final notionId = (n['id'] as String?)?.trim() ?? '';
        if (notionId.isEmpty) continue;

        final newScore = (n['score'] as num?)?.toInt().clamp(0, 100) ?? 0;
        final newErreurs = List<String>.from(n['erreurs'] as List? ?? []);

        final ref = col.doc(notionId);
        final existing = await ref.get();

        int finalScore = newScore;
        int tentatives = 1;
        List<Map<String, dynamic>> historique = [
          {'ts': now.toIso8601String(), 'score': newScore}
        ];

        if (existing.exists) {
          final d = existing.data()!;
          final oldScore = (d['score'] as num?)?.toInt() ?? newScore;
          finalScore = ((newScore * 0.7) + (oldScore * 0.3)).round().clamp(0, 100);
          tentatives = ((d['tentatives'] as num?)?.toInt() ?? 0) + 1;

          final prev = List<Map<String, dynamic>>.from(
              d['historiqueScores'] as List? ?? []);
          prev.add({'ts': now.toIso8601String(), 'score': newScore});
          if (prev.length > 10) { historique = prev.sublist(prev.length - 10); }
          else { historique = prev; }
        }

        await ref.set({
          'notionId'        : notionId,
          'label'           : (n['label'] as String?)?.trim() ?? notionId,
          'matiere'         : matiere,
          'categorie'       : categorie,
          'score'           : finalScore,
          'tentatives'      : tentatives,
          'derniereEval'    : Timestamp.fromDate(now),
          'erreurs'         : newErreurs.take(5).toList(),
          'historiqueScores': historique,
          'sourceType'      : sourceType,
          'sourceTitre'     : sourceTitre,
        });
      } catch (e) {
        debugPrint('[MaitriseService] enregistrer erreur notion ${n['id']}: $e');
      }
    }
    await _updateSummary(uid);
  }

  // ── Résumé agrégé (pour lecture côté professeur) ─────────────────────────

  /// Relit toutes les notions de l'élève et écrit un résumé plat dans
  /// `users/{uid}` (merge). Utilisé par les vues professeur.
  static Future<void> _updateSummary(String uid) async {
    try {
      final snap = await _db
          .collection('users')
          .doc(uid)
          .collection('maitrise')
          .get();
      if (snap.docs.isEmpty) return;

      final notions = snap.docs
          .map((d) => MaitriseModel.fromFirestore(d.data()))
          .toList();

      final Map<String, Map<String, dynamic>> parMatiere = {};
      int totalMaitrise = 0, totalEnCours = 0, totalARetrav = 0;

      for (final n in notions) {
        final m = parMatiere.putIfAbsent(n.matiere, () => {
          'total': 0, 'maitrise': 0, 'enCours': 0, 'aRetravailler': 0, 'alertes': <String>[],
        });
        m['total'] = (m['total'] as int) + 1;
        if (n.score >= 75) {
          m['maitrise'] = (m['maitrise'] as int) + 1;
          totalMaitrise++;
        } else if (n.score >= 45) {
          m['enCours'] = (m['enCours'] as int) + 1;
          totalEnCours++;
        } else {
          m['aRetravailler'] = (m['aRetravailler'] as int) + 1;
          totalARetrav++;
          final al = m['alertes'] as List<String>;
          if (al.length < 5) al.add('${n.label} (${n.score}/100)');
        }
      }

      final total = notions.length;
      final pct   = total == 0 ? 0 : (totalMaitrise * 100 ~/ total);

      await _db.collection('users').doc(uid).set({
        'maitrise_summary': {
          'updatedAt' : Timestamp.now(),
          'totaux': {
            'total'         : total,
            'maitrise'      : totalMaitrise,
            'enCours'       : totalEnCours,
            'aRetravailler' : totalARetrav,
            'pct'           : pct,
          },
          'parMatiere': parMatiere,
        },
        'maitrise_en_difficulte': totalARetrav > 0,
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('[MaitriseService] _updateSummary erreur: $e');
    }
  }

  /// Lit le résumé de maîtrise d'un élève depuis `users/{uid}.maitrise_summary`.
  /// Retourne `{}` si l'élève n'a pas encore de données IA.
  static Future<Map<String, dynamic>> summaryForUser(String uid) async {
    try {
      final doc = await _db.collection('users').doc(uid).get();
      if (!doc.exists) return {};
      return (doc.data()?['maitrise_summary'] as Map<String, dynamic>?) ?? {};
    } catch (e) {
      debugPrint('[MaitriseService] summaryForUser erreur: $e');
      return {};
    }
  }

  // ── Contexte adaptatif pour l'IA ────────────────────────────────────────────

  /// Retourne une chaîne à injecter dans les prompts IA pour adapter le contenu
  /// aux difficultés connues de l'élève dans une matière donnée.
  static Future<String> contexteAdaptatif(String matiere) async {
    final uid = _uid;
    if (uid == null) return '';
    try {
      final snap = await _db
          .collection('users')
          .doc(uid)
          .collection('maitrise')
          .where('matiere', isEqualTo: matiere)
          .get();

      if (snap.docs.isEmpty) return '';

      final notions = snap.docs
          .map((d) => MaitriseModel.fromFirestore(d.data()))
          .toList();

      final difficult = notions.where((n) => n.score < 45).toList();
      final enCours   = notions.where((n) => n.score >= 45 && n.score < 75).toList();

      if (difficult.isEmpty && enCours.isEmpty) return '';

      final sb = StringBuffer('\n\n--- SUIVI PÉDAGOGIQUE (données élève) ---\n');
      if (difficult.isNotEmpty) {
        sb.writeln('🔴 Notions à retravailler en priorité :');
        for (final n in difficult) {
          sb.write('  • ${n.label} (score: ${n.score}/100)');
          if (n.erreurs.isNotEmpty) sb.write(' — erreur récurrente: ${n.erreurs.first}');
          sb.writeln();
        }
      }
      if (enCours.isNotEmpty) {
        sb.writeln('🟡 Notions en cours d\'acquisition :');
        for (final n in enCours) {
          sb.writeln('  • ${n.label} (score: ${n.score}/100)');
        }
      }
      sb.writeln('→ Insiste particulièrement sur ces notions.\n-----------------------------------------');
      return sb.toString();
    } catch (e) {
      debugPrint('[MaitriseService] contexteAdaptatif erreur: $e');
      return '';
    }
  }
}
