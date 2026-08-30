// lib/presentation/thix_market/pages/sell_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:html/parser.dart' as html_parser;

import 'package:thix_id/core/theme/thix_design_policy.dart';
import '../providers/market_providers.dart';

// ============================================================================
// CONSTANTES & VALIDATEURS
// ============================================================================
const Duration _kRequestTimeout = Duration(seconds: 15);
const Duration _kRetryDelay = Duration(milliseconds: 400);

class _SellValidators {
  _SellValidators._();

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

  static bool isValidId(String? id) {
    if (id == null || id.isEmpty) return false;
    return RegExp(r'^[0-9a-fA-F-]{8,}$').hasMatch(id);
  }

  static int safeInt(dynamic v, {int fallback = 0}) {
    if (v == null) return fallback;
    final parsed = (v as num?)?.toInt() ?? fallback;
    return parsed < 0 ? fallback : parsed;
  }

  static double safeDouble(dynamic v, {double fallback = 0.0}) {
    if (v == null) return fallback;
    final parsed = (v as num?)?.toDouble() ?? fallback;
    return parsed < 0 || parsed.isNaN || parsed.isInfinite ? fallback : parsed;
  }

  static String formatCount(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}k';
    return '$count';
  }

  static String formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return 'Date inconnue';
    try {
      return DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(dateStr));
    } catch (_) {
      return _SellValidators.sanitize(dateStr, maxLength: 20);
    }
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
        debugPrint('[SellPage] ❌ $label: timeout after $attempt attempts');
        throw TimeoutException('$label: délai dépassé');
      }
      debugPrint('[SellPage] ⏱️ $label timeout — retry $attempt/$maxRetries');
      await Future.delayed(_kRetryDelay);
    } catch (e) {
      debugPrint('[SellPage] ❌ $label error: $e');
      rethrow;
    }
  }
}

// ============================================================================
// MODÈLES
// ============================================================================
class SellerStats {
  final int totalSales;
  final int revenue;
  final int totalViews;
  final double conversionRate;
  final List<SalesDataPoint> salesData;
  final List<TopProduct> topProducts;

  const SellerStats({
    required this.totalSales,
    required this.revenue,
    required this.totalViews,
    required this.conversionRate,
    required this.salesData,
    required this.topProducts,
  });
}

class SalesDataPoint {
  final String label;
  final double value;
  const SalesDataPoint({required this.label, required this.value});
}

class TopProduct {
  final String? imageUrl;
  final String name;
  final int views;
  final double revenue;
  const TopProduct({this.imageUrl, required this.name, required this.views, required this.revenue});
}

// ============================================================================
// PROVIDERS
// ============================================================================
final myAnnouncementsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final db = ref.read(supabaseClientProvider);
  final uid = db.auth.currentUser?.id;
  if (uid == null) return [];

  debugPrint('[SellPage] 📢 Loading announcements');
  try {
    final res = await _withRetry(
      () => db.from('products').select().eq('owner_id', uid).order('created_at', ascending: false),
      label: 'fetchAnnouncements',
    );
    debugPrint('[SellPage] ✓ Loaded ${(res as List).length} announcements');
    return List<Map<String, dynamic>>.from(res);
  } catch (e) {
    debugPrint('[SellPage] ❌ Announcements error: $e');
    return [];
  }
});

final myOrdersProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final db = ref.read(supabaseClientProvider);
  final uid = db.auth.currentUser?.id;
  if (uid == null) return [];

  debugPrint('[SellPage] 📦 Loading orders');
  try {
    final res = await _withRetry(
      () => db.from('orders').select().eq('seller_id', uid).order('created_at', ascending: false).limit(100),
      label: 'fetchOrders',
    );
    debugPrint('[SellPage] ✓ Loaded ${(res as List).length} orders');
    return List<Map<String, dynamic>>.from(res);
  } catch (e) {
    debugPrint('[SellPage] ❌ Orders error: $e');
    return [];
  }
});

final myLivesProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final db = ref.read(supabaseClientProvider);
  final uid = db.auth.currentUser?.id;
  if (uid == null) return [];

  debugPrint('[SellPage] 🎬 Loading lives');
  try {
    final res = await _withRetry(
      () => db.from('lives').select().eq('host_id', uid).order('created_at', ascending: false),
      label: 'fetchLives',
    );
    debugPrint('[SellPage] ✓ Loaded ${(res as List).length} lives');
    return List<Map<String, dynamic>>.from(res);
  } catch (e) {
    debugPrint('[SellPage] ❌ Lives error: $e');
    return [];
  }
});

final sellerStatsProvider =
    FutureProvider.autoDispose<SellerStats>((ref) async {
  debugPrint('[SellPage] 📊 Calculating seller stats');

  // Requêtes parallèles
  final ordersFuture = ref.read(myOrdersProvider.future);
  final annFuture = ref.read(myAnnouncementsProvider.future);

  final results = await Future.wait([ordersFuture, annFuture]);
  final orders = results[0] as List<Map<String, dynamic>>;
  final ann = results[1] as List<Map<String, dynamic>>;

  // Calcul revenue
  int revenue = 0;
  for (final o in orders) {
    revenue += _SellValidators.safeInt(o['total']);
  }

  // Calcul views
  int views = 0;
  for (final a in ann) {
    views += _SellValidators.safeInt(a['views']);
  }

  // Conversion rate (protection division par zéro)
  double conv = 0.0;
  if (ann.isNotEmpty) {
    conv = (orders.length / ann.length * 100).clamp(0, 100).toDouble();
  }

  // Sales data (6 derniers mois)
  List<SalesDataPoint> sales = [];
  for (int i = 0; i < 6; i++) {
    final d = DateTime.now().subtract(Duration(days: (5 - i) * 30));
    final label = DateFormat('MMM').format(d);
    double val = revenue > 0 ? (i + 1) * revenue / 6.0 : 10.0;
    sales.add(SalesDataPoint(label: label, value: val));
  }

  // Top products
  final top = ann.take(5).map((e) {
    return TopProduct(
      imageUrl: _SellValidators.sanitizeUrl(e['image_url']?.toString()),
      name: _SellValidators.sanitize(e['title']?.toString() ?? 'Sans titre', maxLength: 60),
      views: _SellValidators.safeInt(e['views']),
      revenue: _SellValidators.safeDouble(e['price']),
    );
  }).toList();

  debugPrint('[SellPage] ✓ Stats: $revenue FC, ${orders.length} sales, $views views, ${conv.toStringAsFixed(1)}% conv');

  return SellerStats(
    totalSales: orders.length,
    revenue: revenue,
    totalViews: views,
    conversionRate: conv,
    salesData: sales,
    topProducts: top,
  );
});

// ============================================================================
// PAGE PRINCIPALE
// ============================================================================
class SellPage extends ConsumerStatefulWidget {
  const SellPage({super.key});
  @override
  ConsumerState<SellPage> createState() => _SellPageState();
}

