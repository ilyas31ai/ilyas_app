import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/user_model.dart';
import '../services/professeur_service.dart';
import '../widgets/user_avatar.dart';
import 'scolar_chat_room_page.dart';

/// Messagerie professeur — trois onglets :
///   1. Direction (admin) : messagerie interne
///   2. Élèves : questions pédagogiques reçues / à initier
///   3. Parents : contact direct avec les parents des élèves
class ProfesseurMessageriePage extends StatelessWidget {
  const ProfesseurMessageriePage({super.key});

  String get _currentUser =>
      FirebaseAuth.instance.currentUser?.email ?? '';
  String get _currentUid =>
      FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: const Color(0xFF0D1117),
        appBar: AppBar(
          backgroundColor: const Color(0xFF161B22),
          elevation: 0,
          title: const Text(
            'Messagerie',
            style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold),
          ),
          bottom: const TabBar(
            labelColor: Color(0xFF2563EB),
            unselectedLabelColor: Colors.white38,
            indicatorColor: Color(0xFF2563EB),
            tabs: [
              Tab(text: 'Direction'),
              Tab(text: 'Élèves'),
              Tab(text: 'Parents'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _DirectionTab(currentUser: _currentUser),
            _ElevesTab(currentUser: _currentUser, currentUid: _currentUid),
            _ParentsTab(currentUser: _currentUser, currentUid: _currentUid),
          ],
        ),
      ),
    );
  }
}

// ─── Onglet Direction ─────────────────────────────────────────────────────────

