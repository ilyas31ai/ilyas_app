import 'package:flutter/material.dart';
import '../models/note_model.dart';
import '../models/user_model.dart';
import '../services/etudiant_service.dart';
import '../widgets/cycle_access_guard.dart';

const _kColors = [Color(0xFF6C47FF), Color(0xFF1E3A5F)];

class LyceeOrientationPage extends StatelessWidget {
  const LyceeOrientationPage({super.key});

  @override
  Widget build(BuildContext context) {
    return CycleAccessGuard(
      cycleCategorie: 'Lycée',
      cycleColors: _kColors,
      builder: (user) => _Body(user: user),
    );
  }
}

class _Body extends StatelessWidget {
  final UserModel user;
  const _Body({required this.user});

  String get _classeNom => user.classeNom ?? user.niveau ?? '';

  static const _domaines = [
    _Domaine(
      icon: Icons.healing_outlined,
      nom: 'Sciences de la Santé',
      formations: ['Médecine (7 ans)', 'Pharmacie (5 ans)', 'Médecine dentaire (5 ans)', 'Sciences infirmières'],
      bac: ['Sciences Expérimentales'],
      color: Color(0xFFDC2626),
      moyenneMin: 15.0,
    ),
    _Domaine(
      icon: Icons.engineering_outlined,
      nom: 'Sciences de l\'Ingénieur',
      formations: ['Génie civil', 'Génie mécanique', 'Génie électrique', 'Informatique industrielle'],
      bac: ['Mathématiques', 'Technique Mathématique'],
      color: Color(0xFF2563EB),
      moyenneMin: 13.0,
    ),
    _Domaine(
      icon: Icons.computer_outlined,
      nom: 'Informatique & TIC',
      formations: ['Licence Informatique', 'Mathématiques-Informatique', 'Systèmes & Réseaux', 'Intelligence artificielle'],
      bac: ['Mathématiques', 'Sciences Expérimentales'],
      color: Color(0xFF0891B2),
      moyenneMin: 12.0,
    ),
    _Domaine(
      icon: Icons.gavel_outlined,
      nom: 'Droit & Sciences Politiques',
      formations: ['Droit', 'Sciences politiques', 'Administration', 'Relations internationales'],
      bac: ['Lettres et Philosophie', 'Langues Étrangères'],
      color: Color(0xFFBE185D),
      moyenneMin: 11.0,
    ),
    _Domaine(
      icon: Icons.trending_up_outlined,
      nom: 'Sciences Économiques',
      formations: ['Commerce', 'Finance', 'Management', 'Audit et contrôle de gestion'],
      bac: ['Gestion et Économie', 'Mathématiques'],
      color: Color(0xFFD97706),
      moyenneMin: 11.0,
    ),
    _Domaine(
      icon: Icons.translate_outlined,
      nom: 'Langues & Lettres',
      formations: ['Littérature arabe', 'Français', 'Traduction', 'Langues appliquées'],
      bac: ['Lettres et Philosophie', 'Langues Étrangères'],
      color: Color(0xFF7C3AED),
      moyenneMin: 10.0,
    ),
    _Domaine(
      icon: Icons.agriculture_outlined,
      nom: 'Sciences Agronomiques',
      formations: ['Agronomie', 'Biologie végétale', 'Vétérinaire', 'Agroalimentaire'],
      bac: ['Sciences Expérimentales'],
      color: Color(0xFF15803D),
      moyenneMin: 12.0,
    ),
  ];

  static const _etapes = [
    (etape: '1', label: 'BAC obtenu', desc: 'Obtention du baccalauréat avec mention si possible'),
    (etape: '2', label: 'Inscription PROGRES', desc: 'Saisie des vœux sur le portail MESRS (progressnation.dz)'),
    (etape: '3', label: 'Classement & Affectation', desc: 'Affectation automatique selon la moyenne et les vœux'),
    (etape: '4', label: 'Inscription à l\'université', desc: 'Validation de l\'inscription à l\'établissement affecté'),
    (etape: '5', label: 'Début des cours', desc: 'Intégration dans la formation et début du cursus universitaire'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        elevation: 0,
        title: const Text('Orientation Post-BAC', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
      ),
      body: _classeNom.isEmpty
          ? _StaticContent(user: user, domaines: _domaines, etapes: _etapes)
          : StreamBuilder<List<NoteModel>>(
              stream: EtudiantService.notesStream(_classeNom),
              builder: (_, snap) {
                final notes = snap.data ?? [];
                final moyenne = notes.isEmpty
                    ? null
                    : notes.fold<double>(0, (a, n) => a + n.sur20) / notes.length;
                return _StaticContent(
                  user: user,
                  domaines: _domaines,
                  etapes: _etapes,
                  moyenne: moyenne,
                );
              },
            ),
    );
  }
}

