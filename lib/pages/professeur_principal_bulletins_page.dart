import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/appreciation_model.dart';
import '../models/bulletin_recap_model.dart';
import '../models/classe_model.dart';
import '../models/note_model.dart';
import '../models/user_model.dart';
import '../services/bulletin_recap_service.dart';
import '../services/professeur_service.dart';
import '../services/user_service.dart';
import 'eleve_releve_notes_page.dart';

// ─── Helpers top-level ────────────────────────────────────────────────────────

String _mention(double v) {
  if (v >= 16) return 'Excellent';
  if (v >= 14) return 'Bien';
  if (v >= 12) return 'Assez bien';
  if (v >= 10) return 'Passable';
  if (v >= 8) return 'Insuffisant';
  return 'Tres faible';
}

// ─── Palette ──────────────────────────────────────────────────────────────────

const _kBg     = Color(0xFF0D1117);
const _kCard   = Color(0xFF161B22);
const _kCard2  = Color(0xFF1F2937);
const _kBorder = Color(0xFF30363D);
const _kBlue   = Color(0xFF2563EB);
const _kPurple = Color(0xFF6C47FF);
const _kGreen  = Color(0xFF16A34A);
const _kOrange = Color(0xFFD97706);
const _kRed    = Color(0xFFDC2626);
const _kTeal   = Color(0xFF0F766E);

// ─── Data classes ─────────────────────────────────────────────────────────────

/// Données bulletin d'un élève calculées côté client.
class _EleveStats {
  final UserModel eleve;
  final double? moyGen;       // moyenne générale /20
  final int nbNotes;
  final Map<String, double> moyParMatiere;
  final List<AppreciationModel> appreciations;

  const _EleveStats({
    required this.eleve,
    this.moyGen,
    this.nbNotes = 0,
    this.moyParMatiere = const {},
    this.appreciations = const [],
  });

  bool get enDifficulte => moyGen != null && moyGen! < 10;
  bool get tresEnDifficulte => moyGen != null && moyGen! < 8;
}

/// Jeu de données chargé pour une classe + trimestre.
class _ClasseData {
  final List<_EleveStats> elevesStats;
  final double? moyenneClasse;
  final int nbEnDifficulte;
  final Map<String, int> distribution; // mention → count
  final int nbAvecAppreciations;

  const _ClasseData({
    required this.elevesStats,
    this.moyenneClasse,
    required this.nbEnDifficulte,
    required this.distribution,
    required this.nbAvecAppreciations,
  });
}

// ─── Entry point ──────────────────────────────────────────────────────────────

/// Module Bulletins du Professeur Principal.
///
/// Le professeur principal voit tous les bulletins de sa classe :
/// moyennes (toutes matières), appréciations de tous les enseignants,
/// classement, élèves en difficulté, statistiques et récapitulatif.
class ProfesseurPrincipalBulletinsPage extends StatefulWidget {
  const ProfesseurPrincipalBulletinsPage({super.key});

  @override
  State<ProfesseurPrincipalBulletinsPage> createState() =>
      _ProfesseurPrincipalBulletinsPageState();
}

