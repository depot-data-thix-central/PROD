// lib/presentation/thix_market/cart/cart_item_tile.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:html/parser.dart' as html_parser;

import 'package:thix_id/core/theme/thix_design_policy.dart';

// ============================================================================
// CONSTANTES
// ============================================================================
const int _kMinQuantity = 1;
const int _kMaxQuantity = 999;
const int _kLowStockThreshold = 5;
const int _kMaxTitleLength = 80;
const int _kMaxShopNameLength = 40;
const int _kMaxCityLength = 40;
const int _kMaxWarrantyLength = 30;

// ============================================================================
// VALIDATEURS
// ============================================================================
class _CartItemValidators {
  _CartItemValidators._();

  static String sanitize(String? input, {int maxLength = 500}) {
    if (input == null || input.trim().isEmpty) return '';
    final doc = html_parser.parse(input);
    var s = doc.body?.text ?? input;
    s = s
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll(RegExp(r'javascript:', caseSensitive: false), '')
        .replaceAll(RegExp(r'on\w+\s*=', caseSensitive: false), '')
        .replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '')
        .trim();
    return s.length > maxLength ? s.substring(0, maxLength) : s;
  }

  static String? sanitizeUrl(String? url) {
    if (url == null || url.trim().isEmpty) return null;
    final t = url.trim();
    if (!t.startsWith('http://') && !t.startsWith('https://')) return null;
    return t.replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '');
  }

  static double safeDouble(dynamic v, {double fallback = 0.0}) {
    if (v == null) return fallback;
    final parsed = (v as num?)?.toDouble() ?? fallback;
    return parsed < 0 || parsed.isNaN || parsed.isInfinite ? fallback : parsed;
  }

  static int safeInt(dynamic v, {int fallback = 0, int max = _kMaxQuantity}) {
    if (v == null) return fallback;
    final parsed = (v as num?)?.toInt() ?? fallback;
    if (parsed < 0) return fallback;
    return parsed > max ? max : parsed;
  }

  static String safeWarranty(dynamic v) {
    if (v == null) return '12 mois';
    if (v is String) {
      final sanitized = sanitize(v, maxLength: _kMaxWarrantyLength);
      return sanitized.isEmpty ? '12 mois' : sanitized;
    }
    if (v is num) return '$v mois';
    return '12 mois';
  }

  static String formatAmount(double amount, String locale) {
    try {
      return NumberFormat.decimalPattern(locale).format(amount.toInt());
    } catch (_) {
      return amount.toInt().toString();
    }
  }
}

// ============================================================================
// LOCALIZATION HELPER
// ============================================================================
extension _CartItemL10n on BuildContext {
  String cartT(String fr, String en) {
    final lang = Localizations.localeOf(this).languageCode;
    return lang == 'fr' ? fr : en;
  }

  String get localeCode => Localizations.localeOf(this).languageCode;
}

// ============================================================================
// WIDGET PRINCIPAL
// ============================================================================
class CartItemTile extends StatefulWidget {
  final Map<String, dynamic> cartItem;
  final double realPrice;
  final double oldPrice;
  final int discountPercent;
  final String currency;
  final Function(int) onQuantityChanged;
  final VoidCallback onRemove;

  const CartItemTile({
    super.key,
    required this.cartItem,
    required this.realPrice,
    required this.oldPrice,
    required this.discountPercent,
    required this.currency,
    required this.onQuantityChanged,
    required this.onRemove,
  });

  @override
  State<CartItemTile> createState() => _CartItemTileState();
}

class _CartItemTileState extends State<CartItemTile> {
  bool _isUpdatingQty = false;

