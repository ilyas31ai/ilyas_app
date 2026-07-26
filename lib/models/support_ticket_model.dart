import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Type de demande envoyée via le module Support & Suggestions.
enum SupportTicketType { bug, suggestion, question, avis }

extension SupportTicketTypeX on SupportTicketType {
  String get label {
    switch (this) {
      case SupportTicketType.bug:
        return 'Bug';
      case SupportTicketType.suggestion:
        return 'Suggestion';
      case SupportTicketType.question:
        return 'Question';
      case SupportTicketType.avis:
        return 'Avis';
    }
  }

  String get value {
    switch (this) {
      case SupportTicketType.bug:
        return 'bug';
      case SupportTicketType.suggestion:
        return 'suggestion';
      case SupportTicketType.question:
        return 'question';
      case SupportTicketType.avis:
        return 'avis';
    }
  }

  IconData get icon {
    switch (this) {
      case SupportTicketType.bug:
        return Icons.bug_report_outlined;
      case SupportTicketType.suggestion:
        return Icons.lightbulb_outline;
      case SupportTicketType.question:
        return Icons.help_outline;
      case SupportTicketType.avis:
        return Icons.star_outline;
    }
  }

  Color get color {
    switch (this) {
      case SupportTicketType.bug:
        return const Color(0xFFDC2626);
      case SupportTicketType.suggestion:
        return const Color(0xFF16A34A);
      case SupportTicketType.question:
        return const Color(0xFF2563EB);
      case SupportTicketType.avis:
        return const Color(0xFFD97706);
    }
  }

  static SupportTicketType fromString(String? s) {
    switch (s) {
      case 'suggestion':
        return SupportTicketType.suggestion;
      case 'question':
        return SupportTicketType.question;
      case 'avis':
        return SupportTicketType.avis;
      default:
        return SupportTicketType.bug;
    }
  }
}

/// Statut de traitement d'une demande, suivi par la Direction.
enum SupportTicketStatut { nouveau, enCours, resolu }

extension SupportTicketStatutX on SupportTicketStatut {
  String get label {
    switch (this) {
      case SupportTicketStatut.nouveau:
        return 'Nouveau';
      case SupportTicketStatut.enCours:
        return 'En cours';
      case SupportTicketStatut.resolu:
        return 'Résolu';
    }
  }

  String get value {
    switch (this) {
      case SupportTicketStatut.nouveau:
        return 'nouveau';
      case SupportTicketStatut.enCours:
        return 'en_cours';
      case SupportTicketStatut.resolu:
        return 'resolu';
    }
  }

  Color get color {
    switch (this) {
      case SupportTicketStatut.nouveau:
        return const Color(0xFFD97706);
      case SupportTicketStatut.enCours:
        return const Color(0xFF2563EB);
      case SupportTicketStatut.resolu:
        return const Color(0xFF16A34A);
    }
  }

  static SupportTicketStatut fromString(String? s) {
    switch (s) {
      case 'en_cours':
        return SupportTicketStatut.enCours;
      case 'resolu':
        return SupportTicketStatut.resolu;
      default:
        return SupportTicketStatut.nouveau;
    }
  }
}

/// Demande envoyée par un utilisateur (bug, suggestion, question, avis),
/// enregistrée dans Firestore (`support_tickets`) et traitée par la
/// Direction depuis [DirectionSupportPage].
///
/// Les champs `reponse*` sont écrits par [SupportTicketModel.toMap] /
/// [SupportService] mais ne sont pour l'instant renseignés par aucune UI —
/// ils préparent la structure pour une future fonctionnalité de réponse
/// directe à l'utilisateur, sans qu'aucune migration de données soit
/// nécessaire le jour où cette UI sera ajoutée.
class SupportTicketModel {
  final String id;

  // Auteur (dénormalisé à la création — évite les lectures N+1 depuis le
  // tableau de bord Direction, et reste stable même si le profil change).
  final String userId;
  final String userName;
  final String userEmail;
  final String userRole;
  final String? etablissementNom;

  final SupportTicketType type;
  final String sujet;
  final String description;
  final String? screenshotUrl;
  final SupportTicketStatut statut;

  // Contexte technique — aide au diagnostic des bugs.
  final String appVersion;
  final String deviceInfo;

  final Timestamp? createdAt;
  final Timestamp? updatedAt;

  // Préparé pour la réponse directe (non exposé en UI aujourd'hui).
  final String? reponse;
  final Timestamp? reponseAt;
  final String? reponseParNom;

  const SupportTicketModel({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userEmail,
    required this.userRole,
    this.etablissementNom,
    required this.type,
    required this.sujet,
    required this.description,
    this.screenshotUrl,
    this.statut = SupportTicketStatut.nouveau,
    this.appVersion = '',
    this.deviceInfo = '',
    this.createdAt,
    this.updatedAt,
    this.reponse,
    this.reponseAt,
    this.reponseParNom,
  });

  factory SupportTicketModel.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return SupportTicketModel(
      id: doc.id,
      userId: d['userId'] as String? ?? '',
      userName: d['userName'] as String? ?? '',
      userEmail: d['userEmail'] as String? ?? '',
      userRole: d['userRole'] as String? ?? '',
      etablissementNom: d['etablissementNom'] as String?,
      type: SupportTicketTypeX.fromString(d['type'] as String?),
      sujet: d['sujet'] as String? ?? '',
      description: d['description'] as String? ?? '',
      screenshotUrl: d['screenshotUrl'] as String?,
      statut: SupportTicketStatutX.fromString(d['statut'] as String?),
      appVersion: d['appVersion'] as String? ?? '',
      deviceInfo: d['deviceInfo'] as String? ?? '',
      createdAt: d['createdAt'] as Timestamp?,
      updatedAt: d['updatedAt'] as Timestamp?,
      reponse: d['reponse'] as String?,
      reponseAt: d['reponseAt'] as Timestamp?,
      reponseParNom: d['reponseParNom'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'userId': userId,
        'userName': userName,
        'userEmail': userEmail,
        'userRole': userRole,
        if (etablissementNom != null) 'etablissementNom': etablissementNom,
        'type': type.value,
        'sujet': sujet,
        'description': description,
        if (screenshotUrl != null) 'screenshotUrl': screenshotUrl,
        'statut': statut.value,
        'appVersion': appVersion,
        'deviceInfo': deviceInfo,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
}
