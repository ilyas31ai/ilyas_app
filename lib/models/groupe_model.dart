import 'package:cloud_firestore/cloud_firestore.dart';

enum GroupeRole { admin, membre }
enum GroupeType { public, prive, classe }

extension GroupeRoleX on GroupeRole {
  String get label => switch (this) {
        GroupeRole.admin  => 'Admin',
        GroupeRole.membre => 'Membre',
      };

  static GroupeRole fromString(String? s) => switch (s) {
        'admin'  => GroupeRole.admin,
        _        => GroupeRole.membre,
      };
}

extension GroupeTypeX on GroupeType {
  String get value => switch (this) {
        GroupeType.public  => 'public',
        GroupeType.prive   => 'prive',
        GroupeType.classe  => 'classe',
      };

  String get label => switch (this) {
        GroupeType.public  => 'Public',
        GroupeType.prive   => 'Privé',
        GroupeType.classe  => 'Classe',
      };

  static GroupeType fromString(String? s) => switch (s) {
        'prive'  => GroupeType.prive,
        'classe' => GroupeType.classe,
        _        => GroupeType.public,
      };
}

class GroupeModel {
  final String id;
  final String nom;
  final String description;
  final String matiere;
  final String niveau;
  final String creatorUid;
  final String creatorEmail;
  final GroupeType type;
  final String? classeId;
  final String? classeNom;
  final int memberCount;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const GroupeModel({
    required this.id,
    required this.nom,
    this.description = '',
    this.matiere = '',
    this.niveau = '',
    required this.creatorUid,
    required this.creatorEmail,
    this.type = GroupeType.public,
    this.classeId,
    this.classeNom,
    this.memberCount = 1,
    required this.createdAt,
    this.updatedAt,
  });

  factory GroupeModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return GroupeModel(
      id:           doc.id,
      nom:          d['nom'] as String? ?? '',
      description:  d['description'] as String? ?? '',
      matiere:      d['matiere'] as String? ?? '',
      niveau:       d['niveau'] as String? ?? '',
      creatorUid:   d['creatorUid'] as String? ?? '',
      creatorEmail: d['creatorEmail'] as String? ?? '',
      type:         GroupeTypeX.fromString(d['type'] as String?),
      classeId:     d['classeId'] as String?,
      classeNom:    d['classeNom'] as String?,
      memberCount:  d['memberCount'] as int? ?? 1,
      createdAt:    (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt:    (d['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
        'nom':          nom,
        'description':  description,
        'matiere':      matiere,
        'niveau':       niveau,
        'creatorUid':   creatorUid,
        'creatorEmail': creatorEmail,
        'type':         type.value,
        if (classeId != null) 'classeId': classeId,
        if (classeNom != null) 'classeNom': classeNom,
        'memberCount':  memberCount,
        'createdAt':    FieldValue.serverTimestamp(),
        'updatedAt':    FieldValue.serverTimestamp(),
      };
}

class GroupeMembre {
  final String uid;
  final String email;
  final String nom;
  final GroupeRole role;
  final DateTime joinedAt;

  const GroupeMembre({
    required this.uid,
    required this.email,
    required this.nom,
    required this.role,
    required this.joinedAt,
  });

  factory GroupeMembre.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return GroupeMembre(
      uid:      doc.id,
      email:    d['email'] as String? ?? '',
      nom:      d['nom'] as String? ?? '',
      role:     GroupeRoleX.fromString(d['role'] as String?),
      joinedAt: (d['joinedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'email':    email,
        'nom':      nom,
        'role':     role == GroupeRole.admin ? 'admin' : 'membre',
        'joinedAt': FieldValue.serverTimestamp(),
      };
}

class GroupeDocument {
  final String id;
  final String titre;
  final String type;
  final String contenu;
  final String? fileUrl;
  final String? fileName;
  final String auteurUid;
  final String auteurEmail;
  final String auteurNom;
  final DateTime createdAt;

  const GroupeDocument({
    required this.id,
    required this.titre,
    this.type = 'fiche',
    this.contenu = '',
    this.fileUrl,
    this.fileName,
    required this.auteurUid,
    required this.auteurEmail,
    required this.auteurNom,
    required this.createdAt,
  });

  factory GroupeDocument.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return GroupeDocument(
      id:          doc.id,
      titre:       d['titre'] as String? ?? '',
      type:        d['type'] as String? ?? 'fiche',
      contenu:     d['contenu'] as String? ?? '',
      fileUrl:     d['fileUrl'] as String?,
      fileName:    d['fileName'] as String?,
      auteurUid:   d['auteurUid'] as String? ?? '',
      auteurEmail: d['auteurEmail'] as String? ?? '',
      auteurNom:   d['auteurNom'] as String? ?? '',
      createdAt:   (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
