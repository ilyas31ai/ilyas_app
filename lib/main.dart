import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

// 🔥 FIREBASE
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';

// 📄 PAGES
import 'pages/login_page.dart';
import 'pages/main_shell.dart';
import 'pages/eleves_page.dart';
import 'pages/scolar_connect_page.dart';
import 'pages/scolar_chat_room_page.dart';
import 'pages/espace_direction_page.dart';
import 'pages/espace_parent_page.dart';
import 'pages/espace_professeur_page.dart';
import 'pages/monde_enfants_page.dart';
import 'pages/jeux_scolaires_page.dart';
import 'pages/leaderboard_page.dart';
import 'pages/professeur_rdv_page.dart';
import 'services/notification_service.dart';

// 🏫 ROUTES — Architecture multi-cycles
import 'routes/app_routes.dart';
import 'pages/cycle_placeholder_page.dart';

// 📋 BULLETIN / RELEVÉ DE NOTES
import 'pages/eleve_releve_notes_page.dart';

// 🆕 NOUVEAUX MODULES
import 'pages/register_page.dart';
import 'pages/pending_validation_page.dart';
import 'pages/professeur_dossier_page.dart';
import 'pages/inscription_wizard_page.dart';
import 'pages/scolar_profile_page.dart';
import 'pages/scolar_salle_page.dart';

// 👩‍🏫 PROFESSEUR — sous-pages (deep-link direct)
import 'pages/professeur_dashboard_page.dart';
import 'pages/professeur_emploi_page.dart';
import 'pages/professeur_notes_page.dart';
import 'pages/professeur_devoirs_page.dart';
import 'pages/professeur_eleves_page.dart';
import 'pages/professeur_presences_page.dart';
import 'pages/professeur_documents_page.dart';
import 'pages/professeur_bibliotheque_page.dart';
import 'pages/professeur_corrige_page.dart';
import 'pages/professeur_evaluations_qualitative_page.dart';
import 'pages/professeur_messagerie_page.dart';

// 🏛️ DIRECTION — sous-pages (deep-link direct)
import 'pages/fiche_enseignant_page.dart';
import 'pages/direction_dashboard_page.dart';
import 'pages/direction_classes_page.dart';
import 'pages/direction_disponibilites_page.dart';
import 'pages/direction_eleves_page.dart';
import 'pages/direction_historique_remplacements_page.dart';
import 'pages/direction_statistiques_page.dart';
import 'pages/direction_stats_remplacements_page.dart';
import 'pages/professeur_disponibilite_page.dart';

// 🏫 PRIMAIRE — écrans de production
import 'pages/primaire_dashboard_page.dart';

// 🌸 MATERNELLE — écrans de production (Lots 6 & 8)
import 'pages/maternelle_dashboard_page.dart';
import 'pages/maternelle_activites_page.dart';
import 'pages/maternelle_competences_page.dart';
import 'pages/maternelle_observations_page.dart';
import 'pages/maternelle_presences_page.dart';
import 'pages/maternelle_communication_page.dart';
import 'pages/maternelle_cahier_vie_page.dart';
import 'pages/maternelle_albums_page.dart';
import 'pages/maternelle_histoires_page.dart';
import 'pages/maternelle_galerie_page.dart';
import 'pages/maternelle_coloriages_page.dart';
import 'pages/maternelle_comptines_page.dart';
import 'pages/maternelle_repas_page.dart';
import 'pages/maternelle_sieste_page.dart';
import 'pages/maternelle_calendrier_page.dart';

// 🎓 UNIVERSITÉ — écrans de production (Lot 6)
import 'pages/universite_dashboard_page.dart';
import 'pages/universite_ues_page.dart';
import 'pages/universite_ects_page.dart';
import 'pages/universite_semestres_page.dart';
import 'pages/universite_parcours_page.dart';
import 'pages/universite_options_page.dart';
import 'pages/universite_examens_page.dart';
import 'pages/universite_rattrapages_page.dart';
import 'pages/universite_stages_page.dart';
import 'pages/universite_memoires_page.dart';
import 'pages/universite_soutenances_page.dart';

// 🏫 COLLÈGE — écrans de production (Lot 5)
import 'pages/college_dashboard_page.dart';
import 'pages/college_matieres_page.dart';
import 'pages/college_devoirs_page.dart';
import 'pages/college_notes_page.dart';
import 'pages/college_brevet_page.dart';
import 'pages/college_orientation_page.dart';
import 'pages/college_presences_page.dart';

