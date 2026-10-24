// lib/presentation/thix_market/widgets/products/local_product_card.dart
// ============================================================================
// CARTE PRODUIT LOCAL — affiche TOUT pour un produit local
//  • Secteur (badge coloré) • Producteur / coopérative • Terroir + drapeau
//  • Labels / certifications • Prix converti par unité • Périssable / expiration
//  • Stock • Note • Wishlist • Ribbon "100% LOCAL"
// ============================================================================

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:thix_id/core/theme/thix_design_policy.dart';

import '../../core/african_countries.dart';
import '../../core/currency_service.dart';
import '../../core/local_sectors.dart';
import '../../providers/currency_provider.dart';
import 'wishlist_button.dart';

class LocalProductCard extends ConsumerWidget {
  final Map<String, dynamic> product;
  final double? width;
  final double height;

  const LocalProductCard({
    super.key,
    required this.product,
    this.width,
    this.height = 268,
  });

  // ── Helpers parsing sécurisés ──
  static String _clean(String? s, [int max = 80]) {
    if (s == null) return '';
    var v = s.replaceAll(RegExp(r'<[^>]*>'), '').trim();
    return v.length > max ? v.substring(0, max) : v;
  }

  static String? _image(Map<String, dynamic> p) {
    final u = p['image_url']?.toString();
    if (u != null && u.startsWith('http')) return u;
    if (p['images'] is List && (p['images'] as List).isNotEmpty) {
      final f = (p['images'] as List).first.toString();
      if (f.startsWith('http')) return f;
    }
    return null;
  }

  static int _stock(dynamic v) {
    final n = int.tryParse(v.toString());
    return (n != null && n >= 0) ? n : 0;
  }

