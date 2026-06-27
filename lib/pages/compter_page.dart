import 'package:flutter/material.dart';
import 'dart:math';

class CompterPage extends StatefulWidget {
  const CompterPage({super.key});

  @override
  State<CompterPage> createState() => _CompterPageState();
}

class _CompterPageState extends State<CompterPage> {
  int correctAnswer = 0;
  List<int> options = [];

  @override
  void initState() {
    super.initState();
    generateQuestion();
  }

  void generateQuestion() {
    final random = Random();

    correctAnswer = random.nextInt(9) + 1;

    options = [
      correctAnswer,
      correctAnswer + 1,
      correctAnswer - 1 > 0 ? correctAnswer - 1 : correctAnswer + 2,
    ];

    options = options.toSet().toList();

    while (options.length < 3) {
      options.add(random.nextInt(10) + 1);
    }

    options.shuffle();

    setState(() {});
  }

  void checkAnswer(int value) {
    if (value == correctAnswer) {
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

  Widget buildObjects() {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 10,
      children: List.generate(
        correctAnswer,
        (index) => const Icon(Icons.circle, color: Colors.white),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Compter 🔢")),
      body: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF36D1DC), Color(0xFF5B86E5)],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('assets/logo.png', height: 80),
            const SizedBox(height: 20),
            const Text("Combien ?", style: TextStyle(color: Colors.white)),
            const SizedBox(height: 20),
            buildObjects(),
            const SizedBox(height: 30),
            buildOption(options[0], Colors.blue),
            buildOption(options[1], Colors.green),
            buildOption(options[2], Colors.purple),
          ],
        ),
      ),
    );
  }
}