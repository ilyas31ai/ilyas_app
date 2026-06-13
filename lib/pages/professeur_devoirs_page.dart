import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../models/classe_model.dart';
import '../models/devoir_model.dart';
import '../services/professeur_service.dart';
import 'professeur_creer_devoir_page.dart';

class ProfesseurDevoirsPage extends StatefulWidget {
  const ProfesseurDevoirsPage({super.key});

  @override
  State<ProfesseurDevoirsPage> createState() => _ProfesseurDevoirsPageState();
}

class _ProfesseurDevoirsPageState extends State<ProfesseurDevoirsPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        elevation: 0,
        title: const Text('Devoirs',
            style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold)),
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            heroTag: 'fab_interactif',
            backgroundColor: const Color(0xFF0F766E),
            onPressed: () => _showCreerInteractifDialog(context),
            icon: const Icon(Icons.edit_note, color: Colors.white),
            label: const Text('Interactif',
                style: TextStyle(color: Colors.white)),
          ),
          const SizedBox(height: 10),
          FloatingActionButton.extended(
            heroTag: 'fab_pdf',
            backgroundColor: const Color(0xFF6C47FF),
            onPressed: () => _showSendDialog(context),
            icon: const Icon(Icons.send_outlined, color: Colors.white),
            label:
                const Text('Envoyer PDF', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: StreamBuilder<List<DevoirModel>>(
        stream: ProfesseurService.devoirsStream(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: Color(0xFF6C47FF)));
          }
          final devoirs = snap.data ?? [];
          if (devoirs.isEmpty) return _emptyState(context);
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            itemCount: devoirs.length,
            itemBuilder: (ctx, i) => _DevoirCard(
              devoir: devoirs[i],
              onDelete: () => _confirmDelete(ctx, devoirs[i]),
            ),
          );
        },
      ),
    );
  }

  Widget _emptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.assignment_outlined,
              color: Colors.white24, size: 56),
          const SizedBox(height: 16),
          const Text('Aucun devoir envoyé',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          const Text('Envoyez votre premier devoir',
              style: TextStyle(color: Colors.white38, fontSize: 13)),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C47FF),
                foregroundColor: Colors.white),
            icon: const Icon(Icons.send_outlined),
            label: const Text('Envoyer un devoir'),
            onPressed: () => _showSendDialog(context),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, DevoirModel devoir) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161B22),
        title: const Text('Supprimer le devoir',
            style: TextStyle(color: Colors.white)),
        content: Text('Supprimer « ${devoir.titre} » ?',
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
    if (ok == true) await ProfesseurService.deleteDevoir(devoir.id);
  }

  Future<void> _showCreerInteractifDialog(BuildContext context) async {
    // Load classes first, then let the professor pick one
    final classes = await ProfesseurService.classesStream().first;
    if (!mounted) return;

    ClasseModel? selected;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          backgroundColor: const Color(0xFF161B22),
          title: const Text('Choisir une classe',
              style: TextStyle(color: Colors.white)),
          content: classes.isEmpty
              ? const Text('Aucune classe disponible.',
                  style: TextStyle(color: Colors.white70))
              : DropdownButtonFormField<ClasseModel>(
                  dropdownColor: const Color(0xFF161B22),
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Classe',
                    labelStyle: TextStyle(color: Colors.white38),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Color(0x26FFFFFF)),
                    ),
                  ),
                  items: classes
                      .map((c) => DropdownMenuItem(
                            value: c,
                            child: Text(c.nom,
                                style:
                                    const TextStyle(color: Colors.white)),
                          ))
                      .toList(),
                  onChanged: (c) => setSt(() => selected = c),
                ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Annuler',
                    style: TextStyle(color: Colors.white38))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F766E)),
              onPressed: selected == null
                  ? null
                  : () => Navigator.pop(ctx),
              child: const Text('Continuer',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );

    if (selected == null || !mounted) return;

    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ProfesseurCreerDevoirPage(
          classeId: selected!.id,
          classeNom: selected!.nom,
          categorie: selected!.niveau,
        ),
      ),
    );
    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Devoir interactif publié !'),
      ));
    }
  }

  Future<void> _showSendDialog(BuildContext context) async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF161B22),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _DevoirForm(),
    );
  }
}

// ─── Carte devoir ─────────────────────────────────────────────────────────────

class _DevoirCard extends StatelessWidget {
  final DevoirModel devoir;
  final VoidCallback onDelete;

