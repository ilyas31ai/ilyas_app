import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../models/remplacement_model.dart';
import '../models/school_model.dart';
import '../models/user_model.dart';
import '../services/remplacement_service.dart';
import '../services/user_service.dart';
import 'direction_classes_page.dart';
import 'direction_comptes_attente_page.dart';
import 'direction_disponibilites_page.dart';
import 'direction_eleves_page.dart';
import 'direction_historique_remplacements_page.dart';
import 'direction_statistiques_page.dart';
import 'notifications_page.dart';

// ─── Data ─────────────────────────────────────────────────────────────────────

class _Stats {
  final double? presenceRate;
  final int? inscriptionsValidees;
  final int? devoirsActifs;
  final int? totalAbsences;
  const _Stats({
    this.presenceRate,
    this.inscriptionsValidees,
    this.devoirsActifs,
    this.totalAbsences,
  });
}

// ─── Page ─────────────────────────────────────────────────────────────────────

class DirectionDashboardPage extends StatefulWidget {
  const DirectionDashboardPage({super.key});

  @override
  State<DirectionDashboardPage> createState() =>
      _DirectionDashboardPageState();
}

class _DirectionDashboardPageState extends State<DirectionDashboardPage> {
  static final _db = FirebaseFirestore.instance;

  // ── Palette ─────────────────────────────────────────────────────────────────
  static const _bg     = Color(0xFF0D1117);
  static const _card   = Color(0xFF161B22);
  static const _card2  = Color(0xFF1F2937);
  static const _border = Color(0xFF30363D);
  static const _orange = Color(0xFFF59E0B);
  static const _blue   = Color(0xFF2563EB);
  static const _purple = Color(0xFF6C47FF);
  static const _green  = Color(0xFF16A34A);
  static const _red    = Color(0xFFDC2626);
  static const _cyan   = Color(0xFF0891B2);

  // ── State ───────────────────────────────────────────────────────────────────
  String _schoolId = '';
  Future<_Stats>? _statsFuture;
  bool _codeLoading = false;

  final _searchCtrl  = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── Init ────────────────────────────────────────────────────────────────────

  Future<void> _init() async {
    final id = await UserService.currentSchoolId();
    if (!mounted) return;
    setState(() {
      _schoolId = id;
      _statsFuture = _loadStats(id);
    });
    await _ensureInvitationCode(id);
  }

  Future<void> _ensureInvitationCode(String schoolId) async {
    if (schoolId.isEmpty || schoolId == kDefaultSchoolId) return;
    final snap = await _db.collection('schools').doc(schoolId).get();
    final existing = (snap.data()?['codeInvitation'] as String?)?.trim() ?? '';
    if (existing.isNotEmpty) return;
    final code = _generateCode();
    await _db.collection('schools').doc(schoolId).set(
        {'codeInvitation': code}, SetOptions(merge: true));
  }

