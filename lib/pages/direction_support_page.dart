import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/support_ticket_model.dart';
import '../models/user_model.dart';
import '../services/support_service.dart';

const _kBg = Color(0xFF0D1117);
const _kCard = Color(0xFF161B22);
const _kField = Color(0xFF0D1117);
const _kBlue = Color(0xFF2563EB);
const _kBorder = Color(0x1AFFFFFF);

/// Seuil de largeur à partir duquel le tableau de bord bascule en vue
/// "maître-détail" (liste + panneau latéral), adaptée aux grands écrans
/// (PC, tablette en paysage) — en dessous, la liste occupe tout l'écran et
/// le détail s'ouvre en page pleine (téléphone).
const double _kWideBreakpoint = 900;

/// Tableau de bord Direction du module Support & Suggestions : consultation,
/// recherche, filtrage et suivi de statut de toutes les demandes envoyées
/// par les utilisateurs (voir [SupportFormPage] côté envoi).
class DirectionSupportPage extends StatefulWidget {
  const DirectionSupportPage({super.key});

  @override
  State<DirectionSupportPage> createState() => _DirectionSupportPageState();
}

class _DirectionSupportPageState extends State<DirectionSupportPage> {
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
                    t.userEmail.toLowerCase().contains(q))
                .toList();
          }

          return LayoutBuilder(builder: (context, constraints) {
            final wide = constraints.maxWidth >= _kWideBreakpoint;
            final listPane = _buildListPane(loading, all, tickets, wide);
            if (!wide) return listPane;
            return Row(
              children: [
                SizedBox(width: 400, child: listPane),
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
              hintText: 'Rechercher (sujet, description, utilisateur…)',
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
                Icon(Icons.person_outline, size: 12, color: Colors.white24),
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

// ─── Détail d'une demande ──────────────────────────────────────────────────

/// Vue détaillée d'une demande, alimentée par un flux Firestore direct sur
/// son document (plutôt que par l'objet de la liste parente) : reste à jour
/// après un changement de statut ou l'ajout d'une réponse, aussi bien en
/// panneau latéral (PC) qu'en page pleine (téléphone).
class SupportTicketDetailView extends StatefulWidget {
  final String ticketId;
  const SupportTicketDetailView({required this.ticketId, super.key});

  @override
  State<SupportTicketDetailView> createState() =>
      _SupportTicketDetailViewState();
}

class _SupportTicketDetailViewState extends State<SupportTicketDetailView> {
  final _reponseCtrl = TextEditingController();
  bool _savingReponse = false;
  bool _reponseCtrlInitialized = false;

  @override
  void dispose() {
    _reponseCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveReponse() async {
    final texte = _reponseCtrl.text.trim();
    if (texte.isEmpty) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _savingReponse = true);
    try {
      await SupportService.enregistrerReponse(widget.ticketId, texte);
      messenger.showSnackBar(const SnackBar(
        content: Text('Réponse enregistrée'),
        backgroundColor: Color(0xFF16A34A),
      ));
    } catch (e) {
      messenger.showSnackBar(SnackBar(
        content: Text('Erreur lors de l\'enregistrement : $e'),
        backgroundColor: const Color(0xFFDC2626),
      ));
    } finally {
      if (mounted) setState(() => _savingReponse = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('support_tickets')
          .doc(widget.ticketId)
          .snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(
            child: Text('Erreur de chargement :\n${snap.error}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red, fontSize: 12)),
          );
        }
        if (!snap.hasData) {
          return const Center(
              child: CircularProgressIndicator(color: _kBlue));
        }
        if (!snap.data!.exists) {
          return const Center(
              child: Text('Cette demande a été supprimée.',
                  style: TextStyle(color: Colors.white38, fontSize: 13)));
        }
        final t = SupportTicketModel.fromDoc(snap.data!);
        if (!_reponseCtrlInitialized) {
          _reponseCtrl.text = t.reponse ?? '';
          _reponseCtrlInitialized = true;
        }
        final date = t.createdAt != null
            ? DateFormat('dd/MM/yyyy à HH:mm').format(t.createdAt!.toDate())
            : '—';
        final roleLabel = t.userRole.isEmpty
            ? '—'
            : UserRoleX.fromString(t.userRole).label;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(t.type.icon, color: t.type.color, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(t.sujet.isEmpty ? '(sans sujet)' : t.sujet,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text('${t.type.label} · $date',
                  style: const TextStyle(color: Colors.white38, fontSize: 12)),
              const SizedBox(height: 16),
              _infoCard('Utilisateur', [
                _infoRow(Icons.person_outline, 'Nom', t.userName),
                _infoRow(Icons.badge_outlined, 'Rôle', roleLabel),
                _infoRow(Icons.email_outlined, 'Email', t.userEmail),
                _infoRow(Icons.account_balance_outlined, 'Établissement',
                    t.etablissementNom ?? '—'),
              ]),
              const SizedBox(height: 12),
              _infoCard('Contexte technique', [
                _infoRow(Icons.info_outline, 'Version de l\'app', t.appVersion),
                _infoRow(Icons.phone_android_outlined, 'Appareil', t.deviceInfo),
              ]),
              const SizedBox(height: 16),
              const Text('Message',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _kCard,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _kBorder),
                ),
                child: Text(t.description,
                    style: const TextStyle(color: Colors.white70, fontSize: 13.5)),
              ),
              if (t.screenshotUrl != null) ...[
                const SizedBox(height: 16),
                const Text('Capture d\'écran',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () => _openScreenshot(context, t.screenshotUrl!),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(t.screenshotUrl!,
                        height: 200, width: double.infinity, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                              height: 100,
                              alignment: Alignment.center,
                              color: _kCard,
                              child: const Text('Image indisponible',
                                  style: TextStyle(color: Colors.white38, fontSize: 12)),
                            )),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              const Text('Statut',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: SupportTicketStatut.values.map((s) {
                  final active = s == t.statut;
                  return GestureDetector(
                    onTap: () => SupportService.changerStatut(t.id, s),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 9),
                      decoration: BoxDecoration(
                        color: active
                            ? s.color.withValues(alpha: 0.18)
                            : _kCard,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: active
                                ? s.color.withValues(alpha: 0.6)
                                : _kBorder),
                      ),
                      child: Text(s.label,
                          style: TextStyle(
                              color: active ? s.color : Colors.white54,
                              fontSize: 12.5,
                              fontWeight:
                                  active ? FontWeight.w700 : FontWeight.w500)),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
              const Text('Réponse interne',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              const Text(
                'Enregistrée pour référence — pas encore transmise à '
                'l\'utilisateur (fonctionnalité à venir).',
                style: TextStyle(color: Colors.white24, fontSize: 11),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _reponseCtrl,
                maxLines: 4,
                minLines: 2,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Votre réponse…',
                  hintStyle: const TextStyle(color: Colors.white24, fontSize: 12.5),
                  filled: true,
                  fillColor: _kField,
                  contentPadding: const EdgeInsets.all(12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                ),
              ),
              if (t.reponseAt != null) ...[
                const SizedBox(height: 4),
                Text(
                    'Dernière mise à jour par ${t.reponseParNom ?? '—'} le '
                    '${DateFormat('dd/MM/yyyy à HH:mm').format(t.reponseAt!.toDate())}',
                    style: const TextStyle(color: Colors.white24, fontSize: 10.5)),
              ],
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                  onPressed: _savingReponse ? null : _saveReponse,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: _savingReponse
                      ? const SizedBox(
                          width: 16, height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('Enregistrer la réponse'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _infoCard(String title, List<Widget> rows) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  color: Colors.white38,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8)),
          const SizedBox(height: 8),
          ...rows,
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: Colors.white38),
          const SizedBox(width: 8),
          Text('$label : ',
              style: const TextStyle(color: Colors.white38, fontSize: 12.5)),
          Expanded(
            child: Text(value.isEmpty ? '—' : value,
                style: const TextStyle(color: Colors.white70, fontSize: 12.5)),
          ),
        ],
      ),
    );
  }

  void _openScreenshot(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(12),
        child: InteractiveViewer(
          child: Image.network(url, errorBuilder: (_, __, ___) => const Padding(
            padding: EdgeInsets.all(24),
            child: Text('Image indisponible',
                style: TextStyle(color: Colors.white38)),
          )),
        ),
      ),
    );
  }
}
