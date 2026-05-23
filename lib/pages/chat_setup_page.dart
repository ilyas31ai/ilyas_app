import 'package:flutter/material.dart';
import '../services/chat_ia_service.dart';
import 'chat_ia_page.dart';

class ChatSetupPage extends StatefulWidget {
  const ChatSetupPage({super.key});

  @override
  State<ChatSetupPage> createState() => _ChatSetupPageState();
}

class _ChatSetupPageState extends State<ChatSetupPage> {
  String? _level;
  String? _subject;
  bool _creating = false;

  static const _levels = ['Primaire', 'Collège', 'Lycée', 'Bac', 'Université', 'DALF'];

  static const _subjects = [
    ('Maths', Icons.calculate, Color(0xFF2563EB)),
    ('Français', Icons.menu_book, Color(0xFF16A34A)),
    ('Anglais', Icons.language, Color(0xFFDC2626)),
    ('Histoire', Icons.history_edu, Color(0xFFD97706)),
    ('Géographie', Icons.public, Color(0xFF0891B2)),
    ('Physique', Icons.science, Color(0xFF7C3AED)),
    ('Chimie', Icons.biotech, Color(0xFFBE185D)),
    ('SVT', Icons.eco, Color(0xFF15803D)),
    ('Philosophie', Icons.psychology, Color(0xFF6D28D9)),
    ('Informatique', Icons.code, Color(0xFF0F766E)),
  ];

  Future<void> _start() async {
    if (_level == null || _subject == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choisis un niveau et une matière')),
      );
      return;
    }
    setState(() => _creating = true);
    final id = await ChatIaService.createConversation(
      level: _level!,
      subject: _subject!,
    );
    if (!mounted) return;
    setState(() => _creating = false);
    if (id != null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ChatIAPage(
            conversationId: id,
            level: _level!,
            subject: _subject!,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        elevation: 0,
        title: const Text('Nouveau chat', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ───────────────────────────────────────────────────────
            Center(
              child: Column(
                children: [
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6C47FF), Color(0xFF2563EB)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(Icons.auto_awesome, size: 36, color: Colors.white),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'SCOLAR AI',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Configure ton assistant scolaire',
                    style: TextStyle(color: Colors.white54, fontSize: 14),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // ── Niveau ───────────────────────────────────────────────────────
            _sectionLabel('Niveau scolaire', Icons.school),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _levels.map((lvl) {
                final sel = _level == lvl;
                return GestureDetector(
                  onTap: () => setState(() => _level = lvl),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                    decoration: BoxDecoration(
                      gradient: sel
                          ? const LinearGradient(
                              colors: [Color(0xFF6C47FF), Color(0xFF2563EB)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : null,
                      color: sel ? null : const Color(0xFF1F2937),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                        color: sel ? Colors.transparent : Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                    child: Text(
                      lvl,
                      style: TextStyle(
                        color: sel ? Colors.white : Colors.white60,
                        fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                        fontSize: 14,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 28),

            // ── Matière ──────────────────────────────────────────────────────
            _sectionLabel('Matière', Icons.book),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 2.8,
              children: _subjects.map(((String name, IconData icon, Color color) s) {
                final sel = _subject == s.$1;
                return GestureDetector(
                  onTap: () => setState(() => _subject = s.$1),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: sel
                          ? s.$3.withValues(alpha: 0.25)
                          : const Color(0xFF1F2937),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: sel ? s.$3 : Colors.white.withValues(alpha: 0.08),
                        width: sel ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(s.$2, color: sel ? s.$3 : Colors.white54, size: 20),
                        const SizedBox(width: 10),
                        Text(
                          s.$1,
                          style: TextStyle(
                            color: sel ? Colors.white : Colors.white60,
                            fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 32),

            // ── Bouton démarrer ───────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: (_creating || _level == null || _subject == null) ? null : _start,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  padding: EdgeInsets.zero,
                ).copyWith(
                  backgroundColor: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.disabled)) return Colors.white12;
                    return null;
                  }),
                ),
                child: Ink(
                  decoration: BoxDecoration(
                    gradient: (_level != null && _subject != null)
                        ? const LinearGradient(
                            colors: [Color(0xFF6C47FF), Color(0xFF2563EB)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : null,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Container(
                    alignment: Alignment.center,
                    child: _creating
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.chat_bubble_rounded, color: Colors.white, size: 20),
                              SizedBox(width: 10),
                              Text(
                                'Démarrer le chat',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String label, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: Colors.white54, size: 18),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}
