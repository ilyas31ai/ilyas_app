import 'package:flutter/material.dart';
import '../models/devoir_model.dart';
import '../models/submission_model.dart';
import '../models/user_model.dart';
import '../services/etudiant_service.dart';
import '../widgets/cycle_access_guard.dart';

const _kColors = [Color(0xFF6C47FF), Color(0xFF2563EB)];

class LyceeDevoirs extends StatelessWidget {
  const LyceeDevoirs({super.key});

  @override
  Widget build(BuildContext context) {
    return CycleAccessGuard(
      cycleCategorie: 'Lycée',
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
        title: const Text('Mes Devoirs', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
        bottom: TabBar(
          controller: _tab,
          indicatorColor: _kColors.first,
          labelColor: _kColors.first,
          unselectedLabelColor: Colors.white38,
          labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          tabs: const [
            Tab(text: 'À faire'),
            Tab(text: 'Rendus'),
            Tab(text: 'En retard'),
          ],
        ),
      ),
      body: _classeNom.isEmpty
          ? const Center(child: Text('Classe non configurée', style: TextStyle(color: Colors.white38)))
          : _DevoirsContent(classeNom: _classeNom, user: widget.user, tabController: _tab),
    );
  }
}

class _DevoirsContent extends StatelessWidget {
  final String classeNom;
  final UserModel user;
  final TabController tabController;
  const _DevoirsContent({required this.classeNom, required this.user, required this.tabController});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<DevoirModel>>(
      stream: EtudiantService.devoirsStream(classeNom),
      builder: (_, dSnap) => StreamBuilder<List<SubmissionModel>>(
        stream: EtudiantService.submissionsStream(),
        builder: (_, sSnap) {
          if (dSnap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF6C47FF)));
          }
          final devoirs = dSnap.data ?? [];
          final subs = sSnap.data ?? [];
          final submittedIds = subs.map((s) => s.assignmentId).toSet();
          final now = DateTime.now();

          final aFaire = devoirs
              .where((d) => !submittedIds.contains(d.id) && (d.dateLimite == null || !d.dateLimite!.isBefore(now)))
              .toList()
            ..sort((a, b) {
              if (a.dateLimite == null && b.dateLimite == null) return 0;
              if (a.dateLimite == null) return 1;
              if (b.dateLimite == null) return -1;
              return a.dateLimite!.compareTo(b.dateLimite!);
            });

          final rendus = devoirs
              .where((d) => submittedIds.contains(d.id))
              .toList()
            ..sort((a, b) {
              if (a.dateLimite == null && b.dateLimite == null) return 0;
              if (a.dateLimite == null) return 1;
              if (b.dateLimite == null) return -1;
              return b.dateLimite!.compareTo(a.dateLimite!);
            });

          final enRetard = devoirs
              .where((d) => !submittedIds.contains(d.id) && d.dateLimite != null && d.dateLimite!.isBefore(now))
              .toList()
            ..sort((a, b) => b.dateLimite!.compareTo(a.dateLimite!));

