import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/conversation_model.dart';
import '../models/message_model.dart';
import '../models/user_model.dart';
import '../services/messagerie_service.dart';
import '../services/social_service.dart';
import '../services/storage_service.dart';

// ─── Palette ──────────────────────────────────────────────────────────────────

const _kBg     = Color(0xFF0D1117);
const _kCard   = Color(0xFF161B22);
const _kCard2  = Color(0xFF1F2937);
const _kBorder = Color(0xFF30363D);
const _kBlue   = Color(0xFF2563EB);
const _kPurple = Color(0xFF6C47FF);
const _kGreen  = Color(0xFF16A34A);
const _kOrange = Color(0xFFD97706);
const _kRed    = Color(0xFFDC2626);
const _kMeBubble   = Color(0xFF1E3A5F);
const _kThemBubble = Color(0xFF1F2937);

// ─── Entry point ──────────────────────────────────────────────────────────────

class ConversationPage extends StatefulWidget {
  final String convId;
  final UserModel me;

  const ConversationPage(
      {super.key, required this.convId, required this.me});

  @override
  State<ConversationPage> createState() => _ConversationPageState();
}

class _ConversationPageState extends State<ConversationPage>
    with WidgetsBindingObserver {
  final _scrollCtrl = ScrollController();
  final _textCtrl = TextEditingController();
  final _focusNode = FocusNode();

  // Sending state
  bool _sending = false;
  bool _uploadingFile = false;

  // Reply
  MessageModel? _replyTo;

  // Voice recording
  final _recorder = AudioRecorder();
  bool _isRecording = false;
  String? _voicePath;
  int _recordSecs = 0;
  Timer? _recordTimer;

  // Typing
  Timer? _typingTimer;
  bool _isTyping = false;

  // Conversation data
  ConversationModel? _conv;
  StreamSubscription<List<ConversationModel>>? _convSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _listenConversation();
    // Mark as read when opening
    MessagerieService.markConversationRead(widget.convId);
    // Go online
    SocialService.goOnline();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollCtrl.dispose();
    _textCtrl.dispose();
    _focusNode.dispose();
    _recorder.dispose();
    _recordTimer?.cancel();
    _typingTimer?.cancel();
    _convSub?.cancel();
    MessagerieService.setTyping(widget.convId, false);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      MessagerieService.markConversationRead(widget.convId);
    }
  }

  void _listenConversation() {
    _convSub = MessagerieService.conversationsStream().listen((list) {
      final conv = list.where((c) => c.id == widget.convId).firstOrNull;
      if (conv != null && mounted) {
        setState(() => _conv = conv);
      }
    });
  }

  void _scrollToBottom({bool animate = false}) {
    if (!_scrollCtrl.hasClients) return;
    if (animate) {
      _scrollCtrl.animateTo(
        _scrollCtrl.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    } else {
      _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
    }
  }

  // ── Typing ────────────────────────────────────────────────────────────────

  void _onTextChanged(String v) {
    if (v.isNotEmpty && !_isTyping) {
      _isTyping = true;
      MessagerieService.setTyping(widget.convId, true);
    }
    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 3), () {
      _isTyping = false;
      MessagerieService.setTyping(widget.convId, false);
    });
    setState(() {});
  }

  // ── Send text ─────────────────────────────────────────────────────────────

  Future<void> _sendText() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty || _sending) return;
    _textCtrl.clear();
    setState(() {
      _sending = true;
      _isTyping = false;
    });
    MessagerieService.setTyping(widget.convId, false);

    final msg = MessageModel(
      id: '',
      senderId: widget.me.uid,
      senderNom: widget.me.displayName,
      senderRole: widget.me.role.name,
      text: text,
      type: 'text',
      replyToId: _replyTo?.id,
      replyToText: _replyTo?.text,
      replyToSenderNom: _replyTo?.senderNom,
      readBy: [widget.me.uid],
      sentAt: Timestamp.now(),
    );

    try {
      await MessagerieService.sendMessage(
        convId: widget.convId,
        participantIds: _conv?.participantIds ?? [],
        message: msg,
      );
      setState(() => _replyTo = null);
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _scrollToBottom(animate: true));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  // ── Send file ─────────────────────────────────────────────────────────────

  Future<void> _sendFile(File file, String type, String name,
      {String? mimeType}) async {
    setState(() => _uploadingFile = true);
    try {
      final url =
          await StorageService.uploadChatFile(file, widget.convId);
      if (url == null) throw Exception('Upload échoué');

      final size = await file.length();
      final msg = MessageModel(
        id: '',
        senderId: widget.me.uid,
        senderNom: widget.me.displayName,
        senderRole: widget.me.role.name,
        text: name,
        type: type,
        fileUrl: url,
        fileName: name,
        fileSize: size,
        mimeType: mimeType,
        replyToId: _replyTo?.id,
        replyToText: _replyTo?.text,
        replyToSenderNom: _replyTo?.senderNom,
        readBy: [widget.me.uid],
        sentAt: Timestamp.now(),
      );
      await MessagerieService.sendMessage(
        convId: widget.convId,
        participantIds: _conv?.participantIds ?? [],
        message: msg,
      );
      setState(() => _replyTo = null);
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _scrollToBottom(animate: true));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erreur envoi : $e'),
          backgroundColor: _kRed,
        ));
      }
    } finally {
      if (mounted) setState(() => _uploadingFile = false);
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    Navigator.pop(context);
    final img = await ImagePicker().pickImage(
        source: source, imageQuality: 80);
    if (img == null) return;
    final name = img.path.split('/').last;
    await _sendFile(File(img.path), 'image', name,
        mimeType: 'image/jpeg');
  }

  Future<void> _pickFile() async {
    Navigator.pop(context);
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: [
        'pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx',
        'txt', 'zip'
      ],
    );
    if (result == null || result.files.isEmpty) return;
    final pf = result.files.first;
    if (pf.path == null) return;
    await _sendFile(File(pf.path!), 'file', pf.name,
        mimeType: pf.extension);
  }

  void _showAttachmentSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _kCard,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2)),
            ),
            Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
              _AttachOption(
                icon: Icons.photo_library_outlined,
                label: 'Galerie',
                color: _kBlue,
                onTap: () => _pickImage(ImageSource.gallery),
              ),
              _AttachOption(
                icon: Icons.camera_alt_outlined,
                label: 'Caméra',
                color: _kGreen,
                onTap: () => _pickImage(ImageSource.camera),
              ),
              _AttachOption(
                icon: Icons.insert_drive_file_outlined,
                label: 'Fichier',
                color: _kOrange,
                onTap: () => _pickFile(),
              ),
            ]),
            const SizedBox(height: 8),
          ]),
        ),
      ),
    );
  }

  // ── Voice recording ───────────────────────────────────────────────────────

  Future<void> _startRecording() async {
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) return;
    final dir = await getTemporaryDirectory();
    _voicePath =
        '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc),
      path: _voicePath!,
    );
    _recordSecs = 0;
    _recordTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _recordSecs++);
    });
    setState(() => _isRecording = true);
  }

  Future<void> _stopRecording({bool cancel = false}) async {
    _recordTimer?.cancel();
    _recordTimer = null;
    final path = await _recorder.stop();
    setState(() => _isRecording = false);
    if (cancel || path == null || _recordSecs < 1) return;
    final duration = _recordSecs;
    final name = 'voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
    setState(() => _uploadingFile = true);
    try {
      final url =
          await StorageService.uploadChatFile(File(path), widget.convId);
      if (url == null) throw Exception('Upload échoué');
      final msg = MessageModel(
        id: '',
        senderId: widget.me.uid,
        senderNom: widget.me.displayName,
        senderRole: widget.me.role.name,
        text: 'Message vocal',
        type: 'voice',
        fileUrl: url,
        fileName: name,
        voiceDuration: duration,
        readBy: [widget.me.uid],
        sentAt: Timestamp.now(),
      );
      await MessagerieService.sendMessage(
        convId: widget.convId,
        participantIds: _conv?.participantIds ?? [],
        message: msg,
      );
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _scrollToBottom(animate: true));
    } finally {
      if (mounted) setState(() => _uploadingFile = false);
    }
  }

  // ── Message actions (long press) ──────────────────────────────────────────

  void _showMessageActions(
      BuildContext ctx, MessageModel msg) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: ctx,
      backgroundColor: _kCard,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) {
        final isOwn = msg.senderId == widget.me.uid;
        final isAdmin = widget.me.role == UserRole.admin;
        return SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const SizedBox(height: 8),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 6),
            // Reply
            ListTile(
              leading: const Icon(Icons.reply_outlined,
                  color: Colors.white70),
              title: const Text('Répondre',
                  style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                setState(() => _replyTo = msg);
                _focusNode.requestFocus();
              },
            ),
            // Copy text
            if (msg.type == 'text' && !msg.isDeleted)
              ListTile(
                leading: const Icon(Icons.copy_outlined,
                    color: Colors.white70),
                title: const Text('Copier',
                    style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  Clipboard.setData(ClipboardData(text: msg.text));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Copié'),
                        duration: Duration(seconds: 1)),
                  );
                },
              ),
            // Pin
            if (!msg.isDeleted)
              ListTile(
                leading: Icon(
                    msg.isPinned
                        ? Icons.push_pin_outlined
                        : Icons.push_pin_outlined,
                    color: _kOrange),
                title: Text(
                    msg.isPinned ? 'Désépingler' : 'Épingler',
                    style: const TextStyle(color: Colors.white)),
                onTap: () async {
                  Navigator.pop(context);
                  if (msg.isPinned) {
                    await MessagerieService.unpinMessage(
                        widget.convId, msgId: msg.id);
                  } else {
                    await MessagerieService.pinMessage(
                        widget.convId, msg, widget.me.displayName);
                  }
                },
              ),
            // Delete
            if (isOwn || isAdmin)
              ListTile(
                leading:
                    const Icon(Icons.delete_outline, color: _kRed),
                title: const Text('Supprimer',
                    style: TextStyle(color: _kRed)),
                onTap: () async {
                  Navigator.pop(context);
                  await MessagerieService.deleteMessage(
                      widget.convId, msg.id);
                },
              ),
            const SizedBox(height: 8),
          ]),
        );
      },
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final convName = _conv?.displayNameFor(widget.me.uid) ?? '…';
    final isGroup = _conv?.type == ConvType.group;

    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kCard,
        elevation: 0,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: InkWell(
          onTap: isGroup ? () => _showGroupInfo(context) : null,
          child: Row(children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: isGroup
                  ? _kPurple.withValues(alpha: 0.2)
                  : _kBlue.withValues(alpha: 0.2),
              child: isGroup
                  ? const Icon(Icons.group_outlined,
                      color: _kPurple, size: 18)
                  : Text(
                      convName.isNotEmpty
                          ? convName[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                          color: _kBlue,
                          fontWeight: FontWeight.bold,
                          fontSize: 13)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(convName,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  if (!isGroup)
                    _OnlineStatus(
                      uid: _conv?.participantIds
                              .firstWhere((id) => id != widget.me.uid,
                                  orElse: () => '') ??
                          '',
                      participantNoms:
                          _conv?.participantNoms ?? {},
                    )
                  else
                    Text(
                        '${_conv?.participantIds.length ?? 0} membres',
                        style: const TextStyle(
                            color: Colors.white38,
                            fontSize: 11)),
                ],
              ),
            ),
          ]),
        ),
      ),
      body: Column(children: [
        // Message épinglé
        if (_conv?.pinnedMessageId != null)
          _PinnedBanner(
            conv: _conv!,
            onDismiss: () =>
                MessagerieService.unpinMessage(widget.convId),
          ),
        // Messages
        Expanded(
          child: StreamBuilder<List<MessageModel>>(
            stream: MessagerieService.messagesStream(widget.convId),
            builder: (ctx, snap) {
              if (snap.connectionState == ConnectionState.waiting &&
                  snap.data == null) {
                return const Center(
                    child: CircularProgressIndicator(
                        color: _kPurple));
              }
              final msgs = snap.data ?? [];

              // Mark as read when new messages arrive
              if (msgs.isNotEmpty) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  MessagerieService.markConversationRead(
                      widget.convId);
                  if (_scrollCtrl.hasClients) {
                    final maxExt =
                        _scrollCtrl.position.maxScrollExtent;
                    if (_scrollCtrl.offset >= maxExt - 100) {
                      _scrollToBottom(animate: true);
                    }
                  }
                });
              }

              if (msgs.isEmpty) {
                return const Center(
                  child: Text(
                    'Aucun message.\nSoyez le premier à écrire !',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: Colors.white24, fontSize: 14),
                  ),
                );
              }

              return ListView.builder(
                controller: _scrollCtrl,
                padding:
                    const EdgeInsets.fromLTRB(12, 12, 12, 8),
                itemCount: msgs.length,
                itemBuilder: (_, i) {
                  final msg = msgs[i];
                  final showDate = i == 0 ||
                      !_sameDay(msgs[i - 1].sentAt.toDate(),
                          msg.sentAt.toDate());
                  final showSender =
                      isGroup && msg.senderId != widget.me.uid;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (showDate)
                        _DateDivider(
                            date: msg.sentAt.toDate()),
                      _MessageBubble(
                        msg: msg,
                        isMe: msg.senderId == widget.me.uid,
                        showSender: showSender,
                        participantCount:
                            _conv?.participantIds.length ?? 2,
                        onLongPress: () =>
                            _showMessageActions(context, msg),
                        onReply: () {
                          setState(() => _replyTo = msg);
                          _focusNode.requestFocus();
                        },
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ),
        // Typing indicator
        _TypingIndicator(
          convId: widget.convId,
          participantNoms: _conv?.participantNoms ?? {},
          myUid: widget.me.uid,
        ),
        // Reply preview
        if (_replyTo != null)
          _ReplyPreview(
            msg: _replyTo!,
            onCancel: () => setState(() => _replyTo = null),
          ),
        // Input
        _MessageInput(
          textCtrl: _textCtrl,
          focusNode: _focusNode,
          isRecording: _isRecording,
          uploadingFile: _uploadingFile,
          recordSecs: _recordSecs,
          onChanged: _onTextChanged,
          onSend: _sendText,
          onAttach: _showAttachmentSheet,
          onRecordStart: _startRecording,
          onRecordStop: () => _stopRecording(),
          onRecordCancel: () => _stopRecording(cancel: true),
          sending: _sending,
        ),
      ]),
    );
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.day == b.day && a.month == b.month && a.year == b.year;

  void _showGroupInfo(BuildContext context) {
    final conv = _conv;
    if (conv == null) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: _kCard,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _GroupInfoSheet(conv: conv, me: widget.me),
    );
  }
}

