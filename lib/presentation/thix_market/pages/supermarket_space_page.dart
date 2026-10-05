// lib/presentation/thix_market/pages/supermarket_space_page.dart
// ============================================================================
// SUPERMARCHÉ 3D — Production Enterprise v5
// ----------------------------------------------------------------------------
//  • Entrée par portes vitrées coulissantes
//  • Barre du haut "HUD" (nom, détails, position) + fiche magasin
//  • Bannière hero des promotions (auto-défilement, repliable)
//  • Étagères collées au mur, plafond + spots visibles au-dessus
//  • Allées en pseudo-3D (perspective Matrix4 — léger pour le CPU/GPU)
//  • Étages + ascenseur, mini-plan, recherche "téléportation"
//  • Rayons Frais / Surgelés / Boissons avec portes vitrées qui s'ouvrent
//  • Produits déjà affichés + bouton Panier
// ============================================================================
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show PointMode;

import 'package:barcode_widget/barcode_widget.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/l10n/app_localizations.dart';
import 'package:thix_id/presentation/thix_market/cart/cart_provider.dart' show cartProvider;
import 'package:thix_id/presentation/thix_market/models/supermarket_models.dart';
import 'package:thix_id/presentation/thix_market/providers/market_providers.dart' show supabaseClientProvider;
import 'package:thix_id/presentation/thix_market/providers/supermarket_providers.dart';

import 'department_products_page.dart';

// ============================================================================
// CONSTANTES
// ============================================================================
const Color _kRailRed = Color(0xFFD93025);
const Color _kRailRedDark = Color(0xFFB3261E);
const Color _kWood = Color(0xFF9A7B52);
const Color _kWoodDark = Color(0xFF7A5D3A);
const Color _kMetalWhite = Color(0xFFFAFAFA);
const Color _kMetalEdge = Color(0xFFE3E6EA);
const Color _kMeshWire = Color(0xFFC9CED6);
const Color _kPerfDot = Color(0xFFD5DAE0);

const double _kViewport = 0.86;
const double _kLevelH = 142;
const double _kRailH = 22;
const double _kSignH = 96;
const double _kDoorH = 28 + _kLevelH * 2 + 3 + 6;
const double _kDoorGap = 14;
const double _kHeroH = 108;
const double _kCeilH = 44; // hauteur du plafond (spots visibles ici)
const int _kCols = 3;
const int _kFloorSize = 4;
const Duration _kDbTimeout = Duration(seconds: 15);

// ============================================================================
// HELPERS
// ============================================================================
String _tr(AppLocalizations l10n, String key, String fb) {
  final v = l10n.t(key);
  return (v.isEmpty || v == key) ? fb : v;
}

String _fold(String s) {
  const from = 'àâäéèêëîïôöùûüç';
  const to = 'aaaeeeeiioouuuc';
  var out = s.toLowerCase();
  for (var i = 0; i < from.length; i++) {
    out = out.replaceAll(from[i], to[i]);
  }
  return out;
}

bool _word(String n, String w) => RegExp('(^|[^a-z])$w([^a-z]|\$)').hasMatch(n);

int _stockOf(SupermarketProduct p) => ((p.stock as num?) ?? 0).toInt();

/// Sur le web on laisse le navigateur décoder l'image à sa taille réelle
/// (évite certains rendus noirs) ; sur mobile on réduit pour économiser la mémoire.
int? _memW(int w) => kIsWeb ? null : w;

String _fmtDate(dynamic v) {
  if (v == null) return '—';
  final s = v.toString();
  try {
    final d = DateTime.parse(s);
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  } catch (_) {
    return s;
  }
}

String _floorName(int i) => i == 0 ? 'RDC' : 'Étage $i';
String _floorShort(int i) => i == 0 ? 'RDC' : '$i';

extension _ProductX on SupermarketProduct {
  String get pid => id.toString();
}

enum _ZoneType { standard, produce, fresh, frozen, drinks }

_ZoneType _zoneOf(String name) {
  final n = _fold(name);
  if (n.contains('surg') || n.contains('glac') || n.contains('frozen')) {
    return _ZoneType.frozen;
  }
  const drinks = [
    'boisson', 'drink', 'soda', 'biere', 'beverage', 'alcool',
    'liqueur', 'cocktail', 'limonade', 'brasserie', 'sirop',
  ];
  for (final k in drinks) {
    if (n.contains(k)) return _ZoneType.drinks;
  }
  if (_word(n, 'eau') || _word(n, 'eaux') || _word(n, 'jus') || _word(n, 'vin') || _word(n, 'vins')) {
    return _ZoneType.drinks;
  }
  const fresh = [
    'frais', 'lait', 'cremerie', 'boucher', 'viande', 'poisson',
    'charcut', 'traiteur', 'fromage', 'yaourt', 'oeuf',
  ];
  for (final k in fresh) {
    if (n.contains(k)) return _ZoneType.fresh;
  }
  const produce = ['fruit', 'legum', 'boulang', 'pain', 'patiss', 'primeur'];
  for (final k in produce) {
    if (n.contains(k)) return _ZoneType.produce;
  }
  return _ZoneType.standard;
}

bool _isCooler(_ZoneType z) =>
    z == _ZoneType.frozen || z == _ZoneType.fresh || z == _ZoneType.drinks;

String _zoneTagline(_ZoneType z) {
  switch (z) {
    case _ZoneType.frozen:
      return 'SURGELÉS · -18°C';
    case _ZoneType.fresh:
      return 'PRODUITS FRAIS · +4°C';
    case _ZoneType.drinks:
      return 'BOISSONS FRAÎCHES · +2°C';
    case _ZoneType.produce:
      return 'FRAIS DU JOUR';
    case _ZoneType.standard:
      return 'RAYON';
  }
}

String _zoneTemp(_ZoneType z) {
  switch (z) {
    case _ZoneType.frozen:
      return '-18°C';
    case _ZoneType.drinks:
      return '+2°C';
    default:
      return '+4°C';
  }
}

Color _zoneAccent(_ZoneType z) {
  switch (z) {
    case _ZoneType.frozen:
      return const Color(0xFF0277BD);
    case _ZoneType.drinks:
      return const Color(0xFF00838F);
    default:
      return const Color(0xFF2E7D32);
  }
}

List<Color> _zoneInterior(_ZoneType z) {
  switch (z) {
    case _ZoneType.frozen:
      return const [Color(0xFFE1F5FE), Color(0xFFB3E5FC)];
    case _ZoneType.drinks:
      return const [Color(0xFFE0F7FA), Color(0xFFB2EBF2)];
    default:
      return const [Color(0xFFE8F5E9), Color(0xFFC8E6C9)];
  }
}

