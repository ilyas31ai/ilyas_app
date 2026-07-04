import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/classe_model.dart';
import '../models/devoir_model.dart';
import '../models/submission_model.dart';
import '../models/user_model.dart';
import '../services/ai_revision_service.dart';
import '../services/maitrise_service.dart';
import '../services/professeur_service.dart';
import 'professeur_creer_devoir_page.dart';

class ProfesseurDevoirsPage extends StatefulWidget {
  const ProfesseurDevoirsPage({super.key});

  @override
  State<ProfesseurDevoirsPage> createState() => _ProfesseurDevoirsPageState();
}

class _ProfesseurDevoirsPageState extends State<ProfesseurDevoirsPage> {
  int _filter = 0; // 0=tous, 1=à rendre, 2=expirés

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        elevation: 0,
        title: const Text('Devoirs',
            style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold)),
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            heroTag: 'fab_interactif',
            backgroundColor: const Color(0xFF0F766E),
            onPressed: () => _showCreerInteractifDialog(context),
            icon: const Icon(Icons.edit_note, color: Colors.white),
            label: const Text('Interactif',
                style: TextStyle(color: Colors.white)),
          ),
          const SizedBox(height: 10),
          FloatingActionButton.extended(
            heroTag: 'fab_pdf',
            backgroundColor: const Color(0xFF6C47FF),
            onPressed: () => _showCreerDevoirComplet(context),
            icon: const Icon(Icons.assignment_outlined, color: Colors.white),
            label: const Text('Nouveau devoir',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: StreamBuilder<List<DevoirModel>>(
        stream: ProfesseurService.devoirsStream(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: Color(0xFF6C47FF)));
          }
          final now = DateTime.now();
          var devoirs = snap.data ?? [];
          // Filter
          if (_filter == 1) {
            devoirs = devoirs.where((d) =>
                d.dateLimite == null || d.dateLimite!.isAfter(now)).toList();
          } else if (_filter == 2) {
            devoirs = devoirs.where((d) =>
                d.dateLimite != null && d.dateLimite!.isBefore(now)).toList();
          }
          if (devoirs.isEmpty && snap.data?.isEmpty == true) {
            return _emptyState(context);
          }
          return Column(
            children: [
              // Filter chips
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(children: [
                    _FilterChip(
                        label: 'Tous',
                        selected: _filter == 0,
                        onTap: () => setState(() => _filter = 0)),
                    const SizedBox(width: 8),
                    _FilterChip(
                        label: 'En cours',
                        selected: _filter == 1,
                        onTap: () => setState(() => _filter = 1)),
                    const SizedBox(width: 8),
                    _FilterChip(
                        label: 'Expirés',
                        selected: _filter == 2,
                        onTap: () => setState(() => _filter = 2)),
                  ]),
                ),
              ),
              Expanded(
                child: devoirs.isEmpty
                    ? const Center(
                        child: Text('Aucun devoir dans ce filtre.',
                            style: TextStyle(color: Colors.white38)))
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                        itemCount: devoirs.length,
                        itemBuilder: (ctx, i) => _DevoirCard(
                          devoir: devoirs[i],
                          onDelete: () => _confirmDelete(ctx, devoirs[i]),
                          onEdit: () =>
                              _showCreerDevoirComplet(ctx, existing: devoirs[i]),
                          onSoumissions: () =>
                              _showSoumissionsSheet(ctx, devoirs[i]),
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _emptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.assignment_outlined,
              color: Colors.white24, size: 56),
          const SizedBox(height: 16),
          const Text('Aucun devoir envoyé',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          const Text('Envoyez votre premier devoir',
              style: TextStyle(color: Colors.white38, fontSize: 13)),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C47FF),
                foregroundColor: Colors.white),
            icon: const Icon(Icons.send_outlined),
            label: const Text('Envoyer un devoir'),
            onPressed: () => _showSendDialog(context),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, DevoirModel devoir) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161B22),
        title: const Text('Supprimer le devoir',
            style: TextStyle(color: Colors.white)),
        content: Text('Supprimer « ${devoir.titre} » ?',
            style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler',
                  style: TextStyle(color: Colors.white38))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Supprimer',
                  style: TextStyle(color: Color(0xFFDC2626)))),
        ],
      ),
    );
    if (ok == true) await ProfesseurService.deleteDevoir(devoir.id);
  }

  Future<void> _showCreerInteractifDialog(BuildContext context) async {
    // Load classes first, then let the professor pick one
    final classes = await ProfesseurService.classesStream().first;
    if (!context.mounted) return;

    ClasseModel? selected;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          backgroundColor: const Color(0xFF161B22),
          title: const Text('Choisir une classe',
              style: TextStyle(color: Colors.white)),
          content: classes.isEmpty
              ? const Text('Aucune classe disponible.',
                  style: TextStyle(color: Colors.white70))
              : DropdownButtonFormField<ClasseModel>(
                  dropdownColor: const Color(0xFF161B22),
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Classe',
                    labelStyle: TextStyle(color: Colors.white38),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Color(0x26FFFFFF)),
                    ),
                  ),
                  items: classes
                      .map((c) => DropdownMenuItem(
                            value: c,
                            child: Text(c.nom,
                                style:
                                    const TextStyle(color: Colors.white)),
                          ))
                      .toList(),
                  onChanged: (c) => setSt(() => selected = c),
                ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Annuler',
                    style: TextStyle(color: Colors.white38))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F766E)),
              onPressed: selected == null
                  ? null
                  : () => Navigator.pop(ctx),
              child: const Text('Continuer',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );

    if (selected == null || !context.mounted) return;

    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ProfesseurCreerDevoirPage(
          classeId: selected!.id,
          classeNom: selected!.nom,
          categorie: selected!.niveau,
        ),
      ),
    );
    if (result == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Devoir interactif publié !'),
      ));
    }
  }

  Future<void> _showSendDialog(BuildContext context) async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF161B22),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _DevoirForm(),
    );
  }

  Future<void> _showCreerDevoirComplet(BuildContext context,
      {DevoirModel? existing}) async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF161B22),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _DevoirFormComplet(existing: existing),
    );
  }

  void _showSoumissionsSheet(BuildContext context, DevoirModel devoir) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0D1117),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _SoumissionsSheet(devoir: devoir),
    );
  }
}

// ─── Carte devoir ─────────────────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF6C47FF)
              : Colors.white.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label,
            style: TextStyle(
                color: selected ? Colors.white : Colors.white54,
                fontWeight:
                    selected ? FontWeight.bold : FontWeight.normal,
                fontSize: 12)),
      ),
    );
  }
}

class _DevoirCard extends StatelessWidget {
  final DevoirModel devoir;
  final VoidCallback onDelete;
  final VoidCallback onEdit;
  final VoidCallback onSoumissions;

