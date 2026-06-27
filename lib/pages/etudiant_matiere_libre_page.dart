import 'package:flutter/material.dart';

import '../services/ai_revision_service.dart';
import '../services/maitrise_service.dart';
import '../services/revision_firestore_service.dart';

// ─── Constantes ───────────────────────────────────────────────────────────────

const _kGradients = <String, List<Color>>{
  'Mathématiques'   : [Color(0xFF2563EB), Color(0xFF0891B2)],
  'Français'        : [Color(0xFF7C3AED), Color(0xFF6C47FF)],
  'Histoire-Géo'    : [Color(0xFFB45309), Color(0xFFD97706)],
  'SVT'             : [Color(0xFF15803D), Color(0xFF16A34A)],
  'Physique-Chimie' : [Color(0xFFDC2626), Color(0xFFEA580C)],
  'Anglais'         : [Color(0xFF0F766E), Color(0xFF0891B2)],
  'Espagnol'        : [Color(0xFFD97706), Color(0xFFCA8A04)],
  'Informatique'    : [Color(0xFF374151), Color(0xFF4B5563)],
  'Philosophie'     : [Color(0xFF6C47FF), Color(0xFF9333EA)],
  'Sciences'        : [Color(0xFF047857), Color(0xFF065F46)],
  'Économie'        : [Color(0xFF0891B2), Color(0xFF0E7490)],
  'Droit'           : [Color(0xFF1D4ED8), Color(0xFF1E40AF)],
  'Lettres'         : [Color(0xFF7C3AED), Color(0xFF6C47FF)],
};

List<Color> _grad(String m) =>
    _kGradients[m] ?? const [Color(0xFF6C47FF), Color(0xFF2563EB)];

const _kCategories = ['Maternelle', 'Primaire', 'Collège', 'Lycée', 'Université'];

// ═══════════════════════════════════════════════════════════════════════════════
// Page Matière Libre
// ═══════════════════════════════════════════════════════════════════════════════

class EtudiantMatiereLibrePage extends StatefulWidget {
  final String matiere;
  final String categorieInitiale;
  final String classeNom;

  const EtudiantMatiereLibrePage({
    super.key,
    required this.matiere,
    required this.categorieInitiale,
    this.classeNom = '',
  });

  @override
  State<EtudiantMatiereLibrePage> createState() => _EtudiantMatiereLibrePageState();
}

