// lib/presentation/thix_market/checkout/checkout_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'checkout_provider.dart';
import 'shipping_method_selector.dart';
import 'payment_method_selector.dart';
import 'order_summary_widget.dart';
import 'order_confirmation_page.dart';
import 'payment_waiting_page.dart';
import '../delivery/delivery_address_selector.dart';
import '../cart/cart_provider.dart';

// ============================================================================
// CONSTANTES
// ============================================================================
const Duration _kLoadTimeout = Duration(seconds: 20);
const Duration _kRetryDelay = Duration(milliseconds: 400);

// ============================================================================
// VALIDATEURS
// ============================================================================
class _CheckoutValidators {
  _CheckoutValidators._();

  static bool isValidId(String? id) {
    if (id == null || id.trim().isEmpty) return false;
    return RegExp(r'^[0-9a-fA-F-]{8,}$').hasMatch(id.trim());
  }

  static String friendlyError(dynamic e) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('timeout')) return 'Délai dépassé. Vérifiez votre connexion.';
    if (msg.contains('network') || msg.contains('socket')) return 'Erreur réseau. Réessayez.';
    if (msg.contains('permission') || msg.contains('policy')) return 'Accès non autorisé.';
    if (msg.contains('cart') || msg.contains('empty')) return 'Votre panier est vide.';
    if (msg.contains('address')) return 'Adresse de livraison invalide.';
    return 'Une erreur est survenue. Réessayez.';
  }
}

// ============================================================================
// LOCALIZATION HELPER (extension pour éviter duplication)
// ============================================================================
extension _CheckoutL10n on BuildContext {
  String checkoutT(String fr, String en) {
    final lang = Localizations.localeOf(this).languageCode;
    return lang == 'fr' ? fr : en;
  }
}

// ============================================================================
// STEPS DÉFINITION (centralisé)
// ============================================================================
class _CheckoutStep {
  final String id;
  final String labelFr;
  final String labelEn;
  final IconData icon;

  const _CheckoutStep({
    required this.id,
    required this.labelFr,
    required this.labelEn,
    required this.icon,
  });

  String label(BuildContext context) => context.checkoutT(labelFr, labelEn);
}

const List<_CheckoutStep> _kSteps = [
  _CheckoutStep(id: 'address', labelFr: 'Adresse', labelEn: 'Address', icon: Icons.location_on_rounded),
  _CheckoutStep(id: 'shipping', labelFr: 'Livraison', labelEn: 'Shipping', icon: Icons.local_shipping_rounded),
  _CheckoutStep(id: 'summary', labelFr: 'Vérif.', labelEn: 'Review', icon: Icons.fact_check_rounded),
  _CheckoutStep(id: 'payment', labelFr: 'Paiement', labelEn: 'Payment', icon: Icons.payment_rounded),
  _CheckoutStep(id: 'success', labelFr: 'Bon', labelEn: 'Order', icon: Icons.celebration_rounded),
];

// ============================================================================
// PAGE PRINCIPALE
// ============================================================================
class CheckoutPage extends ConsumerStatefulWidget {
  const CheckoutPage({super.key});

