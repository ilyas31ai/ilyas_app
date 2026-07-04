import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/appreciation_model.dart';
import '../models/bulletin_validation_model.dart';
import '../models/note_model.dart';
import '../models/user_model.dart';
import '../services/appreciation_service.dart';
import '../services/bulletin_validation_service.dart';
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
      case _Period.t1:    return 'Trim. 1';
      case _Period.t2:    return 'Trim. 2';
      case _Period.t3:    return 'Trim. 3';
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

// ─── Colours ──────────────────────────────────────────────────────────────────

const _kBg     = Color(0xFF0D1117);
const _kCard   = Color(0xFF161B22);
const _kCard2  = Color(0xFF1F2937);
const _kBorder = Color(0xFF30363D);
const _kPurple = Color(0xFF6C47FF);
const _kBlue   = Color(0xFF2563EB);
const _kGreen  = Color(0xFF16A34A);
const _kOrange = Color(0xFFD97706);
const _kRed    = Color(0xFFDC2626);
const _kTeal   = Color(0xFF0F766E);

// ─── Body ─────────────────────────────────────────────────────────────────────

class _ReleveBody extends StatefulWidget {
  final String eleveUid;
  final String? eleveNomHint;
  const _ReleveBody({required this.eleveUid, this.eleveNomHint});

  @override
  State<_ReleveBody> createState() => _ReleveBodyState();
}

