import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/devoir_model.dart';
import '../models/submission_model.dart';
import '../services/etudiant_service.dart';

// ─── Palette ──────────────────────────────────────────────────────────────────

const _kBg     = Color(0xFF0D1117);
const _kCard   = Color(0xFF161B22);
const _kCard2  = Color(0xFF1F2937);
const _kBorder = Color(0xFF30363D);
const _kBlue   = Color(0xFF2563EB);
const _kPurple = Color(0xFF6C47FF);
const _kGreen  = Color(0xFF16A34A);
const _kOrange = Color(0xFFD97706);
const _kRed    = Color(0xFFDC2626);

// ─── Page soumission devoir (non-interactif) ──────────────────────────────────

class EtudiantSoumissionDevoirPage extends StatefulWidget {
  final DevoirModel devoir;
  final SubmissionModel? existingSubmission;

  const EtudiantSoumissionDevoirPage({
    super.key,
    required this.devoir,
    this.existingSubmission,
  });

  @override
  State<EtudiantSoumissionDevoirPage> createState() =>
      _EtudiantSoumissionDevoirPageState();
}

class _EtudiantSoumissionDevoirPageState
    extends State<EtudiantSoumissionDevoirPage> {
  final _textCtrl = TextEditingController();
  final _commentCtrl = TextEditingController();
  final List<File> _fichiers = [];
  final List<String> _nomsF = [];
  bool _saving = false;

  bool get _isCorrected =>
      widget.existingSubmission?.status == SubmissionStatus.corrected;
  bool get _isSubmitted => widget.existingSubmission != null;
  bool get _isExpired =>
      widget.devoir.dateLimite != null &&
      DateTime.now().isAfter(widget.devoir.dateLimite!);

  @override
  void initState() {
    super.initState();
    if (widget.existingSubmission != null) {
      _textCtrl.text =
          widget.existingSubmission!.textReponse;
      _commentCtrl.text =
          widget.existingSubmission!.comment;
    }
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowMultiple: true,
      allowedExtensions: [
        'pdf', 'jpg', 'jpeg', 'png', 'doc', 'docx',
        'xls', 'xlsx', 'txt'
      ],
    );
    if (result == null) return;
    for (final f in result.files) {
      if (f.path != null) {
        setState(() {
          _fichiers.add(File(f.path!));
          _nomsF.add(f.name);
        });
      }
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    final img = await ImagePicker()
        .pickImage(source: source, imageQuality: 80);
    if (img == null) return;
    final name = img.path.split('/').last;
    setState(() {
      _fichiers.add(File(img.path));
      _nomsF.add(name);
    });
  }

  Future<void> _submit() async {
    if (_saving) return;
    if (_textCtrl.text.trim().isEmpty && _fichiers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text(
            'Ajoutez une réponse (texte ou fichier) avant de soumettre.'),
        backgroundColor: _kRed,
      ));
      return;
    }
    setState(() => _saving = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      await EtudiantService.submitDevoirComplet(
        assignmentId: widget.devoir.id,
        teacherId: widget.devoir.professeurId,
        devoirTitre: widget.devoir.titre,
        classeId: widget.devoir.classeId,
        classeNom: widget.devoir.classeNom,
        textReponse: _textCtrl.text.trim(),
        fichiers: _fichiers,
        nomsFichiers: _nomsF,
        commentaire: _commentCtrl.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Devoir soumis avec succès !'),
          backgroundColor: _kGreen,
        ));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erreur : $e'),
          backgroundColor: _kRed,
        ));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.devoir;
    final sub = widget.existingSubmission;

    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kCard,
        elevation: 0,
        title: Text(d.titre,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.bold),
            maxLines: 1,
            overflow: TextOverflow.ellipsis),
        actions: [
          if (!_isCorrected && !_isExpired)
            TextButton(
              onPressed: _saving ? null : _submit,
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          color: _kPurple, strokeWidth: 2))
                  : const Text('Soumettre',
                      style: TextStyle(color: _kPurple,
                          fontWeight: FontWeight.bold)),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Détails du devoir ─────────────────────────────────────────
            _Section(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _kOrange.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(d.matiere,
                          style: const TextStyle(
                              color: _kOrange,
                              fontSize: 11,
                              fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text('Sur ${d.bareme} pts',
                          style: const TextStyle(
                              color: Colors.white38, fontSize: 11)),
                    ),
                  ]),
                  const SizedBox(height: 10),
                  Text(d.titre,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16)),
                  if (d.description.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(d.description,
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 13, height: 1.5)),
                  ],
                  if (d.professeurNom.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text('Par ${d.professeurNom}',
                        style: const TextStyle(
                            color: Colors.white38, fontSize: 12)),
                  ],
                  if (d.dateLimite != null) ...[
                    const SizedBox(height: 6),
                    Row(children: [
                      Icon(Icons.schedule,
                          size: 13,
                          color: _isExpired ? _kRed : _kGreen),
                      const SizedBox(width: 4),
                      Text(
                        'Limite : ${DateFormat('dd/MM/yyyy à HH:mm').format(d.dateLimite!)}',
                        style: TextStyle(
                            color: _isExpired ? _kRed : _kGreen,
                            fontSize: 12),
                      ),
                    ]),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),

            // ── Pièces jointes du devoir ──────────────────────────────────
            if (d.tousLesAttachements.isNotEmpty) ...[
              _SectionTitle('Ressources du professeur'),
              const SizedBox(height: 6),
              ...d.tousLesAttachements.map(
                (f) => _AttachmentTile(
                  nom: f['nom'] ?? 'Fichier',
                  type: f['type'] ?? '',
                  url: f['url'] ?? '',
                ),
              ),
              const SizedBox(height: 12),
            ],

            // ── Résultat correction ───────────────────────────────────────
            if (_isCorrected && sub != null) ...[
              _SectionTitle('Correction'),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _kGreen.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: _kGreen.withValues(alpha: 0.25)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (sub.grade != null)
                      Row(children: [
                        const Icon(Icons.star,
                            color: _kGreen, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          '${sub.grade!.toStringAsFixed(1)} / ${d.bareme}',
                          style: const TextStyle(
                              color: _kGreen,
                              fontWeight: FontWeight.bold,
                              fontSize: 18),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: _kGreen.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _mention(
                                sub.grade!, d.bareme.toDouble()),
                            style: const TextStyle(
                                color: _kGreen,
                                fontWeight: FontWeight.bold,
                                fontSize: 11),
                          ),
                        ),
                      ]),
                    if (sub.teacherComment != null &&
                        sub.teacherComment!.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      const Divider(color: Colors.white12),
                      const SizedBox(height: 6),
                      Row(crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        const Icon(Icons.comment_outlined,
                            color: Colors.white38, size: 14),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(sub.teacherComment!,
                              style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                  height: 1.4)),
                        ),
                      ]),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // ── Soumission existante ──────────────────────────────────────
            if (_isSubmitted && sub != null) ...[
              _SectionTitle('Votre soumission'),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _kBlue.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: _kBlue.withValues(alpha: 0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Soumis le ${DateFormat('dd/MM/yyyy à HH:mm').format(sub.createdAt)}',
                      style: const TextStyle(
                          color: Colors.white38, fontSize: 11),
                    ),
                    if (sub.textReponse.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(sub.textReponse,
                          style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                              height: 1.4)),
                    ],
                    if (sub.tousLesFichiers.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      ...sub.tousLesFichiers.map(
                        (f) => _AttachmentTile(
                          nom: f['nom'] ?? 'Fichier',
                          type: f['type'] ?? '',
                          url: f['url'] ?? '',
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // ── Formulaire de soumission ──────────────────────────────────
            if (!_isCorrected && !(_isExpired && !_isSubmitted)) ...[
              _SectionTitle(_isSubmitted
                  ? 'Modifier votre réponse'
                  : 'Votre réponse'),
              const SizedBox(height: 6),
              // Texte
              TextField(
                controller: _textCtrl,
                maxLines: 6,
                style: const TextStyle(
                    color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Tapez votre réponse ici…',
                  hintStyle: const TextStyle(
                      color: Colors.white24, fontSize: 13),
                  filled: true,
                  fillColor: _kCard2,
                  contentPadding: const EdgeInsets.all(12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _commentCtrl,
                maxLines: 2,
                style: const TextStyle(
                    color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Commentaire pour le professeur (optionnel)',
                  hintStyle: const TextStyle(
                      color: Colors.white24, fontSize: 12),
                  filled: true,
                  fillColor: _kCard2,
                  contentPadding: const EdgeInsets.all(12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              // Nouveaux fichiers
              if (_fichiers.isNotEmpty) ...[
                Wrap(spacing: 6, runSpacing: 4, children: [
                  ..._fichiers.asMap().entries.map((e) => Container(
                        padding: const EdgeInsets.fromLTRB(8, 4, 4, 4),
                        decoration: BoxDecoration(
                          color:
                              _kPurple.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: _kPurple.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                          const Icon(Icons.attach_file,
                              size: 12, color: _kPurple),
                          const SizedBox(width: 4),
                          ConstrainedBox(
                            constraints:
                                const BoxConstraints(maxWidth: 130),
                            child: Text(_nomsF[e.key],
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    color: _kPurple, fontSize: 11)),
                          ),
                          const SizedBox(width: 4),
                          GestureDetector(
                            onTap: () => setState(() {
                              _fichiers.removeAt(e.key);
                              _nomsF.removeAt(e.key);
                            }),
                            child: const Icon(Icons.close,
                                size: 12, color: _kPurple),
                          ),
                        ]),
                      )),
                ]),
                const SizedBox(height: 8),
              ],
              // Boutons ajouter fichiers
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _kPurple,
                      side: BorderSide(
                          color: _kPurple.withValues(alpha: 0.5)),
                    ),
                    icon: const Icon(Icons.attach_file, size: 16),
                    label: const Text('Fichier',
                        style: TextStyle(fontSize: 12)),
                    onPressed: _pickFiles,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _kBlue,
                      side:
                          BorderSide(color: _kBlue.withValues(alpha: 0.5)),
                    ),
                    icon: const Icon(Icons.photo_camera_outlined,
                        size: 16),
                    label: const Text('Photo',
                        style: TextStyle(fontSize: 12)),
                    onPressed: () => _pickImage(ImageSource.camera),
                  ),
                ),
              ]),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kPurple,
                    foregroundColor: Colors.white,
                    padding:
                        const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: _saving ? null : _submit,
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : Text(
                          _isSubmitted
                              ? 'Mettre à jour la soumission'
                              : 'Soumettre le devoir',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold)),
                ),
              ),
            ],
            if (_isExpired && !_isSubmitted)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _kRed.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: _kRed.withValues(alpha: 0.25)),
                ),
                child: const Row(children: [
                  Icon(Icons.lock_clock_outlined,
                      color: _kRed, size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'La date limite est dépassée. Vous ne pouvez plus soumettre ce devoir.',
                      style: TextStyle(
                          color: Colors.white54, fontSize: 12),
                    ),
                  ),
                ]),
              ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

