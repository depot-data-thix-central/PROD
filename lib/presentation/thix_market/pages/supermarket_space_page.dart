// lib/presentation/thix_market/pages/supermarket_space_page.dart
// ============================================================================
// SUPERMARCHÉ 3D — v7 "Premium"
// Fichier 1/2 : page, logique, hero banner, header, HUD, entrée, résultats
// Fichier 2/2 : supermarket_space_widgets.dart (monde 3D : allées, rayons,
//               frigos, produits, fiche produit, tokens)
// ============================================================================

import 'dart:async';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:thix_id/l10n/app_localizations.dart';
import 'package:thix_id/presentation/thix_market/cart/cart_provider.dart' show cartProvider;
import 'package:thix_id/presentation/thix_market/models/supermarket_models.dart';
import 'package:thix_id/presentation/thix_market/providers/market_providers.dart' show supabaseClientProvider;
import 'package:thix_id/presentation/thix_market/providers/supermarket_providers.dart';

import 'department_products_page.dart';
import 'supermarket_space_widgets.dart';

// Compatibilité : les anciens tokens restent accessibles via cette page.
export 'supermarket_space_widgets.dart'
    show kBg, kSurface, kInk, kInkSoft, kInkMuted, kBorder, kAccent, kAccentDark, kAccentSoft, kDanger, kSuccess, kGold;

// ============================================================================
// PAGE PRINCIPALE
// ============================================================================
class SupermarketSpacePage extends ConsumerStatefulWidget {
  final String supermarketId;
  const SupermarketSpacePage({super.key, required this.supermarketId});

  @override
  ConsumerState<SupermarketSpacePage> createState() => _SupermarketSpacePageState();
}

