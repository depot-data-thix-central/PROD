// lib/presentation/thix_market/widgets/live/live_voting_panel.dart
// ============================================================================
// LIVE VOTING PANEL — Production Enterprise v5
// ----------------------------------------------------------------------------
//  • ✅ Charge les vrais détails produit (image, titre, prix) via Supabase
//  • ✅ Conversion automatique des devises (54 devises africaines)
//  • ✅ Plus de placeholders hardcodés (icônes, UUID substrings)
//  • ✅ Support FR / EN / SW via AppLocalizations
//  • ✅ Skeleton loading pour chaque candidat
//  • ✅ Barre de progression visuelle des votes
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
// PROVIDER LOCAL — Détails produit pour le panneau de vote
// ============================================================================
final _voteProductDetailProvider =
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
    debugPrint('[VotePanel] ❌ Fetch product $productId: $e');
    return null;
  }
});

// ============================================================================
// WIDGET PRINCIPAL
// ============================================================================
class LiveVotingPanel extends ConsumerWidget {
  final String sessionId;

  const LiveVotingPanel({super.key, required this.sessionId});

  static const _navy = Color(0xFF1B2A4A);
  static const _gold = Color(0xFFE3B23C);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final candidates = ref.watch(liveVoteCandidatesProvider(sessionId));
    final service = LiveShoppingService();

    return Container(
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _navy,
        borderRadius: BorderRadius.circular(24),
      ),
      padding: const EdgeInsets.all(18),
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
              const Icon(Icons.how_to_vote_rounded, color: _gold, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  l10n.t('live_vote_title'),
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            l10n.t('live_vote_subtitle'),
            style: const TextStyle(color: Colors.white54, fontSize: 11),
          ),
          const SizedBox(height: 14),

