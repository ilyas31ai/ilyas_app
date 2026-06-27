import 'package:cloud_firestore/cloud_firestore.dart';

import 'school_model.dart';

/// Module Université — traité comme une entité parallèle à [ClasseModel],
/// pas une extension forcée du modèle classe (décision d'architecture déjà
/// actée, `02_RAPPORT_ARCHITECTURE_COMPLET.md` §13.2). Préparation de
/// structure uniquement : aucun service, aucun écran, aucune collection
/// Firestore créée à ce stade.

class FormationModel {
  final String id;
  final String schoolId;
  final String nom;
  final String niveau; // 'licence' | 'master' | 'doctorat'
  final List<String> parcours;

  const FormationModel({
    required this.id,
    this.schoolId = kDefaultSchoolId,
    required this.nom,
    this.niveau = 'licence',
    this.parcours = const [],
  });

  factory FormationModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return FormationModel(
      id: doc.id,
      schoolId: d['schoolId'] as String? ?? kDefaultSchoolId,
      nom: d['nom'] as String? ?? '',
      niveau: d['niveau'] as String? ?? 'licence',
      parcours: List<String>.from(d['parcours'] as List? ?? []),
    );
  }

  Map<String, dynamic> toMap() => {
        'schoolId': schoolId,
        'nom': nom,
        'niveau': niveau,
        'parcours': parcours,
      };
}

class UniteEnseignementModel {
  final String id;
  final String schoolId;
  final String code;
  final String nom;
  final double creditsEcts;
  final String formationId;
  final String semestre;

  const UniteEnseignementModel({
    required this.id,
    this.schoolId = kDefaultSchoolId,
    required this.code,
    required this.nom,
    this.creditsEcts = 0,
    required this.formationId,
    this.semestre = '',
  });

  factory UniteEnseignementModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return UniteEnseignementModel(
      id: doc.id,
      schoolId: d['schoolId'] as String? ?? kDefaultSchoolId,
      code: d['code'] as String? ?? '',
      nom: d['nom'] as String? ?? '',
      creditsEcts: (d['creditsEcts'] as num?)?.toDouble() ?? 0,
      formationId: d['formationId'] as String? ?? '',
      semestre: d['semestre'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
        'schoolId': schoolId,
        'code': code,
        'nom': nom,
        'creditsEcts': creditsEcts,
        'formationId': formationId,
        'semestre': semestre,
      };
}

class SemestreModel {
  final String id;
  final String schoolId;
  final String nom;
  final String formationId;
  final DateTime? dateDebut;
  final DateTime? dateFin;

  const SemestreModel({
    required this.id,
    this.schoolId = kDefaultSchoolId,
    required this.nom,
    required this.formationId,
    this.dateDebut,
    this.dateFin,
  });