  @override
  ConsumerState<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends ConsumerState<CheckoutPage> {
  bool _isContinuing = false;
  bool _isRetrying = false;

  @override
  void initState() {
    super.initState();
    debugPrint('[Checkout] 🛒 Page opened');
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  @override
  void dispose() {
    debugPrint('[Checkout] 👋 Page disposed');
    super.dispose();
  }

  Future<void> _loadData() async {
    if (_isRetrying) return;
    setState(() => _isRetrying = true);
    HapticFeedback.selectionClick();

    try {
      await ref
          .read(checkoutProvider.notifier)
          .loadCheckoutData()
          .timeout(_kLoadTimeout);
      debugPrint('[Checkout] ✓ Data loaded');
    } on TimeoutException {
      debugPrint('[Checkout] ⏱️ Load timeout');
    } catch (e) {
      debugPrint('[Checkout] ❌ Load error: $e');
    } finally {
      if (mounted) setState(() => _isRetrying = false);
    }
  }

  /// Index de l'étape courante dans la liste
  int _currentStepIndex(String stepId) {
    // Gestion des alias (confirmation = summary, waiting_payment = payment, etc.)
    switch (stepId) {
      case 'address': return 0;
      case 'shipping': return 1;
      case 'summary':
      case 'confirmation': return 2;
      case 'payment':
      case 'waiting_payment': return 3;
      case 'success':
      case 'bon_de_commande': return 4;
      default: return 0;
    }
  }

  bool _isTerminalStep(String stepId) {
    return stepId == 'success' || stepId == 'bon_de_commande' || stepId == 'waiting_payment';
  }

  Future<bool> _onWillPop() async {
    final state = ref.read(checkoutProvider);
    final stepIdx = _currentStepIndex(state.currentStep);

    // Si étape terminale, pop direct
    if (_isTerminalStep(state.currentStep)) return true;

    // Si étape 1 (address), pop direct sans confirmation
    if (stepIdx == 0) return true;

    // Sinon, confirmation
    HapticFeedback.mediumImpact();
    final shouldLeave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rLg)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: ThixPolicy.warning.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.warning_amber_rounded, color: ThixPolicy.warning, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                context.checkoutT('Quitter le checkout ?', 'Leave checkout?'),
                style: ThixPolicy.h3Style.copyWith(fontWeight: ThixPolicy.bold, fontSize: 16),
              ),
            ),
          ],
        ),
        content: Text(
          context.checkoutT(
            'Votre progression sera perdue. Voulez-vous vraiment quitter ?',
            'Your progress will be lost. Are you sure you want to leave?',
          ),
          style: ThixPolicy.bodyStyle,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              context.checkoutT('Rester', 'Stay'),
              style: ThixPolicy.labelStyle.copyWith(color: ThixPolicy.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: ThixPolicy.danger,
              foregroundColor: Colors.white,
            ),
            child: Text(context.checkoutT('Quitter', 'Leave')),
          ),
        ],
      ),
    );
    return shouldLeave ?? false;
  }

  Future<void> _onBackPressed(CheckoutState state, CheckoutNotifier notifier) async {
    HapticFeedback.selectionClick();
    final step = state.currentStep;

    if (step == 'address') {
      final shouldPop = await _onWillPop();
      if (shouldPop && mounted) context.pop();
    } else {
      notifier.previous();
      debugPrint('[Checkout] ⬅️ Previous step from $step');
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(checkoutProvider);
    final notifier = ref.read(checkoutProvider.notifier);
    final stepIdx = _currentStepIndex(state.currentStep);

    return PopScope(
      canPop: _isTerminalStep(state.currentStep) || stepIdx == 0,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && mounted) context.pop();
      },
      child: Scaffold(
        backgroundColor: ThixPolicy.surfaceSoft,
        appBar: AppBar(
          backgroundColor: ThixPolicy.card,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: Semantics(
            button: true,
            label: context.checkoutT('Retour', 'Back'),
            child: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: ThixPolicy.textMain),
              tooltip: context.checkoutT('Retour', 'Back'),
              onPressed: () => _onBackPressed(state, notifier),
            ),
          ),
          title: Text(
            context.checkoutT('Validation de commande', 'Checkout'),
            style: ThixPolicy.h3Style.copyWith(
              color: ThixPolicy.textMain,
              fontWeight: ThixPolicy.bold,
              fontSize: 18,
            ),
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(60),
            child: _Stepper(currentStepId: state.currentStep),
          ),
        ),
        body: _buildBody(state, notifier),
      ),
    );
  }

  Widget _buildBody(CheckoutState state, CheckoutNotifier notifier) {
    if (state.isLoading && !_isRetrying) {
      return const _SkeletonCheckout();
    }

    if (state.error != null) {
      return _ErrorState(
        message: _CheckoutValidators.friendlyError(state.error),
        onRetry: _loadData,
        isRetrying: _isRetrying,
      );
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      child: _buildStepContent(state, notifier),
    );
  }

  Widget _buildStepContent(CheckoutState state, CheckoutNotifier notifier) {
    switch (state.currentStep) {
      case 'address':
        return _AddressStep(
          key: const ValueKey('step_address'),
          state: state,
          notifier: notifier,
          isContinuing: _isContinuing,
          onContinue: () => _handleContinue(notifier, 'shipping'),
        );

      case 'shipping':
        return const ShippingMethodSelector(key: ValueKey('step_shipping'));

      case 'summary':
      case 'confirmation':
        return const OrderSummaryWidget(key: ValueKey('step_summary'));

      case 'payment':
        return const PaymentMethodSelector(key: ValueKey('step_payment'));

      case 'waiting_payment':
        final orderId = state.createdOrder?['id']?.toString();
        if (orderId == null || !_CheckoutValidators.isValidId(orderId)) {
          debugPrint('[Checkout] ⚠️ waiting_payment with invalid orderId: $orderId');
          return _OrderNotFoundState(onRetry: _loadData);
        }
        return PaymentWaitingPage(key: const ValueKey('step_waiting'), orderId: orderId);

      case 'success':
      case 'bon_de_commande':
        final order = state.createdOrder;
        if (order == null) {
          debugPrint('[Checkout] ⚠️ success with null order');
          return _OrderNotFoundState(onRetry: _loadData);
        }
        final currencySymbol = ref.read(cartProvider.notifier).currencySymbol;
        return OrderConfirmationPage(
          key: const ValueKey('step_success'),
          order: order,
          currencySymbol: currencySymbol,
        );

      default:
        debugPrint('[Checkout] ⚠️ Unknown step: ${state.currentStep}');
        return _UnknownStepState(
          onRetry: _loadData,
          onBack: () => context.pop(),
        );
    }
  }

  Future<void> _handleContinue(CheckoutNotifier notifier, String nextStep) async {
    if (_isContinuing) return;
    setState(() => _isContinuing = true);
    HapticFeedback.mediumImpact();

    try {
      notifier.goToStep(nextStep);
      debugPrint('[Checkout] ➡️ Continue to $nextStep');
    } catch (e) {
      debugPrint('[Checkout] ❌ Continue error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(children: [
              const Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text(_CheckoutValidators.friendlyError(e))),
            ]),
            backgroundColor: ThixPolicy.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isContinuing = false);
    }
  }
}

