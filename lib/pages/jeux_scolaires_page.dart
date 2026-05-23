import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/xp_service.dart';

class JeuxScolairesPage extends StatelessWidget {
  const JeuxScolairesPage({super.key});

  static const _games = [
    _GameInfo(
      title: 'Maths rapides',
      emoji: '⚡',
      desc: 'Addition · Soustraction · Multiplication',
      colors: [Color(0xFF6C47FF), Color(0xFF2563EB)],
    ),
    _GameInfo(
      title: 'Multiplications',
      emoji: '✖️',
      desc: 'Tables de multiplication',
      colors: [Color(0xFF16A34A), Color(0xFF059669)],
    ),
    _GameInfo(
      title: 'Calcul mental',
      emoji: '🔢',
      desc: 'Rapidité et précision mentale',
      colors: [Color(0xFF0891B2), Color(0xFF7C3AED)],
    ),
    _GameInfo(
      title: 'Défis chrono',
      emoji: '⏱️',
      desc: 'Bats le chrono sur 10 questions',
      colors: [Color(0xFFB45309), Color(0xFFD97706)],
    ),
    _GameInfo(
      title: 'Orthographe',
      emoji: '✍️',
      desc: 'Trouve le mot bien orthographié',
      colors: [Color(0xFFBE185D), Color(0xFF9333EA)],
    ),
    _GameInfo(
      title: 'Vocabulaire',
      emoji: '📝',
      desc: 'Associe le mot à sa définition',
      colors: [Color(0xFFD97706), Color(0xFFF59E0B)],
    ),
    _GameInfo(
      title: 'Mémoire visuelle',
      emoji: '🧠',
      desc: 'Retiens la séquence de couleurs',
      colors: [Color(0xFFDC2626), Color(0xFFDB2777)],
    ),
    _GameInfo(
      title: 'Puzzle logique',
      emoji: '🧩',
      desc: 'Complète la suite logique',
      colors: [Color(0xFF0F766E), Color(0xFF0891B2)],
    ),
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
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
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
  const _GameInfo({
    required this.title,
    required this.emoji,
    required this.desc,
    required this.colors,
  });
}

// ─── Animated Tile ────────────────────────────────────────────────────────────

class _GameTile extends StatefulWidget {
  final _GameInfo game;
  const _GameTile({required this.game});

  @override
  State<_GameTile> createState() => _GameTileState();
}

class _GameTileState extends State<_GameTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      lowerBound: 0.93,
      upperBound: 1.0,
      value: 1.0,
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) {
    HapticFeedback.mediumImpact();
    _ctrl.reverse();
  }

  void _onTapUp(TapUpDetails _) {
    _ctrl.forward().then((_) => _openGame());
  }

  void _onTapCancel() => _ctrl.forward();

  void _openGame() {
    Widget? sheet;
    switch (widget.game.title) {
      case 'Maths rapides':
        sheet = const _MathsRapidesGame();
        break;
      case 'Multiplications':
        sheet = const _MultiplicationsGame();
        break;
      case 'Calcul mental':
        sheet = const _CalculMentalGame();
        break;
      case 'Défis chrono':
        sheet = const _DefisChrono();
        break;
      case 'Orthographe':
        sheet = const _OrthographeGame();
        break;
      case 'Vocabulaire':
        sheet = const _VocabulaireGame();
        break;
      case 'Mémoire visuelle':
        sheet = const _MemoireVisuelle();
        break;
      case 'Puzzle logique':
        sheet = const _PuzzleLogique();
        break;
    }
    if (sheet == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => sheet!,
    );
  }

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: ScaleTransition(
        scale: _ctrl,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: game.colors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: game.colors[0].withValues(alpha: 0.35),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Padding(
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
                    style:
                        const TextStyle(color: Colors.white70, fontSize: 11),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
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
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  GAMES
// ═══════════════════════════════════════════════════════════════════════════════

// ─── 1. Maths Rapides ─────────────────────────────────────────────────────────

class _MathsRapidesGame extends StatefulWidget {
  const _MathsRapidesGame();
  @override
  State<_MathsRapidesGame> createState() => _MathsRapidesGameState();
}

class _MathsRapidesGameState extends State<_MathsRapidesGame> {
  final _rng = Random();
  int _score = 0, _streak = 0, _timeLeft = 30;
  Timer? _timer;
  late int _a, _b, _answer;
  late String _op;
  late List<int> _choices;
  String? _feedback;
  bool _gameOver = false;

  @override
  void initState() {
    super.initState();
    _gen();
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() {
        if (_timeLeft > 0) { _timeLeft--; }
        else { _gameOver = true; t.cancel(); XpService.gainXP(_score * 10); }
      });
    });
  }

  void _gen() {
    final ops = ['+', '-', '×'];
    _op = ops[_rng.nextInt(ops.length)];
    switch (_op) {
      case '+': _a = _rng.nextInt(20)+1; _b = _rng.nextInt(20)+1; _answer = _a+_b; break;
      case '-': _a = _rng.nextInt(20)+10; _b = _rng.nextInt(_a)+1; _answer = _a-_b; break;
      case '×': _a = _rng.nextInt(10)+1; _b = _rng.nextInt(10)+1; _answer = _a*_b; break;
    }
    final w = <int>{};
    while (w.length < 3) {
      final v = _rng.nextBool() ? _answer+_rng.nextInt(10)+1 : (_answer-_rng.nextInt(10)-1).abs();
      if (v != _answer) w.add(v);
    }
    _choices = [...w, _answer]..shuffle(_rng);
    _feedback = null;
  }

  void _answer_(int val) {
    if (_gameOver || _feedback != null) return;
    HapticFeedback.selectionClick();
    final ok = val == _answer;
    if (!ok) HapticFeedback.vibrate();
    setState(() { if (ok) { _score++; _streak++; } else _streak = 0; _feedback = ok ? '✅' : '❌'; });
    Future.delayed(const Duration(milliseconds: 600), () { if (mounted && !_gameOver) setState(_gen); });
  }

  @override
  void dispose() { _timer?.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) => _gameSheet(
    context,
    _gameOver ? _resultBody(context, '🎉', '$_score bonnes réponses', _score * 10,
      () { _timer?.cancel(); setState(() { _score=0; _streak=0; _timeLeft=30; _gameOver=false; _gen(); }); _startTimer(); })
    : Padding(
      padding: const EdgeInsets.fromLTRB(24,16,24,24),
      child: Column(children: [
        _handle(), const SizedBox(height:20),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          _badge('⏱','$_timeLeft s', _timeLeft<10 ? Colors.redAccent : Colors.white60),
          _badge('⚡','$_score bonnes', Colors.amber),
          _badge('🔥','$_streak 🔥', Colors.orange),
        ]),
        const SizedBox(height:10),
        _timerBar(_timeLeft/30, _timeLeft<10, const Color(0xFF6C47FF)),
        const Spacer(),
        _feedback != null ? Text(_feedback!, style: const TextStyle(fontSize:52))
          : Text('$_a $_op $_b = ?', style: const TextStyle(color:Colors.white, fontSize:44, fontWeight:FontWeight.bold)),
        const Spacer(),
        _choiceGrid(_choices, _answer_),
      ]),
    ),
  );
}

