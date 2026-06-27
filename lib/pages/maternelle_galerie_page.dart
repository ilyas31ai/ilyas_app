import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../widgets/cycle_access_guard.dart';

const _kColors = [Color(0xFFEC4899), Color(0xFF7C3AED)];

class MaternelleGaleriePage extends StatelessWidget {
  const MaternelleGaleriePage({super.key});

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

  String get _classeNom => user.classeNom ?? user.niveau ?? '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        elevation: 0,
        title: const Text('Galerie de la classe',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
      ),
      body: _classeNom.isEmpty
          ? const Center(child: Text('Classe non configurée', style: TextStyle(color: Colors.white38)))
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('galerie_photos')
                  .where('classeNom', isEqualTo: _classeNom)
                  .orderBy('date', descending: true)
                  .limit(24)
                  .snapshots(),
              builder: (_, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Color(0xFFEC4899)));
                }
                final docs = snap.data?.docs ?? [];
                return CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(child: _HeaderBanner()),
                    SliverToBoxAdapter(child: _DisclaimerCard()),
                    if (docs.isEmpty)
                      const SliverToBoxAdapter(child: _EmptyState())
                    else
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                        sliver: SliverGrid(
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                            childAspectRatio: 1.1,
                          ),
                          delegate: SliverChildBuilderDelegate(
                            (ctx, i) {
                              final d = docs[i].data() as Map<String, dynamic>;
                              return _PhotoCard(data: d);
                            },
                            childCount: docs.length,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
    );
  }
}

class _HeaderBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: _kColors, begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Row(
        children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Photos de classe', style: TextStyle(color: Colors.white60, fontSize: 11)),
              Text('Notre galerie', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
              Text('Moments capturés par l\'enseignant', style: TextStyle(color: Colors.white70, fontSize: 12)),
            ]),
          ),
          Icon(Icons.photo_library_outlined, color: Colors.white24, size: 44),
        ],
      ),
    );
  }
}

class _DisclaimerCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFEC4899).withValues(alpha: 0.2)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.shield_outlined, color: Color(0xFFEC4899), size: 16),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Photos publiées selon les autorisations signées avec l\'établissement. Toute diffusion externe est interdite.',
              style: TextStyle(color: Colors.white54, fontSize: 11, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _PhotoCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _PhotoCard({required this.data});

  static const _activityColors = [
    Color(0xFFEC4899), Color(0xFF9333EA), Color(0xFF2563EB),
    Color(0xFF0891B2), Color(0xFF15803D), Color(0xFFD97706),
  ];

  String get _dateLabel {
    final d = (data['date'] as Timestamp?)?.toDate() ?? DateTime.now();
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
  }

  Color _colorFor(String desc) {
    final idx = desc.hashCode.abs() % _activityColors.length;
    return _activityColors[idx];
  }

  @override
  Widget build(BuildContext context) {
    final desc = data['description'] as String? ?? 'Activité de classe';
    final url = data['url'] as String? ?? '';
    final color = _colorFor(desc);

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              child: url.isNotEmpty
                  ? Image.network(url, fit: BoxFit.cover, width: double.infinity,
                      errorBuilder: (_, __, ___) => _placeholder(color))
                  : _placeholder(color),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(desc, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(_dateLabel, style: const TextStyle(color: Colors.white38, fontSize: 10)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholder(Color color) {
    return Container(
      color: color.withValues(alpha: 0.08),
      child: Center(
        child: Icon(Icons.photo_outlined, color: color.withValues(alpha: 0.4), size: 36),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: const Column(children: [
        Icon(Icons.photo_library_outlined, color: Colors.white24, size: 48),
        SizedBox(height: 12),
        Text('Aucune photo pour l\'instant', style: TextStyle(color: Colors.white38, fontSize: 14)),
        SizedBox(height: 6),
        Text('L\'enseignant partagera ici les photos des activités de la classe.',
            style: TextStyle(color: Colors.white24, fontSize: 12), textAlign: TextAlign.center),
      ]),
    );
  }
}
