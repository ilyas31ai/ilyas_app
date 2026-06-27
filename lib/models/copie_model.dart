import 'package:cloud_firestore/cloud_firestore.dart';

import 'school_model.dart';

enum CopieStatut { brouillon, soumis, corrige }

extension CopieStatutX on CopieStatut {
  String get value => const {
        CopieStatut.brouillon: 'brouillon',
        CopieStatut.soumis: 'soumis',
        CopieStatut.corrige: 'corrige',
      }[this]!;

  String get label => const {
        CopieStatut.brouillon: 'Brouillon',
        CopieStatut.soumis: 'Soumis',
        CopieStatut.corrige: 'Corrigé',
      }[this]!;

  static CopieStatut fromString(String? s) {
    switch (s) {
      case 'soumis':
        return CopieStatut.soumis;
      case 'corrige':
        return CopieStatut.corrige;
      default:
        return CopieStatut.brouillon;
    }
  }
}

/// Student's interactive submission for a devoir with questions.
class CopieModel {
  final String id;
  final String schoolId;
  final String devoirId;
  final String eleveId;
  final String eleveNom;
  final String classeId;
  final String professeurId;
  final CopieStatut statut;
  final DateTime dateDebut;
  final DateTime? dateSoumission;
  // { questionId: { 'valeur': dynamic, 'photoUrl': String? } }
  final Map<String, dynamic> reponses;
  final double? note;
  final double? noteSur;
  final String? commentaire;
  // { questionId: { 'note': double, 'ok': bool, 'commentaire': String } }
  final Map<String, dynamic> corrections;

  const CopieModel({
    required this.id,
    this.schoolId = kDefaultSchoolId,
    required this.devoirId,
    required this.eleveId,
    required this.eleveNom,
    required this.classeId,
    required this.professeurId,
    required this.statut,
    required this.dateDebut,
    this.dateSoumission,
    this.reponses = const {},
    this.note,
    this.noteSur,
    this.commentaire,
    this.corrections = const {},
  });

  factory CopieModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return CopieModel(
      id: doc.id,
      schoolId: d['schoolId'] as String? ?? kDefaultSchoolId,
      devoirId: d['devoirId'] as String? ?? '',
      eleveId: d['eleveId'] as String? ?? '',
      eleveNom: d['eleveNom'] as String? ?? '',
      classeId: d['classeId'] as String? ?? '',
      professeurId: d['professeurId'] as String? ?? '',
      statut: CopieStatutX.fromString(d['statut'] as String?),
      dateDebut: (d['dateDebut'] as Timestamp?)?.toDate() ?? DateTime.now(),
      dateSoumission: (d['dateSoumission'] as Timestamp?)?.toDate(),
      reponses: Map<String, dynamic>.from(d['reponses'] as Map? ?? {}),
      note: (d['note'] as num?)?.toDouble(),
      noteSur: (d['noteSur'] as num?)?.toDouble(),
      commentaire: d['commentaire'] as String?,
      corrections: Map<String, dynamic>.from(d['corrections'] as Map? ?? {}),
    );
  }

  Map<String, dynamic> toMap() => {
        'schoolId': schoolId,
        'devoirId': devoirId,
        'eleveId': eleveId,
        'eleveNom': eleveNom,
        'classeId': classeId,
        'professeurId': professeurId,
        'statut': statut.value,
        'dateDebut': Timestamp.fromDate(dateDebut),
        if (dateSoumission != null)
          'dateSoumission': Timestamp.fromDate(dateSoumission!),
        'reponses': reponses,
        if (note != null) 'note': note,
        if (noteSur != null) 'noteSur': noteSur,
        if (commentaire != null) 'commentaire': commentaire,
        'corrections': corrections,
      };
}
