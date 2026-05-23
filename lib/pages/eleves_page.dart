import 'package:flutter/material.dart';

class ElevesPage extends StatelessWidget {
  const ElevesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Espace Élèves"),
        backgroundColor: Colors.deepPurple,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 🔝 LOGO + TITRE
          Column(
            children: [
              Image.asset(
                'assets/logo.png',
                width: 80,
              ),
              const SizedBox(height: 10),
              const Text(
                "ILYAS31AI",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),

          // 🔔 Notifications
          buildCard(context, Icons.notifications, "Notifications"),

          // 🪑 Plan de classe
          buildCard(context, Icons.grid_view, "Plan de classe"),

          const SizedBox(height: 20),

          // 📚 Révision
          const Text(
            "Révision",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          buildCard(context, Icons.quiz, "Quiz interactifs"),
          buildCard(context, Icons.menu_book, "Fiches de cours"),
          buildCard(context, Icons.style, "Flashcards"),

          const SizedBox(height: 20),

          // 💬 Communication
          const Text(
            "Communication",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          buildCard(context, Icons.chat, "Discussion"),
          buildCard(context, Icons.people, "Amis"),

          const SizedBox(height: 20),

          // 📊 Suivi scolaire
          const Text(
            "Suivi scolaire",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          buildCard(context, Icons.assignment, "Devoirs"),
          buildCard(context, Icons.bar_chart, "Notes & statistiques"),
          buildCard(context, Icons.schedule, "Emploi du temps"),
        ],
      ),
    );
  }

  // 🔥 CARD DESIGN + NAVIGATION
  Widget buildCard(BuildContext context, IconData icon, String title) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Colors.blue, Colors.purple],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Icon(icon, color: Colors.white),
        title: Text(
          title,
          style: const TextStyle(color: Colors.white),
        ),
        trailing: const Icon(Icons.arrow_forward, color: Colors.white),

        // 🚀 NAVIGATION CORRIGÉE
        onTap: () {
          if (title == "Notifications") {
            Navigator.pushNamed(context, '/notifications');
          } else if (title == "Plan de classe") {
            Navigator.pushNamed(context, '/plan');
          } else if (title == "Quiz interactifs") {
            Navigator.pushNamed(context, '/quiz');
          } else if (title == "Fiches de cours") {
            Navigator.pushNamed(context, '/fiches');
          } else if (title == "Flashcards") {
            Navigator.pushNamed(context, '/flashcards');
          } else if (title == "Discussion") {
            Navigator.pushNamed(
              context,
              '/discussion',
              arguments: {'name': 'Classe'},
            );
          } else if (title == "Amis") {
            Navigator.pushNamed(context, '/amis');
          } else if (title == "Devoirs") {
            Navigator.pushNamed(context, '/devoirs');
          } else if (title == "Notes & statistiques") {
            Navigator.pushNamed(context, '/notes'); // ✅ FIX
          } else if (title == "Emploi du temps") {
            Navigator.pushNamed(context, '/emploi');
          }
        },
      ),
    );
  }
}