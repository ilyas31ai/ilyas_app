import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/appreciation_model.dart';
import '../models/bulletin_validation_model.dart';
import '../models/classe_model.dart';
import '../models/note_model.dart';
import '../models/user_model.dart';
import '../services/bulletin_validation_service.dart';
import '../services/user_service.dart';
import 'eleve_releve_notes_page.dart';

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

// ─── Data helpers ─���────────────────────────────────────���──────────────────────

/// Données de bulletin agrégées pour un élève sur un trimestre.
class _EleveData {
  final UserModel eleve;
  final double? moyenne;
  final int nbNotes;
  final List<AppreciationModel> appreciations;

  const _EleveData({
    required this.eleve,
    this.moyenne,
    this.nbNotes = 0,
    this.appreciations = const [],
  });
}

/// Statistiques agrégées pour une classe sur un trimestre.
class _ClasseStats {
  final double? moyenneClasse;
  final int nbEleves;
  final int nbAvecNotes;
  final Map<String, int> distribution; // mention → count
  final List<_EleveData> elevesData;

  const _ClasseStats({
    this.moyenneClasse,
    required this.nbEleves,
    required this.nbAvecNotes,
    required this.distribution,
    required this.elevesData,
  });
}

int _trimestreDe(DateTime d) {
  final m = d.month;
  if (m >= 9 && m <= 11) return 1;
  if (m == 12 || m <= 2) return 2;
  return 3;
}

String _mention(double v) {
  if (v >= 16) return 'Excellent';
  if (v >= 14) return 'Bien';
  if (v >= 12) return 'Assez bien';
  if (v >= 10) return 'Passable';
  if (v >= 8)  return 'Insuffisant';
  return 'Tres faible';
}

Color _mentionColor(double v) {
  if (v >= 14) return _kGreen;
  if (v >= 10) return _kOrange;
  return _kRed;
}

// ─── Entry point ────────────────────────���─────────────────────────────────────

/// Module Direction — consultation globale des bulletins.
///
/// Sources de données partagées avec élèves et parents.
/// La Direction consulte sans jamais modifier les notes des enseignants.
class DirectionBulletinsConsulterPage extends StatefulWidget {
  const DirectionBulletinsConsulterPage({super.key});

  @override
  State<DirectionBulletinsConsulterPage> createState() =>
      _DirectionBulletinsConsulterPageState();
}

class _DirectionBulletinsConsulterPageState
    extends State<DirectionBulletinsConsulterPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tc;
  final int _anneeScol = DateTime.now().year;
  int _trimestre = _currentTrim();
  bool _searchMode = false;
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  String _dirNom = '';

  static int _currentTrim() {
    final m = DateTime.now().month;
    if (m >= 9 && m <= 11) return 1;
    if (m == 12 || m <= 2) return 2;
    return 3;
  }

  @override
  void initState() {
    super.initState();
    _tc = TabController(length: 3, vsync: this);
    _searchCtrl.addListener(() {
      setState(() => _searchQuery = _searchCtrl.text.trim().toLowerCase());
    });
    UserService.currentUserStream().first.then((u) {
      if (mounted && u != null) setState(() => _dirNom = u.displayName);
    });
  }

  @override
  void dispose() {
    _tc.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: _buildAppBar(),
      body: Column(children: [
        // Barre de recherche (visible si mode recherche)
        if (_searchMode) _SearchBar(controller: _searchCtrl),
        // Sélecteur trimestre
        _TrimestreChips(
          selected: _trimestre,
          onChanged: (t) => setState(() => _trimestre = t),
        ),
        // TabBar
        Container(
          color: _kCard,
          child: TabBar(
            controller: _tc,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white38,
            indicatorColor: _kPurple,
            labelStyle: const TextStyle(
                fontWeight: FontWeight.w700, fontSize: 13),
            tabs: const [
              Tab(text: 'Classes'),
              Tab(text: 'Recherche'),
              Tab(text: 'Statistiques'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tc,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _ClassesTab(
                  trimestre: _trimestre,
                  anneeScol: _anneeScol,
                  dirNom: _dirNom),
              _RechercheTab(query: _searchQuery),
              _StatistiquesTab(
                  trimestre: _trimestre, anneeScol: _anneeScol),
            ],
          ),
        ),
      ]),
    );
  }

  AppBar _buildAppBar() => AppBar(
        backgroundColor: _kCard,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Bulletins — Direction',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold)),
            Text('Consultation globale · $_anneeScol',
                style: const TextStyle(
                    color: Colors.white38, fontSize: 11)),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              _searchMode ? Icons.search_off : Icons.search,
              color: _searchMode ? _kPurple : Colors.white54,
            ),
            onPressed: () {
              setState(() {
                _searchMode = !_searchMode;
                if (!_searchMode) {
                  _searchCtrl.clear();
                  _tc.animateTo(0);
                } else {
                  _tc.animateTo(1);
                }
              });
            },
          ),
        ],
      );
}

