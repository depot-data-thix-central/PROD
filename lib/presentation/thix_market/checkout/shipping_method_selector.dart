// lib/presentation/thix_market/checkout/shipping_method_selector.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:html/parser.dart' as html_parser;

import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'checkout_provider.dart';

// ============================================================================
// VALIDATEURS
// ============================================================================
class _ShippingValidators {
  _ShippingValidators._();

  static bool isValidId(String? id) {
    if (id == null || id.trim().isEmpty) return false;
    // IDs de shipping peuvent être alphanumériques avec underscores
    return RegExp(r'^[a-zA-Z0-9_\-]{2,}$').hasMatch(id.trim());
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

  static double safeDouble(dynamic v, {double fallback = 0.0}) {
    if (v == null) return fallback;
    final parsed = (v as num?)?.toDouble() ?? fallback;
    return parsed < 0 || parsed.isNaN || parsed.isInfinite ? fallback : parsed;
  }
}

// ============================================================================
// LOCALIZATION HELPER
// ============================================================================
extension _ShippingL10n on BuildContext {
  String shipT(String fr, String en) {
    final lang = Localizations.localeOf(this).languageCode;
    return lang == 'fr' ? fr : en;
  }
}

// ============================================================================
// MODÈLE DE MÉTHODE DE LIVRAISON
// ============================================================================
class _ShippingMethod {
  final String id;
  final String nameFr;
  final String nameEn;
  final String priceLabelFr;
  final String priceLabelEn;
  final String daysFr;
  final String daysEn;
  final double price;
  final IconData icon;

  const _ShippingMethod({
    required this.id,
    required this.nameFr,
    required this.nameEn,
    required this.priceLabelFr,
    required this.priceLabelEn,
    required this.daysFr,
    required this.daysEn,
    required this.price,
    required this.icon,
  });

  String name(BuildContext context) => context.shipT(nameFr, nameEn);
  String priceLabel(BuildContext context) => context.shipT(priceLabelFr, priceLabelEn);
  String days(BuildContext context) => context.shipT(daysFr, daysEn);

  Map<String, dynamic> toMap(BuildContext context) => {
        'id': id,
        'name': name(context),
        'price': price,
        'price_label': priceLabel(context),
        'days': days(context),
      };
}

// ============================================================================
// MÉTHODES DE LIVRAISON STATIQUES
// ============================================================================
const List<_ShippingMethod> _kShippingMethods = [
  _ShippingMethod(
    id: 'home_delivery',
    nameFr: 'Livraison à domicile',
    nameEn: 'Home Delivery',
    priceLabelFr: 'Fixé par le livreur',
    priceLabelEn: 'Set by courier',
    daysFr: 'Le livreur vous contactera',
    daysEn: 'Courier will contact you',
    price: 0,
    icon: Icons.local_shipping_rounded,
  ),
  _ShippingMethod(
    id: 'pickup',
    nameFr: 'Point relais THIX',
    nameEn: 'THIX Pickup Point',
    priceLabelFr: 'Gratuit',
    priceLabelEn: 'Free',
    daysFr: 'Retrait en boutique',
    daysEn: 'In-store pickup',
    price: 0,
    icon: Icons.store_rounded,
  ),
];

// ============================================================================
// WIDGET PRINCIPAL
// ============================================================================
class ShippingMethodSelector extends ConsumerStatefulWidget {
  const ShippingMethodSelector({super.key});

  @override
  ConsumerState<ShippingMethodSelector> createState() => _ShippingMethodSelectorState();
}

class _ShippingMethodSelectorState extends ConsumerState<ShippingMethodSelector> {
  bool _isNavigating = false;

  @override
  void initState() {
    super.initState();
    debugPrint('[ShippingSelector] 🚚 Page opened (${_kShippingMethods.length} methods)');
  }

  @override
  void dispose() {
    debugPrint('[ShippingSelector] 👋 Page disposed');
    super.dispose();
  }

  void _onMethodSelected(_ShippingMethod method) {
    HapticFeedback.selectionClick();
    final notifier = ref.read(checkoutProvider.notifier);
    notifier.selectShippingMethod(method.toMap(context));
    debugPrint('[ShippingSelector] ✓ Selected: ${method.id}');
  }