  const _DevoirCard({
    required this.devoir,
    required this.onDelete,
    required this.onEdit,
    required this.onSoumissions,
  });

  @override
  Widget build(BuildContext context) {
    final limit = devoir.dateLimite;
    final isLate =
        limit != null && limit.isBefore(DateTime.now());
    return Dismissible(
      key: Key(devoir.id),
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
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF161B22),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [Color(0xFF6C47FF), Color(0xFF2563EB)]),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.assignment_outlined,
                      color: Colors.white, size: 19),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(devoir.titre,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 14),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      Text('${devoir.classeNom} · ${devoir.matiere}',
                          style: const TextStyle(
                              color: Colors.white38, fontSize: 12)),
                    ],
                  ),
                ),
                if (devoir.aFichier)
                  const Icon(Icons.attach_file,
                      color: Colors.white24, size: 16),
              ],
            ),
            if (devoir.description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(devoir.description,
                  style: const TextStyle(
                      color: Colors.white60, fontSize: 12),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
            ],
            if (limit != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.schedule,
                    color: isLate
                        ? const Color(0xFFDC2626)
                        : const Color(0xFF15803D),
                    size: 14,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Limite : ${_fmt(limit)}',
                    style: TextStyle(
                      color: isLate
                          ? const Color(0xFFDC2626)
                          : const Color(0xFF15803D),
                      fontSize: 12,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Sur ${devoir.bareme} pts',
                    style: const TextStyle(
                        color: Colors.white38, fontSize: 11),
                  ),
                ],
              ),
            ],
            // Action bar
            const SizedBox(height: 10),
            Row(children: [
              if (devoir.classeNom.isNotEmpty && devoir.matiere.isNotEmpty)
                _ActionBtn(
                  icon: Icons.analytics_outlined,
                  label: 'Suivi IA',
                  color: const Color(0xFF0891B2),
                  onTap: () => _showTracabiliteSheet(context),
                ),
              const SizedBox(width: 6),
              _ActionBtn(
                icon: Icons.rate_review_outlined,
                label: 'Corrections',
                color: const Color(0xFF16A34A),
                onTap: onSoumissions,
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.edit_outlined,
                    color: Colors.white38, size: 18),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: onEdit,
                tooltip: 'Modifier',
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.delete_outline,
                    color: Color(0xFFDC2626), size: 18),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: onDelete,
                tooltip: 'Supprimer',
              ),
            ]),
          ],
        ),
      ),
    );
  }

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  void _showTracabiliteSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0D1117),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _TracabiliteSheet(devoir: devoir),
    );
  }
}

// ─── Feuille de traçabilité complète ─────────────────────────────────────────

class _TracabiliteSheet extends StatefulWidget {
  final DevoirModel devoir;
  const _TracabiliteSheet({required this.devoir});
  @override
  State<_TracabiliteSheet> createState() => _TracabiliteSheetState();
}

class _TracabiliteSheetState extends State<_TracabiliteSheet> {
  bool _loading = true;
  List<UserModel> _eleves = [];
  // uid → stats matière du devoir
  Map<String, Map<String, dynamic>> _statsPar = {};
  String? _recommandations;
  bool _loadingReco = false;

  // ── Soumissions ──────────────────────────────────────────────────────────
  // uid → true si l'élève a soumis ce devoir
  Map<String, bool> _aSubmis = {};

  // ── Analyse IA du devoir ─────────────────────────────────────────────────
  Map<String, String> _analyse = {};
  bool _loadingAnalyse = false;

  // ── Timeline avant/après ─────────────────────────────────────────────────
  // notion → {avantMoy, apresMoy}
  List<_NotionDelta> _timeline = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final eleves = await ProfesseurService.elevesMaitriseStream(
              widget.devoir.classeNom)
          .first;
      final Map<String, Map<String, dynamic>> stats = {};
      for (final e in eleves) {
        final summary    = await MaitriseService.summaryForUser(e.uid);
        final parMatiere = (summary['parMatiere'] as Map<String, dynamic>?) ?? {};
        final mData =
            (parMatiere[widget.devoir.matiere] as Map<String, dynamic>?) ?? {};
        stats[e.uid] = mData;
      }

      // ── Soumissions ─────────────────────────────────────────────────────
      final Map<String, bool> aSubmis = {for (final e in eleves) e.uid: false};
      try {
        final db = FirebaseFirestore.instance;
        if (widget.devoir.estInteractif) {
          // copies interactives
          final snap = await db
              .collection('copies')
              .where('devoirId', isEqualTo: widget.devoir.id)
              .get();
          for (final d in snap.docs) {
            final uid = d.data()['eleveId'] as String? ?? '';
            if (uid.isNotEmpty) aSubmis[uid] = true;
          }
        } else {
          // PDF submissions
          final snap = await db
              .collection('submissions')
              .where('assignmentId', isEqualTo: widget.devoir.id)
              .get();
          for (final d in snap.docs) {
            final uid = d.data()['studentId'] as String? ?? '';
            if (uid.isNotEmpty) aSubmis[uid] = true;
          }
        }
      } catch (_) { /* best-effort */ }

