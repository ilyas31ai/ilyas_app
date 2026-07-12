import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import '../models/enseignant_profil_model.dart';
import '../models/permission_model.dart';
import '../models/user_model.dart';
import '../services/user_service.dart';
import 'direction_comptes_attente_page.dart';
import 'direction_classes_page.dart';
import 'direction_inviter_enseignant_page.dart';
import 'fiche_enseignant_page.dart';
import 'direction_dashboard_page.dart';
import 'direction_disponibilites_page.dart';
import 'direction_eleves_page.dart';
import 'direction_historique_remplacements_page.dart';
import 'direction_statistiques_page.dart';
import 'direction_stats_remplacements_page.dart';
import 'inscription_import_page.dart';
import 'inscription_recherche_page.dart';
import 'inscription_validation_page.dart';
import 'direction_bulletins_page.dart';
import 'direction_bulletins_consulter_page.dart';
import 'inscription_verification_page.dart';
import 'messagerie_page.dart';

// Restreint l'Espace Direction aux rôles Direction
// ([PermissionService.isDirection] : admin, direction, adminEtablissement,
// superAdmin) — voir la vérification dans le StreamBuilder ci-dessous.
const bool _kAdminOnly = true;

/// Hub de l'Espace Direction — gestion des inscriptions scolaires.
/// Accès conditionné par [_kAdminOnly] : si true, réservé aux rôles Direction
/// (voir [PermissionService.isDirection]).
class EspaceDirectionPage extends StatelessWidget {
  const EspaceDirectionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        elevation: 0,
        title: const Text(
          'Espace Direction',
          style: TextStyle(
              color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
      body: StreamBuilder<UserModel?>(
        stream: UserService.currentUserStream(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF2563EB)),
            );
          }
          final role = snap.data?.role;
          if (_kAdminOnly && (role == null || !PermissionService.isDirection(role))) {
            return _AccessRefuse(name: snap.data?.displayName ?? '');
          }
          return _DirectionHome();
        },
      ),
    );
  }
}

// ─── Accès refusé ─────────────────────────────────────────────────────────────

