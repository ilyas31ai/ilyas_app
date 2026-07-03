import 'package:cloud_firestore/cloud_firestore.dart';

class MessageModel {
  final String id;
  final String senderId;
  final String senderNom;
  final String senderRole;
  final String text;
  final String type; // 'text' | 'image' | 'file' | 'voice'
  final String? fileUrl;
  final String? fileName;
  final int? fileSize; // bytes
  final String? mimeType;
  final int? voiceDuration; // seconds
  final String? replyToId;
  final String? replyToText;
  final String? replyToSenderNom;
  final List<String> readBy; // UIDs who have read this message
  final Timestamp sentAt;
  final bool isDeleted;
  final bool isPinned;

  const MessageModel({
    required this.id,
    required this.senderId,
    required this.senderNom,
    this.senderRole = '',
    required this.text,
    this.type = 'text',
    this.fileUrl,
    this.fileName,
    this.fileSize,
    this.mimeType,
    this.voiceDuration,
    this.replyToId,
    this.replyToText,
    this.replyToSenderNom,
    this.readBy = const [],
    required this.sentAt,
    this.isDeleted = false,
    this.isPinned = false,
  });

  bool isReadBy(String uid) => readBy.contains(uid);

  factory MessageModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return MessageModel(
      id: doc.id,
      senderId: d['senderId'] as String? ?? '',
      senderNom: d['senderNom'] as String? ?? '',
      senderRole: d['senderRole'] as String? ?? '',
      text: d['text'] as String? ?? '',
      type: d['type'] as String? ?? 'text',
      fileUrl: d['fileUrl'] as String?,
      fileName: d['fileName'] as String?,
      fileSize: (d['fileSize'] as num?)?.toInt(),
      mimeType: d['mimeType'] as String?,
      voiceDuration: (d['voiceDuration'] as num?)?.toInt(),
      replyToId: d['replyToId'] as String?,
      replyToText: d['replyToText'] as String?,
      replyToSenderNom: d['replyToSenderNom'] as String?,
      readBy: List<String>.from(d['readBy'] as List? ?? []),
      sentAt: d['sentAt'] as Timestamp? ?? Timestamp.now(),
      isDeleted: d['isDeleted'] as bool? ?? false,
      isPinned: d['isPinned'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
        'senderId': senderId,
        'senderNom': senderNom,
        'senderRole': senderRole,
        'text': text,
        'type': type,
        if (fileUrl != null) 'fileUrl': fileUrl,
        if (fileName != null) 'fileName': fileName,
        if (fileSize != null) 'fileSize': fileSize,
        if (mimeType != null) 'mimeType': mimeType,
        if (voiceDuration != null) 'voiceDuration': voiceDuration,
        if (replyToId != null) 'replyToId': replyToId,
        if (replyToText != null) 'replyToText': replyToText,
        if (replyToSenderNom != null) 'replyToSenderNom': replyToSenderNom,
        'readBy': readBy,
        'sentAt': FieldValue.serverTimestamp(),
        'isDeleted': isDeleted,
        'isPinned': isPinned,
      };
}
