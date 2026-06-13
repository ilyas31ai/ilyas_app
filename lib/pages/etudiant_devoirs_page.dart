import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import '../models/devoir_model.dart';
import '../models/copie_model.dart';
import '../services/devoir_interactif_service.dart';
import '../services/etudiant_service.dart';
import 'etudiant_faire_devoir_page.dart';

class EtudiantDevoirsPage extends StatefulWidget {
  const EtudiantDevoirsPage({super.key});

  @override
  State<EtudiantDevoirsPage> createState() => _EtudiantDevoirsPageState();
}

class _EtudiantDevoirsPageState extends State<EtudiantDevoirsPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final eleveNom = user?.displayName ?? user?.email ?? 'Élève';

    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        elevation: 0,
        title: const Text(
          'Mes Devoirs',
          style: TextStyle(
              color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'À faire'),
            Tab(text: 'Terminés'),
          ],
        ),
      ),
      body: StreamBuilder<String?>(
        stream: EtudiantService.classeNomStream(),
        builder: (context, classSnap) {
          if (classSnap.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: Color(0xFF2563EB)));
          }
          final classeNom = classSnap.data ?? '';
          if (classeNom.isEmpty) {
            return const Center(
              child: Text('Classe non assignée.',
                  style: TextStyle(color: Colors.white70)),
            );
          }
          return StreamBuilder<List<DevoirModel>>(
            stream: DevoirInteractifService.devoirsEleveStream(classeNom),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(
                    child: CircularProgressIndicator(
                        color: Color(0xFF2563EB)));
              }
              final devoirs = snap.data ?? [];
              return TabBarView(
                controller: _tabs,
                children: [
                  _DevoirsList(
                    devoirs: devoirs,
                    eleveNom: eleveNom,
                    doneFilter: false,
                  ),
                  _DevoirsList(
                    devoirs: devoirs,
                    eleveNom: eleveNom,
                    doneFilter: true,
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _DevoirsList extends StatelessWidget {
  final List<DevoirModel> devoirs;
  final String eleveNom;
  final bool doneFilter;

  const _DevoirsList({
    required this.devoirs,
    required this.eleveNom,
    required this.doneFilter,
  });

  @override
  Widget build(BuildContext context) {
    if (devoirs.isEmpty) {
      return Center(
        child: Text(
          doneFilter ? 'Aucun devoir terminé.' : 'Aucun devoir à faire.',
          style: const TextStyle(color: Colors.white70),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: devoirs.length,
      itemBuilder: (context, i) => _DevoirTile(
        devoir: devoirs[i],
        eleveNom: eleveNom,
        doneFilter: doneFilter,
      ),
    );
  }
}

class _DevoirTile extends StatelessWidget {
  final DevoirModel devoir;
  final String eleveNom;
  final bool doneFilter;

  const _DevoirTile({
    required this.devoir,
    required this.eleveNom,
    required this.doneFilter,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<CopieModel?>(
      stream: DevoirInteractifService.copieStream(devoir.id),
      builder: (context, snap) {
        final copie = snap.data;
        final statut = copie?.statut;

        // Filter: "À faire" = no copie or brouillon; "Terminés" = soumis/corrigé
        final isDone = statut == CopieStatut.soumis ||
            statut == CopieStatut.corrige;
        if (isDone != doneFilter) return const SizedBox.shrink();

        final isExpired = devoir.dateLimite != null &&
            DateTime.now().isAfter(devoir.dateLimite!);

        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            leading: _TypeIcon(devoir: devoir),
            title: Text(devoir.titre,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${devoir.matiere} · ${devoir.classeNom}'),
                if (devoir.dateLimite != null)
                  Text(
                    'Limite : ${DateFormat('dd/MM/yyyy HH:mm').format(devoir.dateLimite!)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: isExpired ? Colors.red : Colors.grey[600],
                    ),
                  ),
                if (statut == CopieStatut.corrige && copie != null)
                  Text(
                    'Note : ${copie.note?.toStringAsFixed(1) ?? '-'}/${copie.noteSur?.toStringAsFixed(0) ?? '?'}',
                    style: const TextStyle(
                        color: Colors.green, fontWeight: FontWeight.w600),
                  ),
              ],
            ),
            trailing: _StatusChip(statut: statut, isExpired: isExpired),
            onTap: () {
              if (isDone) {
                // Show result/review
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => EtudiantFaireDevoirPage(
                      devoir: devoir,
                      eleveNom: eleveNom,
                      readOnly: true,
                      existingCopie: copie,
                    ),
                  ),
                );
                return;
              }
              if (isExpired && statut == null) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('La date limite est dépassée.'),
                ));
                return;
              }
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => EtudiantFaireDevoirPage(
                    devoir: devoir,
                    eleveNom: eleveNom,
                    readOnly: false,
                    existingCopie: copie,
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _TypeIcon extends StatelessWidget {
  final DevoirModel devoir;
  const _TypeIcon({required this.devoir});

  @override
  Widget build(BuildContext context) {
    if (devoir.estExamen) {
      return const CircleAvatar(
        backgroundColor: Colors.red,
        child: Icon(Icons.timer, color: Colors.white, size: 20),
      );
    }
    if (devoir.estInteractif) {
      return const CircleAvatar(
        backgroundColor: Colors.blue,
        child: Icon(Icons.edit_note, color: Colors.white, size: 20),
      );
    }
    return const CircleAvatar(
      backgroundColor: Colors.orange,
      child: Icon(Icons.picture_as_pdf, color: Colors.white, size: 20),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final CopieStatut? statut;
  final bool isExpired;
  const _StatusChip({required this.statut, required this.isExpired});

  @override
  Widget build(BuildContext context) {
    if (statut == CopieStatut.corrige) {
      return const Chip(
        label: Text('Corrigé', style: TextStyle(fontSize: 11)),
        backgroundColor: Color(0xFFE8F5E9),
      );
    }
    if (statut == CopieStatut.soumis) {
      return const Chip(
        label: Text('Soumis', style: TextStyle(fontSize: 11)),
        backgroundColor: Color(0xFFE3F2FD),
      );
    }
    if (statut == CopieStatut.brouillon) {
      return const Chip(
        label: Text('Brouillon', style: TextStyle(fontSize: 11)),
        backgroundColor: Color(0xFFFFF9C4),
      );
    }
    if (isExpired) {
      return const Chip(
        label: Text('Expiré', style: TextStyle(fontSize: 11)),
        backgroundColor: Color(0xFFFFEBEE),
      );
    }
    return const Chip(
      label: Text('À faire', style: TextStyle(fontSize: 11)),
      backgroundColor: Color(0xFFF3E5F5),
    );
  }
}
