import 'package:cloud_firestore/cloud_firestore.dart';

import 'school_model.dart';

/// Bulletin scolaire (collection `bulletins`), généré à partir des
/// documents `notes` existants — pas de double saisie.
class BulletinModel {
  final String id;
  final String schoolId;
  final String eleveId;
  final String periode;
  final double moyenneGenerale;
  final List<String> notesIds;
  final String statut; // 'brouillon' | 'publie'

  const BulletinModel({
    required this.id,
    this.schoolId = kDefaultSchoolId,
    required this.eleveId,
    required this.periode,
    this.moyenneGenerale = 0,
    this.notesIds = const [],
    this.statut = 'brouillon',
  });

  factory BulletinModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return BulletinModel(
      id: doc.id,
      schoolId: d['schoolId'] as String? ?? kDefaultSchoolId,
      eleveId: d['eleveId'] as String? ?? '',
      periode: d['periode'] as String? ?? '',
      moyenneGenerale: (d['moyenneGenerale'] as num?)?.toDouble() ?? 0,
      notesIds: List<String>.from(d['notesIds'] as List? ?? []),
      statut: d['statut'] as String? ?? 'brouillon',
    );
  }

  Map<String, dynamic> toMap() => {
        'schoolId': schoolId,
        'eleveId': eleveId,
        'periode': periode,
        'moyenneGenerale': moyenneGenerale,
        'notesIds': notesIds,
        'statut': statut,
      };
}

/// Compétence évaluée (collection `competences`), Primaire/Collège.
class CompetenceModel {
  final String id;
  final String schoolId;
  final String eleveId;
  final String matiereId;
  final String libelle;
  final String niveauMaitrise;

  const CompetenceModel({
    required this.id,
    this.schoolId = kDefaultSchoolId,
    required this.eleveId,
    required this.matiereId,
    required this.libelle,
    this.niveauMaitrise = '',
  });

  factory CompetenceModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return CompetenceModel(
      id: doc.id,
      schoolId: d['schoolId'] as String? ?? kDefaultSchoolId,
      eleveId: d['eleveId'] as String? ?? '',
      matiereId: d['matiereId'] as String? ?? '',
      libelle: d['libelle'] as String? ?? '',
      niveauMaitrise: d['niveauMaitrise'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
        'schoolId': schoolId,
        'eleveId': eleveId,
        'matiereId': matiereId,
        'libelle': libelle,
        'niveauMaitrise': niveauMaitrise,
      };
}

/// Orientation Collège (Brevet) / Lycée (Parcoursup) — collection `orientations`.
class OrientationModel {
  final String id;
  final String schoolId;
  final String eleveId;
  final String cycleCible;
  final List<String> voeux;
  final String avisDirection;

  const OrientationModel({
    required this.id,
    this.schoolId = kDefaultSchoolId,
    required this.eleveId,
    this.cycleCible = '',
    this.voeux = const [],
    this.avisDirection = '',
  });

  factory OrientationModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return OrientationModel(
      id: doc.id,
      schoolId: d['schoolId'] as String? ?? kDefaultSchoolId,
      eleveId: d['eleveId'] as String? ?? '',
      cycleCible: d['cycleCible'] as String? ?? '',
      voeux: List<String>.from(d['voeux'] as List? ?? []),
      avisDirection: d['avisDirection'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
        'schoolId': schoolId,
        'eleveId': eleveId,
        'cycleCible': cycleCible,
        'voeux': voeux,
        'avisDirection': avisDirection,
      };
}
