import 'dart:io';
import 'dart:math';

import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../models/inscription_model.dart';
import 'inscription_service.dart';

/// Sélection, sauvegarde et extraction des données d'un PDF d'inscription.
///
/// Le projet ne contient aucun moteur d'OCR / extraction de texte PDF.
/// Comme pour AiResponseService (déjà simulé côté "IA"),
/// l'extraction ici génère un brouillon plausible que la Direction corrige
/// ensuite à l'écran de vérification — aucun élève n'est créé avant cette
/// validation manuelle.
class PdfInscriptionService {
  static final _storage = FirebaseStorage.instanceFor(bucket: 'gs://ilyasapp-4762c.firebasestorage.app');
  static final _rand = Random();

  static String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  // ── Sélection du PDF ──────────────────────────────────────────────────────

  static Future<File?> pickPdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    final path = result?.files.single.path;
    if (path == null) return null;
    return File(path);
  }

  // ── Sauvegarde dans Firebase Storage ──────────────────────────────────────

  static Future<String?> uploadPdf(File file, String fileName) async {
    final uid = _uid;
    if (uid == null) return null;
    try {
      final token = List.generate(
        36,
        (_) => 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'[
            _rand.nextInt(62)],
      ).join();
      final safeName = '${DateTime.now().millisecondsSinceEpoch}_$fileName';
      final ref = _storage.ref().child('inscriptions_pdf/$uid/$safeName');
      final task = await ref.putFile(
        file,
        SettableMetadata(
          contentType: 'application/pdf',
          customMetadata: {'firebaseStorageDownloadTokens': token},
        ),
      );
      if (task.state == TaskState.success) {
        final bucket      = task.ref.bucket;
        final encodedPath = Uri.encodeComponent(task.ref.fullPath);
        return 'https://firebasestorage.googleapis.com/v0/b/$bucket/o/$encodedPath?alt=media&token=$token';
      }
    } catch (_) {}
    return null;
  }

  // ── Extraction simulée ────────────────────────────────────────────────────

  static const _prenoms = [
    'Amine', 'Yasmine', 'Sofia', 'Adam', 'Lina', 'Rayan',
    'Nour', 'Ilyas', 'Sara', 'Mehdi', 'Salma', 'Yanis',
  ];
  static const _noms = [
    'Benali', 'El Amrani', 'Tazi', 'Chraibi', 'Idrissi',
    'Bensaid', 'Alaoui', 'Cherkaoui', 'Naciri', 'Bouzid',
  ];
  static const _classes = [
    'CP', 'CE1', 'CE2', 'CM1', 'CM2', '6ème', '5ème', '4ème', '3ème',
  ];
  static const _villes = ['Rabat', 'Casablanca', 'Fès', 'Marrakech', 'Tanger', 'Agadir'];
  static const _liens = ['Grand-parent', 'Oncle', 'Tante', 'Voisin', 'Frère/Sœur aîné(e)'];

  static String _pick(List<String> l) => l[_rand.nextInt(l.length)];

  static String _phone() =>
      '06${List.generate(8, (_) => _rand.nextInt(10)).join()}';

  static Future<_ExtractedData> _simulateExtraction() async {
    await Future.delayed(Duration(milliseconds: 900 + _rand.nextInt(900)));

    final prenom = _pick(_prenoms);
    final nom = _pick(_noms);
    final birthYear = DateTime.now().year - (5 + _rand.nextInt(12));
    final slug = nom.toLowerCase().replaceAll(' ', '');

    final eleve = EleveInfo(
      nom: nom,
      prenom: prenom,
      dateNaissance:
          DateTime(birthYear, 1 + _rand.nextInt(12), 1 + _rand.nextInt(28)),
      sexe: _rand.nextBool() ? 'Masculin' : 'Féminin',
      adresse: '${1 + _rand.nextInt(200)} Rue ${_pick(_noms)}, ${_pick(_villes)}',
      classeDemandee: _pick(_classes),
    );
    final parent1 = ParentInfo(
      nomComplet: '${_pick(_prenoms)} $nom',
      telephone: _phone(),
      email: '$slug.parent1@example.com',
    );
    final parent2 = ParentInfo(
      nomComplet: '${_pick(_prenoms)} $nom',
      telephone: _phone(),
      email: '$slug.parent2@example.com',
    );
    final urgence = ContactUrgence(
      nom: '${_pick(_prenoms)} $nom',
      telephone: _phone(),
      lien: _pick(_liens),
    );

    return _ExtractedData(eleve, parent1, parent2, urgence);
  }

  // ── Pipeline complet : sélection → upload → extraction → brouillon ──────

  static Future<Inscription?> importAndCreateDraft({
    required File file,
    required String fileName,
    void Function(double progress)? onProgress,
  }) async {
    onProgress?.call(0.05);
    final pdfUrl = await uploadPdf(file, fileName);
    onProgress?.call(0.45);
    if (pdfUrl == null) return null;

    final extracted = await _simulateExtraction();
    onProgress?.call(0.85);

    final id = await InscriptionService.createDraft(
      pdfUrl: pdfUrl,
      pdfName: fileName,
      eleve: extracted.eleve,
      parent1: extracted.parent1,
      parent2: extracted.parent2,
      urgence: extracted.urgence,
    );
    onProgress?.call(1.0);

    return Inscription(
      id: id,
      pdfUrl: pdfUrl,
      pdfName: fileName,
      eleve: extracted.eleve,
      parent1: extracted.parent1,
      parent2: extracted.parent2,
      urgence: extracted.urgence,
      dateImport: DateTime.now(),
    );
  }
}

class _ExtractedData {
  final EleveInfo eleve;
  final ParentInfo parent1;
  final ParentInfo parent2;
  final ContactUrgence urgence;
  const _ExtractedData(this.eleve, this.parent1, this.parent2, this.urgence);
}
