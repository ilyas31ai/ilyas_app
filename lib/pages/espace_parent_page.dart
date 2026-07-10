import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/bulletin_validation_model.dart';
import '../models/devoir_model.dart';
import '../models/document_model.dart';
import '../models/note_model.dart';
import '../models/rdv_model.dart';
import '../models/user_model.dart';
import '../services/bulletin_validation_service.dart';
import '../services/maitrise_service.dart';
import '../services/parent_service.dart';
import '../services/user_service.dart';
import 'messagerie_page.dart';
import 'eleve_releve_notes_page.dart';

Future<void> _runRdvAction(BuildContext context, Future<void> Function() action) async {
  try {
    await action();
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Erreur : $e'),
        backgroundColor: const Color(0xFFDC2626),
      ));
    }
  }
}

class EspaceParentPage extends StatelessWidget {
  const EspaceParentPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        elevation: 0,
        title: const Text(
          'Espace Parent',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: StreamBuilder<UserModel?>(
        stream: UserService.currentUserStream(),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final user = snap.data;
          if (user == null || user.role != UserRole.parent) {
            return _centered(
              Icons.family_restroom,
              'Cet espace est réservé aux parents.',
            );
          }
          if (user.enfantIds.isEmpty) {
            return _NoEnfantLinkedView(parentUid: user.uid);
          }
          // Un seul enfant : vue directe. Plusieurs : sélecteur en haut.
          if (user.enfantIds.length == 1) {
            return _EnfantView(uid: user.enfantIds.first);
          }
          return _MultiEnfantView(enfantIds: user.enfantIds);
        },
      ),
    );
  }

  static Widget _centered(IconData icon, String msg) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white24, size: 56),
              const SizedBox(height: 16),
              Text(msg,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white54, fontSize: 15)),
            ],
          ),
        ),
      );
}

// ── Aucun enfant lié : ressaisie de l'email pour relancer le rattachement ────
// Couvre le cas où le rattachement automatique à l'inscription (email non
// encore reconnu, faute de frappe, enfant pas encore inscrit à ce moment-là)
// a échoué silencieusement : le parent peut réessayer lui-même sans dépendre
// uniquement d'une intervention manuelle de la Direction.
class _NoEnfantLinkedView extends StatefulWidget {
  final String parentUid;
  const _NoEnfantLinkedView({required this.parentUid});

  @override
  State<_NoEnfantLinkedView> createState() => _NoEnfantLinkedViewState();
}

class _NoEnfantLinkedViewState extends State<_NoEnfantLinkedView> {
  final _emailCtrl = TextEditingController();
  bool _loading = false;
  String? _message;
  bool _success = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _retry() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) return;
    setState(() {
      _loading = true;
      _message = null;
    });
    final linked =
        await UserService.linkParentToChildByEmail(widget.parentUid, email);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _success = linked;
      _message = linked
          ? 'Enfant relié avec succès !'
          : "Aucun élève trouvé avec cet email, ou son compte n'est pas "
              "encore créé. Vérifiez l'orthographe ou contactez la Direction.";
    });
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.child_care_outlined,
                color: Colors.white24, size: 56),
            const SizedBox(height: 16),
            const Text(
              "Aucun enfant lié à votre compte.\n"
              "Saisissez l'email utilisé par votre enfant pour le relier, "
              "ou contactez la Direction de l'établissement.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54, fontSize: 15),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _emailCtrl,
              enabled: !_loading,
              keyboardType: TextInputType.emailAddress,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Email de votre enfant',
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: const Color(0xFF161B22),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _retry,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFBE185D),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: _loading
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      )
                    : const Text('Relier mon enfant',
                        style: TextStyle(color: Colors.white)),
              ),
            ),
            if (_message != null) ...[
              const SizedBox(height: 14),
              Text(
                _message!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _success
                      ? const Color(0xFF16A34A)
                      : const Color(0xFFEF4444),
                  fontSize: 13,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Sélecteur multi-enfants ───────────────────────────────────────────────────

class _MultiEnfantView extends StatefulWidget {
  final List<String> enfantIds;
  const _MultiEnfantView({required this.enfantIds});
  @override
  State<_MultiEnfantView> createState() => _MultiEnfantViewState();
}

class _MultiEnfantViewState extends State<_MultiEnfantView> {
  int _selected = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Sélecteur horizontal
        SizedBox(
          height: 48,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            itemCount: widget.enfantIds.length,
            itemBuilder: (ctx, i) => _ChildChip(
              uid: widget.enfantIds[i],
              selected: i == _selected,
              onTap: () => setState(() => _selected = i),
            ),
          ),
        ),
        Expanded(child: _EnfantView(uid: widget.enfantIds[_selected])),
      ],
    );
  }
}

class _ChildChip extends StatelessWidget {
  final String uid;
  final bool selected;
  final VoidCallback onTap;
  const _ChildChip({required this.uid, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
      builder: (ctx, snap) {
        final raw = (snap.hasData && snap.data!.exists)
            ? snap.data!.data() as Map<String, dynamic>?
            : null;
        final name = (raw?['displayName'] as String?) ?? (snap.hasData ? '?' : '…');
        return GestureDetector(
          onTap: onTap,
          child: Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: selected ? const Color(0xFF2563EB) : const Color(0xFF161B22),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: selected ? const Color(0xFF2563EB) : Colors.white12,
              ),
            ),
            child: Text(name,
                style: TextStyle(
                    color: selected ? Colors.white : Colors.white54,
                    fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 13)),
          ),
        );
      },
    );
  }
}

// ── Vue complète d'un enfant — branchement par cycle ────────────────────────

