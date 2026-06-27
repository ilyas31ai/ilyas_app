import 'package:flutter/material.dart';

import '../services/ai_revision_service.dart';
import '../services/revision_firestore_service.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// Page IA Scolaire — Assistant IA scolaire standalone
// ═══════════════════════════════════════════════════════════════════════════════

class AiScolairePage extends StatefulWidget {
  const AiScolairePage({super.key});

  @override
  State<AiScolairePage> createState() => _AiScolairePageState();
}

class _AiScolairePageState extends State<AiScolairePage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  String _matiere  = 'Mathématiques';
  String _categorie = 'Collège';

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('IA Scolaire',
                style: TextStyle(
                    color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            Text('$_matiere · $_categorie',
                style: const TextStyle(color: Colors.white38, fontSize: 11)),
          ],
        ),
        actions: [
          // Matière picker
          PopupMenuButton<String>(
            icon: const Icon(Icons.book_outlined, color: Colors.white70),
            tooltip: 'Changer la matière',
            color: const Color(0xFF1C2128),
            onSelected: (v) => setState(() => _matiere = v),
            itemBuilder: (_) => _kMatieres.map((m) => PopupMenuItem(
              value: m,
              child: Row(children: [
                if (m == _matiere)
                  const Icon(Icons.check, color: Color(0xFF0F766E), size: 16)
                else
                  const SizedBox(width: 16),
                const SizedBox(width: 8),
                Text(m, style: const TextStyle(color: Colors.white, fontSize: 13)),
              ]),
            )).toList(),
          ),
          // Catégorie picker
          PopupMenuButton<String>(
            icon: const Icon(Icons.tune, color: Colors.white70),
            tooltip: 'Changer le niveau',
            color: const Color(0xFF1C2128),
            onSelected: (v) => setState(() => _categorie = v),
            itemBuilder: (_) => _kCategories.map((c) => PopupMenuItem(
              value: c,
              child: Row(children: [
                if (c == _categorie)
                  const Icon(Icons.check, color: Color(0xFF0F766E), size: 16)
                else
                  const SizedBox(width: 16),
                const SizedBox(width: 8),
                Text(c, style: const TextStyle(color: Colors.white, fontSize: 13)),
              ]),
            )).toList(),
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          indicatorColor: const Color(0xFF2563EB),
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white38,
          tabs: const [
            Tab(text: '💬 Question'),
            Tab(text: '📚 Cours'),
            Tab(text: '❓ QCM'),
            Tab(text: '🃏 Flashcards'),
            Tab(text: '📋 Fiche'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _QuestionTab(matiere: _matiere, categorie: _categorie),
          _CoursTab(matiere: _matiere, categorie: _categorie),
          _QcmTab(matiere: _matiere, categorie: _categorie),
          _FlashcardsTab(matiere: _matiere, categorie: _categorie),
          _FicheTab(matiere: _matiere, categorie: _categorie),
        ],
      ),
    );
  }
}

// ─── Constants ────────────────────────────────────────────────────────────────

const _kCategories = ['Maternelle', 'Primaire', 'Collège', 'Lycée', 'Université'];

const _kMatieres = [
  'Mathématiques', 'Français', 'Histoire-Géo', 'SVT', 'Physique-Chimie',
  'Anglais', 'Espagnol', 'Informatique', 'Philosophie', 'Sciences',
  'Économie', 'Droit', 'Lettres',
];

// ═══════════════════════════════════════════════════════════════════════════════
// Tab 1 — Question / réponse libre
// ═══════════════════════════════════════════════════════════════════════════════

class _QuestionTab extends StatefulWidget {
  final String matiere, categorie;
  const _QuestionTab({required this.matiere, required this.categorie});
  @override
  State<_QuestionTab> createState() => _QuestionTabState();
}

class _QuestionTabState extends State<_QuestionTab> {
  final _ctrl   = TextEditingController();
  final _scroll = ScrollController();
  final List<_ChatEntry> _history = [];
  bool _loading = false;

