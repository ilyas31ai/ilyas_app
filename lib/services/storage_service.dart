import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

class StorageService {
  static final _storage = FirebaseStorage.instance;
  static String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  static Future<String?> uploadProfilePhoto(File file) async {
    final uid = _uid;
    if (uid.isEmpty) return null;
    final ref = _storage.ref().child('profile_photos/$uid.jpg');
    final task = await ref.putFile(
      file,
      SettableMetadata(contentType: 'image/jpeg'),
    );
    if (task.state == TaskState.success) {
      return await ref.getDownloadURL();
    }
    return null;
  }
}
