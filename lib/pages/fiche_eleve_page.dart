import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/classe_model.dart';
import '../models/user_model.dart';
import '../services/maitrise_service.dart';
import '../services/professeur_service.dart';

// ─── Helpers ──────────────────────────────────────────────────────────────────

List<Color> _nameGrad(String name) {
  const palettes = <List<Color>>[
    [Color(0xFF2563EB), Color(0xFF0891B2)],
    [Color(0xFF7C3AED), Color(0xFF6C47FF)],
    [Color(0xFF15803D), Color(0xFF16A34A)],
    [Color(0xFFDC2626), Color(0xFFEA580C)],
    [Color(0xFF0F766E), Color(0xFF0891B2)],
    [Color(0xFFD97706), Color(0xFFCA8A04)],
    [Color(0xFF374151), Color(0xFF4B5563)],
    [Color(0xFF9333EA), Color(0xFF7C3AED)],
  ];
  if (name.isEmpty) return palettes[0];
  final idx = name.codeUnits.fold(0, (a, b) => a + b) % palettes.length;
  return palettes[idx];
}

Color _cycleColor(String cat) {
  return switch (cat.toLowerCase()) {
    'maternelle'  => const Color(0xFFF59E0B),
    'primaire'    => const Color(0xFF10B981),
    'collège'     => const Color(0xFF3B82F6),
    'lycée'       => const Color(0xFF8B5CF6),
    'université'  => const Color(0xFFEF4444),
    _             => const Color(0xFF6B7280),
  };
}

// ═══════════════════════════════════════════════════════════════════════════════
// Page fiche élève
// ═══════════════════════════════════════════════════════════════════════════════

class FicheElevePage extends StatefulWidget {
  final Map<String, dynamic> eleve;
  final UserModel? userIA;
  final ClasseModel? classe;

  const FicheElevePage({
    super.key,
    required this.eleve,
    this.userIA,
    this.classe,
  });

  @override
  State<FicheElevePage> createState() => _FicheElevePageState();
}

class _FicheElevePageState extends State<FicheElevePage> {
  List<Map<String, dynamic>> _parents = [];
  Map<String, dynamic>? _eleveDoc;
  bool _loadingExtra = true;

  @override
  void initState() {
    super.initState();
    _loadExtra();
  }

  Future<void> _loadExtra() async {
    try {
      final uid = _uid;
      if (uid.isEmpty) { if (mounted) setState(() => _loadingExtra = false); return; }

      final parentFuture = FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'parent')
          .where('enfantIds', arrayContains: uid)
          .get();
      final eleveFuture = FirebaseFirestore.instance
          .collection('eleves')
          .where('authUid', isEqualTo: uid)
          .limit(1)
          .get();

      final results = await Future.wait([parentFuture, eleveFuture]);
      if (!mounted) return;
      final parentSnap = results[0];
      final eleveSnap  = results[1];
      setState(() {
        _parents = parentSnap.docs
            .map((d) => <String, dynamic>{'id': d.id, ...d.data()})
            .toList();
        if (eleveSnap.docs.isNotEmpty) _eleveDoc = eleveSnap.docs.first.data();
        _loadingExtra = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingExtra = false);
    }
  }

  // ── Getters ──────────────────────────────────────────────────────────────────

  Map<String, dynamic> get _e => widget.eleve;

  String get _uid =>
      _e['authUid'] as String? ?? _e['uid'] as String? ?? widget.userIA?.uid ?? '';

  String get _prenom =>
      _e['prenom'] as String? ?? _eleveDoc?['prenom'] as String? ?? '';

  String get _nom =>
      _e['nom'] as String? ?? _eleveDoc?['nom'] as String? ?? '';

  String get _fullName {
    final n = '$_prenom $_nom'.trim();
    if (n.isNotEmpty) return n;
    return _e['displayName'] as String? ?? widget.userIA?.displayName ?? 'Élève';
  }

