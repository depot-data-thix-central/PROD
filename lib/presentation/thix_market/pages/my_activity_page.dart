// lib/presentation/thix_market/pages/my_activity_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:html/parser.dart' as html_parser;

import 'package:thix_id/core/theme/thix_design_policy.dart';
import '../providers/activity_provider.dart';

// ============================================================================
// PROVIDER WRAPPER (compatible avec ActivityProvider existant)
// ============================================================================
final activityProvider = ChangeNotifierProvider<ActivityProvider>(
  (ref) => ActivityProvider(),
);

// ============================================================================
// CONSTANTES
// ============================================================================
const Duration _kRequestTimeout = Duration(seconds: 15);
const Duration _kRetryDelay = Duration(milliseconds: 400);
const int _kMaxCommentLength = 500;

// ============================================================================
// VALIDATEURS
// ============================================================================
class _ActivityValidators {
  _ActivityValidators._();

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

  static double safeRating(dynamic rating) {
    if (rating == null) return 0.0;
    final val = (rating as num?)?.toDouble() ?? 0.0;
    return val.clamp(0.0, 5.0);
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

  /// Parse une couleur depuis DB avec fallback
  static Color safeColor(dynamic colorValue, {Color fallback = const Color(0xFFE5592F)}) {
    if (colorValue == null) return fallback;
    if (colorValue is int) return Color(colorValue);
    if (colorValue is String) {
      final hex = colorValue.replaceAll('#', '').replaceAll('0x', '');
      final parsed = int.tryParse(hex, radix: 16);
      if (parsed != null) return Color(parsed);
    }
    return fallback;
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
        debugPrint('[MyActivity] ❌ $label: timeout after $attempt attempts');
        throw TimeoutException('$label: délai dépassé');
      }
      debugPrint('[MyActivity] ⏱️ $label timeout — retry $attempt/$maxRetries');
      await Future.delayed(_kRetryDelay);
    } catch (e) {
      debugPrint('[MyActivity] ❌ $label error: $e');
      rethrow;
    }
  }
}

// ============================================================================
// PAGE PRINCIPALE
// ============================================================================
class MyActivityPage extends ConsumerStatefulWidget {
  const MyActivityPage({super.key});

  @override
  ConsumerState<MyActivityPage> createState() => _MyActivityPageState();
}

