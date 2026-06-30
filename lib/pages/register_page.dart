import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/user_model.dart';
import '../services/user_service.dart';
import 'pending_validation_page.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _pageCtrl = PageController();
  int _currentStep = 0;
  UserRole? _selectedRole;
  String? _selectedCycle;
  bool _loading = false;
  bool _accepteCgu = false;
  bool _pwdVisible = false;
  bool _confirmPwdVisible = false;

  final _prenomCtrl = TextEditingController();
  final _nomCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _pwdCtrl = TextEditingController();
  final _confirmPwdCtrl = TextEditingController();
  final _classeCtrl = TextEditingController();
  final _matiereCtrl = TextEditingController();
  final _enfantEmailCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _pageCtrl.dispose();
    _prenomCtrl.dispose();
    _nomCtrl.dispose();
    _emailCtrl.dispose();
    _pwdCtrl.dispose();
    _confirmPwdCtrl.dispose();
    _classeCtrl.dispose();
    _matiereCtrl.dispose();
    _enfantEmailCtrl.dispose();
    super.dispose();
  }

  // ─── Progress / Step helpers ──────────────────────────────────────────────

  int get _displayStep {
    if (_selectedRole == UserRole.parent) {
      if (_currentStep == 0) return 1;
      if (_currentStep == 2) return 2;
      return 3;
    }
    return _currentStep + 1;
  }

  int get _totalDisplaySteps => _selectedRole == UserRole.parent ? 3 : 4;

  double get _progress => _displayStep / _totalDisplaySteps;

  // ─── Actions ──────────────────────────────────────────────────────────────

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: const Color(0xFFEF4444),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _nextStep() {
    if (_currentStep == 0) {
      if (_selectedRole == null) {
        _showError('Veuillez sélectionner votre rôle');
        return;
      }
      if (_selectedRole == UserRole.parent) {
        _pageCtrl.animateToPage(
          2,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
        setState(() => _currentStep = 2);
        return;
      }
    }
    if (_currentStep == 1) {
      if (_selectedCycle == null) {
        _showError('Veuillez sélectionner votre cycle');
        return;
      }
    }
    if (_currentStep == 2) {
      if (!(_formKey.currentState?.validate() ?? false)) {
        return;
      }
    }
    _pageCtrl.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
    setState(() => _currentStep++);
  }

  void _prevStep() {
    if (_currentStep == 2 && _selectedRole == UserRole.parent) {
      _pageCtrl.animateToPage(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      setState(() => _currentStep = 0);
      return;
    }
    _pageCtrl.previousPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
    setState(() => _currentStep--);
  }

  Future<void> _submit() async {
    if (!_accepteCgu) {
      _showError("Veuillez accepter les conditions d'utilisation");
      return;
    }
    setState(() => _loading = true);
    try {
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailCtrl.text.trim(),
        password: _pwdCtrl.text.trim(),
      );

      await cred.user?.updateDisplayName(
        '${_prenomCtrl.text.trim()} ${_nomCtrl.text.trim()}',
      );

      final uid = cred.user!.uid;
      final role = _selectedRole!;
      final displayName =
          '${_prenomCtrl.text.trim()} ${_nomCtrl.text.trim()}';

      final bool needsValidation = _selectedRole == UserRole.professeur ||
          (_selectedRole == UserRole.eleve &&
              _classeCtrl.text.trim().isNotEmpty);
      final String statut = needsValidation ? 'en_attente' : 'actif';

      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'uid': uid,
        'email': _emailCtrl.text.trim(),
        'displayName': displayName,
        'role': role.value,
        'schoolId': 'default',
        if (_selectedCycle != null) 'categorie': _selectedCycle,
        if (_matiereCtrl.text.trim().isNotEmpty)
          'matiere': _matiereCtrl.text.trim(),
        if (_classeCtrl.text.trim().isNotEmpty)
          'classeDemandee': _classeCtrl.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'lastSeen': FieldValue.serverTimestamp(),
        'statut': statut,
      });

      if (role == UserRole.parent && _enfantEmailCtrl.text.trim().isNotEmpty) {
        await UserService.syncProfile(role: UserRole.parent);
        // TODO: déclencher liaison parent-enfant via email
      }

      if (mounted) {
        if (statut == 'en_attente') {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute<void>(
              builder: (_) => PendingValidationPage(
                displayName: displayName,
                role: role.value,
                cycle: _selectedCycle,
                classeDemandee: _classeCtrl.text.trim().isNotEmpty
                    ? _classeCtrl.text.trim()
                    : null,
                matiere: _matiereCtrl.text.trim().isNotEmpty
                    ? _matiereCtrl.text.trim()
                    : null,
              ),
            ),
          );
        } else {
          _showSuccess();
        }
      }
    } on FirebaseAuthException catch (e) {
      String msg;
      switch (e.code) {
        case 'email-already-in-use':
          msg = 'Email déjà utilisé';
          break;
        case 'invalid-email':
          msg = 'Email invalide';
          break;
        case 'weak-password':
          msg = 'Mot de passe trop faible (min 6 caractères)';
          break;
        case 'network-request-failed':
          msg = 'Pas de connexion réseau';
          break;
        case 'too-many-requests':
          msg = 'Trop de tentatives — réessayez plus tard';
          break;
        default:
          msg = '[${e.code}] ${e.message ?? 'Erreur inconnue'}';
      }
      if (mounted) {
        setState(() => _loading = false);
        _showError(msg);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    }
  }

  void _showSuccess() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _SuccessOverlay(
        displayName: '${_prenomCtrl.text.trim()} ${_nomCtrl.text.trim()}',
        role: _selectedRole!,
        onTap: () => Navigator.of(context).popUntil((r) => r.isFirst),
      ),
    );
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: PageView(
                controller: _pageCtrl,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildStep0(),
                  _buildStep1(),
                  _buildStep2(),
                  _buildStep3(),
                ],
              ),
            ),
            _buildBottomNav(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF161B22),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.arrow_back_ios_new,
                    color: Colors.white70,
                    size: 16,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Créer un compte',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                'Étape $_displayStep / $_totalDisplaySteps',
                style: const TextStyle(color: Colors.white54, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [Color(0xFF6C47FF), Color(0xFF2563EB)],
            ).createShader(bounds),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: _progress,
                minHeight: 6,
                backgroundColor: const Color(0xFF1F2937),
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
    final isLastStep = _currentStep == 3;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1117),
        border: Border(
          top: BorderSide(
            color: Colors.white.withValues(alpha: 0.08),
          ),
        ),
      ),
      child: Row(
        children: [
          if (_currentStep > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: _prevStep,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white70,
                  side: const BorderSide(color: Color(0xFF1F2937)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Précédent'),
              ),
            ),
          if (_currentStep > 0) const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: isLastStep ? _buildSubmitButton() : _buildNextButton(),
          ),
        ],
      ),
    );
  }

  Widget _buildNextButton() {
    return ElevatedButton(
      onPressed: _nextStep,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF6C47FF),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: const Text(
        'Suivant',
        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6C47FF), Color(0xFF2563EB)],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ElevatedButton(
        onPressed: _loading ? null : _submit,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: _loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : const Text(
                'Créer mon compte',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
              ),
      ),
    );
  }

  // ─── Step 0 : Role selection ──────────────────────────────────────────────

  Widget _buildStep0() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Quel est votre rôle ?',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Votre accès sera personnalisé selon votre profil',
            style: TextStyle(color: Colors.white54, fontSize: 14),
          ),
          const SizedBox(height: 28),
          _RoleCard(
            icon: Icons.school_outlined,
            title: 'Élève',
            description: 'Accédez à vos cours, devoirs et révisions',
            gradientColors: const [Color(0xFF2563EB), Color(0xFF06B6D4)],
            selected: _selectedRole == UserRole.eleve,
            onTap: () => setState(() => _selectedRole = UserRole.eleve),
          ),
          const SizedBox(height: 14),
          _RoleCard(
            icon: Icons.family_restroom,
            title: 'Parent',
            description: 'Suivez la scolarité de votre enfant',
            gradientColors: const [Color(0xFFEC4899), Color(0xFF8B5CF6)],
            selected: _selectedRole == UserRole.parent,
            onTap: () => setState(() => _selectedRole = UserRole.parent),
          ),
          const SizedBox(height: 14),
          _RoleCard(
            icon: Icons.cast_for_education_outlined,
            title: 'Enseignant',
            description: 'Gérez vos classes et vos cours',
            gradientColors: const [Color(0xFF10B981), Color(0xFF0D9488)],
            selected: _selectedRole == UserRole.professeur,
            onTap: () => setState(() => _selectedRole = UserRole.professeur),
          ),
        ],
      ),
    );
  }

  // ─── Step 1 : Cycle selection ─────────────────────────────────────────────

  Widget _buildStep1() {
    final title = _selectedRole == UserRole.professeur
        ? 'Dans quel cycle enseignez-vous ?'
        : 'Dans quel cycle êtes-vous ?';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "Sélectionnez votre cycle d'enseignement",
            style: TextStyle(color: Colors.white54, fontSize: 14),
          ),
          const SizedBox(height: 24),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 14,
            crossAxisSpacing: 14,
            childAspectRatio: 1.1,
            children: [
              _CycleCard(
                icon: Icons.child_care,
                name: 'Maternelle',
                subtitle: 'PS · MS · GS',
                color: const Color(0xFF10B981),
                selected: _selectedCycle == 'Maternelle',
                onTap: () => setState(() => _selectedCycle = 'Maternelle'),
              ),
              _CycleCard(
                icon: Icons.menu_book,
                name: 'Primaire',
                subtitle: 'CP → CM2',
                color: const Color(0xFF3B82F6),
                selected: _selectedCycle == 'Primaire',
                onTap: () => setState(() => _selectedCycle = 'Primaire'),
              ),
              _CycleCard(
                icon: Icons.school,
                name: 'Collège',
                subtitle: '6e → 3e',
                color: const Color(0xFF8B5CF6),
                selected: _selectedCycle == 'Collège',
                onTap: () => setState(() => _selectedCycle = 'Collège'),
              ),
              _CycleCard(
                icon: Icons.auto_stories,
                name: 'Lycée',
                subtitle: 'Seconde → Terminale',
                color: const Color(0xFFF59E0B),
                selected: _selectedCycle == 'Lycée',
                onTap: () => setState(() => _selectedCycle = 'Lycée'),
              ),
              _CycleCard(
                icon: Icons.account_balance,
                name: 'Université',
                subtitle: 'L1 → Doctorat',
                color: const Color(0xFFEF4444),
                selected: _selectedCycle == 'Université',
                onTap: () => setState(() => _selectedCycle = 'Université'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Step 2 : Form ────────────────────────────────────────────────────────

  Widget _buildStep2() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Créez votre compte',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Ces informations seront utilisées pour personnaliser votre espace',
              style: TextStyle(color: Colors.white54, fontSize: 14),
            ),
            const SizedBox(height: 24),
            _buildField(
              'Prénom',
              _prenomCtrl,
              icon: Icons.person_outline,
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Veuillez entrer votre prénom';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
            _buildField(
              'Nom',
              _nomCtrl,
              icon: Icons.person_outline,
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Veuillez entrer votre nom';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
            _buildField(
              'Email',
              _emailCtrl,
              icon: Icons.email_outlined,
              type: TextInputType.emailAddress,
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Veuillez entrer votre email';
                }
                if (!v.contains('@') || !v.contains('.')) {
                  return 'Email invalide';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
            _buildField(
              'Mot de passe',
              _pwdCtrl,
              icon: Icons.lock_outline,
              obscure: true,
              validator: (v) {
                if (v == null || v.isEmpty) {
                  return 'Veuillez entrer un mot de passe';
                }
                if (v.length < 6) {
                  return 'Minimum 6 caractères';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
            _buildField(
              'Confirmer le mot de passe',
              _confirmPwdCtrl,
              icon: Icons.lock_outline,
              obscure: true,
              validator: (v) {
                if (v != _pwdCtrl.text) {
                  return 'Les mots de passe ne correspondent pas';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
            if (_selectedRole == UserRole.eleve) ...[
              _buildField(
                'Classe souhaitée',
                _classeCtrl,
                icon: Icons.class_,
                hint: 'ex: 3e B, Terminale S...',
              ),
              const SizedBox(height: 14),
            ],
            if (_selectedRole == UserRole.parent) ...[
              _buildField(
                'Email de votre enfant (facultatif)',
                _enfantEmailCtrl,
                icon: Icons.child_care,
                hint: 'Pour lier automatiquement le compte',
                type: TextInputType.emailAddress,
              ),
              const SizedBox(height: 14),
            ],
            if (_selectedRole == UserRole.professeur) ...[
              _buildField(
                'Matière principale',
                _matiereCtrl,
                icon: Icons.subject,
                hint: 'ex: Mathématiques, Français...',
              ),
              const SizedBox(height: 14),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildField(
    String label,
    TextEditingController ctrl, {
    IconData? icon,
    TextInputType type = TextInputType.text,
    bool obscure = false,
    String? hint,
    String? Function(String?)? validator,
  }) {
    final isConfirmField = ctrl == _confirmPwdCtrl;
    final isVisible = isConfirmField ? _confirmPwdVisible : _pwdVisible;

    return TextFormField(
      controller: ctrl,
      keyboardType: type,
      obscureText: obscure ? !isVisible : false,
      style: const TextStyle(color: Colors.white),
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white54),
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white38),
        filled: true,
        fillColor: const Color(0xFF161B22),
        prefixIcon: icon != null
            ? Icon(icon, color: Colors.white54, size: 20)
            : null,
        suffixIcon: obscure
            ? IconButton(
                icon: Icon(
                  isVisible
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: Colors.white54,
                  size: 20,
                ),
                onPressed: () {
                  if (isConfirmField) {
                    setState(() => _confirmPwdVisible = !_confirmPwdVisible);
                  } else {
                    setState(() => _pwdVisible = !_pwdVisible);
                  }
                },
              )
            : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF1F2937)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF1F2937)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF6C47FF)),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFEF4444)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFEF4444)),
        ),
        errorStyle: const TextStyle(color: Color(0xFFEF4444)),
      ),
    );
  }

  // ─── Step 3 : Confirmation ────────────────────────────────────────────────

  Widget _buildStep3() {
    final prenom = _prenomCtrl.text.trim();
    final nom = _nomCtrl.text.trim();
    final displayName = '$prenom $nom'.trim();
    final initial =
        displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Tout est prêt !',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Vérifiez vos informations avant de créer votre compte',
            style: TextStyle(color: Colors.white54, fontSize: 14),
          ),
          const SizedBox(height: 24),

          // Summary card
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF161B22),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFF6C47FF).withValues(alpha: 0.4),
              ),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [Color(0xFF6C47FF), Color(0xFF2563EB)],
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        initial,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayName.isNotEmpty
                                ? displayName
                                : 'Votre nom',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          if (_selectedRole != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF6C47FF)
                                    .withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                _selectedRole!.label,
                                style: const TextStyle(
                                  color: Color(0xFF6C47FF),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Divider(color: Color(0xFF1F2937)),
                ),
                if (_selectedCycle != null)
                  _summaryRow(
                    Icons.layers_outlined,
                    'Cycle',
                    _selectedCycle!,
                  ),
                _summaryRow(
                  Icons.email_outlined,
                  'Email',
                  _emailCtrl.text.trim(),
                ),
                if (_selectedRole == UserRole.eleve &&
                    _classeCtrl.text.trim().isNotEmpty)
                  _summaryRow(
                    Icons.class_,
                    'Classe',
                    _classeCtrl.text.trim(),
                  ),
                if (_selectedRole == UserRole.professeur &&
                    _matiereCtrl.text.trim().isNotEmpty)
                  _summaryRow(
                    Icons.subject,
                    'Matière',
                    _matiereCtrl.text.trim(),
                  ),
                if (_selectedRole == UserRole.parent &&
                    _enfantEmailCtrl.text.trim().isNotEmpty)
                  _summaryRow(
                    Icons.child_care,
                    'Email enfant',
                    _enfantEmailCtrl.text.trim(),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // CGU checkbox
          GestureDetector(
            onTap: () => setState(() => _accepteCgu = !_accepteCgu),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: _accepteCgu
                        ? const Color(0xFF6C47FF)
                        : Colors.transparent,
                    border: Border.all(
                      color: _accepteCgu
                          ? const Color(0xFF6C47FF)
                          : const Color(0xFF1F2937),
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: _accepteCgu
                      ? const Icon(Icons.check, color: Colors.white, size: 16)
                      : null,
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    "J'accepte les conditions d'utilisation",
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _summaryRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: Colors.white38, size: 18),
          const SizedBox(width: 12),
          Text(
            '$label :',
            style: const TextStyle(color: Colors.white54, fontSize: 13),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Private widgets ──────────────────────────────────────────────────────────

class _RoleCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final List<Color> gradientColors;
  final bool selected;
  final VoidCallback onTap;

  const _RoleCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.gradientColors,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFF161B22),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? const Color(0xFF6C47FF)
                : const Color(0xFF1F2937),
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: gradientColors),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: Colors.white, size: 26),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              const Icon(
                Icons.check_circle,
                color: Color(0xFF6C47FF),
                size: 22,
              ),
          ],
        ),
      ),
    );
  }
}

