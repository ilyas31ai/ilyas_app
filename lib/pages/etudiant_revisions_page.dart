import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/ai_assistant_service.dart';
import '../services/etudiant_service.dart';

// ─── Constants ────────────────────────────────────────────────────────────────

const _matieres = [
  'Mathématiques',
  'Français',
  'Histoire-Géo',
  'SVT',
  'Physique-Chimie',
  'Anglais',
  'Espagnol',
  'Informatique',
  'Autre',
];

const _matierIcons = <String, IconData>{
  'Mathématiques': Icons.calculate_outlined,
  'Français': Icons.menu_book_outlined,
  'Histoire-Géo': Icons.public_outlined,
  'SVT': Icons.eco_outlined,
  'Physique-Chimie': Icons.science_outlined,
  'Anglais': Icons.language_outlined,
  'Espagnol': Icons.translate_outlined,
  'Informatique': Icons.computer_outlined,
  'Autre': Icons.star_outline,
};

const _matierColors = <String, List<Color>>{
  'Mathématiques': [Color(0xFF2563EB), Color(0xFF0891B2)],
  'Français': [Color(0xFF7C3AED), Color(0xFF6C47FF)],
  'Histoire-Géo': [Color(0xFFB45309), Color(0xFFD97706)],
  'SVT': [Color(0xFF15803D), Color(0xFF16A34A)],
  'Physique-Chimie': [Color(0xFFDC2626), Color(0xFFEA580C)],
  'Anglais': [Color(0xFF0F766E), Color(0xFF0891B2)],
  'Espagnol': [Color(0xFFD97706), Color(0xFFCA8A04)],
  'Informatique': [Color(0xFF374151), Color(0xFF4B5563)],
  'Autre': [Color(0xFF6C47FF), Color(0xFF2563EB)],
};

// ─── Progress persistence ──────────────────────────────────────────────────────

Future<Map<String, int>> _loadProgress() async {
  final prefs = await SharedPreferences.getInstance();
  final uid = FirebaseAuth.instance.currentUser?.uid ?? 'guest';
  final raw = prefs.getString('revisions_progress_$uid') ?? '{}';
  return Map<String, int>.from(jsonDecode(raw) as Map);
}

Future<void> _saveProgress(Map<String, int> progress) async {
  final prefs = await SharedPreferences.getInstance();
  final uid = FirebaseAuth.instance.currentUser?.uid ?? 'guest';
  await prefs.setString('revisions_progress_$uid', jsonEncode(progress));
}

// ─── Main page ─────────────────────────────────────────────────────────────────

class EtudiantRevisionsPage extends StatefulWidget {
  const EtudiantRevisionsPage({super.key});

  @override
  State<EtudiantRevisionsPage> createState() =>
      _EtudiantRevisionsPageState();
}

class _EtudiantRevisionsPageState extends State<EtudiantRevisionsPage> {
  Map<String, int> _progress = {};
  String? _classeNom;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final progress = await _loadProgress();
    final classeNom =
        await EtudiantService.classeNomStream().first;
    if (mounted) {
      setState(() {
        _progress = progress;
        _classeNom = classeNom;
        _loading = false;
      });
    }
  }

  void _onProgressUpdate(String matiere, int score) {
    final updated = Map<String, int>.from(_progress)..[matiere] = score;
    setState(() => _progress = updated);
    _saveProgress(updated);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        elevation: 0,
        title: const Text(
          'Révisions',
          style: TextStyle(
              color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF2563EB)))
          : CustomScrollView(
              slivers: [
                // ── Progress banner ──────────────────────────────────────
                SliverToBoxAdapter(
                  child: _ProgressBanner(
                      progress: _progress, total: _matieres.length),
                ),
                // ── Subject grid ────────────────────────────────────────
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  sliver: SliverGrid(
                    delegate: SliverChildBuilderDelegate(
                      (context, i) {
                        final m = _matieres[i];
                        return _MatiereCard(
                          matiere: m,
                          score: _progress[m],
                          icon: _matierIcons[m] ?? Icons.star_outline,
                          colors: _matierColors[m] ??
                              const [Color(0xFF6C47FF), Color(0xFF2563EB)],
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => _MatiereRevisionsPage(
                                  matiere: m,
                                  classeNom: _classeNom ?? '',
                                  score: _progress[m] ?? 0,
                                  onScoreUpdate: (s) =>
                                      _onProgressUpdate(m, s),
                                ),
                              ),
                            );
                          },
                        );
                      },
                      childCount: _matieres.length,
                    ),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 1.15,
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

