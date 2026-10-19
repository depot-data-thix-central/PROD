// lib/presentation/thix_market/checkout/order_summary_widget.dart
// ============================================================================
// ORDER SUMMARY WIDGET — Production Enterprise v5
// ----------------------------------------------------------------------------
//  • ✅ Conversion automatique des prix dans la devise sélectionnée
//  • ✅ Support 54 devises africaines via AfricanCurrencies
//  • ✅ Indicateur visuel 💱 si prix convertis
//  • ✅ Support FR / EN / SW via Localizations
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:html/parser.dart' as html_parser;

import 'package:thix_id/core/theme/thix_design_policy.dart';
import '../cart/cart_provider.dart';
import '../core/african_currencies.dart';
import '../core/currency_service.dart';
import '../providers/currency_provider.dart';
import 'checkout_provider.dart';

// ============================================================================
// VALIDATEURS
// ============================================================================
class _OrderSummaryValidators {
  _OrderSummaryValidators._();

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
}

// ============================================================================
// LOCALIZATION HELPER
// ============================================================================
extension _OrderSummaryL10n on BuildContext {
  String sumT(String fr, String en, [String? sw]) {
    final lang = Localizations.localeOf(this).languageCode;
    if (lang == 'sw' && sw != null) return sw;
    return lang == 'fr' ? fr : en;
  }

  String get localeCode => Localizations.localeOf(this).languageCode;
}

// ============================================================================
// WIDGET PRINCIPAL
// ============================================================================
class OrderSummaryWidget extends ConsumerStatefulWidget {
  const OrderSummaryWidget({super.key});

  @override
  ConsumerState<OrderSummaryWidget> createState() => _OrderSummaryWidgetState();
}

class _OrderSummaryWidgetState extends ConsumerState<OrderSummaryWidget> {
  bool _isNavigating = false;

  @override
  void initState() {
    super.initState();
    debugPrint('[OrderSummary] 📋 Page opened');
  }

  @override
  void dispose() {
    debugPrint('[OrderSummary] 👋 Widget disposed');
    super.dispose();
  }

