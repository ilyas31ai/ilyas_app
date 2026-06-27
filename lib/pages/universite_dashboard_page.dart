import 'package:flutter/material.dart';
import '../models/classe_model.dart';
import '../models/note_model.dart';
import '../models/user_model.dart';
import '../routes/app_routes.dart';
import '../services/etudiant_service.dart';
import '../widgets/cycle_access_guard.dart';

const _kColors = [Color(0xFF1E3A5F), Color(0xFF2563EB)];

class UniversiteDashboardPage extends StatelessWidget {
  const UniversiteDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return CycleAccessGuard(
      cycleCategorie: 'Université',
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
          _classeNom.isNotEmpty ? 'Université · $_classeNom' : 'Espace Universitaire',
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
                  _DernieresNotes(classeNom: _classeNom),
                  const SizedBox(height: 20),
                ],
                _sectionLabel('Mon espace étudiant'),
                const SizedBox(height: 10),
                _buildGrid(context),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGrid(BuildContext context) {
    const items = [
      _NavItem(Icons.layers_outlined, 'Mes UE', AppRoutes.universiteUes, _kColors),
      _NavItem(Icons.stars_outlined, 'ECTS', AppRoutes.universiteEcts, [Color(0xFF16A34A), Color(0xFF0891B2)]),
      _NavItem(Icons.calendar_today_outlined, 'Semestres', AppRoutes.universiteSemestres, [Color(0xFF7C3AED), Color(0xFF2563EB)]),
      _NavItem(Icons.route_outlined, 'Parcours', AppRoutes.universiteParcours, [Color(0xFF0891B2), Color(0xFF15803D)]),
      _NavItem(Icons.tune_outlined, 'Options', AppRoutes.universiteOptions, [Color(0xFFD97706), Color(0xFFBE185D)]),
      _NavItem(Icons.edit_note_outlined, 'Examens', AppRoutes.universiteExamens, [Color(0xFFDC2626), Color(0xFF7C3AED)]),
      _NavItem(Icons.refresh_outlined, 'Rattrapages', AppRoutes.universiteRattrapages, [Color(0xFFBE185D), Color(0xFFDC2626)]),
      _NavItem(Icons.work_outline, 'Stage', AppRoutes.universiteStage, [Color(0xFF374151), Color(0xFF6B7280)]),
      _NavItem(Icons.menu_book_outlined, 'Mémoire', AppRoutes.universiteMemoire, [Color(0xFF15803D), Color(0xFF16A34A)]),
      _NavItem(Icons.mic_outlined, 'Soutenance', AppRoutes.universiteSoutenances, [Color(0xFF1E3A5F), Color(0xFF0891B2)]),
    ];
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3, childAspectRatio: 1.0,
        crossAxisSpacing: 10, mainAxisSpacing: 10,
      ),
      itemCount: items.length,
      itemBuilder: (_, i) => _NavCell(item: items[i]),
    );
  }

  static Widget _sectionLabel(String t) => Text(
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
                  user.displayName.isNotEmpty ? 'Bonjour, ${user.displayName}' : 'Espace Universitaire',
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  '${user.niveau ?? 'Licence'} · Cycle Universitaire',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                if ((user.classeNom ?? '').isNotEmpty)
                  Text(user.classeNom!, style: const TextStyle(color: Colors.white54, fontSize: 11)),
              ],
            ),
          ),
          const Icon(Icons.account_balance_outlined, color: Colors.white24, size: 52),
        ],
      ),
    );
  }
}

// ── KPIs ──────────────────────────────────────────────────────────────────────

class _KpiRow extends StatelessWidget {
  final String classeNom;
  const _KpiRow({required this.classeNom});

  static const _kEctsParUe = 3;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<NoteModel>>(
      stream: EtudiantService.notesStream(classeNom),
      builder: (_, notesSnap) {
        final notes = notesSnap.data ?? [];
        final matieres = <String, List<NoteModel>>{};
        for (final n in notes) { (matieres[n.matiere] ??= []).add(n); }
        final moyGen = notes.isEmpty
            ? 0.0
            : notes.fold<double>(0, (a, n) => a + n.sur20) / notes.length;
        final ectsValides = matieres.entries
            .where((e) => e.value.fold<double>(0, (a, n) => a + n.sur20) / e.value.length >= 10)
            .length * _kEctsParUe;

        return Row(
          children: [
            Expanded(child: _KpiBox('Moyenne', moyGen.toStringAsFixed(2), const Color(0xFF2563EB), subtitle: '/20')),
            const SizedBox(width: 8),
            Expanded(child: _KpiBox('ECTS validés', '$ectsValides', const Color(0xFF16A34A), subtitle: 'crédits')),
            const SizedBox(width: 8),
            Expanded(
              child: StreamBuilder<int>(
                stream: EtudiantService.devoirsEnAttenteStream(classeNom),
                builder: (_, s) => _KpiBox('Examens', s.data?.toString() ?? '–', const Color(0xFFDC2626), subtitle: 'en attente'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: StreamBuilder<int>(
                stream: EtudiantService.absencesMonthStream(),
                builder: (_, s) => _KpiBox('Absences', s.data?.toString() ?? '–', const Color(0xFFD97706), subtitle: 'ce mois'),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _KpiBox extends StatelessWidget {
  final String label, value;
  final Color color;
  final String? subtitle;
  const _KpiBox(this.label, this.value, this.color, {this.subtitle});

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
          Text(value, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold)),
          if (subtitle != null)
            Text(subtitle!, style: const TextStyle(color: Colors.white38, fontSize: 9)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10)),
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

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionLabel('Cours du jour'),
            const SizedBox(height: 8),
            if (slots.isEmpty)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFF161B22),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                ),
                child: const Center(child: Text('Aucun cours aujourd\'hui', style: TextStyle(color: Colors.white38, fontSize: 13))),
              )
            else
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
    Color(0xFF2563EB), Color(0xFF0891B2), Color(0xFF7C3AED),
    Color(0xFF15803D), Color(0xFFD97706),
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
        border: Border.all(color: _color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 4, height: 36,
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
        final recent = notes.take(4).toList();

        if (recent.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionLabel('Dernières notes'),
            const SizedBox(height: 8),
            ...recent.map((n) {
              final c = n.sur20 >= 14 ? Colors.green : n.sur20 >= 10 ? Colors.amber : Colors.red;
              return Container(
                margin: const EdgeInsets.only(bottom: 6),
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
            }),
          ],
        );
      },
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    style: const TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2),
  );
}

// ── Grille de navigation ──────────────────────────────────────────────────────

class _NavItem {
  final IconData icon;
  final String label, route;
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
          color: const Color(0xFF161B22),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
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
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
