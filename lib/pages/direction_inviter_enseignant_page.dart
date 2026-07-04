import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/invitation_model.dart';
import '../models/user_model.dart';
import '../services/invitation_service.dart';
import '../services/user_service.dart';

class DirectionInviterEnseignantPage extends StatefulWidget {
  const DirectionInviterEnseignantPage({super.key});

  @override
  State<DirectionInviterEnseignantPage> createState() =>
      _DirectionInviterEnseignantPageState();
}

class _DirectionInviterEnseignantPageState
    extends State<DirectionInviterEnseignantPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;
  final _searchCtrl = TextEditingController();
  String _filterMatiere = '';
  int _validityDays = 7;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _searchCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
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
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Inviter un enseignant',
          style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold),
        ),
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: const Color(0xFF6C47FF),
          labelColor: const Color(0xFF6C47FF),
          unselectedLabelColor: Colors.white38,
          tabs: const [
            Tab(text: 'Rechercher'),
            Tab(text: 'Invitations'),
          ],
        ),
      ),
      body: StreamBuilder<UserModel?>(
        stream: UserService.currentUserStream(),
        builder: (context, snap) {
          final schoolId = snap.data?.schoolId ?? '';
          return TabBarView(
            controller: _tabCtrl,
            children: [
              _SearchTab(
                searchCtrl: _searchCtrl,
                filterMatiere: _filterMatiere,
                validityDays: _validityDays,
                onMatiereChanged: (v) =>
                    setState(() => _filterMatiere = v),
                onValidityChanged: (v) =>
                    setState(() => _validityDays = v),
              ),
              _InvitationsTab(schoolId: schoolId),
            ],
          );
        },
      ),
    );
  }
}

// ── Onglet 1 : Recherche ──────────────────────────────────────────────────────

class _SearchTab extends StatelessWidget {
  final TextEditingController searchCtrl;
  final String filterMatiere;
  final int validityDays;
  final ValueChanged<String> onMatiereChanged;
  final ValueChanged<int> onValidityChanged;

