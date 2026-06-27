import 'package:flutter/material.dart';
import '../models/note_model.dart';
import '../models/user_model.dart';
import '../services/etudiant_service.dart';
import '../widgets/cycle_access_guard.dart';

const _kColors = [Color(0xFF1E3A5F), Color(0xFF2563EB)];
const _kEctsParUe = 3;

class UniversiteUesPage extends StatelessWidget {
  const UniversiteUesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return CycleAccessGuard(
      cycleCategorie: 'Université',
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
    _tab = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  // S1 : Oct–Jan, S2 : Fév–Juin (calendrier algérien)
  static List<NoteModel> _filtrerSemestre(List<NoteModel> all, int s) {
    if (s == 0) return all;
    final year = DateTime.now().month >= 9 ? DateTime.now().year : DateTime.now().year - 1;
    final (debut, fin) = s == 1
        ? (DateTime(year, 10, 1), DateTime(year + 1, 1, 31, 23, 59))
        : (DateTime(year + 1, 2, 1), DateTime(year + 1, 6, 30, 23, 59));
    return all.where((n) => !n.date.isBefore(debut) && !n.date.isAfter(fin)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        elevation: 0,
        title: const Text('Unités d\'Enseignement',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
        bottom: TabBar(
          controller: _tab,
          indicatorColor: _kColors.last,
          labelColor: _kColors.last,
          unselectedLabelColor: Colors.white38,
          labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          tabs: const [Tab(text: 'Tout'), Tab(text: 'S1'), Tab(text: 'S2')],
        ),
      ),
      body: _classeNom.isEmpty
          ? const Center(child: Text('Classe non configurée', style: TextStyle(color: Colors.white38)))
          : StreamBuilder<List<NoteModel>>(
              stream: EtudiantService.notesStream(_classeNom),
              builder: (_, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Color(0xFF2563EB)));
                }
                final allNotes = snap.data ?? [];
                return TabBarView(
                  controller: _tab,
                  children: List.generate(3, (i) {
                    final notes = _filtrerSemestre(allNotes, i);
                    return _UesList(notes: notes, niveau: widget.user.niveau, tabIndex: i);
                  }),
                );
              },
            ),
    );
  }
}

// ── Liste des UEs ─────────────────────────────────────────────────────────────

class _UesList extends StatelessWidget {
  final List<NoteModel> notes;
  final String? niveau;
  final int tabIndex;
  const _UesList({required this.notes, this.niveau, required this.tabIndex});

  List<_UeData> get _ues {
    final groups = <String, List<NoteModel>>{};
    for (final n in notes) { (groups[n.matiere] ??= []).add(n); }
    return groups.entries.map((e) {
      final avg = e.value.fold<double>(0, (a, n) => a + n.sur20) / e.value.length;
      return _UeData(nom: e.key, notes: e.value, moyenne: avg);
    }).toList()..sort((a, b) => a.nom.compareTo(b.nom));
  }

  @override
  Widget build(BuildContext context) {
    final ues = _ues;
    if (notes.isEmpty) {
      final msg = tabIndex == 0 ? 'Aucune UE enregistrée' : 'Aucune UE pour le semestre $tabIndex';
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.layers_outlined, color: Colors.white24, size: 48),
            const SizedBox(height: 12),
            Text(msg, style: const TextStyle(color: Colors.white38)),
          ],
        ),
      );
    }

    final moyGen = ues.fold<double>(0, (a, u) => a + u.moyenne) / ues.length;
    final ectsVal = ues.where((u) => u.moyenne >= 10).length * _kEctsParUe;
    final ectsTotal = ues.length * _kEctsParUe;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        _SummaryBanner(ues: ues, moyGen: moyGen, ectsVal: ectsVal, ectsTotal: ectsTotal, niveau: niveau),
        const SizedBox(height: 16),
        ...ues.asMap().entries.map((e) => _UeCard(ue: e.value, index: e.key)),
      ],
    );
  }
}

class _UeData {
  final String nom;
  final List<NoteModel> notes;
  final double moyenne;
  const _UeData({required this.nom, required this.notes, required this.moyenne});
}

// ── Bannière résumé ───────────────────────────────────────────────────────────

class _SummaryBanner extends StatelessWidget {
  final List<_UeData> ues;
  final double moyGen;
  final int ectsVal, ectsTotal;
  final String? niveau;
  const _SummaryBanner({required this.ues, required this.moyGen, required this.ectsVal, required this.ectsTotal, this.niveau});