      if (mounted) {
        setState(() {
          _eleves   = eleves;
          _statsPar = stats;
          _aSubmis  = aSubmis;
          _loading  = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Analyse IA + timeline ────────────────────────────────────────────────

  Future<void> _chargerAnalyse() async {
    if (_loadingAnalyse) return;
    setState(() => _loadingAnalyse = true);
    try {
      final analyse = await AiRevisionService.analyserDevoir(widget.devoir);
      final notionsStr = analyse['notions'] ?? '';
      final notionIds = notionsStr
          .split(',')
          .map((s) => s.trim().toLowerCase().replaceAll(' ', '_'))
          .where((s) => s.isNotEmpty)
          .toList();

      // Timeline avant/après dateEnvoi
      final deltas = await _computeTimeline(notionIds, notionsStr);

      if (mounted) {
        setState(() {
          _analyse         = analyse;
          _timeline        = deltas;
          _loadingAnalyse  = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingAnalyse = false);
    }
  }

  Future<List<_NotionDelta>> _computeTimeline(
      List<String> notionIds, String notionsStr) async {
    if (_eleves.isEmpty || widget.devoir.dateEnvoi.isAfter(DateTime.now())) {
      return [];
    }
    final db = FirebaseFirestore.instance;
    final dateRef = widget.devoir.dateEnvoi;

    // notion label → [scores_avant], [scores_apres]
    final Map<String, List<int>> avants = {};
    final Map<String, List<int>> apres  = {};

    final labels = notionsStr
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    for (final e in _eleves) {
      try {
        // Lire toutes les notions de cet élève pour la matière du devoir
        final snap = await db
            .collection('users')
            .doc(e.uid)
            .collection('maitrise')
            .where('matiere', isEqualTo: widget.devoir.matiere)
            .get();

        for (final doc in snap.docs) {
          final data = doc.data();
          final label = (data['label'] as String?) ?? doc.id;
          // Match approximatif : si l'un des labels IA est contenu dans le label notion
          final isRelevant = labels.any((l) =>
              label.toLowerCase().contains(l.toLowerCase()) ||
              l.toLowerCase().contains(label.toLowerCase()));
          if (!isRelevant) continue;

          final hist = List<Map<String, dynamic>>.from(
              data['historiqueScores'] as List? ?? []);
          for (final h in hist) {
            final ts = h['ts'] as String? ?? '';
            final score = (h['score'] as num?)?.toInt() ?? -1;
            if (score < 0) continue;
            final date = DateTime.tryParse(ts);
            if (date == null) continue;

            if (date.isBefore(dateRef)) {
              (avants[label] ??= []).add(score);
            } else {
              (apres[label] ??= []).add(score);
            }
          }
        }
      } catch (_) {}
    }

    final result = <_NotionDelta>[];
    final allLabels = {...avants.keys, ...apres.keys};
    for (final lbl in allLabels) {
      final av = avants[lbl];
      final ap = apres[lbl];
      if (av == null && ap == null) continue;
      final avMoy = av != null ? av.reduce((a, b) => a + b) / av.length : null;
      final apMoy = ap != null ? ap.reduce((a, b) => a + b) / ap.length : null;
      result.add(_NotionDelta(label: lbl, avant: avMoy, apres: apMoy));
    }
    result.sort((a, b) {
      final da = (a.apres ?? 0) - (a.avant ?? 0);
      final db = (b.apres ?? 0) - (b.avant ?? 0);
      return db.compareTo(da);
    });
    return result;
  }

  Future<void> _genererReco() async {
    setState(() { _loadingReco = true; _recommandations = null; });
    final statsEleves = _eleves.map((e) {
      final s = _statsPar[e.uid] ?? {};
      return {
        'nom'          : e.displayName,
        'total'        : (s['total']         as int?) ?? 0,
        'maitrise'     : (s['maitrise']      as int?) ?? 0,
        'enCours'      : (s['enCours']       as int?) ?? 0,
        'aRetravailler': (s['aRetravailler'] as int?) ?? 0,
        'alertes'      : (s['alertes']       as List?) ?? [],
      };
    }).toList();
    final reco = await AiRevisionService.genererRecommandationsProfesseur(
      matiere    : widget.devoir.matiere,
      classeNom  : widget.devoir.classeNom,
      statsEleves: statsEleves,
    );
    if (mounted) setState(() { _recommandations = reco; _loadingReco = false; });
  }

  // Statistiques de classe
  int get _nbActifs =>
      _eleves.where((e) => (_statsPar[e.uid] ?? {}).isNotEmpty).length;

  double? get _scoreMoyen {
    final actifs = _eleves.where((e) => (_statsPar[e.uid] ?? {}).isNotEmpty);
    if (actifs.isEmpty) return null;
    int total = 0, count = 0;
    for (final e in actifs) {
      final s = _statsPar[e.uid]!;
      final m = ((s['maitrise'] as int? ?? 0) * 100 +
                 (s['enCours']  as int? ?? 0) * 60 +
                 (s['aRetravailler'] as int? ?? 0) * 20);
      final t = (s['total'] as int? ?? 0);
      if (t > 0) { total += m ~/ t; count++; }
    }
    return count == 0 ? null : total / count;
  }

  // Notions en difficulté agrégées (toutes erreurs de la classe)
  List<String> get _notionsClasse {
    final Map<String, int> counts = {};
    for (final e in _eleves) {
      final s = _statsPar[e.uid] ?? {};
      final al = (s['alertes'] as List?) ?? [];
      for (final a in al) {
        final key = a.toString().split(' (').first.trim();
        counts[key] = (counts[key] ?? 0) + 1;
      }
    }
    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(5).map((e) => '${e.key} (${e.value} élève${e.value > 1 ? 's' : ''})').toList();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (_, ctrl) => Column(
        children: [
          // Header fixe
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            decoration: const BoxDecoration(
              color: Color(0xFF161B22),
              borderRadius:
                  BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(children: [
                  Container(
                    width: 38, height: 38,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [Color(0xFF0891B2), Color(0xFF0F766E)]),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.analytics_outlined,
                        color: Colors.white, size: 19),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.devoir.titre,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        Text(
                          '${widget.devoir.matiere} · ${widget.devoir.classeNom}',
                          style: const TextStyle(
                              color: Colors.white38, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ]),
              ],
            ),
          ),
          const Divider(height: 1, color: Colors.white12),
          // Corps scrollable
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(
                        color: Color(0xFF0891B2)))
                : ListView(
                    controller: ctrl,
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                    children: [
                      _buildStats(),
                      const SizedBox(height: 16),
                      _buildSoumissions(),
                      const SizedBox(height: 16),
                      _buildElevesList(),
                      if (_notionsClasse.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _buildNotionsClasse(),
                      ],
                      const SizedBox(height: 16),
                      _buildAnalyseDevoir(),
                      if (_timeline.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _buildTimeline(),
                      ],
                      const SizedBox(height: 16),
                      _buildRecoSection(),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  // ── Soumissions ────────────────────────────────────────────────────────────

  Widget _buildSoumissions() {
    final total   = _eleves.length;
    final nbSubmis = _aSubmis.values.where((v) => v).length;
    final nonSubmis = _eleves.where((e) => !(_aSubmis[e.uid] ?? false)).toList();
    final pct = total == 0 ? 0 : (nbSubmis * 100 ~/ total);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('SOUMISSIONS',
            style: TextStyle(
                color: Colors.white38,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF161B22),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Text(
                  '$nbSubmis / $total',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 8),
                Text('rendus ($pct%)',
                    style: const TextStyle(color: Colors.white54, fontSize: 13)),
                const Spacer(),
                Icon(
                  widget.devoir.estInteractif
                      ? Icons.quiz_outlined
                      : Icons.picture_as_pdf_outlined,
                  color: Colors.white38,
                  size: 18,
                ),
              ]),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: total > 0 ? nbSubmis / total : 0,
                  backgroundColor: Colors.white10,
                  color: nbSubmis == total
                      ? Colors.green
                      : nbSubmis > total ~/ 2
                          ? Colors.orange
                          : Colors.red,
                  minHeight: 6,
                ),
              ),
              if (nonSubmis.isNotEmpty) ...[
                const SizedBox(height: 10),
                const Text('N\'ont pas rendu :',
                    style: TextStyle(color: Colors.white38, fontSize: 11)),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: nonSubmis
                      .map((e) => Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: Colors.red.withValues(alpha: 0.25)),
                            ),
                            child: Text(e.displayName,
                                style: const TextStyle(
                                    color: Colors.red, fontSize: 11)),
                          ))
                      .toList(),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // ── Analyse IA du devoir ───────────────────────────────────────────────────

  Widget _buildAnalyseDevoir() {
    if (_analyse.isEmpty && !_loadingAnalyse) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('ANALYSE DU DEVOIR',
              style: TextStyle(
                  color: Colors.white38,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2)),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF0891B2),
                side: const BorderSide(color: Color(0xFF0891B2)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              icon: const Icon(Icons.auto_awesome, size: 16),
              label: const Text('Analyser les notions du devoir',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              onPressed: _chargerAnalyse,
            ),
          ),
        ],
      );
    }

    if (_loadingAnalyse) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: CircularProgressIndicator(color: Color(0xFF0891B2)),
        ),
      );
    }

    final notions = _analyse['notions'] ?? '';
    final competences = _analyse['competences'] ?? '';
    final difficulte = _analyse['difficulte'] ?? '';
    final chapitre = _analyse['chapitre'] ?? '';
    final conseils = _analyse['conseils'] ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('ANALYSE DU DEVOIR',
                style: TextStyle(
                    color: Colors.white38,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2)),
            const Spacer(),
            GestureDetector(
              onTap: _chargerAnalyse,
              child: const Icon(Icons.refresh, color: Colors.white24, size: 14),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF0C2035),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: const Color(0xFF0891B2).withValues(alpha: 0.25)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (chapitre.isNotEmpty && chapitre != 'À identifier') ...[
                _AnalyseRow(icon: Icons.book_outlined, label: 'Chapitre', value: chapitre),
                const SizedBox(height: 6),
              ],
              _AnalyseRow(icon: Icons.lightbulb_outline, label: 'Notions', value: notions),
              if (competences.isNotEmpty) ...[
                const SizedBox(height: 6),
                _AnalyseRow(
                    icon: Icons.stars_outlined,
                    label: 'Compétences',
                    value: competences),
              ],
              if (difficulte.isNotEmpty) ...[
                const SizedBox(height: 6),
                _AnalyseRow(
                    icon: Icons.speed_outlined,
                    label: 'Difficulté',
                    value: difficulte,
                    valueColor: difficulte == 'Avancé'
                        ? Colors.red
                        : difficulte == 'Facile'
                            ? Colors.green
                            : Colors.orange),
              ],
              if (conseils.isNotEmpty) ...[
                const SizedBox(height: 8),
                const Divider(color: Colors.white10),
                const SizedBox(height: 4),
                Text(conseils,
                    style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                        fontStyle: FontStyle.italic)),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // ── Timeline avant/après ───────────────────────────────────────────────────

  Widget _buildTimeline() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('PROGRESSION AVANT / APRÈS CE DEVOIR',
            style: TextStyle(
                color: Colors.white38,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF161B22),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          ),
          child: Column(
            children: [
              // En-tête
              const Row(
                children: [
                  Expanded(
                      flex: 3,
                      child: Text('Notion',
                          style: TextStyle(
                              color: Colors.white38,
                              fontSize: 10,
                              fontWeight: FontWeight.w700))),
                  SizedBox(
                      width: 48,
                      child: Text('Avant',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: Colors.white38,
                              fontSize: 10,
                              fontWeight: FontWeight.w700))),
                  SizedBox(
                      width: 48,
                      child: Text('Après',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: Colors.white38,
                              fontSize: 10,
                              fontWeight: FontWeight.w700))),
                  SizedBox(
                      width: 40,
                      child: Text('Δ',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: Colors.white38,
                              fontSize: 10,
                              fontWeight: FontWeight.w700))),
                ],
              ),
              const Divider(color: Colors.white10),
              ..._timeline.map((d) {
                final delta = d.apres != null && d.avant != null
                    ? d.apres! - d.avant!
                    : null;
                final deltaColor = delta == null
                    ? Colors.white38
                    : delta > 5
                        ? Colors.green
                        : delta < -5
                            ? Colors.red
                            : Colors.orange;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Text(d.label,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ),
                      SizedBox(
                        width: 48,
                        child: Text(
                          d.avant != null ? '${d.avant!.round()}%' : '–',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: Colors.white54, fontSize: 12),
                        ),
                      ),
                      SizedBox(
                        width: 48,
                        child: Text(
                          d.apres != null ? '${d.apres!.round()}%' : '–',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 12),
                        ),
                      ),
                      SizedBox(
                        width: 40,
                        child: Text(
                          delta == null
                              ? '–'
                              : '${delta >= 0 ? '+' : ''}${delta.round()}',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: deltaColor,
                              fontSize: 12,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                );
              }),
              if (_timeline.every((d) => d.avant == null)) ...[
                const SizedBox(height: 4),
                const Text(
                  'Données insuffisantes avant ce devoir pour comparer.',
                  style: TextStyle(color: Colors.white38, fontSize: 11),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // ── Bannière statistiques de classe ────────────────────────────────────────

  Widget _buildStats() {
    final total  = _eleves.length;
    final actifs = _nbActifs;
    final score  = _scoreMoyen;
    final retrav = _eleves.where((e) {
      final s = _statsPar[e.uid] ?? {};
      return (s['aRetravailler'] as int? ?? 0) > 0;
    }).length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0C2A40), Color(0xFF0F2535)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border:
            Border.all(color: const Color(0xFF0891B2).withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('STATISTIQUES DE CLASSE',
              style: TextStyle(
                  color: Color(0xFF0891B2),
                  fontSize: 10, fontWeight: FontWeight.w700,
                  letterSpacing: 1.2)),
          const SizedBox(height: 12),
          Row(children: [
            _StatBadge(
                value: '$actifs/$total',
                label: 'ont révisé',
                color: const Color(0xFF0891B2)),
            const SizedBox(width: 12),
            _StatBadge(
                value: '$retrav',
                label: 'en difficulté',
                color: const Color(0xFFDC2626)),
            const SizedBox(width: 12),
            if (score != null)
              _StatBadge(
                  value: '${score.round()}%',
                  label: 'score IA moy.',
                  color: score >= 60
                      ? const Color(0xFF16A34A)
                      : const Color(0xFFD97706)),
          ]),
        ],
      ),
    );
  }

  // ── Liste des élèves ───────────────────────────────────────────────────────

  Widget _buildElevesList() {
    if (_eleves.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF161B22),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: const Center(
          child: Text(
            'Aucun élève de cette classe n\'utilise encore\nles révisions IA.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white38, fontSize: 13),
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('ÉLÈVES',
            style: TextStyle(
                color: Colors.white38, fontSize: 10,
                fontWeight: FontWeight.w700, letterSpacing: 1.2)),
        const SizedBox(height: 8),
        ..._eleves.map((e) {
          final s = _statsPar[e.uid] ?? {};
          final hasData  = s.isNotEmpty;
          final mait     = (s['maitrise']      as int?) ?? 0;
          final enCours  = (s['enCours']       as int?) ?? 0;
          final aRetrav  = (s['aRetravailler'] as int?) ?? 0;
          final total    = (s['total']         as int?) ?? 0;
          final alertes  = (s['alertes']       as List?) ?? [];

          final emoji = !hasData
              ? '⚪'
              : aRetrav > 0
                  ? '🔴'
                  : enCours > 0
                      ? '🟡'
                      : '🟢';

          return Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF161B22),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: Colors.white.withValues(alpha: 0.05)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text(emoji,
                      style: const TextStyle(fontSize: 16)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(e.displayName,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 13)),
                  ),
                  if (hasData)
                    Text('🟢$mait 🟡$enCours 🔴$aRetrav / $total',
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 11))
                  else
                    const Text('Pas encore révisé',
                        style: TextStyle(
                            color: Colors.white24, fontSize: 11)),
                ]),
                if (alertes.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  ...alertes.take(2).map((a) => Padding(
                    padding: const EdgeInsets.only(top: 2, left: 26),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.warning_amber_outlined,
                            color: Color(0xFFDC2626), size: 10),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(a.toString(),
                              style: const TextStyle(
                                  color: Color(0xFFDC2626),
                                  fontSize: 10, height: 1.3)),
                        ),
                      ],
                    ),
                  )),
                ],
              ],
            ),
          );
        }),
      ],
    );
  }

  // ── Notions de classe en difficulté ───────────────────────────────────────

  Widget _buildNotionsClasse() {
    final notions = _notionsClasse;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('NOTIONS À REPRENDRE EN CLASSE',
            style: TextStyle(
                color: Colors.white38, fontSize: 10,
                fontWeight: FontWeight.w700, letterSpacing: 1.2)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF1A0F0F),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: const Color(0xFFDC2626).withValues(alpha: 0.25)),
          ),
          child: Column(
            children: notions.map((n) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(children: [
                const Icon(Icons.circle, color: Color(0xFFDC2626), size: 6),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(n,
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 12)),
                ),
              ]),
            )).toList(),
          ),
        ),
      ],
    );
  }

  // ── Recommandations IA ─────────────────────────────────────────────────────

  Widget _buildRecoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('RECOMMANDATIONS IA',
            style: TextStyle(
                color: Colors.white38, fontSize: 10,
                fontWeight: FontWeight.w700, letterSpacing: 1.2)),
        const SizedBox(height: 8),
        if (_recommandations == null && !_loadingReco)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F766E),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              icon: const Icon(Icons.auto_awesome, size: 16),
              label: const Text('Générer les recommandations',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              onPressed: _genererReco,
            ),
          )
        else if (_loadingReco)
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: CircularProgressIndicator(
                  color: Color(0xFF0F766E)),
            ),
          )
        else if (_recommandations != null)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF0A1F1A),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: const Color(0xFF0F766E).withValues(alpha: 0.3)),
            ),
            child: SelectableText(
              _recommandations!,
              style: const TextStyle(
                  color: Colors.white, fontSize: 13, height: 1.5),
            ),
          ),
      ],
    );
  }
}