  const _DevoirCard({required this.devoir, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final limit = devoir.dateLimite;
    final isLate =
        limit != null && limit.isBefore(DateTime.now());
    return Dismissible(
      key: Key(devoir.id),
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [Color(0xFF6C47FF), Color(0xFF2563EB)]),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.assignment_outlined,
                      color: Colors.white, size: 19),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(devoir.titre,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 14),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      Text('${devoir.classeNom} · ${devoir.matiere}',
                          style: const TextStyle(
                              color: Colors.white38, fontSize: 12)),
                    ],
                  ),
                ),
                if (devoir.aFichier)
                  const Icon(Icons.attach_file,
                      color: Colors.white24, size: 16),
              ],
            ),
            if (devoir.description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(devoir.description,
                  style: const TextStyle(
                      color: Colors.white60, fontSize: 12),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
            ],
            if (limit != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.schedule,
                    color: isLate
                        ? const Color(0xFFDC2626)
                        : const Color(0xFF15803D),
                    size: 14,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Date limite : ${_fmt(limit)}',
                    style: TextStyle(
                      color: isLate
                          ? const Color(0xFFDC2626)
                          : const Color(0xFF15803D),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

// ─── Formulaire envoi devoir ──────────────────────────────────────────────────

class _DevoirForm extends StatefulWidget {
  @override
  State<_DevoirForm> createState() => _DevoirFormState();
}

class _DevoirFormState extends State<_DevoirForm> {
  final _titre = TextEditingController();
  final _desc = TextEditingController();
  final _matiere = TextEditingController();
  final _classeNom = TextEditingController();
  DateTime? _dateLimite;
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
            const Text('Envoyer un devoir',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _Field(controller: _titre, label: 'Titre du devoir'),
            const SizedBox(height: 10),
            _Field(controller: _desc, label: 'Description (optionnel)', maxLines: 3),
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
            // Date limite
            InkWell(
              onTap: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now().add(const Duration(days: 7)),
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                  builder: (ctx, child) => Theme(
                    data: Theme.of(ctx).copyWith(
                        colorScheme: const ColorScheme.dark(
                          primary: Color(0xFF6C47FF),
                          surface: Color(0xFF161B22),
                        )),
                    child: child!,
                  ),
                );
                if (d != null) setState(() => _dateLimite = d);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 14),
                decoration: BoxDecoration(
                  border: Border.all(
                      color: Colors.white.withValues(alpha: 0.15)),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.schedule,
                        color: Colors.white38, size: 18),
                    const SizedBox(width: 10),
                    Text(
                      _dateLimite != null
                          ? 'Limite : ${_dateLimite!.day.toString().padLeft(2, '0')}/${_dateLimite!.month.toString().padLeft(2, '0')}/${_dateLimite!.year}'
                          : 'Date limite (optionnel)',
                      style: TextStyle(
                          color: _dateLimite != null
                              ? Colors.white
                              : Colors.white38,
                          fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            // Fichier
            InkWell(
              onTap: _pickFile,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 14),
                decoration: BoxDecoration(
                  border: Border.all(
                      color: Colors.white.withValues(alpha: 0.15)),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.attach_file,
                        color: Colors.white38, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _fichierNom ?? 'Joindre un fichier (optionnel)',
                        style: TextStyle(
                            color: _fichierNom != null
                                ? Colors.white
                                : Colors.white38,
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
                    backgroundColor: const Color(0xFF6C47FF),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14)),
                onPressed: _saving ? null : _send,
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Text('Envoyer le devoir',
                        style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform
        .pickFiles(type: FileType.custom, allowedExtensions: ['pdf', 'jpg', 'png', 'jpeg']);
    if (result != null && result.files.single.path != null) {
      setState(() {
        _fichier = File(result.files.single.path!);
        _fichierNom = result.files.single.name;
      });
    }
  }

  Future<void> _send() async {
    if (_titre.text.trim().isEmpty || _matiere.text.trim().isEmpty ||
        _classeNom.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      await ProfesseurService.sendDevoir(
        titre: _titre.text.trim(),
        description: _desc.text.trim(),
        matiere: _matiere.text.trim(),
        classeId: '',
        classeNom: _classeNom.text.trim(),
        dateLimite: _dateLimite,
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
          borderSide: const BorderSide(color: Color(0xFF6C47FF)),
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
          borderSide: const BorderSide(color: Color(0xFF6C47FF)),
        ),
      ),
    );
  }
}
