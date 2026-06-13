import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/classe_model.dart';
import '../services/professeur_service.dart';

class ProfesseurElevesPage extends StatefulWidget {
  const ProfesseurElevesPage({super.key});

  @override
  State<ProfesseurElevesPage> createState() => _ProfesseurElevesPageState();
}

class _ProfesseurElevesPageState extends State<ProfesseurElevesPage> {
  ClasseModel? _selectedClasse;
  final _nomCtrl = TextEditingController();
  final _niveauCtrl = TextEditingController();

  @override
  void dispose() {
    _nomCtrl.dispose();
    _niveauCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        elevation: 0,
        title: const Text('Gestion des élèves',
            style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Colors.white),
            tooltip: 'Créer une classe',
            onPressed: () => _showAddClasseDialog(context),
          ),
        ],
      ),
      body: StreamBuilder<List<ClasseModel>>(
        stream: ProfesseurService.classesStream(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: Color(0xFF7C3AED)));
          }
          final classes = snap.data ?? [];
          if (classes.isEmpty) return _emptyClasses(context);

          if (_selectedClasse == null ||
              !classes.any((c) => c.id == _selectedClasse!.id)) {
            WidgetsBinding.instance
                .addPostFrameCallback((_) => setState(() => _selectedClasse = classes.first));
          }

          return Column(
            children: [
              _ClasseSelector(
                classes: classes,
                selected: _selectedClasse,
                onChanged: (c) => setState(() => _selectedClasse = c),
                onDelete: (c) => _confirmDeleteClasse(context, c),
              ),
              Expanded(
                child: _selectedClasse == null
                    ? const SizedBox.shrink()
                    : _ElevesParClasse(classe: _selectedClasse!),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _emptyClasses(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.groups_outlined, color: Colors.white24, size: 56),
          const SizedBox(height: 16),
          const Text('Aucune classe créée',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          const Text('Créez votre première classe',
              style: TextStyle(color: Colors.white38, fontSize: 13)),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7C3AED),
                foregroundColor: Colors.white),
            icon: const Icon(Icons.add),
            label: const Text('Créer une classe'),
            onPressed: () => _showAddClasseDialog(context),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddClasseDialog(BuildContext context) async {
    _nomCtrl.clear();
    _niveauCtrl.clear();

    await showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF161B22),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _AddClasseSheet(
        nomCtrl: _nomCtrl,
        niveauCtrl: _niveauCtrl,
      ),
    );
  }

  Future<void> _confirmDeleteClasse(
      BuildContext context, ClasseModel classe) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161B22),
        title: const Text('Supprimer la classe',
            style: TextStyle(color: Colors.white)),
        content: Text('Supprimer « ${classe.nom} » ?',
            style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child:
                  const Text('Annuler', style: TextStyle(color: Colors.white38))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Supprimer',
                  style: TextStyle(color: Color(0xFFDC2626)))),
        ],
      ),
    );
    if (ok == true) await ProfesseurService.deleteClass(classe.id);
  }
}

// ─── Sheet création de classe ─────────────────────────────────────────────────

class _AddClasseSheet extends StatefulWidget {
  final TextEditingController nomCtrl;
  final TextEditingController niveauCtrl;
  const _AddClasseSheet(
      {required this.nomCtrl, required this.niveauCtrl});

  @override
  State<_AddClasseSheet> createState() => _AddClasseSheetState();
}

class _AddClasseSheetState extends State<_AddClasseSheet> {
  bool _saving = false;
  String? _error;

  Future<void> _creer() async {
    final nom = widget.nomCtrl.text.trim();
    final niveau = widget.niveauCtrl.text.trim();

    if (nom.isEmpty) {
      setState(() => _error = 'Le nom de la classe est obligatoire.');
      return;
    }

    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

    if (uid.isEmpty) {
      setState(() => _error = 'Erreur : utilisateur non authentifié.');
      return;
    }

    setState(() { _saving = true; _error = null; });

    try {
      await ProfesseurService.addClass(nom: nom, niveau: niveau);
      if (mounted) Navigator.pop(context);
    } catch (e, st) {
      debugPrint('[Classe] ERREUR Firestore : $e\n$st');
      setState(() {
        _saving = false;
        _error = e.toString().replaceAll('FirebaseException', 'Firestore');
      });
    }
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
          const Text('Créer une classe',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _Field(controller: widget.nomCtrl, label: 'Nom de la classe (ex: 6ème A)'),
          const SizedBox(height: 10),
          _Field(controller: widget.niveauCtrl, label: 'Niveau (ex: 6ème)'),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFDC2626).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFDC2626).withValues(alpha: 0.4)),
              ),
              child: Text(_error!,
                  style: const TextStyle(color: Color(0xFFDC2626), fontSize: 12)),
            ),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7C3AED),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14)),
              onPressed: _saving ? null : _creer,
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Créer',
                      style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Selector ─────────────────────────────────────────────────────────────────