class _StatBadge extends StatelessWidget {
  final String value, label;
  final Color color;
  const _StatBadge(
      {required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(value,
          style: TextStyle(
              color: color, fontSize: 22, fontWeight: FontWeight.bold)),
      Text(label,
          style: const TextStyle(color: Colors.white38, fontSize: 10)),
    ],
  );
}

// ─── Data class pour timeline ─────────────────────────────────────────────────

class _NotionDelta {
  final String label;
  final double? avant;
  final double? apres;
  const _NotionDelta({required this.label, this.avant, this.apres});
}

// ─── Widget ligne analyse ─────────────────────────────────────────────────────

class _AnalyseRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;
  const _AnalyseRow(
      {required this.icon,
      required this.label,
      required this.value,
      this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: const Color(0xFF0891B2), size: 14),
        const SizedBox(width: 6),
        SizedBox(
          width: 70,
          child: Text('$label :',
              style: const TextStyle(color: Colors.white38, fontSize: 12)),
        ),
        Expanded(
          child: Text(value,
              style: TextStyle(
                  color: valueColor ?? Colors.white70, fontSize: 12)),
        ),
      ],
    );
  }
}

// ─── Formulaire envoi devoir ──────────────────────────────────────────────────

class _DevoirForm extends StatefulWidget {
  @override
  State<_DevoirForm> createState() => _DevoirFormState();
}