class _SupermarketSpacePageState extends ConsumerState<SupermarketSpacePage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entry =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 2200));
  bool _entryStarted = false;

  PageController _pageCtrl = PageController(viewportFraction: kSmViewport);
  int _floor = 0;
  bool _hidden = false;
  bool _changing = false;
  double _slideDir = 1;
  bool _heroVisible = true;

  final ValueNotifier<int> _aisle = ValueNotifier<int>(0);
  final ValueNotifier<String?> _highlight = ValueNotifier<String?>(null);
  final ValueNotifier<int> _cartCount = ValueNotifier<int>(0);
  final ValueNotifier<Set<String>> _added = ValueNotifier<Set<String>>(<String>{});
  final Set<String> _busy = <String>{};

  Timer? _hlTimer;
  Timer? _debounce;
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _focus = FocusNode();
  String _query = '';
  bool _promoMode = false;

  List<SupermarketDepartment> _depts = const <SupermarketDepartment>[];
  List<SupermarketProduct> _all = const <SupermarketProduct>[];
  final Map<String, String> _foldCache = <String, String>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadCartCount());
  }

  @override
  void dispose() {
    _entry.dispose();
    _pageCtrl.dispose();
    _aisle.dispose();
    _highlight.dispose();
    _cartCount.dispose();
    _added.dispose();
    _hlTimer?.cancel();
    _debounce?.cancel();
    _searchCtrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  // --------------------------------------------------------------------------
  // FEEDBACK
  // --------------------------------------------------------------------------
  void _toast(String msg, {bool error = false, bool cart = false}) {
    if (!mounted) return;
    final m = ScaffoldMessenger.of(context);
    m.hideCurrentSnackBar();
    m.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 92),
        backgroundColor: error ? kDanger : kInk,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        duration: const Duration(seconds: 3),
        content: Row(children: [
          Icon(error ? Icons.error_outline_rounded : Icons.check_circle_rounded,
              color: error ? Colors.white : kAccent, size: 17),
          const SizedBox(width: 8),
          Expanded(
            child: Text(msg,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
          ),
        ]),
        action: cart
            ? SnackBarAction(label: 'Voir', textColor: kAccent, onPressed: () => context.push('/market/cart'))
            : null,
      ),
    );
  }

  void _setHighlight(String id) {
    _hlTimer?.cancel();
    _highlight.value = id;
    _hlTimer = Timer(const Duration(seconds: 6), () => _highlight.value = null);
  }

  void _markAdded(String id) {
    _added.value = <String>{..._added.value, id};
    Future.delayed(const Duration(milliseconds: 1400), () {
      if (!mounted) return;
      final s = <String>{..._added.value}..remove(id);
      _added.value = s;
    });
  }

  // --------------------------------------------------------------------------
  // PANIER (Supabase)
  // --------------------------------------------------------------------------
  Future<void> _loadCartCount() async {
    try {
      final db = ref.read(supabaseClientProvider);
      final uid = db.auth.currentUser?.id;
      if (uid == null) return;
      final res = await db.from('cart').select('quantity').eq('user_id', uid).timeout(kSmDbTimeout);
      var n = 0;
      for (final row in (res as List)) {
        n += ((row as Map)['quantity'] as num?)?.toInt() ?? 0;
      }
      if (mounted) _cartCount.value = n;
    } catch (e) {
      debugPrint('[SupermarketSpace] cart count error: $e');
    }
  }

  Future<void> _addToCart(SupermarketProduct p, {int qty = 1}) async {
    final pid = smPid(p);
    if (_busy.contains(pid)) return;

    final stock = smStockOf(p);
    if (stock <= 0) {
      _toast('Rupture de stock', error: true);
      return;
    }

    final db = ref.read(supabaseClientProvider);
    final uid = db.auth.currentUser?.id;
    if (uid == null) {
      _toast('Veuillez vous connecter', error: true);
      return;
    }

    _busy.add(pid);
    HapticFeedback.mediumImpact();
    try {
      final existing = await db
          .from('cart')
          .select()
          .match({'user_id': uid, 'product_id': pid})
          .maybeSingle()
          .timeout(kSmDbTimeout);

      if (existing != null) {
        final cur = (existing['quantity'] as num?)?.toInt() ?? 0;
        if (cur + qty > stock) {
          _toast('Stock limité à $stock (déjà $cur)', error: true);
          return;
        }
        await db.from('cart').update({'quantity': cur + qty}).eq('id', existing['id']).timeout(kSmDbTimeout);
      } else {
        await db
            .from('cart')
            .insert({'user_id': uid, 'product_id': pid, 'quantity': qty})
            .timeout(kSmDbTimeout);
      }

      ref.invalidate(cartProvider);
      _cartCount.value += qty;
      _markAdded(pid);
      _toast('${p.title} ajouté', cart: true);
    } catch (e) {
      debugPrint('[SupermarketSpace] addToCart error: $e');
      _toast('Erreur ajout', error: true);
    } finally {
      _busy.remove(pid);
    }
  }

  // --------------------------------------------------------------------------
  // NAVIGATION 3D
  // --------------------------------------------------------------------------
  PageController _newCtrl(int initial) => PageController(viewportFraction: kSmViewport, initialPage: initial);

  Future<void> _changeFloor(int target, {int aisle = 0}) async {
    if (_changing) return;
    if (target == _floor) {
      if (_pageCtrl.hasClients) {
        await _pageCtrl.animateToPage(aisle,
            duration: const Duration(milliseconds: 600), curve: Curves.easeInOutCubic);
      }
      return;
    }
    _changing = true;
    final goingUp = target > _floor;
    HapticFeedback.mediumImpact();
    setState(() {
      _hidden = true;
      _slideDir = goingUp ? 1 : -1;
    });
    await Future.delayed(const Duration(milliseconds: 230));
    if (!mounted) return;
    final old = _pageCtrl;
    setState(() {
      _floor = target;
      _pageCtrl = _newCtrl(aisle);
      _aisle.value = aisle;
      _hidden = false;
      _heroVisible = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
    _changing = false;
  }

  Future<void> _goToIndex(int deptIdx) async {
    if (deptIdx < 0 || deptIdx >= _depts.length) return;
    await _changeFloor(deptIdx ~/ kSmFloorSize, aisle: deptIdx % kSmFloorSize);
  }

  Future<void> _goToProduct(SupermarketProduct p) async {
    FocusScope.of(context).unfocus();
    final idx = _depts.indexWhere((d) => d.id == p.departmentId);
    if (idx < 0) {
      _openQuickView(p);
      return;
    }
    setState(() {
      _query = '';
      _promoMode = false;
      _searchCtrl.clear();
    });
    _setHighlight(smPid(p));
    await _goToIndex(idx);
  }

  void _openQuickView(SupermarketProduct p) {
    HapticFeedback.selectionClick();
    final l10n = AppLocalizations.of(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SmProductQuickView(
        product: p,
        l10n: l10n,
        onAdd: (qty) => _addToCart(p, qty: qty),
      ),
    );
  }

  // --------------------------------------------------------------------------
  // FICHE MAGASIN
  // --------------------------------------------------------------------------
  void _showShopInfo(Map<String, dynamic> shop) {
    HapticFeedback.selectionClick();
    final name = shop['name']?.toString() ?? '';
    final city = shop['city']?.toString() ?? '';
    final address = shop['address']?.toString() ?? '';
    final phone = shop['phone']?.toString() ?? '';
    final desc = shop['description']?.toString() ?? '';
    final logo = shop['logo_url']?.toString();
    final rating = (shop['rating'] as num?)?.toDouble() ?? 0;
    final isOpen = (shop['is_open'] as bool?) ?? true;
    final floors = math.max(1, (_depts.length / kSmFloorSize).ceil());

    Widget line(IconData icon, String text) => Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(color: kAccentSoft, borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, size: 15, color: kAccentDark),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(text,
                      style: const TextStyle(fontSize: 12.5, height: 1.35, fontWeight: FontWeight.w600, color: kInkSoft)),
                ),
              ),
            ],
          ),
        );

    Widget stat(String value, String label) => Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 11),
            decoration: BoxDecoration(
              color: kSurface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: kBorder),
            ),
            child: Column(
              children: [
                Text(value, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: kAccent)),
                const SizedBox(height: 2),
                Text(label, style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: kInkMuted)),
              ],
            ),
          ),
        );

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(color: kBorder, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        color: kSurface,
                        shape: BoxShape.circle,
                        border: Border.all(color: kAccent.withOpacity(0.4), width: 2),
                      ),
                      child: ClipOval(
                        child: (logo != null && logo.isNotEmpty)
                            ? CachedNetworkImage(
                                imageUrl: logo,
                                fit: BoxFit.cover,
                                memCacheWidth: smMemW(160),
                                errorWidget: (_, __, ___) => const Icon(Icons.storefront_rounded, color: kAccent),
                              )
                            : const Icon(Icons.storefront_rounded, color: kAccent, size: 26),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: kInk)),
                          const SizedBox(height: 5),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: (isOpen ? kSuccess : kDanger).withOpacity(0.14),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(isOpen ? 'OUVERT' : 'FERMÉ',
                                    style: TextStyle(
                                        fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.5, color: isOpen ? kSuccess : kDanger)),
                              ),
                              if (rating > 0) ...[
                                const SizedBox(width: 8),
                                const Icon(Icons.star_rounded, size: 15, color: kGold),
                                const SizedBox(width: 2),
                                Text(rating.toStringAsFixed(1),
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: kInkSoft)),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    stat('${_depts.length}', 'Rayons'),
                    const SizedBox(width: 8),
                    stat('$floors', floors > 1 ? 'Étages' : 'Étage'),
                    const SizedBox(width: 8),
                    stat('${_all.length}', 'Produits'),
                  ],
                ),
                if (city.isNotEmpty) line(Icons.place_rounded, city),
                if (address.isNotEmpty) line(Icons.map_outlined, address),
                if (phone.isNotEmpty) line(Icons.phone_outlined, phone),
                if (desc.isNotEmpty) line(Icons.info_outline_rounded, desc),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --------------------------------------------------------------------------
  // RECHERCHE
  // --------------------------------------------------------------------------
  void _onQuery(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 220), () {
      if (!mounted) return;
      setState(() {
        _query = v.trim();
        if (_query.isNotEmpty) _promoMode = false;
      });
    });
  }

  void _clearSearch() {
    _searchCtrl.clear();
    _focus.unfocus();
    setState(() {
      _query = '';
      _promoMode = false;
    });
  }

  List<SupermarketProduct> _computeResults() {
    if (_promoMode) {
      return _all.where((p) => p.onPromo && smStockOf(p) > 0).take(40).toList();
    }
    final q = smFold(_query);
    if (q.isEmpty) return const <SupermarketProduct>[];
    final out = <SupermarketProduct>[];
    for (final p in _all) {
      final title = _foldCache.putIfAbsent(smPid(p), () => smFold(p.title));
      final bc = p.barcode ?? '';
      if (title.contains(q) || (bc.isNotEmpty && bc.contains(_query))) {
        out.add(p);
        if (out.length >= 40) break;
      }
    }
    return out;
  }

  String _locate(SupermarketProduct p) {
    final idx = _depts.indexWhere((d) => d.id == p.departmentId);
    if (idx < 0) return 'Rayon inconnu';
    return 'Allée ${idx + 1} · ${_depts[idx].name} · ${smFloorName(idx ~/ kSmFloorSize)}';
  }

  // --------------------------------------------------------------------------
  // BUILD
  // --------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final shopAsync = ref.watch(supermarketDetailsProvider(widget.supermarketId));
    final deptsAsync = ref.watch(departmentsProvider(widget.supermarketId));
    final productsAsync = ref.watch(supermarketShelfProductsProvider(widget.supermarketId));

    return Scaffold(
      backgroundColor: kBg,
      body: shopAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: kAccent, strokeWidth: 2)),
        error: (e, _) => Center(child: Text('$e')),
        data: (shop) {
          if (shop == null) {
            return const Center(child: Text('Supermarché introuvable', style: TextStyle(color: kInkMuted)));
          }

          _depts = deptsAsync.valueOrNull ?? <SupermarketDepartment>[];
          final raw = productsAsync.valueOrNull ?? <SupermarketProduct>[];
          _all = (raw as List).cast<SupermarketProduct>();

          final floorCount = math.max(1, (_depts.length / kSmFloorSize).ceil());
          if (_floor >= floorCount) _floor = floorCount - 1;

          final byDept = <String, List<SupermarketProduct>>{};
          for (final p in _all) {
            byDept.putIfAbsent('${p.departmentId}', () => <SupermarketProduct>[]).add(p);
          }

          if (!_entryStarted) {
            _entryStarted = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              Future.delayed(const Duration(milliseconds: 450), () {
                if (mounted) _entry.forward();
              });
            });
          }

          final panelOpen = _promoMode || _query.isNotEmpty;
          final heroOn = _heroVisible && !panelOpen;
          final start = _floor * kSmFloorSize;
          final end = math.min(start + kSmFloorSize, _depts.length);
          final floorDepts = _depts.isEmpty ? const <SupermarketDepartment>[] : _depts.sublist(start, end);

          final body = SafeArea(
            bottom: false,
            child: Column(
              children: [
                _topBar(shop),
                ClipRect(
                  child: AnimatedSize(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic,
                    alignment: Alignment.topCenter,
                    child: SizedBox(
                      width: double.infinity,
                      height: heroOn ? kSmHeroH + 8 : 0,
                      child: heroOn
                          ? _PromoHero(
                              products: _all,
                              storeName: shop['name']?.toString() ?? '',
                              logo: shop['logo_url']?.toString(),
                              added: _added,
                              locate: _locate,
                              onGo: _goToProduct,
                              onAdd: (p) => _addToCart(p),
                            )
                          : const SizedBox.shrink(),
                    ),
                  ),
                ),
                _searchBar(),
                _quickChips(),
                Expanded(
                  child: Stack(
                    children: [
                      const Positioned.fill(child: RepaintBoundary(child: CustomPaint(painter: SmBackdropPainter()))),
                      Positioned.fill(
                        child: AnimatedOpacity(
                          opacity: _hidden ? 0 : 1,
                          duration: const Duration(milliseconds: 200),
                          child: AnimatedSlide(
                            offset: _hidden ? Offset(0, 0.08 * _slideDir) : Offset.zero,
                            duration: const Duration(milliseconds: 230),
                            curve: Curves.easeOutCubic,
                            child: _buildAisles(floorDepts, start, byDept),
                          ),
                        ),
                      ),
                      const Positioned.fill(
                        child: IgnorePointer(child: RepaintBoundary(child: CustomPaint(painter: SmCeilingPainter()))),
                      ),
                      Positioned(
                        left: 10,
                        right: 10,
                        bottom: 10 + MediaQuery.of(context).padding.bottom,
                        child: _Hud(
                          floor: _floor,
                          floorCount: floorCount,
                          floorDepts: floorDepts,
                          firstAisleNo: start + 1,
                          aisle: _aisle,
                          cart: _cartCount,
                          onJump: (i) {
                            if (_pageCtrl.hasClients) {
                              HapticFeedback.selectionClick();
                              _pageCtrl.animateToPage(i,
                                  duration: const Duration(milliseconds: 550), curve: Curves.easeInOutCubic);
                            }
                          },
                          onUp: () => _changeFloor(_floor + 1),
                          onDown: () => _changeFloor(_floor - 1),
                          onCart: () => context.push('/market/cart'),
                        ),
                      ),
                      if (panelOpen)
                        Positioned.fill(
                          child: _ResultsPanel(
                            promo: _promoMode,
                            results: _computeResults(),
                            locate: _locate,
                            onGo: _goToProduct,
                            onAdd: (p) => _addToCart(p),
                            onClose: _clearSearch,
                            added: _added,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );

          return Stack(
            fit: StackFit.expand,
            children: [
              AnimatedBuilder(
                animation: _entry,
                child: body,
                builder: (_, child) {
                  final t = Curves.easeOutCubic.transform(_entry.value);
                  return Transform.scale(scale: 0.9 + 0.1 * t, child: child);
                },
              ),
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _entry,
                  builder: (_, __) {
                    if (_entry.isCompleted) return const SizedBox.shrink();
                    return _StoreEntrance(
                      t: _entry,
                      name: shop['name']?.toString() ?? '',
                      onSkip: () => _entry.animateTo(1, duration: const Duration(milliseconds: 350)),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildAisles(
    List<SupermarketDepartment> floorDepts,
    int start,
    Map<String, List<SupermarketProduct>> byDept,
  ) {
    if (floorDepts.isEmpty) {
      return const Center(
        child: Text('Aucun rayon pour le moment',
            style: TextStyle(color: kInkMuted, fontWeight: FontWeight.w700, fontSize: 13)),
      );
    }
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n is! ScrollUpdateNotification) return false;
        if (n.metrics.axis != Axis.vertical) return false;
        final px = n.metrics.pixels;
        if (px > 60 && _heroVisible) {
          setState(() => _heroVisible = false);
        } else if (px < 8 && !_heroVisible) {
          setState(() => _heroVisible = true);
        }
        return false;
      },
      child: PageView.builder(
        key: ValueKey('floor_$_floor'),
        controller: _pageCtrl,
        physics: const BouncingScrollPhysics(),
        itemCount: floorDepts.length,
        onPageChanged: (i) {
          _aisle.value = i;
          HapticFeedback.selectionClick();
        },
        itemBuilder: (_, i) {
          final dept = floorDepts[i];
          final globalNo = start + i + 1;
          final products = byDept['${dept.id}'] ?? const <SupermarketProduct>[];
          return SmAisleCarouselItem(
            controller: _pageCtrl,
            index: i,
            child: SmAislePage(
              dept: dept,
              aisleNumber: globalNo,
              products: products,
              zone: smZoneOf(dept.name),
              highlight: _highlight,
              added: _added,
              onTapProduct: _openQuickView,
              onAdd: (p) => _addToCart(p),
              onOpenAisle: () {
                HapticFeedback.selectionClick();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => DepartmentProductsPage(
                      departmentId: dept.id,
                      departmentName: dept.name,
                      aisleNumber: globalNo,
                      accentColor: dept.color,
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  // --------------------------------------------------------------------------
  // TOP BAR / RECHERCHE / CHIPS
  // --------------------------------------------------------------------------
  Widget _topBar(Map<String, dynamic> shop) {
    final name = shop['name']?.toString() ?? '';
    final city = shop['city']?.toString() ?? '';
    final logo = shop['logo_url']?.toString();
    final rating = (shop['rating'] as num?)?.toDouble() ?? 0;
    final isOpen = (shop['is_open'] as bool?) ?? true;

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
      child: SmTapScale(
        onTap: () => _showShopInfo(shop),
        child: Container(
          padding: const EdgeInsets.fromLTRB(6, 6, 12, 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: kBorder),
            boxShadow: const [BoxShadow(color: Color(0x140F172A), blurRadius: 14, offset: Offset(0, 5))],
          ),
          child: Row(
            children: [
              SmTapScale(
                onTap: () => Navigator.of(context).maybePop(),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(color: kSurface, shape: BoxShape.circle),
                  child: const Icon(Icons.arrow_back_ios_new_rounded, size: 14, color: kInkSoft),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 40,
                height: 40,
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(colors: [kAccent, kGold]),
                ),
                child: Container(
                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                  child: ClipOval(
                    child: (logo != null && logo.isNotEmpty)
                        ? CachedNetworkImage(
                            imageUrl: logo,
                            fit: BoxFit.cover,
                            memCacheWidth: smMemW(120),
                            errorWidget: (_, __, ___) => const Icon(Icons.storefront_rounded, size: 18, color: kAccent),
                          )
                        : const Icon(Icons.storefront_rounded, size: 18, color: kAccent),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: kInk, letterSpacing: -0.2)),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          margin: const EdgeInsets.only(right: 5),
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: (isOpen ? kSuccess : kDanger).withOpacity(0.14),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(isOpen ? 'OUVERT' : 'FERMÉ',
                              style: TextStyle(
                                  fontSize: 7.5, fontWeight: FontWeight.w900, letterSpacing: 0.5, color: isOpen ? kSuccess : kDanger)),
                        ),
                        const Icon(Icons.place_rounded, size: 10, color: kInkMuted),
                        const SizedBox(width: 2),
                        Flexible(
                          child: Text(city,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 10, color: kInkMuted)),
                        ),
                        if (rating > 0) ...[
                          const SizedBox(width: 6),
                          const Icon(Icons.star_rounded, size: 12, color: kGold),
                          Text(rating.toStringAsFixed(1),
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: kGold)),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    ValueListenableBuilder<int>(
                      valueListenable: _aisle,
                      builder: (_, a, __) {
                        final idx = _floor * kSmFloorSize + a;
                        final deptName = (idx >= 0 && idx < _depts.length) ? _depts[idx].name : '';
                        final text = deptName.isEmpty
                            ? smFloorName(_floor)
                            : '${smFloorName(_floor)} · Allée ${idx + 1} · $deptName';
                        return Row(
                          children: [
                            const Icon(Icons.navigation_rounded, size: 10, color: kAccent),
                            const SizedBox(width: 3),
                            Flexible(
                              child: Text(text,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: kAccent)),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.info_outline_rounded, size: 18, color: kInkMuted),
            ],
          ),
        ),
      ),
    );
  }

  Widget _searchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 6),
      child: Container(
        height: 42,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(21),
          border: Border.all(color: kBorder),
          boxShadow: const [BoxShadow(color: Color(0x0F0F172A), blurRadius: 10, offset: Offset(0, 3))],
        ),
        child: TextField(
          controller: _searchCtrl,
          focusNode: _focus,
          textInputAction: TextInputAction.search,
          onChanged: _onQuery,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kInk),
          decoration: InputDecoration(
            hintText: 'Rechercher un produit ou un code-barres…',
            hintStyle: const TextStyle(fontSize: 12, color: kInkMuted, fontWeight: FontWeight.w500),
            prefixIcon: const Icon(Icons.search_rounded, size: 19, color: kAccent),
            suffixIcon: (_query.isNotEmpty || _promoMode)
                ? IconButton(
                    icon: const Icon(Icons.close_rounded, size: 17, color: kInkMuted),
                    onPressed: _clearSearch,
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
      ),
    );
  }

  Widget _quickChips() {
    final zoneFirst = <SmZone, int>{};
    for (var i = 0; i < _depts.length; i++) {
      zoneFirst.putIfAbsent(smZoneOf(_depts[i].name), () => i);
    }
    final promoCount = _all.where((p) => p.onPromo).length;

    final chips = <Widget>[
      if (promoCount > 0)
        _QuickChip(
          label: 'Promos',
          icon: Icons.local_fire_department_rounded,
          color: kSmRed,
          badge: promoCount,
          selected: _promoMode,
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() {
              _promoMode = !_promoMode;
              if (_promoMode) {
                _searchCtrl.clear();
                _query = '';
                _focus.unfocus();
              }
            });
          },
        ),
      if (zoneFirst.containsKey(SmZone.drinks))
        _QuickChip(
          label: 'Boissons',
          icon: Icons.local_drink_rounded,
          color: const Color(0xFF00838F),
          onTap: () => _goToIndex(zoneFirst[SmZone.drinks]!),
        ),
      if (zoneFirst.containsKey(SmZone.frozen))
        _QuickChip(
          label: 'Surgelés',
          icon: Icons.ac_unit_rounded,
          color: const Color(0xFF0288D1),
          onTap: () => _goToIndex(zoneFirst[SmZone.frozen]!),
        ),
      if (zoneFirst.containsKey(SmZone.fresh))
        _QuickChip(
          label: 'Frais',
          icon: Icons.kitchen_rounded,
          color: kSuccess,
          onTap: () => _goToIndex(zoneFirst[SmZone.fresh]!),
        ),
      if (zoneFirst.containsKey(SmZone.produce))
        _QuickChip(
          label: 'Primeur',
          icon: Icons.eco_rounded,
          color: const Color(0xFF8D6E63),
          onTap: () => _goToIndex(zoneFirst[SmZone.produce]!),
        ),
    ];
    if (chips.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        itemCount: chips.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (_, i) => chips[i],
      ),
    );
  }
}

// ============================================================================
// HERO BANNER — GRAND FORMAT (style THIX LOCAL)
// ============================================================================
class _PromoHero extends StatefulWidget {
  final List<SupermarketProduct> products;
  final String storeName;
  final String? logo;
  final ValueNotifier<Set<String>> added;
  final String Function(SupermarketProduct) locate;
  final ValueChanged<SupermarketProduct> onGo;
  final ValueChanged<SupermarketProduct> onAdd;

  const _PromoHero({
    required this.products,
    required this.storeName,
    required this.logo,
    required this.added,
    required this.locate,
    required this.onGo,
    required this.onAdd,
  });

  @override
  State<_PromoHero> createState() => _PromoHeroState();
}

class _PromoHeroState extends State<_PromoHero> {
  final PageController _ctrl = PageController(viewportFraction: 0.94);
  Timer? _timer;
  int _index = 0;
  DateTime _resumeAt = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      final n = _items().length;
      if (!mounted || n <= 1 || !_ctrl.hasClients) return;
      if (DateTime.now().isBefore(_resumeAt)) return;
      final next = (_index + 1) % n;
      _ctrl.animateToPage(next, duration: const Duration(milliseconds: 700), curve: Curves.easeOutCubic);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  List<SupermarketProduct> _items() {
    final promos = <SupermarketProduct>[
      for (final p in widget.products) if (p.onPromo && smStockOf(p) > 0) p,
    ];
    if (promos.isNotEmpty) return promos.take(8).toList();

    final featured = <SupermarketProduct>[
      for (final p in widget.products) if ((p.isFeatured || p.rating >= 4.5) && smStockOf(p) > 0) p,
    ];
    if (featured.isNotEmpty) return featured.take(6).toList();

    return <SupermarketProduct>[
      for (final p in widget.products) if (p.hasPhotos && smStockOf(p) > 0) p,
    ].take(6).toList();
  }

  @override
  Widget build(BuildContext context) {
    final items = _items();
    if (_index >= items.length && items.isNotEmpty) _index = 0;
    if (items.isEmpty) return _welcome();

    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n.metrics.axis == Axis.horizontal &&
            ((n is ScrollStartNotification && n.dragDetails != null) ||
                (n is ScrollUpdateNotification && n.dragDetails != null))) {
          _resumeAt = DateTime.now().add(const Duration(seconds: 4));
        }
        return false;
      },
      child: Stack(
        children: [
          PageView.builder(
            controller: _ctrl,
            itemCount: items.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (_, i) => _tile(items[i], i, items.length),
          ),
          if (items.length > 1)
            Positioned(
              bottom: 5,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List<Widget>.generate(items.length, (i) {
                  final on = i == _index;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 240),
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    width: on ? 16 : 5,
                    height: 4,
                    decoration: BoxDecoration(
                      color: on ? kAccent : kBorder,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  );
                }),
              ),
            ),
        ],
      ),
    );
  }

  Widget _welcome() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 2, 12, 10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [kAccentDark, kAccent, Color(0xFFFB923C)],
        ),
        borderRadius: BorderRadius.circular(26),
        boxShadow: [BoxShadow(color: kAccent.withOpacity(0.35), blurRadius: 18, offset: const Offset(0, 8))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: Stack(
          children: [
            Positioned(
              right: -30,
              top: -30,
              child: Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.12)),
              ),
            ),
            Positioned(
              right: 40,
              bottom: -50,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.1)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withOpacity(0.6), width: 3),
                    ),
                    child: ClipOval(
                      child: (widget.logo != null && widget.logo!.isNotEmpty)
                          ? CachedNetworkImage(
                              imageUrl: widget.logo!,
                              fit: BoxFit.cover,
                              memCacheWidth: smMemW(200),
                              errorWidget: (_, __, ___) => const Icon(Icons.storefront_rounded, color: kAccent, size: 32),
                            )
                          : const Icon(Icons.storefront_rounded, color: kAccent, size: 32),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.storeName.isEmpty ? 'Bienvenue' : 'Bienvenue chez ${widget.storeName}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white, fontSize: 19, height: 1.15, fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 6),
                        Text('Parcourez les rayons en 3D',
                            style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 12.5, fontWeight: FontWeight.w600)),
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

  Widget _tile(SupermarketProduct p, int i, int total) {
    final promo = p.onPromo;
    return Padding(
      padding: const EdgeInsets.fromLTRB(5, 2, 5, 12),
      child: SmTapScale(
        onTap: () => widget.onGo(p),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            boxShadow: const [BoxShadow(color: Color(0x4D0F172A), blurRadius: 18, offset: Offset(0, 8))],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(26),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (p.hasPhotos)
                  _KenBurns(
                    child: CachedNetworkImage(
                      imageUrl: p.mainPhoto,
                      fit: BoxFit.cover,
                      memCacheWidth: smMemW(900),
                      placeholder: (_, __) => Container(color: kInk),
                      errorWidget: (_, __, ___) => Container(color: kInk),
                    ),
                  )
                else
                  Container(
                    decoration: const BoxDecoration(gradient: LinearGradient(colors: [kAccentDark, kAccent])),
                  ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.28),
                        Colors.black.withOpacity(0.08),
                        Colors.black.withOpacity(0.82),
                      ],
                      stops: const [0.0, 0.38, 1.0],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                            decoration: BoxDecoration(
                              color: promo ? kSmRed : kGold,
                              borderRadius: BorderRadius.circular(9),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(promo ? Icons.local_fire_department_rounded : Icons.star_rounded,
                                    size: 12, color: Colors.white),
                                const SizedBox(width: 4),
                                Text(promo ? 'PROMO -${p.promoPercent}%' : 'SÉLECTION',
                                    style: const TextStyle(
                                        fontSize: 9.5, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 0.6)),
                              ],
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.35),
                              borderRadius: BorderRadius.circular(9),
                              border: Border.all(color: Colors.white.withOpacity(0.25)),
                            ),
                            child: Text('${i + 1}/$total',
                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white)),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 19, height: 1.12, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.3)),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Text('${p.priceLabel()} ${p.currency}',
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: kGold)),
                              if (promo) ...[
                                const SizedBox(width: 8),
                                Text('${p.price}',
                                    style: TextStyle(
                                        fontSize: 11.5, color: Colors.white.withOpacity(0.7), decoration: TextDecoration.lineThrough)),
                              ],
                              const SizedBox(width: 10),
                              Expanded(
                                child: Row(
                                  children: [
                                    const Icon(Icons.near_me_rounded, size: 11, color: Colors.white70),
                                    const SizedBox(width: 3),
                                    Expanded(
                                      child: Text(widget.locate(p),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontSize: 10, color: Colors.white70, fontWeight: FontWeight.w600)),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 9),
                          Row(
                            children: [
                              Expanded(
                                child: SmTapScale(
                                  onTap: () => widget.onGo(p),
                                  child: Container(
                                    height: 34,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.18),
                                      borderRadius: BorderRadius.circular(17),
                                      border: Border.all(color: Colors.white.withOpacity(0.55)),
                                    ),
                                    child: const Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.near_me_rounded, size: 14, color: Colors.white),
                                        SizedBox(width: 5),
                                        Text('Voir en rayon',
                                            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w900, color: Colors.white)),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ValueListenableBuilder<Set<String>>(
                                  valueListenable: widget.added,
                                  builder: (_, set, __) {
                                    final done = set.contains(smPid(p));
                                    return SmTapScale(
                                      onTap: () => widget.onAdd(p),
                                      child: AnimatedContainer(
                                        duration: const Duration(milliseconds: 200),
                                        height: 34,
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: done ? const [kSuccess, Color(0xFF22C55E)] : const [kAccent, Color(0xFFFB923C)],
                                          ),
                                          borderRadius: BorderRadius.circular(17),
                                          boxShadow: [BoxShadow(color: kAccent.withOpacity(0.45), blurRadius: 10, offset: const Offset(0, 3))],
                                        ),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(done ? Icons.check_rounded : Icons.add_shopping_cart_rounded,
                                                size: 14, color: Colors.white),
                                            const SizedBox(width: 5),
                                            Text(done ? 'Ajouté' : 'Ajouter',
                                                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w900, color: Colors.white)),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
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
          ),
        ),
      ),
    );
  }
}

