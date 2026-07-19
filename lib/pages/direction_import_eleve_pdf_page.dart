import 'dart:math';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../models/classe_model.dart';
import '../models/student_import_result.dart';
import '../services/document_import/eleve_document_import_service.dart';
import '../services/eleve_account_service.dart';

/// Réplique locale de la hiérarchie scolaire (voir aussi
/// `direction_eleves_page.dart`, dont la constante équivalente est privée
/// au fichier) — sert uniquement à déduire la catégorie à partir du niveau
/// de la classe reconnue/sélectionnée.
const Map<String, List<String>> _kNiveauxParCategorie = {
  'Maternelle': ['PS', 'MS', 'GS'],
  'Primaire': ['CP', 'CE1', 'CE2', 'CM1', 'CM2'],
  'Collège': ['6e', '5e', '4e', '3e'],
  'Lycée': ['Seconde', 'Première', 'Terminale'],
  'Université': ['L1', 'L2', 'L3', 'M1', 'M2', 'Doctorat'],
};

const _kBg = Color(0xFF0D1117);
const _kCard = Color(0xFF161B22);
const _kField = Color(0xFF0D1117);
const _kBlue = Color(0xFF2563EB);
const _kGreen = Color(0xFF16A34A);
const _kAmber = Color(0xFFD97706);
const _kRed = Color(0xFFDC2626);

enum _Step { pick, processing, review, error }

/// Import automatique d'un dossier élève depuis un PDF scanné (OCR local).
///
/// Pipeline : sélection du PDF → [EleveDocumentImportService] (rendu des
/// pages + OCR ML Kit + reconnaissance de champs) → formulaire de relecture
/// pré-rempli (champs non reconnus mis en évidence) → création du compte
/// élève via [EleveAccountService.creerEleve], la même logique que l'ajout
/// manuel dans `direction_eleves_page.dart`.
class DirectionImportElevePdfPage extends StatefulWidget {
  const DirectionImportElevePdfPage({super.key});

  @override
  State<DirectionImportElevePdfPage> createState() =>
      _DirectionImportElevePdfPageState();
}

