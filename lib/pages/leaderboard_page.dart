import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/xp_model.dart';
import '../services/xp_service.dart';
import '../widgets/user_avatar.dart';

class LeaderboardPage extends StatefulWidget {
  const LeaderboardPage({super.key});

  @override
  State<LeaderboardPage> createState() => _LeaderboardPageState();
}

class _LeaderboardPageState extends State<LeaderboardPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _podiumAnim;
  late final Stream<List<XpModel>> _stream;
  final _uid = FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));
    _podiumAnim = CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut);
    _stream = XpService.leaderboardStream();
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        title: const Text('🏆 Classement'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: StreamBuilder<List<XpModel>>(
        stream: _stream,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(
                    color: Color(0xFF6C47FF)));
          }
          if (!snap.hasData || snap.data!.isEmpty) {
            return const Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text('🏆', style: TextStyle(fontSize: 48)),
                SizedBox(height: 12),
                Text('Aucun joueur encore',
                    style: TextStyle(color: Colors.white54, fontSize: 16)),
                SizedBox(height: 8),
                Text('Joue pour gagner des XP !',
                    style: TextStyle(color: Colors.white38, fontSize: 13)),
              ]),
            );
          }

          final list = snap.data!;
          return ListView(
            children: [
              if (list.length >= 3)
                ScaleTransition(
                  scale: _podiumAnim,
                  child: _buildPodium(list),
                ),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text('Classement général',
                    style: TextStyle(
                        color: Colors.white54,
                        fontSize: 13,
                        fontWeight: FontWeight.bold)),
              ),
              ...list.asMap().entries.map((e) => _buildRow(e.key, e.value)),
              const SizedBox(height: 30),
            ],
          );
        },
      ),
    );
  }

  // ─── Podium ────────────────────────────────────────────────────────────────

  Widget _buildPodium(List<XpModel> list) {
    return Container(
      height: 210,
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF1C2128),
            const Color(0xFF0D1117),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(child: _podiumSlot(list[1], 2, 130, const Color(0xFF9CA3AF))),
          Expanded(child: _podiumSlot(list[0], 1, 165, const Color(0xFFFBBF24))),
          Expanded(child: _podiumSlot(list[2], 3, 105, const Color(0xFFF97316))),
        ],
      ),
    );
  }

  Widget _podiumSlot(XpModel xp, int rank, double height, Color color) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(rank == 1 ? '👑' : rank == 2 ? '🥈' : '🥉',
            style: const TextStyle(fontSize: 22)),
        const SizedBox(height: 4),
        UserAvatar(
          username: xp.displayName,
          radius: 20,
          photoUrl: xp.photoUrl.isNotEmpty ? xp.photoUrl : null,
        ),
        const SizedBox(height: 4),
        SizedBox(
          width: 70,
          child: Text(
            xp.displayName.contains('@')
                ? xp.displayName.split('@').first
                : xp.displayName,
            style: const TextStyle(color: Colors.white, fontSize: 11),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
            textAlign: TextAlign.center,
          ),
        ),
        Text('${xp.xp} XP',
            style: TextStyle(
                color: color, fontSize: 10, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Container(
          height: height,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            border: Border.all(color: color.withValues(alpha: 0.35)),
          ),
          child: Center(
              child: Text('#$rank',
                  style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 18))),
        ),
      ],
    );
  }

  // ─── List row ─────────────────────────────────────────────────────────────

  Widget _buildRow(int index, XpModel xp) {
    final isMe = xp.uid == _uid;
    final rank = index + 1;

    return AnimatedContainer(
      duration: Duration(milliseconds: 200 + index * 30),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isMe
            ? const Color(0xFF6C47FF).withValues(alpha: 0.12)
            : const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(14),
        border: isMe
            ? Border.all(
                color: const Color(0xFF6C47FF).withValues(alpha: 0.4))
            : null,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 38,
            child: rank <= 3
                ? Text(rank == 1 ? '🥇' : rank == 2 ? '🥈' : '🥉',
                    style: const TextStyle(fontSize: 20),
                    textAlign: TextAlign.center)
                : Text('#$rank',
                    style: const TextStyle(
                        color: Colors.white54,
                        fontWeight: FontWeight.bold,
                        fontSize: 14),
                    textAlign: TextAlign.center),
          ),
          const SizedBox(width: 10),
          UserAvatar(
            username: xp.displayName,
            radius: 18,
            photoUrl: xp.photoUrl.isNotEmpty ? xp.photoUrl : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Flexible(
                    child: Text(
                      xp.displayName.contains('@')
                          ? xp.displayName.split('@').first
                          : xp.displayName,
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isMe) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                          color: const Color(0xFF6C47FF),
                          borderRadius: BorderRadius.circular(6)),
                      child: const Text('Toi',
                          style:
                              TextStyle(color: Colors.white, fontSize: 10)),
                    ),
                  ],
                ]),
                Text('Niv. ${xp.level} · ${xp.levelTitle}',
                    style: const TextStyle(
                        color: Colors.white54, fontSize: 11)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${xp.xp} XP',
                  style: const TextStyle(
                      color: Colors.amber, fontWeight: FontWeight.bold)),
              if (xp.badges.isNotEmpty)
                Row(
                  children: xp.badges
                      .take(3)
                      .map((b) => Text(_badgeEmoji(b),
                          style: const TextStyle(fontSize: 14)))
                      .toList(),
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _badgeEmoji(String badge) {
    switch (badge) {
      case 'first_xp':
        return '⭐';
      case 'level_5':
        return '🌟';
      case 'level_10':
        return '💫';
      default:
        return '🏅';
    }
  }
}
