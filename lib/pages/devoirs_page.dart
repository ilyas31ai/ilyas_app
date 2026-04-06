import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DevoirsPage extends StatefulWidget {
  const DevoirsPage({super.key});

  @override
  State<DevoirsPage> createState() => _DevoirsPageState();
}

class _DevoirsPageState extends State<DevoirsPage> {
  List<Map<String, String>> devoirs = [];

  final TextEditingController titreController = TextEditingController();
  DateTime? selectedDate;

  @override
  void initState() {
    super.initState();
    loadDevoirs();
  }

  // 🔥 Charger
  Future<void> loadDevoirs() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('devoirs');

    if (data != null) {
      List decoded = jsonDecode(data);
      setState(() {
        devoirs = decoded.map((e) => Map<String, String>.from(e)).toList();
      });
    }
  }

  // 💾 Sauvegarder
  Future<void> saveDevoirs() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('devoirs', jsonEncode(devoirs));
  }

  // ➕ Ajouter
  void addDevoir() {
    if (titreController.text.isEmpty || selectedDate == null) return;

    setState(() {
      devoirs.add({
        "titre": titreController.text,
        "date": selectedDate.toString().split(' ')[0],
      });
    });

    saveDevoirs();

    titreController.clear();
    selectedDate = null;

    Navigator.pop(context);
  }

  // 🗑️ Supprimer
  void deleteDevoir(int index) {
    setState(() {
      devoirs.removeAt(index);
    });

    saveDevoirs();
  }

  // 📅 Date
  Future<void> pickDate() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
    );

    if (picked != null) {
      setState(() {
        selectedDate = picked;
      });
    }
  }

  // 🪟 Popup
  void showAddDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1A1A2E),
          title: const Text("Ajouter un devoir"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titreController,
                decoration: const InputDecoration(
                  hintText: "Nom du devoir",
                ),
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: pickDate,
                child: const Text("Choisir une date"),
              ),
              if (selectedDate != null)
                Text("Date: ${selectedDate.toString().split(' ')[0]}"),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Annuler"),
            ),
            ElevatedButton(
              onPressed: addDevoir,
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
      backgroundColor: const Color(0xFF0D1117),

      appBar: AppBar(
        title: const Text("📚 Devoirs"),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),

      floatingActionButton: FloatingActionButton(
        onPressed: showAddDialog,
        backgroundColor: Colors.blueAccent,
        child: const Icon(Icons.add),
      ),

      body: Column(
        children: [
          const SizedBox(height: 10),

          // 🔥 LOGO + TITRE
          Column(
            children: [
              Image.asset(
                'assets/logo.png',
                height: 80,
              ),
              const SizedBox(height: 10),
              const Text(
                "Liste des devoirs",
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.white70,
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // 🔥 LISTE
          Expanded(
            child: devoirs.isEmpty
                ? const Center(
                    child: Text(
                      "Aucun devoir",
                      style: TextStyle(color: Colors.white70),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: devoirs.length,
                    itemBuilder: (context, index) {
                      final devoir = devoirs[index];

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFF1F4068),
                              Color(0xFF16213E)
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  devoir["titre"]!,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  devoir["date"]!,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                  ),
                                ),
                              ],
                            ),
                            IconButton(
                              onPressed: () => deleteDevoir(index),
                              icon: const Icon(Icons.delete,
                                  color: Colors.red),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}