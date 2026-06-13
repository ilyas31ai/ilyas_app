import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../models/classe_model.dart';
import '../models/document_model.dart';
import '../services/professeur_service.dart';

class ProfesseurDocumentsPage extends StatefulWidget {
  const ProfesseurDocumentsPage({super.key});

  @override
  State<ProfesseurDocumentsPage> createState() =>
      _ProfesseurDocumentsPageState();
}

class _ProfesseurDocumentsPageState extends State<ProfesseurDocumentsPage> {
  String _filterType = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        elevation: 0,
        title: const Text('Documents pédagogiques',
            style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF0F766E),
        onPressed: () => _showAddDialog(context),
        icon: const Icon(Icons.upload_file_outlined, color: Colors.white),
        label: const Text('Déposer', style: TextStyle(color: Colors.white)),
      ),
      body: Column(
        children: [
          _TypeFilter(
            selected: _filterType,
            onChanged: (t) => setState(() => _filterType = t),
          ),
          Expanded(
            child: StreamBuilder<List<DocumentPedagogique>>(
              stream: ProfesseurService.documentsStream(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child: CircularProgressIndicator(
                          color: Color(0xFF0F766E)));
                }
                var docs = snap.data ?? [];
                if (_filterType.isNotEmpty) {
                  docs = docs.where((d) => d.type == _filterType).toList();
                }
                if (docs.isEmpty) return _emptyState(context);
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                  itemCount: docs.length,
                  itemBuilder: (ctx, i) => _DocCard(
                    doc: docs[i],
                    onDelete: () => _confirmDelete(ctx, docs[i]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.folder_open_outlined,
              color: Colors.white24, size: 56),
          const SizedBox(height: 16),
          const Text('Aucun document déposé',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          const Text('Déposez cours, exercices et corrections',
              style: TextStyle(color: Colors.white38, fontSize: 13)),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F766E),
                foregroundColor: Colors.white),
            icon: const Icon(Icons.upload_file_outlined),
            label: const Text('Déposer un document'),
            onPressed: () => _showAddDialog(context),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, DocumentPedagogique doc) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161B22),
        title: const Text('Supprimer le document',
            style: TextStyle(color: Colors.white)),
        content: Text('Supprimer « ${doc.titre} » ?',
            style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler',
                  style: TextStyle(color: Colors.white38))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Supprimer',
                  style: TextStyle(color: Color(0xFFDC2626)))),
        ],
      ),
    );
    if (ok == true) await ProfesseurService.deleteDocument(doc.id);
  }

  Future<void> _showAddDialog(BuildContext context) async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF161B22),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _DocumentForm(),
    );
  }
}

// ─── Filtre type ──────────────────────────────────────────────────────────────

class _TypeFilter extends StatelessWidget {
  final String selected;
  final void Function(String) onChanged;