class _EtudiantMatiereLibrePageState extends State<EtudiantMatiereLibrePage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  late String _categorie;

  // Content per tab (reset when categorie changes)
  String? _cours;
  String? _fiche;
  List<Map<String, dynamic>>? _flashcards;
  String? _exercices;
  List<Map<String, dynamic>>? _quiz;
  bool _coursLoading       = false;
  bool _ficheLoading       = false;
  bool _flashcardsLoading  = false;
  bool _exoLoading         = false;
  bool _quizLoading        = false;
  String _exoNiveau        = 'Intermédiaire';
  bool   _isAdapted        = false;

  @override
  void initState() {
    super.initState();
    _categorie = widget.categorieInitiale.isNotEmpty
        ? widget.categorieInitiale
        : 'Collège';
    _tabs = TabController(length: 6, vsync: this);
    _tabs.addListener(_onTabChange);
    _loadCours();
    _checkAdaptation();
  }

  Future<void> _checkAdaptation() async {
    final ctx = await MaitriseService.contexteAdaptatif(widget.matiere);
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
      case 0: _loadCours();
      case 1: _loadFiche();
      case 2: _loadFlashcards();
      case 3: break; // exercices: on demand
      case 4: _loadQuiz();
      case 5: break; // aide: on demand
    }
  }

  void _changeCategorie(String newCat) {
    if (newCat == _categorie) return;
    setState(() {
      _categorie          = newCat;
      _cours              = null;
      _fiche              = null;
      _flashcards         = null;
      _exercices          = null;
      _quiz               = null;
      _coursLoading       = false;
      _ficheLoading       = false;
      _flashcardsLoading  = false;
      _exoLoading         = false;
      _quizLoading        = false;
      _isAdapted          = false;
    });
    _checkAdaptation();
    switch (_tabs.index) {
      case 0: _loadCours();
      case 2: _loadQuiz();
    }
  }

  Future<void> _loadCours() async {
    if (_cours != null || _coursLoading) return;
    setState(() => _coursLoading = true);
    final r = await AiRevisionService.genererCoursLibre(
      matiere: widget.matiere,
      categorie: _categorie,
      classeNom: widget.classeNom,
    );
    if (mounted) setState(() { _cours = r; _coursLoading = false; });
    if (r.isNotEmpty && !r.startsWith('❌') && !r.startsWith('⚠️')) {
      RevisionFirestoreService.saveSession(
        matiere: widget.matiere, categorie: _categorie, type: 'cours');
    }
  }

  Future<void> _loadFiche() async {
    if (_fiche != null || _ficheLoading) return;
    setState(() => _ficheLoading = true);
    final r = await AiRevisionService.genererFicheRevision(
      matiere: widget.matiere,
      categorie: _categorie,
      classeNom: widget.classeNom,
    );
    if (mounted) setState(() { _fiche = r; _ficheLoading = false; });
    if (r.isNotEmpty && !r.startsWith('❌') && !r.startsWith('⚠️')) {
      RevisionFirestoreService.saveSession(
        matiere: widget.matiere, categorie: _categorie, type: 'fiche');
    }
  }

  Future<void> _loadFlashcards() async {
    if (_flashcards != null || _flashcardsLoading) return;
    setState(() => _flashcardsLoading = true);
    final r = await AiRevisionService.genererFlashcardsLibres(
      matiere: widget.matiere,
      categorie: _categorie,
    );
    if (mounted) setState(() { _flashcards = r; _flashcardsLoading = false; });
    if (r.isNotEmpty) {
      RevisionFirestoreService.saveSession(
        matiere: widget.matiere, categorie: _categorie, type: 'flashcards',
        nbCards: r.length);
    }
  }

  Future<void> _loadExercices() async {
    if (_exoLoading) return;
    setState(() { _exoLoading = true; _exercices = null; });
    final r = await AiRevisionService.genererExercicesLibres(
      matiere: widget.matiere,
      categorie: _categorie,
      difficulte: _exoNiveau,
    );
    if (mounted) setState(() { _exercices = r; _exoLoading = false; });
  }

  Future<void> _loadQuiz() async {
    if (_quiz != null || _quizLoading) return;
    setState(() => _quizLoading = true);
    final r = await AiRevisionService.genererQuizLibre(
      matiere: widget.matiere,
      categorie: _categorie,
    );
    if (mounted) setState(() { _quiz = r; _quizLoading = false; });
  }

  @override
  Widget build(BuildContext context) {
    final g = _grad(widget.matiere);
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.matiere,
                style: const TextStyle(
                    color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            Row(children: [
              Text('Révision libre · $_categorie',
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
          // Level picker
          PopupMenuButton<String>(
            icon: const Icon(Icons.tune, color: Colors.white70),
            tooltip: 'Changer le niveau',
            color: const Color(0xFF1C2128),
            onSelected: _changeCategorie,
            itemBuilder: (_) => _kCategories
                .map((c) => PopupMenuItem<String>(
                      value: c,
                      child: Row(children: [
                        if (c == _categorie)
                          const Icon(Icons.check, color: Color(0xFF0F766E), size: 16)
                        else
                          const SizedBox(width: 16),
                        const SizedBox(width: 8),
                        Text(c, style: const TextStyle(color: Colors.white)),
                      ]),
                    ))
                .toList(),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white54),
            tooltip: 'Régénérer le contenu',
            onPressed: () async {
              await AiRevisionService.clearCacheLibre(widget.matiere, _categorie);
              if (mounted) {
                setState(() { _cours = null; _exercices = null; _quiz = null; _isAdapted = false; });
                _loadCours();
                _checkAdaptation();
              }
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          indicatorColor: g.first,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white38,
          tabs: const [
            Tab(text: '📚 Cours'),
            Tab(text: '📋 Fiche'),
            Tab(text: '🃏 Flashcards'),
            Tab(text: '✏️ Exercices'),
            Tab(text: '❓ Quiz'),
            Tab(text: '💬 Aide IA'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _LibreCoursTab(
            cours: _cours,
            loading: _coursLoading,
            matiere: widget.matiere,
            categorie: _categorie,
            grad: g,
            onLoad: _loadCours,
          ),
          _LibreFicheTab(
            fiche: _fiche,
            loading: _ficheLoading,
            matiere: widget.matiere,
            categorie: _categorie,
            grad: g,
            onLoad: _loadFiche,
          ),
          _LibreFlashcardsTab(
            flashcards: _flashcards,
            loading: _flashcardsLoading,
            matiere: widget.matiere,
            categorie: _categorie,
            grad: g,
            onLoad: _loadFlashcards,
          ),
          _LibreExercicesTab(
            exercices: _exercices,
            loading: _exoLoading,
            niveau: _exoNiveau,
            grad: g,
            onLevelChange: (l) { _exoNiveau = l; _exercices = null; },
            onGenerate: _loadExercices,
            matiere: widget.matiere,
            categorie: _categorie,
          ),
          _LibreQuizTab(
            quiz: _quiz,
            loading: _quizLoading,
            grad: g,
            matiere: widget.matiere,
            categorie: _categorie,
            onLoad: _loadQuiz,
          ),
          _LibreAideTab(
            matiere: widget.matiere,
            categorie: _categorie,
            grad: g,
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Tab 2 — Fiche de révision
// ═══════════════════════════════════════════════════════════════════════════════

class _LibreFicheTab extends StatelessWidget {
  final String? fiche;
  final bool loading;
  final String matiere, categorie;
  final List<Color> grad;
  final VoidCallback onLoad;
  const _LibreFicheTab({
    required this.fiche, required this.loading,
    required this.matiere, required this.categorie,
    required this.grad, required this.onLoad,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) return const _LoadingView(msg: 'Génération de la fiche…');
    if (fiche == null) {
      return _EmptyView(
        icon: Icons.article_outlined,
        msg: 'Fiche non encore générée',
        btnLabel: 'Générer la fiche',
        grad: grad, onTap: onLoad,
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _GradBanner(
          grad: grad,
          icon: Icons.article_outlined,
          title: 'Fiche de révision — $matiere',
          subtitle: '$categorie · Synthèse structurée',
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF161B22),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: grad.first.withValues(alpha: 0.2)),
          ),
          child: Text(fiche!,
              style: const TextStyle(color: Colors.white, height: 1.7, fontSize: 13)),
        ),
        const SizedBox(height: 12),
        _InfoBox(
          icon: Icons.tips_and_updates_outlined,
          color: Colors.amber,
          text: 'Utilise cette fiche pour une révision rapide avant un devoir ou un examen.',
        ),
        const SizedBox(height: 24),

        // BAC prep for Lycée
        if (categorie == 'Lycée') ...[
          const Divider(color: Colors.white12),
          const SizedBox(height: 12),
          Text('BAC — Sujet type'.toUpperCase(),
              style: const TextStyle(
                  color: Colors.white38, fontSize: 11,
                  fontWeight: FontWeight.w700, letterSpacing: 1.2)),
          const SizedBox(height: 10),
          _BacSujetSection(matiere: matiere, grad: grad),
        ],

        // Grand Oral for Terminale Lycée
        if (categorie == 'Lycée') ...[
          const SizedBox(height: 16),
          Text('Grand Oral'.toUpperCase(),
              style: const TextStyle(
                  color: Colors.white38, fontSize: 11,
                  fontWeight: FontWeight.w700, letterSpacing: 1.2)),
          const SizedBox(height: 10),
          _GrandOralSection(specialite: matiere, grad: grad),
        ],

        // Partiel prep for Université
        if (categorie == 'Université') ...[
          const Divider(color: Colors.white12),
          const SizedBox(height: 12),
          Text('Préparation Partiel'.toUpperCase(),
              style: const TextStyle(
                  color: Colors.white38, fontSize: 11,
                  fontWeight: FontWeight.w700, letterSpacing: 1.2)),
          const SizedBox(height: 10),
          _PartielSection(ue: matiere, grad: grad),
        ],
      ],
    );
  }
}

// ── Sujet BAC section ─────────────────────────────────────────────────────────

class _BacSujetSection extends StatefulWidget {
  final String matiere;
  final List<Color> grad;
  const _BacSujetSection({required this.matiere, required this.grad});
  @override
  State<_BacSujetSection> createState() => _BacSujetSectionState();
}

class _BacSujetSectionState extends State<_BacSujetSection> {
  String? _sujet;
  bool _loading = false;

  Future<void> _generate() async {
    setState(() { _loading = true; _sujet = null; });
    final r = await AiRevisionService.genererSujetBac(matiere: widget.matiere);
    if (mounted) setState(() { _sujet = r; _loading = false; });
    if (r.isNotEmpty && !r.startsWith('❌')) {
      RevisionFirestoreService.saveSession(
        matiere: widget.matiere, categorie: 'Lycée', type: 'bac');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: widget.grad.first,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(44),
          ),
          onPressed: _loading ? null : _generate,
          icon: const Icon(Icons.school_outlined, size: 18),
          label: Text(_sujet == null ? 'Générer un sujet type BAC' : 'Nouveau sujet BAC'),
        ),
        if (_loading) const Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: _LoadingView(msg: 'Génération du sujet BAC…'),
        ),
        if (_sujet != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1040),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF6C47FF).withValues(alpha: 0.3)),
            ),
            child: Text(_sujet!,
                style: const TextStyle(color: Colors.white, height: 1.65, fontSize: 13)),
          ),
        ],
      ],
    );
  }
}

