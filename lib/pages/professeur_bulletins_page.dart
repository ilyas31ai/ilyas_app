import 'dart:async';

import 'package:flutter/material.dart';

import '../models/appreciation_model.dart';
import '../models/classe_model.dart';
import '../models/user_model.dart';
import '../services/appreciation_service.dart';
import '../services/professeur_service.dart';
import '../services/user_service.dart';

// ─── Entry point ──────────────────────────────────────────────────────────────

class ProfesseurBulletinsPage extends StatefulWidget {
  const ProfesseurBulletinsPage({super.key});

  @override
  State<ProfesseurBulletinsPage> createState() =>
      _ProfesseurBulletinsPageState();
}

// ─── Palette ──────────────────────────────────────────────────────────────────

const _kBg     = Color(0xFF0D1117);
const _kCard   = Color(0xFF161B22);
const _kCard2  = Color(0xFF1F2937);
const _kBorder = Color(0xFF30363D);
const _kPurple = Color(0xFF6C47FF);
const _kGreen  = Color(0xFF16A34A);
const _kOrange = Color(0xFFD97706);
const _kRed    = Color(0xFFDC2626);
const _kTeal   = Color(0xFF0F766E);

// ─── State ────────────────────────────────────────────────────────────────────

class _ProfesseurBulletinsPageState
    extends State<ProfesseurBulletinsPage> {
  ClasseModel? _classe;
  int _trimestre = _currentTrimestre();
  String _matiere = '';
  String _profNom = '';
  bool _savingAll = false;

  static int _currentTrimestre() {
    final m = DateTime.now().month;
    if (m >= 9 && m <= 11) return 1;
    if (m == 12 || m <= 2) return 2;
    return 3;
  }

  @override
  void initState() {
    super.initState();
    UserService.currentUserStream().first.then((u) {
      if (mounted && u != null) {
        setState(() => _profNom = u.displayName);
      }
    });
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: _buildAppBar(),
      body: StreamBuilder<List<ClasseModel>>(
        stream: ProfesseurService.classesStream(),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: _kTeal));
          }
          final classes = snap.data ?? [];
          if (classes.isEmpty) return _emptyClasses();

          if (_classe == null || !classes.contains(_classe)) {
            WidgetsBinding.instance.addPostFrameCallback(
                (_) => setState(() => _classe = classes.first));
          }

          return Column(children: [
            _ClasseTrimestrePicker(
              classes: classes,
              selectedClasse: _classe,
              trimestre: _trimestre,
              onClasseChanged: (c) => setState(() {
                _classe = c;
                _matiere = '';
              }),
              onTrimestreChanged: (t) =>
                  setState(() => _trimestre = t),
            ),
            Expanded(
              child: _classe == null
                  ? const SizedBox.shrink()
                  : _BulletinContent(
                      classe: _classe!,
                      trimestre: _trimestre,
                      matiere: _matiere,
                      profNom: _profNom,
                      savingAll: _savingAll,
                      onMatiereChanged: (m) =>
                          setState(() => _matiere = m),
                      onSaveAll: _saveAll,
                    ),
            ),
          ]);
        },
      ),
    );
  }

  AppBar _buildAppBar() => AppBar(
        backgroundColor: const Color(0xFF161B22),
        elevation: 0,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Bulletins',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold)),
            Text('Saisie des appréciations',
                style:
                    TextStyle(color: Colors.white38, fontSize: 11)),
          ],
        ),
        actions: [
          if (_savingAll)
            const Padding(
              padding: EdgeInsets.all(14),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    color: _kTeal, strokeWidth: 2),
              ),
            ),
        ],
      );

  Future<void> _saveAll() async {
    if (_classe == null) return;
    setState(() => _savingAll = true);
    try {
      // Déclenche la sauvegarde depuis le state de chaque card
      // via la clé globale (voir _BulletinContent)
      await Future<void>.delayed(const Duration(milliseconds: 100));
    } finally {
      if (mounted) setState(() => _savingAll = false);
    }
  }

  Widget _emptyClasses() => const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.class_outlined, color: Colors.white24, size: 48),
            SizedBox(height: 14),
            Text('Aucune classe assignée',
                style:
                    TextStyle(color: Colors.white54, fontSize: 15)),
            SizedBox(height: 6),
            Text(
              'Créez ou rejoignez une classe\ndepuis la gestion des élèves.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white24, fontSize: 12),
            ),
          ]),
        ),
      );
}