// ─── Barre de recherche ─────��─────────────────────────────────────────────────

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  const _SearchBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _kCard2,
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
      child: TextField(
        controller: controller,
        autofocus: true,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Rechercher un élève par nom…',
          hintStyle:
              const TextStyle(color: Colors.white38, fontSize: 13),
          prefixIcon:
              const Icon(Icons.person_search, color: Colors.white38),
          suffixIcon: controller.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear,
                      color: Colors.white38, size: 18),
                  onPressed: controller.clear,
                )
              : null,
          filled: true,
          fillColor: _kCard,
          contentPadding: const EdgeInsets.symmetric(
              horizontal: 14, vertical: 10),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _kBorder)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _kBorder)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _kPurple)),
        ),
      ),
    );
  }
}

// ─── Sélecteur trimestre ──────────────────────────────────────────────────────

class _TrimestreChips extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onChanged;
  const _TrimestreChips(
      {required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _kCard,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      child: Row(
        children: [1, 2, 3].map((t) {
          final sel = t == selected;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: GestureDetector(
                onTap: () => onChanged(t),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  decoration: BoxDecoration(
                    color: sel ? _kPurple : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: sel ? _kPurple : Colors.white24),
                  ),
                  child: Text('T$t',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: sel ? Colors.white : Colors.white38,
                          fontWeight: FontWeight.bold,
                          fontSize: 13)),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─── Tab 1 : Classes ──────────────────────────────────────────────────────────

class _ClassesTab extends StatelessWidget {
  final int trimestre;
  final int anneeScol;
  final String dirNom;
  const _ClassesTab(
      {required this.trimestre,
      required this.anneeScol,
      required this.dirNom});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('classes')
          .orderBy('nom')
          .snapshots(),
      builder: (ctx, snapC) {
        if (snapC.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: _kPurple));
        }
        final classes = snapC.data?.docs
                .map(ClasseModel.fromFirestore)
                .toList() ??
            [];
        if (classes.isEmpty) {
          return _empty('Aucune classe',
              'Créez des classes depuis la gestion des classes.');
        }
        return StreamBuilder<List<BulletinValidationModel>>(
          stream: BulletinValidationService.streamAll(anneeScol),
          builder: (ctx2, snapV) {
            final vals = {
              for (final v in snapV.data ?? []) v.id: v
            };
            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 40),
              itemCount: classes.length,
              itemBuilder: (_, i) => _ClasseCard(
                classe: classes[i],
                trimestre: trimestre,
                anneeScol: anneeScol,
                validation: vals[BulletinValidationModel.docId(
                  classeId: classes[i].id,
                  trimestre: trimestre,
                  anneeScol: anneeScol,
                )],
                dirNom: dirNom,
              ),
            );
          },
        );
      },
    );
  }

  Widget _empty(String title, String sub) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.class_outlined,
                color: Colors.white24, size: 48),
            const SizedBox(height: 14),
            Text(title,
                style: const TextStyle(
                    color: Colors.white54, fontSize: 15)),
            const SizedBox(height: 6),
            Text(sub,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.white24, fontSize: 12)),
          ]),
        ),
      );
}

// ─── Carte classe ─────────────────────────────────────────────────────────────

class _ClasseCard extends StatefulWidget {
  final ClasseModel classe;
  final int trimestre;
  final int anneeScol;
  final BulletinValidationModel? validation;
  final String dirNom;
  const _ClasseCard({
    required this.classe,
    required this.trimestre,
    required this.anneeScol,
    required this.validation,
    required this.dirNom,
  });

  @override
  State<_ClasseCard> createState() => _ClasseCardState();
}

class _ClasseCardState extends State<_ClasseCard> {
  bool _publishing = false;

