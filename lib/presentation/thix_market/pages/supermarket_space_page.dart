// lib/presentation/thix_market/pages/supermarket_space_page.dart
// ============================================================================
// SUPERMARCHÉ — "Storefront Pro" v7
// Fichier 1/2 : page + logique (état, panier Supabase, recherche, layout)
// Fichier 2/2 : supermarket_space_widgets.dart (design system + composants)
// ============================================================================

import 'dart:async';

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

class SupermarketSpacePage extends ConsumerStatefulWidget {
  final String supermarketId;
  const SupermarketSpacePage({super.key, required this.supermarketId});

  @override
  ConsumerState<SupermarketSpacePage> createState() => _SupermarketSpacePageState();
}

class _SupermarketSpacePageState extends ConsumerState<SupermarketSpacePage> {
  static const Duration _dbTimeout = Duration(seconds: 15);

  final ValueNotifier<int> _cartCount = ValueNotifier<int>(0);
  final ValueNotifier<Set<String>> _added = ValueNotifier<Set<String>>(<String>{});
  final Set<String> _busy = <String>{};

  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _focus = FocusNode();
  final ScrollController _scroll = ScrollController();
  Timer? _debounce;

  String _query = '';
  String _railId = kSmAll;

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
    _cartCount.dispose();
    _added.dispose();
    _debounce?.cancel();
    _searchCtrl.dispose();
    _focus.dispose();
    _scroll.dispose();
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
        margin: const EdgeInsets.fromLTRB(14, 0, 14, 90),
        backgroundColor: error ? SmColors.red : SmColors.ink,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        duration: const Duration(seconds: 3),
        content: Row(children: [
          Icon(error ? Icons.error_outline_rounded : Icons.check_circle_rounded,
              color: error ? Colors.white : SmColors.yellow, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(msg,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Colors.white)),
          ),
        ]),
        action: cart
            ? SnackBarAction(
                label: 'Voir',
                textColor: SmColors.yellow,
                onPressed: () => context.push('/market/cart'),
              )
            : null,
      ),
    );
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
      final res = await db.from('cart').select('quantity').eq('user_id', uid).timeout(_dbTimeout);
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
          .timeout(_dbTimeout);

      if (existing != null) {
        final cur = (existing['quantity'] as num?)?.toInt() ?? 0;
        if (cur + qty > stock) {
          _toast('Stock limité à $stock (déjà $cur)', error: true);
          return;
        }
        await db.from('cart').update({'quantity': cur + qty}).eq('id', existing['id']).timeout(_dbTimeout);
      } else {
        await db
            .from('cart')
            .insert({'user_id': uid, 'product_id': pid, 'quantity': qty})
            .timeout(_dbTimeout);
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
  // NAVIGATION / SHEETS
  // --------------------------------------------------------------------------
  void _openQuickView(SupermarketProduct p) {
    HapticFeedback.selectionClick();
    FocusScope.of(context).unfocus();
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

  void _openDepartment(SupermarketDepartment d, int number) {
    HapticFeedback.selectionClick();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DepartmentProductsPage(
          departmentId: d.id,
          departmentName: d.name,
          aisleNumber: number,
          accentColor: d.color,
        ),
      ),
    );
  }

  void _selectRail(String id) {
    if (id == _railId) return;
    HapticFeedback.selectionClick();
    setState(() => _railId = id);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.jumpTo(0);
    });
  }

  // --------------------------------------------------------------------------
  // RECHERCHE
  // --------------------------------------------------------------------------
  void _onQuery(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 220), () {
      if (!mounted) return;
      setState(() => _query = v.trim());
    });
  }

  void _clearSearch() {
    _searchCtrl.clear();
    _focus.unfocus();
    setState(() => _query = '');
  }

  List<SupermarketProduct> _computeResults() {
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
    final idx = _depts.indexWhere((d) => '${d.id}' == '${p.departmentId}');
    if (idx < 0) return 'Rayon inconnu';
    return 'Rayon ${idx + 1} · ${_depts[idx].name}';
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
      backgroundColor: SmColors.bg,
      resizeToAvoidBottomInset: false,
      body: shopAsync.when(
        loading: () => const SmLoadingView(),
        error: (e, _) => Center(child: Text('$e')),
        data: (shop) {
          if (shop == null) {
            return const Center(
              child: Text('Supermarché introuvable', style: TextStyle(color: SmColors.inkMuted)),
            );
          }

          _depts = deptsAsync.valueOrNull ?? <SupermarketDepartment>[];
          final raw = productsAsync.valueOrNull ?? <SupermarketProduct>[];
          _all = (raw as List).cast<SupermarketProduct>();

          final hasPromo = _all.any((p) => p.onPromo);
          if (_railId == kSmPromo && !hasPromo) _railId = kSmAll;
          if (_railId != kSmAll && _railId != kSmPromo && !_depts.any((d) => '${d.id}' == _railId)) {
            _railId = kSmAll;
          }

          final byDept = <String, List<SupermarketProduct>>{};
          for (final p in _all) {
            byDept.putIfAbsent('${p.departmentId}', () => <SupermarketProduct>[]).add(p);
          }

          return Stack(
            children: [
              Column(
                children: [
                  _header(shop),
                  Expanded(
                    child: CustomScrollView(
                      controller: _scroll,
                      physics: const BouncingScrollPhysics(),
                      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                      slivers: _slivers(shop, byDept, hasPromo),
                    ),
                  ),
                ],
              ),
              Positioned(
                left: 14,
                right: 14,
                bottom: 12 + MediaQuery.of(context).padding.bottom,
                child: SmCartBar(count: _cartCount, onTap: () => context.push('/market/cart')),
              ),
            ],
          );
        },
      ),
    );
  }

  // --------------------------------------------------------------------------
  // HEADER : identité + panier + recherche
  // --------------------------------------------------------------------------
  Widget _header(Map<String, dynamic> shop) {
    final name = shop['name']?.toString() ?? '';
    final city = shop['city']?.toString() ?? '';
    final logo = shop['logo_url']?.toString();
    final rating = (shop['rating'] as num?)?.toDouble() ?? 0;
    final isOpen = (shop['is_open'] as bool?) ?? true;

    return Container(
      padding: EdgeInsets.fromLTRB(12, MediaQuery.of(context).padding.top + 8, 12, 14),
      decoration: const BoxDecoration(
        gradient: SmColors.headerGradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              SmTapScale(
                onTap: () => Navigator.of(context).maybePop(),
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.16), shape: BoxShape.circle),
                  child: const Icon(Icons.arrow_back_ios_new_rounded, size: 15, color: Colors.white),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SmTapScale(
                  onTap: () => showSmShopInfo(
                    context,
                    shop: shop,
                    departments: _depts.length,
                    products: _all.length,
                  ),
                  child: Row(
                    children: [
                      SmShopLogo(url: logo, size: 42),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 15.5, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.2)),
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                SmPill(
                                  text: isOpen ? 'OUVERT' : 'FERMÉ',
                                  bg: isOpen ? SmColors.green : SmColors.red,
                                ),
                                if (city.isNotEmpty) ...[
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(city,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.8))),
                                  ),
                                ],
                                if (rating > 0) ...[
                                  const SizedBox(width: 8),
                                  const Icon(Icons.star_rounded, size: 13, color: SmColors.yellow),
                                  const SizedBox(width: 2),
                                  Text(rating.toStringAsFixed(1),
                                      style: const TextStyle(
                                          fontSize: 11, fontWeight: FontWeight.w800, color: SmColors.yellow)),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SmTapScale(
                onTap: () => context.push('/market/cart'),
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.16), shape: BoxShape.circle),
                        child: const Icon(Icons.shopping_bag_outlined, size: 20, color: Colors.white),
                      ),
                      Positioned(
                        top: -2,
                        right: -2,
                        child: ValueListenableBuilder<int>(
                          valueListenable: _cartCount,
                          builder: (_, n, __) {
                            if (n == 0) return const SizedBox.shrink();
                            return Container(
                              constraints: const BoxConstraints(minWidth: 18),
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              decoration: BoxDecoration(
                                color: SmColors.yellow,
                                borderRadius: BorderRadius.circular(9),
                                border: Border.all(color: SmColors.blueDark, width: 1.5),
                              ),
                              child: Text('$n',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: SmColors.ink)),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 14, offset: Offset(0, 5))],
            ),
            child: TextField(
              controller: _searchCtrl,
              focusNode: _focus,
              textInputAction: TextInputAction.search,
              onChanged: _onQuery,
              style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: SmColors.ink),
              decoration: InputDecoration(
                hintText: 'Rechercher un produit ou un code-barres…',
                hintStyle: const TextStyle(fontSize: 12.5, color: SmColors.inkMuted, fontWeight: FontWeight.w500),
                prefixIcon: const Icon(Icons.search_rounded, size: 20, color: SmColors.blue),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18, color: SmColors.inkMuted),
                        onPressed: _clearSearch,
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // CONTENU
  // --------------------------------------------------------------------------
  List<SmRailItem> _railItems(bool hasPromo) => <SmRailItem>[
        const SmRailItem(id: kSmAll, label: 'Tout', icon: Icons.grid_view_rounded, color: SmColors.blue),
        if (hasPromo)
          const SmRailItem(id: kSmPromo, label: 'Promos', icon: Icons.local_fire_department_rounded, color: SmColors.red),
        for (final d in _depts) SmRailItem(id: '${d.id}', label: d.name, icon: d.icon, color: d.color),
      ];

  SliverToBoxAdapter _railSliver(bool hasPromo) {
    // placeholder pour garder la signature simple (voir _pinnedRail)
    return const SliverToBoxAdapter(child: SizedBox.shrink());
  }

  Widget _pinnedRail(bool hasPromo) {
    return SliverPersistentHeader(
      pinned: true,
      delegate: SmPinnedHeader(
        height: 94,
        child: SmDeptRail(
          items: _railItems(hasPromo),
          selectedId: _railId,
          onSelect: _selectRail,
        ),
      ),
    );
  }

  Widget _productGrid(List<SupermarketProduct> list) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 0),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          mainAxisExtent: 256,
        ),
        delegate: SliverChildBuilderDelegate(
          (_, i) => SmProductCard(
            product: list[i],
            added: _added,
            onTap: _openQuickView,
            onAdd: (p) => _addToCart(p),
          ),
          childCount: list.length,
        ),
      ),
    );
  }

  List<Widget> _slivers(Map<String, dynamic> shop, Map<String, List<SupermarketProduct>> byDept, bool hasPromo) {
    final out = <Widget>[];
    const bottomPad = SliverToBoxAdapter(child: SizedBox(height: 120));

    // ---- MODE RECHERCHE ----------------------------------------------------
    if (_query.isNotEmpty) {
      final res = _computeResults();
      out.add(SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
          child: Row(
            children: [
              const Icon(Icons.search_rounded, size: 18, color: SmColors.blue),
              const SizedBox(width: 6),
              Expanded(
                child: Text('${res.length} résultat(s) pour « $_query »',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: SmColors.ink)),
              ),
              TextButton(
                onPressed: _clearSearch,
                child: const Text('Effacer', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
        ),
      ));
      if (res.isEmpty) {
        out.add(const SliverToBoxAdapter(
          child: SmEmpty(icon: Icons.search_off_rounded, text: 'Aucun produit trouvé'),
        ));
      } else {
        out.add(SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (_, i) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: SmResultTile(
                  product: res[i],
                  location: _locate(res[i]),
                  added: _added,
                  onTap: _openQuickView,
                  onAdd: (p) => _addToCart(p),
                ),
              ),
              childCount: res.length,
            ),
          ),
        ));
      }
      out.add(bottomPad);
      return out;
    }

    // ---- MODE ACCUEIL ------------------------------------------------------
    if (_railId == kSmAll) {
      out.add(SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.only(top: 16),
          child: SizedBox(
            height: 184,
            child: SmPromoHero(
              products: _all,
              storeName: shop['name']?.toString() ?? '',
              added: _added,
              onTap: _openQuickView,
              onAdd: (p) => _addToCart(p),
            ),
          ),
        ),
      ));
      out.add(SliverToBoxAdapter(
        child: SmStatsStrip(stats: [
          SmStat(value: '${_depts.length}', label: 'Rayons', icon: Icons.category_rounded, color: SmColors.blue),
          SmStat(value: '${_all.length}', label: 'Produits', icon: Icons.inventory_2_rounded, color: SmColors.sky),
          SmStat(
            value: '${_all.where((p) => smStockOf(p) > 0).length}',
            label: 'Disponibles',
            icon: Icons.check_circle_rounded,
            color: SmColors.green,
          ),
        ]),
      ));
      out.add(_pinnedRail(hasPromo));

      final sections = <int>[];
      for (var i = 0; i < _depts.length; i++) {
        if ((byDept['${_depts[i].id}'] ?? const <SupermarketProduct>[]).isNotEmpty) sections.add(i);
      }

      if (sections.isEmpty) {
        out.add(const SliverToBoxAdapter(
          child: SmEmpty(icon: Icons.inventory_2_outlined, text: 'Rayons en réapprovisionnement'),
        ));
      } else {
        out.add(SliverList(
          delegate: SliverChildBuilderDelegate(
            (ctx, i) {
              final di = sections[i];
              final d = _depts[di];
              final list = byDept['${d.id}']!;
              final shown = list.length < 12 ? list.length : 12;
              final extra = list.length - shown;
              final zone = smZoneOf(d.name);
              return Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SmSectionHeader(
                      title: d.name,
                      subtitle: 'Rayon ${di + 1} · ${list.length} produit(s)',
                      icon: d.icon,
                      color: d.color,
                      tag: smZoneTag(zone),
                      tagColor: smZoneColor(zone),
                      onTap: () => _openDepartment(d, di + 1),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 256,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        itemCount: shown + (extra > 0 ? 1 : 0),
                        separatorBuilder: (_, __) => const SizedBox(width: 10),
                        itemBuilder: (_, k) {
                          if (k >= shown) {
                            return SmSeeAllTile(
                              color: d.color,
                              remaining: extra,
                              onTap: () => _openDepartment(d, di + 1),
                            );
                          }
                          return SizedBox(
                            width: 156,
                            child: SmProductCard(
                              product: list[k],
                              added: _added,
                              onTap: _openQuickView,
                              onAdd: (p) => _addToCart(p),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
            childCount: sections.length,
          ),
        ));
      }
      out.add(bottomPad);
      return out;
    }

    // ---- MODE PROMOS -------------------------------------------------------
    out.add(_pinnedRail(hasPromo));
    if (_railId == kSmPromo) {
      final promos = _all.where((p) => p.onPromo && smStockOf(p) > 0).take(60).toList();
      out.add(SliverToBoxAdapter(
        child: SmBanner(
          title: 'Promotions du moment',
          subtitle: '${promos.length} offre(s) à saisir',
          icon: Icons.local_fire_department_rounded,
          color: SmColors.red,
        ),
      ));
      if (promos.isEmpty) {
        out.add(const SliverToBoxAdapter(
          child: SmEmpty(icon: Icons.local_offer_outlined, text: 'Aucune promotion en ce moment'),
        ));
      } else {
        out.add(_productGrid(promos));
      }
      out.add(bottomPad);
      return out;
    }

    // ---- MODE RAYON --------------------------------------------------------
    final idx = _depts.indexWhere((d) => '${d.id}' == _railId);
    if (idx < 0) {
      out.add(bottomPad);
      return out;
    }
    final dept = _depts[idx];
    final list = byDept[_railId] ?? const <SupermarketProduct>[];
    final zone = smZoneOf(dept.name);
    final tag = smZoneTag(zone);

    out.add(SliverToBoxAdapter(
      child: SmBanner(
        title: dept.name,
        subtitle: 'Rayon ${idx + 1} · ${list.length} produit(s)${tag == null ? '' : ' · $tag'}',
        icon: dept.icon,
        color: dept.color,
        actionLabel: 'Ouvrir',
        onAction: () => _openDepartment(dept, idx + 1),
      ),
    ));
    if (list.isEmpty) {
      out.add(const SliverToBoxAdapter(
        child: SmEmpty(icon: Icons.inventory_2_outlined, text: 'Rayon en réapprovisionnement'),
      ));
    } else {
      out.add(_productGrid(list));
    }
    out.add(bottomPad);
    return out;
  }
}
