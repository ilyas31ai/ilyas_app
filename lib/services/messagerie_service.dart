import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

import '../models/conversation_model.dart';
import '../models/message_model.dart';
import '../models/user_model.dart';

class MessagerieService {
  static final _db = FirebaseFirestore.instance;
  static final _rtdb = FirebaseDatabase.instance.ref();
  static CollectionReference<Map<String, dynamic>> get _convs =>
      _db.collection('conversations');
  static String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  // ── Conversations ─────────────────────────────────────────────────────────

  static Stream<List<ConversationModel>> conversationsStream() {
    final uid = _uid;
    if (uid.isEmpty) return const Stream.empty();
    return _convs
        .where('participantIds', arrayContains: uid)
        .orderBy('lastMessageAt', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map(ConversationModel.fromFirestore).toList());
  }

  /// Total non lu pour l'utilisateur courant (utile pour badge nav).
  static Stream<int> totalUnreadStream() {
    final uid = _uid;
    if (uid.isEmpty) return const Stream.empty();
    return _convs
        .where('participantIds', arrayContains: uid)
        .snapshots()
        .map((snap) {
      int total = 0;
      for (final doc in snap.docs) {
        final conv = ConversationModel.fromFirestore(doc);
        if (!conv.isArchivedBy(uid)) {
          total += conv.unreadFor(uid);
        }
      }
      return total;
    });
  }

  /// Crée ou retourne une conversation directe entre deux utilisateurs.
  static Future<String> getOrCreateDirect({
    required UserModel me,
    required UserModel other,
  }) async {
    final id = ConversationModel.directId(me.uid, other.uid);
    final doc = await _convs.doc(id).get();
    if (doc.exists) return id;

    final conv = ConversationModel(
      id: id,
      type: ConvType.direct,
      participantIds: [me.uid, other.uid],
      participantNoms: {me.uid: me.displayName, other.uid: other.displayName},
      participantRoles: {
        me.uid: me.role.name,
        other.uid: other.role.name,
      },
      unreadCounts: {me.uid: 0, other.uid: 0},
      createdBy: me.uid,
    );
    await _convs.doc(id).set(conv.toMap());
    return id;
  }

  /// Crée un groupe (classe, équipe, perso…).
  static Future<String> createGroup({
    required UserModel creator,
    required String name,
    required List<UserModel> participants,
    String? classeId,
    String? classeNom,
  }) async {
    final ids = {creator.uid, ...participants.map((u) => u.uid)}.toList();
    final noms = {creator.uid: creator.displayName};
    final roles = {creator.uid: creator.role.name};
    for (final p in participants) {
      noms[p.uid] = p.displayName;
      roles[p.uid] = p.role.name;
    }
    final counts = {for (final id in ids) id: 0};

    final ref = _convs.doc();
    final conv = ConversationModel(
      id: ref.id,
      type: ConvType.group,
      name: name,
      participantIds: ids,
      participantNoms: noms,
      participantRoles: roles,
      unreadCounts: counts,
      classeId: classeId,
      classeNom: classeNom,
      createdBy: creator.uid,
    );
    await ref.set(conv.toMap());
    return ref.id;
  }

  // ── Autorisation Élève ↔ Professeur ──────────────────────────────────────

  /// UIDs des professeurs qu'un élève est autorisé à contacter : le
  /// professeur de sa classe (profId) et tout professeur intervenant dans
  /// son emploi du temps (matières multiples).
  static Future<Set<String>> profsAutorisesPourEleve(UserModel eleve) async {
    final ids = <String>{};
    final profId = eleve.profId ?? '';
    if (profId.isNotEmpty) ids.add(profId);

    final classeNom = eleve.classeNom ?? '';
    if (classeNom.isNotEmpty) {
      try {
        final snap = await _db
            .collection('emplois_du_temps')
            .where('classeNom', isEqualTo: classeNom)
            .get();
        for (final d in snap.docs) {
          final pid = d.data()['professeurId'] as String? ?? '';
          if (pid.isNotEmpty) ids.add(pid);
        }
      } catch (_) {}
    }
    return ids;
  }

