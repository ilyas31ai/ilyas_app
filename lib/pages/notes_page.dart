import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../models/note_model.dart';
import '../services/etudiant_service.dart';

class NotesPage extends StatelessWidget {
  const NotesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        elevation: 0,
        title: const Text(
          'Notes & Resultats',
          style: TextStyle(
              color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
      body: StreamBuilder<String?>(
        stream: EtudiantService.classeNomStream(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: Color(0xFF2563EB)));
          }
          final classeNom = snap.data;
          if (classeNom == null || classeNom.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.school_outlined,
                      color: Colors.white24, size: 48),
                  SizedBox(height: 12),
                  Text('Classe non assignee',
                      style:
                          TextStyle(color: Colors.white38, fontSize: 15)),
                ],
              ),
            );
          }
          return _NotesBody(classeNom: classeNom);
        },
      ),
    );
  }
}

class _NotesBody extends StatelessWidget {
  final String classeNom;
  const _NotesBody({required this.classeNom});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<NoteModel>>(
      stream: EtudiantService.notesStream(classeNom),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: Color(0xFF2563EB)));
        }
        if (snap.hasError) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Impossible de charger les notes.\nVérifiez votre connexion.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54, fontSize: 13),
              ),
            ),
          );
        }
        final notes = snap.data ?? [];
        if (notes.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.grade_outlined,
                    color: Colors.white24, size: 48),
                SizedBox(height: 12),
                Text('Aucune note publiee',
                    style: TextStyle(
                        color: Colors.white38, fontSize: 15)),
              ],
            ),
          );
        }

        final moyenne = _computeMoyenne(notes);
        final parMatiere = _computeParMatiere(notes);

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            _MoyenneCard(moyenne: moyenne),
            if (notes.length >= 2) ...[
              const SizedBox(height: 20),
              _NotesChart(notes: notes),
            ],
            const SizedBox(height: 24),
            _sectionLabel('Par matiere'),
            const SizedBox(height: 10),
            ...parMatiere.entries
                .map((e) => _MatiereRow(matiere: e.key, moyenne: e.value))
                .toList(),
            const SizedBox(height: 24),
            _sectionLabel('Toutes les notes'),
            const SizedBox(height: 10),
            ...notes.map((n) => _NoteRow(note: n)).toList(),
          ],
        );
      },
    );
  }

  double _computeMoyenne(List<NoteModel> notes) {
    if (notes.isEmpty) return 0;
    final total = notes.fold<double>(0, (s, n) => s + n.sur20);
    return total / notes.length;
  }

  Map<String, double> _computeParMatiere(List<NoteModel> notes) {
    final Map<String, List<double>> map = {};
    for (final n in notes) {
      map.putIfAbsent(n.matiere, () => []).add(n.sur20);
    }
    return map.map((k, v) {
      final avg = v.fold<double>(0, (s, x) => s + x) / v.length;
      return MapEntry(k, avg);
    });
  }

  Widget _sectionLabel(String label) {
    return Text(
      label.toUpperCase(),
      style: const TextStyle(
        color: Colors.white38,
        fontSize: 11,
        letterSpacing: 1.2,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _MoyenneCard extends StatelessWidget {
  final double moyenne;
  const _MoyenneCard({required this.moyenne});

  @override
  Widget build(BuildContext context) {
    final color = moyenne >= 14
        ? const Color(0xFF16A34A)
        : moyenne >= 10
            ? const Color(0xFFD97706)
            : const Color(0xFFDC2626);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6C47FF), Color(0xFF2563EB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Moyenne generale',
                  style: TextStyle(color: Colors.white70, fontSize: 13)),
              const SizedBox(height: 6),
              Text(
                moyenne.toStringAsFixed(2),
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 38,
                    fontWeight: FontWeight.bold),
              ),
              const Text('/20',
                  style: TextStyle(color: Colors.white60, fontSize: 16)),
            ],
          ),
          const Spacer(),
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Icon(
                moyenne >= 10
                    ? Icons.emoji_events_outlined
                    : Icons.trending_up,
                color: color,
                size: 32,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NotesChart extends StatelessWidget {
  final List<NoteModel> notes;
  const _NotesChart({required this.notes});

  @override
  Widget build(BuildContext context) {
    final sorted = List<NoteModel>.from(notes)
      ..sort((a, b) => a.date.compareTo(b.date));
    final spots = sorted.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), e.value.sur20);
    }).toList();

    return Container(
      height: 180,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'EVOLUTION DES NOTES',
            style: TextStyle(
              color: Colors.white38,
              fontSize: 10,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: Colors.white.withValues(alpha: 0.05),
                    strokeWidth: 1,
                  ),
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      interval: 5,
                      getTitlesWidget: (v, _) => Text(
                        '${v.toInt()}',
                        style: const TextStyle(
                            color: Colors.white38, fontSize: 10),
                      ),
                    ),
                  ),
                  bottomTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                minY: 0,
                maxY: 20,
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    gradient: const LinearGradient(
                        colors: [Color(0xFF6C47FF), Color(0xFF2563EB)]),
                    barWidth: 2.5,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (_, __, ___, ____) =>
                          FlDotCirclePainter(
                        radius: 3,
                        color: const Color(0xFF6C47FF),
                        strokeWidth: 1.5,
                        strokeColor: Colors.white,
                      ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF6C47FF).withValues(alpha: 0.2),
                          const Color(0xFF2563EB).withValues(alpha: 0.0),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MatiereRow extends StatelessWidget {
  final String matiere;
  final double moyenne;
  const _MatiereRow({required this.matiere, required this.moyenne});

  @override
  Widget build(BuildContext context) {
    final color = moyenne >= 14
        ? const Color(0xFF16A34A)
        : moyenne >= 10
            ? const Color(0xFFD97706)
            : const Color(0xFFDC2626);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(matiere,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500)),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${moyenne.toStringAsFixed(1)}/20',
              style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

class _NoteRow extends StatelessWidget {
  final NoteModel note;
  const _NoteRow({required this.note});

  @override
  Widget build(BuildContext context) {
    final pct = note.bareme > 0 ? note.note / note.bareme : 0.0;
    final color = pct >= 0.7
        ? const Color(0xFF16A34A)
        : pct >= 0.5
            ? const Color(0xFFD97706)
            : const Color(0xFFDC2626);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(note.intitule,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(note.matiere,
                        style: const TextStyle(
                            color: Colors.white38, fontSize: 11)),
                    const SizedBox(width: 8),
                    Text(
                      _formatDate(note.date),
                      style: const TextStyle(
                          color: Colors.white24, fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${note.note}/${note.bareme}',
              style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}
