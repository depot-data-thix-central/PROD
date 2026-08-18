import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/category.dart';
import '../models/formation.dart';
import '../models/certificate.dart';
import '../models/enrollment.dart';

// Client global - ne casse pas la DB
final supabaseClientProvider = Provider<SupabaseClient>((ref) => Supabase.instance.client);

// ✅ CORRECTION 1 : Méthode native ultra-propre pour éviter les doublons d'ID au démarrage (sans RxDart)
final currentUserIdProvider = StreamProvider<String?>((ref) async* {
  final client = Supabase.instance.client;
  
  String? lastId = client.auth.currentUser?.id;
  yield lastId;
  
  await for (final event in client.auth.onAuthStateChange) {
    final newId = event.session?.user.id;
    if (newId != lastId) {
      lastId = newId;
      yield lastId;
    }
  }
});

final categoriesProvider = FutureProvider.autoDispose<List<Category>>((ref) async {
  ref.keepAlive();

  final client = ref.watch(supabaseClientProvider);

  final res = await client
      .from('categories')
      .select('id,name,icon,created_at')
      .order('name');

  return res.map((e) => Category.fromJson(e)).toList();
});

// --- FORMATIONS PAGINÉES ---
class PaginatedFormations {
  final List<Formation> items;
  final bool hasMore;
  final bool isLoadingMore;
  const PaginatedFormations({required this.items, this.hasMore = true, this.isLoadingMore = false});
  PaginatedFormations copyWith({List<Formation>? items, bool? hasMore, bool? isLoadingMore}) =>
    PaginatedFormations(items: items ?? this.items, hasMore: hasMore ?? this.hasMore, isLoadingMore: isLoadingMore ?? this.isLoadingMore);
}

class FormationsNotifier extends AsyncNotifier<PaginatedFormations> {
  static const _limit = 20;
  int _offset = 0;
  String? _categoryId;
  String? _level;
  String? get currentCategory => _categoryId;
  String? get currentLevel => _level;

  @override
  Future<PaginatedFormations> build() async {
    _offset = 0;
    final client = ref.watch(supabaseClientProvider);
    final items = await _fetchPage(client, 0);
    _offset = items.length;
    return PaginatedFormations(items: items, hasMore: items.length == _limit);
  }

  Future<List<Formation>> _fetchPage(SupabaseClient client, int offset) async {
    var query = client.from('formations').select('id,title,image_url,rating,price,currency,is_free,category_id,level,created_at');
    if (_categoryId != null) query = query.eq('category_id', _categoryId!);
    if (_level != null) query = query.eq('level', _level!);
    final data = await query.order('created_at', ascending: false).range(offset, offset + _limit - 1);
    return data.map((e) => Formation.fromJson(e)).toList();
  }

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasMore || current.isLoadingMore) return;
    state = AsyncData(current.copyWith(isLoadingMore: true));
    try {
      final client = ref.read(supabaseClientProvider);
      final newItems = await _fetchPage(client, _offset);
      _offset += newItems.length;
      state = AsyncData(PaginatedFormations(items: [...current.items, ...newItems], hasMore: newItems.length == _limit));
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<void> filter({String? categoryId, String? level}) async {
    _categoryId = categoryId;
    _level = level;
    _offset = 0;
    ref.invalidateSelf();
  }

  Future<void> filterByCategory(String? c) => filter(categoryId: c, level: _level);
  Future<void> filterByLevel(String? l) => filter(categoryId: _categoryId, level: l);
}

final formationsProvider = AsyncNotifierProvider<FormationsNotifier, PaginatedFormations>(FormationsNotifier.new);

// --- MES COURS PAGINÉS ---
class MyEnrollmentsNotifier extends FamilyAsyncNotifier<List<Enrollment>, String> {
  static const _limit = 20;
  int _offset = 0;
  bool _hasMore = true;
  bool get hasMore => _hasMore;