class _DevoirFormState extends State<_DevoirForm> {
  final _titre = TextEditingController();
  final _desc = TextEditingController();
  final _matiere = TextEditingController();
  final _classeNom = TextEditingController();
  DateTime? _dateLimite;
  File? _fichier;
  String? _fichierNom;
  bool _saving = false;

  List<ClasseModel> _classes = [];

  @override
  void initState() {
    super.initState();
    ProfesseurService.classesStream()
        .first
        .then((c) { if (mounted) setState(() => _classes = c); });
  }

  @override
  void dispose() {
    for (final c in [_titre, _desc, _matiere, _classeNom]) c.dispose();
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
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Envoyer un devoir',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _Field(controller: _titre, label: 'Titre du devoir'),
            const SizedBox(height: 10),
            _Field(controller: _desc, label: 'Description (optionnel)', maxLines: 3),
            const SizedBox(height: 10),
            _Field(controller: _matiere, label: 'Matière'),
            const SizedBox(height: 10),
            if (_classes.isNotEmpty)
              DropdownButtonFormField<ClasseModel>(
                dropdownColor: const Color(0xFF161B22),
                style: const TextStyle(color: Colors.white),
                decoration: _inputDeco('Classe'),
                items: _classes
                    .map((c) => DropdownMenuItem(
                        value: c,
                        child: Text(c.nom,
                            style: const TextStyle(color: Colors.white))))
                    .toList(),
                onChanged: (c) {
                  if (c != null) _classeNom.text = c.nom;
                },
              )
            else
              _Field(controller: _classeNom, label: 'Classe (ex: 6ème A)'),
            const SizedBox(height: 10),
            // Date limite
            InkWell(
              onTap: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now().add(const Duration(days: 7)),
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                  builder: (ctx, child) => Theme(
                    data: Theme.of(ctx).copyWith(
                        colorScheme: const ColorScheme.dark(
                          primary: Color(0xFF6C47FF),
                          surface: Color(0xFF161B22),
                        )),
                    child: child!,
                  ),
                );
                if (d != null) setState(() => _dateLimite = d);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 14),
                decoration: BoxDecoration(
                  border: Border.all(
                      color: Colors.white.withValues(alpha: 0.15)),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.schedule,
                        color: Colors.white38, size: 18),
                    const SizedBox(width: 10),
                    Text(
                      _dateLimite != null
                          ? 'Limite : ${_dateLimite!.day.toString().padLeft(2, '0')}/${_dateLimite!.month.toString().padLeft(2, '0')}/${_dateLimite!.year}'
                          : 'Date limite (optionnel)',
                      style: TextStyle(
                          color: _dateLimite != null
                              ? Colors.white
                              : Colors.white38,
                          fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            // Fichier
            InkWell(
              onTap: _pickFile,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 14),
                decoration: BoxDecoration(
                  border: Border.all(
                      color: Colors.white.withValues(alpha: 0.15)),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.attach_file,
                        color: Colors.white38, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _fichierNom ?? 'Joindre un fichier (optionnel)',
                        style: TextStyle(
                            color: _fichierNom != null
                                ? Colors.white
                                : Colors.white38,
                            fontSize: 14),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6C47FF),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14)),
                onPressed: _saving ? null : _send,
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Text('Envoyer le devoir',
                        style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform
        .pickFiles(type: FileType.custom, allowedExtensions: ['pdf', 'jpg', 'png', 'jpeg']);
    if (result != null && result.files.single.path != null) {
      setState(() {
        _fichier = File(result.files.single.path!);
        _fichierNom = result.files.single.name;
      });
    }
  }

