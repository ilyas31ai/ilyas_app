import 'dart:async';
import 'package:flutter/material.dart';

class QuizPage extends StatefulWidget {
  const QuizPage({super.key});

  @override
  State<QuizPage> createState() => _QuizPageState();
}

class _QuizPageState extends State<QuizPage> {
  int questionIndex = 0;
  int score = 0;
  String? selectedAnswer;

  int timeLeft = 10;
  Timer? timer;

  final List<Map<String, dynamic>> questions = [
    {
      'question': 'Quelle est la capitale de la France ?',
      'answers': ['Paris', 'Londres', 'Berlin', 'Madrid'],
      'correct': 'Paris',
    },
    {
      'question': '2 + 2 = ?',
      'answers': ['3', '4', '5', '6'],
      'correct': '4',
    },
    {
      'question': 'Couleur du ciel ?',
      'answers': ['Rouge', 'Bleu', 'Vert', 'Jaune'],
      'correct': 'Bleu',
    },
  ];

  @override
  void initState() {
    super.initState();
    startTimer();
  }

  void startTimer() {
    timeLeft = 10;
    timer?.cancel();
    timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (timeLeft == 0) {
        nextQuestion(null);
      } else {
        setState(() => timeLeft--);
      }
    });
  }

  void nextQuestion(String? answer) {
    timer?.cancel();

    if (answer != null &&
        answer == questions[questionIndex]['correct']) {
      score++;
    }

    if (questionIndex < questions.length - 1) {
      setState(() {
        questionIndex++;
        selectedAnswer = null;
      });
      startTimer();
    } else {
      showResult();
    }
  }

  void selectAnswer(String answer) {
    setState(() {
      selectedAnswer = answer;
    });

    Future.delayed(const Duration(milliseconds: 500), () {
      nextQuestion(answer);
    });
  }

  void showResult() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text("🎉 Résultat"),
        content: Text("Score : $score / ${questions.length}"),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              restartQuiz();
            },
            child: const Text("Rejouer"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text("Quitter"),
          ),
        ],
      ),
    );
  }

  void restartQuiz() {
    setState(() {
      questionIndex = 0;
      score = 0;
      selectedAnswer = null;
    });
    startTimer();
  }

  Color getColor(String answer) {
    if (selectedAnswer == null) return Colors.blue;

    if (answer == questions[questionIndex]['correct']) {
      return Colors.green;
    } else if (answer == selectedAnswer) {
      return Colors.red;
    }
    return Colors.grey;
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var current = questions[questionIndex];

    double progress =
        (questionIndex + 1) / questions.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Quiz PRO 🚀"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            timer?.cancel();
            Navigator.pop(context);
          },
        ),
      ),

      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // 🔥 LOGO
            Image.asset('assets/logo.png', height: 70),

            const SizedBox(height: 10),

            // 📊 PROGRESS BAR
            LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              borderRadius: BorderRadius.circular(10),
            ),

            const SizedBox(height: 10),

            // ⏱ TIMER
            Text(
              "⏱ $timeLeft s",
              style: const TextStyle(fontSize: 18),
            ),

            const SizedBox(height: 10),

            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Question ${questionIndex + 1}/${questions.length}",
                style: const TextStyle(color: Colors.grey),
              ),
            ),

            const SizedBox(height: 10),

            Text(
              current['question'],
              style: const TextStyle(fontSize: 20),
            ),

            const SizedBox(height: 20),

            ...current['answers'].map<Widget>((ans) {
              return Container(
                margin: const EdgeInsets.symmetric(vertical: 6),
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: getColor(ans),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: selectedAnswer == null
                      ? () => selectAnswer(ans)
                      : null,
                  child: Text(ans),
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }
}