// ─── 2. Multiplications ───────────────────────────────────────────────────────

class _MultiplicationsGame extends StatefulWidget {
  const _MultiplicationsGame();
  @override
  State<_MultiplicationsGame> createState() => _MultiplicationsGameState();
}

class _MultiplicationsGameState extends State<_MultiplicationsGame> {
  final _rng = Random();
  int _score=0, _timeLeft=45;
  Timer? _timer;
  late int _a, _b, _answer;
  late List<int> _choices;
  String? _feedback;
  bool _gameOver=false;

  @override
  void initState() { super.initState(); _gen(); _startTimer(); }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds:1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() { if (_timeLeft>0) _timeLeft--; else { _gameOver=true; t.cancel(); XpService.gainXP(_score*10); } });
    });
  }

  void _gen() {
    _a=_rng.nextInt(10)+1; _b=_rng.nextInt(10)+1; _answer=_a*_b;
    final w=<int>{};
    while (w.length<3) { final v=(_rng.nextInt(10)+1)*(_rng.nextInt(10)+1); if (v!=_answer) w.add(v); }
    _choices=[...w,_answer]..shuffle(_rng); _feedback=null;
  }

  void _ans(int val) {
    if (_gameOver||_feedback!=null) return;
    HapticFeedback.selectionClick();
    final ok=val==_answer; if (!ok) HapticFeedback.vibrate();
    setState(() { if (ok) _score++; _feedback=ok?'✅':'❌'; });
    Future.delayed(const Duration(milliseconds:600), () { if (mounted&&!_gameOver) setState(_gen); });
  }

  @override
  void dispose() { _timer?.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) => _gameSheet(context,
    _gameOver ? _resultBody(context,'🏆','$_score × bonnes réponses',_score*10,
      () { _timer?.cancel(); setState(() { _score=0; _timeLeft=45; _gameOver=false; _gen(); }); _startTimer(); })
    : Padding(padding: const EdgeInsets.fromLTRB(24,16,24,24), child: Column(children: [
        _handle(), const SizedBox(height:20),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          _badge('⏱','$_timeLeft s', _timeLeft<10?Colors.redAccent:Colors.white60),
          _badge('✖️','$_score bonnes', Colors.amber),
        ]),
        const SizedBox(height:10),
        _timerBar(_timeLeft/45, _timeLeft<10, const Color(0xFF16A34A)),
        const Spacer(),
        _feedback!=null ? Text(_feedback!,style:const TextStyle(fontSize:52))
          : Text('$_a × $_b = ?',style:const TextStyle(color:Colors.white,fontSize:44,fontWeight:FontWeight.bold)),
        const Spacer(),
        _choiceGrid(_choices, _ans),
      ])),
  );
}

