import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:image_picker/image_picker.dart';
import '../models/user_model.dart';
import '../services/social_service.dart';
import '../services/storage_service.dart';
import '../services/user_service.dart';
import '../widgets/shimmer_box.dart';
import '../widgets/user_avatar.dart';
import 'edit_profile_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  String get _email => FirebaseAuth.instance.currentUser?.email ?? '';

  final _db = FirebaseDatabase.instance.ref();

  late final Stream<UserModel?> _profileStream;

  int _friendsCount = 0;
  int _devoirsSubmis = 0;
  String _scoreIA = '—';
  bool _statsLoading = true;
  bool _uploadingPhoto = false;

  @override
  void initState() {
    super.initState();
    _profileStream = UserService.currentUserStream();
    _loadStats();
  }

  Future<void> _pickAndUploadPhoto() async {
    final picker = ImagePicker();
    final picked =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 75);
    if (picked == null) return;

    setState(() => _uploadingPhoto = true);
    try {
      final url =
          await StorageService.uploadProfilePhoto(File(picked.path));
      if (url != null) {
        await UserService.updateProfile({'photoUrl': url});
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Échec de l\'envoi de la photo. Réessayez.'),
          backgroundColor: Color(0xFFDC2626),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erreur lors de l\'envoi de la photo : $e'),
          backgroundColor: const Color(0xFFDC2626),
        ));
      }
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  Future<void> _loadStats() async {
    final email = _email;
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (email.isEmpty) {
      if (mounted) setState(() => _statsLoading = false);
      return;
    }

    int friendsCount = 0;
    int devoirsCount = 0;
    String scoreIA = '—';

    try {
      final k = SocialService.encodeKey(email);
      final friendsSnap = await _db.child('friends/$k').get();
      if (friendsSnap.exists && friendsSnap.value is Map) {
        friendsCount =
            Map<dynamic, dynamic>.from(friendsSnap.value as Map).length;
      }
    } catch (_) {}

    if (uid.isNotEmpty) {
      final fs = FirebaseFirestore.instance;
      try {
        final subSnap = await fs
            .collection('submissions')
            .where('studentId', isEqualTo: uid)
            .get();
        devoirsCount = subSnap.docs.length;
      } catch (_) {}
      try {
        final userDoc = await fs.collection('users').doc(uid).get();
        if (userDoc.exists) {
          final d = userDoc.data() ?? {};
          final summary = d['maitrise_summary'] as Map<String, dynamic>? ?? {};
          final totaux = summary['totaux'] as Map<String, dynamic>? ?? {};
          final total = (totaux['total'] as num?)?.toInt() ?? 0;
          final maitrise = (totaux['maitrise'] as num?)?.toInt() ?? 0;
          if (total > 0) scoreIA = '${(maitrise * 100 ~/ total)}%';
        }
      } catch (_) {}
    }

    if (!mounted) return;
    setState(() {
      _friendsCount = friendsCount;
      _devoirsSubmis = devoirsCount;
      _scoreIA = scoreIA;
      _statsLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<UserModel?>(
      stream: _profileStream,
      builder: (context, snap) {
        if (snap.hasError) {
          return Scaffold(
            backgroundColor: const Color(0xFF0D1117),
            body: Center(
              child: Text(
                'Erreur de chargement du profil.',
                style: const TextStyle(color: Colors.white54, fontSize: 14),
              ),
            ),
          );
        }
        final loading = snap.connectionState == ConnectionState.waiting;
        final profile = snap.data;
        return Scaffold(
          backgroundColor: const Color(0xFF0D1117),
          body: SafeArea(
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                    child: _buildHeader(context, profile, loading)),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      _buildStatsRow(),
                      const SizedBox(height: 20),
                      loading
                          ? _buildInfoShimmer()
                          : _buildInfoCard(profile),
                      const SizedBox(height: 20),
                      _buildBadgesSection(),
                      const SizedBox(height: 20),
                      _buildActionsSection(context, profile),
                    ]),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ─── Header ───────────────────────────────────────────────────────────────

  Widget _buildHeader(
      BuildContext context, UserModel? profile, bool loading) {
    final displayName = profile?.displayName ??
        (_email.contains('@') ? _email.split('@').first : _email);
    final roleLabel = profile?.role.label ?? '…';
    final roleColor = _roleColor(profile?.role);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Mon Profil',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold),
              ),
              Row(
                children: [
                  if (profile != null)
                    IconButton(
                      icon: const Icon(Icons.edit_outlined,
                          color: Colors.white54, size: 20),
                      tooltip: 'Modifier le profil',
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              EditProfilePage(profile: profile),
                        ),
                      ),
                    ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB)
                          .withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: const Color(0xFF2563EB)
                              .withValues(alpha: 0.3)),
                    ),
                    child: const Text(
                      'ILYAS31AI',
                      style: TextStyle(
                          color: Color(0xFF2563EB),
                          fontSize: 11,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Tappable avatar with upload overlay
          GestureDetector(
            onTap: _pickAndUploadPhoto,
            child: Stack(
              alignment: Alignment.center,
              children: [
                UserAvatar(
                  username: _email,
                  radius: 42,
                  showStatus: true,
                  photoUrl: profile?.photoUrl,
                ),
                if (_uploadingPhoto)
                  Container(
                    width: 84,
                    height: 84,
                    decoration: BoxDecoration(
                      color: Colors.black45,
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    ),
                  )
                else
                  Positioned(
                    bottom: 2,
                    right: 2,
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: const Color(0xFF2563EB),
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: const Color(0xFF0D1117), width: 2),
                      ),
                      child: const Icon(Icons.camera_alt,
                          color: Colors.white, size: 12),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          loading
              ? ShimmerBox(
                  width: 120,
                  height: 22,
                  radius: 6,
                )
              : Text(
                  displayName,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold),
                ),
          const SizedBox(height: 4),
          Text(
            _email,
            style: const TextStyle(color: Colors.white38, fontSize: 12),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _BadgePill(Icons.shield_outlined, roleLabel, roleColor),
              const SizedBox(width: 8),
              const _BadgePill(Icons.star, 'Actif', Color(0xFFD97706)),
            ],
          ),
        ],
      ),
    );
  }

  Color _roleColor(UserRole? role) {
    switch (role) {
      case UserRole.professeur:
        return const Color(0xFF6C47FF);
      case UserRole.admin:
        return const Color(0xFFD97706);
      default:
        return const Color(0xFF16A34A);
    }
  }

  // ─── Stats ────────────────────────────────────────────────────────────────

  Widget _buildStatsRow() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _StatCell(
            icon: Icons.people_outline,
            label: 'Amis',
            value: _statsLoading ? '…' : '$_friendsCount',
          ),
          _VertDivider(),
          _StatCell(
            icon: Icons.assignment_turned_in_outlined,
            label: 'Devoirs remis',
            value: _statsLoading ? '…' : '$_devoirsSubmis',
          ),
          _VertDivider(),
          _StatCell(
            icon: Icons.psychology_outlined,
            label: 'Score IA',
            value: _statsLoading ? '…' : _scoreIA,
          ),
        ],
      ),
    );
  }

  // ─── Info Card ────────────────────────────────────────────────────────────

  Widget _buildInfoCard(UserModel? profile) {
    final memberSince = profile?.createdAt != null
        ? _formatDate(profile!.createdAt!.toDate())
        : '—';
    final niveau = profile?.niveau;
    final classeNom = profile?.classeNom;
    final matiere = profile?.matiere;
    final bio = profile?.bio;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Informations',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 15)),
          const SizedBox(height: 14),
          _InfoRow(Icons.email_outlined, 'Email', _email),
          if (classeNom != null && classeNom.isNotEmpty) ...[
            const Divider(color: Color(0xFF21262D), height: 22),
            _InfoRow(Icons.class_outlined, 'Classe', classeNom),
          ],
          if (niveau != null && niveau.isNotEmpty) ...[
            const Divider(color: Color(0xFF21262D), height: 22),
            _InfoRow(Icons.school_outlined, 'Niveau', niveau),
          ],
          if (matiere != null && matiere.isNotEmpty) ...[
            const Divider(color: Color(0xFF21262D), height: 22),
            _InfoRow(Icons.book_outlined, 'Matière', matiere),
          ],
          if (bio != null && bio.isNotEmpty) ...[
            const Divider(color: Color(0xFF21262D), height: 22),
            _InfoRow(Icons.info_outline, 'Bio', bio),
          ],
          const Divider(color: Color(0xFF21262D), height: 22),
          _InfoRow(
              Icons.calendar_today_outlined, 'Membre depuis', memberSince),
        ],
      ),
    );
  }

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  // ─── Badges ───────────────────────────────────────────────────────────────

  Widget _buildBadgesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('BADGES',
            style: TextStyle(
                color: Colors.white38,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2)),
        const SizedBox(height: 12),
        Row(
          children: [
            _BadgeCard(Icons.star, 'Actif', 'Connecté régulièrement',
                const Color(0xFFD97706)),
            const SizedBox(width: 10),
            _BadgeCard(Icons.chat_bubble, 'Bavard', 'Messages envoyés',
                const Color(0xFF2563EB)),
            const SizedBox(width: 10),
            _BadgeCard(Icons.school, 'Studieux', 'Révisions complètes',
                const Color(0xFF16A34A)),
          ],
        ),
      ],
    );
  }

  // ─── Info Shimmer ─────────────────────────────────────────────────────────

  Widget _buildInfoShimmer() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ShimmerBox(width: 100, height: 14),
          const SizedBox(height: 18),
          const ShimmerBox(width: double.infinity, height: 12),
          const SizedBox(height: 10),
          const ShimmerBox(width: double.infinity, height: 12),
          const SizedBox(height: 10),
          const ShimmerBox(width: 160, height: 12),
        ],
      ),
    );
  }

  // ─── Actions ──────────────────────────────────────────────────────────────

  Widget _buildActionsSection(BuildContext context, UserModel? profile) {
    final isEleve = profile?.role == UserRole.eleve;
    return Column(
      children: [
        if (profile != null)
          _ActionTile(
            icon: Icons.edit_outlined,
            label: 'Modifier le profil',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => EditProfilePage(profile: profile)),
            ),
          ),
        if (profile != null) const SizedBox(height: 8),
        _ActionTile(
          icon: Icons.notifications_outlined,
          label: 'Notifications',
          onTap: () => Navigator.pushNamed(context, '/notifications'),
        ),
        if (isEleve) ...[
          const SizedBox(height: 8),
          _ActionTile(
            icon: Icons.forum_outlined,
            label: 'Contacter mes professeurs',
            onTap: () => Navigator.pushNamed(context, '/eleve_discussion'),
          ),
        ],
        const SizedBox(height: 8),
        _ActionTile(
          icon: Icons.chat_bubble_outline,
          label: 'Messages',
          onTap: () => Navigator.pushNamed(context, '/users'),
        ),
        const SizedBox(height: 8),
        _ActionTile(
          icon: Icons.logout,
          label: 'Se déconnecter',
          onTap: () => FirebaseAuth.instance.signOut(),
          color: Colors.redAccent,
        ),
      ],
    );
  }
}

