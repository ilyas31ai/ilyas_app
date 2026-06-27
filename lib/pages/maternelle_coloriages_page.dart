import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../widgets/cycle_access_guard.dart';

const _kColors = [Color(0xFF9333EA), Color(0xFFEC4899)];

class MaternelleColoriagesPage extends StatelessWidget {
  const MaternelleColoriagesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return CycleAccessGuard(
      cycleCategorie: 'Maternelle',
      cycleColors: _kColors,
      builder: (user) => _Body(user: user),
    );
  }
}

class _Body extends StatelessWidget {
  final UserModel user;
  const _Body({required this.user});

  static const _categories = [
    _Cat('Animaux de la ferme', Icons.agriculture_outlined, Color(0xFF15803D),
        ['La vache', 'Le cochon', 'Le coq', 'L\'âne', 'Le mouton']),
    _Cat('Animaux de la jungle', Icons.forest_outlined, Color(0xFFD97706),
        ['Le lion', 'L\'éléphant', 'La girafe', 'Le singe', 'Le crocodile']),
    _Cat('Fruits et légumes', Icons.apple_outlined, Color(0xFFEC4899),
        ['La pomme', 'La banane', 'La fraise', 'La carotte', 'Le raisin']),
    _Cat('Véhicules', Icons.directions_car_outlined, Color(0xFF2563EB),
        ['La voiture', 'L\'avion', 'Le bateau', 'Le camion', 'Le train']),
    _Cat('La nature', Icons.local_florist_outlined, Color(0xFF0F766E),
        ['La fleur', 'L\'arbre', 'Le soleil', 'La pluie', 'L\'arc-en-ciel']),
    _Cat('Mon corps', Icons.accessibility_outlined, Color(0xFF9333EA),
        ['La main', 'Le visage', 'Les yeux', 'La bouche', 'Les oreilles']),
    _Cat('Fêtes et saisons', Icons.celebration_outlined, Color(0xFFD97706),
        ['L\'Aïd', 'Yennayer', 'Le printemps', 'L\'automne', 'La neige']),
    _Cat('Les chiffres', Icons.calculate_outlined, Color(0xFF0891B2),
        ['1 étoile', '2 papillons', '3 pommes', '4 ballons', '5 poissons']),
    _Cat('Les lettres', Icons.font_download_outlined, Color(0xFF6366F1),
        ['Aleph', 'Ba', 'A', 'B', 'Chiffres arabes']),
    _Cat('Formes géométriques', Icons.pentagon_outlined, Color(0xFFBE185D),
        ['Le cercle', 'Le carré', 'Le triangle', 'Le rectangle', 'L\'étoile']),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        elevation: 0,
        title: const Text('Coloriages & Fiches',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          _HeaderBanner(),
          const SizedBox(height: 12),
          _InfoCard(),
          const SizedBox(height: 16),
          ..._categories.map((c) => _CatCard(cat: c)),
        ],
      ),
    );
  }
}

class _Cat {
  final String titre;
  final IconData icon;
  final Color color;
  final List<String> fiches;
  const _Cat(this.titre, this.icon, this.color, this.fiches);
}

class _HeaderBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: _kColors, begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Row(
        children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Créativité & Motricité fine', style: TextStyle(color: Colors.white60, fontSize: 11)),
              Text('Coloriages & Fiches', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
              Text('10 thèmes · 50 fiches d\'activités', style: TextStyle(color: Colors.white70, fontSize: 12)),
            ]),
          ),
          Icon(Icons.palette_outlined, color: Colors.white24, size: 44),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF9333EA).withValues(alpha: 0.2)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.print_outlined, color: Color(0xFF9333EA), size: 16),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Les fiches d\'activités sont disponibles auprès de l\'enseignant. Demandez-les lors des réunions parents-professeurs.',
              style: TextStyle(color: Colors.white54, fontSize: 12, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _CatCard extends StatefulWidget {
  final _Cat cat;
  const _CatCard({required this.cat});

  @override
  State<_CatCard> createState() => _CatCardState();
}

class _CatCardState extends State<_CatCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.cat;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(color: c.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                    child: Icon(c.icon, color: c.color, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(c.titre, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
                        Text('${c.fiches.length} fiches disponibles', style: const TextStyle(color: Colors.white38, fontSize: 11)),
                      ],
                    ),
                  ),
                  Icon(_expanded ? Icons.expand_less : Icons.expand_more, color: Colors.white38),
                ],
              ),
            ),
          ),
          if (_expanded) ...[
            const Divider(color: Colors.white10, height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: c.fiches.map((f) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: c.color.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: c.color.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.description_outlined, color: c.color, size: 12),
                      const SizedBox(width: 4),
                      Text(f, style: TextStyle(color: c.color, fontSize: 11, fontWeight: FontWeight.w500)),
                    ],
                  ),
                )).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
