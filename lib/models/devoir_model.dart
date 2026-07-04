import 'package:cloud_firestore/cloud_firestore.dart';
import 'question_model.dart';
import 'school_model.dart';

class DevoirModel {
  final String id;
  final String schoolId;
  final String titre;
  final String description;
  final String matiere;
  final String classeId;
  final String classeNom;
  final String categorie;
  final String professeurId;
  final String professeurNom;
  final DateTime dateEnvoi;
  final DateTime? dateLimite;
  final DateTime? datePublication;
  // Single file (legacy compat)
  final String fichierUrl;
  final String fichierNom;
  // Multiple attachments: [{url, nom, type}]
  final List<Map<String, String>> piecesJointes;
  // Barème (sur N points, default 20)
  final int bareme;
  // Interactive homework fields
  final List<QuestionModel> questions;
  final bool estExamen;
  final bool aiActive;
  final int? dureeMinutes;

  const DevoirModel({
    required this.id,
    this.schoolId = kDefaultSchoolId,
    required this.titre,
    required this.description,
    required this.matiere,
    required this.classeId,
    required this.classeNom,
    this.categorie = '',
    required this.professeurId,
    this.professeurNom = '',
    required this.dateEnvoi,
    this.dateLimite,
    this.datePublication,
    this.fichierUrl = '',
    this.fichierNom = '',
    this.piecesJointes = const [],
    this.bareme = 20,
    this.questions = const [],
    this.estExamen = false,
    this.aiActive = true,
    this.dureeMinutes,
  });

  bool get aFichier => fichierUrl.isNotEmpty || piecesJointes.isNotEmpty;
  bool get estInteractif => questions.isNotEmpty;
  double get totalPoints =>
      questions.fold(0.0, (acc, q) => acc + q.points);

  List<Map<String, String>> get tousLesAttachements {
    final all = <Map<String, String>>[...piecesJointes];
    if (fichierUrl.isNotEmpty) {
      final ext = fichierNom.split('.').last.toLowerCase();
      all.insert(0, {'url': fichierUrl, 'nom': fichierNom, 'type': ext});
    }
    return all;
  }

  factory DevoirModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    final rawQ = d['questions'] as List? ?? [];
    final rawPJ = d['piecesJointes'] as List? ?? [];
    return DevoirModel(
      id: doc.id,
      schoolId: d['schoolId'] as String? ?? kDefaultSchoolId,
      titre: d['titre'] as String? ?? '',
      description: d['description'] as String? ?? '',
      matiere: d['matiere'] as String? ?? '',
      classeId: d['classeId'] as String? ?? '',
      classeNom: d['classeNom'] as String? ?? '',
      categorie: d['categorie'] as String? ?? '',
      professeurId: d['professeurId'] as String? ?? '',
      professeurNom: d['professeurNom'] as String? ?? '',
      dateEnvoi:
          (d['dateEnvoi'] as Timestamp?)?.toDate() ?? DateTime.now(),
      dateLimite: (d['dateLimite'] as Timestamp?)?.toDate(),
      datePublication: (d['datePublication'] as Timestamp?)?.toDate(),
      fichierUrl: d['fichierUrl'] as String? ?? '',
      fichierNom: d['fichierNom'] as String? ?? '',
      piecesJointes: rawPJ
          .map<Map<String, String>>((e) => Map<String, String>.from(
              (e as Map).map((k, v) =>
                  MapEntry(k.toString(), v.toString()))))
          .toList(),
      bareme: (d['bareme'] as num?)?.toInt() ?? 20,
      questions: rawQ
          .map((q) =>
              QuestionModel.fromMap(q as Map<String, dynamic>))
          .toList(),
      estExamen: d['estExamen'] as bool? ?? false,
      aiActive: d['aiActive'] as bool? ?? true,
      dureeMinutes: d['dureeMinutes'] as int?,
    );
  }

  Map<String, dynamic> toMap() => {
        'schoolId': schoolId,
        'titre': titre,
        'description': description,
        'matiere': matiere,
        'classeId': classeId,
        'classeNom': classeNom,
        if (categorie.isNotEmpty) 'categorie': categorie,
        'professeurId': professeurId,
        if (professeurNom.isNotEmpty) 'professeurNom': professeurNom,
        'dateEnvoi': FieldValue.serverTimestamp(),
        if (dateLimite != null)
          'dateLimite': Timestamp.fromDate(dateLimite!),
        if (datePublication != null)
          'datePublication': Timestamp.fromDate(datePublication!),
        'fichierUrl': fichierUrl,
        'fichierNom': fichierNom,
        'piecesJointes': piecesJointes,
        'bareme': bareme,
        if (questions.isNotEmpty)
          'questions': questions.map((q) => q.toMap()).toList(),
        'estExamen': estExamen,
        'aiActive': aiActive,
        if (dureeMinutes != null) 'dureeMinutes': dureeMinutes,
      };
}
