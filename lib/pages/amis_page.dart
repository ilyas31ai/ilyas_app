import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'discussion_page.dart';

class AmisPage extends StatefulWidget {
  const AmisPage({super.key});

  @override
  State<AmisPage> createState() => _AmisPageState();
}

class _AmisPageState extends State<AmisPage> {
  List<String> amis = [];
  TextEditingController controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    loadAmis();
  }

  // 💾 SAVE
  Future<void> saveAmis() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("amis", jsonEncode(amis));
  }

  // 📥 LOAD
  Future<void> loadAmis() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString("amis");

    if (data != null) {
      setState(() {
        amis = List<String>.from(jsonDecode(data));
      });
    }
  }

  // ➕ AJOUTER AMI
  void addAmi() {
    if (controller.text.isEmpty) return;

    setState(() {
      amis.add(controller.text);
    });

    controller.clear();
    saveAmis();
  }

  // ❌ SUPPRIMER AMI
  void deleteAmi(int index) {
    setState(() {
      amis.removeAt(index);
    });

    saveAmis();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),

      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text("Mes amis 👥"),
      ),

      body: Column(
        children: [
          // 🔍 INPUT AJOUT
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: "Ajouter un ami...",
                      hintStyle:
                          const TextStyle(color: Colors.white54),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.1),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: addAmi,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [Colors.pink, Colors.orange],
                      ),
                    ),
                    child:
                        const Icon(Icons.add, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),

          // 📜 LISTE AMIS
          Expanded(
            child: ListView.builder(
              itemCount: amis.length,
              itemBuilder: (context, index) {
                final nom = amis[index];

                return ListTile(
                  // 👤 AVATAR
                  leading: CircleAvatar(
                    radius: 25,
                    backgroundColor: Colors.pink,
                    child: Text(
                      nom[0].toUpperCase(),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),

                  title: Text(
                    nom,
                    style: const TextStyle(color: Colors.white),
                  ),

                  trailing: IconButton(
                    icon: const Icon(Icons.delete,
                        color: Colors.red),
                    onPressed: () => deleteAmi(index),
                  ),

                  // 💬 OUVRIR CHAT
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            DiscussionPage(nom: nom),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}