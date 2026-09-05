/// ProfileVideoCard (Production Enterprise)
/// Menu ⋮ : Modifier · Privé/Public · Supprimer (uniquement si isOwner)
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  final String ownerUserId; // pour invalider userPostsProvider
  final VoidCallback? onChanged; // refresh optionnel après edit/delete

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

  @override
  void initState() {
    super.initState();
    _trimmedCoverUrl = widget.post.coverUrl.trim();
    _hasCover = _trimmedCoverUrl.isNotEmpty;
  }

  @override
  void didUpdateWidget(covariant ProfileVideoCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.post.coverUrl != widget.post.coverUrl) {
      _trimmedCoverUrl = widget.post.coverUrl.trim();
      _hasCover = _trimmedCoverUrl.isNotEmpty;
    }
  }

  String _safeTr(AppLocalizations l10n, String key, String fallback) {
    final val = l10n.t(key);
    if (val.isEmpty || val == key || val.contains(key)) return fallback;
    return val;
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

  // ── MENU ACTIONS ──────────────────────────────────────────

  Future<void> _onMenuSelected(String action) async {
    if (_busy || !widget.isOwner) return;
    HapticFeedback.selectionClick();

    switch (action) {
      case 'edit':
        await _editTitleDescription();
        break;
      case 'toggle_private':
        await _togglePublished();
        break;
      case 'delete':
        await _confirmAndDelete();
        break;
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
      // À brancher sur ton updateMedia (ou RPC)
      await MediaService().updateMediaMeta(
        widget.post.id,
        title: newTitle,
        subtitle: descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
      );
      widget.onChanged?.call();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_safeTr(l10n, 'profile_edit_success', 'Vidéo mise à jour')),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_safeTr(l10n, 'profile_edit_error', 'Échec de la modification')),
            backgroundColor: ThixPolicy.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _togglePublished() async {
    final l10n = AppLocalizations.of(context);
    final makePrivate = widget.post.isPublished; // si publié → on le rend privé

    setState(() => _busy = true);
    try {
      await MediaService().updateMediaMeta(
        widget.post.id,
        isPublished: !widget.post.isPublished,
      );
      widget.onChanged?.call();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              makePrivate
                  ? _safeTr(l10n, 'profile_now_private', 'Vidéo en privé')
                  : _safeTr(l10n, 'profile_now_public', 'Vidéo publiée'),
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_safeTr(l10n, 'profile_edit_error', 'Échec de la modification')),
            backgroundColor: ThixPolicy.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
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
        content: Text(
          _safeTr(
            l10n,
            'profile_delete_confirm',
            'Cette action est définitive. La vidéo sera supprimée pour tout le monde.',
          ),
        ),
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

      ref
          .read(userPostsProvider(widget.ownerUserId).notifier)
          .removePost(widget.post.id);
      widget.onChanged?.call();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_safeTr(l10n, 'profile_delete_success', 'Vidéo supprimée')),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_safeTr(l10n, 'profile_delete_error', 'Impossible de supprimer')),
            backgroundColor: ThixPolicy.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
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

  // ── BUILD ─────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final liveStats = ref.watch(mediaCountsStreamProvider(widget.post.id));
    final views = liveStats.valueOrNull?.viewCount ?? widget.post.viewCount;

    return RepaintBoundary(
      child: Semantics(
        button: true,
        label: '${widget.post.title}. ${_formatNumber(views)} vues.',
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
                    if (widget.post.isPaid) _buildPaidBadge(l10n),
                    if (!widget.post.isPublished) _buildPrivateBadge(l10n),
                    _buildViewsOverlay(views),
                  ],
                ),
              ),
            ),

            // ⋮ MENU (uniquement propriétaire)
            if (widget.isOwner)
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
                    itemBuilder: (ctx) => [
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
                            Text(
                              widget.post.isPublished
                                  ? _safeTr(l10n, 'profile_menu_private', 'Mettre en privé')
                                  : _safeTr(l10n, 'profile_menu_public', 'Publier'),
                            ),
                          ],
                        ),
                      ),
                      const PopupMenuDivider(),
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline, size: 20, color: ThixPolicy.danger),
                            const SizedBox(width: 12),
                            Text(
                              _safeTr(l10n, 'profile_menu_delete', 'Supprimer'),
                              style: TextStyle(color: ThixPolicy.danger),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
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
      memCacheWidth: 200,
      memCacheHeight: 300,
      fadeInDuration: const Duration(milliseconds: 200),
      placeholder: (_, __) => Container(color: ThixPolicy.surfaceSoft),
      errorWidget: (_, __, ___) => Container(
        color: ThixPolicy.surfaceSoft,
        child: Icon(Icons.broken_image_rounded, color: ThixPolicy.textMuted, size: 24),
      ),
    );
  }

  Widget _buildGradient() {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Color(0x1A000000), Color(0xCC000000)],
          stops: [0.5, 0.7, 1.0],
        ),
      ),
    );
  }

  Widget _buildPaidBadge(AppLocalizations l10n) {
    return Positioned(
      top: 6,
      left: 6,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: const BoxDecoration(
          color: ThixPolicy.warning,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.lock_rounded, size: 10, color: ThixPolicy.inkDeep),
      ),
    );
  }

  Widget _buildPrivateBadge(AppLocalizations l10n) {
    return Positioned(
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
          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Widget _buildViewsOverlay(int views) {
    return Positioned(
      left: 6,
      bottom: 6,
      child: Row(
        children: [
          const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 14),
          const SizedBox(width: 2),
          Text(
            _formatNumber(views),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
