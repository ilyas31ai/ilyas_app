import 'dart:async';

import 'package:flutter/material.dart';

import '../models/classe_model.dart';
import '../models/note_model.dart';
import '../services/professeur_service.dart';

class ProfesseurNotesPage extends StatefulWidget {
  const ProfesseurNotesPage({super.key});

  @override
  State<ProfesseurNotesPage> createState() => _ProfesseurNotesPageState();
}

class _ProfesseurNotesPageState extends State<ProfesseurNotesPage> {
  ClasseModel? _classe;
  String _matiere = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        elevation: 0,
        title: const Text('Notes',
            style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold)),
      ),
      body: StreamBuilder<List<ClasseModel>>(
        stream: ProfesseurService.classesStream(),
        builder: (context, snap) {
          final classes = snap.data ?? [];
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: Color(0xFFD97706)));
          }
          if (classes.isEmpty) {
            return _emptyClasses();
          }
          if (_classe == null) {
            WidgetsBinding.instance.addPostFrameCallback(
                (_) => setState(() => _classe = classes.first));
          }
          return Column(
            children: [
              _FilterBar(
                classes: classes,
                selectedClasse: _classe,
                matiere: _matiere,
                onClasseChanged: (c) => setState(() => _classe = c),
                onMatiereChanged: (m) => setState(() => _matiere = m),
              ),
              Expanded(
                child: _classe == null
                    ? const SizedBox.shrink()
                    : _NotesContent(
                        classe: _classe!,
                        matiere: _matiere,
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _emptyClasses() => const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'Créez d\'abord une classe\ndans la Gestion des élèves.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white38, fontSize: 14),
          ),
        ),
      );
}

// ─── Filtre classe + matière ──────────────────────────────────────────────────

class _FilterBar extends StatelessWidget {
  final List<ClasseModel> classes;
  final ClasseModel? selectedClasse;
  final String matiere;
  final void Function(ClasseModel) onClasseChanged;
  final void Function(String) onMatiereChanged;

  const _FilterBar({
    required this.classes,
    required this.selectedClasse,
    required this.matiere,
    required this.onClasseChanged,
    required this.onMatiereChanged,
  });

  @override
  Widget build(BuildContext context) {
    final matieres = ['', 'Maths', 'Français', 'Anglais', 'Histoire', 'Sciences', 'Physique'];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: const Color(0xFF161B22),
      child: Row(
        children: [
          Expanded(
            child: DropdownButton<ClasseModel>(
              value: selectedClasse,
              dropdownColor: const Color(0xFF161B22),
              style: const TextStyle(color: Colors.white, fontSize: 13),
              underline: const SizedBox.shrink(),
              isExpanded: true,
              items: classes
                  .map((c) => DropdownMenuItem(
                      value: c,
                      child: Text(c.nom,
                          style: const TextStyle(color: Colors.white))))
                  .toList(),
              onChanged: (c) { if (c != null) onClasseChanged(c); },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButton<String>(
              value: matieres.contains(matiere) ? matiere : '',
              dropdownColor: const Color(0xFF161B22),
              style: const TextStyle(color: Colors.white, fontSize: 13),
              underline: const SizedBox.shrink(),
              isExpanded: true,
              items: matieres
                  .map((m) => DropdownMenuItem(
                      value: m,
                      child: Text(m.isEmpty ? 'Toutes matières' : m,
                          style: const TextStyle(color: Colors.white))))
                  .toList(),
              onChanged: (m) => onMatiereChanged(m ?? ''),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Contenu notes ────────────────────────────────────────────────────────────

class _NotesContent extends StatelessWidget {
  final ClasseModel classe;
  final String matiere;

  const _NotesContent({required this.classe, required this.matiere});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<NoteModel>>(
      stream: ProfesseurService.notesStream(classe.id, matiere),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: Color(0xFFD97706)));
        }
        final notes = snap.data ?? [];

        // Calcul de la moyenne par classe/matière
        double? moyenne;
        if (notes.isNotEmpty) {
          final sum = notes.fold(0.0, (s, n) => s + n.sur20);
          moyenne = sum / notes.length;
        }

        return Column(
          children: [
            if (moyenne != null) _MoyenneBar(moyenne: moyenne),
            Expanded(
              child: notes.isEmpty
                  ? _emptyNotes(context)
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                      itemCount: notes.length,
                      itemBuilder: (ctx, i) => _NoteTile(
                            note: notes[i],
                            onEdit: () => _showEditDialog(ctx, notes[i]),
                            onDelete: () =>
                                ProfesseurService.deleteNote(notes[i].id),
                          ),
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _emptyNotes(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.grade_outlined, color: Colors.white24, size: 48),
          const SizedBox(height: 12),
          const Text('Aucune note saisie',
              style: TextStyle(color: Colors.white38, fontSize: 14)),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD97706),
                foregroundColor: Colors.white),
            icon: const Icon(Icons.add),
            label: const Text('Ajouter une note'),
            onPressed: () => _showAddDialog(context),
          ),
        ],
      ),
    );
  }

  void _showAddDialog(BuildContext context) =>
      _NoteDialog.show(context, classeId: classe.id, classeNom: classe.nom, matiereDefault: matiere);

  void _showEditDialog(BuildContext context, NoteModel note) =>
      _NoteDialog.show(context, classeId: classe.id, classeNom: classe.nom, matiereDefault: matiere, existing: note);
}

// ─── Moyenne ──────────────────────────────────────────────────────────────────

class _MoyenneBar extends StatelessWidget {
  final double moyenne;
  const _MoyenneBar({required this.moyenne});