class _ReleveBodyState extends State<_ReleveBody>
    with SingleTickerProviderStateMixin {
  _Period _period = _PeriodX.current();
  int _anneeScol = _currentSchoolYear();
  bool _pdfLoading = false;
  bool _printLoading = false;
  int? _rang;

  // Notification in-page : bulletin nouvellement publié
  final Set<String> _shownBannerKeys = {};
  StreamSubscription<BulletinValidationModel?>? _valSub;

  // Animation pour banner
  late final AnimationController _bannerCtrl;
  bool _showBanner = false;
  String _bannerLabel = '';

  // ── School year helpers ────────────────────────────────────────────────────

  static int _currentSchoolYear() {
    final now = DateTime.now();
    return now.month >= 9 ? now.year : now.year - 1;
  }

  static List<int> _availableYears() {
    final current = _currentSchoolYear();
    return [current, current - 1];
  }

  static bool _noteInYear(NoteModel n, int schoolYear) {
    final m = n.date.month;
    final y = n.date.year;
    if (m >= 9) return y == schoolYear;
    return y == schoolYear + 1;
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Color _noteColor(double v) {
    if (v >= 14) return _kGreen;
    if (v >= 10) return _kOrange;
    return _kRed;
  }

  String _mention(double v) {
    if (v >= 16) return 'Félicitations';
    if (v >= 14) return 'Bien';
    if (v >= 12) return 'Assez bien';
    if (v >= 10) return 'Passable';
    if (v >= 8)  return 'Insuffisant';
    return 'Très insuffisant';
  }

  String _appreciationText(double v) {
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
    final byYear = all.where((n) => _noteInYear(n, _anneeScol)).toList();
    if (_period == _Period.annee) return byYear;
    final t = _period.index + 1;
    return byYear
        .where((n) => _PeriodX.trimestreOf(n.date) == t)
        .toList();
  }

  static const _palette = [
    Color(0xFF2563EB), Color(0xFF0F766E), Color(0xFF7C3AED),
    Color(0xFFD97706), Color(0xFFBE185D), Color(0xFF16A34A),
    Color(0xFFDC2626), Color(0xFF0891B2), Color(0xFF6C47FF),
  ];

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _bannerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
  }

  @override
  void dispose() {
    _valSub?.cancel();
    _bannerCtrl.dispose();
    super.dispose();
  }

  // ── Bulletin publication listener ─────────────────────────────────────────

  void _listenForPublication(String classeId, int trimestre) {
    _valSub?.cancel();
    if (classeId.isEmpty || trimestre == 0) return;
    _valSub = BulletinValidationService.stream(
      classeId: classeId,
      trimestre: trimestre,
      anneeScol: _anneeScol,
    ).listen((val) async {
      if (val?.publie != true) return;
      final key = '${classeId}_t${trimestre}_$_anneeScol';
      if (_shownBannerKeys.contains(key)) return;
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      if (prefs.getBool('bulletin_banner_$key') == true) return;
      await prefs.setBool('bulletin_banner_$key', true);
      if (!mounted) return;
      _shownBannerKeys.add(key);
      setState(() {
        _showBanner = true;
        _bannerLabel = 'Bulletin T$trimestre publié par la Direction !';
      });
      _bannerCtrl.forward(from: 0);
      // Auto-hide après 5 secondes
      Future.delayed(const Duration(seconds: 5), () {
        if (mounted) {
          setState(() => _showBanner = false);
          _bannerCtrl.reverse();
        }
      });
    });
  }

  // ── Rang ──────────────────────────────────────────────────────────────────

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

      final sorted = moyennes.values.toList()
        ..sort((a, b) => b.compareTo(a));
      final rang =
          sorted.indexWhere((m) => (m - myMoyenne).abs() < 0.001) + 1;
      if (mounted) setState(() => _rang = rang > 0 ? rang : null);
    } catch (_) {}
  }

  // ── PDF helpers ───────────────────────────────────────────────────────────

  Future<pw.Document> _buildPdfDoc(
    String nom,
    String classe,
    List<NoteModel> notes,
    Map<String, double> moyParMatiere,
    double moyGen,
    List<AppreciationModel> appreciations,
  ) async {
    final doc = pw.Document();
    final periodLabel = _period.label;
    final now = DateFormat('dd/MM/yyyy').format(DateTime.now());

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      build: (ctx) => [
        // ── En-tête ────────────────────────────────────────────────────
        pw.Container(
          padding: const pw.EdgeInsets.all(16),
          decoration: pw.BoxDecoration(
            color: PdfColor.fromInt(0xFF1E293B),
            borderRadius: pw.BorderRadius.circular(8),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('SCOLAR AI Educative — Bulletin de notes',
                      style: pw.TextStyle(
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.white)),
                  pw.Text('Année $_anneeScol-${_anneeScol + 1}',
                      style: const pw.TextStyle(
                          fontSize: 10, color: PdfColors.grey300)),
                ],
              ),
              pw.SizedBox(height: 4),
              pw.Text('$nom • $classe • $periodLabel • Généré le $now',
                  style: const pw.TextStyle(
                      fontSize: 10, color: PdfColors.grey300)),
            ],
          ),
        ),
        pw.SizedBox(height: 16),

        // ── Moyenne générale ───────────────────────────────────────────
        pw.Container(
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(
                color: PdfColor.fromInt(0xFF6C47FF), width: 1.5),
            borderRadius: pw.BorderRadius.circular(6),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Moyenne générale',
                      style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold, fontSize: 11)),
                  pw.Text(_mention(moyGen),
                      style: const pw.TextStyle(
                          fontSize: 10, color: PdfColors.grey600)),
                ],
              ),
              pw.Text('${moyGen.toStringAsFixed(2)} / 20',
                  style: pw.TextStyle(
                      fontSize: 20,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColor.fromInt(0xFF6C47FF))),
            ],
          ),
        ),
        pw.SizedBox(height: 16),

        // ── Tableau matières ───────────────────────────────────────────
        pw.Text('Résultats par matière',
            style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold, fontSize: 13)),
        pw.SizedBox(height: 6),
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
                _pdfCell('Matière', header: true),
                _pdfCell('Moyenne', header: true),
                _pdfCell('Appréciation', header: true),
              ],
            ),
            ...moyParMatiere.entries.map((e) => pw.TableRow(
              children: [
                _pdfCell(e.key),
                _pdfCell('${e.value.toStringAsFixed(2)}/20'),
                _pdfCell(_appreciationText(e.value)),
              ],
            )),
          ],
        ),
        pw.SizedBox(height: 16),

        // ── Détail des notes ───────────────────────────────────────────
        pw.Text('Détail des notes',
            style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold, fontSize: 13)),
        pw.SizedBox(height: 6),
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
              _pdfCell(
                  n.intitule.isNotEmpty ? n.intitule : '—'),
              _pdfCell(n.matiere),
              _pdfCell(
                  '${n.note}/${n.bareme.toInt()}'),
              _pdfCell(DateFormat('dd/MM/yy')
                  .format(n.date)),
            ])),
          ],
        ),
        pw.SizedBox(height: 16),

        // ── Appréciations professeurs ──────────────────────────────────
        if (appreciations.isNotEmpty) ...[
          pw.Text('Appréciations des professeurs',
              style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold, fontSize: 13)),
          pw.SizedBox(height: 6),
          ...appreciations.where((a) => a.texte.isNotEmpty).map((a) =>
            pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 8),
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(
                    color: PdfColor.fromInt(0xFFE5E7EB), width: 0.5),
                borderRadius: pw.BorderRadius.circular(4),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    a.matiere.isNotEmpty
                        ? '${a.matiere}${a.professeurNom.isNotEmpty ? " · ${a.professeurNom}" : ""}'
                        : a.professeurNom.isNotEmpty
                            ? a.professeurNom
                            : 'Professeur',
                    style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 10,
                        color: PdfColor.fromInt(0xFF6C47FF)),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(a.texte,
                      style: const pw.TextStyle(fontSize: 10)),
                ],
              ),
            ),
          ),
          pw.SizedBox(height: 12),
        ],

        // ── Appréciation conseil ───────────────────────────────────────
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

    return doc;
  }

  Future<void> _exportPdf(
    String nom,
    String classe,
    List<NoteModel> notes,
    Map<String, double> moyParMatiere,
    double moyGen,
    List<AppreciationModel> appreciations,
  ) async {
    setState(() => _pdfLoading = true);
    try {
      final doc = await _buildPdfDoc(
          nom, classe, notes, moyParMatiere, moyGen, appreciations);
      final pdfName =
          'Bulletin_${nom.replaceAll(' ', '_')}_${_period.label}.pdf';
      await Printing.sharePdf(
          bytes: await doc.save(), filename: pdfName);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erreur PDF : $e'),
          backgroundColor: _kRed,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
        ));
      }
    } finally {
      if (mounted) setState(() => _pdfLoading = false);
    }
  }

  Future<void> _printPdf(
    String nom,
    String classe,
    List<NoteModel> notes,
    Map<String, double> moyParMatiere,
    double moyGen,
    List<AppreciationModel> appreciations,
  ) async {
    setState(() => _printLoading = true);
    try {
      final doc = await _buildPdfDoc(
          nom, classe, notes, moyParMatiere, moyGen, appreciations);
      await Printing.layoutPdf(
        onLayout: (_) async => doc.save(),
        name: 'Bulletin_${nom.replaceAll(' ', '_')}_${_period.label}',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erreur impression : $e'),
          backgroundColor: _kRed,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
        ));
      }
    } finally {
      if (mounted) setState(() => _printLoading = false);
    }
  }

  static pw.Widget _pdfCell(String text, {bool header = false}) =>
      pw.Padding(
        padding: const pw.EdgeInsets.all(6),
        child: pw.Text(
          text,
          style: pw.TextStyle(
            fontSize: 10,
            fontWeight:
                header ? pw.FontWeight.bold : null,
            color: header ? PdfColors.white : null,
          ),
        ),
      );

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: _buildAppBar(),
      body: StreamBuilder<List<NoteModel>>(
        stream: _notesStream(),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: _kPurple));
          }
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
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
            // Sélecteur période
            _PeriodTabs(
              selected: _period,
              onChanged: (p) => setState(() {
                _period = p;
                _rang = null;
              }),
            ),
            // Sélecteur année scolaire
            _YearSelector(
              selected: _anneeScol,
              years: _availableYears(),
              onChanged: (y) =>
                  setState(() {
                    _anneeScol = y;
                    _rang = null;
                  }),
            ),
            // Bandeau notification bulletin
            if (_showBanner)
              _BulletinNotifBanner(
                label: _bannerLabel,
                onDismiss: () {
                  setState(() => _showBanner = false);
                  _bannerCtrl.reverse();
                },
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

  AppBar _buildAppBar() => AppBar(
        backgroundColor: _kCard,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Bulletin & Relevé de notes',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold)),
            Text(
              'Année $_anneeScol-${_anneeScol + 1}',
              style: const TextStyle(
                  color: Colors.white38, fontSize: 11),
            ),
          ],
        ),
        actions: [
          if (_pdfLoading || _printLoading)
            const Padding(
              padding: EdgeInsets.all(14),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    color: _kPurple, strokeWidth: 2),
              ),
            ),
        ],
      );

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
      final list = s.docs.map(NoteModel.fromFirestore).toList();
      list.sort((a, b) => b.date.compareTo(a.date));
      return list;
    });
  }

  Widget _buildContent(
    List<NoteModel> allNotes,
    List<NoteModel> notes,
  ) {
    final byMatiere = <String, List<NoteModel>>{};
    for (final n in notes) {
      (byMatiere[n.matiere] ??= []).add(n);
    }

    final moyParMatiere = byMatiere.map((mat, ns) {
      final avg =
          ns.fold<double>(0, (s, n) => s + n.sur20) / ns.length;
      return MapEntry(mat, avg);
    });

    final sortedMat = moyParMatiere.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    final moyGen = moyParMatiere.values.isEmpty
        ? 0.0
        : moyParMatiere.values.reduce((a, b) => a + b) /
            moyParMatiere.length;

    final classeNom =
        notes.isNotEmpty ? notes.first.classeNom : '';
    final classeId =
        notes.isNotEmpty ? notes.first.classeId : '';

    // Démarrer le listener publication (pour la bannière in-page)
    if (classeId.isNotEmpty && _period != _Period.annee) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _listenForPublication(classeId, _period.index + 1);
      });
    }

    // Rang (direction seulement)
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

    // Notes de l'année (toutes périodes) pour graphiques
    final yearNotes = allNotes
        .where((n) => _noteInYear(n, _anneeScol))
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    // Moyennes par trimestre (pour graphique comparatif)
    final moyParTrim = <int, double>{};
    for (int t = 1; t <= 3; t++) {
      final ns = yearNotes
          .where((n) => _PeriodX.trimestreOf(n.date) == t)
          .toList();
      if (ns.isNotEmpty) {
        final byM = <String, List<double>>{};
        for (final n in ns) {
          (byM[n.matiere] ??= []).add(n.sur20);
        }
        final matAvgs =
            byM.values.map((v) => v.reduce((a, b) => a + b) / v.length);
        moyParTrim[t] =
            matAvgs.reduce((a, b) => a + b) / matAvgs.length;
      }
    }

    // Progression vs trimestre précédent
    double? prevMoy;
    if (_period != _Period.annee && _period.index > 0) {
      prevMoy = moyParTrim[_period.index]; // index 0=T1,1=T2,2=T3 → prev
    }

    return StreamBuilder<List<AppreciationModel>>(
      stream: AppreciationService.streamByEleve(
        eleveId: widget.eleveUid,
        trimestre: _period == _Period.annee ? null : _period.index + 1,
      ),
      builder: (ctx, appSnap) {
        final appreciations = appSnap.data
                ?.where((a) => a.texte.isNotEmpty)
                .toList() ??
            [];

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
          children: [
            // Badge publication Direction
            if (classeId.isNotEmpty && _period != _Period.annee)
              _PublicationBanner(
                classeId: classeId,
                trimestre: _period.index + 1,
                anneeScol: _anneeScol,
              ),

            // Hero card avec progression
            _HeroCard(
              nom: nom,
              classe: classeNom,
              periode: _period.label,
              annee: '$_anneeScol-${_anneeScol + 1}',
              moyGen: moyGen,
              mention: _mention(moyGen),
              color: _noteColor(moyGen),
              prevMoy: prevMoy,
            ),
            const SizedBox(height: 12),

            // Stats row
            _StatsRow(
              nbMatieres: byMatiere.length,
              nbNotes: notes.length,
              minNote: notes.isEmpty
                  ? 0
                  : notes
                      .map((n) => n.sur20)
                      .reduce((a, b) => a < b ? a : b),
              maxNote: notes.isEmpty
                  ? 0
                  : notes
                      .map((n) => n.sur20)
                      .reduce((a, b) => a > b ? a : b),
              rang: _rang,
            ),
            const SizedBox(height: 16),

            // Graphique comparatif T1/T2/T3
            if (moyParTrim.length >= 2) ...[
              _TrimestreBarChart(
                moyParTrim: moyParTrim,
                currentTrim: _period == _Period.annee
                    ? null
                    : _period.index + 1,
              ),
              const SizedBox(height: 16),
            ],

            // Graphique évolution notes brutes
            if (yearNotes.length >= 2) ...[
              _EvolutionChart(notes: yearNotes),
              const SizedBox(height: 16),
            ],

            // Matières
            _sectionLabel(
                'Résultats par matière', Icons.bar_chart_outlined),
            const SizedBox(height: 10),
            ...sortedMat.asMap().entries.map((e) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _MatiereCard(
                matiere: e.value.key,
                moy: e.value.value,
                notes: byMatiere[e.value.key]!,
                appreciation: _appreciationText(e.value.value),
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

            // Appréciations professeurs (depuis le stream)
            if (appreciations.isNotEmpty) ...[
              _ProfAppreciationsSection(
                  appreciations: appreciations),
              const SizedBox(height: 16),
            ],

            // Boutons PDF / Impression
            _ActionButtons(
              pdfLoading: _pdfLoading,
              printLoading: _printLoading,
              onExport: () => _exportPdf(
                  nom,
                  classeNom,
                  notes,
                  moyParMatiere,
                  moyGen,
                  appreciations),
              onPrint: () => _printPdf(
                  nom,
                  classeNom,
                  notes,
                  moyParMatiere,
                  moyGen,
                  appreciations),
            ),
          ],
        );
      },
    );
  }

  Widget _sectionLabel(String text, IconData icon) => Row(children: [
        Icon(icon, color: _kPurple, size: 16),
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
  const _PeriodTabs(
      {required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _kCard,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
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
                      ? _kPurple
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: selected == p
                        ? _kPurple
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

// ─── Year selector ────────────────────────────────────────────────────────────

class _YearSelector extends StatelessWidget {
  final int selected;
  final List<int> years;
  final ValueChanged<int> onChanged;
  const _YearSelector(
      {required this.selected,
      required this.years,
      required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _kCard2,
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
      child: Row(
        children: [
          const Icon(Icons.calendar_today_outlined,
              color: Colors.white38, size: 13),
          const SizedBox(width: 8),
          ...years.map((y) {
            final sel = y == selected;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => onChanged(y),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: sel
                        ? _kPurple.withValues(alpha: 0.15)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: sel
                          ? _kPurple.withValues(alpha: 0.5)
                          : Colors.white12,
                    ),
                  ),
                  child: Text(
                    '$y-${y + 1}',
                    style: TextStyle(
                      color: sel ? _kPurple : Colors.white38,
                      fontWeight: sel
                          ? FontWeight.bold
                          : FontWeight.normal,
                      fontSize: 11,
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ─── Bulletin notification banner ─────────────────────────────────────────────

class _BulletinNotifBanner extends StatelessWidget {
  final String label;
  final VoidCallback onDismiss;
  const _BulletinNotifBanner(
      {required this.label, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _kGreen.withValues(alpha: 0.12),
      padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
      child: Row(children: [
        const Icon(Icons.celebration_outlined,
            color: _kGreen, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
                color: _kGreen,
                fontWeight: FontWeight.w600,
                fontSize: 13),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.close,
              color: Colors.white38, size: 18),
          onPressed: onDismiss,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
      ]),
    );
  }
}

// ─── Hero card ────────────────────────────────────────────────────────────────

class _HeroCard extends StatelessWidget {
  final String nom, classe, periode, annee, mention;
  final double moyGen;
  final double? prevMoy;
  final Color color;
  const _HeroCard({
    required this.nom,
    required this.classe,
    required this.periode,
    required this.annee,
    required this.moyGen,
    required this.mention,
    required this.color,
    this.prevMoy,
  });

  @override
  Widget build(BuildContext context) {
    final delta = prevMoy != null ? moyGen - prevMoy! : null;

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
            color: _kPurple.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: _kPurple.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.description_outlined,
                  color: _kPurple, size: 20),
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
                  Text('$periode · $annee',
                      style: const TextStyle(
                          color: Colors.white38, fontSize: 11)),
                ],
              ),
            ),
            // Badge delta progression
            if (delta != null)
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: (delta >= 0 ? _kGreen : _kRed)
                      .withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: (delta >= 0 ? _kGreen : _kRed)
                        .withValues(alpha: 0.3),
                  ),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(
                    delta >= 0
                        ? Icons.trending_up
                        : Icons.trending_down,
                    color: delta >= 0 ? _kGreen : _kRed,
                    size: 14,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    '${delta >= 0 ? '+' : ''}${delta.toStringAsFixed(1)}',
                    style: TextStyle(
                        color: delta >= 0 ? _kGreen : _kRed,
                        fontWeight: FontWeight.bold,
                        fontSize: 12),
                  ),
                ]),
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
                    crossAxisAlignment:
                        CrossAxisAlignment.baseline,
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
              value: (moyGen / 20).clamp(0.0, 1.0),
              minHeight: 5,
              color: color,
              backgroundColor: color.withValues(alpha: 0.12),
            ),
          ),
          const SizedBox(height: 6),
          // Repères 10 et 14 sous la barre
          Row(children: [
            const Spacer(flex: 10),
            Text('10',
                style: TextStyle(
                    color: Colors.white24,
                    fontSize: 9)),
            const Spacer(flex: 4),
            Text('14',
                style: TextStyle(
                    color: Colors.white24,
                    fontSize: 9)),
            const Spacer(flex: 6),
          ]),
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
  const _StatsRow({
    required this.nbMatieres,
    required this.nbNotes,
    required this.minNote,
    required this.maxNote,
    this.rang,
  });

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      _StatChip(
          label: 'Matières',
          value: '$nbMatieres',
          icon: Icons.book_outlined,
          color: _kBlue),
      const SizedBox(width: 8),
      _StatChip(
          label: 'Notes',
          value: '$nbNotes',
          icon: Icons.grade_outlined,
          color: _kPurple),
      const SizedBox(width: 8),
      _StatChip(
          label: 'Max /20',
          value: maxNote.toStringAsFixed(1),
          icon: Icons.arrow_upward,
          color: _kGreen),
      const SizedBox(width: 8),
      _StatChip(
          label: rang != null ? 'Rang' : 'Min /20',
          value: rang != null
              ? '$rang'
              : minNote.toStringAsFixed(1),
          icon: rang != null
              ? Icons.emoji_events_outlined
              : Icons.arrow_downward,
          color: _kOrange),
    ]);
  }
}

