import 'package:cloud_firestore/cloud_firestore.dart';

class ClasseModel {
  final String id;
  final String nom;
  final String niveau;
  final String professeurId;
  final List<String> eleveIds;
  final int anneeScol;

  const ClasseModel({
    required this.id,
    required this.nom,
    required this.niveau,
    required this.professeurId,
    this.eleveIds = const [],
    required this.anneeScol,
  });

  int get nbEleves => eleveIds.length;

  factory ClasseModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return ClasseModel(
      id: doc.id,
      nom: d['nom'] as String? ?? '',
      niveau: d['niveau'] as String? ?? '',
      professeurId: d['professeurId'] as String? ?? '',
      eleveIds: List<String>.from(d['eleveIds'] as List? ?? []),
      anneeScol: (d['anneeScol'] as num?)?.toInt() ?? DateTime.now().year,
    );
  }

  Map<String, dynamic> toMap() => {
        'nom': nom,
        'niveau': niveau,
        'professeurId': professeurId,
        'eleveIds': eleveIds,
        'anneeScol': anneeScol,
      };

  ClasseModel copyWith({List<String>? eleveIds}) => ClasseModel(
        id: id,
        nom: nom,
        niveau: niveau,
        professeurId: professeurId,
        eleveIds: eleveIds ?? this.eleveIds,
        anneeScol: anneeScol,
      );
}

class EmploiSlot {
  final String id;
  final int jour; // 1=Lundi … 5=Vendredi
  final String heureDebut;
  final String heureFin;
  final String matiere;
  final String classeNom;
  final String classeId;
  final String salle;
  final String professeurId;

  const EmploiSlot({
    required this.id,
    required this.jour,
    required this.heureDebut,
    required this.heureFin,
    required this.matiere,
    required this.classeNom,
    required this.classeId,
    required this.salle,
    required this.professeurId,
  });

  static const joursLabels = ['Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi'];
  String get jourLabel => jour >= 1 && jour <= 5 ? joursLabels[jour - 1] : '?';

  factory EmploiSlot.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return EmploiSlot(
      id: doc.id,
      jour: (d['jour'] as num?)?.toInt() ?? 1,
      heureDebut: d['heureDebut'] as String? ?? '08:00',
      heureFin: d['heureFin'] as String? ?? '09:00',
      matiere: d['matiere'] as String? ?? '',
      classeNom: d['classeNom'] as String? ?? '',
      classeId: d['classeId'] as String? ?? '',
      salle: d['salle'] as String? ?? '',
      professeurId: d['professeurId'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
        'jour': jour,
        'heureDebut': heureDebut,
        'heureFin': heureFin,
        'matiere': matiere,
        'classeNom': classeNom,
        'classeId': classeId,
        'salle': salle,
        'professeurId': professeurId,
      };
}
