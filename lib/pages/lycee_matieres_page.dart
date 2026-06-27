import 'package:flutter/material.dart';
import '../models/classe_model.dart';
import '../models/note_model.dart';
import '../models/user_model.dart';
import '../services/etudiant_service.dart';
import '../widgets/cycle_access_guard.dart';

const _kColors = [Color(0xFF6C47FF), Color(0xFF2563EB)];

class LyceeMatieresPage extends StatelessWidget {
  const LyceeMatieresPage({super.key});

  @override
  Widget build(BuildContext context) {
    return CycleAccessGuard(
      cycleCategorie: 'Lycée',
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
        title: const Text('Mes Matières', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
      ),
      body: _classeNom.isEmpty
          ? const Center(child: Text('Classe non configurée', style: TextStyle(color: Colors.white38)))
          : _MatieresList(classeNom: _classeNom),
    );
  }
}

class _MatieresList extends StatelessWidget {
  final String classeNom;
  const _MatieresList({required this.classeNom});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<EmploiSlot>>(
      stream: EtudiantService.emploiStream(classeNom),
      builder: (_, emploiSnap) => StreamBuilder<List<NoteModel>>(
        stream: EtudiantService.notesStream(classeNom),
        builder: (_, notesSnap) {
          if (emploiSnap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF6C47FF)));
          }
          final slots = emploiSnap.data ?? [];
          final allNotes = notesSnap.data ?? [];

          final notesByMatiere = <String, List<NoteModel>>{};
          for (final n in allNotes) { (notesByMatiere[n.matiere] ??= []).add(n); }

          final matieresSlotsMap = <String, List<EmploiSlot>>{};
          for (final s in slots) {
            if (s.matiere.isNotEmpty) (matieresSlotsMap[s.matiere] ??= []).add(s);
          }
          for (final m in notesByMatiere.keys) {
            matieresSlotsMap.putIfAbsent(m, () => []);
          }

          if (matieresSlotsMap.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.book_outlined, color: Colors.white24, size: 48),
                  SizedBox(height: 12),
                  Text('Emploi du temps non configuré', style: TextStyle(color: Colors.white38)),
                ],
              ),
            );
          }

          final matieres = matieresSlotsMap.keys.toList()..sort();
          final matieresMoyennes = <String, double>{};
          for (final m in matieres) {
            final notes = notesByMatiere[m] ?? [];
            if (notes.isNotEmpty) {
              matieresMoyennes[m] = notes.fold<double>(0, (s, n) => s + n.sur20) / notes.length;
            }
          }

          final moyGen = matieresMoyennes.isEmpty
              ? null
              : matieresMoyennes.values.fold<double>(0, (s, v) => s + v) / matieresMoyennes.length;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              if (moyGen != null) _MoyenneGenerale(moyenne: moyGen, nbMatieres: matieres.length),
              if (moyGen != null) const SizedBox(height: 16),
              ...matieres.asMap().entries.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _MatiereCard(
                  matiere: e.value,
                  slots: matieresSlotsMap[e.value] ?? [],
                  notes: notesByMatiere[e.value] ?? [],
                  moyenne: matieresMoyennes[e.value],
                  color: _kMatColors[e.key % _kMatColors.length],
                ),
              )),
            ],
          );
        },
      ),
    );
  }

  static const _kMatColors = [
    Color(0xFF6C47FF), Color(0xFF2563EB), Color(0xFF0F766E),
    Color(0xFFDC2626), Color(0xFFD97706), Color(0xFFBE185D),
    Color(0xFF7C3AED), Color(0xFF0891B2),
  ];
}

// ── Bannière moyenne générale ─────────────────────────────────────────────────

class _MoyenneGenerale extends StatelessWidget {
  final double moyenne;
  final int nbMatieres;
  const _MoyenneGenerale({required this.moyenne, required this.nbMatieres});

  Color get _color => moyenne >= 14 ? Colors.green : moyenne >= 10 ? Colors.amber : Colors.red;