  String _generateCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rand = Random.secure();
    return List.generate(6, (_) => chars[rand.nextInt(chars.length)]).join();
  }

  Future<void> _regenerateCode() async {
    if (_schoolId.isEmpty || _schoolId == kDefaultSchoolId) return;
    setState(() => _codeLoading = true);
    final code = _generateCode();
    await _db.collection('schools').doc(_schoolId).set(
        {'codeInvitation': code}, SetOptions(merge: true));
    if (mounted) setState(() => _codeLoading = false);
  }

  Future<_Stats> _loadStats(String schoolId) async {
    final since = Timestamp.fromDate(
        DateTime.now().subtract(const Duration(days: 7)));

    double? presenceRate;
    int? totalAbsences;
    try {
      final presSnap = await _db
          .collection('presences')
          .where('date', isGreaterThan: since)
          .limit(500)
          .get();
      final total = presSnap.docs.length;
      if (total > 0) {
        final present = presSnap.docs
            .where((d) =>
                d.data()['present'] == true ||
                d.data()['statut'] == 'present')
            .length;
        presenceRate = present / total * 100;
        totalAbsences = presSnap.docs
            .where((d) => d.data()['statut'] == 'absent')
            .length;
      }
    } catch (_) {}

    int? inscriptionsValidees;
    int? devoirsActifs;
    try {
      final inscSnap = await _db
          .collection('eleves')
          .where('statutInscription', isEqualTo: 'validee')
          .limit(500)
          .get();
      inscriptionsValidees = inscSnap.docs.length;
    } catch (_) {}
    try {
      final devoirsSnap = await _db.collection('devoirs').limit(300).get();
      devoirsActifs = devoirsSnap.docs.length;
    } catch (_) {}

    return _Stats(
      presenceRate: presenceRate,
      inscriptionsValidees: inscriptionsValidees,
      devoirsActifs: devoirsActifs,
      totalAbsences: totalAbsences,
    );
  }

  // ── Actions ─────────────────────────────────────────────────────────────────

  void _copyCode(String code) {
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: const Text('Code copié'),
      backgroundColor: _green,
      duration: const Duration(seconds: 2),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  void _shareCode(String code, String schoolNom) {
    Clipboard.setData(ClipboardData(
        text: 'Rejoignez $schoolNom sur SCOLAR AI Educative avec le code : $code'));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: const Text('Message copié — partagez-le à vos utilisateurs'),
      backgroundColor: _blue,
      duration: const Duration(seconds: 2),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  void _showCreateAnnonce(String schoolNom) {
    final titreCtrl   = TextEditingController();
    final contenuCtrl = TextEditingController();
    String type = 'annonce';
    const types = [
      ('Annonce', 'annonce', Icons.campaign_outlined),
      ('Urgence', 'urgence', Icons.warning_amber_outlined),
      ('Info',    'info',    Icons.info_outline),
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          backgroundColor: _card,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Nouvelle annonce',
              style: TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  children: types.map((t) {
                    final (label, value, icon) = t;
                    final sel = type == value;
                    return GestureDetector(
                      onTap: () => setS(() => type = value),
                      child: Chip(
                        avatar: Icon(icon,
                            size: 14,
                            color: sel ? Colors.white : Colors.white54),
                        label: Text(label,
                            style: TextStyle(
                                color: sel ? Colors.white : Colors.white54,
                                fontSize: 12)),
                        backgroundColor: sel ? _purple : _card2,
                        side: BorderSide(color: sel ? _purple : _border),
                        padding: EdgeInsets.zero,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: titreCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputDeco('Titre'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: contenuCtrl,
                  style: const TextStyle(color: Colors.white),
                  maxLines: 4,
                  decoration: _inputDeco("Contenu de l'annonce"),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler',
                  style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _purple,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () async {
                final titre   = titreCtrl.text.trim();
                final contenu = contenuCtrl.text.trim();
                if (titre.isEmpty || contenu.isEmpty) return;
                final uid  = FirebaseAuth.instance.currentUser?.uid ?? '';
                final user = await UserService.currentUserStream().first;
                await _db.collection('annonces').add({
                  'schoolId': _schoolId,
                  'titre': titre,
                  'contenu': contenu,
                  'auteurId': uid,
                  'auteurNom': user?.displayName ?? 'Directeur',
                  'date': Timestamp.now(),
                  'type': type,
                });
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Publier'),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDeco(String label) => InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white54),
        filled: true,
        fillColor: _card2,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _border)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _border)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _purple)),
      );

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: _buildAppBar(),
      body: _schoolId.isEmpty
          ? const Center(child: CircularProgressIndicator(color: _purple))
          : StreamBuilder<DocumentSnapshot>(
              stream: _db.collection('schools').doc(_schoolId).snapshots(),
              builder: (ctx, schoolSnap) {
                final schoolData =
                    schoolSnap.data?.data() as Map<String, dynamic>?;
                final schoolNom =
                    schoolData?['nom'] as String? ?? 'Mon établissement';
                final schoolVille =
                    schoolData?['ville'] as String? ?? '';
                final inviteCode =
                    schoolData?['codeInvitation'] as String? ?? '';

                return RefreshIndicator(
                  color: _purple,
                  backgroundColor: _card,
                  onRefresh: () async =>
                      setState(() => _statsFuture = _loadStats(_schoolId)),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
                    children: [
                      // 1. Recherche globale
                      _buildSearchBar(),
                      const SizedBox(height: 16),

                      // 2. Hero établissement
                      _buildSchoolHero(schoolNom, schoolVille, inviteCode),
                      const SizedBox(height: 16),

                      // 3. Comptes en attente (orange banner)
                      _buildPendingBanner(),

                      // 4. Alertes
                      _buildAlertesSection(),
                      const SizedBox(height: 16),

                      // 5. KPIs effectifs
                      _buildKpiGrid(),
                      const SizedBox(height: 16),

                      // 6. Présences du jour
                      _buildPresenceDuJour(),
                      const SizedBox(height: 16),

                      // 7. Emploi du temps du jour
                      _buildEmploiDuJour(),
                      const SizedBox(height: 16),

                      // 8. Remplacements en attente
                      _buildRemplacementsSection(),
                      const SizedBox(height: 16),

                      // 9. Stats globales
                      _buildStatsSection(),
                      const SizedBox(height: 16),

                      // 10. Raccourcis modules
                      _buildRaccourcisSection(),
                      const SizedBox(height: 16),

                      // 11. Dernières inscriptions
                      _buildDernieresInscriptions(),
                      const SizedBox(height: 16),

                      // 12. Annonces
                      _buildAnnoncesSection(schoolNom),
                    ],
                  ),
                );
              },
            ),
    );
  }

  // ─── AppBar ────────────────────────────────────────────────────────────────

  AppBar _buildAppBar() => AppBar(
        backgroundColor: const Color(0xFF161B22),
        elevation: 0,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tableau de bord',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold)),
            Text('SCOLAR AI Educative · Direction',
                style: TextStyle(color: Colors.white38, fontSize: 11)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined,
                color: Colors.white54, size: 22),
            tooltip: 'Notifications',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                  builder: (_) =>
                      const NotificationsPage(currentUser: '')),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white54, size: 20),
            tooltip: 'Actualiser',
            onPressed: () =>
                setState(() => _statsFuture = _loadStats(_schoolId)),
          ),
        ],
      );

  // ─── Recherche globale ─────────────────────────────────────────────────────

  Widget _buildSearchBar() {
    return Column(
      children: [
        TextField(
          controller: _searchCtrl,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          onChanged: (v) => setState(() => _searchQuery = v.trim()),
          decoration: InputDecoration(
            hintText: 'Rechercher un utilisateur, une classe…',
            hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
            prefixIcon: const Icon(Icons.search, color: Colors.white38, size: 20),
            suffixIcon: _searchQuery.isNotEmpty
                ? GestureDetector(
                    onTap: () {
                      _searchCtrl.clear();
                      setState(() => _searchQuery = '');
                    },
                    child: const Icon(Icons.close,
                        color: Colors.white38, size: 18),
                  )
                : null,
            filled: true,
            fillColor: _card,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _border)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _border)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _purple)),
          ),
        ),
        if (_searchQuery.isNotEmpty) _buildSearchResults(),
      ],
    );
  }

  Widget _buildSearchResults() {
    final q = _searchQuery.toLowerCase();
    return StreamBuilder<QuerySnapshot>(
      stream: _db.collection('users').limit(50).snapshots(),
      builder: (ctx, snap) {
        if (!snap.hasData) {
          return const Padding(
            padding: EdgeInsets.only(top: 8),
            child: LinearProgressIndicator(color: _purple),
          );
        }
        final results = snap.data!.docs
            .where((d) {
              final data = d.data() as Map<String, dynamic>;
              final name =
                  ((data['displayName'] as String?) ?? '').toLowerCase();
              final email =
                  ((data['email'] as String?) ?? '').toLowerCase();
              final classe =
                  ((data['classeNom'] as String?) ?? '').toLowerCase();
              return name.contains(q) ||
                  email.contains(q) ||
                  classe.contains(q);
            })
            .take(6)
            .toList();

        if (results.isEmpty) {
          return Container(
            margin: const EdgeInsets.only(top: 6),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _border),
            ),
            child: const Text('Aucun résultat',
                style: TextStyle(color: Colors.white38, fontSize: 13)),
          );
        }

        return Container(
          margin: const EdgeInsets.only(top: 6),
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _border),
          ),
          child: Column(
            children: results.map((d) {
              final data = d.data() as Map<String, dynamic>;
              final name =
                  (data['displayName'] as String?) ?? 'Utilisateur';
              final role = (data['role'] as String?) ?? '';
              final classe =
                  (data['classeNom'] as String?) ?? '';
              return ListTile(
                dense: true,
                leading: CircleAvatar(
                  radius: 16,
                  backgroundColor: _purple.withValues(alpha: 0.2),
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: const TextStyle(
                        color: _purple,
                        fontSize: 12,
                        fontWeight: FontWeight.bold),
                  ),
                ),
                title: Text(name,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 13)),
                subtitle: Text(
                  [role, classe].where((s) => s.isNotEmpty).join(' · '),
                  style:
                      const TextStyle(color: Colors.white38, fontSize: 11),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  // ─── School hero ───────────────────────────────────────────────────────────

  Widget _buildSchoolHero(String nom, String ville, String code) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _orange.withValues(alpha: 0.3)),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _orange.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.domain, color: _orange, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(nom,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.bold)),
                  if (ville.isNotEmpty)
                    Text(ville,
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 13)),
                ],
              ),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _green.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text('Actif',
                  style: TextStyle(
                      color: _green,
                      fontSize: 11,
                      fontWeight: FontWeight.w700)),
            ),
          ]),
          const SizedBox(height: 16),
          const Divider(color: Color(0xFF30363D)),
          const SizedBox(height: 12),
          const Text("Code d'invitation",
              style: TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: _card2,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _orange.withValues(alpha: 0.4)),
            ),
            child: _codeLoading || code.isEmpty
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                        color: _orange, strokeWidth: 2))
                : Row(children: [
                    Expanded(
                      child: Text(code,
                          style: const TextStyle(
                            color: _orange,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 6,
                          )),
                    ),
                    const SizedBox(width: 8),
                    _iconBtn(Icons.copy_outlined, _orange,
                        () => _copyCode(code),
                        tooltip: 'Copier'),
                    const SizedBox(width: 6),
                    _iconBtn(Icons.share_outlined, _blue,
                        () => _shareCode(code, nom),
                        tooltip: 'Partager'),
                    const SizedBox(width: 6),
                    _iconBtn(Icons.refresh, Colors.white38,
                        _regenerateCode,
                        tooltip: 'Nouveau code'),
                  ]),
          ),
          const SizedBox(height: 8),
          Text(
            'Partagez ce code pour que vos utilisateurs rejoignent cet établissement',
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.35),
                fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _iconBtn(IconData icon, Color color, VoidCallback? onTap,
      {String? tooltip}) {
    return Tooltip(
      message: tooltip ?? '',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Icon(icon, color: color, size: 17),
        ),
      ),
    );
  }

  // ─── Pending banner ────────────────────────────────────────────────────────

  Widget _buildPendingBanner() {
    // Seuls les élèves passent par la validation manuelle (voir
    // DirectionComptesAttentePage) — les enseignants utilisent le système
    // de codes d'invitation et ne sont donc jamais 'en_attente'. On filtre
    // par rôle pour que ce compteur reste cohérent avec la liste réelle.
    return StreamBuilder<QuerySnapshot>(
      stream: _db
          .collection('users')
          .where('statut', isEqualTo: 'en_attente')
          .where('role', isEqualTo: 'eleve')
          .snapshots(),
      builder: (ctx, snap) {
        final count = snap.data?.docs.length ?? 0;
        if (count == 0) return const SizedBox.shrink();
        return GestureDetector(
          onTap: () => Navigator.push(context,
              MaterialPageRoute<void>(
                  builder: (_) => const DirectionComptesAttentePage())),
          child: Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
            decoration: BoxDecoration(
              color: _orange.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
              border:
                  Border.all(color: _orange.withValues(alpha: 0.5)),
            ),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _orange.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.pending_actions,
                    color: _orange, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$count compte${count > 1 ? 's' : ''} en attente de validation',
                      style: const TextStyle(
                          color: _orange,
                          fontWeight: FontWeight.bold,
                          fontSize: 14),
                    ),
                    const Text('Appuyez pour valider ou refuser',
                        style: TextStyle(
                            color: Colors.white54, fontSize: 12)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: _orange, size: 20),
            ]),
          ),
        );
      },
    );
  }

  // ─── Alertes importantes ───────────────────────────────────────────────────

  Widget _buildAlertesSection() {
    return StreamBuilder<QuerySnapshot>(
      stream: _db
          .collection('remplacements')
          .where('statut', isEqualTo: 'enAttente')
          .limit(10)
          .snapshots(),
      builder: (ctx, remSnap) {
        final remCount = remSnap.data?.docs.length ?? 0;
        if (remCount == 0) return const SizedBox.shrink();
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _red.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _red.withValues(alpha: 0.3)),
          ),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _red.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.warning_amber_rounded,
                  color: _red, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Alertes importantes',
                      style: TextStyle(
                          color: _red,
                          fontWeight: FontWeight.bold,
                          fontSize: 13)),
                  if (remCount > 0)
                    Text(
                      '$remCount remplacement${remCount > 1 ? 's' : ''} en attente de traitement',
                      style: const TextStyle(
                          color: Colors.white54, fontSize: 12),
                    ),
                ],
              ),
            ),
            TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                    builder: (_) =>
                        const DirectionHistoriqueRemplacementsPage()),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 6),
                backgroundColor: _red.withValues(alpha: 0.1),
                foregroundColor: _red,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Voir', style: TextStyle(fontSize: 12)),
            ),
          ]),
        );
      },
    );
  }

  // ─── KPI grid ──────────────────────────────────────────────────────────────

  Widget _buildKpiGrid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('Effectifs', Icons.groups_outlined),
        const SizedBox(height: 10),
        LayoutBuilder(builder: (ctx, constraints) {
          final cols = constraints.maxWidth > 500 ? 4 : 2;
          return GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: cols,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: cols == 4 ? 0.95 : 1.2,
            children: [
              _roleKpiCard('eleve', Icons.groups_outlined, 'Élèves',
                  [_blue, _cyan]),
              _roleKpiCard('professeur', Icons.school_outlined,
                  'Enseignants', [const Color(0xFF7C3AED), _purple]),
              _classesKpiCard(),
              _roleKpiCard('parent', Icons.family_restroom_outlined,
                  'Parents',
                  [const Color(0xFFBE185D), const Color(0xFFDB2777)]),
            ],
          );
        }),
      ],
    );
  }

  Widget _roleKpiCard(
      String role, IconData icon, String label, List<Color> colors) {
    return StreamBuilder<int>(
      stream: UserService.usersByRoleStream(role).map((l) => l.length),
      builder: (ctx, snap) {
        final value = snap.hasData ? '${snap.data}' : '…';
        return _KpiCard(
            icon: icon, value: value, label: label, colors: colors);
      },
    );
  }

  Widget _classesKpiCard() {
    return StreamBuilder<QuerySnapshot>(
      stream: _db.collection('classes').snapshots(),
      builder: (ctx, snap) {
        final value =
            snap.hasData ? '${snap.data!.docs.length}' : '…';
        return _KpiCard(
          icon: Icons.class_outlined,
          value: value,
          label: 'Classes',
          colors: const [Color(0xFF15803D), _green],
        );
      },
    );
  }

  // ─── Présences du jour ─────────────────────────────────────────────────────

  Widget _buildPresenceDuJour() {
    // Le champ Firestore 'presences.date' est un Timestamp (voir
    // PresenceRecord.toMap()) — comparer avec une chaîne 'yyyy-MM-dd' ne
    // matchait jamais aucun document et affichait toujours "Aucune présence"
    // même quand des présences existaient pour aujourd'hui.
    final now = DateTime.now();
    final startOfDay = Timestamp.fromDate(DateTime(now.year, now.month, now.day));
    final endOfDay = Timestamp.fromDate(
        DateTime(now.year, now.month, now.day).add(const Duration(days: 1)));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel("Présences aujourd'hui", Icons.how_to_reg_outlined),
        const SizedBox(height: 10),
        StreamBuilder<QuerySnapshot>(
          stream: _db
              .collection('presences')
              .where('date', isGreaterThanOrEqualTo: startOfDay)
              .where('date', isLessThan: endOfDay)
              .limit(200)
              .snapshots(),
          builder: (ctx, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const _MiniLoader();
            }
            final docs = snap.data?.docs ?? [];
            if (docs.isEmpty) {
              return _emptyCard(
                  Icons.how_to_reg_outlined,
                  "Aucune présence enregistrée pour aujourd'hui");
            }
            final present = docs
                .where((d) =>
                    (d.data() as Map)['statut'] == 'present')
                .length;
            final absent = docs
                .where((d) =>
                    (d.data() as Map)['statut'] == 'absent')
                .length;
            final retard = docs
                .where((d) =>
                    (d.data() as Map)['statut'] == 'retard')
                .length;
            final total = docs.length;
            final pct =
                total > 0 ? (present / total * 100).round() : 0;

            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _card,
                borderRadius: BorderRadius.circular(14),
                border:
                    Border.all(color: Colors.white.withValues(alpha: 0.06)),
              ),
              child: Column(children: [
                Row(children: [
                  Expanded(
                      child: _PresenceStatBox(
                          label: 'Présents',
                          value: present,
                          color: _green,
                          icon: Icons.check_circle_outline)),
                  const SizedBox(width: 8),
                  Expanded(
                      child: _PresenceStatBox(
                          label: 'Absents',
                          value: absent,
                          color: _red,
                          icon: Icons.cancel_outlined)),
                  const SizedBox(width: 8),
                  Expanded(
                      child: _PresenceStatBox(
                          label: 'Retards',
                          value: retard,
                          color: _orange,
                          icon: Icons.schedule_outlined)),
                ]),
                const SizedBox(height: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Taux de présence',
                            style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 11)),
                        Text('$pct%',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: total > 0 ? present / total : 0,
                        minHeight: 6,
                        color: _green,
                        backgroundColor: _green.withValues(alpha: 0.12),
                      ),
                    ),
                  ],
                ),
              ]),
            );
          },
        ),
      ],
    );
  }

  // ─── Emploi du temps du jour ───────────────────────────────────────────────

  Widget _buildEmploiDuJour() {
    final jours = [
      '', 'Lundi', 'Mardi', 'Mercredi', 'Jeudi',
      'Vendredi', 'Samedi', 'Dimanche'
    ];
    final jourAuj = DateTime.now().weekday < jours.length
        ? jours[DateTime.now().weekday]
        : '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('Emploi du temps · $jourAuj',
            Icons.calendar_today_outlined),
        const SizedBox(height: 10),
        if (jourAuj.isEmpty || DateTime.now().weekday > 6)
          _emptyCard(Icons.calendar_today_outlined, 'Pas de cours ce jour')
        else
          StreamBuilder<QuerySnapshot>(
            stream: _db
                .collection('emplois_du_temps')
                .where('jour', isEqualTo: jourAuj)
                .limit(20)
                .snapshots(),
            builder: (ctx, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const _MiniLoader();
              }
              final slots = (snap.data?.docs ?? [])
                ..sort((a, b) {
                  final da = (a.data() as Map)['heureDebut'] as String? ?? '';
                  final db = (b.data() as Map)['heureDebut'] as String? ?? '';
                  return da.compareTo(db);
                });

              if (slots.isEmpty) {
                return _emptyCard(Icons.calendar_today_outlined,
                    'Aucun créneau pour $jourAuj');
              }
              return Container(
                decoration: BoxDecoration(
                  color: _card,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: Colors.white.withValues(alpha: 0.06)),
                ),
                child: Column(
                  children: slots.take(8).map((d) {
                    final data = d.data() as Map<String, dynamic>;
                    return _EmploiSlotRow(data: data);
                  }).toList(),
                ),
              );
            },
          ),
      ],
    );
  }

  // ─── Remplacements en attente ──────────────────────────────────────────────

  Widget _buildRemplacementsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Expanded(
              child: _sectionLabel(
                  'Remplacements en attente',
                  Icons.swap_horiz_outlined)),
          TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                  builder: (_) =>
                      const DirectionHistoriqueRemplacementsPage()),
            ),
            style: TextButton.styleFrom(
              foregroundColor: _purple,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            ),
            child: const Text('Tout voir', style: TextStyle(fontSize: 12)),
          ),
        ]),
        const SizedBox(height: 10),
        StreamBuilder<List<Remplacement>>(
          stream: RemplacementService.remplacementsStream(
              statut: RemplacementStatut.enAttente),
          builder: (ctx, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const _MiniLoader();
            }
            final list = snap.data ?? [];
            if (list.isEmpty) {
              return _emptyCard(
                  Icons.check_circle_outline,
                  'Aucun remplacement en attente',
                  color: _green);
            }
            return Column(
              children: list
                  .take(4)
                  .map((r) => _RemplacementTile(remplacement: r))
                  .toList(),
            );
          },
        ),
      ],
    );
  }

  // ─── Stats globales ────────────────────────────────────────────────────────

  Widget _buildStatsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('Statistiques globales', Icons.bar_chart),
        const SizedBox(height: 10),
        FutureBuilder<_Stats>(
          future: _statsFuture,
          builder: (ctx, snap) {
            final stats = snap.data;
            final loading =
                snap.connectionState == ConnectionState.waiting;
            return Column(children: [
              Row(children: [
                Expanded(
                  child: _StatBar(
                    icon: Icons.how_to_reg_outlined,
                    label: 'Présence globale (7j)',
                    value: loading ? null : stats?.presenceRate,
                    unit: '%',
                    color: _green,
                    maxValue: 100,
                    loading: loading,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _StatBar(
                    icon: Icons.how_to_reg_outlined,
                    label: 'Inscriptions validées',
                    value: loading
                        ? null
                        : stats?.inscriptionsValidees?.toDouble(),
                    unit: '',
                    color: _blue,
                    maxValue: 500,
                    loading: loading,
                    showRaw: true,
                  ),
                ),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                  child: _StatBar(
                    icon: Icons.assignment_outlined,
                    label: 'Devoirs publiés',
                    value: loading
                        ? null
                        : stats?.devoirsActifs?.toDouble(),
                    unit: '',
                    color: _purple,
                    maxValue: 300,
                    loading: loading,
                    showRaw: true,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _StatBar(
                    icon: Icons.cancel_outlined,
                    label: 'Absences (7j)',
                    value: loading
                        ? null
                        : stats?.totalAbsences?.toDouble(),
                    unit: '',
                    color: _red,
                    maxValue: 100,
                    loading: loading,
                    showRaw: true,
                  ),
                ),
              ]),
            ]);
          },
        ),
      ],
    );
  }

  // ─── Raccourcis modules ────────────────────────────────────────────────────

  Widget _buildRaccourcisSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('Accès rapide', Icons.grid_view_outlined),
        const SizedBox(height: 10),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 4,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 0.85,
          children: [
            _ShortcutCard(
              icon: Icons.groups_outlined,
              label: 'Élèves',
              color: _blue,
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                      builder: (_) => const DirectionElevesPage())),
            ),
            _ShortcutCard(
              icon: Icons.class_outlined,
              label: 'Classes',
              color: _cyan,
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                      builder: (_) => const DirectionClassesPage())),
            ),
            _ShortcutCard(
              icon: Icons.pending_actions,
              label: 'Comptes',
              color: _orange,
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                      builder: (_) =>
                          const DirectionComptesAttentePage())),
            ),
            _ShortcutCard(
              icon: Icons.bar_chart,
              label: 'Stats',
              color: _purple,
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                      builder: (_) =>
                          const DirectionStatistiquesPage())),
            ),
            _ShortcutCard(
              icon: Icons.swap_horiz_outlined,
              label: 'Remplace-\nments',
              color: const Color(0xFF7C3AED),
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                      builder: (_) =>
                          const DirectionHistoriqueRemplacementsPage())),
            ),
            _ShortcutCard(
              icon: Icons.event_available_outlined,
              label: 'Dispos',
              color: _green,
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                      builder: (_) =>
                          const DirectionDisponibilitesPage())),
            ),
            _ShortcutCard(
              icon: Icons.campaign_outlined,
              label: 'Annonces',
              color: const Color(0xFFDB2777),
              onTap: () => _showCreateAnnonce(''),
            ),
            _ShortcutCard(
              icon: Icons.notifications_outlined,
              label: 'Notifs',
              color: Colors.white54,
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                      builder: (_) =>
                          const NotificationsPage(currentUser: ''))),
            ),
          ],
        ),
      ],
    );
  }

  // ─── Dernières inscriptions ────────────────────────────────────────────────

  Widget _buildDernieresInscriptions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('Dernières inscriptions', Icons.person_add_outlined),
        const SizedBox(height: 10),
        StreamBuilder<QuerySnapshot>(
          stream: _db
              .collection('users')
              .orderBy('createdAt', descending: true)
              .limit(5)
              .snapshots(),
          builder: (ctx, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const _MiniLoader();
            }
            final docs = snap.data?.docs ?? [];
            if (docs.isEmpty) {
              return _emptyCard(
                  Icons.person_outline, 'Aucune inscription récente');
            }
            return Container(
              decoration: BoxDecoration(
                color: _card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.06)),
              ),
              child: Column(
                children: docs.map((d) {
                  final user = UserModel.fromDoc(d);
                  return _InscriptionTile(user: user);
                }).toList(),
              ),
            );
          },
        ),
      ],
    );
  }

  // ─── Annonces ──────────────────────────────────────────────────────────────

  Widget _buildAnnoncesSection(String schoolNom) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Expanded(
              child:
                  _sectionLabel('Annonces récentes', Icons.campaign_outlined)),
          TextButton.icon(
            onPressed: () => _showCreateAnnonce(schoolNom),
            icon: const Icon(Icons.add, size: 16, color: _purple),
            label: const Text('Nouvelle',
                style: TextStyle(color: _purple, fontSize: 13)),
            style: TextButton.styleFrom(
              backgroundColor: _purple.withValues(alpha: 0.1),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            ),
          ),
        ]),
        const SizedBox(height: 10),
        StreamBuilder<QuerySnapshot>(
          stream: _db
              .collection('annonces')
              .where('schoolId', isEqualTo: _schoolId)
              .orderBy('date', descending: true)
              .limit(5)
              .snapshots(),
          builder: (ctx, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: CircularProgressIndicator(
                      color: _purple, strokeWidth: 2),
                ),
              );
            }
            final docs = snap.data?.docs ?? [];
            if (docs.isEmpty) {
              return _emptyCard(Icons.campaign_outlined,
                  'Aucune annonce — appuyez sur "Nouvelle"');
            }
            return Column(
              children: docs
                  .map((d) => _AnnonceCard(
                      data: d.data() as Map<String, dynamic>,
                      id: d.id,
                      db: _db))
                  .toList(),
            );
          },
        ),
      ],
    );
  }

  // ─── Shared helpers ────────────────────────────────────────────────────────

  Widget _sectionLabel(String text, IconData icon) => Padding(
        padding: const EdgeInsets.only(bottom: 2),
        child: Row(children: [
          Icon(icon, color: _purple, size: 16),
          const SizedBox(width: 7),
          Text(text,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700)),
        ]),
      );

  Widget _emptyCard(IconData icon, String msg, {Color? color}) =>
      Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(12),
          border:
              Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Row(children: [
          Icon(icon, color: color ?? Colors.white24, size: 24),
          const SizedBox(width: 12),
          Flexible(
            child: Text(msg,
                style:
                    const TextStyle(color: Colors.white38, fontSize: 13)),
          ),
        ]),
      );
}