// ── Contenu principal ─────────────────────────────────────────────────────────

class _StaticContent extends StatelessWidget {
  final UserModel user;
  final List<_Domaine> domaines;
  final List<({String etape, String label, String desc})> etapes;
  final double? moyenne;
  const _StaticContent({
    required this.user,
    required this.domaines,
    required this.etapes,
    this.moyenne,
  });

  @override
  Widget build(BuildContext context) {
    final recommandes = moyenne == null
        ? <_Domaine>[]
        : domaines.where((d) => moyenne! >= d.moyenneMin).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        _HeaderBanner(niveau: user.niveau, moyenne: moyenne),
        if (moyenne != null) ...[
          const SizedBox(height: 16),
          _ProfilCard(moyenne: moyenne!),
        ],
        if (recommandes.isNotEmpty) ...[
          const SizedBox(height: 20),
          _sectionLabel('Filières recommandées pour vous'),
          const SizedBox(height: 10),
          ...recommandes.map((d) => _DomaineCard(domaine: d, highlighted: true)),
        ],
        const SizedBox(height: 20),
        _sectionLabel('Tous les parcours universitaires'),
        const SizedBox(height: 10),
        ...domaines.map((d) => _DomaineCard(
              domaine: d,
              highlighted: false,
              dimmed: moyenne != null && moyenne! < d.moyenneMin,
            )),
        const SizedBox(height: 20),
        _sectionLabel('Calendrier d\'orientation'),
        const SizedBox(height: 10),
        _CalendrierCard(etapes: etapes),
        const SizedBox(height: 20),
        _sectionLabel('Conseils clés'),
        const SizedBox(height: 10),
        const _ConseilsList(),
      ],
    );
  }

  static Widget _sectionLabel(String t) => Text(
    t.toUpperCase(),
    style: const TextStyle(
        color: Colors.white38, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2),
  );
}

// ── En-tête ───────────────────────────────────────────────────────────────────

class _HeaderBanner extends StatelessWidget {
  final String? niveau;
  final double? moyenne;
  const _HeaderBanner({this.niveau, this.moyenne});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: _kColors, begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Post-BAC · Université', style: TextStyle(color: Colors.white70, fontSize: 12)),
                const Text('Orientation Supérieure',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(niveau ?? 'Secondaire · Algérie', style: const TextStyle(color: Colors.white60, fontSize: 12)),
                if (moyenne != null)
                  Text('Moyenne actuelle : ${moyenne!.toStringAsFixed(2)}/20',
                      style: const TextStyle(color: Colors.white54, fontSize: 12)),
              ],
            ),
          ),
          const Icon(Icons.school_outlined, color: Colors.white24, size: 52),
        ],
      ),
    );
  }
}

// ── Profil personnalisé ───────────────────────────────────────────────────────

class _ProfilCard extends StatelessWidget {
  final double moyenne;
  const _ProfilCard({required this.moyenne});

  Color get _color => moyenne >= 14 ? Colors.green : moyenne >= 10 ? Colors.amber : Colors.red;

  String get _label {
    if (moyenne >= 16) return 'Profil Excellence — toutes les filières accessibles';
    if (moyenne >= 14) return 'Bon profil — filières sélectives à portée';
    if (moyenne >= 12) return 'Profil correct — choix ciblés recommandés';
    if (moyenne >= 10) return 'Profil moyen — préparez votre projet d\'orientation';
    return 'Profil fragile — renforcez vos résultats avant le BAC';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.person_outline, color: _color, size: 16),
              const SizedBox(width: 8),
              Text('Mon profil BAC', style: TextStyle(color: _color, fontWeight: FontWeight.w600, fontSize: 13)),
              const Spacer(),
              Text('${moyenne.toStringAsFixed(2)}/20',
                  style: TextStyle(color: _color, fontWeight: FontWeight.bold, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: moyenne / 20,
              backgroundColor: Colors.white.withValues(alpha: 0.1),
              valueColor: AlwaysStoppedAnimation<Color>(_color),
              minHeight: 4,
            ),
          ),
          const SizedBox(height: 8),
          Text(_label, style: const TextStyle(color: Colors.white60, fontSize: 12, height: 1.4)),
        ],
      ),
    );
  }
}