  @override
  void dispose() {
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final q = _ctrl.text.trim();
    if (q.isEmpty || _loading) return;
    _ctrl.clear();
    setState(() {
      _history.add(_ChatEntry(isUser: true, text: q));
      _loading = true;
    });
    _scrollToBottom();

    final r = await AiRevisionService.repondreQuestion(
      question : q,
      matiere  : widget.matiere,
      categorie: widget.categorie,
    );
    if (mounted) {
      setState(() {
        _history.add(_ChatEntry(isUser: false, text: r));
        _loading = false;
      });
      RevisionFirestoreService.saveSession(
        matiere: widget.matiere, categorie: widget.categorie, type: 'cours');
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Chat history
        Expanded(
          child: _history.isEmpty
              ? _buildWelcome()
              : ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.all(16),
                  itemCount: _history.length + (_loading ? 1 : 0),
                  itemBuilder: (_, i) {
                    if (i == _history.length) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 10),
                        child: Row(children: [
                          SizedBox(width: 8),
                          SizedBox(
                            width: 16, height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Color(0xFF2563EB)),
                          ),
                          SizedBox(width: 10),
                          Text('Génération…',
                              style: TextStyle(color: Colors.white38, fontSize: 12)),
                        ]),
                      );
                    }
                    final entry = _history[i];
                    return _MessageBubble(entry: entry);
                  },
                ),
        ),
        // Input
        Container(
          color: const Color(0xFF161B22),
          padding: const EdgeInsets.fromLTRB(12, 8, 8, 12),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _ctrl,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  maxLines: 3,
                  minLines: 1,
                  decoration: InputDecoration(
                    hintText: 'Pose ta question sur ${widget.matiere}…',
                    hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                    filled: true,
                    fillColor: const Color(0xFF0D1117),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                  ),
                  onSubmitted: (_) => _send(),
                  textInputAction: TextInputAction.send,
                ),
              ),
              const SizedBox(width: 8),
              Material(
                color: const Color(0xFF2563EB),
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: _loading ? null : _send,
                  child: const Padding(
                    padding: EdgeInsets.all(12),
                    child: Icon(Icons.send_rounded, color: Colors.white, size: 20),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWelcome() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1E3A5F), Color(0xFF0F2027)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF2563EB).withValues(alpha: 0.3)),
            ),
            child: Column(
              children: [
                const Icon(Icons.smart_toy_outlined,
                    color: Color(0xFF2563EB), size: 44),
                const SizedBox(height: 12),
                const Text('Bonjour ! Je suis ton assistant IA scolaire.',
                    style: TextStyle(
                        color: Colors.white, fontSize: 15,
                        fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center),
                const SizedBox(height: 8),
                Text(
                  'Pose-moi n\'importe quelle question sur ${widget.matiere} '
                  '(niveau ${widget.categorie}).\nJ\'explique, j\'illustre et je t\'aide à comprendre.',
                  style: const TextStyle(color: Colors.white60, fontSize: 12, height: 1.6),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text('EXEMPLES DE QUESTIONS',
                style: TextStyle(
                    color: Colors.white38, fontSize: 10,
                    fontWeight: FontWeight.w700, letterSpacing: 1.2)),
          ),
          const SizedBox(height: 10),
          ..._kExemples.map((q) => GestureDetector(
            onTap: () { _ctrl.text = q; _ctrl.selection = TextSelection.fromPosition(
                TextPosition(offset: q.length)); },
            child: Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF161B22),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.2)),
              ),
              child: Row(children: [
                const Icon(Icons.chat_bubble_outline,
                    color: Color(0xFF2563EB), size: 16),
                const SizedBox(width: 10),
                Expanded(
                    child: Text(q,
                        style: const TextStyle(color: Colors.white70, fontSize: 13))),
              ]),
            ),
          )),
        ],
      ),
    );
  }

  static const _kExemples = [
    'Explique-moi le théorème de Pythagore',
    'Comment fonctionne la photosynthèse ?',
    'Quelle est la différence entre un verbe transitif et intransitif ?',
    'Donne-moi un résumé de la Révolution française',
  ];
}

class _ChatEntry {
  final bool isUser;
  final String text;
  const _ChatEntry({required this.isUser, required this.text});
}

class _MessageBubble extends StatelessWidget {
  final _ChatEntry entry;
  const _MessageBubble({required this.entry});

