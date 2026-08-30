// lib/presentation/thix_market/pages/shop_statistics_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:thix_id/core/theme/thix_design_policy.dart';
import '../providers/market_providers.dart';

// ============================================================================
// CONSTANTES & VALIDATEURS
// ============================================================================
const Duration _kRequestTimeout = Duration(seconds: 15);
const Duration _kRetryDelay = Duration(milliseconds: 400);

class _StatsValidators {
  _StatsValidators._();

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

  static bool isValidId(String? id) {
    if (id == null || id.isEmpty) return false;
    return RegExp(r'^[0-9a-fA-F-]{20,}$').hasMatch(id);
  }

  /// Formate un nombre : 1000 → 1.2k, 1500000 → 1.5M
  static String formatCount(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}k';
    return '$count';
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
        debugPrint('[ShopStats] ❌ $label: timeout after $attempt attempts');
        throw TimeoutException('$label: délai dépassé');
      }
      debugPrint('[ShopStats] ⏱️ $label timeout — retry $attempt/$maxRetries');
      await Future.delayed(_kRetryDelay);
    } catch (e) {
      debugPrint('[ShopStats] ❌ $label error: $e');
      rethrow;
    }
  }
}

// ============================================================================
// PROVIDER (Requêtes parallèles + note dynamique)
// ============================================================================
final shopStatsProvider =
    FutureProvider.autoDispose.family<ShopStats, String>((ref, shopId) async {
  if (!_StatsValidators.isValidId(shopId)) {
    debugPrint('[ShopStats] ⚠️ Invalid shopId: $shopId');
    throw Exception('ID boutique invalide');
  }

  debugPrint('[ShopStats] 📊 Loading stats for shop ${shopId.substring(0, 8)}...');

  final db = ref.read(supabaseClientProvider);

  // Requêtes parallèles pour performance (Syntaxe Supabase v2)
  
  final productsFuture = _withRetry(
    () => db.from('products').count(CountOption.exact).eq('shop_id', shopId),
    label: 'countProducts',
  ).catchError((_) => 0);

  final followersFuture = _withRetry(
    () => db.from('shop_followers').count(CountOption.exact).eq('shop_id', shopId),
    label: 'countFollowers',
  ).catchError((_) => 0);

  final ordersFuture = _withRetry(
    () => db.from('order_items').count(CountOption.exact).eq('shop_id', shopId),
    label: 'countOrders',
  ).catchError((_) => 0);

  // Note dynamique calculée depuis les reviews
  final ratingFuture = _withRetry(
    () => db
        .from('products')
        .select('id')
        .eq('shop_id', shopId)
        .then((products) async {
      if ((products as List).isEmpty) return (avg: 0.0, count: 0);

      final productIds = products.map((p) => p['id'].toString()).toList();
      final reviews = await db
          .from('reviews')
          .select('rating')
          .inFilter('product_id', productIds)
          .timeout(_kRequestTimeout);

      final ratings = (reviews as List)
          .map((r) => (r['rating'] as num?)?.toDouble() ?? 0.0)
          .where((r) => r > 0 && r <= 5)
          .toList();

      if (ratings.isEmpty) return (avg: 0.0, count: 0);

      final avg = ratings.reduce((a, b) => a + b) / ratings.length;
      return (avg: avg, count: ratings.length);
    }),
    label: 'calcRating',
  ).catchError((_) => (avg: 0.0, count: 0));

  // Shop name pour le header
  final shopNameFuture = _withRetry(
    () => db.from('shops').select('name').eq('id', shopId).maybeSingle(),
    label: 'fetchShopName',
  ).then((res) => res?['name']?.toString() ?? 'Boutique').catchError((_) => 'Boutique');

  // Exécution parallèle
  final results = await Future.wait([
    productsFuture,
    followersFuture,
    ordersFuture,
    ratingFuture,
    shopNameFuture,
  ]);

  final stats = ShopStats(
    shopName: _StatsValidators.sanitize(results[4] as String, maxLength: 60),
    products: results[0] as int,
    followers: results[1] as int,
    orders: results[2] as int,
    ratingAvg: (results[3] as ({double avg, int count})).avg,
    ratingCount: (results[3] as ({double avg, int count})).count,
  );

  debugPrint('[ShopStats] ✓ Loaded: ${stats.products} products, ${stats.followers} followers, ${stats.orders} orders, ${stats.ratingAvg.toStringAsFixed(1)}★ (${stats.ratingCount} reviews)');
  return stats;
});

// ============================================================================
// MODÈLE
// ============================================================================
class ShopStats {
  final String shopName;
  final int products;
  final int followers;
  final int orders;
  final double ratingAvg;
  final int ratingCount;

  const ShopStats({
    required this.shopName,
    required this.products,
    required this.followers,
    required this.orders,
    required this.ratingAvg,
    required this.ratingCount,
  });
}

// ============================================================================
// PAGE
// ============================================================================
class ShopStatisticsPage extends ConsumerStatefulWidget {
  final String shopId;
  const ShopStatisticsPage({super.key, required this.shopId});

  @override
  ConsumerState<ShopStatisticsPage> createState() => _ShopStatisticsPageState();
}

class _ShopStatisticsPageState extends ConsumerState<ShopStatisticsPage> {
  @override
  void initState() {
    super.initState();
    debugPrint('[ShopStats] 📊 Page opened for ${widget.shopId.substring(0, 8)}...');
  }

  @override
  void dispose() {
    debugPrint('[ShopStats] 👋 Page disposed');
    super.dispose();
  }