  /// UIDs des élèves qu'un professeur est autorisé à contacter : élèves de
  /// ses classes, via plusieurs stratégies de repli cumulées (profId direct,
  /// classes.professeurId + eleveIds, classeNom).
  static Future<Set<String>> elevesAutorisesPourProf(UserModel prof) async {
    final ids = <String>{};
    final uid = prof.uid;
    if (uid.isEmpty) return ids;

    // Approche 1 — profId écrit directement sur le profil élève
    try {
      final snap =
          await _db.collection('users').where('profId', isEqualTo: uid).get();
      for (final d in snap.docs) {
        ids.add(d.id);
      }
    } catch (_) {}

    // Approche 2 — classes dont ce professeur est titulaire
    final classeNoms = <String>{};
    try {
      final snap = await _db
          .collection('classes')
          .where('professeurId', isEqualTo: uid)
          .get();
      for (final d in snap.docs) {
        final data = d.data();
        final nom = data['nom'] as String? ?? '';
        if (nom.isNotEmpty) classeNoms.add(nom);
        final eleveIds = List<String>.from(data['eleveIds'] as List? ?? []);
        ids.addAll(eleveIds.where((e) => e.isNotEmpty));
      }
    } catch (_) {}

    // Approche 3 — élèves rattachés par classeNom (repli si eleveIds absent)
    if (classeNoms.isNotEmpty) {
      try {
        final snap = await _db
            .collection('users')
            .where('role', isEqualTo: 'eleve')
            .where('classeNom', whereIn: classeNoms.take(10).toList())
            .get();
        for (final d in snap.docs) {
          ids.add(d.id);
        }
      } catch (_) {}
    }

    return ids;
  }

  // ── Messages ──────────────────────────────────────────────────────────────

  static Stream<List<MessageModel>> messagesStream(String convId,
      {int limit = 60}) {
    return _convs
        .doc(convId)
        .collection('messages')
        .orderBy('sentAt', descending: false)
        .limitToLast(limit)
        .snapshots()
        .map((snap) =>
            snap.docs.map(MessageModel.fromFirestore).toList());
  }

  static Future<void> sendMessage({
    required String convId,
    required List<String> participantIds,
    required MessageModel message,
  }) async {
    final batch = _db.batch();
    final msgRef = _convs.doc(convId).collection('messages').doc();

    // Add message
    batch.set(msgRef, message.toMap());

    // Update conversation: last message + unread counts
    final unreadUpdate = <String, dynamic>{
      'lastMessage': message.type == 'text'
          ? message.text
          : message.type == 'voice'
              ? '🎤 Message vocal'
              : message.type == 'image'
                  ? '🖼️ Image'
                  : '📎 Fichier',
      'lastMessageType': message.type,
      'lastMessageAt': FieldValue.serverTimestamp(),
      'lastSenderId': message.senderId,
      'lastSenderNom': message.senderNom,
    };
    for (final uid in participantIds) {
      if (uid != message.senderId) {
        unreadUpdate['unreadCounts.$uid'] = FieldValue.increment(1);
      }
    }
    batch.update(_convs.doc(convId), unreadUpdate);

    await batch.commit();
  }

  /// Marque tous les messages comme lus pour l'utilisateur courant.
  static Future<void> markConversationRead(String convId) async {
    final uid = _uid;
    if (uid.isEmpty) return;

    // Reset unread count
    await _convs.doc(convId).update({'unreadCounts.$uid': 0});

    // Marque comme lus les 30 derniers messages non encore lus par cet
    // utilisateur. Firestore ne permet pas de filtrer directement sur
    // "readBy ne contient pas uid" : on récupère les derniers messages puis
    // on filtre côté client avant de les mettre à jour.
    final recent = await _convs
        .doc(convId)
        .collection('messages')
        .orderBy('sentAt', descending: true)
        .limit(30)
        .get();

    final batch = _db.batch();
    for (final doc in recent.docs) {
      final readBy =
          List<String>.from((doc.data()['readBy'] as List?) ?? []);
      if (!readBy.contains(uid)) {
        batch.update(doc.reference, {
          'readBy': FieldValue.arrayUnion([uid])
        });
      }
    }
    await batch.commit();
  }

