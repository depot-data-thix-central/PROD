import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'checkout_provider.dart';

class ShippingMethodSelector extends ConsumerWidget {
  const ShippingMethodSelector({super.key});

  static const thixOrange = Color(0xFFE5592F);
  static const pureWhite = Color(0xFFFFFFFF);
  static const darkText = Color(0xFF10192E);
  static const mutedText = Color(0xFF7386A8);

  static const _methods = [
    {
      'id': 'home_delivery',
      'name': 'Livraison à domicile',
      'price': 0,
      'price_label': 'Fixé par le livreur',
      'days': 'Le livreur vous contactera'
    },
    {
      'id': 'pickup',
      'name': 'Point relais THIX',
      'price': 0,
      'price_label': 'Gratuit',
      'days': 'Retrait en boutique'
    },
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(checkoutProvider);
    final notifier = ref.read(checkoutProvider.notifier);

    return Column(children: [
      Expanded(
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _methods.length,
          itemBuilder: (context, index) {
            final method = _methods[index];
            final isSelected =
                state.selectedShipping != null && state.selectedShipping!['id'] == method['id'];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: isSelected ? thixOrange : Colors.grey.shade200,
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: RadioListTile<Map<String, dynamic>>(
                value: method,
                groupValue: state.selectedShipping,
                onChanged: (value) {
                  if (value != null) notifier.selectShippingMethod(value);
                },
                activeColor: thixOrange,
                title: Text(
                  method['name'].toString(),
                  style: const TextStyle(fontWeight: FontWeight.w700, color: darkText),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    method['days'].toString(),
                    style: const TextStyle(color: mutedText, fontSize: 13),
                  ),
                ),
                secondary: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected ? thixOrange.withOpacity(0.1) : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    method['price_label'].toString(),
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                      color: isSelected ? thixOrange : Colors.grey.shade600,
                    ),
                  ),
                ),
              ),
            );
          },
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
            height: 56,
            child: ElevatedButton(
              onPressed: state.selectedShipping == null
                  ? null
                  : () {
                      notifier.selectShippingMethod(state.selectedShipping!);
                      notifier.goToStep('summary');
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: thixOrange,
                foregroundColor: pureWhite,
                disabledBackgroundColor: Colors.grey.shade200,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: const Text(
                'Continuer',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
            ),
          ),
        ),
      ),
    ]);
  }
}
