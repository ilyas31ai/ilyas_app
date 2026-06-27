import 'dart:io';
import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

class StorageService {
  static final _storage = FirebaseStorage.instanceFor(bucket: 'gs://ilyasapp-4762c.firebasestorage.app');
  static String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  static String _token() {
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rng = Random.secure();
    return List.generate(36, (_) => chars[rng.nextInt(chars.length)]).join();
  }

  static Future<String?> uploadProfilePhoto(File file) async {
    final uid = _uid;
    if (uid.isEmpty) return null;
    final token = _token();
    final ref = _storage.ref().child('profile_photos/$uid.jpg');
    final task = await ref.putFile(
      file,
      SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: {'firebaseStorageDownloadTokens': token},
      ),
    );
    if (task.state == TaskState.success) {
      final bucket      = task.ref.bucket;
      final encodedPath = Uri.encodeComponent(task.ref.fullPath);
      return 'https://firebasestorage.googleapis.com/v0/b/$bucket/o/$encodedPath?alt=media&token=$token';
    }
    return null;
  }
}
