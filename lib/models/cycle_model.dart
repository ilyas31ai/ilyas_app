import 'package:cloud_firestore/cloud_firestore.dart';

/// Référentiel global (collection `cycles`), partagé par tous les
/// établissements — pas de `schoolId` ici, volontairement (cf. architecture
/// cible, `00_RAPPORT_ARCHITECTURE_GLOBAL.md` §2.2).
class CycleModel {
  final String id;
  final String nom; // 'Maternelle' | 'Primaire' | 'Collège' | 'Lycée' | 'Université'
  final List<String> niveauIds;

  const CycleModel({
    required this.id,
    required this.nom,
    this.niveauIds = const [],
  });

  factory CycleModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return CycleModel(
      id: doc.id,
      nom: d['nom'] as String? ?? '',
      niveauIds: List<String>.from(d['niveauIds'] as List? ?? []),
    );
  }

  Map<String, dynamic> toMap() => {
        'nom': nom,
        if (niveauIds.isNotEmpty) 'niveauIds': niveauIds,
      };
}

/// Référentiel global (collection `niveaux`), ex. 'PS', 'CP', '6e', 'Seconde', 'L1'.
class NiveauModel {
  final String id;
  final String cycleId;
  final String nom;
  final int ordre;

  const NiveauModel({
    required this.id,
    required this.cycleId,
    required this.nom,
    this.ordre = 0,
  });

  factory NiveauModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return NiveauModel(
      id: doc.id,
      cycleId: d['cycleId'] as String? ?? '',
      nom: d['nom'] as String? ?? '',
      ordre: (d['ordre'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
        'cycleId': cycleId,
        'nom': nom,
        'ordre': ordre,
      };
}
