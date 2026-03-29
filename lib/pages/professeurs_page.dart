import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class ProfesseursPage extends StatefulWidget {
  const ProfesseursPage({super.key});

  @override
  State<ProfesseursPage> createState() => _ProfesseursPageState();
}

class _ProfesseursPageState extends State<ProfesseursPage> {
  final TextEditingController controller = TextEditingController();

  List<Map<String, dynamic>> profs = [];

  @override
  void initState() {
    super.initState();
    chargerProfs();
  }

  // 🔄 Charger
  Future<void> chargerProfs() async {
    final prefs = await SharedPreferences.getInstance();
    String? data = prefs.getString('profs');

    if (data != null) {
      List decoded = jsonDecode(data);
      profs = decoded.map((e) => Map<String, dynamic>.from(e)).toList();
    }

    setState(() {});
  }

  // 💾 Sauvegarder
  Future<void> sauvegarderProfs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('profs', jsonEncode(profs));
  }

  // ➕ Ajouter prof
  void ajouterProf() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Ajouter professeur"),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: "Nom du prof"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Annuler"),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                setState(() {
                  profs.add({
                    "nom": controller.text,
                    "devoirs": [],
                  });
                });
                sauvegarderProfs();
                controller.clear();
                Navigator.pop(context);
              }
            },
            child: const Text("Ajouter"),
          ),
        ],
      ),
    );
  }

  // ➕ Ajouter devoir
  void ajouterDevoir(int index) {
    TextEditingController devoirController = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Ajouter devoir"),
        content: TextField(
          controller: devoirController,
          decoration: const InputDecoration(hintText: "Nom du devoir"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Annuler"),
          ),
          ElevatedButton(
            onPressed: () {
              if (devoirController.text.isNotEmpty) {
                setState(() {
                  profs[index]["devoirs"].add(devoirController.text);
                });
                sauvegarderProfs();
                Navigator.pop(context);
              }
            },
            child: const Text("Ajouter"),
          ),
        ],
      ),
    );
  }

  // 👁 Voir devoirs
  void voirDevoirs(int index) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text("Devoirs de ${profs[index]["nom"]}"),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: List.generate(
              profs[index]["devoirs"].length,
              (i) => ListTile(
                title: Text(profs[index]["devoirs"][i]),
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Fermer"),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text("Professeurs"),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),

      body: ListView.builder(
        itemCount: profs.length,
        itemBuilder: (context, index) {
          final prof = profs[index];

          return Dismissible(
            key: Key(prof["nom"] + index.toString()),
            direction: DismissDirection.endToStart,

            // 🔴 fond rouge
            background: Container(
              margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
              padding: const EdgeInsets.only(right: 20),
              alignment: Alignment.centerRight,
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.delete, color: Colors.white, size: 30),
            ),

            // ❌ suppression + undo
            onDismissed: (direction) {
              final removed = prof;

              setState(() {
                profs.removeAt(index);
              });

              sauvegarderProfs();

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text("${removed["nom"]} supprimé"),
                  action: SnackBarAction(
                    label: "Annuler",
                    onPressed: () {
                      setState(() {
                        profs.insert(index, removed);
                      });
                      sauvegarderProfs();
                    },
                  ),
                ),
              );
            },

            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        prof["nom"],
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        "Devoirs: ${prof["devoirs"].length}",
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.add, color: Colors.white),
                        onPressed: () => ajouterDevoir(index),
                      ),
                      IconButton(
                        icon: const Icon(Icons.visibility, color: Colors.white),
                        onPressed: () => voirDevoirs(index),
                      ),
                    ],
                  )
                ],
              ),
            ),
          );
        },
      ),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: ajouterProf,
        icon: const Icon(Icons.add),
        label: const Text("Ajouter"),
      ),
    );
  }
}