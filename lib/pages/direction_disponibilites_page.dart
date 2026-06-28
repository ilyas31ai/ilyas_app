import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/disponibilite_model.dart';
import '../models/remplacement_model.dart';
import '../models/user_model.dart';
import '../services/remplacement_service.dart';
import '../services/user_service.dart';

class DirectionDisponibilitesPage extends StatefulWidget {
  const DirectionDisponibilitesPage({super.key});

  @override
  State<DirectionDisponibilitesPage> createState() =>
      _DirectionDisponibilitesPageState();
}

class _DirectionDisponibilitesPageState
    extends State<DirectionDisponibilitesPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        elevation: 0,
        title: const Text(
          'Disponibilités & Remplacements',
          style: TextStyle(
              color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF6C47FF),
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white38,
          labelStyle:
              const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          isScrollable: true,
          tabs: const [
            Tab(text: 'Tableau de bord'),
            Tab(text: 'Disponibilités'),
            Tab(text: 'Remplacements'),
            Tab(text: 'Calendrier'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _TabDashboard(),
          _TabDisponibilites(),
          _TabRemplacements(),
          _TabCalendrier(),
        ],
      ),
    );
  }
}

// ─── Tab 1: Tableau de bord ───────────────────────────────────────────────────

class _TabDashboard extends StatelessWidget {
  const _TabDashboard();

  @override
  Widget build(BuildContext context) {
    final todayStr = RemplacementService.todayStr();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6C47FF), Color(0xFF2563EB)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Gestion des disponibilités',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Aujourd\'hui : $todayStr',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.schedule,
                    color: Colors.white24, size: 48),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Stats grid
          FutureBuilder<Map<String, int>>(
            future: RemplacementService.statsRapides(),
            builder: (ctx, snap) {
              final s = snap.data ??
                  {
                    'disponibles': 0,
                    'absents': 0,
                    'courssSansEnseignant': 0,
                    'enAttente': 0,
                    'valides': 0,
                  };
              return GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.8,
                children: [
                  _StatCard(
                    label: 'Disponibles',
                    value: '${s['disponibles'] ?? 0}',
                    icon: Icons.check_circle_outline,
                    color: const Color(0xFF10B981),
                  ),
                  _StatCard(
                    label: 'Absents',
                    value: '${s['absents'] ?? 0}',
                    icon: Icons.person_off_outlined,
                    color: const Color(0xFFEF4444),
                  ),
                  _StatCard(
                    label: 'En attente',
                    value: '${s['enAttente'] ?? 0}',
                    icon: Icons.hourglass_empty,
                    color: const Color(0xFFF59E0B),
                  ),
                  _StatCard(
                    label: 'Validés auj.',
                    value: '${s['valides'] ?? 0}',
                    icon: Icons.verified_outlined,
                    color: const Color(0xFF2563EB),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 20),
          // Remplacements urgents
          const _SectionLabel(text: 'Remplacements urgents'),
          const SizedBox(height: 8),
          StreamBuilder<List<Remplacement>>(
            stream: RemplacementService.remplacementsDuJourStream(todayStr),
            builder: (ctx, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(
                    child: CircularProgressIndicator(
                        color: Color(0xFF6C47FF), strokeWidth: 2));
              }
              final list = (snap.data ?? [])
                  .where((r) =>
                      r.statut == RemplacementStatut.enAttente ||
                      r.statut == RemplacementStatut.propose)
                  .toList();
              if (list.isEmpty) {
                return _EmptyState(
                    icon: Icons.check_circle_outline,
                    message: 'Aucun remplacement urgent aujourd\'hui');
              }
              return Column(
                children: list
                    .map((r) => _UrgentCard(
                          remplacement: r,
                          onAction: () => _showProposerDialog(ctx, r),
                        ))
                    .toList(),
              );
            },
          ),
          const SizedBox(height: 20),
          // Absences déclarées
          const _SectionLabel(text: 'Absences déclarées aujourd\'hui'),
          const SizedBox(height: 8),
          _AbsencesDuJour(date: todayStr),
        ],
      ),
    );
  }

  void _showProposerDialog(BuildContext context, Remplacement r) {
    showDialog(
      context: context,
      builder: (_) => _ProposerRemplacantDialog(remplacement: r),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _StatCard(
      {required this.label,
      required this.value,
      required this.icon,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(value,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold)),
              Text(label,
                  style:
                      const TextStyle(color: Colors.white54, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }
}

class _UrgentCard extends StatelessWidget {
  final Remplacement remplacement;
  final VoidCallback onAction;
  const _UrgentCard({required this.remplacement, required this.onAction});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.warning_amber_outlined,
                color: Color(0xFFF59E0B), size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(remplacement.professeurAbsentNom,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 13)),
                Text(
                    '${remplacement.classeNom} · ${remplacement.matiere} · ${remplacement.heureDebut}–${remplacement.heureFin}',
                    style:
                        const TextStyle(color: Colors.white54, fontSize: 11)),
              ],
            ),
          ),
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              backgroundColor:
                  const Color(0xFF6C47FF).withValues(alpha: 0.2),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Gérer',
                style: TextStyle(color: Color(0xFF6C47FF), fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

class _AbsencesDuJour extends StatelessWidget {
  final String date;
  const _AbsencesDuJour({required this.date});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<DisponibiliteEnseignant>>(
      stream: RemplacementService.allDisponibilitesStream(),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(
                  color: Color(0xFF6C47FF), strokeWidth: 2));
        }
        final dispos = snap.data ?? [];
        if (dispos.isEmpty) {
          return _EmptyState(
              icon: Icons.event_available_outlined,
              message: 'Aucune absence déclarée');
        }
        return Column(
          children: dispos.map((d) => _AbsenceTile(dispo: d, date: date)).toList(),
        );
      },
    );
  }
}

