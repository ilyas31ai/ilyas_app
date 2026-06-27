import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/classe_model.dart';
import '../models/user_model.dart';
import '../services/maitrise_service.dart';
import '../services/professeur_service.dart';
import '../services/user_service.dart';
import 'fiche_eleve_page.dart';

// ─── Helpers ──────────────────────────────────────────────────────────────────

List<Color> _nameGrad(String name) {
  const palettes = <List<Color>>[
    [Color(0xFF2563EB), Color(0xFF0891B2)],
    [Color(0xFF7C3AED), Color(0xFF6C47FF)],
    [Color(0xFF15803D), Color(0xFF16A34A)],
    [Color(0xFFDC2626), Color(0xFFEA580C)],
    [Color(0xFF0F766E), Color(0xFF0891B2)],
    [Color(0xFFD97706), Color(0xFFCA8A04)],
    [Color(0xFF374151), Color(0xFF4B5563)],
    [Color(0xFF9333EA), Color(0xFF7C3AED)],
  ];
  if (name.isEmpty) return palettes[0];
  final idx = name.codeUnits.fold(0, (a, b) => a + b) % palettes.length;
  return palettes[idx];
}

Color _cycleColor(String cat) => switch (cat.toLowerCase()) {
  'maternelle'  => const Color(0xFFF59E0B),
  'primaire'    => const Color(0xFF10B981),
  'collège'     => const Color(0xFF3B82F6),
  'lycée'       => const Color(0xFF8B5CF6),
  'université'  => const Color(0xFFEF4444),
  _             => const Color(0xFF6B7280),
};

String _inferCycle(String niveau) {
  final n = niveau.toLowerCase();
  if (RegExp(r'\bps\b|\bms\b|\bgs\b|\btps\b').hasMatch(n)) return 'Maternelle';
  if (RegExp(r'\bcp\b|\bce1\b|\bce2\b|\bcm1\b|\bcm2\b').hasMatch(n)) return 'Primaire';
  if (RegExp(r'6|5[eè]|4[eè]|3[eè]|coll').hasMatch(n)) return 'Collège';
  if (RegExp(r'seconde|premi|termin|2nde|lyc|bac').hasMatch(n)) return 'Lycée';
  if (RegExp(r'l1|l2|l3|m1|m2|doctorat|univ|master|licence').hasMatch(n)) return 'Université';
  return '';
}

// ═══════════════════════════════════════════════════════════════════════════════
// Page principale
// ═══════════════════════════════════════════════════════════════════════════════

class ProfesseurElevesPage extends StatefulWidget {
  const ProfesseurElevesPage({super.key});

  @override
  State<ProfesseurElevesPage> createState() => _ProfesseurElevesPageState();
}

class _ProfesseurElevesPageState extends State<ProfesseurElevesPage> {
  ClasseModel? _selectedClasse;
  String _cycleFilter  = '';
  String _searchQuery  = '';

  final _searchCtrl = TextEditingController();
  final _nomCtrl    = TextEditingController();
  final _niveauCtrl = TextEditingController();

  List<UserModel> _usersIA    = [];
  StreamSubscription<List<UserModel>>? _subIA;

  @override
  void dispose() {
    _searchCtrl.dispose();
    _nomCtrl.dispose();
    _niveauCtrl.dispose();
    _subIA?.cancel();
    super.dispose();
  }

  void _subscribeIA(String classeNom) {
    _subIA?.cancel();
    _subIA = ProfesseurService.elevesMaitriseStream(classeNom)
        .listen((u) { if (mounted) setState(() => _usersIA = u); });
  }

  UserModel? _findUserIA(Map<String, dynamic> eleve) {
    final authUid = eleve['authUid'] as String?;
    if (authUid != null && authUid.isNotEmpty) {
      final m = _usersIA.where((u) => u.uid == authUid).firstOrNull;
      if (m != null) return m;
    }
    final full = '${eleve['prenom'] ?? ''} ${eleve['nom'] ?? ''}'.trim().toLowerCase();
    for (final u in _usersIA) {
      if (u.displayName.toLowerCase() == full) return u;
    }
    if (full.isNotEmpty) {
      final prenom = full.split(' ').first;
      for (final u in _usersIA) {
        if (u.displayName.toLowerCase().startsWith(prenom)) return u;
      }
    }
    return null;
  }

  void _selectClasse(ClasseModel c) {
    setState(() { _selectedClasse = c; _searchQuery = ''; _searchCtrl.clear(); });
    _subscribeIA(c.nom);
  }

  void _clearClasse() {
    setState(() { _selectedClasse = null; _searchQuery = ''; _searchCtrl.clear(); });
    _subIA?.cancel();
    _usersIA = [];
  }

