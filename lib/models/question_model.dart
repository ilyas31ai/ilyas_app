import 'dart:math';

enum TypeQuestion { qcm, vraiFaux, reponseCourte, reponseLongue, photo }

extension TypeQuestionX on TypeQuestion {
  String get value => const {
        TypeQuestion.qcm: 'qcm',
        TypeQuestion.vraiFaux: 'vrai_faux',
        TypeQuestion.reponseCourte: 'reponse_courte',
        TypeQuestion.reponseLongue: 'reponse_longue',
        TypeQuestion.photo: 'photo',
      }[this]!;

  String get label => const {
        TypeQuestion.qcm: 'QCM',
        TypeQuestion.vraiFaux: 'Vrai / Faux',
        TypeQuestion.reponseCourte: 'Réponse courte',
        TypeQuestion.reponseLongue: 'Réponse longue',
        TypeQuestion.photo: 'Photo / Document',
      }[this]!;

  static TypeQuestion fromString(String? s) {
    switch (s) {
      case 'qcm':
        return TypeQuestion.qcm;
      case 'vrai_faux':
        return TypeQuestion.vraiFaux;
      case 'reponse_courte':
        return TypeQuestion.reponseCourte;
      case 'reponse_longue':
        return TypeQuestion.reponseLongue;
      case 'photo':
        return TypeQuestion.photo;
      default:
        return TypeQuestion.reponseCourte;
    }
  }
}

class QuestionModel {
  final String id;
  final TypeQuestion type;
  final String enonce;
  final double points;
  final List<String> choix;
  final int? bonneReponseIndex;
  final bool? bonneReponseVF;
  final String reponseAttendue;
  final String correctionModele;

  const QuestionModel({
    required this.id,
    required this.type,
    required this.enonce,
    this.points = 1.0,
    this.choix = const [],
    this.bonneReponseIndex,
    this.bonneReponseVF,
    this.reponseAttendue = '',
    this.correctionModele = '',
  });

  factory QuestionModel.fromMap(Map<String, dynamic> d) => QuestionModel(
        id: d['id'] as String? ?? '',
        type: TypeQuestionX.fromString(d['type'] as String?),
        enonce: d['enonce'] as String? ?? '',
        points: (d['points'] as num?)?.toDouble() ?? 1.0,
        choix: List<String>.from(d['choix'] as List? ?? []),
        bonneReponseIndex: d['bonneReponseIndex'] as int?,
        bonneReponseVF: d['bonneReponseVF'] as bool?,
        reponseAttendue: d['reponseAttendue'] as String? ?? '',
        correctionModele: d['correctionModele'] as String? ?? '',
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'type': type.value,
        'enonce': enonce,
        'points': points,
        if (choix.isNotEmpty) 'choix': choix,
        if (bonneReponseIndex != null) 'bonneReponseIndex': bonneReponseIndex,
        if (bonneReponseVF != null) 'bonneReponseVF': bonneReponseVF,
        if (reponseAttendue.isNotEmpty) 'reponseAttendue': reponseAttendue,
        if (correctionModele.isNotEmpty) 'correctionModele': correctionModele,
      };

  QuestionModel copyWith({
    TypeQuestion? type,
    String? enonce,
    double? points,
    List<String>? choix,
    int? bonneReponseIndex,
    bool? bonneReponseVF,
    String? reponseAttendue,
    String? correctionModele,
  }) =>
      QuestionModel(
        id: id,
        type: type ?? this.type,
        enonce: enonce ?? this.enonce,
        points: points ?? this.points,
        choix: choix ?? this.choix,
        bonneReponseIndex: bonneReponseIndex ?? this.bonneReponseIndex,
        bonneReponseVF: bonneReponseVF ?? this.bonneReponseVF,
        reponseAttendue: reponseAttendue ?? this.reponseAttendue,
        correctionModele: correctionModele ?? this.correctionModele,
      );

  static String genId() =>
      DateTime.now().millisecondsSinceEpoch.toRadixString(36) +
      Random().nextInt(9999).toString().padLeft(4, '0');
}
