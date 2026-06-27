import 'package:flutter/material.dart';

import '../models/devoir_model.dart';
import '../services/ai_revision_service.dart';
import '../services/maitrise_service.dart';

// ─── Couleurs matières ────────────────────────────────────────────────────────

const _kColors = <String, List<Color>>{
  'Mathématiques'   : [Color(0xFF2563EB), Color(0xFF0891B2)],
  'Français'        : [Color(0xFF7C3AED), Color(0xFF6C47FF)],
  'Histoire-Géo'    : [Color(0xFFB45309), Color(0xFFD97706)],
  'SVT'             : [Color(0xFF15803D), Color(0xFF16A34A)],
  'Physique-Chimie' : [Color(0xFFDC2626), Color(0xFFEA580C)],
  'Anglais'         : [Color(0xFF0F766E), Color(0xFF0891B2)],
  'Philosophie'     : [Color(0xFF6C47FF), Color(0xFF9333EA)],
  'Informatique'    : [Color(0xFF374151), Color(0xFF4B5563)],
};

List<Color> _grad(String m) =>
    _kColors[m] ?? const [Color(0xFF6C47FF), Color(0xFF2563EB)];

// ═══════════════════════════════════════════════════════════════════════════════
// Page principale
// ═══════════════════════════════════════════════════════════════════════════════

class EtudiantRevisionsIaPage extends StatefulWidget {
  final DevoirModel devoir;
  const EtudiantRevisionsIaPage({super.key, required this.devoir});

  @override
  State<EtudiantRevisionsIaPage> createState() => _EtudiantRevisionsIaPageState();
}

