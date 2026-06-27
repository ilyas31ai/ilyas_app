import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../models/maitrise_model.dart';
import '../services/maitrise_service.dart';

// ─── Couleurs par matière (reprises des autres pages) ─────────────────────────

const _kGrad = <String, Color>{
  'Mathématiques'   : Color(0xFF2563EB),
  'Français'        : Color(0xFF7C3AED),
  'Histoire-Géo'    : Color(0xFFB45309),
  'SVT'             : Color(0xFF15803D),
  'Physique-Chimie' : Color(0xFFDC2626),
  'Anglais'         : Color(0xFF0F766E),
  'Espagnol'        : Color(0xFFD97706),
  'Informatique'    : Color(0xFF374151),
  'Philosophie'     : Color(0xFF6C47FF),
  'Sciences'        : Color(0xFF047857),
  'Économie'        : Color(0xFF0891B2),
  'Droit'           : Color(0xFF1D4ED8),
  'Lettres'         : Color(0xFF7C3AED),
};

Color _matiereColor(String m) => _kGrad[m] ?? const Color(0xFF6C47FF);

// ═══════════════════════════════════════════════════════════════════════════════
// Widget embarquable dans un TabBarView (pas de Scaffold)
// ═══════════════════════════════════════════════════════════════════════════════

class ProgressionContent extends StatelessWidget {
  const ProgressionContent({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<MaitriseModel>>(
      stream: MaitriseService.stream(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFF2563EB)));
        }

        final notions = snap.data ?? [];

        if (notions.isEmpty) {
          return _buildEmpty();
        }

        // Regroupe par matière, trie les notions (à retravailler en premier)
        final Map<String, List<MaitriseModel>> grouped = {};
        for (final n in notions) {
          (grouped[n.matiere] ??= []).add(n);
        }
        for (final list in grouped.values) {
          list.sort((a, b) => a.score.compareTo(b.score)); // les plus faibles en premier
        }
        // Trie les matières : celles avec le plus de notions à retravailler en premier
        final matieres = grouped.keys.toList()
          ..sort((a, b) {
            final aRed = grouped[a]!.where((n) => n.score < 45).length;
            final bRed = grouped[b]!.where((n) => n.score < 45).length;
            return bRed.compareTo(aRed);
          });

        // Résumé global
        final total     = notions.length;
        final maitrise  = notions.where((n) => n.niveau == 'maitrise').length;
        final enCours   = notions.where((n) => n.niveau == 'en_cours').length;
        final aRetrav   = notions.where((n) => n.niveau == 'a_retravailler').length;

        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: _SummaryBanner(
                  total: total,
                  maitrise: maitrise,
                  enCours: enCours,
                  aRetrav: aRetrav,
                ),
              ),
            ),
            ...matieres.map((m) => SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: _MatiereSection(
                  matiere: m,
                  notions: grouped[m]!,
                  color: _matiereColor(m),
                ),
              ),
            )),
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        );
      },
    );
  }

  Widget _buildEmpty() => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.trending_up_outlined, color: Colors.white24, size: 56),
            const SizedBox(height: 20),
            const Text('Aucun suivi de maîtrise',
                style: TextStyle(color: Colors.white54, fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            const Text(
              'Fais un quiz ou un exercice pour que l\'IA commence\nà suivre ta progression notion par notion.',
              style: TextStyle(color: Colors.white38, fontSize: 13, height: 1.5),
              textAlign: TextAlign.center,
            ),
          ]),
        ),
      );
}

// ─── Bannière résumé ──────────────────────────────────────────────────────────

class _SummaryBanner extends StatelessWidget {
  final int total, maitrise, enCours, aRetrav;
  const _SummaryBanner({
    required this.total, required this.maitrise,
    required this.enCours, required this.aRetrav,
  });

  @override
  Widget build(BuildContext context) {
    final pct = total == 0 ? 0 : (maitrise * 100 ~/ total);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E3A5F), Color(0xFF1B2E4A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(children: [
        // Jauge circulaire
        Stack(alignment: Alignment.center, children: [
          SizedBox(
            width: 64, height: 64,
            child: CircularProgressIndicator(
              value: pct / 100,
              backgroundColor: Colors.white12,
              color: pct >= 80 ? const Color(0xFF16A34A) : const Color(0xFF2563EB),
              strokeWidth: 6,
            ),
          ),
          Text('$pct%',
              style: const TextStyle(
                  color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
        ]),
        const SizedBox(width: 16),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('$total notion${total > 1 ? 's' : ''} suivie${total > 1 ? 's' : ''}',
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 8),
            Row(children: [
              _StatChip(emoji: '🟢', count: maitrise, label: 'Maîtrisées'),
              const SizedBox(width: 8),
              _StatChip(emoji: '🟡', count: enCours, label: 'En cours'),
              const SizedBox(width: 8),
              _StatChip(emoji: '🔴', count: aRetrav, label: 'À retravailler'),
            ]),
          ]),
        ),
      ]),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String emoji, label;
  final int count;
  const _StatChip({required this.emoji, required this.count, required this.label});
  @override
  Widget build(BuildContext context) => Column(mainAxisSize: MainAxisSize.min, children: [
        Row(mainAxisSize: MainAxisSize.min, children: [
          Text(emoji, style: const TextStyle(fontSize: 13)),
          const SizedBox(width: 3),
          Text('$count', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
        ]),
        Text(label, style: const TextStyle(color: Colors.white38, fontSize: 9)),
      ]);
}

// ─── Section par matière ──────────────────────────────────────────────────────

class _MatiereSection extends StatefulWidget {
  final String matiere;
  final List<MaitriseModel> notions;
  final Color color;
  const _MatiereSection({
    required this.matiere, required this.notions, required this.color,
  });
  @override
  State<_MatiereSection> createState() => _MatiereSectionState();
}

class _MatiereSectionState extends State<_MatiereSection> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final aRetrav  = widget.notions.where((n) => n.niveau == 'a_retravailler').length;
    final maitrise = widget.notions.where((n) => n.niveau == 'maitrise').length;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(children: [
        // Header cliquable
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(children: [
              Container(
                width: 10, height: 10,
                decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(widget.matiere,
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
              ),
              if (aRetrav > 0)
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDC2626).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFDC2626).withValues(alpha: 0.3)),
                  ),
                  child: Text('$aRetrav à retravailler',
                      style: const TextStyle(color: Color(0xFFDC2626), fontSize: 10)),
                ),
              Text('$maitrise/${widget.notions.length}',
                  style: const TextStyle(color: Colors.white38, fontSize: 12)),
              const SizedBox(width: 6),
              Icon(_expanded ? Icons.expand_less : Icons.expand_more,
                  color: Colors.white38, size: 18),
            ]),
          ),
        ),
        if (_expanded) ...[
          const Divider(color: Colors.white12, height: 1),
          ...widget.notions.map((n) => _NotionRow(notion: n)),
        ],
      ]),
    );
  }
}

