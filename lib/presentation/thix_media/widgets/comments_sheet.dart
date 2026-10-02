/// CommentsSheet (Production Enterprise) — v2 Light
/// i18n + sanitization + Semantics + timeouts + ThixPolicy + Certification Badges
import 'dart:ui';

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

String _tr(AppLocalizations l10n, String key, [Map<String, String>? args]) {
  if (args == null || args.isEmpty) return l10n.t(key);
  return l10n.tn(key, args);
}

// ─── HELPERS CERTIFICATION ─────────────────────────────────────────────
enum _CertTier { none, standard, premium, enterprise, official }

class _CertInfo {
  final _CertTier tier;
  final bool verified;
  const _CertInfo({required this.tier, required this.verified});

  static const _CertInfo empty = _CertInfo(tier: _CertTier.none, verified: false);

  Color get badgeColor {
    if (!verified) return _CommentsPalette.textMut;
    switch (tier) {
      case _CertTier.official:
        return const Color(0xFF1E40AF); // Bleu officiel
      case _CertTier.enterprise:
        return const Color(0xFF7C3AED); // Violet
      case _CertTier.premium:
        return _CommentsPalette.gold; // Or
      case _CertTier.standard:
        return const Color(0xFF0891B2); // Cyan
      case _CertTier.none:
        return _CommentsPalette.textMut;
    }
  }

  String label(AppLocalizations l10n) {
    if (!verified) return '';
    switch (tier) {
      case _CertTier.official:
        return l10n.t('certification_tier_official', fallback: 'Officiel');
      case _CertTier.enterprise:
        return l10n.t('certification_tier_enterprise', fallback: 'Entreprise');
      case _CertTier.premium:
        return l10n.t('certification_tier_premium', fallback: 'Premium');
      case _CertTier.standard:
        return l10n.t('certification_tier_standard', fallback: 'Standard');
      case _CertTier.none:
        return '';
    }
  }
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
  
  // Cache des certifications par user_id
  final Map<String, _CertInfo> _certCache = {};
  
  // Avatar de l'utilisateur connecté
  String? _currentUserAvatarUrl;

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

  void _showError(String key, {Map<String, String>? args}) {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_tr(l10n, key, args)),
        backgroundColor: ThixPolicy.danger,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // Chargement du profil de l'utilisateur connecté pour la barre de saisie
  Future<void> _fetchCurrentUserProfile() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return;

