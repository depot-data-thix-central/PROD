// lib/presentation/thix_market/pages/supermarket_space_page.dart
// ============================================================================
// SUPERMARCHÉ — ÉTAGÈRES GONDOLES RÉALISTES (fond clair, enterprise)
// ============================================================================
import 'dart:async';

import 'package:barcode_widget/barcode_widget.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/l10n/app_localizations.dart';
import 'package:thix_id/presentation/thix_market/models/supermarket_models.dart';
import 'package:thix_id/presentation/thix_market/providers/supermarket_providers.dart';
import 'department_products_page.dart';

// Couleurs gondole (référentiel magasin réel)
const Color _kRailRed = Color(0xFFD93025);
const Color _kRailRedDark = Color(0xFFB3261E);
const Color _kMetalWhite = Color(0xFFFAFAFA);
const Color _kMetalEdge = Color(0xFFE3E6EA);
const Color _kMeshWire = Color(0xFFC9CED6);
const Color _kPerfDot = Color(0xFFDDE1E6);

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
    final productsAsync = ref.watch(supermarketShelfProductsProvider(supermarketId));

    return Scaffold(
      backgroundColor: ThixPolicy.surfaceSoft,
      body: shopAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (shop) {
          if (shop == null) return const Center(child: Text('Supermarché introuvable'));
          final depts = deptsAsync.valueOrNull ?? const <SupermarketDepartment>[];
          final products = productsAsync.valueOrNull ?? const <SupermarketProduct>[];

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              _LightStorefront(shop: shop, l10n: l10n),

              // ── HERO BANNER AUTO-SCROLLING ──
              SliverToBoxAdapter(
                child: _HeroCarousel(
                  products: products,
                  l10n: l10n,
                  onProductTap: (p) => _openQuickView(context, p, l10n),
                ),
              ),

              // ── TITRE RAYONS ──
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 10),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: ThixPolicy.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.storefront_rounded, size: 18, color: ThixPolicy.primary),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _tr(l10n, 'sm_aisles_title', 'Nos rayons'),
                              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: ThixPolicy.textMain, letterSpacing: -0.3),
                            ),
                            Text(
                              _tr(l10n, 'sm_aisles_subtitle', 'Étagères en temps réel avec stock'),
                              style: const TextStyle(fontSize: 11, color: ThixPolicy.textMuted),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── ÉTAGÈRES GONDOLES ──
              if (depts.isEmpty && productsAsync.isLoading)
                const SliverToBoxAdapter(
                  child: Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator())),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (ctx, i) {
                        final dept = depts[i];
                        final deptProducts = products.where((p) => p.departmentId == dept.id).toList();
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 22),
                          child: _GondolaShelf(
                            dept: dept,
                            aisleNumber: i + 1,
                            products: deptProducts,
                            l10n: l10n,
                            onProductTap: (p) => _openQuickView(context, p, l10n),
                            onOpenAisle: () {
                              HapticFeedback.selectionClick();
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
                        );
                      },
                      childCount: depts.length,
                    ),
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 110)),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/market/cart'),
        backgroundColor: ThixPolicy.primary,
        foregroundColor: Colors.white,
        elevation: 4,
        icon: const Icon(Icons.shopping_cart_rounded, size: 20),
        label: Text(_tr(l10n, 'sm_cart', 'Panier')),
      ),
    );
  }

  void _openQuickView(BuildContext context, SupermarketProduct p, AppLocalizations l10n) {
    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ProductQuickView(product: p, l10n: l10n),
    );
  }
}

// ============================================================================
// DEVANTURE CLAIRE
// ============================================================================
class _LightStorefront extends StatelessWidget {
  final Map<String, dynamic> shop;
  final AppLocalizations l10n;
  const _LightStorefront({required this.shop, required this.l10n});

