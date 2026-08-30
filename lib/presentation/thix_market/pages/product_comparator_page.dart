// lib/presentation/thix_market/pages/product_comparator_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import 'package:html/parser.dart' as html_parser;

import 'package:thix_id/core/theme/thix_design_policy.dart';
import '../providers/market_providers.dart';
import '../cart/cart_provider.dart';

// ============================================================================
// CONSTANTES
// ============================================================================
const Duration _kRequestTimeout = Duration(seconds: 15);
const Duration _kRetryDelay = Duration(milliseconds: 400);
const Duration _kSearchDebounce = Duration(milliseconds: 350);
const int _kMaxComparisonItems = 4;
const int _kMaxSearchResults = 30;
const int _kMaxQueryLength = 100;

// ============================================================================
// VALIDATEURS
// ============================================================================
class _ComparatorValidators {
  _ComparatorValidators._();

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
    final val = (price as num?)?.toDouble() ?? 0.0;
    return val < 0 || val.isNaN || val.isInfinite ? 0.0 : val;
  }

  static double safeRating(dynamic rating) {
    if (rating == null) return 0.0;
    final val = (rating as num?)?.toDouble() ?? 0.0;
    return val.clamp(0.0, 5.0);
  }

  static int safeStock(dynamic stock) {
    if (stock == null) return 0;
    final val = (stock as num?)?.toInt() ?? 0;
    return val < 0 ? 0 : val;
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
        debugPrint('[Comparator] ❌ $label: timeout after $attempt attempts');
        throw TimeoutException('$label: délai dépassé');
      }
      debugPrint('[Comparator] ⏱️ $label timeout — retry $attempt/$maxRetries');
      await Future.delayed(_kRetryDelay);
    } catch (e) {
      debugPrint('[Comparator] ❌ $label error: $e');
      rethrow;
    }
  }
}

// ============================================================================
// MODÈLE
// ============================================================================
class ComparisonProduct {
  final String id;
  final String title;
  final double price;
  final String currency;
  final String? imageUrl;
  final String? brand;
  final double rating;
  final String? condition;
  final int stock;
  final String shopName;

  const ComparisonProduct({
    required this.id,
    required this.title,
    required this.price,
    required this.currency,
    this.imageUrl,
    this.brand,
    required this.rating,
    this.condition,
    required this.stock,
    required this.shopName,
  });

  bool get isAvailable => stock > 0;
  String get symbol => _ComparatorValidators.parseCurrency(currency);

  factory ComparisonProduct.fromMap(Map<String, dynamic> map) {
    final shop = map['shop'];
    return ComparisonProduct(
      id: map['id']?.toString() ?? '',
      title: _ComparatorValidators.sanitize(map['title']?.toString() ?? 'Produit', maxLength: 80),
      price: _ComparatorValidators.safePrice(map['price']),
      currency: map['currency']?.toString() ?? 'FC',
      imageUrl: _ComparatorValidators.sanitizeUrl(map['image_url']?.toString()),
      brand: _ComparatorValidators.sanitize(map['brand']?.toString(), maxLength: 40),
      rating: _ComparatorValidators.safeRating(map['rating']),
      condition: _ComparatorValidators.sanitize(map['condition']?.toString(), maxLength: 30),
      stock: _ComparatorValidators.safeStock(map['stock']),
      shopName: _ComparatorValidators.sanitize(
        shop is Map ? shop['name']?.toString() : null,
        maxLength: 40,
      ),
    );
  }
}

// ============================================================================
// STATE : IDs sélectionnés
// ============================================================================
class ComparatorNotifier extends StateNotifier<List<String>> {
  ComparatorNotifier() : super([]);

  bool add(String id) {
    if (!_ComparatorValidators.isValidId(id)) {
      debugPrint('[Comparator] ⚠️ Reject invalid ID: $id');
      return false;
    }
    if (state.contains(id)) return false;
    if (state.length >= _kMaxComparisonItems) return false;
    state = [...state, id];
    debugPrint('[Comparator] ➕ Added $id (total: ${state.length})');
    return true;
  }

  bool remove(String id) {
    if (!state.contains(id)) return false;
    state = state.where((e) => e != id).toList();
    debugPrint('[Comparator] ➖ Removed $id (total: ${state.length})');
    return true;
  }

