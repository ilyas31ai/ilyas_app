import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/classe_model.dart';
import '../models/user_model.dart';
import '../services/etudiant_service.dart';
import '../widgets/cycle_access_guard.dart';

const _kColors = [Color(0xFF0891B2), Color(0xFF2563EB)];

class MaternelleCalendrierPage extends StatelessWidget {
  const MaternelleCalendrierPage({super.key});

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

  String get _classeNom => user.classeNom ?? user.niveau ?? '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        elevation: 0,
        title: const Text('Calendrier des activités',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          _HeaderBanner(),
          const SizedBox(height: 16),
          _sectionLabel('Emploi du temps'),
          const SizedBox(height: 10),
          _classeNom.isEmpty
              ? _infoBox('Classe non configurée')
              : _EmploiSection(classeNom: _classeNom),
          const SizedBox(height: 20),
          _sectionLabel('Événements à venir'),
          const SizedBox(height: 10),
          _classeNom.isEmpty
              ? _infoBox('Classe non configurée')
              : _EvenementsSection(classeNom: _classeNom),
        ],
      ),
    );
  }

  static Widget _sectionLabel(String t) => Text(
        t.toUpperCase(),
        style: const TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2),
      );

  static Widget _infoBox(String msg) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: const Color(0xFF161B22), borderRadius: BorderRadius.circular(12)),
        child: Text(msg, style: const TextStyle(color: Colors.white38, fontSize: 13)),
      );
}

class _HeaderBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: _kColors, begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Row(
        children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Planning & événements', style: TextStyle(color: Colors.white60, fontSize: 11)),
              Text('Ma semaine à l\'école', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
              Text('Activités, sorties et fêtes de classe', style: TextStyle(color: Colors.white70, fontSize: 12)),
            ]),
          ),
          Icon(Icons.calendar_month_outlined, color: Colors.white24, size: 44),
        ],
      ),
    );
  }
}

class _EmploiSection extends StatelessWidget {
  final String classeNom;
  const _EmploiSection({required this.classeNom});

  static const _jours = ['Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi'];

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<EmploiSlot>>(
      stream: EtudiantService.emploiStream(classeNom),
      builder: (_, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFF0891B2)));
        }
        final slots = snap.data ?? [];
        if (slots.isEmpty) {
          return _empty('Emploi du temps non encore publié');
        }
        final byJour = <int, List<EmploiSlot>>{};
        for (final s in slots) { (byJour[s.jour] ??= []).add(s); }

        return Column(
          children: byJour.entries.map((e) {
            final jourLabel = e.key >= 1 && e.key <= 5 ? _jours[e.key - 1] : 'Jour ${e.key}';
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF161B22),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
                    child: Text(jourLabel, style: const TextStyle(color: Color(0xFF0891B2), fontWeight: FontWeight.w700, fontSize: 13)),
                  ),
                  const Divider(color: Colors.white10, height: 1),
                  ...e.value.map((s) => Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        child: Row(
                          children: [
                            const Icon(Icons.schedule, color: Colors.white24, size: 14),
                            const SizedBox(width: 8),
                            Text('${s.heureDebut} – ${s.heureFin}', style: const TextStyle(color: Colors.white38, fontSize: 12)),
                            const SizedBox(width: 12),
                            Expanded(child: Text(s.matiere, style: const TextStyle(color: Colors.white, fontSize: 13))),
                          ],
                        ),
                      )),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }

  static Widget _empty(String msg) => Container(
        padding: const EdgeInsets.all(20),
        alignment: Alignment.center,
        decoration: BoxDecoration(color: const Color(0xFF161B22), borderRadius: BorderRadius.circular(12)),
        child: Text(msg, style: const TextStyle(color: Colors.white38, fontSize: 13)),
      );
}

class _EvenementsSection extends StatelessWidget {
  final String classeNom;
  const _EvenementsSection({required this.classeNom});

  static const _typeColors = {
    'sortie': Color(0xFF2563EB),
    'fete': Color(0xFFD97706),
    'activite': Color(0xFFEC4899),
    'info': Color(0xFF0891B2),
  };
  static const _typeIcons = {
    'sortie': Icons.directions_bus_outlined,
    'fete': Icons.celebration_outlined,
    'activite': Icons.palette_outlined,
    'info': Icons.info_outline,
  };

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('evenements_maternelle')
          .where('classeNom', isEqualTo: classeNom)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(now))
          .orderBy('date')
          .limit(10)
          .snapshots(),
      builder: (_, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(20),
            alignment: Alignment.center,
            decoration: BoxDecoration(color: const Color(0xFF161B22), borderRadius: BorderRadius.circular(12)),
            child: const Text('Aucun événement à venir', style: TextStyle(color: Colors.white38, fontSize: 13)),
          );
        }
        return Column(
          children: docs.map((doc) {
            final d = doc.data() as Map<String, dynamic>;
            final date = (d['date'] as Timestamp?)?.toDate() ?? DateTime.now();
            final type = d['type'] as String? ?? 'info';
            final color = _typeColors[type] ?? const Color(0xFF0891B2);
            final icon = _typeIcons[type] ?? Icons.event_outlined;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF161B22),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: color.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                    child: Icon(icon, color: color, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(d['titre'] as String? ?? 'Événement',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                        Text(_fmt(date), style: const TextStyle(color: Colors.white38, fontSize: 11)),
                        if ((d['description'] as String? ?? '').isNotEmpty)
                          Text(d['description'] as String, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }
}
