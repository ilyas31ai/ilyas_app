import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../services/xp_service.dart';

class JeuxScolairesPage extends StatelessWidget {
  const JeuxScolairesPage({super.key});

  static const _games = [
    _GameInfo('Maths rapides', '⚡', 'Addition · Soustraction · Multiplication',
        [Color(0xFF6C47FF), Color(0xFF2563EB)], true),
    _GameInfo('Multiplications', '✖️', 'Tables de multiplication',
        [Color(0xFF16A34A), Color(0xFF059669)], true),
    _GameInfo('Mémoire visuelle', '🧠', 'Retiens et reproduis',
        [Color(0xFFDC2626), Color(0xFFDB2777)], false),
    _GameInfo('Vocabulaire', '📝', 'Enrichis ton dictionnaire',
        [Color(0xFFD97706), Color(0xFFF59E0B)], false),
    _GameInfo('Calcul mental', '🔢', 'Rapidité et précision',
        [Color(0xFF0891B2), Color(0xFF7C3AED)], false),
    _GameInfo('Orthographe', '✍️', 'Bonne orthographe = bon français',
        [Color(0xFFBE185D), Color(0xFF9333EA)], false),
    _GameInfo('Puzzle logique', '🧩', 'Réflexion et logique',
        [Color(0xFF0F766E), Color(0xFF0891B2)], false),
    _GameInfo('Défis chrono', '⏱️', 'Bats le chrono !',
        [Color(0xFFB45309), Color(0xFFD97706)], false),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        title: const Text('🎮 Jeux Scolaires'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.88,
        ),
        itemCount: _games.length,
        itemBuilder: (_, i) => _GameTile(game: _games[i]),
      ),
    );
  }
}

// ─── Data ─────────────────────────────────────────────────────────────────────

class _GameInfo {
  final String title, emoji, desc;
  final List<Color> colors;
  final bool available;
  const _GameInfo(this.title, this.emoji, this.desc, this.colors, this.available);
}

// ─── Tile ─────────────────────────────────────────────────────────────────────

class _GameTile extends StatelessWidget {
  final _GameInfo game;
  const _GameTile({required this.game});