  Future<void> _continueToPayment() async {
    if (_isNavigating) return;

    final checkout = ref.read(checkoutProvider);
    final checkoutNotifier = ref.read(checkoutProvider.notifier);

    // Validation : adresse et shipping requis
    if (checkout.selectedAddress == null) {
      HapticFeedback.lightImpact();
      _showError(context.sumT(
        'Veuillez sélectionner une adresse',
        'Please select an address',
        'Tafadhali chagua anwani',
      ));
      return;
    }

    if (checkout.selectedShipping == null) {
      HapticFeedback.lightImpact();
      _showError(context.sumT(
        'Veuillez sélectionner un mode de livraison',
        'Please select a shipping method',
        'Tafadhali chagua njia ya usafirishaji',
      ));
      return;
    }

    setState(() => _isNavigating = true);
    HapticFeedback.mediumImpact();

    try {
      checkoutNotifier.goToStep('payment');
      debugPrint('[OrderSummary] ➡️ Continue to payment');
    } catch (e) {
      debugPrint('[OrderSummary] ❌ Navigation error: $e');
      if (mounted) {
        _showError(context.sumT(
          'Erreur lors de la navigation',
          'Navigation error',
          'Hitilafu ya urambazaji',
        ));
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
    final lang = Localizations.localeOf(context).languageCode;
    
    // ✅ Écouter le provider de devise pour rebuild si changement
    final displayCurrencyCode = ref.watch(currencyProvider);
    final currencyService = CurrencyService.instance;
    
    final cartNotifier = ref.read(cartProvider.notifier);
    final cartState = ref.watch(cartProvider);
    final checkout = ref.watch(checkoutProvider);

    // ✅ Devise du panier (code ISO-4217)
    final cartCurrencyCode = cartNotifier.currency;
    final displayCurrencyInfo = AfricanCurrencies.byCode(displayCurrencyCode);
    final displaySymbol = displayCurrencyInfo?.symbol ?? displayCurrencyCode;
    
    // ✅ Détection de conversion
    final isConverted = cartCurrencyCode != displayCurrencyCode;

    // ✅ Conversion des montants
    final subtotalInCartCurrency = _OrderSummaryValidators.safeDouble(cartNotifier.subtotal);
    final convertedSubtotal = currencyService.convert(
      subtotalInCartCurrency,
      from: cartCurrencyCode,
      to: displayCurrencyCode,
    );
    final formattedSubtotal = currencyService.formatPrice(
      convertedSubtotal,
      currencyCode: displayCurrencyCode,
      lang: lang,
    );

    // Calcul shipping (dans la devise du panier, puis converti)
    final shippingPriceInCartCurrency = checkout.selectedShipping != null
        ? _OrderSummaryValidators.safeDouble(checkout.selectedShipping!['price'])
        : 0.0;
    final convertedShipping = currencyService.convert(
      shippingPriceInCartCurrency,
      from: cartCurrencyCode,
      to: displayCurrencyCode,
    );
    final formattedShippingAmount = currencyService.formatPrice(
      convertedShipping,
      currencyCode: displayCurrencyCode,
      lang: lang,
    );
    
    final shippingLabel = checkout.selectedShipping != null
        ? _OrderSummaryValidators.sanitize(
            checkout.selectedShipping!['price_label']?.toString() ?? formattedShippingAmount,
            maxLength: 40,
          )
        : context.sumT('À déterminer', 'To be determined', 'Ithibitishwe');
    final shippingName = checkout.selectedShipping != null
        ? _OrderSummaryValidators.sanitize(
            checkout.selectedShipping!['name']?.toString() ?? context.sumT('Livraison', 'Shipping', 'Usafirishaji'),
            maxLength: 60,
          )
        : context.sumT('Livraison', 'Shipping', 'Usafirishaji');

    // Total = sous-total + shipping (déjà convertis)
    final convertedTotal = convertedSubtotal + convertedShipping;
    final formattedTotal = currencyService.formatPrice(
      convertedTotal,
      currencyCode: displayCurrencyCode,
      lang: lang,
    );

    // Items du panier (avec conversion individuelle)
    final items = cartState.items.map((item) {
      final product = item['product'] as Map?;
      double priceInCartCurrency = 0;
      try {
        priceInCartCurrency = _OrderSummaryValidators.safeDouble(cartNotifier.getItemRealPrice(item));
      } catch (e) {
        debugPrint('[OrderSummary] ⚠️ Price calculation error: $e');
      }

      final quantity = _OrderSummaryValidators.safeInt(item['quantity'], fallback: 1);
      final productName = _OrderSummaryValidators.sanitize(
        product != null && product['title'] != null
            ? product['title'].toString()
            : context.sumT('Produit', 'Product', 'Bidhaa'),
        maxLength: 80,
      );

      String? imageUrl;
      if (product != null) {
        if (product['images'] is List && (product['images'] as List).isNotEmpty) {
          imageUrl = _OrderSummaryValidators.sanitizeUrl((product['images'] as List).first.toString());
        } else {
          imageUrl = _OrderSummaryValidators.sanitizeUrl(product['image_url']?.toString());
        }
      }

      // ✅ Conversion du prix de l'article
      final convertedItemPrice = currencyService.convert(
        priceInCartCurrency,
        from: cartCurrencyCode,
        to: displayCurrencyCode,
      );

      return {
        'product_id': product != null ? product['id'] : item['product_id'],
        'quantity': quantity,
        'price': convertedItemPrice, // ✅ Prix déjà converti
        'product_name': productName,
        'image_url': imageUrl,
      };
    }).toList();

    // État panier vide
    if (items.isEmpty) {
      return _EmptyCartState(
        message: context.sumT(
          'Votre panier est vide',
          'Your cart is empty',
          'Kikapu chako ni tupu',
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ✅ Indicateur de conversion (si applicable)
                if (isConverted)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: ThixPolicy.primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: ThixPolicy.primary.withOpacity(0.2)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.currency_exchange_rounded, size: 16, color: ThixPolicy.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            context.sumT(
                              'Prix convertis en ${displayCurrencyInfo?.displayName(lang) ?? displayCurrencyCode}',
                              'Prices converted to ${displayCurrencyInfo?.displayName(lang) ?? displayCurrencyCode}',
                              'Bei zimebadilishwa kuwa ${displayCurrencyInfo?.displayName(lang) ?? displayCurrencyCode}',
                            ),
                            style: ThixPolicy.captionStyle.copyWith(
                              color: ThixPolicy.primary,
                              fontWeight: ThixPolicy.semiBold,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                _AddressSection(address: checkout.selectedAddress),
                const SizedBox(height: 16),
                _ShippingSection(name: shippingName, priceLabel: shippingLabel),
                const SizedBox(height: 16),

                Text(
                  context.sumT('Articles', 'Items', 'Bidhaa'),
                  style: ThixPolicy.titleStyle.copyWith(
                    fontWeight: ThixPolicy.bold,
                    fontSize: 16,
                    color: ThixPolicy.textMain,
                  ),
                ),
                const SizedBox(height: 8),

                ...items.map((item) => _ItemRow(
                      item: item,
                      currencyCode: displayCurrencyCode,
                      currencyService: currencyService,
                      lang: lang,
                    )),

                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Divider(color: ThixPolicy.border.withOpacity(0.6)),
                ),

                _PriceRow(
                  label: context.sumT('Sous-total', 'Subtotal', 'Jumla ndogo'),
                  value: formattedSubtotal,
                ),
                _PriceRow(
                  label: context.sumT('Livraison', 'Shipping', 'Usafirishaji'),
                  value: shippingLabel,
                  isHighlight: true,
                ),

                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Divider(height: 1, color: ThixPolicy.border.withOpacity(0.6)),
                ),

                _PriceRow(
                  label: context.sumT('Total à payer', 'Total to pay', 'Jumla ya kulipa'),
                  value: formattedTotal,
                  isTotal: true,
                  showConversionIcon: isConverted,
                ),
              ],
            ),
          ),
        ),

        _ContinueButton(
          isProcessing: checkout.isProcessing || _isNavigating,
          label: context.sumT(
            'Continuer vers le paiement',
            'Continue to Payment',
            'Endelea kulipa',
          ),
          onPressed: _continueToPayment,
        ),
      ],
    );
  }
}

