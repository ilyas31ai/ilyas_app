import 'package:flutter/material.dart';

import '../models/disponibilite_model.dart';
import '../models/remplacement_model.dart';
import '../models/user_model.dart';
import '../services/remplacement_service.dart';
import '../services/user_service.dart';

class ProfesseurDisponibilitePage extends StatefulWidget {
  const ProfesseurDisponibilitePage({super.key});

  @override
  State<ProfesseurDisponibilitePage> createState() =>
      _ProfesseurDisponibilitePageState();
}

class _ProfesseurDisponibilitePageState
    extends State<ProfesseurDisponibilitePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        elevation: 0,
        title: const Text(
          'Mes disponibilités',
          style: TextStyle(
              color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
        ),
      ),
      body: StreamBuilder<UserModel?>(
        stream: UserService.currentUserStream(),
        builder: (ctx, userSnap) {
          if (userSnap.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: Color(0xFF6C47FF)));
          }
          final user = userSnap.data;
          if (user == null) {
            return const Center(
              child: Text('Non connecté',
                  style: TextStyle(color: Colors.white38)),
            );
          }
          return StreamBuilder<DisponibiliteEnseignant?>(
            stream: RemplacementService.disponibiliteStream(user.uid),
            builder: (ctx2, dispoSnap) {
              if (dispoSnap.connectionState == ConnectionState.waiting) {
                return const Center(
                    child: CircularProgressIndicator(color: Color(0xFF6C47FF)));
              }
              return _DispoEditor(
                user: user,
                dispo: dispoSnap.data,
              );
            },
          );
        },
      ),
    );
  }
}

class _DispoEditor extends StatefulWidget {
  final UserModel user;
  final DisponibiliteEnseignant? dispo;

  const _DispoEditor({required this.user, this.dispo});

  @override
  State<_DispoEditor> createState() => _DispoEditorState();
}

class _DispoEditorState extends State<_DispoEditor> {
  static const _jours = [
    'Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi'
  ];

  late List<String> _selectedJours;
  late List<CreneauHoraire> _creneaux;
  late List<String> _matieres;
  late List<String> _niveaux;
  late List<String> _classes;
  late bool _disponibleAujourdhui;
  bool _saving = false;