  static double _price(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString().replaceAll(RegExp(r'[^\d.,-]'), '')) ?? 0;
  }

  List<String> _certs(Map<String, dynamic> p) {
    final raw = p['certifications'];
    if (raw is List) return raw.map((e) => e.toString()).toList();
    return const [];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = Localizations.localeOf(context).languageCode;
    final displayCurrency = ref.watch(currencyProvider);

    final id = product['id']?.toString() ?? '';
    final title = _clean(product['title']?.toString() ?? product['name']?.toString(), 120);
    final sector = localSectorById(product['local_sector']?.toString());
    final producer = _clean(product['producer_name']?.toString(), 60);
    final shopEmbedded = product['shop'];
    final shopName = _clean(
      (shopEmbedded is Map ? shopEmbedded['name'] : null)?.toString() ??
          product['shop_name']?.toString() ??
          '',
      40,
    );
    final terroirRaw = _clean(product['terroir']?.toString(), 60);
    final cityRaw = _clean(product['city']?.toString(), 60);
    final origin = terroirRaw.isNotEmpty ? terroirRaw : cityRaw;
    final originLine = AfricanCountries.locationLine(
      city: origin.isNotEmpty ? origin : cityRaw,
      code: product['country']?.toString(),
    );

    // ── Prix (devise vendeur → devise affichée) ──
    final sellerCurrency = (product['currency'] ?? 'CDF').toString().toUpperCase();
    final original = _price(product['price']);
    final rawDisc = product['discount_price'];
    final disc = rawDisc != null ? _price(rawDisc) : null;
    final hasDisc = disc != null && disc > 0 && disc < original;
    final base = hasDisc ? disc! : original;
    final svc = CurrencyService.instance;
    final converted = svc.convert(base, from: sellerCurrency, to: displayCurrency);
    final convertedOrig = hasDisc
        ? svc.convert(original, from: sellerCurrency, to: displayCurrency)
        : null;
    final priceLabel = svc.formatPrice(converted, currencyCode: displayCurrency, lang: lang);
    final origLabel = convertedOrig != null
        ? svc.formatPrice(convertedOrig, currencyCode: displayCurrency, lang: lang)
        : null;
    final unit = product['unit']?.toString() ?? '';

    // ── Stock & périssable ──
    final stock = _stock(product['stock']);
    final isOut = stock <= 0;
    final isLow = !isOut && stock <= 5;
    final perishable = product['is_perishable'] == true ||
        (product['expiry_date']?.toString().isNotEmpty ?? false);
    final expiry = DateTime.tryParse(product['expiry_date']?.toString() ?? '');
    int? daysLeft;
    if (expiry != null) {
      final now = DateTime.now();
      daysLeft = DateTime(expiry.year, expiry.month, expiry.day)
          .difference(DateTime(now.year, now.month, now.day))
          .inDays;
    }
    final isExpired = daysLeft != null && daysLeft < 0;

    final rating = (product['rating'] as num?)?.toDouble() ?? 0;
    final certs = _certs(product);
    final img = _image(product);

    return RepaintBoundary(
      child: Semantics(
        button: true,
        label: '$title, ${isOut ? 'indisponible' : priceLabel}',
        enabled: !isOut && !isExpired,
        child: GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            if (id.isNotEmpty) context.push('/market/product/$id');
          },
          child: Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              color: ThixPolicy.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: ThixPolicy.border.withOpacity(0.7)),
              boxShadow: ThixPolicy.shadowSoft(opacity: 0.05),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ─────────── IMAGE + BADGES ───────────
                Expanded(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        img == null
                            ? Container(
                                color: kLocalGreenSoft,
                                child: Icon(sector?.icon ?? Icons.agriculture_rounded,
                                    color: kLocalGreen.withOpacity(0.5), size: 34),
                              )
                            : CachedNetworkImage(
                                imageUrl: img,
                                fit: BoxFit.cover,
                                placeholder: (_, __) => const Center(
                                    child: SizedBox(width: 18, height: 18,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: kLocalGreen))),
                                errorWidget: (_, __, ___) => Container(
                                    color: kLocalGreenSoft,
                                    child: Icon(sector?.icon ?? Icons.agriculture_rounded,
                                        color: kLocalGreen.withOpacity(0.5), size: 34)),
                              ),

                        if (isOut || isExpired)
                          Container(
                            color: Colors.black.withOpacity(0.45),
                            child: Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                    color: ThixPolicy.danger, borderRadius: BorderRadius.circular(4)),
                                child: Text(
                                  isExpired ? 'EXPIRÉ' : 'ÉPUISÉ',
                                  style: const TextStyle(color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.w900),
                                ),
                              ),
                            ),
                          ),

                        // Badge secteur (haut gauche)
                        if (sector != null)
                          Positioned(
                            top: 6,
                            left: 6,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                              decoration: BoxDecoration(
                                color: sector.color,
                                borderRadius: BorderRadius.circular(6),
                                boxShadow: [BoxShadow(color: sector.color.withOpacity(0.4), blurRadius: 4, offset: const Offset(0, 1))],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(sector.icon, size: 9, color: Colors.white),
                                  const SizedBox(width: 3),
                                  ConstrainedBox(
                                    constraints: const BoxConstraints(maxWidth: 90),
                                    child: Text(
                                      sector.label(lang),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w800),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                        // Wishlist (haut droite)
                        if (id.isNotEmpty)
                          Positioned(
                            top: 6,
                            right: 6,
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                              child: WishlistButton(productId: id, size: 15),
                            ),
                          ),

                        // Ribbon 100% LOCAL (bas gauche)
                        Positioned(
                          bottom: 6,
                          left: 6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(colors: [kLocalGreen, kLocalGreenDeep]),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.verified_rounded, size: 9, color: Colors.white),
                                SizedBox(width: 3),
                                Text('100% LOCAL',
                                    style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 0.3)),
                              ],
                            ),
                          ),
                        ),

                        // Chip expiration (bas droite)
                        if (perishable && daysLeft != null && !isExpired)
                          Positioned(
                            bottom: 6,
                            right: 6,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                              decoration: BoxDecoration(
                                color: daysLeft <= 3 ? ThixPolicy.warning : ThixPolicy.success,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                daysLeft <= 3 ? 'Expire dans $daysLeft j' : 'Frais',
                                style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w800),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

                // ─────────── INFOS ───────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title.isEmpty ? '—' : title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: ThixPolicy.labelStyle.copyWith(
                            fontWeight: ThixPolicy.semiBold, fontSize: 11.5, color: ThixPolicy.textMain, height: 1.2),
                      ),

                      // Producteur / coopérative (fallback boutique)
                      if (producer.isNotEmpty || shopName.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            const Icon(Icons.handshake_rounded, size: 10, color: kLocalGreen),
                            const SizedBox(width: 3),
                            Expanded(
                              child: Text(
                                producer.isNotEmpty ? producer : shopName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: ThixPolicy.microStyle.copyWith(
                                    color: kLocalGreen, fontSize: 9.5, fontWeight: ThixPolicy.semiBold),
                              ),
                            ),
                          ],
                        ),
                      ],

                      // Terroir + drapeau
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.location_on_outlined, size: 9.5, color: ThixPolicy.textMuted),
                          const SizedBox(width: 2),
                          Expanded(
                            child: Text(originLine,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: ThixPolicy.microStyle.copyWith(color: ThixPolicy.textMuted, fontSize: 9)),
                          ),
                        ],
                      ),

                      // Labels / certifications (max 2 + n)
                      if (certs.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            for (final c in certs.take(2))
                              Container(
                                margin: const EdgeInsets.only(right: 4),
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                decoration: BoxDecoration(
                                  color: kLocalGreen.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: kLocalGreen.withOpacity(0.35)),
                                ),
                                child: Text(
                                  (lang == 'fr'
                                          ? kLocalCertifications.firstWhere((e) => e.id == c,
                                              orElse: () => LocalCertification(c, c, c, Icons.verified_rounded)).labelFr
                                          : kLocalCertifications.firstWhere((e) => e.id == c,
                                              orElse: () => LocalCertification(c, c, c, Icons.verified_rounded)).labelEn),
                                  style: TextStyle(fontSize: 7.5, fontWeight: FontWeight.w800, color: kLocalGreenDeep),
                                ),
                              ),
                            if (certs.length > 2)
                              Text('+${certs.length - 2}',
                                  style: TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: ThixPolicy.textMuted)),
                          ],
                        ),
                      ],

                      const SizedBox(height: 4),
                      // Prix + unité
                      Row(
                        children: [
                          if (hasDisc && origLabel != null)
                            Padding(
                              padding: const EdgeInsets.only(right: 4),
                              child: Text(origLabel,
                                  style: TextStyle(
                                      decoration: TextDecoration.lineThrough,
                                      fontSize: 9,
                                      color: ThixPolicy.textMuted)),
                            ),
                          Expanded(
                            child: Text(
                              isOut ? 'Indisponible' : priceLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: ThixPolicy.labelStyle.copyWith(
                                  fontWeight: ThixPolicy.bold,
                                  fontSize: 13,
                                  color: isOut ? ThixPolicy.textMuted : ThixPolicy.danger),
                            ),
                          ),
                          if (rating > 0)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.star_rounded, size: 10, color: ThixPolicy.gold),
                                Text(rating.toStringAsFixed(1),
                                    style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w800, color: ThixPolicy.textSecondary)),
                              ],
                            ),
                        ],
                      ),
                      if (unit.isNotEmpty && !isOut)
                        Text('/ ${kLocalUnitLabel(unit)}',
                            style: ThixPolicy.microStyle.copyWith(color: ThixPolicy.textMuted, fontSize: 8.5)),

                      // Stock
                      if (!isOut) ...[
                        const SizedBox(height: 3),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 4,
                              height: 4,
                              decoration: BoxDecoration(
                                  color: isLow ? ThixPolicy.warning : ThixPolicy.success, shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 3),
                            Text(
                              isLow
                                  ? (lang == 'en' ? 'Only $stock left!' : lang == 'sw' ? 'Zimebaki $stock tu!' : 'Plus que $stock !')
                                  : '$stock ${lang == 'en' ? 'in stock' : lang == 'sw' ? 'stock' : 'en stock'}',
                              style: ThixPolicy.microStyle.copyWith(
                                  fontSize: 8.5,
                                  fontWeight: ThixPolicy.semiBold,
                                  color: isLow ? ThixPolicy.warning : ThixPolicy.success),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