// ── Grand Oral section ────────────────────────────────────────────────────────

class _GrandOralSection extends StatefulWidget {
  final String specialite;
  final List<Color> grad;
  const _GrandOralSection({required this.specialite, required this.grad});
  @override
  State<_GrandOralSection> createState() => _GrandOralSectionState();
}

class _GrandOralSectionState extends State<_GrandOralSection> {
  String? _content;
  bool _loading = false;

  Future<void> _generate() async {
    setState(() { _loading = true; _content = null; });
    final r = await AiRevisionService.preparationGrandOral(
        specialite: widget.specialite);
    if (mounted) setState(() { _content = r; _loading = false; });
    if (r.isNotEmpty && !r.startsWith('❌')) {
      RevisionFirestoreService.saveSession(
        matiere: widget.specialite, categorie: 'Lycée', type: 'grand_oral');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF6C47FF),
            side: const BorderSide(color: Color(0xFF6C47FF)),
            minimumSize: const Size.fromHeight(44),
          ),
          onPressed: _loading ? null : _generate,
          icon: const Icon(Icons.record_voice_over_outlined, size: 18),
          label: const Text('Préparer le Grand Oral'),
        ),
        if (_loading) const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: _LoadingView(msg: 'Préparation Grand Oral…'),
        ),
        if (_content != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF0D1117),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF6C47FF).withValues(alpha: 0.25)),
            ),
            child: Text(_content!,
                style: const TextStyle(color: Colors.white, height: 1.65, fontSize: 13)),
          ),
        ],
      ],
    );
  }
}