  Future<void> _continue() async {
    if (_isNavigating) return;

    final state = ref.read(checkoutProvider);
    if (state.selectedShipping == null) {
      HapticFeedback.lightImpact();
      _showError(context.shipT('Veuillez sélectionner un mode de livraison', 'Please select a shipping method'));
      return;
    }

    final shippingId = state.selectedShipping!['id']?.toString();
    if (!_ShippingValidators.isValidId(shippingId)) {
      HapticFeedback.lightImpact();
      _showError(context.shipT('Mode de livraison invalide', 'Invalid shipping method'));
      return;
    }

    setState(() => _isNavigating = true);
    HapticFeedback.mediumImpact();

    try {
      final notifier = ref.read(checkoutProvider.notifier);
      notifier.goToStep('summary');
      debugPrint('[ShippingSelector] ➡️ Continue to summary');
    } catch (e) {
      debugPrint('[ShippingSelector] ❌ Navigation error: $e');
      if (mounted) {
        _showError(context.shipT('Erreur de navigation', 'Navigation error'));
      }
    } finally {
      if (mounted) setState(() => _isNavigating = false);
    }
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
    final state = ref.watch(checkoutProvider);
    final selectedId = state.selectedShipping?['id']?.toString();
    final hasMethods = _kShippingMethods.isNotEmpty;

    return Column(
      children: [
        Expanded(
          child: hasMethods
              ? ListView.builder(
                  padding: const EdgeInsets.all(16),
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: _kShippingMethods.length,
                  itemBuilder: (context, index) {
                    final method = _kShippingMethods[index];
                    final isSelected = selectedId == method.id;

                    return _ShippingMethodCard(
                      method: method,
                      isSelected: isSelected,
                      onTap: () => _onMethodSelected(method),
                    );
                  },
                )
              : _EmptyState(
                  message: context.shipT(
                    'Aucune méthode de livraison disponible',
                    'No shipping methods available',
                  ),
                ),
        ),

        _ContinueButton(
          isEnabled: state.selectedShipping != null && !_isNavigating,
          isProcessing: _isNavigating,
          label: context.shipT('Continuer', 'Continue'),
          onPressed: _continue,
        ),
      ],
    );
  }
}

// ============================================================================
// COMPOSANTS RÉUTILISABLES
// ============================================================================

class _ShippingMethodCard extends StatelessWidget {
  final _ShippingMethod method;
  final bool isSelected;
  final VoidCallback onTap;

  const _ShippingMethodCard({
    required this.method,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final name = method.name(context);
    final priceLabel = method.priceLabel(context);
    final days = method.days(context);

    return Semantics(
      button: true,
      selected: isSelected,
      label: '$name, $priceLabel, $days',
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: ThixPolicy.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? ThixPolicy.primary : ThixPolicy.border.withOpacity(0.6),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: ThixPolicy.primary.withOpacity(0.12),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ]
              : ThixPolicy.shadowSoft(opacity: 0.03),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Icône de méthode
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? ThixPolicy.primary.withOpacity(0.1)
                          : ThixPolicy.surfaceSoft,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      method.icon,
                      color: isSelected ? ThixPolicy.primary : ThixPolicy.textMuted,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),

                  // Nom + délai
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
                          days,
                          style: ThixPolicy.captionStyle.copyWith(
                            color: ThixPolicy.textMuted,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Prix + indicateur sélection
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? ThixPolicy.primary.withOpacity(0.1)
                              : ThixPolicy.surfaceSoft,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          priceLabel,
                          style: ThixPolicy.captionStyle.copyWith(
                            fontWeight: ThixPolicy.bold,
                            fontSize: 11,
                            color: isSelected ? ThixPolicy.primary : ThixPolicy.textMuted,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected ? ThixPolicy.primary : ThixPolicy.border,
                            width: 2,
                          ),
                          color: isSelected ? ThixPolicy.primary : Colors.transparent,
                        ),
                        child: isSelected
                            ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
                            : null,
                      ),
                    ],
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

class _ContinueButton extends StatelessWidget {
  final bool isEnabled;
  final bool isProcessing;
  final String label;
  final VoidCallback onPressed;

  const _ContinueButton({
    required this.isEnabled,
    required this.isProcessing,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: ThixPolicy.card,
        boxShadow: ThixPolicy.shadowSoft(opacity: 0.06),
      ),
      child: SafeArea(
        top: false,
        child: Semantics(
          button: true,
          label: label,
          enabled: isEnabled,
          child: SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: isEnabled ? onPressed : null,
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
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          label,
                          style: ThixPolicy.titleStyle.copyWith(
                            fontWeight: ThixPolicy.bold,
                            fontSize: 16,
                            color: Colors.white,
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
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String message;

  const _EmptyState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: ThixPolicy.textMuted.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.local_shipping_outlined, size: 64, color: ThixPolicy.textMuted),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: ThixPolicy.bodyStyle.copyWith(color: ThixPolicy.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}
