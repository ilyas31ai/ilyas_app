import 'package:flutter/material.dart';
import '../models/xp_model.dart';
import '../services/xp_service.dart';
import 'jeux_scolaires_page.dart';
import 'leaderboard_page.dart';

class MondeEnfantsPage extends StatefulWidget {
  const MondeEnfantsPage({super.key});

  @override
  State<MondeEnfantsPage> createState() => _MondeEnfantsPageState();
}

class _MondeEnfantsPageState extends State<MondeEnfantsPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Stream<XpModel?> _xpStream;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _xpStream = XpService.currentXpStream();
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
      body: FadeTransition(
        opacity: _fade,
        child: CustomScrollView(
          slivers: [
            _buildHeader(),
            SliverToBoxAdapter(child: _buildContent()),
          ],
        ),
      ),
    );
  }

  // ─── Header ──────────────────────────────────────────────────────────────

  SliverAppBar _buildHeader() {
    return SliverAppBar(
      expandedHeight: 210,
      pinned: true,
      backgroundColor: const Color(0xFF1A0533),
      title: const Text('Monde Enfant',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      flexibleSpace: FlexibleSpaceBar(
        background: _XpHeader(stream: _xpStream),
      ),
    );
  }

  // ─── Content ─────────────────────────────────────────────────────────────

  Widget _buildContent() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel('👶 Maternelle', Colors.pinkAccent),
          const SizedBox(height: 12),
          _gameGrid(_maternelleGames),
          const SizedBox(height: 28),
          _sectionLabel('🧒 Niveau CP', Colors.lightBlueAccent),
          const SizedBox(height: 12),
          _gameGrid(_cpGames),
          const SizedBox(height: 28),
          _sectionLabel('🎯 Jeux Premium', Colors.purpleAccent),
          const SizedBox(height: 12),
          _bigCard(
            title: 'Jeux Scolaires',
            subtitle: '8 mini-jeux · Gagne des XP',
            emoji: '🎮',
            colors: [const Color(0xFF6C47FF), const Color(0xFF2563EB)],
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const JeuxScolairesPage()),
            ),
          ),
          const SizedBox(height: 12),
          _bigCard(
            title: 'Classement',
            subtitle: 'Top joueurs · Podium animé',
            emoji: '🏆',
            colors: [const Color(0xFFF59E0B), const Color(0xFFEF4444)],
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const LeaderboardPage()),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _sectionLabel(String title, Color color) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
              color: color, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 10),
        Text(title,
            style: TextStyle(
                color: color, fontSize: 17, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _gameGrid(List<_GameItem> games) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.2,
      ),
      itemCount: games.length,
      itemBuilder: (_, i) => _GameTileSmall(game: games[i]),
    );
  }

  Widget _bigCard({
    required String title,
    required String subtitle,
    required String emoji,
    required List<Color> colors,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          height: 90,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
                colors: colors,
                begin: Alignment.centerLeft,
                end: Alignment.centerRight),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                  color: colors[0].withValues(alpha: 0.35),
                  blurRadius: 12,
                  offset: const Offset(0, 5))
            ],
          ),
          child: Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 38)),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold)),
                    Text(subtitle,
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12)),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios,
                  color: Colors.white54, size: 16),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Game data ────────────────────────────────────────────────────────────

  static final _maternelleGames = [
    _GameItem('Alphabet', '🔤', '/alphabet',
        [const Color(0xFF2563EB), const Color(0xFF1D4ED8)], 5),
    _GameItem('Chiffres', '🔢', '/chiffres',
        [const Color(0xFF16A34A), const Color(0xFF15803D)], 5),
    _GameItem('Couleurs', '🎨', '/couleurs',
        [const Color(0xFF7C3AED), const Color(0xFF6D28D9)], 5),
    _GameItem('Animaux', '🐶', '/animaux',
        [const Color(0xFF0891B2), const Color(0xFF0E7490)], 5),
  ];

  static final _cpGames = [
    _GameItem('Lecture', '📖', '/lecture',
        [const Color(0xFFD97706), const Color(0xFFB45309)], 10),
    _GameItem('Additions', '➕', '/addition',
        [const Color(0xFFDC2626), const Color(0xFFB91C1C)], 10),
    _GameItem('Soustractions', '➖', '/soustraction',
        [const Color(0xFFDB2777), const Color(0xFFBE185D)], 10),
    _GameItem('Compter', '🔢', '/compter',
        [const Color(0xFF059669), const Color(0xFF047857)], 10),
    _GameItem('Comparer', '📊', '/comparer',
        [const Color(0xFF2563EB), const Color(0xFF1D4ED8)], 10),
    _GameItem('Maths', '🧮', '/math',
        [const Color(0xFF7C3AED), const Color(0xFF6D28D9)], 15),
  ];
}

// ─── Data class ───────────────────────────────────────────────────────────────

class _GameItem {
  final String title, emoji, route;
  final List<Color> colors;
  final int xp;
  const _GameItem(this.title, this.emoji, this.route, this.colors, this.xp);
}

// ─── Small game tile ──────────────────────────────────────────────────────────

class _GameTileSmall extends StatelessWidget {
  final _GameItem game;
  const _GameTileSmall({required this.game});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => Navigator.pushNamed(context, game.route),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
                colors: game.colors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                  color: game.colors[0].withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4))
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(game.emoji, style: const TextStyle(fontSize: 34)),
              const SizedBox(height: 6),
              Text(game.title,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13),
                  textAlign: TextAlign.center),
              const SizedBox(height: 4),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(10)),
                child: Text('+${game.xp} XP',
                    style: const TextStyle(color: Colors.white, fontSize: 11)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── XP Header ────────────────────────────────────────────────────────────────

class _XpHeader extends StatelessWidget {
  final Stream<XpModel?> stream;
  const _XpHeader({required this.stream});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<XpModel?>(
      stream: stream,
      builder: (context, snap) {
        final xp = snap.data;
        return Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1A0533), Color(0xFF2D1B69), Color(0xFF1E3A8A)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 56, 20, 20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text('🎮', style: TextStyle(fontSize: 30)),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Niveau ${xp?.level ?? 1}',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold)),
                          Text(xp?.levelTitle ?? 'Débutant',
                              style: const TextStyle(
                                  color: Colors.white60, fontSize: 12)),
                        ],
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: Colors.amber.withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          children: [
                            const Text('⭐', style: TextStyle(fontSize: 14)),
                            const SizedBox(width: 4),
                            Text('${xp?.xp ?? 0} XP',
                                style: const TextStyle(
                                    color: Colors.amber,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: xp?.levelProgress ?? 0,
                      backgroundColor: Colors.white.withValues(alpha: 0.12),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                          Color(0xFF8B5CF6)),
                      minHeight: 8,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${xp?.xpInCurrentLevel ?? 0} / 200 XP · prochain niveau',
                    style:
                        const TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
