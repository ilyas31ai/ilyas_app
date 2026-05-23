import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/user_service.dart';
import '../widgets/user_avatar.dart';

class ProfesseursPage extends StatefulWidget {
  final String currentUser;

  const ProfesseursPage({super.key, required this.currentUser});

  @override
  State<ProfesseursPage> createState() => _ProfesseursPageState();
}

class _ProfesseursPageState extends State<ProfesseursPage> {
  // Firestore stream → uniquement les vrais professeurs inscrits
  late final Stream<List<UserModel>> _profsStream;

  @override
  void initState() {
    super.initState();
    _profsStream = UserService.usersByRoleStream('professeur');
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
      body: StreamBuilder<List<UserModel>>(
        stream: _profsStream,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: Color(0xFF2563EB)));
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
                  const Text(
                    'Aucun professeur inscrit',
                    style: TextStyle(
                        color: Colors.white54,
                        fontSize: 17,
                        fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Les professeurs apparaissent ici\naprès leur inscription',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white24, fontSize: 13),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
            itemCount: profs.length,
            itemBuilder: (_, i) {
              final prof = profs[i];
              return _ProfCard(
                prof: prof,
                onChat: () => Navigator.pushNamed(
                  context,
                  '/discussion',
                  arguments: {
                    'name': prof.email,
                    'user': widget.currentUser,
                  },
                ),
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
  final UserModel prof;
  final VoidCallback onChat;

  const _ProfCard({
    required this.prof,
    required this.onChat,
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

  Color _accent(String matiere) {
    final key = matiere.toLowerCase();
    for (final e in _matiereColors.entries) {
      if (key.contains(e.key)) return e.value;
    }
    return const Color(0xFF6C47FF);
  }

  @override
  Widget build(BuildContext context) {
    final matiere = prof.matiere ?? '';
    final accent = _accent(matiere);
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
              UserAvatar(username: prof.email, radius: 24, showStatus: true),
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
                  'Prof. ${prof.displayName}',
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
                OnlineLabel(username: prof.email),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline,
                color: Color(0xFF2563EB), size: 20),
            tooltip: 'Envoyer un message',
            onPressed: onChat,
          ),
        ],
      ),
    );
  }
}
