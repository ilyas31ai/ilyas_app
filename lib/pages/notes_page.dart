import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class NotesPage extends StatefulWidget {
  const NotesPage({super.key});

  @override
 State<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends State<NotesPage> {
  final TextEditingController noteController = TextEditingController();
  final TextEditingController matiereController = TextEditingController();

  List<Map<String, dynamic>> notes = [];

  double get moyenne {
    if (notes.isEmpty) return 0;
    double total = 0;
    for (var n in notes) {
      total += n["note"];
    }
    return total / notes.length;
  }

  // 🔥 AJOUT NOTE CORRIGÉ
  void ajouterNote() {
    final matiere = matiereController.text.trim();
    final noteText = noteController.text.trim();

    if (matiere.isEmpty || noteText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Remplis tous les champs")),
      );
      return;
    }

    final note = double.tryParse(noteText);

    if (note == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Entre un nombre valide")),
      );
      return;
    }

    setState(() {
      notes.add({
        "matiere": matiere,
        "note": note,
      });
    });

    matiereController.clear();
    noteController.clear();
  }

  List<FlSpot> getSpots() {
    return List.generate(notes.length, (index) {
      return FlSpot(index.toDouble(), notes[index]["note"]);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F2027),
      appBar: AppBar(
        title: const Text("Notes & Statistiques"),
        backgroundColor: Colors.green,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // 🔥 LOGO
            Image.asset('assets/logo.png', height: 70),
            const SizedBox(height: 20),

            // 📊 MOYENNE
            Text(
              "Moyenne : ${moyenne.toStringAsFixed(2)} / 20",
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 20),

            // 📈 GRAPHIQUE
            SizedBox(
              height: 200,
              child: notes.isEmpty
                  ? const Center(
                      child: Text(
                        "Ajoute des notes pour voir le graphique",
                        style: TextStyle(color: Colors.white54),
                      ),
                    )
                  : LineChart(
                      LineChartData(
                        borderData: FlBorderData(show: false),
                        titlesData: FlTitlesData(show: false),
                        lineBarsData: [
                          LineChartBarData(
                            spots: getSpots(),
                            isCurved: true,
                            color: Colors.green,
                            barWidth: 3,
                          ),
                        ],
                      ),
                    ),
            ),

            const SizedBox(height: 20),

            // ✏️ INPUT MATIÈRE
            TextField(
              controller: matiereController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: "Matière",
                hintStyle: TextStyle(color: Colors.white54),
              ),
            ),

            // ✏️ INPUT NOTE
            TextField(
              controller: noteController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: "Note /20",
                hintStyle: TextStyle(color: Colors.white54),
              ),
            ),

            const SizedBox(height: 10),

            // 🔥 BOUTON
            ElevatedButton(
              onPressed: ajouterNote, // ✅ IMPORTANT
              child: const Text("Ajouter"),
            ),

            const SizedBox(height: 20),

            // 📋 LISTE
            Expanded(
              child: ListView.builder(
                itemCount: notes.length,
                itemBuilder: (context, index) {
                  final n = notes[index];

                  return Container(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Colors.green, Colors.teal],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Text(
                          n["matiere"],
                          style: const TextStyle(color: Colors.white),
                        ),
                        const Spacer(),
                        Text(
                          "${n["note"]}/20",
                          style: const TextStyle(color: Colors.white),
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
    );
  }
}