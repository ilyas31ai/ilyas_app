import 'package:flutter/material.dart';
import '../models/annonce_model.dart';
import '../models/classe_model.dart';
import '../models/devoir_model.dart';
import '../models/note_model.dart';
import '../models/submission_model.dart';
import '../models/user_model.dart';
import '../routes/app_routes.dart';
import '../services/etudiant_service.dart';
import '../widgets/cycle_access_guard.dart';

const _kColors = [Color(0xFF0F766E), Color(0xFF0891B2)];

class CollegeDashboardPage extends StatelessWidget {
  const CollegeDashboardPage({super.key});

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

  String get _classeNom => user.classeNom ?? user.niveau ?? '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        elevation: 0,
        title: Text(
          _classeNom.isNotEmpty ? 'Collège · $_classeNom' : 'Espace Collège',
          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined, color: Colors.white60),
            onPressed: () => Navigator.pushNamed(context, AppRoutes.notifications),
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _Banner(user: user, classeNom: _classeNom)),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // KPIs
                _KpisRow(classeNom: _classeNom, uid: user.uid),
                const SizedBox(height: 20),

                // Navigation rapide
                _sectionLabel('Navigation rapide'),
                const SizedBox(height: 10),
                _quickGrid(context),

                // Cours du jour
                if (_classeNom.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  _sectionLabel('Cours aujourd\'hui'),
                  const SizedBox(height: 10),
                  _CoursDuJour(classeNom: _classeNom),
                ],

                // Devoirs urgents
                if (_classeNom.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(child: _sectionLabel('Devoirs à rendre')),
                      TextButton(
                        onPressed: () => Navigator.pushNamed(context, AppRoutes.collegeDevoirs),
                        child: const Text('Voir tout', style: TextStyle(color: Color(0xFF0F766E), fontSize: 12)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  _DevoirsUrgents(classeNom: _classeNom),
                ],

                // Dernières notes
                ...[
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(child: _sectionLabel('Dernières notes')),
                      TextButton(
                        onPressed: () => Navigator.pushNamed(context, AppRoutes.collegeNotes),
                        child: const Text('Voir tout', style: TextStyle(color: Color(0xFF0F766E), fontSize: 12)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  _DernieresNotes(classeNom: _classeNom),
                ],

                // Annonces
                ...[
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(child: _sectionLabel('Annonces')),
                      TextButton(
                        onPressed: () => Navigator.pushNamed(context, '/etudiant_annonces'),
                        child: const Text('Voir tout', style: TextStyle(color: Color(0xFF0F766E), fontSize: 12)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const _Annonces(),
                ],
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _quickGrid(BuildContext context) {
    const items = [
      _NavItem(Icons.book_outlined, 'Matières', AppRoutes.collegeMatieres, _kColors),
      _NavItem(Icons.assignment_outlined, 'Devoirs', AppRoutes.collegeDevoirs, [Color(0xFF6C47FF), Color(0xFF2563EB)]),
      _NavItem(Icons.grade_outlined, 'Notes', AppRoutes.collegeNotes, [Color(0xFFD97706), Color(0xFFDC2626)]),
      _NavItem(Icons.description_outlined, 'Bulletin', AppRoutes.collegeBulletin, [Color(0xFF15803D), Color(0xFF16A34A)]),
      _NavItem(Icons.emoji_events_outlined, 'BEM', AppRoutes.collegeBrevet, [Color(0xFFBE185D), Color(0xFF7C3AED)]),
      _NavItem(Icons.school_outlined, 'Révisions', AppRoutes.collegeRevisions, [Color(0xFF374151), Color(0xFF1E3A5F)]),
      _NavItem(Icons.how_to_reg_outlined, 'Présences', AppRoutes.collegePresences, [Color(0xFF0F766E), Color(0xFF15803D)]),
      _NavItem(Icons.folder_outlined, 'Documents', AppRoutes.collegeDocuments, [Color(0xFF1E3A5F), Color(0xFF374151)]),
      _NavItem(Icons.explore_outlined, 'Orientation', AppRoutes.collegeOrientation, [Color(0xFF374151), Color(0xFF0F172A)]),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 1.0,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: items.length,
      itemBuilder: (_, i) => _NavCell(item: items[i]),
    );
  }

  Widget _sectionLabel(String t) => Text(
    t.toUpperCase(),
    style: const TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2),
  );
}

// ── Bannière ──────────────────────────────────────────────────────────────────

class _Banner extends StatelessWidget {
  final UserModel user;
  final String classeNom;
  const _Banner({required this.user, required this.classeNom});

  @override
  Widget build(BuildContext context) {
    final first = user.displayName.split(' ').first;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: _kColors, begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bonjour, $first',
                  style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  classeNom.isNotEmpty ? 'Classe : $classeNom · Cycle Moyen' : 'Cycle Moyen',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text('Préparation BEM · Orientation Lycée', style: TextStyle(color: Colors.white, fontSize: 10)),
                ),
              ],
            ),
          ),
          const Icon(Icons.menu_book_outlined, color: Colors.white24, size: 52),
        ],
      ),
    );
  }
}

