import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/user_avatar.dart';
import 'scolar_chat_room_page.dart';

// ─── Constants ───────────────────────────────────────────────────────────────
const _gdBg = Color(0xFF0D1117);
const _gdCard = Color(0xFF161B22);
const _gdCard2 = Color(0xFF1F2937);
const _gdBorder = Color(0xFF21262D);
const _gdBlue = Color(0xFF2563EB);
const _gdPurple = Color(0xFF6C47FF);

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
  final _fs = FirebaseFirestore.instance;

  String get _me => FirebaseAuth.instance.currentUser?.email ?? '';
  String get _chatName => 'groupe_${widget.groupeId}';
  String get _docsPath => 'scolar_groupes/${widget.groupeId}/documents';
  String get _objectifsPath => 'scolar_groupes/${widget.groupeId}/objectifs';
  String get _membresPath => 'scolar_groupes/${widget.groupeId}/membres';

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
    _ensureCurrentUserMember();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _ensureCurrentUserMember() async {
    if (_me.isEmpty) return;
    try {
      await _fs
          .collection('scolar_groupes')
          .doc(widget.groupeId)
          .collection('membres')
          .doc(_me)
          .set({
        'email': _me,
        'nom': _me.split('@').first,
        'joinedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final matiere = widget.groupeData['matiere'] as String? ?? '';
    final niveau = widget.groupeData['niveau'] as String? ?? '';

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
            Row(
              children: [
                if (matiere.isNotEmpty) ...[
                  _SmallTag(text: matiere, color: _gdPurple),
                  const SizedBox(width: 4),
                ],
                if (niveau.isNotEmpty)
                  _SmallTag(text: niveau, color: _gdBlue),
              ],
            ),
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
            Tab(icon: Icon(Icons.chat_bubble_outline, size: 16), text: 'Chat'),
            Tab(
                icon: Icon(Icons.folder_open_outlined, size: 16),
                text: 'Documents'),
            Tab(
                icon: Icon(Icons.flag_outlined, size: 16),
                text: 'Objectifs'),
            Tab(
                icon: Icon(Icons.people_outline, size: 16),
                text: 'Membres'),
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
      user: _me,
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
      body: StreamBuilder<QuerySnapshot>(
        stream: _fs.collection(_docsPath).orderBy('createdAt', descending: true).snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: _gdPurple));
          }
          final docs = snap.data?.docs ?? [];
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
            itemBuilder: (_, i) {
              final d = docs[i].data() as Map<String, dynamic>;
              return _DocumentCard(data: d);
            },
          );
        },
      ),
    );
  }

  Future<void> _showAddDocumentDialog() async {
    final titreCtrl = TextEditingController();
    final contenuCtrl = TextEditingController();
    String type = 'fiche';

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
              children: [
                _DialogField(ctrl: titreCtrl, hint: 'Titre du document'),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  children: ['fiche', 'cours', 'qcm', 'pdf'].map((t) {
                    return ChoiceChip(
                      label: Text(t.toUpperCase()),
                      selected: type == t,
                      onSelected: (_) => setSt(() => type = t),
                      backgroundColor: _gdCard2,
                      selectedColor: _gdBlue,
                      labelStyle: TextStyle(
                          color: type == t ? Colors.white : Colors.white54,
                          fontSize: 11),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 10),
                _DialogField(
                    ctrl: contenuCtrl,
                    hint: 'Contenu ou lien…',
                    maxLines: 3),
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
                backgroundColor: _gdBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () async {
                final titre = titreCtrl.text.trim();
                if (titre.isEmpty) return;
                Navigator.pop(ctx);
                await _fs.collection(_docsPath).add({
                  'titre': titre,
                  'type': type,
                  'contenu': contenuCtrl.text.trim(),
                  'auteurEmail': _me,
                  'auteurNom': _me.split('@').first,
                  'createdAt': FieldValue.serverTimestamp(),
                });
              },
              child: const Text('Ajouter'),
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
    return Scaffold(
      backgroundColor: _gdBg,
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddObjectifDialog,
        backgroundColor: _gdPurple,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _fs.collection(_objectifsPath).orderBy('createdAt').snapshots(),
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
              final doc = docs[i];
              final d = doc.data() as Map<String, dynamic>;
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
            child:
                const Text('Annuler', style: TextStyle(color: Colors.white54)),
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
              await _fs.collection(_objectifsPath).add({
                'titre': titre,
                'done': false,
                'auteurEmail': _me,
                'auteurNom': _me.split('@').first,
                'createdAt': FieldValue.serverTimestamp(),
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
      body: StreamBuilder<QuerySnapshot>(
        stream: _fs.collection(_membresPath).snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: _gdPurple));
          }
          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) {
            return _buildEmptyState(
              icon: Icons.people_outline,
              title: 'Aucun membre',
              subtitle: 'Invitez des camarades à rejoindre ce groupe',
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 100),
            itemCount: docs.length,
            itemBuilder: (_, i) {
              final d = docs[i].data() as Map<String, dynamic>;
              final email = d['email'] as String? ?? '';
              final nom = d['nom'] as String? ?? email.split('@').first;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _gdCard,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _gdBorder),
                ),
                child: Row(
                  children: [
                    UserAvatar(
                        username: email, radius: 22, showStatus: true),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(nom,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500)),
                          Text(email,
                              style: const TextStyle(
                                  color: Colors.white38, fontSize: 11),
                              overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                    if (email == _me)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: _gdPurple.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text('Vous',
                            style: TextStyle(
                                color: _gdPurple,
                                fontSize: 10,
                                fontWeight: FontWeight.w600)),
                      ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _showInviteDialog() async {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Partagez le nom du groupe avec vos camarades !'),
        behavior: SnackBarBehavior.floating,
      ),
    );
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
              gradient: const LinearGradient(
                  colors: [_gdPurple, _gdBlue]),
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

// ─── Document Card ────────────────────────────────────────────────────────────

class _DocumentCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _DocumentCard({required this.data});

  static const _typeColors = {
    'fiche': Color(0xFF6C47FF),
    'cours': Color(0xFF2563EB),
    'qcm': Color(0xFF16A34A),
    'pdf': Color(0xFFD97706),
  };
  static const _typeIcons = {
    'fiche': Icons.description_outlined,
    'cours': Icons.menu_book_outlined,
    'qcm': Icons.quiz_outlined,
    'pdf': Icons.picture_as_pdf_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final titre = data['titre'] as String? ?? '';
    final type = data['type'] as String? ?? 'fiche';
    final auteur = data['auteurNom'] as String? ?? '';
    final contenu = data['contenu'] as String? ?? '';
    final color = _typeColors[type] ?? _gdBlue;
    final icon = _typeIcons[type] ?? Icons.description_outlined;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _gdCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _gdBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                Text(titre,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(type.toUpperCase(),
                      style: TextStyle(
                          color: color,
                          fontSize: 9,
                          fontWeight: FontWeight.w700)),
                ),
                if (contenu.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(contenu,
                      style: const TextStyle(
                          color: Colors.white38, fontSize: 12),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                ],
                const SizedBox(height: 4),
                Text('par $auteur',
                    style: const TextStyle(
                        color: Colors.white24, fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
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
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
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