class _KenBurns extends StatefulWidget {
  final Widget child;
  const _KenBurns({required this.child});

  @override
  State<_KenBurns> createState() => _KenBurnsState();
}

class _KenBurnsState extends State<_KenBurns> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 9))..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      child: widget.child,
      builder: (_, child) => Transform.scale(
        scale: 1.0 + 0.09 * Curves.easeInOut.transform(_c.value),
        child: child,
      ),
    );
  }
}

// ============================================================================
// ENTRÉE : PORTES VITRÉES COULISSANTES
// ============================================================================
class _StoreEntrance extends StatelessWidget {
  final Animation<double> t;
  final String name;
  final VoidCallback onSkip;
  const _StoreEntrance({required this.t, required this.name, required this.onSkip});

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;
    return LayoutBuilder(
      builder: (context, box) {
        final w = box.maxWidth;
        return AnimatedBuilder(
          animation: t,
          builder: (_, __) {
            final open = const Interval(0.30, 0.78, curve: Curves.easeInOutCubic).transform(t.value);
            final fade = 1 - const Interval(0.82, 1.0, curve: Curves.easeIn).transform(t.value);
            final hint = 1 - const Interval(0.0, 0.25).transform(t.value);
            final sensorOn = t.value > 0.28;

            return Opacity(
              opacity: fade,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onSkip,
                child: Stack(
                  children: [
                    Positioned(left: -open * w / 2, top: 0, bottom: 0, width: w / 2, child: const _GlassDoor(left: true)),
                    Positioned(right: -open * w / 2, top: 0, bottom: 0, width: w / 2, child: const _GlassDoor(left: false)),
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        padding: EdgeInsets.fromLTRB(14, topInset + 10, 14, 10),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [kAccentDark, kAccent]),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.25), blurRadius: 12, offset: const Offset(0, 4))],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(color: Colors.white.withOpacity(0.18), borderRadius: BorderRadius.circular(8)),
                              child: const Icon(Icons.storefront_rounded, color: Colors.white, size: 18),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                name.isEmpty ? 'Supermarché' : name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: -0.3),
                              ),
                            ),
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: sensorOn ? const Color(0xFF69F0AE) : const Color(0xFFFF5252),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: (sensorOn ? const Color(0xFF69F0AE) : const Color(0xFFFF5252)).withOpacity(0.7),
                                    blurRadius: 6,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 60,
                      child: Opacity(
                        opacity: hint.clamp(0.0, 1.0),
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(22),
                              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 10)],
                            ),
                            child: const Text('Bienvenue — les portes s\'ouvrent…',
                                style: TextStyle(color: kAccentDark, fontSize: 11.5, fontWeight: FontWeight.w800)),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _GlassDoor extends StatelessWidget {
  final bool left;
  const _GlassDoor({required this.left});

  @override
  Widget build(BuildContext context) {
    const frame = BorderSide(color: Color(0xFF90A4AE), width: 4);
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFD9EEFB), Color(0xFFB7DCF3), Color(0xFFDDF0FC)],
        ),
        border: Border(top: frame, bottom: frame, left: left ? frame : BorderSide.none, right: left ? BorderSide.none : frame),
      ),
      child: Stack(
        children: [
          Align(alignment: Alignment.center, child: Container(height: 40, color: Colors.white.withOpacity(0.35))),
          Align(
            alignment: left ? Alignment.centerRight : Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Container(
                width: 6,
                height: 110,
                decoration: BoxDecoration(color: const Color(0xFF546E7A), borderRadius: BorderRadius.circular(3)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// HUD : ASCENSEUR + MINI-PLAN + PANIER
// ============================================================================
class _Hud extends StatelessWidget {
  final int floor;
  final int floorCount;
  final List<SupermarketDepartment> floorDepts;
  final int firstAisleNo;
  final ValueNotifier<int> aisle;
  final ValueNotifier<int> cart;
  final ValueChanged<int> onJump;
  final VoidCallback onUp;
  final VoidCallback onDown;
  final VoidCallback onCart;

  const _Hud({
    required this.floor,
    required this.floorCount,
    required this.floorDepts,
    required this.firstAisleNo,
    required this.aisle,
    required this.cart,
    required this.onJump,
    required this.onUp,
    required this.onDown,
    required this.onCart,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (floorCount > 1) ...[
          _Elevator(floor: floor, count: floorCount, onUp: onUp, onDown: onDown),
          const SizedBox(width: 6),
        ],
        Expanded(child: _miniMap()),
        const SizedBox(width: 6),
        _CartFab(count: cart, onTap: onCart),
      ],
    );
  }

  Widget _miniMap() {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.96),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kBorder),
        boxShadow: const [BoxShadow(color: Color(0x1F0F172A), blurRadius: 14, offset: Offset(0, 5))],
      ),
      child: ValueListenableBuilder<int>(
        valueListenable: aisle,
        builder: (_, current, __) {
          return Row(
            children: List<Widget>.generate(floorDepts.length, (i) {
              final d = floorDepts[i];
              final active = i == current;
              return Expanded(
                child: SmTapScale(
                  onTap: () => onJump(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      color: active ? d.color : d.color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: active ? [BoxShadow(color: d.color.withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 2))] : null,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(active ? Icons.shopping_cart_rounded : d.icon, size: 14, color: active ? Colors.white : d.color),
                        Text('${firstAisleNo + i}',
                            style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w900, color: active ? Colors.white : d.color)),
                      ],
                    ),
                  ),
                ),
              );
            }),
          );
        },
      ),
    );
  }
}