// ─── KPI Card ─────────────────────────────────────────────────────────────────

class _KpiCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final List<Color> colors;

  const _KpiCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors[0].withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: colors[0].withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: colors[0], size: 16),
          ),
          const SizedBox(height: 8),
          Text(value,
              style: TextStyle(
                  color: colors[0],
                  fontSize: 22,
                  fontWeight: FontWeight.bold)),
          Text(label,
              style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 11,
                  fontWeight: FontWeight.w500),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

// ─── Stat Bar ─────────────────────────────────────────────────────────────────

class _StatBar extends StatelessWidget {
  final IconData icon;
  final String label;
  final double? value;
  final String unit;
  final Color color;
  final double maxValue;
  final bool loading;
  final bool showRaw;

  const _StatBar({
    required this.icon,
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
    required this.maxValue,
    required this.loading,
    this.showRaw = false,
  });

  @override
  Widget build(BuildContext context) {
    final displayVal = value != null
        ? showRaw
            ? value!.toInt().toString()
            : value!.toStringAsFixed(1)
        : '—';
    final progress =
        value != null ? (value! / maxValue).clamp(0.0, 1.0) : 0.0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 6),
            Expanded(
              child: Text(label,
                  style: const TextStyle(
                      color: Colors.white54, fontSize: 11),
                  overflow: TextOverflow.ellipsis),
            ),
          ]),
          const SizedBox(height: 10),
          loading
              ? SizedBox(
                  height: 22,
                  child: LinearProgressIndicator(
                    color: color,
                    backgroundColor: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(displayVal,
                            style: TextStyle(
                                color: color,
                                fontSize: 22,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(width: 3),
                        if (unit.isNotEmpty)
                          Text(unit,
                              style: TextStyle(
                                  color: color.withValues(alpha: 0.7),
                                  fontSize: 12)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 4,
                        color: color,
                        backgroundColor: color.withValues(alpha: 0.12),
                      ),
                    ),
                  ],
                ),
        ],
      ),
    );
  }
}

