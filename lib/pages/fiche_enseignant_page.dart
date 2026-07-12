import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/disponibilite_model.dart';
import '../models/enseignant_profil_model.dart';
import '../models/remplacement_model.dart';
import '../services/remplacement_service.dart';
import '../services/storage_service.dart';

// ─── Constantes de couleurs ───────────────────────────────────────────────────

const _bg = Color(0xFF0D1117);
const _card = Color(0xFF161B22);
const _card2 = Color(0xFF1F2937);
const _blue = Color(0xFF2563EB);
const _purple = Color(0xFF6C47FF);
const _green = Color(0xFF16A34A);

// ─── Page principale ──────────────────────────────────────────────────────────

class FicheEnseignantPage extends StatefulWidget {
  final String uid;
  final String displayName;

  const FicheEnseignantPage({
    super.key,
    required this.uid,
    required this.displayName,
  });

  @override
  State<FicheEnseignantPage> createState() => _FicheEnseignantPageState();
}

class _FicheEnseignantPageState extends State<FicheEnseignantPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Stream<EnseignantProfil?> _profilStream() {
    return FirebaseFirestore.instance
        .collection('enseignants_profils')
        .doc(widget.uid)
        .snapshots()
        .map((snap) =>
            snap.exists ? EnseignantProfil.fromFirestore(snap) : null);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<EnseignantProfil?>(
      stream: _profilStream(),
      builder: (context, snap) {
        if (snap.hasError) {
          return Scaffold(
            backgroundColor: _bg,
            appBar: AppBar(
              backgroundColor: const Color(0xFF161B22),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            body: const Center(
              child: Text('Erreur de chargement du profil',
                  style: TextStyle(color: Colors.white38)),
            ),
          );
        }
        final profil = snap.data;
        return Scaffold(
          backgroundColor: _bg,
          body: NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) => [
              _buildSliverAppBar(profil, innerBoxIsScrolled),
            ],
            body: TabBarView(
              controller: _tabController,
              children: [
                _TabProfil(uid: widget.uid, profil: profil),
                _TabDisponibilites(uid: widget.uid),
                _TabDashboard(uid: widget.uid),
                _TabRemplacements(uid: widget.uid),
                _TabIA(uid: widget.uid),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSliverAppBar(EnseignantProfil? profil, bool innerBoxIsScrolled) {
    final name = profil?.fullName.isNotEmpty == true
        ? profil!.fullName
        : widget.displayName;
    final matiere =
        (profil?.matieres.isNotEmpty == true) ? profil!.matieres.first : '';
    final statut = profil?.statut ?? 'Actif';

    Color statutColor;
    switch (statut) {
      case 'En congé':
        statutColor = Colors.amber;
        break;
      case 'Absent':
        statutColor = Colors.red;
        break;
      default:
        statutColor = Colors.green;
    }

    return SliverAppBar(
      expandedHeight: 200,
      floating: false,
      pinned: true,
      backgroundColor: const Color(0xFF161B22),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        if (profil != null)
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: Colors.white70),
            tooltip: 'Modifier le profil',
            onPressed: () => _openEditDialog(profil),
          ),
        IconButton(
          icon: const Icon(Icons.delete_outline, color: Color(0xFFEF4444)),
          tooltip: 'Supprimer le professeur',
          onPressed: () => _confirmDeleteProfesseur(name),
        ),
      ],
      bottom: TabBar(
        controller: _tabController,
        indicatorColor: _purple,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white38,
        labelStyle:
            const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        isScrollable: true,
        tabs: const [
          Tab(text: 'Profil'),
          Tab(text: 'Disponibilités'),
          Tab(text: 'Tableau de bord'),
          Tab(text: 'Remplacements'),
          Tab(text: 'IA'),
        ],
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1A1040), Color(0xFF0F1B3D)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 48),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 42,
                    backgroundColor: _purple.withValues(alpha: 0.3),
                    backgroundImage: profil?.photoUrl != null
                        ? NetworkImage(profil!.photoUrl!)
                        : null,
                    child: profil?.photoUrl == null
                        ? Text(
                            name.isNotEmpty
                                ? name[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 32,
                                fontWeight: FontWeight.bold),
                          )
                        : null,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            _SmallChip(
                                label: 'Professeur',
                                color: _purple.withValues(alpha: 0.8)),
                            if (matiere.isNotEmpty) ...[
                              const SizedBox(width: 6),
                              _SmallChip(
                                  label: matiere,
                                  color: _blue.withValues(alpha: 0.8)),
                            ],
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: statutColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              statut,
                              style: TextStyle(
                                  color: statutColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _openEditDialog(EnseignantProfil profil) {
    showDialog(
      context: context,
      builder: (_) => _EditProfilDialog(profil: profil),
    );
  }

  /// Supprime le compte professeur. Bloque si des classes lui sont encore
  /// affectées (professeurId == uid) — la Direction doit d'abord réaffecter
  /// ces classes à un autre enseignant.
  Future<void> _confirmDeleteProfesseur(String name) async {
    final db = FirebaseFirestore.instance;
    final classesSnap = await db
        .collection('classes')
        .where('professeurId', isEqualTo: widget.uid)
        .get();

    if (!mounted) return;

    if (classesSnap.docs.isNotEmpty) {
      final noms = classesSnap.docs
          .map((d) => (d.data())['nom'] as String? ?? d.id)
          .join(', ');
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: _card,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Suppression impossible',
              style: TextStyle(color: Colors.white, fontSize: 16)),
          content: Text(
            'Ce professeur est encore affecté à la classe : $noms.\n\n'
            'Réaffectez d\'abord ces classes à un autre enseignant depuis '
            '« Gestion des classes » avant de supprimer ce compte.',
            style: const TextStyle(color: Colors.white54, fontSize: 13, height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Compris', style: TextStyle(color: _purple)),
            ),
          ],
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Supprimer ce professeur ?',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        content: Text(
          'Cette action supprime définitivement le compte de $name '
          'ainsi que sa fiche enseignante.\n\nCette action est irréversible.',
          style: const TextStyle(color: Colors.white54, fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler', style: TextStyle(color: Colors.white60)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer',
                style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      final batch = db.batch();
      batch.delete(db.collection('users').doc(widget.uid));
      batch.delete(db.collection('enseignants_profils').doc(widget.uid));
      await batch.commit();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('$name supprimé(e)'),
          backgroundColor: const Color(0xFF16A34A),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erreur lors de la suppression : $e'),
          backgroundColor: const Color(0xFFEF4444),
          duration: const Duration(seconds: 6),
        ));
      }
    }
  }
}

// ─── Tab 1 — Profil ───────────────────────────────────────────────────────────

class _TabProfil extends StatelessWidget {
  final String uid;
  final EnseignantProfil? profil;

  const _TabProfil({required this.uid, required this.profil});

  @override
  Widget build(BuildContext context) {
    if (profil == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: _purple),
            const SizedBox(height: 16),
            const Text('Chargement du profil…',
                style: TextStyle(color: Colors.white54)),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () => _createProfil(context),
              icon: const Icon(Icons.add, color: _purple),
              label: const Text('Créer le profil',
                  style: TextStyle(color: _purple)),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionCard(
            title: 'Informations personnelles',
            child: _PersonalInfoSection(profil: profil!),
          ),
          const SizedBox(height: 12),
          _SectionCard(
            title: 'Informations professionnelles',
            child: _ProfessionalInfoSection(uid: uid, profil: profil!),
          ),
          const SizedBox(height: 12),
          _SectionCard(
            title: 'CV',
            child: _CvSection(uid: uid, profil: profil!),
          ),
        ],
      ),
    );
  }

  Future<void> _createProfil(BuildContext context) async {
    // Créer un profil vide dans Firestore
    final empty = EnseignantProfil(uid: uid, nom: '', prenom: '');
    await FirebaseFirestore.instance
        .collection('enseignants_profils')
        .doc(uid)
        .set(empty.toMap());
  }
}

