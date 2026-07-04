import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/groupe_model.dart';
import '../models/user_model.dart';
import '../models/school_model.dart';
import '../services/groupe_service.dart';
import '../services/social_service.dart';
import '../services/user_service.dart';
import '../services/school_service.dart';
import '../services/scolar_gamification_service.dart';
import '../widgets/user_avatar.dart';
import 'scolar_chat_room_page.dart';
import 'scolar_profile_page.dart';
import 'scolar_salle_page.dart';
import 'scolar_groupe_detail_page.dart';

// ─── Constants ───────────────────────────────────────────────────────────────
const _bg = Color(0xFF0D1117);
const _card = Color(0xFF161B22);
const _card2 = Color(0xFF1F2937);
const _border = Color(0xFF21262D);
const _blue = Color(0xFF2563EB);
const _purple = Color(0xFF6C47FF);

String get _me => FirebaseAuth.instance.currentUser?.email ?? '';
String get _myName =>
    FirebaseAuth.instance.currentUser?.displayName ??
    _me.split('@').first;

// ─── Page principale ──────────────────────────────────────────────────────────

class SCOLARConnectPage extends StatefulWidget {
  const SCOLARConnectPage({super.key});

  @override
  State<SCOLARConnectPage> createState() => _SCOLARConnectPageState();
}

class _SCOLARConnectPageState extends State<SCOLARConnectPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: NestedScrollView(
        headerSliverBuilder: (_, __) => [
          SliverAppBar(
            expandedHeight: 90,
            floating: true,
            snap: true,
            pinned: true,
            backgroundColor: _card,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF1A1040), Color(0xFF0E0B2A), _bg],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
              title: Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [_purple, _blue]),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.hub_outlined,
                        color: Colors.white, size: 16),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'SCOLAR Connect',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.4,
                    ),
                  ),
                ],
              ),
              titlePadding:
                  const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 52),
            ),
            bottom: TabBar(
              controller: _tabs,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              indicatorColor: _purple,
              indicatorWeight: 2.5,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white38,
              labelStyle: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600),
              tabs: const [
                Tab(
                    icon: Icon(Icons.home_outlined, size: 16),
                    text: 'Accueil'),
                Tab(
                    icon: Icon(Icons.person_search_outlined,
                        size: 16),
                    text: 'Trouver'),
                Tab(
                    icon: Icon(Icons.groups_outlined, size: 16),
                    text: 'Groupes'),
                Tab(
                    icon: Icon(Icons.chat_bubble_outline, size: 16),
                    text: 'Messages'),
                Tab(
                    icon: Icon(Icons.folder_shared_outlined, size: 16),
                    text: 'Partage'),
              ],
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabs,
          children: [
            _AccueilTab(tabs: _tabs),
            const _TrouverTab(),
            const _GroupesTab(),
            const _MessagerieTab(),
            const _PartageTab(),
          ],
        ),
      ),
    );
  }
}

// ─── Tab 0 : Accueil ──────────────────────────────────────────────────────────

