import 'package:flutter/material.dart';
import '../models/note_model.dart';
import '../models/user_model.dart';
import '../services/etudiant_service.dart';
import '../widgets/cycle_access_guard.dart';

const _kColors = [Color(0xFF0891B2), Color(0xFF2563EB)];

class LyceeControleContinuPage extends StatelessWidget {
  const LyceeControleContinuPage({super.key});

  @override
  Widget build(BuildContext context) {
    return CycleAccessGuard(
      cycleCategorie: 'Lycée',
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
    _tab = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

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
        title: const Text('Contrôle Continu', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
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
      body: _classeNom.isEmpty
          ? const Center(child: Text('Classe non configurée', style: TextStyle(color: Colors.white38)))
          : StreamBuilder<List<NoteModel>>(
              stream: EtudiantService.notesStream(_classeNom),
              builder: (_, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Color(0xFF0891B2)));
                }
                final allNotes = snap.data ?? [];
                return TabBarView(
                  controller: _tab,
                  children: List.generate(4, (i) {
                    final notes = _filtrer(allNotes, i);
                    return _TabContent(notes: notes, tabIndex: i);
                  }),
                );
              },
            ),
    );
  }
}

// ── Contenu d'un onglet ────────────────────────────────────────────────────────

class _TabContent extends StatelessWidget {
  final List<NoteModel> notes;
  final int tabIndex;
  const _TabContent({required this.notes, required this.tabIndex});

  static Map<String, List<NoteModel>> _groupByMatiere(List<NoteModel> notes) {
    final m = <String, List<NoteModel>>{};
    for (final n in notes) { (m[n.matiere] ??= []).add(n); }
    return m;
  }

  @override
  Widget build(BuildContext context) {
    if (notes.isEmpty) {
      final label = tabIndex == 0 ? 'Aucune note publiée' : 'Aucune note pour le trimestre $tabIndex';
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.analytics_outlined, color: Colors.white24, size: 48),
            const SizedBox(height: 12),
            Text(label, style: const TextStyle(color: Colors.white38)),
          ],
        ),
      );
    }

    final ccNotes = notes.where((n) => n.bareme < 20).toList();
    final dsNotes = notes.where((n) => n.bareme >= 20).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        _SummaryBanner(ccNotes: ccNotes, dsNotes: dsNotes),
        const SizedBox(height: 20),
        _SectionHeader('Interros / TP / Oral', ccNotes.length),
        const SizedBox(height: 8),
        if (ccNotes.isEmpty)
          const _EmptyState('Aucune note de contrôle continu')
        else
          ..._groupByMatiere(ccNotes).entries.map((e) => _NoteGroup(matiere: e.key, notes: e.value)),
        const SizedBox(height: 20),
        _SectionHeader('Devoirs Surveillés', dsNotes.length),
        const SizedBox(height: 8),
        if (dsNotes.isEmpty)
          const _EmptyState('Aucun devoir surveillé')
        else
          ..._groupByMatiere(dsNotes).entries.map((e) => _NoteGroup(matiere: e.key, notes: e.value)),
      ],
    );
  }
}

// ── Bannière résumé ───────────────────────────────────────────────────────────

class _SummaryBanner extends StatelessWidget {
  final List<NoteModel> ccNotes;
  final List<NoteModel> dsNotes;
  const _SummaryBanner({required this.ccNotes, required this.dsNotes});

  static double _avg(List<NoteModel> notes) {
    if (notes.isEmpty) return 0;
    return notes.fold<double>(0, (a, n) => a + n.sur20) / notes.length;
  }

