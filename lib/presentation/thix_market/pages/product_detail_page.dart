// lib/presentation/thix_market/pages/product_detail_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:intl/intl.dart';
import 'package:html/parser.dart' as html_parser;

import 'package:thix_id/core/theme/thix_design_policy.dart';
import '../providers/market_providers.dart';
import '../checkout/checkout_page.dart';
import '../cart/cart_provider.dart';

// ============================================================================
// CONSTANTES
// ============================================================================
const Duration _kRequestTimeout = Duration(seconds: 15);
const Duration _kRetryDelay = Duration(milliseconds: 400);
const int _kMaxReviewsPreview = 3;
const int _kMaxReviewsLoad = 50;

// ============================================================================
// VALIDATEURS
// ============================================================================
class _ProductDetailValidators {
  _ProductDetailValidators._();

  static String sanitize(String? input, {int maxLength = 500}) {
    if (input == null || input.trim().isEmpty) return '';
    final doc = html_parser.parse(input);
    var s = doc.body?.text ?? input;
    s = s
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll(RegExp(r'javascript:', caseSensitive: false), '')
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

  static int clampStock(dynamic stock) {
    if (stock == null) return 0;
    final val = (stock as num?)?.toInt() ?? 0;
    return val < 0 ? 0 : val;
  }

  static double clampRating(dynamic rating) {
    if (rating == null) return 0.0;
    final val = (rating as num?)?.toDouble() ?? 0.0;
    return val.clamp(0.0, 5.0);
  }

  static String parseCurrency(String? currency) {
    final c = (currency ?? 'CDF').toString().toUpperCase().trim();
    if (c == 'USD' || c == '\$') return '\$';
    if (c == 'EUR' || c == '€') return '€';
    if (c == 'XOF' || c == 'FCFA' || c == 'FC' || c == 'CDF') return 'FC';
    return c;
  }

  static String parsePrice(num? price, String symbol) {
    if (price == null || price < 0) return 'Prix indisponible';
    return '${price.toInt()} $symbol';
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
        debugPrint('[ProductDetail] ❌ $label: timeout after $attempt attempts');
        throw TimeoutException('$label: délai dépassé');
      }
      debugPrint('[ProductDetail] ⏱️ $label timeout — retry $attempt/$maxRetries');
      await Future.delayed(_kRetryDelay);
    } catch (e) {
      debugPrint('[ProductDetail] ❌ $label error: $e');
      rethrow;
    }
  }
}

// ============================================================================
// PROVIDERS
// ============================================================================
final productDetailProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>, String>((ref, productId) async {
  debugPrint('[ProductDetail] 📦 Loading product $productId');

  final db = ref.read(supabaseClientProvider);

  // Charger produit + shop + reviews en parallèle
  final prodFuture = _withRetry(
    () => db.from('products').select().eq('id', productId).maybeSingle(),
    label: 'fetchProduct',
  );

  final prod = await prodFuture;
  if (prod == null) throw Exception('Produit introuvable');

  final shopId = prod['shop_id']?.toString();
  final shopFuture = shopId != null
      ? _withRetry(
          () => db.from('shops').select().eq('id', shopId).maybeSingle(),
          label: 'fetchShop',
        ).catchError((_) => null)
      : Future.value(null);

  final reviewsFuture = _withRetry(
    () => db
        .from('reviews')
        .select('*, user:users(name, avatar)')
        .eq('product_id', productId)
        .order('created_at', ascending: false)
        .limit(_kMaxReviewsLoad),
    label: 'fetchReviews',
  ).then((r) => List<Map<String, dynamic>>.from(r)).catchError((_) => <Map<String, dynamic>>[]);

  final results = await Future.wait([shopFuture, reviewsFuture]);
  final shop = results[0] as Map<String, dynamic>?;
  final reviews = results[1] as List<Map<String, dynamic>>;

  // Calculer rating moyen
  double rating = 0;
  if (reviews.isNotEmpty) {
    double sum = 0;
    for (final rev in reviews) {
      sum += _ProductDetailValidators.clampRating(rev['rating']);
    }
    rating = sum / reviews.length;
  }

  debugPrint('[ProductDetail] ✓ Loaded product with ${reviews.length} reviews');

  return {
    ...prod,
    'shop': shop ?? {},
    'reviews': reviews,
    'reviews_count': reviews.length,
    'rating': rating,
  };
});

final storeProductsProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>((ref, shopId) async {
  final db = ref.read(supabaseClientProvider);
  final res = await _withRetry(
    () => db.from('products').select().eq('shop_id', shopId).limit(10),
    label: 'fetchStoreProducts',
  );
  return List<Map<String, dynamic>>.from(res);
});

final isFavoriteProvider =
    FutureProvider.autoDispose.family<bool, String>((ref, productId) async {
  final db = ref.read(supabaseClientProvider);
  final uid = db.auth.currentUser?.id;
  if (uid == null) return false;

  try {
    final res = await _withRetry(
      () => db
          .from('wishlist')
          .select()
          .match({'user_id': uid, 'product_id': productId})
          .maybeSingle(),
      label: 'checkFavorite',
    );
    return res != null;
  } catch (e) {
    debugPrint('[ProductDetail] ⚠️ Check favorite error: $e');
    return false;
  }
});

// ============================================================================
// PAGE
// ============================================================================
class ProductDetailPage extends ConsumerStatefulWidget {
  final String productId;
  const ProductDetailPage({super.key, required this.productId});

  @override
  ConsumerState<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends ConsumerState<ProductDetailPage> {
  int _qty = 1;
  String? _variant;
  String? _colorSel;
  bool _adding = false;
  int _imgIndex = 0;

  String _t(BuildContext context, String fr, String en) {
    final lang = Localizations.localeOf(context).languageCode;
    return lang == 'fr' ? fr : en;
  }

  Future<void> _toggleFav(bool currentlyFav) async {
    HapticFeedback.selectionClick();

    final db = ref.read(supabaseClientProvider);
    final uid = db.auth.currentUser?.id;

    if (uid == null) {
      _showError(_t(context, 'Veuillez vous connecter', 'Please log in'));
      return;
    }

    try {
      if (!currentlyFav) {
        await _withRetry(
          () => db.from('wishlist').insert({
            'user_id': uid,
            'product_id': widget.productId,
          }),
          label: 'addFavorite',
        );
        debugPrint('[ProductDetail] ❤️ Added to favorites');
      } else {
        await _withRetry(
          () => db.from('wishlist').delete().match({
            'user_id': uid,
            'product_id': widget.productId,
          }),
          label: 'removeFavorite',
        );
        debugPrint('[ProductDetail] 💔 Removed from favorites');
      }
      ref.invalidate(isFavoriteProvider(widget.productId));
    } catch (e) {
      debugPrint('[ProductDetail] ❌ Toggle favorite error: $e');
      _showError('Erreur lors de la mise à jour des favoris');
    }
  }

  Future<void> _addToCart({int maxStock = 0}) async {
    if (_adding) return; // Protection double-tap

    if (maxStock <= 0) {
      _showError(_t(context, 'Rupture de stock', 'Out of stock'));
      return;
    }

    final db = ref.read(supabaseClientProvider);
    final uid = db.auth.currentUser?.id;

    if (uid == null) {
      _showError(_t(context, 'Veuillez vous connecter', 'Please log in'));
      return;
    }

    if (_qty > maxStock) {
      _showError(_t(context, 'Stock limité à $maxStock', 'Stock limited to $maxStock'));
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() => _adding = true);

    try {
      final existing = await _withRetry(
        () => db
            .from('cart')
            .select()
            .match({'user_id': uid, 'product_id': widget.productId})
            .maybeSingle(),
        label: 'checkCart',
      );

      if (existing != null) {
        int cur = (existing['quantity'] as num?)?.toInt() ?? 0;
        final newQty = cur + _qty;
        if (newQty > maxStock) {
          _showError(_t(context, 'Stock limité à $maxStock', 'Stock limited to $maxStock'));
          return;
        }
        await _withRetry(
          () => db.from('cart').update({'quantity': newQty}).eq('id', existing['id']),
          label: 'updateCart',
        );
      } else {
        await _withRetry(
          () => db.from('cart').insert({
            'user_id': uid,
            'product_id': widget.productId,
            'quantity': _qty,
            'variant': _variant,
            'color': _colorSel,
          }),
          label: 'insertCart',
        );
      }

      _showSuccess(_t(context, 'Ajouté au panier !', 'Added to cart!'));
      ref.invalidate(cartProvider);
      debugPrint('[ProductDetail] 🛒 Added to cart: qty=$_qty, variant=$_variant, color=$_colorSel');
    } catch (e) {
      debugPrint('[ProductDetail] ❌ Add to cart error: $e');
      _showError('Erreur lors de l\'ajout au panier');
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  Future<void> _buyNow(int stock) async {
    if (stock <= 0) {
      _showError(_t(context, 'Rupture de stock', 'Out of stock'));
      return;
    }

    await _addToCart(maxStock: stock);

    if (mounted && !_adding) {
      try {
        context.push('/market/checkout');
      } catch (e) {
        debugPrint('[ProductDetail] ⚠️ Navigation fallback: $e');
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CheckoutPage()),
        );
      }
    }
  }

  void _openChat(Map<String, dynamic> product) {
    HapticFeedback.selectionClick();

    final shop = product['shop'] as Map<String, dynamic>?;
    final shopId = product['shop_id'];

    if (shopId == null) {
      _showError(_t(context, 'Boutique indisponible', 'Store unavailable'));
      return;
    }

    String name = _ProductDetailValidators.sanitize(shop?['name']?.toString() ?? 'Vendeur', maxLength: 60);
    String? avatar = _ProductDetailValidators.sanitizeUrl(shop?['logo_url']?.toString());

    context.push(
      '/market/chat/$shopId',
      extra: {'title': name, 'userName': name, 'userAvatar': avatar},
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: ThixPolicy.danger,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: ThixPolicy.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(productDetailProvider(widget.productId));
    final favAsync = ref.watch(isFavoriteProvider(widget.productId));

    return detailAsync.when(
      loading: () => _buildSkeleton(),
      error: (e, _) => _buildErrorState(e.toString()),
      data: (product) => _buildContent(product, favAsync.valueOrNull ?? false),
    );
  }

  Widget _buildSkeleton() {
    return Scaffold(
      backgroundColor: ThixPolicy.surface,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 380,
            pinned: true,
            backgroundColor: Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(color: Colors.grey.shade200),
            ),
          ),
          SliverToBoxAdapter(
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(height: 28, width: 150, color: Colors.grey.shade200),
                  const SizedBox(height: 12),
                  Container(height: 20, width: double.infinity, color: Colors.grey.shade200),
                  const SizedBox(height: 8),
                  Container(height: 14, width: 200, color: Colors.grey.shade200),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: ThixPolicy.textMain),
          onPressed: () => context.pop(),
        ),
        backgroundColor: ThixPolicy.card,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
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
              Text('Erreur de chargement', style: ThixPolicy.h3Style.copyWith(fontWeight: ThixPolicy.bold)),
              const SizedBox(height: 8),
              Text(
                _ProductDetailValidators.sanitize(error, maxLength: 200),
                style: ThixPolicy.bodySmallStyle,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => ref.invalidate(productDetailProvider(widget.productId)),
                icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                label: const Text('Réessayer'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: ThixPolicy.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rFull)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(Map<String, dynamic> product, bool isFav) {
    final imagesRaw = product['images'] as List?;
    List<String> images = [];
    if (imagesRaw != null && imagesRaw.isNotEmpty) {
      images = imagesRaw
          .map((e) => _ProductDetailValidators.sanitizeUrl(e.toString()))
          .whereType<String>()
          .toList();
    } else if (product['image_url'] != null) {
      final url = _ProductDetailValidators.sanitizeUrl(product['image_url'].toString());
      if (url != null) images = [url];
    }

    if (images.isEmpty) images = []; // Pas d'image placeholder

    bool hasDiscount = product['discount_price'] != null &&
        (product['discount_price'] as num) < (product['price'] as num);

    String currency = _ProductDetailValidators.parseCurrency(product['currency']?.toString());
    String symbol = currency;

    int stock = _ProductDetailValidators.clampStock(product['stock']);
    bool available = stock > 0;

    List variants = product['variants'] is List ? product['variants'] as List : [];
    List colors = product['colors'] is List ? product['colors'] as List : [];
    List reviews = product['reviews'] is List ? product['reviews'] as List : [];

    final shopId = product['shop_id']?.toString();
    final shop = product['shop'] as Map<String, dynamic>?;

    final title = _ProductDetailValidators.sanitize(product['title']?.toString() ?? '', maxLength: 150);
    final description = _ProductDetailValidators.sanitize(product['description']?.toString() ?? '', maxLength: 2000);
    final price = (product['price'] as num?)?.toDouble();
    final discountPrice = hasDiscount ? (product['discount_price'] as num?)?.toDouble() : null;
    final rating = _ProductDetailValidators.clampRating(product['rating']);
    final reviewsCount = (product['reviews_count'] as num?)?.toInt() ?? 0;

    return Scaffold(
      backgroundColor: ThixPolicy.surface,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 380,
            pinned: true,
            backgroundColor: Colors.white,
            leading: Padding(
              padding: const EdgeInsets.all(8),
              child: _circleBtn(Icons.arrow_back_ios_new_rounded, () {
                HapticFeedback.selectionClick();
                context.pop();
              }),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.all(8),
                child: Semantics(
                  button: true,
                  label: isFav ? 'Retirer des favoris' : 'Ajouter aux favoris',
                  selected: isFav,
                  child: _circleBtn(
                    isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                    () => _toggleFav(isFav),
                    color: isFav ? ThixPolicy.danger : ThixPolicy.textMain,
                  ),
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                children: [
                  Container(color: Colors.white),
                  if (images.isNotEmpty)
                    CarouselSlider(
                      options: CarouselOptions(
                        height: 400,
                        viewportFraction: 1,
                        enableInfiniteScroll: images.length > 1,
                        onPageChanged: (i, _) => setState(() => _imgIndex = i),
                      ),
                      items: images
                          .map(
                            (img) => CachedNetworkImage(
                              imageUrl: img,
                              fit: BoxFit.contain,
                              width: double.infinity,
                              placeholder: (context, url) => const Center(
                                child: CircularProgressIndicator(color: ThixPolicy.primary),
                              ),
                              errorWidget: (context, url, error) => const Center(
                                child: Icon(Icons.broken_image_rounded, size: 50, color: ThixPolicy.textSecondary),
                              ),
                            ),
                          )
                          .toList(),
                    )
                  else
                    const Center(
                      child: Icon(Icons.image_not_supported_rounded, size: 80, color: ThixPolicy.textDisabled),
                    ),
                  if (images.length > 1)
                    Positioned(
                      bottom: 24,
                      left: 0,
                      right: 0,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: images.asMap().entries.map((e) {
                          final active = _imgIndex == e.key;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            width: active ? 24 : 8,
                            height: 6,
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              color: active ? ThixPolicy.primary : ThixPolicy.border,
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // PRIX + TITRE
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            _ProductDetailValidators.parsePrice(hasDiscount ? discountPrice : price, symbol),
                            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: ThixPolicy.textMain),
                          ),
                          if (hasDiscount && price != null)
                            Padding(
                              padding: const EdgeInsets.only(left: 8, bottom: 4),
                              child: Text(
                                '${price.toInt()} $symbol',
                                style: const TextStyle(
                                  fontSize: 14,
                                  decoration: TextDecoration.lineThrough,
                                  color: ThixPolicy.textSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        title,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: ThixPolicy.textMain, height: 1.3),
                      ),
                      if (!available) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: ThixPolicy.danger.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.remove_shopping_cart_rounded, size: 16, color: ThixPolicy.danger),
                              const SizedBox(width: 6),
                              Text(
                                _t(context, 'Rupture de stock', 'Out of stock'),
                                style: const TextStyle(color: ThixPolicy.danger, fontWeight: FontWeight.w800, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          RatingBar.builder(
                            initialRating: rating,
                            minRating: 0,
                            direction: Axis.horizontal,
                            allowHalfRating: true,
                            itemCount: 5,
                            itemSize: 14,
                            ignoreGestures: true,
                            itemBuilder: (_, __) => const Icon(Icons.star_rounded, color: ThixPolicy.gold),
                            onRatingUpdate: (_) {},
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '$reviewsCount ${_t(context, 'avis', 'reviews')}',
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: ThixPolicy.textSecondary),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 10),

                // VARIANTES + QUANTITÉ
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (variants.isNotEmpty) _buildVariants(variants),
                      if (variants.isNotEmpty && colors.isNotEmpty) const SizedBox(height: 16),
                      if (colors.isNotEmpty) _buildColors(colors),
                      if (variants.isNotEmpty || colors.isNotEmpty) const SizedBox(height: 16),
                      Row(
                        children: [
                          Text(
                            _t(context, 'Quantité', 'Quantity'),
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: ThixPolicy.textMain),
                          ),
                          const Spacer(),
                          Container(
                            decoration: BoxDecoration(
                              color: ThixPolicy.surface,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: ThixPolicy.border),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _qtyBtn(Icons.remove_rounded, () {
                                  if (_qty > 1) {
                                    HapticFeedback.selectionClick();
                                    setState(() => _qty--);
                                  }
                                }),
                                SizedBox(
                                  width: 40,
                                  child: Center(
                                    child: Text(
                                      '$_qty',
                                      style: const TextStyle(fontWeight: FontWeight.w900, color: ThixPolicy.textMain),
                                    ),
                                  ),
                                ),
                                _qtyBtn(Icons.add_rounded, () {
                                  if (_qty < stock) {
                                    HapticFeedback.selectionClick();
                                    setState(() => _qty++);
                                  }
                                }),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 10),

                // BOUTIQUE
                if (shop != null && shop.isNotEmpty)
                  Container(
                    color: Colors.white,
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(ThixPolicy.rSm),
                                border: Border.all(color: ThixPolicy.border),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(ThixPolicy.rSm),
                                child: _ProductDetailValidators.sanitizeUrl(shop['logo_url']?.toString()) != null
                                    ? CachedNetworkImage(
                                        imageUrl: _ProductDetailValidators.sanitizeUrl(shop['logo_url']?.toString())!,
                                        fit: BoxFit.cover,
                                        errorWidget: (_, __, ___) => const Icon(Icons.storefront_rounded, color: ThixPolicy.textSecondary),
                                      )
                                    : const Icon(Icons.storefront_rounded, color: ThixPolicy.textSecondary, size: 24),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _ProductDetailValidators.sanitize(shop['name']?.toString() ?? _t(context, 'Boutique Partenaire', 'Partner Store'), maxLength: 60),
                                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: ThixPolicy.textMain),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${_t(context, 'Partenaire vérifié', 'Verified Partner')} • ${_ProductDetailValidators.sanitize(shop['city']?.toString() ?? '', maxLength: 40)}',
                                    style: const TextStyle(color: ThixPolicy.textSecondary, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: shopId != null
                                    ? () {
                                        HapticFeedback.selectionClick();
                                        context.push('/market/shop/$shopId');
                                      }
                                    : null,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: ThixPolicy.textMain,
                                  side: const BorderSide(color: ThixPolicy.border),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                ),
                                child: Text(_t(context, 'Plus de produits', 'More products')),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton(
                                onPressed: shopId != null
                                    ? () {
                                        HapticFeedback.selectionClick();
                                        context.push('/market/shop/$shopId');
                                      }
                                    : null,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: ThixPolicy.textMain,
                                  side: const BorderSide(color: ThixPolicy.border),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                ),
                                child: Text(_t(context, 'Profil vendeur', 'Store profile')),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 10),

                // DÉTAILS + AVIS
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _t(context, 'Détails du produit', 'Product details'),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: ThixPolicy.textMain),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        description,
                        style: const TextStyle(height: 1.5, color: ThixPolicy.textSecondary, fontSize: 13),
                      ),
                      const SizedBox(height: 24),
                      const Divider(color: ThixPolicy.border),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _t(context, 'Avis clients', 'Customer reviews'),
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: ThixPolicy.textMain),
                          ),
                          if (reviews.isNotEmpty)
                            GestureDetector(
                              onTap: () => _showAllReviews(reviews),
                              child: Text(
                                _t(context, 'Voir tout', 'See all'),
                                style: const TextStyle(color: ThixPolicy.primary, fontWeight: FontWeight.w800, fontSize: 13),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (reviews.isEmpty)
                        Text(
                          _t(context, 'Aucun avis pour le moment.', 'No reviews yet.'),
                          style: const TextStyle(color: ThixPolicy.textSecondary, fontSize: 13),
                        )
                      else
                        ...reviews.take(_kMaxReviewsPreview).map((r) => _reviewCard(r as Map<String, dynamic>)),
                    ],
                  ),
                ),
                const SizedBox(height: 110),
              ],
            ),
          ),
        ],
      ),

      // BOTTOM BAR
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        decoration: BoxDecoration(color: Colors.white, boxShadow: ThixPolicy.shadowCard()),
        child: SafeArea(
          top: false,
          child: Row(
            children: [
              Semantics(
                button: true,
                label: 'Voir la boutique',
                child: InkWell(
                  onTap: shopId != null
                      ? () {
                          HapticFeedback.selectionClick();
                          context.push('/market/shop/$shopId');
                        }
                      : null,
                  child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.storefront_rounded, color: ThixPolicy.textMain, size: 22),
                      SizedBox(height: 2),
                      Text('Store', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 1,
                child: Semantics(
                  button: true,
                  label: 'Contacter le vendeur',
                  child: OutlinedButton(
                    onPressed: () => _openChat(product),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: ThixPolicy.border, width: 1.5),
                      foregroundColor: ThixPolicy.textMain,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rXl)),
                    ),
                    child: const Text('Chat now', style: TextStyle(fontWeight: FontWeight.w800)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 1,
                child: Semantics(
                  button: true,
                  label: available ? 'Acheter maintenant' : 'Indisponible',
                  enabled: available && !_adding,
                  child: ElevatedButton(
                    onPressed: available && !_adding ? () => _buyNow(stock) : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: available ? ThixPolicy.primary : Colors.grey,
                      disabledBackgroundColor: Colors.grey.shade400,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rXl)),
                    ),
                    child: _adding
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Text(
                            available ? 'Buy now' : _t(context, 'Rupture de stock', 'Out of stock'),
                            style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.white),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _circleBtn(IconData icon, VoidCallback onTap, {Color color = ThixPolicy.textMain}) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.9),
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4)],
        ),
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }

  Widget _qtyBtn(IconData icon, VoidCallback onTap) {
    return InkWell(
      borderRadius: BorderRadius.circular(30),
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        child: Icon(icon, size: 18, color: ThixPolicy.textMain),
      ),
    );
  }

  Widget _buildVariants(List list) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _t(context, 'Taille / Modèle', 'Size / Model'),
          style: const TextStyle(fontWeight: FontWeight.w600, color: ThixPolicy.textMain, fontSize: 14),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: list.map((v) {
            final label = _ProductDetailValidators.sanitize(v is String ? v : v['name']?.toString(), maxLength: 50);
            final sel = _variant == label;
            return _chip(label, sel, () {
              HapticFeedback.selectionClick();
              setState(() => _variant = sel ? null : label);
            });
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildColors(List list) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _t(context, 'Couleurs', 'Colors'),
          style: const TextStyle(fontWeight: FontWeight.w600, color: ThixPolicy.textMain, fontSize: 14),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: list.map((c) {
            final label = _ProductDetailValidators.sanitize(c is String ? c : c['name']?.toString(), maxLength: 50);
            final sel = _colorSel == label;
            return _chip(label, sel, () {
              HapticFeedback.selectionClick();
              setState(() => _colorSel = sel ? null : label);
            });
          }).toList(),
        ),
      ],
    );
  }

  Widget _chip(String label, bool sel, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: sel ? ThixPolicy.primary.withOpacity(0.1) : ThixPolicy.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: sel ? ThixPolicy.primary : ThixPolicy.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: sel ? FontWeight.w800 : FontWeight.w500,
            fontSize: 13,
            color: sel ? ThixPolicy.primary : ThixPolicy.textMain,
          ),
        ),
      ),
    );
  }

  Widget _reviewCard(Map<String, dynamic> review) {
    final user = review['user'] as Map?;
    String name = _ProductDetailValidators.sanitize(
      user?['name']?.toString() ?? _t(context, 'Client vérifié', 'Verified Customer'),
      maxLength: 50,
    );
    String? avatar = _ProductDetailValidators.sanitizeUrl(user?['avatar']?.toString());

    double rating = _ProductDetailValidators.clampRating(review['rating']);
    String comment = _ProductDetailValidators.sanitize(review['comment']?.toString() ?? '', maxLength: 500);

    String date = '';
    if (review['created_at'] != null) {
      try {
        date = DateFormat('dd/MM/yyyy').format(DateTime.parse(review['created_at'].toString()));
      } catch (_) {}
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ThixPolicy.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: ThixPolicy.border,
                backgroundImage: avatar != null ? CachedNetworkImageProvider(avatar) : null,
                child: avatar == null
                    ? const Icon(Icons.person_rounded, size: 16, color: ThixPolicy.textSecondary)
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: ThixPolicy.textMain),
                    ),
                    RatingBar.builder(
                      initialRating: rating,
                      minRating: 0,
                      direction: Axis.horizontal,
                      allowHalfRating: true,
                      itemCount: 5,
                      itemSize: 10,
                      ignoreGestures: true,
                      itemBuilder: (context, _) => const Icon(Icons.star_rounded, color: ThixPolicy.gold),
                      onRatingUpdate: (_) {},
                    ),
                  ],
                ),
              ),
              Text(
                date,
                style: const TextStyle(fontSize: 11, color: ThixPolicy.textSecondary),
              ),
            ],
          ),
          if (comment.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                comment,
                style: const TextStyle(height: 1.4, fontSize: 13, color: ThixPolicy.textMain),
              ),
            ),
        ],
      ),
    );
  }

  void _showAllReviews(List reviews) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: DraggableScrollableSheet(
          initialChildSize: 0.9,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Text(
                        _t(context, 'Tous les avis', 'All reviews'),
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: ThixPolicy.textMain),
                      ),
                      const Spacer(),
                      InkWell(
                        onTap: () => Navigator.pop(context),
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(color: ThixPolicy.surface, shape: BoxShape.circle),
                          child: const Icon(Icons.close_rounded, size: 18, color: ThixPolicy.textMain),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: reviews.length,
                    itemBuilder: (context, index) => _reviewCard(reviews[index] as Map<String, dynamic>),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
