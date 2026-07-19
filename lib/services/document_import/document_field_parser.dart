import '../../models/student_import_result.dart';

/// Un "modèle" de reconnaissance des champs élève/parents à partir du texte
/// brut renvoyé par l'OCR.
///
/// L'architecture accepte plusieurs implémentations en parallèle (un
/// établissement peut utiliser un formulaire différent d'un autre) : voir
/// [StudentDocumentParsing.parseWithBestParser], qui essaie chaque parseur
/// enregistré et retient celui ayant reconnu le plus de champs. Ajouter un
/// nouveau modèle de document ne nécessite donc qu'une nouvelle classe
/// implémentant cette interface, sans modifier le reste du pipeline.
abstract class DocumentFieldParser {
  /// Nom court identifiant ce modèle (diagnostic, logs).
  String get name;

  StudentImportResult parse(String rawText);
}

/// Essaie plusieurs [DocumentFieldParser] sur le même texte et retient le
/// résultat ayant reconnu le plus de champs.
class StudentDocumentParsing {
  static StudentImportResult parseWithBestParser(
    String rawText,
    List<DocumentFieldParser> parsers,
  ) {
    StudentImportResult? best;
    for (final parser in parsers) {
      final result = parser.parse(rawText);
      if (best == null || result.champsReconnus > best.champsReconnus) {
        best = result;
      }
    }
    return best ?? StudentImportResult(rawText: rawText);
  }
}
