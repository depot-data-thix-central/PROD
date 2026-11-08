// lib/presentation/chat/status/status_viewer_page.dart
import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:intl/intl.dart';
import 'package:video_player/video_player.dart';

import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/l10n/app_localizations.dart';
import 'package:thix_id/models/chat/user_status_story.dart';
import 'package:thix_id/presentation/chat/providers/status_provider.dart';
import 'package:thix_id/presentation/chat/status/create_status_page.dart';
import 'package:thix_id/services/chat/status_service.dart';

// ============================================================================
// CONSTANTS
// ============================================================================
const Duration _kTextDuration = Duration(seconds: 5);
const Duration _kImageDuration = Duration(seconds: 7);
const Duration _kMaxVideoDuration = Duration(seconds: 120); // 2 min max
const double _kProgressHeight = 3.0;
const double _kAvatarRadius = 18.0;
const double _kFontSizeContent = 32.0;
const double _kFontSizeName = 14.0;
const double _kFontSizeTime = 11.0;
const int _kMaxNameLength = 80;
const int _kMaxContentLength = 500;

// ============================================================================
// VALIDATORS
// ============================================================================
class _StatusValidators {
  _StatusValidators._();

  static String sanitize(String? input, {int maxLength = 500}) {
    if (input == null || input.trim().isEmpty) return '';
    final doc = html_parser.parse(input);
    var s = doc.body?.text ?? input;
    s = s
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll(RegExp(r'javascript:', caseSensitive: false), '')
        .replaceAll(RegExp(r'on\w+\s*=', caseSensitive: false), '')
        .replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '')
        .trim();
    return s.length > maxLength ? s.substring(0, maxLength) : s;
  }

  static String? sanitizeUrl(String? url) {
    if (url == null || url.trim().isEmpty) return null;
    final t = url.trim();
    if (!t.startsWith('http://') && !t.startsWith('https://')) return null;
    return t.replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '');
  }

  static Color parseBg(String hex) {
    try {
      final h = hex.replaceAll('#', '');
      if (h.length < 6) return ThixPolicy.primary;
      return Color(int.parse('FF$h', radix: 16));
    } catch (_) {
      return ThixPolicy.primary;
    }
  }

  /// Détecte si l'URL pointe vers une vidéo (par extension ou path).
  static bool isVideoUrl(String? url) {
    if (url == null) return false;
    final lower = url.toLowerCase();
    return lower.endsWith('.mp4') ||
        lower.endsWith('.mov') ||
        lower.endsWith('.m4v') ||
        lower.endsWith('.webm') ||
        lower.endsWith('.avi') ||
        lower.contains('/videos/') ||
        lower.contains('/video/');
  }

  static String friendlyError(dynamic e) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('timeout')) return 'Délai dépassé. Vérifiez votre connexion.';
    if (msg.contains('network')) return 'Erreur réseau. Réessayez.';
    if (msg.contains('not found')) return 'Statut introuvable.';
    return 'Une erreur est survenue.';
  }
}

// ============================================================================
// STATUS VIEWER PAGE
// ============================================================================

class StatusViewerPage extends ConsumerStatefulWidget {
  final List<UserStatusStory> stories;
  final int initialIndex;

  const StatusViewerPage({
    super.key,
    required this.stories,
    this.initialIndex = 0,
  });

  @override
  ConsumerState<StatusViewerPage> createState() => _StatusViewerPageState();
}

