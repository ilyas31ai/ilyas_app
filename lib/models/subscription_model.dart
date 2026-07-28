import 'package:cloud_firestore/cloud_firestore.dart';

/// Structure préparatoire pour la gestion future des abonnements et
/// paiements des établissements (Espace Éditeur) — non branchée à une UI
/// pour l'instant. Un document par établissement, id = schoolId, collection
/// `subscriptions` (voir firestore.rules : lecture/écriture réservées à
/// [EditeurAccessService.isAuthorized]).
enum SubscriptionPlan { gratuit, standard, premium }

extension SubscriptionPlanX on SubscriptionPlan {
  String get label {
    switch (this) {
      case SubscriptionPlan.gratuit:
        return 'Gratuit';
      case SubscriptionPlan.standard:
        return 'Standard';
      case SubscriptionPlan.premium:
        return 'Premium';
    }
  }

  String get value {
    switch (this) {
      case SubscriptionPlan.gratuit:
        return 'gratuit';
      case SubscriptionPlan.standard:
        return 'standard';
      case SubscriptionPlan.premium:
        return 'premium';
    }
  }

  static SubscriptionPlan fromString(String? s) {
    switch (s) {
      case 'standard':
        return SubscriptionPlan.standard;
      case 'premium':
        return SubscriptionPlan.premium;
      default:
        return SubscriptionPlan.gratuit;
    }
  }
}

enum SubscriptionStatut { actif, expire, suspendu }

extension SubscriptionStatutX on SubscriptionStatut {
  String get value {
    switch (this) {
      case SubscriptionStatut.actif:
        return 'actif';
      case SubscriptionStatut.expire:
        return 'expire';
      case SubscriptionStatut.suspendu:
        return 'suspendu';
    }
  }

  static SubscriptionStatut fromString(String? s) {
    switch (s) {
      case 'expire':
        return SubscriptionStatut.expire;
      case 'suspendu':
        return SubscriptionStatut.suspendu;
      default:
        return SubscriptionStatut.actif;
    }
  }
}

class SubscriptionModel {
  final String schoolId;
  final SubscriptionPlan plan;
  final SubscriptionStatut statut;
  final Timestamp? dateDebut;
  final Timestamp? dateFin;
  final Timestamp? updatedAt;

  const SubscriptionModel({
    required this.schoolId,
    this.plan = SubscriptionPlan.gratuit,
    this.statut = SubscriptionStatut.actif,
    this.dateDebut,
    this.dateFin,
    this.updatedAt,
  });

  factory SubscriptionModel.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return SubscriptionModel(
      schoolId: doc.id,
      plan: SubscriptionPlanX.fromString(d['plan'] as String?),
      statut: SubscriptionStatutX.fromString(d['statut'] as String?),
      dateDebut: d['dateDebut'] as Timestamp?,
      dateFin: d['dateFin'] as Timestamp?,
      updatedAt: d['updatedAt'] as Timestamp?,
    );
  }

  Map<String, dynamic> toMap() => {
        'plan': plan.value,
        'statut': statut.value,
        if (dateDebut != null) 'dateDebut': dateDebut,
        if (dateFin != null) 'dateFin': dateFin,
        'updatedAt': FieldValue.serverTimestamp(),
      };
}
