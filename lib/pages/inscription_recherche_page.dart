import 'package:flutter/material.dart';

import '../models/inscription_model.dart';
import '../services/inscription_service.dart';
import '../widgets/inscription_card.dart';

/// Recherche d'un dossier par nom/prénom élève, matricule, ou nom/téléphone
/// d'un parent — sur les inscriptions déjà traitées (hors brouillons).
class InscriptionRecherchePage extends StatefulWidget {
  const InscriptionRecherchePage({super.key});

  @override
  State<InscriptionRecherchePage> createState() => _InscriptionRecherchePageState();
}

class _InscriptionRecherchePageState extends State<InscriptionRecherchePage> {
  final _ctrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        elevation: 0,
        title: const Text('Recherche',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: _searchField(),
          ),
          Expanded(child: _results()),
        ],
      ),
    );
  }

  Widget _searchField() {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.07)),
    );
    return TextField(
      controller: _ctrl,
      onChanged: (v) => setState(() => _query = v),
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        hintText: 'Nom, prénom, matricule, téléphone parent…',
        hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
        prefixIcon: const Icon(Icons.search, color: Colors.white38),
        suffixIcon: _query.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.close, color: Colors.white38, size: 18),
                onPressed: () {
                  _ctrl.clear();
                  setState(() => _query = '');
                },
              ),
        filled: true,
        fillColor: const Color(0xFF161B22),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: border,
        enabledBorder: border,
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF2563EB)),
        ),
      ),
    );
  }

  Widget _results() {
    final q = _query.trim();
    if (q.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'Recherchez un dossier par nom, prénom ou matricule de l\'élève, '
            'ou par le nom/téléphone d\'un parent.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white38, fontSize: 13),
          ),
        ),
      );
    }
    return StreamBuilder<List<Inscription>>(
      stream: InscriptionService.search(q),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF2563EB)),
          );
        }
        final items = snap.data ?? [];
        if (items.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                'Aucun résultat pour « $q ».',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white38, fontSize: 13),
              ),
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          itemCount: items.length,
          itemBuilder: (_, i) => InscriptionCard(inscription: items[i]),
        );
      },
    );
  }
}
