import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/devoir_model.dart';
import '../services/etudiant_service.dart';
import '../services/revision_firestore_service.dart';
import 'etudiant_revisions_ia_page.dart';
import 'etudiant_matiere_libre_page.dart';
import 'etudiant_progression_page.dart';

// ─── Hiérarchie scolaire ──────────────────────────────────────────────────────

const _kMatieres = <String, List<String>>{
  'Maternelle': ['Éveil', 'Lecture & Écriture', 'Calcul', 'Arts plastiques', 'Motricité'],
  'Primaire':   ['Mathématiques', 'Français', 'Histoire-Géo', 'Sciences', 'Anglais', 'Arts'],
  'Collège':    ['Mathématiques', 'Français', 'Histoire-Géo', 'SVT', 'Physique-Chimie', 'Anglais', 'Espagnol', 'Informatique'],
  'Lycée':      ['Mathématiques', 'Français', 'Histoire-Géo', 'SVT', 'Physique-Chimie', 'Anglais', 'Philosophie', 'Spécialité'],
  'Université': ['Mathématiques', 'Informatique', 'Économie', 'Droit', 'Sciences', 'Langues', 'Lettres', 'Autre'],
};

const _kDefaultMatieres = ['Mathématiques', 'Français', 'Histoire-Géo', 'SVT', 'Physique-Chimie', 'Anglais'];

const _kNiveauxParCategorie = <String, List<String>>{
  'Maternelle': ['PS', 'MS', 'GS', 'TPS'],
  'Primaire':   ['CP', 'CE1', 'CE2', 'CM1', 'CM2'],
  'Collège':    ['6e', '5e', '4e', '3e', '6ème', '5ème', '4ème', '3ème'],
  'Lycée':      ['Seconde', 'Première', 'Terminale', '2nde', '1ère', '1ere'],
  'Université': ['L1', 'L2', 'L3', 'M1', 'M2', 'Doctorat'],
};

String _inferCategorie(String niveau) {
  final niv = niveau.trim().toLowerCase();
  if (niv.isEmpty) return '';
  for (final entry in _kNiveauxParCategorie.entries) {
    for (final n in entry.value) {
      if (niv == n.toLowerCase() || niv.contains(n.toLowerCase())) return entry.key;
    }
  }
  return '';
}

// ─── Couleurs / gradients par matière ────────────────────────────────────────

const _kGradients = <String, List<Color>>{
  'Mathématiques'   : [Color(0xFF2563EB), Color(0xFF0891B2)],
  'Français'        : [Color(0xFF7C3AED), Color(0xFF6C47FF)],
  'Histoire-Géo'    : [Color(0xFFB45309), Color(0xFFD97706)],
  'SVT'             : [Color(0xFF15803D), Color(0xFF16A34A)],
  'Physique-Chimie' : [Color(0xFFDC2626), Color(0xFFEA580C)],
  'Anglais'         : [Color(0xFF0F766E), Color(0xFF0891B2)],
  'Espagnol'        : [Color(0xFFD97706), Color(0xFFCA8A04)],
  'Informatique'    : [Color(0xFF374151), Color(0xFF4B5563)],
  'Philosophie'     : [Color(0xFF6C47FF), Color(0xFF9333EA)],
  'Éveil'           : [Color(0xFFF59E0B), Color(0xFFD97706)],
  'Calcul'          : [Color(0xFF2563EB), Color(0xFF0891B2)],
  'Sciences'        : [Color(0xFF047857), Color(0xFF065F46)],
  'Économie'        : [Color(0xFF0891B2), Color(0xFF0E7490)],
  'Droit'           : [Color(0xFF1D4ED8), Color(0xFF1E40AF)],
  'Lettres'         : [Color(0xFF7C3AED), Color(0xFF6C47FF)],
};

List<Color> _grad(String m) =>
    _kGradients[m] ?? const [Color(0xFF6C47FF), Color(0xFF2563EB)];

// ─── SharedPreferences ────────────────────────────────────────────────────────

const _kPrefPrefix  = 'revisions_v3_';
const _kPrefProgKey = '${_kPrefPrefix}progress_';
const _kPrefCatKey  = '${_kPrefPrefix}categorie_';

