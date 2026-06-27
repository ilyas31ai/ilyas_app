import 'package:cloud_firestore/cloud_firestore.dart';

import 'school_model.dart';

enum PresenceStatut { present, absent, retard }

extension PresenceStatutX on PresenceStatut {
  String get label {
    switch (this) {
      case PresenceStatut.present:
        return 'Présent';
      case PresenceStatut.absent:
        return 'Absent';
      case PresenceStatut.retard:
        return 'En retard';
    }
  }

  String get value {
    switch (this) {
      case PresenceStatut.present:
        return 'present';
      case PresenceStatut.absent:
        return 'absent';
      case PresenceStatut.retard:
        return 'retard';
    }
  }

  static PresenceStatut fromString(String? s) {
    switch (s) {
      case 'absent':
        return PresenceStatut.absent;
      case 'retard':
        return PresenceStatut.retard;
      default:
        return PresenceStatut.present;
    }
  }
}

class PresenceRecord {
  final String id;
  final String schoolId;
  final String eleveId;
  final String eleveNom;
  final String elevePrenom;
  final String classeId;
  final String classeNom;
  final String professeurId;
  final DateTime date;
  final PresenceStatut statut;
  final String motif;

  const PresenceRecord({
    required this.id,
    this.schoolId = kDefaultSchoolId,
    required this.eleveId,
    required this.eleveNom,
    required this.elevePrenom,
    required this.classeId,
    required this.classeNom,
    required this.professeurId,
    required this.date,
    required this.statut,
    this.motif = '',
  });

  String get eleveNomComplet => '$elevePrenom $eleveNom'.trim();

  factory PresenceRecord.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return PresenceRecord(
      id: doc.id,
      schoolId: d['schoolId'] as String? ?? kDefaultSchoolId,
      eleveId: d['eleveId'] as String? ?? '',
      eleveNom: d['eleveNom'] as String? ?? '',
      elevePrenom: d['elevePrenom'] as String? ?? '',
      classeId: d['classeId'] as String? ?? '',
      classeNom: d['classeNom'] as String? ?? '',
      professeurId: d['professeurId'] as String? ?? '',
      date: (d['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      statut: PresenceStatutX.fromString(d['statut'] as String?),
      motif: d['motif'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
        'schoolId': schoolId,
        'eleveId': eleveId,
        'eleveNom': eleveNom,
        'elevePrenom': elevePrenom,
        'classeId': classeId,
        'classeNom': classeNom,
        'professeurId': professeurId,
        'date': Timestamp.fromDate(date),
        'statut': statut.value,
        'motif': motif,
      };

  PresenceRecord copyWith({PresenceStatut? statut, String? motif}) =>
      PresenceRecord(
        id: id,
        schoolId: schoolId,
        eleveId: eleveId,
        eleveNom: eleveNom,
        elevePrenom: elevePrenom,
        classeId: classeId,
        classeNom: classeNom,
        professeurId: professeurId,
        date: date,
        statut: statut ?? this.statut,
        motif: motif ?? this.motif,
      );
}
