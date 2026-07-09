import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class DirectionStatistiquesPage extends StatelessWidget {
  const DirectionStatistiquesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        elevation: 0,
        title: const Text(
          'Statistiques',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: const _StatsBody(),
    );
  }
}

class _StatsBody extends StatefulWidget {
  const _StatsBody();
  @override
  State<_StatsBody> createState() => _StatsBodyState();
}

class _StatsBodyState extends State<_StatsBody> {
  static final _db = FirebaseFirestore.instance;

  // ── données chargées ──
  List<_ClasseStat> _classes = [];
  int _totalEleves = 0;
  int _totalProfesseurs = 0;
  int _totalParents = 0;
  int _totalPresencesAuj = 0;
  int _totalAbsencesAuj = 0;
  bool _loading = true;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      // Chargements en parallèle
      final results = await Future.wait([
        _db.collection('classes').get(),
        _db.collection('users').where('role', isEqualTo: 'eleve').get(),
        _db.collection('users').where('role', isEqualTo: 'professeur').get(),
        _db.collection('users').where('role', isEqualTo: 'parent').get(),
        _db.collection('presences')
            .where('date', isEqualTo: _todayStr())
            .get(),
      ]);

      final classesSnap = results[0];
      final elevesSnap = results[1];
      final profsSnap = results[2];
      final parentsSnap = results[3];
      final presencesSnap = results[4];

      // Stats de présence du jour
      int presentAuj = 0, absentAuj = 0;
      for (final doc in presencesSnap.docs) {
        final s = (doc.data()['statut'] as String?) ?? '';
        if (s == 'present') presentAuj++;
        if (s == 'absent') absentAuj++;
      }

      // Calcul par classe
      final classeStats = <_ClasseStat>[];
      for (final classDoc in classesSnap.docs) {
        final data = classDoc.data();
        final nom = (data['nom'] as String?) ?? classDoc.id;
        final eleveIds = List<String>.from(data['eleveIds'] as List? ?? []);

        // Récupérer les présences de cette classe
        int present = 0, absent = 0, retard = 0;
        for (final pDoc in presencesSnap.docs) {
          final pd = pDoc.data();
          if (eleveIds.contains(pd['eleveId'] as String? ?? '')) {
            final s = (pd['statut'] as String?) ?? '';
            if (s == 'present') present++;
            if (s == 'absent') absent++;
            if (s == 'retard') retard++;
          }
        }

        classeStats.add(_ClasseStat(
          nom: nom,
          nbEleves: eleveIds.length,
          present: present,
          absent: absent,
          retard: retard,
        ));
      }
      classeStats.sort((a, b) => b.nbEleves.compareTo(a.nbEleves));

