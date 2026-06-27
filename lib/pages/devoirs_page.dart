import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/devoir_model.dart';
import '../models/submission_model.dart';
import '../services/etudiant_service.dart';

enum DevoirStatus { aFaire, remis, corrige, enRetard }

class DevoirsPage extends StatelessWidget {
  const DevoirsPage({super.key});

  @override
  Widget build(BuildContext context) {
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
            return _unassigned();
          }
          return _DevoirsBody(classeNom: classeNom);
        },
      ),
    );
  }

  Widget _unassigned() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.school_outlined, color: Colors.white24, size: 48),
          SizedBox(height: 12),
          Text('Classe non assignee',
              style: TextStyle(color: Colors.white38, fontSize: 15)),
        ],
      ),
    );
  }
}

class _DevoirsBody extends StatefulWidget {
  final String classeNom;
  const _DevoirsBody({required this.classeNom});

  @override
  State<_DevoirsBody> createState() => _DevoirsBodyState();
}

class _DevoirsBodyState extends State<_DevoirsBody>
    with SingleTickerProviderStateMixin {
  List<DevoirModel> _devoirs = [];
  List<SubmissionModel> _submissions = [];
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    EtudiantService.devoirsStream(widget.classeNom).listen((d) {
      if (mounted) setState(() => _devoirs = d);
    });
    EtudiantService.submissionsStream().listen((s) {
      if (mounted) setState(() => _submissions = s);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  DevoirStatus _statusOf(DevoirModel d) {
    final sub = _submissions.where((s) => s.assignmentId == d.id).firstOrNull;
    if (sub != null && sub.status == SubmissionStatus.corrected) {
      return DevoirStatus.corrige;
    }
    if (sub != null && sub.status == SubmissionStatus.pending) {
      return DevoirStatus.remis;
    }
    if (sub == null &&
        d.dateLimite != null &&
        d.dateLimite!.isBefore(DateTime.now())) {
      return DevoirStatus.enRetard;
    }
    return DevoirStatus.aFaire;
  }

  List<DevoirModel> _filtered(DevoirStatus? filter) {
    if (filter == null) return _devoirs;
    return _devoirs.where((d) => _statusOf(d) == filter).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          color: const Color(0xFF161B22),
          child: TabBar(
            controller: _tabController,
            isScrollable: true,
            indicatorColor: const Color(0xFF6C47FF),
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white38,
            labelStyle: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600),
            tabs: const [
              Tab(text: 'Tous'),
              Tab(text: 'A faire'),
              Tab(text: 'Remis'),
              Tab(text: 'Corrige'),
              Tab(text: 'En retard'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _DevoirList(
                  devoirs: _filtered(null),
                  statusOf: _statusOf,
                  submissions: _submissions,
                  classeNom: widget.classeNom),
              _DevoirList(
                  devoirs: _filtered(DevoirStatus.aFaire),
                  statusOf: _statusOf,
                  submissions: _submissions,
                  classeNom: widget.classeNom),
              _DevoirList(
                  devoirs: _filtered(DevoirStatus.remis),
                  statusOf: _statusOf,
                  submissions: _submissions,
                  classeNom: widget.classeNom),
              _DevoirList(
                  devoirs: _filtered(DevoirStatus.corrige),
                  statusOf: _statusOf,
                  submissions: _submissions,
                  classeNom: widget.classeNom),
              _DevoirList(
                  devoirs: _filtered(DevoirStatus.enRetard),
                  statusOf: _statusOf,
                  submissions: _submissions,
                  classeNom: widget.classeNom),
            ],
          ),
        ),
      ],
    );
  }
}

class _DevoirList extends StatelessWidget {
  final List<DevoirModel> devoirs;
  final DevoirStatus Function(DevoirModel) statusOf;
  final List<SubmissionModel> submissions;
  final String classeNom;

  const _DevoirList({
    required this.devoirs,
    required this.statusOf,
    required this.submissions,
    required this.classeNom,
  });

