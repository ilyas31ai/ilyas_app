import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/appreciation_model.dart';
import '../models/note_model.dart';
import '../models/user_model.dart';
import '../services/appreciation_service.dart';
import '../services/etudiant_service.dart';
import '../services/user_service.dart';

// ─── Entry point ──────────────────────────────────────────────────────────────

/// Bulletin / Relevé de notes unifié.
/// [eleveUid] nul → l'élève connecté. Non nul → parent/direction visualise
/// un élève spécifique.
class EleveReleveNotesPage extends StatelessWidget {
  final String? eleveUid;
  final String? eleveNom;
  const EleveReleveNotesPage({super.key, this.eleveUid, this.eleveNom});

  @override
  Widget build(BuildContext context) {
    final targetUid =
        eleveUid ?? FirebaseAuth.instance.currentUser?.uid ?? '';
    return _ReleveBody(eleveUid: targetUid, eleveNomHint: eleveNom);
  }
}

// ─── Period enum ──────────────────────────────────────────────────────────────

enum _Period { t1, t2, t3, annee }

extension _PeriodX on _Period {
  String get label {
    switch (this) {
      case _Period.t1:   return 'Trim. 1';
      case _Period.t2:   return 'Trim. 2';
      case _Period.t3:   return 'Trim. 3';
      case _Period.annee: return 'Année';
    }
  }

  static _Period current() {
    final m = DateTime.now().month;
    if (m >= 9 && m <= 11) return _Period.t1;
    if (m == 12 || m <= 2) return _Period.t2;
    return _Period.t3;
  }

  static int trimestreOf(DateTime d) {
    final m = d.month;
    if (m >= 9 && m <= 11) return 1;
    if (m == 12 || m <= 2) return 2;
    return 3;
  }
}

// ─── Body ─────────────────────────────────────────────────────────────────────

class _ReleveBody extends StatefulWidget {
  final String eleveUid;
  final String? eleveNomHint;
  const _ReleveBody({required this.eleveUid, this.eleveNomHint});

  @override
  State<_ReleveBody> createState() => _ReleveBodyState();
}

class _ReleveBodyState extends State<_ReleveBody> {
  static const _bg     = Color(0xFF0D1117);
  static const _purple = Color(0xFF6C47FF);
  static const _green  = Color(0xFF16A34A);
  static const _orange = Color(0xFFD97706);
  static const _red    = Color(0xFFDC2626);

  _Period _period = _PeriodX.current();
  bool _pdfLoading = false;
  int? _rang; // null = non calculé ou non disponible

  // ─── Helpers ─────────────────────────────────────────────────────────────────

  Color _noteColor(double v) {
    if (v >= 14) return _green;
    if (v >= 10) return _orange;
    return _red;
  }

  String _mention(double v) {
    if (v >= 16) return 'Félicitations';
    if (v >= 14) return 'Bien';
    if (v >= 12) return 'Assez bien';
    if (v >= 10) return 'Passable';
    if (v >= 8)  return 'Insuffisant';
    return 'Très insuffisant';
  }

  String _appreciation(double v) {
    if (v >= 18) return 'Excellent';
    if (v >= 15) return 'Très bien';
    if (v >= 12) return 'Bien';
    if (v >= 10) return 'Assez bien';
    if (v >= 7)  return 'Insuffisant';
    return 'Très faible';
  }

  String _conseilTexte(double v) {
    if (v >= 16) return 'Félicitations du conseil de classe pour ce trimestre exceptionnel. Continuez sur cette lancée !';
    if (v >= 14) return 'Encouragements du conseil de classe. Excellent travail, maintenez vos efforts.';
    if (v >= 12) return 'Bon trimestre dans l\'ensemble. Des efforts supplémentaires permettraient d\'atteindre l\'excellence.';
    if (v >= 10) return 'Résultats satisfaisants. Il convient de renforcer le travail personnel.';
    if (v >= 8)  return 'Résultats insuffisants. Un travail plus régulier est indispensable.';
    return 'Résultats très insuffisants. Une remise à niveau urgente est nécessaire.';
  }

