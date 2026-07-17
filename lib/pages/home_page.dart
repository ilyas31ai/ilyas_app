import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/annonce_model.dart';
import '../models/classe_model.dart';
import '../models/devoir_model.dart';
import '../models/note_model.dart';
import '../models/submission_model.dart';
import '../models/permission_model.dart';
import '../models/user_model.dart';
import '../routes/app_routes.dart';
import '../services/etudiant_service.dart';
import '../services/notification_service.dart';
import '../services/social_service.dart';
import '../services/user_service.dart';
import '../widgets/user_avatar.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String get _user => FirebaseAuth.instance.currentUser?.email ?? '';
  String get _name {
    if (_profile?.displayName.isNotEmpty == true) return _profile!.displayName;
    final u = _user;
    return u.contains('@') ? u.split('@').first : u;
  }

  UserModel? _profile;
  StreamSubscription<UserModel?>? _sub;

  UserRole get _role => _profile?.role ?? UserRole.eleve;

  /// Cycle de l'élève dérivé du champ `categorie`.
  _Cycle get _cycle {
    switch (_profile?.categorie) {
      case 'Maternelle':
        return _Cycle.maternelle;
      case 'Primaire':
        return _Cycle.primaire;
      case 'Collège':
      case 'College':
        return _Cycle.college;
      case 'Lycée':
      case 'Lycee':
        return _Cycle.lycee;
      case 'Université':
      case 'Universite':
        return _Cycle.universite;
      default:
        return _Cycle.lycee; // fallback
    }
  }

  @override
  void initState() {
    super.initState();
    _sub = UserService.currentUserStream().listen((u) {
      if (mounted) setState(() => _profile = u);
      // Notifications élève — bulletins + corrections devoirs
      if (u?.role == UserRole.eleve &&
          u?.classeId != null &&
          u!.classeId!.isNotEmpty) {
        final year = DateTime.now().month >= 9
            ? DateTime.now().year
            : DateTime.now().year - 1;
        NotificationService.initEleveListeners(u.classeId!, year);
        NotificationService.initEleveSubmissionListeners(u.uid);
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profile = _profile;

    // Tableau de bord complet adapté au cycle pour les élèves connectés
    if (_role == UserRole.eleve && profile != null) {
      return _EleveFullDashboard(
        profile: profile,
        cycle: _cycle,
        userEmail: _user,
        name: _name,
      );
    }

    // Autres rôles (Direction, Professeur, Parent) + état de chargement
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildHeader(context)),
            SliverToBoxAdapter(child: _buildBanner()),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _buildSectionLabel('Navigation rapide'),
                  const SizedBox(height: 10),
                  _buildQuickGrid(context),
                  const SizedBox(height: 22),
                  _buildSectionLabel('Outils'),
                  const SizedBox(height: 10),
                  _buildToolsList(context),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
      child: Row(
        children: [
          UserAvatar(username: _user, radius: 22, showStatus: false),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bonjour, $_name',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  _roleSubtitle,
                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.notifications_outlined, color: Colors.white60),
            onPressed: () => Navigator.pushNamed(context, '/notifications'),
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white30, size: 20),
            onPressed: () async {
              // Fixer le statut hors ligne avant signOut() : une fois
              // déconnecté, FirebaseAuth.instance.currentUser devient null et
              // SocialService.goOffline() ne peut plus retrouver l'utilisateur
              // à mettre à jour, laissant le statut "En ligne" bloqué en RTDB.
              await SocialService.goOffline();
              await FirebaseAuth.instance.signOut();
            },
          ),
        ],
      ),
    );
  }

  String get _roleSubtitle {
    if (PermissionService.isDirection(_role)) return 'SCOLAR AI Educative · Direction';
    if (_role == UserRole.professeur) return 'SCOLAR AI Educative · Professeur';
    if (_role == UserRole.parent) return 'SCOLAR AI Educative · Parent';
    final niveau = _profile?.niveau;
    if (niveau != null && niveau.isNotEmpty) return 'SCOLAR AI Educative · $niveau';
    return 'SCOLAR AI Educative · Élève';
  }

  // ─── Banner ────────────────────────────────────────────────────────────────

  Widget _buildBanner() {
    final (title, subtitle, colors) = _bannerContent;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(subtitle,
                    style: const TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
          Icon(_bannerIcon, color: Colors.white24, size: 52),
        ],
      ),
    );
  }

  (String, String, List<Color>) get _bannerContent {
    if (PermissionService.isDirection(_role)) {
      return (
        'Espace Direction',
        'Pilotage · Inscriptions · Classes',
        [const Color(0xFF6C47FF), const Color(0xFF2563EB)],
      );
    }
    if (_role == UserRole.professeur) {
      return (
        'Espace Professeur',
        'Devoirs · Notes · Présences',
        [const Color(0xFF0F766E), const Color(0xFF0891B2)],
      );
    }
    if (_role == UserRole.parent) {
      return (
        'Espace Parent',
        'Suivi de vos enfants · Résultats · Devoirs',
        [const Color(0xFFBE185D), const Color(0xFF9D174D)],
      );
    }
    // Élève — selon cycle
    return switch (_cycle) {
      _Cycle.maternelle => (
          'Monde des Enfants',
          'Apprentissage par le jeu · Activités créatives',
          [const Color(0xFFBE185D), const Color(0xFF7C3AED)],
        ),
      _Cycle.primaire => (
          'Plateforme scolaire',
          'Jeux éducatifs · Devoirs',
          [const Color(0xFF6C47FF), const Color(0xFF2563EB)],
        ),
      _Cycle.universite => (
          'Espace Étudiant',
          'Ressources · Examens',
          [const Color(0xFF374151), const Color(0xFF1F2937)],
        ),
      _ => (
          'Plateforme scolaire',
          'Devoirs · Notes',
          [const Color(0xFF6C47FF), const Color(0xFF2563EB)],
        ),
    };
  }

  IconData get _bannerIcon {
    if (PermissionService.isDirection(_role)) return Icons.account_balance;
    if (_role == UserRole.professeur) return Icons.school;
    if (_role == UserRole.parent) return Icons.family_restroom;
    if (_cycle == _Cycle.maternelle || _cycle == _Cycle.primaire) {
      return Icons.child_care;
    }
    return Icons.auto_awesome;
  }

  // ─── Quick Grid ────────────────────────────────────────────────────────────

  Widget _buildSectionLabel(String text) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        color: Colors.white38,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildQuickGrid(BuildContext context) {
    final items = _quickItems;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 1.05,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: items.length,
      itemBuilder: (_, i) => _QuickGridCell(item: items[i]),
    );
  }

  List<_QItem> get _quickItems {
    // ── Direction ─────────────────────────────────────────────────────────────
    if (PermissionService.isDirection(_role)) {
      return const [
        _QItem(Icons.account_balance_outlined, 'Gestion',
            [Color(0xFF6C47FF), Color(0xFF2563EB)], '/espace_direction'),
        _QItem(Icons.groups_outlined, 'Élèves',
            [Color(0xFF2563EB), Color(0xFF0891B2)], '/direction_eleves'),
        _QItem(Icons.class_outlined, 'Classes',
            [Color(0xFF0F766E), Color(0xFF0891B2)], '/direction_classes'),
        _QItem(Icons.description_outlined, 'Bulletins',
            [Color(0xFF7C3AED), Color(0xFF6C47FF)], '/direction_bulletins'),
        _QItem(Icons.bar_chart_outlined, 'Statistiques',
            [Color(0xFFD97706), Color(0xFFF59E0B)], '/direction_statistiques'),
        _QItem(Icons.notifications_outlined, 'Alertes',
            [Color(0xFF374151), Color(0xFF4B5563)], '/notifications'),
      ];
    }

    // ── Professeur ────────────────────────────────────────────────────────────
    if (_role == UserRole.professeur) {
      return [
        const _QItem(Icons.school, 'Mon espace',
            [Color(0xFF0F766E), Color(0xFF0891B2)], '/espace_professeur'),
        const _QItem(Icons.notifications, 'Alertes',
            [Color(0xFF374151), Color(0xFF1F2937)], '/notifications'),
      ];
    }

    // ── Parent ────────────────────────────────────────────────────────────────
    if (_role == UserRole.parent) {
      return [
        const _QItem(Icons.family_restroom, 'Mon espace',
            [Color(0xFFBE185D), Color(0xFF9D174D)], '/espace_parent'),
        const _QItem(Icons.notifications, 'Alertes',
            [Color(0xFF374151), Color(0xFF1F2937)], '/notifications'),
      ];
    }

    // ── Élève — adapté au cycle ───────────────────────────────────────────────
    return _eleveItems;
  }

  List<_QItem> get _eleveItems {
    const alertes = _QItem(Icons.notifications, 'Alertes',
        [Color(0xFF374151), Color(0xFF1F2937)], '/notifications');
    const enfants = _QItem(Icons.child_care, 'Enfants',
        [Color(0xFFBE185D), Color(0xFF7C3AED)], '/monde_enfants');
    const jeux = _QItem(Icons.sports_esports, 'Jeux',
        [Color(0xFF7C3AED), Color(0xFF6C47FF)], '/jeux_scolaires');

    return switch (_cycle) {
      _Cycle.maternelle => [enfants, alertes],
      _Cycle.primaire => [enfants, jeux, alertes],
      _Cycle.college => [jeux, alertes],
      _Cycle.lycee => [jeux, alertes],
      _Cycle.universite => [alertes],
    };
  }

  // ─── Tools List ────────────────────────────────────────────────────────────

  Widget _buildToolsList(BuildContext context) {
    final isEleve = _role == UserRole.eleve;
    final isProf = _role == UserRole.professeur;
    final isDirection = PermissionService.isDirection(_role);

    return Column(
      children: [
        if (isEleve)
          _ToolCard(
            icon: Icons.forum_outlined,
            title: 'Contacter mes professeurs',
            subtitle: 'Questions pédagogiques privées',
            colors: const [Color(0xFF2563EB), Color(0xFF6C47FF)],
            onTap: () => Navigator.pushNamed(context, '/scolar_connect'),
          ),
        if (isEleve) const SizedBox(height: 8),
        if (isProf)
          _ToolCard(
            icon: Icons.people_outline,
            title: 'Mes élèves',
            subtitle: 'Gestion et suivi de vos élèves',
            colors: const [Color(0xFF0F766E), Color(0xFF0891B2)],
            onTap: () => Navigator.pushNamed(context, '/eleves'),
          ),
        if (isProf) const SizedBox(height: 8),
        if (isDirection)
          _ToolCard(
            icon: Icons.account_balance_outlined,
            title: 'Espace Direction',
            subtitle: 'Inscriptions · Classes · Élèves · Bulletins',
            colors: const [Color(0xFF6C47FF), Color(0xFF2563EB)],
            onTap: () => Navigator.pushNamed(context, '/espace_direction'),
          ),
        if (isDirection) const SizedBox(height: 8),
        _ToolCard(
          icon: Icons.forum_outlined,
          title: 'Messagerie interne',
          subtitle: 'Messages en temps réel avec tous les contacts',
          colors: const [Color(0xFF2563EB), Color(0xFF6C47FF)],
          onTap: () => Navigator.pushNamed(context, '/messagerie'),
        ),
        const SizedBox(height: 8),
        _ToolCard(
          icon: Icons.chat_bubble_outline,
          title: 'SCOLAR AI Educative',
          subtitle: 'Discussions avec vos contacts',
          colors: const [Color(0xFF374151), Color(0xFF1F2937)],
          onTap: () => Navigator.pushNamed(context, '/scolar_connect'),
        ),
      ],
    );
  }
}