  void _refresh() {
    HapticFeedback.selectionClick();
    ref.invalidate(shopStatsProvider(widget.shopId));
    debugPrint('[ShopStats] 🔄 Refreshing');
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(shopStatsProvider(widget.shopId));

    return Scaffold(
      backgroundColor: ThixPolicy.surfaceSoft,
      appBar: AppBar(
        title: Text(
          'Statistiques',
          style: ThixPolicy.h3Style.copyWith(fontWeight: ThixPolicy.bold, color: ThixPolicy.textMain),
        ),
        backgroundColor: ThixPolicy.card,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: ThixPolicy.textMain, size: 20),
          onPressed: () {
            HapticFeedback.selectionClick();
            context.pop();
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
      body: async.when(
        loading: () => const _SkeletonGrid(),
        error: (e, _) => _ErrorState(
          message: _StatsValidators.sanitize(e.toString(), maxLength: 200),
          onRetry: _refresh,
        ),
        data: (stats) => _buildContent(stats),
      ),
    );
  }

  Widget _buildContent(ShopStats stats) {
    return RefreshIndicator(
      color: ThixPolicy.primary,
      onRefresh: () async {
        _refresh();
        await Future.delayed(const Duration(milliseconds: 500));
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header boutique
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [ThixPolicy.inkDeep, ThixPolicy.primary],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Aperçu général',
                    style: ThixPolicy.captionStyle.copyWith(color: Colors.white.withOpacity(0.7)),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    stats.shopName,
                    style: ThixPolicy.h2Style.copyWith(
                      color: Colors.white,
                      fontWeight: ThixPolicy.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Grille stats
            GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.5,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _StatCard(
                  label: 'Produits',
                  value: _StatsValidators.formatCount(stats.products),
                  icon: Icons.inventory_2_rounded,
                  color: ThixPolicy.primary,
                ),
                _StatCard(
                  label: 'Abonnés',
                  value: _StatsValidators.formatCount(stats.followers),
                  icon: Icons.favorite_rounded,
                  color: ThixPolicy.danger,
                ),
                _StatCard(
                  label: 'Commandes',
                  value: _StatsValidators.formatCount(stats.orders),
                  icon: Icons.receipt_long_rounded,
                  color: ThixPolicy.success,
                ),
                _StatCard(
                  label: 'Note moyenne',
                  value: '${stats.ratingAvg.toStringAsFixed(1)} ★',
                  subtitle: '${stats.ratingCount} avis',
                  icon: Icons.star_rounded,
                  color: ThixPolicy.gold,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Section insights (bonus)
            _buildInsights(stats),
          ],
        ),
      ),
    );
  }

  Widget _buildInsights(ShopStats stats) {
    final insights = <_Insight>[];

    // Taux de conversion (commandes / followers)
    if (stats.followers > 0) {
      final conversion = (stats.orders / stats.followers * 100).toStringAsFixed(1);
      insights.add(_Insight(
        icon: Icons.trending_up_rounded,
        color: ThixPolicy.success,
        title: 'Taux de conversion',
        value: '$conversion%',
        subtitle: 'Commandes par abonné',
      ));
    }

    // Moyenne commandes par produit
    if (stats.products > 0) {
      final avg = (stats.orders / stats.products).toStringAsFixed(1);
      insights.add(_Insight(
        icon: Icons.analytics_rounded,
        color: ThixPolicy.primary,
        title: 'Commandes par produit',
        value: avg,
        subtitle: 'Performance catalogue',
      ));
    }

    if (insights.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Insights',
          style: ThixPolicy.h3Style.copyWith(fontWeight: ThixPolicy.bold, color: ThixPolicy.textMain),
        ),
        const SizedBox(height: 12),
        ...insights.map((insight) => Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: ThixPolicy.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: ThixPolicy.border.withOpacity(0.6)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: insight.color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(insight.icon, color: insight.color, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          insight.title,
                          style: ThixPolicy.labelStyle.copyWith(
                            color: ThixPolicy.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          insight.value,
                          style: ThixPolicy.h3Style.copyWith(
                            fontWeight: ThixPolicy.bold,
                            color: ThixPolicy.textMain,
                          ),
                        ),
                        if (insight.subtitle != null)
                          Text(
                            insight.subtitle!,
                            style: ThixPolicy.captionStyle.copyWith(
                              color: ThixPolicy.textMuted,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            )),
      ],
    );
  }
}

// ============================================================================
// COMPOSANTS
// ============================================================================

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final String? subtitle;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    this.subtitle,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label: $value${subtitle != null ? ", $subtitle" : ""}',
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: ThixPolicy.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: ThixPolicy.border.withOpacity(0.6)),
          boxShadow: ThixPolicy.shadowSoft(opacity: 0.03),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 16, color: color),
            ),
            const Spacer(),
            Text(
              value,
              style: ThixPolicy.h3Style.copyWith(
                fontSize: 18,
                fontWeight: ThixPolicy.bold,
                color: ThixPolicy.textMain,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: ThixPolicy.captionStyle.copyWith(
                fontSize: 12,
                color: ThixPolicy.textMuted,
              ),
            ),
            if (subtitle != null)
              Text(
                subtitle!,
                style: ThixPolicy.microStyle.copyWith(
                  color: ThixPolicy.textMuted,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Insight {
  final IconData icon;
  final Color color;
  final String title;
  final String value;
  final String? subtitle;

  const _Insight({
    required this.icon,
    required this.color,
    required this.title,
    required this.value,
    this.subtitle,
  });
}

class _SkeletonGrid extends StatelessWidget {
  const _SkeletonGrid();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 80,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.5,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: List.generate(
              4,
              (_) => Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
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
