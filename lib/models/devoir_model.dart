import 'package:cloud_firestore/cloud_firestore.dart';
import 'question_model.dart';

class DevoirModel {
  final String id;
  final String titre;
  final String description;
  final String matiere;
  final String classeId;
  final String classeNom;
  final String categorie;
  final String professeurId;
  final DateTime dateEnvoi;
  final DateTime? dateLimite;
  final String fichierUrl;
  final String fichierNom;
  // Interactive homework fields
  final List<QuestionModel> questions;
  final bool estExamen;
  final bool aiActive;
  final int? dureeMinutes;

  const DevoirModel({
    required this.id,
    required this.titre,
    required this.description,
    required this.matiere,
    required this.classeId,
    required this.classeNom,
    this.categorie = '',
    required this.professeurId,
    required this.dateEnvoi,
    this.dateLimite,
    this.fichierUrl = '',
    this.fichierNom = '',
    this.questions = const [],
    this.estExamen = false,
    this.aiActive = true,
    this.dureeMinutes,
  });

  bool get aFichier => fichierUrl.isNotEmpty;
  bool get estInteractif => questions.isNotEmpty;
  double get totalPoints =>
      questions.fold(0.0, (sum, q) => sum + q.points);

  factory DevoirModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    final rawQ = d['questions'] as List? ?? [];
    return DevoirModel(
      id: doc.id,
      titre: d['titre'] as String? ?? '',
      description: d['description'] as String? ?? '',
      matiere: d['matiere'] as String? ?? '',
      classeId: d['classeId'] as String? ?? '',
      classeNom: d['classeNom'] as String? ?? '',
      categorie: d['categorie'] as String? ?? '',
      professeurId: d['professeurId'] as String? ?? '',
      dateEnvoi:
          (d['dateEnvoi'] as Timestamp?)?.toDate() ?? DateTime.now(),
      dateLimite: (d['dateLimite'] as Timestamp?)?.toDate(),
      fichierUrl: d['fichierUrl'] as String? ?? '',
      fichierNom: d['fichierNom'] as String? ?? '',
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
        'titre': titre,
        'description': description,
        'matiere': matiere,
        'classeId': classeId,
        'classeNom': classeNom,
        if (categorie.isNotEmpty) 'categorie': categorie,
        'professeurId': professeurId,
        'dateEnvoi': Timestamp.fromDate(dateEnvoi),
        if (dateLimite != null)
          'dateLimite': Timestamp.fromDate(dateLimite!),
        'fichierUrl': fichierUrl,
        'fichierNom': fichierNom,
        if (questions.isNotEmpty)
          'questions': questions.map((q) => q.toMap()).toList(),
        'estExamen': estExamen,
        'aiActive': aiActive,
        if (dureeMinutes != null) 'dureeMinutes': dureeMinutes,
      };
}
