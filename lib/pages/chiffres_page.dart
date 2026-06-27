import 'package:flutter/material.dart';
import 'dart:math';

class ChiffresPage extends StatefulWidget {
  const ChiffresPage({super.key});

  @override
  State<ChiffresPage> createState() => _ChiffresPageState();
}

class _ChiffresPageState extends State<ChiffresPage> {
  int correct = 0;
  List<int> options = [];
  int score = 0;

  @override
  void initState() {
    super.initState();
    generateQuestion();
  }

  void generateQuestion() {
    final random = Random();

    correct = random.nextInt(5) + 1; // 1 à 5

    options = [correct];

    while (options.length < 3) {
      int n = random.nextInt(6) + 1;
      if (!options.contains(n)) {
        options.add(n);
      }
    }

    options.shuffle();
    setState(() {});
  }

  void checkAnswer(int value) {
    if (value == correct) {
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

  String getEmojis(int n) {
    return "🍎 " * n;
  }

  Widget answerButton(int value, Color color) {
    return InkWell(
      borderRadius: BorderRadius.circular(30),
      onTap: () => checkAnswer(value),
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
            "$value",
            style: const TextStyle(
              fontSize: 24,
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
        title: const Text("Jeu Chiffres 🔢"),
        backgroundColor: Colors.transparent,
        centerTitle: true,
      ),
      body: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFf7971e), Color(0xFFffd200)],
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
              "Combien il y a ? 👇",
              style: TextStyle(color: Colors.white, fontSize: 20),
            ),

            const SizedBox(height: 20),

            Text(
              getEmojis(correct),
              style: const TextStyle(fontSize: 40),
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