  String get _appreciation {
    if (moyenne >= 18) return 'Excellent';
    if (moyenne >= 15) return 'Très bien';
    if (moyenne >= 12) return 'Bien';
    if (moyenne >= 10) return 'Assez bien';
    if (moyenne >= 7) return 'Insuffisant';
    return 'Très faible';
  }

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
                const Text('Moyenne générale', style: TextStyle(color: Colors.white70, fontSize: 12)),
                const SizedBox(height: 4),
                Text('${moyenne.toStringAsFixed(2)} / 20',
                    style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                Text('$nbMatieres matière${nbMatieres > 1 ? 's' : ''}',
                    style: const TextStyle(color: Colors.white60, fontSize: 11)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(color: _color.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(10)),
            child: Text(_appreciation, style: TextStyle(color: _color, fontWeight: FontWeight.bold, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

// ── Carte matière ─────────────────────────────────────────────────────────────

class _MatiereCard extends StatelessWidget {
  final String matiere;
  final List<EmploiSlot> slots;
  final List<NoteModel> notes;
  final double? moyenne;
  final Color color;
  const _MatiereCard({
    required this.matiere,
    required this.slots,
    required this.notes,
    required this.moyenne,
    required this.color,
  });

  String get _joursLabel {
    if (slots.isEmpty) return '';
    final jours = slots.map((s) => s.jourLabel).toSet().toList()..sort();
    return jours.join(', ');
  }

  String get _heuresLabel {
    if (slots.isEmpty) return '';
    final s = slots.first;
    return '${s.heureDebut} – ${s.heureFin}';
  }

  Color get _moyColor =>
      moyenne == null ? Colors.white38 : moyenne! >= 14 ? Colors.green : moyenne! >= 10 ? Colors.amber : Colors.red;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _showNotes(context),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF161B22),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Container(
              width: 42, height: 42,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
              child: Icon(Icons.book_outlined, color: color, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(matiere, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
                  if (_joursLabel.isNotEmpty)
                    Text(_joursLabel, style: const TextStyle(color: Colors.white38, fontSize: 12)),
                  if (_heuresLabel.isNotEmpty)
                    Text(_heuresLabel, style: const TextStyle(color: Colors.white38, fontSize: 11)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (moyenne != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: _moyColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                    child: Text('${moyenne!.toStringAsFixed(1)}/20',
                        style: TextStyle(color: _moyColor, fontWeight: FontWeight.bold, fontSize: 12)),
                  )
                else
                  Text('${notes.length} note${notes.length > 1 ? 's' : ''}',
                      style: const TextStyle(color: Colors.white38, fontSize: 11)),
                if (slots.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('${slots.length}×/sem', style: const TextStyle(color: Colors.white24, fontSize: 10)),
                  ),
              ],
            ),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right, color: Colors.white24, size: 18),
          ],
        ),
      ),
    );
  }

  void _showNotes(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF161B22),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      isScrollControlled: true,
      builder: (_) => _MatiereNotesSheet(matiere: matiere, notes: notes, color: color),
    );
  }
}

// ── Feuille détail notes ──────────────────────────────────────────────────────

class _MatiereNotesSheet extends StatelessWidget {
  final String matiere;
  final List<NoteModel> notes;
  final Color color;
  const _MatiereNotesSheet({required this.matiere, required this.notes, required this.color});

  @override
  Widget build(BuildContext context) {
    final double moy = notes.isEmpty ? 0 : notes.fold<double>(0, (s, n) => s + n.sur20) / notes.length;
    final Color moyColor = moy >= 14 ? Colors.green : moy >= 10 ? Colors.amber : Colors.red;

    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      maxChildSize: 0.9,
      minChildSize: 0.3,
      expand: false,
      builder: (_, controller) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              children: [
                Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
                  child: Icon(Icons.book_outlined, color: color, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(matiere, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                      Text('${notes.length} note${notes.length > 1 ? 's' : ''}', style: const TextStyle(color: Colors.white38, fontSize: 12)),
                    ],
                  ),
                ),
                if (notes.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(color: moyColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
                    child: Text('${moy.toStringAsFixed(2)}/20', style: TextStyle(color: moyColor, fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
              ],
            ),
          ),
          const Divider(color: Colors.white10, height: 1),
          Expanded(
            child: notes.isEmpty
                ? const Center(child: Text('Aucune note pour cette matière', style: TextStyle(color: Colors.white38)))
                : ListView.separated(
                    controller: controller,
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 32),
                    itemCount: notes.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final n = notes[i];
                      final nc = n.sur20 >= 14 ? Colors.green : n.sur20 >= 10 ? Colors.amber : Colors.red;
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(color: const Color(0xFF0D1117), borderRadius: BorderRadius.circular(10)),
                        child: Row(
                          children: [
                            Container(
                              width: 46,
                              alignment: Alignment.center,
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              decoration: BoxDecoration(color: nc.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
                              child: Text(n.sur20.toStringAsFixed(1), style: TextStyle(color: nc, fontWeight: FontWeight.bold, fontSize: 14)),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(n.intitule.isNotEmpty ? n.intitule : 'Note',
                                      style: const TextStyle(color: Colors.white, fontSize: 13),
                                      maxLines: 1, overflow: TextOverflow.ellipsis),
                                  Text('${n.date.day}/${n.date.month}/${n.date.year}',
                                      style: const TextStyle(color: Colors.white38, fontSize: 11)),
                                ],
                              ),
                            ),
                            Text('/${n.bareme.toInt()}', style: const TextStyle(color: Colors.white38, fontSize: 11)),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
