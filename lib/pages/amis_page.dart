import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/social_service.dart';
import '../services/user_service.dart';
import '../widgets/user_avatar.dart';

class AmisPage extends StatefulWidget {
  final String currentUser;

  const AmisPage({super.key, required this.currentUser});

  @override
  State<AmisPage> createState() => _AmisPageState();
}

class _AmisPageState extends State<AmisPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  // Streams initialisés une seule fois : évite les re-souscriptions sur rebuild
  late final Stream<List<String>> _friendsStream;
  late final Stream<List<String>> _requestsStream;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _friendsStream = SocialService.friendsStream(widget.currentUser);
    _requestsStream = SocialService.requestsStream(widget.currentUser);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  // ─── Actions ──────────────────────────────────────────────────────────────

  Future<void> _openChat(String user) {
    return Navigator.pushNamed(
      context,
      '/discussion',
      arguments: {'name': user, 'user': widget.currentUser},
    );
  }

  Future<void> _confirmRemoveFriend(String user) async {
    final ok = await _confirm(
      'Supprimer $user de vos amis ?',
      confirmText: 'Supprimer',
    );
    if (ok == true) {
      await SocialService.removeFriend(widget.currentUser, user);
    }
  }

  Future<void> _confirmBlock(String user) async {
    final ok = await _confirm(
      'Bloquer $user ? Il ne pourra plus vous contacter.',
      confirmText: 'Bloquer',
    );
    if (ok == true) {
      await SocialService.blockUser(widget.currentUser, user);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$user est bloqué'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<bool?> _confirm(String message, {required String confirmText}) {
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1F2937),
        title: const Text('Confirmer',
            style: TextStyle(color: Colors.white, fontSize: 16)),
        content: Text(message, style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler',
                style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(confirmText,
                style: const TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  // ─── Build ────────────────────────────────────────────────────────────────

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
        title: Row(
          children: [
            UserAvatar(username: widget.currentUser, radius: 17),
            const SizedBox(width: 10),
            const Text(
              'Amis & Social',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold),
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: const Color(0xFF2563EB),
          indicatorWeight: 2,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white38,
          labelStyle:
              const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          tabs: const [
            Tab(text: 'Amis'),
            Tab(text: 'Demandes'),
            Tab(text: 'Trouver'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _buildFriendsTab(),
          _buildRequestsTab(),
          // _DiscoverTab est un StatefulWidget indépendant avec ses propres streams
          _DiscoverTab(
            currentUser: widget.currentUser,
            onChat: _openChat,
            onBlock: _confirmBlock,
          ),
        ],
      ),
    );
  }

  // ─── Tab 1 : Amis ─────────────────────────────────────────────────────────

  Widget _buildFriendsTab() {
    return StreamBuilder<List<String>>(
      stream: _friendsStream, // stream stocké → pas de re-souscription
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: Color(0xFF2563EB)));
        }
        final friends = snap.data ?? [];
        if (friends.isEmpty) {
          return _emptyState(
            icon: Icons.people_outline,
            title: 'Aucun ami',
            subtitle: "Explore l'onglet Trouver pour ajouter des amis",
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: friends.length,
          itemBuilder: (_, i) => _FriendTile(
            username: friends[i],
            onChat: () => _openChat(friends[i]),
            onRemove: () => _confirmRemoveFriend(friends[i]),
            onBlock: () => _confirmBlock(friends[i]),
          ),
        );
      },
    );
  }

  // ─── Tab 2 : Demandes ─────────────────────────────────────────────────────

  Widget _buildRequestsTab() {
    return StreamBuilder<List<String>>(
      stream: _requestsStream, // stream stocké → pas de re-souscription
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: Color(0xFF2563EB)));
        }
        final requests = snap.data ?? [];
        if (requests.isEmpty) {
          return _emptyState(
            icon: Icons.inbox_outlined,
            title: 'Aucune demande',
            subtitle: 'Les demandes reçues apparaissent ici',
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: requests.length,
          itemBuilder: (_, i) => _RequestTile(
            fromUser: requests[i],
            onAccept: () => SocialService.acceptRequest(
                widget.currentUser, requests[i]),
            onReject: () => SocialService.rejectRequest(
                widget.currentUser, requests[i]),
          ),
        );
      },
    );
  }

  Widget _emptyState(
      {required IconData icon,
      required String title,
      required String subtitle}) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 56, color: Colors.white24),
          const SizedBox(height: 14),
          Text(title,
              style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 17,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white24, fontSize: 13)),
        ],
      ),
    );
  }
}

// ─── Discover Tab (StatefulWidget) ────────────────────────────────────────────
// Streams séparés du parent → setState sur la recherche ne rebuild pas les
// onglets Amis/Demandes. Streams stockés en initState → pas de re-souscription.

class _DiscoverTab extends StatefulWidget {
  final String currentUser;
  final Future<void> Function(String) onChat;
  final Future<void> Function(String) onBlock;

  const _DiscoverTab({
    required this.currentUser,
    required this.onChat,
    required this.onBlock,
  });

  @override
  State<_DiscoverTab> createState() => _DiscoverTabState();
}