class _ProfesseurPrincipalBulletinsPageState
    extends State<ProfesseurPrincipalBulletinsPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tc;
  ClasseModel? _selectedClasse;
  int _trimestre = _currentTrim();
  UserModel? _profUser;
  bool _loadingData = false;
  _ClasseData? _data;
  String? _loadError;

  static int _currentTrim() {
    final m = DateTime.now().month;
    if (m >= 9 && m <= 11) return 1;
    if (m == 12 || m <= 2) return 2;
    return 3;
  }

  static int _schoolYear() {
    final now = DateTime.now();
    return now.month >= 9 ? now.year : now.year - 1;
  }

  @override
  void initState() {
    super.initState();
    _tc = TabController(length: 3, vsync: this);
    UserService.currentUserStream().first.then((u) {
      if (mounted) setState(() => _profUser = u);
    });
  }

  @override
  void dispose() {
    _tc.dispose();
    super.dispose();
  }

  // ── Data loading ─────────────────────────────────────────────────────────

  Future<void> _loadData(ClasseModel classe) async {
    setState(() {
      _loadingData = true;
      _data = null;
      _loadError = null;
    });
    try {
      final db = FirebaseFirestore.instance;

      // 1. Élèves de la classe
      final elevesSnap = await db
          .collection('users')
          .where('role', isEqualTo: 'eleve')
          .where('classeNom', isEqualTo: classe.nom)
          .get();
      final eleves = elevesSnap.docs.map(UserModel.fromDoc).toList();
      eleves.sort((a, b) => a.displayName.compareTo(b.displayName));

      // 2. Toutes les notes publiées pour cette classe
      final notesSnap = await db
          .collection('notes')
          .where('classeId', isEqualTo: classe.id)
          .where('publie', isEqualTo: true)
          .get();
      final allNotes = notesSnap.docs.map(NoteModel.fromFirestore).toList();

      // Filtrer par trimestre (client-side)
      final notes = allNotes.where((n) {
        final m = n.date.month;
        int t;
        if (m >= 9 && m <= 11) { t = 1; }
        else if (m == 12 || m <= 2) { t = 2; }
        else { t = 3; }
        return t == _trimestre;
      }).toList();

      // 3. Toutes les appréciations pour cette classe + trimestre
      final appsSnap = await db
          .collection('appreciations')
          .where('classeId', isEqualTo: classe.id)
          .where('trimestre', isEqualTo: _trimestre)
          .get();
      final allApps =
          appsSnap.docs.map(AppreciationModel.fromFirestore).toList();

      // 4. Grouper par élève
      final notesByEleve = <String, List<NoteModel>>{};
      for (final n in notes) {
        (notesByEleve[n.eleveId] ??= []).add(n);
      }
      final appsByEleve = <String, List<AppreciationModel>>{};
      for (final a in allApps) {
        (appsByEleve[a.eleveId] ??= []).add(a);
      }

      // 5. Construire _EleveStats
      final stats = eleves.map((e) {
        final ns = notesByEleve[e.uid] ?? [];
        final as_ = appsByEleve[e.uid] ?? [];
        if (ns.isEmpty) {
          return _EleveStats(
            eleve: e,
            moyGen: null,
            nbNotes: 0,
            appreciations: as_,
          );
        }
        final byM = <String, List<double>>{};
        for (final n in ns) {
          (byM[n.matiere] ??= []).add(n.sur20);
        }
        final moyParM = byM.map((m, vs) {
          final avg = vs.reduce((a, b) => a + b) / vs.length;
          return MapEntry(m, avg);
        });
        final moy = moyParM.values.isEmpty
            ? null
            : moyParM.values.reduce((a, b) => a + b) / moyParM.length;
        return _EleveStats(
          eleve: e,
          moyGen: moy,
          nbNotes: ns.length,
          moyParMatiere: moyParM,
          appreciations: as_,
        );
      }).toList();

      // 6. Stats classe
      final avgs = stats
          .where((s) => s.moyGen != null)
          .map((s) => s.moyGen!)
          .toList();
      final moyClasse = avgs.isEmpty
          ? null
          : avgs.reduce((a, b) => a + b) / avgs.length;

      final dist = <String, int>{
        'Excellent': 0,
        'Bien': 0,
        'Assez bien': 0,
        'Passable': 0,
        'Insuffisant': 0,
      };
      for (final avg in avgs) {
        final m = _mention(avg);
        final k = m == 'Tres faible' ? 'Insuffisant' : m;
        dist[k] = (dist[k] ?? 0) + 1;
      }

      final nbDiff = stats.where((s) => s.enDifficulte).length;
      final nbApps = stats.where((s) => s.appreciations.isNotEmpty).length;

      if (mounted) {
        setState(() {
          _data = _ClasseData(
            elevesStats: stats,
            moyenneClasse: moyClasse,
            nbEnDifficulte: nbDiff,
            distribution: dist,
            nbAvecAppreciations: nbApps,
          );
          _loadingData = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadError = e.toString();
          _loadingData = false;
        });
      }
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kCard,
        elevation: 0,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Bulletins — Prof. Principal',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.bold)),
          if (_selectedClasse != null)
            Text(_selectedClasse!.nom,
                style: const TextStyle(
                    color: Colors.white38, fontSize: 11)),
        ]),
        bottom: _selectedClasse != null && _data != null
            ? TabBar(
                controller: _tc,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white38,
                indicatorColor: _kPurple,
                labelStyle: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 12),
                tabs: const [
                  Tab(text: 'Classement'),
                  Tab(text: 'Statistiques'),
                  Tab(text: 'Recapitulatif'),
                ],
              )
            : null,
      ),
      body: StreamBuilder<List<ClasseModel>>(
        stream: ProfesseurService.classesStream(),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: _kPurple));
          }
          final classes = snap.data ?? [];
          if (classes.isEmpty) {
            return _emptyClasses();
          }
          // Auto-select first class
          if (_selectedClasse == null && classes.isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              setState(() => _selectedClasse = classes.first);
              _loadData(classes.first);
            });
          }
          return Column(children: [
            // Sélecteur classe + trimestre
            _ClasseTrimestreHeader(
              classes: classes,
              selectedClasse: _selectedClasse,
              trimestre: _trimestre,
              onClasseChanged: (c) {
                setState(() {
                  _selectedClasse = c;
                  _data = null;
                });
                _loadData(c);
              },
              onTrimestreChanged: (t) {
                setState(() {
                  _trimestre = t;
                  _data = null;
                });
                if (_selectedClasse != null) _loadData(_selectedClasse!);
              },
            ),
            // Corps
            Expanded(child: _buildBody()),
          ]);
        },
      ),
    );
  }

  Widget _buildBody() {
    if (_loadingData) {
      return const Center(
          child: CircularProgressIndicator(color: _kPurple));
    }
    if (_loadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.lock_outline,
                color: Colors.white24, size: 42),
            const SizedBox(height: 12),
            Text(
              'Impossible de charger les données.\n\n$_loadError',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.white38, fontSize: 12),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                if (_selectedClasse != null) _loadData(_selectedClasse!);
              },
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Réessayer'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: _kPurple,
                  foregroundColor: Colors.white),
            ),
          ]),
        ),
      );
    }
    if (_selectedClasse == null || _data == null) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.class_outlined,
              color: Colors.white24, size: 48),
          const SizedBox(height: 14),
          const Text('Sélectionnez une classe',
              style: TextStyle(color: Colors.white38, fontSize: 14)),
        ]),
      );
    }

    return TabBarView(
      controller: _tc,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _ClassementTab(
          data: _data!,
          classe: _selectedClasse!,
          trimestre: _trimestre,
        ),
        _StatistiquesTab(
          data: _data!,
          classe: _selectedClasse!,
          trimestre: _trimestre,
        ),
        _RecapitulatifTab(
          classe: _selectedClasse!,
          trimestre: _trimestre,
          anneeScol: _schoolYear(),
          profUser: _profUser,
          data: _data!,
        ),
      ],
    );
  }

  Widget _emptyClasses() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.school_outlined,
              color: Colors.white24, size: 52),
          const SizedBox(height: 16),
          const Text('Aucune classe assignée',
              style: TextStyle(
                  color: Colors.white54,
                  fontSize: 15,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text(
            'Vous n\'avez aucune classe en tant que professeur principal.\nCréez une classe depuis "Gestion des élèves".',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white24, fontSize: 12),
          ),
        ]),
      ),
    );
  }
}