      if (!mounted) return;
      setState(() {
        _classes = classeStats;
        _totalEleves = elevesSnap.docs.length;
        _totalProfesseurs = profsSnap.docs.length;
        _totalParents = parentsSnap.docs.length;
        _totalPresencesAuj = presentAuj;
        _totalAbsencesAuj = absentAuj;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = true;
      });
    }
  }

  String _todayStr() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF2563EB)));
    }
    if (_error) {
      return RefreshIndicator(
        onRefresh: () async {
          setState(() { _loading = true; _error = false; });
          await _load();
        },
        child: ListView(
          children: const [
            SizedBox(height: 80),
            Center(
              child: Text(
                'Erreur de chargement.\nTirez pour réessayer.',
                style: TextStyle(color: Colors.white38, fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () async {
        setState(() => _loading = true);
        await _load();
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        children: [
          // ── KPIs globaux ─────────────────────────────────────────────────
          _sectionLabel('Vue d\'ensemble'),
          const SizedBox(height: 10),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.4,
            children: [
              _kpiCard(Icons.groups_outlined, _totalEleves.toString(),
                  'Élèves inscrits', const [Color(0xFF2563EB), Color(0xFF0891B2)]),
              _kpiCard(Icons.school_outlined, _totalProfesseurs.toString(),
                  'Professeurs', const [Color(0xFF7C3AED), Color(0xFF6C47FF)]),
              _kpiCard(Icons.family_restroom_outlined, _totalParents.toString(),
                  'Parents', const [Color(0xFFBE185D), Color(0xFFDB2777)]),
              _kpiCard(Icons.class_outlined, _classes.length.toString(),
                  'Classes actives', const [Color(0xFF15803D), Color(0xFF16A34A)]),
            ],
          ),

          // ── Présences du jour ─────────────────────────────────────────────
          const SizedBox(height: 24),
          _sectionLabel('Présences aujourd\'hui'),
          const SizedBox(height: 10),
          _presenceCard(),

          // ── Effectif par classe ──────────────────────────────────────────
          if (_classes.isNotEmpty) ...[
            const SizedBox(height: 24),
            _sectionLabel('Effectif par classe'),
            const SizedBox(height: 10),
            _effectifChart(),
          ],

          // ── Tableau détaillé ─────────────────────────────────────────────
          if (_classes.isNotEmpty) ...[
            const SizedBox(height: 24),
            _sectionLabel('Détail par classe'),
            const SizedBox(height: 10),
            ..._classes.map((c) => _classeRow(c)),
          ],
        ],
      ),
    );
  }

  Widget _presenceCard() {
    final total = _totalPresencesAuj + _totalAbsencesAuj;
    final tauxPresence = total > 0
        ? (_totalPresencesAuj / total * 100).toStringAsFixed(1)
        : '—';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(14),
      ),
      child: total == 0
          ? const Center(
              child: Text(
                'Aucune donnée de présence enregistrée aujourd\'hui.',
                style: TextStyle(color: Colors.white38, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            )
          : Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$tauxPresence%',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.bold),
                      ),
                      const Text('Taux de présence',
                          style: TextStyle(color: Colors.white54, fontSize: 12)),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: total > 0 ? _totalPresencesAuj / total : 0,
                          backgroundColor: Colors.red.withValues(alpha: 0.3),
                          color: Colors.green,
                          minHeight: 8,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(children: [
                        _dot(Colors.green),
                        const SizedBox(width: 4),
                        Text('$_totalPresencesAuj présents',
                            style: const TextStyle(
                                color: Colors.white54, fontSize: 11)),
                        const SizedBox(width: 12),
                        _dot(Colors.red),
                        const SizedBox(width: 4),
                        Text('$_totalAbsencesAuj absents',
                            style: const TextStyle(
                                color: Colors.white54, fontSize: 11)),
                      ]),
                    ],
                  ),
                ),
                if (total > 0) ...[
                  const SizedBox(width: 16),
                  SizedBox(
                    width: 90,
                    height: 90,
                    child: PieChart(
                      PieChartData(
                        sections: [
                          PieChartSectionData(
                            value: _totalPresencesAuj.toDouble(),
                            color: Colors.green,
                            radius: 28,
                            title: '',
                          ),
                          PieChartSectionData(
                            value: _totalAbsencesAuj.toDouble(),
                            color: Colors.red,
                            radius: 28,
                            title: '',
                          ),
                        ],
                        centerSpaceRadius: 20,
                        sectionsSpace: 2,
                      ),
                    ),
                  ),
                ],
              ],
            ),
    );
  }

  Widget _effectifChart() {
    final shown = _classes.take(8).toList();
    final maxEleves = shown.isEmpty
        ? 1.0
        : shown.map((c) => c.nbEleves).reduce((a, b) => a > b ? a : b).toDouble();
    return Container(
      height: 200,
      padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(14),
      ),
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxEleves + 2,
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => const Color(0xFF1C2128),
              getTooltipItem: (group, _, rod, __) => BarTooltipItem(
                '${shown[group.x].nom}\n',
                const TextStyle(color: Colors.white, fontSize: 11),
                children: [
                  TextSpan(
                    text: '${rod.toY.toInt()} élèves',
                    style: const TextStyle(
                        color: Color(0xFF2563EB),
                        fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final i = value.toInt();
                  if (i < 0 || i >= shown.length) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      shown[i].nom.length > 6
                          ? shown[i].nom.substring(0, 6)
                          : shown[i].nom,
                      style: const TextStyle(
                          color: Colors.white38, fontSize: 9),
                    ),
                  );
                },
                reservedSize: 28,
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                getTitlesWidget: (value, meta) => Text(
                  value.toInt().toString(),
                  style: const TextStyle(color: Colors.white24, fontSize: 9),
                ),
              ),
            ),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          gridData: FlGridData(
            show: true,
            getDrawingHorizontalLine: (_) =>
                const FlLine(color: Colors.white10, strokeWidth: 1),
            drawVerticalLine: false,
          ),
          barGroups: List.generate(shown.length, (i) {
            return BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: shown[i].nbEleves.toDouble(),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2563EB), Color(0xFF0891B2)],
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                  ),
                  width: 18,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }

  Widget _classeRow(_ClasseStat c) {
    final total = c.present + c.absent + c.retard;
    final pct = total > 0 ? (c.present / total * 100).toStringAsFixed(0) : null;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFF2563EB).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.class_outlined,
                color: Color(0xFF2563EB), size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(c.nom,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
                Text(
                  '${c.nbEleves} élève${c.nbEleves != 1 ? 's' : ''}'
                  '${c.absent > 0 ? '  ·  ${c.absent} abs.' : ''}',
                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                ),
              ],
            ),
          ),
          if (pct != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '$pct%',
                style: const TextStyle(
                    color: Colors.green,
                    fontSize: 11,
                    fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
    );
  }

  Widget _kpiCard(
      IconData icon, String value, String label, List<Color> colors) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
            colors: colors.map((c) => c.withValues(alpha: 0.15)).toList(),
            begin: Alignment.topLeft,
            end: Alignment.bottomRight),
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.first.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: colors.first, size: 22),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold)),
              Text(label,
                  style: const TextStyle(color: Colors.white54, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dot(Color c) => Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: c, shape: BoxShape.circle),
      );

  Widget _sectionLabel(String text) => Text(
        text.toUpperCase(),
        style: const TextStyle(
            color: Colors.white38,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2),
      );
}

class _ClasseStat {
  final String nom;
  final int nbEleves;
  final int present;
  final int absent;
  final int retard;
  const _ClasseStat({
    required this.nom,
    required this.nbEleves,
    required this.present,
    required this.absent,
    required this.retard,
  });
}