  @override
  Widget build(BuildContext context) {
    final cover = shop['cover_url']?.toString();
    final logo = shop['logo_url']?.toString();
    final name = shop['name']?.toString() ?? '';
    final city = shop['city']?.toString() ?? '';
    final rating = (shop['rating'] as num?)?.toDouble() ?? 0;
    final isOpen = (shop['is_open'] as bool?) ?? true;

    return SliverAppBar(
      expandedHeight: 210,
      pinned: true,
      backgroundColor: Colors.white,
      foregroundColor: ThixPolicy.textMain,
      elevation: 0,
      leading: Padding(
        padding: const EdgeInsets.all(8),
        child: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: ThixPolicy.shadowSoft()),
            child: const Icon(Icons.arrow_back_ios_new_rounded, color: ThixPolicy.textMain, size: 16),
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
                  gradient: LinearGradient(colors: [Color(0xFFE8F0FE), Color(0xFFF6F7FB)]),
                ),
              ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.white.withOpacity(0.6), ThixPolicy.surfaceSoft],
                  stops: const [0.35, 0.75, 1],
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
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                      boxShadow: ThixPolicy.shadowSoft(),
                    ),
                    child: logo != null && logo.isNotEmpty
                        ? ClipOval(child: CachedNetworkImage(imageUrl: logo, fit: BoxFit.cover))
                        : const Icon(Icons.storefront_rounded, color: ThixPolicy.primary, size: 24),
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
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: ThixPolicy.textMain)),
                        const SizedBox(height: 3),
                        Row(children: [
                          if (isOpen)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(color: ThixPolicy.success.withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
                              child: const Text('OUVERT', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: ThixPolicy.success, letterSpacing: 0.6)),
                            ),
                          const SizedBox(width: 6),
                          const Icon(Icons.place_rounded, size: 11, color: ThixPolicy.textMuted),
                          const SizedBox(width: 3),
                          Expanded(child: Text(city, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: ThixPolicy.textSecondary))),
                          if (rating > 0) ...[
                            const Icon(Icons.star_rounded, size: 12, color: ThixPolicy.gold),
                            const SizedBox(width: 2),
                            Text(rating.toStringAsFixed(1), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: ThixPolicy.gold)),
                          ],
                        ]),
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
// HERO BANNER AUTO-SCROLLING (promos / vedettes / frais)
// ============================================================================
class _HeroItem {
  final String badge;
  final String title;
  final String subtitle;
  final String cta;
  final List<Color> gradient;
  final IconData icon;
  final SupermarketProduct? product;
  final VoidCallback? onTap;

  _HeroItem({
    required this.badge,
    required this.title,
    required this.subtitle,
    required this.cta,
    required this.gradient,
    required this.icon,
    this.product,
    this.onTap,
  });
}

class _HeroCarousel extends StatefulWidget {
  final List<SupermarketProduct> products;
  final AppLocalizations l10n;
  final ValueChanged<SupermarketProduct> onProductTap;
  const _HeroCarousel({required this.products, required this.l10n, required this.onProductTap});

  @override
  State<_HeroCarousel> createState() => _HeroCarouselState();
}

class _HeroCarouselState extends State<_HeroCarousel> {
  final PageController _ctrl = PageController();
  Timer? _timer;
  int _index = 0;
  List<_HeroItem> _items = const [];

  @override
  void initState() {
    super.initState();
    _buildItems();
    _startTimer();
  }

