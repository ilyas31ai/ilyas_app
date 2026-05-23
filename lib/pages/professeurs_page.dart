import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class ProfesseursPage extends StatefulWidget {
  final String currentUser;

  const ProfesseursPage({super.key, required this.currentUser});

  @override
  State<ProfesseursPage> createState() => _ProfesseursPageState();
}

class _ProfesseursPageState extends State<ProfesseursPage> {
  final db = FirebaseDatabase.instance.ref();

  // ➕ AJOUT PROF
  void ajouterProf() {
    TextEditingController controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Ajouter professeur"),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              hintText: "Nom du professeur",
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Annuler"),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = controller.text.trim();
                if (name.isEmpty) return;

                // 🔥 sauvegarde Firebase
                await db.child("professeurs/$name").set({
                  "name": name,
                });

                // 🔥 ajouter en contact (optionnel)
                await db
                    .child("users/${widget.currentUser}/contacts/$name")
                    .set(true);

                Navigator.pop(context);
              },
              child: const Text("Ajouter"),
            ),
          ],
        );
      },
    );
  }

  // ❌ supprimer prof
  void supprimerProf(String name) async {
    await db.child("professeurs/$name").remove();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),

      appBar: AppBar(
        backgroundColor: Colors.red,
        title: const Text("Professeurs"),
      ),

      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            // 🔷 LOGO
            Image.asset("assets/logo.png", height: 70),
            const SizedBox(height: 10),
            const Text(
              "ILYAS31AI",
              style: TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 15),

            // 📋 LISTE FIREBASE
            Expanded(
              child: StreamBuilder(
                stream: db.child("professeurs").onValue,
                builder: (context, snapshot) {
                  if (!snapshot.hasData ||
                      snapshot.data!.snapshot.value == null) {
                    return const Center(
                      child: Text("Aucun professeur",
                          style: TextStyle(color: Colors.white)),
                    );
                  }

                  final data = Map<dynamic, dynamic>.from(
                      snapshot.data!.snapshot.value as Map);

                  final profs = data.keys.toList();

                  return ListView.builder(
                    itemCount: profs.length,
                    itemBuilder: (context, index) {
                      final name = profs[index];

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
                            const CircleAvatar(
                              backgroundColor: Colors.white,
                              child: Icon(Icons.person),
                            ),

                            const SizedBox(width: 10),

                            Expanded(
                              child: Text(
                                name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),

                            // 💬 CHAT
                            IconButton(
                              onPressed: () {
                                Navigator.pushNamed(
                                  context,
                                  '/discussion',
                                  arguments: {
                                    "name": name,
                                    "user": widget.currentUser,
                                  },
                                );
                              },
                              icon: const Icon(Icons.chat,
                                  color: Colors.white),
                            ),

                            // ❌ SUPPRIMER
                            IconButton(
                              onPressed: () {
                                supprimerProf(name);
                              },
                              icon: const Icon(Icons.delete,
                                  color: Colors.red),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),

      // ➕ AJOUT
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.orange,
        onPressed: ajouterProf,
        child: const Icon(Icons.add),
      ),
    );
  }
}