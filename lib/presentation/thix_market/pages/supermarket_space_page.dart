// lib/presentation/thix_market/pages/supermarket_space_page.dart
// ============================================================================
// SUPERMARCHÉ 3D IMMERSIF — Expérience nouvelle génération
// ============================================================================
import 'dart:math' as math;
import 'dart:ui' as ui;

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

class SupermarketSpacePage extends ConsumerStatefulWidget {
  final String supermarketId;
  const SupermarketSpacePage({super.key, required this.supermarketId});

  @override
  ConsumerState<SupermarketSpacePage> createState() =>
      _SupermarketSpacePageState();
}

class _SupermarketSpacePageState extends ConsumerState<SupermarketSpacePage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entranceCtrl;

  @override
  void initState() {
    super.initState();
    _entranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _entranceCtrl.forward();
    });
  }

  @override
  void dispose() {
    _entranceCtrl.dispose();
    super.dispose();
  }

  String _tr(AppLocalizations l10n, String key, String fb) {
    final v = l10n.t(key);
    return (v.isEmpty || v == key) ? fb : v;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final shopAsync = ref.watch(supermarketDetailsProvider(widget.supermarketId));
    final deptsAsync = ref.watch(departmentsProvider(widget.supermarketId));
    final promosAsync = ref.watch(supermarketPromosProvider(widget.supermarketId));
    final allProductsAsync = ref.watch(
      supermarketAllProductsProvider(widget.supermarketId),
    );

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      body: shopAsync.when(
        loading: () => const _LoadingEntrance(),
        error: (e, _) => Center(
          child: Text('$e', style: const TextStyle(color: Colors.white)),
        ),
        data: (shop) {
          if (shop == null) {
            return const Center(
              child: Text(
                'Supermarché introuvable',
                style: TextStyle(color: Colors.white),
              ),
            );
          }
          return Stack(
            children: [
              // Fond atmosphérique
              Positioned.fill(
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0xFF1A1F2E),
                        Color(0xFF0A0E1A),
                      ],
                    ),
                  ),
                ),
              ),
              CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  _ImmersiveStorefront(shop: shop, l10n: l10n),

                  // ── TITRE : PLAN 3D DU MAGASIN ──
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: ThixPolicy.primary.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.view_in_ar_rounded,
                              size: 18,
                              color: ThixPolicy.primary,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _tr(l10n, 'sm_aisles_title', 'Plan du supermarché'),
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                Text(
                                  _tr(
                                    l10n,
                                    'sm_aisles_subtitle',
                                    'Explorez nos rayons en 3D',
                                  ),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.white54,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ── GRILLE 3D DES RAYONS ──
                  deptsAsync.when(
                    loading: () => const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.all(40),
                        child: Center(
                          child: CircularProgressIndicator(color: Colors.white),
                        ),
                      ),
                    ),
                    error: (e, _) => SliverToBoxAdapter(
                      child: Center(
                        child: Text('$e', style: const TextStyle(color: Colors.white)),
                      ),
                    ),
                    data: (depts) {
                      if (depts.isEmpty) {
                        return const SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.all(40),
                            child: Center(
                              child: Text(
                                'Aucun rayon disponible',
                                style: TextStyle(color: Colors.white54),
                              ),
                            ),
                          ),
                        );
                      }

                      // Récupérer les produits pour afficher le stock
                      final allProducts = allProductsAsync.valueOrNull ?? [];

                      return SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (ctx, i) {
                              final dept = depts[i];
                              final deptProducts = allProducts
                                  .where((p) => p['department_id'] == dept.id)
                                  .toList();

                              return AnimatedBuilder(
                                animation: _entranceCtrl,
                                builder: (ctx, child) {
                                  final delay = i * 0.06;
                                  final progress = ((_entranceCtrl.value - delay) / 0.3)
                                      .clamp(0.0, 1.0);
                                  final curve = Curves.easeOutCubic.transform(progress);

                                  return Transform.translate(
                                    offset: Offset(0, 60 * (1 - curve)),
                                    child: Opacity(
                                      opacity: curve,
                                      child: child,
                                    ),
                                  );
                                },
                                child: Padding(
                                  padding: const EdgeInsets.only(bottom: 16),
                                  child: _Aisle3D(
                                    dept: dept,
                                    aisleNumber: i + 1,
                                    products: deptProducts,
                                    onTap: () {
                                      HapticFeedback.mediumImpact();
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => DepartmentProductsPage(
                                            departmentId: dept.id,
                                            departmentName: dept.name,
                                            aisleNumber: i + 1,
                                            accentColor: dept.color,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              );
                            },
                            childCount: depts.length,
                          ),
                        ),
                      );
                    },
                  ),

                  // ── PROMOS DU JOUR ──
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: ThixPolicy.danger.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.local_fire_department_rounded,
                              size: 18,
                              color: ThixPolicy.danger,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _tr(l10n, 'sm_promos', 'Promos du jour'),
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                Text(
                                  _tr(l10n, 'sm_promos_subtitle', 'Offres limitées'),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.white54,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  promosAsync.when(
                    loading: () => const SliverToBoxAdapter(child: SizedBox(height: 60)),
                    error: (_, __) => const SliverToBoxAdapter(child: SizedBox.shrink()),
                    data: (promos) {
                      if (promos.isEmpty) {
                        return SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              _tr(l10n, 'sm_no_promos', 'Aucune promo aujourd\'hui.'),
                              style: const TextStyle(color: Colors.white38),
                            ),
                          ),
                        );
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
                                onTap: (_) => context.push(
                                  '/market/product/${promos[i]['id']}',
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 120)),
                ],
              ),

              // ── BOUTON PANIER FLOTTANT ──
              Positioned(
                right: 16,
                bottom: 24,
                child: _FloatingCartButton(l10n: l10n),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ============================================================================
// LOADING IMMERSIF
// ============================================================================
class _LoadingEntrance extends StatelessWidget {
  const _LoadingEntrance();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1A1F2E), Color(0xFF0A0E1A)],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: ThixPolicy.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.storefront_rounded,
                size: 40,
                color: ThixPolicy.primary,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Ouverture du magasin...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: ThixPolicy.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// DEVANTURE IMMERSIVE (header sombre premium)