  bool get _isSearching => _searchQuery.isNotEmpty;

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        elevation: 0,
        leading: _selectedClasse != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
                onPressed: _clearClasse,
              )
            : null,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _selectedClasse != null
                  ? 'Classe ${_selectedClasse!.nom}'
                  : 'Gestion des élèves',
              style: const TextStyle(
                  color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            if (_selectedClasse != null)
              Text(
                '${_selectedClasse!.nbEleves} élève${_selectedClasse!.nbEleves > 1 ? 's' : ''}'
                '${_selectedClasse!.niveau.isNotEmpty ? ' · ${_selectedClasse!.niveau}' : ''}',
                style: const TextStyle(color: Colors.white38, fontSize: 11),
              ),
          ],
        ),
        actions: [
          if (_selectedClasse == null)
            IconButton(
              icon: const Icon(Icons.add, color: Colors.white),
              tooltip: 'Créer une classe',
              onPressed: () => _showAddClasseDialog(context),
            ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          if (!_isSearching && _selectedClasse == null) _buildCycleFilter(),
          const Divider(height: 1, color: Colors.white12),
          Expanded(
            child: _isSearching
                ? _GlobalSearchView(query: _searchQuery)
                : _selectedClasse == null
                    ? _ClassGrid(
                        cycleFilter: _cycleFilter,
                        onSelect: _selectClasse,
                        onDelete: (c) => _confirmDeleteClasse(context, c),
                      )
                    : _StudentListView(
                        classe: _selectedClasse!,
                        usersIA: _usersIA,
                        findUserIA: _findUserIA,
                      ),
          ),
        ],
      ),
    );
  }

  // ── Search bar ────────────────────────────────────────────────────────────────

  Widget _buildSearchBar() {
    return Container(
      color: const Color(0xFF0D1117),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: TextField(
        controller: _searchCtrl,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        onChanged: (v) => setState(() => _searchQuery = v.trim()),
        decoration: InputDecoration(
          hintText: 'Rechercher un élève…',
          hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
          prefixIcon: const Icon(Icons.search, color: Colors.white38, size: 20),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close, color: Colors.white38, size: 18),
                  onPressed: () { _searchCtrl.clear(); setState(() => _searchQuery = ''); },
                )
              : null,
          filled: true,
          fillColor: const Color(0xFF161B22),
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  // ── Cycle filter chips ────────────────────────────────────────────────────────

  Widget _buildCycleFilter() {
    const cycles = ['Maternelle', 'Primaire', 'Collège', 'Lycée', 'Université'];
    return Container(
      height: 40,
      color: const Color(0xFF0D1117),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _CycleChip(label: 'Tous', selected: _cycleFilter.isEmpty,
              color: const Color(0xFF6B7280),
              onTap: () => setState(() => _cycleFilter = '')),
          ...cycles.map((c) => _CycleChip(
            label: c,
            selected: _cycleFilter == c,
            color: _cycleColor(c),
            onTap: () => setState(() => _cycleFilter = _cycleFilter == c ? '' : c),
          )),
        ],
      ),
    );
  }

  // ── Dialogs ───────────────────────────────────────────────────────────────────

  Future<void> _showAddClasseDialog(BuildContext context) async {
    _nomCtrl.clear();
    _niveauCtrl.clear();
    await showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF161B22),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _AddClasseSheet(nomCtrl: _nomCtrl, niveauCtrl: _niveauCtrl),
    );
  }

  Future<void> _confirmDeleteClasse(BuildContext context, ClasseModel classe) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF161B22),
        title: const Text('Supprimer la classe', style: TextStyle(color: Colors.white)),
        content: Text('Supprimer « ${classe.nom} » ?',
            style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler', style: TextStyle(color: Colors.white38))),
          TextButton(onPressed: () => Navigator.pop(context, true),
              child: const Text('Supprimer', style: TextStyle(color: Color(0xFFDC2626)))),
        ],
      ),
    );
    if (ok == true) await ProfesseurService.deleteClass(classe.id);
  }
}

// ─── Cycle chip ───────────────────────────────────────────────────────────────

class _CycleChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  const _CycleChip({required this.label, required this.selected, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: selected ? color.withValues(alpha: 0.2) : const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: selected ? color : Colors.white.withValues(alpha: 0.1)),
      ),
      child: Text(label, style: TextStyle(
          color: selected ? color : Colors.white54, fontSize: 12,
          fontWeight: selected ? FontWeight.w600 : FontWeight.normal)),
    ),
  );
}