class _EnfantView extends StatelessWidget {
  final String uid;
  const _EnfantView({required this.uid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<UserModel?>(
      stream: ParentService.enfantStream(uid),
      builder: (ctx, snap) {
        if (snap.hasError) {
          return EspaceParentPage._centered(
            Icons.error_outline,
            'Impossible de charger le profil de votre enfant.\n'
            'Vérifiez votre connexion et réessayez.',
          );
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final enfant = snap.data;
        if (enfant == null) {
          return EspaceParentPage._centered(
            Icons.person_off_outlined,
            "Le profil de cet enfant est introuvable.\n"
            "Contactez la Direction de l'établissement.",
          );
        }

        switch (enfant.categorie) {
          case 'Maternelle':
            return _MaternelleParentView(enfant: enfant);
          case 'Collège':
            return _CollegeParentView(enfant: enfant);
          case 'Lycée':
            return _LyceeParentView(enfant: enfant);
          default:
            return _ClassiqueParentView(enfant: enfant);
        }
      },
    );
  }
}

// ── Vue classique (Primaire / Collège / Lycée / Université) — 7 onglets ──────

class _ClassiqueParentView extends StatelessWidget {
  final UserModel enfant;
  const _ClassiqueParentView({required this.enfant});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 8,
      child: Column(
        children: [
          _EnfantHeader(enfant: enfant),
          const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            indicatorColor: Color(0xFF2563EB),
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white38,
            labelStyle: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            tabs: [
              Tab(text: 'Résumé'),
              Tab(text: 'Bulletins'),
              Tab(text: 'Devoirs'),
              Tab(text: 'Documents'),
              Tab(text: 'Emploi du temps'),
              Tab(text: 'Présences'),
              Tab(text: 'RDV'),
              Tab(text: 'Messages'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _ResumeTab(uid: enfant.uid, classeNom: enfant.classeNom ?? '', classeId: enfant.classeId ?? ''),
                _BulletinsParentTab(enfantUid: enfant.uid, enfantNom: enfant.displayName, classeId: enfant.classeId ?? ''),
                _DevoirsTab(classeNom: enfant.classeNom ?? ''),
                _ParentDocumentsTab(classeNom: enfant.classeNom ?? ''),
                _EmploiTab(classeId: enfant.classeId ?? ''),
                _PresencesTab(enfantUid: enfant.uid),
                _RdvTab(enfant: enfant),
                _DiscussionTab(classeId: enfant.classeId ?? ''),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Vue Maternelle — 5 onglets spécialisés ───────────────────────────────────

class _MaternelleParentView extends StatelessWidget {
  final UserModel enfant;
  const _MaternelleParentView({required this.enfant});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5,
      child: Column(
        children: [
          _EnfantHeader(enfant: enfant, accentColor: const Color(0xFFEC4899)),
          TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            indicatorColor: const Color(0xFFEC4899),
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white38,
            labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            tabs: const [
              Tab(text: 'Journée'),
              Tab(text: 'Cahier de vie'),
              Tab(text: 'Compétences'),
              Tab(text: 'Ressources'),
              Tab(text: 'Contact'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _ParentJourneeTab(enfantUid: enfant.uid),
                _ParentCahierVieTab(enfantUid: enfant.uid),
                _ParentCompetencesTab(enfantUid: enfant.uid),
                const _ParentRessourcesTab(),
                _ParentContactTab(enfant: enfant),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _EnfantHeader extends StatelessWidget {
  final UserModel enfant;
  final Color accentColor;
  const _EnfantHeader({
    required this.enfant,
    this.accentColor = const Color(0xFF2563EB),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF161B22),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: const Color(0xFF1E3A5F),
            radius: 20,
            child: Text(
              enfant.displayName.isNotEmpty ? enfant.displayName[0].toUpperCase() : '?',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(enfant.displayName,
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                if (enfant.classeNom != null)
                  Text(enfant.classeNom!,
                      style: const TextStyle(color: Colors.white54, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Onglet 1 : Résumé ────────────────────────────────────────────────────────

class _ResumeTab extends StatelessWidget {
  final String uid;
  final String classeNom;
  final String classeId;
  const _ResumeTab({required this.uid, this.classeNom = '', this.classeId = ''});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _LivePresenceBanner(enfantUid: uid),
        _ProchainCours(classeId: classeId),
        _SectionTitle('Suivi pédagogique IA'),
        _MaitriseCard(uid: uid),
        const SizedBox(height: 16),
        _SectionTitle('Notes récentes'),
        _NotesCard(uid: uid),
        const SizedBox(height: 16),
        _SectionTitle('Activité récente'),
        _ActivityFeed(enfantUid: uid, classeNom: classeNom, classeId: classeId),
      ],
    );
  }
}

class _MaitriseCard extends StatelessWidget {
  final String uid;
  const _MaitriseCard({required this.uid});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: MaitriseService.summaryForUser(uid),
      builder: (ctx, snap) {
        if (snap.hasError) {
          return const _Card(
            child: Text('Données de progression indisponibles.',
                style: TextStyle(color: Colors.white38)),
          );
        }
        if (!snap.hasData) {
          return const _Card(child: Center(child: CircularProgressIndicator()));
        }
        final summary = snap.data ?? {};
        final totaux = summary['totaux'] as Map? ?? {};
        final maitrise = (totaux['maitrise'] as num?)?.toInt() ?? 0;
        final enCours = (totaux['enCours'] as num?)?.toInt() ?? 0;
        final aRetrav = (totaux['aRetravailler'] as num?)?.toInt() ?? 0;
        final total = (totaux['total'] as num?)?.toInt() ?? 0;
        final pct = (totaux['pct'] as num?)?.toInt() ?? 0;
        if (total == 0) {
          return const _Card(
            child: Text('Pas encore de données de révision IA.',
                style: TextStyle(color: Colors.white38)),
          );
        }

        final parMatiere = summary['parMatiere'] as Map? ?? {};
        final alertes = <String>[];
        for (final entry in parMatiere.entries) {
          final m = entry.value as Map? ?? {};
          final ma = List<String>.from(m['alertes'] as List? ?? []);
          alertes.addAll(ma.map((a) => '${entry.key}: $a'));
        }

        return _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                _StatBadge('🟢 $maitrise', Colors.green.shade900),
                const SizedBox(width: 8),
                _StatBadge('🟡 $enCours', Colors.amber.shade900),
                const SizedBox(width: 8),
                _StatBadge('🔴 $aRetrav', Colors.red.shade900),
                const Spacer(),
                Text('$pct% maîtrisé',
                    style: const TextStyle(color: Colors.white54, fontSize: 12)),
              ]),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: total > 0 ? maitrise / total : 0,
                  backgroundColor: Colors.white10,
                  color: Colors.green,
                  minHeight: 6,
                ),
              ),
              if (alertes.isNotEmpty) ...[
                const SizedBox(height: 10),
                ...alertes.take(3).map((a) => Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text('• $a',
                          style: const TextStyle(color: Colors.red, fontSize: 11),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    )),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _NotesCard extends StatelessWidget {
  final String uid;
  const _NotesCard({required this.uid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<NoteModel>>(
      stream: ParentService.notesEnfantStream(uid),
      builder: (ctx, snap) {
        if (snap.hasError) {
          return const _Card(
            child: Text('Impossible de charger les notes.',
                style: TextStyle(color: Colors.redAccent)),
          );
        }
        final notes = snap.data ?? [];
        if (notes.isEmpty && snap.hasData) {
          return const _Card(
            child: Text('Aucune note publiée.',
                style: TextStyle(color: Colors.white38)),
          );
        }
        return _Card(
          child: Column(
            children: [
              ...notes.take(5).map((n) => _NoteRow(note: n)),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  onPressed: () => Navigator.push(
                    ctx,
                    MaterialPageRoute<void>(
                      builder: (_) => EleveReleveNotesPage(
                        eleveUid: uid,
                        eleveNom: notes.isNotEmpty
                            ? '${notes.first.elevePrenom} ${notes.first.eleveNom}'.trim()
                            : null,
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.description_outlined, size: 15),
                  label: const Text('Voir le bulletin complet',
                      style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF6C47FF),
                    backgroundColor: const Color(0xFF6C47FF).withValues(alpha: 0.08),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(
                        vertical: 8, horizontal: 12),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Onglet 2 : Devoirs ────────────────────────────────────────────────────────

class _DevoirsTab extends StatelessWidget {
  final String classeNom;
  const _DevoirsTab({required this.classeNom});

  @override
  Widget build(BuildContext context) {
    if (classeNom.isEmpty) {
      return const Center(
        child: Text('Classe non disponible.', style: TextStyle(color: Colors.white38)),
      );
    }
    return StreamBuilder<List<DevoirModel>>(
      stream: ParentService.devoirsEnfantStream(classeNom),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return const Center(
            child: Text('Impossible de charger les devoirs.',
                style: TextStyle(color: Colors.redAccent)),
          );
        }
        final devoirs = snap.data ?? [];
        if (devoirs.isEmpty) {
          return const Center(
            child: Text('Aucun devoir pour cette classe.',
                style: TextStyle(color: Colors.white38)),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: devoirs.length,
          itemBuilder: (ctx, i) => _DevoirTile(devoir: devoirs[i]),
        );
      },
    );
  }
}

class _DevoirTile extends StatelessWidget {
  final DevoirModel devoir;
  const _DevoirTile({required this.devoir});

  @override
  Widget build(BuildContext context) {
    final overdue = devoir.dateLimite != null &&
        devoir.dateLimite!.isBefore(DateTime.now());
    return Card(
      color: const Color(0xFF161B22),
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor:
              overdue ? Colors.red.shade900 : const Color(0xFF1E3A5F),
          child: Text(
            devoir.matiere.isNotEmpty ? devoir.matiere[0] : '?',
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ),
        title: Text(devoir.titre,
            style: const TextStyle(color: Colors.white, fontSize: 14)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(devoir.matiere,
                style: const TextStyle(color: Colors.white54, fontSize: 12)),
            if (devoir.dateLimite != null)
              Text(
                'Pour le ${DateFormat('dd/MM/yyyy').format(devoir.dateLimite!)}',
                style: TextStyle(
                  color: overdue ? Colors.red : Colors.white38,
                  fontSize: 11,
                ),
              ),
          ],
        ),
        trailing: devoir.estInteractif
            ? const Icon(Icons.quiz_outlined, color: Colors.blue, size: 18)
            : devoir.aFichier
                ? const Icon(Icons.picture_as_pdf_outlined,
                    color: Colors.orange, size: 18)
                : null,
      ),
    );
  }
}

// ── Onglet 3 (Classique) : Documents ─────────────────────────────────────────

class _ParentDocumentsTab extends StatelessWidget {
  final String classeNom;
  const _ParentDocumentsTab({required this.classeNom});

  @override
  Widget build(BuildContext context) {
    if (classeNom.isEmpty) {
      return const Center(
        child: Text('Classe non disponible.',
            style: TextStyle(color: Colors.white38)),
      );
    }
    // NOTE : utilise ParentService.documentsEnfantStream (collection
    // `documents_prof`), la même source que l'espace Professeur/Élève.
    // Cet onglet interrogeait auparavant une collection `documents` inexistante
    // dans les règles Firestore (accès refusé en silence) et lisait un champ
    // `url` qui n'a jamais existé (le champ réel est `fichierUrl`) : le résultat
    // était un onglet Documents systématiquement vide pour tous les parents.
    return StreamBuilder<List<DocumentPedagogique>>(
      stream: ParentService.documentsEnfantStream(classeNom),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return const Center(
            child: Text('Impossible de charger les documents.',
                style: TextStyle(color: Colors.redAccent)),
          );
        }
        final docs = snap.data ?? [];
        if (docs.isEmpty) {
          return const Center(
            child: Text('Aucun document partagé.',
                style: TextStyle(color: Colors.white38)),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (ctx, i) {
            final d = docs[i];
            final titre = d.titre.isNotEmpty ? d.titre : 'Document';
            final sousTitre = [d.matiere, d.type]
                .where((s) => s.isNotEmpty)
                .join(' · ');
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF161B22),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.picture_as_pdf_outlined,
                      color: Color(0xFFF97316), size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(titre,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 13),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis),
                        if (sousTitre.isNotEmpty)
                          Text(sousTitre,
                              style: const TextStyle(
                                  color: Colors.white38, fontSize: 11)),
                      ],
                    ),
                  ),
                  if (d.fichierUrl.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.open_in_new,
                          color: Color(0xFF2563EB), size: 18),
                      onPressed: () async {
                        final uri = Uri.tryParse(d.fichierUrl);
                        if (uri != null) await launchUrl(uri);
                      },
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

// ── Onglet 3 : Emploi du temps ────────────────────────────────────────────────

class _EmploiTab extends StatelessWidget {
  final String classeId;
  const _EmploiTab({required this.classeId});

  @override
  Widget build(BuildContext context) {
    if (classeId.isEmpty) {
      return const Center(
        child: Text('Classe non disponible.', style: TextStyle(color: Colors.white38)),
      );
    }
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: ParentService.emploiEnfantStream(classeId),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return const Center(
            child: Text("Impossible de charger l'emploi du temps.",
                style: TextStyle(color: Colors.redAccent)),
          );
        }
        final slots = snap.data ?? [];
        if (slots.isEmpty) {
          return const Center(
            child: Text("Emploi du temps non disponible.",
                style: TextStyle(color: Colors.white38)),
          );
        }

        // Regrouper par jour
        final Map<String, List<Map<String, dynamic>>> byJour = {};
        for (final s in slots) {
          final jour = (s['jour'] as String?) ?? 'Autre';
          (byJour[jour] ??= []).add(s);
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: byJour.entries.map((e) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(e.key,
                      style: const TextStyle(
                          color: Color(0xFF2563EB),
                          fontWeight: FontWeight.bold,
                          fontSize: 14)),
                ),
                ...e.value.map((s) => _SlotTile(slot: s)),
                const SizedBox(height: 4),
              ],
            );
          }).toList(),
        );
      },
    );
  }
}

class _SlotTile extends StatelessWidget {
  final Map<String, dynamic> slot;
  const _SlotTile({required this.slot});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Text(
            '${slot['heureDebut'] ?? ''} – ${slot['heureFin'] ?? ''}',
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text((slot['matiere'] as String?) ?? '',
                style: const TextStyle(color: Colors.white, fontSize: 13)),
          ),
          if ((slot['salle'] as String?)?.isNotEmpty == true)
            Text('Salle ${slot['salle']}',
                style: const TextStyle(color: Colors.white38, fontSize: 11)),
        ],
      ),
    );
  }
}

// ── Onglet 4 : Présences ─────────────────────────────────────────────────────

class _PresencesTab extends StatelessWidget {
  final String enfantUid;
  const _PresencesTab({required this.enfantUid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: ParentService.presencesEnfantStream(enfantUid),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return const Center(
            child: Text('Impossible de charger les présences.',
                style: TextStyle(color: Colors.redAccent)),
          );
        }

        final incidents = (snap.data ?? [])
            .where((d) {
              final s = (d['statut'] as String?) ?? '';
              return s == 'absent' || s == 'retard';
            })
            .toList();

        if (incidents.isEmpty && snap.hasData) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle_outline, color: Colors.green, size: 48),
                  SizedBox(height: 12),
                  Text('Aucune absence ou retard enregistré.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white54)),
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: incidents.length,
          itemBuilder: (ctx, i) {
            final inc = incidents[i];
            final isAbsent = (inc['statut'] as String?) == 'absent';
            final motif = (inc['motif'] as String?) ?? '';
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF161B22),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isAbsent
                      ? Colors.red.withValues(alpha: 0.3)
                      : Colors.orange.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isAbsent ? Icons.cancel_outlined : Icons.schedule,
                    color: isAbsent ? Colors.red : Colors.orange,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text((inc['date'] as String?) ?? '',
                            style: const TextStyle(
                                color: Colors.white, fontWeight: FontWeight.w500)),
                        Text(
                          isAbsent ? 'Absent(e)' : 'Retard',
                          style: TextStyle(
                              color: isAbsent ? Colors.red : Colors.orange,
                              fontSize: 12),
                        ),
                        if (motif.isNotEmpty)
                          Text(motif,
                              style: const TextStyle(
                                  color: Colors.white38, fontSize: 11)),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

// ── Onglet 5 : RDV ───────────────────────────────────────────────────────────

class _RdvTab extends StatelessWidget {
  final UserModel enfant;
  const _RdvTab({required this.enfant});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<RdvModel>>(
      stream: ParentService.rdvStream(),
      builder: (ctx, snap) {
        final rdvList = snap.data ?? [];
        final enfantRdv =
            rdvList.where((r) => r.eleveUid == enfant.uid).toList();

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.add_circle_outline, size: 18),
              label: const Text('Demander un rendez-vous'),
              onPressed: () => _showRdvForm(context),
            ),
            const SizedBox(height: 16),
            if (snap.hasError)
              const Center(
                child: Padding(
                  padding: EdgeInsets.only(top: 32),
                  child: Text('Impossible de charger vos rendez-vous.',
                      style: TextStyle(color: Colors.redAccent)),
                ),
              )
            else if (enfantRdv.isEmpty && snap.hasData)
              const Center(
                child: Padding(
                  padding: EdgeInsets.only(top: 32),
                  child: Text('Aucun rendez-vous.',
                      style: TextStyle(color: Colors.white38)),
                ),
              )
            else
              ...enfantRdv.map((rdv) => _RdvTile(rdv: rdv)),
          ],
        );
      },
    );
  }

  void _showRdvForm(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF161B22),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => _RdvForm(enfant: enfant),
    );
  }
}

class _RdvTile extends StatelessWidget {
  final RdvModel rdv;
  const _RdvTile({required this.rdv});

  @override
  Widget build(BuildContext context) {
    final statut = rdv.statut;
    Color color;
    if (statut == RdvStatut.accepte || statut == RdvStatut.confirme) {
      color = Colors.green;
    } else if (statut == RdvStatut.refuse || statut == RdvStatut.annule) {
      color = Colors.red;
    } else if (statut == RdvStatut.proposeAutreDate) {
      color = Colors.orange;
    } else {
      color = Colors.blue;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1C2128),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Prof. ${rdv.professeurNom}',
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w600),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(statut.label,
                    style: TextStyle(color: color, fontSize: 11)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            DateFormat('dd/MM/yyyy – HH:mm').format(rdv.dateHeure),
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
          if (rdv.motif.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(rdv.motif,
                style: const TextStyle(color: Colors.white38, fontSize: 12),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
          ],
          if (statut == RdvStatut.proposeAutreDate &&
              rdv.contrePropositionDate != null) ...[
            const SizedBox(height: 6),
            Text(
              'Contre-proposition : ${DateFormat('dd/MM/yyyy – HH:mm').format(rdv.contrePropositionDate!)}',
              style: const TextStyle(color: Colors.orange, fontSize: 12),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                _SmallButton(
                  'Accepter',
                  Colors.green,
                  () => _runRdvAction(
                      context, () => ParentService.confirmerContreProposition(rdv.id)),
                ),
                const SizedBox(width: 8),
                _SmallButton(
                  'Annuler',
                  Colors.red,
                  () => _runRdvAction(context, () => ParentService.annulerRdv(rdv.id)),
                ),
              ],
            ),
          ],
          if (statut == RdvStatut.demande) ...[
            const SizedBox(height: 6),
            _SmallButton(
              'Annuler la demande',
              Colors.red,
              () => _runRdvAction(context, () => ParentService.annulerRdv(rdv.id)),
            ),
          ],
        ],
      ),
    );
  }
}

class _SmallButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onPressed;
  const _SmallButton(this.label, this.color, this.onPressed);

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        minimumSize: const Size(0, 28),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      onPressed: onPressed,
      child: Text(label, style: const TextStyle(fontSize: 11)),
    );
  }
}