  void _onTap(BuildContext context) {
    if (!game.available) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${game.title} — bientôt disponible !'),
        backgroundColor: const Color(0xFF1C2128),
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    if (game.title == 'Maths rapides') {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => const _MathsRapidesGame(),
      );
    } else if (game.title == 'Multiplications') {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => const _MultiplicationsGame(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _onTap(context),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
              colors: game.colors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color: game.colors[0].withValues(alpha: 0.35),
                blurRadius: 10,
                offset: const Offset(0, 5))
          ],
        ),
        child: Stack(
          children: [
            if (!game.available)
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                      color: Colors.black38,
                      borderRadius: BorderRadius.circular(8)),
                  child: const Text('Bientôt',
                      style: TextStyle(color: Colors.white70, fontSize: 9)),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(game.emoji, style: const TextStyle(fontSize: 38)),
                  const Spacer(),
                  Text(game.title,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(game.desc,
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 11),
                      maxLines: 2),
                  const SizedBox(height: 8),
                  Row(children: const [
                    Icon(Icons.star, color: Colors.amber, size: 13),
                    SizedBox(width: 4),
                    Text('+10 XP / bonne réponse',
                        style:
                            TextStyle(color: Colors.white60, fontSize: 10)),
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Maths Rapides ────────────────────────────────────────────────────────────

class _MathsRapidesGame extends StatefulWidget {
  const _MathsRapidesGame();

  @override
  State<_MathsRapidesGame> createState() => _MathsRapidesGameState();
}

class _MathsRapidesGameState extends State<_MathsRapidesGame> {
  final _rng = Random();
  int _score = 0;
  int _streak = 0;
  int _timeLeft = 30;
  Timer? _timer;
  late int _a, _b, _answer;
  late String _op;
  late List<int> _choices;
  String? _feedback;
  bool _gameOver = false;

  @override
  void initState() {
    super.initState();
    _generateQuestion();
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() {
        if (_timeLeft > 0) {
          _timeLeft--;
        } else {
          _gameOver = true;
          t.cancel();
          XpService.gainXP(_score * 10);
        }
      });
    });
  }

  void _generateQuestion() {
    final ops = ['+', '-', '×'];
    _op = ops[_rng.nextInt(ops.length)];
    switch (_op) {
      case '+':
        _a = _rng.nextInt(20) + 1;
        _b = _rng.nextInt(20) + 1;
        _answer = _a + _b;
        break;
      case '-':
        _a = _rng.nextInt(20) + 10;
        _b = _rng.nextInt(_a) + 1;
        _answer = _a - _b;
        break;
      case '×':
        _a = _rng.nextInt(10) + 1;
        _b = _rng.nextInt(10) + 1;
        _answer = _a * _b;
        break;
    }
    final wrong = <int>{};
    while (wrong.length < 3) {
      final offset = _rng.nextInt(10) + 1;
      final w = _rng.nextBool() ? _answer + offset : (_answer - offset).abs();
      if (w != _answer) wrong.add(w);
    }
    _choices = [...wrong, _answer]..shuffle(_rng);
    _feedback = null;
  }

  void _onAnswer(int val) {
    if (_gameOver || _feedback != null) return;
    if (val == _answer) {
      setState(() { _score++; _streak++; _feedback = '✅'; });
    } else {
      setState(() { _streak = 0; _feedback = '❌'; });
    }
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted && !_gameOver) setState(() => _generateQuestion());
    });
  }

  @override
  void dispose() { _timer?.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Color(0xFF161B22),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: _gameOver ? _buildResult() : _buildGame(),
    );
  }

  Widget _buildGame() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Column(
        children: [
          _handle(),
          const SizedBox(height: 20),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            _badge('⏱', '$_timeLeft s',
                _timeLeft < 10 ? Colors.redAccent : Colors.white60),
            _badge('⚡', '$_score bonnes', Colors.amber),
            _badge('🔥', '$_streak streak', Colors.orange),
          ]),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: _timeLeft / 30,
              backgroundColor: Colors.white12,
              valueColor: AlwaysStoppedAnimation<Color>(
                  _timeLeft < 10 ? Colors.redAccent : const Color(0xFF6C47FF)),
              minHeight: 6,
            ),
          ),
          const Spacer(),
          _feedback != null
              ? Text(_feedback!, style: const TextStyle(fontSize: 52))
              : Text(
                  '$_a $_op $_b = ?',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 44,
                      fontWeight: FontWeight.bold),
                ),
          const Spacer(),
          GridView.count(
            shrinkWrap: true,
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 2.5,
            children: _choices.map(_choiceBtn).toList(),
          ),
        ],
      ),
    );
  }

  Widget _choiceBtn(int val) => Material(
        color: const Color(0xFF1C2128),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _onAnswer(val),
          child: Center(
            child: Text('$val',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold)),
          ),
        ),
      );

  Widget _buildResult() {
    final xpEarned = _score * 10;
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('🎉', style: TextStyle(fontSize: 64)),
          const SizedBox(height: 16),
          Text('$_score bonnes réponses !',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('+$xpEarned XP gagnés',
              style: const TextStyle(color: Colors.amber, fontSize: 20)),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C47FF),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () {
                _timer?.cancel();
                setState(() {
                  _score = 0; _streak = 0; _timeLeft = 30; _gameOver = false;
                  _generateQuestion();
                });
                _startTimer();
              },
              child: const Text('Rejouer',
                  style: TextStyle(fontSize: 16, color: Colors.white)),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer',
                style: TextStyle(color: Colors.white54)),
          ),
        ],
      ),
    );
  }
}

// ─── Multiplications ──────────────────────────────────────────────────────────

