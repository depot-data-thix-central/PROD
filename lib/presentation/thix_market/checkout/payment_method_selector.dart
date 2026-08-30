// lib/presentation/thix_market/checkout/payment_method_selector.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:html/parser.dart' as html_parser;

import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'checkout_provider.dart';
import '../cart/cart_provider.dart';

// ============================================================================
// CONSTANTES
// ============================================================================
const Duration _kPaymentTimeout = Duration(seconds: 45);
const Duration _kRetryDelay = Duration(milliseconds: 400);
const int _kMaxPhoneLength = 20;
const int _kMaxProductNameLength = 80;

// ============================================================================
// VALIDATEURS
// ============================================================================
class _PaymentValidators {
  _PaymentValidators._();

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

  static String? sanitizeUrl(String? url) {
    if (url == null || url.trim().isEmpty) return null;
    final t = url.trim();
    if (!t.startsWith('http://') && !t.startsWith('https://')) return null;
    return t.replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '');
  }

  /// Validation numéro RDC : +243 suivi de 9 chiffres (préfixe 8x/9x)
  static bool isValidDrcPhone(String? phone) {
    if (phone == null || phone.trim().isEmpty) return false;
    final cleaned = phone.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    // +243812345678 ou +243912345678 (12 chiffres total)
    return RegExp(r'^\+243[89]\d{8}$').hasMatch(cleaned);
  }

  static String normalizePhone(String phone) {
    return phone.replaceAll(RegExp(r'[\s\-\(\)]'), '');
  }

  static double safeDouble(dynamic v, {double fallback = 0.0}) {
    if (v == null) return fallback;
    final parsed = (v as num?)?.toDouble() ?? fallback;
    return parsed < 0 || parsed.isNaN || parsed.isInfinite ? fallback : parsed;
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

  static String friendlyError(dynamic e) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('timeout')) return 'Délai dépassé. Vérifiez votre connexion.';
    if (msg.contains('network') || msg.contains('socket')) return 'Erreur réseau. Réessayez.';
    if (msg.contains('permission') || msg.contains('policy')) return 'Accès non autorisé.';
    if (msg.contains('stock') || msg.contains('rupture')) return e.toString();
    if (msg.contains('payment') || msg.contains('transaction')) return 'Échec du paiement. Réessayez.';
    if (msg.contains('insufficient')) return 'Solde insuffisant.';
    return 'Une erreur est survenue. Réessayez.';
  }
}

// ============================================================================
// LOCALIZATION HELPER
// ============================================================================
extension _PaymentL10n on BuildContext {
  String payT(String fr, String en) {
    final lang = Localizations.localeOf(this).languageCode;
    return lang == 'fr' ? fr : en;
  }

  String get localeCode => Localizations.localeOf(this).languageCode;
}

// ============================================================================
// HELPERS
// ============================================================================
Future<T> _withRetry<T>(
  Future<T> Function() fn, {
  required String label,
  int maxRetries = 0, // Pas de retry sur paiement (risque de double charge)
}) async {
  int attempt = 0;
  while (true) {
    try {
      return await fn().timeout(_kPaymentTimeout);
    } on TimeoutException {
      attempt++;
      if (attempt > maxRetries) {
        debugPrint('[PaymentSelector] ❌ $label: timeout after $attempt attempts');
        throw TimeoutException('$label: délai dépassé');
      }
      debugPrint('[PaymentSelector] ⏱️ $label timeout — retry $attempt/$maxRetries');
      await Future.delayed(_kRetryDelay);
    } catch (e) {
      debugPrint('[PaymentSelector] ❌ $label error: $e');
      rethrow;
    }
  }
}

// ============================================================================
// WIDGET PRINCIPAL
// ============================================================================
class PaymentMethodSelector extends ConsumerStatefulWidget {
  const PaymentMethodSelector({super.key});

  @override
  ConsumerState<PaymentMethodSelector> createState() => _PaymentMethodSelectorState();
}

class _PaymentMethodSelectorState extends ConsumerState<PaymentMethodSelector> {
  final TextEditingController _phoneController = TextEditingController();
  String? _selectedOperator;
  bool _isProcessing = false;

