import 'dart:math';
import 'package:flutter/material.dart';

class AlphabetPage extends StatefulWidget {
  const AlphabetPage({super.key});

  @override
  State<AlphabetPage> createState() => _AlphabetPageState();
}

class _AlphabetPageState extends State<AlphabetPage> {
  final List<Map<String, String>> words = [
    {"word": "Chat", "letter": "C"},
    {"word": "Chien", "letter": "C"},
    {"word": "Banane", "letter": "B"},
    {"word": "Avion", "letter": "A"},
    {"word": "Éléphant", "letter": "E"},
    {"word": "Gâteau", "letter": "G"},
    {"word": "Fleur", "letter": "F"},
    {"word": "Maison", "letter": "M"},
  ];

  int score = 0;
  List<int> usedIndexes = [];

  String currentWord = "";
  String correctLetter = "";
  List<String> choices = [];

  @override
  void initState() {
    super.initState();
    generateQuestion();
  }

  void generateQuestion() {
    if (usedIndexes.length == words.length) {
      usedIndexes.clear();
    }

    int index;
    do {
      index = Random().nextInt(words.length);
    } while (usedIndexes.contains(index));

    usedIndexes.add(index);

    final item = words[index];

    currentWord = item["word"]!;
    correctLetter = item["letter"]!;

    generateChoices();
  }

  void generateChoices() {
    Set<String> options = {correctLetter};

    while (options.length < 3) {
      String randomLetter =
          String.fromCharCode(Random().nextInt(26) + 65);
      options.add(randomLetter);
    }

    choices = options.toList()..shuffle();
  }

  void checkAnswer(String answer) {
    if (answer == correctLetter) {
      score++;
      showResult(true);
    } else {
      showResult(false);
    }

    setState(() {
      generateQuestion();
    });
  }

  void showResult(bool success) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success ? "Bravo 🎉" : "Oops ❌",
        ),
        backgroundColor: success ? Colors.green : Colors.red,
        duration: const Duration(milliseconds: 600),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Jeu Alphabet 🎮"),
        backgroundColor: Colors.transparent,
        centerTitle: true,
      ),
      body: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue, Colors.green],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              "🎯 Trouve la première lettre",
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
            const SizedBox(height: 10),

            Text(
              currentWord,
              style: const TextStyle(
                fontSize: 34,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 30),

            ...choices.map((letter) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      backgroundColor: Colors.white.withValues(alpha: 0.2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    onPressed: () => checkAnswer(letter),
                    child: Text(
                      letter,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),

            const SizedBox(height: 20),

            Text(
              "Score : $score",
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
              ),
            )
          ],
        ),
      ),
    );
  }
}