  final _matCtrl = TextEditingController();
  final _niveauCtrl = TextEditingController();
  final _classeCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initFromDispo(widget.dispo);
  }

  @override
  void didUpdateWidget(_DispoEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.dispo != widget.dispo && widget.dispo != null) {
      _initFromDispo(widget.dispo);
    }
  }

  void _initFromDispo(DisponibiliteEnseignant? d) {
    _selectedJours = List<String>.from(d?.jours ?? []);
    _creneaux = List<CreneauHoraire>.from(d?.creneaux ?? []);
    _matieres = List<String>.from(d?.matieres ?? []);
    _niveaux = List<String>.from(d?.niveaux ?? []);
    _classes = List<String>.from(d?.classes ?? []);
    _disponibleAujourdhui = d?.disponibleAujourdhui ?? true;
  }

  @override
  void dispose() {
    _matCtrl.dispose();
    _niveauCtrl.dispose();
    _classeCtrl.dispose();
    super.dispose();
  }

  Future<void> _addCreneau() async {
    final jour = _selectedJours.isNotEmpty ? _selectedJours.first : 'Lundi';
    final debut = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 8, minute: 0),
    );
    if (debut == null) {
      return;
    }
    if (!mounted) {
      return;
    }
    final fin = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: debut.hour + 2, minute: 0),
    );
    if (fin == null) {
      return;
    }
    setState(() {
      _creneaux.add(CreneauHoraire(
        jour: jour,
        heureDebut:
            '${debut.hour.toString().padLeft(2, '0')}:${debut.minute.toString().padLeft(2, '0')}',
        heureFin:
            '${fin.hour.toString().padLeft(2, '0')}:${fin.minute.toString().padLeft(2, '0')}',
      ));
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final dispo = DisponibiliteEnseignant(
      uid: widget.user.uid,
      nom: widget.user.displayName,
      email: widget.user.email,
      jours: _selectedJours,
      creneaux: _creneaux,
      matieres: _matieres,
      niveaux: _niveaux,
      classes: _classes,
      disponibleAujourdhui: _disponibleAujourdhui,
    );
    await RemplacementService.saveDisponibilite(widget.user.uid, dispo);
    if (mounted) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Disponibilités enregistrées'),
          backgroundColor: Color(0xFF10B981),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Section 1: Jours de présence
              _SectionHeader(icon: Icons.calendar_today_outlined, title: 'Jours de présence'),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF161B22),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                ),
                child: Column(
                  children: _jours.map((j) => CheckboxListTile(
                    dense: true,
                    title: Text(j,
                        style: const TextStyle(color: Colors.white, fontSize: 14)),
                    value: _selectedJours.contains(j),
                    activeColor: const Color(0xFF6C47FF),
                    checkColor: Colors.white,
                    onChanged: (v) => setState(() {
                      if (v == true) {
                        _selectedJours.add(j);
                      } else {
                        _selectedJours.remove(j);
                      }
                    }),
                  )).toList(),
                ),
              ),
              const SizedBox(height: 6),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF161B22),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                ),
                child: CheckboxListTile(
                  dense: true,
                  title: const Text('Disponible aujourd\'hui',
                      style: TextStyle(color: Colors.white, fontSize: 14)),
                  subtitle: const Text('Cochez si vous êtes présent aujourd\'hui',
                      style: TextStyle(color: Colors.white38, fontSize: 11)),
                  value: _disponibleAujourdhui,
                  activeColor: const Color(0xFF10B981),
                  checkColor: Colors.white,
                  onChanged: (v) =>
                      setState(() => _disponibleAujourdhui = v ?? true),
                ),
              ),
              const SizedBox(height: 20),

              // Section 2: Créneaux horaires
              Row(
                children: [
                  const _SectionHeader(
                      icon: Icons.access_time_outlined,
                      title: 'Créneaux horaires'),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: _addCreneau,
                    icon: const Icon(Icons.add, color: Color(0xFF6C47FF), size: 16),
                    label: const Text('Ajouter',
                        style: TextStyle(color: Color(0xFF6C47FF), fontSize: 12)),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              if (_creneaux.isEmpty)
                _EmptyHint(text: 'Aucun créneau — appuyez sur Ajouter')
              else
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF161B22),
                    borderRadius: BorderRadius.circular(12),
                    border:
                        Border.all(color: Colors.white.withValues(alpha: 0.06)),
                  ),
                  child: Column(
                    children: _creneaux.asMap().entries.map((e) {
                      final c = e.value;
                      return ListTile(
                        dense: true,
                        leading: const Icon(Icons.access_time,
                            color: Colors.white38, size: 18),
                        title: Text(
                            '${c.jour} — ${c.heureDebut} à ${c.heureFin}',
                            style: const TextStyle(
                                color: Colors.white, fontSize: 13)),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline,
                              color: Colors.white38, size: 18),
                          onPressed: () =>
                              setState(() => _creneaux.removeAt(e.key)),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              const SizedBox(height: 20),

              // Section 3: Matières
              const _SectionHeader(
                  icon: Icons.book_outlined, title: 'Mes matières'),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF161B22),
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.06)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: _matieres
                          .map((m) => InputChip(
                                label: Text(m,
                                    style: const TextStyle(
                                        color: Colors.white, fontSize: 12)),
                                backgroundColor: const Color(0xFF1F2937),
                                deleteIconColor: Colors.white38,
                                onDeleted: () =>
                                    setState(() => _matieres.remove(m)),
                              ))
                          .toList(),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _matCtrl,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 13),
                            decoration: const InputDecoration(
                              hintText: 'Ajouter une matière…',
                              hintStyle: TextStyle(
                                  color: Colors.white38, fontSize: 12),
                              border: InputBorder.none,
                              isDense: true,
                            ),
                            onSubmitted: (v) {
                              if (v.trim().isNotEmpty) {
                                setState(() {
                                  _matieres.add(v.trim());
                                  _matCtrl.clear();
                                });
                              }
                            },
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add_circle,
                              color: Color(0xFF6C47FF), size: 22),
                          onPressed: () {
                            final v = _matCtrl.text.trim();
                            if (v.isNotEmpty) {
                              setState(() {
                                _matieres.add(v);
                                _matCtrl.clear();
                              });
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Section 4: Niveaux et classes
              const _SectionHeader(
                  icon: Icons.school_outlined, title: 'Niveaux et classes'),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF161B22),
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.06)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Niveaux',
                        style:
                            TextStyle(color: Colors.white54, fontSize: 12)),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: _niveaux
                          .map((n) => InputChip(
                                label: Text(n,
                                    style: const TextStyle(
                                        color: Colors.white, fontSize: 12)),
                                backgroundColor: const Color(0xFF1F2937),
                                deleteIconColor: Colors.white38,
                                onDeleted: () =>
                                    setState(() => _niveaux.remove(n)),
                              ))
                          .toList(),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _niveauCtrl,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 13),
                            decoration: const InputDecoration(
                              hintText: 'Ex : 3AM, 1AS…',
                              hintStyle: TextStyle(
                                  color: Colors.white38, fontSize: 12),
                              border: InputBorder.none,
                              isDense: true,
                            ),
                            onSubmitted: (v) {
                              if (v.trim().isNotEmpty) {
                                setState(() {
                                  _niveaux.add(v.trim());
                                  _niveauCtrl.clear();
                                });
                              }
                            },
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add_circle,
                              color: Color(0xFF2563EB), size: 22),
                          onPressed: () {
                            final v = _niveauCtrl.text.trim();
                            if (v.isNotEmpty) {
                              setState(() {
                                _niveaux.add(v);
                                _niveauCtrl.clear();
                              });
                            }
                          },
                        ),
                      ],
                    ),
                    const Divider(color: Colors.white12, height: 16),
                    const Text('Classes',
                        style:
                            TextStyle(color: Colors.white54, fontSize: 12)),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: _classes
                          .map((c) => InputChip(
                                label: Text(c,
                                    style: const TextStyle(
                                        color: Colors.white, fontSize: 12)),
                                backgroundColor: const Color(0xFF1F2937),
                                deleteIconColor: Colors.white38,
                                onDeleted: () =>
                                    setState(() => _classes.remove(c)),
                              ))
                          .toList(),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _classeCtrl,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 13),
                            decoration: const InputDecoration(
                              hintText: 'Ex : 3AM-A, 1AS-B…',
                              hintStyle: TextStyle(
                                  color: Colors.white38, fontSize: 12),
                              border: InputBorder.none,
                              isDense: true,
                            ),
                            onSubmitted: (v) {
                              if (v.trim().isNotEmpty) {
                                setState(() {
                                  _classes.add(v.trim());
                                  _classeCtrl.clear();
                                });
                              }
                            },
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add_circle,
                              color: Color(0xFF0F766E), size: 22),
                          onPressed: () {
                            final v = _classeCtrl.text.trim();
                            if (v.isNotEmpty) {
                              setState(() {
                                _classes.add(v);
                                _classeCtrl.clear();
                              });
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Section 5: Déclarer une absence
              const _SectionHeader(
                  icon: Icons.person_off_outlined,
                  title: 'Déclarer une absence'),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF161B22),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.3)),
                ),
                child: Column(
                  children: [
                    const Text(
                      'Signalez votre absence à l\'avance pour permettre à la direction d\'organiser votre remplacement.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: () => showDialog(
                        context: context,
                        builder: (_) => _ProfAbsenceDialog(
                          uid: widget.user.uid,
                          nom: widget.user.displayName,
                        ),
                      ),
                      icon: const Icon(Icons.person_off_outlined,
                          color: Colors.white, size: 18),
                      label: const Text('Déclarer mon absence',
                          style: TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFEF4444),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 10),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Section 6: Mes remplacements
              const _SectionHeader(
                  icon: Icons.swap_horiz, title: 'Mes remplacements'),
              const SizedBox(height: 8),
              StreamBuilder<List<Remplacement>>(
                stream: RemplacementService.remplacementsParEnseignantStream(
                    widget.user.uid),
                builder: (ctx, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(
                        child: CircularProgressIndicator(
                            color: Color(0xFF6C47FF), strokeWidth: 2));
                  }
                  final list = snap.data ?? [];
                  if (list.isEmpty) {
                    return _EmptyHint(
                        text: 'Aucun remplacement qui vous est assigné');
                  }
                  return Column(
                    children: list.map((r) => _MonRemplacementTile(
                          remplacement: r,
                          uid: widget.user.uid,
                        )).toList(),
                  );
                },
              ),
            ],
          ),
        ),
        // Save FAB
        Positioned(
          bottom: 20,
          right: 20,
          child: FloatingActionButton.extended(
            backgroundColor: const Color(0xFF6C47FF),
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.save_outlined, color: Colors.white),
            label: const Text('Enregistrer',
                style: TextStyle(color: Colors.white)),
          ),
        ),
      ],
    );
  }
}

