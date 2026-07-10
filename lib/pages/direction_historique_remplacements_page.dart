import 'package:flutter/material.dart';

import '../models/remplacement_model.dart';
import '../services/remplacement_service.dart';

class DirectionHistoriqueRemplacementsPage extends StatefulWidget {
  const DirectionHistoriqueRemplacementsPage({super.key});

  @override
  State<DirectionHistoriqueRemplacementsPage> createState() =>
      _DirectionHistoriqueRemplacementsPageState();
}

class _DirectionHistoriqueRemplacementsPageState
    extends State<DirectionHistoriqueRemplacementsPage> {
  String _search = '';
  _DateFilter _dateFilter = _DateFilter.tout;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        elevation: 0,
        title: const Text(
          'Historique des remplacements',
          style: TextStyle(
              color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
            child: TextField(
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Rechercher par nom, classe, matière…',
                hintStyle: const TextStyle(color: Colors.white38),
                prefixIcon:
                    const Icon(Icons.search, color: Colors.white38, size: 20),
                filled: true,
                fillColor: const Color(0xFF161B22),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (v) => setState(() => _search = v.trim().toLowerCase()),
            ),
          ),
          // Date filter chips
          SizedBox(
            height: 42,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              children: _DateFilter.values.map((f) {
                final active = _dateFilter == f;
                return GestureDetector(
                  onTap: () => setState(() => _dateFilter = f),
                  child: Container(
                    margin: const EdgeInsets.only(right: 6),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 4),
                    decoration: BoxDecoration(
                      color: active
                          ? const Color(0xFF6C47FF)
                          : const Color(0xFF161B22),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: active
                              ? const Color(0xFF6C47FF)
                              : Colors.white12),
                    ),
                    child: Text(f.label,
                        style: TextStyle(
                            color: active ? Colors.white : Colors.white54,
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                  ),
                );
              }).toList(),
            ),
          ),
          // List
          Expanded(
            child: StreamBuilder<List<Remplacement>>(
              stream: RemplacementService.remplacementsStream(),
              builder: (ctx, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child: CircularProgressIndicator(
                          color: Color(0xFF6C47FF)));
                }
                if (snap.hasError) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Erreur de chargement des remplacements.\nVérifiez votre connexion.',
                        style: TextStyle(color: Colors.white54),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                var list = snap.data ?? [];

                // Date filter
                final now = DateTime.now();
                if (_dateFilter != _DateFilter.tout) {
                  list = list.where((r) {
                    try {
                      final parts = r.date.split('-');
                      if (parts.length < 3) {
                        return false;
                      }
                      final d = DateTime(int.parse(parts[0]),
                          int.parse(parts[1]), int.parse(parts[2]));
                      switch (_dateFilter) {
                        case _DateFilter.aujourdhui:
                          return d.year == now.year &&
                              d.month == now.month &&
                              d.day == now.day;
                        case _DateFilter.semaine:
                          final start =
                              now.subtract(Duration(days: now.weekday - 1));
                          final end = start.add(const Duration(days: 7));
                          return d.isAfter(
                                  start.subtract(const Duration(days: 1))) &&
                              d.isBefore(end);
                        case _DateFilter.mois:
                          return d.year == now.year && d.month == now.month;
                        case _DateFilter.tout:
                          return true;
                      }
                    } catch (_) {
                      return false;
                    }
                  }).toList();
                }

                // Search filter
                if (_search.isNotEmpty) {
                  list = list.where((r) {
                    return r.professeurAbsentNom
                            .toLowerCase()
                            .contains(_search) ||
                        (r.professeurRemplacantNom ?? '')
                            .toLowerCase()
                            .contains(_search) ||
                        r.classeNom.toLowerCase().contains(_search) ||
                        r.matiere.toLowerCase().contains(_search);
                  }).toList();
                }

                if (list.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.history, color: Colors.white12, size: 48),
                        SizedBox(height: 10),
                        Text('Aucun remplacement trouvé',
                            style: TextStyle(
                                color: Colors.white38, fontSize: 14)),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(14, 6, 14, 20),
                  itemCount: list.length,
                  itemBuilder: (ctx2, i) =>
                      _HistoriqueCard(remplacement: list[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

enum _DateFilter {
  aujourdhui,
  semaine,
  mois,
  tout;

  String get label {
    switch (this) {
      case _DateFilter.aujourdhui:
        return "Aujourd'hui";
      case _DateFilter.semaine:
        return 'Cette semaine';
      case _DateFilter.mois:
        return 'Ce mois';
      case _DateFilter.tout:
        return 'Tout';
    }
  }
}

class _HistoriqueCard extends StatelessWidget {
  final Remplacement remplacement;
  const _HistoriqueCard({required this.remplacement});

  IconData _iconForStatut(RemplacementStatut s) {
    switch (s) {
      case RemplacementStatut.confirme:
        return Icons.verified_outlined;
      case RemplacementStatut.accepte:
        return Icons.check_circle_outline;
      case RemplacementStatut.refuse:
        return Icons.cancel_outlined;
      case RemplacementStatut.annule:
        return Icons.remove_circle_outline;
      case RemplacementStatut.termine:
        return Icons.task_alt;
      case RemplacementStatut.propose:
        return Icons.person_add_outlined;
      case RemplacementStatut.enAttente:
        return Icons.hourglass_empty;
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = remplacement;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: r.statutColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(_iconForStatut(r.statut),
                color: r.statutColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(r.professeurAbsentNom,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 13)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: r.statutColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(r.statutLabel,
                          style: TextStyle(
                              color: r.statutColor, fontSize: 10)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 3,
                  children: [
                    _Tag(text: r.classeNom),
                    _Tag(text: r.matiere),
                    _Tag(text: r.date),
                    _Tag(
                        text:
                            '${r.heureDebut}–${r.heureFin}'),
                    _Tag(text: r.motifLabel),
                  ],
                ),
                if (r.professeurRemplacantNom != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.arrow_forward,
                          size: 12, color: Colors.white38),
                      const SizedBox(width: 4),
                      Text('Remplaçant : ${r.professeurRemplacantNom}',
                          style: const TextStyle(
                              color: Colors.white54, fontSize: 11)),
                    ],
                  ),
                ],
                if (r.valideParNom != null) ...[
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(Icons.verified_user_outlined,
                          size: 12, color: Colors.white24),
                      const SizedBox(width: 4),
                      Text('Validé par : ${r.valideParNom}',
                          style: const TextStyle(
                              color: Colors.white38, fontSize: 11)),
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

class _Tag extends StatelessWidget {
  final String text;
  const _Tag({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFF1F2937),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(text,
          style: const TextStyle(color: Colors.white54, fontSize: 10)),
    );
  }
}
