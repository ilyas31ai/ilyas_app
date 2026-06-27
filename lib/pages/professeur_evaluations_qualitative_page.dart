import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/classe_model.dart';
import '../services/professeur_service.dart';

class ProfesseurEvaluationsQualitativePage extends StatefulWidget {
  const ProfesseurEvaluationsQualitativePage({super.key});

  @override
  State<ProfesseurEvaluationsQualitativePage> createState() =>
      _ProfesseurEvaluationsQualitativePageState();
}

class _ProfesseurEvaluationsQualitativePageState
    extends State<ProfesseurEvaluationsQualitativePage> {
  List<ClasseModel> _classes = [];
  ClasseModel? _selectedClasse;
  bool _classesLoaded = false;

  @override
  void initState() {
    super.initState();
    ProfesseurService.classesStream().first.then((c) {
      if (mounted) {
        setState(() {
          _classes = c;
          _classesLoaded = true;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        elevation: 0,
        title: const Text('Évaluations qualitatives',
            style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          _HeaderBanner(),
          _ClassePicker(
            classes: _classes,
            loaded: _classesLoaded,
            selected: _selectedClasse,
            onChanged: (c) => setState(() => _selectedClasse = c),
          ),
          Expanded(
            child: _selectedClasse == null
                ? _NoClasseSelected()
                : _ElevesEvaluations(classe: _selectedClasse!),
          ),
        ],
      ),
    );
  }
}

class _HeaderBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [Color(0xFFEC4899), Color(0xFF9333EA)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Maternelle', style: TextStyle(color: Colors.white70, fontSize: 11)),
                Text('Compétences par domaine',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold)),
                Text('Grille Acquis / En cours / Non acquis',
                    style: TextStyle(color: Colors.white60, fontSize: 11)),
              ],
            ),
          ),
          Icon(Icons.child_care, color: Colors.white24, size: 40),
        ],
      ),
    );
  }
}

class _ClassePicker extends StatelessWidget {
  final List<ClasseModel> classes;
  final bool loaded;
  final ClasseModel? selected;
  final void Function(ClasseModel?) onChanged;
  const _ClassePicker(
      {required this.classes,
      required this.loaded,
      required this.selected,
      required this.onChanged});

  @override
  Widget build(BuildContext context) {
    if (!loaded) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: LinearProgressIndicator(color: Color(0xFFEC4899)),
      );
    }
    if (classes.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text('Aucune classe assignée',
            style: TextStyle(color: Colors.white38, fontSize: 13)),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: DropdownButtonFormField<ClasseModel>(
        value: selected,
        dropdownColor: const Color(0xFF161B22),
        style: const TextStyle(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          labelText: 'Sélectionner une classe',
          labelStyle: const TextStyle(color: Colors.white38),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFEC4899)),
          ),
        ),
        items: classes
            .map((c) => DropdownMenuItem(
                value: c,
                child: Text(c.nom,
                    style: const TextStyle(color: Colors.white))))
            .toList(),
        onChanged: onChanged,
      ),
    );
  }
}

class _NoClasseSelected extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.class_outlined, color: Colors.white24, size: 48),
          SizedBox(height: 12),
          Text('Sélectionnez une classe',
              style: TextStyle(color: Colors.white38, fontSize: 14)),
        ],
      ),
    );
  }
}

// ─── Élèves + évaluations ─────────────────────────────────────────────────────

class _ElevesEvaluations extends StatelessWidget {
  final ClasseModel classe;
  const _ElevesEvaluations({required this.classe});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: ProfesseurService.elevesParClasseStream(classe.nom),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: Color(0xFFEC4899)));
        }
        final eleves = snap.data ?? [];
        if (eleves.isEmpty) {
          return const Center(
            child: Text('Aucun élève dans cette classe',
                style: TextStyle(color: Colors.white38, fontSize: 13)),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          itemCount: eleves.length,
          itemBuilder: (ctx, i) => _EleveCard(
            eleve: eleves[i],
            classeId: classe.id,
            classeNom: classe.nom,
          ),
        );
      },
    );
  }
}

// ─── Domaines et compétences ──────────────────────────────────────────────────

