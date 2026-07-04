import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:firebase_database/firebase_database.dart' hide Query;
import '../services/social_service.dart';
import '../services/storage_service.dart';
import '../services/user_service.dart';
import '../widgets/user_avatar.dart';

// Remplace discussion_page.dart — même API, design entièrement nouveau.
class SCOLARChatRoomPage extends StatefulWidget {
  final String name;
  final String user;
  final String? displayName;

  const SCOLARChatRoomPage({
    super.key,
    required this.name,
    required this.user,
    this.displayName,
  });

  @override
  State<SCOLARChatRoomPage> createState() => _SCOLARChatRoomPageState();
}

class _SCOLARChatRoomPageState extends State<SCOLARChatRoomPage> {
  final _textCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _sending = false;
  bool _blocked = false;
  bool _showScrollBtn = false;
  String? _myDisplayName;
  late final Stream<List<Map<String, dynamic>>> _messagesStream;

  // ── Typing indicator ──────────────────────────────────────────────────────
  bool _isTyping = false;
  Timer? _typingDebounce;
  late final Stream<DatabaseEvent> _typingStream;

  // ── Reply ─────────────────────────────────────────────────────────────────
  Map<String, dynamic>? _replyToMsg;

  // ── File sharing ──────────────────────────────────────────────────────────
  bool _uploadingFile = false;

  // ── Voice recording ───────────────────────────────────────────────────────
  bool _isRecording = false;
  bool _recordingCancelled = false;
  final AudioRecorder _recorder = AudioRecorder();
  String? _currentRecordingPath;
  Timer? _recordTimer;
  int _recordSeconds = 0;

  // ── Audio playback (one player per message, keyed by audioUrl) ────────────
  final Map<String, AudioPlayer> _audioPlayers = {};
  final Map<String, bool> _audioPlaying = {};
  final Map<String, Duration> _audioDurations = {};
  final Map<String, Duration> _audioPositions = {};

  String get _chatId => SocialService.chatId(widget.user, widget.name);
  bool get _isGroup =>
      widget.name == 'general' || widget.name == 'Classe';
  String get _label =>
      (widget.displayName != null && widget.displayName!.isNotEmpty)
          ? widget.displayName!
          : widget.name;

  @override
  void initState() {
    super.initState();
    _messagesStream = SocialService.messagesStream(_chatId);
    _typingStream = FirebaseDatabase.instance
        .ref('typing/$_chatId')
        .onValue;
    _init();
    _scrollCtrl.addListener(_onScroll);
    _textCtrl.addListener(_onTextChanged);
    UserService.currentUserStream().first.then((u) {
      if (mounted && u != null && u.displayName.isNotEmpty) {
        _myDisplayName = u.displayName;
      }
    });
  }

  @override
  void dispose() {
    _typingDebounce?.cancel();
    _clearTyping();
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    _recorder.dispose();
    for (final p in _audioPlayers.values) {
      p.dispose();
    }
    _recordTimer?.cancel();
    super.dispose();
  }

  void _onTextChanged() {
    if (_textCtrl.text.isNotEmpty) {
      if (!_isTyping) {
        _isTyping = true;
        _writeTyping(true);
      }
      _typingDebounce?.cancel();
      _typingDebounce = Timer(const Duration(milliseconds: 1500), () {
        _isTyping = false;
        _clearTyping();
      });
    } else {
      _typingDebounce?.cancel();
      _isTyping = false;
      _clearTyping();
    }
  }

  void _writeTyping(bool typing) {
    final k = SocialService.encodeKey(widget.user);
    if (typing) {
      FirebaseDatabase.instance
          .ref('typing/$_chatId/$k')
          .set(DateTime.now().millisecondsSinceEpoch);
    } else {
      FirebaseDatabase.instance.ref('typing/$_chatId/$k').remove();
    }
  }

  void _clearTyping() {
    final k = SocialService.encodeKey(widget.user);
    FirebaseDatabase.instance.ref('typing/$_chatId/$k').remove();
  }

  Future<void> _init() async {
    if (!_isGroup) {
      _blocked = await SocialService.isBlocked(widget.user, widget.name);
      if (mounted) setState(() {});
    }
    await Future.delayed(const Duration(milliseconds: 400));
    if (mounted) await SocialService.markSeen(_chatId, widget.user);
  }

  void _onScroll() {
    final atBottom = _scrollCtrl.hasClients &&
        _scrollCtrl.position.pixels >=
            _scrollCtrl.position.maxScrollExtent - 80;
    if (atBottom != !_showScrollBtn) {
      setState(() => _showScrollBtn = !atBottom);
    }
  }

