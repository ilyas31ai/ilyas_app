import 'package:flutter/material.dart';
import '../models/chat_conversation.dart';

class ConversationTile extends StatelessWidget {
  final ChatConversation conversation;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const ConversationTile({
    super.key,
    required this.conversation,
    required this.onTap,
    required this.onDelete,
  });

  static const _icons = <String, IconData>{
    'Maths': Icons.calculate,
    'Français': Icons.menu_book,
    'Anglais': Icons.language,
    'Histoire': Icons.history_edu,
    'Géographie': Icons.public,
    'Physique': Icons.science,
    'Chimie': Icons.biotech,
    'SVT': Icons.eco,
    'Philosophie': Icons.psychology,
    'Informatique': Icons.code,
  };

  static const _colors = <String, Color>{
    'Maths': Color(0xFF2563EB),
    'Français': Color(0xFF16A34A),
    'Anglais': Color(0xFFDC2626),
    'Histoire': Color(0xFFD97706),
    'Géographie': Color(0xFF0891B2),
    'Physique': Color(0xFF7C3AED),
    'Chimie': Color(0xFFBE185D),
    'SVT': Color(0xFF15803D),
    'Philosophie': Color(0xFF6D28D9),
    'Informatique': Color(0xFF0F766E),
  };

  @override
  Widget build(BuildContext context) {
    final color = _colors[conversation.subject] ?? const Color(0xFF374151);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF1F2937),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Row(
          children: [
            // Subject icon
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _icons[conversation.subject] ?? Icons.chat,
                color: color,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            // Title and preview
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    conversation.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (conversation.lastMessage.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      conversation.lastMessage,
                      style: const TextStyle(color: Colors.white54, fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          conversation.level,
                          style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _timeAgo(conversation.updatedAt),
                        style: const TextStyle(color: Colors.white38, fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Delete
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.white30, size: 20),
              tooltip: 'Supprimer',
              onPressed: onDelete,
              splashRadius: 18,
            ),
          ],
        ),
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'À l\'instant';
    if (diff.inMinutes < 60) return 'Il y a ${diff.inMinutes}min';
    if (diff.inHours < 24) return 'Il y a ${diff.inHours}h';
    if (diff.inDays == 1) return 'Hier';
    if (diff.inDays < 7) return 'Il y a ${diff.inDays}j';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}