  Future<void> _send() async {
    if (_titre.text.trim().isEmpty || _matiere.text.trim().isEmpty ||
        _classeNom.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      await ProfesseurService.sendDevoir(
        titre: _titre.text.trim(),
        description: _desc.text.trim(),
        matiere: _matiere.text.trim(),
        classeId: '',
        classeNom: _classeNom.text.trim(),
        dateLimite: _dateLimite,
        fichier: _fichier,
        fichierNom: _fichierNom,
      );
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  InputDecoration _inputDeco(String label) => InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white38),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF6C47FF)),
        ),
      );
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionBtn(
      {required this.icon,
      required this.label,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final int maxLines;

  const _Field({required this.controller, required this.label, this.maxLines = 1});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
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
          borderSide: const BorderSide(color: Color(0xFF6C47FF)),
        ),
      ),
    );
  }
}

// ─── Formulaire complet de devoir (créer ou modifier) ────────────────────────

class _DevoirFormComplet extends StatefulWidget {
  final DevoirModel? existing;
  const _DevoirFormComplet({this.existing});

  @override
  State<_DevoirFormComplet> createState() => _DevoirFormCompletState();
}

class _DevoirFormCompletState extends State<_DevoirFormComplet> {
  late final TextEditingController _titre;
  late final TextEditingController _desc;
  late final TextEditingController _matiere;
  late final TextEditingController _baremeCtrl;

  ClasseModel? _selectedClasse;
  List<ClasseModel> _classes = [];
  DateTime? _dateLimite;
  DateTime? _datePub;
  bool _saving = false;