class _EtudiantRevisionsIaPageState extends State<EtudiantRevisionsIaPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  // Lazy-loaded content per tab
  Map<String, String>? _analyse;
  String? _resume;
  String? _exercices;
  bool _analyseLoading = false;
  bool _resumeLoading  = false;
  bool _exoLoading     = false;
  String _exoNiveau    = 'Intermédiaire';

  List<Map<String, dynamic>>? _quiz;
  bool _quizLoading = false;

  bool _isAdapted = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 5, vsync: this);
    _tabs.addListener(_onTabChange);
    _loadAnalyse();
    _checkAdaptation();
  }

  Future<void> _checkAdaptation() async {
    final ctx = await MaitriseService.contexteAdaptatif(widget.devoir.matiere);
    if (mounted && ctx.isNotEmpty) setState(() => _isAdapted = true);
  }

  @override
  void dispose() {
    _tabs
      ..removeListener(_onTabChange)
      ..dispose();
    super.dispose();
  }

  void _onTabChange() {
    if (!_tabs.indexIsChanging) return;
    switch (_tabs.index) {
      case 0: _loadAnalyse();
      case 1: _loadResume();
      case 2: break; // exercices loaded on demand
      case 3: _loadQuiz();
      case 4: break; // aide loaded on demand
    }
  }

  Future<void> _loadAnalyse() async {
    if (_analyse != null || _analyseLoading) return;
    setState(() => _analyseLoading = true);
    final r = await AiRevisionService.analyserDevoir(widget.devoir);
    if (mounted) setState(() { _analyse = r; _analyseLoading = false; });
  }

  Future<void> _loadResume() async {
    if (_resume != null || _resumeLoading) return;
    setState(() => _resumeLoading = true);
    final r = await AiRevisionService.genererResume(widget.devoir);
    if (mounted) setState(() { _resume = r; _resumeLoading = false; });
  }

  Future<void> _loadExercices() async {
    if (_exoLoading) return;
    setState(() { _exoLoading = true; _exercices = null; });
    final r = await AiRevisionService.genererExercices(widget.devoir, _exoNiveau);
    if (mounted) setState(() { _exercices = r; _exoLoading = false; });
  }

  Future<void> _loadQuiz() async {
    if (_quiz != null || _quizLoading) return;
    setState(() => _quizLoading = true);
    final r = await AiRevisionService.genererQuiz(widget.devoir);
    if (mounted) setState(() { _quiz = r; _quizLoading = false; });
  }

  @override
  Widget build(BuildContext context) {
    final d    = widget.devoir;
    final grad = _grad(d.matiere);

    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(d.titre,
                style: const TextStyle(
                    color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            Row(children: [
              Text('${d.matiere} · ${d.classeNom}',
                  style: const TextStyle(color: Colors.white38, fontSize: 11)),
              if (_isAdapted) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F766E).withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF0F766E).withValues(alpha: 0.5)),
                  ),
                  child: const Text('🎯 Adapté',
                      style: TextStyle(color: Color(0xFF0F766E), fontSize: 9, fontWeight: FontWeight.bold)),
                ),
              ],
            ]),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white54),
            tooltip: 'Vider le cache IA',
            onPressed: () async {
              await AiRevisionService.clearCache(d.id);
              if (mounted) {
                setState(() {
                  _analyse = null; _resume = null;
                  _exercices = null; _quiz = null;
                  _isAdapted = false;
                });
                _loadAnalyse();
                _checkAdaptation();
              }
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          indicatorColor: grad.first,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white38,
          tabs: const [
            Tab(text: '🔍 Analyse'),
            Tab(text: '📚 Cours'),
            Tab(text: '✏️ Exercices'),
            Tab(text: '❓ Quiz'),
            Tab(text: '💬 Aide IA'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _AnalyseTab(analyse: _analyse, loading: _analyseLoading, grad: grad),
          _CoursTab(resume: _resume, loading: _resumeLoading, grad: grad, onLoad: _loadResume),
          _ExercicesTab(
            exercices: _exercices,
            loading: _exoLoading,
            niveau: _exoNiveau,
            grad: grad,
            onLevelChange: (l) { _exoNiveau = l; _exercices = null; },
            onGenerate: _loadExercices,
            matiere: d.matiere,
            categorie: d.categorie,
            sourceTitre: d.titre,
          ),
          _QuizTab(
            quiz: _quiz, loading: _quizLoading, grad: grad, onLoad: _loadQuiz,
            matiere: d.matiere, categorie: d.categorie,
            sourceType: 'quiz_devoir', sourceTitre: d.titre,
          ),
          _AideTab(devoir: widget.devoir, grad: grad),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Tab 1 — Analyse
// ═══════════════════════════════════════════════════════════════════════════════

class _AnalyseTab extends StatelessWidget {
  final Map<String, String>? analyse;
  final bool loading;
  final List<Color> grad;
  const _AnalyseTab({required this.analyse, required this.loading, required this.grad});

  @override
  Widget build(BuildContext context) {
    if (loading) return const _LoadingView(msg: 'Analyse du devoir en cours…');

    final a = analyse ?? {};
    final fields = [
      ('📖 Matière',       a['matiere']     ?? '—'),
      ('📌 Chapitre',      a['chapitre']    ?? '—'),
      ('🧠 Notions',       a['notions']     ?? '—'),
      ('🎯 Compétences',   a['competences'] ?? '—'),
      ('📊 Difficulté',    a['difficulte']  ?? '—'),
      ('💡 Conseils',      a['conseils']    ?? '—'),
    ];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _GradBanner(
          grad: grad,
          icon: Icons.auto_awesome,
          title: 'Analyse IA du devoir',
          subtitle: 'Notions identifiées et conseils de révision',
        ),
        const SizedBox(height: 16),
        ...fields.map((f) => _InfoCard(label: f.$1, value: f.$2)),
        const SizedBox(height: 8),
        _InfoBox(
          icon: Icons.info_outline,
          color: Colors.blue,
          text: 'L\'IA analyse le contenu du devoir pour adapter ton programme de révision.',
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Tab 2 — Cours
// ═══════════════════════════════════════════════════════════════════════════════

class _CoursTab extends StatelessWidget {
  final String? resume;
  final bool loading;
  final List<Color> grad;
  final VoidCallback onLoad;
  const _CoursTab({required this.resume, required this.loading, required this.grad, required this.onLoad});

  @override
  Widget build(BuildContext context) {
    if (loading) return const _LoadingView(msg: 'Génération du cours en cours…');

    if (resume == null) {
      return _EmptyView(
        icon: Icons.menu_book_outlined,
        msg: 'Cours non encore généré',
        btnLabel: 'Générer le cours',
        onTap: onLoad,
        grad: grad,
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _GradBanner(
          grad: grad,
          icon: Icons.menu_book_outlined,
          title: 'Cours adapté',
          subtitle: 'Résumé des notions de ce devoir',
        ),
        const SizedBox(height: 16),
        _TextCard(text: resume!),
        const SizedBox(height: 12),
        _InfoBox(
          icon: Icons.block,
          color: Colors.orange,
          text: 'Ce cours porte sur les NOTIONS du devoir — pas sur ses réponses.',
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Tab 3 — Exercices similaires
// ═══════════════════════════════════════════════════════════════════════════════

class _ExercicesTab extends StatefulWidget {
  final String? exercices;
  final bool loading;
  final String niveau;
  final List<Color> grad;
  final void Function(String) onLevelChange;
  final VoidCallback onGenerate;
  final String matiere, categorie, sourceTitre;
  const _ExercicesTab({
    required this.exercices,
    required this.loading,
    required this.niveau,
    required this.grad,
    required this.onLevelChange,
    required this.onGenerate,
    required this.matiere,
    required this.categorie,
    required this.sourceTitre,
  });
  @override
  State<_ExercicesTab> createState() => _ExercicesTabState();
}

class _ExercicesTabState extends State<_ExercicesTab> {
  bool _showCorrection = false;
  late String _level;
  bool _selfEvalDone    = false;
  bool _selfEvalSaving  = false;
  String? _selfEvalNiveau; // 'maitrise' | 'en_cours' | 'a_retravailler'

  @override
  void initState() {
    super.initState();
    _level = widget.niveau;
  }

  @override
  void didUpdateWidget(_ExercicesTab old) {
    super.didUpdateWidget(old);
    if (old.exercices != widget.exercices) {
      _showCorrection = false;
      _selfEvalDone   = false;
      _selfEvalNiveau = null;
    }
  }

  Future<void> _doSelfEval(int score, String niveau) async {
    if (_selfEvalDone) return;
    setState(() { _selfEvalSaving = true; _selfEvalNiveau = niveau; });
    final slug   = widget.matiere.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_');
    final label  = '${widget.matiere} — exercices ${widget.niveau}';
    final erreurs = score < 50 ? ['Difficultés sur les exercices de niveau ${widget.niveau}'] : <String>[];
    await MaitriseService.enregistrer(
      notions     : [{'id': '${slug}_exo', 'label': label, 'score': score, 'erreurs': erreurs}],
      matiere     : widget.matiere,
      categorie   : widget.categorie,
      sourceType  : 'exercice',
      sourceTitre : widget.sourceTitre,
    );
    if (mounted) setState(() { _selfEvalDone = true; _selfEvalSaving = false; });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.loading) return const _LoadingView(msg: 'Génération des exercices…');

    final exo = widget.exercices;
    String? ex, corr;
    if (exo != null) {
      final corrIdx = exo.indexOf('**Correction');
      if (corrIdx > 0) {
        ex   = exo.substring(0, corrIdx).trim();
        corr = exo.substring(corrIdx).trim();
      } else {
        ex = exo;
      }
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _GradBanner(
          grad: widget.grad,
          icon: Icons.edit_outlined,
          title: 'Exercices similaires',
          subtitle: 'Entraîne-toi avec des données différentes',
        ),
        const SizedBox(height: 16),
        Row(
          children: ['Facile', 'Intermédiaire', 'Avancé'].map((l) => Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(l, style: const TextStyle(fontSize: 12)),
              selected: l == _level,
              onSelected: widget.loading ? null : (_) {
                setState(() { _level = l; _showCorrection = false; _selfEvalDone = false; _selfEvalNiveau = null; });
                widget.onLevelChange(l);
                widget.onGenerate();
              },
              selectedColor: widget.grad.first,
              labelStyle: TextStyle(color: l == _level ? Colors.white : Colors.white54),
            ),
          )).toList(),
        ),
        const SizedBox(height: 10),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: widget.grad.first,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(44),
          ),
          onPressed: widget.loading ? null : widget.onGenerate,
          icon: const Icon(Icons.refresh, size: 18),
          label: Text(exo == null ? 'Générer les exercices' : 'Nouveaux exercices ($_level)'),
        ),
        if (ex != null) ...[
          const SizedBox(height: 14),
          _TextCard(text: ex),
          if (corr != null) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => setState(() => _showCorrection = !_showCorrection),
              icon: Icon(_showCorrection ? Icons.visibility_off : Icons.visibility, size: 16),
              label: Text(_showCorrection ? 'Masquer la correction' : 'Voir la correction'),
              style: OutlinedButton.styleFrom(foregroundColor: Colors.white70),
            ),
            if (_showCorrection) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF0A1F0A),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF16A34A).withValues(alpha: 0.4)),
                ),
                child: Text(corr, style: const TextStyle(color: Colors.white, height: 1.6)),
              ),
              const SizedBox(height: 14),
              // ── Self-assessment ───────────────────────────────────────────
              if (_selfEvalSaving)
                const Center(child: Padding(
                  padding: EdgeInsets.all(8),
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white54),
                ))
              else if (_selfEvalDone)
                _MaitriseBadgeInline(
                  emoji  : _selfEvalNiveau == 'maitrise' ? '🟢' : _selfEvalNiveau == 'en_cours' ? '🟡' : '🔴',
                  label  : _selfEvalNiveau == 'maitrise' ? 'Maîtrisé — enregistré' : _selfEvalNiveau == 'en_cours' ? 'En cours — enregistré' : 'À retravailler — enregistré',
                  color  : _selfEvalNiveau == 'maitrise' ? const Color(0xFF16A34A) : _selfEvalNiveau == 'en_cours' ? const Color(0xFFD97706) : const Color(0xFFDC2626),
                )
              else ...[
                const Text('Comment tu t\'en es sorti ?',
                    style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Row(children: [
                  _SelfEvalBtn(emoji: '🟢', label: 'Facile',           onTap: () => _doSelfEval(90, 'maitrise')),
                  const SizedBox(width: 8),
                  _SelfEvalBtn(emoji: '🟡', label: 'Quelques doutes',  onTap: () => _doSelfEval(60, 'en_cours')),
                  const SizedBox(width: 8),
                  _SelfEvalBtn(emoji: '🔴', label: 'Difficile',        onTap: () => _doSelfEval(30, 'a_retravailler')),
                ]),
              ],
            ],
          ],
        ] else if (!widget.loading) ...[
          const SizedBox(height: 20),
          _InfoBox(
            icon: Icons.lightbulb_outline,
            color: Colors.amber,
            text: 'Ces exercices portent sur les MÊMES NOTIONS que ton devoir — avec des données différentes.',
          ),
        ],
        const SizedBox(height: 8),
        _InfoBox(
          icon: Icons.block,
          color: Colors.orange,
          text: 'Ces exercices d\'entraînement ne contiennent PAS les réponses de ton devoir.',
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Tab 4 — Quiz interactif
// ═══════════════════════════════════════════════════════════════════════════════

class _QuizTab extends StatefulWidget {
  final List<Map<String, dynamic>>? quiz;
  final bool loading;
  final List<Color> grad;
  final VoidCallback onLoad;
  final String matiere, categorie, sourceType, sourceTitre;
  const _QuizTab({
    required this.quiz,
    required this.loading,
    required this.grad,
    required this.onLoad,
    required this.matiere,
    required this.categorie,
    required this.sourceType,
    required this.sourceTitre,
  });
  @override
  State<_QuizTab> createState() => _QuizTabState();
}

class _QuizTabState extends State<_QuizTab> {
  int _qi = 0;
  int? _selected;
  bool _answered = false;
  int _correct = 0;
  bool _done = false;
  bool _showExplication = false;

  // Suivi pédagogique
  final List<bool> _resultats    = [];
  List<Map<String, dynamic>>? _evaluation;
  bool _evaluating = false;

  void _restart() => setState(() {
    _qi = 0; _selected = null; _answered = false;
    _correct = 0; _done = false; _showExplication = false;
    _resultats.clear(); _evaluation = null; _evaluating = false;
  });

  Future<void> _triggerEvaluation(List<Map<String, dynamic>> quiz) async {
    if (_evaluating || _evaluation != null) return;
    setState(() => _evaluating = true);
    try {
      final notions = await AiRevisionService.evaluerNotions(
        matiere      : widget.matiere,
        categorie    : widget.categorie,
        questions    : quiz,
        resultatEleve: List.from(_resultats),
      );
      if (notions.isNotEmpty) {
        await MaitriseService.enregistrer(
          notions     : notions,
          matiere     : widget.matiere,
          categorie   : widget.categorie,
          sourceType  : widget.sourceType,
          sourceTitre : widget.sourceTitre,
        );
      }
      if (mounted) setState(() { _evaluation = notions; _evaluating = false; });
    } catch (e) {
      if (mounted) setState(() => _evaluating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.loading) return const _LoadingView(msg: 'Génération du quiz…');

    final quiz = widget.quiz;
    if (quiz == null) {
      return _EmptyView(
        icon: Icons.quiz_outlined,
        msg: 'Quiz non encore généré',
        btnLabel: 'Générer le quiz',
        onTap: widget.onLoad,
        grad: widget.grad,
      );
    }

    if (_done) return _buildResult(quiz);

    final q       = quiz[_qi];
    final choices = List<String>.from(q['choices'] as List? ?? []);
    final answer  = q['answer'] as int? ?? 0;
    final explic  = q['explication'] as String? ?? '';

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LinearProgressIndicator(
            value: (_qi + 1) / quiz.length,
            backgroundColor: Colors.white12,
            color: widget.grad.first,
            minHeight: 5,
          ),
          const SizedBox(height: 8),
          Text('Question ${_qi + 1} / ${quiz.length} · $_correct correcte(s)',
              style: const TextStyle(color: Colors.white38, fontSize: 11)),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF161B22),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Text(q['q'] as String? ?? '',
                style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(height: 14),
          ...choices.asMap().entries.map((e) {
            Color bg = const Color(0xFF161B22);
            Color border = Colors.white.withValues(alpha: 0.08);
            if (_answered) {
              if (e.key == answer)        { bg = const Color(0xFF0A1F0A); border = const Color(0xFF16A34A); }
              else if (e.key == _selected){ bg = const Color(0xFF1F0A0A); border = const Color(0xFFDC2626); }
            }
            return GestureDetector(
              onTap: () {
                if (_answered) return;
                final isCorrect = e.key == answer;
                setState(() {
                  _selected = e.key;
                  _answered = true;
                  if (isCorrect) _correct++;
                  _resultats.add(isCorrect);
                });
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                    color: bg, borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: border)),
                child: Row(
                  children: [
                    if (_answered && e.key == answer)
                      const Icon(Icons.check_circle, color: Color(0xFF16A34A), size: 18)
                    else if (_answered && e.key == _selected)
                      const Icon(Icons.cancel, color: Color(0xFFDC2626), size: 18)
                    else
                      const Icon(Icons.radio_button_unchecked, color: Colors.white38, size: 18),
                    const SizedBox(width: 10),
                    Expanded(child: Text(e.value, style: const TextStyle(color: Colors.white, fontSize: 14))),
                  ],
                ),
              ),
            );
          }),
          if (_answered && explic.isNotEmpty) ...[
            TextButton(
              onPressed: () => setState(() => _showExplication = !_showExplication),
              child: Text(_showExplication ? 'Masquer l\'explication' : 'Voir l\'explication',
                  style: const TextStyle(color: Colors.white54, fontSize: 12)),
            ),
            if (_showExplication)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF161B22),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                ),
                child: Text(explic, style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.5)),
              ),
          ],
          const Spacer(),
          if (_answered)
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.grad.first,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(44),
              ),
              onPressed: () {
                if (_qi < quiz.length - 1) {
                  setState(() { _qi++; _selected = null; _answered = false; _showExplication = false; });
                } else {
                  setState(() => _done = true);
                  _triggerEvaluation(quiz);
                }
              },
              child: Text(_qi < quiz.length - 1 ? 'Question suivante' : 'Voir les résultats'),
            ),
        ],
      ),
    );
  }

  Widget _buildResult(List<Map<String, dynamic>> quiz) {
    final pct   = quiz.isEmpty ? 0 : (_correct * 100 ~/ quiz.length);
    final color = pct >= 80 ? const Color(0xFF16A34A) : pct >= 50 ? const Color(0xFFD97706) : const Color(0xFFDC2626);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Score global
          Stack(alignment: Alignment.center, children: [
            SizedBox(
              width: 100, height: 100,
              child: CircularProgressIndicator(
                  value: pct / 100, color: color,
                  backgroundColor: Colors.white12, strokeWidth: 8),
            ),
            Text('$pct%', style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 16),
          Text('$_correct / ${quiz.length} bonnes réponses',
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(
            pct >= 80 ? '🎉 Excellent ! Tu maîtrises bien ces notions.'
                : pct >= 50 ? '👍 Bien ! Revois les points manqués dans l\'onglet Cours.'
                : '💪 Continue — relis le cours et réessaie.',
            style: const TextStyle(color: Colors.white70, fontSize: 13),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),

          // ── Bilan par notion ─────────────────────────────────────────────
          Align(
            alignment: Alignment.centerLeft,
            child: Text('BILAN PAR NOTION',
                style: const TextStyle(color: Colors.white38, fontSize: 11,
                    fontWeight: FontWeight.w600, letterSpacing: 1.2)),
          ),
          const SizedBox(height: 10),
          if (_evaluating)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                SizedBox(width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white38)),
                SizedBox(width: 12),
                Text('Analyse de ta maîtrise…', style: TextStyle(color: Colors.white38, fontSize: 12)),
              ]),
            )
          else if (_evaluation != null && _evaluation!.isNotEmpty)
            ..._evaluation!.map((n) {
              final s = (n['score'] as num?)?.toInt() ?? 0;
              final emoji = s >= 75 ? '🟢' : s >= 45 ? '🟡' : '🔴';
              final lvl   = s >= 75 ? 'Maîtrisé' : s >= 45 ? 'En cours' : 'À retravailler';
              final c     = s >= 75 ? const Color(0xFF16A34A) : s >= 45 ? const Color(0xFFD97706) : const Color(0xFFDC2626);
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: c.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: c.withValues(alpha: 0.25)),
                ),
                child: Row(children: [
                  Text(emoji, style: const TextStyle(fontSize: 16)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(n['label'] as String? ?? '', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                      Text(lvl, style: TextStyle(color: c, fontSize: 11)),
                    ]),
                  ),
                  Text('$s/100', style: TextStyle(color: c, fontSize: 13, fontWeight: FontWeight.bold)),
                ]),
              );
            })
          else
            const Text('Aucune donnée de suivi disponible.',
                style: TextStyle(color: Colors.white24, fontSize: 12)),

          const SizedBox(height: 20),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
                backgroundColor: widget.grad.first, foregroundColor: Colors.white),
            onPressed: _restart,
            icon: const Icon(Icons.replay, size: 18),
            label: const Text('Recommencer'),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Tab 5 — Aide IA à 4 niveaux