Future<Map<String, int>> _loadProgress() async {
  final prefs = await SharedPreferences.getInstance();
  final uid   = FirebaseAuth.instance.currentUser?.uid ?? 'guest';
  final raw   = prefs.getString('$_kPrefProgKey$uid') ?? '{}';
  return Map<String, int>.from(jsonDecode(raw) as Map);
}

Future<void> _saveProgress(Map<String, int> p) async {
  final prefs = await SharedPreferences.getInstance();
  final uid   = FirebaseAuth.instance.currentUser?.uid ?? 'guest';
  await prefs.setString('$_kPrefProgKey$uid', jsonEncode(p));
}

// ═══════════════════════════════════════════════════════════════════════════════
// Page principale
// ═══════════════════════════════════════════════════════════════════════════════

class EtudiantRevisionsPage extends StatefulWidget {
  const EtudiantRevisionsPage({super.key});

  @override
  State<EtudiantRevisionsPage> createState() => _EtudiantRevisionsPageState();
}

class _EtudiantRevisionsPageState extends State<EtudiantRevisionsPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  Map<String, String> _profil = {};
  Map<String, int> _progress = {};
  bool _loading = true;

  String get _categorie => _profil['categorie'] ?? '';
  String get _niveau    => _profil['niveau'] ?? '';
  String get _classeNom => _profil['classeNom'] ?? '';
  List<String> get _matieres => _kMatieres[_categorie] ?? _kDefaultMatieres;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
    _init();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    final progress = await _loadProgress();
    final profil   = await EtudiantService.profilStream().first;

    var cat  = (profil['categorie'] ?? '').trim();
    final niv = (profil['niveau'] ?? '').trim();
    final cn  = (profil['classeNom'] ?? '').trim();

    if (cat.isEmpty) cat = _inferCategorie(niv.isNotEmpty ? niv : cn);

    // Fallback: previously chosen categorie
    if (cat.isEmpty) {
      final prefs = await SharedPreferences.getInstance();
      final uid   = FirebaseAuth.instance.currentUser?.uid ?? 'guest';
      cat = prefs.getString('$_kPrefCatKey$uid') ?? '';
    }

    if (mounted) {
      setState(() {
        _profil   = {...profil, 'categorie': cat};
        _progress = progress;
        _loading  = false;
      });
      if (cat.isEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _pickCategorie());
      }
    }
  }

  Future<void> _pickCategorie() async {
    final chosen = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _CategoriePicker(current: _categorie),
    );
    if (chosen != null && chosen.isNotEmpty && mounted) {
      final prefs = await SharedPreferences.getInstance();
      final uid   = FirebaseAuth.instance.currentUser?.uid ?? 'guest';
      await prefs.setString('$_kPrefCatKey$uid', chosen);
      setState(() => _profil = {..._profil, 'categorie': chosen});
    }
  }

  void _onProgressUpdate(String matiere, int score) {
    final updated = Map<String, int>.from(_progress)..[matiere] = score;
    setState(() => _progress = updated);
    _saveProgress(updated);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Révisions',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            Text(
              _categorie.isNotEmpty
                  ? '$_categorie${_niveau.isNotEmpty ? " · $_niveau" : ""}${_classeNom.isNotEmpty ? " · $_classeNom" : ""}'
                  : '— Choisir le niveau →',
              style: TextStyle(
                color: _categorie.isNotEmpty ? Colors.white38 : Colors.orangeAccent,
                fontSize: 11,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.smart_toy_outlined, color: Colors.white70),
            tooltip: 'IA Scolaire — assistant IA',
            onPressed: () => Navigator.pushNamed(context, '/ai_scolaire'),
          ),
          IconButton(
            icon: const Icon(Icons.tune, color: Colors.white70),
            tooltip: 'Changer de niveau',
            onPressed: _loading ? null : _pickCategorie,
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: const [
            Tab(icon: Icon(Icons.book_outlined, size: 18), text: 'Mes devoirs'),
            Tab(icon: Icon(Icons.grid_view_outlined, size: 18), text: 'Matières libres'),
            Tab(icon: Icon(Icons.trending_up_outlined, size: 18), text: 'Progression'),
            Tab(icon: Icon(Icons.dashboard_outlined, size: 18), text: 'Tableau de bord'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF2563EB)))
          : TabBarView(
              controller: _tabs,
              children: [
                _DevoirsRevisionsTab(classeNom: _classeNom),
                _MatieresLibresTab(
                  matieres: _matieres,
                  categorie: _categorie,
                  classeNom: _classeNom,
                  progress: _progress,
                  onProgressUpdate: _onProgressUpdate,
                ),
                const ProgressionContent(),
                const _RevisionDashboardTab(),
              ],
            ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Tab 1 — Devoirs à réviser
// ═══════════════════════════════════════════════════════════════════════════════

class _DevoirsRevisionsTab extends StatelessWidget {
  final String classeNom;
  const _DevoirsRevisionsTab({required this.classeNom});

  @override
  Widget build(BuildContext context) {
    if (classeNom.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.school_outlined, color: Colors.white24, size: 48),
              const SizedBox(height: 16),
              const Text(
                'Aucune classe assignée.\nContacte ton professeur ou l\'administration.',
                style: TextStyle(color: Colors.white54, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              const Text(
                'Tu peux quand même utiliser les Matières libres\npour réviser les notions générales.',
                style: TextStyle(color: Colors.white38, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return StreamBuilder<List<DevoirModel>>(
      stream: EtudiantService.devoirsStream(classeNom),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFF2563EB)));
        }
        if (snap.hasError) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Impossible de charger les devoirs.\nVérifiez votre connexion.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54, fontSize: 13),
              ),
            ),
          );
        }
        final devoirs = snap.data ?? [];
        if (devoirs.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.inbox_outlined, color: Colors.white24, size: 48),
                  SizedBox(height: 16),
                  Text(
                    'Aucun devoir reçu pour l\'instant.',
                    style: TextStyle(color: Colors.white54, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Dès que ton professeur envoie un devoir,\nil apparaîtra ici avec le bouton "Réviser avec l\'IA".',
                    style: TextStyle(color: Colors.white38, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Explainer banner
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF0F766E), Color(0xFF2563EB)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.smart_toy_outlined, color: Colors.white, size: 28),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Réviser avec l\'IA',
                                    style: TextStyle(
                                        color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                                const SizedBox(height: 2),
                                Text('${devoirs.length} devoir${devoirs.length > 1 ? 's' : ''} disponible${devoirs.length > 1 ? 's' : ''} · L\'IA analyse le devoir et génère cours, exercices et quiz',
                                    style: const TextStyle(color: Colors.white70, fontSize: 11)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) => _DevoirRevisionCard(devoir: devoirs[i]),
                  childCount: devoirs.length,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _DevoirRevisionCard extends StatelessWidget {
  final DevoirModel devoir;
  const _DevoirRevisionCard({required this.devoir});

  @override
  Widget build(BuildContext context) {
    final d    = devoir;
    final grad = _grad(d.matiere);
    final now  = DateTime.now();
    final isExpired = d.dateLimite != null && now.isAfter(d.dateLimite!);
    final dueLbl = d.dateLimite != null
        ? 'Limite : ${_fmt(d.dateLimite!)}'
        : 'Envoyé le ${_fmt(d.dateEnvoi)}';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with matière gradient
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                  colors: [grad.first.withValues(alpha: 0.18), Colors.transparent],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: grad),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(d.matiere,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 8),
                if (d.estExamen)
                  _Chip(label: 'Examen', color: Colors.red)
                else if (d.estInteractif)
                  _Chip(label: 'Interactif', color: Colors.blue)
                else
                  _Chip(label: 'PDF', color: Colors.orange),
                const Spacer(),
                Text(dueLbl,
                    style: TextStyle(
                        color: isExpired ? Colors.red[300] : Colors.white38,
                        fontSize: 10)),
              ],
            ),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(d.titre,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                if (d.description.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(d.description,
                      style: const TextStyle(color: Colors.white54, fontSize: 12, height: 1.4),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                ],
                if (d.estInteractif) ...[
                  const SizedBox(height: 4),
                  Text('${d.questions.length} question${d.questions.length > 1 ? 's' : ''}',
                      style: const TextStyle(color: Colors.white38, fontSize: 11)),
                ],
                const SizedBox(height: 12),
                // Bouton principal
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: grad.first,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => EtudiantRevisionsIaPage(devoir: d),
                      ),
                    ),
                    icon: const Icon(Icons.smart_toy_outlined, size: 18),
                    label: const Text('Réviser avec l\'IA',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _fmt(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  const _Chip({required this.label, required this.color});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Text(label,
            style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600)),
      );
}

