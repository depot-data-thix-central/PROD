// lib/presentation/home/widgets/home_headlines_carousel.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:html/parser.dart' as html_parser;

import 'package:thix_id/l10n/app_localizations.dart';
import 'package:thix_id/presentation/common/notifications_sheet.dart';
import 'package:thix_id/core/theme/thix_design_policy.dart';

// ============================================================================
// CONSTANTS
// ============================================================================
const Duration _kRequestTimeout = Duration(seconds: 15);
const Duration _kRetryDelay = Duration(milliseconds: 500);
const int _kMaxRetries = 2;
const double _kBannerHeight = 160.0;
const int _kAutoScrollInterval = 5; // secondes
const int _kMaxTitleLength = 100;
const int _kMaxTagLength = 30;

// ============================================================================
// VALIDATORS
// ============================================================================
class _CarouselValidators {
  _CarouselValidators._();

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

  static String friendlyError(dynamic e) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('timeout')) return 'Délai dépassé. Vérifiez votre connexion.';
    if (msg.contains('network') || msg.contains('socket')) return 'Erreur réseau. Réessayez.';
    if (msg.contains('permission') || msg.contains('policy')) return 'Accès non autorisé.';
    if (msg.contains('not found')) return 'Ressource introuvable.';
    return 'Une erreur est survenue. Réessayez.';
  }

  static String? extractStoragePath(String? imageUrl) {
    if (imageUrl == null || imageUrl.isEmpty) return null;
    try {
      final uri = Uri.parse(imageUrl);
      final segments = uri.pathSegments;
      final bucketIndex = segments.indexOf('banners');
      if (bucketIndex != -1 && bucketIndex < segments.length - 1) {
        return segments.sublist(bucketIndex + 1).join('/');
      }
    } catch (e) {
      debugPrint('[Carousel] ⚠️ Failed to parse image URL: $e');
    }
    return null;
  }
}

// ============================================================================
// HELPERS
// ============================================================================
Future<T> _carouselRetry<T>(
  Future<T> Function() fn, {
  required String label,
  int maxRetries = _kMaxRetries,
}) async {
  int attempt = 0;
  while (true) {
    try {
      return await fn().timeout(_kRequestTimeout);
    } on TimeoutException {
      attempt++;
      if (attempt > maxRetries) {
        debugPrint('[Carousel] ❌ $label: timeout after $attempt attempts');
        throw TimeoutException('$label: délai dépassé');
      }
      debugPrint('[Carousel] ⏱️ $label timeout — retry $attempt/$maxRetries');
      await Future.delayed(_kRetryDelay);
    } catch (e) {
      debugPrint('[Carousel] ❌ $label error: $e');
      rethrow;
    }
  }
}

// ============================================================================
// WIDGET PRINCIPAL
// ============================================================================
class HomeHeadlinesCarousel extends StatefulWidget {
  final PageController controller;
  final String? uid;
  final VoidCallback onThixInfoTap;
  final VoidCallback onOpportunityTap;

  const HomeHeadlinesCarousel({
    super.key,
    required this.controller,
    required this.uid,
    required this.onThixInfoTap,
    required this.onOpportunityTap,
  });

  @override
  State<HomeHeadlinesCarousel> createState() => _HomeHeadlinesCarouselState();
}

