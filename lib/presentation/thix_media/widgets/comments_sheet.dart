/// CommentsSheet (Production Enterprise)
/// i18n + sanitization + Semantics + timeouts + ThixPolicy
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:thix_id/presentation/thix_media/providers/thix_media_provider.dart';
import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/l10n/app_localizations.dart';
import 'package:thix_id/l10n/i18n_service.dart';

import '../utils/media_constants.dart';

const int _kMaxCommentLength = 1000;
const int _kRootsLimit = 50;
const Duration _kQueryTimeout = Duration(seconds: 15);
const double _kSheetBlur = kIsWeb ? 6 : 15;

class _CommentsSanitizer {
  static String content(String? input) {
    if (input == null) return '';
    final s = input
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]'), '')
        .trim();
    return s.length > _kMaxCommentLength
        ? s.substring(0, _kMaxCommentLength)
        : s;
  }

  static String name(String? input) {
    if (input == null) return '';
    final s = input.replaceAll(RegExp(r'[<>\x00-\x1F\x7F]'), '').trim();
    return s.length > 50 ? s.substring(0, 50) : s;
  }
}

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
    debugPrint('[Comments] Sheet opened for media ${widget.mediaId}');
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  SupabaseClient get _client => Supabase.instance.client;

  void _showError(String key, {Map<String, String>? args}) {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.t(key, args: args ?? {})),
        backgroundColor: ThixPolicy.danger,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ── Fetch ─────────────────────────────────────────────────

  Future<void> _fetchRoots() async {
    try {
      final res = await _client
          .from('media_comments')
          .select('id,user_id,user_name,avatar_url,content,created_at,parent_id,like_count,reply_count')
          .eq('media_id', widget.mediaId)
          .isFilter('parent_id', null)
          .order('created_at', ascending: false)
          .limit(_kRootsLimit)
          .timeout(_kQueryTimeout);

      if (mounted) {
        setState(() {
          _roots = (res as List)
              .map((e) => CommentItem.fromMap(Map<String, dynamic>.from(e as Map)))
              .toList();
          _loading = false;
        });
        _fetchUserLikes();
      }
    } catch (e) {
      debugPrint('[Comments] fetchRoots failed: $e');
      if (mounted) {
        setState(() => _loading = false);
        _showError('comments_load_error');
      }
    }
  }

  Future<void> _fetchUserLikes() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null || _roots.isEmpty) return;
    try {
      final ids = _roots.map((c) => c.id).toList();
      final res = await _client
          .from('comment_likes')
          .select('comment_id')
          .eq('user_id', uid)
          .inFilter('comment_id', ids)
          .timeout(_kQueryTimeout);
      if (mounted) {
        setState(() => _likedIds
            .addAll((res as List).map((e) => (e as Map)['comment_id'].toString())));
      }
    } catch (e) {
      debugPrint('[Comments] fetchUserLikes failed: $e');
    }
  }

  Future<void> _fetchReplies(String parentId) async {
    try {
      final res = await _client
          .from('media_comments')
          .select('id,user_id,user_name,avatar_url,content,created_at,parent_id,like_count,reply_count')
          .eq('parent_id', parentId)
          .order('created_at', ascending: true)
          .timeout(_kQueryTimeout);

      if (mounted) {
        setState(() {
          _replies[parentId] = (res as List)
              .map((e) => CommentItem.fromMap(Map<String, dynamic>.from(e as Map)))
              .toList();
          _expanded.add(parentId);
        });
      }
    } catch (e) {
      debugPrint('[Comments] fetchReplies failed: $e');
      _showError('comments_replies_error');
    }
  }

  // ── Submit / edit / delete ────────────────────────────────

  Future<void> _submit() async {
    final t = _CommentsSanitizer.content(_controller.text);
    if (t.isEmpty || _sending) return;
    if (t.length > _kMaxCommentLength) {
      _showError('comments_too_long', args: {'max': '$_kMaxCommentLength'});
      return;
    }

    final uid = _client.auth.currentUser?.id;
    if (uid == null) {
      _showError('comments_login_required');
      return;
    }

    setState(() => _sending = true);
    HapticFeedback.mediumImpact();
    try {
      if (_editingComment != null) {
        await _client
            .from('media_comments')
            .update({'content': t, 'updated_at': DateTime.now().toIso8601String()})
            .eq('id', _editingComment!.id)
            .timeout(_kQueryTimeout);
        setState(() => _editingComment = null);
        await _fetchRoots();
      } else {
        final p = await _client
            .from('profiles')
            .select('username, full_name, avatar_url')
            .eq('id', uid)
            .maybeSingle()
            .timeout(_kQueryTimeout);

        String name = 'Utilisateur';
        if (p?['username']?.toString().trim().isNotEmpty == true) {
          name = p!['username'].toString();
        } else if (p?['full_name']?.toString().trim().isNotEmpty == true) {
          name = p!['full_name'].toString();
        }

        final parentId = _replyingTo?.parentId ?? _replyingTo?.id;
        await _client
            .from('media_comments')
            .insert({
              'media_id': widget.mediaId,
              'user_id': uid,
              'user_name': _CommentsSanitizer.name(name),
              'avatar_url': p?['avatar_url'],
              'content': t,
              'parent_id': parentId,
            })
            .timeout(_kQueryTimeout);

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
      debugPrint('[Comments] Submitted');
    } catch (e) {
      debugPrint('[Comments] Submit failed: $e');
      _showError('comments_send_error');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _delete(String id) async {
    try {
      await _client
          .from('media_comments')
          .delete()
          .eq('id', id)
          .timeout(_kQueryTimeout);
      _fetchRoots();
      ref.invalidate(commentCountProvider(widget.mediaId));
      debugPrint('[Comments] Deleted $id');
    } catch (e) {
      debugPrint('[Comments] Delete failed: $e');
      _showError('comments_delete_error');
    }
  }

  Future<void> _toggleCommentLike(CommentItem c, bool isLiked, int currentLikes) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) {
      _showError('comments_login_required');
      return;
    }
    HapticFeedback.selectionClick();

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
      await _client
          .rpc('toggle_comment_like', params: {'p_comment_id': c.id})
          .timeout(_kQueryTimeout);
    } catch (e) {
      debugPrint('[Comments] Like rollback: $e');
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

  void _showOptions(CommentItem c) {
    final l10n = AppLocalizations.of(context);
    final uid = _client.auth.currentUser?.id;
    final isAuthor = uid == c.userId;
    HapticFeedback.mediumImpact();

    showModalBottomSheet(
      context: context,
      backgroundColor: ThixPolicy.card,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isAuthor)
              ListTile(
                leading: const Icon(Icons.edit_rounded, color: ThixPolicy.primary),
                title: Text(l10n.t('comments_edit'),
                    style: const TextStyle(color: ThixPolicy.textMain)),
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
                leading: const Icon(Icons.delete_rounded, color: ThixPolicy.danger),
                title: Text(l10n.t('comments_delete'),
                    style: const TextStyle(color: ThixPolicy.danger)),
                onTap: () {
                  Navigator.pop(context);
                  _delete(c.id);
                },
              ),
            ListTile(
              leading: const Icon(Icons.flag_rounded, color: ThixPolicy.warning),
              title: Text(l10n.t('comments_report'),
                  style: const TextStyle(color: ThixPolicy.warning)),
              onTap: () {
                Navigator.pop(context);
                debugPrint('[Comments] Reported comment ${c.id}');
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(l10n.t('comments_reported')),
                    backgroundColor: ThixPolicy.primary,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final insets = MediaQuery.of(context).viewInsets.bottom;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 150),
      padding: EdgeInsets.only(bottom: insets),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: _kSheetBlur, sigmaY: _kSheetBlur),
          child: Container(
            height: MediaQuery.of(context).size.height * 0.70,
            decoration: BoxDecoration(
              color: ThixPolicy.inkDeep.withValues(alpha: 0.97),
              border: Border(
                top: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
              ),
            ),
            child: Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 16),
                Semantics(
                  header: true,
                  child: Text(
                    l10n.t('comments_count', args: {'count': '${_roots.length}'}),
                    style: const TextStyle(
                      color: ThixPolicy.textMain,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: _loading
                      ? const Center(
                          child: CircularProgressIndicator(color: ThixPolicy.primary))
                      : _roots.isEmpty
                          ? Center(
                              child: Text(
                                l10n.t('comments_empty'),
                                style: TextStyle(
                                  color: ThixPolicy.textMuted,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                              itemCount: _roots.length,
                              itemBuilder: (c, i) => _buildCommentTile(_roots[i]),
                            ),
                ),
                _buildInputBar(l10n),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputBar(AppLocalizations l10n) {
    return Container(
      decoration: BoxDecoration(
        color: ThixPolicy.card,
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
        ),
      ),
      child: Column(
        children: [
          if (_replyingTo != null || _editingComment != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.black26,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _editingComment != null
                          ? l10n.t('comments_editing')
                          : l10n.t('comments_reply_to', args: {
                              'name': _CommentsSanitizer.name(_replyingTo!.userName)
                            }),
                      style: TextStyle(
                        color: ThixPolicy.textMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Semantics(
                    button: true,
                    label: l10n.t('common_cancel'),
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _replyingTo = null;
                          _editingComment = null;
                        });
                        _controller.clear();
                      },
                      child: const Icon(Icons.close_rounded,
                          color: ThixPolicy.textMuted, size: 16),
                    ),
                  ),
                ],
              ),
            ),
          Padding(
            padding: EdgeInsets.fromLTRB(
                16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.06)),
                    ),
                    child: Semantics(
                      textField: true,
                      label: l10n.t('comments_hint'),
                      child: TextField(
                        controller: _controller,
                        focusNode: _focusNode,
                        minLines: 1,
                        maxLines: 4,
                        maxLength: _kMaxCommentLength,
                        onSubmitted: (_) => _submit(),
                        style: const TextStyle(
                            color: ThixPolicy.textMain, fontSize: 14),
                        cursorColor: ThixPolicy.textMain,
                        decoration: InputDecoration(
                          counterText: '',
                          hintText: _editingComment != null
                              ? l10n.t('comments_hint_edit')
                              : (_replyingTo != null
                                  ? l10n.t('comments_hint_reply')
                                  : l10n.t('comments_hint')),
                          hintStyle: TextStyle(
                              color: ThixPolicy.textMuted.withValues(alpha: 0.6),
                              fontSize: 14),
                          filled: false,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          isDense: true,
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Semantics(
                  button: true,
                  label: l10n.t('comments_send'),
                  child: GestureDetector(
                    onTap: _submit,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: _sending
                            ? null
                            : const LinearGradient(
                                colors: [Colors.white, Color(0xFFE2E8F0)]),
                        color: _sending
                            ? Colors.white.withValues(alpha: 0.1)
                            : null,
                        shape: BoxShape.circle,
                      ),
                      child: _sending
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: CircularProgressIndicator(
                                  color: ThixPolicy.inkDeep, strokeWidth: 2),
                            )
                          : const Icon(Icons.send_rounded,
                              color: ThixPolicy.inkDeep, size: 18),
                    ),
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
    final l10n = AppLocalizations.of(context);
    final i18n = I18nService.of(context);
    final isLiked = _likedIds.contains(c.id);
    final currentLikes = _localCommentLikes[c.id] ?? c.likeCount;
    final safeName = _CommentsSanitizer.name(c.userName);
    final safeContent = _CommentsSanitizer.content(c.content);

    return Padding(
      padding: EdgeInsets.only(left: isReply ? 48 : 0, top: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Avatar(url: c.avatarUrl, small: isReply),
          const SizedBox(width: 12),
          Expanded(
            child: Semantics(
              label: '$safeName: $safeContent',
              child: GestureDetector(
                onLongPress: () => _showOptions(c),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      safeName,
                      style: TextStyle(
                        color: ThixPolicy.textMuted,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      safeContent,
                      style: const TextStyle(
                        color: ThixPolicy.textMain,
                        fontSize: 14,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          i18n.relativeTime(c.createdAt),
                          style: TextStyle(
                            color: ThixPolicy.textMuted.withValues(alpha: 0.6),
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Semantics(
                          button: true,
                          label: l10n.t('comments_reply'),
                          child: GestureDetector(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setState(() {
                                _replyingTo = c;
                                _editingComment = null;
                              });
                              _focusNode.requestFocus();
                            },
                            child: Text(
                              l10n.t('comments_reply'),
                              style: TextStyle(
                                color: ThixPolicy.textMuted,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const Spacer(),
                        Semantics(
                          button: true,
                          label: '${l10n.t("band_like")} $currentLikes',
                          child: GestureDetector(
                            onTap: () =>
                                _toggleCommentLike(c, isLiked, currentLikes),
                            child: Row(
                              children: [
                                Icon(
                                  isLiked
                                      ? Icons.favorite_rounded
                                      : Icons.favorite_border_rounded,
                                  color: isLiked
                                      ? ThixPolicy.danger
                                      : ThixPolicy.textMuted,
                                  size: 14,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  currentLikes > 0 ? '$currentLikes' : '',
                                  style: TextStyle(
                                    color: isLiked
                                        ? ThixPolicy.danger
                                        : ThixPolicy.textMuted,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (!isReply &&
                        (c.replyCount > 0 || _replies.containsKey(c.id))) ...[
                      const SizedBox(height: 8),
                      Semantics(
                        button: true,
                        label: _expanded.contains(c.id)
                            ? l10n.t('comments_hide')
                            : l10n.t('comments_see_replies',
                                args: {'count': '${c.replyCount}'}),
                        child: GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            if (_expanded.contains(c.id)) {
                              setState(() => _expanded.remove(c.id));
                            } else {
                              _fetchReplies(c.id);
                            }
                          },
                          child: Row(
                            children: [
                              Container(
                                  width: 24,
                                  height: 1,
                                  color: Colors.white24),
                              const SizedBox(width: 8),
                              Text(
                                _expanded.contains(c.id)
                                    ? l10n.t('comments_hide')
                                    : l10n.t('comments_see_replies',
                                        args: {'count': '${c.replyCount}'}),
                                style: TextStyle(
                                  color: ThixPolicy.textMuted,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    if (!isReply && _expanded.contains(c.id))
                      ...(_replies[c.id] ?? [])
                          .map((r) => _buildCommentTile(r, isReply: true)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String? url;
  final bool small;
  const _Avatar({this.url, this.small = false});

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: small ? 14 : 18,
      backgroundColor: Colors.white.withValues(alpha: 0.08),
      backgroundImage:
          url != null && url!.isNotEmpty ? CachedNetworkImageProvider(url!) : null,
      child: url == null || url!.isEmpty
          ? Icon(Icons.person,
              size: small ? 16 : 20, color: ThixPolicy.textMuted)
          : null,
    );
  }
}
