import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:thix_id/models/network_post.dart';
import 'package:thix_id/presentation/network/widgets/post_card.dart';

class MyPostsPage extends ConsumerStatefulWidget {
  const MyPostsPage({super.key});
  @override
  ConsumerState<MyPostsPage> createState() => _MyPostsPageState();
}

class _MyPostsPageState extends ConsumerState<MyPostsPage> {
  List<NetworkPost> _posts = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  final ScrollController _scroll = ScrollController();
  int _offset = 0;
  static const int _limit = 15;

  @override
  void initState() {
    super.initState();
    _load();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 300) {
      _loadMore();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
    });
    final supa = Supabase.instance.client;
    final uid = supa.auth.currentUser?.id;
    if (uid == null) {
      setState(() {
        _loading = false;
      });
      return;
    }
    try {
      final res = await supa
         .from('network_posts')
         .select('*, profiles!network_posts_user_id_fkey(display_name, photo_url, avatar_url)')
         .eq('user_id', uid)
         .order('created_at', ascending: false)
         .range(0, _limit - 1);
      if (!mounted) return;
      final list = (res as List).map((e) {
        final prof = e['profiles'] as Map<String, dynamic>?;
        return NetworkPost.fromJson({
         ...e,
          'author_name': prof?['display_name'],
          'author_avatar': prof?['photo_url']?? prof?['avatar_url'],
        });
      }).toList();
      setState(() {
        _posts = list;
        _offset = list.length;
        _hasMore = (res as List).length == _limit;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore ||!_hasMore) return;
    setState(() {
      _loadingMore = true;
    });
    final supa = Supabase.instance.client;
    final uid = supa.auth.currentUser!.id;
    try {
      final res = await supa
         .from('network_posts')
         .select('*, profiles!network_posts_user_id_fkey(display_name, photo_url, avatar_url)')
         .eq('user_id', uid)
         .order('created_at', ascending: false)
         .range(_offset, _offset + _limit - 1);
      if (!mounted) return;
      final more = (res as List).map((e) {
        final prof = e['profiles'] as Map<String, dynamic>?;
        return NetworkPost.fromJson({
         ...e,
          'author_name': prof?['display_name'],
          'author_avatar': prof?['photo_url']?? prof?['avatar_url'],
        });
      }).toList();
      setState(() {
        _posts.addAll(more);
        _offset += more.length;
        _hasMore = (res as List).length == _limit;
        _loadingMore = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadingMore = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = Supabase.instance.client.auth.currentUser?.id?? '';
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('Mes publications', style: TextStyle(color: Color(0xFF0B1B3D), fontWeight: FontWeight.bold)),
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Color(0xFF0B1B3D)), onPressed: () => context.pop()),
      ),
      body: _loading
         ? const Center(child: CircularProgressIndicator(color: Color(0xFFD4AF37)))
          : _posts.isEmpty
             ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.post_add, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('Aucune publication', style: TextStyle(fontWeight: FontWeight.bold)),
                      Text('Vos posts apparaîtront ici', style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  color: const Color(0xFFD4AF37),
                  child: CustomScrollView(
                    controller: _scroll,
                    slivers: [
                      SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (ctx, i) {
                            if (i == _posts.length) {
                              return _loadingMore
                                 ? const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()))
                                  : const SizedBox(height: 80);
                            }
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12, top: 8, left: 12, right: 12),
                              child: PostCard(post: _posts[i], currentProfileId: uid, onTap: () => context.push('/network/post/${_posts[i].id}')),
                            );
                          },
                          childCount: _posts.length + 1,
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}