const _kDomaines = [
  _Domaine('Langage & Communication', Icons.chat_bubble_outline,
      Color(0xFF2563EB), [
    'S\'exprimer en phrases',
    'Comprendre une consigne',
    'Raconter une histoire',
    'Répondre à une question',
  ]),
  _Domaine('Découverte du Monde', Icons.science_outlined, Color(0xFF0891B2), [
    'Observer et décrire',
    'Trier et classer',
    'Identifier des quantités',
    'Situer dans le temps',
  ]),
  _Domaine('Motricité Globale', Icons.directions_run_outlined, Color(0xFF15803D),
      [
        'Courir sans tomber',
        'Sauter à pieds joints',
        'Lancer et attraper',
        'Monter / descendre',
      ]),
  _Domaine('Motricité Fine', Icons.brush_outlined, Color(0xFF7C3AED), [
    'Tenir un crayon',
    'Découper avec des ciseaux',
    'Coller et assembler',
    'Tracer des formes',
  ]),
  _Domaine('Vie en Collectivité', Icons.people_outline, Color(0xFFD97706), [
    'Respecter les règles',
    'Partager et coopérer',
    'S\'habiller seul',
    'Ranger son matériel',
  ]),
  _Domaine('Arts & Créativité', Icons.palette_outlined, Color(0xFFEC4899), [
    'Chanter une comptine',
    'Réaliser un dessin',
    'Utiliser la peinture',
    'Imiter et jouer',
  ]),
];

class _Domaine {
  final String nom;
  final IconData icon;
  final Color color;
  final List<String> competences;
  const _Domaine(this.nom, this.icon, this.color, this.competences);
}

// ─── Carte élève (expansible) ─────────────────────────────────────────────────

class _EleveCard extends StatefulWidget {
  final Map<String, dynamic> eleve;
  final String classeId;
  final String classeNom;
  const _EleveCard(
      {required this.eleve,
      required this.classeId,
      required this.classeNom});

  @override
  State<_EleveCard> createState() => _EleveCardState();
}

class _EleveCardState extends State<_EleveCard> {
  bool _expanded = false;

  String get _nom {
    final prenom = widget.eleve['prenom'] as String? ?? '';
    final nom = widget.eleve['nom'] as String? ?? '';
    return '$prenom $nom'.trim().isEmpty
        ? widget.eleve['displayName'] as String? ?? 'Élève'
        : '$prenom $nom'.trim();
  }

  String get _eleveId => widget.eleve['id'] as String? ?? '';

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEC4899).withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        _nom.isNotEmpty ? _nom[0].toUpperCase() : '?',
                        style: const TextStyle(
                            color: Color(0xFFEC4899),
                            fontWeight: FontWeight.bold,
                            fontSize: 16),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(_nom,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 14)),
                  ),
                  Icon(
                    _expanded
                        ? Icons.expand_less
                        : Icons.expand_more,
                    color: Colors.white38,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
          if (_expanded) ...[
            const Divider(color: Colors.white10, height: 1),
            if (_eleveId.isEmpty)
              const Padding(
                padding: EdgeInsets.all(14),
                child: Text('ID élève introuvable',
                    style: TextStyle(color: Colors.white38, fontSize: 12)),
              )
            else
              _EleveEvaluationForm(
                eleveId: _eleveId,
                eleveNom: _nom,
                classeId: widget.classeId,
                classeNom: widget.classeNom,
              ),
          ],
        ],
      ),
    );
  }
}

// ─── Formulaire évaluation par domaine ───────────────────────────────────────

class _EleveEvaluationForm extends StatefulWidget {
  final String eleveId;
  final String eleveNom;
  final String classeId;
  final String classeNom;
  const _EleveEvaluationForm(
      {required this.eleveId,
      required this.eleveNom,
      required this.classeId,
      required this.classeNom});

  @override
  State<_EleveEvaluationForm> createState() => _EleveEvaluationFormState();
}

