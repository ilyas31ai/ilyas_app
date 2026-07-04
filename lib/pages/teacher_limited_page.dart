import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/invitation_service.dart';
import 'profile_page.dart';
import 'professeur_dossier_page.dart';

class TeacherLimitedPage extends StatefulWidget {
  final String displayName;
  final String? matiere;

  const TeacherLimitedPage({
    super.key,
    required this.displayName,
    this.matiere,
  });

  @override
  State<TeacherLimitedPage> createState() => _TeacherLimitedPageState();
}

class _TeacherLimitedPageState extends State<TeacherLimitedPage> {
  final _codeCtrl = TextEditingController();
  bool _loading = false;
  String? _errorMsg;

  @override
  void initState() {
    super.initState();
    _migrateIfNeeded();
  }

  /// Migre les anciens comptes "en_attente" vers "actif + limited".
  Future<void> _migrateIfNeeded() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final doc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final data = doc.data() ?? <String, dynamic>{};
      if (data['statut'] == 'en_attente') {
        await FirebaseFirestore.instance.collection('users').doc(uid).update({
          'statut': 'actif',
          'teacherStatus': 'limited',
        });
      }
    } catch (_) {}
  }

  Future<void> _utiliserCode() async {
    final code = _codeCtrl.text.trim();
    if (code.isEmpty) {
      setState(() => _errorMsg = "Veuillez saisir votre code d'invitation");
      return;
    }
    setState(() {
      _loading = true;
      _errorMsg = null;
    });
    try {
      await InvitationService.utiliserCode(code);
      // Le StreamBuilder de main.dart réagit automatiquement au changement
      // de teacherStatus et redirige vers MainShell.
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMsg =
              e.toString().replaceFirst('Exception: ', '');
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Header(
                displayName: widget.displayName,
                matiere: widget.matiere,
              ),
              const SizedBox(height: 20),
              _buildStatusBanner(),
              const SizedBox(height: 24),
              _buildCodeSection(),
              const SizedBox(height: 20),
              _buildPermissionsRow(),
              const SizedBox(height: 28),
              _buildActions(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF59E0B).withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: const Color(0xFFF59E0B).withValues(alpha: 0.35)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: Color(0xFFF59E0B), size: 18),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Compte non rattaché à un établissement. Saisissez le code que votre directeur vous a communiqué pour accéder à toutes les fonctionnalités.',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCodeSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: const Color(0xFF6C47FF).withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.vpn_key_outlined,
                  color: Color(0xFF6C47FF), size: 20),
              SizedBox(width: 10),
              Text(
                'Rejoindre un établissement',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _codeCtrl,
            textCapitalization: TextCapitalization.characters,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
              LengthLimitingTextInputFormatter(8),
            ],
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
              letterSpacing: 5,
            ),
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              hintText: 'XXXXXXXX',
              hintStyle: TextStyle(
                color: Colors.white.withValues(alpha: 0.2),
                fontSize: 24,
                letterSpacing: 5,
              ),
              filled: true,
              fillColor: const Color(0xFF0D1117),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                    color: Colors.white.withValues(alpha: 0.08)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                    color: Colors.white.withValues(alpha: 0.08)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF6C47FF)),
              ),
            ),
          ),
          if (_errorMsg != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.error_outline,
                    color: Color(0xFFEF4444), size: 15),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _errorMsg!,
                    style: const TextStyle(
                        color: Color(0xFFEF4444), fontSize: 13),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _loading ? null : _utiliserCode,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C47FF),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: _loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    )
                  : const Text(
                      'Valider le code',
                      style: TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 15),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionsRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _PermissionCard(
            title: 'Autorisé',
            color: const Color(0xFF059669),
            icon: Icons.check_circle_outline,
            items: const [
              'Modifier le profil',
              'Matière principale',
              'Spécialité',
              'Ville',
              'Expérience',
              'Diplômes',
              'Consulter son profil',
              'Saisir un code',
              'Se déconnecter',
            ],
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _PermissionCard(
            title: 'Bloqué',
            color: const Color(0xFFEF4444),
            icon: Icons.block_outlined,
            items: const [
              'Classes / élèves',
              'Emplois du temps',
              'Devoirs',
              'Documents',
              'Notes / bulletins',
              'Présences',
              'Messagerie',
              'Notifications',
              'Groupes',
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActions(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    return Column(
      children: [
        OutlinedButton.icon(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ProfilePage()),
          ),
          icon: const Icon(Icons.person_outline,
              color: Color(0xFF2563EB), size: 18),
          label: const Text('Modifier mon profil',
              style: TextStyle(color: Color(0xFF2563EB))),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Color(0xFF2563EB)),
            padding: const EdgeInsets.symmetric(vertical: 12),
            minimumSize: const Size(double.infinity, 0),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ProfesseurDossierPage(
                uid: uid,
                displayName: widget.displayName,
                statut: 'actif',
                schoolNom: null,
              ),
            ),
          ),
          icon: const Icon(Icons.folder_open_outlined,
              color: Color(0xFF0F766E), size: 18),
          label: const Text('Compléter mon dossier',
              style: TextStyle(color: Color(0xFF0F766E))),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Color(0xFF0F766E)),
            padding: const EdgeInsets.symmetric(vertical: 12),
            minimumSize: const Size(double.infinity, 0),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 16),
        TextButton.icon(
          onPressed: () => FirebaseAuth.instance.signOut(),
          icon: const Icon(Icons.logout, color: Colors.white38, size: 18),
          label: const Text(
            'Se déconnecter',
            style: TextStyle(color: Colors.white38, fontSize: 14),
          ),
        ),
      ],
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final String displayName;
  final String? matiere;
  const _Header({required this.displayName, this.matiere});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF6C47FF), Color(0xFF2563EB)],
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.school, color: Colors.white, size: 26),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Bonjour, $displayName',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                matiere?.isNotEmpty == true
                    ? 'Enseignant · $matiere'
                    : 'Enseignant',
                style: const TextStyle(
                    color: Colors.white54, fontSize: 13),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PermissionCard extends StatelessWidget {
  final String title;
  final Color color;
  final IconData icon;
  final List<String> items;
  const _PermissionCard({
    required this.title,
    required this.color,
    required this.icon,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 14),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 5),
                    child: Icon(Icons.circle,
                        color: color.withValues(alpha: 0.5), size: 5),
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      item,
                      style: const TextStyle(
                          color: Colors.white60, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