  @override
  Widget build(BuildContext context) {
    final color = moyenne >= 10
        ? const Color(0xFF15803D)
        : const Color(0xFFDC2626);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: const Color(0xFF161B22),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('Moyenne de la classe',
              style: TextStyle(color: Colors.white70, fontSize: 13)),
          Text(
            '${moyenne.toStringAsFixed(2)} / 20',
            style: TextStyle(
                color: color, fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ],
      ),
    );
  }
}

// ─── Note Tile ────────────────────────────────────────────────────────────────

class _NoteTile extends StatelessWidget {
  final NoteModel note;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _NoteTile(
      {required this.note, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final color = note.sur20 >= 10
        ? const Color(0xFF15803D)
        : const Color(0xFFDC2626);
    return Dismissible(
      key: Key(note.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        decoration: BoxDecoration(
          color: const Color(0xFFDC2626).withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete_outline, color: Color(0xFFDC2626)),
      ),
      onDismissed: (_) => onDelete(),
      child: InkWell(
        onTap: onEdit,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF161B22),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    note.sur20.toStringAsFixed(1),
                    style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.bold,
                        fontSize: 14),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(note.eleveNomComplet,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 14)),
                    Text(
                      '${note.intitule} · ${note.matiere} · ${note.note}/${note.bareme.toInt()}',
                      style: const TextStyle(
                          color: Colors.white38, fontSize: 12),
                    ),
                  ],
                ),
              ),
              if (note.publie)
                const Icon(Icons.visibility_outlined,
                    color: Color(0xFF15803D), size: 16),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Dialog ajout / modification note ────────────────────────────────────────

class _NoteDialog {
  static void show(
    BuildContext context, {
    required String classeId,
    required String classeNom,
    required String matiereDefault,
    NoteModel? existing,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF161B22),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _NoteForm(
        classeId: classeId,
        classeNom: classeNom,
        matiereDefault: matiereDefault,
        existing: existing,
      ),
    );
  }
}

class _NoteForm extends StatefulWidget {
  final String classeId;
  final String classeNom;
  final String matiereDefault;
  final NoteModel? existing;

  const _NoteForm({
    required this.classeId,
    required this.classeNom,
    required this.matiereDefault,
    this.existing,
  });

  @override
  State<_NoteForm> createState() => _NoteFormState();
}

