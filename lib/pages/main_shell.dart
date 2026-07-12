import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'home_page.dart';
import 'eleves_page.dart';
import 'profile_page.dart';
import 'scolar_connect_page.dart';
import 'direction_dashboard_page.dart';
import 'espace_direction_page.dart';
import 'professeur_eleves_page.dart';
import 'espace_parent_page.dart';
import '../models/permission_model.dart';
import '../models/user_model.dart';
import '../services/notification_service.dart';
import '../services/social_service.dart';
import '../services/user_service.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;
  UserRole _role = UserRole.eleve;
  bool _listenersInit = false;
  StreamSubscription<UserModel?>? _roleSub;

  static String get _user => FirebaseAuth.instance.currentUser?.email ?? '';

  @override
  void initState() {
    super.initState();
    SocialService.goOnline();
    UserService.syncProfile();
    NotificationService.init(_user);

    // Écoute les changements de rôle pour mettre à jour la navigation.
    // N'appelle setState que lorsque le rôle change réellement (pas à chaque
    // lastSeen) pour éviter de reconstruire l'IndexedStack inutilement.
    _roleSub = UserService.currentUserStream().listen((user) {
      if (user == null) return;

      // Initialiser les listeners de notification une seule fois.
      if (!_listenersInit) {
        _listenersInit = true;
        final uid = user.uid;
        NotificationService.initMessagerieListeners(uid);
        if (user.role == UserRole.parent && user.enfantIds.isNotEmpty) {
          NotificationService.initParentListeners(user.enfantIds,
              enfantClasseIds: user.enfantClasseIds);
        }
        if (user.role == UserRole.professeur) {
          NotificationService.initProfesseurListeners(uid);
        }
      }

      // Mettre à jour la navigation uniquement si le rôle change.
      if (user.role != _role) {
        final wasDirection = PermissionService.isDirection(_role);
        final isDirection  = PermissionService.isDirection(user.role);
        setState(() {
          _role = user.role;
          // Réinitialiser l'index si la catégorie change (Direction ↔ autre)
          // pour éviter d'atterrir sur un onglet invalide.
          if (wasDirection != isDirection) _index = 0;
        });
      }
    });
  }

  @override
  void dispose() {
    _roleSub?.cancel();
    SocialService.goOffline();
    NotificationService.disposeParentListeners();
    NotificationService.disposeProfesseurListeners();
    NotificationService.disposeMessagerieListeners();
    super.dispose();
  }

  // ─── Configuration par rôle ───────────────────────────────────────────────

  bool get _isDirection => PermissionService.isDirection(_role);

  List<Widget> get _pages {
    if (_isDirection) {
      return const [
        HomePage(),
        DirectionDashboardPage(),
        EspaceDirectionPage(),
        ProfilePage(),
      ];
    }
    // L'onglet 2 doit pointer vers l'espace propre à chaque rôle : le hub
    // "Espace Étudiant" (ElevesPage) n'a de sens que pour un élève — un
    // professeur y voyait par erreur "Mes devoirs/Mes notes" au lieu de sa
    // liste d'élèves, et un parent y voyait le même hub élève au lieu de
    // l'espace de suivi de son enfant.
    final Widget secondTab = switch (_role) {
      UserRole.professeur => const ProfesseurElevesPage(),
      UserRole.parent => const EspaceParentPage(),
      _ => const ElevesPage(),
    };
    return [
      const HomePage(),
      secondTab,
      const SCOLARConnectPage(),
      const ProfilePage(),
    ];
  }

  List<BottomNavigationBarItem> get _navItems {
    if (_isDirection) {
      return const [
        BottomNavigationBarItem(
          icon: Icon(Icons.home_outlined),
          activeIcon: Icon(Icons.home),
          label: 'Accueil',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.dashboard_outlined),
          activeIcon: Icon(Icons.dashboard),
          label: 'Tableau de bord',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.account_balance_outlined),
          activeIcon: Icon(Icons.account_balance),
          label: 'Gestion',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person_outline),
          activeIcon: Icon(Icons.person),
          label: 'Profil',
        ),
      ];
    }
    return [
      const BottomNavigationBarItem(
        icon: Icon(Icons.home_outlined),
        activeIcon: Icon(Icons.home),
        label: 'Accueil',
      ),
      BottomNavigationBarItem(
        icon: const Icon(Icons.school_outlined),
        activeIcon: const Icon(Icons.school),
        label: switch (_role) {
          UserRole.professeur => 'Élèves',
          UserRole.parent => 'Mon enfant',
          _ => 'Mon espace',
        },
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.hub_outlined),
        activeIcon: Icon(Icons.hub),
        label: 'Réseau',
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.person_outline),
        activeIcon: Icon(Icons.person),
        label: 'Profil',
      ),
    ];
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final safeIndex = _index.clamp(0, 3);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (_index != 0) setState(() => _index = 0);
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0D1117),
        body: IndexedStack(
          index: safeIndex,
          children: _pages,
        ),
        bottomNavigationBar: BottomNavigationBar(
          backgroundColor: const Color(0xFF161B22),
          selectedItemColor: const Color(0xFF6C47FF),
          unselectedItemColor: Colors.white38,
          type: BottomNavigationBarType.fixed,
          selectedFontSize: 11,
          unselectedFontSize: 11,
          currentIndex: safeIndex,
          onTap: (i) => setState(() => _index = i),
          items: _navItems,
        ),
      ),
    );
  }
}
