import 'package:cloud_firestore/cloud_firestore.dart';

import 'school_model.dart';

/// Statut du dossier d'inscription dans le pipeline de la Direction.
enum InscriptionStatut { brouillon, enAttente, validee, refusee }

extension InscriptionStatutX on InscriptionStatut {
  String get label {
    switch (this) {
      case InscriptionStatut.brouillon:
        return 'À vérifier';
      case InscriptionStatut.enAttente:
        return 'En attente';
      case InscriptionStatut.validee:
        return 'Validée';
      case InscriptionStatut.refusee:
        return 'Refusée';
    }
  }

  String get value {
    switch (this) {
      case InscriptionStatut.brouillon:
        return 'brouillon';
      case InscriptionStatut.enAttente:
        return 'en_attente';
      case InscriptionStatut.validee:
        return 'validee';
      case InscriptionStatut.refusee:
        return 'refusee';
    }
  }

  static InscriptionStatut fromString(String? s) {
    switch (s) {
      case 'en_attente':
        return InscriptionStatut.enAttente;
      case 'validee':
        return InscriptionStatut.validee;
      case 'refusee':
        return InscriptionStatut.refusee;
      default:
        return InscriptionStatut.brouillon;
    }
  }
}

/// Informations de l'élève — extraites du PDF puis vérifiées manuellement.
class EleveInfo {
  final String nom;
  final String prenom;
  final DateTime? dateNaissance;
  final String sexe;
  final String adresse;
  final String classeDemandee;
  /// Email du compte élève pour lier l'inscription à Firebase Auth.
  final String emailEleve;

  const EleveInfo({
    this.nom = '',
    this.prenom = '',
    this.dateNaissance,
    this.sexe = '',
    this.adresse = '',
    this.classeDemandee = '',
    this.emailEleve = '',
  });

