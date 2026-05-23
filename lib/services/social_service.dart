import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class SocialService {
  static final _db = FirebaseDatabase.instance.ref();

  static String get me => FirebaseAuth.instance.currentUser?.email ?? '';

  /// Encode an email for use as an RTDB path segment.
  /// RTDB forbids '.', '#', '$', '[', ']' — replace '.' with ','.
  static String encodeKey(String s) =>
      s.replaceAll('.', ',').replaceAll('#', '_').replaceAll(r'$', '_');

  /// Decode an RTDB key back to the original email.
  static String decodeKey(String s) => s.replaceAll(',', '.');

  static String chatId(String a, String b) {
    if (a == 'general' || b == 'general') return 'general';
    if (a == 'Classe' || b == 'Classe') return 'Classe';
    final pair = [encodeKey(a), encodeKey(b)]..sort();
    return pair.join('__');
  }

  // ─── Présence ─────────────────────────────────────────────────────────────

  static Future<void> goOnline() async {
    final u = me;
    if (u.isEmpty) return;
    final k = encodeKey(u);
    await _db.child('users/$k').update({'name': u});
    await _db.child('status/$k').set({
      'online': true,
      'lastSeen': DateTime.now().millisecondsSinceEpoch,
    });
    _db.child('status/$k').onDisconnect().set({
      'online': false,
      'lastSeen': ServerValue.timestamp,
    });
  }

  static Future<void> goOffline() async {
    final u = me;
    if (u.isEmpty) return;
    final k = encodeKey(u);
    await _db.child('status/$k').update({
      'online': false,
      'lastSeen': DateTime.now().millisecondsSinceEpoch,
    });
  }

  static Stream<bool> onlineStream(String user) {
    final k = encodeKey(user);
    return _db
        .child('status/$k/online')
        .onValue
        .map<bool>((e) => e.snapshot.value == true)
        .asBroadcastStream();
  }

  static Future<int?> lastSeen(String user) async {
    final snap =
        await _db.child('status/${encodeKey(user)}/lastSeen').get();
    return snap.value as int?;
  }

  // ─── Messages ─────────────────────────────────────────────────────────────

  static Stream<List<Map<String, dynamic>>> messagesStream(String cId) {
    return _db
        .child('messages/$cId')
        .limitToLast(100)
        .onValue
        .map<List<Map<String, dynamic>>>((e) {
          if (e.snapshot.value == null) return [];
          final raw = Map<dynamic, dynamic>.from(e.snapshot.value as Map);
          final list = raw.values
              .map((v) => Map<String, dynamic>.from(v as Map))
              .toList()
            ..sort((a, b) =>
                (a['time'] as int? ?? 0).compareTo(b['time'] as int? ?? 0));
          return list;
        })
        .asBroadcastStream();
  }

  static Future<void> sendMessage({
    required String chatIdStr,
    required String sender,
    required String toUser,
    required String text,
  }) async {
    final time = DateTime.now().millisecondsSinceEpoch;
    await _db.child('messages/$chatIdStr').push().set({
      'text': text,
      'sender': sender,
      'time': time,
      'seen': false,
    });
    if (toUser != 'general' && toUser != 'Classe') {
      final k = encodeKey(toUser);
      await _db.child('notifications/$k').push().set({
        'title': sender,
        'body': text,
        'time': time,
      });
    }
  }

  static Future<void> markSeen(String chatIdStr, String viewer) async {
    final snap = await _db.child('messages/$chatIdStr').get();
    if (!snap.exists) return;
    final data = Map<dynamic, dynamic>.from(snap.value as Map);
    for (final e in data.entries) {
      final msg = Map<dynamic, dynamic>.from(e.value as Map);
      if (msg['sender'] != viewer && msg['seen'] != true) {
        await _db.child('messages/$chatIdStr/${e.key}/seen').set(true);
      }
    }
  }

  // ─── Contacts ─────────────────────────────────────────────────────────────

  static Stream<List<String>> contactsStream(String user) {
    final k = encodeKey(user);
    return _db
        .child('users/$k/contacts')
        .onValue
        .map<List<String>>((e) {
          if (e.snapshot.value == null) return [];
          return Map<dynamic, dynamic>.from(e.snapshot.value as Map)
              .keys
              .map((key) => decodeKey(key.toString()))
              .toList();
        })
        .asBroadcastStream();
  }

  static Future<void> addContact(String owner, String contact) async {
    final kContact = encodeKey(contact);
    final kOwner = encodeKey(owner);
    await _db.child('users/$kContact').update({'name': contact});
    await _db.child('users/$kOwner/contacts/$kContact').set(true);
  }

  // ─── Amis ─────────────────────────────────────────────────────────────────

  static Stream<List<String>> friendsStream(String user) {
    final k = encodeKey(user);
    return _db
        .child('friends/$k')
        .onValue
        .map<List<String>>((e) {
          if (e.snapshot.value == null) return [];
          return Map<dynamic, dynamic>.from(e.snapshot.value as Map)
              .keys
              .map((key) => decodeKey(key.toString()))
              .toList();
        })
        .asBroadcastStream();
  }

  static Stream<List<String>> requestsStream(String user) {
    final k = encodeKey(user);
    return _db
        .child('friend_requests/$k')
        .onValue
        .map<List<String>>((e) {
          if (e.snapshot.value == null) return [];
          return Map<dynamic, dynamic>.from(e.snapshot.value as Map)
              .keys
              .map((key) => decodeKey(key.toString()))
              .toList();
        })
        .asBroadcastStream();
  }

  static Stream<List<String>> allUsersStream(String excludeUser) {
    final kExclude = encodeKey(excludeUser);
    return _db
        .child('users')
        .onValue
        .map<List<String>>((e) {
          if (e.snapshot.value == null) return [];
          return Map<dynamic, dynamic>.from(e.snapshot.value as Map)
              .keys
              .where((k) => k != kExclude)
              .map((key) => decodeKey(key.toString()))
              .toList();
        })
        .asBroadcastStream();
  }

  static Future<void> sendFriendRequest(String from, String to) async {
    await _db
        .child('friend_requests/${encodeKey(to)}/${encodeKey(from)}')
        .set(true);
  }

  static Future<void> acceptRequest(String viewer, String from) async {
    final kViewer = encodeKey(viewer);
    final kFrom = encodeKey(from);
    await _db.child('friends/$kViewer/$kFrom').set(true);
    await _db.child('friends/$kFrom/$kViewer').set(true);
    await _db.child('friend_requests/$kViewer/$kFrom').remove();
  }

  static Future<void> rejectRequest(String viewer, String from) async {
    await _db
        .child('friend_requests/${encodeKey(viewer)}/${encodeKey(from)}')
        .remove();
  }

  static Future<void> removeFriend(String a, String b) async {
    final ka = encodeKey(a);
    final kb = encodeKey(b);
    await _db.child('friends/$ka/$kb').remove();
    await _db.child('friends/$kb/$ka').remove();
  }

  // ─── Blocage ──────────────────────────────────────────────────────────────

  static Future<void> blockUser(String blocker, String target) async {
    await _db
        .child('blocked/${encodeKey(blocker)}/${encodeKey(target)}')
        .set(true);
    await removeFriend(blocker, target);
  }

  static Future<void> unblockUser(String blocker, String target) async {
    await _db
        .child('blocked/${encodeKey(blocker)}/${encodeKey(target)}')
        .remove();
  }

  static Future<bool> isBlocked(String by, String target) async {
    final snap = await _db
        .child('blocked/${encodeKey(by)}/${encodeKey(target)}')
        .get();
    return snap.value == true;
  }

  // ─── Professeurs (legacy RTDB) ─────────────────────────────────────────────

  static Stream<List<Map<String, dynamic>>> profsStream() {
    return _db
        .child('professeurs')
        .onValue
        .map<List<Map<String, dynamic>>>((e) {
          if (e.snapshot.value == null) return [];
          return Map<dynamic, dynamic>.from(e.snapshot.value as Map)
              .entries
              .map((en) {
                final data = en.value is Map
                    ? Map<String, dynamic>.from(en.value as Map)
                    : <String, dynamic>{'name': en.key.toString()};
                data['id'] = en.key.toString();
                return data;
              })
              .toList();
        })
        .asBroadcastStream();
  }

  static Future<void> addProf(
      String currentUser, String name, String matiere) async {
    await _db
        .child('professeurs/$name')
        .set({'name': name, 'matiere': matiere});
    await _db
        .child('users/${encodeKey(currentUser)}/contacts/${encodeKey(name)}')
        .set(true);
  }

  static Future<void> removeProf(String currentUser, String name) async {
    await _db.child('professeurs/$name').remove();
  }
}