  // New attachments
  final List<File> _fichiers = [];
  final List<String> _nomsF = [];
  // Existing attachments (from edit)
  List<Map<String, String>> _existingPJ = [];

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _titre = TextEditingController(text: e?.titre ?? '');
    _desc = TextEditingController(text: e?.description ?? '');
    _matiere = TextEditingController(text: e?.matiere ?? '');
    _baremeCtrl = TextEditingController(text: (e?.bareme ?? 20).toString());
    _dateLimite = e?.dateLimite;
    _datePub = e?.datePublication;
    _existingPJ = List<Map<String, String>>.from(
        e?.tousLesAttachements ?? []);
    ProfesseurService.classesStream().first.then((c) {
      if (mounted) {
        setState(() {
          _classes = c;
          if (e != null) {
            _selectedClasse = c
                .where((cl) => cl.nom == e.classeNom)
                .firstOrNull;
          }
        });
      }
    });
  }

  @override
  void dispose() {
    for (final c in [_titre, _desc, _matiere, _baremeCtrl]) c.dispose();
    super.dispose();
  }

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowMultiple: true,
      allowedExtensions: [
        'pdf', 'jpg', 'jpeg', 'png', 'doc', 'docx',
        'xls', 'xlsx', 'ppt', 'pptx', 'txt'
      ],
    );
    if (result == null) return;
    for (final f in result.files) {
      if (f.path != null) {
        setState(() {
          _fichiers.add(File(f.path!));
          _nomsF.add(f.name);
        });
      }
    }
  }

  Future<void> _pickDate(bool isLimite) async {
    final d = await showDatePicker(
      context: context,
      initialDate:
          DateTime.now().add(Duration(days: isLimite ? 7 : 0)),
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF6C47FF),
              surface: Color(0xFF161B22),
            )),
        child: child!,
      ),
    );
    if (d != null) {
      setState(() {
        if (isLimite) _dateLimite = d;
        else _datePub = d;
      });
    }
  }

  Future<void> _save() async {
    if (_titre.text.trim().isEmpty ||
        _matiere.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      final bareme = int.tryParse(_baremeCtrl.text.trim()) ?? 20;
      final classeNom = _selectedClasse?.nom ?? '';
      final classeId = _selectedClasse?.id ?? '';
      if (widget.existing == null) {
        await ProfesseurService.sendDevoirComplet(
          titre: _titre.text.trim(),
          description: _desc.text.trim(),
          matiere: _matiere.text.trim(),
          classeId: classeId,
          classeNom: classeNom,
          bareme: bareme,
          dateLimite: _dateLimite,
          datePublication: _datePub,
          fichiers: _fichiers,
          nomsF: _nomsF,
        );
      } else {
        // Build updated piecesJointes: existing + new uploads
        final newPJ = <Map<String, String>>[];
        for (var i = 0; i < _fichiers.length; i++) {
          final nom = i < _nomsF.length ? _nomsF[i] : _fichiers[i].path.split('/').last;
          final url = await _uploadFile(_fichiers[i], nom);
          if (url != null) {
            final ext = nom.split('.').last.toLowerCase();
            newPJ.add({'url': url, 'nom': nom, 'type': ext});
          }
        }
        await ProfesseurService.updateDevoir(
          widget.existing!.id,
          {
            'titre': _titre.text.trim(),
            'description': _desc.text.trim(),
            'matiere': _matiere.text.trim(),
            if (classeNom.isNotEmpty) 'classeNom': classeNom,
            if (classeId.isNotEmpty) 'classeId': classeId,
            'bareme': bareme,
            if (_dateLimite != null)
              'dateLimite': Timestamp.fromDate(_dateLimite!),
            if (_datePub != null)
              'datePublication': Timestamp.fromDate(_datePub!),
            'piecesJointes': [..._existingPJ, ...newPJ],
          },
        );
      }
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<String?> _uploadFile(File file, String nom) async {
    try {
      final storage = FirebaseStorage.instanceFor(
          bucket: 'gs://ilyasapp-4762c.firebasestorage.app');
      const chars =
          'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
      final rng = Random.secure();
      final token =
          List.generate(36, (_) => chars[rng.nextInt(chars.length)]).join();
      final ts = DateTime.now().millisecondsSinceEpoch;
      final ref = storage.ref(
          'devoirs/${widget.existing!.id}/${ts}_$nom');
      final bytes = await file.readAsBytes();
      final snap = await ref.putData(bytes,
          SettableMetadata(
              customMetadata: {'firebaseStorageDownloadTokens': token}));
      if (snap.state == TaskState.success) {
        final bucket = snap.ref.bucket;
        final encoded = Uri.encodeComponent(snap.ref.fullPath);
        return 'https://firebasestorage.googleapis.com/v0/b/$bucket/o/$encoded?alt=media&token=$token';
      }
    } catch (_) {}
    return null;
  }

  InputDecoration _deco(String label) => InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white38),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:
              BorderSide(color: Colors.white.withValues(alpha: 0.15)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF6C47FF)),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          left: 16,
          right: 16,
          top: 16),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(isEdit ? 'Modifier le devoir' : 'Nouveau devoir',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _Field(controller: _titre, label: 'Titre *'),
            const SizedBox(height: 10),
            _Field(
                controller: _desc,
                label: 'Description (consignes)',
                maxLines: 4),
            const SizedBox(height: 10),
            _Field(controller: _matiere, label: 'Matière *'),
            const SizedBox(height: 10),
            // Classe selector
            if (_classes.isNotEmpty)
              DropdownButtonFormField<ClasseModel>(
                value: _selectedClasse,
                dropdownColor: const Color(0xFF161B22),
                style: const TextStyle(color: Colors.white),
                decoration: _deco('Classe'),
                items: _classes
                    .map((c) => DropdownMenuItem(
                        value: c,
                        child: Text(c.nom,
                            style:
                                const TextStyle(color: Colors.white))))
                    .toList(),
                onChanged: (c) => setState(() => _selectedClasse = c),
              ),
            const SizedBox(height: 10),
            // Barème
            TextField(
              controller: _baremeCtrl,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: _deco('Barème (sur N points)'),
            ),
            const SizedBox(height: 10),
            // Date limite
            _DatePickerRow(
              label: _dateLimite != null
                  ? 'Limite : ${DateFormat('dd/MM/yyyy').format(_dateLimite!)}'
                  : 'Date limite (optionnel)',
              icon: Icons.schedule_outlined,
              set: _dateLimite != null,
              onTap: () => _pickDate(true),
              onClear: () => setState(() => _dateLimite = null),
            ),
            const SizedBox(height: 8),
            // Date de publication
            _DatePickerRow(
              label: _datePub != null
                  ? 'Publication : ${DateFormat('dd/MM/yyyy').format(_datePub!)}'
                  : 'Date de publication (optionnel)',
              icon: Icons.publish_outlined,
              set: _datePub != null,
              onTap: () => _pickDate(false),
              onClear: () => setState(() => _datePub = null),
            ),
            const SizedBox(height: 10),
            // Existing attachments
            if (_existingPJ.isNotEmpty) ...[
              const Text('Pièces jointes existantes :',
                  style: TextStyle(color: Colors.white38, fontSize: 11)),
              const SizedBox(height: 4),
              Wrap(spacing: 6, runSpacing: 4, children: [
                ..._existingPJ.asMap().entries.map((e) =>
                    _PjChip(
                      nom: e.value['nom'] ?? 'Fichier',
                      onRemove: () => setState(
                          () => _existingPJ.removeAt(e.key)),
                    )),
              ]),
              const SizedBox(height: 8),
            ],
            // New files to attach
            if (_fichiers.isNotEmpty) ...[
              const Text('Nouvelles pièces jointes :',
                  style: TextStyle(color: Colors.white38, fontSize: 11)),
              const SizedBox(height: 4),
              Wrap(spacing: 6, runSpacing: 4, children: [
                ..._fichiers.asMap().entries.map((e) =>
                    _PjChip(
                      nom: _nomsF[e.key],
                      onRemove: () => setState(() {
                        _fichiers.removeAt(e.key);
                        _nomsF.removeAt(e.key);
                      }),
                    )),
              ]),
              const SizedBox(height: 8),
            ],
            // Ajouter fichiers
            InkWell(
              onTap: _pickFiles,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  border: Border.all(
                      color: const Color(0xFF6C47FF)
                          .withValues(alpha: 0.4),
                      style: BorderStyle.solid),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(children: [
                  Icon(Icons.attach_file,
                      color: Color(0xFF6C47FF), size: 18),
                  SizedBox(width: 8),
                  Text('Ajouter des pièces jointes',
                      style: TextStyle(
                          color: Color(0xFF6C47FF), fontSize: 13)),
                ]),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6C47FF),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14)),
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : Text(isEdit ? 'Enregistrer' : 'Publier le devoir',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DatePickerRow extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool set;
  final VoidCallback onTap;
  final VoidCallback onClear;
  const _DatePickerRow(
      {required this.label,
      required this.icon,
      required this.set,
      required this.onTap,
      required this.onClear});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(
              color: Colors.white.withValues(alpha: 0.15)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(children: [
          Icon(icon, color: Colors.white38, size: 18),
          const SizedBox(width: 10),
          Expanded(
              child: Text(label,
                  style: TextStyle(
                      color: set ? Colors.white : Colors.white38,
                      fontSize: 13))),
          if (set)
            GestureDetector(
              onTap: onClear,
              child: const Icon(Icons.close,
                  color: Colors.white24, size: 16),
            ),
        ]),
      ),
    );
  }
}

class _PjChip extends StatelessWidget {
  final String nom;
  final VoidCallback onRemove;
  const _PjChip({required this.nom, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 4, 4, 4),
      decoration: BoxDecoration(
        color: const Color(0xFF6C47FF).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: const Color(0xFF6C47FF).withValues(alpha: 0.3)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.attach_file,
            size: 12, color: Color(0xFF6C47FF)),
        const SizedBox(width: 4),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 120),
          child: Text(nom,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: Color(0xFF6C47FF), fontSize: 11)),
        ),
        const SizedBox(width: 4),
        GestureDetector(
          onTap: onRemove,
          child: const Icon(Icons.close,
              size: 12, color: Color(0xFF6C47FF)),
        ),
      ]),
    );
  }
}

// ─── Feuille des soumissions et corrections ───────────────���───────────────────

