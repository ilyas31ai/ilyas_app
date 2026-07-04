import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'home_page.dart';
import 'eleves_page.dart';
import 'profile_page.dart';
import 'scolar_connect_page.dart';
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

  static String get _user => FirebaseAuth.instance.currentUser?.email ?? '';

  @override
  void initState() {
    super.initState();
    SocialService.goOnline();
    UserService.syncProfile();
    NotificationService.init(_user);
    _maybeInitRoleListeners();
  }

  void _maybeInitRoleListeners() {
    UserService.currentUserStream().first.then((user) {
      if (user == null) return;
      final uid = user.uid;

      // Messagerie — tous les rôles
      NotificationService.initMessagerieListeners(uid);

      // Rôle parent
      if (user.role == UserRole.parent && user.enfantIds.isNotEmpty) {
        NotificationService.initParentListeners(user.enfantIds);
      }
      // Rôle professeur
      if (user.role == UserRole.professeur) {
        NotificationService.initProfesseurListeners(uid);
      }
    });
  }

  @override
  void dispose() {
    SocialService.goOffline();
    NotificationService.disposeParentListeners();
    NotificationService.disposeProfesseurListeners();
    NotificationService.disposeMessagerieListeners();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (_index != 0) setState(() => _index = 0);
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0D1117),
        body: IndexedStack(
          index: _index,
          children: const [
            HomePage(),
            ElevesPage(),
            SCOLARConnectPage(),
            ProfilePage(),
          ],
        ),
        bottomNavigationBar: BottomNavigationBar(
          backgroundColor: const Color(0xFF161B22),
          selectedItemColor: const Color(0xFF6C47FF),
          unselectedItemColor: Colors.white38,
          type: BottomNavigationBarType.fixed,
          selectedFontSize: 11,
          unselectedFontSize: 11,
          currentIndex: _index,
          onTap: (i) => setState(() => _index = i),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'Accueil',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.school_outlined),
              activeIcon: Icon(Icons.school),
              label: 'Révision',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.hub_outlined),
              activeIcon: Icon(Icons.hub),
              label: 'Connect',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'Profil',
            ),
          ],
        ),
      ),
    );
  }
}
