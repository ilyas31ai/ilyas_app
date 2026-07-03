import 'package:cloud_firestore/cloud_firestore.dart';

import 'school_model.dart';

/// Appréciation textuelle d'un professeur pour un élève,
/// pour une matière donnée sur un trimestre donné.
///
/// Collection Firestore : `appreciations`
/// ID du document : `{professeurId}_{eleveId}_{classeId}_{trimestre}_{anneeScol}`
/// Ce format prévisible permet un upsert idempotent via `set(merge: true)`.
class AppreciationModel {
  final String id;
  final String schoolId;
  final String professeurId;
  final String professeurNom;
  final String eleveId;
  final String eleveNom;
  final String elevePrenom;
  final String classeId;
  final String classeNom;
  final String matiere;
  final int trimestre;
  final int anneeScol;
  final String texte;
  final Timestamp createdAt;
  final Timestamp? updatedAt;

  const AppreciationModel({
    required this.id,
    this.schoolId = kDefaultSchoolId,
    required this.professeurId,
    this.professeurNom = '',
    required this.eleveId,
    required this.eleveNom,
    required this.elevePrenom,
    required this.classeId,
    required this.classeNom,
    required this.matiere,
    required this.trimestre,
    required this.anneeScol,
    required this.texte,
    required this.createdAt,
    this.updatedAt,
  });

  String get eleveNomComplet => '$elevePrenom $eleveNom'.trim();

  /// ID prédictible pour upsert idempotent.
  static String docId({
    required String professeurId,
    required String eleveId,
    required String classeId,
    required int trimestre,
    required int anneeScol,
  }) =>
      '${professeurId}_${eleveId}_${classeId}_t${trimestre}_$anneeScol';

  factory AppreciationModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return AppreciationModel(
      id: doc.id,
      schoolId: d['schoolId'] as String? ?? kDefaultSchoolId,
      professeurId: d['professeurId'] as String? ?? '',
      professeurNom: d['professeurNom'] as String? ?? '',
      eleveId: d['eleveId'] as String? ?? '',
      eleveNom: d['eleveNom'] as String? ?? '',
      elevePrenom: d['elevePrenom'] as String? ?? '',
      classeId: d['classeId'] as String? ?? '',
      classeNom: d['classeNom'] as String? ?? '',
      matiere: d['matiere'] as String? ?? '',
      trimestre: (d['trimestre'] as num?)?.toInt() ?? 1,
      anneeScol: (d['anneeScol'] as num?)?.toInt() ?? DateTime.now().year,
      texte: d['texte'] as String? ?? '',
      createdAt:
          (d['createdAt'] as Timestamp?) ?? Timestamp.now(),
      updatedAt: d['updatedAt'] as Timestamp?,
    );
  }

  Map<String, dynamic> toMap() => {
        'schoolId': schoolId,
        'professeurId': professeurId,
        'professeurNom': professeurNom,
        'eleveId': eleveId,
        'eleveNom': eleveNom,
        'elevePrenom': elevePrenom,
        'classeId': classeId,
        'classeNom': classeNom,
        'matiere': matiere,
        'trimestre': trimestre,
        'anneeScol': anneeScol,
        'texte': texte,
        'updatedAt': FieldValue.serverTimestamp(),
      };
}