  // Méthodes de paiement principales
  static const List<Map<String, dynamic>> _kMainMethods = [
    {
      'id': 'mobile_money',
      'name_fr': 'Mobile Money (RDC)',
      'name_en': 'Mobile Money (DRC)',
      'desc': 'Vodacom • Airtel • Orange • Africell',
      'icon': Icons.phone_android_rounded,
      'thixColorKey': 'primary',
    },
    {
      'id': 'cash',
      'name_fr': 'Paiement à la livraison',
      'name_en': 'Cash on Delivery',
      'desc_fr': 'Règlement en espèces à la réception',
      'desc_en': 'Pay in cash upon receipt',
      'icon': Icons.payments_rounded,
      'thixColorKey': 'success',
    },
    {
      'id': 'thix_money',
      'name': 'THIX Money Wallet',
      'desc_fr': 'Paiement instantané sécurisé',
      'desc_en': 'Secure instant payment',
      'icon': Icons.account_balance_wallet_rounded,
      'thixColorKey': 'primary',
    },
    {
      'id': 'card',
      'name_fr': 'Carte Bancaire Internationale',
      'name_en': 'International Credit Card',
      'desc': 'Visa • Mastercard',
      'icon': Icons.credit_card_rounded,
      'thixColorKey': 'inkDeep',
    },
  ];

  // Opérateurs Mobile Money avec couleurs brand
  static const List<Map<String, dynamic>> _kMobileOperators = [
    {'id': 'vodacom', 'name': 'Vodacom (M-Pesa)', 'short': 'V', 'brandColor': Color(0xFFE60012)},
    {'id': 'airtel', 'name': 'Airtel Money', 'short': 'A', 'brandColor': Color(0xFFED1C24)},
    {'id': 'orange', 'name': 'Orange Money', 'short': 'O', 'brandColor': Color(0xFFFF7900)},
    {'id': 'africell', 'name': 'Africell (AfriMoney)', 'short': 'AF', 'brandColor': Color(0xFF662D91)},
  ];

  @override
  void initState() {
    super.initState();
    debugPrint('[PaymentSelector] 💳 Page opened');
  }

  @override
  void dispose() {
    _phoneController.dispose();
    debugPrint('[PaymentSelector] 👋 Page disposed');
    super.dispose();
  }

  /// Récupère la couleur ThixPolicy par clé (fallback sur primary)
  Color _thixColor(String key) {
    switch (key) {
      case 'success': return ThixPolicy.success;
      case 'inkDeep': return ThixPolicy.inkDeep;
      case 'gold': return ThixPolicy.gold;
      default: return ThixPolicy.primary;
    }
  }

  /// Validation complète avant paiement
  _PaymentValidationResult _validateBeforePay() {
    final state = ref.read(checkoutProvider);
    final cartState = ref.read(cartProvider);

    if (state.selectedPayment == null) {
      return _PaymentValidationResult(
        isValid: false,
        message: context.payT('Veuillez sélectionner un mode de paiement', 'Please select a payment method'),
      );
    }

    if (cartState.items.isEmpty) {
      return _PaymentValidationResult(
        isValid: false,
        message: context.payT('Votre panier est vide', 'Your cart is empty'),
      );
    }

    if (state.selectedAddress == null) {
      return _PaymentValidationResult(
        isValid: false,
        message: context.payT('Adresse de livraison requise', 'Delivery address required'),
      );
    }

    if (state.selectedShipping == null) {
      return _PaymentValidationResult(
        isValid: false,
        message: context.payT('Mode de livraison requis', 'Shipping method required'),
      );
    }

    final methodId = state.selectedPayment!['id']?.toString();
    if (methodId == 'mobile_money') {
      if (_selectedOperator == null) {
        return _PaymentValidationResult(
          isValid: false,
          message: context.payT('Veuillez sélectionner un opérateur', 'Please select an operator'),
        );
      }
      final phone = _phoneController.text.trim();
      if (phone.isEmpty) {
        return _PaymentValidationResult(
          isValid: false,
          message: context.payT('Numéro de téléphone requis', 'Phone number required'),
        );
      }
      if (!_PaymentValidators.isValidDrcPhone(phone)) {
        return _PaymentValidationResult(
          isValid: false,
          message: context.payT('Numéro invalide. Format: +243 8X XXX XXXX', 'Invalid number. Format: +243 8X XXX XXXX'),
        );
      }
    }

    return _PaymentValidationResult(isValid: true);
  }

