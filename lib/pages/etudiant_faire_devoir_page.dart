import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../models/copie_model.dart';
import '../models/devoir_model.dart';
import '../models/question_model.dart';
import '../services/ai_assistant_service.dart';
import '../services/devoir_interactif_service.dart';

class EtudiantFaireDevoirPage extends StatefulWidget {
  final DevoirModel devoir;
  final String eleveNom;
  final bool readOnly;
  final CopieModel? existingCopie;

  const EtudiantFaireDevoirPage({
    super.key,
    required this.devoir,
    required this.eleveNom,
    required this.readOnly,
    this.existingCopie,
  });

  @override
  State<EtudiantFaireDevoirPage> createState() =>
      _EtudiantFaireDevoirPageState();
}

class _EtudiantFaireDevoirPageState extends State<EtudiantFaireDevoirPage> {
  late Map<String, dynamic> _reponses;
  String? _copieId;
  bool _saving = false;
  bool _submitting = false;

  // Timer for exams
  Timer? _timer;
  int _secondsLeft = 0;

  @override
  void initState() {
    super.initState();
    _copieId = widget.existingCopie?.id;
    _reponses =
        Map<String, dynamic>.from(widget.existingCopie?.reponses ?? {});
    _initTimer();
  }

  void _initTimer() {
    if (!widget.devoir.estExamen) return;
    if (widget.readOnly) return;
    final dur = widget.devoir.dureeMinutes;
    if (dur == null) return;
    _secondsLeft = dur * 60;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_secondsLeft <= 0) {
        _timer?.cancel();
        _autoSubmit();
        return;
      }
      setState(() => _secondsLeft--);
    });
  }

  Future<void> _autoSubmit() async {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('⏱ Temps écoulé ! Devoir soumis automatiquement.'),
      duration: Duration(seconds: 4),
    ));
    await _submit(auto: true);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // ── Responses ─────────────────────────────────────────────────────────────

  void _setReponse(String questionId, dynamic valeur) {
    setState(() => _reponses[questionId] = {'valeur': valeur});
  }

  dynamic _getValeur(String questionId) =>
      (_reponses[questionId] as Map?)?['valeur'];

  // ── Draft save ────────────────────────────────────────────────────────────

  Future<void> _saveDraft() async {
    if (widget.readOnly) return;
    setState(() => _saving = true);
    try {
      final id = await DevoirInteractifService.sauvegarderCopie(
        devoirId: widget.devoir.id,
        classeId: widget.devoir.classeId,
        eleveNom: widget.eleveNom,
        professeurId: widget.devoir.professeurId,
        reponses: _reponses,
        soumettre: false,
        copieId: _copieId,
      );
      _copieId = id;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Brouillon sauvegardé.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ── Submit ────────────────────────────────────────────────────────────────

  Future<void> _submit({bool auto = false}) async {
    if (widget.readOnly) return;
    if (!auto) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Soumettre le devoir ?'),
          content: const Text(
              'Vous ne pourrez plus modifier vos réponses après la soumission.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Annuler')),
            ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Soumettre')),
          ],
        ),
      );
      if (ok != true) return;
    }

    setState(() => _submitting = true);
    try {
      await DevoirInteractifService.sauvegarderCopie(
        devoirId: widget.devoir.id,
        classeId: widget.devoir.classeId,
        eleveNom: widget.eleveNom,
        professeurId: widget.devoir.professeurId,
        reponses: _reponses,
        soumettre: true,
        copieId: _copieId,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erreur : $e')));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  // ── UI ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final d = widget.devoir;
    final copie = widget.existingCopie;

    return Scaffold(
      appBar: AppBar(
        title: Text(d.titre),
        actions: [
          if (d.estExamen && !widget.readOnly && _secondsLeft > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Center(
                child: Text(
                  _formatTime(_secondsLeft),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _secondsLeft < 120 ? Colors.red : null,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          if (!widget.readOnly) ...[
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
                onPressed: _saveDraft,
                child: const Text('Brouillon'),
              ),
          ],
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Header info
          Card(
            color: Theme.of(context).colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${d.matiere} · ${d.classeNom}',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  if (d.description.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(d.description),
                    ),
                  if (d.dateLimite != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Limite : ${DateFormat('dd/MM/yyyy HH:mm').format(d.dateLimite!)}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  if (d.estInteractif)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '${d.questions.length} question(s) · ${d.totalPoints.toStringAsFixed(0)} points',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  if (!d.aiActive || d.estExamen)
                    const Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Row(
                        children: [
                          Icon(Icons.block, size: 14, color: Colors.red),
                          SizedBox(width: 4),
                          Text('Assistant IA désactivé',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.red)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Grade if corrected
          if (widget.readOnly &&
              copie?.statut == CopieStatut.corrige &&
              copie != null) ...[
            _GradeCard(copie: copie),
            const SizedBox(height: 16),
          ],

          // Questions
          if (d.estInteractif)
            ...d.questions.asMap().entries.map(
                  (e) => _QuestionWidget(
                    index: e.key,
                    question: e.value,
                    valeur: _getValeur(e.value.id),
                    correction: widget.readOnly && copie != null
                        ? (copie.corrections[e.value.id]
                            as Map<String, dynamic>?)
                        : null,
                    readOnly: widget.readOnly,
                    aiEnabled: d.aiActive && !d.estExamen,
                    matiere: d.matiere,
                    classeNom: d.classeNom,
                    onChanged: (v) => _setReponse(e.value.id, v),
                    devoirId: d.id,
                  ),
                ),

          const SizedBox(height: 80),
        ],
      ),
      bottomNavigationBar: widget.readOnly
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: ElevatedButton(
                  onPressed: _submitting ? null : () => _submit(),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                  child: _submitting
                      ? const CircularProgressIndicator()
                      : const Text('Soumettre le devoir',
                          style: TextStyle(fontSize: 16)),
                ),
              ),
            ),
    );
  }

  String _formatTime(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}

// ── Grade card ────────────────────────────────────────────────────────────────

class _GradeCard extends StatelessWidget {
  final CopieModel copie;
  const _GradeCard({required this.copie});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFFE8F5E9),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.grade, color: Colors.green),
                const SizedBox(width: 8),
                Text(
                  'Note : ${copie.note?.toStringAsFixed(1) ?? '-'}/${copie.noteSur?.toStringAsFixed(0) ?? '?'}',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            if (copie.commentaire != null && copie.commentaire!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('Commentaire : ${copie.commentaire}'),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Question widget ───────────────────────────────────────────────────────────

class _QuestionWidget extends StatefulWidget {
  final int index;
  final QuestionModel question;
  final dynamic valeur;
  final Map<String, dynamic>? correction;
  final bool readOnly;
  final bool aiEnabled;
  final String matiere;
  final String classeNom;
  final String devoirId;
  final void Function(dynamic) onChanged;

  const _QuestionWidget({
    required this.index,
    required this.question,
    required this.valeur,
    required this.correction,
    required this.readOnly,
    required this.aiEnabled,
    required this.matiere,
    required this.classeNom,
    required this.devoirId,
    required this.onChanged,
  });

  @override
  State<_QuestionWidget> createState() => _QuestionWidgetState();
}

class _QuestionWidgetState extends State<_QuestionWidget> {
  late final TextEditingController _textCtrl;
  String? _aiHint;
  bool _loadingHint = false;
  int _hintLevel = 0;

  @override
  void initState() {
    super.initState();
    final v = widget.valeur;
    _textCtrl = TextEditingController(
        text: (v is String) ? v : '');
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  Future<void> _requestHint() async {
    if (_hintLevel >= 3) return;
    setState(() {
      _hintLevel++;
      _loadingHint = true;
      _aiHint = null;
    });
    final hint = await AiAssistantService.getHint(
      enonce: widget.question.enonce,
      matiere: widget.matiere,
      niveau: _hintLevel,
      classeNom: widget.classeNom,
      reponseEleve: _textCtrl.text,
    );
    if (mounted) setState(() { _loadingHint = false; _aiHint = hint; });
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final picked =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked == null) return;
    setState(() => _loadingHint = true);
    try {
      final url = await DevoirInteractifService.uploadPhotoReponse(
          File(picked.path), widget.devoirId);
      widget.onChanged(url);
    } finally {
      if (mounted) setState(() => _loadingHint = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = widget.question;
    final corr = widget.correction;
    final isCorrect = corr?['ok'] as bool?;

    Color? borderColor;
    if (corr != null) {
      borderColor =
          isCorrect == true ? Colors.green : Colors.red;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: borderColor != null
            ? BorderSide(color: borderColor, width: 2)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Question header
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 13,
                  backgroundColor:
                      Theme.of(context).colorScheme.primary,
                  child: Text(
                    '${widget.index + 1}',
                    style: const TextStyle(
                        color: Colors.white, fontSize: 12),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(q.enonce,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600)),
                      Text(
                        '${q.type.label} · ${q.points.toStringAsFixed(1)} pt',
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                if (corr != null)
                  Icon(
                    isCorrect == true
                        ? Icons.check_circle
                        : Icons.cancel,
                    color: isCorrect == true
                        ? Colors.green
                        : Colors.red,
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // Input by type
            if (q.type == TypeQuestion.qcm)
              _buildQcm(q)
            else if (q.type == TypeQuestion.vraiFaux)
              _buildVraiFaux(q)
            else if (q.type == TypeQuestion.photo)
              _buildPhoto()
            else
              _buildText(q),

            // Correction feedback
            if (corr != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isCorrect == true
                      ? const Color(0xFFE8F5E9)
                      : const Color(0xFFFFEBEE),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isCorrect == true
                          ? '✓ Bonne réponse'
                          : '✗ Réponse incorrecte',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isCorrect == true
                            ? Colors.green[800]
                            : Colors.red[800],
                      ),
                    ),
                    if (q.correctionModele.isNotEmpty)
                      Text('Correction : ${q.correctionModele}'),
                    if ((corr['commentaire'] as String?)
                            ?.isNotEmpty ==
                        true)
                      Text('Prof : ${corr['commentaire']}'),
                  ],
                ),
              ),
            ],

            // AI assistant
            if (widget.aiEnabled && !widget.readOnly) ...[
              const SizedBox(height: 8),
              _AiHintSection(
                hintLevel: _hintLevel,
                loading: _loadingHint,
                hint: _aiHint,
                onRequest: _hintLevel < 3 ? _requestHint : null,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildQcm(QuestionModel q) {
    return Column(
      children: q.choix.asMap().entries.map((e) {
        final selected = widget.valeur == e.key;
        return RadioListTile<int>(
          title: Text(e.value),
          value: e.key,
          groupValue: widget.valeur as int?,
          onChanged: widget.readOnly
              ? null
              : (v) => widget.onChanged(v),
          selected: selected,
          dense: true,
        );
      }).toList(),
    );
  }

  Widget _buildVraiFaux(QuestionModel q) {
    return Row(
      children: [
        Expanded(
          child: RadioListTile<bool>(
            title: const Text('Vrai'),
            value: true,
            groupValue: widget.valeur as bool?,
            onChanged:
                widget.readOnly ? null : (v) => widget.onChanged(v),
            dense: true,
          ),
        ),
        Expanded(
          child: RadioListTile<bool>(
            title: const Text('Faux'),
            value: false,
            groupValue: widget.valeur as bool?,
            onChanged:
                widget.readOnly ? null : (v) => widget.onChanged(v),
            dense: true,
          ),
        ),
      ],
    );
  }

  Widget _buildText(QuestionModel q) {
    return TextField(
      controller: _textCtrl,
      decoration: const InputDecoration(
        border: OutlineInputBorder(),
        hintText: 'Votre réponse…',
      ),
      maxLines:
          q.type == TypeQuestion.reponseLongue ? 5 : 2,
      readOnly: widget.readOnly,
      onChanged: (v) => widget.onChanged(v),
    );
  }

  Widget _buildPhoto() {
    final url = widget.valeur as String?;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (url != null && url.isNotEmpty)
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(url,
                height: 200, width: double.infinity, fit: BoxFit.cover),
          ),
        if (!widget.readOnly)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: OutlinedButton.icon(
              onPressed: _loadingHint ? null : _pickPhoto,
              icon: _loadingHint
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.photo_library),
              label: Text(url != null ? 'Changer la photo' : 'Joindre une photo'),
            ),
          ),
      ],
    );
  }
}

// ── AI hint section ───────────────────────────────────────────────────────────

class _AiHintSection extends StatelessWidget {
  final int hintLevel;
  final bool loading;
  final String? hint;
  final VoidCallback? onRequest;

  const _AiHintSection({
    required this.hintLevel,
    required this.loading,
    required this.hint,
    required this.onRequest,
  });

  String get _nextLabel {
    switch (hintLevel) {
      case 0:
        return '💡 Demander un indice';
      case 1:
        return '🔍 Voir la méthode';
      default:
        return '🎯 Résolution guidée';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hint != null)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF3E5F5),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFCE93D8)),
            ),
            child: Text(hint!),
          ),
        if (onRequest != null)
          loading
              ? const Row(
                  children: [
                    SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2)),
                    SizedBox(width: 8),
                    Text("L'IA réfléchit…",
                        style: TextStyle(fontSize: 12)),
                  ],
                )
              : TextButton.icon(
                  onPressed: onRequest,
                  icon: const Icon(Icons.auto_fix_high, size: 16),
                  label: Text(_nextLabel,
                      style: const TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                  ),
                ),
      ],
    );
  }
}