// ─── 3. Calcul Mental ─────────────────────────────────────────────────────────

class _CalculMentalGame extends StatefulWidget {
  const _CalculMentalGame();
  @override
  State<_CalculMentalGame> createState() => _CalculMentalGameState();
}

class _CalculMentalGameState extends State<_CalculMentalGame> {
  final _rng = Random();
  int _score=0, _timeLeft=60;
  Timer? _timer;
  late int _a, _b, _c, _answer;
  late String _op1, _op2;
  late List<int> _choices;
  String? _feedback;
  bool _gameOver=false;

  @override
  void initState() { super.initState(); _gen(); _startTimer(); }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds:1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() { if (_timeLeft>0) _timeLeft--; else { _gameOver=true; t.cancel(); XpService.gainXP(_score*10); } });
    });
  }

  void _gen() {
    // 3-number chain: (a op1 b) op2 c
    final ops = ['+','-'];
    _op1=ops[_rng.nextInt(2)]; _op2=ops[_rng.nextInt(2)];
    _a=_rng.nextInt(15)+1; _b=_rng.nextInt(10)+1; _c=_rng.nextInt(8)+1;
    int step1 = _op1=='+' ? _a+_b : _a-_b;
    _answer = _op2=='+' ? step1+_c : step1-_c;
    if (_answer < 0) { _a+=10; step1=_op1=='+' ? _a+_b : _a-_b; _answer=_op2=='+' ? step1+_c : step1-_c; }
    final w=<int>{};
    while (w.length<3) {
      final v=_answer+(_rng.nextBool()?1:-1)*(_rng.nextInt(5)+1);
      if (v!=_answer) w.add(v);
    }
    _choices=[...w,_answer]..shuffle(_rng); _feedback=null;
  }

  void _ans(int val) {
    if (_gameOver||_feedback!=null) return;
    HapticFeedback.selectionClick();
    final ok=val==_answer; if (!ok) HapticFeedback.vibrate();
    setState(() { if (ok) _score++; _feedback=ok?'✅':'❌'; });
    Future.delayed(const Duration(milliseconds:600), () { if (mounted&&!_gameOver) setState(_gen); });
  }

  @override
  void dispose() { _timer?.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) => _gameSheet(context,
    _gameOver ? _resultBody(context,'🧮','$_score calculs réussis',_score*10,
      () { _timer?.cancel(); setState(() { _score=0; _timeLeft=60; _gameOver=false; _gen(); }); _startTimer(); })
    : Padding(padding: const EdgeInsets.fromLTRB(24,16,24,24), child: Column(children: [
        _handle(), const SizedBox(height:20),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          _badge('⏱','$_timeLeft s', _timeLeft<15?Colors.redAccent:Colors.white60),
          _badge('🔢','$_score réussis', Colors.amber),
        ]),
        const SizedBox(height:10),
        _timerBar(_timeLeft/60, _timeLeft<15, const Color(0xFF0891B2)),
        const Spacer(),
        _feedback!=null ? Text(_feedback!,style:const TextStyle(fontSize:52))
          : Text('$_a $_op1 $_b $_op2 $_c = ?',
              style:const TextStyle(color:Colors.white,fontSize:36,fontWeight:FontWeight.bold),
              textAlign:TextAlign.center),
        const Spacer(),
        _choiceGrid(_choices, _ans),
      ])),
  );
}

// ─── 4. Défis Chrono ──────────────────────────────────────────────────────────

class _DefisChrono extends StatefulWidget {
  const _DefisChrono();
  @override
  State<_DefisChrono> createState() => _DefisChronoState();
}

class _DefisChronoState extends State<_DefisChrono> {
  final _rng = Random();
  int _score=0, _current=0;
  final int _total=10;
  Stopwatch _sw = Stopwatch();
  late int _a, _b, _answer;
  late String _op;
  late List<int> _choices;
  String? _feedback;
  bool _gameOver=false;
  int _elapsedMs=0;

  @override
  void initState() { super.initState(); _gen(); _sw.start(); }

  void _gen() {
    final ops=['+','-','×'];
    _op=ops[_rng.nextInt(ops.length)];
    switch (_op) {
      case '+': _a=_rng.nextInt(20)+1; _b=_rng.nextInt(20)+1; _answer=_a+_b; break;
      case '-': _a=_rng.nextInt(20)+10; _b=_rng.nextInt(_a)+1; _answer=_a-_b; break;
      case '×': _a=_rng.nextInt(10)+1; _b=_rng.nextInt(10)+1; _answer=_a*_b; break;
    }
    final w=<int>{};
    while (w.length<3) { final v=_rng.nextBool()?_answer+_rng.nextInt(8)+1:(_answer-_rng.nextInt(8)-1).abs(); if(v!=_answer) w.add(v); }
    _choices=[...w,_answer]..shuffle(_rng); _feedback=null;
  }