// ── Progress banner ────────────────────────────────────────────────────────────

class _ProgressBanner extends StatelessWidget {
  final Map<String, int> progress;
  final int total;
  const _ProgressBanner({required this.progress, required this.total});

  @override
  Widget build(BuildContext context) {
    final mastered =
        progress.values.where((v) => v >= 80).length;
    final toReinforce =
        progress.values.where((v) => v > 0 && v < 80).length;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F766E), Color(0xFF16A34A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Ma progression',
                    style: TextStyle(
                        color: Colors.white70, fontSize: 12)),
                const SizedBox(height: 4),
                Text(
                  '$mastered / $total matières maîtrisées',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold),
                ),
                if (toReinforce > 0)
                  Text(
                    '$toReinforce à renforcer',
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 12),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 56,
                height: 56,
                child: CircularProgressIndicator(
                  value: total == 0 ? 0 : mastered / total,
                  backgroundColor: Colors.white30,
                  color: Colors.white,
                  strokeWidth: 5,
                ),
              ),
              Text(
                '${total == 0 ? 0 : (mastered * 100 ~/ total)}%',
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Subject card ───────────────────────────────────────────────────────────────

class _MatiereCard extends StatelessWidget {
  final String matiere;
  final int? score;
  final IconData icon;
  final List<Color> colors;
  final VoidCallback onTap;

  const _MatiereCard({
    required this.matiere,
    required this.score,
    required this.icon,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final pct = score ?? 0;
    final statusColor = pct >= 80
        ? const Color(0xFF16A34A)
        : pct >= 40
            ? const Color(0xFFD97706)
            : Colors.white38;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF161B22),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: colors),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
            const SizedBox(height: 10),
            Text(
              matiere,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            if (pct > 0)
              LinearProgressIndicator(
                value: pct / 100,
                backgroundColor: Colors.white12,
                color: statusColor,
              )
            else
              const Text('Non démarré',
                  style:
                      TextStyle(color: Colors.white38, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

// ─── Per-matière revision page ────────────────────────────────────────────────

class _MatiereRevisionsPage extends StatefulWidget {
  final String matiere;
  final String classeNom;
  final int score;
  final void Function(int) onScoreUpdate;

  const _MatiereRevisionsPage({
    required this.matiere,
    required this.classeNom,
    required this.score,
    required this.onScoreUpdate,
  });

  @override
  State<_MatiereRevisionsPage> createState() =>
      _MatiereRevisionsPageState();
}

class _MatiereRevisionsPageState extends State<_MatiereRevisionsPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = _matierColors[widget.matiere] ??
        const [Color(0xFF6C47FF), Color(0xFF2563EB)];

    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        elevation: 0,
        title: Text(
          widget.matiere,
          style: const TextStyle(
              color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'Cours'),
            Tab(text: 'Exercices'),
            Tab(text: 'Quiz'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _CoursTab(
              matiere: widget.matiere,
              classeNom: widget.classeNom,
              gradientColors: colors),
          _ExercicesTab(
              matiere: widget.matiere,
              classeNom: widget.classeNom,
              gradientColors: colors),
          _QuizTab(
            matiere: widget.matiere,
            classeNom: widget.classeNom,
            initialScore: widget.score,
            onScoreUpdate: widget.onScoreUpdate,
            gradientColors: colors,
          ),
        ],
      ),
    );
  }
}

// ── Cours tab ──────────────────────────────────────────────────────────────────

class _CoursTab extends StatefulWidget {
  final String matiere;
  final String classeNom;
  final List<Color> gradientColors;
  const _CoursTab({
    required this.matiere,
    required this.classeNom,
    required this.gradientColors,
  });

  @override
  State<_CoursTab> createState() => _CoursTabState();
}

class _CoursTabState extends State<_CoursTab> {
  final _chapCtrl = TextEditingController();
  String? _explanation;
  bool _loading = false;

  @override
  void dispose() {
    _chapCtrl.dispose();
    super.dispose();
  }

  Future<void> _explain() async {
    if (_chapCtrl.text.trim().isEmpty) return;
    setState(() { _loading = true; _explanation = null; });
    final result = await AiAssistantService.expliquerNotion(
      notion: _chapCtrl.text.trim(),
      matiere: widget.matiere,
      classeNom: widget.classeNom,
    );
    if (mounted) setState(() { _explanation = result; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Summary card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: widget.gradientColors),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Assistant de cours',
                  style: TextStyle(
                      color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 4),
              const Text(
                'Demande une explication sur n\'importe quelle notion.',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _chapCtrl,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: 'Notion ou chapitre à expliquer',
            labelStyle: const TextStyle(color: Colors.white38),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide:
                  BorderSide(color: Colors.white.withValues(alpha: 0.15)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: widget.gradientColors.first),
            ),
          ),
          maxLines: 2,
        ),
        const SizedBox(height: 10),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: widget.gradientColors.first,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
          onPressed: _loading ? null : _explain,
          icon: _loading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2))
              : const Icon(Icons.auto_fix_high),
          label: const Text('Expliquer'),
        ),
        if (_explanation != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF161B22),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Text(
              _explanation!,
              style: const TextStyle(color: Colors.white, height: 1.5),
            ),
          ),
        ],
        const SizedBox(height: 24),
        const _SectionHeader('Points clés à retenir'),
        const SizedBox(height: 8),
        _KeyPointsCard(matiere: widget.matiere),
      ],
    );
  }
}

