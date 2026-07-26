import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/support_ticket_model.dart';
import '../services/support_service.dart';

const _kBg = Color(0xFF0D1117);
const _kCard = Color(0xFF161B22);
const _kField = Color(0xFF0D1117);
const _kBlue = Color(0xFF2563EB);
const _kGreen = Color(0xFF16A34A);
const _kRed = Color(0xFFDC2626);

/// Formulaire d'envoi d'une demande de support (bug, suggestion, question,
/// avis), accessible depuis le profil de tout rôle (élève, professeur,
/// parent, Direction). Voir [SupportService.creerTicket] pour le pipeline
/// d'enregistrement (Firestore + capture d'écran optionnelle sur Storage).
class SupportFormPage extends StatefulWidget {
  const SupportFormPage({super.key});

  @override
  State<SupportFormPage> createState() => _SupportFormPageState();
}

class _SupportFormPageState extends State<SupportFormPage> {
  SupportTicketType _type = SupportTicketType.bug;
  final _sujetCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  File? _screenshot;
  bool _submitting = false;

  @override
  void dispose() {
    _sujetCtrl.dispose();
    _descriptionCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickScreenshot() async {
    final picked = await ImagePicker()
        .pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked == null) return;
    setState(() => _screenshot = File(picked.path));
  }

  Future<void> _submit() async {
    final messenger = ScaffoldMessenger.of(context);
    final sujet = _sujetCtrl.text.trim();
    final description = _descriptionCtrl.text.trim();
    if (sujet.isEmpty || description.isEmpty) {
      messenger.showSnackBar(const SnackBar(
        content: Text('Le sujet et la description sont requis'),
        backgroundColor: _kRed,
      ));
      return;
    }

    setState(() => _submitting = true);
    final err = await SupportService.creerTicket(
      type: _type,
      sujet: sujet,
      description: description,
      screenshot: _screenshot,
    );
    if (!mounted) return;
    setState(() => _submitting = false);

    if (err != null) {
      messenger.showSnackBar(SnackBar(
        content: Text(err),
        backgroundColor: _kRed,
        duration: const Duration(seconds: 6),
      ));
      return;
    }
    messenger.showSnackBar(const SnackBar(
      content: Text('Votre demande a été envoyée. Merci !'),
      backgroundColor: _kGreen,
    ));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kCard,
        elevation: 0,
        title: const Text('Support & Suggestions',
            style: TextStyle(
                color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Signalez un bug, proposez une amélioration, posez une question "
              "ou laissez votre avis — la Direction reçoit votre message avec "
              "les informations techniques nécessaires pour vous aider.",
              style: TextStyle(color: Colors.white38, fontSize: 12.5),
            ),
            const SizedBox(height: 20),
            _sectionTitle('Type de demande'),
            const SizedBox(height: 10),
            _typeSelector(),
            const SizedBox(height: 20),
            _sectionTitle('Sujet'),
            const SizedBox(height: 8),
            _textField(_sujetCtrl, 'Résumez votre demande en quelques mots'),
            const SizedBox(height: 20),
            _sectionTitle('Description'),
            const SizedBox(height: 8),
            _textField(
              _descriptionCtrl,
              'Décrivez en détail — pour un bug, précisez ce que vous '
              'faisiez et ce qui s\'est passé',
              maxLines: 6,
            ),
            const SizedBox(height: 20),
            _sectionTitle('Capture d\'écran (optionnel)'),
            const SizedBox(height: 8),
            _screenshotPicker(),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: _submitting
                    ? const SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Envoyer',
                        style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) => Text(title,
      style: const TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.3));

  Widget _typeSelector() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: SupportTicketType.values.map((t) {
        final selected = t == _type;
        return GestureDetector(
          onTap: () => setState(() => _type = t),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: selected ? t.color.withValues(alpha: 0.15) : _kCard,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: selected
                      ? t.color.withValues(alpha: 0.6)
                      : Colors.white.withValues(alpha: 0.08)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(t.icon, size: 16, color: selected ? t.color : Colors.white54),
                const SizedBox(width: 6),
                Text(t.label,
                    style: TextStyle(
                        color: selected ? t.color : Colors.white70,
                        fontSize: 12.5,
                        fontWeight: selected ? FontWeight.w700 : FontWeight.w500)),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _textField(TextEditingController ctrl, String hint, {int maxLines = 1}) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      minLines: maxLines > 1 ? 3 : 1,
      style: const TextStyle(color: Colors.white, fontSize: 13.5),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white24, fontSize: 12.5),
        filled: true,
        fillColor: _kField,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _kBlue),
        ),
      ),
    );
  }

  Widget _screenshotPicker() {
    if (_screenshot != null) {
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Image.file(_screenshot!, height: 180, width: double.infinity, fit: BoxFit.cover),
            Positioned(
              top: 6,
              right: 6,
              child: GestureDetector(
                onTap: () => setState(() => _screenshot = null),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                      color: Colors.black54, shape: BoxShape.circle),
                  child: const Icon(Icons.close, color: Colors.white, size: 16),
                ),
              ),
            ),
          ],
        ),
      );
    }
    return OutlinedButton.icon(
      onPressed: _pickScreenshot,
      icon: const Icon(Icons.image_outlined, size: 18),
      label: const Text('Choisir une capture d\'écran'),
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white70,
        side: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