// ─── Online status ────────────────────────────────────────────────────────────

class _OnlineStatus extends StatelessWidget {
  final String uid;
  final Map<String, String> participantNoms;
  const _OnlineStatus(
      {required this.uid, required this.participantNoms});

  @override
  Widget build(BuildContext context) {
    if (uid.isEmpty) return const SizedBox.shrink();
    // Use uid-based email lookup to reuse SocialService.onlineStream
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .where(FieldPath.documentId, isEqualTo: uid)
          .limit(1)
          .snapshots(),
      builder: (_, snap) {
        final email = snap.data?.docs.isNotEmpty == true
            ? (snap.data!.docs.first.data()
                    as Map<String, dynamic>)['email'] as String? ??
                ''
            : '';
        if (email.isEmpty) return const SizedBox.shrink();
        return StreamBuilder<bool>(
          stream: SocialService.onlineStream(email),
          builder: (_, s) {
            final online = s.data ?? false;
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: online ? _kGreen : Colors.white24,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  online ? 'En ligne' : 'Hors ligne',
                  style: TextStyle(
                    color: online ? _kGreen : Colors.white24,
                    fontSize: 10,
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

// ─── Pinned banner ────────────────────────────────────────────────────────────

class _PinnedBanner extends StatelessWidget {
  final ConversationModel conv;
  final VoidCallback onDismiss;
  const _PinnedBanner({required this.conv, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: _kOrange.withValues(alpha: 0.1),
        border: Border(
          bottom: BorderSide(
              color: _kOrange.withValues(alpha: 0.25)),
        ),
      ),
      child: Row(children: [
        const Icon(Icons.push_pin, color: _kOrange, size: 14),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                conv.pinnedMessageSenderNom ?? '',
                style: const TextStyle(
                    color: _kOrange,
                    fontSize: 10,
                    fontWeight: FontWeight.bold),
              ),
              Text(
                conv.pinnedMessageText ?? '',
                style: const TextStyle(
                    color: Colors.white54, fontSize: 12),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.close,
              color: Colors.white38, size: 16),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          onPressed: onDismiss,
        ),
      ]),
    );
  }
}

// ─── Typing indicator ─────────────────────────────────────────────────────────

class _TypingIndicator extends StatelessWidget {
  final String convId;
  final Map<String, String> participantNoms;
  final String myUid;
  const _TypingIndicator(
      {required this.convId,
      required this.participantNoms,
      required this.myUid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<String>>(
      stream: MessagerieService.typingStream(convId),
      builder: (_, snap) {
        final typers = snap.data ?? [];
        if (typers.isEmpty) return const SizedBox.shrink();
        final names = typers
            .map((uid) => participantNoms[uid] ?? 'Quelqu\'un')
            .join(', ');
        return Padding(
          padding:
              const EdgeInsets.fromLTRB(14, 4, 14, 0),
          child: Row(children: [
            _TypingDots(),
            const SizedBox(width: 8),
            Text('$names écrit…',
                style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 11,
                    fontStyle: FontStyle.italic)),
          ]),
        );
      },
    );
  }
}

class _TypingDots extends StatefulWidget {
  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        duration: const Duration(milliseconds: 900),
        vsync: this)
      ..repeat();
    _anim = Tween<double>(begin: 0, end: 1).animate(_ctrl);
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
      builder: (_, __) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final delay = i / 3.0;
            final val = ((_anim.value - delay).abs() < 0.33)
                ? 1.0
                : 0.3;
            return Container(
              width: 5,
              height: 5,
              margin: const EdgeInsets.symmetric(horizontal: 1),
              decoration: BoxDecoration(
                color: Colors.white38
                    .withValues(alpha: val),
                shape: BoxShape.circle,
              ),
            );
          }),
        );
      },
    );
  }
}

