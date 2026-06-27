import 'package:flutter/material.dart';
import '../models/note_model.dart';
import '../models/user_model.dart';
import '../services/etudiant_service.dart';
import '../widgets/cycle_access_guard.dart';

const _kColors = [Color(0xFF16A34A), Color(0xFF0891B2)];
const _kEctsParUe = 3;
const _kEctsObjectif = 180; // Licence = 180 ECTS

class UniversiteEctsPage extends StatelessWidget {
  const UniversiteEctsPage({super.key});

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
        title: const Text('Crédits ECTS', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
      ),
      body: StreamBuilder<List<NoteModel>>(
        stream: EtudiantService.notesStream(_classeNom),
        builder: (_, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF16A34A)));
          }
          final notes = snap.data ?? [];
          final matieres = <String>{};
          for (final n in notes) { matieres.add(n.matiere); }

          // UEs validées = matières dont la moyenne >= 10/20
          final moyParMatiere = <String, double>{};
          for (final m in matieres) {
            final ns = notes.where((n) => n.matiere == m).toList();
            moyParMatiere[m] = ns.fold<double>(0, (a, n) => a + n.sur20) / ns.length;
          }
          final validees = moyParMatiere.entries.where((e) => e.value >= 10).length;
          final ectsObtenus = validees * _kEctsParUe;
          final ectsTotaux = matieres.length * _kEctsParUe;
          final pct = _kEctsObjectif > 0 ? (ectsObtenus / _kEctsObjectif).clamp(0.0, 1.0) : 0.0;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              _EctsProgressCard(ectsObtenus: ectsObtenus, ectsTotaux: ectsTotaux, pct: pct, niveau: user.niveau),
              const SizedBox(height: 16),
              _SemestresCard(matieres: matieres.length, validees: validees),
              const SizedBox(height: 20),
              _sectionLabel('Détail par UE'),
              const SizedBox(height: 10),
              if (moyParMatiere.isEmpty)
                const Center(child: Padding(
                  padding: EdgeInsets.only(top: 20),
                  child: Text('Aucune UE enregistrée', style: TextStyle(color: Colors.white38)),
                ))
              else
                ...(moyParMatiere.entries.toList()..sort((a, b) => a.key.compareTo(b.key)))
                    .asMap()
                    .entries
                    .map((e) => _UeEctsRow(nom: e.value.key, moyenne: e.value.value, index: e.key)),
              const SizedBox(height: 20),
              _ObjectifCard(),
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

class _EctsProgressCard extends StatelessWidget {
  final int ectsObtenus, ectsTotaux;
  final double pct;
  final String? niveau;
  const _EctsProgressCard({required this.ectsObtenus, required this.ectsTotaux, required this.pct, this.niveau});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: _kColors, begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('ECTS obtenus · ${niveau ?? ''}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                    Text('$ectsObtenus / $_kEctsObjectif ECTS',
                        style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              const Icon(Icons.stars_outlined, color: Colors.white24, size: 40),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              backgroundColor: Colors.black26,
              color: Colors.white,
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 6),
          Text('${(pct * 100).toStringAsFixed(0)} % vers la Licence (180 ECTS)',
              style: const TextStyle(color: Colors.white70, fontSize: 11)),
        ],
      ),
    );
  }
}

class _SemestresCard extends StatelessWidget {
  final int matieres, validees;
  const _SemestresCard({required this.matieres, required this.validees});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _Stat('UE inscrites', '$matieres', const Color(0xFF2563EB))),
        const SizedBox(width: 10),
        Expanded(child: _Stat('UE validées', '$validees', const Color(0xFF16A34A))),
        const SizedBox(width: 10),
        Expanded(child: _Stat('En échec', '${matieres - validees}', const Color(0xFFDC2626))),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  final String label, value;
  final Color color;
  const _Stat(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          Text(value, style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: Colors.white38, fontSize: 11), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _UeEctsRow extends StatelessWidget {
  final String nom;
  final double moyenne;
  final int index;
  const _UeEctsRow({required this.nom, required this.moyenne, required this.index});

  static const _palette = [
    Color(0xFF2563EB), Color(0xFF0891B2), Color(0xFF7C3AED),
    Color(0xFF15803D), Color(0xFFD97706), Color(0xFFDC2626),
  ];

  bool get _valide => moyenne >= 10;
  Color get _color => _palette[index % _palette.length];

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          Container(
            width: 8, height: 8,
            decoration: BoxDecoration(color: _color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(nom, style: const TextStyle(color: Colors.white, fontSize: 13))),
          Text('${moyenne.toStringAsFixed(1)}/20',
              style: TextStyle(color: _valide ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                  fontWeight: FontWeight.w600, fontSize: 12)),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: (_valide ? const Color(0xFF16A34A) : const Color(0xFFDC2626)).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text('$_kEctsParUe ECTS',
                style: TextStyle(color: _valide ? const Color(0xFF16A34A) : const Color(0xFFDC2626), fontSize: 10)),
          ),
        ],
      ),
    );
  }
}

class _ObjectifCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF16A34A).withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text('Objectifs ECTS', style: TextStyle(color: Color(0xFF16A34A), fontWeight: FontWeight.w700, fontSize: 13)),
          SizedBox(height: 8),
          _ObjRow('Licence (L3)', '180 ECTS'),
          _ObjRow('Master (M2)', '120 ECTS supplémentaires'),
          _ObjRow('Doctorat', 'Après 300 ECTS + thèse'),
        ],
      ),
    );
  }
}

class _ObjRow extends StatelessWidget {
  final String label, value;
  const _ObjRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.arrow_right, color: Color(0xFF0891B2), size: 16),
          const SizedBox(width: 6),
          Expanded(child: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12))),
          Text(value, style: const TextStyle(color: Colors.white38, fontSize: 12)),
        ],
      ),
    );
  }
}
