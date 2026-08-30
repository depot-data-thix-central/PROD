// lib/presentation/thix_market/pages/wishlist_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:thix_id/core/theme/thix_design_policy.dart';
import '../providers/market_providers.dart';
import '../providers/product_provider.dart';

// ============================================================================
// CONSTANTES & VALIDATEURS
// ============================================================================
class _WishlistValidators {
  _WishlistValidators._();

  static String sanitize(String? input, {int maxLength = 200}) {
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

  static double safePrice(dynamic price) {
    return (price as num?)?.toDouble() ?? 0.0;
  }

  static int safeStock(dynamic stock) {
    if (stock == null) return 0;
    final val = (stock as num?)?.toInt() ?? 0;
    return val < 0 ? 0 : val;
  }
}

// ============================================================================
// PAGE PRINCIPALE
// ============================================================================
class WishlistPage extends ConsumerStatefulWidget {
  const WishlistPage({super.key});

  @override
  ConsumerState<WishlistPage> createState() => _WishlistPageState();
}

class _WishlistPageState extends ConsumerState<WishlistPage> {
  @override
  void initState() {
    super.initState();
    debugPrint('[Wishlist] ❤️ Page opened');
  }

  @override
  void dispose() {
    debugPrint('[Wishlist] 👋 Page disposed');
    super.dispose();
  }

  void _refresh() {
    HapticFeedback.selectionClick();
    ref.invalidate(favoritesProvider);
    debugPrint('[Wishlist] 🔄 Refreshing provider');
  }

