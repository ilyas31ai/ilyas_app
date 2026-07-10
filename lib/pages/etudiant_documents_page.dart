import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/document_model.dart';
import '../services/etudiant_service.dart';

class EtudiantDocumentsPage extends StatefulWidget {
  const EtudiantDocumentsPage({super.key});

  @override
  State<EtudiantDocumentsPage> createState() =>
      _EtudiantDocumentsPageState();
}

class _EtudiantDocumentsPageState extends State<EtudiantDocumentsPage> {
  String _selectedType = 'Tous';
  final _searchController = TextEditingController();
  String _searchQuery = '';

  static const _types = ['Tous', 'cours', 'exercice', 'correction', 'autre'];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        elevation: 0,
        title: const Text(
          'Documents pedagogiques',
          style: TextStyle(
              color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
      body: StreamBuilder<String?>(
        stream: EtudiantService.classeNomStream(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(
                    color: Color(0xFF2563EB)));
          }
          final classeNom = snap.data ?? '';
          if (classeNom.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.school_outlined,
                      color: Colors.white24, size: 48),
                  SizedBox(height: 12),
                  Text('Classe non assignee',
                      style:
                          TextStyle(color: Colors.white38, fontSize: 15)),
                ],
              ),
            );
          }
          return Column(
            children: [
              _SearchField(
                controller: _searchController,
                onChanged: (v) =>
                    setState(() => _searchQuery = v.toLowerCase()),
              ),
              _FilterChips(
                types: _types,
                selected: _selectedType,
                onSelected: (t) => setState(() => _selectedType = t),
              ),
              Expanded(
                child: _DocumentsList(
                  classeNom: classeNom,
                  selectedType: _selectedType,
                  searchQuery: _searchQuery,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  const _SearchField(
      {required this.controller, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: 'Rechercher un document...',
          hintStyle: const TextStyle(color: Colors.white38),
          prefixIcon:
              const Icon(Icons.search, color: Colors.white38, size: 20),
          filled: true,
          fillColor: const Color(0xFF161B22),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
                color: Colors.white.withValues(alpha: 0.1)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
                color: Colors.white.withValues(alpha: 0.1)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                const BorderSide(color: Color(0xFF6C47FF)),
          ),
        ),
      ),
    );
  }
}

class _FilterChips extends StatelessWidget {
  final List<String> types;
  final String selected;
  final ValueChanged<String> onSelected;
  const _FilterChips(
      {required this.types,
      required this.selected,
      required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: types.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final t = types[i];
          final isSelected = t == selected;
          return FilterChip(
            label: Text(
              t == 'Tous' ? 'Tous' : _typeLabel(t),
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white54,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            selected: isSelected,
            onSelected: (_) => onSelected(t),
            backgroundColor: const Color(0xFF161B22),
            selectedColor: const Color(0xFF6C47FF),
            checkmarkColor: Colors.white,
            side: BorderSide(
              color: isSelected
                  ? const Color(0xFF6C47FF)
                  : Colors.white.withValues(alpha: 0.1),
            ),
          );
        },
      ),
    );
  }

  String _typeLabel(String t) {
    switch (t) {
      case 'cours':
        return 'Cours';
      case 'exercice':
        return 'Exercice';
      case 'correction':
        return 'Correction';
      default:
        return 'Autre';
    }
  }
}

class _DocumentsList extends StatelessWidget {
  final String classeNom;
  final String selectedType;
  final String searchQuery;
  const _DocumentsList({
    required this.classeNom,
    required this.selectedType,
    required this.searchQuery,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<DocumentPedagogique>>(
      stream: EtudiantService.documentsStream(classeNom),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(
                  color: Color(0xFF2563EB)));
        }
        if (snap.hasError) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.lock_outline, color: Colors.white24, size: 48),
                  SizedBox(height: 12),
                  Text(
                    'Documents non disponibles',
                    style: TextStyle(
                        color: Colors.white60,
                        fontSize: 15,
                        fontWeight: FontWeight.w600),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Contactez votre professeur si le problème persiste.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ],
              ),
            ),
          );
        }
        var docs = snap.data ?? [];

        if (selectedType != 'Tous') {
          docs = docs.where((d) => d.type == selectedType).toList();
        }
        if (searchQuery.isNotEmpty) {
          docs = docs.where((d) {
            return d.titre.toLowerCase().contains(searchQuery) ||
                d.matiere.toLowerCase().contains(searchQuery) ||
                d.description.toLowerCase().contains(searchQuery);
          }).toList();
        }

        if (docs.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.folder_open_outlined,
                    color: Colors.white24, size: 48),
                SizedBox(height: 12),
                Text('Aucun document',
                    style: TextStyle(
                        color: Colors.white38, fontSize: 15)),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (_, i) => _DocCard(doc: docs[i]),
        );
      },
    );
  }
}

class _DocCard extends StatelessWidget {
  final DocumentPedagogique doc;
  const _DocCard({required this.doc});

  static const _typeColors = {
    'cours': Color(0xFF2563EB),
    'exercice': Color(0xFF16A34A),
    'correction': Color(0xFF6C47FF),
    'autre': Color(0xFF4B5563),
  };

  static const _typeLabels = {
    'cours': 'Cours',
    'exercice': 'Exercice',
    'correction': 'Correction',
    'autre': 'Autre',
  };

  @override
  Widget build(BuildContext context) {
    final typeColor =
        _typeColors[doc.type] ?? const Color(0xFF4B5563);
    final typeLabel =
        _typeLabels[doc.type] ?? doc.type;
    final profName = doc.professeurId.length > 14
        ? doc.professeurId.substring(0, 14)
        : doc.professeurId;

    return InkWell(
      onTap: () async {
        if (doc.fichierUrl.isNotEmpty) {
          final uri = Uri.parse(doc.fichierUrl);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri,
                mode: LaunchMode.externalApplication);
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Aucun fichier joint'),
              backgroundColor: Color(0xFF374151),
            ),
          );
        }
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF161B22),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    doc.titre,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: typeColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    typeLabel,
                    style: TextStyle(
                        color: typeColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            if (doc.description.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                doc.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: Colors.white54, fontSize: 12),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6C47FF)
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(doc.matiere,
                      style: const TextStyle(
                          color: Color(0xFF6C47FF),
                          fontSize: 10)),
                ),
                const SizedBox(width: 8),
                Text(doc.classeNom,
                    style: const TextStyle(
                        color: Colors.white38, fontSize: 11)),
                const Spacer(),
                Text(
                  _formatDate(doc.dateDepot),
                  style: const TextStyle(
                      color: Colors.white24, fontSize: 11),
                ),
                if (doc.aFichier) ...[
                  const SizedBox(width: 6),
                  const Icon(Icons.attach_file,
                      color: Colors.white38, size: 14),
                ],
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Par $profName',
              style: const TextStyle(
                  color: Colors.white24, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