class _AccueilTab extends StatelessWidget {
  final TabController tabs;
  const _AccueilTab({required this.tabs});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<String>>(
      stream: SocialService.friendsStream(_me),
      builder: (context, snapFriends) {
        final friends = snapFriends.data ?? [];
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            _buildHeroCard(context, friends.length),
            const SizedBox(height: 16),
            _buildQuickActions(context),
            const SizedBox(height: 20),
            _buildCanauxSection(context),
            const SizedBox(height: 20),
            if (friends.isNotEmpty) ...[
              _buildConnexionsSection(context, friends),
              const SizedBox(height: 20),
            ],
            _buildBadgesSection(friends.length),
            const SizedBox(height: 20),
            _buildSallesSection(context),
            const SizedBox(height: 20),
            _buildObjectifsSection(context),
            const SizedBox(height: 20),
            _buildActivitySection(context),
            const SizedBox(height: 20),
            _buildProfilButton(context),
          ],
        );
      },
    );
  }

  Widget _buildHeroCard(BuildContext context, int friendCount) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A1040), Color(0xFF0F1B3D)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: _purple.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Bienvenue sur',
                    style: TextStyle(
                        color: Colors.white54, fontSize: 12)),
                const Text('SCOLAR Connect',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.3,
                    )),
                const SizedBox(height: 6),
                Text(
                  'Bonjour, ${_myName.split(' ').first}',
                  style: const TextStyle(
                      color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _StatChip(
                        icon: Icons.people_outline,
                        value: '$friendCount',
                        label: 'connexions'),
                    const SizedBox(width: 8),
                    _StatChip(
                        icon: Icons.groups_outlined,
                        value: '—',
                        label: 'groupes'),
                  ],
                ),
                const SizedBox(height: 10),
                // XP bar
                StreamBuilder<Map<String, dynamic>>(
                  stream: ScolarGamificationService.statsStream(
                      FirebaseAuth.instance.currentUser?.uid ?? ''),
                  builder: (context, snapStats) {
                    final stats = snapStats.data ?? {};
                    final xp = stats['xp'] as int? ?? 0;
                    final level = stats['level'] as int? ?? 1;
                    final xpProgress = (xp % 100) / 100.0;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                    colors: [_purple, _blue]),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Niv. $level',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                            Text(
                              '$xp XP',
                              style: const TextStyle(
                                  color: Colors.white38, fontSize: 11),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: xpProgress,
                            minHeight: 5,
                            backgroundColor: Colors.white12,
                            valueColor: const AlwaysStoppedAnimation<Color>(
                                _purple),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [_purple, _blue]),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(Icons.hub_outlined,
                color: Colors.white, size: 32),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    final actions = [
      (Icons.person_search_outlined, 'Trouver', const [Color(0xFF2563EB), Color(0xFF1D4ED8)], 1),
      (Icons.groups_2_outlined, 'Groupes', const [Color(0xFF6C47FF), Color(0xFF4F35C2)], 2),
      (Icons.chat_bubble_outline, 'Messages', const [Color(0xFF0D9488), Color(0xFF0F766E)], 3),
      (Icons.folder_shared_outlined, 'Partager', const [Color(0xFFD97706), Color(0xFFB45309)], 4),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader('Actions rapides'),
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: 4,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 0.85,
          children: actions.map((a) {
            final (icon, label, colors, tabIdx) = a;
            return _QuickActionCard(
              icon: icon,
              label: label,
              colors: colors,
              onTap: () => tabs.animateTo(tabIdx),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildCanauxSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader('Canaux'),
        const SizedBox(height: 10),
        _ChannelCard(
          icon: Icons.public,
          title: 'Canal Général',
          subtitle: 'Discussion ouverte à tous',
          colors: const [Color(0xFF2563EB), Color(0xFF1D4ED8)],
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SCOLARChatRoomPage(
                  name: 'general', user: _me, displayName: 'Général'),
            ),
          ),
        ),
        const SizedBox(height: 8),
        _ChannelCard(
          icon: Icons.school_outlined,
          title: 'Canal de Classe',
          subtitle: 'Messages de votre classe',
          colors: const [Color(0xFF6C47FF), Color(0xFF4F35C2)],
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SCOLARChatRoomPage(
                  name: 'Classe', user: _me, displayName: 'Classe'),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildConnexionsSection(BuildContext context, List<String> friends) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader('Mes connexions (${friends.length})'),
        const SizedBox(height: 10),
        SizedBox(
          height: 84,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: friends.length.clamp(0, 10),
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, i) {
              final email = friends[i];
              final name = email.split('@').first;
              return GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SCOLARChatRoomPage(
                        name: email, user: _me, displayName: name),
                  ),
                ),
                child: Column(
                  children: [
                    UserAvatar(
                        username: email, radius: 26, showStatus: true),
                    const SizedBox(height: 6),
                    Text(
                      name.length > 8
                          ? '${name.substring(0, 8)}…'
                          : name,
                      style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildBadgesSection(int friendCount) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader('Mes badges'),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _BadgeChip(
                emoji: '🌟',
                label: 'Explorateur',
                color: const Color(0xFFD97706),
                earned: true),
            _BadgeChip(
                emoji: '💬',
                label: 'Communicateur',
                color: _blue,
                earned: friendCount > 0),
            _BadgeChip(
                emoji: '🤝',
                label: 'Connecté',
                color: _purple,
                earned: friendCount >= 3),
            _BadgeChip(
                emoji: '📚',
                label: 'Partageur',
                color: const Color(0xFF0D9488),
                earned: false),
            _BadgeChip(
                emoji: '🏆',
                label: 'Leader',
                color: const Color(0xFFEC4899),
                earned: false),
          ],
        ),
      ],
    );
  }

  Widget _buildSallesSection(BuildContext context) {
    final salles = [
      ('Salle Mathématiques', 'Mathématiques'),
      ('Salle Sciences', 'Sciences'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader('Salles actives'),
        const SizedBox(height: 10),
        ...salles.map((s) {
          final (nom, matiere) = s;
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            child: InkWell(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      SCOLARSallePage(salleNom: nom, matiere: matiere),
                ),
              ),
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _card,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _border),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                            colors: [_purple, _blue]),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.meeting_room_outlined,
                          color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(nom,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600)),
                          Text(matiere,
                              style: const TextStyle(
                                  color: Colors.white38, fontSize: 12)),
                        ],
                      ),
                    ),
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                          color: Colors.greenAccent,
                          shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 4),
                    const Text('Active',
                        style: TextStyle(
                            color: Colors.greenAccent, fontSize: 11)),
                    const SizedBox(width: 6),
                    const Icon(Icons.chevron_right,
                        color: Colors.white24, size: 20),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildObjectifsSection(BuildContext context) {
    final objectifs = [
      ('Envoyer 5 messages', Icons.chat_bubble_outline, 0.4),
      ('Rejoindre 1 groupe', Icons.groups_outlined, 0.0),
      ('Partager 1 fiche', Icons.folder_shared_outlined, 0.0),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader('Objectifs de la semaine'),
        const SizedBox(height: 10),
        ...objectifs.map((o) {
          final (label, icon, progress) = o;
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _border),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: progress >= 1.0
                        ? const Color(0xFF16A34A).withValues(alpha: 0.15)
                        : _purple.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    progress >= 1.0 ? Icons.check_circle_outlined : icon,
                    color: progress >= 1.0
                        ? const Color(0xFF16A34A)
                        : _purple,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w500)),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 4,
                          backgroundColor: Colors.white12,
                          valueColor:
                              const AlwaysStoppedAnimation<Color>(_purple),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '${(progress * 100).round()}%',
                  style: const TextStyle(
                      color: Colors.white38, fontSize: 12),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildActivitySection(BuildContext context) {
    final activities = [
      (Icons.chat_bubble_outline, _blue, 'Vous avez envoyé un message dans Général', '2 min'),
      (Icons.group_add_outlined, _purple, 'Vous avez rejoint "Groupe Mathématiques"', '15 min'),
      (Icons.upload_outlined, const Color(0xFF0D9488), 'Vous avez partagé une fiche', '1 h'),
      (Icons.person_add_outlined, const Color(0xFFD97706), 'Nouvelle connexion ajoutée', '3 h'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader('Activité récente'),
        const SizedBox(height: 10),
        ...activities.map((a) {
          final (icon, color, text, time) = a;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(text,
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 12),
                          maxLines: 2),
                      Text(time,
                          style: const TextStyle(
                              color: Colors.white24, fontSize: 11)),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildProfilButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                SCOLARProfilePage(email: _me, isOwn: true),
          ),
        ),
        icon: const Icon(Icons.person_outline, size: 18),
        label: const Text('Mon profil SCOLAR'),
        style: OutlinedButton.styleFrom(
          foregroundColor: _purple,
          side: BorderSide(color: _purple.withValues(alpha: 0.5)),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }
}

// ─── Tab 1 : Trouver ──────────────────────────────────────────────────────────

class _TrouverTab extends StatefulWidget {
  const _TrouverTab();

  @override
  State<_TrouverTab> createState() => _TrouverTabState();
}

class _TrouverTabState extends State<_TrouverTab> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  String _cycleFilter = '';
  String _schoolFilter = '';
  late final Stream<List<UserModel>> _usersStream;
  late final Stream<List<String>> _friendsStream;
  late final Stream<List<SchoolModel>> _schoolsStream;

  final _cycles = [
    ('Tous', ''),
    ('Collège', 'Collège'),
    ('Lycée', 'Lycée'),
    ('Université', 'Université'),
    ('Primaire', 'Primaire'),
    ('Maternelle', 'Maternelle'),
  ];

  @override
  void initState() {
    super.initState();
    _usersStream = UserService.allUsersStream();
    _friendsStream = SocialService.friendsStream(_me);
    _schoolsStream = SchoolService.allSchoolsStream();
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
        _buildSearchBar(),
        _buildCycleFilters(),
        _buildSchoolFilters(),
        Expanded(child: _buildUserList()),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      color: _card,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      child: TextField(
        controller: _searchCtrl,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Nom, classe, matière, spécialité…',
          hintStyle: const TextStyle(color: Colors.white38),
          prefixIcon: const Icon(Icons.search, color: Colors.white38, size: 20),
          suffixIcon: _query.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear,
                      color: Colors.white38, size: 18),
                  onPressed: _searchCtrl.clear,
                )
              : null,
          filled: true,
          fillColor: _card2,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _buildCycleFilters() {
    return Container(
      color: _card,
      height: 42,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        children: _cycles.map((c) {
          final (label, value) = c;
          final selected = _cycleFilter == value;
          return GestureDetector(
            onTap: () => setState(() => _cycleFilter = value),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 5),
              decoration: BoxDecoration(
                gradient: selected
                    ? const LinearGradient(
                        colors: [_purple, _blue])
                    : null,
                color: selected ? null : _card2,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: selected
                      ? Colors.transparent
                      : _border,
                ),
              ),
              child: Text(
                label,
                style: TextStyle(
                  color: selected
                      ? Colors.white
                      : Colors.white54,
                  fontSize: 12,
                  fontWeight: selected
                      ? FontWeight.w700
                      : FontWeight.normal,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSchoolFilters() {
    return StreamBuilder<List<SchoolModel>>(
      stream: _schoolsStream,
      builder: (context, snap) {
        final schools = snap.data ?? [];
        if (schools.isEmpty) return const SizedBox.shrink();
        return Container(
          color: _card,
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            children: [
              _schoolChip('Tous établissements', ''),
              ...schools.map((s) => _schoolChip(s.nom, s.id)),
            ],
          ),
        );
      },
    );
  }

  Widget _schoolChip(String label, String value) {
    final selected = _schoolFilter == value;
    return GestureDetector(
      onTap: () => setState(() => _schoolFilter = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          gradient: selected
              ? const LinearGradient(colors: [Color(0xFF0D9488), _blue])
              : null,
          color: selected ? null : _card2,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? Colors.transparent : _border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.school_outlined, size: 11, color: Colors.white54),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : Colors.white54,
                fontSize: 11,
                fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserList() {
    return StreamBuilder<List<UserModel>>(
      stream: _usersStream,
      builder: (context, snapUsers) {
        return StreamBuilder<List<String>>(
          stream: _friendsStream,
          builder: (context, snapFriends) {
            if (snapUsers.connectionState ==
                ConnectionState.waiting) {
              return const Center(
                  child: CircularProgressIndicator(
                      color: _purple));
            }
            final all = (snapUsers.data ?? [])
                .where((u) => u.email != _me)
                .toList();
            final friends = snapFriends.data ?? [];

            var filtered = all;
            if (_cycleFilter.isNotEmpty) {
              filtered = filtered
                  .where((u) =>
                      (u.categorie ?? '').toLowerCase() ==
                      _cycleFilter.toLowerCase())
                  .toList();
            }
            if (_schoolFilter.isNotEmpty) {
              filtered = filtered
                  .where((u) =>
                      (u.schoolId.isEmpty
                          ? kDefaultSchoolId
                          : u.schoolId) ==
                      _schoolFilter)
                  .toList();
            }
            if (_query.isNotEmpty) {
              filtered = filtered
                  .where((u) =>
                      u.displayName
                          .toLowerCase()
                          .contains(_query) ||
                      u.email
                          .toLowerCase()
                          .contains(_query) ||
                      (u.classeNom ?? '')
                          .toLowerCase()
                          .contains(_query) ||
                      (u.niveau ?? '')
                          .toLowerCase()
                          .contains(_query) ||
                      (u.matiere ?? '')
                          .toLowerCase()
                          .contains(_query))
                  .toList();
            }

            if (filtered.isEmpty) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                        Icons.person_search_outlined,
                        color: Colors.white24,
                        size: 56),
                    const SizedBox(height: 14),
                    Text(
                      all.isEmpty
                          ? 'Aucun utilisateur inscrit'
                          : 'Aucun résultat',
                      style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 16,
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(
                  14, 10, 14, 32),
              itemCount: filtered.length,
              itemBuilder: (_, i) {
                final u = filtered[i];
                final isFriend =
                    friends.contains(u.email);
                return _UserConnectCard(
                  user: u,
                  isFriend: isFriend,
                  onMessage: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SCOLARChatRoomPage(
                        name: u.email,
                        user: _me,
                        displayName: u.displayName.isNotEmpty
                            ? u.displayName
                            : null,
                      ),
                    ),
                  ),
                  onConnect: isFriend
                      ? null
                      : () => SocialService.sendFriendRequest(
                          _me, u.email),
                );
              },
            );
          },
        );
      },
    );
  }
}

// ─── Tab 2 : Groupes ──────────────────────────────────────────────────────────

class _GroupesTab extends StatefulWidget {
  const _GroupesTab();

  @override
  State<_GroupesTab> createState() => _GroupesTabState();
}

class _GroupesTabState extends State<_GroupesTab> {
  bool _mesGroupesOnly = false;

  Future<void> _showCreateDialog() async {
    final nomCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final matiereCtrl = TextEditingController();
    final niveauCtrl = TextEditingController();
    GroupeType typeSelected = GroupeType.public;

    await showDialog<void>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          backgroundColor: _card,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20)),
          title: const Row(children: [
            Icon(Icons.group_add_outlined, color: _purple, size: 22),
            SizedBox(width: 10),
            Text('Créer un groupe',
                style: TextStyle(color: Colors.white, fontSize: 16)),
          ]),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _DialogField(ctrl: nomCtrl, hint: 'Nom du groupe *'),
                const SizedBox(height: 8),
                _DialogField(
                    ctrl: descCtrl, hint: 'Description (optionnel)', maxLines: 2),
                const SizedBox(height: 8),
                _DialogField(
                    ctrl: matiereCtrl, hint: 'Matière (ex: Mathématiques)'),
                const SizedBox(height: 8),
                _DialogField(
                    ctrl: niveauCtrl, hint: 'Niveau (ex: Terminale, L2…)'),
                const SizedBox(height: 12),
                const Text('Visibilité',
                    style: TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  children: GroupeType.values.map((t) => ChoiceChip(
                    label: Text(t.label),
                    selected: typeSelected == t,
                    onSelected: (_) => setSt(() => typeSelected = t),
                    backgroundColor: _card2,
                    selectedColor: _purple,
                    labelStyle: TextStyle(
                        color: typeSelected == t
                            ? Colors.white
                            : Colors.white54,
                        fontSize: 12),
                  )).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler',
                  style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _purple,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () async {
                final nom = nomCtrl.text.trim();
                if (nom.isEmpty) return;
                Navigator.pop(ctx);
                try {
                  final id = await GroupeService.creerGroupe(
                    nom: nom,
                    description: descCtrl.text.trim(),
                    matiere: matiereCtrl.text.trim(),
                    niveau: niveauCtrl.text.trim(),
                    type: typeSelected,
                  );
                  if (mounted) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SCOLARGroupeDetailPage(
                          groupeId: id,
                          groupeNom: nom,
                          groupeData: {
                            'id': id,
                            'nom': nom,
                            'matiere': matiereCtrl.text.trim(),
                            'niveau': niveauCtrl.text.trim(),
                            'type': typeSelected.value,
                          },
                        ),
                      ),
                    );
                  }
                } catch (_) {}
              },
              child: const Text('Créer'),
            ),
          ],
        ),
      ),
    );
    nomCtrl.dispose();
    descCtrl.dispose();
    matiereCtrl.dispose();
    niveauCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateDialog,
        backgroundColor: _purple,
        icon: const Icon(Icons.group_add_outlined),
        label: const Text('Nouveau groupe'),
      ),
      body: Column(
        children: [
          // Filtre Tous / Mes groupes
          Container(
            color: _card,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              children: [
                _FilterChip(
                  label: 'Tous',
                  selected: !_mesGroupesOnly,
                  onTap: () => setState(() => _mesGroupesOnly = false),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Mes groupes',
                  selected: _mesGroupesOnly,
                  onTap: () => setState(() => _mesGroupesOnly = true),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<GroupeModel>>(
              stream: _mesGroupesOnly
                  ? GroupeService.mesGroupesStream()
                  : GroupeService.tousGroupesStream(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child: CircularProgressIndicator(color: _purple));
                }
                final groups = snap.data ?? [];
                if (groups.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                                colors: [_purple, _blue]),
                            borderRadius: BorderRadius.circular(22),
                          ),
                          child: const Icon(Icons.groups_outlined,
                              color: Colors.white54, size: 40),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          _mesGroupesOnly
                              ? 'Vous n\'avez rejoint aucun groupe'
                              : 'Aucun groupe de révision',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                            'Créez un groupe pour réviser ensemble !',
                            style: TextStyle(
                                color: Colors.white38, fontSize: 13)),
                        const SizedBox(height: 100),
                      ],
                    ),
                  );
                }
                return ListView.builder(
                  padding:
                      const EdgeInsets.fromLTRB(14, 14, 14, 100),
                  itemCount: groups.length,
                  itemBuilder: (_, i) =>
                      _GroupModelCard(groupe: groups[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          gradient: selected
              ? const LinearGradient(colors: [_purple, _blue])
              : null,
          color: selected ? null : _card2,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? Colors.transparent : _border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : Colors.white54,
            fontSize: 12,
            fontWeight:
                selected ? FontWeight.w700 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

class _GroupModelCard extends StatelessWidget {
  final GroupeModel groupe;
  const _GroupModelCard({required this.groupe});

  static const _gradients = [
    [Color(0xFF6C47FF), Color(0xFF4F35C2)],
    [Color(0xFF2563EB), Color(0xFF1D4ED8)],
    [Color(0xFF0D9488), Color(0xFF0F766E)],
    [Color(0xFFD97706), Color(0xFFB45309)],
    [Color(0xFFDC2626), Color(0xFFEA580C)],
  ];

  @override
  Widget build(BuildContext context) {
    final hash = groupe.nom.length % _gradients.length;
    final grad = _gradients[hash];
    final initiale =
        groupe.nom.isNotEmpty ? groupe.nom[0].toUpperCase() : 'G';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SCOLARGroupeDetailPage(
              groupeId: groupe.id,
              groupeNom: groupe.nom,
              groupeData: {
                'id':      groupe.id,
                'nom':     groupe.nom,
                'matiere': groupe.matiere,
                'niveau':  groupe.niveau,
                'type':    groupe.type.value,
                'creatorEmail': groupe.creatorEmail,
                'creatorUid':   groupe.creatorUid,
              },
            ),
          ),
        ),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _border),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: grad),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Text(initiale,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            groupe.nom,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        _TypeChip(type: groupe.type),
                      ],
                    ),
                    if (groupe.matiere.isNotEmpty ||
                        groupe.niveau.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        [groupe.matiere, groupe.niveau]
                            .where((s) => s.isNotEmpty)
                            .join(' · '),
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (groupe.description.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        groupe.description,
                        style: const TextStyle(
                            color: Colors.white38, fontSize: 11),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.people_outline,
                            color: Colors.white24, size: 13),
                        const SizedBox(width: 3),
                        Text('${groupe.memberCount} membre(s)',
                            style: const TextStyle(
                                color: Colors.white38, fontSize: 11)),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right,
                  color: Colors.white24, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  final GroupeType type;
  const _TypeChip({required this.type});

  Color get _color => switch (type) {
        GroupeType.public  => const Color(0xFF16A34A),
        GroupeType.prive   => const Color(0xFFD97706),
        GroupeType.classe  => const Color(0xFF2563EB),
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        type.label,
        style: TextStyle(
            color: _color, fontSize: 10, fontWeight: FontWeight.w600),
      ),
    );
  }
}

