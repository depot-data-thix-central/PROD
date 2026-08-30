// lib/presentation/thix_market/cart/cart_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:html/parser.dart' as html_parser;

import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'cart_provider.dart';
import 'cart_summary_widget.dart';
import 'cart_item_tile.dart';

// ============================================================================
// VALIDATEURS
// ============================================================================
class _CartPageValidators {
  _CartPageValidators._();

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

  static String friendlyError(dynamic e) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('timeout')) return 'Délai dépassé. Vérifiez votre connexion.';
    if (msg.contains('network') || msg.contains('socket')) return 'Erreur réseau. Réessayez.';
    if (msg.contains('permission') || msg.contains('policy')) return 'Accès non autorisé.';
    if (msg.contains('stock')) return e.toString();
    return 'Une erreur est survenue. Réessayez.';
  }
}

// ============================================================================
// LOCALIZATION HELPER
// ============================================================================
extension _CartPageL10n on BuildContext {
  String cartPgT(String fr, String en) {
    final lang = Localizations.localeOf(this).languageCode;
    return lang == 'fr' ? fr : en;
  }

  String get localeCode => Localizations.localeOf(this).languageCode;
}

// ============================================================================
// PAGE PRINCIPALE
// ============================================================================
class CartPage extends ConsumerStatefulWidget {
  const CartPage({super.key});

  @override
  ConsumerState<CartPage> createState() => _CartPageState();
}

class _CartPageState extends ConsumerState<CartPage> {
  bool _isClearing = false;

  @override
  void initState() {
    super.initState();
    debugPrint('[CartPage] 🛒 Page opened');
  }

  @override
  void dispose() {
    debugPrint('[CartPage] 👋 Page disposed');
    super.dispose();
  }