// ── Partiel section (Université) ──────────────────────────────────────────────

class _PartielSection extends StatefulWidget {
  final String ue;
  final List<Color> grad;
  const _PartielSection({required this.ue, required this.grad});
  @override
  State<_PartielSection> createState() => _PartielSectionState();
}

class _PartielSectionState extends State<_PartielSection> {
  String? _content;
  bool _loading = false;

  Future<void> _generate() async {
    setState(() { _loading = true; _content = null; });
    final r = await AiRevisionService.preparerPartiel(ue: widget.ue, niveau: 'Université');
    if (mounted) setState(() { _content = r; _loading = false; });
    if (r.isNotEmpty && !r.startsWith('❌')) {
      RevisionFirestoreService.saveSession(
        matiere: widget.ue, categorie: 'Université', type: 'partiel');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: widget.grad.first,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(44),
          ),
          onPressed: _loading ? null : _generate,
          icon: const Icon(Icons.school_outlined, size: 18),
          label: const Text('Préparer le partiel'),
        ),
        if (_loading) const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: _LoadingView(msg: 'Préparation partiel…'),
        ),
        if (_content != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF161B22),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: widget.grad.first.withValues(alpha: 0.25)),
            ),
            child: Text(_content!,
                style: const TextStyle(color: Colors.white, height: 1.65, fontSize: 13)),
          ),
        ],
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Tab 3 — Flashcards interactives
// ═══════════════════════════════════════════════════════════════════════════════

class _LibreFlashcardsTab extends StatefulWidget {
  final List<Map<String, dynamic>>? flashcards;
  final bool loading;
  final String matiere, categorie;
  final List<Color> grad;
  final VoidCallback onLoad;
  const _LibreFlashcardsTab({
    required this.flashcards, required this.loading,
    required this.matiere, required this.categorie,
    required this.grad, required this.onLoad,
  });
  @override
  State<_LibreFlashcardsTab> createState() => _LibreFlashcardsTabState();
}

class _LibreFlashcardsTabState extends State<_LibreFlashcardsTab> {
  int _index = 0;
  bool _flipped = false;
  final Map<int, bool?> _known = {}; // true=known, false=to_review

  void _flip() => setState(() => _flipped = !_flipped);

  void _mark(bool known) {
    setState(() {
      _known[_index] = known;
      if (_index < (widget.flashcards?.length ?? 1) - 1) {
        _index++;
        _flipped = false;
      }
    });
  }

  void _restart() => setState(() { _index = 0; _flipped = false; _known.clear(); });