  @override
  Widget build(BuildContext context) {
    final isUser = entry.isUser;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(
          top: 4, bottom: 4,
          left: isUser ? 48 : 0,
          right: isUser ? 0 : 48,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isUser
              ? const Color(0xFF2563EB)
              : const Color(0xFF161B22),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(14),
            topRight: const Radius.circular(14),
            bottomLeft: Radius.circular(isUser ? 14 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 14),
          ),
          border: isUser
              ? null
              : Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Text(
          entry.text,
          style: TextStyle(
            color: isUser ? Colors.white : Colors.white,
            fontSize: 13,
            height: 1.6,
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Tab 2 — Cours généré par l'IA
// ═══════════════════════════════════════════════════════════════════════════════

class _CoursTab extends StatefulWidget {
  final String matiere, categorie;
  const _CoursTab({required this.matiere, required this.categorie});
  @override
  State<_CoursTab> createState() => _CoursTabState();
}

class _CoursTabState extends State<_CoursTab> {
  String? _cours;
  bool _loading = false;

  Future<void> _generate() async {
    setState(() { _loading = true; _cours = null; });
    final r = await AiRevisionService.genererCoursLibre(
        matiere: widget.matiere, categorie: widget.categorie);
    if (mounted) setState(() { _cours = r; _loading = false; });
    if (r.isNotEmpty && !r.startsWith('❌')) {
      RevisionFirestoreService.saveSession(
          matiere: widget.matiere, categorie: widget.categorie, type: 'cours');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const _AiLoadingView(msg: 'Génération du cours…');
    if (_cours == null) return _buildEmpty();
    return _buildContent();
  }

  Widget _buildEmpty() => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.menu_book_outlined, color: Colors.white24, size: 56),
        const SizedBox(height: 16),
        Text('Cours sur ${widget.matiere}',
            style: const TextStyle(
                color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text('Niveau ${widget.categorie}',
            style: const TextStyle(color: Colors.white38, fontSize: 13)),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2563EB),
            foregroundColor: Colors.white,
            minimumSize: const Size(200, 44),
          ),
          onPressed: _generate,
          icon: const Icon(Icons.auto_awesome, size: 18),
          label: const Text('Générer le cours'),
        ),
      ]),
    ),
  );

  Widget _buildContent() => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      Row(mainAxisAlignment: MainAxisAlignment.end, children: [
        TextButton.icon(
          onPressed: _generate,
          icon: const Icon(Icons.refresh, size: 16),
          label: const Text('Régénérer', style: TextStyle(fontSize: 12)),
          style: TextButton.styleFrom(foregroundColor: Colors.white38),
        ),
      ]),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF161B22),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF2563EB).withValues(alpha: 0.2)),
        ),
        child: Text(_cours!,
            style: const TextStyle(color: Colors.white, height: 1.7, fontSize: 13)),
      ),
    ],
  );
}

// ═══════════════════════════════════════════════════════════════════════════════
// Tab 3 — QCM
// ═══════════════════════════════════════════════════════════════════════════════

class _QcmTab extends StatefulWidget {
  final String matiere, categorie;
  const _QcmTab({required this.matiere, required this.categorie});
  @override
  State<_QcmTab> createState() => _QcmTabState();
}

class _QcmTabState extends State<_QcmTab> {
  List<Map<String, dynamic>>? _quiz;
  bool _loading = false;
  int _qi = 0;
  int? _selected;
  bool _answered = false;
  int _correct = 0;
  bool _done = false;

  Future<void> _generate() async {
    setState(() {
      _loading = true; _quiz = null;
      _qi = 0; _selected = null; _answered = false;
      _correct = 0; _done = false;
    });
    final r = await AiRevisionService.genererQuizLibre(
        matiere: widget.matiere, categorie: widget.categorie);
    if (mounted) setState(() { _quiz = r; _loading = false; });
  }

  void _restart() => setState(() {
    _qi = 0; _selected = null; _answered = false;
    _correct = 0; _done = false;
  });

  @override
  Widget build(BuildContext context) {
    if (_loading) return const _AiLoadingView(msg: 'Génération du QCM…');
    final quiz = _quiz;
    if (quiz == null) return _buildStart();
    if (_done) return _buildResult(quiz);
    return _buildQuestion(quiz);
  }

