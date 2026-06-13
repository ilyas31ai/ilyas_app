import 'package:cloud_firestore/cloud_firestore.dart';

class NoteModel {
  final String id;
  final String eleveId;
  final String eleveNom;
  final String elevePrenom;
  final String classeId;
  final String classeNom;
  final String matiere;
  final String professeurId;
  final double note;
  final double bareme;
  final String intitule;
  final DateTime date;
  final bool publie;

  const NoteModel({
    required this.id,
    required this.eleveId,
    required this.eleveNom,
    required this.elevePrenom,
    required this.classeId,
    required this.classeNom,
    required this.matiere,
    required this.professeurId,
    required this.note,
    this.bareme = 20,
    required this.intitule,
    required this.date,
    this.publie = false,
  });

  String get eleveNomComplet => '$elevePrenom $eleveNom'.trim();
  double get sur20 => bareme == 0 ? 0 : (note / bareme) * 20;

  factory NoteModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return NoteModel(
      id: doc.id,
      eleveId: d['eleveId'] as String? ?? '',
      eleveNom: d['eleveNom'] as String? ?? '',
      elevePrenom: d['elevePrenom'] as String? ?? '',
      classeId: d['classeId'] as String? ?? '',
      classeNom: d['classeNom'] as String? ?? '',
      matiere: d['matiere'] as String? ?? '',
      professeurId: d['professeurId'] as String? ?? '',
      note: (d['note'] as num?)?.toDouble() ?? 0,
      bareme: (d['bareme'] as num?)?.toDouble() ?? 20,
      intitule: d['intitule'] as String? ?? '',
      date: (d['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      publie: d['publie'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
        'eleveId': eleveId,
        'eleveNom': eleveNom,
        'elevePrenom': elevePrenom,
        'classeId': classeId,
        'classeNom': classeNom,
        'matiere': matiere,
        'professeurId': professeurId,
        'note': note,
        'bareme': bareme,
        'intitule': intitule,
        'date': Timestamp.fromDate(date),
        'publie': publie,
      };

  NoteModel copyWith({double? note, String? intitule, bool? publie}) =>
      NoteModel(
        id: id,
        eleveId: eleveId,
        eleveNom: eleveNom,
        elevePrenom: elevePrenom,
        classeId: classeId,
        classeNom: classeNom,
        matiere: matiere,
        professeurId: professeurId,
        note: note ?? this.note,
        bareme: bareme,
        intitule: intitule ?? this.intitule,
        date: date,
        publie: publie ?? this.publie,
      );
}