// ─── Cycle enum (interne à la page) ──────────────────────────────────────────

enum _Cycle { maternelle, primaire, college, lycee, universite }

// ─── Quick Grid Cell ──────────────────────────────────────────────────────────

class _QItem {
  final IconData icon;
  final String label;
  final List<Color> colors;
  final String route;
  const _QItem(this.icon, this.label, this.colors, this.route);
}

class _QuickGridCell extends StatelessWidget {
  final _QItem item;
  const _QuickGridCell({required this.item});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.pushNamed(context, item.route),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF161B22),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: item.colors),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(item.icon, color: Colors.white, size: 22),
            ),
            const SizedBox(height: 8),
            Text(
              item.label,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TABLEAU DE BORD ÉLÈVE — adapté au cycle scolaire
// ═══════════════════════════════════════════════════════════════════════════════

class _EleveFullDashboard extends StatelessWidget {
  final UserModel profile;
  final _Cycle cycle;
  final String userEmail;
  final String name;

  const _EleveFullDashboard({
    required this.profile,
    required this.cycle,
    required this.userEmail,
    required this.name,
  });

  String get _classeNom => profile.classeNom ?? profile.niveau ?? '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildHeader(context)),
            SliverToBoxAdapter(child: _CycleBanner(profile: profile, cycle: cycle)),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // ── KPIs ──────────────────────────────────────────────────
                  _EleveKPIs(classeNom: _classeNom, uid: profile.uid, cycle: cycle),
                  const SizedBox(height: 20),
                  // ── Navigation par cycle ───────────────────────────────
                  _sectionLabel('Mon espace'),
                  const SizedBox(height: 10),
                  _CycleNavGrid(cycle: cycle),
                  // ── Cours du jour ──────────────────────────────────────
                  if (_classeNom.isNotEmpty && cycle != _Cycle.maternelle) ...[
                    const SizedBox(height: 20),
                    _sectionLabel('Cours aujourd\'hui'),
                    const SizedBox(height: 10),
                    _EleveCoursDuJour(classeNom: _classeNom),
                  ],
                  // ── Devoirs urgents ────────────────────────────────────
                  if (_classeNom.isNotEmpty && cycle != _Cycle.maternelle) ...[
                    const SizedBox(height: 20),
                    _sectionLabel('Devoirs à rendre'),
                    const SizedBox(height: 10),
                    _EleveDevoirsUrgents(classeNom: _classeNom),
                  ],
                  // ── Dernières notes ────────────────────────────────────
                  if (cycle != _Cycle.maternelle) ...[
                    const SizedBox(height: 20),
                    _sectionLabel('Dernières notes'),
                    const SizedBox(height: 10),
                    _EleveNotesRecentes(uid: profile.uid),
                  ],
                  // ── Annonces ──────────────────────────────────────────
                  const SizedBox(height: 20),
                  _sectionLabel('Annonces'),
                  const SizedBox(height: 10),
                  const _EleveAnnonces(),
                  // ── Outils de communication ───────────────────────────
                  const SizedBox(height: 20),
                  _sectionLabel('Communication'),
                  const SizedBox(height: 10),
                  _EleveCommunicationTools(cycle: cycle),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 4),
      child: Row(
        children: [
          UserAvatar(username: userEmail, radius: 22, showStatus: false),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bonjour, $name',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.bold),
                ),
                Text(
                  profile.niveau != null && profile.niveau!.isNotEmpty
                      ? '${profile.niveau} · ${profile.classeNom ?? ''}'
                      : profile.classeNom ?? 'SCOLAR AI Educative · Élève',
                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.notifications_outlined, color: Colors.white60),
            onPressed: () => Navigator.pushNamed(context, '/notifications'),
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white30, size: 20),
            onPressed: () async {
              // Fixer le statut hors ligne avant signOut() : une fois
              // déconnecté, FirebaseAuth.instance.currentUser devient null et
              // SocialService.goOffline() ne peut plus retrouver l'utilisateur
              // à mettre à jour, laissant le statut "En ligne" bloqué en RTDB.
              await SocialService.goOffline();
              await FirebaseAuth.instance.signOut();
            },
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) => Text(
        text.toUpperCase(),
        style: const TextStyle(
            color: Colors.white38,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2),
      );
}