  Widget _buildStart() => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.quiz_outlined, color: Colors.white24, size: 56),
        const SizedBox(height: 16),
        Text('QCM — ${widget.matiere}',
            style: const TextStyle(
                color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text('Niveau ${widget.categorie} · 5 à 8 questions',
            style: const TextStyle(color: Colors.white38, fontSize: 13)),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF6C47FF),
            foregroundColor: Colors.white,
            minimumSize: const Size(200, 44),
          ),
          onPressed: _generate,
          icon: const Icon(Icons.play_arrow_rounded, size: 18),
          label: const Text('Lancer le QCM'),
        ),
      ]),
    ),
  );

  Widget _buildQuestion(List<Map<String, dynamic>> quiz) {
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
            color: const Color(0xFF6C47FF),
            minHeight: 4,
          ),
          const SizedBox(height: 8),
          Text('Question ${_qi + 1} / ${quiz.length}',
              style: const TextStyle(color: Colors.white38, fontSize: 11)),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF161B22),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Text(q['q'] as String? ?? '',
                style: const TextStyle(
                    color: Colors.white, fontSize: 15,
                    fontWeight: FontWeight.w600)),
          ),
          const SizedBox(height: 14),
          ...choices.asMap().entries.map((e) {
            Color bg     = const Color(0xFF161B22);
            Color border = Colors.white.withValues(alpha: 0.08);
            if (_answered) {
              if (e.key == answer) {
                bg = const Color(0xFF0A1F0A);
                border = const Color(0xFF16A34A);
              } else if (e.key == _selected) {
                bg = const Color(0xFF1F0A0A);
                border = const Color(0xFFDC2626);
              }
            }
            return GestureDetector(
              onTap: () {
                if (_answered) return;
                setState(() {
                  _selected = e.key;
                  _answered = true;
                  if (e.key == answer) _correct++;
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
                    const Icon(Icons.radio_button_unchecked,
                        color: Colors.white38, size: 18),
                  const SizedBox(width: 10),
                  Expanded(child: Text(e.value,
                      style: const TextStyle(color: Colors.white, fontSize: 14))),
                ]),
              ),
            );
          }),
          if (_answered && explic.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF0D1B2A),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.25)),
              ),
              child: Text(explic,
                  style: const TextStyle(
                      color: Colors.white70, fontSize: 13, height: 1.5)),
            ),
            const SizedBox(height: 8),
          ],
          const Spacer(),
          if (_answered)
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C47FF),
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(44),
              ),
              onPressed: () {
                if (_qi < quiz.length - 1) {
                  setState(() {
                    _qi++;
                    _selected = null;
                    _answered = false;
                  });
                } else {
                  setState(() => _done = true);
                  final pct = quiz.isEmpty ? 0 : (_correct * 100 ~/ quiz.length);
                  RevisionFirestoreService.saveSession(
                    matiere  : widget.matiere,
                    categorie: widget.categorie,
                    type     : 'quiz',
                    score    : pct,
                  );
                }
              },
              child: Text(_qi < quiz.length - 1
                  ? 'Question suivante'
                  : 'Voir les résultats'),
            ),
        ],
      ),
    );
  }

  Widget _buildResult(List<Map<String, dynamic>> quiz) {
    final pct = quiz.isEmpty ? 0 : (_correct * 100 ~/ quiz.length);
    final color = pct >= 80
        ? const Color(0xFF16A34A)
        : pct >= 50
            ? const Color(0xFFD97706)
            : const Color(0xFFDC2626);
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
          Text('$pct%',
              style: TextStyle(
                  color: color, fontSize: 22, fontWeight: FontWeight.bold)),
        ]),
        const SizedBox(height: 16),
        Text('$_correct / ${quiz.length} bonnes réponses',
            style: const TextStyle(
                color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Text(
          pct >= 80 ? '🎉 Excellent résultat !'
              : pct >= 50 ? '👍 Bien ! Continue à réviser.'
              : '💪 Entraîne-toi encore, tu vas y arriver.',
          style: const TextStyle(color: Colors.white70, fontSize: 13),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 28),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6C47FF),
              foregroundColor: Colors.white,
            ),
            onPressed: _restart,
            icon: const Icon(Icons.replay, size: 18),
            label: const Text('Recommencer'),
          ),
          const SizedBox(width: 12),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white54,
              side: const BorderSide(color: Colors.white12),
            ),
            onPressed: _generate,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Nouveau QCM'),
          ),
        ]),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Tab 4 — Flashcards