  @override
  Widget build(BuildContext context) {
    if (devoirs.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.assignment_outlined, color: Colors.white24, size: 48),
            SizedBox(height: 12),
            Text('Aucun devoir',
                style: TextStyle(color: Colors.white38, fontSize: 15)),
          ],
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      itemCount: devoirs.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final d = devoirs[i];
        final sub =
            submissions.where((s) => s.assignmentId == d.id).firstOrNull;
        return _DevoirCard(
          devoir: d,
          status: statusOf(d),
          onTap: () =>
              _showDevoirDetail(context, d, sub, classeNom),
        );
      },
    );
  }
}

class _DevoirCard extends StatelessWidget {
  final DevoirModel devoir;
  final DevoirStatus status;
  final VoidCallback onTap;

  const _DevoirCard({
    required this.devoir,
    required this.status,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isLate = devoir.dateLimite != null &&
        devoir.dateLimite!.isBefore(now);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF161B22),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    devoir.titre,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600),
                  ),
                ),
                _StatusChip(status: status),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6C47FF).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(devoir.matiere,
                      style: const TextStyle(
                          color: Color(0xFF6C47FF), fontSize: 11)),
                ),
                const SizedBox(width: 8),
                Text(
                  'Prof: ${_truncate(devoir.professeurId)}',
                  style: const TextStyle(
                      color: Colors.white38, fontSize: 11),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.calendar_today_outlined,
                    color: Colors.white38, size: 12),
                const SizedBox(width: 4),
                Text(
                  'Envoye le ${_formatDate(devoir.dateEnvoi)}',
                  style: const TextStyle(
                      color: Colors.white38, fontSize: 11),
                ),
                if (devoir.dateLimite != null) ...[
                  const SizedBox(width: 12),
                  const Icon(Icons.timer_outlined,
                      color: Colors.white38, size: 12),
                  const SizedBox(width: 4),
                  Text(
                    'Limite: ${_formatDate(devoir.dateLimite!)}',
                    style: TextStyle(
                        color: isLate ? Colors.red : Colors.white38,
                        fontSize: 11),
                  ),
                ],
                const Spacer(),
                if (devoir.aFichier)
                  const Icon(Icons.attach_file,
                      color: Colors.white38, size: 14),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _truncate(String s) =>
      s.length > 12 ? '${s.substring(0, 12)}...' : s;

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

class _StatusChip extends StatelessWidget {
  final DevoirStatus status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;
    switch (status) {
      case DevoirStatus.aFaire:
        color = const Color(0xFF2563EB);
        label = 'A faire';
        break;
      case DevoirStatus.remis:
        color = const Color(0xFF16A34A);
        label = 'Remis';
        break;
      case DevoirStatus.corrige:
        color = const Color(0xFF6C47FF);
        label = 'Corrige';
        break;
      case DevoirStatus.enRetard:
        color = const Color(0xFFDC2626);
        label = 'En retard';
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}

void _showDevoirDetail(BuildContext context, DevoirModel devoir,
    SubmissionModel? submission, String classeNom) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF161B22),
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (ctx) => _DevoirDetailSheet(
        devoir: devoir, submission: submission, classeNom: classeNom),
  );
}

class _DevoirDetailSheet extends StatelessWidget {
  final DevoirModel devoir;
  final SubmissionModel? submission;
  final String classeNom;