  void _ans(int val) {
    if (_gameOver||_feedback!=null) return;
    HapticFeedback.selectionClick();
    final ok=val==_answer; if (!ok) HapticFeedback.vibrate();
    setState(() { if (ok) _score++; _feedback=ok?'✅':'❌'; });
    Future.delayed(const Duration(milliseconds:500), () {
      if (!mounted) return;
      setState(() {
        _current++;
        if (_current >= _total) {
          _gameOver=true; _elapsedMs=_sw.elapsedMilliseconds; _sw.stop();
          XpService.gainXP(_score*10);
        } else _gen();
      });
    });
  }

  @override
  Widget build(BuildContext context) => _gameSheet(context,
    _gameOver ? Padding(padding: const EdgeInsets.all(32), child: Column(mainAxisAlignment:MainAxisAlignment.center, children:[
      const Text('⏱️', style:TextStyle(fontSize:64)),
      const SizedBox(height:16),
      Text('$_score / $_total correctes', style:const TextStyle(color:Colors.white,fontSize:26,fontWeight:FontWeight.bold)),
      const SizedBox(height:8),
      Text('Temps : ${(_elapsedMs/1000).toStringAsFixed(1)}s', style:const TextStyle(color:Colors.white60,fontSize:16)),
      Text('+${_score*10} XP', style:const TextStyle(color:Colors.amber,fontSize:20)),
      const SizedBox(height:32),
      SizedBox(width:double.infinity, child:ElevatedButton(
        style:ElevatedButton.styleFrom(backgroundColor:const Color(0xFFB45309), padding:const EdgeInsets.symmetric(vertical:16),
          shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(14))),
        onPressed:() => setState(() { _score=0; _current=0; _gameOver=false; _sw=Stopwatch()..start(); _gen(); }),
        child:const Text('Rejouer',style:TextStyle(fontSize:16,color:Colors.white)),
      )),
      const SizedBox(height:12),
      TextButton(onPressed:()=>Navigator.pop(context), child:const Text('Fermer',style:TextStyle(color:Colors.white54))),
    ]))
    : Padding(padding: const EdgeInsets.fromLTRB(24,16,24,24), child: Column(children:[
        _handle(), const SizedBox(height:20),
        Row(mainAxisAlignment:MainAxisAlignment.spaceBetween, children:[
          _badge('📊','${_current+1}/$_total', Colors.white60),
          _badge('✅','$_score correctes', Colors.amber),
        ]),
        const SizedBox(height:10),
        ClipRRect(borderRadius:BorderRadius.circular(4), child:LinearProgressIndicator(
          value:_current/_total, backgroundColor:Colors.white12,
          valueColor:const AlwaysStoppedAnimation<Color>(Color(0xFFD97706)), minHeight:6,
        )),
        const Spacer(),
        _feedback!=null ? Text(_feedback!,style:const TextStyle(fontSize:52))
          : Text('$_a $_op $_b = ?',style:const TextStyle(color:Colors.white,fontSize:44,fontWeight:FontWeight.bold)),
        const Spacer(),
        _choiceGrid(_choices, _ans),
      ])),
  );
}

// ─── 5. Orthographe ───────────────────────────────────────────────────────────

class _OrthographeGame extends StatefulWidget {
  const _OrthographeGame();
  @override
  State<_OrthographeGame> createState() => _OrthographeGameState();
}

class _OrthographeGameState extends State<_OrthographeGame> {
  static const _questions = [
    _OrthoQ('Il est parti en ___', ['vacances', 'vacence', 'vaccances', 'vacanse'], 0),
    _OrthoQ('Elle est très ___', ['intelligente', 'inteligente', 'intelligent', 'intelidjente'], 0),
    _OrthoQ('Nous avons ___ le gâteau', ['mangé', 'mangée', 'manger', 'mangés'], 0),
    _OrthoQ('Le chien est ___', ['fidèle', 'fidele', 'fidelle', 'fideille'], 0),
    _OrthoQ('La ___ est grande', ['bibliothèque', 'bibliotheque', 'biblioteque', 'bibliothéque'], 0),
    _OrthoQ('Un ___ de fleurs', ['bouquet', 'bouquet', 'boukè', 'bouquais'], 0),
    _OrthoQ('Il fait ___ dehors', ['froid', 'frois', 'froide', 'froi'], 0),
    _OrthoQ('Ils sont ___ fatigués', ['très', 'trés', 'tré', 'tres'], 0),
    _OrthoQ('Elle ___ à la maison', ['reste', 'rest', 'rester', 'rests'], 0),
    _OrthoQ('Un ___ de soleil', ['rayon', 'raient', 'raion', 'raiont'], 0),
  ];

  final _rng = Random();
  int _score=0, _timeLeft=60, _qIdx=0;
  Timer? _timer;
  late List<_OrthoQ> _shuffled;
  String? _feedback;
  bool _gameOver=false;

  @override
  void initState() {
    super.initState();
    _shuffled=List.from(_questions)..shuffle(_rng);
    _startTimer();
  }

  void _startTimer() {
    _timer=Timer.periodic(const Duration(seconds:1),(t) {
      if (!mounted) { t.cancel(); return; }
      setState(() { if (_timeLeft>0) _timeLeft--; else { _gameOver=true; t.cancel(); XpService.gainXP(_score*10); } });
    });
  }