class _MyActivityPageState extends ConsumerState<MyActivityPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    debugPrint('[MyActivity] 📊 Page opened');

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAllData();
    });
  }

  Future<void> _loadAllData() async {
    final provider = ref.read(activityProvider);
    try {
      await Future.wait([
        _withRetry(() => provider.loadPurchases(), label: 'loadPurchases'),
        _withRetry(() => provider.loadSales(), label: 'loadSales'),
        _withRetry(() => provider.loadRatings(), label: 'loadRatings'),
        _withRetry(() => provider.loadGlobalStats(), label: 'loadGlobalStats'),
      ]);
      debugPrint('[MyActivity] ✓ All data loaded');
    } catch (e) {
      debugPrint('[MyActivity] ❌ Load error: $e');
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    debugPrint('[MyActivity] 👋 Page disposed');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = ref.watch(activityProvider);

    return Scaffold(
      backgroundColor: ThixPolicy.surfaceSoft,
      appBar: AppBar(
        title: Text(
          'Mon activité',
          style: ThixPolicy.h3Style.copyWith(fontWeight: ThixPolicy.bold, color: ThixPolicy.textMain),
        ),
        backgroundColor: ThixPolicy.card,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: ThixPolicy.textMain),
          tooltip: 'Retour',
          onPressed: () {
            HapticFeedback.selectionClick();
            context.pop();
          },
        ),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Achats'),
            Tab(text: 'Ventes'),
            Tab(text: 'Évaluations'),
          ],
          indicatorColor: ThixPolicy.primary,
          labelColor: ThixPolicy.primary,
          unselectedLabelColor: ThixPolicy.textSecondary,
          labelStyle: ThixPolicy.labelStyle.copyWith(fontWeight: ThixPolicy.bold),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildPurchasesTab(provider),
          _buildSalesTab(provider),
          _buildRatingsTab(provider),
        ],
      ),
    );
  }

  Widget _buildPurchasesTab(ActivityProvider provider) {
    if (provider.isLoadingPurchases) {
      return const _SkeletonList();
    }

    if (provider.purchases.isEmpty) {
      return _EmptyState(
        title: 'Aucun achat',
        subtitle: 'Vos commandes apparaîtront ici',
        icon: Icons.shopping_bag_outlined,
      );
    }

    return RefreshIndicator(
      color: ThixPolicy.primary,
      onRefresh: () async {
        HapticFeedback.selectionClick();
        await _withRetry(() => provider.loadPurchases(), label: 'refreshPurchases');
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: provider.purchases.length,
        itemBuilder: (context, index) {
          final order = provider.purchases[index];
          return _OrderCard(
            order: order,
            isPurchase: true,
            onLeaveReview: (id) => _leaveReview(id),
            onCancel: (id) => _cancelOrder(id),
          );
        },
      ),
    );
  }

  Widget _buildSalesTab(ActivityProvider provider) {
    if (provider.isLoadingSales) {
      return const _SkeletonList();
    }

    if (provider.sales.isEmpty) {
      return _EmptyState(
        title: 'Aucune vente',
        subtitle: 'Vos ventes apparaîtront ici',
        icon: Icons.sell_outlined,
      );
    }

    return RefreshIndicator(
      color: ThixPolicy.primary,
      onRefresh: () async {
        HapticFeedback.selectionClick();
        await _withRetry(() => provider.loadSales(), label: 'refreshSales');
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: provider.sales.length,
        itemBuilder: (context, index) {
          final order = provider.sales[index];
          return _OrderCard(
            order: order,
            isPurchase: false,
            onLeaveReview: null,
            onCancel: (id) => _cancelOrder(id),
          );
        },
      ),
    );
  }

  Widget _buildRatingsTab(ActivityProvider provider) {
    final stats = provider.ratingStats;
    final average = _ActivityValidators.safeDouble(stats['average']);
    final total = _ActivityValidators.safeInt(stats['total']);
    final distribution = stats['distribution'] as Map? ?? {};

    return Column(
      children: [
        // Rating summary
        Container(
          color: ThixPolicy.card,
          padding: const EdgeInsets.all(24),
          child: Row(
            children: [
              // Average rating
              Expanded(
                child: Column(
                  children: [
                    Text(
                      average.toStringAsFixed(1),
                      style: ThixPolicy.h1Style.copyWith(
                        fontSize: 48,
                        fontWeight: ThixPolicy.bold,
                        color: ThixPolicy.primary,
                      ),
                    ),
                    RatingBar.builder(
                      initialRating: average,
                      minRating: 0,
                      direction: Axis.horizontal,
                      allowHalfRating: true,
                      itemCount: 5,
                      itemSize: 20,
                      ignoreGestures: true,
                      itemBuilder: (_, __) => const Icon(Icons.star_rounded, color: ThixPolicy.gold),
                      onRatingUpdate: (_) {},
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$total évaluations',
                      style: ThixPolicy.bodySmallStyle.copyWith(color: ThixPolicy.textMuted),
                    ),
                  ],
                ),
              ),
              // Rating distribution
              Expanded(
                child: Column(
                  children: List.generate(5, (index) {
                    final star = 5 - index;
                    final percentage = _ActivityValidators.safeDouble(distribution[star]);
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          Text('$star', style: ThixPolicy.captionStyle.copyWith(fontSize: 12, color: ThixPolicy.textMain)),
                          const SizedBox(width: 4),
                          const Icon(Icons.star_rounded, size: 12, color: ThixPolicy.gold),
                          const SizedBox(width: 8),
                          Expanded(
                            child: LinearProgressIndicator(
                              value: percentage / 100,
                              backgroundColor: ThixPolicy.border,
                              color: ThixPolicy.gold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${percentage.toInt()}%',
                            style: ThixPolicy.captionStyle.copyWith(fontSize: 11, color: ThixPolicy.textMuted),
                          ),
                        ],
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        ),

        // Badges
        if (provider.badges.isNotEmpty)
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: ThixPolicy.card,
              borderRadius: BorderRadius.circular(ThixPolicy.rMd),
              border: Border.all(color: ThixPolicy.border.withOpacity(0.6)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mes badges',
                  style: ThixPolicy.h3Style.copyWith(fontWeight: ThixPolicy.bold, color: ThixPolicy.textMain),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: provider.badges.map<Widget>((badge) => _BadgeChip(badge: badge)).toList(),
                ),
              ],
            ),
          ),

        // Ratings list
        Expanded(
          child: provider.isLoadingRatings
              ? const _SkeletonList()
              : provider.ratings.isEmpty
                  ? _EmptyState(
                      title: 'Aucune évaluation',
                      subtitle: 'Les évaluations reçues apparaîtront ici',
                      icon: Icons.star_border_rounded,
                    )
                  : RefreshIndicator(
                      color: ThixPolicy.primary,
                      onRefresh: () async {
                        HapticFeedback.selectionClick();
                        await _withRetry(() => provider.loadRatings(), label: 'refreshRatings');
                      },
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: provider.ratings.length,
                        itemBuilder: (context, index) {
                          final rating = provider.ratings[index];
                          return _RatingCard(rating: rating);
                        },
                      ),
                    ),
        ),
      ],
    );
  }

  void _leaveReview(String orderId) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _LeaveReviewSheet(orderId: orderId),
    );
  }

  Future<void> _cancelOrder(String orderId) async {
    HapticFeedback.mediumImpact();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rLg)),
        title: Text('Annuler la commande ?', style: ThixPolicy.h3Style.copyWith(fontWeight: ThixPolicy.bold)),
        content: Text('Êtes-vous sûr de vouloir annuler cette commande ?', style: ThixPolicy.bodyStyle),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Non', style: ThixPolicy.labelStyle.copyWith(color: ThixPolicy.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: ThixPolicy.danger, foregroundColor: Colors.white),
            child: const Text('Oui, annuler'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await _withRetry(
          () => ref.read(activityProvider).cancelOrder(orderId),
          label: 'cancelOrder',
        );
        debugPrint('[MyActivity] ✓ Order $orderId cancelled');
        _showSuccess('Commande annulée');
      } catch (e) {
        debugPrint('[MyActivity] ❌ Cancel order error: $e');
        _showError('Erreur lors de l\'annulation');
      }
    }
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
}

