import 'package:flutter/material.dart';

import '../models/classe_model.dart';
import '../models/presence_model.dart';
import '../services/professeur_service.dart';

class ProfesseurPresencesPage extends StatefulWidget {
  const ProfesseurPresencesPage({super.key});

  @override
  State<ProfesseurPresencesPage> createState() =>
      _ProfesseurPresencesPageState();
}

class _ProfesseurPresencesPageState extends State<ProfesseurPresencesPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  ClasseModel? _classe;
  DateTime _date = DateTime.now();

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        elevation: 0,
        title: const Text('Présences',
            style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: const Color(0xFF15803D),
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white38,
          tabs: const [
            Tab(text: 'Faire l\'appel'),
            Tab(text: 'Historique'),
          ],
        ),
      ),
      body: StreamBuilder<List<ClasseModel>>(
        stream: ProfesseurService.classesStream(),
        builder: (context, snap) {
          final classes = snap.data ?? [];
          if (classes.isNotEmpty && _classe == null) {
            WidgetsBinding.instance
                .addPostFrameCallback((_) => setState(() => _classe = classes.first));
          }
          return Column(
            children: [
              if (classes.isNotEmpty)
                _ClasseDateBar(
                  classes: classes,
                  selected: _classe,
                  date: _date,
                  onClasseChanged: (c) => setState(() => _classe = c),
                  onDateChanged: (d) => setState(() => _date = d),
                ),
              Expanded(
                child: TabBarView(
                  controller: _tabs,
                  children: [
                    _classe == null
                        ? _emptyClasses()
                        : _AppelTab(classe: _classe!, date: _date),
                    _classe == null
                        ? _emptyClasses()
                        : _HistoriqueTab(classeId: _classe!.id),
                  ],
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

// ─── Barre classe + date ──────────────────────────────────────────────────────

class _ClasseDateBar extends StatelessWidget {
  final List<ClasseModel> classes;
  final ClasseModel? selected;
  final DateTime date;
  final void Function(ClasseModel) onClasseChanged;
  final void Function(DateTime) onDateChanged;

  const _ClasseDateBar({
    required this.classes,
    required this.selected,
    required this.date,
    required this.onClasseChanged,
    required this.onDateChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: const Color(0xFF161B22),
      child: Row(
        children: [
          Expanded(
            child: DropdownButton<ClasseModel>(
              value: selected,
              dropdownColor: const Color(0xFF161B22),
              style: const TextStyle(color: Colors.white, fontSize: 14),
              underline: const SizedBox.shrink(),
              isExpanded: true,
              items: classes
                  .map((c) => DropdownMenuItem(
                      value: c,
                      child: Text(c.nom,
                          style: const TextStyle(color: Colors.white))))
                  .toList(),
              onChanged: (c) {
                if (c != null) onClasseChanged(c);
              },
            ),
          ),
          const SizedBox(width: 12),
          InkWell(
            onTap: () async {
              final d = await showDatePicker(
                context: context,
                initialDate: date,
                firstDate: DateTime(2020),
                lastDate: DateTime.now().add(const Duration(days: 30)),
                builder: (ctx, child) => Theme(
                  data: Theme.of(ctx).copyWith(
                    colorScheme: const ColorScheme.dark(
                      primary: Color(0xFF15803D),
                      surface: Color(0xFF161B22),
                    ),
                  ),
                  child: child!,
                ),
              );
              if (d != null) onDateChanged(d);
            },
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.15)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today,
                      color: Colors.white54, size: 14),
                  const SizedBox(width: 6),
                  Text(
                    '${date.day.toString().padLeft(2, '0')}/'
                    '${date.month.toString().padLeft(2, '0')}',
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Faire l'appel ────────────────────────────────────────────────────────────

class _AppelTab extends StatefulWidget {
  final ClasseModel classe;
  final DateTime date;
  const _AppelTab({required this.classe, required this.date});

  @override
  State<_AppelTab> createState() => _AppelTabState();
}

class _AppelTabState extends State<_AppelTab> {
  final Map<String, PresenceStatut> _statuts = {};
  final Map<String, String> _motifs = {};
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: ProfesseurService.elevesParClasseStream(widget.classe.nom),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: Color(0xFF15803D)));
        }
        final eleves = snap.data ?? [];
        if (eleves.isEmpty) {
          return const Center(
            child: Text('Aucun élève dans cette classe',
                style: TextStyle(color: Colors.white38)),
          );
        }

        for (final e in eleves) {
          _statuts.putIfAbsent(e['id'] as String, () => PresenceStatut.present);
        }

        return Column(
          children: [
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                itemCount: eleves.length,
                itemBuilder: (ctx, i) {
                  final e = eleves[i];
                  final eid = e['id'] as String;
                  return _AppelTile(
                    nom: '${e['prenom'] ?? ''} ${e['nom'] ?? ''}'.trim(),
                    statut: _statuts[eid] ?? PresenceStatut.present,
                    onChanged: (s) => setState(() => _statuts[eid] = s),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF15803D),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14)),
                  onPressed: _saving
                      ? null
                      : () => _saveAppel(eleves),
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Text('Enregistrer l\'appel',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15)),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _saveAppel(List<Map<String, dynamic>> eleves) async {
    setState(() => _saving = true);
    try {
      await ProfesseurService.saveAppel(
        classeId: widget.classe.id,
        classeNom: widget.classe.nom,
        date: widget.date,
        eleves: eleves,
        statuts: _statuts,
        motifs: _motifs,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Appel enregistré'),
            backgroundColor: Color(0xFF15803D),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _AppelTile extends StatelessWidget {
  final String nom;
  final PresenceStatut statut;
  final void Function(PresenceStatut) onChanged;

  const _AppelTile({
    required this.nom,
    required this.statut,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: _borderColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(nom.isEmpty ? '—' : nom,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                    fontSize: 14)),
          ),
          _PresenceButton(
            icon: Icons.check_circle_outline,
            label: 'P',
            color: const Color(0xFF15803D),
            active: statut == PresenceStatut.present,
            onTap: () => onChanged(PresenceStatut.present),
          ),
          const SizedBox(width: 6),
          _PresenceButton(
            icon: Icons.cancel_outlined,
            label: 'A',
            color: const Color(0xFFDC2626),
            active: statut == PresenceStatut.absent,
            onTap: () => onChanged(PresenceStatut.absent),
          ),
          const SizedBox(width: 6),
          _PresenceButton(
            icon: Icons.access_time,
            label: 'R',
            color: const Color(0xFFD97706),
            active: statut == PresenceStatut.retard,
            onTap: () => onChanged(PresenceStatut.retard),
          ),
        ],
      ),
    );
  }

  Color get _borderColor {
    switch (statut) {
      case PresenceStatut.present:
        return const Color(0xFF15803D);
      case PresenceStatut.absent:
        return const Color(0xFFDC2626);
      case PresenceStatut.retard:
        return const Color(0xFFD97706);
    }
  }
}

class _PresenceButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool active;
  final VoidCallback onTap;

  const _PresenceButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: active ? color.withValues(alpha: 0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: active ? color : Colors.white.withValues(alpha: 0.1)),
        ),
        child: Text(label,
            style: TextStyle(
                color: active ? color : Colors.white38,
                fontWeight: FontWeight.bold,
                fontSize: 13)),
      ),
    );
  }
}

// ─── Historique ───────────────────────────────────────────────────────────────

class _HistoriqueTab extends StatelessWidget {
  final String classeId;
  const _HistoriqueTab({required this.classeId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<PresenceRecord>>(
      stream: ProfesseurService.historiquePresencesStream(classeId),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: Color(0xFF15803D)));
        }
        final records = snap.data ?? [];
        if (records.isEmpty) {
          return const Center(
              child: Text('Aucun historique disponible',
                  style: TextStyle(color: Colors.white38)));
        }
        // Grouper par date
        final grouped = <String, List<PresenceRecord>>{};
        for (final r in records) {
          final key =
              '${r.date.day.toString().padLeft(2, '0')}/${r.date.month.toString().padLeft(2, '0')}/${r.date.year}';
          grouped.putIfAbsent(key, () => []).add(r);
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: grouped.entries.map((e) {
            final absents = e.value
                .where((r) => r.statut == PresenceStatut.absent)
                .length;
            final retards = e.value
                .where((r) => r.statut == PresenceStatut.retard)
                .length;
            return _HistoriqueCard(
                date: e.key,
                records: e.value,
                absents: absents,
                retards: retards);
          }).toList(),
        );
      },
    );
  }
}

