import 'package:cloud_firestore/cloud_firestore.dart';

/// Récapitulatif de fin de trimestre rédigé par le professeur principal.
///
/// Stocké dans /bulletins_recap/{classeId}_t{trim}_{anneeScol}.
/// Lecture : tout utilisateur auth. Écriture : prof principal uniquement.
class BulletinRecapModel {
  final String id;
  final String classeId;
  final String classeNom;
  final int trimestre;
  final int anneeScol;
  final String profPrincipalId;
  final String profPrincipalNom;

  /// Appréciation générale de la classe
  final String texteGeneral;

  /// Points forts collectifs
  final String pointsForts;

  /// Points à améliorer collectifs
  final String pointsAmeliorer;

  /// Objectifs pour le prochain trimestre
  final String objectifs;

  final Timestamp? dateRecap;
  final bool publie;

  const BulletinRecapModel({
    required this.id,
    required this.classeId,
    required this.classeNom,
    required this.trimestre,
    required this.anneeScol,
    required this.profPrincipalId,
    required this.profPrincipalNom,
    this.texteGeneral = '',
    this.pointsForts = '',
    this.pointsAmeliorer = '',
    this.objectifs = '',
    this.dateRecap,
    this.publie = false,
  });

  static String docId({
    required String classeId,
    required int trimestre,
    required int anneeScol,
  }) =>
      '${classeId}_t${trimestre}_$anneeScol';

  factory BulletinRecapModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return BulletinRecapModel(
      id: doc.id,
      classeId: d['classeId'] as String? ?? '',
      classeNom: d['classeNom'] as String? ?? '',
      trimestre: (d['trimestre'] as num?)?.toInt() ?? 1,
      anneeScol: (d['anneeScol'] as num?)?.toInt() ?? DateTime.now().year,
      profPrincipalId: d['profPrincipalId'] as String? ?? '',
      profPrincipalNom: d['profPrincipalNom'] as String? ?? '',
      texteGeneral: d['texteGeneral'] as String? ?? '',
      pointsForts: d['pointsForts'] as String? ?? '',
      pointsAmeliorer: d['pointsAmeliorer'] as String? ?? '',
      objectifs: d['objectifs'] as String? ?? '',
      dateRecap: d['dateRecap'] as Timestamp?,
      publie: d['publie'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
        'classeId': classeId,
        'classeNom': classeNom,
        'trimestre': trimestre,
        'anneeScol': anneeScol,
        'profPrincipalId': profPrincipalId,
        'profPrincipalNom': profPrincipalNom,
        'texteGeneral': texteGeneral,
        'pointsForts': pointsForts,
        'pointsAmeliorer': pointsAmeliorer,
        'objectifs': objectifs,
        'dateRecap': FieldValue.serverTimestamp(),
        'publie': publie,
      };
}
