import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../models/question_model.dart';
import '../services/devoir_interactif_service.dart';

class ProfesseurCreerDevoirPage extends StatefulWidget {
  final String classeId;
  final String classeNom;
  final String categorie;

  const ProfesseurCreerDevoirPage({
    super.key,
    required this.classeId,
    required this.classeNom,
    required this.categorie,
  });

  @override
  State<ProfesseurCreerDevoirPage> createState() =>
      _ProfesseurCreerDevoirPageState();
}

class _ProfesseurCreerDevoirPageState
    extends State<ProfesseurCreerDevoirPage> {
  final _formKey = GlobalKey<FormState>();
  final _titreCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  String _matiere = 'Mathématiques';
  DateTime? _dateLimite;
  File? _pdfFile;
  String? _pdfNom;

  bool _estExamen = false;
  bool _aiActive = true;
  final _dureeCtrl = TextEditingController();

  final List<QuestionModel> _questions = [];
  bool _saving = false;

  static const _matieres = [
    'Mathématiques', 'Français', 'Histoire-Géo', 'SVT',
    'Physique-Chimie', 'Anglais', 'Espagnol', 'Informatique', 'Autre',
  ];

  @override
  void dispose() {
    _titreCtrl.dispose();
    _descCtrl.dispose();
    _dureeCtrl.dispose();
    super.dispose();
  }

  // ── PDF ──────────────────────────────────────────────────────────────────────

  Future<void> _pickPdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (result != null && result.files.single.path != null) {
      setState(() {
        _pdfFile = File(result.files.single.path!);
        _pdfNom = result.files.single.name;
      });
    }
  }

  // ── Date ─────────────────────────────────────────────────────────────────────

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null) return;
    final time = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 23, minute: 59),
    );
    setState(() {
      _dateLimite = time == null
          ? date
          : DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  // ── Questions ────────────────────────────────────────────────────────────────

  void _addQuestion(TypeQuestion type) {
    setState(() {
      _questions.add(QuestionModel(
        id: QuestionModel.genId(),
        type: type,
        enonce: '',
        choix: type == TypeQuestion.qcm ? ['', ''] : const [],
      ));
    });
  }

  void _removeQuestion(int index) {
    setState(() => _questions.removeAt(index));
  }

  void _updateQuestion(int index, QuestionModel q) {
    setState(() => _questions[index] = q);
  }

  // ── Save ─────────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_questions.isEmpty && _pdfFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Ajoutez au moins une question ou un PDF.'),
      ));
      return;
    }
    for (final q in _questions) {
      if (q.enonce.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Un énoncé de question est vide.'),
        ));
        return;
      }
    }

    setState(() => _saving = true);
    try {
      await DevoirInteractifService.creerDevoir(
        titre: _titreCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        matiere: _matiere,
        classeId: widget.classeId,
        classeNom: widget.classeNom,
        categorie: widget.categorie,
        questions: _questions,
        dateLimite: _dateLimite,
        pdfFile: _pdfFile,
        pdfNom: _pdfNom,
        estExamen: _estExamen,
        aiActive: _aiActive,
        dureeMinutes: _estExamen && _dureeCtrl.text.isNotEmpty
            ? int.tryParse(_dureeCtrl.text)
            : null,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ── UI ───────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Créer un devoir'),
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.all(14),
              child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else
            TextButton(
              onPressed: _save,
              child: const Text('Publier',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── General info ──────────────────────────────────────────────────
            _SectionTitle('Informations générales'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _titreCtrl,
              decoration: const InputDecoration(
                labelText: 'Titre *',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Requis' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descCtrl,
              decoration: const InputDecoration(
                labelText: 'Description / consignes',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _matiere,
              decoration: const InputDecoration(
                labelText: 'Matière',
                border: OutlineInputBorder(),
              ),
              items: _matieres
                  .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                  .toList(),
              onChanged: (v) => setState(() => _matiere = v!),
            ),
            const SizedBox(height: 12),
            // Date limit
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today),
              title: Text(_dateLimite == null
                  ? 'Date limite (optionnel)'
                  : 'Limite : ${DateFormat('dd/MM/yyyy HH:mm').format(_dateLimite!)}'),
              trailing: _dateLimite != null
                  ? IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => setState(() => _dateLimite = null),
                    )
                  : null,
              onTap: _pickDate,
            ),
            const Divider(),

            // ── Exam settings ─────────────────────────────────────────────────
            _SectionTitle('Paramètres'),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Mode examen (chronométré)'),
              subtitle: const Text("Désactive l'assistant IA automatiquement"),
              value: _estExamen,
              onChanged: (v) => setState(() {
                _estExamen = v;
                if (v) _aiActive = false;
              }),
            ),
            if (_estExamen)
              Padding(
                padding: const EdgeInsets.only(left: 16, bottom: 8),
                child: TextFormField(
                  controller: _dureeCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Durée (minutes)',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
              ),
            if (!_estExamen)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Assistant IA activé'),
                subtitle: const Text('Les élèves peuvent demander des indices'),
                value: _aiActive,
                onChanged: (v) => setState(() => _aiActive = v),
              ),
            const Divider(),

            // ── PDF attachment ────────────────────────────────────────────────
            _SectionTitle('Pièce jointe PDF (optionnel)'),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
              title:
                  Text(_pdfNom ?? 'Joindre un fichier PDF'),
              trailing: _pdfFile != null
                  ? IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () =>
                          setState(() { _pdfFile = null; _pdfNom = null; }),
                    )
                  : null,
              onTap: _pickPdf,
            ),
            const Divider(),

            // ── Questions ─────────────────────────────────────────────────────
            _SectionTitle('Questions interactives'),
            const SizedBox(height: 8),
            ..._questions.asMap().entries.map(
                  (e) => _QuestionCard(
                    index: e.key,
                    question: e.value,
                    onUpdate: (q) => _updateQuestion(e.key, q),
                    onRemove: () => _removeQuestion(e.key),
                  ),
                ),
            const SizedBox(height: 8),
            _AddQuestionBar(onAdd: _addQuestion),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}

