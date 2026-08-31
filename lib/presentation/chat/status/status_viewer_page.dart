// lib/presentation/chat/status/status_viewer_page.dart
import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:intl/intl.dart';

import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/l10n/app_localizations.dart';
import 'package:thix_id/models/chat/user_status_story.dart';
import 'package:thix_id/presentation/chat/providers/chat_providers.dart';
import 'package:thix_id/presentation/chat/providers/status_provider.dart';
import 'package:thix_id/presentation/chat/status/create_status_page.dart';
import 'package:thix_id/services/chat/status_service.dart';

// ============================================================================
// CONSTANTS
// ============================================================================
const Duration _kTextDuration = Duration(seconds: 5);
const Duration _kImageDuration = Duration(seconds: 7);
const double _kProgressHeight = 3.0;
const double _kAvatarRadius = 18.0;
const double _kFontSizeContent = 28.0;
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

/// Visionneuse de statuts (Stories) avec navigation, réactions et métriques.
///
/// Fonctionnalités :
/// - Navigation tactile (gauche/droite) ou swipe
/// - Appui long pour pause
/// - Barres de progression multiples
/// - Réactions rapides
/// - Menu actions (propriétaire) : vues, edit, delete
/// - Repost (non propriétaire)
class StatusViewerPage extends ConsumerStatefulWidget {
  final List<UserStatusStory> stories;

  const StatusViewerPage({super.key, required this.stories});

  @override
  ConsumerState<StatusViewerPage> createState() => _StatusViewerPageState();
}

