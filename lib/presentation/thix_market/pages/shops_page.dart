// lib/presentation/thix_market/pages/shops_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:html/parser.dart' as html_parser;

import 'package:thix_id/core/theme/thix_design_policy.dart';
import '../providers/shop_provider.dart';

// ============================================================================
// CONSTANTES & VALIDATEURS
// ============================================================================
class _ShopsValidators {
  _ShopsValidators._();

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

  static double clampRating(dynamic rating) {
    if (rating == null) return 0.0;
    final val = (rating as num?)?.toDouble() ?? 0.0;
    return val.clamp(0.0, 5.0);
  }

  static int safeFollowers(dynamic followers) {
    if (followers == null) return 0;
    final val = (followers as num?)?.toInt() ?? 0;
    return val < 0 ? 0 : val;
  }
}

// ============================================================================
// PAGE PRINCIPALE
// ============================================================================
class ShopsPage extends ConsumerStatefulWidget {
  const ShopsPage({super.key});

  @override
  ConsumerState<ShopsPage> createState() => _ShopsPageState();
}

class _ShopsPageState extends ConsumerState<ShopsPage> {
  @override
  void initState() {
    super.initState();
    debugPrint('[Shops] 🏪 Page opened');
  }

  @override
  void dispose() {
    debugPrint('[Shops] 👋 Page disposed');
    super.dispose();
  }

  void _refresh() {
    HapticFeedback.selectionClick();
    ref.invalidate(myShopsProvider);
    ref.invalidate(followedShopsProvider);
    debugPrint('[Shops] 🔄 Refreshing providers');
  }