class _EleveEvaluationFormState extends State<_EleveEvaluationForm> {
  // key = 'domaine||competence', value = 'acquis'|'en_cours'|'non_acquis'
  final Map<String, String> _niveaux = {};
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadExisting();
  }

  Future<void> _loadExisting() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('competences_maternelle')
          .where('eleveId', isEqualTo: widget.eleveId)
          .get();
      final map = <String, String>{};
      for (final doc in snap.docs) {
        final data = doc.data();
        final domaine = data['domaine'] as String? ?? '';
        final competence = data['competence'] as String? ?? '';
        final niveau = data['niveau'] as String? ?? '';
        if (domaine.isNotEmpty && competence.isNotEmpty && niveau.isNotEmpty) {
          map['$domaine||$competence'] = niveau;
        }
      }
      if (mounted) setState(() { _niveaux.addAll(map); _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final batch = FirebaseFirestore.instance.batch();
      for (final entry in _niveaux.entries) {
        final parts = entry.key.split('||');
        if (parts.length != 2) continue;
        final domaine = parts[0];
        final competence = parts[1];
        final docId =
            '${widget.eleveId}_${domaine.replaceAll(' ', '_')}_${competence.replaceAll(' ', '_')}';
        final ref = FirebaseFirestore.instance
            .collection('competences_maternelle')
            .doc(docId);
        batch.set(ref, {
          'eleveId': widget.eleveId,
          'eleveNom': widget.eleveNom,
          'classeId': widget.classeId,
          'classeNom': widget.classeNom,
          'domaine': domaine,
          'competence': competence,
          'niveau': entry.value,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Évaluations enregistrées'),
          backgroundColor: Color(0xFF15803D),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erreur : $e'),
          backgroundColor: const Color(0xFFDC2626),
          duration: const Duration(seconds: 6),
        ));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: LinearProgressIndicator(color: Color(0xFFEC4899)),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      child: Column(
        children: [
          ..._kDomaines.map((d) => _DomaineSection(
                domaine: d,
                niveaux: _niveaux,
                onChanged: (key, val) =>
                    setState(() => _niveaux[key] = val),
              )),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEC4899),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12)),
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Text('Enregistrer',
                      style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}

class _DomaineSection extends StatelessWidget {
  final _Domaine domaine;
  final Map<String, String> niveaux;
  final void Function(String key, String val) onChanged;
  const _DomaineSection(
      {required this.domaine,
      required this.niveaux,
      required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: domaine.color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: domaine.color.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
            child: Row(
              children: [
                Icon(domaine.icon, color: domaine.color, size: 16),
                const SizedBox(width: 6),
                Text(
                  domaine.nom,
                  style: TextStyle(
                      color: domaine.color,
                      fontWeight: FontWeight.w700,
                      fontSize: 12),
                ),
              ],
            ),
          ),
          ...domaine.competences.map((c) {
            final key = '${domaine.nom}||$c';
            final current = niveaux[key] ?? '';
            return Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(c,
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 12)),
                  const SizedBox(height: 4),
                  _NiveauToggle(
                    current: current,
                    color: domaine.color,
                    onChanged: (v) => onChanged(key, v),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _NiveauToggle extends StatelessWidget {
  final String current;
  final Color color;
  final void Function(String) onChanged;
  const _NiveauToggle(
      {required this.current,
      required this.color,
      required this.onChanged});

  static const _options = [
    ('acquis', 'Acquis', Color(0xFF15803D)),
    ('en_cours', 'En cours', Color(0xFFD97706)),
    ('non_acquis', 'Non acquis', Color(0xFFDC2626)),
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: _options.map((opt) {
        final (val, label, optColor) = opt;
        final active = current == val;
        return GestureDetector(
          onTap: () => onChanged(val),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            margin: const EdgeInsets.only(right: 6),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: active
                  ? optColor.withValues(alpha: 0.2)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                  color: active
                      ? optColor
                      : Colors.white.withValues(alpha: 0.12),
                  width: active ? 1.2 : 1),
            ),
            child: Text(
              label,
              style: TextStyle(
                  color: active ? optColor : Colors.white38,
                  fontSize: 10,
                  fontWeight:
                      active ? FontWeight.w700 : FontWeight.normal),
            ),
          ),
        );
      }).toList(),
    );
  }
}
