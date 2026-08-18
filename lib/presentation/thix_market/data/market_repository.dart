import 'package:supabase_flutter/supabase_flutter.dart';

class MarketRepository {
  final SupabaseClient _db;
  MarketRepository(this._db);

  Future<List<Map<String, dynamic>>> fetchBanners() async {
    final res = await _db.from('banners').select('*').eq('is_active', true).order('priority', ascending: true).limit(10);
    return List<Map<String, dynamic>>.from(res);
  }

  Future<List<Map<String, dynamic>>> fetchProducts({
    int page = 0,
    int limit = 20,
    bool flashOnly = false,
    String? category,
    String? search,
  }) async {
    // IMPORTANT: on ne select jamais shop_name, on passe par la relation shops
    var q = _db.from('products').select('*, shop:shops(id,name,rating,logo_url,city)').eq('status', 'active');

    if (flashOnly) q = q.eq('is_flash_sale', true);
    if (category != null && category != 'all') q = q.eq('category', category);
    if (search != null && search.isNotEmpty) q = q.ilike('title', '%$search%');

    final ordered = q.order('created_at', ascending: false);
    final ranged = ordered.range(page * limit, (page + 1) * limit - 1);
    final res = await ranged;
    return List<Map<String, dynamic>>.from(res);
  }

  Future<List<Map<String, dynamic>>> fetchFeaturedShops() async {
    final res = await _db.from('shops').select('id,name,logo_url,rating,is_verified,city').eq('is_featured', true).limit(10);
    return List<Map<String, dynamic>>.from(res);
  }

  Future<String?> fetchMyShopId() async {
    final uid = _db.auth.currentUser?.id;
    if (uid == null) return null;
    final res = await _db.from('shops').select('id').eq('owner_id', uid).maybeSingle();
    return res?['id'] as String?;
  }

  Future<int> fetchUnread() async {
    final uid = _db.auth.currentUser?.id;
    if (uid == null) return 0;
    try {
      final res = await _db.from('notifications').select('id').eq('user_id', uid).eq('is_read', false).count(CountOption.exact);
      return res.count;
    } catch (_) {
      return 0;
    }
  }
}