  /// Confirmation avant paiement Cash on Delivery
  Future<bool> _confirmCashPayment(double total, String symbol) async {
    HapticFeedback.mediumImpact();
    final formatted = _PaymentValidators.formatAmount(total.toInt(), context.localeCode);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rLg)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: ThixPolicy.success.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.payments_rounded, color: ThixPolicy.success, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                context.payT('Confirmer le paiement', 'Confirm payment'),
                style: ThixPolicy.h3Style.copyWith(fontWeight: ThixPolicy.bold, fontSize: 16),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.payT(
                'Vous payerez en espèces à la livraison.',
                'You will pay in cash upon delivery.',
              ),
              style: ThixPolicy.bodyStyle,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: ThixPolicy.success.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: ThixPolicy.success.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.attach_money_rounded, color: ThixPolicy.success, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      context.payT('Montant à préparer', 'Amount to prepare'),
                      style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.textMuted),
                    ),
                  ),
                  Text(
                    '$formatted $symbol',
                    style: ThixPolicy.labelStyle.copyWith(
                      color: ThixPolicy.success,
                      fontWeight: ThixPolicy.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              context.payT('Annuler', 'Cancel'),
              style: ThixPolicy.labelStyle.copyWith(color: ThixPolicy.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: ThixPolicy.success,
              foregroundColor: Colors.white,
            ),
            child: Text(context.payT('Confirmer', 'Confirm')),
          ),
        ],
      ),
    );

    return confirmed ?? false;
  }

  Future<void> _handlePayment() async {
    if (_isProcessing) return;

    // Validation
    final validation = _validateBeforePay();
    if (!validation.isValid) {
      HapticFeedback.lightImpact();
      _showError(validation.message!);
      return;
    }

    final state = ref.read(checkoutProvider);
    final notifier = ref.read(checkoutProvider.notifier);
    final cartNotifier = ref.read(cartProvider.notifier);
    final cartState = ref.read(cartProvider);

    final methodId = state.selectedPayment!['id']?.toString() ?? '';

    // Confirmation pour Cash on Delivery
    if (methodId == 'cash') {
      final confirmed = await _confirmCashPayment(cartNotifier.subtotal, cartNotifier.currencySymbol);
      if (!confirmed) return;
    }

    setState(() => _isProcessing = true);
    HapticFeedback.mediumImpact();
    debugPrint('[PaymentSelector] 💰 Processing payment: $methodId');

    try {
      // Construire items sanitizés
      final items = cartState.items.map((item) {
        final product = item['product'] as Map?;
        double price = 0;
        try {
          price = _PaymentValidators.safeDouble(cartNotifier.getItemRealPrice(item));
        } catch (e) {
          debugPrint('[PaymentSelector] ⚠️ Price calc error: $e');
        }

        final productName = _PaymentValidators.sanitize(
          product?['title']?.toString() ?? context.payT('Produit', 'Product'),
          maxLength: _kMaxProductNameLength,
        );

        String? imageUrl;
        if (product != null) {
          if (product['images'] is List && (product['images'] as List).isNotEmpty) {
            imageUrl = _PaymentValidators.sanitizeUrl((product['images'] as List).first.toString());
          } else {
            imageUrl = _PaymentValidators.sanitizeUrl(product['image_url']?.toString());
          }
        }

        return {
          'product_id': product != null ? product['id'] : item['product_id'],
          'quantity': _PaymentValidators.safeInt(item['quantity'], fallback: 1),
          'price': price,
          'product_name': productName,
          'image_url': imageUrl,
        };
      }).toList();

      final total = cartNotifier.subtotal;
      final phone = _phoneController.text.trim().isNotEmpty
          ? _PaymentValidators.normalizePhone(_phoneController.text.trim())
          : null;

      final result = await _withRetry(
        () => notifier.processOrder(
          total: total,
          items: items,
          phoneNumber: phone,
        ),
        label: 'processOrder[$methodId]',
        maxRetries: 0, // Pas de retry sur paiement
      );

      if (!mounted) return;

      final needsWaiting = result['needs_waiting'] == true;
      debugPrint('[PaymentSelector] ✓ Payment processed (needs_waiting=$needsWaiting)');

      if (needsWaiting) {
        notifier.goToStep('waiting_payment');
      } else {
        _showSuccess(context.payT('Paiement effectué avec succès !', 'Payment successful!'));
        notifier.goToStep('bon_de_commande');
      }
    } catch (e) {
      final friendly = _PaymentValidators.friendlyError(e);
      debugPrint('[PaymentSelector] ❌ Payment error: $friendly');
      if (mounted) _showError(friendly);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _onMethodSelected(Map<String, dynamic> method) {
    HapticFeedback.selectionClick();
    final notifier = ref.read(checkoutProvider.notifier);
    notifier.selectPaymentMethod(method);

    // Reset opérateur si pas mobile money
    if (method['id'] != 'mobile_money') {
      setState(() => _selectedOperator = null);
    }
  }

  void _onOperatorSelected(String opId) {
    HapticFeedback.selectionClick();
    setState(() => _selectedOperator = opId);
    debugPrint('[PaymentSelector] 📱 Operator selected: $opId');
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

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(message)),
        ]),
        backgroundColor: ThixPolicy.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  bool _computeCanPay() {
    final state = ref.read(checkoutProvider);
    if (state.selectedPayment == null) return false;

    final isMobile = state.selectedPayment!['id'] == 'mobile_money';
    if (isMobile && (_selectedOperator == null || _phoneController.text.trim().isEmpty)) {
      return false;
    }

    return !_isProcessing;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(checkoutProvider);
    final cartNotifier = ref.read(cartProvider.notifier);
    final total = cartNotifier.subtotal;
    final symbol = cartNotifier.currencySymbol;
    final formattedTotal = _PaymentValidators.formatAmount(total.toInt(), context.localeCode);

    final isMobileMoneySelected = state.selectedPayment != null &&
        state.selectedPayment!['id'] == 'mobile_money';

    final canPay = _computeCanPay();

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              Text(
                context.payT('Choisissez votre mode de paiement', 'Choose your payment method'),
                style: ThixPolicy.titleStyle.copyWith(
                  fontSize: 17,
                  fontWeight: ThixPolicy.bold,
                  color: ThixPolicy.textMain,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                context.payT('Sélectionnez une option pour continuer', 'Select an option to continue'),
                style: ThixPolicy.bodySmallStyle.copyWith(
                  fontSize: 13,
                  color: ThixPolicy.textMuted,
                  fontWeight: ThixPolicy.regular,
                ),
              ),
              const SizedBox(height: 20),

              ..._kMainMethods.map((method) {
                final isSelected = state.selectedPayment != null &&
                    state.selectedPayment!['id'] == method['id'];
                final color = _thixColor(method['thixColorKey'] as String);
                final name = (method['name'] ??
                        (Localizations.localeOf(context).languageCode == 'fr'
                            ? method['name_fr']
                            : method['name_en']))
                    ?.toString() ?? '';
                final desc = (method['desc'] ??
                        (Localizations.localeOf(context).languageCode == 'fr'
                            ? method['desc_fr']
                            : method['desc_en']))
                    ?.toString() ?? '';

                return Column(
                  children: [
                    _PaymentMethodCard(
                      method: method,
                      name: name,
                      desc: desc,
                      isSelected: isSelected,
                      color: color,
                      onTap: () => _onMethodSelected(method),
                    ),
                    if (method['id'] == 'mobile_money' && isMobileMoneySelected)
                      _MobileMoneySection(
                        operators: _kMobileOperators,
                        selectedOperator: _selectedOperator,
                        phoneController: _phoneController,
                        onOperatorSelected: _onOperatorSelected,
                        onPhoneChanged: (_) => setState(() {}),
                      ),
                  ],
                );
              }),
            ],
          ),
        ),

        _PayBottomBar(
          formattedTotal: formattedTotal,
          symbol: symbol,
          canPay: canPay,
          isProcessing: _isProcessing,
          label: context.payT('Payer maintenant', 'Pay Now'),
          totalLabel: context.payT('Total à payer', 'Total to pay'),
          onPay: _handlePayment,
        ),
      ],
    );
  }
}