// ─── Tab 3 : Messages ─────────────────────────────────────────────────────────

class _MessagerieTab extends StatefulWidget {
  const _MessagerieTab();

  @override
  State<_MessagerieTab> createState() => _MessagerieTabState();
}

class _MessagerieTabState extends State<_MessagerieTab> {
  late final Stream<List<String>> _contactsStream;
  late final Stream<List<String>> _friendsStream;

  @override
  void initState() {
    super.initState();
    _contactsStream = SocialService.contactsStream(_me);
    _friendsStream = SocialService.friendsStream(_me);
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 32),
      children: [
        const _SectionHeader('Canaux'),
        const SizedBox(height: 10),
        _ChannelCard(
          icon: Icons.public,
          title: 'Canal Général',
          subtitle: 'Discussion ouverte',
          colors: const [Color(0xFF2563EB), Color(0xFF1D4ED8)],
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SCOLARChatRoomPage(
                  name: 'general',
                  user: _me,
                  displayName: 'Général'),
            ),
          ),
        ),
        const SizedBox(height: 8),
        _ChannelCard(
          icon: Icons.school_outlined,
          title: 'Canal de Classe',
          subtitle: 'Votre classe',
          colors: const [Color(0xFF6C47FF), Color(0xFF4F35C2)],
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SCOLARChatRoomPage(
                  name: 'Classe',
                  user: _me,
                  displayName: 'Classe'),
            ),
          ),
        ),
        const SizedBox(height: 20),
        const _SectionHeader('Conversations privées'),
        const SizedBox(height: 10),
        StreamBuilder<List<String>>(
          stream: _friendsStream,
          builder: (context, snapFriends) {
            return StreamBuilder<List<String>>(
              stream: _contactsStream,
              builder: (context, snapContacts) {
                final friends = snapFriends.data ?? [];
                final contacts = snapContacts.data ?? [];
                final merged = {
                  ...friends,
                  ...contacts
                }.where((e) => e != _me).toList();

                if (merged.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: _card,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _border),
                    ),
                    child: const Column(
                      children: [
                        Icon(Icons.chat_bubble_outline,
                            color: Colors.white24, size: 36),
                        SizedBox(height: 10),
                        Text('Aucune conversation',
                            style: TextStyle(
                                color: Colors.white54,
                                fontSize: 14)),
                        SizedBox(height: 4),
                        Text(
                          'Trouvez des camarades dans l\'onglet Trouver',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: Colors.white24,
                              fontSize: 12),
                        ),
                      ],
                    ),
                  );
                }
                return Column(
                  children: merged
                      .map((email) => Padding(
                            padding:
                                const EdgeInsets.only(bottom: 8),
                            child: _ConvTile(
                              email: email,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      SCOLARChatRoomPage(
                                    name: email,
                                    user: _me,
                                    displayName:
                                        email.split('@').first,
                                  ),
                                ),
                              ),
                            ),
                          ))
                      .toList(),
                );
              },
            );
          },
        ),
      ],
    );
  }
}