  void toggle(String id) {
    if (state.contains(id)) {
      remove(id);
    } else {
      add(id);
    }
  }

  void clear() {
    state = [];
    debugPrint('[Comparator] 🗑️ Cleared all');
  }

  bool contains(String id) => state.contains(id);
  bool get isFull => state.length >= _kMaxComparisonItems;
}

final comparatorIdsProvider =
    StateNotifierProvider<ComparatorNotifier, List<String>>(
  (ref) => ComparatorNotifier(),
);

// ============================================================================
// PROVIDER produits sélectionnés (avec retry + typed model)
// ============================================================================
final comparatorSelectedProductsProvider =
    FutureProvider.autoDispose<List<ComparisonProduct>>((ref) async {
  final ids = ref.watch(comparatorIdsProvider);
  if (ids.isEmpty) return [];

  final validIds = ids.where(_ComparatorValidators.isValidId).toList();
  if (validIds.isEmpty) return [];

  debugPrint('[Comparator] 📦 Loading ${validIds.length} selected products');

  final db = ref.read(supabaseClientProvider);
  try {
    final res = await _withRetry(
      () => db
          .from('products')
          .select('*, shop:shops(name)')
          .inFilter('id', validIds),
      label: 'fetchComparisonProducts',
    );

    final list = List<Map<String, dynamic>>.from(res);
    // Conserver l'ordre de sélection
    list.sort((a, b) => validIds
        .indexOf(a['id'].toString())
        .compareTo(validIds.indexOf(b['id'].toString())));

    final products = list.map((m) => ComparisonProduct.fromMap(m)).toList();
    debugPrint('[Comparator] ✓ Loaded ${products.length} products');
    return products;
  } catch (e) {
    debugPrint('[Comparator] ❌ Load products error: $e');
    return [];
  }
});

// ============================================================================
// PAGE
// ============================================================================
class ProductComparatorPage extends ConsumerStatefulWidget {
  const ProductComparatorPage({super.key});

  @override
  ConsumerState<ProductComparatorPage> createState() => _ProductComparatorPageState();
}

class _ProductComparatorPageState extends ConsumerState<ProductComparatorPage> {
  final TextEditingController _searchCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  Timer? _debounceTimer;
  String _query = '';
  bool _searching = false;
  List<ComparisonProduct> _searchResults = [];
  final Set<String> _addingToCart = {};

  @override
  void initState() {
    super.initState();
    debugPrint('[Comparator] ⚖️ Page opened');
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    debugPrint('[Comparator] 👋 Page disposed');
    super.dispose();
  }

  void _onQueryChanged(String v) {
    _debounceTimer?.cancel();
    final sanitized = _ComparatorValidators.sanitize(v, maxLength: _kMaxQueryLength);

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
      if (_searchCtrl.text.trim() == sanitized) {
        _search(sanitized);
      }
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
            .select('id, title, price, currency, image_url, brand, rating, condition, stock, shop:shops(name)')
            .ilike('title', '%$q%')
            .limit(_kMaxSearchResults),
        label: 'searchProducts["$q"]',
      );

      if (!mounted) return;
      final products = (res as List)
          .map((m) => ComparisonProduct.fromMap(Map<String, dynamic>.from(m as Map)))
          .toList();