  @override
  void didUpdateWidget(covariant _HeroCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.products != widget.products) _buildItems();
  }

  void _buildItems() {
    final l10n = widget.l10n;
    final items = <_HeroItem>[];
    final promos = widget.products.where((p) => p.onPromo).toList();
    final featured = widget.products.where((p) => p.isFeatured || p.rating >= 4.5).toList();
    final fresh = widget.products.where((p) => p.isPerishable && !p.isExpired).toList();

    for (final p in promos.take(3)) {
      items.add(_HeroItem(
        badge: 'PROMO -${p.promoPercent}%',
        title: p.title,
        subtitle: '${p.priceLabel(p.price)} ${p.currency} → ${p.priceLabel()} ${p.currency}',
        cta: 'J\'en profite',
        gradient: const [Color(0xFFFFF1F0), Color(0xFFFFE4E1)],
        icon: Icons.local_fire_department_rounded,
        product: p,
        onTap: () => widget.onProductTap(p),
      ));
    }
    for (final p in featured.take(2)) {
      items.add(_HeroItem(
        badge: 'VEDETTE',
        title: p.title,
        subtitle: '${p.priceLabel()} ${p.currency} • ★ ${p.rating.toStringAsFixed(1)}',
        cta: 'Découvrir',
        gradient: const [Color(0xFFE8F0FE), Color(0xFFDCE7FB)],
        icon: Icons.star_rounded,
        product: p,
        onTap: () => widget.onProductTap(p),
      ));
    }
    for (final p in fresh.take(2)) {
      items.add(_HeroItem(
        badge: 'FRAÎCHEUR',
        title: p.title,
        subtitle: p.expiryDate != null ? 'À consommer avant le ${_fmtDate(p.expiryDate!)}' : 'Produit frais du jour',
        cta: 'Voir',
        gradient: const [Color(0xFFE9F7EC), Color(0xFFDFF2E3)],
        icon: Icons.eco_rounded,
        product: p,
        onTap: () => widget.onProductTap(p),
      ));
    }
    if (items.isEmpty) {
      items.add(_HeroItem(
        badge: 'BIENVENUE',
        title: 'Votre supermarché en ligne',
        subtitle: 'Parcourez nos rayons comme en magasin',
        cta: 'Explorer',
        gradient: const [Color(0xFFE8F0FE), Color(0xFFF6F7FB)],
        icon: Icons.storefront_rounded,
      ));
    }
    setState(() => _items = items);
  }

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || _items.isEmpty || !_ctrl.hasClients) return;
      final next = (_index + 1) % _items.length;
      _ctrl.animateToPage(next, duration: const Duration(milliseconds: 450), curve: Curves.easeInOut);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_items.isEmpty) return const SizedBox.shrink();
    return Column(
      children: [
        SizedBox(
          height: 150,
          child: PageView.builder(
            controller: _ctrl,
            itemCount: _items.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (_, i) {
              final item = _items[i];
              return GestureDetector(
                onTap: item.onTap,
                child: Container(
                  margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: item.gradient),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.white),
                    boxShadow: ThixPolicy.shadowSoft(opacity: 0.08),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(color: item.gradient.last.withOpacity(0.9), borderRadius: BorderRadius.circular(6)),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(item.icon, size: 11, color: ThixPolicy.textMain),
                                    const SizedBox(width: 4),
                                    Text(item.badge, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: ThixPolicy.textMain, letterSpacing: 0.6)),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: ThixPolicy.textMain, height: 1.2)),
                              const SizedBox(height: 4),
                              Text(item.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: ThixPolicy.textSecondary)),
                              const SizedBox(height: 8),
                              Text(item.cta, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: ThixPolicy.primary)),
                            ],
                          ),
                        ),
                      ),
                      if (item.product != null && item.product!.hasPhotos)
                        Padding(
                          padding: const EdgeInsets.only(right: 16),
                          child: Container(
                            width: 96,
                            height: 96,
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), boxShadow: ThixPolicy.shadowSoft(opacity: 0.12)),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: CachedNetworkImage(
                                imageUrl: item.product!.mainPhoto,
                                fit: BoxFit.cover,
                                errorWidget: (_, __, ___) => Icon(item.icon, color: ThixPolicy.textMuted),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(_items.length, (i) {
            final active = i == _index;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: active ? 18 : 6,
              height: 6,
              decoration: BoxDecoration(color: active ? ThixPolicy.primary : ThixPolicy.border, borderRadius: BorderRadius.circular(3)),
            );
          }),
        ),
      ],
    );
  }
}

// ============================================================================
// ÉTAGÈRE GONDOLE RÉALISTE (blanc + rails rouges + fond perforé)
// ============================================================================
class _GondolaShelf extends StatelessWidget {
  final SupermarketDepartment dept;
  final int aisleNumber;
  final List<SupermarketProduct> products;
  final AppLocalizations l10n;
  final ValueChanged<SupermarketProduct> onProductTap;
  final VoidCallback onOpenAisle;

  static const int _cols = 4;
  static const int _levels = 4;