// ─── Tab 4 : Partage ──────────────────────────────────────────────────────────

class _PartageTab extends StatefulWidget {
  const _PartageTab();

  @override
  State<_PartageTab> createState() => _PartageTabState();
}

class _PartageTabState extends State<_PartageTab> {
  final _fs = FirebaseFirestore.instance;
  String _filterType = '';

  final _types = [
    ('Tout', ''),
    ('Fiche', 'fiche'),
    ('Cours', 'cours'),
    ('QCM', 'qcm'),
    ('PDF', 'pdf'),
  ];

  Query get _query {
    var q = _fs
        .collection('scolar_partages')
        .orderBy('createdAt', descending: true)
        .limit(50);
    return q;
  }

  Future<void> _showPartageDialog() async {
    final titreCtrl = TextEditingController();
    final matiereCtrl = TextEditingController();
    final contenuCtrl = TextEditingController();
    String type = 'fiche';
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          backgroundColor: _card,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20)),
          title: const Row(children: [
            Icon(Icons.upload_outlined, color: _blue, size: 22),
            SizedBox(width: 10),
            Text('Partager',
                style: TextStyle(color: Colors.white, fontSize: 16)),
          ]),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _DialogField(ctrl: titreCtrl, hint: 'Titre'),
                const SizedBox(height: 10),
                _DialogField(ctrl: matiereCtrl, hint: 'Matière'),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  children: ['fiche', 'cours', 'qcm', 'pdf'].map((t) {
                    return ChoiceChip(
                      label: Text(t.toUpperCase()),
                      selected: type == t,
                      onSelected: (_) => setSt(() => type = t),
                      backgroundColor: _card2,
                      selectedColor: _purple,
                      labelStyle: TextStyle(
                          color: type == t
                              ? Colors.white
                              : Colors.white54,
                          fontSize: 11),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 10),
                _DialogField(
                    ctrl: contenuCtrl,
                    hint: 'Contenu ou résumé…',
                    maxLines: 4),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler',
                  style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _blue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () async {
                final titre = titreCtrl.text.trim();
                if (titre.isEmpty) return;
                Navigator.pop(ctx);
                await _fs.collection('scolar_partages').add({
                  'titre': titre,
                  'matiere': matiereCtrl.text.trim(),
                  'type': type,
                  'contenu': contenuCtrl.text.trim(),
                  'auteurEmail': _me,
                  'auteurNom': _myName,
                  'createdAt': FieldValue.serverTimestamp(),
                });
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Document partagé !'),
                      backgroundColor: Color(0xFF16A34A),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
              child: const Text('Partager'),
            ),
          ],
        ),
      ),
    );
    titreCtrl.dispose();
    matiereCtrl.dispose();
    contenuCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showPartageDialog,
        backgroundColor: _blue,
        icon: const Icon(Icons.upload_outlined),
        label: const Text('Partager'),
      ),
      body: Column(
        children: [
          Container(
            color: _card,
            height: 42,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 5),
              children: _types.map((t) {
                final (label, value) = t;
                final sel = _filterType == value;
                return GestureDetector(
                  onTap: () =>
                      setState(() => _filterType = value),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 5),
                    decoration: BoxDecoration(
                      gradient: sel
                          ? const LinearGradient(
                              colors: [_blue, Color(0xFF1D4ED8)])
                          : null,
                      color: sel ? null : _card2,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: sel ? Colors.transparent : _border),
                    ),
                    child: Text(label,
                        style: TextStyle(
                            color: sel
                                ? Colors.white
                                : Colors.white54,
                            fontSize: 12,
                            fontWeight: sel
                                ? FontWeight.w700
                                : FontWeight.normal)),
                  ),
                );
              }).toList(),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _query.snapshots(),
              builder: (context, snap) {
                if (snap.connectionState ==
                    ConnectionState.waiting) {
                  return const Center(
                      child: CircularProgressIndicator(
                          color: _blue));
                }
                var docs = snap.data?.docs ?? [];
                if (_filterType.isNotEmpty) {
                  docs = docs
                      .where((d) =>
                          (d['type'] as String? ?? '') ==
                          _filterType)
                      .toList();
                }
                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                                colors: [_blue, Color(0xFF1D4ED8)]),
                            borderRadius:
                                BorderRadius.circular(20),
                          ),
                          child: const Icon(
                              Icons.folder_shared_outlined,
                              color: Colors.white54,
                              size: 36),
                        ),
                        const SizedBox(height: 18),
                        const Text('Aucun document partagé',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600)),
                        const SizedBox(height: 6),
                        const Text(
                            'Partagez des fiches avec vos camarades !',
                            style: TextStyle(
                                color: Colors.white38,
                                fontSize: 13)),
                        const SizedBox(height: 100),
                      ],
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(
                      14, 14, 14, 100),
                  itemCount: docs.length,
                  itemBuilder: (_, i) {
                    final d =
                        docs[i].data() as Map<String, dynamic>;
                    return _PartageCard(data: d);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Helper Widgets ───────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white70,
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  const _StatChip(
      {required this.icon, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white70, size: 14),
          const SizedBox(width: 5),
          Text(
            '$value $label',
            style: const TextStyle(
                color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _BadgeChip extends StatelessWidget {
  final String emoji;
  final String label;
  final Color color;
  final bool earned;
  const _BadgeChip(
      {required this.emoji,
      required this.label,
      required this.color,
      required this.earned});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: earned
            ? color.withValues(alpha: 0.15)
            : _card2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color:
              earned ? color.withValues(alpha: 0.5) : _border,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji,
              style: TextStyle(
                  fontSize: 14,
                  color: earned ? null : Colors.grey)),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: earned ? color : Colors.white24,
              fontSize: 12,
              fontWeight: earned
                  ? FontWeight.w700
                  : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final List<Color> colors;
  final VoidCallback onTap;
  const _QuickActionCard(
      {required this.icon,
      required this.label,
      required this.colors,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _border),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: colors),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
            const SizedBox(height: 7),
            Text(label,
                style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w600),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _ChannelCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final List<Color> colors;
  final VoidCallback onTap;
  const _ChannelCard(
      {required this.icon,
      required this.title,
      required this.subtitle,
      required this.colors,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _border),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: colors),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600)),
                  Text(subtitle,
                      style: const TextStyle(
                          color: Colors.white38, fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right,
                color: Colors.white24, size: 20),
          ],
        ),
      ),
    );
  }
}

