import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/bulletin_validation_model.dart';
import '../models/classe_model.dart';
import '../services/bulletin_validation_service.dart';
import '../services/user_service.dart';

// ─── Palette ──────────────────────────────────────────────────────────────────

const _kBg     = Color(0xFF0D1117);
const _kCard   = Color(0xFF161B22);
const _kCard2  = Color(0xFF1F2937);
const _kBlue   = Color(0xFF2563EB);
const _kGreen  = Color(0xFF16A34A);
const _kOrange = Color(0xFFD97706);
const _kRed    = Color(0xFFDC2626);

// ─── Entry point ──────────────────────────────────────────────────────────────

/// Page Direction : publication des bulletins par classe et par trimestre.
///
/// La Direction marque chaque combinaison classe/trimestre comme « publiée ».
/// Élèves et parents voient alors un badge « Validé » dans leur bulletin.
/// Les données elles-mêmes (notes, appréciations) sont la source unique partagée.
class DirectionBulletinsPage extends StatefulWidget {
  const DirectionBulletinsPage({super.key});

  @override
  State<DirectionBulletinsPage> createState() =>
      _DirectionBulletinsPageState();
}

class _DirectionBulletinsPageState
    extends State<DirectionBulletinsPage> {
  final int _anneeScol = DateTime.now().year;
  String _dirNom = '';

  @override
  void initState() {
    super.initState();
    UserService.currentUserStream().first.then((u) {
      if (mounted && u != null) {
        setState(() => _dirNom = u.displayName);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kCard,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Publication des bulletins',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold)),
            Text('Année $_anneeScol',
                style: const TextStyle(
                    color: Colors.white38, fontSize: 11)),
          ],
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('classes')
            .orderBy('nom')
            .snapshots(),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: _kBlue));
          }
          if (snap.hasError) {
            return const Center(
              child: Text('Erreur de chargement des classes',
                  style: TextStyle(color: Colors.white38)),
            );
          }
          final classes = snap.data?.docs
                  .map((d) => ClasseModel.fromFirestore(d))
                  .toList() ??
              [];
          if (classes.isEmpty) {
            return const Center(
              child: Text('Aucune classe',
                  style: TextStyle(color: Colors.white38)),
            );
          }
          return StreamBuilder<List<BulletinValidationModel>>(
            stream: BulletinValidationService.streamAll(_anneeScol),
            builder: (ctx2, valSnap) {
              if (valSnap.hasError) {
                return const Center(
                  child: Text('Erreur de chargement des validations',
                      style: TextStyle(color: Colors.white38)),
                );
              }
              final validations = valSnap.data ?? [];
              final valMap = {
                for (final v in validations) v.id: v
              };
              return ListView.builder(
                padding:
                    const EdgeInsets.fromLTRB(12, 12, 12, 40),
                itemCount: classes.length,
                itemBuilder: (ctx3, i) => _ClasseCard(
                  classe: classes[i],
                  anneeScol: _anneeScol,
                  validations: valMap,
                  dirNom: _dirNom,
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// ─── Carte par classe ─────────────────────────────────────────────────────────

class _ClasseCard extends StatelessWidget {
  final ClasseModel classe;
  final int anneeScol;
  final Map<String, BulletinValidationModel?> validations;
  final String dirNom;

  const _ClasseCard({
    required this.classe,
    required this.anneeScol,
    required this.validations,
    required this.dirNom,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header classe
          Container(
            padding:
                const EdgeInsets.fromLTRB(14, 12, 14, 10),
            decoration: BoxDecoration(
              color: _kBlue.withValues(alpha: 0.08),
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(14)),
            ),
            child: Row(children: [
              const Icon(Icons.class_outlined,
                  color: _kBlue, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(classe.nom,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14)),
              ),
              if (classe.niveau.isNotEmpty)
                Text(classe.niveau,
                    style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 11)),
            ]),
          ),
          // Lignes trimestres
          ...List.generate(3, (i) {
            final t = i + 1;
            final id = BulletinValidationModel.docId(
                classeId: classe.id,
                trimestre: t,
                anneeScol: anneeScol);
            final val = validations[id];
            return _TrimestreRow(
              classe: classe,
              trimestre: t,
              anneeScol: anneeScol,
              validation: val,
              dirNom: dirNom,
            );
          }),
          const SizedBox(height: 2),
        ],
      ),
    );
  }
}

