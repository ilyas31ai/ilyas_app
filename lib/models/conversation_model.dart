import 'package:cloud_firestore/cloud_firestore.dart';

/// Type de conversation.
enum ConvType {
  direct('direct'),
  group('group');

  const ConvType(this.value);
  final String value;

  static ConvType fromString(String s) =>
      s == 'direct' ? ConvType.direct : ConvType.group;
}

class ConversationModel {
  final String id;
  final ConvType type;
  final String name;
  final List<String> participantIds;
  final Map<String, String> participantNoms;   // uid → displayName
  final Map<String, String> participantRoles;  // uid → role string
  final String lastMessage;
  final String lastMessageType; // 'text'|'image'|'file'|'voice'
  final Timestamp? lastMessageAt;
  final String lastSenderId;
  final String lastSenderNom;
  final Map<String, int> unreadCounts;         // uid → unread count
  final List<String> archivedBy;
  final String? classeId;
  final String? classeNom;
  final String createdBy;
  final Timestamp? createdAt;
  final String? pinnedMessageId;
  final String? pinnedMessageText;
  final String? pinnedMessageSenderNom;

  const ConversationModel({
    required this.id,
    required this.type,
    this.name = '',
    required this.participantIds,
    this.participantNoms = const {},
    this.participantRoles = const {},
    this.lastMessage = '',
    this.lastMessageType = 'text',
    this.lastMessageAt,
    this.lastSenderId = '',
    this.lastSenderNom = '',
    this.unreadCounts = const {},
    this.archivedBy = const [],
    this.classeId,
    this.classeNom,
    this.createdBy = '',
    this.createdAt,
    this.pinnedMessageId,
    this.pinnedMessageText,
    this.pinnedMessageSenderNom,
  });

  /// ID déterministe pour une conversation directe (2 participants).
  static String directId(String uid1, String uid2) {
    final s = [uid1, uid2]..sort();
    return '${s[0]}__${s[1]}';
  }

  /// Nom affiché pour un utilisateur donné.
  String displayNameFor(String uid) {
    if (type == ConvType.direct) {
      final other =
          participantIds.firstWhere((id) => id != uid, orElse: () => '');
      return participantNoms[other] ?? 'Utilisateur';
    }
    return name.isNotEmpty ? name : 'Groupe';
  }

  /// Initiale de l'avatar pour un utilisateur donné.
  String avatarInitialFor(String uid) {
    final dn = displayNameFor(uid);
    return dn.isNotEmpty ? dn[0].toUpperCase() : '?';
  }

  int unreadFor(String uid) => unreadCounts[uid] ?? 0;
  bool isArchivedBy(String uid) => archivedBy.contains(uid);

  factory ConversationModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return ConversationModel(
      id: doc.id,
      type: ConvType.fromString(d['type'] as String? ?? 'direct'),
      name: d['name'] as String? ?? '',
      participantIds: List<String>.from(d['participantIds'] as List? ?? []),
      participantNoms: Map<String, String>.from(
          (d['participantNoms'] as Map? ?? {}).map(
              (k, v) => MapEntry(k.toString(), v.toString()))),
      participantRoles: Map<String, String>.from(
          (d['participantRoles'] as Map? ?? {}).map(
              (k, v) => MapEntry(k.toString(), v.toString()))),
      lastMessage: d['lastMessage'] as String? ?? '',
      lastMessageType: d['lastMessageType'] as String? ?? 'text',
      lastMessageAt: d['lastMessageAt'] as Timestamp?,
      lastSenderId: d['lastSenderId'] as String? ?? '',
      lastSenderNom: d['lastSenderNom'] as String? ?? '',
      unreadCounts: Map<String, int>.from(
          (d['unreadCounts'] as Map? ?? {}).map(
              (k, v) => MapEntry(k.toString(), (v as num).toInt()))),
      archivedBy: List<String>.from(d['archivedBy'] as List? ?? []),
      classeId: d['classeId'] as String?,
      classeNom: d['classeNom'] as String?,
      createdBy: d['createdBy'] as String? ?? '',
      createdAt: d['createdAt'] as Timestamp?,
      pinnedMessageId: d['pinnedMessageId'] as String?,
      pinnedMessageText: d['pinnedMessageText'] as String?,
      pinnedMessageSenderNom: d['pinnedMessageSenderNom'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'type': type.value,
        'name': name,
        'participantIds': participantIds,
        'participantNoms': participantNoms,
        'participantRoles': participantRoles,
        'lastMessage': lastMessage,
        'lastMessageType': lastMessageType,
        'lastMessageAt': lastMessageAt,
        'lastSenderId': lastSenderId,
        'lastSenderNom': lastSenderNom,
        'unreadCounts': unreadCounts,
        'archivedBy': archivedBy,
        'classeId': classeId,
        'classeNom': classeNom,
        'createdBy': createdBy,
        'createdAt': createdAt ?? FieldValue.serverTimestamp(),
        'pinnedMessageId': pinnedMessageId,
        'pinnedMessageText': pinnedMessageText,
        'pinnedMessageSenderNom': pinnedMessageSenderNom,
      };
}
