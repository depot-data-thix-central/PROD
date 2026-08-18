import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/market_repository.dart';

final supabaseClientProvider = Provider<SupabaseClient>((ref)=> Supabase.instance.client);
final marketRepositoryProvider = Provider<MarketRepository>((ref)=> MarketRepository(ref.watch(supabaseClientProvider)));

final bannersProvider = FutureProvider<List<Map<String,dynamic>>>((ref)=> ref.watch(marketRepositoryProvider).fetchBanners());
final flashSalesProvider = FutureProvider<List<Map<String,dynamic>>>((ref)=> ref.watch(marketRepositoryProvider).fetchProducts(page:0,limit:8,flashOnly:true));
final featuredShopsProvider = FutureProvider<List<Map<String,dynamic>>>((ref)=> ref.watch(marketRepositoryProvider).fetchFeaturedShops());
final myShopIdProvider = FutureProvider<String?>((ref)=> ref.watch(marketRepositoryProvider).fetchMyShopId());
final unreadProvider = FutureProvider<int>((ref)=> ref.watch(marketRepositoryProvider).fetchUnread());

class ForYouNotifier extends AsyncNotifier<List<Map<String,dynamic>>> {
  int _page=0;
  bool _hasMore=true;
  bool get hasMore=> _hasMore;

  @override Future<List<Map<String,dynamic>>> build() async {
    _page=0;
    _hasMore=true;
    final first = await ref.read(marketRepositoryProvider).fetchProducts(page:0,limit:20);
    _page=1;
    _hasMore=first.length==20;
    return first;
  }

  Future<void> loadMore() async {
    if(!_hasMore) return;
    if(state.isLoading) return;
    final cur = state.valueOrNull;
    if(cur==null || cur.isEmpty) return;

    state = AsyncLoading<List<Map<String,dynamic>>>().copyWithPrevious(AsyncData(cur));

    try{
      final more = await ref.read(marketRepositoryProvider).fetchProducts(page:_page,limit:20);
      if(more.length<20) _hasMore=false;
      _page++;
      state = AsyncData([...cur,...more]);
    }catch(e,st){
      state = AsyncValue<List<Map<String,dynamic>>>.error(e,st).copyWithPrevious(AsyncData(cur));
    }
  }

  Future<void> refresh() async {
    _page=0;
    _hasMore=true;
    ref.invalidateSelf();
    await future;
  }
}

final forYouProvider = AsyncNotifierProvider<ForYouNotifier,List<Map<String,dynamic>>>(ForYouNotifier.new);

final allMarketProductsProvider = Provider<List<Map<String,dynamic>>>((ref){
  final flash = ref.watch(flashSalesProvider).valueOrNull?? const <Map<String,dynamic>>[];
  final forYou = ref.watch(forYouProvider).valueOrNull?? const <Map<String,dynamic>>[];
  final map=<String,Map<String,dynamic>>{};
  for(final p in [...flash,...forYou]){
    final id=p['id']?.toString();
    if(id!=null) map[id]=p;
  }
  return map.values.toList();
});
