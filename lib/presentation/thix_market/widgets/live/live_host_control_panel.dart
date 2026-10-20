// lib/presentation/thix_market/widgets/live/live_host_control_panel.dart
// ============================================================================
// LIVE HOST CONTROL PANEL — Production Enterprise v5
// ----------------------------------------------------------------------------
//  • ✅ Charge les vrais détails produit (image, titre, prix) via Supabase
//  • ✅ Conversion automatique des devises
//  • ✅ Plus de placeholders hardcodés (icônes, UUID substrings)
//  • ✅ Support FR / EN / SW via AppLocalizations
//  • ✅ Skeleton loading pour chaque tile
// ============================================================================

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:thix_id/l10n/app_localizations.dart';
import 'package:thix_id/presentation/thix_market/models/live_shopping_models.dart';
import 'package:thix_id/presentation/thix_market/providers/live_shopping_providers.dart';
import 'package:thix_id/services/live_shopping_service.dart';
import '../../core/african_currencies.dart';
import '../../core/currency_service.dart';
import '../../providers/currency_provider.dart';
import 'package:thix_id/presentation/thix_market/providers/live_shopping_providers.dart'; 
// ============================================================================
// PROVIDER LOCAL — Détails produit pour le panneau hôte
// ============================================================================
final _hostProductDetailProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>?, String>((ref, productId) async {
  try {
    final res = await Supabase.instance.client
        .from('products')
        .select('id, title, price, discount_price, currency, image_url, images')
        .eq('id', productId)
        .maybeSingle()
        .timeout(const Duration(seconds: 8));
    return res != null ? Map<String, dynamic>.from(res) : null;
  } catch (e) {
    debugPrint('[HostPanel] ❌ Fetch product $productId: $e');
    return null;
  }
});

// ============================================================================
// WIDGET PRINCIPAL
// ============================================================================
class LiveHostControlPanel extends ConsumerStatefulWidget {
  final String sessionId;
  final List<String> availableProductIds;

  const LiveHostControlPanel({
    super.key,
    required this.sessionId,
    required this.availableProductIds,
  });

  @override
  ConsumerState<LiveHostControlPanel> createState() => _LiveHostControlPanelState();
}

class _LiveHostControlPanelState extends ConsumerState<LiveHostControlPanel> {
  final _service = LiveShoppingService();

  static const _navy = Color(0xFF1B2A4A);
  static const _gold = Color(0xFFC9962C);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final pinnedAsync = ref.watch(livePinnedProductsProvider(widget.sessionId));
    final pinned = pinnedAsync.valueOrNull ?? const [];

    // Produits disponibles = catalogue - déjà épinglés
    final pinnedIds = pinned.map((p) => p.productId).toSet();
    final available = widget.availableProductIds
        .where((id) => !pinnedIds.contains(id))
        .toList();

