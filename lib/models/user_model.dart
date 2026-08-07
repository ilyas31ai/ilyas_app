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
  editeur,
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
      case UserRole.editeur:
        return 'Éditeur';
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
      case UserRole.editeur:
        return 'editeur';
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
      case 'editeur':
        return UserRole.editeur;
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

  /// UID du professeur de la classe de l'élève — écrit par la Direction à
  /// l'affectation de classe ([direction_eleves_page.dart]). Utilisé pour
  /// restreindre la messagerie élève → professeur à ses vrais enseignants.
  final String? profId;

  // Fiche contact — renseignée par la Direction (gestion élèves/professeurs).
  // Additif : reste null pour tous les comptes existants (aucune régression
  // sur displayName, qui demeure la source d'affichage historique).
  final String? nom;
  final String? prenom;
  final String? adresse;
  final String? telephone;
  final String? ville;

  // Fiche élève étendue — renseignée manuellement ou via import PDF (OCR).
  // Additif, voir [EleveAccountService.creerEleve].
  final String? dateNaissance; // format 'AAAA-MM-JJ'
  final String? sexe;          // 'M' | 'F'
  final String? matricule;
  final String? pereNom;
  final String? pereTelephone;
  final String? pereEmail;
  final String? mereNom;
  final String? mereTelephone;
  final String? mereEmail;
  final String? contactUrgenceNom;
  final String? contactUrgenceTelephone;
  final String? autresInfos;

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
    this.profId,
    this.nom,
    this.prenom,
    this.adresse,
    this.telephone,
    this.ville,
    this.dateNaissance,
    this.sexe,
    this.matricule,
    this.pereNom,
    this.pereTelephone,
    this.pereEmail,
    this.mereNom,
    this.mereTelephone,
    this.mereEmail,
    this.contactUrgenceNom,
    this.contactUrgenceTelephone,
    this.autresInfos,
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
      profId: d['profId'] as String?,
      nom: d['nom'] as String?,
      prenom: d['prenom'] as String?,
      adresse: d['adresse'] as String?,
      telephone: d['telephone'] as String?,
      ville: d['ville'] as String?,
      dateNaissance: d['dateNaissance'] as String?,
      sexe: d['sexe'] as String?,
      matricule: d['matricule'] as String?,
      pereNom: d['pereNom'] as String?,
      pereTelephone: d['pereTelephone'] as String?,
      pereEmail: d['pereEmail'] as String?,
      mereNom: d['mereNom'] as String?,
      mereTelephone: d['mereTelephone'] as String?,
      mereEmail: d['mereEmail'] as String?,
      contactUrgenceNom: d['contactUrgenceNom'] as String?,
      contactUrgenceTelephone: d['contactUrgenceTelephone'] as String?,
      autresInfos: d['autresInfos'] as String?,
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
        if (profId != null) 'profId': profId,
        if (nom != null) 'nom': nom,
        if (prenom != null) 'prenom': prenom,
        if (adresse != null) 'adresse': adresse,
        if (telephone != null) 'telephone': telephone,
        if (ville != null) 'ville': ville,
        if (dateNaissance != null) 'dateNaissance': dateNaissance,
        if (sexe != null) 'sexe': sexe,
        if (matricule != null) 'matricule': matricule,
        if (pereNom != null) 'pereNom': pereNom,
        if (pereTelephone != null) 'pereTelephone': pereTelephone,
        if (pereEmail != null) 'pereEmail': pereEmail,
        if (mereNom != null) 'mereNom': mereNom,
        if (mereTelephone != null) 'mereTelephone': mereTelephone,
        if (mereEmail != null) 'mereEmail': mereEmail,
        if (contactUrgenceNom != null) 'contactUrgenceNom': contactUrgenceNom,
        if (contactUrgenceTelephone != null)
          'contactUrgenceTelephone': contactUrgenceTelephone,
        if (autresInfos != null) 'autresInfos': autresInfos,
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
    String? profId,
    String? nom,
    String? prenom,
    String? adresse,
    String? telephone,
    String? ville,
    String? dateNaissance,
    String? sexe,
    String? matricule,
    String? pereNom,
    String? pereTelephone,
    String? pereEmail,
    String? mereNom,
    String? mereTelephone,
    String? mereEmail,
    String? contactUrgenceNom,
    String? contactUrgenceTelephone,
    String? autresInfos,
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
        profId: profId ?? this.profId,
        nom: nom ?? this.nom,
        prenom: prenom ?? this.prenom,
        adresse: adresse ?? this.adresse,
        telephone: telephone ?? this.telephone,
        ville: ville ?? this.ville,
        dateNaissance: dateNaissance ?? this.dateNaissance,
        sexe: sexe ?? this.sexe,
        matricule: matricule ?? this.matricule,
        pereNom: pereNom ?? this.pereNom,
        pereTelephone: pereTelephone ?? this.pereTelephone,
        pereEmail: pereEmail ?? this.pereEmail,
        mereNom: mereNom ?? this.mereNom,
        mereTelephone: mereTelephone ?? this.mereTelephone,
        mereEmail: mereEmail ?? this.mereEmail,
        contactUrgenceNom: contactUrgenceNom ?? this.contactUrgenceNom,
        contactUrgenceTelephone:
            contactUrgenceTelephone ?? this.contactUrgenceTelephone,
        autresInfos: autresInfos ?? this.autresInfos,
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
