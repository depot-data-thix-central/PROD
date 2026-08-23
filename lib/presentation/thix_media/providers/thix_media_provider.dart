import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:thix_id/models/media_content.dart';
import 'package:thix_id/services/media_service.dart';

// 🌟 1. AJOUT DE .autoDispose POUR PURGER LA MÉMOIRE EN SORTANT DU MODULE
final selectedCategoryProvider = StateProvider.autoDispose<String>((ref) => "Accueil");
final searchQueryProvider = StateProvider.autoDispose<String>((ref) => "");

class ThixMediaNotifier extends StateNotifier<AsyncValue<List<MediaContent>>> {
  ThixMediaNotifier(this.ref): super(const AsyncValue.loading()){ 
    _load(); 
    ref.listen(selectedCategoryProvider, (_,__)=>refresh()); 
    ref.listen(searchQueryProvider, (_,__)=>refresh()); 
  }
  
  final Ref ref; 
  DateTime? _cursor; 
  bool _hasMore = true, _loading = false; 
  final Set<String> _seen = {}; 
  
  static const _limit = 40;
  
  Future<void> _load() => refresh();
  
  Future<void> refresh() async { 
    _cursor = null; 
    _hasMore = true; 
    _seen.clear(); 
    state = const AsyncValue.loading(); 
    try { 
      final l = await _fetch(null); 
      // 🌟 2. SÉCURITÉ : On vérifie que la page est toujours ouverte avant de mettre à jour
      if (!mounted) return; 
      state = AsyncValue.data(l); 
    } catch (e, st) { 
      if (!mounted) return;
      state = AsyncValue.error(e, st); 
    } 
  }
  
  Future<void> loadMore() async { 
    if (_loading || !_hasMore || state.value == null) return; 
    _loading = true; 
    try { 
      final m = await _fetch(_cursor); 
      if (!mounted) return;
      if (m.length < _limit) _hasMore = false; 
      state = AsyncValue.data([...state.value!, ...m]); 
    } finally { 
      _loading = false; 
    } 
  }
  
  Future<List<MediaContent>> _fetch(DateTime? cur) async {
    final cat = ref.read(selectedCategoryProvider); 
    final search = ref.read(searchQueryProvider).trim(); 
    final svc = MediaService();
    
    if (cat == 'Fil' && search.isEmpty) { 
      final p = await svc.fetchShuffledFeed(seenIds: _seen.toList(), limit: _limit); 
      _seen.addAll(p.items.map((e) => e.id)); 
      if (p.items.isNotEmpty) _cursor = p.items.last.createdAt; 
      return p.items; 
    }
    
    var q = Supabase.instance.client.from('media_content').select('*');
    if (cur != null) q = q.lt('created_at', cur.toIso8601String());
    
    if (search.isNotEmpty) {
      q = q.ilike('title', '%$search%'); 
    } else if (cat == 'Accueil') {
      q = q.neq('type', 'Fil'); 
    } else {
      q = q.eq('type', cat);
    }
    
    final res = await q.order('created_at', ascending: false).limit(_limit);
    
    final list = (res as List).map((it) { 
      return MediaContent.fromJson(Map<String, dynamic>.from(it as Map)); 
    }).toList();
    
    if (list.isNotEmpty) {
      _cursor = list.last.createdAt; 
    }
    
    if (search.isEmpty) {
      list.shuffle();
    }
    
    _seen.addAll(list.map((e) => e.id)); 
    return list;
  }
}

// 🌟 3. AJOUT DE .autoDispose SUR TOUS LES PROVIDERS POUR UN RECHARGEMENT PROPRE
final thixMediaListProvider = StateNotifierProvider.autoDispose<ThixMediaNotifier, AsyncValue<List<MediaContent>>>((ref) => ThixMediaNotifier(ref));

final bannerItemsProvider = Provider.autoDispose<List<MediaContent>>((ref) {
  return ref.watch(thixMediaListProvider).valueOrNull?.take(5).toList() ?? [];
});

final newReleasesProvider = Provider.autoDispose<List<MediaContent>>((ref) {
  final list = ref.watch(thixMediaListProvider).valueOrNull?.take(15).toList() ?? [];
  list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
  return list;
});

final trendingProvider = Provider.autoDispose<List<MediaContent>>((ref) {
  final list = ref.watch(thixMediaListProvider).valueOrNull ?? [];
  if (list.length <= 5) return [];
  return list.skip(5).take(10).toList();
});

final recommendationsProvider = Provider.autoDispose<List<MediaContent>>((ref) {
  final list = ref.watch(thixMediaListProvider).valueOrNull ?? [];
  if (list.length <= 15) return list;
  return list.skip(15).toList();
});
