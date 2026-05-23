import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../widgets/user_avatar.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  String get _user => FirebaseAuth.instance.currentUser?.email ?? '';
  String get _name =>
      _user.contains('@') ? _user.split('@').first : _user;

  final _db = FirebaseDatabase.instance.ref();

  int _friendsCount = 0;
  int _contactsCount = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    if (_user.isEmpty) return;
    final results = await Future.wait([
      _db.child('friends/$_user').get(),
      _db.child('users/$_user/contacts').get(),
    ]);

    final friendsSnap = results[0];
    final contactsSnap = results[1];

    if (!mounted) return;
    setState(() {
      _friendsCount = friendsSnap.exists
          ? (Map<dynamic, dynamic>.from(friendsSnap.value as Map)).length
          : 0;
      _contactsCount = contactsSnap.exists
          ? (Map<dynamic, dynamic>.from(contactsSnap.value as Map)).length
          : 0;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildHeader()),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _buildStatsRow(),
                  const SizedBox(height: 20),
                  _buildInfoCard(),
                  const SizedBox(height: 20),
                  _buildBadgesSection(),
                  const SizedBox(height: 20),
                  _buildActionsSection(context),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Header ───────────────────────────────────────────────────────────────

  Widget _buildHeader() {
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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.3)),
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
          const SizedBox(height: 24),
          UserAvatar(username: _user, radius: 42, showStatus: true),
          const SizedBox(height: 14),
          Text(
            _name,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            _user,
            style: const TextStyle(color: Colors.white38, fontSize: 12),
          ),
          const SizedBox(height: 10),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _BadgePill(Icons.star, 'Actif', Color(0xFFD97706)),
              SizedBox(width: 8),
              _BadgePill(Icons.school, 'Studieux', Color(0xFF16A34A)),
            ],
          ),
        ],
      ),
    );
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
            value: _loading ? '…' : '$_friendsCount',
          ),
          _VertDivider(),
          _StatCell(
            icon: Icons.contacts_outlined,
            label: 'Contacts',
            value: _loading ? '…' : '$_contactsCount',
          ),
          _VertDivider(),
          const _StatCell(
            icon: Icons.military_tech_outlined,
            label: 'Badges',
            value: '3',
          ),
        ],
      ),
    );
  }

  // ─── Info Card ────────────────────────────────────────────────────────────

  Widget _buildInfoCard() {
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
          _InfoRow(Icons.email_outlined, 'Email', _user),
          const Divider(color: Color(0xFF21262D), height: 22),
          const _InfoRow(Icons.school_outlined, 'Niveau', 'ILYAS31AI'),
          const Divider(color: Color(0xFF21262D), height: 22),
          const _InfoRow(
              Icons.calendar_today_outlined, 'Membre depuis', 'Mai 2025'),
        ],
      ),
    );
  }

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

  // ─── Actions ──────────────────────────────────────────────────────────────

  Widget _buildActionsSection(BuildContext context) {
    return Column(
      children: [
        _ActionTile(
          icon: Icons.notifications_outlined,
          label: 'Notifications',
          onTap: () => Navigator.pushNamed(context, '/notifications'),
        ),
        const SizedBox(height: 8),
        _ActionTile(
          icon: Icons.people_outline,
          label: 'Mes amis',
          onTap: () => Navigator.pushNamed(context, '/amis'),
        ),
        const SizedBox(height: 8),
        _ActionTile(
          icon: Icons.chat_bubble_outline,
          label: 'Messages privés',
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