// ============================================================================
class _ImmersiveStorefront extends StatelessWidget {
  final Map<String, dynamic> shop;
  final AppLocalizations l10n;
  const _ImmersiveStorefront({required this.shop, required this.l10n});

  @override
  Widget build(BuildContext context) {
    final cover = shop['cover_url']?.toString();
    final logo = shop['logo_url']?.toString();
    final name = shop['name']?.toString() ?? '';
    final city = shop['city']?.toString() ?? '';
    final address = shop['address']?.toString() ?? '';
    final rating = (shop['rating'] as num?)?.toDouble() ?? 0;
    final isOpen = (shop['is_open'] as bool?) ?? true;

    return SliverAppBar(
      expandedHeight: 280,
      pinned: true,
      backgroundColor: const Color(0xFF0A0E1A),
      leading: Padding(
        padding: const EdgeInsets.all(8),
        child: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.5),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white24),
            ),
            child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 16),
          ),
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            // Image de couverture avec effet cinematic
            if (cover != null && cover.isNotEmpty)
              CachedNetworkImage(
                imageUrl: cover,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => _DefaultStorefrontCover(),
              )
            else
              const _DefaultStorefrontCover(),

            // Overlay sombre en dégradé
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.3),
                    Colors.black.withOpacity(0.1),
                    Colors.black.withOpacity(0.6),
                    const Color(0xFF0A0E1A),
                  ],
                  stops: const [0, 0.3, 0.7, 1],
                ),
              ),
            ),

            // Grain cinématique subtil
            Positioned.fill(
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 0.3, sigmaY: 0.3),
                child: Container(color: Colors.transparent),
              ),
            ),

            // Infos du magasin en bas
            Positioned(
              left: 16,
              right: 16,
              bottom: 20,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Logo
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: ThixPolicy.primary.withOpacity(0.5),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: logo != null && logo.isNotEmpty
                        ? ClipOval(
                            child: CachedNetworkImage(imageUrl: logo, fit: BoxFit.cover),
                          )
                        : const Icon(
                            Icons.storefront_rounded,
                            color: ThixPolicy.primaryDeep,
                            size: 30,
                          ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  letterSpacing: -0.4,
                                ),
                              ),
                            ),
                            if (isOpen) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: ThixPolicy.success.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: ThixPolicy.success.withOpacity(0.5),
                                  ),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.circle, color: ThixPolicy.success, size: 6),
                                    SizedBox(width: 3),
                                    Text(
                                      'OUVERT',
                                      style: TextStyle(
                                        fontSize: 8,
                                        fontWeight: FontWeight.w900,
                                        color: ThixPolicy.success,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.place_rounded, size: 11, color: Colors.white70),
                            const SizedBox(width: 3),
                            Expanded(
                              child: Text(
                                address.isNotEmpty ? '$city · $address' : city,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.white70,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (rating > 0) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.star_rounded, size: 13, color: ThixPolicy.gold),
                              const SizedBox(width: 3),
                              Text(
                                rating.toStringAsFixed(1),
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: ThixPolicy.gold,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                width: 3,
                                height: 3,
                                decoration: const BoxDecoration(
                                  color: Colors.white38,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Livraison 30min',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),
                        ],
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

class _DefaultStorefrontCover extends StatelessWidget {
  const _DefaultStorefrontCover();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            ThixPolicy.primaryDeep,
            const Color(0xFF1E40AF),
            ThixPolicy.domainMarket,
          ],
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(painter: _StorefrontPatternPainter()),
          ),
        ],
      ),
    );
  }
}

