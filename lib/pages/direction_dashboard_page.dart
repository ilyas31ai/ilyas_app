import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/user_service.dart';
import '../widgets/dashboard_stat_card.dart';

class DirectionDashboardPage extends StatelessWidget {
  const DirectionDashboardPage({super.key});

  static final _db = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        elevation: 0,
        title: const Text(
          'Tableau de bord',
          style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          _sectionLabel('Établissement'),
          const SizedBox(height: 10),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.35,
            children: [
              _roleStatCard(
                role: 'eleve',
                icon: Icons.groups_outlined,
                label: 'Élèves',
                colors: const [Color(0xFF2563EB), Color(0xFF0891B2)],
              ),
              _roleStatCard(
                role: 'professeur',
                icon: Icons.school_outlined,
                label: 'Professeurs',
                colors: const [Color(0xFF7C3AED), Color(0xFF6C47FF)],
              ),
              _classesStatCard(),
              _roleStatCard(
                role: 'parent',
                icon: Icons.family_restroom_outlined,
                label: 'Parents',
                colors: const [Color(0xFFBE185D), Color(0xFFDB2777)],
              ),
            ],
          ),
          const SizedBox(height: 24),
          _sectionLabel('Classes actives'),
          const SizedBox(height: 10),
          _classesList(),
        ],
      ),
    );
  }

  Widget _roleStatCard({
    required String role,
    required IconData icon,
    required String label,
    required List<Color> colors,
  }) {
    return StreamBuilder<int>(
      stream: UserService.usersByRoleStream(role)
          .map((list) => list.length),
      builder: (context, snap) {
        final value = snap.hasData ? snap.data!.toString() : '…';
        return DashboardStatCard(
            icon: icon, value: value, label: label, colors: colors);
      },
    );
  }

  Widget _classesStatCard() {
    return StreamBuilder<QuerySnapshot>(
      stream: _db.collection('classes').snapshots(),
      builder: (context, snap) {
        final value =
            snap.hasData ? snap.data!.docs.length.toString() : '…';
        return DashboardStatCard(
          icon: Icons.class_outlined,
          value: value,
          label: 'Classes',
          colors: const [Color(0xFF15803D), Color(0xFF16A34A)],
        );
      },
    );
  }

  Widget _classesList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _db
          .collection('classes')
          .orderBy('nom')
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: CircularProgressIndicator(color: Color(0xFF2563EB)),
            ),
          );
        }
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Aucune classe créée pour le moment.',
              style: TextStyle(color: Colors.white38, fontSize: 13),
            ),
          );
        }
        return Column(
          children: docs.map((d) {
            final data = d.data() as Map<String, dynamic>;
            final nom = data['nom'] as String? ?? d.id;
            final niveau = data['niveau'] as String? ?? '';
            final eleveIds =
                List<String>.from(data['eleveIds'] as List? ?? []);
            final profNom =
                data['professeurDisplayName'] as String? ?? '';
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF161B22),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.05)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB)
                          .withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.class_outlined,
                        color: Color(0xFF2563EB), size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          nom,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600),
                        ),
                        if (niveau.isNotEmpty || profNom.isNotEmpty)
                          Text(
                            [
                              if (niveau.isNotEmpty) niveau,
                              if (profNom.isNotEmpty) profNom,
                            ].join(' · '),
                            style: const TextStyle(
                                color: Colors.white38, fontSize: 11),
                          ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF16A34A)
                          .withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${eleveIds.length} élève${eleveIds.length != 1 ? 's' : ''}',
                      style: const TextStyle(
                          color: Color(0xFF16A34A),
                          fontSize: 11,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _sectionLabel(String text) => Text(
        text.toUpperCase(),
        style: const TextStyle(
            color: Colors.white38,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2),
      );
}
