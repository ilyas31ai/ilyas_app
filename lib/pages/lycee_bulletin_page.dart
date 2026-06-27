import 'package:flutter/material.dart';
import '../models/note_model.dart';
import '../models/user_model.dart';
import '../services/etudiant_service.dart';
import '../widgets/cycle_access_guard.dart';

const _kColors = [Color(0xFF6C47FF), Color(0xFF15803D)];

class LyceeBulletinPage extends StatelessWidget {
  const LyceeBulletinPage({super.key});

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

class _BodyState extends State<_Body> {
  int _trimestre = _currentTrimestre;
  String get _classeNom => widget.user.classeNom ?? widget.user.niveau ?? '';

  static int get _currentTrimestre {
    final m = DateTime.now().month;
    if (m >= 9 && m <= 11) return 1;
    if (m >= 12 || m <= 2) return 2;
    return 3;
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

  List<NoteModel> _filtrer(List<NoteModel> all) =>
      all.where((n) => _trimestreDe(n.date) == _trimestre).toList();

  Map<String, double> _moyennesParMatiere(List<NoteModel> notes) {
    final groups = <String, List<double>>{};
    for (final n in notes) { (groups[n.matiere] ??= []).add(n.sur20); }
    return groups.map((m, vals) => MapEntry(m, vals.reduce((a, b) => a + b) / vals.length));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        elevation: 0,
        title: const Text('Bulletin', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
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
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Trim. $_trimestre',
                      style: TextStyle(color: _kColors.first, fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(width: 4),
                  Icon(Icons.arrow_drop_down, color: _kColors.first, size: 18),
                ],
              ),
            ),
            onSelected: (v) => setState(() => _trimestre = v),
            itemBuilder: (_) => [1, 2, 3].map((t) => PopupMenuItem(
              value: t,
              child: Text('Trimestre $t', style: const TextStyle(color: Colors.white)),
            )).toList(),
          ),
        ],
      ),
      body: Column(
        children: [
          _TrimestrePicker(selected: _trimestre, onChanged: (t) => setState(() => _trimestre = t)),
          Expanded(
            child: StreamBuilder<List<NoteModel>>(
              stream: EtudiantService.notesStream(_classeNom),
              builder: (_, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Color(0xFF6C47FF)));
                }
                final all = snap.data ?? [];
                final notes = _filtrer(all);
                if (notes.isEmpty) {
                  return _EmptyBulletin(trimestre: _trimestre);
                }
                final moyennes = _moyennesParMatiere(notes);
                final matieres = moyennes.keys.toList()..sort();
                final moyGen = moyennes.values.reduce((a, b) => a + b) / moyennes.length;

                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
                  children: [
                    _BulletinHeader(
                      nom: widget.user.displayName,
                      niveau: widget.user.niveau,
                      classe: _classeNom,
                      trimestre: _trimestre,
                      moyenne: moyGen,
                    ),
                    const SizedBox(height: 16),
                    ...matieres.asMap().entries.map((e) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _BulletinRow(
                        matiere: e.value,
                        moyenne: moyennes[e.value]!,
                        nbNotes: notes.where((n) => n.matiere == e.value).length,
                        accentColor: _kMatColors[e.key % _kMatColors.length],
                      ),
                    )),
                    const SizedBox(height: 16),
                    _AppreciationCard(moyenne: moyGen),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  static const _kMatColors = [
    Color(0xFF6C47FF), Color(0xFF2563EB), Color(0xFF0F766E),
    Color(0xFFDC2626), Color(0xFFD97706), Color(0xFFBE185D),
    Color(0xFF7C3AED), Color(0xFF0891B2),
  ];
}

// ── Sélecteur trimestre ───────────────────────────────────────────────────────

class _TrimestrePicker extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onChanged;
  const _TrimestrePicker({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF161B22),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [1, 2, 3].map((t) => Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: GestureDetector(
              onTap: () => onChanged(t),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: selected == t ? _kColors.first : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: selected == t ? _kColors.first : Colors.white24),
                ),
                child: Text(
                  'Trim. $t',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: selected == t ? Colors.white : Colors.white54,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
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

// ── État vide ─────────────────────────────────────────────────────────────────

class _EmptyBulletin extends StatelessWidget {
  final int trimestre;
  const _EmptyBulletin({required this.trimestre});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.description_outlined, color: Colors.white24, size: 48),
          const SizedBox(height: 12),
          Text('Aucune note pour le trimestre $trimestre', style: const TextStyle(color: Colors.white38)),
          const SizedBox(height: 8),
          const Text('Les notes seront visibles une fois publiées', style: TextStyle(color: Colors.white24, fontSize: 12)),
        ],
      ),
    );
  }
}

