import 'package:flutter/material.dart';

import '../models/annonce_model.dart';
import '../models/devoir_model.dart';
import '../models/note_model.dart';
import '../models/rdv_model.dart';
import '../models/user_model.dart';
import '../services/etudiant_service.dart';
import '../services/rdv_service.dart';
import '../services/user_service.dart';

class NotificationsPage extends StatelessWidget {
  // currentUser (email) kept for route compatibility; auth handled internally
  final String currentUser;
  const NotificationsPage({super.key, required this.currentUser});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        elevation: 0,
        title: const Text(
          'Notifications',
          style: TextStyle(
              color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
      body: StreamBuilder<UserModel?>(
        stream: UserService.currentUserStream(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF2563EB)),
            );
          }
          final user = snap.data;
          if (user == null) {
            return const Center(
              child: Text('Non connecté',
                  style: TextStyle(color: Colors.white38)),
            );
          }
          return _NotifBody(user: user);
        },
      ),
    );
  }
}

// ── Corps ─────────────────────────────────────────────────────────────────────

class _NotifBody extends StatelessWidget {
  final UserModel user;
  const _NotifBody({required this.user});

  @override
  Widget build(BuildContext context) {
    final classeNom = user.classeNom ?? user.niveau ?? '';
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
      children: [
        _HeaderBanner(role: user.role),
        const SizedBox(height: 20),

        // ── Élève ──────────────────────────────────────────────────────────
        if (user.role == UserRole.eleve) ...[
          _sectionLabel('Notes récentes'),
          const SizedBox(height: 8),
          _NotesSection(classeNom: classeNom),
          const SizedBox(height: 20),
          _sectionLabel('Devoirs à rendre'),
          const SizedBox(height: 8),
          _DevoirsSection(classeNom: classeNom),
          const SizedBox(height: 20),
          _sectionLabel('Annonces'),
          const SizedBox(height: 8),
          const _AnnoncesSection(),
        ],

        // ── Parent ─────────────────────────────────────────────────────────
        if (user.role == UserRole.parent) ...[
          _sectionLabel('Annonces scolaires'),
          const SizedBox(height: 8),
          const _AnnoncesSection(),
          const SizedBox(height: 20),
          const _ParentEspaceCard(),
        ],

        // ── Professeur ─────────────────────────────────────────────────────
        if (user.role == UserRole.professeur) ...[
          _sectionLabel('RDV en attente'),
          const SizedBox(height: 8),
          const _ProfRdvSection(),
          const SizedBox(height: 20),
          _sectionLabel('Annonces'),
          const SizedBox(height: 8),
          const _AnnoncesSection(),
        ],

        // ── Direction / Admin ──────────────────────────────────────────────
        if (user.role == UserRole.admin ||
            user.role == UserRole.direction ||
            user.role == UserRole.adminEtablissement ||
            user.role == UserRole.superAdmin) ...[
          _sectionLabel('Annonces'),
          const SizedBox(height: 8),
          const _AnnoncesSection(),
        ],
      ],
    );
  }

  static Widget _sectionLabel(String text) => Text(
        text.toUpperCase(),
        style: const TextStyle(
            color: Colors.white38,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2),
      );
}

// ── Header banner ─────────────────────────────────────────────────────────────

class _HeaderBanner extends StatelessWidget {
  final UserRole role;
  const _HeaderBanner({required this.role});

  String get _roleLabel {
    switch (role) {
      case UserRole.eleve:
        return 'Espace Élève';
      case UserRole.parent:
        return 'Espace Parent';
      case UserRole.professeur:
        return 'Espace Professeur';
      case UserRole.admin:
      case UserRole.direction:
      case UserRole.adminEtablissement:
      case UserRole.superAdmin:
        return 'Espace Direction';
    }
  }

  List<Color> get _colors {
    switch (role) {
      case UserRole.eleve:
        return [const Color(0xFF2563EB), const Color(0xFF0891B2)];
      case UserRole.parent:
        return [const Color(0xFF6C47FF), const Color(0xFF2563EB)];
      case UserRole.professeur:
        return [const Color(0xFFD97706), const Color(0xFFF59E0B)];
      default:
        return [const Color(0xFF15803D), const Color(0xFF0891B2)];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
            colors: _colors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_roleLabel,
                    style: const TextStyle(color: Colors.white70, fontSize: 12)),
                const Text('Notifications',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold)),
                const Text('Vos dernières activités scolaires',
                    style: TextStyle(color: Colors.white60, fontSize: 12)),
              ],
            ),
          ),
          Icon(Icons.notifications_outlined,
              color: Colors.white.withValues(alpha: 0.2), size: 44),
        ],
      ),
    );
  }
}

// ── Notes section (élève) ─────────────────────────────────────────────────────

class _NotesSection extends StatelessWidget {
  final String classeNom;
  const _NotesSection({required this.classeNom});

