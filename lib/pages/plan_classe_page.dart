import 'package:flutter/material.dart';

class PlanClassePage extends StatefulWidget {
  const PlanClassePage({super.key});

  @override
  State<PlanClassePage> createState() => _PlanClassePageState();
}

class _PlanClassePageState extends State<PlanClassePage> {
  List<String> eleves = [];

  void ajouterEleve() {
    TextEditingController controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Ajouter un élève"),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              hintText: "Nom de l'élève",
            ),
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
                    eleves.add(controller.text);
                  });
                }
                Navigator.pop(context);
              },
              child: const Text("Ajouter"),
            ),
          ],
        );
      },
    );
  }

  void supprimerEleve(int index) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Supprimer cet élève ?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Non"),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                eleves.removeAt(index);
              });
              Navigator.pop(context);
            },
            child: const Text("Oui"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Plan de classe"),
      ),

      floatingActionButton: FloatingActionButton(
        onPressed: ajouterEleve,
        child: const Icon(Icons.add),
      ),

      body: eleves.isEmpty
          ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Center(
                  child: Image.asset(
                    'assets/logo.png',
                    width: 90,
                  ),
                ),
                const SizedBox(height: 15),
                const Text(
                  "Aucun élève",
                  style: TextStyle(fontSize: 18),
                ),
                const SizedBox(height: 10),
                const Text(
                  "Ajoute des élèves avec le bouton +",
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            )

          : GridView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: eleves.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemBuilder: (context, index) {
                return Container(
                  decoration: BoxDecoration(
                    color: Colors.blueGrey[800],
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black54,
                        blurRadius: 4,
                      )
                    ],
                  ),
                  child: Stack(
                    children: [

                      /// CONTENU
                      Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Image.asset(
                              'assets/logo.png',
                              width: 30,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              eleves[index],
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),

                      /// BOUTON SUPPRIMER
                      Positioned(
                        top: 5,
                        right: 5,
                        child: GestureDetector(
                          onTap: () => supprimerEleve(index),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            padding: const EdgeInsets.all(5),
                            child: const Icon(
                              Icons.close,
                              size: 16,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}