class _HomeHeadlinesCarouselState extends State<HomeHeadlinesCarousel>
    with WidgetsBindingObserver {
  late final Stream<List<Map<String, dynamic>>> _bannersStream;
  Stream<List<Map<String, dynamic>>>? _priorityNotifStream;

  Timer? _autoTimer;
  int _cardCount = 0;
  bool _isAdmin = false;
  bool _isAppVisible = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    debugPrint('[Carousel] 🎠 Initialized');

    _checkAdminRole();
    _initStreams();
    _startAutoScroll();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autoTimer?.cancel();
    debugPrint('[Carousel] 👋 Disposed');
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _isAppVisible = state == AppLifecycleState.resumed;
    if (_isAppVisible) {
      _startAutoScroll();
    } else {
      _autoTimer?.cancel();
      debugPrint('[Carousel] ⏸️ Auto-scroll paused (app background)');
    }
  }

  void _initStreams() {
    final client = Supabase.instance.client;

    // Bannières dynamiques
    _bannersStream = client
        .from('banners')
        .stream(primaryKey: ['id'])
        .eq('is_active', true)
        .order('created_at', ascending: false);

    // Notifications prioritaires
    final uid = widget.uid;
    if (uid != null && uid.trim().isNotEmpty) {
      try {
        _priorityNotifStream = client
            .from('notifications')
            .stream(primaryKey: ['id'])
            .eq('user_id', uid)
            .order('created_at', ascending: false)
            .limit(5);
      } catch (e) {
        debugPrint('[Carousel] ⚠️ Priority notif stream error: $e');
        _priorityNotifStream = null;
      }
    }
  }

  void _startAutoScroll() {
    _autoTimer?.cancel();
    _autoTimer = Timer.periodic(
      const Duration(seconds: _kAutoScrollInterval),
      (_) {
        if (!_isAppVisible) return;
        if (!widget.controller.hasClients || _cardCount <= 1) return;
        final current = widget.controller.page?.round() ?? 0;
        final next = (current + 1) % _cardCount;
        widget.controller.animateToPage(
          next,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOutCubic,
        );
      },
    );
  }

  Future<void> _checkAdminRole() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      final data = await _carouselRetry(
        () => Supabase.instance.client
            .from('profiles')
            .select('role, account_type')
            .eq('id', user.id)
            .maybeSingle(),
        label: 'checkAdminRole',
      );

      if (!mounted) return;

      if (data != null) {
        final role = (data['role'] ?? data['account_type'] ?? '')
            .toString()
            .toLowerCase();
        final isAdmin = role == 'admin' || role == 'entreprise' || role == 'support';
        setState(() => _isAdmin = isAdmin);
        debugPrint('[Carousel] ✓ Admin check: $isAdmin');
      }
    } catch (e) {
      debugPrint('[Carousel] ⚠️ Admin check failed (non-critical): $e');
    }
  }

  Future<void> _deleteBanner(String id, String? imageUrl) async {
    if (!mounted) return;

    HapticFeedback.mediumImpact();

    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          l10n.t('banner_delete_title'),
          style: const TextStyle(fontWeight: FontWeight.w800, color: ThixPolicy.textMain),
        ),
        content: Text(
          l10n.t('banner_delete_message'),
          style: const TextStyle(color: ThixPolicy.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.t('common_cancel'), style: const TextStyle(color: ThixPolicy.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: ThixPolicy.danger,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.t('banner_delete_confirm'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    debugPrint('[Carousel] 🗑️ Deleting banner $id');

    try {
      // Delete DB
      await _carouselRetry(
        () => Supabase.instance.client.from('banners').delete().eq('id', id),
        label: 'deleteBanner[$id]',
      );

      // Delete storage (si image existe)
      final storagePath = _CarouselValidators.extractStoragePath(imageUrl);
      if (storagePath != null) {
        try {
          await _carouselRetry(
            () => Supabase.instance.client.storage.from('banners').remove([storagePath]),
            label: 'deleteBannerStorage[$storagePath]',
          );
          debugPrint('[Carousel] ✓ Storage deleted: $storagePath');
        } catch (e) {
          debugPrint('[Carousel] ⚠️ Storage delete failed (non-critical): $e');
        }
      }

      if (mounted) {
        _showSuccess(l10n.t('banner_deleted'));
      }
      debugPrint('[Carousel] ✓ Banner deleted');
    } catch (e) {
      debugPrint('[Carousel] ❌ Delete banner error: $e');
      if (mounted) _showError(_CarouselValidators.friendlyError(e));
    }
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(message)),
        ]),
        backgroundColor: ThixPolicy.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
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

  Color _getAccentColor(String tag) {
    final t = tag.toLowerCase();
    if (t.contains('opportunit')) return ThixPolicy.domainOpportunity;
    if (t.contains('info')) return ThixPolicy.domainInfo;
    if (t.contains('urgent') || t.contains('sos')) return ThixPolicy.danger;
    return ThixPolicy.primaryDeep;
  }

  IconData _getIcon(String tag) {
    final t = tag.toLowerCase();
    if (t.contains('opportunit')) return Icons.lightbulb_rounded;
    if (t.contains('info')) return Icons.newspaper_rounded;
    if (t.contains('urgent') || t.contains('sos')) return Icons.priority_high_rounded;
    return Icons.campaign_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _priorityNotifStream,
      builder: (context, notifSnap) {
        final notifs = (notifSnap.data ?? const <Map<String, dynamic>>[])
            .where((n) => (n['priority'] == true) || (n['is_priority'] == true))
            .toList(growable: false);
        final priorityNotif = notifs.isEmpty ? null : notifs.first;

        return StreamBuilder<List<Map<String, dynamic>>>(
          stream: _bannersStream,
          builder: (context, bannerSnap) {
            final banners = bannerSnap.data ?? [];
            final cards = <Widget>[];

            // 1. Notification prioritaire
            if (priorityNotif != null) {
              cards.add(_HeadlineBanner(
                label: l10n.t('home_headline_notif_priority'),
                title: _CarouselValidators.sanitize(
                  (priorityNotif['title'] as String?) ??
                      (priorityNotif['message'] as String?) ??
                      l10n.t('home_headline_new_notif'),
                  maxLength: _kMaxTitleLength,
                ),
                imageUrl: _CarouselValidators.sanitizeUrl(priorityNotif['image_url'] as String?),
                icon: Icons.priority_high_rounded,
                accent: ThixPolicy.danger,
                height: _kBannerHeight,
                onTap: () {
                  HapticFeedback.selectionClick();
                  NotificationsSheet.show(context);
                },
              ));
            }

            // 2. Bannières administratives
            for (final b in banners) {
              final id = b['id'].toString();
              final title = _CarouselValidators.sanitize(
                b['title'] as String? ?? l10n.t('banner_default_title'),
                maxLength: _kMaxTitleLength,
              );
              final tag = _CarouselValidators.sanitize(
                b['tag'] as String? ?? l10n.t('banner_default_tag'),
                maxLength: _kMaxTagLength,
              );
              final imageUrl = _CarouselValidators.sanitizeUrl(b['image_url'] as String?);
              final accent = _getAccentColor(tag);

              cards.add(
                Stack(
                  children: [
                    _HeadlineBanner(
                      label: tag,
                      title: title,
                      imageUrl: imageUrl,
                      icon: _getIcon(tag),
                      accent: accent,
                      height: _kBannerHeight,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        if (tag.toLowerCase().contains('opportunit')) {
                          widget.onOpportunityTap();
                        } else {
                          widget.onThixInfoTap();
                        }
                      },
                    ),
                    if (_isAdmin)
                      Positioned(
                        top: 12,
                        left: 12,
                        child: _AdminDeleteButton(
                          onTap: () => _deleteBanner(id, imageUrl),
                        ),
                      ),
                  ],
                ),
              );
            }

            // 3. Fallback si aucune annonce
            if (cards.isEmpty) {
              return _EmptyBanner(message: l10n.t('banner_empty'));
            }

            _cardCount = cards.length;

            return RepaintBoundary(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: _kBannerHeight,
                    child: PageView(controller: widget.controller, children: cards),
                  ),
                  if (cards.length > 1) ...[
                    const SizedBox(height: 10),
                    _CarouselDots(controller: widget.controller, count: cards.length),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }
}

// ============================================================================
// COMPOSANTS
// ============================================================================

class _AdminDeleteButton extends StatelessWidget {
  final VoidCallback onTap;

  const _AdminDeleteButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Semantics(
      button: true,
      label: l10n.t('banner_delete_button'),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: ThixPolicy.danger.withOpacity(0.9),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withOpacity(0.5), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.white),
        ),
      ),
    );
  }
}

