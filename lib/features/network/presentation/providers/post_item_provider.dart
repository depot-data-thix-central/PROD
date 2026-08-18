import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:thix_id/models/network_post.dart';
import 'package:thix_id/features/network/data/network_service_provider.dart';

/// Provider famille autoDispose = 1 provider par postId = scale millions
/// Chaque PostCard ne rebuild que lui-même
final postItemProvider = StateNotifierProvider.family<PostItemNotifier, NetworkPost, String>(
  (ref, postId) => throw UnimplementedError('overridden in PostCard'),
);

class PostItemNotifier extends StateNotifier<NetworkPost> {
  PostItemNotifier(super.initialPost, this.ref);
  final Ref ref;

  Future<void> toggleLike() async {
    final wasLiked = state.isLiked;
    final oldCount = state.likesCount;
    // optimistic
    state = state.copyWith(isLiked:!wasLiked, likesCount: wasLiked? oldCount - 1 : oldCount + 1);
    try {
      if (wasLiked) {
        await ref.read(networkServiceProvider).unlikePost(state.id);
      } else {
        await ref.read(networkServiceProvider).likePost(state.id);
      }
    } catch (_) {
      state = state.copyWith(isLiked: wasLiked, likesCount: oldCount);
    }
  }

  Future<void> toggleSave() async {
    final wasSaved = state.isSaved;
    state = state.copyWith(isSaved:!wasSaved);
    try {
      if (wasSaved) {
        await ref.read(networkServiceProvider).unsavePost(state.id);
      } else {
        await ref.read(networkServiceProvider).savePost(state.id);
      }
    } catch (_) {
      state = state.copyWith(isSaved: wasSaved);
    }
  }

  void updateContent(String newContent) {
    state = state.copyWith(content: newContent);
  }

  void incrementRepost() {
    state = state.copyWith(repostsCount: state.repostsCount + 1, isReposted: true);
  }
}