// ============================================================================
// COMPOSANTS RÉUTILISABLES
// ============================================================================

class _AddressSection extends StatelessWidget {
  final Map<String, dynamic>? address;

  const _AddressSection({required this.address});

  @override
  Widget build(BuildContext context) {
    if (address == null) {
      return _SectionCard(
        title: context.sumT('Adresse de livraison', 'Delivery Address', 'Anwani ya uwasilishaji'),
        children: [
          Text(
            context.sumT(
              'Aucune adresse sélectionnée',
              'No address selected',
              'Hakuna anwani iliyochaguliwa',
            ),
            style: ThixPolicy.bodySmallStyle.copyWith(color: ThixPolicy.textMuted),
          ),
        ],
      );
    }

    final fullName = _OrderSummaryValidators.sanitize(address!['full_name']?.toString() ?? '', maxLength: 60);
    final addressLine = _OrderSummaryValidators.sanitize(address!['address_line']?.toString() ?? '', maxLength: 120);
    final commune = _OrderSummaryValidators.sanitize(address!['commune']?.toString() ?? '', maxLength: 40);
    final city = _OrderSummaryValidators.sanitize(address!['city']?.toString() ?? '', maxLength: 40);
    final landmark = _OrderSummaryValidators.sanitize(address!['landmark']?.toString() ?? '', maxLength: 80);
    final phone = _OrderSummaryValidators.sanitize(address!['phone']?.toString() ?? '', maxLength: 20);

    return _SectionCard(
      title: context.sumT('Adresse de livraison', 'Delivery Address', 'Anwani ya uwasilishaji'),
      children: [
        if (fullName.isNotEmpty)
          Text(
            fullName,
            style: ThixPolicy.labelStyle.copyWith(fontWeight: ThixPolicy.semiBold, color: ThixPolicy.textMain),
          ),
        if (addressLine.isNotEmpty)
          Text(
            addressLine,
            style: ThixPolicy.bodySmallStyle.copyWith(color: ThixPolicy.textSecondary),
          ),
        if (commune.isNotEmpty || city.isNotEmpty)
          Text(
            '$commune, $city',
            style: ThixPolicy.bodySmallStyle.copyWith(color: ThixPolicy.textSecondary),
          ),
        if (landmark.isNotEmpty)
          Text(
            '${context.sumT('Repère', 'Landmark', 'Alama')}: $landmark',
            style: ThixPolicy.bodySmallStyle.copyWith(
              fontStyle: FontStyle.italic,
              color: ThixPolicy.textMuted,
            ),
          ),
        if (phone.isNotEmpty)
          Text(
            '${context.sumT('Tél', 'Phone', 'Simu')}: $phone',
            style: ThixPolicy.bodySmallStyle.copyWith(color: ThixPolicy.textSecondary),
          ),
      ],
    );
  }
}

class _ShippingSection extends StatelessWidget {
  final String name;
  final String priceLabel;

  const _ShippingSection({required this.name, required this.priceLabel});

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: context.sumT('Mode de livraison', 'Shipping Method', 'Njia ya usafirishaji'),
      children: [
        Text(
          name,
          style: ThixPolicy.labelStyle.copyWith(fontWeight: ThixPolicy.semiBold, color: ThixPolicy.textMain),
        ),
        Text(
          '${context.sumT('Frais', 'Fees', 'Gharama')} : $priceLabel',
          style: ThixPolicy.bodySmallStyle.copyWith(color: ThixPolicy.primary, fontWeight: ThixPolicy.semiBold),
        ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SectionCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ThixPolicy.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ThixPolicy.border.withOpacity(0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: ThixPolicy.titleStyle.copyWith(
              fontWeight: ThixPolicy.bold,
              color: ThixPolicy.textMain,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 12),
          ...children.map((c) => Padding(padding: const EdgeInsets.only(bottom: 4), child: c)),
        ],
      ),
    );
  }
}

