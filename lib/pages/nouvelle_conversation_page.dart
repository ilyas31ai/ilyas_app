import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/user_model.dart';
import '../services/messagerie_service.dart';

// ─── Palette ──────────────────────────────────────────────────────────────────

const _kBg     = Color(0xFF0D1117);
const _kCard   = Color(0xFF161B22);
const _kCard2  = Color(0xFF1F2937);
const _kBorder = Color(0xFF30363D);
const _kBlue   = Color(0xFF2563EB);
const _kPurple = Color(0xFF6C47FF);
const _kGreen  = Color(0xFF16A34A);

// ─── Page ─────────────────────────────────────────────────────────────────────

class NouvelleConversationPage extends StatefulWidget {
  final UserModel me;
  const NouvelleConversationPage({super.key, required this.me});

  @override
  State<NouvelleConversationPage> createState() =>
      _NouvelleConversationPageState();
}

class _NouvelleConversationPageState
    extends State<NouvelleConversationPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tc;
  final _searchCtrl = TextEditingController();
  final _groupNameCtrl = TextEditingController();
  String _query = '';
  final Set<String> _selectedIds = {};
  final Map<String, UserModel> _selectedUsers = {};
  bool _creating = false;

  /// UIDs autorisés pour le rôle courant (professeurs pour un élève, élèves
  /// pour un professeur). `null` = pas de restriction pour ce rôle.
  Set<String>? _allowedIds;
  bool _loadingAllowed = true;

  @override
  void initState() {
    super.initState();
    _tc = TabController(length: 2, vsync: this);
    _loadAllowed();
  }

  /// Restreint la messagerie Élève ↔ Professeur, Parent ↔ Direction et
  /// Direction ↔ Professeur : un élève ne doit voir que ses professeurs, un
  /// professeur que les élèves et la Direction de son établissement, un
  /// parent que la Direction de son établissement, et la Direction que les
  /// parents et professeurs de son établissement.
  Future<void> _loadAllowed() async {
    Set<String>? ids;
    if (widget.me.role == UserRole.eleve) {
      ids = await MessagerieService.profsAutorisesPourEleve(widget.me);
    } else if (widget.me.role == UserRole.professeur) {
      final eleves = await MessagerieService.elevesAutorisesPourProf(widget.me);
      final directions =
          await MessagerieService.directionsAutoriseesPourProfesseur(widget.me);
      ids = {...eleves, ...directions};
    } else if (widget.me.role == UserRole.parent) {
      ids = await MessagerieService.directionsAutoriseesPourParent(widget.me);
    } else if (widget.me.role == UserRole.admin ||
        widget.me.role == UserRole.direction) {
      final parents = await MessagerieService.parentsAutorisesPourDirection(widget.me);
      final profs =
          await MessagerieService.professeursAutorisesPourDirection(widget.me);
      ids = {...parents, ...profs};
    }
    if (mounted) {
      setState(() {
        _allowedIds = ids;
        _loadingAllowed = false;
      });
    }
  }

  /// Applique la restriction de rôle sur une liste de contacts déjà chargée.
  List<UserModel> _applyRoleFilter(List<UserModel> users) {
    if (widget.me.role == UserRole.eleve) {
      final allowed = _allowedIds ?? const <String>{};
      return users
          .where((u) => u.role == UserRole.professeur && allowed.contains(u.uid))
          .toList();
    }
    if (widget.me.role == UserRole.professeur) {
      final allowed = _allowedIds ?? const <String>{};
      return users.where((u) {
        if (u.role == UserRole.eleve) return allowed.contains(u.uid);
        if (u.role == UserRole.admin || u.role == UserRole.direction) {
          return allowed.contains(u.uid);
        }
        return true;
      }).toList();
    }
    if (widget.me.role == UserRole.parent) {
      final allowed = _allowedIds ?? const <String>{};
      return users
          .where((u) =>
              (u.role == UserRole.admin || u.role == UserRole.direction) &&
              allowed.contains(u.uid))
          .toList();
    }
    if (widget.me.role == UserRole.admin ||
        widget.me.role == UserRole.direction) {
      final allowed = _allowedIds ?? const <String>{};
      return users.where((u) {
        if (u.role == UserRole.parent) return allowed.contains(u.uid);
        if (u.role == UserRole.professeur) return allowed.contains(u.uid);
        return true;
      }).toList();
    }
    return users;
  }

  @override
  void dispose() {
    _tc.dispose();
    _searchCtrl.dispose();
    _groupNameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kCard,
        elevation: 0,
        title: const Text('Nouvelle conversation',
            style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tc,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white38,
          indicatorColor: _kPurple,
          labelStyle:
              const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
          tabs: const [
            Tab(text: 'Direct'),
            Tab(text: 'Groupe'),
          ],
        ),
      ),
      body: Column(children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
          child: TextField(
            controller: _searchCtrl,
            onChanged: (v) => setState(() => _query = v),
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Rechercher par nom…',
              hintStyle:
                  const TextStyle(color: Colors.white24, fontSize: 13),
              prefixIcon:
                  const Icon(Icons.search, color: Colors.white38, size: 20),
              filled: true,
              fillColor: _kCard2,
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        // Selected chips (group mode)
        if (_tc.index == 1 && _selectedIds.isNotEmpty)
          _SelectedChips(
            selected: _selectedUsers.values.toList(),
            onRemove: (u) => setState(() {
              _selectedIds.remove(u.uid);
              _selectedUsers.remove(u.uid);
            }),
          ),
        // Content
        Expanded(
          child: TabBarView(
            controller: _tc,
            children: [
              _DirectList(
                me: widget.me,
                query: _query,
                loadingAllowed: _loadingAllowed,
                roleFilter: _applyRoleFilter,
                onSelect: (u) => _createDirect(u),
              ),
              _GroupBuilder(
                me: widget.me,
                query: _query,
                loadingAllowed: _loadingAllowed,
                roleFilter: _applyRoleFilter,
                selectedIds: _selectedIds,
                groupNameCtrl: _groupNameCtrl,
                onToggle: (u) {
                  setState(() {
                    if (_selectedIds.contains(u.uid)) {
                      _selectedIds.remove(u.uid);
                      _selectedUsers.remove(u.uid);
                    } else {
                      _selectedIds.add(u.uid);
                      _selectedUsers[u.uid] = u;
                    }
                  });
                },
              ),
            ],
          ),
        ),
      ]),
      // Bouton créer groupe
      bottomNavigationBar: AnimatedBuilder(
        animation: _tc,
        builder: (_, __) {
          if (_tc.index != 1) return const SizedBox.shrink();
          return Padding(
            padding: EdgeInsets.fromLTRB(
                12, 8, 12, MediaQuery.of(context).viewInsets.bottom + 12),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: (_selectedIds.isEmpty || _creating)
                    ? null
                    : _createGroup,
                icon: _creating
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.group_add_outlined, size: 18),
                label: Text(_creating
                    ? 'Création…'
                    : 'Créer le groupe (${_selectedIds.length + 1} membres)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      _selectedIds.isEmpty ? _kCard2 : _kPurple,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: _kCard2,
                  disabledForegroundColor: Colors.white24,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  textStyle: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _createDirect(UserModel other) async {
    setState(() => _creating = true);
    try {
      final id = await MessagerieService.getOrCreateDirect(
          me: widget.me, other: other);
      if (mounted) Navigator.pop(context, id);
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  Future<void> _createGroup() async {
    final name = _groupNameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Donnez un nom au groupe'),
          backgroundColor: const Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }
    setState(() => _creating = true);
    try {
      final participants =
          _selectedUsers.values.toList();
      final id = await MessagerieService.createGroup(
        creator: widget.me,
        name: name,
        participants: participants,
      );
      if (mounted) Navigator.pop(context, id);
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }
}

// ─── Chips sélectionnés ───────────────────────────────────────────────────────

class _SelectedChips extends StatelessWidget {
  final List<UserModel> selected;
  final ValueChanged<UserModel> onRemove;
  const _SelectedChips({required this.selected, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      color: _kCard,
      child: Wrap(
        spacing: 6,
        runSpacing: 4,
        children: selected.map((u) {
          return Chip(
            label: Text(u.displayName,
                style: const TextStyle(
                    color: Colors.white, fontSize: 11)),
            deleteIcon: const Icon(Icons.close,
                size: 14, color: Colors.white54),
            onDeleted: () => onRemove(u),
            backgroundColor: _kPurple.withValues(alpha: 0.2),
            side: BorderSide(
                color: _kPurple.withValues(alpha: 0.4)),
            materialTapTargetSize:
                MaterialTapTargetSize.shrinkWrap,
            padding:
                const EdgeInsets.symmetric(horizontal: 4),
          );
        }).toList(),
      ),
    );
  }
}

// ─── Tab Direct ───────────────────────────────────────────────────────────────

class _DirectList extends StatelessWidget {
  final UserModel me;
  final String query;
  final bool loadingAllowed;
  final List<UserModel> Function(List<UserModel>) roleFilter;
  final ValueChanged<UserModel> onSelect;

  const _DirectList(
      {required this.me,
      required this.query,
      required this.loadingAllowed,
      required this.roleFilter,
      required this.onSelect});

  @override
  Widget build(BuildContext context) {
    if (loadingAllowed) {
      return const Center(
          child: CircularProgressIndicator(color: _kPurple));
    }
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .orderBy('displayName')
          .snapshots(),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: _kPurple));
        }
        if (snap.hasError) {
          return Center(
            child: Text('Erreur de chargement',
                style: const TextStyle(color: Colors.white38)),
          );
        }
        // whereNotIn Firestore exclude les docs sans champ 'statut' → filtre Dart
        var users = (snap.data?.docs ?? [])
            .map(UserModel.fromDoc)
            .where((u) => u.uid != me.uid)
            .where((u) => u.statut != 'en_attente')
            .toList();
        users = roleFilter(users);
        users = users.where((u) {
          if (query.isEmpty) return true;
          return u.displayName
              .toLowerCase()
              .contains(query.toLowerCase());
        }).toList();

        if (users.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                me.role == UserRole.eleve
                    ? 'Aucun professeur disponible.\nContactez la Direction si votre classe n\'est pas encore assignée.'
                    : me.role == UserRole.professeur
                        ? 'Aucun contact disponible.\nSeuls vos élèves et la Direction de votre établissement apparaissent ici.'
                        : me.role == UserRole.parent
                            ? 'Aucune Direction disponible pour votre établissement.'
                            : (me.role == UserRole.admin ||
                                    me.role == UserRole.direction)
                                ? 'Aucun contact disponible.\nParents et professeurs de votre établissement apparaissent ici.'
                                : 'Aucun utilisateur trouvé',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white38),
              ),
            ),
          );
        }

        return ListView.separated(
          itemCount: users.length,
          separatorBuilder: (_, __) =>
              const Divider(height: 1, color: _kBorder, indent: 64),
          itemBuilder: (_, i) => _UserTile(
              user: users[i],
              onTap: () => onSelect(users[i]),
              trailing: const Icon(Icons.chevron_right,
                  color: Colors.white24, size: 18)),
        );
      },
    );
  }
}

