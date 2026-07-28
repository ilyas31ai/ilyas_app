import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/support_ticket_model.dart';
import '../models/user_model.dart';

/// Statistiques globales de la plateforme SCOLAR AI Educative, tous
/// établissements confondus — alimente [EditeurDashboardPage].
class PlatformStats {
  final int totalEtablissements;
  final int totalEleves;
  final int totalProfesseurs;
  final int totalParents;
  final int totalDirections;
  final int totalUtilisateurs;
  final int actifsJour;
  final int actifsSemaine;
  final int actifsMois;

  const PlatformStats({
    this.totalEtablissements = 0,
    this.totalEleves = 0,
    this.totalProfesseurs = 0,
    this.totalParents = 0,
    this.totalDirections = 0,
    this.totalUtilisateurs = 0,
    this.actifsJour = 0,
    this.actifsSemaine = 0,
    this.actifsMois = 0,
  });
}

/// Répartition des demandes Support & Suggestions par type et par statut,
/// tous établissements confondus — alimente [EditeurStatistiquesPage].
class TicketStats {
  final int total;
  final int bugs;
  final int suggestions;
  final int questions;
  final int avis;
  final int nouveaux;
  final int enCours;
  final int resolus;

  const TicketStats({
    this.total = 0,
    this.bugs = 0,
    this.suggestions = 0,
    this.questions = 0,
    this.avis = 0,
    this.nouveaux = 0,
    this.enCours = 0,
    this.resolus = 0,
  });
}

/// Requêtes agrégées (compteurs) réservées à l'Espace Éditeur — voir
/// [EditeurAccessService] pour le contrôle d'accès. Utilise les requêtes
/// d'agrégation Firestore (`count()`) pour éviter de télécharger l'ensemble
/// des documents `users` sur une plateforme multi-établissements.
class EditeurStatsService {
  static final _db = FirebaseFirestore.instance;

  static Future<int> _count(Query query) async {
    final agg = await query.count().get();
    return agg.count ?? 0;
  }

  static Future<PlatformStats> chargerStats() async {
    final now = DateTime.now();
    final dayAgo = Timestamp.fromDate(now.subtract(const Duration(days: 1)));
    final weekAgo = Timestamp.fromDate(now.subtract(const Duration(days: 7)));
    final monthAgo = Timestamp.fromDate(now.subtract(const Duration(days: 30)));

    final users = _db.collection('users');

    final results = await Future.wait([
      _count(_db.collection('schools')),
      _count(users.where('role', isEqualTo: 'eleve')),
      _count(users.where('role', isEqualTo: 'professeur')),
      _count(users.where('role', isEqualTo: 'parent')),
      _count(users.where('role',
          whereIn: ['admin', 'direction', 'adminEtablissement'])),
      _count(users),
      _count(users.where('lastSeen', isGreaterThanOrEqualTo: dayAgo)),
      _count(users.where('lastSeen', isGreaterThanOrEqualTo: weekAgo)),
      _count(users.where('lastSeen', isGreaterThanOrEqualTo: monthAgo)),
    ]);

    return PlatformStats(
      totalEtablissements: results[0],
      totalEleves: results[1],
      totalProfesseurs: results[2],
      totalParents: results[3],
      totalDirections: results[4],
      totalUtilisateurs: results[5],
      actifsJour: results[6],
      actifsSemaine: results[7],
      actifsMois: results[8],
    );
  }

  /// Les [limit] derniers comptes créés, tous rôles et établissements
  /// confondus, du plus récent au plus ancien.
  static Future<List<UserModel>> inscriptionsRecentes({int limit = 10}) async {
    final snap = await _db
        .collection('users')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();
    return snap.docs.map(UserModel.fromDoc).toList();
  }

  /// Répartition des tickets Support & Suggestions par type et statut,
  /// calculée depuis la liste déjà chargée par [SupportService.ticketsStream]
  /// (pas de requête supplémentaire — le volume de tickets reste modeste).
  static TicketStats ticketStatsFrom(List<SupportTicketModel> tickets) {
    int bugs = 0, suggestions = 0, questions = 0, avis = 0;
    int nouveaux = 0, enCours = 0, resolus = 0;
    for (final t in tickets) {
      switch (t.type) {
        case SupportTicketType.bug:
          bugs++;
          break;
        case SupportTicketType.suggestion:
          suggestions++;
          break;
        case SupportTicketType.question:
          questions++;
          break;
        case SupportTicketType.avis:
          avis++;
          break;
      }
      switch (t.statut) {
        case SupportTicketStatut.nouveau:
          nouveaux++;
          break;
        case SupportTicketStatut.enCours:
          enCours++;
          break;
        case SupportTicketStatut.resolu:
          resolus++;
          break;
      }
    }
    return TicketStats(
      total: tickets.length,
      bugs: bugs,
      suggestions: suggestions,
      questions: questions,
      avis: avis,
      nouveaux: nouveaux,
      enCours: enCours,
      resolus: resolus,
    );
  }
}