class _DirectionTab extends StatelessWidget {
  final String currentUser;
  const _DirectionTab({required this.currentUser});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _InfoBanner(
          icon: Icons.lock_outline,
          color: const Color(0xFF374151),
          text: 'Communication réservée : Professeur ↔ Direction.',
        ),
        Expanded(
          child: StreamBuilder<List<UserModel>>(
            stream: ProfesseurService.contactsAutorises(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(
                    child: CircularProgressIndicator(
                        color: Color(0xFF374151)));
              }
              if (snap.hasError) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'Impossible de charger les contacts Direction.',
                      style: TextStyle(color: Colors.white54, fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }
              final contacts = snap.data ?? [];
              if (contacts.isEmpty) {
                return _emptyState(
                  Icons.forum_outlined,
                  'Aucun contact Direction disponible',
                  'Les comptes Direction (admin) apparaîtront ici.',
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                itemCount: contacts.length,
                itemBuilder: (ctx, i) => _UserTile(
                  displayName: contacts[i].displayName.isNotEmpty
                      ? contacts[i].displayName
                      : contacts[i].username,
                  email: contacts[i].email,
                  photoUrl: contacts[i].photoUrl,
                  roleLabel: 'Direction',
                  roleColor: const Color(0xFFD97706),
                  currentUser: currentUser,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ─── Onglet Élèves ────────────────────────────────────────────────────────────

class _ElevesTab extends StatefulWidget {
  final String currentUser;
  final String currentUid;
  const _ElevesTab({required this.currentUser, required this.currentUid});

  @override
  State<_ElevesTab> createState() => _ElevesTabState();
}

class _ElevesTabState extends State<_ElevesTab> {
  late Future<List<UserModel>> _elevesFuture;

  @override
  void initState() {
    super.initState();
    _elevesFuture = _loadEleves();
  }

  void _refresh() => setState(() => _elevesFuture = _loadEleves());

  Future<List<UserModel>> _loadEleves() async {
    final uid = widget.currentUid;
    if (uid.isEmpty) return [];
    final fs = FirebaseFirestore.instance;
    final currentEmail = FirebaseAuth.instance.currentUser?.email ?? '';

    // Approche 1 — profId écrit dans le profil élève par la Direction
    try {
      final snap = await fs
          .collection('users')
          .where('profId', isEqualTo: uid)
          .get();
      final byProfId = snap.docs
          .map(UserModel.fromDoc)
          .where((u) => u.role == UserRole.eleve)
          .toList();
      if (byProfId.isNotEmpty) {
        return byProfId..sort((a, b) => a.displayName.compareTo(b.displayName));
      }
    } catch (_) {}

    // Approche 2 — classes où professeurId == uid
    final classeIds = <String>{};
    try {
      final snap = await fs
          .collection('classes')
          .where('professeurId', isEqualTo: uid)
          .get();
      for (final d in snap.docs) { classeIds.add(d.id); }
    } catch (_) {}

    // Approche 3 — classes où professeurEmail == email (si uid non trouvé)
    if (classeIds.isEmpty && currentEmail.isNotEmpty) {
      try {
        final snap = await fs
            .collection('classes')
            .where('professeurEmail', isEqualTo: currentEmail)
            .get();
        for (final d in snap.docs) { classeIds.add(d.id); }
      } catch (_) {}
    }

    if (classeIds.isNotEmpty) {
      // Approche 2b — élèves via classeId dans leur profil utilisateur
      try {
        final snap = await fs
            .collection('users')
            .where('classeId', whereIn: classeIds.take(10).toList())
            .get();
        final eleves = snap.docs
            .map(UserModel.fromDoc)
            .where((u) => u.role == UserRole.eleve)
            .toList();
        if (eleves.isNotEmpty) {
          return eleves..sort((a, b) => a.displayName.compareTo(b.displayName));
        }
      } catch (_) {}

      // Approche 4 — eleveIds directement depuis les documents classe
      final allEleveIds = <String>[];
      for (final cid in classeIds) {
        try {
          final classeDoc = await fs.collection('classes').doc(cid).get();
          final ids = List<String>.from(
              classeDoc.data()?['eleveIds'] as List? ?? []);
          allEleveIds.addAll(ids.where((id) => id.isNotEmpty));
        } catch (_) {}
      }
      if (allEleveIds.isNotEmpty) {
        final eleves = <UserModel>[];
        for (int i = 0; i < allEleveIds.length; i += 10) {
          final end =
              i + 10 > allEleveIds.length ? allEleveIds.length : i + 10;
          final chunk = allEleveIds.sublist(i, end);
          try {
            final snap = await fs
                .collection('users')
                .where(FieldPath.documentId, whereIn: chunk)
                .get();
            eleves.addAll(snap.docs
                .map(UserModel.fromDoc)
                .where((u) => u.role == UserRole.eleve));
          } catch (_) {}
        }
        if (eleves.isNotEmpty) {
          return eleves
            ..sort((a, b) => a.displayName.compareTo(b.displayName));
        }
      }
    }

    // Approche 5 — fallback admin : si le compte est Direction, charger tous les élèves
    try {
      final meSnap = await fs.collection('users').doc(uid).get();
      final role = meSnap.data()?['role'] as String? ?? '';
      if (role == 'admin') {
        final snap = await fs
            .collection('users')
            .where('role', isEqualTo: 'eleve')
            .get();
        final eleves = snap.docs
            .map(UserModel.fromDoc)
            .toList()
          ..sort((a, b) => a.displayName.compareTo(b.displayName));
        return eleves;
      }
    } catch (_) {}

    return [];
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _InfoBanner(
          icon: Icons.school_outlined,
          color: const Color(0xFF2563EB),
          text:
              'Vos élèves peuvent vous envoyer des questions. '
              'Cliquez sur un élève pour ouvrir la discussion.',
        ),
        Expanded(
          child: FutureBuilder<List<UserModel>>(
            future: _elevesFuture,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(
                    child: CircularProgressIndicator(
                        color: Color(0xFF2563EB)));
              }
              if (snap.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.groups_outlined,
                            color: Colors.white24, size: 48),
                        const SizedBox(height: 12),
                        const Text(
                          'Impossible de charger la liste des élèves.',
                          style:
                              TextStyle(color: Colors.white54, fontSize: 14),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        TextButton.icon(
                          onPressed: _refresh,
                          icon: const Icon(Icons.refresh,
                              color: Color(0xFF2563EB)),
                          label: const Text('Réessayer',
                              style: TextStyle(color: Color(0xFF2563EB))),
                        ),
                      ],
                    ),
                  ),
                );
              }
              final eleves = snap.data ?? [];
              if (eleves.isEmpty) {
                return _emptyState(
                  Icons.groups_outlined,
                  'Aucun élève dans vos classes',
                  'Assignez des élèves à vos classes pour les voir ici.',
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                itemCount: eleves.length,
                itemBuilder: (ctx, i) {
                  final e = eleves[i];
                  return _UserTile(
                    displayName: e.displayName.isNotEmpty
                        ? e.displayName
                        : e.username,
                    email: e.email,
                    photoUrl: e.photoUrl,
                    roleLabel: e.classeNom ?? 'Élève',
                    roleColor: const Color(0xFF16A34A),
                    currentUser: widget.currentUser,
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

// ─── Widgets partagés ─────────────────────────────────────────────────────────

class _InfoBanner extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;

  const _InfoBanner({
    required this.icon,
    required this.color,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Colors.white38, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}

class _UserTile extends StatelessWidget {
  final String displayName;
  final String email;
  final String? photoUrl;
  final String roleLabel;
  final Color roleColor;
  final String currentUser;

  const _UserTile({
    required this.displayName,
    required this.email,
    this.photoUrl,
    required this.roleLabel,
    required this.roleColor,
    required this.currentUser,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SCOLARChatRoomPage(
            name: email,
            user: currentUser,
            displayName: displayName.isNotEmpty ? displayName : null,
          ),
        ),
      ),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF161B22),
          borderRadius: BorderRadius.circular(12),
          border:
              Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Row(
          children: [
            UserAvatar(
                username: email,
                radius: 22,
                showStatus: true,
                photoUrl: photoUrl),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14),
                  ),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: roleColor.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          roleLabel,
                          style: TextStyle(
                              color: roleColor,
                              fontSize: 10,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right,
                color: Colors.white24, size: 18),
          ],
        ),
      ),
    );
  }
}

// ─── Onglet Parents ───────────────────────────────────────────────────────────

class _ParentsTab extends StatefulWidget {
  final String currentUser;
  final String currentUid;
  const _ParentsTab(
      {required this.currentUser, required this.currentUid});

  @override
  State<_ParentsTab> createState() => _ParentsTabState();
}

class _ParentsTabState extends State<_ParentsTab> {
  late final Future<List<UserModel>> _parentsFuture;

  @override
  void initState() {
    super.initState();
    _parentsFuture = _loadParents();
  }

  Future<List<UserModel>> _loadParents() async {
    final uid = widget.currentUid;
    if (uid.isEmpty) return [];
    try {
      final fs = FirebaseFirestore.instance;

      // 1. Récupérer les classeIds des classes du professeur
      final classesSnap = await fs
          .collection('classes')
          .where('professeurId', isEqualTo: uid)
          .get();

      final classeIds = classesSnap.docs.map((d) => d.id).toList();
      if (classeIds.isEmpty) return [];

      // 2. Parents dont les enfants sont dans ces classes — filtre unique
      //    arrayContainsAny sur enfantClasseIds (index auto), role filtré en Dart
      final parentsSnap = await fs
          .collection('users')
          .where('enfantClasseIds',
              arrayContainsAny: classeIds.take(10).toList())
          .get();

      final parents = parentsSnap.docs
          .map(UserModel.fromDoc)
          .where((u) => u.role == UserRole.parent)
          .toList()
        ..sort((a, b) => a.displayName.compareTo(b.displayName));
      return parents;
    } catch (_) {
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _InfoBanner(
          icon: Icons.family_restroom_outlined,
          color: const Color(0xFFBE185D),
          text:
              'Parents des élèves dans vos classes. '
              'Cliquez pour envoyer un message.',
        ),
        Expanded(
          child: FutureBuilder<List<UserModel>>(
            future: _parentsFuture,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(
                    child: CircularProgressIndicator(
                        color: Color(0xFFBE185D)));
              }
              if (snap.hasError) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'Impossible de charger les contacts parents.',
                      style: TextStyle(color: Colors.white54, fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }
              final parents = snap.data ?? [];
              if (parents.isEmpty) {
                return _emptyState(
                  Icons.family_restroom_outlined,
                  'Aucun parent trouvé',
                  'Les parents des élèves de vos classes apparaîtront ici.',
                );
              }
              return ListView.builder(
                padding:
                    const EdgeInsets.fromLTRB(16, 12, 16, 32),
                itemCount: parents.length,
                itemBuilder: (ctx, i) {
                  final p = parents[i];
                  return _UserTile(
                    displayName: p.displayName.isNotEmpty
                        ? p.displayName
                        : p.username,
                    email: p.email,
                    photoUrl: p.photoUrl,
                    roleLabel: 'Parent',
                    roleColor: const Color(0xFFBE185D),
                    currentUser: widget.currentUser,
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

// ─── Empty state ──────────────────────────────────────────────────────────────

Widget _emptyState(IconData icon, String title, String subtitle) {
  return Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white24, size: 48),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white38, fontSize: 14),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white24, fontSize: 12),
          ),
        ],
      ),
    ),
  );
}