  List<NoteModel> _filter(List<NoteModel> all) {
    if (_period == _Period.annee) return all;
    final t = _period.index + 1;
    return all.where((n) => _PeriodX.trimestreOf(n.date) == t).toList();
  }

  static const _palette = [
    Color(0xFF2563EB), Color(0xFF0F766E), Color(0xFF7C3AED),
    Color(0xFFD97706), Color(0xFFBE185D), Color(0xFF16A34A),
    Color(0xFFDC2626), Color(0xFF0891B2), Color(0xFF6C47FF),
  ];

  // ─── Rang ─────────────────────────────────────────────────────────────────

  Future<void> _computeRang(String classeNom, double myMoyenne) async {
    if (classeNom.isEmpty) return;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('notes')
          .where('classeNom', isEqualTo: classeNom)
          .where('publie', isEqualTo: true)
          .get();

      final byEleve = <String, List<double>>{};
      for (final doc in snap.docs) {
        final d = doc.data();
        final uid = d['eleveId'] as String? ?? '';
        final note = (d['note'] as num?)?.toDouble() ?? 0;
        final bareme = (d['bareme'] as num?)?.toDouble() ?? 20;
        final sur20 = bareme == 0 ? 0.0 : (note / bareme) * 20;
        if (uid.isNotEmpty) (byEleve[uid] ??= []).add(sur20);
      }
      if (byEleve.isEmpty) return;

      final moyennes = byEleve.map((uid, vals) {
        final avg = vals.reduce((a, b) => a + b) / vals.length;
        return MapEntry(uid, avg);
      });

      final sorted = moyennes.values.toList()..sort((a, b) => b.compareTo(a));
      final rang = sorted.indexWhere((m) => (m - myMoyenne).abs() < 0.001) + 1;
      if (mounted) setState(() => _rang = rang > 0 ? rang : null);
    } catch (_) {}
  }

  // ─── PDF ──────────────────────────────────────────────────────────────────

  Future<void> _exportPdf(
    String nom,
    String classe,
    List<NoteModel> notes,
    Map<String, double> moyParMatiere,
    double moyGen,
  ) async {
    setState(() => _pdfLoading = true);
    try {
      final doc = pw.Document();
      final periodLabel = _period.label;
      final now = DateFormat('dd/MM/yyyy').format(DateTime.now());

      doc.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (ctx) => [
          // En-tête
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromInt(0xFF1E293B),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('SCOLAR Connect — Relevé de notes',
                    style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white)),
                pw.SizedBox(height: 4),
                pw.Text('$nom • $classe • $periodLabel • Généré le $now',
                    style: const pw.TextStyle(
                        fontSize: 10, color: PdfColors.grey300)),
              ],
            ),
          ),
          pw.SizedBox(height: 16),

          // Moyenne générale
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(
                  color: PdfColor.fromInt(0xFF6C47FF), width: 1),
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Moyenne générale',
                    style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold, fontSize: 13)),
                pw.Text('${moyGen.toStringAsFixed(2)} / 20',
                    style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColor.fromInt(0xFF6C47FF))),
              ],
            ),
          ),
          pw.SizedBox(height: 16),

          // Tableau matières
          pw.Table(
            border: pw.TableBorder.all(
                color: PdfColor.fromInt(0xFFE5E7EB), width: 0.5),
            columnWidths: {
              0: const pw.FlexColumnWidth(3),
              1: const pw.FlexColumnWidth(1.5),
              2: const pw.FlexColumnWidth(2),
            },
            children: [
              pw.TableRow(
                decoration: pw.BoxDecoration(
                    color: PdfColor.fromInt(0xFF374151)),
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Text('Matière',
                        style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.white,
                            fontSize: 11)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Text('Moyenne',
                        style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.white,
                            fontSize: 11)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Text('Appréciation',
                        style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.white,
                            fontSize: 11)),
                  ),
                ],
              ),
              ...moyParMatiere.entries.map((e) => pw.TableRow(
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Text(e.key,
                        style: const pw.TextStyle(fontSize: 11)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Text('${e.value.toStringAsFixed(2)}/20',
                        style: const pw.TextStyle(fontSize: 11)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Text(_appreciation(e.value),
                        style: const pw.TextStyle(fontSize: 10)),
                  ),
                ],
              )),
            ],
          ),
          pw.SizedBox(height: 16),

          // Liste des notes
          pw.Text('Détail des notes',
              style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold, fontSize: 13)),
          pw.SizedBox(height: 8),
          pw.Table(
            border: pw.TableBorder.all(
                color: PdfColor.fromInt(0xFFE5E7EB), width: 0.5),
            columnWidths: {
              0: const pw.FlexColumnWidth(2.5),
              1: const pw.FlexColumnWidth(1.5),
              2: const pw.FlexColumnWidth(1),
              3: const pw.FlexColumnWidth(1.5),
            },
            children: [
              pw.TableRow(
                decoration: pw.BoxDecoration(
                    color: PdfColor.fromInt(0xFF374151)),
                children: [
                  _pdfCell('Évaluation', header: true),
                  _pdfCell('Matière', header: true),
                  _pdfCell('Note', header: true),
                  _pdfCell('Date', header: true),
                ],
              ),
              ...notes.map((n) => pw.TableRow(children: [
                _pdfCell(n.intitule.isNotEmpty ? n.intitule : '—'),
                _pdfCell(n.matiere),
                _pdfCell('${n.note}/${n.bareme.toInt()}'),
                _pdfCell(DateFormat('dd/MM/yy').format(n.date)),
              ])),
            ],
          ),
          pw.SizedBox(height: 16),

          // Appréciation conseil
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromInt(0xFFF9FAFB),
              borderRadius: pw.BorderRadius.circular(6),
              border: pw.Border.all(
                  color: PdfColor.fromInt(0xFFE5E7EB), width: 0.5),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Appréciation du conseil de classe',
                    style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold, fontSize: 11)),
                pw.SizedBox(height: 4),
                pw.Text(_conseilTexte(moyGen),
                    style: const pw.TextStyle(fontSize: 10)),
              ],
            ),
          ),
        ],
      ));

      await Printing.layoutPdf(
          onLayout: (_) async => doc.save(),
          name:
              'Bulletin_${nom.replaceAll(' ', '_')}_$periodLabel.pdf');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erreur PDF : $e'),
          backgroundColor: _red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
      }
    } finally {
      if (mounted) setState(() => _pdfLoading = false);
    }
  }

  static pw.Widget _pdfCell(String text, {bool header = false}) =>
      pw.Padding(
        padding: const pw.EdgeInsets.all(6),
        child: pw.Text(
          text,
          style: pw.TextStyle(
            fontSize: 10,
            fontWeight: header ? pw.FontWeight.bold : null,
            color: header ? PdfColors.white : null,
          ),
        ),
      );

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        elevation: 0,
        title: const Text('Bulletin & Relevé de notes',
            style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.bold)),
        actions: [
          _pdfLoading
              ? const Padding(
                  padding: EdgeInsets.all(14),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        color: _purple, strokeWidth: 2),
                  ))
              : const SizedBox.shrink(),
        ],
      ),
      body: StreamBuilder<List<NoteModel>>(
        stream: _notesStream(),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: _purple));
          }
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.lock_outline,
                      color: Colors.white24, size: 42),
                  const SizedBox(height: 12),
                  Text(
                    'Impossible de charger les notes.\n${snap.error}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: Colors.white38, fontSize: 13),
                  ),
                ]),
              ),
            );
          }

          final allNotes = snap.data ?? [];
          final filtered = _filter(allNotes);

          return Column(children: [
            _PeriodTabs(
              selected: _period,
              onChanged: (p) => setState(() {
                _period = p;
                _rang = null;
              }),
            ),
            Expanded(
              child: filtered.isEmpty
                  ? _EmptyState(period: _period)
                  : _buildContent(allNotes, filtered),
            ),
          ]);
        },
      ),
    );
  }

  Stream<List<NoteModel>> _notesStream() {
    final uid = widget.eleveUid;
    if (uid == FirebaseAuth.instance.currentUser?.uid) {
      return EtudiantService.notesStream('');
    }
    return FirebaseFirestore.instance
        .collection('notes')
        .where('eleveId', isEqualTo: uid)
        .where('publie', isEqualTo: true)
        .snapshots()
        .map((s) {
      final list =
          s.docs.map(NoteModel.fromFirestore).toList();
      list.sort((a, b) => b.date.compareTo(a.date));
      return list;
    });
  }

  Widget _buildContent(
    List<NoteModel> allNotes,
    List<NoteModel> notes,
  ) {
    final byMatiere = <String, List<NoteModel>>{};
    for (final n in notes) { (byMatiere[n.matiere] ??= []).add(n); }

    final moyParMatiere = byMatiere.map((mat, ns) {
      final avg = ns.fold<double>(0, (s, n) => s + n.sur20) / ns.length;
      return MapEntry(mat, avg);
    });

    final sortedMat = moyParMatiere.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    final moyGen = moyParMatiere.values.isEmpty
        ? 0.0
        : moyParMatiere.values.reduce((a, b) => a + b) /
            moyParMatiere.length;

    // Trigger rank computation for direction
    final classeNom = notes.isNotEmpty ? notes.first.classeNom : '';
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (_rang == null && classeNom.isNotEmpty) {
        final user = await UserService.currentUserStream().first;
        if (user?.role == UserRole.admin ||
            user?.role == UserRole.direction ||
            user?.role == UserRole.superAdmin) {
          _computeRang(classeNom, moyGen);
        }
      }
    });

    final nom = widget.eleveNomHint ??
        (notes.isNotEmpty
            ? '${notes.first.elevePrenom} ${notes.first.eleveNom}'.trim()
            : 'Élève');
    final classe = classeNom;

    final sorted = List<NoteModel>.from(allNotes)
      ..sort((a, b) => a.date.compareTo(b.date));

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
      children: [
        // Hero card
        _HeroCard(
          nom: nom,
          classe: classe,
          periode: _period.label,
          moyGen: moyGen,
          mention: _mention(moyGen),
          color: _noteColor(moyGen),
        ),
        const SizedBox(height: 12),

        // Stats row
        _StatsRow(
          nbMatieres: byMatiere.length,
          nbNotes: notes.length,
          minNote: notes.map((n) => n.sur20).reduce((a, b) => a < b ? a : b),
          maxNote: notes.map((n) => n.sur20).reduce((a, b) => a > b ? a : b),
          rang: _rang,
          totalEleves: null,
        ),
        const SizedBox(height: 16),

        // Graphique d'évolution
        if (sorted.length >= 2) ...[
          _EvolutionChart(notes: sorted),
          const SizedBox(height: 16),
        ],

        // Matières
        _sectionLabel('Résultats par matière', Icons.bar_chart_outlined),
        const SizedBox(height: 10),
        ...sortedMat.asMap().entries.map((e) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _MatiereCard(
            matiere: e.value.key,
            moy: e.value.value,
            notes: byMatiere[e.value.key]!,
            appreciation: _appreciation(e.value.value),
            accentColor: _palette[e.key % _palette.length],
            noteColor: _noteColor(e.value.value),
          ),
        )),
        const SizedBox(height: 8),

        // Appréciation conseil
        _ConseilCard(
          moyenne: moyGen,
          texte: _conseilTexte(moyGen),
          color: _noteColor(moyGen),
        ),
        const SizedBox(height: 16),

        // Appréciations des professeurs
        _ProfAppreciationsSection(
          eleveId: widget.eleveUid,
          trimestre: _period == _Period.annee ? null : _period.index + 1,
        ),

        // Bouton PDF
        _PdfButton(
          loading: _pdfLoading,
          onTap: () => _exportPdf(
              nom, classe, notes, moyParMatiere, moyGen),
        ),
      ],
    );
  }

  Widget _sectionLabel(String text, IconData icon) => Row(children: [
        Icon(icon, color: _purple, size: 16),
        const SizedBox(width: 7),
        Text(text,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w700)),
      ]);
}

