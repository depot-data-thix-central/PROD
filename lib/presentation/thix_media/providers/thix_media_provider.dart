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
  
  // 🌟 Augmentation de la limite à 40 pour avoir un plus grand "pool" à mélanger
  static const _limit = 40;
  
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
    
    // 1. Si on est sur le Fil et sans recherche, on utilise l'algo aléatoire natif
    if (cat == 'Fil' && search.isEmpty) { 
      final p = await svc.fetchShuffledFeed(seenIds: _seen.toList(), limit: _limit); 
      _seen.addAll(p.items.map((e) => e.id)); 
      if (p.items.isNotEmpty) _cursor = p.items.last.createdAt; 
      return p.items; 
    }
    
    // 2. Requête Supabase classique
    var q = Supabase.instance.client.from('media_content').select('*');
    if (cur != null) q = q.lt('created_at', cur.toIso8601String());
    
    // 3. Application des filtres
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
      // 🌟 IMPORTANT : On sauvegarde le curseur EXACT AVANT de mélanger !
      _cursor = list.last.createdAt; 
    }
    
    // 🌟 MIX INTELLIGENT : On mélange la liste pour casser la monotonie 
    // (Sauf si l'utilisateur fait une recherche précise, auquel cas on garde l'ordre logique)
    if (search.isEmpty) {
      list.shuffle();
    }
    
    _seen.addAll(list.map((e) => e.id)); 
    return list;
  }
}

final thixMediaListProvider = StateNotifierProvider<ThixMediaNotifier, AsyncValue<List<MediaContent>>>((ref) => ThixMediaNotifier(ref));

// ============================================================================
// 🌟 DÉCOUPAGE INTELLIGENT DES RANGÉES (Évite de répéter les mêmes vidéos)
// ============================================================================

// Bannières : Prend les 5 premières vidéos du lot mélangé
final bannerItemsProvider = Provider<List<MediaContent>>((ref) {
  return ref.watch(thixMediaListProvider).valueOrNull?.take(5).toList() ?? [];
});

// Nouveautés : Récupère un extrait et force le tri par date (pour avoir les VRAIES nouveautés)
final newReleasesProvider = Provider<List<MediaContent>>((ref) {
  final list = ref.watch(thixMediaListProvider).valueOrNull?.take(15).toList() ?? [];
  list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
  return list;
});

// Tendances : Saute les 5 vidéos de la bannière et prend les 10 suivantes
final trendingProvider = Provider<List<MediaContent>>((ref) {
  final list = ref.watch(thixMediaListProvider).valueOrNull ?? [];
  if (list.length <= 5) return [];
  return list.skip(5).take(10).toList();
});

// Recommandations : Prend tout le reste (pour le défilement infini vers le bas)
final recommendationsProvider = Provider<List<MediaContent>>((ref) {
  final list = ref.watch(thixMediaListProvider).valueOrNull ?? [];
  if (list.length <= 15) return list;
  return list.skip(15).toList();
});
