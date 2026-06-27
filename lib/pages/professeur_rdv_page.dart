import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/rdv_model.dart';
import '../services/rdv_service.dart';

class ProfesseurRdvPage extends StatelessWidget {
  const ProfesseurRdvPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        elevation: 0,
        title: const Text('Rendez-vous parents',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: StreamBuilder<List<RdvModel>>(
        stream: RdvService.rdvProfesseurStream(),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final all = snap.data ?? [];
          if (all.isEmpty) {
            return const Center(
              child: Text('Aucun rendez-vous.',
                  style: TextStyle(color: Colors.white38)),
            );
          }

          // Trier : en attente en premier
          final sorted = [...all]..sort((a, b) {
              const order = [
                RdvStatut.demande,
                RdvStatut.proposeAutreDate,
                RdvStatut.accepte,
                RdvStatut.confirme,
                RdvStatut.refuse,
                RdvStatut.annule,
              ];
              return order.indexOf(a.statut)
                  .compareTo(order.indexOf(b.statut));
            });

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: sorted.length,
            itemBuilder: (ctx, i) => _RdvCard(rdv: sorted[i]),
          );
        },
      ),
    );
  }
}

class _RdvCard extends StatefulWidget {
  final RdvModel rdv;
  const _RdvCard({required this.rdv});
  @override
  State<_RdvCard> createState() => _RdvCardState();
}

class _RdvCardState extends State<_RdvCard> {
  bool _expanded = false;
  bool _busy = false;
  final _notesCtrl = TextEditingController();

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _accepter() async {
    setState(() => _busy = true);
    await RdvService.accepter(widget.rdv.id, notesProfesseur: _notesCtrl.text.trim());
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _refuser() async {
    setState(() => _busy = true);
    await RdvService.refuser(widget.rdv.id, notesProfesseur: _notesCtrl.text.trim());
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _proposerAutreDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 60)),
    );
    if (picked == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 17, minute: 0),
    );
    if (time == null || !mounted) return;
    final nouvelle = DateTime(
        picked.year, picked.month, picked.day, time.hour, time.minute);
    setState(() => _busy = true);
    await RdvService.proposerAutreDate(
      widget.rdv.id,
      nouvelle,
      notesProfesseur: _notesCtrl.text.trim(),
    );
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final rdv = widget.rdv;
    final statut = rdv.statut;
    final pending = statut == RdvStatut.demande;
    Color color;
    if (statut == RdvStatut.accepte || statut == RdvStatut.confirme) {
      color = Colors.green;
    } else if (statut == RdvStatut.refuse || statut == RdvStatut.annule) {
      color = Colors.red;
    } else if (statut == RdvStatut.proposeAutreDate) {
      color = Colors.orange;
    } else {
      color = Colors.blue;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          // En-tête cliquable
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Parent : ${rdv.parentNom}',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 14)),
                        const SizedBox(height: 2),
                        Text('Élève : ${rdv.eleveNom} · ${rdv.classeNom}',
                            style: const TextStyle(
                                color: Colors.white54, fontSize: 12)),
                        const SizedBox(height: 2),
                        Text(
                          DateFormat('dd/MM/yyyy – HH:mm')
                              .format(rdv.dateHeure),
                          style: const TextStyle(
                              color: Colors.white38, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(statut.label,
                        style: TextStyle(color: color, fontSize: 11)),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    _expanded
                        ? Icons.expand_less
                        : Icons.expand_more,
                    color: Colors.white38,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),

          // Détail et actions
          if (_expanded)
            Padding(
              padding:
                  const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(color: Colors.white10),
                  if (rdv.motif.isNotEmpty) ...[
                    const Text('Motif',
                        style: TextStyle(
                            color: Colors.white54, fontSize: 11)),
                    const SizedBox(height: 2),
                    Text(rdv.motif,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 13)),
                    const SizedBox(height: 8),
                  ],
                  if (rdv.notesParent.isNotEmpty) ...[
                    const Text('Notes du parent',
                        style: TextStyle(
                            color: Colors.white54, fontSize: 11)),
                    const SizedBox(height: 2),
                    Text(rdv.notesParent,
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12)),
                    const SizedBox(height: 8),
                  ],
                  if (rdv.contrePropositionDate != null) ...[
                    Text(
                      'Contre-proposition : ${DateFormat('dd/MM/yyyy – HH:mm').format(rdv.contrePropositionDate!)}',
                      style: const TextStyle(
                          color: Colors.orange, fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (pending) ...[
                    TextField(
                      controller: _notesCtrl,
                      maxLines: 2,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 12),
                      decoration: InputDecoration(
                        labelText: 'Réponse (optionnel)',
                        labelStyle: const TextStyle(
                            color: Colors.white38, fontSize: 12),
                        isDense: true,
                        enabledBorder: OutlineInputBorder(
                          borderSide:
                              const BorderSide(color: Colors.white12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: const BorderSide(
                              color: Color(0xFF2563EB)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (_busy)
                      const Center(child: CircularProgressIndicator())
                    else
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.green,
                                side:
                                    const BorderSide(color: Colors.green),
                              ),
                              onPressed: _accepter,
                              child: const Text('Accepter',
                                  style: TextStyle(fontSize: 12)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.orange,
                                side: const BorderSide(
                                    color: Colors.orange),
                              ),
                              onPressed: _proposerAutreDate,
                              child: const Text('Autre date',
                                  style: TextStyle(fontSize: 12)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red,
                                side:
                                    const BorderSide(color: Colors.red),
                              ),
                              onPressed: _refuser,
                              child: const Text('Refuser',
                                  style: TextStyle(fontSize: 12)),
                            ),
                          ),
                        ],
                      ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}