  @override
  Widget build(BuildContext context) {
    // Extraction sécurisée des données
    final product = (widget.cartItem['product'] as Map<String, dynamic>?) ?? {};
    final shop = (product['shop'] as Map<String, dynamic>?) ?? {};

    final rawQty = _CartItemValidators.safeInt(widget.cartItem['quantity'], fallback: 1);
    final stock = _CartItemValidators.safeInt(product['stock'], fallback: 999);
    final maxQty = stock > 0 ? stock.clamp(_kMinQuantity, _kMaxQuantity) : 0;
    final qty = rawQty.clamp(_kMinQuantity, maxQty > 0 ? maxQty : _kMinQuantity);

    final hasDiscount = widget.discountPercent > 0 && widget.realPrice < widget.oldPrice;
    final isOutOfStock = stock <= 0;
    final isLowStock = stock > 0 && stock <= _kLowStockThreshold;

    final title = _CartItemValidators.sanitize(
      product['title']?.toString() ?? product['name']?.toString() ?? context.cartT('Produit', 'Product'),
      maxLength: _kMaxTitleLength,
    );
    final shopName = _CartItemValidators.sanitize(
      shop['name']?.toString() ?? product['shop_name']?.toString() ?? 'ZANDO GLOBAL',
      maxLength: _kMaxShopNameLength,
    );
    final city = _CartItemValidators.sanitize(
      shop['city']?.toString() ?? shop['ville']?.toString() ?? product['city']?.toString() ?? 'Kinshasa',
      maxLength: _kMaxCityLength,
    );
    final warranty = _CartItemValidators.safeWarranty(product['warranty'] ?? product['garantie']);
    final imageUrl = _CartItemValidators.sanitizeUrl(product['image_url']?.toString());

    final realPrice = _CartItemValidators.safeDouble(widget.realPrice);
    final oldPrice = _CartItemValidators.safeDouble(widget.oldPrice);
    final formattedReal = _CartItemValidators.formatAmount(realPrice, context.localeCode);
    final formattedOld = _CartItemValidators.formatAmount(oldPrice, context.localeCode);

    return Semantics(
      label: '${context.cartT("Article", "Item")}: $title, '
          '${context.cartT("Quantité", "Quantity")}: $qty, '
          '${context.cartT("Prix", "Price")}: $formattedReal ${widget.currency}',
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: ThixPolicy.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: ThixPolicy.border.withOpacity(0.6)),
          boxShadow: ThixPolicy.shadowSoft(opacity: 0.03),
        ),
        child: Opacity(
          opacity: isOutOfStock ? 0.6 : 1.0,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ProductImage(
                imageUrl: imageUrl,
                discountPercent: hasDiscount ? widget.discountPercent : 0,
                isOutOfStock: isOutOfStock,
                outOfStockLabel: context.cartT('Rupture', 'Out of stock'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: ThixPolicy.labelStyle.copyWith(
                        fontWeight: ThixPolicy.bold,
                        fontSize: 13.2,
                        color: ThixPolicy.textMain,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 5),
                    _ShopLocationRow(shopName: shopName, city: city),
                    const SizedBox(height: 6),
                    _BadgesRow(
                      stock: stock,
                      isLowStock: isLowStock,
                      isOutOfStock: isOutOfStock,
                      warranty: warranty,
                      inStockLabel: context.cartT('En stock', 'In stock'),
                      stockLabel: context.cartT('Stock', 'Stock'),
                      outOfStockLabel: context.cartT('Indisponible', 'Unavailable'),
                      warrantyPrefix: context.cartT('Garantie', 'Warranty'),
                    ),
                    const SizedBox(height: 8),
                    _PriceRow(
                      realPrice: formattedReal,
                      oldPrice: formattedOld,
                      currency: widget.currency,
                      hasDiscount: hasDiscount,
                    ),
                    const SizedBox(height: 10),
                    _ActionsRow(
                      qty: qty,
                      maxQty: maxQty,
                      isOutOfStock: isOutOfStock,
                      isUpdatingQty: _isUpdatingQty,
                      onDecrement: () => _changeQuantity(qty - 1, maxQty),
                      onIncrement: () => _changeQuantity(qty + 1, maxQty),
                      onRemove: _handleRemove,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _changeQuantity(int newQty, int maxQty) async {
    if (_isUpdatingQty) return;

    if (newQty < _kMinQuantity) {
      HapticFeedback.lightImpact();
      return;
    }

    if (newQty > maxQty) {
      HapticFeedback.lightImpact();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(context.cartT(
                'Stock maximum atteint ($maxQty)',
                'Maximum stock reached ($maxQty)',
              )),
            ),
          ]),
          backgroundColor: ThixPolicy.warning,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    setState(() => _isUpdatingQty = true);
    HapticFeedback.selectionClick();

    try {
      widget.onQuantityChanged(newQty);
      debugPrint('[CartItem] 🔢 Quantity changed to $newQty');
    } catch (e) {
      debugPrint('[CartItem] ❌ Quantity change error: $e');
    } finally {
      if (mounted) {
        // Petit délai pour feedback visuel
        await Future.delayed(const Duration(milliseconds: 150));
        if (mounted) setState(() => _isUpdatingQty = false);
      }
    }
  }

  void _handleRemove() {
    HapticFeedback.mediumImpact();
    debugPrint('[CartItem] 🗑️ Remove requested');
    widget.onRemove();
  }
}

// ============================================================================
// COMPOSANTS RÉUTILISABLES
// ============================================================================

class _ProductImage extends StatelessWidget {
  final String? imageUrl;
  final int discountPercent;
  final bool isOutOfStock;
  final String outOfStockLabel;

  const _ProductImage({
    required this.imageUrl,
    required this.discountPercent,
    required this.isOutOfStock,
    required this.outOfStockLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: imageUrl != null
              ? CachedNetworkImage(
                  imageUrl: imageUrl!,
                  width: 88,
                  height: 88,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(
                    width: 88,
                    height: 88,
                    color: ThixPolicy.surfaceSoft,
                    child: const Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: ThixPolicy.primary,
                        ),
                      ),
                    ),
                  ),
                  errorWidget: (_, __, ___) => Container(
                    width: 88,
                    height: 88,
                    color: ThixPolicy.surfaceSoft,
                    child: const Icon(Icons.image_outlined, color: ThixPolicy.textMuted, size: 32),
                  ),
                )
              : Container(
                  width: 88,
                  height: 88,
                  color: ThixPolicy.surfaceSoft,
                  child: const Icon(Icons.image_outlined, color: ThixPolicy.textMuted, size: 32),
                ),
        ),
        if (discountPercent > 0)
          Positioned(
            top: 6,
            left: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: ThixPolicy.gold,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '-$discountPercent%',
                style: ThixPolicy.microStyle.copyWith(
                  fontSize: 10,
                  fontWeight: ThixPolicy.bold,
                  color: ThixPolicy.danger,
                ),
              ),
            ),
          ),
        if (isOutOfStock)
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Container(
                color: Colors.black.withOpacity(0.5),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: ThixPolicy.danger,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      outOfStockLabel,
                      style: ThixPolicy.microStyle.copyWith(
                        fontSize: 9,
                        fontWeight: ThixPolicy.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _ShopLocationRow extends StatelessWidget {
  final String shopName;
  final String city;

  const _ShopLocationRow({required this.shopName, required this.city});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.storefront_rounded, size: 11, color: ThixPolicy.primary),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            shopName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: ThixPolicy.captionStyle.copyWith(
              fontSize: 11,
              fontWeight: ThixPolicy.bold,
              color: ThixPolicy.textMain,
            ),
          ),
        ),
        const SizedBox(width: 5),
        Text('•', style: ThixPolicy.captionStyle.copyWith(fontSize: 10, color: ThixPolicy.textMuted)),
        const SizedBox(width: 5),
        const Icon(Icons.location_on_outlined, size: 11, color: ThixPolicy.textMuted),
        const SizedBox(width: 2),
        Expanded(
          child: Text(
            city,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: ThixPolicy.captionStyle.copyWith(fontSize: 11, color: ThixPolicy.textMuted),
          ),
        ),
      ],
    );
  }
}

