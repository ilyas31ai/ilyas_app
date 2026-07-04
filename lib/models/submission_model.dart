import 'package:cloud_firestore/cloud_firestore.dart';

import 'school_model.dart';

enum SubmissionStatus { pending, corrected }

extension SubmissionStatusX on SubmissionStatus {
  String get value {
    switch (this) {
      case SubmissionStatus.pending:
        return 'pending';
      case SubmissionStatus.corrected:
        return 'corrected';
    }
  }

  String get label {
    switch (this) {
      case SubmissionStatus.pending:
        return 'En attente';
      case SubmissionStatus.corrected:
        return 'Corrigé';
    }
  }

  static SubmissionStatus fromString(String? s) {
    switch (s) {
      case 'corrected':
        return SubmissionStatus.corrected;
      default:
        return SubmissionStatus.pending;
    }
  }
}

class SubmissionModel {
  final String id;
  final String schoolId;
  final String studentId;
  final String studentEmail;
  final String studentNom;
  final String classeId;
  final String classeNom;
  final String devoirTitre;
  final String assignmentId;
  final String teacherId;
  // Legacy single file
  final String fileUrl;
  final String fileType;
  // Text answer
  final String comment;
  final String textReponse;
  // Multiple files: [{url, nom, type}]
  final List<Map<String, String>> piecesJointes;
  final DateTime createdAt;
  final SubmissionStatus status;
  final double? grade;
  final String? teacherComment;

  const SubmissionModel({
    required this.id,
    this.schoolId = kDefaultSchoolId,
    required this.studentId,
    required this.studentEmail,
    this.studentNom = '',
    this.classeId = '',
    this.classeNom = '',
    this.devoirTitre = '',
    required this.assignmentId,
    required this.teacherId,
    this.fileUrl = '',
    this.fileType = '',
    this.comment = '',
    this.textReponse = '',
    this.piecesJointes = const [],
    required this.createdAt,
    this.status = SubmissionStatus.pending,
    this.grade,
    this.teacherComment,
  });

  List<Map<String, String>> get tousLesFichiers {
    final all = <Map<String, String>>[...piecesJointes];
    if (fileUrl.isNotEmpty) {
      all.insert(0, {'url': fileUrl, 'nom': 'Fichier joint', 'type': fileType});
    }
    return all;
  }

  factory SubmissionModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    final rawPJ = d['piecesJointes'] as List? ?? [];
    return SubmissionModel(
      id: doc.id,
      schoolId: d['schoolId'] as String? ?? kDefaultSchoolId,
      studentId: d['studentId'] as String? ?? '',
      studentEmail: d['studentEmail'] as String? ?? '',
      studentNom: d['studentNom'] as String? ?? '',
      classeId: d['classeId'] as String? ?? '',
      classeNom: d['classeNom'] as String? ?? '',
      devoirTitre: d['devoirTitre'] as String? ?? '',
      assignmentId: d['assignmentId'] as String? ?? '',
      teacherId: d['teacherId'] as String? ?? '',
      fileUrl: d['fileUrl'] as String? ?? '',
      fileType: d['fileType'] as String? ?? '',
      comment: d['comment'] as String? ?? '',
      textReponse: d['textReponse'] as String? ?? '',
      piecesJointes: rawPJ
          .map<Map<String, String>>((e) => Map<String, String>.from(
              (e as Map).map((k, v) =>
                  MapEntry(k.toString(), v.toString()))))
          .toList(),
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: SubmissionStatusX.fromString(d['status'] as String?),
      grade: (d['grade'] as num?)?.toDouble(),
      teacherComment: d['teacherComment'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'schoolId': schoolId,
        'studentId': studentId,
        'studentEmail': studentEmail,
        if (studentNom.isNotEmpty) 'studentNom': studentNom,
        if (classeId.isNotEmpty) 'classeId': classeId,
        if (classeNom.isNotEmpty) 'classeNom': classeNom,
        if (devoirTitre.isNotEmpty) 'devoirTitre': devoirTitre,
        'assignmentId': assignmentId,
        'teacherId': teacherId,
        'fileUrl': fileUrl,
        'fileType': fileType,
        'comment': comment,
        if (textReponse.isNotEmpty) 'textReponse': textReponse,
        'piecesJointes': piecesJointes,
        'createdAt': Timestamp.fromDate(createdAt),
        'status': status.value,
        if (grade != null) 'grade': grade,
        if (teacherComment != null) 'teacherComment': teacherComment,
      };
}