  // ============================================================
  // ACTIONS
  // ============================================================
  Future<void> _confirmClearCart() async {
    if (_isClearing) return;

    HapticFeedback.mediumImpact();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rLg)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: ThixPolicy.danger.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.delete_sweep_rounded, color: ThixPolicy.danger, size: 20),
            ),
            const SizedBox(width: 10),
            Text(
              context.cartPgT('Vider le panier ?', 'Empty cart?'),
              style: ThixPolicy.h3Style.copyWith(fontWeight: ThixPolicy.bold, fontSize: 16),
            ),
          ],
        ),
        content: Text(
          context.cartPgT(
            'Tous les articles seront supprimés. Cette action est irréversible.',
            'All items will be removed. This action is irreversible.',
          ),
          style: ThixPolicy.bodyStyle,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              context.cartPgT('Annuler', 'Cancel'),
              style: ThixPolicy.labelStyle.copyWith(color: ThixPolicy.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: ThixPolicy.danger,
              foregroundColor: Colors.white,
            ),
            child: Text(context.cartPgT('Vider', 'Empty')),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isClearing = true);

    try {
      final cart = ref.read(cartProvider.notifier);
      await cart.clearCart();
      debugPrint('[CartPage] 🗑️ Cart cleared');
      if (mounted) {
        _showSuccess(context.cartPgT('Panier vidé', 'Cart emptied'));
      }
    } catch (e) {
      debugPrint('[CartPage] ❌ Clear cart error: $e');
      if (mounted) {
        _showError(_CartPageValidators.friendlyError(e));
      }
    } finally {
      if (mounted) setState(() => _isClearing = false);
    }
  }

  void _onQuantityChanged(String cartRowId, int newQty, int stock) {
    HapticFeedback.selectionClick();
    final cart = ref.read(cartProvider.notifier);

    if (newQty <= 0) {
      HapticFeedback.mediumImpact();
      cart.removeFromCart(cartRowId);
      debugPrint('[CartPage] 🗑️ Item removed via qty=0: $cartRowId');
      return;
    }

    if (newQty > stock) {
      HapticFeedback.lightImpact();
      _showError(context.cartPgT('Stock limité à $stock', 'Stock limited to $stock'));
      return;
    }

    cart.updateQuantity(cartRowId, newQty).catchError((e) {
      debugPrint('[CartPage] ❌ Update quantity error: $e');
      if (mounted) {
        _showError(_CartPageValidators.friendlyError(e));
      }
    });
    debugPrint('[CartPage] 🔢 Qty updated: $cartRowId → $newQty');
  }

  void _onRemoveItem(String cartRowId) {
    HapticFeedback.mediumImpact();
    ref.read(cartProvider.notifier).removeFromCart(cartRowId);
    debugPrint('[CartPage] 🗑️ Item removed: $cartRowId');
  }

  void _navigateToShop() {
    HapticFeedback.mediumImpact();
    context.push('/market/buy');
    debugPrint('[CartPage] 🛍️ Navigate to shop');
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          const Icon(Icons.error_outline_rounded, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(message)),
        ]),
        backgroundColor: ThixPolicy.danger,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(message)),
        ]),
        backgroundColor: ThixPolicy.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================
  @override
  Widget build(BuildContext context) {
    final cartState = ref.watch(cartProvider);
    final cart = ref.read(cartProvider.notifier);

    final hasOutOfStock = cart.hasOutOfStockItems;
    final hasMixed = cart.hasMixedCurrency;
    final blocked = hasOutOfStock || hasMixed;
    final totalQty = cart.totalQuantity;

    return Scaffold(
      backgroundColor: ThixPolicy.surfaceSoft,
      appBar: AppBar(
        backgroundColor: ThixPolicy.card,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: Semantics(
          button: true,
          label: context.cartPgT('Retour', 'Back'),
          child: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: ThixPolicy.textMain),
            tooltip: context.cartPgT('Retour', 'Back'),
            onPressed: () {
              HapticFeedback.selectionClick();
              context.pop();
            },
          ),
        ),
        title: Text(
          context.cartPgT('Mon panier ($totalQty)', 'My cart ($totalQty)'),
          style: ThixPolicy.h3Style.copyWith(
            fontWeight: ThixPolicy.bold,
            color: ThixPolicy.textMain,
            fontSize: 18,
          ),
        ),
        actions: [
          if (cartState.items.isNotEmpty)
            Semantics(
              button: true,
              label: context.cartPgT('Vider le panier', 'Empty cart'),
              enabled: !_isClearing,
              child: TextButton.icon(
                onPressed: _isClearing ? null : _confirmClearCart,
                icon: _isClearing
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: ThixPolicy.danger),
                      )
                    : const Icon(Icons.delete_sweep_rounded, size: 16, color: ThixPolicy.danger),
                label: Text(
                  context.cartPgT('Vider', 'Empty'),
                  style: ThixPolicy.labelStyle.copyWith(
                    color: _isClearing ? ThixPolicy.textDisabled : ThixPolicy.danger,
                    fontWeight: ThixPolicy.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: _buildBody(cartState, cart, hasOutOfStock, hasMixed, blocked),
    );
  }

  Widget _buildBody(
    CartState cartState,
    CartNotifier cart,
    bool hasOutOfStock,
    bool hasMixed,
    bool blocked,
  ) {
    if (cartState.isLoading) {
      return const _SkeletonCart();
    }

    if (cartState.items.isEmpty) {
      return _EmptyCart(
        title: context.cartPgT('Votre panier est vide', 'Your cart is empty'),
        subtitle: context.cartPgT('Ajoutez des produits pour continuer', 'Add products to continue'),
        buttonLabel: context.cartPgT('Découvrir', 'Discover'),
        onShopPressed: _navigateToShop,
      );
    }

    return Column(
      children: [
        // Alerte multi-devises
        if (hasMixed)
          _AlertBanner(
            icon: Icons.currency_exchange_rounded,
            color: ThixPolicy.warning,
            message: context.cartPgT(
              'Votre panier contient des devises différentes (USD et FC). '
              'Retirez les articles d\'une devise pour continuer.',
              'Your cart contains different currencies (USD and FC). '
              'Remove items from one currency to continue.',
            ),
          ),

        // Alerte rupture de stock
        if (hasOutOfStock)
          _AlertBanner(
            icon: Icons.warning_amber_rounded,
            color: ThixPolicy.danger,
            message: context.cartPgT(
              'Certains articles sont en rupture de stock. Retirez-les pour continuer.',
              'Some items are out of stock. Remove them to continue.',
            ),
          ),

        // Liste articles
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: cartState.items.length,
            itemBuilder: (context, index) {
              final cartItem = cartState.items[index];
              final product = (cartItem['product'] as Map<String, dynamic>?) ?? {};
              final realPrice = cart.getItemRealPrice(cartItem);
              final oldPrice = cart.getItemOldPrice(cartItem);
              final discount = cart.getItemDiscountPercent(cartItem);
              final cur = cart.currencyForItem(cartItem);
              final cartRowId = cartItem['id']?.toString() ?? '';
              final stock = (product['stock'] as num?)?.toInt() ?? 0;
              final isOut = stock <= 0;

              return Opacity(
                opacity: isOut ? 0.55 : 1.0,
                child: CartItemTile(
                  cartItem: cartItem,
                  realPrice: realPrice,
                  oldPrice: oldPrice,
                  discountPercent: discount,
                  currency: cur,
                  onQuantityChanged: (newQty) => _onQuantityChanged(cartRowId, newQty, stock),
                  onRemove: () => _onRemoveItem(cartRowId),
                ),
              );
            },
          ),
        ),

        // Résumé
        if (hasMixed)
          _MixedCurrencySummary(
            subtotals: cart.subtotalsByCurrency,
            titleLabel: context.cartPgT('Totaux par devise', 'Totals by currency'),
            warningLabel: context.cartPgT(
              'Retirez une devise pour valider la commande.',
              'Remove one currency to validate the order.',
            ),
            buttonLabel: context.cartPgT(
              'Devises mixtes — impossible de continuer',
              'Mixed currencies — cannot continue',
            ),
            locale: context.localeCode,
          )
        else
          IgnorePointer(
            ignoring: blocked,
            child: Opacity(
              opacity: blocked ? 0.5 : 1.0,
              child: CartSummaryWidget(
                subtotal: cart.subtotal,
                originalSubtotal: cart.originalSubtotal,
                discount: cart.totalDiscount,
                shippingCost: cart.shippingCost,
                total: cart.total,
                itemCount: cart.totalQuantity,
                currency: cart.currencySymbol,
              ),
            ),
          ),
      ],
    );
  }
}

