import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/copie_model.dart';
import '../models/devoir_model.dart';
import '../models/submission_model.dart';
import '../services/devoir_interactif_service.dart';
import '../services/etudiant_service.dart';
import 'etudiant_faire_devoir_page.dart';
import 'etudiant_revisions_ia_page.dart';
import 'etudiant_soumission_devoir_page.dart';

// ─── Palette ──────────────────────────────────────────────────────────────────

const _kBg     = Color(0xFF0D1117);
const _kCard   = Color(0xFF161B22);
const _kBlue   = Color(0xFF2563EB);
const _kPurple = Color(0xFF6C47FF);
const _kGreen  = Color(0xFF16A34A);
const _kOrange = Color(0xFFD97706);
const _kRed    = Color(0xFFDC2626);

class EtudiantDevoirsPage extends StatefulWidget {
  const EtudiantDevoirsPage({super.key});

  @override
  State<EtudiantDevoirsPage> createState() => _EtudiantDevoirsPageState();
}

class _EtudiantDevoirsPageState extends State<EtudiantDevoirsPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final eleveNom = user?.displayName ?? user?.email ?? 'Élève';

    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kCard,
        elevation: 0,
        title: const Text(
          'Mes Devoirs',
          style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold),
        ),
        bottom: TabBar(
          controller: _tabs,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white38,
          indicatorColor: _kPurple,
          labelStyle:
              const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
          tabs: const [
            Tab(text: 'À faire'),
            Tab(text: 'Rendus'),
            Tab(text: 'Corrigés'),
          ],
        ),
      ),
      body: StreamBuilder<String?>(
        stream: EtudiantService.classeNomStream(),
        builder: (context, classSnap) {
          if (classSnap.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: _kBlue));
          }
          final classeNom = classSnap.data ?? '';
          if (classeNom.isEmpty) {
            return const Center(
              child: Text('Classe non assignée.',
                  style: TextStyle(color: Colors.white70)),
            );
          }
          return StreamBuilder<List<DevoirModel>>(
            stream: EtudiantService.allDevoirsStream(classeNom),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(
                    child: CircularProgressIndicator(color: _kBlue));
              }
              final devoirs = snap.data ?? [];
              return TabBarView(
                controller: _tabs,
                children: [
                  _DevoirsList(
                      devoirs: devoirs,
                      eleveNom: eleveNom,
                      tab: _DevoirsTab.aFaire),
                  _DevoirsList(
                      devoirs: devoirs,
                      eleveNom: eleveNom,
                      tab: _DevoirsTab.rendus),
                  _DevoirsList(
                      devoirs: devoirs,
                      eleveNom: eleveNom,
                      tab: _DevoirsTab.corriges),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

enum _DevoirsTab { aFaire, rendus, corriges }

// ─── Liste unifiée ─────────────────────────────────────���──────────────────────

class _DevoirsList extends StatelessWidget {
  final List<DevoirModel> devoirs;
  final String eleveNom;
  final _DevoirsTab tab;

  const _DevoirsList({
    required this.devoirs,
    required this.eleveNom,
    required this.tab,
  });

  @override
  Widget build(BuildContext context) {
    if (devoirs.isEmpty) {
      return Center(
        child: Text(
          tab == _DevoirsTab.aFaire
              ? 'Aucun devoir à faire.'
              : tab == _DevoirsTab.rendus
                  ? 'Aucun devoir rendu.'
                  : 'Aucun devoir corrigé.',
          style: const TextStyle(color: Colors.white38),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      itemCount: devoirs.length,
      itemBuilder: (_, i) => _DevoirTile(
        devoir: devoirs[i],
        eleveNom: eleveNom,
        tab: tab,
      ),
    );
  }
}

// ─── Tile devoir (gère interactive et fichier) ────────────────────────────────

class _DevoirTile extends StatelessWidget {
  final DevoirModel devoir;
  final String eleveNom;
  final _DevoirsTab tab;

  const _DevoirTile({
    required this.devoir,
    required this.eleveNom,
    required this.tab,
  });

  @override
  Widget build(BuildContext context) {
    // Interactive devoirs use the copies collection
    if (devoir.estInteractif || devoir.estExamen) {
      return _InteractiveTile(
          devoir: devoir, eleveNom: eleveNom, tab: tab);
    }
    // File/text devoirs use the submissions collection
    return _SubmissionTile(devoir: devoir, eleveNom: eleveNom, tab: tab);
  }
}

// ─── Devoir interactif ────────────────────────────────────────────────────────

class _InteractiveTile extends StatelessWidget {
  final DevoirModel devoir;
  final String eleveNom;
  final _DevoirsTab tab;
  const _InteractiveTile(
      {required this.devoir, required this.eleveNom, required this.tab});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<CopieModel?>(
      stream: DevoirInteractifService.copieStream(devoir.id),
      builder: (_, snap) {
        final copie = snap.data;
        final statut = copie?.statut;

        final isDone = statut == CopieStatut.soumis ||
            statut == CopieStatut.corrige;
        final isCorrected = statut == CopieStatut.corrige;
        final isExpired = devoir.dateLimite != null &&
            DateTime.now().isAfter(devoir.dateLimite!);

        // Tab filter
        if (tab == _DevoirsTab.aFaire && isDone) {
          return const SizedBox.shrink();
        }
        if (tab == _DevoirsTab.rendus && (isCorrected || !isDone)) {
          return const SizedBox.shrink();
        }
        if (tab == _DevoirsTab.corriges && !isCorrected) {
          return const SizedBox.shrink();
        }

        return _DevoirCard(
          devoir: devoir,
          statusBadge: _StatusBadge(
            label: isCorrected
                ? 'Corrigé'
                : isDone
                    ? 'Rendu'
                    : isExpired
                        ? 'Expiré'
                        : 'À faire',
            color: isCorrected
                ? _kGreen
                : isDone
                    ? _kBlue
                    : isExpired
                        ? _kRed
                        : _kPurple,
          ),
          grade: isCorrected && copie?.note != null
              ? '${copie!.note!.toStringAsFixed(1)} / ${copie.noteSur?.toStringAsFixed(0) ?? devoir.bareme}'
              : null,
          teacherComment: null,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => EtudiantFaireDevoirPage(
                devoir: devoir,
                eleveNom: eleveNom,
                readOnly: isDone,
                existingCopie: copie,
              ),
            ),
          ),
          onRevise: () => Navigator.push(
            context,
            MaterialPageRoute<void>(
                builder: (_) => EtudiantRevisionsIaPage(devoir: devoir)),
          ),
        );
      },
    );
  }
}

// ─── Devoir fichier/texte ─────────────────────────────────────────────────────

class _SubmissionTile extends StatelessWidget {
  final DevoirModel devoir;
  final String eleveNom;
  final _DevoirsTab tab;
  const _SubmissionTile(
      {required this.devoir, required this.eleveNom, required this.tab});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<SubmissionModel?>(
      stream: EtudiantService.submissionForDevoir(devoir.id),
      builder: (_, snap) {
        final sub = snap.data;
        final isCorrected = sub?.status == SubmissionStatus.corrected;
        final isSubmitted = sub != null;
        final isExpired = devoir.dateLimite != null &&
            DateTime.now().isAfter(devoir.dateLimite!);

        if (tab == _DevoirsTab.aFaire && isSubmitted) {
          return const SizedBox.shrink();
        }
        if (tab == _DevoirsTab.rendus && (isCorrected || !isSubmitted)) {
          return const SizedBox.shrink();
        }
        if (tab == _DevoirsTab.corriges && !isCorrected) {
          return const SizedBox.shrink();
        }

        return _DevoirCard(
          devoir: devoir,
          statusBadge: _StatusBadge(
            label: isCorrected
                ? 'Corrigé'
                : isSubmitted
                    ? 'Rendu'
                    : isExpired
                        ? 'Expiré'
                        : 'À faire',
            color: isCorrected
                ? _kGreen
                : isSubmitted
                    ? _kBlue
                    : isExpired
                        ? _kRed
                        : _kPurple,
          ),
          grade: isCorrected && sub?.grade != null
              ? '${sub!.grade!.toStringAsFixed(1)} / ${devoir.bareme}'
              : null,
          teacherComment: isCorrected ? sub?.teacherComment : null,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => EtudiantSoumissionDevoirPage(
                devoir: devoir,
                existingSubmission: sub,
              ),
            ),
          ),
          onRevise: devoir.matiere.isNotEmpty
              ? () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                        builder: (_) =>
                            EtudiantRevisionsIaPage(devoir: devoir)),
                  )
              : null,
        );
      },
    );
  }
}