List<Color> _zoneGlass(_ZoneType z) {
  switch (z) {
    case _ZoneType.frozen:
      return const [Color(0xC7E3F2FD), Color(0xBFB3E5FC)];
    case _ZoneType.drinks:
      return const [Color(0xC7E0F7FA), Color(0xBFB2EBF2)];
    default:
      return const [Color(0xC7E8F5E9), Color(0xBFC8E6C9)];
  }
}

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

  PageController _pageCtrl = PageController(viewportFraction: _kViewport);
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

  // ── Feedback ──────────────────────────────────────────────────────────
  void _toast(String msg, {bool error = false, bool cart = false}) {
    if (!mounted) return;
    final m = ScaffoldMessenger.of(context);
    m.hideCurrentSnackBar();
    m.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 96),
        backgroundColor: error ? ThixPolicy.danger : ThixPolicy.success,
        duration: const Duration(seconds: 3),
        content: Row(children: [
          Icon(error ? Icons.error_outline_rounded : Icons.check_circle_rounded,
              color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(msg, maxLines: 2, overflow: TextOverflow.ellipsis)),
        ]),
        action: cart
            ? SnackBarAction(
                label: 'Voir',
                textColor: Colors.white,
                onPressed: () => context.push('/market/cart'),
              )
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

  // ── Panier ────────────────────────────────────────────────────────────
  Future<void> _loadCartCount() async {
    try {
      final db = ref.read(supabaseClientProvider);
      final uid = db.auth.currentUser?.id;
      if (uid == null) return;
      final res = await db
          .from('cart')
          .select('quantity')
          .eq('user_id', uid)
          .timeout(_kDbTimeout);
      var n = 0;
      for (final row in (res as List)) {
        n += ((row as Map)['quantity'] as num?)?.toInt() ?? 0;
      }
      if (mounted) _cartCount.value = n;
    } catch (e) {
      debugPrint('[SupermarketSpace] ⚠️ cart count error: $e');
    }
  }

  Future<void> _addToCart(SupermarketProduct p) async {
    final pid = p.pid;
    if (_busy.contains(pid)) return;

    final stock = _stockOf(p);
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
          .timeout(_kDbTimeout);

      if (existing != null) {
        final cur = (existing['quantity'] as num?)?.toInt() ?? 0;
        if (cur + 1 > stock) {
          _toast('Stock limité à $stock (déjà $cur dans le panier)', error: true);
          return;
        }
        await db
            .from('cart')
            .update({'quantity': cur + 1})
            .eq('id', existing['id'])
            .timeout(_kDbTimeout);
      } else {
        await db
            .from('cart')
            .insert({'user_id': uid, 'product_id': pid, 'quantity': 1})
            .timeout(_kDbTimeout);
      }

      ref.invalidate(cartProvider);
      _cartCount.value += 1;
      _markAdded(pid);
      _toast('${p.title} ajouté au panier', cart: true);
    } catch (e) {
      debugPrint('[SupermarketSpace] ❌ addToCart error: $e');
      _toast('Impossible d\'ajouter au panier. Réessayez.', error: true);
    } finally {
      _busy.remove(pid);
    }
  }

  // ── Navigation dans le magasin ────────────────────────────────────────
  PageController _newCtrl(int initial) =>
      PageController(viewportFraction: _kViewport, initialPage: initial);

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
    await _changeFloor(deptIdx ~/ _kFloorSize, aisle: deptIdx % _kFloorSize);
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
    _setHighlight(p.pid);
    await _goToIndex(idx);
  }

  void _openQuickView(SupermarketProduct p) {
    HapticFeedback.selectionClick();
    final l10n = AppLocalizations.of(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ProductQuickView(
        product: p,
        l10n: l10n,
        onAdd: () => _addToCart(p),
      ),
    );
  }

  // ── Fiche du magasin ──────────────────────────────────────────────────
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
    final floors = math.max(1, (_depts.length / _kFloorSize).ceil());

    Widget line(IconData icon, String text) => Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 18, color: ThixPolicy.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(text,
                    style: const TextStyle(
                        fontSize: 13,
                        height: 1.4,
                        fontWeight: FontWeight.w600,
                        color: ThixPolicy.textMain)),
              ),
            ],
          ),
        );

    Widget stat(String value, String label) => Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: ThixPolicy.surfaceSoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Text(value,
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w900, color: ThixPolicy.primary)),
                Text(label,
                    style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: ThixPolicy.textMuted)),
              ],
            ),
          ),
        );

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                        color: ThixPolicy.border, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: ThixPolicy.surfaceSoft,
                        shape: BoxShape.circle,
                        border: Border.all(color: ThixPolicy.border),
                      ),
                      child: ClipOval(
                        child: (logo != null && logo.isNotEmpty)
                            ? CachedNetworkImage(
                                imageUrl: logo,
                                fit: BoxFit.cover,
                                memCacheWidth: _memW(160),
                                errorWidget: (_, __, ___) => const Icon(
                                    Icons.storefront_rounded,
                                    color: ThixPolicy.primary),
                              )
                            : const Icon(Icons.storefront_rounded,
                                color: ThixPolicy.primary, size: 26),
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
                              style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: ThixPolicy.textMain)),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Container(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: (isOpen ? ThixPolicy.success : ThixPolicy.danger)
                                      .withOpacity(0.14),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(isOpen ? 'OUVERT' : 'FERMÉ',
                                    style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 0.6,
                                        color: isOpen
                                            ? ThixPolicy.success
                                            : ThixPolicy.danger)),
                              ),
                              if (rating > 0) ...[
                                const SizedBox(width: 8),
                                const Icon(Icons.star_rounded,
                                    size: 14, color: ThixPolicy.gold),
                                const SizedBox(width: 2),
                                Text(rating.toStringAsFixed(1),
                                    style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                        color: ThixPolicy.gold)),
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

  // ── Recherche ─────────────────────────────────────────────────────────
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
      return _all.where((p) => p.onPromo && _stockOf(p) > 0).take(40).toList();
    }
    final q = _fold(_query);
    if (q.isEmpty) return const <SupermarketProduct>[];
    final out = <SupermarketProduct>[];
    for (final p in _all) {
      final title = _foldCache.putIfAbsent(p.pid, () => _fold(p.title));
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
    return 'Allée ${idx + 1} · ${_depts[idx].name} · ${_floorName(idx ~/ _kFloorSize)}';
  }

  // ========================================================================
  // BUILD
  // ========================================================================
  @override
  Widget build(BuildContext context) {
    final shopAsync = ref.watch(supermarketDetailsProvider(widget.supermarketId));
    final deptsAsync = ref.watch(departmentsProvider(widget.supermarketId));
    final productsAsync = ref.watch(supermarketShelfProductsProvider(widget.supermarketId));

    return Scaffold(
      backgroundColor: const Color(0xFFEAF0F8),
      body: shopAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (shop) {
          if (shop == null) {
            return const Center(child: Text('Supermarché introuvable'));
          }

          _depts = deptsAsync.valueOrNull ?? <SupermarketDepartment>[];
          final raw = productsAsync.valueOrNull ?? <SupermarketProduct>[];
          _all = (raw as List).cast<SupermarketProduct>();

          final floorCount = math.max(1, (_depts.length / _kFloorSize).ceil());
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
          final start = _floor * _kFloorSize;
          final end = math.min(start + _kFloorSize, _depts.length);
          final floorDepts = _depts.isEmpty
              ? const <SupermarketDepartment>[]
              : _depts.sublist(start, end);

          final body = SafeArea(
            bottom: false,
            child: Column(
              children: [
                _topBar(shop),
                ClipRect(
                  child: AnimatedSize(
                    duration: const Duration(milliseconds: 260),
                    curve: Curves.easeOutCubic,
                    alignment: Alignment.topCenter,
                    child: SizedBox(
                      width: double.infinity,
                      height: heroOn ? _kHeroH + 6 : 0,
                      child: heroOn
                          ? _PromoHero(
                              products: _all,
                              storeName: shop['name']?.toString() ?? '',
                              added: _added,
                              onGo: _goToProduct,
                              onAdd: _addToCart,
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
                      // 1) Mur + sol
                      const Positioned.fill(
                        child: RepaintBoundary(
                          child: CustomPaint(painter: _BackdropPainter()),
                        ),
                      ),
                      // 2) Étagères collées au mur
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
                      // 3) Plafond + spots PAR-DESSUS les étagères (non cliquable)
                      const Positioned.fill(
                        child: IgnorePointer(
                          child: RepaintBoundary(
                            child: CustomPaint(painter: _CeilingPainter()),
                          ),
                        ),
                      ),
                      // 4) HUD
                      Positioned(
                        left: 12,
                        right: 12,
                        bottom: 12 + MediaQuery.of(context).padding.bottom,
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
                                  duration: const Duration(milliseconds: 550),
                                  curve: Curves.easeInOutCubic);
                            }
                          },
                          onUp: () => _changeFloor(_floor + 1),
                          onDown: () => _changeFloor(_floor - 1),
                          onCart: () => context.push('/market/cart'),
                        ),
                      ),
                      // 5) Résultats de recherche
                      if (panelOpen)
                        Positioned.fill(
                          child: _ResultsPanel(
                            promo: _promoMode,
                            results: _computeResults(),
                            locate: _locate,
                            onGo: _goToProduct,
                            onAdd: _addToCart,
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
                      onSkip: () => _entry.animateTo(1,
                          duration: const Duration(milliseconds: 350)),
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

  // ── Aisles (PageView 3D) ──────────────────────────────────────────────
  Widget _buildAisles(
    List<SupermarketDepartment> floorDepts,
    int start,
    Map<String, List<SupermarketProduct>> byDept,
  ) {
    if (floorDepts.isEmpty) {
      return const Center(
        child: Text('Aucun rayon pour le moment',
            style: TextStyle(color: ThixPolicy.textSecondary, fontWeight: FontWeight.w700)),
      );
    }
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        // Le hero se replie quand on descend dans une allée
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
          final products = byDept[dept.id] ?? const <SupermarketProduct>[];
          return _AisleCarouselItem(
            controller: _pageCtrl,
            index: i,
            child: _AislePage(
              dept: dept,
              aisleNumber: globalNo,
              products: products,
              zone: _zoneOf(dept.name),
              highlight: _highlight,
              added: _added,
              onTapProduct: _openQuickView,
              onAdd: _addToCart,
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

  // ── Barre du haut (HUD) ───────────────────────────────────────────────
  Widget _topBar(Map<String, dynamic> shop) {
    final name = shop['name']?.toString() ?? '';
    final city = shop['city']?.toString() ?? '';
    final logo = shop['logo_url']?.toString();
    final rating = (shop['rating'] as num?)?.toDouble() ?? 0;
    final isOpen = (shop['is_open'] as bool?) ?? true;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _showShopInfo(shop),
        child: Container(
          padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.94),
            borderRadius: BorderRadius.circular(24),
            boxShadow: ThixPolicy.shadowSoft(opacity: 0.12),
          ),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.of(context).maybePop(),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: ThixPolicy.surfaceSoft,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.arrow_back_ios_new_rounded,
                      size: 16, color: ThixPolicy.textMain),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: ThixPolicy.border),
                ),
                child: ClipOval(
                  child: (logo != null && logo.isNotEmpty)
                      ? CachedNetworkImage(
                          imageUrl: logo,
                          fit: BoxFit.cover,
                          memCacheWidth: _memW(120),
                          errorWidget: (_, __, ___) => const Icon(
                              Icons.storefront_rounded,
                              size: 20,
                              color: ThixPolicy.primary),
                        )
                      : const Icon(Icons.storefront_rounded,
                          size: 20, color: ThixPolicy.primary),
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
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: ThixPolicy.textMain)),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          margin: const EdgeInsets.only(right: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: (isOpen ? ThixPolicy.success : ThixPolicy.danger)
                                .withOpacity(0.14),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(isOpen ? 'OUVERT' : 'FERMÉ',
                              style: TextStyle(
                                  fontSize: 8,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.6,
                                  color:
                                      isOpen ? ThixPolicy.success : ThixPolicy.danger)),
                        ),
                        const Icon(Icons.place_rounded,
                            size: 11, color: ThixPolicy.textMuted),
                        const SizedBox(width: 2),
                        Flexible(
                          child: Text(city,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 11, color: ThixPolicy.textSecondary)),
                        ),
                        if (rating > 0) ...[
                          const SizedBox(width: 6),
                          const Icon(Icons.star_rounded, size: 12, color: ThixPolicy.gold),
                          Text(rating.toStringAsFixed(1),
                              style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: ThixPolicy.gold)),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    ValueListenableBuilder<int>(
                      valueListenable: _aisle,
                      builder: (_, a, __) {
                        final idx = _floor * _kFloorSize + a;
                        final deptName =
                            (idx >= 0 && idx < _depts.length) ? _depts[idx].name : '';
                        final text = deptName.isEmpty
                            ? _floorName(_floor)
                            : '${_floorName(_floor)} · Allée ${idx + 1} · $deptName';
                        return Row(
                          children: [
                            const Icon(Icons.navigation_rounded,
                                size: 10, color: ThixPolicy.primary),
                            const SizedBox(width: 3),
                            Flexible(
                              child: Text(text,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      color: ThixPolicy.primary)),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.info_outline_rounded,
                  size: 20, color: ThixPolicy.textMuted),
            ],
          ),
        ),
      ),
    );
  }

  Widget _searchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: ThixPolicy.shadowSoft(),
        ),
        child: TextField(
          controller: _searchCtrl,
          focusNode: _focus,
          textInputAction: TextInputAction.search,
          onChanged: _onQuery,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            hintText: 'Chercher un produit (ex : Fanta, lait…)',
            hintStyle: const TextStyle(fontSize: 13, color: ThixPolicy.textMuted),
            prefixIcon:
                const Icon(Icons.search_rounded, size: 20, color: ThixPolicy.textSecondary),
            suffixIcon: (_query.isNotEmpty || _promoMode)
                ? IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18),
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
    final zoneFirst = <_ZoneType, int>{};
    for (var i = 0; i < _depts.length; i++) {
      zoneFirst.putIfAbsent(_zoneOf(_depts[i].name), () => i);
    }
    final hasPromo = _all.any((p) => p.onPromo);

    final chips = <Widget>[
      if (hasPromo)
        _QuickChip(
          label: 'Promos',
          icon: Icons.local_fire_department_rounded,
          color: _kRailRed,
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
      if (zoneFirst.containsKey(_ZoneType.drinks))
        _QuickChip(
          label: 'Boissons',
          icon: Icons.local_drink_rounded,
          color: const Color(0xFF00838F),
          onTap: () => _goToIndex(zoneFirst[_ZoneType.drinks]!),
        ),
      if (zoneFirst.containsKey(_ZoneType.frozen))
        _QuickChip(
          label: 'Surgelés',
          icon: Icons.ac_unit_rounded,
          color: const Color(0xFF0288D1),
          onTap: () => _goToIndex(zoneFirst[_ZoneType.frozen]!),
        ),
      if (zoneFirst.containsKey(_ZoneType.fresh))
        _QuickChip(
          label: 'Frais',
          icon: Icons.kitchen_rounded,
          color: const Color(0xFF2E7D32),
          onTap: () => _goToIndex(zoneFirst[_ZoneType.fresh]!),
        ),
      if (zoneFirst.containsKey(_ZoneType.produce))
        _QuickChip(
          label: 'Primeur',
          icon: Icons.eco_rounded,
          color: const Color(0xFF8D6E63),
          onTap: () => _goToIndex(zoneFirst[_ZoneType.produce]!),
        ),
    ];
    if (chips.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: chips.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) => chips[i],
      ),
    );
  }
}