class _UserConnectCard extends StatelessWidget {
  final UserModel user;
  final bool isFriend;
  final VoidCallback? onMessage;
  final VoidCallback? onConnect;

  const _UserConnectCard({
    required this.user,
    required this.isFriend,
    this.onMessage,
    this.onConnect,
  });

  static const _cycleColors = {
    'lycée': Color(0xFF6C47FF),
    'collège': Color(0xFF2563EB),
    'université': Color(0xFF0D9488),
    'primaire': Color(0xFF16A34A),
    'maternelle': Color(0xFFD97706),
  };

  @override
  Widget build(BuildContext context) {
    final cycle = (user.categorie ?? '').toLowerCase();
    final cycleColor =
        _cycleColors[cycle] ?? const Color(0xFF2563EB);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          UserAvatar(
              username: user.email,
              radius: 24,
              showStatus: true,
              photoUrl: (user.photoUrl?.isNotEmpty == true)
                  ? user.photoUrl
                  : null),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    user.displayName.isNotEmpty
                        ? user.displayName
                        : user.email.split('@').first,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    if (user.categorie?.isNotEmpty == true)
                      _MiniTag(
                          text: user.categorie!,
                          color: cycleColor),
                    if (user.classeNom?.isNotEmpty == true)
                      _MiniTag(
                          text: user.classeNom!,
                          color: Colors.white38),
                    if (user.matiere != null &&
                        user.matiere!.isNotEmpty)
                      _MiniTag(
                          text: user.matiere!,
                          color: const Color(0xFF0D9488)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            children: [
              if (isFriend)
                IconButton(
                  onPressed: onMessage,
                  icon: const Icon(Icons.chat_bubble_outline,
                      color: _blue, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: 'Message',
                )
              else
                GestureDetector(
                  onTap: onConnect,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [_purple, _blue]),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('+ Connecter',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600)),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniTag extends StatelessWidget {
  final String text;
  final Color color;
  const _MiniTag({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(text,
          style: TextStyle(
              color: color, fontSize: 10, fontWeight: FontWeight.w600)),
    );
  }
}


class _ConvTile extends StatelessWidget {
  final String email;
  final VoidCallback onTap;
  const _ConvTile({required this.email, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final name = email.contains('@')
        ? email.split('@').first
        : email;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _border),
        ),
        child: Row(
          children: [
            UserAvatar(
                username: email, radius: 22, showStatus: true),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500)),
                  const Text('Appuyez pour discuter',
                      style: TextStyle(
                          color: Colors.white38, fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.chat_bubble_outline,
                color: _blue, size: 18),
          ],
        ),
      ),
    );
  }
}

