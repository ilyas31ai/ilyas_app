import 'package:cloud_firestore/cloud_firestore.dart';

class AnnonceModel {
  final String id;
  final String titre;
  final String contenu;
  final String auteurId;
  final String auteurNom;
  final DateTime date;
  final String type;

  const AnnonceModel({
    required this.id,
    required this.titre,
    required this.contenu,
    required this.auteurId,
    required this.auteurNom,
    required this.date,
    this.type = 'annonce',
  });

  factory AnnonceModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return AnnonceModel(
      id: doc.id,
      titre: d['titre'] is String ? d['titre'] as String : '',
      contenu: d['contenu'] is String ? d['contenu'] as String : '',
      auteurId: d['auteurId'] is String ? d['auteurId'] as String : '',
      auteurNom: d['auteurNom'] is String ? d['auteurNom'] as String : '',
      date: d['date'] is Timestamp
          ? (d['date'] as Timestamp).toDate()
          : DateTime.now(),
      type: d['type'] is String ? d['type'] as String : 'annonce',
    );
  }

  Map<String, dynamic> toMap() => {
        'titre': titre,
        'contenu': contenu,
        'auteurId': auteurId,
        'auteurNom': auteurNom,
        'date': Timestamp.fromDate(date),
        'type': type,
      };
}