class _RdvForm extends StatefulWidget {
  final UserModel enfant;
  const _RdvForm({required this.enfant});
  @override
  State<_RdvForm> createState() => _RdvFormState();
}

class _RdvFormState extends State<_RdvForm> {
  final _motifCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  DateTime? _date;
  String? _profId;
  String? _profNom;
  bool _sending = false;

  @override
  void dispose() {
    _motifCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 60)),
    );
    if (picked == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 17, minute: 0),
    );
    if (time == null) return;
    setState(() {
      _date = DateTime(picked.year, picked.month, picked.day,
          time.hour, time.minute);
    });
  }

  Future<void> _submit() async {
    if (_profId == null || _date == null || _motifCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Remplissez tous les champs requis.')),
      );
      return;
    }
    setState(() => _sending = true);
    try {
      await ParentService.demanderRdv(
        professeurId: _profId!,
        professeurNom: _profNom ?? '',
        classeNom: widget.enfant.classeNom ?? '',
        eleveUid: widget.enfant.uid,
        eleveNom: widget.enfant.displayName,
        dateHeure: _date!,
        motif: _motifCtrl.text.trim(),
        notesParent: _notesCtrl.text.trim(),
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Demander un RDV',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16)),
          const SizedBox(height: 16),
          // Sélecteur de professeur
          _ProfesseurDropdown(
            classeNom: widget.enfant.classeNom ?? '',
            onSelected: (id, nom) => setState(() {
              _profId = id;
              _profNom = nom;
            }),
          ),
          const SizedBox(height: 12),
          // Date/heure
          GestureDetector(
            onTap: _pickDate,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF0D1117),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today,
                      color: Colors.white38, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    _date != null
                        ? DateFormat('dd/MM/yyyy – HH:mm').format(_date!)
                        : 'Choisir une date et heure',
                    style: TextStyle(
                        color: _date != null ? Colors.white : Colors.white38),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _Field(label: 'Motif *', controller: _motifCtrl, maxLines: 2),
          const SizedBox(height: 8),
          _Field(
              label: 'Notes (optionnel)',
              controller: _notesCtrl,
              maxLines: 2),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onPressed: _sending ? null : _submit,
              child: _sending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Text('Envoyer la demande'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfesseurDropdown extends StatelessWidget {
  final String classeNom;
  final void Function(String id, String nom) onSelected;
  const _ProfesseurDropdown(
      {required this.classeNom, required this.onSelected});

  // Le modèle actuel n'a qu'un professeur par classe (classes/{id}.professeurId) :
  // on ne propose donc que le(s) professeur(s) réellement assigné(s) à la classe
  // de l'enfant, pas tous les professeurs de l'établissement.
  Stream<QuerySnapshot> _profsOfClasse() async* {
    final classesSnap = await FirebaseFirestore.instance
        .collection('classes')
        .where('nom', isEqualTo: classeNom)
        .get();
    final profIds = classesSnap.docs
        .map((d) => d.data()['professeurId'] as String? ?? '')
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();
    if (profIds.isEmpty) {
      yield* FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'professeur')
          .snapshots();
      return;
    }
    yield* FirebaseFirestore.instance
        .collection('users')
        .where(FieldPath.documentId, whereIn: profIds)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _profsOfClasse(),
      builder: (ctx, snap) {
        if (snap.hasError) {
          return const Text('Impossible de charger la liste des professeurs.',
              style: TextStyle(color: Colors.redAccent, fontSize: 12));
        }
        if (snap.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 40,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Text('Aucun professeur disponible.',
              style: TextStyle(color: Colors.white38, fontSize: 12));
        }
        final items = docs
            .map((d) => DropdownMenuItem<String>(
                  value: d.id,
                  child: Text(
                    (d.data() as Map)['displayName'] as String? ?? d.id,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ))
            .toList();
        return DropdownButtonFormField<String>(
          dropdownColor: const Color(0xFF1C2128),
          decoration: InputDecoration(
            labelText: 'Professeur *',
            labelStyle: const TextStyle(color: Colors.white54),
            enabledBorder: OutlineInputBorder(
              borderSide: const BorderSide(color: Colors.white12),
              borderRadius: BorderRadius.circular(8),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: const BorderSide(color: Color(0xFF2563EB)),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          items: items,
          onChanged: (val) {
            if (val == null) return;
            final doc = docs.firstWhere((d) => d.id == val);
            final nom = (doc.data() as Map)['displayName'] as String? ?? '';
            onSelected(val, nom);
          },
        );
      },
    );
  }
}

class _Field extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final int maxLines;
  const _Field(
      {required this.label, required this.controller, this.maxLines = 1});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white54, fontSize: 13),
        enabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Colors.white12),
          borderRadius: BorderRadius.circular(8),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Color(0xFF2563EB)),
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}

// ── Widgets réutilisables ─────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text,
          style: const TextStyle(
              color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 13)),
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
      ),
      child: child,
    );
  }
}

class _StatBadge extends StatelessWidget {
  final String label;
  final Color bg;
  const _StatBadge(this.label, this.bg);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(label,
          style: const TextStyle(color: Colors.white70, fontSize: 12)),
    );
  }
}

class _NoteRow extends StatelessWidget {
  final NoteModel note;
  const _NoteRow({required this.note});

  @override
  Widget build(BuildContext context) {
    final sur20 = note.sur20;
    final color =
        sur20 >= 14 ? Colors.green : sur20 >= 10 ? Colors.amber : Colors.red;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 44,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(sur20.toStringAsFixed(1),
                style: TextStyle(
                    color: color, fontWeight: FontWeight.bold, fontSize: 13)),
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
                    style: const TextStyle(color: Colors.white38, fontSize: 11)),
              ],
            ),
          ),
          const Text('/20', style: TextStyle(color: Colors.white38, fontSize: 11)),
        ],
      ),
    );
  }
}

