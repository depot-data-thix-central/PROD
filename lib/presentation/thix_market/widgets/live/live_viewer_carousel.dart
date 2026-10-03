// lib/presentation/thix_market/widgets/live/live_viewer_carousel.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
    super.dispose();
  }

  void _autoScrollToFeatured(List<LivePinnedProduct> pinned, String? featuredId) {
    if (featuredId == null || featuredId == _lastFeaturedId) return;
    if (pinned.isEmpty) return;
    final idx = pinned.indexWhere((p) => p.productId == featuredId);
    if (idx >= 0 && idx != _currentPage && _pageCtrl.hasClients) {
      _pageCtrl.animateToPage(idx,
          duration: const Duration(milliseconds: 450), curve: Curves.easeOutCubic);
      setState(() => _currentPage = idx);
    }
    _lastFeaturedId = featuredId;
  }

  @override
  Widget build(BuildContext context) {
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
          // Bouton vote
          GestureDetector(
            onTap: widget.onOpenVoting,
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
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.how_to_vote_rounded,
                      color: Color(0xFF1B2A4A), size: 16),
                  SizedBox(width: 6),
                  Text('Voter pour le prochain produit',
                      style: TextStyle(
                          color: Color(0xFF1B2A4A),
                          fontSize: 12,
                          fontWeight: FontWeight.w900)),
                ],
              ),
            ),
          ),
          // Carousel
          if (pinned.isEmpty)
            const SizedBox(
              height: 60,
              child: Center(
                child: Text('Produits à venir…',
                    style: TextStyle(color: Colors.white60, fontSize: 13)),
              ),
            )
          else
            SizedBox(
              height: 170,
              child: PageView.builder(
                controller: _pageCtrl,
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemCount: pinned.length,
                itemBuilder: (context, i) {
                  final p = pinned[i];
                  return LivePinnedProductCard(
                    productId: p.productId,
                    isFeatured: p.productId == featuredId,
                    onTap: () {
                      // TODO: ouvrir détail produit
                    },
                  );
                },
              ),
            ),
          // Dots
          if (pinned.isNotEmpty) ...[
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
