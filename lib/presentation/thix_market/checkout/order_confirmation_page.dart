// lib/presentation/thix_market/checkout/order_confirmation_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'checkout_provider.dart';

class OrderConfirmationPage extends ConsumerWidget {
  final Map<String, dynamic> order;
  final String? currencySymbol;

  const OrderConfirmationPage({
    super.key,
    required this.order,
    this.currencySymbol,
  });

  static const thixOrange = Color(0xFFE5592F);
  static const pureWhite = Color(0xFFFFFFFF);
  static const darkText = Color(0xFF10192E);
  static const mutedText = Color(0xFF7386A8);
  static const success = Color(0xFF2ECC71);
  static const lightBg = Color(0xFFF7F8FC);

  String _t(BuildContext context, String fr, String en) {
    final lang = Localizations.localeOf(context).languageCode;
    return lang == 'fr' ? fr : en;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final symbol = currencySymbol ?? 'FC';
    final total = (order['total'] as num?)?.toInt() ?? 0;
    final orderId = order['id']?.toString() ?? 'N/A';
    final shortId = orderId.length > 8 ? orderId.substring(0, 8).toUpperCase() : orderId;
    final shippingMethod = order['shipping_method']?.toString() ?? 'Standard';
    final paymentStatus = order['payment_status']?.toString() ?? 'pending';

    final statusLabel = paymentStatus == 'paid'
        ? _t(context, 'Payé', 'Paid')
        : (paymentStatus == 'pending_delivery'
            ? _t(context, 'À la livraison', 'Cash on delivery')
            : _t(context, 'En attente', 'Pending'));

    final statusColor = paymentStatus == 'paid'
        ? success
        : (paymentStatus == 'pending_delivery' ? thixOrange : Colors.orange);

    void goHome() {
      ref.read(checkoutProvider.notifier).reset();
      context.go('/');
    }

    return Scaffold(
      backgroundColor: lightBg,
      body: SafeArea(
        child: Column(
          children: [
            // Header custom
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    onPressed: goHome,
                    icon: const Icon(Icons.close_rounded, color: darkText),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: Column(
                  children: [
                    // Success animation
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.0, end: 1.0),
                      duration: const Duration(milliseconds: 700),
                      curve: Curves.elasticOut,
                      builder: (context, scale, child) {
                        return Transform.scale(
                          scale: scale,
                          child: Container(
                            width: 110,
                            height: 110,
                            decoration: BoxDecoration(
                              color: success.withOpacity(0.12),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: success.withOpacity(0.2),
                                  blurRadius: 24,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.check_circle_rounded,
                              size: 72,
                              color: success,
                            ),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 24),

                    Text(
                      _t(context, 'Merci pour votre commande !', 'Thank you for your order!'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: darkText,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _t(
                        context,
                        'Votre commande a été enregistrée avec succès.',
                        'Your order has been successfully placed.',
                      ),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: mutedText,
                        fontWeight: FontWeight.w500,
                      ),
                    ),

                    const SizedBox(height: 28),

                    // Order ID card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade200),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.03),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: thixOrange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.receipt_long_rounded, color: thixOrange, size: 22),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _t(context, 'N° de commande', 'Order number'),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: mutedText,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                SelectableText(
                                  '#$shortId',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: darkText,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: orderId));
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(_t(context, 'Numéro copié', 'Number copied')),
                                  behavior: SnackBarBehavior.floating,
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            },
                            icon: const Icon(Icons.copy_rounded, size: 20, color: mutedText),
                            style: IconButton.styleFrom(
                              backgroundColor: lightBg,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Récapitulatif
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.grey.shade200),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.03),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _t(context, 'Récapitulatif', 'Summary'),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: darkText,
                            ),
                          ),
                          const SizedBox(height: 18),

                          _infoRow(
                            icon: Icons.payments_rounded,
                            label: _t(context, 'Total payé', 'Total paid'),
                            value: '$total $symbol',
                            valueColor: thixOrange,
                            isBold: true,
                          ),
                          const SizedBox(height: 14),
                          _infoRow(
                            icon: Icons.local_shipping_outlined,
                            label: _t(context, 'Livraison', 'Shipping'),
                            value: shippingMethod,
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: statusColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(Icons.credit_card_rounded, size: 18, color: statusColor),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _t(context, 'Statut paiement', 'Payment status'),
                                  style: const TextStyle(
                                    color: mutedText,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: statusColor.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  statusLabel,
                                  style: TextStyle(
                                    color: statusColor,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 18),
                            child: Divider(height: 1),
                          ),

                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.mark_email_read_rounded, color: thixOrange, size: 20),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _t(
                                    context,
                                    'Un email de confirmation vous a été envoyé avec le suivi de votre commande.',
                                    'A confirmation email has been sent with your order tracking.',
                                  ),
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 13,
                                    height: 1.45,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 28),

                    // Boutons
                    if (orderId != 'N/A')
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton.icon(
                          onPressed: () => context.push('/market/tracking/$orderId'),
                          icon: const Icon(Icons.local_shipping_rounded, size: 22),
                          label: Text(
                            _t(context, 'Suivre ma commande', 'Track my order'),
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: thixOrange,
                            foregroundColor: pureWhite,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),

                    const SizedBox(height: 12),

                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: OutlinedButton(
                        onPressed: goHome,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: darkText,
                          side: BorderSide(color: Colors.grey.shade300, width: 1.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          _t(context, 'Retour à l\'accueil', 'Back to home'),
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
    bool isBold = false,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: thixOrange.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: thixOrange),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: mutedText,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: isBold ? FontWeight.w900 : FontWeight.w700,
            color: valueColor ?? darkText,
            fontSize: isBold ? 17 : 14,
          ),
        ),
      ],
    );
  }
}
