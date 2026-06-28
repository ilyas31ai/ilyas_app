import 'package:cloud_firestore/cloud_firestore.dart';

/// Firestore collection: disponibilites/{uid}
class DisponibiliteEnseignant {
  final String uid;
  final String nom;
  final String email;
  final List<String> jours; // ['Lundi', 'Mardi', ...]
  final List<CreneauHoraire> creneaux;
  final List<String> matieres;
  final List<String> niveaux;
  final List<String> classes;
  final bool disponibleAujourdhui;
  final Timestamp? updatedAt;

  const DisponibiliteEnseignant({
    required this.uid,
    required this.nom,
    required this.email,
    required this.jours,
    required this.creneaux,
    required this.matieres,
    required this.niveaux,
    required this.classes,
    required this.disponibleAujourdhui,
    this.updatedAt,
  });

  factory DisponibiliteEnseignant.fromMap(String uid, Map<String, dynamic> m) {
    return DisponibiliteEnseignant(
      uid: uid,
      nom: (m['nom'] as String?) ?? '',
      email: (m['email'] as String?) ?? '',
      jours: List<String>.from((m['jours'] as List<dynamic>?) ?? []),
      creneaux: ((m['creneaux'] as List<dynamic>?) ?? [])
          .map((e) => CreneauHoraire.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList(),
      matieres: List<String>.from((m['matieres'] as List<dynamic>?) ?? []),
      niveaux: List<String>.from((m['niveaux'] as List<dynamic>?) ?? []),
      classes: List<String>.from((m['classes'] as List<dynamic>?) ?? []),
      disponibleAujourdhui: (m['disponibleAujourdhui'] as bool?) ?? false,
      updatedAt: m['updatedAt'] as Timestamp?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'nom': nom,
      'email': email,
      'jours': jours,
      'creneaux': creneaux.map((c) => c.toMap()).toList(),
      'matieres': matieres,
      'niveaux': niveaux,
      'classes': classes,
      'disponibleAujourdhui': disponibleAujourdhui,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  DisponibiliteEnseignant copyWith({
    String? uid,
    String? nom,
    String? email,
    List<String>? jours,
    List<CreneauHoraire>? creneaux,
    List<String>? matieres,
    List<String>? niveaux,
    List<String>? classes,
    bool? disponibleAujourdhui,
    Timestamp? updatedAt,
  }) {
    return DisponibiliteEnseignant(
      uid: uid ?? this.uid,
      nom: nom ?? this.nom,
      email: email ?? this.email,
      jours: jours ?? this.jours,
      creneaux: creneaux ?? this.creneaux,
      matieres: matieres ?? this.matieres,
      niveaux: niveaux ?? this.niveaux,
      classes: classes ?? this.classes,
      disponibleAujourdhui: disponibleAujourdhui ?? this.disponibleAujourdhui,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class CreneauHoraire {
  final String jour;
  final String heureDebut; // '08:00'
  final String heureFin; // '10:00'

  const CreneauHoraire({
    required this.jour,
    required this.heureDebut,
    required this.heureFin,
  });

  factory CreneauHoraire.fromMap(Map<String, dynamic> m) {
    return CreneauHoraire(
      jour: (m['jour'] as String?) ?? '',
      heureDebut: (m['heureDebut'] as String?) ?? '08:00',
      heureFin: (m['heureFin'] as String?) ?? '09:00',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'jour': jour,
      'heureDebut': heureDebut,
      'heureFin': heureFin,
    };
  }

  @override
  String toString() => '$jour $heureDebut–$heureFin';
}
