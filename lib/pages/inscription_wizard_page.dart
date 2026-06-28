import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/inscription_model.dart';
import '../services/inscription_service.dart';

// ─── Constants ───────────────────────────────────────────────────────────────
const _iwBg = Color(0xFF0D1117);
const _iwCard = Color(0xFF161B22);
const _iwCard2 = Color(0xFF1F2937);
const _iwBorder = Color(0xFF21262D);
const _iwBlue = Color(0xFF2563EB);
const _iwPurple = Color(0xFF6C47FF);

// ─── Cycles / Niveaux ─────────────────────────────────────────────────────────

const _cycles = ['Maternelle', 'Primaire', 'Collège', 'Lycée', 'Université'];

const _niveauxByCycle = <String, List<String>>{
  'Maternelle': ['PS', 'MS', 'GS'],
  'Primaire': ['1AP', '2AP', '3AP', '4AP', '5AP', '6AP'],
  'Collège': ['1AM', '2AM', '3AM', '4AM'],
  'Lycée': ['1AS', '2AS', '3AS'],
  'Université': ['L1', 'L2', 'L3', 'M1', 'M2', 'Doctorat'],
};

// ─── Page ─────────────────────────────────────────────────────────────────────

class InscriptionWizardPage extends StatefulWidget {
  final String? draftId;

  const InscriptionWizardPage({super.key, this.draftId});

  @override
  State<InscriptionWizardPage> createState() => _InscriptionWizardPageState();
}

