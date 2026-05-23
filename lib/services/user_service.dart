import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';

class UserService {
  static final _db = FirebaseFirestore.instance;

  static String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';
  static String get _email => FirebaseAuth.instance.currentUser?.email ?? '';

  /// Create profile on first signup, update lastSeen on subsequent logins.
  /// Silently ignores transient Firestore errors.
  static Future<void> syncProfile({UserRole? role}) async {
    final uid = _uid;
    final email = _email;
    if (uid.isEmpty || email.isEmpty) return;

    try {
      final ref = _db.collection('users').doc(uid);
      final snap = await ref.get();

      if (snap.exists) {
        await ref.update({'lastSeen': FieldValue.serverTimestamp()});
      } else {
        final displayName =
            email.contains('@') ? email.split('@').first : email;
        await ref.set({
          'uid': uid,
          'email': email,
          'displayName': displayName,
          'role': (role ?? UserRole.eleve).value,
          'createdAt': FieldValue.serverTimestamp(),
          'lastSeen': FieldValue.serverTimestamp(),
        });
      }
    } catch (_) {
      // Transient network error — will retry on next launch
    }
  }

  /// Stream of the current authenticated user's profile.
  static Stream<UserModel?> currentUserStream() {
    final uid = _uid;
    if (uid.isEmpty) return Stream.value(null);
    return _db
        .collection('users')
        .doc(uid)
        .snapshots()
        .map<UserModel?>(
            (snap) => snap.exists ? UserModel.fromDoc(snap) : null)
        .asBroadcastStream();
  }

  /// All registered users except the current one.
  static Stream<List<UserModel>> allUsersStream() {
    final uid = _uid;
    return _db
        .collection('users')
        .snapshots()
        .map<List<UserModel>>((snap) => snap.docs
            .where((d) => d.id != uid)
            .map((d) => UserModel.fromDoc(d))
            .toList())
        .asBroadcastStream();
  }

  /// Users filtered by role ('eleve', 'professeur', 'admin').
  static Stream<List<UserModel>> usersByRoleStream(String role) {
    return _db
        .collection('users')
        .where('role', isEqualTo: role)
        .snapshots()
        .map<List<UserModel>>(
            (snap) => snap.docs.map((d) => UserModel.fromDoc(d)).toList())
        .asBroadcastStream();
  }

  /// Update fields on the current user's profile document.
  static Future<void> updateProfile(Map<String, dynamic> data) async {
    final uid = _uid;
    if (uid.isEmpty) return;
    await _db.collection('users').doc(uid).update(data);
  }
}