// ─── Tab Groupe ───────────────────────────────────────────────────────────────

class _GroupBuilder extends StatelessWidget {
  final UserModel me;
  final String query;
  final bool loadingAllowed;
  final List<UserModel> Function(List<UserModel>) roleFilter;
  final Set<String> selectedIds;
  final TextEditingController groupNameCtrl;
  final ValueChanged<UserModel> onToggle;

  const _GroupBuilder({
    required this.me,
    required this.query,
    required this.loadingAllowed,
    required this.roleFilter,
    required this.selectedIds,
    required this.groupNameCtrl,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    if (loadingAllowed) {
      return const Center(
          child: CircularProgressIndicator(color: _kPurple));
    }
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .orderBy('displayName')
          .snapshots(),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: _kPurple));
        }
        if (snap.hasError) {
          return Center(
            child: Text('Erreur de chargement',
                style: const TextStyle(color: Colors.white38)),
          );
        }
        // whereNotIn Firestore exclude les docs sans champ 'statut' → filtre Dart
        var users = (snap.data?.docs ?? [])
            .map(UserModel.fromDoc)
            .where((u) => u.uid != me.uid)
            .where((u) => u.statut != 'en_attente')
            .toList();
        users = roleFilter(users);
        users = users.where((u) {
          if (query.isEmpty) return true;
          return u.displayName
              .toLowerCase()
              .contains(query.toLowerCase());
        }).toList();

        return ListView(
          padding:
              const EdgeInsets.fromLTRB(12, 8, 12, 100),
          children: [
            // Nom du groupe
            TextField(
              controller: groupNameCtrl,
              style: const TextStyle(
                  color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Nom du groupe…',
                hintStyle: const TextStyle(
                    color: Colors.white24, fontSize: 13),
                prefixIcon: const Icon(Icons.group_outlined,
                    color: Colors.white38, size: 20),
                filled: true,
                fillColor: _kCard,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide:
                      BorderSide(color: _kPurple.withValues(alpha: 0.3)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide:
                      BorderSide(color: _kBorder.withValues(alpha: 0.6)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide:
                      BorderSide(color: _kPurple.withValues(alpha: 0.6)),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Quick groups
            _QuickGroupsSection(me: me, onToggle: onToggle, selectedIds: selectedIds),
            const SizedBox(height: 4),
            const Text('MEMBRES',
                style: TextStyle(
                    color: Colors.white38,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1)),
            const SizedBox(height: 8),
            ...users.map((u) => _UserTile(
                  user: u,
                  selected: selectedIds.contains(u.uid),
                  onTap: () => onToggle(u),
                  trailing: Checkbox(
                    value: selectedIds.contains(u.uid),
                    onChanged: (_) => onToggle(u),
                    activeColor: _kPurple,
                    side: BorderSide(color: Colors.white38),
                  ),
                )),
          ],
        );
      },
    );
  }
}