class _KeyPointsCard extends StatelessWidget {
  final String matiere;
  const _KeyPointsCard({required this.matiere});

  static const _points = <String, List<String>>{
    'Mathématiques': [
      'Maîtriser les opérations de base',
      'Comprendre les fractions et pourcentages',
      'Résolution d\'équations du 1er degré',
      'Géométrie : angles, triangles, cercles',
    ],
    'Français': [
      'Accord du participe passé',
      'Subjonctif vs indicatif',
      'Figures de style : métaphore, comparaison',
      'Structure d\'une dissertation',
    ],
    'Histoire-Géo': [
      'Chronologie des grandes périodes',
      'Lecture et analyse de cartes',
      'Notions de développement durable',
      'Mondialisation et échanges internationaux',
    ],
    'SVT': [
      'Organisation cellulaire du vivant',
      'Cycles de reproduction',
      'Écosystèmes et chaînes alimentaires',
      'Génétique de base',
    ],
    'Physique-Chimie': [
      'Lois de Newton',
      'États de la matière',
      'Réactions chimiques et équations',
      'Optique et lumière',
    ],
    'Anglais': [
      'Temps verbaux : present, past, future',
      'Vocabulaire thématique',
      'Compréhension écrite',
      'Expression orale et intonation',
    ],
  };

  @override
  Widget build(BuildContext context) {
    final pts = _points[matiere] ?? ['Consulte tes cours et fiches de révision.'];
    return Column(
      children: pts
          .map((p) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF161B22),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: Colors.white.withValues(alpha: 0.05)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_outline,
                        color: Color(0xFF16A34A), size: 16),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(p,
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 13)),
                    ),
                  ],
                ),
              ))
          .toList(),
    );
  }
}

// ── Exercices tab ──────────────────────────────────────────────────────────────

class _ExercicesTab extends StatefulWidget {
  final String matiere;
  final String classeNom;
  final List<Color> gradientColors;
  const _ExercicesTab({
    required this.matiere,
    required this.classeNom,
    required this.gradientColors,
  });

  @override
  State<_ExercicesTab> createState() => _ExercicesTabState();
}

class _ExercicesTabState extends State<_ExercicesTab> {
  String _level = 'Facile';
  String? _exercise;
  String? _correction;
  bool _loading = false;
  bool _showCorrection = false;

