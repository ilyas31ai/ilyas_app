import 'package:flutter/material.dart';
import '../models/note_model.dart';
import '../models/user_model.dart';
import '../services/etudiant_service.dart';
import '../widgets/cycle_access_guard.dart';

const _kColors = [Color(0xFFBE185D), Color(0xFFDC2626)];

class UniversiteRattrapagesPage extends StatelessWidget {
  const UniversiteRattrapagesPage({super.key});

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

  String get _classeNom => user.classeNom ?? user.niveau ?? '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        elevation: 0,
        title: const Text('Rattrapages', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
      ),
      body: StreamBuilder<List<NoteModel>>(
        stream: EtudiantService.notesStream(_classeNom),
        builder: (_, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFFBE185D)));
          }
          final notes = snap.data ?? [];
          // Grouper par matière
          final groups = <String, List<NoteModel>>{};
          for (final n in notes) { (groups[n.matiere] ??= []).add(n); }

          // UEs en échec (moy < 10) → rattrapage
          final enEchec = groups.entries.where((e) {
            final avg = e.value.fold<double>(0, (a, n) => a + n.sur20) / e.value.length;
            return avg < 10;
          }).toList()..sort((a, b) => a.key.compareTo(b.key));

          final validated = groups.entries.length - enEchec.length;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              _StatusBanner(enEchec: enEchec.length, valides: validated, total: groups.length),
              const SizedBox(height: 16),
              if (enEchec.isEmpty)
                _NoRattrapage()
              else ...[
                _sectionLabel('UE en rattrapage (${enEchec.length})'),
                const SizedBox(height: 10),
                ...enEchec.map((e) {
                  final avg = e.value.fold<double>(0, (a, n) => a + n.sur20) / e.value.length;
                  return _RattrapageCard(matiere: e.key, moyenne: avg, notes: e.value);
                }),
                const SizedBox(height: 16),
                _ConseilsRattrapage(),
              ],
            ],
          );
        },
      ),
    );
  }

  static Widget _sectionLabel(String t) => Text(
    t.toUpperCase(),
    style: const TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2),
  );
}

class _StatusBanner extends StatelessWidget {
  final int enEchec, valides, total;
  const _StatusBanner({required this.enEchec, required this.valides, required this.total});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: _kColors, begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Situation académique', style: TextStyle(color: Colors.white70, fontSize: 12)),
              Text('$enEchec UE en échec', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _Chip('Validées', valides, const Color(0xFF16A34A)),
              const SizedBox(width: 8),
              _Chip('En échec', enEchec, Colors.white),
              const SizedBox(width: 8),
              _Chip('Total UE', total, Colors.white60),
            ],
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  const _Chip(this.label, this.count, this.color);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(8)),
        child: Column(
          children: [
            Text('$count', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)),
            Text(label, style: const TextStyle(color: Colors.white60, fontSize: 10)),
          ],
        ),
      ),
    );
  }
}

class _NoRattrapage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF16A34A).withValues(alpha: 0.2)),
      ),
      child: const Column(
        children: [
          Icon(Icons.emoji_events_outlined, color: Color(0xFF16A34A), size: 48),
          SizedBox(height: 12),
          Text('Aucun rattrapage !', style: TextStyle(color: Color(0xFF16A34A), fontWeight: FontWeight.bold, fontSize: 16)),
          SizedBox(height: 6),
          Text('Toutes vos UE sont validées', style: TextStyle(color: Colors.white38, fontSize: 13)),
        ],
      ),
    );
  }
}

class _RattrapageCard extends StatelessWidget {
  final String matiere;
  final double moyenne;
  final List<NoteModel> notes;
  const _RattrapageCard({required this.matiere, required this.moyenne, required this.notes});

  double get _ecart => 10.0 - moyenne;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFDC2626).withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38, height: 38,
                decoration: BoxDecoration(color: const Color(0xFFDC2626).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(9)),
                child: const Icon(Icons.refresh_outlined, color: Color(0xFFDC2626), size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(matiere, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                    Text('Manque ${_ecart.toStringAsFixed(1)} pts pour valider',
                        style: const TextStyle(color: Color(0xFFDC2626), fontSize: 11)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(moyenne.toStringAsFixed(1),
                      style: const TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.bold, fontSize: 18)),
                  const Text('/20', style: TextStyle(color: Colors.white38, fontSize: 11)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (moyenne / 10).clamp(0.0, 1.0),
              backgroundColor: const Color(0xFFDC2626).withValues(alpha: 0.15),
              color: const Color(0xFFDC2626),
              minHeight: 5,
            ),
          ),
        ],
      ),
    );
  }
}

class _ConseilsRattrapage extends StatelessWidget {
  static const _conseils = [
    'Concentrez-vous sur les UE avec le plus grand écart au 10',
    'Demandez des annales à votre département',
    'Consultez votre enseignant pour les points clés',
    'Formez un groupe de révision avec vos camarades',
    'La session de rattrapage se tient généralement en septembre',
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
          const Text('Conseils pour le rattrapage',
              style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w700, fontSize: 13)),
          const SizedBox(height: 10),
          ..._conseils.map((c) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.lightbulb_outline, color: Color(0xFFD97706), size: 15),
                const SizedBox(width: 8),
                Expanded(child: Text(c, style: const TextStyle(color: Colors.white54, fontSize: 12, height: 1.4))),
              ],
            ),
          )),
        ],
      ),
    );
  }
}
