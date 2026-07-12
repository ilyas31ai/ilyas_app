import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../widgets/cycle_access_guard.dart';

const _kColors = [Color(0xFFBE185D), Color(0xFF7C3AED)];

class CollegeBrevePage extends StatelessWidget {
  const CollegeBrevePage({super.key});

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
        title: const Text('BEM — Brevet Moyen', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          _banner(niveau: user.niveau),
          const SizedBox(height: 20),
          _sectionLabel('Matières de l\'examen'),
          const SizedBox(height: 10),
          ..._kMatieresBEM.map((m) => _MatiereCard(matiere: m)),
          const SizedBox(height: 20),
          _sectionLabel('Conseils de préparation'),
          const SizedBox(height: 10),
          ..._kConseils.map((c) => _ConseilTile(conseil: c)),
          const SizedBox(height: 20),
          _sectionLabel('Chronométrage — Examens blancs'),
          const SizedBox(height: 10),
          _chronoBanner(context),
        ],
      ),
    );
  }

  Widget _banner({String? niveau}) => Container(
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
              const Text('Brevet de l\'Enseignement Moyen', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(niveau != null && niveau.isNotEmpty ? 'Niveau : $niveau' : 'Préparation BEM',
                  style: const TextStyle(color: Colors.white70, fontSize: 12)),
            ],
          ),
        ),
        const Icon(Icons.emoji_events_outlined, color: Colors.white24, size: 48),
      ],
    ),
  );

  Widget _chronoBanner(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFF161B22),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFBE185D).withValues(alpha: 0.3)),
    ),
    child: Row(
      children: [
        const Icon(Icons.timer_outlined, color: Color(0xFFBE185D), size: 32),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Examens blancs chronométrés', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
              SizedBox(height: 3),
              Text('Fonctionnalité à venir', style: TextStyle(color: Colors.white38, fontSize: 12)),
            ],
          ),
        ),
        const Icon(Icons.chevron_right, color: Colors.white24, size: 20),
      ],
    ),
  );

  Widget _sectionLabel(String t) => Text(
    t.toUpperCase(),
    style: const TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2),
  );
}

class _MatiereCard extends StatelessWidget {
  final ({String nom, String coeff, Color color}) matiere;
  const _MatiereCard({required this.matiere});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          Container(
            width: 8, height: 8,
            decoration: BoxDecoration(color: matiere.color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(matiere.nom, style: const TextStyle(color: Colors.white70, fontSize: 13))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: matiere.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text('Coeff. ${matiere.coeff}', style: TextStyle(color: matiere.color, fontSize: 11, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

class _ConseilTile extends StatelessWidget {
  final String conseil;
  const _ConseilTile({required this.conseil});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lightbulb_outline, color: Color(0xFFD97706), size: 16),
          const SizedBox(width: 10),
          Expanded(child: Text(conseil, style: const TextStyle(color: Colors.white60, fontSize: 13))),
        ],
      ),
    );
  }
}

const _kMatieresBEM = [
  (nom: 'Langue Arabe', coeff: '5', color: Color(0xFF2563EB)),
  (nom: 'Mathématiques', coeff: '4', color: Color(0xFF0F766E)),
  (nom: 'Langue Française', coeff: '3', color: Color(0xFF7C3AED)),
  (nom: 'Sciences Naturelles', coeff: '2', color: Color(0xFF16A34A)),
  (nom: 'Histoire-Géographie', coeff: '2', color: Color(0xFFD97706)),
  (nom: 'Éducation Islamique', coeff: '2', color: Color(0xFFBE185D)),
  (nom: 'Langue Étrangère 2', coeff: '2', color: Color(0xFF374151)),
];

const _kConseils = [
  'Révisez les chapitres clés en Mathématiques : fractions, algèbre, géométrie.',
  'En Français, entraînez-vous à la production écrite (rédaction, résumé).',
  'Relisez le programme d\'Histoire et de Géographie en synthèses courtes.',
  'Faites des exercices chronométrés pour vous habituer aux conditions d\'examen.',
  'Dormez suffisamment et révisez régulièrement plutôt qu\'en une seule fois.',
];
