import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../models/inscription_model.dart';
import '../services/inscription_service.dart';
import '../services/pdf_inscription_service.dart';
import '../widgets/pdf_import_tile.dart';
import '../widgets/pdf_preview_page.dart';
import '../widgets/scan_loading_widget.dart';
import 'inscription_verification_page.dart';

enum _Phase { idle, loading, done }

class InscriptionImportPage extends StatefulWidget {
  const InscriptionImportPage({super.key});

  @override
  State<InscriptionImportPage> createState() => _InscriptionImportPageState();
}

class _InscriptionImportPageState extends State<InscriptionImportPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;

  File? _file;
  String _fileName = '';
  _Phase _phase = _Phase.idle;
  double _progress = 0;
  Inscription? _draft;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  // ── Sélection ─────────────────────────────────────────────────────────────

  Future<void> _pick() async {
    final file = await PdfInscriptionService.pickPdf();
    if (file == null || !mounted) return;
    setState(() {
      _file = file;
      _fileName = file.path.split(Platform.pathSeparator).last;
      _phase = _Phase.idle;
      _draft = null;
    });
  }

  void _previewLocal() {
    final file = _file;
    if (file == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PdfPreviewPage(
          title: _fileName,
          loader: () => file.readAsBytes(),
        ),
      ),
    );
  }

  // ── Import + extraction ──────────────────────────────────────────────────

  Future<void> _import() async {
    if (_file == null || _phase == _Phase.loading) return;
    setState(() {
      _phase = _Phase.loading;
      _progress = 0;
    });

    final draft = await PdfInscriptionService.importAndCreateDraft(
      file: _file!,
      fileName: _fileName,
      onProgress: (p) {
        if (mounted) setState(() => _progress = p);
      },
    );

    if (!mounted) return;
    setState(() {
      _draft = draft;
      _phase = draft != null ? _Phase.done : _Phase.idle;
    });
  }

  void _reset() {
    setState(() {
      _file = null;
      _fileName = '';
      _phase = _Phase.idle;
      _progress = 0;
      _draft = null;
    });
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: _appBar(),
      body: Column(
        children: [
          _tabBar(),
          Expanded(
            child: TabBarView(
              controller: _tabCtrl,
              physics: const NeverScrollableScrollPhysics(),
              children: [_importTab(), _historyTab()],
            ),
          ),
        ],
      ),
    );
  }

  AppBar _appBar() => AppBar(
        backgroundColor: const Color(0xFF161B22),
        elevation: 0,
        title: const Text(
          'Import PDF',
          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        actions: [
          if (_file != null)
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white54),
              tooltip: 'Nouvel import',
              onPressed: _reset,
            ),
        ],
      );

  Widget _tabBar() => Container(
        color: const Color(0xFF161B22),
        child: TabBar(
          controller: _tabCtrl,
          indicatorColor: const Color(0xFF0F766E),
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white38,
          labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          tabs: const [Tab(text: 'Importer'), Tab(text: 'Historique')],
        ),
      );

  // ── Onglet Importer ───────────────────────────────────────────────────────

  Widget _importTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_file == null) _pickCard(),
          if (_file != null) _selectedCard(),
          if (_phase == _Phase.loading) ...[
            const SizedBox(height: 16),
            ScanLoadingWidget(progress: _progress),
          ],
          if (_phase == _Phase.done && _draft != null) ...[
            const SizedBox(height: 16),
            _resultCard(_draft!),
          ],
        ],
      ),
    );
  }

  Widget _pickCard() {
    return InkWell(
      onTap: _pick,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
        decoration: BoxDecoration(
          color: const Color(0xFF161B22),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
              color: Colors.white.withValues(alpha: 0.08),
              style: BorderStyle.solid),
        ),
        child: Column(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0F766E), Color(0xFF0891B2)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.upload_file, color: Colors.white, size: 26),
            ),
            const SizedBox(height: 16),
            const Text(
              'Sélectionner un PDF d\'inscription',
              style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            const Text(
              'Le dossier sera analysé puis proposé à la vérification',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white38, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _selectedCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFDC2626).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.picture_as_pdf_outlined,
                    color: Color(0xFFDC2626), size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _fileName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _previewLocal,
                  icon: const Icon(Icons.visibility_outlined, size: 18),
                  label: const Text('Aperçu'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white70,
                    side: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _phase == _Phase.loading ? null : _import,
                  icon: const Icon(Icons.cloud_upload_outlined, size: 18),
                  label: const Text('Importer'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F766E),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _resultCard(Inscription draft) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF16A34A).withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.check_circle_outline, color: Color(0xFF16A34A), size: 20),
              SizedBox(width: 8),
              Text(
                'PDF sauvegardé et analysé',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Données extraites pour ${draft.nomCompletEleve.isEmpty ? "l’élève" : draft.nomCompletEleve}. '
            'Vérifiez et corrigez les informations avant validation.',
            style: const TextStyle(color: Colors.white38, fontSize: 12),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => InscriptionVerificationFormPage(inscription: draft),
                ),
              ),
              icon: const Icon(Icons.fact_check_outlined, size: 18),
              label: const Text('Vérifier maintenant'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C47FF),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Onglet Historique ─────────────────────────────────────────────────────

  Widget _historyTab() {
    return StreamBuilder<List<Inscription>>(
      stream: InscriptionService.historyStream(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF2563EB)),
          );
        }
        final items = snap.data ?? [];
        if (items.isEmpty) {
          return const Center(
            child: Text('Aucun PDF importé pour le moment',
                style: TextStyle(color: Colors.white38, fontSize: 13)),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          itemCount: items.length,
          itemBuilder: (_, i) {
            final item = items[i];
            return PdfImportTile(
              inscription: item,
              onTap: () => _openHistoryItem(item),
            );
          },
        );
      },
    );
  }

  void _openHistoryItem(Inscription item) {
    if (item.statut == InscriptionStatut.brouillon) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => InscriptionVerificationFormPage(inscription: item),
        ),
      );
      return;
    }
    if (item.pdfUrl.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PdfPreviewPage(
          title: item.pdfName,
          loader: () => _fetchPdfBytes(item.pdfUrl),
        ),
      ),
    );
  }

  Future<Uint8List> _fetchPdfBytes(String url) async {
    final res = await http.get(Uri.parse(url));
    return res.bodyBytes;
  }
}
