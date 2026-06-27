import 'package:flutter/material.dart';
import '../models/inscription_model.dart';

class InscriptionCard extends StatelessWidget {
  final Inscription inscription;
  final VoidCallback? onTap;
  final Widget? trailing;

  const InscriptionCard({
    super.key,
    required this.inscription,
    this.onTap,
    this.trailing,
  });

  Color get _statutColor {
    switch (inscription.statut) {
      case InscriptionStatut.brouillon:
        return const Color(0xFFD97706);
      case InscriptionStatut.enAttente:
        return const Color(0xFF6C47FF);
      case InscriptionStatut.validee:
        return const Color(0xFF16A34A);
      case InscriptionStatut.refusee:
        return const Color(0xFFDC2626);
    }
  }

  @override
  Widget build(BuildContext context) {
    final eleve = inscription.eleve;
    final initiale =
        eleve.prenom.isNotEmpty ? eleve.prenom[0].toUpperCase() : '?';
    final sousTitre = [
      if (inscription.matricule.isNotEmpty) inscription.matricule,
      if (eleve.classeDemandee.isNotEmpty) eleve.classeDemandee,
    ].join(' · ');

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF161B22),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6C47FF), Color(0xFF2563EB)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    initiale,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 17),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        inscription.nomCompletEleve.isEmpty
                            ? 'Élève sans nom'
                            : inscription.nomCompletEleve,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 14),
                      ),
                      if (sousTitre.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          sousTitre,
                          style: const TextStyle(
                              color: Colors.white38, fontSize: 12),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _StatusBadge(label: inscription.statut.label, color: _statutColor),
              ],
            ),
            if (trailing != null) ...[
              const SizedBox(height: 12),
              trailing!,
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}