class _StatChip extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _StatChip({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
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

// ─── Trimestre bar chart ──────────────────────────────────────────────────────

class _TrimestreBarChart extends StatelessWidget {
  final Map<int, double> moyParTrim;
  final int? currentTrim; // trimestre sélectionné (1-3), null = Année

  const _TrimestreBarChart(
      {required this.moyParTrim, this.currentTrim});

  Color _barColor(double v) {
    if (v >= 14) return _kGreen;
    if (v >= 10) return _kOrange;
    return _kRed;
  }

  @override
  Widget build(BuildContext context) {
    final groups = <BarChartGroupData>[];
    final labels = ['T1', 'T2', 'T3'];
    for (int t = 1; t <= 3; t++) {
      final moy = moyParTrim[t] ?? 0.0;
      final isCurrent = currentTrim == t;
      final barColor = isCurrent
          ? _kPurple
          : (moy > 0 ? _barColor(moy) : Colors.white12);
      groups.add(BarChartGroupData(
        x: t - 1,
        barRods: [
          BarChartRodData(
            toY: moy.clamp(0, 20),
            gradient: LinearGradient(
              colors: [
                barColor.withValues(alpha: isCurrent ? 1.0 : 0.7),
                barColor.withValues(alpha: isCurrent ? 0.7 : 0.4),
              ],
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
            ),
            width: 32,
            borderRadius: const BorderRadius.vertical(
                top: Radius.circular(6)),
            backDrawRodData: BackgroundBarChartRodData(
              show: true,
              toY: 20,
              color: Colors.white.withValues(alpha: 0.04),
            ),
          ),
        ],
      ));
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.bar_chart_outlined,
                color: _kPurple, size: 15),
            const SizedBox(width: 7),
            const Text('PROGRESSION PAR TRIMESTRE',
                style: TextStyle(
                    color: Colors.white38,
                    fontSize: 10,
                    letterSpacing: 1.1,
                    fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 14),
          SizedBox(
            height: 130,
            child: BarChart(BarChartData(
              maxY: 20,
              minY: 0,
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: 5,
                getDrawingHorizontalLine: (_) => FlLine(
                  color: Colors.white.withValues(alpha: 0.05),
                  strokeWidth: 1,
                ),
              ),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (v, _) {
                      final i = v.toInt();
                      if (i < 0 || i >= labels.length) {
                        return const SizedBox.shrink();
                      }
                      final isCurrent =
                          currentTrim == (i + 1);
                      return Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          labels[i],
                          style: TextStyle(
                              color: isCurrent
                                  ? _kPurple
                                  : Colors.white38,
                              fontSize: 11,
                              fontWeight: isCurrent
                                  ? FontWeight.bold
                                  : FontWeight.normal),
                        ),
                      );
                    },
                    reservedSize: 24,
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    interval: 5,
                    reservedSize: 28,
                    getTitlesWidget: (v, _) => Text(
                      '${v.toInt()}',
                      style: const TextStyle(
                          color: Colors.white24, fontSize: 9),
                    ),
                  ),
                ),
                topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
              ),
              barGroups: groups,
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (_) => _kCard2,
                  getTooltipItem: (g, _, rod, __) {
                    final t = g.x + 1;
                    final moy = moyParTrim[t] ?? 0.0;
                    return BarTooltipItem(
                      'T$t\n${moy.toStringAsFixed(2)}/20',
                      const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 11),
                    );
                  },
                ),
              ),
            )),
          ),
          const SizedBox(height: 4),
          // Moyennes texte sous les barres
          Row(children: [
            for (int t = 1; t <= 3; t++) ...[
              Expanded(
                child: Text(
                  moyParTrim[t] != null
                      ? '${moyParTrim[t]!.toStringAsFixed(1)}/20'
                      : '—',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: (currentTrim == t)
                          ? _kPurple
                          : Colors.white38,
                      fontSize: 10,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ]),
        ],
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
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.show_chart_outlined,
                color: _kBlue, size: 15),
            const SizedBox(width: 7),
            const Text('ÉVOLUTION DES NOTES',
                style: TextStyle(
                    color: Colors.white38,
                    fontSize: 10,
                    letterSpacing: 1.1,
                    fontWeight: FontWeight.w600)),
            const Spacer(),
            Text('${notes.length} notes',
                style: const TextStyle(
                    color: Colors.white24, fontSize: 10)),
          ]),
          const SizedBox(height: 10),
          Expanded(
            child: LineChart(LineChartData(
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: 5,
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
                    getTitlesWidget: (v, _) => Text(
                        '${v.toInt()}',
                        style: const TextStyle(
                            color: Colors.white38,
                            fontSize: 9)),
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
                      colors: [_kPurple, _kBlue]),
                  barWidth: 2.5,
                  isStrokeCapRound: true,
                  dotData: FlDotData(
                    show: true,
                    getDotPainter: (_, __, ___, ____) =>
                        FlDotCirclePainter(
                      radius: 3,
                      color: _kPurple,
                      strokeWidth: 1.5,
                      strokeColor: Colors.white,
                    ),
                  ),
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      colors: [
                        _kPurple.withValues(alpha: 0.2),
                        _kBlue.withValues(alpha: 0.0),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
                // Ligne de seuil 10/20
                LineChartBarData(
                  spots: [
                    FlSpot(0, 10),
                    FlSpot((spots.length - 1).toDouble(), 10),
                  ],
                  isCurved: false,
                  color: Colors.white.withValues(alpha: 0.15),
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
        color: _kCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(children: [
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
                      Text(widget.appreciation,
                          style: TextStyle(
                              color: widget.noteColor
                                  .withValues(alpha: 0.85),
                              fontSize: 11)),
                      const SizedBox(width: 6),
                      Text(
                        '${widget.notes.length} note${widget.notes.length > 1 ? 's' : ''}',
                        style: const TextStyle(
                            color: Colors.white38,
                            fontSize: 11),
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
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 6),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: (widget.moy / 20).clamp(0.0, 1.0),
              minHeight: 3,
              color: widget.noteColor,
              backgroundColor:
                  widget.noteColor.withValues(alpha: 0.1),
            ),
          ),
        ),
        if (_expanded) ...[
          const Divider(color: _kBorder, height: 1),
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
    final pct =
        note.bareme > 0 ? note.note / note.bareme : 0.0;
    final color = pct >= 0.7
        ? _kGreen
        : pct >= 0.5
            ? _kOrange
            : _kRed;
    final fmt = DateFormat('dd/MM/yy');

    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        border: Border(
            bottom: BorderSide(
                color: _kBorder.withValues(alpha: 0.5),
                width: 0.4)),
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
            note.note
                .toStringAsFixed(note.note % 1 == 0 ? 0 : 1),
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
                note.intitule.isNotEmpty
                    ? note.intitule
                    : 'Évaluation',
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
        ],
      ),
    );
  }
}