class _AccessRefuse extends StatelessWidget {
  final String name;
  const _AccessRefuse({required this.name});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.lock_outline, color: Colors.white38, size: 30),
            ),
            const SizedBox(height: 18),
            const Text(
              'Accès réservé à la Direction',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              name.isEmpty
                  ? 'Cet espace est réservé aux comptes Direction.'
                  : 'Bonjour $name, cet espace est réservé aux comptes Direction.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white38, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Hub Direction ────────────────────────────────────────────────────────────

class _DirectionHome extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _buildBanner()),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              _buildSectionLabel('Gestion des inscriptions'),
              const SizedBox(height: 8),
              _buildComptesAttenteCard(context),
              _ModuleCard(
                icon: Icons.dashboard_customize_outlined,
                title: 'Tableau de bord',
                subtitle: 'Vue d\'ensemble des inscriptions et élèves',
                colors: const [Color(0xFF2563EB), Color(0xFF0891B2)],
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const DirectionDashboardPage())),
              ),
              _ModuleCard(
                icon: Icons.upload_file_outlined,
                title: 'Import PDF',
                subtitle: 'Sélectionner, prévisualiser et sauvegarder un dossier',
                colors: const [Color(0xFF0F766E), Color(0xFF0891B2)],
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const InscriptionImportPage())),
              ),
              _ModuleCard(
                icon: Icons.fact_check_outlined,
                title: 'Vérification',
                subtitle: 'Contrôler et corriger les données extraites',
                colors: const [Color(0xFFD97706), Color(0xFFDC2626)],
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const InscriptionVerificationPage())),
              ),
              _ModuleCard(
                icon: Icons.how_to_reg_outlined,
                title: 'Validation des inscriptions',
                subtitle: 'Accepter, refuser et commenter les dossiers',
                colors: const [Color(0xFF7C3AED), Color(0xFF6C47FF)],
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const InscriptionValidationPage())),
              ),
              _ModuleCard(
                icon: Icons.search,
                title: 'Recherche',
                subtitle: 'Élève, parent, matricule, téléphone…',
                colors: const [Color(0xFF15803D), Color(0xFF16A34A)],
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const InscriptionRecherchePage())),
              ),
              _ModuleCard(
                icon: Icons.bar_chart_outlined,
                title: 'Statistiques',
                subtitle: 'Effectifs, présences et indicateurs de l\'établissement',
                colors: const [Color(0xFFD97706), Color(0xFFF59E0B)],
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const DirectionStatistiquesPage())),
              ),
              _ModuleCard(
                icon: Icons.school_outlined,
                title: 'Gestion des classes',
                subtitle: 'Créer les classes et assigner les professeurs',
                colors: const [Color(0xFF0F766E), Color(0xFF0891B2)],
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const DirectionClassesPage())),
              ),
              _ModuleCard(
                icon: Icons.people_alt_outlined,
                title: 'Gestion des élèves',
                subtitle: 'Voir les comptes élèves et affecter les classes',
                colors: const [Color(0xFF0F766E), Color(0xFF059669)],
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const DirectionElevesPage())),
              ),
              _ModuleCard(
                icon: Icons.description_outlined,
                title: 'Publication des bulletins',
                subtitle: 'Valider et publier les bulletins par classe et trimestre',
                colors: const [Color(0xFF0F766E), Color(0xFF6C47FF)],
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const DirectionBulletinsPage())),
              ),
              _ModuleCard(
                icon: Icons.analytics_outlined,
                title: 'Consultation globale des bulletins',
                subtitle: 'Consulter, rechercher et statistiques par classe et élève',
                colors: const [Color(0xFF2563EB), Color(0xFF6C47FF)],
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const DirectionBulletinsConsulterPage())),
              ),
              const SizedBox(height: 4),
              _buildSectionLabel('Gestion des disponibilités'),
              const SizedBox(height: 8),
              _ModuleCard(
                icon: Icons.event_available_outlined,
                title: 'Disponibilités & Remplacements',
                subtitle: 'Gérer les disponibilités et les remplacements intelligents',
                colors: const [Color(0xFF6C47FF), Color(0xFF8B5CF6)],
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const DirectionDisponibilitesPage())),
              ),
              _ModuleCard(
                icon: Icons.history_edu_outlined,
                title: 'Historique',
                subtitle: 'Consulter l\'historique complet des remplacements',
                colors: const [Color(0xFF0F766E), Color(0xFF0891B2)],
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const DirectionHistoriqueRemplacementsPage())),
              ),
              _ModuleCard(
                icon: Icons.analytics_outlined,
                title: 'Statistiques remplacements',
                subtitle: 'Taux d\'acceptation, absences, profils les plus sollicités',
                colors: const [Color(0xFFD97706), Color(0xFFF59E0B)],
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const DirectionStatsRemplacementsPage())),
              ),
              const SizedBox(height: 4),
              _buildSectionLabel('Communication'),
              const SizedBox(height: 8),
              _ModuleCard(
                icon: Icons.forum_outlined,
                title: 'Messagerie interne',
                subtitle: 'Messages en temps réel — Profs, Parents, Élèves',
                colors: const [Color(0xFF2563EB), Color(0xFF6C47FF)],
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const MessageriePage())),
              ),
              const SizedBox(height: 4),
              _buildSectionLabel('Gestion des enseignants'),
              const SizedBox(height: 8),
              _ModuleCard(
                icon: Icons.person_add_outlined,
                title: 'Inviter un enseignant',
                subtitle: 'Générer un code d\'invitation pour un enseignant',
                colors: const [Color(0xFF6C47FF), Color(0xFF8B5CF6)],
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(
                        builder: (_) => const DirectionInviterEnseignantPage())),
              ),
              _ModuleCard(
                icon: Icons.badge_outlined,
                title: 'Fiches enseignants',
                subtitle: 'Profils complets, disponibilités et statistiques',
                colors: const [Color(0xFF6C47FF), Color(0xFF2563EB)],
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const DirectionEnseignantsListPage())),
              ),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _buildComptesAttenteCard(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .where('statut', isEqualTo: 'en_attente')
          .snapshots(),
      builder: (context, snap) {
        // Ne compter que les élèves — les enseignants utilisent le nouveau
        // système d'invitation par code et ne passent plus par en_attente.
        final count = snap.data?.docs.where((d) {
          final data = d.data() as Map<String, dynamic>;
          return data['role'] != 'professeur';
        }).length ?? 0;
        return InkWell(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => const DirectionComptesAttentePage(),
            ),
          ),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            decoration: BoxDecoration(
              color: const Color(0xFF161B22),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: count > 0
                    ? const Color(0xFFF59E0B).withValues(alpha: 0.4)
                    : Colors.white.withValues(alpha: 0.05),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFF59E0B), Color(0xFFEF4444)],
                    ),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: const Icon(Icons.how_to_reg_outlined,
                      color: Colors.white, size: 21),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Comptes en attente',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Approuver ou refuser les nouvelles demandes',
                        style: TextStyle(
                          color: Colors.white38,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (count > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$count',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6C47FF), Color(0xFF2563EB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Gestion des inscriptions',
                  style: const TextStyle(
                      color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Import · Vérification · Validation · Suivi',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          const Icon(Icons.account_balance, color: Colors.white24, size: 52),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String text) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        color: Colors.white38,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
      ),
    );
  }
}