// ─── Header classe + trimestre ────────────────────────────────────────────────

class _ClasseTrimestreHeader extends StatelessWidget {
  final List<ClasseModel> classes;
  final ClasseModel? selectedClasse;
  final int trimestre;
  final ValueChanged<ClasseModel> onClasseChanged;
  final ValueChanged<int> onTrimestreChanged;

  const _ClasseTrimestreHeader({
    required this.classes,
    required this.selectedClasse,
    required this.trimestre,
    required this.onClasseChanged,
    required this.onTrimestreChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _kCard,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(children: [
        // Classes chips
        if (classes.length <= 6)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: classes.map((c) {
                final sel = c.id == selectedClasse?.id;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => onClasseChanged(c),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: sel ? _kBlue : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: sel ? _kBlue : Colors.white24,
                        ),
                      ),
                      child: Text(c.nom,
                          style: TextStyle(
                              color:
                                  sel ? Colors.white : Colors.white54,
                              fontWeight: sel
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              fontSize: 13)),
                    ),
                  ),
                );
              }).toList(),
            ),
          )
        else
          DropdownButton<ClasseModel>(
            value: selectedClasse,
            isExpanded: true,
            dropdownColor: _kCard2,
            underline: const SizedBox.shrink(),
            style: const TextStyle(color: Colors.white, fontSize: 13),
            items: classes
                .map((c) => DropdownMenuItem(
                      value: c,
                      child: Text(c.nom),
                    ))
                .toList(),
            onChanged: (c) {
              if (c != null) onClasseChanged(c);
            },
          ),
        const SizedBox(height: 8),
        // Trimestre chips
        Row(
          children: [1, 2, 3].map((t) {
            final sel = t == trimestre;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: GestureDetector(
                  onTap: () => onTrimestreChanged(t),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      color: sel ? _kPurple : Colors.transparent,
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(
                        color: sel ? _kPurple : Colors.white24,
                      ),
                    ),
                    child: Text('Trimestre $t',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: sel
                                ? Colors.white
                                : Colors.white38,
                            fontWeight: FontWeight.w600,
                            fontSize: 11)),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ]),
    );
  }
}

// ─── Tab 1 : Classement ───────────────────────────────────────────────────────

class _ClassementTab extends StatelessWidget {
  final _ClasseData data;
  final ClasseModel classe;
  final int trimestre;

  const _ClassementTab({
    required this.data,
    required this.classe,
    required this.trimestre,
  });

  @override
  Widget build(BuildContext context) {
    // Trier par moyenne décroissante (sans notes = en bas)
    final sorted = List<_EleveStats>.from(data.elevesStats)
      ..sort((a, b) {
        if (a.moyGen == null && b.moyGen == null) return 0;
        if (a.moyGen == null) return 1;
        if (b.moyGen == null) return -1;
        return b.moyGen!.compareTo(a.moyGen!);
      });

    if (sorted.isEmpty) {
      return const Center(
        child: Text('Aucun élève dans cette classe',
            style: TextStyle(color: Colors.white38, fontSize: 14)),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 40),
      itemCount: sorted.length,
      itemBuilder: (_, i) => _EleveRankTile(
        stats: sorted[i],
        rank: i + 1,
        trimestre: trimestre,
        totalEleves: sorted.length,
      ),
    );
  }
}

class _EleveRankTile extends StatelessWidget {
  final _EleveStats stats;
  final int rank;
  final int trimestre;
  final int totalEleves;

  const _EleveRankTile({
    required this.stats,
    required this.rank,
    required this.trimestre,
    required this.totalEleves,
  });

