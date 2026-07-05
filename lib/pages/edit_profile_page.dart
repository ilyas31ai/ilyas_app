import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/user_service.dart';

class EditProfilePage extends StatefulWidget {
  final UserModel profile;

  const EditProfilePage({super.key, required this.profile});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _bioCtrl;
  late final TextEditingController _matiereCtrl;
  String? _selectedNiveau;
  bool _saving = false;

  static const _niveaux = [
    '6ème', '5ème', '4ème', '3ème',
    'Seconde', 'Première', 'Terminale',
    'BTS', 'BUT', 'Licence 1', 'Licence 2', 'Licence 3',
    'Master 1', 'Master 2',
  ];

  @override
  void initState() {
    super.initState();
    _nameCtrl =
        TextEditingController(text: widget.profile.displayName);
    _bioCtrl =
        TextEditingController(text: widget.profile.bio ?? '');
    _matiereCtrl =
        TextEditingController(text: widget.profile.matiere ?? '');
    _selectedNiveau = _niveaux.contains(widget.profile.niveau)
        ? widget.profile.niveau
        : null;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _bioCtrl.dispose();
    _matiereCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      _snack('Le nom ne peut pas être vide');
      return;
    }
    setState(() => _saving = true);

    final data = <String, dynamic>{'displayName': name};
    final bio = _bioCtrl.text.trim();
    if (bio.isNotEmpty) {
      data['bio'] = bio;
    } else {
      data['bio'] = '';
    }
    if (widget.profile.role == UserRole.eleve &&
        _selectedNiveau != null) {
      data['niveau'] = _selectedNiveau;
    }
    if (widget.profile.role == UserRole.professeur) {
      data['matiere'] = _matiereCtrl.text.trim();
    }

    try {
      await UserService.updateProfile(data);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) _snack('Erreur : $e');
    }
    if (mounted) setState(() => _saving = false);
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Modifier le profil',
          style: TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.bold),
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Color(0xFF2563EB)),
                  )
                : const Text('Enregistrer',
                    style: TextStyle(
                        color: Color(0xFF2563EB),
                        fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Role badge
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: _roleColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: _roleColor.withValues(alpha: 0.3)),
              ),
              child: Text(
                widget.profile.role.label,
                style: TextStyle(
                    color: _roleColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(height: 24),

            _FieldLabel('Nom affiché'),
            const SizedBox(height: 8),
            _Field(
              controller: _nameCtrl,
              hint: 'Votre prénom ou pseudo',
              icon: Icons.person_outline,
            ),
            const SizedBox(height: 20),

            _FieldLabel('Bio'),
            const SizedBox(height: 8),
            _Field(
              controller: _bioCtrl,
              hint: 'Quelques mots sur vous…',
              icon: Icons.info_outline,
              maxLines: 3,
            ),

            // Niveau — élèves seulement
            if (widget.profile.role == UserRole.eleve) ...[
              const SizedBox(height: 20),
              _FieldLabel('Niveau scolaire'),
              const SizedBox(height: 8),
              _NiveauDropdown(
                value: _selectedNiveau,
                niveaux: _niveaux,
                onChanged: (v) => setState(() => _selectedNiveau = v),
              ),
            ],

            // Matière — professeurs seulement
            if (widget.profile.role == UserRole.professeur) ...[
              const SizedBox(height: 20),
              _FieldLabel('Matière enseignée'),
              const SizedBox(height: 8),
              _Field(
                controller: _matiereCtrl,
                hint: 'Ex : Mathématiques, Français…',
                icon: Icons.book_outlined,
              ),
            ],

            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
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
                    : const Text('Enregistrer',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color get _roleColor {
    switch (widget.profile.role) {
      case UserRole.professeur:
        return const Color(0xFF6C47FF);
      case UserRole.admin:
      case UserRole.direction:
      case UserRole.adminEtablissement:
      case UserRole.superAdmin:
        return const Color(0xFFD97706);
      case UserRole.parent:
        return const Color(0xFFBE185D);
      default:
        return const Color(0xFF16A34A);
    }
  }
}

// ─── Field helpers ────────────────────────────────────────────────────────────

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
            color: Colors.white54,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8),
      );
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final int maxLines;

  const _Field({
    required this.controller,
    required this.hint,
    required this.icon,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          prefixIcon:
              Icon(icon, color: Colors.white38, size: 18),
          hintText: hint,
          hintStyle:
              const TextStyle(color: Colors.white24, fontSize: 14),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
        ),
      ),
    );
  }
}

class _NiveauDropdown extends StatelessWidget {
  final String? value;
  final List<String> niveaux;
  final ValueChanged<String?> onChanged;

  const _NiveauDropdown({
    required this.value,
    required this.niveaux,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          dropdownColor: const Color(0xFF1C2128),
          hint: const Text('Sélectionner un niveau',
              style: TextStyle(color: Colors.white24, fontSize: 14)),
          style:
              const TextStyle(color: Colors.white, fontSize: 14),
          items: niveaux
              .map((n) => DropdownMenuItem(value: n, child: Text(n)))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}