// ─── Reply preview ────────────────────────────────────────────────────────────

class _ReplyPreview extends StatelessWidget {
  final MessageModel msg;
  final VoidCallback onCancel;
  const _ReplyPreview({required this.msg, required this.onCancel});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
      decoration: BoxDecoration(
        color: _kCard2,
        border:
            const Border(top: BorderSide(color: _kBorder)),
      ),
      child: Row(children: [
        Container(
            width: 3,
            height: 36,
            decoration: BoxDecoration(
              color: _kPurple,
              borderRadius: BorderRadius.circular(2),
            )),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(msg.senderNom,
                  style: const TextStyle(
                      color: _kPurple,
                      fontSize: 11,
                      fontWeight: FontWeight.bold)),
              Text(
                msg.type == 'text' ? msg.text : '📎 Fichier',
                style: const TextStyle(
                    color: Colors.white38, fontSize: 12),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.close,
              color: Colors.white38, size: 18),
          onPressed: onCancel,
        ),
      ]),
    );
  }
}

// ─── Message input ────────────────────────────────────────────────────────────

class _MessageInput extends StatelessWidget {
  final TextEditingController textCtrl;
  final FocusNode focusNode;
  final bool isRecording;
  final bool uploadingFile;
  final int recordSecs;
  final ValueChanged<String> onChanged;
  final VoidCallback onSend;
  final VoidCallback onAttach;
  final VoidCallback onRecordStart;
  final VoidCallback onRecordStop;
  final VoidCallback onRecordCancel;
  final bool sending;

