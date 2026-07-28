import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/support_ticket_model.dart';
import '../services/support_service.dart';
import 'direction_support_page.dart' show SupportTicketDetailView;

const _kBg = Color(0xFF0D1117);
const _kCard = Color(0xFF161B22);
const _kField = Color(0xFF0D1117);
const _kBlue = Color(0xFF2563EB);
const _kBorder = Color(0x1AFFFFFF);

const double _kWideBreakpoint = 900;

/// Support & Suggestions — vue Éditeur : toutes les demandes de tous les
/// établissements (le flux [SupportService.ticketsStream] n'est pas scopé
/// par établissement). Reprend le détail/réponse/statut de
/// [SupportTicketDetailView] (Espace Direction) et ajoute la recherche et
/// l'affichage par établissement, utiles à une vue plateforme.
class EditeurSupportPage extends StatefulWidget {
  const EditeurSupportPage({super.key});

  @override
  State<EditeurSupportPage> createState() => _EditeurSupportPageState();
}

class _EditeurSupportPageState extends State<EditeurSupportPage> {
  String _search = '';
  SupportTicketStatut? _statutFiltre;
  SupportTicketType? _typeFiltre;
  String? _selectedId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kCard,
        elevation: 0,
        title: const Text('Support & Suggestions',
            style: TextStyle(
                color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        child: StreamBuilder<List<SupportTicketModel>>(
          stream: SupportService.ticketsStream(),
          builder: (context, snap) {
            if (snap.hasError) {
              return Center(
                child: Text('Erreur de chargement :\n${snap.error}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red, fontSize: 12)),
              );
            }
            final loading = snap.connectionState == ConnectionState.waiting;
            final all = snap.data ?? [];
            var tickets = all;
            if (_statutFiltre != null) {
              tickets = tickets.where((t) => t.statut == _statutFiltre).toList();
            }
            if (_typeFiltre != null) {
              tickets = tickets.where((t) => t.type == _typeFiltre).toList();
            }
            if (_search.isNotEmpty) {
              final q = _search.toLowerCase();
              tickets = tickets
                  .where((t) =>
                      t.sujet.toLowerCase().contains(q) ||
                      t.description.toLowerCase().contains(q) ||
                      t.userName.toLowerCase().contains(q) ||
                      t.userEmail.toLowerCase().contains(q) ||
                      (t.etablissementNom ?? '').toLowerCase().contains(q))
                  .toList();
            }

            return LayoutBuilder(builder: (context, constraints) {
              final wide = constraints.maxWidth >= _kWideBreakpoint;
              final listPane = _buildListPane(loading, all, tickets, wide);
              if (!wide) return listPane;
              return Row(
                children: [
                  SizedBox(width: 420, child: listPane),
                  const VerticalDivider(width: 1, color: _kBorder),
                  Expanded(
                    child: _selectedId == null
                        ? const _EmptyDetailHint()
                        : SupportTicketDetailView(
                            key: ValueKey(_selectedId),
                            ticketId: _selectedId!,
                          ),
                  ),
                ],
              );
            });
          },
        ),
      ),
    );
  }

