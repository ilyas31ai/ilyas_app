import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/social_service.dart';
import '../widgets/shimmer_box.dart';
import '../widgets/user_avatar.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String get _user => FirebaseAuth.instance.currentUser?.email ?? '';
  String get _name {
    final u = FirebaseAuth.instance.currentUser?.email ?? '';
    return u.contains('@') ? u.split('@').first : u;
  }

  late final Stream<List<String>> _contactsStream;

  @override
  void initState() {
    super.initState();
    final user = _user;
    _contactsStream = user.isNotEmpty
        ? SocialService.contactsStream(user)
        : const Stream.empty();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildHeader(context)),
            SliverToBoxAdapter(child: _buildBanner(context)),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _buildSectionLabel('Navigation rapide'),
                  const SizedBox(height: 10),
                  _buildQuickGrid(context),
                  const SizedBox(height: 22),
                  _buildSectionLabel('Outils'),
                  const SizedBox(height: 10),
                  _buildToolsList(context),
                  const SizedBox(height: 22),
                  _buildSectionLabel('Activité récente'),
                  const SizedBox(height: 10),
                  _buildRecentMessages(context),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Header ───────────────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
      child: Row(
        children: [
          UserAvatar(username: _user, radius: 22, showStatus: false),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bonjour, $_name 👋',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Text(
                  'SCOLAR AI · ILYAS31AI',
                  style: TextStyle(color: Colors.white38, fontSize: 11),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.notifications_outlined, color: Colors.white60),
            onPressed: () => Navigator.pushNamed(context, '/notifications'),
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white30, size: 20),
            onPressed: () => FirebaseAuth.instance.signOut(),
          ),
        ],
      ),
    );
  }

  // ─── Hero Banner ──────────────────────────────────────────────────────────

  Widget _buildBanner(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6C47FF), Color(0xFF2563EB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Plateforme scolaire',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Chat IA · Révision · Messagerie',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () => Navigator.pushNamed(context, '/chat'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Démarrer le Chat IA →',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.auto_awesome, color: Colors.white24, size: 52),
        ],
      ),
    );
  }

  // ─── Quick Grid ───────────────────────────────────────────────────────────

  Widget _buildSectionLabel(String text) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        color: Colors.white38,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildQuickGrid(BuildContext context) {
    const items = [
      _QItem(Icons.auto_awesome, 'Chat IA', [Color(0xFF6C47FF), Color(0xFF2563EB)], '/chat'),
      _QItem(Icons.school, 'Révision', [Color(0xFF2563EB), Color(0xFF0891B2)], '/eleves'),
      _QItem(Icons.message, 'Messages', [Color(0xFF15803D), Color(0xFF16A34A)], '/users'),
      _QItem(Icons.people, 'Amis', [Color(0xFF7C3AED), Color(0xFF6C47FF)], '/amis'),
      _QItem(Icons.child_care, 'Enfants', [Color(0xFFBE185D), Color(0xFF7C3AED)], '/monde_enfants'),
      _QItem(Icons.notifications, 'Alertes', [Color(0xFF374151), Color(0xFF1F2937)], '/notifications'),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 1.05,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: items.length,
      itemBuilder: (_, i) {
        final item = items[i];
        return _QuickGridCell(item: item);
      },
    );
  }

  // ─── Tools List ───────────────────────────────────────────────────────────

  Widget _buildToolsList(BuildContext context) {
    return Column(
      children: [
        _ToolCard(
          icon: Icons.camera_alt,
          title: 'Scan devoirs',
          subtitle: 'Photographier et analyser',
          colors: const [Color(0xFF0F766E), Color(0xFF0891B2)],
          onTap: () => Navigator.pushNamed(context, '/scan'),
        ),
        const SizedBox(height: 8),
        _ToolCard(
          icon: Icons.chat_bubble_rounded,
          title: 'Discussion classe',
          subtitle: 'Chat avec toute la classe',
          colors: const [Color(0xFF7C3AED), Color(0xFF6C47FF)],
          onTap: () => Navigator.pushNamed(
            context,
            '/discussion',
            arguments: {
              'name': 'Classe',
              'user': FirebaseAuth.instance.currentUser?.email ?? '',
            },
          ),
        ),
        const SizedBox(height: 8),
        _ToolCard(
          icon: Icons.person,
          title: 'Professeurs',
          subtitle: 'Gérer vos professeurs',
          colors: const [Color(0xFFD97706), Color(0xFFDC2626)],
          onTap: () => Navigator.pushNamed(context, '/professeurs'),
        ),
      ],
    );
  }

  // ─── Recent Messages ──────────────────────────────────────────────────────

  Widget _buildRecentMessages(BuildContext context) {
    final user = _user;
    if (user.isEmpty) return const SizedBox.shrink();

    return StreamBuilder<List<String>>(
      stream: _contactsStream,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return Column(
            children: List.generate(
              2,
              (_) => Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF161B22),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  children: [
                    ShimmerBox(width: 40, height: 40, radius: 20),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ShimmerBox(width: 100, height: 12),
                          SizedBox(height: 6),
                          ShimmerBox(width: 160, height: 10),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final contacts = snap.data ?? [];
        if (contacts.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF161B22),
              borderRadius: BorderRadius.circular(14),
              border:
                  Border.all(color: Colors.white.withValues(alpha: 0.05)),
            ),
            child: const Center(
              child: Text(
                'Aucun contact récent',
                style: TextStyle(color: Colors.white38, fontSize: 13),
              ),
            ),
          );
        }

        final preview = contacts.take(3).toList();
        return Column(
          children: preview.map((contact) {
            return _RecentContactTile(
              key: ValueKey(contact),
              contact: contact,
              user: user,
              onTap: () => Navigator.pushNamed(
                context,
                '/discussion',
                arguments: {'name': contact, 'user': user},
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

// ─── Quick Grid Cell ──────────────────────────────────────────────────────────

class _QItem {
  final IconData icon;
  final String label;
  final List<Color> colors;
  final String route;
  const _QItem(this.icon, this.label, this.colors, this.route);
}

class _QuickGridCell extends StatelessWidget {
  final _QItem item;
  const _QuickGridCell({required this.item});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.pushNamed(context, item.route),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF161B22),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: item.colors),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(item.icon, color: Colors.white, size: 22),
            ),
            const SizedBox(height: 8),
            Text(
              item.label,
              style: const TextStyle(
                  color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Tool Card ────────────────────────────────────────────────────────────────

class _ToolCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final List<Color> colors;
  final VoidCallback onTap;

  const _ToolCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: const Color(0xFF161B22),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: colors),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14)),
                  Text(subtitle,
                      style:
                          const TextStyle(color: Colors.white38, fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white24, size: 20),
          ],
        ),
      ),
    );
  }
}

