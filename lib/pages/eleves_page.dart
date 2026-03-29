import 'package:flutter/material.dart';
import 'emploi_page.dart';
import 'plan_classe_page.dart';

class ElevesPage extends StatelessWidget {
  const ElevesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Élèves"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Text(
              "Espace élèves",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 30),

            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const EmploiPage(),
                  ),
                );
              },
              child: const Text("📅 Emploi du temps"),
            ),

            const SizedBox(height: 15),

            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const PlanClassePage(),
                  ),
                );
              },
              child: const Text("🏫 Plan de classe"),
            ),
          ],
        ),
      ),
    );
  }
}