// ─── Period tabs ──────────────────────────────────────────────────────────────

class _PeriodTabs extends StatelessWidget {
  final _Period selected;
  final ValueChanged<_Period> onChanged;
  const _PeriodTabs({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF161B22),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: _Period.values.map((p) => Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: GestureDetector(
              onTap: () => onChanged(p),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 7),
                decoration: BoxDecoration(
                  color: selected == p
                      ? const Color(0xFF6C47FF)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: selected == p
                        ? const Color(0xFF6C47FF)
                        : Colors.white24,
                  ),
                ),
                child: Text(
                  p.label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: selected == p
                        ? Colors.white
                        : Colors.white54,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ),
        )).toList(),
      ),
    );
  }
}

// ─── Hero card ────────────────────────────────────────────────────────────────

class _HeroCard extends StatelessWidget {
  final String nom, classe, periode, mention;
  final double moyGen;
  final Color color;
  const _HeroCard({
    required this.nom,
    required this.classe,
    required this.periode,
    required this.moyGen,
    required this.mention,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E1B4B), Color(0xFF0F172A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
            color: const Color(0xFF6C47FF).withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: const Color(0xFF6C47FF).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.description_outlined,
                  color: Color(0xFF6C47FF), size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(nom,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16)),
                  if (classe.isNotEmpty)
                    Text('Classe : $classe',
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 12)),
                  Text('Bulletin · $periode',
                      style: const TextStyle(
                          color: Colors.white38, fontSize: 11)),
                ],
              ),
            ),
          ]),
          const SizedBox(height: 18),
          Row(children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Moyenne générale',
                      style: TextStyle(
                          color: Colors.white54, fontSize: 11)),
                  const SizedBox(height: 2),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(moyGen.toStringAsFixed(2),
                          style: TextStyle(
                              color: color,
                              fontSize: 36,
                              fontWeight: FontWeight.bold)),
                      Text(' / 20',
                          style: TextStyle(
                              color: color.withValues(alpha: 0.7),
                              fontSize: 14)),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: color.withValues(alpha: 0.3)),
              ),
              child: Text(mention,
                  style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 13)),
            ),
          ]),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: LinearProgressIndicator(
              value: moyGen / 20,
              minHeight: 5,
              color: color,
              backgroundColor: color.withValues(alpha: 0.12),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Stats row ────────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  final int nbMatieres, nbNotes;
  final double minNote, maxNote;
  final int? rang;
  final int? totalEleves;
  const _StatsRow({
    required this.nbMatieres,
    required this.nbNotes,
    required this.minNote,
    required this.maxNote,
    this.rang,
    this.totalEleves,
  });

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      _StatChip(
          label: 'Matières',
          value: '$nbMatieres',
          icon: Icons.book_outlined,
          color: const Color(0xFF2563EB)),
      const SizedBox(width: 8),
      _StatChip(
          label: 'Notes',
          value: '$nbNotes',
          icon: Icons.grade_outlined,
          color: const Color(0xFF6C47FF)),
      const SizedBox(width: 8),
      _StatChip(
          label: 'Max',
          value: maxNote.toStringAsFixed(1),
          icon: Icons.arrow_upward,
          color: const Color(0xFF16A34A)),
      const SizedBox(width: 8),
      _StatChip(
          label: rang != null ? 'Rang' : 'Min',
          value: rang != null
              ? '$rang${totalEleves != null ? '/$totalEleves' : ''}'
              : minNote.toStringAsFixed(1),
          icon: rang != null
              ? Icons.emoji_events_outlined
              : Icons.arrow_downward,
          color: const Color(0xFFD97706)),
    ]);
  }
}

