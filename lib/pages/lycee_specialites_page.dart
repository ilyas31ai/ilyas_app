import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../widgets/cycle_access_guard.dart';

const _kColors = [Color(0xFFD97706), Color(0xFFBE185D)];

class LyceeSpecialitesPage extends StatelessWidget {
  const LyceeSpecialitesPage({super.key});

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

  static const _filieres = [
    _Filiere(
      icon: Icons.science_outlined,
      nom: 'Sciences Expérimentales',
      code: 'SE',
      matieresCles: ['Biologie', 'Chimie', 'Physique', 'Maths'],
      debouches: ['Médecine', 'Pharmacie', 'Agronomie', 'Sciences naturelles'],
      color: Color(0xFF16A34A),
    ),
    _Filiere(
      icon: Icons.calculate_outlined,
      nom: 'Mathématiques',
      code: 'Math',
      matieresCles: ['Maths', 'Physique', 'Algorithmique', 'Français'],
      debouches: ['Génie civil', 'Informatique', 'Architecture', 'Économie'],
      color: Color(0xFF2563EB),
    ),
    _Filiere(
      icon: Icons.computer_outlined,
      nom: 'Technique Mathématique',
      code: 'TM',
      matieresCles: ['Maths', 'Technologie', 'Physique', 'Dessin technique'],
      debouches: ['Génie industriel', 'Électronique', 'Mécanique', 'BTP'],
      color: Color(0xFF0891B2),
    ),
    _Filiere(
      icon: Icons.menu_book_outlined,
      nom: 'Lettres et Philosophie',
      code: 'LP',
      matieresCles: ['Arabe', 'Français', 'Philosophie', 'Histoire-Géo'],
      debouches: ['Droit', 'Sciences politiques', 'Journalisme', 'Traduction'],
      color: Color(0xFFBE185D),
    ),
    _Filiere(
      icon: Icons.language_outlined,
      nom: 'Langues Étrangères',
      code: 'LE',
      matieresCles: ['Français', 'Anglais', 'Espagnol/Allemand', 'Littérature'],
      debouches: ['Traduction', 'Commerce international', 'Tourisme', 'Enseignement'],
      color: Color(0xFF7C3AED),
    ),
    _Filiere(
      icon: Icons.bar_chart_outlined,
      nom: 'Gestion et Économie',
      code: 'GE',
      matieresCles: ['Économie', 'Comptabilité', 'Droit', 'Maths'],
      debouches: ['Commerce', 'Finance', 'Administration', 'Marketing'],
      color: Color(0xFFD97706),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        elevation: 0,
        title: const Text('Filières & Spécialités', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          _HeaderBanner(niveau: user.niveau),
          const SizedBox(height: 20),
          ..._filieres.map((f) => _FiliereCard(filiere: f)),
        ],
      ),
    );
  }
}

class _HeaderBanner extends StatelessWidget {
  final String? niveau;
  const _HeaderBanner({this.niveau});

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
                const Text('Filières du Lycée', style: TextStyle(color: Colors.white70, fontSize: 12)),
                const Text('Choisir sa voie', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(
                  niveau != null ? 'Niveau : $niveau' : 'Cycle Secondaire — Algérie',
                  style: const TextStyle(color: Colors.white60, fontSize: 12),
                ),
              ],
            ),
          ),
          const Icon(Icons.star_half_outlined, color: Colors.white24, size: 48),
        ],
      ),
    );
  }
}

class _Filiere {
  final IconData icon;
  final String nom;
  final String code;
  final List<String> matieresCles;
  final List<String> debouches;
  final Color color;
  const _Filiere({
    required this.icon, required this.nom, required this.code,
    required this.matieresCles, required this.debouches, required this.color,
  });
}

class _FiliereCard extends StatefulWidget {
  final _Filiere filiere;
  const _FiliereCard({required this.filiere});

  @override
  State<_FiliereCard> createState() => _FiliereCardState();
}

class _FiliereCardState extends State<_FiliereCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final f = widget.filiere;
    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF161B22),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _expanded ? f.color.withValues(alpha: 0.4) : Colors.white.withValues(alpha: 0.05)),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 42, height: 42,
                    decoration: BoxDecoration(color: f.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                    child: Icon(f.icon, color: f.color, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(f.nom, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                        Text('Filière ${f.code}', style: TextStyle(color: f.color, fontSize: 11)),
                      ],
                    ),
                  ),
                  Icon(_expanded ? Icons.expand_less : Icons.expand_more, color: Colors.white38),
                ],
              ),
            ),
            if (_expanded) ...[
              const Divider(color: Colors.white10, height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SubSection('Matières clés', f.matieresCles, Icons.book_outlined, f.color),
                    const SizedBox(height: 10),
                    _SubSection('Débouchés', f.debouches, Icons.arrow_forward_outlined, const Color(0xFF0891B2)),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SubSection extends StatelessWidget {
  final String title;
  final List<String> items;
  final IconData icon;
  final Color color;
  const _SubSection(this.title, this.items, this.icon, this.color);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: items.map((item) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color.withValues(alpha: 0.2)),
            ),
            child: Text(item, style: TextStyle(color: color, fontSize: 11)),
          )).toList(),
        ),
      ],
    );
  }
}
