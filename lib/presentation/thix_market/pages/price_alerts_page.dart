// lib/presentation/thix_market/pages/price_alerts_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:html/parser.dart' as html_parser;

import 'package:thix_id/core/theme/thix_design_policy.dart';
import '../providers/market_providers.dart';

// ============================================================================
// CONSTANTES
// ============================================================================
const Duration _kRequestTimeout = Duration(seconds: 15);
const Duration _kRetryDelay = Duration(milliseconds: 400);
const Duration _kSearchDebounce = Duration(milliseconds: 350);
const int _kMaxSearchResults = 25;
const int _kMaxQueryLength = 100;

// ============================================================================
// VALIDATEURS
// ============================================================================
class _PriceAlertsValidators {
  _PriceAlertsValidators._();

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

  static bool isValidId(String? id) {
    if (id == null || id.isEmpty) return false;
    return RegExp(r'^[0-9a-fA-F-]{8,}$').hasMatch(id);
  }

  static double safePrice(dynamic price) {
    if (price == null) return 0.0;
    if (price is num) {
      final v = price.toDouble();
      return (v.isNaN || v.isInfinite || v < 0) ? 0.0 : v;
    }
    final parsed = double.tryParse(price.toString().replaceAll(RegExp(r'[^\d.]'), ''));
    if (parsed == null || parsed < 0 || parsed.isNaN || parsed.isInfinite) return 0.0;
    return parsed;
  }

  static String parseCurrency(String? currency) {
    final c = (currency ?? 'FC').toString().toUpperCase().trim();
    if (c == 'USD' || c == '\$') return '\$';
    if (c == 'EUR' || c == '€') return '€';
    if (c == 'XOF' || c == 'FCFA' || c == 'FC' || c == 'CDF') return 'FC';
    return c;
  }
}

// ============================================================================
// HELPERS
// ============================================================================
Future<T> _withRetry<T>(
  Future<T> Function() fn, {
  required String label,
  int maxRetries = 1,
}) async {
  int attempt = 0;
  while (true) {
    try {
      return await fn().timeout(_kRequestTimeout);
    } on TimeoutException {
      attempt++;
      if (attempt > maxRetries) {
        debugPrint('[PriceAlerts] ❌ $label: timeout after $attempt attempts');
        throw TimeoutException('$label: délai dépassé');
      }
      debugPrint('[PriceAlerts] ⏱️ $label timeout — retry $attempt/$maxRetries');
      await Future.delayed(_kRetryDelay);
    } catch (e) {
      debugPrint('[PriceAlerts] ❌ $label error: $e');
      rethrow;
    }
  }
}

// ============================================================================
// MODÈLE
// ============================================================================
class PriceAlert {
  final String id;
  final String productId;
  final String title;
  final String? imageUrl;
  final String shopName;
  final double currentPrice;
  final double targetPrice;
  final String currency;

  const PriceAlert({
    required this.id,
    required this.productId,
    required this.title,
    this.imageUrl,
    required this.shopName,
    required this.currentPrice,
    required this.targetPrice,
    required this.currency,
  });

  bool get isReached => currentPrice > 0 && currentPrice <= targetPrice;
  bool get isProductUnavailable => currentPrice <= 0;
  String get symbol => _PriceAlertsValidators.parseCurrency(currency);

  double get discountPercent {
    if (currentPrice <= 0 || targetPrice <= 0) return 0;
    return ((currentPrice - targetPrice) / currentPrice * 100).abs();
  }

  factory PriceAlert.fromMap(Map<String, dynamic> alert) {
    final prodRaw = alert['products'];
    final prod = prodRaw is Map ? Map<String, dynamic>.from(prodRaw) : <String, dynamic>{};
    final shopRaw = prod['shop'];
    final shop = shopRaw is Map ? Map<String, dynamic>.from(shopRaw) : <String, dynamic>{};

    return PriceAlert(
      id: alert['id']?.toString() ?? '',
      productId: alert['product_id']?.toString() ?? '',
      title: _PriceAlertsValidators.sanitize(prod['title']?.toString() ?? 'Produit inconnu', maxLength: 80),
      imageUrl: _PriceAlertsValidators.sanitizeUrl(prod['image_url']?.toString()),
      shopName: _PriceAlertsValidators.sanitize(shop['name']?.toString() ?? 'Boutique', maxLength: 40),
      currentPrice: _PriceAlertsValidators.safePrice(prod['price']),
      targetPrice: _PriceAlertsValidators.safePrice(alert['target_price']),
      currency: prod['currency']?.toString() ?? 'FC',
    );
  }
}

