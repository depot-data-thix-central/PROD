// lib/presentation/thix_market/cart/cart_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'cart_provider.dart';
import 'cart_summary_widget.dart';
import 'cart_item_tile.dart';

class CartPage extends ConsumerWidget {
  const CartPage({super.key});
  static const navy = Color(0xFF0A1931);
  static const bg = Color(0xFFF7F8FC);
  static const red = Color(0xFFD81E2C);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cartState = ref.watch(cartProvider);
    final cart = ref.read(cartProvider.notifier);
    final hasOutOfStock = cart.hasOutOfStockItems;
    final hasMixed = cart.hasMixedCurrency;
    final blocked = hasOutOfStock || hasMixed;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              size: 18, color: navy),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Mon panier (${cart.totalQuantity})',
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            color: navy,
            fontSize: 18,
          ),
        ),
        actions: [
          if (cartState.items.isNotEmpty)
            TextButton(
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    title: const Text(
                      'Vider le panier?',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    content:
                        const Text('Tous les articles seront supprimés.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Annuler'),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: red,
                        ),
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text(
                          'Vider',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                );
                if (ok == true) cart.clearCart();
              },
              child: const Text(
                'Vider',
                style: TextStyle(
                  color: red,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
      body: cartState.isLoading
          ? const Center(child: CircularProgressIndicator(color: navy))
          : cartState.items.isEmpty
              ? _buildEmptyCart(context)
              : Column(
                  children: [
                    // ===== ALERTE MULTI-DEVISES =====
                    if (hasMixed)
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.orange.withOpacity(0.4),
                          ),
                        ),
                        child: const Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.currency_exchange_rounded,
                                color: Colors.orange, size: 20),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Votre panier contient des devises différentes (USD et FC). '
                                'Retirez les articles d\'une devise pour continuer.',
                                style: TextStyle(
                                  color: Color(0xFF9A5B00),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // ===== ALERTE RUPTURE DE STOCK =====
                    if (hasOutOfStock)
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: red.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: red.withOpacity(0.3)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.warning_amber_rounded,
                                color: red, size: 20),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Certains articles sont en rupture de stock. Retirez-les pour continuer.',
                                style: TextStyle(
                                  color: red,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                        itemCount: cartState.items.length,
                        itemBuilder: (context, index) {
                          final cartItem = cartState.items[index];
                          final product =
                              (cartItem['product'] as Map<String, dynamic>?) ??
                                  {};
                          final realPrice = cart.getItemRealPrice(cartItem);
                          final oldPrice = cart.getItemOldPrice(cartItem);
                          final discount =
                              cart.getItemDiscountPercent(cartItem);
                          final cur = cart.currencyForItem(cartItem);
                          final cartRowId = cartItem['id'].toString();
                          final stock =
                              (product['stock'] as num?)?.toInt() ?? 0;
                          final isOut = stock <= 0;

                          return Opacity(
                            opacity: isOut ? 0.55 : 1.0,
                            child: CartItemTile(
                              cartItem: cartItem,
                              realPrice: realPrice,
                              oldPrice: oldPrice,
                              discountPercent: discount,
                              currency: cur,
                              onQuantityChanged: (newQty) {
                                if (newQty <= 0) {
                                  cart.removeFromCart(cartRowId);
                                } else {
                                  if (newQty > stock) {
                                    ScaffoldMessenger.of(context)
                                        .showSnackBar(
                                      SnackBar(
                                        content:
                                            Text('Stock limité à $stock'),
                                        backgroundColor: red,
                                      ),
                                    );
                                    return;
                                  }
                                  cart
                                      .updateQuantity(cartRowId, newQty)
                                      .catchError((e) {
                                    ScaffoldMessenger.of(context)
                                        .showSnackBar(
                                      SnackBar(
                                        content: Text('$e'),
                                        backgroundColor: red,
                                      ),
                                    );
                                  });
                                }
                              },
                              onRemove: () =>
                                  cart.removeFromCart(cartRowId),
                            ),
                          );
                        },
                      ),
                    ),

                    // ===== RÉSUMÉ =====
                    // Multi-devise → afficher totaux séparés + bloquer checkout
                    if (hasMixed)
                      _mixedCurrencySummary(cart)
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
                ),
    );
  }

  /// Totaux séparés quand devises mélangées
  Widget _mixedCurrencySummary(CartNotifier cart) {
    final byCur = cart.subtotalsByCurrency;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Totaux par devise',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 14,
                color: navy,
              ),
            ),
            const SizedBox(height: 10),
            ...byCur.entries.map((e) {
              final symbol = e.key == 'USD' ? '\$' : 'FC';
              final val = e.key == 'USD'
                  ? e.value.toStringAsFixed(2)
                  : e.value.toInt().toString();
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Sous-total ($symbol)',
                        style: const TextStyle(color: Color(0xFF6B7280))),
                    Text(
                      '$val $symbol',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        color: navy,
                      ),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 8),
            const Text(
              'Retirez une devise pour valider la commande.',
              style: TextStyle(fontSize: 12, color: Colors.orange),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: null,
                style: ElevatedButton.styleFrom(
                  disabledBackgroundColor: Colors.grey.shade300,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'Devises mixtes — impossible de continuer',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyCart(BuildContext context) {
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
                color: const Color(0xFFEFF5FF),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 16,
                  ),
                ],
              ),
              child: const Icon(
                Icons.shopping_cart_outlined,
                size: 56,
                color: Color(0xFF7386A8),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Votre panier est vide',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: navy,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Ajoutez des produits pour continuer',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
            ),
            const SizedBox(height: 28),
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: () => context.push('/market/buy'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: red,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 36),
                  elevation: 0,
                ),
                child: const Text(
                  'Découvrir',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
