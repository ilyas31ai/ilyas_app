import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../widgets/cycle_access_guard.dart';

const _kColors = [Color(0xFFBE185D), Color(0xFF7C3AED)];

class LyceeBacPage extends StatelessWidget {
  const LyceeBacPage({super.key});

  @override
  Widget build(BuildContext context) {
    return CycleAccessGuard(
      cycleCategorie: 'Lycée',
      cycleColors: _kColors,
      builder: (user) => _Body(user: user),
    );
  }
}

class _Body extends StatelessWidget {
  final UserModel user;
  const _Body({required this.user});

  static const _matieres = [
    (matiere: 'Langue Arabe', coeff: 3, unite: 'Toutes filières'),
    (matiere: 'Mathématiques', coeff: 6, unite: 'Sciences / Maths'),
    (matiere: 'Physique', coeff: 6, unite: 'Sciences Expérimentales'),
    (matiere: 'Sciences Naturelles', coeff: 6, unite: 'Sciences Expérimentales'),
    (matiere: 'Langue Française', coeff: 2, unite: 'Toutes filières'),
    (matiere: 'Langue Anglaise', coeff: 2, unite: 'Toutes filières'),
    (matiere: 'Philosophie', coeff: 2, unite: 'Toutes filières'),
    (matiere: 'Histoire-Géographie', coeff: 1, unite: 'Toutes filières'),
    (matiere: 'Éducation Islamique', coeff: 2, unite: 'Toutes filières'),
    (matiere: 'Éducation Civique', coeff: 1, unite: 'Toutes filières'),
  ];

  static const _conseils = [
    (icon: Icons.schedule_outlined, titre: 'Planning de révision', desc: 'Préparer un calendrier 6 mois avant le BAC avec priorité sur les matières à fort coefficient.'),
    (icon: Icons.library_books_outlined, titre: 'Sujets corrigés', desc: 'S\'entraîner sur les 5 dernières années de sujets officiels du BAC algérien.'),
    (icon: Icons.group_outlined, titre: 'Groupes d\'étude', desc: 'Constituer des groupes de révision avec des camarades de la même filière.'),
    (icon: Icons.timer_outlined, titre: 'Examens blancs', desc: 'Simuler les conditions d\'examen avec des examens blancs chronométrés.'),
    (icon: Icons.psychology_outlined, titre: 'Bien-être', desc: 'Respecter les pauses et le sommeil — la concentration dépend d\'un esprit reposé.'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        elevation: 0,
        title: const Text('Préparation BAC', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          _BacBanner(niveau: user.niveau),
          const SizedBox(height: 20),
          _sectionLabel('Matières & Coefficients'),
          const SizedBox(height: 10),
          ..._matieres.map((m) => _MatiereRow(matiere: m.matiere, coeff: m.coeff, unite: m.unite)),
          const SizedBox(height: 20),
          _sectionLabel('Conditions de réussite'),
          const SizedBox(height: 10),
          _ConditionsCard(),
          const SizedBox(height: 20),
          _sectionLabel('Conseils de préparation'),
          const SizedBox(height: 10),
          ..._conseils.map((c) => _ConseilCard(icon: c.icon, titre: c.titre, desc: c.desc)),
        ],
      ),
    );
  }

  Widget _sectionLabel(String t) => Text(
    t.toUpperCase(),
    style: const TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2),
  );
}

class _BacBanner extends StatelessWidget {
  final String? niveau;
  const _BacBanner({this.niveau});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: _kColors, begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Baccalauréat', style: TextStyle(color: Colors.white70, fontSize: 12)),
                const Text('Préparation & Informations', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(
                  'Cycle Secondaire · ${niveau ?? 'Lycée'}',
                  style: const TextStyle(color: Colors.white60, fontSize: 12),
                ),
              ],
            ),
          ),
          const Icon(Icons.school_outlined, color: Colors.white24, size: 52),
        ],
      ),
    );
  }
}

class _MatiereRow extends StatelessWidget {
  final String matiere;
  final int coeff;
  final String unite;
  const _MatiereRow({required this.matiere, required this.coeff, required this.unite});

  Color get _coeffColor {
    if (coeff >= 6) return const Color(0xFFDC2626);
    if (coeff >= 3) return const Color(0xFFD97706);
    return const Color(0xFF6C47FF);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(matiere, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
                Text(unite, style: const TextStyle(color: Colors.white38, fontSize: 11)),
              ],
            ),
          ),
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(color: _coeffColor.withValues(alpha: 0.15), shape: BoxShape.circle),
            child: Center(
              child: Text('×$coeff', style: TextStyle(color: _coeffColor, fontSize: 11, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConditionsCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const conditions = [
      'Moyenne générale ≥ 10/20 pour être admis',
      'Aucune matière clé (coeff ≥ 5) inférieure à 05/20',
      'Note éliminatoire < 05 dans certaines matières',
      'Présence obligatoire à toutes les épreuves',
      'Résultats publiés officiellement sur le site ONEFD',
    ];
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFBE185D).withValues(alpha: 0.2)),
      ),
      child: Column(
        children: conditions.map((c) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.chevron_right, color: Color(0xFFBE185D), size: 16),
              const SizedBox(width: 8),
              Expanded(child: Text(c, style: const TextStyle(color: Colors.white70, fontSize: 13))),
            ],
          ),
        )).toList(),
      ),
    );
  }
}

class _ConseilCard extends StatelessWidget {
  final IconData icon;
  final String titre;
  final String desc;
  const _ConseilCard({required this.icon, required this.titre, required this.desc});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(color: const Color(0xFF7C3AED).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(9)),
            child: Icon(icon, color: const Color(0xFF7C3AED), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titre, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 4),
                Text(desc, style: const TextStyle(color: Colors.white54, fontSize: 12, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RevisionsBanner extends StatelessWidget {
  final BuildContext parentContext;
  const _RevisionsBanner(this.parentContext);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(parentContext, '/etudiant_revisions'),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [
            const Color(0xFF7C3AED).withValues(alpha: 0.8),
            const Color(0xFFBE185D).withValues(alpha: 0.8),
          ]),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Row(
          children: [
            Icon(Icons.play_circle_outline, color: Colors.white, size: 32),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Commencer les révisions', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                  Text('Accès à l\'espace révisions adapté au BAC', style: TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 16),
          ],
        ),
      ),
    );
  }
}