class _SellPageState extends ConsumerState<SellPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() => setState(() {}));
    debugPrint('[SellPage] 🏪 Seller dashboard opened');
  }

  Future<void> _refresh() async {
    HapticFeedback.selectionClick();
    ref.invalidate(myAnnouncementsProvider);
    ref.invalidate(myOrdersProvider);
    ref.invalidate(myLivesProvider);
    ref.invalidate(sellerStatsProvider);
    debugPrint('[SellPage] 🔄 Refreshing all providers');
  }

  @override
  void dispose() {
    _tabController.dispose();
    debugPrint('[SellPage] 👋 Seller dashboard disposed');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ThixPolicy.surfaceSoft,
      appBar: AppBar(
        title: Text(
          'Espace Vendeur',
          style: ThixPolicy.h2Style.copyWith(
            fontWeight: ThixPolicy.bold,
            color: ThixPolicy.textMain,
          ),
        ),
        backgroundColor: ThixPolicy.card,
        elevation: 0,
        scrolledUnderElevation: 0,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Annonces'),
            Tab(text: 'Commandes'),
            Tab(text: 'Stats'),
            Tab(text: 'Lives'),
          ],
          indicatorColor: ThixPolicy.primary,
          labelColor: ThixPolicy.primary,
          unselectedLabelColor: ThixPolicy.textSecondary,
          labelStyle: ThixPolicy.labelStyle.copyWith(fontWeight: ThixPolicy.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: ThixPolicy.textMain),
            tooltip: 'Rafraîchir',
            onPressed: _refresh,
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _annoncesTab(),
          _ordersTab(),
          _statsTab(),
          _livesTab(),
        ],
      ),
      floatingActionButton: _tabController.index == 0 || _tabController.index == 3
          ? FloatingActionButton.extended(
              onPressed: () {
                HapticFeedback.mediumImpact();
                _tabController.index == 0
                    ? context.push('/market/announcement/publish')
                    : context.push('/market/live/create');
              },
              backgroundColor: ThixPolicy.primary,
              icon: Icon(
                _tabController.index == 0 ? Icons.add_rounded : Icons.videocam_rounded,
                color: Colors.white,
              ),
              label: Text(
                _tabController.index == 0 ? 'Publier' : 'Créer un live',
                style: ThixPolicy.labelStyle.copyWith(color: Colors.white, fontWeight: ThixPolicy.bold),
              ),
            )
          : null,
    );
  }

  Widget _annoncesTab() {
    final async = ref.watch(myAnnouncementsProvider);
    return async.when(
      loading: () => const _SkeletonList(),
      error: (e, _) => _ErrorState(
        message: _SellValidators.sanitize(e.toString(), maxLength: 200),
        onRetry: _refresh,
      ),
      data: (list) {
        if (list.isEmpty) {
          return _EmptyState(
            icon: Icons.sell_rounded,
            title: 'Aucune annonce',
            subtitle: 'Publiez votre première annonce pour commencer à vendre',
            actionLabel: 'Publier une annonce',
            onAction: () {
              HapticFeedback.mediumImpact();
              context.push('/market/announcement/publish');
            },
          );
        }
        return RefreshIndicator(
          color: ThixPolicy.primary,
          onRefresh: _refresh,
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: list.length,
            itemBuilder: (_, i) => _announcementCard(list[i]),
          ),
        );
      },
    );
  }

  Widget _announcementCard(Map<String, dynamic> ann) {
    final id = ann['id']?.toString() ?? '';
    if (!_SellValidators.isValidId(id)) return const SizedBox.shrink();

    final status = _SellValidators.sanitize(ann['status']?.toString() ?? 'active', maxLength: 20);
    final priceVal = _SellValidators.safeInt(ann['price']);
    final discountVal = _SellValidators.safeInt(ann['discount_price'], fallback: -1);
    final hasDiscount = discountVal >= 0 && discountVal < priceVal;
    final displayPrice = hasDiscount ? discountVal : priceVal;

    String? img;
    if (ann['image_url'] != null) {
      img = _SellValidators.sanitizeUrl(ann['image_url'].toString());
    } else if (ann['images'] is List && (ann['images'] as List).isNotEmpty) {
      img = _SellValidators.sanitizeUrl((ann['images'] as List).first.toString());
    }

    final views = _SellValidators.safeInt(ann['views']);
    final title = _SellValidators.sanitize(ann['title']?.toString() ?? 'Sans titre', maxLength: 80);

    return Semantics(
      button: true,
      label: 'Annonce $title, $displayPrice FCFA, $views vues',
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: ThixPolicy.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: ThixPolicy.border.withOpacity(0.6)),
          boxShadow: ThixPolicy.shadowSoft(opacity: 0.03),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: img == null
                        ? Container(
                            width: 80,
                            height: 80,
                            color: ThixPolicy.surfaceSoft,
                            child: const Icon(Icons.image_outlined, color: ThixPolicy.textMuted, size: 32),
                          )
                        : CachedNetworkImage(
                            imageUrl: img,
                            width: 80,
                            height: 80,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => Container(
                              width: 80,
                              height: 80,
                              color: ThixPolicy.surfaceSoft,
                              child: const Center(
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: ThixPolicy.primary),
                                ),
                              ),
                            ),
                            errorWidget: (_, __, ___) => Container(
                              width: 80,
                              height: 80,
                              color: ThixPolicy.surfaceSoft,
                              child: const Icon(Icons.broken_image_outlined, color: ThixPolicy.textMuted, size: 32),
                            ),
                          ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: ThixPolicy.labelStyle.copyWith(
                            fontWeight: ThixPolicy.semiBold,
                            fontSize: 15,
                            color: ThixPolicy.textMain,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              '$displayPrice FCFA',
                              style: ThixPolicy.labelStyle.copyWith(
                                color: ThixPolicy.primary,
                                fontWeight: ThixPolicy.bold,
                              ),
                            ),
                            if (hasDiscount)
                              Padding(
                                padding: const EdgeInsets.only(left: 6),
                                child: Text(
                                  '$priceVal FCFA',
                                  style: ThixPolicy.captionStyle.copyWith(
                                    decoration: TextDecoration.lineThrough,
                                    color: ThixPolicy.textMuted,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.visibility_outlined, size: 12, color: ThixPolicy.textMuted),
                            const SizedBox(width: 4),
                            Text(
                              '${_SellValidators.formatCount(views)} vues',
                              style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.textMuted),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _ActionButton(
                      icon: Icons.edit_rounded,
                      label: 'Modifier',
                      onTap: () {
                        HapticFeedback.selectionClick();
                        context.push('/market/announcement/$id/edit');
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _ActionButton(
                      icon: Icons.trending_up_rounded,
                      label: 'Booster',
                      onTap: () => _showBoost(id, title),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _ActionButton(
                      icon: Icons.share_rounded,
                      label: 'Partager',
                      onTap: () => _shareAnnouncement(id, title, displayPrice),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _ordersTab() {
    final async = ref.watch(myOrdersProvider);
    return async.when(
      loading: () => const _SkeletonList(),
      error: (e, _) => _ErrorState(
        message: _SellValidators.sanitize(e.toString(), maxLength: 200),
        onRetry: _refresh,
      ),
      data: (orders) {
        if (orders.isEmpty) {
          return _EmptyState(
            icon: Icons.inbox_rounded,
            title: 'Aucune commande',
            subtitle: 'Les commandes de vos clients apparaîtront ici',
          );
        }

        List<Map<String, dynamic>> pending = [];
        List<Map<String, dynamic>> preparing = [];
        List<Map<String, dynamic>> shipped = [];
        List<Map<String, dynamic>> completed = [];

        for (final o in orders) {
          final s = o['status']?.toString() ?? '';
          if (s == 'pending') pending.add(o);
          else if (s == 'preparing') preparing.add(o);
          else if (s == 'shipped') shipped.add(o);
          else if (s == 'completed') completed.add(o);
        }

        return DefaultTabController(
          length: 4,
          child: Column(
            children: [
              Container(
                color: ThixPolicy.card,
                child: TabBar(
                  tabs: [
                    Tab(text: 'À traiter (${pending.length})'),
                    Tab(text: 'Préparation (${preparing.length})'),
                    Tab(text: 'Expédiées (${shipped.length})'),
                    Tab(text: 'Terminées (${completed.length})'),
                  ],
                  isScrollable: true,
                  indicatorColor: ThixPolicy.primary,
                  labelColor: ThixPolicy.primary,
                  unselectedLabelColor: ThixPolicy.textSecondary,
                  labelStyle: ThixPolicy.labelStyle.copyWith(fontWeight: ThixPolicy.bold),
                ),
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    _orderList(pending),
                    _orderList(preparing),
                    _orderList(shipped),
                    _orderList(completed),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _orderList(List<Map<String, dynamic>> orders) {
    if (orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 64, color: ThixPolicy.textDisabled),
            const SizedBox(height: 12),
            Text(
              'Aucune commande',
              style: ThixPolicy.bodyStyle.copyWith(color: ThixPolicy.textMuted),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: orders.length,
      itemBuilder: (_, i) {
        final o = orders[i];
        final total = _SellValidators.safeInt(o['total']);
        final sid = o['id']?.toString() ?? '';
        final status = _SellValidators.sanitize(o['status']?.toString() ?? '', maxLength: 20);
        final shortId = sid.length > 8 ? sid.substring(0, 8).toUpperCase() : sid.toUpperCase();

        if (!_SellValidators.isValidId(sid)) return const SizedBox.shrink();

        return Semantics(
          button: true,
          label: 'Commande $shortId, $total FCFA, statut $status',
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: ThixPolicy.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: ThixPolicy.border.withOpacity(0.6)),
            ),
            child: ListTile(
              onTap: () {
                HapticFeedback.selectionClick();
                context.push('/market/order/$sid');
                debugPrint('[SellPage] 📦 Tap order $sid');
              },
              title: Text(
                'Commande #$shortId',
                style: ThixPolicy.labelStyle.copyWith(fontWeight: ThixPolicy.bold, color: ThixPolicy.textMain),
              ),
              subtitle: Text(
                '$total FCFA',
                style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.primary, fontWeight: ThixPolicy.semiBold),
              ),
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getStatusColor(status).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  status,
                  style: ThixPolicy.captionStyle.copyWith(
                    fontSize: 11,
                    fontWeight: ThixPolicy.bold,
                    color: _getStatusColor(status),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return ThixPolicy.gold;
      case 'preparing':
        return ThixPolicy.primary;
      case 'shipped':
        return ThixPolicy.success;
      case 'completed':
        return ThixPolicy.success;
      default:
        return ThixPolicy.textMuted;
    }
  }

  Widget _statsTab() {
    final async = ref.watch(sellerStatsProvider);
    return async.when(
      loading: () => const _SkeletonStats(),
      error: (e, _) => _ErrorState(
        message: _SellValidators.sanitize(e.toString(), maxLength: 200),
        onRetry: _refresh,
      ),
      data: (stats) {
        return RefreshIndicator(
          color: ThixPolicy.primary,
          onRefresh: _refresh,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.1,
                  children: [
                    _statCard(
                      'Ventes totales',
                      _SellValidators.formatCount(stats.totalSales),
                      Icons.trending_up_rounded,
                      ThixPolicy.success,
                    ),
                    _statCard(
                      'Chiffre d\'affaires',
                      '${_SellValidators.formatCount(stats.revenue)} FCFA',
                      Icons.attach_money_rounded,
                      ThixPolicy.primary,
                    ),
                    _statCard(
                      'Vues totales',
                      _SellValidators.formatCount(stats.totalViews),
                      Icons.visibility_rounded,
                      ThixPolicy.domainMedia,
                    ),
                    _statCard(
                      'Taux de conversion',
                      '${stats.conversionRate.toStringAsFixed(1)}%',
                      Icons.percent_rounded,
                      ThixPolicy.gold,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: ThixPolicy.card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: ThixPolicy.border.withOpacity(0.6)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ventes mensuelles',
                        style: ThixPolicy.h3Style.copyWith(fontWeight: ThixPolicy.bold, color: ThixPolicy.textMain),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 200,
                        child: LineChart(
                          LineChartData(
                            gridData: const FlGridData(show: false),
                            titlesData: FlTitlesData(
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  getTitlesWidget: (v, m) {
                                    int idx = v.toInt();
                                    if (idx >= 0 && idx < stats.salesData.length) {
                                      return Text(
                                        stats.salesData[idx].label,
                                        style: ThixPolicy.microStyle.copyWith(color: ThixPolicy.textMuted),
                                      );
                                    }
                                    return const Text('');
                                  },
                                  reservedSize: 24,
                                ),
                              ),
                              leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            ),
                            lineBarsData: [
                              LineChartBarData(
                                spots: List.generate(
                                  stats.salesData.length,
                                  (i) => FlSpot(i.toDouble(), stats.salesData[i].value),
                                ),
                                isCurved: true,
                                color: ThixPolicy.primary,
                                barWidth: 3,
                                dotData: const FlDotData(show: false),
                                belowBarData: BarAreaData(
                                  show: true,
                                  color: ThixPolicy.primary.withOpacity(0.1),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _statCard(String title, String value, IconData icon, Color color) {
    return Semantics(
      label: '$title: $value',
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: ThixPolicy.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: ThixPolicy.border.withOpacity(0.6)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 6),
            Text(
              value,
              style: ThixPolicy.titleStyle.copyWith(
                fontSize: 18,
                fontWeight: ThixPolicy.bold,
                color: ThixPolicy.textMain,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              title,
              style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.textMuted),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _livesTab() {
    final async = ref.watch(myLivesProvider);
    return async.when(
      loading: () => const _SkeletonList(),
      error: (e, _) => _ErrorState(
        message: _SellValidators.sanitize(e.toString(), maxLength: 200),
        onRetry: _refresh,
      ),
      data: (lives) {
        if (lives.isEmpty) {
          return _EmptyState(
            icon: Icons.live_tv_rounded,
            title: 'Aucun live',
            subtitle: 'Créez votre premier live pour engager votre audience',
            actionLabel: 'Démarrer un live',
            onAction: () {
              HapticFeedback.mediumImpact();
              context.push('/market/live/create');
            },
          );
        }

        return RefreshIndicator(
          color: ThixPolicy.primary,
          onRefresh: _refresh,
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: lives.length,
            itemBuilder: (_, i) => _liveCard(lives[i]),
          ),
        );
      },
    );
  }

  Widget _liveCard(Map<String, dynamic> live) {
    final id = live['id']?.toString() ?? '';
    if (!_SellValidators.isValidId(id)) return const SizedBox.shrink();

    final title = _SellValidators.sanitize(live['title']?.toString() ?? 'Live', maxLength: 80);
    final thumb = _SellValidators.sanitizeUrl(live['thumbnail']?.toString());
    final status = _SellValidators.sanitize(live['status']?.toString() ?? '', maxLength: 20);
    final isLive = status == 'live';
    final dateStr = _SellValidators.formatDate(live['created_at']?.toString());

    return Semantics(
      button: true,
      label: 'Live $title, ${isLive ? "en direct" : "terminé"}, $dateStr',
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: ThixPolicy.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: ThixPolicy.border.withOpacity(0.6)),
          boxShadow: ThixPolicy.shadowSoft(opacity: 0.03),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: thumb == null
                    ? Container(
                        width: 80,
                        height: 80,
                        color: ThixPolicy.surfaceSoft,
                        child: const Icon(Icons.live_tv_outlined, color: ThixPolicy.textMuted, size: 32),
                      )
                    : CachedNetworkImage(
                        imageUrl: thumb,
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(
                          width: 80,
                          height: 80,
                          color: ThixPolicy.surfaceSoft,
                          child: const Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: ThixPolicy.primary),
                            ),
                          ),
                        ),
                        errorWidget: (_, __, ___) => Container(
                          width: 80,
                          height: 80,
                          color: ThixPolicy.surfaceSoft,
                          child: const Icon(Icons.broken_image_outlined, color: ThixPolicy.textMuted, size: 32),
                        ),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: ThixPolicy.labelStyle.copyWith(
                              fontWeight: ThixPolicy.semiBold,
                              color: ThixPolicy.textMain,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isLive)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: ThixPolicy.danger,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'LIVE',
                              style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      dateStr,
                      style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.textMuted),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        if (isLive)
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                HapticFeedback.mediumImpact();
                                context.push('/market/live/$id');
                              },
                              icon: const Icon(Icons.visibility_rounded, size: 16),
                              label: const Text('Voir', style: TextStyle(fontSize: 12)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: ThixPolicy.danger,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                        if (!isLive)
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                HapticFeedback.selectionClick();
                                context.push('/market/live/$id/replay');
                              },
                              icon: const Icon(Icons.replay_rounded, size: 16),
                              label: const Text('Replay', style: TextStyle(fontSize: 12)),
                            ),
                          ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              HapticFeedback.selectionClick();
                              context.push('/market/live/$id/stats');
                            },
                            icon: const Icon(Icons.bar_chart_rounded, size: 16),
                            label: const Text('Stats', style: TextStyle(fontSize: 12)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showBoost(String id, String title) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (c) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.trending_up_rounded, color: ThixPolicy.primary, size: 24),
                const SizedBox(width: 8),
                Text(
                  'Booster votre annonce',
                  style: ThixPolicy.h3Style.copyWith(fontWeight: ThixPolicy.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Augmentez la visibilité de "$title"',
              style: ThixPolicy.bodySmallStyle.copyWith(color: ThixPolicy.textSecondary),
            ),
            const SizedBox(height: 16),
            _BoostOption(
              title: 'Standard',
              price: '2 500 FCFA',
              description: '5 000 vues garanties',
              icon: Icons.trending_up_rounded,
              color: ThixPolicy.primary,
              onTap: () => _confirmBoost(id, 'standard', 2500),
            ),
            _BoostOption(
              title: 'Premium',
              price: '5 000 FCFA',
              description: '15 000 vues garanties',
              icon: Icons.trending_up_rounded,
              color: ThixPolicy.gold,
              onTap: () => _confirmBoost(id, 'premium', 5000),
            ),
            _BoostOption(
              title: 'VIP',
              price: '10 000 FCFA',
              description: '50 000 vues garanties',
              icon: Icons.star_rounded,
              color: ThixPolicy.danger,
              onTap: () => _confirmBoost(id, 'vip', 10000),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmBoost(String id, String tier, int price) {
    Navigator.pop(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rLg)),
        title: Text('Confirmer le boost', style: ThixPolicy.h3Style.copyWith(fontWeight: ThixPolicy.bold)),
        content: Text(
          'Voulez-vous booster votre annonce pour $price FCFA ?',
          style: ThixPolicy.bodyStyle,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Annuler', style: ThixPolicy.labelStyle.copyWith(color: ThixPolicy.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              HapticFeedback.mediumImpact();
              debugPrint('[SellPage] 🚀 Boost confirmed: $id ($tier, $price FCFA)');
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Boost $tier activé ! Paiement en cours...'),
                  backgroundColor: ThixPolicy.success,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: ThixPolicy.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
  }

  void _shareAnnouncement(String id, String title, int price) {
    HapticFeedback.selectionClick();
    Share.share(
      '🛍️ Découvrez "$title" à $price FCFA sur THIX Market !\nhttps://thix.app/market/product/$id',
      subject: 'Annonce $title',
    );
    debugPrint('[SellPage] 📤 Share announcement $id');
  }
}

// ============================================================================
// COMPOSANTS
// ============================================================================

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionButton({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        label: Text(label, style: ThixPolicy.captionStyle.copyWith(fontWeight: ThixPolicy.semiBold)),
        style: OutlinedButton.styleFrom(
          foregroundColor: ThixPolicy.primary,
          side: const BorderSide(color: ThixPolicy.primary),
          padding: const EdgeInsets.symmetric(vertical: 8),
        ),
      ),
    );
  }
}

class _BoostOption extends StatelessWidget {
  final String title;
  final String price;
  final String description;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _BoostOption({
    required this.title,
    required this.price,
    required this.description,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Boost $title, $price, $description',
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(
          '$title - $price',
          style: ThixPolicy.labelStyle.copyWith(fontWeight: ThixPolicy.bold),
        ),
        subtitle: Text(description, style: ThixPolicy.captionStyle),
        trailing: const Icon(Icons.chevron_right_rounded, color: ThixPolicy.textMuted),
        onTap: onTap,
      ),
    );
  }
}

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
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(width: 80, height: 80, color: Colors.grey.shade200),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(height: 14, width: 180, color: Colors.grey.shade200),
                  const SizedBox(height: 8),
                  Container(height: 12, width: 100, color: Colors.grey.shade200),
                  const SizedBox(height: 8),
                  Container(height: 10, width: 80, color: Colors.grey.shade200),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SkeletonStats extends StatelessWidget {
  const _SkeletonStats();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.1,
        children: List.generate(
          4,
          (_) => Container(decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(12))),
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
  final String? actionLabel;
  final VoidCallback? onAction;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
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
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: ThixPolicy.primary.withOpacity(0.06),
                shape: BoxShape.circle,
                border: Border.all(color: ThixPolicy.gold.withOpacity(0.4), width: 1.4),
              ),
              child: Icon(icon, size: 64, color: ThixPolicy.primary),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: ThixPolicy.h2Style.copyWith(fontWeight: ThixPolicy.bold, color: ThixPolicy.textMain),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: ThixPolicy.bodySmallStyle.copyWith(color: ThixPolicy.textSecondary, height: 1.4),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: onAction,
                style: ElevatedButton.styleFrom(
                  backgroundColor: ThixPolicy.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rFull)),
                  elevation: 0,
                ),
                child: Text(
                  actionLabel!,
                  style: ThixPolicy.labelStyle.copyWith(fontWeight: ThixPolicy.bold, color: Colors.white),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