class _AbsenceTile extends StatelessWidget {
  final DisponibiliteEnseignant dispo;
  final String date;
  const _AbsenceTile({required this.dispo, required this.date});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('disponibilites')
          .doc(dispo.uid)
          .collection('absences')
          .where('date', isEqualTo: date)
          .snapshots(),
      builder: (ctx, snap) {
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return const SizedBox.shrink();
        }
        final absence = docs.first.data() as Map<String, dynamic>;
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF161B22),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: const Color(0xFFEF4444).withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    (dispo.nom.isNotEmpty ? dispo.nom[0] : '?').toUpperCase(),
                    style: const TextStyle(
                        color: Color(0xFFEF4444),
                        fontWeight: FontWeight.bold,
                        fontSize: 15),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(dispo.nom,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 13)),
                    Text(
                        'Absent · Motif : ${(absence['motif'] as String?) ?? ''}',
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 11)),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text('Absent',
                    style: TextStyle(
                        color: Color(0xFFEF4444), fontSize: 10)),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─── Tab 2: Disponibilités ────────────────────────────────────────────────────

class _TabDisponibilites extends StatefulWidget {
  const _TabDisponibilites();

  @override
  State<_TabDisponibilites> createState() => _TabDisponibilitesState();
}

class _TabDisponibilitesState extends State<_TabDisponibilites> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF6C47FF),
        icon: const Icon(Icons.person_off_outlined, color: Colors.white),
        label:
            const Text('Déclarer absence', style: TextStyle(color: Colors.white)),
        onPressed: () =>
            showDialog(context: context, builder: (_) => const _AbsenceDialog()),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
            child: TextField(
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Rechercher un enseignant…',
                hintStyle: const TextStyle(color: Colors.white38),
                prefixIcon:
                    const Icon(Icons.search, color: Colors.white38, size: 20),
                filled: true,
                fillColor: const Color(0xFF161B22),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (v) => setState(() => _search = v.trim().toLowerCase()),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<UserModel>>(
              stream: UserService.usersByRoleStream('professeur'),
              builder: (ctx, profSnap) {
                return StreamBuilder<List<DisponibiliteEnseignant>>(
                  stream: RemplacementService.allDisponibilitesStream(),
                  builder: (ctx2, dispoSnap) {
                    if (profSnap.connectionState == ConnectionState.waiting) {
                      return const Center(
                          child: CircularProgressIndicator(
                              color: Color(0xFF6C47FF)));
                    }
                    final profs = (profSnap.data ?? []).where((p) {
                      if (_search.isEmpty) {
                        return true;
                      }
                      return (p.displayName.toLowerCase()).contains(_search) ||
                          (p.matiere ?? '').toLowerCase().contains(_search);
                    }).toList();

                    final dispoMap = {
                      for (final d in dispoSnap.data ?? []) d.uid: d
                    };

                    if (profs.isEmpty) {
                      return _EmptyState(
                          icon: Icons.people_outline,
                          message: 'Aucun enseignant trouvé');
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.fromLTRB(14, 4, 14, 80),
                      itemCount: profs.length,
                      itemBuilder: (ctx3, i) {
                        final prof = profs[i];
                        final dispo = dispoMap[prof.uid];
                        return _EnseignantDispoCard(
                          prof: prof,
                          dispo: dispo,
                          onEdit: () => showDialog(
                            context: context,
                            builder: (_) => _DispoEditDialog(
                              dispo: dispo,
                              uid: prof.uid,
                              nom: prof.displayName,
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _EnseignantDispoCard extends StatelessWidget {
  final UserModel prof;
  final DisponibiliteEnseignant? dispo;
  final VoidCallback onEdit;

  const _EnseignantDispoCard(
      {required this.prof, this.dispo, required this.onEdit});

  static const _joursAbrev = {
    'Lundi': 'Lun',
    'Mardi': 'Mar',
    'Mercredi': 'Mer',
    'Jeudi': 'Jeu',
    'Vendredi': 'Ven',
    'Samedi': 'Sam',
  };

  @override
  Widget build(BuildContext context) {
    final jours = dispo?.jours ?? [];
    final disponible = dispo?.disponibleAujourdhui ?? false;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: const Color(0xFF6C47FF).withValues(alpha: 0.2),
                child: Text(
                  prof.displayName.isNotEmpty
                      ? prof.displayName[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                      color: Color(0xFF6C47FF),
                      fontWeight: FontWeight.bold,
                      fontSize: 14),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(prof.displayName,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 13)),
                        const SizedBox(width: 6),
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: disponible
                                ? const Color(0xFF10B981)
                                : const Color(0xFFEF4444),
                          ),
                        ),
                      ],
                    ),
                    if ((prof.matiere ?? '').isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(top: 3),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2563EB).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(prof.matiere ?? '',
                            style: const TextStyle(
                                color: Color(0xFF2563EB), fontSize: 10)),
                      ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined,
                    color: Colors.white38, size: 18),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          if (jours.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 5,
              children: _joursAbrev.entries.map((e) {
                final active = jours.contains(e.key);
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: active
                        ? const Color(0xFF6C47FF).withValues(alpha: 0.2)
                        : const Color(0xFF21262D),
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(
                      color: active
                          ? const Color(0xFF6C47FF).withValues(alpha: 0.5)
                          : Colors.transparent,
                    ),
                  ),
                  child: Text(e.value,
                      style: TextStyle(
                          color: active ? const Color(0xFF6C47FF) : Colors.white38,
                          fontSize: 10,
                          fontWeight: FontWeight.w600)),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Tab 3: Remplacements ──────────────────────────────────────────────────────

class _TabRemplacements extends StatefulWidget {
  const _TabRemplacements();

  @override
  State<_TabRemplacements> createState() => _TabRemplacementsState();
}

class _TabRemplacementsState extends State<_TabRemplacements> {
  RemplacementStatut? _filter;

  static const _filters = [
    null,
    RemplacementStatut.enAttente,
    RemplacementStatut.propose,
    RemplacementStatut.accepte,
    RemplacementStatut.confirme,
    RemplacementStatut.termine,
  ];
  static const _filterLabels = [
    'Tous',
    'En attente',
    'Proposé',
    'Accepté',
    'Confirmé',
    'Terminé',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF6C47FF),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Nouveau remplacement',
            style: TextStyle(color: Colors.white)),
        onPressed: () => showDialog(
            context: context,
            builder: (_) => const _CreateRemplacementDialog()),
      ),
      body: Column(
        children: [
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              itemCount: _filters.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (ctx, i) {
                final active = _filter == _filters[i];
                return GestureDetector(
                  onTap: () => setState(() => _filter = _filters[i]),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: active
                          ? const Color(0xFF6C47FF)
                          : const Color(0xFF161B22),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: active
                              ? const Color(0xFF6C47FF)
                              : Colors.white12),
                    ),
                    child: Text(_filterLabels[i],
                        style: TextStyle(
                            color: active ? Colors.white : Colors.white54,
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                  ),
                );
              },
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Remplacement>>(
              stream:
                  RemplacementService.remplacementsStream(statut: _filter),
              builder: (ctx, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child: CircularProgressIndicator(
                          color: Color(0xFF6C47FF)));
                }
                final list = snap.data ?? [];
                if (list.isEmpty) {
                  return _EmptyState(
                      icon: Icons.swap_horiz,
                      message: 'Aucun remplacement trouvé');
                }
                return ListView.builder(
                  padding:
                      const EdgeInsets.fromLTRB(14, 6, 14, 80),
                  itemCount: list.length,
                  itemBuilder: (ctx2, i) => _RemplacementCard(
                    remplacement: list[i],
                    onProposer: () => showDialog(
                      context: context,
                      builder: (_) =>
                          _ProposerRemplacantDialog(remplacement: list[i]),
                    ),
                    onValider: () => RemplacementService.updateStatut(
                        list[i].id, RemplacementStatut.confirme),
                    onAnnuler: () => RemplacementService.updateStatut(
                        list[i].id, RemplacementStatut.annule),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _RemplacementCard extends StatelessWidget {
  final Remplacement remplacement;
  final VoidCallback onProposer;
  final VoidCallback onValider;
  final VoidCallback onAnnuler;

  const _RemplacementCard({
    required this.remplacement,
    required this.onProposer,
    required this.onValider,
    required this.onAnnuler,
  });

  @override
  Widget build(BuildContext context) {
    final r = remplacement;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(r.professeurAbsentNom,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14)),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: r.statutColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(r.statutLabel,
                    style: TextStyle(color: r.statutColor, fontSize: 11)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              _InfoChip(
                  icon: Icons.school_outlined, label: r.classeNom),
              _InfoChip(icon: Icons.book_outlined, label: r.matiere),
              _InfoChip(
                  icon: Icons.calendar_today_outlined, label: r.date),
              _InfoChip(
                  icon: Icons.access_time_outlined,
                  label: '${r.heureDebut}–${r.heureFin}'),
            ],
          ),
          if (r.professeurRemplacantNom != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.swap_horiz,
                    color: Colors.white38, size: 14),
                const SizedBox(width: 4),
                Text('Remplaçant : ${r.professeurRemplacantNom}',
                    style:
                        const TextStyle(color: Colors.white54, fontSize: 12)),
              ],
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              if (r.statut == RemplacementStatut.enAttente)
                _ActionBtn(
                    label: 'Proposer remplaçant',
                    color: const Color(0xFF6C47FF),
                    onTap: onProposer),
              if (r.statut == RemplacementStatut.propose ||
                  r.statut == RemplacementStatut.accepte) ...[
                _ActionBtn(
                    label: 'Valider',
                    color: const Color(0xFF10B981),
                    onTap: onValider),
                const SizedBox(width: 8),
              ],
              if (r.statut != RemplacementStatut.annule &&
                  r.statut != RemplacementStatut.termine)
                _ActionBtn(
                    label: 'Annuler',
                    color: const Color(0xFFEF4444),
                    onTap: onAnnuler),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFF1F2937),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white38, size: 11),
          const SizedBox(width: 4),
          Text(label,
              style:
                  const TextStyle(color: Colors.white54, fontSize: 11)),
        ],
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionBtn(
      {required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Text(label,
            style: TextStyle(
                color: color, fontSize: 11, fontWeight: FontWeight.w600)),
      ),
    );
  }
}

// ─── Tab 4: Calendrier ─────────────────────────────────────────────────────────

class _TabCalendrier extends StatefulWidget {
  const _TabCalendrier();

  @override
  State<_TabCalendrier> createState() => _TabCalendrierState();
}

class _TabCalendrierState extends State<_TabCalendrier> {
  late DateTime _weekStart;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _weekStart = now.subtract(Duration(days: now.weekday - 1));
  }

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _todayStr() => _fmt(DateTime.now());

  @override
  Widget build(BuildContext context) {
    final days =
        List.generate(7, (i) => _weekStart.add(Duration(days: i)));
    final dayStrs = days.map(_fmt).toList();
    const joursAbrev = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];
    final today = _todayStr();

    return Column(
      children: [
        // Navigation semaine
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
          child: Row(
            children: [
              IconButton(
                onPressed: () => setState(() =>
                    _weekStart = _weekStart.subtract(const Duration(days: 7))),
                icon: const Icon(Icons.chevron_left, color: Colors.white54),
              ),
              Expanded(
                child: Text(
                  'Semaine du ${days[0].day}/${days[0].month}/${days[0].year}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14),
                ),
              ),
              IconButton(
                onPressed: () => setState(() =>
                    _weekStart = _weekStart.add(const Duration(days: 7))),
                icon: const Icon(Icons.chevron_right, color: Colors.white54),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // Day columns
        StreamBuilder<List<Remplacement>>(
          stream: RemplacementService.remplacementsStream(),
          builder: (ctx, remSnap) {
            return StreamBuilder<List<DisponibiliteEnseignant>>(
              stream: RemplacementService.allDisponibilitesStream(),
              builder: (ctx2, dispoSnap) {
                final remplacements = remSnap.data ?? [];
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Row(
                    children: List.generate(7, (i) {
                      final dayStr = dayStrs[i];
                      final isToday = dayStr == today;
                      final dayName = joursAbrev[i];
                      final dayNum = days[i].day;

                      // Count remplacements for this day
                      final dayRempls = remplacements
                          .where((r) => r.date == dayStr)
                          .toList();
                      final enAttente = dayRempls
                          .where((r) =>
                              r.statut == RemplacementStatut.enAttente)
                          .length;
                      final confirmes = dayRempls
                          .where((r) =>
                              r.statut == RemplacementStatut.confirme ||
                              r.statut == RemplacementStatut.accepte)
                          .length;

                      return GestureDetector(
                        onTap: () => _showDayDetails(
                            context, dayStr, dayName, dayRempls),
                        child: Container(
                          width: 90,
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isToday
                                ? const Color(0xFF1F2937)
                                : const Color(0xFF161B22),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isToday
                                  ? const Color(0xFF6C47FF)
                                  : Colors.white.withValues(alpha: 0.06),
                              width: isToday ? 2 : 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(dayName,
                                  style: TextStyle(
                                      color: isToday
                                          ? const Color(0xFF6C47FF)
                                          : Colors.white54,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600)),
                              Text('$dayNum',
                                  style: TextStyle(
                                      color: isToday
                                          ? Colors.white
                                          : Colors.white70,
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              _CalDot(
                                  color: const Color(0xFFF59E0B),
                                  label: '$enAttente att.',
                                  visible: enAttente > 0),
                              _CalDot(
                                  color: const Color(0xFF10B981),
                                  label: '$confirmes conf.',
                                  visible: confirmes > 0),
                              if (enAttente == 0 && confirmes == 0)
                                const Text('Libre',
                                    style: TextStyle(
                                        color: Colors.white24,
                                        fontSize: 10)),
                            ],
                          ),
                        ),
                      );
                    }),
                  ),
                );
              },
            );
          },
        ),
        const SizedBox(height: 14),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 14),
          child: _SectionLabel(text: 'Légende'),
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              _LegendItem(
                  color: const Color(0xFFF59E0B), label: 'En attente'),
              const SizedBox(width: 14),
              _LegendItem(
                  color: const Color(0xFF10B981), label: 'Confirmé'),
              const SizedBox(width: 14),
              _LegendItem(
                  color: const Color(0xFF6C47FF),
                  label: 'Aujourd\'hui'),
            ],
          ),
        ),
      ],
    );
  }

  void _showDayDetails(BuildContext context, String dateStr, String dayName,
      List<Remplacement> remplacements) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF161B22),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _DayBottomSheet(
          dateStr: dateStr,
          dayName: dayName,
          remplacements: remplacements),
    );
  }
}

