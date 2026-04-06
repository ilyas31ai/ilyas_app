import 'package:flutter/material.dart';

// 🔥 IMPORT DES PAGES
import 'pages/home_page.dart';
import 'pages/eleves_page.dart';
import 'pages/emploi_page.dart';
import 'pages/devoirs_page.dart';
import 'pages/notifications_page.dart';
import 'pages/plan_classe_page.dart';
import 'pages/quiz_page.dart';
import 'pages/fiches_page.dart';
import 'pages/flashcards_page.dart';
import 'pages/discussion_page.dart';
import 'pages/amis_page.dart';
import 'pages/professeurs_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ILYAS APP',
      theme: ThemeData.dark(),

      // 🏠 ACCUEIL
      home: const HomePage(),

      routes: {
  '/eleves': (context) => const ElevesMenuPage(),
  '/emploi': (context) => const EmploiPage(),
  '/devoirs': (context) => const DevoirsPage(),
  '/notifications': (context) => const NotificationsPage(),
  '/plan': (context) => const PlanClassePage(),
  '/quiz': (context) => const QuizPage(),
  '/fiches': (context) => const FichesPage(),
  '/flashcards': (context) => const FlashcardsPage(),

  // ✅ CORRECTION ICI (TRÈS IMPORTANT)
  '/discussion': (context) {
    final args =
        ModalRoute.of(context)!.settings.arguments as Map;

    return DiscussionPage(
      name: args['name'],
    );
  },

  '/amis': (context) => const AmisPage(),
  '/professeurs': (context) => const ProfesseursPage(),
},
    );
  }
}