// ============================================================================
// COMPOSANTS
// ============================================================================

class _OrderCard extends StatelessWidget {
  final Map<String, dynamic> order;
  final bool isPurchase;
  final void Function(String orderId)? onLeaveReview;
  final void Function(String orderId)? onCancel;

  const _OrderCard({
    required this.order,
    required this.isPurchase,
    this.onLeaveReview,
    this.onCancel,
  });

  static const Map<String, Color> _statusColors = {
    'pending': ThixPolicy.gold,
    'processing': ThixPolicy.primary,
    'shipped': ThixPolicy.domainMedia,
    'delivered': ThixPolicy.success,
    'cancelled': ThixPolicy.danger,
    'refunded': ThixPolicy.textMuted,
  };

  static const Map<String, String> _statusLabels = {
    'pending': 'En attente',
    'processing': 'En préparation',
    'shipped': 'Expédiée',
    'delivered': 'Livrée',
    'cancelled': 'Annulée',
    'refunded': 'Remboursée',
  };

  @override
  Widget build(BuildContext context) {
    final id = order['id']?.toString() ?? '';
    if (!_ActivityValidators.isValidId(id)) return const SizedBox.shrink();

    final status = order['status']?.toString() ?? 'pending';
    final statusColor = _statusColors[status] ?? ThixPolicy.textMuted;
    final statusText = _statusLabels[status] ?? 'Inconnu';
    final items = order['items'] as List? ?? [];
    final total = _ActivityValidators.safeInt(order['total']);

    return Semantics(
      button: true,
      label: 'Commande $id, statut $statusText, total $total FCFA',
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: ThixPolicy.card,
          borderRadius: BorderRadius.circular(ThixPolicy.rMd),
          border: Border.all(color: ThixPolicy.border.withOpacity(0.6)),
          boxShadow: ThixPolicy.shadowSoft(opacity: 0.03),
        ),
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            context.push('/market/order/$id');
            debugPrint('[MyActivity] 📦 Tap order $id');
          },
          borderRadius: BorderRadius.circular(ThixPolicy.rMd),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Commande #$id',
                      style: ThixPolicy.labelStyle.copyWith(fontWeight: ThixPolicy.bold, fontSize: 16, color: ThixPolicy.textMain),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        statusText,
                        style: ThixPolicy.captionStyle.copyWith(
                          color: statusColor,
                          fontSize: 12,
                          fontWeight: ThixPolicy.semiBold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ...items.take(2).map((item) => _buildItemRow(item)),
                if (items.length > 2)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'et ${items.length - 2} autre(s) article(s)',
                      style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.textMuted, fontSize: 12),
                    ),
                  ),
                const Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Total', style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.textMuted, fontSize: 12)),
                        Text(
                          '$total FCFA',
                          style: ThixPolicy.titleStyle.copyWith(
                            fontWeight: ThixPolicy.bold,
                            fontSize: 16,
                            color: ThixPolicy.primary,
                          ),
                        ),
                      ],
                    ),
                    if (status == 'delivered' && isPurchase && onLeaveReview != null)
                      Semantics(
                        button: true,
                        label: 'Laisser un avis',
                        child: OutlinedButton(
                          onPressed: () => onLeaveReview!(id),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: ThixPolicy.primary),
                            foregroundColor: ThixPolicy.primary,
                          ),
                          child: const Text('Laisser un avis'),
                        ),
                      ),
                    if (status == 'pending' && onCancel != null)
                      Semantics(
                        button: true,
                        label: 'Annuler la commande',
                        child: OutlinedButton(
                          onPressed: () => onCancel!(id),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: ThixPolicy.danger),
                            foregroundColor: ThixPolicy.danger,
                          ),
                          child: const Text('Annuler'),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildItemRow(dynamic item) {
    final imageUrl = _ActivityValidators.sanitizeUrl(item['image_url']?.toString());
    final name = _ActivityValidators.sanitize(item['name']?.toString() ?? 'Article inconnu', maxLength: 60);
    final quantity = _ActivityValidators.safeInt(item['quantity'], fallback: 1);
    final price = _ActivityValidators.safeInt(item['price']);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: imageUrl == null
                ? Container(
                    width: 50,
                    height: 50,
                    color: ThixPolicy.surfaceSoft,
                    child: const Icon(Icons.image_not_supported_outlined, color: ThixPolicy.textMuted, size: 24),
                  )
                : CachedNetworkImage(
                    imageUrl: imageUrl,
                    width: 50,
                    height: 50,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(
                      width: 50,
                      height: 50,
                      color: ThixPolicy.surfaceSoft,
                      child: const Center(child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))),
                    ),
                    errorWidget: (_, __, ___) => Container(
                      width: 50,
                      height: 50,
                      color: ThixPolicy.surfaceSoft,
                      child: const Icon(Icons.broken_image_outlined, color: ThixPolicy.textMuted, size: 20),
                    ),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: ThixPolicy.labelStyle.copyWith(fontWeight: ThixPolicy.semiBold, color: ThixPolicy.textMain),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '$quantity x $price FCFA',
                  style: ThixPolicy.captionStyle.copyWith(fontSize: 12, color: ThixPolicy.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RatingCard extends StatelessWidget {
  final Map<String, dynamic> rating;

  const _RatingCard({required this.rating});

  @override
  Widget build(BuildContext context) {
    final userAvatar = _ActivityValidators.sanitizeUrl(rating['user_avatar']?.toString());
    final userName = _ActivityValidators.sanitize(rating['user_name']?.toString() ?? 'Utilisateur', maxLength: 50);
    final ratingValue = _ActivityValidators.safeRating(rating['rating']);
    final comment = _ActivityValidators.sanitize(rating['comment']?.toString(), maxLength: 500);
    final reply = _ActivityValidators.sanitize(rating['reply']?.toString(), maxLength: 500);

    String dateStr = '';
    if (rating['created_at'] != null) {
      try {
        dateStr = DateFormat('dd/MM/yyyy').format(DateTime.parse(rating['created_at'].toString()));
      } catch (_) {
        dateStr = _ActivityValidators.sanitize(rating['created_at']?.toString(), maxLength: 20);
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: ThixPolicy.card,
        borderRadius: BorderRadius.circular(ThixPolicy.rMd),
        border: Border.all(color: ThixPolicy.border.withOpacity(0.6)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: ThixPolicy.surfaceSoft,
                  backgroundImage: userAvatar != null ? CachedNetworkImageProvider(userAvatar) : null,
                  child: userAvatar == null
                      ? const Icon(Icons.person_rounded, color: ThixPolicy.textMuted, size: 20)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        userName,
                        style: ThixPolicy.labelStyle.copyWith(fontWeight: ThixPolicy.bold, color: ThixPolicy.textMain),
                      ),
                      RatingBar.builder(
                        initialRating: ratingValue,
                        minRating: 0,
                        direction: Axis.horizontal,
                        allowHalfRating: true,
                        itemCount: 5,
                        itemSize: 14,
                        ignoreGestures: true,
                        itemBuilder: (_, __) => const Icon(Icons.star_rounded, color: ThixPolicy.gold),
                        onRatingUpdate: (_) {},
                      ),
                    ],
                  ),
                ),
                if (dateStr.isNotEmpty)
                  Text(
                    dateStr,
                    style: ThixPolicy.captionStyle.copyWith(fontSize: 11, color: ThixPolicy.textMuted),
                  ),
              ],
            ),
            if (comment.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(comment, style: ThixPolicy.bodyStyle.copyWith(color: ThixPolicy.textMain)),
            ],
            if (reply.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: ThixPolicy.surfaceSoft,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Réponse du vendeur',
                      style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.textMuted, fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    Text(reply, style: ThixPolicy.bodySmallStyle.copyWith(color: ThixPolicy.textMain)),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BadgeChip extends StatelessWidget {
  final Map<String, dynamic> badge;

  const _BadgeChip({required this.badge});

  @override
  Widget build(BuildContext context) {
    final name = _ActivityValidators.sanitize(badge['name']?.toString() ?? '', maxLength: 30);
    final colorStart = _ActivityValidators.safeColor(badge['color_start'], fallback: ThixPolicy.primary);
    final colorEnd = _ActivityValidators.safeColor(badge['color_end'], fallback: ThixPolicy.primary.withOpacity(0.7));

    if (name.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [colorStart, colorEnd]),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.emoji_events_rounded, size: 16, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            name,
            style: ThixPolicy.captionStyle.copyWith(color: Colors.white, fontSize: 12, fontWeight: ThixPolicy.bold),
          ),
        ],
      ),
    );
  }
}

