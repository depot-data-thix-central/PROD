import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/forum_topic.dart';

// Provider local pour éviter le cycle d'import
final _supabaseProvider = Provider<SupabaseClient>((ref) => Supabase.instance.client);

class PaginatedForumTopics {
  final List<ForumTopic> items;
  final bool hasMore;
  const PaginatedForumTopics({required this.items, this.hasMore = true});
  PaginatedForumTopics copyWith({List<ForumTopic>? items, bool? hasMore}) =>
    PaginatedForumTopics(items: items ?? this.items, hasMore: hasMore ?? this.hasMore);
}

class ForumTopicsNotifier extends FamilyAsyncNotifier<PaginatedForumTopics, String> {
  static const _limit = 20;
  int _offset = 0;
  bool _hasMore = true;
  bool get hasMore => _hasMore;

  @override
  Future<PaginatedForumTopics> build(String formationId) async {
    _offset = 0; _hasMore = true;
    final client = ref.watch(_supabaseProvider);
    final res = await client.from('forum_topics')
     .select('id,formation_id,title,content,author_id,created_at,pinned,reply_count,author:profiles(id,full_name,avatar_url)')
     .eq('formation_id', formationId)
     .order('pinned', ascending: false).order('created_at', ascending: false)
     .range(0, _limit - 1);
    _offset = res.length;
    _hasMore = res.length == _limit;
    return PaginatedForumTopics(items: res.map((e) => ForumTopic.fromJson(e)).toList(), hasMore: _hasMore);
  }

  Future<void> loadMore() async {
    if (!_hasMore) return;
    final client = ref.read(_supabaseProvider);
    final res = await client.from('forum_topics')
     .select('id,formation_id,title,content,author_id,created_at,pinned,reply_count,author:profiles(id,full_name,avatar_url)')
     .eq('formation_id', arg).order('pinned', ascending: false).order('created_at', ascending: false)
     .range(_offset, _offset + _limit - 1);
    if (res.isEmpty) { _hasMore = false; return; }
    _offset += res.length;
    _hasMore = res.length == _limit;
    final newItems = res.map((e) => ForumTopic.fromJson(e)).toList();
    state = AsyncData(PaginatedForumTopics(items: [...state.value?.items ?? [], ...newItems], hasMore: _hasMore));
  }

  Future<ForumTopic?> createTopic({required String title, required String content}) async {
    final client = ref.read(_supabaseProvider);
    final userId = client.auth.currentUser?.id;
    if (userId == null) return null;
    final res = await client.from('forum_topics').insert({
      'formation_id': arg, 'title': title, 'content': content, 'author_id': userId,
    }).select('id,formation_id,title,content,author_id,created_at,pinned,reply_count').single();
    final topic = ForumTopic.fromJson(res);
    final current = state.value;
    if (current != null) {
      state = AsyncData(current.copyWith(items: [topic, ...current.items]));
    }
    return topic;
  }
}

final forumTopicsProvider = AsyncNotifierProvider.family<ForumTopicsNotifier, PaginatedForumTopics, String>(ForumTopicsNotifier.new);