  Future<void> _togglePublish() async {
    final publie = widget.validation?.publie ?? false;
    setState(() => _publishing = true);
    try {
      await BulletinValidationService.publish(
        classeId: widget.classe.id,
        classeNom: widget.classe.nom,
        trimestre: widget.trimestre,
        anneeScol: widget.anneeScol,
        publie: !publie,
        directionNom: widget.dirNom,
      );
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final publie = widget.validation?.publie ?? false;
    final ts = widget.validation?.datePub;
    final dateStr = ts != null
        ? DateFormat('dd/MM/yy').format(ts.toDate())
        : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: publie
              ? _kGreen.withValues(alpha: 0.25)
              : Colors.white.withValues(alpha: 0.06),
        ),
      ),
      child: Column(children: [
        // Header classe
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
          child: Row(children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _kBlue.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  widget.classe.nom.isNotEmpty
                      ? widget.classe.nom[0]
                      : '?',
                  style: const TextStyle(
                      color: _kBlue,
                      fontWeight: FontWeight.bold,
                      fontSize: 15),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.classe.nom,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14)),
                  Row(children: [
                    if (widget.classe.niveau.isNotEmpty)
                      Text(widget.classe.niveau,
                          style: const TextStyle(
                              color: Colors.white38, fontSize: 11)),
                    if (widget.classe.niveau.isNotEmpty)
                      const Text(' · ',
                          style: TextStyle(
                              color: Colors.white24, fontSize: 11)),
                    Icon(
                      publie
                          ? Icons.verified_outlined
                          : Icons.hourglass_empty_outlined,
                      color: publie ? _kGreen : Colors.white24,
                      size: 12,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      publie
                          ? 'Publié${dateStr != null ? ' · $dateStr' : ''}'
                          : 'Non publié',
                      style: TextStyle(
                          color: publie ? _kGreen : Colors.white38,
                          fontSize: 11),
                    ),
                  ]),
                ],
              ),
            ),
            // Toggle publish
            GestureDetector(
              onTap: _publishing ? null : _togglePublish,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: publie
                      ? _kRed.withValues(alpha: 0.12)
                      : _kGreen.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: publie
                        ? _kRed.withValues(alpha: 0.3)
                        : _kGreen.withValues(alpha: 0.3),
                  ),
                ),
                child: _publishing
                    ? SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: publie ? _kRed : _kGreen,
                        ))
                    : Text(
                        publie ? 'Retirer' : 'Publier',
                        style: TextStyle(
                            color: publie ? _kRed : _kGreen,
                            fontSize: 11,
                            fontWeight: FontWeight.w700),
                      ),
              ),
            ),
          ]),
        ),
        // Footer: bouton consulter
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => _ClasseDetailPage(
                    classe: widget.classe,
                    trimestre: widget.trimestre,
                    anneeScol: widget.anneeScol,
                    validation: widget.validation,
                    dirNom: widget.dirNom,
                  ),
                ),
              ),
              icon: const Icon(Icons.people_alt_outlined, size: 15),
              label: const Text('Consulter les bulletins'),
              style: OutlinedButton.styleFrom(
                foregroundColor: _kBlue,
                side: BorderSide(
                    color: _kBlue.withValues(alpha: 0.4)),
                padding: const EdgeInsets.symmetric(
                    vertical: 8, horizontal: 12),
                textStyle: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

// ─── Tab 2 : Recherche élève ──────��───────────────────────────────────────────

class _RechercheTab extends StatelessWidget {
  final String query;
  const _RechercheTab({required this.query});

  @override
  Widget build(BuildContext context) {
    if (query.isEmpty) {
      return const Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.person_search, color: Colors.white24, size: 48),
          SizedBox(height: 14),
          Text('Tapez un nom pour rechercher',
              style: TextStyle(color: Colors.white38, fontSize: 14)),
          SizedBox(height: 4),
          Text('Appuyez sur l\'icone loupe en haut',
              style: TextStyle(color: Colors.white24, fontSize: 12)),
        ]),
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'eleve')
          .orderBy('displayName')
          .snapshots(),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: _kPurple));
        }
        final allEleves = snap.data?.docs
                .map(UserModel.fromDoc)
                .where((u) =>
                    u.displayName.toLowerCase().contains(query) ||
                    (u.classeNom?.toLowerCase().contains(query) ?? false))
                .toList() ??
            [];

        if (allEleves.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.search_off,
                    color: Colors.white24, size: 42),
                const SizedBox(height: 12),
                Text('Aucun résultat pour "$query"',
                    style: const TextStyle(
                        color: Colors.white38, fontSize: 14)),
              ]),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 40),
          itemCount: allEleves.length,
          itemBuilder: (_, i) =>
              _EleveSearchTile(eleve: allEleves[i]),
        );
      },
    );
  }
}

class _EleveSearchTile extends StatelessWidget {
  final UserModel eleve;
  const _EleveSearchTile({required this.eleve});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: CircleAvatar(
          backgroundColor: _kPurple.withValues(alpha: 0.15),
          child: Text(
            eleve.displayName.isNotEmpty
                ? eleve.displayName[0].toUpperCase()
                : '?',
            style: const TextStyle(
                color: _kPurple,
                fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(eleve.displayName,
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 14)),
        subtitle: Text(
          [
            if (eleve.classeNom?.isNotEmpty == true) eleve.classeNom!,
            if (eleve.niveau?.isNotEmpty == true) eleve.niveau!,
          ].join(' · '),
          style:
              const TextStyle(color: Colors.white38, fontSize: 12),
        ),
        trailing: ElevatedButton(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => EleveReleveNotesPage(
                eleveUid: eleve.uid,
                eleveNom: eleve.displayName,
              ),
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: _kPurple,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 8),
            textStyle: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8)),
          ),
          child: const Text('Bulletin'),
        ),
      ),
    );
  }
}

// ─── Tab 3 : Statistiques globales ────────────────────────────────────────────

class _StatistiquesTab extends StatefulWidget {
  final int trimestre;
  final int anneeScol;
  const _StatistiquesTab(
      {required this.trimestre, required this.anneeScol});

  @override
  State<_StatistiquesTab> createState() => _StatistiquesTabState();
}

