// lib/presentation/thix_media/widgets/profile_video_card.dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/l10n/app_localizations.dart';
import 'package:thix_id/models/media_content.dart';
import 'package:thix_id/presentation/thix_media/media_routes.dart';
import 'package:thix_id/presentation/thix_media/providers/thix_media_provider.dart';
import 'package:thix_id/presentation/thix_media/providers/user_profile_providers.dart';
import 'package:thix_id/services/media_service.dart';

const Duration _kTapThrottle = Duration(milliseconds: 500);

class ProfileVideoCard extends ConsumerStatefulWidget {
  final MediaContent post;
  final bool isOwner;
  final String ownerUserId;
  final VoidCallback? onChanged;

  const ProfileVideoCard({
    super.key,
    required this.post,
    this.isOwner = false,
    required this.ownerUserId,
    this.onChanged,
  });

  @override
  ConsumerState<ProfileVideoCard> createState() => _ProfileVideoCardState();
}

class _ProfileVideoCardState extends ConsumerState<ProfileVideoCard> {
  DateTime? _lastTap;
  late String _trimmedCoverUrl;
  late bool _hasCover;
  bool _busy = false;
  bool _alreadyReposted = false;
  String? _originalAuthorName;

  @override
  void initState() {
    super.initState();
    _trimmedCoverUrl = widget.post.coverUrl.trim();
    _hasCover = _trimmedCoverUrl.isNotEmpty;
    _checkRepostStatus();
    _loadOriginalAuthor();
  }

