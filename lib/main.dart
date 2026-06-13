import 'package:flutter/material.dart';

// 🔥 FIREBASE
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';

// 📄 PAGES
import 'pages/login_page.dart';
import 'pages/main_shell.dart';
import 'pages/eleves_page.dart';
import 'pages/scan_page.dart';
import 'pages/espace_direction_page.dart';
import 'pages/espace_professeur_page.dart';
import 'pages/monde_enfants_page.dart';
import 'pages/jeux_scolaires_page.dart';
import 'pages/leaderboard_page.dart';

// 🧠 ÉLÈVES
import 'pages/quiz_page.dart';
import 'pages/fiches_page.dart';
import 'pages/flashcards_page.dart';
import 'pages/devoirs_page.dart';
import 'pages/etudiant_devoirs_page.dart';
import 'pages/etudiant_revisions_page.dart';
import 'pages/notes_page.dart';
import 'pages/emploi_page.dart';
import 'pages/notifications_page.dart';
import 'pages/plan_classe_page.dart';
import 'pages/etudiant_dashboard_page.dart';
import 'pages/etudiant_documents_page.dart';
import 'pages/etudiant_annonces_page.dart';

// 🎮 ENFANTS
import 'pages/alphabet_page.dart';
import 'pages/chiffres_page.dart';
import 'pages/couleurs_page.dart';
import 'pages/animaux_dessin_page.dart';
import 'pages/lecture_page.dart';
import 'pages/addition_game_page.dart';
import 'pages/soustraction_page.dart';
import 'pages/compter_page.dart';
import 'pages/comparer_page.dart';
import 'pages/math_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 🔥 INITIALISATION FIREBASE
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // 🔕 NOTIFICATIONS DÉSACTIVÉES TEMPORAIREMENT
  // await NotificationService.init("ilyas");

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  static String get currentUser =>
      FirebaseAuth.instance.currentUser?.email ?? '';

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ILYAS APP',

      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0D1117),
        useMaterial3: true,
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF2563EB),
          surface: Color(0xFF161B22),
        ),
      ),

      // 🏠 AUTH GUARD
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              backgroundColor: Color(0xFF0D1117),
              body: Center(
                child: CircularProgressIndicator(color: Color(0xFF2563EB)),
              ),
            );
          }
          if (snapshot.hasData) return const MainShell();
          return const LoginPage();
        },
      ),

      routes: {
        // 📌 PRINCIPAL
        '/eleves': (context) => const ElevesPage(),

        '/scan': (context) => const ScanPage(),

        '/espace_direction': (context) => const EspaceDirectionPage(),

        '/espace_professeur': (context) => const EspaceProfesseurPage(),

        '/monde_enfants': (context) =>
            const MondeEnfantsPage(),

        '/jeux_scolaires': (context) => const JeuxScolairesPage(),

        '/leaderboard': (context) => const LeaderboardPage(),

        // 🎓 ÉLÈVES
        '/quiz': (context) => const QuizPage(),

        '/fiches': (context) => const FichesPage(),

        '/flashcards': (context) =>
            const FlashcardsPage(),

        '/devoirs': (context) => const DevoirsPage(),

        '/etudiant_devoirs': (context) => const EtudiantDevoirsPage(),

        '/etudiant_revisions': (context) => const EtudiantRevisionsPage(),

        '/notes': (context) => const NotesPage(),

        '/emploi': (context) => const EmploiPage(),

        // 🔔 NOTIFICATIONS
        '/notifications': (context) =>
            NotificationsPage(
              currentUser: currentUser,
            ),

        '/plan': (context) => const PlanClassePage(),

        '/etudiant_dashboard': (context) => const EtudiantDashboardPage(),

        '/etudiant_documents': (context) => const EtudiantDocumentsPage(),

        '/etudiant_annonces': (context) => const EtudiantAnnoncesPage(),

        // 🎮 ENFANTS
        '/alphabet': (context) => const AlphabetPage(),

        '/chiffres': (context) => const ChiffresPage(),

        '/couleurs': (context) => const CouleursPage(),

        '/animaux': (context) =>
            const AnimauxDessinPage(),

        '/lecture': (context) => const LecturePage(),

        '/addition': (context) =>
            const AdditionGamePage(),

        '/soustraction': (context) =>
            const SoustractionPage(),

        '/compter': (context) => const CompterPage(),

        '/comparer': (context) => const ComparerPage(),

        '/math': (context) => const MathPage(),
      },

    );
  }
}