  const _MessageInput({
    required this.textCtrl,
    required this.focusNode,
    required this.isRecording,
    required this.uploadingFile,
    required this.recordSecs,
    required this.onChanged,
    required this.onSend,
    required this.onAttach,
    required this.onRecordStart,
    required this.onRecordStop,
    required this.onRecordCancel,
    required this.sending,
  });

  String get _duration {
    final m = recordSecs ~/ 60;
    final s = recordSecs % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          8, 8, 8, MediaQuery.of(context).viewInsets.bottom + 8),
      decoration: const BoxDecoration(
        color: _kCard,
        border:
            Border(top: BorderSide(color: _kBorder)),
      ),
      child: isRecording
          ? _RecordingBar(
              duration: _duration,
              onStop: onRecordStop,
              onCancel: onRecordCancel,
            )
          : Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              // Attach button
              IconButton(
                icon: const Icon(Icons.attach_file_outlined,
                    color: Colors.white54),
                onPressed: uploadingFile ? null : onAttach,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(
                    minWidth: 36, minHeight: 36),
              ),
              const SizedBox(width: 6),
              // Text field
              Expanded(
                child: TextField(
                  controller: textCtrl,
                  focusNode: focusNode,
                  onChanged: onChanged,
                  onSubmitted: (_) => onSend(),
                  minLines: 1,
                  maxLines: 5,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: uploadingFile
                        ? 'Envoi en cours…'
                        : 'Message…',
                    hintStyle: const TextStyle(
                        color: Colors.white24, fontSize: 13),
                    filled: true,
                    fillColor: _kCard2,
                    contentPadding:
                        const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              // Send or Voice button
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: textCtrl,
                builder: (_, v, __) {
                  if (v.text.trim().isNotEmpty) {
                    return IconButton(
                      icon: const Icon(Icons.send_rounded,
                          color: _kPurple),
                      onPressed:
                          (sending || uploadingFile) ? null : onSend,
                    );
                  }
                  return GestureDetector(
                    onLongPressStart: (_) => onRecordStart(),
                    onLongPressEnd: (_) => onRecordStop(),
                    child: Icon(
                      Icons.mic_outlined,
                      color: uploadingFile
                          ? Colors.white24
                          : Colors.white54,
                    ),
                  );
                },
              ),
            ]),
    );
  }
}

