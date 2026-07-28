import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../models/support_ticket_model.dart';
import '../services/editeur_stats_service.dart';
import '../services/support_service.dart';

const _kBg = Color(0xFF0D1117);
const _kCard = Color(0xFF161B22);
const _kBorder = Color(0x1AFFFFFF);
const _kBlue = Color(0xFF2563EB);

/// Statistiques générales de la plateforme (Espace Éditeur) : volume et
/// répartition des demandes Support & Suggestions, tous établissements
/// confondus. Calculées côté client depuis [SupportService.ticketsStream] —
/// voir [EditeurStatsService.ticketStatsFrom].
class EditeurStatistiquesPage extends StatelessWidget {
  const EditeurStatistiquesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kCard,
        elevation: 0,
        title: const Text('Statistiques',
            style: TextStyle(
                color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        child: StreamBuilder<List<SupportTicketModel>>(
          stream: SupportService.ticketsStream(),
          builder: (context, snap) {
            if (snap.hasError) {
              return Center(
                child: Text('Erreur de chargement :\n${snap.error}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red, fontSize: 12)),
              );
            }
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(
                  child: CircularProgressIndicator(color: _kBlue));
            }
            final stats =
                EditeurStatsService.ticketStatsFrom(snap.data ?? []);
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
              children: [
                _sectionLabel('Vue d\'ensemble'),
                const SizedBox(height: 10),
                _totalCard(stats.total),
                const SizedBox(height: 24),
                _sectionLabel('Répartition par type'),
                const SizedBox(height: 10),
                if (stats.total == 0)
                  _emptyCard('Aucune demande enregistrée pour le moment.')
                else ...[
                  _typeChart(stats),
                  const SizedBox(height: 12),
                  _typeLegend(stats),
                ],
                const SizedBox(height: 24),
                _sectionLabel('Répartition par statut'),
                const SizedBox(height: 10),
                if (stats.total == 0)
                  _emptyCard('Aucune demande enregistrée pour le moment.')
                else
                  _statutBars(stats),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _emptyCard(String text) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _kCard,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(text,
            style: const TextStyle(color: Colors.white38, fontSize: 13)),
      );

  Widget _totalCard(int total) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2563EB), Color(0xFF0891B2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.confirmation_number_outlined,
              color: Colors.white, size: 30),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$total',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold)),
              const Text('Demandes reçues au total',
                  style: TextStyle(color: Colors.white70, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _typeChart(TicketStats stats) {
    final entries = [
      (SupportTicketType.bug.color, stats.bugs.toDouble()),
      (SupportTicketType.suggestion.color, stats.suggestions.toDouble()),
      (SupportTicketType.question.color, stats.questions.toDouble()),
      (SupportTicketType.avis.color, stats.avis.toDouble()),
    ];
    return Container(
      height: 180,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kBorder),
      ),
      child: PieChart(
        PieChartData(
          sectionsSpace: 2,
          centerSpaceRadius: 36,
          sections: [
            for (final e in entries)
              if (e.$2 > 0)
                PieChartSectionData(
                  value: e.$2,
                  color: e.$1,
                  radius: 46,
                  title: e.$2.toInt().toString(),
                  titleStyle: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold),
                ),
          ],
        ),
      ),
    );
  }

  Widget _typeLegend(TicketStats stats) {
    final rows = [
      (SupportTicketType.bug.label, SupportTicketType.bug.color, stats.bugs),
      (SupportTicketType.suggestion.label, SupportTicketType.suggestion.color,
          stats.suggestions),
      (SupportTicketType.question.label, SupportTicketType.question.color,
          stats.questions),
      (SupportTicketType.avis.label, SupportTicketType.avis.color, stats.avis),
    ];
    return Wrap(
      spacing: 14,
      runSpacing: 8,
      children: [
        for (final r in rows)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: r.$2, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Text('${r.$1} · ${r.$3}',
                  style: const TextStyle(color: Colors.white70, fontSize: 12)),
            ],
          ),
      ],
    );
  }

  Widget _statutBars(TicketStats stats) {
    final rows = [
      (SupportTicketStatut.nouveau.label, SupportTicketStatut.nouveau.color,
          stats.nouveaux),
      (SupportTicketStatut.enCours.label, SupportTicketStatut.enCours.color,
          stats.enCours),
      (SupportTicketStatut.resolu.label, SupportTicketStatut.resolu.color,
          stats.resolus),
    ];
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kBorder),
      ),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            Row(
              children: [
                SizedBox(
                    width: 90,
                    child: Text(rows[i].$1,
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12))),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: stats.total > 0 ? rows[i].$3 / stats.total : 0,
                      backgroundColor: Colors.white.withValues(alpha: 0.06),
                      color: rows[i].$2,
                      minHeight: 10,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                    width: 28,
                    child: Text('${rows[i].$3}',
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 12))),
              ],
            ),
            if (i != rows.length - 1) const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) => Text(
        text.toUpperCase(),
        style: const TextStyle(
            color: Colors.white38,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2),
      );
}