// ── Modèle domaine ────────────────────────────────────────────────────────────

class _Domaine {
  final IconData icon;
  final String nom;
  final List<String> formations;
  final List<String> bac;
  final Color color;
  final double moyenneMin;
  const _Domaine({
    required this.icon,
    required this.nom,
    required this.formations,
    required this.bac,
    required this.color,
    required this.moyenneMin,
  });
}

// ── Carte domaine (dépliable) ─────────────────────────────────────────────────

class _DomaineCard extends StatefulWidget {
  final _Domaine domaine;
  final bool highlighted;
  final bool dimmed;
  const _DomaineCard({required this.domaine, this.highlighted = false, this.dimmed = false});

  @override
  State<_DomaineCard> createState() => _DomaineCardState();
}

class _DomaineCardState extends State<_DomaineCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final d = widget.domaine;
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: widget.dimmed ? 0.45 : 1.0,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF161B22),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: widget.highlighted && !widget.dimmed
                ? d.color.withValues(alpha: 0.5)
                : _expanded
                    ? d.color.withValues(alpha: 0.25)
                    : Colors.white.withValues(alpha: 0.05),
            width: widget.highlighted ? 1.5 : 1.0,
          ),
        ),
        child: Column(
          children: [
            InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                          color: d.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                      child: Icon(d.icon, color: d.color, size: 21),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(d.nom,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                          Text('Moy. min. ${d.moyenneMin.toStringAsFixed(0)}/20',
                              style: const TextStyle(color: Colors.white38, fontSize: 11)),
                        ],
                      ),
                    ),
                    if (widget.highlighted)
                      Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                            color: d.color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
                        child: Text('Recommandé', style: TextStyle(color: d.color, fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                    Icon(_expanded ? Icons.expand_less : Icons.expand_more, color: Colors.white38, size: 20),
                  ],
                ),
              ),
            ),
            if (_expanded) ...[
              const Divider(color: Colors.white10, height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Subsection('Formations disponibles', d.formations, d.color),
                    const SizedBox(height: 10),
                    Text('BAC requis : ${d.bac.join(' / ')}',
                        style: const TextStyle(color: Colors.white38, fontSize: 11)),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Subsection extends StatelessWidget {
  final String title;
  final List<String> items;
  final Color color;
  const _Subsection(this.title, this.items, this.color);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        ...items.map((item) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            children: [
              Icon(Icons.circle, color: color, size: 5),
              const SizedBox(width: 8),
              Expanded(child: Text(item, style: const TextStyle(color: Colors.white70, fontSize: 12))),
            ],
          ),
        )),
      ],
    );
  }
}

// ── Calendrier orientation ────────────────────────────────────────────────────

class _CalendrierCard extends StatelessWidget {
  final List<({String etape, String label, String desc})> etapes;
  const _CalendrierCard({required this.etapes});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        children: List.generate(etapes.length, (i) {
          final e = etapes[i];
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Container(
                    width: 28, height: 28,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E3A5F),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFF6C47FF), width: 1.5),
                    ),
                    child: Center(
                      child: Text(e.etape,
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  if (i < etapes.length - 1)
                    Container(width: 1, height: 36, color: Colors.white12),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(e.label,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                      const SizedBox(height: 2),
                      Text(e.desc, style: const TextStyle(color: Colors.white38, fontSize: 12)),
                    ],
                  ),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}

// ── Conseils ──────────────────────────────────────────────────────────────────

class _ConseilsList extends StatelessWidget {
  const _ConseilsList();

  static const _conseils = [
    'Viser une moyenne ≥ 14 pour être compétitif dans les filières sélectives',
    'Bien réfléchir à ses vœux par ordre de préférence réaliste',
    'Contacter les universités pour des journées portes ouvertes',
    'Consulter le CNPLET pour des conseils d\'orientation personnalisés',
    'Garder en tête ses points forts et sa vocation professionnelle',
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF374151).withValues(alpha: 0.4)),
      ),
      child: Column(
        children: _conseils.map((c) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.lightbulb_outline, color: Color(0xFFD97706), size: 16),
              const SizedBox(width: 8),
              Expanded(child: Text(c, style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4))),
            ],
          ),
        )).toList(),
      ),
    );
  }
}