String _mention(double grade, double bareme) {
  final pct = bareme > 0 ? grade / bareme * 20 : 0.0;
  if (pct >= 16) return 'TB';
  if (pct >= 14) return 'B';
  if (pct >= 12) return 'AB';
  if (pct >= 10) return 'P';
  return 'Insuffisant';
}

class _Section extends StatelessWidget {
  final Widget child;
  const _Section({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: child,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        color: Colors.white38,
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
      ),
    );
  }
}

class _AttachmentTile extends StatelessWidget {
  final String nom;
  final String type;
  final String url;
  const _AttachmentTile(
      {required this.nom, required this.type, required this.url});

  @override
  Widget build(BuildContext context) {
    final isPdf = type == 'pdf';
    final isImage =
        ['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(type);
    final icon = isPdf
        ? Icons.picture_as_pdf_outlined
        : isImage
            ? Icons.image_outlined
            : Icons.insert_drive_file_outlined;
    final color = isPdf
        ? _kRed
        : isImage
            ? _kBlue
            : _kOrange;

    return InkWell(
      onTap: url.isNotEmpty ? () => launchUrl(Uri.parse(url)) : null,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border:
              Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(nom,
                style: const TextStyle(
                    color: Colors.white70, fontSize: 12),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ),
          Icon(Icons.open_in_new_outlined,
              color: Colors.white24, size: 14),
        ]),
      ),
    );
  }
}
