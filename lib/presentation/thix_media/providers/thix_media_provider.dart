/// Thix Media Providers (Production Enterprise)
/// ✅ Logs structurés + timeouts + sanitization + validation UUID
/// ✅ Pagination fixée (shuffle avant cursor) + _seen optimisé (Set + List)
/// ✅ MediaService singleton + architecture cohérente
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:thix_id/models/media_content.dart';
import 'package:thix_id/services/media_service.dart';

// ============================================================================
// CONSTANTS
// ============================================================================

const Duration _kQueryTimeout = Duration(seconds: 15);
const Duration _kPollingInterval = Duration(seconds: 15);
const int _kMaxPollingErrors = 3;
const int _kMaxSeenItems = 500;
const int _kFetchLimit = 24;

// ============================================================================
// LOGGING
// ============================================================================

class _MediaProviderLogger {
  static const _tag = 'MediaProvider';
  static void info(String m, [Map<String, dynamic>? d]) => _log('INFO', m, d);
  static void warn(String m, [Map<String, dynamic>? d]) => _log('WARN', m, d);
  static void error(String m, [Map<String, dynamic>? d]) => _log('ERROR', m, d);
  static void _log(String l, String m, Map<String, dynamic>? d) {
    if (!kDebugMode && l == 'INFO') return;
    final data = d != null
        ? ' ${d.entries.map((e) => '${e.key}=${e.value}').join(', ')}'
        : '';
    debugPrint('[$_tag] [$l] $m$data');
  }
}

// ============================================================================
// VALIDATORS
// ============================================================================

class _MediaProviderValidators {
  static final _uuidRegex = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
    caseSensitive: false,
  );

  static bool isValidUuid(String? id) {
    if (id == null || id.isEmpty) return false;
    return _uuidRegex.hasMatch(id);
  }

  /// Échappe les caractères spéciaux SQL LIKE pour éviter injection
  static String sanitizeSearchQuery(String? input) {
    if (input == null || input.isEmpty) return '';
    return input
        .replaceAll('%', '\\%')
        .replaceAll('_', '\\_')
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '')
        .trim()
        .substring(0, input.length.clamp(0, 100));
  }
}

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
  final isAdmin = role == 'admin' || role == 'superadmin';
  _MediaProviderLogger.info('Admin check', {'userId': u.id, 'isAdmin': isAdmin});
  return isAdmin;
});

// ============================================================================
// MEDIA COUNTS POLLING (renommé : c'est du polling, pas un vrai stream)
// ============================================================================

final mediaCountsPollingProvider = StreamProvider.autoDispose.family<MediaCounts, String>((ref, mediaId) async* {
  if (!_MediaProviderValidators.isValidUuid(mediaId)) {
    _MediaProviderLogger.warn('Invalid mediaId for polling', {'mediaId': mediaId});
    yield const MediaCounts(likeCount: 0, viewCount: 0, commentCount: 0);
    return;
  }

  int consecutiveErrors = 0;

  while (consecutiveErrors < _kMaxPollingErrors) {
    try {
      final r = await Supabase.instance.client
          .from('media_stats')
          .select('like_count,view_count,comment_count')
          .eq('media_id', mediaId)
          .maybeSingle()
          .timeout(_kQueryTimeout);

      yield MediaCounts(
        likeCount: (r?['like_count'] as int?) ?? 0,
        viewCount: (r?['view_count'] as int?) ?? 0,
        commentCount: (r?['comment_count'] as int?) ?? 0,
      );
      consecutiveErrors = 0;
    } catch (e) {
      consecutiveErrors++;
      _MediaProviderLogger.warn('Polling error', {
        'mediaId': mediaId,
        'consecutiveErrors': consecutiveErrors,
        'error': '$e',
      });
      if (consecutiveErrors >= _kMaxPollingErrors) break;
    }
    await Future.delayed(_kPollingInterval);
  }
});

// Alias pour compatibilité (deprecated)
@Deprecated('Use mediaCountsPollingProvider instead')
final mediaCountsStreamProvider = mediaCountsPollingProvider;

