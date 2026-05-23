import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/chat_conversation.dart';
import '../models/chat_message.dart';

class ChatIaService {
  static final _db = FirebaseFirestore.instance;

  static String? get _userId => FirebaseAuth.instance.currentUser?.uid;

  static CollectionReference<Map<String, dynamic>>? get _conversations {
    final uid = _userId;
    if (uid == null) return null;
    return _db.collection('chat_ia').doc(uid).collection('conversations');
  }

  // ─── Conversations ────────────────────────────────────────────────────────

  static Future<String?> createConversation({
    required String level,
    required String subject,
  }) async {
    final ref = _conversations;
    if (ref == null) return null;
    final now = DateTime.now();
    final doc = await ref.add({
      'title': '$subject · $level',
      'level': level,
      'subject': subject,
      'createdAt': Timestamp.fromDate(now),
      'updatedAt': Timestamp.fromDate(now),
      'lastMessage': '',
    });
    return doc.id;
  }

  static Stream<List<ChatConversation>> conversationsStream() {
    final ref = _conversations;
    if (ref == null) return Stream.value([]);
    return ref
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => ChatConversation.fromFirestore(d)).toList());
  }

  static Future<void> updateTitle(String convId, String title) async {
    await _conversations?.doc(convId).update({'title': title});
  }

  static Future<void> deleteConversation(String convId) async {
    final ref = _conversations;
    if (ref == null) return;
    final msgs = await ref.doc(convId).collection('messages').get();
    final batch = _db.batch();
    for (final doc in msgs.docs) {
      batch.delete(doc.reference);
    }
    batch.delete(ref.doc(convId));
    await batch.commit();
  }

  // ─── Messages ─────────────────────────────────────────────────────────────

  static Stream<List<ChatMessage>> messagesStream(String convId) {
    final ref = _conversations;
    if (ref == null) return Stream.value([]);
    return ref
        .doc(convId)
        .collection('messages')
        .orderBy('timestamp')
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => ChatMessage.fromFirestore(d)).toList());
  }

  static Future<void> addMessage({
    required String convId,
    required String content,
    required bool isUser,
  }) async {
    final ref = _conversations;
    if (ref == null) return;
    final now = DateTime.now();
    await ref.doc(convId).collection('messages').add({
      'content': content,
      'isUser': isUser,
      'timestamp': Timestamp.fromDate(now),
    });
    final preview = content.length > 80 ? '${content.substring(0, 80)}…' : content;
    await ref.doc(convId).update({
      'lastMessage': preview,
      'updatedAt': Timestamp.fromDate(now),
    });
  }
}