  const _GondolaShelf({
    required this.dept,
    required this.aisleNumber,
    required this.products,
    required this.l10n,
    required this.onProductTap,
    required this.onOpenAisle,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onOpenAisle,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _kMetalEdge),
          boxShadow: ThixPolicy.shadowSoft(opacity: 0.07),
        ),
        child: Column(
          children: [
            _GondolaHeader(dept: dept, aisleNumber: aisleNumber, count: products.length),
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 0, 6, 6),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _SideMesh(width: 12),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: _kMetalWhite,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: _kMetalEdge),
                        ),
                        child: Stack(
                          children: [
                            Positioned.fill(child: CustomPaint(painter: _PerforatedPainter())),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: List.generate(_levels, (lvl) {
                                return _ShelfLevel(
                                  slots: _levelProducts(lvl),
                                  onProductTap: onProductTap,
                                );
                              }),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const _SideMesh(width: 12),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(width: 14, height: 8, decoration: BoxDecoration(color: _kMeshWire, borderRadius: BorderRadius.circular(2))),
                  Container(width: 14, height: 8, decoration: BoxDecoration(color: _kMeshWire, borderRadius: BorderRadius.circular(2))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<SupermarketProduct?> _levelProducts(int lvl) {
    final slots = <SupermarketProduct?>[];
    for (var c = 0; c < _cols; c++) {
      final idx = lvl * _cols + c;
      slots.add(idx < products.length ? products[idx] : null);
    }
    return slots;
  }
}

class _GondolaHeader extends StatelessWidget {
  final SupermarketDepartment dept;
  final int aisleNumber;
  final int count;
  const _GondolaHeader({required this.dept, required this.aisleNumber, required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(color: dept.color, borderRadius: BorderRadius.circular(6)),
            child: Text('ALLÉE $aisleNumber', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 0.8)),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(color: dept.color.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
            child: Icon(dept.icon, size: 16, color: dept.color),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(dept.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: ThixPolicy.textMain)),
          ),
          Text('$count', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: dept.color)),
          const Icon(Icons.chevron_right_rounded, size: 16, color: ThixPolicy.textMuted),
        ],
      ),
    );
  }
}

class _SideMesh extends StatelessWidget {
  final double width;
  const _SideMesh({required this.width});

  @override
  Widget build(BuildContext context) {
    return SizedBox(width: width, child: CustomPaint(painter: _MeshPainter()));
  }
}

class _MeshPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _kMeshWire
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    for (var y = 0.0; y <= size.height; y += 7) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
    for (var x = 0.0; x <= size.width; x += 6) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _PerforatedPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = _kPerfDot;
    for (var y = 6.0; y < size.height; y += 9) {
      for (var x = 6.0; x < size.width; x += 9) {
        canvas.drawCircle(Offset(x, y), 1.0, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ============================================================================
// NIVEAU D'ÉTAGÈRE : produits + tablette + rail rouge + étiquettes
// ============================================================================
class _ShelfLevel extends StatelessWidget {
  final List<SupermarketProduct?> slots;
  final ValueChanged<SupermarketProduct> onProductTap;

  const _ShelfLevel({required this.slots, required this.onProductTap});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 86,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: slots
                .map<Widget>((p) => Expanded(
                      child: p == null ? const SizedBox.shrink() : _Facing(product: p, onTap: () => onProductTap(p)),
                    ))
                .toList(),
          ),
        ),
        _ShelfBoard(slots: slots),
      ],
    );
  }
}

class _ShelfBoard extends StatelessWidget {
  final List<SupermarketProduct?> slots;
  const _ShelfBoard({required this.slots});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 24,
      child: Stack(
        children: [
          Positioned(
            top: 0,
            left: 2,
            right: 2,
            height: 9,
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.white, Color(0xFFEDEFF2)]),
                borderRadius: BorderRadius.circular(2),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.10), blurRadius: 3, offset: const Offset(0, 2))],
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: 15,
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [_kRailRed, _kRailRedDark]),
                borderRadius: BorderRadius.circular(3),
                boxShadow: [BoxShadow(color: _kRailRed.withOpacity(0.25), blurRadius: 4, offset: const Offset(0, 2))],
              ),
            ),
          ),
          Positioned(
            bottom: 2,
            left: 0,
            right: 0,
            height: 11,
            child: Row(
              children: slots
                  .map<Widget>((p) => Expanded(child: p == null ? const SizedBox.shrink() : Center(child: _PriceTag(product: p))))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _PriceTag extends StatelessWidget {
  final SupermarketProduct product;
  const _PriceTag({required this.product});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(2)),
      child: Text(
        '${product.priceLabel()} ${product.currency}',
        style: TextStyle(fontSize: 7.5, fontWeight: FontWeight.w900, color: product.onPromo ? _kRailRed : ThixPolicy.textMain),
      ),
    );
  }
}

