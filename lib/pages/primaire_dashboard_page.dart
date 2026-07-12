import 'package:flutter/material.dart';
import '../models/classe_model.dart';
import '../models/devoir_model.dart';
import '../models/note_model.dart';
import '../models/user_model.dart';
import '../routes/app_routes.dart';
import '../services/etudiant_service.dart';
import '../widgets/cycle_access_guard.dart';

const _kColors = [Color(0xFF16A34A), Color(0xFF0891B2)];

class PrimaireDashboardPage extends StatelessWidget {
  const PrimaireDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return CycleAccessGuard(
      cycleCategorie: 'Primaire',
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
          _classeNom.isNotEmpty ? 'Primaire · $_classeNom' : 'École Primaire',
          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _Banner(user: user)),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                if (_classeNom.isNotEmpty) ...[
                  _KpiRow(classeNom: _classeNom),
                  const SizedBox(height: 20),
                  _CoursDuJour(classeNom: _classeNom),
                  const SizedBox(height: 20),
                ],
                _sectionLabel('Mes accès'),
                const SizedBox(height: 10),
                _QuickGrid(classeNom: _classeNom),
                if (_classeNom.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  _sectionLabel('Devoirs récents'),
                  const SizedBox(height: 10),
                  _DevoirsRecents(classeNom: _classeNom),
                  const SizedBox(height: 20),
                  _sectionLabel('Dernières notes'),
                  const SizedBox(height: 10),
                  _DernieresNotes(classeNom: _classeNom),
                ],
              ]),
            ),
          ),
        ],
      ),
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
  const _Banner({required this.user});

  @override
  Widget build(BuildContext context) {
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
                  user.displayName.isNotEmpty ? 'Bonjour, ${user.displayName.split(' ').first} !' : 'École Primaire',
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  '${user.niveau ?? 'Cycle Primaire'} · École',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                if ((user.classeNom ?? '').isNotEmpty)
                  Text(user.classeNom!, style: const TextStyle(color: Colors.white54, fontSize: 11)),
              ],
            ),
          ),
          const Icon(Icons.school_outlined, color: Colors.white24, size: 52),
        ],
      ),
    );
  }
}

// ── KPIs ──────────────────────────────────────────────────────────────────────

class _KpiRow extends StatelessWidget {
  final String classeNom;
  const _KpiRow({required this.classeNom});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: StreamBuilder<int>(
          stream: EtudiantService.devoirsEnAttenteStream(classeNom),
          builder: (_, s) => _KpiBox(
            label: 'Devoirs\nen attente',
            value: s.data?.toString() ?? '–',
            color: const Color(0xFF6C47FF),
            icon: Icons.assignment_outlined,
          ),
        )),
        const SizedBox(width: 8),
        Expanded(child: StreamBuilder<int>(
          stream: EtudiantService.totalNotesStream(classeNom),
          builder: (_, s) => _KpiBox(
            label: 'Notes\nenregistrées',
            value: s.data?.toString() ?? '–',
            color: const Color(0xFFD97706),
            icon: Icons.grade_outlined,
          ),
        )),
        const SizedBox(width: 8),
        Expanded(child: StreamBuilder<int>(
          stream: EtudiantService.absencesMonthStream(),
          builder: (_, s) => _KpiBox(
            label: 'Absences\nce mois',
            value: s.data?.toString() ?? '–',
            color: const Color(0xFFDC2626),
            icon: Icons.event_busy_outlined,
          ),
        )),
      ],
    );
  }
}

class _KpiBox extends StatelessWidget {
  final String label, value;
  final Color color;
  final IconData? icon;
  const _KpiBox({required this.label, required this.value, required this.color, this.icon});

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
          if (icon != null) Icon(icon!, color: color, size: 18),
          if (icon != null) const SizedBox(height: 4),
          Text(value, style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
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

  static int get _jourSemaine {
    final d = DateTime.now().weekday;
    return d <= 5 ? d : 1;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<EmploiSlot>>(
      stream: EtudiantService.emploiStream(classeNom),
      builder: (_, snap) {
        final slots = (snap.data ?? [])
            .where((s) => s.jour == _jourSemaine && s.matiere.isNotEmpty)
            .toList()
          ..sort((a, b) => a.heureDebut.compareTo(b.heureDebut));

        if (slots.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'COURS DU JOUR',
              style: TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2),
            ),
            const SizedBox(height: 8),
            ...slots.asMap().entries.map((e) => _SlotTile(slot: e.value, index: e.key)),
          ],
        );
      },
    );
  }
}

class _SlotTile extends StatelessWidget {
  final EmploiSlot slot;
  final int index;
  const _SlotTile({required this.slot, required this.index});

  static const _palette = [
    Color(0xFF16A34A), Color(0xFF0891B2), Color(0xFF6C47FF),
    Color(0xFFD97706), Color(0xFFDC2626),
  ];