// ═══════════════════════════════════════════════════════════════════════════════
// Class Grid
// ═══════════════════════════════════════════════════════════════════════════════

class _ClassGrid extends StatelessWidget {
  final String cycleFilter;
  final void Function(ClasseModel) onSelect;
  final void Function(ClasseModel) onDelete;
  const _ClassGrid({required this.cycleFilter, required this.onSelect, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ClasseModel>>(
      stream: ProfesseurService.classesStream(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFF7C3AED)));
        }
        final all = snap.data ?? [];
        if (all.isEmpty) return _emptyClasses(context);

        final classes = cycleFilter.isEmpty
            ? all
            : all.where((c) => _inferCycle(c.niveau) == cycleFilter).toList();

        if (classes.isEmpty) {
          return Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.filter_list_off, color: Colors.white24, size: 40),
              const SizedBox(height: 12),
              Text('Aucune classe de niveau $cycleFilter',
                  style: const TextStyle(color: Colors.white38, fontSize: 13)),
            ]),
          );
        }

        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.25,
          ),
          itemCount: classes.length,
          itemBuilder: (_, i) => _ClassCard(
            classe: classes[i],
            onTap: () => onSelect(classes[i]),
            onDelete: () => onDelete(classes[i]),
          ),
        );
      },
    );
  }

  Widget _emptyClasses(BuildContext context) => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.groups_outlined, color: Colors.white24, size: 56),
      const SizedBox(height: 16),
      const Text('Aucune classe créée',
          style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      const Text('Créez votre première classe via le bouton +',
          style: TextStyle(color: Colors.white38, fontSize: 12)),
    ]),
  );
}

class _ClassCard extends StatelessWidget {
  final ClasseModel classe;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  const _ClassCard({required this.classe, required this.onTap, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final cycle = _inferCycle(classe.niveau);
    final color = _cycleColor(cycle);
    final grad  = _nameGrad(classe.nom);

    return GestureDetector(
      onTap: onTap,
      onLongPress: onDelete,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF161B22),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(children: [
              Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: grad),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.groups_outlined, color: Colors.white, size: 18),
              ),
              const Spacer(),
              if (cycle.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(cycle, style: TextStyle(
                      color: color, fontSize: 9, fontWeight: FontWeight.w700)),
                ),
            ]),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(classe.nom, style: const TextStyle(
                  color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
              if (classe.niveau.isNotEmpty)
                Text(classe.niveau, style: const TextStyle(color: Colors.white38, fontSize: 11)),
              const SizedBox(height: 4),
              Row(children: [
                Icon(Icons.person_outline, color: Colors.white38, size: 12),
                const SizedBox(width: 4),
                Text(
                  '${classe.nbEleves} élève${classe.nbEleves > 1 ? 's' : ''}',
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                ),
                const Spacer(),
                const Icon(Icons.arrow_forward_ios, color: Colors.white24, size: 11),
              ]),
            ]),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Student List View (within a class)
// ═══════════════════════════════════════════════════════════════════════════════

class _StudentListView extends StatefulWidget {
  final ClasseModel classe;
  final List<UserModel> usersIA;
  final UserModel? Function(Map<String, dynamic>) findUserIA;
  const _StudentListView({
    required this.classe,
    required this.usersIA,
    required this.findUserIA,
  });
  @override
  State<_StudentListView> createState() => _StudentListViewState();
}

class _StudentListViewState extends State<_StudentListView> {
  String _localSearch = '';
  final _ctrl = TextEditingController();

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Local search within class
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
          child: TextField(
            controller: _ctrl,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            onChanged: (v) => setState(() => _localSearch = v.trim().toLowerCase()),
            decoration: InputDecoration(
              hintText: 'Filtrer dans cette classe…',
              hintStyle: const TextStyle(color: Colors.white24, fontSize: 12),
              prefixIcon: const Icon(Icons.person_search_outlined, color: Colors.white24, size: 18),
              suffixIcon: _localSearch.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close, color: Colors.white24, size: 16),
                      onPressed: () { _ctrl.clear(); setState(() => _localSearch = ''); },
                    )
                  : null,
              filled: true,
              fillColor: const Color(0xFF161B22),
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        Expanded(
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: ProfesseurService.elevesParClasseStream(widget.classe.nom),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(
                    child: CircularProgressIndicator(color: Color(0xFF7C3AED)));
              }
              final all = snap.data ?? [];
              final eleves = _localSearch.isEmpty
                  ? all
                  : all.where((e) {
                      final name = '${e['prenom'] ?? ''} ${e['nom'] ?? ''}'.toLowerCase();
                      final mat  = (e['matricule'] as String? ?? '').toLowerCase();
                      return name.contains(_localSearch) || mat.contains(_localSearch);
                    }).toList();