  _OrthoQ get _q => _shuffled[_qIdx % _shuffled.length];

  void _ans(int idx) {
    if (_gameOver||_feedback!=null) return;
    HapticFeedback.selectionClick();
    final ok=idx==_q.correct; if (!ok) HapticFeedback.vibrate();
    setState(() { if (ok) _score++; _feedback=ok?'✅':'❌ → ${_q.choices[_q.correct]}'; });
    Future.delayed(const Duration(milliseconds:900), () {
      if (mounted&&!_gameOver) setState(() { _qIdx++; _feedback=null; });
    });
  }

  @override
  void dispose() { _timer?.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) => _gameSheet(context,
    _gameOver ? _resultBody(context,'✍️','$_score mots corrects',_score*10,
      () { _timer?.cancel(); setState(() { _score=0; _timeLeft=60; _qIdx=0; _gameOver=false; _shuffled=List.from(_questions)..shuffle(_rng); }); _startTimer(); })
    : Padding(padding: const EdgeInsets.fromLTRB(24,16,24,24), child:Column(children:[
        _handle(), const SizedBox(height:20),
        Row(mainAxisAlignment:MainAxisAlignment.spaceBetween, children:[
          _badge('⏱','$_timeLeft s', _timeLeft<15?Colors.redAccent:Colors.white60),
          _badge('✅','$_score corrects', Colors.amber),
        ]),
        const SizedBox(height:10),
        _timerBar(_timeLeft/60, _timeLeft<15, const Color(0xFFBE185D)),
        const Spacer(),
        if (_feedback!=null)
          Text(_feedback!, style:const TextStyle(color:Colors.white,fontSize:18,fontWeight:FontWeight.bold), textAlign:TextAlign.center)
        else ...[
          Text(_q.question, style:const TextStyle(color:Colors.white70,fontSize:16), textAlign:TextAlign.center),
          const SizedBox(height:8),
          const Text('Quel mot est correctement orthographié ?',
            style:TextStyle(color:Colors.white38,fontSize:12), textAlign:TextAlign.center),
        ],
        const Spacer(),
        ...List.generate(_q.choices.length,(i)=>Container(
          width:double.infinity, margin:const EdgeInsets.only(bottom:10),
          child:Material(color:const Color(0xFF1C2128), borderRadius:BorderRadius.circular(14),
            child:InkWell(borderRadius:BorderRadius.circular(14), onTap:()=>_ans(i),
              child:Padding(padding:const EdgeInsets.symmetric(vertical:14,horizontal:16),
                child:Text(_q.choices[i], style:const TextStyle(color:Colors.white,fontSize:16,fontWeight:FontWeight.bold),
                  textAlign:TextAlign.center)))),
        )),
      ])),
  );
}

class _OrthoQ {
  final String question;
  final List<String> choices;
  final int correct;
  const _OrthoQ(this.question, this.choices, this.correct);
}

// ─── 6. Vocabulaire ───────────────────────────────────────────────────────────

class _VocabulaireGame extends StatefulWidget {
  const _VocabulaireGame();
  @override
  State<_VocabulaireGame> createState() => _VocabulaireGameState();
}

class _VocabulaireGameState extends State<_VocabulaireGame> {
  static const _questions = [
    _VocabQ('Synonyme de "rapide"', ['lent', 'vite', 'grand', 'lourd'], 1),
    _VocabQ('Synonyme de "content"', ['triste', 'fatigué', 'heureux', 'méchant'], 2),
    _VocabQ('Antonyme de "chaud"', ['tiède', 'brûlant', 'froid', 'doux'], 2),
    _VocabQ('Synonyme de "courageux"', ['peureux', 'brave', 'timide', 'calme'], 1),
    _VocabQ('Signification de "aurora"', ['coucher du soleil', 'pluie', 'lever du soleil', 'vent'], 2),
    _VocabQ('Antonyme de "grand"', ['maigre', 'gros', 'petit', 'fort'], 2),
    _VocabQ('Synonyme de "chercher"', ['trouver', 'fuir', 'quérir', 'donner'], 2),
    _VocabQ('Signification de "aride"', ['humide', 'sec', 'froid', 'chaud'], 1),
    _VocabQ('Synonyme de "fatigué"', ['reposé', 'alerte', 'épuisé', 'fort'], 2),
    _VocabQ('Antonyme de "monter"', ['avancer', 'descendre', 'tourner', 'marcher'], 1),
  ];

  final _rng = Random();
  int _score=0, _timeLeft=90, _qIdx=0;
  Timer? _timer;
  late List<_VocabQ> _shuffled;
  String? _feedback;
  bool _gameOver=false;

  @override
  void initState() {
    super.initState();
    _shuffled=List.from(_questions)..shuffle(_rng);
    _startTimer();
  }