// ─── Annonce Card ─────────────────────────────────────────────────────────────

class _AnnonceCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final String id;
  final FirebaseFirestore db;

  const _AnnonceCard(
      {required this.data, required this.id, required this.db});

  Color _typeColor(String t) {
    switch (t) {
      case 'urgence':
        return const Color(0xFFEF4444);
      case 'info':
        return const Color(0xFF2563EB);
      default:
        return const Color(0xFF6C47FF);
    }
  }

  IconData _typeIcon(String t) {
    switch (t) {
      case 'urgence':
        return Icons.warning_amber_outlined;
      case 'info':
        return Icons.info_outline;
      default:
        return Icons.campaign_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final titre  = data['titre']   as String? ?? '';
    final contenu = data['contenu'] as String? ?? '';
    final type   = data['type']    as String? ?? 'annonce';
    final date   = data['date'] is Timestamp
        ? (data['date'] as Timestamp).toDate()
        : DateTime.now();
    final auteur = data['auteurNom'] as String? ?? '';
    final color  = _typeColor(type);
    final fmt    = DateFormat('d MMM yyyy', 'fr_FR');

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(_typeIcon(type), color: color, size: 11),
              const SizedBox(width: 4),
              Text(
                type[0].toUpperCase() + type.substring(1),
                style: TextStyle(
                    color: color,
                    fontSize: 10,
                    fontWeight: FontWeight.w700),
              ),
            ]),
          ),
          const Spacer(),
          Text(fmt.format(date),
              style:
                  const TextStyle(color: Colors.white38, fontSize: 11)),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () =>
                db.collection('annonces').doc(id).delete(),
            child:
                const Icon(Icons.close, color: Colors.white24, size: 16),
          ),
        ]),
        const SizedBox(height: 8),
        Text(titre,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(contenu,
            style:
                const TextStyle(color: Colors.white60, fontSize: 12),
            maxLines: 3,
            overflow: TextOverflow.ellipsis),
        if (auteur.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text('— $auteur',
              style:
                  const TextStyle(color: Colors.white38, fontSize: 11)),
        ],
      ]),
    );
  }
}

