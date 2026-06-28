import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/social_service.dart';
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
    _init();
    _scrollCtrl.addListener(_onScroll);
    UserService.currentUserStream().first.then((u) {
      if (mounted && u != null && u.displayName.isNotEmpty) {
        _myDisplayName = u.displayName;
      }
    });
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
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
    setState(() => _sending = true);
    await SocialService.sendMessage(
      chatIdStr: _chatId,
      sender: widget.user,
      toUser: widget.name,
      text: text,
      senderDisplayName: _myDisplayName,
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
              if (_blocked) _buildBlockedBanner(),
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
                  const Text('SCOLAR Connect',
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
                  msg: msg, isMe: isMe, isGroup: _isGroup),
            ]);
          },
        );
      },
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

  Widget _buildInput() {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
      decoration: const BoxDecoration(
        color: Color(0xFF161B22),
        border:
            Border(top: BorderSide(color: Color(0xFF21262D))),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: _textCtrl,
                enabled: !_blocked,
                style:
                    const TextStyle(color: Colors.white, fontSize: 15),
                maxLines: 5,
                minLines: 1,
                keyboardType: TextInputType.multiline,
                textCapitalization: TextCapitalization.sentences,
                onSubmitted: (_) => _send(),
                decoration: InputDecoration(
                  hintText: _blocked
                      ? 'Utilisateur bloqué'
                      : 'Votre message…',
                  hintStyle: const TextStyle(
                      color: Colors.white38, fontSize: 14),
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
                                  Color(0xFF2563EB)
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                        color: _blocked
                            ? const Color(0xFF1F2937)
                            : null,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.send_rounded,
                        color: _blocked
                            ? Colors.white24
                            : Colors.white,
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

  const _MessageBubble(
      {required this.msg,
      required this.isMe,
      required this.isGroup});

  String _fmt(int? ts) {
    if (ts == null) return '';
    final d = DateTime.fromMillisecondsSinceEpoch(ts);
    return '${d.hour}:${d.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final sender = msg['sender'] as String? ?? '';
    final text = msg['text'] as String? ?? '';
    final ts = msg['time'] as int?;
    final seen = msg['seen'] == true;

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
            child: GestureDetector(
              onLongPress: () {
                Clipboard.setData(ClipboardData(text: text));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Message copié'),
                    duration: Duration(seconds: 1),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  gradient: isMe
                      ? const LinearGradient(
                          colors: [
                            Color(0xFF6C47FF),
                            Color(0xFF2563EB)
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  color:
                      isMe ? null : const Color(0xFF1F2937),
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(18),
                    topRight: const Radius.circular(18),
                    bottomLeft: Radius.circular(isMe ? 18 : 4),
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
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (!isMe && isGroup)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
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
                            seen ? Icons.done_all : Icons.done,
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
          ),
        ],
      ),
    );
  }
}