// ── Onglet 6 : Messages (Parent → Professeur) ─────────────────────────────────

class _DiscussionTab extends StatefulWidget {
  final String classeId;
  const _DiscussionTab({required this.classeId});

  @override
  State<_DiscussionTab> createState() => _DiscussionTabState();
}

class _DiscussionTabState extends State<_DiscussionTab> {
  static final _fs = FirebaseFirestore.instance;
  late final Future<List<UserModel>> _profsFuture;

  @override
  void initState() {
    super.initState();
    _profsFuture = _loadProfesseurs();
  }

  Future<List<UserModel>> _loadProfesseurs() async {
    final classeId = widget.classeId;
    if (classeId.isEmpty) return [];
    try {
      // 1. Charger les professeurIds depuis emplois_du_temps
      final emploiSnap = await _fs
          .collection('emplois_du_temps')
          .where('classeId', isEqualTo: classeId)
          .get();

      final profIds = emploiSnap.docs
          .map((d) => d.data()['professeurId'] as String? ?? '')
          .where((id) => id.isNotEmpty)
          .toSet();

      // 2. Fallback : professeurId depuis la collection classes
      if (profIds.isEmpty) {
        final classeDoc =
            await _fs.collection('classes').doc(classeId).get();
        final profId =
            (classeDoc.data() ?? {})['professeurId'] as String?;
        if (profId != null && profId.isNotEmpty) profIds.add(profId);
      }

      if (profIds.isEmpty) return [];

      // 3. Charger le profil de chaque professeur
      final profs = <UserModel>[];
      for (final profId in profIds.take(15)) {
        try {
          final doc = await _fs.collection('users').doc(profId).get();
          if (doc.exists) {
            final model = UserModel.fromDoc(doc);
            if (model.role == UserRole.professeur) profs.add(model);
          }
        } catch (_) {}
      }
      profs.sort((a, b) => a.displayName.compareTo(b.displayName));
      return profs;
    } catch (_) {
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    final parentEmail =
        FirebaseAuth.instance.currentUser?.email ?? '';
    return FutureBuilder<List<UserModel>>(
      future: _profsFuture,
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
              child:
                  CircularProgressIndicator(color: Color(0xFF2563EB)));
        }
        if (snap.hasError) {
          return const Center(
            child: Text('Erreur de chargement.',
                style: TextStyle(color: Colors.white54)),
          );
        }
        final profs = snap.data ?? [];
        if (profs.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.person_off_outlined,
                      color: Colors.white24, size: 52),
                  SizedBox(height: 14),
                  Text(
                    'Aucun professeur assigné à cette classe.',
                    textAlign: TextAlign.center,
                    style:
                        TextStyle(color: Colors.white54, fontSize: 14),
                  ),
                ],
              ),
            ),
          );
        }
        return Column(
          children: [
            // Lien messagerie interne
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: InkWell(
                onTap: () => Navigator.push(context,
                    MaterialPageRoute<void>(
                        builder: (_) => const MessageriePage())),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF2563EB), Color(0xFF6C47FF)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(children: [
                    Icon(Icons.forum_outlined,
                        color: Colors.white, size: 20),
                    SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Messagerie interne',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13)),
                          Text('Messages en temps réel',
                              style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11)),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right,
                        color: Colors.white54, size: 18),
                  ]),
                ),
              ),
            ),
            _DiscussionInfoBanner(),
            Expanded(
              child: ListView.builder(
                padding:
                    const EdgeInsets.fromLTRB(16, 12, 16, 32),
                itemCount: profs.length,
                itemBuilder: (ctx, i) => _ProfMessageTile(
                  prof: profs[i],
                  parentEmail: parentEmail,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _DiscussionInfoBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: const Color(0xFFBE185D).withValues(alpha: 0.3)),
      ),
      child: const Row(
        children: [
          Icon(Icons.forum_outlined,
              color: Color(0xFFBE185D), size: 16),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Envoyez un message privé aux professeurs de votre enfant. '
              'Conversations privées et sécurisées.',
              style:
                  TextStyle(color: Colors.white54, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Onglets Maternelle ────────────────────────────────────────────────────────

/// Onglet Journée : affiche les présences/activités du jour pour l'enfant.
class _ParentJourneeTab extends StatelessWidget {
  final String enfantUid;
  const _ParentJourneeTab({required this.enfantUid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('presences')
          .where('eleveId', isEqualTo: enfantUid)
          .orderBy('date', descending: true)
          .limit(10)
          .snapshots(),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return const Center(
            child: Text('Impossible de charger la journée.',
                style: TextStyle(color: Colors.redAccent)),
          );
        }
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Center(
            child: Text('Aucun enregistrement de journée.',
                style: TextStyle(color: Colors.white38)),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (ctx, i) {
            final d = docs[i].data() as Map<String, dynamic>;
            final date = (d['date'] as String?) ?? '';
            final statut = (d['statut'] as String?) ?? 'present';
            final isPresent = statut == 'present';
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF161B22),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(
                    isPresent ? Icons.check_circle_outline : Icons.cancel_outlined,
                    color: isPresent ? Colors.green : Colors.red,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(date,
                        style: const TextStyle(color: Colors.white, fontSize: 13)),
                  ),
                  Text(
                    isPresent ? 'Présent(e)' : 'Absent(e)',
                    style: TextStyle(
                        color: isPresent ? Colors.green : Colors.red,
                        fontSize: 12),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

/// Onglet Cahier de vie : affiche les entrées du cahier de vie de l'enfant.
class _ParentCahierVieTab extends StatelessWidget {
  final String enfantUid;
  const _ParentCahierVieTab({required this.enfantUid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('cahier_vie')
          .where('eleveId', isEqualTo: enfantUid)
          .orderBy('date', descending: true)
          .limit(20)
          .snapshots(),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return const Center(
            child: Text('Impossible de charger le cahier de vie.',
                style: TextStyle(color: Colors.redAccent)),
          );
        }
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.menu_book_outlined, color: Colors.white24, size: 52),
                  SizedBox(height: 12),
                  Text('Le cahier de vie est vide pour le moment.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white38)),
                ],
              ),
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (ctx, i) {
            final d = docs[i].data() as Map<String, dynamic>;
            final titre = (d['titre'] as String?) ?? 'Entrée';
            final contenu = (d['contenu'] as String?) ?? '';
            final date = (d['date'] as String?) ?? '';
            final imageUrl = (d['imageUrl'] as String?) ?? '';
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF161B22),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: const Color(0xFFEC4899).withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.auto_stories_outlined,
                          color: Color(0xFFEC4899), size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(titre,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13)),
                      ),
                      Text(date,
                          style: const TextStyle(
                              color: Colors.white38, fontSize: 11)),
                    ],
                  ),
                  if (contenu.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(contenu,
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12)),
                  ],
                  if (imageUrl.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        imageUrl,
                        height: 160,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }
}

/// Onglet Compétences : affiche les évaluations qualitatives de l'enfant.
class _ParentCompetencesTab extends StatelessWidget {
  final String enfantUid;
  const _ParentCompetencesTab({required this.enfantUid});

  @override
  Widget build(BuildContext context) {
    // Les évaluations qualitatives (maternelle) sont saisies par le
    // professeur dans `competences_maternelle` (voir
    // professeur_evaluations_qualitative_page.dart) — c'est la seule
    // collection réellement alimentée pour cette fonctionnalité.
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('competences_maternelle')
          .where('eleveId', isEqualTo: enfantUid)
          .orderBy('updatedAt', descending: true)
          .limit(30)
          .snapshots(),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return const Center(
            child: Text('Impossible de charger les compétences.',
                style: TextStyle(color: Colors.redAccent)),
          );
        }
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.star_outline, color: Colors.white24, size: 52),
                  SizedBox(height: 12),
                  Text('Aucune évaluation enregistrée.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white38)),
                ],
              ),
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (ctx, i) {
            final d = docs[i].data() as Map<String, dynamic>;
            final competence = (d['competence'] as String?) ?? '';
            final niveau = (d['niveau'] as String?) ?? '';
            final updatedAt = d['updatedAt'] as Timestamp?;
            final date = updatedAt != null
                ? DateFormat('dd/MM/yyyy').format(updatedAt.toDate())
                : '';
            Color niveauColor;
            switch (niveau.toLowerCase()) {
              case 'acquis':
                niveauColor = Colors.green;
                break;
              case 'en_cours':
                niveauColor = Colors.amber;
                break;
              default:
                niveauColor = Colors.red;
            }
            final niveauLabel = switch (niveau.toLowerCase()) {
              'acquis' => 'Acquis',
              'en_cours' => 'En cours',
              'non_acquis' => 'Non acquis',
              _ => niveau,
            };
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF161B22),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                        color: niveauColor, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(competence,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 13)),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(niveauLabel,
                          style: TextStyle(
                              color: niveauColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w600)),
                      Text(date,
                          style: const TextStyle(
                              color: Colors.white38, fontSize: 10)),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

/// Onglet Ressources : liens vers les ressources Maternelle.
class _ParentRessourcesTab extends StatelessWidget {
  const _ParentRessourcesTab();

