import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/user_model.dart';
import '../services/editeur_stats_service.dart';

const _kBg = Color(0xFF0D1117);
const _kCard = Color(0xFF161B22);
const _kBorder = Color(0x1AFFFFFF);
const _kBlue = Color(0xFF2563EB);

/// Tableau de bord de l'Espace Éditeur : effectifs et activité de la
/// plateforme, tous établissements confondus. Voir [EditeurStatsService].
class EditeurDashboardPage extends StatefulWidget {
  const EditeurDashboardPage({super.key});

  @override
  State<EditeurDashboardPage> createState() => _EditeurDashboardPageState();
}

class _EditeurDashboardPageState extends State<EditeurDashboardPage> {
  PlatformStats? _stats;
  List<UserModel> _recentes = [];
  bool _loading = true;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = false;
    });
    try {
      final results = await Future.wait([
        EditeurStatsService.chargerStats(),
        EditeurStatsService.inscriptionsRecentes(),
      ]);
      if (!mounted) return;
      setState(() {
        _stats = results[0] as PlatformStats;
        _recentes = results[1] as List<UserModel>;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kCard,
        elevation: 0,
        title: const Text('Tableau de bord',
            style: TextStyle(
                color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(color: _kBlue))
            : _error
                ? RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(
                      children: const [
                        SizedBox(height: 100),
                        Center(
                          child: Text(
                            'Erreur de chargement.\nTirez pour réessayer.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white38, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
                      children: [
                        _sectionLabel('Vue d\'ensemble'),
                        const SizedBox(height: 10),
                        GridView.count(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisCount: 2,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 1.4,
                          children: [
                            _kpiCard(Icons.account_balance_outlined,
                                '${_stats!.totalEtablissements}',
                                'Établissements',
                                const [Color(0xFF6C47FF), Color(0xFF2563EB)]),
                            _kpiCard(Icons.people_alt_outlined,
                                '${_stats!.totalUtilisateurs}',
                                'Utilisateurs',
                                const [Color(0xFF2563EB), Color(0xFF0891B2)]),
                            _kpiCard(Icons.groups_outlined,
                                '${_stats!.totalEleves}', 'Élèves',
                                const [Color(0xFF16A34A), Color(0xFF0891B2)]),
                            _kpiCard(Icons.school_outlined,
                                '${_stats!.totalProfesseurs}', 'Professeurs',
                                const [Color(0xFF7C3AED), Color(0xFF6C47FF)]),
                            _kpiCard(Icons.family_restroom_outlined,
                                '${_stats!.totalParents}', 'Parents',
                                const [Color(0xFFBE185D), Color(0xFFDB2777)]),
                            _kpiCard(Icons.admin_panel_settings_outlined,
                                '${_stats!.totalDirections}', 'Directions',
                                const [Color(0xFFD97706), Color(0xFFDC2626)]),
                          ],
                        ),
                        const SizedBox(height: 24),
                        _sectionLabel('Utilisateurs actifs'),
                        const SizedBox(height: 10),
                        _activiteCard(),
                        const SizedBox(height: 24),
                        _sectionLabel('Nouvelles inscriptions'),
                        const SizedBox(height: 10),
                        if (_recentes.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: _kCard,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text('Aucune inscription récente.',
                                style: TextStyle(
                                    color: Colors.white38, fontSize: 13)),
                          )
                        else
                          ..._recentes.map(_inscriptionRow),
                      ],
                    ),
                  ),
      ),
    );
  }

  Widget _activiteCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kBorder),
      ),
      child: Row(
        children: [
          _activiteItem('Aujourd\'hui', _stats!.actifsJour, const Color(0xFF16A34A)),
          _divider(),
          _activiteItem('Cette semaine', _stats!.actifsSemaine, const Color(0xFF2563EB)),
          _divider(),
          _activiteItem('Ce mois', _stats!.actifsMois, const Color(0xFFD97706)),
        ],
      ),
    );
  }

  Widget _divider() => Container(
        width: 1,
        height: 44,
        color: Colors.white.withValues(alpha: 0.08),
      );

  Widget _activiteItem(String label, int value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text('$value',
              style: TextStyle(
                  color: color, fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(label,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white54, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _inscriptionRow(UserModel u) {
    final date = u.createdAt != null
        ? DateFormat('dd/MM/yy HH:mm').format(u.createdAt!.toDate())
        : '—';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    u.displayName.isEmpty
                        ? (u.email.isEmpty ? 'Utilisateur' : u.email)
                        : u.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(u.role.label,
                    style: const TextStyle(color: Colors.white38, fontSize: 11)),
              ],
            ),
          ),
          Text(date,
              style: const TextStyle(color: Colors.white24, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _kpiCard(
      IconData icon, String value, String label, List<Color> colors) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
            colors: colors.map((c) => c.withValues(alpha: 0.15)).toList(),
            begin: Alignment.topLeft,
            end: Alignment.bottomRight),
        color: _kCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.first.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: colors.first, size: 22),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold)),
              Text(label,
                  style: const TextStyle(color: Colors.white54, fontSize: 11)),
            ],
          ),
        ],
      ),
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