class _ModuleCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final List<Color> colors;
  final VoidCallback onTap;

  const _ModuleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: const Color(0xFF161B22),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: colors),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, color: Colors.white, size: 21),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: const TextStyle(color: Colors.white38, fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white24, size: 20),
          ],
        ),
      ),
    );
  }
}

// ─── Liste des enseignants ────────────────────────────────────────────────────

class DirectionEnseignantsListPage extends StatefulWidget {
  const DirectionEnseignantsListPage({super.key});

  @override
  State<DirectionEnseignantsListPage> createState() =>
      _DirectionEnseignantsListPageState();
}

class _DirectionEnseignantsListPageState
    extends State<DirectionEnseignantsListPage> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        elevation: 0,
        title: const Text(
          'Fiches enseignants',
          style: TextStyle(
              color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF6C47FF),
        tooltip: 'Ajouter un professeur',
        onPressed: () => _showAddProfesseurDialog(context),
        child: const Icon(Icons.person_add_outlined, color: Colors.white),
      ),
      body: Column(
        children: [
          // Barre de recherche
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
            child: TextField(
              style: const TextStyle(color: Colors.white),
              onChanged: (v) => setState(() => _search = v.toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Rechercher un enseignant…',
                hintStyle: const TextStyle(color: Colors.white38),
                prefixIcon:
                    const Icon(Icons.search, color: Colors.white38, size: 20),
                filled: true,
                fillColor: const Color(0xFF161B22),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
            ),
          ),
          // Liste
          Expanded(
            child: StreamBuilder<List<UserModel>>(
              stream: UserService.usersByRoleStream('professeur'),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child:
                        CircularProgressIndicator(color: Color(0xFF6C47FF)),
                  );
                }
                if (snap.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Erreur de chargement des enseignants :\n${snap.error}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.red, fontSize: 12),
                      ),
                    ),
                  );
                }
                var teachers = snap.data ?? [];
                if (_search.isNotEmpty) {
                  teachers = teachers
                      .where((u) =>
                          u.displayName.toLowerCase().contains(_search) ||
                          (u.matiere ?? '').toLowerCase().contains(_search) ||
                          u.email.toLowerCase().contains(_search))
                      .toList();
                }
                if (teachers.isEmpty) {
                  return const Center(
                    child: Text(
                      'Aucun enseignant trouvé',
                      style: TextStyle(color: Colors.white38),
                    ),
                  );
                }
                return ListView.builder(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  itemCount: teachers.length,
                  itemBuilder: (context, i) =>
                      _EnseignantTile(user: teachers[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ── Création directe d'un compte professeur ─────────────────────────────

  Future<void> _showAddProfesseurDialog(BuildContext context) async {
    final prenomCtrl = TextEditingController();
    final nomCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final adresseCtrl = TextEditingController();
    final telephoneCtrl = TextEditingController();
    final matiereCtrl = TextEditingController();
    final pwdCtrl = TextEditingController();
    bool pwdVisible = false;
    bool sendReset = true;
    bool busy = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          backgroundColor: const Color(0xFF161B22),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Ajouter un professeur',
              style: TextStyle(
                  color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                        child: _ProfDialogField(prenomCtrl, 'Prénom',
                            Icons.person_outline)),
                    const SizedBox(width: 10),
                    Expanded(
                        child: _ProfDialogField(
                            nomCtrl, 'Nom', Icons.person_outline)),
                  ],
                ),
                const SizedBox(height: 12),
                _ProfDialogField(emailCtrl, 'Adresse email',
                    Icons.email_outlined,
                    type: TextInputType.emailAddress),
                const SizedBox(height: 12),
                TextField(
                  controller: pwdCtrl,
                  obscureText: !pwdVisible,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Mot de passe temporaire',
                    hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                    prefixIcon: const Icon(Icons.lock_outline,
                        color: Colors.white38, size: 18),
                    suffixIcon: IconButton(
                      icon: Icon(
                        pwdVisible
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: Colors.white38, size: 18,
                      ),
                      onPressed: () => setDlg(() => pwdVisible = !pwdVisible),
                    ),
                    filled: true,
                    fillColor: const Color(0xFF0D1117),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide:
                            BorderSide(color: Colors.white.withValues(alpha: 0.1))),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide:
                            BorderSide(color: Colors.white.withValues(alpha: 0.1))),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFF6C47FF))),
                  ),
                ),
                const SizedBox(height: 12),
                _ProfDialogField(adresseCtrl, 'Adresse (optionnel)',
                    Icons.home_outlined,
                    type: TextInputType.streetAddress),
                const SizedBox(height: 12),
                _ProfDialogField(
                    telephoneCtrl, 'Numéro de téléphone (optionnel)',
                    Icons.phone_outlined,
                    type: TextInputType.phone),
                const SizedBox(height: 12),
                _ProfDialogField(matiereCtrl, 'Matière principale (optionnel)',
                    Icons.menu_book_outlined),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Checkbox(
                      value: sendReset,
                      onChanged: busy
                          ? null
                          : (v) => setDlg(() => sendReset = v ?? true),
                      activeColor: const Color(0xFF6C47FF),
                      side: const BorderSide(color: Colors.white38),
                    ),
                    const Expanded(
                      child: Text(
                        "Envoyer un email d'invitation",
                        style: TextStyle(color: Colors.white60, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: busy ? null : () => Navigator.pop(ctx),
              child: const Text('Annuler',
                  style: TextStyle(color: Colors.white60)),
            ),
            TextButton(
              onPressed: busy
                  ? null
                  : () async {
                      final prenom = prenomCtrl.text.trim();
                      final nom = nomCtrl.text.trim();
                      final email = emailCtrl.text.trim();
                      final pwd = pwdCtrl.text.trim();
                      if (prenom.isEmpty || nom.isEmpty || email.isEmpty ||
                          pwd.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text(
                              'Remplissez le prénom, le nom, l\'email et le mot de passe'),
                          backgroundColor: Color(0xFFDC2626),
                        ));
                        return;
                      }
                      if (pwd.length < 6) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text(
                              'Mot de passe trop court (minimum 6 caractères)'),
                          backgroundColor: Color(0xFFDC2626),
                        ));
                        return;
                      }
                      setDlg(() => busy = true);
                      final err = await _createProfesseurCompte(
                        prenom: prenom,
                        nom: nom,
                        email: email,
                        password: pwd,
                        adresse: adresseCtrl.text.trim(),
                        telephone: telephoneCtrl.text.trim(),
                        matiere: matiereCtrl.text.trim(),
                        sendResetEmail: sendReset,
                      );
                      if (!ctx.mounted) return;
                      Navigator.pop(ctx);
                      if (err != null) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(err),
                          backgroundColor: const Color(0xFFDC2626),
                          duration: const Duration(seconds: 6),
                        ));
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(sendReset
                              ? 'Professeur créé — invitation envoyée à $email'
                              : 'Compte professeur créé'),
                          backgroundColor: const Color(0xFF16A34A),
                        ));
                      }
                    },
              child: busy
                  ? const SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Color(0xFF6C47FF)))
                  : const Text('Créer',
                      style: TextStyle(
                          color: Color(0xFF6C47FF), fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );

    prenomCtrl.dispose();
    nomCtrl.dispose();
    emailCtrl.dispose();
    adresseCtrl.dispose();
    telephoneCtrl.dispose();
    matiereCtrl.dispose();
    pwdCtrl.dispose();
  }

  /// Crée un compte Firebase Auth + document Firestore pour un professeur,
  /// créé directement par la Direction (hors flux d'invitation par code).
  /// Utilise une application secondaire pour ne pas déconnecter l'admin.
  /// Retourne null si succès, ou le message d'erreur.
  Future<String?> _createProfesseurCompte({
    required String prenom,
    required String nom,
    required String email,
    required String password,
    String adresse = '',
    String telephone = '',
    String matiere = '',
    bool sendResetEmail = true,
  }) async {
    FirebaseApp? secondaryApp;
    try {
      secondaryApp = await Firebase.initializeApp(
        name: 'prof_${DateTime.now().millisecondsSinceEpoch}',
        options: Firebase.app().options,
      );

      final cred = await FirebaseAuth.instanceFor(app: secondaryApp)
          .createUserWithEmailAndPassword(email: email, password: password);
      final uid = cred.user!.uid;

      final schoolId = await UserService.currentSchoolId();
      final displayName = '$prenom $nom'.trim();

      final userData = <String, dynamic>{
        'uid': uid,
        'email': email,
        'displayName': displayName,
        'nom': nom,
        'prenom': prenom,
        'role': 'professeur',
        // Créé directement par la Direction : déjà rattaché à l'établissement,
        // contrairement au flux d'invitation par code (teacherStatus 'limited').
        'teacherStatus': 'active',
        'statut': 'actif',
        'schoolId': schoolId,
        'createdAt': FieldValue.serverTimestamp(),
        'lastSeen': FieldValue.serverTimestamp(),
      };
      if (adresse.isNotEmpty) userData['adresse'] = adresse;
      if (telephone.isNotEmpty) userData['telephone'] = telephone;
      if (matiere.isNotEmpty) userData['matiere'] = matiere;

      final profil = EnseignantProfil(
        uid: uid,
        nom: nom,
        prenom: prenom,
        adresse: adresse.isNotEmpty ? adresse : null,
        telephone: telephone.isNotEmpty ? telephone : null,
        email: email,
        matieres: matiere.isNotEmpty ? [matiere] : const [],
      );

      final db = FirebaseFirestore.instance;
      final batch = db.batch();
      batch.set(db.collection('users').doc(uid), userData);
      batch.set(db.collection('enseignants_profils').doc(uid), profil.toMap());
      await batch.commit();

      if (sendResetEmail) {
        await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      }

      return null;
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'email-already-in-use':
          return 'Un compte existe déjà avec cet email';
        case 'invalid-email':
          return 'Adresse email invalide';
        case 'weak-password':
          return 'Mot de passe trop faible (minimum 6 caractères)';
        default:
          return '[${e.code}] ${e.message ?? 'Erreur inconnue'}';
      }
    } catch (e) {
      return 'Erreur : $e';
    } finally {
      try {
        await FirebaseAuth.instanceFor(app: secondaryApp!).signOut();
      } catch (_) {}
      try {
        await secondaryApp?.delete();
      } catch (_) {}
    }
  }
}