class _LeaveReviewSheet extends ConsumerStatefulWidget {
  final String orderId;

  const _LeaveReviewSheet({required this.orderId});

  @override
  ConsumerState<_LeaveReviewSheet> createState() => _LeaveReviewSheetState();
}

class _LeaveReviewSheetState extends ConsumerState<_LeaveReviewSheet> {
  double _rating = 5;
  final TextEditingController _commentController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submitReview() async {
    if (_submitting) return;

    final comment = _ActivityValidators.sanitize(_commentController.text, maxLength: _kMaxCommentLength);
    if (comment.isEmpty) {
      _showError('Veuillez ajouter un commentaire');
      return;
    }

    if (_rating < 1 || _rating > 5) {
      _showError('Note invalide');
      return;
    }

    setState(() => _submitting = true);
    HapticFeedback.mediumImpact();

    try {
      await _withRetry(
        () => ref.read(activityProvider).submitReview(widget.orderId, _rating, comment),
        label: 'submitReview',
      );
      debugPrint('[MyActivity] ✓ Review submitted for ${widget.orderId}');
      if (mounted) {
        Navigator.pop(context);
        _showSuccess('Avis envoyé avec succès');
      }
    } catch (e) {
      debugPrint('[MyActivity] ❌ Submit review error: $e');
      if (mounted) _showError('Erreur lors de l\'envoi');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showError(String message) {
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
    return Container(
      padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      decoration: BoxDecoration(
        color: ThixPolicy.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
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
          Text(
            'Laisser un avis',
            style: ThixPolicy.h2Style.copyWith(fontWeight: ThixPolicy.bold, color: ThixPolicy.textMain),
          ),
          const SizedBox(height: 16),
          Text('Note', style: ThixPolicy.labelStyle.copyWith(fontWeight: ThixPolicy.semiBold, color: ThixPolicy.textMain)),
          const SizedBox(height: 8),
          RatingBar.builder(
            initialRating: _rating,
            minRating: 1,
            direction: Axis.horizontal,
            allowHalfRating: true,
            itemCount: 5,
            itemSize: 32,
            itemBuilder: (_, __) => const Icon(Icons.star_rounded, color: ThixPolicy.gold),
            onRatingUpdate: (rating) => setState(() => _rating = rating),
          ),
          const SizedBox(height: 16),
          Text('Commentaire', style: ThixPolicy.labelStyle.copyWith(fontWeight: ThixPolicy.semiBold, color: ThixPolicy.textMain)),
          const SizedBox(height: 8),
          TextField(
            controller: _commentController,
            maxLines: 4,
            maxLength: _kMaxCommentLength,
            decoration: InputDecoration(
              hintText: 'Partagez votre expérience...',
              filled: true,
              fillColor: ThixPolicy.surfaceSoft,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: ThixPolicy.primary, width: 1.5),
              ),
              counterText: '',
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _submitting ? null : () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: ThixPolicy.textSecondary,
                    side: BorderSide(color: ThixPolicy.border),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Annuler'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _submitting ? null : _submitReview,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ThixPolicy.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    elevation: 0,
                  ),
                  child: _submitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Envoyer', style: TextStyle(color: Colors.white, fontWeight: ThixPolicy.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;

  const _EmptyState({required this.title, required this.subtitle, required this.icon});

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
            child: Icon(icon, size: 64, color: ThixPolicy.textMuted),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: ThixPolicy.h3Style.copyWith(fontWeight: ThixPolicy.bold, color: ThixPolicy.textMain),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: ThixPolicy.bodySmallStyle.copyWith(color: ThixPolicy.textMuted),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _SkeletonList extends StatelessWidget {
  const _SkeletonList();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 5,
      itemBuilder: (_, __) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: ThixPolicy.card,
          borderRadius: BorderRadius.circular(ThixPolicy.rMd),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(height: 16, width: 150, color: Colors.grey.shade200),
            const SizedBox(height: 12),
            Row(
              children: [
                Container(width: 50, height: 50, color: Colors.grey.shade200),
                const SizedBox(width: 12),
                Expanded(child: Container(height: 14, color: Colors.grey.shade200)),
              ],
            ),
            const SizedBox(height: 12),
            Container(height: 14, width: 100, color: Colors.grey.shade200),
          ],
        ),
      ),
    );
  }
}
