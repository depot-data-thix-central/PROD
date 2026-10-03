/// CommentsSheet (Production Enterprise) — v4
/// Certification via MediaCertBadge (même source que profil / détail / fil)
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/l10n/app_localizations.dart';
import 'package:thix_id/l10n/i18n_service.dart';
import 'package:thix_id/presentation/thix_media/providers/thix_media_provider.dart';

import '../utils/media_constants.dart';
import 'media_cert_badge.dart';

const int _kMaxCommentLength = 1000;
const int _kRootsLimit = 50;
const Duration _kQueryTimeout = Duration(seconds: 15);

// ─── PALETTE CLAIRE COMMENTS ───────────────────────────────────────────
class _CommentsPalette {
  static const Color bg = Color(0xFFF8FAFC);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceSoft = Color(0xFFF1F5F9);
  static const Color border = Color(0xFFE2E8F0);
  static const Color borderSoft = Color(0xFFEEF2F6);
  static const Color textMain = Color(0xFF0F172A);
  static const Color textSec = Color(0xFF475569);
  static const Color textMut = Color(0xFF94A3B8);
  static const Color gold = Color(0xFFD4A017);
  static const Color ink = Color(0xFF0A1628);
}

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

/// Traduction avec texte français de secours si la clé n'existe pas.
String _t(AppLocalizations l10n, String key, String fallback,
    {Map<String, String>? args}) {
  final v = (args == null || args.isEmpty) ? l10n.t(key) : l10n.tn(key, args);
  if (v.isEmpty || v == key || v.contains(key)) return fallback;
  return v;
}

class CommentsSheet extends ConsumerStatefulWidget {
  final String mediaId, mediaTitle;
  const CommentsSheet({
    super.key,
    required this.mediaId,
    required this.mediaTitle,
  });

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

  String? _currentUserAvatarUrl;

  String _safeTr(AppLocalizations l10n, String key, String fallback) =>
      _t(l10n, key, fallback);

  @override
  void initState() {
    super.initState();
    _fetchCurrentUserProfile();
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

  void _showError(String key, String fallback, {Map<String, String>? args}) {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_t(l10n, key, fallback, args: args)),
        backgroundColor: ThixPolicy.danger,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _fetchCurrentUserProfile() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return;

    try {
      final p = await _client
          .from('profiles')
          .select('avatar_url')
          .eq('id', uid)
          .maybeSingle()
          .timeout(_kQueryTimeout);

      if (!mounted || p == null) return;
      setState(() => _currentUserAvatarUrl = p['avatar_url']?.toString());
    } catch (e) {
      debugPrint('[Comments] fetchCurrentUserProfile failed: $e');
    }
  }

  Future<void> _fetchRoots() async {
    try {
      final res = await _client
          .from('media_comments')
          .select(
            'id,user_id,user_name,avatar_url,content,created_at,parent_id,like_count,reply_count',
          )
          .eq('media_id', widget.mediaId)
          .isFilter('parent_id', null)
          .order('created_at', ascending: false)
          .limit(_kRootsLimit)
          .timeout(_kQueryTimeout);

      if (mounted) {
        final roots = (res as List)
            .map((e) => CommentItem.fromMap(Map<String, dynamic>.from(e as Map)))
            .toList();
        setState(() {
          _roots = roots;
          _loading = false;
        });
        _fetchUserLikes();
      }
    } catch (e) {
      debugPrint('[Comments] fetchRoots failed: $e');
      if (mounted) {
        setState(() => _loading = false);
        _showError('comments_load_error',
            'Impossible de charger les commentaires.');
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
        setState(() {
          _likedIds.addAll(
            (res as List).map((e) => (e as Map)['comment_id'].toString()),
          );
        });
      }
    } catch (e) {
      debugPrint('[Comments] fetchUserLikes failed: $e');
    }
  }

