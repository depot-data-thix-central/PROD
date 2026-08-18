import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:thix_id/models/network_post.dart';
import 'package:thix_id/models/comment.dart';

class PostDetailPage extends ConsumerStatefulWidget {
  final String postId;
  final String currentProfileId;
  const PostDetailPage({super.key, required this.postId, required this.currentProfileId});
  @override
  ConsumerState<PostDetailPage> createState() => _PostDetailPageState();
}

class _PostDetailPageState extends ConsumerState<PostDetailPage> {
  final _commentCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _focus = FocusNode();
  NetworkPost? _post;
  List<Comment> _comments = [];
  bool _loading = true;
  bool _submitting = false;
  String? _replyId;
  String? _replyName;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    _scrollCtrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
    });
    final supa = Supabase.instance.client;
    try {
      final p = await supa.from('network_posts').select('*, profiles!network_posts_user_id_fkey(display_name, photo_url, avatar_url)').eq('id', widget.postId).single();
      final c = await supa.from('comments').select('*, profiles(display_name, photo_url)').eq('post_id', widget.postId).order('created_at');
      if (!mounted) return;
      setState(() {
        _post = NetworkPost.fromJson({
          ...p,
          'author_name': p['profiles']?['display_name'],
          'author_avatar': p['profiles']?['photo_url'] ?? p['profiles']?['avatar_url']
        });
        _comments = (c as List).map((e) => Comment.fromJson(e)).toList();
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

  Future<void> _submit({String? parentId}) async {
    final txt = _commentCtrl.text.trim();
    if (txt.isEmpty || _submitting) return;
    setState(() {
      _submitting = true;
    });
    try {
      final supa = Supabase.instance.client;
      final uid = supa.auth.currentUser!.id;
      final res = await supa.from('comments').insert({'post_id': widget.postId, 'user_id': uid, 'content': txt, 'parent_id': parentId}).select().single();
      if (mounted) {
        setState(() {
          _comments.insert(0, Comment.fromJson(res));
          _commentCtrl.clear();
          _replyId = null;
          _replyName = null;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  Future<void> _toggleLike(Comment cm) async {
    final old = cm.isLiked;
    final count = cm.likesCount;
    setState(() {
      cm.isLiked = !old;
      cm.likesCount = old ? count - 1 : count + 1;
    });
    try {
      final supa = Supabase.instance.client;
      if (cm.isLiked) {
        await supa.from('comment_likes').insert({'comment_id': cm.id, 'user_id': supa.auth.currentUser!.id});
      } else {
        await supa.from('comment_likes').delete().eq('comment_id', cm.id).eq('user_id', supa.auth.currentUser!.id);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          cm.isLiked = old;
          cm.likesCount = count;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Publication', style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh))],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _post == null
              ? const Center(child: Text('Introuvable'))
              : Column(
                  children: [
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: _load,
                        child: CustomScrollView(
                          controller: _scrollCtrl,
                          slivers: [
                            SliverToBoxAdapter(
                              child: Container(
                                margin: const EdgeInsets.all(12),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(children: [
                                      CircleAvatar(radius: 20, child: _post!.authorAvatar != null ? ClipOval(child: Image.network(_post!.authorAvatar!, width: 40, height: 40, fit: BoxFit.cover, errorBuilder: (a, b, c) => const Icon(Icons.person))) : const Icon(Icons.person)),
                                      const SizedBox(width: 10),
                                      Expanded(child: Text(_post!.authorName ?? 'User', style: const TextStyle(fontWeight: FontWeight.bold))),
                                    ]),
                                    const SizedBox(height: 12),
                                    Text(_post!.content),
                                    // 🔴 CORRECTION ICI : imageUrls (au pluriel) et imageUrls.first
                                    if (_post!.imageUrls.isNotEmpty) ...[
                                      const SizedBox(height: 12),
                                      ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.network(_post!.imageUrls.first, errorBuilder: (a, b, c) => const SizedBox()))
                                    ],
                                  ],
                                ),
                              ),
                            ),
                            _comments.isEmpty
                                ? SliverFillRemaining(child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.comment_outlined, size: 60, color: Colors.grey.shade300), const Text('Aucun commentaire')])))
                                : SliverList(delegate: SliverChildBuilderDelegate((_, i) => _commentTile(_comments[i]), childCount: _comments.length)),
                            const SliverToBoxAdapter(child: SizedBox(height: 80)),
                          ],
                        ),
                      ),
                    ),
                    _inputBar(),
                  ],
                ),
    );
  }

  Widget _commentTile(Comment c) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6)]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            leading: CircleAvatar(radius: 18, child: c.userAvatar != null ? ClipOval(child: Image.network(c.userAvatar!, width: 36, height: 36, fit: BoxFit.cover, errorBuilder: (a, b, c) => const Icon(Icons.person, size: 18))) : const Icon(Icons.person, size: 18)),
            title: Row(children: [Text(c.userName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)), const SizedBox(width: 6), Text(timeago.format(c.createdAt, locale: 'fr'), style: const TextStyle(fontSize: 10, color: Colors.grey))]),
            dense: true,
          ),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Text(c.content, style: const TextStyle(fontSize: 14))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(children: [
              InkWell(onTap: () => _toggleLike(c), child: Row(children: [Icon(c.isLiked ? Icons.favorite : Icons.favorite_border, size: 16, color: c.isLiked ? Colors.red : Colors.grey), const SizedBox(width: 4), Text(c.likesCount > 0 ? '${c.likesCount}' : '', style: const TextStyle(fontSize: 11))])),
              const SizedBox(width: 16),
              InkWell(onTap: () { setState(() { _replyId = c.id; _replyName = c.userName; }); _focus.requestFocus(); }, child: Row(children: const [Icon(Icons.reply, size: 16, color: Colors.grey), SizedBox(width: 4), Text('Répondre', style: TextStyle(fontSize: 11))])),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _inputBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, -2))]),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_replyId != null)
            Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(20)),
              child: Row(children: [
                const Icon(Icons.reply, size: 14, color: Colors.blue),
                const SizedBox(width: 6),
                Text('Réponse à $_replyName', style: const TextStyle(fontSize: 12, color: Colors.blue)),
                const Spacer(),
                InkWell(onTap: () { setState(() { _replyId = null; _replyName = null; }); }, child: const Icon(Icons.close, size: 16))
              ]),
            ),
          Row(children: [
            Expanded(child: TextField(controller: _commentCtrl, focusNode: _focus, onSubmitted: (_) => _submit(parentId: _replyId), decoration: InputDecoration(hintText: _replyId != null ? 'Écrire une réponse...' : 'Écrire un commentaire...', border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none), filled: true, fillColor: Colors.grey.shade100, contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10)))),
            const SizedBox(width: 8),
            CircleAvatar(backgroundColor: const Color(0xFF2D6CDF), radius: 22, child: IconButton(icon: _submitting ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.send, color: Colors.white, size: 20), onPressed: _submitting ? null : () => _submit(parentId: _replyId))),
          ]),
        ],
      ),
    );
  }
}