          return Column(
            children: [
              _SummaryBar(aFaire: aFaire.length, rendus: rendus.length, enRetard: enRetard.length),
              Expanded(
                child: TabBarView(
                  controller: tabController,
                  children: [
                    _DevoirsList(devoirs: aFaire, statut: _Statut.aFaire, user: user, subs: subs),
                    _DevoirsList(devoirs: rendus, statut: _Statut.rendu, user: user, subs: subs),
                    _DevoirsList(devoirs: enRetard, statut: _Statut.enRetard, user: user, subs: subs),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ── Barre résumé ──────────────────────────────────────────────────────────────

class _SummaryBar extends StatelessWidget {
  final int aFaire;
  final int rendus;
  final int enRetard;
  const _SummaryBar({required this.aFaire, required this.rendus, required this.enRetard});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF161B22),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Row(
        children: [
          _SummaryChip(label: 'À faire', count: aFaire, color: _kColors.first),
          const SizedBox(width: 8),
          _SummaryChip(label: 'Rendus', count: rendus, color: const Color(0xFF16A34A)),
          const SizedBox(width: 8),
          _SummaryChip(label: 'En retard', count: enRetard, color: const Color(0xFFDC2626)),
        ],
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  const _SummaryChip({required this.label, required this.count, required this.color});

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

// ── Liste devoirs ─────────────────────────────────────────────────────────────

enum _Statut { aFaire, rendu, enRetard }

class _DevoirsList extends StatelessWidget {
  final List<DevoirModel> devoirs;
  final _Statut statut;
  final UserModel user;
  final List<SubmissionModel> subs;
  const _DevoirsList({required this.devoirs, required this.statut, required this.user, required this.subs});

  @override
  Widget build(BuildContext context) {
    if (devoirs.isEmpty) return _emptyView(statut);
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      itemCount: devoirs.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) => _DevoirTile(
        devoir: devoirs[i],
        statut: statut,
        user: user,
        submission: subs.where((s) => s.assignmentId == devoirs[i].id).firstOrNull,
      ),
    );
  }

  Widget _emptyView(_Statut s) {
    final (icon, msg) = switch (s) {
      _Statut.aFaire   => (Icons.assignment_outlined, 'Aucun devoir à faire'),
      _Statut.rendu    => (Icons.assignment_turned_in_outlined, 'Aucun devoir rendu'),
      _Statut.enRetard => (Icons.assignment_late_outlined, 'Aucun devoir en retard'),
    };
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white24, size: 48),
          const SizedBox(height: 12),
          Text(msg, style: const TextStyle(color: Colors.white38)),
        ],
      ),
    );
  }
}

// ── Tuile devoir ──────────────────────────────────────────────────────────────

class _DevoirTile extends StatelessWidget {
  final DevoirModel devoir;
  final _Statut statut;
  final UserModel user;
  final SubmissionModel? submission;
  const _DevoirTile({required this.devoir, required this.statut, required this.user, this.submission});

  bool get _isUrgent {
    final dl = devoir.dateLimite;
    if (dl == null) return false;
    return dl.difference(DateTime.now()).inDays <= 2;
  }

  Color get _iconColor => switch (statut) {
    _Statut.rendu    => const Color(0xFF16A34A),
    _Statut.enRetard => const Color(0xFFDC2626),
    _Statut.aFaire   => _isUrgent ? Colors.orange : _kColors.first,
  };

  IconData get _icon => switch (statut) {
    _Statut.rendu    => Icons.check_circle_outline,
    _Statut.enRetard => Icons.assignment_late_outlined,
    _Statut.aFaire   => Icons.assignment_outlined,
  };

  String get _statusLabel => switch (statut) {
    _Statut.rendu    => 'Rendu',
    _Statut.enRetard => 'En retard',
    _Statut.aFaire   => _isUrgent ? 'Urgent' : 'À faire',
  };

  Color get _borderColor => switch (statut) {
    _Statut.rendu    => const Color(0xFF16A34A).withValues(alpha: 0.3),
    _Statut.enRetard => const Color(0xFFDC2626).withValues(alpha: 0.3),
    _Statut.aFaire   => _isUrgent ? Colors.orange.withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.05),
  };

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: statut != _Statut.rendu ? () => Navigator.pushNamed(context, '/etudiant_faire_devoir', arguments: {
        'devoirId': devoir.id,
        'classeNom': user.classeNom ?? '',
      }) : null,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF161B22),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _borderColor),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(color: _iconColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
              child: Icon(_icon, color: _iconColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(devoir.titre,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
                  const SizedBox(height: 3),
                  Text(devoir.matiere, style: const TextStyle(color: Colors.white38, fontSize: 12)),
                  if (devoir.description.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(devoir.description,
                        style: const TextStyle(color: Colors.white54, fontSize: 12),
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                  ],
                  if (devoir.dateLimite != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today_outlined, size: 11, color: _iconColor),
                          const SizedBox(width: 4),
                          Text('Limite : ${_fmt(devoir.dateLimite!)}',
                              style: TextStyle(color: _iconColor, fontSize: 11)),
                        ],
                      ),
                    ),
                  if (submission != null) ...[
                    const SizedBox(height: 4),
                    Text('Rendu le ${_fmt(submission!.createdAt)}',
                        style: const TextStyle(color: Colors.white38, fontSize: 11)),
                  ],
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _StatusBadge(label: _statusLabel, color: _iconColor),
                if (statut != _Statut.rendu) ...[
                  const SizedBox(height: 6),
                  const Icon(Icons.chevron_right, color: Colors.white24, size: 16),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}
