import 'package:flutter/material.dart';
import '../models/inscription_model.dart';

class PdfImportTile extends StatelessWidget {
  final Inscription inscription;
  final VoidCallback? onTap;

  const PdfImportTile({super.key, required this.inscription, this.onTap});

  Color get _statutColor {
    switch (inscription.statut) {
      case InscriptionStatut.brouillon:
        return const Color(0xFFD97706);
      case InscriptionStatut.enAttente:
        return const Color(0xFF6C47FF);
      case InscriptionStatut.validee:
        return const Color(0xFF16A34A);
      case InscriptionStatut.refusee:
        return const Color(0xFFDC2626);
    }
  }

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  @override
  Widget build(BuildContext context) {
    final color = _statutColor;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF161B22),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFDC2626).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.picture_as_pdf_outlined,
                  color: Color(0xFFDC2626), size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    inscription.pdfName.isEmpty
                        ? 'document.pdf'
                        : inscription.pdfName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 13),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Importé le ${_formatDate(inscription.dateImport)}'
                    '${inscription.nomCompletEleve.isNotEmpty ? ' · ${inscription.nomCompletEleve}' : ''}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                inscription.statut.label,
                style: TextStyle(
                    color: color, fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