class _StorefrontPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (var i = 0; i < size.width; i += 40) {
      canvas.drawLine(Offset(i.toDouble(), 0), Offset(i.toDouble(), size.height), paint);
    }
    for (var i = 0; i < size.height; i += 40) {
      canvas.drawLine(Offset(0, i.toDouble()), Offset(size.width, i.toDouble()), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ============================================================================
// ALLÉE 3D COMPLÈTE (étagère + enseigne + effets)
// ============================================================================
class _Aisle3D extends StatelessWidget {
  final SupermarketDepartment dept;
  final int aisleNumber;
  final List<Map<String, dynamic>> products;
  final VoidCallback onTap;

  const _Aisle3D({
    required this.dept,
    required this.aisleNumber,
    required this.products,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isFresh = dept.iconKey == 'produce' || dept.iconKey == 'dairy';
    final isFrozen = dept.iconKey == 'frozen';
    final isBakery = dept.iconKey == 'bakery';
    final isButcher = dept.iconKey == 'butcher';

    // Prendre les 6 premiers produits pour remplir l'étagère
    final displayProducts = products.take(6).toList();
    final totalStock = products.fold<int>(
      0,
      (sum, p) => sum + ((p['stock'] as num?)?.toInt() ?? 0),
    );

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── ENSEIGNE NÉON DU RAYON ──
            _NeonSign(
              aisleNumber: aisleNumber,
              dept: dept,
              productCount: products.length,
            ),
            const SizedBox(height: 10),

            // ── ÉTAGÈRE 3D ──
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF1F2937),
                    const Color(0xFF111827),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: dept.color.withOpacity(0.3),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: dept.color.withOpacity(0.15),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                  BoxShadow(
                    color: Colors.black.withOpacity(0.5),
                    blurRadius: 30,
                    offset: const Offset(0, 15),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header de l'étagère
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: dept.color.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: dept.color.withOpacity(0.3)),
                        ),
                        child: Icon(dept.icon, color: dept.color, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              dept.name,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: -0.2,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Text(
                                  '${products.length} produits',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.white54,
                                  ),
                                ),
                                if (totalStock > 0) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    width: 3,
                                    height: 3,
                                    decoration: const BoxDecoration(
                                      color: Colors.white24,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Stock: $totalStock',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Colors.white54,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: dept.color.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Explorer',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: dept.color,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.arrow_forward_rounded,
                              size: 12,
                              color: dept.color,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // ── ÉTAGÈRE 3D AVEC PRODUITS ──
                  Stack(
                    children: [
                      // Étagère avec perspective
                      _Shelf3D(
                        color: dept.color,
                        isFresh: isFresh,
                        isFrozen: isFrozen,
                        isBakery: isBakery,
                        isButcher: isButcher,
                        products: displayProducts,
                      ),

                      // Effets spéciaux par type de rayon
                      if (isFresh) const _FreshCondensationEffect(),
                      if (isFrozen) const _FrozenMistEffect(),
                      if (isBakery) const _WarmGlowEffect(),
                    ],
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
// ENSEIGNE NÉON LUMINEUSE
// ============================================================================
class _NeonSign extends StatelessWidget {
  final int aisleNumber;
  final SupermarketDepartment dept;
  final int productCount;

  const _NeonSign({
    required this.aisleNumber,
    required this.dept,
    required this.productCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: dept.color.withOpacity(0.5), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: dept.color.withOpacity(0.4),
            blurRadius: 12,
            spreadRadius: 1,
          ),
          BoxShadow(
            color: dept.color.withOpacity(0.2),
            blurRadius: 24,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: dept.color,
              borderRadius: BorderRadius.circular(6),
              boxShadow: [
                BoxShadow(
                  color: dept.color.withOpacity(0.8),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Text(
              'ALLÉE $aisleNumber',
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: 1,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            dept.name.toUpperCase(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: dept.color,
              letterSpacing: 0.5,
              shadows: [
                Shadow(color: dept.color.withOpacity(0.8), blurRadius: 8),
              ],
            ),
          ),
          if (productCount > 0) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '$productCount',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: Colors.white70,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ============================================================================
// ÉTAGÈRE 3D AVEC PERSPECTIVE
// ============================================================================
class _Shelf3D extends StatelessWidget {
  final Color color;
  final bool isFresh;
  final bool isFrozen;
  final bool isBakery;
  final bool isButcher;
  final List<Map<String, dynamic>> products;

  const _Shelf3D({
    required this.color,
    required this.isFresh,
    required this.isFrozen,
    required this.isBakery,
    required this.isButcher,
    required this.products,
  });

  @override
  Widget build(BuildContext context) {
    // Déterminer la couleur de fond selon le type de rayon
    final shelfBg = isFrozen
        ? const Color(0xFF0C1929)
        : isBakery
            ? const Color(0xFF2D1810)
            : isButcher
                ? const Color(0xFF1F0F0F)
                : isFresh
                    ? const Color(0xFF0F1F14)
                    : const Color(0xFF1A1A1A);

    // Lumière d'ambiance
    final ambientLight = isBakery
        ? const Color(0xFFFFD28A).withOpacity(0.15)
        : isButcher
            ? const Color(0xFFFF6B6B).withOpacity(0.1)
            : isFresh
                ? const Color(0xFF90EE90).withOpacity(0.1)
                : isFrozen
                    ? const Color(0xFFADD8E6).withOpacity(0.15)
                    : Colors.white.withOpacity(0.05);

    return Container(
      height: 140,
      decoration: BoxDecoration(
        color: shelfBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.2)),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            ambientLight,
            Colors.transparent,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 8,
            offset: const Offset(0, 4),
            spreadRadius: -2,
          ),
        ],
      ),
      child: Stack(
        children: [
          // Étagères horizontales (3 niveaux)
          CustomPaint(
            size: const Size(double.infinity, 140),
            painter: _ShelfLinesPainter(color: color.withOpacity(0.3)),
          ),

          // Produits sur les étagères
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                // Produits affichés (max 6 visibles)
                ...List.generate(
                  products.length.clamp(0, 6),
                  (i) => Expanded(
                    child: _ProductOnShelf(
                      product: products[i],
                      accentColor: color,
                      index: i,
                    ),
                  ),
                ),
                // Espace vide si moins de 6 produits
                ...List.generate(
                  (6 - products.length).clamp(0, 6),
                  (_) => const Expanded(child: SizedBox()),
                ),
              ],
            ),
          ),

          // Reflet brillant en haut
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 2,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    Colors.white.withOpacity(0.2),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShelfLinesPainter extends CustomPainter {
  final Color color;
  _ShelfLinesPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    // 3 étagères horizontales
    final y1 = size.height * 0.33;
    final y2 = size.height * 0.66;

    canvas.drawLine(Offset(0, y1), Offset(size.width, y1), paint);
    canvas.drawLine(Offset(0, y2), Offset(size.width, y2), paint);

    // Montants verticaux
    final vPaint = Paint()
      ..color = color.withOpacity(0.5)
      ..strokeWidth = 1;

    for (var x = 0.0; x <= size.width; x += size.width / 6) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), vPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ============================================================================
// PRODUIT SUR ÉTAGÈRE (avec stock visible)
// ============================================================================
class _ProductOnShelf extends StatelessWidget {
  final Map<String, dynamic> product;
  final Color accentColor;
  final int index;

  const _ProductOnShelf({
    required this.product,
    required this.accentColor,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    final imageUrl = product['image_url']?.toString();
    final stock = (product['stock'] as num?)?.toInt() ?? 0;
    final title = product['title']?.toString() ?? '';
    final price = (product['price'] as num?)?.toDouble() ?? 0;
    final discountPrice = (product['discount_price'] as num?)?.toDouble();

    // Nombre d'unités visibles (max 4 par produit)
    final visibleUnits = stock.clamp(0, 4);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // Stack de produits (représentation visuelle du stock)
          Expanded(
            child: Stack(
              alignment: Alignment.bottomCenter,
              children: [
                // Produits empilés (effet 3D)
                ...List.generate(visibleUnits, (i) {
                  final offset = i * 2.0;
                  final scale = 1.0 - (i * 0.03);
                  return Positioned(
                    left: offset,
                    right: offset,
                    bottom: offset,
                    child: Transform.scale(
                      scale: scale,
                      child: _ProductUnit(
                        imageUrl: imageUrl,
                        accentColor: accentColor,
                        depth: i,
                      ),
                    ),
                  );
                }),

                // Si aucun stock, afficher "RUPTURE"
                if (visibleUnits == 0)
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: ThixPolicy.danger.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: ThixPolicy.danger.withOpacity(0.5)),
                    ),
                    child: const Icon(
                      Icons.remove_shopping_cart_rounded,
                      size: 16,
                      color: ThixPolicy.danger,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          // Prix
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.6),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              discountPrice != null
                  ? '${discountPrice.toStringAsFixed(0)}'
                  : '${price.toStringAsFixed(0)}',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w900,
                color: discountPrice != null ? ThixPolicy.danger : Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductUnit extends StatelessWidget {
  final String? imageUrl;
  final Color accentColor;
  final int depth;

  const _ProductUnit({
    required this.imageUrl,
    required this.accentColor,
    required this.depth,
  });

  @override
  Widget build(BuildContext context) {
    final shadowOpacity = (0.3 - depth * 0.08).clamp(0.05, 0.3);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: accentColor.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(shadowOpacity),
            blurRadius: 4 - depth,
            offset: Offset(0, 2 - depth * 0.5),
          ),
        ],
      ),
      child: imageUrl != null && imageUrl!.isNotEmpty
          ? ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: CachedNetworkImage(
                imageUrl: imageUrl!,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => Icon(
                  Icons.inventory_2_rounded,
                  color: accentColor,
                  size: 18,
                ),
              ),
            )
          : Icon(
              Icons.inventory_2_rounded,
              color: accentColor,
              size: 18,
            ),
    );
  }
}

// ============================================================================
// EFFETS VISUELS SPÉCIAUX
// ============================================================================

// Condensation pour rayon frais
class _FreshCondensationEffect extends StatelessWidget {
  const _FreshCondensationEffect();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: CustomPaint(painter: _CondensationPainter()),
      ),
    );
  }
}

class _CondensationPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(42); // Seed fixe pour stabilité
    final paint = Paint()..color = Colors.white.withOpacity(0.15);

    // Gouttelettes de condensation
    for (var i = 0; i < 30; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height * 0.3;
      final radius = 1.0 + random.nextDouble() * 2.0;
      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Brume pour surgelés
class _FrozenMistEffect extends StatelessWidget {
  const _FrozenMistEffect();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.white.withOpacity(0.12),
                Colors.transparent,
              ],
            ),
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}

// Lueur chaude pour boulangerie
class _WarmGlowEffect extends StatelessWidget {
  const _WarmGlowEffect();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.topCenter,
              radius: 1.2,
              colors: [
                const Color(0xFFFFD28A).withOpacity(0.15),
                Colors.transparent,
              ],
            ),
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// BOUTON PANIER FLOTTANT
// ============================================================================
class _FloatingCartButton extends StatelessWidget {
  final AppLocalizations l10n;
  const _FloatingCartButton({required this.l10n});

  String _tr(String key, String fb) {
    final v = l10n.t(key);
    return (v.isEmpty || v == key) ? fb : v;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/market/cart'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [ThixPolicy.primary, Color(0xFF1E40AF)],
          ),
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: ThixPolicy.primary.withOpacity(0.5),
              blurRadius: 20,
              spreadRadius: 2,
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.shopping_cart_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              _tr('sm_cart', 'Panier'),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
