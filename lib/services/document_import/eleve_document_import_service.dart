import 'dart:typed_data';

import '../../models/student_import_result.dart';
import 'document_field_parser.dart';
import 'mlkit_ocr_engine.dart';
import 'ocr_engine.dart';
import 'pdf_page_renderer.dart';
import 'regex_student_field_parser.dart';

/// Point d'entrée unique du pipeline d'import de dossier élève.
///
/// Conçu pour accepter plusieurs sources de document sans changer d'API :
/// - [extractFromPdf] aujourd'hui (dossier scanné en PDF) ;
/// - [extractFromImages] déjà disponible pour une évolution future (photos
///   de formulaires papier, images prises à l'appareil photo) — un PDF
///   n'est qu'un cas particulier qui passe d'abord par [PdfPageRenderer].
///
/// Le moteur OCR ([OcrEngine]) et les modèles de reconnaissance
/// ([DocumentFieldParser]) sont injectables : remplacer l'OCR local par une
/// IA distante plus tard ne nécessite qu'une nouvelle implémentation
/// d'[OcrEngine], sans toucher à cette classe ni à l'UI.
class EleveDocumentImportService {
  final OcrEngine ocrEngine;
  final List<DocumentFieldParser> parsers;

  EleveDocumentImportService({
    OcrEngine? ocrEngine,
    List<DocumentFieldParser>? parsers,
  })  : ocrEngine = ocrEngine ?? MlKitOcrEngine(),
        parsers = parsers ?? [RegexStudentFieldParser()];

  /// Extrait les champs élève/parents à partir d'un PDF (dossier
  /// d'inscription scanné). Rend les premières pages en images puis
  /// applique l'OCR + le meilleur parseur disponible.
  Future<StudentImportResult> extractFromPdf(Uint8List pdfBytes) async {
    final images = await PdfPageRenderer.renderPages(pdfBytes, maxPages: 5);
    return extractFromImages(images);
  }

  /// Extrait les champs à partir d'une ou plusieurs images déjà décodées
  /// (photo de formulaire papier, capture caméra…) — même pipeline OCR +
  /// parsing que pour un PDF, réutilisable tel quel pour les évolutions
  /// prévues par la spécification.
  Future<StudentImportResult> extractFromImages(
      List<Uint8List> images) async {
    final buffer = StringBuffer();
    for (final image in images) {
      final text = await ocrEngine.extractTextFromImage(image);
      buffer.writeln(text);
    }
    final rawText = buffer.toString();
    return StudentDocumentParsing.parseWithBestParser(rawText, parsers);
  }

  Future<void> dispose() => ocrEngine.dispose();
}
