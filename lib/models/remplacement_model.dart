import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

// Firestore collection: remplacements/{id}

enum RemplacementStatut {
  enAttente,
  propose,
  accepte,
  refuse,
  confirme,
  termine,
  annule,
}

extension RemplacementStatutExt on RemplacementStatut {
  String get value {
    switch (this) {
      case RemplacementStatut.enAttente:
        return 'enAttente';
      case RemplacementStatut.propose:
        return 'propose';
      case RemplacementStatut.accepte:
        return 'accepte';
      case RemplacementStatut.refuse:
        return 'refuse';
      case RemplacementStatut.confirme:
        return 'confirme';
      case RemplacementStatut.termine:
        return 'termine';
      case RemplacementStatut.annule:
        return 'annule';
    }
  }

  static RemplacementStatut fromString(String? s) {
    switch (s) {
      case 'propose':
        return RemplacementStatut.propose;
      case 'accepte':
        return RemplacementStatut.accepte;
      case 'refuse':
        return RemplacementStatut.refuse;
      case 'confirme':
        return RemplacementStatut.confirme;
      case 'termine':
        return RemplacementStatut.termine;
      case 'annule':
        return RemplacementStatut.annule;
      default:
        return RemplacementStatut.enAttente;
    }
  }
}

class Remplacement {
  final String id;
  final String professeurAbsentUid;
  final String professeurAbsentNom;
  final String? professeurRemplacantUid;
  final String? professeurRemplacantNom;
  final String matiere;
  final String classeId;
  final String classeNom;
  final String niveau;
  final String cycle;
  final String motif; // 'maladie', 'formation', 'conge', 'autre'
  final String date; // ISO8601 date string 'YYYY-MM-DD'
  final String heureDebut;
  final String heureFin;
  final RemplacementStatut statut;
  final String? commentaire;
  final String? valideParUid;
  final String? valideParNom;
  final Timestamp createdAt;
  final Timestamp? updatedAt;

  const Remplacement({
    required this.id,
    required this.professeurAbsentUid,
    required this.professeurAbsentNom,
    this.professeurRemplacantUid,
    this.professeurRemplacantNom,
    required this.matiere,
    required this.classeId,
    required this.classeNom,
    required this.niveau,
    required this.cycle,
    required this.motif,
    required this.date,
    required this.heureDebut,
    required this.heureFin,
    required this.statut,
    this.commentaire,
    this.valideParUid,
    this.valideParNom,
    required this.createdAt,
    this.updatedAt,
  });

  factory Remplacement.fromFirestore(DocumentSnapshot doc) {
    final m = doc.data() as Map<String, dynamic>? ?? {};
    return Remplacement(
      id: doc.id,
      professeurAbsentUid: (m['professeurAbsentUid'] as String?) ?? '',
      professeurAbsentNom: (m['professeurAbsentNom'] as String?) ?? '',
      professeurRemplacantUid: m['professeurRemplacantUid'] as String?,
      professeurRemplacantNom: m['professeurRemplacantNom'] as String?,
      matiere: (m['matiere'] as String?) ?? '',
      classeId: (m['classeId'] as String?) ?? '',
      classeNom: (m['classeNom'] as String?) ?? '',
      niveau: (m['niveau'] as String?) ?? '',
      cycle: (m['cycle'] as String?) ?? '',
      motif: (m['motif'] as String?) ?? 'autre',
      date: (m['date'] as String?) ?? '',
      heureDebut: (m['heureDebut'] as String?) ?? '',
      heureFin: (m['heureFin'] as String?) ?? '',
      statut: RemplacementStatutExt.fromString(m['statut'] as String?),
      commentaire: m['commentaire'] as String?,
      valideParUid: m['valideParUid'] as String?,
      valideParNom: m['valideParNom'] as String?,
      createdAt: (m['createdAt'] as Timestamp?) ?? Timestamp.now(),
      updatedAt: m['updatedAt'] as Timestamp?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'professeurAbsentUid': professeurAbsentUid,
      'professeurAbsentNom': professeurAbsentNom,
      if (professeurRemplacantUid != null)
        'professeurRemplacantUid': professeurRemplacantUid,
      if (professeurRemplacantNom != null)
        'professeurRemplacantNom': professeurRemplacantNom,
      'matiere': matiere,
      'classeId': classeId,
      'classeNom': classeNom,
      'niveau': niveau,
      'cycle': cycle,
      'motif': motif,
      'date': date,
      'heureDebut': heureDebut,
      'heureFin': heureFin,
      'statut': statut.value,
      if (commentaire != null) 'commentaire': commentaire,
      if (valideParUid != null) 'valideParUid': valideParUid,
      if (valideParNom != null) 'valideParNom': valideParNom,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  String get statutLabel {
    switch (statut) {
      case RemplacementStatut.enAttente:
        return 'En attente';
      case RemplacementStatut.propose:
        return 'Proposé';
      case RemplacementStatut.accepte:
        return 'Accepté';
      case RemplacementStatut.refuse:
        return 'Refusé';
      case RemplacementStatut.confirme:
        return 'Confirmé';
      case RemplacementStatut.termine:
        return 'Terminé';
      case RemplacementStatut.annule:
        return 'Annulé';
    }
  }

  Color get statutColor {
    switch (statut) {
      case RemplacementStatut.enAttente:
        return const Color(0xFFF59E0B);
      case RemplacementStatut.propose:
        return const Color(0xFF2563EB);
      case RemplacementStatut.accepte:
        return const Color(0xFF10B981);
      case RemplacementStatut.refuse:
        return const Color(0xFFEF4444);
      case RemplacementStatut.confirme:
        return const Color(0xFF10B981);
      case RemplacementStatut.termine:
        return const Color(0xFF6B7280);
      case RemplacementStatut.annule:
        return const Color(0xFF6B7280);
    }
  }

  String get motifLabel {
    switch (motif) {
      case 'maladie':
        return 'Maladie';
      case 'formation':
        return 'Formation';
      case 'conge':
        return 'Congé';
      default:
        return 'Autre';
    }
  }
}