  @override
  Widget build(BuildContext context) {
    final ressources = [
      {'icon': Icons.auto_stories_outlined, 'label': 'Histoires', 'route': '/monde_enfants', 'color': const Color(0xFF7C3AED)},
      {'icon': Icons.music_note_outlined, 'label': 'Comptines', 'route': '/monde_enfants', 'color': const Color(0xFFEC4899)},
      {'icon': Icons.palette_outlined, 'label': 'Coloriages', 'route': '/monde_enfants', 'color': const Color(0xFFF97316)},
      {'icon': Icons.quiz_outlined, 'label': 'Jeux éducatifs', 'route': '/jeux_scolaires', 'color': const Color(0xFF0EA5E9)},
    ];

    return GridView.count(
      padding: const EdgeInsets.all(16),
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.2,
      children: ressources.map((r) {
        final color = r['color'] as Color;
        return InkWell(
          onTap: () => Navigator.pushNamed(context, r['route'] as String),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withValues(alpha: 0.3)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(r['icon'] as IconData, color: color, size: 36),
                const SizedBox(height: 8),
                Text(r['label'] as String,
                    style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.bold,
                        fontSize: 14)),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

/// Onglet Contact : affiche les infos de contact du professeur de l'enfant.
class _ParentContactTab extends StatelessWidget {
  final UserModel enfant;
  const _ParentContactTab({required this.enfant});

  @override
  Widget build(BuildContext context) {
    final classeId = enfant.classeId;
    if (classeId == null || classeId.isEmpty) {
      return const Center(
        child: Text('Classe non assignée.',
            style: TextStyle(color: Colors.white38)),
      );
    }
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('classes').doc(classeId).get(),
      builder: (ctx, classeSnap) {
        if (classeSnap.hasError) {
          return const Center(
            child: Text('Impossible de charger les informations de la classe.',
                style: TextStyle(color: Colors.redAccent)),
          );
        }
        if (!classeSnap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final data = classeSnap.data?.data() as Map<String, dynamic>?;
        final profId = data?['professeurId'] as String?;
        if (profId == null || profId.isEmpty) {
          return const Center(
            child: Text('Aucun professeur assigné.',
                style: TextStyle(color: Colors.white38)),
          );
        }
        return FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance.collection('users').doc(profId).get(),
          builder: (ctx2, profSnap) {
            if (profSnap.hasError) {
              return const Center(
                child: Text('Impossible de charger le professeur.',
                    style: TextStyle(color: Colors.redAccent)),
              );
            }
            if (!profSnap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final prof = profSnap.data?.data() as Map<String, dynamic>?;
            if (prof == null) {
              return const Center(
                child: Text('Professeur introuvable.',
                    style: TextStyle(color: Colors.white38)),
              );
            }
            final nom = (prof['displayName'] as String?) ?? '';
            final email = (prof['email'] as String?) ?? '';
            final matiere = (prof['matiere'] as String?) ?? '';
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF161B22),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: const Color(0xFFEC4899).withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 36,
                        backgroundColor: const Color(0xFFEC4899).withValues(alpha: 0.2),
                        child: Text(
                          nom.isNotEmpty ? nom[0].toUpperCase() : '?',
                          style: const TextStyle(
                              color: Color(0xFFEC4899),
                              fontSize: 28,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(nom,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold)),
                      if (matiere.isNotEmpty)
                        Text(matiere,
                            style: const TextStyle(
                                color: Colors.white54, fontSize: 13)),
                      const SizedBox(height: 16),
                      if (email.isNotEmpty)
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFEC4899),
                            side: const BorderSide(
                                color: Color(0xFFEC4899)),
                          ),
                          icon: const Icon(Icons.message_outlined, size: 16),
                          label: const Text('Envoyer un message'),
                          onPressed: () => Navigator.pushNamed(
                            context,
                            '/discussion',
                            arguments: {
                              'name': email,
                              'user': FirebaseAuth.instance.currentUser?.email ?? '',
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _ProfMessageTile extends StatelessWidget {
  final UserModel prof;
  final String parentEmail;
  const _ProfMessageTile(
      {required this.prof, required this.parentEmail});

  @override
  Widget build(BuildContext context) {
    final initials = prof.displayName.isNotEmpty
        ? prof.displayName[0].toUpperCase()
        : (prof.username.isNotEmpty
            ? prof.username[0].toUpperCase()
            : '?');
    return InkWell(
      onTap: () => Navigator.pushNamed(
        context,
        '/discussion',
        arguments: {'name': prof.email, 'user': parentEmail},
      ),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF161B22),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: const Color(0xFF1E3A5F),
              radius: 22,
              child: Text(
                initials,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    prof.displayName.isNotEmpty
                        ? prof.displayName
                        : prof.username,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14),
                  ),
                  if (prof.matiere != null &&
                      prof.matiere!.isNotEmpty)
                    Text(
                      prof.matiere!,
                      style: const TextStyle(
                          color: Colors.white38, fontSize: 12),
                    ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFF0F766E).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'Professeur',
                style: TextStyle(
                    color: Color(0xFF0F766E),
                    fontSize: 10,
                    fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right,
                color: Colors.white24, size: 18),
          ],
        ),
      ),
    );
  }
}


// ════════════════════════════════════════════════════════════════════════════════
// ESPACE PARENT — COLLÈGE + LYCÉE
// ════════════════════════════════════════════════════════════════════════════════

const _kCollegeAccent = Color(0xFF2563EB);
const _kCollegeColors = [Color(0xFF1E3A5F), Color(0xFF2563EB)];
const _kLyceeAccent = Color(0xFF6C47FF);
const _kLyceeColors = [Color(0xFF6C47FF), Color(0xFF15803D)];

// ── Vue Parent Collège ────────────────────────────────────────────────────────

class _CollegeParentView extends StatelessWidget {
  final UserModel enfant;
  const _CollegeParentView({required this.enfant});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 9,
      child: Column(
        children: [
          _EnfantHeader(enfant: enfant, accentColor: _kCollegeAccent),
          const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            indicatorColor: _kCollegeAccent,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white38,
            labelStyle: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            tabs: [
              Tab(text: 'Résumé'),
              Tab(text: 'Bulletins'),
              Tab(text: 'Notes'),
              Tab(text: 'Devoirs'),
              Tab(text: 'Documents'),
              Tab(text: 'Emploi'),
              Tab(text: 'Présences'),
              Tab(text: 'RDV'),
              Tab(text: 'Messages'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _CycleResumeTab(enfant: enfant, colors: _kCollegeColors),
                _BulletinsParentTab(enfantUid: enfant.uid, enfantNom: enfant.displayName, classeId: enfant.classeId ?? ''),
                _CycleNotesTab(enfantUid: enfant.uid, accentColor: _kCollegeAccent),
                _DevoirsTab(classeNom: enfant.classeNom ?? ''),
                _ParentDocumentsTab(classeNom: enfant.classeNom ?? ''),
                _EmploiTab(classeId: enfant.classeId ?? ''),
                _PresencesTab(enfantUid: enfant.uid),
                _RdvTab(enfant: enfant),
                _DiscussionTab(classeId: enfant.classeId ?? ''),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Vue Parent Lycée ──────────────────────────────────────────────────────────

class _LyceeParentView extends StatelessWidget {
  final UserModel enfant;
  const _LyceeParentView({required this.enfant});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 9,
      child: Column(
        children: [
          _EnfantHeader(enfant: enfant, accentColor: _kLyceeAccent),
          const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            indicatorColor: _kLyceeAccent,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white38,
            labelStyle: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            tabs: [
              Tab(text: 'Résumé'),
              Tab(text: 'Bulletins'),
              Tab(text: 'Notes'),
              Tab(text: 'Devoirs'),
              Tab(text: 'Documents'),
              Tab(text: 'Emploi'),
              Tab(text: 'Présences'),
              Tab(text: 'RDV'),
              Tab(text: 'Messages'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _CycleResumeTab(enfant: enfant, colors: _kLyceeColors, lyceeMode: true),
                _BulletinsParentTab(enfantUid: enfant.uid, enfantNom: enfant.displayName, classeId: enfant.classeId ?? ''),
                _CycleNotesTab(enfantUid: enfant.uid, accentColor: _kLyceeAccent, lyceeMode: true),
                _DevoirsTab(classeNom: enfant.classeNom ?? ''),
                _ParentDocumentsTab(classeNom: enfant.classeNom ?? ''),
                _EmploiTab(classeId: enfant.classeId ?? ''),
                _PresencesTab(enfantUid: enfant.uid),
                _RdvTab(enfant: enfant),
                _DiscussionTab(classeId: enfant.classeId ?? ''),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Onglet Résumé partagé Collège / Lycée ─────────────────────────────────────

class _CycleResumeTab extends StatelessWidget {
  final UserModel enfant;
  final List<Color> colors;
  final bool lyceeMode;
  const _CycleResumeTab({required this.enfant, required this.colors, this.lyceeMode = false});

  static String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  static String _mention(double v, {bool lyceeMode = false}) {
    if (lyceeMode) {
      if (v >= 16) return 'Félicitations du jury';
      if (v >= 14) return 'Mention Bien';
      if (v >= 12) return 'Mention Assez Bien';
      if (v >= 10) return 'Admis(e)';
      return 'Insuffisant';
    }
    if (v >= 16) return 'Excellent';
    if (v >= 14) return 'Très bien';
    if (v >= 12) return 'Bien';
    if (v >= 10) return 'Assez bien';
    return 'Insuffisant';
  }

  static Color _mentionColor(double v) {
    if (v >= 14) return const Color(0xFF16A34A);
    if (v >= 10) return const Color(0xFFD97706);
    return const Color(0xFFDC2626);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<NoteModel>>(
      stream: ParentService.notesEnfantStream(enfant.uid),
      builder: (_, notesSnap) {
        final notes = notesSnap.data ?? [];
        final moyGen = notes.isEmpty ? 0.0 : notes.fold<double>(0, (a, n) => a + n.sur20) / notes.length;
        final recentNotes = (List<NoteModel>.from(notes)..sort((a, b) => b.date.compareTo(a.date))).take(4).toList();

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            _LivePresenceBanner(enfantUid: enfant.uid),
            _ProchainCours(classeId: enfant.classeId ?? ''),
            // Bannière cycle
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              lyceeMode ? 'Lycée · ${enfant.niveau ?? ''}' : 'Collège · ${enfant.niveau ?? ''}',
                              style: const TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                            Text(
                              notes.isEmpty ? '–' : '${moyGen.toStringAsFixed(2)} / 20',
                              style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                            ),
                            if ((enfant.classeNom ?? '').isNotEmpty)
                              Text(enfant.classeNom!, style: const TextStyle(color: Colors.white60, fontSize: 12)),
                          ],
                        ),
                      ),
                      if (notes.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: _mentionColor(moyGen).withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            _mention(moyGen, lyceeMode: lyceeMode),
                            style: TextStyle(color: _mentionColor(moyGen), fontWeight: FontWeight.bold, fontSize: 11),
                          ),
                        ),
                    ],
                  ),
                  if (notes.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: moyGen / 20,
                        backgroundColor: Colors.white.withValues(alpha: 0.15),
                        valueColor: AlwaysStoppedAnimation<Color>(_mentionColor(moyGen)),
                        minHeight: 4,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),

            // KPI row
            StreamBuilder<List<DevoirModel>>(
              stream: ParentService.devoirsEnfantStream(enfant.classeNom ?? ''),
              builder: (_, devSnap) {
                final now = DateTime.now();
                final enAttente = (devSnap.data ?? []).where((d) => d.dateLimite?.isAfter(now) == true).length;
                return StreamBuilder<List<Map<String, dynamic>>>(
                  stream: ParentService.presencesEnfantStream(enfant.uid),
                  builder: (_, presSnap) {
                    final absences = (presSnap.data ?? []).where((d) => (d['statut'] as String?) == 'absent').length;
                    return Row(
                      children: [
                        Expanded(child: _ParentKpiBox('Notes', notes.length.toString(), colors.last, Icons.grade_outlined)),
                        const SizedBox(width: 8),
                        Expanded(child: _ParentKpiBox('Devoirs\nà venir', enAttente.toString(), const Color(0xFF6C47FF), Icons.assignment_outlined)),
                        const SizedBox(width: 8),
                        Expanded(child: _ParentKpiBox('Absences\nce mois', absences.toString(), const Color(0xFFDC2626), Icons.event_busy_outlined)),
                      ],
                    );
                  },
                );
              },
            ),

            // Info BAC (Lycée seulement)
            if (lyceeMode) ...[
              const SizedBox(height: 16),
              _SectionTitle('Préparation BAC'),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF161B22),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF6C47FF).withValues(alpha: 0.25)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Icon(Icons.school_outlined, color: Color(0xFF6C47FF), size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          notes.isEmpty ? 'Aucune note disponible' : 'Contrôle Continu : ${moyGen.toStringAsFixed(2)}/20',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 6),
                    const Text(
                      "La moyenne du contrôle continu contribue au BAC. Suivez l'évolution trimestre par trimestre dans l'onglet Notes.",
                      style: TextStyle(color: Colors.white54, fontSize: 11, height: 1.4),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),

            // Dernières notes
            if (recentNotes.isNotEmpty) ...[
              _SectionTitle('Notes récentes'),
              ...recentNotes.map((n) {
                final c = n.sur20 >= 14 ? const Color(0xFF16A34A) : n.sur20 >= 10 ? const Color(0xFFD97706) : const Color(0xFFDC2626);
                return Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF161B22),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 42, height: 42, alignment: Alignment.center,
                        decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
                        child: Text(n.sur20.toStringAsFixed(1), style: TextStyle(color: c, fontWeight: FontWeight.bold, fontSize: 14)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(n.matiere, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
                            Text(n.intitule.isNotEmpty ? n.intitule : 'Évaluation',
                                style: const TextStyle(color: Colors.white38, fontSize: 11),
                                maxLines: 1, overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('/${n.bareme.toInt()}', style: const TextStyle(color: Colors.white38, fontSize: 11)),
                          Text(_fmt(n.date), style: const TextStyle(color: Colors.white24, fontSize: 10)),
                        ],
                      ),
                    ],
                  ),
                );
              }),
            ] else if (notesSnap.hasData)
              const _Card(child: Text('Aucune note publiée.', style: TextStyle(color: Colors.white38))),
            const SizedBox(height: 16),
            _SectionTitle('Activité récente'),
            _ActivityFeed(
              enfantUid: enfant.uid,
              classeNom: enfant.classeNom ?? '',
              classeId: enfant.classeId ?? '',
            ),
          ],
        );
      },
    );
  }
}

// ── Onglet Notes partagé Collège / Lycée ─────────────────────────────────────

class _CycleNotesTab extends StatefulWidget {
  final String enfantUid;
  final Color accentColor;
  final bool lyceeMode;
  const _CycleNotesTab({required this.enfantUid, required this.accentColor, this.lyceeMode = false});

  @override
  State<_CycleNotesTab> createState() => _CycleNotesTabState();
}

class _CycleNotesTabState extends State<_CycleNotesTab> {
  late int _trimestre;

  @override
  void initState() {
    super.initState();
    _trimestre = _currentTrimestre;
  }

  static int get _currentTrimestre {
    final m = DateTime.now().month;
    if (m >= 9 && m <= 11) return 1;
    if (m == 12 || m <= 2) return 2;
    return 3;
  }

  static int _trimestreDe(DateTime d) {
    final m = d.month;
    if (m >= 9 && m <= 11) return 1;
    if (m == 12 || m <= 2) return 2;
    if (m >= 3 && m <= 5) return 3;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _TrimestrePicker(
          selected: _trimestre,
          accentColor: widget.accentColor,
          onChanged: (t) => setState(() => _trimestre = t),
        ),
        Expanded(
          child: StreamBuilder<List<NoteModel>>(
            stream: ParentService.notesEnfantStream(widget.enfantUid),
            builder: (_, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator(color: widget.accentColor));
              }
              if (snap.hasError) {
                return const Center(
                  child: Text('Impossible de charger les notes.',
                      style: TextStyle(color: Colors.redAccent)),
                );
              }
              final filtered = (snap.data ?? []).where((n) => _trimestreDe(n.date) == _trimestre).toList();
              if (filtered.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.grade_outlined, color: Colors.white24, size: 48),
                      const SizedBox(height: 12),
                      Text('Aucune note pour le trimestre $_trimestre',
                          style: const TextStyle(color: Colors.white38)),
                    ],
                  ),
                );
              }

              final groups = <String, List<NoteModel>>{};
              for (final n in filtered) { (groups[n.matiere] ??= []).add(n); }
              final matieres = groups.entries.map((e) {
                final avg = e.value.fold<double>(0, (s, n) => s + n.sur20) / e.value.length;
                return (nom: e.key, avg: avg, notes: e.value);
              }).toList()..sort((a, b) => a.nom.compareTo(b.nom));
              final moyGen = matieres.fold<double>(0, (s, m) => s + m.avg) / matieres.length;

              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                children: [
                  _NotesSummaryBanner(
                    moyGen: moyGen, trimestre: _trimestre,
                    nbMatieres: matieres.length,
                    accentColor: widget.accentColor, lyceeMode: widget.lyceeMode,
                  ),
                  const SizedBox(height: 12),
                  ...matieres.asMap().entries.map((e) => _ParentMatiereCard(
                    nom: e.value.nom, avg: e.value.avg, notes: e.value.notes,
                    index: e.key, accentColor: widget.accentColor, lyceeMode: widget.lyceeMode,
                  )),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _TrimestrePicker extends StatelessWidget {
  final int selected;
  final Color accentColor;
  final ValueChanged<int> onChanged;
  const _TrimestrePicker({required this.selected, required this.accentColor, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF161B22),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [1, 2, 3].map((t) => Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: GestureDetector(
              onTap: () => onChanged(t),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: selected == t ? accentColor : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: selected == t ? accentColor : Colors.white24),
                ),
                child: Text(
                  'Trim. $t',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: selected == t ? Colors.white : Colors.white54,
                    fontWeight: selected == t ? FontWeight.w600 : FontWeight.normal,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ),
        )).toList(),
      ),
    );
  }
}