// ─── Badge de publication Direction ──────────────────────────────────────────

class _PublicationBanner extends StatelessWidget {
  final String classeId;
  final int trimestre;
  final int anneeScol;
  const _PublicationBanner({
    required this.classeId,
    required this.trimestre,
    required this.anneeScol,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<BulletinValidationModel?>(
      stream: BulletinValidationService.stream(
          classeId: classeId,
          trimestre: trimestre,
          anneeScol: anneeScol),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }
        final val = snap.data;
        final publie = val?.publie ?? false;
        if (!publie) return const SizedBox.shrink();

        final dateStr = val?.datePub != null
            ? ' · ${val!.datePub!.toDate().day.toString().padLeft(2, '0')}/'
                '${val.datePub!.toDate().month.toString().padLeft(2, '0')}/'
                '${val.datePub!.toDate().year}'
            : '';

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(
              horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: _kGreen.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: _kGreen.withValues(alpha: 0.3)),
          ),
          child: Row(children: [
            const Icon(Icons.verified_outlined,
                color: _kGreen, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Bulletin T$trimestre validé par la Direction$dateStr',
                style: const TextStyle(
                    color: _kGreen,
                    fontWeight: FontWeight.w600,
                    fontSize: 12),
              ),
            ),
          ]),
        );
      },
    );
  }
}

