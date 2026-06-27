import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../widgets/cycle_access_guard.dart';

const _kColors = [Color(0xFF0891B2), Color(0xFF15803D)];

enum _Statut { present, absent, retard }

class MaterneilePresencesPage extends StatelessWidget {
  const MaterneilePresencesPage({super.key});

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
        title: const Text('Mes Présences', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
      ),
      body: uid.isEmpty
          ? const Center(child: Text('Non connecté', style: TextStyle(color: Colors.white38)))
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('presences')
                  .where('eleveId', isEqualTo: uid)
                  .orderBy('date', descending: true)
                  .snapshots(),
              builder: (_, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Color(0xFF0891B2)));
                }
                final docs = snap.data?.docs ?? [];
                if (docs.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.how_to_reg_outlined, color: Colors.white24, size: 48),
                        SizedBox(height: 12),
                        Text('Aucun enregistrement de présence', style: TextStyle(color: Colors.white38)),
                      ],
                    ),
                  );
                }
                final records = docs.map((d) {
                  final data = d.data() as Map<String, dynamic>;
                  return (
                    date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
                    statut: _parse(data['statut'] as String? ?? 'present'),
                    motif: data['motif'] as String? ?? '',
                  );
                }).toList();

                final nbP = records.where((r) => r.statut == _Statut.present).length;
                final nbA = records.where((r) => r.statut == _Statut.absent).length;
                final nbR = records.where((r) => r.statut == _Statut.retard).length;
                final taux = records.isEmpty ? 0 : (nbP * 100 ~/ records.length);

                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                  children: [
                    _StatsHeader(nbP: nbP, nbA: nbA, nbR: nbR, taux: taux),
                    const SizedBox(height: 16),
                    ...records.map((r) => _PresenceRow(date: r.date, statut: r.statut, motif: r.motif)),
                  ],
                );
              },
            ),
    );
  }

  static _Statut _parse(String s) {
    if (s == 'absent') return _Statut.absent;
    if (s == 'retard') return _Statut.retard;
    return _Statut.present;
  }
}

class _StatsHeader extends StatelessWidget {
  final int nbP, nbA, nbR, taux;
  const _StatsHeader({required this.nbP, required this.nbA, required this.nbR, required this.taux});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: _kColors, begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Taux de présence', style: TextStyle(color: Colors.white70, fontSize: 13)),
              Text('$taux %', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _Chip('Présent', nbP, const Color(0xFF16A34A)),
              const SizedBox(width: 8),
              _Chip('Absent', nbA, const Color(0xFFDC2626)),
              const SizedBox(width: 8),
              _Chip('Retard', nbR, const Color(0xFFD97706)),
            ],
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  const _Chip(this.label, this.count, this.color);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(8)),
        child: Column(
          children: [
            Text('$count', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)),
            Text(label, style: const TextStyle(color: Colors.white60, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

class _PresenceRow extends StatelessWidget {
  final DateTime date;
  final _Statut statut;
  final String motif;
  const _PresenceRow({required this.date, required this.statut, required this.motif});

  (String, Color, IconData) get _info => switch (statut) {
    _Statut.present => ('Présent', const Color(0xFF16A34A), Icons.check_circle_outline),
    _Statut.absent  => ('Absent', const Color(0xFFDC2626), Icons.cancel_outlined),
    _Statut.retard  => ('Retard', const Color(0xFFD97706), Icons.schedule_outlined),
  };

  String get _dateLabel =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

  @override
  Widget build(BuildContext context) {
    final (label, color, icon) = _info;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_dateLabel, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
                if (motif.isNotEmpty)
                  Text(motif, style: const TextStyle(color: Colors.white38, fontSize: 12)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
            child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