class _RecordingBar extends StatelessWidget {
  final String duration;
  final VoidCallback onStop;
  final VoidCallback onCancel;
  const _RecordingBar(
      {required this.duration,
      required this.onStop,
      required this.onCancel});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      IconButton(
        icon: const Icon(Icons.delete_outline, color: _kRed),
        onPressed: onCancel,
      ),
      Expanded(
        child: Row(children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
                color: _kRed, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          const Text('Enregistrement…',
              style: TextStyle(
                  color: Colors.white54,
                  fontSize: 13,
                  fontStyle: FontStyle.italic)),
          const Spacer(),
          Text(duration,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14)),
          const SizedBox(width: 8),
        ]),
      ),
      IconButton(
        icon: const Icon(Icons.send_rounded, color: _kPurple),
        onPressed: onStop,
      ),
    ]);
  }
}

class _AttachOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _AttachOption(
      {required this.icon,
      required this.label,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
              border:
                  Border.all(color: color.withValues(alpha: 0.3)),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 6),
          Text(label,
              style: const TextStyle(
                  color: Colors.white54, fontSize: 11)),
        ]),
      ),
    );
  }
}

// ─── Message bubble ───────────────────────────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  final MessageModel msg;
  final bool isMe;
  final bool showSender;
  final int participantCount;
  final VoidCallback onLongPress;
  final VoidCallback onReply;

  const _MessageBubble({
    required this.msg,
    required this.isMe,
    required this.showSender,
    required this.participantCount,
    required this.onLongPress,
    required this.onReply,
  });

  @override
  Widget build(BuildContext context) {
    if (msg.isDeleted) {
      return _DeletedBubble(isMe: isMe);
    }

    return Padding(
      padding: EdgeInsets.only(
        bottom: 4,
        left: isMe ? 48 : 0,
        right: isMe ? 0 : 48,
      ),
      child: Column(
        crossAxisAlignment:
            isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (showSender)
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 2),
              child: Text(msg.senderNom,
                  style: TextStyle(
                      color: _senderColor(msg.senderRole),
                      fontSize: 11,
                      fontWeight: FontWeight.bold)),
            ),
          GestureDetector(
            onLongPress: onLongPress,
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
              decoration: BoxDecoration(
                color: isMe ? _kMeBubble : _kThemBubble,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isMe ? 16 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 16),
                ),
                border: Border.all(
                  color: isMe
                      ? _kBlue.withValues(alpha: 0.2)
                      : Colors.white.withValues(alpha: 0.05),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Reply quote
                  if (msg.replyToId != null)
                    _ReplyQuote(msg: msg),
                  // Content
                  _MsgContent(msg: msg),
                  // Footer: time + read status
                  const SizedBox(height: 2),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        _fmt(msg.sentAt.toDate()),
                        style: const TextStyle(
                            color: Colors.white24,
                            fontSize: 9),
                      ),
                      if (isMe) ...[
                        const SizedBox(width: 4),
                        _ReadIndicator(
                          readCount: msg.readBy.length,
                          participantCount: participantCount,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _fmt(DateTime dt) =>
      DateFormat('HH:mm').format(dt);

  static Color _senderColor(String role) {
    switch (role) {
      case 'professeur':
        return _kGreen;
      case 'admin':
      case 'direction':
        return _kPurple;
      case 'parent':
        return _kOrange;
      default:
        return _kBlue;
    }
  }
}

class _DeletedBubble extends StatelessWidget {
  final bool isMe;
  const _DeletedBubble({required this.isMe});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          bottom: 4, left: isMe ? 48 : 0, right: isMe ? 0 : 48),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: Colors.white.withValues(alpha: 0.06)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.do_not_disturb_outlined,
                  color: Colors.white24, size: 14),
              const SizedBox(width: 6),
              const Text('Message supprimé',
                  style: TextStyle(
                      color: Colors.white24,
                      fontStyle: FontStyle.italic,
                      fontSize: 12)),
            ]),
          ),
        ],
      ),
    );
  }
}