class _Elevator extends StatelessWidget {
  final int floor;
  final int count;
  final VoidCallback onUp;
  final VoidCallback onDown;
  const _Elevator({required this.floor, required this.count, required this.onUp, required this.onDown});

  Widget _btn(IconData icon, bool enabled, VoidCallback onTap) {
    return SmTapScale(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 34,
        height: 26,
        decoration: BoxDecoration(
          gradient: enabled ? const LinearGradient(colors: [kAccent, Color(0xFFFB923C)]) : null,
          color: enabled ? null : kBorder,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 18, color: Colors.white),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.96),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorder),
        boxShadow: const [BoxShadow(color: Color(0x1F0F172A), blurRadius: 12, offset: Offset(0, 4))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _btn(Icons.keyboard_arrow_up_rounded, floor < count - 1, onUp),
          const SizedBox(height: 1),
          const Text('ÉTAGE', style: TextStyle(fontSize: 6.5, fontWeight: FontWeight.w900, color: kInkMuted, letterSpacing: 0.5)),
          Text(smFloorShort(floor), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: kInk)),
          const SizedBox(height: 1),
          _btn(Icons.keyboard_arrow_down_rounded, floor > 0, onDown),
        ],
      ),
    );
  }
}

class _CartFab extends StatefulWidget {
  final ValueNotifier<int> count;
  final VoidCallback onTap;
  const _CartFab({required this.count, required this.onTap});