// ─── Appréciations professeurs ────────────────────────────────────────────────

class _ProfAppreciationsSection extends StatelessWidget {
  final List<AppreciationModel> appreciations;
  const _ProfAppreciationsSection(
      {required this.appreciations});

  static const _matiereColors = [
    _kBlue, _kTeal, _kPurple, _kOrange, Color(0xFFBE185D),
  ];

  @override
  Widget build(BuildContext context) {
    if (appreciations.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          const Icon(Icons.rate_review_outlined,
              color: _kPurple, size: 16),
          const SizedBox(width: 7),
          const Text('Appréciations des professeurs',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: _kPurple.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '${appreciations.length}',
              style: const TextStyle(
                  color: _kPurple,
                  fontWeight: FontWeight.bold,
                  fontSize: 12),
            ),
          ),
        ]),
        const SizedBox(height: 10),
        ...appreciations.asMap().entries.map((entry) {
          final a = entry.value;
          final color =
              _matiereColors[entry.key % _matiereColors.length];
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: color.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: Center(
                        child: Icon(Icons.person_outline,
                            color: color, size: 15),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          if (a.matiere.isNotEmpty)
                            Text(a.matiere,
                                style: TextStyle(
                                    color: color,
                                    fontWeight:
                                        FontWeight.bold,
                                    fontSize: 13)),
                          if (a.professeurNom.isNotEmpty)
                            Text(a.professeurNom,
                                style: const TextStyle(
                                    color: Colors.white38,
                                    fontSize: 11)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text('T${a.trimestre}',
                          style: TextStyle(
                              color: color,
                              fontWeight: FontWeight.bold,
                              fontSize: 11)),
                    ),
                  ]),
                  const SizedBox(height: 10),
                  Text(a.texte,
                      style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          height: 1.5)),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}