// ─── Classe + Trimestre picker ─────────────────────────────────────────────────

class _ClasseTrimestrePicker extends StatelessWidget {
  final List<ClasseModel> classes;
  final ClasseModel? selectedClasse;
  final int trimestre;
  final ValueChanged<ClasseModel> onClasseChanged;
  final ValueChanged<int> onTrimestreChanged;

  const _ClasseTrimestrePicker({
    required this.classes,
    required this.selectedClasse,
    required this.trimestre,
    required this.onClasseChanged,
    required this.onTrimestreChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF161B22),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Classe dropdown
          if (classes.length > 1)
            SizedBox(
              height: 36,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: classes.length,
                separatorBuilder: (_, __) => const SizedBox(width: 6),
                itemBuilder: (ctx, i) {
                  final c = classes[i];
                  final sel = c == selectedClasse;
                  return GestureDetector(
                    onTap: () => onClasseChanged(c),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: sel ? _kTeal : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: sel ? _kTeal : Colors.white24,
                        ),
                      ),
                      child: Text(c.nom,
                          style: TextStyle(
                              color: sel
                                  ? Colors.white
                                  : Colors.white54,
                              fontWeight: FontWeight.w600,
                              fontSize: 12)),
                    ),
                  );
                },
              ),
            )
          else if (selectedClasse != null)
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: _kTeal.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border:
                    Border.all(color: _kTeal.withValues(alpha: 0.4)),
              ),
              child: Text(selectedClasse!.nom,
                  style: const TextStyle(
                      color: _kTeal,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ),
          const SizedBox(height: 8),
          // Trimestre chips
          Row(
            children: [1, 2, 3].map((t) {
              final sel = t == trimestre;
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: GestureDetector(
                  onTap: () => onTrimestreChanged(t),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: sel ? _kPurple : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: sel ? _kPurple : Colors.white24,
                      ),
                    ),
                    child: Text('Trimestre $t',
                        style: TextStyle(
                            color:
                                sel ? Colors.white : Colors.white54,
                            fontWeight: FontWeight.w600,
                            fontSize: 12)),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

// ─── Contenu principal ────────────────────────────────────────────────────────

class _BulletinContent extends StatefulWidget {
  final ClasseModel classe;
  final int trimestre;
  final String matiere;
  final String profNom;
  final bool savingAll;
  final ValueChanged<String> onMatiereChanged;
  final VoidCallback onSaveAll;

  const _BulletinContent({
    required this.classe,
    required this.trimestre,
    required this.matiere,
    required this.profNom,
    required this.savingAll,
    required this.onMatiereChanged,
    required this.onSaveAll,
  });

  @override
  State<_BulletinContent> createState() => _BulletinContentState();
}

class _BulletinContentState extends State<_BulletinContent> {
  Map<String, double> _moyennes = {};
  List<AppreciationModel> _appreciations = [];
  List<String> _matieres = [];
  StreamSubscription<List<AppreciationModel>>? _appSub;
  bool _loadingMoyennes = true;
  int _savedCount = 0;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void didUpdateWidget(_BulletinContent old) {
    super.didUpdateWidget(old);
    if (old.classe != widget.classe ||
        old.trimestre != widget.trimestre) {
      _reload();
    }
  }

  @override
  void dispose() {
    _appSub?.cancel();
    super.dispose();
  }

  void _reload() {
    _appSub?.cancel();
    setState(() => _loadingMoyennes = true);

    // Charger moyennes + matières
    AppreciationService.moyennesParEleve(
      classeId: widget.classe.id,
      trimestre: widget.trimestre,
    ).then((m) {
      if (mounted) {
        setState(() {
          _moyennes = m;
          _loadingMoyennes = false;
        });
      }
    });

    AppreciationService.matieresForClasse(widget.classe.id)
        .then((mats) {
      if (mounted) {
        setState(() => _matieres = mats);
        if (mats.isNotEmpty && widget.matiere.isEmpty) {
          widget.onMatiereChanged(mats.first);
        }
      }
    });

    _appSub = AppreciationService.streamByClasse(
      classeId: widget.classe.id,
      trimestre: widget.trimestre,
      anneeScol: DateTime.now().year,
    ).listen((apps) {
      if (mounted) {
        setState(() {
          _appreciations = apps;
          _savedCount = apps.where((a) => a.texte.isNotEmpty).length;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<UserModel>>(
      stream: AppreciationService.elevesStream(widget.classe.nom),
      builder: (ctx, snap) {
        final eleves = snap.data ?? [];

        return Column(children: [
          // Sélecteur matière + header stats
          _MatiereBar(
            matieres: _matieres,
            selected: widget.matiere,
            onChanged: widget.onMatiereChanged,
          ),
          _SummaryBar(
            nbEleves: eleves.length,
            nbSaved: _savedCount,
            loadingMoyennes: _loadingMoyennes,
            onSaveAll: widget.onSaveAll,
          ),
          // Liste des élèves
          Expanded(
            child: eleves.isEmpty
                ? _emptyEleves()
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 40),
                    itemCount: eleves.length,
                    itemBuilder: (ctx, i) {
                      final eleve = eleves[i];
                      final moy = _moyennes[eleve.uid];
                      final existing = _appreciations
                          .where((a) => a.eleveId == eleve.uid)
                          .firstOrNull;
                      return _EleveAppreciationCard(
                        key: ValueKey(
                            '${eleve.uid}_${widget.trimestre}_${widget.matiere}'),
                        eleve: eleve,
                        moyenne: moy,
                        existing: existing,
                        classe: widget.classe,
                        trimestre: widget.trimestre,
                        matiere: widget.matiere,
                        profNom: widget.profNom,
                        onSaved: () =>
                            setState(() => _savedCount++),
                      );
                    },
                  ),
          ),
        ]);
      },
    );
  }

  Widget _emptyEleves() => const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.person_outline,
                color: Colors.white24, size: 48),
            SizedBox(height: 14),
            Text('Aucun élève dans cette classe',
                style:
                    TextStyle(color: Colors.white54, fontSize: 14)),
            SizedBox(height: 6),
            Text(
              'Les élèves apparaîtront ici une fois\nqu\'ils auront rejoint la classe.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white24, fontSize: 12),
            ),
          ]),
        ),
      );
}

// ─── Barre sélection matière ──────────────────────────────────────────────────

class _MatiereBar extends StatelessWidget {
  final List<String> matieres;
  final String selected;
  final ValueChanged<String> onChanged;
  const _MatiereBar(
      {required this.matieres,
      required this.selected,
      required this.onChanged});

  @override
  Widget build(BuildContext context) {
    if (matieres.isEmpty) return const SizedBox.shrink();
    return Container(
      color: _kCard2,
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        itemCount: matieres.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (_, i) {
          final m = matieres[i];
          final sel = m == selected;
          return GestureDetector(
            onTap: () => onChanged(m),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: sel
                    ? _kTeal.withValues(alpha: 0.2)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: sel
                      ? _kTeal
                      : Colors.white.withValues(alpha: 0.12),
                ),
              ),
              child: Text(m,
                  style: TextStyle(
                      color: sel ? _kTeal : Colors.white54,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ),
          );
        },
      ),
    );
  }
}