class _PersonalInfoSection extends StatelessWidget {
  final EnseignantProfil profil;
  const _PersonalInfoSection({required this.profil});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _InfoField(label: 'Nom', value: profil.nom),
            const SizedBox(width: 10),
            _InfoField(label: 'Prénom', value: profil.prenom),
            const SizedBox(width: 10),
            _InfoField(label: 'Sexe', value: profil.sexe ?? '—'),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _InfoField(
                label: 'Date de naissance',
                value: profil.dateNaissance ?? '—'),
            const SizedBox(width: 10),
            _InfoField(
                label: 'Nationalité', value: profil.nationalite ?? '—'),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _InfoField(label: 'Téléphone', value: profil.telephone ?? '—'),
            const SizedBox(width: 10),
            _InfoField(label: 'Email', value: profil.email ?? '—'),
          ],
        ),
        const SizedBox(height: 10),
        _InfoField(
            label: 'Adresse',
            value: profil.adresse ?? '—',
            expanded: true),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: _blue.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _blue.withValues(alpha: 0.25)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Matricule enseignant',
                  style: TextStyle(color: Colors.white54, fontSize: 11)),
              const SizedBox(height: 4),
              Text(
                profil.matriculeDisplay,
                style: const TextStyle(
                    color: _blue,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProfessionalInfoSection extends StatelessWidget {
  final String uid;
  final EnseignantProfil profil;
  const _ProfessionalInfoSection({required this.uid, required this.profil});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ChipListField(label: 'Matières enseignées', items: profil.matieres, color: _blue),
        const SizedBox(height: 10),
        _ChipListField(label: 'Cycles', items: profil.cycles, color: _purple),
        const SizedBox(height: 10),
        _ChipListField(label: 'Niveaux', items: profil.niveaux, color: Colors.teal),
        const SizedBox(height: 10),
        // Classes from Firestore
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('classes')
              .where('professeurId', isEqualTo: uid)
              .snapshots(),
          builder: (context, snap) {
            final classes = snap.data?.docs
                    .map((d) =>
                        (d.data() as Map<String, dynamic>)['nom'] as String? ??
                        d.id)
                    .toList() ??
                [];
            return _ChipListField(
                label: 'Classes attribuées',
                items: classes,
                color: Colors.orange);
          },
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _InfoField(
                label: "Date d'embauche",
                value: profil.dateEmbauche ?? '—'),
            const SizedBox(width: 10),
            _InfoField(
                label: 'Type de contrat',
                value: profil.typeContrat ?? '—'),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: _card2,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      profil.tempsPlein
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      color: profil.tempsPlein ? Colors.green : Colors.white38,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      profil.tempsPlein ? 'Temps plein' : 'Temps partiel',
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatutBadgeField(statut: profil.statut),
            ),
          ],
        ),
      ],
    );
  }
}

class _CvSection extends StatefulWidget {
  final String uid;
  final EnseignantProfil profil;
  const _CvSection({required this.uid, required this.profil});

  @override
  State<_CvSection> createState() => _CvSectionState();
}

class _CvSectionState extends State<_CvSection> {
  bool _uploading = false;

  Future<void> _pickAndUpload() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx'],
    );
    if (result == null || result.files.single.path == null) return;

    final file = File(result.files.single.path!);
    final fileName = result.files.single.name;
    setState(() => _uploading = true);
    try {
      final url =
          await StorageService.uploadTeacherDocument(file, widget.uid, 'cv');
      if (url == null) {
        throw Exception('Échec de l\'envoi du fichier');
      }
      await FirebaseFirestore.instance
          .collection('enseignants_profils')
          .doc(widget.uid)
          .set({'cvUrl': url, 'cvNom': fileName}, SetOptions(merge: true));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erreur lors de l\'envoi du CV : $e'),
          backgroundColor: const Color(0xFFEF4444),
          duration: const Duration(seconds: 6),
        ));
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _openCv(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Impossible d\'ouvrir le CV'),
        backgroundColor: Color(0xFFEF4444),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasCv = widget.profil.cvUrl != null && widget.profil.cvUrl!.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasCv)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: _green.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _green.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.description_outlined, color: _green, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.profil.cvNom ?? 'CV.pdf',
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                TextButton(
                  onPressed: () => _openCv(widget.profil.cvUrl!),
                  child: const Text('Consulter',
                      style: TextStyle(color: _green, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          )
        else
          const Text(
            'Aucun CV téléversé pour ce professeur.',
            style: TextStyle(color: Colors.white38, fontSize: 12),
          ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _uploading ? null : _pickAndUpload,
            icon: _uploading
                ? const SizedBox(
                    width: 14, height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: _purple))
                : const Icon(Icons.upload_file_outlined, size: 16, color: _purple),
            label: Text(hasCv ? 'Remplacer le CV' : 'Téléverser un CV',
                style: const TextStyle(color: _purple)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: _purple),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(vertical: 10),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Tab 2 — Disponibilités ───────────────────────────────────────────────────

class _TabDisponibilites extends StatefulWidget {
  final String uid;
  const _TabDisponibilites({required this.uid});

  @override
  State<_TabDisponibilites> createState() => _TabDisponibilitesState();
}

class _TabDisponibilitesState extends State<_TabDisponibilites> {
  static const _jours = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam'];
  static const _joursLong = [
    'Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi'
  ];

  DateTime _weekStart = _currentWeekStart();

  static DateTime _currentWeekStart() {
    final now = DateTime.now();
    return now.subtract(Duration(days: now.weekday - 1));
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DisponibiliteEnseignant?>(
      stream: RemplacementService.disponibiliteStream(widget.uid),
      builder: (context, snap) {
        final dispo = snap.data;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionCard(
                title: 'Jours disponibles',
                child: _JoursDisponibles(
                    dispo: dispo, uid: widget.uid, joursLong: _joursLong, jours: _jours),
              ),
              const SizedBox(height: 12),
              _SectionCard(
                title: 'Créneaux horaires',
                child: _CreneauxSection(dispo: dispo, uid: widget.uid),
              ),
              const SizedBox(height: 12),
              _SectionCard(
                title: 'Calendrier hebdomadaire',
                child: _CalendrierHebdo(
                  dispo: dispo,
                  weekStart: _weekStart,
                  uid: widget.uid,
                  onPrev: () => setState(
                      () => _weekStart = _weekStart.subtract(const Duration(days: 7))),
                  onNext: () => setState(
                      () => _weekStart = _weekStart.add(const Duration(days: 7))),
                ),
              ),
              const SizedBox(height: 12),
              _SectionCard(
                title: 'Congés & Absences déclarées',
                child: _AbsencesSection(uid: widget.uid),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _JoursDisponibles extends StatelessWidget {
  final DisponibiliteEnseignant? dispo;
  final String uid;
  final List<String> joursLong;
  final List<String> jours;

  const _JoursDisponibles({
    required this.dispo,
    required this.uid,
    required this.joursLong,
    required this.jours,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: List.generate(jours.length, (i) {
        final jourLong = joursLong[i];
        final selected = dispo?.jours.contains(jourLong) ?? false;
        return ChoiceChip(
          label: Text(jours[i]),
          selected: selected,
          selectedColor: _purple,
          backgroundColor: _card2,
          labelStyle: TextStyle(
            color: selected ? Colors.white : Colors.white54,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
          onSelected: (val) => _toggleJour(context, jourLong, val, dispo),
        );
      }),
    );
  }

  Future<void> _toggleJour(BuildContext context, String jour, bool add,
      DisponibiliteEnseignant? current) async {
    final currentJours = List<String>.from(current?.jours ?? []);
    if (add) {
      if (!currentJours.contains(jour)) {
        currentJours.add(jour);
      }
    } else {
      currentJours.remove(jour);
    }
    final updated = (current ?? DisponibiliteEnseignant(
          uid: uid,
          nom: '',
          email: '',
          jours: [],
          creneaux: [],
          matieres: [],
          niveaux: [],
          classes: [],
          disponibleAujourdhui: false,
        ))
        .copyWith(jours: currentJours);
    await RemplacementService.saveDisponibilite(uid, updated);
  }
}

class _CreneauxSection extends StatelessWidget {
  final DisponibiliteEnseignant? dispo;
  final String uid;
  const _CreneauxSection({required this.dispo, required this.uid});

  @override
  Widget build(BuildContext context) {
    final creneaux = dispo?.creneaux ?? [];
    return Column(
      children: [
        if (creneaux.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('Aucun créneau défini',
                style: TextStyle(color: Colors.white38, fontSize: 13)),
          )
        else
          ...creneaux.map((c) => _CreneauTile(
                creneau: c,
                onDelete: () => _deleteCreneau(c),
              )),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => _addCreneau(context),
          icon: const Icon(Icons.add, size: 18, color: _purple),
          label:
              const Text('Ajouter un créneau', style: TextStyle(color: _purple)),
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: _purple.withValues(alpha: 0.5)),
          ),
        ),
      ],
    );
  }

  Future<void> _deleteCreneau(CreneauHoraire creneau) async {
    final updated = (dispo!).copyWith(
        creneaux: dispo!.creneaux.where((c) => c != creneau).toList());
    await RemplacementService.saveDisponibilite(uid, updated);
  }

  Future<void> _addCreneau(BuildContext context) async {
    final result = await showDialog<CreneauHoraire>(
      context: context,
      builder: (_) => const _AddCreneauDialog(),
    );
    if (result == null) return;
    final current = dispo ?? DisponibiliteEnseignant(
      uid: uid, nom: '', email: '', jours: [], creneaux: [],
      matieres: [], niveaux: [], classes: [], disponibleAujourdhui: false,
    );
    final updated = current.copyWith(creneaux: [...current.creneaux, result]);
    await RemplacementService.saveDisponibilite(uid, updated);
  }
}

class _CreneauTile extends StatelessWidget {
  final CreneauHoraire creneau;
  final VoidCallback onDelete;
  const _CreneauTile({required this.creneau, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _card2,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.schedule, color: _purple, size: 18),
          const SizedBox(width: 10),
          Text(creneau.jour,
              style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
          const SizedBox(width: 8),
          Text('${creneau.heureDebut} – ${creneau.heureFin}',
              style: const TextStyle(color: Colors.white54, fontSize: 12)),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.close, size: 16, color: Colors.white24),
            onPressed: onDelete,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          ),
        ],
      ),
    );
  }
}

class _CalendrierHebdo extends StatelessWidget {
  final DisponibiliteEnseignant? dispo;
  final DateTime weekStart;
  final String uid;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  const _CalendrierHebdo({
    required this.dispo,
    required this.weekStart,
    required this.uid,
    required this.onPrev,
    required this.onNext,
  });

  static const _colHeaders = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];
  static const _joursLong = [
    'Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi', 'Dimanche'
  ];

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final todayIdx = now.weekday - 1; // 0=Lundi
    final weekLabel =
        '${weekStart.day}/${weekStart.month} – ${weekStart.add(const Duration(days: 6)).day}/${weekStart.add(const Duration(days: 6)).month}';

    return Column(
      children: [
        // Navigation
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left, color: Colors.white54),
              onPressed: onPrev,
            ),
            Text(weekLabel,
                style: const TextStyle(color: Colors.white70, fontSize: 13)),
            IconButton(
              icon: const Icon(Icons.chevron_right, color: Colors.white54),
              onPressed: onNext,
            ),
          ],
        ),
        const SizedBox(height: 6),
        // Grid header
        Row(
          children: List.generate(7, (i) {
            final isToday = _isSameWeek() && i == todayIdx;
            return Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 6),
                margin: const EdgeInsets.symmetric(horizontal: 1),
                decoration: BoxDecoration(
                  color: isToday
                      ? _purple.withValues(alpha: 0.2)
                      : _card2,
                  borderRadius: BorderRadius.circular(6),
                  border: isToday
                      ? Border.all(color: _purple.withValues(alpha: 0.6))
                      : null,
                ),
                child: Text(
                  _colHeaders[i],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isToday ? _purple : Colors.white38,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 4),
        // Grid rows (slots)
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: List.generate(7, (dayIdx) {
            final jourLong = _joursLong[dayIdx];
            final creneaux = dispo?.creneaux
                    .where((c) => c.jour == jourLong)
                    .toList() ??
                [];
            final isAvail = dispo?.jours.contains(jourLong) ?? false;
            final isToday = _isSameWeek() && dayIdx == todayIdx;

            return Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 1),
                padding:
                    const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                decoration: BoxDecoration(
                  color: isAvail
                      ? Colors.green.withValues(alpha: 0.07)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  border: isToday
                      ? Border.all(color: _purple.withValues(alpha: 0.4))
                      : Border.all(
                          color: Colors.white.withValues(alpha: 0.04)),
                ),
                child: Column(
                  children: [
                    if (creneaux.isEmpty)
                      Container(
                        height: 28,
                        decoration: BoxDecoration(
                          color: isAvail
                              ? Colors.green.withValues(alpha: 0.15)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      )
                    else
                      ...creneaux.map((c) => Container(
                            margin: const EdgeInsets.only(bottom: 3),
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '${c.heureDebut}\n${c.heureFin}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  color: Colors.greenAccent,
                                  fontSize: 9),
                            ),
                          )),
                  ],
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 8),
        // Legend
        Wrap(
          spacing: 12,
          children: [
            _LegendDot(color: Colors.green, label: 'Disponible'),
            _LegendDot(color: Colors.red, label: 'Absent'),
            _LegendDot(color: Colors.orange, label: 'Remplacement'),
          ],
        ),
      ],
    );
  }

  bool _isSameWeek() {
    final now = DateTime.now();
    final thisWeekStart =
        now.subtract(Duration(days: now.weekday - 1));
    return weekStart.year == thisWeekStart.year &&
        weekStart.month == thisWeekStart.month &&
        weekStart.day == thisWeekStart.day;
  }
}