  @override
  Widget build(BuildContext context) {
    final ccAvg = _avg(ccNotes);
    final dsAvg = _avg(dsNotes);
    final all = ccNotes + dsNotes;
    final globalAvg = all.isEmpty ? 0.0 : _avg(all);
    final globalColor = globalAvg >= 14 ? Colors.green : globalAvg >= 10 ? Colors.amber : Colors.red;

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
                    const Text('Moyenne globale', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    Text('${globalAvg.toStringAsFixed(2)}/20',
                        style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                    Text('${all.length} note${all.length > 1 ? 's' : ''}',
                        style: const TextStyle(color: Colors.white60, fontSize: 11)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                    color: globalColor.withValues(alpha: 0.25), borderRadius: BorderRadius.circular(10)),
                child: Text(_mention(globalAvg),
                    style: TextStyle(color: globalColor, fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: globalAvg / 20,
              backgroundColor: Colors.white.withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation<Color>(globalColor),
              minHeight: 5,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _MiniStat('CC', ccAvg, ccNotes.length, const Color(0xFF0891B2))),
              const SizedBox(width: 8),
              Expanded(child: _MiniStat('DS', dsAvg, dsNotes.length, const Color(0xFF2563EB))),
            ],
          ),
        ],
      ),
    );
  }

  static String _mention(double v) {
    if (v >= 16) return 'Félicitations';
    if (v >= 14) return 'Mention Bien';
    if (v >= 12) return 'Assez Bien';
    if (v >= 10) return 'Admis';
    return 'Insuffisant';
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final double avg;
  final int count;
  final Color color;
  const _MiniStat(this.label, this.avg, this.count, this.color);

  @override
  Widget build(BuildContext context) {
    final c = avg >= 14 ? Colors.green : avg >= 10 ? Colors.amber : Colors.red;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(8)),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 28, height: 28,
                decoration: BoxDecoration(color: color.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(6)),
                child: Center(child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold))),
              ),
              const Spacer(),
              Text('${avg.toStringAsFixed(1)}/20', style: TextStyle(color: c, fontSize: 12, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: avg / 20,
              backgroundColor: Colors.white.withValues(alpha: 0.1),
              valueColor: AlwaysStoppedAnimation<Color>(c),
              minHeight: 3,
            ),
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: Text('$count note${count > 1 ? 's' : ''}', style: const TextStyle(color: Colors.white38, fontSize: 10)),
          ),
        ],
      ),
    );
  }
}

// ── En-tête de section ────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final int count;
  const _SectionHeader(this.title, this.count);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(title, style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w700)),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
              color: const Color(0xFF0891B2).withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
          child: Text('$count',
              style: const TextStyle(color: Color(0xFF0891B2), fontSize: 11, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String msg;
  const _EmptyState(this.msg);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18),
      alignment: Alignment.center,
      child: Text(msg, style: const TextStyle(color: Colors.white38, fontSize: 13)),
    );
  }
}

// ── Groupe par matière (dépliable) ────────────────────────────────────────────

class _NoteGroup extends StatefulWidget {
  final String matiere;
  final List<NoteModel> notes;
  const _NoteGroup({required this.matiere, required this.notes});

  @override
  State<_NoteGroup> createState() => _NoteGroupState();
}

class _NoteGroupState extends State<_NoteGroup> {
  bool _expanded = false;

  static Color _col(double v) {
    if (v >= 14) return const Color(0xFF16A34A);
    if (v >= 10) return const Color(0xFFD97706);
    return const Color(0xFFDC2626);
  }

  static String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  @override
  Widget build(BuildContext context) {
    final avg = widget.notes.fold<double>(0, (a, n) => a + n.sur20) / widget.notes.length;
    final avgColor = _col(avg);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: _expanded ? _kColors.first.withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              child: Row(
                children: [
                  Container(
                    width: 4, height: 32,
                    decoration: BoxDecoration(color: avgColor, borderRadius: BorderRadius.circular(2)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.matiere,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                        Text('${widget.notes.length} note${widget.notes.length > 1 ? 's' : ''}',
                            style: const TextStyle(color: Colors.white38, fontSize: 11)),
                      ],
                    ),
                  ),
                  Icon(avg >= 10 ? Icons.trending_up : Icons.trending_down,
                      color: avg >= 10 ? Colors.green : Colors.red, size: 14),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration:
                        BoxDecoration(color: avgColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
                    child: Text('${avg.toStringAsFixed(1)}/20',
                        style: TextStyle(color: avgColor, fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 4),
                  Icon(_expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                      color: Colors.white38, size: 18),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 6),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: avg / 20,
                backgroundColor: Colors.white.withValues(alpha: 0.08),
                valueColor: AlwaysStoppedAnimation<Color>(avgColor),
                minHeight: 3,
              ),
            ),
          ),
          if (_expanded) ...[
            const Divider(color: Colors.white10, height: 1),
            ...widget.notes.map((n) {
              final nc = _col(n.sur20);
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      decoration:
                          BoxDecoration(color: nc.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
                      child: Text(n.sur20.toStringAsFixed(1),
                          style: TextStyle(color: nc, fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(n.intitule.isNotEmpty ? n.intitule : 'Note',
                              style: const TextStyle(color: Colors.white70, fontSize: 13),
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
