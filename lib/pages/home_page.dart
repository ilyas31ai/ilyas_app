import 'package:flutter/material.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  Widget buildButton(BuildContext context, String title, IconData icon,
      String route, Color color) {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, route),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color.withOpacity(0.8), color.withOpacity(0.4)],
          ),
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 10),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 🔷 LOGO
            Image.asset(
              'assets/logo.png',
              height: 90,
            ),

            const SizedBox(height: 10),

            const Text(
              "ILYAS31AI",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),

            const Text(
              "Bienvenue 👋",
              style: TextStyle(color: Colors.white70),
            ),

            const SizedBox(height: 30),

            // 🔘 BOUTONS
            buildButton(context, "Espace Élèves", Icons.school, '/eleves',
                Colors.blue),
            buildButton(context, "Professeurs", Icons.person, '/professeurs',
                Colors.orange),
            buildButton(context, "Discussion", Icons.chat, '/discussion',
                Colors.purple),
            buildButton(context, "Chat IA", Icons.smart_toy, '/chat',
                Colors.deepPurple),
            buildButton(context, "Scan devoirs", Icons.camera_alt, '/scan',
                Colors.teal),
            buildButton(context, "Paramètres", Icons.settings, '/settings',
                Colors.grey),
          ],
        ),
      ),
    );
  }
}