// lib/presentation/thix_market/checkout/order_confirmation_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:html/parser.dart' as html_parser;

import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'checkout_provider.dart';

// ============================================================================
// VALIDATEURS
// ============================================================================
class _OrderConfValidators {
  _OrderConfValidators._();

  static bool isValidId(String? id) {
    if (id == null || id.trim().isEmpty || id == 'N/A') return false;
    return RegExp(r'^[0-9a-fA-F-]{8,}$').hasMatch(id.trim());
  }

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

  static String safeSymbol(String? symbol) {
    if (symbol == null || symbol.trim().isEmpty) return 'FC';
    final cleaned = symbol.replaceAll(RegExp(r'[<>"\']'), '').trim();
    return cleaned.isEmpty ? 'FC' : cleaned;
  }

  static int safeInt(dynamic v, {int fallback = 0}) {
    if (v == null) return fallback;
    final parsed = (v as num?)?.toInt() ?? fallback;
    return parsed < 0 ? fallback : parsed;
  }

  static String formatAmount(int amount, String locale) {
    try {
      return NumberFormat.decimalPattern(locale).format(amount);
    } catch (_) {
      return amount.toString();
    }
  }
}

// ============================================================================
// LOCALIZATION HELPER (extension)
// ============================================================================
extension _OrderConfL10n on BuildContext {
  String confT(String fr, String en) {
    final lang = Localizations.localeOf(this).languageCode;
    return lang == 'fr' ? fr : en;
  }

  String get localeCode => Localizations.localeOf(this).languageCode;
}

// ============================================================================
// PAGE PRINCIPALE
// ============================================================================
class OrderConfirmationPage extends ConsumerStatefulWidget {
  final Map<String, dynamic> order;
  final String? currencySymbol;

  const OrderConfirmationPage({
    super.key,
    required this.order,
    this.currencySymbol,
  });

  @override
  ConsumerState<OrderConfirmationPage> createState() => _OrderConfirmationPageState();
}

class _OrderConfirmationPageState extends ConsumerState<OrderConfirmationPage> {
  bool _isNavigating = false;

  @override
  void initState() {
    super.initState();
    final orderId = widget.order['id']?.toString();
    debugPrint('[OrderConfirmation] ✅ Page opened for order ${_shortId(orderId ?? '')}');
  }

  @override
  void dispose() {
    debugPrint('[OrderConfirmation] 👋 Page disposed');
    super.dispose();
  }

  String _shortId(String id) {
    if (id.isEmpty || id == 'N/A') return 'N/A';
    return id.length > 8 ? id.substring(0, 8).toUpperCase() : id.toUpperCase();
  }

  Future<void> _goHome() async {
    if (_isNavigating) return;
    setState(() => _isNavigating = true);
    HapticFeedback.mediumImpact();

    try {
      ref.read(checkoutProvider.notifier).reset();
      debugPrint('[OrderConfirmation] 🏠 Reset + go home');
      if (!mounted) return;
      context.go('/');
    } catch (e) {
      debugPrint('[OrderConfirmation] ❌ Go home error: $e');
      if (mounted) setState(() => _isNavigating = false);
    }
  }

  Future<void> _trackOrder(String orderId) async {
    if (_isNavigating) return;
    if (!_OrderConfValidators.isValidId(orderId)) {
      HapticFeedback.lightImpact();
      _showError(context.confT('Identifiant invalide', 'Invalid order ID'));
      return;
    }

    setState(() => _isNavigating = true);
    HapticFeedback.mediumImpact();
    debugPrint('[OrderConfirmation] 📦 Track order: ${_shortId(orderId)}');

    try {
      if (!mounted) return;
      await context.push('/market/tracking/$orderId');
    } catch (e) {
      debugPrint('[OrderConfirmation] ❌ Track error: $e');
    } finally {
      if (mounted) setState(() => _isNavigating = false);
    }
  }