  const _DevoirDetailSheet({
    required this.devoir,
    required this.submission,
    required this.classeNom,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isLate = devoir.dateLimite != null &&
        devoir.dateLimite!.isBefore(now);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      builder: (_, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Text(devoir.titre,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          if (devoir.description.isNotEmpty) ...[
            Text(
              devoir.description,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 16),
          ],
          _infoRow(Icons.subject_outlined, 'Matiere', devoir.matiere),
          _infoRow(Icons.class_outlined, 'Classe', devoir.classeNom),
          _infoRow(Icons.calendar_today_outlined, 'Envoye le',
              _formatDate(devoir.dateEnvoi)),
          if (devoir.dateLimite != null)
            _infoRow(
              Icons.timer_outlined,
              'Date limite',
              _formatDate(devoir.dateLimite!),
              valueColor: isLate ? Colors.red : null,
            ),
          if (devoir.aFichier) ...[
            const SizedBox(height: 12),
            _AttachButton(url: devoir.fichierUrl, nom: devoir.fichierNom),
          ],
          const SizedBox(height: 16),
          const Divider(color: Colors.white12),
          const SizedBox(height: 12),
          if (submission != null) ...[
            _SubmissionInfo(submission: submission!),
            const SizedBox(height: 12),
          ],
          if (submission == null) ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6C47FF),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.upload_outlined),
                label: const Text('Remettre le devoir'),
                onPressed: () {
                  Navigator.pop(context);
                  _showSubmitSheet(context, devoir);
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value,
      {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, color: Colors.white38, size: 16),
          const SizedBox(width: 8),
          Text('$label: ',
              style: const TextStyle(color: Colors.white38, fontSize: 13)),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                  color: valueColor ?? Colors.white70, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

class _SubmissionInfo extends StatelessWidget {
  final SubmissionModel submission;
  const _SubmissionInfo({required this.submission});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1117),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: const Color(0xFF16A34A).withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle_outline,
                  color: Color(0xFF16A34A), size: 18),
              const SizedBox(width: 8),
              Text(
                submission.status.label,
                style: const TextStyle(
                    color: Color(0xFF16A34A),
                    fontWeight: FontWeight.w600,
                    fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Remis le ${_formatDate(submission.createdAt)}',
            style: const TextStyle(color: Colors.white38, fontSize: 12),
          ),
          if (submission.grade != null) ...[
            const SizedBox(height: 6),
            Text(
              'Note: ${submission.grade}',
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14),
            ),
          ],
          if (submission.teacherComment != null &&
              submission.teacherComment!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Commentaire: ${submission.teacherComment}',
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

class _AttachButton extends StatelessWidget {
  final String url;
  final String nom;
  const _AttachButton({required this.url, required this.nom});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white70,
        side: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
      ),
      icon: const Icon(Icons.attach_file, size: 18),
      label: Text(
        nom.isNotEmpty ? nom : 'Piece jointe',
        overflow: TextOverflow.ellipsis,
      ),
      onPressed: () async {
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      },
    );
  }
}

void _showSubmitSheet(BuildContext context, DevoirModel devoir) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF161B22),
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (ctx) => _SubmitSheet(devoir: devoir),
  );
}

class _SubmitSheet extends StatefulWidget {
  final DevoirModel devoir;
  const _SubmitSheet({required this.devoir});

  @override
  State<_SubmitSheet> createState() => _SubmitSheetState();
}

class _SubmitSheetState extends State<_SubmitSheet> {
  final _commentController = TextEditingController();
  File? _file;
  String? _fileName;
  bool _loading = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'doc', 'docx'],
    );
    if (result != null && result.files.single.path != null) {
      setState(() {
        _file = File(result.files.single.path!);
        _fileName = result.files.single.name;
      });
    }
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final img = await picker.pickImage(source: ImageSource.gallery);
    if (img != null) {
      setState(() {
        _file = File(img.path);
        _fileName = img.name;
      });
    }
  }

  Future<void> _submit() async {
    setState(() => _loading = true);
    try {
      await EtudiantService.submitDevoir(
        assignmentId: widget.devoir.id,
        teacherId: widget.devoir.professeurId,
        file: _file,
        fileName: _fileName,
        comment: _commentController.text.trim(),
      );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Devoir remis avec succes'),
            backgroundColor: Color(0xFF16A34A),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const Text('Remettre le devoir',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(
              controller: _commentController,
              maxLines: 3,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Commentaire (optionnel)',
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: const Color(0xFF0D1117),
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
                  borderSide: const BorderSide(color: Color(0xFF6C47FF)),
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (_fileName != null)
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D1117),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: const Color(0xFF16A34A).withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.attach_file,
                        color: Color(0xFF16A34A), size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _fileName!,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 13),
                      ),
                    ),
                    GestureDetector(
                      onTap: () =>
                          setState(() {
                            _file = null;
                            _fileName = null;
                          }),
                      child: const Icon(Icons.close,
                          color: Colors.white38, size: 16),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white70,
                      side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.15)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      padding:
                          const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: const Icon(Icons.description_outlined, size: 18),
                    label: const Text('Fichier'),
                    onPressed: _pickFile,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white70,
                      side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.15)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      padding:
                          const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: const Icon(Icons.photo_outlined, size: 18),
                    label: const Text('Photo'),
                    onPressed: _pickPhoto,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6C47FF),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _loading ? null : _submit,
                child: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Text('Envoyer',
                        style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 15)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