  /// Supprime (soft delete) un message.
  static Future<void> deleteMessage(
      String convId, String msgId) async {
    await _convs.doc(convId).collection('messages').doc(msgId).update({
      'isDeleted': true,
      'text': '',
      'fileUrl': null,
    });
  }

  /// Épingle un message dans la conversation.
  static Future<void> pinMessage(
      String convId, MessageModel msg, String pinnerNom) async {
    await _convs.doc(convId).update({
      'pinnedMessageId': msg.id,
      'pinnedMessageText': msg.type == 'text' ? msg.text : '📎 Fichier',
      'pinnedMessageSenderNom': pinnerNom,
    });
    await _convs
        .doc(convId)
        .collection('messages')
        .doc(msg.id)
        .update({'isPinned': true});
  }

  /// Désépingle le message actuel.
  static Future<void> unpinMessage(String convId,
      {String? msgId}) async {
    await _convs.doc(convId).update({
      'pinnedMessageId': FieldValue.delete(),
      'pinnedMessageText': FieldValue.delete(),
      'pinnedMessageSenderNom': FieldValue.delete(),
    });
    if (msgId != null) {
      await _convs
          .doc(convId)
          .collection('messages')
          .doc(msgId)
          .update({'isPinned': false});
    }
  }

  /// Archive / désarchive la conversation pour l'utilisateur courant.
  static Future<void> toggleArchive(
      String convId, bool archive) async {
    final uid = _uid;
    if (uid.isEmpty) return;
    await _convs.doc(convId).update({
      'archivedBy': archive
          ? FieldValue.arrayUnion([uid])
          : FieldValue.arrayRemove([uid]),
    });
  }

  /// Quitte un groupe (se retire de la liste des participants).
  static Future<void> leaveGroup(String convId) async {
    final uid = _uid;
    if (uid.isEmpty) return;
    await _convs.doc(convId).update({
      'participantIds': FieldValue.arrayRemove([uid]),
    });
  }

  // ── Typing indicators (RTDB) ──────────────────────────────────────────────

  static Future<void> setTyping(String convId, bool typing) async {
    final uid = _uid;
    if (uid.isEmpty) return;
    final ref = _rtdb.child('typing/$convId/$uid');
    if (typing) {
      await ref.set(ServerValue.timestamp);
    } else {
      await ref.remove();
    }
  }

  /// Stream of UIDs currently typing (excluding self).
  static Stream<List<String>> typingStream(String convId) {
    final uid = _uid;
    return _rtdb.child('typing/$convId').onValue.map((event) {
      if (event.snapshot.value == null) return <String>[];
      final data =
          Map<dynamic, dynamic>.from(event.snapshot.value as Map);
      final now = DateTime.now().millisecondsSinceEpoch;
      return data.entries
          .where((e) {
            if (e.key.toString() == uid) return false;
            final ts = e.value as int? ?? 0;
            return now - ts < 10000; // active in last 10s
          })
          .map((e) => e.key.toString())
          .toList();
    });
  }

  // ── Search ────────────────────────────────────────────────────────────────

  static List<ConversationModel> filterConversations(
      List<ConversationModel> all, String query, String uid) {
    if (query.isEmpty) return all;
    final q = query.toLowerCase();
    return all.where((c) {
      final name = c.displayNameFor(uid).toLowerCase();
      final last = c.lastMessage.toLowerCase();
      return name.contains(q) || last.contains(q);
    }).toList();
  }
}