// ============================================================================
// FACING PRODUIT (photo réelle + badges + répétition selon stock)
// ============================================================================
class _Facing extends StatelessWidget {
  final SupermarketProduct product;
  final VoidCallback onTap;
  const _Facing({required this.product, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final facings = product.stock <= 0 ? 0 : product.stock.clamp(1, 3);

    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            if (facings > 0)
              Align(
                alignment: Alignment.bottomCenter,
                child: SizedBox(
                  height: 74,
                  child: Stack(
                    children: List.generate(facings, (i) {
                      final behind = i > 0;
                      return Positioned(
                        left: i * 5.0,
                        right: (facings - 1 - i) * 2.0,
                        bottom: 0,
                        top: behind ? 3.0 : 0,
                        child: Opacity(
                          opacity: behind ? 0.55 : 1.0,
                          child: _ProductBox(product: product, muted: behind),
                        ),
                      );
                    }),
                  ),
                ),
              )
            else
              Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  height: 40,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.grey.withOpacity(0.15)),
                  ),
                  child: const Center(child: Text('RUPTURE', style: TextStyle(fontSize: 7, fontWeight: FontWeight.w900, color: Colors.grey))),
                ),
              ),
            if (product.onPromo)
              Positioned(
                top: -4,
                left: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(color: _kRailRed, borderRadius: BorderRadius.circular(4)),
                  child: Text('-${product.promoPercent}%', style: const TextStyle(fontSize: 7.5, fontWeight: FontWeight.w900, color: Colors.white)),
                ),
              ),
            if (product.isPerishable)
              Positioned(
                top: -4,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(
                    color: product.isExpired ? Colors.grey : (product.isFreshSoon ? Colors.orange : ThixPolicy.success),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    product.isExpired ? 'EXPIRÉ' : (product.isFreshSoon ? 'J-${product.daysToExpiry}' : 'FRAIS'),
                    style: const TextStyle(fontSize: 7, fontWeight: FontWeight.w900, color: Colors.white),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ProductBox extends StatelessWidget {
  final SupermarketProduct product;
  final bool muted;
  const _ProductBox({required this.product, this.muted = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: _kMetalEdge),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(muted ? 0.05 : 0.12), blurRadius: 3, offset: const Offset(0, 2))],
      ),
      child: product.hasPhotos
          ? ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: CachedNetworkImage(
                imageUrl: product.mainPhoto,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => const Icon(Icons.inventory_2_rounded, size: 18, color: ThixPolicy.textMuted),
              ),
            )
          : const Center(child: Icon(Icons.inventory_2_rounded, size: 18, color: ThixPolicy.textMuted)),
    );
  }
}

// ============================================================================
// FICHE PRODUIT RAPIDE (bottom sheet)
// ============================================================================
class _ProductQuickView extends StatelessWidget {
  final SupermarketProduct product;
  final AppLocalizations l10n;
  const _ProductQuickView({required this.product, required this.l10n});