// ═══════════════════════════════════════════════════════════════════════════════

class _AideTab extends StatefulWidget {
  final DevoirModel devoir;
  final List<Color> grad;
  const _AideTab({required this.devoir, required this.grad});
  @override
  State<_AideTab> createState() => _AideTabState();
}

class _AideTabState extends State<_AideTab> {
  final _questionCtrl = TextEditingController();
  final _reponseCtrl  = TextEditingController();
  String? _response;
  bool _loading = false;
  int _activeLevel = 0;

  @override
  void dispose() {
    _questionCtrl.dispose();
    _reponseCtrl.dispose();
    super.dispose();
  }

  Future<void> _ask(int niveau) async {
    final q = _questionCtrl.text.trim();
    if (q.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Décris ta difficulté avant de demander de l\'aide.')),
      );
      return;
    }
    setState(() { _loading = true; _response = null; _activeLevel = niveau; });
    final r = await AiRevisionService.obtenirAide(
      devoir: widget.devoir,
      questionEleve: q,
      niveau: niveau,
      reponseEleve: niveau == 4 ? _reponseCtrl.text.trim() : null,
    );
    if (mounted) setState(() { _response = r; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    final grad = widget.grad;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _GradBanner(
          grad: grad,
          icon: Icons.support_agent_outlined,
          title: 'Professeur particulier IA',
          subtitle: '4 niveaux d\'aide — sans jamais donner la réponse',
        ),
        const SizedBox(height: 16),

        // Règle pédagogique
        _InfoBox(
          icon: Icons.shield_outlined,
          color: Colors.teal,
          text: 'L\'IA ne donnera JAMAIS la réponse finale du devoir. Elle aide à comprendre, pas à copier.',
        ),
        const SizedBox(height: 16),

        // Champ : ta difficulté
        const Text('Quelle est ta difficulté ?',
            style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        TextField(
          controller: _questionCtrl,
          style: const TextStyle(color: Colors.white),
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'Ex : "Je ne comprends pas comment calculer…" ou "Je bloque sur la question 2"',
            hintStyle: const TextStyle(color: Colors.white24, fontSize: 13),
            filled: true,
            fillColor: const Color(0xFF161B22),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.15))),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.15))),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: grad.first)),
          ),
        ),
        const SizedBox(height: 16),

        // Champ réponse (niveau 4 uniquement)
        const Text('Ma réponse proposée (pour la vérification)',
            style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextField(
          controller: _reponseCtrl,
          style: const TextStyle(color: Colors.white),
          maxLines: 2,
          decoration: InputDecoration(
            hintText: 'Écris ici ta réponse pour que l\'IA vérifie ton raisonnement…',
            hintStyle: const TextStyle(color: Colors.white24, fontSize: 12),
            filled: true,
            fillColor: const Color(0xFF161B22),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.15))),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.15))),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: grad.first)),
          ),
        ),
        const SizedBox(height: 16),

        // 4 boutons de niveau
        _SectionLabel('Choisis le niveau d\'aide :'),
        const SizedBox(height: 10),
        ...const [
          (1, '💡', 'Indice',         'Un petit coup de pouce pour t\'orienter'),
          (2, '📚', 'Notion du cours','Explication de la notion théorique'),
          (3, '🔍', 'Méthode',        'Les étapes à suivre pour ce type de problème'),
          (4, '✅', 'Vérifier',       'L\'IA vérifie ton raisonnement (écris ta réponse ci-dessus)'),
        ].map((t) => _NiveauBtn(
          niveau: t.$1,
          emoji: t.$2,
          label: t.$3,
          subtitle: t.$4,
          active: _activeLevel == t.$1 && _loading,
          grad: grad,
          onTap: _loading ? null : () => _ask(t.$1),
        )),

        // Réponse IA
        if (_loading) ...[
          const SizedBox(height: 20),
          const Center(
            child: Column(children: [
              CircularProgressIndicator(color: Color(0xFF2563EB)),
              SizedBox(height: 12),
              Text('Le professeur IA réfléchit…',
                  style: TextStyle(color: Colors.white54, fontSize: 13)),
            ]),
          ),
        ] else if (_response != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF161B22),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: grad.first.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(Icons.smart_toy_outlined, color: grad.first, size: 18),
                  const SizedBox(width: 8),
                  Text('Professeur IA',
                      style: TextStyle(color: grad.first, fontWeight: FontWeight.w600, fontSize: 13)),
                ]),
                const SizedBox(height: 10),
                Text(_response!, style: const TextStyle(color: Colors.white, height: 1.65, fontSize: 14)),
                const SizedBox(height: 12),
                Text('Niveau d\'aide $_activeLevel/4',
                    style: const TextStyle(color: Colors.white24, fontSize: 11)),
              ],
            ),
          ),
        ],
        const SizedBox(height: 32),
      ],
    );
  }
}