// 🎓 LYCÉE — écrans de production (Lot 5)
import 'pages/lycee_dashboard_page.dart';
import 'pages/lycee_matieres_page.dart';
import 'pages/lycee_devoirs_page.dart';
import 'pages/lycee_notes_page.dart';
import 'pages/lycee_bac_page.dart';
import 'pages/lycee_orientation_page.dart';
import 'pages/lycee_presences_page.dart';
import 'pages/lycee_controle_continu_page.dart';
import 'pages/lycee_specialites_page.dart';

// 🧠 ÉLÈVES
import 'pages/quiz_page.dart';
import 'pages/fiches_page.dart';
import 'pages/flashcards_page.dart';
import 'pages/devoirs_page.dart';
import 'pages/etudiant_devoirs_page.dart';
import 'pages/etudiant_revisions_page.dart';
import 'pages/ai_scolaire_page.dart';
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

// Évite de ré-initialiser NotificationService à chaque rebuild du StreamBuilder
// pour le même utilisateur déjà connecté.
String? _notifInitializedFor;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Capture TOUTES les erreurs Flutter non gérées avec stacktrace complet
  FlutterError.onError = (FlutterErrorDetails details) {
    debugPrint('══════════════════════════════════════════');
    debugPrint('[FLUTTER_ERROR] ${details.exceptionAsString()}');
    debugPrint('[FLUTTER_ERROR] Stack:\n${details.stack}');
    debugPrint('══════════════════════════════════════════');
    FlutterError.presentError(details);
  };

  // Capture les erreurs async non rattrapées (Futures, Streams)
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('══════════════════════════════════════════');
    debugPrint('[PLATFORM_ERROR] ${error.runtimeType}: $error');
    debugPrint('[PLATFORM_ERROR] Stack:\n$stack');
    debugPrint('══════════════════════════════════════════');
    return true;
  };

  // 🔥 INITIALISATION FIREBASE
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } on FirebaseException catch (e) {
    if (e.code != 'duplicate-app') rethrow;
    // duplicate-app = hot restart ou pré-init native Android, app déjà prête
  }

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
      title: 'ScolarAI Educative',

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
          if (snapshot.hasData) {
            final uid = snapshot.data!.uid;
            final email = snapshot.data!.email ?? '';
            return StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(uid)
                  .snapshots(),
              builder: (context, userSnap) {
                if (userSnap.connectionState == ConnectionState.waiting) {
                  return const Scaffold(
                    backgroundColor: Color(0xFF0D1117),
                    body: Center(
                      child: CircularProgressIndicator(
                          color: Color(0xFF2563EB)),
                    ),
                  );
                }
                final data =
                    userSnap.data?.data() as Map<String, dynamic>? ?? {};
                final statut = data['statut'] as String? ?? 'actif';

                if (statut == 'en_attente') {
                  return PendingValidationPage(
                    displayName: data['displayName'] as String? ?? '',
                    role: data['role'] as String? ?? 'eleve',
                    cycle: data['categorie'] as String?,
                    classeDemandee: data['classeDemandee'] as String?,
                    matiere: data['matiere'] as String?,
                  );
                }

                if (statut == 'refuse') {
                  return _RefusedPage(
                    displayName: data['displayName'] as String? ?? '',
                    motif: data['refusMotif'] as String?,
                  );
                }

                // statut == 'actif' (or any unknown value — backwards compat)
                if (email.isNotEmpty && email != _notifInitializedFor) {
                  _notifInitializedFor = email;
                  NotificationService.init(email);
                }
                return const MainShell();
              },
            );
          }
          _notifInitializedFor = null;
          return const LoginPage();
        },
      ),

      // /discussion prend des arguments → onGenerateRoute
      onGenerateRoute: (settings) {
        if (settings.name == '/discussion') {
          final args =
              settings.arguments as Map<String, dynamic>? ?? {};
          return MaterialPageRoute(
            builder: (_) => SCOLARChatRoomPage(
              name: args['name'] as String? ?? '',
              user: args['user'] as String? ?? currentUser,
              displayName: args['displayName'] as String?,
            ),
          );
        }
        return null;
      },

      routes: {
        // 📌 PRINCIPAL
        '/eleves': (context) => const ElevesPage(),

        '/espace_direction': (context) => const EspaceDirectionPage(),

        '/espace_parent': (context) => const EspaceParentPage(),

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

        '/ai_scolaire': (context) => const AiScolairePage(),

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

        '/professeur_rdv': (context) => const ProfesseurRdvPage(),

        // ── Professeur — deep-link sous-pages ──────────────────────────────
        AppRoutes.professeurTableauBord: (_) =>
            const ProfesseurDashboardPage(),
        AppRoutes.professeurEmploi: (_) => const ProfesseurEmploiPage(),
        AppRoutes.professeurNotes: (_) => const ProfesseurNotesPage(),
        AppRoutes.professeurDevoirs: (_) => const ProfesseurDevoirsPage(),
        AppRoutes.professeurEleves: (_) => const ProfesseurElevesPage(),
        AppRoutes.professeurPresences: (_) =>
            const ProfesseurPresencesPage(),
        AppRoutes.professeurDocuments: (_) =>
            const ProfesseurDocumentsPage(),
        AppRoutes.professeurBibliotheque: (_) =>
            const ProfesseurBibliothequePage(),
        AppRoutes.professeurCorrige: (_) => const ProfesseurCorrigePage(),
        AppRoutes.professeurMessagerie: (_) =>
            const ProfesseurMessageriePage(),
        AppRoutes.professeurEvaluationsQualitatives: (_) =>
            const ProfesseurEvaluationsQualitativePage(),

        // ── Direction — deep-link sous-pages ───────────────────────────────
        AppRoutes.directionTableauBord: (_) =>
            const DirectionDashboardPage(),
        AppRoutes.directionClasses: (_) => const DirectionClassesPage(),
        AppRoutes.directionEleves: (_) => const DirectionElevesPage(),
        AppRoutes.directionStatistiques: (_) => const DirectionStatistiquesPage(),

        // ── Direction — disponibilités & remplacements ─────────────────────
        '/direction_disponibilites': (_) =>
            const DirectionDisponibilitesPage(),
        '/direction_historique_remplacements': (_) =>
            const DirectionHistoriqueRemplacementsPage(),
        '/direction_stats_remplacements': (_) =>
            const DirectionStatsRemplacementsPage(),
        '/fiche_enseignant': (context) {
          final args = ModalRoute.of(context)!.settings.arguments
              as Map<String, dynamic>? ?? {};
          return FicheEnseignantPage(
            uid: args['uid'] as String? ?? '',
            displayName: args['displayName'] as String? ?? '',
          );
        },
        '/professeur_disponibilite': (_) =>
            const ProfesseurDisponibilitePage(),
        AppRoutes.directionSeedReferentiel: (_) =>
            const CyclePlaceholderPage(
              title: 'Initialisation Référentiel',
              subtitle:
                  'Initialiser les cycles scolaires, niveaux et l\'établissement dans Firestore',
              cycleId: 'direction',
              icon: Icons.cloud_upload_outlined,
              features: [
                'Seed cycles : Maternelle → Université',
                'Seed niveaux : PS, 1AP, 1AM, 1AS, L1…',
                'Seed établissement par défaut',
                'Idempotent — peut être relancé sans risque',
              ],
            ),

        // ── Maternelle ─────────────────────────────────────────────────────
        AppRoutes.maternelleTableauBord: (_) => const MaternelleDashboardPage(),
        AppRoutes.maternelleActivites: (_) => const MaterneileActivitesPage(),
        AppRoutes.maternelleEvaluations: (_) => const MaterneileCompetencesPage(),
        AppRoutes.maternellePortfolio: (_) => const MaterneileObservationsPage(),
        AppRoutes.maternellePresences: (_) => const MaterneilePresencesPage(),
        AppRoutes.maternelleCommunication: (_) => const MaternelleCommunicationPage(),
        AppRoutes.maternelleCahierVie: (_) => const MaternelleCahierViePage(),
        AppRoutes.maternelleAlbums: (_) => const MaternelleAlbumsPage(),
        AppRoutes.maternelleHistoires: (_) => const MaternelleHistoiresPage(),
        AppRoutes.maternelleGalerie: (_) => const MaternelleGaleriePage(),
        AppRoutes.maternelleColoriages: (_) => const MaternelleColoriagesPage(),
        AppRoutes.maternelleComptines: (_) => const MaternelleComptinesPage(),
        AppRoutes.maternelleRepas: (_) => const MaternelleRepasPage(),
        AppRoutes.maternelleSieste: (_) => const MaternelleSiestePage(),
        AppRoutes.maternelleCalendrier: (_) => const MaternelleCalendrierPage(),

        // ── Primaire ───────────────────────────────────────────────────────
        AppRoutes.primaireTableauBord: (_) => const PrimaireDashboardPage(),
        AppRoutes.primaireBulletin: (_) => const EleveReleveNotesPage(),

        // ── Collège ────────────────────────────────────────────────────────
        AppRoutes.collegeTableauBord: (_) => const CollegeDashboardPage(),
        AppRoutes.collegeMatieres: (_) => const CollegeMatieresPage(),
        AppRoutes.collegeDevoirs: (_) => const CollegeDevoirs(),
        AppRoutes.collegeNotes: (_) => const CollegeNotesPage(),
        AppRoutes.collegeBulletin: (_) => const EleveReleveNotesPage(),
        AppRoutes.collegeBrevet: (_) => const CollegeBrevePage(),
        AppRoutes.collegeOrientation: (_) => const CollegeOrientationPage(),
        AppRoutes.collegePresences: (_) => const CollegePresencesPage(),

        // ── Lycée ──────────────────────────────────────────────────────────
        AppRoutes.lyceeTableauBord: (_) => const LyceeDashboardPage(),
        AppRoutes.lyceeMatieres: (_) => const LyceeMatieresPage(),
        AppRoutes.lyceeDevoirs: (_) => const LyceeDevoirs(),
        AppRoutes.lyceeNotes: (_) => const LyceeNotesPage(),
        AppRoutes.lyceeBulletin: (_) => const EleveReleveNotesPage(),
        AppRoutes.lyceeBacBlanc: (_) => const LyceeBacPage(),
        AppRoutes.lyceeOrientation: (_) => const LyceeOrientationPage(),
        AppRoutes.lyceePresences: (_) => const LyceePresencesPage(),
        AppRoutes.lyceeControleConu: (_) => const LyceeControleContinuPage(),
        AppRoutes.lyceeSpecialites: (_) => const LyceeSpecialitesPage(),

        // ── Université ─────────────────────────────────────────────────────
        AppRoutes.universiteTableauBord: (_) => const UniversiteDashboardPage(),
        AppRoutes.universiteUes: (_) => const UniversiteUesPage(),
        AppRoutes.universiteEcts: (_) => const UniversiteEctsPage(),
        AppRoutes.universiteSemestres: (_) => const UniversiteSemestresPage(),
        AppRoutes.universiteParcours: (_) => const UniversiteParcoursPage(),
        AppRoutes.universiteOptions: (_) => const UniversiteOptionsPage(),
        AppRoutes.universiteExamens: (_) => const UniversiteExamensPage(),
        AppRoutes.universiteRattrapages: (_) => const UniversiteRattrapagesPage(),
        AppRoutes.universiteStage: (_) => const UniversiteStagesPage(),
        AppRoutes.universiteMemoire: (_) => const UniversiteMemoiresPage(),
        AppRoutes.universiteSoutenances: (_) => const UniversiteSoutenancesPage(),

        // 💬 SCOLAR CONNECT
        '/scolar_connect': (context) => const SCOLARConnectPage(),
        '/amis': (context) => const SCOLARConnectPage(),
        '/users': (context) => const SCOLARConnectPage(),
        '/eleve_discussion': (context) => const SCOLARConnectPage(),

        // 🆕 REGISTER
        '/register': (context) => const RegisterPage(),
        '/professeur_dossier': (context) {
          final args = ModalRoute.of(context)!.settings.arguments
              as Map<String, dynamic>;
          return ProfesseurDossierPage(
            uid: args['uid'] as String,
            displayName: args['displayName'] as String,
            statut: args['statut'] as String,
            schoolNom: args['schoolNom'] as String?,
          );
        },

        // 🆕 INSCRIPTION WIZARD
        '/inscription_wizard': (context) =>
            const InscriptionWizardPage(),

        // 🆕 SCOLAR PROFILE
        '/scolar_profile': (context) {
          final args = ModalRoute.of(context)!.settings.arguments
              as Map<String, dynamic>? ??
              {};
          return SCOLARProfilePage(
            email: args['email'] as String? ?? '',
            isOwn: args['isOwn'] as bool? ?? false,
          );
        },

        // 🆕 SCOLAR SALLE
        '/scolar_salle': (context) {
          final args = ModalRoute.of(context)!.settings.arguments
              as Map<String, dynamic>? ??
              {};
          return SCOLARSallePage(
            salleNom: args['salleNom'] as String? ?? 'Salle 1',
            matiere: args['matiere'] as String? ?? '',
          );
        },
      },

    );
  }
}

// ─── Refused page (shown when statut == 'refuse') ─────────────────────────────

class _RefusedPage extends StatelessWidget {
  final String displayName;
  final String? motif;
  const _RefusedPage({required this.displayName, this.motif});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: const BoxDecoration(
                  color: Color(0xFF1F2937),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.block_outlined,
                    color: Color(0xFFEF4444), size: 40),
              ),
              const SizedBox(height: 24),
              const Text(
                'Demande refusée',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              if (motif != null && motif!.isNotEmpty)
                Text(
                  'Motif : $motif',
                  style: const TextStyle(
                      color: Colors.white54, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              const SizedBox(height: 8),
              const Text(
                "Contactez votre établissement pour plus d'informations.",
                style: TextStyle(color: Colors.white38, fontSize: 13),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              TextButton(
                onPressed: () => FirebaseAuth.instance.signOut(),
                child: const Text(
                  'Se déconnecter',
                  style: TextStyle(color: Color(0xFFEF4444)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}