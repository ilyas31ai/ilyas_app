import 'package:flutter/material.dart';
import '../models/note_model.dart';
import '../models/user_model.dart';
import '../services/etudiant_service.dart';
import '../widgets/cycle_access_guard.dart';

const _kColors = [Color(0xFF7C3AED), Color(0xFF2563EB)];

class UniversiteSemestresPage extends StatelessWidget {
  const UniversiteSemestresPage({super.key});

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

class _BodyState extends State<_Body> {
  int _semestre = 1;
  String get _classeNom => widget.user.classeNom ?? widget.user.niveau ?? '';

  List<NoteModel> _filtrer(List<NoteModel> all) {
    final year = DateTime.now().month >= 9 ? DateTime.now().year : DateTime.now().year - 1;
    final (debut, fin) = _semestre == 1
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
        title: const Text('Semestres',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
      ),
      body: Column(
        children: [
          _SemestrePicker(selected: _semestre, onChanged: (s) => setState(() => _semestre = s)),
          Expanded(
            child: StreamBuilder<List<NoteModel>>(
              stream: EtudiantService.notesStream(_classeNom),
              builder: (_, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Color(0xFF7C3AED)));
                }
                final notes = _filtrer(snap.data ?? []);
                final groups = <String, List<NoteModel>>{};
                for (final n in notes) { (groups[n.matiere] ??= []).add(n); }
                final ues = groups.entries.map((e) {
                  final avg = e.value.fold<double>(0, (a, n) => a + n.sur20) / e.value.length;
                  return (nom: e.key, avg: avg, count: e.value.length, notes: e.value);
                }).toList()..sort((a, b) => a.nom.compareTo(b.nom));
                final moyS = ues.isEmpty ? 0.0 : ues.fold<double>(0, (a, u) => a + u.avg) / ues.length;
                final validees = ues.where((u) => u.avg >= 10).length;

                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                  children: [
                    _SemestreBanner(
                      semestre: _semestre, moy: moyS,
                      nbUes: ues.length, validees: validees,
                      niveau: widget.user.niveau,
                    ),
                    const SizedBox(height: 16),
                    if (ues.isEmpty)
                      const Center(child: Padding(
                        padding: EdgeInsets.only(top: 24),
                        child: Text('Aucune note pour ce semestre', style: TextStyle(color: Colors.white38)),
                      ))
                    else
                      ...ues.asMap().entries.map((e) => _UeRow(
                        nom: e.value.nom,
                        avg: e.value.avg,
                        count: e.value.count,
                        index: e.key,
                      )),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Sélecteur semestre ────────────────────────────────────────────────────────

class _SemestrePicker extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onChanged;
  const _SemestrePicker({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF161B22),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [1, 2].map((s) => Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: GestureDetector(
              onTap: () => onChanged(s),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: selected == s ? const Color(0xFF7C3AED) : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: selected == s ? const Color(0xFF7C3AED) : Colors.white24),
                ),
                child: Text(
                  'Semestre $s',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: selected == s ? Colors.white : Colors.white54,
                    fontWeight: FontWeight.w600, fontSize: 13,
                  ),
                ),
              ),
            ),
          ),
        )).toList(),
      ),
    );
  }
}

// ── Bannière semestre ─────────────────────────────────────────────────────────

class _SemestreBanner extends StatelessWidget {
  final int semestre, nbUes, validees;
  final double moy;
  final String? niveau;
  const _SemestreBanner({required this.semestre, required this.moy, required this.nbUes, required this.validees, this.niveau});

  Color get _color => moy >= 14 ? Colors.green : moy >= 10 ? Colors.amber : Colors.red;

  String get _mention {
    if (moy >= 16) return 'Très bien';
    if (moy >= 14) return 'Bien';
    if (moy >= 12) return 'Assez bien';
    if (moy >= 10) return 'Passable';
    return 'Insuffisant';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
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
                    Text('Semestre $semestre · ${niveau ?? ''}',
                        style: const TextStyle(color: Colors.white70, fontSize: 12)),
                    Text(moy.toStringAsFixed(2),
                        style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                    Text('$nbUes UE · Moyenne /20',
                        style: const TextStyle(color: Colors.white60, fontSize: 12)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(color: _color.withValues(alpha: 0.25), borderRadius: BorderRadius.circular(10)),
                    child: Text(_mention, style: TextStyle(color: _color, fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                  const SizedBox(height: 6),
                  Text('$validees/$nbUes validées', style: const TextStyle(color: Colors.white54, fontSize: 11)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: moy / 20,
              backgroundColor: Colors.white.withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation<Color>(_color),
              minHeight: 4,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Ligne UE avec progress bar ────────────────────────────────────────────────

class _UeRow extends StatelessWidget {
  final String nom;
  final double avg;
  final int count, index;
  const _UeRow({required this.nom, required this.avg, required this.count, required this.index});

  static const _palette = [
    Color(0xFF7C3AED), Color(0xFF2563EB), Color(0xFF0891B2),
    Color(0xFF15803D), Color(0xFFD97706), Color(0xFFDC2626),
  ];

  Color get _accentColor => _palette[index % _palette.length];
  Color get _avgColor {
    if (avg >= 14) return const Color(0xFF16A34A);
    if (avg >= 10) return const Color(0xFFD97706);
    return const Color(0xFFDC2626);
  }
  bool get _valide => avg >= 10;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 6, height: 36,
                decoration: BoxDecoration(color: _accentColor, borderRadius: BorderRadius.circular(3)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(nom,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                    Text('$count évaluation${count > 1 ? 's' : ''}',
                        style: const TextStyle(color: Colors.white38, fontSize: 11)),
                  ],
                ),
              ),
              Row(
                children: [
                  Text(avg.toStringAsFixed(1),
                      style: TextStyle(color: _avgColor, fontWeight: FontWeight.bold, fontSize: 16)),
                  Text('/20', style: const TextStyle(color: Colors.white38, fontSize: 11)),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: (_valide ? const Color(0xFF16A34A) : const Color(0xFFDC2626)).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(_valide ? 'Validée' : 'Échec',
                        style: TextStyle(
                            color: _valide ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                            fontSize: 10, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: avg / 20,
              backgroundColor: Colors.white.withValues(alpha: 0.08),
              valueColor: AlwaysStoppedAnimation<Color>(_avgColor),
              minHeight: 3,
            ),
          ),
        ],
      ),
    );
  }
}
