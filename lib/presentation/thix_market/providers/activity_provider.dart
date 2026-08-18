import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ActivityProvider extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

  List<Map<String, dynamic>> _purchases = [];
  List<Map<String, dynamic>> _sales = [];
  List<Map<String, dynamic>> _ratings = [];
  List<Map<String, dynamic>> _badges = [];
  Map<String, dynamic> _ratingStats = {
    'average': 0.0,
    'total': 0,
    'distribution': <int, int>{1: 0, 2: 0, 3: 0, 4: 0, 5: 0},
  };
  bool _isLoadingPurchases = false;
  bool _isLoadingSales = false;
  bool _isLoadingRatings = false;

  List<Map<String, dynamic>> get purchases => _purchases;
  List<Map<String, dynamic>> get sales => _sales;
  List<Map<String, dynamic>> get ratings => _ratings;
  List<Map<String, dynamic>> get badges => _badges;
  Map<String, dynamic> get ratingStats => _ratingStats;
  bool get isLoadingPurchases => _isLoadingPurchases;
  bool get isLoadingSales => _isLoadingSales;
  bool get isLoadingRatings => _isLoadingRatings;

  Future<void> loadPurchases() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;
    _isLoadingPurchases = true;
    notifyListeners();
    try {
      final response = await _supabase
          .from('orders')
          .select('id, status, total, created_at, order_items(quantity, price, product_name, product_image)')
          .eq('user_id', userId)
          .order('created_at', ascending: false);
      _purchases = List<Map<String, dynamic>>.from(response).map(_normalizeOrder).toList();
    } catch (_) {
      _purchases = [];
    } finally {
      _isLoadingPurchases = false;
      notifyListeners();
    }
  }

  Future<void> loadSales() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;
    _isLoadingSales = true;
    notifyListeners();
    try {
      final shopIds = await _supabase.from('shops').select('id').eq('owner_id', userId);
      final ids = shopIds.map((e) => e['id']).whereType<String>().toList();
      if (ids.isEmpty) {
        _sales = [];
      } else {
        final response = await _supabase
            .from('orders')
            .select('id, status, total, created_at, shop_id, order_items(quantity, price, product_name, product_image)')
            .inFilter('shop_id', ids)
            .order('created_at', ascending: false);
        _sales = List<Map<String, dynamic>>.from(response).map(_normalizeOrder).toList();
      }
    } catch (_) {
      _sales = [];
    } finally {
      _isLoadingSales = false;
      notifyListeners();
    }
  }

  Future<void> loadRatings() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;
    _isLoadingRatings = true;
    notifyListeners();
    try {
      final response = await _supabase
          .from('reviews')
          .select('id, rating, comment, reply, created_at, user:users(name, avatar)')
          .eq('seller_id', userId)
          .order('created_at', ascending: false);
      _ratings = List<Map<String, dynamic>>.from(response).map((rating) {
        final user = Map<String, dynamic>.from(rating['user'] ?? const {});
        return {
          ...rating,
          'user_name': user['name'] ?? 'Client THIX',
          'user_avatar': user['avatar'],
        };
      }).toList();
      _buildRatingStats();
    } catch (_) {
      _ratings = [];
      _ratingStats = {
        'average': 0.0,
        'total': 0,
        'distribution': <int, int>{1: 0, 2: 0, 3: 0, 4: 0, 5: 0},
      };
    } finally {
      _isLoadingRatings = false;
      notifyListeners();
    }
  }

  Future<void> loadGlobalStats() async {
    _badges = [
      {'name': 'Vendeur fiable', 'color_start': 0xFFE5592F, 'color_end': 0xFFFF8A65},
      {'name': 'Livraison rapide', 'color_start': 0xFF2563EB, 'color_end': 0xFF60A5FA},
    ];
    notifyListeners();
  }

  Future<void> cancelOrder(String orderId) async {
    try {
      await _supabase.from('orders').update({'status': 'cancelled'}).eq('id', orderId);
      for (final list in [_purchases, _sales]) {
        final index = list.indexWhere((order) => order['id'] == orderId);
        if (index != -1) {
          list[index]['status'] = 'cancelled';
        }
      }
      notifyListeners();
    } catch (_) {}
  }

  Future<void> submitReview(String orderId, double rating, String comment) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;
    try {
      await _supabase.from('reviews').insert({
        'order_id': orderId,
        'user_id': userId,
        'rating': rating,
        'comment': comment,
        'created_at': DateTime.now().toIso8601String(),
      });
      await loadRatings();
    } catch (_) {}
  }

  Map<String, dynamic> _normalizeOrder(Map<String, dynamic> order) {
    final rawItems = List<Map<String, dynamic>>.from(order['order_items'] ?? const []);
    final items = rawItems
        .map((item) => {
              'name': item['product_name'] ?? 'Produit',
              'image_url': item['product_image'] ?? '',
              'quantity': item['quantity'] ?? 1,
              'price': item['price'] ?? 0,
            })
        .toList();
    return {
      ...order,
      'items': items,
      'total': (order['total'] ?? 0) is num ? (order['total'] as num).toDouble().toInt() : 0,
    };
  }

  void _buildRatingStats() {
    final distribution = <int, int>{1: 0, 2: 0, 3: 0, 4: 0, 5: 0};
    double totalRating = 0;
    for (final rating in _ratings) {
      final value = ((rating['rating'] ?? 0) as num).toDouble();
      final rounded = value.round().clamp(1, 5);
      distribution[rounded] = (distribution[rounded] ?? 0) + 1;
      totalRating += value;
    }
    final total = _ratings.length;
    _ratingStats = {
      'average': total == 0 ? 0.0 : totalRating / total,
      'total': total,
      'distribution': distribution.map((key, value) => MapEntry(key, total == 0 ? 0 : ((value / total) * 100).round())),
    };
  }
}
