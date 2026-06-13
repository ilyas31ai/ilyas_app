import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/etudiant_service.dart';

class ElevesPage extends StatelessWidget {
  const ElevesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        elevation: 0,
        title: const Text(
          'Espace Etudiant',
          style: TextStyle(
              color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
      body: StreamBuilder<String?>(
        stream: EtudiantService.classeNomStream(),
        builder: (context, snap) {
          final classeNom = snap.data;
          return _StudentHub(classeNom: classeNom);
        },
      ),
    );
  }
}

class _StudentHub extends StatelessWidget {
  final String? classeNom;
  const _StudentHub({required this.classeNom});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final displayName = user?.displayName ?? user?.email ?? 'Etudiant';

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6C47FF), Color(0xFF2563EB)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Bienvenue',
                    style: TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 4),
                Text(
                  displayName,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    classeNom ?? 'Classe non assignee',
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(child: _sectionLabel('Tableau de bord')),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              _NavCard(
                icon: Icons.dashboard_outlined,
                title: 'Tableau de bord',
                subtitle: 'Apercu general de votre scolarite',
                colors: const [Color(0xFF6C47FF), Color(0xFF2563EB)],
                onTap: () =>
                    Navigator.pushNamed(context, '/etudiant_dashboard'),
              ),
            ]),
          ),
        ),
        SliverToBoxAdapter(child: _sectionLabel('Scolarite')),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              _NavCard(
                icon: Icons.assignment_outlined,
                title: 'Mes Devoirs',
                subtitle: 'Consulter et remettre vos devoirs',
                colors: const [Color(0xFF7C3AED), Color(0xFF6C47FF)],
                onTap: () =>
                    Navigator.pushNamed(context, '/etudiant_devoirs'),
              ),
              const SizedBox(height: 10),
              _NavCard(
                icon: Icons.menu_book_outlined,
                title: 'Révisions',
                subtitle: 'Cours, exercices et quiz par matière',
                colors: const [Color(0xFF0F766E), Color(0xFF16A34A)],
                onTap: () =>
                    Navigator.pushNamed(context, '/etudiant_revisions'),
              ),
              const SizedBox(height: 10),
              _NavCard(
                icon: Icons.bar_chart_outlined,
                title: 'Notes & Resultats',
                subtitle: 'Vos notes et moyennes par matiere',
                colors: const [Color(0xFF0891B2), Color(0xFF2563EB)],
                onTap: () => Navigator.pushNamed(context, '/notes'),
              ),
              const SizedBox(height: 10),
              _NavCard(
                icon: Icons.schedule_outlined,
                title: 'Emploi du temps',
                subtitle: 'Votre planning hebdomadaire',
                colors: const [Color(0xFF15803D), Color(0xFF16A34A)],
                onTap: () => Navigator.pushNamed(context, '/emploi'),
              ),
            ]),
          ),
        ),
        SliverToBoxAdapter(child: _sectionLabel('Ressources')),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              _NavCard(
                icon: Icons.folder_outlined,
                title: 'Documents pedagogiques',
                subtitle: 'Cours, exercices et corrections',
                colors: const [Color(0xFFD97706), Color(0xFFB45309)],
                onTap: () =>
                    Navigator.pushNamed(context, '/etudiant_documents'),
              ),
              const SizedBox(height: 10),
              _NavCard(
                icon: Icons.campaign_outlined,
                title: 'Annonces',
                subtitle: "Actualites et informations de l'ecole",
                colors: const [Color(0xFF0F766E), Color(0xFF0891B2)],
                onTap: () =>
                    Navigator.pushNamed(context, '/etudiant_annonces'),
              ),
            ]),
          ),
        ),
        SliverToBoxAdapter(child: _sectionLabel('Autre')),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              _NavCard(
                icon: Icons.notifications_outlined,
                title: 'Notifications',
                subtitle: 'Vos alertes et rappels',
                colors: const [Color(0xFF374151), Color(0xFF4B5563)],
                onTap: () => Navigator.pushNamed(context, '/notifications'),
              ),
              const SizedBox(height: 10),
              _NavCard(
                icon: Icons.info_outline,
                title: 'Informations administratives',
                subtitle: 'Calendrier, examens, evenements',
                colors: const [Color(0xFF0F766E), Color(0xFF0D9488)],
                onTap: () =>
                    Navigator.pushNamed(context, '/etudiant_annonces'),
              ),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _sectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          color: Colors.white38,
          fontSize: 11,
          letterSpacing: 1.2,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _NavCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final List<Color> colors;
  final VoidCallback onTap;

  const _NavCard({
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
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF161B22),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: colors),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: const TextStyle(
                          color: Colors.white38, fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white38, size: 20),
          ],
        ),
      ),
    );
  }
}
