import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:printing/printing.dart';

/// Convertit les pages d'un PDF quelconque (pas seulement ceux générés par
/// le package `pdf`) en images PNG, pour qu'elles puissent être passées à
/// un [OcrEngine]. Utilise `printing` (déjà une dépendance du projet, basé
/// sur pdfium), 100% local — aucun envoi réseau.
class PdfPageRenderer {
  /// Rend au plus [maxPages] pages du PDF en images PNG. `dpi` contrôle la
  /// résolution du rendu : plus élevé améliore la reconnaissance de texte
  /// mais ralentit le traitement.
  static Future<List<Uint8List>> renderPages(
    Uint8List pdfBytes, {
    double dpi = 200,
    int maxPages = 5,
  }) async {
    final images = <Uint8List>[];
    await for (final page in Printing.raster(pdfBytes, dpi: dpi)) {
      images.add(await _flattenToOpaquePng(page));
      if (images.length >= maxPages) break;
    }
    return images;
  }

  /// [PdfRaster.toPng] encode directement les pixels rendus sans les
  /// composer sur un fond opaque. Sur Android, les zones non peintes du PDF
  /// gardent alpha=0 avec un RGB hérité du buffer natif (souvent noir) : le
  /// PNG obtenu s'affiche normalement dans un lecteur qui composite déjà
  /// sur blanc par défaut, mais un moteur OCR qui lit les pixels bruts n'y
  /// voit alors aucun contraste réel (texte et fond tous deux "noirs" une
  /// fois l'alpha ignoré) — d'où 0 caractère détecté malgré une image
  /// visuellement correcte. On aplatit donc explicitement sur fond blanc
  /// avant l'OCR.
  static Future<Uint8List> _flattenToOpaquePng(PdfRaster page) async {
    final image = await page.toImage();
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.drawColor(const ui.Color(0xFFFFFFFF), ui.BlendMode.src);
    canvas.drawImage(image, ui.Offset.zero, ui.Paint());
    final picture = recorder.endRecording();
    final flattened = await picture.toImage(image.width, image.height);
    final data = await flattened.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  }
}
