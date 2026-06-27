import 'package:flutter/material.dart';
import '../models/note_model.dart';
import '../models/user_model.dart';
import '../services/etudiant_service.dart';
import '../widgets/cycle_access_guard.dart';

const _kColors = [Color(0xFF0F766E), Color(0xFF0891B2)];

class CollegeNotesPage extends StatelessWidget {
  const CollegeNotesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return CycleAccessGuard(
      cycleCategorie: 'Collège',
      cycleColors: _kColors,
      builder: (user) => _Body(user: user),
    );
  }
}

class _Body extends StatefulWidget {
  final UserModel user;
  const _Body({required this.user});

  @override
  State<_Body> createState() => _BodyState();
}

class _BodyState extends State<_Body> with SingleTickerProviderStateMixin {
  late final TabController _tab;
  String get _classeNom => widget.user.classeNom ?? widget.user.niveau ?? '';

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 4, vsync: this, initialIndex: 0);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  // Détermine le trimestre courant en fonction du mois
  static int get _currentTrimestre {
    final m = DateTime.now().month;
    if (m >= 9 && m <= 11) return 1;
    if (m >= 12 || m <= 2) return 2;
    return 3;
  }

  // Retourne le trimestre d'une date scolaire
  static int _trimestreDe(DateTime d) {
    final annee = d.month >= 9 ? d.year : d.year - 1;
    final debut1 = DateTime(annee, 9, 1);
    final fin1   = DateTime(annee, 11, 30, 23, 59);
    final debut2 = DateTime(annee, 12, 1);
    final fin2   = DateTime(annee + 1, 2, 28, 23, 59);
    if (!d.isBefore(debut1) && !d.isAfter(fin1)) return 1;
    if (!d.isBefore(debut2) && !d.isAfter(fin2)) return 2;
    return 3;
  }

  // Filtre les notes selon l'onglet (0 = Tout, 1..3 = T1..T3)
  List<NoteModel> _filtrer(List<NoteModel> all, int tabIndex) {
    if (tabIndex == 0) return all;
    return all.where((n) => _trimestreDe(n.date) == tabIndex).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        elevation: 0,
        title: const Text('Mes Notes', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
        bottom: TabBar(
          controller: _tab,
          indicatorColor: _kColors.first,
          labelColor: _kColors.first,
          unselectedLabelColor: Colors.white38,
          labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          tabs: const [
            Tab(text: 'Tout'),
            Tab(text: 'Trim. 1'),
            Tab(text: 'Trim. 2'),
            Tab(text: 'Trim. 3'),
          ],
        ),
      ),
      body: StreamBuilder<List<NoteModel>>(
        stream: EtudiantService.notesStream(_classeNom),
        builder: (_, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF0F766E)));
          }
          if (snap.hasError) {
            return Center(child: Text('Erreur : ${snap.error}', style: const TextStyle(color: Colors.white38)));
          }
          final all = snap.data ?? [];
          return TabBarView(
            controller: _tab,
            children: List.generate(4, (i) {
              final notes = _filtrer(all, i);
              if (notes.isEmpty) return _Empty(tabIndex: i);
              return _NotesList(notes: notes, highlightTrimestre: i == 0 ? _currentTrimestre : null);
            }),
          );
        },
      ),
    );
  }
}

// ── État vide ─────────────────────────────────────────────────────────────────

class _Empty extends StatelessWidget {
  final int tabIndex;
  const _Empty({required this.tabIndex});

  @override
  Widget build(BuildContext context) {
    final msg = tabIndex == 0 ? 'Aucune note publiée' : 'Aucune note pour le trimestre $tabIndex';
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.grade_outlined, color: Colors.white24, size: 48),
          const SizedBox(height: 12),
          Text(msg, style: const TextStyle(color: Colors.white38)),
        ],
      ),
    );
  }
}

// ── Liste des notes ───────────────────────────────────────────────────────────

class _NotesList extends StatelessWidget {
  final List<NoteModel> notes;
  final int? highlightTrimestre;
  const _NotesList({required this.notes, this.highlightTrimestre});

  Map<String, List<NoteModel>> get _grouped {
    final map = <String, List<NoteModel>>{};
    for (final n in notes) { (map[n.matiere] ??= []).add(n); }
    return map;
  }

  double _moyenne(List<NoteModel> ns) {
    if (ns.isEmpty) return 0;
    return ns.fold<double>(0, (a, n) => a + n.sur20) / ns.length;
  }