// ─── Carte visuelle du devoir ─────────────────────────────────────────────────

class _DevoirCard extends StatelessWidget {
  final DevoirModel devoir;
  final Widget statusBadge;
  final String? grade;
  final String? teacherComment;
  final VoidCallback onTap;
  final VoidCallback? onRevise;

  const _DevoirCard({
    required this.devoir,
    required this.statusBadge,
    required this.grade,
    required this.teacherComment,
    required this.onTap,
    this.onRevise,
  });

  @override
  Widget build(BuildContext context) {
    final isExpired = devoir.dateLimite != null &&
        DateTime.now().isAfter(devoir.dateLimite!);
    final typeIcon = devoir.estExamen
        ? Icons.timer_outlined
        : devoir.estInteractif
            ? Icons.quiz_outlined
            : Icons.description_outlined;
    final typeColor = devoir.estExamen
        ? _kRed
        : devoir.estInteractif
            ? _kBlue
            : _kOrange;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _kCard,
          borderRadius: BorderRadius.circular(14),
          border:
              Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: typeColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(typeIcon, color: typeColor, size: 20),
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
                    Text(
                      '${devoir.matiere} · ${devoir.classeNom}',
                      style: const TextStyle(
                          color: Colors.white38, fontSize: 12),
                    ),
                  ],
                ),
              ),
              statusBadge,
            ]),
            if (devoir.description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(devoir.description,
                  style: const TextStyle(
                      color: Colors.white54, fontSize: 12),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
            ],
            const SizedBox(height: 8),
            Row(children: [
              if (devoir.dateLimite != null)
                Row(children: [
                  Icon(Icons.schedule,
                      size: 13,
                      color:
                          isExpired ? _kRed : Colors.white38),
                  const SizedBox(width: 4),
                  Text(
                    DateFormat('dd/MM à HH:mm')
                        .format(devoir.dateLimite!),
                    style: TextStyle(
                        color: isExpired ? _kRed : Colors.white38,
                        fontSize: 11),
                  ),
                ]),
              const SizedBox(width: 12),
              Text('Sur ${devoir.bareme} pts',
                  style: const TextStyle(
                      color: Colors.white24, fontSize: 11)),
              if (devoir.tousLesAttachements.isNotEmpty) ...[
                const SizedBox(width: 8),
                Icon(Icons.attach_file,
                    size: 12, color: Colors.white24),
                Text(
                    '${devoir.tousLesAttachements.length}',
                    style: const TextStyle(
                        color: Colors.white24, fontSize: 11)),
              ],
            ]),
            // Grade + comment
            if (grade != null) ...[
              const SizedBox(height: 6),
              Row(children: [
                const Icon(Icons.star_outlined,
                    color: _kGreen, size: 14),
                const SizedBox(width: 4),
                Text(grade!,
                    style: const TextStyle(
                        color: _kGreen,
                        fontWeight: FontWeight.bold,
                        fontSize: 13)),
              ]),
            ],
            if (teacherComment != null &&
                teacherComment!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _kGreen.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: _kGreen.withValues(alpha: 0.2)),
                ),
                child: Row(children: [
                  const Icon(Icons.comment_outlined,
                      color: _kGreen, size: 12),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(teacherComment!,
                        style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                  ),
                ]),
              ),
            ],
            if (onRevise != null) ...[
              const SizedBox(height: 8),
              GestureDetector(
                onTap: onRevise,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color:
                        const Color(0xFF0F766E).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: const Color(0xFF0F766E)
                            .withValues(alpha: 0.4)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.smart_toy_outlined,
                          size: 12, color: Color(0xFF0F766E)),
                      SizedBox(width: 4),
                      Text('Réviser avec l\'IA',
                          style: TextStyle(
                              color: Color(0xFF0F766E),
                              fontSize: 11,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Badge statut ─────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(label,
          style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.bold)),
    );
  }
}