  @override
  Future<List<Enrollment>> build(String userId) async {
    _offset = 0; _hasMore = true;
    final client = ref.watch(supabaseClientProvider);
    final res = await client.from('enrollments')
     .select('id,progress,status,enrolled_at,created_at,formation:formations(id,title,image_url,rating,price,currency,is_free,category_id,created_at)')
     .eq('uid', userId)
     .order('enrolled_at', ascending: false).range(0, _limit - 1);
    
    _offset = res.length;
    _hasMore = res.length == _limit;
    return res.map((e) => Enrollment.fromJson(e)).toList();
  }

  Future<void> loadMore() async {
    if (!_hasMore || state is AsyncLoading) return; 
    
    // ✅ CORRECTION 2 : Ajout du try/catch pour protéger le state en cas de coupure réseau
    try {
      final client = ref.read(supabaseClientProvider);
      final res = await client.from('enrollments')
       .select('id,progress,status,enrolled_at,created_at,formation:formations(id,title,image_url,rating,price,currency,is_free,category_id,created_at)')
       .eq('uid', arg)
       .order('enrolled_at', ascending: false).range(_offset, _offset + _limit - 1);
      
      if (res.isEmpty) { _hasMore = false; return; }
      _offset += res.length;
      _hasMore = res.length == _limit;
      final newItems = res.map((e) => Enrollment.fromJson(e)).toList();
      state = AsyncData([...state.value ?? [], ...newItems]);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }
}
final myEnrollmentsProvider = AsyncNotifierProvider.family<MyEnrollmentsNotifier, List<Enrollment>, String>(MyEnrollmentsNotifier.new);

// --- CERTIFICATS ---
final certificatesProvider = FutureProvider.family<List<Certificate>, String>((ref, String userId) async {
  final client = ref.watch(supabaseClientProvider);
  final res = await client.from('certificates').select('id,formation_id,verification_hash,issued_at,created_at').eq('user_id', userId).order('issued_at', ascending: false).limit(100);
  return res.map((e) => Certificate.fromJson(e)).toList();
});

final recommendationsProvider = FutureProvider.family<List<Formation>, String>((ref, String userId) async {
  final client = ref.watch(supabaseClientProvider);
  final res = await client.from('recommendations').select('formation:formations(id,title,image_url,rating,price,currency,is_free)').eq('user_id', userId).limit(10);
  return res.where((e) => e['formation'] != null).map((e) => Formation.fromJson(e['formation'] as Map<String,dynamic>)).toList();
});

final formationDetailProvider = FutureProvider.family<Formation?, String>((ref, String formationId) async {
  final client = ref.watch(supabaseClientProvider);
  
  final res = await client.from('formations').select('''
    id,
    title,
    description,
    image_url,
    rating,
    price,
    currency,
    is_free,
    category_id,
    level,
    created_at,
    category:categories(id,name),
    modules(
      id,
      title,
      order_index,
      lessons(
        id,
        title,
        description,
        content,
        duration_minutes,
        order_index,
        type,
        module_id
      )
    )
  ''').eq('id', formationId).maybeSingle();
  
  // ✅ CORRECTION 4 : Tri explicite en mémoire des modules et des leçons
  if (res != null && res['modules'] != null) {
    final modulesList = res['modules'] as List;
    modulesList.sort((a, b) => (a['order_index'] as int? ?? 0).compareTo(b['order_index'] as int? ?? 0));
    
    for (var module in modulesList) {
      if (module['lessons'] != null) {
        (module['lessons'] as List).sort((a, b) => (a['order_index'] as int? ?? 0).compareTo(b['order_index'] as int? ?? 0));
      }
    }
  }
  
  return res == null ? null : Formation.fromJson(res);
});

final enrollmentProvider = FutureProvider.family<dynamic, ({String userId, String formationId})>((ref, params) async {
  final client = ref.watch(supabaseClientProvider);

  return await client
      .from('enrollments')
      .select('id,progress,status')
      .eq('uid', params.userId)
      .eq('formation_id', params.formationId)
      .maybeSingle();
});

class EnrollNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<bool> enroll({
    required String userId,
    required String formationId,
  }) async {
    state = const AsyncLoading();

    try {
      final client = ref.read(supabaseClientProvider);

      final existing = await client
          .from('enrollments')
          .select('id')
          .eq('uid', userId)
          .eq('formation_id', formationId)
          .maybeSingle();

      if (existing != null) {
        ref.invalidate(
          enrollmentProvider(
            (userId: userId, formationId: formationId),
          ),
        );

        state = const AsyncData(null);
        return true;
      }

      await client.from('enrollments').insert({
        'uid': userId,
        'formation_id': formationId,
        'status': 'active',
        'progress': 0,
        'enrolled_at': DateTime.now().toIso8601String(),
      });

      ref.invalidate(
        enrollmentProvider(
          (userId: userId, formationId: formationId),
        ),
      );

      ref.invalidate(myEnrollmentsProvider(userId));
      
      // ✅ CORRECTION 3 : Suppression de ref.invalidate(formationsProvider) 
      // pour éviter de recharger le catalogue entier inutilement.

      state = const AsyncData(null);
      return true;
    } catch (e, st) {
      state = AsyncError(e, st);
      return false;
    }
  }
}
final enrollProvider = AsyncNotifierProvider<EnrollNotifier, void>(EnrollNotifier.new);

