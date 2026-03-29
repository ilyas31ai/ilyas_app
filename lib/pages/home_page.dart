import 'package:flutter/material.dart';
import 'eleves_page.dart';
import 'professeurs_page.dart';
import 'discussion_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 25),
            child: Column(
              children: [
                // 🔥 LOGO
                Image.asset("assets/logo.png", height: 90),

                const SizedBox(height: 15),

                const Text(
                  "Ilyas31AI",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 30),

                // 🔘 BOUTONS
                buildButton(context, "Élèves", Icons.school,
                    const ElevesPage()),

                buildButton(context, "Professeurs", Icons.person,
                    const ProfesseursPage()),

                buildButton(
                  context,
                  "Discussion",
                  Icons.chat_bubble,
                  const DiscussionPage(nom: "ilyas31ai"),
                ),

                buildButton(
                  context,
                  "Chat IA",
                  Icons.smart_toy,
                  const Scaffold(
                    body: Center(child: Text("Chat IA bientôt 🤖")),
                  ),
                ),

                buildButton(
                  context,
                  "Paramètres",
                  Icons.settings,
                  const Scaffold(
                    body: Center(child: Text("Paramètres ⚙️")),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget buildButton(
      BuildContext context, String text, IconData icon, Widget page) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => page),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 15),
        padding: const EdgeInsets.symmetric(vertical: 18),
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Colors.pink, Colors.orange],
          ),
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 10),
            Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}