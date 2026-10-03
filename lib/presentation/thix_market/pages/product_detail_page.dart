// lib/presentation/thix_market/pages/product_detail_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:intl/intl.dart';
import 'package:html/parser.dart' as html_parser;
import '../core/african_countries.dart';
import 'package:thix_id/core/theme/thix_design_policy.dart';
import '../providers/market_providers.dart';
import '../cart/cart_provider.dart';
import '../widgets/products/product_card.dart';

// ============================================================================
// CONSTANTES
// ============================================================================
const Duration _kRequestTimeout = Duration(seconds: 15);
const Duration _kRetryDelay = Duration(milliseconds: 400);
const int _kMaxReviewsPreview = 3;
const int _kMaxReviewsLoad = 50;
const int _kMaxSimilar = 10;
const double _kSimilarCardHeight = 250;
const double _kSimilarCardWidth = 150;

// ============================================================================
// VALIDATEURS
// ============================================================================
class _V {
  _V._();

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

  static num? toNum(dynamic v) {
    if (v == null) return null;
    if (v is num) return v;
    return num.tryParse(v.toString());
  }

  static int clampStock(dynamic stock) {
    final val = toNum(stock)?.toInt() ?? 0;
    return val < 0 ? 0 : val;
  }

  static double clampRating(dynamic rating) {
    final val = toNum(rating)?.toDouble() ?? 0.0;
    return val.clamp(0.0, 5.0);
  }

  static String parseCurrency(String? currency) {
    final c = (currency ?? 'CDF').toString().toUpperCase().trim();
    if (c == 'USD' || c == '\$') return '\$';
    if (c == 'EUR' || c == '€') return '€';
    if (c == 'XOF' || c == 'FCFA' || c == 'FC' || c == 'CDF') return 'FC';
    return c;
  }

