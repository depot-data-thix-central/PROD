import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:thix_id/models/media_content.dart';
import 'package:thix_id/services/media_service.dart';
import '../utils/media_constants.dart';

// ============================================================================
// STATE PROVIDERS (avec autoDispose)
// ============================================================================
final selectedCategoryProvider = StateProvider.autoDispose<String>((ref) => "Tous");
final searchQueryProvider = StateProvider.autoDispose<String>((ref) => "");

// ============================================================================
// ADMIN PROVIDER
// ============================================================================
final isMediaAdminProvider = FutureProvider.autoDispose<bool>((ref) async {
  final u = Supabase.instance.client.auth.currentUser;
  if (u == null) return false;
  final role = u.appMetadata['role'] ?? u.userMetadata?['role'];
  return role == 'admin' || role == 'superadmin';
});

// ============================================================================
// MEDIA STATS STREAM (avec cleanup automatique)
// ============================================================================
final mediaCountsStreamProvider = StreamProvider.autoDispose.family<MediaCounts, String>((ref, mediaId) async* {
  int errorCount = 0;
  const maxErrors = 3;
  
  while (errorCount < maxErrors) {
    try {
      final r = await Supabase.instance.client
          .from('media_stats')
          .select('like_count,view_count,comment_count')
          .eq('media_id', mediaId)
          .maybeSingle();
      
      yield MediaCounts(
        likeCount: (r?['like_count'] as int?) ?? 0,
        viewCount: (r?['view_count'] as int?) ?? 0,
        commentCount: (r?['comment_count'] as int?) ?? 0,
      );
      errorCount = 0;
    } catch (e) {
      errorCount++;
      if (errorCount >= maxErrors) break;
    }
    await Future.delayed(const Duration(seconds: 15));
  }
});

// ============================================================================
// COMMENT COUNT PROVIDER
// ============================================================================
final commentCountProvider = FutureProvider.autoDispose.family<int, String>((ref, mediaId) async {
  try {
    final r = await Supabase.instance.client
        .from('media_stats')
        .select('comment_count')
        .eq('media_id', mediaId)
        .maybeSingle();
    return (r?['comment_count'] as int?) ?? 0;
  } catch (_) {
    return 0;
  }
});

// ============================================================================
// CREATOR & FOLLOW PROVIDERS
// ============================================================================
final mediaCreatorIdProvider = FutureProvider.autoDispose.family<String?, String>((ref, mediaId) async {
  if (mediaId.isEmpty) return null;
  try {
    final res = await Supabase.instance.client
        .from('media_content')
        .select('user_id')
        .eq('id', mediaId)
        .maybeSingle();
    return res?['user_id'] as String?;
  } catch (_) {
    return null;
  }
});

final userProfileProvider = FutureProvider.autoDispose.family<Map<String, dynamic>?, String>((ref, userId) async {
  if (userId.isEmpty) return null;
  try {
    return await Supabase.instance.client
        .from('profiles')
        .select('username, full_name, avatar_url, role')
        .eq('id', userId)
        .maybeSingle();
  } catch (_) {
    return null;
  }
});

final isFollowingProvider = FutureProvider.autoDispose.family<bool, String>((ref, targetId) async {
  final uid = Supabase.instance.client.auth.currentUser?.id;
  if (uid == null || uid == targetId) return true;
  try {
    final res = await Supabase.instance.client
        .from('follows')
        .select()
        .eq('follower_id', uid)
        .eq('following_id', targetId)
        .maybeSingle();
    return res != null;
  } catch (_) {
    return false;
  }
});

// ============================================================================
// MAIN MEDIA LIST PROVIDER (StateNotifier)
// ============================================================================
class ThixMediaNotifier extends StateNotifier<AsyncValue<List<MediaContent>>> {
  ThixMediaNotifier(this.ref) : super(const AsyncValue.loading()) {
    _load();
    ref.listen(selectedCategoryProvider, (_, __) => refresh());
    ref.listen(searchQueryProvider, (_, __) => refresh());
  }

  final Ref ref;
  DateTime? _cursor;
  bool _hasMore = true;
  bool _loading = false;
  final List<String> _seen = [];
  static const int _maxSeenItems = 500;
  static const int _limit = 24;

  Future<void> _load() => refresh();

  Future<void> refresh() async {
    _cursor = null;
    _hasMore = true;
    _seen.clear();
    state = const AsyncValue.loading();
    try {
      final l = await _fetch(null);
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
      final p = await svc.fetchShuffledFeed(seenIds: _seen, limit: _limit);
      _addToSeen(p.items.map((e) => e.id));
      if (p.items.isNotEmpty) _cursor = p.items.last.createdAt;
      return p.items;
    }

    var q = Supabase.instance.client.from('media_content').select('*, media_stats(*)');
    if (cur != null) q = q.lt('created_at', cur.toUtc().toIso8601String());

    if (search.isNotEmpty) {
      q = q.ilike('title', '%$search%');
    } else if (cat == 'Tous') {
      q = q.neq('type', 'Fil');
    } else if (cat != 'Fil') {
      q = q.eq('type', cat);
    }

    final res = await q.order('created_at', ascending: false).limit(_limit);
    final list = (res as List).map((it) {
      return MediaContent.fromJson(Map<String, dynamic>.from(it as Map));
    }).toList();

    if (list.isNotEmpty) _cursor = list.last.createdAt;
    if (search.isEmpty && cat == 'Tous') list.shuffle();

    _addToSeen(list.map((e) => e.id));
    return list;
  }

  void _addToSeen(Iterable<String> ids) {
    for (var id in ids) {
      if (!_seen.contains(id)) {
        _seen.insert(0, id);
        if (_seen.length > _maxSeenItems) _seen.removeLast();
      }
    }
  }
}

final thixMediaListProvider = StateNotifierProvider.autoDispose<ThixMediaNotifier, AsyncValue<List<MediaContent>>>(
  (ref) => ThixMediaNotifier(ref),
);

final bannerItemsProvider = Provider.autoDispose<List<MediaContent>>((ref) {
  return ref.watch(thixMediaListProvider).valueOrNull?.take(6).toList() ?? [];
});