  Color get _color => moyGen >= 14 ? Colors.green : moyGen >= 10 ? Colors.amber : Colors.red;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: _kColors, begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Moyenne générale · ${niveau ?? ''}',
                        style: const TextStyle(color: Colors.white70, fontSize: 12)),
                    Text('${moyGen.toStringAsFixed(2)} / 20',
                        style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: _color.withValues(alpha: 0.25), borderRadius: BorderRadius.circular(10)),
                child: Text(_mention(moyGen), style: TextStyle(color: _color, fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: moyGen / 20,
              backgroundColor: Colors.white.withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation<Color>(_color),
              minHeight: 4,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _Mini('UE inscrites', '${ues.length}'),
              const SizedBox(width: 8),
              _Mini('ECTS validés', '$ectsVal / $ectsTotal'),
            ],
          ),
        ],
      ),
    );
  }

  static String _mention(double v) {
    if (v >= 16) return 'Très bien';
    if (v >= 14) return 'Bien';
    if (v >= 12) return 'Assez bien';
    if (v >= 10) return 'Passable';
    return 'Insuffisant';
  }
}

class _Mini extends StatelessWidget {
  final String label, value;
  const _Mini(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(8)),
        child: Row(
          children: [
            Text(label, style: const TextStyle(color: Colors.white60, fontSize: 11)),
            const Spacer(),
            Text(value, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

// ── Carte UE (dépliable) ──────────────────────────────────────────────────────

class _UeCard extends StatefulWidget {
  final _UeData ue;
  final int index;
  const _UeCard({required this.ue, required this.index});

  @override
  State<_UeCard> createState() => _UeCardState();
}

class _UeCardState extends State<_UeCard> {
  bool _expanded = false;

  static const _palette = [
    Color(0xFF2563EB), Color(0xFF0891B2), Color(0xFF7C3AED),
    Color(0xFF15803D), Color(0xFFD97706), Color(0xFFDC2626),
  ];

  Color get _color => _palette[widget.index % _palette.length];

  Color _noteColor(double v) {
    if (v >= 14) return const Color(0xFF16A34A);
    if (v >= 10) return const Color(0xFFD97706);
    return const Color(0xFFDC2626);
  }

  static String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  @override
  Widget build(BuildContext context) {
    final ue = widget.ue;
    final validated = ue.moyenne >= 10;
    final avgColor = _noteColor(ue.moyenne);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _expanded ? _color.withValues(alpha: 0.35) : Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(13),
              child: Row(
                children: [
                  Container(
                    width: 38, height: 38,
                    decoration: BoxDecoration(color: _color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(9)),
                    child: Center(child: Text('UE', style: TextStyle(color: _color, fontWeight: FontWeight.bold, fontSize: 11))),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(ue.nom, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                        Text('$_kEctsParUe ECTS · ${ue.notes.length} évaluation${ue.notes.length > 1 ? 's' : ''}',
                            style: const TextStyle(color: Colors.white38, fontSize: 11)),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(ue.moyenne.toStringAsFixed(1),
                          style: TextStyle(color: avgColor, fontWeight: FontWeight.bold, fontSize: 16)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: (validated ? const Color(0xFF16A34A) : const Color(0xFFDC2626)).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(validated ? 'Validée' : 'Échec',
                            style: TextStyle(
                                color: validated ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                                fontSize: 10)),
                      ),
                    ],
                  ),
                  const SizedBox(width: 4),
                  Icon(_expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                      color: Colors.white38, size: 18),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(13, 0, 13, 6),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: ue.moyenne / 20,
                backgroundColor: Colors.white.withValues(alpha: 0.08),
                valueColor: AlwaysStoppedAnimation<Color>(avgColor),
                minHeight: 3,
              ),
            ),
          ),
          if (_expanded) ...[
            const Divider(color: Colors.white10, height: 1),
            ...ue.notes.map((n) {
              final nc = _noteColor(n.sur20);
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      decoration: BoxDecoration(color: nc.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
                      child: Text(n.sur20.toStringAsFixed(1),
                          style: TextStyle(color: nc, fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(n.intitule.isNotEmpty ? n.intitule : 'Évaluation',
                              style: const TextStyle(color: Colors.white60, fontSize: 12),
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                          Text(_fmt(n.date), style: const TextStyle(color: Colors.white38, fontSize: 10)),
                        ],
                      ),
                    ),
                    Text('/${n.bareme.toInt()}', style: const TextStyle(color: Colors.white24, fontSize: 11)),
                  ],
                ),
              );
            }),
            const SizedBox(height: 4),
          ],
        ],
      ),
    );
  }
}
