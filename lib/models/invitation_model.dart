import 'package:cloud_firestore/cloud_firestore.dart';

/// Code d'invitation à usage unique, généré par un directeur pour un enseignant.
/// Stocké dans Firestore : teacher_invitations/{id}
class TeacherInvitation {
  final String id;
  final String code;
  final String schoolId;
  final String schoolNom;
  final String directorUid;
  /// UID de l'enseignant ciblé (peut être vide si code générique)
  final String teacherUid;
  final String teacherEmail;
  final String teacherName;
  final DateTime expiresAt;
  final bool used;
  final bool revoked;
  final DateTime? usedAt;
  final DateTime createdAt;

  const TeacherInvitation({
    required this.id,
    required this.code,
    required this.schoolId,
    required this.schoolNom,
    required this.directorUid,
    this.teacherUid = '',
    this.teacherEmail = '',
    this.teacherName = '',
    required this.expiresAt,
    this.used = false,
    this.revoked = false,
    this.usedAt,
    required this.createdAt,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);
  bool get isValid => !used && !revoked && !isExpired;

  String get statusLabel {
    if (used) return 'Utilisé';
    if (revoked) return 'Révoqué';
    if (isExpired) return 'Expiré';
    return 'En attente';
  }

  factory TeacherInvitation.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return TeacherInvitation(
      id: doc.id,
      code: d['code'] as String? ?? '',
      schoolId: d['schoolId'] as String? ?? '',
      schoolNom: d['schoolNom'] as String? ?? '',
      directorUid: d['directorUid'] as String? ?? '',
      teacherUid: d['teacherUid'] as String? ?? '',
      teacherEmail: d['teacherEmail'] as String? ?? '',
      teacherName: d['teacherName'] as String? ?? '',
      expiresAt: (d['expiresAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      used: d['used'] as bool? ?? false,
      revoked: d['revoked'] as bool? ?? false,
      usedAt: (d['usedAt'] as Timestamp?)?.toDate(),
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'code': code,
        'schoolId': schoolId,
        'schoolNom': schoolNom,
        'directorUid': directorUid,
        'teacherUid': teacherUid,
        'teacherEmail': teacherEmail,
        'teacherName': teacherName,
        'expiresAt': Timestamp.fromDate(expiresAt),
        'used': used,
        'revoked': revoked,
        'createdAt': FieldValue.serverTimestamp(),
      };
}
