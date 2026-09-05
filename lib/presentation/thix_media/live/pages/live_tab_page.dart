// lib/presentation/thix_media/live/pages/live_tab_page.dart
//
// LiveTabPage — Découverte des lives + accès Go Live / Watch
// Production Enterprise (niveau TikTok Live Discovery)
//
// Features :
// - Découverte des lives actifs avec cover réelle + avatar host
// - Skeleton loader animé au chargement
// - Staggered animation d'entrée sur la grille
// - Badge LIVE pulsant + "Live depuis X min"
// - Formatage counts (K/M)
// - Long press → partage du live
// - Indicateur nombre de lives dans le header
// - Semantics complet + haptics + throttling
// - Logging structuré
import 'dart:async';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/l10n/app_localizations.dart';

import '../providers/go_live_provider.dart';
import '../services/live_service.dart';
import 'go_live_page.dart';
import 'live_viewer_page.dart';

// ============================================================================
// CONSTANTS
// ============================================================================

const Duration _kActionThrottle = Duration(milliseconds: 500);
const Duration _kCardStaggerDelay = Duration(milliseconds: 40);
const Duration _kPulseDuration = Duration(milliseconds: 1200);
const int _kMaxLivesLoaded = 50;

// ============================================================================
// LOGGING
// ============================================================================

class _LiveTabLogger {
  static const _tag = 'LiveTab';
  static void info(String m, [Map<String, dynamic>? d]) => _log('INFO', m, d);
  static void warn(String m, [Map<String, dynamic>? d]) => _log('WARN', m, d);
  static void error(String m, [Map<String, dynamic>? d]) => _log('ERROR', m, d);
  static void _log(String l, String m, Map<String, dynamic>? d) {
    if (!kDebugMode && l == 'INFO') return;
    final data = d != null
        ? ' ${d.entries.map((e) => '${e.key}=${e.value}').join(', ')}'
        : '';
    debugPrint('[$_tag] [$l] $m$data');
  }
}

// ============================================================================
// HELPERS
// ============================================================================

String _formatCount(int n) {
  if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
  if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
  return '$n';
}

String _formatDuration(DateTime since) {
  final diff = DateTime.now().difference(since);
  if (diff.inMinutes < 1) return '< 1 min';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min';
  final h = diff.inHours;
  final m = diff.inMinutes % 60;
  return m == 0 ? '${h}h' : '${h}h${m.toString().padLeft(2, '0')}';
}

// ============================================================================
// PROVIDER — liste des lives actifs
// ============================================================================

final activeLivesProvider =
    FutureProvider.autoDispose<List<LiveSession>>((ref) async {
  try {
    final lives = await ref.watch(liveServiceProvider).listActiveLives();
    // Tri décroissant par viewers (tendances en premier)
    lives.sort((a, b) => b.viewerCount.compareTo(a.viewerCount));
    _LiveTabLogger.info('Lives loaded', {'count': lives.length});
    return lives.take(_kMaxLivesLoaded).toList();
  } catch (e, stack) {
    _LiveTabLogger.error('Failed to load lives',
        {'error': '$e', 'stack': stack.toString()});
    rethrow;
  }
});

// ============================================================================
// PAGE
// ============================================================================

class LiveTabPage extends ConsumerStatefulWidget {
  const LiveTabPage({super.key});

  @override
  ConsumerState<LiveTabPage> createState() => _LiveTabPageState();
}

class _LiveTabPageState extends ConsumerState<LiveTabPage> {
  DateTime? _lastAction;

