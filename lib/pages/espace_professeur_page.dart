import 'package:flutter/material.dart';

import '../models/user_model.dart';
import '../services/user_service.dart';
import 'professeur_dashboard_page.dart';
import 'professeur_emploi_page.dart';
import 'professeur_eleves_page.dart';
import 'professeur_presences_page.dart';
import 'professeur_notes_page.dart';
import 'professeur_devoirs_page.dart';
import 'professeur_documents_page.dart';
import 'professeur_bibliotheque_page.dart';
import 'professeur_corrige_page.dart';
import 'professeur_evaluations_qualitative_page.dart';
import 'professeur_disponibilite_page.dart';
import 'professeur_messagerie_page.dart';
import 'professeur_bulletins_page.dart';
import 'professeur_rdv_page.dart';

const bool _kProfesseurOnly = true;

/// Hub de l'Espace Professeur — gestion pédagogique.
/// Accès conditionné par [_kProfesseurOnly] : si true, réservé à [UserRole.professeur].
class EspaceProfesseurPage extends StatelessWidget {
  const EspaceProfesseurPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        elevation: 0,
        title: const Text(
          'Espace Professeur',
          style: TextStyle(
              color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
      body: StreamBuilder<UserModel?>(
        stream: UserService.currentUserStream(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF0F766E)),
            );
          }
          final role = snap.data?.role;
          if (_kProfesseurOnly && role != UserRole.professeur) {
            return _AccessRefuse(name: snap.data?.displayName ?? '');
          }
          return _ProfesseurHome(user: snap.data);
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
              'Accès réservé aux Professeurs',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              name.isEmpty
                  ? 'Cet espace est réservé aux comptes Professeur.'
                  : 'Bonjour $name, cet espace est réservé aux comptes Professeur.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white38, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Hub Professeur ───────────────────────────────────────────────────────────

class _ProfesseurHome extends StatelessWidget {
  final UserModel? user;
  const _ProfesseurHome({this.user});

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _buildBanner()),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              _buildSectionLabel('Pédagogie'),
              const SizedBox(height: 8),
              _ModuleCard(
                icon: Icons.dashboard_customize_outlined,
                title: 'Tableau de bord',
                subtitle: 'Vue d\'ensemble : classes, élèves, devoirs',
                colors: const [Color(0xFF0F766E), Color(0xFF0891B2)],
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const ProfesseurDashboardPage())),
              ),
              _ModuleCard(
                icon: Icons.calendar_month_outlined,
                title: 'Emploi du temps',
                subtitle: 'Voir son planning, salles et matières',
                colors: const [Color(0xFF2563EB), Color(0xFF0891B2)],
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const ProfesseurEmploiPage())),
              ),
              _ModuleCard(
                icon: Icons.groups_outlined,
                title: 'Gestion des élèves',
                subtitle: 'Liste par classe, fiche élève',
                colors: const [Color(0xFF7C3AED), Color(0xFF6C47FF)],
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const ProfesseurElevesPage())),
              ),
              const SizedBox(height: 4),
              _buildSectionLabel('Suivi'),
              const SizedBox(height: 8),
              _ModuleCard(
                icon: Icons.how_to_reg_outlined,
                title: 'Présences',
                subtitle: 'Faire l\'appel, absences et retards',
                colors: const [Color(0xFF15803D), Color(0xFF16A34A)],
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const ProfesseurPresencesPage())),
              ),
              _ModuleCard(
                icon: Icons.grade_outlined,
                title: 'Notes',
                subtitle: 'Saisir notes et calculer les moyennes',
                colors: const [Color(0xFFD97706), Color(0xFFDC2626)],
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const ProfesseurNotesPage())),
              ),
              _ModuleCard(
                icon: Icons.description_outlined,
                title: 'Bulletins · Appréciations',
                subtitle: 'Rédiger les appréciations de fin de trimestre',
                colors: const [Color(0xFF0F766E), Color(0xFF6C47FF)],
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const ProfesseurBulletinsPage())),
              ),
              const SizedBox(height: 4),
              _buildSectionLabel('Ressources'),
              const SizedBox(height: 8),
              _ModuleCard(
                icon: Icons.assignment_outlined,
                title: 'Devoirs',
                subtitle: 'Envoyer devoirs avec date limite et fichier',
                colors: const [Color(0xFF6C47FF), Color(0xFF2563EB)],
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const ProfesseurDevoirsPage())),
              ),
              _ModuleCard(
                icon: Icons.folder_open_outlined,
                title: 'Documents pédagogiques',
                subtitle: 'Déposer cours, exercices, PDF, vidéos',
                colors: const [Color(0xFF0F766E), Color(0xFF15803D)],
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const ProfesseurDocumentsPage())),
              ),
              _ModuleCard(
                icon: Icons.library_books_outlined,
                title: 'Bibliothèque',
                subtitle: 'Consulter et rechercher tous vos documents',
                colors: const [Color(0xFF0891B2), Color(0xFF0F766E)],
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const ProfesseurBibliothequePage())),
              ),
              _ModuleCard(
                icon: Icons.task_alt_outlined,
                title: 'Corrigés',
                subtitle: 'Déposer un corrigé par devoir',
                colors: const [Color(0xFF15803D), Color(0xFF16A34A)],
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const ProfesseurCorrigePage())),
              ),
              _ModuleCard(
                icon: Icons.assignment_turned_in_outlined,
                title: 'Évaluations qualitatives',
                subtitle: 'Grille Acquis / En cours / Non acquis — Maternelle',
                colors: const [Color(0xFFEC4899), Color(0xFF9333EA)],
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const ProfesseurEvaluationsQualitativePage())),
              ),
              const SizedBox(height: 4),
              _buildSectionLabel('Communication'),
              const SizedBox(height: 8),
              _ModuleCard(
                icon: Icons.event_note_outlined,
                title: 'Rendez-vous parents',
                subtitle: 'Gérer les demandes de RDV des parents',
                colors: const [Color(0xFF1E3A5F), Color(0xFF2563EB)],
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const ProfesseurRdvPage())),
              ),
              _ModuleCard(
                icon: Icons.forum_outlined,
                title: 'Messages',
                subtitle: 'Élèves · Parents · Direction',
                colors: const [Color(0xFF1E3A5F), Color(0xFF2563EB)],
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const ProfesseurMessageriePage())),
              ),
              const SizedBox(height: 4),
              _buildSectionLabel('Disponibilités'),
              const SizedBox(height: 8),
              _ModuleCard(
                icon: Icons.event_available_outlined,
                title: 'Mes disponibilités',
                subtitle: 'Gérer mes horaires et déclarer une absence',
                colors: const [Color(0xFF6C47FF), Color(0xFF8B5CF6)],
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const ProfesseurDisponibilitePage())),
              ),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _buildBanner() {
    final matiere = user?.matiere;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F766E), Color(0xFF0891B2)],
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
                  user?.displayName.isNotEmpty == true
                      ? 'Bienvenue, ${user!.displayName}'
                      : 'Espace Professeur',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  matiere != null && matiere.isNotEmpty
                      ? '$matiere · Gestion pédagogique'
                      : 'Classes · Notes · Devoirs · Présences',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          const Icon(Icons.school, color: Colors.white24, size: 52),
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

// ─── Module Card ──────────────────────────────────────────────────────────────

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
                      style: const TextStyle(
                          color: Colors.white38, fontSize: 12)),
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