class _CalDot extends StatelessWidget {
  final Color color;
  final String label;
  final bool visible;
  const _CalDot(
      {required this.color, required this.label, required this.visible});

  @override
  Widget build(BuildContext context) {
    if (!visible) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
              width: 6,
              height: 6,
              decoration:
                  BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 3),
          Text(label,
              style: TextStyle(color: color, fontSize: 9)),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 5),
        Text(label,
            style: const TextStyle(color: Colors.white54, fontSize: 12)),
      ],
    );
  }
}

class _DayBottomSheet extends StatelessWidget {
  final String dateStr;
  final String dayName;
  final List<Remplacement> remplacements;
  const _DayBottomSheet(
      {required this.dateStr,
      required this.dayName,
      required this.remplacements});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('$dayName — $dateStr',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white38),
                onPressed: () => Navigator.pop(context),
              )
            ],
          ),
          const SizedBox(height: 8),
          if (remplacements.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                  child: Text('Aucun remplacement ce jour',
                      style: TextStyle(color: Colors.white38))),
            )
          else
            ...remplacements.map((r) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                            color: r.statutColor, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                            '${r.professeurAbsentNom} → ${r.classeNom} · ${r.matiere} · ${r.heureDebut}–${r.heureFin}',
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 13)),
                      ),
                    ],
                  ),
                )),
        ],
      ),
    );
  }
}