class _HistoriqueCard extends StatelessWidget {
  final String date;
  final List<PresenceRecord> records;
  final int absents;
  final int retards;

  const _HistoriqueCard({
    required this.date,
    required this.records,
    required this.absents,
    required this.retards,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 14),
        collapsedIconColor: Colors.white38,
        iconColor: Colors.white38,
        title: Row(
          children: [
            Text(date,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14)),
            const SizedBox(width: 12),
            _Badge('$absents abs.', const Color(0xFFDC2626)),
            const SizedBox(width: 6),
            _Badge('$retards ret.', const Color(0xFFD97706)),
          ],
        ),
        children: records.map((r) => _HistoriqueTile(record: r)).toList(),
      ),
    );
  }
}

class _HistoriqueTile extends StatelessWidget {
  final PresenceRecord record;
  const _HistoriqueTile({required this.record});

  @override
  Widget build(BuildContext context) {
    final color = record.statut == PresenceStatut.present
        ? const Color(0xFF15803D)
        : record.statut == PresenceStatut.absent
            ? const Color(0xFFDC2626)
            : const Color(0xFFD97706);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(record.eleveNomComplet,
                style:
                    const TextStyle(color: Colors.white70, fontSize: 13)),
          ),
          Text(record.statut.label,
              style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}
