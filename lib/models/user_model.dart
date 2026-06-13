import 'package:cloud_firestore/cloud_firestore.dart';

/// Rôles stockés dans Firestore users/{uid}.role
enum UserRole { eleve, professeur, admin, parent }

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

  // Élève
  final String? categorie;  // 'Maternelle', 'Primaire', 'Collège', 'Lycée', 'Université'
  final String? niveau;     // 'PS', 'CP', '6e', 'Seconde', 'L1'…
  final String? classeId;   // ID du document dans /classes
  final String? classeNom;  // nom de la classe, ex. '6A'

  // Professeur
  final String? matiere;

  // Parent
  /// UIDs des élèves enfants (utilisé dans les règles Firestore)
  final List<String> enfantIds;
  /// classeIds des enfants (pour filtrer devoirs/docs par classe)
  final List<String> enfantClasseIds;

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
    this.categorie,
    this.niveau,
    this.classeId,
    this.classeNom,
    this.matiere,
    this.enfantIds = const [],
    this.enfantClasseIds = const [],
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
      categorie: d['categorie'] as String?,
      niveau: d['niveau'] as String?,
      classeId: d['classeId'] as String?,
      classeNom: d['classeNom'] as String?,
      matiere: d['matiere'] as String?,
      enfantIds: List<String>.from(d['enfantIds'] as List? ?? []),
      enfantClasseIds: List<String>.from(d['enfantClasseIds'] as List? ?? []),
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
        if (photoUrl != null) 'photoUrl': photoUrl,
        if (categorie != null) 'categorie': categorie,
        if (niveau != null) 'niveau': niveau,
        if (classeId != null) 'classeId': classeId,
        if (classeNom != null) 'classeNom': classeNom,
        if (matiere != null) 'matiere': matiere,
        if (enfantIds.isNotEmpty) 'enfantIds': enfantIds,
        if (enfantClasseIds.isNotEmpty) 'enfantClasseIds': enfantClasseIds,
        if (bio != null) 'bio': bio,
      };

  UserModel copyWith({
    String? displayName,
    UserRole? role,
    String? photoUrl,
    String? categorie,
    String? niveau,
    String? classeId,
    String? classeNom,
    String? matiere,
    List<String>? enfantIds,
    List<String>? enfantClasseIds,
    String? bio,
  }) =>
      UserModel(
        uid: uid,
        email: email,
        displayName: displayName ?? this.displayName,
        role: role ?? this.role,
        photoUrl: photoUrl ?? this.photoUrl,
        categorie: categorie ?? this.categorie,
        niveau: niveau ?? this.niveau,
        classeId: classeId ?? this.classeId,
        classeNom: classeNom ?? this.classeNom,
        matiere: matiere ?? this.matiere,
        enfantIds: enfantIds ?? this.enfantIds,
        enfantClasseIds: enfantClasseIds ?? this.enfantClasseIds,
        bio: bio ?? this.bio,
        createdAt: createdAt,
        lastSeen: lastSeen,
      );
}