// ─── Présence stat box ────────────────────────────────────────────────────────

class _PresenceStatBox extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  final IconData icon;

  const _PresenceStatBox({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(height: 4),
        Text('$value',
            style: TextStyle(
                color: color,
                fontSize: 20,
                fontWeight: FontWeight.bold)),
        Text(label,
            style: const TextStyle(color: Colors.white38, fontSize: 9),
            textAlign: TextAlign.center),
      ]),
    );
  }
}

// ─── Emploi slot row ──────────────────────────────────────────────────────────

class _EmploiSlotRow extends StatelessWidget {
  final Map<String, dynamic> data;
  const _EmploiSlotRow({required this.data});

  @override
  Widget build(BuildContext context) {
    final matiere = data['matiere'] as String? ?? '—';
    final debut   = data['heureDebut'] as String? ?? '';
    final fin     = data['heureFin']   as String? ?? '';
    final salle   = data['salle']      as String? ?? '';
    final classe  = data['classeNom']  as String? ?? '';

    final now  = DateTime.now();
    final dH   = int.tryParse(debut.split(':').firstOrNull ?? '') ?? -1;
    final dM   = int.tryParse(debut.split(':').lastOrNull ?? '') ?? 0;
    final fH   = int.tryParse(fin.split(':').firstOrNull ?? '') ?? -1;
    final fM   = int.tryParse(fin.split(':').lastOrNull ?? '') ?? 0;
    final dDt  = dH >= 0
        ? DateTime(now.year, now.month, now.day, dH, dM)
        : null;
    final fDt  = fH >= 0
        ? DateTime(now.year, now.month, now.day, fH, fM)
        : null;
    final isNow = dDt != null &&
        fDt != null &&
        now.isAfter(dDt) &&
        now.isBefore(fDt);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        border: const Border(
            bottom: BorderSide(color: Color(0xFF30363D), width: 0.5)),
        color: isNow
            ? const Color(0xFF2563EB).withValues(alpha: 0.06)
            : Colors.transparent,
      ),
      child: Row(children: [
        SizedBox(
          width: 86,
          child: Text(
            '$debut – $fin',
            style: TextStyle(
                color: isNow
                    ? const Color(0xFF2563EB)
                    : Colors.white38,
                fontSize: 11,
                fontWeight:
                    isNow ? FontWeight.w600 : FontWeight.normal),
          ),
        ),
        if (isNow)
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.only(right: 6),
            decoration: const BoxDecoration(
                color: Color(0xFF2563EB), shape: BoxShape.circle),
          ),
        Expanded(
          child: Text(matiere,
              style: TextStyle(
                  color:
                      isNow ? Colors.white : Colors.white70,
                  fontSize: 13,
                  fontWeight: isNow
                      ? FontWeight.w600
                      : FontWeight.normal)),
        ),
        if (classe.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text(classe,
                style: const TextStyle(
                    color: Colors.white38, fontSize: 10)),
          ),
        if (salle.isNotEmpty) ...[
          const SizedBox(width: 6),
          Text('Salle $salle',
              style: const TextStyle(
                  color: Colors.white24, fontSize: 10)),
        ],
      ]),
    );
  }
}