  void _scrollToBottom({bool animated = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollCtrl.hasClients) return;
      if (animated) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      } else {
        _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
      }
    });
  }

  Future<void> _send() async {
    if (_sending || _blocked) return;
    final text = _textCtrl.text.trim();
    if (text.isEmpty) return;
    _textCtrl.clear();
    _typingDebounce?.cancel();
    _isTyping = false;
    _clearTyping();
    final reply = _replyToMsg;
    if (mounted) setState(() { _sending = true; _replyToMsg = null; });
    await SocialService.sendMessage(
      chatIdStr: _chatId,
      sender: widget.user,
      toUser: widget.name,
      text: text,
      senderDisplayName: _myDisplayName,
      replyTo: reply != null
          ? {
              'sender': reply['sender'] as String? ?? '',
              'text': (reply['text'] as String? ?? '').length > 60
                  ? '${(reply['text'] as String).substring(0, 60)}…'
                  : reply['text'] as String? ?? '',
            }
          : null,
    );
    if (mounted) setState(() => _sending = false);
    _scrollToBottom();
  }

  Future<void> _blockUser() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1F2937),
        title: const Text('Bloquer ?', style: TextStyle(color: Colors.white)),
        content: Text(
          'Bloquer $_label ? Vous ne recevrez plus ses messages.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler',
                style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Bloquer',
                style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      await SocialService.blockUser(widget.user, widget.name);
      setState(() => _blocked = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: _buildAppBar(),
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(child: _buildMessages()),
              _buildTypingIndicator(),
              if (_blocked) _buildBlockedBanner(),
              if (_replyToMsg != null) _buildReplyPreview(),
              _buildInput(),
            ],
          ),
          if (_showScrollBtn)
            Positioned(
              bottom: 80,
              right: 14,
              child: GestureDetector(
                onTap: () => _scrollToBottom(),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF6C47FF), Color(0xFF2563EB)],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.keyboard_arrow_down,
                      color: Colors.white, size: 22),
                ),
              ),
            ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1A1040), Color(0xFF161B22)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      ),
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      titleSpacing: 0,
      title: Row(
        children: [
          _isGroup
              ? Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6C47FF), Color(0xFF2563EB)],
                    ),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: const Icon(Icons.groups, color: Colors.white, size: 22),
                )
              : UserAvatar(
                  username: widget.name, radius: 20, showStatus: true),
          const SizedBox(width: 10),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isGroup
                      ? (widget.name == 'general'
                          ? 'Canal Général'
                          : 'Canal de Classe')
                      : _label,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
                if (!_isGroup)
                  OnlineLabel(username: widget.name)
                else
                  const Text('SCOLAR AI Educative',
                      style: TextStyle(color: Colors.white38, fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
      actions: [
        if (!_isGroup)
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white54),
            color: const Color(0xFF1F2937),
            onSelected: (v) {
              if (v == 'block') _blockUser();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'block',
                child: Row(children: [
                  Icon(Icons.block, color: Colors.redAccent, size: 18),
                  SizedBox(width: 10),
                  Text('Bloquer',
                      style: TextStyle(color: Colors.redAccent)),
                ]),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildMessages() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _messagesStream,
      builder: (context, snap) {
        final msgs = snap.data ?? [];
        if (msgs.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6C47FF), Color(0xFF2563EB)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(Icons.chat_bubble_outline,
                      color: Colors.white54, size: 36),
                ),
                const SizedBox(height: 18),
                const Text('Démarrez la conversation',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Text(
                  _isGroup
                      ? 'Partagez avec le groupe !'
                      : 'Premier message à $_label…',
                  style:
                      const TextStyle(color: Colors.white38, fontSize: 13),
                ),
              ],
            ),
          );
        }
        WidgetsBinding.instance
            .addPostFrameCallback((_) => _scrollToBottom(animated: false));
        return ListView.builder(
          controller: _scrollCtrl,
          padding:
              const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
          itemCount: msgs.length,
          itemBuilder: (_, i) {
            final msg = msgs[i];
            final isMe = msg['sender'] == widget.user;
            final showDate = i == 0 ||
                _dayOf(msgs[i]['time']) != _dayOf(msgs[i - 1]['time']);
            return Column(children: [
              if (showDate) _buildDateChip(msg['time'] as int? ?? 0),
              _MessageBubble(
                msg: msg,
                isMe: isMe,
                isGroup: _isGroup,
                chatId: _chatId,
                onReply: (m) => setState(() => _replyToMsg = m),
                isAudioPlaying: (url) => _audioPlaying[url] == true,
                audioPosition: (url) =>
                    _audioPositions[url] ?? Duration.zero,
                audioDuration: (url) => _audioDurations[url],
                onToggleAudio: (url) { _toggleAudio(url); },
              ),
            ]);
          },
        );
      },
    );
  }

  Widget _buildTypingIndicator() {
    return StreamBuilder<DatabaseEvent>(
      stream: _typingStream,
      builder: (context, snap) {
        if (!snap.hasData || snap.data!.snapshot.value == null) {
          return const SizedBox.shrink();
        }
        final raw =
            Map<dynamic, dynamic>.from(snap.data!.snapshot.value as Map);
        final myKey = SocialService.encodeKey(widget.user);
        final now = DateTime.now().millisecondsSinceEpoch;
        // Find other users typing (activity within last 3 seconds)
        final typingUsers = raw.entries.where((e) {
          if (e.key.toString() == myKey) return false;
          final ts = e.value as int? ?? 0;
          return (now - ts) < 3000;
        }).map((e) => SocialService.decodeKey(e.key.toString())).toList();

        if (typingUsers.isEmpty) return const SizedBox.shrink();

        final name = typingUsers.first.contains('@')
            ? typingUsers.first.split('@').first
            : typingUsers.first;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            children: [
              const SizedBox(width: 44),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF1F2937),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(18),
                    topRight: Radius.circular(18),
                    bottomLeft: Radius.circular(4),
                    bottomRight: Radius.circular(18),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$name est en train d\'écrire',
                      style: const TextStyle(
                          color: Colors.white54, fontSize: 12),
                    ),
                    const SizedBox(width: 6),
                    const _TypingDots(),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildReplyPreview() {
    final reply = _replyToMsg;
    if (reply == null) return const SizedBox.shrink();
    final sender = reply['sender'] as String? ?? '';
    final text = reply['text'] as String? ?? '';
    final name = sender.contains('@') ? sender.split('@').first : sender;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const BoxDecoration(
        color: Color(0xFF1F2937),
        border: Border(
            top: BorderSide(color: Color(0xFF21262D)),
            left: BorderSide(color: Color(0xFF6C47FF), width: 3)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Répondre à $name',
                  style: const TextStyle(
                      color: Color(0xFF6C47FF),
                      fontSize: 11,
                      fontWeight: FontWeight.bold),
                ),
                Text(
                  text.length > 80 ? '${text.substring(0, 80)}…' : text,
                  style: const TextStyle(
                      color: Colors.white54, fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => _replyToMsg = null),
            child: const Icon(Icons.close,
                color: Colors.white38, size: 18),
          ),
        ],
      ),
    );
  }

  Widget _buildBlockedBanner() => Container(
        color: const Color(0xFF1F2937),
        padding:
            const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
        child: Row(
          children: [
            const Icon(Icons.block, color: Colors.redAccent, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text('Vous avez bloqué $_label.',
                  style: const TextStyle(
                      color: Colors.white60, fontSize: 13)),
            ),
            TextButton(
              onPressed: () async {
                await SocialService.unblockUser(
                    widget.user, widget.name);
                if (mounted) setState(() => _blocked = false);
              },
              child: const Text('Débloquer',
                  style: TextStyle(
                      color: Color(0xFF2563EB), fontSize: 13)),
            ),
          ],
        ),
      );

  // ── File sharing ──────────────────────────────────────────────────────────

  Future<void> _pickAndSendFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: [
        'pdf', 'doc', 'docx', 'jpg', 'jpeg', 'png', 'gif',
        'txt', 'ppt', 'pptx', 'xls', 'xlsx',
      ],
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) { return; }
    final picked = result.files.first;
    if (picked.path == null) { return; }

    setState(() => _uploadingFile = true);

    final file = File(picked.path!);
    final ext = picked.extension?.toLowerCase() ?? 'other';
    final fileType = ['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(ext)
        ? 'image'
        : ext == 'pdf'
            ? 'pdf'
            : ['doc', 'docx'].contains(ext)
                ? 'doc'
                : 'other';

    final url = await StorageService.uploadChatFile(file, _chatId);
    if (url == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Échec de l\'envoi du fichier'),
            backgroundColor: Color(0xFFEF4444),
          ),
        );
      }
      setState(() => _uploadingFile = false);
      return;
    }

    await SocialService.sendMessage(
      chatIdStr: _chatId,
      sender: widget.user,
      toUser: widget.name,
      text: '',
      senderDisplayName: _myDisplayName,
      fileUrl: url,
      fileName: picked.name,
      fileType: fileType,
      fileSize: picked.size,
    );

    if (mounted) { setState(() => _uploadingFile = false); }
    _scrollToBottom();
  }

  Future<void> _pickAndSendImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) { return; }
    final picked = result.files.first;
    if (picked.path == null) { return; }

    setState(() => _uploadingFile = true);
    final file = File(picked.path!);
    final url = await StorageService.uploadChatFile(file, _chatId);
    if (url == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Échec de l\'envoi de l\'image'),
            backgroundColor: Color(0xFFEF4444),
          ),
        );
      }
      setState(() => _uploadingFile = false);
      return;
    }

    await SocialService.sendMessage(
      chatIdStr: _chatId,
      sender: widget.user,
      toUser: widget.name,
      text: '',
      senderDisplayName: _myDisplayName,
      fileUrl: url,
      fileName: picked.name,
      fileType: 'image',
      fileSize: picked.size,
    );

    if (mounted) { setState(() => _uploadingFile = false); }
    _scrollToBottom();
  }

  void _showAttachmentSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF161B22),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Envoyer un fichier',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _AttachOption(
                    icon: Icons.image_outlined,
                    label: 'Image',
                    color: const Color(0xFF10B981),
                    onTap: () { Navigator.pop(context); _pickAndSendImage(); },
                  ),
                  _AttachOption(
                    icon: Icons.picture_as_pdf_outlined,
                    label: 'PDF / Doc',
                    color: const Color(0xFFEF4444),
                    onTap: () { Navigator.pop(context); _pickAndSendFile(); },
                  ),
                  _AttachOption(
                    icon: Icons.mic_outlined,
                    label: 'Vocal',
                    color: const Color(0xFF6C47FF),
                    onTap: () { Navigator.pop(context); _startRecording(); },
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  // ── Voice recording ───────────────────────────────────────────────────────

  Future<void> _startRecording() async {
    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Permission microphone requise'),
            backgroundColor: Color(0xFFEF4444),
          ),
        );
      }
      return;
    }

    final dir = await getTemporaryDirectory();
    _currentRecordingPath =
        '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 128000,
        sampleRate: 44100,
      ),
      path: _currentRecordingPath!,
    );

    _recordSeconds = 0;
    _recordTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) { setState(() => _recordSeconds++); }
      if (_recordSeconds >= 120) { _stopAndSendRecording(); }
    });

    if (mounted) {
      setState(() { _isRecording = true; _recordingCancelled = false; });
    }
  }

  Future<void> _stopAndSendRecording() async {
    _recordTimer?.cancel();
    final path = await _recorder.stop();
    if (mounted) { setState(() => _isRecording = false); }

    if (_recordingCancelled || path == null) {
      _recordingCancelled = false;
      return;
    }

    final mins = _recordSeconds ~/ 60;
    final secs = _recordSeconds % 60;
    final duration = '$mins:${secs.toString().padLeft(2, '0')}';

    setState(() => _uploadingFile = true);

    final url = await StorageService.uploadChatAudio(File(path), _chatId);
    if (url == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Échec de l\'envoi du message vocal'),
            backgroundColor: Color(0xFFEF4444),
          ),
        );
      }
      setState(() => _uploadingFile = false);
      return;
    }

    await SocialService.sendMessage(
      chatIdStr: _chatId,
      sender: widget.user,
      toUser: widget.name,
      text: '🎤 Message vocal',
      senderDisplayName: _myDisplayName,
      audioUrl: url,
      audioDuration: duration,
    );

    if (mounted) { setState(() => _uploadingFile = false); }
    _scrollToBottom();
  }

  void _cancelRecording() async {
    _recordTimer?.cancel();
    _recordingCancelled = true;
    await _recorder.stop();
    if (mounted) { setState(() => _isRecording = false); }
  }

  String get _recordingTime {
    final mins = _recordSeconds ~/ 60;
    final secs = _recordSeconds % 60;
    return '$mins:${secs.toString().padLeft(2, '0')}';
  }

  // ── Audio playback ────────────────────────────────────────────────────────

  Future<void> _toggleAudio(String audioUrl) async {
    if (!_audioPlayers.containsKey(audioUrl)) {
      final player = AudioPlayer();
      _audioPlayers[audioUrl] = player;
      player.onPlayerStateChanged.listen((state) {
        if (mounted) {
          setState(() => _audioPlaying[audioUrl] = state == PlayerState.playing);
        }
      });
      player.onDurationChanged.listen((d) {
        if (mounted) { setState(() => _audioDurations[audioUrl] = d); }
      });
      player.onPositionChanged.listen((p) {
        if (mounted) { setState(() => _audioPositions[audioUrl] = p); }
      });
      player.onPlayerComplete.listen((_) {
        if (mounted) {
          setState(() {
            _audioPlaying[audioUrl] = false;
            _audioPositions[audioUrl] = Duration.zero;
          });
        }
      });
    }

    final player = _audioPlayers[audioUrl]!;
    if (_audioPlaying[audioUrl] == true) {
      await player.pause();
    } else {
      await player.play(UrlSource(audioUrl));
    }
  }

  // ── Recording bar ─────────────────────────────────────────────────────────

  Widget _buildRecordingBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      color: const Color(0xFF161B22),
      child: Row(
        children: [
          GestureDetector(
            onTap: _cancelRecording,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: const BoxDecoration(
                color: Color(0xFF1F2937),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.delete_outline, color: Color(0xFFEF4444), size: 20),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF1F2937),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                children: [
                  const _RecordingDot(),
                  const SizedBox(width: 8),
                  const Text(
                    'Enregistrement...',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const Spacer(),
                  Text(
                    _recordingTime,
                    style: const TextStyle(
                      color: Color(0xFFEF4444),
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: _stopAndSendRecording,
            child: Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF6C47FF), Color(0xFF2563EB)],
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.stop_rounded, color: Colors.white, size: 22),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInput() {
    if (_isRecording) {
      return _buildRecordingBar();
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
      decoration: const BoxDecoration(
        color: Color(0xFF161B22),
        border: Border(top: BorderSide(color: Color(0xFF21262D))),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!_blocked)
              GestureDetector(
                onTap: _showAttachmentSheet,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  child: _uploadingFile
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFF6C47FF),
                          ),
                        )
                      : const Icon(
                          Icons.add_circle_outline,
                          color: Color(0xFF6C47FF),
                          size: 24,
                        ),
                ),
              ),
            Expanded(
              child: TextField(
                controller: _textCtrl,
                enabled: !_blocked,
                style: const TextStyle(color: Colors.white, fontSize: 15),
                maxLines: 5,
                minLines: 1,
                keyboardType: TextInputType.multiline,
                textCapitalization: TextCapitalization.sentences,
                onSubmitted: (_) => _send(),
                decoration: InputDecoration(
                  hintText: _blocked
                      ? 'Utilisateur bloqué'
                      : 'Votre message…',
                  hintStyle:
                      const TextStyle(color: Colors.white38, fontSize: 14),
                  filled: true,
                  fillColor: const Color(0xFF21262D),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            _sending
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Color(0xFF6C47FF)),
                    ),
                  )
                : GestureDetector(
                    onTap: _blocked ? null : _send,
                    child: Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        gradient: _blocked
                            ? null
                            : const LinearGradient(
                                colors: [
                                  Color(0xFF6C47FF),
                                  Color(0xFF2563EB),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                        color: _blocked ? const Color(0xFF1F2937) : null,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.send_rounded,
                        color: _blocked ? Colors.white24 : Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateChip(int ts) {
    final d = DateTime.fromMillisecondsSinceEpoch(ts);
    final now = DateTime.now();
    final String label;
    if (_dayOf(ts) == _dayOf(now.millisecondsSinceEpoch)) {
      label = "Aujourd'hui";
    } else if (_dayOf(ts) ==
        _dayOf(now
            .subtract(const Duration(days: 1))
            .millisecondsSinceEpoch)) {
      label = 'Hier';
    } else {
      label = '${d.day}/${d.month}/${d.year}';
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Center(
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF21262D),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(label,
              style: const TextStyle(
                  color: Colors.white38, fontSize: 11)),
        ),
      ),
    );
  }

  int _dayOf(int? ts) {
    if (ts == null) return 0;
    final d = DateTime.fromMillisecondsSinceEpoch(ts);
    return DateTime(d.year, d.month, d.day).millisecondsSinceEpoch;
  }
}

// ─── Bulle de message ─────────────────────────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  final Map<String, dynamic> msg;
  final bool isMe;
  final bool isGroup;
  final String chatId;
  final ValueChanged<Map<String, dynamic>> onReply;
  final bool Function(String)? isAudioPlaying;
  final Duration Function(String)? audioPosition;
  final Duration? Function(String)? audioDuration;
  final void Function(String)? onToggleAudio;

  const _MessageBubble({
    required this.msg,
    required this.isMe,
    required this.isGroup,
    required this.chatId,
    required this.onReply,
    this.isAudioPlaying,
    this.audioPosition,
    this.audioDuration,
    this.onToggleAudio,
  });

  String _fmt(int? ts) {
    if (ts == null) return '';
    final d = DateTime.fromMillisecondsSinceEpoch(ts);
    return '${d.hour}:${d.minute.toString().padLeft(2, '0')}';
  }

  void _showActionSheet(BuildContext context, String text, int? ts) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1F2937),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2))),
              // Emoji reactions
              _ReactionBar(chatId: chatId, messageTime: ts ?? 0),
              const SizedBox(height: 12),
              const Divider(color: Color(0xFF374151)),
              // Copy
              ListTile(
                dense: true,
                leading: const Icon(Icons.copy_outlined,
                    color: Colors.white70, size: 20),
                title: const Text('Copier',
                    style: TextStyle(color: Colors.white70)),
                onTap: () {
                  Navigator.pop(context);
                  Clipboard.setData(ClipboardData(text: text));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Message copié'),
                      duration: Duration(seconds: 1),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),
              // Reply
              ListTile(
                dense: true,
                leading: const Icon(Icons.reply_outlined,
                    color: Color(0xFF6C47FF), size: 20),
                title: const Text('Répondre',
                    style: TextStyle(color: Color(0xFF6C47FF))),
                onTap: () {
                  Navigator.pop(context);
                  onReply(msg);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sender = msg['sender'] as String? ?? '';
    final text = msg['text'] as String? ?? '';
    final ts = msg['time'] as int?;
    final seen = msg['seen'] == true;
    final replyTo = msg['replyTo'] as Map<dynamic, dynamic>?;
    final msgType = (msg['type'] as String?) ?? 'text';
    final audioUrl = msg['audioUrl'] as String? ?? '';
    final fileUrl = msg['fileUrl'] as String? ?? '';

    final isAudioMsg = msgType == 'audio' && audioUrl.isNotEmpty;
    final isFileMsg =
        (msgType == 'file' || msgType == 'image') && fileUrl.isNotEmpty;

    return Padding(
      padding: EdgeInsets.only(
        left: isMe ? 52 : 8,
        right: isMe ? 8 : 52,
        top: 3,
        bottom: 3,
      ),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            UserAvatar(username: sender, radius: 16),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onLongPress: () => _showActionSheet(context, text, ts),
                  child: isAudioMsg
                      ? _AudioBubble(
                          message: msg,
                          isMine: isMe,
                          isPlaying:
                              isAudioPlaying?.call(audioUrl) ?? false,
                          position:
                              audioPosition?.call(audioUrl) ?? Duration.zero,
                          totalDuration: audioDuration?.call(audioUrl),
                          onToggle: () {
                            onToggleAudio?.call(audioUrl);
                          },
                        )
                      : isFileMsg
                          ? _FileBubble(message: msg, isMine: isMe)
                          : Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                gradient: isMe
                                    ? const LinearGradient(
                                        colors: [
                                          Color(0xFF6C47FF),
                                          Color(0xFF2563EB),
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      )
                                    : null,
                                color: isMe ? null : const Color(0xFF1F2937),
                                borderRadius: BorderRadius.only(
                                  topLeft: const Radius.circular(18),
                                  topRight: const Radius.circular(18),
                                  bottomLeft:
                                      Radius.circular(isMe ? 18 : 4),
                                  bottomRight:
                                      Radius.circular(isMe ? 4 : 18),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color:
                                        Colors.black.withValues(alpha: 0.2),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (!isMe && isGroup)
                                    Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 4),
                                      child: Text(
                                        sender.contains('@')
                                            ? sender.split('@').first
                                            : sender,
                                        style: const TextStyle(
                                          color: Color(0xFF6C47FF),
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  // Reply preview
                                  if (replyTo != null) ...[
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      margin:
                                          const EdgeInsets.only(bottom: 6),
                                      decoration: BoxDecoration(
                                        color: Colors.black26,
                                        borderRadius:
                                            BorderRadius.circular(8),
                                        border: const Border(
                                          left: BorderSide(
                                              color: Color(0xFF6C47FF),
                                              width: 3),
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            (replyTo['sender'] as String? ??
                                                    '')
                                                .split('@')
                                                .first,
                                            style: const TextStyle(
                                                color: Color(0xFF6C47FF),
                                                fontSize: 10,
                                                fontWeight:
                                                    FontWeight.bold),
                                          ),
                                          Text(
                                            replyTo['text'] as String? ??
                                                '',
                                            style: const TextStyle(
                                                color: Colors.white54,
                                                fontSize: 11),
                                            maxLines: 1,
                                            overflow:
                                                TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                  Text(text,
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 15,
                                          height: 1.4)),
                                  const SizedBox(height: 4),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(_fmt(ts),
                                          style: const TextStyle(
                                              color: Colors.white38,
                                              fontSize: 10)),
                                      if (isMe) ...[
                                        const SizedBox(width: 4),
                                        Icon(
                                          seen
                                              ? Icons.done_all
                                              : Icons.done,
                                          size: 14,
                                          color: seen
                                              ? const Color(0xFF60A5FA)
                                              : Colors.white38,
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                ),
                // Timestamp row for audio/file (shown outside the bubble)
                if (isAudioMsg || isFileMsg)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_fmt(ts),
                            style: const TextStyle(
                                color: Colors.white38, fontSize: 10)),
                        if (isMe) ...[
                          const SizedBox(width: 4),
                          Icon(
                            seen ? Icons.done_all : Icons.done,
                            size: 14,
                            color: seen
                                ? const Color(0xFF60A5FA)
                                : Colors.white38,
                          ),
                        ],
                      ],
                    ),
                  ),
                // Reaction display
                _ReactionsDisplay(chatId: chatId, messageTime: ts ?? 0),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Reaction Bar (bottom sheet) ──────────────────────────────────────────────

class _ReactionBar extends StatelessWidget {
  final String chatId;
  final int messageTime;
  const _ReactionBar({required this.chatId, required this.messageTime});

  static const _emojis = ['👍', '❤️', '😂', '😮', '😢', '🔥'];

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: _emojis.map((emoji) {
        return GestureDetector(
          onTap: () async {
            Navigator.pop(context);
            final ref = FirebaseDatabase.instance
                .ref('reactions/$chatId/$messageTime/$emoji');
            final snap = await ref.get();
            final count = (snap.value as int? ?? 0) + 1;
            await ref.set(count);
          },
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 6),
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: const Color(0xFF374151),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(emoji, style: const TextStyle(fontSize: 22)),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ─── Reactions Display (on bubble) ───────────────────────────────────────────

class _ReactionsDisplay extends StatelessWidget {
  final String chatId;
  final int messageTime;
  const _ReactionsDisplay(
      {required this.chatId, required this.messageTime});

  @override
  Widget build(BuildContext context) {
    if (messageTime == 0) return const SizedBox.shrink();
    return StreamBuilder<DatabaseEvent>(
      stream: FirebaseDatabase.instance
          .ref('reactions/$chatId/$messageTime')
          .onValue,
      builder: (context, snap) {
        if (!snap.hasData || snap.data!.snapshot.value == null) {
          return const SizedBox.shrink();
        }
        final raw =
            Map<dynamic, dynamic>.from(snap.data!.snapshot.value as Map);
        if (raw.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Wrap(
            spacing: 4,
            children: raw.entries.map((e) {
              final emoji = e.key.toString();
              final count = e.value as int? ?? 0;
              if (count <= 0) return const SizedBox.shrink();
              return Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF374151),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(emoji,
                        style: const TextStyle(fontSize: 13)),
                    const SizedBox(width: 4),
                    Text('$count',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 11)),
                  ],
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }
}

// ─── Typing Dots Animation ────────────────────────────────────────────────────

class _TypingDots extends StatefulWidget {
  const _TypingDots();

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with TickerProviderStateMixin {
  late final List<AnimationController> _controllers;
  late final List<Animation<double>> _anims;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(
      3,
      (i) => AnimationController(
          vsync: this, duration: const Duration(milliseconds: 400))
        ..repeat(reverse: true),
    );
    _anims = _controllers
        .asMap()
        .entries
        .map((e) => CurvedAnimation(
              parent: e.value,
              curve: Interval(e.key * 0.2, 1.0, curve: Curves.easeInOut),
            ))
        .toList();

    for (int i = 0; i < 3; i++) {
      Future.delayed(Duration(milliseconds: i * 150), () {
        if (mounted) {
          _controllers[i].repeat(reverse: true);
        }
      });
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        return AnimatedBuilder(
          animation: _anims[i],
          builder: (_, __) => Container(
            margin: const EdgeInsets.symmetric(horizontal: 2),
            width: 5,
            height: 5 + _anims[i].value * 4,
            decoration: const BoxDecoration(
              color: Colors.white38,
              shape: BoxShape.circle,
            ),
          ),
        );
      }),
    );
  }
}

// ─── File bubble ──────────────────────────────────────────────────────────────

class _FileBubble extends StatelessWidget {
  final Map<String, dynamic> message;
  final bool isMine;

  const _FileBubble({required this.message, required this.isMine});

  @override
  Widget build(BuildContext context) {
    final fileType = message['fileType'] as String? ?? 'other';
    final fileName = message['fileName'] as String? ?? 'Fichier';
    final fileSize = message['fileSize'] as int?;
    final fileUrl = message['fileUrl'] as String? ?? '';

    final isImage = fileType == 'image';

    final IconData icon;
    final Color iconColor;
    if (fileType == 'image') {
      icon = Icons.image_outlined;
      iconColor = const Color(0xFF10B981);
    } else if (fileType == 'pdf') {
      icon = Icons.picture_as_pdf_outlined;
      iconColor = const Color(0xFFEF4444);
    } else if (fileType == 'doc') {
      icon = Icons.description_outlined;
      iconColor = const Color(0xFF2563EB);
    } else {
      icon = Icons.attach_file_outlined;
      iconColor = const Color(0xFF6B7280);
    }

    const bg = LinearGradient(
      colors: [Color(0xFF6C47FF), Color(0xFF2563EB)],
    );

    return Container(
      constraints: const BoxConstraints(maxWidth: 260),
      decoration: BoxDecoration(
        gradient: isMine ? bg : null,
        color: isMine ? null : const Color(0xFF1F2937),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isImage && fileUrl.isNotEmpty)
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
              child: Image.network(
                fileUrl,
                height: 180,
                width: 260,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox(
                  height: 80,
                  child: Center(
                    child: Icon(Icons.broken_image, color: Colors.white38),
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!isImage) ...[
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: iconColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, color: iconColor, size: 20),
                  ),
                  const SizedBox(width: 10),
                ],
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fileName,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w500),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (fileSize != null)
                        Text(
                          _formatSize(fileSize),
                          style: const TextStyle(
                              color: Colors.white54, fontSize: 11),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () async {
                    final uri = Uri.parse(fileUrl);
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri,
                          mode: LaunchMode.externalApplication);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.download_outlined,
                        color: Colors.white, size: 16),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) { return '$bytes B'; }
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

// ─── Audio bubble ─────────────────────────────────────────────────────────────

class _AudioBubble extends StatelessWidget {
  final Map<String, dynamic> message;
  final bool isMine;
  final bool isPlaying;
  final Duration position;
  final Duration? totalDuration;
  final VoidCallback onToggle;

  const _AudioBubble({
    required this.message,
    required this.isMine,
    required this.isPlaying,
    required this.position,
    this.totalDuration,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final storedDuration = message['audioDuration'] as String? ?? '0:00';
    final displayDuration = totalDuration != null
        ? '${totalDuration!.inMinutes}:${(totalDuration!.inSeconds % 60).toString().padLeft(2, '0')}'
        : storedDuration;

    double progress = 0;
    if (totalDuration != null && totalDuration!.inMilliseconds > 0) {
      progress =
          position.inMilliseconds / totalDuration!.inMilliseconds;
    }

    return Container(
      width: 220,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        gradient: isMine
            ? const LinearGradient(
                colors: [Color(0xFF6C47FF), Color(0xFF2563EB)],
              )
            : null,
        color: isMine ? null : const Color(0xFF1F2937),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: onToggle,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Decorative waveform bars
                SizedBox(
                  height: 24,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: List.generate(18, (i) {
                      final h = (i % 3 == 0)
                          ? 18.0
                          : (i % 2 == 0)
                              ? 12.0
                              : 8.0;
                      final active = (i / 18) <= progress;
                      return Container(
                        width: 3,
                        height: h,
                        decoration: BoxDecoration(
                          color: active
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      );
                    }),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isPlaying
                      ? '${position.inMinutes}:${(position.inSeconds % 60).toString().padLeft(2, '0')}'
                      : displayDuration,
                  style:
                      const TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.mic, color: Colors.white54, size: 14),
        ],
      ),
    );
  }
}

// ─── Attachment option button ─────────────────────────────────────────────────

class _AttachOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _AttachOption({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 6),
          Text(label,
              style:
                  const TextStyle(color: Colors.white70, fontSize: 12)),
        ],
      ),
    );
  }
}

// ─── Pulsing recording dot ────────────────────────────────────────────────────

class _RecordingDot extends StatefulWidget {
  const _RecordingDot();

  @override
  State<_RecordingDot> createState() => _RecordingDotState();
}

class _RecordingDotState extends State<_RecordingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600))
      ..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.4, end: 1.0).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color: const Color(0xFFEF4444).withValues(alpha: _anim.value),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
