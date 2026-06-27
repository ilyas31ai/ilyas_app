import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../models/classe_model.dart';
import '../models/devoir_model.dart';
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
            onPressed: () => _showSendDialog(context),
            icon: const Icon(Icons.send_outlined, color: Colors.white),
            label:
                const Text('Envoyer PDF', style: TextStyle(color: Colors.white)),
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
          final devoirs = snap.data ?? [];
          if (devoirs.isEmpty) return _emptyState(context);
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            itemCount: devoirs.length,
            itemBuilder: (ctx, i) => _DevoirCard(
              devoir: devoirs[i],
              onDelete: () => _confirmDelete(ctx, devoirs[i]),
            ),
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
}

// ─── Carte devoir ─────────────────────────────────────────────────────────────

class _DevoirCard extends StatelessWidget {
  final DevoirModel devoir;
  final VoidCallback onDelete;

  const _DevoirCard({required this.devoir, required this.onDelete});

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
            const SizedBox(height: 6),
            // Bouton traçabilité IA
            if (devoir.classeNom.isNotEmpty && devoir.matiere.isNotEmpty)
              Align(
                alignment: Alignment.centerLeft,
                child: InkWell(
                  onTap: () => _showTracabiliteSheet(context),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0891B2).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: const Color(0xFF0891B2)
                              .withValues(alpha: 0.3)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.analytics_outlined,
                            size: 13, color: Color(0xFF0891B2)),
                        SizedBox(width: 5),
                        Text('Suivi élèves',
                            style: TextStyle(
                                color: Color(0xFF0891B2),
                                fontSize: 11,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
              ),
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
                    'Date limite : ${_fmt(limit)}',
                    style: TextStyle(
                      color: isLate
                          ? const Color(0xFFDC2626)
                          : const Color(0xFF15803D),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
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
