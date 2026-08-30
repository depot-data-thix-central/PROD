// lib/presentation/thix_market/pages/shop_detail_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import 'package:html/parser.dart' as html_parser;

import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/data/models/live/live_model.dart';
import 'package:thix_id/presentation/network/live/live_viewer_screen.dart';
import '../providers/shop_provider.dart';
import '../providers/market_providers.dart';

// ============================================================================
// CONSTANTES & VALIDATEURS
// ============================================================================
const Duration _kRequestTimeout = Duration(seconds: 15);
const Duration _kRetryDelay = Duration(milliseconds: 400);

class _ShopDetailValidators {
  _ShopDetailValidators._();

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

  static int safeInt(dynamic v, {int fallback = 0}) {
    if (v == null) return fallback;
    final parsed = (v as num?)?.toInt() ?? fallback;
    return parsed < 0 ? fallback : parsed;
  }

  static double safePrice(dynamic price) {
    if (price == null) return 0.0;
    final val = (price as num?)?.toDouble() ?? 0.0;
    return val < 0 ? 0.0 : val;
  }

  /// Formate un nombre : 1000 → 1.2k, 1500000 → 1.5M
  static String formatCount(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}k';
    return '$count';
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
        debugPrint('[ShopDetail] ❌ $label: timeout after $attempt attempts');
        throw TimeoutException('$label: délai dépassé');
      }
      debugPrint('[ShopDetail] ⏱️ $label timeout — retry $attempt/$maxRetries');
      await Future.delayed(_kRetryDelay);
    } catch (e) {
      debugPrint('[ShopDetail] ❌ $label error: $e');
      rethrow;
    }
  }
}

// ============================================================================
// PROVIDER (chargement enrichi)
// ============================================================================
final shopDetailDataProvider =
    FutureProvider.autoDispose.family<ShopDetailData, String>((ref, shopId) async {
  if (!_ShopDetailValidators.isValidId(shopId)) {
    debugPrint('[ShopDetail] ⚠️ Invalid shopId: $shopId');
    throw Exception('ID boutique invalide');
  }

  debugPrint('[ShopDetail] 🏪 Loading shop ${shopId.substring(0, 8)}...');

  final db = ref.read(supabaseClientProvider);
  final uid = db.auth.currentUser?.id;

  // Charger shop + produits + is_followed en parallèle
  final shopFuture = _withRetry(
    () => db.from('shops').select('*').eq('id', shopId).maybeSingle(),
    label: 'fetchShop',
  );

  final productsFuture = _withRetry(
    () => db
        .from('products')
        .select('*')
        .eq('shop_id', shopId)
        .eq('status', 'active')
        .order('created_at', ascending: false)
        .limit(50),
    label: 'fetchProducts',
  ).then((r) => List<Map<String, dynamic>>.from(r)).catchError((_) => <Map<String, dynamic>>[]);

  final followFuture = uid != null
      ? _withRetry(
          () => db
              .from('shop_followers')
              .select('id')
              .eq('user_id', uid)
              .eq('shop_id', shopId)
              .maybeSingle(),
          label: 'checkFollow',
        ).then((r) => r != null).catchError((_) => false)
      : Future.value(false);

  final results = await Future.wait([shopFuture, productsFuture, followFuture]);

  final shopData = results[0] as Map<String, dynamic>?;
  if (shopData == null) throw Exception('Boutique introuvable');

  final data = ShopDetailData(
    raw: shopData,
    products: results[1] as List<Map<String, dynamic>>,
    isFollowed: results[2] as bool,
  );

  debugPrint('[ShopDetail] ✓ Loaded ${data.products.length} products, followed=${data.isFollowed}');
  return data;
});

// ============================================================================
// MODÈLE
// ============================================================================
class ShopDetailData {
  final Map<String, dynamic> raw;
  final List<Map<String, dynamic>> products;
  final bool isFollowed;

  const ShopDetailData({
    required this.raw,
    required this.products,
    required this.isFollowed,
  });