              if (all.isEmpty) return _emptyClass();
              if (eleves.isEmpty) {
                return Center(
                  child: Text('Aucun résultat pour « $_localSearch »',
                      style: const TextStyle(color: Colors.white38, fontSize: 13)),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                itemCount: eleves.length,
                itemBuilder: (ctx, i) {
                  final eleve  = eleves[i];
                  final userIA = widget.findUserIA(eleve);
                  return _StudentCard(
                    eleve: eleve,
                    index: i + 1,
                    userIA: userIA,
                    onTap: () => Navigator.push(ctx, MaterialPageRoute(
                      builder: (_) => FicheElevePage(
                        eleve: eleve,
                        userIA: userIA,
                        classe: widget.classe,
                      ),
                    )),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _emptyClass() => const Center(
    child: Padding(
      padding: EdgeInsets.all(32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.person_outline, color: Colors.white24, size: 48),
        SizedBox(height: 12),
        Text('Aucun élève dans cette classe',
            style: TextStyle(color: Colors.white38, fontSize: 14)),
        SizedBox(height: 6),
        Text('Les élèves sont créés via l\'Espace Direction',
            style: TextStyle(color: Colors.white24, fontSize: 12),
            textAlign: TextAlign.center),
      ]),
    ),
  );
}

// ─── Student Card ─────────────────────────────────────────────────────────────

class _StudentCard extends StatelessWidget {
  final Map<String, dynamic> eleve;
  final int index;
  final UserModel? userIA;
  final VoidCallback onTap;
  const _StudentCard({
    required this.eleve, required this.index,
    this.userIA, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final prenom    = eleve['prenom'] as String? ?? '';
    final nom       = eleve['nom']    as String? ?? '';
    final fullName  = '$prenom $nom'.trim().let((s) =>
        s.isEmpty ? (eleve['displayName'] as String? ?? 'Élève $index') : s);
    final matricule = eleve['matricule'] as String? ?? '';
    final classeNom = eleve['classeNom'] as String? ?? eleve['classe'] as String? ?? '';
    final grad      = _nameGrad(fullName);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF161B22),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: grad),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  fullName.isNotEmpty ? fullName[0].toUpperCase() : '?',
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(fullName, style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
                  const SizedBox(height: 3),
                  Row(children: [
                    if (matricule.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(matricule,
                            style: const TextStyle(color: Colors.white38, fontSize: 10)),
                      ),
                      const SizedBox(width: 6),
                    ],
                    if (classeNom.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: grad.first.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(classeNom,
                            style: TextStyle(color: grad.first, fontSize: 10,
                                fontWeight: FontWeight.w600)),
                      ),
                  ]),
                ],
              ),
            ),
            if (userIA != null) _MiniMaitriseIndicator(uid: userIA!.uid),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, color: Colors.white24, size: 18),
          ],
        ),
      ),
    );
  }
}

extension _LetExt<T> on T {
  R let<R>(R Function(T) block) => block(this);
}

// ═══════════════════════════════════════════════════════════════════════════════
// Global Search View
// ═══════════════════════════════════════════════════════════════════════════════

class _GlobalSearchView extends StatelessWidget {
  final String query;
  const _GlobalSearchView({required this.query});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<UserModel>>(
      stream: UserService.usersByRoleStream('eleve'),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFF7C3AED)));
        }
        final all = snap.data ?? [];
        final q   = query.toLowerCase();
        final results = all.where((u) {
          return u.displayName.toLowerCase().contains(q) ||
              u.email.toLowerCase().contains(q) ||
              (u.classeNom ?? '').toLowerCase().contains(q) ||
              (u.niveau ?? '').toLowerCase().contains(q) ||
              (u.categorie ?? '').toLowerCase().contains(q);
        }).toList();

        if (results.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.search_off, color: Colors.white24, size: 48),
                const SizedBox(height: 12),
                Text('Aucun élève trouvé pour « $query »',
                    style: const TextStyle(color: Colors.white38, fontSize: 13),
                    textAlign: TextAlign.center),
              ]),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 32),
          itemCount: results.length,
          itemBuilder: (ctx, i) {
            final u    = results[i];
            final grad = _nameGrad(u.displayName);
            final classeNom = u.classeNom ?? '';
            final categorie = u.categorie ?? '';
            return InkWell(
              onTap: () => Navigator.push(ctx, MaterialPageRoute(
                builder: (_) => FicheElevePage(
                  eleve: {
                    'displayName': u.displayName,
                    'email': u.email,
                    'classeNom': classeNom,
                    'classe': classeNom,
                    'categorie': categorie,
                    'niveau': u.niveau ?? '',
                    'uid': u.uid,
                    'authUid': u.uid,
                    'photoUrl': u.photoUrl,
                  },
                  userIA: u,
                ),
              )),
              borderRadius: BorderRadius.circular(14),
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF161B22),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                ),
                child: Row(children: [
                  Container(
                    width: 42, height: 42,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: grad), shape: BoxShape.circle),
                    child: Center(
                      child: Text(
                        u.displayName.isNotEmpty ? u.displayName[0].toUpperCase() : '?',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(u.displayName, style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
                    const SizedBox(height: 3),
                    Row(children: [
                      if (classeNom.isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: grad.first.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(classeNom, style: TextStyle(color: grad.first, fontSize: 10,
                              fontWeight: FontWeight.w600)),
                        ),
                        const SizedBox(width: 6),
                      ],
                      if (categorie.isNotEmpty)
                        Text(categorie, style: TextStyle(
                            color: _cycleColor(categorie), fontSize: 10)),
                    ]),
                  ])),
                  const Icon(Icons.chevron_right, color: Colors.white24, size: 18),
                ]),
              ),
            );
          },
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Mini maîtrise indicator (dots 🔴/🟡/🟢)
// ═══════════════════════════════════════════════════════════════════════════════