  String _tr(String key, String fb) {
    final v = l10n.t(key);
    return (v.isEmpty || v == key) ? fb : v;
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.82,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollCtrl) => Container(
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        child: ListView(
          controller: scrollCtrl,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: ThixPolicy.border, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            _PhotoGallery(photos: product.photos),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: Text(product.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: ThixPolicy.textMain))),
                if (product.onPromo)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: _kRailRed, borderRadius: BorderRadius.circular(8)),
                    child: Text('-${product.promoPercent}%', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.white)),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text('${product.priceLabel()} ${product.currency}', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: product.onPromo ? _kRailRed : ThixPolicy.primary)),
                if (product.onPromo) ...[
                  const SizedBox(width: 8),
                  Text('${product.priceLabel(product.price)} ${product.currency}', style: const TextStyle(fontSize: 13, color: ThixPolicy.textMuted, decoration: TextDecoration.lineThrough)),
                ],
                if (product.unit != null) ...[
                  const SizedBox(width: 8),
                  Text('/ ${product.unit}', style: const TextStyle(fontSize: 12, color: ThixPolicy.textMuted)),
                ],
              ],
            ),
            const SizedBox(height: 14),
            _InfoGrid(product: product),
            const SizedBox(height: 16),
            if (product.barcode != null && product.barcode!.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: ThixPolicy.surfaceSoft, borderRadius: BorderRadius.circular(14)),
                child: Column(
                  children: [
                    BarcodeWidget(barcode: Barcode.code128(), data: product.barcode!, height: 48, drawText: false, color: ThixPolicy.textMain),
                    const SizedBox(height: 6),
                    Text(product.barcode!, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 2, color: ThixPolicy.textSecondary)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            if (product.description != null && product.description!.isNotEmpty) ...[
              Text(_tr('sm_description', 'Description'), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: ThixPolicy.textMain)),
              const SizedBox(height: 6),
              Text(product.description!, style: const TextStyle(fontSize: 13, color: ThixPolicy.textSecondary, height: 1.5)),
              const SizedBox(height: 20),
            ],
            SizedBox(
              height: 50,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  context.push('/market/product/${product.id}');
                },
                icon: const Icon(Icons.open_in_full_rounded, size: 18),
                label: Text(_tr('sm_full_sheet', 'Voir la fiche complète')),
                style: ElevatedButton.styleFrom(backgroundColor: ThixPolicy.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhotoGallery extends StatefulWidget {
  final List<String> photos;
  const _PhotoGallery({required this.photos});

  @override
  State<_PhotoGallery> createState() => _PhotoGalleryState();
}

class _PhotoGalleryState extends State<_PhotoGallery> {
  final PageController _ctrl = PageController();
  int _i = 0;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.photos.isEmpty) {
      return Container(
        height: 220,
        decoration: BoxDecoration(color: ThixPolicy.surfaceSoft, borderRadius: BorderRadius.circular(16)),
        child: const Center(child: Icon(Icons.image_not_supported_outlined, size: 40, color: ThixPolicy.textMuted)),
      );
    }
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            height: 220,
            child: PageView.builder(
              controller: _ctrl,
              itemCount: widget.photos.length,
              onPageChanged: (i) => setState(() => _i = i),
              itemBuilder: (_, i) => CachedNetworkImage(
                imageUrl: widget.photos[i],
                fit: BoxFit.cover,
                width: double.infinity,
                placeholder: (_, __) => const Center(child: CircularProgressIndicator()),
                errorWidget: (_, __, ___) => const Center(child: Icon(Icons.broken_image_rounded, color: ThixPolicy.textMuted)),
              ),
            ),
          ),
        ),
        if (widget.photos.length > 1) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(widget.photos.length, (i) {
              final active = i == _i;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: active ? 16 : 6,
                height: 6,
                decoration: BoxDecoration(color: active ? ThixPolicy.primary : ThixPolicy.border, borderRadius: BorderRadius.circular(3)),
              );
            }),
          ),
        ],
      ],
    );
  }
}

class _InfoGrid extends StatelessWidget {
  final SupermarketProduct product;
  const _InfoGrid({required this.product});

  @override
  Widget build(BuildContext context) {
    final cells = <Widget>[
      _InfoCell(
        icon: Icons.inventory_2_rounded,
        label: 'Stock',
        value: '${product.stock}${product.unit != null ? ' ${product.unit}' : ''}',
        color: product.stock > 0 ? ThixPolicy.success : ThixPolicy.danger,
      ),
      _InfoCell(icon: Icons.category_outlined, label: 'Unité', value: product.unit ?? 'pcs', color: ThixPolicy.primary),
      if (product.isPerishable)
        _InfoCell(
          icon: product.isExpired ? Icons.warning_amber_rounded : Icons.event_rounded,
          label: 'Expiration',
          value: product.expiryDate != null
              ? '${product.expiryDate!.day.toString().padLeft(2, '0')}/${product.expiryDate!.month.toString().padLeft(2, '0')}/${product.expiryDate!.year}'
              : '—',
          color: product.isExpired ? ThixPolicy.danger : (product.isFreshSoon ? Colors.orange : ThixPolicy.success),
        ),
      if (product.onPromo)
        _InfoCell(icon: Icons.local_offer_rounded, label: 'Prix promo', value: '${product.priceLabel()} ${product.currency}', color: _kRailRed),
    ];

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: cells.map((c) => SizedBox(width: (MediaQuery.of(context).size.width - 60) / 2, child: c)).toList(),
    );
  }
}

class _InfoCell extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _InfoCell({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: ThixPolicy.surfaceSoft, borderRadius: BorderRadius.circular(12), border: Border.all(color: ThixPolicy.border)),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 10, color: ThixPolicy.textMuted, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: color)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
