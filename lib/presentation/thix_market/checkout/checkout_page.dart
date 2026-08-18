// lib/presentation/thix_market/checkout/checkout_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'checkout_provider.dart';
import 'shipping_method_selector.dart';
import 'payment_method_selector.dart';
import 'order_summary_widget.dart';
import 'order_confirmation_page.dart';
import 'payment_waiting_page.dart';
import '../delivery/delivery_address_selector.dart';
import '../cart/cart_provider.dart';

class CheckoutPage extends ConsumerStatefulWidget {
  const CheckoutPage({super.key});

  @override
  ConsumerState<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends ConsumerState<CheckoutPage> {
  String _t(BuildContext context, String fr, String en) {
    final lang = Localizations.localeOf(context).languageCode;
    return lang == 'fr' ? fr : en;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(checkoutProvider.notifier).loadCheckoutData();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(checkoutProvider);
    final notifier = ref.read(checkoutProvider.notifier);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: Color(0xFF0A1931)),
          onPressed: () {
            final step = state.currentStep;
            if (step == 'address') {
              context.pop();
            } else {
              notifier.previous();
            }
          },
        ),
        title: Text(
          _t(context, 'Validation de commande', 'Checkout Validation'),
          style: const TextStyle(
            color: Color(0xFF0A1931),
            fontWeight: FontWeight.w900,
            fontSize: 18,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: _stepper(state.currentStep),
        ),
      ),
      body: _buildBody(state, notifier),
    );
  }

  Widget _stepper(String step) {
    int idx = 0;
    switch (step) {
      case 'address':
        idx = 0;
        break;
      case 'shipping':
        idx = 1;
        break;
      case 'summary':
      case 'confirmation':
        idx = 2;
        break;
      case 'payment':
      case 'waiting_payment':
        idx = 3;
        break;
      case 'success':
      case 'bon_de_commande':
        idx = 4;
        break;
      default:
        idx = 0;
    }

    final labels = [
      _t(context, 'Adresse', 'Address'),
      _t(context, 'Livraison', 'Shipping'),
      _t(context, 'Vérif.', 'Review'),
      _t(context, 'Paiement', 'Payment'),
      _t(context, 'Bon', 'Order'),
    ];

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Row(
        children: List.generate(5, (i) {
          final active = i <= idx;
          final current = i == idx;
          return Expanded(
            child: Row(
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: active ? const Color(0xFFE5592F) : Colors.grey.shade200,
                        shape: BoxShape.circle,
                        border: current
                            ? Border.all(color: const Color(0xFFE5592F), width: 2)
                            : null,
                      ),
                      child: Center(
                        child: i < idx
                            ? const Icon(Icons.check, size: 14, color: Colors.white)
                            : Text(
                                '${i + 1}',
                                style: TextStyle(
                                  color: active ? Colors.white : Colors.grey,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 11,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      labels[i],
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: current ? FontWeight.w700 : FontWeight.w500,
                        color: active ? const Color(0xFFE5592F) : Colors.grey,
                      ),
                    ),
                  ],
                ),
                if (i < 4)
                  Expanded(
                    child: Container(
                      height: 3,
                      margin: const EdgeInsets.only(bottom: 14, left: 4, right: 4),
                      decoration: BoxDecoration(
                        color: i < idx ? const Color(0xFFE5592F) : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildBody(CheckoutState state, CheckoutNotifier notifier) {
    if (state.isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFE5592F)),
      );
    }

    if (state.error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                state.error!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => notifier.loadCheckoutData(),
                icon: const Icon(Icons.refresh),
                label: Text(_t(context, 'Réessayer', 'Retry')),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE5592F),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: _buildStepContent(state, notifier),
    );
  }

  Widget _buildStepContent(CheckoutState state, CheckoutNotifier notifier) {
    switch (state.currentStep) {
      case 'address':
        return _AddressStep(
          state: state,
          notifier: notifier,
          onContinue: () => notifier.goToStep('shipping'),
        );

      case 'shipping':
        return const ShippingMethodSelector();

      case 'summary':
      case 'confirmation':
        return const OrderSummaryWidget();

      case 'payment':
        return const PaymentMethodSelector();

      case 'waiting_payment':
        final orderId = state.createdOrder?['id']?.toString();
        if (orderId == null) {
          return Center(
            child: Text(_t(context, 'Commande introuvable', 'Order not found')),
          );
        }
        return PaymentWaitingPage(orderId: orderId);

      case 'success':
      case 'bon_de_commande':
        final order = state.createdOrder;
        if (order == null) {
          return Center(
            child: Text(_t(context, 'Commande introuvable', 'Order not found')),
          );
        }
        final currencySymbol = ref.read(cartProvider.notifier).currencySymbol;
        return OrderConfirmationPage(
          order: order,
          currencySymbol: currencySymbol,
        );

      default:
        return Center(
          child: Text('Étape inconnue: ${state.currentStep}'),
        );
    }
  }
}

class _AddressStep extends StatelessWidget {
  final CheckoutState state;
  final CheckoutNotifier notifier;
  final VoidCallback onContinue;

  const _AddressStep({
    required this.state,
    required this.notifier,
    required this.onContinue,
  });

  String _t(BuildContext context, String fr, String en) {
    final lang = Localizations.localeOf(context).languageCode;
    return lang == 'fr' ? fr : en;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: DeliveryAddressSelector(
              onAddressSelected: (address) {
                notifier.selectAddress(address);
              },
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 16,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: state.selectedAddress != null
                    ? () {
                        notifier.selectAddress(state.selectedAddress!);
                        onContinue();
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE5592F),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.shade200,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  _t(context, 'Continuer', 'Continue'),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
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
