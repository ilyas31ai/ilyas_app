import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/annonce_model.dart';
import '../models/user_model.dart';
import '../services/etudiant_service.dart';
import '../widgets/cycle_access_guard.dart';

const _kColors = [Color(0xFFD97706), Color(0xFFBE185D)];

class MaternelleCommunicationPage extends StatelessWidget {
  const MaternelleCommunicationPage({super.key});

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
        title: const Text('Communication', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          _HeaderBanner(),
          const SizedBox(height: 16),
          _sectionLabel('Messages de l\'enseignant'),
          const SizedBox(height: 10),
          _MessagesStream(uid: uid),
          const SizedBox(height: 20),
          _sectionLabel('Annonces de l\'école'),
          const SizedBox(height: 10),
          _AnnoncesStream(classeNom: user.classeNom ?? user.niveau ?? ''),
          const SizedBox(height: 20),
          _InfoCard(),
        ],
      ),
    );
  }

  static Widget _sectionLabel(String t) => Text(
    t.toUpperCase(),
    style: const TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2),
  );
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('École - Parents', style: TextStyle(color: Colors.white70, fontSize: 12)),
                Text('Communication', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                Text('Messages et annonces de l\'établissement', style: TextStyle(color: Colors.white60, fontSize: 12)),
              ],
            ),
          ),
          Icon(Icons.message_outlined, color: Colors.white24, size: 42),
        ],
      ),
    );
  }
}

class _MessagesStream extends StatelessWidget {
  final String uid;
  const _MessagesStream({required this.uid});

  @override
  Widget build(BuildContext context) {
    if (uid.isEmpty) return const SizedBox.shrink();
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('messages_parents')
          .where('eleveId', isEqualTo: uid)
          .orderBy('date', descending: true)
          .limit(10)
          .snapshots(),
      builder: (_, snap) {
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return _Empty('Aucun message de l\'enseignant');
        }
        return Column(
          children: docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return _MessageCard(
              date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
              sujet: data['sujet'] as String? ?? 'Message',
              contenu: data['contenu'] as String? ?? '',
              auteur: data['professeurNom'] as String? ?? 'Enseignant',
              lu: data['lu'] as bool? ?? false,
            );
          }).toList(),
        );
      },
    );
  }
}

class _AnnoncesStream extends StatelessWidget {
  final String classeNom;
  const _AnnoncesStream({required this.classeNom});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AnnonceModel>>(
      stream: EtudiantService.annoncesStream(),
      builder: (_, snap) {
        final annonces = snap.data ?? [];
        if (annonces.isEmpty) return _Empty('Aucune annonce');
        return Column(
          children: annonces.take(5).map((a) => _AnnonceCard(
            date: a.date,
            titre: a.titre,
            contenu: a.contenu,
          )).toList(),
        );
      },
    );
  }
}

class _Empty extends StatelessWidget {
  final String msg;
  const _Empty(this.msg);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      alignment: Alignment.center,
      child: Text(msg, style: const TextStyle(color: Colors.white38, fontSize: 13)),
    );
  }
}

class _MessageCard extends StatelessWidget {
  final DateTime date;
  final String sujet, contenu, auteur;
  final bool lu;
  const _MessageCard({required this.date, required this.sujet, required this.contenu, required this.auteur, required this.lu});

  String get _dateLabel =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: lu ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFD97706).withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34, height: 34,
                decoration: BoxDecoration(
                  color: const Color(0xFFD97706).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.mail_outline, color: Color(0xFFD97706), size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(sujet, style: TextStyle(color: Colors.white, fontWeight: lu ? FontWeight.w500 : FontWeight.w700, fontSize: 13)),
                    Text('$auteur · $_dateLabel', style: const TextStyle(color: Colors.white38, fontSize: 11)),
                  ],
                ),
              ),
              if (!lu)
                Container(
                  width: 8, height: 8,
                  decoration: const BoxDecoration(color: Color(0xFFD97706), shape: BoxShape.circle),
                ),
            ],
          ),
          if (contenu.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(contenu, style: const TextStyle(color: Colors.white60, fontSize: 12, height: 1.4)),
          ],
        ],
      ),
    );
  }
}

class _AnnonceCard extends StatelessWidget {
  final DateTime date;
  final String titre, contenu;
  const _AnnonceCard({required this.date, required this.titre, required this.contenu});

  String get _dateLabel =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.campaign_outlined, color: Color(0xFFBE185D), size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titre, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                Text(_dateLabel, style: const TextStyle(color: Colors.white38, fontSize: 11)),
                if (contenu.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(contenu, style: const TextStyle(color: Colors.white60, fontSize: 12, height: 1.4)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD97706).withValues(alpha: 0.2)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: Color(0xFFD97706), size: 18),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'La communication pédagogique est assurée exclusivement par les enseignants. Pour tout contact direct, utilisez le cahier de liaison ou contactez l\'établissement.',
              style: TextStyle(color: Colors.white54, fontSize: 12, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