// ═══════════════════════════════════════════════════════════════════════════════
// Tab 2 — Matières libres (révision générale sans devoir spécifique)
// ═══════════════════════════════════════════════════════════════════════════════

class _MatieresLibresTab extends StatelessWidget {
  final List<String> matieres;
  final String categorie, classeNom;
  final Map<String, int> progress;
  final void Function(String, int) onProgressUpdate;

  const _MatieresLibresTab({
    required this.matieres,
    required this.categorie,
    required this.classeNom,
    required this.progress,
    required this.onProgressUpdate,
  });

  @override
  Widget build(BuildContext context) {
    final mastered = progress.values.where((v) => v >= 80).length;
    final total    = matieres.length;
    final pct      = total == 0 ? 0 : (mastered * 100 ~/ total);

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              children: [
                // Info banner
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF161B22),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                  ),
                  child: Row(
                    children: [
                      Stack(alignment: Alignment.center, children: [
                        SizedBox(
                          width: 52, height: 52,
                          child: CircularProgressIndicator(
                            value: pct / 100,
                            backgroundColor: Colors.white12,
                            color: pct >= 80 ? Colors.green : const Color(0xFF2563EB),
                            strokeWidth: 5,
                          ),
                        ),
                        Text('$pct%',
                            style: const TextStyle(
                                color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                      ]),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Révision générale',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14)),
                            const SizedBox(height: 2),
                            Text('$mastered / $total matières maîtrisées',
                                style: const TextStyle(color: Colors.white54, fontSize: 12)),
                            const SizedBox(height: 2),
                            const Text(
                              'Clique sur une matière → génère cours et quiz avec l\'IA',
                              style: TextStyle(color: Colors.white38, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
          sliver: SliverGrid(
            delegate: SliverChildBuilderDelegate(
              (ctx, i) {
                final m = matieres[i];
                return _MatiereCard(
                  matiere: m,
                  score: progress[m],
                  onTap: () => Navigator.push(
                    ctx,
                    MaterialPageRoute(
                      builder: (_) => EtudiantMatiereLibrePage(
                        matiere: m,
                        categorieInitiale: categorie,
                        classeNom: classeNom,
                      ),
                    ),
                  ),
                );
              },
              childCount: matieres.length,
            ),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.1,
            ),
          ),
        ),
      ],
    );
  }
}

class _MatiereCard extends StatelessWidget {
  final String matiere;
  final int? score;
  final VoidCallback onTap;
  const _MatiereCard({required this.matiere, required this.score, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final pct         = score ?? 0;
    final statusColor = pct >= 80
        ? const Color(0xFF16A34A)
        : pct >= 40
            ? const Color(0xFFD97706)
            : Colors.white38;
    final g = _grad(matiere);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF161B22),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: g),
                borderRadius: BorderRadius.circular(11),
              ),
              child: const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: Text(matiere,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
            ),
            const SizedBox(height: 6),
            if (pct > 0) ...[
              LinearProgressIndicator(
                value: pct / 100,
                backgroundColor: Colors.white12,
                color: statusColor,
                minHeight: 4,
              ),
              const SizedBox(height: 4),
              Text('$pct%', style: TextStyle(color: statusColor, fontSize: 10)),
            ] else
              const Text('Non démarré', style: TextStyle(color: Colors.white38, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Tab 4 — Tableau de bord révisions (stats Firebase)
// ═══════════════════════════════════════════════════════════════════════════════

class _RevisionDashboardTab extends StatelessWidget {
  const _RevisionDashboardTab();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, dynamic>>(
      stream: RevisionFirestoreService.statsStream(),
      builder: (context, statsSnap) {
        return StreamBuilder<List<Map<String, dynamic>>>(
          stream: RevisionFirestoreService.historyStream(limit: 10),
          builder: (context, histSnap) {
            final stats   = statsSnap.data ?? {};
            final history = histSnap.data ?? [];

            final totalSessions  = (stats['totalSessions']   as num?)?.toInt()  ?? 0;
            final totalQuiz      = (stats['totalQuiz']       as num?)?.toInt()  ?? 0;
            final sumScores      = (stats['sumScores']       as num?)?.toInt()  ?? 0;
            final totalFiches    = (stats['totalFiches']     as num?)?.toInt()  ?? 0;
            final totalFlashcards= (stats['totalFlashcards'] as num?)?.toInt()  ?? 0;
            final tempsTotal     = (stats['tempsTotal']      as num?)?.toInt()  ?? 0;
            final avgScore       = totalQuiz > 0 ? sumScores ~/ totalQuiz : 0;

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ── Header ──────────────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0F766E), Color(0xFF2563EB)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(children: [
                    const Icon(Icons.auto_awesome, color: Colors.white, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Tableau de bord',
                              style: TextStyle(
                                  color: Colors.white, fontSize: 16,
                                  fontWeight: FontWeight.bold)),
                          Text(
                            totalSessions == 0
                                ? 'Lance ta première révision pour voir les stats ici.'
                                : '$totalSessions session${totalSessions > 1 ? 's' : ''} de révision au total',
                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: 20),

                // ── KPI grid ────────────────────────────────────────────────
                const _SectionLabel(text: 'MES STATISTIQUES'),
                const SizedBox(height: 10),
                GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: 1.5,
                  children: [
                    _KpiCard(
                      icon: Icons.school_outlined,
                      color: const Color(0xFF2563EB),
                      label: 'Sessions',
                      value: '$totalSessions',
                    ),
                    _KpiCard(
                      icon: Icons.quiz_outlined,
                      color: const Color(0xFF6C47FF),
                      label: 'Quiz passés',
                      value: '$totalQuiz',
                    ),
                    _KpiCard(
                      icon: Icons.percent_outlined,
                      color: avgScore >= 70
                          ? const Color(0xFF16A34A)
                          : avgScore >= 50
                              ? const Color(0xFFD97706)
                              : const Color(0xFFDC2626),
                      label: 'Score moyen',
                      value: totalQuiz > 0 ? '$avgScore%' : '—',
                    ),
                    _KpiCard(
                      icon: Icons.article_outlined,
                      color: const Color(0xFF0F766E),
                      label: 'Fiches créées',
                      value: '$totalFiches',
                    ),
                    _KpiCard(
                      icon: Icons.style_outlined,
                      color: const Color(0xFFD97706),
                      label: 'Flashcards vues',
                      value: '$totalFlashcards',
                    ),
                    _KpiCard(
                      icon: Icons.timer_outlined,
                      color: const Color(0xFF7C3AED),
                      label: 'Temps total',
                      value: tempsTotal > 0 ? '${tempsTotal}min' : '—',
                    ),
                  ],
                ),

                if (history.isNotEmpty) ...[
                  const SizedBox(height: 24),

                  // ── Historique récent ──────────────────────────────────────
                  const _SectionLabel(text: 'ACTIVITÉ RÉCENTE'),
                  const SizedBox(height: 10),
                  ...history.take(8).map((s) => _HistoryTile(session: s)),
                ],

                if (totalSessions == 0) ...[
                  const SizedBox(height: 32),
                  const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.auto_graph_outlined, color: Colors.white12, size: 56),
                        SizedBox(height: 16),
                        Text(
                          'Commence à réviser pour remplir\nton tableau de bord !',
                          style: TextStyle(color: Colors.white38, fontSize: 14),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Cours · Fiches · Flashcards · Quiz\ntout est tracé automatiquement.',
                          style: TextStyle(color: Colors.white24, fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 32),
              ],
            );
          },
        );
      },
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel({required this.text});
  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(
          color: Colors.white38, fontSize: 11,
          fontWeight: FontWeight.w700, letterSpacing: 1.2));
}

class _KpiCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label, value;
  const _KpiCard({
    required this.icon, required this.color,
    required this.label, required this.value,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFF161B22),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color.withValues(alpha: 0.2)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 16),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: TextStyle(
                color: color, fontSize: 20, fontWeight: FontWeight.bold)),
            Text(label, style: const TextStyle(
                color: Colors.white54, fontSize: 11)),
          ],
        ),
      ],
    ),
  );
}

