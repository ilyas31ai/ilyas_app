import 'package:flutter/material.dart';
import 'dart:math';

class LecturePage extends StatefulWidget {
  const LecturePage({super.key});

  @override
  State<LecturePage> createState() => _LecturePageState();
}

class _LecturePageState extends State<LecturePage> {
  final List<String> mots = [
    "PAPA",
    "MAMAN",
    "CHAT",
    "CHIEN",
    "LIVRE",
    "VOITURE",
  ];

  String motCorrect = "";
  List<String> options = [];
  int score = 0;

  @override
  void initState() {
    super.initState();
    genererQuestion();
  }

  void genererQuestion() {
    final random = Random();

    motCorrect = mots[random.nextInt(mots.length)];

    options = [motCorrect];

    while (options.length < 3) {
      String mot = mots[random.nextInt(mots.length)];
      if (!options.contains(mot)) {
        options.add(mot);
      }
    }

    options.shuffle();
    setState(() {});
  }

  void verifier(String choix) {
    if (choix == motCorrect) {
      score++;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Bravo 🎉"),
          backgroundColor: Colors.green,
          duration: Duration(milliseconds: 800),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Essaie encore ❌"),
          backgroundColor: Colors.red,
          duration: Duration(milliseconds: 800),
        ),
      );
    }

    Future.delayed(const Duration(milliseconds: 900), () {
      genererQuestion();
    });
  }

  Widget bouton(String texte) {
    return GestureDetector(
      onTap: () => verifier(texte),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF667eea), Color(0xFF764ba2)],
          ),
          borderRadius: BorderRadius.circular(30),
        ),
        child: Center(
          child: Text(
            texte,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
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
        title: const Text("Lecture 📖"),
        backgroundColor: Colors.transparent,
      ),
      body: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFF9A9E), Color(0xFFFAD0C4)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Column(
          children: [
            const SizedBox(height: 20),

            Image.asset('assets/logo.png', height: 80),

            const SizedBox(height: 10),

            const Text(
              "Lis le mot 👇",
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),

            const SizedBox(height: 10),

            Text(
              motCorrect,
              style: const TextStyle(
                fontSize: 32,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 30),

            ...options.map((o) => bouton(o)).toList(),

            const Spacer(),

            Text(
              "Score : $score",
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