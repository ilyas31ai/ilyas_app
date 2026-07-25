import 'dart:io';
import 'dart:typed_data';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path_provider/path_provider.dart';

import 'ocr_engine.dart';

/// OCR local via Google ML Kit Text Recognition (traitement 100% sur
/// l'appareil — aucune image ni texte n'est envoyé à un serveur distant).
/// Nécessite d'écrire l'image dans un fichier temporaire : l'API ML Kit ne
/// décode pas un buffer PNG/JPEG directement, seulement un chemin de
/// fichier ou un buffer YUV brut avec métadonnées caméra.
class MlKitOcrEngine implements OcrEngine {
  final TextRecognizer _recognizer =
      TextRecognizer(script: TextRecognitionScript.latin);

  @override
  Future<String> extractTextFromImage(Uint8List imageBytes) async {
    final dir = await getTemporaryDirectory();
    final ext = _isJpeg(imageBytes) ? 'jpg' : 'png';
    final file = File(
        '${dir.path}/ocr_${DateTime.now().microsecondsSinceEpoch}.$ext');
    await file.writeAsBytes(imageBytes, flush: true);
    try {
      final input = InputImage.fromFilePath(file.path);
      final result = await _recognizer.processImage(input);
      return result.text;
    } finally {
      try {
        await file.delete();
      } catch (_) {}
    }
  }

  @override
  Future<void> dispose() => _recognizer.close();

  /// Les photos prises à la caméra (`image_picker`) sont des JPEG alors que
  /// les pages de PDF rasterisées ([PdfPageRenderer]) sont des PNG — le
  /// décodeur natif se base surtout sur le contenu, mais on nomme le fichier
  /// temporaire avec la bonne extension par cohérence.
  static bool _isJpeg(Uint8List bytes) =>
      bytes.length > 2 && bytes[0] == 0xFF && bytes[1] == 0xD8;
}
