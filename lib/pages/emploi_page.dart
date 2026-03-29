import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class EmploiPage extends StatefulWidget {
  const EmploiPage({super.key});

  @override
  State<EmploiPage> createState() => _EmploiPageState();
}

class _EmploiPageState extends State<EmploiPage> {
  List<Map<String, String>> cours = [];
  String selectedJour = "Lundi";

  @override
  void initState() {
    super.initState();
    loadCours();
  }

  // 💾 Sauvegarde
  Future<void> saveCours() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setString("cours", jsonEncode(cours));
  }

  // 📥 Charger
  Future<void> loadCours() async {
    final prefs = await SharedPreferences.getInstance();
    String? data = prefs.getString("cours");

    if (data != null) {
      setState(() {
        cours = List<Map<String, String>>.from(jsonDecode(data));
      });
    }
  }

  // 🎨 Couleurs
  Color getColor(String matiere) {
    switch (matiere.toLowerCase()) {
      case "maths":
        return Colors.blue;
      case "français":
        return Colors.red;
      case "informatique":
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Emploi du temps")),

      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            "Mes cours",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),

          ...cours.map((c) => Dismissible(
                key: Key(c.toString()),
                onDismissed: (direction) {
                  setState(() {
                    cours.remove(c);
                  });
                  saveCours();
                },
                background: Container(color: Colors.red),

                child: Card(
                  color: getColor(c['matiere']!),
                  child: ListTile(
                    leading: const Icon(Icons.access_time, color: Colors.white),
                    title: Text(
                      "${c['jour']} - ${c['date']} - ${c['heure']}",
                      style: const TextStyle(color: Colors.white),
                    ),
                    subtitle: Text(
                      "${c['matiere']} | Salle ${c['salle']}",
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              )),
        ],
      ),

      floatingActionButton: FloatingActionButton(
        onPressed: () {
          TextEditingController dateController = TextEditingController();
          TextEditingController heureController = TextEditingController();
          TextEditingController matiereController = TextEditingController();
          TextEditingController salleController = TextEditingController();

          showDialog(
            context: context,
            builder: (context) {
              return AlertDialog(
                title: const Text("Ajouter un cours"),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Jour
                      DropdownButtonFormField<String>(
                        value: selectedJour,
                        items: [
                          "Lundi",
                          "Mardi",
                          "Mercredi",
                          "Jeudi",
                          "Vendredi",
                          "Samedi",
                          "Dimanche"
                        ].map((jour) {
                          return DropdownMenuItem(
                            value: jour,
                            child: Text(jour),
                          );
                        }).toList(),
                        onChanged: (value) {
                          selectedJour = value!;
                        },
                        decoration:
                            const InputDecoration(labelText: "Jour"),
                      ),

                      // Date
                      TextField(
                        controller: dateController,
                        readOnly: true,
                        decoration:
                            const InputDecoration(labelText: "Date"),
                        onTap: () async {
                          DateTime? pickedDate =
                              await showDatePicker(
                            context: context,
                            initialDate: DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2100),
                          );

                          if (pickedDate != null) {
                            dateController.text =
                                "${pickedDate.day}/${pickedDate.month}/${pickedDate.year}";
                          }
                        },
                      ),

                      // Heure
                      TextField(
                        controller: heureController,
                        readOnly: true,
                        decoration:
                            const InputDecoration(labelText: "Heure"),
                        onTap: () async {
                          TimeOfDay? pickedTime =
                              await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay.now(),
                          );

                          if (pickedTime != null) {
                            heureController.text =
                                "${pickedTime.hour}h${pickedTime.minute.toString().padLeft(2, '0')}";
                          }
                        },
                      ),

                      TextField(
                        controller: matiereController,
                        decoration: const InputDecoration(
                            labelText: "Matière"),
                      ),

                      TextField(
                        controller: salleController,
                        decoration:
                            const InputDecoration(labelText: "Salle"),
                      ),
                    ],
                  ),
                ),

                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: const Text("Annuler"),
                  ),

                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        cours.add({
                          "jour": selectedJour,
                          "date": dateController.text,
                          "heure": heureController.text,
                          "matiere": matiereController.text,
                          "salle": salleController.text,
                        });

                        // 📅 TRI
                        cours.sort((a, b) =>
                            a['date']!.compareTo(b['date']!));
                      });

                      saveCours();
                      Navigator.pop(context);
                    },
                    child: const Text("Ajouter"),
                  ),
                ],
              );
            },
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}