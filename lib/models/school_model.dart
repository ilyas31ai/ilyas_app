import 'package:cloud_firestore/cloud_firestore.dart';

/// Identifiant de l'établissement unique actuel, utilisé comme valeur de
/// repli tant que le backfill `schoolId` (Phase 2) n'a pas été exécuté sur
/// les données existantes. Toute lecture sans `schoolId` est traitée comme
/// appartenant à cet établissement — aucune régression sur les données
/// actuelles, qui n'ont pas encore ce champ.
const String kDefaultSchoolId = 'ecole_default';

class SchoolModel {
  final String id;
  final String nom;
  final String type; // 'maternelle'|'primaire'|'college'|'lycee'|'universite'|'mixte'
  final String statut; // 'actif'|'suspendu'
  final List<String> campusIds;
  final Timestamp? createdAt;

  const SchoolModel({
    required this.id,
    required this.nom,
    this.type = 'mixte',
    this.statut = 'actif',
    this.campusIds = const [],
    this.createdAt,
  });

  factory SchoolModel.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return SchoolModel(
      id: doc.id,
      nom: d['nom'] as String? ?? '',
      type: d['type'] as String? ?? 'mixte',
      statut: d['statut'] as String? ?? 'actif',
      campusIds: List<String>.from(d['campusIds'] as List? ?? []),
      createdAt: d['createdAt'] as Timestamp?,
    );
  }

  Map<String, dynamic> toMap() => {
        'nom': nom,
        'type': type,
        'statut': statut,
        if (campusIds.isNotEmpty) 'campusIds': campusIds,
      };
}
