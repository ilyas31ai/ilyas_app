import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class PlanClassePage extends StatefulWidget {
  const PlanClassePage({super.key});

  @override
  State<PlanClassePage> createState() => _PlanClassePageState();
}

class _PlanClassePageState extends State<PlanClassePage> {
  List<Map<String, String>> eleves = [];

  @override
  void initState() {
    super.initState();
    loadEleves();
  }

  // 🎨 Couleur aléatoire
  Color getColor(String name) {
    return Colors.primaries[name.hashCode % Colors.primaries.length];
  }

  // 💾 SAVE
  Future<void> saveEleves() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setString("eleves", jsonEncode(eleves));
  }

  // 📂 LOAD
  Future<void> loadEleves() async {
    final prefs = await SharedPreferences.getInstance();
    String? data = prefs.getString("eleves");

    if (data != null) {
      setState(() {
        eleves = List<Map<String, String>>.from(
          jsonDecode(data),
        );
      });
    } else {
      eleves = [
        {"nom": "Ali"},
        {"nom": "Sara"},
        {"nom": "Jean"},
        {"nom": "Fatou"},
      ];
    }
  }

  // ➕ AJOUTER
  void ajouterEleve() {
    TextEditingController ctrl = TextEditingController();

    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text("Ajouter élève"),
          content: TextField(controller: ctrl),
          actions: [
            TextButton(
              onPressed: () {
                setState(() {
                  eleves.add({"nom": ctrl.text});
                });
                saveEleves();
                Navigator.pop(context);
              },
              child: const Text("Ajouter"),
            )
          ],
        );
      },
    );
  }

  // ✏️ MODIFIER
  void modifierEleve(int index) {
    TextEditingController ctrl =
        TextEditingController(text: eleves[index]["nom"]);

    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text("Modifier"),
          content: TextField(controller: ctrl),
          actions: [
            TextButton(
              onPressed: () {
                setState(() {
                  eleves[index]["nom"] = ctrl.text;
                });
                saveEleves();
                Navigator.pop(context);
              },
              child: const Text("OK"),
            )
          ],
        );
      },
    );
  }

  // ❌ DELETE
  void supprimerEleve(int index) {
    setState(() {
      eleves.removeAt(index);
    });
    saveEleves();
  }

  // 🔁 DRAG
  void reorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex--;
      final item = eleves.removeAt(oldIndex);
      eleves.insert(newIndex, item);
    });
    saveEleves();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Plan de classe"),
        backgroundColor: Colors.black,
      ),

      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
          ),
        ),

        child: ReorderableListView(
          onReorder: reorder,

          children: List.generate(eleves.length, (index) {
            final nom = eleves[index]["nom"] ?? "";

            return Container(
              key: ValueKey(nom),
              margin: const EdgeInsets.all(10),

              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(20),
              ),

              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: getColor(nom),
                  child: Text(
                    nom.isNotEmpty ? nom[0] : "?",
                    style: const TextStyle(color: Colors.white),
                  ),
                ),

                title: Text(
                  nom,
                  style: const TextStyle(color: Colors.white),
                ),

                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.white),
                      onPressed: () => modifierEleve(index),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => supprimerEleve(index),
                    ),
                    const Icon(Icons.drag_handle, color: Colors.white),
                  ],
                ),
              ),
            );
          }),
        ),
      ),

      floatingActionButton: FloatingActionButton(
        onPressed: ajouterEleve,
        child: const Icon(Icons.add),
      ),
    );
  }
}