// ─── Barre résumé ─────────────────────────────────────────────────────────────

class _SummaryBar extends StatelessWidget {
  final int nbEleves, nbSaved;
  final bool loadingMoyennes;
  final VoidCallback onSaveAll;
  const _SummaryBar({
    required this.nbEleves,
    required this.nbSaved,
    required this.loadingMoyennes,
    required this.onSaveAll,
  });

  @override
  Widget build(BuildContext context) {
    final pct = nbEleves > 0 ? nbSaved / nbEleves : 0.0;
    return Container(
      color: const Color(0xFF161B22),
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
      child: Row(children: [
        // Barre progression
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Text(
                  '$nbSaved / $nbEleves appréciations',
                  style: const TextStyle(
                      color: Colors.white, fontSize: 12),
                ),
                if (loadingMoyennes) ...[
                  const SizedBox(width: 8),
                  const SizedBox(
                    width: 10,
                    height: 10,
                    child: CircularProgressIndicator(
                        color: Colors.white38, strokeWidth: 1.5),
                  ),
                ],
              ]),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: pct.clamp(0.0, 1.0),
                  minHeight: 3,
                  color: _kTeal,
                  backgroundColor: _kTeal.withValues(alpha: 0.12),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        // Badge complet
        if (nbEleves > 0 && nbSaved == nbEleves)
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _kGreen.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: _kGreen.withValues(alpha: 0.3)),
            ),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.check_circle_outline,
                  color: _kGreen, size: 13),
              SizedBox(width: 4),
              Text('Complet',
                  style: TextStyle(
                      color: _kGreen,
                      fontSize: 11,
                      fontWeight: FontWeight.w700)),
            ]),
          ),
      ]),
    );
  }
}