  @override
  Widget build(BuildContext context) {
    final grouped = _grouped;
    final matieres = grouped.keys.toList()..sort();
    final moyenneGen = _moyenne(notes);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        // Carte moyenne générale
        _MoyenneCard(moyenne: moyenneGen, nbNotes: notes.length),
        const SizedBox(height: 16),
        // Section par matière
        ...matieres.asMap().entries.map((e) {
          final matiere = e.value;
          final ns = grouped[matiere]!;
          final moy = _moyenne(ns);
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _MatiereSection(
              matiere: matiere,
              notes: ns,
              moyenne: moy,
              moyenneGen: moyenneGen,
              accentColor: _kMatColors[e.key % _kMatColors.length],
            ),
          );
        }),
      ],
    );
  }

  static const _kMatColors = [
    Color(0xFF2563EB), Color(0xFF0F766E), Color(0xFF7C3AED),
    Color(0xFFD97706), Color(0xFFBE185D), Color(0xFF16A34A),
    Color(0xFFDC2626), Color(0xFF0891B2),
  ];
}

// ── Carte moyenne générale ────────────────────────────────────────────────────

class _MoyenneCard extends StatelessWidget {
  final double moyenne;
  final int nbNotes;
  const _MoyenneCard({required this.moyenne, required this.nbNotes});

  Color get _color => moyenne >= 14 ? const Color(0xFF16A34A) : moyenne >= 10 ? const Color(0xFFD97706) : const Color(0xFFDC2626);
  String get _appreciation {
    if (moyenne >= 18) return 'Excellent';
    if (moyenne >= 15) return 'Très bien';
    if (moyenne >= 12) return 'Bien';
    if (moyenne >= 10) return 'Assez bien';
    if (moyenne >= 7) return 'Insuffisant';
    return 'Très faible';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: _kColors, begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Moyenne générale', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    const SizedBox(height: 4),
                    Text('${moyenne.toStringAsFixed(2)}/20',
                        style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _color.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(_appreciation, style: TextStyle(color: _color, fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                  const SizedBox(height: 4),
                  Text('$nbNotes note${nbNotes > 1 ? 's' : ''}',
                      style: const TextStyle(color: Colors.white60, fontSize: 11)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Barre de progression /20
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: moyenne / 20,
              backgroundColor: Colors.white.withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation<Color>(_color),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Section par matière ───────────────────────────────────────────────────────

class _MatiereSection extends StatefulWidget {
  final String matiere;
  final List<NoteModel> notes;
  final double moyenne;
  final double moyenneGen;
  final Color accentColor;
  const _MatiereSection({
    required this.matiere,
    required this.notes,
    required this.moyenne,
    required this.moyenneGen,
    required this.accentColor,
  });

  @override
  State<_MatiereSection> createState() => _MatiereSectionState();
}

class _MatiereSectionState extends State<_MatiereSection> {
  bool _expanded = false;

  Color get _couleur => widget.moyenne >= 14 ? Colors.green : widget.moyenne >= 10 ? Colors.amber : Colors.red;
  bool get _aboveMoy => widget.moyenne >= widget.moyenneGen;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        children: [
          // En-tête cliquable
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  // Indicateur couleur
                  Container(
                    width: 4,
                    height: 36,
                    decoration: BoxDecoration(
                      color: widget.accentColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.matiere, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
                        Text('${widget.notes.length} note${widget.notes.length > 1 ? 's' : ''}',
                            style: const TextStyle(color: Colors.white38, fontSize: 11)),
                      ],
                    ),
                  ),
                  // Indicateur au-dessus/en dessous de la moyenne
                  Icon(
                    _aboveMoy ? Icons.trending_up : Icons.trending_down,
                    color: _aboveMoy ? Colors.green : Colors.red,
                    size: 14,
                  ),
                  const SizedBox(width: 6),
                  // Moyenne de la matière
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _couleur.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('${widget.moyenne.toStringAsFixed(1)}/20',
                        style: TextStyle(color: _couleur, fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    _expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    color: Colors.white38,
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
          // Barre de progression
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: widget.moyenne / 20,
                backgroundColor: Colors.white.withValues(alpha: 0.08),
                valueColor: AlwaysStoppedAnimation<Color>(_couleur),
                minHeight: 3,
              ),
            ),
          ),
          // Notes dépliables
          if (_expanded) ...[
            const Divider(color: Colors.white10, height: 1),
            ...widget.notes.map((n) => _NoteRow(note: n, couleur: _couleur)),
            const SizedBox(height: 4),
          ],
        ],
      ),
    );
  }
}

class _NoteRow extends StatelessWidget {
  final NoteModel note;
  final Color couleur;
  const _NoteRow({required this.note, required this.couleur});

  @override
  Widget build(BuildContext context) {
    final c = note.sur20 >= 14 ? Colors.green : note.sur20 >= 10 ? Colors.amber : Colors.red;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      child: Row(
        children: [
          Expanded(
            child: Text(
              note.intitule.isNotEmpty ? note.intitule : 'Note',
              style: const TextStyle(color: Colors.white60, fontSize: 13),
            ),
          ),
          Text(
            '${note.note}/${note.bareme.toInt()}',
            style: TextStyle(color: c, fontWeight: FontWeight.w600, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
