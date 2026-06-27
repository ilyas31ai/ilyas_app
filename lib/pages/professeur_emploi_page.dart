import 'package:flutter/material.dart';

import '../models/classe_model.dart';
import '../services/professeur_service.dart';

class ProfesseurEmploiPage extends StatefulWidget {
  const ProfesseurEmploiPage({super.key});

  @override
  State<ProfesseurEmploiPage> createState() => _ProfesseurEmploiPageState();
}

class _ProfesseurEmploiPageState extends State<ProfesseurEmploiPage> {
  static const _jours = ['Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        elevation: 0,
        title: const Text('Emploi du temps',
            style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Colors.white),
            onPressed: () => _showAddSlotDialog(context),
          ),
        ],
      ),
      body: StreamBuilder<List<EmploiSlot>>(
        stream: ProfesseurService.emploiStream(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: Color(0xFF0F766E)));
          }
          final slots = snap.data ?? [];
          if (slots.isEmpty) {
            return _emptyState(context);
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: List.generate(5, (i) {
              final jourNum = i + 1;
              final jourSlots =
                  slots.where((s) => s.jour == jourNum).toList();
              if (jourSlots.isEmpty) return const SizedBox.shrink();
              return _JourSection(
                  jour: _jours[i],
                  slots: jourSlots,
                  onDelete: (id) => ProfesseurService.deleteSlot(id));
            }),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF0F766E),
        onPressed: () => _showAddSlotDialog(context),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _emptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.calendar_month_outlined,
              color: Colors.white24, size: 56),
          const SizedBox(height: 16),
          const Text('Aucun cours planifié',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          const Text('Ajoutez vos créneaux hebdomadaires',
              style: TextStyle(color: Colors.white38, fontSize: 13)),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F766E),
                foregroundColor: Colors.white),
            icon: const Icon(Icons.add),
            label: const Text('Ajouter un créneau'),
            onPressed: () => _showAddSlotDialog(context),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddSlotDialog(BuildContext context) async {
    int selectedJour = 1;
    final matiereCtrl = TextEditingController();
    final classeCtrl = TextEditingController();
    final salleCtrl = TextEditingController();
    TimeOfDay debut = const TimeOfDay(hour: 8, minute: 0);
    TimeOfDay fin = const TimeOfDay(hour: 9, minute: 0);

    final classes = await ProfesseurService.classesStream().first;
    if (!context.mounted) return;
    ClasseModel? selectedClasse;

    await showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF161B22),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
              left: 20,
              right: 20,
              top: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Nouveau créneau',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              // Jour
              DropdownButtonFormField<int>(
                value: selectedJour,
                dropdownColor: const Color(0xFF161B22),
                style: const TextStyle(color: Colors.white),
                decoration: _inputDeco('Jour'),
                items: List.generate(
                  5,
                  (i) => DropdownMenuItem(
                      value: i + 1,
                      child: Text(EmploiSlot.joursLabels[i])),
                ),
                onChanged: (v) => setModal(() => selectedJour = v ?? 1),
              ),
              const SizedBox(height: 10),
              // Horaires
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () async {
                        final t = await showTimePicker(
                            context: ctx, initialTime: debut);
                        if (t != null) setModal(() => debut = t);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 14),
                        decoration: BoxDecoration(
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.15)),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(children: [
                          const Icon(Icons.access_time,
                              color: Colors.white38, size: 16),
                          const SizedBox(width: 8),
                          Text(debut.format(ctx),
                              style: const TextStyle(color: Colors.white)),
                        ]),
                      ),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Text('–', style: TextStyle(color: Colors.white38)),
                  ),
                  Expanded(
                    child: InkWell(
                      onTap: () async {
                        final t = await showTimePicker(
                            context: ctx, initialTime: fin);
                        if (t != null) setModal(() => fin = t);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 14),
                        decoration: BoxDecoration(
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.15)),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(children: [
                          const Icon(Icons.access_time,
                              color: Colors.white38, size: 16),
                          const SizedBox(width: 8),
                          Text(fin.format(ctx),
                              style: const TextStyle(color: Colors.white)),
                        ]),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _Field(controller: matiereCtrl, label: 'Matière'),
              const SizedBox(height: 10),
              if (classes.isNotEmpty)
                DropdownButtonFormField<ClasseModel>(
                  value: selectedClasse,
                  dropdownColor: const Color(0xFF161B22),
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputDeco('Classe'),
                  items: classes
                      .map((c) => DropdownMenuItem(
                          value: c,
                          child: Text(c.nom,
                              style: const TextStyle(color: Colors.white))))
                      .toList(),
                  onChanged: (c) => setModal(() => selectedClasse = c),
                )
              else
                _Field(controller: classeCtrl, label: 'Classe (ex: 6ème A)'),
              const SizedBox(height: 10),
              _Field(controller: salleCtrl, label: 'Salle (optionnel)'),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F766E),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14)),
                  onPressed: () async {
                    final classeNom = selectedClasse?.nom ?? classeCtrl.text.trim();
                    if (matiereCtrl.text.trim().isEmpty ||
                        classeNom.isEmpty) {
                      return;
                    }
                    final fmt = (TimeOfDay t) =>
                        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
                    await ProfesseurService.addSlot(
                      jour: selectedJour,
                      heureDebut: fmt(debut),
                      heureFin: fmt(fin),
                      matiere: matiereCtrl.text.trim(),
                      classeNom: classeNom,
                      classeId: selectedClasse?.id ?? '',
                      salle: salleCtrl.text.trim(),
                    );
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  child: const Text('Enregistrer',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDeco(String label) => InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white38),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:
              BorderSide(color: Colors.white.withValues(alpha: 0.15)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF0F766E)),
        ),
      );
}

// ─── Jour Section ─────────────────────────────────────────────────────────────

class _JourSection extends StatelessWidget {
  final String jour;
  final List<EmploiSlot> slots;
  final void Function(String) onDelete;

  const _JourSection(
      {required this.jour, required this.slots, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(jour.toUpperCase(),
              style: const TextStyle(
                  color: Colors.white38,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2)),
        ),
        ...slots.map((s) => _SlotCard(slot: s, onDelete: onDelete)),
      ],
    );
  }
}

class _SlotCard extends StatelessWidget {
  final EmploiSlot slot;
  final void Function(String) onDelete;
  const _SlotCard({required this.slot, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(slot.id),
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
      onDismissed: (_) => onDelete(slot.id),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF161B22),
          borderRadius: BorderRadius.circular(12),
          border:
              Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [Color(0xFF0F766E), Color(0xFF0891B2)]),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${slot.heureDebut}\n${slot.heureFin}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(slot.matiere,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14)),
                  Text(
                    slot.classeNom +
                        (slot.salle.isNotEmpty ? ' · ${slot.salle}' : ''),
                    style:
                        const TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline,
                  color: Colors.white24, size: 18),
              onPressed: () => onDelete(slot.id),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Shared Widgets ───────────────────────────────────────────────────────────

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
          borderSide: const BorderSide(color: Color(0xFF0F766E)),
        ),
      ),
    );
  }
}
