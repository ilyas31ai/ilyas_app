import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../widgets/cycle_access_guard.dart';

const _kColors = [Color(0xFF15803D), Color(0xFF0891B2)];

class MaternelleHistoiresPage extends StatelessWidget {
  const MaternelleHistoiresPage({super.key});

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

  static const _histoires = [
    _Histoire(
      'Le Petit Lapin Blanc',
      Color(0xFFEC4899),
      Icons.cruelty_free_outlined,
      'Il était une fois un petit lapin blanc qui vivait dans un grand champ fleuri.\n\nChaque matin, il sautait de son terrier pour explorer le monde. Un jour, il découvrit une carotte géante, aussi grande que lui !\n\n— Je ne pourrai jamais la porter seul, dit-il.\n\nAlors ses amis les lapins vinrent l\'aider, et ensemble ils partagèrent la carotte en petits morceaux pour tout le monde.\n\nFin. 🐇',
    ),
    _Histoire(
      'La Petite Étoile Perdue',
      Color(0xFF6366F1),
      Icons.star_outlined,
      'Haut dans le ciel, une petite étoile s\'était éloignée trop loin et ne trouvait plus son chemin.\n\nElle pleurait des larmes lumineuses qui tombaient sur la Terre comme des étoiles filantes.\n\nUn enfant les aperçut et fit un vœu : — Je souhaite que la petite étoile rentre chez elle !\n\nEt grâce à ce vœu plein d\'amour, l\'étoile retrouva sa place dans le ciel.\n\nFin. ⭐',
    ),
    _Histoire(
      'Les Nuages Farceurs',
      Color(0xFF0891B2),
      Icons.cloud_outlined,
      'Les nuages aimaient jouer à cache-cache avec le soleil.\n\n— Un, deux, trois ! comptait le grand nuage blanc. Et paf ! Il cachait le soleil qui riait sous sa barbe dorée.\n\nMais quand il pleuvait trop, les fleurs criaient : — Assez ! Nous voulons le soleil maintenant !\n\nAlors les nuages s\'écartaient, et l\'arc-en-ciel apparaissait : leur plus beau cadeau.\n\nFin. 🌈',
    ),
    _Histoire(
      'La Forêt qui Chante',
      Color(0xFF15803D),
      Icons.forest_outlined,
      'Dans une forêt enchantée, chaque arbre avait sa propre chanson.\n\nLe chêne bourdonnait comme une abeille. Le bouleau sifflait comme le vent. Le sapin chantait comme les oiseaux.\n\nUn jour, une petite fille perdue dans la forêt tendit l\'oreille. En écoutant la musique des arbres, elle retrouva son chemin jusqu\'à la maison.\n\nFin. 🌲',
    ),
    _Histoire(
      'Léo le Petit Poussin',
      Color(0xFFD97706),
      Icons.egg_alt_outlined,
      'Léo sortait tout juste de son œuf. Tout était nouveau : le soleil, les fleurs, les autres animaux de la ferme.\n\n— Bonjour ! dit Léo à la vache.\n— Meuh ! répondit la vache.\n— Bonjour ! dit Léo au chien.\n— Ouaf ! répondit le chien.\n\nLéo apprit ce jour-là que chacun a sa façon de dire bonjour, et que toutes ces langues forment une belle amitié.\n\nFin. 🐣',
    ),
    _Histoire(
      'Le Géant au Grand Cœur',
      Color(0xFF9333EA),
      Icons.favorite_outlined,
      'Il était une fois un géant si grand que les nuages lui chatouillaient les oreilles.\n\nTout le monde avait peur de lui... jusqu\'au jour où un petit garçon osa l\'approcher.\n\n— Tu n\'es pas méchant du tout ! dit l\'enfant.\n— Non, répondit le géant avec des larmes dans les yeux. Je suis juste très seul.\n\nDepuis ce jour, le géant et l\'enfant devinrent les meilleurs amis du monde.\n\nFin. 💜',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        elevation: 0,
        title: const Text('Histoires',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          _HeaderBanner(),
          const SizedBox(height: 16),
          ..._histoires.map((h) => _HistoireCard(histoire: h)),
        ],
      ),
    );
  }
}

class _Histoire {
  final String titre, texte;
  final Color color;
  final IconData icon;
  const _Histoire(this.titre, this.color, this.icon, this.texte);
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
              Text('À lire ensemble', style: TextStyle(color: Colors.white60, fontSize: 11)),
              Text('Petites histoires', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
              Text('Pour les tout-petits lecteurs', style: TextStyle(color: Colors.white70, fontSize: 12)),
            ]),
          ),
          Icon(Icons.auto_stories_outlined, color: Colors.white24, size: 44),
        ],
      ),
    );
  }
}

class _HistoireCard extends StatefulWidget {
  final _Histoire histoire;
  const _HistoireCard({required this.histoire});

  @override
  State<_HistoireCard> createState() => _HistoireCardState();
}

class _HistoireCardState extends State<_HistoireCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final h = widget.histoire;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: h.color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 42, height: 42,
                    decoration: BoxDecoration(color: h.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                    child: Icon(h.icon, color: h.color, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(h.titre,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
                  ),
                  Icon(_expanded ? Icons.expand_less : Icons.expand_more, color: Colors.white38, size: 20),
                ],
              ),
            ),
          ),
          if (_expanded) ...[
            const Divider(color: Colors.white10, height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Text(
                h.texte,
                style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.7),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
