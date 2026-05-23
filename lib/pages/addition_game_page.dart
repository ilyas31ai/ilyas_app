import 'dart:math';
import 'package:flutter/material.dart';

class AdditionGamePage extends StatefulWidget {
  const AdditionGamePage({super.key});

  @override
  State<AdditionGamePage> createState() => _AdditionGamePageState();
}

class _AdditionGamePageState extends State<AdditionGamePage> {
  int a = 0;
  int b = 0;
  int correctAnswer = 0;
  int score = 0;

  List<int> options = [];

  void generateQuestion() {
    final random = Random();

    a = random.nextInt(10);
    b = random.nextInt(10);
    correctAnswer = a + b;

    options = [
      correctAnswer,
      correctAnswer + random.nextInt(3) + 1,
      correctAnswer - (random.nextInt(3) + 1),
    ];

    options.shuffle();
  }

  void checkAnswer(int answer) {
    if (answer == correctAnswer) {
      setState(() {
        score++;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("🎉 Bravo !")),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ Réponse: $correctAnswer")),
      );
    }

    setState(() {
      generateQuestion();
    });
  }

  @override
  void initState() {
    super.initState();
    generateQuestion();
  }

  Widget answerButton(int value, Color color) {
    return GestureDetector(
      onTap: () => checkAnswer(value),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color.withOpacity(0.8), color.withOpacity(0.4)],
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Center(
          child: Text(
            value.toString(),
            style: const TextStyle(
              fontSize: 28,
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
        title: const Text("Jeu Additions ➕"),
      ),
      body: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.orange, Colors.red],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [

            // 🔥 LOGO
            Image.asset(
              'assets/logo.png',
              height: 80,
            ),

            const SizedBox(height: 10),

            const Text(
              "ILYAS31AI",
              style: TextStyle(
                fontSize: 22,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 30),

            // ❓ QUESTION
            Text(
              "$a + $b = ?",
              style: const TextStyle(
                fontSize: 40,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 30),

            // 🎯 RÉPONSES
            answerButton(options[0], Colors.blue),
            answerButton(options[1], Colors.green),
            answerButton(options[2], Colors.purple),

            const SizedBox(height: 30),

            // 📊 SCORE
            Text(
              "Score: $score",
              style: const TextStyle(
                fontSize: 24,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}