class _StatChip extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _StatChip(
      {required this.label,
      required this.value,
      required this.icon,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                  color: color,
                  fontSize: 15,
                  fontWeight: FontWeight.bold)),
          Text(label,
              style: const TextStyle(
                  color: Colors.white38, fontSize: 9),
              textAlign: TextAlign.center),
        ]),
      ),
    );
  }
}

// ─── Evolution chart ──────────────────────────────────────────────────────────

class _EvolutionChart extends StatelessWidget {
  final List<NoteModel> notes;
  const _EvolutionChart({required this.notes});

  @override
  Widget build(BuildContext context) {
    final spots = notes.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), e.value.sur20.clamp(0, 20));
    }).toList();

    return Container(
      height: 160,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('ÉVOLUTION DES NOTES',
              style: TextStyle(
                  color: Colors.white38,
                  fontSize: 10,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          Expanded(
            child: LineChart(LineChartData(
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (_) => FlLine(
                  color: Colors.white.withValues(alpha: 0.05),
                  strokeWidth: 1,
                ),
              ),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    interval: 5,
                    getTitlesWidget: (v, _) => Text('${v.toInt()}',
                        style: const TextStyle(
                            color: Colors.white38, fontSize: 9)),
                  ),
                ),
                bottomTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
              ),
              borderData: FlBorderData(show: false),
              minY: 0,
              maxY: 20,
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  gradient: const LinearGradient(
                      colors: [Color(0xFF6C47FF), Color(0xFF2563EB)]),
                  barWidth: 2.5,
                  isStrokeCapRound: true,
                  dotData: FlDotData(
                    show: true,
                    getDotPainter: (_, __, ___, ____) =>
                        FlDotCirclePainter(
                      radius: 3,
                      color: const Color(0xFF6C47FF),
                      strokeWidth: 1.5,
                      strokeColor: Colors.white,
                    ),
                  ),
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF6C47FF).withValues(alpha: 0.2),
                        const Color(0xFF2563EB).withValues(alpha: 0.0),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
                // Ligne moyenne (10/20)
                LineChartBarData(
                  spots: [
                    FlSpot(0, 10),
                    FlSpot((spots.length - 1).toDouble(), 10),
                  ],
                  isCurved: false,
                  color: Colors.white.withValues(alpha: 0.2),
                  barWidth: 1,
                  dotData: const FlDotData(show: false),
                  dashArray: [4, 4],
                ),
              ],
            )),
          ),
        ],
      ),
    );
  }
}

