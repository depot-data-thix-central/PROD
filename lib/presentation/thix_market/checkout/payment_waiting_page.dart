// lib/presentation/thix_market/checkout/payment_waiting_page.dart
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'checkout_provider.dart';

// ============================================================================
// CONSTANTES
// ============================================================================
const Duration _kPollingInterval = Duration(seconds: 4);
const Duration _kTimeoutDuration = Duration(minutes: 3);
const Duration _kNetworkRetryDelay = Duration(seconds: 2);
const int _kMaxPollingErrors = 5;

// ============================================================================
// VALIDATEURS
// ============================================================================
class _PaymentWaitingValidators {
  _PaymentWaitingValidators._();

  static bool isValidOrderId(String? id) {
    if (id == null || id.trim().isEmpty) return false;
    return RegExp(r'^[0-9a-fA-F-]{8,}$').hasMatch(id.trim());
  }

  static String shortOrderId(String id) {
    if (id.length <= 8) return id.toUpperCase();
    return '${id.substring(0, 8).toUpperCase()}...';
  }

  static String sanitizeOrderId(String id) {
    return id.replaceAll(RegExp(r'[^0-9a-fA-F-]'), '');
  }

  static String formatCountdown(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}

// ============================================================================
// LOCALIZATION HELPER
// ============================================================================
extension _PaymentWaitingL10n on BuildContext {
  String waitT(String fr, String en) {
    final lang = Localizations.localeOf(this).languageCode;
    return lang == 'fr' ? fr : en;
  }
}

// ============================================================================
// PAGE PRINCIPALE
// ============================================================================
class PaymentWaitingPage extends ConsumerStatefulWidget {
  final String orderId;

  const PaymentWaitingPage({super.key, required this.orderId});

  @override
  ConsumerState<PaymentWaitingPage> createState() => _PaymentWaitingPageState();
}

class _PaymentWaitingPageState extends ConsumerState<PaymentWaitingPage>
    with SingleTickerProviderStateMixin {
  StreamSubscription<List<Map<String, dynamic>>>? _subscription;
  Timer? _timeoutTimer;
  Timer? _pollingTimer;
  Timer? _countdownTimer;

  bool _isResolved = false; // Unified guard for success/failed/timeout
  bool _timedOut = false;
  bool _orderNotFound = false;
  Duration _remainingTime = _kTimeoutDuration;

  // Counters pour debug/monitoring
  int _pollingAttempts = 0;
  int _pollingErrors = 0;

  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _pulseAnimation = CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut);
    _pulseController.repeat(reverse: true);

    final isValid = _PaymentWaitingValidators.isValidOrderId(widget.orderId);
    debugPrint('[PaymentWaiting] ⏳ Page opened for order ${_PaymentWaitingValidators.shortOrderId(widget.orderId)}${isValid ? "" : " (INVALID)"}');

