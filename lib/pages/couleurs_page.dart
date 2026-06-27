import 'package:flutter/material.dart';
import 'dart:math';

class CouleursPage extends StatefulWidget {
  const CouleursPage({super.key});

  @override
  State<CouleursPage> createState() => _CouleursPageState();
}

class _CouleursPageState extends State<CouleursPage> {
  Map<String, Color> colors = {
    "Rouge": Colors.red,
    "Bleu": Colors.blue,
    "Vert": Colors.green,
    "Jaune": Colors.yellow,
    "Orange": Colors.orange,
    "Violet": Colors.purple,
  };

  String correctName = "";
  Color correctColor = Colors.red;
  List<String> options = [];
  int score = 0;

  @override
  void initState() {
    super.initState();
    generateQuestion();
  }

  void generateQuestion() {
    final random = Random();

    List<String> keys = colors.keys.toList();
    correctName = keys[random.nextInt(keys.length)];
    correctColor = colors[correctName]!;

    options = [correctName];

    while (options.length < 3) {
      String randomColor = keys[random.nextInt(keys.length)];
      if (!options.contains(randomColor)) {
        options.add(randomColor);
      }
    }

    options.shuffle();
    setState(() {});
  }

  void checkAnswer(String value) {
    if (value == correctName) {
      score++;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Bravo 🎉"),
          backgroundColor: Colors.green,
          duration: Duration(milliseconds: 500),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Essaie encore 😅"),
          backgroundColor: Colors.red,
          duration: Duration(milliseconds: 500),
        ),
      );
    }

    Future.delayed(const Duration(milliseconds: 600), () {
      generateQuestion();
    });
  }

  Widget answerButton(String text, Color color) {
    return InkWell(
      borderRadius: BorderRadius.circular(30),
      onTap: () => checkAnswer(text),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              color.withValues(alpha: 0.8),
              color.withValues(alpha: 0.4),
            ],
          ),
          borderRadius: BorderRadius.circular(30),
        ),
        child: Center(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 20,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Jeu Couleurs 🎨"),
        backgroundColor: Colors.transparent,
        centerTitle: true,
      ),
      body: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFff7e5f), Color(0xFFfeb47b)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('assets/logo.png', height: 80),

            const SizedBox(height: 20),

            const Text(
              "Quelle est cette couleur ? 👇",
              style: TextStyle(color: Colors.white, fontSize: 20),
            ),

            const SizedBox(height: 20),

            // 🎨 carré couleur
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: correctColor,
                borderRadius: BorderRadius.circular(20),
              ),
            ),

            const SizedBox(height: 30),

            answerButton(options[0], Colors.blue),
            answerButton(options[1], Colors.green),
            answerButton(options[2], Colors.purple),

            const SizedBox(height: 20),

            Text(
              "Score : $score",
              style: const TextStyle(color: Colors.white, fontSize: 18),
            ),
          ],
        ),
      ),
    );
  }
}