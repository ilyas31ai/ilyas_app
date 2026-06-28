import 'package:cloud_firestore/cloud_firestore.dart';

import 'user_model.dart';

/// Firestore collection: enseignants_profils/{uid}
///
/// Profil étendu d'un enseignant, séparé de [UserModel] pour éviter de
/// surcharger la collection `users` et permettre des champs métier avancés.
class EnseignantProfil {
  final String uid;
  final String nom;
  final String prenom;
  final String? sexe; // 'M' | 'F' | 'Autre'
  final String? dateNaissance; // ISO date string 'YYYY-MM-DD'
  final String? adresse;
  final String? telephone;
  final String? email;
  final String? nationalite;
  final String? matricule;
  final String? photoUrl;

  // Infos professionnelles
  final List<String> matieres;
  final List<String> cycles; // ['Collège', 'Lycée', ...]
  final List<String> niveaux;
  final List<String> classes;
  final String? dateEmbauche; // ISO date
  final String? typeContrat; // 'CDI' | 'CDD' | 'Vacataire' | 'Titulaire'
  final bool tempsPlein;
  final String statut; // 'Actif' | 'En congé' | 'Absent'

  // Stats (computed/cached)
  final int heuresTotal;
  final int remplacementsTotal;
  final Timestamp? updatedAt;

  const EnseignantProfil({
    required this.uid,
    required this.nom,
    required this.prenom,
    this.sexe,
    this.dateNaissance,
    this.adresse,
    this.telephone,
    this.email,
    this.nationalite,
    this.matricule,
    this.photoUrl,
    this.matieres = const [],
    this.cycles = const [],
    this.niveaux = const [],
    this.classes = const [],
    this.dateEmbauche,
    this.typeContrat,
    this.tempsPlein = true,
    this.statut = 'Actif',
    this.heuresTotal = 0,
    this.remplacementsTotal = 0,
    this.updatedAt,
  });

  // ─── Factories ────────────────────────────────────────────────────────────

  factory EnseignantProfil.fromFirestore(DocumentSnapshot doc) {
    final m = doc.data() as Map<String, dynamic>? ?? {};
    return EnseignantProfil.fromMap(doc.id, m);
  }

  factory EnseignantProfil.fromMap(String uid, Map<String, dynamic> m) {
    return EnseignantProfil(
      uid: uid,
      nom: (m['nom'] as String?) ?? '',
      prenom: (m['prenom'] as String?) ?? '',
      sexe: m['sexe'] as String?,
      dateNaissance: m['dateNaissance'] as String?,
      adresse: m['adresse'] as String?,
      telephone: m['telephone'] as String?,
      email: m['email'] as String?,
      nationalite: m['nationalite'] as String?,
      matricule: m['matricule'] as String?,
      photoUrl: m['photoUrl'] as String?,
      matieres: List<String>.from((m['matieres'] as List<dynamic>?) ?? []),
      cycles: List<String>.from((m['cycles'] as List<dynamic>?) ?? []),
      niveaux: List<String>.from((m['niveaux'] as List<dynamic>?) ?? []),
      classes: List<String>.from((m['classes'] as List<dynamic>?) ?? []),
      dateEmbauche: m['dateEmbauche'] as String?,
      typeContrat: m['typeContrat'] as String?,
      tempsPlein: (m['tempsPlein'] as bool?) ?? true,
      statut: (m['statut'] as String?) ?? 'Actif',
      heuresTotal: (m['heuresTotal'] as int?) ?? 0,
      remplacementsTotal: (m['remplacementsTotal'] as int?) ?? 0,
      updatedAt: m['updatedAt'] as Timestamp?,
    );
  }

  /// Crée un profil minimal à partir d'un [UserModel] (initialisation).
  factory EnseignantProfil.fromUserModel(UserModel u) {
    // Tenter de séparer nom et prénom depuis displayName
    final parts = u.displayName.trim().split(' ');
    final prenom = parts.isNotEmpty ? parts.first : '';
    final nom = parts.length > 1 ? parts.sublist(1).join(' ') : '';
    return EnseignantProfil(
      uid: u.uid,
      nom: nom,
      prenom: prenom,
      email: u.email,
      photoUrl: u.photoUrl,
      matieres: u.matiere != null && u.matiere!.isNotEmpty ? [u.matiere!] : [],
      statut: 'Actif',
    );
  }

  // ─── Serialisation ────────────────────────────────────────────────────────

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'nom': nom,
      'prenom': prenom,
      if (sexe != null) 'sexe': sexe,
      if (dateNaissance != null) 'dateNaissance': dateNaissance,
      if (adresse != null) 'adresse': adresse,
      if (telephone != null) 'telephone': telephone,
      if (email != null) 'email': email,
      if (nationalite != null) 'nationalite': nationalite,
      if (matricule != null) 'matricule': matricule,
      if (photoUrl != null) 'photoUrl': photoUrl,
      'matieres': matieres,
      'cycles': cycles,
      'niveaux': niveaux,
      'classes': classes,
      if (dateEmbauche != null) 'dateEmbauche': dateEmbauche,
      if (typeContrat != null) 'typeContrat': typeContrat,
      'tempsPlein': tempsPlein,
      'statut': statut,
      'heuresTotal': heuresTotal,
      'remplacementsTotal': remplacementsTotal,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  // ─── CopyWith ─────────────────────────────────────────────────────────────

  EnseignantProfil copyWith({
    String? nom,
    String? prenom,
    String? sexe,
    String? dateNaissance,
    String? adresse,
    String? telephone,
    String? email,
    String? nationalite,
    String? matricule,
    String? photoUrl,
    List<String>? matieres,
    List<String>? cycles,
    List<String>? niveaux,
    List<String>? classes,
    String? dateEmbauche,
    String? typeContrat,
    bool? tempsPlein,
    String? statut,
    int? heuresTotal,
    int? remplacementsTotal,
  }) {
    return EnseignantProfil(
      uid: uid,
      nom: nom ?? this.nom,
      prenom: prenom ?? this.prenom,
      sexe: sexe ?? this.sexe,
      dateNaissance: dateNaissance ?? this.dateNaissance,
      adresse: adresse ?? this.adresse,
      telephone: telephone ?? this.telephone,
      email: email ?? this.email,
      nationalite: nationalite ?? this.nationalite,
      matricule: matricule ?? this.matricule,
      photoUrl: photoUrl ?? this.photoUrl,
      matieres: matieres ?? this.matieres,
      cycles: cycles ?? this.cycles,
      niveaux: niveaux ?? this.niveaux,
      classes: classes ?? this.classes,
      dateEmbauche: dateEmbauche ?? this.dateEmbauche,
      typeContrat: typeContrat ?? this.typeContrat,
      tempsPlein: tempsPlein ?? this.tempsPlein,
      statut: statut ?? this.statut,
      heuresTotal: heuresTotal ?? this.heuresTotal,
      remplacementsTotal: remplacementsTotal ?? this.remplacementsTotal,
      updatedAt: updatedAt,
    );
  }

  /// Matricule affiché — auto-généré si absent.
  String get matriculeDisplay =>
      (matricule != null && matricule!.isNotEmpty)
          ? matricule!
          : 'ENS-${uid.substring(0, uid.length.clamp(0, 6)).toUpperCase()}';

  /// Nom complet prénom + nom.
  String get fullName => '$prenom $nom'.trim();
}
