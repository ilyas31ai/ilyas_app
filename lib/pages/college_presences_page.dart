import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/presence_model.dart';
import '../models/user_model.dart';
import '../widgets/cycle_access_guard.dart';

const _kColors = [Color(0xFF0F766E), Color(0xFF15803D)];

class CollegePresencesPage extends StatelessWidget {
  const CollegePresencesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return CycleAccessGuard(
      cycleCategorie: 'Collège',
      cycleColors: _kColors,
      builder: (user) => _Body(user: user),
    );
  }
}

class _Body extends StatelessWidget {
  final UserModel user;
  const _Body({required this.user});

  static final _db = FirebaseFirestore.instance;
  static String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  Stream<List<PresenceRecord>> _presencesStream() {
    return _db
        .collection('presences')
        .where('eleveId', isEqualTo: _uid)
        .orderBy('date', descending: true)
        .limit(60)
        .snapshots()
        .map((s) => s.docs.map(PresenceRecord.fromFirestore).toList());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        elevation: 0,
        title: const Text('Mes Présences', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
      ),
      body: StreamBuilder<List<PresenceRecord>>(
        stream: _presencesStream(),
        builder: (_, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF0F766E)));
          }
          if (snap.hasError) {
            return Center(
              child: Text('Données de présence non disponibles.\n${snap.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white38, fontSize: 13)),
            );
          }
          final records = snap.data ?? [];
          if (records.isEmpty) {
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
          final absences = records.where((r) => r.statut == PresenceStatut.absent).length;
          final retards = records.where((r) => r.statut == PresenceStatut.retard).length;
          final presents = records.length - absences - retards;

          return Column(
            children: [
              _StatsHeader(presents: presents, absences: absences, retards: retards),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                  itemCount: records.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (_, i) => _PresenceRow(record: records[i]),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StatsHeader extends StatelessWidget {
  final int presents;
  final int absences;
  final int retards;
  const _StatsHeader({required this.presents, required this.absences, required this.retards});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF161B22),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          _StatChip(label: 'Présent', value: presents, color: const Color(0xFF16A34A)),
          const SizedBox(width: 8),
          _StatChip(label: 'Absent', value: absences, color: const Color(0xFFDC2626)),
          const SizedBox(width: 8),
          _StatChip(label: 'Retard', value: retards, color: const Color(0xFFD97706)),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  const _StatChip({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          children: [
            Text('$value', style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold)),
            Text(label, style: const TextStyle(color: Colors.white38, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

class _PresenceRow extends StatelessWidget {
  final PresenceRecord record;
  const _PresenceRow({required this.record});

  Color get _color {
    return switch (record.statut) {
      PresenceStatut.present => const Color(0xFF16A34A),
      PresenceStatut.absent => const Color(0xFFDC2626),
      PresenceStatut.retard => const Color(0xFFD97706),
    };
  }

  IconData get _icon {
    return switch (record.statut) {
      PresenceStatut.present => Icons.check_circle_outline,
      PresenceStatut.absent => Icons.cancel_outlined,
      PresenceStatut.retard => Icons.watch_later_outlined,
    };
  }

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _color.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Icon(_icon, color: _color, size: 18),
          const SizedBox(width: 12),
          Expanded(child: Text(_fmt(record.date), style: const TextStyle(color: Colors.white70, fontSize: 13))),
          if (record.motif.isNotEmpty)
            Text(record.motif, style: const TextStyle(color: Colors.white38, fontSize: 12)),
          const SizedBox(width: 8),
          Text(record.statut.label, style: TextStyle(color: _color, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