  factory EleveInfo.fromMap(Map<String, dynamic>? m) {
    final d = m ?? {};
    return EleveInfo(
      nom: d['nom'] as String? ?? '',
      prenom: d['prenom'] as String? ?? '',
      dateNaissance: (d['dateNaissance'] as Timestamp?)?.toDate(),
      sexe: d['sexe'] as String? ?? '',
      adresse: d['adresse'] as String? ?? '',
      classeDemandee: d['classeDemandee'] as String? ?? '',
      emailEleve: d['emailEleve'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
        'nom': nom,
        'prenom': prenom,
        if (dateNaissance != null)
          'dateNaissance': Timestamp.fromDate(dateNaissance!),
        'sexe': sexe,
        'adresse': adresse,
        'classeDemandee': classeDemandee,
        if (emailEleve.isNotEmpty) 'emailEleve': emailEleve,
      };

  EleveInfo copyWith({
    String? nom,
    String? prenom,
    DateTime? dateNaissance,
    String? sexe,
    String? adresse,
    String? classeDemandee,
    String? emailEleve,
  }) =>
      EleveInfo(
        nom: nom ?? this.nom,
        prenom: prenom ?? this.prenom,
        dateNaissance: dateNaissance ?? this.dateNaissance,
        sexe: sexe ?? this.sexe,
        adresse: adresse ?? this.adresse,
        classeDemandee: classeDemandee ?? this.classeDemandee,
        emailEleve: emailEleve ?? this.emailEleve,
      );
}

/// Coordonnées d'un parent.
class ParentInfo {
  final String nomComplet;
  final String telephone;
  final String email;

  const ParentInfo({
    this.nomComplet = '',
    this.telephone = '',
    this.email = '',
  });

  bool get isEmpty =>
      nomComplet.trim().isEmpty && telephone.trim().isEmpty && email.trim().isEmpty;

  factory ParentInfo.fromMap(Map<String, dynamic>? m) {
    if (m == null) return const ParentInfo();
    return ParentInfo(
      nomComplet: m['nomComplet'] as String? ?? '',
      telephone: m['telephone'] as String? ?? '',
      email: m['email'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
        'nomComplet': nomComplet,
        'telephone': telephone,
        'email': email,
      };

  ParentInfo copyWith({String? nomComplet, String? telephone, String? email}) =>
      ParentInfo(
        nomComplet: nomComplet ?? this.nomComplet,
        telephone: telephone ?? this.telephone,
        email: email ?? this.email,
      );
}

/// Contact à prévenir en cas d'urgence.
class ContactUrgence {
  final String nom;
  final String telephone;
  final String lien;

  const ContactUrgence({this.nom = '', this.telephone = '', this.lien = ''});

  factory ContactUrgence.fromMap(Map<String, dynamic>? m) {
    final d = m ?? {};
    return ContactUrgence(
      nom: d['nom'] as String? ?? '',
      telephone: d['telephone'] as String? ?? '',
      lien: d['lien'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
        'nom': nom,
        'telephone': telephone,
        'lien': lien,
      };

  ContactUrgence copyWith({String? nom, String? telephone, String? lien}) =>
      ContactUrgence(
        nom: nom ?? this.nom,
        telephone: telephone ?? this.telephone,
        lien: lien ?? this.lien,
      );
}

/// Dossier d'inscription scolaire — du PDF importé au statut final.
class Inscription {
  final String id;
  final String schoolId;
  final String pdfUrl;
  final String pdfName;
  final EleveInfo eleve;
  final ParentInfo parent1;
  final ParentInfo? parent2;
  final ContactUrgence urgence;
  final String matricule;
  final InscriptionStatut statut;
  final String commentaire;
  final DateTime dateImport;
  final DateTime? dateInscription;
  final String eleveId;

  const Inscription({
    required this.id,
    this.schoolId = kDefaultSchoolId,
    required this.pdfUrl,
    required this.pdfName,
    required this.eleve,
    required this.parent1,
    this.parent2,
    required this.urgence,
    this.matricule = '',
    this.statut = InscriptionStatut.brouillon,
    this.commentaire = '',
    required this.dateImport,
    this.dateInscription,
    this.eleveId = '',
  });

  String get nomCompletEleve => '${eleve.prenom} ${eleve.nom}'.trim();

  factory Inscription.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    final p2 = d['parent2'] as Map<String, dynamic>?;
    return Inscription(
      id: doc.id,
      schoolId: d['schoolId'] as String? ?? kDefaultSchoolId,
      pdfUrl: d['pdfUrl'] as String? ?? '',
      pdfName: d['pdfName'] as String? ?? '',
      eleve: EleveInfo.fromMap(d['eleve'] as Map<String, dynamic>?),
      parent1: ParentInfo.fromMap(d['parent1'] as Map<String, dynamic>?),
      parent2: p2 != null ? ParentInfo.fromMap(p2) : null,
      urgence: ContactUrgence.fromMap(d['urgence'] as Map<String, dynamic>?),
      matricule: d['matricule'] as String? ?? '',
      statut: InscriptionStatutX.fromString(d['statut'] as String?),
      commentaire: d['commentaire'] as String? ?? '',
      dateImport:
          (d['dateImport'] as Timestamp?)?.toDate() ?? DateTime.now(),
      dateInscription: (d['dateInscription'] as Timestamp?)?.toDate(),
      eleveId: d['eleveId'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
        'schoolId': schoolId,
        'pdfUrl': pdfUrl,
        'pdfName': pdfName,
        'eleve': eleve.toMap(),
        'parent1': parent1.toMap(),
        if (parent2 != null && !parent2!.isEmpty) 'parent2': parent2!.toMap(),
        'urgence': urgence.toMap(),
        'matricule': matricule,
        'statut': statut.value,
        'commentaire': commentaire,
        'dateImport': Timestamp.fromDate(dateImport),
        if (dateInscription != null)
          'dateInscription': Timestamp.fromDate(dateInscription!),
        'eleveId': eleveId,
      };

  Inscription copyWith({
    EleveInfo? eleve,
    ParentInfo? parent1,
    ParentInfo? parent2,
    ContactUrgence? urgence,
    String? matricule,
    InscriptionStatut? statut,
    String? commentaire,
    DateTime? dateInscription,
    String? eleveId,
  }) =>
      Inscription(
        id: id,
        schoolId: schoolId,
        pdfUrl: pdfUrl,
        pdfName: pdfName,
        eleve: eleve ?? this.eleve,
        parent1: parent1 ?? this.parent1,
        parent2: parent2 ?? this.parent2,
        urgence: urgence ?? this.urgence,
        matricule: matricule ?? this.matricule,
        statut: statut ?? this.statut,
        commentaire: commentaire ?? this.commentaire,
        dateImport: dateImport,
        dateInscription: dateInscription ?? this.dateInscription,
        eleveId: eleveId ?? this.eleveId,
      );
}