  @override
  Widget build(BuildContext context) {
    if (widget.loading) return const _LoadingView(msg: 'Génération des flashcards…');
    final cards = widget.flashcards;
    if (cards == null || cards.isEmpty) {
      return _EmptyView(
        icon: Icons.style_outlined,
        msg: 'Flashcards non encore générées',
        btnLabel: 'Générer les flashcards',
        grad: widget.grad, onTap: widget.onLoad,
      );
    }

    final done = _index >= cards.length;
    if (done) return _buildSummary(cards);

    final card  = cards[_index];
    final front = card['front'] as String? ?? '';
    final back  = card['back']  as String? ?? '';
    final theme = card['theme'] as String? ?? '';

    final knownCount  = _known.values.where((v) => v == true).length;
    final reviewCount = _known.values.where((v) => v == false).length;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Progress
          LinearProgressIndicator(
            value: _index / cards.length,
            backgroundColor: Colors.white12,
            color: widget.grad.first,
            minHeight: 4,
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${_index + 1} / ${cards.length}',
                  style: const TextStyle(color: Colors.white38, fontSize: 11)),
              Row(children: [
                const Text('🟢 ', style: TextStyle(fontSize: 12)),
                Text('$knownCount', style: const TextStyle(color: Color(0xFF16A34A), fontSize: 11)),
                const SizedBox(width: 10),
                const Text('🔴 ', style: TextStyle(fontSize: 12)),
                Text('$reviewCount', style: const TextStyle(color: Color(0xFFDC2626), fontSize: 11)),
              ]),
            ],
          ),
          const SizedBox(height: 14),

          // Card
          Expanded(
            child: GestureDetector(
              onTap: _flip,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: _flipped
                        ? [const Color(0xFF0D1F0D), const Color(0xFF0A1A1A)]
                        : [widget.grad.first.withValues(alpha: 0.15), const Color(0xFF161B22)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _flipped
                        ? const Color(0xFF16A34A).withValues(alpha: 0.4)
                        : widget.grad.first.withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (theme.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: widget.grad.first.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(theme,
                            style: TextStyle(
                                color: widget.grad.first, fontSize: 11,
                                fontWeight: FontWeight.w600)),
                      ),
                    Icon(
                      _flipped ? Icons.lightbulb_outlined : Icons.quiz_outlined,
                      color: _flipped ? const Color(0xFF16A34A) : widget.grad.first,
                      size: 28,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      _flipped ? back : front,
                      style: TextStyle(
                        color: _flipped ? const Color(0xFFBBF7D0) : Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      _flipped ? 'Réponse' : 'Appuie pour voir la réponse',
                      style: TextStyle(
                        color: (_flipped ? const Color(0xFF16A34A) : Colors.white38)
                            .withValues(alpha: 0.7),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Action buttons
          const SizedBox(height: 16),
          if (_flipped) ...[
            Row(children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0A2A0A),
                    foregroundColor: const Color(0xFF16A34A),
                    side: const BorderSide(color: Color(0xFF16A34A)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () => _mark(true),
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text('Je sais', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2A0A0A),
                    foregroundColor: const Color(0xFFDC2626),
                    side: const BorderSide(color: Color(0xFFDC2626)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () => _mark(false),
                  icon: const Icon(Icons.replay, size: 18),
                  label: const Text('À revoir', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ]),
          ] else ...[
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.grad.first,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(44),
              ),
              onPressed: _flip,
              icon: const Icon(Icons.flip, size: 18),
              label: const Text('Retourner la carte'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSummary(List<Map<String, dynamic>> cards) {
    final known  = _known.values.where((v) => v == true).length;
    final review = _known.values.where((v) => v == false).length;
    final pct    = cards.isEmpty ? 0 : (known * 100 ~/ cards.length);
    final color  = pct >= 75 ? const Color(0xFF16A34A)
        : pct >= 50 ? const Color(0xFFD97706)
        : const Color(0xFFDC2626);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Stack(alignment: Alignment.center, children: [
            SizedBox(
              width: 100, height: 100,
              child: CircularProgressIndicator(
                value: pct / 100, color: color,
                backgroundColor: Colors.white12, strokeWidth: 8),
            ),
            Text('$pct%', style: TextStyle(
                color: color, fontSize: 22, fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 16),
          Text('$known / ${cards.length} cartes mémorisées',
              style: const TextStyle(
                  color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(
            pct >= 75 ? '🎉 Excellent ! Tu maîtrises bien ces notions.'
                : pct >= 50 ? '👍 Bien ! Revois les cartes rouges.'
                : '💪 Continue — reprends les cartes rouges et recommence.',
            style: const TextStyle(color: Colors.white70, fontSize: 13),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            _StatBadge(emoji: '🟢', label: 'Mémorisé', value: known.toString(),
                color: const Color(0xFF16A34A)),
            const SizedBox(width: 16),
            _StatBadge(emoji: '🔴', label: 'À revoir', value: review.toString(),
                color: const Color(0xFFDC2626)),
          ]),
          const SizedBox(height: 28),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.grad.first,
              foregroundColor: Colors.white,
              minimumSize: const Size(200, 44),
            ),
            onPressed: _restart,
            icon: const Icon(Icons.replay, size: 18),
            label: const Text('Recommencer'),
          ),
          const SizedBox(height: 12),
          if (review > 0)
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFDC2626),
                side: const BorderSide(color: Color(0xFFDC2626)),
                minimumSize: const Size(200, 44),
              ),
              onPressed: () {
                final toReview = _known.entries
                    .where((e) => e.value == false)
                    .map((e) => e.key)
                    .toList();
                if (toReview.isNotEmpty) {
                  setState(() {
                    _index = toReview.first;
                    _flipped = false;
                    _known.clear();
                  });
                }
              },
              icon: const Icon(Icons.replay, size: 18),
              label: Text('Retravailler les $review cartes à revoir'),
            ),
        ],
      ),
    );
  }
}

class _StatBadge extends StatelessWidget {
  final String emoji, label, value;
  final Color color;
  const _StatBadge({required this.emoji, required this.label, required this.value, required this.color});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: color.withValues(alpha: 0.3)),
    ),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Text(emoji, style: const TextStyle(fontSize: 20)),
      const SizedBox(height: 4),
      Text(value, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold)),
      Text(label, style: TextStyle(color: color.withValues(alpha: 0.7), fontSize: 11)),
    ]),
  );
}

