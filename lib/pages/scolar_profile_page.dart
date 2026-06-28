import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../services/user_service.dart';
import '../services/scolar_gamification_service.dart';
import '../widgets/user_avatar.dart';
import 'scolar_chat_room_page.dart';

// ─── Constants ───────────────────────────────────────────────────────────────
const _spBg = Color(0xFF0D1117);
const _spCard = Color(0xFF161B22);
const _spCard2 = Color(0xFF1F2937);
const _spBorder = Color(0xFF21262D);
const _spBlue = Color(0xFF2563EB);
const _spPurple = Color(0xFF6C47FF);

// ─── Page ─────────────────────────────────────────────────────────────────────

class SCOLARProfilePage extends StatefulWidget {
  final String email;
  final bool isOwn;

  const SCOLARProfilePage({
    super.key,
    required this.email,
    this.isOwn = false,
  });

  @override
  State<SCOLARProfilePage> createState() => _SCOLARProfilePageState();
}

class _SCOLARProfilePageState extends State<SCOLARProfilePage> {
  String get _me => FirebaseAuth.instance.currentUser?.email ?? '';
  String get _myName =>
      FirebaseAuth.instance.currentUser?.displayName ??
      _me.split('@').first;

  final _availabilityOptions = ['En ligne', 'Occupé', 'Absent'];
  String _availability = 'En ligne';