// ─── Reusable sub-widgets ──────────────────────────────────────────────────────

class _BadgePill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _BadgePill(this.icon, this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 13),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatCell({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: const Color(0xFF2563EB), size: 22),
        const SizedBox(height: 6),
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold)),
        Text(label,
            style: const TextStyle(color: Colors.white38, fontSize: 12)),
      ],
    );
  }
}

class _VertDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
        width: 1, height: 50, color: Colors.white.withValues(alpha: 0.08));
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow(this.icon, this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Colors.white38, size: 17),
        const SizedBox(width: 10),
        Text('$label : ',
            style: const TextStyle(color: Colors.white38, fontSize: 13)),
        Expanded(
          child: Text(value,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
              overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }
}

class _BadgeCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;

  const _BadgeCard(this.icon, this.title, this.subtitle, this.color);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 6),
            Text(title,
                style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w700),
                textAlign: TextAlign.center),
            const SizedBox(height: 2),
            Text(subtitle,
                style: const TextStyle(color: Colors.white38, fontSize: 10),
                textAlign: TextAlign.center,
                maxLines: 2),
          ],
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? Colors.white;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF161B22),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Row(
          children: [
            Icon(icon, color: c.withValues(alpha: 0.8), size: 20),
            const SizedBox(width: 14),
            Expanded(
              child: Text(label,
                  style: TextStyle(
                      color: c,
                      fontSize: 14,
                      fontWeight: FontWeight.w500)),
            ),
            Icon(Icons.chevron_right,
                color: c.withValues(alpha: 0.3), size: 20),
          ],
        ),
      ),
    );
  }
}