// ── Section title ─────────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(text,
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.bold)),
      );
}

// ── Add question bar ──────────────────────────────────────────────────────────

class _AddQuestionBar extends StatelessWidget {
  final void Function(TypeQuestion) onAdd;
  const _AddQuestionBar({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: TypeQuestion.values.map((t) {
        return OutlinedButton.icon(
          onPressed: () => onAdd(t),
          icon: const Icon(Icons.add, size: 16),
          label: Text(t.label, style: const TextStyle(fontSize: 12)),
        );
      }).toList(),
    );
  }
}

// ── Question card ─────────────────────────────────────────────────────────────

class _QuestionCard extends StatefulWidget {
  final int index;
  final QuestionModel question;
  final void Function(QuestionModel) onUpdate;
  final VoidCallback onRemove;

  const _QuestionCard({
    required this.index,
    required this.question,
    required this.onUpdate,
    required this.onRemove,
  });

  @override
  State<_QuestionCard> createState() => _QuestionCardState();
}

class _QuestionCardState extends State<_QuestionCard> {
  late final TextEditingController _enonceCtrl;
  late final TextEditingController _pointsCtrl;
  late final TextEditingController _correctionCtrl;
  late List<TextEditingController> _choixCtrlrs;

  @override
  void initState() {
    super.initState();
    _enonceCtrl =
        TextEditingController(text: widget.question.enonce);
    _pointsCtrl =
        TextEditingController(text: widget.question.points.toString());
    _correctionCtrl =
        TextEditingController(text: widget.question.correctionModele);
    _choixCtrlrs = widget.question.choix
        .map((c) => TextEditingController(text: c))
        .toList();
  }

  @override
  void dispose() {
    _enonceCtrl.dispose();
    _pointsCtrl.dispose();
    _correctionCtrl.dispose();
    for (final c in _choixCtrlrs) {
      c.dispose();
    }
    super.dispose();
  }

  void _emit() {
    widget.onUpdate(widget.question.copyWith(
      enonce: _enonceCtrl.text,
      points: double.tryParse(_pointsCtrl.text) ?? 1.0,
      correctionModele: _correctionCtrl.text,
      choix: _choixCtrlrs.map((c) => c.text).toList(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final q = widget.question;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Chip(
                  label: Text(q.type.label,
                      style: const TextStyle(fontSize: 11)),
                  padding: EdgeInsets.zero,
                ),
                const SizedBox(width: 8),
                Text('Q${widget.index + 1}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold)),
                const Spacer(),
                SizedBox(
                  width: 70,
                  child: TextFormField(
                    controller: _pointsCtrl,
                    decoration: const InputDecoration(
                      labelText: 'pts',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    onChanged: (_) => _emit(),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: widget.onRemove,
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Enonce
            TextFormField(
              controller: _enonceCtrl,
              decoration: const InputDecoration(
                labelText: 'Énoncé de la question *',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              onChanged: (_) => _emit(),
            ),
            const SizedBox(height: 8),
            // Type-specific fields
            if (q.type == TypeQuestion.qcm) _buildQcm(),
            if (q.type == TypeQuestion.vraiFaux) _buildVraiFaux(),
            // Correction model
            TextFormField(
              controller: _correctionCtrl,
              decoration: const InputDecoration(
                labelText: 'Correction / réponse attendue (optionnel)',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
              onChanged: (_) => _emit(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQcm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Choix :', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        ..._choixCtrlrs.asMap().entries.map((e) {
          final i = e.key;
          return Row(
            children: [
              Radio<int>(
                value: i,
                groupValue: widget.question.bonneReponseIndex,
                onChanged: (v) {
                  widget.onUpdate(widget.question.copyWith(
                    bonneReponseIndex: v,
                    enonce: _enonceCtrl.text,
                    choix: _choixCtrlrs.map((c) => c.text).toList(),
                  ));
                },
              ),
              Expanded(
                child: TextFormField(
                  controller: e.value,
                  decoration: InputDecoration(
                    labelText: 'Choix ${i + 1}',
                    isDense: true,
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (_) => _emit(),
                ),
              ),
              if (_choixCtrlrs.length > 2)
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline, size: 18),
                  onPressed: () {
                    setState(() {
                      _choixCtrlrs[i].dispose();
                      _choixCtrlrs.removeAt(i);
                    });
                    _emit();
                  },
                ),
            ],
          );
        }),
        if (_choixCtrlrs.length < 6)
          TextButton.icon(
            onPressed: () {
              setState(() => _choixCtrlrs.add(TextEditingController()));
              _emit();
            },
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Ajouter un choix'),
          ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildVraiFaux() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          const Text('Bonne réponse : '),
          ChoiceChip(
            label: const Text('Vrai'),
            selected: widget.question.bonneReponseVF == true,
            onSelected: (_) => widget.onUpdate(
                widget.question.copyWith(bonneReponseVF: true,
                    enonce: _enonceCtrl.text)),
          ),
          const SizedBox(width: 8),
          ChoiceChip(
            label: const Text('Faux'),
            selected: widget.question.bonneReponseVF == false,
            onSelected: (_) => widget.onUpdate(
                widget.question.copyWith(bonneReponseVF: false,
                    enonce: _enonceCtrl.text)),
          ),
        ],
      ),
    );
  }
}