class SearchResult {
  final String id;
  final String title;
  final double price;
  final String currency;
  final String? imageUrl;
  final String shopName;

  const SearchResult({
    required this.id,
    required this.title,
    required this.price,
    required this.currency,
    this.imageUrl,
    required this.shopName,
  });

  String get symbol => _PriceAlertsValidators.parseCurrency(currency);

  factory SearchResult.fromMap(Map<String, dynamic> p) {
    final shop = p['shop'];
    return SearchResult(
      id: p['id']?.toString() ?? '',
      title: _PriceAlertsValidators.sanitize(p['title']?.toString() ?? 'Produit', maxLength: 80),
      price: _PriceAlertsValidators.safePrice(p['price']),
      currency: p['currency']?.toString() ?? 'FC',
      imageUrl: _PriceAlertsValidators.sanitizeUrl(p['image_url']?.toString()),
      shopName: _PriceAlertsValidators.sanitize(
        shop is Map ? shop['name']?.toString() : null,
        maxLength: 40,
      ),
    );
  }
}

// ============================================================================
// PROVIDER (typed + retry)
// ============================================================================
final priceAlertsProvider =
    FutureProvider.autoDispose<List<PriceAlert>>((ref) async {
  final db = ref.read(supabaseClientProvider);
  final uid = db.auth.currentUser?.id;
  if (uid == null) return [];

  debugPrint('[PriceAlerts] 🔔 Loading alerts');

  try {
    final res = await _withRetry(
      () => db
          .from('price_alerts')
          .select('id, target_price, product_id, created_at, products(title, image_url, price, currency, shop:shops(name))')
          .eq('user_id', uid)
          .order('created_at', ascending: false),
      label: 'fetchPriceAlerts',
    );

    final alerts = (res as List).map((e) => PriceAlert.fromMap(Map<String, dynamic>.from(e as Map))).toList();
    debugPrint('[PriceAlerts] ✓ Loaded ${alerts.length} alerts');
    return alerts;
  } catch (e) {
    debugPrint('[PriceAlerts] ❌ Load error: $e');
    return [];
  }
});

// ============================================================================
// PAGE
// ============================================================================
class PriceAlertsPage extends ConsumerStatefulWidget {
  const PriceAlertsPage({super.key});

  @override
  ConsumerState<PriceAlertsPage> createState() => _PriceAlertsPageState();
}

class _PriceAlertsPageState extends ConsumerState<PriceAlertsPage> {
  final TextEditingController _searchCtrl = TextEditingController();
  Timer? _debounceTimer;
  String _query = '';
  bool _searching = false;
  bool _creatingAlert = false;
  List<SearchResult> _searchResults = [];

  @override
  void initState() {
    super.initState();
    debugPrint('[PriceAlerts] 🔔 Page opened');
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchCtrl.dispose();
    debugPrint('[PriceAlerts] 👋 Page disposed');
    super.dispose();
  }

  void _onQueryChanged(String v) {
    _debounceTimer?.cancel();
    final sanitized = _PriceAlertsValidators.sanitize(v, maxLength: _kMaxQueryLength);

    if (sanitized.isEmpty) {
      if (mounted) {
        setState(() {
          _query = '';
          _searchResults = [];
          _searching = false;
        });
      }
      return;
    }

    _debounceTimer = Timer(_kSearchDebounce, () {
      if (!mounted) return;
      if (_searchCtrl.text.trim() == sanitized) _search(sanitized);
    });
  }