  static String formatPrice(num? price, String symbol) {
    if (price == null || price < 0) return 'Prix indisponible';
    if (price == 0) return 'Sur demande';
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

  final prod = await _withRetry(
    () => db.from('products').select().eq('id', productId).maybeSingle(),
    label: 'fetchProduct',
  );
  if (prod == null) throw Exception('Produit introuvable');

  final shopId = prod['shop_id']?.toString();

  Future<Map<String, dynamic>?> shopF() async {
    if (shopId == null || shopId.isEmpty) return null;
    try {
      return await _withRetry(
        () => db.from('shops').select().eq('id', shopId).maybeSingle(),
        label: 'fetchShop',
      );
    } catch (_) {
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> reviewsF() async {
    for (final table in const ['product_reviews', 'reviews']) {
      try {
        final r = await _withRetry(
          () => db
              .from(table)
              .select()
              .eq('product_id', productId)
              .order('created_at', ascending: false)
              .limit(_kMaxReviewsLoad),
          label: 'fetchReviews($table)',
        );
        return List<Map<String, dynamic>>.from(r as List);
      } catch (_) {}
    }
    return <Map<String, dynamic>>[];
  }

  final results = await Future.wait<dynamic>([shopF(), reviewsF()]);
  final shop = results[0] as Map<String, dynamic>?;
  final reviews = results[1] as List<Map<String, dynamic>>;

  double rating = 0;
  if (reviews.isNotEmpty) {
    double sum = 0;
    for (final rev in reviews) {
      sum += _V.clampRating(rev['rating']);
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

/// Produits similaires : même catégorie > même boutique > plus récents
final similarProductsProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>((ref, productId) async {
  final db = ref.read(supabaseClientProvider);
  final prod = await ref.watch(productDetailProvider(productId).future);
  final category = prod['category']?.toString();
  final shopId = prod['shop_id']?.toString();

  final result = <Map<String, dynamic>>[];
  final seen = <String>{productId};

  void add(dynamic rows) {
    for (final row in List<Map<String, dynamic>>.from(rows as List)) {
      final id = row['id']?.toString();
      if (id == null || id.isEmpty || !seen.add(id)) continue;
      result.add(row);
      if (result.length >= _kMaxSimilar) return;
    }
  }

  if (category != null && category.isNotEmpty) {
    try {
      add(await db
          .from('products')
          .select()
          .eq('status', 'active')
          .eq('category', category)
          .neq('id', productId)
          .order('created_at', ascending: false)
          .limit(_kMaxSimilar)
          .timeout(_kRequestTimeout));
    } catch (e) {
      debugPrint('[ProductDetail] ⚠️ similar(category) error: $e');
    }
  }

  if (result.length < _kMaxSimilar && shopId != null && shopId.isNotEmpty) {
    try {
      add(await db
          .from('products')
          .select()
          .eq('status', 'active')
          .eq('shop_id', shopId)
          .neq('id', productId)
          .order('created_at', ascending: false)
          .limit(_kMaxSimilar)
          .timeout(_kRequestTimeout));
    } catch (e) {
      debugPrint('[ProductDetail] ⚠️ similar(shop) error: $e');
    }
  }

  if (result.length < 6) {
    try {
      add(await db
          .from('products')
          .select()
          .eq('status', 'active')
          .neq('id', productId)
          .order('created_at', ascending: false)
          .limit(_kMaxSimilar)
          .timeout(_kRequestTimeout));
    } catch (e) {
      debugPrint('[ProductDetail] ⚠️ similar(latest) error: $e');
    }
  }

  debugPrint('[ProductDetail] ✓ ${result.length} similar products');
  return result;
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
  final PageController _pageCtrl = PageController();
  int _qty = 1;
  String? _variant;
  String? _colorSel;
  bool _adding = false;
  bool _descExpanded = false;
  int _imgIndex = 0;

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  String _t(BuildContext context, String fr, String en) {
    final lang = Localizations.localeOf(context).languageCode;
    return lang == 'fr' ? fr : en;
  }

  // ─────────────────────────────────────────────────────────────
  // ACTIONS
  // ─────────────────────────────────────────────────────────────
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
          () => db.from('wishlist').insert({'user_id': uid, 'product_id': widget.productId}),
          label: 'addFavorite',
        );
      } else {
        await _withRetry(
          () => db.from('wishlist').delete().match({'user_id': uid, 'product_id': widget.productId}),
          label: 'removeFavorite',
        );
      }
      ref.invalidate(isFavoriteProvider(widget.productId));
    } catch (e) {
      debugPrint('[ProductDetail] ❌ Toggle favorite error: $e');
      _showError('Erreur lors de la mise à jour des favoris');
    }
  }

  Future<void> _addToCart({int maxStock = 0}) async {
    if (_adding) return;

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
        () => db.from('cart').select().match({'user_id': uid, 'product_id': widget.productId}).maybeSingle(),
        label: 'checkCart',
      );

      if (existing != null) {
        final cur = (existing['quantity'] as num?)?.toInt() ?? 0;
        final newQty = cur + _qty;
        if (newQty > maxStock) {
          _showError(_t(context, 'Stock limité à $maxStock (déjà $cur dans le panier)',
              'Stock limited to $maxStock ($cur already in cart)'));
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

      _showSuccess(
        _t(context, 'Ajouté au panier !', 'Added to cart!'),
        actionLabel: _t(context, 'Voir le panier', 'View cart'),
        onAction: () => context.push('/market/cart'),
      );
      ref.invalidate(cartProvider);
    } catch (e) {
      debugPrint('[ProductDetail] ❌ Add to cart error: $e');
      _showError('Erreur lors de l\'ajout au panier');
    } finally {
      if (mounted) setState(() => _adding = false);
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

    final name = _V.sanitize(shop?['name']?.toString() ?? 'Vendeur', maxLength: 60);
    final avatar = _V.sanitizeUrl(shop?['logo_url']?.toString());

    context.push(
      '/market/chat/$shopId',
      extra: {'title': name, 'userName': name, 'userAvatar': avatar},
    );
  }

  void _openShop(String? shopId) {
    if (shopId == null || shopId.isEmpty) return;
    HapticFeedback.selectionClick();
    context.push('/market/shop/$shopId');
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
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

  void _showSuccess(String message, {String? actionLabel, VoidCallback? onAction}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
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
        action: (actionLabel != null && onAction != null)
            ? SnackBarAction(label: actionLabel, textColor: Colors.white, onPressed: onAction)
            : null,
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────
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
      backgroundColor: ThixPolicy.surfaceSoft,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 360,
            pinned: true,
            backgroundColor: Colors.white,
            leading: Padding(
              padding: const EdgeInsets.all(8),
              child: _circleBtn(Icons.arrow_back_ios_new_rounded, () => context.pop()),
            ),
            flexibleSpace: FlexibleSpaceBar(background: Container(color: Colors.grey.shade200)),
          ),
          SliverToBoxAdapter(
            child: _card(
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
      backgroundColor: ThixPolicy.surfaceSoft,
      appBar: AppBar(
        elevation: 0,
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
                decoration: BoxDecoration(color: ThixPolicy.danger.withOpacity(0.1), shape: BoxShape.circle),
                child: const Icon(Icons.error_outline_rounded, size: 56, color: ThixPolicy.danger),
              ),
              const SizedBox(height: 20),
              Text('Erreur de chargement', style: ThixPolicy.h3Style.copyWith(fontWeight: ThixPolicy.bold)),
              const SizedBox(height: 8),
              Text(_V.sanitize(error, maxLength: 200), style: ThixPolicy.bodySmallStyle, textAlign: TextAlign.center),
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
    // ─── Images ───
    final imagesRaw = product['images'] as List?;
    List<String> images = [];
    if (imagesRaw != null && imagesRaw.isNotEmpty) {
      images = imagesRaw.map((e) => _V.sanitizeUrl(e.toString())).whereType<String>().toList();
    }
    if (images.isEmpty && product['image_url'] != null) {
      final url = _V.sanitizeUrl(product['image_url'].toString());
      if (url != null) images = [url];
    }

    // ─── Prix ───
    final symbol = _V.parseCurrency(product['currency']?.toString());
    final price = _V.toNum(product['price'])?.toDouble();
    final dp = _V.toNum(product['discount_price'])?.toDouble();
    final hasDiscount = price != null && dp != null && dp > 0 && dp < price;
    final discountPct = hasDiscount ? ((price - dp) / price * 100).round() : 0;
    final unitPrice = hasDiscount ? dp : price;

    // ─── Stock ───
    final stock = _V.clampStock(product['stock']);
    final available = stock > 0;
    final lowStock = available && stock <= 5;

    // ─── Données ───
    final variants = product['variants'] is List ? product['variants'] as List : [];
    final colors = product['colors'] is List ? product['colors'] as List : [];
    final reviews = product['reviews'] is List ? product['reviews'] as List : [];
    final shopId = product['shop_id']?.toString();
    final shop = product['shop'] as Map<String, dynamic>?;
    final shopName = _V.sanitize(shop?['name']?.toString(), maxLength: 60);

    final title = _V.sanitize(product['title']?.toString() ?? '', maxLength: 150);
    final description = _V.sanitize(product['description']?.toString() ?? '', maxLength: 2000);
    final rating = _V.clampRating(product['rating']);
    final reviewsCount = (product['reviews_count'] as num?)?.toInt() ?? 0;

    return Scaffold(
      backgroundColor: ThixPolicy.surfaceSoft,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ─────────── GALERIE ───────────
          SliverAppBar(
            expandedHeight: 360,
            pinned: true,
            elevation: 0,
            scrolledUnderElevation: 0,
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
              collapseMode: CollapseMode.pin,
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Container(color: ThixPolicy.surfaceSoft),
                  if (images.isNotEmpty)
                    PageView.builder(
                      controller: _pageCtrl,
                      itemCount: images.length,
                      onPageChanged: (i) => setState(() => _imgIndex = i),
                      itemBuilder: (_, i) => CachedNetworkImage(
                        imageUrl: images[i],
                        fit: BoxFit.cover,
                        width: double.infinity,
                        placeholder: (_, __) => const Center(
                          child: SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2, color: ThixPolicy.primary),
                          ),
                        ),
                        errorWidget: (_, __, ___) => const Center(
                          child: Icon(Icons.shopping_bag_outlined, size: 56, color: ThixPolicy.textMuted),
                        ),
                      ),
                    )
                  else
                    const Center(child: Icon(Icons.shopping_bag_outlined, size: 64, color: ThixPolicy.textMuted)),

                  // Badge réduction
                  if (hasDiscount)
                    Positioned(
                      left: 16,
                      bottom: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [ThixPolicy.danger, Color(0xFFB71C1C)]),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '-$discountPct%',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12),
                        ),
                      ),
                    ),

                  // Compteur 1/3
                  if (images.length > 1)
                    Positioned(
                      right: 16,
                      bottom: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.55),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${_imgIndex + 1}/${images.length}',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 11),
                        ),
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
                // ─────────── PRIX + TITRE ───────────
                _card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            _V.formatPrice(unitPrice, symbol),
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                              color: hasDiscount ? ThixPolicy.danger : ThixPolicy.textMain,
                              letterSpacing: -0.5,
                            ),
                          ),
                          if (hasDiscount)
                            Padding(
                              padding: const EdgeInsets.only(left: 8, bottom: 4),
                              child: Text(
                                '${price.toInt()} $symbol',
                                style: const TextStyle(
                                  fontSize: 13,
                                  decoration: TextDecoration.lineThrough,
                                  color: ThixPolicy.textMuted,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        title.isEmpty ? '—' : title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: ThixPolicy.textMain,
                          height: 1.3,
                        ),
                      ),
                      if ((product['city']?.toString().trim().isNotEmpty ?? false) ||
    product['country'] != null) ...[
  const SizedBox(height: 6),
  Row(
    children: [
      const Icon(Icons.location_on_outlined, size: 14, color: ThixPolicy.textMuted),
      const SizedBox(width: 4),
      Flexible(
        child: Text(
          AfricanCountries.locationLine(
            city: product['city']?.toString() ?? '',
            code: product['country']?.toString(),
          ),
          style: const TextStyle(fontSize: 12, color: ThixPolicy.textSecondary, fontWeight: FontWeight.w600),
        ),
      ),
    ],
  ),
],
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          _stockChip(available: available, lowStock: lowStock, stock: stock),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              RatingBar.builder(
                                initialRating: rating,
                                minRating: 0,
                                direction: Axis.horizontal,
                                allowHalfRating: true,
                                itemCount: 5,
                                itemSize: 13,
                                ignoreGestures: true,
                                itemBuilder: (_, __) => const Icon(Icons.star_rounded, color: ThixPolicy.gold),
                                onRatingUpdate: (_) {},
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '$reviewsCount ${_t(context, 'avis', 'reviews')}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 11,
                                  color: ThixPolicy.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      if (shopName.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => _openShop(shopId),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.storefront_rounded, size: 14, color: ThixPolicy.domainMarket),
                              const SizedBox(width: 5),
                              Flexible(
                                child: Text(
                                  shopName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: ThixPolicy.domainMarket,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              const Icon(Icons.chevron_right_rounded, size: 16, color: ThixPolicy.domainMarket),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // ─────────── VARIANTES + QUANTITÉ ───────────
                _card(
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
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: ThixPolicy.textMain),
                          ),
                          const Spacer(),
                          Container(
                            decoration: BoxDecoration(
                              color: ThixPolicy.surfaceSoft,
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
                                  width: 36,
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
                      if (unitPrice != null && unitPrice > 0 && _qty > 1) ...[
                        const SizedBox(height: 10),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            'Total : ${(unitPrice * _qty).toInt()} $symbol',
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: ThixPolicy.textMain),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // ─────────── BADGES DE CONFIANCE ───────────
                _card(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _trustItem(Icons.lock_outline_rounded, _t(context, 'Paiement\nsécurisé', 'Secure\npayment')),
                      _trustItem(Icons.verified_user_outlined, _t(context, 'Vendeur\nvérifié', 'Verified\nseller')),
                      _trustItem(Icons.local_shipping_outlined, _t(context, 'Livraison\nfiable', 'Reliable\ndelivery')),
                      _trustItem(Icons.headset_mic_outlined, _t(context, 'Support\n24/7', 'Support\n24/7')),
                    ],
                  ),
                ),

                // ─────────── BOUTIQUE ───────────
                if (shop != null && shop.isNotEmpty) _buildShopCard(shop, shopId),

                // ─────────── DÉTAILS ───────────
                if (description.isNotEmpty)
                  _card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _sectionTitle(_t(context, 'Détails du produit', 'Product details')),
                        const SizedBox(height: 10),
                        Text(
                          description,
                          maxLines: _descExpanded ? null : 4,
                          overflow: _descExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
                          style: const TextStyle(height: 1.5, color: ThixPolicy.textSecondary, fontSize: 13),
                        ),
                        if (description.length > 140)
                          GestureDetector(
                            onTap: () => setState(() => _descExpanded = !_descExpanded),
                            child: Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                _descExpanded
                                    ? _t(context, 'Voir moins', 'See less')
                                    : _t(context, 'Voir plus', 'See more'),
                                style: const TextStyle(
                                  color: ThixPolicy.primary,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                // ─────────── AVIS ───────────
                _card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _sectionTitle(_t(context, 'Avis clients', 'Customer reviews')),
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
                      const SizedBox(height: 12),
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

                // ─────────── PRODUITS SIMILAIRES ───────────
                _buildSimilarSection(),

                const SizedBox(height: 110),
              ],
            ),
          ),
        ],
      ),