  @override
  Widget build(BuildContext context) {
    final moy = stats.moyGen;
    final color = moy != null
        ? (moy >= 14 ? _kGreen : moy >= 10 ? _kOrange : _kRed)
        : Colors.white24;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: stats.tresEnDifficulte
              ? _kRed.withValues(alpha: 0.3)
              : stats.enDifficulte
                  ? _kOrange.withValues(alpha: 0.2)
                  : Colors.white.withValues(alpha: 0.06),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showAppreciationsSheet(context),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Row(children: [
            // Rang
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: rank <= 3
                    ? _kOrange.withValues(alpha: 0.15)
                    : _kCard2,
                shape: BoxShape.circle,
                border: rank == 1
                    ? Border.all(
                        color: _kOrange.withValues(alpha: 0.4),
                        width: 1.5)
                    : null,
              ),
              child: Center(
                child: Text('$rank',
                    style: TextStyle(
                        color: rank <= 3 ? _kOrange : Colors.white38,
                        fontWeight: FontWeight.bold,
                        fontSize: 12)),
              ),
            ),
            const SizedBox(width: 10),
            // Avatar
            CircleAvatar(
              radius: 16,
              backgroundColor: _kPurple.withValues(alpha: 0.15),
              child: Text(
                stats.eleve.displayName.isNotEmpty
                    ? stats.eleve.displayName[0].toUpperCase()
                    : '?',
                style: const TextStyle(
                    color: _kPurple,
                    fontWeight: FontWeight.bold,
                    fontSize: 13),
              ),
            ),
            const SizedBox(width: 10),
            // Nom + infos
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(stats.eleve.displayName,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  Row(children: [
                    Text(
                      '${stats.nbNotes} note${stats.nbNotes > 1 ? 's' : ''}',
                      style: const TextStyle(
                          color: Colors.white38, fontSize: 11),
                    ),
                    if (stats.appreciations.isNotEmpty) ...[
                      const Text(' · ',
                          style: TextStyle(
                              color: Colors.white24, fontSize: 11)),
                      Icon(Icons.rate_review_outlined,
                          color: _kPurple, size: 11),
                      Text(
                        ' ${stats.appreciations.length}',
                        style: const TextStyle(
                            color: Colors.white38, fontSize: 11),
                      ),
                    ],
                    if (stats.enDifficulte) ...[
                      const SizedBox(width: 6),
                      Icon(
                        stats.tresEnDifficulte
                            ? Icons.warning_outlined
                            : Icons.info_outline,
                        color: stats.tresEnDifficulte
                            ? _kRed
                            : _kOrange,
                        size: 12,
                      ),
                    ],
                  ]),
                ],
              ),
            ),
            // Moyenne
            if (moy != null)
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: color.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('${moy.toStringAsFixed(2)}/20',
                        style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.bold,
                            fontSize: 13)),
                    Text(
                      _mention(moy),
                      style: TextStyle(
                          color: color.withValues(alpha: 0.7),
                          fontSize: 9),
                    ),
                  ],
                ),
              )
            else
              const Text('—',
                  style: TextStyle(
                      color: Colors.white24, fontSize: 13)),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right,
                color: Colors.white24, size: 16),
          ]),
        ),
      ),
    );
  }

  void _showAppreciationsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: _kCard,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _EleveAppreciationsSheet(
        stats: stats,
        trimestre: trimestre,
      ),
    );
  }
}

// ─── Bottom sheet appréciations élève ────────────────────────────────────────

class _EleveAppreciationsSheet extends StatelessWidget {
  final _EleveStats stats;
  final int trimestre;
  const _EleveAppreciationsSheet(
      {required this.stats, required this.trimestre});