  Future<void> _generate() async {
    setState(() { _loading = true; _exercise = null; _correction = null; _showCorrection = false; });
    final prompt =
        'Génère un exercice de niveau $_level en ${widget.matiere} pour un élève${widget.classeNom.isNotEmpty ? ' de ${widget.classeNom}' : ''}. '
        'Format :\n**Exercice :**\n[exercice ici]\n\n**Correction :**\n[correction détaillée ici]';
    final apiKey = await AiAssistantService.getApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      if (mounted) {
        setState(() {
          _exercise = 'Configure la clé API dans les paramètres pour générer des exercices.';
          _loading = false;
        });
      }
      return;
    }
    // Use AI to generate
    final result = await AiAssistantService.expliquerNotion(
      notion: prompt,
      matiere: widget.matiere,
      classeNom: widget.classeNom,
    );
    if (mounted) {
      // Split exercise from correction
      final parts = result.split(RegExp(r'\*\*Correction\s*:\*\*', caseSensitive: false));
      setState(() {
        _exercise = parts.isNotEmpty ? parts[0].replaceAll(RegExp(r'\*\*Exercice\s*:\*\*', caseSensitive: false), '').trim() : result;
        _correction = parts.length > 1 ? parts[1].trim() : null;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Level selector
        Row(
          children: ['Facile', 'Intermédiaire', 'Avancé'].map((l) {
            final selected = l == _level;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(l),
                selected: selected,
                onSelected: (_) => setState(() => _level = l),
                selectedColor: widget.gradientColors.first,
                labelStyle: TextStyle(
                    color: selected ? Colors.white : Colors.white60),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: widget.gradientColors.first,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(44),
          ),
          onPressed: _loading ? null : _generate,
          icon: _loading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2))
              : const Icon(Icons.refresh),
          label: Text('Générer un exercice $_level'),
        ),
        if (_exercise != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF161B22),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Text(_exercise!,
                style: const TextStyle(
                    color: Colors.white, height: 1.5)),
          ),
          if (_correction != null) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () =>
                  setState(() => _showCorrection = !_showCorrection),
              icon: Icon(_showCorrection
                  ? Icons.visibility_off
                  : Icons.visibility),
              label: Text(_showCorrection
                  ? 'Masquer la correction'
                  : 'Voir la correction'),
            ),
            if (_showCorrection)
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D2A1A),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: const Color(0xFF16A34A).withValues(alpha: 0.4)),
                ),
                child: Text(_correction!,
                    style: const TextStyle(
                        color: Colors.white, height: 1.5)),
              ),
          ],
        ],
      ],
    );
  }
}

// ── Quiz tab ───────────────────────────────────────────────────────────────────

class _QuizTab extends StatefulWidget {
  final String matiere;
  final String classeNom;
  final int initialScore;
  final void Function(int) onScoreUpdate;
  final List<Color> gradientColors;

  const _QuizTab({
    required this.matiere,
    required this.classeNom,
    required this.initialScore,
    required this.onScoreUpdate,
    required this.gradientColors,
  });

  @override
  State<_QuizTab> createState() => _QuizTabState();
}

// A simple 5-question static quiz per subject
const _quizzes = <String, List<Map<String, dynamic>>>{
  'Mathématiques': [
    {'q': 'Combien font 15 × 8 ?', 'choices': ['110', '120', '130', '140'], 'answer': 1},
    {'q': 'Quelle est la racine carrée de 144 ?', 'choices': ['10', '11', '12', '13'], 'answer': 2},
    {'q': 'Quel est le périmètre d\'un carré de côté 5 cm ?', 'choices': ['10 cm', '15 cm', '20 cm', '25 cm'], 'answer': 2},
    {'q': '3² + 4² = ?', 'choices': ['20', '25', '30', '35'], 'answer': 1},
    {'q': 'Combien font 7/8 + 1/8 ?', 'choices': ['7/16', '8/8', '1', '8/16'], 'answer': 2},
  ],
  'Français': [
    {'q': 'Quel est le pluriel de "bal" ?', 'choices': ['bals', 'baux', 'bal', 'bales'], 'answer': 0},
    {'q': '"Il faut que je ___" — quel mode verbal ?', 'choices': ['indicatif', 'subjonctif', 'impératif', 'conditionnel'], 'answer': 1},
    {'q': '"Vif comme l\'éclair" est une...', 'choices': ['métaphore', 'comparaison', 'allitération', 'hyperbole'], 'answer': 1},
    {'q': 'Quel est le participe passé de "prendre" ?', 'choices': ['prit', 'prendu', 'pris', 'prend'], 'answer': 2},
    {'q': '"Je ne sais pas si tu VIENDRAS" — quel temps ?', 'choices': ['présent', 'futur', 'conditionnel', 'subjonctif'], 'answer': 1},
  ],
};

