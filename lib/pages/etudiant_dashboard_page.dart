import 'package:flutter/material.dart';

import '../models/annonce_model.dart';
import '../models/classe_model.dart';
import '../models/devoir_model.dart';
import '../models/note_model.dart';
import '../services/etudiant_service.dart';

class EtudiantDashboardPage extends StatelessWidget {
  const EtudiantDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        elevation: 0,
        title: const Text(
          'Tableau de bord',
          style: TextStyle(
              color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
      body: StreamBuilder<String?>(
        stream: EtudiantService.classeNomStream(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(
                    color: Color(0xFF2563EB)));
          }
          final classeNom = snap.data;
          if (classeNom == null || classeNom.isEmpty) {
            return _UnassignedBanner();
          }
          return _DashboardBody(classeNom: classeNom);
        },
      ),
    );
  }
}

class _UnassignedBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF161B22),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Row(
          children: const [
            Icon(Icons.info_outline, color: Color(0xFF2563EB), size: 28),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Vous n\'etes pas encore assigne a une classe. Contactez la Direction.',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardBody extends StatelessWidget {
  final String classeNom;
  const _DashboardBody({required this.classeNom});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final weekday = now.weekday;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        _StatsRow(classeNom: classeNom, weekday: weekday),
        const SizedBox(height: 24),
        _sectionLabel('Cours aujourd\'hui'),
        const SizedBox(height: 10),
        _TodayCoursSection(classeNom: classeNom, weekday: weekday),
        const SizedBox(height: 24),
        _sectionLabel('Devoirs recents'),
        const SizedBox(height: 10),
        _RecentDevoirsSection(classeNom: classeNom),
        const SizedBox(height: 24),
        _sectionLabel('Dernieres notes'),
        const SizedBox(height: 10),
        _RecentNotesSection(classeNom: classeNom),
        const SizedBox(height: 24),
        _sectionLabel('Annonces recentes'),
        const SizedBox(height: 10),
        const _RecentAnnoncesSection(),
      ],
    );
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

class _StatsRow extends StatelessWidget {
  final String classeNom;
  final int weekday;
  const _StatsRow({required this.classeNom, required this.weekday});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.35,
      children: [
        StreamBuilder<List<EmploiSlot>>(
          stream: EtudiantService.emploiStream(classeNom),
          builder: (context, snap) {
            final count = snap.data
                    ?.where((s) => s.jour == weekday)
                    .length ??
                0;
            return _StatCard(
              icon: Icons.schedule_outlined,
              value: '$count',
              label: "Cours aujourd'hui",
              colors: const [Color(0xFF2563EB), Color(0xFF0891B2)],
            );
          },
        ),
        StreamBuilder<int>(
          stream: EtudiantService.devoirsEnAttenteStream(classeNom),
          builder: (context, snap) {
            return _StatCard(
              icon: Icons.assignment_late_outlined,
              value: '${snap.data ?? 0}',
              label: 'Devoirs en attente',
              colors: const [Color(0xFF7C3AED), Color(0xFF6C47FF)],
            );
          },
        ),
        StreamBuilder<int>(
          stream: EtudiantService.totalNotesStream(classeNom),
          builder: (context, snap) {
            return _StatCard(
              icon: Icons.bar_chart_outlined,
              value: '${snap.data ?? 0}',
              label: 'Notes publiees',
              colors: const [Color(0xFF15803D), Color(0xFF16A34A)],
            );
          },
        ),
        StreamBuilder<int>(
          stream: EtudiantService.documentsCountStream(classeNom),
          builder: (context, snap) {
            return _StatCard(
              icon: Icons.folder_outlined,
              value: '${snap.data ?? 0}',
              label: 'Documents dispo',
              colors: const [Color(0xFFD97706), Color(0xFFB45309)],
            );
          },
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final List<Color> colors;

  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: colors),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: Colors.white, size: 19),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white38, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _TodayCoursSection extends StatelessWidget {
  final String classeNom;
  final int weekday;
  const _TodayCoursSection(
      {required this.classeNom, required this.weekday});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<EmploiSlot>>(
      stream: EtudiantService.emploiStream(classeNom),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(
                  color: Color(0xFF2563EB)));
        }
        final slots =
            (snap.data ?? []).where((s) => s.jour == weekday).toList();
        if (slots.isEmpty) {
          return _emptyState(
              Icons.event_available_outlined, 'Pas de cours aujourd\'hui');
        }
        return Column(
          children: slots.map((s) => _SlotCard(slot: s)).toList(),
        );
      },
    );
  }
}