      setState(() {
        _searchResults = products;
        _searching = false;
      });
      debugPrint('[Comparator] 🔍 Found ${products.length} results for "$q"');
    } catch (e) {
      debugPrint('[Comparator] ❌ Search error: $e');
      if (mounted) {
        setState(() {
          _searchResults = [];
          _searching = false;
        });
        _showError('Erreur lors de la recherche');
      }
    }
  }

  Future<void> _addToCart(ComparisonProduct product) async {
    if (_addingToCart.contains(product.id)) return;

    if (!product.isAvailable) {
      _showError('Ce produit est en rupture de stock');
      return;
    }

    final db = ref.read(supabaseClientProvider);
    final uid = db.auth.currentUser?.id;

    if (uid == null) {
      HapticFeedback.lightImpact();
      context.push('/login');
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() => _addingToCart.add(product.id));

    try {
      // Vérifier si déjà dans panier
      final existing = await _withRetry(
        () => db
            .from('cart')
            .select('id')
            .eq('user_id', uid)
            .eq('product_id', product.id)
            .maybeSingle(),
        label: 'checkCart',
      );

      if (existing != null) {
        _showInfo('Déjà dans votre panier');
      } else {
        await _withRetry(
          () => db.from('cart').insert({
            'user_id': uid,
            'product_id': product.id,
            'quantity': 1,
          }),
          label: 'addToCart',
        );
        ref.invalidate(cartProvider);
        _showSuccess('Ajouté au panier !');
        debugPrint('[Comparator] 🛒 Added ${product.id} to cart');
      }
    } catch (e) {
      debugPrint('[Comparator] ❌ Add to cart error: $e');
      _showError('Erreur lors de l\'ajout au panier');
    } finally {
      if (mounted) setState(() => _addingToCart.remove(product.id));
    }
  }

  void _shareComparison(List<ComparisonProduct> products) {
    HapticFeedback.selectionClick();
    final lines = products.map((p) => '• ${p.title} — ${p.price.toInt()} ${p.symbol}').join('\n');
    Share.share(
      '⚖️ Comparaison THIX Market :\n$lines\n\nDécouvrez sur https://thix.app/market/compare',
      subject: 'Comparaison produits THIX',
    );
    debugPrint('[Comparator] 📤 Shared ${products.length} products');
  }

  Future<void> _confirmRemove(String id, String title) async {
    HapticFeedback.lightImpact();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rLg)),
        title: Text('Retirer de la comparaison ?', style: ThixPolicy.h3Style.copyWith(fontWeight: ThixPolicy.bold)),
        content: Text('"$title" sera retiré de votre comparaison.', style: ThixPolicy.bodyStyle),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Annuler', style: ThixPolicy.labelStyle.copyWith(color: ThixPolicy.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: ThixPolicy.danger, foregroundColor: Colors.white),
            child: const Text('Retirer'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      ref.read(comparatorIdsProvider.notifier).remove(id);
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

  void _showInfo(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          const Icon(Icons.info_outline_rounded, color: Colors.white, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(message)),
        ]),
        backgroundColor: ThixPolicy.primary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedIds = ref.watch(comparatorIdsProvider);
    final selectedAsync = ref.watch(comparatorSelectedProductsProvider);

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
          'Comparateur B2B',
          style: ThixPolicy.h3Style.copyWith(
            color: ThixPolicy.textMain,
            fontWeight: ThixPolicy.bold,
            fontSize: 18,
          ),
        ),
        actions: [
          if (selectedIds.length >= 2)
            IconButton(
              icon: const Icon(Icons.share_rounded, color: ThixPolicy.textMain),
              tooltip: 'Partager la comparaison',
              onPressed: () {
                final products = selectedAsync.valueOrNull ?? [];
                if (products.isNotEmpty) _shareComparison(products);
              },
            ),
          if (selectedIds.isNotEmpty)
            TextButton(
              onPressed: () {
                HapticFeedback.mediumImpact();
                ref.read(comparatorIdsProvider.notifier).clear();
              },
              child: Text(
                'Vider',
                style: ThixPolicy.labelStyle.copyWith(
                  color: ThixPolicy.danger,
                  fontWeight: ThixPolicy.bold,
                ),
              ),
            ),
        ],
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

          // Compteur sélection
          if (selectedIds.isNotEmpty)
            Container(
              width: double.infinity,
              color: ThixPolicy.gold.withOpacity(0.08),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  const Icon(Icons.compare_arrows_rounded, color: ThixPolicy.gold, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    '${selectedIds.length}/$_kMaxComparisonItems produit(s) sélectionné(s)',
                    style: ThixPolicy.labelStyle.copyWith(
                      fontWeight: ThixPolicy.bold,
                      color: ThixPolicy.textMain,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),

          Expanded(
            child: _query.isNotEmpty
                ? _buildSearchResults(selectedIds)
                : selectedAsync.when(
                    loading: () => const _SkeletonTable(),
                    error: (e, _) => _ErrorState(
                      message: _ComparatorValidators.sanitize(e.toString(), maxLength: 200),
                      onRetry: () => ref.invalidate(comparatorSelectedProductsProvider),
                    ),
                    data: (products) {
                      if (products.length < 2) {
                        return _EmptyState(
                          products: products,
                          onRemove: (id, title) => _confirmRemove(id, title),
                        );
                      }
                      return _ComparisonTable(
                        products: products,
                        onRemove: (id, title) => _confirmRemove(id, title),
                        onAddToCart: _addToCart,
                        addingToCart: _addingToCart,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults(List<String> selectedIds) {
    if (_searching) {
      return const Center(child: CircularProgressIndicator(color: ThixPolicy.primary));
    }

    if (_searchResults.isEmpty) {
      return _EmptySearchState(query: _query);
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _searchResults.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final product = _searchResults[i];
        final selected = selectedIds.contains(product.id);
        final notifier = ref.read(comparatorIdsProvider.notifier);
        final canAdd = selected || !notifier.isFull;

        return Semantics(
          button: true,
          label: '${product.title}, ${product.price.toInt()} ${product.symbol}, ${selected ? "sélectionné" : "non sélectionné"}',
          selected: selected,
          child: Material(
            color: ThixPolicy.card,
            borderRadius: BorderRadius.circular(ThixPolicy.rLg),
            child: InkWell(
              borderRadius: BorderRadius.circular(ThixPolicy.rLg),
              onTap: () {
                if (selected) {
                  HapticFeedback.selectionClick();
                  notifier.remove(product.id);
                } else if (!canAdd) {
                  HapticFeedback.lightImpact();
                  _showError('Maximum $_kMaxComparisonItems produits');
                } else {
                  HapticFeedback.mediumImpact();
                  notifier.add(product.id);
                }
              },
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(ThixPolicy.rLg),
                  border: Border.all(
                    color: selected ? ThixPolicy.primary : ThixPolicy.border,
                    width: selected ? 2 : 1,
                  ),
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
                                child: const Center(
                                  child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: ThixPolicy.primary)),
                                ),
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
                            style: ThixPolicy.labelStyle.copyWith(
                              fontWeight: ThixPolicy.bold,
                              fontSize: 14,
                              color: ThixPolicy.textMain,
                            ),
                          ),
                          if (product.brand != null && product.brand!.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              product.brand!,
                              style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.textMuted),
                            ),
                          ],
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Text(
                                '${product.price.toInt()} ${product.symbol}',
                                style: ThixPolicy.labelStyle.copyWith(
                                  fontWeight: ThixPolicy.bold,
                                  fontSize: 14,
                                  color: ThixPolicy.danger,
                                ),
                              ),
                              if (!product.isAvailable) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: ThixPolicy.danger.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'Rupture',
                                    style: ThixPolicy.microStyle.copyWith(
                                      color: ThixPolicy.danger,
                                      fontWeight: ThixPolicy.bold,
                                      fontSize: 9,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: selected ? ThixPolicy.primary : Colors.transparent,
                        border: Border.all(
                          color: selected ? ThixPolicy.primary : ThixPolicy.border,
                          width: 2,
                        ),
                      ),
                      child: selected ? const Icon(Icons.check_rounded, size: 16, color: Colors.white) : null,
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
        label: 'Rechercher un produit à comparer',
        child: TextField(
          controller: controller,
          onChanged: onChanged,
          textInputAction: TextInputAction.search,
          style: ThixPolicy.bodyStyle.copyWith(color: ThixPolicy.textMain),
          decoration: InputDecoration(
            hintText: 'Rechercher un produit à comparer...',
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
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(ThixPolicy.rLg),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ),
    );
  }
}

class _ComparisonTable extends StatelessWidget {
  final List<ComparisonProduct> products;
  final void Function(String id, String title) onRemove;
  final Future<void> Function(ComparisonProduct p) onAddToCart;
  final Set<String> addingToCart;

  const _ComparisonTable({
    required this.products,
    required this.onRemove,
    required this.onAddToCart,
    required this.addingToCart,
  });

  // Calcul du "meilleur" par feature
  int? _bestPriceIndex() {
    if (products.isEmpty) return null;
    final available = products.where((p) => p.isAvailable && p.price > 0).toList();
    if (available.isEmpty) return null;
    final min = available.reduce((a, b) => a.price < b.price ? a : b);
    return products.indexOf(min);
  }

  int? _bestRatingIndex() {
    if (products.isEmpty) return null;
    final rated = products.where((p) => p.rating > 0).toList();
    if (rated.isEmpty) return null;
    final max = rated.reduce((a, b) => a.rating > b.rating ? a : b);
    return products.indexOf(max);
  }

  @override
  Widget build(BuildContext context) {
    final bestPriceIdx = _bestPriceIndex();
    final bestRatingIdx = _bestRatingIndex();

    final features = <_Feature>[
      _Feature(label: 'Prix', key: 'price', bestIndex: bestPriceIdx, highlightColor: ThixPolicy.success),
      _Feature(label: 'Marque', key: 'brand'),
      _Feature(label: 'Évaluation', key: 'rating', bestIndex: bestRatingIdx, highlightColor: ThixPolicy.gold),
      _Feature(label: 'État', key: 'condition'),
      _Feature(label: 'Stock', key: 'stock'),
      _Feature(label: 'Boutique', key: 'shop'),
    ];

    return SingleChildScrollView(
      child: Column(
        children: [
          Container(
            color: ThixPolicy.card,
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(width: 80),
                ...products.map((p) => Expanded(child: _ProductHeader(product: p, onRemove: onRemove, onAddToCart: onAddToCart, isAdding: addingToCart.contains(p.id)))),
              ],
            ),
          ),
          const Divider(height: 1, color: ThixPolicy.border),
          ...features.map((f) => _FeatureRow(feature: f, products: products)),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _Feature {
  final String label;
  final String key;
  final int? bestIndex;
  final Color? highlightColor;

  const _Feature({required this.label, required this.key, this.bestIndex, this.highlightColor});
}

class _ProductHeader extends StatelessWidget {
  final ComparisonProduct product;
  final void Function(String id, String title) onRemove;
  final Future<void> Function(ComparisonProduct p) onAddToCart;
  final bool isAdding;

  const _ProductHeader({
    required this.product,
    required this.onRemove,
    required this.onAddToCart,
    required this.isAdding,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.topRight,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: double.infinity,
                  height: 90,
                  color: ThixPolicy.surfaceSoft,
                  child: product.imageUrl == null
                      ? const Icon(Icons.image_not_supported_outlined, color: ThixPolicy.textMuted, size: 28)
                      : CachedNetworkImage(
                          imageUrl: product.imageUrl!,
                          fit: BoxFit.contain,
                          placeholder: (_, __) => const Center(child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))),
                          errorWidget: (_, __, ___) => const Icon(Icons.broken_image_outlined, color: ThixPolicy.textMuted, size: 28),
                        ),
                ),
              ),
              Semantics(
                button: true,
                label: 'Retirer ${product.title}',
                child: GestureDetector(
                  onTap: () => onRemove(product.id, product.title),
                  child: Container(
                    margin: const EdgeInsets.all(4),
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: ThixPolicy.shadowSoft(opacity: 0.15),
                    ),
                    child: const Icon(Icons.close_rounded, size: 14, color: ThixPolicy.danger),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Semantics(
            label: product.title,
            child: Text(
              product.title,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: ThixPolicy.captionStyle.copyWith(
                fontSize: 12,
                fontWeight: ThixPolicy.bold,
                height: 1.2,
                color: ThixPolicy.textMain,
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 32,
            child: Semantics(
              button: true,
              label: product.isAvailable ? 'Ajouter ${product.title} au panier' : 'Indisponible',
              enabled: product.isAvailable && !isAdding,
              child: ElevatedButton(
                onPressed: product.isAvailable && !isAdding ? () => onAddToCart(product) : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: product.isAvailable ? ThixPolicy.danger : ThixPolicy.textDisabled,
                  disabledBackgroundColor: ThixPolicy.textDisabled,
                  padding: EdgeInsets.zero,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: isAdding
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Icon(
                        product.isAvailable ? Icons.shopping_cart_checkout_rounded : Icons.remove_shopping_cart_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final _Feature feature;
  final List<ComparisonProduct> products;

  const _FeatureRow({required this.feature, required this.products});

  String _getValue(ComparisonProduct p) {
    switch (feature.key) {
      case 'price':
        return p.price > 0 ? '${p.price.toInt()} ${p.symbol}' : 'N/A';
      case 'brand':
        return p.brand != null && p.brand!.isNotEmpty ? p.brand! : '—';
      case 'rating':
        return p.rating > 0 ? '⭐ ${p.rating.toStringAsFixed(1)}' : '—';
      case 'condition':
        return p.condition != null && p.condition!.isNotEmpty ? p.condition! : '—';
      case 'stock':
        return p.isAvailable ? '${p.stock} en stock' : 'Rupture';
      case 'shop':
        return p.shopName.isNotEmpty ? p.shopName : '—';
      default:
        return '—';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: ThixPolicy.border)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Text(
                feature.label,
                style: ThixPolicy.captionStyle.copyWith(
                  fontSize: 11,
                  fontWeight: ThixPolicy.bold,
                  color: ThixPolicy.textMuted,
                ),
              ),
            ),
          ),
          ...List.generate(products.length, (i) {
            final p = products[i];
            final value = _getValue(p);
            final isBest = feature.bestIndex == i;
            final isPrice = feature.key == 'price';
            final isStockOut = feature.key == 'stock' && !p.isAvailable;

            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Container(
                  padding: isBest ? const EdgeInsets.symmetric(horizontal: 6, vertical: 3) : EdgeInsets.zero,
                  decoration: isBest && feature.highlightColor != null
                      ? BoxDecoration(
                          color: feature.highlightColor!.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: feature.highlightColor!.withOpacity(0.4)),
                        )
                      : null,
                  child: Text(
                    value,
                    textAlign: TextAlign.center,
                    style: ThixPolicy.labelStyle.copyWith(
                      fontSize: 13,
                      fontWeight: isPrice || isBest ? ThixPolicy.bold : ThixPolicy.semiBold,
                      color: isStockOut
                          ? ThixPolicy.danger
                          : isPrice
                              ? ThixPolicy.danger
                              : isBest
                                  ? feature.highlightColor ?? ThixPolicy.textMain
                                  : ThixPolicy.textMain,
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final List<ComparisonProduct> products;
  final void Function(String id, String title) onRemove;

  const _EmptyState({required this.products, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final hasOne = products.length == 1;

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
              child: const Icon(Icons.compare_arrows_rounded, size: 64, color: ThixPolicy.gold),
            ),
            const SizedBox(height: 24),
            Text(
              hasOne ? 'Ajoutez un autre produit' : 'Comparateur B2B',
              style: ThixPolicy.h2Style.copyWith(
                fontSize: 20,
                fontWeight: ThixPolicy.bold,
                color: ThixPolicy.textMain,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              hasOne
                  ? 'Il vous faut au moins 2 produits pour comparer.'
                  : 'Recherchez des produits ci-dessus\net sélectionnez-en jusqu\'à $_kMaxComparisonItems pour comparer.',
              textAlign: TextAlign.center,
              style: ThixPolicy.bodySmallStyle.copyWith(
                color: ThixPolicy.textMuted,
                height: 1.4,
              ),
            ),
            if (products.isNotEmpty) ...[
              const SizedBox(height: 24),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: products.map((p) {
                  return Semantics(
                    label: '${p.title}, cliquer pour retirer',
                    child: Chip(
                      label: Text(p.title, style: ThixPolicy.captionStyle.copyWith(fontWeight: ThixPolicy.semiBold)),
                      deleteIcon: const Icon(Icons.close_rounded, size: 16),
                      onDeleted: () => onRemove(p.id, p.title),
                      backgroundColor: ThixPolicy.gold.withOpacity(0.1),
                      side: BorderSide(color: ThixPolicy.gold.withOpacity(0.4)),
                    ),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _EmptySearchState extends StatelessWidget {
  final String query;
  const _EmptySearchState({required this.query});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off_rounded, size: 64, color: ThixPolicy.textDisabled),
          const SizedBox(height: 16),
          Text(
            'Aucun produit trouvé',
            style: ThixPolicy.h3Style.copyWith(fontWeight: ThixPolicy.bold, color: ThixPolicy.textMain),
          ),
          const SizedBox(height: 8),
          Text(
            'pour « $query »',
            style: ThixPolicy.bodySmallStyle.copyWith(color: ThixPolicy.textMuted),
          ),
        ],
      ),
    );
  }
}

class _SkeletonTable extends StatelessWidget {
  const _SkeletonTable();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              const SizedBox(width: 80),
              Expanded(
                child: Container(height: 120, decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(12))),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(height: 120, decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(12))),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...List.generate(
            5,
            (_) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(height: 20, color: Colors.grey.shade200),
            ),
          ),
        ],
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
