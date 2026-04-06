import 'package:flutter/material.dart';

class AmisPage extends StatefulWidget {
  const AmisPage({super.key});

  @override
  State<AmisPage> createState() => _AmisPageState();
}

class _AmisPageState extends State<AmisPage> {
  List<Map<String, dynamic>> amis = [
    {"name": "Ali", "phone": "0612345678", "online": true},
    {"name": "Sara", "phone": "0623456789", "online": false},
    {"name": "Yassine", "phone": "0634567890", "online": true},
    {"name": "Fatima", "phone": "0645678901", "online": false},
  ];

  String search = "";

  // ➕ Ajouter ami
  void ajouterAmi() {
    TextEditingController nameController = TextEditingController();
    TextEditingController phoneController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.black87,
          title: const Text("Ajouter un ami",
              style: TextStyle(color: Colors.white)),

          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: "Nom",
                  hintStyle: TextStyle(color: Colors.white54),
                ),
              ),
              TextField(
                controller: phoneController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: "Téléphone",
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
                if (nameController.text.isNotEmpty &&
                    phoneController.text.isNotEmpty) {
                  setState(() {
                    amis.add({
                      "name": nameController.text,
                      "phone": phoneController.text,
                      "online": false,
                    });
                  });
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
    final filtered = amis
        .where((a) =>
            a["name"].toLowerCase().contains(search.toLowerCase()) ||
            a["phone"].contains(search))
        .toList();

    return Scaffold(
      backgroundColor: const Color(0xFF0F2027),

      appBar: AppBar(
        title: const Text("Mes Amis"),
        backgroundColor: Colors.blueAccent,
      ),

      body: Column(
        children: [
          const SizedBox(height: 10),

          // 🔥 LOGO
          Image.asset(
            "assets/logo.png",
            height: 60,
          ),

          const SizedBox(height: 10),

          // 🔍 RECHERCHE
          Padding(
            padding: const EdgeInsets.all(10),
            child: TextField(
              onChanged: (value) {
                setState(() => search = value);
              },
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: "Rechercher un ami...",
                hintStyle: const TextStyle(color: Colors.white54),
                prefixIcon: const Icon(Icons.search, color: Colors.white),
                filled: true,
                fillColor: Colors.black45,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          // 👥 LISTE
          Expanded(
            child: ListView.builder(
              itemCount: filtered.length,
              itemBuilder: (context, index) {
                final ami = filtered[index];

                return InkWell(
                  onTap: () {
                    Navigator.pushNamed(
                      context,
                      '/discussion',
                      arguments: ami["name"],
                    );
                  },

                  child: Container(
                    margin: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    padding: const EdgeInsets.all(12),

                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1E3C72), Color(0xFF2A5298)],
                      ),
                      borderRadius: BorderRadius.circular(15),
                    ),

                    child: Row(
                      children: [
                        // 👤 AVATAR + ONLINE
                        Stack(
                          children: [
                            CircleAvatar(
                              radius: 25,
                              backgroundColor: Colors.white,
                              child: Text(
                                ami["name"][0],
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              ),
                            ),

                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: ami["online"]
                                      ? Colors.green
                                      : Colors.grey,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: Colors.white, width: 2),
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(width: 15),

                        // 📄 INFOS
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              ami["name"],
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              ami["phone"],
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),

                        const Spacer(),

                        const Icon(Icons.chat, color: Colors.white),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),

      // ➕ AJOUT AMI
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.blueAccent,
        onPressed: ajouterAmi,
        child: const Icon(Icons.person_add),
      ),
    );
  }
}