  @override
  State<_CartFab> createState() => _CartFabState();
}

class _CartFabState extends State<_CartFab> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (_, child) {
        final t = _pulse.value;
        return Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 54 + t * 12,
              height: 54 + t * 12,
              decoration: BoxDecoration(shape: BoxShape.circle, color: kAccent.withOpacity(0.15 * (1 - t))),
            ),
            child!,
          ],
        );
      },
      child: SmTapScale(
        onTap: widget.onTap,
        child: SizedBox(
          width: 54,
          height: 54,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFFB923C), kAccentDark]),
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: kAccent.withOpacity(0.45), blurRadius: 12, offset: const Offset(0, 5))],
                ),
                child: const Icon(Icons.shopping_cart_rounded, color: Colors.white, size: 23),
              ),
              Positioned(
                top: -2,
                right: -2,
                child: ValueListenableBuilder<int>(
                  valueListenable: widget.count,
                  builder: (_, n, __) {
                    if (n == 0) return const SizedBox.shrink();
                    return Container(
                      constraints: const BoxConstraints(minWidth: 18),
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      decoration: BoxDecoration(
                        color: kSmRed,
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      child: Text('$n',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.white)),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final int? badge;
  final VoidCallback onTap;
  const _QuickChip({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    this.selected = false,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return SmTapScale(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.fromLTRB(6, 0, 12, 0),
        height: 34,
        decoration: BoxDecoration(
          color: selected ? color : Colors.white,
          borderRadius: BorderRadius.circular(17),
          border: Border.all(color: selected ? color : color.withOpacity(0.35)),
          boxShadow: selected ? [BoxShadow(color: color.withOpacity(0.35), blurRadius: 8, offset: const Offset(0, 3))] : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: selected ? Colors.white.withOpacity(0.25) : color.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 13, color: selected ? Colors.white : color),
            ),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: selected ? Colors.white : kInk)),
            if (badge != null) ...[
              const SizedBox(width: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: selected ? Colors.white : color,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('$badge',
                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: selected ? color : Colors.white)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// RÉSULTATS DE RECHERCHE
// ============================================================================
class _ResultsPanel extends StatelessWidget {
  final bool promo;
  final List<SupermarketProduct> results;
  final String Function(SupermarketProduct) locate;
  final ValueChanged<SupermarketProduct> onGo;
  final ValueChanged<SupermarketProduct> onAdd;
  final VoidCallback onClose;
  final ValueNotifier<Set<String>> added;

  const _ResultsPanel({
    required this.promo,
    required this.results,
    required this.locate,
    required this.onGo,
    required this.onAdd,
    required this.onClose,
    required this.added,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(8, 4, 8, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: kBorder),
        boxShadow: const [BoxShadow(color: Color(0x1F0F172A), blurRadius: 18, offset: Offset(0, 6))],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 4, 4),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: (promo ? kSmRed : kAccent).withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(promo ? Icons.local_fire_department_rounded : Icons.search_rounded,
                      size: 15, color: promo ? kSmRed : kAccent),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    promo ? 'Promotions du moment' : '${results.length} résultat(s)',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: kInk),
                  ),
                ),
                IconButton(icon: const Icon(Icons.close_rounded, size: 19, color: kInkMuted), onPressed: onClose),
              ],
            ),
          ),
          const Divider(height: 1, color: kBorder),
          Expanded(
            child: results.isEmpty
                ? const Center(
                    child: Text('Aucun produit trouvé',
                        style: TextStyle(color: kInkMuted, fontWeight: FontWeight.w700, fontSize: 12)),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemCount: results.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, color: kBorder),
                    itemBuilder: (_, i) {
                      final p = results[i];
                      final out = smStockOf(p) <= 0;
                      return SmTapScale(
                        onTap: () => onGo(p),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: SizedBox(
                                  width: 48,
                                  height: 48,
                                  child: p.hasPhotos
                                      ? CachedNetworkImage(
                                          imageUrl: p.mainPhoto,
                                          fit: BoxFit.cover,
                                          memCacheWidth: smMemW(130),
                                          errorWidget: (_, __, ___) =>
                                              const ColoredBox(color: kSurface, child: Icon(Icons.inventory_2_rounded, color: kInkMuted)),
                                        )
                                      : const ColoredBox(color: kSurface, child: Icon(Icons.inventory_2_rounded, color: kInkMuted)),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(p.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: kInk)),
                                    const SizedBox(height: 2),
                                    Row(
                                      children: [
                                        const Icon(Icons.near_me_rounded, size: 10, color: kAccent),
                                        const SizedBox(width: 3),
                                        Expanded(
                                          child: Text(locate(p),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(fontSize: 10, color: kInkMuted)),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text('${p.priceLabel()} ${p.currency}',
                                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: p.onPromo ? kSmRed : kInk)),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              ValueListenableBuilder<Set<String>>(
                                valueListenable: added,
                                builder: (_, set, __) {
                                  final done = set.contains(smPid(p));
                                  return SmTapScale(
                                    onTap: out ? null : () => onAdd(p),
                                    child: Container(
                                      width: 34,
                                      height: 34,
                                      decoration: BoxDecoration(
                                        color: out ? Colors.grey.shade400 : (done ? kSuccess : kAccent),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                          out ? Icons.block_rounded : (done ? Icons.check_rounded : Icons.add_shopping_cart_rounded),
                                          size: 16,
                                          color: Colors.white),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
