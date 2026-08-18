import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'market_providers.dart';

// ================= STATE =================
class ProductListState {
  final List<Map<String,dynamic>> items;
  final bool hasMore;
  final int page;
  final String? category;
  final String? query;
  const ProductListState({this.items=const [], this.hasMore=true, this.page=0, this.category, this.query});
  ProductListState copyWith({List<Map<String,dynamic>>? items, bool? hasMore, int? page, String? category, String? query}){
    return ProductListState(
      items: items?? this.items,
      hasMore: hasMore?? this.hasMore,
      page: page?? this.page,
      category: category?? this.category,
      query: query?? this.query,
    );
  }
}

// ================= PRODUCTS PAGINATED =================
class ProductNotifier extends AsyncNotifier<ProductListState> {
  @override Future<ProductListState> build() async {
    final first = await _fetch(page:0);
    return ProductListState(items:first, hasMore:first.length==20, page:1);
  }

  Future<List<Map<String,dynamic>>> _fetch({int page=0, String? category, String? query}) async {
    final db = ref.read(supabaseClientProvider);
    var q = db.from('products').select('*, shop:shops(name, rating)').eq('status','active');
    if(category!=null && category!='all') q = q.eq('category', category);
    if(query!=null && query.isNotEmpty) q = q.ilike('title', '%$query%');
    final ordered = q.order('created_at', ascending:false);
    final ranged = ordered.range(page*20, (page+1)*20 -1);
    final res = await ranged;
    return List<Map<String,dynamic>>.from(res);
  }

  Future<void> load({String? category, String? query, bool refresh=false}) async {
    final cur = state.valueOrNull ?? const ProductListState();
    if(refresh){
      state = const AsyncLoading<ProductListState>();
      try{
        final first = await _fetch(page:0, category:category, query:query);
        state = AsyncData(ProductListState(items:first, hasMore:first.length==20, page:1, category:category, query:query));
      }catch(e,st){ state = AsyncValue<ProductListState>.error(e,st); }
      return;
    }
    if(!cur.hasMore) return;
    if(state.isLoading) return;

    state = AsyncLoading<ProductListState>().copyWithPrevious(AsyncData(cur));
    try{
      final more = await _fetch(page:cur.page, category:cur.category??category, query:cur.query??query);
      final hasMore = more.length==20;
      state = AsyncData(cur.copyWith(items:[...cur.items,...more], hasMore:hasMore, page:cur.page+1, category:category??cur.category, query:query??cur.query));
    }catch(e,st){
      state = AsyncValue<ProductListState>.error(e,st).copyWithPrevious(AsyncData(cur));
    }
  }

  Future<void> refresh() => load(refresh:true);
}

final productProvider = AsyncNotifierProvider<ProductNotifier, ProductListState>(ProductNotifier.new);

// ================= PRODUCT DETAIL =================
final productDetailProvider = FutureProvider.family<Map<String,dynamic>?, String>((ref, id) async {
  final db = ref.read(supabaseClientProvider);
  try{
    final res = await db.from('products').select('*, shop:shops(*), reviews:reviews(*, user:users(name, avatar))').eq('id', id).single();
    return res;
  }catch(e){ debugPrint('detail $e'); return null; }
});

// ================= FAVORITES / WISHLIST =================
class FavoritesNotifier extends AsyncNotifier<List<Map<String,dynamic>>> {
  @override Future<List<Map<String,dynamic>>> build() async => _load();

  Future<List<Map<String,dynamic>>> _load() async {
    final db = ref.read(supabaseClientProvider);
    final uid = db.auth.currentUser?.id;
    if(uid==null) return [];
    final res = await db.from('wishlist').select('product:products(*, shop:shops(name))').eq('user_id', uid);
    return res.map((e)=> Map<String,dynamic>.from(e['product'] as Map)).toList();
  }

  Future<void> toggle(String productId) async {
    final db = ref.read(supabaseClientProvider);
    final uid = db.auth.currentUser?.id;
    if(uid==null) return;
    final cur = state.valueOrNull?? [];
    final isFav = cur.any((p)=> p['id']==productId);

    // optimistic
    if(isFav){ state = AsyncData(cur.where((p)=> p['id']!=productId).toList()); }
    else {
      // cherche produit dans productProvider pour ajout rapide
      final products = ref.read(productProvider).valueOrNull?.items?? [];
      final prod = products.firstWhere((p)=> p['id']==productId, orElse: ()=> <String,dynamic>{});
      if(prod.isNotEmpty) state = AsyncData([...cur, prod]);
    }

    try{
      final existing = await db.from('wishlist').select().match({'user_id':uid,'product_id':productId}).maybeSingle();
      if(existing!=null){ await db.from('wishlist').delete().match({'user_id':uid,'product_id':productId}); }
      else { await db.from('wishlist').insert({'user_id':uid,'product_id':productId}); }
      ref.invalidateSelf();
    }catch(e){
      debugPrint('toggleFav $e');
      state = AsyncData(cur);
    }
  }

  Future<void> refresh() async { ref.invalidateSelf(); }
}

final favoritesProvider = AsyncNotifierProvider<FavoritesNotifier, List<Map<String,dynamic>>>(FavoritesNotifier.new);

class WishlistNotifier extends AsyncNotifier<List<Map<String,dynamic>>> {
  @override Future<List<Map<String,dynamic>>> build() async {
    final db = ref.read(supabaseClientProvider);
    final uid = db.auth.currentUser?.id;
    if(uid==null) return [];
    final res = await db.from('wishlists').select('*, products(*)').eq('user_id', uid).order('created_at', ascending:false);
    return List<Map<String,dynamic>>.from(res);
  }

  Future<void> remove(String wishlistId) async {
    final cur = state.valueOrNull?? [];
    state = AsyncData(cur.where((w)=> w['id']!=wishlistId).toList());
    try{
      final db = ref.read(supabaseClientProvider);
      await db.from('wishlists').delete().eq('id', wishlistId);
    }catch(e){
      debugPrint('removeWishlist $e');
      state = AsyncData(cur);
    }
  }
}

final wishlistProvider = AsyncNotifierProvider<WishlistNotifier, List<Map<String,dynamic>>>(WishlistNotifier.new);
