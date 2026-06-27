import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../widgets/cycle_access_guard.dart';

const _kColors = [Color(0xFF1E3A5F), Color(0xFF0891B2)];

class UniversiteSoutenancesPage extends StatelessWidget {
  const UniversiteSoutenancesPage({super.key});

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
        title: const Text('Soutenance', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('soutenances')
            .where('etudiantId', isEqualTo: uid)
            .snapshots(),
        builder: (_, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF0891B2)));
          }
          final docs = snap.data?.docs ?? [];
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              _HeaderBanner(niveau: user.niveau),
              const SizedBox(height: 16),
              if (docs.isEmpty) ...[
                _NoSoutenance(),
                const SizedBox(height: 16),
                _PrepaCard(),
              ] else ...[
                ...docs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return _SoutenanceCard(
                    date: (data['date'] as Timestamp?)?.toDate(),
                    heure: data['heure'] as String? ?? '',
                    salle: data['salle'] as String? ?? '',
                    jury: (data['jury'] as List?)?.cast<String>() ?? [],
                    mention: data['mention'] as String? ?? '',
                    note: (data['note'] as num?)?.toDouble(),
                    statut: data['statut'] as String? ?? 'planifie',
                  );
                }),
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
                const Text('Présentation finale', style: TextStyle(color: Colors.white70, fontSize: 12)),
                const Text('Soutenance de Mémoire', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                Text(niveau ?? 'Master / Licence', style: const TextStyle(color: Colors.white60, fontSize: 12)),
              ],
            ),
          ),
          const Icon(Icons.mic_outlined, color: Colors.white24, size: 48),
        ],
      ),
    );
  }
}

class _SoutenanceCard extends StatelessWidget {
  final DateTime? date;
  final String heure, salle, mention, statut;
  final List<String> jury;
  final double? note;
  const _SoutenanceCard({this.date, required this.heure, required this.salle, required this.jury, required this.mention, this.note, required this.statut});

  Color get _color {
    if (statut == 'effectuee') return const Color(0xFF16A34A);
    if (statut == 'planifie') return const Color(0xFF2563EB);
    return const Color(0xFFD97706);
  }

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.mic_outlined, color: _color, size: 28),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      date != null ? _fmt(date!) : 'Date à définir',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    if (heure.isNotEmpty || salle.isNotEmpty)
                      Text('${heure.isNotEmpty ? heure : ''}${salle.isNotEmpty ? ' · Salle $salle' : ''}',
                          style: const TextStyle(color: Colors.white60, fontSize: 12)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: _color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
                child: Text(
                  statut == 'effectuee' ? 'Effectuée' : statut == 'planifie' ? 'Planifiée' : 'En attente',
                  style: TextStyle(color: _color, fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          if (jury.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Text('Membres du jury :', style: TextStyle(color: Colors.white54, fontSize: 12)),
            ...jury.map((j) => Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Row(
                children: [
                  const Icon(Icons.person_outline, color: Colors.white24, size: 14),
                  const SizedBox(width: 6),
                  Text(j, style: const TextStyle(color: Colors.white60, fontSize: 12)),
                ],
              ),
            )),
          ],
          if (note != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF16A34A).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF16A34A).withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.emoji_events_outlined, color: Color(0xFF16A34A), size: 22),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${note!.toStringAsFixed(1)} / 20',
                          style: const TextStyle(color: Color(0xFF16A34A), fontWeight: FontWeight.bold, fontSize: 18)),
                      if (mention.isNotEmpty)
                        Text('Mention : $mention', style: const TextStyle(color: Colors.white60, fontSize: 12)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _NoSoutenance extends StatelessWidget {
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
          Icon(Icons.mic_off_outlined, color: Colors.white24, size: 48),
          SizedBox(height: 12),
          Text('Aucune soutenance planifiée', style: TextStyle(color: Colors.white38, fontSize: 14)),
          SizedBox(height: 6),
          Text('La date de votre soutenance sera communiquée par votre département.',
              style: TextStyle(color: Colors.white24, fontSize: 12), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _PrepaCard extends StatelessWidget {
  static const _conseils = [
    (icon: Icons.timer_outlined, t: 'Durée', d: 'Préparez une présentation de 20 minutes précises'),
    (icon: Icons.slideshow_outlined, t: 'Slides', d: 'Entre 15 et 20 diapositives maximum'),
    (icon: Icons.question_answer_outlined, t: 'Questions', d: 'Anticipez les questions sur votre méthodologie'),
    (icon: Icons.people_outlined, t: 'Jury', d: 'Soignez votre communication verbale et non verbale'),
    (icon: Icons.task_alt_outlined, t: 'Logistique', d: 'Testez le matériel de projection à l\'avance'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF0891B2).withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Préparer sa soutenance', style: TextStyle(color: Color(0xFF0891B2), fontWeight: FontWeight.w700, fontSize: 13)),
          const SizedBox(height: 10),
          ..._conseils.map((c) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 34, height: 34,
                  decoration: BoxDecoration(color: const Color(0xFF0891B2).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                  child: Icon(c.icon, color: const Color(0xFF0891B2), size: 17),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(c.t, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12)),
                      Text(c.d, style: const TextStyle(color: Colors.white38, fontSize: 11, height: 1.3)),
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
