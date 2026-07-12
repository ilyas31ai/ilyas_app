import 'package:cloud_firestore/cloud_firestore.dart';

import 'school_model.dart';

/// Rôles stockés dans Firestore users/{uid}.role
///
/// `direction`, `adminEtablissement` et `superAdmin` sont des valeurs
/// nouvelles (Phase 2, architecture multi-établissements) : aucun compte
/// existant ne les porte encore. `admin` reste le rôle actif pour tous les
/// comptes Direction actuels — son remplacement progressif par `direction`
/// est une migration distincte, non effectuée par cet ajout (additif, zéro
/// régression : tout code existant testant `UserRole.admin` continue de
/// fonctionner à l'identique).
enum UserRole {
  eleve,
  professeur,
  admin,
  parent,
  direction,
  adminEtablissement,
  superAdmin,
}

extension UserRoleX on UserRole {
  String get label {
    switch (this) {
      case UserRole.eleve:
        return 'Élève';
      case UserRole.professeur:
        return 'Professeur';
      case UserRole.admin:
        return 'Direction';
      case UserRole.parent:
        return 'Parent';
      case UserRole.direction:
        return 'Direction';
      case UserRole.adminEtablissement:
        return 'Administrateur Établissement';
      case UserRole.superAdmin:
        return 'Super Administrateur';
    }
  }

  String get value {
    switch (this) {
      case UserRole.eleve:
        return 'eleve';
      case UserRole.professeur:
        return 'professeur';
      case UserRole.admin:
        return 'admin';
      case UserRole.parent:
        return 'parent';
      case UserRole.direction:
        return 'direction';
      case UserRole.adminEtablissement:
        return 'adminEtablissement';
      case UserRole.superAdmin:
        return 'superAdmin';
    }
  }

  static UserRole fromString(String? s) {
    switch (s) {
      case 'professeur':
        return UserRole.professeur;
      case 'admin':
        return UserRole.admin;
      case 'parent':
        return UserRole.parent;
      case 'direction':
        return UserRole.direction;
      case 'adminEtablissement':
        return UserRole.adminEtablissement;
      case 'superAdmin':
        return UserRole.superAdmin;
      default:
        return UserRole.eleve;
    }
  }
}

class UserModel {
  final String uid;
  final String email;
  final String displayName;
  final UserRole role;
  final String? photoUrl;

  /// Établissement d'appartenance (Phase 2, multi-établissements).
  /// Toujours renseigné en mémoire : vaut [kDefaultSchoolId] si absent du
  /// document Firestore (cas de tous les comptes existants avant backfill).
  final String schoolId;

  // Élève
  final String? categorie;  // 'Maternelle', 'Primaire', 'Collège', 'Lycée', 'Université'
  final String? niveau;     // 'PS', 'CP', '6e', 'Seconde', 'L1'…
  final String? classeId;   // ID du document dans /classes
  final String? classeNom;  // nom de la classe, ex. '6A'

  // Professeur
  final String? matiere;

  // Fiche contact — renseignée par la Direction (gestion élèves/professeurs).
  // Additif : reste null pour tous les comptes existants (aucune régression
  // sur displayName, qui demeure la source d'affichage historique).
  final String? nom;
  final String? prenom;
  final String? adresse;
  final String? telephone;

  // Parent
  /// UIDs des élèves enfants (utilisé dans les règles Firestore)
  final List<String> enfantIds;
  /// classeIds des enfants (pour filtrer devoirs/docs par classe)
  final List<String> enfantClasseIds;

  // Validation
  final String statut; // 'actif' | 'en_attente' | 'refuse'

  // Enseignant — système d'invitation par code
  /// 'limited' : compte actif mais non rattaché à un établissement.
  /// 'active'  : code d'invitation utilisé, pleinement fonctionnel.
  /// null      : ancien compte actif (rétrocompatibilité → traité comme 'active').
  final String? teacherStatus;
  final String? linkedSchoolNom;

  // Commun
  final String? bio;
  final Timestamp? createdAt;
  final Timestamp? lastSeen;

