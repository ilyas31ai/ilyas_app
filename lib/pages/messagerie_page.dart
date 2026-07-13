import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/conversation_model.dart';
import '../models/user_model.dart';
import '../services/messagerie_service.dart';
import '../services/user_service.dart';
import 'conversation_page.dart';
import 'nouvelle_conversation_page.dart';

// ─── Palette ──────────────────────────────────────────────────────────────────

const _kBg     = Color(0xFF0D1117);
const _kCard   = Color(0xFF161B22);
const _kCard2  = Color(0xFF1F2937);
const _kBorder = Color(0xFF30363D);
const _kBlue   = Color(0xFF2563EB);
const _kPurple = Color(0xFF6C47FF);
const _kRed    = Color(0xFFDC2626);

// ─── Entry point ──────────────────────────────────────────────────────────────

class MessageriePage extends StatefulWidget {
  const MessageriePage({super.key});

  @override
  State<MessageriePage> createState() => _MessageriePageState();
}

class _MessageriePageState extends State<MessageriePage>
    with SingleTickerProviderStateMixin {
  late final TabController _tc;
  final _searchCtrl = TextEditingController();
  String _query = '';
  UserModel? _me;

  @override
  void initState() {
    super.initState();
    _tc = TabController(length: 3, vsync: this);
    UserService.currentUserStream().first.then((u) {
      if (mounted) setState(() => _me = u);
    });
  }

  @override
  void dispose() {
    _tc.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kCard,
        elevation: 0,
        title: const Text('Messagerie',
            style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: Colors.white70),
            tooltip: 'Nouvelle conversation',
            onPressed: () => _openNewConversation(),
          ),
        ],
        bottom: TabBar(
          controller: _tc,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white38,
          indicatorColor: _kPurple,
          labelStyle:
              const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
          tabs: const [
            Tab(text: 'Tous'),
            Tab(text: 'Non lus'),
            Tab(text: 'Archives'),
          ],
        ),
      ),
      body: Column(children: [
        // Barre de recherche
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
          child: TextField(
            controller: _searchCtrl,
            onChanged: (v) => setState(() => _query = v),
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Rechercher une conversation…',
              hintStyle:
                  const TextStyle(color: Colors.white24, fontSize: 13),
              prefixIcon:
                  const Icon(Icons.search, color: Colors.white38, size: 20),
              suffixIcon: _query.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear,
                          color: Colors.white38, size: 18),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() => _query = '');
                      },
                    )
                  : null,
              filled: true,
              fillColor: _kCard2,
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        // Tabs content
        Expanded(
          child: TabBarView(
            controller: _tc,
            children: [
              _ConvList(
                  filter: _ConvFilter.all,
                  query: _query,
                  me: _me),
              _ConvList(
                  filter: _ConvFilter.unread,
                  query: _query,
                  me: _me),
              _ConvList(
                  filter: _ConvFilter.archived,
                  query: _query,
                  me: _me),
            ],
          ),
        ),
      ]),
      floatingActionButton: FloatingActionButton(
        onPressed: _openNewConversation,
        backgroundColor: _kPurple,
        child: const Icon(Icons.add_comment_outlined,
            color: Colors.white),
      ),
    );
  }

  void _openNewConversation() async {
    if (_me == null) return;
    final convId = await Navigator.push<String>(
      context,
      MaterialPageRoute<String>(
        builder: (_) => NouvelleConversationPage(me: _me!),
      ),
    );
    if (convId != null && mounted) {
      Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) =>
              ConversationPage(convId: convId, me: _me!),
        ),
      );
    }
  }
}

// ─── Filtre ───────────────────────────────────────────────────────────────────

enum _ConvFilter { all, unread, archived }

// ─── Liste des conversations ──────────────────────────────────────────────────

class _ConvList extends StatelessWidget {
  final _ConvFilter filter;
  final String query;
  final UserModel? me;

  const _ConvList({
    required this.filter,
    required this.query,
    required this.me,
  });

  @override
  Widget build(BuildContext context) {
    final uid = me?.uid ?? FirebaseAuth.instance.currentUser?.uid ?? '';

    return StreamBuilder<List<ConversationModel>>(
      stream: MessagerieService.conversationsStream(),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: _kPurple));
        }
        if (snap.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Erreur de chargement des conversations.\nVérifiez votre connexion.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white38, fontSize: 13),
              ),
            ),
          );
        }
        var all = snap.data ?? [];

        // Filtre principal
        switch (filter) {
          case _ConvFilter.all:
            all = all.where((c) => !c.isArchivedBy(uid)).toList();
          case _ConvFilter.unread:
            all = all
                .where(
                    (c) => !c.isArchivedBy(uid) && c.unreadFor(uid) > 0)
                .toList();
          case _ConvFilter.archived:
            all = all.where((c) => c.isArchivedBy(uid)).toList();
        }

        // Filtre recherche
        if (query.isNotEmpty) {
          all = MessagerieService.filterConversations(all, query, uid);
        }

        if (all.isEmpty) {
          return _EmptyState(filter: filter);
        }

        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 6),
          itemCount: all.length,
          separatorBuilder: (_, __) =>
              const Divider(height: 1, color: _kBorder, indent: 70),
          itemBuilder: (_, i) =>
              _ConvTile(conv: all[i], uid: uid, me: me),
        );
      },
    );
  }
}

// ─── Tile conversation ────────────────────────────────────────────────────────

