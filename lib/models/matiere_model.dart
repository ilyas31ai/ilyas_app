import 'package:cloud_firestore/cloud_firestore.dart';

import 'school_model.dart';

/// Référentiel des matières par établissement (collection `matieres`),
/// destiné à remplacer à terme la liste statique `_kMatieres` codée en dur
/// dans `etudiant_revisions_page.dart` (DT-05) — pas encore branché, ce
/// modèle prépare uniquement la structure.
class MatiereModel {
  final String id;
  final String schoolId;
  final String nom;
  final String cycleId;
  final String niveauId;
  final double coefficient;
  final bool obligatoire;
  final String? professeurPrincipalId;
  final List<String> professeursSecondaires;

  const MatiereModel({
    required this.id,
    this.schoolId = kDefaultSchoolId,
    required this.nom,
    this.cycleId = '',
    this.niveauId = '',
    this.coefficient = 1.0,
    this.obligatoire = true,
    this.professeurPrincipalId,
    this.professeursSecondaires = const [],
  });

  factory MatiereModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return MatiereModel(
      id: doc.id,
      schoolId: d['schoolId'] as String? ?? kDefaultSchoolId,
      nom: d['nom'] as String? ?? '',
      cycleId: d['cycleId'] as String? ?? '',
      niveauId: d['niveauId'] as String? ?? '',
      coefficient: (d['coefficient'] as num?)?.toDouble() ?? 1.0,
      obligatoire: d['obligatoire'] as bool? ?? true,
      professeurPrincipalId: d['professeurPrincipalId'] as String?,
      professeursSecondaires:
          List<String>.from(d['professeursSecondaires'] as List? ?? []),
    );
  }

  Map<String, dynamic> toMap() => {
        'schoolId': schoolId,
        'nom': nom,
        'cycleId': cycleId,
        'niveauId': niveauId,
        'coefficient': coefficient,
        'obligatoire': obligatoire,
        if (professeurPrincipalId != null)
          'professeurPrincipalId': professeurPrincipalId,
        if (professeursSecondaires.isNotEmpty)
          'professeursSecondaires': professeursSecondaires,
      };
}