// ============================================================================
// BANNIÈRE HERO — PRODUITS EN PROMOTION
// ============================================================================
class _PromoHero extends StatefulWidget {
  final List<SupermarketProduct> products;
  final String storeName;
  final ValueNotifier<Set<String>> added;
  final ValueChanged<SupermarketProduct> onGo;
  final ValueChanged<SupermarketProduct> onAdd;

  const _PromoHero({
    required this.products,
    required this.storeName,
    required this.added,
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
    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      final n = _items().length;
      if (!mounted || n <= 1 || !_ctrl.hasClients) return;
      if (DateTime.now().isBefore(_resumeAt)) return;
      final next = (_index + 1) % n;
      _ctrl.animateToPage(next,
          duration: const Duration(milliseconds: 600), curve: Curves.easeOutCubic);
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
      for (final p in widget.products)
        if (p.onPromo && _stockOf(p) > 0) p,
    ];
    if (promos.isNotEmpty) return promos.take(6).toList();

    final featured = <SupermarketProduct>[
      for (final p in widget.products)
        if ((p.isFeatured || p.rating >= 4.5) && _stockOf(p) > 0) p,
    ];
    if (featured.isNotEmpty) return featured.take(4).toList();

    return <SupermarketProduct>[
      for (final p in widget.products)
        if (p.hasPhotos && _stockOf(p) > 0) p,
    ].take(4).toList();
  }