// ============================================================================
// COMMENT COUNT PROVIDER
// ============================================================================

final commentCountProvider = FutureProvider.autoDispose.family<int, String>((ref, mediaId) async {
  if (!_MediaProviderValidators.isValidUuid(mediaId)) {
    _MediaProviderLogger.warn('Invalid mediaId for commentCount', {'mediaId': mediaId});
    return 0;
  }

  try {
    final r = await Supabase.instance.client
        .from('media_stats')
        .select('comment_count')
        .eq('media_id', mediaId)
        .maybeSingle()
        .timeout(_kQueryTimeout);
    return (r?['comment_count'] as int?) ?? 0;
  } catch (e) {
    _MediaProviderLogger.error('commentCount failed', {'mediaId': mediaId, 'error': '$e'});
    return 0;
  }
});

// ============================================================================
// CREATOR & FOLLOW PROVIDERS
// ============================================================================

final mediaCreatorIdProvider = FutureProvider.autoDispose.family<String?, String>((ref, mediaId) async {
  if (!_MediaProviderValidators.isValidUuid(mediaId)) {
    _MediaProviderLogger.warn('Invalid mediaId for creatorId', {'mediaId': mediaId});
    return null;
  }

  try {
    final res = await Supabase.instance.client
        .from('media_content')
        .select('user_id')
        .eq('id', mediaId)
        .maybeSingle()
        .timeout(_kQueryTimeout);
    return res?['user_id'] as String?;
  } catch (e) {
    _MediaProviderLogger.error('creatorId failed', {'mediaId': mediaId, 'error': '$e'});
    return null;
  }
});

final userProfileProvider = FutureProvider.autoDispose.family<Map<String, dynamic>?, String>((ref, userId) async {
  if (!_MediaProviderValidators.isValidUuid(userId)) {
    _MediaProviderLogger.warn('Invalid userId for profile', {'userId': userId});
    return null;
  }

  try {
    return await Supabase.instance.client
        .from('profiles')
        .select('username, full_name, avatar_url, role')
        .eq('id', userId)
        .maybeSingle()
        .timeout(_kQueryTimeout);
  } catch (e) {
    _MediaProviderLogger.error('userProfile failed', {'userId': userId, 'error': '$e'});
    return null;
  }
});

final isFollowingProvider = FutureProvider.autoDispose.family<bool, String>((ref, targetId) async {
  final uid = Supabase.instance.client.auth.currentUser?.id;
  if (uid == null || !_MediaProviderValidators.isValidUuid(targetId)) return false;
  
  // ✅ FIX : un utilisateur ne peut pas se follow lui-même
  if (uid == targetId) return false;

  try {
    final res = await Supabase.instance.client
        .from('follows')
        .select()
        .eq('follower_id', uid)
        .eq('following_id', targetId)
        .maybeSingle()
        .timeout(_kQueryTimeout);
    return res != null;
  } catch (e) {
    _MediaProviderLogger.error('isFollowing failed', {'targetId': targetId, 'error': '$e'});
    return false;
  }
});

// ============================================================================
// MAIN MEDIA LIST PROVIDER (StateNotifier)
// ============================================================================

class ThixMediaNotifier extends StateNotifier<AsyncValue<List<MediaContent>>> {
  ThixMediaNotifier(this.ref) : super(const AsyncValue.loading()) {
    _load();
    _categoryListener = ref.listen(selectedCategoryProvider, (_, __) => refresh());
    _searchListener = ref.listen(searchQueryProvider, (_, __) => refresh());
  }

  final Ref ref;
  Listener? _categoryListener;
  Listener? _searchListener;

  DateTime? _cursor;
  bool _hasMore = true;
  bool _loading = false;

  // ✅ FIX : Set pour O(1) contains + List pour ordre d'insertion
  final Set<String> _seenSet = {};
  final List<String> _seenList = [];