  bool _throttle() {
    final now = DateTime.now();
    if (_lastAction != null &&
        now.difference(_lastAction!) < _kActionThrottle) {
      return false;
    }
    _lastAction = now;
    return true;
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? ThixPolicy.danger : ThixPolicy.domainMedia,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 2),
    ));
  }

  Future<void> _refresh() async {
    if (!_throttle()) return;
    HapticFeedback.selectionClick();
    _LiveTabLogger.info('Refresh triggered');
    ref.invalidate(activeLivesProvider);
    try {
      await ref.read(activeLivesProvider.future);
    } catch (_) {}
  }

  Future<void> _openGoLive(AppLocalizations l10n) async {
    if (!_throttle()) return;
    HapticFeedback.mediumImpact();
    final currentUid = Supabase.instance.client.auth.currentUser?.id;
    if (currentUid == null) {
      _snack(l10n.t('live_login_required'), error: true);
      _LiveTabLogger.warn('Go Live blocked: not authenticated');
      return;
    }
    _LiveTabLogger.info('Go Live tapped');
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const GoLivePage()),
    );
  }

  void _openViewer(LiveSession live) {
    if (!_throttle()) return;
    HapticFeedback.selectionClick();
    _LiveTabLogger.info('Viewer opened',
        {'liveId': live.id, 'title': live.title});
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => LiveViewerPage(liveId: live.id)),
    );
  }

  void _shareLive(AppLocalizations l10n, LiveSession live) {
    if (!_throttle()) return;
    HapticFeedback.lightImpact();
    final link = 'https://thix.id/live/${live.id}';
    Clipboard.setData(ClipboardData(text: link));
    _snack(l10n.t('live_link_copied'));
    _LiveTabLogger.info('Live link copied', {'liveId': live.id});
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final livesAsync = ref.watch(activeLivesProvider);
    final currentUid = Supabase.instance.client.auth.currentUser?.id;

    return Scaffold(
      backgroundColor: Colors.black, // Ou Color(0xFF0B0B0F)
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Header ────────────────────────────────────────
            _Header(
              l10n: l10n,
              livesAsync: livesAsync,
              onRefresh: _refresh,
            ),

            // ── Bouton Go Live ────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Semantics(
                button: true,
                label: l10n.t('live_go_live_btn'),
                child: SizedBox(
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: () => _openGoLive(l10n),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE11D48),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: const Icon(Icons.podcasts_rounded, size: 22),
                    label: Text(
                      l10n.t('live_go_live_btn'),
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // ── Liste ─────────────────────────────────────────
            Expanded(
              child: livesAsync.when(
                loading: () => const _SkeletonLoader(),
                error: (e, _) {
                  _LiveTabLogger.error('Error state rendered',
                      {'error': '$e'});
                  return _ErrorState(
                    message: e.toString(),
                    onRetry: _refresh,
                    retryLabel: l10n.t('common_retry'),
                  );
                },
                data: (lives) {
                  if (lives.isEmpty) {
                    return _EmptyState(
                      title: l10n.t('live_empty_title'),
                      subtitle: l10n.t('live_empty_subtitle'),
                      cta: l10n.t('live_go_live_btn'),
                      onCta: currentUid == null
                          ? null
                          : () => _openGoLive(l10n),
                    );
                  }

                  return RefreshIndicator(
                    color: const Color(0xFFE11D48),
                    backgroundColor: const Color(0xFF1A1A1A),
                    onRefresh: _refresh,
                    child: GridView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                      physics: const BouncingScrollPhysics(
                        parent: AlwaysScrollableScrollPhysics(),
                      ),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 0.72,
                      ),
                      itemCount: lives.length,
                      itemBuilder: (context, index) {
                        final live = lives[index];
                        final isOwn = currentUid != null &&
                            live.hostId == currentUid;
                        return _LiveCard(
                          key: ValueKey('live_${live.id}'),
                          session: live,
                          isOwn: isOwn,
                          index: index,
                          onTap: () => _openViewer(live),
                          onLongPress: () => _shareLive(l10n, live),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// HEADER
// ============================================================================

class _Header extends StatelessWidget {
  final AppLocalizations l10n;
  final AsyncValue<List<LiveSession>> livesAsync;
  final VoidCallback onRefresh;

  const _Header({
    required this.l10n,
    required this.livesAsync,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final count = livesAsync.valueOrNull?.length ?? 0;
    final countLabel = count > 0
        ? ' · $count ${l10n.t('live_active_now')}'
        : '';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 8),
      child: Row(
        children: [
          const _LiveBadge(),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              l10n.t('live_tab_title') + countLabel,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Semantics(
            button: true,
            label: l10n.t('common_refresh'),
            child: IconButton(
              tooltip: l10n.t('common_refresh'),
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
            ),
          ),
        ],
      ),
    );
  }
}

class _LiveBadge extends StatefulWidget {
  const _LiveBadge();

  @override
  State<_LiveBadge> createState() => _LiveBadgeState();
}

class _LiveBadgeState extends State<_LiveBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: _kPulseDuration,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFFE11D48),
          borderRadius: BorderRadius.circular(6),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFE11D48).withValues(alpha: 0.4 * _ctrl.value),
              blurRadius: 8,
              spreadRadius: 1,
            ),
          ],
        ),
        child: const Text(
          'LIVE',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 12,
            letterSpacing: 0.6,
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// CARD
// ============================================================================

class _LiveCard extends StatefulWidget {
  final LiveSession session;
  final bool isOwn;
  final int index;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _LiveCard({
    super.key,
    required this.session,
    required this.onTap,
    required this.onLongPress,
    required this.index,
    this.isOwn = false,
  });

  @override
  State<_LiveCard> createState() => _LiveCardState();
}

class _LiveCardState extends State<_LiveCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _fadeAnim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    Future.delayed(_kCardStaggerDelay * widget.index, () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final s = widget.session;
    final hasCover =
        s.coverUrl != null && s.coverUrl!.isNotEmpty;
    final hasAvatar =
        s.hostAvatarUrl != null && s.hostAvatarUrl!.isNotEmpty;

    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position: _slideAnim,
        child: Semantics(
          button: true,
          label:
              '${s.title}, ${s.viewerCount} ${l10n.t('live_viewers')}, ${s.category}',
          onLongPressHint: l10n.t('live_share'),
          child: Material(
            color: ThixPolicy.surfaceSoft,
            borderRadius: BorderRadius.circular(14),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: widget.onTap,
              onLongPress: widget.onLongPress,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // ── Cover ──
                  if (hasCover)
                    CachedNetworkImage(
                      imageUrl: s.coverUrl!,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => const _CoverPlaceholder(),
                      errorWidget: (_, __, ___) => const _CoverPlaceholder(),
                    )
                  else
                    const _CoverPlaceholder(),

                  // ── Gradient bas ──
                  const Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: 90,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Colors.black87],
                        ),
                      ),
                    ),
                  ),

                  // ── Badge LIVE (pulsant) ──
                  Positioned(
                    top: 8,
                    left: 8,
                    child: _CardLiveBadge(),
                  ),

                  // ── Badge "Toi" ──
                  if (widget.isOwn)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          l10n.t('live_badge_self'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),

                  // ── Avatar host ──
                  if (hasAvatar)
                    Positioned(
                      left: 10,
                      bottom: 52,
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFFE11D48),
                            width: 2,
                          ),
                        ),
                        child: ClipOval(
                          child: CachedNetworkImage(
                            imageUrl: s.hostAvatarUrl!,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => Container(
                              color: ThixPolicy.surfaceSoft,
                              child: const Icon(Icons.person,
                                  color: Colors.white54, size: 16),
                            ),
                          ),
                        ),
                      ),
                    ),

                  // ── Infos ──
                  Positioned(
                    left: hasAvatar ? 46 : 10,
                    right: 10,
                    bottom: 10,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          s.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(
                              Icons.remove_red_eye_outlined,
                              size: 12,
                              color: Colors.white70,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _formatCount(s.viewerCount),
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                fontFeatures: [
                                  FontFeature.tabularFigures()
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.schedule_rounded,
                              size: 11,
                              color: Colors.white54,
                            ),
                            const SizedBox(width: 3),
                            Flexible(
                              child: Text(
                                _formatDuration(s.startedAt),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 10,
                                  fontFeatures: [
                                    FontFeature.tabularFigures()
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (s.category.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            s.category,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white38,
                              fontSize: 10,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ],
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

class _CardLiveBadge extends StatefulWidget {
  @override
  State<_CardLiveBadge> createState() => _CardLiveBadgeState();
}

class _CardLiveBadgeState extends State<_CardLiveBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: _kPulseDuration,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFFE11D48),
          borderRadius: BorderRadius.circular(5),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFE11D48).withValues(alpha: 0.5 * _ctrl.value),
              blurRadius: 6,
            ),
          ],
        ),
        child: const Text(
          'LIVE',
          style: TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.4,
          ),
        ),
      ),
    );
  }
}