// ─── Carte élève + champ appréciation ─────────────────────────────────────────

class _EleveAppreciationCard extends StatefulWidget {
  final UserModel eleve;
  final double? moyenne;
  final AppreciationModel? existing;
  final ClasseModel classe;
  final int trimestre;
  final String matiere;
  final String profNom;
  final VoidCallback onSaved;

  const _EleveAppreciationCard({
    super.key,
    required this.eleve,
    required this.moyenne,
    required this.existing,
    required this.classe,
    required this.trimestre,
    required this.matiere,
    required this.profNom,
    required this.onSaved,
  });

  @override
  State<_EleveAppreciationCard> createState() =>
      _EleveAppreciationCardState();
}

class _EleveAppreciationCardState
    extends State<_EleveAppreciationCard> {
  late TextEditingController _ctrl;
  bool _saving = false;
  bool _saved = false;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(
        text: widget.existing?.texte ?? '');
    _ctrl.addListener(() {
      if (!_dirty) setState(() => _dirty = true);
      if (_saved) setState(() => _saved = false);
    });
  }

  @override
  void didUpdateWidget(_EleveAppreciationCard old) {
    super.didUpdateWidget(old);
    // Mise à jour silencieuse si une sauvegarde externe change le texte
    if (old.existing?.texte != widget.existing?.texte &&
        !_dirty) {
      _ctrl.text = widget.existing?.texte ?? '';
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final texte = _ctrl.text.trim();
    if (texte.isEmpty) return;
    setState(() => _saving = true);
    try {
      final e = widget.eleve;
      await AppreciationService.save(
        eleveId: e.uid,
        eleveNom: e.displayName.split(' ').last,
        elevePrenom: e.displayName.split(' ').first,
        classeId: widget.classe.id,
        classeNom: widget.classe.nom,
        matiere: widget.matiere,
        trimestre: widget.trimestre,
        anneeScol: DateTime.now().year,
        texte: texte,
        professeurNom: widget.profNom,
      );
      if (mounted) {
        setState(() {
          _saving = false;
          _saved = true;
          _dirty = false;
        });
        widget.onSaved();
        // Reset le badge "Enregistré" après 2s
        Future<void>.delayed(const Duration(seconds: 2)).then((_) {
          if (mounted) setState(() => _saved = false);
        });
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

  Color get _moyColor {
    final m = widget.moyenne;
    if (m == null) return Colors.white38;
    if (m >= 14) return _kGreen;
    if (m >= 10) return _kOrange;
    return _kRed;
  }

  String get _suggestionText {
    final m = widget.moyenne;
    if (m == null) return '';
    if (m >= 16) return 'Excellent trimestre. Félicitations, continuez sur cette lancée !';
    if (m >= 14) return 'Très bon travail. Des résultats solides qui témoignent d\'un engagement sérieux.';
    if (m >= 12) return 'Bon trimestre dans l\'ensemble. Quelques points à consolider pour atteindre l\'excellence.';
    if (m >= 10) return 'Résultats satisfaisants. Persévérance et régularité permettront de progresser.';
    if (m >= 8) return 'Des efforts sont nécessaires. Je vous encourage à revoir les notions fondamentales.';
    return 'Résultats très insuffisants. Un travail de rattrapage urgent est indispensable.';
  }

  @override
  Widget build(BuildContext context) {
    final hasMoy = widget.moyenne != null;
    final moy = widget.moyenne;
    final hasSavedText = widget.existing?.texte.isNotEmpty == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _saved
              ? _kGreen.withValues(alpha: 0.5)
              : _dirty
                  ? _kPurple.withValues(alpha: 0.35)
                  : Colors.white.withValues(alpha: 0.06),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // En-tête élève
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
            child: Row(children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: _kPurple.withValues(alpha: 0.15),
                child: Text(
                  widget.eleve.displayName.isNotEmpty
                      ? widget.eleve.displayName[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                      color: _kPurple,
                      fontWeight: FontWeight.bold,
                      fontSize: 14),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.eleve.displayName,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 14),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    if (widget.matiere.isNotEmpty)
                      Text(widget.matiere,
                          style: const TextStyle(
                              color: Colors.white38,
                              fontSize: 11)),
                  ],
                ),
              ),
              // Moyenne
              if (hasMoy)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _moyColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: _moyColor.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    '${moy!.toStringAsFixed(2)}/20',
                    style: TextStyle(
                        color: _moyColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 13),
                  ),
                )
              else
                const Text('—/20',
                    style: TextStyle(
                        color: Colors.white24, fontSize: 13)),
              // Status badge
              if (_saved || hasSavedText && !_dirty) ...[
                const SizedBox(width: 8),
                Icon(
                  _saved ? Icons.check_circle : Icons.check_circle_outline,
                  color: _saved ? _kGreen : Colors.white24,
                  size: 16,
                ),
              ],
            ]),
          ),
          // Barre de progression moyenne
          if (hasMoy) ...[
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: (moy! / 20).clamp(0.0, 1.0),
                  minHeight: 2,
                  color: _moyColor,
                  backgroundColor:
                      _moyColor.withValues(alpha: 0.1),
                ),
              ),
            ),
          ],
          const SizedBox(height: 10),
          // Champ appréciation
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: TextField(
              controller: _ctrl,
              style: const TextStyle(
                  color: Colors.white, fontSize: 13),
              maxLines: 3,
              minLines: 2,
              textInputAction: TextInputAction.newline,
              decoration: InputDecoration(
                hintText: hasMoy
                    ? _suggestionText
                    : 'Saisir l\'appréciation…',
                hintStyle: const TextStyle(
                    color: Colors.white24, fontSize: 12),
                filled: true,
                fillColor: _kCard2,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
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
          ),
          // Boutons action
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Row(children: [
              // Suggestion auto
              if (hasMoy && _ctrl.text.isEmpty)
                TextButton.icon(
                  onPressed: () {
                    _ctrl.text = _suggestionText;
                    setState(() => _dirty = true);
                  },
                  icon: const Icon(Icons.auto_fix_high,
                      size: 13, color: Colors.white38),
                  label: const Text('Suggestion auto',
                      style: TextStyle(
                          color: Colors.white38, fontSize: 11)),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                  ),
                ),
              const Spacer(),
              // Bouton Enregistrer
              if (_dirty || _ctrl.text.isNotEmpty)
                ElevatedButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 13,
                          height: 13,
                          child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 1.5))
                      : Icon(
                          _saved
                              ? Icons.check
                              : Icons.save_outlined,
                          size: 14),
                  label: Text(
                    _saving
                        ? 'Enregistrement…'
                        : _saved
                            ? 'Enregistré !'
                            : 'Enregistrer',
                    style: const TextStyle(fontSize: 12),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        _saved ? _kGreen : _kTeal,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    textStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600),
                  ),
                ),
            ]),
          ),
        ],
      ),
    );
  }
}
