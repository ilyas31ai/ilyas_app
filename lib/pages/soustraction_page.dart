import 'package:flutter/material.dart';
import 'dart:math';

class SoustractionPage extends StatefulWidget {
  const SoustractionPage({super.key});

  @override
  State<SoustractionPage> createState() => _SoustractionPageState();
}

class _SoustractionPageState extends State<SoustractionPage> {
  int num1 = 0;
  int num2 = 0;
  int score = 0;
  List<int> options = [];

  @override
  void initState() {
    super.initState();
    generateQuestion();
  }

  void generateQuestion() {
    final random = Random();

    num1 = random.nextInt(10) + 2;
    num2 = random.nextInt(num1 - 1) + 1;

    int correctAnswer = num1 - num2;

    options = [
      correctAnswer,
      correctAnswer + random.nextInt(3) + 1,
      correctAnswer - random.nextInt(2),
    ];

    options = options.toSet().toList();

    while (options.length < 3) {
      options.add(random.nextInt(10));
    }

    options.shuffle();

    setState(() {});
  }

  void checkAnswer(int answer) {
    int correct = num1 - num2;

    if (answer == correct) {
      score++;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Bravo 🎉")),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Essaie encore 😅")),
      );
    }

    generateQuestion();
  }

  Widget buildOption(int value, Color color) {
    return GestureDetector(
      onTap: () => checkAnswer(value),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color.withValues(alpha: 0.8), color.withValues(alpha: 0.4)],
          ),
          borderRadius: BorderRadius.circular(30),
        ),
        child: Center(
          child: Text(
            "$value",
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
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
        title: const Text("Jeu Soustractions ➖"),
      ),
      body: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFF7E5F), Color(0xFFFFB88C)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/logo.png',
              height: 80,
            ),
            const SizedBox(height: 10),
            const Text(
              "SCOLAR AI Educative",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 30),
            Text(
              "$num1 - $num2 = ?",
              style: const TextStyle(
                fontSize: 28,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 30),
            buildOption(options[0], Colors.blue),
            buildOption(options[1], Colors.green),
            buildOption(options[2], Colors.purple),
            const SizedBox(height: 20),
            Text(
              "Score: $score",
              style: const TextStyle(color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}