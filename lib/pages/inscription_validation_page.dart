import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../models/classe_model.dart';
import '../models/inscription_model.dart';
import '../services/inscription_service.dart';
import '../widgets/inscription_card.dart';
import '../widgets/pdf_preview_page.dart';

/// Décision finale de la Direction sur les dossiers vérifiés : accepter,
/// refuser, commenter et consulter le PDF source.
class InscriptionValidationPage extends StatelessWidget {
  const InscriptionValidationPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        elevation: 0,
        title: const Text('Validation des inscriptions',
            style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
      ),
      body: StreamBuilder<List<Inscription>>(
        stream: InscriptionService.pendingStream(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF2563EB)),
            );
          }
          final items = snap.data ?? [];
          if (items.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'Aucun dossier en attente de décision.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white38, fontSize: 13),
                ),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            itemCount: items.length,
            itemBuilder: (_, i) => _ValidationItem(inscription: items[i]),
          );
        },
      ),
    );
  }
}

class _ValidationItem extends StatefulWidget {
  final Inscription inscription;
  const _ValidationItem({required this.inscription});

  @override
  State<_ValidationItem> createState() => _ValidationItemState();
}

class _ValidationItemState extends State<_ValidationItem> {
  bool _busy = false;

  Future<Uint8List> _fetchPdfBytes(String url) async {
    final res = await http.get(Uri.parse(url));
    return res.bodyBytes;
  }

  void _consulterPdf() {
    final i = widget.inscription;
    if (i.pdfUrl.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PdfPreviewPage(
          title: i.pdfName,
          loader: () => _fetchPdfBytes(i.pdfUrl),
        ),
      ),
    );
  }

  Future<void> _decide(bool accepted) async {
    if (_busy) return;

    // Fetch classes for the picker (only when accepting)
    List<ClasseModel> classes = [];
    if (accepted) {
      try {
        final snap = await FirebaseFirestore.instance
            .collection('classes')
            .orderBy('nom')
            .get();
        classes = snap.docs.map(ClasseModel.fromFirestore).toList();
      } catch (_) {}
    }

    if (!mounted) return;

    final commentCtrl = TextEditingController();
    ClasseModel? selectedClasse;
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.07)),
    );

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          backgroundColor: const Color(0xFF161B22),
          title: Text(
            accepted ? 'Accepter ce dossier ?' : 'Refuser ce dossier ?',
            style: const TextStyle(color: Colors.white),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${widget.inscription.nomCompletEleve} · ${widget.inscription.matricule}',
                  style: const TextStyle(color: Colors.white60, fontSize: 13),
                ),
                if (accepted && classes.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  const Text('Affecter une classe',
                      style: TextStyle(color: Colors.white54, fontSize: 12)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D1117),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.1)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<ClasseModel>(
                        value: selectedClasse,
                        isExpanded: true,
                        dropdownColor: const Color(0xFF161B22),
                        hint: const Text('Choisir une classe',
                            style: TextStyle(
                                color: Colors.white38, fontSize: 13)),
                        items: classes
                            .map((c) => DropdownMenuItem(
                                  value: c,
                                  child: Text('${c.nom} — ${c.niveau}',
                                      style: const TextStyle(
                                          color: Colors.white, fontSize: 13)),
                                ))
                            .toList(),
                        onChanged: (v) => setDlgState(() => selectedClasse = v),
                      ),
                    ),
                  ),
                ],
                if (accepted && classes.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 10),
                    child: Text(
                      'Aucune classe disponible — créez une classe depuis l\'espace Professeur.',
                      style: TextStyle(color: Color(0xFFD97706), fontSize: 12),
                    ),
                  ),
                const SizedBox(height: 14),
                TextField(
                  controller: commentCtrl,
                  maxLines: 3,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Commentaire (optionnel)',
                    hintStyle:
                        const TextStyle(color: Colors.white38, fontSize: 13),
                    filled: true,
                    fillColor: const Color(0xFF0D1117),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    border: border,
                    enabledBorder: border,
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFF2563EB)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Retour',
                  style: TextStyle(color: Colors.white60)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(
                accepted ? 'Accepter' : 'Refuser',
                style: TextStyle(
                    color: accepted
                        ? const Color(0xFF16A34A)
                        : const Color(0xFFDC2626),
                    fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
    if (confirm != true || !mounted) return;

    setState(() => _busy = true);
    final comment = commentCtrl.text.trim();
    await InscriptionService.setDecision(
      widget.inscription,
      accepted: accepted,
      commentaire: comment.isEmpty ? null : comment,
      classeId: selectedClasse?.id,
      classeNom: selectedClasse?.nom,
      niveau: selectedClasse?.niveau,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(accepted
          ? 'Dossier accepté${selectedClasse != null ? ' — classe ${selectedClasse!.nom}' : ''}'
          : 'Dossier refusé'),
      backgroundColor:
          accepted ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final i = widget.inscription;
    return InscriptionCard(
      inscription: i,
      trailing: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (i.commentaire.isNotEmpty) ...[
            Text(
              '« ${i.commentaire} »',
              style: const TextStyle(color: Colors.white38, fontSize: 12, fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: 10),
          ],
          Row(
            children: [
              _actionBtn(
                icon: Icons.picture_as_pdf_outlined,
                label: 'PDF',
                color: Colors.white60,
                onTap: _consulterPdf,
              ),
              const SizedBox(width: 8),
              _actionBtn(
                icon: Icons.close,
                label: 'Refuser',
                color: const Color(0xFFDC2626),
                onTap: _busy ? null : () => _decide(false),
              ),
              const SizedBox(width: 8),
              _actionBtn(
                icon: Icons.check,
                label: 'Accepter',
                color: const Color(0xFF16A34A),
                filled: true,
                onTap: _busy ? null : () => _decide(true),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _actionBtn({
    required IconData icon,
    required String label,
    required Color color,
    VoidCallback? onTap,
    bool filled = false,
  }) {
    final active = onTap != null;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: filled ? color.withValues(alpha: 0.18) : Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: filled ? color.withValues(alpha: 0.4) : Colors.white.withValues(alpha: 0.08)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 15, color: active ? color : color.withValues(alpha: 0.35)),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                    color: active ? color : color.withValues(alpha: 0.35),
                    fontSize: 12,
                    fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