class _StatistiquesTabState extends State<_StatistiquesTab> {
  bool _loading = false;
  bool _loaded = false;
  _GlobalStats? _stats;

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('notes')
          .where('publie', isEqualTo: true)
          .get();

      final allNotes = snap.docs.map(NoteModel.fromFirestore).toList();
      final filtered = widget.trimestre == 0
          ? allNotes
          : allNotes
              .where(
                  (n) => _trimestreDe(n.date) == widget.trimestre)
              .toList();

      final byEleve = <String, List<double>>{};
      final byClasse = <String, List<double>>{};
      for (final n in filtered) {
        (byEleve[n.eleveId] ??= []).add(n.sur20);
        (byClasse[n.classeId] ??= []).add(n.sur20);
      }

      final eleveAvgs = byEleve.map((uid, vals) {
        final avg = vals.reduce((a, b) => a + b) / vals.length;
        return MapEntry(uid, avg);
      });

      final classeAvgs = byClasse.map((id, vals) {
        final avg = vals.reduce((a, b) => a + b) / vals.length;
        return MapEntry(id, avg);
      });

      double globalAvg = 0;
      if (eleveAvgs.isNotEmpty) {
        globalAvg = eleveAvgs.values.reduce((a, b) => a + b) /
            eleveAvgs.length;
      }

      final dist = <String, int>{
        'Excellent': 0,
        'Bien': 0,
        'Assez bien': 0,
        'Passable': 0,
        'Insuffisant': 0,
      };
      for (final avg in eleveAvgs.values) {
        final m = _mention(avg);
        if (m == 'Tres faible') {
          dist['Insuffisant'] = (dist['Insuffisant'] ?? 0) + 1;
        } else {
          dist[m] = (dist[m] ?? 0) + 1;
        }
      }

      // Classement des classes par moyenne
      final classeRanked = classeAvgs.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      // Validation status
      final valSnap = await FirebaseFirestore.instance
          .collection('bulletin_validations')
          .where('anneeScol', isEqualTo: widget.anneeScol)
          .where('trimestre', isEqualTo: widget.trimestre)
          .get();
      final pubCount =
          valSnap.docs.where((d) => d['publie'] == true).length;
      final totalClasses = byClasse.length;

      final classesSnap = await FirebaseFirestore.instance
          .collection('classes')
          .get();
      final classeNames = {
        for (final d in classesSnap.docs)
          d.id: (d.data()['nom'] as String?) ?? d.id
      };

      if (mounted) {
        setState(() {
          _stats = _GlobalStats(
            globalAvg: globalAvg,
            nbEleves: eleveAvgs.length,
            nbClasses: byClasse.length,
            distribution: dist,
            classeRanked: classeRanked
                .take(5)
                .map((e) => MapEntry(
                    classeNames[e.key] ?? e.key, e.value))
                .toList(),
            pubCount: pubCount,
            totalClasses: totalClasses,
          );
          _loaded = true;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded && !_loading) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.bar_chart_outlined,
                color: Colors.white24, size: 52),
            const SizedBox(height: 16),
            const Text('Statistiques globales',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15)),
            const SizedBox(height: 8),
            const Text(
              'Agrège toutes les notes publiées pour\nle trimestre sélectionné.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white38, fontSize: 13),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.analytics_outlined, size: 16),
              label: const Text('Charger les statistiques'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _kPurple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ]),
        ),
      );
    }

    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(color: _kPurple));
    }

    final s = _stats!;
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 40),
      children: [
        // KPI row
        _StatsKpiRow(
          globalAvg: s.globalAvg,
          nbEleves: s.nbEleves,
          nbClasses: s.nbClasses,
          pubCount: s.pubCount,
          totalClasses: s.totalClasses,
        ),
        const SizedBox(height: 16),
        // Distribution mentions
        _DistributionCard(
            distribution: s.distribution, total: s.nbEleves),
        const SizedBox(height: 16),
        // Top classes
        if (s.classeRanked.isNotEmpty) ...[
          _TopClassesCard(classes: s.classeRanked),
          const SizedBox(height: 16),
        ],
        // Refresh
        TextButton.icon(
          onPressed: _load,
          icon: const Icon(Icons.refresh, size: 15),
          label: const Text('Recalculer'),
          style: TextButton.styleFrom(foregroundColor: Colors.white38),
        ),
      ],
    );
  }
}

class _GlobalStats {
  final double globalAvg;
  final int nbEleves;
  final int nbClasses;
  final Map<String, int> distribution;
  final List<MapEntry<String, double>> classeRanked;
  final int pubCount;
  final int totalClasses;

  const _GlobalStats({
    required this.globalAvg,
    required this.nbEleves,
    required this.nbClasses,
    required this.distribution,
    required this.classeRanked,
    required this.pubCount,
    required this.totalClasses,
  });
}

// ── KPI row ───────────────────────────────────────────────────────────────────

class _StatsKpiRow extends StatelessWidget {
  final double globalAvg;
  final int nbEleves;
  final int nbClasses;
  final int pubCount;
  final int totalClasses;