  @override
  void dispose() {
    _categoryListener?.close();
    _searchListener?.close();
    _MediaProviderLogger.info('ThixMediaNotifier disposed');
    super.dispose();
  }

  Future<void> _load() => refresh();

  Future<void> refresh() async {
    _cursor = null;
    _hasMore = true;
    _seenSet.clear();
    _seenList.clear();
    state = const AsyncValue.loading();

    try {
      final list = await _fetch(null);
      if (!mounted) return;
      state = AsyncValue.data(list);
      _MediaProviderLogger.info('Refresh successful', {'count': list.length});
    } catch (e, st) {
      if (!mounted) return;
      _MediaProviderLogger.error('Refresh failed', {'error': '$e'});
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> loadMore() async {
    if (_loading || !_hasMore || state.value == null) return;
    _loading = true;

    try {
      final moreItems = await _fetch(_cursor);
      if (!mounted) return;

      if (moreItems.length < _kFetchLimit) {
        _hasMore = false;
      }

      state = AsyncValue.data([...state.value!, ...moreItems]);
      _MediaProviderLogger.info('Load more successful', {'count': moreItems.length, 'total': state.value!.length});
    } catch (e) {
      _MediaProviderLogger.error('Load more failed', {'error': '$e'});
    } finally {
      _loading = false;
    }
  }

  Future<List<MediaContent>> _fetch(DateTime? cursor) async {
    final category = ref.read(selectedCategoryProvider);
    final searchRaw = ref.read(searchQueryProvider);
    final search = _MediaProviderValidators.sanitizeSearchQuery(searchRaw);
    final service = MediaService();

    // Fil spécial (feed vidéo)
    if (category == 'Fil' && search.isEmpty) {
      final page = await service.fetchShuffledFeed(
        seenIds: _seenList,
        limit: _kFetchLimit,
      );
      _addToSeen(page.items.map((e) => e.id));
      if (page.items.isNotEmpty) {
        _cursor = page.items.last.createdAt;
      }
      return page.items;
    }

    // Catalogue classique
    var query = Supabase.instance.client
        .from('media_content')
        .select('*, media_stats(*)');

    if (cursor != null) {
      query = query.lt('created_at', cursor.toUtc().toIso8601String());
    }

    if (search.isNotEmpty) {
      query = query.ilike('title', '%$search%');
    } else if (category == 'Tous') {
      query = query.neq('type', 'Fil');
    } else if (category != 'Fil') {
      query = query.eq('type', category);
    }

    final result = await query
        .order('created_at', ascending: false)
        .limit(_kFetchLimit)
        .timeout(_kQueryTimeout);

    var list = (result as List)
        .map((it) => MediaContent.fromJson(Map<String, dynamic>.from(it as Map)))
        .toList();

    // ✅ FIX : shuffle AVANT de prendre le curseur (sinon curseur pointe vers mauvais item)
    if (search.isEmpty && category == 'Tous') {
      list.shuffle();
    }

    // Curseur basé sur le dernier item APRÈS shuffle
    if (list.isNotEmpty) {
      _cursor = list.last.createdAt;
    }

    _addToSeen(list.map((e) => e.id));
    return list;
  }

  void _addToSeen(Iterable<String> ids) {
    for (var id in ids) {
      if (!_seenSet.contains(id)) {
        _seenSet.add(id);
        _seenList.insert(0, id);
        if (_seenList.length > _kMaxSeenItems) {
          final removed = _seenList.removeLast();
          _seenSet.remove(removed);
        }
      }
    }
  }
}

final thixMediaListProvider = StateNotifierProvider.autoDispose<ThixMediaNotifier, AsyncValue<List<MediaContent>>>(
  (ref) => ThixMediaNotifier(ref),
);

// ============================================================================
// BANNER PROVIDER (watch correct pour reactivity)
// ============================================================================

final bannerItemsProvider = Provider.autoDispose<List<MediaContent>>((ref) {
  final asyncList = ref.watch(thixMediaListProvider);
  return asyncList.whenOrNull(data: (list) => list.take(6).toList()) ?? [];
});