class _NiveauBtn extends StatelessWidget {
  final int niveau;
  final String emoji, label, subtitle;
  final bool active;
  final List<Color> grad;
  final VoidCallback? onTap;
  const _NiveauBtn({
    required this.niveau,
    required this.emoji,
    required this.label,
    required this.subtitle,
    required this.active,
    required this.grad,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: active ? grad.first.withValues(alpha: 0.15) : const Color(0xFF161B22),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: active ? grad.first : Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: Row(children: [
          Text(emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Niveau $niveau — $label',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
              const SizedBox(height: 2),
              Text(subtitle,
                  style: const TextStyle(color: Colors.white38, fontSize: 12)),
            ]),
          ),
          Icon(Icons.chevron_right, color: onTap == null ? Colors.white12 : Colors.white38),
        ]),
      ),
    );
  }
}

// ─── Widgets suivi pédagogique ────────────────────────────────────────────────

class _MaitriseBadgeInline extends StatelessWidget {
  final String emoji, label;
  final Color color;
  const _MaitriseBadgeInline({required this.emoji, required this.label, required this.color});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w600)),
        ]),
      );
}

class _SelfEvalBtn extends StatelessWidget {
  final String emoji, label;
  final VoidCallback onTap;
  const _SelfEvalBtn({required this.emoji, required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) => Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF161B22),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(emoji, style: const TextStyle(fontSize: 18)),
              const SizedBox(height: 4),
              Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11), textAlign: TextAlign.center),
            ]),
          ),
        ),
      );
}

