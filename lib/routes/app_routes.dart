/// Constantes de routes de l'application, organisées par cycle scolaire et rôle.
///
/// Convention :
///  • Utiliser toujours ces constantes — jamais les chaînes littérales.
///  • Routes marquées `// → alias` réutilisent une page existante.
///  • Routes marquées `// → placeholder` pointent vers [CyclePlaceholderPage]
///    en attendant leur écran de production.
///  • Routes marquées `// → existant` étaient déjà dans main.dart.
class AppRoutes {
  AppRoutes._(); // Non instanciable

  // ── Shell & Global ──────────────────────────────────────────────────────────
  static const notifications = '/notifications'; // → existant
  static const messages = '/scolar_connect'; // → SCOLAR Connect
  static const eleveDiscussion = '/scolar_connect'; // → SCOLAR Connect
  static const scolarConnect = '/scolar_connect';
  static const messagerie = '/messagerie';
  static const espaceDirection = '/espace_direction'; // → existant
  static const espaceProfesseur = '/espace_professeur'; // → existant
  static const espaceParent = '/espace_parent'; // → existant
  static const eleves = '/eleves'; // → existant (ElevesPage)
  static const leaderboard = '/leaderboard'; // → existant

  // ── Maternelle ──────────────────────────────────────────────────────────────
  static const maternelleTableauBord = '/maternelle_tableau_bord';
  static const maternelleEvaluations = '/maternelle_evaluations'; // Compétences qualitatives
  static const maternellePortfolio = '/maternelle_portfolio'; // Observations
  static const maternelleActivites = '/maternelle_activites'; // Activités (prod Lot 6)
  static const maternellePresences = '/maternelle_presences';
  static const maternelleCommunication = '/maternelle_communication';
  static const maternelleCahierVie = '/maternelle_cahier_vie';
  static const maternelleAlbums = '/maternelle_albums';
  static const maternelleHistoires = '/maternelle_histoires';
  static const maternelleGalerie = '/maternelle_galerie';
  static const maternelleColoriages = '/maternelle_coloriages';
  static const maternelleComptines = '/maternelle_comptines';
  static const maternelleRepas = '/maternelle_repas';
  static const maternelleSieste = '/maternelle_sieste';
  static const maternelleCalendrier = '/maternelle_calendrier';

  static const maternelleJeux = '/jeux_scolaires'; // → alias JeuxScolairesPage
  static const maternelleMonde = '/monde_enfants'; // → alias MondeEnfantsPage

  // ── Primaire ────────────────────────────────────────────────────────────────
  static const primaireTableauBord = '/primaire_tableau_bord';
  static const primaireBulletin = '/primaire_bulletin';

  /// Réutilise les pages élève existantes
  static const primaireRevisions = '/etudiant_revisions'; // → alias
  static const primaireDevoirs = '/etudiant_devoirs'; // → alias
  static const primaireNotes = '/notes'; // → alias
  static const primaireDocuments = '/etudiant_documents'; // → alias
  static const primaireMondeEnfants = '/monde_enfants'; // → alias
  static const primaireJeux = '/jeux_scolaires'; // → alias

  // ── Collège ─────────────────────────────────────────────────────────────────
  static const collegeTableauBord = '/college_tableau_bord';
  static const collegeMatieres = '/college_matieres';
  static const collegeDevoirs = '/college_devoirs';
  static const collegeNotes = '/college_notes';
  static const collegeBulletin = '/college_bulletin';
  static const collegeBrevet = '/college_brevet';
  static const collegeOrientation = '/college_orientation';
  static const collegePresences = '/college_presences';

  static const collegeRevisions = '/etudiant_revisions'; // → alias
  static const collegeDocuments = '/etudiant_documents'; // → alias
  static const collegeJeux = '/jeux_scolaires'; // → alias

  // ── Lycée ───────────────────────────────────────────────────────────────────
  static const lyceeTableauBord = '/lycee_tableau_bord';
  static const lyceeMatieres = '/lycee_matieres';
  static const lyceeDevoirs = '/lycee_devoirs';
  static const lyceeNotes = '/lycee_notes';
  static const lyceeBulletin = '/lycee_bulletin';
  static const lyceeBacBlanc = '/lycee_bac_blanc';
  static const lyceeOrientation = '/lycee_orientation';
  static const lyceePresences = '/lycee_presences';
  static const lyceeControleConu = '/lycee_controle_continu';
  static const lyceeSpecialites = '/lycee_specialites';

  static const lyceeRevisions = '/etudiant_revisions'; // → alias
  static const lyceeDocuments = '/etudiant_documents'; // → alias
  static const lyceeJeux = '/jeux_scolaires'; // → alias

  // ── Université ──────────────────────────────────────────────────────────────
  static const universiteTableauBord = '/universite_tableau_bord';
  static const universiteUes = '/universite_ues';
  static const universiteEcts = '/universite_ects';
  static const universiteSemestres = '/universite_semestres';
  static const universiteParcours = '/universite_parcours';
  static const universiteOptions = '/universite_options';
  static const universiteExamens = '/universite_examens';
  static const universiteRattrapages = '/universite_rattrapages';
  static const universiteStage = '/universite_stage';
  static const universiteMemoire = '/universite_memoire';
  static const universiteSoutenances = '/universite_soutenances';

  static const universiteRevisions = '/etudiant_revisions'; // → alias

  // ── Professeur ──────────────────────────────────────────────────────────────
  /// Tableau de bord professeur (accès direct, hors hub EspaceProfesseurPage)
  static const professeurTableauBord = '/professeur_tableau_bord';
  static const professeurEmploi = '/professeur_emploi';
  static const professeurNotes = '/professeur_notes';
  static const professeurDevoirs = '/professeur_devoirs';
  static const professeurEleves = '/professeur_eleves';
  static const professeurPresences = '/professeur_presences';
  static const professeurDocuments = '/professeur_documents';
  static const professeurBibliotheque = '/professeur_bibliotheque';
  static const professeurCorrige = '/professeur_corrige';
  static const professeurMessagerie = '/professeur_messagerie';
  static const professeurRdv = '/professeur_rdv'; // → existant
  static const professeurBulletins = '/professeur_bulletins';
  static const professeurPrincipalBulletins = '/professeur_principal_bulletins';

  /// Évaluations qualitatives Maternelle (spécifique Maternelle)
  static const professeurEvaluationsQualitatives =
      '/professeur_evaluations_qualitatives';

  // ── Direction ───────────────────────────────────────────────────────────────
  /// Tableau de bord Direction (accès direct, hors hub EspaceDirectionPage)
  static const directionTableauBord = '/direction_tableau_bord';
  static const directionClasses = '/direction_classes';
  static const directionEleves = '/direction_eleves';
  static const directionStatistiques = '/direction_statistiques';
  static const directionBulletins = '/direction_bulletins';
  static const directionBulletinsConsulter = '/direction_bulletins_consulter';
  static const directionInviterEnseignant = '/direction_inviter_enseignant';

  /// Espace enseignant non rattaché à un établissement
  static const teacherLimited = '/teacher_limited';

  /// Initialisation du référentiel cycles/niveaux (SuperAdmin uniquement)
  static const directionSeedReferentiel = '/direction_seed_referentiel';
}
