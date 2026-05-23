import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

class ProfileService {
  static Future<String?> uploadImage(String userId) async {
    final picker = ImagePicker();

    final picked =
        await picker.pickImage(source: ImageSource.gallery);

    if (picked == null) return null;

    final file = File(picked.path);

    final ref =
        FirebaseStorage.instance.ref("profiles/$userId.jpg");

    await ref.putFile(file);

    return await ref.getDownloadURL();
  }
}