class _InscriptionWizardPageState extends State<InscriptionWizardPage>
    with TickerProviderStateMixin {
  final _pageCtrl = PageController();
  int _currentStep = 0;
  static const int _totalSteps = 6;
  bool _saving = false;
  bool _submitted = false;
  String? _submittedId;

  // ── Step 1 : Infos élève ─────────────────────────────────────────────────
  final _nomCtrl = TextEditingController();
  final _prenomCtrl = TextEditingController();
  final _adresseCtrl = TextEditingController();
  final _telephoneCtrl = TextEditingController();
  final _emailEleveCtrl = TextEditingController();
  final _nationaliteCtrl = TextEditingController();
  String _sexe = '';
  DateTime? _dateNaissance;
  final _formKey1 = GlobalKey<FormState>();

  // ── Step 2 : Responsables ────────────────────────────────────────────────
  // Père
  final _pereNomCtrl = TextEditingController();
  final _pereProfCtrl = TextEditingController();
  final _pereTelCtrl = TextEditingController();
  final _pereEmailCtrl = TextEditingController();
  final _pereAdresseCtrl = TextEditingController();
  // Mère
  final _mereNomCtrl = TextEditingController();
  final _mereProfCtrl = TextEditingController();
  final _mereTelCtrl = TextEditingController();
  final _mereEmailCtrl = TextEditingController();
  final _mereAdresseCtrl = TextEditingController();
  // Tuteur
  final _tuteurNomCtrl = TextEditingController();
  final _tuteurProfCtrl = TextEditingController();
  final _tuteurTelCtrl = TextEditingController();
  final _tuteurEmailCtrl = TextEditingController();
  final _tuteurAdresseCtrl = TextEditingController();

  bool _pereExpanded = true;
  bool _mereExpanded = false;
  bool _tuteurExpanded = false;

  // ── Step 3 : Scolarité ───────────────────────────────────────────────────
  String _selectedCycle = '';
  String _selectedNiveau = '';
  String _selectedClasse = '';
  final _etablissementCtrl = TextEditingController();

  // ── Step 4 : Documents ───────────────────────────────────────────────────
  final List<_DocItem> _docs = [
    _DocItem('Carte d\'identité nationale'),
    _DocItem('Certificat de naissance'),
    _DocItem('Bulletins scolaires (dernière année)'),
    _DocItem('Photos d\'identité (x4)'),
    _DocItem('Certificat médical'),
    _DocItem('Justificatif de domicile'),
  ];

  // ── Step 5 : Vérification IA ─────────────────────────────────────────────
  Future<List<_IaCheckResult>>? _iaCheckFuture;

  // ── Step 6 : Validation ──────────────────────────────────────────────────
  // (uses _submitted flag)

  @override
  void initState() {
    super.initState();
    if (widget.draftId != null) {
      _loadDraft();
    }
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _nomCtrl.dispose();
    _prenomCtrl.dispose();
    _adresseCtrl.dispose();
    _telephoneCtrl.dispose();
    _emailEleveCtrl.dispose();
    _nationaliteCtrl.dispose();
    _pereNomCtrl.dispose();
    _pereProfCtrl.dispose();
    _pereTelCtrl.dispose();
    _pereEmailCtrl.dispose();
    _pereAdresseCtrl.dispose();
    _mereNomCtrl.dispose();
    _mereProfCtrl.dispose();
    _mereTelCtrl.dispose();
    _mereEmailCtrl.dispose();
    _mereAdresseCtrl.dispose();
    _tuteurNomCtrl.dispose();
    _tuteurProfCtrl.dispose();
    _tuteurTelCtrl.dispose();
    _tuteurEmailCtrl.dispose();
    _tuteurAdresseCtrl.dispose();
    _etablissementCtrl.dispose();
    super.dispose();
  }

  // ── Draft load ────────────────────────────────────────────────────────────

  Future<void> _loadDraft() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('inscription_wizards')
          .doc(uid)
          .get();
      if (!doc.exists || !mounted) return;
      final d = doc.data() ?? {};
      setState(() {
        _nomCtrl.text = d['nom'] as String? ?? '';
        _prenomCtrl.text = d['prenom'] as String? ?? '';
        _adresseCtrl.text = d['adresse'] as String? ?? '';
        _telephoneCtrl.text = d['telephone'] as String? ?? '';
        _emailEleveCtrl.text = d['emailEleve'] as String? ?? '';
        _nationaliteCtrl.text = d['nationalite'] as String? ?? '';
        _sexe = d['sexe'] as String? ?? '';
        final ts = d['dateNaissance'] as Timestamp?;
        if (ts != null) {
          _dateNaissance = ts.toDate();
        }
        _selectedCycle = d['cycle'] as String? ?? '';
        _selectedNiveau = d['niveau'] as String? ?? '';
        _selectedClasse = d['classe'] as String? ?? '';
        _etablissementCtrl.text = d['etablissement'] as String? ?? '';
      });
    } catch (_) {}
  }

  // ── Auto-save ─────────────────────────────────────────────────────────────

  Future<void> _autoSave() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    setState(() => _saving = true);
    try {
      await FirebaseFirestore.instance
          .collection('inscription_wizards')
          .doc(uid)
          .set({
        'nom': _nomCtrl.text.trim(),
        'prenom': _prenomCtrl.text.trim(),
        'adresse': _adresseCtrl.text.trim(),
        'telephone': _telephoneCtrl.text.trim(),
        'emailEleve': _emailEleveCtrl.text.trim(),
        'nationalite': _nationaliteCtrl.text.trim(),
        'sexe': _sexe,
        if (_dateNaissance != null)
          'dateNaissance': Timestamp.fromDate(_dateNaissance!),
        'cycle': _selectedCycle,
        'niveau': _selectedNiveau,
        'classe': _selectedClasse,
        'etablissement': _etablissementCtrl.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
        'step': _currentStep,
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.cloud_done_outlined,
                    color: Colors.white, size: 16),
                SizedBox(width: 8),
                Text('Brouillon sauvegardé automatiquement'),
              ],
            ),
            duration: Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Color(0xFF16A34A),
          ),
        );
      }
    } catch (_) {}
    if (mounted) setState(() => _saving = false);
  }

  // ── Navigation ────────────────────────────────────────────────────────────

  bool _validateCurrentStep() {
    if (_currentStep == 0) {
      if (_nomCtrl.text.trim().isEmpty ||
          _prenomCtrl.text.trim().isEmpty ||
          _sexe.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Veuillez remplir les champs obligatoires (*)'),
            backgroundColor: Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return false;
      }
    }
    if (_currentStep == 1) {
      if (_pereNomCtrl.text.trim().isEmpty &&
          _mereNomCtrl.text.trim().isEmpty &&
          _tuteurNomCtrl.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('Renseignez au moins un responsable légal'),
            backgroundColor: Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return false;
      }
    }
    if (_currentStep == 2) {
      if (_selectedCycle.isEmpty || _selectedNiveau.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sélectionnez le cycle et le niveau'),
            backgroundColor: Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return false;
      }
    }
    return true;
  }

  Future<void> _goNext() async {
    if (!_validateCurrentStep()) return;
    await _autoSave();
    if (!mounted) return;
    if (_currentStep == 4) {
      // Start AI check
      setState(() {
        _iaCheckFuture = _runIaCheck();
      });
    }
    if (_currentStep < _totalSteps - 1) {
      setState(() => _currentStep++);
      _pageCtrl.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    }
  }

  void _goPrev() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _pageCtrl.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    }
  }

  // ── IA Check (simulation) ────────────────────────────────────────────────

  Future<List<_IaCheckResult>> _runIaCheck() async {
    await Future.delayed(const Duration(seconds: 2));
    final results = <_IaCheckResult>[];

    // Required fields
    results.add(_IaCheckResult(
      label: 'Nom de l\'élève',
      status: _nomCtrl.text.trim().isNotEmpty
          ? _IaStatus.ok
          : _IaStatus.error,
    ));
    results.add(_IaCheckResult(
      label: 'Prénom de l\'élève',
      status: _prenomCtrl.text.trim().isNotEmpty
          ? _IaStatus.ok
          : _IaStatus.error,
    ));
    results.add(_IaCheckResult(
      label: 'Date de naissance',
      status: _dateNaissance != null ? _IaStatus.ok : _IaStatus.warning,
      note: _dateNaissance == null ? 'Recommandé pour le dossier' : null,
    ));
    results.add(_IaCheckResult(
      label: 'Sexe',
      status: _sexe.isNotEmpty ? _IaStatus.ok : _IaStatus.error,
    ));
    results.add(_IaCheckResult(
      label: 'Adresse',
      status: _adresseCtrl.text.trim().isNotEmpty
          ? _IaStatus.ok
          : _IaStatus.warning,
      note: _adresseCtrl.text.trim().isEmpty ? 'Optionnel mais recommandé' : null,
    ));
    results.add(_IaCheckResult(
      label: 'Email élève',
      status: _emailEleveCtrl.text.trim().isNotEmpty
          ? _IaStatus.ok
          : _IaStatus.warning,
      note: _emailEleveCtrl.text.trim().isEmpty
          ? 'Nécessaire pour créer le compte'
          : null,
    ));
    results.add(_IaCheckResult(
      label: 'Responsable légal',
      status: (_pereNomCtrl.text.trim().isNotEmpty ||
              _mereNomCtrl.text.trim().isNotEmpty ||
              _tuteurNomCtrl.text.trim().isNotEmpty)
          ? _IaStatus.ok
          : _IaStatus.error,
    ));
    results.add(_IaCheckResult(
      label: 'Cycle et niveau',
      status: (_selectedCycle.isNotEmpty && _selectedNiveau.isNotEmpty)
          ? _IaStatus.ok
          : _IaStatus.error,
    ));
    results.add(_IaCheckResult(
      label: 'Nationalité',
      status: _nationaliteCtrl.text.trim().isNotEmpty
          ? _IaStatus.ok
          : _IaStatus.warning,
      note: _nationaliteCtrl.text.trim().isEmpty ? 'Optionnel' : null,
    ));
    return results;
  }

  int _completenessScore(List<_IaCheckResult> results) {
    final ok = results.where((r) => r.status == _IaStatus.ok).length;
    return ((ok / results.length) * 100).round();
  }

  // ── Final Submit ──────────────────────────────────────────────────────────

  Future<void> _submit() async {
    setState(() => _saving = true);
    try {
      final eleve = EleveInfo(
        nom: _nomCtrl.text.trim(),
        prenom: _prenomCtrl.text.trim(),
        dateNaissance: _dateNaissance,
        sexe: _sexe,
        adresse: _adresseCtrl.text.trim(),
        classeDemandee: _selectedClasse.isNotEmpty
            ? _selectedClasse
            : '$_selectedCycle - $_selectedNiveau',
        emailEleve: _emailEleveCtrl.text.trim(),
      );

      final parent1 = _pereNomCtrl.text.trim().isNotEmpty
          ? ParentInfo(
              nomComplet: _pereNomCtrl.text.trim(),
              telephone: _pereTelCtrl.text.trim(),
              email: _pereEmailCtrl.text.trim(),
            )
          : ParentInfo(
              nomComplet: _mereNomCtrl.text.trim(),
              telephone: _mereTelCtrl.text.trim(),
              email: _mereEmailCtrl.text.trim(),
            );

      ParentInfo? parent2;
      if (_pereNomCtrl.text.trim().isNotEmpty &&
          _mereNomCtrl.text.trim().isNotEmpty) {
        parent2 = ParentInfo(
          nomComplet: _mereNomCtrl.text.trim(),
          telephone: _mereTelCtrl.text.trim(),
          email: _mereEmailCtrl.text.trim(),
        );
      }

      final urgence = ContactUrgence(
        nom: parent1.nomComplet,
        telephone: parent1.telephone,
        lien: _pereNomCtrl.text.trim().isNotEmpty ? 'Père' : 'Mère',
      );

      final id = await InscriptionService.createDraft(
        pdfUrl: '',
        pdfName: 'wizard',
        eleve: eleve,
        parent1: parent1,
        parent2: parent2,
        urgence: urgence,
      );

      // Clean up draft
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        await FirebaseFirestore.instance
            .collection('inscription_wizards')
            .doc(uid)
            .delete();
      }

      if (mounted) {
        setState(() {
          _saving = false;
          _submitted = true;
          _submittedId = id;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur : $e'),
            backgroundColor: const Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _iwBg,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: PageView(
              controller: _pageCtrl,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildStep1(),
                _buildStep2(),
                _buildStep3(),
                _buildStep4(),
                _buildStep5(),
                _buildStep6(),
              ],
            ),
          ),
          if (!_submitted) _buildNavBar(),
        ],
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    final stepLabels = [
      'Infos élève',
      'Responsables',
      'Scolarité',
      'Documents',
      'Vérification',
      'Validation',
    ];

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1A1040), Color(0xFF0F1B3D)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // AppBar row
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Inscription scolaire',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Étape ${_currentStep + 1} / $_totalSteps — ${stepLabels[_currentStep]}',
                          style: const TextStyle(
                              color: Colors.white54, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  if (_saving)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white54),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Progress bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: (_currentStep + 1) / _totalSteps,
                  minHeight: 6,
                  backgroundColor: Colors.white12,
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(_iwPurple),
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Step dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_totalSteps, (i) {
                final active = i == _currentStep;
                final done = i < _currentStep;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: active ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    gradient: done || active
                        ? const LinearGradient(
                            colors: [_iwPurple, _iwBlue])
                        : null,
                    color: (!done && !active) ? Colors.white12 : null,
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  // ── Step 1 : Infos élève ─────────────────────────────────────────────────

  Widget _buildStep1() {
    final year = DateTime.now().year;
    final matriculePreview =
        'MAT-$year-${(1000 + (DateTime.now().millisecond % 9000)).toString()}';

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
      child: Form(
        key: _formKey1,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Photo
            Center(
              child: Stack(
                children: [
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [_iwPurple, _iwBlue]),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.person_outline,
                        color: Colors.white, size: 42),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: () {
                        // TODO: implement image picker
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Sélection photo : bientôt disponible'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: _iwCard,
                          shape: BoxShape.circle,
                          border: Border.all(color: _iwBorder),
                        ),
                        child: const Icon(Icons.camera_alt,
                            color: _iwPurple, size: 15),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Matricule (display only)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _iwCard,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _iwPurple.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.badge_outlined,
                      color: _iwPurple, size: 18),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Matricule (généré automatiquement)',
                          style: TextStyle(
                              color: Colors.white38, fontSize: 10)),
                      Text(matriculePreview,
                          style: const TextStyle(
                              color: _iwPurple,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            _WizardField(ctrl: _nomCtrl, label: 'Nom *', hint: 'Nom de famille'),
            _WizardField(ctrl: _prenomCtrl, label: 'Prénom *', hint: 'Prénom'),

            // Sexe
            const _FieldLabel('Sexe *'),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              initialValue: _sexe.isNotEmpty ? _sexe : null,
              decoration: _dropDecoration('Sélectionner'),
              dropdownColor: _iwCard2,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              onChanged: (v) => setState(() => _sexe = v ?? ''),
              items: ['Masculin', 'Féminin', 'Autre']
                  .map((s) => DropdownMenuItem(
                      value: s,
                      child: Text(s,
                          style: const TextStyle(color: Colors.white))))
                  .toList(),
            ),
            const SizedBox(height: 14),

            // Date de naissance
            const _FieldLabel('Date de naissance'),
            const SizedBox(height: 6),
            GestureDetector(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate:
                      _dateNaissance ?? DateTime(DateTime.now().year - 10),
                  firstDate: DateTime(1990),
                  lastDate: DateTime.now(),
                  builder: (ctx, child) => Theme(
                    data: ThemeData.dark().copyWith(
                      colorScheme: const ColorScheme.dark(
                          primary: _iwPurple, surface: _iwCard),
                    ),
                    child: child!,
                  ),
                );
                if (picked != null && mounted) {
                  setState(() => _dateNaissance = picked);
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 14),
                decoration: BoxDecoration(
                  color: _iwCard2,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _iwBorder),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today_outlined,
                        color: Colors.white38, size: 18),
                    const SizedBox(width: 10),
                    Text(
                      _dateNaissance != null
                          ? '${_dateNaissance!.day}/${_dateNaissance!.month}/${_dateNaissance!.year}'
                          : 'Sélectionner une date',
                      style: TextStyle(
                          color: _dateNaissance != null
                              ? Colors.white
                              : Colors.white38,
                          fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            _WizardField(ctrl: _adresseCtrl, label: 'Adresse', hint: 'Adresse complète'),
            _WizardField(ctrl: _telephoneCtrl, label: 'Téléphone', hint: '0X XX XX XX XX',
                keyboardType: TextInputType.phone),
            _WizardField(ctrl: _emailEleveCtrl, label: 'Email élève', hint: 'eleve@example.com',
                keyboardType: TextInputType.emailAddress),
            _WizardField(ctrl: _nationaliteCtrl, label: 'Nationalité', hint: 'Ex: Algérienne'),
          ],
        ),
      ),
    );
  }

  // ── Step 2 : Responsables ────────────────────────────────────────────────

  Widget _buildStep2() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
      child: Column(
        children: [
          _buildParentCard(
            title: 'Père',
            icon: Icons.man_outlined,
            expanded: _pereExpanded,
            onExpand: () => setState(() => _pereExpanded = !_pereExpanded),
            nomCtrl: _pereNomCtrl,
            profCtrl: _pereProfCtrl,
            telCtrl: _pereTelCtrl,
            emailCtrl: _pereEmailCtrl,
            adresseCtrl: _pereAdresseCtrl,
          ),
          const SizedBox(height: 12),
          _buildParentCard(
            title: 'Mère',
            icon: Icons.woman_outlined,
            expanded: _mereExpanded,
            onExpand: () => setState(() => _mereExpanded = !_mereExpanded),
            nomCtrl: _mereNomCtrl,
            profCtrl: _mereProfCtrl,
            telCtrl: _mereTelCtrl,
            emailCtrl: _mereEmailCtrl,
            adresseCtrl: _mereAdresseCtrl,
          ),
          const SizedBox(height: 12),
          _buildParentCard(
            title: 'Tuteur légal',
            icon: Icons.supervisor_account_outlined,
            expanded: _tuteurExpanded,
            onExpand: () =>
                setState(() => _tuteurExpanded = !_tuteurExpanded),
            nomCtrl: _tuteurNomCtrl,
            profCtrl: _tuteurProfCtrl,
            telCtrl: _tuteurTelCtrl,
            emailCtrl: _tuteurEmailCtrl,
            adresseCtrl: _tuteurAdresseCtrl,
          ),
        ],
      ),
    );
  }

  Widget _buildParentCard({
    required String title,
    required IconData icon,
    required bool expanded,
    required VoidCallback onExpand,
    required TextEditingController nomCtrl,
    required TextEditingController profCtrl,
    required TextEditingController telCtrl,
    required TextEditingController emailCtrl,
    required TextEditingController adresseCtrl,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: _iwCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _iwBorder),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onExpand,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [_iwPurple, _iwBlue]),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child:
                        Icon(icon, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600)),
                        Text(
                          nomCtrl.text.trim().isNotEmpty
                              ? nomCtrl.text.trim()
                              : 'Non renseigné',
                          style: TextStyle(
                              color: nomCtrl.text.trim().isNotEmpty
                                  ? Colors.white54
                                  : Colors.white24,
                              fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    expanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: Colors.white38,
                  ),
                ],
              ),
            ),
          ),
          if (expanded) ...[
            const Divider(color: _iwBorder, height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(
                children: [
                  _WizardField(ctrl: nomCtrl, label: 'Nom complet', hint: 'Nom et prénom'),
                  _WizardField(ctrl: profCtrl, label: 'Profession', hint: 'Ex: Enseignant, Médecin…'),
                  _WizardField(ctrl: telCtrl, label: 'Téléphone', hint: '0X XX XX XX XX',
                      keyboardType: TextInputType.phone),
                  _WizardField(ctrl: emailCtrl, label: 'Email', hint: 'parent@example.com',
                      keyboardType: TextInputType.emailAddress),
                  _WizardField(ctrl: adresseCtrl, label: 'Adresse', hint: 'Adresse complète'),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Step 3 : Scolarité ───────────────────────────────────────────────────

  Widget _buildStep3() {
    final niveaux = _selectedCycle.isNotEmpty
        ? (_niveauxByCycle[_selectedCycle] ?? [])
        : <String>[];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cycle
          const _FieldLabel('Cycle d\'enseignement *'),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            initialValue: _selectedCycle.isNotEmpty ? _selectedCycle : null,
            decoration: _dropDecoration('Sélectionner un cycle'),
            dropdownColor: _iwCard2,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            onChanged: (v) {
              setState(() {
                _selectedCycle = v ?? '';
                _selectedNiveau = '';
              });
            },
            items: _cycles
                .map((c) => DropdownMenuItem(
                    value: c,
                    child: Text(c,
                        style: const TextStyle(color: Colors.white))))
                .toList(),
          ),
          const SizedBox(height: 14),

          // Niveau
          const _FieldLabel('Niveau *'),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            initialValue:
                (_selectedNiveau.isNotEmpty && niveaux.contains(_selectedNiveau))
                    ? _selectedNiveau
                    : null,
            decoration: _dropDecoration(
              niveaux.isEmpty
                  ? 'Sélectionnez d\'abord un cycle'
                  : 'Sélectionner un niveau',
            ),
            dropdownColor: _iwCard2,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            onChanged: niveaux.isEmpty
                ? null
                : (v) => setState(() => _selectedNiveau = v ?? ''),
            items: niveaux
                .map((n) => DropdownMenuItem(
                    value: n,
                    child: Text(n,
                        style: const TextStyle(color: Colors.white))))
                .toList(),
          ),
          const SizedBox(height: 14),

          // Classe (manual input — TODO: load from Firestore)
          _WizardField(
            ctrl: TextEditingController(text: _selectedClasse)
              ..addListener(() {}),
            label: 'Classe demandée',
            hint: 'Ex: 3AM-A (TODO: chargement depuis Firestore)',
            onChanged: (v) => _selectedClasse = v,
          ),
          const SizedBox(height: 6),

          _WizardField(
            ctrl: _etablissementCtrl,
            label: 'Établissement',
            hint: 'Nom de l\'établissement',
          ),
          const SizedBox(height: 16),

          // Info card
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _iwBlue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _iwBlue.withValues(alpha: 0.3)),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: _iwBlue, size: 18),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'La classe finale sera attribuée par la Direction après validation du dossier.',
                    style: TextStyle(
                        color: Colors.white70, fontSize: 12, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Step 4 : Documents ───────────────────────────────────────────────────

  Widget _buildStep4() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Documents requis',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          const Text(
              'Préparez ces documents pour finaliser votre dossier.',
              style: TextStyle(color: Colors.white54, fontSize: 13)),
          const SizedBox(height: 16),
          ..._docs.asMap().entries.map((entry) {
            final i = entry.key;
            final doc = entry.value;
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _iwCard,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _iwBorder),
              ),
              child: Row(
                children: [
                  Icon(
                    doc.provided
                        ? Icons.check_circle_outlined
                        : Icons.radio_button_unchecked,
                    color: doc.provided
                        ? const Color(0xFF16A34A)
                        : Colors.white24,
                    size: 22,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(doc.label,
                            style: TextStyle(
                              color: doc.provided
                                  ? Colors.white
                                  : Colors.white70,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            )),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: doc.provided
                                ? const Color(0xFF16A34A)
                                    .withValues(alpha: 0.15)
                                : Colors.white12,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            doc.provided ? 'Fourni' : 'À fournir',
                            style: TextStyle(
                                color: doc.provided
                                    ? const Color(0xFF16A34A)
                                    : Colors.white38,
                                fontSize: 10,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      // TODO: implement file upload
                      setState(() => _docs[i].provided = !_docs[i].provided);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: doc.provided
                            ? null
                            : const LinearGradient(
                                colors: [_iwPurple, _iwBlue]),
                        color: doc.provided ? _iwCard2 : null,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        doc.provided ? 'Retirer' : 'Ajouter',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 16),

          // Signature section
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _iwCard,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: _iwPurple.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.draw_outlined,
                        color: _iwPurple, size: 20),
                    const SizedBox(width: 10),
                    const Text('Signature électronique',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600)),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _iwPurple.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text('Bientôt',
                          style: TextStyle(
                              color: _iwPurple,
                              fontSize: 10,
                              fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'La signature électronique sera disponible dans une prochaine mise à jour.',
                  // TODO: implement electronic signature
                  style: TextStyle(
                      color: Colors.white38, fontSize: 12, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Step 5 : Vérification IA ─────────────────────────────────────────────

  Widget _buildStep5() {
    _iaCheckFuture ??= _runIaCheck();
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
      child: FutureBuilder<List<_IaCheckResult>>(
        future: _iaCheckFuture,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 40),
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [_iwPurple, _iwBlue]),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: const Icon(Icons.psychology_outlined,
                      color: Colors.white, size: 40),
                ),
                const SizedBox(height: 20),
                const Text('Analyse IA en cours…',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 10),
                const Text('Vérification de la complétude du dossier',
                    style: TextStyle(
                        color: Colors.white54, fontSize: 13)),
                const SizedBox(height: 24),
                const CircularProgressIndicator(color: _iwPurple),
              ],
            );
          }

          final results = snap.data ?? [];
          final score = _completenessScore(results);
          final errors = results.where((r) => r.status == _IaStatus.error).length;
          final warnings = results.where((r) => r.status == _IaStatus.warning).length;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Score card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1A1040), Color(0xFF0F1B3D)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: _iwPurple.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 80,
                      height: 80,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          CircularProgressIndicator(
                            value: score / 100,
                            strokeWidth: 8,
                            backgroundColor: Colors.white12,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              score >= 80
                                  ? const Color(0xFF16A34A)
                                  : score >= 50
                                      ? const Color(0xFFD97706)
                                      : const Color(0xFFDC2626),
                            ),
                          ),
                          Text(
                            '$score%',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Score de complétude',
                              style: TextStyle(
                                  color: Colors.white70, fontSize: 12)),
                          Text(
                            score >= 80
                                ? 'Dossier bien rempli'
                                : score >= 50
                                    ? 'Dossier incomplet'
                                    : 'Dossier insuffisant',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              if (errors > 0) ...[
                                const Icon(Icons.error_outline,
                                    color: Color(0xFFDC2626), size: 14),
                                const SizedBox(width: 4),
                                Text('$errors erreur${errors > 1 ? 's' : ''}',
                                    style: const TextStyle(
                                        color: Color(0xFFDC2626),
                                        fontSize: 12)),
                                const SizedBox(width: 10),
                              ],
                              if (warnings > 0) ...[
                                const Icon(Icons.warning_amber_outlined,
                                    color: Color(0xFFD97706), size: 14),
                                const SizedBox(width: 4),
                                Text('$warnings avertissement${warnings > 1 ? 's' : ''}',
                                    style: const TextStyle(
                                        color: Color(0xFFD97706),
                                        fontSize: 12)),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Checklist
              const Text('Détail de l\'analyse',
                  style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8)),
              const SizedBox(height: 10),
              ...results.map((r) {
                Color color;
                IconData icon;
                switch (r.status) {
                  case _IaStatus.ok:
                    color = const Color(0xFF16A34A);
                    icon = Icons.check_circle_outlined;
                  case _IaStatus.warning:
                    color = const Color(0xFFD97706);
                    icon = Icons.warning_amber_outlined;
                  case _IaStatus.error:
                    color = const Color(0xFFDC2626);
                    icon = Icons.error_outline;
                }
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border:
                        Border.all(color: color.withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    children: [
                      Icon(icon, color: color, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(r.label,
                                style: TextStyle(
                                    color: color,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600)),
                            if (r.note != null)
                              Text(r.note!,
                                  style: const TextStyle(
                                      color: Colors.white38,
                                      fontSize: 11)),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }

  // ── Step 6 : Validation finale ───────────────────────────────────────────

  Widget _buildStep6() {
    if (_submitted) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  color: const Color(0xFF16A34A).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: const Color(0xFF16A34A).withValues(alpha: 0.4),
                      width: 2),
                ),
                child: const Icon(Icons.check_rounded,
                    color: Color(0xFF16A34A), size: 48),
              ),
              const SizedBox(height: 20),
              const Text('Dossier soumis avec succès !',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center),
              const SizedBox(height: 8),
              const Text(
                'Votre dossier a été transmis à l\'administration. Vous serez contacté prochainement.',
                style: TextStyle(
                    color: Colors.white54, fontSize: 13, height: 1.5),
                textAlign: TextAlign.center,
              ),
              if (_submittedId != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _iwCard,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _iwBorder),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.badge_outlined,
                          color: _iwPurple, size: 16),
                      const SizedBox(width: 8),
                      Text('ID: $_submittedId',
                          style: const TextStyle(
                              color: Colors.white54, fontSize: 12)),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _iwPurple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 32, vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Retour à l\'accueil'),
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _iwCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _iwBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.person_outlined, color: _iwPurple, size: 18),
                    SizedBox(width: 8),
                    Text('Récapitulatif élève',
                        style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 12),
                _SummaryRow('Nom complet',
                    '${_prenomCtrl.text.trim()} ${_nomCtrl.text.trim()}'.trim()),
                _SummaryRow('Sexe', _sexe),
                _SummaryRow('Date de naissance',
                    _dateNaissance != null
                        ? '${_dateNaissance!.day}/${_dateNaissance!.month}/${_dateNaissance!.year}'
                        : 'Non renseignée'),
                _SummaryRow('Email', _emailEleveCtrl.text.trim()),
                _SummaryRow('Cycle', _selectedCycle),
                _SummaryRow('Niveau', _selectedNiveau),
                _SummaryRow('Responsable',
                    _pereNomCtrl.text.trim().isNotEmpty
                        ? _pereNomCtrl.text.trim()
                        : _mereNomCtrl.text.trim()),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Status timeline
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _iwCard,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _iwBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.timeline, color: _iwBlue, size: 18),
                    SizedBox(width: 8),
                    Text('Processus d\'inscription',
                        style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 14),
                _TimelineStep(
                    label: 'Brouillon', active: true, done: false),
                _TimelineStep(
                    label: 'En attente', active: false, done: false),
                _TimelineStep(
                    label: 'Vérification', active: false, done: false),
                _TimelineStep(
                    label: 'Validé', active: false, done: false,
                    isLast: true),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Submit button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: _iwPurple,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.white12,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5, color: Colors.white),
                    )
                  : const Text('Soumettre le dossier',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'En soumettant, vous confirmez l\'exactitude des informations fournies.',
            style: TextStyle(
                color: Colors.white24, fontSize: 11),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ── Navigation bar ────────────────────────────────────────────────────────

  Widget _buildNavBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
      decoration: const BoxDecoration(
        color: _iwCard,
        border: Border(top: BorderSide(color: _iwBorder)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            if (_currentStep > 0)
              Expanded(
                child: OutlinedButton(
                  onPressed: _goPrev,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white70,
                    side: const BorderSide(color: _iwBorder),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Précédent'),
                ),
              ),
            if (_currentStep > 0) const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: _saving ? null : _goNext,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _currentStep == _totalSteps - 1
                      ? const Color(0xFF16A34A)
                      : _iwPurple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : Text(
                        _currentStep == _totalSteps - 1
                            ? 'Finaliser'
                            : 'Suivant',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  InputDecoration _dropDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.white38),
      filled: true,
      fillColor: _iwCard2,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _iwBorder),
      ),
    );
  }
}

