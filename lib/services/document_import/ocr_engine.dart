import 'dart:typed_data';

/// Abstraction du moteur de reconnaissance de texte (OCR).
///
/// Implémentation actuelle : [MlKitOcrEngine] (ML Kit on-device, aucune
/// donnée envoyée à un service distant). Concevoir tout le pipeline d'import
/// contre cette interface permet de remplacer plus tard le moteur local par
/// une IA plus performante (cloud ou modèle plus lourd) sans toucher au
/// reste du code — seule une nouvelle implémentation de [OcrEngine] serait
/// nécessaire.
abstract class OcrEngine {
  /// Extrait le texte visible d'une image (PNG/JPEG déjà décodée en octets).
  Future<String> extractTextFromImage(Uint8List imageBytes);

  /// Libère les ressources natives du moteur (à appeler une fois le
  /// pipeline d'import terminé).
  Future<void> dispose();
}
