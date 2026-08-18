import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:thix_id/features/auth/presentation/providers/auth_controller.dart';

class CartSummaryWidget extends ConsumerWidget {
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

  static const navyDeep = Color(0xFF0A1F44);
  static const primaryBlue = Color(0xFF2D6CDF);
  static const red = Color(0xFFD81E2C);
  static const gold = Color(0xFFF0A93B);
  static const darkText = Color(0xFF10192E);
  static const mutedText = Color(0xFF7386A8);

  String _fmt(double v) => '${v.toInt()} $currency';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasDiscount = discount > 0.5;
    final isLoggedIn = ref.watch(authControllerProvider).valueOrNull!= null;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [BoxShadow(color: navyDeep.withOpacity(0.08), blurRadius: 20, offset: const Offset(0, -6))],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(4))),
            const SizedBox(height: 16),
            _row('Sous-total ($itemCount ${itemCount>1?'articles':'article'})', _fmt(hasDiscount? originalSubtotal : subtotal), hasDiscount? originalSubtotal : subtotal, isMuted: false),
            if (hasDiscount)...[
              const SizedBox(height: 6),
              _row('Remise', '-${_fmt(discount)}', discount, valueColor: const Color(0xFF00B074), icon: Icons.local_offer_outlined),
            ],
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(children: [
                  const Text('Livraison', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: mutedText)),
                  const SizedBox(width: 6),
                  Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: const Color(0xFFFFF4CC), borderRadius: BorderRadius.circular(6)), child: const Text('À confirmer', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Color(0xFF8A6D00)))),
                ]),
                Text(shippingCost==0? '0 $currency' : _fmt(shippingCost), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: darkText)),
              ],
            ),
            const Divider(height: 24, thickness: 1),
            _row('Total', _fmt(total), total, isTotal: true),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity, height: 54,
              child: ElevatedButton(
                onPressed: ()=> _checkout(context, isLoggedIn),
                style: ElevatedButton.styleFrom(backgroundColor: primaryBlue, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 0),
                child: const Text('Continuer vers la validation', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value, double raw, {bool isTotal=false, bool isMuted=false, Color? valueColor, IconData? icon}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(children: [
          if(icon!=null)...[Icon(icon, size: 14, color: valueColor), const SizedBox(width: 4)],
          Text(label, style: TextStyle(fontSize: isTotal? 16 : 14, fontWeight: isTotal? FontWeight.w800 : FontWeight.w500, color: isTotal? darkText : isMuted? mutedText : darkText)),
        ]),
        Text(value, style: TextStyle(fontSize: isTotal? 19 : 14.5, fontWeight: isTotal? FontWeight.w900 : FontWeight.w700, color: valueColor?? (isTotal? primaryBlue : darkText), decoration: isMuted &&!isTotal? TextDecoration.lineThrough : null)),
      ],
    );
  }

  void _checkout(BuildContext context, bool isLoggedIn){
    if(!isLoggedIn){ context.go('/login'); return; }
    context.push('/market/checkout');
  }
}