  void _startTimer() {
    _timer=Timer.periodic(const Duration(seconds:1),(t) {
      if (!mounted) { t.cancel(); return; }
      setState(() { if (_timeLeft>0) _timeLeft--; else { _gameOver=true; t.cancel(); XpService.gainXP(_score*10); } });
    });
  }

  _VocabQ get _q => _shuffled[_qIdx % _shuffled.length];

  void _ans(int idx) {
    if (_gameOver||_feedback!=null) return;
    HapticFeedback.selectionClick();
    final ok=idx==_q.correct; if (!ok) HapticFeedback.vibrate();
    setState(() { if (ok) _score++; _feedback=ok?'✅ Correct !':'❌ → ${_q.choices[_q.correct]}'; });
    Future.delayed(const Duration(milliseconds:900), () {
      if (mounted&&!_gameOver) setState(() { _qIdx++; _feedback=null; });
    });
  }

  @override
  void dispose() { _timer?.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) => _gameSheet(context,
    _gameOver ? _resultBody(context,'📝','$_score bonnes définitions',_score*10,
      () { _timer?.cancel(); setState(() { _score=0; _timeLeft=90; _qIdx=0; _gameOver=false; _shuffled=List.from(_questions)..shuffle(_rng); }); _startTimer(); })
    : Padding(padding: const EdgeInsets.fromLTRB(24,16,24,24), child:Column(children:[
        _handle(), const SizedBox(height:20),
        Row(mainAxisAlignment:MainAxisAlignment.spaceBetween, children:[
          _badge('⏱','$_timeLeft s', _timeLeft<20?Colors.redAccent:Colors.white60),
          _badge('📝','$_score corrects', Colors.amber),
        ]),
        const SizedBox(height:10),
        _timerBar(_timeLeft/90, _timeLeft<20, const Color(0xFFD97706)),
        const Spacer(),
        if (_feedback!=null)
          Text(_feedback!, style:const TextStyle(color:Colors.white,fontSize:18), textAlign:TextAlign.center)
        else
          Text(_q.question, style:const TextStyle(color:Colors.white,fontSize:20,fontWeight:FontWeight.bold), textAlign:TextAlign.center),
        const Spacer(),
        ...List.generate(_q.choices.length,(i)=>Container(
          width:double.infinity, margin:const EdgeInsets.only(bottom:10),
          child:Material(color:const Color(0xFF1C2128), borderRadius:BorderRadius.circular(14),
            child:InkWell(borderRadius:BorderRadius.circular(14), onTap:()=>_ans(i),
              child:Padding(padding:const EdgeInsets.symmetric(vertical:14,horizontal:16),
                child:Text(_q.choices[i], style:const TextStyle(color:Colors.white,fontSize:16),
                  textAlign:TextAlign.center)))),
        )),
      ])),
  );
}

class _VocabQ {
  final String question;
  final List<String> choices;
  final int correct;
  const _VocabQ(this.question, this.choices, this.correct);
}

// ─── 7. Mémoire Visuelle ──────────────────────────────────────────────────────

class _MemoireVisuelle extends StatefulWidget {
  const _MemoireVisuelle();
  @override
  State<_MemoireVisuelle> createState() => _MemoireVisuelleState();
}

class _MemoireVisuelleState extends State<_MemoireVisuelle> {
  static const _colors = [
    Colors.red, Colors.blue, Colors.green, Colors.yellow,
    Colors.purple, Colors.orange,
  ];
  static const _emojis = ['🔴','🔵','🟢','🟡','🟣','🟠'];

  final _rng = Random();
  List<int> _sequence = [];
  List<int> _userInput = [];
  int _round = 1;
  int _score = 0;
  bool _showing = false;
  bool _gameOver = false;
  int _showIdx = -1;

  @override
  void initState() { super.initState(); _nextRound(); }

  void _nextRound() async {
    _sequence = List.generate(_round + 2, (_) => _rng.nextInt(6));
    _userInput = [];
    await Future.delayed(const Duration(milliseconds: 800));
    await _showSequence();
  }

  Future<void> _showSequence() async {
    if (!mounted) return;
    setState(() => _showing = true);
    for (int i = 0; i < _sequence.length; i++) {
      if (!mounted) return;
      setState(() => _showIdx = _sequence[i]);
      await Future.delayed(const Duration(milliseconds: 600));
      if (!mounted) return;
      setState(() => _showIdx = -1);
      await Future.delayed(const Duration(milliseconds: 300));
    }
    if (mounted) setState(() { _showing = false; _showIdx = -1; });
  }

  void _onTap(int idx) {
    if (_showing || _gameOver) return;
    HapticFeedback.selectionClick();
    setState(() => _userInput.add(idx));
    final pos = _userInput.length - 1;
    if (_userInput[pos] != _sequence[pos]) {
      HapticFeedback.vibrate();
      setState(() => _gameOver = true);
      XpService.gainXP(_score * 10);
      return;
    }
    if (_userInput.length == _sequence.length) {
      setState(() { _score++; _round++; });
      _nextRound();
    }
  }