// ─── Boutons PDF + Impression ─────────────────────────────────────────────────

class _ActionButtons extends StatelessWidget {
  final bool pdfLoading;
  final bool printLoading;
  final VoidCallback onExport;
  final VoidCallback onPrint;
  const _ActionButtons({
    required this.pdfLoading,
    required this.printLoading,
    required this.onExport,
    required this.onPrint,
  });

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // Bouton téléchargement PDF
      SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: pdfLoading || printLoading ? null : onExport,
          icon: pdfLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2))
              : const Icon(Icons.picture_as_pdf_outlined,
                  size: 18),
          label: Text(pdfLoading
              ? 'Génération…'
              : 'Télécharger le bulletin PDF'),
          style: ElevatedButton.styleFrom(
            backgroundColor: _kPurple,
            foregroundColor: Colors.white,
            padding:
                const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            textStyle: const TextStyle(
                fontSize: 14, fontWeight: FontWeight.w600),
            disabledBackgroundColor:
                _kPurple.withValues(alpha: 0.4),
          ),
        ),
      ),
      const SizedBox(height: 10),
      // Bouton impression
      SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: pdfLoading || printLoading ? null : onPrint,
          icon: printLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      color: _kPurple, strokeWidth: 2))
              : const Icon(Icons.print_outlined, size: 18),
          label: Text(
              printLoading ? 'Préparation…' : 'Imprimer le bulletin'),
          style: OutlinedButton.styleFrom(
            foregroundColor: _kPurple,
            side: BorderSide(
                color: _kPurple.withValues(alpha: 0.5)),
            padding:
                const EdgeInsets.symmetric(vertical: 13),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            textStyle: const TextStyle(
                fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    ]);
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
          style:
              TextStyle(color: Colors.white24, fontSize: 12),
        ),
      ]),
    );
  }
}