  const _StatsKpiRow({
    required this.globalAvg,
    required this.nbEleves,
    required this.nbClasses,
    required this.pubCount,
    required this.totalClasses,
  });

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      _KpiBox(
          label: 'Moy. globale',
          value: '${globalAvg.toStringAsFixed(2)}/20',
          color: _mentionColor(globalAvg),
          icon: Icons.calculate_outlined),
      const SizedBox(width: 8),
      _KpiBox(
          label: 'Élèves',
          value: '$nbEleves',
          color: _kBlue,
          icon: Icons.people_alt_outlined),
      const SizedBox(width: 8),
      _KpiBox(
          label: 'Publiés',
          value: '$pubCount/$totalClasses',
          color: pubCount == totalClasses && totalClasses > 0
              ? _kGreen
              : _kOrange,
          icon: Icons.verified_outlined),
    ]);
  }
}

class _KpiBox extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;
  const _KpiBox(
      {required this.label,
      required this.value,
      required this.color,
      required this.icon});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border:
              Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 6),
          Text(value,
              style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 16)),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(
                  color: Colors.white38, fontSize: 10),
              textAlign: TextAlign.center),
        ]),
      ),
    );
  }
}

// ── Distribution ───��──────────────────────────────────────────────────────────

class _DistributionCard extends StatelessWidget {
  final Map<String, int> distribution;
  final int total;
  const _DistributionCard(
      {required this.distribution, required this.total});

  static const _colors = {
    'Excellent': _kGreen,
    'Bien': Color(0xFF16A34A),
    'Assez bien': _kTeal,
    'Passable': _kOrange,
    'Insuffisant': _kRed,
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [
            Icon(Icons.bar_chart_outlined,
                color: _kPurple, size: 16),
            SizedBox(width: 7),
            Text('Répartition des mentions',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13)),
          ]),
          const SizedBox(height: 14),
          ...distribution.entries.map((e) {
            final pct = total > 0 ? e.value / total : 0.0;
            final color =
                _colors[e.key] ?? Colors.white38;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(children: [
                SizedBox(
                  width: 72,
                  child: Text(e.key,
                      style: TextStyle(
                          color: color,
                          fontSize: 11,
                          fontWeight: FontWeight.w600)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: pct.clamp(0.0, 1.0),
                      minHeight: 8,
                      color: color,
                      backgroundColor:
                          color.withValues(alpha: 0.1),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 24,
                  child: Text('${e.value}',
                      style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 11)),
                ),
              ]),
            );
          }),
        ],
      ),
    );
  }
}

// ── Top classes ───────────────────────────────────────────────────────────────

class _TopClassesCard extends StatelessWidget {
  final List<MapEntry<String, double>> classes;
  const _TopClassesCard({required this.classes});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [
            Icon(Icons.emoji_events_outlined,
                color: _kOrange, size: 16),
            SizedBox(width: 7),
            Text('Top classes',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13)),
          ]),
          const SizedBox(height: 12),
          ...classes.asMap().entries.map((entry) {
            final rank = entry.key + 1;
            final e = entry.value;
            final color = _mentionColor(e.value);
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: rank == 1
                        ? _kOrange.withValues(alpha: 0.2)
                        : _kCard2,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text('$rank',
                        style: TextStyle(
                            color: rank == 1
                                ? _kOrange
                                : Colors.white38,
                            fontWeight: FontWeight.bold,
                            fontSize: 11)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(e.key,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 13)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${e.value.toStringAsFixed(2)}/20',
                    style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.bold,
                        fontSize: 12),
                  ),
                ),
              ]),
            );
          }),
        ],
      ),
    );
  }
}

// ─── Page détail d'une classe ─────���───────────────────────────────────────────

class _ClasseDetailPage extends StatefulWidget {
  final ClasseModel classe;
  final int trimestre;
  final int anneeScol;
  final BulletinValidationModel? validation;
  final String dirNom;

  const _ClasseDetailPage({
    required this.classe,
    required this.trimestre,
    required this.anneeScol,
    required this.validation,
    required this.dirNom,
  });

  @override
  State<_ClasseDetailPage> createState() => _ClasseDetailPageState();
}

class _ClasseDetailPageState extends State<_ClasseDetailPage> {
  String _searchQuery = '';
  bool _sortByMoyenne = true;
  bool _publishing = false;
  late BulletinValidationModel? _validation;

  @override
  void initState() {
    super.initState();
    _validation = widget.validation;
  }