  @override
  Widget build(BuildContext context) => _gameSheet(context,
    _gameOver ? _resultBody(context,'🧠','$_score séquences mémorisées',_score*10,
      () => setState(() { _sequence=[]; _userInput=[]; _round=1; _score=0; _showing=false; _gameOver=false; _showIdx=-1; _nextRound(); }))
    : Padding(padding: const EdgeInsets.fromLTRB(24,16,24,24), child:Column(children:[
        _handle(), const SizedBox(height:20),
        Row(mainAxisAlignment:MainAxisAlignment.spaceBetween, children:[
          _badge('🧠','Séquence $_round', Colors.white60),
          _badge('✅','$_score réussis', Colors.amber),
        ]),
        const SizedBox(height:16),
        Text(_showing ? 'Mémorise !' : (_userInput.isEmpty ? 'Reproduis la séquence' : 'Continue...'),
          style:const TextStyle(color:Colors.white70, fontSize:14), textAlign:TextAlign.center),
        const SizedBox(height:8),
        Text('${_userInput.length} / ${_sequence.length}',
          style:const TextStyle(color:Colors.white38, fontSize:12)),
        const Spacer(),
        GridView.count(
          shrinkWrap:true, crossAxisCount:3, crossAxisSpacing:12, mainAxisSpacing:12,
          children:List.generate(6,(i)=>GestureDetector(
            onTap:()=>_onTap(i),
            child:AnimatedContainer(
              duration:const Duration(milliseconds:150),
              decoration:BoxDecoration(
                color:_showIdx==i ? _colors[i] : _colors[i].withValues(alpha:0.25),
                borderRadius:BorderRadius.circular(16),
                boxShadow:_showIdx==i ? [BoxShadow(color:_colors[i].withValues(alpha:0.6),blurRadius:12)] : [],
              ),
              child:Center(child:Text(_emojis[i], style:const TextStyle(fontSize:32))),
            ),
          )),
        ),
        const Spacer(),
      ])),
  );
}

// ─── 8. Puzzle Logique ────────────────────────────────────────────────────────

class _PuzzleLogique extends StatefulWidget {
  const _PuzzleLogique();
  @override
  State<_PuzzleLogique> createState() => _PuzzleLogiqueState();
}

class _PuzzleLogiqueState extends State<_PuzzleLogique> {
  static const _puzzles = [
    _Puzzle('2, 4, 6, 8, ?', ['9','10','11','12'], 1),
    _Puzzle('1, 3, 6, 10, ?', ['13','14','15','16'], 2),
    _Puzzle('2, 4, 8, 16, ?', ['24','30','32','28'], 2),
    _Puzzle('5, 10, 20, 40, ?', ['60','80','75','70'], 1),
    _Puzzle('1, 1, 2, 3, 5, ?', ['7','8','9','6'], 1),
    _Puzzle('100, 50, 25, ?', ['10','12','12.5','13'], 2),
    _Puzzle('3, 6, 12, 24, ?', ['36','48','42','50'], 1),
    _Puzzle('0, 1, 4, 9, ?', ['12','16','14','15'], 1),
    _Puzzle('7, 14, 21, 28, ?', ['32','33','35','36'], 2),
    _Puzzle('1, 8, 27, 64, ?', ['100','125','128','216'], 1),
  ];

  final _rng = Random();
  int _score=0, _timeLeft=120, _qIdx=0;
  Timer? _timer;
  late List<_Puzzle> _shuffled;
  String? _feedback;
  bool _gameOver=false;

  @override
  void initState() {
    super.initState();
    _shuffled=List.from(_puzzles)..shuffle(_rng);
    _startTimer();
  }

  void _startTimer() {
    _timer=Timer.periodic(const Duration(seconds:1),(t) {
      if (!mounted) { t.cancel(); return; }
      setState(() { if (_timeLeft>0) _timeLeft--; else { _gameOver=true; t.cancel(); XpService.gainXP(_score*10); } });
    });
  }

  _Puzzle get _q => _shuffled[_qIdx % _shuffled.length];

  void _ans(int idx) {
    if (_gameOver||_feedback!=null) return;
    HapticFeedback.selectionClick();
    final ok=idx==_q.correct; if (!ok) HapticFeedback.vibrate();
    setState(() { if (ok) _score++; _feedback=ok?'✅ Bravo !':'❌ → ${_q.choices[_q.correct]}'; });
    Future.delayed(const Duration(milliseconds:900), () {
      if (mounted&&!_gameOver) setState(() { _qIdx++; _feedback=null; });
    });
  }