class _NotesSummaryBanner extends StatelessWidget {
  final double moyGen;
  final int trimestre, nbMatieres;
  final Color accentColor;
  final bool lyceeMode;
  const _NotesSummaryBanner({
    required this.moyGen, required this.trimestre,
    required this.nbMatieres, required this.accentColor, required this.lyceeMode,
  });

  Color get _c => moyGen >= 14 ? const Color(0xFF16A34A) : moyGen >= 10 ? const Color(0xFFD97706) : const Color(0xFFDC2626);

  String get _mention {
    if (lyceeMode) {
      if (moyGen >= 16) return 'Félicitations';
      if (moyGen >= 14) return 'Mention Bien';
      if (moyGen >= 12) return 'Assez Bien';
      if (moyGen >= 10) return 'Admis(e)';
      return 'Insuffisant';
    }
    if (moyGen >= 16) return 'Excellent';
    if (moyGen >= 14) return 'Très bien';
    if (moyGen >= 12) return 'Bien';
    if (moyGen >= 10) return 'Assez bien';
    return 'Insuffisant';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accentColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Trimestre $trimestre · $nbMatieres matières',
                        style: const TextStyle(color: Colors.white54, fontSize: 12)),
                    Text('${moyGen.toStringAsFixed(2)} / 20',
                        style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: _c.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                child: Text(_mention, style: TextStyle(color: _c, fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: moyGen / 20,
              backgroundColor: Colors.white.withValues(alpha: 0.1),
              valueColor: AlwaysStoppedAnimation<Color>(_c),
              minHeight: 4,
            ),
          ),
        ],
      ),
    );
  }
}

class _ParentMatiereCard extends StatefulWidget {
  final String nom;
  final double avg;
  final List<NoteModel> notes;
  final int index;
  final Color accentColor;
  final bool lyceeMode;
  const _ParentMatiereCard({
    required this.nom, required this.avg, required this.notes,
    required this.index, required this.accentColor, required this.lyceeMode,
  });

  @override
  State<_ParentMatiereCard> createState() => _ParentMatiereCardState();
}

class _ParentMatiereCardState extends State<_ParentMatiereCard> {
  bool _expanded = false;

  static const _palette = [
    Color(0xFF2563EB), Color(0xFF0891B2), Color(0xFF7C3AED),
    Color(0xFF15803D), Color(0xFFD97706), Color(0xFFDC2626), Color(0xFF6C47FF),
  ];

  Color get _color => _palette[widget.index % _palette.length];
  Color get _avgColor => widget.avg >= 14 ? const Color(0xFF16A34A) : widget.avg >= 10 ? const Color(0xFFD97706) : const Color(0xFFDC2626);

  String get _appreciation {
    if (widget.lyceeMode) {
      if (widget.avg >= 16) return 'Félicitations';
      if (widget.avg >= 14) return 'Mention Bien';
      if (widget.avg >= 12) return 'Assez Bien';
      if (widget.avg >= 10) return 'Admis(e)';
      return 'Insuffisant';
    }
    if (widget.avg >= 16) return 'Excellent';
    if (widget.avg >= 14) return 'Très bien';
    if (widget.avg >= 12) return 'Bien';
    if (widget.avg >= 10) return 'Assez bien';
    return 'Insuffisant';
  }

