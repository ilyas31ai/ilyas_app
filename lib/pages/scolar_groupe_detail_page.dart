import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/groupe_model.dart';
import '../services/groupe_service.dart';
import '../widgets/user_avatar.dart';
import 'scolar_chat_room_page.dart';

// ─── Constants ───────────────────────────────────────────────────────────────
const _gdBg     = Color(0xFF0D1117);
const _gdCard   = Color(0xFF161B22);
const _gdCard2  = Color(0xFF1F2937);
const _gdBorder = Color(0xFF21262D);
const _gdBlue   = Color(0xFF2563EB);
const _gdPurple = Color(0xFF6C47FF);
const _gdGreen  = Color(0xFF16A34A);
const _gdRed    = Color(0xFFDC2626);

// ─── Page ─────────────────────────────────────────────────────────────────────

class SCOLARGroupeDetailPage extends StatefulWidget {
  final String groupeId;
  final String groupeNom;
  final Map<String, dynamic> groupeData;

  const SCOLARGroupeDetailPage({
    super.key,
    required this.groupeId,
    required this.groupeNom,
    required this.groupeData,
  });

  @override
  State<SCOLARGroupeDetailPage> createState() =>
      _SCOLARGroupeDetailPageState();
}

class _SCOLARGroupeDetailPageState extends State<SCOLARGroupeDetailPage>
    with TickerProviderStateMixin {
  late final TabController _tabs;

  String get _myUid   => FirebaseAuth.instance.currentUser?.uid ?? '';
  String get _myEmail => FirebaseAuth.instance.currentUser?.email ?? '';
  String get _chatName => 'groupe_${widget.groupeId}';
  String get _objectifsPath => 'scolar_groupes/${widget.groupeId}/objectifs';

  GroupeRole? _monRole;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
    _rejoindreEtChargerRole();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _rejoindreEtChargerRole() async {
    await GroupeService.rejoindreGroupe(widget.groupeId);
    final role = await GroupeService.monRole(widget.groupeId);
    if (mounted) setState(() => _monRole = role);
  }

  bool get _isAdmin => _monRole == GroupeRole.admin;

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final matiere = widget.groupeData['matiere'] as String? ?? '';
    final niveau  = widget.groupeData['niveau'] as String? ?? '';

    return Scaffold(
      backgroundColor: _gdBg,
      appBar: AppBar(
        backgroundColor: _gdCard,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.groupeNom,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
            Row(children: [
              if (matiere.isNotEmpty) ...[
                _SmallTag(text: matiere, color: _gdPurple),
                const SizedBox(width: 4),
              ],
              if (niveau.isNotEmpty)
                _SmallTag(text: niveau, color: _gdBlue),
            ]),
          ],
        ),
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          indicatorColor: _gdPurple,
          indicatorWeight: 2,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white38,
          labelStyle:
              const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          tabs: const [
            Tab(icon: Icon(Icons.chat_bubble_outline, size: 16),  text: 'Chat'),
            Tab(icon: Icon(Icons.folder_open_outlined,  size: 16), text: 'Documents'),
            Tab(icon: Icon(Icons.flag_outlined,         size: 16), text: 'Objectifs'),
            Tab(icon: Icon(Icons.people_outline,        size: 16), text: 'Membres'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _buildChatTab(),
          _buildDocumentsTab(),
          _buildObjectifsTab(),
          _buildMembresTab(),
        ],
      ),
    );
  }

  // ── Tab Chat ──────────────────────────────────────────────────────────────

  Widget _buildChatTab() {
    return SCOLARChatRoomPage(
      name: _chatName,
      user: _myEmail,
      displayName: widget.groupeNom,
    );
  }

  // ── Tab Documents ─────────────────────────────────────────────────────────

  Widget _buildDocumentsTab() {
    return Scaffold(
      backgroundColor: _gdBg,
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDocumentDialog,
        backgroundColor: _gdBlue,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: StreamBuilder<List<GroupeDocument>>(
        stream: GroupeService.documentsStream(widget.groupeId),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: _gdPurple));
          }
          final docs = snap.data ?? [];
          if (docs.isEmpty) {
            return _buildEmptyState(
              icon: Icons.folder_open_outlined,
              title: 'Aucun document',
              subtitle: 'Ajoutez des fiches et ressources au groupe',
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 100),
            itemCount: docs.length,
            itemBuilder: (_, i) => _DocumentCard(
              doc: docs[i],
              groupeId: widget.groupeId,
              isAdmin: _isAdmin,
            ),
          );
        },
      ),
    );
  }

  Future<void> _showAddDocumentDialog() async {
    final titreCtrl   = TextEditingController();
    final contenuCtrl = TextEditingController();
    String type = 'fiche';
    File? pickedFile;
    String? pickedFileName;
    bool uploading = false;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          backgroundColor: _gdCard,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20)),
          title: const Row(children: [
            Icon(Icons.upload_outlined, color: _gdBlue, size: 22),
            SizedBox(width: 10),
            Text('Ajouter un document',
                style: TextStyle(color: Colors.white, fontSize: 15)),
          ]),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _DialogField(ctrl: titreCtrl, hint: 'Titre du document *'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  children: ['fiche', 'cours', 'qcm', 'pdf']
                      .map((t) => ChoiceChip(
                            label: Text(t.toUpperCase()),
                            selected: type == t,
                            onSelected: (_) => setSt(() => type = t),
                            backgroundColor: _gdCard2,
                            selectedColor: _gdBlue,
                            labelStyle: TextStyle(
                                color: type == t
                                    ? Colors.white
                                    : Colors.white54,
                                fontSize: 11),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 8),
                _DialogField(
                    ctrl: contenuCtrl,
                    hint: 'Contenu ou lien… (optionnel)',
                    maxLines: 3),
                const SizedBox(height: 10),
                // Bouton sélection fichier
                GestureDetector(
                  onTap: () async {
                    final result = await FilePicker.platform.pickFiles(
                      type: FileType.custom,
                      allowedExtensions: [
                        'pdf', 'docx', 'doc', 'txt', 'pptx', 'ppt',
                        'xlsx', 'xls', 'jpg', 'jpeg', 'png',
                      ],
                    );
                    if (result != null && result.files.single.path != null) {
                      setSt(() {
                        pickedFile = File(result.files.single.path!);
                        pickedFileName = result.files.single.name;
                      });
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: _gdCard2,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: pickedFile != null
                              ? _gdBlue.withValues(alpha: 0.5)
                              : Colors.white12),
                    ),
                    child: Row(children: [
                      Icon(
                        pickedFile != null
                            ? Icons.attach_file
                            : Icons.upload_file_outlined,
                        color: pickedFile != null
                            ? _gdBlue
                            : Colors.white38,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          pickedFileName ?? 'Joindre un fichier (optionnel)',
                          style: TextStyle(
                              color: pickedFile != null
                                  ? Colors.white
                                  : Colors.white38,
                              fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (pickedFile != null)
                        GestureDetector(
                          onTap: () =>
                              setSt(() { pickedFile = null; pickedFileName = null; }),
                          child: const Icon(Icons.close,
                              color: Colors.white38, size: 16),
                        ),
                    ]),
                  ),
                ),
                if (uploading) ...[
                  const SizedBox(height: 10),
                  const LinearProgressIndicator(
                    backgroundColor: Color(0xFF1F2937),
                    valueColor: AlwaysStoppedAnimation(_gdBlue),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: uploading ? null : () => Navigator.pop(ctx),
              child: const Text('Annuler',
                  style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _gdBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: uploading
                  ? null
                  : () async {
                      final titre = titreCtrl.text.trim();
                      if (titre.isEmpty) return;
                      setSt(() => uploading = true);
                      try {
                        await GroupeService.ajouterDocument(
                          groupeId: widget.groupeId,
                          titre: titre,
                          type: type,
                          contenu: contenuCtrl.text.trim(),
                          fichier: pickedFile,
                          nomFichier: pickedFileName,
                        );
                        if (ctx.mounted) Navigator.pop(ctx);
                      } catch (_) {
                        setSt(() => uploading = false);
                      }
                    },
              child: uploading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Text('Ajouter'),
            ),
          ],
        ),
      ),
    );
    titreCtrl.dispose();
    contenuCtrl.dispose();
  }

  // ── Tab Objectifs ─────────────────────────────────────────────────────────

  Widget _buildObjectifsTab() {
    final fs = FirebaseFirestore.instance;
    return Scaffold(
      backgroundColor: _gdBg,
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddObjectifDialog,
        backgroundColor: _gdPurple,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: fs
            .collection(_objectifsPath)
            .orderBy('createdAt')
            .snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: _gdPurple));
          }
          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) {
            return _buildEmptyState(
              icon: Icons.flag_outlined,
              title: 'Aucun objectif',
              subtitle: 'Définissez les objectifs du groupe',
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 100),
            itemCount: docs.length,
            itemBuilder: (_, i) {
              final doc  = docs[i];
              final d    = doc.data() as Map<String, dynamic>;
              final done = d['done'] as bool? ?? false;
              final title = d['titre'] as String? ?? '';
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: _gdCard,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _gdBorder),
                ),
                child: CheckboxListTile(
                  value: done,
                  onChanged: (val) async {
                    await doc.reference.update({'done': val ?? false});
                  },
                  title: Text(
                    title,
                    style: TextStyle(
                      color: done ? Colors.white38 : Colors.white,
                      fontSize: 14,
                      decoration: done
                          ? TextDecoration.lineThrough
                          : TextDecoration.none,
                    ),
                  ),
                  subtitle: Text(
                    d['auteurNom'] as String? ?? '',
                    style: const TextStyle(
                        color: Colors.white24, fontSize: 11),
                  ),
                  activeColor: _gdPurple,
                  checkColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _showAddObjectifDialog() async {
    final ctrl = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _gdCard,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: const Row(children: [
          Icon(Icons.flag_outlined, color: _gdPurple, size: 22),
          SizedBox(width: 10),
          Text('Nouvel objectif',
              style: TextStyle(color: Colors.white, fontSize: 15)),
        ]),
        content: _DialogField(ctrl: ctrl, hint: 'Décrivez l\'objectif…'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler',
                style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _gdPurple,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              final titre = ctrl.text.trim();
              if (titre.isEmpty) return;
              Navigator.pop(context);
              await FirebaseFirestore.instance
                  .collection(_objectifsPath)
                  .add({
                'titre':       titre,
                'done':        false,
                'auteurEmail': _myEmail,
                'auteurNom':   _myEmail.split('@').first,
                'createdAt':   FieldValue.serverTimestamp(),
              });
            },
            child: const Text('Ajouter'),
          ),
        ],
      ),
    );
    ctrl.dispose();
  }

  // ── Tab Membres ───────────────────────────────────────────────────────────

  Widget _buildMembresTab() {
    return Scaffold(
      backgroundColor: _gdBg,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showInviteDialog,
        backgroundColor: _gdPurple,
        icon: const Icon(Icons.person_add_outlined),
        label: const Text('Inviter'),
      ),
      body: StreamBuilder<List<GroupeMembre>>(
        stream: GroupeService.membresStream(widget.groupeId),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: _gdPurple));
          }
          final membres = snap.data ?? [];
          if (membres.isEmpty) {
            return _buildEmptyState(
              icon: Icons.people_outline,
              title: 'Aucun membre',
              subtitle: 'Invitez des camarades à rejoindre ce groupe',
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 100),
            itemCount: membres.length,
            itemBuilder: (_, i) => _MembreTile(
              membre: membres[i],
              myUid: _myUid,
              isAdmin: _isAdmin,
              onChangerRole: (role) async {
                await GroupeService.changerRole(
                    widget.groupeId, membres[i].uid, role);
              },
              onSupprimer: () async {
                await GroupeService.supprimerMembre(
                    widget.groupeId, membres[i].uid);
              },
            ),
          );
        },
      ),
    );
  }

  Future<void> _showInviteDialog() async {
    final emailCtrl = TextEditingController();
    bool loading = false;
    String? erreur;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          backgroundColor: _gdCard,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20)),
          title: const Row(children: [
            Icon(Icons.person_add_outlined,
                color: _gdPurple, size: 22),
            SizedBox(width: 10),
            Text('Inviter un membre',
                style: TextStyle(color: Colors.white, fontSize: 15)),
          ]),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _DialogField(
                  ctrl: emailCtrl,
                  hint: 'Email du membre à inviter'),
              if (erreur != null) ...[
                const SizedBox(height: 6),
                Text(erreur!,
                    style: const TextStyle(
                        color: _gdRed, fontSize: 12)),
              ],
              if (loading) ...[
                const SizedBox(height: 10),
                const LinearProgressIndicator(
                  backgroundColor: Color(0xFF1F2937),
                  valueColor: AlwaysStoppedAnimation(_gdPurple),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler',
                  style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _gdPurple,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: loading
                  ? null
                  : () async {
                      final email = emailCtrl.text.trim();
                      if (email.isEmpty || !email.contains('@')) {
                        setSt(() => erreur = 'Email invalide');
                        return;
                      }
                      setSt(() { loading = true; erreur = null; });
                      try {
                        await GroupeService.inviterParEmail(
                            widget.groupeId, email);
                        if (ctx.mounted && mounted) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content:
                                  Text('$email a été invité !'),
                              backgroundColor: _gdGreen,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(10)),
                            ),
                          );
                        }
                      } catch (_) {
                        setSt(() {
                          loading = false;
                          erreur = 'Erreur lors de l\'invitation';
                        });
                      }
                    },
              child: loading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Text('Inviter'),
            ),
          ],
        ),
      ),
    );
    emailCtrl.dispose();
  }

  // ── Helper ────────────────────────────────────────────────────────────────

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              gradient:
                  const LinearGradient(colors: [_gdPurple, _gdBlue]),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(icon, color: Colors.white54, size: 36),
          ),
          const SizedBox(height: 16),
          Text(title,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(subtitle,
              style: const TextStyle(
                  color: Colors.white38, fontSize: 13),
              textAlign: TextAlign.center),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

// ─── Membre Tile ──────────────────────────────────────────────────────────────

class _MembreTile extends StatelessWidget {
  final GroupeMembre membre;
  final String myUid;
  final bool isAdmin;
  final Future<void> Function(GroupeRole) onChangerRole;
  final Future<void> Function() onSupprimer;

  const _MembreTile({
    required this.membre,
    required this.myUid,
    required this.isAdmin,
    required this.onChangerRole,
    required this.onSupprimer,
  });

  @override
  Widget build(BuildContext context) {
    final isMe     = membre.uid == myUid;
    final isMemAdm = membre.role == GroupeRole.admin;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _gdCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _gdBorder),
      ),
      child: Row(children: [
        UserAvatar(username: membre.email, radius: 22, showStatus: true),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                membre.nom.isNotEmpty
                    ? membre.nom
                    : membre.email.split('@').first,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500),
              ),
              Text(
                membre.email,
                style: const TextStyle(
                    color: Colors.white38, fontSize: 11),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        // Badge rôle
        _RoleBadge(role: membre.role, isMe: isMe),
        // Menu admin (sauf soi-même si admin)
        if (isAdmin && !isMe) ...[
          const SizedBox(width: 4),
          PopupMenuButton<_MembreAction>(
            icon: const Icon(Icons.more_vert,
                color: Colors.white38, size: 18),
            color: _gdCard2,
            onSelected: (action) async {
              if (action == _MembreAction.promouvoir) {
                await onChangerRole(GroupeRole.admin);
              } else if (action == _MembreAction.retrograder) {
                await onChangerRole(GroupeRole.membre);
              } else if (action == _MembreAction.supprimer) {
                await onSupprimer();
              }
            },
            itemBuilder: (_) => [
              if (!isMemAdm)
                const PopupMenuItem(
                  value: _MembreAction.promouvoir,
                  child: Row(children: [
                    Icon(Icons.star_outline,
                        color: _gdPurple, size: 16),
                    SizedBox(width: 8),
                    Text('Nommer admin',
                        style: TextStyle(
                            color: Colors.white, fontSize: 13)),
                  ]),
                ),
              if (isMemAdm)
                const PopupMenuItem(
                  value: _MembreAction.retrograder,
                  child: Row(children: [
                    Icon(Icons.person_outline,
                        color: Colors.white54, size: 16),
                    SizedBox(width: 8),
                    Text('Rétrograder en membre',
                        style: TextStyle(
                            color: Colors.white, fontSize: 13)),
                  ]),
                ),
              const PopupMenuItem(
                value: _MembreAction.supprimer,
                child: Row(children: [
                  Icon(Icons.remove_circle_outline,
                      color: _gdRed, size: 16),
                  SizedBox(width: 8),
                  Text('Retirer du groupe',
                      style:
                          TextStyle(color: _gdRed, fontSize: 13)),
                ]),
              ),
            ],
          ),
        ],
      ]),
    );
  }
}

