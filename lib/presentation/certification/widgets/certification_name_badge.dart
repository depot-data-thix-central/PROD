// lib/presentation/certification/widgets/certification_name_badge.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:thix_id/models/certification_tier.dart';
import 'package:thix_id/presentation/certification/providers/certification_provider.dart';
import 'package:thix_id/services/certification_service.dart';

/// Sceau certification (icône seule par défaut, ou avec le nom du niveau).
class CertificationNameBadge extends ConsumerWidget {
  final double iconSize;
  final EdgeInsetsGeometry padding;
  final CertificationTier? tier;
  final CertificationStatus? status;
  final bool showLabel; // ✅ Ajout du paramètre

  const CertificationNameBadge({
    super.key,
    this.iconSize = 15,
    this.padding = const EdgeInsets.only(left: 4),
    this.tier,
    this.status,
    this.showLabel = false, // ✅ Par défaut sur 'false' (sceau seul)
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (tier != null) {
      return Padding(
        padding: padding,
        child: _buildContent(
          tier: tier!,
          status: status ?? CertificationStatus.approved,
        ),
      );
    }

    final async = ref.watch(myCertificationProvider);
    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (info) {
        if (!info.isCertified && info.status != CertificationStatus.pending) {
          return const SizedBox.shrink();
        }
        return Padding(
          padding: padding,
          child: _buildContent(
            tier: info.tier,
            status: info.status,
          ),
        );
      },
    );
  }

  /// Construit le contenu final (sceau seul, ou sceau + texte)
  Widget _buildContent({
    required CertificationTier tier,
    required CertificationStatus status,
  }) {
    final seal = _CertSeal(
      tier: tier,
      status: status,
      size: iconSize,
    );

    if (!showLabel) return seal;

    // Si on veut afficher le label en plus du sceau
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        seal,
        const SizedBox(width: 4),
        Text(
          tier.shortLabel,
          style: TextStyle(
            color: tier.badgeColor,
            fontSize: iconSize * 0.85,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

/// Sceau seul — contour dentelé + check blanc, plat et net (pas de glow).
class _CertSeal extends StatelessWidget {
  final CertificationTier tier;
  final CertificationStatus status;
  final double size;

  const _CertSeal({
    required this.tier,
    required this.status,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final color = tier.badgeColor;
    final pending = status == CertificationStatus.pending;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Contour dentelé exact (scallop / médaille) — sans glow autour
          CustomPaint(
            size: Size(size, size),
            painter: _ScallopedSealPainter(color: color),
          ),
          // Check / sablier blanc
          Icon(
            pending ? Icons.hourglass_top_rounded : Icons.check_rounded,
            color: Colors.white,
            size: size * 0.52,
          ),
        ],
      ),
    );
  }
}

/// Dessine le contour dentelé (forme exacte du sceau de certification),
/// remplissage plat (une seule teinte, léger dégradé interne discret),
/// sans ombre ni halo autour — rendu net comme les badges Facebook/X.
class _ScallopedSealPainter extends CustomPainter {
  final Color color;
  final int notches;
  final double amplitude;

  _ScallopedSealPainter({
    required this.color,
    this.notches = 18,
    this.amplitude = 0.09,
  });

  Path _scallopPath(Offset center, double radius) {
    final path = Path();
    const steps = 240;
    for (int i = 0; i <= steps; i++) {
      final theta = (i / steps) * 2 * math.pi;
      final r = radius *
          (1 - amplitude / 2 + (amplitude / 2) * math.cos(notches * theta));
      final x = center.dx + r * math.cos(theta - math.pi / 2);
      final y = center.dy + r * math.sin(theta - math.pi / 2);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final path = _scallopPath(center, radius);

    // Remplissage plat avec très léger dégradé interne (relief discret,
    // sans ombre portée ni halo extérieur)
    final fillPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          Color.lerp(color, Colors.white, 0.08)!,
          color,
        ],
        stops: const [0.0, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawPath(path, fillPaint);

    // Fin liseré blanc translucide (bord net, pas de contraste fort)
    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.06
      ..color = Colors.white.withOpacity(0.25);
    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _ScallopedSealPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.notches != notches ||
        oldDelegate.amplitude != amplitude;
  }
}