    return Container(
      decoration: const BoxDecoration(
        color: _navy,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle drag
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 16),

          // Titre
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(color: _gold, borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.shopping_bag_rounded, size: 15, color: _navy),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  l10n.t('live_host_products_title'),
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900),
                ),
              ),
              Text(
                '${pinned.length} ${l10n.t("live_host_active")}',
                style: const TextStyle(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Section "Actifs" (réordonnables) ──
          if (pinned.isNotEmpty) ...[
            Text(
              l10n.t('live_host_current_section'),
              style: const TextStyle(color: Colors.white60, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.5),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 140, // ✅ Augmenté de 120 → 140 pour éviter la coupe
              child: ReorderableListView.builder(
                scrollDirection: Axis.horizontal,
                onReorder: (old, nw) async {
                  HapticFeedback.selectionClick();
                  final reordered = List<LivePinnedProduct>.from(pinned);
                  final item = reordered.removeAt(old);
                  reordered.insert(nw > old ? nw - 1 : nw, item);
                  await _service.reorderPinned(
                    widget.sessionId,
                    reordered.map((p) => p.id).toList(),
                  );
                },
                itemCount: pinned.length,
                itemBuilder: (ctx, i) {
                  final p = pinned[i];
                  return _PinnedTile(
                    key: ValueKey(p.id),
                    pinned: p,
                    onSetFeatured: () async {
                      HapticFeedback.selectionClick();
                      await _service.setFeatured(widget.sessionId, p.id);
                    },
                    onRemove: () async {
                      HapticFeedback.mediumImpact();
                      await _service.unpinProduct(p.id);
                    },
                    onVoteCandidate: () async {
                      await _service.addVoteCandidate(widget.sessionId, p.productId);
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(l10n.t('live_host_vote_added')),
                          backgroundColor: _gold,
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
          ],

          // ── Section "Catalogue disponible" ──
          Text(
            l10n.t('live_host_catalog_section'),
            style: const TextStyle(color: Colors.white60, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.5),
          ),
          const SizedBox(height: 8),
          if (available.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text(
                  l10n.t('live_host_all_pinned'),
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ),
            )
          else
            SizedBox(
              height: 130, // ✅ Augmenté de 110 → 130 pour éviter la coupe
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: available.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (ctx, i) {
                  final pid = available[i];
                  return _AvailableTile(
                    productId: pid,
                    onPin: () async {
                      HapticFeedback.selectionClick();
                      await _service.pinProduct(widget.sessionId, pid);
                    },
                  );
                },
              ),
            ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
        ],
      ),
    );
  }
}

// ============================================================================
// TILE PRODUIT ÉPINGLÉ — Avec vraies données
// ============================================================================
class _PinnedTile extends ConsumerWidget {
  final LivePinnedProduct pinned;
  final VoidCallback onSetFeatured;
  final VoidCallback onRemove;
  final VoidCallback onVoteCandidate;

  const _PinnedTile({
    super.key,
    required this.pinned,
    required this.onSetFeatured,
    required this.onRemove,
    required this.onVoteCandidate,
  });

  static const _navy = Color(0xFF1B2A4A);
  static const _gold = Color(0xFFC9962C);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productAsync = ref.watch(_hostProductDetailProvider(pinned.productId));
    final displayCurrencyCode = ref.watch(currencyProvider);
    final currencyService = CurrencyService.instance;
    final lang = Localizations.localeOf(context).languageCode;

    return Container(
      width: 140, // ✅ Élargi de 130 → 140
      margin: const EdgeInsets.only(right: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: pinned.isFeatured ? _gold : Colors.white24,
          width: pinned.isFeatured ? 2 : 1,
        ),
      ),
      child: productAsync.when(
        loading: () => _buildSkeleton(pinned.isFeatured),
        error: (_, __) => _buildSkeleton(pinned.isFeatured),
        data: (product) {
          if (product == null) return _buildSkeleton(pinned.isFeatured);
          return _buildContent(product, displayCurrencyCode, currencyService, lang);
        },
      ),
    );
  }

  Widget _buildContent(
    Map<String, dynamic> product,
    String displayCurrencyCode,
    CurrencyService currencyService,
    String lang,
  ) {
    // Image
    String? imageUrl = product['image_url']?.toString();
    if ((imageUrl == null || imageUrl.isEmpty) && product['images'] is List) {
      final images = product['images'] as List;
      if (images.isNotEmpty) imageUrl = images.first.toString();
    }

    // Titre
    final title = (product['title']?.toString() ?? 'Produit').trim();

    // Prix converti
    final sellerCurrency = (product['currency'] ?? 'CDF').toString().toUpperCase();
    final price = (product['price'] as num?)?.toDouble() ?? 0;
    final discountPrice = (product['discount_price'] as num?)?.toDouble();
    final hasDiscount = discountPrice != null && discountPrice > 0 && discountPrice < price;
    final displayPrice = hasDiscount ? discountPrice! : price;

    final convertedPrice = currencyService.convert(displayPrice, from: sellerCurrency, to: displayCurrencyCode);
    final formattedPrice = currencyService.formatPrice(convertedPrice, currencyCode: displayCurrencyCode, lang: lang);

    return Column(
      children: [
        // ✅ VRAIE IMAGE
        ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
          child: Stack(
            children: [
              imageUrl != null && imageUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: imageUrl,
                      height: 70, // ✅ Augmenté de 60 → 70
                      width: double.infinity,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(
                        height: 70,
                        color: Colors.white.withOpacity(0.08),
                        child: const Center(
                          child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white38)),
                        ),
                      ),
                      errorWidget: (_, __, ___) => Container(
                        height: 70,
                        color: Colors.white.withOpacity(0.08),
                        child: const Center(child: Icon(Icons.broken_image_rounded, color: Colors.white38, size: 20)),
                      ),
                    )
                  : Container(
                      height: 70,
                      color: Colors.white.withOpacity(0.08),
                      child: const Center(child: Icon(Icons.shopping_bag_rounded, color: Colors.white38, size: 24)),
                    ),
              if (pinned.isFeatured)
                Positioned(
                  top: 4, left: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(color: _gold, borderRadius: BorderRadius.circular(4)),
                    child: const Icon(Icons.star_rounded, color: _navy, size: 10),
                  ),
                ),
            ],
          ),
        ),

        // ✅ VRAIS INFOS + ACTIONS
        Padding(
          padding: const EdgeInsets.all(6),
          child: Column(
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 2),
              Text(
                formattedPrice,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: _gold, fontSize: 10, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _miniBtn(
                    icon: pinned.isFeatured ? Icons.star_rounded : Icons.star_border_rounded,
                    color: _gold,
                    onTap: onSetFeatured,
                  ),
                  const SizedBox(width: 4),
                  _miniBtn(
                    icon: Icons.how_to_vote_rounded,
                    color: const Color(0xFF7C3AED),
                    onTap: onVoteCandidate,
                  ),
                  const SizedBox(width: 4),
                  _miniBtn(
                    icon: Icons.close_rounded,
                    color: const Color(0xFFE53935),
                    onTap: onRemove,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSkeleton(bool isFeatured) {
    return Column(
      children: [
        Container(
          height: 70,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
          ),
          child: const Center(
            child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white38)),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(6),
          child: Column(
            children: [
              Container(height: 10, width: double.infinity, color: Colors.white.withOpacity(0.1)),
              const SizedBox(height: 4),
              Container(height: 8, width: 60, color: Colors.white.withOpacity(0.1)),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(3, (_) => Container(
                  width: 20, height: 20, margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                )),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// TILE CATALOGUE DISPONIBLE — Avec vraies données
// ============================================================================
class _AvailableTile extends ConsumerWidget {
  final String productId;
  final VoidCallback onPin;

  const _AvailableTile({required this.productId, required this.onPin});

  static const _gold = Color(0xFFC9962C);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final productAsync = ref.watch(_hostProductDetailProvider(productId));

    return GestureDetector(
      onTap: onPin,
      child: Container(
        width: 110, // ✅ Élargi de 100 → 110
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white24),
        ),
        child: productAsync.when(
          loading: () => _buildSkeleton(),
          error: (_, __) => _buildSkeleton(),
          data: (product) {
            if (product == null) return _buildSkeleton();
            return _buildContent(product);
          },
        ),
      ),
    );
  }

  Widget _buildContent(Map<String, dynamic> product) {
    // Image
    String? imageUrl = product['image_url']?.toString();
    if ((imageUrl == null || imageUrl.isEmpty) && product['images'] is List) {
      final images = product['images'] as List;
      if (images.isNotEmpty) imageUrl = images.first.toString();
    }

    // Titre court
    final title = (product['title']?.toString() ?? '').trim();
    final shortTitle = title.length > 20 ? '${title.substring(0, 20)}…' : title;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // ✅ VRAIE IMAGE
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: imageUrl != null && imageUrl.isNotEmpty
              ? CachedNetworkImage(
                  imageUrl: imageUrl,
                  height: 55, // ✅ Augmenté de 50 → 55
                  width: 75,  // ✅ Élargi de 70 → 75
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(
                    height: 55, width: 75,
                    color: Colors.white.withOpacity(0.08),
                    child: const Center(
                      child: SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white38)),
                    ),
                  ),
                  errorWidget: (_, __, ___) => Container(
                    height: 55, width: 75,
                    color: Colors.white.withOpacity(0.08),
                    child: const Icon(Icons.broken_image_rounded, color: Colors.white38, size: 18),
                  ),
                )
              : Container(
                  height: 55, width: 75,
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.shopping_bag_rounded, color: Colors.white38, size: 20),
                ),
        ),
        const SizedBox(height: 4),
        // ✅ VRAI TITRE
        if (shortTitle.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              shortTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 8, fontWeight: FontWeight.w600),
            ),
          ),
        const SizedBox(height: 2),
        const Icon(Icons.add_circle_rounded, color: _gold, size: 20),
      ],
    );
  }

  Widget _buildSkeleton() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          height: 55, width: 75,
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
        ),
        const SizedBox(height: 6),
        Container(height: 8, width: 60, color: Colors.white.withOpacity(0.1)),
        const SizedBox(height: 4),
        Container(width: 20, height: 20, decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), shape: BoxShape.circle)),
      ],
    );
  }
}

// ============================================================================
// BOUTON MINIATURE RÉUTILISABLE
// ============================================================================
Widget _miniBtn({
  required IconData icon,
  required Color color,
  required VoidCallback onTap,
}) {
  return GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Icon(icon, color: color, size: 12),
    ),
  );
}