  static String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  @override
  Widget build(BuildContext context) {
    if (classeNom.isEmpty) return const _Empty('Classe non assignée');
    return StreamBuilder<List<NoteModel>>(
      stream: EtudiantService.notesStream(classeNom),
      builder: (_, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const _Loading();
        }
        final notes = List<NoteModel>.from(snap.data ?? [])
          ..sort((a, b) => b.date.compareTo(a.date));
        if (notes.isEmpty) return const _Empty('Aucune note récente');
        return Column(
          children: notes.take(5).map((n) {
            final color = n.sur20 >= 14
                ? const Color(0xFF16A34A)
                : n.sur20 >= 10
                    ? const Color(0xFFD97706)
                    : const Color(0xFFDC2626);
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF161B22),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: color.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(n.sur20.toStringAsFixed(1),
                        style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.bold,
                            fontSize: 14)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(n.matiere,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 13)),
                        Text(
                          '${n.intitule.isNotEmpty ? n.intitule : 'Évaluation'} · ${_fmt(n.date)}',
                          style: const TextStyle(
                              color: Colors.white38, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.grade_outlined, color: color, size: 16),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

// ── Devoirs section (élève) ───────────────────────────────────────────────────

class _DevoirsSection extends StatelessWidget {
  final String classeNom;
  const _DevoirsSection({required this.classeNom});

  static String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    if (classeNom.isEmpty) return const _Empty('Classe non assignée');
    final now = DateTime.now();
    return StreamBuilder<List<DevoirModel>>(
      stream: EtudiantService.devoirsStream(classeNom),
      builder: (_, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const _Loading();
        }
        final devoirs = (snap.data ?? [])
            .where((d) => d.dateLimite != null && d.dateLimite!.isAfter(now))
            .toList()
          ..sort((a, b) => a.dateLimite!.compareTo(b.dateLimite!));
        if (devoirs.isEmpty) return const _Empty('Aucun devoir à rendre');
        return Column(
          children: devoirs.take(4).map((d) {
            final days = d.dateLimite!.difference(now).inDays;
            final urgColor = days <= 1
                ? const Color(0xFFDC2626)
                : days <= 3
                    ? const Color(0xFFD97706)
                    : const Color(0xFF2563EB);
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF161B22),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: urgColor.withValues(alpha: 0.25)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: urgColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.assignment_outlined,
                        color: urgColor, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(d.titre,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 13),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        Text(
                          '${d.matiere} · à rendre le ${_fmt(d.dateLimite!)}',
                          style: const TextStyle(
                              color: Colors.white38, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: urgColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('${days}j',
                        style: TextStyle(
                            color: urgColor,
                            fontSize: 11,
                            fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

// ── Annonces section ──────────────────────────────────────────────────────────

class _AnnoncesSection extends StatelessWidget {
  const _AnnoncesSection();

  static String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AnnonceModel>>(
      stream: EtudiantService.annoncesStream(),
      builder: (_, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const _Loading();
        }
        final annonces = snap.data ?? [];
        if (annonces.isEmpty) return const _Empty('Aucune annonce');
        return Column(
          children: annonces.take(5).map((a) {
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF161B22),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.05)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFF6C47FF).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: const Icon(Icons.campaign_outlined,
                        color: Color(0xFF6C47FF), size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(a.titre,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 13),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        Text(_fmt(a.date),
                            style: const TextStyle(
                                color: Colors.white38, fontSize: 11)),
                        if (a.contenu.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(a.contenu,
                              style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 12,
                                  height: 1.4),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

// ── RDV section (professeur) ──────────────────────────────────────────────────

class _ProfRdvSection extends StatelessWidget {
  const _ProfRdvSection();

  static String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<RdvModel>>(
      stream: RdvService.rdvProfesseurStream(),
      builder: (_, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const _Loading();
        }
        final rdvs = (snap.data ?? [])
            .where((r) => r.statut == RdvStatut.demande)
            .toList();
        if (rdvs.isEmpty) return const _Empty('Aucun RDV en attente');
        return Column(
          children: rdvs.take(5).map((r) {
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF161B22),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.event_note_outlined,
                        color: Color(0xFF2563EB), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(r.parentNom,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 13)),
                        Text('Demande de RDV · ${_fmt(r.dateHeure)}',
                            style: const TextStyle(
                                color: Colors.white38, fontSize: 11)),
                        if (r.motif.isNotEmpty)
                          Text(r.motif,
                              style: const TextStyle(
                                  color: Colors.white54, fontSize: 12),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD97706).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('En attente',
                        style: TextStyle(
                            color: Color(0xFFD97706),
                            fontSize: 10,
                            fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

// ── Carte orientation Espace Parent ───────────────────────────────────────────

class _ParentEspaceCard extends StatelessWidget {
  const _ParentEspaceCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: const Color(0xFF6C47FF).withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [Color(0xFF6C47FF), Color(0xFF2563EB)]),
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Icon(Icons.family_restroom_outlined,
                color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Espace Parent',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14)),
                Text(
                  'Suivre les résultats, devoirs et présences de vos enfants',
                  style:
                      TextStyle(color: Colors.white38, fontSize: 12),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: Colors.white24, size: 20),
        ],
      ),
    );
  }
}

// ── Widgets partagés ──────────────────────────────────────────────────────────

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child:
              CircularProgressIndicator(color: Color(0xFF2563EB), strokeWidth: 2),
        ),
      );
}

class _Empty extends StatelessWidget {
  final String message;
  const _Empty(this.message);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        alignment: Alignment.center,
        child: Text(message,
            style: const TextStyle(color: Colors.white38, fontSize: 13)),
      );
}
