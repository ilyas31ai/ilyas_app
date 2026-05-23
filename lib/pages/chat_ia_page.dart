import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../models/chat_message.dart';
import '../services/chat_ia_service.dart';
import '../services/ai_response_service.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/typing_indicator.dart';

class ChatIAPage extends StatefulWidget {
  final String conversationId;
  final String level;
  final String subject;
  final String? title;

  const ChatIAPage({
    super.key,
    required this.conversationId,
    required this.level,
    required this.subject,
    this.title,
  });

  @override
  State<ChatIAPage> createState() => _ChatIAPageState();
}

class _ChatIAPageState extends State<ChatIAPage> with TickerProviderStateMixin {
  // ── Controllers ────────────────────────────────────────────────────────────
  final _textCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _tts = FlutterTts();
  final _speech = SpeechToText();
  final _picker = ImagePicker();

  // ── State ──────────────────────────────────────────────────────────────────
  bool _typing = false;
  bool _listening = false;
  bool _speechReady = false;
  int? _speakingIndex;
  late String _convTitle;

  // Local image/pdf messages (not persisted in Firestore)
  final List<Map<String, dynamic>> _localMedia = [];

  // ── Init / dispose ─────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _convTitle = widget.title ?? '${widget.subject} · ${widget.level}';
    _initTts();
    _initSpeech();
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    _tts.stop();
    _speech.stop();
    super.dispose();
  }

  Future<void> _initTts() async {
    await _tts.setLanguage(widget.subject == 'Anglais' ? 'en-US' : 'fr-FR');
    await _tts.setPitch(1.0);
    await _tts.setSpeechRate(0.45);
    _tts.setCompletionHandler(() {
      if (mounted) setState(() => _speakingIndex = null);
    });
  }

  Future<void> _initSpeech() async {
    _speechReady = await _speech.initialize(
      onError: (_) { if (mounted) setState(() => _listening = false); },
    );
    if (mounted) setState(() {});
  }

  // ── Rename / Delete ────────────────────────────────────────────────────────
  Future<void> _renameConversation() async {
    final ctrl = TextEditingController(text: _convTitle);
    final newTitle = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1F2937),
        title: const Text('Renommer', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Nom de la conversation',
            hintStyle: TextStyle(color: Colors.white38),
            enabledBorder:
                UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF2563EB))),
            focusedBorder:
                UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF6C47FF))),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, ctrl.text.trim()),
            child: const Text('Renommer', style: TextStyle(color: Color(0xFF2563EB))),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (newTitle != null && newTitle.isNotEmpty && newTitle != _convTitle) {
      await ChatIaService.updateTitle(widget.conversationId, newTitle);
      if (mounted) setState(() => _convTitle = newTitle);
    }
  }

  Future<void> _deleteConversation() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1F2937),
        title: const Text('Supprimer ?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Cette conversation sera supprimée définitivement.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Supprimer', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ChatIaService.deleteConversation(widget.conversationId);
      if (mounted) Navigator.pop(context);
    }
  }

  // ── Scroll ─────────────────────────────────────────────────────────────────
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ── Send message ───────────────────────────────────────────────────────────
  Future<void> _send() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty || _typing) return;

    _textCtrl.clear();
    if (_listening) {
      await _speech.stop();
      if (mounted) setState(() => _listening = false);
    }

    // Save user message to Firestore
    await ChatIaService.addMessage(
      convId: widget.conversationId,
      content: text,
      isUser: true,
    );
    if (!mounted) return;
    setState(() => _typing = true);
    _scrollToBottom();

    // Get AI response
    final response = await AiResponseService.getResponse(
      question: text,
      level: widget.level,
      subject: widget.subject,
    );
    if (!mounted) return;

    // Save AI response to Firestore
    await ChatIaService.addMessage(
      convId: widget.conversationId,
      content: response,
      isUser: false,
    );
    if (!mounted) return;
    setState(() => _typing = false);
    _scrollToBottom();
  }

  // ── Voice ──────────────────────────────────────────────────────────────────
  Future<void> _toggleListen() async {
    if (!_speechReady) return;
    if (_listening) {
      await _speech.stop();
      if (mounted) setState(() => _listening = false);
      return;
    }
    if (mounted) setState(() => _listening = true);
    await _speech.listen(
      localeId: widget.subject == 'Anglais' ? 'en_US' : 'fr_FR',
      onResult: (r) {
        if (mounted) {
          setState(() {
            _textCtrl.text = r.recognizedWords;
            _textCtrl.selection =
                TextSelection.fromPosition(TextPosition(offset: _textCtrl.text.length));
          });
        }
      },
    );
  }

  Future<void> _speak(String text, int index) async {
    if (_speakingIndex == index) {
      await _tts.stop();
      if (mounted) setState(() => _speakingIndex = null);
      return;
    }
    if (mounted) setState(() => _speakingIndex = index);
    await _tts.setLanguage(widget.subject == 'Anglais' ? 'en-US' : 'fr-FR');
    await _tts.speak(text);
  }

  // ── Media ──────────────────────────────────────────────────────────────────
  Future<void> _pickImage() async {
    final img = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (img == null || !mounted) return;
    setState(() => _localMedia.add({'type': 'image', 'path': img.path}));
    _scrollToBottom();
  }

  Future<void> _pickPdf() async {
    final result =
        await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf']);
    if (result == null || !mounted) return;
    setState(() =>
        _localMedia.add({'type': 'pdf', 'name': result.files.single.name}));
    _scrollToBottom();
  }

  // ── PDF export ─────────────────────────────────────────────────────────────
  Future<void> _exportPdf(String text) async {
    final clean = text
        .replaceAll(RegExp(r'```[\s\S]*?```'), '')
        .replaceAll(RegExp(r'\*\*|__|`'), '')
        .trim();
    final pdf = pw.Document();
    final logo = await imageFromAssetBundle('assets/logo.png');
    pdf.addPage(pw.MultiPage(build: (ctx) => [
      pw.Row(children: [
        pw.Container(width: 44, height: 44, child: pw.Image(logo)),
        pw.SizedBox(width: 12),
        pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text('SCOLAR AI',
              style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
          pw.Text('${widget.level} — ${widget.subject}',
              style: const pw.TextStyle(fontSize: 11)),
        ]),
      ]),
      pw.Divider(height: 20),
      pw.Text(clean, style: const pw.TextStyle(fontSize: 13)),
    ]));
    await Printing.layoutPdf(onLayout: (_) async => pdf.save());
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: _appBar(),
      body: Column(
        children: [
          Expanded(child: _messageList()),
          if (_typing) const TypingIndicator(),
          _inputBar(),
        ],
      ),
    );
  }

  AppBar _appBar() => AppBar(
        backgroundColor: const Color(0xFF161B22),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6C47FF), Color(0xFF2563EB)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.auto_awesome, size: 18, color: Colors.white),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _convTitle,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const Text(
                    'SCOLAR AI',
                    style: TextStyle(color: Colors.white54, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white54),
            color: const Color(0xFF1F2937),
            onSelected: (v) {
              if (v == 'rename') _renameConversation();
              if (v == 'delete') _deleteConversation();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'rename',
                child: Row(
                  children: [
                    Icon(Icons.edit_outlined, color: Colors.white70, size: 18),
                    SizedBox(width: 10),
                    Text('Renommer', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                    SizedBox(width: 10),
                    Text('Supprimer', style: TextStyle(color: Colors.redAccent)),
                  ],
                ),
              ),
            ],
          ),
        ],
      );

  // ── Message list ───────────────────────────────────────────────────────────
  Widget _messageList() {
    return StreamBuilder<List<ChatMessage>>(
      stream: ChatIaService.messagesStream(widget.conversationId),
      builder: (context, snap) {
        final messages = snap.data ?? [];
        if (messages.isEmpty && _localMedia.isEmpty && !_typing) {
          return _emptyState();
        }
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
        return ListView.builder(
          controller: _scrollCtrl,
          padding: const EdgeInsets.symmetric(vertical: 12),
          itemCount: messages.length + _localMedia.length,
          itemBuilder: (_, i) {
            if (i < messages.length) {
              final msg = messages[i];
              return _buildItem(msg, i);
            }
            // Local media (images, PDFs)
            final media = _localMedia[i - messages.length];
            return _buildMedia(media);
          },
        );
      },
    );
  }

  Widget _buildItem(ChatMessage msg, int index) {
    if (msg.isUser) return ChatBubble(message: msg);

    // AI message with action chips
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ChatBubble(message: msg),
        Padding(
          padding: const EdgeInsets.only(left: 52, bottom: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _actionChip(
                icon: _speakingIndex == index ? Icons.stop_rounded : Icons.volume_up_rounded,
                label: _speakingIndex == index ? 'Stop' : 'Écouter',
                onTap: () => _speak(msg.content, index),
              ),
              const SizedBox(width: 8),
              _actionChip(
                icon: Icons.picture_as_pdf_outlined,
                label: 'PDF',
                onTap: () => _exportPdf(msg.content),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMedia(Map<String, dynamic> media) {
    if (media['type'] == 'image') {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Image.file(File(media['path'] as String), width: 220),
          ),
        ),
      );
    }
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF1F2937),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.picture_as_pdf, color: Colors.redAccent, size: 20),
            const SizedBox(width: 8),
            Text(media['name'] as String? ?? '',
                style: const TextStyle(color: Colors.white70, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _actionChip({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: Colors.white60),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(fontSize: 12, color: Colors.white60)),
          ],
        ),
      ),
    );
  }

  Widget _emptyState() => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6C47FF), Color(0xFF2563EB)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.auto_awesome, size: 36, color: Colors.white),
            ),
            const SizedBox(height: 20),
            Text(
              widget.subject,
              style: const TextStyle(
                  color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              'Niveau ${widget.level}',
              style: const TextStyle(color: Colors.white54, fontSize: 14),
            ),
            const SizedBox(height: 16),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 40),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1F2937),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Text(
                'Pose ta question et je t\'explique\nétape par étape avec des exemples !',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white60, fontSize: 14, height: 1.5),
              ),
            ),
          ],
        ),
      );

  // ── Input bar ──────────────────────────────────────────────────────────────
  Widget _inputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 8, 6, 12),
      decoration: const BoxDecoration(
        color: Color(0xFF161B22),
        border: Border(top: BorderSide(color: Color(0xFF21262D))),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            IconButton(
              icon: const Icon(Icons.image_outlined, size: 22, color: Colors.white54),
              tooltip: 'Image',
              onPressed: _pickImage,
            ),
            IconButton(
              icon: const Icon(Icons.attach_file, size: 22, color: Colors.white54),
              tooltip: 'PDF',
              onPressed: _pickPdf,
            ),
            Expanded(
              child: TextField(
                controller: _textCtrl,
                style: const TextStyle(color: Colors.white, fontSize: 15),
                maxLines: 5,
                minLines: 1,
                keyboardType: TextInputType.multiline,
                textCapitalization: TextCapitalization.sentences,
                onSubmitted: (_) => _send(),
                decoration: InputDecoration(
                  hintText: 'Pose ta question en ${widget.subject}…',
                  hintStyle: const TextStyle(color: Colors.white38, fontSize: 14),
                  filled: true,
                  fillColor: const Color(0xFF21262D),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            IconButton(
              icon: Icon(
                _listening ? Icons.mic_rounded : Icons.mic_none_rounded,
                size: 22,
                color: _listening
                    ? Colors.redAccent
                    : (_speechReady ? Colors.white54 : Colors.white24),
              ),
              tooltip: _speechReady ? 'Dicter' : 'Micro indisponible',
              onPressed: _speechReady ? _toggleListen : null,
            ),
            _typing
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5, color: Color(0xFF2563EB)),
                    ),
                  )
                : IconButton(
                    icon:
                        const Icon(Icons.send_rounded, size: 22, color: Color(0xFF2563EB)),
                    tooltip: 'Envoyer',
                    onPressed: _send,
                  ),
          ],
        ),
      ),
    );
  }
}
