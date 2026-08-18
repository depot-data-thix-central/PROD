// lib/presentation/thix_market/checkout/payment_method_selector.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'checkout_provider.dart';
import '../cart/cart_provider.dart';

class PaymentMethodSelector extends ConsumerStatefulWidget {
  const PaymentMethodSelector({super.key});

  @override
  ConsumerState<PaymentMethodSelector> createState() =>
      _PaymentMethodSelectorState();
}

class _PaymentMethodSelectorState extends ConsumerState<PaymentMethodSelector> {
  static const Color thixOrange = Color(0xFFE5592F);
  static const Color pureWhite = Color(0xFFFFFFFF);
  static const Color darkText = Color(0xFF10192E);
  static const Color mutedText = Color(0xFF7386A8);
  static const Color cardBorder = Color(0xFFEEF1F7);
  static const Color lightBg = Color(0xFFF7F8FC);

  final TextEditingController _phoneController = TextEditingController();
  String? _selectedOperator;
  bool _isProcessing = false;

  String _t(BuildContext context, String fr, String en) {
    final lang = Localizations.localeOf(context).languageCode;
    return lang == 'fr' ? fr : en;
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _handlePayment() async {
    final state = ref.read(checkoutProvider);
    final notifier = ref.read(checkoutProvider.notifier);
    final cartNotifier = ref.read(cartProvider.notifier);
    final cartState = ref.read(cartProvider);

    if (state.selectedPayment == null) return;

    setState(() => _isProcessing = true);

    try {
      final items = cartState.items.map((item) {
        final product = item['product'] as Map?;
        double price = 0;
        try {
          price = cartNotifier.getItemRealPrice(item);
        } catch (_) {}
        return {
          'product_id': product != null ? product['id'] : item['product_id'],
          'quantity': item['quantity'],
          'price': price,
          'product_name': product?['title']?.toString() ?? 'Produit',
          'image_url': product != null
              ? (product['images'] is List &&
                      (product['images'] as List).isNotEmpty
                  ? (product['images'] as List).first.toString()
                  : product['image_url']?.toString())
              : null,
        };
      }).toList();

      final total = cartNotifier.subtotal;
      final phone = _phoneController.text.trim().isNotEmpty
          ? _phoneController.text.trim()
          : null;

      final result = await notifier.processOrder(
        total: total,
        items: items,
        phoneNumber: phone,
      );

      if (!mounted) return;

      final needsWaiting = result['needs_waiting'] == true;

      if (needsWaiting) {
        notifier.goToStep('waiting_payment');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _t(context, 'Paiement effectué avec succès !', 'Payment successful!'),
            ),
            backgroundColor: Colors.green.shade600,
            behavior: SnackBarBehavior.floating,
          ),
        );
        notifier.goToStep('bon_de_commande');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_t(context, 'Erreur', 'Error')} : $e'),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(checkoutProvider);
    final notifier = ref.read(checkoutProvider.notifier);
    final cartNotifier = ref.read(cartProvider.notifier);
    final total = cartNotifier.subtotal;
    final currencySymbol = cartNotifier.currencySymbol;

    final isMobileMoneySelected = state.selectedPayment != null &&
        state.selectedPayment!['id'] == 'mobile_money';

    final List<Map<String, dynamic>> mainMethods = [
      {
        'id': 'mobile_money',
        'name': _t(context, 'Mobile Money (RDC)', 'Mobile Money (DRC)'),
        'desc': 'Vodacom • Airtel • Orange • Africell',
        'icon': Icons.phone_android_rounded,
        'color': const Color(0xFF2D6CDF),
      },
      {
        'id': 'cash',
        'name': _t(context, 'Paiement à la livraison', 'Cash on Delivery'),
        'desc': _t(context, 'Règlement en espèces à la réception',
            'Pay in cash upon receipt'),
        'icon': Icons.payments_rounded,
        'color': const Color(0xFF00B074),
      },
      {
        'id': 'thix_money',
        'name': 'THIX Money Wallet',
        'desc': _t(context, 'Paiement instantané sécurisé',
            'Secure instant payment'),
        'icon': Icons.account_balance_wallet_rounded,
        'color': thixOrange,
      },
      {
        'id': 'card',
        'name': _t(context, 'Carte Bancaire Internationale',
            'International Credit Card'),
        'desc': 'Visa • Mastercard',
        'icon': Icons.credit_card_rounded,
        'color': const Color(0xFF0A1F44),
      },
    ];

    final List<Map<String, dynamic>> mobileOperators = [
      {
        'id': 'vodacom',
        'name': 'Vodacom (M-Pesa)',
        'short': 'V',
        'color': const Color(0xFFE60012)
      },
      {
        'id': 'airtel',
        'name': 'Airtel Money',
        'short': 'A',
        'color': const Color(0xFFED1C24)
      },
      {
        'id': 'orange',
        'name': 'Orange Money',
        'short': 'O',
        'color': const Color(0xFFFF7900)
      },
      {
        'id': 'africell',
        'name': 'Africell (AfriMoney)',
        'short': 'AF',
        'color': const Color(0xFF662D91)
      },
    ];