  void _copyOrderId(String orderId) {
    HapticFeedback.selectionClick();
    Clipboard.setData(ClipboardData(text: orderId));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Text(context.confT('Numéro copié', 'Number copied')),
        ]),
        backgroundColor: ThixPolicy.success,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
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

  @override
  Widget build(BuildContext context) {
    final symbol = _OrderConfValidators.safeSymbol(widget.currencySymbol);
    final total = _OrderConfValidators.safeInt(widget.order['total']);
    final orderId = widget.order['id']?.toString() ?? 'N/A';
    final shortId = _shortId(orderId);
    final shippingMethod = _OrderConfValidators.sanitize(
      widget.order['shipping_method']?.toString() ?? 'Standard',
      maxLength: 60,
    );
    final paymentStatus = widget.order['payment_status']?.toString() ?? 'pending';
    final formattedTotal = _OrderConfValidators.formatAmount(total, context.localeCode);

    // Mapping statut → label + couleur
    final statusConfig = _getStatusConfig(paymentStatus, context);

    return Scaffold(
      backgroundColor: ThixPolicy.surfaceSoft,
      body: SafeArea(
        child: Column(
          children: [
            // Header custom
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Semantics(
                    button: true,
                    label: context.confT('Fermer et retourner à l\'accueil', 'Close and return home'),
                    child: IconButton(
                      onPressed: _isNavigating ? null : _goHome,
                      icon: Icon(
                        Icons.close_rounded,
                        color: _isNavigating ? ThixPolicy.textDisabled : ThixPolicy.textMain,
                      ),
                      tooltip: context.confT('Fermer', 'Close'),
                      style: IconButton.styleFrom(
                        backgroundColor: ThixPolicy.card,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  children: [
                    const _SuccessAnimation(),
                    const SizedBox(height: 24),

                    Text(
                      context.confT('Merci pour votre commande !', 'Thank you for your order!'),
                      textAlign: TextAlign.center,
                      style: ThixPolicy.h2Style.copyWith(
                        fontSize: 22,
                        fontWeight: ThixPolicy.bold,
                        color: ThixPolicy.textMain,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      context.confT(
                        'Votre commande a été enregistrée avec succès.',
                        'Your order has been successfully placed.',
                      ),
                      textAlign: TextAlign.center,
                      style: ThixPolicy.bodyStyle.copyWith(
                        fontSize: 14,
                        color: ThixPolicy.textMuted,
                        fontWeight: ThixPolicy.regular,
                      ),
                    ),

                    const SizedBox(height: 28),

                    _OrderIdCard(
                      shortId: shortId,
                      fullId: orderId,
                      onCopy: _copyOrderId,
                      copyLabel: context.confT('Copier le numéro', 'Copy number'),
                      orderLabel: context.confT('N° de commande', 'Order number'),
                    ),

                    const SizedBox(height: 16),

                    _SummaryCard(
                      formattedTotal: formattedTotal,
                      symbol: symbol,
                      shippingMethod: shippingMethod,
                      statusLabel: statusConfig.label,
                      statusColor: statusConfig.color,
                      emailNote: context.confT(
                        'Un email de confirmation vous a été envoyé avec le suivi de votre commande.',
                        'A confirmation email has been sent with your order tracking.',
                      ),
                      summaryTitle: context.confT('Récapitulatif', 'Summary'),
                      totalLabel: context.confT('Total payé', 'Total paid'),
                      shippingLabel: context.confT('Livraison', 'Shipping'),
                      statusTitle: context.confT('Statut paiement', 'Payment status'),
                    ),

                    const SizedBox(height: 28),

                    _ActionButtons(
                      canTrack: _OrderConfValidators.isValidId(orderId),
                      trackLabel: context.confT('Suivre ma commande', 'Track my order'),
                      homeLabel: context.confT('Retour à l\'accueil', 'Back to home'),
                      onTrack: () => _trackOrder(orderId),
                      onHome: _goHome,
                      isNavigating: _isNavigating,
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

  _StatusConfig _getStatusConfig(String status, BuildContext context) {
    switch (status) {
      case 'paid':
        return _StatusConfig(
          label: context.confT('Payé', 'Paid'),
          color: ThixPolicy.success,
        );
      case 'pending_delivery':
        return _StatusConfig(
          label: context.confT('À la livraison', 'Cash on delivery'),
          color: ThixPolicy.primary,
        );
      case 'pending':
      case 'awaiting_payment':
        return _StatusConfig(
          label: context.confT('En attente', 'Pending'),
          color: ThixPolicy.gold,
        );
      case 'failed':
        return _StatusConfig(
          label: context.confT('Échoué', 'Failed'),
          color: ThixPolicy.danger,
        );
      default:
        return _StatusConfig(
          label: context.confT('En attente', 'Pending'),
          color: ThixPolicy.textMuted,
        );
    }
  }
}

// ============================================================================
// MODÈLE INTERNE
// ============================================================================
class _StatusConfig {
  final String label;
  final Color color;
  const _StatusConfig({required this.label, required this.color});
}

// ============================================================================
// COMPOSANTS RÉUTILISABLES
// ============================================================================

class _SuccessAnimation extends StatelessWidget {
  const _SuccessAnimation();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: context.confT('Commande confirmée', 'Order confirmed'),
      child: TweenAnimationBuilder<double>(
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
                color: ThixPolicy.success.withOpacity(0.12),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: ThixPolicy.success.withOpacity(0.2),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                size: 72,
                color: ThixPolicy.success,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _OrderIdCard extends StatelessWidget {
  final String shortId;
  final String fullId;
  final ValueChanged<String> onCopy;
  final String copyLabel;
  final String orderLabel;

  const _OrderIdCard({
    required this.shortId,
    required this.fullId,
    required this.onCopy,
    required this.copyLabel,
    required this.orderLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$orderLabel: $fullId',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: ThixPolicy.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: ThixPolicy.border.withOpacity(0.6)),
          boxShadow: ThixPolicy.shadowSoft(opacity: 0.04),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: ThixPolicy.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.receipt_long_rounded, color: ThixPolicy.primary, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    orderLabel,
                    style: ThixPolicy.captionStyle.copyWith(
                      fontSize: 12,
                      color: ThixPolicy.textMuted,
                      fontWeight: ThixPolicy.regular,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Semantics(
                    label: 'Sélectionner pour copier',
                    child: SelectableText(
                      '#$shortId',
                      style: ThixPolicy.titleStyle.copyWith(
                        fontSize: 16,
                        fontWeight: ThixPolicy.bold,
                        color: ThixPolicy.textMain,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Semantics(
              button: true,
              label: copyLabel,
              child: IconButton(
                onPressed: () => onCopy(fullId),
                icon: const Icon(Icons.copy_rounded, size: 20, color: ThixPolicy.textMuted),
                tooltip: copyLabel,
                style: IconButton.styleFrom(
                  backgroundColor: ThixPolicy.surfaceSoft,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String formattedTotal;
  final String symbol;
  final String shippingMethod;
  final String statusLabel;
  final Color statusColor;
  final String emailNote;
  final String summaryTitle;
  final String totalLabel;
  final String shippingLabel;
  final String statusTitle;

  const _SummaryCard({
    required this.formattedTotal,
    required this.symbol,
    required this.shippingMethod,
    required this.statusLabel,
    required this.statusColor,
    required this.emailNote,
    required this.summaryTitle,
    required this.totalLabel,
    required this.shippingLabel,
    required this.statusTitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: ThixPolicy.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: ThixPolicy.border.withOpacity(0.6)),
        boxShadow: ThixPolicy.shadowSoft(opacity: 0.04),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            summaryTitle,
            style: ThixPolicy.titleStyle.copyWith(
              fontSize: 16,
              fontWeight: ThixPolicy.bold,
              color: ThixPolicy.textMain,
            ),
          ),
          const SizedBox(height: 18),

          _InfoRow(
            icon: Icons.payments_rounded,
            label: totalLabel,
            value: '$formattedTotal $symbol',
            valueColor: ThixPolicy.primary,
            isBold: true,
          ),
          const SizedBox(height: 14),
          _InfoRow(
            icon: Icons.local_shipping_outlined,
            label: shippingLabel,
            value: shippingMethod,
          ),
          const SizedBox(height: 14),

          // Status payment row
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
                  statusTitle,
                  style: ThixPolicy.labelStyle.copyWith(
                    color: ThixPolicy.textMuted,
                    fontWeight: ThixPolicy.semiBold,
                    fontSize: 13,
                  ),
                ),
              ),
              Semantics(
                label: '$statusTitle: $statusLabel',
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusColor.withOpacity(0.3)),
                  ),
                  child: Text(
                    statusLabel,
                    style: ThixPolicy.captionStyle.copyWith(
                      color: statusColor,
                      fontWeight: ThixPolicy.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ],
          ),

          Padding(
            padding: const EdgeInsets.symmetric(vertical: 18),
            child: Divider(height: 1, color: ThixPolicy.border.withOpacity(0.6)),
          ),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: ThixPolicy.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.mark_email_read_rounded, color: ThixPolicy.primary, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  emailNote,
                  style: ThixPolicy.bodySmallStyle.copyWith(
                    color: ThixPolicy.textSecondary,
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;
  final bool isBold;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
    this.isBold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label: $value',
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: ThixPolicy.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: ThixPolicy.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: ThixPolicy.labelStyle.copyWith(
                color: ThixPolicy.textMuted,
                fontWeight: ThixPolicy.semiBold,
                fontSize: 13,
              ),
            ),
          ),
          Text(
            value,
            style: ThixPolicy.labelStyle.copyWith(
              fontWeight: isBold ? ThixPolicy.bold : ThixPolicy.semiBold,
              color: valueColor ?? ThixPolicy.textMain,
              fontSize: isBold ? 17 : 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButtons extends StatelessWidget {
  final bool canTrack;
  final String trackLabel;
  final String homeLabel;
  final VoidCallback onTrack;
  final VoidCallback onHome;
  final bool isNavigating;

  const _ActionButtons({
    required this.canTrack,
    required this.trackLabel,
    required this.homeLabel,
    required this.onTrack,
    required this.onHome,
    required this.isNavigating,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (canTrack) ...[
          Semantics(
            button: true,
            label: trackLabel,
            enabled: !isNavigating,
            child: SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton.icon(
                onPressed: isNavigating ? null : onTrack,
                icon: isNavigating
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.local_shipping_rounded, size: 22, color: Colors.white),
                label: Text(
                  trackLabel,
                  style: ThixPolicy.titleStyle.copyWith(
                    color: Colors.white,
                    fontWeight: ThixPolicy.bold,
                    fontSize: 16,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: ThixPolicy.primary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: ThixPolicy.primary.withOpacity(0.5),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],

        Semantics(
          button: true,
          label: homeLabel,
          enabled: !isNavigating,
          child: SizedBox(
            width: double.infinity,
            height: 54,
            child: OutlinedButton(
              onPressed: isNavigating ? null : onHome,
              style: OutlinedButton.styleFrom(
                foregroundColor: ThixPolicy.textMain,
                disabledForegroundColor: ThixPolicy.textDisabled,
                side: BorderSide(
                  color: isNavigating ? ThixPolicy.border.withOpacity(0.5) : ThixPolicy.border,
                  width: 1.5,
                ),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: Text(
                homeLabel,
                style: ThixPolicy.titleStyle.copyWith(
                  fontWeight: ThixPolicy.semiBold,
                  fontSize: 15,
                  color: isNavigating ? ThixPolicy.textDisabled : ThixPolicy.textMain,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
