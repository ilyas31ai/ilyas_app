import 'package:cloud_firestore/cloud_firestore.dart';

import 'school_model.dart';

/// Statut de publication d'un bulletin par la Direction.
///
/// Collection Firestore : `bulletin_validations`
/// ID du document : `{classeId}_{trimestre}_{anneeScol}`
///
/// Source unique — élève et parent lisent le même enregistrement.
/// Quand `publie == true`, les bulletins de cette classe/trimestre
/// sont considérés comme validés et disponibles en consultation.
class BulletinValidationModel {
  final String id;
  final String schoolId;
  final String classeId;
  final String classeNom;
  final int trimestre;
  final int anneeScol;
  final bool publie;
  final Timestamp? datePub;
  final String? directionUid;
  final String? directionNom;
  final String? note; // commentaire optionnel de la direction

  const BulletinValidationModel({
    required this.id,
    this.schoolId = kDefaultSchoolId,
    required this.classeId,
    required this.classeNom,
    required this.trimestre,
    required this.anneeScol,
    required this.publie,
    this.datePub,
    this.directionUid,
    this.directionNom,
    this.note,
  });

  /// ID prédictible pour upsert idempotent.
  static String docId({
    required String classeId,
    required int trimestre,
    required int anneeScol,
  }) =>
      '${classeId}_t${trimestre}_$anneeScol';

  factory BulletinValidationModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return BulletinValidationModel(
      id: doc.id,
      schoolId: d['schoolId'] as String? ?? kDefaultSchoolId,
      classeId: d['classeId'] as String? ?? '',
      classeNom: d['classeNom'] as String? ?? '',
      trimestre: (d['trimestre'] as num?)?.toInt() ?? 1,
      anneeScol: (d['anneeScol'] as num?)?.toInt() ?? DateTime.now().year,
      publie: d['publie'] as bool? ?? false,
      datePub: d['datePub'] as Timestamp?,
      directionUid: d['directionUid'] as String?,
      directionNom: d['directionNom'] as String?,
      note: d['note'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'schoolId': schoolId,
        'classeId': classeId,
        'classeNom': classeNom,
        'trimestre': trimestre,
        'anneeScol': anneeScol,
        'publie': publie,
        'datePub': publie ? FieldValue.serverTimestamp() : null,
        'directionUid': directionUid,
        'directionNom': directionNom,
        'note': note,
        'updatedAt': FieldValue.serverTimestamp(),
      };
}