// ✅ Mis à jour pour utiliser CurrencyService
class _ItemRow extends StatelessWidget {
  final Map<String, dynamic> item;
  final String currencyCode;
  final CurrencyService currencyService;
  final String lang;

  const _ItemRow({
    required this.item,
    required this.currencyCode,
    required this.currencyService,
    required this.lang,
  });

  @override
  Widget build(BuildContext context) {
    final imageUrl = item['image_url'] as String?;
    final productName = item['product_name'] as String;
    final quantity = item['quantity'] as int;
    final price = item['price'] as double; // ✅ Déjà converti
    
    final formattedPrice = currencyService.formatPrice(
      price * quantity,
      currencyCode: currencyCode,
      lang: lang,
    );

    return Semantics(
      label: '$productName, ${context.sumT('Quantité', 'Quantity', 'Idadi')} $quantity, $formattedPrice',
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: imageUrl != null
              ? CachedNetworkImage(
                  imageUrl: imageUrl,
                  width: 50,
                  height: 50,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(
                    width: 50,
                    height: 50,
                    color: ThixPolicy.surfaceSoft,
                    child: const Center(
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: ThixPolicy.primary),
                      ),
                    ),
                  ),
                  errorWidget: (_, __, ___) => Container(
                    width: 50,
                    height: 50,
                    color: ThixPolicy.surfaceSoft,
                    child: const Icon(Icons.broken_image_outlined, color: ThixPolicy.textMuted, size: 20),
                  ),
                )
              : Container(
                  width: 50,
                  height: 50,
                  color: ThixPolicy.surfaceSoft,
                  child: const Icon(Icons.image_rounded, color: ThixPolicy.textMuted),
                ),
        ),
        title: Text(
          productName,
          style: ThixPolicy.labelStyle.copyWith(
            fontWeight: ThixPolicy.semiBold,
            color: ThixPolicy.textMain,
            fontSize: 14,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${context.sumT('Qté', 'Qty', 'Idadi')}: $quantity',
          style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.textMuted, fontSize: 12),
        ),
        trailing: Text(
          formattedPrice,
          style: ThixPolicy.labelStyle.copyWith(
            fontWeight: ThixPolicy.bold,
            color: ThixPolicy.textMain,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}

// ✅ Mis à jour avec indicateur de conversion
class _PriceRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isTotal;
  final bool isHighlight;
  final bool showConversionIcon;

  const _PriceRow({
    required this.label,
    required this.value,
    this.isTotal = false,
    this.isHighlight = false,
    this.showConversionIcon = false,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label: $value',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                label,
                style: ThixPolicy.labelStyle.copyWith(
                  fontWeight: isTotal ? ThixPolicy.bold : ThixPolicy.regular,
                  fontSize: isTotal ? 16 : 14,
                  color: isTotal ? ThixPolicy.textMain : ThixPolicy.textMuted,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: ThixPolicy.labelStyle.copyWith(
                    fontWeight: isTotal ? ThixPolicy.bold : (isHighlight ? ThixPolicy.semiBold : ThixPolicy.semiBold),
                    fontSize: isTotal ? 18 : 14,
                    color: isTotal ? ThixPolicy.textMain : (isHighlight ? ThixPolicy.primary : ThixPolicy.textMain),
                  ),
                ),
                // ✅ Indicateur de conversion sur le total
                if (showConversionIcon && isTotal) ...[
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    decoration: BoxDecoration(
                      color: ThixPolicy.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Icon(
                      Icons.currency_exchange_rounded,
                      size: 12,
                      color: ThixPolicy.primary,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ContinueButton extends StatelessWidget {
  final bool isProcessing;
  final String label;
  final VoidCallback onPressed;

  const _ContinueButton({
    required this.isProcessing,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Semantics(
        button: true,
        label: label,
        enabled: !isProcessing,
        child: ElevatedButton(
          onPressed: isProcessing ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: ThixPolicy.primary,
            foregroundColor: Colors.white,
            disabledBackgroundColor: ThixPolicy.primary.withOpacity(0.5),
            minimumSize: const Size(double.infinity, 56),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 0,
          ),
          child: isProcessing
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : Text(
                  label,
                  style: ThixPolicy.titleStyle.copyWith(
                    fontWeight: ThixPolicy.bold,
                    fontSize: 16,
                    color: Colors.white,
                  ),
                ),
        ),
      ),
    );
  }
}

class _EmptyCartState extends StatelessWidget {
  final String message;

  const _EmptyCartState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: ThixPolicy.textMuted.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.shopping_cart_outlined, size: 64, color: ThixPolicy.textMuted),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: ThixPolicy.h3Style.copyWith(
              fontWeight: ThixPolicy.bold,
              color: ThixPolicy.textMain,
            ),
          ),
        ],
      ),
    );
  }
}
