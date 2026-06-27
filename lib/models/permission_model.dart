import 'user_model.dart';

/// Matrice de permissions par rôle.
///
/// Règle de lecture : [PermissionService.can] est la seule API publique.
/// Toute condition `role == UserRole.X` dans l'UI doit être remplacée
/// progressivement par un appel à [PermissionService.can].
enum AppPermission {
  // ── Direction ──────────────────────────────────────────────────────────────
  gererEleves,
  gererClasses,
  gererProfesseurs,
  validerInscriptions,
  voirStatistiques,
  gererEtablissement,
  exporterDonnees,

  // ── SuperAdmin uniquement ──────────────────────────────────────────────────
  gererEtablissements, // multi-établissements
  initialiserReferentiel, // seed cycles/niveaux/schools

  // ── Professeur ─────────────────────────────────────────────────────────────
  saisirNotes,
  saisirEvaluationsQualitatives, // Maternelle
  gererDevoirs,
  prendrePresences,
  voirElevesClasse,
  partagerDocuments,
  envoyerAnnonces,
  gererEmploiDuTemps,

  // ── Élève ──────────────────────────────────────────────────────────────────
  voirMesNotes,
  voirMesDevoirs,
  rendreDevoir,
  accederRevisions,
  accederJeux,
  accederMondeEnfants, // Maternelle / Primaire uniquement

  // ── Parent ─────────────────────────────────────────────────────────────────
  voirNotesEnfant,
  voirDevoirsEnfant,
  voirPresencesEnfant,
  contacterProfesseur,
}

/// Permissions accordées à chaque rôle.
const _matrix = <UserRole, Set<AppPermission>>{
  UserRole.superAdmin: {
    // Tout
    AppPermission.gererEleves,
    AppPermission.gererClasses,
    AppPermission.gererProfesseurs,
    AppPermission.validerInscriptions,
    AppPermission.voirStatistiques,
    AppPermission.gererEtablissement,
    AppPermission.exporterDonnees,
    AppPermission.gererEtablissements,
    AppPermission.initialiserReferentiel,
    AppPermission.saisirNotes,
    AppPermission.saisirEvaluationsQualitatives,
    AppPermission.gererDevoirs,
    AppPermission.prendrePresences,
    AppPermission.voirElevesClasse,
    AppPermission.partagerDocuments,
    AppPermission.envoyerAnnonces,
    AppPermission.gererEmploiDuTemps,
    AppPermission.voirMesNotes,
    AppPermission.voirMesDevoirs,
    AppPermission.rendreDevoir,
    AppPermission.accederRevisions,
    AppPermission.accederJeux,
    AppPermission.accederMondeEnfants,
    AppPermission.voirNotesEnfant,
    AppPermission.voirDevoirsEnfant,
    AppPermission.voirPresencesEnfant,
    AppPermission.contacterProfesseur,
  },
  UserRole.adminEtablissement: {
    AppPermission.gererEleves,
    AppPermission.gererClasses,
    AppPermission.gererProfesseurs,
    AppPermission.validerInscriptions,
    AppPermission.voirStatistiques,
    AppPermission.gererEtablissement,
    AppPermission.exporterDonnees,
  },
  UserRole.admin: {
    AppPermission.gererEleves,
    AppPermission.gererClasses,
    AppPermission.gererProfesseurs,
    AppPermission.validerInscriptions,
    AppPermission.voirStatistiques,
    AppPermission.gererEtablissement,
    AppPermission.exporterDonnees,
    // Peut également superviser
    AppPermission.saisirNotes,
    AppPermission.partagerDocuments,
    AppPermission.envoyerAnnonces,
  },
  UserRole.direction: {
    AppPermission.gererEleves,
    AppPermission.gererClasses,
    AppPermission.gererProfesseurs,
    AppPermission.validerInscriptions,
    AppPermission.voirStatistiques,
    AppPermission.gererEtablissement,
    AppPermission.exporterDonnees,
    AppPermission.saisirNotes,
    AppPermission.partagerDocuments,
    AppPermission.envoyerAnnonces,
  },
  UserRole.professeur: {
    AppPermission.saisirNotes,
    AppPermission.saisirEvaluationsQualitatives,
    AppPermission.gererDevoirs,
    AppPermission.prendrePresences,
    AppPermission.voirElevesClasse,
    AppPermission.partagerDocuments,
    AppPermission.envoyerAnnonces,
    AppPermission.gererEmploiDuTemps,
  },
  UserRole.eleve: {
    AppPermission.voirMesNotes,
    AppPermission.voirMesDevoirs,
    AppPermission.rendreDevoir,
    AppPermission.accederRevisions,
    AppPermission.accederJeux,
    AppPermission.accederMondeEnfants,
  },
  UserRole.parent: {
    AppPermission.voirNotesEnfant,
    AppPermission.voirDevoirsEnfant,
    AppPermission.voirPresencesEnfant,
    AppPermission.contacterProfesseur,
  },
};

class PermissionService {
  /// Vérifie si le rôle possède la permission demandée.
  static bool can(UserRole role, AppPermission permission) =>
      _matrix[role]?.contains(permission) ?? false;

  /// Vérifie si le rôle est un rôle Direction (admin, direction, adminEtablissement, superAdmin).
  static bool isDirection(UserRole role) => const {
        UserRole.admin,
        UserRole.direction,
        UserRole.adminEtablissement,
        UserRole.superAdmin,
      }.contains(role);

  /// Vérifie si le rôle peut accéder à l'espace professeur.
  static bool canAccessProfesseur(UserRole role) =>
      role == UserRole.professeur || isDirection(role);

  /// Vérifie si le rôle peut accéder à l'espace parent.
  static bool canAccessParent(UserRole role) =>
      role == UserRole.parent || isDirection(role);

  /// Toutes les permissions d'un rôle.
  static Set<AppPermission> permissionsFor(UserRole role) =>
      _matrix[role] ?? const {};
}