  @override
  Widget build(BuildContext context) {
    final moy = stats.moyGen;
    final color = moy != null
        ? (moy >= 14 ? _kGreen : moy >= 10 ? _kOrange : _kRed)
        : Colors.white38;

    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      maxChildSize: 0.92,
      minChildSize: 0.35,
      expand: false,
      builder: (ctx, ctrl) => Column(children: [
        // Handle
        Container(
          margin: const EdgeInsets.only(top: 10, bottom: 8),
          width: 36,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.white24,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        // Header élève
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          child: Row(children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: _kPurple.withValues(alpha: 0.15),
              child: Text(
                stats.eleve.displayName.isNotEmpty
                    ? stats.eleve.displayName[0].toUpperCase()
                    : '?',
                style: const TextStyle(
                    color: _kPurple,
                    fontWeight: FontWeight.bold,
                    fontSize: 18),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(stats.eleve.displayName,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16)),
                  Text(
                    moy != null
                        ? 'Moy. T$trimestre : ${moy.toStringAsFixed(2)}/20 · ${_mention(moy)}'
                        : 'Aucune note pour T$trimestre',
                    style: TextStyle(
                        color: color,
                        fontSize: 12,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            // Bouton bulletin complet
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => EleveReleveNotesPage(
                      eleveUid: stats.eleve.uid,
                      eleveNom: stats.eleve.displayName,
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _kPurple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                textStyle: const TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w600),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Bulletin'),
            ),
          ]),
        ),
        // Moyennes par matière
        if (stats.moyParMatiere.isNotEmpty) ...[
          const Divider(color: _kBorder, height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Résultats par matière',
                  style: TextStyle(
                      color: Colors.white54,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 8,
              runSpacing: 6,
              children: stats.moyParMatiere.entries.map((e) {
                final c = e.value >= 14
                    ? _kGreen
                    : e.value >= 10
                        ? _kOrange
                        : _kRed;
                return Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: c.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: c.withValues(alpha: 0.25)),
                  ),
                  child: RichText(
                    text: TextSpan(children: [
                      TextSpan(
                          text: e.key,
                          style: const TextStyle(
                              color: Colors.white60,
                              fontSize: 11)),
                      TextSpan(
                          text:
                              '  ${e.value.toStringAsFixed(1)}/20',
                          style: TextStyle(
                              color: c,
                              fontWeight: FontWeight.bold,
                              fontSize: 11)),
                    ]),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),
        ],
        // Appréciations
        const Divider(color: _kBorder, height: 1),
        Expanded(
          child: stats.appreciations.isEmpty
              ? const Center(
                  child: Text(
                    'Aucune appréciation pour ce trimestre',
                    style: TextStyle(
                        color: Colors.white38, fontSize: 13),
                  ),
                )
              : ListView.separated(
                  controller: ctrl,
                  padding:
                      const EdgeInsets.fromLTRB(16, 10, 16, 24),
                  itemCount: stats.appreciations.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: 8),
                  itemBuilder: (_, i) =>
                      _AppreciationCard(app: stats.appreciations[i]),
                ),
        ),
      ]),
    );
  }
}

// ─── Carte appréciation ───────────────────────────────────────────────────────

class _AppreciationCard extends StatelessWidget {
  final AppreciationModel app;
  const _AppreciationCard({required this.app});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kCard2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: _kPurple.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _kPurple.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                app.matiere.isNotEmpty
                    ? app.matiere
                    : 'Général',
                style: const TextStyle(
                    color: _kPurple,
                    fontWeight: FontWeight.bold,
                    fontSize: 11),
              ),
            ),
            const SizedBox(width: 8),
            if (app.professeurNom.isNotEmpty)
              Expanded(
                child: Text(
                  app.professeurNom,
                  style: const TextStyle(
                      color: Colors.white38, fontSize: 11),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ]),
          const SizedBox(height: 8),
          Text(app.texte,
              style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  height: 1.5)),
        ],
      ),
    );
  }
}

// ─── Tab 2 : Statistiques ─────────────────────────────────────────────────────

class _StatistiquesTab extends StatelessWidget {
  final _ClasseData data;
  final ClasseModel classe;
  final int trimestre;

  const _StatistiquesTab({
    required this.data,
    required this.classe,
    required this.trimestre,
  });

  @override
  Widget build(BuildContext context) {
    final diffEleves = data.elevesStats
        .where((s) => s.enDifficulte)
        .toList()
      ..sort((a, b) => (a.moyGen ?? 20).compareTo(b.moyGen ?? 20));

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 40),
      children: [
        // KPIs
        _KpiRow(data: data, trimestre: trimestre),
        const SizedBox(height: 16),

        // Barre progression appréciations
        _AppreciationsProgress(
          done: data.nbAvecAppreciations,
          total: data.elevesStats.length,
        ),
        const SizedBox(height: 16),

        // Distribution mentions
        _DistributionChart(
            distribution: data.distribution,
            total: data.elevesStats
                .where((s) => s.moyGen != null)
                .length),
        const SizedBox(height: 16),

        // Élèves en difficulté
        if (diffEleves.isNotEmpty) ...[
          _sectionLabel(
              'Eleves en difficulte (${diffEleves.length})',
              Icons.warning_amber_outlined,
              _kRed),
          const SizedBox(height: 10),
          ...diffEleves.map((s) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _DifficulteCard(stats: s, trimestre: trimestre),
          )),
        ],
      ],
    );
  }

  Widget _sectionLabel(String text, IconData icon, Color color) =>
      Row(children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 7),
        Expanded(
          child: Text(text,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700)),
        ),
      ]);
}

class _KpiRow extends StatelessWidget {
  final _ClasseData data;
  final int trimestre;
  const _KpiRow({required this.data, required this.trimestre});