// ── En-tête bulletin ──────────────────────────────────────────────────────────

class _BulletinHeader extends StatelessWidget {
  final String nom;
  final String? niveau;
  final String classe;
  final int trimestre;
  final double moyenne;
  const _BulletinHeader({
    required this.nom,
    this.niveau,
    required this.classe,
    required this.trimestre,
    required this.moyenne,
  });

  Color get _color => moyenne >= 14 ? Colors.green : moyenne >= 10 ? Colors.amber : Colors.red;

  String get _mention {
    if (moyenne >= 16) return 'Félicitations du jury';
    if (moyenne >= 14) return 'Mention Bien';
    if (moyenne >= 12) return 'Mention Assez Bien';
    if (moyenne >= 10) return 'Admis';
    return 'Avertissement';
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
              const Icon(Icons.description_outlined, color: Colors.white70, size: 18),
              const SizedBox(width: 8),
              Text('Bulletin — Trimestre $trimestre',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 10),
          Text(nom, style: const TextStyle(color: Colors.white70, fontSize: 13)),
          if (niveau != null && niveau!.isNotEmpty)
            Text('Niveau : $niveau', style: const TextStyle(color: Colors.white54, fontSize: 12)),
          if (classe.isNotEmpty)
            Text('Classe : $classe', style: const TextStyle(color: Colors.white54, fontSize: 12)),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Moyenne générale', style: TextStyle(color: Colors.white60, fontSize: 12)),
                    Text('${moyenne.toStringAsFixed(2)} / 20',
                        style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: _color.withValues(alpha: 0.25), borderRadius: BorderRadius.circular(10)),
                child: Text(_mention, style: TextStyle(color: _color, fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: moyenne / 20,
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

// ── Ligne matière ─────────────────────────────────────────────────────────────

class _BulletinRow extends StatelessWidget {
  final String matiere;
  final double moyenne;
  final int nbNotes;
  final Color accentColor;
  const _BulletinRow({required this.matiere, required this.moyenne, required this.nbNotes, required this.accentColor});

  Color get _color => moyenne >= 14 ? Colors.green : moyenne >= 10 ? Colors.amber : Colors.red;

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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          Container(
            width: 4, height: 32,
            decoration: BoxDecoration(color: accentColor, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(matiere, style: const TextStyle(color: Colors.white, fontSize: 14)),
                Text('$nbNotes note${nbNotes > 1 ? 's' : ''} · $_appreciation',
                    style: TextStyle(color: _color.withValues(alpha: 0.7), fontSize: 11)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(moyenne.toStringAsFixed(1), style: TextStyle(color: _color, fontWeight: FontWeight.bold, fontSize: 16)),
              Text('/20', style: const TextStyle(color: Colors.white38, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Carte appréciations ───────────────────────────────────────────────────────

class _AppreciationCard extends StatelessWidget {
  final double moyenne;
  const _AppreciationCard({required this.moyenne});

  String get _texte {
    if (moyenne >= 16) return 'Félicitations du conseil de classe. Résultats remarquables dignes d\'un bachelier d\'excellence. Maintenez cette dynamique jusqu\'au BAC.';
    if (moyenne >= 14) return 'Mention Bien. Excellent niveau secondaire. Avec ce rythme, le Baccalauréat est à votre portée.';
    if (moyenne >= 12) return 'Mention Assez Bien. Bon trimestre. Renforcez les matières à fort coefficient pour viser la mention au BAC.';
    if (moyenne >= 10) return 'Résultats satisfaisants. Travail régulier requis pour sécuriser les matières clés du BAC.';
    if (moyenne >= 8) return 'Résultats insuffisants. Un programme de soutien dans les matières à coefficient élevé est fortement recommandé.';
    return 'Résultats très insuffisants. Consultez immédiatement vos professeurs principaux. Un plan de remédiation urgent est nécessaire.';
  }

  Color get _color => moyenne >= 14 ? Colors.green : moyenne >= 10 ? Colors.amber : Colors.red;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.comment_outlined, color: _color, size: 16),
              const SizedBox(width: 8),
              Text('Appréciation du conseil de classe',
                  style: TextStyle(color: _color, fontWeight: FontWeight.w600, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 10),
          Text(_texte, style: const TextStyle(color: Colors.white60, fontSize: 13, height: 1.5)),
        ],
      ),
    );
  }
}
