// ════════════════════════════════════════════════════════════════════════════
//  THIX PORTFOLIO BUSINESS — WIDGET : COVER PARALLAX
//  Fichier  : lib/presentation/thix_portfolio/widgets/parallax_cover.dart
//  Module   : THIX Portfolio Business
//  Éditeur  : SONATHIX GROUP — Kinshasa, RDC
//  Version  : 1.0.0 — Novembre 2026
// ════════════════════════════════════════════════════════════════════════════
//
//  Image de couverture avec :
//    • Effet parallax lié au scroll (facteur configurable, 0 = désactivé) ;
//    • Dégradé theme.heroGradient en overlay (opacity version-safe via
//      widget Opacity, jamais withOpacity/withValues → compatible 3.24+) ;
//    • Placeholder shimmer pendant le chargement (CachedNetworkImage) ;
//    • Fallback dégradé pur si aucune image (entreprise sans cover).
// ════════════════════════════════════════════════════════════════════════════

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class ParallaxCover extends StatefulWidget {
  const ParallaxCover({
    super.key,
    required this.colors,
    this.imageUrl,
    this.factor = 0.35,
    this.height = 340,
    this.overlayOpacity = 0.55,
  });

  /// Dégradé du thème de l'entreprise (primary → secondary).
  final List<Color> colors;
  final String? imageUrl;

  /// Intensité du parallax (0 → 1). 0 = image fixe.
  final double factor;
  final double height;
  final double overlayOpacity;

  @override
  State<ParallaxCover> createState() => _ParallaxCoverState();
}

class _ParallaxCoverState extends State<ParallaxCover> {
  ScrollPosition? _position;
  double _offset = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _detach();
    final pos = Scrollable.maybeOf(context)?.position;
    if (pos != null) {
      _position = pos;
      _position!.addListener(_onScroll);
      _offset = _position!.pixels;
    }
  }

  void _onScroll() {
    if (!mounted) return;
    final p = _position?.pixels ?? 0;
    if ((p - _offset).abs() > 1) setState(() => _offset = p);
  }

  void _detach() {
    _position?.removeListener(_onScroll);
    _position = null;
  }

  @override
  void dispose() {
    _detach();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Le parallax translate l'image vers le haut quand on scrolle.
    final shift = -_offset.clamp(0.0, widget.height * 2) * widget.factor;
    final extra = widget.height * widget.factor;

    return ClipRect(
      child: SizedBox(
        height: widget.height,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ── Image (ou dégradé seul si pas de cover) ──
            Transform.translate(
              offset: Offset(0, shift),
              child: SizedBox(
                height: widget.height + extra,
                child: widget.imageUrl == null || widget.imageUrl!.isEmpty
                    ? _GradientBase(colors: widget.colors)
                    : CachedNetworkImage(
                        imageUrl: widget.imageUrl!,
                        fit: BoxFit.cover,
                        placeholder: (context, url) =>
                            _GradientBase(colors: widget.colors),
                        errorWidget: (context, url, error) =>
                            _GradientBase(colors: widget.colors),
                      ),
              ),
            ),

            // ── Overlay dégradé du thème (opacity version-safe) ──
            IgnorePointer(
              child: Opacity(
                opacity: widget.overlayOpacity,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        widget.colors.first,
                        widget.colors.last,
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // ── Voile bas pour lisibilité du titre ──
            const IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.center,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black38],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dégradé animé subtil servant de base / placeholder.
class _GradientBase extends StatelessWidget {
  const _GradientBase({required this.colors});
  final List<Color> colors;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: colors.length >= 2 ? colors : [colors.first, colors.first],
          ),
        ),
        child: Shimmer.fromColors(
          baseColor: Colors.white.withOpacity(0.06),
          highlightColor: Colors.white.withOpacity(0.14),
          child: const SizedBox.expand(),
        ),
      );
}