class _SoumissionsSheet extends StatelessWidget {
  final DevoirModel devoir;
  const _SoumissionsSheet({required this.devoir});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (_, ctrl) => Column(children: [
        // Header
        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          decoration: const BoxDecoration(
            color: Color(0xFF161B22),
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(children: [
            Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 12),
            Row(children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [Color(0xFF16A34A), Color(0xFF0F766E)]),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.rate_review_outlined,
                    color: Colors.white, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(devoir.titre,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    Text(
                      'Corrections · Sur ${devoir.bareme} pts',
                      style: const TextStyle(
                          color: Colors.white38, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ]),
          ]),
        ),
        const Divider(height: 1, color: Colors.white12),
        Expanded(
          child: StreamBuilder<List<SubmissionModel>>(
            stream: ProfesseurService.submissionsForDevoirStream(devoir.id),
            builder: (ctx, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(
                    child: CircularProgressIndicator(
                        color: Color(0xFF16A34A)));
              }
              final subs = snap.data ?? [];
              if (subs.isEmpty) {
                return const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.inbox_outlined,
                          color: Colors.white24, size: 48),
                      SizedBox(height: 12),
                      Text('Aucune soumission pour ce devoir.',
                          style: TextStyle(
                              color: Colors.white38, fontSize: 13)),
                    ],
                  ),
                );
              }
              return ListView.separated(
                controller: ctrl,
                padding: const EdgeInsets.all(12),
                itemCount: subs.length,
                separatorBuilder: (_, __) =>
                    const Divider(color: Colors.white12, height: 1),
                itemBuilder: (_, i) => _SubmissionTile(
                  sub: subs[i],
                  bareme: devoir.bareme,
                  onGrade: () => _showGradeSheet(ctx, subs[i]),
                ),
              );
            },
          ),
        ),
      ]),
    );
  }

  void _showGradeSheet(BuildContext context, SubmissionModel sub) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF161B22),
      shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => _GradeSheet(sub: sub, bareme: devoir.bareme),
    );
  }
}

class _SubmissionTile extends StatelessWidget {
  final SubmissionModel sub;
  final int bareme;
  final VoidCallback onGrade;
  const _SubmissionTile(
      {required this.sub, required this.bareme, required this.onGrade});

  @override
  Widget build(BuildContext context) {
    final isCorrected = sub.status == SubmissionStatus.corrected;
    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: isCorrected
            ? const Color(0xFF16A34A).withValues(alpha: 0.2)
            : const Color(0xFF6C47FF).withValues(alpha: 0.2),
        child: Icon(
          isCorrected
              ? Icons.check_circle_outline
              : Icons.hourglass_empty_outlined,
          color: isCorrected
              ? const Color(0xFF16A34A)
              : const Color(0xFF6C47FF),
          size: 18,
        ),
      ),
      title: Text(
        sub.studentNom.isNotEmpty ? sub.studentNom : sub.studentEmail,
        style: const TextStyle(
            color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            DateFormat('dd/MM à HH:mm').format(sub.createdAt),
            style:
                const TextStyle(color: Colors.white38, fontSize: 11),
          ),
          if (isCorrected && sub.grade != null)
            Text('${sub.grade!.toStringAsFixed(1)} / $bareme',
                style: const TextStyle(
                    color: Color(0xFF16A34A),
                    fontWeight: FontWeight.bold,
                    fontSize: 12)),
          if (sub.textReponse.isNotEmpty)
            Text(sub.textReponse,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: Colors.white54, fontSize: 11)),
        ],
      ),
      trailing: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (sub.tousLesFichiers.isNotEmpty)
            GestureDetector(
              onTap: () {
                final url = sub.tousLesFichiers.first['url'] ?? '';
                if (url.isNotEmpty) launchUrl(Uri.parse(url));
              },
              child: const Icon(Icons.download_outlined,
                  color: Colors.white38, size: 18),
            ),
          const SizedBox(height: 4),
          GestureDetector(
            onTap: onGrade,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFF6C47FF).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                isCorrected ? 'Modifier' : 'Corriger',
                style: const TextStyle(
                    color: Color(0xFF6C47FF),
                    fontSize: 10,
                    fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GradeSheet extends StatefulWidget {
  final SubmissionModel sub;
  final int bareme;
  const _GradeSheet({required this.sub, required this.bareme});

  @override
  State<_GradeSheet> createState() => _GradeSheetState();
}

class _GradeSheetState extends State<_GradeSheet> {
  late final TextEditingController _gradeCtrl;
  late final TextEditingController _commentCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _gradeCtrl = TextEditingController(
        text: widget.sub.grade?.toStringAsFixed(1) ?? '');
    _commentCtrl =
        TextEditingController(text: widget.sub.teacherComment ?? '');
  }

  @override
  void dispose() {
    _gradeCtrl.dispose();
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final grade = double.tryParse(_gradeCtrl.text.trim());
    if (grade == null) return;
    setState(() => _saving = true);
    try {
      await ProfesseurService.graderSubmission(
        widget.sub.id,
        grade,
        _commentCtrl.text.trim(),
      );
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          left: 16,
          right: 16,
          top: 16),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 12),
            Text(
              widget.sub.studentNom.isNotEmpty
                  ? widget.sub.studentNom
                  : widget.sub.studentEmail,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text('Rendu le ${DateFormat('dd/MM/yyyy à HH:mm').format(widget.sub.createdAt)}',
                style: const TextStyle(
                    color: Colors.white38, fontSize: 12)),
            if (widget.sub.textReponse.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text('Réponse de l\'élève :',
                  style:
                      TextStyle(color: Colors.white38, fontSize: 11)),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color:
                      Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(widget.sub.textReponse,
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 13)),
              ),
            ],
            if (widget.sub.tousLesFichiers.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text('Fichiers joints :',
                  style:
                      TextStyle(color: Colors.white38, fontSize: 11)),
              const SizedBox(height: 4),
              ...widget.sub.tousLesFichiers.map((f) => ListTile(
                    dense: true,
                    leading: const Icon(
                        Icons.insert_drive_file_outlined,
                        color: Color(0xFFD97706),
                        size: 18),
                    title: Text(f['nom'] ?? 'Fichier',
                        style: const TextStyle(
                            color: Colors.white, fontSize: 12)),
                    onTap: () {
                      final url = f['url'] ?? '';
                      if (url.isNotEmpty) launchUrl(Uri.parse(url));
                    },
                    trailing: const Icon(Icons.open_in_new,
                        color: Colors.white24, size: 14),
                  )),
            ],
            const SizedBox(height: 16),
            // Note
            TextField(
              controller: _gradeCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Note / ${widget.bareme}',
                labelStyle:
                    const TextStyle(color: Colors.white38),
                suffixText: '/ ${widget.bareme}',
                suffixStyle:
                    const TextStyle(color: Colors.white38),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(
                      color: Colors.white.withValues(alpha: 0.15)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide:
                      const BorderSide(color: Color(0xFF6C47FF)),
                ),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _commentCtrl,
              maxLines: 3,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Commentaire (optionnel)',
                labelStyle:
                    const TextStyle(color: Colors.white38),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(
                      color: Colors.white.withValues(alpha: 0.15)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide:
                      const BorderSide(color: Color(0xFF6C47FF)),
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF16A34A),
                    foregroundColor: Colors.white,
                    padding:
                        const EdgeInsets.symmetric(vertical: 14)),
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Text('Valider la correction',
                        style: TextStyle(
                            fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