// ─── Recent Contact Tile ──────────────────────────────────────────────────────
// StatefulWidget : stream stocké en initState → stable sur les rebuilds du parent

class _RecentContactTile extends StatefulWidget {
  final String contact;
  final String user;
  final VoidCallback onTap;

  const _RecentContactTile({
    super.key,
    required this.contact,
    required this.user,
    required this.onTap,
  });

  @override
  State<_RecentContactTile> createState() => _RecentContactTileState();
}

class _RecentContactTileState extends State<_RecentContactTile> {
  late final Stream<List<Map<String, dynamic>>> _msgStream;

  String get _displayName => widget.contact.contains('@')
      ? widget.contact.split('@').first
      : widget.contact;

  @override
  void initState() {
    super.initState();
    final chatId = SocialService.chatId(widget.user, widget.contact);
    _msgStream = SocialService.messagesStream(chatId);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _msgStream,
      builder: (context, snap) {
        final msgs = snap.data ?? [];
        final lastText = msgs.isNotEmpty
            ? (msgs.last['text'] as String? ?? '')
            : 'Aucun message';

        return InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF161B22),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: Colors.white.withValues(alpha: 0.05)),
            ),
            child: Row(
              children: [
                UserAvatar(
                    username: widget.contact, radius: 20, showStatus: true),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _displayName,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 13),
                      ),
                      Text(
                        lastText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white38, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right,
                    color: Colors.white24, size: 18),
              ],
            ),
          ),
        );
      },
    );
  }
}
