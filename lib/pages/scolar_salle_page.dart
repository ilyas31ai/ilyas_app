import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/user_avatar.dart';
import 'scolar_chat_room_page.dart';

// ─── Constants ───────────────────────────────────────────────────────────────
const _ssBg = Color(0xFF0D1117);
const _ssCard = Color(0xFF161B22);
const _ssCard2 = Color(0xFF1F2937);
const _ssBorder = Color(0xFF21262D);
const _ssBlue = Color(0xFF2563EB);
const _ssPurple = Color(0xFF6C47FF);

// ─── Page ─────────────────────────────────────────────────────────────────────

class SCOLARSallePage extends StatefulWidget {
  final String salleNom;
  final String matiere;

  const SCOLARSallePage({
    super.key,
    required this.salleNom,
    required this.matiere,
  });

  @override
  State<SCOLARSallePage> createState() => _SCOLARSallePageState();
}

class _SCOLARSallePageState extends State<SCOLARSallePage>
    with TickerProviderStateMixin {
  late final TabController _tabs;

  // Pomodoro state
  static const int _workMinutes = 25;
  static const int _breakMinutes = 5;
  Timer? _pomTimer;
  int _secondsLeft = _workMinutes * 60;
  bool _isWorking = true;
  bool _running = false;
  int _sessionCount = 0;

  // Notes state
  final _notesCtrl = TextEditingController();
  bool _notesSaving = false;
  String _notesSavedAt = '';

  // Chat
  String get _me => FirebaseAuth.instance.currentUser?.email ?? '';

  final _fs = FirebaseFirestore.instance;

  // Static participants
  final List<String> _participants = [];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
    _loadNotes();
    _participants.add(_me);
  }

  @override
  void dispose() {
    _pomTimer?.cancel();
    _tabs.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  // ── Pomodoro ─────────────────────────────────────────────────────────────

  void _startPom() {
    _pomTimer?.cancel();
    setState(() => _running = true);
    _pomTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        if (_secondsLeft > 0) {
          _secondsLeft--;
        } else {
          _pomTimer?.cancel();
          _running = false;
          if (_isWorking) {
            _sessionCount++;
            _isWorking = false;
            _secondsLeft = _breakMinutes * 60;
          } else {
            _isWorking = true;
            _secondsLeft = _workMinutes * 60;
          }
        }
      });
    });
  }

  void _pausePom() {
    _pomTimer?.cancel();
    setState(() => _running = false);
  }

  void _resetPom() {
    _pomTimer?.cancel();
    setState(() {
      _running = false;
      _isWorking = true;
      _secondsLeft = _workMinutes * 60;
    });
  }

  String get _pomLabel {
    final m = _secondsLeft ~/ 60;
    final s = _secondsLeft % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  double get _pomProgress {
    final total = _isWorking ? _workMinutes * 60 : _breakMinutes * 60;
    return 1.0 - (_secondsLeft / total);
  }

  // ── Notes ─────────────────────────────────────────────────────────────────

  Future<void> _loadNotes() async {
    try {
      final doc = await _fs
          .collection('scolar_salles')
          .doc(widget.salleNom)
          .get();
      if (doc.exists && mounted) {
        _notesCtrl.text = doc.data()?['notes'] as String? ?? '';
      }
    } catch (_) {}
  }

  Future<void> _saveNotes() async {
    setState(() => _notesSaving = true);
    try {
      await _fs.collection('scolar_salles').doc(widget.salleNom).set({
        'notes': _notesCtrl.text,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': _me,
      }, SetOptions(merge: true));
      if (mounted) {
        final now = DateTime.now();
        setState(() {
          _notesSavedAt =
              'Sauvegardé à ${now.hour}:${now.minute.toString().padLeft(2, '0')}';
          _notesSaving = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _notesSaving = false);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _ssBg,
      appBar: AppBar(
        backgroundColor: _ssCard,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.salleNom,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.bold),
            ),
            if (widget.matiere.isNotEmpty)
              Text(widget.matiere,
                  style: const TextStyle(
                      color: Colors.white38, fontSize: 11)),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 14),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.greenAccent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: Colors.greenAccent.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                      color: Colors.greenAccent, shape: BoxShape.circle),
                ),
                const SizedBox(width: 5),
                Text(
                  '${_participants.length} en ligne',
                  style: const TextStyle(
                      color: Colors.greenAccent,
                      fontSize: 11,
                      fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: _ssPurple,
          indicatorWeight: 2,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white38,
          labelStyle:
              const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          tabs: const [
            Tab(icon: Icon(Icons.timer_outlined, size: 16), text: 'Pomodoro'),
            Tab(icon: Icon(Icons.edit_note, size: 16), text: 'Notes'),
            Tab(
                icon: Icon(Icons.people_outline, size: 16),
                text: 'Participants'),
            Tab(
                icon: Icon(Icons.chat_bubble_outline, size: 16),
                text: 'Chat'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _buildPomodoroTab(),
          _buildNotesTab(),
          _buildParticipantsTab(),
          _buildChatTab(),
        ],
      ),
    );
  }

  // ── Tab Pomodoro ──────────────────────────────────────────────────────────

  Widget _buildPomodoroTab() {
    final quotes = [
      'La concentration est la clé du succès.',
      'Chaque minute de concentration compte.',
      'Travailler avec méthode, c\'est travailler moins pour plus de résultats.',
      'La régularité bat le talent.',
    ];
    final quoteIdx = (_sessionCount) % quotes.length;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
      child: Column(
        children: [
          // Session label
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: (_isWorking ? _ssPurple : const Color(0xFF16A34A))
                  .withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: (_isWorking ? _ssPurple : const Color(0xFF16A34A))
                    .withValues(alpha: 0.4),
              ),
            ),
            child: Text(
              _isWorking ? 'Session de travail' : 'Pause 🌿',
              style: TextStyle(
                  color:
                      _isWorking ? _ssPurple : const Color(0xFF16A34A),
                  fontSize: 13,
                  fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 32),

          // Circular timer
          SizedBox(
            width: 220,
            height: 220,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 220,
                  height: 220,
                  child: CircularProgressIndicator(
                    value: _pomProgress,
                    strokeWidth: 10,
                    backgroundColor: _ssCard2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                        _isWorking ? _ssPurple : const Color(0xFF16A34A)),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _pomLabel,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 52,
                        fontWeight: FontWeight.bold,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                    Text(
                      '$_sessionCount session${_sessionCount > 1 ? 's' : ''} complétée${_sessionCount > 1 ? 's' : ''}',
                      style: const TextStyle(
                          color: Colors.white38, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Control buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _PomBtn(
                icon: Icons.refresh,
                label: 'Reset',
                color: Colors.white38,
                onTap: _resetPom,
              ),
              const SizedBox(width: 16),
              _PomBtn(
                icon: _running ? Icons.pause_rounded : Icons.play_arrow_rounded,
                label: _running ? 'Pause' : 'Démarrer',
                color: _ssPurple,
                large: true,
                onTap: _running ? _pausePom : _startPom,
              ),
              const SizedBox(width: 16),
              _PomBtn(
                icon: Icons.skip_next_rounded,
                label: 'Skip',
                color: Colors.white38,
                onTap: () {
                  _pomTimer?.cancel();
                  setState(() {
                    _running = false;
                    if (_isWorking) {
                      _sessionCount++;
                      _isWorking = false;
                      _secondsLeft = _breakMinutes * 60;
                    } else {
                      _isWorking = true;
                      _secondsLeft = _workMinutes * 60;
                    }
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 32),

          // Motivational quote
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _ssCard,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _ssBorder),
            ),
            child: Row(
              children: [
                const Icon(Icons.format_quote,
                    color: _ssPurple, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    quotes[quoteIdx],
                    style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                        height: 1.5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Tab Notes ─────────────────────────────────────────────────────────────

  Widget _buildNotesTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Notes collaboratives',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600)),
              const Spacer(),
              if (_notesSaving)
                const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: _ssPurple))
              else if (_notesSavedAt.isNotEmpty)
                Text(_notesSavedAt,
                    style: const TextStyle(
                        color: Colors.white38, fontSize: 11)),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: _ssCard,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _ssBorder),
              ),
              child: TextField(
                controller: _notesCtrl,
                maxLines: null,
                expands: true,
                style: const TextStyle(
                    color: Colors.white, fontSize: 14, height: 1.6),
                decoration: const InputDecoration(
                  hintText: 'Écrivez vos notes ici…',
                  hintStyle: TextStyle(color: Colors.white24),
                  contentPadding: EdgeInsets.all(14),
                  border: InputBorder.none,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _saveNotes,
              icon: const Icon(Icons.save_outlined, size: 18),
              label: const Text('Sauvegarder'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _ssPurple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Tab Participants ──────────────────────────────────────────────────────

  Widget _buildParticipantsTab() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _ssCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _ssBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.people_outline,
                      color: _ssPurple, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    '${_participants.length} participant${_participants.length > 1 ? 's' : ''}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ..._participants.map((email) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        UserAvatar(
                            username: email,
                            radius: 20,
                            showStatus: true),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            email.contains('@')
                                ? email.split('@').first
                                : email,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 13),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.greenAccent
                                .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text('En ligne',
                              style: TextStyle(
                                  color: Colors.greenAccent,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  )),
            ],
          ),
        ),
      ],
    );
  }

  // ── Tab Chat ──────────────────────────────────────────────────────────────

  Widget _buildChatTab() {
    return SCOLARChatRoomPage(
      name: 'salle_${widget.salleNom}',
      user: _me,
      displayName: widget.salleNom,
    );
  }
}

// ─── Widgets helpers ──────────────────────────────────────────────────────────

class _PomBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool large;
  final VoidCallback onTap;

  const _PomBtn({
    required this.icon,
    required this.label,
    required this.color,
    this.large = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final size = large ? 68.0 : 52.0;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              gradient: large
                  ? const LinearGradient(
                      colors: [_ssPurple, _ssBlue])
                  : null,
              color: large ? null : _ssCard,
              shape: BoxShape.circle,
              border: Border.all(
                  color: large ? Colors.transparent : _ssBorder),
            ),
            child: Icon(icon,
                color: large ? Colors.white : color,
                size: large ? 30 : 22),
          ),
          const SizedBox(height: 6),
          Text(label,
              style: TextStyle(
                  color: color, fontSize: 11, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
