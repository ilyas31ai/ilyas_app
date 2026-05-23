import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../models/chat_message.dart';

class ChatBubble extends StatelessWidget {
  final ChatMessage message;

  const ChatBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    return Padding(
      padding: EdgeInsets.only(
        left: isUser ? 60 : 12,
        right: isUser ? 12 : 60,
        top: 3,
        bottom: 3,
      ),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[_aiAvatar(), const SizedBox(width: 8)],
          Flexible(child: _bubble(context, isUser)),
          if (isUser) ...[const SizedBox(width: 8), _userAvatar()],
        ],
      ),
    );
  }

  Widget _aiAvatar() => Container(
        width: 32,
        height: 32,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF6C47FF), Color(0xFF2563EB)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.auto_awesome, size: 16, color: Colors.white),
      );

  Widget _userAvatar() => Container(
        width: 32,
        height: 32,
        decoration: const BoxDecoration(
          color: Color(0xFF374151),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.person, size: 18, color: Colors.white70),
      );

  Widget _bubble(BuildContext context, bool isUser) {
    return Container(
      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: isUser
            ? const LinearGradient(
                colors: [Color(0xFF2563EB), Color(0xFF1E40AF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: isUser ? null : const Color(0xFF1F2937),
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(20),
          topRight: const Radius.circular(20),
          bottomLeft: Radius.circular(isUser ? 20 : 4),
          bottomRight: Radius.circular(isUser ? 4 : 20),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: isUser
          ? SelectableText(
              message.content,
              style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.5),
            )
          : MarkdownBody(
              data: message.content,
              selectable: true,
              styleSheet: MarkdownStyleSheet(
                p: const TextStyle(color: Colors.white, fontSize: 15, height: 1.5),
                strong: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                em: const TextStyle(
                    color: Colors.white70, fontStyle: FontStyle.italic, fontSize: 15),
                code: TextStyle(
                  color: const Color(0xFFE2E8F0),
                  backgroundColor: Colors.white.withValues(alpha: 0.12),
                  fontSize: 13,
                  fontFamily: 'monospace',
                ),
                codeblockDecoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(8),
                ),
                codeblockPadding: const EdgeInsets.all(10),
                listBullet: const TextStyle(color: Colors.white, fontSize: 15),
                h1: const TextStyle(
                    color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                h2: const TextStyle(
                    color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                h3: const TextStyle(
                    color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                tableHead: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                tableBody: const TextStyle(color: Colors.white70, fontSize: 13),
                tableBorder: TableBorder.all(color: Colors.white24),
                blockquote: const TextStyle(color: Colors.white60, fontSize: 14),
                blockquoteDecoration: const BoxDecoration(
                  border: Border(
                    left: BorderSide(color: Color(0xFF6C47FF), width: 3),
                  ),
                ),
                horizontalRuleDecoration: const BoxDecoration(
                  border: Border(
                    top: BorderSide(color: Colors.white24),
                  ),
                ),
              ),
            ),
    );
  }
}