class _CoverPlaceholder extends StatelessWidget {
  const _CoverPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2A1A22), Color(0xFF121218)],
        ),
      ),
      child: const Center(
        child: Icon(
          Icons.live_tv_rounded,
          size: 42,
          color: Colors.white24,
        ),
      ),
    );
  }
}

// ============================================================================
// SKELETON LOADER
// ============================================================================

class _SkeletonLoader extends StatelessWidget {
  const _SkeletonLoader();

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.72,
      ),
      itemCount: 6,
      itemBuilder: (_, __) => const _SkeletonCard(),
    );
  }
}

class _SkeletonCard extends StatefulWidget {
  const _SkeletonCard();

  @override
  State<_SkeletonCard> createState() => _SkeletonCardState();
}

class _SkeletonCardState extends State<_SkeletonCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        final t = _ctrl.value;
        final color = Color.lerp(
          const Color(0xFF1A1A1F),
          const Color(0xFF2A2A30),
          math.sin(t * math.pi * 2) * 0.5 + 0.5,
        )!;
        return Container(
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(
                  height: 10,
                  width: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  height: 8,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  height: 8,
                  width: 80,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ============================================================================
// EMPTY / ERROR
// ============================================================================

class _EmptyState extends StatelessWidget {
  final String title;
  final String subtitle;
  final String cta;
  final VoidCallback? onCta;

  const _EmptyState({
    required this.title,
    required this.subtitle,
    required this.cta,
    this.onCta,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.sensors_off_rounded,
              size: 56,
              color: Colors.white.withValues(alpha: 0.25),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.45),
                fontSize: 13,
              ),
            ),
            if (onCta != null) ...[
              const SizedBox(height: 20),
              Semantics(
                button: true,
                label: cta,
                child: TextButton(
                  onPressed: onCta,
                  child: Text(
                    cta,
                    style: const TextStyle(
                      color: Color(0xFFE11D48),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final String retryLabel;

  const _ErrorState({
    required this.message,
    required this.onRetry,
    required this.retryLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.white38, size: 40),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white54, fontSize: 13),
            ),
            const SizedBox(height: 16),
            Semantics(
              button: true,
              label: retryLabel,
              child: TextButton(
                onPressed: onRetry,
                child: Text(retryLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
