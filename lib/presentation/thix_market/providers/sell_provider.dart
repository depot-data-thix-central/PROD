// lib/presentation/thix_market/providers/sell_provider.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SellProvider extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

  // États
  List<Map<String, dynamic>> _announcements = [];
  List<Map<String, dynamic>> _orders = [];
  List<Map<String, dynamic>> _myLives = [];
  Map<String, dynamic> _stats = {};
  
  bool _isLoading = false;
  bool _isLoadingOrders = false;
  bool _isLoadingLives = false;

  // Getters
  List<Map<String, dynamic>> get announcements => _announcements;
  List<Map<String, dynamic>> get orders => _orders;
  Map<String, dynamic> get stats => _stats;
  List<Map<String, dynamic>> get myLives => _myLives;
  
  bool get isLoading => _isLoading;
  bool get isLoadingOrders => _isLoadingOrders;
  bool get isLoadingLives => _isLoadingLives;

  // ============================================================
  // 1. CHARGEMENT DES ANNONCES
  // ============================================================
  Future<void> loadMyAnnouncements() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;
    
    _isLoading = true;
    notifyListeners();

    try {
      final shopResponse = await _supabase.from('shops').select('id').eq('owner_id', userId);
      final shopIds = shopResponse.map((e) => e['id']).toList();

      if (shopIds.isEmpty) {
        _announcements = [];
      } else {
        final response = await _supabase
            .from('products')
            .select('*, shop:shops(name, logo_url)')
            .inFilter('shop_id', shopIds)
            .order('created_at', ascending: false);
        _announcements = List<Map<String, dynamic>>.from(response);
      }
    } catch (e) {
      debugPrint('🚨 Erreur Annonces: $e');
      _announcements = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

    // ============================================================
  // 2. CHARGEMENT DES COMMANDES (VERSION LIAISON order_items)
  // ============================================================
    Future<void> loadOrders() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;
    
    _isLoadingOrders = true;
    notifyListeners();

    try {
      // 1. Mes boutiques
      final shopResponse = await _supabase.from('shops').select('id').eq('owner_id', userId);
      final shopIds = shopResponse.map((e) => e['id'].toString()).toList();

      debugPrint("🛍️ Mes shops: $shopIds");

      if (shopIds.isEmpty) {
        _orders = [];
        return;
      }

      // 2. Les commandes où orders.shop_id est dans mes shops
      final response = await _supabase
          .from('orders')
          .select('''
            *,
            order_items(
              *,
              products(name, image_url, price)
            )
          ''')
          .inFilter('shop_id', shopIds)
          .order('created_at', ascending: false);

      _orders = List<Map<String, dynamic>>.from(response);
      debugPrint("✅ Commandes vendeur trouvées : ${_orders.length}");

    } catch (e, stack) {
      debugPrint("🚨 ERREUR loadOrders: $e");
      debugPrint("$stack");
      _orders = [];
    } finally {
      _isLoadingOrders = false;
      notifyListeners();
    }
  }


  // ============================================================
  // 3. CHARGEMENT DES LIVES
  // ============================================================
  Future<void> loadMyLives() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;
    _isLoadingLives = true;
    notifyListeners();

    try {
      final shopResponse = await _supabase.from('shops').select('id').eq('owner_id', userId).maybeSingle();
      if (shopResponse != null) {
        final response = await _supabase
            .from('lives')
            .select()
            .eq('shop_id', shopResponse['id'])
            .order('created_at', ascending: false);
        _myLives = List<Map<String, dynamic>>.from(response);
      }
    } catch (e) {
      debugPrint('🚨 Erreur Lives: $e');
      _myLives = [];
    } finally {
      _isLoadingLives = false;
      notifyListeners();
    }
  }

  // ============================================================
  // UTILITAIRES
  // ============================================================
  List<Map<String, dynamic>> _generateSalesData() {
    return List.generate(6, (i) => {
      'label': 'M-${5 - i}',
      'value': (100.0 + i * 50.0),
    });
  }
}