      // ─────────── BARRE DU BAS ───────────
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 16, offset: const Offset(0, -4))],
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: Row(
              children: [
                _bottomIconBtn(
                  icon: Icons.storefront_rounded,
                  label: 'Store',
                  onTap: shopId != null ? () => _openShop(shopId) : null,
                ),
                const SizedBox(width: 10),
                _bottomIconBtn(
                  icon: Icons.chat_bubble_outline_rounded,
                  label: 'Chat',
                  onTap: () => _openChat(product),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Semantics(
                    button: true,
                    label: available ? 'Ajouter au panier' : 'Indisponible',
                    enabled: available && !_adding,
                    child: ElevatedButton.icon(
                      onPressed: available && !_adding ? () => _addToCart(maxStock: stock) : null,
                      icon: _adding
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : Icon(
                              available ? Icons.add_shopping_cart_rounded : Icons.remove_shopping_cart_rounded,
                              size: 20,
                              color: Colors.white,
                            ),
                      label: Text(
                        available
                            ? _t(context, 'Ajouter au panier', 'Add to cart')
                            : _t(context, 'Rupture de stock', 'Out of stock'),
                        style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.white, fontSize: 14),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ThixPolicy.primary,
                        disabledBackgroundColor: Colors.grey.shade400,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rXl)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // SECTIONS
  // ─────────────────────────────────────────────────────────────
  Widget _buildShopCard(Map<String, dynamic> shop, String? shopId) {
    final logo = _V.sanitizeUrl(shop['logo_url']?.toString());
    final name = _V.sanitize(
      shop['name']?.toString() ?? _t(context, 'Boutique Partenaire', 'Partner Store'),
      maxLength: 60,
    );
    final city = _V.sanitize(shop['city']?.toString() ?? '', maxLength: 40);
    final verified = shop['is_verified'] == true;
    final shopRating = _V.toNum(shop['rating'])?.toDouble();

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: ThixPolicy.surfaceSoft,
                  border: Border.all(color: ThixPolicy.border),
                ),
                child: ClipOval(
                  child: logo != null
                      ? CachedNetworkImage(
                          imageUrl: logo,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) =>
                              const Icon(Icons.storefront_rounded, color: ThixPolicy.textMuted),
                        )
                      : const Icon(Icons.storefront_rounded, color: ThixPolicy.textMuted, size: 24),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: ThixPolicy.textMain),
                          ),
                        ),
                        if (verified) ...[
                          const SizedBox(width: 5),
                          const Icon(Icons.verified_rounded, size: 16, color: ThixPolicy.primary),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 10,
                      children: [
                        if (city.isNotEmpty)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.location_on_outlined, size: 12, color: ThixPolicy.textMuted),
                              const SizedBox(width: 2),
                              Text(city, style: const TextStyle(color: ThixPolicy.textMuted, fontSize: 11)),
                            ],
                          ),
                        if (shopRating != null && shopRating > 0)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.star_rounded, size: 13, color: ThixPolicy.gold),
                              const SizedBox(width: 2),
                              Text(
                                shopRating.toStringAsFixed(1),
                                style: const TextStyle(color: ThixPolicy.textSecondary, fontSize: 11, fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: shopId != null ? () => _openShop(shopId) : null,
              icon: const Icon(Icons.storefront_rounded, size: 18),
              label: Text(_t(context, 'Visiter la boutique', 'Visit store')),
              style: OutlinedButton.styleFrom(
                foregroundColor: ThixPolicy.textMain,
                side: const BorderSide(color: ThixPolicy.border),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSimilarSection() {
    final similarAsync = ref.watch(similarProductsProvider(widget.productId));

    return similarAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (items) {
        if (items.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Row(
                children: [
                  const Icon(Icons.auto_awesome_rounded, size: 20, color: ThixPolicy.gold),
                  const SizedBox(width: 8),
                  _sectionTitle(_t(context, 'Produits similaires', 'Similar products')),
                ],
              ),
            ),
            SizedBox(
              height: _kSimilarCardHeight,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (_, i) => SizedBox(
                  width: _kSimilarCardWidth,
                  height: _kSimilarCardHeight,
                  child: ProductCard(
                    key: ValueKey('similar_${items[i]['id']}'),
                    product: items[i],
                    variant: ProductCardVariant.horizontal,
                    width: _kSimilarCardWidth,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // ─────────────────────────────────────────────────────────────
  // WIDGETS UTILITAIRES
  // ─────────────────────────────────────────────────────────────
  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ThixPolicy.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ThixPolicy.border.withOpacity(0.7)),
        boxShadow: ThixPolicy.shadowSoft(opacity: 0.04),
      ),
      child: child,
    );
  }

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: ThixPolicy.textMain, letterSpacing: -0.3),
    );
  }

  Widget _stockChip({required bool available, required bool lowStock, required int stock}) {
    final Color color = !available
        ? ThixPolicy.danger
        : lowStock
            ? ThixPolicy.warning
            : ThixPolicy.success;
    final String label = !available
        ? _t(context, 'Rupture de stock', 'Out of stock')
        : lowStock
            ? _t(context, 'Plus que $stock !', 'Only $stock left!')
            : _t(context, '$stock disponibles', '$stock in stock');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _trustItem(IconData icon, String label) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: ThixPolicy.domainMarket.withOpacity(0.1), shape: BoxShape.circle),
          child: Icon(icon, size: 18, color: ThixPolicy.domainMarket),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: ThixPolicy.textMain, height: 1.2),
        ),
      ],
    );
  }

  Widget _bottomIconBtn({required IconData icon, required String label, VoidCallback? onTap}) {
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 48,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: onTap == null ? ThixPolicy.textDisabled : ThixPolicy.textMain, size: 22),
                const SizedBox(height: 2),
                Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600)),
              ],
            ),
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
          color: Colors.white.withOpacity(0.92),
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
          style: const TextStyle(fontWeight: FontWeight.w700, color: ThixPolicy.textMain, fontSize: 14),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: list.map((v) {
            final label = _V.sanitize(v is String ? v : v['name']?.toString(), maxLength: 50);
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
          style: const TextStyle(fontWeight: FontWeight.w700, color: ThixPolicy.textMain, fontSize: 14),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: list.map((c) {
            final label = _V.sanitize(c is String ? c : c['name']?.toString(), maxLength: 50);
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
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: sel ? ThixPolicy.primary.withOpacity(0.1) : ThixPolicy.surfaceSoft,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: sel ? ThixPolicy.primary : ThixPolicy.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: sel ? FontWeight.w800 : FontWeight.w500,
            fontSize: 12.5,
            color: sel ? ThixPolicy.primary : ThixPolicy.textMain,
          ),
        ),
      ),
    );
  }

  Widget _reviewCard(Map<String, dynamic> review) {
    final user = review['user'] as Map?;
    final name = _V.sanitize(
      user?['name']?.toString() ?? _t(context, 'Client vérifié', 'Verified Customer'),
      maxLength: 50,
    );
    final avatar = _V.sanitizeUrl(user?['avatar']?.toString());
    final rating = _V.clampRating(review['rating']);
    final comment = _V.sanitize(review['comment']?.toString() ?? '', maxLength: 500);

    String date = '';
    if (review['created_at'] != null) {
      try {
        date = DateFormat('dd/MM/yyyy').format(DateTime.parse(review['created_at'].toString()));
      } catch (_) {}
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: ThixPolicy.surfaceSoft, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: ThixPolicy.border,
                backgroundImage: avatar != null ? CachedNetworkImageProvider(avatar) : null,
                child: avatar == null ? const Icon(Icons.person_rounded, size: 16, color: ThixPolicy.textSecondary) : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: ThixPolicy.textMain)),
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
              Text(date, style: const TextStyle(fontSize: 11, color: ThixPolicy.textSecondary)),
            ],
          ),
          if (comment.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(comment, style: const TextStyle(height: 1.4, fontSize: 13, color: ThixPolicy.textMain)),
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
                          decoration: const BoxDecoration(color: ThixPolicy.surfaceSoft, shape: BoxShape.circle),
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