class _DiscoverTabState extends State<_DiscoverTab> {
  // Firestore stream → seuls les vrais utilisateurs inscrits
  late final Stream<List<UserModel>> _allUsersStream;
  late final Stream<List<String>> _friendsStream;
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _allUsersStream = UserService.allUsersStream();
    _friendsStream = SocialService.friendsStream(widget.currentUser);
    _searchCtrl.addListener(() {
      if (mounted) setState(() => _query = _searchCtrl.text.toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          color: const Color(0xFF161B22),
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          child: TextField(
            controller: _searchCtrl,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Rechercher un utilisateur…',
              hintStyle: const TextStyle(color: Colors.white38),
              prefixIcon:
                  const Icon(Icons.search, color: Colors.white38, size: 20),
              suffixIcon: _query.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear,
                          color: Colors.white38, size: 18),
                      onPressed: _searchCtrl.clear,
                    )
                  : null,
              filled: true,
              fillColor: const Color(0xFF21262D),
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        Expanded(
          child: StreamBuilder<List<UserModel>>(
            stream: _allUsersStream,
            builder: (context, snapAll) {
              return StreamBuilder<List<String>>(
                stream: _friendsStream,
                builder: (context, snapFriends) {
                  final all = snapAll.data ?? [];
                  final friends = snapFriends.data ?? [];
                  final filtered = _query.isEmpty
                      ? all
                      : all
                          .where((u) =>
                              u.displayName
                                  .toLowerCase()
                                  .contains(_query) ||
                              u.email.toLowerCase().contains(_query))
                          .toList();

                  if (filtered.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            all.isEmpty
                                ? Icons.people_outline
                                : Icons.search_off,
                            size: 56,
                            color: Colors.white24,
                          ),
                          const SizedBox(height: 14),
                          Text(
                            all.isEmpty
                                ? 'Aucun utilisateur inscrit'
                                : 'Aucun résultat',
                            style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 17,
                                fontWeight: FontWeight.w600),
                          ),
                          if (all.isEmpty) ...[
                            const SizedBox(height: 6),
                            const Text(
                              'Les utilisateurs apparaissent ici\naprès leur inscription',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: Colors.white24, fontSize: 13),
                            ),
                          ],
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: filtered.length,
                    itemBuilder: (_, i) {
                      final userModel = filtered[i];
                      final isFriend = friends.contains(userModel.email);
                      return _DiscoverTile(
                        user: userModel,
                        isFriend: isFriend,
                        onAdd: isFriend
                            ? null
                            : () => SocialService.sendFriendRequest(
                                widget.currentUser, userModel.email),
                        onChat: isFriend
                            ? () => widget.onChat(userModel.email)
                            : null,
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

// ─── Tiles ────────────────────────────────────────────────────────────────────

class _FriendTile extends StatelessWidget {
  final String username;
  final VoidCallback onChat;
  final VoidCallback onRemove;
  final VoidCallback onBlock;

  const _FriendTile({
    required this.username,
    required this.onChat,
    required this.onRemove,
    required this.onBlock,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onChat,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF161B22),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Row(
          children: [
            UserAvatar(username: username, radius: 22, showStatus: true),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    username.contains('@')
                        ? username.split('@').first
                        : username,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14),
                  ),
                  OnlineLabel(username: username),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chat_bubble_outline,
                  color: Color(0xFF2563EB), size: 20),
              tooltip: 'Message',
              onPressed: onChat,
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert,
                  color: Colors.white38, size: 20),
              color: const Color(0xFF1F2937),
              onSelected: (v) {
                if (v == 'remove') onRemove();
                if (v == 'block') onBlock();
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'remove',
                  child: Row(children: [
                    Icon(Icons.person_remove_outlined,
                        color: Colors.white70, size: 16),
                    SizedBox(width: 8),
                    Text('Supprimer', style: TextStyle(color: Colors.white)),
                  ]),
                ),
                PopupMenuItem(
                  value: 'block',
                  child: Row(children: [
                    Icon(Icons.block, color: Colors.redAccent, size: 16),
                    SizedBox(width: 8),
                    Text('Bloquer',
                        style: TextStyle(color: Colors.redAccent)),
                  ]),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RequestTile extends StatelessWidget {
  final String fromUser;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const _RequestTile({
    required this.fromUser,
    required this.onAccept,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: const Color(0xFF6C47FF).withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          UserAvatar(username: fromUser, radius: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fromUser.contains('@')
                      ? fromUser.split('@').first
                      : fromUser,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14),
                ),
                const Text("Demande d'ami",
                    style: TextStyle(color: Colors.white38, fontSize: 12)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.redAccent, size: 22),
            tooltip: 'Refuser',
            onPressed: onReject,
          ),
          IconButton(
            icon:
                const Icon(Icons.check, color: Colors.greenAccent, size: 22),
            tooltip: 'Accepter',
            onPressed: onAccept,
          ),
        ],
      ),
    );
  }
}

class _DiscoverTile extends StatelessWidget {
  final UserModel user;
  final bool isFriend;
  final VoidCallback? onAdd;
  final VoidCallback? onChat;

  const _DiscoverTile({
    required this.user,
    required this.isFriend,
    this.onAdd,
    this.onChat,
  });

  static const _roleColor = {
    'professeur': Color(0xFF6C47FF),
    'admin': Color(0xFFD97706),
    'eleve': Color(0xFF16A34A),
  };

  @override
  Widget build(BuildContext context) {
    final roleColor =
        _roleColor[user.role.value] ?? const Color(0xFF2563EB);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          UserAvatar(username: user.email, radius: 22, showStatus: true),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.displayName,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: roleColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    user.role.label,
                    style: TextStyle(
                        color: roleColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
          if (isFriend)
            TextButton.icon(
              onPressed: onChat,
              icon: const Icon(Icons.chat_bubble_outline,
                  size: 16, color: Color(0xFF2563EB)),
              label: const Text('Message',
                  style: TextStyle(color: Color(0xFF2563EB), fontSize: 12)),
            )
          else
            GestureDetector(
              onTap: onAdd,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.4)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.person_add_outlined,
                        size: 14, color: Color(0xFF2563EB)),
                    SizedBox(width: 5),
                    Text('Ajouter',
                        style: TextStyle(
                            color: Color(0xFF2563EB),
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
