import 'package:flutter/material.dart';

class ElevesMenuPage extends StatelessWidget {
  const ElevesMenuPage({super.key});

  Widget buildItem(
      BuildContext context, String title, IconData icon, String route) {
    return InkWell(
      onTap: () {
        if (route == '/discussion') {
          Navigator.pushNamed(
            context,
            '/discussion',
            arguments: {
              'name': 'Élève',
              'type': 'eleve',
            },
          );
        } else {
          Navigator.pushNamed(context, route);
        }
      },
      borderRadius: BorderRadius.circular(15),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.blue.shade700.withOpacity(0.6),
              Colors.blue.shade400.withOpacity(0.3),
            ],
          ),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 12),
            Text(
              title,
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),

      appBar: AppBar(
        backgroundColor: Colors.blue,
        title: const Text("Espace Élèves"),
      ),

      body: Column(
        children: [
          const SizedBox(height: 20),

          // 🔥 LOGO + TEXTE
          Column(
            children: [
              Image.asset(
                'assets/logo.png',
                width: 100,
              ),
              const SizedBox(height: 10),
              const Text(
                "Bienvenue",
                style: TextStyle(color: Colors.white70),
              ),
            ],
          ),

          const SizedBox(height: 20),

          Expanded(
            child: ListView(
              children: [
                buildItem(context, "Notifications", Icons.notifications,
                    '/notifications'),
                buildItem(context, "Plan de classe", Icons.map,
                    '/plan_classe'),

                const Padding(
                  padding: EdgeInsets.all(10),
                  child: Text("Révision",
                      style: TextStyle(color: Colors.white54)),
                ),

                buildItem(context, "Quiz interactifs", Icons.quiz,
                    '/quiz'),
                buildItem(context, "Fiches de cours", Icons.book,
                    '/fiches'),
                buildItem(context, "Flashcards", Icons.style,
                    '/flashcards'),

                const Padding(
                  padding: EdgeInsets.all(10),
                  child: Text("Communication",
                      style: TextStyle(color: Colors.white54)),
                ),

                buildItem(context, "Discussion", Icons.chat,
                    '/discussion'),
                buildItem(context, "Amis", Icons.people, '/amis'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}