import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:thix_id/core/theme/thix_design_policy.dart';
import '../providers/thix_media_providers.dart';
import '../utils/media_constants.dart';

class CommentsSheet extends ConsumerStatefulWidget {
  final String mediaId, mediaTitle;
  const CommentsSheet({super.key, required this.mediaId, required this.mediaTitle});

  @override
  ConsumerState<CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends ConsumerState<CommentsSheet> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _sending = false;
  bool _loading = true;

  List<CommentItem> _roots = [];
  final Map<String, List<CommentItem>> _replies = {};
  final Set<String> _expanded = {};
  CommentItem? _replyingTo;
  CommentItem? _editingComment;
  final Set<String> _likedIds = {};
  final Map<String, int> _localCommentLikes = {};

  @override
  void initState() {
    super.initState();
    _fetchRoots();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: MediaColors.danger),
    );
  }

  Future<void> _fetchRoots() async {
    try {
      final res = await Supabase.instance.client
          .from('media_comments')
          .select('id,user_id,user_name,avatar_url,content,created_at,parent_id,like_count,reply_count')
          .eq('media_id', widget.mediaId)
          .isFilter('parent_id', null)
          .order('created_at', ascending: false)
          .limit(50);

      if (mounted) {
        setState(() {
          _roots = (res as List).map((e) => CommentItem.fromMap(e as Map<String, dynamic>)).toList();
          _loading = false;
        });
        _fetchUserLikes();
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loading = false);
        _showError("Impossible de charger les commentaires.");
      }
    }
  }

  Future<void> _fetchUserLikes() async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;
    try {
      final res = await Supabase.instance.client.from('comment_likes').select('comment_id').eq('user_id', uid);
      if (mounted) {
        setState(() => _likedIds.addAll((res as List).map((e) => e['comment_id'] as String)));
      }
    } catch (_) {}
  }

  Future<void> _fetchReplies(String parentId) async {
    try {
      final res = await Supabase.instance.client
          .from('media_comments')
          .select('id,user_id,user_name,avatar_url,content,created_at,parent_id,like_count,reply_count')
          .eq('parent_id', parentId)
          .order('created_at', ascending: true);

      if (mounted) {
        setState(() {
          _replies[parentId] = (res as List).map((e) => CommentItem.fromMap(e as Map<String, dynamic>)).toList();
          _expanded.add(parentId);
        });
      }
    } catch (_) {
      _showError("Impossible de charger les réponses.");
    }
  }

  Future<void> _submit() async {
    final t = _controller.text.trim();
    if (t.isEmpty || _sending) return;
    if (t.length > 1000) {
      _showError("Commentaire trop long (max 1000 caractères).");
      return;
    }

    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) {
      _showError('Veuillez vous connecter.');
      return;
    }

    setState(() => _sending = true);
    try {
      if (_editingComment != null) {
        await Supabase.instance.client.from('media_comments').update({'content': t}).eq('id', _editingComment!.id);
        setState(() => _editingComment = null);
        await _fetchRoots();
      } else {
        final p = await Supabase.instance.client.from('profiles').select('username, full_name, avatar_url').eq('id', uid).maybeSingle();
        final authUser = Supabase.instance.client.auth.currentUser;

        String name = 'Utilisateur';
        if (p != null && p['username'] != null && p['username'].toString().trim().isNotEmpty) {
          name = p['username'].toString();
        } else if (p != null && p['full_name'] != null && p['full_name'].toString().trim().isNotEmpty) {
          name = p['full_name'].toString();
        } else if (authUser?.userMetadata?['full_name'] != null) {
          name = authUser!.userMetadata!['full_name'].toString();
        }

        final parentId = _replyingTo?.parentId ?? _replyingTo?.id;
        await Supabase.instance.client.from('media_comments').insert({
          'media_id': widget.mediaId,
          'user_id': uid,
          'user_name': name,
          'avatar_url': p?['avatar_url'],
          'content': t,
          'parent_id': parentId,
        });
        if (parentId != null) {
          await _fetchReplies(parentId);
        } else {
          await _fetchRoots();
        }
      }
      _controller.clear();
      _focusNode.unfocus();
      setState(() => _replyingTo = null);
      ref.invalidate(commentCountProvider(widget.mediaId));
    } catch (e) {
      _showError("Échec de l'envoi.");
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _delete(String id) async {
    try {
      await Supabase.instance.client.from('media_comments').delete().eq('id', id);
      _fetchRoots();
      ref.invalidate(commentCountProvider(widget.mediaId));
    } catch (_) {
      _showError("Impossible de supprimer ce commentaire.");
    }
  }

  void _showOptions(CommentItem c) {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    final isAuthor = uid == c.userId;
    showModalBottomSheet(
      context: context,
      backgroundColor: MediaColors.card,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isAuthor)
              ListTile(
                leading: const Icon(Icons.edit, color: Colors.white),
                title: const Text('Modifier', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _editingComment = c;
                    _replyingTo = null;
                  });
                  _controller.text = c.content;
                  _focusNode.requestFocus();
                },
              ),
            if (isAuthor)
              ListTile(
                leading: const Icon(Icons.delete, color: MediaColors.danger),
                title: const Text('Supprimer', style: TextStyle(color: MediaColors.danger)),
                onTap: () {
                  Navigator.pop(context);
                  _delete(c.id);
                },
              ),
            ListTile(
              leading: const Icon(Icons.flag, color: MediaColors.warning),
              title: const Text('Signaler', style: TextStyle(color: MediaColors.warning)),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Signalé aux modérateurs')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime d) {
    final diff = DateTime.now().difference(d);
    if (diff.inSeconds < 60) return "À l'instant";
    if (diff.inMinutes < 60) return "${diff.inMinutes}m";
    if (diff.inHours < 24) return "${diff.inHours}h";
    return "${diff.inDays}j";
  }

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.of(context).viewInsets.bottom;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 150),
      padding: EdgeInsets.only(bottom: insets),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            height: MediaQuery.of(context).size.height * 0.70,
            decoration: BoxDecoration(
              color: MediaColors.card.withOpacity(0.97),
              border: Border(top: BorderSide(color: Colors.white.withOpacity(0.1))),
            ),
            child: Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(4)),
                ),
                const SizedBox(height: 16),
                Text(
                  '${_roots.length} commentaires',
                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: _loading
                      ? const Center(child: CircularProgressIndicator(color: Colors.white))
                      : _roots.isEmpty
                          ? const Center(
                              child: Text(
                                'Soyez le premier à commenter !',
                                style: TextStyle(color: Colors.white54, fontWeight: FontWeight.w500),
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                              itemCount: _roots.length,
                              itemBuilder: (c, i) => _buildCommentTile(_roots[i]),
                            ),
                ),
                _buildInputBar(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      decoration: BoxDecoration(
        color: MediaColors.cardLight,
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.05))),
      ),
      child: Column(
        children: [
          if (_replyingTo != null || _editingComment != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.black26,
              child: Row(
                children: [
                  Text(
                    _editingComment != null ? 'Modification' : 'Réponse à @${_replyingTo!.userName}',
                    style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _replyingTo = null;
                        _editingComment = null;
                      });
                      _controller.clear();
                    },
                    child: const Icon(Icons.close_rounded, color: Colors.white54, size: 16),
                  ),
                ],
              ),
            ),
          Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white.withOpacity(0.06)),
                    ),
                    child: TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      minLines: 1,
                      maxLines: 4,
                      maxLength: 1000,
                      onSubmitted: (_) => _submit(),
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      cursorColor: Colors.white,
                      decoration: InputDecoration(
                        counterText: '',
                        hintText: _editingComment != null
                            ? 'Modifier...'
                            : (_replyingTo != null ? 'Votre réponse...' : 'Ajouter un commentaire...'),
                        hintStyle: const TextStyle(color: Colors.white38, fontSize: 14),
                        filled: false,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: _submit,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: _sending ? null : const LinearGradient(
                        colors: [Colors.white, Color(0xFFE2E8F0)],
                      ),
                      color: _sending ? Colors.white10 : null,
                      shape: BoxShape.circle,
                    ),
                    child: _sending
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: CircularProgressIndicator(color: MediaColors.navyDeep, strokeWidth: 2),
                          )
                        : const Icon(Icons.send_rounded, color: MediaColors.navyDeep, size: 18),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentTile(CommentItem c, {bool isReply = false}) {
    final isLiked = _likedIds.contains(c.id);
    final currentLikes = _localCommentLikes[c.id] ?? c.likeCount;

    return Padding(
      padding: EdgeInsets.only(left: isReply ? 48 : 0, top: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: isReply ? 14 : 18,
            backgroundColor: Colors.white12,
            backgroundImage: c.avatarUrl != null && c.avatarUrl!.isNotEmpty
                ? CachedNetworkImageProvider(c.avatarUrl!)
                : null,
            child: c.avatarUrl == null ? Icon(Icons.person, size: isReply ? 16 : 20, color: Colors.white54) : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              onLongPress: () => _showOptions(c),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    c.userName,
                    style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(c.content, style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.3)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(_formatDate(c.createdAt), style: const TextStyle(color: Colors.white38, fontSize: 12)),
                      const SizedBox(width: 16),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _replyingTo = c;
                            _editingComment = null;
                          });
                          _focusNode.requestFocus();
                        },
                        child: const Text('Répondre', style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: () => _toggleCommentLike(c, isLiked, currentLikes),
                        child: Row(
                          children: [
                            Icon(
                              isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                              color: isLiked ? MediaColors.danger : Colors.white54,
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              currentLikes > 0 ? '$currentLikes' : "",
                              style: TextStyle(
                                color: isLiked ? MediaColors.danger : Colors.white54,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (!isReply && (c.replyCount > 0 || _replies.containsKey(c.id))) ...[
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () {
                        if (_expanded.contains(c.id)) {
                          setState(() => _expanded.remove(c.id));
                        } else {
                          _fetchReplies(c.id);
                        }
                      },
                      child: Row(
                        children: [
                          Container(width: 24, height: 1, color: Colors.white24),
                          const SizedBox(width: 8),
                          Text(
                            _expanded.contains(c.id) ? 'Masquer' : 'Voir les ${c.replyCount} réponses',
                            style: const TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (!isReply && _expanded.contains(c.id))
                    ...(_replies[c.id] ?? []).map((r) => _buildCommentTile(r, isReply: true)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleCommentLike(CommentItem c, bool isLiked, int currentLikes) async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) {
      _showError('Connectez-vous pour aimer.');
      return;
    }

    setState(() {
      if (isLiked) {
        _likedIds.remove(c.id);
        _localCommentLikes[c.id] = (currentLikes - 1).clamp(0, 999999);
      } else {
        _likedIds.add(c.id);
        _localCommentLikes[c.id] = currentLikes + 1;
      }
    });

    try {
      await Supabase.instance.client.rpc('toggle_comment_like', params: {'p_comment_id': c.id});
    } catch (_) {
      if (mounted) {
        setState(() {
          if (isLiked) {
            _likedIds.add(c.id);
            _localCommentLikes[c.id] = currentLikes;
          } else {
            _likedIds.remove(c.id);
            _localCommentLikes[c.id] = currentLikes;
          }
        });
      }
    }
  }
}
