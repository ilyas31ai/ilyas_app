import 'package:flutter/material.dart';

import '../models/devoir_model.dart';
import '../models/classe_model.dart';
import '../services/professeur_service.dart';
import '../widgets/dashboard_stat_card.dart';

class ProfesseurDashboardPage extends StatelessWidget {
  const ProfesseurDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        elevation: 0,
        title: const Text('Tableau de bord',
            style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          _sectionLabel('Statistiques'),
          const SizedBox(height: 10),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.1,
            children: [
              _statStream(
                stream: ProfesseurService.totalClassesStream(),
                icon: Icons.class_outlined,
                label: 'Classes',
                colors: const [Color(0xFF0F766E), Color(0xFF0891B2)],
              ),
              _statStream(
                stream: ProfesseurService.totalElevesStream(),
                icon: Icons.groups_outlined,
                label: 'Élèves',
                colors: const [Color(0xFF2563EB), Color(0xFF0891B2)],
              ),
              _statStream(
                stream: ProfesseurService.totalDevoirsStream(),
                icon: Icons.assignment_outlined,
                label: 'Devoirs envoyés',
                colors: const [Color(0xFF6C47FF), Color(0xFF2563EB)],
              ),
              _statStream(
                stream: ProfesseurService.totalDocumentsStream(),
                icon: Icons.folder_open_outlined,
                label: 'Documents déposés',
                colors: const [Color(0xFF15803D), Color(0xFF16A34A)],
              ),
            ],
          ),
          const SizedBox(height: 24),
          _sectionLabel('Prochains cours'),
          const SizedBox(height: 10),
          _ProchainsCours(),
          const SizedBox(height: 24),
          _sectionLabel('Derniers devoirs envoyés'),
          const SizedBox(height: 10),
          _DerniersDevoirs(),
        ],
      ),
    );
  }

  Widget _statStream({
    required Stream<int> stream,
    required IconData icon,
    required String label,
    required List<Color> colors,
  }) {
    return StreamBuilder<int>(
      stream: stream,
      builder: (context, snap) {
        final value = snap.hasData ? snap.data!.toString() : '0';
        return DashboardStatCard(
            icon: icon, value: value, label: label, colors: colors);
      },
    );
  }

  Widget _sectionLabel(String text) => Text(
        text.toUpperCase(),
        style: const TextStyle(
            color: Colors.white38,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2),
      );
}

// ─── Prochains cours ──────────────────────────────────────────────────────────

class _ProchainsCours extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final today = DateTime.now().weekday; // 1=Lundi … 7=Dimanche
    return StreamBuilder<List<EmploiSlot>>(
      stream: ProfesseurService.emploiStream(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const _EmptyCard('Chargement…');
        }
        final slots = snap.data ?? [];
        if (slots.isEmpty) {
          return const _EmptyCard('Aucun cours planifié.\nAjoutez votre emploi du temps.');
        }
        // Affiche les cours du jour courant ou du prochain jour ouvré
        final prochains = _getProchainsCours(slots, today);
        return Column(
          children: prochains
              .map((s) => _CoursCard(slot: s))
              .toList(),
        );
      },
    );
  }

  List<EmploiSlot> _getProchainsCours(List<EmploiSlot> all, int today) {
    // Cherche les cours du jour courant
    var jour = today > 5 ? 1 : today;
    for (int offset = 0; offset < 5; offset++) {
      final j = ((jour - 1 + offset) % 5) + 1;
      final cours = all.where((s) => s.jour == j).take(3).toList();
      if (cours.isNotEmpty) return cours;
    }
    return all.take(3).toList();
  }
}

class _CoursCard extends StatelessWidget {
  final EmploiSlot slot;
  const _CoursCard({required this.slot});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [Color(0xFF0F766E), Color(0xFF0891B2)]),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(slot.jourLabel.substring(0, 3),
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(slot.matiere,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14)),
                Text(
                  '${slot.heureDebut} – ${slot.heureFin} · ${slot.classeNom}'
                  '${slot.salle.isNotEmpty ? ' · ${slot.salle}' : ''}',
                  style:
                      const TextStyle(color: Colors.white38, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Derniers devoirs ─────────────────────────────────────────────────────────

class _DerniersDevoirs extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<DevoirModel>>(
      stream: ProfesseurService.devoirsStream(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const _EmptyCard('Chargement…');
        }
        final devoirs = (snap.data ?? []).take(3).toList();
        if (devoirs.isEmpty) {
          return const _EmptyCard('Aucun devoir envoyé pour le moment.');
        }
        return Column(
          children: devoirs.map((d) => _DevoirTile(devoir: d)).toList(),
        );
      },
    );
  }
}

class _DevoirTile extends StatelessWidget {
  final DevoirModel devoir;
  const _DevoirTile({required this.devoir});

  @override
  Widget build(BuildContext context) {
    final limit = devoir.dateLimite;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [Color(0xFF6C47FF), Color(0xFF2563EB)]),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.assignment_outlined,
                color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(devoir.titre,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                Text(
                  '${devoir.classeNom} · ${devoir.matiere}'
                  '${limit != null ? ' · Limite : ${_fmt(limit)}' : ''}',
                  style: const TextStyle(color: Colors.white38, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
}

class _EmptyCard extends StatelessWidget {
  final String message;
  const _EmptyCard(this.message);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Center(
        child: Text(message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white38, fontSize: 13)),
      ),
    );
  }
}