// ─── Dialogs ──────────────────────────────────────────────────────────────────

class _DispoEditDialog extends StatefulWidget {
  final DisponibiliteEnseignant? dispo;
  final String uid;
  final String nom;
  const _DispoEditDialog({this.dispo, required this.uid, required this.nom});

  @override
  State<_DispoEditDialog> createState() => _DispoEditDialogState();
}

class _DispoEditDialogState extends State<_DispoEditDialog> {
  static const _jours = [
    'Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi'
  ];
  late List<String> _selectedJours;
  late List<CreneauHoraire> _creneaux;
  late List<String> _matieres;
  late bool _disponibleAujourdhui;
  final _matCtrl = TextEditingController();
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _selectedJours = List<String>.from(widget.dispo?.jours ?? []);
    _creneaux = List<CreneauHoraire>.from(widget.dispo?.creneaux ?? []);
    _matieres = List<String>.from(widget.dispo?.matieres ?? []);
    _disponibleAujourdhui = widget.dispo?.disponibleAujourdhui ?? true;
  }

  @override
  void dispose() {
    _matCtrl.dispose();
    super.dispose();
  }

  Future<void> _addCreneau() async {
    final jour = _selectedJours.isNotEmpty ? _selectedJours.first : 'Lundi';
    final debut = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 8, minute: 0),
    );
    if (debut == null) {
      return;
    }
    if (!mounted) {
      return;
    }
    final fin = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: debut.hour + 2, minute: 0),
    );
    if (fin == null) {
      return;
    }
    setState(() {
      _creneaux.add(CreneauHoraire(
        jour: jour,
        heureDebut:
            '${debut.hour.toString().padLeft(2, '0')}:${debut.minute.toString().padLeft(2, '0')}',
        heureFin:
            '${fin.hour.toString().padLeft(2, '0')}:${fin.minute.toString().padLeft(2, '0')}',
      ));
    });
  }

  Future<void> _save() async {
    setState(() => _loading = true);
    final dispo = DisponibiliteEnseignant(
      uid: widget.uid,
      nom: widget.nom,
      email: widget.dispo?.email ?? '',
      jours: _selectedJours,
      creneaux: _creneaux,
      matieres: _matieres,
      niveaux: widget.dispo?.niveaux ?? [],
      classes: widget.dispo?.classes ?? [],
      disponibleAujourdhui: _disponibleAujourdhui,
    );
    await RemplacementService.saveDisponibilite(widget.uid, dispo);
    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF161B22),
      title: Text('Disponibilités — ${widget.nom}',
          style:
              const TextStyle(color: Colors.white, fontSize: 15)),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Jours de présence',
                  style: TextStyle(color: Colors.white70, fontSize: 13)),
              const SizedBox(height: 4),
              ..._jours.map((j) => CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(j,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 13)),
                    value: _selectedJours.contains(j),
                    activeColor: const Color(0xFF6C47FF),
                    onChanged: (v) => setState(() {
                      if (v == true) {
                        _selectedJours.add(j);
                      } else {
                        _selectedJours.remove(j);
                      }
                    }),
                  )),
              const SizedBox(height: 8),
              CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: const Text('Disponible aujourd\'hui',
                    style: TextStyle(color: Colors.white70, fontSize: 13)),
                value: _disponibleAujourdhui,
                activeColor: const Color(0xFF10B981),
                onChanged: (v) =>
                    setState(() => _disponibleAujourdhui = v ?? true),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Text('Créneaux',
                      style:
                          TextStyle(color: Colors.white70, fontSize: 13)),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: _addCreneau,
                    icon: const Icon(Icons.add,
                        color: Color(0xFF6C47FF), size: 16),
                    label: const Text('Ajouter',
                        style: TextStyle(
                            color: Color(0xFF6C47FF), fontSize: 12)),
                    style: TextButton.styleFrom(
                        padding: EdgeInsets.zero),
                  ),
                ],
              ),
              ..._creneaux.asMap().entries.map((e) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        const Icon(Icons.access_time,
                            color: Colors.white38, size: 14),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                              '${e.value.jour} ${e.value.heureDebut}–${e.value.heureFin}',
                              style: const TextStyle(
                                  color: Colors.white60,
                                  fontSize: 12)),
                        ),
                        GestureDetector(
                          onTap: () => setState(
                              () => _creneaux.removeAt(e.key)),
                          child: const Icon(Icons.close,
                              color: Colors.white38, size: 14),
                        ),
                      ],
                    ),
                  )),
              const SizedBox(height: 8),
              const Text('Matières',
                  style: TextStyle(color: Colors.white70, fontSize: 13)),
              const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                children: [
                  ..._matieres.map((m) => InputChip(
                        label: Text(m,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 11)),
                        backgroundColor: const Color(0xFF1F2937),
                        deleteIconColor: Colors.white38,
                        onDeleted: () =>
                            setState(() => _matieres.remove(m)),
                      )),
                ],
              ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _matCtrl,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 13),
                      decoration: const InputDecoration(
                        hintText: 'Ajouter une matière…',
                        hintStyle: TextStyle(
                            color: Colors.white38, fontSize: 12),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle,
                        color: Color(0xFF6C47FF), size: 20),
                    onPressed: () {
                      final v = _matCtrl.text.trim();
                      if (v.isNotEmpty) {
                        setState(() {
                          _matieres.add(v);
                          _matCtrl.clear();
                        });
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler',
              style: TextStyle(color: Colors.white38)),
        ),
        ElevatedButton(
          onPressed: _loading ? null : _save,
          style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6C47FF)),
          child: _loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Text('Enregistrer',
                  style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}