class _HistoryTile extends StatelessWidget {
  final Map<String, dynamic> session;
  const _HistoryTile({required this.session});

  static const _typeLabels = <String, String>{
    'cours'      : 'Cours',
    'fiche'      : 'Fiche',
    'flashcards' : 'Flashcards',
    'quiz'       : 'Quiz',
    'exercices'  : 'Exercices',
    'bac'        : 'Sujet BAC',
    'grand_oral' : 'Grand Oral',
    'partiel'    : 'Partiel',
  };

  static const _typeColors = <String, Color>{
    'cours'      : Color(0xFF2563EB),
    'fiche'      : Color(0xFF0F766E),
    'flashcards' : Color(0xFFD97706),
    'quiz'       : Color(0xFF6C47FF),
    'exercices'  : Color(0xFFDC2626),
    'bac'        : Color(0xFF7C3AED),
    'grand_oral' : Color(0xFF9333EA),
    'partiel'    : Color(0xFF047857),
  };

  static const _typeIcons = <String, IconData>{
    'cours'      : Icons.menu_book_outlined,
    'fiche'      : Icons.article_outlined,
    'flashcards' : Icons.style_outlined,
    'quiz'       : Icons.quiz_outlined,
    'exercices'  : Icons.edit_outlined,
    'bac'        : Icons.school_outlined,
    'grand_oral' : Icons.record_voice_over_outlined,
    'partiel'    : Icons.assignment_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final type     = session['type'] as String? ?? 'cours';
    final matiere  = session['matiere'] as String? ?? '';
    final cat      = session['categorie'] as String? ?? '';
    final score    = (session['score'] as num?)?.toInt();
    final color    = _typeColors[type] ?? const Color(0xFF6C47FF);
    final icon     = _typeIcons[type] ?? Icons.auto_awesome;
    final typeLabel= _typeLabels[type] ?? type;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(matiere,
                style: const TextStyle(
                    color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
            Text('$typeLabel · $cat',
                style: const TextStyle(color: Colors.white38, fontSize: 11)),
          ]),
        ),
        if (score != null) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: (score >= 70
                  ? const Color(0xFF16A34A)
                  : score >= 50
                      ? const Color(0xFFD97706)
                      : const Color(0xFFDC2626))
                  .withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text('$score%',
                style: TextStyle(
                    color: score >= 70
                        ? const Color(0xFF16A34A)
                        : score >= 50
                            ? const Color(0xFFD97706)
                            : const Color(0xFFDC2626),
                    fontSize: 11,
                    fontWeight: FontWeight.bold)),
          ),
        ],
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Sélecteur de catégorie
// ═══════════════════════════════════════════════════════════════════════════════

