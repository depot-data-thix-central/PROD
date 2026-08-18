import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:thix_id/models/comment.dart';
import 'package:thix_id/features/network/data/network_service_provider.dart';

final commentsProvider = AsyncNotifierProviderFamily<Comments, List<Comment>, String>(Comments.new);

class Comments extends FamilyAsyncNotifier<List<Comment>, String> {
  static const int limit = 20;
  int _offset = 0;
  bool _hasMore = true;
  bool get hasMore => _hasMore;

  @override
  Future<List<Comment>> build(String postId) async {
    _offset = 0; _hasMore = true;
    final all = await ref.read(networkServiceProvider).getCommentsWithReplies(arg);
    final page = all.take(limit).toList();
    _offset = page.length;
    _hasMore = all.length > limit;
    return page;
  }

  Future<void> loadMore() async {
    if (!_hasMore) return;
    final all = await ref.read(networkServiceProvider).getCommentsWithReplies(arg);
    if (_offset >= all.length) { _hasMore = false; return; }
    final end = (_offset + limit).clamp(0, all.length);
    final more = all.sublist(_offset, end);
    _offset = end; _hasMore = end < all.length;
    final current = state.valueOrNull ?? [];
    state = AsyncData([...current, ...more]);
  }

  Future<void> addComment(String content, {String? parentId}) async {
    final newComment = await ref.read(networkServiceProvider).addComment(arg, content, parentId: parentId);
    final current = state.valueOrNull ?? [];
    if (parentId == null) {
      state = AsyncData([newComment, ...current]);
    } else {
      for (var c in current) { if (c.id == parentId) { c.replies.insert(0, newComment); break; } }
      state = AsyncData([...current]);
    }
  }
}