class _EmptyBanner extends StatelessWidget {
  final String message;

  const _EmptyBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: _kBannerHeight,
      width: double.infinity,
      decoration: BoxDecoration(
        color: ThixPolicy.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: ThixPolicy.border.withOpacity(0.6), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: Text(
          message,
          style: ThixPolicy.labelStyle.copyWith(
            color: ThixPolicy.textSecondary,
            fontWeight: ThixPolicy.semiBold,
          ),
        ),
      ),
    );
  }
}

class _CarouselDots extends StatefulWidget {
  final PageController controller;
  final int count;

  const _CarouselDots({required this.controller, required this.count});

  @override
  State<_CarouselDots> createState() => _CarouselDotsState();
}

class _CarouselDotsState extends State<_CarouselDots> {
  int _page = 0;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onScroll);
  }

  void _onScroll() {
    if (!widget.controller.hasClients) return;
    final p = widget.controller.page?.round() ?? 0;
    if (p != _page && mounted) {
      setState(() => _page = p);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onScroll);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activePage = widget.count == 0 ? 0 : _page.clamp(0, widget.count - 1);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(widget.count, (i) {
        final active = i == activePage;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: active ? 20 : 6,
          height: 6,
          decoration: BoxDecoration(
            color: active ? ThixPolicy.primaryDeep : ThixPolicy.border,
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}

class _HeadlineBanner extends StatelessWidget {
  final String label;
  final String title;
  final IconData icon;
  final Color accent;
  final String? imageUrl;
  final double height;
  final VoidCallback onTap;

  const _HeadlineBanner({
    required this.label,
    required this.title,
    required this.icon,
    required this.accent,
    required this.height,
    this.imageUrl,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasImage = imageUrl != null && imageUrl!.trim().isNotEmpty;
    final l10n = AppLocalizations.of(context);

    return Semantics(
      button: true,
      label: '$label. $title',
      child: GestureDetector(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Container(
              height: height,
              decoration: BoxDecoration(
                color: hasImage ? Colors.transparent : ThixPolicy.card,
                border: Border.all(color: ThixPolicy.border.withOpacity(0.6), width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (hasImage)
                    CachedNetworkImage(
                      imageUrl: imageUrl!.trim(),
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: accent.withOpacity(0.05),
                        child: Center(
                          child: SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.4, color: accent),
                          ),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: accent.withOpacity(0.1),
                        alignment: Alignment.center,
                        child: Icon(icon, color: accent.withOpacity(0.5), size: 40),
                      ),
                    )
                  else
                    Container(
                      color: accent.withOpacity(0.05),
                      alignment: Alignment.center,
                      child: Icon(icon, color: accent.withOpacity(0.4), size: 50),
                    ),

                  // Gradient pour lisibilité
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withOpacity(0.0),
                            Colors.black.withOpacity(hasImage ? 0.7 : 0.2),
                          ],
                          stops: const [0.3, 1.0],
                        ),
                      ),
                    ),
                  ),

                  // Textes
                  Positioned(
                    left: ThixPolicy.s16,
                    right: ThixPolicy.s16,
                    bottom: ThixPolicy.s16,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: accent.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            label,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          title,
                          style: TextStyle(
                            color: hasImage ? Colors.white : ThixPolicy.textMain,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            height: 1.2,
                            letterSpacing: -0.3,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),

                  // Flèche navigation
                  Positioned(
                    right: ThixPolicy.s12,
                    top: ThixPolicy.s12,
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.25),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withOpacity(0.5), width: 1.2),
                      ),
                      child: Icon(
                        Icons.arrow_forward_rounded,
                        size: 18,
                        color: hasImage ? Colors.white : ThixPolicy.textMain,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
