import 'package:flutter/material.dart';

/// Page d'attente pour les modules en cours de développement.
///
/// Utilisée dans les routes cycle-spécifiques qui n'ont pas encore d'écran
/// de production. Remplacée progressivement, route par route, au Lot 4+.
///
/// Contrairement à [ComingSoonPage] (orientée jeux), cette page est conçue
/// pour les modules pédagogiques : bulletin, brevet, UE, stage, etc.
class CyclePlaceholderPage extends StatelessWidget {
  final String title;
  final String subtitle;
  final String cycleId; // 'maternelle'|'primaire'|'college'|'lycee'|'universite'|'professeur'|'direction'
  final IconData? icon;
  final List<String> features;

  const CyclePlaceholderPage({
    super.key,
    required this.title,
    required this.subtitle,
    required this.cycleId,
    this.icon,
    this.features = const [],
  });

  // ── Couleurs et icônes par cycle ────────────────────────────────────────────

  List<Color> get _colors {
    switch (cycleId) {
      case 'maternelle':
        return [const Color(0xFFBE185D), const Color(0xFF7C3AED)];
      case 'primaire':
        return [const Color(0xFF6C47FF), const Color(0xFF2563EB)];
      case 'college':
        return [const Color(0xFF0F766E), const Color(0xFF0891B2)];
      case 'lycee':
        return [const Color(0xFF1E3A5F), const Color(0xFFDC2626)];
      case 'universite':
        return [const Color(0xFF1E3A5F), const Color(0xFF2563EB)];
      case 'professeur':
        return [const Color(0xFF0F766E), const Color(0xFF15803D)];
      case 'direction':
        return [const Color(0xFF6C47FF), const Color(0xFF2563EB)];
      default:
        return [const Color(0xFF374151), const Color(0xFF1F2937)];
    }
  }

  String get _cycleLabel {
    switch (cycleId) {
      case 'maternelle':
        return 'Maternelle';
      case 'primaire':
        return 'Primaire';
      case 'college':
        return 'Moyen';
      case 'lycee':
        return 'Secondaire';
      case 'universite':
        return 'Université';
      case 'professeur':
        return 'Professeur';
      case 'direction':
        return 'Direction';
      default:
        return '';
    }
  }

  IconData get _defaultIcon {
    switch (cycleId) {
      case 'maternelle':
        return Icons.child_care;
      case 'primaire':
        return Icons.menu_book_outlined;
      case 'college':
        return Icons.school_outlined;
      case 'lycee':
        return Icons.calculate_outlined;
      case 'universite':
        return Icons.account_balance_outlined;
      case 'professeur':
        return Icons.school;
      case 'direction':
        return Icons.account_balance;
      default:
        return Icons.construction_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = _colors;
    final primary = colors[0];
    final secondary = colors[1];

    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              color: Colors.white70, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          title,
          style: const TextStyle(
              color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 32, 24, 48),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // ── Icône principale ──────────────────────────────────────────────
            _GradientIconBox(
              icon: icon ?? _defaultIcon,
              colors: colors,
            ),

            const SizedBox(height: 28),

            // ── Badge cycle ───────────────────────────────────────────────────
            if (_cycleLabel.isNotEmpty)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border:
                      Border.all(color: primary.withValues(alpha: 0.35)),
                ),
                child: Text(
                  _cycleLabel.toUpperCase(),
                  style: TextStyle(
                      color: primary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2),
                ),
              ),

            const SizedBox(height: 16),

            // ── Titre ─────────────────────────────────────────────────────────
            Text(
              title,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 10),

            // ── Sous-titre ────────────────────────────────────────────────────
            Text(
              subtitle,
              style: const TextStyle(color: Colors.white54, fontSize: 14),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 28),

            // ── Badge "Module en préparation" ─────────────────────────────────
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF161B22),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                    color: secondary.withValues(alpha: 0.4)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.build_circle_outlined,
                      color: secondary, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'Module en préparation',
                    style: TextStyle(
                        color: secondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),

            // ── Fonctionnalités prévues ───────────────────────────────────────
            if (features.isNotEmpty) ...[
              const SizedBox(height: 32),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Fonctionnalités prévues'.toUpperCase(),
                  style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2),
                ),
              ),
              const SizedBox(height: 12),
              ...features.map((f) => _FeatureRow(
                    label: f,
                    color: primary,
                  )),
            ],

            const SizedBox(height: 40),

            // ── Barre de progression ──────────────────────────────────────────
            _ProgressSection(colors: colors),

            const SizedBox(height: 32),

            // ── Bouton retour ─────────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: BorderSide(color: primary.withValues(alpha: 0.7)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Retour',
                  style: TextStyle(
                      color: primary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Sous-widgets ────────────────────────────────────────────────────────────────

class _GradientIconBox extends StatefulWidget {
  final IconData icon;
  final List<Color> colors;
  const _GradientIconBox({required this.icon, required this.colors});

  @override
  State<_GradientIconBox> createState() => _GradientIconBoxState();
}

class _GradientIconBoxState extends State<_GradientIconBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _float;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _float =
        Tween<double>(begin: -8, end: 8).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Transform.translate(
        offset: Offset(0, _float.value),
        child: Container(
          width: 110,
          height: 110,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: widget.colors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: widget.colors[0].withValues(alpha: 0.4),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Icon(widget.icon, color: Colors.white, size: 52),
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final String label;
  final Color color;
  const _FeatureRow({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label,
                style: const TextStyle(color: Colors.white70, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

class _ProgressSection extends StatelessWidget {
  final List<Color> colors;
  const _ProgressSection({required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Avancement',
                  style: TextStyle(color: Colors.white54, fontSize: 12)),
              Text('Architecture',
                  style: TextStyle(
                      color: colors[0],
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: 0.35,
              backgroundColor: Colors.white12,
              valueColor: AlwaysStoppedAnimation<Color>(colors[0]),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Architecture validée · Écran en cours de développement',
            style: TextStyle(color: Colors.white30, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
