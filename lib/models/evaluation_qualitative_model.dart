import 'package:cloud_firestore/cloud_firestore.dart';

import 'school_model.dart';

/// Domaine d'apprentissage Maternelle (collection `domainesApprentissage`) :
/// Langage oral, Langage écrit, Découverte des nombres, Découverte du monde,
/// Activités artistiques, Activités physiques, Motricité, Vie collective,
/// Autonomie, Développement personnel.
class DomaineApprentissageModel {
  final String id;
  final String schoolId;
  final String nom;

  const DomaineApprentissageModel({
    required this.id,
    this.schoolId = kDefaultSchoolId,
    required this.nom,
  });

  factory DomaineApprentissageModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return DomaineApprentissageModel(
      id: doc.id,
      schoolId: d['schoolId'] as String? ?? kDefaultSchoolId,
      nom: d['nom'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() => {'schoolId': schoolId, 'nom': nom};
}

/// Niveau de maîtrise qualitatif Maternelle — remplace les notes chiffrées
/// pour ce cycle (collection `evaluationsQualitatives`).
enum NiveauQualitatif { acquis, enCoursAcquisition, nonAcquis }

extension NiveauQualitatifX on NiveauQualitatif {
  String get label {
    switch (this) {
      case NiveauQualitatif.acquis:
        return 'Acquis';
      case NiveauQualitatif.enCoursAcquisition:
        return "En cours d'acquisition";
      case NiveauQualitatif.nonAcquis:
        return 'Non acquis';
    }
  }

  String get value {
    switch (this) {
      case NiveauQualitatif.acquis:
        return 'acquis';
      case NiveauQualitatif.enCoursAcquisition:
        return 'en_cours_acquisition';
      case NiveauQualitatif.nonAcquis:
        return 'non_acquis';
    }
  }

  static NiveauQualitatif fromString(String? s) {
    switch (s) {
      case 'acquis':
        return NiveauQualitatif.acquis;
      case 'non_acquis':
        return NiveauQualitatif.nonAcquis;
      default:
        return NiveauQualitatif.enCoursAcquisition;
    }
  }
}

class EvaluationQualitativeModel {
  final String id;
  final String schoolId;
  final String eleveId;
  final String domaineId;
  final NiveauQualitatif niveau;
  final String observations;
  final DateTime date;

  const EvaluationQualitativeModel({
    required this.id,
    this.schoolId = kDefaultSchoolId,
    required this.eleveId,
    required this.domaineId,
    required this.niveau,
    this.observations = '',
    required this.date,
  });

  factory EvaluationQualitativeModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return EvaluationQualitativeModel(
      id: doc.id,
      schoolId: d['schoolId'] as String? ?? kDefaultSchoolId,
      eleveId: d['eleveId'] as String? ?? '',
      domaineId: d['domaineId'] as String? ?? '',
      niveau: NiveauQualitatifX.fromString(d['niveau'] as String?),
      observations: d['observations'] as String? ?? '',
      date: (d['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'schoolId': schoolId,
        'eleveId': eleveId,
        'domaineId': domaineId,
        'niveau': niveau.value,
        'observations': observations,
        'date': Timestamp.fromDate(date),
      };
}
