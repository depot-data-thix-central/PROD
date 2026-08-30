// lib/presentation/thix_market/cart/cart_summary_widget.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:thix_id/features/auth/presentation/providers/auth_controller.dart';

import 'package:thix_id/core/theme/thix_design_policy.dart';

// ============================================================================
// VALIDATEURS
// ============================================================================
class _CartSummaryValidators {
  _CartSummaryValidators._();

  static double safeDouble(dynamic v, {double fallback = 0.0}) {
    if (v == null) return fallback;
    final parsed = (v as num?)?.toDouble() ?? fallback;
    if (parsed < 0 || parsed.isNaN || parsed.isInfinite) return fallback;
    return parsed;
  }

  static int safeInt(dynamic v, {int fallback = 0}) {
    if (v == null) return fallback;
    final parsed = (v as num?)?.toInt() ?? fallback;
    return parsed < 0 ? fallback : parsed;
  }

  static String safeCurrency(String? currency) {
    if (currency == null || currency.trim().isEmpty) return 'FC';
    final cleaned = currency.replaceAll(RegExp(r'[<>"\']'), '').trim();
    return cleaned.isEmpty ? 'FC' : cleaned;
  }

  static String formatAmount(double amount, String locale, {bool isUSD = false}) {
    try {
      if (isUSD) {
        return NumberFormat.decimalPatternDigits(
          locale: locale,
          decimalDigits: 2,
        ).format(amount);
      }
      return NumberFormat.decimalPattern(locale).format(amount.toInt());
    } catch (_) {
      return isUSD ? amount.toStringAsFixed(2) : amount.toInt().toString();
    }
  }

  static bool isUSD(String currency) {
    final upper = currency.toUpperCase().trim();
    return upper == 'USD' || upper == '\$' || upper == 'DOLLAR';
  }
}

// ============================================================================
// LOCALIZATION HELPER
// ============================================================================
extension _CartSummaryL10n on BuildContext {
  String sumW(String fr, String en) {
    final lang = Localizations.localeOf(this).languageCode;
    return lang == 'fr' ? fr : en;
  }

  String get localeCode => Localizations.localeOf(this).languageCode;
}

// ============================================================================
// WIDGET PRINCIPAL
// ============================================================================
class CartSummaryWidget extends ConsumerStatefulWidget {
  final double subtotal;
  final double originalSubtotal;
  final double discount;
  final double shippingCost;
  final double total;
  final int itemCount;
  final String currency;

  const CartSummaryWidget({
    super.key,
    required this.subtotal,
    required this.originalSubtotal,
    required this.discount,
    required this.shippingCost,
    required this.total,
    required this.itemCount,
    required this.currency,
  });

  @override
  ConsumerState<CartSummaryWidget> createState() => _CartSummaryWidgetState();
}

class _CartSummaryWidgetState extends ConsumerState<CartSummaryWidget> {
  bool _isNavigating = false;

  @override
  Widget build(BuildContext context) {
    // Validation des valeurs
    final subtotal = _CartSummaryValidators.safeDouble(widget.subtotal);
    final originalSubtotal = _CartSummaryValidators.safeDouble(widget.originalSubtotal);
    final discount = _CartSummaryValidators.safeDouble(widget.discount);
    final shippingCost = _CartSummaryValidators.safeDouble(widget.shippingCost);
    final total = _CartSummaryValidators.safeDouble(widget.total);
    final itemCount = _CartSummaryValidators.safeInt(widget.itemCount);
    final currency = _CartSummaryValidators.safeCurrency(widget.currency);

    final hasDiscount = discount > 0.5;
    final isUSD = _CartSummaryValidators.isUSD(currency);
    final locale = context.localeCode;

    // Formatage i18n
    final formattedSubtotal = _CartSummaryValidators.formatAmount(
      hasDiscount ? originalSubtotal : subtotal,
      locale,
      isUSD: isUSD,
    );
    final formattedDiscount = _CartSummaryValidators.formatAmount(discount, locale, isUSD: isUSD);
    final formattedShipping = shippingCost == 0
        ? '0 $currency'
        : '${_CartSummaryValidators.formatAmount(shippingCost, locale, isUSD: isUSD)} $currency';
    final formattedTotal = _CartSummaryValidators.formatAmount(total, locale, isUSD: isUSD);

    final authState = ref.watch(authControllerProvider);
    final isLoggedIn = authState.valueOrNull != null;

    final subtotalLabel = context.sumW(
      'Sous-total ($itemCount ${itemCount > 1 ? 'articles' : 'article'})',
      'Subtotal ($itemCount ${itemCount > 1 ? 'items' : 'item'})',
    );
    final discountLabel = context.sumW('Remise', 'Discount');
    final shippingLabel = context.sumW('Livraison', 'Shipping');
    const shippingBadgeLabel = 'À confirmer';
    final totalLabel = context.sumW('Total', 'Total');
    final buttonLabel = context.sumW('Continuer vers la validation', 'Continue to checkout');

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: ThixPolicy.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: ThixPolicy.shadowSoft(opacity: 0.08),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle drag
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: ThixPolicy.border,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 16),