  Future<void> _togglePublish() async {
    final publie = _validation?.publie ?? false;
    setState(() => _publishing = true);
    try {
      await BulletinValidationService.publish(
        classeId: widget.classe.id,
        classeNom: widget.classe.nom,
        trimestre: widget.trimestre,
        anneeScol: widget.anneeScol,
        publie: !publie,
        directionNom: widget.dirNom,
      );
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kCard,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.classe.nom,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16)),
            Text('Trimestre ${widget.trimestre} · ${widget.anneeScol}',
                style: const TextStyle(
                    color: Colors.white38, fontSize: 11)),
          ],
        ),
      ),
      body: StreamBuilder<BulletinValidationModel?>(
        stream: BulletinValidationService.stream(
          classeId: widget.classe.id,
          trimestre: widget.trimestre,
          anneeScol: widget.anneeScol,
        ),
        builder: (ctx, valSnap) {
          if (valSnap.hasData) _validation = valSnap.data;
          final publie = _validation?.publie ?? false;
          return Column(children: [
            // Bandeau publication
            _DetailPublicationHeader(
              classe: widget.classe,
              trimestre: widget.trimestre,
              publie: publie,
              validation: _validation,
              publishing: _publishing,
              onToggle: _togglePublish,
            ),
            // Barre recherche + tri
            _DetailSearchBar(
              query: _searchQuery,
              sortByMoyenne: _sortByMoyenne,
              onQueryChanged: (q) =>
                  setState(() => _searchQuery = q.toLowerCase()),
              onSortToggle: () =>
                  setState(() => _sortByMoyenne = !_sortByMoyenne),
            ),
            // Liste élèves
            Expanded(
              child: _ElevesBulletinList(
                classe: widget.classe,
                trimestre: widget.trimestre,
                searchQuery: _searchQuery,
                sortByMoyenne: _sortByMoyenne,
              ),
            ),
          ]);
        },
      ),
    );
  }
}

// ── Bandeau publication classe détail ─────────────────────────────────────────

class _DetailPublicationHeader extends StatelessWidget {
  final ClasseModel classe;
  final int trimestre;
  final bool publie;
  final BulletinValidationModel? validation;
  final bool publishing;
  final VoidCallback onToggle;

  const _DetailPublicationHeader({
    required this.classe,
    required this.trimestre,
    required this.publie,
    required this.validation,
    required this.publishing,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final ts = validation?.datePub;
    final dateStr = ts != null
        ? DateFormat('dd/MM/yyyy HH:mm').format(ts.toDate())
        : null;

    return Container(
      color: publie
          ? _kGreen.withValues(alpha: 0.08)
          : _kCard2,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      child: Row(children: [
        Icon(
          publie ? Icons.verified : Icons.hourglass_empty_outlined,
          color: publie ? _kGreen : Colors.white24,
          size: 18,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                publie ? 'Bulletin T$trimestre publié' : 'Bulletin T$trimestre non publié',
                style: TextStyle(
                    color: publie ? _kGreen : Colors.white54,
                    fontWeight: FontWeight.bold,
                    fontSize: 13),
              ),
              if (publie && dateStr != null)
                Text('Le $dateStr${validation?.directionNom?.isNotEmpty == true ? ' par ${validation!.directionNom}' : ''}',
                    style: const TextStyle(
                        color: Colors.white24, fontSize: 10)),
            ],
          ),
        ),
        GestureDetector(
          onTap: publishing ? null : onToggle,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: publie
                  ? _kRed.withValues(alpha: 0.12)
                  : _kGreen.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: publie
                    ? _kRed.withValues(alpha: 0.3)
                    : _kGreen.withValues(alpha: 0.3),
              ),
            ),
            child: publishing
                ? SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: publie ? _kRed : _kGreen))
                : Text(publie ? 'Dépublier' : 'Publier',
                    style: TextStyle(
                        color: publie ? _kRed : _kGreen,
                        fontWeight: FontWeight.w700,
                        fontSize: 12)),
          ),
        ),
      ]),
    );
  }
}

// ── Barre recherche + tri ─────────────────────────────────────────────────────

class _DetailSearchBar extends StatefulWidget {
  final String query;
  final bool sortByMoyenne;
  final ValueChanged<String> onQueryChanged;
  final VoidCallback onSortToggle;
  const _DetailSearchBar({
    required this.query,
    required this.sortByMoyenne,
    required this.onQueryChanged,
    required this.onSortToggle,
  });

  @override
  State<_DetailSearchBar> createState() => _DetailSearchBarState();
}

class _DetailSearchBarState extends State<_DetailSearchBar> {
  late final TextEditingController _c;