class _SlotCard extends StatelessWidget {
  final EmploiSlot slot;
  const _SlotCard({required this.slot});

  @override
  Widget build(BuildContext context) {
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
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [Color(0xFF6C47FF), Color(0xFF2563EB)]),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${slot.heureDebut}-${slot.heureFin}',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(slot.matiere,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600)),
                if (slot.salle.isNotEmpty)
                  Text('Salle ${slot.salle}',
                      style: const TextStyle(
                          color: Colors.white38, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentDevoirsSection extends StatelessWidget {
  final String classeNom;
  const _RecentDevoirsSection({required this.classeNom});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<DevoirModel>>(
      stream: EtudiantService.devoirsStream(classeNom),
      builder: (context, dSnap) {
        return StreamBuilder<List<dynamic>>(
          stream: EtudiantService.submissionsStream(),
          builder: (context, sSnap) {
            if (dSnap.connectionState == ConnectionState.waiting) {
              return const Center(
                  child: CircularProgressIndicator(
                      color: Color(0xFF2563EB)));
            }
            final submissions = sSnap.data ?? [];
            final submittedIds = submissions
                .map((s) => s.assignmentId as String)
                .toSet();
            final pending = (dSnap.data ?? [])
                .where((d) => !submittedIds.contains(d.id))
                .take(3)
                .toList();
            if (pending.isEmpty) {
              return _emptyState(
                  Icons.assignment_turned_in_outlined,
                  'Tous les devoirs sont remis');
            }
            return Column(
              children: pending.map((d) => _DevoirMiniCard(devoir: d)).toList(),
            );
          },
        );
      },
    );
  }
}

class _DevoirMiniCard extends StatelessWidget {
  final DevoirModel devoir;
  const _DevoirMiniCard({required this.devoir});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isLate = devoir.dateLimite != null &&
        devoir.dateLimite!.isBefore(now);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: isLate
                ? Colors.red.withValues(alpha: 0.3)
                : Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(devoir.titre,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(devoir.matiere,
                    style: const TextStyle(
                        color: Colors.white38, fontSize: 12)),
              ],
            ),
          ),
          if (devoir.dateLimite != null)
            Text(
              _formatDate(devoir.dateLimite!),
              style: TextStyle(
                  color: isLate ? Colors.red : Colors.white38,
                  fontSize: 11),
            ),
        ],
      ),
    );
  }

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
}

class _RecentNotesSection extends StatelessWidget {
  final String classeNom;
  const _RecentNotesSection({required this.classeNom});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<NoteModel>>(
      stream: EtudiantService.notesStream(classeNom),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(
                  color: Color(0xFF2563EB)));
        }
        final notes = (snap.data ?? []).take(3).toList();
        if (notes.isEmpty) {
          return _emptyState(
              Icons.grade_outlined, 'Aucune note publiee');
        }
        return Column(
          children: notes.map((n) => _NoteMiniCard(note: n)).toList(),
        );
      },
    );
  }
}

class _NoteMiniCard extends StatelessWidget {
  final NoteModel note;
  const _NoteMiniCard({required this.note});

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
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(note.matiere,
                    style: const TextStyle(
                        color: Colors.white38, fontSize: 12)),
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
}

class _RecentAnnoncesSection extends StatelessWidget {
  const _RecentAnnoncesSection();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AnnonceModel>>(
      stream: EtudiantService.annoncesStream(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(
                  color: Color(0xFF2563EB)));
        }
        final annonces = (snap.data ?? []).take(2).toList();
        if (annonces.isEmpty) {
          return _emptyState(
              Icons.campaign_outlined, 'Aucune annonce');
        }
        return Column(
          children:
              annonces.map((a) => _AnnonceMiniCard(annonce: a)).toList(),
        );
      },
    );
  }
}

class _AnnonceMiniCard extends StatelessWidget {
  final AnnonceModel annonce;
  const _AnnonceMiniCard({required this.annonce});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(annonce.titre,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(
            annonce.contenu,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white38, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

Widget _emptyState(IconData icon, String message) {
  return Container(
    padding: const EdgeInsets.symmetric(vertical: 24),
    child: Column(
      children: [
        Icon(icon, color: Colors.white24, size: 36),
        const SizedBox(height: 8),
        Text(message,
            style: const TextStyle(color: Colors.white38, fontSize: 13)),
      ],
    ),
  );
}
