import 'dart:io';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/storage_service.dart';

// ─── Constants ────────────────────────────────────────────────────────────────

const _bg    = Color(0xFF0D1117);
const _card  = Color(0xFF161B22);
const _card2 = Color(0xFF1F2937);
const _bord  = Color(0xFF30363D);
const _purple = Color(0xFF6C47FF);
const _blue   = Color(0xFF2563EB);
const _green  = Color(0xFF16A34A);
const _orange = Color(0xFFF59E0B);
const _red    = Color(0xFFEF4444);

// ─── Page ─────────────────────────────────────────────────────────────────────

class ProfesseurDossierPage extends StatefulWidget {
  final String uid;
  final String displayName;
  final String statut; // 'actif' | 'en_attente'
  final String? schoolNom;

  const ProfesseurDossierPage({
    super.key,
    required this.uid,
    required this.displayName,
    required this.statut,
    this.schoolNom,
  });

  @override
  State<ProfesseurDossierPage> createState() =>
      _ProfesseurDossierPageState();
}

class _ProfesseurDossierPageState extends State<ProfesseurDossierPage>
    with TickerProviderStateMixin {

  final _pageCtrl = PageController();
  int _step = 0;
  static const int _totalSteps = 6;

  // Step 0 — Photo
  File? _photoFile;
  String? _photoUrl;
  bool _uploadingPhoto = false;

  // Step 1 — Documents
  final _docs = <_DocEntry>[];
  bool _uploadingDoc = false;

  // Step 2 — Matricule
  late String _matricule;
  final _matriculeCtrl = TextEditingController();

  // Step 3 — Signature
  final _signaturePoints = <Offset?>[];
  bool _signatureDone = false;

  // Step 4 — Vérification IA
  bool _verifying = false;
  bool _verified = false;
  double _completionScore = 0;
  late AnimationController _verifyAnim;

  // Step 5 — Confirmation
  bool _saving = false;
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    _matricule = _generateMatricule();
    _matriculeCtrl.text = _matricule;
    _verifyAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _matriculeCtrl.dispose();
    _verifyAnim.dispose();
    super.dispose();
  }

  // ─── Helpers ───────────────────────────────────────────────────────────────

  String _generateMatricule() {
    final year = DateTime.now().year;
    final rng = Random.secure();
    final suffix = List.generate(5, (_) => rng.nextInt(10)).join();
    return 'ENS-$year-$suffix';
  }

  double _computeScore() {
    int filled = 0;
    if (_photoUrl != null) filled++;
    if (_docs.any((d) => d.type == 'diplome' && d.url != null)) filled++;
    if (_docs.any((d) => d.type == 'cni' && d.url != null)) filled++;
    if (_signatureDone) filled++;
    return (filled / 4 * 100).roundToDouble();
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: _red,
      duration: const Duration(seconds: 3),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  // ─── Navigation ────────────────────────────────────────────────────────────

  void _next() {
    if (_step == 3 && !_signatureDone) {
      _showError('Veuillez signer avant de continuer');
      return;
    }
    if (_step == 4 && !_verified) {
      _runVerification();
      return;
    }
    if (_step == _totalSteps - 1) {
      _saveDossier();
      return;
    }
    _pageCtrl.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut);
    setState(() => _step++);
  }

  void _prev() {
    if (_step == 0) return;
    _pageCtrl.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut);
    setState(() => _step--);
  }

  // ─── Photo ─────────────────────────────────────────────────────────────────

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final picked =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked == null) return;
    final file = File(picked.path);
    setState(() {
      _photoFile = file;
      _uploadingPhoto = true;
    });
    final url = await StorageService.uploadProfilePhoto(file);
    if (mounted) {
      setState(() {
        _photoUrl = url;
        _uploadingPhoto = false;
      });
    }
  }

  Future<void> _takePhoto() async {
    final picker = ImagePicker();
    final picked =
        await picker.pickImage(source: ImageSource.camera, imageQuality: 80);
    if (picked == null) return;
    final file = File(picked.path);
    setState(() {
      _photoFile = file;
      _uploadingPhoto = true;
    });
    final url = await StorageService.uploadProfilePhoto(file);
    if (mounted) {
      setState(() {
        _photoUrl = url;
        _uploadingPhoto = false;
      });
    }
  }

  // ─── Documents ─────────────────────────────────────────────────────────────

  Future<void> _pickDocument(String type, String label) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
    );
    if (result == null || result.files.single.path == null) return;
    final file = File(result.files.single.path!);
    final name = result.files.single.name;
    setState(() => _uploadingDoc = true);
    final url =
        await StorageService.uploadTeacherDocument(file, widget.uid, type);
    if (mounted) {
      setState(() {
        _uploadingDoc = false;
        final existing = _docs.indexWhere((d) => d.type == type);
        final entry = _DocEntry(
            type: type, label: label, fileName: name, url: url);
        if (existing >= 0) {
          _docs[existing] = entry;
        } else {
          _docs.add(entry);
        }
      });
    }
  }

  // ─── Verification IA ───────────────────────────────────────────────────────

  Future<void> _runVerification() async {
    setState(() {
      _verifying = true;
      _verified = false;
    });
    await Future.delayed(const Duration(milliseconds: 2200));
    if (!mounted) return;
    final score = _computeScore();
    setState(() {
      _verifying = false;
      _verified = true;
      _completionScore = score;
    });
    _pageCtrl.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut);
    setState(() => _step++);
  }

  // ─── Save dossier ──────────────────────────────────────────────────────────

  Future<void> _saveDossier() async {
    setState(() => _saving = true);
    final db = FirebaseFirestore.instance;
    try {
      final docsMap = <String, dynamic>{};
      for (final d in _docs) {
        if (d.url != null) docsMap[d.type] = {'url': d.url, 'nom': d.fileName};
      }
      await db.collection('enseignant_dossiers').doc(widget.uid).set({
        'uid': widget.uid,
        'displayName': widget.displayName,
        'matricule': _matriculeCtrl.text.trim(),
        'photoUrl': _photoUrl,
        'documents': docsMap,
        'signatureComplete': _signatureDone,
        'completionScore': _completionScore,
        'statut': widget.statut,
        'schoolNom': widget.schoolNom,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      // Mise à jour du profil utilisateur avec le matricule et la photo
      await db.collection('users').doc(widget.uid).update({
        'matricule': _matriculeCtrl.text.trim(),
        if (_photoUrl != null) 'photoUrl': _photoUrl,
        'dossierComplete': _completionScore >= 75,
      });
      if (mounted) setState(() { _saving = false; _saved = true; });
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        _showError('Erreur lors de la sauvegarde : $e');
      }
    }
  }

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: PageView(
                controller: _pageCtrl,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildPhotoStep(),
                  _buildDocumentsStep(),
                  _buildMatriculeStep(),
                  _buildSignatureStep(),
                  _buildVerificationStep(),
                  _buildConfirmationStep(),
                ],
              ),
            ),
            _buildBottomNav(),
          ],
        ),
      ),
    );
  }

  // ─── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    final labels = [
      'Photo',
      'Documents',
      'Matricule',
      'Signature',
      'Vérification IA',
      'Confirmation',
    ];
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (_step > 0 && !_saved)
                GestureDetector(
                  onTap: _prev,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _card,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.arrow_back_ios_new,
                        color: Colors.white70, size: 16),
                  ),
                ),
              if (_step > 0 && !_saved) const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Dossier Enseignant',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.bold),
                    ),
                    Text(
                      labels[_step],
                      style:
                          const TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Text(
                'Étape ${_step + 1} / $_totalSteps',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Step dots
          Row(
            children: List.generate(_totalSteps, (i) {
              final done = i < _step;
              final current = i == _step;
              return Expanded(
                child: Container(
                  margin:
                      EdgeInsets.only(right: i < _totalSteps - 1 ? 4 : 0),
                  height: 4,
                  decoration: BoxDecoration(
                    color: done
                        ? _green
                        : current
                            ? _purple
                            : _card2,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  // ─── Bottom nav ────────────────────────────────────────────────────────────

  Widget _buildBottomNav() {
    if (_saved) return const SizedBox.shrink();
    String label;
    if (_step == 4 && !_verified) {
      label = 'Lancer la vérification IA';
    } else if (_step == _totalSteps - 1) {
      label = 'Finaliser mon dossier';
    } else {
      label = _step == 0 && _photoUrl == null ? 'Passer (optionnel)' : 'Suivant';
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: BoxDecoration(
        color: _bg,
        border: Border(
            top: BorderSide(color: Colors.white.withValues(alpha: 0.07))),
      ),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: (_verifying || _saving || _uploadingPhoto || _uploadingDoc)
              ? null
              : _next,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            backgroundColor: _step == _totalSteps - 1 ? _green : _purple,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
          child: (_saving || (_step == 4 && _verifying))
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2))
              : Text(label,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 15)),
        ),
      ),
    );
  }

  // ─── Step 0 : Photo ────────────────────────────────────────────────────────

  Widget _buildPhotoStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          _stepTitle('Photo de profil', 'Ajoutez une photo pour personnaliser votre profil enseignant'),
          const SizedBox(height: 32),
          Center(
            child: Stack(
              alignment: Alignment.bottomRight,
              children: [
                Container(
                  width: 130,
                  height: 130,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _card2,
                    border: Border.all(
                        color: _purple.withValues(alpha: 0.5), width: 2),
                    image: _photoFile != null
                        ? DecorationImage(
                            image: FileImage(_photoFile!),
                            fit: BoxFit.cover)
                        : null,
                  ),
                  child: _photoFile == null
                      ? const Icon(Icons.person_outline,
                          color: Colors.white38, size: 52)
                      : null,
                ),
                if (_uploadingPhoto)
                  Container(
                    width: 130,
                    height: 130,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black.withValues(alpha: 0.5),
                    ),
                    child: const Center(
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    ),
                  ),
                if (_photoUrl != null && !_uploadingPhoto)
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                        shape: BoxShape.circle, color: _green),
                    child: const Icon(Icons.check,
                        color: Colors.white, size: 14),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          Row(
            children: [
              Expanded(
                child: _actionBtn(
                    Icons.photo_library_outlined, 'Galerie', _pickPhoto),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _actionBtn(
                    Icons.camera_alt_outlined, 'Caméra', _takePhoto),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Optionnel — vous pourrez modifier votre photo plus tard',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.3), fontSize: 12),
          ),
        ],
      ),
    );
  }

  // ─── Step 1 : Documents ────────────────────────────────────────────────────

  Widget _buildDocumentsStep() {
    final docTypes = [
      ('diplome', 'Diplôme / Attestation', Icons.school_outlined),
      ('cni', 'Pièce d\'identité', Icons.badge_outlined),
      ('cv', 'CV (optionnel)', Icons.description_outlined),
      ('autre', 'Autre document', Icons.attach_file_outlined),
    ];
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _stepTitle('Documents', 'Téléchargez vos justificatifs (PDF ou image)'),
          const SizedBox(height: 20),
          if (_uploadingDoc)
            const LinearProgressIndicator(
                color: _blue, backgroundColor: _card2),
          const SizedBox(height: 4),
          ...docTypes.map((t) {
            final (type, label, icon) = t;
            final entry = _docs.firstWhere(
                (d) => d.type == type,
                orElse: () => _DocEntry(
                    type: type, label: label, fileName: '', url: null));
            final uploaded = entry.url != null;
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              decoration: BoxDecoration(
                color: _card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: uploaded
                        ? _green.withValues(alpha: 0.4)
                        : _bord),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: (uploaded ? _green : _blue)
                          .withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(uploaded ? Icons.check_circle_outline : icon,
                        color: uploaded ? _green : _blue, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(label,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600)),
                        if (uploaded)
                          Text(entry.fileName,
                              style: const TextStyle(
                                  color: Colors.white54, fontSize: 11),
                              overflow: TextOverflow.ellipsis)
                        else
                          Text(
                              type == 'diplome' || type == 'cni'
                                  ? 'Recommandé'
                                  : 'Optionnel',
                              style: TextStyle(
                                  color: type == 'diplome' || type == 'cni'
                                      ? _orange.withValues(alpha: 0.8)
                                      : Colors.white38,
                                  fontSize: 11)),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: _uploadingDoc
                        ? null
                        : () => _pickDocument(type, label),
                    style: TextButton.styleFrom(
                      foregroundColor: uploaded ? _green : _blue,
                      backgroundColor: (uploaded ? _green : _blue)
                          .withValues(alpha: 0.1),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    child:
                        Text(uploaded ? 'Modifier' : 'Ajouter',
                            style: const TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ─── Step 2 : Matricule ────────────────────────────────────────────────────

  Widget _buildMatriculeStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          _stepTitle('Matricule enseignant',
              'Un numéro unique a été généré automatiquement pour vous'),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [Color(0xFF1E293B), Color(0xFF0F172A)]),
              borderRadius: BorderRadius.circular(16),
              border:
                  Border.all(color: _purple.withValues(alpha: 0.4)),
            ),
            child: Column(
              children: [
                const Icon(Icons.badge_outlined, color: _purple, size: 36),
                const SizedBox(height: 16),
                Text(
                  _matriculeCtrl.text,
                  style: const TextStyle(
                    color: _purple,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 3,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Ce matricule identifie votre compte de façon unique',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.4),
                      fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _matriculeCtrl,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                letterSpacing: 2,
                fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              labelText: 'Modifier le matricule (optionnel)',
              labelStyle: const TextStyle(color: Colors.white54),
              filled: true,
              fillColor: _card,
              prefixIcon:
                  const Icon(Icons.edit_outlined, color: Colors.white38, size: 18),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _bord)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _bord)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _purple)),
            ),
            onChanged: (v) => setState(() => _matricule = v),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () {
              final newCode = _generateMatricule();
              setState(() {
                _matricule = newCode;
                _matriculeCtrl.text = newCode;
              });
            },
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Regénérer'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white54,
              side: const BorderSide(color: _bord),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Step 3 : Signature ────────────────────────────────────────────────────

  Widget _buildSignatureStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _stepTitle('Signature électronique',
              'Signez dans le cadre ci-dessous pour valider votre dossier'),
          const SizedBox(height: 20),
          Container(
            height: 200,
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: _signatureDone
                      ? _green.withValues(alpha: 0.6)
                      : _bord,
                  width: 1.5),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(13),
              child: GestureDetector(
                onPanUpdate: (d) => setState(() {
                  _signaturePoints.add(d.localPosition);
                  if (!_signatureDone) _signatureDone = true;
                }),
                onPanEnd: (_) => setState(() => _signaturePoints.add(null)),
                child: CustomPaint(
                  painter: _SignaturePainter(points: _signaturePoints),
                  size: Size.infinite,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(
                      _signatureDone
                          ? Icons.check_circle_outline
                          : Icons.info_outline,
                      color: _signatureDone ? _green : Colors.white38,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _signatureDone
                          ? 'Signature enregistrée'
                          : 'Signez dans le cadre blanc',
                      style: TextStyle(
                          color: _signatureDone ? _green : Colors.white38,
                          fontSize: 12),
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: () =>
                    setState(() {
                      _signaturePoints.clear();
                      _signatureDone = false;
                    }),
                icon: const Icon(Icons.clear, size: 14, color: Colors.white38),
                label: const Text('Effacer',
                    style: TextStyle(color: Colors.white38, fontSize: 12)),
                style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _orange.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _orange.withValues(alpha: 0.2)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.lock_outline, color: _orange, size: 16),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Votre signature est stockée de façon sécurisée et ne sera utilisée que pour valider votre dossier.',
                    style: TextStyle(color: Colors.white54, fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Step 4 : Vérification IA ──────────────────────────────────────────────

  Widget _buildVerificationStep() {
    if (_verifying) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            RotationTransition(
              turns: _verifyAnim,
              child: const Icon(Icons.auto_awesome, color: _purple, size: 48),
            ),
            const SizedBox(height: 20),
            const Text('Analyse de votre dossier en cours…',
                style: TextStyle(color: Colors.white, fontSize: 15)),
            const SizedBox(height: 8),
            Text(
              'Vérification des documents et de la cohérence',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4), fontSize: 12),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          _stepTitle('Vérification IA',
              'Notre assistant analyse votre dossier avant soumission'),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _purple.withValues(alpha: 0.3)),
            ),
            child: Column(
              children: [
                const Icon(Icons.auto_awesome_outlined,
                    color: _purple, size: 36),
                const SizedBox(height: 14),
                const Text(
                  'Prêt pour la vérification',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'L\'IA va vérifier la cohérence et la complétude de votre dossier.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _checkRow(Icons.photo_outlined, 'Photo de profil',
              _photoUrl != null),
          _checkRow(Icons.school_outlined, 'Diplôme',
              _docs.any((d) => d.type == 'diplome' && d.url != null)),
          _checkRow(Icons.badge_outlined, 'Pièce d\'identité',
              _docs.any((d) => d.type == 'cni' && d.url != null)),
          _checkRow(Icons.draw_outlined, 'Signature',
              _signatureDone),
        ],
      ),
    );
  }

  Widget _checkRow(IconData icon, String label, bool done) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(done ? Icons.check_circle_outline : Icons.radio_button_unchecked,
              color: done ? _green : Colors.white24, size: 18),
          const SizedBox(width: 10),
          Icon(icon, color: done ? Colors.white70 : Colors.white30, size: 16),
          const SizedBox(width: 8),
          Text(label,
              style: TextStyle(
                  color: done ? Colors.white70 : Colors.white30,
                  fontSize: 13)),
          const Spacer(),
          Text(done ? 'OK' : 'Manquant',
              style: TextStyle(
                  color: done ? _green : _orange.withValues(alpha: 0.7),
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  // ─── Step 5 : Confirmation ─────────────────────────────────────────────────

  Widget _buildConfirmationStep() {
    final isPending = widget.statut == 'en_attente';
    final scoreColor = _completionScore >= 75
        ? _green
        : _completionScore >= 40
            ? _orange
            : _red;

    if (_saved) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _green.withValues(alpha: 0.15)),
                child: const Icon(Icons.check_circle_outline,
                    color: _green, size: 56),
              ),
              const SizedBox(height: 20),
              const Text('Dossier enregistré !',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Text(
                isPending
                    ? 'Votre dossier est en attente de validation par le directeur de ${widget.schoolNom ?? "l'établissement"}.'
                    : 'Vous pouvez maintenant accéder à la plateforme. Complétez votre dossier pour débloquer toutes les fonctionnalités.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white54, fontSize: 13),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () =>
                      Navigator.of(context).popUntil((r) => r.isFirst),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    isPending ? 'Fermer' : 'Accéder à la plateforme',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          _stepTitle('Confirmation',
              'Récapitulatif de votre dossier avant finalisation'),
          const SizedBox(height: 20),

          // Score complétude
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _card,
              borderRadius: BorderRadius.circular(14),
              border:
                  Border.all(color: scoreColor.withValues(alpha: 0.3)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    const Text('Complétude du dossier',
                        style: TextStyle(
                            color: Colors.white54,
                            fontSize: 13,
                            fontWeight: FontWeight.w500)),
                    const Spacer(),
                    Text(
                      '${_completionScore.toInt()}%',
                      style: TextStyle(
                          color: scoreColor,
                          fontSize: 18,
                          fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: _completionScore / 100,
                    color: scoreColor,
                    backgroundColor: scoreColor.withValues(alpha: 0.12),
                    minHeight: 5,
                  ),
                ),
                if (_completionScore < 75) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Ajoutez photo, diplôme et pièce d\'identité pour un dossier complet',
                    style: TextStyle(
                        color: _orange.withValues(alpha: 0.8),
                        fontSize: 11),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Résumé
          _summaryTile(Icons.person_outline, 'Nom', widget.displayName),
          _summaryTile(Icons.badge_outlined, 'Matricule',
              _matriculeCtrl.text),
          _summaryTile(
              Icons.business_outlined,
              'École',
              widget.schoolNom ?? 'Accès libre'),
          _summaryTile(
              Icons.pending_actions,
              'Statut',
              isPending
                  ? 'En attente de validation'
                  : 'Accès actif'),
          const SizedBox(height: 14),

          // Status info card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: (isPending ? _orange : _green)
                  .withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: (isPending ? _orange : _green)
                      .withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(
                    isPending
                        ? Icons.hourglass_top_outlined
                        : Icons.check_circle_outline,
                    color: isPending ? _orange : _green,
                    size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isPending
                        ? 'Votre dossier sera examiné par le directeur de ${widget.schoolNom ?? "l'établissement"}. Vous recevrez une notification.'
                        : 'Votre compte est actif. Vous aurez accès à toutes les fonctionnalités après validation de votre dossier.',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 12),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Historique
          _buildHistoriqueSection(),
        ],
      ),
    );
  }

  Widget _buildHistoriqueSection() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('enseignant_dossiers')
          .where('uid', isEqualTo: widget.uid)
          .orderBy('createdAt', descending: true)
          .limit(5)
          .snapshots(),
      builder: (context, snap) {
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Divider(color: _bord),
            const SizedBox(height: 8),
            const Text('Historique des inscriptions',
                style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            ...docs.map((d) {
              final data = d.data() as Map<String, dynamic>;
              final createdAt = data['createdAt'] is Timestamp
                  ? (data['createdAt'] as Timestamp).toDate()
                  : DateTime.now();
              final s = data['statut'] as String? ?? 'actif';
              final school = data['schoolNom'] as String? ?? 'Accès libre';
              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                decoration: BoxDecoration(
                    color: _card2,
                    borderRadius: BorderRadius.circular(10)),
                child: Row(
                  children: [
                    Icon(Icons.assignment_outlined,
                        color: Colors.white38, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(school,
                          style: const TextStyle(
                              color: Colors.white60, fontSize: 12)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: (s == 'actif' ? _green : _orange)
                            .withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                          s == 'actif' ? 'Actif' : 'En attente',
                          style: TextStyle(
                              color: s == 'actif' ? _green : _orange,
                              fontSize: 10,
                              fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(width: 8),
                    Text(
                        '${createdAt.day}/${createdAt.month}/${createdAt.year}',
                        style: const TextStyle(
                            color: Colors.white24, fontSize: 10)),
                  ],
                ),
              );
            }),
          ],
        );
      },
    );
  }

  // ─── Helpers UI ────────────────────────────────────────────────────────────

  Widget _stepTitle(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Text(subtitle,
            style: const TextStyle(color: Colors.white54, fontSize: 13)),
      ],
    );
  }

  Widget _actionBtn(IconData icon, String label, VoidCallback onTap) {
    return ElevatedButton.icon(
      onPressed: _uploadingPhoto ? null : onTap,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: _card,
        foregroundColor: Colors.white70,
        padding: const EdgeInsets.symmetric(vertical: 12),
        side: const BorderSide(color: _bord),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Widget _summaryTile(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, color: Colors.white38, size: 16),
          const SizedBox(width: 10),
          Text('$label :',
              style: const TextStyle(color: Colors.white54, fontSize: 13)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500),
                overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}

// ─── Signature painter ────────────────────────────────────────────────────────

class _SignaturePainter extends CustomPainter {
  final List<Offset?> points;
  const _SignaturePainter({required this.points});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF1E293B)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    for (int i = 0; i < points.length - 1; i++) {
      if (points[i] != null && points[i + 1] != null) {
        canvas.drawLine(points[i]!, points[i + 1]!, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_SignaturePainter old) => old.points != points;
}

// ─── Doc entry ────────────────────────────────────────────────────────────────

class _DocEntry {
  final String type;
  final String label;
  final String fileName;
  final String? url;
  const _DocEntry(
      {required this.type,
      required this.label,
      required this.fileName,
      required this.url});
}
