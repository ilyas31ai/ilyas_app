import 'package:flutter/material.dart';

import '../models/annonce_model.dart';
import '../services/etudiant_service.dart';

class EtudiantAnnoncesPage extends StatelessWidget {
  const EtudiantAnnoncesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        elevation: 0,
        title: const Text(
          'Annonces & Informations',
          style: TextStyle(
              color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<AnnonceModel>>(
              stream: EtudiantService.annoncesStream(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child: CircularProgressIndicator(
                          color: Color(0xFF2563EB)));
                }
                if (snap.hasError) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.campaign_outlined,
                              color: Colors.white24, size: 48),
                          SizedBox(height: 12),
                          Text(
                            'Annonces non disponibles',
                            style: TextStyle(
                                color: Colors.white60,
                                fontSize: 15,
                                fontWeight: FontWeight.w600),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Vérifiez votre connexion ou contactez l\'administration.',
                            textAlign: TextAlign.center,
                            style:
                                TextStyle(color: Colors.white38, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                final annonces = snap.data ?? [];
                if (annonces.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.campaign_outlined,
                            color: Colors.white24, size: 48),
                        SizedBox(height: 12),
                        Text('Aucune annonce',
                            style: TextStyle(
                                color: Colors.white38, fontSize: 15)),
                      ],
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                  itemCount: annonces.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) => _AnnonceCard(annonce: annonces[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}


// ── CARTE ANNONCE ─────────────────────────────────────────────────────────────
class _AnnonceCard extends StatelessWidget {
  final AnnonceModel annonce;
  const _AnnonceCard({required this.annonce});

  static const _typeConfig = {
    'annonce': [Color(0xFF2563EB), 'Annonce'],
    'examen': [Color(0xFFDC2626), 'Examen'],
    'evenement': [Color(0xFF16A34A), 'Evenement'],
    'info': [Color(0xFF4B5563), 'Info'],
  };

  @override
  Widget build(BuildContext context) {
    final config = _typeConfig[annonce.type] ??
        [const Color(0xFF4B5563), annonce.type];
    final typeColor = config[0] as Color;
    final typeLabel = config[1] as String;

    return InkWell(
      onTap: () => _showDetail(context),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF161B22),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    annonce.titre,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: typeColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    typeLabel,
                    style: TextStyle(
                        color: typeColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              annonce.contenu,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: Colors.white60, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.person_outline,
                    color: Colors.white24, size: 13),
                const SizedBox(width: 4),
                Text(
                  annonce.auteurNom.isNotEmpty
                      ? annonce.auteurNom
                      : 'Administration',
                  style: const TextStyle(
                      color: Colors.white38, fontSize: 11),
                ),
                const Spacer(),
                const Icon(Icons.calendar_today_outlined,
                    color: Colors.white24, size: 12),
                const SizedBox(width: 4),
                Text(
                  _formatDate(annonce.date),
                  style: const TextStyle(
                      color: Colors.white38, fontSize: 11),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showDetail(BuildContext context) {
    final config = _typeConfig[annonce.type] ??
        [const Color(0xFF4B5563), annonce.type];
    final typeColor = config[0] as Color;
    final typeLabel = config[1] as String;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF161B22),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.92,
        builder: (_, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: Text(
                    annonce.titre,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: typeColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    typeLabel,
                    style: TextStyle(
                        color: typeColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.person_outline,
                    color: Colors.white38, size: 14),
                const SizedBox(width: 6),
                Text(
                  annonce.auteurNom.isNotEmpty
                      ? annonce.auteurNom
                      : 'Administration',
                  style: const TextStyle(
                      color: Colors.white38, fontSize: 12),
                ),
                const SizedBox(width: 12),
                const Icon(Icons.calendar_today_outlined,
                    color: Colors.white38, size: 13),
                const SizedBox(width: 4),
                Text(
                  _formatDate(annonce.date),
                  style: const TextStyle(
                      color: Colors.white38, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(color: Colors.white12),
            const SizedBox(height: 12),
            Text(
              annonce.contenu,
              style: const TextStyle(
                  color: Colors.white70, fontSize: 14, height: 1.6),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}