// ── Bannière cycle ────────────────────────────────────────────────────────────

class _CycleBanner extends StatelessWidget {
  final UserModel profile;
  final _Cycle cycle;
  const _CycleBanner({required this.profile, required this.cycle});

  @override
  Widget build(BuildContext context) {
    final (title, subtitle, colors, icon) = _content;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
            colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(subtitle,
                    style: const TextStyle(color: Colors.white70, fontSize: 12)),
                if ((profile.classeNom ?? '').isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Classe : ${profile.classeNom}',
                      style: const TextStyle(color: Colors.white, fontSize: 11),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Icon(icon, color: Colors.white24, size: 48),
        ],
      ),
    );
  }

  (String, String, List<Color>, IconData) get _content => switch (cycle) {
        _Cycle.maternelle => (
            'Monde des Enfants',
            'Apprendre en s\'amusant chaque jour',
            [const Color(0xFFBE185D), const Color(0xFF7C3AED)],
            Icons.child_care,
          ),
        _Cycle.primaire => (
            'École Primaire',
            'Devoirs · Notes · Jeux',
            [const Color(0xFF16A34A), const Color(0xFF0891B2)],
            Icons.school_outlined,
          ),
        _Cycle.college => (
            'Collège',
            'Matières · Notes · BEM',
            [const Color(0xFF0F766E), const Color(0xFF0891B2)],
            Icons.menu_book_outlined,
          ),
        _Cycle.lycee => (
            'Lycée',
            'Spécialités · BAC · Bulletin',
            [const Color(0xFF6C47FF), const Color(0xFF2563EB)],
            Icons.auto_awesome,
          ),
        _Cycle.universite => (
            'Université',
            'UEs · ECTS · Examens · Stages · Mémoire',
            [const Color(0xFF374151), const Color(0xFF1E3A5F)],
            Icons.account_balance_outlined,
          ),
      };
}

