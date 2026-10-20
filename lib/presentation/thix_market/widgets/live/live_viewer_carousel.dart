// lib/presentation/thix_market/widgets/live/live_viewer_carousel.dart
// ============================================================================
// LIVE VIEWER CAROUSEL — Production Enterprise v5
// ----------------------------------------------------------------------------
//  • ✅ Hauteur corrigée (200px au lieu de 170px) → plus de coupe
//  • ✅ Navigation produit gérée par LivePinnedProductCard (plus de TODO)
//  • ✅ Support FR / EN / SW via AppLocalizations
//  • ✅ Auto-scroll fluide vers le produit featured
//  • ✅ Bouton vote avec traduction dynamique
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:thix_id/l10n/app_localizations.dart';
import 'package:thix_id/presentation/thix_market/models/live_shopping_models.dart';
import 'package:thix_id/presentation/thix_market/providers/live_shopping_providers.dart';
import 'package:thix_id/presentation/thix_market/widgets/live/live_pinned_product_card.dart';

class LiveViewerCarousel extends ConsumerStatefulWidget {
  final String sessionId;
  final VoidCallback onOpenVoting;

  const LiveViewerCarousel({
    super.key,
    required this.sessionId,
    required this.onOpenVoting,
  });

  @override
  ConsumerState<LiveViewerCarousel> createState() => _LiveViewerCarouselState();
}

class _LiveViewerCarouselState extends ConsumerState<LiveViewerCarousel> {
  late PageController _pageCtrl;
  int _currentPage = 0;
  String? _lastFeaturedId;

  @override
  void initState() {
    super.initState();
    _pageCtrl = PageController(viewportFraction: 0.72);
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    debugPrint('[LiveCarousel] 👋 Disposed');
    super.dispose();
  }

  void _autoScrollToFeatured(List<LivePinnedProduct> pinned, String? featuredId) {
    if (featuredId == null || featuredId == _lastFeaturedId) return;
    if (pinned.isEmpty) return;
    final idx = pinned.indexWhere((p) => p.productId == featuredId);
    if (idx >= 0 && idx != _currentPage && _pageCtrl.hasClients) {
      _pageCtrl.animateToPage(
        idx,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
      );
      setState(() => _currentPage = idx);
      debugPrint('[LiveCarousel] 🎯 Auto-scrolled to featured product at index $idx');
    }
    _lastFeaturedId = featuredId;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final pinnedAsync = ref.watch(livePinnedProductsProvider(widget.sessionId));
    final pinned = pinnedAsync.valueOrNull ?? const [];
    final featuredId = ref.watch(liveFeaturedProductIdProvider(pinned));

    // Auto-scroll dès que l'hôte change le featured
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _autoScrollToFeatured(pinned, featuredId);
    });

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black.withOpacity(0.85)],
        ),
      ),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom + 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ─── BOUTON VOTE ───
          GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              widget.onOpenVoting();
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFE3B23C),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFE3B23C).withOpacity(0.4),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.how_to_vote_rounded, color: Color(0xFF1B2A4A), size: 16),
                  const SizedBox(width: 6),
                  Text(
                    l10n.t('live_vote_next_product'),
                    style: const TextStyle(
                      color: Color(0xFF1B2A4A),
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ─── CAROUSEL PRODUITS ───
          if (pinned.isEmpty)
            SizedBox(
              height: 80,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.shopping_bag_outlined, color: Colors.white38, size: 28),
                    const SizedBox(height: 6),
                    Text(
                      l10n.t('live_products_coming_soon'),
                      style: const TextStyle(color: Colors.white60, fontSize: 13),
                    ),
                  ],
                ),
              ),
            )
          else
            // ✅ HAUTEUR CORRIGÉE : 200px au lieu de 170px
            SizedBox(
              height: 200,
              child: PageView.builder(
                controller: _pageCtrl,
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemCount: pinned.length,
                itemBuilder: (context, i) {
                  final p = pinned[i];
                  return LivePinnedProductCard(
                    productId: p.productId,
                    isFeatured: p.productId == featuredId,
                    // ✅ onTap supprimé → LivePinnedProductCard gère la navigation
                    //    vers /market/product/$productId automatiquement
                  );
                },
              ),
            ),

          // ─── DOTS INDICATEURS ───
          if (pinned.isNotEmpty && pinned.length > 1) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(pinned.length, (i) {
                final active = i == _currentPage;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: active ? 18 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: active ? const Color(0xFFE3B23C) : Colors.white24,
                    borderRadius: BorderRadius.circular(3),
                  ),
                );
              }),
            ),
          ],
        ],
      ),
    );
  }
}