            // Sous-total
            _SummaryRow(
              label: subtotalLabel,
              value: '$formattedSubtotal $currency',
              valueColor: ThixPolicy.textMain,
              isTotal: false,
            ),

            if (hasDiscount) ...[
              const SizedBox(height: 6),
              _SummaryRow(
                label: discountLabel,
                value: '-$formattedDiscount $currency',
                valueColor: ThixPolicy.success,
                icon: Icons.local_offer_outlined,
                iconColor: ThixPolicy.success,
              ),
            ],

            const SizedBox(height: 6),

            // Livraison
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Semantics(
                  label: '$shippingLabel: $shippingBadgeLabel',
                  child: Row(
                    children: [
                      Text(
                        shippingLabel,
                        style: ThixPolicy.bodyStyle.copyWith(
                          fontSize: 14,
                          fontWeight: ThixPolicy.regular,
                          color: ThixPolicy.textMuted,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: ThixPolicy.gold.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          shippingBadgeLabel,
                          style: ThixPolicy.microStyle.copyWith(
                            fontSize: 9,
                            fontWeight: ThixPolicy.bold,
                            color: ThixPolicy.gold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  formattedShipping,
                  style: ThixPolicy.labelStyle.copyWith(
                    fontSize: 14,
                    fontWeight: ThixPolicy.semiBold,
                    color: ThixPolicy.textMain,
                  ),
                ),
              ],
            ),

            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Divider(height: 1, color: ThixPolicy.border.withOpacity(0.6)),
            ),

            // Total
            _SummaryRow(
              label: totalLabel,
              value: '$formattedTotal $currency',
              isTotal: true,
            ),

            const SizedBox(height: 16),

            // Bouton Checkout
            Semantics(
              button: true,
              label: buttonLabel,
              enabled: !_isNavigating,
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _isNavigating ? null : () => _checkout(isLoggedIn),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ThixPolicy.primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: ThixPolicy.primary.withOpacity(0.5),
                    disabledForegroundColor: Colors.white70,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: _isNavigating
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              buttonLabel,
                              style: ThixPolicy.titleStyle.copyWith(
                                fontWeight: ThixPolicy.bold,
                                fontSize: 15.5,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 18),
                          ],
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _checkout(bool isLoggedIn) async {
    if (_isNavigating) return;

    HapticFeedback.mediumImpact();
    setState(() => _isNavigating = true);

    try {
      if (!isLoggedIn) {
        debugPrint('[CartSummary] 🔐 Redirect to login (user not authenticated)');
        if (!mounted) return;
        await context.push('/login');
      } else {
        debugPrint('[CartSummary] 🛒 Navigate to checkout');
        if (!mounted) return;
        await context.push('/market/checkout');
      }
    } catch (e) {
      debugPrint('[CartSummary] ❌ Navigation error: $e');
    } finally {
      if (mounted) {
        setState(() => _isNavigating = false);
      }
    }
  }
}

// ============================================================================
// COMPOSANTS RÉUTILISABLES
// ============================================================================

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isTotal;
  final Color? valueColor;
  final IconData? icon;
  final Color? iconColor;

  const _SummaryRow({
    required this.label,
    required this.value,
    this.isTotal = false,
    this.valueColor,
    this.icon,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final finalValueColor = valueColor ?? (isTotal ? ThixPolicy.primary : ThixPolicy.textMain);

    return Semantics(
      label: '$label: $value',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 14, color: iconColor ?? finalValueColor),
                    const SizedBox(width: 4),
                  ],
                  Flexible(
                    child: Text(
                      label,
                      style: ThixPolicy.bodyStyle.copyWith(
                        fontSize: isTotal ? 16 : 14,
                        fontWeight: isTotal ? ThixPolicy.bold : ThixPolicy.regular,
                        color: ThixPolicy.textMain,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              value,
              style: ThixPolicy.labelStyle.copyWith(
                fontSize: isTotal ? 19 : 14.5,
                fontWeight: isTotal ? ThixPolicy.bold : ThixPolicy.semiBold,
                color: finalValueColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