// ─── Ligne par trimestre ──────────────────────────────────────────────────────

class _TrimestreRow extends StatefulWidget {
  final ClasseModel classe;
  final int trimestre;
  final int anneeScol;
  final BulletinValidationModel? validation;
  final String dirNom;

  const _TrimestreRow({
    required this.classe,
    required this.trimestre,
    required this.anneeScol,
    required this.validation,
    required this.dirNom,
  });

  @override
  State<_TrimestreRow> createState() => _TrimestreRowState();
}

class _TrimestreRowState extends State<_TrimestreRow> {
  bool _loading = false;

  Future<void> _toggle() async {
    final current = widget.validation?.publie ?? false;
    setState(() => _loading = true);
    try {
      await BulletinValidationService.publish(
        classeId: widget.classe.id,
        classeNom: widget.classe.nom,
        trimestre: widget.trimestre,
        anneeScol: widget.anneeScol,
        publie: !current,
        directionNom: widget.dirNom,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
            !current
                ? 'Bulletin T${widget.trimestre} — ${widget.classe.nom} publié'
                : 'Bulletin T${widget.trimestre} — ${widget.classe.nom} dépublié',
          ),
          backgroundColor: !current ? _kGreen : _kOrange,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 2),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erreur : $e'),
          backgroundColor: _kRed,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
        ));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final publie = widget.validation?.publie ?? false;
    final datePub = widget.validation?.datePub;
    final dateStr = datePub != null
        ? DateFormat('dd/MM/yyyy').format(datePub.toDate())
        : null;

    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
              color: Colors.white.withValues(alpha: 0.04)),
        ),
      ),
      child: Row(children: [
        // Trimestre badge
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: publie
                ? _kGreen.withValues(alpha: 0.12)
                : _kCard2,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text('T${widget.trimestre}',
                style: TextStyle(
                    color: publie ? _kGreen : Colors.white38,
                    fontWeight: FontWeight.bold,
                    fontSize: 13)),
          ),
        ),
        const SizedBox(width: 12),
        // Statut
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(
                  publie
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                  color: publie ? _kGreen : Colors.white24,
                  size: 14,
                ),
                const SizedBox(width: 5),
                Text(
                  publie ? 'Publié' : 'Non publié',
                  style: TextStyle(
                      color:
                          publie ? _kGreen : Colors.white38,
                      fontWeight: FontWeight.w600,
                      fontSize: 12),
                ),
              ]),
              if (publie && dateStr != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    'Le $dateStr${widget.validation?.directionNom?.isNotEmpty == true ? ' par ${widget.validation!.directionNom}' : ''}',
                    style: const TextStyle(
                        color: Colors.white24,
                        fontSize: 10),
                  ),
                ),
            ],
          ),
        ),
        // Toggle button
        GestureDetector(
          onTap: _loading ? null : _toggle,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: publie
                  ? _kRed.withValues(alpha: 0.12)
                  : _kGreen.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: publie
                    ? _kRed.withValues(alpha: 0.3)
                    : _kGreen.withValues(alpha: 0.3),
              ),
            ),
            child: _loading
                ? SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      color: publie ? _kRed : _kGreen,
                      strokeWidth: 2,
                    ))
                : Text(
                    publie ? 'Dépublier' : 'Publier',
                    style: TextStyle(
                        color: publie ? _kRed : _kGreen,
                        fontWeight: FontWeight.w700,
                        fontSize: 12),
                  ),
          ),
        ),
      ]),
    );
  }
}
