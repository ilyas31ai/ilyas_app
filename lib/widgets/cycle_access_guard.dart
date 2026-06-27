import 'package:flutter/material.dart';
import '../models/permission_model.dart';
import '../models/user_model.dart';
import '../services/user_service.dart';

/// Garde d'accès par cycle scolaire.
///
/// Laisse passer :
///  • tout utilisateur dont [UserModel.categorie] == [cycleCategorie]
///  • tout rôle Direction ([PermissionService.isDirection])
///
/// Bloque les autres avec un écran "accès refusé" sans crash.
class CycleAccessGuard extends StatelessWidget {
  final String cycleCategorie; // 'Collège' | 'Lycée' | 'Primaire' | etc.
  final List<Color> cycleColors;
  final Widget Function(UserModel user) builder;

  const CycleAccessGuard({
    super.key,
    required this.cycleCategorie,
    required this.cycleColors,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<UserModel?>(
      stream: UserService.currentUserStream(),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return Scaffold(
            backgroundColor: const Color(0xFF0D1117),
            body: Center(
              child: CircularProgressIndicator(color: cycleColors[0]),
            ),
          );
        }
        final user = snap.data;
        if (user == null) {
          return const _AccessDenied(reason: 'Vous devez être connecté.');
        }
        if (PermissionService.isDirection(user.role)) return builder(user);
        if (user.categorie == cycleCategorie) return builder(user);

        return _AccessDenied(
          reason:
              'Cet espace est réservé aux élèves du cycle $cycleCategorie.',
          displayName: user.displayName,
        );
      },
    );
  }
}

class _AccessDenied extends StatelessWidget {
  final String reason;
  final String? displayName;
  const _AccessDenied({required this.reason, this.displayName});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        elevation: 0,
        leading: const BackButton(color: Colors.white70),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.lock_outline,
                    color: Colors.white38, size: 28),
              ),
              const SizedBox(height: 18),
              if (displayName != null && displayName!.isNotEmpty)
                Text(
                  'Bonjour $displayName',
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
              const SizedBox(height: 8),
              Text(
                reason,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 24),
              OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.white24),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Retour',
                    style: TextStyle(color: Colors.white60)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
