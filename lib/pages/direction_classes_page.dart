import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/classe_model.dart';
import '../models/user_model.dart';

const Map<String, List<String>> _kNiveaux = {
  'Maternelle': ['PS', 'MS', 'GS'],
  'Primaire': ['CP', 'CE1', 'CE2', 'CM1', 'CM2'],
  'Collège': ['6e', '5e', '4e', '3e'],
  'Lycée': ['Seconde', 'Première', 'Terminale'],
  'Université': ['L1', 'L2', 'L3', 'M1', 'M2', 'Doctorat'],
};

/// Page Direction — gestion des classes et affectation des professeurs.
class DirectionClassesPage extends StatefulWidget {
  const DirectionClassesPage({super.key});

  @override
  State<DirectionClassesPage> createState() => _DirectionClassesPageState();
}

class _DirectionClassesPageState extends State<DirectionClassesPage> {
  static final _fs = FirebaseFirestore.instance;
  List<UserModel> _profs = [];

  @override
  void initState() {
    super.initState();
    _loadProfs();
  }

  Future<void> _loadProfs() async {
    try {
      final snap = await _fs
          .collection('users')
          .where('role', isEqualTo: 'professeur')
          .get();
      if (!mounted) return;
      setState(() {
        _profs = snap.docs.map(UserModel.fromDoc).toList()
          ..sort((a, b) => a.displayName.compareTo(b.displayName));
      });
    } catch (e) {
      debugPrint('[DirectionClasses] _loadProfs ERROR: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Impossible de charger la liste des professeurs.'),
          backgroundColor: const Color(0xFFDC2626),
        ));
      }
    }
  }

  UserModel? _profForId(String id) {
    if (id.isEmpty) return null;
    final matches = _profs.where((p) => p.uid == id);
    return matches.isEmpty ? null : matches.first;
  }

  // ── Créer une classe ──────────────────────────────────────────────────────

  Future<void> _showCreateDialog(BuildContext context) async {
    final nomCtrl = TextEditingController();
    String? selectedNiveau;
    UserModel? selectedProf;
    bool busy = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          backgroundColor: const Color(0xFF161B22),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Créer une classe',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _field(nomCtrl, 'Nom (ex : 6ème A)', Icons.class_outlined),
                const SizedBox(height: 12),
                _dropdown<String>(
                  value: selectedNiveau,
                  hint: 'Niveau',
                  items: _kNiveaux.values
                      .expand((e) => e)
                      .map((n) => DropdownMenuItem(
                            value: n,
                            child: Text(n,
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 13)),
                          ))
                      .toList(),
                  onChanged: (v) => setDlg(() => selectedNiveau = v),
                ),
                const SizedBox(height: 12),
                _dropdown<UserModel>(
                  value: selectedProf,
                  hint: 'Assigner un professeur (optionnel)',
                  items: _profs
                      .map((p) => DropdownMenuItem(
                            value: p,
                            child: Text(
                              p.displayName.isNotEmpty ? p.displayName : p.email,
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 13),
                            ),
                          ))
                      .toList(),
                  onChanged: (v) => setDlg(() => selectedProf = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: busy ? null : () => Navigator.pop(ctx),
              child:
                  const Text('Annuler', style: TextStyle(color: Colors.white60)),
            ),
            TextButton(
              onPressed: busy
                  ? null
                  : () async {
                      final nom = nomCtrl.text.trim();
                      if (nom.isEmpty || selectedNiveau == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Remplissez le nom et le niveau'),
                            backgroundColor: Color(0xFFDC2626),
                          ),
                        );
                        return;
                      }
                      setDlg(() => busy = true);
                      try {
                        await _fs.collection('classes').add({
                          'nom': nom,
                          'niveau': selectedNiveau,
                          'professeurId': selectedProf?.uid ?? '',
                          'professeurEmail': selectedProf?.email ?? '',
                          'professeurDisplayName': selectedProf != null
                              ? (selectedProf!.displayName.isNotEmpty
                                  ? selectedProf!.displayName
                                  : selectedProf!.username)
                              : '',
                          'professeurMatiere': selectedProf?.matiere ?? '',
                          'eleveIds': <String>[],
                          'anneeScol': DateTime.now().year,
                        });
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text('Classe $nom créée'),
                            backgroundColor: const Color(0xFF16A34A),
                          ));
                        }
                      } catch (e) {
                        setDlg(() => busy = false);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text('Erreur : $e'),
                            backgroundColor: const Color(0xFFDC2626),
                          ));
                        }
                      }
                    },
              child: busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Color(0xFF2563EB)))
                  : const Text('Créer',
                      style: TextStyle(
                          color: Color(0xFF2563EB),
                          fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
    nomCtrl.dispose();
  }

  // ── Assigner professeur ───────────────────────────────────────────────────

  Future<void> _showAssignProfDialog(
      BuildContext context, ClasseModel classe) async {
    UserModel? selected = _profForId(classe.professeurId);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          backgroundColor: const Color(0xFF161B22),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Professeur — ${classe.nom}',
            style: const TextStyle(
                color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
          ),
          content: _profs.isEmpty
              ? const Text('Aucun professeur inscrit.',
                  style: TextStyle(color: Color(0xFFD97706), fontSize: 13))
              : _dropdown<UserModel>(
                  value: selected,
                  hint: 'Choisir un professeur',
                  items: _profs
                      .map((p) => DropdownMenuItem(
                            value: p,
                            child: Text(
                              p.displayName.isNotEmpty ? p.displayName : p.email,
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 13),
                            ),
                          ))
                      .toList(),
                  onChanged: (v) => setDlg(() => selected = v),
                ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler',
                  style: TextStyle(color: Colors.white60)),
            ),
            if (_profs.isNotEmpty)
              TextButton(
                onPressed:
                    selected == null ? null : () => Navigator.pop(ctx, true),
                child: Text(
                  'Confirmer',
                  style: TextStyle(
                    color: selected == null
                        ? Colors.white24
                        : const Color(0xFF2563EB),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
      ),
    );

    if (confirmed != true || selected == null) return;
    try {
      final profData = {
        'professeurId': selected!.uid,
        'professeurEmail': selected!.email,
        'professeurDisplayName': selected!.displayName.isNotEmpty
            ? selected!.displayName
            : selected!.username,
        'professeurMatiere': selected!.matiere ?? '',
      };
      await _fs.collection('classes').doc(classe.id).update(profData);

      // Propager les infos du prof dans le profil de chaque élève de la classe
      final eleveProfData = {
        'profId': selected!.uid,
        'profEmail': selected!.email,
        'profDisplayName': selected!.displayName.isNotEmpty
            ? selected!.displayName
            : selected!.username,
        'profMatiere': selected!.matiere ?? '',
      };
      final failedEleveIds = <String>[];
      for (final eleveId in classe.eleveIds) {
        try {
          await _fs.collection('users').doc(eleveId).update(eleveProfData);
        } catch (e) {
          debugPrint('[DirectionClasses] propagation prof → élève $eleveId ERROR: $e');
          failedEleveIds.add(eleveId);
        }
      }
      if (failedEleveIds.isNotEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              '${failedEleveIds.length} élève(s) non mis à jour (erreur réseau/permission).'),
          backgroundColor: const Color(0xFFD97706),
        ));
      }

      if (mounted) {
        final name = selected!.displayName.isNotEmpty
            ? selected!.displayName
            : selected!.email;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('$name assigné à ${classe.nom}'),
          backgroundColor: const Color(0xFF16A34A),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erreur : $e'),
          backgroundColor: const Color(0xFFDC2626),
        ));
      }
    }
  }

  // ── UI helpers ────────────────────────────────────────────────────────────

  Widget _field(
      TextEditingController ctrl, String hint, IconData icon) {
    return TextField(
      controller: ctrl,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
        prefixIcon: Icon(icon, color: Colors.white38, size: 18),
        filled: true,
        fillColor: const Color(0xFF0D1117),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide:
                BorderSide(color: Colors.white.withValues(alpha: 0.1))),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide:
                BorderSide(color: Colors.white.withValues(alpha: 0.1))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFF2563EB))),
      ),
    );
  }

  Widget _dropdown<T>({
    required T? value,
    required String hint,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?>? onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1117),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          dropdownColor: const Color(0xFF161B22),
          hint: Text(hint,
              style: const TextStyle(color: Colors.white38, fontSize: 13)),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        elevation: 0,
        title: const Text(
          'Gestion des classes',
          style: TextStyle(
              color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF2563EB),
        tooltip: 'Créer une classe',
        onPressed: () => _showCreateDialog(context),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _fs.collection('classes').orderBy('nom').snapshots(),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
                child:
                    CircularProgressIndicator(color: Color(0xFF2563EB)));
          }
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Erreur : ${snap.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                ),
              ),
            );
          }
          final classes = (snap.data?.docs ?? [])
              .map(ClasseModel.fromFirestore)
              .toList();

          if (classes.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.school_outlined,
                        color: Colors.white24, size: 52),
                    const SizedBox(height: 14),
                    const Text(
                      'Aucune classe créée.',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Utilisez + pour créer la première classe\net assigner un professeur.',
                      textAlign: TextAlign.center,
                      style:
                          TextStyle(color: Colors.white38, fontSize: 13),
                    ),
                  ],
                ),
              ),
            );
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                child: Row(
                  children: [
                    Text(
                      '${classes.length} classe${classes.length != 1 ? 's' : ''}',
                      style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                          fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '${classes.where((c) => c.professeurId.isNotEmpty).length} avec professeur',
                      style: const TextStyle(
                          color: Color(0xFF0F766E), fontSize: 12),
                    ),
                    if (classes.any((c) => c.professeurId.isEmpty)) ...[
                      const SizedBox(width: 12),
                      Text(
                        '${classes.where((c) => c.professeurId.isEmpty).length} sans professeur',
                        style: const TextStyle(
                            color: Color(0xFFD97706), fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                  itemCount: classes.length,
                  itemBuilder: (_, i) {
                    final classe = classes[i];
                    final prof = _profForId(classe.professeurId);
                    final hasProf = prof != null;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 13),
                      decoration: BoxDecoration(
                        color: const Color(0xFF161B22),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: hasProf
                              ? Colors.white.withValues(alpha: 0.05)
                              : const Color(0xFFD97706)
                                  .withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F766E)
                                  .withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.school_outlined,
                                color: Color(0xFF0F766E), size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${classe.nom}  ·  ${classe.niveau}',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14),
                                ),
                                const SizedBox(height: 3),
                                if (hasProf)
                                  Row(
                                    children: [
                                      const Icon(Icons.person_outline,
                                          color: Color(0xFF0F766E),
                                          size: 12),
                                      const SizedBox(width: 4),
                                      Text(
                                        prof.displayName.isNotEmpty
                                            ? prof.displayName
                                            : prof.email,
                                        style: const TextStyle(
                                            color: Color(0xFF0F766E),
                                            fontSize: 12),
                                      ),
                                    ],
                                  )
                                else
                                  const Text('⚠ Aucun professeur assigné',
                                      style: TextStyle(
                                          color: Color(0xFFD97706),
                                          fontSize: 12)),
                                const SizedBox(height: 2),
                                Text(
                                  '${classe.nbEleves} élève${classe.nbEleves != 1 ? 's' : ''}',
                                  style: const TextStyle(
                                      color: Colors.white38, fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              hasProf
                                  ? Icons.swap_horiz
                                  : Icons.person_add_outlined,
                              color: hasProf
                                  ? Colors.white38
                                  : const Color(0xFFD97706),
                              size: 20,
                            ),
                            tooltip: hasProf
                                ? 'Changer le professeur'
                                : 'Assigner un professeur',
                            onPressed: () =>
                                _showAssignProfDialog(context, classe),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
