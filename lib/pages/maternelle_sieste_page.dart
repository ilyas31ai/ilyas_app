import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../widgets/cycle_access_guard.dart';

const _kColors = [Color(0xFF6366F1), Color(0xFF9333EA)];

class MaternelleSiestePage extends StatelessWidget {
  const MaternelleSiestePage({super.key});

  @override
  Widget build(BuildContext context) {
    return CycleAccessGuard(
      cycleCategorie: 'Maternelle',
      cycleColors: _kColors,
      builder: (user) => _Body(user: user),
    );
  }
}

class _Body extends StatelessWidget {
  final UserModel user;
  const _Body({required this.user});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        elevation: 0,
        title: const Text('Suivi de la sieste',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
      ),
      body: uid.isEmpty
          ? const Center(child: Text('Non connecté', style: TextStyle(color: Colors.white38)))
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('sieste_maternelle')
                  .where('eleveId', isEqualTo: uid)
                  .orderBy('date', descending: true)
                  .limit(15)
                  .snapshots(),
              builder: (_, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Color(0xFF6366F1)));
                }
                final docs = snap.data?.docs ?? [];
                final records = docs.map((d) => d.data() as Map<String, dynamic>).toList();
                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                  children: [
                    _HeaderBanner(prenom: user.displayName),
                    const SizedBox(height: 16),
                    if (records.isNotEmpty) ...[
                      _StatsCard(records: records),
                      const SizedBox(height: 16),
                    ],
                    if (records.isEmpty)
                      _EmptyState()
                    else
                      ...records.map((r) => _SiesteCard(data: r)),
                  ],
                );
              },
            ),
    );
  }
}

class _HeaderBanner extends StatelessWidget {
  final String prenom;
  const _HeaderBanner({required this.prenom});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: _kColors, begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Repos de l\'après-midi', style: TextStyle(color: Colors.white60, fontSize: 11)),
              const Text('Suivi de la sieste', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
              Text(prenom.isNotEmpty ? 'Pour $prenom' : 'Votre enfant',
                  style: const TextStyle(color: Colors.white70, fontSize: 12)),
            ]),
          ),
          const Icon(Icons.bedtime_outlined, color: Colors.white24, size: 44),
        ],
      ),
    );
  }
}

class _StatsCard extends StatelessWidget {
  final List<Map<String, dynamic>> records;
  const _StatsCard({required this.records});

  @override
  Widget build(BuildContext context) {
    final total = records.length;
    final dors = records.where((r) => r['a_dormi'] == true).length;
    final pct = total > 0 ? (dors / total * 100).round() : 0;
    final durees = records
        .where((r) => r['a_dormi'] == true && r['duree_min'] != null)
        .map((r) => (r['duree_min'] as num).toInt())
        .toList();
    final moyDuree = durees.isEmpty ? 0 : durees.fold(0, (a, b) => a + b) ~/ durees.length;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Expanded(child: _Stat('$pct %', 'A dormi', const Color(0xFF6366F1))),
          Container(width: 1, height: 40, color: Colors.white12),
          Expanded(child: _Stat('$dors/$total', 'Siestes', const Color(0xFF15803D))),
          Container(width: 1, height: 40, color: Colors.white12),
          Expanded(child: _Stat('${moyDuree}min', 'Durée\nmoyenne', const Color(0xFF9333EA))),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String v, l;
  final Color c;
  const _Stat(this.v, this.l, this.c);

  @override
  Widget build(BuildContext context) => Column(children: [
        Text(v, style: TextStyle(color: c, fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(l, style: const TextStyle(color: Colors.white38, fontSize: 10), textAlign: TextAlign.center),
      ]);
}

class _SiesteCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _SiesteCard({required this.data});

  String get _dateLabel {
    final d = (data['date'] as Timestamp?)?.toDate() ?? DateTime.now();
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final aDormi = data['a_dormi'] as bool? ?? false;
    final dureeMin = (data['duree_min'] as num?)?.toInt() ?? 0;
    final commentaire = data['commentaire'] as String? ?? '';
    final color = aDormi ? const Color(0xFF6366F1) : const Color(0xFF374151);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
            child: Icon(aDormi ? Icons.bedtime_outlined : Icons.wb_sunny_outlined, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(aDormi ? 'A bien dormi' : 'N\'a pas dormi',
                    style: TextStyle(color: aDormi ? Colors.white : Colors.white54, fontWeight: FontWeight.w600, fontSize: 14)),
                Text(
                  _dateLabel + (aDormi && dureeMin > 0 ? ' · ${dureeMin}min' : ''),
                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                ),
                if (commentaire.isNotEmpty)
                  Text(commentaire, style: const TextStyle(color: Colors.white54, fontSize: 12)),
              ],
            ),
          ),
          Icon(aDormi ? Icons.check_circle_outline : Icons.cancel_outlined, color: color, size: 20),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: const Column(children: [
        Icon(Icons.bedtime_outlined, color: Colors.white24, size: 48),
        SizedBox(height: 12),
        Text('Aucun suivi de sieste', style: TextStyle(color: Colors.white38, fontSize: 14)),
        SizedBox(height: 6),
        Text('L\'équipe éducative renseignera le suivi des siestes ici.',
            style: TextStyle(color: Colors.white24, fontSize: 12), textAlign: TextAlign.center),
      ]),
    );
  }
}