  Future<void> _fetchReplies(String parentId) async {
    try {
      final res = await _client
          .from('media_comments')
          .select(
            'id,user_id,user_name,avatar_url,content,created_at,parent_id,like_count,reply_count',
          )
          .eq('parent_id', parentId)
          .order('created_at', ascending: true)
          .timeout(_kQueryTimeout);

      if (mounted) {
        final replies = (res as List)
            .map((e) => CommentItem.fromMap(Map<String, dynamic>.from(e as Map)))
            .toList();
        setState(() {
          _replies[parentId] = replies;
          _expanded.add(parentId);
        });
      }
    } catch (e) {
      debugPrint('[Comments] fetchReplies failed: $e');
      _showError('comments_replies_error',
          'Impossible de charger les réponses.');
    }
  }

  Future<void> _submit() async {
    final t = _CommentsSanitizer.content(_controller.text);
    if (t.isEmpty || _sending) return;
    if (t.length > _kMaxCommentLength) {
      _showError('comments_too_long', 'Commentaire trop long.',
          args: {'max': '$_kMaxCommentLength'});
      return;
    }

    final uid = _client.auth.currentUser?.id;
    if (uid == null) {
      _showError('comments_login_required', 'Veuillez vous connecter.');
      return;
    }

    setState(() => _sending = true);
    HapticFeedback.mediumImpact();
    try {
      if (_editingComment != null) {
        await _client
            .from('media_comments')
            .update({
              'content': t,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', _editingComment!.id)
            .timeout(_kQueryTimeout);
        if (mounted) setState(() => _editingComment = null);
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
        await _client.from('media_comments').insert({
          'media_id': widget.mediaId,
          'user_id': uid,
          'user_name': _CommentsSanitizer.name(name),
          'avatar_url': p?['avatar_url'],
          'content': t,
          'parent_id': parentId,
        }).timeout(_kQueryTimeout);

        if (parentId != null) {
          await _fetchReplies(parentId);
        } else {
          await _fetchRoots();
        }
      }

      if (!mounted) return;
      _controller.clear();
      _focusNode.unfocus();
      setState(() => _replyingTo = null);
      ref.invalidate(mediaCommentCountProvider(widget.mediaId));
    } catch (e) {
      debugPrint('[Comments] Submit failed: $e');
      _showError('comments_send_error', 'Échec de l\'envoi.');
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
      if (mounted) {
        await _fetchRoots();
        ref.invalidate(mediaCommentCountProvider(widget.mediaId));
      }
    } catch (e) {
      debugPrint('[Comments] Delete failed: $e');
      _showError('comments_delete_error', 'Suppression impossible.');
    }
  }

  Future<void> _toggleCommentLike(
    CommentItem c,
    bool isLiked,
    int currentLikes,
  ) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) {
      _showError('comments_login_required', 'Veuillez vous connecter.');
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
          } else {
            _likedIds.remove(c.id);
          }
          _localCommentLikes[c.id] = currentLikes;
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
      backgroundColor: _CommentsPalette.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: _CommentsPalette.border,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 12),
            if (isAuthor)
              ListTile(
                leading: const Icon(Icons.edit_rounded, color: ThixPolicy.primary),
                title: Text(
                  _safeTr(l10n, 'comments_edit', 'Modifier'),
                  style: const TextStyle(
                      color: _CommentsPalette.textMain,
                      fontWeight: FontWeight.w600),
                ),
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
                title: Text(
                  _safeTr(l10n, 'comments_delete', 'Supprimer'),
                  style: const TextStyle(
                      color: ThixPolicy.danger, fontWeight: FontWeight.w600),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _delete(c.id);
                },
              ),
            ListTile(
              leading: const Icon(Icons.flag_rounded, color: ThixPolicy.warning),
              title: Text(
                _safeTr(l10n, 'comments_report', 'Signaler'),
                style: const TextStyle(
                    color: ThixPolicy.warning, fontWeight: FontWeight.w600),
              ),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                        _safeTr(l10n, 'comments_reported', 'Commentaire signalé.')),
                    backgroundColor: ThixPolicy.primary,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final insets = MediaQuery.of(context).viewInsets.bottom;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 150),
      padding: EdgeInsets.only(bottom: insets),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: const BoxDecoration(
          color: _CommentsPalette.bg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 20,
              offset: Offset(0, -4),
            ),
          ],
        ),
        child: Column(
          children: [
            // ── HEADER ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: 20,
                    decoration: BoxDecoration(
                      color: _CommentsPalette.gold,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    _safeTr(l10n, 'comments_title', 'Commentaires'),
                    style: const TextStyle(
                      color: _CommentsPalette.textMain,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _CommentsPalette.gold.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${_roots.length}',
                      style: const TextStyle(
                        color: _CommentsPalette.gold,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: const BoxDecoration(
                        color: _CommentsPalette.surfaceSoft,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        color: _CommentsPalette.textSec,
                        size: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Container(height: 1, color: _CommentsPalette.borderSoft),
            // ── LIST ──
            Expanded(
              child: _loading
                  ? const Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: _CommentsPalette.gold,
                          strokeWidth: 2,
                        ),
                      ),
                    )
                  : _roots.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(18),
                                decoration: const BoxDecoration(
                                  color: _CommentsPalette.surfaceSoft,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.chat_bubble_outline_rounded,
                                  size: 32,
                                  color: _CommentsPalette.textMut,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _safeTr(l10n, 'comments_empty',
                                    'Aucun commentaire'),
                                style: const TextStyle(
                                  color: _CommentsPalette.textSec,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _safeTr(l10n, 'comments_empty_hint',
                                    'Soyez le premier à commenter'),
                                style: const TextStyle(
                                  color: _CommentsPalette.textMut,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                          itemCount: _roots.length,
                          itemBuilder: (c, i) => _buildCommentTile(_roots[i]),
                        ),
            ),
            // ── INPUT BAR ──
            _buildInputBar(l10n),
          ],
        ),
      ),
    );
  }

  Widget _buildInputBar(AppLocalizations l10n) {
    final uid = _client.auth.currentUser?.id;

    final String replyLabel = _editingComment != null
        ? _safeTr(l10n, 'comments_editing', 'Modification du commentaire')
        : (_replyingTo != null
            ? _t(
                l10n,
                'comments_reply_to',
                'Réponse à ${_CommentsSanitizer.name(_replyingTo!.userName)}',
                args: {'name': _CommentsSanitizer.name(_replyingTo!.userName)},
              )
            : '');

    return Container(
      decoration: const BoxDecoration(
        color: _CommentsPalette.surface,
        border: Border(top: BorderSide(color: _CommentsPalette.borderSoft)),
        boxShadow: [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 8,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        children: [
          if (_replyingTo != null || _editingComment != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: _CommentsPalette.surfaceSoft,
              child: Row(
                children: [
                  Container(
                    width: 3,
                    height: 16,
                    decoration: BoxDecoration(
                      color: _CommentsPalette.gold,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      replyLabel,
                      style: const TextStyle(
                        color: _CommentsPalette.textSec,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _replyingTo = null;
                        _editingComment = null;
                      });
                      _controller.clear();
                    },
                    child: const Icon(
                      Icons.close_rounded,
                      color: _CommentsPalette.textMut,
                      size: 16,
                    ),
                  ),
                ],
              ),
            ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              12,
              10,
              12,
              MediaQuery.of(context).padding.bottom + 10,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    _Avatar(url: _currentUserAvatarUrl),
                    Positioned(
                      right: -4,
                      bottom: -4,
                      child: MediaCertBadge(
                        userId: uid,
                        iconSize: 13,
                        padding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: _CommentsPalette.surfaceSoft,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: _CommentsPalette.borderSoft),
                    ),
                    child: TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      minLines: 1,
                      maxLines: 4,
                      maxLength: _kMaxCommentLength,
                      onSubmitted: (_) => _submit(),
                      style: const TextStyle(
                        color: _CommentsPalette.textMain,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      cursorColor: _CommentsPalette.gold,
                      decoration: InputDecoration(
                        counterText: '',
                        hintText: _editingComment != null
                            ? _safeTr(l10n, 'comments_hint_edit',
                                'Modifier votre commentaire…')
                            : (_replyingTo != null
                                ? _safeTr(l10n, 'comments_hint_reply',
                                    'Écrire une réponse…')
                                : _safeTr(l10n, 'comments_hint',
                                    'Ajouter un commentaire…')),
                        hintStyle: const TextStyle(
                          color: _CommentsPalette.textMut,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w500,
                        ),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: _sending ? null : _submit,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: _sending
                          ? null
                          : const LinearGradient(
                              colors: [_CommentsPalette.gold, Color(0xFFB8860B)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                      color: _sending ? _CommentsPalette.surfaceSoft : null,
                      shape: BoxShape.circle,
                      boxShadow: _sending
                          ? null
                          : [
                              BoxShadow(
                                color: _CommentsPalette.gold.withValues(alpha: 0.4),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                    ),
                    child: _sending
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.send_rounded,
                            color: Colors.white, size: 18),
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

    return Container(
      margin: EdgeInsets.only(
        left: isReply ? 36 : 0,
        top: 8,
        bottom: 4,
      ),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _CommentsPalette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _CommentsPalette.borderSoft),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Avatar(url: c.avatarUrl, small: isReply),
          const SizedBox(width: 10),
          Expanded(
            child: GestureDetector(
              onLongPress: () => _showOptions(c),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          safeName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _CommentsPalette.textMain,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.1,
                          ),
                        ),
                      ),
                      // ✅ Sceau de certification (niveau réel depuis la base)
                      MediaCertBadge(
                        userId: c.userId,
                        iconSize: 15,
                        padding: const EdgeInsets.only(left: 5),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    safeContent,
                    style: const TextStyle(
                      color: _CommentsPalette.textSec,
                      fontSize: 13.5,
                      height: 1.45,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        i18n.relativeTime(c.createdAt),
                        style: const TextStyle(
                          color: _CommentsPalette.textMut,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 14),
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() {
                            _replyingTo = c;
                            _editingComment = null;
                          });
                          _focusNode.requestFocus();
                        },
                        child: Text(
                          _safeTr(l10n, 'comments_reply', 'Répondre'),
                          style: const TextStyle(
                            color: _CommentsPalette.textSec,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: () => _toggleCommentLike(c, isLiked, currentLikes),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isLiked
                                ? ThixPolicy.danger.withValues(alpha: 0.08)
                                : _CommentsPalette.surfaceSoft,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isLiked
                                    ? Icons.favorite_rounded
                                    : Icons.favorite_border_rounded,
                                color: isLiked
                                    ? ThixPolicy.danger
                                    : _CommentsPalette.textMut,
                                size: 13,
                              ),
                              if (currentLikes > 0) ...[
                                const SizedBox(width: 3),
                                Text(
                                  '$currentLikes',
                                  style: TextStyle(
                                    color: isLiked
                                        ? ThixPolicy.danger
                                        : _CommentsPalette.textMut,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (!isReply &&
                      (c.replyCount > 0 || _replies.containsKey(c.id))) ...[
                    const SizedBox(height: 10),
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        if (_expanded.contains(c.id)) {
                          setState(() => _expanded.remove(c.id));
                        } else {
                          _fetchReplies(c.id);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: _CommentsPalette.surfaceSoft,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: _CommentsPalette.borderSoft),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _expanded.contains(c.id)
                                  ? Icons.expand_less_rounded
                                  : Icons.expand_more_rounded,
                              color: _CommentsPalette.textSec,
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _expanded.contains(c.id)
                                  ? _safeTr(l10n, 'comments_hide', 'Masquer')
                                  : _t(
                                      l10n,
                                      'comments_see_replies',
                                      'Voir les réponses (${c.replyCount})',
                                      args: {'count': '${c.replyCount}'},
                                    ),
                              style: const TextStyle(
                                color: _CommentsPalette.textSec,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  if (!isReply && _expanded.contains(c.id))
                    ...(_replies[c.id] ?? []).map(
                      (r) => _buildCommentTile(r, isReply: true),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── AVATAR ────────────────────────────────────────────────────────────
class _Avatar extends StatelessWidget {
  final String? url;
  final bool small;
  const _Avatar({this.url, this.small = false});

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: small ? 14 : 18,
      backgroundColor: _CommentsPalette.surfaceSoft,
      backgroundImage:
          url != null && url!.isNotEmpty ? CachedNetworkImageProvider(url!) : null,
      child: url == null || url!.isEmpty
          ? Icon(
              Icons.person,
              size: small ? 16 : 20,
              color: _CommentsPalette.textMut,
            )
          : null,
    );
  }
}