class _CategoriePicker extends StatelessWidget {
  final String current;
  const _CategoriePicker({required this.current});

  static const _items = <Map<String, dynamic>>[
    {'cat': 'Maternelle',  'icon': Icons.child_friendly_outlined,   'sub': 'PS · MS · GS'},
    {'cat': 'Primaire',    'icon': Icons.school_outlined,            'sub': 'CP · CE1 · CE2 · CM1 · CM2'},
    {'cat': 'Collège',     'icon': Icons.menu_book_outlined,         'sub': '6ème · 5ème · 4ème · 3ème'},
    {'cat': 'Lycée',       'icon': Icons.auto_stories_outlined,      'sub': 'Seconde · Première · Terminale'},
    {'cat': 'Université',  'icon': Icons.account_balance_outlined,   'sub': 'Licence · Master · Doctorat'},
  ];

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF161B22),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: const Text('Choisir ton niveau',
          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: _items.map((item) {
          final cat    = item['cat'] as String;
          final isSelected = cat == current;
          return GestureDetector(
            onTap: () => Navigator.of(context).pop(cat),
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF0F766E).withValues(alpha: 0.3)
                    : const Color(0xFF0D1117),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFF0F766E)
                      : Colors.white.withValues(alpha: 0.08),
                ),
              ),
              child: Row(children: [
                Icon(item['icon'] as IconData,
                    color: isSelected ? const Color(0xFF0F766E) : Colors.white54, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(cat,
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.white70,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          fontSize: 14,
                        )),
                    Text(item['sub'] as String,
                        style: const TextStyle(color: Colors.white38, fontSize: 11)),
                  ]),
                ),
                if (isSelected)
                  const Icon(Icons.check_circle, color: Color(0xFF0F766E), size: 18),
              ]),
            ),
          );
        }).toList(),
      ),
    );
  }
}
