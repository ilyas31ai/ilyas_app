import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FlashcardsPage extends StatefulWidget {
  const FlashcardsPage({super.key});

  @override
  State<FlashcardsPage> createState() => _FlashcardsPageState();
}

class CardModel {
  String q;
  String a;

  CardModel({required this.q, required this.a});
}

class _FlashcardsPageState extends State<FlashcardsPage> {
  List<CardModel> cards = [];
  int index = 0;
  int score = 0;
  int niveau = 1;

  @override
  void initState() {
    super.initState();
    loadCards();
  }

  // 🔹 Sauvegarde
  Future<void> saveCards() async {
    final prefs = await SharedPreferences.getInstance();
    final data = cards.map((c) => {'q': c.q, 'a': c.a}).toList();
    prefs.setString('flashcards', jsonEncode(data));
  }

  // 🔹 Chargement
  Future<void> loadCards() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('flashcards');

    if (data != null) {
      final decoded = jsonDecode(data);
      if (decoded.isNotEmpty) {
        setState(() {
          cards = decoded
              .map<CardModel>((c) => CardModel(q: c['q'], a: c['a']))
              .toList();
        });
        return;
      }
    }

    // défaut
    setState(() {
      cards = [
        CardModel(q: "Capitale de la France ?", a: "Paris"),
        CardModel(q: "2 + 2 ?", a: "4"),
      ];
    });

    saveCards();
  }

  // 🔹 Ajouter carte
  void addCard(String q, String a) {
    setState(() {
      cards.add(CardModel(q: q, a: a));
    });
    saveCards();
  }

  // 🔹 Mode intelligent
  void jeSais() {
    setState(() {
      score++;
      if (score % 3 == 0) niveau++;
      nextCard();
    });
  }

  void jeSaisPas() {
    setState(() {
      if (score > 0) score--;
      nextCard();
    });
  }

  void nextCard() {
    if (index < cards.length - 1) {
      index++;
    } else {
      index = 0;
    }
  }

  // 🔹 Dialog
  void showAddDialog() {
    String q = "";
    String a = "";

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Nouvelle flashcard"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: const InputDecoration(labelText: "Question"),
              onChanged: (value) => q = value,
            ),
            TextField(
              decoration: const InputDecoration(labelText: "Réponse"),
              onChanged: (value) => a = value,
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Annuler")),
          ElevatedButton(
              onPressed: () {
                if (q.isNotEmpty && a.isNotEmpty) {
                  addCard(q, a);
                }
                Navigator.pop(context);
              },
              child: const Text("Ajouter")),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (cards.isEmpty) {
      return const Scaffold(
        body: Center(
          child: Text("Aucune carte",
              style: TextStyle(color: Colors.white)),
        ),
      );
    }

    final card = cards[index];

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),

      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text("Flashcards PRO"),
      ),

      floatingActionButton: FloatingActionButton(
        onPressed: showAddDialog,
        child: const Icon(Icons.add),
      ),

      body: Column(
        children: [
          const SizedBox(height: 20),

          Image.asset("assets/logo.png", height: 80),

          const SizedBox(height: 10),

          const Text("Mode intelligent",
              style: TextStyle(color: Colors.white)),

          const SizedBox(height: 10),

          Text("Score : $score",
              style: const TextStyle(color: Colors.green, fontSize: 18)),

          Text("Carte ${index + 1} / ${cards.length}",
              style: const TextStyle(color: Colors.white70)),

          const SizedBox(height: 5),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.green,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text("Niveau : $niveau",
                style: const TextStyle(color: Colors.white)),
          ),

          const SizedBox(height: 30),

          // 🔹 Carte
          Container(
            margin: const EdgeInsets.all(20),
            padding: const EdgeInsets.all(30),
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Colors.blue, Colors.cyan],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                Text(
                  card.q,
                  style: const TextStyle(
                      fontSize: 20, color: Colors.white),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                Text(
                  card.a,
                  style: const TextStyle(
                      fontSize: 16, color: Colors.white70),
                )
              ],
            ),
          ),

          const SizedBox(height: 20),

          // 🔹 Boutons IA
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: jeSaisPas,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                ),
                child: const Text("Je ne sais pas"),
              ),
              const SizedBox(width: 20),
              ElevatedButton(
                onPressed: jeSais,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                ),
                child: const Text("Je sais"),
              ),
            ],
          ),
        ],
      ),
    );
  }
}