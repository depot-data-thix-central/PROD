// lib/presentation/thix_market/widgets/live/live_offer_card.dart
// ============================================================================
// LIVE OFFER CARD — Production Enterprise v5
// ----------------------------------------------------------------------------
//  • ✅ Conversion automatique des devises (54 devises africaines)
//  • ✅ Timer compte à rebours temps réel (Timer.periodic 1s)
//  • ✅ Support FR / EN / SW via AppLocalizations
//  • ✅ Navigation vers ProductDetailPage au tap
//  • ✅ Badge réduction + barre de stock visuelle
//  • ✅ Indicateur 💱 si devise convertie
//  • ✅ Gestion safe des données (null-safe partout)
// ============================================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:thix_id/l10n/app_localizations.dart';

import 'package:thix_id/core/theme/thix_design_policy.dart';
import '../../core/african_currencies.dart';
import '../../core/currency_service.dart';
import '../../providers/currency_provider.dart';

// ============================================================================
// VALIDATEURS
// ============================================================================
class _OfferValidators {
  _OfferValidators._();

  static String sanitize(String? input, {int maxLength = 200}) {
    if (input == null || input.trim().isEmpty) return '';
    final s = input.trim();
    return s.length > maxLength ? s.substring(0, maxLength) : s;
  }

  static String? sanitizeUrl(String? url) {
    if (url == null || url.trim().isEmpty) return null;
    final t = url.trim();
    if (!t.startsWith('http://') && !t.startsWith('https://')) return null;
    return t;
  }

  static double safeDouble(dynamic v, {double fallback = 0.0}) {
    if (v == null) return fallback;
    final parsed = (v as num?)?.toDouble() ?? fallback;
    return parsed < 0 || parsed.isNaN || parsed.isInfinite ? fallback : parsed;
  }

  static int safeInt(dynamic v, {int fallback = 0}) {
    if (v == null) return fallback;
    final parsed = (v as num?)?.toInt() ?? fallback;
    return parsed < 0 ? fallback : parsed;
  }

  static String normalizeCurrencyCode(dynamic c) {
    if (c == null) return 'CDF';
    final v = c.toString().toUpperCase().trim();
    if (AfricanCurrencies.byCode(v) != null) return v;
    final aliases = <String, String>{
      'FC': 'CDF', 'FCFA': 'XOF', r'$': 'USD',
      'DOLLAR': 'USD', 'US': 'USD', 'EURO': 'EUR', '€': 'EUR',
    };
    return aliases[v] ?? 'CDF';
  }
}

// ============================================================================
// WIDGET PRINCIPAL — ConsumerStatefulWidget pour timer + devise
// ============================================================================
class LiveOfferCard extends ConsumerStatefulWidget {
  final Map<String, dynamic> offer;
  final VoidCallback? onTap;
  final VoidCallback? onClaim;

  const LiveOfferCard({
    super.key,
    required this.offer,
    this.onTap,
    this.onClaim,
  });

  @override
  ConsumerState<LiveOfferCard> createState() => _LiveOfferCardState();
}

