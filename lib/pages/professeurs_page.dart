import 'package:flutter/material.dart';
import 'discussion_page.dart';

class ProfesseursPage extends StatelessWidget {
  const ProfesseursPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Liste des profs
    final List<Map<String, String>> profs = [
      {"name": "Mr Dupont"},
      {"name": "Mme Fatima"},
      {"name": "Mme Sarah"},
      {"name": "Mr Yassine"},
    ];

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),

      appBar: AppBar(
        backgroundColor: Colors.red,
        title: const Text("Professeurs"),
      ),

      body: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          children: [
            // 🔍 Barre de recherche
            TextField(
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: "Rechercher prof ou matière...",
                hintStyle: const TextStyle(color: Colors.white54),
                filled: true,
                fillColor: Colors.white10,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
              ),
            ),

            const SizedBox(height: 10),

            // 📋 Liste des profs
            Expanded(
              child: ListView.builder(
                itemCount: profs.length,
                itemBuilder: (context, index) {
                  final prof = profs[index];
                  final name = prof["name"]!;

                  return Container(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Colors.blue, Colors.cyan],
                      ),
                      borderRadius: BorderRadius.circular(15),
                    ),

                    child: Row(
                      children: [
                        // 👤 Avatar
                        const CircleAvatar(
                          backgroundColor: Colors.white,
                          child: Icon(Icons.person),
                        ),

                        const SizedBox(width: 10),

                        // 📛 Nom
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold),
                              ),
                              const Text(
                                "En ligne",
                                style: TextStyle(
                                    color: Colors.white70, fontSize: 12),
                              ),
                            ],
                          ),
                        ),

                        // 💬 Bouton chat
                        IconButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    DiscussionPage(name: name),
                              ),
                            );
                          },
                          icon: const Icon(Icons.chat, color: Colors.white),
                        ),

                        // 🗑 Supprimer (optionnel)
                        IconButton(
                          onPressed: () {},
                          icon: const Icon(Icons.delete, color: Colors.red),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),

      // ➕ bouton ajouter
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.orange,
        onPressed: () {},
        child: const Icon(Icons.add),
      ),
    );
  }
}