// ═══════════════════════════════════════════════════════════════════════════════
// Tab 1 — Cours
// ═══════════════════════════════════════════════════════════════════════════════

class _LibreCoursTab extends StatelessWidget {
  final String? cours;
  final bool loading;
  final String matiere, categorie;
  final List<Color> grad;
  final VoidCallback onLoad;
  const _LibreCoursTab({
    required this.cours, required this.loading,
    required this.matiere, required this.categorie,
    required this.grad, required this.onLoad,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) return const _LoadingView(msg: 'Génération du cours…');
    if (cours == null) {
      return _EmptyView(
        icon: Icons.menu_book_outlined,
        msg: 'Cours non encore généré',
        btnLabel: 'Générer le cours',
        grad: grad, onTap: onLoad,
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _GradBanner(
          grad: grad,
          icon: Icons.menu_book_outlined,
          title: '$matiere — $categorie',
          subtitle: 'Programme et notions fondamentales',
        ),
        const SizedBox(height: 16),
        _TextCard(text: cours!),
        const SizedBox(height: 12),
        _InfoBox(
          icon: Icons.lightbulb_outline,
          color: Colors.amber,
          text: 'Ce cours est adapté au niveau $categorie. Utilise l\'onglet Exercices pour t\'entraîner.',
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Tab 2 — Exercices
// ═══════════════════════════════════════════════════════════════════════════════

class _LibreExercicesTab extends StatefulWidget {
  final String? exercices;
  final bool loading;
  final String niveau;
  final List<Color> grad;
  final void Function(String) onLevelChange;
  final VoidCallback onGenerate;
  final String matiere, categorie;
  const _LibreExercicesTab({
    required this.exercices, required this.loading,
    required this.niveau, required this.grad,
    required this.onLevelChange, required this.onGenerate,
    required this.matiere, required this.categorie,
  });
  @override
  State<_LibreExercicesTab> createState() => _LibreExercicesTabState();
}

class _LibreExercicesTabState extends State<_LibreExercicesTab> {
  bool _showCorrection = false;
  late String _level;
  bool _selfEvalDone   = false;
  bool _selfEvalSaving = false;
  String? _selfEvalNiveau;

  @override
  void initState() { super.initState(); _level = widget.niveau; }

  @override
  void didUpdateWidget(_LibreExercicesTab old) {
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
    final slug  = widget.matiere.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_');
    final label = '${widget.matiere} — exercices $_level';
    final err   = score < 50 ? ['Difficultés sur les exercices de niveau $_level'] : <String>[];
    await MaitriseService.enregistrer(
      notions     : [{'id': '${slug}_exo_libre', 'label': label, 'score': score, 'erreurs': err}],
      matiere     : widget.matiere,
      categorie   : widget.categorie,
      sourceType  : 'exercice_libre',
      sourceTitre : 'Révision libre — ${widget.matiere}',
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
          title: 'Exercices d\'entraînement',
          subtitle: '${widget.matiere} · ${widget.categorie} — corrections complètes',
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
              label: Text(_showCorrection ? 'Masquer la correction' : 'Voir la correction complète'),
              style: OutlinedButton.styleFrom(foregroundColor: Colors.white70),
            ),
            if (_showCorrection) ...[
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF0A1F0A),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF16A34A).withValues(alpha: 0.4)),
                ),
                child: Text(corr, style: const TextStyle(color: Colors.white, height: 1.65)),
              ),
              const SizedBox(height: 14),
              if (_selfEvalSaving)
                const Center(child: Padding(
                  padding: EdgeInsets.all(8),
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white54),
                ))
              else if (_selfEvalDone)
                _SelfEvalBadge(niveau: _selfEvalNiveau)
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
        ],
        const SizedBox(height: 8),
        _InfoBox(
          icon: Icons.check_circle_outline,
          color: Colors.green,
          text: 'Mode révision libre : les corrections complètes sont disponibles pour apprendre à partir de tes erreurs.',
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Tab 3 — Quiz
// ═══════════════════════════════════════════════════════════════════════════════

class _LibreQuizTab extends StatefulWidget {
  final List<Map<String, dynamic>>? quiz;
  final bool loading;
  final List<Color> grad;
  final String matiere, categorie;
  final VoidCallback onLoad;
  const _LibreQuizTab({
    required this.quiz, required this.loading,
    required this.grad, required this.matiere,
    required this.categorie, required this.onLoad,
  });
  @override
  State<_LibreQuizTab> createState() => _LibreQuizTabState();
}

class _LibreQuizTabState extends State<_LibreQuizTab> {
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
          sourceType  : 'quiz_libre',
          sourceTitre : 'Révision libre — ${widget.matiere}',
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
        grad: widget.grad, onTap: widget.onLoad,
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
                style: const TextStyle(
                    color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
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
                child: Row(children: [
                  if (_answered && e.key == answer)
                    const Icon(Icons.check_circle, color: Color(0xFF16A34A), size: 18)
                  else if (_answered && e.key == _selected)
                    const Icon(Icons.cancel, color: Color(0xFFDC2626), size: 18)
                  else
                    const Icon(Icons.radio_button_unchecked, color: Colors.white38, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                      child: Text(e.value,
                          style: const TextStyle(color: Colors.white, fontSize: 14))),
                ]),
              ),
            );
          }),
          if (_answered && explic.isNotEmpty) ...[
            TextButton(
              onPressed: () => setState(() => _showExplication = !_showExplication),
              child: Text(_showExplication ? 'Masquer' : 'Voir l\'explication',
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
                child: Text(explic,
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 13, height: 1.5)),
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
                  setState(() {
                    _qi++; _selected = null;
                    _answered = false; _showExplication = false;
                  });
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
      child: Column(children: [
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
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(n['label'] as String? ?? '', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                  Text(lvl, style: TextStyle(color: c, fontSize: 11)),
                ])),
                Text('$s/100', style: TextStyle(color: c, fontSize: 13, fontWeight: FontWeight.bold)),
              ]),
            );
          }),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
              backgroundColor: widget.grad.first, foregroundColor: Colors.white),
          onPressed: _restart,
          icon: const Icon(Icons.replay, size: 18),
          label: const Text('Recommencer'),
        ),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Tab 4 — Aide IA à 4 niveaux (mode libre)