// ─── Remplacement tile ────────────────────────────────────────────────────────

class _RemplacementTile extends StatelessWidget {
  final Remplacement remplacement;
  const _RemplacementTile({required this.remplacement});

  @override
  Widget build(BuildContext context) {
    final r     = remplacement;
    final color = r.statutColor;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(Icons.swap_horiz_outlined, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(r.professeurAbsentNom,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              Text(
                '${r.classeNom} · ${r.date} ${r.heureDebut}',
                style: const TextStyle(
                    color: Colors.white38, fontSize: 11),
              ),
            ],
          ),
        ),
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(r.statutLabel,
              style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: FontWeight.bold)),
        ),
      ]),
    );
  }
}

// ─── Inscription tile ─────────────────────────────────────────────────────────

class _InscriptionTile extends StatelessWidget {
  final UserModel user;
  const _InscriptionTile({required this.user});

  static const _roleColors = {
    'eleve':      Color(0xFF2563EB),
    'professeur': Color(0xFF7C3AED),
    'parent':     Color(0xFFDB2777),
    'direction':  Color(0xFFF59E0B),
    'admin':      Color(0xFFF59E0B),
  };

  static const _roleIcons = {
    'eleve':      Icons.school_outlined,
    'professeur': Icons.school,
    'parent':     Icons.family_restroom_outlined,
    'direction':  Icons.admin_panel_settings_outlined,
    'admin':      Icons.admin_panel_settings_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final roleKey = user.role.value;
    final color   = _roleColors[roleKey] ?? Colors.white38;
    final icon    = _roleIcons[roleKey]  ?? Icons.person_outline;
    final createdAt = user.createdAt?.toDate();
    final timeStr = createdAt != null
        ? DateFormat('dd/MM/yyyy · HH:mm').format(createdAt)
        : '';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: const BoxDecoration(
        border: Border(
            bottom: BorderSide(color: Color(0xFF30363D), width: 0.5)),
      ),
      child: Row(children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: color.withValues(alpha: 0.15),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(user.displayName,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                      fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(user.role.label,
                      style: TextStyle(
                          color: color,
                          fontSize: 9,
                          fontWeight: FontWeight.w600)),
                ),
                if ((user.classeNom ?? '').isNotEmpty) ...[
                  const SizedBox(width: 4),
                  Text(user.classeNom!,
                      style: const TextStyle(
                          color: Colors.white38, fontSize: 10)),
                ],
              ]),
            ],
          ),
        ),
        if (timeStr.isNotEmpty)
          Text(timeStr,
              style: const TextStyle(
                  color: Colors.white24, fontSize: 10)),
      ]),
    );
  }
}

// ─── Shortcut card ────────────────────────────────────────────────────────────

class _ShortcutCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ShortcutCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 6),
            Text(label,
                style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 10,
                    fontWeight: FontWeight.w500),
                textAlign: TextAlign.center,
                maxLines: 2),
          ],
        ),
      ),
    );
  }
}

// ─── Mini loader ──────────────────────────────────────────────────────────────

class _MiniLoader extends StatelessWidget {
  const _MiniLoader();

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: CircularProgressIndicator(
              color: Color(0xFF6C47FF), strokeWidth: 2),
        ),
      );
}