class _ReplyQuote extends StatelessWidget {
  final MessageModel msg;
  const _ReplyQuote({required this.msg});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(8),
        border: const Border(
            left: BorderSide(color: _kPurple, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(msg.replyToSenderNom ?? '',
              style: const TextStyle(
                  color: _kPurple,
                  fontSize: 10,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(
            msg.replyToText ?? '📎 Fichier',
            style: const TextStyle(
                color: Colors.white38, fontSize: 11),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ─── Message content (text, image, file, voice) ───────────────────────────────

class _MsgContent extends StatelessWidget {
  final MessageModel msg;
  const _MsgContent({required this.msg});

  @override
  Widget build(BuildContext context) {
    switch (msg.type) {
      case 'image':
        return _ImageContent(msg: msg);
      case 'file':
        return _FileContent(msg: msg);
      case 'voice':
        return _VoiceContent(msg: msg);
      default:
        return Text(msg.text,
            style: const TextStyle(
                color: Colors.white, fontSize: 14, height: 1.4));
    }
  }
}

class _ImageContent extends StatelessWidget {
  final MessageModel msg;
  const _ImageContent({required this.msg});

  @override
  Widget build(BuildContext context) {
    if (msg.fileUrl == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.network(
            msg.fileUrl!,
            width: 220,
            fit: BoxFit.cover,
            loadingBuilder: (_, child, progress) {
              if (progress == null) return child;
              return Container(
                width: 220,
                height: 160,
                color: Colors.white.withValues(alpha: 0.05),
                child: const Center(
                    child: CircularProgressIndicator(
                        color: _kPurple, strokeWidth: 2)),
              );
            },
            errorBuilder: (_, __, ___) => Container(
              width: 220,
              height: 100,
              color: Colors.white.withValues(alpha: 0.05),
              child: const Icon(Icons.broken_image_outlined,
                  color: Colors.white24),
            ),
          ),
        ),
        if (msg.text.isNotEmpty && msg.text != msg.fileName)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(msg.text,
                style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13)),
          ),
      ],
    );
  }
}

class _FileContent extends StatelessWidget {
  final MessageModel msg;
  const _FileContent({required this.msg});

  @override
  Widget build(BuildContext context) {
    final name = msg.fileName ?? msg.text;
    final size = msg.fileSize != null
        ? _fmtSize(msg.fileSize!)
        : '';
    return InkWell(
      onTap: msg.fileUrl != null
          ? () => launchUrl(Uri.parse(msg.fileUrl!))
          : null,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _kOrange.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
                Icons.insert_drive_file_outlined,
                color: _kOrange,
                size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
                if (size.isNotEmpty)
                  Text(size,
                      style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 10)),
              ],
            ),
          ),
          const Icon(Icons.download_outlined,
              color: Colors.white38, size: 16),
        ]),
      ),
    );
  }

  static String _fmtSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