  @override
  Widget build(BuildContext context) {
    final items = _items();
    if (_index >= items.length && items.isNotEmpty) _index = 0;

    if (items.isEmpty) {
      return _welcome();
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n.metrics.axis == Axis.horizontal &&
            ((n is ScrollStartNotification && n.dragDetails != null) ||
                (n is ScrollUpdateNotification && n.dragDetails != null))) {
          _resumeAt = DateTime.now().add(const Duration(seconds: 3));
        }
        return false;
      },
      child: Stack(
        children: [
          PageView.builder(
            controller: _ctrl,
            itemCount: items.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (_, i) => _tile(items[i]),
          ),
          if (items.length > 1)
            Positioned(
              top: 12,
              right: 26,
              child: Row(
                children: List<Widget>.generate(items.length, (i) {
                  final on = i == _index;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    width: on ? 14 : 5,
                    height: 5,
                    decoration: BoxDecoration(
                      color: on ? Colors.white : Colors.white.withOpacity(0.45),
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
      margin: const EdgeInsets.fromLTRB(16, 2, 16, 6),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [ThixPolicy.primaryDeep, ThixPolicy.primary],
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: ThixPolicy.shadowSoft(opacity: 0.14),
      ),
      child: Row(
        children: [
          const Icon(Icons.storefront_rounded, color: Colors.white, size: 34),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.storeName.isEmpty ? 'Bienvenue' : 'Bienvenue chez ${widget.storeName}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 3),
                Text('Parcourez les rayons comme en magasin',
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.85),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tile(SupermarketProduct p) {
    final promo = p.onPromo;

    return Container(
      margin: const EdgeInsets.fromLTRB(4, 2, 4, 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: ThixPolicy.shadowSoft(opacity: 0.16),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => widget.onGo(p),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (p.hasPhotos)
                CachedNetworkImage(
                  imageUrl: p.mainPhoto,
                  fit: BoxFit.cover,
                  memCacheWidth: _memW(700),
                  placeholder: (_, __) => Container(color: ThixPolicy.primaryDeep),
                  errorWidget: (_, __, ___) => Container(color: ThixPolicy.primaryDeep),
                )
              else
                Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [ThixPolicy.primaryDeep, ThixPolicy.primary],
                    ),
                  ),
                ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Colors.black.withOpacity(0.80),
                      Colors.black.withOpacity(0.28),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: promo ? _kRailRed : ThixPolicy.gold,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                    promo
                                        ? Icons.local_fire_department_rounded
                                        : Icons.star_rounded,
                                    size: 11,
                                    color: Colors.white),
                                const SizedBox(width: 3),
                                Text(
                                  promo ? 'PROMO -${p.promoPercent}%' : 'VEDETTE',
                                  style: const TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                      letterSpacing: 0.5),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            p.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 16,
                                height: 1.15,
                                fontWeight: FontWeight.w900,
                                color: Colors.white),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Text('${p.priceLabel()} ${p.currency}',
                                  style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white)),
                              if (promo) ...[
                                const SizedBox(width: 6),
                                Text('${p.price}',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.white.withOpacity(0.7),
                                        decoration: TextDecoration.lineThrough)),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        _heroBtn(Icons.near_me_rounded, () => widget.onGo(p)),
                        const SizedBox(height: 8),
                        ValueListenableBuilder<Set<String>>(
                          valueListenable: widget.added,
                          builder: (_, set, __) {
                            final done = set.contains(p.pid);
                            return _heroBtn(
                              done ? Icons.check_rounded : Icons.add_shopping_cart_rounded,
                              _stockOf(p) <= 0 ? null : () => widget.onAdd(p),
                              color: done ? ThixPolicy.success : ThixPolicy.primary,
                              filled: true,
                            );
                          },
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

  Widget _heroBtn(
    IconData icon,
    VoidCallback? onTap, {
    Color color = Colors.white,
    bool filled = false,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: filled ? color : Colors.white.withOpacity(0.2),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withOpacity(filled ? 0.0 : 0.6)),
        ),
        child: Icon(icon, size: 17, color: Colors.white),
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
                    Positioned(
                      left: -open * w / 2,
                      top: 0,
                      bottom: 0,
                      width: w / 2,
                      child: const _GlassDoor(left: true),
                    ),
                    Positioned(
                      right: -open * w / 2,
                      top: 0,
                      bottom: 0,
                      width: w / 2,
                      child: const _GlassDoor(left: false),
                    ),
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        padding: EdgeInsets.fromLTRB(20, topInset + 14, 20, 14),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [ThixPolicy.primaryDeep, ThixPolicy.primary],
                          ),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withOpacity(0.25),
                                blurRadius: 14,
                                offset: const Offset(0, 4)),
                          ],
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.storefront_rounded, color: Colors.white, size: 26),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                name.isEmpty ? 'Supermarché' : name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.3),
                              ),
                            ),
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: sensorOn ? const Color(0xFF69F0AE) : const Color(0xFFFF5252),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: (sensorOn ? const Color(0xFF69F0AE) : const Color(0xFFFF5252))
                                        .withOpacity(0.7),
                                    blurRadius: 8,
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
                      bottom: 70,
                      child: Opacity(
                        opacity: hint.clamp(0.0, 1.0),
                        child: const Center(
                          child: Text(
                            'Bienvenue — les portes s\'ouvrent…',
                            style: TextStyle(
                                color: ThixPolicy.primaryDeep,
                                fontSize: 14,
                                fontWeight: FontWeight.w800),
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
        border: Border(
          top: frame,
          bottom: frame,
          left: left ? frame : BorderSide.none,
          right: left ? BorderSide.none : frame,
        ),
      ),
      child: Stack(
        children: [
          Align(
            alignment: Alignment.center,
            child: Container(
              height: 46,
              color: Colors.white.withOpacity(0.35),
            ),
          ),
          Align(
            alignment: left ? Alignment.centerRight : Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Container(
                width: 8,
                height: 130,
                decoration: BoxDecoration(
                  color: const Color(0xFF546E7A),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// FOND DU MAGASIN : mur + sol (dessiné une seule fois)
// ============================================================================
class _BackdropPainter extends CustomPainter {
  const _BackdropPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final horizon = h * 0.80;

    // ── Mur (derrière les étagères) ──
    final wallRect = Rect.fromLTWH(0, 0, w, horizon);
    canvas.drawRect(
      wallRect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFE9EFF8), Color(0xFFD3DDEA)],
        ).createShader(wallRect),
    );

    // Joints des panneaux muraux
    final seam = Paint()
      ..color = Colors.white.withOpacity(0.35)
      ..strokeWidth = 1;
    for (var i = 1; i < 4; i++) {
      canvas.drawLine(Offset(w * i / 4, _kCeilH), Offset(w * i / 4, horizon), seam);
    }

    // Plinthe
    canvas.drawRect(
      Rect.fromLTWH(0, horizon - 6, w, 6),
      Paint()..color = const Color(0xFFB7C3D3),
    );

    // ── Sol ──
    final floorRect = Rect.fromLTWH(0, horizon, w, h - horizon);
    canvas.drawRect(
      floorRect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFD9E0EA), Color(0xFFBFC9D7)],
        ).createShader(floorRect),
    );

    canvas.save();
    canvas.clipRect(floorRect);
    final line = Paint()
      ..color = Colors.white.withOpacity(0.55)
      ..strokeWidth = 1;
    final vp = Offset(w / 2, horizon - (h - horizon) * 1.2);
    for (var i = -6; i <= 6; i++) {
      canvas.drawLine(vp, Offset(w / 2 + i * w * 0.22, h), line);
    }
    for (var k = 1; k <= 6; k++) {
      final y = horizon + (h - horizon) * math.pow(k / 6, 2).toDouble();
      canvas.drawLine(Offset(0, y), Offset(w, y), line);
    }
    canvas.restore();

    // Flaques de lumière au sol (sous chaque spot)
    for (final fx in const [0.14, 0.38, 0.62, 0.86]) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(w * fx, horizon + (h - horizon) * 0.38),
          width: w * 0.30,
          height: (h - horizon) * 0.46,
        ),
        Paint()..color = Colors.white.withOpacity(0.20),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Plafond + rail + spots : dessiné PAR-DESSUS les étagères.
class _CeilingPainter extends CustomPainter {
  const _CeilingPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Plafond opaque (les produits glissent dessous quand on défile)
    final ceilRect = Rect.fromLTWH(0, 0, w, _kCeilH);
    canvas.drawRect(
      ceilRect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFB8C4D3), Color(0xFFE6ECF4)],
        ).createShader(ceilRect),
    );
    final tile = Paint()
      ..color = const Color(0xFF90A4AE).withOpacity(0.18)
      ..strokeWidth = 1;
    for (var i = 1; i < 6; i++) {
      canvas.drawLine(Offset(w * i / 6, 0), Offset(w * i / 6, _kCeilH), tile);
    }
    canvas.drawRect(
      Rect.fromLTWH(0, _kCeilH - 2, w, 2),
      Paint()..color = const Color(0xFFAFBCCB),
    );

    // Ombre douce sous le plafond, sur le haut des étagères
    final shRect = Rect.fromLTWH(0, _kCeilH, w, 20);
    canvas.drawRect(
      shRect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.black.withOpacity(0.12), Colors.black.withOpacity(0.0)],
        ).createShader(shRect),
    );

    // Rail de projecteurs
    final railY = _kCeilH * 0.38;
    canvas.drawRect(
      Rect.fromLTWH(0, railY, w, 4),
      Paint()..color = const Color(0xFF78909C),
    );

    // Spots
    for (final fx in const [0.14, 0.38, 0.62, 0.86]) {
      final cx = w * fx;
      final cy = railY + 4;

      // Cône de lumière sur les étagères
      final coneBottom = h * 0.60;
      final coneRect = Rect.fromLTWH(cx - w * 0.16, cy, w * 0.32, coneBottom - cy);
      final cone = Path()
        ..moveTo(cx - 6, cy + 8)
        ..lineTo(cx + 6, cy + 8)
        ..lineTo(cx + w * 0.16, coneBottom)
        ..lineTo(cx - w * 0.16, coneBottom)
        ..close();
      canvas.drawPath(
        cone,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.white.withOpacity(0.26), Colors.white.withOpacity(0.0)],
          ).createShader(coneRect),
      );

      // Tige + corps du projecteur
      canvas.drawRect(
        Rect.fromLTWH(cx - 1.5, cy, 3, 5),
        Paint()..color = const Color(0xFF546E7A),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(cx, cy + 9), width: 16, height: 9),
          const Radius.circular(3),
        ),
        Paint()..color = const Color(0xFF37474F),
      );

      // Halo + lentille allumée
      final glowC = Offset(cx, cy + 14);
      canvas.drawCircle(
        glowC,
        18,
        Paint()
          ..shader = RadialGradient(
            colors: [Colors.white.withOpacity(0.9), Colors.white.withOpacity(0.0)],
          ).createShader(Rect.fromCircle(center: glowC, radius: 18)),
      );
      canvas.drawOval(
        Rect.fromCenter(center: Offset(cx, cy + 13.5), width: 10, height: 4),
        Paint()..color = Colors.white,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _PerfPainter extends CustomPainter {
  const _PerfPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final pts = <Offset>[];
    for (var y = 6.0; y < size.height; y += 9) {
      for (var x = 6.0; x < size.width; x += 9) {
        pts.add(Offset(x, y));
      }
    }
    canvas.drawPoints(
      PointMode.points,
      pts,
      Paint()
        ..color = _kPerfDot
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _MeshPainter extends CustomPainter {
  const _MeshPainter();

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

class _FrostPainter extends CustomPainter {
  const _FrostPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rnd = math.Random(7);
    final p = Paint()..color = Colors.white.withOpacity(0.55);
    for (var i = 0; i < 46; i++) {
      final edge = rnd.nextDouble();
      final x = i.isEven
          ? rnd.nextDouble() * size.width * 0.28
          : size.width - rnd.nextDouble() * size.width * 0.28;
      final y = edge * size.height;
      canvas.drawCircle(Offset(x, y), 0.8 + rnd.nextDouble() * 2.2, p);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ============================================================================
// ALLÉE EN PERSPECTIVE (coverflow 3D, GPU)
// ============================================================================
class _AisleCarouselItem extends StatelessWidget {
  final PageController controller;
  final int index;
  final Widget child;
  const _AisleCarouselItem({
    required this.controller,
    required this.index,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      child: RepaintBoundary(child: child),
      builder: (_, ch) {
        var current = controller.initialPage.toDouble();
        if (controller.hasClients && controller.position.haveDimensions) {
          current = controller.page ?? current;
        }
        final delta = (index - current).clamp(-1.5, 1.5);
        final angle = delta * 0.42;
        final scale = 1 - delta.abs() * 0.08;
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.0012)
            ..rotateY(angle)
            ..scale(scale, scale, 1.0),
          child: Opacity(opacity: (1 - delta.abs() * 0.25).clamp(0.4, 1.0), child: ch),
        );
      },
    );
  }
}

class _AislePage extends StatefulWidget {
  final SupermarketDepartment dept;
  final int aisleNumber;
  final List<SupermarketProduct> products;
  final _ZoneType zone;
  final ValueNotifier<String?> highlight;
  final ValueNotifier<Set<String>> added;
  final ValueChanged<SupermarketProduct> onTapProduct;
  final ValueChanged<SupermarketProduct> onAdd;
  final VoidCallback onOpenAisle;

  const _AislePage({
    required this.dept,
    required this.aisleNumber,
    required this.products,
    required this.zone,
    required this.highlight,
    required this.added,
    required this.onTapProduct,
    required this.onAdd,
    required this.onOpenAisle,
  });

  @override
  State<_AislePage> createState() => _AislePageState();
}

class _AislePageState extends State<_AislePage> {
  final ScrollController _scroll = ScrollController();

  bool get _cooler => _isCooler(widget.zone);
  int get _perUnit => _cooler ? _kCols * 2 : _kCols;
  double get _unitExtent => _cooler ? _kDoorH + _kDoorGap : _kLevelH + _kRailH;

  @override
  void initState() {
    super.initState();
    widget.highlight.addListener(_onHighlight);
    WidgetsBinding.instance.addPostFrameCallback((_) => _onHighlight());
  }

  @override
  void dispose() {
    widget.highlight.removeListener(_onHighlight);
    _scroll.dispose();
    super.dispose();
  }

  void _onHighlight() {
    final id = widget.highlight.value;
    if (id == null) return;
    final idx = widget.products.indexWhere((p) => p.pid == id);
    if (idx < 0) return;
    final unit = idx ~/ _perUnit;
    final target = _kSignH + unit * _unitExtent - 30;
    Future.delayed(const Duration(milliseconds: 650), () {
      if (!mounted || !_scroll.hasClients) return;
      _scroll.animateTo(
        target.clamp(0.0, _scroll.position.maxScrollExtent),
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final products = widget.products;
    final units = (products.length / _perUnit).ceil();
    final total = (units == 0 ? 1 : units) + 2;

    return ListView.builder(
      controller: _scroll,
      physics: const ClampingScrollPhysics(), // plus de vide au-dessus du panneau
      padding: const EdgeInsets.fromLTRB(2, _kCeilH, 2, 130), // collé sous le plafond
      itemCount: total,
      itemBuilder: (ctx, i) {
        if (i == 0) {
          return _AisleSign(
            dept: widget.dept,
            aisleNumber: widget.aisleNumber,
            count: products.length,
            zone: widget.zone,
            onTap: widget.onOpenAisle,
          );
        }
        if (i == total - 1) return const _FixtureBase();
        if (units == 0) return _EmptyAisle(color: widget.dept.color);

        final u = i - 1;
        final slice = products.skip(u * _perUnit).take(_perUnit).toList();

        if (_cooler) {
          return Padding(
            padding: const EdgeInsets.only(bottom: _kDoorGap),
            child: _CoolerDoor(
              products: slice,
              zone: widget.zone,
              highlight: widget.highlight,
              added: widget.added,
              onTapProduct: widget.onTapProduct,
              onAdd: widget.onAdd,
            ),
          );
        }

        final wood = widget.zone == _ZoneType.produce;
        return _GondolaLevel(
          products: slice,
          rail: wood ? _kWood : _kRailRed,
          railDark: wood ? _kWoodDark : _kRailRedDark,
          highlight: widget.highlight,
          added: widget.added,
          onTapProduct: widget.onTapProduct,
          onAdd: widget.onAdd,
        );
      },
    );
  }
}

// ============================================================================
// PANNEAU D'ALLÉE (fixé sur rail mural)
// ============================================================================
class _AisleSign extends StatelessWidget {
  final SupermarketDepartment dept;
  final int aisleNumber;
  final int count;
  final _ZoneType zone;
  final VoidCallback onTap;
  const _AisleSign({
    required this.dept,
    required this.aisleNumber,
    required this.count,
    required this.zone,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _kSignH,
      child: Column(
        children: [
          // Rail de fixation mural (le panneau est collé au mur)
          SizedBox(
            height: 14,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFB0BEC5), Color(0xFF78909C)],
                ),
                borderRadius: BorderRadius.vertical(top: Radius.circular(5)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (var i = 0; i < 2; i++)
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Color(0xFF455A64),
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: onTap,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [dept.color, dept.color.withOpacity(0.78)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: dept.color.withOpacity(0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.22),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text('ALLÉE $aisleNumber',
                          style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 0.8)),
                    ),
                    const SizedBox(width: 8),
                    Icon(dept.icon, size: 20, color: Colors.white),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(dept.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white)),
                          Text(_zoneTagline(zone),
                              style: TextStyle(
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white.withOpacity(0.85),
                                  letterSpacing: 0.6)),
                        ],
                      ),
                    ),
                    Text('$count',
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w900, color: Colors.white)),
                    const Icon(Icons.chevron_right_rounded, size: 18, color: Colors.white),
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

class _FixtureBase extends StatelessWidget {
  const _FixtureBase();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          height: 14,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: const BoxDecoration(
            color: Color(0xFF78909C),
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(6)),
          ),
        ),
        const SizedBox(height: 4),
        Container(
          height: 10,
          margin: const EdgeInsets.symmetric(horizontal: 26),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.10),
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ],
    );
  }
}