// ─── Quick groups (raccourcis) ────────────────────────────────────────────────

class _QuickGroupsSection extends StatelessWidget {
  final UserModel me;
  final Set<String> selectedIds;
  final ValueChanged<UserModel> onToggle;
  const _QuickGroupsSection(
      {required this.me,
      required this.selectedIds,
      required this.onToggle});

  @override
  Widget build(BuildContext context) {
    if (me.role != UserRole.professeur &&
        me.role != UserRole.admin &&
        me.role != UserRole.direction) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('GROUPES RAPIDES',
            style: TextStyle(
                color: Colors.white38,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.1)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 6, children: [
          if (me.role == UserRole.professeur)
            _QuickChip(
              label: 'Mes élèves',
              icon: Icons.school_outlined,
              color: _kBlue,
              onTap: () => _selectByRole(context, 'eleve',
                  classeNom: me.classeNom),
            ),
          if (me.role == UserRole.professeur)
            _QuickChip(
              label: 'Parents de ma classe',
              icon: Icons.family_restroom_outlined,
              color: _kGreen,
              onTap: () =>
                  _selectParents(context, classeNom: me.classeNom),
            ),
          if (me.role == UserRole.admin || me.role == UserRole.direction)
            _QuickChip(
              label: 'Tous les profs',
              icon: Icons.person_outline,
              color: _kPurple,
              onTap: () =>
                  _selectByRole(context, 'professeur', schoolId: me.schoolId),
            ),
        ]),
        const SizedBox(height: 12),
      ],
    );
  }

  Future<void> _selectByRole(BuildContext context, String role,
      {String? classeNom, String? schoolId}) async {
    Query<Map<String, dynamic>> q = FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: role);
    if (classeNom != null && classeNom.isNotEmpty) {
      q = q.where('classeNom', isEqualTo: classeNom);
    }
    final snap = await q.get();
    for (final doc in snap.docs) {
      final u = UserModel.fromDoc(doc);
      if (u.uid == me.uid || selectedIds.contains(u.uid)) continue;
      // Filtrage schoolId côté client : voir note dans MessagerieService sur
      // le backfill Phase 2 non effectué pour tous les comptes existants.
      if (schoolId != null && u.schoolId != schoolId) continue;
      onToggle(u);
    }
  }

  Future<void> _selectParents(BuildContext context,
      {String? classeNom}) async {
    if (classeNom == null || classeNom.isEmpty) return;
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'parent')
        .get();
    for (final doc in snap.docs) {
      final u = UserModel.fromDoc(doc);
      if (u.uid != me.uid && !selectedIds.contains(u.uid)) {
        onToggle(u);
      }
    }
  }
}