  @override
  void initState() {
    super.initState();
    _c = TextEditingController(text: widget.query);
    _c.addListener(() => widget.onQueryChanged(_c.text));
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _kCard2,
      padding: const EdgeInsets.symmetric(
          horizontal: 12, vertical: 8),
      child: Row(children: [
        Expanded(
          child: SizedBox(
            height: 36,
            child: TextField(
              controller: _c,
              style:
                  const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Filtrer par nom…',
                hintStyle: const TextStyle(
                    color: Colors.white38, fontSize: 12),
                prefixIcon: const Icon(Icons.search,
                    color: Colors.white38, size: 16),
                filled: true,
                fillColor: _kCard,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 10),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide:
                        const BorderSide(color: _kBorder)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide:
                        const BorderSide(color: _kBorder)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide:
                        const BorderSide(color: _kPurple)),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: widget.onSortToggle,
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: _kCard,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _kBorder),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(
                widget.sortByMoyenne
                    ? Icons.sort_outlined
                    : Icons.sort_by_alpha_outlined,
                color: Colors.white54,
                size: 15,
              ),
              const SizedBox(width: 4),
              Text(
                widget.sortByMoyenne ? 'Moy.' : 'A-Z',
                style: const TextStyle(
                    color: Colors.white54, fontSize: 11),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}

// ── Liste des élèves ──────────────────────────────────────────────────────────

class _ElevesBulletinList extends StatelessWidget {
  final ClasseModel classe;
  final int trimestre;
  final String searchQuery;
  final bool sortByMoyenne;

  const _ElevesBulletinList({
    required this.classe,
    required this.trimestre,
    required this.searchQuery,
    required this.sortByMoyenne,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_ClasseStats>(
      future: _loadStats(),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: _kPurple));
        }
        if (snap.hasError || !snap.hasData) {
          return Center(
            child: Text('Erreur : ${snap.error}',
                style: const TextStyle(
                    color: Colors.white38, fontSize: 13)),
          );
        }
        final stats = snap.data!;

        // Filtrage + tri
        var list = List<_EleveData>.from(stats.elevesData);
        if (searchQuery.isNotEmpty) {
          list = list
              .where((e) => e.eleve.displayName
                  .toLowerCase()
                  .contains(searchQuery))
              .toList();
        }
        if (sortByMoyenne) {
          list.sort((a, b) {
            final ma = a.moyenne ?? -1;
            final mb = b.moyenne ?? -1;
            return mb.compareTo(ma);
          });
        } else {
          list.sort((a, b) =>
              a.eleve.displayName.compareTo(b.eleve.displayName));
        }

        if (list.isEmpty) {
          return const Center(
            child: Text('Aucun élève trouvé',
                style: TextStyle(color: Colors.white38, fontSize: 14)),
          );
        }

        return Column(children: [
          // Stats header classe
          _ClasseStatsHeader(stats: stats, trimestre: trimestre),
          // Liste
          Expanded(
            child: ListView.builder(
              padding:
                  const EdgeInsets.fromLTRB(12, 8, 12, 40),
              itemCount: list.length,
              itemBuilder: (_, i) => _EleveBulletinTile(
                data: list[i],
                rank: sortByMoyenne ? i + 1 : null,
              ),
            ),
          ),
        ]);
      },
    );
  }

  Future<_ClasseStats> _loadStats() async {
    final db = FirebaseFirestore.instance;

    // Élèves de la classe
    final elevesSnap = await db
        .collection('users')
        .where('role', isEqualTo: 'eleve')
        .where('classeNom', isEqualTo: classe.nom)
        .get();
    final eleves = elevesSnap.docs.map(UserModel.fromDoc).toList();
    eleves.sort((a, b) => a.displayName.compareTo(b.displayName));

    // Notes de la classe publiées
    final notesSnap = await db
        .collection('notes')
        .where('classeId', isEqualTo: classe.id)
        .where('publie', isEqualTo: true)
        .get();
    final allNotes = notesSnap.docs.map(NoteModel.fromFirestore).toList();
    final notes = allNotes
        .where((n) => _trimestreDe(n.date) == trimestre)
        .toList();

    // Appréciations pour ce trimestre
    final appSnap = await db
        .collection('appreciations')
        .where('classeId', isEqualTo: classe.id)
        .where('trimestre', isEqualTo: trimestre)
        .get();
    final appreciations =
        appSnap.docs.map(AppreciationModel.fromFirestore).toList();

    // Grouper notes par élève
    final notesByEleve = <String, List<NoteModel>>{};
    for (final n in notes) {
      (notesByEleve[n.eleveId] ??= []).add(n);
    }
    final appsByEleve = <String, List<AppreciationModel>>{};
    for (final a in appreciations) {
      (appsByEleve[a.eleveId] ??= []).add(a);
    }

    // Construire _EleveData
    final elevesData = eleves.map((e) {
      final ns = notesByEleve[e.uid] ?? [];
      double? avg;
      if (ns.isNotEmpty) {
        avg = ns.fold<double>(0, (s, n) => s + n.sur20) / ns.length;
      }
      return _EleveData(
        eleve: e,
        moyenne: avg,
        nbNotes: ns.length,
        appreciations: appsByEleve[e.uid] ?? [],
      );
    }).toList();

    // Stats classe
    final avgs = elevesData
        .where((e) => e.moyenne != null)
        .map((e) => e.moyenne!)
        .toList();
    double? classMoy;
    if (avgs.isNotEmpty) {
      classMoy = avgs.reduce((a, b) => a + b) / avgs.length;
    }

    final dist = <String, int>{
      'Excellent': 0,
      'Bien': 0,
      'Assez bien': 0,
      'Passable': 0,
      'Insuffisant': 0,
    };
    for (final avg in avgs) {
      final m = _mention(avg);
      if (m == 'Tres faible') {
        dist['Insuffisant'] = (dist['Insuffisant'] ?? 0) + 1;
      } else {
        dist[m] = (dist[m] ?? 0) + 1;
      }
    }

    return _ClasseStats(
      moyenneClasse: classMoy,
      nbEleves: eleves.length,
      nbAvecNotes: avgs.length,
      distribution: dist,
      elevesData: elevesData,
    );
  }
}

// ── Stats header classe ───────────────────────────────────────────────────────

class _ClasseStatsHeader extends StatelessWidget {
  final _ClasseStats stats;
  final int trimestre;
  const _ClasseStatsHeader(
      {required this.stats, required this.trimestre});