class _MonRemplacementTile extends StatelessWidget {
  final Remplacement remplacement;
  final String uid;
  const _MonRemplacementTile(
      {required this.remplacement, required this.uid});

  @override
  Widget build(BuildContext context) {
    final r = remplacement;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                    '${r.classeNom} · ${r.matiere}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 13)),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: r.statutColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(r.statutLabel,
                    style: TextStyle(color: r.statutColor, fontSize: 11)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text('${r.date} · ${r.heureDebut}–${r.heureFin}',
              style: const TextStyle(color: Colors.white38, fontSize: 12)),
          if (r.statut == RemplacementStatut.propose) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => RemplacementService.updateStatut(
                        r.id, RemplacementStatut.accepte,
                        remplacantUid: uid),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF10B981),
                      side: const BorderSide(color: Color(0xFF10B981)),
                      padding: const EdgeInsets.symmetric(vertical: 6),
                    ),
                    child: const Text('Accepter', style: TextStyle(fontSize: 12)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => RemplacementService.updateStatut(
                        r.id, RemplacementStatut.refuse),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFEF4444),
                      side: const BorderSide(color: Color(0xFFEF4444)),
                      padding: const EdgeInsets.symmetric(vertical: 6),
                    ),
                    child: const Text('Refuser', style: TextStyle(fontSize: 12)),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ProfAbsenceDialog extends StatefulWidget {
  final String uid;
  final String nom;
  const _ProfAbsenceDialog({required this.uid, required this.nom});

  @override
  State<_ProfAbsenceDialog> createState() => _ProfAbsenceDialogState();
}

