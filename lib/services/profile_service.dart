import 'dart:io';
import 'dart:math';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

class ProfileService {
  static String _token() {
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rng = Random.secure();
    return List.generate(36, (_) => chars[rng.nextInt(chars.length)]).join();
  }

  static Future<String?> uploadImage(String userId) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return null;

    final token = _token();
    final file  = File(picked.path);
    final ref   = FirebaseStorage.instanceFor(bucket: 'gs://ilyasapp-4762c.firebasestorage.app')
        .ref('profiles/$userId.jpg');

    final snap = await ref.putFile(
      file,
      SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: {'firebaseStorageDownloadTokens': token},
      ),
    );

    if (snap.state != TaskState.success) return null;

    final bucket      = snap.ref.bucket;
    final encodedPath = Uri.encodeComponent(snap.ref.fullPath);
    return 'https://firebasestorage.googleapis.com/v0/b/$bucket/o/$encodedPath?alt=media&token=$token';
  }
}
