import 'package:flutter/material.dart';
import '../services/social_service.dart';
import '../widgets/user_avatar.dart';

class ProfesseursPage extends StatefulWidget {
  final String currentUser;

  const ProfesseursPage({super.key, required this.currentUser});

  @override
  State<ProfesseursPage> createState() => _ProfesseursPageState();
}

class _ProfesseursPageState extends State<ProfesseursPage> {
  Future<void> _showAddDialog() async {
    final nameCtrl = TextEditingController();
    final matiereCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1F2937),
        title: const Text(
          'Ajouter un professeur',
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'Nom du professeur',
                hintStyle: TextStyle(color: Colors.white38),
                prefixIcon:
                    Icon(Icons.person, color: Colors.white38, size: 18),
                enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF2563EB))),
                focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF6C47FF))),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: matiereCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'Matière enseignée',
                hintStyle: TextStyle(color: Colors.white38),
                prefixIcon:
                    Icon(Icons.book_outlined, color: Colors.white38, size: 18),
                enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF2563EB))),
                focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF6C47FF))),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler',
                style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;
              await SocialService.addProf(
                widget.currentUser,
                name,
                matiereCtrl.text.trim(),
              );
              if (mounted) Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
            ),
            child: const Text('Ajouter'),
          ),
        ],
      ),
    );

    nameCtrl.dispose();
    matiereCtrl.dispose();
  }

  Future<void> _confirmDelete(String name) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1F2937),
        title: const Text('Supprimer ?',
            style: TextStyle(color: Colors.white)),
        content: Text('Supprimer Prof. $name ?',
            style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler',
                style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Supprimer',
                style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (ok == true) {
      await SocialService.removeProf(widget.currentUser, name);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Professeurs',
          style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF2563EB),
        onPressed: _showAddDialog,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Ajouter',
            style: TextStyle(color: Colors.white)),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: SocialService.profsStream(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
                child:
                    CircularProgressIndicator(color: Color(0xFF2563EB)));
          }

          final profs = snap.data ?? [];

          if (profs.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: const Color(0xFF161B22),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Icon(Icons.school_outlined,
                        color: Colors.white24, size: 36),
                  ),
                  const SizedBox(height: 16),
                  const Text('Aucun professeur',
                      style: TextStyle(
                          color: Colors.white54,
                          fontSize: 17,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  const Text('Ajoute un professeur avec le bouton +',
                      style:
                          TextStyle(color: Colors.white24, fontSize: 13)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
            itemCount: profs.length,
            itemBuilder: (_, i) {
              final prof = profs[i];
              final name = prof['id'] as String? ?? '';
              final matiere = prof['matiere'] as String? ?? '';

              return _ProfCard(
                name: name,
                matiere: matiere,
                onChat: () => Navigator.pushNamed(
                  context,
                  '/discussion',
                  arguments: {
                    'name': name,
                    'user': widget.currentUser,
                  },
                ),
                onDelete: () => _confirmDelete(name),
              );
            },
          );
        },
      ),
    );
  }
}

// ─── Prof Card ────────────────────────────────────────────────────────────────

class _ProfCard extends StatelessWidget {
  final String name;
  final String matiere;
  final VoidCallback onChat;
  final VoidCallback onDelete;

  const _ProfCard({
    required this.name,
    required this.matiere,
    required this.onChat,
    required this.onDelete,
  });

  static const _matiereColors = <String, Color>{
    'maths': Color(0xFF2563EB),
    'français': Color(0xFF16A34A),
    'anglais': Color(0xFFDC2626),
    'histoire': Color(0xFFD97706),
    'géographie': Color(0xFF0891B2),
    'physique': Color(0xFF7C3AED),
    'chimie': Color(0xFFBE185D),
    'svt': Color(0xFF15803D),
    'philosophie': Color(0xFF6D28D9),
    'informatique': Color(0xFF0F766E),
  };

  Color get _accent {
    final key = matiere.toLowerCase();
    for (final e in _matiereColors.entries) {
      if (key.contains(e.key)) return e.value;
    }
    return const Color(0xFF6C47FF);
  }

  @override
  Widget build(BuildContext context) {
    final accent = _accent;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 5),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Stack(
            children: [
              UserAvatar(username: name, radius: 24, showStatus: true),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: accent,
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: const Color(0xFF161B22), width: 1.5),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Prof. $name',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                if (matiere.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      matiere,
                      style: TextStyle(
                          color: accent,
                          fontSize: 11,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                const SizedBox(height: 2),
                OnlineLabel(username: name),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline,
                color: Color(0xFF2563EB), size: 20),
            tooltip: 'Envoyer un message',
            onPressed: onChat,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline,
                color: Colors.white30, size: 20),
            tooltip: 'Supprimer',
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}