// ═══════════════════════════════════════════════════════════════════════════════

class _FlashcardsTab extends StatefulWidget {
  final String matiere, categorie;
  const _FlashcardsTab({required this.matiere, required this.categorie});
  @override
  State<_FlashcardsTab> createState() => _FlashcardsTabState();
}

class _FlashcardsTabState extends State<_FlashcardsTab> {
  List<Map<String, dynamic>>? _cards;
  bool _loading = false;
  int _index = 0;
  bool _flipped = false;
  final Map<int, bool?> _known = {};

  Future<void> _generate() async {
    setState(() {
      _loading = true; _cards = null;
      _index = 0; _flipped = false; _known.clear();
    });
    final r = await AiRevisionService.genererFlashcardsLibres(
        matiere: widget.matiere, categorie: widget.categorie);
    if (mounted) setState(() { _cards = r; _loading = false; });
    if (r.isNotEmpty) {
      RevisionFirestoreService.saveSession(
        matiere  : widget.matiere, categorie: widget.categorie,
        type     : 'flashcards', nbCards: r.length,
      );
    }
  }

  void _flip() => setState(() => _flipped = !_flipped);

  void _mark(bool known) {
    setState(() {
      _known[_index] = known;
      if (_index < (_cards?.length ?? 1) - 1) {
        _index++;
        _flipped = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const _AiLoadingView(msg: 'Génération des flashcards…');
    final cards = _cards;
    if (cards == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.style_outlined, color: Colors.white24, size: 56),
            const SizedBox(height: 16),
            Text('Flashcards — ${widget.matiere}',
                style: const TextStyle(
                    color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Niveau ${widget.categorie} · 8+ cartes mémo',
                style: const TextStyle(color: Colors.white38, fontSize: 13)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD97706),
                foregroundColor: Colors.white,
                minimumSize: const Size(200, 44),
              ),
              onPressed: _generate,
              icon: const Icon(Icons.auto_awesome, size: 18),
              label: const Text('Générer les flashcards'),
            ),
          ]),
        ),
      );
    }

    if (_index >= cards.length) return _buildSummary(cards);

    final card  = cards[_index];
    final front = card['front'] as String? ?? '';
    final back  = card['back']  as String? ?? '';
    final theme = card['theme'] as String? ?? '';

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LinearProgressIndicator(
            value: _index / cards.length,
            backgroundColor: Colors.white12,
            color: const Color(0xFFD97706),
            minHeight: 4,
          ),
          const SizedBox(height: 6),
          Text('${_index + 1} / ${cards.length}',
              style: const TextStyle(color: Colors.white38, fontSize: 11)),
          const SizedBox(height: 12),
          Expanded(
            child: GestureDetector(
              onTap: _flip,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: _flipped
                        ? [const Color(0xFF0D1F0D), const Color(0xFF0A1A1A)]
                        : [const Color(0xFFD97706).withValues(alpha: 0.15),
                           const Color(0xFF161B22)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _flipped
                        ? const Color(0xFF16A34A).withValues(alpha: 0.4)
                        : const Color(0xFFD97706).withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (theme.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD97706).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(theme,
                            style: const TextStyle(
                                color: Color(0xFFD97706),
                                fontSize: 11,
                                fontWeight: FontWeight.w600)),
                      ),
                      const SizedBox(height: 14),
                    ],
                    Icon(
                      _flipped ? Icons.lightbulb_outlined : Icons.quiz_outlined,
                      color: _flipped
                          ? const Color(0xFF16A34A)
                          : const Color(0xFFD97706),
                      size: 28,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      _flipped ? back : front,
                      style: TextStyle(
                        color: _flipped
                            ? const Color(0xFFBBF7D0)
                            : Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 18),
                    Text(
                      _flipped ? 'Réponse' : 'Appuie pour voir la réponse',
                      style: const TextStyle(color: Colors.white38, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (_flipped)
            Row(children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0A2A0A),
                    foregroundColor: const Color(0xFF16A34A),
                    side: const BorderSide(color: Color(0xFF16A34A)),
                  ),
                  onPressed: () => _mark(true),
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text('Je sais'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2A0A0A),
                    foregroundColor: const Color(0xFFDC2626),
                    side: const BorderSide(color: Color(0xFFDC2626)),
                  ),
                  onPressed: () => _mark(false),
                  icon: const Icon(Icons.replay, size: 18),
                  label: const Text('À revoir'),
                ),
              ),
            ])
          else
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD97706),
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(44),
              ),
              onPressed: _flip,
              icon: const Icon(Icons.flip, size: 18),
              label: const Text('Retourner'),
            ),
        ],
      ),
    );
  }

  Widget _buildSummary(List<Map<String, dynamic>> cards) {
    final known  = _known.values.where((v) => v == true).length;
    final pct    = cards.isEmpty ? 0 : (known * 100 ~/ cards.length);
    final color  = pct >= 75
        ? const Color(0xFF16A34A)
        : pct >= 50
            ? const Color(0xFFD97706)
            : const Color(0xFFDC2626);
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
          Text('$pct%',
              style: TextStyle(
                  color: color, fontSize: 22, fontWeight: FontWeight.bold)),
        ]),
        const SizedBox(height: 12),
        Text('$known / ${cards.length} cartes mémorisées',
            style: const TextStyle(
                color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFD97706),
            foregroundColor: Colors.white,
          ),
          onPressed: () => setState(() {
            _index = 0; _flipped = false; _known.clear();
          }),
          icon: const Icon(Icons.replay, size: 18),
          label: const Text('Recommencer'),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white54,
            side: const BorderSide(color: Colors.white12),
          ),
          onPressed: _generate,
          icon: const Icon(Icons.refresh, size: 18),
          label: const Text('Nouvelles flashcards'),
        ),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Tab 5 — Fiche de révision
