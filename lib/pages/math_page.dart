import 'package:flutter/material.dart';
import 'dart:math';

class MathPage extends StatefulWidget {
  const MathPage({super.key});

  @override
  State<MathPage> createState() => _MathPageState();
}

class _MathPageState extends State<MathPage> {
  int table = 1; // 🔥 niveau
  int a = 0;
  int correctAnswer = 0;
  List<int> options = [];
  int score = 0;

  @override
  void initState() {
    super.initState();
    generateQuestion();
  }

  void generateQuestion() {
    final random = Random();

    a = random.nextInt(10) + 1;
    correctAnswer = table * a;

    options = [
      correctAnswer,
      correctAnswer + random.nextInt(5) + 1,
      (correctAnswer - random.nextInt(3)).abs(),
    ];

    options = options.toSet().toList();

    while (options.length < 3) {
      options.add(random.nextInt(100));
    }

    options.shuffle();

    setState(() {});
  }

  void nextLevel() {
    if (table < 10) {
      table++;
      score = 0;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("🎉 Niveau $table !"),
          backgroundColor: Colors.orange,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("🏆 Bravo ! Jeu terminé"),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void checkAnswer(int value) {
    if (value == correctAnswer) {
      score++;

      if (score == 5) {
        nextLevel();
      }

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
              color.withOpacity(0.8),
              color.withOpacity(0.4),
            ],
          ),
          borderRadius: BorderRadius.circular(30),
        ),
        child: Center(
          child: Text(
            "$value",
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
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
        title: const Text("Multiplications 🧮"),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF4facfe), Color(0xFF00f2fe)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 🔥 LOGO
            Image.asset('assets/logo.png', height: 80),

            const SizedBox(height: 10),

            // 🎯 NIVEAU
            Text(
              "Table de $table",
              style: const TextStyle(
                fontSize: 20,
                color: Colors.white,
              ),
            ),

            const SizedBox(height: 20),

            // ❓ QUESTION
            Text(
              "$table x $a = ?",
              style: const TextStyle(
                fontSize: 36,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 30),

            // 🔘 OPTIONS
            answerButton(options[0], Colors.blue),
            answerButton(options[1], Colors.green),
            answerButton(options[2], Colors.purple),

            const SizedBox(height: 20),

            // 📊 SCORE
            Text(
              "Score : $score / 5",
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }
}