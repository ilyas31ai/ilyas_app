import 'package:cloud_firestore/cloud_firestore.dart';

import 'school_model.dart';

/// Workflow de publication d'un document pédagogique (DT-06, ajout additif).
/// Champ optionnel : les documents existants sans valeur sont traités comme
/// "publie" (comportement historique, aucune régression d'affichage).
enum DocumentStatut { televerse, valide, publie, archive }

extension DocumentStatutX on DocumentStatut {
  String get value {
    switch (this) {
      case DocumentStatut.televerse:
        return 'televerse';
      case DocumentStatut.valide:
        return 'valide';
      case DocumentStatut.publie:
        return 'publie';
      case DocumentStatut.archive:
        return 'archive';
    }
  }

  static DocumentStatut fromString(String? s) {
    switch (s) {
      case 'televerse':
        return DocumentStatut.televerse;
      case 'valide':
        return DocumentStatut.valide;
      case 'archive':
        return DocumentStatut.archive;
      default:
        return DocumentStatut.publie;
    }
  }
}

class DocumentPedagogique {
  final String id;
  final String schoolId;
  final String titre;
  final String description;
  final String matiere;
  final String classeId;
  final String classeNom;
  final String professeurId;
  final String fichierUrl;
  final String fichierNom;
  final DateTime dateDepot;
  final String type; // 'cours', 'exercice', 'correction', 'video', 'autre'
  final DocumentStatut statut;
  final String devoirId; // lien vers DevoirModel.id si type='correction'

  const DocumentPedagogique({
    required this.id,
    this.schoolId = kDefaultSchoolId,
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
    this.statut = DocumentStatut.publie,
    this.devoirId = '',
  });

  bool get aFichier => fichierUrl.isNotEmpty;

  factory DocumentPedagogique.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return DocumentPedagogique(
      id: doc.id,
      schoolId: d['schoolId'] as String? ?? kDefaultSchoolId,
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
      statut: DocumentStatutX.fromString(d['statut'] as String?),
      devoirId: d['devoirId'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
        'schoolId': schoolId,
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
        'statut': statut.value,
        if (devoirId.isNotEmpty) 'devoirId': devoirId,
      };
}
