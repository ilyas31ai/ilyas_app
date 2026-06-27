import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../widgets/cycle_access_guard.dart';

const _kColors = [Color(0xFFEC4899), Color(0xFF9333EA)];

class MaternelleCahierViePage extends StatelessWidget {
  const MaternelleCahierViePage({super.key});

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

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        elevation: 0,
        title: const Text('Cahier de vie',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
      ),
      body: uid.isEmpty
          ? const Center(child: Text('Non connecté', style: TextStyle(color: Colors.white38)))
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('cahier_vie')
                  .where('eleveId', isEqualTo: uid)
                  .orderBy('date', descending: true)
                  .limit(30)
                  .snapshots(),
              builder: (_, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Color(0xFFEC4899)));
                }
                final docs = snap.data?.docs ?? [];
                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                  children: [
                    _HeaderCard(prenom: user.displayName),
                    const SizedBox(height: 16),
                    if (docs.isEmpty)
                      _EmptyState()
                    else
                      ...docs.map((doc) {
                        final d = doc.data() as Map<String, dynamic>;
                        return _EntreeCard(
                          date: (d['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
                          titre: d['titre'] as String? ?? 'Un beau moment',
                          contenu: d['contenu'] as String? ?? '',
                          auteur: d['auteur'] as String? ?? 'L\'enseignant',
                          type: d['type'] as String? ?? 'moment',
                        );
                      }),
                  ],
                );
              },
            ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  final String prenom;
  const _HeaderCard({required this.prenom});

  @override
  Widget build(BuildContext context) {
    return Container(
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
                const Text('Maternelle', style: TextStyle(color: Colors.white60, fontSize: 11)),
                Text(
                  prenom.isNotEmpty ? 'Le cahier de $prenom' : 'Mon cahier de vie',
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Text('Souvenirs & moments de classe', style: TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
          const Icon(Icons.menu_book_outlined, color: Colors.white24, size: 48),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        children: [
          const Icon(Icons.auto_stories_outlined, color: Colors.white24, size: 56),
          const SizedBox(height: 16),
          const Text('Le cahier de vie sera bientôt rempli !',
              style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center),
          const SizedBox(height: 8),
          const Text(
            'L\'enseignant ajoutera ici les beaux moments de la classe : sorties, fêtes, créations et découvertes.',
            style: TextStyle(color: Colors.white38, fontSize: 13, height: 1.5),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _EntreeCard extends StatelessWidget {
  final DateTime date;
  final String titre, contenu, auteur, type;
  const _EntreeCard({required this.date, required this.titre, required this.contenu, required this.auteur, required this.type});

  static const _typeData = {
    'sortie':    (color: Color(0xFF2563EB), icon: Icons.directions_bus_outlined, label: 'Sortie'),
    'activite':  (color: Color(0xFFEC4899), icon: Icons.palette_outlined,       label: 'Activité'),
    'projet':    (color: Color(0xFF9333EA), icon: Icons.science_outlined,        label: 'Projet'),
    'fete':      (color: Color(0xFFD97706), icon: Icons.celebration_outlined,    label: 'Fête'),
    'moment':    (color: Color(0xFF15803D), icon: Icons.favorite_outlined,       label: 'Moment'),
  };

  String get _dateLabel => '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

  @override
  Widget build(BuildContext context) {
    final td = _typeData[type] ?? _typeData['moment']!;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: td.color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(color: td.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                child: Icon(td.icon, color: td.color, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(titre, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
                    Text('$auteur · $_dateLabel', style: const TextStyle(color: Colors.white38, fontSize: 11)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: td.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
                child: Text(td.label, style: TextStyle(color: td.color, fontSize: 10, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          if (contenu.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Divider(color: Colors.white10, height: 1),
            const SizedBox(height: 10),
            Text(contenu, style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.5)),
          ],
        ],
      ),
    );
  }
}
