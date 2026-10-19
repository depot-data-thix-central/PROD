// lib/presentation/thix_market/cart/cart_summary_widget.dart
// ============================================================================
// CART SUMMARY WIDGET — Production Enterprise v5
// ----------------------------------------------------------------------------
//  • ✅ Support de la conversion de devises automatique
//  • ✅ Indicateur visuel 💱 si prix convertis
//  • ✅ Support 54 devises africaines via AfricanCurrencies
//  • ✅ Support FR / EN / SW via Localizations
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:thix_id/features/auth/presentation/providers/auth_controller.dart';

import 'package:thix_id/core/theme/thix_design_policy.dart';
import '../core/african_currencies.dart';
import '../core/currency_service.dart';
import '../providers/currency_provider.dart';

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
    if (currency == null || currency.trim().isEmpty) return 'CDF';
    final cleaned = currency.replaceAll(RegExp('[<>"\']'), '').trim();
    return cleaned.isEmpty ? 'CDF' : cleaned;
  }
}

// ============================================================================
// LOCALIZATION HELPER
// ============================================================================
extension _CartSummaryL10n on BuildContext {
  String sumW(String fr, String en, [String? sw]) {
    final lang = Localizations.localeOf(this).languageCode;
    if (lang == 'sw' && sw != null) return sw;
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
  final String currency; // ✅ Code ISO-4217 (CDF, USD, XOF, etc.)
  final bool isConverted; // ✅ Indique si les prix ont été convertis

  const CartSummaryWidget({
    super.key,
    required this.subtotal,
    required this.originalSubtotal,
    required this.discount,
    required this.shippingCost,
    required this.total,
    required this.itemCount,
    required this.currency,
    this.isConverted = false,
  });

  @override
  ConsumerState<CartSummaryWidget> createState() => _CartSummaryWidgetState();
}

class _CartSummaryWidgetState extends ConsumerState<CartSummaryWidget> {
  bool _isNavigating = false;

  @override
  Widget build(BuildContext context) {
    final lang = Localizations.localeOf(context).languageCode;
    
    // ✅ Écouter le provider de devise pour rebuild si changement
    ref.watch(currencyProvider);
    
    // Validation des valeurs
    final subtotal = _CartSummaryValidators.safeDouble(widget.subtotal);
    final originalSubtotal = _CartSummaryValidators.safeDouble(widget.originalSubtotal);
    final discount = _CartSummaryValidators.safeDouble(widget.discount);
    final shippingCost = _CartSummaryValidators.safeDouble(widget.shippingCost);
    final total = _CartSummaryValidators.safeDouble(widget.total);
    final itemCount = _CartSummaryValidators.safeInt(widget.itemCount);
    
    // ✅ Code devise normalisé (ISO-4217)
    final currencyCode = _CartSummaryValidators.safeCurrency(widget.currency);
    final currencyInfo = AfricanCurrencies.byCode(currencyCode);
    final currencySymbol = currencyInfo?.symbol ?? currencyCode;

    final hasDiscount = discount > 0.5;
    final currencyService = CurrencyService.instance;

    // ✅ Formatage intelligent avec CurrencyService
    final formattedSubtotal = currencyService.formatPrice(
      hasDiscount ? originalSubtotal : subtotal,
      currencyCode: currencyCode,
      lang: lang,
    );
    final formattedDiscount = currencyService.formatPrice(
      discount,
      currencyCode: currencyCode,
      lang: lang,
    );
    final formattedShipping = shippingCost == 0
        ? currencyService.formatPrice(0, currencyCode: currencyCode, lang: lang)
        : currencyService.formatPrice(shippingCost, currencyCode: currencyCode, lang: lang);
    final formattedTotal = currencyService.formatPrice(
      total,
      currencyCode: currencyCode,
      lang: lang,
    );

    final authState = ref.watch(authControllerProvider);
    final isLoggedIn = authState.valueOrNull != null;

    // Labels traduits (FR / EN / SW)
    final subtotalLabel = context.sumW(
      'Sous-total ($itemCount ${itemCount > 1 ? 'articles' : 'article'})',
      'Subtotal ($itemCount ${itemCount > 1 ? 'items' : 'item'})',
      'Jumla ndogo ($itemCount ${itemCount > 1 ? 'bidhaa' : 'bidhaa'})',
    );
    final discountLabel = context.sumW('Remise', 'Discount', 'Punguzo');
    final shippingLabel = context.sumW('Livraison', 'Shipping', 'Usafirishaji');
    final shippingBadgeLabel = context.sumW('À confirmer', 'To confirm', 'Ithibitishwe');
    final totalLabel = context.sumW('Total', 'Total', 'Jumla');
    final buttonLabel = context.sumW(
      'Continuer vers la validation',
      'Continue to checkout',
      'Endelea kulipa',
    );

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

            // ✅ Indicateur de conversion (si applicable)
            if (widget.isConverted)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: ThixPolicy.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: ThixPolicy.primary.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.currency_exchange_rounded, size: 16, color: ThixPolicy.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        context.sumW(
                          'Prix convertis en ${currencyInfo?.displayName(lang) ?? currencyCode}',
                          'Prices converted to ${currencyInfo?.displayName(lang) ?? currencyCode}',
                          'Bei zimebadilishwa kuwa ${currencyInfo?.displayName(lang) ?? currencyCode}',
                        ),
                        style: ThixPolicy.captionStyle.copyWith(
                          color: ThixPolicy.primary,
                          fontWeight: ThixPolicy.semiBold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Sous-total
            _SummaryRow(
              label: subtotalLabel,
              value: formattedSubtotal,
              valueColor: ThixPolicy.textMain,
              isTotal: false,
            ),

            if (hasDiscount) ...[
              const SizedBox(height: 6),
              _SummaryRow(
                label: discountLabel,
                value: '-$formattedDiscount',
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
              value: formattedTotal,
              isTotal: true,
              showConversionIcon: widget.isConverted,
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
  final bool showConversionIcon; // ✅ Indicateur de conversion

  const _SummaryRow({
    required this.label,
    required this.value,
    this.isTotal = false,
    this.valueColor,
    this.icon,
    this.iconColor,
    this.showConversionIcon = false,
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
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: ThixPolicy.labelStyle.copyWith(
                    fontSize: isTotal ? 19 : 14.5,
                    fontWeight: isTotal ? ThixPolicy.bold : ThixPolicy.semiBold,
                    color: finalValueColor,
                  ),
                ),
                // ✅ Indicateur de conversion sur le total
                if (showConversionIcon && isTotal) ...[
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    decoration: BoxDecoration(
                      color: ThixPolicy.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Icon(
                      Icons.currency_exchange_rounded,
                      size: 12,
                      color: ThixPolicy.primary,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
