import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../widgets/cycle_access_guard.dart';

const _kColors = [Color(0xFF374151), Color(0xFF6B7280)];

class UniversiteStagesPage extends StatelessWidget {
  const UniversiteStagesPage({super.key});

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
        title: const Text('Mon Stage', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('stages')
            .where('etudiantId', isEqualTo: uid)
            .snapshots(),
        builder: (_, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF6B7280)));
          }
          final docs = snap.data?.docs ?? [];
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              _HeaderBanner(hasStage: docs.isNotEmpty, niveau: user.niveau),
              const SizedBox(height: 16),
              if (docs.isEmpty) ...[
                _InfoCard(),
                const SizedBox(height: 16),
                _EtapesCard(),
              ] else ...[
                ...docs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return _StageCard(
                    entreprise: data['entreprise'] as String? ?? 'Entreprise',
                    poste: data['poste'] as String? ?? 'Stagiaire',
                    debut: (data['dateDebut'] as Timestamp?)?.toDate(),
                    fin: (data['dateFin'] as Timestamp?)?.toDate(),
                    statut: data['statut'] as String? ?? 'en_cours',
                    tuteur: data['tuteurNom'] as String? ?? '',
                    note: data['note'] as double?,
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
  final bool hasStage;
  final String? niveau;
  const _HeaderBanner({required this.hasStage, this.niveau});

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
                const Text('Expérience professionnelle', style: TextStyle(color: Colors.white70, fontSize: 12)),
                const Text('Stage en Entreprise', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                Text(niveau ?? 'Cycle Universitaire', style: const TextStyle(color: Colors.white60, fontSize: 12)),
              ],
            ),
          ),
          Icon(hasStage ? Icons.work_outlined : Icons.work_off_outlined, color: Colors.white24, size: 48),
        ],
      ),
    );
  }
}

class _StageCard extends StatelessWidget {
  final String entreprise, poste, statut, tuteur;
  final DateTime? debut, fin;
  final double? note;
  const _StageCard({required this.entreprise, required this.poste, required this.statut, required this.tuteur, this.debut, this.fin, this.note});

  Color get _statusColor {
    if (statut == 'termine') return const Color(0xFF16A34A);
    if (statut == 'en_cours') return const Color(0xFF2563EB);
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
        border: Border.all(color: _statusColor.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(entreprise, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: _statusColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
                child: Text(statut == 'termine' ? 'Terminé' : statut == 'en_cours' ? 'En cours' : 'Planifié',
                    style: TextStyle(color: _statusColor, fontSize: 11, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          Text(poste, style: const TextStyle(color: Colors.white60, fontSize: 13)),
          if (debut != null || fin != null) ...[
            const SizedBox(height: 8),
            Text(
              [if (debut != null) 'Début : ${_fmt(debut!)}', if (fin != null) 'Fin : ${_fmt(fin!)}'].join('  •  '),
              style: const TextStyle(color: Colors.white38, fontSize: 12),
            ),
          ],
          if (tuteur.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('Tuteur : $tuteur', style: const TextStyle(color: Colors.white38, fontSize: 12)),
          ],
          if (note != null) ...[
            const SizedBox(height: 8),
            Text('Note obtenue : ${note!.toStringAsFixed(1)} / 20',
                style: const TextStyle(color: Color(0xFF16A34A), fontWeight: FontWeight.w600, fontSize: 13)),
          ],
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: const Column(
        children: [
          Icon(Icons.work_off_outlined, color: Colors.white24, size: 48),
          SizedBox(height: 12),
          Text('Aucun stage enregistré', style: TextStyle(color: Colors.white38, fontSize: 14)),
          SizedBox(height: 6),
          Text('Votre convention de stage apparaîtra ici une fois validée par votre département.',
              style: TextStyle(color: Colors.white24, fontSize: 12), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _EtapesCard extends StatelessWidget {
  static const _etapes = [
    (step: '1', label: 'Trouver une entreprise', desc: 'Chercher un stage dans votre domaine de spécialité'),
    (step: '2', label: 'Convention de stage', desc: 'Faire signer la convention par l\'entreprise et le département'),
    (step: '3', label: 'Déroulement du stage', desc: 'Tenir un journal de bord hebdomadaire'),
    (step: '4', label: 'Rapport de stage', desc: 'Rédiger et déposer le rapport selon le modèle du département'),
    (step: '5', label: 'Soutenance', desc: 'Présenter votre travail devant un jury'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Étapes du stage', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w700, fontSize: 13)),
          const SizedBox(height: 10),
          ...List.generate(_etapes.length, (i) {
            final e = _etapes[i];
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    Container(
                      width: 26, height: 26,
                      decoration: BoxDecoration(
                        color: const Color(0xFF374151),
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFF6B7280)),
                      ),
                      child: Center(child: Text(e.step, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))),
                    ),
                    if (i < _etapes.length - 1)
                      Container(width: 1, height: 28, color: Colors.white12),
                  ],
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(e.label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12)),
                        Text(e.desc, style: const TextStyle(color: Colors.white38, fontSize: 11)),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }
}