  Future<void> _editBio(BuildContext context, String currentBio) async {
    final ctrl = TextEditingController(text: currentBio);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _spCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Modifier la bio',
            style: TextStyle(color: Colors.white, fontSize: 16)),
        content: TextField(
          controller: ctrl,
          maxLines: 4,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Parlez de vous…',
            hintStyle: const TextStyle(color: Colors.white38),
            filled: true,
            fillColor: _spCard2,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child:
                const Text('Annuler', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _spPurple,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (ok == true && mounted) {
      await UserService.updateProfile({'bio': ctrl.text.trim()});
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<UserModel?>(
      stream: UserService.currentUserStream(),
      builder: (context, snapUser) {
        final user = snapUser.data;
        final uid = user?.uid ?? '';
        return StreamBuilder<Map<String, dynamic>>(
          stream: ScolarGamificationService.statsStream(uid),
          builder: (context, snapStats) {
            final stats = snapStats.data ?? {};
            return _buildScaffold(context, user, stats);
          },
        );
      },
    );
  }

  Widget _buildScaffold(
      BuildContext context, UserModel? user, Map<String, dynamic> stats) {
    final displayName = widget.isOwn
        ? (_myName.isNotEmpty ? _myName : widget.email.split('@').first)
        : (user?.displayName.isNotEmpty == true
            ? user!.displayName
            : widget.email.split('@').first);
    final bio = widget.isOwn ? (user?.bio ?? '') : '';
    final role = user?.role ?? UserRole.eleve;
    final cycle = user?.categorie ?? '';
    final niveau = user?.niveau ?? '';
    final matiere = user?.matiere ?? '';
    final xp = stats['xp'] as int? ?? 0;
    final level = stats['level'] as int? ?? 1;
    final badges = List<String>.from(stats['badges'] as List? ?? []);
    final streak = stats['streak'] as int? ?? 0;
    final weeklyXp = stats['weeklyXp'] as int? ?? 0;
    final xpProgress = (xp % 100) / 100.0;

    return Scaffold(
      backgroundColor: _spBg,
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(displayName, role, cycle, niveau, matiere),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // XP Level Bar
                  _buildXpBar(xp, level, xpProgress),
                  const SizedBox(height: 20),

                  // Stats grid
                  _buildStatsGrid(xp, level, streak, weeklyXp),
                  const SizedBox(height: 20),

                  // Bio section
                  _buildBioSection(bio, widget.isOwn, context),
                  const SizedBox(height: 20),

                  // Disponibilité (only own)
                  if (widget.isOwn) ...[
                    _buildDisponibilite(),
                    const SizedBox(height: 20),
                  ],

                  // Badges
                  _buildBadgesSection(badges),
                  const SizedBox(height: 24),

                  // Action button
                  if (!widget.isOwn)
                    _buildMessageButton(context, displayName),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar(
    String displayName,
    UserRole role,
    String cycle,
    String niveau,
    String matiere,
  ) {
    return SliverAppBar(
      expandedHeight: 220,
      pinned: true,
      backgroundColor: _spCard,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1A1040), Color(0xFF0F1B3D)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 40),
              Stack(
                children: [
                  UserAvatar(
                    username: widget.email,
                    radius: 50,
                    showStatus: true,
                  ),
                  if (widget.isOwn)
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                              colors: [_spPurple, _spBlue]),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.camera_alt,
                            color: Colors.white, size: 14),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                displayName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                alignment: WrapAlignment.center,
                children: [
                  _RoleBadge(role: role),
                  if (cycle.isNotEmpty)
                    _TagChip(text: cycle, color: _spPurple),
                  if (niveau.isNotEmpty)
                    _TagChip(text: niveau, color: _spBlue),
                  if (matiere.isNotEmpty)
                    _TagChip(
                        text: matiere, color: const Color(0xFF0D9488)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildXpBar(int xp, int level, double progress) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _spCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _spBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [_spPurple, _spBlue]),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Niv. $level',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '$xp XP total',
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
              Text(
                '${(xp % 100)}/100 XP',
                style: const TextStyle(color: Colors.white38, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: _spCard2,
              valueColor: const AlwaysStoppedAnimation<Color>(_spPurple),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid(int xp, int level, int streak, int weeklyXp) {
    final items = [
      (Icons.bolt_outlined, '$xp', 'XP Total', _spPurple),
      (Icons.military_tech_outlined, 'Niv. $level', 'Niveau', _spBlue),
      (Icons.local_fire_department_outlined, '$streak j', 'Streak',
          const Color(0xFFD97706)),
      (Icons.trending_up, '$weeklyXp', 'XP semaine', const Color(0xFF0D9488)),
    ];
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 2.4,
      children: items.map((item) {
        final (icon, value, label, color) = item;
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _spCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _spBorder),
          ),
          child: Row(
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
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(value,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold)),
                    Text(label,
                        style: const TextStyle(
                            color: Colors.white38, fontSize: 10)),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildBioSection(String bio, bool isOwn, BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _spCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _spBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Bio',
                  style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8)),
              const Spacer(),
              if (isOwn)
                GestureDetector(
                  onTap: () => _editBio(context, bio),
                  child: const Icon(Icons.edit_outlined,
                      color: _spPurple, size: 16),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            bio.isNotEmpty ? bio : 'Aucune bio pour le moment.',
            style: TextStyle(
                color: bio.isNotEmpty ? Colors.white70 : Colors.white24,
                fontSize: 13,
                height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildDisponibilite() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _spCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _spBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Disponibilité',
              style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: _availabilityOptions.map((opt) {
              final selected = _availability == opt;
              Color optColor;
              switch (opt) {
                case 'En ligne':
                  optColor = Colors.greenAccent;
                case 'Occupé':
                  optColor = const Color(0xFFD97706);
                default:
                  optColor = Colors.white38;
              }
              return GestureDetector(
                onTap: () => setState(() => _availability = opt),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: selected
                        ? optColor.withValues(alpha: 0.15)
                        : _spCard2,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: selected
                            ? optColor.withValues(alpha: 0.5)
                            : _spBorder),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color:
                              selected ? optColor : Colors.white24,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(opt,
                          style: TextStyle(
                              color: selected ? optColor : Colors.white38,
                              fontSize: 12,
                              fontWeight: selected
                                  ? FontWeight.w700
                                  : FontWeight.normal)),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildBadgesSection(List<String> earnedBadges) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Badges',
            style: TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: ScolarGamificationService.allBadges.map((badge) {
            final earned = earnedBadges.contains(badge);
            final color = Color(
                ScolarGamificationService.badgeColorValue(badge));
            final emoji = ScolarGamificationService.badgeEmoji(badge);
            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: earned
                    ? color.withValues(alpha: 0.15)
                    : _spCard2,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: earned
                      ? color.withValues(alpha: 0.5)
                      : _spBorder,
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
                    badge,
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
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildMessageButton(BuildContext context, String displayName) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () {
          final me = FirebaseAuth.instance.currentUser?.email ?? '';
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SCOLARChatRoomPage(
                name: widget.email,
                user: me,
                displayName: displayName,
              ),
            ),
          );
        },
        icon: const Icon(Icons.chat_bubble_outline, size: 18),
        label: const Text('Envoyer un message'),
        style: ElevatedButton.styleFrom(
          backgroundColor: _spPurple,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }
}

// ─── Widgets helpers ──────────────────────────────────────────────────────────

class _RoleBadge extends StatelessWidget {
  final UserRole role;
  const _RoleBadge({required this.role});

  Color get _color {
    switch (role) {
      case UserRole.professeur:
        return _spBlue;
      case UserRole.admin:
      case UserRole.direction:
        return const Color(0xFFD97706);
      case UserRole.parent:
        return const Color(0xFF0D9488);
      default:
        return _spPurple;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _color.withValues(alpha: 0.4)),
      ),
      child: Text(role.label,
          style: TextStyle(
              color: _color,
              fontSize: 11,
              fontWeight: FontWeight.w700)),
    );
  }
}

class _TagChip extends StatelessWidget {
  final String text;
  final Color color;
  const _TagChip({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text,
          style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600)),
    );
  }
}
