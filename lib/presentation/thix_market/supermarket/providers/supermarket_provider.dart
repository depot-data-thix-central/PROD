// lib/presentation/thix_market/supermarket/providers/supermarket_provider.dart
// Provider unique supermarket - alimente home + detail + product + cart
// Réutilise ton Supabase existant, pas de nouveau Service

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupermarketProvider extends ChangeNotifier {
  // --- Deps ---
  final _supa = Supabase.instance.client;

  // --- State Home ---
  List<Map<String, dynamic>> shops = [];
  bool isLoadingShops = false;

  // --- State Detail ---
  List<Map<String, dynamic>> aisles = [];
  List<Map<String, dynamic>> products = [];
  Map<String, int> cartQty = {}; // productId -> qty panier rapide

  String? currentShopId;
  String selectedAisle = 'Tous';
  bool isLoadingDetail = false;
  bool isLoadingMore = false;
  bool hasMore = true;
  String? errorMessage;

  // --- Pagination ---
  int _page = 0;
  static const int _pageSize = 30;

  // --- Realtime ---
  RealtimeChannel? _stockChannel;

  // ===========================================================
  // 1. HOME: charge Freshia, MegaStore, CityMart, DailyDrop
  // ===========================================================
  Future<void> loadSupermarkets() async {
    try {
      isLoadingShops = true;
      errorMessage = null;
      notifyListeners();

      // vendor_type = supermarket, table existante shops
      final res = await _supa
        .from('shops')
        .select('id, name, logo_url, cover_url, delivery_eta, delivery_fee, min_order, vendor_type')
        .eq('vendor_type', 'supermarket')
        .eq('is_verified', true)
        .order('created_at', ascending: false);

      shops = List<Map<String, dynamic>>.from(res);
    } catch (e, st) {
      debugPrint('loadSupermarkets ERROR $e $st');
      errorMessage = 'Impossible de charger les supermarchés';
    } finally {
      isLoadingShops = false;
      notifyListeners();
    }
  }

  // ===========================================================
  // 2. DETAIL: rayons + produits d'un shop
  // ===========================================================
  Future<void> loadShopDetail(String shopId) async {
    currentShopId = shopId;
    _page = 0;
    hasMore = true;
    products = [];
    selectedAisle = 'Tous';
    isLoadingDetail = true;
    errorMessage = null;
    notifyListeners();

    try {
      // Charge en parallèle: rayons + première page produits
      final results = await Future.wait([
        _supa.from('supermarket_aisles').select('*').eq('shop_id', shopId).order('sort'),
        _supa.from('products').select('*').eq('shop_id', shopId).eq('is_active', true).order('created_at', ascending: false).range(0, _pageSize - 1),
      ]);

      final aisleRes = results[0] as List;
      final productRes = results[1] as List;

      aisles = [
        {'id': 'all', 'name': 'Tous', 'icon': 'apps'},
      ...List<Map<String, dynamic>>.from(aisleRes),
      ];

      products = List<Map<String, dynamic>>.from(productRes);
      if (products.length < _pageSize) hasMore = false;
      _page = 1;

      _listenStock(shopId);
    } catch (e) {
      errorMessage = 'Erreur chargement boutique';
      debugPrint('loadShopDetail $e');
    }

    isLoadingDetail = false;
    notifyListeners();
  }

  // ===========================================================
  // 3. PAGINATION infinie
  // ===========================================================
  Future<void> _fetchNextPage() async {
    if (isLoadingMore ||!hasMore || currentShopId == null) return;

    isLoadingMore = true;
    notifyListeners();

    try {
      final from = _page * _pageSize;
      final to = from + _pageSize - 1;

      final res = await _supa
        .from('products')
        .select('*')
        .eq('shop_id', currentShopId!)
        .eq('is_active', true)
        .order('created_at', ascending: false)
        .range(from, to);

      final fetched = List<Map<String, dynamic>>.from(res);
      if (fetched.length < _pageSize) hasMore = false;

      products.addAll(fetched);
      _page++;
    } catch (e) {
      debugPrint('pagination error $e');
    }

    isLoadingMore = false;
    notifyListeners();
  }

  void loadMoreIfNeeded(int index) {
    // Précharge 6 items avant la fin
    if (index >= products.length - 6) {
      _fetchNextPage();
    }
  }

  // ===========================================================
  // 4. FILTRE + PANIER RAPIDE
  // ===========================================================
  List<Map<String, dynamic>> get filteredProducts {
    if (selectedAisle == 'Tous') return products;
    final aisleObj = aisles.firstWhere((a) => a['name'] == selectedAisle, orElse: () => {'id': ''});
    return products.where((p) => p['aisle_id'] == aisleObj['id']).toList();
  }

  void setAisle(String name) {
    selectedAisle = name;
    notifyListeners();
  }

  void add(String productId, int delta) {
    final current = cartQty[productId]?? 0;
    final next = current + delta;

    if (next <= 0) {
      cartQty.remove(productId);
    } else {
      // Bloque si dépasse stock réel Supabase
      final p = products.firstWhere((e) => e['id'] == productId, orElse: () => {'stock': 999});
      final stock = (p['stock']?? 999) as int;
      if (next > stock) return;
      cartQty[productId] = next;
    }
    notifyListeners();
  }

  void clearCart() {
    cartQty.clear();
    notifyListeners();
  }

  int get totalItems => cartQty.values.fold(0, (a, b) => a + b);

  int get totalPrice {
    int sum = 0;
    cartQty.forEach((id, qty) {
      final p = products.firstWhere((e) => e['id'] == id, orElse: () => {'price': 0});
      sum += ((p['price']?? 0) as int) * qty;
    });
    return sum;
  }

  // Prix en dollars pour UI capture ($2.29)
  double get totalPriceDollars => totalPrice / 100;

  // ===========================================================
  // 5. REALTIME STOCK: ne pas vendre en rupture
  // ===========================================================
  void _listenStock(String shopId) {
    _stockChannel?.unsubscribe();
    _stockChannel = _supa
      .channel('sm-stock-prod-$shopId')
      .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'products',
          filter: PostgresChangeFilter(
  type: PostgresChangeFilterType.eq, // <-- Ajoute cette ligne
  column: 'shop_id', 
  value: shopId
),

          callback: (payload) {
            final idx = products.indexWhere((e) => e['id'] == payload.newRecord['id']);
            if (idx!= -1) {
              products[idx]['stock'] = payload.newRecord['stock'];
              products[idx]['price'] = payload.newRecord['price'];
              // Si produit en rupture et dans panier -> retire
              if ((payload.newRecord['stock']?? 0) == 0) {
                cartQty.remove(payload.newRecord['id']);
              }
              notifyListeners();
            }
          },
        )
      .subscribe();
  }

  @override
  void dispose() {
    _stockChannel?.unsubscribe();
    super.dispose();
  }
}
