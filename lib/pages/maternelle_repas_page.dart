import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../widgets/cycle_access_guard.dart';

const _kColors = [Color(0xFFD97706), Color(0xFFEC4899)];

class MaternelleRepasPage extends StatelessWidget {
  const MaternelleRepasPage({super.key});

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
        title: const Text('Suivi des repas',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
      ),
      body: uid.isEmpty
          ? const Center(child: Text('Non connecté', style: TextStyle(color: Colors.white38)))
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('repas_maternelle')
                  .where('eleveId', isEqualTo: uid)
                  .orderBy('date', descending: true)
                  .limit(15)
                  .snapshots(),
              builder: (_, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Color(0xFFD97706)));
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
                      ...records.map((r) => _RepasCard(data: r)),
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
              const Text('Cantine & goûter', style: TextStyle(color: Colors.white60, fontSize: 11)),
              const Text('Suivi des repas', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
              Text(prenom.isNotEmpty ? 'Pour $prenom' : 'Votre enfant',
                  style: const TextStyle(color: Colors.white70, fontSize: 12)),
            ]),
          ),
          const Icon(Icons.restaurant_outlined, color: Colors.white24, size: 44),
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
    final tout = records.where((r) => r['midi'] == 'tout').length;
    final pct = total > 0 ? (tout / total * 100).round() : 0;
    final gouters = records.where((r) => r['gouter'] == true).length;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD97706).withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Expanded(child: _StatItem('$pct %', 'Repas\ncomplété', const Color(0xFFD97706))),
          Container(width: 1, height: 40, color: Colors.white12),
          Expanded(child: _StatItem('$tout/$total', 'Tout\nmangé', const Color(0xFF15803D))),
          Container(width: 1, height: 40, color: Colors.white12),
          Expanded(child: _StatItem('$gouters', 'Goûters\npris', const Color(0xFF9333EA))),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String value, label;
  final Color color;
  const _StatItem(this.value, this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Text(value, style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.bold)),
      const SizedBox(height: 2),
      Text(label, style: const TextStyle(color: Colors.white38, fontSize: 10), textAlign: TextAlign.center),
    ]);
  }
}

class _RepasCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _RepasCard({required this.data});

  static const _midiColors = {
    'tout': Color(0xFF15803D),
    'peu': Color(0xFFD97706),
    'rien': Color(0xFFDC2626),
  };
  static const _midiLabels = {'tout': 'Tout mangé', 'peu': 'Peu mangé', 'rien': 'N\'a pas mangé'};
  static const _midiIcons = {
    'tout': Icons.sentiment_very_satisfied_outlined,
    'peu': Icons.sentiment_neutral_outlined,
    'rien': Icons.sentiment_dissatisfied_outlined,
  };

  String get _dateLabel {
    final d = (data['date'] as Timestamp?)?.toDate() ?? DateTime.now();
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final midi = data['midi'] as String? ?? 'peu';
    final gouter = data['gouter'] as bool? ?? false;
    final commentaire = data['commentaire'] as String? ?? '';
    final color = _midiColors[midi] ?? const Color(0xFFD97706);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_midiIcons[midi] ?? Icons.help_outline, color: color, size: 24),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_midiLabels[midi] ?? 'Repas', style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 14)),
                    Text(_dateLabel, style: const TextStyle(color: Colors.white38, fontSize: 11)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: (gouter ? const Color(0xFF9333EA) : Colors.white12).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  gouter ? 'Goûter ✓' : 'Goûter –',
                  style: TextStyle(
                    color: gouter ? const Color(0xFF9333EA) : Colors.white38,
                    fontSize: 10, fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          if (commentaire.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(commentaire, style: const TextStyle(color: Colors.white60, fontSize: 12, height: 1.4)),
          ],
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
        Icon(Icons.restaurant_outlined, color: Colors.white24, size: 48),
        SizedBox(height: 12),
        Text('Aucun suivi repas enregistré', style: TextStyle(color: Colors.white38, fontSize: 14)),
        SizedBox(height: 6),
        Text('L\'équipe éducative renseignera le suivi des repas ici.',
            style: TextStyle(color: Colors.white24, fontSize: 12), textAlign: TextAlign.center),
      ]),
    );
  }
}
