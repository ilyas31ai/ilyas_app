import 'package:cloud_firestore/cloud_firestore.dart';

import 'school_model.dart';

enum RdvStatut {
  demande,
  accepte,
  refuse,
  proposeAutreDate,
  confirme,
  annule,
  reporte,
  termine,
}

extension RdvStatutX on RdvStatut {
  String get value {
    switch (this) {
      case RdvStatut.demande:
        return 'demande';
      case RdvStatut.accepte:
        return 'accepte';
      case RdvStatut.refuse:
        return 'refuse';
      case RdvStatut.proposeAutreDate:
        return 'propose_autre_date';
      case RdvStatut.confirme:
        return 'confirme';
      case RdvStatut.annule:
        return 'annule';
      case RdvStatut.reporte:
        return 'reporte';
      case RdvStatut.termine:
        return 'termine';
    }
  }

  String get label {
    switch (this) {
      case RdvStatut.demande:
        return 'En attente';
      case RdvStatut.accepte:
        return 'Accepté';
      case RdvStatut.refuse:
        return 'Refusé';
      case RdvStatut.proposeAutreDate:
        return 'Autre date proposée';
      case RdvStatut.confirme:
        return 'Confirmé';
      case RdvStatut.annule:
        return 'Annulé';
      case RdvStatut.reporte:
        return 'Reporté';
      case RdvStatut.termine:
        return 'Terminé';
    }
  }

  static RdvStatut fromString(String? s) {
    switch (s) {
      case 'accepte':
        return RdvStatut.accepte;
      case 'refuse':
        return RdvStatut.refuse;
      case 'propose_autre_date':
        return RdvStatut.proposeAutreDate;
      case 'confirme':
        return RdvStatut.confirme;
      case 'annule':
        return RdvStatut.annule;
      case 'reporte':
        return RdvStatut.reporte;
      case 'termine':
        return RdvStatut.termine;
      default:
        return RdvStatut.demande;
    }
  }
}

class RdvModel {
  final String id;
  final String schoolId;
  final String parentUid;
  final String parentNom;
  final String professeurId;
  final String professeurNom;
  final String classeNom;
  final String eleveUid;
  final String eleveNom;
  final DateTime dateHeure;
  final int dureeMinutes;
  final String motif;
  final RdvStatut statut;
  final String notesParent;
  final String notesProfesseur;
  final DateTime? contrePropositionDate;
  final Timestamp? createdAt;
  final Timestamp? updatedAt;

  const RdvModel({
    required this.id,
    this.schoolId = kDefaultSchoolId,
    required this.parentUid,
    required this.parentNom,
    required this.professeurId,
    required this.professeurNom,
    required this.classeNom,
    required this.eleveUid,
    required this.eleveNom,
    required this.dateHeure,
    required this.dureeMinutes,
    required this.motif,
    required this.statut,
    this.notesParent = '',
    this.notesProfesseur = '',
    this.contrePropositionDate,
    this.createdAt,
    this.updatedAt,
  });

  factory RdvModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return RdvModel(
      id: doc.id,
      schoolId: d['schoolId'] as String? ?? kDefaultSchoolId,
      parentUid: d['parentUid'] as String? ?? '',
      parentNom: d['parentNom'] as String? ?? '',
      professeurId: d['professeurId'] as String? ?? '',
      professeurNom: d['professeurNom'] as String? ?? '',
      classeNom: d['classeNom'] as String? ?? '',
      eleveUid: d['eleveUid'] as String? ?? '',
      eleveNom: d['eleveNom'] as String? ?? '',
      dateHeure: (d['dateHeure'] as Timestamp?)?.toDate() ?? DateTime.now(),
      dureeMinutes: (d['dureeMinutes'] as num?)?.toInt() ?? 30,
      motif: d['motif'] as String? ?? '',
      statut: RdvStatutX.fromString(d['statut'] as String?),
      notesParent: d['notesParent'] as String? ?? '',
      notesProfesseur: d['notesProfesseur'] as String? ?? '',
      contrePropositionDate:
          (d['contrePropositionDate'] as Timestamp?)?.toDate(),
      createdAt: d['createdAt'] as Timestamp?,
      updatedAt: d['updatedAt'] as Timestamp?,
    );
  }

  Map<String, dynamic> toMap() => {
        'schoolId': schoolId,
        'parentUid': parentUid,
        'parentNom': parentNom,
        'professeurId': professeurId,
        'professeurNom': professeurNom,
        'classeNom': classeNom,
        'eleveUid': eleveUid,
        'eleveNom': eleveNom,
        'dateHeure': dateHeure,
        'dureeMinutes': dureeMinutes,
        'motif': motif,
        'statut': statut.value,
        if (notesParent.isNotEmpty) 'notesParent': notesParent,
        if (notesProfesseur.isNotEmpty) 'notesProfesseur': notesProfesseur,
        if (contrePropositionDate != null)
          'contrePropositionDate': contrePropositionDate,
      };
}
