import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class HashtagPage extends StatefulWidget {
  final String tag;
  const HashtagPage({super.key, required this.tag});
  @override State<HashtagPage> createState() => _HashtagPageState();
}

class _HashtagPageState extends State<HashtagPage> {
  List<Map<String, dynamic>> posts = [];
  bool loading = true;
  bool isFollowingTag = false;
  String sort = 'recent';

  @override void initState() {
    super.initState();
    _checkFollow();
    load();
  }

  Future<void> _checkFollow() async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;
    try {
      final r = await Supabase.instance.client.from('hashtag_follows').select('hashtag').eq('user_id', uid).eq('hashtag', widget.tag).maybeSingle();
      if (mounted) setState(() { isFollowingTag = r != null; });
    } catch (_) {}
  }

  Future<void> load() async {
    setState(() { loading = true; });
    try {
      final supa = Supabase.instance.client;
      // FIX TYPAGE : on build la requête en une fois
      final res = sort == 'popular'
          ? await supa.from('network_posts').select('id, content, image_url, media_urls, likes_count, created_at, profiles!network_posts_user_id_fkey(display_name, photo_url)').ilike('content', '%#${widget.tag}%').order('likes_count', ascending: false).limit(50)
          : await supa.from('network_posts').select('id, content, image_url, media_urls, likes_count, created_at, profiles!network_posts_user_id_fkey(display_name, photo_url)').ilike('content', '%#${widget.tag}%').order('created_at', ascending: false).limit(50);

      if (mounted) {
        setState(() {
          posts = (res as List).cast<Map<String, dynamic>>();
          loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() { loading = false; });
    }
  }

  Future<void> toggleFollow() async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;
    setState(() { isFollowingTag = !isFollowingTag; });
    try {
      if (isFollowingTag) {
        await Supabase.instance.client.from('hashtag_follows').insert({'user_id': uid, 'hashtag': widget.tag});
      } else {
        await Supabase.instance.client.from('hashtag_follows').delete().eq('user_id', uid).eq('hashtag', widget.tag);
      }
    } catch (_) {
      if (mounted) setState(() { isFollowingTag = !isFollowingTag; });
    }
  }

  @override Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text('#${widget.tag}'),
        actions: [
          TextButton(onPressed: toggleFollow, child: Text(isFollowingTag ? 'Suivi' : 'Suivre')),
          PopupMenuButton<String>(onSelected: (v) { sort = v; load(); }, itemBuilder: (_) => [const PopupMenuItem(value: 'recent', child: Text('Récent')), const PopupMenuItem(value: 'popular', child: Text('Populaire'))]),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : posts.isEmpty
              ? const Center(child: Text('Aucun post pour ce hashtag'))
              : RefreshIndicator(
                  onRefresh: load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: posts.length,
                    itemBuilder: (_, i) {
                      final p = posts[i];
                      final prof = p['profiles'] as Map<String, dynamic>?;
                      final img = p['image_url'];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                        child: ListTile(
                          leading: CircleAvatar(child: Text(prof?['display_name']?[0] ?? '#')),
                          title: Text(prof?['display_name'] ?? 'User', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            const SizedBox(height: 4),
                            Text(p['content'] ?? ''),
                            if (img != null) Padding(padding: const EdgeInsets.only(top: 8), child: Image.network(img, height: 150, fit: BoxFit.cover)),
                          ]),
                          onTap: () => context.push('/network/post/${p['id']}'),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
