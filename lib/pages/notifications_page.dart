import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/annonce_model.dart';
import '../models/devoir_model.dart';
import '../models/note_model.dart';
import '../models/rdv_model.dart';
import '../models/user_model.dart';
import '../services/etudiant_service.dart';
import '../services/parent_service.dart';
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
          if (snap.hasError) {
            return const Center(
              child: Text('Erreur de chargement',
                  style: TextStyle(color: Colors.white38)),
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
          _sectionLabel('Notes récentes'),
          const SizedBox(height: 8),
          _ParentNotesSection(enfantIds: user.enfantIds),
          const SizedBox(height: 20),
          _sectionLabel('Absences & Retards'),
          const SizedBox(height: 8),
          _ParentAbsencesSection(enfantIds: user.enfantIds),
          const SizedBox(height: 20),
          _sectionLabel('Rendez-vous'),
          const SizedBox(height: 8),
          const _ParentRdvSection(),
          const SizedBox(height: 20),
          _sectionLabel('Annonces scolaires'),
          const SizedBox(height: 8),
          const _AnnoncesSection(),
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
      case UserRole.editeur:
        return 'Espace Éditeur';
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
        if (snap.hasError) return const _Empty('Erreur de chargement');
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
        if (snap.hasError) return const _Empty('Erreur de chargement');
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
        if (snap.hasError) return const _Empty('Erreur de chargement');
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
        if (snap.hasError) return const _Empty('Erreur de chargement');
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

// ── Sections parent ───────────────────────────────────────────────────────────

class _ParentNotesSection extends StatefulWidget {
  final List<String> enfantIds;
  const _ParentNotesSection({required this.enfantIds});

  @override
  State<_ParentNotesSection> createState() => _ParentNotesSectionState();
}

class _ParentNotesSectionState extends State<_ParentNotesSection> {
  final _subs = <StreamSubscription>[];
  final _byChild = <String, List<NoteModel>>{};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    if (widget.enfantIds.isEmpty) {
      _loading = false;
      return;
    }
    for (final uid in widget.enfantIds) {
      _subs.add(ParentService.notesEnfantStream(uid).listen((notes) {
        setState(() {
          _byChild[uid] = notes;
          _loading = false;
        });
      }));
    }
  }

  @override
  void dispose() {
    for (final s in _subs) { s.cancel(); }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const _Loading();
    final all = _byChild.values.expand((n) => n).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    if (all.isEmpty) return const _Empty('Aucune note publiée');
    return Column(
      children: all.take(6).map((n) => _ParentNoteCard(note: n)).toList(),
    );
  }
}

class _ParentNoteCard extends StatelessWidget {
  final NoteModel note;
  const _ParentNoteCard({required this.note});

  static String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final color = note.sur20 >= 14
        ? const Color(0xFF16A34A)
        : note.sur20 >= 10
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
            child: Text(note.sur20.toStringAsFixed(1),
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
                Text(note.matiere,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 13)),
                Text(
                  note.eleveNomComplet.isNotEmpty
                      ? '${note.eleveNomComplet} · ${note.intitule.isNotEmpty ? note.intitule : "Évaluation"}'
                      : note.intitule.isNotEmpty
                          ? note.intitule
                          : 'Évaluation',
                  style:
                      const TextStyle(color: Colors.white38, fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Text(_fmt(note.date),
              style:
                  const TextStyle(color: Colors.white24, fontSize: 11)),
        ],
      ),
    );
  }
}

// ── Absences & Retards parent ─────────────────────────────────────────────────

class _ParentAbsencesSection extends StatefulWidget {
  final List<String> enfantIds;
  const _ParentAbsencesSection({required this.enfantIds});

  @override
  State<_ParentAbsencesSection> createState() =>
      _ParentAbsencesSectionState();
}

class _ParentAbsencesSectionState extends State<_ParentAbsencesSection> {
  final _subs = <StreamSubscription>[];
  final _byChild = <String, List<Map<String, dynamic>>>{};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    if (widget.enfantIds.isEmpty) {
      _loading = false;
      return;
    }
    for (final uid in widget.enfantIds) {
      _subs.add(ParentService.presencesEnfantStream(uid).listen((list) {
        setState(() {
          _byChild[uid] = list
              .where((d) =>
                  (d['statut'] as String?) == 'absent' ||
                  (d['statut'] as String?) == 'retard')
              .toList();
          _loading = false;
        });
      }));
    }
  }

  @override
  void dispose() {
    for (final s in _subs) { s.cancel(); }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const _Loading();
    final all = _byChild.values.expand((l) => l).toList()
      ..sort((a, b) =>
          ((b['date'] as String?) ?? '').compareTo((a['date'] as String?) ?? ''));
    if (all.isEmpty) {
      return const _Empty('Aucune absence ni retard enregistré');
    }
    return Column(
      children: all.take(6).map((d) => _ParentAbsenceCard(data: d)).toList(),
    );
  }
}

class _ParentAbsenceCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _ParentAbsenceCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final statut = data['statut'] as String? ?? '';
    final isAbsent = statut == 'absent';
    final color = isAbsent ? const Color(0xFFDC2626) : const Color(0xFFD97706);
    final date = data['date'] as String? ?? '';
    final motif = data['motif'] as String? ?? '';
    final prenom = data['elevePrenom'] as String? ?? '';
    final nom = data['eleveNom'] as String? ?? '';
    final enfantNom = '$prenom $nom'.trim();
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isAbsent ? Icons.cancel_outlined : Icons.schedule_outlined,
              color: color,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isAbsent ? 'Absence' : 'Retard',
                  style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w600,
                      fontSize: 13),
                ),
                if (enfantNom.isNotEmpty)
                  Text(enfantNom,
                      style: const TextStyle(
                          color: Colors.white54, fontSize: 11)),
                if (motif.isNotEmpty)
                  Text(motif,
                      style: const TextStyle(
                          color: Colors.white38, fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          Text(date,
              style: const TextStyle(color: Colors.white24, fontSize: 11)),
        ],
      ),
    );
  }
}

// ── RDV parent ────────────────────────────────────────────────────────────────

class _ParentRdvSection extends StatelessWidget {
  const _ParentRdvSection();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<RdvModel>>(
      stream: ParentService.rdvStream(),
      builder: (_, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const _Loading();
        }
        final rdvs = snap.data ?? [];
        if (rdvs.isEmpty) return const _Empty('Aucun rendez-vous');
        return Column(
          children: rdvs.take(4).map((r) => _ParentRdvCard(rdv: r)).toList(),
        );
      },
    );
  }
}

class _ParentRdvCard extends StatelessWidget {
  final RdvModel rdv;
  const _ParentRdvCard({required this.rdv});

  @override
  Widget build(BuildContext context) {
    final statut = rdv.statut;
    final Color color;
    if (statut == RdvStatut.accepte || statut == RdvStatut.confirme) {
      color = const Color(0xFF16A34A);
    } else if (statut == RdvStatut.refuse || statut == RdvStatut.annule) {
      color = const Color(0xFFDC2626);
    } else if (statut == RdvStatut.proposeAutreDate) {
      color = const Color(0xFFD97706);
    } else {
      color = const Color(0xFF2563EB);
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.event_note_outlined,
                color: Colors.white54, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Prof. ${rdv.professeurNom}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                Text(
                  DateFormat('dd/MM/yyyy – HH:mm').format(rdv.dateHeure),
                  style:
                      const TextStyle(color: Colors.white38, fontSize: 11),
                ),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(statut.label,
                style: TextStyle(
                    color: color,
                    fontSize: 10,
                    fontWeight: FontWeight.bold)),
          ),
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