  @override
  void didUpdateWidget(covariant ProfileVideoCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.post.coverUrl != widget.post.coverUrl) {
      _trimmedCoverUrl = widget.post.coverUrl.trim();
      _hasCover = _trimmedCoverUrl.isNotEmpty;
    }
    if (oldWidget.post.id != widget.post.id) {
      _checkRepostStatus();
      _loadOriginalAuthor();
    }
  }

  bool get _isRepost => 
      widget.post.repostOf != null && widget.post.repostOf!.isNotEmpty;

  String _safeTr(AppLocalizations l10n, String key, String fallback) {
    final val = l10n.t(key);
    if (val.isEmpty || val == key || val.contains(key)) return fallback;
    return val;
  }

  /// Vérifie si l'utilisateur courant a déjà reposté ce média
  Future<void> _checkRepostStatus() async {
    if (_isRepost) return; // Déjà un repost, pas besoin de vérifier
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null || uid == widget.ownerUserId) return;
    try {
      final existing = await Supabase.instance.client
          .from('media_content')
          .select('id')
          .eq('user_id', uid)
          .eq('repost_of', widget.post.id)
          .maybeSingle()
          .timeout(const Duration(seconds: 5));
      if (mounted && existing != null) {
        setState(() => _alreadyReposted = true);
      }
    } catch (_) {}
  }

  /// Charge le nom de l'auteur original si c'est un repost
  Future<void> _loadOriginalAuthor() async {
    if (!_isRepost) return;
    try {
      final original = await Supabase.instance.client
          .from('media_content')
          .select('user_id')
          .eq('id', widget.post.repostOf!)
          .maybeSingle()
          .timeout(const Duration(seconds: 5));
      if (original == null) return;
      final userId = original['user_id']?.toString();
      if (userId == null) return;
      
      final profile = await Supabase.instance.client
          .from('profiles')
          .select('username, full_name')
          .eq('id', userId)
          .maybeSingle()
          .timeout(const Duration(seconds: 5));
      if (mounted && profile != null) {
        final name = (profile['username'] as String?)?.isNotEmpty == true
            ? profile['username'] as String
            : (profile['full_name'] as String?) ?? '';
        setState(() => _originalAuthorName = name);
      }
    } catch (_) {}
  }

  void _handleTap() {
    final now = DateTime.now();
    if (_lastTap != null && now.difference(_lastTap!) < _kTapThrottle) return;
    _lastTap = now;

    HapticFeedback.selectionClick();
    if (widget.post.videoUrl.trim().isEmpty) return;

    MediaRoutes.goToVideoPlayer(
      context, 
      videoUrl: widget.post.videoUrl, 
      title: widget.post.title,
    );
  }

  Future<void> _onMenuSelected(String action) async {
    if (_busy) return;
    HapticFeedback.selectionClick();

    switch (action) {
      case 'edit':
        if (widget.isOwner) await _editTitleDescription();
        break;
      case 'toggle_private':
        if (widget.isOwner) await _togglePublished();
        break;
      case 'delete':
        if (widget.isOwner) await _confirmAndDelete();
        break;
      case 'view_original':
        await _openOriginal();
        break;
      case 'repost':
        await _repostMedia();
        break;
    }
  }

  /// Ouvre le média original (si c'est un repost)
  Future<void> _openOriginal() async {
    if (!_isRepost) return;
    try {
      final original = await Supabase.instance.client
          .from('media_content')
          .select()
          .eq('id', widget.post.repostOf!)
          .maybeSingle()
          .timeout(const Duration(seconds: 5));
      if (original == null || !mounted) return;
      
      final originalMedia = MediaContent.fromJson(
        Map<String, dynamic>.from(original as Map),
      );
      MediaRoutes.goToVideoPlayer(
        context,
        videoUrl: originalMedia.videoUrl,
        title: originalMedia.title,
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_safeTr(
              AppLocalizations.of(context),
              'profile_original_unavailable',
              'Original indisponible',
            )),
            backgroundColor: ThixPolicy.danger,
          ),
        );
      }
    }
  }

  /// Reposte le média sur le profil de l'utilisateur courant
  Future<void> _repostMedia() async {
    final l10n = AppLocalizations.of(context);
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_safeTr(l10n, 'detail_login_required', 'Veuillez vous connecter')),
          backgroundColor: ThixPolicy.danger,
        ),
      );
      return;
    }

    if (_alreadyReposted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_safeTr(l10n, 'profile_already_reposted', 'Déjà reposté')),
          backgroundColor: ThixPolicy.warning,
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ThixPolicy.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          _safeTr(l10n, 'profile_repost_title', 'Reposter cette vidéo'),
          style: const TextStyle(
            color: ThixPolicy.textMain,
            fontWeight: FontWeight.w800,
          ),
        ),
        content: Text(
          _safeTr(
            l10n,
            'profile_repost_confirm',
            'La vidéo apparaîtra sur votre profil avec attribution à l\'auteur original.',
          ),
          style: const TextStyle(color: ThixPolicy.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              _safeTr(l10n, 'common_cancel', 'Annuler'),
              style: const TextStyle(color: ThixPolicy.textSecondary),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: ThixPolicy.primary,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(_safeTr(l10n, 'profile_repost', 'Reposter')),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      await MediaService().repostMedia(widget.post.id);
      if (!mounted) return;
      setState(() => _alreadyReposted = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_safeTr(l10n, 'profile_repost_success', 'Reposté avec succès')),
          backgroundColor: ThixPolicy.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_safeTr(l10n, 'profile_repost_failed', 'Échec du repost')),
          backgroundColor: ThixPolicy.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _editTitleDescription() async {
    final l10n = AppLocalizations.of(context);
    final titleCtrl = TextEditingController(text: widget.post.title);
    final descCtrl = TextEditingController(text: widget.post.subtitle ?? '');

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_safeTr(l10n, 'profile_edit_video', 'Modifier la vidéo')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleCtrl,
              maxLength: 100,
              decoration: InputDecoration(
                labelText: _safeTr(l10n, 'create_title', 'Titre'),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descCtrl,
              maxLength: 300,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: _safeTr(l10n, 'create_description', 'Description'),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(_safeTr(l10n, 'common_cancel', 'Annuler')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(_safeTr(l10n, 'common_save', 'Enregistrer')),
          ),
        ],
      ),
    );

    if (saved != true || !mounted) return;
    final newTitle = titleCtrl.text.trim();
    if (newTitle.isEmpty) return;

    setState(() => _busy = true);
    try {
      await MediaService().updateMediaMeta(widget.post.id, {
        'title': newTitle,
        'subtitle': descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
      });
      ref.invalidate(userPostsProvider(widget.ownerUserId));
      ref.invalidate(userPrivatePostsProvider(widget.ownerUserId));
      widget.onChanged?.call();
    } catch (e) {
      // Ignorer l'erreur visuelle
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _togglePublished() async {
    setState(() => _busy = true);
    try {
      await MediaService().updateMediaMeta(widget.post.id, {
        'is_published': !widget.post.isPublished,
      });
      ref.invalidate(userPostsProvider(widget.ownerUserId));
      ref.invalidate(userPrivatePostsProvider(widget.ownerUserId));
      widget.onChanged?.call();
    } catch (e) {
      // Ignorer
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmAndDelete() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_safeTr(l10n, 'profile_delete_title', 'Supprimer la vidéo ?')),
        content: Text(_safeTr(l10n, 'profile_delete_confirm', 'Cette action est définitive.')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(_safeTr(l10n, 'common_cancel', 'Annuler')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: ThixPolicy.danger),
            child: Text(_safeTr(l10n, 'common_delete', 'Supprimer')),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      HapticFeedback.mediumImpact();
      await MediaService().deleteMedia(widget.post);

      if (widget.post.isPublished) {
        ref.read(userPostsProvider(widget.ownerUserId).notifier).removePost(widget.post.id);
      } else {
        ref.read(userPrivatePostsProvider(widget.ownerUserId).notifier).removePost(widget.post.id);
      }
      widget.onChanged?.call();
    } catch (e) {
      // Ignorer
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _formatNumber(int num) {
    if (num < 0) return '0';
    if (num >= 1000000) return '${(num / 1000000).toStringAsFixed(1)}M';
    if (num >= 1000) return '${(num / 1000).toStringAsFixed(1)}K';
    return '$num';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final liveStats = ref.watch(mediaCountsStreamProvider(widget.post.id));
    final views = liveStats.valueOrNull?.viewCount ?? widget.post.viewCount;
    final repostCount = widget.post.repostCount;
    final currentUid = Supabase.instance.client.auth.currentUser?.id;
    final canRepost = currentUid != null && 
                       currentUid != widget.ownerUserId && 
                       !_isRepost;

    return RepaintBoundary(
      child: Stack(
        fit: StackFit.expand,
        children: [
          GestureDetector(
            onTap: _handleTap,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _buildCover(),
                  _buildGradient(),
                  if (widget.post.isPaid) _buildPaidBadge(),
                  if (!widget.post.isPublished) _buildPrivateBadge(l10n),
                  if (_isRepost) _buildRepostBadge(l10n),
                  _buildStatsOverlay(views, repostCount),
                ],
              ),
            ),
          ),

          // Menu popup (owner OU visiteur avec options repost)
          Positioned(
            top: 4,
            right: 4,
            child: Material(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(20),
              child: PopupMenuButton<String>(
                enabled: !_busy,
                icon: _busy 
                    ? const SizedBox(
                        width: 18, 
                        height: 18, 
                        child: CircularProgressIndicator(
                          strokeWidth: 2, 
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.more_vert, color: Colors.white, size: 20),
                padding: EdgeInsets.zero,
                onSelected: _onMenuSelected,
                itemBuilder: (ctx) {
                  final items = <PopupMenuEntry<String>>[];
                  
                  // Options OWNER
                  if (widget.isOwner) {
                    items.addAll([
                      PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            const Icon(Icons.edit_outlined, size: 20),
                            const SizedBox(width: 12),
                            Text(_safeTr(l10n, 'profile_menu_edit', 'Modifier')),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'toggle_private',
                        child: Row(
                          children: [
                            Icon(
                              widget.post.isPublished 
                                  ? Icons.lock_outline 
                                  : Icons.public,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Text(widget.post.isPublished 
                                ? _safeTr(l10n, 'profile_menu_private', 'Mettre en privé') 
                                : _safeTr(l10n, 'profile_menu_public', 'Publier')),
                          ],
                        ),
                      ),
                    ]);
                    
                    // "Voir original" si c'est un repost
                    if (_isRepost) {
                      items.add(PopupMenuItem(
                        value: 'view_original',
                        child: Row(
                          children: [
                            const Icon(Icons.open_in_new_rounded, size: 20),
                            const SizedBox(width: 12),
                            Text(_safeTr(l10n, 'profile_view_original', 'Voir l\'original')),
                          ],
                        ),
                      ));
                    }
                    
                    items.add(const PopupMenuDivider());
                    items.add(PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          const Icon(Icons.delete_outline, size: 20, color: ThixPolicy.danger),
                          const SizedBox(width: 12),
                          Text(
                            _safeTr(l10n, 'profile_menu_delete', 'Supprimer'),
                            style: const TextStyle(color: ThixPolicy.danger),
                          ),
                        ],
                      ),
                    ));
                  } else {
                    // Options VISITEUR
                    if (_isRepost) {
                      items.add(PopupMenuItem(
                        value: 'view_original',
                        child: Row(
                          children: [
                            const Icon(Icons.open_in_new_rounded, size: 20),
                            const SizedBox(width: 12),
                            Text(_safeTr(l10n, 'profile_view_original', 'Voir l\'original')),
                          ],
                        ),
                      ));
                    }
                    
                    if (canRepost) {
                      items.add(PopupMenuItem(
                        value: 'repost',
                        enabled: !_alreadyReposted,
                        child: Row(
                          children: [
                            Icon(
                              _alreadyReposted 
                                  ? Icons.check_circle_outline 
                                  : Icons.repeat_rounded,
                              size: 20,
                              color: _alreadyReposted 
                                  ? ThixPolicy.success 
                                  : ThixPolicy.primary,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              _alreadyReposted
                                  ? _safeTr(l10n, 'profile_already_reposted', 'Déjà reposté')
                                  : _safeTr(l10n, 'profile_repost', 'Reposter'),
                              style: TextStyle(
                                color: _alreadyReposted 
                                    ? ThixPolicy.success 
                                    : ThixPolicy.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ));
                    }
                  }
                  
                  return items;
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCover() {
    if (!_hasCover) {
      return Container(
        color: ThixPolicy.surfaceSoft,
        child: Icon(
          Icons.play_circle_outline_rounded,
          color: ThixPolicy.textMuted.withValues(alpha: 0.4),
          size: 40,
        ),
      );
    }
    return CachedNetworkImage(
      imageUrl: _trimmedCoverUrl,
      fit: BoxFit.cover,
      fadeInDuration: const Duration(milliseconds: 200),
      placeholder: (_, __) => Container(color: ThixPolicy.surfaceSoft),
      errorWidget: (_, __, ___) => Container(
        color: ThixPolicy.surfaceSoft,
        child: const Icon(Icons.broken_image_rounded, color: Colors.white54, size: 24),
      ),
    );
  }

  Widget _buildGradient() => const DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Colors.transparent, Color(0x1A000000), Color(0xCC000000)],
        stops: [0.5, 0.7, 1.0],
      ),
    ),
  );

  Widget _buildPaidBadge() => Positioned(
    top: 6,
    left: 6,
    child: Container(
      padding: const EdgeInsets.all(4),
      decoration: const BoxDecoration(color: ThixPolicy.warning, shape: BoxShape.circle),
      child: const Icon(Icons.lock_rounded, size: 10, color: ThixPolicy.inkDeep),
    ),
  );

  Widget _buildPrivateBadge(AppLocalizations l10n) => Positioned(
    top: 6,
    left: widget.post.isPaid ? 28 : 6,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        _safeTr(l10n, 'profile_badge_private', 'Privé'),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
  );

  /// ✅ Badge Repost avec attribution à l'auteur original
  Widget _buildRepostBadge(AppLocalizations l10n) {
    final authorDisplay = _originalAuthorName != null && _originalAuthorName!.isNotEmpty
        ? '@${_originalAuthorName!}'
        : _safeTr(l10n, 'profile_original_author', 'auteur');
    
    return Positioned(
      top: 6,
      left: widget.post.isPaid ? 28 : 6,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: ThixPolicy.primary.withOpacity(0.95),
          borderRadius: BorderRadius.circular(6),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.repeat_rounded, color: Colors.white, size: 10),
            const SizedBox(width: 3),
            Flexible(
              child: Text(
                authorDisplay,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// ✅ Overlay stats : Vues + Reposts
  Widget _buildStatsOverlay(int views, int repostCount) => Positioned(
    left: 6,
    right: 6,
    bottom: 6,
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Vues
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 14),
            const SizedBox(width: 2),
            Text(
              _formatNumber(views),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                shadows: [Shadow(color: Colors.black54, blurRadius: 2)],
              ),
            ),
          ],
        ),
        // Reposts (si > 0)
        if (repostCount > 0)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.repeat_rounded, color: Colors.white, size: 12),
              const SizedBox(width: 2),
              Text(
                _formatNumber(repostCount),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  shadows: [Shadow(color: Colors.black54, blurRadius: 2)],
                ),
              ),
            ],
          ),
      ],
    ),
  );
}