// ── KPIs ──────────────────────────────────────────────────────────────────────

class _EleveKPIs extends StatelessWidget {
  final String classeNom;
  final String uid;
  final _Cycle cycle;
  const _EleveKPIs(
      {required this.classeNom, required this.uid, required this.cycle});

  @override
  Widget build(BuildContext context) {
    final weekday = DateTime.now().weekday;
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.5,
      children: [
        if (cycle != _Cycle.maternelle)
          StreamBuilder<List<EmploiSlot>>(
            stream: classeNom.isNotEmpty
                ? EtudiantService.emploiStream(classeNom)
                : Stream.value([]),
            builder: (_, snap) {
              final count = snap.data
                      ?.where((s) => s.jour == weekday)
                      .length ??
                  0;
              return _KpiCard(
                icon: Icons.schedule_outlined,
                value: '$count',
                label: 'Cours aujourd\'hui',
                colors: const [Color(0xFF2563EB), Color(0xFF0891B2)],
              );
            },
          )
        else
          _KpiCard(
            icon: Icons.child_care,
            value: '🌟',
            label: 'Bonne journée !',
            colors: const [Color(0xFFBE185D), Color(0xFF7C3AED)],
          ),
        StreamBuilder<int>(
          stream: classeNom.isNotEmpty
              ? EtudiantService.devoirsEnAttenteStream(classeNom)
              : Stream.value(0),
          builder: (_, snap) => _KpiCard(
            icon: Icons.assignment_late_outlined,
            value: '${snap.data ?? 0}',
            label: 'Devoirs en attente',
            colors: const [Color(0xFF7C3AED), Color(0xFF6C47FF)],
          ),
        ),
        StreamBuilder<int>(
          stream: EtudiantService.totalNotesStream(classeNom),
          builder: (_, snap) => _KpiCard(
            icon: Icons.grade_outlined,
            value: '${snap.data ?? 0}',
            label: 'Notes publiées',
            colors: const [Color(0xFF15803D), Color(0xFF16A34A)],
          ),
        ),
        StreamBuilder<int>(
          stream: EtudiantService.absencesMonthStream(),
          builder: (_, snap) => _KpiCard(
            icon: Icons.event_busy_outlined,
            value: '${snap.data ?? 0}',
            label: 'Absences ce mois',
            colors: snap.data != null && snap.data! > 0
                ? const [Color(0xFFDC2626), Color(0xFFB91C1C)]
                : const [Color(0xFF374151), Color(0xFF1F2937)],
          ),
        ),
      ],
    );
  }
}