  const _TypeFilter({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final types = ['', 'cours', 'exercice', 'correction', 'autre'];
    final labels = ['Tous', 'Cours', 'Exercice', 'Correction', 'Autre'];
    return Container(
      height: 44,
      color: const Color(0xFF161B22),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        itemCount: types.length,
        itemBuilder: (ctx, i) {
          final active = selected == types[i];
          return GestureDetector(
            onTap: () => onChanged(types[i]),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                gradient: active
                    ? const LinearGradient(
                        colors: [Color(0xFF0F766E), Color(0xFF0891B2)])
                    : null,
                color: active ? null : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: active
                        ? Colors.transparent
                        : Colors.white.withValues(alpha: 0.15)),
              ),
              child: Center(
                child: Text(labels[i],
                    style: TextStyle(
                        color: active ? Colors.white : Colors.white38,
                        fontSize: 12,
                        fontWeight: active ? FontWeight.w600 : FontWeight.normal)),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─── Carte document ───────────────────────────────────────────────────────────

class _DocCard extends StatelessWidget {
  final DocumentPedagogique doc;
  final VoidCallback onDelete;

  const _DocCard({required this.doc, required this.onDelete});

  static const _typeColors = {
    'cours': Color(0xFF0F766E),
    'exercice': Color(0xFF2563EB),
    'correction': Color(0xFF15803D),
    'autre': Color(0xFF374151),
  };

  @override
  Widget build(BuildContext context) {
    final color = _typeColors[doc.type] ?? const Color(0xFF374151);
    return Dismissible(
      key: Key(doc.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        decoration: BoxDecoration(
          color: const Color(0xFFDC2626).withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete_outline, color: Color(0xFFDC2626)),
      ),
      onDismissed: (_) => onDelete(),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF161B22),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: color.withValues(alpha: 0.4)),
              ),
              child: Icon(Icons.description_outlined,
                  color: color, size: 21),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(doc.titre,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  Text(
                    '${doc.classeNom} · ${doc.matiere} · ${doc.type}',
                    style:
                        const TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ],
              ),
            ),
            if (doc.aFichier)
              const Icon(Icons.attach_file,
                  color: Colors.white24, size: 16),
            IconButton(
              icon: const Icon(Icons.delete_outline,
                  color: Colors.white24, size: 18),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Formulaire ajout document ────────────────────────────────────────────────

class _DocumentForm extends StatefulWidget {
  @override
  State<_DocumentForm> createState() => _DocumentFormState();
}

class _DocumentFormState extends State<_DocumentForm> {
  final _titre = TextEditingController();
  final _desc = TextEditingController();
  final _matiere = TextEditingController();
  final _classeNom = TextEditingController();
  String _type = 'cours';
  File? _fichier;
  String? _fichierNom;
  bool _saving = false;
  List<ClasseModel> _classes = [];

  @override
  void initState() {
    super.initState();
    ProfesseurService.classesStream()
        .first
        .then((c) { if (mounted) setState(() => _classes = c); });
  }

  @override
  void dispose() {
    for (final c in [_titre, _desc, _matiere, _classeNom]) c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          left: 20,
          right: 20,
          top: 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Déposer un document',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _Field(controller: _titre, label: 'Titre du document'),
            const SizedBox(height: 10),
            _Field(controller: _desc, label: 'Description (optionnel)', maxLines: 2),
            const SizedBox(height: 10),
            _Field(controller: _matiere, label: 'Matière'),
            const SizedBox(height: 10),
            if (_classes.isNotEmpty)
              DropdownButtonFormField<ClasseModel>(
                dropdownColor: const Color(0xFF161B22),
                style: const TextStyle(color: Colors.white),
                decoration: _inputDeco('Classe'),
                items: _classes
                    .map((c) => DropdownMenuItem(
                        value: c,
                        child: Text(c.nom,
                            style: const TextStyle(color: Colors.white))))
                    .toList(),
                onChanged: (c) {
                  if (c != null) _classeNom.text = c.nom;
                },
              )
            else
              _Field(controller: _classeNom, label: 'Classe (ex: 6ème A)'),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: _type,
              dropdownColor: const Color(0xFF161B22),
              style: const TextStyle(color: Colors.white),
              decoration: _inputDeco('Type'),
              items: const [
                DropdownMenuItem(value: 'cours', child: Text('Cours')),
                DropdownMenuItem(value: 'exercice', child: Text('Exercice')),
                DropdownMenuItem(value: 'correction', child: Text('Correction')),
                DropdownMenuItem(value: 'autre', child: Text('Autre')),
              ],
              onChanged: (t) => setState(() => _type = t ?? 'cours'),
            ),
            const SizedBox(height: 10),
            InkWell(
              onTap: _pickFile,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.attach_file, color: Colors.white38, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _fichierNom ?? 'Joindre un fichier PDF (optionnel)',
                        style: TextStyle(
                            color: _fichierNom != null ? Colors.white : Colors.white38,
                            fontSize: 14),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F766E),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14)),
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Déposer', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform
        .pickFiles(type: FileType.custom, allowedExtensions: ['pdf', 'doc', 'docx', 'ppt', 'pptx']);
    if (result != null && result.files.single.path != null) {
      setState(() {
        _fichier = File(result.files.single.path!);
        _fichierNom = result.files.single.name;
      });
    }
  }

  Future<void> _save() async {
    if (_titre.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      await ProfesseurService.addDocument(
        titre: _titre.text.trim(),
        description: _desc.text.trim(),
        matiere: _matiere.text.trim(),
        classeId: '',
        classeNom: _classeNom.text.trim(),
        type: _type,
        fichier: _fichier,
        fichierNom: _fichierNom,
      );
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  InputDecoration _inputDeco(String label) => InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white38),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF0F766E)),
        ),
      );
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final int maxLines;
  const _Field({required this.controller, required this.label, this.maxLines = 1});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white38),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF0F766E)),
        ),
      ),
    );
  }
}
