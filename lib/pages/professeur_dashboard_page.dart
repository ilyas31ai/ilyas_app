import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/classe_model.dart';
import '../models/rdv_model.dart';
import '../services/professeur_service.dart';
import '../services/rdv_service.dart';
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
          _sectionLabel('Statistiques pédagogiques'),
          const SizedBox(height: 10),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.35,
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
          const SizedBox(height: 12),
          _ElevesEnDifficulteCard(),
          const SizedBox(height: 12),
          _RdvEnAttenteCard(),
          const SizedBox(height: 24),
          _sectionLabel('Prochains cours'),
          const SizedBox(height: 10),
          _ProchainsCours(),
          const SizedBox(height: 24),
          _sectionLabel('Alertes pédagogiques'),
          const SizedBox(height: 10),
          _AlertesPedagogiques(),
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
        if (snap.hasError) {
          return DashboardStatCard(icon: icon, value: '—', label: label, colors: colors);
        }
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

// ─── Carte "Élèves en difficulté" (pleine largeur) ───────────────────────────

class _ElevesEnDifficulteCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: ProfesseurService.totalElevesEnDifficulteStream(),
      builder: (context, snap) {
        final count = snap.data ?? 0;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFF161B22),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: count > 0
                  ? const Color(0xFFDC2626).withValues(alpha: 0.3)
                  : Colors.white.withValues(alpha: 0.06),
            ),
          ),
          child: Row(children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: count > 0
                    ? [const Color(0xFFDC2626), const Color(0xFFB91C1C)]
                    : [const Color(0xFF15803D), const Color(0xFF16A34A)]),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                count > 0
                    ? Icons.warning_amber_outlined
                    : Icons.check_circle_outline,
                color: Colors.white, size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    count > 0
                        ? '$count élève${count > 1 ? 's' : ''} en difficulté'
                        : 'Tous les élèves à jour',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14),
                  ),
                  Text(
                    count > 0
                        ? 'Notions 🔴 détectées par l\'IA — voir les alertes ci-dessous'
                        : 'Aucune notion critique détectée par l\'IA',
                    style: const TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                ],
              ),
            ),
            Text(
              '$count',
              style: TextStyle(
                color: count > 0
                    ? const Color(0xFFDC2626)
                    : const Color(0xFF16A34A),
                fontSize: 28, fontWeight: FontWeight.bold,
              ),
            ),
          ]),
        );
      },
    );
  }
}

// ─── RDV en attente ──────────────────────────────────────────────────────────

class _RdvEnAttenteCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<RdvModel>>(
      stream: RdvService.rdvProfesseurStream(),
      builder: (context, snap) {
        if (snap.hasError) return const SizedBox.shrink();
        final rdvs = snap.data ?? [];
        final enAttente = rdvs.where((r) => r.statut == RdvStatut.demande).length;
        if (enAttente == 0) return const SizedBox.shrink();
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFF161B22),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF2563EB).withValues(alpha: 0.4)),
          ),
          child: Row(children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [Color(0xFF1E3A5F), Color(0xFF2563EB)]),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.event_note_outlined, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  '$enAttente demande${enAttente > 1 ? 's' : ''} de RDV en attente',
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const Text(
                  'Appuyez pour gérer les rendez-vous parents',
                  style: TextStyle(color: Colors.white38, fontSize: 11),
                ),
              ]),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF2563EB).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '$enAttente',
                style: const TextStyle(
                    color: Color(0xFF2563EB),
                    fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ]),
        );
      },
    );
  }
}

// ─── Alertes pédagogiques ─────────────────────────────────────────────────────

class _AlerteData {
  final String nom, classeNom;
  final int aRetravailler;
  final Map<String, dynamic> parMatiere;
  const _AlerteData({
    required this.nom,
    required this.classeNom,
    required this.aRetravailler,
    required this.parMatiere,
  });
}

class _AlertesPedagogiques extends StatefulWidget {
  @override
  State<_AlertesPedagogiques> createState() => _AlertesPedagogiquesState();
}

class _AlertesPedagogiquesState extends State<_AlertesPedagogiques> {
  List<_AlerteData>? _alertes;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final classes = await ProfesseurService.classesStream().first;
    if (!mounted) return;
    final db = FirebaseFirestore.instance;
    final List<_AlerteData> result = [];
    for (final classe in classes) {
      final snap = await db
          .collection('users')
          .where('role', isEqualTo: 'eleve')
          .where('classeNom', isEqualTo: classe.nom)
          .where('maitrise_en_difficulte', isEqualTo: true)
          .get();
      for (final doc in snap.docs) {
        final data    = doc.data();
        final summary = (data['maitrise_summary'] as Map<String, dynamic>?) ?? {};
        final totaux  = (summary['totaux'] as Map<String, dynamic>?) ?? {};
        final aRetrav = (totaux['aRetravailler'] as int?) ?? 0;
        if (aRetrav > 0) {
          result.add(_AlerteData(
            nom           : data['displayName'] as String? ?? 'Élève',
            classeNom     : classe.nom,
            aRetravailler : aRetrav,
            parMatiere    : (summary['parMatiere'] as Map<String, dynamic>?) ?? {},
          ));
        }
      }
    }
    result.sort((a, b) => b.aRetravailler.compareTo(a.aRetravailler));
    if (mounted) setState(() => _alertes = result);
  }

  @override
  Widget build(BuildContext context) {
    if (_alertes == null) return const _EmptyCard('Chargement des alertes…');
    if (_alertes!.isEmpty) {
      return const _EmptyCard('Aucune alerte · Tous les élèves sont à jour ✅');
    }
    return Column(
      children: _alertes!.take(5).map((a) => _AlerteCard(data: a)).toList(),
    );
  }
}

class _AlerteCard extends StatelessWidget {
  final _AlerteData data;
  const _AlerteCard({required this.data});

  @override
  Widget build(BuildContext context) {
    String? worstMatiere;
    int worstCount = 0;
    data.parMatiere.forEach((m, v) {
      final n = ((v as Map<String, dynamic>?))?['aRetravailler'] as int? ?? 0;
      if (n > worstCount) { worstCount = n; worstMatiere = m; }
    });
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: const Color(0xFFDC2626).withValues(alpha: 0.2)),
      ),
      child: Row(children: [
        const Text('🔴', style: TextStyle(fontSize: 18)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(data.nom,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 13)),
            Text(
              '${data.classeNom}'
              '${worstMatiere != null ? ' · $worstMatiere' : ''}'
              ' · ${data.aRetravailler} notion${data.aRetravailler > 1 ? 's' : ''} à retravailler',
              style: const TextStyle(color: Colors.white38, fontSize: 12),
            ),
          ]),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xFFDC2626).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '${data.aRetravailler}🔴',
            style: const TextStyle(
                color: Color(0xFFDC2626),
                fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ),
      ]),
    );
  }
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
