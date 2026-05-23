import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class SocialService {
  static final _db = FirebaseDatabase.instance.ref();

  static String get me => FirebaseAuth.instance.currentUser?.email ?? '';

  static String chatId(String a, String b) {
    if (a == 'general' || b == 'general') return 'general';
    if (a == 'Classe' || b == 'Classe') return 'Classe';
    final pair = [a, b]..sort();
    return pair.join('__');
  }

  // ─── Présence ─────────────────────────────────────────────────────────────

  static Future<void> goOnline() async {
    final u = me;
    if (u.isEmpty) return;
    await _db.child('users/$u').update({'name': u});
    await _db.child('status/$u').set({
      'online': true,
      'lastSeen': DateTime.now().millisecondsSinceEpoch,
    });
    _db.child('status/$u').onDisconnect().set({
      'online': false,
      'lastSeen': ServerValue.timestamp,
    });
  }

  static Future<void> goOffline() async {
    final u = me;
    if (u.isEmpty) return;
    await _db.child('status/$u').update({
      'online': false,
      'lastSeen': DateTime.now().millisecondsSinceEpoch,
    });
  }

  static Stream<bool> onlineStream(String user) {
    return _db.child('status/$user/online').onValue
        .map((e) => e.snapshot.value == true);
  }

  static Future<int?> lastSeen(String user) async {
    final snap = await _db.child('status/$user/lastSeen').get();
    return snap.value as int?;
  }

  // ─── Messages ─────────────────────────────────────────────────────────────

  static Stream<List<Map<String, dynamic>>> messagesStream(String cId) {
    return _db.child('messages/$cId').limitToLast(100).onValue.map((e) {
      if (e.snapshot.value == null) return [];
      final raw = Map<dynamic, dynamic>.from(e.snapshot.value as Map);
      final list = raw.values
          .map((v) => Map<String, dynamic>.from(v as Map))
          .toList()
        ..sort((a, b) => (a['time'] as int? ?? 0).compareTo(b['time'] as int? ?? 0));
      return list;
    });
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
      await _db.child('notifications/$toUser').push().set({
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
    return _db.child('users/$user/contacts').onValue.map((e) {
      if (e.snapshot.value == null) return [];
      return List<String>.from(
          Map<dynamic, dynamic>.from(e.snapshot.value as Map).keys);
    });
  }

  static Future<void> addContact(String owner, String contact) async {
    await _db.child('users/$contact').update({'name': contact});
    await _db.child('users/$owner/contacts/$contact').set(true);
  }

  // ─── Amis ─────────────────────────────────────────────────────────────────

  static Stream<List<String>> friendsStream(String user) {
    return _db.child('friends/$user').onValue.map((e) {
      if (e.snapshot.value == null) return [];
      return List<String>.from(
          Map<dynamic, dynamic>.from(e.snapshot.value as Map).keys);
    });
  }

  static Stream<List<String>> requestsStream(String user) {
    return _db.child('friend_requests/$user').onValue.map((e) {
      if (e.snapshot.value == null) return [];
      return List<String>.from(
          Map<dynamic, dynamic>.from(e.snapshot.value as Map).keys);
    });
  }

  static Stream<List<String>> allUsersStream(String excludeUser) {
    return _db.child('users').onValue.map((e) {
      if (e.snapshot.value == null) return [];
      return List<String>.from(
          Map<dynamic, dynamic>.from(e.snapshot.value as Map)
              .keys
              .where((k) => k != excludeUser));
    });
  }

  static Future<void> sendFriendRequest(String from, String to) async {
    await _db.child('friend_requests/$to/$from').set(true);
  }

  static Future<void> acceptRequest(String viewer, String from) async {
    await _db.child('friends/$viewer/$from').set(true);
    await _db.child('friends/$from/$viewer').set(true);
    await _db.child('friend_requests/$viewer/$from').remove();
  }

  static Future<void> rejectRequest(String viewer, String from) async {
    await _db.child('friend_requests/$viewer/$from').remove();
  }

  static Future<void> removeFriend(String a, String b) async {
    await _db.child('friends/$a/$b').remove();
    await _db.child('friends/$b/$a').remove();
  }

  // ─── Blocage ──────────────────────────────────────────────────────────────

  static Future<void> blockUser(String blocker, String target) async {
    await _db.child('blocked/$blocker/$target').set(true);
    await removeFriend(blocker, target);
  }

  static Future<void> unblockUser(String blocker, String target) async {
    await _db.child('blocked/$blocker/$target').remove();
  }

  static Future<bool> isBlocked(String by, String target) async {
    final snap = await _db.child('blocked/$by/$target').get();
    return snap.value == true;
  }

  // ─── Professeurs ──────────────────────────────────────────────────────────

  static Stream<List<Map<String, dynamic>>> profsStream() {
    return _db.child('professeurs').onValue.map((e) {
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
    });
  }

  static Future<void> addProf(String currentUser, String name, String matiere) async {
    await _db.child('professeurs/$name').set({'name': name, 'matiere': matiere});
    await _db.child('users/$currentUser/contacts/$name').set(true);
  }

  static Future<void> removeProf(String currentUser, String name) async {
    await _db.child('professeurs/$name').remove();
  }
}
