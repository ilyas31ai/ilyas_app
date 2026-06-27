import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../widgets/cycle_access_guard.dart';

const _kColors = [Color(0xFF15803D), Color(0xFF16A34A)];

class UniversiteMemoiresPage extends StatelessWidget {
  const UniversiteMemoiresPage({super.key});

  @override
  Widget build(BuildContext context) {
    return CycleAccessGuard(
      cycleCategorie: 'Université',
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
        title: const Text('Mon Mémoire', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('memoires')
            .where('etudiantId', isEqualTo: uid)
            .snapshots(),
        builder: (_, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF16A34A)));
          }
          final docs = snap.data?.docs ?? [];
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              _HeaderBanner(niveau: user.niveau),
              const SizedBox(height: 16),
              if (docs.isEmpty) ...[
                _NoMemoire(),
                const SizedBox(height: 16),
                _GuideCard(),
              ] else ...[
                ...docs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return _MemoireCard(
                    titre: data['titre'] as String? ?? 'Mémoire',
                    encadrant: data['encadrantNom'] as String? ?? '',
                    avancement: (data['avancement'] as num?)?.toInt() ?? 0,
                    statut: data['statut'] as String? ?? 'en_cours',
                    dateDepot: (data['dateDepot'] as Timestamp?)?.toDate(),
                  );
                }),
                const SizedBox(height: 16),
                _EtapesMemoire(),
              ],
            ],
          );
        },
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
                const Text('Travail de Fin d\'Études', style: TextStyle(color: Colors.white70, fontSize: 12)),
                const Text('Mémoire de Recherche', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                Text(niveau ?? 'Master / Licence', style: const TextStyle(color: Colors.white60, fontSize: 12)),
              ],
            ),
          ),
          const Icon(Icons.menu_book_outlined, color: Colors.white24, size: 48),
        ],
      ),
    );
  }
}

class _MemoireCard extends StatelessWidget {
  final String titre, encadrant, statut;
  final int avancement;
  final DateTime? dateDepot;
  const _MemoireCard({required this.titre, required this.encadrant, required this.avancement, required this.statut, this.dateDepot});

  Color get _statusColor {
    if (statut == 'depose') return const Color(0xFF16A34A);
    if (statut == 'valide') return const Color(0xFF2563EB);
    return const Color(0xFFD97706);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _statusColor.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(titre, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: _statusColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
                child: Text(
                  statut == 'depose' ? 'Déposé' : statut == 'valide' ? 'Validé' : 'En cours',
                  style: TextStyle(color: _statusColor, fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          if (encadrant.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('Encadrant : $encadrant', style: const TextStyle(color: Colors.white60, fontSize: 12)),
          ],
          if (dateDepot != null) ...[
            const SizedBox(height: 4),
            Text(
              'Date de dépôt : ${dateDepot!.day.toString().padLeft(2, '0')}/${dateDepot!.month.toString().padLeft(2, '0')}/${dateDepot!.year}',
              style: const TextStyle(color: Colors.white38, fontSize: 12),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              const Text('Avancement : ', style: TextStyle(color: Colors.white54, fontSize: 12)),
              Text('$avancement %', style: TextStyle(color: _statusColor, fontWeight: FontWeight.bold, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: avancement / 100,
              backgroundColor: Colors.white12,
              color: _statusColor,
              minHeight: 7,
            ),
          ),
        ],
      ),
    );
  }
}

class _NoMemoire extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: const Column(
        children: [
          Icon(Icons.book_outlined, color: Colors.white24, size: 48),
          SizedBox(height: 12),
          Text('Aucun mémoire enregistré', style: TextStyle(color: Colors.white38, fontSize: 14)),
          SizedBox(height: 6),
          Text('Votre mémoire sera ajouté par votre département après validation du sujet.',
              style: TextStyle(color: Colors.white24, fontSize: 12), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _GuideCard extends StatelessWidget {
  static const _etapes = [
    (n: '1', t: 'Choix du sujet', d: 'Proposer 3 thèmes à votre encadrant potentiel'),
    (n: '2', t: 'Validation du sujet', d: 'Approbation par le chef de département'),
    (n: '3', t: 'Rédaction', d: 'Respecter la charte graphique et le plan type'),
    (n: '4', t: 'Dépôt final', d: 'Version imprimée + fichier numérique avant la date limite'),
    (n: '5', t: 'Soutenance', d: 'Présentation de 20 min + questions du jury'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF15803D).withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Guide du mémoire', style: TextStyle(color: Color(0xFF16A34A), fontWeight: FontWeight.w700, fontSize: 13)),
          const SizedBox(height: 10),
          ..._etapes.map((e) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 20, height: 20,
                  decoration: const BoxDecoration(color: Color(0xFF15803D), shape: BoxShape.circle),
                  child: Center(child: Text(e.n, style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold))),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(e.t, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12)),
                      Text(e.d, style: const TextStyle(color: Colors.white38, fontSize: 11)),
                    ],
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }
}

class _EtapesMemoire extends StatelessWidget {
  @override
  Widget build(BuildContext context) => _GuideCard();
}