class _QuizTabState extends State<_QuizTab> {
  int _qi = 0;
  int? _selected;
  bool _answered = false;
  int _correct = 0;
  bool _done = false;
  late List<Map<String, dynamic>> _questions;

  @override
  void initState() {
    super.initState();
    _questions = _quizzes[widget.matiere] ?? _defaultQuiz();
  }

  List<Map<String, dynamic>> _defaultQuiz() => [
    {'q': 'Ce module de quiz est en cours de développement pour ${widget.matiere}.', 'choices': ['OK', 'Compris', 'Suivant', 'Continuer'], 'answer': 0},
  ];

  void _select(int i) {
    if (_answered) return;
    setState(() {
      _selected = i;
      _answered = true;
      if (i == _questions[_qi]['answer']) _correct++;
    });
  }

  void _next() {
    if (_qi < _questions.length - 1) {
      setState(() { _qi++; _selected = null; _answered = false; });
    } else {
      final pct = (_correct * 100 ~/ _questions.length);
      setState(() => _done = true);
      widget.onScoreUpdate(pct);
    }
  }

  void _restart() {
    setState(() { _qi = 0; _selected = null; _answered = false; _correct = 0; _done = false; });
  }

  @override
  Widget build(BuildContext context) {
    if (_done) return _buildResult();
    final q = _questions[_qi];
    final choices = List<String>.from(q['choices'] as List);
    final answer = q['answer'] as int;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Progress
          LinearProgressIndicator(
            value: (_qi + 1) / _questions.length,
            backgroundColor: Colors.white12,
            color: widget.gradientColors.first,
          ),
          const SizedBox(height: 8),
          Text(
            'Question ${_qi + 1} / ${_questions.length}',
            style: const TextStyle(color: Colors.white38, fontSize: 12),
          ),
          const SizedBox(height: 16),
          // Question
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF161B22),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Text(
              q['q'] as String,
              style: const TextStyle(
                  color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 16),
          // Choices
          ...choices.asMap().entries.map((e) {
            Color bg = const Color(0xFF161B22);
            Color border = Colors.white.withValues(alpha: 0.08);
            if (_answered) {
              if (e.key == answer) {
                bg = const Color(0xFF0D2A1A);
                border = const Color(0xFF16A34A);
              } else if (e.key == _selected) {
                bg = const Color(0xFF2A0D0D);
                border = const Color(0xFFDC2626);
              }
            }
            return GestureDetector(
              onTap: () => _select(e.key),
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: border),
                ),
                child: Row(
                  children: [
                    if (_answered && e.key == answer)
                      const Icon(Icons.check_circle,
                          color: Color(0xFF16A34A), size: 18)
                    else if (_answered && e.key == _selected)
                      const Icon(Icons.cancel, color: Color(0xFFDC2626), size: 18)
                    else
                      const Icon(Icons.radio_button_unchecked,
                          color: Colors.white38, size: 18),
                    const SizedBox(width: 10),
                    Text(e.value,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 14)),
                  ],
                ),
              ),
            );
          }),
          const Spacer(),
          if (_answered)
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.gradientColors.first,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(44),
              ),
              onPressed: _next,
              child: Text(_qi < _questions.length - 1
                  ? 'Question suivante'
                  : 'Voir les résultats'),
            ),
        ],
      ),
    );
  }

  Widget _buildResult() {
    final pct = _correct * 100 ~/ _questions.length;
    final color = pct >= 80
        ? const Color(0xFF16A34A)
        : pct >= 50
            ? const Color(0xFFD97706)
            : const Color(0xFFDC2626);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 50,
              backgroundColor: color.withValues(alpha: 0.15),
              child: Text(
                '$pct%',
                style: TextStyle(
                    fontSize: 28, fontWeight: FontWeight.bold, color: color),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '$_correct / ${_questions.length} bonnes réponses',
              style: const TextStyle(color: Colors.white, fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              pct >= 80
                  ? 'Excellent ! Matière maîtrisée.'
                  : pct >= 50
                      ? 'Bien ! Continue à réviser.'
                      : 'Il faut réviser davantage.',
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: _restart,
              icon: const Icon(Icons.refresh),
              label: const Text('Recommencer'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);
  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
            color: Colors.white38,
            fontSize: 11,
            letterSpacing: 1.2,
            fontWeight: FontWeight.w600),
      );
}