class _CycleCard extends StatelessWidget {
  final IconData icon;
  final String name;
  final String subtitle;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _CycleCard({
    required this.icon,
    required this.name,
    required this.subtitle,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: 0.15)
              : const Color(0xFF161B22),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? color : const Color(0xFF1F2937),
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: selected ? color : Colors.white54,
              size: 28,
            ),
            const SizedBox(height: 8),
            Text(
              name,
              style: TextStyle(
                color: selected ? color : Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(color: Colors.white38, fontSize: 11),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _SuccessOverlay extends StatelessWidget {
  final String displayName;
  final UserRole role;
  final VoidCallback onTap;

  const _SuccessOverlay({
    required this.displayName,
    required this.role,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      backgroundColor: const Color(0xFF0D1117),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFF10B981), Color(0xFF6C47FF)],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6C47FF).withValues(alpha: 0.4),
                  blurRadius: 30,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: const Icon(Icons.check, color: Colors.white, size: 60),
          ),
          const SizedBox(height: 32),
          const Text(
            'Compte créé avec succès !',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            displayName,
            style: const TextStyle(color: Colors.white70, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFF6C47FF).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              role.label,
              style: const TextStyle(
                color: Color(0xFF6C47FF),
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(height: 40),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6C47FF), Color(0xFF2563EB)],
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: ElevatedButton(
                onPressed: onTap,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'Accéder à mon espace',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