// ============================================================================
// COMPOSANTS
// ============================================================================

class _Stepper extends StatelessWidget {
  final String currentStepId;

  const _Stepper({required this.currentStepId});

  int _indexFor(String stepId) {
    switch (stepId) {
      case 'address': return 0;
      case 'shipping': return 1;
      case 'summary':
      case 'confirmation': return 2;
      case 'payment':
      case 'waiting_payment': return 3;
      case 'success':
      case 'bon_de_commande': return 4;
      default: return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentIdx = _indexFor(currentStepId);

    return Semantics(
      label: context.checkoutT(
        'Étape ${currentIdx + 1} sur ${_kSteps.length}',
        'Step ${currentIdx + 1} of ${_kSteps.length}',
      ),
      child: Container(
        color: ThixPolicy.card,
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: Row(
          children: List.generate(_kSteps.length, (i) {
            final step = _kSteps[i];
            final active = i <= currentIdx;
            final current = i == currentIdx;
            final completed = i < currentIdx;

            return Expanded(
              child: Row(
                children: [
                  Semantics(
                    label: '${step.label(context)}, ${current ? context.checkoutT("actuel", "current") : (completed ? context.checkoutT("complété", "completed") : context.checkoutT("à venir", "upcoming"))}',
                    selected: current,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            color: active ? ThixPolicy.primary : ThixPolicy.border.withOpacity(0.5),
                            shape: BoxShape.circle,
                            border: current
                                ? Border.all(color: ThixPolicy.primary.withOpacity(0.4), width: 3)
                                : null,
                          ),
                          child: Center(
                            child: completed
                                ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
                                : Text(
                                    '${i + 1}',
                                    style: ThixPolicy.microStyle.copyWith(
                                      color: active ? Colors.white : ThixPolicy.textMuted,
                                      fontWeight: ThixPolicy.bold,
                                      fontSize: 11,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          step.label(context),
                          style: ThixPolicy.microStyle.copyWith(
                            fontSize: 9,
                            fontWeight: current ? ThixPolicy.bold : ThixPolicy.regular,
                            color: active ? ThixPolicy.primary : ThixPolicy.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (i < _kSteps.length - 1)
                    Expanded(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        height: 3,
                        margin: const EdgeInsets.only(bottom: 14, left: 4, right: 4),
                        decoration: BoxDecoration(
                          color: i < currentIdx ? ThixPolicy.primary : ThixPolicy.border.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                ],
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _AddressStep extends StatelessWidget {
  final CheckoutState state;
  final CheckoutNotifier notifier;
  final bool isContinuing;
  final VoidCallback onContinue;

  const _AddressStep({
    super.key,
    required this.state,
    required this.notifier,
    required this.isContinuing,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    final canContinue = state.selectedAddress != null && !isContinuing;

    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: DeliveryAddressSelector(
              onAddressSelected: (address) => notifier.selectAddress(address),
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          decoration: BoxDecoration(
            color: ThixPolicy.card,
            boxShadow: ThixPolicy.shadowSoft(opacity: 0.06),
          ),
          child: SafeArea(
            top: false,
            child: Semantics(
              button: true,
              label: canContinue
                  ? context.checkoutT('Continuer', 'Continue')
                  : context.checkoutT('Sélectionnez une adresse', 'Select an address'),
              enabled: canContinue,
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: canContinue ? onContinue : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ThixPolicy.primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: ThixPolicy.border.withOpacity(0.5),
                    disabledForegroundColor: ThixPolicy.textDisabled,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: isContinuing
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              context.checkoutT('Continuer', 'Continue'),
                              style: ThixPolicy.titleStyle.copyWith(
                                color: Colors.white,
                                fontWeight: ThixPolicy.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 18),
                          ],
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

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final bool isRetrying;

  const _ErrorState({
    required this.message,
    required this.onRetry,
    required this.isRetrying,
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
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: ThixPolicy.danger.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.error_outline_rounded, size: 56, color: ThixPolicy.danger),
            ),
            const SizedBox(height: 20),
            Text(
              context.checkoutT('Erreur de chargement', 'Loading error'),
              style: ThixPolicy.h3Style.copyWith(fontWeight: ThixPolicy.bold, color: ThixPolicy.textMain),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: ThixPolicy.bodySmallStyle.copyWith(color: ThixPolicy.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Semantics(
              button: true,
              label: context.checkoutT('Réessayer', 'Retry'),
              child: ElevatedButton.icon(
                onPressed: isRetrying ? null : onRetry,
                icon: isRetrying
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.refresh_rounded, color: Colors.white),
                label: Text(
                  context.checkoutT('Réessayer', 'Retry'),
                  style: ThixPolicy.labelStyle.copyWith(fontWeight: ThixPolicy.bold, color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: ThixPolicy.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrderNotFoundState extends StatelessWidget {
  final VoidCallback onRetry;
  const _OrderNotFoundState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: ThixPolicy.warning.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.search_off_rounded, size: 56, color: ThixPolicy.warning),
            ),
            const SizedBox(height: 20),
            Text(
              context.checkoutT('Commande introuvable', 'Order not found'),
              style: ThixPolicy.h3Style.copyWith(fontWeight: ThixPolicy.bold, color: ThixPolicy.textMain),
            ),
            const SizedBox(height: 8),
            Text(
              context.checkoutT(
                'Impossible de récupérer les détails de votre commande.',
                'Unable to retrieve your order details.',
              ),
              style: ThixPolicy.bodySmallStyle.copyWith(color: ThixPolicy.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, color: Colors.white),
              label: Text(
                context.checkoutT('Réessayer', 'Retry'),
                style: ThixPolicy.labelStyle.copyWith(fontWeight: ThixPolicy.bold, color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: ThixPolicy.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UnknownStepState extends StatelessWidget {
  final VoidCallback onRetry;
  final VoidCallback onBack;
  const _UnknownStepState({required this.onRetry, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: ThixPolicy.warning.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.help_outline_rounded, size: 56, color: ThixPolicy.warning),
            ),
            const SizedBox(height: 20),
            Text(
              context.checkoutT('État inattendu', 'Unexpected state'),
              style: ThixPolicy.h3Style.copyWith(fontWeight: ThixPolicy.bold, color: ThixPolicy.textMain),
            ),
            const SizedBox(height: 8),
            Text(
              context.checkoutT(
                'Une erreur inattendue est survenue. Veuillez réessayer.',
                'An unexpected error occurred. Please try again.',
              ),
              style: ThixPolicy.bodySmallStyle.copyWith(color: ThixPolicy.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: onBack,
                  icon: const Icon(Icons.arrow_back_rounded),
                  label: Text(context.checkoutT('Retour', 'Back')),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: ThixPolicy.textMain,
                    side: BorderSide(color: ThixPolicy.border),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                  label: Text(context.checkoutT('Réessayer', 'Retry'), style: const TextStyle(color: Colors.white, fontWeight: ThixPolicy.bold)),
                  style: ElevatedButton.styleFrom(backgroundColor: ThixPolicy.primary),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SkeletonCheckout extends StatelessWidget {
  const _SkeletonCheckout();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header section skeleton
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: ThixPolicy.card,
              borderRadius: BorderRadius.circular(ThixPolicy.rLg),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(height: 14, width: 140, color: Colors.grey.shade200),
                const SizedBox(height: 12),
                Container(height: 48, decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(8))),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // List skeleton
          ...List.generate(
            3,
            (_) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                height: 80,
                decoration: BoxDecoration(
                  color: ThixPolicy.card,
                  borderRadius: BorderRadius.circular(ThixPolicy.rLg),
                ),
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Container(width: 56, height: 56, decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(8))),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(height: 12, width: double.infinity, color: Colors.grey.shade200),
                          const SizedBox(height: 8),
                          Container(height: 10, width: 140, color: Colors.grey.shade200),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const Spacer(),
          // Button skeleton
          Container(
            height: 52,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ],
      ),
    );
  }
}