// ─── Matière card ─────────────────────────────────────────────────────────────

class _MatiereCard extends StatefulWidget {
  final String matiere, appreciation;
  final double moy;
  final List<NoteModel> notes;
  final Color accentColor, noteColor;
  const _MatiereCard({
    required this.matiere,
    required this.moy,
    required this.notes,
    required this.appreciation,
    required this.accentColor,
    required this.noteColor,
  });

  @override
  State<_MatiereCard> createState() => _MatiereCardState();
}

class _MatiereCardState extends State<_MatiereCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(children: [
        // Header
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            child: Row(children: [
              Container(
                width: 5,
                height: 38,
                decoration: BoxDecoration(
                  color: widget.accentColor,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.matiere,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14)),
                    Row(children: [
                      Text(
                        widget.appreciation,
                        style: TextStyle(
                            color: widget.noteColor
                                .withValues(alpha: 0.85),
                            fontSize: 11),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${widget.notes.length} note${widget.notes.length > 1 ? 's' : ''}',
                        style: const TextStyle(
                            color: Colors.white38, fontSize: 11),
                      ),
                    ]),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: widget.noteColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${widget.moy.toStringAsFixed(2)}/20',
                  style: TextStyle(
                      color: widget.noteColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 13),
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                _expanded
                    ? Icons.keyboard_arrow_up
                    : Icons.keyboard_arrow_down,
                color: Colors.white38,
                size: 18,
              ),
            ]),
          ),
        ),
        // Barre progression
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 6),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: widget.moy / 20,
              minHeight: 3,
              color: widget.noteColor,
              backgroundColor:
                  widget.noteColor.withValues(alpha: 0.1),
            ),
          ),
        ),
        // Notes détaillées
        if (_expanded) ...[
          const Divider(color: Color(0xFF30363D), height: 1),
          ...widget.notes.map((n) => _NoteDetailRow(note: n)),
        ],
      ]),
    );
  }
}