  static String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _expanded ? _color.withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
              child: Row(
                children: [
                  Container(
                    width: 5, height: 36,
                    decoration: BoxDecoration(color: _color, borderRadius: BorderRadius.circular(3)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.nom, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                        Text(_appreciation, style: TextStyle(color: _avgColor, fontSize: 11)),
                      ],
                    ),
                  ),
                  Text(widget.avg.toStringAsFixed(1), style: TextStyle(color: _avgColor, fontWeight: FontWeight.bold, fontSize: 16)),
                  Text('/20', style: const TextStyle(color: Colors.white38, fontSize: 11)),
                  const SizedBox(width: 4),
                  Icon(_expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: Colors.white38, size: 18),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: widget.avg / 20,
                backgroundColor: Colors.white.withValues(alpha: 0.08),
                valueColor: AlwaysStoppedAnimation<Color>(_avgColor),
                minHeight: 3,
              ),
            ),
          ),
          if (_expanded) ...[
            const Divider(color: Colors.white10, height: 1),
            ...widget.notes.map((n) {
              final nc = n.sur20 >= 14 ? const Color(0xFF16A34A) : n.sur20 >= 10 ? const Color(0xFFD97706) : const Color(0xFFDC2626);
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                child: Row(
                  children: [
                    Container(
                      width: 44, alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      decoration: BoxDecoration(color: nc.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
                      child: Text(n.sur20.toStringAsFixed(1), style: TextStyle(color: nc, fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(n.intitule.isNotEmpty ? n.intitule : 'Évaluation',
                              style: const TextStyle(color: Colors.white60, fontSize: 12),
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                          Text(_fmt(n.date), style: const TextStyle(color: Colors.white38, fontSize: 10)),
                        ],
                      ),
                    ),
                    Text('/${n.bareme.toInt()}', style: const TextStyle(color: Colors.white24, fontSize: 11)),
                  ],
                ),
              );
            }),
            const SizedBox(height: 4),
          ],
        ],
      ),
    );
  }
}

class _ParentKpiBox extends StatelessWidget {
  final String label, value;
  final Color color;
  final IconData icon;
  const _ParentKpiBox(this.label, this.value, this.color, this.icon);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold)),
          Text(label, style: const TextStyle(color: Colors.white38, fontSize: 9)),
        ],
      ),
    );
  }
}

// ── Suivi en temps réel — Présence aujourd'hui ───────────────────────────────

class _LivePresenceBanner extends StatelessWidget {
  final String enfantUid;
  const _LivePresenceBanner({required this.enfantUid});

  @override
  Widget build(BuildContext context) {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('presences')
          .where('eleveId', isEqualTo: enfantUid)
          .where('date', isEqualTo: today)
          .limit(1)
          .snapshots(),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting || !snap.hasData) {
          return const SizedBox.shrink();
        }
        final docs = snap.data!.docs;
        final statut = docs.isEmpty
            ? ''
            : (docs.first.data() as Map)['statut'] as String? ?? '';

        Color color;
        IconData icon;
        String label;
        switch (statut) {
          case 'present':
            color = const Color(0xFF16A34A);
            icon = Icons.check_circle_outline;
            label = "Présent(e) aujourd'hui";
            break;
          case 'absent':
            color = const Color(0xFFDC2626);
            icon = Icons.cancel_outlined;
            label = "Absent(e) aujourd'hui";
            break;
          case 'retard':
            color = const Color(0xFFD97706);
            icon = Icons.schedule_outlined;
            label = "Retard enregistré aujourd'hui";
            break;
          default:
            return const SizedBox.shrink();
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(label,
                    style: TextStyle(
                        color: color, fontWeight: FontWeight.w600, fontSize: 13)),
              ),
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 4),
              Text('En direct',
                  style: TextStyle(
                      color: color.withValues(alpha: 0.65), fontSize: 10)),
            ],
          ),
        );
      },
    );
  }
}

// ── Suivi en temps réel — Prochain cours ─────────────────────────────────────

class _ProchainCours extends StatelessWidget {
  final String classeId;
  const _ProchainCours({required this.classeId});

