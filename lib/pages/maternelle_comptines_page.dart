import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../widgets/cycle_access_guard.dart';

const _kColors = [Color(0xFFD97706), Color(0xFFEC4899)];

class MaternelleComptinesPage extends StatelessWidget {
  const MaternelleComptinesPage({super.key});

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

  static const _comptines = [
    _Comptine(
      'Promenons-nous dans les bois',
      '🐺', Color(0xFF15803D),
      'Promenons-nous dans les bois\nPendant que le loup n\'y est pas\nSi le loup y était\nIl nous mangerait\nMais comme il n\'y est pas\nIl nous mangera pas !\n\nLoup y es-tu ? M\'entends-tu ? Que fais-tu ?',
      'À chanter en ronde, un enfant joue le loup',
    ),
    _Comptine(
      'Un, deux, trois, nous irons au bois',
      '🍓', Color(0xFFEC4899),
      'Un, deux, trois\nNous irons au bois\nQuatre, cinq, six\nCueillir des cerises\nSept, huit, neuf\nDans mon panier neuf\nDix, onze, douze\nElles seront toutes rouges !',
      'Pour apprendre les chiffres en s\'amusant',
    ),
    _Comptine(
      'Frère Jacques',
      '🔔', Color(0xFF2563EB),
      'Frère Jacques, Frère Jacques\nDormez-vous ? Dormez-vous ?\nSonnez les matines ! Sonnez les matines !\nDin, din, don ! Din, din, don !',
      'À chanter en canon avec deux groupes',
    ),
    _Comptine(
      'Il était un petit navire',
      '⛵', Color(0xFF0891B2),
      'Il était un petit navire\nQui n\'avait ja-ja-jamais navigué\nOhé ! Ohé !\n\nIl entreprit un long voyage\nSur la mer Mé-Mé-Méditerranée\nOhé ! Ohé !',
      'Avec gestes : vagues avec les bras',
    ),
    _Comptine(
      'Tête, épaules, genoux et pieds',
      '👤', Color(0xFF9333EA),
      'Tête, épaules, genoux et pieds\nGenoux et pieds, genoux et pieds\nTête, épaules, genoux et pieds\nYeux, oreilles, bouche et nez !',
      'Avec gestes sur chaque partie du corps',
    ),
    _Comptine(
      'L\'Alphabet en chanson',
      '🔤', Color(0xFFD97706),
      'A B C D E F G\nH I J K L M N O P\nQ R S T U V\nW X Y et Z\n\nMaintenant je sais mon A B C\nLa prochaine fois chante avec moi !',
      'Sur la même mélodie que Twinkle Twinkle',
    ),
    _Comptine(
      'Bateau sur l\'eau',
      '🚤', Color(0xFF0F766E),
      'Bateau sur l\'eau\nLa rivière, la rivière\nBateau sur l\'eau\nLa rivière et l\'eau\n\nTombé dans l\'eau !\nTombé dans l\'eau !',
      'Les enfants miment la chute à la fin',
    ),
    _Comptine(
      'Savez-vous planter des choux',
      '🥬', Color(0xFF15803D),
      'Savez-vous planter les choux\nÀ la mode, à la mode\nSavez-vous planter les choux\nÀ la mode de chez nous ?\n\nOn les plante avec les pieds\nÀ la mode, à la mode\nOn les plante avec les pieds\nÀ la mode de chez nous !',
      'À chanter en montrant chaque partie du corps',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        elevation: 0,
        title: const Text('Comptines & Chansons',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          _HeaderBanner(),
          const SizedBox(height: 16),
          ..._comptines.map((c) => _ComptineCard(comptine: c)),
        ],
      ),
    );
  }
}

class _Comptine {
  final String titre, emoji, paroles, conseil;
  final Color color;
  const _Comptine(this.titre, this.emoji, this.color, this.paroles, this.conseil);
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
              Text('Musique & Langage', style: TextStyle(color: Colors.white60, fontSize: 11)),
              Text('Comptines & Chansons', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
              Text('Pour chanter et danser en classe', style: TextStyle(color: Colors.white70, fontSize: 12)),
            ]),
          ),
          Icon(Icons.music_note_outlined, color: Colors.white24, size: 44),
        ],
      ),
    );
  }
}

class _ComptineCard extends StatefulWidget {
  final _Comptine comptine;
  const _ComptineCard({required this.comptine});

  @override
  State<_ComptineCard> createState() => _ComptineCardState();
}

class _ComptineCardState extends State<_ComptineCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.comptine;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(color: c.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                    child: Center(child: Text(c.emoji, style: const TextStyle(fontSize: 22))),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(c.titre, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
                        Text(c.conseil, style: const TextStyle(color: Colors.white38, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  Icon(_expanded ? Icons.expand_less : Icons.music_note, color: c.color, size: 18),
                ],
              ),
            ),
          ),
          if (_expanded) ...[
            const Divider(color: Colors.white10, height: 1),
            Container(
              margin: const EdgeInsets.all(14),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: c.color.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: c.color.withValues(alpha: 0.12)),
              ),
              child: Text(
                c.paroles,
                style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.9, fontStyle: FontStyle.italic),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Row(
                children: [
                  const Icon(Icons.tips_and_updates_outlined, color: Colors.white38, size: 14),
                  const SizedBox(width: 6),
                  Expanded(child: Text(c.conseil, style: const TextStyle(color: Colors.white54, fontSize: 11))),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