/// Champ texte réutilisé dans la dialog de création d'un professeur.
class _ProfDialogField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final TextInputType type;
  const _ProfDialogField(this.controller, this.hint, this.icon,
      {this.type = TextInputType.text});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: type,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
        prefixIcon: Icon(icon, color: Colors.white38, size: 18),
        filled: true,
        fillColor: const Color(0xFF0D1117),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
          borderSide: const BorderSide(color: Color(0xFF6C47FF)),
        ),
      ),
    );
  }
}

class _EnseignantTile extends StatelessWidget {
  final UserModel user;
  const _EnseignantTile({required this.user});

  @override
  Widget build(BuildContext context) {
    final initials = user.displayName.isNotEmpty
        ? user.displayName[0].toUpperCase()
        : '?';
    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => FicheEnseignantPage(
            uid: user.uid,
            displayName: user.displayName,
          ),
        ),
      ),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF161B22),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor:
                  const Color(0xFF6C47FF).withValues(alpha: 0.25),
              backgroundImage: user.photoUrl != null
                  ? NetworkImage(user.photoUrl!)
                  : null,
              child: user.photoUrl == null
                  ? Text(initials,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold))
                  : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.displayName,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14),
                  ),
                  if (user.matiere != null && user.matiere!.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 3),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2563EB).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        user.matiere!,
                        style: const TextStyle(
                            color: Color(0xFF2563EB),
                            fontSize: 11,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                ],
              ),
            ),
            // Statut dot
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                  color: Colors.green, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, color: Colors.white24, size: 20),
          ],
        ),
      ),
    );
  }
}
