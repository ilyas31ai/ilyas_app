import 'package:flutter/material.dart';

import '../models/classe_model.dart';
import '../services/etudiant_service.dart';

class EmploiPage extends StatelessWidget {
  const EmploiPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        elevation: 0,
        title: const Text(
          'Emploi du temps',
          style: TextStyle(
              color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
      body: StreamBuilder<String?>(
        stream: EtudiantService.classeNomStream(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: Color(0xFF2563EB)));
          }
          final classeNom = snap.data;
          if (classeNom == null || classeNom.isEmpty) {
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
          return _EmploiBody(classeNom: classeNom);
        },
      ),
    );
  }
}

class _EmploiBody extends StatelessWidget {
  final String classeNom;
  const _EmploiBody({required this.classeNom});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<EmploiSlot>>(
      stream: EtudiantService.emploiStream(classeNom),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: Color(0xFF2563EB)));
        }
        final slots = snap.data ?? [];
        return DefaultTabController(
          length: 2,
          child: Column(
            children: [
              Container(
                color: const Color(0xFF161B22),
                child: const TabBar(
                  indicatorColor: Color(0xFF6C47FF),
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white38,
                  labelStyle: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600),
                  tabs: [
                    Tab(text: "Aujourd'hui"),
                    Tab(text: 'Semaine'),
                  ],
                ),
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    _TodayView(slots: slots),
                    _WeekView(slots: slots),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TodayView extends StatelessWidget {
  final List<EmploiSlot> slots;
  const _TodayView({required this.slots});

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now().weekday;
    final todaySlots = slots.where((s) => s.jour == today).toList();

    if (todaySlots.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_available_outlined,
                color: Colors.white24, size: 48),
            SizedBox(height: 12),
            Text("Pas de cours aujourd'hui",
                style: TextStyle(color: Colors.white38, fontSize: 15)),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      itemCount: todaySlots.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) => _SlotCard(slot: todaySlots[i]),
    );
  }
}

class _WeekView extends StatelessWidget {
  final List<EmploiSlot> slots;
  const _WeekView({required this.slots});

  static const _jours = [
    'Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi'
  ];

  @override
  Widget build(BuildContext context) {
    if (slots.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.calendar_month_outlined,
                color: Colors.white24, size: 48),
            SizedBox(height: 12),
            Text('Aucun creneau',
                style: TextStyle(color: Colors.white38, fontSize: 15)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      itemCount: 5,
      itemBuilder: (context, idx) {
        final jour = idx + 1;
        final daySlots = slots.where((s) => s.jour == jour).toList();
        if (daySlots.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 8, top: 8),
              child: Text(
                _jours[idx].toUpperCase(),
                style: const TextStyle(
                  color: Colors.white38,
                  fontSize: 11,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ...daySlots.map((s) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _SlotCard(slot: s),
                )),
          ],
        );
      },
    );
  }
}

class _SlotCard extends StatelessWidget {
  final EmploiSlot slot;
  const _SlotCard({required this.slot});

  static const _colors = [
    [Color(0xFF6C47FF), Color(0xFF2563EB)],
    [Color(0xFF15803D), Color(0xFF16A34A)],
    [Color(0xFF0891B2), Color(0xFF0F766E)],
    [Color(0xFFD97706), Color(0xFFB45309)],
    [Color(0xFFB91C1C), Color(0xFFDC2626)],
    [Color(0xFF7C3AED), Color(0xFF6C47FF)],
  ];

  List<Color> _getColors(String matiere) {
    final idx = matiere.codeUnits.fold<int>(0, (a, b) => a + b) %
        _colors.length;
    return _colors[idx];
  }

  @override
  Widget build(BuildContext context) {
    final colors = _getColors(slot.matiere);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: colors),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                Text(
                  slot.heureDebut,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                const Text('-',
                    style:
                        TextStyle(color: Colors.white60, fontSize: 10)),
                const SizedBox(height: 2),
                Text(
                  slot.heureFin,
                  style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  slot.matiere,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600),
                ),
                if (slot.salle.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      const Icon(Icons.room_outlined,
                          color: Colors.white38, size: 13),
                      const SizedBox(width: 4),
                      Text(
                        'Salle ${slot.salle}',
                        style: const TextStyle(
                            color: Colors.white38, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