class _ClasseSelector extends StatelessWidget {
  final List<ClasseModel> classes;
  final ClasseModel? selected;
  final void Function(ClasseModel) onChanged;
  final void Function(ClasseModel) onDelete;

  const _ClasseSelector({
    required this.classes,
    required this.selected,
    required this.onChanged,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: const Color(0xFF0D1117),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: classes
              .map((c) => _ClasseChip(
                    classe: c,
                    selected: selected?.id == c.id,
                    onTap: () => onChanged(c),
                    onDelete: () => onDelete(c),
                  ))
              .toList(),
        ),
      ),
    );
  }
}

class _ClasseChip extends StatelessWidget {
  final ClasseModel classe;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _ClasseChip({
    required this.classe,
    required this.selected,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onDelete,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          gradient: selected
              ? const LinearGradient(
                  colors: [Color(0xFF7C3AED), Color(0xFF6C47FF)])
              : null,
          color: selected ? null : const Color(0xFF161B22),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: selected
                  ? Colors.transparent
                  : Colors.white.withValues(alpha: 0.1)),
        ),
        child: Text(
          '${classe.nom} (${classe.nbEleves})',
          style: TextStyle(
            color: selected ? Colors.white : Colors.white54,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

// ─── Liste élèves ─────────────────────────────────────────────────────────────

class _ElevesParClasse extends StatelessWidget {
  final ClasseModel classe;
  const _ElevesParClasse({required this.classe});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: ProfesseurService.elevesParClasseStream(classe.nom),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: Color(0xFF7C3AED)));
        }
        final eleves = snap.data ?? [];
        if (eleves.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.person_outline, color: Colors.white24, size: 48),
                  SizedBox(height: 12),
                  Text('Aucun élève dans cette classe',
                      style: TextStyle(color: Colors.white38, fontSize: 14)),
                  SizedBox(height: 8),
                  Text('Les élèves sont créés via l\'Espace Direction',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white24, fontSize: 12)),
                ],
              ),
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          itemCount: eleves.length,
          itemBuilder: (ctx, i) => _EleveTile(
              eleve: eleves[i],
              index: i + 1,
              onTap: () => _showFiche(ctx, eleves[i])),
        );
      },
    );
  }

  void _showFiche(BuildContext context, Map<String, dynamic> eleve) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF161B22),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _FicheEleve(eleve: eleve),
    );
  }
}

class _EleveTile extends StatelessWidget {
  final Map<String, dynamic> eleve;
  final int index;
  final VoidCallback onTap;

  const _EleveTile(
      {required this.eleve, required this.index, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final nom = '${eleve['prenom'] ?? ''} ${eleve['nom'] ?? ''}'.trim();
    final matricule = eleve['matricule'] as String? ?? '';
    return InkWell(
      onTap: onTap,
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
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFF7C3AED).withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text('$index',
                    style: const TextStyle(
                        color: Color(0xFF7C3AED),
                        fontWeight: FontWeight.bold,
                        fontSize: 13)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(nom.isEmpty ? 'Élève sans nom' : nom,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14)),
                  if (matricule.isNotEmpty)
                    Text(matricule,
                        style: const TextStyle(
                            color: Colors.white38, fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white24, size: 18),
          ],
        ),
      ),
    );
  }
}

class _FicheEleve extends StatelessWidget {
  final Map<String, dynamic> eleve;
  const _FicheEleve({required this.eleve});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${eleve['prenom'] ?? ''} ${eleve['nom'] ?? ''}'.trim(),
            style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          if ((eleve['matricule'] as String?)?.isNotEmpty == true)
            _InfoRow(label: 'Matricule', value: eleve['matricule'] as String),
          _InfoRow(
              label: 'Classe',
              value: eleve['classe'] as String? ?? '—'),
          if ((eleve['dateNaissance'] as dynamic) != null)
            _InfoRow(label: 'Naissance', value: _formatDate(eleve)),
          if ((eleve['sexe'] as String?)?.isNotEmpty == true)
            _InfoRow(label: 'Sexe', value: eleve['sexe'] as String),
          if ((eleve['adresse'] as String?)?.isNotEmpty == true)
            _InfoRow(label: 'Adresse', value: eleve['adresse'] as String),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  String _formatDate(Map<String, dynamic> e) {
    final ts = e['dateNaissance'];
    if (ts == null) return '—';
    final dt = ts is DateTime ? ts : (ts as dynamic).toDate() as DateTime;
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(label,
                style:
                    const TextStyle(color: Colors.white38, fontSize: 13)),
          ),
          Expanded(
            child: Text(value,
                style:
                    const TextStyle(color: Colors.white, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  const _Field({required this.controller, required this.label});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white38),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:
              BorderSide(color: Colors.white.withValues(alpha: 0.15)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF7C3AED)),
        ),
      ),
    );
  }
}
