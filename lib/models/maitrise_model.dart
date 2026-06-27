import 'package:cloud_firestore/cloud_firestore.dart';

class MaitriseModel {
  final String notionId;
  final String label;
  final String matiere;
  final String categorie;
  final int score; // 0-100
  final int tentatives;
  final DateTime derniereEval;
  final List<String> erreurs;
  final List<Map<String, dynamic>> historiqueScores; // [{ts, score}, ...] max 10
  final String sourceType; // 'quiz_devoir' | 'quiz_libre' | 'exercice'
  final String sourceTitre;

  const MaitriseModel({
    required this.notionId,
    required this.label,
    required this.matiere,
    required this.categorie,
    required this.score,
    required this.tentatives,
    required this.derniereEval,
    required this.erreurs,
    required this.historiqueScores,
    required this.sourceType,
    required this.sourceTitre,
  });

  // ── Niveau calculé ──────────────────────────────────────────────────────────

  String get niveau {
    if (score >= 75) return 'maitrise';
    if (score >= 45) return 'en_cours';
    return 'a_retravailler';
  }

  String get niveauEmoji => switch (niveau) {
    'maitrise'       => '🟢',
    'en_cours'       => '🟡',
    _                => '🔴',
  };

  String get niveauLabel => switch (niveau) {
    'maitrise'       => 'Maîtrisé',
    'en_cours'       => 'En cours',
    _                => 'À retravailler',
  };

  // ── Firestore ───────────────────────────────────────────────────────────────

  factory MaitriseModel.fromFirestore(Map<String, dynamic> d) {
    DateTime ts(dynamic v) {
      if (v is Timestamp) return v.toDate();
      if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
      return DateTime.now();
    }
    return MaitriseModel(
      notionId        : d['notionId']   as String? ?? '',
      label           : d['label']      as String? ?? '',
      matiere         : d['matiere']    as String? ?? '',
      categorie       : d['categorie']  as String? ?? '',
      score           : (d['score']     as num?)?.toInt() ?? 0,
      tentatives      : (d['tentatives'] as num?)?.toInt() ?? 1,
      derniereEval    : ts(d['derniereEval']),
      erreurs         : List<String>.from(d['erreurs'] as List? ?? []),
      historiqueScores: List<Map<String, dynamic>>.from(d['historiqueScores'] as List? ?? []),
      sourceType      : d['sourceType']  as String? ?? '',
      sourceTitre     : d['sourceTitre'] as String? ?? '',
    );
  }

  Map<String, dynamic> toFirestore() => {
    'notionId'        : notionId,
    'label'           : label,
    'matiere'         : matiere,
    'categorie'       : categorie,
    'score'           : score,
    'tentatives'      : tentatives,
    'derniereEval'    : Timestamp.fromDate(derniereEval),
    'erreurs'         : erreurs,
    'historiqueScores': historiqueScores,
    'sourceType'      : sourceType,
    'sourceTitre'     : sourceTitre,
  };
}