class _BadgesRow extends StatelessWidget {
  final int stock;
  final bool isLowStock;
  final bool isOutOfStock;
  final String warranty;
  final String inStockLabel;
  final String stockLabel;
  final String outOfStockLabel;
  final String warrantyPrefix;

  const _BadgesRow({
    required this.stock,
    required this.isLowStock,
    required this.isOutOfStock,
    required this.warranty,
    required this.inStockLabel,
    required this.stockLabel,
    required this.outOfStockLabel,
    required this.warrantyPrefix,
  });

  @override
  Widget build(BuildContext context) {
    final stockColor = isOutOfStock
        ? ThixPolicy.textMuted
        : isLowStock
            ? ThixPolicy.warning
            : ThixPolicy.success;
    final stockBg = isOutOfStock
        ? ThixPolicy.textMuted.withOpacity(0.1)
        : isLowStock
            ? ThixPolicy.warning.withOpacity(0.1)
            : ThixPolicy.success.withOpacity(0.1);
    final stockIcon = isOutOfStock
        ? Icons.cancel_outlined
        : isLowStock
            ? Icons.warning_amber_rounded
            : Icons.check_circle_rounded;
    final stockText = isOutOfStock
        ? outOfStockLabel
        : isLowStock
            ? '$stockLabel: $stock'
            : inStockLabel;

    return Row(
      children: [
        // Stock badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(
            color: stockBg,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(stockIcon, size: 11, color: stockColor),
              const SizedBox(width: 3),
              Text(
                stockText,
                style: ThixPolicy.microStyle.copyWith(
                  fontSize: 10,
                  fontWeight: ThixPolicy.bold,
                  color: stockColor,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        // Warranty badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(
            color: ThixPolicy.primary.withOpacity(0.08),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: ThixPolicy.primary.withOpacity(0.2)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.verified_user_outlined, size: 11, color: ThixPolicy.primary),
              const SizedBox(width: 3),
              Text(
                '$warrantyPrefix $warranty',
                style: ThixPolicy.microStyle.copyWith(
                  fontSize: 10,
                  fontWeight: ThixPolicy.semiBold,
                  color: ThixPolicy.primary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PriceRow extends StatelessWidget {
  final String realPrice;
  final String oldPrice;
  final String currency;
  final bool hasDiscount;

  const _PriceRow({
    required this.realPrice,
    required this.oldPrice,
    required this.currency,
    required this.hasDiscount,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          '$realPrice $currency',
          style: ThixPolicy.labelStyle.copyWith(
            fontWeight: ThixPolicy.bold,
            fontSize: 15.5,
            color: ThixPolicy.danger,
          ),
        ),
        if (hasDiscount) ...[
          const SizedBox(width: 6),
          Text(
            '$oldPrice $currency',
            style: ThixPolicy.captionStyle.copyWith(
              fontSize: 11.5,
              color: ThixPolicy.textMuted,
              decoration: TextDecoration.lineThrough,
            ),
          ),
        ],
      ],
    );
  }
}

class _ActionsRow extends StatelessWidget {
  final int qty;
  final int maxQty;
  final bool isOutOfStock;
  final bool isUpdatingQty;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;
  final VoidCallback onRemove;

  const _ActionsRow({
    required this.qty,
    required this.maxQty,
    required this.isOutOfStock,
    required this.isUpdatingQty,
    required this.onDecrement,
    required this.onIncrement,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final canDecrement = qty > 1 && !isOutOfStock && !isUpdatingQty;
    final canIncrement = qty < maxQty && !isOutOfStock && !isUpdatingQty;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Quantity selector
        Semantics(
          label: '${context.cartT("Quantité", "Quantity")}: $qty',
          child: Container(
            decoration: BoxDecoration(
              color: ThixPolicy.inkDeep,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Semantics(
                  button: true,
                  label: context.cartT('Diminuer', 'Decrease'),
                  enabled: canDecrement,
                  child: InkWell(
                    onTap: canDecrement ? onDecrement : null,
                    borderRadius: const BorderRadius.horizontal(left: Radius.circular(20)),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      child: Icon(
                        Icons.remove,
                        size: 16,
                        color: canDecrement ? ThixPolicy.gold : Colors.white38,
                      ),
                    ),
                  ),
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 150),
                  child: Text(
                    isUpdatingQty ? '...' : '$qty',
                    key: ValueKey('$qty-$isUpdatingQty'),
                    style: ThixPolicy.labelStyle.copyWith(
                      color: Colors.white,
                      fontWeight: ThixPolicy.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
                Semantics(
                  button: true,
                  label: context.cartT('Augmenter', 'Increase'),
                  enabled: canIncrement,
                  child: InkWell(
                    onTap: canIncrement ? onIncrement : null,
                    borderRadius: const BorderRadius.horizontal(right: Radius.circular(20)),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      child: Icon(
                        Icons.add,
                        size: 16,
                        color: canIncrement ? ThixPolicy.gold : Colors.white38,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Remove button
        Semantics(
          button: true,
          label: context.cartT('Supprimer', 'Remove'),
          child: InkWell(
            onTap: isOutOfStock || isUpdatingQty ? null : onRemove,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: ThixPolicy.danger.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.delete_outline_rounded, size: 17, color: ThixPolicy.danger),
            ),
          ),
        ),
      ],
    );
  }
}
