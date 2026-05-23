import 'package:flutter/material.dart';

class FichesPage extends StatefulWidget {
  const FichesPage({super.key});

  @override
  State<FichesPage> createState() => _FichesPageState();
}

class _FichesPageState extends State<FichesPage> {
  final List<Map<String, String>> fiches = [
    {"title": "Maths - Chapitre 1", "content": "Les équations"},
    {"title": "Histoire", "content": "Révolution française"},
  ];

  void ajouterFiche(String title, String content) {
    setState(() {
      fiches.add({"title": title, "content": content});
    });
  }

  void supprimerFiche(int index) {
    setState(() {
      fiches.removeAt(index);
    });
  }

  void showAddDialog() {
    final titleController = TextEditingController();
    final contentController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          backgroundColor: Colors.black.withOpacity(0.8),
          title: const Text("Ajouter une fiche",
              style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: "Titre",
                  hintStyle: TextStyle(color: Colors.white54),
                ),
              ),
              TextField(
                controller: contentController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: "Contenu",
                  hintStyle: TextStyle(color: Colors.white54),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Annuler"),
            ),
            ElevatedButton(
              onPressed: () {
                if (titleController.text.isNotEmpty &&
                    contentController.text.isNotEmpty) {
                  ajouterFiche(
                    titleController.text,
                    contentController.text,
                  );
                  Navigator.pop(context);
                }
              },
              child: const Text("Ajouter"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Fiches de cours"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),

      // 🔥 BACKGROUND PRO
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),

        child: Column(
          children: [
            const SizedBox(height: 20),

            // 🔥 LOGO + TITLE
            Column(
              children: [
                Image.asset(
                  'assets/logo.png',
                  height: 70,
                ),
                const SizedBox(height: 10),
                const Text(
                  "Fiches de cours",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // 🔥 LISTE
            Expanded(
              child: ListView.builder(
                itemCount: fiches.length,
                itemBuilder: (context, index) {
                  final fiche = fiches[index];

                  return Container(
                    margin:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.blue.withOpacity(0.6),
                          Colors.blueAccent.withOpacity(0.3)
                        ],
                      ),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: ListTile(
                      title: Text(
                        fiche["title"]!,
                        style: const TextStyle(color: Colors.white),
                      ),
                      subtitle: Text(
                        fiche["content"]!,
                        style: const TextStyle(color: Colors.white70),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => supprimerFiche(index),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),

      // 🔥 FLOAT BUTTON PRO
      floatingActionButton: FloatingActionButton(
        heroTag: 'fiches_fab',
        onPressed: showAddDialog,
        backgroundColor: Colors.blueAccent,
        child: const Icon(Icons.add),
      ),
    );
  }
}