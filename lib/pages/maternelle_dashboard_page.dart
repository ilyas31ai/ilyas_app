import 'package:flutter/material.dart';
import '../models/classe_model.dart';
import '../models/user_model.dart';
import '../routes/app_routes.dart';
import '../services/etudiant_service.dart';
import '../widgets/cycle_access_guard.dart';

const _kColors = [Color(0xFFEC4899), Color(0xFF9333EA)];

class MaternelleDashboardPage extends StatelessWidget {
  const MaternelleDashboardPage({super.key});

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
        title: Text(
          _classeNom.isNotEmpty ? 'Maternelle · $_classeNom' : 'Espace Maternelle',
          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _Banner(user: user)),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                if (_classeNom.isNotEmpty) ...[
                  _KpiRow(classeNom: _classeNom),
                  const SizedBox(height: 20),
                  _CoursDuJour(classeNom: _classeNom),
                  const SizedBox(height: 20),
                ],
                _sectionLabel('Ma journée'),
                const SizedBox(height: 10),
                _buildGrid(context, _jourItems),
                const SizedBox(height: 20),
                _sectionLabel('Mon monde'),
                const SizedBox(height: 10),
                _buildGrid(context, _mondeItems),
                const SizedBox(height: 20),
                _sectionLabel('Mon carnet'),
                const SizedBox(height: 10),
                _buildGrid(context, _carnetItems),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  static const _jourItems = [
    _NavItem(Icons.sports_esports_outlined, 'Activités',  AppRoutes.maternelleActivites,  _kColors),
    _NavItem(Icons.calendar_month_outlined,  'Calendrier', AppRoutes.maternelleCalendrier, [Color(0xFF0891B2), Color(0xFF2563EB)]),
    _NavItem(Icons.how_to_reg_outlined,      'Présences',  AppRoutes.maternellePresences,  [Color(0xFF0891B2), Color(0xFF15803D)]),
    _NavItem(Icons.restaurant_outlined,      'Repas',      AppRoutes.maternelleRepas,      [Color(0xFFD97706), Color(0xFFEC4899)]),
    _NavItem(Icons.bedtime_outlined,         'Sieste',     AppRoutes.maternelleSieste,     [Color(0xFF6366F1), Color(0xFF9333EA)]),
  ];

  static const _mondeItems = [
    _NavItem(Icons.auto_stories_outlined,  'Histoires', AppRoutes.maternelleHistoires, [Color(0xFF15803D), Color(0xFF0891B2)]),
    _NavItem(Icons.library_books_outlined, 'Albums',    AppRoutes.maternelleAlbums,    [Color(0xFF2563EB), Color(0xFF9333EA)]),
    _NavItem(Icons.music_note_outlined,    'Comptines', AppRoutes.maternelleComptines, [Color(0xFFD97706), Color(0xFFEC4899)]),
    _NavItem(Icons.palette_outlined,       'Coloriages',AppRoutes.maternelleColoriages,[Color(0xFF9333EA), Color(0xFFEC4899)]),
    _NavItem(Icons.games_outlined,         'Jeux',      AppRoutes.maternelleJeux,      [Color(0xFF374151), Color(0xFF6B7280)]),
  ];

  static const _carnetItems = [
    _NavItem(Icons.menu_book_outlined,     'Cahier de vie', AppRoutes.maternelleCahierVie,     _kColors),
    _NavItem(Icons.visibility_outlined,    'Observations',  AppRoutes.maternellePortfolio,     [Color(0xFF7C3AED), Color(0xFF2563EB)]),
    _NavItem(Icons.stars_outlined,         'Compétences',   AppRoutes.maternelleEvaluations,   [Color(0xFF16A34A), Color(0xFF0891B2)]),
    _NavItem(Icons.message_outlined,       'Messages',      AppRoutes.maternelleCommunication, [Color(0xFFD97706), Color(0xFFBE185D)]),
    _NavItem(Icons.photo_library_outlined, 'Galerie',       AppRoutes.maternelleGalerie,       [Color(0xFFEC4899), Color(0xFF7C3AED)]),
  ];

  Widget _buildGrid(BuildContext context, List<_NavItem> items) {
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
                  user.displayName.isNotEmpty ? 'Bonjour, ${user.displayName} !' : 'Espace Maternelle',
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  '${user.niveau ?? 'Petite section'} · Cycle Maternelle',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                if ((user.classeNom ?? '').isNotEmpty)
                  Text(user.classeNom!, style: const TextStyle(color: Colors.white54, fontSize: 11)),
              ],
            ),
          ),
          const Icon(Icons.child_care, color: Colors.white24, size: 52),
        ],
      ),
    );
  }
}

// ── KPIs ──────────────────────────────────────────────────────────────────────

class _KpiRow extends StatelessWidget {
  final String classeNom;
  const _KpiRow({required this.classeNom});

  static int get _jourSemaine {
    final d = DateTime.now().weekday;
    return d <= 5 ? d : 1;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<EmploiSlot>>(
      stream: EtudiantService.emploiStream(classeNom),
      builder: (_, emploiSnap) {
        final activitesAujourd = (emploiSnap.data ?? [])
            .where((s) => s.jour == _jourSemaine && s.matiere.isNotEmpty)
            .length;
        return Row(
          children: [
            Expanded(child: _KpiBox(
              label: "Activités\naujourd'hui",
              value: activitesAujourd.toString(),
              color: const Color(0xFFEC4899),
              icon: Icons.sports_esports_outlined,
            )),
            const SizedBox(width: 8),
            Expanded(child: StreamBuilder<int>(
              stream: EtudiantService.absencesMonthStream(),
              builder: (_, s) => _KpiBox(
                label: 'Absences\nce mois',
                value: s.data?.toString() ?? '–',
                color: const Color(0xFFD97706),
                icon: Icons.event_busy_outlined,
              ),
            )),
            const SizedBox(width: 8),
            const Expanded(child: _KpiBox(
              label: 'Évaluation\nqualitative',
              value: 'Comp.',
              color: Color(0xFF16A34A),
              icon: Icons.stars_outlined,
            )),
          ],
        );
      },
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
            Text(
              'ACTIVITÉS DU JOUR',
              style: const TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2),
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
    Color(0xFFEC4899), Color(0xFF9333EA), Color(0xFF7C3AED),
    Color(0xFF0891B2), Color(0xFF15803D),
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

// ── Navigation ────────────────────────────────────────────────────────────────

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
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}