class _EmptyAisle extends StatelessWidget {
  final Color color;
  const _EmptyAisle({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 180,
      margin: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.8),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kMetalEdge),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory_2_outlined, size: 40, color: color.withOpacity(0.5)),
          const SizedBox(height: 8),
          const Text('Rayon en cours de réapprovisionnement',
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700, color: ThixPolicy.textSecondary)),
        ],
      ),
    );
  }
}

// ============================================================================
// GONDOLE (étagère ouverte)
// ============================================================================
class _GondolaLevel extends StatelessWidget {
  final List<SupermarketProduct> products;
  final Color rail;
  final Color railDark;
  final ValueNotifier<String?> highlight;
  final ValueNotifier<Set<String>> added;
  final ValueChanged<SupermarketProduct> onTapProduct;
  final ValueChanged<SupermarketProduct> onAdd;

  const _GondolaLevel({
    required this.products,
    required this.rail,
    required this.railDark,
    required this.highlight,
    required this.added,
    required this.onTapProduct,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _kLevelH + _kRailH,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(width: 10, child: CustomPaint(painter: _MeshPainter())),
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                color: _kMetalWhite,
                border: Border.symmetric(vertical: BorderSide(color: _kMetalEdge)),
              ),
              child: Stack(
                children: [
                  const Positioned.fill(child: CustomPaint(painter: _PerfPainter())),
                  Column(
                    children: [
                      SizedBox(
                        height: _kLevelH,
                        child: _SlotsRow(
                          products: products,
                          highlight: highlight,
                          added: added,
                          onTapProduct: onTapProduct,
                          onAdd: onAdd,
                        ),
                      ),
                      _Rail(color: rail, dark: railDark),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10, child: CustomPaint(painter: _MeshPainter())),
        ],
      ),
    );
  }
}