class _AbsenceDialog extends StatefulWidget {
  const _AbsenceDialog();

  @override
  State<_AbsenceDialog> createState() => _AbsenceDialogState();
}

class _AbsenceDialogState extends State<_AbsenceDialog> {
  UserModel? _selectedProf;
  DateTime _selectedDate = DateTime.now();
  String _motif = 'maladie';
  final _commentCtrl = TextEditingController();
  bool _loading = false;

  static const _motifs = [
    'maladie', 'formation', 'conge', 'autre'
  ];
  static const _motifsLabels = [
    'Maladie', 'Formation', 'Congé', 'Autre'
  ];

  String _dateStr(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 60)),
    );
    if (d != null) {
      setState(() => _selectedDate = d);
    }
  }

  Future<void> _save() async {
    if (_selectedProf == null) {
      return;
    }
    setState(() => _loading = true);
    await RemplacementService.declareAbsence(
      uid: _selectedProf!.uid,
      nom: _selectedProf!.displayName,
      date: _dateStr(_selectedDate),
      motif: _motif,
      commentaire: _commentCtrl.text.trim(),
    );
    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF161B22),
      title: const Text('Déclarer une absence',
          style: TextStyle(color: Colors.white, fontSize: 15)),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              StreamBuilder<List<UserModel>>(
                stream: UserService.usersByRoleStream('professeur'),
                builder: (ctx, snap) {
                  final profs = snap.data ?? [];
                  return DropdownButtonFormField<UserModel>(
                    value: _selectedProf,
                    decoration: const InputDecoration(
                      labelText: 'Enseignant',
                      labelStyle: TextStyle(color: Colors.white54),
                      enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.white12)),
                    ),
                    dropdownColor: const Color(0xFF1F2937),
                    style: const TextStyle(color: Colors.white),
                    items: profs
                        .map((p) => DropdownMenuItem(
                              value: p,
                              child: Text(p.displayName,
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 13)),
                            ))
                        .toList(),
                    onChanged: (v) => setState(() => _selectedProf = v),
                  );
                },
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Date',
                    style:
                        TextStyle(color: Colors.white54, fontSize: 13)),
                subtitle: Text(
                    '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                    style: const TextStyle(
                        color: Colors.white, fontSize: 14)),
                trailing: const Icon(Icons.calendar_today,
                    color: Colors.white38, size: 18),
                onTap: _pickDate,
              ),
              DropdownButtonFormField<String>(
                value: _motif,
                decoration: const InputDecoration(
                  labelText: 'Motif',
                  labelStyle: TextStyle(color: Colors.white54),
                  enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.white12)),
                ),
                dropdownColor: const Color(0xFF1F2937),
                style: const TextStyle(color: Colors.white),
                items: List.generate(
                    _motifs.length,
                    (i) => DropdownMenuItem(
                          value: _motifs[i],
                          child: Text(_motifsLabels[i],
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 13)),
                        )),
                onChanged: (v) => setState(() => _motif = v ?? 'maladie'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _commentCtrl,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: const InputDecoration(
                  labelText: 'Commentaire (optionnel)',
                  labelStyle: TextStyle(color: Colors.white54),
                  enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.white12)),
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler',
              style: TextStyle(color: Colors.white38)),
        ),
        ElevatedButton(
          onPressed: _loading ? null : _save,
          style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6C47FF)),
          child: _loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Text('Déclarer',
                  style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}