// ═══════════════════════════════════════════════════════════════════════════════

class _LibreAideTab extends StatefulWidget {
  final String matiere, categorie;
  final List<Color> grad;
  const _LibreAideTab({
    required this.matiere, required this.categorie, required this.grad,
  });
  @override
  State<_LibreAideTab> createState() => _LibreAideTabState();
}

class _LibreAideTabState extends State<_LibreAideTab> {
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
        const SnackBar(content: Text('Décris ta question ou ta difficulté.')),
      );
      return;
    }
    setState(() { _loading = true; _response = null; _activeLevel = niveau; });
    final r = await AiRevisionService.obtenirAideLibre(
      matiere      : widget.matiere,
      categorie    : widget.categorie,
      questionEleve: q,
      niveau       : niveau,
      reponseEleve : niveau == 4 ? _reponseCtrl.text.trim() : null,
    );
    if (mounted) setState(() { _response = r; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.grad;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _GradBanner(
          grad: g,
          icon: Icons.support_agent_outlined,
          title: 'Professeur particulier IA',
          subtitle: '${widget.matiere} · ${widget.categorie}',
        ),
        const SizedBox(height: 12),

        // Différence mode libre / mode devoir
        _InfoBox(
          icon: Icons.check_circle_outline,
          color: Colors.green,
          text: 'Mode révision libre : l\'IA peut expliquer en détail et donner des corrections complètes — tu peux apprendre sans restriction.',
        ),
        const SizedBox(height: 16),

        // Question
        _FieldLabel('Ta question ou difficulté :'),
        const SizedBox(height: 8),
        TextField(
          controller: _questionCtrl,
          style: const TextStyle(color: Colors.white),
          maxLines: 3,
          decoration: _inputDecoration(
            hint: 'Ex : "Comment factoriser un trinôme ?" ou "Je ne comprends pas la conjugaison du subjonctif"',
            accentColor: g.first,
          ),
        ),
        const SizedBox(height: 16),

        _FieldLabel('Ma réponse proposée (pour la vérification — niveau 4) :'),
        const SizedBox(height: 8),
        TextField(
          controller: _reponseCtrl,
          style: const TextStyle(color: Colors.white),
          maxLines: 2,
          decoration: _inputDecoration(
            hint: 'Écris ici ta réponse à un exercice pour que l\'IA la corrige…',
            accentColor: g.first,
          ),
        ),
        const SizedBox(height: 16),

        _FieldLabel('NIVEAU D\'AIDE :'),
        const SizedBox(height: 10),

        ...const [
          (1, '💡', 'Indice',              'Un petit coup de pouce pour orienter ta réflexion'),
          (2, '📚', 'Explication de notion','Définition + exemple complet + contre-exemple'),
          (3, '🔍', 'Méthode pas à pas',    'Démarche complète pour ce type de problème'),
          (4, '✅', 'Corriger ma réponse',  'L\'IA corrige entièrement ta réponse (mode libre)'),
        ].map((t) => _NiveauBtn(
          niveau: t.$1, emoji: t.$2, label: t.$3, subtitle: t.$4,
          active: _activeLevel == t.$1 && _loading,
          grad: g,
          onTap: _loading ? null : () => _ask(t.$1),
        )),

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
              border: Border.all(color: g.first.withValues(alpha: 0.3)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(Icons.smart_toy_outlined, color: g.first, size: 18),
                const SizedBox(width: 8),
                Text('Professeur IA',
                    style: TextStyle(
                        color: g.first, fontWeight: FontWeight.w600, fontSize: 13)),
                const Spacer(),
                Text('Niveau $_activeLevel/4',
                    style: const TextStyle(color: Colors.white24, fontSize: 11)),
              ]),
              const SizedBox(height: 10),
              Text(_response!,
                  style: const TextStyle(
                      color: Colors.white, height: 1.65, fontSize: 14)),
            ]),
          ),
        ],
        const SizedBox(height: 32),
      ],
    );
  }

  InputDecoration _inputDecoration({required String hint, required Color accentColor}) =>
      InputDecoration(
        hintText: hint,
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
            borderSide: BorderSide(color: accentColor)),
      );
}