class _LiveOfferCardState extends ConsumerState<LiveOfferCard> {
  Timer? _countdownTimer;
  Duration _timeLeft = Duration.zero;
  bool _isExpired = false;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  @override
  void didUpdateWidget(covariant LiveOfferCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Redémarrer le timer si l'offre change
    if (oldWidget.offer['expires_at'] != widget.offer['expires_at']) {
      _startCountdown();
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    _countdownTimer?.cancel();

    final expiresAtStr = widget.offer['expires_at']?.toString();
    if (expiresAtStr == null) {
      setState(() => _isExpired = false);
      return;
    }

    final endTime = DateTime.tryParse(expiresAtStr);
    if (endTime == null) {
      setState(() => _isExpired = false);
      return;
    }

    // Mise à jour immédiate
    _updateTimeLeft(endTime);

    // Puis toutes les secondes
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      _updateTimeLeft(endTime);
    });
  }

  void _updateTimeLeft(DateTime endTime) {
    final remaining = endTime.difference(DateTime.now());
    final expired = remaining.isNegative;

    setState(() {
      _timeLeft = expired ? Duration.zero : remaining;
      _isExpired = expired;
    });

    // Arrêter le timer si expiré
    if (expired) {
      _countdownTimer?.cancel();
    }
  }

  String _formatDuration(Duration duration) {
    if (duration.inSeconds <= 0) return '00:00';
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    final displayCurrencyCode = ref.watch(currencyProvider);
    final currencyService = CurrencyService.instance;

    // ─── Extraction sécurisée des données ───
    final sellerCurrencyCode = _OfferValidators.normalizeCurrencyCode(widget.offer['currency']);
    final isConverted = sellerCurrencyCode != displayCurrencyCode;

    final priceRaw = _OfferValidators.safeDouble(widget.offer['price']);
    final originalPriceRaw = _OfferValidators.safeDouble(widget.offer['original_price']);
    final hasDiscount = originalPriceRaw > 0 && priceRaw > 0 && priceRaw < originalPriceRaw;
    final discountPercent = hasDiscount
        ? ((originalPriceRaw - priceRaw) / originalPriceRaw * 100).round()
        : (_OfferValidators.safeInt(widget.offer['discount_percentage']));

    // ✅ Conversion des prix
    final convertedPrice = currencyService.convert(priceRaw, from: sellerCurrencyCode, to: displayCurrencyCode);
    final formattedPrice = currencyService.formatPrice(convertedPrice, currencyCode: displayCurrencyCode, lang: lang);

    String? formattedOriginalPrice;
    if (hasDiscount) {
      final convertedOriginal = currencyService.convert(originalPriceRaw, from: sellerCurrencyCode, to: displayCurrencyCode);
      formattedOriginalPrice = currencyService.formatPrice(convertedOriginal, currencyCode: displayCurrencyCode, lang: lang);
    }

    // Image
    String? imageUrl = _OfferValidators.sanitizeUrl(widget.offer['image_url']?.toString());
    if (imageUrl == null && widget.offer['images'] is List) {
      final images = widget.offer['images'] as List;
      if (images.isNotEmpty) imageUrl = _OfferValidators.sanitizeUrl(images.first.toString());
    }

    // Titre
    final title = _OfferValidators.sanitize(
      widget.offer['title']?.toString() ?? l10n.t('live_offer_fallback_title'),
    );

    // Stock
    final stock = _OfferValidators.safeInt(widget.offer['stock']);
    final stockInitial = _OfferValidators.safeInt(widget.offer['stock_initial'], fallback: stock > 0 ? stock * 2 : 100);
    final hasStock = widget.offer['stock'] != null && stockInitial > 0;
    final stockProgress = hasStock
        ? ((stockInitial - stock) / stockInitial).clamp(0.0, 1.0)
        : 0.0;

    // Produit ID pour navigation
    final productId = widget.offer['id']?.toString() ?? widget.offer['product_id']?.toString();

    // Couleur timer
    final timerColor = _isExpired
        ? ThixPolicy.textMuted
        : _timeLeft.inMinutes < 5
            ? ThixPolicy.danger
            : const Color(0xFFE5592F);

    return GestureDetector(
      onTap: widget.onTap ?? (productId != null ? () {
        HapticFeedback.selectionClick();
        context.push('/market/product/$productId');
      } : null),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: ThixPolicy.border.withOpacity(0.5)),
        ),
        color: ThixPolicy.card,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── IMAGE ───
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: Stack(
                children: [
                  imageUrl != null && imageUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: imageUrl,
                          height: 140,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(
                            height: 140,
                            color: ThixPolicy.surfaceSoft,
                            child: const Center(
                              child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: ThixPolicy.primary)),
                            ),
                          ),
                          errorWidget: (_, __, ___) => Container(
                            height: 140,
                            color: ThixPolicy.surfaceSoft,
                            child: const Icon(Icons.broken_image_outlined, color: ThixPolicy.textMuted, size: 32),
                          ),
                        )
                      : Container(
                          height: 140,
                          color: ThixPolicy.surfaceSoft,
                          child: const Icon(Icons.shopping_bag_outlined, color: ThixPolicy.textMuted, size: 32),
                        ),

                  // Badge réduction
                  if (discountPercent > 0)
                    Positioned(
                      top: 8, left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: ThixPolicy.danger,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '-$discountPercent%',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11),
                        ),
                      ),
                    ),

                  // Timer countdown
                  if (!_isExpired && widget.offer['expires_at'] != null)
                    Positioned(
                      bottom: 8, right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: timerColor.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.timer_outlined, size: 11, color: Colors.white),
                            const SizedBox(width: 4),
                            Text(
                              _formatDuration(_timeLeft),
                              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Badge expiré
                  if (_isExpired)
                    Positioned.fill(
                      child: Container(
                        color: Colors.black.withOpacity(0.45),
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: ThixPolicy.textMuted,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              l10n.t('live_offer_expired'),
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // ─── CONTENU ───
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Titre
                  Text(
                    title.isEmpty ? l10n.t('live_offer_fallback_title') : title,
                    style: ThixPolicy.labelStyle.copyWith(fontWeight: ThixPolicy.bold, fontSize: 14, color: ThixPolicy.textMain),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),

                  // Prix
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          formattedPrice,
                          style: ThixPolicy.titleStyle.copyWith(fontWeight: ThixPolicy.bold, fontSize: 16, color: const Color(0xFFC9962C)),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isConverted) ...[
                        const SizedBox(width: 3),
                        const Icon(Icons.currency_exchange_rounded, size: 12, color: Color(0xFFC9962C)),
                      ],
                      if (formattedOriginalPrice != null) ...[
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            formattedOriginalPrice,
                            style: ThixPolicy.captionStyle.copyWith(
                              decoration: TextDecoration.lineThrough,
                              fontSize: 11,
                              color: ThixPolicy.textMuted,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),

                  // Barre de stock
                  if (hasStock) ...[
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: stockProgress,
                        minHeight: 6,
                        backgroundColor: ThixPolicy.border.withOpacity(0.3),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          stock <= 3 ? ThixPolicy.danger : const Color(0xFFC9962C),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        stock <= 0
                            ? l10n.t('live_offer_out_of_stock')
                            : l10n.t('live_offer_stock_remaining', args: ['$stock']),
                        style: ThixPolicy.microStyle.copyWith(
                          fontSize: 10,
                          color: stock <= 3 ? ThixPolicy.danger : ThixPolicy.textMuted,
                          fontWeight: stock <= 3 ? ThixPolicy.bold : ThixPolicy.regular,
                        ),
                      ),
                    ),
                  ],

                  // Bouton Profiter
                  if (widget.onClaim != null) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: (_isExpired || stock <= 0) ? null : widget.onClaim,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: (_isExpired || stock <= 0) ? ThixPolicy.textMuted : const Color(0xFFC9962C),
                          foregroundColor: (_isExpired || stock <= 0) ? Colors.white : const Color(0xFF1B2A4A),
                          disabledBackgroundColor: ThixPolicy.textMuted.withOpacity(0.5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          elevation: 0,
                        ),
                        child: Text(
                          _isExpired
                              ? l10n.t('live_offer_expired')
                              : stock <= 0
                                  ? l10n.t('live_offer_out_of_stock')
                                  : l10n.t('live_offer_claim_btn'),
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