class _StatusViewerPageState extends ConsumerState<StatusViewerPage>
    with SingleTickerProviderStateMixin {
  late PageController _pageCtrl;
  late AnimationController _progress;
  int _index = 0;
  bool _paused = false;
  bool _isNavigating = false;

  // Video
  VideoPlayerController? _videoCtrl;
  bool _videoReady = false;
  Duration _videoDuration = Duration.zero;
  Timer? _videoProgressTimer;

  // Floating reactions
  final List<_FloatingReaction> _floatingReactions = [];

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, (widget.stories.length - 1).clamp(0, 999999));
    _pageCtrl = PageController(initialPage: _index);
    _progress = AnimationController(vsync: this)
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed && !_isNavigating && !mounted) return;
        if (s == AnimationStatus.completed && !_isNavigating) _next();
      });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _onStoryChanged();
    });
  }

  @override
  void dispose() {
    _progress.dispose();
    _pageCtrl.dispose();
    _disposeVideo();
    _videoProgressTimer?.cancel();
    super.dispose();
  }

  // ============================================================================
  // VIDEO MANAGEMENT
  // ============================================================================

  void _disposeVideo() {
    _videoProgressTimer?.cancel();
    _videoProgressTimer = null;
    final c = _videoCtrl;
    _videoCtrl = null;
    _videoReady = false;
    if (c != null) {
      try {
        c.dispose();
      } catch (_) {}
    }
  }

  Future<void> _initVideoIfNeeded(UserStatusStory s) async {
    _disposeVideo();
    final url = _StatusValidators.sanitizeUrl(s.mediaUrl);
    if (url == null || !s.isVideo) return;

    final uri = Uri.tryParse(url);
    if (uri == null) return;

    final c = VideoPlayerController.networkUrl(
      uri,
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: false),
    );
    _videoCtrl = c;
    _videoReady = false;

    try {
      await c.initialize();
      if (!mounted || _videoCtrl != c) return;

      // Clamp la durée à 2 min max
      final realDur = c.value.duration;
      _videoDuration = realDur > _kMaxVideoDuration ? _kMaxVideoDuration : realDur;

      await c.setLooping(false);
      await c.setVolume(1.0);
      if (!_paused) await c.play();

      if (!mounted) return;
      setState(() => _videoReady = true);

      // Poll la position vidéo pour synchroniser la barre de progression
      _videoProgressTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
        if (!mounted || _videoCtrl != c) return;
        if (_paused) return;
        final pos = c.value.position;
        if (pos >= _videoDuration && _videoDuration > Duration.zero) {
          _next();
        } else {
          setState(() {}); // force rebuild pour mettre à jour la barre
        }
      });
    } catch (e) {
      debugPrint('[StatusViewer] ❌ Video init error: $e');
      _videoReady = false;
      // Fallback : progress via animation controller
      _startProgress();
    }
  }

  double _videoProgress() {
    final c = _videoCtrl;
    if (c == null || !_videoReady || _videoDuration == Duration.zero) return 0;
    final pos = c.value.position;
    return (pos.inMilliseconds / _videoDuration.inMilliseconds).clamp(0.0, 1.0);
  }

  void _pauseVideo() {
    try {
      _videoCtrl?.pause();
    } catch (_) {}
  }

  void _resumeVideo() {
    try {
      _videoCtrl?.play();
    } catch (_) {}
  }

  // ============================================================================
  // STORY LIFECYCLE
  // ============================================================================

  Duration _durationFor(UserStatusStory s) {
    if (s.isVideo) return _videoDuration > Duration.zero ? _videoDuration : _kImageDuration;
    if (s.isImage) return _kImageDuration;
    return _kTextDuration;
  }

  void _onStoryChanged() {
    if (widget.stories.isEmpty) return;
    final s = widget.stories[_index];
    _markCurrent();

    if (s.isVideo) {
      _progress.stop();
      _progress.reset();
      _initVideoIfNeeded(s);
    } else {
      _disposeVideo();
      _startProgress();
    }
  }

  void _startProgress() {
    if (_paused || widget.stories.isEmpty || _isNavigating) return;
    final s = widget.stories[_index];
    if (s.isVideo) return; // progress gérée par le video timer
    _progress.duration = _durationFor(s);
    _progress.forward(from: 0);
  }

  void _pause() {
    if (!_paused) {
      _paused = true;
      _progress.stop();
      _pauseVideo();
    }
  }

  void _resume() {
    if (_paused) {
      _paused = false;
      final s = widget.stories[_index];
      if (s.isVideo) {
        _resumeVideo();
      } else {
        _progress.forward();
      }
    }
  }

  void _next() {
    if (_isNavigating) return;
    if (_index >= widget.stories.length - 1) {
      if (mounted) Navigator.pop(context);
      return;
    }
    _isNavigating = true;
    setState(() => _index++);
    _pageCtrl.jumpToPage(_index);

    Future.delayed(const Duration(milliseconds: 50), () {
      if (mounted) {
        _isNavigating = false;
        _onStoryChanged();
      }
    });
  }

  void _prev() {
    if (_isNavigating) return;
    if (_index <= 0) {
      // Restart current
      _restartCurrent();
      return;
    }
    _isNavigating = true;
    setState(() => _index--);
    _pageCtrl.jumpToPage(_index);

    Future.delayed(const Duration(milliseconds: 50), () {
      if (mounted) {
        _isNavigating = false;
        _onStoryChanged();
      }
    });
  }

  void _restartCurrent() {
    if (widget.stories.isEmpty) return;
    final s = widget.stories[_index];
    if (s.isVideo) {
      _videoCtrl?.seekTo(Duration.zero);
      _videoCtrl?.play();
    } else {
      _progress.forward(from: 0);
    }
  }

  void _markCurrent() {
    if (widget.stories.isEmpty) return;
    final s = widget.stories[_index];
    if (!s.isMine && !s.hasViewed) {
      ref.read(statusProvider.notifier).markViewed(s.statusId);
    }
  }

  // ============================================================================
  // TIME FORMATTING
  // ============================================================================

  String _formatTime(DateTime dt, AppLocalizations l10n) {
    final local = dt.toLocal();
    final now = DateTime.now();
    final diff = now.difference(local);

    if (diff.inMinutes < 1) return l10n.t('status_just_now');
    if (diff.inMinutes < 60) return '${diff.inMinutes} ${l10n.t('status_minutes_ago')}';
    if (diff.inHours < 24 && local.day == now.day) {
      return DateFormat('HH:mm').format(local);
    }
    if (diff.inHours < 48) {
      return '${l10n.t('status_yesterday')} ${DateFormat('HH:mm').format(local)}';
    }
    return DateFormat('dd/MM HH:mm').format(local);
  }

  // ============================================================================
  // ACTIONS
  // ============================================================================

  Future<void> _delete() async {
    final l10n = AppLocalizations.of(context);
    HapticFeedback.mediumImpact();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ThixPolicy.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: ThixPolicy.border),
        ),
        title: Text(l10n.t('status_delete_title'), style: ThixPolicy.titleStyle.copyWith(fontWeight: FontWeight.w800)),
        content: Text(l10n.t('status_delete_message'), style: ThixPolicy.bodyStyle),
        actions: [
          TextButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              Navigator.pop(ctx, false);
            },
            child: Text(l10n.t('common_cancel')),
          ),
          TextButton(
            onPressed: () {
              HapticFeedback.mediumImpact();
              Navigator.pop(ctx, true);
            },
            child: Text(l10n.t('common_delete'), style: const TextStyle(color: ThixPolicy.danger, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (ok != true || !mounted) return;

    final s = widget.stories[_index];
    try {
      debugPrint('[StatusViewer] 🗑️ Deleting status: ${s.statusId}');
      await ref.read(statusServiceProvider).deleteStatus(s.statusId);
      await ref.read(statusProvider.notifier).refresh();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      debugPrint('[StatusViewer] ❌ Delete error: $e');
      if (mounted) _showError(_StatusValidators.friendlyError(e));
    }
  }

  Future<void> _react(String emoji) async {
    final l10n = AppLocalizations.of(context);
    HapticFeedback.selectionClick();

    // Floating reaction animation
    setState(() {
      _floatingReactions.add(_FloatingReaction(
        emoji: emoji,
        key: UniqueKey(),
      ));
    });

    // Clean up old reactions
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _floatingReactions.removeWhere((r) => r.createdAt.isBefore(DateTime.now().subtract(const Duration(seconds: 2))));
        });
      }
    });

    final s = widget.stories[_index];
    try {
      await ref.read(statusServiceProvider).react(s.statusId, emoji);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(children: [
            Text(emoji, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 8),
            Expanded(child: Text('${l10n.t('status_reaction_sent')} $emoji')),
          ]),
          backgroundColor: ThixPolicy.success,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(milliseconds: 1200),
        ),
      );
    } catch (e) {
      debugPrint('[StatusViewer] ❌ React error: $e');
      if (mounted) _showError(_StatusValidators.friendlyError(e));
    }
  }

  /// Double-tap = ❤️ flottant + réaction auto
  void _doubleTapHeart() {
    HapticFeedback.mediumImpact();
    setState(() {
      _floatingReactions.add(_FloatingReaction(
        emoji: '❤️',
        key: UniqueKey(),
        large: true,
      ));
    });
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _floatingReactions.clear());
    });
    _react('❤️');
  }

  Future<void> _repost() async {
    final l10n = AppLocalizations.of(context);
    HapticFeedback.mediumImpact();

    final s = widget.stories[_index];
    try {
      final id = await ref.read(statusServiceProvider).repost(s);
      await ref.read(statusProvider.notifier).refresh();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text(id != null ? l10n.t('status_reposted') : l10n.t('status_repost_error'))),
          ]),
          backgroundColor: id != null ? ThixPolicy.success : ThixPolicy.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      debugPrint('[StatusViewer] ❌ Repost error: $e');
      if (mounted) _showError(_StatusValidators.friendlyError(e));
    }
  }

  void _edit() {
    HapticFeedback.selectionClick();
    Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateStatusPage()));
  }

  Future<void> _showViewers(String statusId) async {
    final l10n = AppLocalizations.of(context);
    _pause();

    try {
      final viewers = await ref.read(statusServiceProvider).getViewers(statusId);
      if (!mounted) return;

      await showModalBottomSheet(
        context: context,
        backgroundColor: ThixPolicy.card,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (ctx) {
          return DraggableScrollableSheet(
            initialChildSize: 0.55,
            minChildSize: 0.3,
            maxChildSize: 0.9,
            expand: false,
            builder: (_, scrollCtrl) {
              return Column(
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: ThixPolicy.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        const Icon(Icons.visibility_outlined, size: 20, color: ThixPolicy.textMain),
                        const SizedBox(width: 8),
                        Text(
                          '${l10n.t('status_viewed_by')} ${viewers.length}',
                          style: ThixPolicy.titleStyle.copyWith(fontWeight: FontWeight.w800, fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: ThixPolicy.border),
                  Expanded(
                    child: viewers.isEmpty
                        ? Center(
                            child: Text(
                              l10n.t('status_no_views'),
                              style: ThixPolicy.bodyStyle.copyWith(color: ThixPolicy.textMuted),
                            ),
                          )
                        : ListView.builder(
                            controller: scrollCtrl,
                            itemCount: viewers.length,
                            itemBuilder: (_, i) {
                              final v = viewers[i];
                              final rawName = v['display_name']?.toString() ?? '';
                              final name = _StatusValidators.sanitize(rawName, maxLength: _kMaxNameLength);
                              final rawAvatar = v['avatar_url']?.toString();
                              final avatarUrl = _StatusValidators.sanitizeUrl(rawAvatar);
                              final viewedAt = DateTime.tryParse('${v['viewed_at']}')?.toLocal();
                              final time = viewedAt != null ? DateFormat('HH:mm').format(viewedAt) : '';

                              return ListTile(
                                leading: CircleAvatar(
                                  radius: 20,
                                  backgroundColor: ThixPolicy.surfaceSoft,
                                  backgroundImage: avatarUrl != null ? CachedNetworkImageProvider(avatarUrl) : null,
                                  child: avatarUrl == null
                                      ? Text(
                                          name.isNotEmpty ? name[0].toUpperCase() : '?',
                                          style: TextStyle(color: ThixPolicy.primary, fontWeight: FontWeight.bold),
                                        )
                                      : null,
                                ),
                                title: Text(
                                  name.isEmpty ? l10n.t('status_unknown_user') : name,
                                  style: ThixPolicy.bodyStyle.copyWith(fontWeight: FontWeight.w600),
                                ),
                                trailing: Text(
                                  time,
                                  style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.textMuted, fontSize: 12),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              );
            },
          );
        },
      );
    } catch (e) {
      debugPrint('[StatusViewer] ❌ Fetch viewers error: $e');
      if (mounted) _showError(_StatusValidators.friendlyError(e));
    } finally {
      if (mounted) _resume();
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          const Icon(Icons.error_outline_rounded, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(message)),
        ]),
        backgroundColor: ThixPolicy.danger,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ============================================================================
  // BUILD
  // ============================================================================

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final stories = widget.stories;

    if (stories.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Text(
            l10n.t('status_no_stories'),
            style: const TextStyle(color: Colors.white),
          ),
        ),
      );
    }

    final current = stories[_index];
    final safeName = _StatusValidators.sanitize(current.displayName, maxLength: _kMaxNameLength);
    final safeContent = _StatusValidators.sanitize(current.content ?? '', maxLength: _kMaxContentLength);
    final safeAvatar = _StatusValidators.sanitizeUrl(current.avatarUrl);
    final bgColor = _StatusValidators.parseBg(current.background);

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onLongPressStart: (_) => _pause(),
        onLongPressEnd: (_) => _resume(),
        onDoubleTap: _doubleTapHeart,
        onTapUp: (d) {
          if (_isNavigating) return;
          final w = MediaQuery.of(context).size.width;
          // Zones de tap : 30% gauche = prev, 30% droite = next, 40% centre = rien (pour ne pas gêner le long press)
          if (d.localPosition.dx < w * 0.3) {
            _prev();
          } else if (d.localPosition.dx > w * 0.7) {
            _next();
          }
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ── CONTENU : format portrait 9:16 ──
            PageView.builder(
              controller: _pageCtrl,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: stories.length,
              onPageChanged: (i) {
                if (i != _index && !_isNavigating) {
                  setState(() => _index = i);
                  _onStoryChanged();
                }
              },
              itemBuilder: (_, i) {
                return _buildStoryContent(stories[i], i == _index, bgColor, safeContent);
              },
            ),

            // ── Floating reactions ──
            ..._floatingReactions.map((r) => _FloatingHeart(key: r.key, emoji: r.emoji, large: r.large)),

            // ── TOP BAR ──
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: Column(
                  children: [
                    // Progress bars
                    Row(
                      children: List.generate(stories.length, (i) {
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            child: AnimatedBuilder(
                              animation: _progress,
                              builder: (_, __) {
                                double value = 0;
                                if (i < _index) {
                                  value = 1;
                                } else if (i == _index) {
                                  final s = stories[i];
                                  value = s.isVideo && _videoReady ? _videoProgress() : _progress.value;
                                }
                                return _StoryProgressBar(value: value);
                              },
                            ),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 12),

                    // Header Info
                    Row(
                      children: [
                        CircleAvatar(
                          radius: _kAvatarRadius,
                          backgroundColor: ThixPolicy.surfaceSoft,
                          backgroundImage: safeAvatar != null ? CachedNetworkImageProvider(safeAvatar) : null,
                          child: safeAvatar == null
                              ? const Icon(Icons.person, color: Colors.white, size: 18)
                              : null,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                current.isMine
                                    ? l10n.t('status_my_status')
                                    : (safeName.isEmpty ? l10n.t('status_unknown_user') : safeName),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: _kFontSizeName,
                                ),
                              ),
                              Text(
                                _formatTime(current.createdAt, l10n),
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: _kFontSizeTime,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (current.isMine)
                          PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert, color: Colors.white),
                            color: ThixPolicy.card,
                            surfaceTintColor: ThixPolicy.card,
                            onSelected: (v) {
                              HapticFeedback.selectionClick();
                              if (v == 'edit') _edit();
                              if (v == 'delete') _delete();
                              if (v == 'views') _showViewers(current.statusId);
                            },
                            itemBuilder: (_) => [
                              PopupMenuItem(
                                value: 'views',
                                child: Row(children: [
                                  const Icon(Icons.visibility_outlined, size: 18),
                                  const SizedBox(width: 8),
                                  Text(l10n.t('status_view_views')),
                                ]),
                              ),
                              PopupMenuItem(
                                value: 'edit',
                                child: Row(children: [
                                  const Icon(Icons.edit_outlined, size: 18),
                                  const SizedBox(width: 8),
                                  Text(l10n.t('status_edit')),
                                ]),
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                child: Row(children: [
                                  const Icon(Icons.delete_outline, size: 18, color: ThixPolicy.danger),
                                  const SizedBox(width: 8),
                                  Text(l10n.t('status_delete'), style: const TextStyle(color: ThixPolicy.danger)),
                                ]),
                              ),
                            ],
                          )
                        else
                          Semantics(
                            button: true,
                            label: l10n.t('common_close'),
                            child: IconButton(
                              icon: const Icon(Icons.close, color: Colors.white),
                              onPressed: () {
                                HapticFeedback.selectionClick();
                                Navigator.pop(context);
                              },
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // ── Pause indicator ──
            if (_paused)
              Center(
                child: IgnorePointer(
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.4),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.pause_rounded, color: Colors.white, size: 48),
                  ),
                ),
              ),

            // ── BOTTOM ACTIONS ──
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                child: Container(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withOpacity(0.6),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: Row(
                    children: [
                      if (current.isMine)
                        Semantics(
                          button: true,
                          label: l10n.t('status_view_views'),
                          child: TextButton.icon(
                            onPressed: () => _showViewers(current.statusId),
                            icon: const Icon(Icons.visibility, color: Colors.white70, size: 18),
                            label: Text(
                              '${current.viewsCount ?? 0}',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      _ReactBtn('❤️', () => _react('❤️')),
                      _ReactBtn('👍', () => _react('👍')),
                      _ReactBtn('😂', () => _react('😂')),
                      _ReactBtn('🔥', () => _react('🔥')),
                      _ReactBtn('😮', () => _react('😮')),
                      const Spacer(),
                      if (!current.isMine)
                        Semantics(
                          button: true,
                          label: l10n.t('status_repost'),
                          child: TextButton.icon(
                            onPressed: _repost,
                            icon: const Icon(Icons.repeat, color: Colors.white, size: 18),
                            label: Text(
                              l10n.t('status_repost'),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================================
  // STORY CONTENT (portrait 9:16)
  // ============================================================================

  Widget _buildStoryContent(UserStatusStory s, bool isCurrent, Color bgColor, String safeContent) {
    final mediaUrl = _StatusValidators.sanitizeUrl(s.mediaUrl);

    // ── VIDEO ──
    if (s.isVideo && mediaUrl != null) {
      if (isCurrent && _videoReady && _videoCtrl != null && _videoCtrl!.value.isInitialized) {
        return Container(
          color: Colors.black,
          child: Center(
            child: AspectRatio(
              aspectRatio: _videoCtrl!.value.aspectRatio > 0
                  ? _videoCtrl!.value.aspectRatio
                  : 9 / 16,
              child: VideoPlayer(_videoCtrl!),
            ),
          ),
        );
      }
      // Loading state
      return Container(
        color: Colors.black,
        child: const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    // ── IMAGE (format portrait 9:16) ──
    if (s.isImage && mediaUrl != null) {
      return Container(
        color: Colors.black,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxHeight: double.infinity,
              maxWidth: double.infinity,
            ),
            child: CachedNetworkImage(
              imageUrl: mediaUrl,
              // ✅ BoxFit.cover pour remplir le cadre 9:16 vertical
              fit: BoxFit.cover,
              alignment: Alignment.center,
              placeholder: (_, __) => Container(
                color: Colors.black,
                child: const Center(
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                ),
              ),
              errorWidget: (_, __, ___) => Center(
                child: Icon(Icons.broken_image_outlined, color: Colors.white54, size: 64),
              ),
            ),
          ),
        ),
      );
    }

    // ── TEXT ──
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            bgColor,
            HSLColor.fromColor(bgColor).withLightness((HSLColor.fromColor(bgColor).lightness - 0.15).clamp(0.0, 1.0)).toColor(),
          ],
        ),
      ),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(32),
      child: Text(
        safeContent.isEmpty ? '—' : safeContent,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontSize: _kFontSizeContent,
          fontWeight: FontWeight.w800,
          height: 1.3,
          letterSpacing: -0.5,
          shadows: [
            Shadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 2)),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// PROGRESS BAR (style WhatsApp avec bordures arrondies)
// ============================================================================
class _StoryProgressBar extends StatelessWidget {
  final double value;
  const _StoryProgressBar({required this.value});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: LinearProgressIndicator(
        value: value,
        minHeight: 2.5,
        backgroundColor: Colors.white24,
        valueColor: const AlwaysStoppedAnimation(Colors.white),
      ),
    );
  }
}

// ============================================================================
// REACT BUTTON
// ============================================================================
class _ReactBtn extends StatelessWidget {
  final String emoji;
  final VoidCallback onTap;

  const _ReactBtn(this.emoji, this.onTap);

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Réagir avec $emoji',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 6),
          child: Text(emoji, style: const TextStyle(fontSize: 22)),
        ),
      ),
    );
  }
}

// ============================================================================
// FLOATING REACTION (animation type Instagram/WhatsApp)
// ============================================================================
class _FloatingReaction {
  final String emoji;
  final Key key;
  final DateTime createdAt;
  final bool large;

  _FloatingReaction({
    required this.emoji,
    required this.key,
    this.large = false,
  }) : createdAt = DateTime.now();
}

class _FloatingHeart extends StatefulWidget {
  final String emoji;
  final bool large;

  const _FloatingHeart({super.key, required this.emoji, this.large = false});

  @override
  State<_FloatingHeart> createState() => _FloatingHeartState();
}

class _FloatingHeartState extends State<_FloatingHeart>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: widget.large ? 900 : 1800),
  );
  late final Animation<double> _opacity = Tween<double>(begin: 1.0, end: 0.0).animate(
    CurvedAnimation(parent: _ctrl, curve: const Interval(0.6, 1.0, curve: Curves.easeOut)),
  );
  late final Animation<double> _scale = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.2).chain(CurveTween(curve: Curves.easeOutBack)), weight: 30),
    TweenSequenceItem(tween: Tween(begin: 1.2, end: 1.0).chain(CurveTween(curve: Curves.easeOut)), weight: 20),
    TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0).chain(CurveTween(curve: Curves.linear)), weight: 50),
  ]).animate(_ctrl);
  late final Animation<Offset> _float = Tween<Offset>(
    begin: Offset.zero,
    end: const Offset(0, -120),
  ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));

  @override
  void initState() {
    super.initState();
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Center(
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (context, _) {
            return Opacity(
              opacity: _opacity.value,
              child: Transform.translate(
                offset: Offset(0, widget.large ? 0 : _float.value.dy),
                child: Transform.scale(
                  scale: _scale.value,
                  child: Text(
                    widget.emoji,
                    style: TextStyle(
                      fontSize: widget.large ? 110 : 48,
                      shadows: [
                        Shadow(color: Colors.black.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4)),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