class _NoteFormState extends State<_NoteForm> {
  late final TextEditingController _eleveNom;
  late final TextEditingController _elevePrenom;
  late final TextEditingController _intitule;
  late final TextEditingController _note;
  late final TextEditingController _bareme;
  late final TextEditingController _matiere;
  bool _saving = false;
  String? _eleveUid;
  List<Map<String, dynamic>> _eleves = [];
  StreamSubscription? _elevesSub;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _eleveNom = TextEditingController(text: e?.eleveNom ?? '');
    _elevePrenom = TextEditingController(text: e?.elevePrenom ?? '');
    _intitule = TextEditingController(text: e?.intitule ?? '');
    _note = TextEditingController(
        text: e != null ? e.note.toString() : '');
    _bareme = TextEditingController(
        text: e != null ? e.bareme.toInt().toString() : '20');
    _matiere = TextEditingController(
        text: e?.matiere ?? widget.matiereDefault);
    if (widget.existing == null && widget.classeNom.isNotEmpty) {
      _elevesSub = ProfesseurService.elevesParClasseStream(widget.classeNom)
          .listen((list) { if (mounted) setState(() => _eleves = list); });
    }
  }

  @override
  void dispose() {
    _elevesSub?.cancel();
    for (final c in [_eleveNom, _elevePrenom, _intitule, _note, _bareme, _matiere]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          left: 20,
          right: 20,
          top: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.existing != null ? 'Modifier la note' : 'Ajouter une note',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          if (widget.existing == null && _eleves.isNotEmpty) ...[
            DropdownButtonFormField<String>(
              decoration: InputDecoration(
                labelText: 'Sélectionner un élève',
                labelStyle: const TextStyle(color: Color(0xFFD97706)),
                enabledBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: Color(0xFFD97706)),
                  borderRadius: BorderRadius.circular(8),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: Color(0xFFD97706), width: 2),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              dropdownColor: const Color(0xFF1C2128),
              style: const TextStyle(color: Colors.white),
              initialValue: null,
              items: _eleves.map((e) {
                final label = '${e['prenom'] ?? ''} ${e['nom'] ?? ''}'.trim();
                return DropdownMenuItem<String>(
                  value: e['id'] as String? ?? '',
                  child: Text(label),
                );
              }).toList(),
              onChanged: (eleveDocId) {
                if (eleveDocId == null) return;
                final e = _eleves.firstWhere(
                  (el) => (el['id'] as String?) == eleveDocId,
                  orElse: () => {},
                );
                setState(() {
                  _eleveUid = e['authUid'] as String? ?? '';
                  _eleveNom.text = e['nom'] as String? ?? '';
                  _elevePrenom.text = e['prenom'] as String? ?? '';
                });
              },
            ),
            const SizedBox(height: 10),
          ],
          Row(
            children: [
              Expanded(child: _Field(controller: _elevePrenom, label: 'Prénom', color: const Color(0xFFD97706))),
              const SizedBox(width: 10),
              Expanded(child: _Field(controller: _eleveNom, label: 'Nom', color: const Color(0xFFD97706))),
            ],
          ),
          const SizedBox(height: 10),
          _Field(controller: _intitule, label: 'Intitulé (ex: Contrôle n°1)', color: const Color(0xFFD97706)),
          const SizedBox(height: 10),
          _Field(controller: _matiere, label: 'Matière', color: const Color(0xFFD97706)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _Field(controller: _note, label: 'Note obtenue', color: const Color(0xFFD97706), keyboardType: TextInputType.number)),
              const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text('/', style: TextStyle(color: Colors.white38, fontSize: 20))),
              Expanded(child: _Field(controller: _bareme, label: 'Barème', color: const Color(0xFFD97706), keyboardType: TextInputType.number)),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD97706),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14)),
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Enregistrer', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final noteVal = double.tryParse(_note.text.trim()) ?? 0;
    final baremeVal = double.tryParse(_bareme.text.trim()) ?? 20;
    if (_eleveNom.text.trim().isEmpty && _elevePrenom.text.trim().isEmpty) return;

    setState(() => _saving = true);
    try {
      if (widget.existing != null) {
        await ProfesseurService.updateNote(widget.existing!.id,
            note: noteVal, intitule: _intitule.text.trim());
      } else {
        await ProfesseurService.addNote(
          eleveId: _eleveUid ?? '',
          eleveUid: _eleveUid ?? '',
          eleveNom: _eleveNom.text.trim(),
          elevePrenom: _elevePrenom.text.trim(),
          classeId: widget.classeId,
          classeNom: widget.classeNom,
          matiere: _matiere.text.trim(),
          note: noteVal,
          bareme: baremeVal,
          intitule: _intitule.text.trim(),
        );
      }
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final Color color;
  final TextInputType? keyboardType;

  const _Field({
    required this.controller,
    required this.label,
    required this.color,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white38),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: color),
        ),
      ),
    );
  }
}