  Widget _buildListPane(bool loading, List<SupportTicketModel> all,
      List<SupportTicketModel> tickets, bool wide) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
          child: TextField(
            style: const TextStyle(color: Colors.white, fontSize: 13.5),
            onChanged: (v) => setState(() => _search = v),
            decoration: InputDecoration(
              hintText: 'Rechercher (sujet, établissement, utilisateur…)',
              hintStyle: const TextStyle(color: Colors.white38, fontSize: 12.5),
              prefixIcon: const Icon(Icons.search, color: Colors.white38, size: 20),
              filled: true,
              fillColor: _kField,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
              ),
            ),
          ),
        ),
        SizedBox(
          height: 38,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            children: [
              _statutChip(null, 'Tous', all.length),
              for (final s in SupportTicketStatut.values)
                _statutChip(
                    s, s.label, all.where((t) => t.statut == s).length),
            ],
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 34,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            children: [
              _typeChip(null, 'Tous types'),
              for (final t in SupportTicketType.values) _typeChip(t, t.label),
            ],
          ),
        ),
        const SizedBox(height: 8),
        const Divider(height: 1, color: _kBorder),
        Expanded(
          child: loading
              ? const Center(
                  child: CircularProgressIndicator(color: _kBlue))
              : tickets.isEmpty
                  ? const Center(
                      child: Text('Aucune demande trouvée',
                          style: TextStyle(color: Colors.white38, fontSize: 13)))
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(10, 10, 10, 20),
                      itemCount: tickets.length,
                      itemBuilder: (context, i) {
                        final t = tickets[i];
                        return _TicketCard(
                          ticket: t,
                          selected: wide && t.id == _selectedId,
                          onTap: () {
                            if (wide) {
                              setState(() => _selectedId = t.id);
                            } else {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => Scaffold(
                                    backgroundColor: _kBg,
                                    appBar: AppBar(
                                      backgroundColor: _kCard,
                                      elevation: 0,
                                      title: const Text('Demande',
                                          style: TextStyle(
                                              color: Colors.white, fontSize: 15)),
                                    ),
                                    body: SafeArea(
                                        child: SupportTicketDetailView(ticketId: t.id)),
                                  ),
                                ),
                              );
                            }
                          },
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Widget _statutChip(SupportTicketStatut? statut, String label, int count) {
    final selected = _statutFiltre == statut;
    final color = statut?.color ?? Colors.white54;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () => setState(() => _statutFiltre = statut),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? color.withValues(alpha: 0.18) : _kCard,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: selected ? color.withValues(alpha: 0.6) : _kBorder),
          ),
          alignment: Alignment.center,
          child: Text('$label ($count)',
              style: TextStyle(
                  color: selected ? color : Colors.white54,
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500)),
        ),
      ),
    );
  }

  Widget _typeChip(SupportTicketType? type, String label) {
    final selected = _typeFiltre == type;
    final color = type?.color ?? Colors.white54;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () => setState(() => _typeFiltre = type),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: selected ? color.withValues(alpha: 0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: selected ? color.withValues(alpha: 0.5) : _kBorder),
          ),
          alignment: Alignment.center,
          child: Text(label,
              style: TextStyle(
                  color: selected ? color : Colors.white38,
                  fontSize: 11.5,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500)),
        ),
      ),
    );
  }
}

class _EmptyDetailHint extends StatelessWidget {
  const _EmptyDetailHint();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('Sélectionnez une demande dans la liste',
          style: TextStyle(color: Colors.white38, fontSize: 13)),
    );
  }
}

class _TicketCard extends StatelessWidget {
  final SupportTicketModel ticket;
  final bool selected;
  final VoidCallback onTap;

  const _TicketCard({
    required this.ticket,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final date = ticket.createdAt != null
        ? DateFormat('dd/MM/yy HH:mm').format(ticket.createdAt!.toDate())
        : '—';
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? _kBlue.withValues(alpha: 0.12) : _kCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: selected ? _kBlue.withValues(alpha: 0.5) : _kBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(ticket.type.icon, size: 15, color: ticket.type.color),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(ticket.sujet.isEmpty ? '(sans sujet)' : ticket.sujet,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600)),
                ),
                const SizedBox(width: 6),
                _StatutBadge(statut: ticket.statut),
              ],
            ),
            const SizedBox(height: 6),
            Text(ticket.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white38, fontSize: 12)),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.account_balance_outlined,
                    size: 12, color: Colors.white24),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                      ticket.etablissementNom?.isNotEmpty == true
                          ? ticket.etablissementNom!
                          : 'Établissement inconnu',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.person_outline, size: 12, color: Colors.white24),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                      ticket.userName.isEmpty ? ticket.userEmail : ticket.userName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white38, fontSize: 11.5)),
                ),
                Text(date,
                    style: const TextStyle(color: Colors.white24, fontSize: 11)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatutBadge extends StatelessWidget {
  final SupportTicketStatut statut;
  const _StatutBadge({required this.statut});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: statut.color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: statut.color.withValues(alpha: 0.35)),
      ),
      child: Text(statut.label,
          style: TextStyle(
              color: statut.color, fontSize: 10.5, fontWeight: FontWeight.w700)),
    );
  }
}