class _QuickChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _QuickChip(
      {required this.label,
      required this.icon,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }
}

// ─── Tuile utilisateur ────────────────────────────────────────────────────────

class _UserTile extends StatelessWidget {
  final UserModel user;
  final VoidCallback onTap;
  final Widget trailing;
  final bool selected;

  const _UserTile({
    required this.user,
    required this.onTap,
    required this.trailing,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    final roleLabel = _roleLabel(user.role);
    return InkWell(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? _kPurple.withValues(alpha: 0.08)
              : Colors.transparent,
        ),
        child: Row(children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: _kPurple.withValues(alpha: 0.15),
            child: Text(
              user.displayName.isNotEmpty
                  ? user.displayName[0].toUpperCase()
                  : '?',
              style: const TextStyle(
                  color: _kPurple,
                  fontWeight: FontWeight.bold,
                  fontSize: 14),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user.displayName,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                Row(children: [
                  Container(
                    margin: const EdgeInsets.only(top: 2),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: _roleColor(user.role)
                          .withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(roleLabel,
                        style: TextStyle(
                            color: _roleColor(user.role),
                            fontSize: 10,
                            fontWeight: FontWeight.w600)),
                  ),
                  if (user.classeNom?.isNotEmpty == true) ...[
                    const SizedBox(width: 6),
                    Text(user.classeNom!,
                        style: const TextStyle(
                            color: Colors.white38, fontSize: 10)),
                  ],
                ]),
              ],
            ),
          ),
          trailing,
        ]),
      ),
    );
  }

  static String _roleLabel(UserRole r) {
    switch (r) {
      case UserRole.eleve:
        return 'Élève';
      case UserRole.professeur:
        return 'Professeur';
      case UserRole.admin:
        return 'Direction';
      case UserRole.parent:
        return 'Parent';
      case UserRole.direction:
        return 'Direction';
      case UserRole.adminEtablissement:
        return 'Admin';
      default:
        return r.name;
    }
  }

  static Color _roleColor(UserRole r) {
    switch (r) {
      case UserRole.eleve:
        return _kBlue;
      case UserRole.professeur:
        return _kGreen;
      case UserRole.admin:
      case UserRole.direction:
      case UserRole.adminEtablissement:
        return _kPurple;
      case UserRole.parent:
        return _kOrange;
      default:
        return Colors.white38;
    }
  }
}

const _kOrange = Color(0xFFD97706);