// ═══════════════════════════════════════════════════════════════════════════════

class _FicheTab extends StatefulWidget {
  final String matiere, categorie;
  const _FicheTab({required this.matiere, required this.categorie});
  @override
  State<_FicheTab> createState() => _FicheTabState();
}

class _FicheTabState extends State<_FicheTab> {
  String? _fiche;
  bool _loading = false;

  Future<void> _generate() async {
    setState(() { _loading = true; _fiche = null; });
    final r = await AiRevisionService.genererFicheRevision(
        matiere: widget.matiere, categorie: widget.categorie);
    if (mounted) setState(() { _fiche = r; _loading = false; });
    if (r.isNotEmpty && !r.startsWith('❌')) {
      RevisionFirestoreService.saveSession(
          matiere: widget.matiere, categorie: widget.categorie, type: 'fiche');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const _AiLoadingView(msg: 'Génération de la fiche…');
    if (_fiche == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.article_outlined, color: Colors.white24, size: 56),
            const SizedBox(height: 16),
            Text('Fiche — ${widget.matiere}',
                style: const TextStyle(
                    color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Niveau ${widget.categorie} · Synthèse clé',
                style: const TextStyle(color: Colors.white38, fontSize: 13)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F766E),
                foregroundColor: Colors.white,
                minimumSize: const Size(200, 44),
              ),
              onPressed: _generate,
              icon: const Icon(Icons.auto_awesome, size: 18),
              label: const Text('Générer la fiche'),
            ),
          ]),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          TextButton.icon(
            onPressed: _generate,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Régénérer', style: TextStyle(fontSize: 12)),
            style: TextButton.styleFrom(foregroundColor: Colors.white38),
          ),
        ]),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF161B22),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: const Color(0xFF0F766E).withValues(alpha: 0.25)),
          ),
          child: Text(_fiche!,
              style: const TextStyle(color: Colors.white, height: 1.7, fontSize: 13)),
        ),
      ],
    );
  }
}

// ─── Shared widgets ───────────────────────────────────────────────────────────

class _AiLoadingView extends StatelessWidget {
  final String msg;
  const _AiLoadingView({required this.msg});
  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      const SizedBox(
        width: 32, height: 32,
        child: CircularProgressIndicator(
            strokeWidth: 3, color: Color(0xFF2563EB)),
      ),
      const SizedBox(height: 16),
      Text(msg, style: const TextStyle(color: Colors.white38, fontSize: 13)),
    ]),
  );
}