  const _SearchTab({
    required this.searchCtrl,
    required this.filterMatiere,
    required this.validityDays,
    required this.onMatiereChanged,
    required this.onValidityChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildSearchBar(context),
        Expanded(
          child: StreamBuilder<List<UserModel>>(
            stream: InvitationService.enseignantsSansEcoleStream(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(
                      color: Color(0xFF6C47FF)),
                );
              }
              if (snap.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Erreur Firestore : ${snap.error}',
                      style: const TextStyle(
                          color: Color(0xFFEF4444), fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }
              final all = snap.data ?? [];
              final filtered = _filter(all);
              if (filtered.isEmpty) {
                return _EmptySearch(
                  hasFilter: searchCtrl.text.isNotEmpty ||
                      filterMatiere.isNotEmpty,
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                itemCount: filtered.length,
                itemBuilder: (context, i) => _TeacherCard(
                  teacher: filtered[i],
                  validityDays: validityDays,
                  onValidityChanged: onValidityChanged,
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Column(
        children: [
          TextField(
            controller: searchCtrl,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Nom, prénom ou email…',
              hintStyle: const TextStyle(color: Colors.white38),
              filled: true,
              fillColor: const Color(0xFF161B22),
              prefixIcon: const Icon(Icons.search,
                  color: Colors.white38, size: 20),
              suffixIcon: searchCtrl.text.isNotEmpty
                  ? GestureDetector(
                      onTap: () => searchCtrl.clear(),
                      child: const Icon(Icons.clear,
                          color: Colors.white38, size: 18),
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                    color: Colors.white.withValues(alpha: 0.08)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                    color: Colors.white.withValues(alpha: 0.08)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF6C47FF)),
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: onMatiereChanged,
                  style:
                      const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Filtrer par matière…',
                    hintStyle: const TextStyle(color: Colors.white38),
                    filled: true,
                    fillColor: const Color(0xFF161B22),
                    prefixIcon: const Icon(Icons.subject_outlined,
                        color: Colors.white38, size: 18),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                          color: Colors.white.withValues(alpha: 0.06)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                          color: Colors.white.withValues(alpha: 0.06)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide:
                          const BorderSide(color: Color(0xFF6C47FF)),
                    ),
                    contentPadding:
                        const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _ValiditySelector(
                  value: validityDays, onChanged: onValidityChanged),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  List<UserModel> _filter(List<UserModel> all) {
    final q = searchCtrl.text.toLowerCase().trim();
    final m = filterMatiere.toLowerCase().trim();
    return all.where((t) {
      final matchQ = q.isEmpty ||
          t.displayName.toLowerCase().contains(q) ||
          t.email.toLowerCase().contains(q);
      final matchM = m.isEmpty ||
          (t.matiere?.toLowerCase().contains(m) ?? false);
      return matchQ && matchM;
    }).toList();
  }
}

class _ValiditySelector extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;
  const _ValiditySelector({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<int>(
      initialValue: value,
      color: const Color(0xFF1F2937),
      onSelected: onChanged,
      itemBuilder: (_) => [
        const PopupMenuItem(value: 3, child: Text('3 jours', style: TextStyle(color: Colors.white))),
        const PopupMenuItem(value: 7, child: Text('7 jours', style: TextStyle(color: Colors.white))),
        const PopupMenuItem(value: 14, child: Text('14 jours', style: TextStyle(color: Colors.white))),
        const PopupMenuItem(value: 30, child: Text('30 jours', style: TextStyle(color: Colors.white))),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: const Color(0xFF161B22),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Row(
          children: [
            const Icon(Icons.timer_outlined,
                color: Colors.white54, size: 16),
            const SizedBox(width: 6),
            Text(
              '${value}j',
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const Icon(Icons.arrow_drop_down,
                color: Colors.white38, size: 16),
          ],
        ),
      ),
    );
  }
}

class _TeacherCard extends StatefulWidget {
  final UserModel teacher;
  final int validityDays;
  final ValueChanged<int> onValidityChanged;
  const _TeacherCard({
    required this.teacher,
    required this.validityDays,
    required this.onValidityChanged,
  });

  @override
  State<_TeacherCard> createState() => _TeacherCardState();
}

class _TeacherCardState extends State<_TeacherCard> {
  bool _generating = false;
  TeacherInvitation? _generated;

  @override
  void didUpdateWidget(covariant _TeacherCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.validityDays != widget.validityDays) {
      setState(() => _generated = null);
    }
  }

  Future<void> _generer() async {
    setState(() => _generating = true);
    try {
      final inv = await InvitationService.genererInvitation(
        teacherUid: widget.teacher.uid,
        teacherEmail: widget.teacher.email,
        teacherName: widget.teacher.displayName,
        validityDays: widget.validityDays,
      );
      if (mounted) setState(() => _generated = inv);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur : $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.teacher;
    return Card(
      color: const Color(0xFF161B22),
      margin: const EdgeInsets.only(bottom: 10),
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _Avatar(name: t.displayName),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t.displayName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        t.email,
                        style: const TextStyle(
                            color: Colors.white38, fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (t.matiere?.isNotEmpty == true)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color:
                          const Color(0xFF6C47FF).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: const Color(0xFF6C47FF)
                              .withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      t.matiere!,
                      style: const TextStyle(
                          color: Color(0xFF6C47FF), fontSize: 11),
                    ),
                  ),
              ],
            ),
            if (_generated != null) ...[
              const SizedBox(height: 12),
              _CodeDisplay(invitation: _generated!),
            ] else ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _generating ? null : _generer,
                  icon: _generating
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2),
                        )
                      : const Icon(Icons.add_circle_outline, size: 16),
                  label: Text(
                    _generating
                        ? 'Génération…'
                        : 'Générer un code (${widget.validityDays}j)',
                    style: const TextStyle(fontSize: 13),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6C47FF),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CodeDisplay extends StatelessWidget {
  final TeacherInvitation invitation;
  const _CodeDisplay({required this.invitation});

  @override
  Widget build(BuildContext context) {
    final expiry =
        '${invitation.expiresAt.day.toString().padLeft(2, '0')}/${invitation.expiresAt.month.toString().padLeft(2, '0')}/${invitation.expiresAt.year}';
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF059669).withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
        border:
            Border.all(color: const Color(0xFF059669).withValues(alpha: 0.35)),
      ),
      child: Column(
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle,
                  color: Color(0xFF34D399), size: 16),
              SizedBox(width: 6),
              Text(
                'Code généré avec succès',
                style: TextStyle(
                    color: Color(0xFF34D399),
                    fontWeight: FontWeight.w600,
                    fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () {
              Clipboard.setData(
                  ClipboardData(text: invitation.code));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Code copié dans le presse-papiers'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF0D1117),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: const Color(0xFF34D399)
                        .withValues(alpha: 0.4)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    invitation.code,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 4,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Icon(Icons.copy_outlined,
                      color: Colors.white38, size: 16),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Expire le $expiry',
            style: const TextStyle(color: Colors.white38, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _EmptySearch extends StatelessWidget {
  final bool hasFilter;
  const _EmptySearch({required this.hasFilter});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.person_search_outlined,
                color: Colors.white24, size: 48),
            const SizedBox(height: 14),
            Text(
              hasFilter
                  ? 'Aucun enseignant ne correspond aux critères'
                  : 'Aucun enseignant disponible',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white54, fontSize: 14),
            ),
            const SizedBox(height: 6),
            Text(
              hasFilter
                  ? 'Modifiez les filtres de recherche'
                  : 'Les enseignants sans école apparaissent ici',
              textAlign: TextAlign.center,
              style:
                  const TextStyle(color: Colors.white24, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Onglet 2 : Invitations envoyées ──────────────────────────────────────────

class _InvitationsTab extends StatelessWidget {
  final String schoolId;
  const _InvitationsTab({required this.schoolId});

  @override
  Widget build(BuildContext context) {
    if (schoolId.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF6C47FF)),
      );
    }
    return StreamBuilder<List<TeacherInvitation>>(
      stream: InvitationService.invitationsEcoleStream(schoolId),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF6C47FF)),
          );
        }
        if (snap.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Erreur Firestore : ${snap.error}',
                style: const TextStyle(
                    color: Color(0xFFEF4444), fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        final list = snap.data ?? [];
        if (list.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Text(
                'Aucune invitation envoyée',
                style: TextStyle(color: Colors.white38),
              ),
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
          itemCount: list.length,
          itemBuilder: (context, i) =>
              _InvitationTile(invitation: list[i]),
        );
      },
    );
  }
}

class _InvitationTile extends StatelessWidget {
  final TeacherInvitation invitation;
  const _InvitationTile({required this.invitation});

  Color get _statusColor {
    if (invitation.used) return const Color(0xFF059669);
    if (invitation.revoked) return const Color(0xFFEF4444);
    if (invitation.isExpired) return Colors.white38;
    return const Color(0xFFF59E0B);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  invitation.teacherName.isNotEmpty
                      ? invitation.teacherName
                      : invitation.teacherEmail,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      invitation.code,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () {
                        Clipboard.setData(
                            ClipboardData(text: invitation.code));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Code copié'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                      child: const Icon(Icons.copy_outlined,
                          color: Colors.white24, size: 14),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  _expiryLabel,
                  style: const TextStyle(
                      color: Colors.white38, fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _StatusChip(
                label: invitation.statusLabel,
                color: _statusColor,
              ),
              if (invitation.isValid) ...[
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: () => _confirmRevoke(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444)
                          .withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                          color: const Color(0xFFEF4444)
                              .withValues(alpha: 0.3)),
                    ),
                    child: const Text(
                      'Révoquer',
                      style: TextStyle(
                          color: Color(0xFFEF4444), fontSize: 11),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  String get _expiryLabel {
    final d = invitation.expiresAt;
    final formatted =
        '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    if (invitation.used && invitation.usedAt != null) {
      final u = invitation.usedAt!;
      return 'Utilisé le ${u.day.toString().padLeft(2, '0')}/${u.month.toString().padLeft(2, '0')}/${u.year}';
    }
    return 'Expire le $formatted';
  }

  Future<void> _confirmRevoke(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1F2937),
        title: const Text('Révoquer le code ?',
            style: TextStyle(color: Colors.white)),
        content: Text(
          'Le code ${invitation.code} sera invalidé immédiatement.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler',
                style: TextStyle(color: Colors.white38)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444)),
            child: const Text('Révoquer'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await InvitationService.revoquerInvitation(invitation.id);
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur : $e'),
              backgroundColor: const Color(0xFFEF4444),
            ),
          );
        }
      }
    }
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(label,
          style: TextStyle(color: color, fontSize: 11)),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String name;
  const _Avatar({required this.name});

  @override
  Widget build(BuildContext context) {
    final initials = name.trim().split(' ').take(2).map((w) {
      return w.isNotEmpty ? w[0].toUpperCase() : '';
    }).join();
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6C47FF), Color(0xFF2563EB)],
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Center(
        child: Text(
          initials,
          style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14),
        ),
      ),
    );
  }
}