class _MultiplicationsGame extends StatefulWidget {
  const _MultiplicationsGame();

  @override
  State<_MultiplicationsGame> createState() => _MultiplicationsGameState();
}

class _MultiplicationsGameState extends State<_MultiplicationsGame> {
  final _rng = Random();
  int _score = 0;
  int _timeLeft = 45;
  Timer? _timer;
  late int _a, _b, _answer;
  late List<int> _choices;
  String? _feedback;
  bool _gameOver = false;

  @override
  void initState() {
    super.initState();
    _generateQuestion();
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() {
        if (_timeLeft > 0) {
          _timeLeft--;
        } else {
          _gameOver = true;
          t.cancel();
          XpService.gainXP(_score * 10);
        }
      });
    });
  }

  void _generateQuestion() {
    _a = _rng.nextInt(10) + 1;
    _b = _rng.nextInt(10) + 1;
    _answer = _a * _b;
    final wrong = <int>{};
    while (wrong.length < 3) {
      final wa = _rng.nextInt(10) + 1;
      final wb = _rng.nextInt(10) + 1;
      final w = wa * wb;
      if (w != _answer) wrong.add(w);
    }
    _choices = [...wrong, _answer]..shuffle(_rng);
    _feedback = null;
  }

  void _onAnswer(int val) {
    if (_gameOver || _feedback != null) return;
    setState(() {
      _feedback = val == _answer ? '✅' : '❌';
      if (val == _answer) _score++;
    });
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted && !_gameOver) setState(() => _generateQuestion());
    });
  }

  @override
  void dispose() { _timer?.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Color(0xFF161B22),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: _gameOver ? _buildResult() : _buildGame(),
    );
  }

  Widget _buildGame() {
    return Column(
      children: [
        _handle(),
        const SizedBox(height: 20),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          _badge('⏱', '$_timeLeft s',
              _timeLeft < 10 ? Colors.redAccent : Colors.white60),
          _badge('✖️', '$_score bonnes', Colors.amber),
        ]),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: _timeLeft / 45,
            backgroundColor: Colors.white12,
            valueColor: AlwaysStoppedAnimation<Color>(
                _timeLeft < 10 ? Colors.redAccent : const Color(0xFF16A34A)),
            minHeight: 6,
          ),
        ),
        const Spacer(),
        _feedback != null
            ? Text(_feedback!, style: const TextStyle(fontSize: 52))
            : Text('$_a × $_b = ?',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 44,
                    fontWeight: FontWeight.bold)),
        const Spacer(),
        GridView.count(
          shrinkWrap: true,
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 2.5,
          children: _choices
              .map((c) => Material(
                    color: const Color(0xFF1C2128),
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => _onAnswer(c),
                      child: Center(
                          child: Text('$c',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold))),
                    ),
                  ))
              .toList(),
        ),
      ],
    );
  }

  Widget _buildResult() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text('🏆', style: TextStyle(fontSize: 64)),
        const SizedBox(height: 16),
        Text('$_score × bonnes réponses !',
            style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text('+${_score * 10} XP',
            style: const TextStyle(color: Colors.amber, fontSize: 20)),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF16A34A),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: () {
              _timer?.cancel();
              setState(() {
                _score = 0; _timeLeft = 45; _gameOver = false;
                _generateQuestion();
              });
              _startTimer();
            },
            child: const Text('Rejouer',
                style: TextStyle(fontSize: 16, color: Colors.white)),
          ),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Fermer',
              style: TextStyle(color: Colors.white54)),
        ),
      ],
    );
  }
}

// ─── Shared helpers ───────────────────────────────────────────────────────────

Widget _handle() => Center(
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
            color: Colors.white24, borderRadius: BorderRadius.circular(2)),
      ),
    );

Widget _badge(String emoji, String text, Color color) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(emoji),
        const SizedBox(width: 4),
        Text(text,
            style: TextStyle(color: color, fontWeight: FontWeight.bold)),
      ]),
    );
