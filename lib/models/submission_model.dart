import 'package:cloud_firestore/cloud_firestore.dart';

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
  final String studentId;
  final String studentEmail;
  final String assignmentId;
  final String teacherId;
  final String fileUrl;
  final String fileType;
  final String comment;
  final DateTime createdAt;
  final SubmissionStatus status;
  final double? grade;
  final String? teacherComment;

  const SubmissionModel({
    required this.id,
    required this.studentId,
    required this.studentEmail,
    required this.assignmentId,
    required this.teacherId,
    this.fileUrl = '',
    this.fileType = '',
    this.comment = '',
    required this.createdAt,
    this.status = SubmissionStatus.pending,
    this.grade,
    this.teacherComment,
  });

  factory SubmissionModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return SubmissionModel(
      id: doc.id,
      studentId: d['studentId'] as String? ?? '',
      studentEmail: d['studentEmail'] as String? ?? '',
      assignmentId: d['assignmentId'] as String? ?? '',
      teacherId: d['teacherId'] as String? ?? '',
      fileUrl: d['fileUrl'] as String? ?? '',
      fileType: d['fileType'] as String? ?? '',
      comment: d['comment'] as String? ?? '',
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: SubmissionStatusX.fromString(d['status'] as String?),
      grade: (d['grade'] as num?)?.toDouble(),
      teacherComment: d['teacherComment'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'studentId': studentId,
        'studentEmail': studentEmail,
        'assignmentId': assignmentId,
        'teacherId': teacherId,
        'fileUrl': fileUrl,
        'fileType': fileType,
        'comment': comment,
        'createdAt': Timestamp.fromDate(createdAt),
        'status': status.value,
        if (grade != null) 'grade': grade,
        if (teacherComment != null) 'teacherComment': teacherComment,
      };
}
