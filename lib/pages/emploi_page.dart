import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class EmploiPage extends StatefulWidget {
  const EmploiPage({super.key});

  @override
  State<EmploiPage> createState() => _EmploiPageState();
}

class _EmploiPageState extends State<EmploiPage> {
  List<String> heures = [
    "08h","09h","10h","11h","12h",
    "13h","14h","15h","16h","17h"
  ];

  List<String> jours = [
    "Lundi","Mardi","Mercredi","Jeudi","Vendredi"
  ];

  Map<String, String> emploi = {};

  final TextEditingController controller = TextEditingController();

  // 🔥 LOAD DATA
  Future<void> loadData() async {
    final prefs = await SharedPreferences.getInstance();
    String? data = prefs.getString("emploi");

    if (data != null) {
      setState(() {
        emploi = Map<String, String>.from(json.decode(data));
      });
    }
  }

  // 🔥 SAVE DATA
  Future<void> saveData() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setString("emploi", json.encode(emploi));
  }

  void ajouterCours(String jour, String heure) {
    String key = "$jour-$heure";
    controller.text = emploi[key] ?? "";

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF161B22),
        title: Text("$jour • $heure"),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: "Entrer matière",
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Annuler"),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                emploi[key] = controller.text;
              });
              saveData(); // 🔥 sauvegarde
              Navigator.pop(context);
            },
            child: const Text("Valider"),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    loadData(); // 🔥 chargement auto
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Emploi du temps"),
      ),

      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(10),
          child: Column(
            children: [

              Image.asset('assets/logo.png', height: 60),
              const SizedBox(height: 10),

              const Text(
                "Organisation hebdomadaire",
                style: TextStyle(color: Colors.grey),
              ),

              const SizedBox(height: 20),

              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // HEURES
                  Column(
                    children: heures.map((h) {
                      return Container(
                        height: 70,
                        width: 60,
                        alignment: Alignment.center,
                        child: Text(h),
                      );
                    }).toList(),
                  ),

                  // JOURS
                  Expanded(
                    child: Row(
                      children: jours.map((jour) {
                        return Expanded(
                          child: Column(
                            children: [

                              // TITRE
                              Container(
                                height: 40,
                                margin: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Colors.blue, Colors.cyan],
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                alignment: Alignment.center,
                                child: Text(jour),
                              ),

                              // CASES
                              ...heures.map((heure) {
                                String key = "$jour-$heure";

                                return GestureDetector(
                                  onTap: () {
                                    ajouterCours(jour, heure);
                                  },

                                  onLongPress: () {
                                    setState(() {
                                      emploi.remove(key);
                                    });
                                    saveData(); // 🔥 suppression sauvegardée
                                  },

                                  child: Container(
                                    height: 60,
                                    margin: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF161B22),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      emploi[key] ?? "+",
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                );
                              }),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}