// ─── Note detail row ──────────────────────────────────────────────────────────

class _NoteDetailRow extends StatelessWidget {
  final NoteModel note;
  const _NoteDetailRow({required this.note});

  @override
  Widget build(BuildContext context) {
    final pct = note.bareme > 0 ? note.note / note.bareme : 0.0;
    final color = pct >= 0.7
        ? const Color(0xFF16A34A)
        : pct >= 0.5
            ? const Color(0xFFD97706)
            : const Color(0xFFDC2626);
    final fmt = DateFormat('dd/MM/yy');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: const BoxDecoration(
        border: Border(
            bottom: BorderSide(color: Color(0xFF30363D), width: 0.4)),
      ),
      child: Row(children: [
        Container(
          width: 46,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(7),
          ),
          child: Text(
            note.note.toStringAsFixed(note.note % 1 == 0 ? 0 : 1),
            style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 14),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                note.intitule.isNotEmpty ? note.intitule : 'Évaluation',
                style: const TextStyle(
                    color: Colors.white, fontSize: 13),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(fmt.format(note.date),
                  style: const TextStyle(
                      color: Colors.white38, fontSize: 11)),
            ],
          ),
        ),
        Text('/${note.bareme.toInt()}',
            style: const TextStyle(
                color: Colors.white38, fontSize: 12)),
      ]),
    );
  }
}