  String get _email =>
      _e['email'] as String? ?? _eleveDoc?['email'] as String? ?? widget.userIA?.email ?? '';

  String get _classeNom =>
      _e['classeNom'] as String? ?? _e['classe'] as String?
      ?? widget.userIA?.classeNom ?? widget.classe?.nom ?? '';

  String get _categorie =>
      _e['categorie'] as String? ?? widget.userIA?.categorie ?? '';

  String get _niveau =>
      _e['niveau'] as String? ?? widget.userIA?.niveau ?? '';

  String get _matricule =>
      _e['matricule'] as String? ?? _eleveDoc?['matricule'] as String? ?? '';

  String? get _photoUrl =>
      _e['photoUrl'] as String? ?? widget.userIA?.photoUrl;

  String get _telephone =>
      _e['telephone'] as String? ?? _eleveDoc?['telephone'] as String? ?? '';

  String get _adresse =>
      _e['adresse'] as String? ?? _eleveDoc?['adresse'] as String? ?? '';

  String get _sexe =>
      _e['sexe'] as String? ?? _eleveDoc?['sexe'] as String? ?? '';

  String _fmtDate(dynamic ts) {
    if (ts == null) return '';
    try {
      final dt = ts is DateTime ? ts : (ts as dynamic).toDate() as DateTime;
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    } catch (_) { return ''; }
  }

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final grad       = _nameGrad(_fullName);
    final cycleColor = _cycleColor(_categorie);

    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: const Color(0xFF0D1117),
            expandedHeight: 230,
            pinned: true,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.more_vert, color: Colors.white),
                onPressed: () => _showOptions(context),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.pin,
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [grad.first.withValues(alpha: 0.45), const Color(0xFF0D1117)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: SafeArea(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 28),
                      // Avatar
                      Container(
                        width: 78, height: 78,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: grad),
                          shape: BoxShape.circle,
                          boxShadow: [BoxShadow(
                            color: grad.first.withValues(alpha: 0.45),
                            blurRadius: 20, spreadRadius: 2,
                          )],
                        ),
                        child: _photoUrl != null && _photoUrl!.isNotEmpty
                            ? ClipOval(child: Image.network(_photoUrl!, fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => _initials()))
                            : _initials(),
                      ),
                      const SizedBox(height: 10),
                      Text(_fullName,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      Wrap(alignment: WrapAlignment.center, spacing: 6, children: [
                        if (_categorie.isNotEmpty)
                          _PillBadge(label: _categorie, bg: cycleColor.withValues(alpha: 0.2),
                              fg: cycleColor),
                        if (_classeNom.isNotEmpty)
                          _PillBadge(label: _classeNom,
                              bg: Colors.white.withValues(alpha: 0.1), fg: Colors.white70),
                        if (_niveau.isNotEmpty)
                          _PillBadge(label: _niveau,
                              bg: Colors.white.withValues(alpha: 0.06), fg: Colors.white38),
                      ]),
                    ],
                  ),
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 48),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildInfosPersonnelles(),
                  const SizedBox(height: 12),
                  _buildInfosScolaires(),
                  const SizedBox(height: 12),
                  _buildFamille(),
                  if (widget.userIA != null) ...[
                    const SizedBox(height: 12),
                    _buildSuiviIA(),
                  ],
                  const SizedBox(height: 12),
                  _buildActions(context),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _initials() => Center(
    child: Text(
      _fullName.isNotEmpty ? _fullName[0].toUpperCase() : '?',
      style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
    ),
  );

  // ── Sections ──────────────────────────────────────────────────────────────────

  Widget _buildInfosPersonnelles() {
    final dateStr = _fmtDate(_e['dateNaissance'] ?? _eleveDoc?['dateNaissance']);
    return _SectionCard(
      title: 'INFORMATIONS PERSONNELLES',
      icon: Icons.person_outline,
      children: [
        if (_matricule.isNotEmpty)
          _InfoTile(icon: Icons.numbers_outlined, label: 'Matricule', value: _matricule, copyable: true),
        if (_sexe.isNotEmpty)
          _InfoTile(icon: Icons.wc_outlined, label: 'Sexe', value: _sexe),
        if (dateStr.isNotEmpty)
          _InfoTile(icon: Icons.cake_outlined, label: 'Date de naissance', value: dateStr),
        if (_email.isNotEmpty)
          _InfoTile(icon: Icons.email_outlined, label: 'Email', value: _email, copyable: true),
        if (_telephone.isNotEmpty)
          _InfoTile(icon: Icons.phone_outlined, label: 'Téléphone', value: _telephone, copyable: true),
        if (_adresse.isNotEmpty)
          _InfoTile(icon: Icons.location_on_outlined, label: 'Adresse', value: _adresse),
        if (_matricule.isEmpty && _sexe.isEmpty && dateStr.isEmpty &&
            _email.isEmpty && _telephone.isEmpty && _adresse.isEmpty)
          _InfoTile(icon: Icons.info_outline, label: '', value: 'Données non renseignées',
              valueColor: Colors.white38),
      ],
    );
  }

  Widget _buildInfosScolaires() {
    return _SectionCard(
      title: 'INFORMATIONS SCOLAIRES',
      icon: Icons.school_outlined,
      children: [
        if (_categorie.isNotEmpty)
          _InfoTile(icon: Icons.layers_outlined, label: 'Cycle', value: _categorie),
        if (_niveau.isNotEmpty)
          _InfoTile(icon: Icons.class_outlined, label: 'Niveau', value: _niveau),
        if (_classeNom.isNotEmpty)
          _InfoTile(icon: Icons.groups_outlined, label: 'Classe', value: _classeNom),
        if (widget.classe != null)
          _InfoTile(icon: Icons.calendar_today_outlined, label: 'Année scolaire',
              value: '${widget.classe!.anneeScol}–${widget.classe!.anneeScol + 1}'),
        _InfoTile(
          icon: _uid.isNotEmpty ? Icons.check_circle_outline : Icons.pending_outlined,
          label: 'Statut',
          value: _uid.isNotEmpty ? 'Actif' : 'Inscription en attente',
          valueColor: _uid.isNotEmpty ? const Color(0xFF16A34A) : const Color(0xFFD97706),
        ),
      ],
    );
  }

  Widget _buildFamille() {
    final p1      = _e['parent1']          as String? ?? _eleveDoc?['parent1']          as String? ?? '';
    final p2      = _e['parent2']          as String? ?? _eleveDoc?['parent2']          as String? ?? '';
    final telPar  = _e['telephoneParent']  as String? ?? _eleveDoc?['telephoneParent']  as String? ?? '';
    final emailPar= _e['emailParent']      as String? ?? _eleveDoc?['emailParent']      as String? ?? '';

    return _SectionCard(
      title: 'FAMILLE',
      icon: Icons.family_restroom_outlined,
      children: [
        if (_loadingExtra)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF7C3AED))),
          )
        else ...[
          ..._parents.expand((p) {
            final pName  = p['displayName'] as String? ?? '';
            final pEmail = p['email']       as String? ?? '';
            return [
              _InfoTile(icon: Icons.person_outline, label: 'Parent', value: pName.isNotEmpty ? pName : 'Parent'),
              if (pEmail.isNotEmpty)
                _InfoTile(icon: Icons.email_outlined, label: 'Email', value: pEmail, copyable: true),
            ];
          }),
          if (p1.isNotEmpty)      _InfoTile(icon: Icons.person_outline, label: 'Parent 1', value: p1),
          if (p2.isNotEmpty)      _InfoTile(icon: Icons.person_outline, label: 'Parent 2', value: p2),
          if (telPar.isNotEmpty)  _InfoTile(icon: Icons.phone_outlined, label: 'Tél. parent', value: telPar, copyable: true),
          if (emailPar.isNotEmpty)_InfoTile(icon: Icons.email_outlined, label: 'Email parent', value: emailPar, copyable: true),
          if (_parents.isEmpty && p1.isEmpty && p2.isEmpty && telPar.isEmpty && emailPar.isEmpty)
            _InfoTile(icon: Icons.info_outline, label: '', value: 'Aucun parent enregistré',
                valueColor: Colors.white38),
        ],
      ],
    );
  }

  Widget _buildSuiviIA() {
    return _SectionCard(
      title: 'SUIVI IA',
      icon: Icons.auto_awesome_outlined,
      children: [_FicheSuiviIA(uid: widget.userIA!.uid)],
    );
  }

  Widget _buildActions(BuildContext context) {
    return _SectionCard(
      title: 'ACTIONS',
      icon: Icons.bolt_outlined,
      children: [
        Row(children: [
          Expanded(
            child: _ActionButton(
              icon: Icons.edit_outlined,
              label: 'Modifier',
              color: const Color(0xFF2563EB),
              onTap: () => _showEditSheet(context),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _ActionButton(
              icon: Icons.person_remove_outlined,
              label: 'Retirer',
              color: const Color(0xFFDC2626),
              onTap: () => _confirmDelete(context),
            ),
          ),
        ]),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 1.15,
          children: [
            _ActionTile(icon: Icons.grade_outlined,       label: 'Notes',      color: const Color(0xFF0F766E),
                onTap: () => _navBack(context, 'Notes')),
            _ActionTile(icon: Icons.how_to_reg_outlined,  label: 'Absences',   color: const Color(0xFFD97706),
                onTap: () => _navBack(context, 'Présences')),
            _ActionTile(icon: Icons.assignment_outlined,  label: 'Devoirs',    color: const Color(0xFF6C47FF),
                onTap: () => _navBack(context, 'Devoirs')),
            _ActionTile(icon: Icons.folder_outlined,      label: 'Documents',  color: const Color(0xFF0891B2),
                onTap: () => _navBack(context, 'Documents')),
            _ActionTile(icon: Icons.event_note_outlined,  label: 'Rendez-vous',color: const Color(0xFF7C3AED),
                onTap: () => _navBack(context, 'Rendez-vous')),
            _ActionTile(icon: Icons.contact_phone_outlined,label: 'Contacter', color: const Color(0xFF15803D),
                onTap: () => _contactParents(context)),
          ],
        ),
      ],
    );
  }

  // ── Handlers ─────────────────────────────────────────────────────────────────

  void _navBack(BuildContext context, String module) {
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Consultez l\'onglet $module.'),
      backgroundColor: const Color(0xFF1C2128),
      behavior: SnackBarBehavior.floating,
    ));
  }

  void _contactParents(BuildContext context) {
    final p1      = _e['parent1']         as String? ?? _eleveDoc?['parent1']         as String? ?? '';
    final p2      = _e['parent2']         as String? ?? _eleveDoc?['parent2']         as String? ?? '';
    final tel     = _e['telephoneParent'] as String? ?? _eleveDoc?['telephoneParent'] as String? ?? '';
    final email   = _e['emailParent']     as String? ?? _eleveDoc?['emailParent']     as String? ?? '';

    if (_parents.isEmpty && p1.isEmpty && p2.isEmpty && tel.isEmpty && email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Aucune information de contact parent disponible.'),
        backgroundColor: Color(0xFF1C2128), behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF161B22),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _ContactSheet(parents: _parents, p1: p1, p2: p2, tel: tel, emailPar: email),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF161B22),
        title: const Text('Retirer de la classe', style: TextStyle(color: Colors.white)),
        content: Text('Retirer $_fullName de la classe $_classeNom ?',
            style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler', style: TextStyle(color: Colors.white38))),
          TextButton(onPressed: () => Navigator.pop(context, true),
              child: const Text('Retirer', style: TextStyle(color: Color(0xFFDC2626)))),
        ],
      ),
    );
    if (ok == true && widget.classe != null && _uid.isNotEmpty) {
      await ProfesseurService.removeEleveFromClasse(widget.classe!.id, _uid);
      if (!context.mounted) return;
      Navigator.pop(context);
    }
  }

  void _showEditSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF161B22),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _EditEleveSheet(
        fullName: _fullName,
        uid: _uid,
        currentClasse: widget.classe,
      ),
    );
  }

  void _showOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF161B22),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 40, height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
          ListTile(
            leading: const Icon(Icons.edit_outlined, color: Colors.white70),
            title: const Text('Modifier', style: TextStyle(color: Colors.white)),
            onTap: () { Navigator.pop(ctx); _showEditSheet(context); },
          ),
          ListTile(
            leading: const Icon(Icons.person_remove_outlined, color: Color(0xFFDC2626)),
            title: const Text('Retirer de la classe', style: TextStyle(color: Color(0xFFDC2626))),
            onTap: () { Navigator.pop(ctx); _confirmDelete(context); },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ─── Pill Badge ───────────────────────────────────────────────────────────────

class _PillBadge extends StatelessWidget {
  final String label;
  final Color bg, fg;
  const _PillBadge({required this.label, required this.bg, required this.fg});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
    child: Text(label, style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w600)),
  );
}