// ============================================================================
// MODÈLE INTERNE
// ============================================================================
class _PaymentValidationResult {
  final bool isValid;
  final String? message;

  const _PaymentValidationResult({required this.isValid, this.message});
}

// ============================================================================
// COMPOSANTS RÉUTILISABLES
// ============================================================================

class _PaymentMethodCard extends StatelessWidget {
  final Map<String, dynamic> method;
  final String name;
  final String desc;
  final bool isSelected;
  final Color color;
  final VoidCallback onTap;

  const _PaymentMethodCard({
    required this.method,
    required this.name,
    required this.desc,
    required this.isSelected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: isSelected,
      label: '$name, $desc',
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: ThixPolicy.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected ? color : ThixPolicy.border,
            width: isSelected ? 2.2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected ? color.withOpacity(0.12) : Colors.black.withOpacity(0.03),
              blurRadius: isSelected ? 16 : 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
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
                      child: Icon(method['icon'] as IconData, color: color, size: 26),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: ThixPolicy.labelStyle.copyWith(
                            fontWeight: ThixPolicy.bold,
                            color: ThixPolicy.textMain,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          desc,
                          style: ThixPolicy.captionStyle.copyWith(
                            color: ThixPolicy.textMuted,
                            fontSize: 12,
                            fontWeight: ThixPolicy.regular,
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
                        color: isSelected ? color : ThixPolicy.border,
                        width: 2,
                      ),
                      color: isSelected ? color : Colors.transparent,
                    ),
                    child: isSelected
                        ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
                        : null,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MobileMoneySection extends StatelessWidget {
  final List<Map<String, dynamic>> operators;
  final String? selectedOperator;
  final TextEditingController phoneController;
  final ValueChanged<String> onOperatorSelected;
  final ValueChanged<String> onPhoneChanged;

  const _MobileMoneySection({
    required this.operators,
    required this.selectedOperator,
    required this.phoneController,
    required this.onOperatorSelected,
    required this.onPhoneChanged,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      margin: const EdgeInsets.only(bottom: 16, left: 4, right: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ThixPolicy.surfaceSoft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ThixPolicy.primary.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.signal_cellular_alt_rounded, size: 18, color: ThixPolicy.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  context.payT('Sélectionnez votre opérateur', 'Select your operator'),
                  style: ThixPolicy.labelStyle.copyWith(
                    fontWeight: ThixPolicy.bold,
                    fontSize: 13.5,
                    color: ThixPolicy.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Grille d'opérateurs
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: operators.map((op) {
              final opId = op['id'] as String;
              final isOpSelected = selectedOperator == opId;
              final opColor = op['brandColor'] as Color;

              return Semantics(
                button: true,
                selected: isOpSelected,
                label: op['name'] as String,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => onOperatorSelected(opId),
                    borderRadius: BorderRadius.circular(14),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: (MediaQuery.of(context).size.width - 74) / 2,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: isOpSelected ? opColor.withOpacity(0.12) : ThixPolicy.card,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isOpSelected ? opColor : ThixPolicy.border,
                          width: isOpSelected ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: opColor,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: Text(
                                op['short'] as String,
                                style: ThixPolicy.microStyle.copyWith(
                                  color: Colors.white,
                                  fontWeight: ThixPolicy.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              op['name'] as String,
                              style: ThixPolicy.captionStyle.copyWith(
                                fontSize: 11.5,
                                fontWeight: isOpSelected ? ThixPolicy.bold : ThixPolicy.semiBold,
                                color: ThixPolicy.textMain,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isOpSelected)
                            Icon(Icons.check_circle_rounded, size: 18, color: opColor),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 18),

          Text(
            context.payT('Numéro Mobile Money', 'Mobile Money Phone Number'),
            style: ThixPolicy.labelStyle.copyWith(
              fontWeight: ThixPolicy.bold,
              fontSize: 13,
              color: ThixPolicy.textMain,
            ),
          ),
          const SizedBox(height: 8),

          Semantics(
            label: context.payT('Numéro de téléphone Mobile Money', 'Mobile Money phone number'),
            child: TextField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              maxLength: _kMaxPhoneLength,
              onChanged: onPhoneChanged,
              style: ThixPolicy.bodyStyle.copyWith(
                fontWeight: ThixPolicy.semiBold,
                fontSize: 15,
                color: ThixPolicy.textMain,
              ),
              decoration: InputDecoration(
                hintText: 'Ex: +243 97X XXX XXX',
                hintStyle: ThixPolicy.bodySmallStyle.copyWith(color: ThixPolicy.textMuted.withOpacity(0.7)),
                counterText: '',
                prefixIcon: Icon(Icons.phone_rounded, color: ThixPolicy.textMuted, size: 20),
                filled: true,
                fillColor: ThixPolicy.card,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: ThixPolicy.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: ThixPolicy.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: ThixPolicy.primary, width: 1.8),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PayBottomBar extends StatelessWidget {
  final String formattedTotal;
  final String symbol;
  final bool canPay;
  final bool isProcessing;
  final String label;
  final String totalLabel;
  final VoidCallback onPay;

  const _PayBottomBar({
    required this.formattedTotal,
    required this.symbol,
    required this.canPay,
    required this.isProcessing,
    required this.label,
    required this.totalLabel,
    required this.onPay,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: ThixPolicy.card,
        boxShadow: ThixPolicy.shadowSoft(opacity: 0.06),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Semantics(
                label: '$totalLabel: $formattedTotal $symbol',
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      totalLabel,
                      style: ThixPolicy.labelStyle.copyWith(
                        fontWeight: ThixPolicy.semiBold,
                        color: ThixPolicy.textMuted,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      '$formattedTotal $symbol',
                      style: ThixPolicy.titleStyle.copyWith(
                        fontWeight: ThixPolicy.bold,
                        color: ThixPolicy.textMain,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Semantics(
              button: true,
              label: label,
              enabled: canPay,
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: canPay ? onPay : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ThixPolicy.primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: ThixPolicy.primary.withOpacity(0.4),
                    disabledForegroundColor: Colors.white70,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: isProcessing
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.lock_rounded, color: Colors.white, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              label,
                              style: ThixPolicy.titleStyle.copyWith(
                                fontWeight: ThixPolicy.bold,
                                fontSize: 16,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