// ─── Conseil card ─────────────────────────────────────────────────────────────

class _ConseilCard extends StatelessWidget {
  final double moyenne;
  final String texte;
  final Color color;
  const _ConseilCard(
      {required this.moyenne, required this.texte, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.comment_outlined, color: color, size: 16),
          const SizedBox(width: 8),
          Text('Appréciation du conseil de classe',
              style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w600,
                  fontSize: 13)),
        ]),
        const SizedBox(height: 10),
        Text(texte,
            style: const TextStyle(
                color: Colors.white60, fontSize: 13, height: 1.5)),
      ]),
    );
  }
}

// ─── Section appréciations professeurs ───────────────────────────────────────

class _ProfAppreciationsSection extends StatelessWidget {
  final String eleveId;
  final int? trimestre;
  const _ProfAppreciationsSection(
      {required this.eleveId, this.trimestre});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AppreciationModel>>(
      stream: AppreciationService.streamByEleve(
          eleveId: eleveId, trimestre: trimestre),
      builder: (ctx, snap) {
        final list = snap.data?.where((a) => a.texte.isNotEmpty).toList() ?? [];
        if (list.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.rate_review_outlined,
                  color: Color(0xFF6C47FF), size: 16),
              const SizedBox(width: 7),
              const Text('Appréciations des professeurs',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: 10),
            ...list.map((a) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF6C47FF).withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF6C47FF).withValues(alpha: 0.2),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Icon(Icons.person_outline,
                          color: Color(0xFF6C47FF), size: 14),
                      const SizedBox(width: 6),
                      Text(
                        a.matiere.isNotEmpty
                            ? '${a.matiere}${a.professeurNom.isNotEmpty ? ' · ${a.professeurNom}' : ''}'
                            : (a.professeurNom.isNotEmpty
                                ? a.professeurNom
                                : 'Professeur'),
                        style: const TextStyle(
                            color: Color(0xFF6C47FF),
                            fontWeight: FontWeight.w600,
                            fontSize: 12),
                      ),
                    ]),
                    const SizedBox(height: 8),
                    Text(a.texte,
                        style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                            height: 1.5)),
                  ],
                ),
              ),
            )),
            const SizedBox(height: 8),
          ],
        );
      },
    );
  }
}

// ─── PDF button ───────────────────────────────────────────────────────────────

class _PdfButton extends StatelessWidget {
  final bool loading;
  final VoidCallback onTap;
  const _PdfButton({required this.loading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: loading ? null : onTap,
        icon: loading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2))
            : const Icon(Icons.picture_as_pdf_outlined, size: 18),
        label: Text(loading ? 'Génération…' : 'Télécharger le bulletin PDF'),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF6C47FF),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(
              fontSize: 14, fontWeight: FontWeight.w600),
          disabledBackgroundColor:
              const Color(0xFF6C47FF).withValues(alpha: 0.5),
        ),
      ),
    );
  }
}

// ─── Empty state ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final _Period period;
  const _EmptyState({required this.period});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.description_outlined,
            color: Colors.white24, size: 52),
        const SizedBox(height: 14),
        Text('Aucune note pour ${period.label}',
            style: const TextStyle(
                color: Colors.white54, fontSize: 15)),
        const SizedBox(height: 6),
        const Text(
          'Les notes seront visibles une fois publiées',
          style: TextStyle(color: Colors.white24, fontSize: 12),
        ),
      ]),
    );
  }
}