class _ProfAbsenceDialogState extends State<_ProfAbsenceDialog> {
  DateTime _date = DateTime.now();
  String _motif = 'maladie';
  final _commentCtrl = TextEditingController();
  bool _loading = false;

  static const _motifs = ['maladie', 'formation', 'conge', 'autre'];
  static const _motifsLabels = ['Maladie', 'Formation', 'Congé', 'Autre'];

  String _dateStr(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 60)),
    );
    if (d != null) {
      setState(() => _date = d);
    }
  }

  Future<void> _save() async {
    setState(() => _loading = true);
    await RemplacementService.declareAbsence(
      uid: widget.uid,
      nom: widget.nom,
      date: _dateStr(_date),
      motif: _motif,
      commentaire: _commentCtrl.text.trim(),
    );
    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF161B22),
      title: const Text('Déclarer une absence',
          style: TextStyle(color: Colors.white, fontSize: 15)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Date',
                  style: TextStyle(color: Colors.white54, fontSize: 13)),
              subtitle: Text(
                  '${_date.day}/${_date.month}/${_date.year}',
                  style: const TextStyle(color: Colors.white, fontSize: 14)),
              trailing: const Icon(Icons.calendar_today,
                  color: Colors.white38, size: 18),
              onTap: _pickDate,
            ),
            DropdownButtonFormField<String>(
              value: _motif,
              decoration: const InputDecoration(
                labelText: 'Motif',
                labelStyle: TextStyle(color: Colors.white54),
                enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white12)),
              ),
              dropdownColor: const Color(0xFF1F2937),
              style: const TextStyle(color: Colors.white),
              items: List.generate(
                  _motifs.length,
                  (i) => DropdownMenuItem(
                        value: _motifs[i],
                        child: Text(_motifsLabels[i],
                            style: const TextStyle(
                                color: Colors.white, fontSize: 13)),
                      )),
              onChanged: (v) => setState(() => _motif = v ?? 'maladie'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _commentCtrl,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: const InputDecoration(
                labelText: 'Commentaire (optionnel)',
                labelStyle: TextStyle(color: Colors.white54),
                enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white12)),
              ),
              maxLines: 2,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler',
              style: TextStyle(color: Colors.white38)),
        ),
        ElevatedButton(
          onPressed: _loading ? null : _save,
          style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444)),
          child: _loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Text('Déclarer',
                  style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}

// ─── Shared helpers ───────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  const _SectionHeader({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF6C47FF), size: 18),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _EmptyHint extends StatelessWidget {
  final String text;
  const _EmptyHint({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Center(
        child: Text(text,
            style: const TextStyle(color: Colors.white38, fontSize: 12)),
      ),
    );
  }
}