  @override
  Widget build(BuildContext context) {
    final moy = data.moyenneClasse;
    final color = moy != null
        ? (moy >= 14 ? _kGreen : moy >= 10 ? _kOrange : _kRed)
        : Colors.white38;

    return Column(children: [
      // Grande carte moy classe
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              _kPurple.withValues(alpha: 0.2),
              _kBlue.withValues(alpha: 0.1),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: _kPurple.withValues(alpha: 0.3)),
        ),
        child: Row(children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Moyenne de classe',
                    style: TextStyle(
                        color: Colors.white54, fontSize: 12)),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment:
                      CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      moy != null
                          ? moy.toStringAsFixed(2)
                          : '—',
                      style: TextStyle(
                          color: color,
                          fontSize: 36,
                          fontWeight: FontWeight.bold),
                    ),
                    if (moy != null)
                      Text(' /20',
                          style: TextStyle(
                              color: color.withValues(alpha: 0.7),
                              fontSize: 14)),
                  ],
                ),
                if (moy != null)
                  Container(
                    margin: const EdgeInsets.only(top: 6),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _mention(moy),
                      style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.bold,
                          fontSize: 12),
                    ),
                  ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('Trimestre $trimestre',
                  style: const TextStyle(
                      color: Colors.white38, fontSize: 11)),
              const SizedBox(height: 12),
              Text('${data.elevesStats.length} élèves',
                  style: const TextStyle(
                      color: Colors.white38, fontSize: 11)),
            ],
          ),
        ]),
      ),
      const SizedBox(height: 10),
      // 3 mini KPIs
      Row(children: [
        _MiniKpi(
          label: 'En difficulte',
          value: '${data.nbEnDifficulte}',
          icon: Icons.trending_down_outlined,
          color: data.nbEnDifficulte > 0 ? _kRed : _kGreen,
        ),
        const SizedBox(width: 8),
        _MiniKpi(
          label: 'Avec appreciation',
          value: '${data.nbAvecAppreciations}',
          icon: Icons.rate_review_outlined,
          color: _kPurple,
        ),
        const SizedBox(width: 8),
        _MiniKpi(
          label: 'Reussite',
          value: data.elevesStats.isEmpty
              ? '—'
              : '${((data.elevesStats.where((s) => (s.moyGen ?? 0) >= 10).length / data.elevesStats.length) * 100).round()}%',
          icon: Icons.check_circle_outline,
          color: _kGreen,
        ),
      ]),
    ]);
  }
}

class _MiniKpi extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _MiniKpi(
      {required this.label,
      required this.value,
      required this.icon,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding:
            const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 6),
          Text(value,
              style: TextStyle(
                  color: color,
                  fontSize: 16,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(
                  color: Colors.white38, fontSize: 9),
              textAlign: TextAlign.center),
        ]),
      ),
    );
  }
}

class _AppreciationsProgress extends StatelessWidget {
  final int done;
  final int total;
  const _AppreciationsProgress(
      {required this.done, required this.total});

  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? done / total : 0.0;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.rate_review_outlined,
                color: _kPurple, size: 15),
            const SizedBox(width: 7),
            const Text('Complétude des appréciations',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700)),
            const Spacer(),
            Text('$done/$total',
                style: const TextStyle(
                    color: Colors.white38, fontSize: 12)),
          ]),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct.clamp(0.0, 1.0),
              minHeight: 8,
              color: pct >= 0.8
                  ? _kGreen
                  : pct >= 0.5
                      ? _kOrange
                      : _kRed,
              backgroundColor:
                  Colors.white.withValues(alpha: 0.06),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            pct >= 1.0
                ? 'Tous les élèves ont au moins une appréciation'
                : '${total - done} élève(s) sans appréciation',
            style: const TextStyle(
                color: Colors.white38, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _DistributionChart extends StatelessWidget {
  final Map<String, int> distribution;
  final int total;
  const _DistributionChart(
      {required this.distribution, required this.total});

  static const _colors = {
    'Excellent': _kGreen,
    'Bien': Color(0xFF22C55E),
    'Assez bien': _kTeal,
    'Passable': _kOrange,
    'Insuffisant': _kRed,
  };

  @override
  Widget build(BuildContext context) {
    if (total == 0) return const SizedBox.shrink();

    final groups = <BarChartGroupData>[];
    final labels = distribution.keys.toList();
    for (int i = 0; i < labels.length; i++) {
      final key = labels[i];
      final count = distribution[key] ?? 0;
      final color = _colors[key] ?? Colors.white38;
      groups.add(BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(
            toY: count.toDouble(),
            color: color.withValues(alpha: 0.75),
            width: 22,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(5)),
            backDrawRodData: BackgroundBarChartRodData(
              show: true,
              toY: total.toDouble(),
              color: Colors.white.withValues(alpha: 0.03),
            ),
          ),
        ],
      ));
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [
            Icon(Icons.bar_chart_outlined,
                color: _kBlue, size: 15),
            SizedBox(width: 7),
            Text('DISTRIBUTION DES MENTIONS',
                style: TextStyle(
                    color: Colors.white38,
                    fontSize: 10,
                    letterSpacing: 1.1,
                    fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 14),
          SizedBox(
            height: 110,
            child: BarChart(BarChartData(
              maxY: total.toDouble(),
              gridData: const FlGridData(show: false),
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
                      final abbr = labels[i].length > 7
                          ? labels[i].substring(0, 6)
                          : labels[i];
                      return Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(abbr,
                            style: const TextStyle(
                                color: Colors.white38,
                                fontSize: 8)),
                      );
                    },
                    reservedSize: 22,
                  ),
                ),
                leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
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
                    final key = labels[g.x];
                    return BarTooltipItem(
                      '$key\n${rod.toY.toInt()} élève(s)',
                      const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 10),
                    );
                  },
                ),
              ),
            )),
          ),
          // Légende
          const SizedBox(height: 6),
          Wrap(
            spacing: 10,
            runSpacing: 4,
            children: distribution.entries.map((e) {
              final color = _colors[e.key] ?? Colors.white38;
              return Row(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(2)),
                ),
                const SizedBox(width: 4),
                Text('${e.key} (${e.value})',
                    style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 10)),
              ]);
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _DifficulteCard extends StatelessWidget {
  final _EleveStats stats;
  final int trimestre;
  const _DifficulteCard(
      {required this.stats, required this.trimestre});

  @override
  Widget build(BuildContext context) {
    final moy = stats.moyGen ?? 0;
    final color = moy < 8 ? _kRed : _kOrange;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(children: [
        Icon(
          moy < 8
              ? Icons.warning_outlined
              : Icons.info_outline,
          color: color,
          size: 16,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(stats.eleve.displayName,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 13)),
              Text(
                '${stats.moyParMatiere.entries.where((e) => e.value < 10).length} matière(s) insuffisante(s)',
                style: const TextStyle(
                    color: Colors.white38, fontSize: 11),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '${moy.toStringAsFixed(2)}/20',
            style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 13),
          ),
        ),
      ]),
    );
  }
}