  @override
  void dispose() { _timer?.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) => _gameSheet(context,
    _gameOver ? _resultBody(context,'🧩','$_score suites trouvées',_score*10,
      () { _timer?.cancel(); setState(() { _score=0; _timeLeft=120; _qIdx=0; _gameOver=false; _shuffled=List.from(_puzzles)..shuffle(_rng); }); _startTimer(); })
    : Padding(padding: const EdgeInsets.fromLTRB(24,16,24,24), child:Column(children:[
        _handle(), const SizedBox(height:20),
        Row(mainAxisAlignment:MainAxisAlignment.spaceBetween, children:[
          _badge('⏱','$_timeLeft s', _timeLeft<30?Colors.redAccent:Colors.white60),
          _badge('🧩','$_score trouvés', Colors.amber),
        ]),
        const SizedBox(height:10),
        _timerBar(_timeLeft/120, _timeLeft<30, const Color(0xFF0F766E)),
        const Spacer(),
        if (_feedback!=null)
          Text(_feedback!, style:const TextStyle(color:Colors.white,fontSize:18), textAlign:TextAlign.center)
        else ...[
          const Text('Quelle est la suite ?', style:TextStyle(color:Colors.white54,fontSize:13)),
          const SizedBox(height:8),
          Text(_q.sequence, style:const TextStyle(color:Colors.white,fontSize:28,fontWeight:FontWeight.bold,letterSpacing:2)),
        ],
        const Spacer(),
        GridView.count(
          shrinkWrap:true, crossAxisCount:2, crossAxisSpacing:12, mainAxisSpacing:12, childAspectRatio:2.5,
          children:List.generate(_q.choices.length,(i)=>Material(
            color:const Color(0xFF1C2128), borderRadius:BorderRadius.circular(14),
            child:InkWell(borderRadius:BorderRadius.circular(14), onTap:()=>_ans(i),
              child:Center(child:Text(_q.choices[i], style:const TextStyle(color:Colors.white,fontSize:20,fontWeight:FontWeight.bold)))),
          )),
        ),
        const SizedBox(height:8),
      ])),
  );
}

class _Puzzle {
  final String sequence;
  final List<String> choices;
  final int correct;
  const _Puzzle(this.sequence, this.choices, this.correct);
}

// ═══════════════════════════════════════════════════════════════════════════════
//  SHARED HELPERS
// ═══════════════════════════════════════════════════════════════════════════════

Widget _gameSheet(BuildContext context, Widget child) => Container(
  height: MediaQuery.of(context).size.height * 0.88,
  decoration: const BoxDecoration(
    color: Color(0xFF161B22),
    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
  ),
  child: child,
);

Widget _resultBody(BuildContext context, String emoji, String label, int xp, VoidCallback onReplay) =>
  Padding(padding: const EdgeInsets.all(32), child: Column(mainAxisAlignment:MainAxisAlignment.center, children:[
    Text(emoji, style:const TextStyle(fontSize:64)),
    const SizedBox(height:16),
    Text(label, style:const TextStyle(color:Colors.white,fontSize:24,fontWeight:FontWeight.bold), textAlign:TextAlign.center),
    const SizedBox(height:8),
    Text('+$xp XP gagnés', style:const TextStyle(color:Colors.amber,fontSize:20)),
    const SizedBox(height:32),
    SizedBox(width:double.infinity, child:ElevatedButton(
      style:ElevatedButton.styleFrom(backgroundColor:const Color(0xFF6C47FF), padding:const EdgeInsets.symmetric(vertical:16),
        shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(14))),
      onPressed:onReplay,
      child:const Text('Rejouer', style:TextStyle(fontSize:16,color:Colors.white)),
    )),
    const SizedBox(height:12),
    TextButton(onPressed:()=>Navigator.pop(context), child:const Text('Fermer',style:TextStyle(color:Colors.white54))),
  ]));

Widget _handle() => Center(child:Container(
  width:40, height:4,
  decoration:BoxDecoration(color:Colors.white24, borderRadius:BorderRadius.circular(2)),
));

Widget _badge(String emoji, String text, Color color) => Container(
  padding:const EdgeInsets.symmetric(horizontal:12,vertical:6),
  decoration:BoxDecoration(color:Colors.white.withValues(alpha:0.05), borderRadius:BorderRadius.circular(12)),
  child:Row(mainAxisSize:MainAxisSize.min, children:[
    Text(emoji), const SizedBox(width:4),
    Text(text, style:TextStyle(color:color, fontWeight:FontWeight.bold)),
  ]),
);

Widget _timerBar(double value, bool danger, Color color) => ClipRRect(
  borderRadius:BorderRadius.circular(4),
  child:LinearProgressIndicator(
    value:value.clamp(0.0,1.0),
    backgroundColor:Colors.white12,
    valueColor:AlwaysStoppedAnimation<Color>(danger ? Colors.redAccent : color),
    minHeight:6,
  ),
);

Widget _choiceGrid(List<int> choices, void Function(int) onAnswer) => GridView.count(
  shrinkWrap:true, crossAxisCount:2, crossAxisSpacing:12, mainAxisSpacing:12, childAspectRatio:2.5,
  children:choices.map((c)=>Material(
    color:const Color(0xFF1C2128), borderRadius:BorderRadius.circular(14),
    child:InkWell(borderRadius:BorderRadius.circular(14), onTap:()=>onAnswer(c),
      child:Center(child:Text('$c', style:const TextStyle(color:Colors.white,fontSize:24,fontWeight:FontWeight.bold)))),
  )).toList(),
);