// ─── Section Card ─────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;
  const _SectionCard({required this.title, required this.icon, required this.children});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFF161B22),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(icon, color: Colors.white38, size: 14),
        const SizedBox(width: 6),
        Text(title, style: const TextStyle(
            color: Colors.white38, fontSize: 10,
            fontWeight: FontWeight.w700, letterSpacing: 1.2)),
      ]),
      const SizedBox(height: 12),
      ...children,
    ]),
  );
}

// ─── Info Tile ────────────────────────────────────────────────────────────────

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final Color? valueColor;
  final bool copyable;
  const _InfoTile({
    required this.icon, required this.label, required this.value,
    this.valueColor, this.copyable = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white24, size: 16),
          const SizedBox(width: 10),
          if (label.isNotEmpty) ...[
            SizedBox(
              width: 110,
              child: Text(label, style: const TextStyle(color: Colors.white38, fontSize: 12)),
            ),
          ],
          Expanded(
            child: GestureDetector(
              onTap: copyable ? () {
                Clipboard.setData(ClipboardData(text: value));
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('$label copié'),
                  backgroundColor: const Color(0xFF1C2128),
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 1),
                ));
              } : null,
              child: Row(children: [
                Expanded(
                  child: Text(value,
                      style: TextStyle(
                          color: valueColor ?? Colors.white, fontSize: 13, height: 1.4)),
                ),
                if (copyable)
                  const Icon(Icons.copy_outlined, color: Colors.white24, size: 14),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Suivi IA ─────────────────────────────────────────────────────────────────

class _FicheSuiviIA extends StatelessWidget {
  final String uid;
  const _FicheSuiviIA({required this.uid});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: MaitriseService.summaryForUser(uid),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF7C3AED))),
          );
        }
        final summary = snap.data ?? {};
        if (summary.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Row(children: [
              Icon(Icons.school_outlined, color: Colors.white24, size: 16),
              SizedBox(width: 10),
              Expanded(child: Text('Aucun suivi disponible — l\'élève n\'a pas encore révisé.',
                  style: TextStyle(color: Colors.white38, fontSize: 12))),
            ]),
          );
        }
        final totaux     = (summary['totaux']     as Map<String, dynamic>?) ?? {};
        final parMatiere = (summary['parMatiere'] as Map<String, dynamic>?) ?? {};
        final total    = (totaux['total']         as int?) ?? 0;
        final maitrise = (totaux['maitrise']      as int?) ?? 0;
        final enCours  = (totaux['enCours']       as int?) ?? 0;
        final aRetrav  = (totaux['aRetravailler'] as int?) ?? 0;
        final pct      = (totaux['pct']           as int?) ?? 0;

        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Global bar
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1E3A5F), Color(0xFF1B2E4A)],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
            ),
            child: Row(children: [
              Stack(alignment: Alignment.center, children: [
                SizedBox(width: 48, height: 48,
                  child: CircularProgressIndicator(
                    value: pct / 100,
                    backgroundColor: Colors.white12,
                    color: pct >= 75 ? const Color(0xFF16A34A) : const Color(0xFF2563EB),
                    strokeWidth: 4,
                  ),
                ),
                Text('$pct%', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
              ]),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('$total notion${total > 1 ? "s" : ""} suivie${total > 1 ? "s" : ""}',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 4),
                Wrap(spacing: 8, children: [
                  _MiniChip('🟢 $maitrise', 'Maîtrisées'),
                  _MiniChip('🟡 $enCours', 'En cours'),
                  _MiniChip('🔴 $aRetrav', 'À retravailler'),
                ]),
              ])),
            ]),
          ),
          const SizedBox(height: 8),
          // Per subject
          ...parMatiere.entries.map((entry) {
            final m  = entry.key;
            final d  = entry.value as Map<String, dynamic>? ?? {};
            final mA = (d['aRetravailler'] as int?) ?? 0;
            final mC = (d['enCours']       as int?) ?? 0;
            final mM = (d['maitrise']      as int?) ?? 0;
            final al = (d['alertes']       as List?) ?? [];
            if (mA == 0 && mC == 0 && mM == 0) return const SizedBox.shrink();
            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF0D1117),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(m, style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13))),
                  Text('🟢$mM 🟡$mC 🔴$mA',
                      style: const TextStyle(color: Colors.white54, fontSize: 12)),
                ]),
                if (al.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  ...al.take(2).map((a) => Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Row(children: [
                      const Icon(Icons.warning_amber_outlined, color: Color(0xFFDC2626), size: 11),
                      const SizedBox(width: 4),
                      Expanded(child: Text(a.toString(),
                          style: const TextStyle(color: Color(0xFFDC2626), fontSize: 10, height: 1.3))),
                    ]),
                  )),
                ],
              ]),
            );
          }),
        ]);
      },
    );
  }
}