// ── KPIs ──────────────────────────────────────────────────────────────────────

class _KpisRow extends StatelessWidget {
  final String classeNom;
  final String uid;
  const _KpisRow({required this.classeNom, required this.uid});

  @override
  Widget build(BuildContext context) {
    final weekday = DateTime.now().weekday;
    return Row(
      children: [
        Expanded(
          child: StreamBuilder<List<EmploiSlot>>(
            stream: classeNom.isNotEmpty
                ? EtudiantService.emploiStream(classeNom)
                : Stream.value([]),
            builder: (_, s) {
              final count = s.data?.where((sl) => sl.jour == weekday).length ?? 0;
              return _KpiBox(label: 'Cours\naujourd\'hui', value: '$count', color: _kColors.first);
            },
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: StreamBuilder<int>(
            stream: classeNom.isNotEmpty
                ? EtudiantService.devoirsEnAttenteStream(classeNom)
                : Stream.value(0),
            builder: (_, s) => _KpiBox(label: 'Devoirs\nen attente', value: s.data?.toString() ?? '–', color: const Color(0xFF6C47FF)),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: StreamBuilder<int>(
            stream: EtudiantService.totalNotesStream(classeNom),
            builder: (_, s) => _KpiBox(label: 'Notes\nreçues', value: s.data?.toString() ?? '–', color: const Color(0xFFD97706)),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: StreamBuilder<int>(
            stream: EtudiantService.absencesMonthStream(),
            builder: (_, s) {
              final v = s.data ?? 0;
              return _KpiBox(label: 'Absences\nce mois', value: '$v', color: v > 0 ? const Color(0xFFDC2626) : const Color(0xFF374151));
            },
          ),
        ),
      ],
    );
  }
}

class _KpiBox extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _KpiBox({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 3),
          Text(label, style: const TextStyle(color: Colors.white38, fontSize: 10)),
        ],
      ),
    );
  }
}

// ── Cours du jour ─────────────────────────────────────────────────────────────

class _CoursDuJour extends StatelessWidget {
  final String classeNom;
  const _CoursDuJour({required this.classeNom});

  @override
  Widget build(BuildContext context) {
    final weekday = DateTime.now().weekday;
    return StreamBuilder<List<EmploiSlot>>(
      stream: EtudiantService.emploiStream(classeNom),
      builder: (_, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const _Loading();
        }
        final slots = (snap.data ?? []).where((s) => s.jour == weekday).toList()
          ..sort((a, b) => a.heureDebut.compareTo(b.heureDebut));
        if (slots.isEmpty) return _empty(Icons.event_available_outlined, 'Pas de cours aujourd\'hui');
        return Column(children: slots.map((s) => _SlotTile(slot: s)).toList());
      },
    );
  }
}

