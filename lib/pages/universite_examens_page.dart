import 'package:flutter/material.dart';
import '../models/devoir_model.dart';
import '../models/submission_model.dart';
import '../models/user_model.dart';
import '../services/etudiant_service.dart';
import '../widgets/cycle_access_guard.dart';

const _kColors = [Color(0xFFDC2626), Color(0xFF7C3AED)];

class UniversiteExamensPage extends StatelessWidget {
  const UniversiteExamensPage({super.key});

  @override
  Widget build(BuildContext context) {
    return CycleAccessGuard(
      cycleCategorie: 'Université',
      cycleColors: _kColors,
      builder: (user) => _Body(user: user),
    );
  }
}

class _Body extends StatefulWidget {
  final UserModel user;
  const _Body({required this.user});

  @override
  State<_Body> createState() => _BodyState();
}

class _BodyState extends State<_Body> with SingleTickerProviderStateMixin {
  late final TabController _tab;
  String get _classeNom => widget.user.classeNom ?? widget.user.niveau ?? '';

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        elevation: 0,
        title: const Text('Examens',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
        bottom: TabBar(
          controller: _tab,
          indicatorColor: _kColors.first,
          labelColor: _kColors.first,
          unselectedLabelColor: Colors.white38,
          labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          tabs: const [Tab(text: 'À venir'), Tab(text: 'Passés'), Tab(text: 'Tous')],
        ),
      ),
      body: _classeNom.isEmpty
          ? const Center(child: Text('Niveau non configuré', style: TextStyle(color: Colors.white38)))
          : StreamBuilder<List<DevoirModel>>(
              stream: EtudiantService.devoirsStream(_classeNom),
              builder: (_, snapD) {
                if (snapD.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Color(0xFFDC2626)));
                }
                return StreamBuilder<List<SubmissionModel>>(
                  stream: EtudiantService.submissionsStream(),
                  builder: (_, snapS) {
                    final devoirs = snapD.data ?? [];
                    final submittedIds = <String>{for (final s in (snapS.data ?? [])) s.assignmentId};
                    final now = DateTime.now();

                    final aVenir = devoirs
                        .where((d) => d.dateLimite != null && d.dateLimite!.isAfter(now))
                        .toList()
                      ..sort((a, b) => a.dateLimite!.compareTo(b.dateLimite!));
                    final passes = devoirs
                        .where((d) => d.dateLimite != null && d.dateLimite!.isBefore(now))
                        .toList()
                      ..sort((a, b) => b.dateLimite!.compareTo(a.dateLimite!));
                    final tous = [...aVenir, ...passes];

                    return Column(
                      children: [
                        _StatsBanner(total: devoirs.length, rendus: submittedIds.length, aVenir: aVenir.length),
                        Expanded(
                          child: TabBarView(
                            controller: _tab,
                            children: [
                              _ExamensList(devoirs: aVenir, submittedIds: submittedIds, emptyMsg: 'Aucun examen à venir'),
                              _ExamensList(devoirs: passes, submittedIds: submittedIds, emptyMsg: 'Aucun examen passé'),
                              _ExamensList(devoirs: tous, submittedIds: submittedIds, emptyMsg: 'Aucun examen enregistré'),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
    );
  }
}

// ── Bannière stats ────────────────────────────────────────────────────────────

class _StatsBanner extends StatelessWidget {
  final int total, rendus, aVenir;
  const _StatsBanner({required this.total, required this.rendus, required this.aVenir});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF161B22),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Row(
        children: [
          _Chip('Total', total, const Color(0xFF7C3AED)),
          const SizedBox(width: 8),
          _Chip('Rendus', rendus, const Color(0xFF16A34A)),
          const SizedBox(width: 8),
          _Chip('À venir', aVenir, const Color(0xFF2563EB)),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  const _Chip(this.label, this.count, this.color);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          children: [
            Text('$count', style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold)),
            Text(label, style: const TextStyle(color: Colors.white38, fontSize: 10)),
          ],
        ),
      ),
    );
  }
}

// ── Liste d'examens ───────────────────────────────────────────────────────────

class _ExamensList extends StatelessWidget {
  final List<DevoirModel> devoirs;
  final Set<String> submittedIds;
  final String emptyMsg;
  const _ExamensList({required this.devoirs, required this.submittedIds, required this.emptyMsg});

  @override
  Widget build(BuildContext context) {
    if (devoirs.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.edit_note_outlined, color: Colors.white24, size: 48),
            const SizedBox(height: 12),
            Text(emptyMsg, style: const TextStyle(color: Colors.white38)),
          ],
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      itemCount: devoirs.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) => _ExamenCard(
        devoir: devoirs[i],
        rendu: submittedIds.contains(devoirs[i].id),
      ),
    );
  }
}

// ── Carte examen ──────────────────────────────────────────────────────────────

class _ExamenCard extends StatelessWidget {
  final DevoirModel devoir;
  final bool rendu;
  const _ExamenCard({required this.devoir, required this.rendu});

  static String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  bool get _isPassed => devoir.dateLimite != null && devoir.dateLimite!.isBefore(DateTime.now());

  bool get _isUrgent {
    if (_isPassed || devoir.dateLimite == null) return false;
    return devoir.dateLimite!.difference(DateTime.now()).inDays <= 3;
  }

  Color get _statusColor {
    if (rendu) return const Color(0xFF16A34A);
    if (_isPassed) return const Color(0xFFDC2626);
    if (_isUrgent) return Colors.orange;
    return const Color(0xFF2563EB);
  }

  String get _statusLabel {
    if (rendu) return 'Rendu';
    if (_isPassed) return 'Non rendu';
    if (_isUrgent) return 'Urgent';
    return 'À venir';
  }

  IconData get _statusIcon {
    if (rendu) return Icons.check_circle_outline;
    if (_isPassed) return Icons.cancel_outlined;
    if (_isUrgent) return Icons.warning_amber_outlined;
    return Icons.schedule_outlined;
  }

  String? get _countdown {
    if (_isPassed || rendu || devoir.dateLimite == null) return null;
    final diff = devoir.dateLimite!.difference(DateTime.now());
    final days = diff.inDays;
    if (days == 0) return 'Aujourd\'hui';
    if (days == 1) return 'Demain';
    return 'Dans $days jours';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _isUrgent && !rendu ? Colors.orange.withValues(alpha: 0.4) : _statusColor.withValues(alpha: 0.2),
          width: _isUrgent && !rendu ? 1.5 : 1.0,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(color: _statusColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
            child: Icon(_statusIcon, color: _statusColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(devoir.titre,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                Text(devoir.matiere, style: const TextStyle(color: Colors.white38, fontSize: 12)),
                if (devoir.description.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(devoir.description,
                        style: const TextStyle(color: Colors.white38, fontSize: 11),
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                  ),
                if (devoir.dateLimite != null) ...[
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      Icon(Icons.calendar_today_outlined, size: 11, color: _statusColor),
                      const SizedBox(width: 4),
                      Text(_fmt(devoir.dateLimite!),
                          style: TextStyle(color: _statusColor, fontSize: 11)),
                      if (_countdown != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: _statusColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(_countdown!, style: TextStyle(color: _statusColor, fontSize: 10, fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: _statusColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
            child: Text(_statusLabel, style: TextStyle(color: _statusColor, fontSize: 11, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