class _AbsencesSection extends StatelessWidget {
  final String uid;
  const _AbsencesSection({required this.uid});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('disponibilites')
              .doc(uid)
              .collection('absences')
              .orderBy('date', descending: true)
              .limit(20)
              .snapshots(),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(
                  child: CircularProgressIndicator(color: _purple));
            }
            final docs = snap.data?.docs ?? [];
            if (docs.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('Aucune absence déclarée',
                    style: TextStyle(color: Colors.white38, fontSize: 13)),
              );
            }
            return Column(
              children: docs
                  .map((doc) => _AbsenceTile(
                      data: doc.data() as Map<String, dynamic>))
                  .toList(),
            );
          },
        ),
        const SizedBox(height: 8),
        ElevatedButton.icon(
          onPressed: () => _showDeclareAbsenceDialog(context),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Déclarer une absence'),
          style: ElevatedButton.styleFrom(
            backgroundColor: _purple,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }

  void _showDeclareAbsenceDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => _DeclareAbsenceDialog(uid: uid),
    );
  }
}

class _AbsenceTile extends StatelessWidget {
  final Map<String, dynamic> data;
  const _AbsenceTile({required this.data});

  @override
  Widget build(BuildContext context) {
    final motif = (data['motif'] as String?) ?? 'autre';
    final date = (data['date'] as String?) ?? '';
    final commentaire = (data['commentaire'] as String?) ?? '';

    Color motifColor;
    switch (motif) {
      case 'maladie':
        motifColor = Colors.red;
        break;
      case 'formation':
        motifColor = _blue;
        break;
      case 'conge':
        motifColor = Colors.green;
        break;
      default:
        motifColor = Colors.grey;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _card2,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: motifColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: motifColor.withValues(alpha: 0.4)),
            ),
            child: Text(
              _motifLabel(motif),
              style: TextStyle(
                  color: motifColor, fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(date,
                    style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
                if (commentaire.isNotEmpty)
                  Text(commentaire,
                      style:
                          const TextStyle(color: Colors.white38, fontSize: 11),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _motifLabel(String motif) {
    switch (motif) {
      case 'maladie':
        return 'Maladie';
      case 'formation':
        return 'Formation';
      case 'conge':
        return 'Congé';
      default:
        return 'Autre';
    }
  }
}

// ─── Tab 3 — Tableau de bord ──────────────────────────────────────────────────

class _TabDashboard extends StatelessWidget {
  final String uid;
  const _TabDashboard({required this.uid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Remplacement>>(
      stream: RemplacementService.remplacementsStream(),
      builder: (context, snap) {
        final all = snap.data ?? [];
        final mine = all.where((r) =>
            r.professeurRemplacantUid == uid ||
            r.professeurAbsentUid == uid).toList();

        final now = DateTime.now();
        final monthStr =
            '${now.year}-${now.month.toString().padLeft(2, '0')}';
        final thisMon = mine
            .where((r) => r.date.startsWith(monthStr))
            .toList();
        final remplacThisMon = thisMon
            .where((r) =>
                r.statut == RemplacementStatut.termine &&
                r.professeurRemplacantUid == uid)
            .length;

        // KPI: disponibilité cette semaine
        final weekStart = now.subtract(Duration(days: now.weekday - 1));
        final weekDays = List.generate(5, (i) {
          final d = weekStart.add(Duration(days: i));
          return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
        });
        final remplacWeek = mine
            .where((r) => weekDays.contains(r.date))
            .length;

        // Charge %
        final charge = ((remplacThisMon / 10.0) * 100).clamp(0, 100).round();

        final last5 = mine.take(5).toList();
        final alertHigh = remplacThisMon > 8;
        final alertCritical = remplacThisMon > 12;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // KPIs
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 1.6,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                children: [
                  _KpiCard(
                    title: 'Heures ce mois',
                    value: '${remplacThisMon * 2}h',
                    icon: Icons.schedule,
                    color: _blue,
                  ),
                  _KpiCard(
                    title: 'Remplacements',
                    value: '$remplacThisMon',
                    icon: Icons.swap_horiz,
                    color: _purple,
                  ),
                  _KpiCard(
                    title: 'Dispo cette semaine',
                    value: '$remplacWeek/5j',
                    icon: Icons.event_available,
                    color: Colors.teal,
                  ),
                  _KpiCard(
                    title: 'Charge de travail',
                    value: '$charge%',
                    icon: Icons.bar_chart,
                    color: charge > 80 ? Colors.red : Colors.green,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Alertes
              if (alertCritical)
                _AlertCard(
                  icon: Icons.warning,
                  color: Colors.red,
                  title: 'Surcharge détectée',
                  subtitle:
                      'Envisager une redistribution des remplacements ($remplacThisMon ce mois)',
                )
              else if (alertHigh)
                _AlertCard(
                  icon: Icons.warning_amber,
                  color: Colors.orange,
                  title: 'Charge élevée',
                  subtitle:
                      '$remplacThisMon remplacements ce mois — surveillance recommandée',
                ),
              const SizedBox(height: 12),
              _SectionCard(
                title: 'Historique des remplacements',
                child: last5.isEmpty
                    ? const Text('Aucun remplacement',
                        style: TextStyle(color: Colors.white38, fontSize: 13))
                    : Column(
                        children:
                            last5.map((r) => _RemplacementMiniCard(r: r, uid: uid)).toList(),
                      ),
              ),
              const SizedBox(height: 12),
              _SectionCard(
                title: 'Absences récentes',
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('disponibilites')
                      .doc(uid)
                      .collection('absences')
                      .orderBy('date', descending: true)
                      .limit(3)
                      .snapshots(),
                  builder: (context, absSnap) {
                    final absDocs = absSnap.data?.docs ?? [];
                    if (absDocs.isEmpty) {
                      return const Text('Aucune absence récente',
                          style:
                              TextStyle(color: Colors.white38, fontSize: 13));
                    }
                    return Column(
                      children: absDocs
                          .map((d) => _AbsenceTile(
                              data: d.data() as Map<String, dynamic>))
                          .toList(),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  const _KpiCard(
      {required this.title,
      required this.value,
      required this.icon,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: color, size: 22),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value,
                  style: TextStyle(
                      color: color,
                      fontSize: 20,
                      fontWeight: FontWeight.bold)),
              Text(title,
                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        ],
      ),
    );
  }
}

class _AlertCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  const _AlertCard(
      {required this.icon,
      required this.color,
      required this.title,
      required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.bold,
                        fontSize: 13)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style:
                        const TextStyle(color: Colors.white54, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RemplacementMiniCard extends StatelessWidget {
  final Remplacement r;
  final String uid;
  const _RemplacementMiniCard({required this.r, required this.uid});

  @override
  Widget build(BuildContext context) {
    final isRemplacant = r.professeurRemplacantUid == uid;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _card2,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: isRemplacant
                  ? Colors.green.withValues(alpha: 0.15)
                  : Colors.orange.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              isRemplacant ? 'Remplaçant' : 'Absent remplacé',
              style: TextStyle(
                color: isRemplacant ? Colors.greenAccent : Colors.orange,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${r.matiere} — ${r.classeNom}',
                    style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
                Text('${r.date}  ${r.heureDebut}–${r.heureFin}',
                    style:
                        const TextStyle(color: Colors.white38, fontSize: 11)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: r.statutColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(r.statutLabel,
                style: TextStyle(color: r.statutColor, fontSize: 10)),
          ),
        ],
      ),
    );
  }
}

// ─── Tab 4 — Remplacements ────────────────────────────────────────────────────

class _TabRemplacements extends StatefulWidget {
  final String uid;
  const _TabRemplacements({required this.uid});

  @override
  State<_TabRemplacements> createState() => _TabRemplacementsState();
}

class _TabRemplacementsState extends State<_TabRemplacements> {
  String _filter = 'Tous';
  static const _filters = [
    'Tous',
    'Remplaçant',
    'Absent',
    'En attente',
    'Terminé',
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Filter chips
        SizedBox(
          height: 48,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            itemCount: _filters.length,
            itemBuilder: (context, i) {
              final f = _filters[i];
              final sel = _filter == f;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(f),
                  selected: sel,
                  selectedColor: _purple,
                  backgroundColor: _card2,
                  labelStyle: TextStyle(
                    color: sel ? Colors.white : Colors.white54,
                    fontSize: 12,
                  ),
                  onSelected: (_) => setState(() => _filter = f),
                ),
              );
            },
          ),
        ),
        Expanded(
          child: StreamBuilder<List<Remplacement>>(
            stream: RemplacementService.remplacementsStream(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(
                    child: CircularProgressIndicator(color: _purple));
              }
              var all = (snap.data ?? []).where((r) =>
                  r.professeurRemplacantUid == widget.uid ||
                  r.professeurAbsentUid == widget.uid).toList();

              switch (_filter) {
                case 'Remplaçant':
                  all = all
                      .where((r) => r.professeurRemplacantUid == widget.uid)
                      .toList();
                  break;
                case 'Absent':
                  all = all
                      .where((r) => r.professeurAbsentUid == widget.uid)
                      .toList();
                  break;
                case 'En attente':
                  all = all
                      .where(
                          (r) => r.statut == RemplacementStatut.enAttente)
                      .toList();
                  break;
                case 'Terminé':
                  all = all
                      .where(
                          (r) => r.statut == RemplacementStatut.termine)
                      .toList();
                  break;
                default:
                  break;
              }

              if (all.isEmpty) {
                return const Center(
                  child: Text('Aucun remplacement',
                      style: TextStyle(color: Colors.white38)),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.all(14),
                itemCount: all.length,
                itemBuilder: (context, i) =>
                    _FicheRemplacementCard(r: all[i], uid: widget.uid),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _FicheRemplacementCard extends StatelessWidget {
  final Remplacement r;
  final String uid;
  const _FicheRemplacementCard({required this.r, required this.uid});

  @override
  Widget build(BuildContext context) {
    final isRemplacant = r.professeurRemplacantUid == uid;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isRemplacant
                      ? Colors.green.withValues(alpha: 0.15)
                      : Colors.orange.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  isRemplacant ? 'Remplaçant' : 'Absent remplacé',
                  style: TextStyle(
                    color: isRemplacant ? Colors.greenAccent : Colors.orange,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: r.statutColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: r.statutColor.withValues(alpha: 0.3)),
                ),
                child: Text(r.statutLabel,
                    style: TextStyle(color: r.statutColor, fontSize: 11)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.book_outlined, color: Colors.white38, size: 16),
              const SizedBox(width: 6),
              Text(r.matiere,
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w600)),
              const SizedBox(width: 12),
              const Icon(Icons.class_outlined, color: Colors.white38, size: 16),
              const SizedBox(width: 6),
              Text(r.classeNom,
                  style: const TextStyle(color: Colors.white70)),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.calendar_today, color: Colors.white38, size: 14),
              const SizedBox(width: 6),
              Text(r.date,
                  style:
                      const TextStyle(color: Colors.white54, fontSize: 12)),
              const SizedBox(width: 12),
              const Icon(Icons.schedule, color: Colors.white38, size: 14),
              const SizedBox(width: 6),
              Text('${r.heureDebut} – ${r.heureFin}',
                  style:
                      const TextStyle(color: Colors.white54, fontSize: 12)),
            ],
          ),
          if (r.statut == RemplacementStatut.propose) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () =>
                        RemplacementService.updateStatut(r.id, RemplacementStatut.accepte),
                    style: OutlinedButton.styleFrom(
                      side:
                          const BorderSide(color: Colors.green),
                      foregroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    child: const Text('Accepter', style: TextStyle(fontSize: 12)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () =>
                        RemplacementService.updateStatut(r.id, RemplacementStatut.refuse),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.red),
                      foregroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    child: const Text('Refuser', style: TextStyle(fontSize: 12)),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Tab 5 — IA ───────────────────────────────────────────────────────────────

class _TabIA extends StatefulWidget {
  final String uid;
  const _TabIA({required this.uid});

  @override
  State<_TabIA> createState() => _TabIAState();
}

class _TabIAState extends State<_TabIA> {
  // Suggestion remplaçant
  String _matiere = '';
  String _jour = 'Lundi';
  String _heure = '08:00';
  List<DisponibiliteEnseignant>? _candidats;
  bool _loadingCandidats = false;

  // Conflits
  List<String> _conflits = [];
  bool _loadingConflits = false;
  bool _conflitsAnalyzed = false;

  // Charge équilibrage
  double _myCharge = 0;
  double _teamAvg = 0;
  bool _loadingCharge = false;
  bool _chargeLoaded = false;

  static const _joursOptions = [
    'Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi'
  ];
  static const _heuresOptions = [
    '08:00', '09:00', '10:00', '11:00', '12:00', '13:00',
    '14:00', '15:00', '16:00', '17:00'
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_purple, _blue],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(Icons.psychology, color: Colors.white, size: 36),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text('Intelligence Artificielle',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold)),
                      SizedBox(height: 2),
                      Text('Analyse et suggestions automatiques',
                          style: TextStyle(color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Suggestion remplaçant ──────────────────────────────────────────
          _SectionCard(
            title: 'Suggestion de remplaçant',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputDeco('Matière recherchée'),
                  onChanged: (v) => setState(() => _matiere = v),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _jour,
                        dropdownColor: _card2,
                        style: const TextStyle(color: Colors.white),
                        decoration: _inputDeco('Jour'),
                        items: _joursOptions
                            .map((j) => DropdownMenuItem(
                                value: j,
                                child: Text(j,
                                    style: const TextStyle(
                                        color: Colors.white))))
                            .toList(),
                        onChanged: (v) {
                          if (v != null) {
                            setState(() => _jour = v);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _heure,
                        dropdownColor: _card2,
                        style: const TextStyle(color: Colors.white),
                        decoration: _inputDeco('Heure'),
                        items: _heuresOptions
                            .map((h) => DropdownMenuItem(
                                value: h,
                                child: Text(h,
                                    style: const TextStyle(
                                        color: Colors.white))))
                            .toList(),
                        onChanged: (v) {
                          if (v != null) {
                            setState(() => _heure = v);
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _matiere.isEmpty || _loadingCandidats
                        ? null
                        : _analyserRemplacants,
                    icon: _loadingCandidats
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.search, size: 18),
                    label: const Text('Analyser'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _purple,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                if (_candidats != null) ...[
                  const SizedBox(height: 12),
                  if (_candidats!.isEmpty)
                    const Text('Aucun candidat trouvé',
                        style: TextStyle(color: Colors.white38, fontSize: 13))
                  else
                    ..._candidats!.asMap().entries.map((entry) {
                      final score = 100 -
                          (entry.key * 15).clamp(0, 80);
                      return _CandidatCard(
                          dispo: entry.value, score: score.toDouble());
                    }),
                  const SizedBox(height: 4),
                  const Text(
                    '// TODO: intégrer moteur IA avancé pour scoring contextuel',
                    style: TextStyle(color: Colors.white24, fontSize: 10),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ── Détection des conflits ─────────────────────────────────────────
          _SectionCard(
            title: 'Détection des conflits',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _loadingConflits ? null : _analyserConflits,
                    icon: _loadingConflits
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: _purple))
                        : const Icon(Icons.warning_outlined,
                            size: 18, color: _purple),
                    label: const Text('Analyser les conflits',
                        style: TextStyle(color: _purple)),
                    style: OutlinedButton.styleFrom(
                      side:
                          BorderSide(color: _purple.withValues(alpha: 0.5)),
                    ),
                  ),
                ),
                if (_conflitsAnalyzed) ...[
                  const SizedBox(height: 10),
                  if (_conflits.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: Colors.green.withValues(alpha: 0.3)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.check_circle,
                              color: Colors.green, size: 18),
                          SizedBox(width: 8),
                          Text('Aucun conflit détecté',
                              style: TextStyle(
                                  color: Colors.green, fontSize: 13)),
                        ],
                      ),
                    )
                  else
                    ..._conflits.map((c) => Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: Colors.orange.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline,
                                  color: Colors.orange, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(c,
                                    style: const TextStyle(
                                        color: Colors.orange, fontSize: 12)),
                              ),
                            ],
                          ),
                        )),
                  const SizedBox(height: 4),
                  const Text(
                    '// TODO: croiser avec emploi du temps Firestore pour détection précise',
                    style: TextStyle(color: Colors.white24, fontSize: 10),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ── Équilibrage de la charge ───────────────────────────────────────
          _SectionCard(
            title: 'Équilibrage de la charge',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                OutlinedButton.icon(
                  onPressed: _loadingCharge ? null : _loadCharge,
                  icon: _loadingCharge
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: _purple))
                      : const Icon(Icons.balance, size: 18, color: _purple),
                  label: const Text('Calculer l\'équilibre',
                      style: TextStyle(color: _purple)),
                  style: OutlinedButton.styleFrom(
                    side:
                        BorderSide(color: _purple.withValues(alpha: 0.5)),
                  ),
                ),
                if (_chargeLoaded) ...[
                  const SizedBox(height: 12),
                  _ChargeBar(myCharge: _myCharge, teamAvg: _teamAvg),
                  const SizedBox(height: 4),
                  const Text(
                    '// TODO: intégrer algorithme ML pour équilibrage automatique',
                    style: TextStyle(color: Colors.white24, fontSize: 10),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ── Alertes ───────────────────────────────────────────────────────
          _SectionCard(
            title: 'Alertes',
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('disponibilites')
                  .doc(widget.uid)
                  .collection('absences')
                  .snapshots(),
              builder: (context, absSnap) {
                return StreamBuilder<List<Remplacement>>(
                  stream: RemplacementService.remplacementsStream(),
                  builder: (context, replSnap) {
                    final now = DateTime.now();
                    final thirtyDaysAgo =
                        now.subtract(const Duration(days: 30));
                    final thirtyStr =
                        '${thirtyDaysAgo.year}-${thirtyDaysAgo.month.toString().padLeft(2, '0')}-${thirtyDaysAgo.day.toString().padLeft(2, '0')}';

                    final allRepl = replSnap.data ?? [];
                    final recentRepl = allRepl.where((r) =>
                        (r.professeurRemplacantUid == widget.uid ||
                            r.professeurAbsentUid == widget.uid) &&
                        r.date.compareTo(thirtyStr) >= 0).length;

                    final absDocs = absSnap.data?.docs ?? [];
                    final recentAbs = absDocs.where((d) {
                      final date = (d.data() as Map<String, dynamic>)['date'] as String? ?? '';
                      return date.compareTo(thirtyStr) >= 0;
                    }).length;

                    final alerts = <_IAAlert>[];
                    if (recentAbs > 5) {
                      alerts.add(_IAAlert(
                        icon: Icons.sick,
                        color: Colors.red,
                        title: 'Taux d\'absence élevé',
                        subtitle:
                            'Envisager un entretien ($recentAbs absences sur 30j)',
                      ));
                    }
                    if (recentRepl > 8) {
                      alerts.add(_IAAlert(
                        icon: Icons.swap_horiz,
                        color: Colors.orange,
                        title: 'Charge de remplacement élevée',
                        subtitle:
                            '$recentRepl remplacements sur les 30 derniers jours',
                      ));
                    }

                    return StreamBuilder<DisponibiliteEnseignant?>(
                      stream: RemplacementService.disponibiliteStream(widget.uid),
                      builder: (context, dispoSnap) {
                        final dispo = dispoSnap.data;
                        if (dispo != null &&
                            !dispo.disponibleAujourdhui) {
                          alerts.add(_IAAlert(
                            icon: Icons.person_off,
                            color: Colors.amber,
                            title: 'Absent aujourd\'hui',
                            subtitle:
                                'Aucune notification envoyée automatiquement',
                          ));
                        }

                        if (alerts.isEmpty) {
                          return const Row(
                            children: [
                              Icon(Icons.check_circle,
                                  color: Colors.green, size: 18),
                              SizedBox(width: 8),
                              Text('Aucune alerte active',
                                  style: TextStyle(
                                      color: Colors.green, fontSize: 13)),
                            ],
                          );
                        }

                        return Column(
                          children: [
                            ...alerts.map((a) => _IAAlertCard(alert: a)),
                            const SizedBox(height: 4),
                            const Text(
                              '// TODO: déclencher notification automatique via NotificationService',
                              style: TextStyle(
                                  color: Colors.white24, fontSize: 10),
                            ),
                          ],
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _analyserRemplacants() async {
    if (!mounted) return;
    setState(() {
      _loadingCandidats = true;
      _candidats = null;
    });
    try {
      final results = await RemplacementService.rechercherRemplacants(
        matiere: _matiere,
        jour: _jour,
        heureDebut: _heure,
        heureFin:
            '${(int.tryParse(_heure.split(':')[0]) ?? 8) + 1}:00',
      );
      // Exclure cet enseignant des candidats
      final filtered =
          results.where((d) => d.uid != widget.uid).toList();
      if (mounted) {
        setState(() {
          _candidats = filtered;
          _loadingCandidats = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingCandidats = false);
      }
    }
  }

  Future<void> _analyserConflits() async {
    if (!mounted) return;
    setState(() {
      _loadingConflits = true;
      _conflits = [];
      _conflitsAnalyzed = false;
    });
    try {
      final now = DateTime.now();
      final weekStart = now.subtract(Duration(days: now.weekday - 1));
      final weekEnd = weekStart.add(const Duration(days: 7));

      final weekStartStr =
          '${weekStart.year}-${weekStart.month.toString().padLeft(2, '0')}-${weekStart.day.toString().padLeft(2, '0')}';
      final weekEndStr =
          '${weekEnd.year}-${weekEnd.month.toString().padLeft(2, '0')}-${weekEnd.day.toString().padLeft(2, '0')}';

      // Récupérer les remplacements de la semaine pour cet enseignant
      final replSnap = await FirebaseFirestore.instance
          .collection('remplacements')
          .where('date', isGreaterThanOrEqualTo: weekStartStr)
          .where('date', isLessThan: weekEndStr)
          .get();

      final myRepl = replSnap.docs
          .map((d) => Remplacement.fromFirestore(d))
          .where((r) =>
              r.professeurRemplacantUid == widget.uid ||
              r.professeurAbsentUid == widget.uid)
          .toList();

      // Vérifier chevauchements
      final conflits = <String>[];
      for (int i = 0; i < myRepl.length; i++) {
        for (int j = i + 1; j < myRepl.length; j++) {
          final a = myRepl[i];
          final b = myRepl[j];
          if (a.date == b.date && _overlap(a, b)) {
            conflits.add(
                'Conflit : ${a.matiere} (${a.heureDebut}-${a.heureFin}) vs ${b.matiere} (${b.heureDebut}-${b.heureFin}) le ${a.date}');
          }
        }
      }

      if (mounted) {
        setState(() {
          _conflits = conflits;
          _loadingConflits = false;
          _conflitsAnalyzed = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadingConflits = false;
          _conflitsAnalyzed = true;
        });
      }
    }
  }

  bool _overlap(Remplacement a, Remplacement b) {
    final aStart = _toMin(a.heureDebut);
    final aEnd = _toMin(a.heureFin);
    final bStart = _toMin(b.heureDebut);
    final bEnd = _toMin(b.heureFin);
    return aStart < bEnd && bStart < aEnd;
  }

  int _toMin(String heure) {
    final parts = heure.split(':');
    if (parts.length < 2) return 0;
    return (int.tryParse(parts[0]) ?? 0) * 60 +
        (int.tryParse(parts[1]) ?? 0);
  }

  Future<void> _loadCharge() async {
    if (!mounted) return;
    setState(() {
      _loadingCharge = true;
      _chargeLoaded = false;
    });
    try {
      final now = DateTime.now();
      final monthStr =
          '${now.year}-${now.month.toString().padLeft(2, '0')}';

      final snap = await FirebaseFirestore.instance
          .collection('remplacements')
          .where('date', isGreaterThanOrEqualTo: '$monthStr-01')
          .where('date', isLessThan: '$monthStr-32')
          .get();

      final docs = snap.docs.map((d) => Remplacement.fromFirestore(d)).toList();

      // Compter par uid
      final countByUid = <String, int>{};
      for (final r in docs) {
        final uid = r.professeurRemplacantUid ?? '';
        if (uid.isNotEmpty) {
          countByUid[uid] = (countByUid[uid] ?? 0) + 1;
        }
      }

      final myCount = (countByUid[widget.uid] ?? 0).toDouble();
      final total = countByUid.values.fold(0, (a, b) => a + b);
      final avg = countByUid.isEmpty
          ? 0.0
          : total / countByUid.length.toDouble();

      if (mounted) {
        setState(() {
          _myCharge = myCount;
          _teamAvg = avg;
          _loadingCharge = false;
          _chargeLoaded = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadingCharge = false;
          _chargeLoaded = true;
        });
      }
    }
  }

  InputDecoration _inputDeco(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white54),
      filled: true,
      fillColor: _card2,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    );
  }
}

class _IAAlert {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  const _IAAlert(
      {required this.icon,
      required this.color,
      required this.title,
      required this.subtitle});
}

class _IAAlertCard extends StatelessWidget {
  final _IAAlert alert;
  const _IAAlertCard({required this.alert});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: alert.color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: alert.color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(alert.icon, color: alert.color, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(alert.title,
                    style: TextStyle(
                        color: alert.color,
                        fontWeight: FontWeight.bold,
                        fontSize: 13)),
                const SizedBox(height: 2),
                Text(alert.subtitle,
                    style: const TextStyle(
                        color: Colors.white54, fontSize: 12)),
              ],
            ),
          ),
          TextButton(
            onPressed: () {
              // TODO: action selon type d'alerte
            },
            child: Text('Agir',
                style:
                    TextStyle(color: alert.color, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

class _CandidatCard extends StatelessWidget {
  final DisponibiliteEnseignant dispo;
  final double score;
  const _CandidatCard({required this.dispo, required this.score});

  @override
  Widget build(BuildContext context) {
    final scoreColor = score >= 70 ? Colors.green : score >= 40 ? Colors.orange : Colors.red;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _card2,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(dispo.nom,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 13)),
              ),
              Text('Score: ${score.round()}%',
                  style: TextStyle(color: scoreColor, fontSize: 12, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: score / 100,
              backgroundColor: Colors.white12,
              valueColor: AlwaysStoppedAnimation<Color>(scoreColor),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              if (dispo.matieres.isNotEmpty)
                _SmallChip(label: dispo.matieres.first, color: _blue.withValues(alpha: 0.7)),
              if (dispo.disponibleAujourdhui)
                _SmallChip(label: 'Dispo aujourd\'hui', color: Colors.green.withValues(alpha: 0.7)),
            ],
          ),
        ],
      ),
    );
  }
}

class _ChargeBar extends StatelessWidget {
  final double myCharge;
  final double teamAvg;
  const _ChargeBar({required this.myCharge, required this.teamAvg});

  @override
  Widget build(BuildContext context) {
    final maxVal = (myCharge > teamAvg * 1.5 ? myCharge : teamAvg * 1.5)
        .clamp(1.0, double.infinity);
    final myRatio = (myCharge / maxVal).clamp(0.0, 1.0);
    final avgRatio = (teamAvg / maxVal).clamp(0.0, 1.0);

    Color barColor;
    if (myCharge > teamAvg * 1.5) {
      barColor = Colors.red;
    } else if (myCharge > teamAvg * 0.9) {
      barColor = Colors.orange;
    } else {
      barColor = Colors.green;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Ma charge : ${myCharge.round()} remplacements',
            style: const TextStyle(color: Colors.white70, fontSize: 12)),
        const SizedBox(height: 6),
        ShaderMask(
          shaderCallback: (bounds) => LinearGradient(
            colors: [barColor.withValues(alpha: 0.6), barColor],
          ).createShader(bounds),
          child: LinearProgressIndicator(
            value: myRatio,
            backgroundColor: Colors.white12,
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            minHeight: 10,
          ),
        ),
        const SizedBox(height: 8),
        Text('Moyenne équipe : ${teamAvg.toStringAsFixed(1)} remplacements',
            style: const TextStyle(color: Colors.white54, fontSize: 12)),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: avgRatio,
          backgroundColor: Colors.white12,
          valueColor: const AlwaysStoppedAnimation<Color>(Colors.white38),
          minHeight: 6,
        ),
      ],
    );
  }
}

// ─── Dialogs ──────────────────────────────────────────────────────────────────

class _EditProfilDialog extends StatefulWidget {
  final EnseignantProfil profil;
  const _EditProfilDialog({required this.profil});

  @override
  State<_EditProfilDialog> createState() => _EditProfilDialogState();
}

class _EditProfilDialogState extends State<_EditProfilDialog> {
  late final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nomCtrl;
  late final TextEditingController _prenomCtrl;
  late final TextEditingController _telephoneCtrl;
  late final TextEditingController _adresseCtrl;
  late final TextEditingController _nationaliteCtrl;
  late final TextEditingController _dateNaissanceCtrl;
  late final TextEditingController _dateEmbaucheCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _matriculeCtrl;

  String? _sexe;
  String? _typeContrat;
  String _statut = 'Actif';
  bool _tempsPlein = true;

  List<String> _matieres = [];
  List<String> _cycles = [];
  List<String> _niveaux = [];

  bool _saving = false;

  static const _allMatieres = [
    'Mathématiques', 'Français', 'Histoire-Géographie', 'Sciences',
    'Physique-Chimie', 'SVT', 'Anglais', 'Espagnol', 'Arabe',
    'Philosophie', 'Économie', 'Informatique', 'EPS', 'Arts plastiques',
    'Musique',
  ];
  static const _allCycles = [
    'Maternelle', 'Primaire', 'Collège', 'Lycée', 'Université'
  ];
  static const _allNiveaux = [
    'PS', 'MS', 'GS', 'CP', 'CE1', 'CE2', 'CM1', 'CM2',
    '6ème', '5ème', '4ème', '3ème', 'Seconde', 'Première', 'Terminale',
    'L1', 'L2', 'L3', 'M1', 'M2',
  ];

  @override
  void initState() {
    super.initState();
    final p = widget.profil;
    _nomCtrl = TextEditingController(text: p.nom);
    _prenomCtrl = TextEditingController(text: p.prenom);
    _telephoneCtrl = TextEditingController(text: p.telephone ?? '');
    _adresseCtrl = TextEditingController(text: p.adresse ?? '');
    _nationaliteCtrl = TextEditingController(text: p.nationalite ?? '');
    _dateNaissanceCtrl =
        TextEditingController(text: p.dateNaissance ?? '');
    _dateEmbaucheCtrl =
        TextEditingController(text: p.dateEmbauche ?? '');
    _emailCtrl = TextEditingController(text: p.email ?? '');
    _matriculeCtrl = TextEditingController(text: p.matricule ?? '');
    _sexe = p.sexe;
    _typeContrat = p.typeContrat;
    _statut = p.statut;
    _tempsPlein = p.tempsPlein;
    _matieres = List<String>.from(p.matieres);
    _cycles = List<String>.from(p.cycles);
    _niveaux = List<String>.from(p.niveaux);
  }

  @override
  void dispose() {
    _nomCtrl.dispose();
    _prenomCtrl.dispose();
    _telephoneCtrl.dispose();
    _adresseCtrl.dispose();
    _nationaliteCtrl.dispose();
    _dateNaissanceCtrl.dispose();
    _dateEmbaucheCtrl.dispose();
    _emailCtrl.dispose();
    _matriculeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: _card,
      title: const Text('Modifier le profil',
          style: TextStyle(color: Colors.white, fontSize: 16)),
      content: SizedBox(
        width: double.maxFinite,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _field(_nomCtrl, 'Nom'),
                const SizedBox(height: 8),
                _field(_prenomCtrl, 'Prénom'),
                const SizedBox(height: 8),
                _dropdown<String>(
                  label: 'Sexe',
                  value: _sexe,
                  items: const ['M', 'F', 'Autre'],
                  onChanged: (v) => setState(() => _sexe = v),
                ),
                const SizedBox(height: 8),
                _field(_dateNaissanceCtrl, 'Date de naissance (AAAA-MM-JJ)'),
                const SizedBox(height: 8),
                _field(_nationaliteCtrl, 'Nationalité'),
                const SizedBox(height: 8),
                _field(_telephoneCtrl, 'Téléphone'),
                const SizedBox(height: 8),
                _field(_emailCtrl, 'Email'),
                const SizedBox(height: 8),
                _field(_adresseCtrl, 'Adresse'),
                const SizedBox(height: 8),
                _field(_matriculeCtrl, 'Matricule'),
                const SizedBox(height: 8),
                _field(_dateEmbaucheCtrl, "Date d'embauche (AAAA-MM-JJ)"),
                const SizedBox(height: 8),
                _dropdown<String>(
                  label: 'Type de contrat',
                  value: _typeContrat,
                  items: const ['CDI', 'CDD', 'Vacataire', 'Titulaire'],
                  onChanged: (v) => setState(() => _typeContrat = v),
                ),
                const SizedBox(height: 8),
                _dropdown<String>(
                  label: 'Statut',
                  value: _statut,
                  items: const ['Actif', 'En congé', 'Absent'],
                  onChanged: (v) {
                    if (v != null) {
                      setState(() => _statut = v);
                    }
                  },
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  title: const Text('Temps plein',
                      style: TextStyle(color: Colors.white70, fontSize: 13)),
                  value: _tempsPlein,
                  activeColor: _purple,
                  tileColor: _card2,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  onChanged: (v) => setState(() => _tempsPlein = v),
                ),
                const SizedBox(height: 10),
                _MultiSelectChips(
                  label: 'Matières',
                  all: _allMatieres,
                  selected: _matieres,
                  color: _blue,
                  onChanged: (v) => setState(() => _matieres = v),
                ),
                const SizedBox(height: 10),
                _MultiSelectChips(
                  label: 'Cycles',
                  all: _allCycles,
                  selected: _cycles,
                  color: _purple,
                  onChanged: (v) => setState(() => _cycles = v),
                ),
                const SizedBox(height: 10),
                _MultiSelectChips(
                  label: 'Niveaux',
                  all: _allNiveaux,
                  selected: _niveaux,
                  color: Colors.teal,
                  onChanged: (v) => setState(() => _niveaux = v),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler',
              style: TextStyle(color: Colors.white38)),
        ),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          style: ElevatedButton.styleFrom(
              backgroundColor: _purple,
              foregroundColor: Colors.white),
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Text('Enregistrer'),
        ),
      ],
    );
  }

  Widget _field(TextEditingController ctrl, String label) {
    return TextFormField(
      controller: ctrl,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white54),
        filled: true,
        fillColor: _card2,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
    );
  }

  Widget _dropdown<T>({
    required String label,
    required T? value,
    required List<T> items,
    required void Function(T?) onChanged,
  }) {
    return DropdownButtonFormField<T>(
      value: value,
      dropdownColor: _card2,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white54),
        filled: true,
        fillColor: _card2,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      items: items
          .map((item) => DropdownMenuItem<T>(
                value: item,
                child: Text(item.toString(),
                    style: const TextStyle(color: Colors.white)),
              ))
          .toList(),
      onChanged: onChanged,
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final updated = widget.profil.copyWith(
      nom: _nomCtrl.text.trim(),
      prenom: _prenomCtrl.text.trim(),
      sexe: _sexe,
      dateNaissance: _dateNaissanceCtrl.text.trim().isNotEmpty
          ? _dateNaissanceCtrl.text.trim()
          : null,
      adresse: _adresseCtrl.text.trim().isNotEmpty
          ? _adresseCtrl.text.trim()
          : null,
      telephone: _telephoneCtrl.text.trim().isNotEmpty
          ? _telephoneCtrl.text.trim()
          : null,
      email: _emailCtrl.text.trim().isNotEmpty
          ? _emailCtrl.text.trim()
          : null,
      nationalite: _nationaliteCtrl.text.trim().isNotEmpty
          ? _nationaliteCtrl.text.trim()
          : null,
      matricule: _matriculeCtrl.text.trim().isNotEmpty
          ? _matriculeCtrl.text.trim()
          : null,
      dateEmbauche: _dateEmbaucheCtrl.text.trim().isNotEmpty
          ? _dateEmbaucheCtrl.text.trim()
          : null,
      typeContrat: _typeContrat,
      tempsPlein: _tempsPlein,
      statut: _statut,
      matieres: _matieres,
      cycles: _cycles,
      niveaux: _niveaux,
    );

    await FirebaseFirestore.instance
        .collection('enseignants_profils')
        .doc(updated.uid)
        .set(updated.toMap(), SetOptions(merge: true));

    if (mounted) {
      setState(() => _saving = false);
      Navigator.pop(context);
    }
  }
}

class _AddCreneauDialog extends StatefulWidget {
  const _AddCreneauDialog();

  @override
  State<_AddCreneauDialog> createState() => _AddCreneauDialogState();
}

class _AddCreneauDialogState extends State<_AddCreneauDialog> {
  String _jour = 'Lundi';
  TimeOfDay _debut = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _fin = const TimeOfDay(hour: 10, minute: 0);

  static const _jours = [
    'Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi'
  ];

  String _fmt(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: _card,
      title: const Text('Nouveau créneau',
          style: TextStyle(color: Colors.white)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<String>(
            value: _jour,
            dropdownColor: _card2,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Jour',
              labelStyle: const TextStyle(color: Colors.white54),
              filled: true,
              fillColor: _card2,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none),
            ),
            items: _jours
                .map((j) => DropdownMenuItem(
                    value: j,
                    child: Text(j,
                        style: const TextStyle(color: Colors.white))))
                .toList(),
            onChanged: (v) {
              if (v != null) {
                setState(() => _jour = v);
              }
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () async {
                    final picked = await showTimePicker(
                        context: context, initialTime: _debut);
                    if (picked != null) {
                      setState(() => _debut = picked);
                    }
                  },
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Début',
                      labelStyle: const TextStyle(color: Colors.white54),
                      filled: true,
                      fillColor: _card2,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none),
                    ),
                    child: Text(_fmt(_debut),
                        style: const TextStyle(color: Colors.white)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: InkWell(
                  onTap: () async {
                    final picked = await showTimePicker(
                        context: context, initialTime: _fin);
                    if (picked != null) {
                      setState(() => _fin = picked);
                    }
                  },
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Fin',
                      labelStyle: const TextStyle(color: Colors.white54),
                      filled: true,
                      fillColor: _card2,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none),
                    ),
                    child: Text(_fmt(_fin),
                        style: const TextStyle(color: Colors.white)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler',
              style: TextStyle(color: Colors.white38)),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(
            context,
            CreneauHoraire(
              jour: _jour,
              heureDebut: _fmt(_debut),
              heureFin: _fmt(_fin),
            ),
          ),
          style: ElevatedButton.styleFrom(
              backgroundColor: _purple, foregroundColor: Colors.white),
          child: const Text('Ajouter'),
        ),
      ],
    );
  }
}

class _DeclareAbsenceDialog extends StatefulWidget {
  final String uid;
  const _DeclareAbsenceDialog({required this.uid});

  @override
  State<_DeclareAbsenceDialog> createState() => _DeclareAbsenceDialogState();
}

class _DeclareAbsenceDialogState extends State<_DeclareAbsenceDialog> {
  final _dateCtrl = TextEditingController();
  final _commentaireCtrl = TextEditingController();
  String _motif = 'maladie';
  bool _saving = false;

  static const _motifs = [
    'maladie', 'formation', 'conge', 'autre'
  ];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _dateCtrl.text =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _dateCtrl.dispose();
    _commentaireCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: _card,
      title: const Text('Déclarer une absence',
          style: TextStyle(color: Colors.white)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextFormField(
            controller: _dateCtrl,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Date (AAAA-MM-JJ)',
              labelStyle: const TextStyle(color: Colors.white54),
              filled: true,
              fillColor: _card2,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: _motif,
            dropdownColor: _card2,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Motif',
              labelStyle: const TextStyle(color: Colors.white54),
              filled: true,
              fillColor: _card2,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none),
            ),
            items: _motifs
                .map((m) => DropdownMenuItem(
                    value: m,
                    child: Text(_motifLabel(m),
                        style: const TextStyle(color: Colors.white))))
                .toList(),
            onChanged: (v) {
              if (v != null) {
                setState(() => _motif = v);
              }
            },
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _commentaireCtrl,
            style: const TextStyle(color: Colors.white),
            maxLines: 2,
            decoration: InputDecoration(
              labelText: 'Commentaire (optionnel)',
              labelStyle: const TextStyle(color: Colors.white54),
              filled: true,
              fillColor: _card2,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler',
              style: TextStyle(color: Colors.white38)),
        ),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          style: ElevatedButton.styleFrom(
              backgroundColor: _purple, foregroundColor: Colors.white),
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Text('Déclarer'),
        ),
      ],
    );
  }

  String _motifLabel(String m) {
    switch (m) {
      case 'maladie':
        return 'Maladie';
      case 'formation':
        return 'Formation';
      case 'conge':
        return 'Congé';
      default:
        return 'Autre';
    }
  }

  Future<void> _save() async {
    if (_dateCtrl.text.isEmpty) return;
    setState(() => _saving = true);
    await RemplacementService.declareAbsence(
      uid: widget.uid,
      nom: '',
      date: _dateCtrl.text.trim(),
      motif: _motif,
      commentaire: _commentaireCtrl.text.trim().isNotEmpty
          ? _commentaireCtrl.text.trim()
          : null,
    );
    if (mounted) {
      setState(() => _saving = false);
      Navigator.pop(context);
    }
  }
}