class _SlotTile extends StatelessWidget {
  final EmploiSlot slot;
  const _SlotTile({required this.slot});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: _kColors),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${slot.heureDebut}–${slot.heureFin}',
              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(slot.matiere, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                if (slot.salle.isNotEmpty)
                  Text('Salle ${slot.salle}', style: const TextStyle(color: Colors.white38, fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Devoirs urgents ───────────────────────────────────────────────────────────

class _DevoirsUrgents extends StatelessWidget {
  final String classeNom;
  const _DevoirsUrgents({required this.classeNom});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<DevoirModel>>(
      stream: EtudiantService.devoirsStream(classeNom),
      builder: (_, dSnap) => StreamBuilder<List<SubmissionModel>>(
        stream: EtudiantService.submissionsStream(),
        builder: (_, sSnap) {
          if (dSnap.connectionState == ConnectionState.waiting) return const _Loading();
          final submitted = (sSnap.data ?? []).map((s) => s.assignmentId).toSet();
          final now = DateTime.now();
          final pending = (dSnap.data ?? []).where((d) => !submitted.contains(d.id)).toList()
            ..sort((a, b) {
              if (a.dateLimite == null && b.dateLimite == null) return 0;
              if (a.dateLimite == null) return 1;
              if (b.dateLimite == null) return -1;
              return a.dateLimite!.compareTo(b.dateLimite!);
            });
          if (pending.isEmpty) return _empty(Icons.assignment_turned_in_outlined, 'Tous les devoirs rendus');
          return Column(
            children: pending.take(3).map((d) {
              final isLate = d.dateLimite != null && d.dateLimite!.isBefore(now);
              final isSoon = d.dateLimite != null && !isLate && d.dateLimite!.difference(now).inDays <= 2;
              return _DevoirRow(devoir: d, isLate: isLate, isSoon: isSoon);
            }).toList(),
          );
        },
      ),
    );
  }
}

class _DevoirRow extends StatelessWidget {
  final DevoirModel devoir;
  final bool isLate;
  final bool isSoon;
  const _DevoirRow({required this.devoir, required this.isLate, required this.isSoon});

  Color get _color => isLate ? Colors.red : isSoon ? Colors.orange : const Color(0xFF6C47FF);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.pushNamed(context, AppRoutes.collegeDevoirs),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: const Color(0xFF161B22),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _color.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 17,
              backgroundColor: _color.withValues(alpha: 0.15),
              child: Text(
                devoir.matiere.isNotEmpty ? devoir.matiere[0] : '?',
                style: TextStyle(color: _color, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(devoir.titre, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(devoir.matiere, style: const TextStyle(color: Colors.white38, fontSize: 11)),
                ],
              ),
            ),
            if (devoir.dateLimite != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('${devoir.dateLimite!.day}/${devoir.dateLimite!.month}', style: TextStyle(color: _color, fontSize: 11)),
                  if (isLate) Text('Retard', style: TextStyle(color: _color, fontSize: 9, fontWeight: FontWeight.bold))
                  else if (isSoon) Text('Urgent', style: TextStyle(color: _color, fontSize: 9, fontWeight: FontWeight.bold)),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

// ── Dernières notes ────────────────────────────────────────────────────────────

class _DernieresNotes extends StatelessWidget {
  final String classeNom;
  const _DernieresNotes({required this.classeNom});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<NoteModel>>(
      stream: EtudiantService.notesStream(classeNom),
      builder: (_, snap) {
        if (snap.connectionState == ConnectionState.waiting) return const _Loading();
        final notes = (snap.data ?? []).take(3).toList();
        if (notes.isEmpty) return _empty(Icons.grade_outlined, 'Aucune note publiée');
        return Column(children: notes.map((n) => _NoteTile(note: n)).toList());
      },
    );
  }
}

class _NoteTile extends StatelessWidget {
  final NoteModel note;
  const _NoteTile({required this.note});

  Color get _color => note.sur20 >= 14 ? Colors.green : note.sur20 >= 10 ? Colors.amber : Colors.red;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
              color: _color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(note.sur20.toStringAsFixed(1), style: TextStyle(color: _color, fontWeight: FontWeight.bold, fontSize: 13)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(note.intitule.isNotEmpty ? note.intitule : 'Note', style: const TextStyle(color: Colors.white, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(note.matiere, style: const TextStyle(color: Colors.white38, fontSize: 11)),
              ],
            ),
          ),
          const Text('/20', style: TextStyle(color: Colors.white38, fontSize: 11)),
        ],
      ),
    );
  }
}

// ── Annonces ──────────────────────────────────────────────────────────────────

class _Annonces extends StatelessWidget {
  const _Annonces();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AnnonceModel>>(
      stream: EtudiantService.annoncesStream(),
      builder: (_, snap) {
        if (snap.connectionState == ConnectionState.waiting) return const _Loading();
        final annonces = (snap.data ?? []).take(2).toList();
        if (annonces.isEmpty) return _empty(Icons.campaign_outlined, 'Aucune annonce');
        return Column(
          children: annonces.map((a) => InkWell(
            onTap: () => Navigator.pushNamed(context, '/etudiant_annonces'),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: const Color(0xFF161B22),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _kColors.first.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.campaign_outlined, color: _kColors.first, size: 14),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(a.titre, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(a.contenu, style: const TextStyle(color: Colors.white54, fontSize: 11), maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          )).toList(),
        );
      },
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

class _Loading extends StatelessWidget {
  const _Loading();
  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: 14),
    child: Center(child: CircularProgressIndicator(color: Color(0xFF0F766E), strokeWidth: 2)),
  );
}

Widget _empty(IconData icon, String msg) => Container(
  padding: const EdgeInsets.symmetric(vertical: 16),
  decoration: BoxDecoration(color: const Color(0xFF161B22), borderRadius: BorderRadius.circular(10)),
  child: Column(
    children: [
      Icon(icon, color: Colors.white24, size: 30),
      const SizedBox(height: 6),
      Text(msg, style: const TextStyle(color: Colors.white38, fontSize: 12)),
    ],
  ),
);

// ── Widgets partagés ──────────────────────────────────────────────────────────

class _NavItem {
  final IconData icon;
  final String label;
  final String route;
  final List<Color> colors;
  const _NavItem(this.icon, this.label, this.route, this.colors);
}

class _NavCell extends StatelessWidget {
  final _NavItem item;
  const _NavCell({required this.item});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.pushNamed(context, item.route),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: item.colors.map((c) => c.withValues(alpha: 0.12)).toList(),
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: item.colors.first.withValues(alpha: 0.3)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(item.icon, color: item.colors.first, size: 26),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(item.label,
                  style: TextStyle(color: item.colors.first, fontSize: 10, fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
    );
  }
}
