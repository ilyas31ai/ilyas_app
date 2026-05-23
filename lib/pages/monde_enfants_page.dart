import 'package:flutter/material.dart';

class MondeEnfantsPage extends StatelessWidget {
  const MondeEnfantsPage({super.key});

  // 🔥 BOUTON DESIGN
  Widget buildButton(
    String title,
    IconData icon,
    Color color,
  ) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withOpacity(0.9),
            color.withOpacity(0.5),
          ],
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.4),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
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
    );
  }

  // 🔥 BOUTON NAVIGATION (IMPORTANT)
  Widget navButton(
    BuildContext context,
    String title,
    IconData icon,
    String route,
    Color color,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(30),
        onTap: () {
          Navigator.pushNamed(context, route);
        },
        child: buildButton(title, icon, color),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Monde Enfants 🎮"),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),

      body: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFFFF7E5F),
              Color(0xFFFFB88C),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),

        child: ListView(
          children: [
            // 🔷 LOGO
            Image.asset('assets/logo.png', height: 80),

            const SizedBox(height: 10),

            const Text(
              "ILYAS31AI",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 30),

            // 👶 MATERNELLE
            const Text(
              "👶 Maternelle",
              style: TextStyle(color: Colors.white, fontSize: 20),
            ),

            const SizedBox(height: 10),

            navButton(context, "Alphabet 🔤", Icons.text_fields, '/alphabet', Colors.blue),
            navButton(context, "Chiffres 🔢", Icons.numbers, '/chiffres', Colors.green),
            navButton(context, "Couleurs 🎨", Icons.palette, '/couleurs', Colors.purple),
            navButton(context, "Animaux 🐶", Icons.pets, '/animaux', Colors.teal),

            const SizedBox(height: 30),

            // 🧒 CP
            const Text(
              "🧒 Niveau CP",
              style: TextStyle(color: Colors.white, fontSize: 20),
            ),

            const SizedBox(height: 10),

            navButton(context, "Lecture 📖", Icons.menu_book, '/lecture', Colors.orange),
            navButton(context, "Additions ➕", Icons.add, '/addition', Colors.red),
            navButton(context, "Soustractions ➖", Icons.remove, '/soustraction', Colors.deepOrange),
            navButton(context, "Compter 🔢", Icons.format_list_numbered, '/compter', Colors.green),
            navButton(context, "Comparer 📊", Icons.bar_chart, '/comparer', Colors.blue),

            const SizedBox(height: 20),

            navButton(context, "Mathématiques 🧮", Icons.calculate, '/math', Colors.indigo),
          ],
        ),
      ),
    );
  }
}