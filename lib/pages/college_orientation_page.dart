import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../widgets/cycle_access_guard.dart';

const _kColors = [Color(0xFF374151), Color(0xFF1E3A5F)];

class CollegeOrientationPage extends StatelessWidget {
  const CollegeOrientationPage({super.key});

  @override
  Widget build(BuildContext context) {
    return CycleAccessGuard(
      cycleCategorie: 'Collège',
      cycleColors: _kColors,
      builder: (user) => _Body(user: user),
    );
  }
}

class _Body extends StatelessWidget {
  final UserModel user;
  const _Body({required this.user});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        elevation: 0,
        title: const Text('Orientation — Secondaire', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          _header(niveau: user.niveau),
          const SizedBox(height: 20),
          _sectionLabel('Filières disponibles en 1ère Année Secondaire'),
          const SizedBox(height: 10),
          ..._kFilieres.map((f) => _FiliereCard(filiere: f)),
          const SizedBox(height: 20),
          _sectionLabel('Critères d\'orientation'),
          const SizedBox(height: 10),
          _criteresCard(),
          const SizedBox(height: 20),
          _sectionLabel('Calendrier'),
          const SizedBox(height: 10),
          ..._kEtapes.map((e) => _EtapeRow(etape: e)),
        ],
      ),
    );
  }

  Widget _sectionLabel(String t) => Text(
    t.toUpperCase(),
    style: const TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2),
  );

  Widget _header({String? niveau}) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      gradient: const LinearGradient(colors: _kColors, begin: Alignment.topLeft, end: Alignment.bottomRight),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Votre orientation', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(niveau != null ? 'Niveau actuel : $niveau' : 'Cycle Moyen',
                  style: const TextStyle(color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 6),
              const Text('Décision du conseil de classe en fin d\'année.', style: TextStyle(color: Colors.white54, fontSize: 11)),
            ],
          ),
        ),
        const Icon(Icons.explore_outlined, color: Colors.white24, size: 44),
      ],
    ),
  );

  Widget _criteresCard() => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFF161B22),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: _kCriteres.map((c) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.chevron_right, color: Color(0xFF0891B2), size: 16),
            const SizedBox(width: 8),
            Expanded(child: Text(c, style: const TextStyle(color: Colors.white60, fontSize: 13))),
          ],
        ),
      )).toList(),
    ),
  );
}

class _FiliereCard extends StatelessWidget {
  final ({String nom, String description, Color color, IconData icon}) filiere;
  const _FiliereCard({required this.filiere});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: filiere.color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: filiere.color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
            child: Icon(filiere.icon, color: filiere.color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(filiere.nom, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 3),
                Text(filiere.description, style: const TextStyle(color: Colors.white38, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EtapeRow extends StatelessWidget {
  final ({String label, String date}) etape;
  const _EtapeRow({required this.etape});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFF0891B2), shape: BoxShape.circle)),
          const SizedBox(width: 12),
          Expanded(child: Text(etape.label, style: const TextStyle(color: Colors.white60, fontSize: 13))),
          Text(etape.date, style: const TextStyle(color: Colors.white38, fontSize: 12)),
        ],
      ),
    );
  }
}

const _kFilieres = [
  (nom: 'Sciences', description: 'Mathématiques · Physique · SVT', color: Color(0xFF0F766E), icon: Icons.science_outlined),
  (nom: 'Lettres & Sciences Humaines', description: 'Littérature · Histoire · Philosophie', color: Color(0xFF7C3AED), icon: Icons.menu_book_outlined),
  (nom: 'Langues Étrangères', description: 'Français · Anglais · Espagnol', color: Color(0xFF2563EB), icon: Icons.language_outlined),
  (nom: 'Gestion & Économie', description: 'Économie · Comptabilité · Droit', color: Color(0xFFD97706), icon: Icons.business_outlined),
  (nom: 'Mathématiques', description: 'Mathématiques approfondies · Physique', color: Color(0xFFBE185D), icon: Icons.calculate_outlined),
];

const _kCriteres = [
  'Moyenne annuelle dans toutes les matières',
  'Avis du conseil de classe et de l\'enseignant principal',
  'Résultats au Brevet de l\'Enseignement Moyen (BEM)',
  'Vœux de l\'élève et de la famille',
];

const _kEtapes = [
  (label: 'Vœux d\'orientation (familles)', date: 'Avr.'),
  (label: 'Délibérations conseil de classe', date: 'Mai'),
  (label: 'Résultats BEM', date: 'Juin'),
  (label: 'Affectation lycée', date: 'Juil.'),
];
