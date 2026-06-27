import 'package:flutter/material.dart';
import '../models/note_model.dart';
import '../models/user_model.dart';
import '../services/etudiant_service.dart';
import '../widgets/cycle_access_guard.dart';

const _kColors = [Color(0xFFD97706), Color(0xFFBE185D)];

class UniversiteOptionsPage extends StatelessWidget {
  const UniversiteOptionsPage({super.key});

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
        title: const Text('UE Optionnelles', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
      ),
      body: StreamBuilder<List<NoteModel>>(
        stream: EtudiantService.notesStream(_classeNom),
        builder: (_, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFFD97706)));
          }
          final notes = snap.data ?? [];
          // Options : UE dont le libellé contient "option", "libre", "transversal" ou "langue"
          final optKeywords = ['option', 'libre', 'transversal', 'langue', 'culture', 'sport'];
          final groups = <String, List<NoteModel>>{};
          for (final n in notes) { (groups[n.matiere] ??= []).add(n); }

          final options = groups.entries.where((e) =>
            optKeywords.any((k) => e.key.toLowerCase().contains(k))).toList();
          final obligatoires = groups.entries.where((e) =>
            !optKeywords.any((k) => e.key.toLowerCase().contains(k))).toList();

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              _HeaderBanner(nbOpts: options.length, nbOblig: obligatoires.length),
              const SizedBox(height: 16),
              _sectionLabel('UE Obligatoires (${obligatoires.length})'),
              const SizedBox(height: 8),
              if (obligatoires.isEmpty)
                _Empty('Aucune UE obligatoire')
              else
                ...obligatoires.asMap().entries.map((e) => _UeRow(
                  matiere: e.value.key,
                  notes: e.value.value,
                  isOption: false,
                  index: e.key,
                )),
              const SizedBox(height: 16),
              _sectionLabel('UE Optionnelles (${options.length})'),
              const SizedBox(height: 8),
              if (options.isEmpty)
                _Empty('Aucune UE optionnelle détectée')
              else
                ...options.asMap().entries.map((e) => _UeRow(
                  matiere: e.value.key,
                  notes: e.value.value,
                  isOption: true,
                  index: e.key,
                )),
              const SizedBox(height: 16),
              _InfoNote(),
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

class _HeaderBanner extends StatelessWidget {
  final int nbOpts, nbOblig;
  const _HeaderBanner({required this.nbOpts, required this.nbOblig});

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
                const Text('Inscription pédagogique', style: TextStyle(color: Colors.white70, fontSize: 12)),
                const Text('Mes UE', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                Text('$nbOblig obligatoires · $nbOpts optionnelles', style: const TextStyle(color: Colors.white60, fontSize: 12)),
              ],
            ),
          ),
          const Icon(Icons.tune_outlined, color: Colors.white24, size: 42),
        ],
      ),
    );
  }
}

class _UeRow extends StatelessWidget {
  final String matiere;
  final List<NoteModel> notes;
  final bool isOption;
  final int index;
  const _UeRow({required this.matiere, required this.notes, required this.isOption, required this.index});

  double get _avg => notes.isEmpty ? 0 : notes.fold<double>(0, (a, n) => a + n.sur20) / notes.length;
  bool get _valide => _avg >= 10;

  Color get _color => isOption ? const Color(0xFFD97706) : const Color(0xFF2563EB);
  Color get _avgColor {
    if (_avg >= 14) return const Color(0xFF16A34A);
    if (_avg >= 10) return const Color(0xFFD97706);
    return const Color(0xFFDC2626);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(color: _color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
            child: Text(isOption ? 'OPT' : 'OBL', style: TextStyle(color: _color, fontSize: 9, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(matiere, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500, fontSize: 13))),
          Text(_avg.toStringAsFixed(1), style: TextStyle(color: _avgColor, fontWeight: FontWeight.bold, fontSize: 14)),
          Text('/20', style: const TextStyle(color: Colors.white38, fontSize: 11)),
          const SizedBox(width: 8),
          Icon(_valide ? Icons.check_circle_outline : Icons.cancel_outlined,
              color: _valide ? const Color(0xFF16A34A) : const Color(0xFFDC2626), size: 16),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  final String msg;
  const _Empty(this.msg);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      alignment: Alignment.center,
      child: Text(msg, style: const TextStyle(color: Colors.white38, fontSize: 13)),
    );
  }
}

class _InfoNote extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFD97706).withValues(alpha: 0.2)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: Color(0xFFD97706), size: 16),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'La détection optionnelle/obligatoire est basée sur le libellé de l\'UE. Pour une liste officielle, consultez votre département.',
              style: TextStyle(color: Colors.white38, fontSize: 11, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
