// lib/presentation/thix_market/pages/supermarket_space_page.dart
// ============================================================================
// ESPACE SUPERMARCHÉ — métaphore du vrai magasin : devanture + allées
// ============================================================================
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/l10n/app_localizations.dart';
import 'package:thix_id/presentation/thix_market/models/supermarket_models.dart';
import 'package:thix_id/presentation/thix_market/providers/supermarket_providers.dart';
import 'package:thix_id/presentation/thix_market/widgets/products/product_card.dart';

import 'department_products_page.dart';

class SupermarketSpacePage extends ConsumerWidget {
  final String supermarketId;
  const SupermarketSpacePage({super.key, required this.supermarketId});

  String _tr(AppLocalizations l10n, String key, String fb) {
    final v = l10n.t(key);
    return (v.isEmpty || v == key) ? fb : v;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final shopAsync = ref.watch(supermarketDetailsProvider(supermarketId));
    final deptsAsync = ref.watch(departmentsProvider(supermarketId));
    final promosAsync = ref.watch(supermarketPromosProvider(supermarketId));

    return Scaffold(
      backgroundColor: ThixPolicy.surfaceSoft,
      body: shopAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (shop) {
          if (shop == null) {
            return const Center(child: Text('Supermarché introuvable'));
          }
          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              _StorefrontHeader(shop: shop, l10n: l10n),
              SliverToBoxAdapter(
                child: _tr(
                        l10n, 'sm_aisles_title', 'Plan du supermarché')
                    .isEmpty
                    ? const SizedBox.shrink()
                    : Padding(
                        padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                        child: Row(
                          children: [
                            const Icon(Icons.map_rounded,
                                size: 18, color: ThixPolicy.primaryDeep),
                            const SizedBox(width: 8),
                            Text(
                              _tr(l10n, 'sm_aisles_title',
                                  'Plan du supermarché'),
                              style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  color: ThixPolicy.textMain),
                            ),
                          ],
                        ),
                      ),
              ),
              // ── GRILLE DES RAYONS (allées numérotées) ──
              deptsAsync.when(
                loading: () => const SliverToBoxAdapter(
                    child: Center(child: CircularProgressIndicator())),
                error: (e, _) => SliverToBoxAdapter(child: Center(child: Text('$e'))),
                data: (depts) {
                  if (depts.isEmpty) {
                    return const SliverToBoxAdapter(
                        child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: Text('Aucun rayon')),
                    ));
                  }
                  return SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverGrid(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 0.85,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (ctx, i) => _AisleTile(
                          dept: depts[i],
                          aisleNumber: i + 1,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => DepartmentProductsPage(
                                  departmentId: depts[i].id,
                                  departmentName: depts[i].name,
                                  aisleNumber: i + 1,
                                  accentColor: depts[i].color,
                                ),
                              ),
                            );
                          },
                        ),
                        childCount: depts.length,
                      ),
                    ),
                  );
                },
              ),
              // ── PROMOS DU JOUR ──
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                  child: Row(
                    children: [
                      const Icon(Icons.local_offer_rounded,
                          size: 18, color: ThixPolicy.danger),
                      const SizedBox(width: 8),
                      Text(
                        _tr(l10n, 'sm_promos', 'Promos du jour'),
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: ThixPolicy.textMain),
                      ),
                    ],
                  ),
                ),
              ),
              promosAsync.when(
                loading: () => const SliverToBoxAdapter(
                    child: SizedBox(height: 60)),
                error: (e, _) => const SliverToBoxAdapter(
                    child: SizedBox.shrink()),
                data: (promos) {
                  if (promos.isEmpty) {
                    return const SliverToBoxAdapter(
                        child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('Aucune promo aujourd\'hui.',
                          style: TextStyle(color: ThixPolicy.textMuted)),
                    ));
                  }
                  return SliverToBoxAdapter(
                    child: SizedBox(
                      height: 240,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: promos.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 12),
                        itemBuilder: (_, i) => SizedBox(
                          width: 160,
                          child: ProductCard(
                            product: promos[i],
                            isFlashSale: true,
                            onTap: (_) => context
                                .push('/market/product/${promos[i]['id']}'),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 120)),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/market/cart'),
        backgroundColor: ThixPolicy.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.shopping_cart_rounded, size: 20),
        label: Text(_tr(l10n, 'sm_cart', 'Panier')),
      ),
    );
  }
}

// ============================================================================
// DEVANTURE (header immersif)
// ============================================================================
class _StorefrontHeader extends StatelessWidget {
  final Map<String, dynamic> shop;
  final AppLocalizations l10n;
  const _StorefrontHeader({required this.shop, required this.l10n});

  @override
  Widget build(BuildContext context) {
    final cover = shop['cover_url']?.toString();
    final logo = shop['logo_url']?.toString();
    final name = shop['name']?.toString() ?? '';
    final city = shop['city']?.toString() ?? '';
    final address = shop['address']?.toString() ?? '';
    final rating = (shop['rating'] as num?)?.toDouble() ?? 0;

    return SliverAppBar(
      expandedHeight: 220,
      pinned: true,
      backgroundColor: ThixPolicy.primaryDeep,
      leading: Padding(
        padding: const EdgeInsets.all(8),
        child: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.35),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.arrow_back_ios_new_rounded,
                color: Colors.white, size: 16),
          ),
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            if (cover != null && cover.isNotEmpty)
              CachedNetworkImage(imageUrl: cover, fit: BoxFit.cover)
            else
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [ThixPolicy.primaryDeep, ThixPolicy.domainMarket],
                  ),
                ),
              ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.25),
                    Colors.transparent,
                    ThixPolicy.surfaceSoft,
                  ],
                  stops: const [0, 0.55, 1],
                ),
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 12,
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                      boxShadow: ThixPolicy.shadowSoft(),
                    ),
                    child: logo != null && logo.isNotEmpty
                        ? ClipOval(
                            child: CachedNetworkImage(
                                imageUrl: logo, fit: BoxFit.cover))
                        : const Icon(Icons.storefront_rounded,
                            color: ThixPolicy.primaryDeep, size: 26),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: ThixPolicy.textMain)),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(Icons.place_rounded,
                                size: 11, color: ThixPolicy.textMuted),
                            const SizedBox(width: 3),
                            Expanded(
                              child: Text(
                                address.isNotEmpty
                                    ? '$city · $address'
                                    : city,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: ThixPolicy.textSecondary),
                              ),
                            ),
                          ],
                        ),
                        if (rating > 0)
                          Row(
                            children: [
                              const Icon(Icons.star_rounded,
                                  size: 12, color: ThixPolicy.gold),
                              const SizedBox(width: 3),
                              Text(rating.toStringAsFixed(1),
                                  style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: ThixPolicy.gold)),
                            ],
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// TUILE RAYON (allée numérotée)
// ============================================================================
class _AisleTile extends StatelessWidget {
  final SupermarketDepartment dept;
  final int aisleNumber;
  final VoidCallback onTap;
  const _AisleTile({
    required this.dept,
    required this.aisleNumber,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Allée $aisleNumber : ${dept.name}',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: ThixPolicy.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: dept.color.withOpacity(0.35)),
            boxShadow: ThixPolicy.shadowSoft(),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Numéro d'allée
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: dept.color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Allée $aisleNumber',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    color: dept.color,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: dept.color.withOpacity(0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(dept.icon, color: dept.color, size: 26),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Text(
                  dept.name,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: ThixPolicy.textMain,
                    height: 1.2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
