// lib/presentation/thix_market/checkout/payment_waiting_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'checkout_provider.dart';

class PaymentWaitingPage extends ConsumerStatefulWidget {
  final String orderId;

  const PaymentWaitingPage({super.key, required this.orderId});

  @override
  ConsumerState<PaymentWaitingPage> createState() => _PaymentWaitingPageState();
}

class _PaymentWaitingPageState extends ConsumerState<PaymentWaitingPage> {
  StreamSubscription? _subscription;
  Timer? _timeoutTimer;
  Timer? _pollingTimer;
  bool _timedOut = false;
  bool _isSuccess = false;

  static const thixOrange = Color(0xFFE5592F);
  static const darkText = Color(0xFF10192E);

  String _t(BuildContext context, String fr, String en) {
    final lang = Localizations.localeOf(context).languageCode;
    return lang == 'fr' ? fr : en;
  }

  @override
  void initState() {
    super.initState();
    _listenToPaymentStatus();
    _startPolling();
    _startTimeout();
  }

  void _listenToPaymentStatus() {
    final client = Supabase.instance.client;

    _subscription = client
        .from('orders')
        .stream(primaryKey: ['id'])
        .eq('id', widget.orderId)
        .listen((data) {
      if (data.isEmpty || _isSuccess) return;
      final status = data.first['payment_status']?.toString();

      if (status == 'paid') {
        _onPaymentSuccess();
      } else if (status == 'failed') {
        _onPaymentFailed();
      }
    });
  }

  void _startPolling() {
    // Sécurité si Realtime ne fonctionne pas
    _pollingTimer = Timer.periodic(const Duration(seconds: 4), (_) async {
      if (_isSuccess || _timedOut) return;
      try {
        final res = await Supabase.instance.client
            .from('orders')
            .select('payment_status')
            .eq('id', widget.orderId)
            .maybeSingle();

        final status = res?['payment_status']?.toString();
        if (status == 'paid') {
          _onPaymentSuccess();
        } else if (status == 'failed') {
          _onPaymentFailed();
        }
      } catch (_) {}
    });
  }

  void _startTimeout() {
    // Timeout 3 minutes
    _timeoutTimer = Timer(const Duration(minutes: 3), () {
      if (mounted && !_isSuccess) {
        setState(() => _timedOut = true);
        _cleanup();
      }
    });
  }

  void _onPaymentSuccess() {
    if (_isSuccess) return;
    _isSuccess = true;
    _cleanup();
    if (!mounted) return;

    // Mettre à jour le state avec la commande finale
    final notifier = ref.read(checkoutProvider.notifier);
    notifier.goToStep('bon_de_commande');
  }

  void _onPaymentFailed() {
    _cleanup();
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_t(context, 'Paiement échoué ou annulé', 'Payment failed or cancelled')),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
      ),
    );
    ref.read(checkoutProvider.notifier).goToStep('payment');
  }

  void _cleanup() {
    _subscription?.cancel();
    _pollingTimer?.cancel();
    _timeoutTimer?.cancel();
  }

  @override
  void dispose() {
    _cleanup();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (!_timedOut) ...[
                  const SizedBox(
                    width: 80,
                    height: 80,
                    child: CircularProgressIndicator(
                      strokeWidth: 5,
                      color: thixOrange,
                    ),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    _t(context, 'En attente de confirmation\ndu paiement', 'Waiting for payment\nconfirmation'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: darkText,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _t(
                      context,
                      'Validez le paiement sur votre téléphone.\nNe fermez pas cette page.',
                      'Confirm the payment on your phone.\nDo not close this page.',
                    ),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 40),
                  Text(
                    _t(context, 'Commande', 'Order') + ' #${widget.orderId.substring(0, 8)}...',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ] else ...[
                  Icon(Icons.timer_off_rounded, size: 72, color: Colors.orange.shade700),
                  const SizedBox(height: 24),
                  Text(
                    _t(context, 'Délai dépassé', 'Timeout'),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: darkText,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _t(
                      context,
                      'Le paiement n\'a pas été confirmé à temps.\nVous pouvez réessayer.',
                      'Payment was not confirmed in time.\nYou can try again.',
                    ),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade600, height: 1.4),
                  ),
                  const SizedBox(height: 36),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: () {
                        ref.read(checkoutProvider.notifier).goToStep('payment');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: thixOrange,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      child: Text(
                        _t(context, 'Réessayer', 'Try again'),
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