  Future<void> _search(String q) async {
    if (!mounted) return;
    setState(() {
      _query = q;
      _searching = true;
    });

    try {
      final db = ref.read(supabaseClientProvider);
      final res = await _withRetry(
        () => db
            .from('products')
            .select('id, title, price, currency, image_url, brand, shop:shops(name)')
            .ilike('title', '%$q%')
            .limit(_kMaxSearchResults),
        label: 'searchProducts["$q"]',
      );

      if (!mounted) return;
      final results = (res as List).map((m) => SearchResult.fromMap(Map<String, dynamic>.from(m as Map))).toList();
      setState(() {
        _searchResults = results;
        _searching = false;
      });
      debugPrint('[PriceAlerts] 🔍 Found ${results.length} products for "$q"');
    } catch (e) {
      debugPrint('[PriceAlerts] ❌ Search error: $e');
      if (mounted) {
        setState(() {
          _searchResults = [];
          _searching = false;
        });
        _showError('Erreur lors de la recherche');
      }
    }
  }

  Future<void> _createAlert(SearchResult product) async {
    if (_creatingAlert) return;

    if (!_PriceAlertsValidators.isValidId(product.id)) {
      _showError('Produit invalide');
      return;
    }

    final uid = ref.read(supabaseClientProvider).auth.currentUser?.id;
    if (uid == null) {
      HapticFeedback.lightImpact();
      context.push('/login');
      return;
    }

    HapticFeedback.mediumImpact();

    final targetCtrl = TextEditingController(
      text: product.price > 0 ? (product.price * 0.9).toInt().toString() : '',
    );

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CreateAlertSheet(
        product: product,
        controller: targetCtrl,
      ),
    );

    // Dispose du controller après fermeture du modal
    targetCtrl.dispose();

    if (confirmed != true) return;

    final targetText = targetCtrl.text.trim().replaceAll(RegExp(r'[^\d.]'), '');
    final target = double.tryParse(targetText);
    if (target == null || target <= 0) {
      _showError('Prix cible invalide');
      return;
    }
    if (product.price > 0 && target >= product.price) {
      _showError('Le prix cible doit être inférieur au prix actuel');
      return;
    }

    setState(() => _creatingAlert = true);