    final canPay = state.selectedPayment != null &&
        !(isMobileMoneySelected &&
            (_selectedOperator == null ||
                _phoneController.text.trim().isEmpty)) &&
        !_isProcessing;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              Text(
                _t(context, 'Choisissez votre mode de paiement',
                    'Choose your payment method'),
                style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: darkText),
              ),
              const SizedBox(height: 6),
              Text(
                _t(context, 'Sélectionnez une option pour continuer',
                    'Select an option to continue'),
                style: const TextStyle(
                    fontSize: 13,
                    color: mutedText,
                    fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 20),
              ...mainMethods.map((method) {
                final isSelected = state.selectedPayment != null &&
                    state.selectedPayment!['id'] == method['id'];
                final color = method['color'] as Color;

                return Column(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: pureWhite,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: isSelected ? color : cardBorder,
                          width: isSelected ? 2.2 : 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: isSelected
                                ? color.withOpacity(0.12)
                                : Colors.black.withOpacity(0.03),
                            blurRadius: isSelected ? 16 : 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            notifier.selectPaymentMethod(method);
                            if (method['id'] != 'mobile_money') {
                              setState(() => _selectedOperator = null);
                            }
                          },
                          borderRadius: BorderRadius.circular(18),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Container(
                                  width: 52,
                                  height: 52,
                                  decoration: BoxDecoration(
                                    color: color.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Center(
                                    child: Icon(
                                      method['icon'] as IconData,
                                      color: color,
                                      size: 26,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        method['name'].toString(),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                          color: darkText,
                                          fontSize: 15,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        method['desc'].toString(),
                                        style: const TextStyle(
                                          color: mutedText,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isSelected
                                          ? color
                                          : Colors.grey.shade300,
                                      width: 2,
                                    ),
                                    color: isSelected
                                        ? color
                                        : Colors.transparent,
                                  ),
                                  child: isSelected
                                      ? const Icon(Icons.check,
                                          size: 14, color: Colors.white)
                                      : null,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (method['id'] == 'mobile_money' && isMobileMoneySelected)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        margin:
                            const EdgeInsets.only(bottom: 16, left: 4, right: 4),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: lightBg,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: const Color(0xFF2D6CDF).withOpacity(0.25)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.signal_cellular_alt_rounded,
                                    size: 18, color: Color(0xFF2D6CDF)),
                                const SizedBox(width: 8),
                                Text(
                                  _t(context, 'Sélectionnez votre opérateur',
                                      'Select your operator'),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13.5,
                                    color: Color(0xFF2D6CDF),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
  crossAxisCount: 2,
  crossAxisSpacing: 10,
  mainAxisSpacing: 10,
  childAspectRatio: 2.6,
),
                              itemCount: mobileOperators.length,
                              itemBuilder: (context, i) {
                                final op = mobileOperators[i];
                                final isOpSelected =
                                    _selectedOperator == op['id'];
                                final opColor = op['color'] as Color;

                                return Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: () => setState(() =>
                                        _selectedOperator = op['id'] as String),
                                    borderRadius: BorderRadius.circular(14),
                                    child: AnimatedContainer(
                                      duration:
                                          const Duration(milliseconds: 180),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: isOpSelected
                                            ? opColor.withOpacity(0.12)
                                            : pureWhite,
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                          color: isOpSelected
                                              ? opColor
                                              : cardBorder,
                                          width: isOpSelected ? 2 : 1,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 28,
                                            height: 28,
                                            decoration: BoxDecoration(
                                              color: opColor,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Center(
                                              child: Text(
                                                op['short'] as String,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.w900,
                                                  fontSize: 11,
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              op['name'] as String,
                                              style: TextStyle(
                                                fontSize: 11.5,
                                                fontWeight: isOpSelected
                                                    ? FontWeight.w800
                                                    : FontWeight.w600,
                                                color: darkText,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          if (isOpSelected)
                                            Icon(Icons.check_circle_rounded,
                                                size: 18, color: opColor),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 18),
                            Text(
                              _t(context, 'Numéro Mobile Money',
                                  'Mobile Money Phone Number'),
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                  color: darkText),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _phoneController,
                              keyboardType: TextInputType.phone,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 15),
                              decoration: InputDecoration(
                                hintText: 'Ex: +243 97X XXX XXX',
                                hintStyle: TextStyle(
                                    color: mutedText.withOpacity(0.7)),
                                prefixIcon: const Icon(Icons.phone_rounded,
                                    color: mutedText, size: 20),
                                filled: true,
                                fillColor: pureWhite,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide:
                                      const BorderSide(color: cardBorder),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide:
                                      const BorderSide(color: cardBorder),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(
                                      color: Color(0xFF2D6CDF), width: 1.8),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 14),
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                          ],
                        ),
                      ),
                  ],
                );
              }),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
          decoration: BoxDecoration(
            color: pureWhite,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 20,
                offset: const Offset(0, -6),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _t(context, 'Total à payer', 'Total to pay'),
                        style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: mutedText,
                            fontSize: 14),
                      ),
                      Text(
                        '${total.toInt()} $currencySymbol',
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          color: darkText,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: canPay ? _handlePayment : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: thixOrange,
                      foregroundColor: pureWhite,
                      disabledBackgroundColor: Colors.grey.shade200,
                      disabledForegroundColor: Colors.grey.shade500,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: _isProcessing
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2.5),
                          )
                        : Text(
                            _t(context, 'Payer maintenant', 'Pay Now'),
                            style: const TextStyle(
                                fontWeight: FontWeight.w800, fontSize: 16),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
