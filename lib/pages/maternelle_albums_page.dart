import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../widgets/cycle_access_guard.dart';

const _kColors = [Color(0xFF2563EB), Color(0xFF9333EA)];

class MaternelleAlbumsPage extends StatelessWidget {
  const MaternelleAlbumsPage({super.key});

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

  static const _albums = [
    _Album('Le lion qui ne savait pas lire', 'Martin Baltscheit', '3–6 ans',
        'Un lion fier découvre que lire ouvre des mondes infinis.',
        Color(0xFFD97706), Icons.auto_stories_outlined),
    _Album('La chenille qui fait des trous', 'Eric Carle', '2–5 ans',
        'Une petite chenille mange, grandit et se transforme en papillon.',
        Color(0xFF15803D), Icons.bug_report_outlined),
    _Album('Max et les Maximonstres', 'Maurice Sendak', '4–7 ans',
        'Max part dans le pays des monstres et devient leur roi.',
        Color(0xFF9333EA), Icons.rocket_launch_outlined),
    _Album('Le Gruffalo', 'Julia Donaldson', '3–6 ans',
        'Une petite souris invente un monstre pour échapper aux prédateurs.',
        Color(0xFF0891B2), Icons.forest_outlined),
    _Album('Petit Ours Brun', 'Marie Aubinais', '2–4 ans',
        'Les aventures quotidiennes d\'un petit ours attachant.',
        Color(0xFF92400E), Icons.child_friendly_outlined),
    _Album('Elmer l\'éléphant bariolé', 'David McKee', '3–6 ans',
        'Elmer est différent des autres et c\'est ce qui le rend unique.',
        Color(0xFFEC4899), Icons.colorize_outlined),
    _Album('L\'Imagier des tout-petits', 'Collectif', '1–3 ans',
        'Premiers mots illustrés pour découvrir le monde.',
        Color(0xFF2563EB), Icons.image_outlined),
    _Album('Martine à l\'école', 'Gilbert Delahaye', '4–7 ans',
        'Martine découvre la vie à l\'école avec ses amis.',
        Color(0xFFBE185D), Icons.school_outlined),
    _Album('Tchoupi à la maternelle', 'Thierry Courtin', '2–5 ans',
        'Tchoupi vit ses premières aventures à l\'école maternelle.',
        Color(0xFF0F766E), Icons.child_care_outlined),
    _Album('La petite poule rousse', 'Conte traditionnel', '3–6 ans',
        'La poule rousse apprend à ses amis les valeurs du travail.',
        Color(0xFFD97706), Icons.egg_alt_outlined),
    _Album('Les Trois Petits Cochons', 'Conte traditionnel', '3–6 ans',
        'Trois frères cochons construisent leurs maisons face au grand méchant loup.',
        Color(0xFF374151), Icons.home_outlined),
    _Album('Boucle d\'Or', 'Conte traditionnel', '3–6 ans',
        'Une petite fille curieuse explore la maison de trois ours.',
        Color(0xFF92400E), Icons.house_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        elevation: 0,
        title: const Text('Albums illustrés',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          _HeaderBanner(),
          const SizedBox(height: 16),
          ..._albums.map((a) => _AlbumCard(album: a)),
        ],
      ),
    );
  }
}

class _Album {
  final String titre, auteur, age, description;
  final Color color;
  final IconData icon;
  const _Album(this.titre, this.auteur, this.age, this.description, this.color, this.icon);
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
              Text('Littérature jeunesse', style: TextStyle(color: Colors.white60, fontSize: 11)),
              Text('Albums illustrés', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
              Text('Sélection pour les 2–7 ans', style: TextStyle(color: Colors.white70, fontSize: 12)),
            ]),
          ),
          Icon(Icons.library_books_outlined, color: Colors.white24, size: 44),
        ],
      ),
    );
  }
}

class _AlbumCard extends StatelessWidget {
  final _Album album;
  const _AlbumCard({required this.album});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: album.color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(
              color: album.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(album.icon, color: album.color, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(album.titre, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(album.auteur, style: TextStyle(color: album.color, fontSize: 12, fontWeight: FontWeight.w500)),
                Text(album.description, style: const TextStyle(color: Colors.white54, fontSize: 11, height: 1.3),
                    maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: album.color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(album.age, style: TextStyle(color: album.color, fontSize: 10, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
