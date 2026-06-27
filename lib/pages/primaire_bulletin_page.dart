import 'package:flutter/material.dart';
import '../models/note_model.dart';
import '../models/user_model.dart';
import '../services/etudiant_service.dart';
import '../widgets/cycle_access_guard.dart';

const _kColors = [Color(0xFF16A34A), Color(0xFF0891B2)];

class PrimaireBulletinPage extends StatelessWidget {
  const PrimaireBulletinPage({super.key});

  @override
  Widget build(BuildContext context) {
    return CycleAccessGuard(
      cycleCategorie: 'Primaire',
      cycleColors: _kColors,
      builder: (user) => _BulletinBody(user: user),
    );
  }
}

// ── Sélecteur trimestre ───────────────────────────────────────────────────────

class _BulletinBody extends StatefulWidget {
  final UserModel user;
  const _BulletinBody({required this.user});

  @override
  State<_BulletinBody> createState() => _BulletinBodyState();
}

class _BulletinBodyState extends State<_BulletinBody> {
  late int _trimestre;

  static int _currentTrimestre() {
    final m = DateTime.now().month;
    if (m >= 9 && m <= 11) return 1;
    if (m == 12 || m <= 2) return 2;
    return 3;
  }

  @override
  void initState() {
    super.initState();
    _trimestre = _currentTrimestre();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        elevation: 0,
        title: const Text('Mon Bulletin',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          PopupMenuButton<int>(
            color: const Color(0xFF161B22),
            child: Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _kColors.first.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('T$_trimestre',
                  style: TextStyle(color: _kColors.first, fontWeight: FontWeight.bold)),
            ),
            onSelected: (v) => setState(() => _trimestre = v),
            itemBuilder: (_) => [1, 2, 3]
                .map((t) => PopupMenuItem(
                      value: t,
                      child: Text('Trimestre $t', style: const TextStyle(color: Colors.white)),
                    ))
                .toList(),
          ),
        ],
      ),
      body: _BulletinContent(
        classeNom: widget.user.classeNom ?? widget.user.niveau ?? '',
        trimestre: _trimestre,
        nom: widget.user.displayName,
        classe: widget.user.classeNom ?? '',
      ),
    );
  }
}

// ── Contenu bulletin ──────────────────────────────────────────────────────────

class _BulletinContent extends StatelessWidget {
  final String classeNom, nom, classe;
  final int trimestre;
  const _BulletinContent({
    required this.classeNom,
    required this.trimestre,
    required this.nom,
    required this.classe,
  });

  static int _trimestreDe(DateTime d) {
    final m = d.month;
    if (m >= 9 && m <= 11) return 1;
    if (m == 12 || m <= 2) return 2;
    if (m >= 3 && m <= 5) return 3;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    if (classeNom.isEmpty) {
      return const Center(
        child: Text('Classe non assignée.', style: TextStyle(color: Colors.white38)),
      );
    }

    return StreamBuilder<List<NoteModel>>(
      stream: EtudiantService.notesStream(classeNom),
      builder: (_, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFF16A34A)));
        }

        final allNotes = (snap.data ?? [])
            .where((n) => _trimestreDe(n.date) == trimestre)
            .toList();

        if (allNotes.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.description_outlined, color: Colors.white24, size: 56),
                const SizedBox(height: 14),
                Text('Aucune note pour le trimestre $trimestre.',
                    style: const TextStyle(color: Colors.white38)),
              ],
            ),
          );
        }

        final byMatiere = <String, List<NoteModel>>{};
        for (final n in allNotes) { (byMatiere[n.matiere] ??= []).add(n); }

        double totalSomme = 0;
        int totalCount = 0;
        for (final notes in byMatiere.values) {
          for (final n in notes) {
            totalSomme += n.sur20;
            totalCount++;
          }
        }
        final moyGen = totalCount > 0 ? totalSomme / totalCount : 0.0;

        final matieres = byMatiere.entries.map((e) {
          final avg = e.value.fold<double>(0, (s, n) => s + n.sur20) / e.value.length;
          return (nom: e.key, avg: avg, notes: e.value);
        }).toList()..sort((a, b) => a.nom.compareTo(b.nom));

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
          children: [
            _BulletinHeader(nom: nom, classe: classe, trimestre: trimestre, moyGen: moyGen),
            const SizedBox(height: 16),
            ...matieres.asMap().entries.map((e) => _MatiereCard(
                  matiere: e.value.nom,
                  avg: e.value.avg,
                  notes: e.value.notes,
                  index: e.key,
                )),
          ],
        );
      },
    );
  }
}

