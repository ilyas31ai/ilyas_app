import 'package:flutter/material.dart';

import '../models/remplacement_model.dart';
import '../services/remplacement_service.dart';

class DirectionStatsRemplacementsPage extends StatefulWidget {
  const DirectionStatsRemplacementsPage({super.key});

  @override
  State<DirectionStatsRemplacementsPage> createState() =>
      _DirectionStatsRemplacementsPageState();
}

class _DirectionStatsRemplacementsPageState
    extends State<DirectionStatsRemplacementsPage> {
  _PeriodFilter _period = _PeriodFilter.mois;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        elevation: 0,
        title: const Text(
          'Statistiques des remplacements',
          style: TextStyle(
              color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          // Period selector chips
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              children: _PeriodFilter.values.map((f) {
                final active = _period == f;
                return GestureDetector(
                  onTap: () => setState(() => _period = f),
                  child: Container(
                    margin: const EdgeInsets.only(right: 6),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 4),
                    decoration: BoxDecoration(
                      color: active
                          ? const Color(0xFFD97706)
                          : const Color(0xFF161B22),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: active
                              ? const Color(0xFFD97706)
                              : Colors.white12),
                    ),
                    child: Text(f.label,
                        style: TextStyle(
                            color: active ? Colors.white : Colors.white54,
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                  ),
                );
              }).toList(),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Remplacement>>(
              stream: RemplacementService.remplacementsStream(),
              builder: (ctx, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child: CircularProgressIndicator(
                          color: Color(0xFFD97706)));
                }
                if (snap.hasError) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Erreur de chargement des statistiques.\nVérifiez votre connexion.',
                        style: TextStyle(color: Colors.white54),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                final allRemplacements = snap.data ?? [];
                final filtered = _filterByPeriod(allRemplacements, _period);
                final stats = _computeStats(filtered);
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // KPI cards
                      Row(
                        children: [
                          Expanded(
                            child: _KpiCard(
                              label: 'Total',
                              value: '${stats.total}',
                              icon: Icons.swap_horiz,
                              color: const Color(0xFF2563EB),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _KpiCard(
                              label: 'Taux acceptation',
                              value:
                                  '${stats.tauxAcceptation.toStringAsFixed(0)}%',
                              icon: Icons.trending_up,
                              color: const Color(0xFF10B981),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _KpiCard(
                              label: 'En attente',
                              value: '${stats.enAttente}',
                              icon: Icons.hourglass_empty,
                              color: const Color(0xFFF59E0B),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Remplacements par statut
                      _SectionLabel(text: 'Répartition par statut'),
                      const SizedBox(height: 10),
                      _BarChart(
                        items: [
                          _BarItem(
                            label: 'En attente',
                            count: stats.enAttente,
                            total: stats.total,
                            color: const Color(0xFFF59E0B),
                          ),
                          _BarItem(
                            label: 'Proposé',
                            count: stats.propose,
                            total: stats.total,
                            color: const Color(0xFF2563EB),
                          ),
                          _BarItem(
                            label: 'Accepté',
                            count: stats.accepte,
                            total: stats.total,
                            color: const Color(0xFF10B981),
                          ),
                          _BarItem(
                            label: 'Refusé',
                            count: stats.refuse,
                            total: stats.total,
                            color: const Color(0xFFEF4444),
                          ),
                          _BarItem(
                            label: 'Confirmé',
                            count: stats.confirme,
                            total: stats.total,
                            color: const Color(0xFF059669),
                          ),
                          _BarItem(
                            label: 'Terminé',
                            count: stats.termine,
                            total: stats.total,
                            color: const Color(0xFF6B7280),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Enseignants les plus sollicités
                      _SectionLabel(text: 'Enseignants les plus sollicités'),
                      const SizedBox(height: 10),
                      _TopEnseignants(remplacements: filtered),
                      const SizedBox(height: 20),

                      // Absences par motif
                      _SectionLabel(text: 'Absences par motif'),
                      const SizedBox(height: 10),
                      _MotifChart(
                        maladie: stats.maladie,
                        formation: stats.formation,
                        conge: stats.conge,
                        autre: stats.autre,
                        total: stats.total,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  List<Remplacement> _filterByPeriod(
      List<Remplacement> all, _PeriodFilter period) {
    final now = DateTime.now();
    return all.where((r) {
      try {
        final parts = r.date.split('-');
        if (parts.length < 3) {
          return false;
        }
        final d = DateTime(
            int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
        switch (period) {
          case _PeriodFilter.semaine:
            final start = now.subtract(Duration(days: now.weekday - 1));
            final end = start.add(const Duration(days: 7));
            return d.isAfter(start.subtract(const Duration(days: 1))) &&
                d.isBefore(end);
          case _PeriodFilter.mois:
            return d.year == now.year && d.month == now.month;
          case _PeriodFilter.annee:
            return d.year == now.year;
        }
      } catch (_) {
        return false;
      }
    }).toList();
  }

  _StatsData _computeStats(List<Remplacement> list) {
    int enAttente = 0, propose = 0, accepte = 0, refuse = 0, confirme = 0,
        termine = 0;
    int maladie = 0, formation = 0, conge = 0, autre = 0;

    for (final r in list) {
      switch (r.statut) {
        case RemplacementStatut.enAttente:
          enAttente++;
          break;
        case RemplacementStatut.propose:
          propose++;
          break;
        case RemplacementStatut.accepte:
          accepte++;
          break;
        case RemplacementStatut.refuse:
          refuse++;
          break;
        case RemplacementStatut.confirme:
          confirme++;
          break;
        case RemplacementStatut.termine:
          termine++;
          break;
        case RemplacementStatut.annule:
          break;
      }
      switch (r.motif) {
        case 'maladie':
          maladie++;
          break;
        case 'formation':
          formation++;
          break;
        case 'conge':
          conge++;
          break;
        default:
          autre++;
      }
    }

    final total = list.length;
    final resolved = accepte + confirme + termine;
    final tauxAcceptation =
        total > 0 ? (resolved / total * 100) : 0.0;

    return _StatsData(
      total: total,
      enAttente: enAttente,
      propose: propose,
      accepte: accepte,
      refuse: refuse,
      confirme: confirme,
      termine: termine,
      maladie: maladie,
      formation: formation,
      conge: conge,
      autre: autre,
      tauxAcceptation: tauxAcceptation,
    );
  }
}

enum _PeriodFilter {
  semaine,
  mois,
  annee;

  String get label {
    switch (this) {
      case _PeriodFilter.semaine:
        return 'Cette semaine';
      case _PeriodFilter.mois:
        return 'Ce mois';
      case _PeriodFilter.annee:
        return 'Cette année';
    }
  }
}

class _StatsData {
  final int total;
  final int enAttente;
  final int propose;
  final int accepte;
  final int refuse;
  final int confirme;
  final int termine;
  final int maladie;
  final int formation;
  final int conge;
  final int autre;
  final double tauxAcceptation;

  const _StatsData({
    required this.total,
    required this.enAttente,
    required this.propose,
    required this.accepte,
    required this.refuse,
    required this.confirme,
    required this.termine,
    required this.maladie,
    required this.formation,
    required this.conge,
    required this.autre,
    required this.tauxAcceptation,
  });
}

class _KpiCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _KpiCard(
      {required this.label,
      required this.value,
      required this.icon,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold)),
          Text(label,
              style: const TextStyle(color: Colors.white38, fontSize: 10)),
        ],
      ),
    );
  }
}

class _BarItem {
  final String label;
  final int count;
  final int total;
  final Color color;
  const _BarItem(
      {required this.label,
      required this.count,
      required this.total,
      required this.color});
  double get ratio => total > 0 ? count / total : 0;
}

class _BarChart extends StatelessWidget {
  final List<_BarItem> items;
  const _BarChart({required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        children: items.map((item) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  SizedBox(
                    width: 70,
                    child: Text(item.label,
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 11)),
                  ),
                  Expanded(
                    child: LinearProgressIndicator(
                      value: item.ratio,
                      backgroundColor:
                          Colors.white.withValues(alpha: 0.06),
                      valueColor:
                          AlwaysStoppedAnimation<Color>(item.color),
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 28,
                    child: Text('${item.count}',
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 11)),
                  ),
                ],
              ),
            ],
          ),
        )).toList(),
      ),
    );
  }
}

class _TopEnseignants extends StatelessWidget {
  final List<Remplacement> remplacements;
  const _TopEnseignants({required this.remplacements});

  @override
  Widget build(BuildContext context) {
    // Count replacements per absent teacher
    final countMap = <String, int>{};
    final nameMap = <String, String>{};
    for (final r in remplacements) {
      final uid = r.professeurAbsentUid;
      countMap[uid] = (countMap[uid] ?? 0) + 1;
      nameMap[uid] = r.professeurAbsentNom;
    }

    final sorted = countMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top5 = sorted.take(5).toList();

    if (top5.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF161B22),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: Text('Aucune donnée',
              style: TextStyle(color: Colors.white38, fontSize: 13)),
        ),
      );
    }

    const rankColors = [
      Color(0xFFFFD700),
      Color(0xFFC0C0C0),
      Color(0xFFCD7F32),
      Colors.white38,
      Colors.white24,
    ];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        children: top5.asMap().entries.map((e) {
          final rank = e.key + 1;
          final uid = e.value.key;
          final count = e.value.value;
          final name = nameMap[uid] ?? uid;
          final color =
              e.key < rankColors.length ? rankColors[e.key] : Colors.white24;

          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text('$rank',
                        style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.bold,
                            fontSize: 12)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(name,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 13)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1F2937),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text('$count abs.',
                      style: const TextStyle(
                          color: Colors.white54, fontSize: 11)),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _MotifChart extends StatelessWidget {
  final int maladie;
  final int formation;
  final int conge;
  final int autre;
  final int total;

  const _MotifChart({
    required this.maladie,
    required this.formation,
    required this.conge,
    required this.autre,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    if (total == 0) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF161B22),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: Text('Aucune donnée',
              style: TextStyle(color: Colors.white38, fontSize: 13)),
        ),
      );
    }

    final items = [
      _MotifItem(
          label: 'Maladie',
          count: maladie,
          color: const Color(0xFFEF4444)),
      _MotifItem(
          label: 'Formation',
          count: formation,
          color: const Color(0xFF2563EB)),
      _MotifItem(
          label: 'Congé',
          count: conge,
          color: const Color(0xFF10B981)),
      _MotifItem(
          label: 'Autre',
          count: autre,
          color: const Color(0xFF6B7280)),
    ];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Horizontal bar segments
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 20,
              child: Row(
                children: items.where((i) => i.count > 0).map((item) {
                  return Expanded(
                    flex: item.count,
                    child: Container(color: item.color),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: items.map((item) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                        color: item.color, shape: BoxShape.circle)),
                const SizedBox(width: 5),
                Text(
                    '${item.label} (${item.count})',
                    style: const TextStyle(
                        color: Colors.white54, fontSize: 12)),
              ],
            )).toList(),
          ),
        ],
      ),
    );
  }
}

class _MotifItem {
  final String label;
  final int count;
  final Color color;
  const _MotifItem(
      {required this.label, required this.count, required this.color});
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        color: Colors.white38,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
      ),
    );
  }
}
