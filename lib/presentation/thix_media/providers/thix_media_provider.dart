/// Thix Media Providers — Riverpod (Production Enterprise)
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:thix_id/models/media_content.dart';
import 'package:thix_id/services/media_service.dart';

const Duration _kQueryTimeout = Duration(seconds: 15);
const Duration _kPollingInterval = Duration(seconds: 15);
const int _kMaxPollingErrors = 3;
const int _kMaxSeenItems = 500;
const int _kFetchLimit = 24;

class MediaCounts {
  final int likeCount;
  final int viewCount;
  final int commentCount;

  const MediaCounts({
    required this.likeCount,
    required this.viewCount,
    required this.commentCount,
  });
}

class _MediaProviderLogger {
  static const _tag = 'MediaProvider';

  static void info(String m, [Map<String, dynamic>? d]) => _log('INFO', m, d);
  static void warn(String m, [Map<String, dynamic>? d]) => _log('WARN', m, d);
  static void error(String m, [Map<String, dynamic>? d]) => _log('ERROR', m, d);

  static void _log(String l, String m, Map<String, dynamic>? d) {
    if (!kDebugMode && l == 'INFO') return;
    // CORRECTION : Syntaxe de l'interpolation de chaîne réparée
    final data = d == null
        ? ''
        : ' ${d.entries.map((e) => '${e.key}=${e.value}').join(', ')}';
    debugPrint('[$_tag] [$l] $m$data');
  }
}

class _MediaProviderValidators {
  static final _uuidRegex = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
    caseSensitive: false,
  );

  static bool isValidUuid(String? id) {
    if (id == null || id.isEmpty) return false;
    return _uuidRegex.hasMatch(id);
  }

  static String sanitizeSearchQuery(String? input) {
    if (input == null || input.isEmpty) return '';
    final cleaned = input
        .replaceAll('%', '\\%')
        .replaceAll('_', '\\_')
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '')
        .trim();
    if (cleaned.isEmpty) return '';
    final end = cleaned.length > 100 ? 100 : cleaned.length;
    return cleaned.substring(0, end);
  }
}

final selectedCategoryProvider =
    StateProvider.autoDispose<String>((ref) => 'Tous');
final searchQueryProvider = StateProvider.autoDispose<String>((ref) => '');

final isMediaAdminProvider = FutureProvider.autoDispose<bool>((ref) async {
  final u = Supabase.instance.client.auth.currentUser;
  if (u == null) return false;
  final role = u.appMetadata['role'] ?? u.userMetadata?['role'];
  final isAdmin = role == 'admin' || role == 'superadmin';
  _MediaProviderLogger.info('Admin check', {
    'userId': u.id,
    'isAdmin': isAdmin,
  });
  return isAdmin;
});

final mediaCountsPollingProvider =
    StreamProvider.autoDispose.family<MediaCounts, String>((ref, mediaId) async* {
  if (!_MediaProviderValidators.isValidUuid(mediaId)) {
    _MediaProviderLogger.warn('Invalid mediaId for polling', {
      'mediaId': mediaId,
    });
    yield const MediaCounts(likeCount: 0, viewCount: 0, commentCount: 0);
    return;
  }

  var consecutiveErrors = 0;
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
    await Future<void>.delayed(_kPollingInterval);
  }
});

@Deprecated('Use mediaCountsPollingProvider instead')
final mediaCountsStreamProvider = mediaCountsPollingProvider;

final commentCountProvider =
    FutureProvider.autoDispose.family<int, String>((ref, mediaId) async {
  if (!_MediaProviderValidators.isValidUuid(mediaId)) {
    _MediaProviderLogger.warn('Invalid mediaId for commentCount', {
      'mediaId': mediaId,
    });
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
    _MediaProviderLogger.error('commentCount failed', {
      'mediaId': mediaId,
      'error': '$e',
    });
    return 0;
  }
});

final mediaCreatorIdProvider =
    FutureProvider.autoDispose.family<String?, String>((ref, mediaId) async {
  if (!_MediaProviderValidators.isValidUuid(mediaId)) {
    _MediaProviderLogger.warn('Invalid mediaId for creatorId', {
      'mediaId': mediaId,
    });
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
    _MediaProviderLogger.error('creatorId failed', {
      'mediaId': mediaId,
      'error': '$e',
    });
    return null;
  }
});

final userProfileProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>?, String>((ref, userId) async {
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
    _MediaProviderLogger.error('userProfile failed', {
      'userId': userId,
      'error': '$e',
    });
    return null;
  }
});

final isFollowingProvider =
    FutureProvider.autoDispose.family<bool, String>((ref, targetId) async {
  final uid = Supabase.instance.client.auth.currentUser?.id;
  if (uid == null || !_MediaProviderValidators.isValidUuid(targetId)) {
    return false;
  }
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
    _MediaProviderLogger.error('isFollowing failed', {
      'targetId': targetId,
      'error': '$e',
    });
    return false;
  }
});

// CORRECTION : Remplacement de AsyncNotifier par AutoDisposeAsyncNotifier
class ThixMediaNotifier extends AutoDisposeAsyncNotifier<List<MediaContent>> {
  DateTime? _cursor;
  bool _hasMore = true;
  bool _loading = false;
  final Set<String> _seenSet = <String>{};
  final List<String> _seenList = <String>[];

  bool get hasMore => _hasMore;

  @override
  Future<List<MediaContent>> build() async {
    ref.listen<String>(selectedCategoryProvider, (prev, next) {
      if (prev != next) {
        refresh();
      }
    });
    ref.listen<String>(searchQueryProvider, (prev, next) {
      if (prev != next) {
        refresh();
      }
    });
    return _fetch(null);
  }

  Future<void> refresh() async {
    _cursor = null;
    _hasMore = true;
    _seenSet.clear();
    _seenList.clear();
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _fetch(null));
    state.whenOrNull(
      data: (list) => _MediaProviderLogger.info('Refresh successful', {
        'count': list.length,
      }),
      error: (e, _) => _MediaProviderLogger.error('Refresh failed', {
        'error': '$e',
      }),
    );
  }

  Future<void> loadMore() async {
    if (_loading || !_hasMore || state.value == null) return;
    _loading = true;
    try {
      final moreItems = await _fetch(_cursor);
      if (moreItems.length < _kFetchLimit) {
        _hasMore = false;
      }
      final current = state.value ?? <MediaContent>[];
      state = AsyncData(<MediaContent>[...current, ...moreItems]);
      _MediaProviderLogger.info('Load more successful', {
        'count': moreItems.length,
        'total': state.value!.length,
      });
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

    if (search.isEmpty && category == 'Tous') {
      list.shuffle();
    }
    if (list.isNotEmpty) {
      _cursor = list.last.createdAt;
    }
    _addToSeen(list.map((e) => e.id));
    return list;
  }

  void _addToSeen(Iterable<String> ids) {
    for (final id in ids) {
      if (_seenSet.add(id)) {
        _seenList.insert(0, id);
        if (_seenList.length > _kMaxSeenItems) {
          final removed = _seenList.removeLast();
          _seenSet.remove(removed);
        }
      }
    }
  }
}

final thixMediaListProvider =
    AsyncNotifierProvider.autoDispose<ThixMediaNotifier, List<MediaContent>>(
  ThixMediaNotifier.new,
);

final bannerItemsProvider = Provider.autoDispose<List<MediaContent>>((ref) {
  final asyncList = ref.watch(thixMediaListProvider);
  return asyncList.whenOrNull(data: (list) => list.take(6).toList()) ??
      const <MediaContent>[];
});
