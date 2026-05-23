import 'package:flutter/material.dart';
import 'dart:math';

class ComparerPage extends StatefulWidget {
  const ComparerPage({super.key});

  @override
  State<ComparerPage> createState() => _ComparerPageState();
}

class _ComparerPageState extends State<ComparerPage> {
  int num1 = 0;
  int num2 = 0;
  int score = 0;

  @override
  void initState() {
    super.initState();
    generateQuestion();
  }

  // 🔥 Générer question
  void generateQuestion() {
    final random = Random();

    num1 = random.nextInt(10);
    num2 = random.nextInt(10);

    setState(() {});
  }

  // ✅ Vérifier réponse
  void checkAnswer(String answer) {
    String correct;

    if (num1 > num2) {
      correct = '>';
    } else if (num1 < num2) {
      correct = '<';
    } else {
      correct = '=';
    }

    if (answer == correct) {
      score++;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Bravo 🎉"),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Oops 😅"),
          backgroundColor: Colors.red,
        ),
      );
    }

    generateQuestion();
  }

  // 🔘 Bouton
  Widget button(String symbol, Color color) {
    return GestureDetector(
      onTap: () => checkAnswer(symbol),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color.withOpacity(0.8), color.withOpacity(0.4)],
          ),
          borderRadius: BorderRadius.circular(30),
        ),
        child: Center(
          child: Text(
            symbol,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 30,
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
        title: const Text("Comparer 📊"),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF2193b0), Color(0xFF6dd5ed)],
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

            const SizedBox(height: 20),

            // 🔢 QUESTION
            Text(
              "$num1  ?  $num2",
              style: const TextStyle(
                fontSize: 40,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 30),

            // 🔘 BOUTONS
            button(">", Colors.green),
            button("<", Colors.orange),
            button("=", Colors.purple),

            const SizedBox(height: 20),

            // 📊 SCORE
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