class _KpiCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final List<Color> colors;
  const _KpiCard(
      {required this.icon,
      required this.value,
      required this.label,
      required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.first.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: colors),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(value,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold)),
                Text(label,
                    style: const TextStyle(color: Colors.white38, fontSize: 10),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Grille navigation par cycle ───────────────────────────────────────────────

class _CycleNavItem {
  final IconData icon;
  final String label;
  final String route;
  final List<Color> colors;
  const _CycleNavItem(this.icon, this.label, this.route, this.colors);
}

class _CycleNavGrid extends StatelessWidget {
  final _Cycle cycle;
  const _CycleNavGrid({required this.cycle});

  List<_CycleNavItem> get _items => switch (cycle) {
        _Cycle.maternelle => [
            const _CycleNavItem(Icons.child_care, 'Monde enfants',
                '/monde_enfants', [Color(0xFFBE185D), Color(0xFF7C3AED)]),
            const _CycleNavItem(Icons.sports_esports_outlined, 'Jeux',
                '/jeux_scolaires', [Color(0xFF7C3AED), Color(0xFF6C47FF)]),
            _CycleNavItem(Icons.dashboard_outlined, 'Mon espace',
                AppRoutes.maternelleTableauBord,
                const [Color(0xFFEC4899), Color(0xFF9D174D)]),
            _CycleNavItem(Icons.auto_stories_outlined, 'Histoires',
                AppRoutes.maternelleHistoires,
                const [Color(0xFFF97316), Color(0xFFDC2626)]),
            _CycleNavItem(Icons.music_note_outlined, 'Comptines',
                AppRoutes.maternelleComptines,
                const [Color(0xFF0F766E), Color(0xFF0891B2)]),
            const _CycleNavItem(Icons.notifications_outlined, 'Alertes',
                '/notifications', [Color(0xFF374151), Color(0xFF1F2937)]),
          ],
        _Cycle.primaire => [
            _CycleNavItem(Icons.dashboard_outlined, 'Tableau de bord',
                AppRoutes.primaireTableauBord,
                const [Color(0xFF16A34A), Color(0xFF0891B2)]),
            _CycleNavItem(Icons.assignment_outlined, 'Devoirs',
                AppRoutes.primaireDevoirs,
                const [Color(0xFF6C47FF), Color(0xFF2563EB)]),
            _CycleNavItem(Icons.grade_outlined, 'Notes',
                AppRoutes.primaireNotes,
                const [Color(0xFFD97706), Color(0xFFDC2626)]),
            _CycleNavItem(Icons.description_outlined, 'Bulletin',
                AppRoutes.primaireBulletin,
                const [Color(0xFF15803D), Color(0xFF16A34A)]),
            const _CycleNavItem(Icons.sports_esports_outlined, 'Jeux',
                '/jeux_scolaires', [Color(0xFFBE185D), Color(0xFF7C3AED)]),
          ],
        _Cycle.college => [
            _CycleNavItem(Icons.dashboard_outlined, 'Tableau de bord',
                AppRoutes.collegeTableauBord,
                const [Color(0xFF0F766E), Color(0xFF0891B2)]),
            _CycleNavItem(Icons.book_outlined, 'Matières',
                AppRoutes.collegeMatieres,
                const [Color(0xFF2563EB), Color(0xFF0891B2)]),
            _CycleNavItem(Icons.assignment_outlined, 'Devoirs',
                AppRoutes.collegeDevoirs,
                const [Color(0xFF6C47FF), Color(0xFF2563EB)]),
            _CycleNavItem(Icons.grade_outlined, 'Notes',
                AppRoutes.collegeNotes,
                const [Color(0xFFD97706), Color(0xFFDC2626)]),
            _CycleNavItem(Icons.description_outlined, 'Bulletin',
                AppRoutes.collegeBulletin,
                const [Color(0xFF15803D), Color(0xFF16A34A)]),
            _CycleNavItem(Icons.emoji_events_outlined, 'BEM',
                AppRoutes.collegeBrevet,
                const [Color(0xFFBE185D), Color(0xFF7C3AED)]),
            _CycleNavItem(Icons.how_to_reg_outlined, 'Présences',
                AppRoutes.collegePresences,
                const [Color(0xFF0F766E), Color(0xFF15803D)]),
            _CycleNavItem(Icons.folder_outlined, 'Documents',
                AppRoutes.collegeDocuments,
                const [Color(0xFF1E3A5F), Color(0xFF374151)]),
          ],
        _Cycle.lycee => [
            _CycleNavItem(Icons.dashboard_outlined, 'Tableau de bord',
                AppRoutes.lyceeTableauBord,
                const [Color(0xFF6C47FF), Color(0xFF2563EB)]),
            _CycleNavItem(Icons.book_outlined, 'Matières',
                AppRoutes.lyceeMatieres,
                const [Color(0xFF2563EB), Color(0xFF0891B2)]),
            _CycleNavItem(Icons.assignment_outlined, 'Devoirs',
                AppRoutes.lyceeDevoirs,
                const [Color(0xFF7C3AED), Color(0xFF6C47FF)]),
            _CycleNavItem(Icons.grade_outlined, 'Notes',
                AppRoutes.lyceeNotes,
                const [Color(0xFFD97706), Color(0xFFDC2626)]),
            _CycleNavItem(Icons.description_outlined, 'Bulletin',
                AppRoutes.lyceeBulletin,
                const [Color(0xFF15803D), Color(0xFF16A34A)]),
            _CycleNavItem(Icons.emoji_events_outlined, 'BAC',
                AppRoutes.lyceeBacBlanc,
                const [Color(0xFFBE185D), Color(0xFF9D174D)]),
            _CycleNavItem(Icons.science_outlined, 'Spécialités',
                AppRoutes.lyceeSpecialites,
                const [Color(0xFF0F766E), Color(0xFF0891B2)]),
            _CycleNavItem(Icons.folder_outlined, 'Documents',
                AppRoutes.lyceeDocuments,
                const [Color(0xFF1E3A5F), Color(0xFF374151)]),
          ],
        _Cycle.universite => [
            _CycleNavItem(Icons.dashboard_outlined, 'Tableau de bord',
                AppRoutes.universiteTableauBord,
                const [Color(0xFF374151), Color(0xFF1E3A5F)]),
            _CycleNavItem(Icons.library_books_outlined, 'UEs',
                AppRoutes.universiteUes,
                const [Color(0xFF2563EB), Color(0xFF0891B2)]),
            _CycleNavItem(Icons.quiz_outlined, 'Examens',
                AppRoutes.universiteExamens,
                const [Color(0xFFDC2626), Color(0xFFB91C1C)]),
            _CycleNavItem(Icons.score_outlined, 'ECTS',
                AppRoutes.universiteEcts,
                const [Color(0xFF15803D), Color(0xFF16A34A)]),
            _CycleNavItem(Icons.work_outline, 'Stages',
                AppRoutes.universiteStage,
                const [Color(0xFF6C47FF), Color(0xFF2563EB)]),
            _CycleNavItem(Icons.menu_book_outlined, 'Mémoire',
                AppRoutes.universiteMemoire,
                const [Color(0xFF7C3AED), Color(0xFF6C47FF)]),
            _CycleNavItem(Icons.calendar_view_week_outlined, 'Semestres',
                AppRoutes.universiteSemestres,
                const [Color(0xFF374151), Color(0xFF1E3A5F)]),
            _CycleNavItem(Icons.explore_outlined, 'Parcours',
                AppRoutes.universiteParcours,
                const [Color(0xFF1E3A5F), Color(0xFF0F172A)]),
          ],
      };

  @override
  Widget build(BuildContext context) {
    final items = _items;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 1.0,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: items.length,
      itemBuilder: (ctx, i) {
        final item = items[i];
        return InkWell(
          onTap: () => Navigator.pushNamed(ctx, item.route),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors:
                    item.colors.map((c) => c.withValues(alpha: 0.12)).toList(),
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: item.colors.first.withValues(alpha: 0.3)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(item.icon, color: item.colors.first, size: 26),
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    item.label,
                    style: TextStyle(
                        color: item.colors.first,
                        fontSize: 10,
                        fontWeight: FontWeight.w600),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Cours du jour ─────────────────────────────────────────────────────────────

class _EleveCoursDuJour extends StatelessWidget {
  final String classeNom;
  const _EleveCoursDuJour({required this.classeNom});

  @override
  Widget build(BuildContext context) {
    final weekday = DateTime.now().weekday;
    return StreamBuilder<List<EmploiSlot>>(
      stream: EtudiantService.emploiStream(classeNom),
      builder: (_, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const _LoadingCard();
        }
        final slots =
            (snap.data ?? []).where((s) => s.jour == weekday).toList();
        if (slots.isEmpty) {
          return _emptyCard(Icons.event_available_outlined,
              'Pas de cours aujourd\'hui');
        }
        return Column(
          children: slots
              .map((s) => _CoursTile(slot: s))
              .toList(),
        );
      },
    );
  }
}

class _CoursTile extends StatelessWidget {
  final EmploiSlot slot;
  const _CoursTile({required this.slot});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [Color(0xFF6C47FF), Color(0xFF2563EB)]),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${slot.heureDebut}–${slot.heureFin}',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(slot.matiere,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
                if (slot.salle.isNotEmpty)
                  Text('Salle ${slot.salle}',
                      style: const TextStyle(
                          color: Colors.white38, fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Devoirs urgents ───────────────────────────────────────────────────────────

class _EleveDevoirsUrgents extends StatelessWidget {
  final String classeNom;
  const _EleveDevoirsUrgents({required this.classeNom});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<DevoirModel>>(
      stream: EtudiantService.devoirsStream(classeNom),
      builder: (_, dSnap) => StreamBuilder<List<SubmissionModel>>(
        stream: EtudiantService.submissionsStream(),
        builder: (_, sSnap) {
          if (dSnap.connectionState == ConnectionState.waiting) {
            return const _LoadingCard();
          }
          final submitted =
              (sSnap.data ?? []).map((s) => s.assignmentId).toSet();
          final now = DateTime.now();
          // Devoirs non remis, triés par date limite
          final pending = (dSnap.data ?? [])
              .where((d) => !submitted.contains(d.id))
              .toList()
            ..sort((a, b) {
              if (a.dateLimite == null && b.dateLimite == null) return 0;
              if (a.dateLimite == null) return 1;
              if (b.dateLimite == null) return -1;
              return a.dateLimite!.compareTo(b.dateLimite!);
            });
          if (pending.isEmpty) {
            return _emptyCard(
                Icons.assignment_turned_in_outlined, 'Tous les devoirs remis');
          }
          return Column(
            children: pending.take(3).map((d) {
              final isLate = d.dateLimite != null && d.dateLimite!.isBefore(now);
              final isSoon = d.dateLimite != null &&
                  !isLate &&
                  d.dateLimite!.difference(now).inDays <= 2;
              return _DevoirUrgentTile(
                  devoir: d, isLate: isLate, isSoon: isSoon);
            }).toList(),
          );
        },
      ),
    );
  }
}

class _DevoirUrgentTile extends StatelessWidget {
  final DevoirModel devoir;
  final bool isLate;
  final bool isSoon;
  const _DevoirUrgentTile(
      {required this.devoir, required this.isLate, required this.isSoon});

  @override
  Widget build(BuildContext context) {
    final borderColor = isLate
        ? Colors.red.withValues(alpha: 0.4)
        : isSoon
            ? Colors.orange.withValues(alpha: 0.4)
            : Colors.white.withValues(alpha: 0.05);
    final statusColor =
        isLate ? Colors.red : isSoon ? Colors.orange : Colors.white38;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: const Color(0xFF1E3A5F),
            child: Text(
              devoir.matiere.isNotEmpty ? devoir.matiere[0] : '?',
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(devoir.titre,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                Text(devoir.matiere,
                    style: const TextStyle(
                        color: Colors.white38, fontSize: 11)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (devoir.dateLimite != null)
                Text(
                  '${devoir.dateLimite!.day}/${devoir.dateLimite!.month}',
                  style: TextStyle(color: statusColor, fontSize: 11),
                ),
              if (isLate)
                Text('En retard',
                    style: TextStyle(
                        color: statusColor,
                        fontSize: 9,
                        fontWeight: FontWeight.bold))
              else if (isSoon)
                Text('Urgent',
                    style: TextStyle(
                        color: statusColor,
                        fontSize: 9,
                        fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Dernières notes ────────────────────────────────────────────────────────────

class _EleveNotesRecentes extends StatelessWidget {
  final String uid;
  const _EleveNotesRecentes({required this.uid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<NoteModel>>(
      stream: EtudiantService.notesStream(''),
      builder: (_, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const _LoadingCard();
        }
        final notes = (snap.data ?? []).take(4).toList();
        if (notes.isEmpty) {
          return _emptyCard(Icons.grade_outlined, 'Aucune note publiée');
        }
        // Moyenne générale
        final moy = notes.fold<double>(0, (s, n) => s + n.sur20) /
            notes.length;
        return Column(
          children: [
            // Barre de moyenne
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF161B22),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Text('Moyenne générale :',
                      style: TextStyle(color: Colors.white54, fontSize: 12)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _moyColor(moy).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${moy.toStringAsFixed(2)} / 20',
                      style: TextStyle(
                          color: _moyColor(moy),
                          fontWeight: FontWeight.bold,
                          fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            ...notes.map((n) => _NoteTile(note: n)),
          ],
        );
      },
    );
  }

  Color _moyColor(double m) =>
      m >= 14 ? Colors.green : m >= 10 ? Colors.amber : Colors.red;
}

class _NoteTile extends StatelessWidget {
  final NoteModel note;
  const _NoteTile({required this.note});

  @override
  Widget build(BuildContext context) {
    final color = note.sur20 >= 14
        ? Colors.green
        : note.sur20 >= 10
            ? Colors.amber
            : Colors.red;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(note.sur20.toStringAsFixed(1),
                style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 13)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(note.intitule,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                Text(note.matiere,
                    style: const TextStyle(
                        color: Colors.white38, fontSize: 11)),
              ],
            ),
          ),
          const Text('/20',
              style: TextStyle(color: Colors.white38, fontSize: 11)),
        ],
      ),
    );
  }
}

// ── Annonces ──────────────────────────────────────────────────────────────────

class _EleveAnnonces extends StatelessWidget {
  const _EleveAnnonces();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AnnonceModel>>(
      stream: EtudiantService.annoncesStream(),
      builder: (_, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const _LoadingCard();
        }
        final annonces = (snap.data ?? []).take(2).toList();
        if (annonces.isEmpty) {
          return _emptyCard(Icons.campaign_outlined, 'Aucune annonce');
        }
        return Column(
          children: annonces.map((a) => _AnnonceTile(annonce: a)).toList(),
        );
      },
    );
  }
}

class _AnnonceTile extends StatelessWidget {
  final AnnonceModel annonce;
  const _AnnonceTile({required this.annonce});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.pushNamed(context, '/etudiant_annonces'),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: const Color(0xFF161B22),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: const Color(0xFF2563EB).withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.campaign_outlined,
                    color: Color(0xFF2563EB), size: 14),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(annonce.titre,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(annonce.contenu,
                style: const TextStyle(color: Colors.white54, fontSize: 11),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}

// ── Outils de communication ───────────────────────────────────────────────────

class _EleveCommunicationTools extends StatelessWidget {
  final _Cycle cycle;
  const _EleveCommunicationTools({required this.cycle});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (cycle != _Cycle.maternelle)
          _CommCard(
            icon: Icons.forum_outlined,
            title: 'Contacter mes professeurs',
            subtitle: 'Questions pédagogiques privées',
            colors: const [Color(0xFF2563EB), Color(0xFF6C47FF)],
            onTap: () => Navigator.pushNamed(context, '/scolar_connect'),
          ),
        const SizedBox(height: 8),
        _CommCard(
          icon: Icons.forum_outlined,
          title: 'Messagerie interne',
          subtitle: 'Messages en temps réel avec tous les contacts',
          colors: const [Color(0xFF2563EB), Color(0xFF6C47FF)],
          onTap: () => Navigator.pushNamed(context, '/messagerie'),
        ),
        const SizedBox(height: 8),
        _CommCard(
          icon: Icons.chat_bubble_outline,
          title: 'SCOLAR AI Educative',
          subtitle: 'Discussions avec vos contacts',
          colors: const [Color(0xFF374151), Color(0xFF1F2937)],
          onTap: () => Navigator.pushNamed(context, '/scolar_connect'),
        ),
      ],
    );
  }
}

class _CommCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final List<Color> colors;
  final VoidCallback onTap;
  const _CommCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: const Color(0xFF161B22),
          borderRadius: BorderRadius.circular(12),
          border:
              Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: colors),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14)),
                  Text(subtitle,
                      style: const TextStyle(
                          color: Colors.white38, fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white24, size: 20),
          ],
        ),
      ),
    );
  }
}

// ── Helpers partagés ──────────────────────────────────────────────────────────

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();
  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 16),
      child: Center(
          child: CircularProgressIndicator(
              color: Color(0xFF2563EB), strokeWidth: 2)),
    );
  }
}

Widget _emptyCard(IconData icon, String msg) => Container(
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.white24, size: 32),
          const SizedBox(height: 6),
          Text(msg, style: const TextStyle(color: Colors.white38, fontSize: 12)),
        ],
      ),
    );

// ─── Tool Card ────────────────────────────────────────────────────────────────

class _ToolCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final List<Color> colors;
  final VoidCallback onTap;

  const _ToolCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: const Color(0xFF161B22),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: colors),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14)),
                  Text(subtitle,
                      style:
                          const TextStyle(color: Colors.white38, fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white24, size: 20),
          ],
        ),
      ),
    );
  }
}
