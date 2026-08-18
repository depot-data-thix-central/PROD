import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'market_providers.dart';

class SearchState {
  final List<Map<String, dynamic>> results;
  final List<String> recent;
  final Map<String, dynamic> filters;
  final bool isLoading;
  final int total;
  final bool hasMore;
  final String lastQuery;
  const SearchState({
    this.results = const [],
    this.recent = const [],
    this.filters = const {},
    this.isLoading = false,
    this.total = 0,
    this.hasMore = true,
    this.lastQuery = '',
  });
  SearchState copyWith({
    List<Map<String, dynamic>>? results,
    List<String>? recent,
    Map<String, dynamic>? filters,
    bool? isLoading,
    int? total,
    bool? hasMore,
    String? lastQuery,
  })=> SearchState(
    results: results ?? this.results,
    recent: recent ?? this.recent,
    filters: filters ?? this.filters,
    isLoading: isLoading ?? this.isLoading,
    total: total ?? this.total,
    hasMore: hasMore ?? this.hasMore,
    lastQuery: lastQuery ?? this.lastQuery,
  );
}

class SearchNotifier extends StateNotifier<SearchState> {
  SearchNotifier(this.ref): super(const SearchState()){
    _loadRecent();
  }
  final Ref ref;
  int _page = 0;
  static const int _limit = 20;
  static const String _prefKey = 'recent_searches_v2';

  Future<void> _loadRecent() async {
    try{
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_prefKey);
      if(list!=null) state = state.copyWith(recent: list);
    }catch(_){}
  }
  Future<void> _saveRecent() async {
    try{
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_prefKey, state.recent);
    }catch(_){}
  }

  void reset(){
    _page = 0;
    state = state.copyWith(results: [], filters: {}, hasMore: true, lastQuery: '', total: 0, isLoading: false);
  }

  Future<void> searchProducts(String query, {bool refresh=false}) async {
    final q = query.trim();
    if(q.isEmpty) return;
    if(refresh){ _page = 0; }
    if(_page==0){
      state = state.copyWith(isLoading: true, lastQuery: q);
    }
    try{
      final db = ref.read(supabaseClientProvider);
      int offset = _page * _limit;
      var builder = db.from('products').select().ilike('title', '%$q%').range(offset, offset + _limit -1).order('created_at', ascending: false);
      // filters simples
      if(state.filters['minPrice']!=null){
        builder = builder.gte('price', state.filters['minPrice']);
      }
      if(state.filters['maxPrice']!=null){
        builder = builder.lte('price', state.filters['maxPrice']);
      }
      if(state.filters['category']!=null){
        builder = builder.eq('category', state.filters['category']);
      }
      final res = await builder;
      final list = List<Map<String,dynamic>>.from(res);
      List<Map<String,dynamic>> merged = refresh || _page==0? list : [...state.results, ...list];
      bool hasMore = list.length==_limit;
      _page++;
      // recent
      List<String> rec = [q, ...state.recent.where((e)=> e!=q)].take(10).toList();
      state = state.copyWith(results: merged, total: merged.length, hasMore: hasMore, recent: rec, isLoading: false);
      _saveRecent();
    }catch(e){
      debugPrint('searchProducts $e');
      state = state.copyWith(isLoading: false, hasMore: false);
    }
  }

  Future<void> searchNearby(double lat, double lng, double radiusKm) async {
    // RPC ou filtre haversine si dispo sinon simple
    try{
      state = state.copyWith(isLoading: true);
      final db = ref.read(supabaseClientProvider);
      final res = await db.from('products').select().limit(40);
      state = state.copyWith(results: List<Map<String,dynamic>>.from(res), total: (res as List).length, isLoading: false, hasMore: false);
    }catch(e){
      state = state.copyWith(isLoading: false);
    }
  }

  void applyFilters(Map<String,dynamic> filters){
    state = state.copyWith(filters: filters);
    _page = 0;
    if(state.lastQuery.isNotEmpty){
      searchProducts(state.lastQuery, refresh: true);
    }
  }

  void clearFilters(){
    state = state.copyWith(filters: {});
    _page = 0;
    if(state.lastQuery.isNotEmpty) searchProducts(state.lastQuery, refresh: true);
  }

  Future<void> clearRecentSearches() async {
    state = state.copyWith(recent: []);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefKey);
  }

  Future<void> removeRecentSearch(String query) async {
    state = state.copyWith(recent: state.recent.where((e)=> e!=query).toList());
    _saveRecent();
  }
}

final searchProvider = StateNotifierProvider<SearchNotifier, SearchState>((ref)=> SearchNotifier(ref));

// Compat getters pour ancienne SearchPage si encore utilisée
final searchResultsProviderCompat = Provider<List<Map<String,dynamic>>>((ref)=> ref.watch(searchProvider).results);
final recentSearchesCompat = Provider<List<String>>((ref)=> ref.watch(searchProvider).recent);