  static (int, int)? _parseHM(String s) {
    final parts = s.split(':');
    if (parts.length < 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return (h, m);
  }

  static DateTime? _slotDt(Map<String, dynamic> s, DateTime ref, String key) {
    final t = _parseHM(s[key] as String? ?? '');
    if (t == null) return null;
    return DateTime(ref.year, ref.month, ref.day, t.$1, t.$2);
  }

  @override
  Widget build(BuildContext context) {
    if (classeId.isEmpty) return const SizedBox.shrink();

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: ParentService.emploiEnfantStream(classeId),
      builder: (ctx, snap) {
        final slots = snap.data ?? [];
        if (slots.isEmpty) return const SizedBox.shrink();

        final now = DateTime.now();
        final jours = ['', 'Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi', 'Dimanche'];
        final jourAuj = now.weekday < jours.length ? jours[now.weekday] : '';
        final today = slots.where((s) => (s['jour'] as String?) == jourAuj).toList();
        if (today.isEmpty) return const SizedBox.shrink();

        Map<String, dynamic>? current;
        Map<String, dynamic>? next;
        DateTime? nextDt;

        for (final s in today) {
          final debut = _slotDt(s, now, 'heureDebut');
          final fin = _slotDt(s, now, 'heureFin');
          if (debut == null || fin == null) continue;
          if (now.isAfter(debut) && now.isBefore(fin)) {
            current = s;
            break;
          }
          if (now.isBefore(debut) && (nextDt == null || debut.isBefore(nextDt))) {
            next = s;
            nextDt = debut;
          }
        }

        final slot = current ?? next;
        if (slot == null) return const SizedBox.shrink();
        final isCurrent = current != null;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isCurrent
                ? const Color(0xFF2563EB).withValues(alpha: 0.1)
                : const Color(0xFF161B22),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isCurrent
                  ? const Color(0xFF2563EB).withValues(alpha: 0.4)
                  : Colors.white.withValues(alpha: 0.07),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isCurrent
                      ? const Color(0xFF2563EB).withValues(alpha: 0.2)
                      : Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isCurrent ? Icons.play_circle_outline : Icons.schedule_outlined,
                  color: isCurrent ? const Color(0xFF2563EB) : Colors.white38,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isCurrent ? 'Cours en cours' : 'Prochain cours',
                      style: TextStyle(
                        color: isCurrent
                            ? const Color(0xFF2563EB)
                            : Colors.white38,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      (slot['matiere'] as String?) ?? 'Cours',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14),
                    ),
                  ],
                ),
              ),
              Text(
                '${slot['heureDebut'] ?? ''} – ${slot['heureFin'] ?? ''}',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Suivi en temps réel — Fil d'activité ────────────────────────────────────

class _FeedItem {
  final DateTime date;
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  const _FeedItem({
    required this.date,
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });
}

class _ActivityFeed extends StatefulWidget {
  final String enfantUid;
  final String classeNom;
  final String classeId;
  const _ActivityFeed({
    required this.enfantUid,
    required this.classeNom,
    required this.classeId,
  });

  @override
  State<_ActivityFeed> createState() => _ActivityFeedState();
}

class _ActivityFeedState extends State<_ActivityFeed> {
  List<_FeedItem> _items = [];
  bool _loading = true;

  StreamSubscription<List<NoteModel>>? _notesSub;
  StreamSubscription<List<Map<String, dynamic>>>? _presencesSub;
  StreamSubscription<List<DevoirModel>>? _devoirsSub;

  List<NoteModel> _notes = [];
  List<Map<String, dynamic>> _presences = [];
  List<DevoirModel> _devoirs = [];

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  void _subscribe() {
    final since = DateTime.now().subtract(const Duration(days: 14));

    _notesSub = ParentService.notesEnfantStream(widget.enfantUid).listen((n) {
      _notes = n.where((x) => x.date.isAfter(since)).toList();
      _merge();
    });

    _presencesSub =
        ParentService.presencesEnfantStream(widget.enfantUid).listen((p) {
      _presences = p;
      _merge();
    });

    if (widget.classeNom.isNotEmpty) {
      _devoirsSub =
          ParentService.devoirsEnfantStream(widget.classeNom).listen((d) {
        _devoirs = d;
        _merge();
      });
    } else {
      _loading = false;
    }
  }

  void _merge() {
    final items = <_FeedItem>[];

    for (final n in _notes) {
      final c = n.sur20 >= 14
          ? const Color(0xFF16A34A)
          : n.sur20 >= 10
              ? const Color(0xFFD97706)
              : const Color(0xFFDC2626);
      items.add(_FeedItem(
        date: n.date,
        icon: Icons.grade_outlined,
        color: c,
        title: '${n.matiere} · ${n.sur20.toStringAsFixed(1)}/20',
        subtitle: n.intitule.isNotEmpty ? n.intitule : 'Évaluation',
      ));
    }

    for (final p in _presences) {
      final s = (p['statut'] as String?) ?? '';
      if (s != 'absent' && s != 'retard') continue;
      final dateStr = (p['date'] as String?) ?? '';
      DateTime? d;
      try {
        d = DateTime.parse(dateStr);
      } catch (_) {}
      if (d == null) continue;
      items.add(_FeedItem(
        date: d,
        icon: s == 'absent' ? Icons.cancel_outlined : Icons.schedule,
        color: s == 'absent'
            ? const Color(0xFFDC2626)
            : const Color(0xFFD97706),
        title: s == 'absent' ? 'Absence enregistrée' : 'Retard enregistré',
        subtitle: (p['motif'] as String?) ?? '',
      ));
    }

    final now = DateTime.now();
    final horizon = now.add(const Duration(days: 7));
    for (final d in _devoirs) {
      if (d.dateLimite == null) continue;
      if (d.dateLimite!.isBefore(now.subtract(const Duration(days: 1)))) continue;
      if (d.dateLimite!.isAfter(horizon)) continue;
      final overdue = d.dateLimite!.isBefore(now);
      items.add(_FeedItem(
        date: d.dateLimite!,
        icon: Icons.assignment_outlined,
        color: overdue ? const Color(0xFFDC2626) : const Color(0xFF6C47FF),
        title: '${d.matiere} · ${d.titre}',
        subtitle: 'Pour le ${DateFormat('dd/MM').format(d.dateLimite!)}',
      ));
    }

    items.sort((a, b) => b.date.compareTo(a.date));
    if (mounted) {
      setState(() {
        _items = items.take(10).toList();
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _notesSub?.cancel();
    _presencesSub?.cancel();
    _devoirsSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const _Card(
          child: Center(
              child: Padding(
        padding: EdgeInsets.all(12),
        child: CircularProgressIndicator(strokeWidth: 2),
      )));
    }
    if (_items.isEmpty) {
      return const _Card(
        child: Text('Aucune activité récente.',
            style: TextStyle(color: Colors.white38)),
      );
    }
    return _Card(
      child: Column(
        children: _items.map((item) => _FeedRow(item: item)).toList(),
      ),
    );
  }
}

class _FeedRow extends StatelessWidget {
  final _FeedItem item;
  const _FeedRow({required this.item});

  static String _relative(DateTime d) {
    final now = DateTime.now();
    if (d.isAfter(now)) {
      final diff = d.difference(now);
      if (diff.inDays > 0) return 'Dans ${diff.inDays}j';
      return 'Bientôt';
    }
    final diff = now.difference(d);
    if (diff.inMinutes < 60) return 'Il y a ${diff.inMinutes}min';
    if (diff.inHours < 24) return 'Il y a ${diff.inHours}h';
    if (diff.inDays < 7) return 'Il y a ${diff.inDays}j';
    return DateFormat('dd/MM').format(d);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: item.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(item.icon, color: item.color, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                if (item.subtitle.isNotEmpty)
                  Text(item.subtitle,
                      style:
                          const TextStyle(color: Colors.white38, fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          Text(_relative(item.date),
              style: const TextStyle(color: Colors.white24, fontSize: 10)),
        ],
      ),
    );
  }
}

// ── Onglet Bulletins parent ───────────────────────────────────────────────────

/// Onglet "Bulletins" dans toutes les vues parent.
///
/// Affiche un sélecteur T1/T2/T3. Pour chaque trimestre :
///  • Résumé (moyenne, mention, nb notes)
///  • Statut de publication par la Direction
///  • Bouton "Voir le bulletin complet" → [EleveReleveNotesPage]
///
/// Source de données : identique à celle de l'élève — pas de duplication.
class _BulletinsParentTab extends StatefulWidget {
  final String enfantUid;
  final String enfantNom;
  final String classeId;

  const _BulletinsParentTab({
    required this.enfantUid,
    required this.enfantNom,
    required this.classeId,
  });

  @override
  State<_BulletinsParentTab> createState() =>
      _BulletinsParentTabState();
}

class _BulletinsParentTabState
    extends State<_BulletinsParentTab>
    with SingleTickerProviderStateMixin {
  late TabController _tc;

  static int _currentTrimestre() {
    final m = DateTime.now().month;
    if (m >= 9 && m <= 11) return 0; // T1
    if (m == 12 || m <= 2) return 1; // T2
    return 2;                         // T3
  }

  @override
  void initState() {
    super.initState();
    _tc = TabController(
        length: 3,
        vsync: this,
        initialIndex: _currentTrimestre());
  }

  @override
  void dispose() {
    _tc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      TabBar(
        controller: _tc,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white38,
        indicatorColor: const Color(0xFF6C47FF),
        labelStyle: const TextStyle(
            fontWeight: FontWeight.w700, fontSize: 13),
        tabs: const [
          Tab(text: 'Trimestre 1'),
          Tab(text: 'Trimestre 2'),
          Tab(text: 'Trimestre 3'),
        ],
      ),
      Expanded(
        child: TabBarView(
          controller: _tc,
          children: [1, 2, 3].map((t) => _BulletinTrimestreCard(
            enfantUid: widget.enfantUid,
            enfantNom: widget.enfantNom,
            classeId: widget.classeId,
            trimestre: t,
          )).toList(),
        ),
      ),
    ]);
  }
}

// ── Carte bulletin par trimestre ──────────────────────────────────────────────

class _BulletinTrimestreCard extends StatelessWidget {
  final String enfantUid;
  final String enfantNom;
  final String classeId;
  final int trimestre;

  const _BulletinTrimestreCard({
    required this.enfantUid,
    required this.enfantNom,
    required this.classeId,
    required this.trimestre,
  });

  static int _trimestreDe(DateTime d) {
    final m = d.month;
    if (m >= 9 && m <= 11) return 1;
    if (m == 12 || m <= 2) return 2;
    return 3;
  }

  static String _mention(double v) {
    if (v >= 16) return 'Très bien';
    if (v >= 14) return 'Bien';
    if (v >= 12) return 'Assez bien';
    if (v >= 10) return 'Passable';
    if (v >= 8) return 'Insuffisant';
    return 'Très insuffisant';
  }

  static Color _mentionColor(double v) {
    if (v >= 14) return const Color(0xFF16A34A);
    if (v >= 10) return const Color(0xFFD97706);
    return const Color(0xFFDC2626);
  }

  @override
  Widget build(BuildContext context) {
    final anneeScol = DateTime.now().year;
    return StreamBuilder<List<NoteModel>>(
      stream: ParentService.notesEnfantStream(enfantUid),
      builder: (ctx, notesSnap) {
        final allNotes = notesSnap.data ?? [];
        final notes = allNotes
            .where((n) => _trimestreDe(n.date) == trimestre)
            .toList();

        return StreamBuilder<BulletinValidationModel?>(
          stream: classeId.isEmpty
              ? Stream.value(null)
              : BulletinValidationService.stream(
                  classeId: classeId,
                  trimestre: trimestre,
                  anneeScol: anneeScol),
          builder: (ctx2, valSnap) {
            final val = valSnap.data;
            final publie = val?.publie ?? false;

            return ListView(
              padding:
                  const EdgeInsets.fromLTRB(16, 16, 16, 40),
              children: [
                // Statut publication
                _PublicationStatusCard(
                    publie: publie,
                    trimestre: trimestre,
                    validation: val),
                const SizedBox(height: 14),

                // Résumé notes
                if (notes.isEmpty)
                  _EmptyBulletin(trimestre: trimestre)
                else
                  _BulletinSummaryCard(
                    notes: notes,
                    trimestre: trimestre,
                    mentionFn: _mention,
                    mentionColorFn: _mentionColor,
                  ),
                const SizedBox(height: 16),

                // Bouton bulletin complet
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => EleveReleveNotesPage(
                          eleveUid: enfantUid,
                          eleveNom: enfantNom,
                        ),
                      ),
                    ),
                    icon: const Icon(
                        Icons.description_outlined,
                        size: 16),
                    label: Text(
                        'Voir le bulletin complet T$trimestre'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6C47FF),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(12)),
                      textStyle: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

// ── Publication status card ───────────────────────────────────────────────────

class _PublicationStatusCard extends StatelessWidget {
  final bool publie;
  final int trimestre;
  final BulletinValidationModel? validation;
  const _PublicationStatusCard(
      {required this.publie,
      required this.trimestre,
      this.validation});

  @override
  Widget build(BuildContext context) {
    if (publie) {
      final ts = validation?.datePub;
      final dateStr = ts != null
          ? ' · ${ts.toDate().day.toString().padLeft(2, '0')}/${ts.toDate().month.toString().padLeft(2, '0')}/${ts.toDate().year}'
          : '';
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF16A34A).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: const Color(0xFF16A34A).withValues(alpha: 0.3)),
        ),
        child: Row(children: [
          const Icon(Icons.verified_outlined,
              color: Color(0xFF16A34A), size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bulletin T$trimestre validé par la Direction',
                  style: const TextStyle(
                      color: Color(0xFF16A34A),
                      fontWeight: FontWeight.bold,
                      fontSize: 13),
                ),
                if (dateStr.isNotEmpty)
                  Text(dateStr.trimLeft(),
                      style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 11)),
              ],
            ),
          ),
        ]),
      );
    }
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFD97706).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: const Color(0xFFD97706).withValues(alpha: 0.25)),
      ),
      child: Row(children: [
        const Icon(Icons.hourglass_empty_outlined,
            color: Color(0xFFD97706), size: 18),
        const SizedBox(width: 10),
        Text(
          'Bulletin T$trimestre en cours de préparation',
          style: const TextStyle(
              color: Color(0xFFD97706),
              fontWeight: FontWeight.w600,
              fontSize: 13),
        ),
      ]),
    );
  }
}

// ── Résumé du bulletin ────────────────────────────────────────────────────────

class _BulletinSummaryCard extends StatelessWidget {
  final List<NoteModel> notes;
  final int trimestre;
  final String Function(double) mentionFn;
  final Color Function(double) mentionColorFn;

  const _BulletinSummaryCard({
    required this.notes,
    required this.trimestre,
    required this.mentionFn,
    required this.mentionColorFn,
  });

  @override
  Widget build(BuildContext context) {
    final byMatiere = <String, List<NoteModel>>{};
    for (final n in notes) {
      (byMatiere[n.matiere] ??= []).add(n);
    }
    final moyParMat = byMatiere.map((m, ns) {
      final avg = ns.fold<double>(0, (s, n) => s + n.sur20) / ns.length;
      return MapEntry(m, avg);
    });
    final moyGen = moyParMat.isEmpty
        ? 0.0
        : moyParMat.values.reduce((a, b) => a + b) / moyParMat.length;
    final mention = mentionFn(moyGen);
    final color = mentionColorFn(moyGen);
    final sortedMat = moyParMat.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header moy générale
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                  colors: [
                    color.withValues(alpha: 0.15),
                    color.withValues(alpha: 0.05)
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight),
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(14)),
            ),
            child: Row(children: [
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text('Trimestre $trimestre',
                        style: const TextStyle(
                            color: Colors.white38,
                            fontSize: 11)),
                    const SizedBox(height: 4),
                    Text(
                      '${moyGen.toStringAsFixed(2)} / 20',
                      style: TextStyle(
                          color: color,
                          fontSize: 28,
                          fontWeight: FontWeight.bold),
                    ),
                    Text('${notes.length} note(s) · ${byMatiere.length} matière(s)',
                        style: const TextStyle(
                            color: Colors.white38,
                            fontSize: 11)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: color.withValues(alpha: 0.3)),
                ),
                child: Text(mention,
                    style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.bold,
                        fontSize: 12)),
              ),
            ]),
          ),
          // Matières
          ...sortedMat.map((e) => Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 8),
                child: Row(children: [
                  Expanded(
                    child: Text(e.key,
                        style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: mentionColorFn(e.value)
                          .withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${e.value.toStringAsFixed(2)}/20',
                      style: TextStyle(
                          color: mentionColorFn(e.value),
                          fontWeight: FontWeight.w700,
                          fontSize: 12),
                    ),
                  ),
                ]),
              )),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ── Empty bulletin ────────────────────────────────────────────────────────────

class _EmptyBulletin extends StatelessWidget {
  final int trimestre;
  const _EmptyBulletin({required this.trimestre});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          vertical: 32, horizontal: 24),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.inbox_outlined,
            color: Colors.white24, size: 42),
        const SizedBox(height: 12),
        Text('Aucune note publiée pour le Trimestre $trimestre',
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: Colors.white38, fontSize: 13)),
        const SizedBox(height: 4),
        const Text(
          'Les notes apparaîtront ici une fois saisies\npar les professeurs.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white24, fontSize: 11),
        ),
      ]),
    );
  }
}


