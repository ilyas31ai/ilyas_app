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

  /// Upload a chat file (PDF, doc, image) to Firebase Storage.
  /// Returns download URL or null on failure.
  static Future<String?> uploadChatFile(File file, String chatId) async {
    final uid = _uid;
    if (uid.isEmpty) return null;
    final token = _token();
    final ext = file.path.split('.').last.toLowerCase();
    final name = '${DateTime.now().millisecondsSinceEpoch}.$ext';
    final ref = _storage.ref().child('chat_files/$chatId/$name');
    try {
      final task = await ref.putFile(file, SettableMetadata(
        customMetadata: {'firebaseStorageDownloadTokens': token},
      ));
      if (task.state == TaskState.success) {
        final bucket = task.ref.bucket;
        final encodedPath = Uri.encodeComponent(task.ref.fullPath);
        return 'https://firebasestorage.googleapis.com/v0/b/$bucket/o/$encodedPath?alt=media&token=$token';
      }
    } catch (_) {}
    return null;
  }

  /// Upload a teacher registration document (diplome, cni, etc.).
  /// Returns download URL or null on failure.
  static Future<String?> uploadTeacherDocument(
      File file, String uid, String docType) async {
    if (uid.isEmpty) return null;
    final token = _token();
    final ext = file.path.split('.').last.toLowerCase();
    final name = '${docType}_${DateTime.now().millisecondsSinceEpoch}.$ext';
    final ref = _storage.ref().child('teacher_docs/$uid/$name');
    try {
      final task = await ref.putFile(file, SettableMetadata(
        customMetadata: {'firebaseStorageDownloadTokens': token},
      ));
      if (task.state == TaskState.success) {
        final bucket = task.ref.bucket;
        final encodedPath = Uri.encodeComponent(task.ref.fullPath);
        return 'https://firebasestorage.googleapis.com/v0/b/$bucket/o/$encodedPath?alt=media&token=$token';
      }
    } catch (_) {}
    return null;
  }

  static Future<String?> uploadDevoirFile(File file, String devoirId) async {
    final uid = _uid;
    if (uid.isEmpty) return null;
    final token = _token();
    final ext = file.path.split('.').last.toLowerCase();
    final name = '${DateTime.now().millisecondsSinceEpoch}.$ext';
    final ref = _storage.ref().child('devoirs/$devoirId/$name');
    try {
      final task = await ref.putFile(file, SettableMetadata(
        customMetadata: {'firebaseStorageDownloadTokens': token},
      ));
      if (task.state == TaskState.success) {
        final bucket = task.ref.bucket;
        final encodedPath = Uri.encodeComponent(task.ref.fullPath);
        return 'https://firebasestorage.googleapis.com/v0/b/$bucket/o/$encodedPath?alt=media&token=$token';
      }
    } catch (_) {}
    return null;
  }

  static Future<String?> uploadSubmissionFile(File file, String assignmentId) async {
    final uid = _uid;
    if (uid.isEmpty) return null;
    final token = _token();
    final ext = file.path.split('.').last.toLowerCase();
    final name = '${DateTime.now().millisecondsSinceEpoch}.$ext';
    final ref = _storage.ref().child('submissions/$uid/$assignmentId/$name');
    try {
      final task = await ref.putFile(file, SettableMetadata(
        customMetadata: {'firebaseStorageDownloadTokens': token},
      ));
      if (task.state == TaskState.success) {
        final bucket = task.ref.bucket;
        final encodedPath = Uri.encodeComponent(task.ref.fullPath);
        return 'https://firebasestorage.googleapis.com/v0/b/$bucket/o/$encodedPath?alt=media&token=$token';
      }
    } catch (_) {}
    return null;
  }

  /// Upload the optional screenshot attached to a support ticket.
  /// Returns download URL or null on failure.
  static Future<String?> uploadSupportScreenshot(
      File file, String ticketId) async {
    final uid = _uid;
    if (uid.isEmpty) return null;
    final token = _token();
    final ext = file.path.split('.').last.toLowerCase();
    final ref = _storage.ref().child('support_screenshots/$uid/$ticketId.$ext');
    try {
      final task = await ref.putFile(file, SettableMetadata(
        customMetadata: {'firebaseStorageDownloadTokens': token},
      ));
      if (task.state == TaskState.success) {
        final bucket = task.ref.bucket;
        final encodedPath = Uri.encodeComponent(task.ref.fullPath);
        return 'https://firebasestorage.googleapis.com/v0/b/$bucket/o/$encodedPath?alt=media&token=$token';
      }
    } catch (_) {}
    return null;
  }

  /// Upload a voice message audio file.
  /// Returns download URL or null on failure.
  static Future<String?> uploadChatAudio(File file, String chatId) async {
    final uid = _uid;
    if (uid.isEmpty) return null;
    final token = _token();
    final name = 'voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
    final ref = _storage.ref().child('chat_audio/$chatId/$name');
    try {
      final task = await ref.putFile(file, SettableMetadata(
        contentType: 'audio/m4a',
        customMetadata: {'firebaseStorageDownloadTokens': token},
      ));
      if (task.state == TaskState.success) {
        final bucket = task.ref.bucket;
        final encodedPath = Uri.encodeComponent(task.ref.fullPath);
        return 'https://firebasestorage.googleapis.com/v0/b/$bucket/o/$encodedPath?alt=media&token=$token';
      }
    } catch (_) {}
    return null;
  }
}