  @override
  Widget build(BuildContext context) {
    final myAsync = ref.watch(myShopsProvider);
    final followedAsync = ref.watch(followedShopsProvider);

    final myCount = myAsync.valueOrNull?.length ?? 0;
    final followedCount = followedAsync.valueOrNull?.length ?? 0;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: ThixPolicy.surfaceSoft,
        appBar: AppBar(
          title: Text(
            'Mes Boutiques',
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
          bottom: TabBar(
            labelColor: ThixPolicy.primary,
            unselectedLabelColor: ThixPolicy.textSecondary,
            indicatorColor: ThixPolicy.gold,
            indicatorWeight: 3,
            labelStyle: ThixPolicy.labelStyle.copyWith(fontWeight: ThixPolicy.bold),
            unselectedLabelStyle: ThixPolicy.labelStyle,
            tabs: [
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.store_rounded, size: 18),
                    const SizedBox(width: 6),
                    Text('Mes boutiques'),
                    if (myCount > 0) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: ThixPolicy.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(ThixPolicy.rFull),
                        ),
                        child: Text(
                          '$myCount',
                          style: ThixPolicy.microStyle.copyWith(
                            color: ThixPolicy.primary,
                            fontWeight: ThixPolicy.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.favorite_rounded, size: 18),
                    const SizedBox(width: 6),
                    Text('Suivies'),
                    if (followedCount > 0) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: ThixPolicy.danger.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(ThixPolicy.rFull),
                        ),
                        child: Text(
                          '$followedCount',
                          style: ThixPolicy.microStyle.copyWith(
                            color: ThixPolicy.danger,
                            fontWeight: ThixPolicy.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
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
          children: [
            _buildMyShopsTab(myAsync),
            _buildFollowedShopsTab(followedAsync),
          ],
        ),
      ),
    );
  }

  Widget _buildMyShopsTab(AsyncValue<List<Map<String, dynamic>>> async) {
    return async.when(
      loading: () => const _SkeletonList(),
      error: (e, _) => _ErrorState(
        message: _ShopsValidators.sanitize(e.toString(), maxLength: 200),
        onRetry: _refresh,
      ),
      data: (list) {
        if (list.isEmpty) {
          return _EmptyState(
            icon: Icons.storefront_rounded,
            title: 'Aucune boutique',
            subtitle: 'Créez votre première boutique pour commencer à vendre',
            actionLabel: 'Créer ma boutique',
            onAction: () {
              HapticFeedback.mediumImpact();
              context.push('/market/shop/create');
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
            itemCount: list.length,
            itemBuilder: (context, i) => _buildShopCard(list[i], isOwned: true),
          ),
        );
      },
    );
  }

  Widget _buildFollowedShopsTab(AsyncValue<List<Map<String, dynamic>>> async) {
    return async.when(
      loading: () => const _SkeletonList(),
      error: (e, _) => _ErrorState(
        message: _ShopsValidators.sanitize(e.toString(), maxLength: 200),
        onRetry: _refresh,
      ),
      data: (list) {
        if (list.isEmpty) {
          return _EmptyState(
            icon: Icons.favorite_border_rounded,
            title: 'Aucune boutique suivie',
            subtitle: 'Explorez les boutiques et suivez vos favorites',
            actionLabel: 'Explorer les boutiques',
            onAction: () {
              HapticFeedback.mediumImpact();
              context.push('/market/shops');
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
            itemCount: list.length,
            itemBuilder: (context, i) => _buildShopCard(list[i], isOwned: false),
          ),
        );
      },
    );
  }

  Widget _buildShopCard(Map<String, dynamic> shop, {required bool isOwned}) {
    final id = shop['id']?.toString();
    if (id == null || id.isEmpty) return const SizedBox.shrink();

    final name = _ShopsValidators.sanitize(shop['name']?.toString() ?? 'Boutique', maxLength: 60);
    final city = _ShopsValidators.sanitize(shop['city']?.toString() ?? '', maxLength: 40);
    final logoUrl = _ShopsValidators.sanitizeUrl(shop['logo_url']?.toString());
    final rating = _ShopsValidators.clampRating(shop['rating']);
    final followers = _ShopsValidators.safeFollowers(shop['followers']);
    final isVerified = shop['is_verified'] == true;

    return Semantics(
      button: true,
      label: 'Boutique $name, note $rating, $followers abonnés',
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
              context.push('/market/shop/$id');
              debugPrint('[Shops] 🏪 Tap shop $id');
            },
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  // Avatar
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: ThixPolicy.border, width: 1.5),
                    ),
                    child: CircleAvatar(
                      radius: 26,
                      backgroundColor: ThixPolicy.surfaceSoft,
                      backgroundImage: logoUrl != null ? CachedNetworkImageProvider(logoUrl) : null,
                      child: logoUrl == null
                          ? const Icon(Icons.store_rounded, color: ThixPolicy.textMuted, size: 26)
                          : null,
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Infos
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                name,
                                style: ThixPolicy.labelStyle.copyWith(
                                  fontWeight: ThixPolicy.bold,
                                  fontSize: 14,
                                  color: ThixPolicy.textMain,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isVerified) ...[
                              const SizedBox(width: 4),
                              const Icon(Icons.verified_rounded, size: 14, color: ThixPolicy.primary),
                            ],
                            if (isOwned) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: ThixPolicy.success.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(ThixPolicy.rSm),
                                ),
                                child: Text(
                                  'Propriétaire',
                                  style: ThixPolicy.microStyle.copyWith(
                                    color: ThixPolicy.success,
                                    fontWeight: ThixPolicy.bold,
                                    fontSize: 9,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        RatingBar.builder(
                          initialRating: rating,
                          itemCount: 5,
                          itemSize: 12,
                          ignoreGestures: true,
                          allowHalfRating: true,
                          itemBuilder: (_, __) => const Icon(Icons.star_rounded, color: ThixPolicy.gold),
                          onRatingUpdate: (_) {},
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            if (city.isNotEmpty) ...[
                              const Icon(Icons.location_on_outlined, size: 11, color: ThixPolicy.textMuted),
                              const SizedBox(width: 2),
                              Text(
                                city,
                                style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.textMuted, fontSize: 11),
                              ),
                              const SizedBox(width: 8),
                            ],
                            const Icon(Icons.people_outline_rounded, size: 11, color: ThixPolicy.textMuted),
                            const SizedBox(width: 2),
                            Text(
                              '$followers abonnés',
                              style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.textMuted, fontSize: 11),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Chevron
                  const Icon(Icons.chevron_right_rounded, color: ThixPolicy.textMuted, size: 22),
                ],
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
              width: 52,
              height: 52,
              decoration: BoxDecoration(color: Colors.grey.shade200, shape: BoxShape.circle),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(height: 14, width: 140, color: Colors.grey.shade200),
                  const SizedBox(height: 8),
                  Container(height: 10, width: 80, color: Colors.grey.shade200),
                  const SizedBox(height: 6),
                  Container(height: 10, width: 100, color: Colors.grey.shade200),
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
