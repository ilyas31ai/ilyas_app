import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

/// Page d'aperçu plein écran pour un document PDF (sélection locale ou
/// dossier déjà sauvegardé), réutilisée par l'import et la validation.
class PdfPreviewPage extends StatelessWidget {
  final String title;
  final Future<Uint8List> Function() loader;

  const PdfPreviewPage({super.key, required this.title, required this.loader});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        elevation: 0,
        title: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white, fontSize: 15),
        ),
      ),
      body: PdfPreview(
        build: (format) => loader(),
        canChangeOrientation: false,
        canChangePageFormat: false,
        canDebug: false,
        loadingWidget: const Center(
          child: CircularProgressIndicator(color: Color(0xFF2563EB)),
        ),
      ),
    );
  }
}