          // Liste des candidats
          candidates.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(color: _gold),
              ),
            ),
            error: (_, __) => Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(l10n.t('common_error'), style: const TextStyle(color: Colors.white70)),
              ),
            ),
            data: (list) {
              if (list.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(20),
                  child: Center(
                    child: Column(
                      children: [
                        const Icon(Icons.how_to_vote_outlined, color: Colors.white24, size: 36),
                        const SizedBox(height: 8),
                        Text(
                          l10n.t('live_vote_no_candidates'),
                          style: const TextStyle(color: Colors.white54, fontSize: 13),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
              }

              // Calculer le max de votes pour la barre de progression
              final maxVotes = list.fold<int>(0, (max, c) => c.voteCount > max ? c.voteCount : max);

              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: list.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (ctx, i) {
                  final c = list[i];
                  return _VoteRow(
                    candidate: c,
                    maxVotes: maxVotes,
                    onTap: () async {
                      HapticFeedback.selectionClick();
                      await service.toggleVote(sessionId, c.productId);
                      ref.invalidate(liveVoteCandidatesProvider(sessionId));
                    },
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// LIGNE DE VOTE — Avec vraies données produit
// ============================================================================
class _VoteRow extends ConsumerWidget {
  final LiveVoteCandidate candidate;
  final int maxVotes;
  final VoidCallback onTap;

  const _VoteRow({
    required this.candidate,
    required this.maxVotes,
    required this.onTap,
  });

  static const _navy = Color(0xFF1B2A4A);
  static const _gold = Color(0xFFE3B23C);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final productAsync = ref.watch(_voteProductDetailProvider(candidate.productId));
    final displayCurrencyCode = ref.watch(currencyProvider);
    final currencyService = CurrencyService.instance;
    final lang = Localizations.localeOf(context).languageCode;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: candidate.viewerVoted ? _gold.withOpacity(0.15) : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: candidate.viewerVoted ? _gold : Colors.white24,
            width: candidate.viewerVoted ? 2 : 1,
          ),
        ),
        child: productAsync.when(
          loading: () => _buildSkeleton(candidate.viewerVoted),
          error: (_, __) => _buildSkeleton(candidate.viewerVoted),
          data: (product) {
            if (product == null) return _buildSkeleton(candidate.viewerVoted);
            return _buildContent(product, displayCurrencyCode, currencyService, lang, l10n);
          },
        ),
      ),
    );
  }

  Widget _buildContent(
    Map<String, dynamic> product,
    String displayCurrencyCode,
    CurrencyService currencyService,
    String lang,
    AppLocalizations l10n,
  ) {
    // ✅ Image
    String? imageUrl = product['image_url']?.toString();
    if ((imageUrl == null || imageUrl.isEmpty) && product['images'] is List) {
      final images = product['images'] as List;
      if (images.isNotEmpty) imageUrl = images.first.toString();
    }

    // ✅ Titre
    final title = (product['title']?.toString() ?? l10n.t('live_vote_product_fallback')).trim();

    // ✅ Prix converti
    final sellerCurrency = (product['currency'] ?? 'CDF').toString().toUpperCase();
    final price = (product['price'] as num?)?.toDouble() ?? 0;
    final discountPrice = (product['discount_price'] as num?)?.toDouble();
    final hasDiscount = discountPrice != null && discountPrice > 0 && discountPrice < price;
    final displayPrice = hasDiscount ? discountPrice! : price;

    final convertedPrice = currencyService.convert(displayPrice, from: sellerCurrency, to: displayCurrencyCode);
    final formattedPrice = currencyService.formatPrice(convertedPrice, currencyCode: displayCurrencyCode, lang: lang);

    // ✅ Barre de progression des votes
    final voteProgress = maxVotes > 0 ? (candidate.voteCount / maxVotes).clamp(0.0, 1.0) : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            // ✅ VRAIE IMAGE PRODUIT
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: imageUrl != null && imageUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: imageUrl,
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(
                        width: 48, height: 48,
                        color: Colors.white.withOpacity(0.08),
                        child: const Center(
                          child: SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white38)),
                        ),
                      ),
                      errorWidget: (_, __, ___) => Container(
                        width: 48, height: 48,
                        color: Colors.white.withOpacity(0.08),
                        child: const Icon(Icons.broken_image_rounded, color: Colors.white38, size: 18),
                      ),
                    )
                  : Container(
                      width: 48, height: 48,
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.shopping_bag_rounded, color: Colors.white38, size: 18),
                    ),
            ),
            const SizedBox(width: 10),

            // ✅ VRAIS INFOS PRODUIT
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    formattedPrice,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: _gold, fontSize: 11, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),

            // ✅ BOUTON VOTE
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: candidate.viewerVoted ? _gold : Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    candidate.viewerVoted ? Icons.check_rounded : Icons.arrow_upward_rounded,
                    size: 13,
                    color: candidate.viewerVoted ? _navy : Colors.white70,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${candidate.voteCount}',
                    style: TextStyle(
                      color: candidate.viewerVoted ? _navy : Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        // ✅ BARRE DE PROGRESSION DES VOTES
        if (candidate.voteCount > 0) ...[
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: voteProgress,
              minHeight: 4,
              backgroundColor: Colors.white.withOpacity(0.08),
              valueColor: AlwaysStoppedAnimation<Color>(
                candidate.viewerVoted ? _gold : Colors.white.withOpacity(0.4),
              ),
            ),
          ),
        ],
      ],
    );
  }

  /// Skeleton pendant le chargement du produit
  Widget _buildSkeleton(bool viewerVoted) {
    return Row(
      children: [
        Container(
          width: 48, height: 48,
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
          child: const Center(
            child: SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white38)),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(height: 12, width: double.infinity, color: Colors.white.withOpacity(0.1)),
              const SizedBox(height: 4),
              Container(height: 10, width: 60, color: Colors.white.withOpacity(0.1)),
            ],
          ),
        ),
        Container(
          width: 50, height: 28,
          decoration: BoxDecoration(
            color: viewerVoted ? _gold.withOpacity(0.15) : Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ],
    );
  }
}