// ─── Ligne d'une notion ───────────────────────────────────────────────────────

class _NotionRow extends StatefulWidget {
  final MaitriseModel notion;
  const _NotionRow({required this.notion});

  @override
  State<_NotionRow> createState() => _NotionRowState();
}

class _NotionRowState extends State<_NotionRow> {
  bool _showChart = false;

  @override
  Widget build(BuildContext context) {
    final n = widget.notion;
    final color = n.niveau == 'maitrise'
        ? const Color(0xFF16A34A)
        : n.niveau == 'en_cours'
            ? const Color(0xFFD97706)
            : const Color(0xFFDC2626);

    final hasHistory = n.historiqueScores.length > 1;

    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.04))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: hasHistory ? () => setState(() => _showChart = !_showChart) : null,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
              child: Row(children: [
                Text(n.niveauEmoji, style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(n.label,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: n.score / 100,
                        backgroundColor: Colors.white12,
                        color: color,
                        minHeight: 4,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(children: [
                      Text(n.niveauLabel, style: TextStyle(color: color, fontSize: 10)),
                      const Spacer(),
                      if (n.tentatives > 1)
                        Text('${n.tentatives} tentatives',
                            style: const TextStyle(color: Colors.white24, fontSize: 10)),
                    ]),
                    if (n.erreurs.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Icon(Icons.warning_amber_outlined,
                              color: Color(0xFFDC2626), size: 11),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(n.erreurs.first,
                                style: const TextStyle(
                                    color: Color(0xFFDC2626), fontSize: 10, height: 1.3)),
                          ),
                        ]),
                      ),
                  ]),
                ),
                const SizedBox(width: 10),
                Text('${n.score}',
                    style: TextStyle(
                        color: color, fontSize: 16, fontWeight: FontWeight.bold)),
                Text('/100',
                    style: const TextStyle(color: Colors.white24, fontSize: 10)),
                if (hasHistory) ...[
                  const SizedBox(width: 6),
                  Icon(
                    _showChart ? Icons.expand_less : Icons.show_chart,
                    color: Colors.white24,
                    size: 16,
                  ),
                ],
              ]),
            ),
          ),
          if (_showChart && hasHistory)
            _HistoriqueChart(historique: n.historiqueScores, color: color),
        ],
      ),
    );
  }
}

// ─── Mini graphique d'historique ──────────────────────────────────────────────

class _HistoriqueChart extends StatelessWidget {
  final List<Map<String, dynamic>> historique;
  final Color color;
  const _HistoriqueChart({required this.historique, required this.color});

  @override
  Widget build(BuildContext context) {
    final spots = <FlSpot>[];
    for (int i = 0; i < historique.length; i++) {
      final score = (historique[i]['score'] as num?)?.toDouble() ?? 0;
      spots.add(FlSpot(i.toDouble(), score));
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
      child: SizedBox(
        height: 80,
        child: LineChart(
          LineChartData(
            minY: 0,
            maxY: 100,
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: 25,
              getDrawingHorizontalLine: (_) => FlLine(
                color: Colors.white10,
                strokeWidth: 1,
              ),
            ),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 28,
                  interval: 50,
                  getTitlesWidget: (v, _) => Text(
                    '${v.toInt()}',
                    style: const TextStyle(color: Colors.white24, fontSize: 9),
                  ),
                ),
              ),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: true,
                color: color,
                barWidth: 2,
                dotData: FlDotData(
                  show: true,
                  getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                    radius: 3,
                    color: color,
                    strokeWidth: 0,
                  ),
                ),
                belowBarData: BarAreaData(
                  show: true,
                  color: color.withValues(alpha: 0.1),
                ),
              ),
            ],
            lineTouchData: LineTouchData(
              touchTooltipData: LineTouchTooltipData(
                getTooltipItems: (spots) => spots
                    .map((s) => LineTooltipItem(
                          '${s.y.toInt()}',
                          TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11),
                        ))
                    .toList(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
