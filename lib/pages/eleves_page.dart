import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ElevesPage extends StatelessWidget {
  const ElevesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final email = FirebaseAuth.instance.currentUser?.email ?? '';
    final name = email.contains('@') ? email.split('@').first : email;

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
          'Espace Élèves',
          style: TextStyle(
              color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _buildHeader(name)),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _buildSection('Révision & Outils', [
                  _Item(Icons.auto_awesome, 'Chat IA',
                      'Assistant scolaire intelligent', '/chat',
                      [const Color(0xFF6C47FF), const Color(0xFF2563EB)]),
                  _Item(Icons.quiz, 'Quiz interactifs',
                      'Teste tes connaissances', '/quiz',
                      [const Color(0xFF2563EB), const Color(0xFF0891B2)]),
                  _Item(Icons.menu_book, 'Fiches de cours',
                      'Résumés et notions clés', '/fiches',
                      [const Color(0xFF16A34A), const Color(0xFF0F766E)]),
                  _Item(Icons.style, 'Flashcards',
                      'Mémorise efficacement', '/flashcards',
                      [const Color(0xFFD97706), const Color(0xFFDC2626)]),
                ]),
                _buildSection('Communication', [
                  _Item(Icons.chat_bubble_rounded, 'Discussion classe',
                      'Chat avec ta classe', '/discussion',
                      [const Color(0xFF7C3AED), const Color(0xFF6C47FF)],
                      args: {'name': 'Classe'}),
                  _Item(Icons.people, 'Amis',
                      'Gère tes amis et contacts', '/amis',
                      [const Color(0xFF0891B2), const Color(0xFF2563EB)]),
                  _Item(Icons.message, 'Messages',
                      'Tes conversations privées', '/users',
                      [const Color(0xFF15803D), const Color(0xFF16A34A)]),
                ]),
                _buildSection('Suivi scolaire', [
                  _Item(Icons.assignment, 'Devoirs',
                      'Suis tes devoirs', '/devoirs',
                      [const Color(0xFFBE185D), const Color(0xFF7C3AED)]),
                  _Item(Icons.bar_chart, 'Notes & Stats',
                      'Analyse tes résultats', '/notes',
                      [const Color(0xFF0891B2), const Color(0xFF6D28D9)]),
                  _Item(Icons.schedule, 'Emploi du temps',
                      'Ton planning de cours', '/emploi',
                      [const Color(0xFFD97706), const Color(0xFFDC2626)]),
                  _Item(Icons.grid_view, 'Plan de classe',
                      'Organisation de la salle', '/plan',
                      [const Color(0xFF0F766E), const Color(0xFF0891B2)]),
                ]),
                _buildSection('Autres', [
                  _Item(Icons.notifications, 'Notifications',
                      'Tes alertes', '/notifications',
                      [const Color(0xFF374151), const Color(0xFF1F2937)]),
                ]),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(String name) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6C47FF), Color(0xFF2563EB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bonjour, $name 👋',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold),
                ),
                const Text(
                  'Espace Élèves · ILYAS31AI',
                  style: TextStyle(
                      color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          const Icon(Icons.school, color: Colors.white70, size: 28),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<_Item> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 20, bottom: 8, left: 2),
          child: Text(
            title.toUpperCase(),
            style: const TextStyle(
              color: Colors.white38,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
        ),
        ...items.map((item) => _ItemCard(item: item)),
      ],
    );
  }
}

class _Item {
  final IconData icon;
  final String title;
  final String subtitle;
  final String route;
  final List<Color> colors;
  final Map<String, dynamic>? args;

  const _Item(this.icon, this.title, this.subtitle, this.route, this.colors,
      {this.args});
}

class _ItemCard extends StatelessWidget {
  final _Item item;
  const _ItemCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        if (item.route == '/discussion') {
          final email =
              FirebaseAuth.instance.currentUser?.email ?? '';
          Navigator.pushNamed(context, '/discussion', arguments: {
            'name': item.args?['name'] ?? 'Classe',
            'user': email,
          });
        } else {
          Navigator.pushNamed(context, item.route);
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: const Color(0xFF161B22),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: item.colors),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(item.icon, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    item.subtitle,
                    style: const TextStyle(
                        color: Colors.white38, fontSize: 12),
                  ),
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