  String get id => raw['id']?.toString() ?? '';
  String get name => _ShopDetailValidators.sanitize(raw['name']?.toString() ?? 'Boutique', maxLength: 80);
  String get description => _ShopDetailValidators.sanitize(raw['description']?.toString() ?? '', maxLength: 1000);
  String get city => _ShopDetailValidators.sanitize(raw['city']?.toString() ?? '', maxLength: 60);
  String? get logoUrl => _ShopDetailValidators.sanitizeUrl(raw['logo_url']?.toString());
  String? get bannerUrl => _ShopDetailValidators.sanitizeUrl(raw['banner_url']?.toString());
  String? get phone => _ShopDetailValidators.sanitize(raw['phone']?.toString() ?? '', maxLength: 20).isNotEmpty ? raw['phone']?.toString() : null;
  int get followers => _ShopDetailValidators.safeInt(raw['followers']);
  int get rating => _ShopDetailValidators.safeInt(raw['rating']);
  bool get isVerified => raw['is_verified'] == true;
  bool get isLive => raw['is_live'] == true || raw['live_status'] == 'live';
  String? get liveChannelName => isLive ? raw['live_channel']?.toString() ?? raw['channel_name']?.toString() : null;
  String? get liveHostId => isLive ? raw['live_host_id']?.toString() : null;
}

// ============================================================================
// PAGE PRINCIPALE
// ============================================================================
class ShopDetailPage extends ConsumerStatefulWidget {
  final String shopId;
  const ShopDetailPage({super.key, required this.shopId});

  @override
  ConsumerState<ShopDetailPage> createState() => _ShopDetailPageState();
}

class _ShopDetailPageState extends ConsumerState<ShopDetailPage> {
  bool _isTogglingFollow = false;

  @override
  void initState() {
    super.initState();
    debugPrint('[ShopDetail] 🏪 Page opened for ${widget.shopId.substring(0, 8)}...');
  }

  @override
  void dispose() {
    debugPrint('[ShopDetail] 👋 Page disposed');
    super.dispose();
  }

  void _refresh() {
    HapticFeedback.selectionClick();
    ref.invalidate(shopDetailDataProvider(widget.shopId));
    debugPrint('[ShopDetail] 🔄 Refreshing');
  }

  Future<void> _toggleFollow(ShopDetailData data) async {
    if (_isTogglingFollow) return;

    final db = ref.read(supabaseClientProvider);
    final uid = db.auth.currentUser?.id;

    if (uid == null) {
      HapticFeedback.lightImpact();
      context.push('/login');
      return;
    }

    setState(() => _isTogglingFollow = true);
    HapticFeedback.mediumImpact();

    try {
      if (data.isFollowed) {
        await _withRetry(
          () => db.from('shop_followers').delete().eq('user_id', uid).eq('shop_id', data.id),
          label: 'unfollowShop',
        );
        debugPrint('[ShopDetail] 💔 Unfollowed ${data.id}');
      } else {
        await _withRetry(
          () => db.from('shop_followers').insert({'user_id': uid, 'shop_id': data.id}),
          label: 'followShop',
        );
        debugPrint('[ShopDetail] ❤️ Followed ${data.id}');
      }
      _refresh();
    } catch (e) {
      debugPrint('[ShopDetail] ❌ Toggle follow error: $e');
      if (mounted) _showError('Erreur lors de l\'abonnement');
    } finally {
      if (mounted) setState(() => _isTogglingFollow = false);
    }
  }

  void _shareShop(ShopDetailData data) {
    HapticFeedback.selectionClick();
    Share.share(
      '🏪 Découvrez ${data.name} sur THIX Market !\nhttps://thix.app/market/shop/${data.id}',
      subject: 'Boutique ${data.name}',
    );
    debugPrint('[ShopDetail] 📤 Share triggered for ${data.id}');
  }

  void _joinLive(ShopDetailData data) {
    HapticFeedback.mediumImpact();
    try {
      final session = LiveSession(
        id: data.id,
        channelName: data.liveChannelName ?? data.id,
        title: '${data.name} - Live',
        hostId: data.liveHostId ?? '',
        hostName: data.name,
        hostAvatarUrl: data.logoUrl,
      );
      Navigator.push(context, MaterialPageRoute(builder: (_) => LiveViewerScreen(session: session)));
      debugPrint('[ShopDetail] 🎬 Joined live ${data.id}');
    } catch (e) {
      debugPrint('[ShopDetail] ❌ Join live error: $e');
      _showError('Impossible de rejoindre le direct');
    }
  }

