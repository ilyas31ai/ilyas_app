import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/permission_model.dart';
import '../models/user_model.dart';
import '../services/user_service.dart';
import 'direction_comptes_attente_page.dart';
import 'direction_classes_page.dart';
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

// Restreint l'Espace Direction aux comptes [UserRole.admin] uniquement.
const bool _kAdminOnly = true;

/// Hub de l'Espace Direction — gestion des inscriptions scolaires.
/// Accès conditionné par [_kAdminOnly] : si true, réservé à [UserRole.admin].
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
              _buildSectionLabel('Gestion des enseignants'),
              const SizedBox(height: 8),
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
        final count = snap.data?.docs.length ?? 0;
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