class _Rail extends StatelessWidget {
  final Color color;
  final Color dark;
  const _Rail({required this.color, required this.dark});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _kRailH,
      child: Stack(
        children: [
          Positioned(
            top: 0,
            left: 2,
            right: 2,
            height: 8,
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.white, Color(0xFFEDEFF2)],
                ),
                borderRadius: BorderRadius.circular(2),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.10),
                      blurRadius: 3,
                      offset: const Offset(0, 2)),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: 14,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [color, dark],
                ),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SlotsRow extends StatelessWidget {
  final List<SupermarketProduct> products;
  final ValueNotifier<String?> highlight;
  final ValueNotifier<Set<String>> added;
  final ValueChanged<SupermarketProduct> onTapProduct;
  final ValueChanged<SupermarketProduct> onAdd;

  const _SlotsRow({
    required this.products,
    required this.highlight,
    required this.added,
    required this.onTapProduct,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List<Widget>.generate(_kCols, (c) {
        if (c >= products.length) return const Expanded(child: SizedBox.shrink());
        return Expanded(
          child: _ProductSlot(
            product: products[c],
            highlight: highlight,
            added: added,
            onTap: onTapProduct,
            onAdd: onAdd,
          ),
        );
      }),
    );
  }
}

// ============================================================================
// FRIGO / CONGÉLATEUR / BOISSONS AVEC PORTE QUI S'OUVRE
// ============================================================================
class _CoolerDoor extends StatefulWidget {
  final List<SupermarketProduct> products;
  final _ZoneType zone;
  final ValueNotifier<String?> highlight;
  final ValueNotifier<Set<String>> added;
  final ValueChanged<SupermarketProduct> onTapProduct;
  final ValueChanged<SupermarketProduct> onAdd;

  const _CoolerDoor({
    required this.products,
    required this.zone,
    required this.highlight,
    required this.added,
    required this.onTapProduct,
    required this.onAdd,
  });

  @override
  State<_CoolerDoor> createState() => _CoolerDoorState();
}