class _MiniMaitriseIndicator extends StatelessWidget {
  final String uid;
  const _MiniMaitriseIndicator({required this.uid});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: MaitriseService.summaryForUser(uid),
      builder: (context, snap) {
        if (!snap.hasData) return const SizedBox.shrink();
        final totaux  = (snap.data!['totaux'] as Map<String, dynamic>?) ?? {};
        final retrav  = (totaux['aRetravailler'] as int?) ?? 0;
        final enCours = (totaux['enCours']       as int?) ?? 0;
        final mait    = (totaux['maitrise']      as int?) ?? 0;
        if (retrav == 0 && enCours == 0 && mait == 0) return const SizedBox.shrink();
        return Row(mainAxisSize: MainAxisSize.min, children: [
          if (retrav  > 0) _dot('🔴', retrav),
          if (enCours > 0) _dot('🟡', enCours),
          if (mait    > 0) _dot('🟢', mait),
        ]);
      },
    );
  }

  Widget _dot(String emoji, int n) => Padding(
    padding: const EdgeInsets.only(left: 2),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Text(emoji, style: const TextStyle(fontSize: 10)),
      Text('$n', style: const TextStyle(color: Colors.white54, fontSize: 10)),
    ]),
  );
}

// ═══════════════════════════════════════════════════════════════════════════════
// Add class sheet
// ═══════════════════════════════════════════════════════════════════════════════

class _AddClasseSheet extends StatefulWidget {
  final TextEditingController nomCtrl;
  final TextEditingController niveauCtrl;
  const _AddClasseSheet({required this.nomCtrl, required this.niveauCtrl});
  @override
  State<_AddClasseSheet> createState() => _AddClasseSheetState();
}

class _AddClasseSheetState extends State<_AddClasseSheet> {
  bool _saving = false;
  String? _error;

  Future<void> _creer() async {
    final nom    = widget.nomCtrl.text.trim();
    final niveau = widget.niveauCtrl.text.trim();
    if (nom.isEmpty) { setState(() => _error = 'Le nom de la classe est obligatoire.'); return; }
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (uid.isEmpty) { setState(() => _error = 'Erreur : utilisateur non authentifié.'); return; }
    setState(() { _saving = true; _error = null; });
    try {
      await ProfesseurService.addClass(nom: nom, niveau: niveau);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error  = e.toString().replaceAll('FirebaseException', 'Firestore');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        left: 20, right: 20, top: 20,
      ),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Créer une classe',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        _Field(controller: widget.nomCtrl, label: 'Nom de la classe (ex: 6ème A)'),
        const SizedBox(height: 10),
        _Field(controller: widget.niveauCtrl, label: 'Niveau (ex: 6ème)'),
        if (_error != null) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFDC2626).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFDC2626).withValues(alpha: 0.4)),
            ),
            child: Text(_error!, style: const TextStyle(color: Color(0xFFDC2626), fontSize: 12)),
          ),
        ],
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7C3AED), foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14)),
            onPressed: _saving ? null : _creer,
            child: _saving
                ? const SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Créer', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
      ]),
    );
  }
}

// ─── Text field ───────────────────────────────────────────────────────────────

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  const _Field({required this.controller, required this.label});
  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    style: const TextStyle(color: Colors.white),
    decoration: InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white38),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFF7C3AED)),
      ),
    ),
  );
}