// ============================================================================
// COMPOSANTS RÉUTILISABLES
// ============================================================================

class _AlertBanner extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String message;

  const _AlertBanner({
    required this.icon,
    required this.color,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Alerte: $message',
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOut,
        builder: (context, value, child) {
          return Transform.translate(
            offset: Offset(0, (1 - value) * -20),
            child: Opacity(
              opacity: value,
              child: child,
            ),
          );
        },
        child: Container(
          width: double.infinity,
          margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: ThixPolicy.bodySmallStyle.copyWith(
                    color: color,
                    fontWeight: ThixPolicy.semiBold,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MixedCurrencySummary extends StatelessWidget {
  final Map<String, double> subtotals;
  final String titleLabel;
  final String warningLabel;
  final String buttonLabel;
  final String locale;

  const _MixedCurrencySummary({
    required this.subtotals,
    required this.titleLabel,
    required this.warningLabel,
    required this.buttonLabel,
    required this.locale,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        color: ThixPolicy.card,
        boxShadow: ThixPolicy.shadowSoft(opacity: 0.06),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              titleLabel,
              style: ThixPolicy.labelStyle.copyWith(
                fontWeight: ThixPolicy.bold,
                fontSize: 14,
                color: ThixPolicy.textMain,
              ),
            ),
            const SizedBox(height: 10),
            ...subtotals.entries.map((e) {
              final symbol = e.key == 'USD' ? '\$' : 'FC';
              final isUSD = e.key == 'USD';
              final formatted = _CartPageValidators.formatAmount(e.value, locale, isUSD: isUSD);

              return Semantics(
                label: 'Sous-total $symbol: $formatted',
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Sous-total ($symbol)',
                        style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.textMuted),
                      ),
                      Text(
                        '$formatted $symbol',
                        style: ThixPolicy.labelStyle.copyWith(
                          fontWeight: ThixPolicy.bold,
                          fontSize: 16,
                          color: ThixPolicy.textMain,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.info_outline_rounded, size: 14, color: ThixPolicy.warning),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    warningLabel,
                    style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.warning, fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Semantics(
              button: true,
              label: buttonLabel,
              enabled: false,
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: null,
                  style: ElevatedButton.styleFrom(
                    disabledBackgroundColor: ThixPolicy.border.withOpacity(0.5),
                    disabledForegroundColor: ThixPolicy.textDisabled,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text(
                    buttonLabel,
                    style: ThixPolicy.labelStyle.copyWith(fontWeight: ThixPolicy.semiBold),
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

class _EmptyCart extends StatelessWidget {
  final String title;
  final String subtitle;
  final String buttonLabel;
  final VoidCallback onShopPressed;

  const _EmptyCart({
    required this.title,
    required this.subtitle,
    required this.buttonLabel,
    required this.onShopPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: ThixPolicy.primary.withOpacity(0.08),
                shape: BoxShape.circle,
                boxShadow: ThixPolicy.shadowSoft(opacity: 0.05),
              ),
              child: const Icon(
                Icons.shopping_cart_outlined,
                size: 56,
                color: ThixPolicy.textMuted,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: ThixPolicy.h3Style.copyWith(
                fontSize: 18,
                fontWeight: ThixPolicy.bold,
                color: ThixPolicy.textMain,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: ThixPolicy.bodySmallStyle.copyWith(color: ThixPolicy.textMuted, fontSize: 14),
            ),
            const SizedBox(height: 28),
            Semantics(
              button: true,
              label: buttonLabel,
              child: SizedBox(
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: onShopPressed,
                  icon: const Icon(Icons.storefront_rounded, color: Colors.white, size: 18),
                  label: Text(
                    buttonLabel,
                    style: ThixPolicy.labelStyle.copyWith(
                      fontWeight: ThixPolicy.bold,
                      fontSize: 15,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ThixPolicy.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    elevation: 0,
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

class _SkeletonCart extends StatelessWidget {
  const _SkeletonCart();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 3,
      itemBuilder: (_, __) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: ThixPolicy.card,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(height: 14, width: double.infinity, color: Colors.grey.shade200),
                  const SizedBox(height: 6),
                  Container(height: 10, width: 140, color: Colors.grey.shade200),
                  const SizedBox(height: 8),
                  Container(height: 16, width: 100, color: Colors.grey.shade200),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        width: 100,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
