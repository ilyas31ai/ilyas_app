import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/user_model.dart';
import '../services/professeur_service.dart';
import 'discussion_page.dart';

/// Messagerie interne réservée aux professeurs.
/// Contacts autorisés : Direction (UserRole.admin) uniquement.
/// Le rôle "secrétariat" pourra être ajouté à UserRole en phase ultérieure.
class ProfesseurMessageriePage extends StatelessWidget {
  const ProfesseurMessageriePage({super.key});

  String get _currentUser =>
      FirebaseAuth.instance.currentUser?.email ?? '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        elevation: 0,
        title: const Text('Messagerie interne',
            style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          _InfoBanner(),
          Expanded(
            child: StreamBuilder<List<UserModel>>(
              stream: ProfesseurService.contactsAutorises(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child: CircularProgressIndicator(
                          color: Color(0xFF374151)));
                }
                final contacts = snap.data ?? [];
                if (contacts.isEmpty) {
                  return _emptyState();
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                  itemCount: contacts.length,
                  itemBuilder: (ctx, i) => _ContactTile(
                    user: contacts[i],
                    currentUser: _currentUser,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.forum_outlined, color: Colors.white24, size: 48),
            SizedBox(height: 12),
            Text(
              'Aucun contact Direction disponible',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Colors.white38, fontSize: 14),
            ),
            SizedBox(height: 8),
            Text(
              'Les comptes Direction (admin) apparaîtront ici.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white24, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Bannière info ────────────────────────────────────────────────────────────

class _InfoBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: const Color(0xFF374151).withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.lock_outline,
              color: Color(0xFF374151), size: 16),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Communication réservée : Professeur ↔ Direction · '
              'Les élèves n\'ont pas accès à cet espace.',
              style: TextStyle(color: Colors.white38, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Tuile contact ────────────────────────────────────────────────────────────

class _ContactTile extends StatelessWidget {
  final UserModel user;
  final String currentUser;

  const _ContactTile({required this.user, required this.currentUser});

  @override
  Widget build(BuildContext context) {
    final initial = user.displayName.isNotEmpty
        ? user.displayName[0].toUpperCase()
        : user.email[0].toUpperCase();

    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DiscussionPage(
            name: user.email,
            user: currentUser,
          ),
        ),
      ),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF161B22),
          borderRadius: BorderRadius.circular(12),
          border:
              Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [Color(0xFF6C47FF), Color(0xFF2563EB)]),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(initial,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.displayName.isNotEmpty
                        ? user.displayName
                        : user.username,
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
                          color: const Color(0xFFD97706)
                              .withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text('Direction',
                            style: TextStyle(
                                color: Color(0xFFD97706),
                                fontSize: 10,
                                fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white24, size: 18),
          ],
        ),
      ),
    );
  }
}
