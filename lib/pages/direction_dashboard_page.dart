import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../models/school_model.dart';
import '../services/user_service.dart';
import 'direction_comptes_attente_page.dart';

// ─── Data class pour stats ────────────────────────────────────────────────────

class _Stats {
  final double? presenceRate;
  final double? moyenneGenerale;
  const _Stats({this.presenceRate, this.moyenneGenerale});
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
  static const _bg = Color(0xFF0D1117);
  static const _card = Color(0xFF161B22);
  static const _card2 = Color(0xFF1F2937);
  static const _border = Color(0xFF30363D);
  static const _orange = Color(0xFFF59E0B);
  static const _blue = Color(0xFF2563EB);
  static const _purple = Color(0xFF6C47FF);
  static const _green = Color(0xFF16A34A);

  String _schoolId = '';
  Future<_Stats>? _statsFuture;
  bool _codeLoading = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

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
    final existing =
        (snap.data()?['codeInvitation'] as String?)?.trim() ?? '';
    if (existing.isNotEmpty) return;
    final code = _generateCode();
    await _db
        .collection('schools')
        .doc(schoolId)
        .set({'codeInvitation': code}, SetOptions(merge: true));
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
    // Presence rate — last 7 days
    final since = Timestamp.fromDate(
        DateTime.now().subtract(const Duration(days: 7)));
    double? presenceRate;
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
      }
    } catch (_) {}

    // Average notes
    double? moyenneGenerale;
    try {
      final notesSnap =
          await _db.collection('notes').limit(300).get();
      final values = notesSnap.docs
          .map((d) => (d.data()['valeur'] as num?)?.toDouble())
          .whereType<double>()
          .where((v) => v > 0 && v <= 20)
          .toList();
      if (values.isNotEmpty) {
        moyenneGenerale =
            values.reduce((a, b) => a + b) / values.length;
      }
    } catch (_) {}

    return _Stats(
        presenceRate: presenceRate,
        moyenneGenerale: moyenneGenerale);
  }

  void _copyCode(String code) {
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Code copié dans le presse-papiers'),
        backgroundColor: _green,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _shareCode(String code, String schoolNom) {
    Clipboard.setData(ClipboardData(
        text:
            'Rejoignez $schoolNom sur SCOLAR AI avec le code : $code'));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content:
            const Text('Message copié — partagez-le à vos utilisateurs'),
        backgroundColor: _blue,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showCreateAnnonce(String schoolNom) {
    final titreCtrl = TextEditingController();
    final contenuCtrl = TextEditingController();
    String type = 'annonce';
    final types = [
      ('Annonce', 'annonce', Icons.campaign_outlined),
      ('Urgence', 'urgence', Icons.warning_amber_outlined),
      ('Info', 'info', Icons.info_outline),
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          backgroundColor: _card,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          title: const Text(
            'Nouvelle annonce',
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // type chips
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
                                color:
                                    sel ? Colors.white : Colors.white54,
                                fontSize: 12)),
                        backgroundColor:
                            sel ? _purple : _card2,
                        side: BorderSide(
                            color: sel ? _purple : _border),
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
                  decoration: _inputDeco('Contenu de l\'annonce'),
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
                final titre = titreCtrl.text.trim();
                final contenu = contenuCtrl.text.trim();
                if (titre.isEmpty || contenu.isEmpty) return;
                final uid =
                    FirebaseAuth.instance.currentUser?.uid ?? '';
                final user =
                    await UserService.currentUserStream().first;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        elevation: 0,
        title: const Text(
          'Tableau de bord',
          style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white54, size: 20),
            tooltip: 'Actualiser',
            onPressed: () => setState(
                () => _statsFuture = _loadStats(_schoolId)),
          ),
        ],
      ),
      body: _schoolId.isEmpty
          ? const Center(
              child: CircularProgressIndicator(color: _purple))
          : StreamBuilder<DocumentSnapshot>(
              stream: _db.collection('schools').doc(_schoolId).snapshots(),
              builder: (context, schoolSnap) {
                final schoolData =
                    schoolSnap.data?.data() as Map<String, dynamic>?;
                final schoolNom =
                    schoolData?['nom'] as String? ?? 'Mon établissement';
                final schoolVille =
                    schoolData?['ville'] as String? ?? '';
                final inviteCode =
                    schoolData?['codeInvitation'] as String? ?? '';

                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                  children: [
                    _buildSchoolHero(
                        schoolNom, schoolVille, inviteCode),
                    const SizedBox(height: 20),
                    _buildPendingBanner(),
                    const SizedBox(height: 20),
                    _buildKpiGrid(),
                    const SizedBox(height: 20),
                    _buildStatsSection(),
                    const SizedBox(height: 20),
                    _buildAnnoncesSection(schoolNom),
                  ],
                );
              },
            ),
    );
  }

  // ─── School hero card ──────────────────────────────────────────────────────

  Widget _buildSchoolHero(
      String nom, String ville, String code) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
            color: _orange.withValues(alpha: 0.3)),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _orange.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.domain,
                    color: _orange, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nom,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (ville.isNotEmpty)
                      Text(
                        ville,
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 13),
                      ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _green.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Actif',
                  style: TextStyle(
                      color: _green,
                      fontSize: 11,
                      fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: Color(0xFF30363D)),
          const SizedBox(height: 12),
          const Text(
            'Code d\'invitation',
            style: TextStyle(
                color: Colors.white54,
                fontSize: 12,
                fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: _card2,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _orange.withValues(alpha: 0.4)),
                  ),
                  child: _codeLoading || code.isEmpty
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                              color: _orange, strokeWidth: 2))
                      : Row(
                          children: [
                            Text(
                              code,
                              style: const TextStyle(
                                color: _orange,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 6,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              'SCOLAR AI',
                              style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  fontSize: 10,
                                  letterSpacing: 1),
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(width: 8),
              _iconBtn(
                Icons.copy_outlined,
                _orange,
                () => code.isNotEmpty ? _copyCode(code) : null,
                tooltip: 'Copier',
              ),
              const SizedBox(width: 6),
              _iconBtn(
                Icons.share_outlined,
                _blue,
                () => code.isNotEmpty ? _shareCode(code, nom) : null,
                tooltip: 'Partager',
              ),
              const SizedBox(width: 6),
              _iconBtn(
                Icons.refresh,
                Colors.white38,
                _regenerateCode,
                tooltip: 'Nouveau code',
              ),
            ],
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

  // ─── Pending accounts banner ───────────────────────────────────────────────

  Widget _buildPendingBanner() {
    return StreamBuilder<QuerySnapshot>(
      stream: _db
          .collection('users')
          .where('statut', isEqualTo: 'en_attente')
          .snapshots(),
      builder: (context, snap) {
        final count = snap.data?.docs.length ?? 0;
        if (count == 0) return const SizedBox.shrink();
        return GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => const DirectionComptesAttentePage(),
            ),
          ),
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
            decoration: BoxDecoration(
              color: _orange.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _orange.withValues(alpha: 0.5)),
            ),
            child: Row(
              children: [
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
                          fontSize: 14,
                        ),
                      ),
                      const Text(
                        'Appuyez pour valider ou refuser',
                        style: TextStyle(
                            color: Colors.white54, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right,
                    color: _orange, size: 20),
              ],
            ),
          ),
        );
      },
    );
  }

  // ─── KPI grid ──────────────────────────────────────────────────────────────

  Widget _buildKpiGrid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('Effectifs'),
        const SizedBox(height: 10),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.5,
          children: [
            _roleKpiCard('eleve', Icons.groups_outlined, 'Élèves',
                [const Color(0xFF2563EB), const Color(0xFF0891B2)]),
            _roleKpiCard(
                'professeur',
                Icons.school_outlined,
                'Enseignants',
                [const Color(0xFF7C3AED), const Color(0xFF6C47FF)]),
            _classesKpiCard(),
            _roleKpiCard('parent', Icons.family_restroom_outlined,
                'Parents',
                [const Color(0xFFBE185D), const Color(0xFFDB2777)]),
          ],
        ),
      ],
    );
  }

  Widget _roleKpiCard(String role, IconData icon, String label,
      List<Color> colors) {
    return StreamBuilder<int>(
      stream: UserService.usersByRoleStream(role)
          .map((list) => list.length),
      builder: (context, snap) {
        final value = snap.hasData ? '${snap.data}' : '…';
        return _KpiCard(
            icon: icon, value: value, label: label, colors: colors);
      },
    );
  }

  Widget _classesKpiCard() {
    return StreamBuilder<QuerySnapshot>(
      stream: _db.collection('classes').snapshots(),
      builder: (context, snap) {
        final value =
            snap.hasData ? '${snap.data!.docs.length}' : '…';
        return _KpiCard(
          icon: Icons.class_outlined,
          value: value,
          label: 'Classes',
          colors: const [Color(0xFF15803D), Color(0xFF16A34A)],
        );
      },
    );
  }

  // ─── Stats globales ────────────────────────────────────────────────────────

  Widget _buildStatsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('Statistiques globales'),
        const SizedBox(height: 10),
        FutureBuilder<_Stats>(
          future: _statsFuture,
          builder: (context, snap) {
            final stats = snap.data;
            final loading =
                snap.connectionState == ConnectionState.waiting;

            return Row(
              children: [
                Expanded(
                  child: _StatBar(
                    icon: Icons.how_to_reg_outlined,
                    label: 'Présence (7j)',
                    value: loading
                        ? null
                        : stats?.presenceRate,
                    unit: '%',
                    color: _green,
                    maxValue: 100,
                    loading: loading,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _StatBar(
                    icon: Icons.bar_chart,
                    label: 'Moyenne générale',
                    value: loading
                        ? null
                        : stats?.moyenneGenerale,
                    unit: '/20',
                    color: _blue,
                    maxValue: 20,
                    loading: loading,
                  ),
                ),
              ],
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
        Row(
          children: [
            Expanded(child: _sectionLabel('Annonces récentes')),
            TextButton.icon(
              onPressed: () => _showCreateAnnonce(schoolNom),
              icon: const Icon(Icons.add, size: 16, color: _purple),
              label: const Text('Nouvelle',
                  style: TextStyle(color: _purple, fontSize: 13)),
              style: TextButton.styleFrom(
                backgroundColor: _purple.withValues(alpha: 0.1),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        StreamBuilder<QuerySnapshot>(
          stream: _db
              .collection('annonces')
              .where('schoolId', isEqualTo: _schoolId)
              .orderBy('date', descending: true)
              .limit(5)
              .snapshots(),
          builder: (context, snap) {
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
              return Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: _card,
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.05)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.campaign_outlined,
                        color: Colors.white24, size: 28),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Aucune annonce publiée',
                          style: TextStyle(
                              color: Colors.white54, fontSize: 13),
                        ),
                        Text(
                          'Appuyez sur "Nouvelle" pour communiquer',
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.25),
                              fontSize: 11),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }
            return Column(
              children: docs.map((d) {
                final data = d.data() as Map<String, dynamic>;
                return _AnnonceCard(data: data, id: d.id, db: _db);
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  // ─── Helpers ───────────────────────────────────────────────────────────────

  Widget _sectionLabel(String text) => Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
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
        border: Border.all(
            color: colors[0].withValues(alpha: 0.25)),
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
          Text(
            value,
            style: TextStyle(
              color: colors[0],
              fontSize: 26,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
                color: Colors.white54,
                fontSize: 12,
                fontWeight: FontWeight.w500),
          ),
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

  const _StatBar({
    required this.icon,
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
    required this.maxValue,
    required this.loading,
  });

  @override
  Widget build(BuildContext context) {
    final displayVal = value != null
        ? value!.toStringAsFixed(1)
        : '—';
    final progress =
        value != null ? (value! / maxValue).clamp(0.0, 1.0) : 0.0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(14),
        border:
            Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                      color: Colors.white54, fontSize: 11),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
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
                        Text(
                          displayVal,
                          style: TextStyle(
                            color: color,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 3),
                        Text(
                          unit,
                          style: TextStyle(
                              color: color.withValues(alpha: 0.7),
                              fontSize: 12),
                        ),
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
    final titre = data['titre'] as String? ?? '';
    final contenu = data['contenu'] as String? ?? '';
    final type = data['type'] as String? ?? 'annonce';
    final date = data['date'] is Timestamp
        ? (data['date'] as Timestamp).toDate()
        : DateTime.now();
    final auteur = data['auteurNom'] as String? ?? '';
    final color = _typeColor(type);
    final fmt = DateFormat('d MMM yyyy', 'fr_FR');

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_typeIcon(type), color: color, size: 11),
                    const SizedBox(width: 4),
                    Text(
                      type[0].toUpperCase() + type.substring(1),
                      style: TextStyle(
                          color: color,
                          fontSize: 10,
                          fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Text(
                fmt.format(date),
                style: const TextStyle(
                    color: Colors.white38, fontSize: 11),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => db.collection('annonces').doc(id).delete(),
                child: const Icon(Icons.close,
                    color: Colors.white24, size: 16),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            titre,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            contenu,
            style: const TextStyle(
                color: Colors.white60, fontSize: 12),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          if (auteur.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              '— $auteur',
              style: const TextStyle(
                  color: Colors.white38, fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }
}
