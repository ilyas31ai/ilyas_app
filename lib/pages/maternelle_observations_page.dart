import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../widgets/cycle_access_guard.dart';

const _kColors = [Color(0xFF7C3AED), Color(0xFF2563EB)];

class MaterneileObservationsPage extends StatelessWidget {
  const MaterneileObservationsPage({super.key});

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
        title: const Text('Observations', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
      ),
      body: uid.isEmpty
          ? const Center(child: Text('Non connecté', style: TextStyle(color: Colors.white38)))
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('observations')
                  .where('eleveId', isEqualTo: uid)
                  .orderBy('date', descending: true)
                  .snapshots(),
              builder: (_, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Color(0xFF7C3AED)));
                }
                final docs = snap.data?.docs ?? [];
                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                  children: [
                    _HeaderBanner(prenom: user.displayName, niveau: user.niveau),
                    const SizedBox(height: 16),
                    if (docs.isEmpty)
                      _EmptyState()
                    else
                      ...docs.map((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        return _ObservationCard(
                          date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
                          domaine: data['domaine'] as String? ?? 'Général',
                          contenu: data['contenu'] as String? ?? '',
                          auteur: data['professeurNom'] as String? ?? 'Enseignant',
                          type: data['type'] as String? ?? 'observation',
                        );
                      }),
                  ],
                );
              },
            ),
    );
  }
}

class _HeaderBanner extends StatelessWidget {
  final String prenom;
  final String? niveau;
  const _HeaderBanner({required this.prenom, this.niveau});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
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
                const Text('Carnet de suivi', style: TextStyle(color: Colors.white70, fontSize: 12)),
                Text(
                  prenom.isNotEmpty ? 'Observations de $prenom' : 'Mes Observations',
                  style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                ),
                if (niveau != null)
                  Text(niveau!, style: const TextStyle(color: Colors.white60, fontSize: 12)),
              ],
            ),
          ),
          const Icon(Icons.visibility_outlined, color: Colors.white24, size: 42),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(height: 40),
          Icon(Icons.note_alt_outlined, color: Colors.white24, size: 52),
          SizedBox(height: 12),
          Text('Aucune observation enregistrée', style: TextStyle(color: Colors.white38, fontSize: 14)),
          SizedBox(height: 6),
          Text('Les observations de l\'enseignant apparaîtront ici', style: TextStyle(color: Colors.white24, fontSize: 12)),
        ],
      ),
    );
  }
}

class _ObservationCard extends StatelessWidget {
  final DateTime date;
  final String domaine, contenu, auteur, type;
  const _ObservationCard({required this.date, required this.domaine, required this.contenu, required this.auteur, required this.type});

  Color get _typeColor {
    if (type == 'felicitation') return const Color(0xFF16A34A);
    if (type == 'alerte') return const Color(0xFFDC2626);
    return const Color(0xFF7C3AED);
  }

  IconData get _typeIcon {
    if (type == 'felicitation') return Icons.emoji_events_outlined;
    if (type == 'alerte') return Icons.warning_amber_outlined;
    return Icons.notes_outlined;
  }

  String get _dateLabel {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _typeColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34, height: 34,
                decoration: BoxDecoration(color: _typeColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
                child: Icon(_typeIcon, color: _typeColor, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(domaine, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                    Text(_dateLabel, style: const TextStyle(color: Colors.white38, fontSize: 11)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(color: _typeColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                child: Text(auteur, style: TextStyle(color: _typeColor, fontSize: 10)),
              ),
            ],
          ),
          if (contenu.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(contenu, style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4)),
          ],
        ],
      ),
    );
  }
}
