import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:thix_id/models/media_content.dart';
import 'package:thix_id/services/media_service.dart';

final selectedCategoryProvider = StateProvider<String>((ref) => "Fil");
final searchQueryProvider = StateProvider<String>((ref) => "");

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
  static const _limit = 20;
  
  Future<void> _load() => refresh();
  
  Future<void> refresh() async { 
    _cursor = null; 
    _hasMore = true; 
    _seen.clear(); 
    state = const AsyncValue.loading(); 
    try { 
      final l = await _fetch(null); 
      state = AsyncValue.data(l); 
    } catch (e, st) { 
      state = AsyncValue.error(e, st); 
    } 
  }
  
  Future<void> loadMore() async { 
    if (_loading || !_hasMore || state.value == null) return; 
    _loading = true; 
    try { 
      final m = await _fetch(_cursor); 
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
    
    // 1. Si on est sur le Fil et sans recherche, on utilise l'algorithme aléatoire ultra-rapide
    if (cat == 'Fil' && search.isEmpty) { 
      final p = await svc.fetchShuffledFeed(seenIds: _seen.toList(), limit: _limit); 
      _seen.addAll(p.items.map((e) => e.id)); 
      if (p.items.isNotEmpty) _cursor = p.items.last.createdAt; 
      return p.items; 
    }
    
    // 2. CORRECTION PGRST200 : On retire la jointure fautive media_stats(...)
    var q = Supabase.instance.client.from('media_content').select('*');
    
    if (cur != null) q = q.lt('created_at', cur.toIso8601String());
    
    // 3. CORRECTION FILTRE : Exclure les vidéos "Fil" de la page d'Accueil
    if (search.isNotEmpty) {
      q = q.ilike('title', '%$search%'); 
    } else if (cat == 'Accueil') {
      q = q.neq('type', 'Fil'); // Cette ligne empêche le Fil de polluer l'Accueil
    } else {
      q = q.eq('type', cat);
    }
    
    final res = await q.order('created_at', ascending: false).limit(_limit);
    
    // 4. Parsing simplifié (les stats sont gérées par StreamProvider côté UI)
    final list = (res as List).map((it) { 
      return MediaContent.fromJson(Map<String, dynamic>.from(it as Map)); 
    }).toList();
    
    if (list.isNotEmpty) _cursor = list.last.createdAt; 
    _seen.addAll(list.map((e) => e.id)); 
    return list;
  }
}

final thixMediaListProvider = StateNotifierProvider<ThixMediaNotifier, AsyncValue<List<MediaContent>>>((ref) => ThixMediaNotifier(ref));

// Les providers dérivés pour les rangées de l'Accueil (Filtrés automatiquement grâce à _fetch)
final bannerItemsProvider = Provider<List<MediaContent>>((ref) => ref.watch(thixMediaListProvider).valueOrNull?.take(5).toList() ?? []);
final recommendationsProvider = Provider<List<MediaContent>>((ref) => ref.watch(thixMediaListProvider).valueOrNull ?? []);
final newReleasesProvider = Provider<List<MediaContent>>((ref) => ref.watch(thixMediaListProvider).valueOrNull ?? []);
final trendingProvider = Provider<List<MediaContent>>((ref) => ref.watch(thixMediaListProvider).valueOrNull ?? []);
