import 'package:cloud_firestore/cloud_firestore.dart';

/// Rôles utilisateur — stockés dans Firestore users/{uid}.role
enum UserRole { eleve, professeur, admin }

extension UserRoleX on UserRole {
  String get label {
    switch (this) {
      case UserRole.eleve:
        return 'Élève';
      case UserRole.professeur:
        return 'Professeur';
      case UserRole.admin:
        return 'Admin';
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
    }
  }

  static UserRole fromString(String? s) {
    switch (s) {
      case 'professeur':
        return UserRole.professeur;
      case 'admin':
        return UserRole.admin;
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
  final String? niveau; // for eleves: '6ème', '5ème'…
  final String? matiere; // for professeurs
  final String? bio;
  final Timestamp? createdAt;
  final Timestamp? lastSeen;

  const UserModel({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.role,
    this.photoUrl,
    this.niveau,
    this.matiere,
    this.bio,
    this.createdAt,
    this.lastSeen,
  });

  /// Username from email (before @)
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
      niveau: d['niveau'] as String?,
      matiere: d['matiere'] as String?,
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
        if (niveau != null) 'niveau': niveau,
        if (matiere != null) 'matiere': matiere,
        if (bio != null) 'bio': bio,
      };

  UserModel copyWith({
    String? displayName,
    UserRole? role,
    String? photoUrl,
    String? niveau,
    String? matiere,
    String? bio,
  }) =>
      UserModel(
        uid: uid,
        email: email,
        displayName: displayName ?? this.displayName,
        role: role ?? this.role,
        photoUrl: photoUrl ?? this.photoUrl,
        niveau: niveau ?? this.niveau,
        matiere: matiere ?? this.matiere,
        bio: bio ?? this.bio,
        createdAt: createdAt,
        lastSeen: lastSeen,
      );
}
