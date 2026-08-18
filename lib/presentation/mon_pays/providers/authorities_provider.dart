// lib/presentation/mon_pays/providers/authorities_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../models/authority.dart';
import '../services/authorities_service.dart';

part 'authorities_provider.g.dart';

// ============================================================
// SERVICE PROVIDER (KeepAlive pour éviter de recréer l'instance)
// ============================================================
@Riverpod(keepAlive: true)
AuthoritiesService authoritiesService(Ref ref) {
  return AuthoritiesService();
}

// ============================================================
// PAGINATION AVEC ASYNC NOTIFIER (Scalable)
// ============================================================
@riverpod
class AuthoritiesPaginated extends _$AuthoritiesPaginated {
  int _currentPage = 0;
  final int _limit = 20;
  bool _hasMore = true;

  @override
  FutureOr<PaginatedResult<Authority>> build({
    String? category,
    String? search,
    bool? activeOnly,
  }) async {
    _currentPage = 0;
    _hasMore = true;
    return _fetchPage();
  }

  Future<PaginatedResult<Authority>> _fetchPage({bool append = false}) async {
    final service = ref.read(authoritiesServiceProvider);
    final result = await service.getAuthoritiesPaginated(
      page: _currentPage,
      limit: _limit,
      category: category,
      search: search,
      activeOnly: activeOnly,
    );

    _hasMore = result.hasMore;

    if (append && state.hasValue) {
      final currentData = state.value!;
      return PaginatedResult<Authority>(
        data: [...currentData.data, ...result.data],
        total: result.total,
        page: result.page,
        limit: result.limit,
        hasMore: result.hasMore,
      );
    }
    return result;
  }

  Future<void> loadNextPage() async {
    if (!_hasMore || state.isLoading || state.isReloading) return;

    _currentPage++;
    
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _fetchPage(append: true));
  }
}

// ============================================================
// LECTURE SEULE (Queries)
// ============================================================

@riverpod
Future<List<Authority>> topAuthorities(Ref ref) async {
  final service = ref.watch(authoritiesServiceProvider);
  final all = await service.getActiveAuthorities();

  String normalize(String s) {
    s = s.toLowerCase().trim();
    const accents = 'àáâãäåçèéêëìíîïñòóôõöùúûüýÿ';
    const sansAccents = 'aaaaaaceeeeiiiinooooouuuuyy';
    final sb = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      final index = accents.indexOf(s[i]);
      sb.write(index != -1 ? sansAccents[index] : s[i]);
    }
    return sb.toString();
  }

  final targetTitles = {
    normalize('Président de la République'),
    normalize('Première Ministre'),
    normalize('Président du Sénat'),
    normalize('Président de l\'Assemblée Nationale'),
  };

  final filtered = all.where((a) => targetTitles.contains(normalize(a.title))).toList();

  int getPriority(String title) {
    final t = normalize(title);
    if (t.contains('président de la république')) return 1;
    if (t.contains('première ministre') || t.contains('premier ministre')) return 2;
    if (t.contains('sénat')) return 3;
    if (t.contains('assemblée')) return 4;
    return 99;
  }

  filtered.sort((a, b) => getPriority(a.title).compareTo(getPriority(b.title)));
  return filtered;
}

@riverpod
Future<Authority> authorityDetail(Ref ref, String id) async {
  final service = ref.watch(authoritiesServiceProvider);
  return service.getAuthorityWithRelations(id);
}

@riverpod
Future<List<Authority>> historicalAuthorities(Ref ref) async {
  final service = ref.watch(authoritiesServiceProvider);
  return service.getHistoricalAuthorities();
}

// ============================================================
// ADMIN / MUTATIONS (CUD Operations)
// ============================================================
@riverpod
class AdminAuthorities extends _$AdminAuthorities {
  @override
  FutureOr<List<Authority>> build() async {
    final service = ref.watch(authoritiesServiceProvider);
    return service.getActiveAuthorities();
  }

  /// 🔑 Méthode de rechargement demandée par admin_authorities_page.dart
  Future<void> loadAuthorities() async {
    ref.invalidateSelf();
    await future;
  }

  Future<void> createAuthority(Authority authority) async {
    final service = ref.read(authoritiesServiceProvider);
    
    await AsyncValue.guard(() async {
      await service.createAuthority(authority);
      ref.invalidate(topAuthoritiesProvider);
      ref.invalidateSelf(); 
    });
  }

  Future<void> updateAuthority(Authority authority) async {
    final service = ref.read(authoritiesServiceProvider);
    
    await AsyncValue.guard(() async {
      await service.updateAuthority(authority);
      
      ref.invalidate(topAuthoritiesProvider);
      ref.invalidate(authorityDetailProvider(authority.id)); 
      ref.invalidate(authoritiesPaginatedProvider);
      ref.invalidateSelf();
    });
  }

  Future<void> deleteAuthority(String id) async {
    final service = ref.read(authoritiesServiceProvider);
    
    await AsyncValue.guard(() async {
      await service.deleteAuthority(id);
      
      ref.invalidate(topAuthoritiesProvider);
      ref.invalidate(authorityDetailProvider(id));
      ref.invalidate(authoritiesPaginatedProvider);
      ref.invalidateSelf();
    });
  }

  Future<void> archiveAuthority(String id) async {
    final service = ref.read(authoritiesServiceProvider);
    
    await AsyncValue.guard(() async {
      await service.archiveAuthority(id);
      
      ref.invalidate(topAuthoritiesProvider);
      ref.invalidate(historicalAuthoritiesProvider);
      ref.invalidate(authorityDetailProvider(id));
      ref.invalidate(authoritiesPaginatedProvider);
      ref.invalidateSelf();
    });
  }
}