// ─── Helper Widgets ───────────────────────────────────────────────────────────

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(text,
          style: const TextStyle(
              color: Colors.white60,
              fontSize: 12,
              fontWeight: FontWeight.w600)),
    );
  }
}

class _WizardField extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final String hint;
  final TextInputType keyboardType;
  final ValueChanged<String>? onChanged;

  const _WizardField({
    required this.ctrl,
    required this.label,
    required this.hint,
    this.keyboardType = TextInputType.text,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _FieldLabel(label),
          TextField(
            controller: ctrl,
            keyboardType: keyboardType,
            onChanged: onChanged,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: Colors.white38),
              filled: true,
              fillColor: const Color(0xFF1F2937),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: _iwBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide:
                    const BorderSide(color: _iwPurple, width: 1.5),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  const _SummaryRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(label,
                style: const TextStyle(
                    color: Colors.white38, fontSize: 12)),
          ),
          Expanded(
            child: Text(
              value.isNotEmpty ? value : '—',
              style: TextStyle(
                  color: value.isNotEmpty ? Colors.white : Colors.white24,
                  fontSize: 13,
                  fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineStep extends StatelessWidget {
  final String label;
  final bool active;
  final bool done;
  final bool isLast;

  const _TimelineStep({
    required this.label,
    required this.active,
    required this.done,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    Color dotColor;
    if (done) {
      dotColor = const Color(0xFF16A34A);
    } else if (active) {
      dotColor = _iwPurple;
    } else {
      dotColor = Colors.white12;
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
                border: Border.all(
                  color: active ? _iwPurple : Colors.white12,
                  width: 2,
                ),
              ),
              child: done
                  ? const Icon(Icons.check, color: Colors.white, size: 10)
                  : null,
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 28,
                color: Colors.white12,
              ),
          ],
        ),
        const SizedBox(width: 12),
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(
            label,
            style: TextStyle(
              color: active
                  ? Colors.white
                  : done
                      ? Colors.white70
                      : Colors.white24,
              fontSize: 13,
              fontWeight: active ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Data Classes ──────────────────────────────────────────────────────────────

class _DocItem {
  final String label;
  bool provided = false;
  _DocItem(this.label);
}

enum _IaStatus { ok, warning, error }

class _IaCheckResult {
  final String label;
  final _IaStatus status;
  final String? note;

  const _IaCheckResult({
    required this.label,
    required this.status,
    this.note,
  });
}