// ─── Tab 3 : Récapitulatif ────────────────────────────────────────────────────

class _RecapitulatifTab extends StatefulWidget {
  final ClasseModel classe;
  final int trimestre;
  final int anneeScol;
  final UserModel? profUser;
  final _ClasseData data;

  const _RecapitulatifTab({
    required this.classe,
    required this.trimestre,
    required this.anneeScol,
    required this.profUser,
    required this.data,
  });

  @override
  State<_RecapitulatifTab> createState() =>
      _RecapitulatifTabState();
}

class _RecapitulatifTabState extends State<_RecapitulatifTab> {
  final _ctrlGeneral = TextEditingController();
  final _ctrlForts = TextEditingController();
  final _ctrlAmeliorer = TextEditingController();
  final _ctrlObjectifs = TextEditingController();
  bool _dirty = false;
  bool _saving = false;
  bool _initialized = false;

  @override
  void dispose() {
    _ctrlGeneral.dispose();
    _ctrlForts.dispose();
    _ctrlAmeliorer.dispose();
    _ctrlObjectifs.dispose();
    super.dispose();
  }

  void _initFromRecap(BulletinRecapModel? recap) {
    if (_initialized) return;
    _initialized = true;
    if (recap == null) return;
    _ctrlGeneral.text = recap.texteGeneral;
    _ctrlForts.text = recap.pointsForts;
    _ctrlAmeliorer.text = recap.pointsAmeliorer;
    _ctrlObjectifs.text = recap.objectifs;
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final uid =
          FirebaseAuth.instance.currentUser?.uid ?? '';
      final nom = widget.profUser?.displayName ?? '';
      final recap = BulletinRecapModel(
        id: BulletinRecapModel.docId(
          classeId: widget.classe.id,
          trimestre: widget.trimestre,
          anneeScol: widget.anneeScol,
        ),
        classeId: widget.classe.id,
        classeNom: widget.classe.nom,
        trimestre: widget.trimestre,
        anneeScol: widget.anneeScol,
        profPrincipalId: uid,
        profPrincipalNom: nom,
        texteGeneral: _ctrlGeneral.text.trim(),
        pointsForts: _ctrlForts.text.trim(),
        pointsAmeliorer: _ctrlAmeliorer.text.trim(),
        objectifs: _ctrlObjectifs.text.trim(),
        publie: true,
      );
      await BulletinRecapService.save(recap);
      if (mounted) {
        setState(() {
          _dirty = false;
          _saving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Row(children: [
            Icon(Icons.check_circle_outline,
                color: Colors.white, size: 16),
            SizedBox(width: 8),
            Text('Récapitulatif enregistré'),
          ]),
          backgroundColor: _kGreen,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 2),
        ));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erreur : $e'),
          backgroundColor: _kRed,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<BulletinRecapModel?>(
      stream: BulletinRecapService.stream(
        classeId: widget.classe.id,
        trimestre: widget.trimestre,
        anneeScol: widget.anneeScol,
      ),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting &&
            !_initialized) {
          return const Center(
              child: CircularProgressIndicator(color: _kPurple));
        }
        _initFromRecap(snap.data);

        return ListView(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 40),
          children: [
            // En-tête
            _RecapHeader(
              classe: widget.classe,
              trimestre: widget.trimestre,
              anneeScol: widget.anneeScol,
              data: widget.data,
              recap: snap.data,
            ),
            const SizedBox(height: 16),

            // Champs
            _RecapField(
              label: 'Appréciation générale de la classe',
              icon: Icons.comment_outlined,
              hint: 'La classe ${widget.classe.nom} a globalement...',
              controller: _ctrlGeneral,
              minLines: 4,
              onChanged: () =>
                  setState(() => _dirty = true),
            ),
            const SizedBox(height: 12),
            _RecapField(
              label: 'Points forts collectifs',
              icon: Icons.thumb_up_outlined,
              hint: 'Les élèves se distinguent par...',
              controller: _ctrlForts,
              minLines: 3,
              accentColor: _kGreen,
              onChanged: () =>
                  setState(() => _dirty = true),
            ),
            const SizedBox(height: 12),
            _RecapField(
              label: 'Points à améliorer',
              icon: Icons.trending_up_outlined,
              hint: 'Des efforts sont nécessaires en...',
              controller: _ctrlAmeliorer,
              minLines: 3,
              accentColor: _kOrange,
              onChanged: () =>
                  setState(() => _dirty = true),
            ),
            const SizedBox(height: 12),
            _RecapField(
              label: 'Objectifs pour le prochain trimestre',
              icon: Icons.flag_outlined,
              hint: 'Pour le trimestre suivant, la classe devra...',
              controller: _ctrlObjectifs,
              minLines: 3,
              accentColor: _kBlue,
              onChanged: () =>
                  setState(() => _dirty = true),
            ),
            const SizedBox(height: 20),

            // Bouton sauvegarde
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: (_saving || !_dirty) ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2))
                    : const Icon(
                        Icons.save_outlined,
                        size: 18),
                label: Text(_saving
                    ? 'Enregistrement...'
                    : _dirty
                        ? 'Enregistrer le recapitulatif'
                        : 'Recapitulatif a jour'),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      _dirty ? _kPurple : _kCard2,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  textStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600),
                  disabledBackgroundColor: _kCard2,
                  disabledForegroundColor: Colors.white38,
                ),
              ),
            ),

            // Date dernière sauvegarde
            if (snap.data?.dateRecap != null) ...[
              const SizedBox(height: 8),
              Center(
                child: Text(
                  'Dernière save : ${DateFormat('dd/MM/yyyy HH:mm').format(snap.data!.dateRecap!.toDate())}',
                  style: const TextStyle(
                      color: Colors.white24, fontSize: 10),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

// ── En-tête recap ─────────────────────────────────────────────────────────────

class _RecapHeader extends StatelessWidget {
  final ClasseModel classe;
  final int trimestre;
  final int anneeScol;
  final _ClasseData data;
  final BulletinRecapModel? recap;

  const _RecapHeader({
    required this.classe,
    required this.trimestre,
    required this.anneeScol,
    required this.data,
    this.recap,
  });

  @override
  Widget build(BuildContext context) {
    final moy = data.moyenneClasse;
    final color = moy != null
        ? (moy >= 14 ? _kGreen : moy >= 10 ? _kOrange : _kRed)
        : Colors.white38;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _kPurple.withValues(alpha: 0.15),
            _kBlue.withValues(alpha: 0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: _kPurple.withValues(alpha: 0.25)),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: _kPurple.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.edit_note_outlined,
              color: _kPurple, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${classe.nom} · Trimestre $trimestre',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14)),
              Text('Année $anneeScol-${anneeScol + 1}',
                  style: const TextStyle(
                      color: Colors.white38, fontSize: 11)),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              moy != null
                  ? '${moy.toStringAsFixed(2)}/20'
                  : '—',
              style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 18),
            ),
            const Text('Moy. classe',
                style: TextStyle(
                    color: Colors.white38, fontSize: 9)),
            if (recap?.publie == true)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_circle,
                          color: _kGreen, size: 11),
                      const SizedBox(width: 3),
                      const Text('Publié',
                          style: TextStyle(
                              color: _kGreen,
                              fontSize: 10,
                              fontWeight: FontWeight.bold)),
                    ]),
              ),
          ],
        ),
      ]),
    );
  }
}

