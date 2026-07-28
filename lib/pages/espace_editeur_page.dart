import 'package:flutter/material.dart';

import '../services/editeur_access_service.dart';
import 'editeur_dashboard_page.dart';
import 'editeur_statistiques_page.dart';
import 'editeur_support_page.dart';

const _kBg = Color(0xFF0D1117);
const _kCard = Color(0xFF161B22);
const _kBorder = Color(0x1AFFFFFF);

/// Espace Éditeur — réservé au propriétaire de SCOLARAI, totalement séparé
/// des espaces établissement (Direction/Professeur/Parent/Élève).
///
/// Sécurité : l'accès n'est PAS conditionné par le rôle Firestore
/// (`users/{uid}.role`) mais par une liste blanche d'UID Firebase — voir
/// [EditeurAccessService]. Un compte Direction/admin normal, quel que soit
/// son rôle, ne peut pas y entrer. Cette page revérifie l'autorisation à
/// l'ouverture (défense en profondeur si atteinte par un lien direct) et
/// redirige automatiquement sinon ; la protection réelle des données reste
/// portée par les règles Firestore (`isEditeurUid()`).
class EspaceEditeurPage extends StatefulWidget {
  const EspaceEditeurPage({super.key});

  @override
  State<EspaceEditeurPage> createState() => _EspaceEditeurPageState();
}

class _EspaceEditeurPageState extends State<EspaceEditeurPage> {
  @override
  void initState() {
    super.initState();
    if (!EditeurAccessService.isAuthorized) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Accès non autorisé.'),
          backgroundColor: Color(0xFFDC2626),
        ));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!EditeurAccessService.isAuthorized) {
      return const Scaffold(
        backgroundColor: _kBg,
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF2563EB)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kCard,
        elevation: 0,
        title: const Text('Espace Éditeur',
            style: TextStyle(
                color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6C47FF), Color(0xFF2563EB)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Row(
                children: [
                  Icon(Icons.admin_panel_settings_outlined,
                      color: Colors.white, size: 30),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('SCOLAR AI Educative',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold)),
                        SizedBox(height: 2),
                        Text('Supervision de la plateforme, tous établissements',
                            style: TextStyle(
                                color: Colors.white70, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _card(
              context,
              icon: Icons.dashboard_outlined,
              iconColors: const [Color(0xFF2563EB), Color(0xFF0891B2)],
              title: 'Tableau de bord',
              subtitle:
                  'Établissements, utilisateurs, activité de la plateforme',
              page: const EditeurDashboardPage(),
            ),
            const SizedBox(height: 10),
            _card(
              context,
              icon: Icons.support_agent_outlined,
              iconColors: const [Color(0xFF16A34A), Color(0xFF0891B2)],
              title: 'Support & Suggestions',
              subtitle:
                  'Toutes les demandes, tous établissements confondus',
              page: const EditeurSupportPage(),
            ),
            const SizedBox(height: 10),
            _card(
              context,
              icon: Icons.bar_chart_outlined,
              iconColors: const [Color(0xFFD97706), Color(0xFFDC2626)],
              title: 'Statistiques',
              subtitle: 'Vue d\'ensemble des demandes reçues',
              page: const EditeurStatistiquesPage(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _card(
    BuildContext context, {
    required IconData icon,
    required List<Color> iconColors,
    required String title,
    required String subtitle,
    required Widget page,
  }) {
    return InkWell(
      onTap: () => Navigator.push(
          context, MaterialPageRoute(builder: (_) => page)),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: _kCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _kBorder),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: iconColors),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: const TextStyle(
                          color: Colors.white38, fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white24),
          ],
        ),
      ),
    );
  }
}