class _MiniChip extends StatelessWidget {
  final String label, sub;
  const _MiniChip(this.label, this.sub);
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
    Text(label, style: const TextStyle(color: Colors.white, fontSize: 10)),
    const SizedBox(width: 2),
    Text(sub, style: const TextStyle(color: Colors.white38, fontSize: 9)),
  ]);
}

// ─── Action widgets ───────────────────────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionButton({required this.icon, required this.label, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) => ElevatedButton.icon(
    style: ElevatedButton.styleFrom(
      backgroundColor: color.withValues(alpha: 0.15),
      foregroundColor: color,
      side: BorderSide(color: color.withValues(alpha: 0.3)),
      padding: const EdgeInsets.symmetric(vertical: 12),
    ),
    onPressed: onTap,
    icon: Icon(icon, size: 16),
    label: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
  );
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionTile({required this.icon, required this.label, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600),
            textAlign: TextAlign.center, maxLines: 2),
      ]),
    ),
  );
}

// ─── Contact Sheet ────────────────────────────────────────────────────────────

class _ContactSheet extends StatelessWidget {
  final List<Map<String, dynamic>> parents;
  final String p1, p2, tel, emailPar;
  const _ContactSheet({
    required this.parents, required this.p1, required this.p2,
    required this.tel, required this.emailPar,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 40, height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
        const Text('Contacter les parents',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        ...[
          ...parents.map((p) => _contactRow(context,
              p['displayName'] as String? ?? 'Parent',
              p['email'] as String? ?? '')),
          if (p1.isNotEmpty) _contactRow(context, p1, ''),
          if (p2.isNotEmpty) _contactRow(context, p2, ''),
          if (tel.isNotEmpty) _copyRow(context, Icons.phone_outlined, 'Téléphone', tel),
          if (emailPar.isNotEmpty) _copyRow(context, Icons.email_outlined, 'Email', emailPar),
        ],
      ]),
    );
  }

  Widget _contactRow(BuildContext context, String name, String email) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF0D1117),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Row(children: [
            const Icon(Icons.person_outline, color: Colors.white38, size: 18),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
              if (email.isNotEmpty)
                Text(email, style: const TextStyle(color: Colors.white38, fontSize: 11)),
            ])),
            if (email.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.copy_outlined, color: Colors.white38, size: 16),
                onPressed: () => Clipboard.setData(ClipboardData(text: email)),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
          ]),
        ),
      );

  Widget _copyRow(BuildContext context, IconData icon, String label, String value) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF0D1117),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Row(children: [
            Icon(icon, color: Colors.white38, size: 16),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: const TextStyle(color: Colors.white38, fontSize: 11)),
              Text(value, style: const TextStyle(color: Colors.white, fontSize: 13)),
            ])),
            IconButton(
              icon: const Icon(Icons.copy_outlined, color: Colors.white38, size: 16),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: value));
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('$label copié'),
                  backgroundColor: const Color(0xFF1C2128),
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 1),
                ));
              },
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ]),
        ),
      );
}