    if (!isValid) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _handleInvalidOrderId());
    } else {
      _startListening();
      _startPolling();
      _startCountdown();
      _startTimeout();
    }
  }

  @override
  void dispose() {
    _cleanup();
    _pulseController.dispose();
    debugPrint('[PaymentWaiting] 👋 Page disposed (polling=$_pollingAttempts, errors=$_pollingErrors)');
    super.dispose();
  }

  // ============================================================
  // LIFECYCLE & CLEANUP
  // ============================================================

  void _handleInvalidOrderId() {
    if (!mounted) return;
    HapticFeedback.lightImpact();
    _showError(context.waitT('Identifiant de commande invalide', 'Invalid order ID'));
    _goToPayment();
  }

  /// Cleanup centralisé : annule tous les timers + subscription
  void _cleanup() {
    _subscription?.cancel();
    _subscription = null;
    _pollingTimer?.cancel();
    _pollingTimer = null;
    _timeoutTimer?.cancel();
    _timeoutTimer = null;
    _countdownTimer?.cancel();
    _countdownTimer = null;
  }

  // ============================================================
  // REALTIME STREAM
  // ============================================================

  void _startListening() {
    final sanitizedId = _PaymentWaitingValidators.sanitizeOrderId(widget.orderId);

    _subscription = Supabase.instance.client
        .from('orders')
        .stream(primaryKey: ['id'])
        .eq('id', sanitizedId)
        .listen(
      (data) {
        if (!mounted || _isResolved) return;

        if (data.isEmpty) {
          debugPrint('[PaymentWaiting] ⚠️ Stream returned empty data');
          return;
        }

        final status = data.first['payment_status']?.toString();
        debugPrint('[PaymentWaiting] 📡 Stream event: payment_status=$status');

        _handlePaymentStatus(status);
      },
      onError: (error) {
        debugPrint('[PaymentWaiting] ⚠️ Stream error: $error');
        // Polling prendra le relais
      },
      onDone: () {
        debugPrint('[PaymentWaiting] ℹ️ Stream closed');
      },
    );
  }

  // ============================================================
  // POLLING (fallback si Realtime ne fonctionne pas)
  // ============================================================

  void _startPolling() {
    _pollingTimer = Timer.periodic(_kPollingInterval, (_) => _pollPaymentStatus());
  }

  Future<void> _pollPaymentStatus() async {
    if (!mounted || _isResolved) {
      _pollingTimer?.cancel();
      return;
    }

    _pollingAttempts++;
    if (_pollingAttempts > 100) {
      // Sécurité : arrêter le polling après 100 tentatives (~7 min)
      debugPrint('[PaymentWaiting] ⚠️ Polling limit reached, stopping');
      _pollingTimer?.cancel();
      return;
    }

    try {
      final sanitizedId = _PaymentWaitingValidators.sanitizeOrderId(widget.orderId);
      final res = await Supabase.instance.client
          .from('orders')
          .select('payment_status')
          .eq('id', sanitizedId)
          .maybeSingle();

      if (!mounted || _isResolved) return;

      if (res == null) {
        // Commande introuvable (supprimée ou ID invalide)
        debugPrint('[PaymentWaiting] ⚠️ Order not found in DB');
        _pollingErrors++;
        if (_pollingErrors >= _kMaxPollingErrors) {
          _handleOrderNotFound();
          return;
        }
      } else {
        _pollingErrors = 0; // Reset error count on successful query
        final status = res['payment_status']?.toString();
        debugPrint('[PaymentWaiting] 🔁 Poll #$_pollingAttempts: payment_status=$status');
        _handlePaymentStatus(status);
      }
    } catch (e) {
      _pollingErrors++;
      debugPrint('[PaymentWaiting] ❌ Polling error #$_pollingErrors: $e');

      // Si trop d'erreurs réseau consécutives, stopper le polling
      if (_pollingErrors >= _kMaxPollingErrors) {
        debugPrint('[PaymentWaiting] ⚠️ Max polling errors reached, stopping');
        _pollingTimer?.cancel();
      }
    }
  }

  // ============================================================
  // TIMEOUT + COUNTDOWN
  // ============================================================

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _isResolved) {
        _countdownTimer?.cancel();
        return;
      }
      setState(() {
        _remainingTime = _remainingTime - const Duration(seconds: 1);
        if (_remainingTime.isNegative) {
          _remainingTime = Duration.zero;
          _countdownTimer?.cancel();
        }
      });
    });
  }

  void _startTimeout() {
    _timeoutTimer = Timer(_kTimeoutDuration, () {
      if (!mounted || _isResolved) return;
      debugPrint('[PaymentWaiting] ⏰ Timeout reached after ${_kTimeoutDuration.inMinutes}min');
      _handleTimeout();
    });
  }

  // ============================================================
  // HANDLERS D'ÉTAT
  // ============================================================

  void _handlePaymentStatus(String? status) {
    if (_isResolved) return;

    switch (status) {
      case 'paid':
        _onPaymentSuccess();
        break;
      case 'failed':
      case 'cancelled':
        _onPaymentFailed();
        break;
      default:
        // pending / awaiting_payment → continuer à attendre
        break;
    }
  }

  void _onPaymentSuccess() {
    if (_isResolved) return;
    _isResolved = true;

    HapticFeedback.mediumImpact();
    debugPrint('[PaymentWaiting] ✅ Payment successful');
    _cleanup();

    if (!mounted) return;

    // Small delay pour laisser l'animation se compléter
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        ref.read(checkoutProvider.notifier).goToStep('bon_de_commande');
      }
    });
  }

  void _onPaymentFailed() {
    if (_isResolved) return;
    _isResolved = true;

    HapticFeedback.heavyImpact();
    debugPrint('[PaymentWaiting] ❌ Payment failed/cancelled');
    _cleanup();

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          const Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(context.waitT('Paiement échoué ou annulé', 'Payment failed or cancelled'))),
        ]),
        backgroundColor: ThixPolicy.danger,
        behavior: SnackBarBehavior.floating,
      ),
    );

    _goToPayment();
  }

  void _handleTimeout() {
    if (_isResolved) return;
    _isResolved = true;
    _timedOut = true;

    HapticFeedback.mediumImpact();
    debugPrint('[PaymentWaiting] ⏰ Timeout UI');
    _cleanup();

    if (mounted) setState(() {});
  }

  void _handleOrderNotFound() {
    if (_isResolved) return;
    _isResolved = true;
    _orderNotFound = true;

    HapticFeedback.heavyImpact();
    debugPrint('[PaymentWaiting] ❌ Order not found');
    _cleanup();

    if (mounted) setState(() {});
  }

  // ============================================================
  // ACTIONS
  // ============================================================

  void _goToPayment() {
    if (!mounted) return;
    HapticFeedback.selectionClick();
    ref.read(checkoutProvider.notifier).goToStep('payment');
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

  void _retry() {
    if (!mounted) return;
    HapticFeedback.mediumImpact();
    _goToPayment();
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ThixPolicy.surfaceSoft,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _buildCurrentState(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentState() {
    if (_orderNotFound) {
      return const _OrderNotFoundState(key: ValueKey('not_found'));
    }

    if (_timedOut) {
      return _TimeoutState(
        key: const ValueKey('timeout'),
        onRetry: _retry,
        retryLabel: context.waitT('Réessayer', 'Try again'),
        titleLabel: context.waitT('Délai dépassé', 'Timeout'),
        subtitleLabel: context.waitT(
          'Le paiement n\'a pas été confirmé à temps.\nVous pouvez réessayer.',
          'Payment was not confirmed in time.\nYou can try again.',
        ),
      );
    }

    return _WaitingState(
      key: const ValueKey('waiting'),
      orderId: widget.orderId,
      remainingTime: _remainingTime,
      pulseAnimation: _pulseAnimation,
      titleLabel: context.waitT(
        'En attente de confirmation\ndu paiement',
        'Waiting for payment\nconfirmation',
      ),
      subtitleLabel: context.waitT(
        'Validez le paiement sur votre téléphone.\nNe fermez pas cette page.',
        'Confirm the payment on your phone.\nDo not close this page.',
      ),
      orderLabel: context.waitT('Commande', 'Order'),
      timeRemainingLabel: context.waitT('Temps restant', 'Time remaining'),
    );
  }
}

// ============================================================================
// COMPOSANTS RÉUTILISABLES
// ============================================================================

class _WaitingState extends StatelessWidget {
  final String orderId;
  final Duration remainingTime;
  final Animation<double> pulseAnimation;
  final String titleLabel;
  final String subtitleLabel;
  final String orderLabel;
  final String timeRemainingLabel;

  const _WaitingState({
    super.key,
    required this.orderId,
    required this.remainingTime,
    required this.pulseAnimation,
    required this.titleLabel,
    required this.subtitleLabel,
    required this.orderLabel,
    required this.timeRemainingLabel,
  });

  @override
  Widget build(BuildContext context) {
    final countdownFormatted = _PaymentWaitingValidators.formatCountdown(remainingTime);
    final shortId = _PaymentWaitingValidators.shortOrderId(orderId);
    final isUrgent = remainingTime.inSeconds < 30;

    return Semantics(
      label: '$titleLabel. $subtitleLabel. $orderLabel $shortId. $timeRemainingLabel $countdownFormatted',
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Animated pulse circle
          AnimatedBuilder(
            listenable: pulseAnimation,
            builder: (context, child) {
              return Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: ThixPolicy.primary.withOpacity(0.1 + pulseAnimation.value * 0.1),
                  boxShadow: [
                    BoxShadow(
                      color: ThixPolicy.primary.withOpacity(0.15 + pulseAnimation.value * 0.15),
                      blurRadius: 30 + pulseAnimation.value * 20,
                      spreadRadius: pulseAnimation.value * 8,
                    ),
                  ],
                ),
                child: Center(
                  child: SizedBox(
                    width: 70,
                    height: 70,
                    child: CircularProgressIndicator(
                      strokeWidth: 5,
                      color: ThixPolicy.primary,
                    ),
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 36),

          Text(
            titleLabel,
            textAlign: TextAlign.center,
            style: ThixPolicy.h2Style.copyWith(
              fontSize: 22,
              fontWeight: ThixPolicy.bold,
              color: ThixPolicy.textMain,
              height: 1.3,
            ),
          ),

          const SizedBox(height: 16),

          Text(
            subtitleLabel,
            textAlign: TextAlign.center,
            style: ThixPolicy.bodyStyle.copyWith(
              fontSize: 14,
              color: ThixPolicy.textMuted,
              height: 1.5,
            ),
          ),

          const SizedBox(height: 40),

          // Countdown timer
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: isUrgent ? ThixPolicy.danger.withOpacity(0.08) : ThixPolicy.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isUrgent ? ThixPolicy.danger.withOpacity(0.3) : ThixPolicy.border.withOpacity(0.6),
              ),
            ),
            child: Column(
              children: [
                Text(
                  timeRemainingLabel,
                  style: ThixPolicy.captionStyle.copyWith(
                    color: ThixPolicy.textMuted,
                    fontSize: 11,
                    fontWeight: ThixPolicy.semiBold,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  countdownFormatted,
                  style: ThixPolicy.h1Style.copyWith(
                    fontSize: 28,
                    fontWeight: ThixPolicy.bold,
                    color: isUrgent ? ThixPolicy.danger : ThixPolicy.textMain,
                    letterSpacing: 2,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Order ID
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.receipt_long_rounded, size: 14, color: ThixPolicy.textMuted),
              const SizedBox(width: 6),
              SelectableText(
                '$orderLabel #$shortId',
                style: ThixPolicy.captionStyle.copyWith(
                  fontSize: 12,
                  color: ThixPolicy.textMuted,
                  fontWeight: ThixPolicy.semiBold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TimeoutState extends StatelessWidget {
  final VoidCallback onRetry;
  final String retryLabel;
  final String titleLabel;
  final String subtitleLabel;

  const _TimeoutState({
    super.key,
    required this.onRetry,
    required this.retryLabel,
    required this.titleLabel,
    required this.subtitleLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$titleLabel. $subtitleLabel',
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: ThixPolicy.warning.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.timer_off_rounded, size: 72, color: ThixPolicy.warning),
          ),
          const SizedBox(height: 28),
          Text(
            titleLabel,
            style: ThixPolicy.h2Style.copyWith(
              fontSize: 22,
              fontWeight: ThixPolicy.bold,
              color: ThixPolicy.textMain,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            subtitleLabel,
            textAlign: TextAlign.center,
            style: ThixPolicy.bodyStyle.copyWith(
              color: ThixPolicy.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 36),
          Semantics(
            button: true,
            label: retryLabel,
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                label: Text(
                  retryLabel,
                  style: ThixPolicy.titleStyle.copyWith(
                    fontWeight: ThixPolicy.bold,
                    fontSize: 16,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: ThixPolicy.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderNotFoundState extends ConsumerWidget {
  const _OrderNotFoundState({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Semantics(
      label: 'Commande introuvable',
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: ThixPolicy.danger.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.search_off_rounded, size: 72, color: ThixPolicy.danger),
          ),
          const SizedBox(height: 28),
          Text(
            context.waitT('Commande introuvable', 'Order not found'),
            style: ThixPolicy.h2Style.copyWith(
              fontSize: 22,
              fontWeight: ThixPolicy.bold,
              color: ThixPolicy.textMain,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            context.waitT(
              'Cette commande n\'existe plus ou a été annulée.',
              'This order no longer exists or has been cancelled.',
            ),
            textAlign: TextAlign.center,
            style: ThixPolicy.bodyStyle.copyWith(
              color: ThixPolicy.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 36),
          Semantics(
            button: true,
            label: context.waitT('Retour au panier', 'Back to cart'),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  ref.read(checkoutProvider.notifier).reset();
                  context.go('/');
                },
                icon: const Icon(Icons.home_rounded, color: Colors.white),
                label: Text(
                  context.waitT('Retour à l\'accueil', 'Back to home'),
                  style: ThixPolicy.titleStyle.copyWith(
                    fontWeight: ThixPolicy.bold,
                    fontSize: 16,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: ThixPolicy.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// ANIMATED BUILDER HELPER
// ============================================================================
class AnimatedBuilder extends AnimatedWidget {
  final Widget Function(BuildContext, Widget?) builder;
  final Widget? child;

  const AnimatedBuilder({
    super.key,
    required super.listenable,
    required this.builder,
    this.child,
  });

  @override
  Widget build(BuildContext context) => builder(context, child);
}