class _PartageCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _PartageCard({required this.data});

  static const _typeColors = {
    'fiche': Color(0xFF6C47FF),
    'cours': Color(0xFF2563EB),
    'qcm': Color(0xFF16A34A),
    'pdf': Color(0xFFD97706),
  };

  static const _typeIcons = {
    'fiche': Icons.description_outlined,
    'cours': Icons.menu_book_outlined,
    'qcm': Icons.quiz_outlined,
    'pdf': Icons.picture_as_pdf_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final titre = data['titre'] as String? ?? '';
    final type = data['type'] as String? ?? 'fiche';
    final matiere = data['matiere'] as String? ?? '';
    final auteur = data['auteurNom'] as String? ?? '';
    final contenu = data['contenu'] as String? ?? '';
    final color =
        _typeColors[type] ?? const Color(0xFF2563EB);
    final icon = _typeIcons[type] ?? Icons.description_outlined;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: color.withValues(alpha: 0.3)),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titre,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(type.toUpperCase(),
                          style: TextStyle(
                              color: color,
                              fontSize: 9,
                              fontWeight: FontWeight.w700)),
                    ),
                    if (matiere.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Text(matiere,
                          style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 11)),
                    ],
                  ],
                ),
                if (contenu.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(contenu,
                      style: const TextStyle(
                          color: Colors.white38, fontSize: 12),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                ],
                const SizedBox(height: 4),
                Text('par $auteur',
                    style: const TextStyle(
                        color: Colors.white24, fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DialogField extends StatelessWidget {
  final TextEditingController ctrl;
  final String hint;
  final int maxLines;
  const _DialogField(
      {required this.ctrl,
      required this.hint,
      this.maxLines = 1});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      minLines: 1,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white38),
        filled: true,
        fillColor: _card2,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