class _CreateRemplacementDialog extends StatefulWidget {
  const _CreateRemplacementDialog();

  @override
  State<_CreateRemplacementDialog> createState() =>
      _CreateRemplacementDialogState();
}

class _CreateRemplacementDialogState
    extends State<_CreateRemplacementDialog> {
  UserModel? _selectedProf;
  String _motif = 'maladie';
  DateTime _date = DateTime.now();
  TimeOfDay _heureDebut = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _heureFin = const TimeOfDay(hour: 10, minute: 0);
  bool _loading = false;

  final _matiereCtrl = TextEditingController();
  final _classeCtrl = TextEditingController();
  final _niveauCtrl = TextEditingController();

  static const _motifs = ['maladie', 'formation', 'conge', 'autre'];
  static const _motifsLabels = ['Maladie', 'Formation', 'Congé', 'Autre'];

  String _dateStr(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _timeStr(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 7)),
      lastDate: DateTime.now().add(const Duration(days: 90)),
    );
    if (d != null) {
      setState(() => _date = d);
    }
  }

  Future<void> _pickDebut() async {
    final t = await showTimePicker(
        context: context, initialTime: _heureDebut);
    if (t != null) {
      setState(() => _heureDebut = t);
    }
  }

  Future<void> _pickFin() async {
    final t =
        await showTimePicker(context: context, initialTime: _heureFin);
    if (t != null) {
      setState(() => _heureFin = t);
    }
  }

  Future<void> _save() async {
    if (_selectedProf == null) {
      return;
    }
    setState(() => _loading = true);
    final r = Remplacement(
      id: '',
      professeurAbsentUid: _selectedProf!.uid,
      professeurAbsentNom: _selectedProf!.displayName,
      matiere: _matiereCtrl.text.trim().isNotEmpty
          ? _matiereCtrl.text.trim()
          : (_selectedProf!.matiere ?? ''),
      classeId: _classeCtrl.text.trim(),
      classeNom: _classeCtrl.text.trim(),
      niveau: _niveauCtrl.text.trim(),
      cycle: '',
      motif: _motif,
      date: _dateStr(_date),
      heureDebut: _timeStr(_heureDebut),
      heureFin: _timeStr(_heureFin),
      statut: RemplacementStatut.enAttente,
      createdAt: Timestamp.now(),
    );
    await RemplacementService.creerRemplacement(r);
    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _matiereCtrl.dispose();
    _classeCtrl.dispose();
    _niveauCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF161B22),
      title: const Text('Nouveau remplacement',
          style: TextStyle(color: Colors.white, fontSize: 15)),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              StreamBuilder<List<UserModel>>(
                stream: UserService.usersByRoleStream('professeur'),
                builder: (ctx, snap) {
                  final profs = snap.data ?? [];
                  return DropdownButtonFormField<UserModel>(
                    value: _selectedProf,
                    decoration: const InputDecoration(
                      labelText: 'Professeur absent',
                      labelStyle: TextStyle(color: Colors.white54),
                      enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.white12)),
                    ),
                    dropdownColor: const Color(0xFF1F2937),
                    style: const TextStyle(color: Colors.white),
                    items: profs
                        .map((p) => DropdownMenuItem(
                              value: p,
                              child: Text(p.displayName,
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 13)),
                            ))
                        .toList(),
                    onChanged: (v) => setState(() => _selectedProf = v),
                  );
                },
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _matiereCtrl,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: const InputDecoration(
                  labelText: 'Matière',
                  labelStyle: TextStyle(color: Colors.white54),
                  enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.white12)),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _classeCtrl,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: const InputDecoration(
                  labelText: 'Classe',
                  labelStyle: TextStyle(color: Colors.white54),
                  enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.white12)),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _niveauCtrl,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: const InputDecoration(
                  labelText: 'Niveau',
                  labelStyle: TextStyle(color: Colors.white54),
                  enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.white12)),
                ),
              ),
              const SizedBox(height: 10),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Date',
                    style: TextStyle(color: Colors.white54, fontSize: 12)),
                subtitle: Text(
                    '${_date.day}/${_date.month}/${_date.year}',
                    style: const TextStyle(
                        color: Colors.white, fontSize: 14)),
                trailing: const Icon(Icons.calendar_today,
                    color: Colors.white38, size: 18),
                onTap: _pickDate,
              ),
              Row(
                children: [
                  Expanded(
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Début',
                          style: TextStyle(
                              color: Colors.white54, fontSize: 12)),
                      subtitle: Text(_timeStr(_heureDebut),
                          style: const TextStyle(
                              color: Colors.white, fontSize: 14)),
                      onTap: _pickDebut,
                    ),
                  ),
                  Expanded(
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Fin',
                          style: TextStyle(
                              color: Colors.white54, fontSize: 12)),
                      subtitle: Text(_timeStr(_heureFin),
                          style: const TextStyle(
                              color: Colors.white, fontSize: 14)),
                      onTap: _pickFin,
                    ),
                  ),
                ],
              ),
              DropdownButtonFormField<String>(
                value: _motif,
                decoration: const InputDecoration(
                  labelText: 'Motif',
                  labelStyle: TextStyle(color: Colors.white54),
                  enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.white12)),
                ),
                dropdownColor: const Color(0xFF1F2937),
                style: const TextStyle(color: Colors.white),
                items: List.generate(
                    _motifs.length,
                    (i) => DropdownMenuItem(
                          value: _motifs[i],
                          child: Text(_motifsLabels[i],
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 13)),
                        )),
                onChanged: (v) => setState(() => _motif = v ?? 'maladie'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler',
              style: TextStyle(color: Colors.white38)),
        ),
        ElevatedButton(
          onPressed: _loading ? null : _save,
          style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6C47FF)),
          child: _loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Text('Créer',
                  style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}

