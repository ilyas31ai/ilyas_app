import 'package:flutter/material.dart';

import '../models/document_model.dart';
import '../services/professeur_service.dart';

class ProfesseurBibliothequePage extends StatefulWidget {
  const ProfesseurBibliothequePage({super.key});

  @override
  State<ProfesseurBibliothequePage> createState() =>
      _ProfesseurBibliothequePageState();
}

class _ProfesseurBibliothequePageState
    extends State<ProfesseurBibliothequePage> {
  String _filterType = '';
  String _search = '';
  final _searchCtrl = TextEditingController();

  static const _typeColors = {
    'cours': Color(0xFF0F766E),
    'exercice': Color(0xFF2563EB),
    'correction': Color(0xFF15803D),
    'video': Color(0xFF7C3AED),
    'autre': Color(0xFF374151),
  };

  static const _typeIcons = {
    'cours': Icons.menu_book_outlined,
    'exercice': Icons.assignment_outlined,
    'correction': Icons.task_alt_outlined,
    'video': Icons.play_circle_outlined,
    'autre': Icons.insert_drive_file_outlined,
  };

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        elevation: 0,
        title: const Text('Bibliothèque',
            style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          _SearchBar(ctrl: _searchCtrl, onChanged: (v) => setState(() => _search = v)),
          _TypeFilter(
            selected: _filterType,
            onChanged: (t) => setState(() => _filterType = t),
          ),
          Expanded(
            child: StreamBuilder<List<DocumentPedagogique>>(
              stream: ProfesseurService.documentsStream(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child: CircularProgressIndicator(
                          color: Color(0xFF0F766E)));
                }
                if (snap.hasError) {
                  return Center(
                    child: Text('Erreur : ${snap.error}',
                        style: const TextStyle(
                            color: Color(0xFFDC2626), fontSize: 13)),
                  );
                }
                var docs = snap.data ?? [];
                if (_filterType.isNotEmpty) {
                  docs = docs.where((d) => d.type == _filterType).toList();
                }
                if (_search.isNotEmpty) {
                  final q = _search.toLowerCase();
                  docs = docs
                      .where((d) =>
                          d.titre.toLowerCase().contains(q) ||
                          d.matiere.toLowerCase().contains(q) ||
                          d.classeNom.toLowerCase().contains(q) ||
                          d.description.toLowerCase().contains(q))
                      .toList();
                }
                if (docs.isEmpty) {
                  return _EmptyState(
                    hasFilter: _filterType.isNotEmpty || _search.isNotEmpty,
                  );
                }
                final grouped = _groupByMatiere(docs);
                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  children: grouped.entries.map((entry) {
                    return _MatiereSection(
                      matiere: entry.key,
                      docs: entry.value,
                      typeColors: _typeColors,
                      typeIcons: _typeIcons,
                    );
                  }).toList(),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Map<String, List<DocumentPedagogique>> _groupByMatiere(
      List<DocumentPedagogique> docs) {
    final map = <String, List<DocumentPedagogique>>{};
    for (final d in docs) {
      (map[d.matiere.isNotEmpty ? d.matiere : 'Sans matière'] ??= []).add(d);
    }
    final sorted = Map.fromEntries(
        map.entries.toList()..sort((a, b) => a.key.compareTo(b.key)));
    return sorted;
  }
}

class _SearchBar extends StatelessWidget {
  final TextEditingController ctrl;
  final void Function(String) onChanged;
  const _SearchBar({required this.ctrl, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF161B22),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: TextField(
        controller: ctrl,
        onChanged: onChanged,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Rechercher titre, matière, classe…',
          hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
          prefixIcon: const Icon(Icons.search, color: Colors.white38, size: 20),
          suffixIcon: ctrl.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, color: Colors.white38, size: 18),
                  onPressed: () {
                    ctrl.clear();
                    onChanged('');
                  },
                )
              : null,
          filled: true,
          fillColor: const Color(0xFF0D1117),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}

class _TypeFilter extends StatelessWidget {
  final String selected;
  final void Function(String) onChanged;
  const _TypeFilter({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final types = ['', 'cours', 'exercice', 'correction', 'video', 'autre'];
    final labels = ['Tous', 'Cours', 'Exercices', 'Corrigés', 'Vidéos', 'Autres'];
    return Container(
      height: 44,
      color: const Color(0xFF161B22),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        itemCount: types.length,
        itemBuilder: (ctx, i) {
          final active = selected == types[i];
          return GestureDetector(
            onTap: () => onChanged(types[i]),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                gradient: active
                    ? const LinearGradient(
                        colors: [Color(0xFF0F766E), Color(0xFF0891B2)])
                    : null,
                color: active ? null : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: active
                        ? Colors.transparent
                        : Colors.white.withValues(alpha: 0.15)),
              ),
              child: Center(
                child: Text(labels[i],
                    style: TextStyle(
                        color: active ? Colors.white : Colors.white38,
                        fontSize: 12,
                        fontWeight:
                            active ? FontWeight.w600 : FontWeight.normal)),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _MatiereSection extends StatelessWidget {
  final String matiere;
  final List<DocumentPedagogique> docs;
  final Map<String, Color> typeColors;
  final Map<String, IconData> typeIcons;
  const _MatiereSection(
      {required this.matiere,
      required this.docs,
      required this.typeColors,
      required this.typeIcons});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 16, 0, 8),
          child: Row(
            children: [
              const Icon(Icons.folder_outlined,
                  color: Color(0xFF0F766E), size: 16),
              const SizedBox(width: 6),
              Text(
                matiere.toUpperCase(),
                style: const TextStyle(
                    color: Color(0xFF0F766E),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                    color: const Color(0xFF0F766E).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10)),
                child: Text('${docs.length}',
                    style: const TextStyle(
                        color: Color(0xFF0F766E),
                        fontSize: 10,
                        fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
        ...docs.map((d) => _DocTile(
              doc: d,
              color: typeColors[d.type] ?? const Color(0xFF374151),
              icon: typeIcons[d.type] ?? Icons.insert_drive_file_outlined,
            )),
      ],
    );
  }
}

class _DocTile extends StatelessWidget {
  final DocumentPedagogique doc;
  final Color color;
  final IconData icon;
  const _DocTile(
      {required this.doc, required this.color, required this.icon});

  String get _dateLabel {
    final d = doc.dateDepot;
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
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
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(doc.titre,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                Text(
                  '${doc.classeNom} · $_dateLabel',
                  style:
                      const TextStyle(color: Colors.white38, fontSize: 11),
                ),
                if (doc.description.isNotEmpty)
                  Text(doc.description,
                      style: const TextStyle(
                          color: Colors.white54, fontSize: 11, height: 1.3),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8)),
                child: Text(_typeLabel(doc.type),
                    style: TextStyle(
                        color: color,
                        fontSize: 10,
                        fontWeight: FontWeight.w600)),
              ),
              if (doc.aFichier)
                const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child:
                      Icon(Icons.attach_file, color: Colors.white24, size: 14),
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _typeLabel(String t) => switch (t) {
        'cours' => 'Cours',
        'exercice' => 'Exercice',
        'correction' => 'Corrigé',
        'video' => 'Vidéo',
        _ => 'Autre',
      };
}

class _EmptyState extends StatelessWidget {
  final bool hasFilter;
  const _EmptyState({required this.hasFilter});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
              hasFilter
                  ? Icons.search_off_outlined
                  : Icons.library_books_outlined,
              color: Colors.white24,
              size: 56),
          const SizedBox(height: 16),
          Text(
              hasFilter
                  ? 'Aucun document trouvé'
                  : 'Bibliothèque vide',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text(
              hasFilter
                  ? 'Modifiez votre recherche ou filtre'
                  : 'Déposez des cours depuis l\'onglet Documents',
              style: const TextStyle(color: Colors.white38, fontSize: 13),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