// ─── Shared Widgets ───────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              color: Colors.white38,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _InfoField extends StatelessWidget {
  final String label;
  final String value;
  final bool expanded;
  const _InfoField(
      {required this.label, required this.value, this.expanded = false});

  @override
  Widget build(BuildContext context) {
    final content = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: _card2,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(color: Colors.white38, fontSize: 10)),
          const SizedBox(height: 2),
          Text(value,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
              maxLines: 2,
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
    return expanded ? SizedBox(width: double.infinity, child: content) : Expanded(child: content);
  }
}

class _ChipListField extends StatelessWidget {
  final String label;
  final List<String> items;
  final Color color;
  const _ChipListField(
      {required this.label, required this.items, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(color: Colors.white38, fontSize: 11)),
        const SizedBox(height: 6),
        items.isEmpty
            ? const Text('—',
                style: TextStyle(color: Colors.white38, fontSize: 12))
            : Wrap(
                spacing: 6,
                runSpacing: 6,
                children: items
                    .map((item) => Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: color.withValues(alpha: 0.3)),
                          ),
                          child: Text(item,
                              style: TextStyle(
                                  color: color,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600)),
                        ))
                    .toList(),
              ),
      ],
    );
  }
}

class _StatutBadgeField extends StatelessWidget {
  final String statut;
  const _StatutBadgeField({required this.statut});

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (statut) {
      case 'En congé':
        color = Colors.amber;
        break;
      case 'Absent':
        color = Colors.red;
        break;
      default:
        color = Colors.green;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: _card2,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
                color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(statut,
              style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _SmallChip extends StatelessWidget {
  final String label;
  final Color color;
  const _SmallChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(label,
          style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w500)),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label,
            style: const TextStyle(color: Colors.white38, fontSize: 11)),
      ],
    );
  }
}

class _MultiSelectChips extends StatelessWidget {
  final String label;
  final List<String> all;
  final List<String> selected;
  final Color color;
  final void Function(List<String>) onChanged;

  const _MultiSelectChips({
    required this.label,
    required this.all,
    required this.selected,
    required this.color,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(color: Colors.white54, fontSize: 12)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: all.map((item) {
            final sel = selected.contains(item);
            return GestureDetector(
              onTap: () {
                final newList = List<String>.from(selected);
                if (sel) {
                  newList.remove(item);
                } else {
                  newList.add(item);
                }
                onChanged(newList);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: sel
                      ? color.withValues(alpha: 0.25)
                      : _card2,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: sel
                        ? color.withValues(alpha: 0.6)
                        : Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: Text(item,
                    style: TextStyle(
                        color: sel ? color : Colors.white54,
                        fontSize: 11,
                        fontWeight:
                            sel ? FontWeight.w600 : FontWeight.normal)),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