class _CoolerDoorState extends State<_CoolerDoor> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
  bool _open = false;

  @override
  void initState() {
    super.initState();
    widget.highlight.addListener(_checkHighlight);
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkHighlight());
  }

  @override
  void dispose() {
    widget.highlight.removeListener(_checkHighlight);
    _ctrl.dispose();
    super.dispose();
  }

  void _checkHighlight() {
    final id = widget.highlight.value;
    if (id == null || _open) return;
    if (widget.products.any((p) => p.pid == id)) _setOpen(true);
  }

  void _setOpen(bool v) {
    if (!mounted || _open == v) return;
    HapticFeedback.mediumImpact();
    setState(() => _open = v);
    if (v) {
      _ctrl.forward();
    } else {
      _ctrl.reverse();
    }
  }

  List<SupermarketProduct> _row(int r) =>
      widget.products.skip(r * _kCols).take(_kCols).toList();

  Widget _tempChip(Color color) {
    final frozen = widget.zone == _ZoneType.frozen;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.85),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(frozen ? Icons.ac_unit_rounded : Icons.thermostat_rounded,
              size: 12, color: color),
          const SizedBox(width: 3),
          Text(_zoneTemp(widget.zone),
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: color)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accent = _zoneAccent(widget.zone);
    final interiorColors = _zoneInterior(widget.zone);
    final glassColors = _zoneGlass(widget.zone);

    final interior = Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: interiorColors,
        ),
      ),
      child: Column(
        children: [
          // En-tête avec bande LED
          Container(
            height: 28,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.white.withOpacity(0.95), Colors.white.withOpacity(0.0)],
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                children: [
                  _tempChip(accent),
                  const Spacer(),
                  AnimatedOpacity(
                    opacity: _open ? 1 : 0,
                    duration: const Duration(milliseconds: 250),
                    child: GestureDetector(
                      onTap: _open ? () => _setOpen(false) : null,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: accent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.close_rounded, size: 11, color: Colors.white),
                            SizedBox(width: 3),
                            Text('Fermer',
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(
            height: _kLevelH,
            child: _SlotsRow(
              products: _row(0),
              highlight: widget.highlight,
              added: widget.added,
              onTapProduct: widget.onTapProduct,
              onAdd: widget.onAdd,
            ),
          ),
          Container(height: 3, color: Colors.white.withOpacity(0.85)),
          SizedBox(
            height: _kLevelH,
            child: _SlotsRow(
              products: _row(1),
              highlight: widget.highlight,
              added: widget.added,
              onTapProduct: widget.onTapProduct,
              onAdd: widget.onAdd,
            ),
          ),
        ],
      ),
    );

    final doorPanel = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _setOpen(true),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: glassColors,
          ),
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: Colors.white.withOpacity(0.9), width: 2),
        ),
        child: Stack(
          children: [
            const Positioned.fill(child: CustomPaint(painter: _FrostPainter())),
            Positioned(top: 8, left: 10, child: _tempChip(accent)),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.touch_app_rounded, size: 34, color: accent.withOpacity(0.85)),
                  const SizedBox(height: 4),
                  Text('Appuyer pour ouvrir',
                      style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w900, color: accent)),
                ],
              ),
            ),
            Positioned(
              right: 8,
              top: 0,
              bottom: 0,
              child: Center(
                child: Container(
                  width: 6,
                  height: 90,
                  decoration: BoxDecoration(
                    color: const Color(0xFF607D8B),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    return SizedBox(
      height: _kDoorH,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFCFD8E3),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF90A4AE), width: 3),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: ClipRRect(borderRadius: BorderRadius.circular(11), child: interior),
            ),
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _ctrl,
                child: doorPanel,
                builder: (_, child) {
                  final t = Curves.easeInOutCubic.transform(_ctrl.value);
                  return IgnorePointer(
                    ignoring: _open,
                    child: Opacity(
                      opacity: (1 - (t - 0.8).clamp(0.0, 0.2) * 3).clamp(0.0, 1.0),
                      child: Transform(
                        alignment: Alignment.centerLeft,
                        transform: Matrix4.identity()
                          ..setEntry(3, 2, 0.0008)
                          ..rotateY(-t * 1.2),
                        child: child,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// PRODUIT SUR L'ÉTAGÈRE (déjà affiché + bouton Panier)
// ============================================================================
class _ProductSlot extends StatelessWidget {
  final SupermarketProduct product;
  final ValueNotifier<String?> highlight;
  final ValueNotifier<Set<String>> added;
  final ValueChanged<SupermarketProduct> onTap;
  final ValueChanged<SupermarketProduct> onAdd;

  const _ProductSlot({
    required this.product,
    required this.highlight,
    required this.added,
    required this.onTap,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final p = product;
    final out = _stockOf(p) <= 0;

    return ValueListenableBuilder<String?>(
      valueListenable: highlight,
      builder: (_, hl, child) {
        final on = hl == p.pid;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: on ? ThixPolicy.gold.withOpacity(0.14) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: on ? ThixPolicy.gold : Colors.transparent, width: 2),
            boxShadow: on
                ? [BoxShadow(color: ThixPolicy.gold.withOpacity(0.5), blurRadius: 12)]
                : const <BoxShadow>[],
          ),
          child: child,
        );
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onTap(p),
        child: Padding(
          padding: const EdgeInsets.all(3),
          child: Column(
            children: [
              Expanded(child: _image(p, out)),
              const SizedBox(height: 3),
              SizedBox(
                height: 13,
                width: double.infinity,
                child: Text(
                  p.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 9.5, fontWeight: FontWeight.w800, color: ThixPolicy.textMain),
                ),
              ),
              SizedBox(
                height: 15,
                child: FittedBox(fit: BoxFit.scaleDown, child: _price(p, out)),
              ),
              const SizedBox(height: 3),
              _cartButton(p, out),
            ],
          ),
        ),
      ),
    );
  }

  Widget _image(SupermarketProduct p, bool out) {
    return Stack(
      children: [
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _kMetalEdge),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(7),
              child: p.hasPhotos
                  ? CachedNetworkImage(
                      imageUrl: p.mainPhoto,
                      fit: BoxFit.contain,
                      memCacheWidth: _memW(220),
                      fadeInDuration: const Duration(milliseconds: 120),
                      placeholder: (_, __) => const ColoredBox(color: Colors.white),
                      errorWidget: (_, __, ___) => const Center(
                        child: Icon(Icons.inventory_2_rounded,
                            size: 20, color: ThixPolicy.textMuted),
                      ),
                    )
                  : const Center(
                      child: Icon(Icons.inventory_2_rounded,
                          size: 20, color: ThixPolicy.textMuted),
                    ),
            ),
          ),
        ),
        if (out)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.65),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(
                child: Text('RUPTURE',
                    style: TextStyle(
                        fontSize: 9, fontWeight: FontWeight.w900, color: Colors.grey)),
              ),
            ),
          ),
        if (p.onPromo)
          Positioned(
            top: 2,
            left: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
              decoration: BoxDecoration(
                  color: _kRailRed, borderRadius: BorderRadius.circular(4)),
              child: Text('-${p.promoPercent}%',
                  style: const TextStyle(
                      fontSize: 8, fontWeight: FontWeight.w900, color: Colors.white)),
            ),
          ),
        if (p.isPerishable)
          Positioned(
            top: 2,
            right: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
              decoration: BoxDecoration(
                color: p.isExpired
                    ? Colors.grey
                    : (p.isFreshSoon ? Colors.orange : ThixPolicy.success),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                p.isExpired ? 'EXPIRÉ' : (p.isFreshSoon ? 'J-${p.daysToExpiry}' : 'FRAIS'),
                style: const TextStyle(
                    fontSize: 7.5, fontWeight: FontWeight.w900, color: Colors.white),
              ),
            ),
          ),
      ],
    );
  }

  Widget _price(SupermarketProduct p, bool out) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${p.priceLabel()} ${p.currency}',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w900,
            color: out
                ? ThixPolicy.textMuted
                : (p.onPromo ? _kRailRed : ThixPolicy.textMain),
          ),
        ),
        if (p.onPromo) ...[
          const SizedBox(width: 3),
          Text(
            '${p.price}',
            style: const TextStyle(
                fontSize: 8.5,
                color: ThixPolicy.textMuted,
                decoration: TextDecoration.lineThrough),
          ),
        ],
      ],
    );
  }

  Widget _cartButton(SupermarketProduct p, bool out) {
    return ValueListenableBuilder<Set<String>>(
      valueListenable: added,
      builder: (_, set, __) {
        final done = set.contains(p.pid);
        final color = out
            ? Colors.grey.shade400
            : (done ? ThixPolicy.success : ThixPolicy.primary);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: out ? null : () => onAdd(p),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 24,
            width: double.infinity,
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  out
                      ? Icons.block_rounded
                      : (done ? Icons.check_rounded : Icons.add_shopping_cart_rounded),
                  size: 12,
                  color: Colors.white,
                ),
                const SizedBox(width: 3),
                Flexible(
                  child: Text(
                    out ? 'Rupture' : (done ? 'Ajouté' : 'Panier'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 9.5, fontWeight: FontWeight.w900, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        );
      },
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
          const SizedBox(width: 8),
        ],
        Expanded(child: _miniMap()),
        const SizedBox(width: 8),
        _CartFab(count: cart, onTap: onCart),
      ],
    );
  }

  Widget _miniMap() {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.94),
        borderRadius: BorderRadius.circular(22),
        boxShadow: ThixPolicy.shadowSoft(opacity: 0.12),
      ),
      child: ValueListenableBuilder<int>(
        valueListenable: aisle,
        builder: (_, current, __) {
          return Row(
            children: List<Widget>.generate(floorDepts.length, (i) {
              final d = floorDepts[i];
              final active = i == current;
              return Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onJump(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      color: active ? d.color : d.color.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(active ? Icons.shopping_cart_rounded : d.icon,
                            size: 15, color: active ? Colors.white : d.color),
                        Text('${firstAisleNo + i}',
                            style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                color: active ? Colors.white : d.color)),
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
  const _Elevator({
    required this.floor,
    required this.count,
    required this.onUp,
    required this.onDown,
  });

  Widget _btn(IconData icon, bool enabled, VoidCallback onTap) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: enabled ? onTap : null,
      child: Container(
        width: 38,
        height: 30,
        decoration: BoxDecoration(
          color: enabled ? ThixPolicy.primary : ThixPolicy.border,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, size: 22, color: Colors.white),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.94),
        borderRadius: BorderRadius.circular(18),
        boxShadow: ThixPolicy.shadowSoft(opacity: 0.12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _btn(Icons.keyboard_arrow_up_rounded, floor < count - 1, onUp),
          const SizedBox(height: 2),
          const Text('ÉTAGE',
              style: TextStyle(
                  fontSize: 7.5,
                  fontWeight: FontWeight.w900,
                  color: ThixPolicy.textMuted,
                  letterSpacing: 0.5)),
          Text(_floorShort(floor),
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w900, color: ThixPolicy.textMain)),
          const SizedBox(height: 2),
          _btn(Icons.keyboard_arrow_down_rounded, floor > 0, onDown),
        ],
      ),
    );
  }
}