    try {
      final db = ref.read(supabaseClientProvider);
      final existing = await _withRetry(
        () => db
            .from('price_alerts')
            .select('id')
            .eq('user_id', uid)
            .eq('product_id', product.id)
            .maybeSingle(),
        label: 'checkExistingAlert',
      );

      if (existing != null) {
        await _withRetry(
          () => db.from('price_alerts').update({
            'target_price': target,
            'product_title': product.title,
            if (product.imageUrl != null) 'product_image': product.imageUrl,
          }).eq('id', existing['id']),
          label: 'updateAlert',
        );
        debugPrint('[PriceAlerts] ✏️ Updated alert ${existing['id']}');
      } else {
        await _withRetry(
          () => db.from('price_alerts').insert({
            'user_id': uid,
            'product_id': product.id,
            'product_title': product.title,
            'target_price': target,
            if (product.imageUrl != null) 'product_image': product.imageUrl,
            'is_active': true,
          }),
          label: 'createAlert',
        );
        debugPrint('[PriceAlerts] ➕ Created alert for ${product.id}');
      }

      ref.invalidate(priceAlertsProvider);

      if (mounted) {
        _searchCtrl.clear();
        setState(() {
          _query = '';
          _searchResults = [];
        });
        _showSuccess('Alerte créée avec succès');
      }
    } catch (e) {
      debugPrint('[PriceAlerts] ❌ Create alert error: $e');
      _showError('Erreur lors de la création de l\'alerte');
    } finally {
      if (mounted) setState(() => _creatingAlert = false);
    }
  }

  Future<void> _deleteAlert(PriceAlert alert) async {
    HapticFeedback.mediumImpact();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rLg)),
        title: Text('Supprimer l\'alerte ?', style: ThixPolicy.h3Style.copyWith(fontWeight: ThixPolicy.bold)),
        content: Text('Vous ne recevrez plus de notification pour "${alert.title}".', style: ThixPolicy.bodyStyle),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Annuler', style: ThixPolicy.labelStyle.copyWith(color: ThixPolicy.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: ThixPolicy.danger, foregroundColor: Colors.white),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _withRetry(
        () => ref.read(supabaseClientProvider).from('price_alerts').delete().eq('id', alert.id),
        label: 'deleteAlert',
      );
      ref.invalidate(priceAlertsProvider);
      debugPrint('[PriceAlerts] 🗑️ Deleted alert ${alert.id}');
      if (mounted) _showSuccess('Alerte supprimée');
    } catch (e) {
      debugPrint('[PriceAlerts] ❌ Delete error: $e');
      _showError('Erreur lors de la suppression');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          const Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
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
          const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(message)),
        ]),
        backgroundColor: ThixPolicy.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final asyncAlerts = ref.watch(priceAlertsProvider);

    return Scaffold(
      backgroundColor: ThixPolicy.surfaceSoft,
      appBar: AppBar(
        backgroundColor: ThixPolicy.card,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: ThixPolicy.textMain),
          tooltip: 'Retour',
          onPressed: () {
            HapticFeedback.selectionClick();
            context.pop();
          },
        ),
        title: Text(
          'Mes Alertes de Prix',
          style: ThixPolicy.h3Style.copyWith(
            color: ThixPolicy.textMain,
            fontWeight: ThixPolicy.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: Column(
        children: [
          _SearchBar(
            controller: _searchCtrl,
            query: _query,
            onChanged: _onQueryChanged,
            onClear: () {
              HapticFeedback.selectionClick();
              _searchCtrl.clear();
              _onQueryChanged('');
            },
          ),
          Expanded(
            child: _query.isNotEmpty
                ? _buildSearchResults()
                : asyncAlerts.when(
                    loading: () => const _SkeletonList(),
                    error: (e, _) => _ErrorState(
                      message: _PriceAlertsValidators.sanitize(e.toString(), maxLength: 200),
                      onRetry: () => ref.invalidate(priceAlertsProvider),
                    ),
                    data: (alerts) {
                      if (alerts.isEmpty) return const _EmptyState();
                      return RefreshIndicator(
                        color: ThixPolicy.primary,
                        onRefresh: () async {
                          HapticFeedback.selectionClick();
                          ref.invalidate(priceAlertsProvider);
                          await Future.delayed(const Duration(milliseconds: 500));
                        },
                        child: ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: alerts.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (ctx, i) => _AlertCard(
                            alert: alerts[i],
                            onTap: () {
                              HapticFeedback.selectionClick();
                              context.push('/market/product/${alerts[i].productId}');
                            },
                            onDelete: () => _deleteAlert(alerts[i]),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_searching) {
      return const Center(child: CircularProgressIndicator(color: ThixPolicy.primary));
    }

    if (_searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off_rounded, size: 64, color: ThixPolicy.textDisabled),
            const SizedBox(height: 16),
            Text(
              'Aucun produit pour',
              style: ThixPolicy.h3Style.copyWith(fontWeight: ThixPolicy.bold, color: ThixPolicy.textMain),
            ),
            const SizedBox(height: 4),
            Text(
              '« $_query »',
              style: ThixPolicy.bodyStyle.copyWith(color: ThixPolicy.textMuted),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _searchResults.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final product = _searchResults[i];
        if (!_PriceAlertsValidators.isValidId(product.id)) return const SizedBox.shrink();

        return Semantics(
          button: true,
          label: 'Créer alerte pour ${product.title}, prix actuel ${product.price.toInt()} ${product.symbol}',
          child: Material(
            color: ThixPolicy.card,
            borderRadius: BorderRadius.circular(ThixPolicy.rLg),
            child: InkWell(
              borderRadius: BorderRadius.circular(ThixPolicy.rLg),
              onTap: _creatingAlert ? null : () => _createAlert(product),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(ThixPolicy.rLg),
                  border: Border.all(color: ThixPolicy.border),
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(ThixPolicy.rSm),
                      child: product.imageUrl == null
                          ? Container(
                              width: 56,
                              height: 56,
                              color: ThixPolicy.surfaceSoft,
                              child: const Icon(Icons.image_not_supported_outlined, color: ThixPolicy.textMuted, size: 28),
                            )
                          : CachedNetworkImage(
                              imageUrl: product.imageUrl!,
                              width: 56,
                              height: 56,
                              fit: BoxFit.cover,
                              placeholder: (_, __) => Container(
                                width: 56,
                                height: 56,
                                color: ThixPolicy.surfaceSoft,
                                child: const Center(child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))),
                              ),
                              errorWidget: (_, __, ___) => Container(
                                width: 56,
                                height: 56,
                                color: ThixPolicy.surfaceSoft,
                                child: const Icon(Icons.broken_image_outlined, color: ThixPolicy.textMuted, size: 28),
                              ),
                            ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            product.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: ThixPolicy.labelStyle.copyWith(fontWeight: ThixPolicy.bold, fontSize: 14, color: ThixPolicy.textMain),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            product.shopName,
                            style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.textMuted),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${product.price.toInt()} ${product.symbol}',
                            style: ThixPolicy.labelStyle.copyWith(fontWeight: ThixPolicy.bold, fontSize: 14, color: ThixPolicy.danger),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: ThixPolicy.gold.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(ThixPolicy.rMd),
                      ),
                      child: const Icon(Icons.notifications_active_rounded, color: ThixPolicy.gold, size: 22),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ============================================================================
// COMPOSANTS
// ============================================================================

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final String query;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const _SearchBar({
    required this.controller,
    required this.query,
    required this.onChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: ThixPolicy.card,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Semantics(
        label: 'Rechercher un produit pour créer une alerte',
        child: TextField(
          controller: controller,
          onChanged: onChanged,
          textInputAction: TextInputAction.search,
          style: ThixPolicy.bodyStyle.copyWith(color: ThixPolicy.textMain),
          decoration: InputDecoration(
            hintText: 'Rechercher un produit pour créer une alerte...',
            hintStyle: ThixPolicy.bodySmallStyle.copyWith(color: ThixPolicy.textMuted, fontSize: 14),
            prefixIcon: const Icon(Icons.search_rounded, color: ThixPolicy.textMuted),
            suffixIcon: query.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20, color: ThixPolicy.textMuted),
                    tooltip: 'Effacer',
                    onPressed: onClear,
                  )
                : null,
            filled: true,
            fillColor: ThixPolicy.surfaceSoft,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(ThixPolicy.rLg), borderSide: BorderSide.none),
          ),
        ),
      ),
    );
  }
}

class _AlertCard extends StatelessWidget {
  final PriceAlert alert;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _AlertCard({
    required this.alert,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final reached = alert.isReached;
    final unavailable = alert.isProductUnavailable;

    return Semantics(
      button: true,
      label: 'Alerte ${alert.title}, cible ${alert.targetPrice.toInt()} ${alert.symbol}, '
          'actuel ${alert.currentPrice.toInt()} ${alert.symbol}, ${reached ? "objectif atteint" : "en surveillance"}',
      child: Dismissible(
        key: Key(alert.id),
        direction: DismissDirection.endToStart,
        confirmDismiss: (_) async {
          // Trigger confirmation dialog
          onDelete();
          return false; // On gère nous-mêmes la suppression après confirmation
        },
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          decoration: BoxDecoration(
            color: ThixPolicy.danger.withOpacity(0.1),
            borderRadius: BorderRadius.circular(ThixPolicy.rLg),
          ),
          child: const Icon(Icons.delete_outline_rounded, color: ThixPolicy.danger, size: 24),
        ),
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              color: ThixPolicy.card,
              borderRadius: BorderRadius.circular(ThixPolicy.rLg),
              border: Border.all(
                color: reached ? ThixPolicy.success.withOpacity(0.5) : ThixPolicy.border,
                width: reached ? 1.5 : 1,
              ),
              boxShadow: ThixPolicy.shadowSoft(opacity: 0.03),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(ThixPolicy.rMd),
                        child: alert.imageUrl == null
                            ? Container(
                                width: 80,
                                height: 80,
                                color: ThixPolicy.surfaceSoft,
                                child: const Icon(Icons.image_not_supported_outlined, color: ThixPolicy.textMuted, size: 28),
                              )
                            : CachedNetworkImage(
                                imageUrl: alert.imageUrl!,
                                width: 80,
                                height: 80,
                                fit: BoxFit.cover,
                                placeholder: (_, __) => Container(
                                  width: 80,
                                  height: 80,
                                  color: ThixPolicy.surfaceSoft,
                                  child: const Center(child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))),
                                ),
                                errorWidget: (_, __, ___) => Container(
                                  width: 80,
                                  height: 80,
                                  color: ThixPolicy.surfaceSoft,
                                  child: const Icon(Icons.broken_image_outlined, color: ThixPolicy.textMuted, size: 28),
                                ),
                              ),
                      ),
                      if (reached)
                        Positioned(
                          top: 4,
                          left: 4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: ThixPolicy.success,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'ATTEINT',
                              style: ThixPolicy.microStyle.copyWith(
                                color: Colors.white,
                                fontWeight: ThixPolicy.bold,
                                fontSize: 8,
                              ),
                            ),
                          ),
                        ),
                      if (unavailable && !reached)
                        Positioned(
                          top: 4,
                          left: 4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: ThixPolicy.textMuted,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'INDISPO',
                              style: ThixPolicy.microStyle.copyWith(
                                color: Colors.white,
                                fontWeight: ThixPolicy.bold,
                                fontSize: 8,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          alert.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: ThixPolicy.labelStyle.copyWith(
                            fontSize: 13,
                            fontWeight: ThixPolicy.bold,
                            color: ThixPolicy.textMain,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.storefront_rounded, size: 12, color: ThixPolicy.textMuted),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                alert.shopName,
                                style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.textMuted, fontSize: 11),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Prix ciblé',
                                  style: ThixPolicy.microStyle.copyWith(color: ThixPolicy.textMuted, fontSize: 9),
                                ),
                                Text(
                                  '${alert.targetPrice.toInt()} ${alert.symbol}',
                                  style: ThixPolicy.captionStyle.copyWith(fontWeight: ThixPolicy.semiBold, fontSize: 12),
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  'Prix actuel',
                                  style: ThixPolicy.microStyle.copyWith(color: ThixPolicy.textMuted, fontSize: 9),
                                ),
                                Text(
                                  unavailable ? 'N/A' : '${alert.currentPrice.toInt()} ${alert.symbol}',
                                  style: ThixPolicy.labelStyle.copyWith(
                                    fontWeight: ThixPolicy.bold,
                                    fontSize: 16,
                                    color: unavailable
                                        ? ThixPolicy.textMuted
                                        : reached
                                            ? ThixPolicy.success
                                            : ThixPolicy.danger,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          decoration: BoxDecoration(
                            color: unavailable
                                ? ThixPolicy.textMuted.withOpacity(0.1)
                                : reached
                                    ? ThixPolicy.success.withOpacity(0.1)
                                    : ThixPolicy.gold.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                unavailable
                                    ? Icons.remove_shopping_cart_rounded
                                    : reached
                                        ? Icons.check_circle_outline_rounded
                                        : Icons.schedule_rounded,
                                size: 14,
                                color: unavailable
                                    ? ThixPolicy.textMuted
                                    : reached
                                        ? ThixPolicy.success
                                        : ThixPolicy.gold,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                unavailable
                                    ? 'Produit indisponible'
                                    : reached
                                        ? 'Objectif atteint !'
                                        : 'En surveillance...',
                                style: ThixPolicy.captionStyle.copyWith(
                                  fontSize: 10,
                                  fontWeight: ThixPolicy.bold,
                                  color: unavailable
                                      ? ThixPolicy.textMuted
                                      : reached
                                          ? ThixPolicy.success
                                          : ThixPolicy.gold,
                                ),
                              ),
                              if (reached && !unavailable) ...[
                                const SizedBox(width: 4),
                                Text(
                                  '(-${alert.discountPercent.toStringAsFixed(0)}%)',
                                  style: ThixPolicy.captionStyle.copyWith(
                                    fontSize: 10,
                                    fontWeight: ThixPolicy.bold,
                                    color: ThixPolicy.success,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
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

class _CreateAlertSheet extends StatelessWidget {
  final SearchResult product;
  final TextEditingController controller;

  const _CreateAlertSheet({required this.product, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        decoration: BoxDecoration(
          color: ThixPolicy.card,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: ThixPolicy.border, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: ThixPolicy.gold.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.notifications_active_rounded, color: ThixPolicy.gold, size: 18),
                ),
                const SizedBox(width: 10),
                Text(
                  'Créer une alerte de prix',
                  style: ThixPolicy.h3Style.copyWith(fontWeight: ThixPolicy.bold, color: ThixPolicy.textMain),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              product.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: ThixPolicy.labelStyle.copyWith(fontSize: 14, color: ThixPolicy.textSecondary, fontWeight: ThixPolicy.semiBold),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  'Prix actuel : ',
                  style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.textMuted),
                ),
                Text(
                  '${product.price.toInt()} ${product.symbol}',
                  style: ThixPolicy.captionStyle.copyWith(fontWeight: ThixPolicy.bold, color: ThixPolicy.danger),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              'Prix cible (notification en dessous)',
              style: ThixPolicy.labelStyle.copyWith(fontSize: 13, fontWeight: ThixPolicy.bold, color: ThixPolicy.textMain),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              autofocus: true,
              style: ThixPolicy.titleStyle.copyWith(fontWeight: ThixPolicy.bold, fontSize: 18),
              decoration: InputDecoration(
                suffixText: product.symbol,
                suffixStyle: ThixPolicy.labelStyle.copyWith(fontWeight: ThixPolicy.bold, color: ThixPolicy.textMuted),
                hintText: '0',
                filled: true,
                fillColor: ThixPolicy.surfaceSoft,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(ThixPolicy.rLg), borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(ThixPolicy.rLg),
                  borderSide: const BorderSide(color: ThixPolicy.primary, width: 1.5),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: ThixPolicy.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rLg)),
                ),
                child: Text(
                  'Créer l\'alerte',
                  style: ThixPolicy.labelStyle.copyWith(fontWeight: ThixPolicy.bold, fontSize: 16, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

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
                color: ThixPolicy.gold.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.notifications_active_outlined, size: 64, color: ThixPolicy.gold),
            ),
            const SizedBox(height: 24),
            Text(
              'Aucune alerte de prix',
              style: ThixPolicy.h2Style.copyWith(fontWeight: ThixPolicy.bold, color: ThixPolicy.textMain),
            ),
            const SizedBox(height: 8),
            Text(
              'Recherchez un produit ci-dessus\net créez une alerte de prix.',
              textAlign: TextAlign.center,
              style: ThixPolicy.bodySmallStyle.copyWith(color: ThixPolicy.textMuted, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}

class _SkeletonList extends StatelessWidget {
  const _SkeletonList();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: 4,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, __) => Container(
        height: 120,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: ThixPolicy.card,
          borderRadius: BorderRadius.circular(ThixPolicy.rLg),
        ),
        child: Row(
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(ThixPolicy.rMd)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(height: 14, width: double.infinity, color: Colors.grey.shade200),
                  const SizedBox(height: 8),
                  Container(height: 10, width: 120, color: Colors.grey.shade200),
                  const SizedBox(height: 12),
                  Container(height: 16, width: 100, color: Colors.grey.shade200),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: ThixPolicy.danger.withOpacity(0.1), shape: BoxShape.circle),
              child: const Icon(Icons.error_outline_rounded, size: 56, color: ThixPolicy.danger),
            ),
            const SizedBox(height: 20),
            Text('Erreur de chargement', style: ThixPolicy.h3Style.copyWith(fontWeight: ThixPolicy.bold, color: ThixPolicy.textMain)),
            const SizedBox(height: 8),
            Text(message, style: ThixPolicy.bodySmallStyle.copyWith(color: ThixPolicy.textSecondary), textAlign: TextAlign.center),
            const SizedBox(height: 24),
            Semantics(
              button: true,
              label: 'Réessayer',
              child: ElevatedButton.icon(
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  onRetry();
                },
                icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                label: const Text('Réessayer', style: TextStyle(fontWeight: ThixPolicy.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: ThixPolicy.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rFull)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