class _ProposerRemplacantDialog extends StatefulWidget {
  final Remplacement remplacement;
  const _ProposerRemplacantDialog({required this.remplacement});

  @override
  State<_ProposerRemplacantDialog> createState() =>
      _ProposerRemplacantDialogState();
}

class _ProposerRemplacantDialogState
    extends State<_ProposerRemplacantDialog> {
  List<DisponibiliteEnseignant>? _candidates;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _rechercher();
  }

  Future<void> _rechercher() async {
    final r = widget.remplacement;
    final dayOfWeek = _dateToJourFr(r.date);
    final results = await RemplacementService.rechercherRemplacants(
      matiere: r.matiere,
      jour: dayOfWeek,
      heureDebut: r.heureDebut,
      heureFin: r.heureFin,
      niveau: r.niveau,
    );
    if (mounted) {
      setState(() {
        _candidates = results;
        _loading = false;
      });
    }
  }

  String _dateToJourFr(String dateStr) {
    try {
      final parts = dateStr.split('-');
      if (parts.length < 3) {
        return 'Lundi';
      }
      final d = DateTime(
          int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
      const jours = [
        'Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi', 'Dimanche'
      ];
      return jours[(d.weekday - 1).clamp(0, 6)];
    } catch (_) {
      return 'Lundi';
    }
  }

  Future<void> _proposer(DisponibiliteEnseignant candidate) async {
    await RemplacementService.updateStatut(
      widget.remplacement.id,
      RemplacementStatut.propose,
      remplacantUid: candidate.uid,
      remplacantNom: candidate.nom,
    );
    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF161B22),
      title: const Text('Trouver un remplaçant',
          style: TextStyle(color: Colors.white, fontSize: 15)),
      content: SizedBox(
        width: double.maxFinite,
        height: 300,
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFF6C47FF)))
            : _candidates == null || _candidates!.isEmpty
                ? const Center(
                    child: Text('Aucun remplaçant disponible',
                        style: TextStyle(color: Colors.white38)))
                : ListView.builder(
                    itemCount: _candidates!.length,
                    itemBuilder: (ctx, i) {
                      final c = _candidates![i];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor: const Color(0xFF6C47FF)
                              .withValues(alpha: 0.2),
                          child: Text(
                            c.nom.isNotEmpty ? c.nom[0].toUpperCase() : '?',
                            style: const TextStyle(
                                color: Color(0xFF6C47FF),
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                        title: Text(c.nom,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 13)),
                        subtitle: Text(
                            c.matieres.join(', '),
                            style: const TextStyle(
                                color: Colors.white38, fontSize: 11)),
                        trailing: TextButton(
                          onPressed: () => _proposer(c),
                          style: TextButton.styleFrom(
                            backgroundColor: const Color(0xFF6C47FF)
                                .withValues(alpha: 0.2),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                          ),
                          child: const Text('Proposer',
                              style: TextStyle(
                                  color: Color(0xFF6C47FF),
                                  fontSize: 11)),
                        ),
                      );
                    },
                  ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Fermer',
              style: TextStyle(color: Colors.white38)),
        ),
      ],
    );
  }
}

// ─── Shared helpers ───────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        color: Colors.white38,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  const _EmptyState({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white12, size: 40),
            const SizedBox(height: 8),
            Text(message,
                style: const TextStyle(color: Colors.white38, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}
