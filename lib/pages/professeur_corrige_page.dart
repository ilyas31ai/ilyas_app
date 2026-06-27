import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../models/devoir_model.dart';
import '../models/document_model.dart';
import '../services/professeur_service.dart';

class ProfesseurCorrigePage extends StatelessWidget {
  const ProfesseurCorrigePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        elevation: 0,
        title: const Text('Corrigés',
            style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold)),
      ),
      body: StreamBuilder<List<DevoirModel>>(
        stream: ProfesseurService.devoirsStream(),
        builder: (context, devoirSnap) {
          if (devoirSnap.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: Color(0xFF15803D)));
          }
          if (devoirSnap.hasError) {
            return Center(
                child: Text('Erreur : ${devoirSnap.error}',
                    style: const TextStyle(
                        color: Color(0xFFDC2626), fontSize: 13)));
          }
          final devoirs = devoirSnap.data ?? [];
          if (devoirs.isEmpty) {
            return _emptyState(context);
          }
          return StreamBuilder<List<DocumentPedagogique>>(
            stream: ProfesseurService.documentsStream(),
            builder: (context, docSnap) {
              final docs = docSnap.data ?? [];
              final corriges = {
                for (final d in docs)
                  if (d.type == 'correction' && d.devoirId.isNotEmpty)
                    d.devoirId: d,
              };
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                itemCount: devoirs.length,
                itemBuilder: (ctx, i) => _DevoirCorrigeCard(
                  devoir: devoirs[i],
                  corrige: corriges[devoirs[i].id],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _emptyState(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.task_alt_outlined, color: Colors.white24, size: 56),
          SizedBox(height: 16),
          Text('Aucun devoir',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600)),
          SizedBox(height: 8),
          Text('Créez des devoirs pour y déposer des corrigés',
              style: TextStyle(color: Colors.white38, fontSize: 13)),
        ],
      ),
    );
  }
}

class _DevoirCorrigeCard extends StatefulWidget {
  final DevoirModel devoir;
  final DocumentPedagogique? corrige;
  const _DevoirCorrigeCard({required this.devoir, this.corrige});

  @override
  State<_DevoirCorrigeCard> createState() => _DevoirCorrigeCardState();
}

class _DevoirCorrigeCardState extends State<_DevoirCorrigeCard> {
  bool _uploading = false;

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  @override
  Widget build(BuildContext context) {
    final hasCorrige = widget.corrige != null;
    final corrigeColor =
        hasCorrige ? const Color(0xFF15803D) : const Color(0xFF374151);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: hasCorrige
                ? const Color(0xFF15803D).withValues(alpha: 0.3)
                : Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: corrigeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  hasCorrige
                      ? Icons.task_alt_outlined
                      : Icons.assignment_outlined,
                  color: corrigeColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.devoir.titre,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 14),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    Text(
                      '${widget.devoir.classeNom} · ${widget.devoir.matiere} · ${_fmt(widget.devoir.dateEnvoi)}',
                      style: const TextStyle(
                          color: Colors.white38, fontSize: 11),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                    color: corrigeColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20)),
                child: Text(
                  hasCorrige ? 'Corrigé disponible' : 'Sans corrigé',
                  style: TextStyle(
                      color: corrigeColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          if (hasCorrige) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF15803D).withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: const Color(0xFF15803D).withValues(alpha: 0.15)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.attach_file,
                      color: Color(0xFF15803D), size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.corrige!.fichierNom.isNotEmpty
                          ? widget.corrige!.fichierNom
                          : widget.corrige!.titre,
                      style: const TextStyle(
                          color: Color(0xFF15803D), fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF15803D),
                side: BorderSide(
                    color: const Color(0xFF15803D).withValues(alpha: 0.4)),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
              icon: _uploading
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                          color: Color(0xFF15803D), strokeWidth: 2))
                  : Icon(hasCorrige
                      ? Icons.upload_file_outlined
                      : Icons.add_circle_outline),
              label: Text(
                _uploading
                    ? 'Téléversement…'
                    : hasCorrige
                        ? 'Remplacer le corrigé'
                        : 'Déposer le corrigé',
                style: const TextStyle(fontSize: 13),
              ),
              onPressed: _uploading ? null : () => _pickAndUpload(context),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickAndUpload(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'ppt', 'pptx']);
    if (result == null || result.files.single.path == null) return;

    final file = File(result.files.single.path!);
    final nom = result.files.single.name;

    setState(() => _uploading = true);
    try {
      await ProfesseurService.addDocument(
        titre: 'Corrigé : ${widget.devoir.titre}',
        description: 'Correction du devoir ${widget.devoir.titre}',
        matiere: widget.devoir.matiere,
        classeId: widget.devoir.classeId,
        classeNom: widget.devoir.classeNom,
        type: 'correction',
        fichier: file,
        fichierNom: nom,
        devoirId: widget.devoir.id,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Corrigé déposé avec succès'),
          backgroundColor: Color(0xFF15803D),
        ));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erreur : $e'),
          backgroundColor: const Color(0xFFDC2626),
          duration: const Duration(seconds: 6),
        ));
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }
}