// ─── Edit élève sheet ─────────────────────────────────────────────────────────

class _EditEleveSheet extends StatefulWidget {
  final String fullName, uid;
  final ClasseModel? currentClasse;
  const _EditEleveSheet({required this.fullName, required this.uid, this.currentClasse});
  @override
  State<_EditEleveSheet> createState() => _EditEleveSheetState();
}

class _EditEleveSheetState extends State<_EditEleveSheet> {
  ClasseModel? _targetClasse;
  bool _saving = false;

  Future<void> _save() async {
    final target = _targetClasse;
    if (target == null || widget.uid.isEmpty) return;
    setState(() => _saving = true);
    try {
      if (widget.currentClasse != null && widget.currentClasse!.id != target.id) {
        await ProfesseurService.removeEleveFromClasse(widget.currentClasse!.id, widget.uid);
      }
      await ProfesseurService.addEleveToClasse(target.id, widget.uid);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Classe mise à jour.'),
          backgroundColor: Color(0xFF1C2128),
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        left: 20, right: 20, top: 20,
      ),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Modifier — ${widget.fullName}',
            style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        const Text('Changer de classe', style: TextStyle(color: Colors.white38, fontSize: 12)),
        const SizedBox(height: 16),
        StreamBuilder<List<ClasseModel>>(
          stream: ProfesseurService.classesStream(),
          builder: (context, snap) {
            final classes = snap.data ?? [];
            return Wrap(spacing: 8, runSpacing: 8, children: classes.map((c) {
              final sel = _targetClasse?.id == c.id;
              return GestureDetector(
                onTap: () => setState(() => _targetClasse = c),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: sel ? const LinearGradient(
                        colors: [Color(0xFF7C3AED), Color(0xFF6C47FF)]) : null,
                    color: sel ? null : const Color(0xFF0D1117),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: sel ? Colors.transparent : Colors.white.withValues(alpha: 0.12)),
                  ),
                  child: Text(c.nom,
                      style: TextStyle(
                          color: sel ? Colors.white : Colors.white54,
                          fontWeight: sel ? FontWeight.w600 : FontWeight.normal,
                          fontSize: 13)),
                ),
              );
            }).toList());
          },
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7C3AED),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              disabledBackgroundColor: const Color(0xFF7C3AED).withValues(alpha: 0.3),
            ),
            onPressed: (_saving || _targetClasse == null) ? null : _save,
            child: _saving
                ? const SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Enregistrer', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
      ]),
    );
  }
}
