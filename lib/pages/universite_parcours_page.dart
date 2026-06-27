import 'package:flutter/material.dart';
import '../models/note_model.dart';
import '../models/user_model.dart';
import '../services/etudiant_service.dart';
import '../widgets/cycle_access_guard.dart';

const _kColors = [Color(0xFF0891B2), Color(0xFF15803D)];

class UniversiteParcoursPage extends StatelessWidget {
  const UniversiteParcoursPage({super.key});

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
        title: const Text('Mon Parcours', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
      ),
      body: StreamBuilder<List<NoteModel>>(
        stream: EtudiantService.notesStream(_classeNom),
        builder: (_, snap) {
          final notes = snap.data ?? [];
          final matieres = <String>{};
          for (final n in notes) { matieres.add(n.matiere); }
          final moyGen = notes.isEmpty ? 0.0 : notes.fold<double>(0, (a, n) => a + n.sur20) / notes.length;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              _ProfileCard(user: user, nbUes: matieres.length, moyGen: moyGen),
              const SizedBox(height: 20),
              _sectionLabel('Progression académique'),
              const SizedBox(height: 10),
              _ParcoursTimeline(niveauActuel: user.niveau ?? 'L1'),
              const SizedBox(height: 20),
              _sectionLabel('Compétences développées'),
              const SizedBox(height: 10),
              _CompetencesCard(matieres: matieres.toList()),
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

class _ParcoursInfo {
  final String label, code, desc;
  const _ParcoursInfo(this.label, this.code, this.desc);
}

class _ProfileCard extends StatelessWidget {
  final UserModel user;
  final int nbUes;
  final double moyGen;
  const _ProfileCard({required this.user, required this.nbUes, required this.moyGen});

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
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(color: Colors.white24, shape: BoxShape.circle),
            child: Center(
              child: Text(
                user.displayName.isNotEmpty ? user.displayName[0].toUpperCase() : '?',
                style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user.displayName.isNotEmpty ? user.displayName : 'Étudiant',
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                Text('${user.niveau ?? 'Licence'} · $nbUes UE · Moy. ${moyGen.toStringAsFixed(2)}/20',
                    style: const TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ParcoursTimeline extends StatelessWidget {
  final String niveauActuel;
  const _ParcoursTimeline({required this.niveauActuel});

  static const _niveaux = [
    _ParcoursInfo('Licence 1', 'L1', '60 ECTS'),
    _ParcoursInfo('Licence 2', 'L2', '60 ECTS'),
    _ParcoursInfo('Licence 3', 'L3', '60 ECTS'),
    _ParcoursInfo('Master 1', 'M1', '60 ECTS'),
    _ParcoursInfo('Master 2', 'M2', '60 ECTS + Mémoire'),
  ];

  bool _isCurrent(String code) => niveauActuel.toUpperCase().contains(code);
  bool _isDone(int i) {
    final codes = ['L1', 'L2', 'L3', 'M1', 'M2'];
    final curIdx = codes.indexWhere((c) => niveauActuel.toUpperCase().contains(c));
    return curIdx > i;
  }

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
        children: List.generate(_niveaux.length, (i) {
          final n = _niveaux[i];
          final current = _isCurrent(n.code);
          final done = _isDone(i);
          final color = done
              ? const Color(0xFF16A34A)
              : current
                  ? const Color(0xFF2563EB)
                  : Colors.white24;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Container(
                    width: 30, height: 30,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                      border: Border.all(color: color, width: 1.5),
                    ),
                    child: Center(
                      child: Icon(
                        done ? Icons.check : current ? Icons.radio_button_checked : Icons.circle_outlined,
                        color: color, size: 16,
                      ),
                    ),
                  ),
                  if (i < _niveaux.length - 1)
                    Container(width: 1, height: 32, color: Colors.white12),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(n.label,
                          style: TextStyle(color: current ? Colors.white : Colors.white70,
                              fontWeight: current ? FontWeight.bold : FontWeight.normal, fontSize: 13)),
                      Text(n.desc, style: const TextStyle(color: Colors.white38, fontSize: 11)),
                    ],
                  ),
                ),
              ),
              if (current)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(color: const Color(0xFF2563EB).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                  child: const Text('En cours', style: TextStyle(color: Color(0xFF2563EB), fontSize: 10, fontWeight: FontWeight.bold)),
                ),
            ],
          );
        }),
      ),
    );
  }
}

class _CompetencesCard extends StatelessWidget {
  final List<String> matieres;
  const _CompetencesCard({required this.matieres});

  @override
  Widget build(BuildContext context) {
    if (matieres.isEmpty) {
      return const Center(child: Text('Aucune UE suivie', style: TextStyle(color: Colors.white38)));
    }
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: matieres.map((m) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF0891B2).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF0891B2).withValues(alpha: 0.25)),
          ),
          child: Text(m, style: const TextStyle(color: Color(0xFF0891B2), fontSize: 12)),
        )).toList(),
      ),
    );
  }
}