enum _MembreAction { promouvoir, retrograder, supprimer }

class _RoleBadge extends StatelessWidget {
  final GroupeRole role;
  final bool isMe;
  const _RoleBadge({required this.role, required this.isMe});

  @override
  Widget build(BuildContext context) {
    if (isMe) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: _gdPurple.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text('Vous',
            style: TextStyle(
                color: _gdPurple,
                fontSize: 10,
                fontWeight: FontWeight.w600)),
      );
    }
    if (role == GroupeRole.admin) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFFD97706).withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text('Admin',
            style: TextStyle(
                color: Color(0xFFD97706),
                fontSize: 10,
                fontWeight: FontWeight.w600)),
      );
    }
    return const SizedBox.shrink();
  }
}

// ─── Document Card ────────────────────────────────────────────────────────────

class _DocumentCard extends StatelessWidget {
  final GroupeDocument doc;
  final String groupeId;
  final bool isAdmin;
  const _DocumentCard({
    required this.doc,
    required this.groupeId,
    required this.isAdmin,
  });

  static const _typeColors = {
    'fiche': Color(0xFF6C47FF),
    'cours': Color(0xFF2563EB),
    'qcm':   Color(0xFF16A34A),
    'pdf':   Color(0xFFD97706),
  };
  static const _typeIcons = {
    'fiche': Icons.description_outlined,
    'cours': Icons.menu_book_outlined,
    'qcm':   Icons.quiz_outlined,
    'pdf':   Icons.picture_as_pdf_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final color = _typeColors[doc.type] ?? _gdBlue;
    final icon  = _typeIcons[doc.type] ?? Icons.description_outlined;
    final hasFile = doc.fileUrl != null && doc.fileUrl!.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _gdCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _gdBorder),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(doc.titre,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(doc.type.toUpperCase(),
                      style: TextStyle(
                          color: color,
                          fontSize: 9,
                          fontWeight: FontWeight.w700)),
                ),
                if (hasFile) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: _gdGreen.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text('Fichier joint',
                        style: TextStyle(
                            color: _gdGreen,
                            fontSize: 9,
                            fontWeight: FontWeight.w700)),
                  ),
                ],
              ]),
              if (doc.contenu.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(doc.contenu,
                    style: const TextStyle(
                        color: Colors.white38, fontSize: 12),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
              ],
              const SizedBox(height: 4),
              Text('par ${doc.auteurNom}',
                  style: const TextStyle(
                      color: Colors.white24, fontSize: 11)),
            ],
          ),
        ),
        Column(children: [
          if (hasFile)
            IconButton(
              icon: const Icon(Icons.download_outlined,
                  color: _gdBlue, size: 20),
              tooltip: 'Télécharger',
              onPressed: () async {
                final uri = Uri.parse(doc.fileUrl!);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri,
                      mode: LaunchMode.externalApplication);
                }
              },
            ),
          if (isAdmin)
            IconButton(
              icon: const Icon(Icons.delete_outline,
                  color: Colors.white24, size: 18),
              tooltip: 'Supprimer',
              onPressed: () async {
                await GroupeService.supprimerDocument(groupeId, doc.id);
              },
            ),
        ]),
      ]),
    );
  }
}

// ─── Small helpers ────────────────────────────────────────────────────────────

class _SmallTag extends StatelessWidget {
  final String text;
  final Color color;
  const _SmallTag({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(text,
          style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w600)),
    );
  }
}

class _DialogField extends StatelessWidget {
  final TextEditingController ctrl;
  final String hint;
  final int maxLines;
  const _DialogField(
      {required this.ctrl, required this.hint, this.maxLines = 1});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      minLines: 1,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white38),
        filled: true,
        fillColor: _gdCard2,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
