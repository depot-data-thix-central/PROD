// lib/features/network/presentation/providers/user_profile_providers.dart
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:thix_id/features/network/data/network_service_provider.dart';
import 'package:thix_id/models/network_post.dart';

/// Profil public (inclut certification_tier / certification_status pour le sceau)
final userProfileProvider =
    FutureProvider.family<Map<String, dynamic>?, String>((ref, userId) async {
  if (userId.isEmpty) return null;

  try {
    // 1) Essai via network service (si déjà à jour)
    final service = ref.read(networkServiceProvider);
    final fromService = await service.getUserProfile(userId);

    if (fromService != null) {
      // Si le service n'a pas encore les colonnes certif → enrichir
      if (!fromService.containsKey('certification_tier') ||
          !fromService.containsKey('certification_status')) {
        final enriched = await _fetchCertificationFields(userId);
        return {
          ...fromService,
          ...enriched,
        };
      }
      return fromService;
    }

    // 2) Fallback direct Supabase
    return await _fetchProfileWithCertification(userId);
  } catch (e) {
    debugPrint('userProfileProvider error: $e');
    return null;
  }
});

/// Champs certification seuls (enrichissement)
Future<Map<String, dynamic>> _fetchCertificationFields(String userId) async {
  try {
    final row = await Supabase.instance.client
        .from('profiles')
        .select('certification_tier, certification_status, is_verified')
        .eq('id', userId)
        .maybeSingle();

    return {
      'certification_tier': row?['certification_tier'],
      'certification_status': row?['certification_status'],
      'is_verified': row?['is_verified'] ?? false,
    };
  } catch (e) {
    debugPrint('_fetchCertificationFields: $e');
    return {
      'certification_tier': null,
      'certification_status': null,
      'is_verified': false,
    };
  }
}

/// Profil minimal + certification
Future<Map<String, dynamic>?> _fetchProfileWithCertification(
    String userId) async {
  try {
    final row = await Supabase.instance.client
        .from('profiles')
        .select(
          'id, display_name, avatar_url, photo_url, username, '
          'certification_tier, certification_status, is_verified',
        )
        .eq('id', userId)
        .maybeSingle();

    if (row == null) return null;
    return Map<String, dynamic>.from(row);
  } catch (e) {
    debugPrint('_fetchProfileWithCertification: $e');
    return null;
  }
}

final pinnedPostsProvider =
    FutureProvider.family<List<NetworkPost>, String>((ref, userId) async {
  final service = ref.read(networkServiceProvider);
  return await service.getPinnedPosts(userId);
});

final userPostsProvider =
    AsyncNotifierProviderFamily<UserPostsNotifier, List<NetworkPost>, String>(
  UserPostsNotifier.new,
);

class UserPostsNotifier
    extends FamilyAsyncNotifier<List<NetworkPost>, String> {
  int _offset = 0;
  static const _limit = 15;
  bool _hasMore = true;
  bool _isLoadingMore = false;
  bool get hasMore => _hasMore;

  @override
  Future<List<NetworkPost>> build(String userId) async {
    _offset = 0;
    final service = ref.read(networkServiceProvider);
    final posts =
        await service.getUserPosts(userId, offset: 0, limit: _limit);
    _offset = posts.length;
    _hasMore = posts.length == _limit;
    return posts;
  }

  Future<void> loadMore() async {
    if (!_hasMore || _isLoadingMore) return;
    _isLoadingMore = true;
    try {
      final service = ref.read(networkServiceProvider);
      final more =
          await service.getUserPosts(arg, offset: _offset, limit: _limit);
      _hasMore = more.length == _limit;
      _offset += more.length;
      state = AsyncData([...state.valueOrNull ?? [], ...more]);
    } finally {
      _isLoadingMore = false;
    }
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final service = ref.read(networkServiceProvider);
      final posts =
          await service.getUserPosts(arg, offset: 0, limit: _limit);
      _offset = posts.length;
      _hasMore = posts.length == _limit;
      return posts;
    });
  }
}

final followStatusProvider =
    FutureProvider.family<bool, String>((ref, targetId) async {
  final supabase = Supabase.instance.client;
  final me = supabase.auth.currentUser?.id;
  if (me == null || me.isEmpty || targetId.isEmpty || me == targetId) {
    return false;
  }

  try {
    final res = await supabase
        .from('follows')
        .select('follower_id')
        .eq('follower_id', me)
        .eq('following_id', targetId)
        .maybeSingle();
    return res != null;
  } catch (e) {
    debugPrint('followStatusProvider error: $e');
    return false;
  }
});