// ═══════════════════════════════════════════════════════════════════════════════
// Widgets partagés
// ═══════════════════════════════════════════════════════════════════════════════

class _LoadingView extends StatelessWidget {
  final String msg;
  const _LoadingView({required this.msg});
  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const CircularProgressIndicator(color: Color(0xFF2563EB)),
          const SizedBox(height: 16),
          Text(msg, style: const TextStyle(color: Colors.white54, fontSize: 13)),
        ]),
      );
}

class _EmptyView extends StatelessWidget {
  final IconData icon;
  final String msg, btnLabel;
  final VoidCallback onTap;
  final List<Color> grad;
  const _EmptyView({
    required this.icon,
    required this.msg,
    required this.btnLabel,
    required this.onTap,
    required this.grad,
  });
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, color: Colors.white24, size: 48),
            const SizedBox(height: 16),
            Text(msg, style: const TextStyle(color: Colors.white54, fontSize: 14)),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: grad.first, foregroundColor: Colors.white),
              onPressed: onTap,
              child: Text(btnLabel),
            ),
          ]),
        ),
      );
}

class _GradBanner extends StatelessWidget {
  final List<Color> grad;
  final IconData icon;
  final String title, subtitle;
  const _GradBanner({
    required this.grad,
    required this.icon,
    required this.title,
    required this.subtitle,
  });
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: grad),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(children: [
          Icon(icon, color: Colors.white, size: 28),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title,
                  style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
              const SizedBox(height: 2),
              Text(subtitle,
                  style: const TextStyle(color: Colors.white70, fontSize: 12)),
            ]),
          ),
        ]),
      );
}

class _InfoCard extends StatelessWidget {
  final String label, value;
  const _InfoCard({required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF161B22),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
            width: 120,
            child: Text(label,
                style: const TextStyle(
                    color: Colors.white38, fontSize: 12, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(value,
                style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.5)),
          ),
        ]),
      );
}

class _TextCard extends StatelessWidget {
  final String text;
  const _TextCard({required this.text});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF161B22),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Text(text, style: const TextStyle(color: Colors.white, height: 1.65, fontSize: 13)),
      );
}

class _InfoBox extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;
  const _InfoBox({required this.icon, required this.color, required this.text});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: TextStyle(color: color.withValues(alpha: 0.9), fontSize: 12, height: 1.5)),
          ),
        ]),
      );
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(
          color: Colors.white38, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1.2));
}