class _ConvTile extends StatelessWidget {
  final ConversationModel conv;
  final String uid;
  final UserModel? me;

  const _ConvTile(
      {required this.conv, required this.uid, required this.me});

  @override
  Widget build(BuildContext context) {
    final unread = conv.unreadFor(uid);
    final name = conv.displayNameFor(uid);
    final initial = conv.avatarInitialFor(uid);
    final isGroup = conv.type == ConvType.group;
    final time = conv.lastMessageAt;

    return InkWell(
      onTap: () {
        if (me == null) return;
        Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) =>
                ConversationPage(convId: conv.id, me: me!),
          ),
        );
      },
      onLongPress: () => _showOptions(context),
      child: Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(children: [
          // Avatar
          Stack(children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: isGroup
                  ? _kPurple.withValues(alpha: 0.2)
                  : _kBlue.withValues(alpha: 0.2),
              child: isGroup
                  ? Icon(Icons.group_outlined,
                      color: _kPurple, size: 22)
                  : Text(initial,
                      style: TextStyle(
                          color: isGroup ? _kPurple : _kBlue,
                          fontWeight: FontWeight.bold,
                          fontSize: 16)),
            ),
            if (unread > 0)
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: _kPurple,
                    shape: BoxShape.circle,
                    border: Border.all(color: _kBg, width: 1.5),
                  ),
                  constraints: const BoxConstraints(
                      minWidth: 18, minHeight: 18),
                  child: Text(
                    unread > 99 ? '99+' : '$unread',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ]),
          const SizedBox(width: 12),
          // Contenu
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(
                    child: Text(name,
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: unread > 0
                                ? FontWeight.bold
                                : FontWeight.w500,
                            fontSize: 14),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ),
                  if (time != null)
                    Text(
                      _formatTime(time.toDate()),
                      style: TextStyle(
                          color: unread > 0
                              ? _kPurple
                              : Colors.white24,
                          fontSize: 10,
                          fontWeight: unread > 0
                              ? FontWeight.bold
                              : FontWeight.normal),
                    ),
                ]),
                const SizedBox(height: 3),
                Row(children: [
                  Expanded(
                    child: Text(
                      _lastMsgPreview(conv),
                      style: TextStyle(
                          color: unread > 0
                              ? Colors.white54
                              : Colors.white24,
                          fontSize: 12,
                          fontWeight: unread > 0
                              ? FontWeight.w500
                              : FontWeight.normal),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (conv.isArchivedBy(uid))
                    Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: Icon(Icons.archive_outlined,
                          color: Colors.white24, size: 14),
                    ),
                ]),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  String _lastMsgPreview(ConversationModel c) {
    if (c.lastMessage.isEmpty) return 'Aucun message';
    if (c.lastSenderId == uid) {
      return 'Vous : ${c.lastMessage}';
    }
    if (c.type == ConvType.group && c.lastSenderNom.isNotEmpty) {
      return '${c.lastSenderNom} : ${c.lastMessage}';
    }
    return c.lastMessage;
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    if (dt.day == now.day &&
        dt.month == now.month &&
        dt.year == now.year) {
      return DateFormat('HH:mm').format(dt);
    }
    if (now.difference(dt).inDays < 7) {
      return DateFormat('EEE', 'fr_FR').format(dt);
    }
    return DateFormat('dd/MM').format(dt);
  }

  void _showOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: _kCard,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _ConvOptions(conv: conv, uid: uid),
    );
  }
}

// ─── Options conversation (long press) ───────────────────────────────────────

class _ConvOptions extends StatelessWidget {
  final ConversationModel conv;
  final String uid;
  const _ConvOptions({required this.conv, required this.uid});

  @override
  Widget build(BuildContext context) {
    final isArchived = conv.isArchivedBy(uid);
    return SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(height: 6),
        Container(
          width: 36,
          height: 4,
          decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(height: 12),
        ListTile(
          leading: Icon(
              isArchived
                  ? Icons.unarchive_outlined
                  : Icons.archive_outlined,
              color: Colors.white70),
          title: Text(
              isArchived ? 'Désarchiver' : 'Archiver',
              style: const TextStyle(color: Colors.white)),
          onTap: () async {
            Navigator.pop(context);
            await MessagerieService.toggleArchive(conv.id, !isArchived);
          },
        ),
        if (conv.type == ConvType.group &&
            conv.createdBy != uid)
          ListTile(
            leading: const Icon(Icons.exit_to_app_outlined,
                color: _kRed),
            title: const Text('Quitter le groupe',
                style: TextStyle(color: _kRed)),
            onTap: () async {
              Navigator.pop(context);
              await MessagerieService.leaveGroup(conv.id);
            },
          ),
        const SizedBox(height: 8),
      ]),
    );
  }
}

// ─── État vide ────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final _ConvFilter filter;
  const _EmptyState({required this.filter});

  @override
  Widget build(BuildContext context) {
    final String label;
    final IconData icon;
    switch (filter) {
      case _ConvFilter.unread:
        label = 'Aucun message non lu';
        icon = Icons.mark_email_read_outlined;
      case _ConvFilter.archived:
        label = 'Aucune conversation archivée';
        icon = Icons.archive_outlined;
      default:
        label = 'Aucune conversation\nAppuyez sur + pour démarrer';
        icon = Icons.chat_bubble_outline;
    }
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: Colors.white12, size: 56),
        const SizedBox(height: 14),
        Text(label,
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: Colors.white24, fontSize: 14)),
      ]),
    );
  }
}
