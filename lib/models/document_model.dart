import 'package:cloud_firestore/cloud_firestore.dart';

class DocumentPedagogique {
  final String id;
  final String titre;
  final String description;
  final String matiere;
  final String classeId;
  final String classeNom;
  final String professeurId;
  final String fichierUrl;
  final String fichierNom;
  final DateTime dateDepot;
  final String type; // 'cours', 'exercice', 'correction', 'autre'

  const DocumentPedagogique({
    required this.id,
    required this.titre,
    required this.description,
    required this.matiere,
    required this.classeId,
    required this.classeNom,
    required this.professeurId,
    required this.fichierUrl,
    required this.fichierNom,
    required this.dateDepot,
    this.type = 'cours',
  });

  bool get aFichier => fichierUrl.isNotEmpty;

  factory DocumentPedagogique.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return DocumentPedagogique(
      id: doc.id,
      titre: d['titre'] is String ? d['titre'] as String : '',
      description: d['description'] is String ? d['description'] as String : '',
      matiere: d['matiere'] is String ? d['matiere'] as String : '',
      classeId: d['classeId'] is String ? d['classeId'] as String : '',
      classeNom: d['classeNom'] is String ? d['classeNom'] as String : '',
      professeurId:
          d['professeurId'] is String ? d['professeurId'] as String : '',
      fichierUrl: d['fichierUrl'] is String ? d['fichierUrl'] as String : '',
      fichierNom: d['fichierNom'] is String ? d['fichierNom'] as String : '',
      dateDepot: d['dateDepot'] is Timestamp
          ? (d['dateDepot'] as Timestamp).toDate()
          : DateTime.now(),
      type: d['type'] is String ? d['type'] as String : 'cours',
    );
  }

  Map<String, dynamic> toMap() => {
        'titre': titre,
        'description': description,
        'matiere': matiere,
        'classeId': classeId,
        'classeNom': classeNom,
        'professeurId': professeurId,
        'fichierUrl': fichierUrl,
        'fichierNom': fichierNom,
        'dateDepot': Timestamp.fromDate(dateDepot),
        'type': type,
      };
}