class _NiveauBtn extends StatelessWidget {
  final int niveau;
  final String emoji, label, subtitle;
  final bool active;
  final List<Color> grad;
  final VoidCallback? onTap;
  const _NiveauBtn({
    required this.niveau, required this.emoji,
    required this.label, required this.subtitle,
    required this.active, required this.grad, required this.onTap,
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
              color: active ? grad.first : Colors.white.withValues(alpha: 0.08)),
        ),
        child: Row(children: [
          Text(emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Niveau $niveau — $label',
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
              const SizedBox(height: 2),
              Text(subtitle,
                  style: const TextStyle(color: Colors.white38, fontSize: 12)),
            ]),
          ),
          Icon(Icons.chevron_right,
              color: onTap == null ? Colors.white12 : Colors.white38),
        ]),
      ),
    );
  }
}

// ─── Widgets suivi pédagogique ────────────────────────────────────────────────

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

class _SelfEvalBadge extends StatelessWidget {
  final String? niveau;
  const _SelfEvalBadge({required this.niveau});
  @override
  Widget build(BuildContext context) {
    final emoji = niveau == 'maitrise' ? '🟢' : niveau == 'en_cours' ? '🟡' : '🔴';
    final label = niveau == 'maitrise' ? 'Maîtrisé — enregistré' : niveau == 'en_cours' ? 'En cours — enregistré' : 'À retravailler — enregistré';
    final color = niveau == 'maitrise' ? const Color(0xFF16A34A) : niveau == 'en_cours' ? const Color(0xFFD97706) : const Color(0xFFDC2626);
    return Container(
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
  final List<Color> grad;
  final VoidCallback onTap;
  const _EmptyView({
    required this.icon, required this.msg, required this.btnLabel,
    required this.grad, required this.onTap,
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
  const _GradBanner({required this.grad, required this.icon, required this.title, required this.subtitle});
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
                  style: const TextStyle(
                      color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
              const SizedBox(height: 2),
              Text(subtitle,
                  style: const TextStyle(color: Colors.white70, fontSize: 12)),
            ]),
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
        child: Text(text,
            style: const TextStyle(color: Colors.white, height: 1.65, fontSize: 13)),
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
                style: TextStyle(
                    color: color.withValues(alpha: 0.9), fontSize: 12, height: 1.5)),
          ),
        ]),
      );
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(
          color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600));
}
