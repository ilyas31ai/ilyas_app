import 'package:flutter/material.dart';
import '../models/chat_conversation.dart';
import '../services/chat_ia_service.dart';
import '../widgets/conversation_tile.dart';
import 'chat_ia_page.dart';
import 'chat_setup_page.dart';

class ChatHistoryPage extends StatefulWidget {
  const ChatHistoryPage({super.key});

  @override
  State<ChatHistoryPage> createState() => _ChatHistoryPageState();
}

class _ChatHistoryPageState extends State<ChatHistoryPage> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _delete(ChatConversation conv) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1F2937),
        title: const Text('Supprimer ?', style: TextStyle(color: Colors.white)),
        content: Text(
          'Supprimer "${conv.title}" définitivement ?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Supprimer', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ChatIaService.deleteConversation(conv.id);
    }
  }

  void _open(ChatConversation conv) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatIAPage(
          conversationId: conv.id,
          level: conv.level,
          subject: conv.subject,
          title: conv.title,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(child: _buildList()),
        ],
      ),
      floatingActionButton: _buildFab(),
    );
  }

  AppBar _buildAppBar() => AppBar(
        backgroundColor: const Color(0xFF161B22),
        elevation: 0,
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6C47FF), Color(0xFF2563EB)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.auto_awesome, size: 18, color: Colors.white),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('SCOLAR AI',
                    style: TextStyle(
                        color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                Text('Assistant scolaire',
                    style: TextStyle(color: Colors.white54, fontSize: 11)),
              ],
            ),
          ],
        ),
      );

  Widget _buildSearchBar() => Container(
        color: const Color(0xFF161B22),
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
        child: TextField(
          controller: _search,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          onChanged: (v) => setState(() => _query = v.toLowerCase()),
          decoration: InputDecoration(
            hintText: 'Rechercher une conversation…',
            hintStyle: const TextStyle(color: Colors.white38, fontSize: 14),
            prefixIcon: const Icon(Icons.search, color: Colors.white38, size: 20),
            suffixIcon: _query.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, color: Colors.white38, size: 18),
                    onPressed: () {
                      _search.clear();
                      setState(() => _query = '');
                    },
                  )
                : null,
            filled: true,
            fillColor: const Color(0xFF21262D),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      );

  Widget _buildList() => StreamBuilder<List<ChatConversation>>(
        stream: ChatIaService.conversationsStream(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF2563EB)),
            );
          }

          final all = snap.data ?? [];
          final filtered = _query.isEmpty
              ? all
              : all
                  .where((c) =>
                      c.title.toLowerCase().contains(_query) ||
                      c.subject.toLowerCase().contains(_query) ||
                      c.level.toLowerCase().contains(_query))
                  .toList();

          if (filtered.isEmpty) {
            return _emptyState(all.isEmpty);
          }

          return ListView.builder(
            padding: const EdgeInsets.only(top: 8, bottom: 100),
            itemCount: filtered.length,
            itemBuilder: (_, i) => ConversationTile(
              conversation: filtered[i],
              onTap: () => _open(filtered[i]),
              onDelete: () => _delete(filtered[i]),
            ),
          );
        },
      );

  Widget _emptyState(bool noConversations) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            noConversations ? Icons.chat_bubble_outline : Icons.search_off,
            size: 64,
            color: Colors.white24,
          ),
          const SizedBox(height: 16),
          Text(
            noConversations ? 'Aucune conversation' : 'Aucun résultat',
            style: const TextStyle(
                color: Colors.white54, fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            noConversations
                ? 'Appuie sur + pour démarrer\nun nouveau chat avec SCOLAR AI'
                : 'Essaie un autre terme de recherche',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white38, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildFab() => FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ChatSetupPage()),
        ),
        backgroundColor: const Color(0xFF2563EB),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Nouveau chat', style: TextStyle(color: Colors.white)),
      );
}