// ─── Voice message player ─────────────────────────────────────────────────────

class _VoiceContent extends StatefulWidget {
  final MessageModel msg;
  const _VoiceContent({required this.msg});

  @override
  State<_VoiceContent> createState() => _VoiceContentState();
}

class _VoiceContentState extends State<_VoiceContent> {
  final _player = AudioPlayer();
  PlayerState _state = PlayerState.stopped;
  int _position = 0; // seconds
  StreamSubscription? _stateSub;
  StreamSubscription? _posSub;

  int get _total => widget.msg.voiceDuration ?? 0;

  @override
  void initState() {
    super.initState();
    _stateSub = _player.onPlayerStateChanged.listen((s) {
      if (mounted) setState(() => _state = s);
    });
    _posSub = _player.onPositionChanged.listen((pos) {
      if (mounted) setState(() => _position = pos.inSeconds);
    });
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    _posSub?.cancel();
    _player.dispose();
    super.dispose();
  }

  String _fmt(int s) {
    final m = s ~/ 60;
    final sec = s % 60;
    return '${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final isPlaying = _state == PlayerState.playing;
    final progress =
        _total > 0 ? _position / _total : 0.0;

    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: 6, vertical: 4),
      child: Row(children: [
        IconButton(
          icon: Icon(
            isPlaying
                ? Icons.pause_circle_filled
                : Icons.play_circle_filled,
            color: _kPurple,
            size: 32,
          ),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          onPressed: () async {
            if (widget.msg.fileUrl == null) return;
            if (isPlaying) {
              await _player.pause();
            } else {
              await _player.play(UrlSource(widget.msg.fileUrl!));
            }
          },
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SliderTheme(
                data: const SliderThemeData(
                  trackHeight: 3,
                  thumbShape:
                      RoundSliderThumbShape(enabledThumbRadius: 6),
                  overlayShape:
                      RoundSliderOverlayShape(overlayRadius: 0),
                ),
                child: Slider(
                  value: progress.clamp(0.0, 1.0),
                  onChanged: (v) async {
                    final pos =
                        Duration(seconds: (_total * v).toInt());
                    await _player.seek(pos);
                  },
                  activeColor: _kPurple,
                  inactiveColor:
                      Colors.white.withValues(alpha: 0.15),
                ),
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                    mainAxisAlignment:
                        MainAxisAlignment.spaceBetween,
                    children: [
                  Text(_fmt(_position),
                      style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 10)),
                  Text(_fmt(_total),
                      style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 10)),
                ]),
              ),
            ],
          ),
        ),
      ]),
    );
  }
}