  void _callShop(String phone) {
    HapticFeedback.mediumImpact();
    debugPrint('[ShopDetail] 📞 Call triggered: $phone');
    _showSuccess('Appel en cours...');
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
    final async = ref.watch(shopDetailDataProvider(widget.shopId));

    return Scaffold(
      backgroundColor: ThixPolicy.surfaceSoft,
      appBar: AppBar(
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
        title: async.valueOrNull != null
            ? Text(
                async.valueOrNull!.name,
                style: ThixPolicy.h3Style.copyWith(
                  fontWeight: ThixPolicy.bold,
                  color: ThixPolicy.textMain,
                  fontSize: 16,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              )
            : Text('Boutique', style: ThixPolicy.h3Style.copyWith(fontWeight: ThixPolicy.bold, color: ThixPolicy.textMain)),
        actions: [
          if (async.valueOrNull != null) ...[
            IconButton(
              icon: const Icon(Icons.share_rounded, color: ThixPolicy.textMain),
              tooltip: 'Partager',
              onPressed: () => _shareShop(async.valueOrNull!),
            ),
            IconButton(
              icon: const Icon(Icons.refresh_rounded, color: ThixPolicy.textMain),
              tooltip: 'Rafraîchir',
              onPressed: _refresh,
            ),
          ],
        ],
      ),
      body: async.when(
        loading: () => const _SkeletonContent(),
        error: (e, _) => _ErrorState(
          message: _ShopDetailValidators.sanitize(e.toString(), maxLength: 200),
          onRetry: _refresh,
        ),
        data: (data) => _buildContent(data),
      ),
    );
  }

  Widget _buildContent(ShopDetailData data) {
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
            _buildShopHeader(data),
            const SizedBox(height: 16),

            // CTA Live si en direct
            if (data.isLive) ...[
              _buildLiveCTA(data),
              const SizedBox(height: 16),
            ],

            // Stats
            _buildStatsRow(data),
            const SizedBox(height: 16),

            // Actions (Follow + Call)
            _buildActions(data),
            const SizedBox(height: 16),

            // Produits
            _buildProductsSection(data),
          ],
        ),
      ),
    );
  }

  Widget _buildShopHeader(ShopDetailData data) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ThixPolicy.card,
        borderRadius: BorderRadius.circular(18),
        border: data.isLive ? Border.all(color: ThixPolicy.danger.withOpacity(0.4), width: 1.4) : null,
        boxShadow: ThixPolicy.shadowSoft(opacity: 0.05),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Badge LIVE
          if (data.isLive) const _LiveBadge(),
          Row(
            children: [
              // Logo
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  color: ThixPolicy.surfaceSoft,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: ThixPolicy.border),
                ),
                child: data.logoUrl == null
                    ? const Icon(Icons.store_rounded, size: 32, color: ThixPolicy.textMuted)
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: CachedNetworkImage(
                          imageUrl: data.logoUrl!,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => const Center(
                            child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: ThixPolicy.primary)),
                          ),
                          errorWidget: (_, __, ___) => const Icon(Icons.store_rounded, size: 32, color: ThixPolicy.textMuted),
                        ),
                      ),
              ),
              const SizedBox(width: 14),

              // Infos
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            data.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: ThixPolicy.h3Style.copyWith(
                              fontSize: 17,
                              fontWeight: ThixPolicy.bold,
                              color: ThixPolicy.textMain,
                            ),
                          ),
                        ),
                        if (data.isVerified) ...[
                          const SizedBox(width: 4),
                          const Icon(Icons.verified_rounded, size: 18, color: ThixPolicy.primary),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    if (data.city.isNotEmpty) ...[
                      Row(
                        children: [
                          const Icon(Icons.location_on_rounded, size: 14, color: ThixPolicy.textMuted),
                          const SizedBox(width: 4),
                          Text(
                            data.city,
                            style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.textMuted, fontSize: 13),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                    ],
                    Row(
                      children: [
                        const Icon(Icons.shopping_bag_outlined, size: 14, color: ThixPolicy.textMuted),
                        const SizedBox(width: 4),
                        Text(
                          '${data.products.length} produits',
                          style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.textMuted, fontSize: 12),
                        ),
                        const SizedBox(width: 12),
                        const Icon(Icons.favorite_rounded, size: 14, color: ThixPolicy.textMuted),
                        const SizedBox(width: 4),
                        Text(
                          _ShopDetailValidators.formatCount(data.followers),
                          style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.textMuted, fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (data.description.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              data.description,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: ThixPolicy.bodySmallStyle.copyWith(color: ThixPolicy.textSecondary, height: 1.4),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLiveCTA(ShopDetailData data) {
    return Semantics(
      button: true,
      label: 'Rejoindre le direct de ${data.name}',
      child: GestureDetector(
        onTap: () => _joinLive(data),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFFE53935), Color(0xFFB71C1C)]),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: ThixPolicy.danger.withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'EN DIRECT MAINTENANT',
                      style: ThixPolicy.labelStyle.copyWith(
                        color: Colors.white,
                        fontWeight: ThixPolicy.bold,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Rejoignez ${data.name} en live',
                      style: ThixPolicy.captionStyle.copyWith(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsRow(ShopDetailData data) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ThixPolicy.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ThixPolicy.border.withOpacity(0.6)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _StatItem(
            value: _ShopDetailValidators.formatCount(data.products.length),
            label: 'Produits',
            icon: Icons.inventory_2_rounded,
            color: ThixPolicy.primary,
          ),
          Container(width: 1, height: 40, color: ThixPolicy.border),
          _StatItem(
            value: _ShopDetailValidators.formatCount(data.followers),
            label: 'Abonnés',
            icon: Icons.favorite_rounded,
            color: ThixPolicy.danger,
          ),
          Container(width: 1, height: 40, color: ThixPolicy.border),
          _StatItem(
            value: data.rating > 0 ? '${data.rating}.0 ★' : 'N/A',
            label: 'Note',
            icon: Icons.star_rounded,
            color: ThixPolicy.gold,
          ),
        ],
      ),
    );
  }

  Widget _buildActions(ShopDetailData data) {
    return Row(
      children: [
        // Bouton Follow
        Expanded(
          child: Semantics(
            button: true,
            label: data.isFollowed ? 'Se désabonner' : 'Suivre la boutique',
            child: GestureDetector(
              onTap: _isTogglingFollow ? null : () => _toggleFollow(data),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: data.isFollowed ? ThixPolicy.surface : ThixPolicy.primary,
                  borderRadius: BorderRadius.circular(14),
                  border: data.isFollowed ? Border.all(color: ThixPolicy.border) : null,
                ),
                child: _isTogglingFollow
                    ? const Center(
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: ThixPolicy.primary),
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            data.isFollowed ? Icons.check_rounded : Icons.add_rounded,
                            color: data.isFollowed ? ThixPolicy.textMain : Colors.white,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            data.isFollowed ? 'Suivi' : 'Suivre',
                            style: ThixPolicy.labelStyle.copyWith(
                              color: data.isFollowed ? ThixPolicy.textMain : Colors.white,
                              fontWeight: ThixPolicy.bold,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),

        if (data.phone != null) ...[
          const SizedBox(width: 12),
          Semantics(
            button: true,
            label: 'Appeler la boutique',
            child: GestureDetector(
              onTap: () => _callShop(data.phone!),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: ThixPolicy.success.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: ThixPolicy.success.withOpacity(0.3)),
                ),
                child: const Icon(Icons.phone_rounded, color: ThixPolicy.success, size: 20),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildProductsSection(ShopDetailData data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Produits',
              style: ThixPolicy.h3Style.copyWith(
                fontWeight: ThixPolicy.bold,
                color: ThixPolicy.textMain,
                fontSize: 15,
              ),
            ),
            const Spacer(),
            if (data.products.length > 6)
              Semantics(
                button: true,
                label: 'Voir tous les produits',
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    context.push('/market/search?shop=${data.id}');
                  },
                  child: Text(
                    'Voir tout',
                    style: ThixPolicy.labelStyle.copyWith(
                      color: ThixPolicy.gold,
                      fontSize: 12,
                      fontWeight: ThixPolicy.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (data.products.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: ThixPolicy.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: ThixPolicy.border.withOpacity(0.6)),
            ),
            child: Center(
              child: Column(
                children: [
                  const Icon(Icons.inventory_2_outlined, size: 40, color: ThixPolicy.textMuted),
                  const SizedBox(height: 8),
                  Text(
                    'Aucun produit',
                    style: ThixPolicy.bodySmallStyle.copyWith(color: ThixPolicy.textMuted),
                  ),
                ],
              ),
            ),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 0.72,
            ),
            itemCount: data.products.length > 6 ? 6 : data.products.length,
            itemBuilder: (context, i) => _ProductCard(product: data.products[i]),
          ),
      ],
    );
  }
}

// ============================================================================
// COMPOSANTS
// ============================================================================

class _LiveBadge extends StatefulWidget {
  const _LiveBadge();
  @override
  State<_LiveBadge> createState() => _LiveBadgeState();
}

class _LiveBadgeState extends State<_LiveBadge> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);
    _scale = Tween<double>(begin: 0.7, end: 1.3).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: ThixPolicy.danger,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ScaleTransition(
            scale: _scale,
            child: Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
            ),
          ),
          const SizedBox(width: 4),
          Text(
            'EN DIRECT',
            style: ThixPolicy.microStyle.copyWith(
              color: Colors.white,
              fontSize: 10,
              fontWeight: ThixPolicy.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final Color color;

  const _StatItem({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Semantics(
        label: '$label: $value',
        child: Column(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(height: 4),
            Text(
              value,
              style: ThixPolicy.titleStyle.copyWith(
                fontWeight: ThixPolicy.bold,
                color: ThixPolicy.textMain,
                fontSize: 14,
              ),
            ),
            Text(
              label,
              style: ThixPolicy.microStyle.copyWith(
                color: ThixPolicy.textMuted,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final Map<String, dynamic> product;
  const _ProductCard({required this.product});

  @override
  Widget build(BuildContext context) {
    final id = product['id']?.toString() ?? '';
    if (!_ShopDetailValidators.isValidId(id)) return const SizedBox.shrink();

    final img = _ShopDetailValidators.sanitizeUrl(product['image_url']?.toString());
    final title = _ShopDetailValidators.sanitize(product['title']?.toString() ?? '', maxLength: 60);
    final price = _ShopDetailValidators.safePrice(product['price']);
    final currency = _ShopDetailValidators.parseCurrency(product['currency']?.toString());
    final symbol = currency;

    return Semantics(
      button: true,
      label: '$title, ${price.toInt()} $symbol',
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          context.push('/market/product/$id');
          debugPrint('[ShopDetail] 🛍️ Tap product $id');
        },
        child: Container(
          decoration: BoxDecoration(
            color: ThixPolicy.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: ThixPolicy.border.withOpacity(0.6)),
            boxShadow: ThixPolicy.shadowSoft(opacity: 0.03),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                  child: img == null
                      ? Container(
                          color: ThixPolicy.surfaceSoft,
                          child: const Center(
                            child: Icon(Icons.image_not_supported_outlined, color: ThixPolicy.textMuted, size: 32),
                          ),
                        )
                      : CachedNetworkImage(
                          imageUrl: img,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => const Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: ThixPolicy.primary),
                            ),
                          ),
                          errorWidget: (_, __, ___) => Container(
                            color: ThixPolicy.surfaceSoft,
                            child: const Icon(Icons.broken_image_outlined, color: ThixPolicy.textMuted, size: 32),
                          ),
                        ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: ThixPolicy.labelStyle.copyWith(
                        fontSize: 12,
                        fontWeight: ThixPolicy.semiBold,
                        color: ThixPolicy.textMain,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      price > 0 ? '${price.toInt()} $symbol' : 'Prix sur demande',
                      style: ThixPolicy.labelStyle.copyWith(
                        fontWeight: ThixPolicy.bold,
                        fontSize: 13,
                        color: ThixPolicy.primary,
                      ),
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
}

class _SkeletonContent extends StatelessWidget {
  const _SkeletonContent();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: ThixPolicy.card,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(height: 16, width: 140, color: Colors.grey.shade200),
                      const SizedBox(height: 8),
                      Container(height: 12, width: 100, color: Colors.grey.shade200),
                      const SizedBox(height: 6),
                      Container(height: 10, width: 120, color: Colors.grey.shade200),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Stats
          Container(
            height: 80,
            decoration: BoxDecoration(
              color: ThixPolicy.card,
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          const SizedBox(height: 16),

          // Actions
          Container(
            height: 52,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          const SizedBox(height: 16),

          // Products
          Container(height: 14, width: 80, color: Colors.grey.shade200),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 0.72,
            ),
            itemCount: 4,
            itemBuilder: (_, __) => Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(14),
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