class _CartFab extends StatelessWidget {
  final ValueNotifier<int> count;
  final VoidCallback onTap;
  const _CartFab({required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 58,
        height: 58,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [ThixPolicy.primary, ThixPolicy.primaryDeep],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: ThixPolicy.primary.withOpacity(0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: const Icon(Icons.shopping_cart_rounded, color: Colors.white, size: 24),
            ),
            Positioned(
              top: -2,
              right: -2,
              child: ValueListenableBuilder<int>(
                valueListenable: count,
                builder: (_, n, __) {
                  if (n == 0) return const SizedBox.shrink();
                  return Container(
                    constraints: const BoxConstraints(minWidth: 20),
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: _kRailRed,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: Text('$n',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 10, fontWeight: FontWeight.w900, color: Colors.white)),
                  );
                },
              ),
            ),
          ],
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
  final VoidCallback onTap;
  const _QuickChip({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: selected ? color : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: selected ? Colors.white : color),
            const SizedBox(width: 5),
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: selected ? Colors.white : ThixPolicy.textMain)),
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
      margin: const EdgeInsets.fromLTRB(10, 4, 10, 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.98),
        borderRadius: BorderRadius.circular(18),
        boxShadow: ThixPolicy.shadowSoft(opacity: 0.16),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 6, 6),
            child: Row(
              children: [
                Icon(promo ? Icons.local_fire_department_rounded : Icons.search_rounded,
                    size: 18, color: promo ? _kRailRed : ThixPolicy.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    promo ? 'Promotions du moment' : '${results.length} résultat(s)',
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w900, color: ThixPolicy.textMain),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: onClose,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: results.isEmpty
                ? const Center(
                    child: Text('Aucun produit trouvé',
                        style: TextStyle(
                            color: ThixPolicy.textSecondary, fontWeight: FontWeight.w700)),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemCount: results.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final p = results[i];
                      final out = _stockOf(p) <= 0;
                      return ListTile(
                        onTap: () => onGo(p),
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: SizedBox(
                            width: 46,
                            height: 46,
                            child: p.hasPhotos
                                ? CachedNetworkImage(
                                    imageUrl: p.mainPhoto,
                                    fit: BoxFit.cover,
                                    memCacheWidth: _memW(120),
                                    errorWidget: (_, __, ___) => const Icon(
                                        Icons.inventory_2_rounded,
                                        color: ThixPolicy.textMuted),
                                  )
                                : const Icon(Icons.inventory_2_rounded,
                                    color: ThixPolicy.textMuted),
                          ),
                        ),
                        title: Text(p.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w800)),
                        subtitle: Row(
                          children: [
                            const Icon(Icons.near_me_rounded,
                                size: 11, color: ThixPolicy.primary),
                            const SizedBox(width: 3),
                            Expanded(
                              child: Text(locate(p),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 11, color: ThixPolicy.textSecondary)),
                            ),
                          ],
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('${p.priceLabel()} ${p.currency}',
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w900,
                                    color: p.onPromo ? _kRailRed : ThixPolicy.textMain)),
                            const SizedBox(height: 3),
                            ValueListenableBuilder<Set<String>>(
                              valueListenable: added,
                              builder: (_, set, __) {
                                final done = set.contains(p.pid);
                                return GestureDetector(
                                  onTap: out ? null : () => onAdd(p),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: out
                                          ? Colors.grey.shade400
                                          : (done
                                              ? ThixPolicy.success
                                              : ThixPolicy.primary),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                        done
                                            ? Icons.check_rounded
                                            : Icons.add_shopping_cart_rounded,
                                        size: 14,
                                        color: Colors.white),
                                  ),
                                );
                              },
                            ),
                          ],
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

// ============================================================================
// FICHE PRODUIT RAPIDE
// ============================================================================
class _ProductQuickView extends StatelessWidget {
  final SupermarketProduct product;
  final AppLocalizations l10n;
  final VoidCallback onAdd;
  const _ProductQuickView({
    required this.product,
    required this.l10n,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final p = product;
    final out = _stockOf(p) <= 0;

    return DraggableScrollableSheet(
      initialChildSize: 0.82,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: ListView(
          controller: scrollCtrl,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: ThixPolicy.border, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            _PhotoGallery(photos: p.photos),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(p.title,
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: ThixPolicy.textMain)),
                ),
                if (p.onPromo)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                        color: _kRailRed, borderRadius: BorderRadius.circular(8)),
                    child: Text('-${p.promoPercent}%',
                        style: const TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w900, color: Colors.white)),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text('${p.priceLabel()} ${p.currency}',
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: p.onPromo ? _kRailRed : ThixPolicy.primary)),
                if (p.onPromo) ...[
                  const SizedBox(width: 8),
                  Text('${p.price} ${p.currency}',
                      style: const TextStyle(
                          fontSize: 13,
                          color: ThixPolicy.textMuted,
                          decoration: TextDecoration.lineThrough)),
                ],
                if (p.unit != null) ...[
                  const SizedBox(width: 8),
                  Text('/ ${p.unit}',
                      style: const TextStyle(fontSize: 12, color: ThixPolicy.textMuted)),
                ],
              ],
            ),
            const SizedBox(height: 14),
            _InfoGrid(product: p),
            const SizedBox(height: 16),
            if (p.barcode != null && p.barcode!.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                    color: ThixPolicy.surfaceSoft, borderRadius: BorderRadius.circular(14)),
                child: Column(
                  children: [
                    BarcodeWidget(
                      barcode: Barcode.code128(),
                      data: p.barcode!,
                      height: 48,
                      drawText: false,
                      color: ThixPolicy.textMain,
                    ),
                    const SizedBox(height: 6),
                    Text(p.barcode!,
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 2,
                            color: ThixPolicy.textSecondary)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            if (p.description != null && p.description!.isNotEmpty) ...[
              Text(_tr(l10n, 'sm_description', 'Description'),
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w900, color: ThixPolicy.textMain)),
              const SizedBox(height: 6),
              Text(p.description!,
                  style: const TextStyle(
                      fontSize: 13, color: ThixPolicy.textSecondary, height: 1.5)),
              const SizedBox(height: 20),
            ],
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: out
                          ? null
                          : () {
                              onAdd();
                              Navigator.pop(context);
                            },
                      icon: Icon(
                          out ? Icons.block_rounded : Icons.add_shopping_cart_rounded,
                          size: 18),
                      label: Text(out ? 'Rupture de stock' : 'Ajouter au panier'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ThixPolicy.primary,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.grey.shade400,
                        disabledForegroundColor: Colors.white,
                        elevation: 0,
                        textStyle: const TextStyle(fontWeight: FontWeight.w900),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  height: 50,
                  width: 50,
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      context.push('/market/product/${p.id}');
                    },
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.zero,
                      side: BorderSide(color: ThixPolicy.border),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Icon(Icons.open_in_full_rounded,
                        size: 20, color: ThixPolicy.textMain),
                  ),
                ),
              ],
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
        decoration: BoxDecoration(
            color: ThixPolicy.surfaceSoft, borderRadius: BorderRadius.circular(16)),
        child: const Center(
          child: Icon(Icons.image_not_supported_outlined,
              size: 40, color: ThixPolicy.textMuted),
        ),
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
                memCacheWidth: _memW(800),
                placeholder: (_, __) => const Center(child: CircularProgressIndicator()),
                errorWidget: (_, __, ___) => const Center(
                  child: Icon(Icons.broken_image_rounded, color: ThixPolicy.textMuted),
                ),
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
                decoration: BoxDecoration(
                  color: active ? ThixPolicy.primary : ThixPolicy.border,
                  borderRadius: BorderRadius.circular(3),
                ),
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
    final stock = _stockOf(product);
    final cells = <Widget>[
      _InfoCell(
        icon: Icons.inventory_2_rounded,
        label: 'Stock',
        value: '$stock${product.unit != null ? ' ${product.unit}' : ''}',
        color: stock > 0 ? ThixPolicy.success : ThixPolicy.danger,
      ),
      _InfoCell(
        icon: Icons.category_outlined,
        label: 'Unité',
        value: product.unit ?? 'pcs',
        color: ThixPolicy.primary,
      ),
      if (product.isPerishable)
        _InfoCell(
          icon: product.isExpired ? Icons.warning_amber_rounded : Icons.event_rounded,
          label: 'Expiration',
          value: _fmtDate(product.expiryDate),
          color: product.isExpired
              ? ThixPolicy.danger
              : (product.isFreshSoon ? Colors.orange : ThixPolicy.success),
        ),
      if (product.onPromo)
        _InfoCell(
          icon: Icons.local_offer_rounded,
          label: 'Prix promo',
          value: '${product.priceLabel()} ${product.currency}',
          color: _kRailRed,
        ),
    ];

    final cellWidth = (MediaQuery.of(context).size.width - 60) / 2;
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: cells.map((c) => SizedBox(width: cellWidth, child: c)).toList(),
    );
  }
}

class _InfoCell extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _InfoCell({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ThixPolicy.surfaceSoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ThixPolicy.border),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 10,
                        color: ThixPolicy.textMuted,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w900, color: color)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
