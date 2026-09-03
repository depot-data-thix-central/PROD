import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../models/media_content.dart';
import '../../../services/media_service.dart';

final adminFilterProvider = StateProvider<String>((ref) => 'Tous');
final adminSearchProvider = StateProvider<String>((ref) => '');

final adminMediaProvider =
    AsyncNotifierProvider<AdminMediaNotifier, List<MediaContent>>(
  AdminMediaNotifier.new,
);

class AdminMediaNotifier extends AsyncNotifier<List<MediaContent>> {
  static const int _pageSize = 30;

  int _page = 0;
  bool _hasMore = true;

  bool get hasMore => _hasMore;

  MediaService get _service =>
      MediaService(client: Supabase.instance.client);

  @override
  Future<List<MediaContent>> build() async {
    _page = 0;
    _hasMore = true;
    return _fetch();
  }

  Future<List<MediaContent>> _fetch() async {
    final data = await _service.fetchAllMediaPaginated(
      limit: _pageSize,
      offset: _page * _pageSize,
    );
    if (data.length < _pageSize) {
      _hasMore = false;
    }
    return data;
  }

  Future<void> loadMore() async {
    if (!_hasMore || state.isLoading) return;
    _page++;
    final more = await _service.fetchAllMediaPaginated(
      limit: _pageSize,
      offset: _page * _pageSize,
    );
    if (more.length < _pageSize) {
      _hasMore = false;
    }
    state = AsyncData(<MediaContent>[
      ...state.valueOrNull ?? const <MediaContent>[],
      ...more,
    ]);
  }

  Future<void> refreshList() async {
    _page = 0;
    _hasMore = true;
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }

  Future<void> delete(MediaContent item) async {
    await _service.deleteMedia(item);
    state = AsyncData(
      state.valueOrNull?.where((e) => e.id != item.id).toList() ??
          const <MediaContent>[],
    );
  }
}

final filteredAdminProvider = Provider<List<MediaContent>>((ref) {
  final all = ref.watch(adminMediaProvider).valueOrNull ?? const <MediaContent>[];
  final filter = ref.watch(adminFilterProvider);
  final q = ref.watch(adminSearchProvider).toLowerCase().trim();

  Iterable<MediaContent> base = all;
  if (filter == 'Publiés') {
    base = base.where((e) => e.isPublished);
  } else if (filter == 'Brouillons') {
    base = base.where((e) => !e.isPublished);
  } else if (const [
    'Films',
    'Séries',
    'Vidéos',
    'Musique',
    'En direct',
    'Playlists',
  ].contains(filter)) {
    base = base.where((e) => e.type == filter);
  }

  if (q.isNotEmpty) {
    base = base.where(
      (e) =>
          e.title.toLowerCase().contains(q) ||
          (e.subtitle?.toLowerCase().contains(q) ?? false),
    );
  }
  return base.toList();
});