  factory SemestreModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return SemestreModel(
      id: doc.id,
      schoolId: d['schoolId'] as String? ?? kDefaultSchoolId,
      nom: d['nom'] as String? ?? '',
      formationId: d['formationId'] as String? ?? '',
      dateDebut: (d['dateDebut'] as Timestamp?)?.toDate(),
      dateFin: (d['dateFin'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
        'schoolId': schoolId,
        'nom': nom,
        'formationId': formationId,
        if (dateDebut != null) 'dateDebut': Timestamp.fromDate(dateDebut!),
        if (dateFin != null) 'dateFin': Timestamp.fromDate(dateFin!),
      };
}

class InscriptionPedagogiqueModel {
  final String id;
  final String schoolId;
  final String etudiantId;
  final String formationId;
  final List<String> ueIds;
  final String anneeUniversitaire;

  const InscriptionPedagogiqueModel({
    required this.id,
    this.schoolId = kDefaultSchoolId,
    required this.etudiantId,
    required this.formationId,
    this.ueIds = const [],
    this.anneeUniversitaire = '',
  });

  factory InscriptionPedagogiqueModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return InscriptionPedagogiqueModel(
      id: doc.id,
      schoolId: d['schoolId'] as String? ?? kDefaultSchoolId,
      etudiantId: d['etudiantId'] as String? ?? '',
      formationId: d['formationId'] as String? ?? '',
      ueIds: List<String>.from(d['ueIds'] as List? ?? []),
      anneeUniversitaire: d['anneeUniversitaire'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
        'schoolId': schoolId,
        'etudiantId': etudiantId,
        'formationId': formationId,
        'ueIds': ueIds,
        'anneeUniversitaire': anneeUniversitaire,
      };
}

class StageModel {
  final String id;
  final String schoolId;
  final String etudiantId;
  final String entreprise;
  final DateTime? dateDebut;
  final DateTime? dateFin;
  final String tuteurId;
  final String rapportUrl;

  const StageModel({
    required this.id,
    this.schoolId = kDefaultSchoolId,
    required this.etudiantId,
    this.entreprise = '',
    this.dateDebut,
    this.dateFin,
    this.tuteurId = '',
    this.rapportUrl = '',
  });

  factory StageModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return StageModel(
      id: doc.id,
      schoolId: d['schoolId'] as String? ?? kDefaultSchoolId,
      etudiantId: d['etudiantId'] as String? ?? '',
      entreprise: d['entreprise'] as String? ?? '',
      dateDebut: (d['dateDebut'] as Timestamp?)?.toDate(),
      dateFin: (d['dateFin'] as Timestamp?)?.toDate(),
      tuteurId: d['tuteurId'] as String? ?? '',
      rapportUrl: d['rapportUrl'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
        'schoolId': schoolId,
        'etudiantId': etudiantId,
        'entreprise': entreprise,
        if (dateDebut != null) 'dateDebut': Timestamp.fromDate(dateDebut!),
        if (dateFin != null) 'dateFin': Timestamp.fromDate(dateFin!),
        'tuteurId': tuteurId,
        'rapportUrl': rapportUrl,
      };
}

class ExamenModel {
  final String id;
  final String schoolId;
  final String ueId;
  final DateTime date;
  final String type; // 'partiel' | 'final' | 'rattrapage'

  const ExamenModel({
    required this.id,
    this.schoolId = kDefaultSchoolId,
    required this.ueId,
    required this.date,
    this.type = 'final',
  });

  factory ExamenModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return ExamenModel(
      id: doc.id,
      schoolId: d['schoolId'] as String? ?? kDefaultSchoolId,
      ueId: d['ueId'] as String? ?? '',
      date: (d['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      type: d['type'] as String? ?? 'final',
    );
  }

  Map<String, dynamic> toMap() => {
        'schoolId': schoolId,
        'ueId': ueId,
        'date': Timestamp.fromDate(date),
        'type': type,
      };
}

class RattrapageModel {
  final String id;
  final String schoolId;
  final String examenId;
  final String etudiantId;
  final double? note;

  const RattrapageModel({
    required this.id,
    this.schoolId = kDefaultSchoolId,
    required this.examenId,
    required this.etudiantId,
    this.note,
  });

  factory RattrapageModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return RattrapageModel(
      id: doc.id,
      schoolId: d['schoolId'] as String? ?? kDefaultSchoolId,
      examenId: d['examenId'] as String? ?? '',
      etudiantId: d['etudiantId'] as String? ?? '',
      note: (d['note'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toMap() => {
        'schoolId': schoolId,
        'examenId': examenId,
        'etudiantId': etudiantId,
        if (note != null) 'note': note,
      };
}

class MemoireModel {
  final String id;
  final String schoolId;
  final String etudiantId;
  final String titre;
  final String directeurId;
  final String documentUrl;
  final String statut;

  const MemoireModel({
    required this.id,
    this.schoolId = kDefaultSchoolId,
    required this.etudiantId,
    this.titre = '',
    this.directeurId = '',
    this.documentUrl = '',
    this.statut = 'en_cours',
  });

  factory MemoireModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return MemoireModel(
      id: doc.id,
      schoolId: d['schoolId'] as String? ?? kDefaultSchoolId,
      etudiantId: d['etudiantId'] as String? ?? '',
      titre: d['titre'] as String? ?? '',
      directeurId: d['directeurId'] as String? ?? '',
      documentUrl: d['documentUrl'] as String? ?? '',
      statut: d['statut'] as String? ?? 'en_cours',
    );
  }

  Map<String, dynamic> toMap() => {
        'schoolId': schoolId,
        'etudiantId': etudiantId,
        'titre': titre,
        'directeurId': directeurId,
        'documentUrl': documentUrl,
        'statut': statut,
      };
}

class SoutenanceModel {
  final String id;
  final String schoolId;
  final String memoireId;
  final DateTime date;
  final List<String> jury;
  final double? noteFinale;

  const SoutenanceModel({
    required this.id,
    this.schoolId = kDefaultSchoolId,
    required this.memoireId,
    required this.date,
    this.jury = const [],
    this.noteFinale,
  });

  factory SoutenanceModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return SoutenanceModel(
      id: doc.id,
      schoolId: d['schoolId'] as String? ?? kDefaultSchoolId,
      memoireId: d['memoireId'] as String? ?? '',
      date: (d['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      jury: List<String>.from(d['jury'] as List? ?? []),
      noteFinale: (d['noteFinale'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toMap() => {
        'schoolId': schoolId,
        'memoireId': memoireId,
        'date': Timestamp.fromDate(date),
        'jury': jury,
        if (noteFinale != null) 'noteFinale': noteFinale,
      };
}