// ── Header bulletin ───────────────────────────────────────────────────────────

class _BulletinHeader extends StatelessWidget {
  final String nom, classe;
  final int trimestre;
  final double moyGen;
  const _BulletinHeader({required this.nom, required this.classe, required this.trimestre, required this.moyGen});

  Color get _color => moyGen >= 14 ? const Color(0xFF16A34A) : moyGen >= 10 ? const Color(0xFFD97706) : const Color(0xFFDC2626);

  String get _mention {
    if (moyGen >= 16) return 'Excellent';
    if (moyGen >= 14) return 'Très bien';
    if (moyGen >= 12) return 'Bien';
    if (moyGen >= 10) return 'Assez bien';
    if (moyGen >= 8) return 'Insuffisant';
    return 'Très insuffisant';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: _kColors, begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(16),
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
                    Text('Bulletin · Trimestre $trimestre',
                        style: const TextStyle(color: Colors.white70, fontSize: 12)),
                    Text('${moyGen.toStringAsFixed(2)} / 20',
                        style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                    Text(nom, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                    if (classe.isNotEmpty)
                      Text('Classe : $classe', style: const TextStyle(color: Colors.white54, fontSize: 11)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: _color.withValues(alpha: 0.25), borderRadius: BorderRadius.circular(10)),
                child: Text(_mention, style: TextStyle(color: _color, fontWeight: FontWeight.bold, fontSize: 13)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: moyGen / 20,
              backgroundColor: Colors.white.withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation<Color>(_color),
              minHeight: 5,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Carte matière ─────────────────────────────────────────────────────────────

class _MatiereCard extends StatelessWidget {
  final String matiere;
  final double avg;
  final List<NoteModel> notes;
  final int index;
  const _MatiereCard({required this.matiere, required this.avg, required this.notes, required this.index});

  static const _palette = [
    Color(0xFF16A34A), Color(0xFF0891B2), Color(0xFF7C3AED),
    Color(0xFFD97706), Color(0xFF2563EB), Color(0xFFDC2626),
  ];

  Color get _accent => _palette[index % _palette.length];

  Color get _avgColor {
    if (avg >= 14) return const Color(0xFF16A34A);
    if (avg >= 10) return const Color(0xFFD97706);
    return const Color(0xFFDC2626);
  }

  String get _appreciation {
    if (avg >= 16) return 'Excellent';
    if (avg >= 14) return 'Très bien';
    if (avg >= 12) return 'Bien';
    if (avg >= 10) return 'Assez bien';
    if (avg >= 8) return 'Insuffisant';
    return 'Très insuffisant';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
            child: Row(
              children: [
                Container(
                  width: 5, height: 36,
                  decoration: BoxDecoration(color: _accent, borderRadius: BorderRadius.circular(3)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(matiere,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                      Text(_appreciation, style: TextStyle(color: _avgColor, fontSize: 11)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: _avgColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
                  child: Text('${avg.toStringAsFixed(2)} / 20',
                      style: TextStyle(color: _avgColor, fontWeight: FontWeight.bold, fontSize: 13)),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: avg / 20,
                backgroundColor: Colors.white.withValues(alpha: 0.08),
                valueColor: AlwaysStoppedAnimation<Color>(_avgColor),
                minHeight: 3,
              ),
            ),
          ),
          const Divider(color: Colors.white10, height: 1),
          ...notes.map((n) => _NoteRow(note: n)),
        ],
      ),
    );
  }
}

// ── Ligne note ────────────────────────────────────────────────────────────────

class _NoteRow extends StatelessWidget {
  final NoteModel note;
  const _NoteRow({required this.note});

  static String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  @override
  Widget build(BuildContext context) {
    final color = note.sur20 >= 14
        ? const Color(0xFF16A34A)
        : note.sur20 >= 10
            ? const Color(0xFFD97706)
            : const Color(0xFFDC2626);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        children: [
          Container(
            width: 44,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
            child: Text(note.sur20.toStringAsFixed(1),
                style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(note.intitule.isNotEmpty ? note.intitule : 'Évaluation',
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(_fmt(note.date), style: const TextStyle(color: Colors.white38, fontSize: 11)),
              ],
            ),
          ),
          Text('/${note.bareme.toInt()}', style: const TextStyle(color: Colors.white38, fontSize: 11)),
        ],
      ),
    );
  }
}
