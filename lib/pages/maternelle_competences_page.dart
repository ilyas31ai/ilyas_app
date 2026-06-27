import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../widgets/cycle_access_guard.dart';

const _kColors = [Color(0xFF16A34A), Color(0xFF0891B2)];

enum _Niveau { acquis, enCours, nonAcquis }

class MaterneileCompetencesPage extends StatelessWidget {
  const MaterneileCompetencesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return CycleAccessGuard(
      cycleCategorie: 'Maternelle',
      cycleColors: _kColors,
      builder: (user) => _Body(user: user),
    );
  }
}

class _Body extends StatelessWidget {
  final UserModel user;
  const _Body({required this.user});

  // Référentiel des domaines et compétences du programme Maternelle algérien
  static const _domains = [
    _Domain(
      icon: Icons.auto_stories_outlined,
      nom: 'Langage et Communication',
      color: Color(0xFF2563EB),
      competences: ['S\'exprime oralement', 'Écoute et comprend', 'Reconnaît les lettres', 'Raconte une histoire'],
    ),
    _Domain(
      icon: Icons.calculate_outlined,
      nom: 'Logique et Mathématiques',
      color: Color(0xFF0891B2),
      competences: ['Compte jusqu\'à 10', 'Reconnaît les formes', 'Compare les grandeurs', 'Classe et sérialise'],
    ),
    _Domain(
      icon: Icons.directions_run_outlined,
      nom: 'Motricité',
      color: Color(0xFF7C3AED),
      competences: ['Motricité globale', 'Motricité fine', 'Équilibre', 'Coordination'],
    ),
    _Domain(
      icon: Icons.brush_outlined,
      nom: 'Arts et Créativité',
      color: Color(0xFFEC4899),
      competences: ['Dessin libre', 'Coloriage dans les lignes', 'Découpage', 'Collage'],
    ),
    _Domain(
      icon: Icons.science_outlined,
      nom: 'Découverte du Monde',
      color: Color(0xFF15803D),
      competences: ['Nomme les animaux', 'Connaît les saisons', 'Reconnaît les couleurs', 'Sens de l\'orientation'],
    ),
    _Domain(
      icon: Icons.people_outlined,
      nom: 'Vie Sociale',
      color: Color(0xFFD97706),
      competences: ['Respect des règles', 'Partage et coopération', 'Autonomie', 'Expression des émotions'],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        elevation: 0,
        title: const Text('Mes Compétences', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('competences_maternelle')
            .where('eleveId', isEqualTo: uid)
            .snapshots(),
        builder: (_, snap) {
          final Map<String, Map<String, String>> resultats = {};
          if (snap.hasData) {
            for (final doc in snap.data!.docs) {
              final data = doc.data() as Map<String, dynamic>;
              final domaine = data['domaine'] as String? ?? '';
              final competence = data['competence'] as String? ?? '';
              final niveau = data['niveau'] as String? ?? 'en_cours';
              (resultats[domaine] ??= {})[competence] = niveau;
            }
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              _LegendeBanner(),
              const SizedBox(height: 16),
              ..._domains.map((d) => _DomainCard(domain: d, resultats: resultats[d.nom] ?? {})),
            ],
          );
        },
      ),
    );
  }
}

class _Domain {
  final IconData icon;
  final String nom;
  final Color color;
  final List<String> competences;
  const _Domain({required this.icon, required this.nom, required this.color, required this.competences});
}

class _LegendeBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: _kColors, begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Évaluations Qualitatives', style: TextStyle(color: Colors.white70, fontSize: 12)),
          const Text('Suivi des Compétences', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Row(
            children: [
              _LegChip('Acquis', const Color(0xFF16A34A)),
              const SizedBox(width: 8),
              _LegChip('En cours', const Color(0xFFD97706)),
              const SizedBox(width: 8),
              _LegChip('Non acquis', const Color(0xFFDC2626)),
            ],
          ),
        ],
      ),
    );
  }
}

class _LegChip extends StatelessWidget {
  final String label;
  final Color color;
  const _LegChip(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(8)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 5),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
        ],
      ),
    );
  }
}

class _DomainCard extends StatefulWidget {
  final _Domain domain;
  final Map<String, String> resultats;
  const _DomainCard({required this.domain, required this.resultats});

  @override
  State<_DomainCard> createState() => _DomainCardState();
}

class _DomainCardState extends State<_DomainCard> {
  bool _expanded = true;

  int get _nbAcquis => widget.resultats.values.where((v) => v == 'acquis').length;
  int get _total => widget.domain.competences.length;

  @override
  Widget build(BuildContext context) {
    final d = widget.domain;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: d.color.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 38, height: 38,
                    decoration: BoxDecoration(color: d.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(9)),
                    child: Icon(d.icon, color: d.color, size: 19),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(d.nom, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                        Text('$_nbAcquis / $_total acquis', style: TextStyle(color: d.color, fontSize: 11)),
                      ],
                    ),
                  ),
                  Icon(_expanded ? Icons.expand_less : Icons.expand_more, color: Colors.white38, size: 20),
                ],
              ),
            ),
          ),
          if (_expanded) ...[
            const Divider(color: Colors.white10, height: 1),
            for (final c in d.competences)
              _CompetenceRow(competence: c, niveau: _parseNiveau(widget.resultats[c])),
          ],
        ],
      ),
    );
  }

  static _Niveau _parseNiveau(String? s) {
    if (s == 'acquis') return _Niveau.acquis;
    if (s == 'non_acquis') return _Niveau.nonAcquis;
    return _Niveau.enCours;
  }
}

class _CompetenceRow extends StatelessWidget {
  final String competence;
  final _Niveau niveau;
  const _CompetenceRow({required this.competence, required this.niveau});

  (String, Color, IconData) get _info => switch (niveau) {
    _Niveau.acquis    => ('Acquis', const Color(0xFF16A34A), Icons.check_circle_outline),
    _Niveau.nonAcquis => ('Non acquis', const Color(0xFFDC2626), Icons.cancel_outlined),
    _Niveau.enCours   => ('En cours', const Color(0xFFD97706), Icons.timelapse_outlined),
  };

  @override
  Widget build(BuildContext context) {
    final (label, color, icon) = _info;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      child: Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 10),
          Expanded(child: Text(competence, style: const TextStyle(color: Colors.white70, fontSize: 12))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
            child: Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