class _StatusViewerPageState extends ConsumerState<StatusViewerPage>
    with SingleTickerProviderStateMixin {
  late PageController _pageCtrl;
  late AnimationController _progress;
  int _index = 0;
  bool _paused = false;
  bool _isNavigating = false; // Protection race condition

  @override
  void initState() {
    super.initState();
    _pageCtrl = PageController();
    _progress = AnimationController(vsync: this)
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed && !_isNavigating) _next();
      });
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _markCurrent();
      _startProgress();
    });
  }

  @override
  void dispose() {
    _progress.dispose();
    _pageCtrl.dispose();
    super.dispose();
  }

  Duration get _currentDuration {
    if (widget.stories.isEmpty) return _kTextDuration;
    final s = widget.stories[_index];
    return s.isImage ? _kImageDuration : _kTextDuration;
  }

  void _startProgress() {
    if (_paused || widget.stories.isEmpty || _isNavigating) return;
    _progress.duration = _currentDuration;
    _progress.forward(from: 0);
  }

  void _pause() {
    if (!_paused) {
      _paused = true;
      _progress.stop();
    }
  }

  void _resume() {
    if (_paused) {
      _paused = false;
      _progress.forward();
    }
  }

  void _next() {
    if (_isNavigating || _index >= widget.stories.length - 1) {
      if (!_isNavigating && mounted) Navigator.pop(context);
      return;
    }

    _isNavigating = true;
    setState(() => _index++);
    _pageCtrl.jumpToPage(_index);
    _markCurrent();
    
    // Petit délai pour éviter les conflits d'animation
    Future.delayed(const Duration(milliseconds: 50), () {
      if (mounted) {
        _isNavigating = false;
        _startProgress();
      }
    });
  }

  void _prev() {
    if (_isNavigating || _index <= 0) {
      if (!_isNavigating && mounted) Navigator.pop(context);
      return;
    }

    _isNavigating = true;
    setState(() => _index--);
    _pageCtrl.jumpToPage(_index);
    _markCurrent();

    Future.delayed(const Duration(milliseconds: 50), () {
      if (mounted) {
        _isNavigating = false;
        _startProgress();
      }
    });
  }

  void _markCurrent() {
    if (widget.stories.isEmpty) return;
    final s = widget.stories[_index];
    if (!s.isMine && !s.hasViewed) {
      ref.read(statusProvider.notifier).markViewed(s.statusId);
    }
  }

  String _formatTime(DateTime dt, AppLocalizations l10n) {
    final local = dt.toLocal();
    final now = DateTime.now();
    final diff = now.difference(local);

    if (diff.inMinutes < 1) return l10n.t('status_just_now');
    if (diff.inMinutes < 60) return l10n.t('status_minutes_ago', args: ['${diff.inMinutes}']);
    if (diff.inHours < 24 && local.day == now.day) {
      return DateFormat('HH:mm').format(local);
    }
    if (diff.inHours < 48) {
      return '${l10n.t('status_yesterday')} ${DateFormat('HH:mm').format(local)}';
    }
    return DateFormat('dd/MM HH:mm').format(local);
  }

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
        title: Text(l10n.t('status_delete_title'), style: ThixPolicy.titleStyle.copyWith(fontWeight: ThixPolicy.bold)),
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
      debugPrint('[StatusViewer] ️ Deleting status: ${s.statusId}');
      await ref.read(statusServiceProvider).deleteStatus(s.statusId);
      await ref.read(statusProvider.notifier).refresh();
      if (mounted) Navigator.pop(context);
      debugPrint('[StatusViewer] ✓ Status deleted');
    } catch (e) {
      debugPrint('[StatusViewer] ❌ Delete error: $e');
      if (mounted) _showError(_StatusValidators.friendlyError(e));
    }
  }

  Future<void> _react(String emoji) async {
    final l10n = AppLocalizations.of(context);
    HapticFeedback.selectionClick();
    
    final s = widget.stories[_index];
    try {
      debugPrint('[StatusViewer] ❤️ Reacting with $emoji');
      await ref.read(statusServiceProvider).react(s.statusId, emoji);
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(children: [
            Text(emoji, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 8),
            Expanded(child: Text(l10n.t('status_reaction_sent', args: [emoji]))),
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

  Future<void> _repost() async {
    final l10n = AppLocalizations.of(context);
    HapticFeedback.mediumImpact();

    final s = widget.stories[_index];
    try {
      debugPrint('[StatusViewer] 🔄 Reposting status');
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
      debugPrint('[StatusViewer] 👁️ Fetching viewers for $statusId');
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
            initialChildSize: 0.45,
            minChildSize: 0.3,
            maxChildSize: 0.85,
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
                          l10n.t('status_viewed_by', args: ['${viewers.length}']),
                          style: ThixPolicy.titleStyle.copyWith(fontWeight: ThixPolicy.bold, fontSize: 16),
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
    final safeMedia = _StatusValidators.sanitizeUrl(current.mediaUrl);
    final bgColor = _StatusValidators.parseBg(current.background);

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onLongPressStart: (_) => _pause(),
        onLongPressEnd: (_) => _resume(),
        onTapUp: (d) {
          if (_isNavigating) return;
          final w = MediaQuery.of(context).size.width;
          if (d.localPosition.dx < w / 3) {
            _prev();
          } else if (d.localPosition.dx > 2 * w / 3) {
            _next();
          }
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ─ Contenu (Image ou Texte) ──
            PageView.builder(
              controller: _pageCtrl,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: stories.length,
              onPageChanged: (i) {
                // Sync index si swipe manuel
                if (i != _index) {
                  setState(() => _index = i);
                  _markCurrent();
                }
              },
              itemBuilder: (_, i) {
                final s = stories[i];
                final mediaUrl = _StatusValidators.sanitizeUrl(s.mediaUrl);
                
                if (s.isImage && mediaUrl != null) {
                  return CachedNetworkImage(
                    imageUrl: mediaUrl,
                    fit: BoxFit.contain,
                    backgroundColor: Colors.black,
                    placeholder: (_, __) => const Center(child: CircularProgressIndicator(color: Colors.white)),
                    errorWidget: (_, __, ___) => Center(
                      child: Icon(Icons.broken_image_outlined, color: Colors.white54, size: 64),
                    ),
                  );
                }
                
                return Container(
                  color: bgColor,
                  alignment: Alignment.center,
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    safeContent.isEmpty ? '—' : safeContent,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: _kFontSizeContent,
                      fontWeight: FontWeight.w700,
                      height: 1.3,
                    ),
                  ),
                );
              },
            ),

            // ── Top Bar (Progress + Info) ──
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
                                if (i < _index) value = 1;
                                if (i == _index) value = _progress.value;
                                return LinearProgressIndicator(
                                  value: value,
                                  minHeight: _kProgressHeight,
                                  backgroundColor: Colors.white30,
                                  valueColor: const AlwaysStoppedAnimation(Colors.white),
                                  borderRadius: BorderRadius.circular(2),
                                );
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
                                current.isMine ? l10n.t('status_my_status') : (safeName.isEmpty ? l10n.t('status_unknown_user') : safeName),
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: _kFontSizeName,
                                ),
                              ),
                              Text(
                                _formatTime(current.createdAt, l10n),
                                style: TextStyle(
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

            // ── Bottom Actions ──
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
                              l10n.t('status_views_count'),
                              style: TextStyle(
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
                              style: TextStyle(
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