    try {
      final p = await _client
          .from('profiles')
          .select('avatar_url, certification_tier, certification_status')
          .eq('id', uid)
          .maybeSingle()
          .timeout(_kQueryTimeout);

      if (!mounted || p == null) return;

      final tierStr = (p['certification_tier'] ?? '').toString().toLowerCase();
      final statusStr = (p['certification_status'] ?? '').toString().toLowerCase();
      final verified = statusStr == 'approved' || statusStr == 'generated' || statusStr == 'active';
      _CertTier tier = _CertTier.none;
      if (verified) {
        switch (tierStr) {
          case 'official': tier = _CertTier.official; break;
          case 'enterprise': tier = _CertTier.enterprise; break;
          case 'premium': tier = _CertTier.premium; break;
          case 'standard': tier = _CertTier.standard; break;
          default: tier = _CertTier.standard;
        }
      }

      setState(() {
        _currentUserAvatarUrl = p['avatar_url']?.toString();
        _certCache[uid] = _CertInfo(tier: tier, verified: verified);
      });
    } catch (e) {
      debugPrint('[Comments] fetchCurrentUserProfile failed: $e');
    }
  }

  // Récupération batch des certifications
  Future<void> _loadCertifications(List<CommentItem> comments) async {
    final userIds = comments.map((c) => c.userId).where((id) => id != null && id.isNotEmpty).toSet();
    final toFetch = userIds.where((id) => !_certCache.containsKey(id)).toList();
    if (toFetch.isEmpty) return;

    try {
      final res = await _client
          .from('profiles')
          .select('id, certification_tier, certification_status')
          .in_('id', toFetch)
          .timeout(_kQueryTimeout);

      if (!mounted) return;
      for (final row in res as List) {
        final id = row['id']?.toString();
        if (id == null) continue;
        final tierStr = (row['certification_tier'] ?? '').toString().toLowerCase();
        final statusStr = (row['certification_status'] ?? '').toString().toLowerCase();
        final verified = statusStr == 'approved' || statusStr == 'generated' || statusStr == 'active';
        _CertTier tier = _CertTier.none;
        if (verified) {
          switch (tierStr) {
            case 'official':
              tier = _CertTier.official;
              break;
            case 'enterprise':
              tier = _CertTier.enterprise;
              break;
            case 'premium':
              tier = _CertTier.premium;
              break;
            case 'standard':
              tier = _CertTier.standard;
              break;
            default:
              tier = _CertTier.standard;
          }
        }
        _certCache[id] = _CertInfo(tier: tier, verified: verified);
      }
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('[Comments] loadCertifications failed: $e');
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
          .is_('parent_id', null)
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
        await _loadCertifications(roots);
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
          .in_('comment_id', ids)
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
        await _loadCertifications(replies);
      }
    } catch (e) {
      debugPrint('[Comments] fetchReplies failed: $e');
      _showError('comments_replies_error');
    }
  }

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
            .select('username, full_name, avatar_url, certification_tier, certification_status')
            .eq('id', uid)
            .maybeSingle()
            .timeout(_kQueryTimeout);

        String name = 'Utilisateur';
        if (p?['username']?.toString().trim().isNotEmpty == true) {
          name = p!['username'].toString();
        } else if (p?['full_name']?.toString().trim().isNotEmpty == true) {
          name = p!['full_name'].toString();
        }

        // Mise à jour du cache de certification de l'auteur
        final tierStr = (p?['certification_tier'] ?? '').toString().toLowerCase();
        final statusStr = (p?['certification_status'] ?? '').toString().toLowerCase();
        final verified = statusStr == 'approved' || statusStr == 'generated' || statusStr == 'active';
        _CertTier tier = _CertTier.none;
        if (verified) {
          switch (tierStr) {
            case 'official': tier = _CertTier.official; break;
            case 'enterprise': tier = _CertTier.enterprise; break;
            case 'premium': tier = _CertTier.premium; break;
            case 'standard': tier = _CertTier.standard; break;
            default: tier = _CertTier.standard;
          }
        }
        _certCache[uid] = _CertInfo(tier: tier, verified: verified);

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
      if (mounted) {
        await _fetchRoots();
        ref.invalidate(mediaCommentCountProvider(widget.mediaId));
      }
    } catch (e) {
      debugPrint('[Comments] Delete failed: $e');
      _showError('comments_delete_error');
    }
  }

  Future<void> _toggleCommentLike(
    CommentItem c,
    bool isLiked,
    int currentLikes,
  ) async {
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
                  l10n.t('comments_edit'),
                  style: const TextStyle(color: _CommentsPalette.textMain, fontWeight: FontWeight.w600),
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
                  l10n.t('comments_delete'),
                  style: const TextStyle(color: ThixPolicy.danger, fontWeight: FontWeight.w600),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _delete(c.id);
                },
              ),
            ListTile(
              leading: const Icon(Icons.flag_rounded, color: ThixPolicy.warning),
              title: Text(
                l10n.t('comments_report'),
                style: const TextStyle(color: ThixPolicy.warning, fontWeight: FontWeight.w600),
              ),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(l10n.t('comments_reported')),
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
                    l10n.t('comments_title', fallback: 'Commentaires'),
                    style: const TextStyle(
                      color: _CommentsPalette.textMain,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _CommentsPalette.gold.withOpacity(0.12),
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
                                l10n.t('comments_empty'),
                                style: const TextStyle(
                                  color: _CommentsPalette.textSec,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                l10n.t('comments_empty_hint',
                                    fallback: 'Soyez le premier à commenter'),
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
    final myCert = uid != null ? (_certCache[uid] ?? _CertInfo.empty) : _CertInfo.empty;

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
                      _editingComment != null
                          ? l10n.t('comments_editing')
                          : _tr(l10n, 'comments_reply_to', {
                              'name': _CommentsSanitizer.name(_replyingTo!.userName),
                            }),
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
                // Avatar réel de l'utilisateur avec son badge de certification
                _AvatarWithBadge(
                  url: _currentUserAvatarUrl,
                  cert: myCert,
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
                            ? l10n.t('comments_hint_edit')
                            : (_replyingTo != null
                                ? l10n.t('comments_hint_reply')
                                : l10n.t('comments_hint')),
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
                // Bouton d'envoi doré premium
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
                                color: _CommentsPalette.gold.withOpacity(0.4),
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
                        : const Icon(Icons.send_rounded, color: Colors.white, size: 18),
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
    final cert = _certCache[c.userId ?? ''] ?? _CertInfo.empty;

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
            color: Colors.black.withOpacity(0.02),
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
                  // ── NOM + BADGE CERTIFICATION ──
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
                      if (cert.verified) ...[
                        const SizedBox(width: 5),
                        _CertificationBadge(cert: cert, l10n: l10n),
                      ],
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
                          l10n.t('comments_reply'),
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
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isLiked
                                ? ThixPolicy.danger.withOpacity(0.08)
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
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                                  ? l10n.t('comments_hide')
                                  : _tr(l10n, 'comments_see_replies', {
                                      'count': '${c.replyCount}',
                                    }),
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

// ─── BADGE CERTIFICATION ───────────────────────────────────────────────
class _CertificationBadge extends StatelessWidget {
  final _CertInfo cert;
  final AppLocalizations l10n;
  const _CertificationBadge({required this.cert, required this.l10n});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: cert.badgeColor.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: cert.badgeColor.withOpacity(0.3), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified_rounded, color: cert.badgeColor, size: 11),
          const SizedBox(width: 3),
          Text(
            cert.label(l10n),
            style: TextStyle(
              color: cert.badgeColor,
              fontSize: 9,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── AVATAR AVEC BADGE CERTIFICATION ───────────────────────────────────
class _AvatarWithBadge extends StatelessWidget {
  final String? url;
  final _CertInfo cert;
  const _AvatarWithBadge({this.url, required this.cert});

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: _CommentsPalette.surfaceSoft,
          backgroundImage:
              url != null && url!.isNotEmpty ? CachedNetworkImageProvider(url!) : null,
          child: url == null || url!.isEmpty
              ? const Icon(Icons.person, size: 18, color: _CommentsPalette.textMut)
              : null,
        ),
        if (cert.verified)
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(
                color: _CommentsPalette.surface,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.verified_rounded,
                color: cert.badgeColor,
                size: 12,
              ),
            ),
          ),
      ],
    );
  }
}

// ─── AVATAR CLASSIQUE ──────────────────────────────────────────────────
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