  Color get _color => _palette[index % _palette.length];

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 4, height: 32,
            decoration: BoxDecoration(color: _color, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(slot.matiere, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                if (slot.salle.isNotEmpty)
                  Text('Salle ${slot.salle}', style: const TextStyle(color: Colors.white38, fontSize: 11)),
              ],
            ),
          ),
          Text('${slot.heureDebut} – ${slot.heureFin}',
              style: TextStyle(color: _color, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ── Grille accès rapide ───────────────────────────────────────────────────────

class _QuickGrid extends StatelessWidget {
  final String classeNom;
  const _QuickGrid({required this.classeNom});

  static const _items = [
    _NavItem(Icons.assignment_outlined, 'Devoirs',    AppRoutes.primaireDevoirs,   [Color(0xFF6C47FF), Color(0xFF2563EB)]),
    _NavItem(Icons.grade_outlined,      'Notes',      AppRoutes.primaireNotes,     [Color(0xFFD97706), Color(0xFFDC2626)]),
    _NavItem(Icons.description_outlined,'Bulletin',   AppRoutes.primaireBulletin,  [Color(0xFF15803D), Color(0xFF16A34A)]),
    _NavItem(Icons.folder_outlined,     'Documents',  AppRoutes.primaireDocuments, [Color(0xFF374151), Color(0xFF1E3A5F)]),
    _NavItem(Icons.sports_esports_outlined,'Jeux',    AppRoutes.primaireJeux,      [Color(0xFFBE185D), Color(0xFF7C3AED)]),
  ];

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3, childAspectRatio: 1.0,
        crossAxisSpacing: 10, mainAxisSpacing: 10,
      ),
      itemCount: _items.length,
      itemBuilder: (ctx, i) {
        final item = _items[i];
        return InkWell(
          onTap: () => Navigator.pushNamed(context, item.route),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF161B22),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: item.colors.first.withValues(alpha: 0.3)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: item.colors),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(item.icon, color: Colors.white, size: 20),
                ),
                const SizedBox(height: 6),
                Text(item.label,
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Devoirs récents ───────────────────────────────────────────────────────────

class _DevoirsRecents extends StatelessWidget {
  final String classeNom;
  const _DevoirsRecents({required this.classeNom});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<DevoirModel>>(
      stream: EtudiantService.devoirsStream(classeNom),
      builder: (_, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const SizedBox(height: 40, child: Center(child: CircularProgressIndicator(strokeWidth: 2)));
        }
        final devoirs = (snap.data ?? [])
          ..sort((a, b) {
            if (a.dateLimite == null && b.dateLimite == null) return 0;
            if (a.dateLimite == null) return 1;
            if (b.dateLimite == null) return -1;
            return a.dateLimite!.compareTo(b.dateLimite!);
          });
        final recent = devoirs.take(3).toList();

        if (recent.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: const Color(0xFF161B22), borderRadius: BorderRadius.circular(10)),
            child: const Text('Aucun devoir pour le moment.', style: TextStyle(color: Colors.white38)),
          );
        }

        return Column(
          children: recent.map((d) {
            final overdue = d.dateLimite != null && d.dateLimite!.isBefore(DateTime.now());
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF161B22),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: overdue ? Colors.red.withValues(alpha: 0.2) : const Color(0xFF1E3A5F),
                    child: Text(
                      d.matiere.isNotEmpty ? d.matiere[0].toUpperCase() : '?',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(d.titre, style: const TextStyle(color: Colors.white, fontSize: 13),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        Text(d.matiere, style: const TextStyle(color: Colors.white38, fontSize: 11)),
                      ],
                    ),
                  ),
                  if (overdue) const Icon(Icons.warning_amber, color: Colors.orange, size: 16),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

// ── Dernières notes ───────────────────────────────────────────────────────────

class _DernieresNotes extends StatelessWidget {
  final String classeNom;
  const _DernieresNotes({required this.classeNom});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<NoteModel>>(
      stream: EtudiantService.notesStream(classeNom),
      builder: (_, snap) {
        final notes = (snap.data ?? [])
          ..sort((a, b) => b.date.compareTo(a.date));
        final recent = notes.take(3).toList();

        if (recent.isEmpty) return const SizedBox.shrink();

        return Column(
          children: recent.map((n) {
            final c = n.sur20 >= 14 ? const Color(0xFF16A34A) : n.sur20 >= 10 ? const Color(0xFFD97706) : const Color(0xFFDC2626);
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF161B22),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40, height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
                    child: Text(n.sur20.toStringAsFixed(1),
                        style: TextStyle(color: c, fontWeight: FontWeight.bold, fontSize: 14)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(n.matiere, style: const TextStyle(color: Colors.white, fontSize: 13)),
                        Text(n.intitule.isNotEmpty ? n.intitule : 'Note',
                            style: const TextStyle(color: Colors.white38, fontSize: 11),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  Text('/${n.bareme.toInt()}', style: const TextStyle(color: Colors.white38, fontSize: 11)),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

// ── Navigation ────────────────────────────────────────────────────────────────

class _NavItem {
  final IconData icon;
  final String label, route;
  final List<Color> colors;
  const _NavItem(this.icon, this.label, this.route, this.colors);
}