class _DirectionImportElevePdfPageState
    extends State<DirectionImportElevePdfPage> {
  _Step _step = _Step.pick;
  String? _errorMessage;
  String? _pdfName;
  bool _submitting = false;

  late final EleveDocumentImportService _importService =
      EleveDocumentImportService();

  StudentImportResult? _result;
  List<ClasseModel> _classes = [];
  ClasseModel? _selectedClasse;

  final _prenomCtrl = TextEditingController();
  final _nomCtrl = TextEditingController();
  final _dateNaissanceCtrl = TextEditingController();
  final _matriculeCtrl = TextEditingController();
  final _pereNomCtrl = TextEditingController();
  final _pereTelCtrl = TextEditingController();
  final _pereEmailCtrl = TextEditingController();
  final _mereNomCtrl = TextEditingController();
  final _mereTelCtrl = TextEditingController();
  final _mereEmailCtrl = TextEditingController();
  final _adresseCtrl = TextEditingController();
  final _villeCtrl = TextEditingController();
  final _urgenceNomCtrl = TextEditingController();
  final _urgenceTelCtrl = TextEditingController();
  final _autresInfosCtrl = TextEditingController();
  final _emailEleveCtrl = TextEditingController();
  final _pwdCtrl = TextEditingController();
  String? _sexe;
  bool _pwdVisible = false;

  @override
  void dispose() {
    _importService.dispose();
    for (final c in [
      _prenomCtrl, _nomCtrl, _dateNaissanceCtrl, _matriculeCtrl,
      _pereNomCtrl, _pereTelCtrl, _pereEmailCtrl,
      _mereNomCtrl, _mereTelCtrl, _mereEmailCtrl,
      _adresseCtrl, _villeCtrl, _urgenceNomCtrl, _urgenceTelCtrl,
      _autresInfosCtrl, _emailEleveCtrl, _pwdCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickAndExtract() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null) {
      setState(() {
        _step = _Step.error;
        _errorMessage = 'Impossible de lire le fichier sélectionné.';
      });
      return;
    }

    setState(() {
      _step = _Step.processing;
      _pdfName = file.name;
      _errorMessage = null;
    });

    try {
      final extraction = await _importService.extractFromPdf(
          Uint8List.fromList(bytes));
      if (!mounted) return;
      await _loadClasses();
      _fillControllers(extraction);
      setState(() {
        _result = extraction;
        _step = _Step.review;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _step = _Step.error;
        _errorMessage = "Échec de l'analyse du document : $e";
      });
    }
  }

  Future<void> _loadClasses() async {
    try {
      final snap =
          await FirebaseFirestore.instance.collection('classes').orderBy('nom').get();
      _classes = snap.docs.map(ClasseModel.fromFirestore).toList();
    } catch (_) {
      _classes = [];
    }
  }

  void _fillControllers(StudentImportResult r) {
    _prenomCtrl.text = r.prenom.value ?? '';
    _nomCtrl.text = r.nom.value ?? '';
    _dateNaissanceCtrl.text = r.dateNaissance.value ?? '';
    _sexe = (r.sexe.value == 'M' || r.sexe.value == 'F') ? r.sexe.value : null;
    _matriculeCtrl.text = r.matricule.value ?? '';
    _pereNomCtrl.text = r.pereNom.value ?? '';
    _pereTelCtrl.text = r.pereTelephone.value ?? '';
    _pereEmailCtrl.text = r.pereEmail.value ?? '';
    _mereNomCtrl.text = r.mereNom.value ?? '';
    _mereTelCtrl.text = r.mereTelephone.value ?? '';
    _mereEmailCtrl.text = r.mereEmail.value ?? '';
    _adresseCtrl.text = r.adresse.value ?? '';
    _villeCtrl.text = r.ville.value ?? '';
    _urgenceNomCtrl.text = r.contactUrgenceNom.value ?? '';
    _urgenceTelCtrl.text = r.contactUrgenceTelephone.value ?? '';
    _autresInfosCtrl.text = r.autresInfos;

    // Tentative de correspondance avec une classe existante.
    final classeTexte = r.classe.value;
    if (classeTexte != null && classeTexte.isNotEmpty && _classes.isNotEmpty) {
      final norm = _slug(classeTexte);
      for (final c in _classes) {
        if (_slug(c.nom).contains(norm) || norm.contains(_slug(c.nom))) {
          _selectedClasse = c;
          break;
        }
      }
    }

    // Compte élève : email + mot de passe temporaire générés (les dossiers
    // d'inscription papier ne contiennent pas d'email élève), modifiables
    // par la Direction avant validation.
    _emailEleveCtrl.text = _suggestEmail(_prenomCtrl.text, _nomCtrl.text);
    _pwdCtrl.text = _generateTempPassword();
  }

  String? _categorieFromClasse(ClasseModel? c) {
    if (c == null) return null;
    for (final entry in _kNiveauxParCategorie.entries) {
      if (entry.value.any((n) => n.toLowerCase() == c.niveau.toLowerCase())) {
        return entry.key;
      }
    }
    return null;
  }

  Future<void> _submit() async {
    final messenger = ScaffoldMessenger.of(context);
    final prenom = _prenomCtrl.text.trim();
    final nom = _nomCtrl.text.trim();
    final email = _emailEleveCtrl.text.trim();
    final pwd = _pwdCtrl.text.trim();
    if (prenom.isEmpty || nom.isEmpty || email.isEmpty || pwd.isEmpty) {
      messenger.showSnackBar(const SnackBar(
        content: Text('Le prénom, le nom, l\'email et le mot de passe du compte sont requis'),
        backgroundColor: _kRed,
      ));
      return;
    }
    if (pwd.length < 6) {
      messenger.showSnackBar(const SnackBar(
        content: Text('Mot de passe trop court (minimum 6 caractères)'),
        backgroundColor: _kRed,
      ));
      return;
    }

    setState(() => _submitting = true);
    final err = await EleveAccountService.creerEleve(
      prenom: prenom,
      nom: nom,
      email: email,
      password: pwd,
      adresse: _adresseCtrl.text.trim(),
      ville: _villeCtrl.text.trim(),
      categorie: _categorieFromClasse(_selectedClasse),
      classeId: _selectedClasse?.id,
      classeNom: _selectedClasse?.nom,
      niveau: _selectedClasse?.niveau,
      dateNaissance: _dateNaissanceCtrl.text.trim(),
      sexe: _sexe,
      matricule: _matriculeCtrl.text.trim(),
      pereNom: _pereNomCtrl.text.trim(),
      pereTelephone: _pereTelCtrl.text.trim(),
      pereEmail: _pereEmailCtrl.text.trim(),
      mereNom: _mereNomCtrl.text.trim(),
      mereTelephone: _mereTelCtrl.text.trim(),
      mereEmail: _mereEmailCtrl.text.trim(),
      contactUrgenceNom: _urgenceNomCtrl.text.trim(),
      contactUrgenceTelephone: _urgenceTelCtrl.text.trim(),
      autresInfos: _autresInfosCtrl.text.trim(),
      sendResetEmail: false,
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
    messenger.showSnackBar(SnackBar(
      content: Text('Élève $prenom $nom importé avec succès'),
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
        title: const Text('Importer un élève (PDF)',
            style: TextStyle(
                color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
      ),
      body: switch (_step) {
        _Step.pick => _buildPickStep(),
        _Step.processing => _buildProcessingStep(),
        _Step.error => _buildErrorStep(),
        _Step.review => _buildReviewStep(),
      },
    );
  }

  Widget _buildPickStep() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [_kBlue, _kGreen]),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.picture_as_pdf_outlined,
                  color: Colors.white, size: 36),
            ),
            const SizedBox(height: 20),
            const Text('Importer un dossier d\'inscription (PDF)',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            const Text(
              "L'extraction se fait localement sur l'appareil (OCR),\naucune donnée n'est envoyée à un service distant.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white38, fontSize: 12.5),
            ),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              onPressed: _pickAndExtract,
              icon: const Icon(Icons.upload_file_outlined),
              label: const Text('Choisir un PDF'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _kBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProcessingStep() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: _kBlue),
          const SizedBox(height: 20),
          Text(_pdfName ?? '',
              style: const TextStyle(color: Colors.white54, fontSize: 12)),
          const SizedBox(height: 8),
          const Text("Analyse du document en cours (OCR)…",
              style: TextStyle(color: Colors.white, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildErrorStep() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: _kRed, size: 48),
            const SizedBox(height: 16),
            Text(_errorMessage ?? 'Une erreur est survenue.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 13)),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => setState(() => _step = _Step.pick),
              style: ElevatedButton.styleFrom(
                backgroundColor: _kBlue,
                foregroundColor: Colors.white,
              ),
              child: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewStep() {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionTitle('Aperçu des données extraites'),
                const SizedBox(height: 4),
                Text(
                  '${_result?.champsReconnus ?? 0} champ(s) reconnu(s) automatiquement — vérifiez et corrigez si nécessaire.',
                  style: const TextStyle(color: Colors.white38, fontSize: 12),
                ),
                const SizedBox(height: 16),
                _sectionTitle('Élève'),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: _field(_prenomCtrl, 'Prénom', _result?.prenom)),
                  const SizedBox(width: 10),
                  Expanded(child: _field(_nomCtrl, 'Nom', _result?.nom)),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(
                      child: _field(_dateNaissanceCtrl,
                          'Date de naissance (AAAA-MM-JJ)', _result?.dateNaissance)),
                  const SizedBox(width: 10),
                  Expanded(child: _sexeFieldWithHelper()),
                ]),
                const SizedBox(height: 10),
                _classeField(),
                const SizedBox(height: 10),
                _field(_matriculeCtrl, 'Matricule (optionnel)', _result?.matricule),
                const SizedBox(height: 20),
                _sectionTitle('Père'),
                const SizedBox(height: 8),
                _field(_pereNomCtrl, 'Nom du père', _result?.pereNom),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: _field(_pereTelCtrl, 'Téléphone', _result?.pereTelephone)),
                  const SizedBox(width: 10),
                  Expanded(child: _field(_pereEmailCtrl, 'Email', _result?.pereEmail)),
                ]),
                const SizedBox(height: 20),
                _sectionTitle('Mère'),
                const SizedBox(height: 8),
                _field(_mereNomCtrl, 'Nom de la mère', _result?.mereNom),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: _field(_mereTelCtrl, 'Téléphone', _result?.mereTelephone)),
                  const SizedBox(width: 10),
                  Expanded(child: _field(_mereEmailCtrl, 'Email', _result?.mereEmail)),
                ]),
                const SizedBox(height: 20),
                _sectionTitle('Informations générales'),
                const SizedBox(height: 8),
                _field(_adresseCtrl, 'Adresse', _result?.adresse),
                const SizedBox(height: 10),
                _field(_villeCtrl, 'Ville', _result?.ville),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(
                      child: _field(_urgenceNomCtrl,
                          "Contact d'urgence — nom", _result?.contactUrgenceNom)),
                  const SizedBox(width: 10),
                  Expanded(
                      child: _field(_urgenceTelCtrl,
                          "Contact d'urgence — téléphone", _result?.contactUrgenceTelephone)),
                ]),
                const SizedBox(height: 10),
                _multilineField(_autresInfosCtrl,
                    'Autres informations détectées dans le document'),
                const SizedBox(height: 20),
                _sectionTitle('Compte élève'),
                const SizedBox(height: 4),
                const Text(
                  "Email et mot de passe temporaire générés automatiquement (absents des dossiers papier) — modifiables.",
                  style: TextStyle(color: Colors.white38, fontSize: 11.5),
                ),
                const SizedBox(height: 8),
                _field(_emailEleveCtrl, 'Email du compte élève', null),
                const SizedBox(height: 10),
                _passwordField(),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kGreen,
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
                    : const Text('Valider et créer l\'élève',
                        style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _sectionTitle(String title) => Text(title,
      style: const TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.3));

  /// Champ de saisie mettant en évidence (bordure ambre + libellé d'alerte)
  /// les champs que l'OCR n'a pas reconnus, conformément à la spécification.
  Widget _field(TextEditingController ctrl, String label, ExtractedField? extracted) {
    final notFound = extracted != null && !extracted.found;
    return TextField(
      controller: ctrl,
      style: const TextStyle(color: Colors.white, fontSize: 13.5),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
            color: notFound ? _kAmber : Colors.white38, fontSize: 12),
        helperText: notFound ? 'Non reconnu — à vérifier' : null,
        helperStyle: const TextStyle(color: _kAmber, fontSize: 10.5),
        filled: true,
        fillColor: _kField,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
              color: notFound
                  ? _kAmber.withValues(alpha: 0.6)
                  : Colors.white.withValues(alpha: 0.1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
              color: notFound
                  ? _kAmber.withValues(alpha: 0.6)
                  : Colors.white.withValues(alpha: 0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _kBlue),
        ),
      ),
    );
  }

  Widget _multilineField(TextEditingController ctrl, String label) {
    return TextField(
      controller: ctrl,
      maxLines: 4,
      minLines: 2,
      style: const TextStyle(color: Colors.white, fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white38, fontSize: 12),
        filled: true,
        fillColor: _kField,
        contentPadding: const EdgeInsets.all(12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
      ),
    );
  }

  Widget _passwordField() {
    return TextField(
      controller: _pwdCtrl,
      obscureText: !_pwdVisible,
      style: const TextStyle(color: Colors.white, fontSize: 13.5),
      decoration: InputDecoration(
        labelText: 'Mot de passe temporaire du compte élève',
        labelStyle: const TextStyle(color: Colors.white38, fontSize: 12),
        suffixIcon: IconButton(
          icon: Icon(
              _pwdVisible ? Icons.visibility_off_outlined : Icons.visibility_outlined,
              color: Colors.white38, size: 18),
          onPressed: () => setState(() => _pwdVisible = !_pwdVisible),
        ),
        filled: true,
        fillColor: _kField,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
      ),
    );
  }

  Widget _sexeField() {
    // Basé sur _sexe (l'état réel du dropdown) plutôt que sur
    // _result.sexe.found seul : un champ "trouvé" par l'OCR mais dont la
    // valeur n'a pas pu être normalisée en M/F laisserait sinon le
    // dropdown vide sans aucun signal visuel d'alerte pour la Direction.
    final notFound = _sexe == null;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: _kField,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: notFound
                ? _kAmber.withValues(alpha: 0.6)
                : Colors.white.withValues(alpha: 0.1)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _sexe,
          isExpanded: true,
          dropdownColor: _kCard,
          hint: Text('Sexe',
              style: TextStyle(
                  color: notFound ? _kAmber : Colors.white38, fontSize: 13)),
          items: const [
            DropdownMenuItem(value: 'M', child: Text('M', style: TextStyle(color: Colors.white))),
            DropdownMenuItem(value: 'F', child: Text('F', style: TextStyle(color: Colors.white))),
          ],
          onChanged: (v) => setState(() => _sexe = v),
        ),
      ),
    );
  }

  Widget _sexeFieldWithHelper() {
    final notFound = _sexe == null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sexeField(),
        if (notFound)
          const Padding(
            padding: EdgeInsets.only(top: 4, left: 4),
            child: Text('Non reconnu — à vérifier',
                style: TextStyle(color: _kAmber, fontSize: 10.5)),
          ),
      ],
    );
  }

  Widget _classeField() {
    final detected = _result?.classe.value;
    final notFound = _result != null && !_result!.classe.found;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (detected != null && detected.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text('Classe détectée dans le document : "$detected"',
                style: const TextStyle(color: Colors.white38, fontSize: 11)),
          ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: _kField,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: (notFound && _selectedClasse == null)
                    ? _kAmber.withValues(alpha: 0.6)
                    : Colors.white.withValues(alpha: 0.1)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<ClasseModel>(
              value: _selectedClasse,
              isExpanded: true,
              dropdownColor: _kCard,
              hint: const Text('Sélectionner la classe',
                  style: TextStyle(color: Colors.white38, fontSize: 13)),
              items: _classes
                  .map((c) => DropdownMenuItem(
                        value: c,
                        child: Text('${c.nom} (${c.niveau})',
                            style: const TextStyle(color: Colors.white, fontSize: 13)),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _selectedClasse = v),
            ),
          ),
        ),
      ],
    );
  }
}

String _suggestEmail(String prenom, String nom) {
  final base = _slug('$prenom.$nom');
  final suffix =
      DateTime.now().millisecondsSinceEpoch.toString().substring(7);
  return '${base.isEmpty ? 'eleve' : base}.$suffix@eleve.import.local';
}

String _slug(String s) {
  const from = 'àâäéèêëîïôöùûüçÀÂÄÉÈÊËÎÏÔÖÙÛÜÇ ';
  const to = 'aaaeeeeiioouuucAAAEEEEIIOOUUUC_';
  var out = s.toLowerCase();
  for (var i = 0; i < from.length; i++) {
    out = out.replaceAll(from[i].toLowerCase(), to[i].toLowerCase());
  }
  return out.replaceAll(RegExp(r'[^a-z0-9._]'), '');
}

String _generateTempPassword() {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnpqrstuvwxyz23456789';
  final rnd = Random.secure();
  return List.generate(10, (_) => chars[rnd.nextInt(chars.length)]).join();
}
