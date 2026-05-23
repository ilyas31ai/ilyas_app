import 'package:cloud_firestore/cloud_firestore.dart';

class ChatConversation {
  final String id;
  final String title;
  final String level;
  final String subject;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String lastMessage;

  const ChatConversation({
    required this.id,
    required this.title,
    required this.level,
    required this.subject,
    required this.createdAt,
    required this.updatedAt,
    required this.lastMessage,
  });

  factory ChatConversation.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ChatConversation(
      id: doc.id,
      title: data['title'] as String? ?? 'Conversation',
      level: data['level'] as String? ?? '',
      subject: data['subject'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
      lastMessage: data['lastMessage'] as String? ?? '',
    );
  }

  Map<String, dynamic> toFirestore() => {
        'title': title,
        'level': level,
        'subject': subject,
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': Timestamp.fromDate(updatedAt),
        'lastMessage': lastMessage,
      };
}
