import 'package:flutter/material.dart';
import '../models/classe_model.dart';
import '../models/user_model.dart';
import '../services/etudiant_service.dart';
import '../widgets/cycle_access_guard.dart';

const _kColors = [Color(0xFFEC4899), Color(0xFF9333EA)];

class MaterneileActivitesPage extends StatelessWidget {
  const MaterneileActivitesPage({super.key});

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

  static const _domaines = [
    _Domaine(Icons.brush_outlined, 'Arts Plastiques', Color(0xFFEC4899)),
    _Domaine(Icons.directions_run_outlined, 'Motricité', Color(0xFF9333EA)),
    _Domaine(Icons.music_note_outlined, 'Musique & Chants', Color(0xFF7C3AED)),
    _Domaine(Icons.auto_stories_outlined, 'Langage & Lecture', Color(0xFF2563EB)),
    _Domaine(Icons.calculate_outlined, 'Mathématiques', Color(0xFF0891B2)),
    _Domaine(Icons.science_outlined, 'Découverte du Monde', Color(0xFF15803D)),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        elevation: 0,
        title: const Text('Mes Activités', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
      ),
      body: _classeNom.isEmpty
          ? const Center(child: Text('Classe non configurée', style: TextStyle(color: Colors.white38)))
          : StreamBuilder<List<EmploiSlot>>(
              stream: EtudiantService.emploiStream(_classeNom),
              builder: (_, snap) {
                final slots = snap.data ?? [];
                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                  children: [
                    _BannerHeader(niveau: user.niveau),
                    const SizedBox(height: 20),
                    _sectionLabel('Domaines d\'apprentissage'),
                    const SizedBox(height: 10),
                    ..._domaines.map((d) => _DomaineCard(domaine: d)),
                    if (slots.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      _sectionLabel('Emploi du temps'),
                      const SizedBox(height: 10),
                      ..._buildSlots(slots),
                    ],
                  ],
                );
              },
            ),
    );
  }

  List<Widget> _buildSlots(List<EmploiSlot> slots) {
    final byJour = <String, List<EmploiSlot>>{};
    for (final s in slots) { (byJour[s.jourLabel] ??= []).add(s); }
    return byJour.entries.map((e) => _JourSection(jour: e.key, slots: e.value)).toList();
  }

  static Widget _sectionLabel(String t) => Text(
    t.toUpperCase(),
    style: const TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2),
  );
}

class _BannerHeader extends StatelessWidget {
  final String? niveau;
  const _BannerHeader({this.niveau});

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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Activités & Apprentissages', style: TextStyle(color: Colors.white70, fontSize: 12)),
                const Text('Mes Activités', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                if (niveau != null)
                  Text(niveau!, style: const TextStyle(color: Colors.white60, fontSize: 12)),
              ],
            ),
          ),
          const Icon(Icons.child_care, color: Colors.white24, size: 42),
        ],
      ),
    );
  }
}

class _Domaine {
  final IconData icon;
  final String nom;
  final Color color;
  const _Domaine(this.icon, this.nom, this.color);
}

class _DomaineCard extends StatelessWidget {
  final _Domaine domaine;
  const _DomaineCard({required this.domaine});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: domaine.color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(color: domaine.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
            child: Icon(domaine.icon, color: domaine.color, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(child: Text(domaine.nom, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14))),
          Icon(Icons.chevron_right, color: domaine.color.withValues(alpha: 0.6), size: 18),
        ],
      ),
    );
  }
}

class _JourSection extends StatelessWidget {
  final String jour;
  final List<EmploiSlot> slots;
  const _JourSection({required this.jour, required this.slots});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
            child: Text(jour, style: const TextStyle(color: Color(0xFFEC4899), fontWeight: FontWeight.w700, fontSize: 13)),
          ),
          const Divider(color: Colors.white10, height: 1),
          for (final s in slots)
            Padding(
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
            ),
        ],
      ),
    );
  }
}