  Future<void> _remove(String wishlistId) async {
    HapticFeedback.mediumImpact();
    try {
      final db = ref.read(supabaseClientProvider);
      await db.from('wishlist').delete().eq('id', wishlistId);
      ref.invalidate(favoritesProvider);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_outline_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                const Text('Produit retiré des favoris'),
              ],
            ),
            backgroundColor: ThixPolicy.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint('[Wishlist] ❌ Remove error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Erreur lors de la suppression'),
            backgroundColor: ThixPolicy.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _addToCart(String productId) async {
    HapticFeedback.selectionClick();
    final db = ref.read(supabaseClientProvider);
    final uid = db.auth.currentUser?.id;
    
    if (uid == null) {
      context.push('/login');
      return;
    }
    
    try {
      final existing = await db.from('cart').select().match({'user_id': uid, 'product_id': productId}).maybeSingle();
      
      if (existing != null) {
        await db.from('cart').update({'quantity': (existing['quantity'] as int) + 1}).eq('id', existing['id']);
      } else {
        await db.from('cart').insert({'user_id': uid, 'product_id': productId, 'quantity': 1});
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.shopping_cart_checkout_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                const Text('Ajouté au panier !'),
              ],
            ),
            backgroundColor: ThixPolicy.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint('[Wishlist] ❌ Add to cart error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Erreur lors de l\'ajout au panier'),
            backgroundColor: ThixPolicy.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final favAsync = ref.watch(favoritesProvider);

    return Scaffold(
      backgroundColor: ThixPolicy.surfaceSoft,
      appBar: AppBar(
        title: Text(
          'Mes Favoris',
          style: ThixPolicy.h3Style.copyWith(fontWeight: ThixPolicy.bold, color: ThixPolicy.textMain),
        ),
        backgroundColor: ThixPolicy.card,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: ThixPolicy.textMain, size: 20),
          onPressed: () {
            HapticFeedback.selectionClick();
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/market');
            }
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: ThixPolicy.textMain),
            tooltip: 'Rafraîchir',
            onPressed: _refresh,
          ),
        ],
      ),
      body: favAsync.when(
        loading: () => const _SkeletonList(),
        error: (e, _) => _ErrorState(
          message: _WishlistValidators.sanitize(e.toString(), maxLength: 200),
          onRetry: _refresh,
        ),
        data: (items) {
          if (items.isEmpty) {
            return _EmptyState(
              icon: Icons.favorite_border_rounded,
              title: 'Votre liste est vide',
              subtitle: 'Vous n\'avez pas encore ajouté de produits à vos favoris. Explorez le marché.',
              actionLabel: 'Explorer le marché',
              onAction: () {
                HapticFeedback.mediumImpact();
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.push('/market');
                }
              },
            );
          }

          return RefreshIndicator(
            color: ThixPolicy.primary,
            onRefresh: () async {
              _refresh();
              await Future.delayed(const Duration(milliseconds: 500));
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: items.length,
              itemBuilder: (context, i) => _buildWishlistCard(items[i]),
            ),
          );
        },
      ),
    );
  }

  Widget _buildWishlistCard(Map<String, dynamic> raw) {
    // raw peut venir de favoritesProvider (produit direct) ou wishlist join
    final product = raw['products'] != null ? Map<String, dynamic>.from(raw['products']) : raw;
    final wishlistId = (raw['wishlist_id'] ?? raw['id']).toString();
    final productId = (product['id'] ?? raw['product_id']).toString();
    
    if (productId.isEmpty || wishlistId.isEmpty) return const SizedBox.shrink();

    final title = _WishlistValidators.sanitize(product['title']?.toString() ?? 'Produit', maxLength: 100);
    final price = _WishlistValidators.safePrice(product['price']);
    final currency = _WishlistValidators.sanitize(product['currency']?.toString() ?? 'FC', maxLength: 10);
    final stock = _WishlistValidators.safeStock(product['stock']);
    final isAvailable = stock > 0;
    final imageUrl = _WishlistValidators.sanitizeUrl(product['image_url']?.toString());

    return Dismissible(
      key: Key(wishlistId),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: ThixPolicy.danger.withOpacity(0.15),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_outline_rounded, color: ThixPolicy.danger, size: 28),
      ),
      onDismissed: (_) => _remove(wishlistId),
      child: Semantics(
        button: true,
        label: 'Produit favori $title, Prix ${price.toInt()} $currency',
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: ThixPolicy.card,
            borderRadius: BorderRadius.circular(16),
            boxShadow: ThixPolicy.shadowSoft(opacity: 0.05),
            border: Border.all(color: ThixPolicy.border.withOpacity(0.6)),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                HapticFeedback.selectionClick();
                context.push('/market/product/$productId');
              },
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    // Image produit
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: 80,
                        height: 80,
                        color: ThixPolicy.surfaceSoft,
                        child: imageUrl == null
                            ? const Icon(Icons.image_not_supported_outlined, color: ThixPolicy.textMuted)
                            : CachedNetworkImage(
                                imageUrl: imageUrl,
                                fit: BoxFit.cover,
                                errorWidget: (_, __, ___) => const Icon(Icons.broken_image_outlined, color: ThixPolicy.textMuted),
                              ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Infos
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: ThixPolicy.labelStyle.copyWith(
                              fontSize: 14,
                              fontWeight: ThixPolicy.bold,
                              color: ThixPolicy.textMain,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${price.toInt()} $currency',
                            style: ThixPolicy.h3Style.copyWith(
                              fontWeight: ThixPolicy.bold,
                              fontSize: 16,
                              color: ThixPolicy.primary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: (isAvailable ? ThixPolicy.success : ThixPolicy.danger).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(ThixPolicy.rSm),
                            ),
                            child: Text(
                              isAvailable ? 'En stock' : 'Rupture de stock',
                              style: ThixPolicy.microStyle.copyWith(
                                color: isAvailable ? ThixPolicy.success : ThixPolicy.danger,
                                fontWeight: ThixPolicy.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Bouton Ajouter au panier
                    if (isAvailable)
                      IconButton(
                        onPressed: () => _addToCart(productId),
                        icon: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: ThixPolicy.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.shopping_cart_outlined, color: ThixPolicy.primary, size: 20),
                        ),
                        tooltip: 'Ajouter au panier',
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// COMPOSANTS RÉUTILISABLES
// ============================================================================

class _SkeletonList extends StatelessWidget {
  const _SkeletonList();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: 5,
      itemBuilder: (_, __) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: ThixPolicy.card,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(12)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(height: 14, width: double.infinity, color: Colors.grey.shade200),
                  const SizedBox(height: 8),
                  Container(height: 14, width: 120, color: Colors.grey.shade200),
                  const SizedBox(height: 12),
                  Container(height: 16, width: 80, color: Colors.grey.shade200),
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
              decoration: BoxDecoration(
                color: ThixPolicy.danger.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.error_outline_rounded, size: 56, color: ThixPolicy.danger),
            ),
            const SizedBox(height: 20),
            Text(
              'Erreur de chargement',
              style: ThixPolicy.h3Style.copyWith(fontWeight: ThixPolicy.bold, color: ThixPolicy.textMain),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: ThixPolicy.bodySmallStyle.copyWith(color: ThixPolicy.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onRetry,
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
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onAction;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: ThixPolicy.primary.withOpacity(0.06),
                shape: BoxShape.circle,
                border: Border.all(color: ThixPolicy.gold.withOpacity(0.4), width: 1.4),
              ),
              child: Icon(icon, size: 38, color: ThixPolicy.primary),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              style: ThixPolicy.h3Style.copyWith(fontWeight: ThixPolicy.bold, color: ThixPolicy.textMain),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: ThixPolicy.bodySmallStyle.copyWith(color: ThixPolicy.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 22),
            ElevatedButton(
              onPressed: onAction,
              style: ElevatedButton.styleFrom(
                backgroundColor: ThixPolicy.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rFull)),
                padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 13),
              ),
              child: Text(
                actionLabel,
                style: ThixPolicy.labelStyle.copyWith(fontWeight: ThixPolicy.bold, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