  const UserModel({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.role,
    this.photoUrl,
    this.schoolId = kDefaultSchoolId,
    this.categorie,
    this.niveau,
    this.classeId,
    this.classeNom,
    this.matiere,
    this.nom,
    this.prenom,
    this.adresse,
    this.telephone,
    this.enfantIds = const [],
    this.enfantClasseIds = const [],
    this.statut = 'actif',
    this.teacherStatus,
    this.linkedSchoolNom,
    this.bio,
    this.createdAt,
    this.lastSeen,
  });

  String get username =>
      email.contains('@') ? email.split('@').first : email;

  factory UserModel.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return UserModel(
      uid: d['uid'] as String? ?? doc.id,
      email: d['email'] as String? ?? '',
      displayName: d['displayName'] as String? ?? '',
      role: UserRoleX.fromString(d['role'] as String?),
      photoUrl: d['photoUrl'] as String?,
      schoolId: d['schoolId'] as String? ?? kDefaultSchoolId,
      categorie: d['categorie'] as String?,
      niveau: d['niveau'] as String?,
      classeId: d['classeId'] as String?,
      classeNom: d['classeNom'] as String?,
      matiere: d['matiere'] as String?,
      nom: d['nom'] as String?,
      prenom: d['prenom'] as String?,
      adresse: d['adresse'] as String?,
      telephone: d['telephone'] as String?,
      enfantIds: List<String>.from(d['enfantIds'] as List? ?? []),
      enfantClasseIds: List<String>.from(d['enfantClasseIds'] as List? ?? []),
      statut: (d['statut'] as String?) ?? 'actif',
      teacherStatus: d['teacherStatus'] as String?,
      linkedSchoolNom: d['linkedSchoolNom'] as String?,
      bio: d['bio'] as String?,
      createdAt: d['createdAt'] as Timestamp?,
      lastSeen: d['lastSeen'] as Timestamp?,
    );
  }

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'email': email,
        'displayName': displayName,
        'role': role.value,
        'schoolId': schoolId,
        if (photoUrl != null) 'photoUrl': photoUrl,
        if (categorie != null) 'categorie': categorie,
        if (niveau != null) 'niveau': niveau,
        if (classeId != null) 'classeId': classeId,
        if (classeNom != null) 'classeNom': classeNom,
        if (matiere != null) 'matiere': matiere,
        if (nom != null) 'nom': nom,
        if (prenom != null) 'prenom': prenom,
        if (adresse != null) 'adresse': adresse,
        if (telephone != null) 'telephone': telephone,
        if (enfantIds.isNotEmpty) 'enfantIds': enfantIds,
        if (enfantClasseIds.isNotEmpty) 'enfantClasseIds': enfantClasseIds,
        'statut': statut,
        if (teacherStatus != null) 'teacherStatus': teacherStatus,
        if (linkedSchoolNom != null) 'linkedSchoolNom': linkedSchoolNom,
        if (bio != null) 'bio': bio,
      };

  UserModel copyWith({
    String? displayName,
    UserRole? role,
    String? photoUrl,
    String? schoolId,
    String? categorie,
    String? niveau,
    String? classeId,
    String? classeNom,
    String? matiere,
    String? nom,
    String? prenom,
    String? adresse,
    String? telephone,
    List<String>? enfantIds,
    List<String>? enfantClasseIds,
    String? statut,
    String? teacherStatus,
    String? linkedSchoolNom,
    String? bio,
  }) =>
      UserModel(
        uid: uid,
        email: email,
        displayName: displayName ?? this.displayName,
        role: role ?? this.role,
        photoUrl: photoUrl ?? this.photoUrl,
        schoolId: schoolId ?? this.schoolId,
        categorie: categorie ?? this.categorie,
        niveau: niveau ?? this.niveau,
        classeId: classeId ?? this.classeId,
        classeNom: classeNom ?? this.classeNom,
        matiere: matiere ?? this.matiere,
        nom: nom ?? this.nom,
        prenom: prenom ?? this.prenom,
        adresse: adresse ?? this.adresse,
        telephone: telephone ?? this.telephone,
        enfantIds: enfantIds ?? this.enfantIds,
        enfantClasseIds: enfantClasseIds ?? this.enfantClasseIds,
        statut: statut ?? this.statut,
        teacherStatus: teacherStatus ?? this.teacherStatus,
        linkedSchoolNom: linkedSchoolNom ?? this.linkedSchoolNom,
        bio: bio ?? this.bio,
        createdAt: createdAt,
        lastSeen: lastSeen,
      );
}