// ─── Read indicator ───────────────────────────────────────────────────────────

class _ReadIndicator extends StatelessWidget {
  final int readCount;
  final int participantCount;
  const _ReadIndicator(
      {required this.readCount, required this.participantCount});

  @override
  Widget build(BuildContext context) {
    final allRead = readCount >= participantCount;
    return Icon(
      allRead ? Icons.done_all : Icons.done,
      color: allRead ? _kBlue : Colors.white24,
      size: 12,
    );
  }
}

// ─── Date divider ─────────────────────────────────────────────────────────────

class _DateDivider extends StatelessWidget {
  final DateTime date;
  const _DateDivider({required this.date});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    String label;
    if (date.day == now.day &&
        date.month == now.month &&
        date.year == now.year) {
      label = "Aujourd'hui";
    } else if (now.difference(date).inDays == 1) {
      label = 'Hier';
    } else {
      label = DateFormat('EEEE d MMMM', 'fr_FR').format(date);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(children: [
        const Expanded(
            child: Divider(color: _kBorder, height: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(label,
              style: const TextStyle(
                  color: Colors.white24, fontSize: 10)),
        ),
        const Expanded(
            child: Divider(color: _kBorder, height: 1)),
      ]),
    );
  }
}

// ─── Group info sheet ─────────────────────────────────────────────────────────

class _GroupInfoSheet extends StatelessWidget {
  final ConversationModel conv;
  final UserModel me;
  const _GroupInfoSheet(
      {required this.conv, required this.me});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      minChildSize: 0.3,
      expand: false,
      builder: (ctx, ctrl) => Column(children: [
        const SizedBox(height: 10),
        Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: _kPurple.withValues(alpha: 0.2),
              child: const Icon(Icons.group_outlined,
                  color: _kPurple, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(conv.name,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16)),
                  Text(
                    '${conv.participantIds.length} membres',
                    style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 12),
                  ),
                ],
              ),
            ),
          ]),
        ),
        const SizedBox(height: 16),
        const Divider(color: _kBorder),
        Expanded(
          child: ListView.separated(
            controller: ctrl,
            padding:
                const EdgeInsets.fromLTRB(16, 8, 16, 24),
            itemCount: conv.participantIds.length,
            separatorBuilder: (_, __) =>
                const Divider(color: _kBorder, height: 1),
            itemBuilder: (_, i) {
              final uid = conv.participantIds[i];
              final nom = conv.participantNoms[uid] ?? uid;
              final role =
                  conv.participantRoles[uid] ?? '';
              return ListTile(
                dense: true,
                leading: CircleAvatar(
                  radius: 16,
                  backgroundColor:
                      _kPurple.withValues(alpha: 0.12),
                  child: Text(
                      nom.isNotEmpty
                          ? nom[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                          color: _kPurple,
                          fontSize: 12)),
                ),
                title: Text(nom,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 13)),
                subtitle: uid == conv.createdBy
                    ? const Text('Créateur',
                        style: TextStyle(
                            color: _kOrange, fontSize: 10))
                    : null,
                trailing: role.isNotEmpty
                    ? Container(
                        padding:
                            const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white
                              .withValues(alpha: 0.05),
                          borderRadius:
                              BorderRadius.circular(6),
                        ),
                        child: Text(role,
                            style: const TextStyle(
                                color: Colors.white38,
                                fontSize: 10)),
                      )
                    : null,
              );
            },
          ),
        ),
      ]),
    );
  }
}
