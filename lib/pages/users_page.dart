import 'package:flutter/material.dart';
import '../services/social_service.dart';
import '../widgets/user_avatar.dart';

class UsersPage extends StatefulWidget {
  final String currentUser;

  const UsersPage({super.key, required this.currentUser});

  @override
  State<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends State<UsersPage> {
  final _addCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    SocialService.goOnline();
    _searchCtrl.addListener(() {
      if (mounted) setState(() => _query = _searchCtrl.text.toLowerCase());
    });
  }

  @override
  void dispose() {
    SocialService.goOffline();
    _addCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _showAddContactDialog() async {
    _addCtrl.clear();
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1F2937),
        title: const Text('Ajouter un contact',
            style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: _addCtrl,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Nom ou email',
            hintStyle: TextStyle(color: Colors.white38),
            enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Color(0xFF2563EB))),
            focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Color(0xFF6C47FF))),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child:
                const Text('Annuler', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () async {
              final name = _addCtrl.text.trim();
              if (name.isEmpty) return;
              await SocialService.addContact(widget.currentUser, name);
              if (mounted) Navigator.pop(context);
            },
            child: const Text('Ajouter',
                style: TextStyle(color: Color(0xFF2563EB))),
          ),
        ],
      ),
    );
  }

  String _timeAgo(int? ts) {
    if (ts == null) return '';
    final diff = DateTime.now()
        .difference(DateTime.fromMillisecondsSinceEpoch(ts));
    if (diff.inMinutes < 1) return 'maintenant';
    if (diff.inMinutes < 60) return '${diff.inMinutes}min';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}j';
    final d = DateTime.fromMillisecondsSinceEpoch(ts);
    return '${d.day}/${d.month}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Messages',
          style: TextStyle(
              color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF2563EB),
        onPressed: _showAddContactDialog,
        child: const Icon(Icons.person_add, color: Colors.white),
      ),
      body: Column(
        children: [
          // Search bar
          Container(
            color: const Color(0xFF161B22),
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            child: TextField(
              controller: _searchCtrl,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Rechercher…',
                hintStyle:
                    const TextStyle(color: Colors.white38, fontSize: 14),
                prefixIcon:
                    const Icon(Icons.search, color: Colors.white38, size: 20),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear,
                            color: Colors.white38, size: 18),
                        onPressed: () => _searchCtrl.clear(),
                      )
                    : null,
                filled: true,
                fillColor: const Color(0xFF21262D),
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          // Contact list
          Expanded(
            child: StreamBuilder<List<String>>(
              stream: SocialService.contactsStream(widget.currentUser),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child: CircularProgressIndicator(
                          color: Color(0xFF2563EB)));
                }
                final all = snap.data ?? [];
                final contacts = _query.isEmpty
                    ? all
                    : all
                        .where((u) => u.toLowerCase().contains(_query))
                        .toList();

                if (contacts.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.chat_bubble_outline,
                            size: 56, color: Colors.white24),
                        const SizedBox(height: 14),
                        Text(
                          all.isEmpty
                              ? 'Aucun contact'
                              : 'Aucun résultat',
                          style: const TextStyle(
                              color: Colors.white54, fontSize: 17),
                        ),
                        const SizedBox(height: 6),
                        if (all.isEmpty)
                          const Text(
                            'Appuie sur + pour ajouter',
                            style: TextStyle(
                                color: Colors.white24, fontSize: 13),
                          ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.only(top: 4, bottom: 100),
                  itemCount: contacts.length,
                  itemBuilder: (_, i) =>
                      _ContactTile(
                    contactName: contacts[i],
                    currentUser: widget.currentUser,
                    timeAgo: _timeAgo,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Contact Tile ─────────────────────────────────────────────────────────────

class _ContactTile extends StatelessWidget {
  final String contactName;
  final String currentUser;
  final String Function(int?) timeAgo;

  const _ContactTile({
    required this.contactName,
    required this.currentUser,
    required this.timeAgo,
  });

  String get _chatId => SocialService.chatId(currentUser, contactName);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: _MessagesPreviewStream(chatId: _chatId, viewer: currentUser).stream,
      builder: (context, snap) {
        final preview = snap.data ?? _MessagePreview.empty();
        return InkWell(
          onTap: () => Navigator.pushNamed(
            context,
            '/discussion',
            arguments: {'name': contactName, 'user': currentUser},
          ),
          child: Container(
            margin:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF161B22),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: Colors.white.withValues(alpha: 0.05)),
            ),
            child: Row(
              children: [
                UserAvatar(
                    username: contactName, radius: 24, showStatus: true),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        contactName.contains('@')
                            ? contactName.split('@').first
                            : contactName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        preview.text,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: preview.unread > 0
                              ? Colors.white70
                              : Colors.white38,
                          fontSize: 12,
                          fontWeight: preview.unread > 0
                              ? FontWeight.w500
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      timeAgo(preview.time),
                      style: const TextStyle(
                          color: Colors.white38, fontSize: 11),
                    ),
                    const SizedBox(height: 4),
                    if (preview.unread > 0)
                      Container(
                        width: 20,
                        height: 20,
                        decoration: const BoxDecoration(
                          color: Color(0xFF2563EB),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '${preview.unread}',
                            style: const TextStyle(
                                fontSize: 10,
                                color: Colors.white,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─── Message Preview Stream ────────────────────────────────────────────────────

class _MessagePreview {
  final String text;
  final int? time;
  final int unread;

  const _MessagePreview({
    required this.text,
    required this.time,
    required this.unread,
  });

  factory _MessagePreview.empty() =>
      const _MessagePreview(text: 'Aucun message', time: null, unread: 0);
}

class _MessagesPreviewStream {
  final String chatId;
  final String viewer;

  _MessagesPreviewStream({required this.chatId, required this.viewer});

  Stream<_MessagePreview> get stream {
    return SocialService.messagesStream(chatId).map((msgs) {
      if (msgs.isEmpty) return _MessagePreview.empty();
      final last = msgs.last;
      final unread = msgs
          .where((m) => m['sender'] != viewer && m['seen'] != true)
          .length;
      return _MessagePreview(
        text: last['text'] as String? ?? '',
        time: last['time'] as int?,
        unread: unread,
      );
    });
  }
}