// --- RECHERCHE ---
class SearchFormationsNotifier extends AsyncNotifier<PaginatedFormations> {
  static const _limit = 20;
  int _offset = 0;
  String _query = '';
  Timer? _debounce;
  bool _hasMore = false;
  String get query => _query;
  bool get hasMore => _hasMore;

  @override
  Future<PaginatedFormations> build() async {
    ref.onDispose(() => _debounce?.cancel());
    return const PaginatedFormations(items: [], hasMore: false);
  }

  void setQuery(String value) {
    _debounce?.cancel();
    final q = value.trim();
    if (q.isEmpty) {
      _query = ''; _offset = 0; _hasMore = false;
      state = const AsyncData(PaginatedFormations(items: [], hasMore: false));
      return;
    }
    if (q.length < 2) return;
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      _query = q; _offset = 0;
      state = const AsyncLoading();
      try {
        final client = ref.read(supabaseClientProvider);
        final items = await _fetch(client, _query, 0);
        _offset = items.length;
        _hasMore = items.length == _limit;
        state = AsyncData(PaginatedFormations(items: items, hasMore: _hasMore));
      } catch (e, st) {
        state = AsyncError(e, st);
      }
    });
  }

  Future<List<Formation>> _fetch(SupabaseClient client, String q, int offset) async {
    // ✅ CORRECTION 5 : Nettoyage drastique de la requête SQL
    final safeQ = q
        .replaceAll('%', '')
        .replaceAll('_', '')
        .replaceAll(',', '')
        .replaceAll('.', '')
        .replaceAll("'", '')
        .replaceAll('"', '');
        
    final res = await client.from('formations')
        .select('id,title,image_url,rating,price,currency,is_free,category_id,created_at')
        .or('title.ilike.%$safeQ%,description.ilike.%$safeQ%')
        .order('rating', ascending: false)
        .range(offset, offset + _limit - 1);
        
    return res.map((e) => Formation.fromJson(e)).toList();
  }

  Future<void> loadMore() async {
    if (!_hasMore || _query.isEmpty) return;
    final current = state.value;
    if (current == null) return;
    state = AsyncData(current.copyWith(isLoadingMore: true));
    try {
      final client = ref.read(supabaseClientProvider);
      final newItems = await _fetch(client, _query, _offset);
      _offset += newItems.length;
      _hasMore = newItems.length == _limit;
      state = AsyncData(PaginatedFormations(items: [...current.items, ...newItems], hasMore: _hasMore));
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  void clear() {
    _debounce?.cancel();
    _query = ''; _offset = 0; _hasMore = false;
    state = const AsyncData(PaginatedFormations(items: [], hasMore: false));
  }
}
final searchFormationsProvider = AsyncNotifierProvider<SearchFormationsNotifier, PaginatedFormations>(SearchFormationsNotifier.new);