  @override
  Widget build(BuildContext context) {
    final moy = stats.moyenneClasse;
    final color = moy != null ? _mentionColor(moy) : Colors.white38;
    return Container(
      color: _kCard2,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      child: Row(children: [
        // Moy classe
        Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
            border:
                Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Column(children: [
            Text(
              moy != null
                  ? '${moy.toStringAsFixed(2)}/20'
                  : '—',
              style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 18),
            ),
            Text('Moy. classe',
                style: const TextStyle(
                    color: Colors.white38, fontSize: 9)),
          ]),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Wrap(spacing: 8, runSpacing: 4, children: [
            _MiniStat(
                label: 'Élèves',
                value: '${stats.nbEleves}',
                color: _kBlue),
            _MiniStat(
                label: 'Avec notes',
                value: '${stats.nbAvecNotes}',
                color: _kTeal),
            _MiniStat(
                label: 'Sans notes',
                value:
                    '${stats.nbEleves - stats.nbAvecNotes}',
                color: stats.nbEleves - stats.nbAvecNotes > 0
                    ? _kOrange
                    : Colors.white38),
          ]),
        ),
      ]),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _MiniStat(
      {required this.label,
      required this.value,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: RichText(
        text: TextSpan(children: [
          TextSpan(
              text: value,
              style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 13)),
          TextSpan(
              text: ' $label',
              style: const TextStyle(
                  color: Colors.white38, fontSize: 11)),
        ]),
      ),
    );
  }
}

// ── Tile élève bulletin ───────────────────────────────────────────────────────

class _EleveBulletinTile extends StatelessWidget {
  final _EleveData data;
  final int? rank;
  const _EleveBulletinTile({required this.data, this.rank});

  @override
  Widget build(BuildContext context) {
    final moy = data.moyenne;
    final color = moy != null ? _mentionColor(moy) : Colors.white24;
    final nbApp = data.appreciations.length;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) => EleveReleveNotesPage(
              eleveUid: data.eleve.uid,
              eleveNom: data.eleve.displayName,
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Row(children: [
            // Rang ou avatar
            if (rank != null)
              Container(
                width: 28,
                height: 28,
                margin: const EdgeInsets.only(right: 10),
                decoration: BoxDecoration(
                  color: rank == 1
                      ? _kOrange.withValues(alpha: 0.15)
                      : _kCard2,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '$rank',
                    style: TextStyle(
                        color: rank == 1
                            ? _kOrange
                            : Colors.white38,
                        fontWeight: FontWeight.bold,
                        fontSize: 11),
                  ),
                ),
              )
            else
              Container(
                width: 36,
                height: 36,
                margin: const EdgeInsets.only(right: 10),
                decoration: BoxDecoration(
                  color: _kPurple.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    data.eleve.displayName.isNotEmpty
                        ? data.eleve.displayName[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                        color: _kPurple,
                        fontWeight: FontWeight.bold,
                        fontSize: 14),
                  ),
                ),
              ),
            // Infos élève
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(data.eleve.displayName,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  Row(children: [
                    Text('${data.nbNotes} note(s)',
                        style: const TextStyle(
                            color: Colors.white38,
                            fontSize: 11)),
                    if (nbApp > 0) ...[
                      const Text(' · ',
                          style: TextStyle(
                              color: Colors.white24,
                              fontSize: 11)),
                      Icon(Icons.rate_review_outlined,
                          color: _kPurple, size: 12),
                      Text(' $nbApp app.',
                          style: const TextStyle(
                              color: Colors.white38,
                              fontSize: 11)),
                    ],
                  ]),
                ],
              ),
            ),
            // Moyenne badge
            if (moy != null)
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border:
                      Border.all(color: color.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${moy.toStringAsFixed(2)}/20',
                      style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.bold,
                          fontSize: 13),
                    ),
                    Text(_mention(moy),
                        style: TextStyle(
                            color: color.withValues(alpha: 0.8),
                            fontSize: 9)),
                  ],
                ),
              )
            else
              const Text('—',
                  style: TextStyle(
                      color: Colors.white24, fontSize: 13)),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right,
                color: Colors.white24, size: 18),
          ]),
        ),
      ),
    );
  }
}