// ── Champ récapitulatif ────────────────────────────────────────────────────────

class _RecapField extends StatelessWidget {
  final String label;
  final String hint;
  final IconData icon;
  final TextEditingController controller;
  final int minLines;
  final Color accentColor;
  final VoidCallback onChanged;

  const _RecapField({
    required this.label,
    required this.hint,
    required this.icon,
    required this.controller,
    required this.minLines,
    this.accentColor = _kPurple,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(icon, color: accentColor, size: 14),
        const SizedBox(width: 6),
        Text(label,
            style: TextStyle(
                color: accentColor,
                fontWeight: FontWeight.w700,
                fontSize: 12)),
      ]),
      const SizedBox(height: 6),
      TextField(
        controller: controller,
        onChanged: (_) => onChanged(),
        minLines: minLines,
        maxLines: null,
        style: const TextStyle(
            color: Colors.white, fontSize: 13, height: 1.5),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(
              color: Colors.white24, fontSize: 12),
          filled: true,
          fillColor: _kCard,
          contentPadding: const EdgeInsets.all(14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(
                color: accentColor.withValues(alpha: 0.2)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(
                color: _kBorder.withValues(alpha: 0.6)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(
                color: accentColor.withValues(alpha: 0.6)),
          ),
        ),
      ),
    ]);
  }
}

