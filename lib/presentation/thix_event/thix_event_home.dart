// lib/presentation/thix_event/thix_event_home.dart
//
// ThixEventHome — DESIGN v2 (clair éditorial, hero banner géant permanent)
//
// • Hero plein écran (66 % de la hauteur), parallax, toujours affiché :
//   événements « featured » → sinon recommandés/à venir → sinon hero de marque
// • Barre du haut transparente sur le hero, qui devient claire au scroll
// • Chips catégories + segment de dates, carrousel de grandes cartes,
//   bannière VIP, liste de grandes cartes 16:11, navigation flottante
// • i18n AppLocalizations (mêmes clés), Semantics, throttling, logging
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../l10n/app_localizations.dart';
import '../../models/event_model.dart';
import '../../providers/event_provider.dart';

// ============================================================================
// PALETTE
// ============================================================================

class _C {
  static const bg = Color(0xFFF7F5F2);
  static const surface = Colors.white;
  static const ink = Color(0xFF0E0E16);
  static const inkSoft = Color(0xFF6B6B7B);
  static const line = Color(0xFFE8E4DD);
  static const accent = Color(0xFF5B3DF5);
  static const accentDeep = Color(0xFF3B22C9);
  static const amber = Color(0xFFFFB020);
  static const soldOut = Color(0xFFEF4444);
  static const lowStock = Color(0xFFF59E0B);
  static const imgBase = Color(0xFF1A1A26);
}

// ============================================================================
// CONSTANTS
// ============================================================================

const Duration _kActionThrottle = Duration(milliseconds: 500);

// ============================================================================
// LOGGING
// ============================================================================

class _EventLogger {
  static const _tag = 'ThixEventHome';
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
// PROVIDER ADMIN (sécurisé)
// ============================================================================

final isEventAdminProvider = FutureProvider.autoDispose<bool>((ref) async {
  final uid = Supabase.instance.client.auth.currentUser?.id;
  if (uid == null) {
    _EventLogger.warn('Admin check: no user');
    return false;
  }

  try {
    final res = await Supabase.instance.client
        .from('profiles')
        .select('role')
        .eq('id', uid)
        .maybeSingle()
        .timeout(const Duration(seconds: 10));

    final isAdmin =
        res != null && (res['role'] == 'admin' || res['role'] == 'superadmin');

    if (isAdmin) {
      _EventLogger.info('Admin access granted', {'userId': uid});
    }

    return isAdmin;
  } catch (e, stack) {
    _EventLogger.error('Admin check failed', {
      'error': '$e',
      'stack': stack.toString(),
    });
    return false;
  }
});

// ============================================================================
// PAGE PRINCIPALE
// ============================================================================

class ThixEventHome extends ConsumerStatefulWidget {
  const ThixEventHome({super.key});

  @override
  ConsumerState<ThixEventHome> createState() => _ThixEventHomeState();
}

class _ThixEventHomeState extends ConsumerState<ThixEventHome> {
  final ScrollController _scrollController = ScrollController();
  final PageController _heroController = PageController();
  final ScrollController _recScrollController = ScrollController();
  final ValueNotifier<double> _scrollY = ValueNotifier<double>(0);

  Timer? _heroTimer;
  Timer? _recTimer;
  int _heroPage = 0;
  int _heroCount = 0;
  bool _recForward = true;
  DateTime? _lastAction;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _startHero();
    _startRec();
    _EventLogger.info('ThixEventHome initialized');
  }

  void _onScroll() {
    final p = _scrollController.position;
    _scrollY.value = p.pixels;
    if (p.pixels > p.maxScrollExtent - 300) {
      ref.read(eventListProvider.notifier).loadMore();
    }
  }

  bool _throttle() {
    final now = DateTime.now();
    if (_lastAction != null && now.difference(_lastAction!) < _kActionThrottle) {
      return false;
    }
    _lastAction = now;
    return true;
  }

  double _pageValue() {
    if (_heroController.hasClients && _heroController.position.hasPixels) {
      return _heroController.page ?? _heroPage.toDouble();
    }
    return _heroPage.toDouble();
  }

  void _startHero() {
    _heroTimer?.cancel();
    _heroTimer = Timer.periodic(const Duration(seconds: 6), (_) {
      if (!mounted || !_heroController.hasClients || _heroCount <= 1) return;
      final next = (_pageValue().round() + 1) % _heroCount;
      _heroController.animateToPage(
        next,
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeOutCubic,
      );
    });
  }

  void _startRec() {
    _recTimer?.cancel();
    _recTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!_recScrollController.hasClients) return;
      final max = _recScrollController.position.maxScrollExtent;
      final cur = _recScrollController.position.pixels;

      if (_recForward) {
        if (cur >= max - 20) {
          _recForward = false;
        } else {
          _recScrollController.animateTo(
            cur + 236,
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOutCubic,
          );
        }
      } else {
        if (cur <= 20) {
          _recForward = true;
        } else {
          _recScrollController.animateTo(
            cur - 236,
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOutCubic,
          );
        }
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _heroController.dispose();
    _recScrollController.dispose();
    _scrollY.dispose();
    _heroTimer?.cancel();
    _recTimer?.cancel();
    _EventLogger.info('ThixEventHome disposed');
    super.dispose();
  }

  // ════════════════════════════════════════════════════════════
  // HELPERS
  // ════════════════════════════════════════════════════════════

  bool _isSoldOut(Event e) => (e.remainingTickets ?? 0) <= 0;

  bool _isLow(Event e) {
    final t = e.remainingTickets ?? 0;
    return t > 0 && t < 10;
  }

  void _openEvent(Event e, String logMsg) {
    if (!_throttle()) return;
    HapticFeedback.mediumImpact();
    _EventLogger.info(logMsg, {'eventId': e.id});
    context.push('/thix-event/event/${e.id}');
  }

  Widget _imgPlaceholder() => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_C.accentDeep, _C.accent],
          ),
        ),
        child: const Center(
          child: Icon(Icons.confirmation_num_rounded, color: Colors.white24, size: 48),
        ),
      );

  Widget _img(String? url, {int? cacheWidth}) {
    if (url == null || url.isEmpty) return _imgPlaceholder();
    return ColoredBox(
      color: _C.imgBase,
      child: Image.network(
        url,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        cacheWidth: cacheWidth,
        gaplessPlayback: true,
        frameBuilder: (ctx, child, frame, sync) => sync
            ? child
            : AnimatedOpacity(
                opacity: frame == null ? 0 : 1,
                duration: const Duration(milliseconds: 250),
                child: child,
              ),
        errorBuilder: (_, __, ___) => _imgPlaceholder(),
      ),
    );
  }

  Widget _pill(String text, Color bg, Color fg, {IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: fg),
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w900,
              color: fg,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _glassChip(IconData icon, String text) {
    return Container(
      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.62),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.16),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.24)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.white),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _metaRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 15, color: _C.accent),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _C.inkSoft,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _heroCurve() {
    return const Positioned(
      left: 0,
      right: 0,
      bottom: -1,
      height: 28,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: _C.bg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  // BUILD
  // ════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final size = MediaQuery.of(context).size;
    final topPad = MediaQuery.of(context).padding.top;
    final heroH = (size.height * 0.66).clamp(500.0, 680.0).toDouble();

    final featuredAsync = ref.watch(featuredEventsProvider);
    final eventsState = ref.watch(eventListProvider);
    final recommended = ref.watch(recommendedEventsProvider);
    final upcoming = ref.watch(upcomingEventsProvider);

    ref.listen<AsyncValue<List<Event>>>(featuredEventsProvider, (prev, next) {
      if (next.valueOrNull != null && next.valueOrNull!.length > 1) {
        _startHero();
      }
    });

    // Hero : featured → sinon recommandés + à venir → sinon placeholder de marque
    List<Event> heroList = featuredAsync.valueOrNull ?? <Event>[];
    if (heroList.isEmpty) {
      final seen = <String>{};
      heroList = [...recommended, ...upcoming]
          .where((e) => seen.add('${e.id}'))
          .take(5)
          .toList();
    }
    _heroCount = heroList.length;

    Widget heroSection;
    if (heroList.isNotEmpty) {
      heroSection = _hero(l10n, heroList, heroH);
    } else if (featuredAsync.hasError) {
      heroSection = _heroPlaceholder(l10n, heroH, error: true);
    } else if (featuredAsync.isLoading) {
      heroSection = _heroPlaceholder(l10n, heroH, loading: true);
    } else {
      heroSection = _heroPlaceholder(l10n, heroH);
    }

    final List<Event> items = upcoming.isNotEmpty
        ? upcoming
        : (eventsState.valueOrNull?.items ?? <Event>[]);

    return Scaffold(
      backgroundColor: _C.bg,
      body: Stack(
        children: [
          RefreshIndicator(
            backgroundColor: Colors.white,
            color: _C.accent,
            edgeOffset: topPad + 60,
            onRefresh: () async {
              if (!_throttle()) return;
              HapticFeedback.mediumImpact();
              _EventLogger.info('Refresh triggered');
              await Future.wait([
                ref.read(eventListProvider.notifier).refreshList(),
                ref.read(featuredEventsProvider.notifier).refresh(),
              ]);
            },
            child: CustomScrollView(
              controller: _scrollController,
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              slivers: [
                SliverToBoxAdapter(child: heroSection),
                SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 6),
                      _categoryChips(l10n),
                      const SizedBox(height: 14),
                      _dateSegment(l10n),
                      const SizedBox(height: 30),
                      _headerSection(
                        l10n,
                        l10n.t('event_most_anticipated'),
                        isPremium: true,
                      ),
                      const SizedBox(height: 16),
                      if (recommended.isNotEmpty)
                        SizedBox(
                          height: 310,
                          child: ListView.separated(
                            controller: _recScrollController,
                            scrollDirection: Axis.horizontal,
                            physics: const BouncingScrollPhysics(),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 4,
                            ),
                            itemCount: recommended.length,
                            separatorBuilder: (_, __) => const SizedBox(width: 16),
                            itemBuilder: (_, i) => _tallCard(l10n, recommended[i]),
                          ),
                        ),
                      const SizedBox(height: 30),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: _vipBanner(l10n),
                      ),
                      const SizedBox(height: 34),
                      _headerSection(l10n, l10n.t('event_featured')),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverList.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 20),
                    itemBuilder: (_, i) => _bigCard(l10n, items[i]),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 140)),
              ],
            ),
          ),
          _topBar(l10n, heroH),
          _bottomNav(l10n),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  // TOP BAR (transparente sur le hero → claire au scroll)
  // ════════════════════════════════════════════════════════════

  Widget _circleBtn({
    required IconData icon,
    required Color fg,
    required Color bg,
    required String label,
    required VoidCallback onTap,
    bool badge = false,
  }) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(icon, size: 20, color: fg),
              if (badge)
                Positioned(
                  top: 9,
                  right: 10,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _C.amber,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.2),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _topBar(AppLocalizations l10n, double heroH) {
    final isAdmin = ref.watch(isEventAdminProvider).valueOrNull ?? false;
    final topPad = MediaQuery.of(context).padding.top;

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: ValueListenableBuilder<double>(
        valueListenable: _scrollY,
        builder: (_, y, __) {
          final t = (y / (heroH - topPad - 70)).clamp(0.0, 1.0).toDouble();
          final fg = Color.lerp(Colors.white, _C.ink, t)!;
          final chip = Color.lerp(
            Colors.white.withOpacity(0.18),
            _C.ink.withOpacity(0.06),
            t,
          )!;

          return AnnotatedRegion<SystemUiOverlayStyle>(
            value: t < 0.5 ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
            child: Container(
              padding: EdgeInsets.fromLTRB(20, topPad + 8, 16, 8),
              decoration: BoxDecoration(
                color: _C.bg.withOpacity(0.95 * t),
                border: Border(
                  bottom: BorderSide(color: _C.line.withOpacity(t)),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: _C.amber,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.confirmation_num_rounded,
                      size: 16,
                      color: _C.ink,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: 'THIX',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: fg,
                              letterSpacing: -0.4,
                            ),
                          ),
                          TextSpan(
                            text: ' ${l10n.t('event_tickets')}',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w300,
                              color: fg.withOpacity(0.85),
                            ),
                          ),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Spacer(),
                  _circleBtn(
                    icon: Icons.search_rounded,
                    fg: fg,
                    bg: chip,
                    label: l10n.t('common_search'),
                    onTap: () {
                      if (!_throttle()) return;
                      HapticFeedback.selectionClick();
                      context.push('/thix-event/search');
                    },
                  ),
                  const SizedBox(width: 8),
                  _circleBtn(
                    icon: Icons.notifications_none_rounded,
                    fg: fg,
                    bg: chip,
                    label: l10n.t('common_notifications'),
                    badge: true,
                    onTap: () {
                      if (!_throttle()) return;
                      HapticFeedback.selectionClick();
                      _EventLogger.info('Notifications tapped');
                      // TODO: Ouvrir page notifications
                    },
                  ),
                  if (isAdmin) ...[
                    const SizedBox(width: 8),
                    Semantics(
                      button: true,
                      label: l10n.t('event_admin_panel'),
                      child: GestureDetector(
                        onTap: () {
                          if (!_throttle()) return;
                          HapticFeedback.mediumImpact();
                          _EventLogger.info('Admin panel opened');
                          context.push('/thix-event/admin');
                        },
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: const BoxDecoration(
                            color: _C.amber,
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: const Text(
                            'AN',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              color: _C.ink,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  // HERO GÉANT
  // ════════════════════════════════════════════════════════════

  Widget _hero(AppLocalizations l10n, List<Event> list, double h) {
    return SizedBox(
      height: h,
      child: Stack(
        children: [
          PageView.builder(
            controller: _heroController,
            itemCount: list.length,
            onPageChanged: (i) => setState(() => _heroPage = i),
            itemBuilder: (_, idx) => _heroSlide(l10n, list[idx], idx),
          ),
          _heroCurve(),
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: _heroDots(list.length),
          ),
        ],
      ),
    );
  }

  Widget _heroSlide(AppLocalizations l10n, Event e, int idx) {
    final soldOut = _isSoldOut(e);
    final low = _isLow(e);

    return GestureDetector(
      onTap: soldOut ? null : () => _openEvent(e, 'Hero tapped'),
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRect(
            child: AnimatedBuilder(
              animation: _heroController,
              child: _img(e.imageUrl, cacheWidth: 1200),
              builder: (_, child) {
                final delta = (_pageValue() - idx).clamp(-1.0, 1.0).toDouble();
                return Transform.translate(
                  offset: Offset(delta * 70, 0),
                  child: Transform.scale(scale: 1.22, child: child),
                );
              },
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.55),
                  Colors.transparent,
                  Colors.black.withOpacity(0.35),
                  Colors.black.withOpacity(0.92),
                ],
                stops: const [0.0, 0.28, 0.55, 1.0],
              ),
            ),
          ),
          Positioned(
            left: 20,
            right: 20,
            bottom: 78,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _pill(l10n.t('event_best_seller'), _C.amber, _C.ink,
                        icon: Icons.bolt_rounded),
                    if (soldOut)
                      _pill(l10n.t('event_sold_out'), _C.soldOut, Colors.white)
                    else if (low)
                      _pill(l10n.t('event_low_stock'), _C.lowStock, Colors.white)
                    else
                      _pill(
                        l10n.t('event_upcoming'),
                        Colors.white.withOpacity(0.18),
                        Colors.white,
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  e.title,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1.0,
                    height: 1.05,
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _glassChip(Icons.calendar_today_rounded, e.shortDate),
                    _glassChip(Icons.location_on_rounded, e.location),
                  ],
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        e.formattedPrice,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Semantics(
                      button: true,
                      label: l10n.t('event_book_now'),
                      enabled: !soldOut,
                      child: GestureDetector(
                        onTap: soldOut ? null : () => _openEvent(e, 'Hero book tapped'),
                        child: Container(
                          height: 54,
                          padding: const EdgeInsets.symmetric(horizontal: 26),
                          decoration: BoxDecoration(
                            color: soldOut ? Colors.grey.shade700 : _C.amber,
                            borderRadius: BorderRadius.circular(27),
                            boxShadow: soldOut
                                ? null
                                : [
                                    BoxShadow(
                                      color: _C.amber.withOpacity(0.4),
                                      blurRadius: 16,
                                      offset: const Offset(0, 6),
                                    ),
                                  ],
                          ),
                          alignment: Alignment.center,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                soldOut
                                    ? l10n.t('event_sold_out')
                                    : l10n.t('event_book_now'),
                                style: TextStyle(
                                  color: soldOut ? Colors.white70 : _C.ink,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 15,
                                ),
                              ),
                              if (!soldOut) ...[
                                const SizedBox(width: 8),
                                const Icon(
                                  Icons.arrow_forward_rounded,
                                  color: _C.ink,
                                  size: 19,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroDots(int count) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        count,
        (i) => AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          height: 6,
          width: _heroPage == i ? 24 : 6,
          decoration: BoxDecoration(
            color: _heroPage == i ? _C.amber : Colors.white.withOpacity(0.4),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
    );
  }

  /// Hero de marque : affiché pendant le chargement, en cas d'erreur
  /// ou quand aucun événement n'existe encore → le hero reste TOUJOURS géant.
  Widget _heroPlaceholder(
    AppLocalizations l10n,
    double h, {
    bool loading = false,
    bool error = false,
  }) {
    return SizedBox(
      height: h,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [_C.accentDeep, _C.accent, Color(0xFF8B5CF6)],
              ),
            ),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (loading)
                    const SizedBox(
                      width: 36,
                      height: 36,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 3,
                      ),
                    )
                  else
                    Icon(
                      error ? Icons.error_outline_rounded : Icons.confirmation_num_rounded,
                      size: 64,
                      color: Colors.white,
                    ),
                  const SizedBox(height: 18),
                  Text(
                    error ? l10n.t('error_generic') : 'THIX ${l10n.t('event_tickets')}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.8,
                    ),
                  ),
                  if (error) ...[
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        if (!_throttle()) return;
                        ref.read(featuredEventsProvider.notifier).refresh();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _C.amber,
                        foregroundColor: _C.ink,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                      child: Text(l10n.t('common_retry')),
                    ),
                  ],
                ],
              ),
            ),
          ),
          _heroCurve(),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  // FILTRES
  // ════════════════════════════════════════════════════════════

  Widget _categoryChips(AppLocalizations l10n) {
    final selected = ref.watch(eventCategoryProvider);
    final filters = [
      {'value': 'all', 'label': l10n.t('event_filter_all'), 'icon': Icons.auto_awesome_rounded},
      {'value': 'concert', 'label': l10n.t('event_filter_concerts'), 'icon': Icons.music_note_rounded},
      {'value': 'festival', 'label': l10n.t('event_filter_festivals'), 'icon': Icons.confirmation_num_rounded},
      {'value': 'business', 'label': l10n.t('event_filter_business'), 'icon': Icons.work_outline_rounded},
      {'value': 'sport', 'label': l10n.t('event_filter_sport'), 'icon': Icons.emoji_events_rounded},
      {'value': 'culture', 'label': l10n.t('event_filter_culture'), 'icon': Icons.palette_outlined},
    ];

    return SizedBox(
      height: 46,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final f = filters[i];
          final isSel = selected == f['value'];
          return Semantics(
            button: true,
            selected: isSel,
            label: f['label'] as String,
            child: GestureDetector(
              onTap: () {
                if (!_throttle()) return;
                HapticFeedback.lightImpact();
                ref.read(eventCategoryProvider.notifier).state = f['value'] as String;
                _EventLogger.info('Category filter changed', {'category': f['value']});
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: isSel ? _C.accent : _C.surface,
                  borderRadius: BorderRadius.circular(23),
                  border: Border.all(color: isSel ? _C.accent : _C.line),
                  boxShadow: isSel
                      ? [
                          BoxShadow(
                            color: _C.accent.withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : [],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      f['icon'] as IconData,
                      size: 17,
                      color: isSel ? Colors.white : _C.ink,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      f['label'] as String,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isSel ? FontWeight.w900 : FontWeight.w700,
                        color: isSel ? Colors.white : _C.ink,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _dateSegment(AppLocalizations l10n) {
    final selected = ref.watch(eventDateFilterProvider);
    final filters = [
      {'value': 'all', 'label': l10n.t('event_date_all')},
      {'value': 'today', 'label': l10n.t('event_date_today')},
      {'value': 'week', 'label': l10n.t('event_date_week')},
      {'value': 'month', 'label': l10n.t('event_date_month')},
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: const Color(0xFFECE8E1),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          children: filters.map((f) {
            final isSel = selected == f['value'];
            return Expanded(
              child: Semantics(
                button: true,
                selected: isSel,
                label: f['label'] as String,
                child: GestureDetector(
                  onTap: () {
                    if (!_throttle()) return;
                    HapticFeedback.lightImpact();
                    ref.read(eventDateFilterProvider.notifier).state = f['value'] as String;
                    _EventLogger.info('Date filter changed', {'filter': f['value']});
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: isSel ? _C.ink : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      f['label'] as String,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isSel ? FontWeight.w900 : FontWeight.w700,
                        color: isSel ? Colors.white : _C.inkSoft,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  // HEADER SECTION
  // ════════════════════════════════════════════════════════════

  Widget _headerSection(
    AppLocalizations l10n,
    String title, {
    bool isPremium = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                if (isPremium)
                  Container(
                    margin: const EdgeInsets.only(right: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: _C.amber,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      l10n.t('event_premium'),
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: _C.ink,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                Flexible(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: _C.ink,
                      letterSpacing: -0.6,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Semantics(
            button: true,
            label: l10n.t('event_view_all'),
            child: GestureDetector(
              onTap: () {
                if (!_throttle()) return;
                HapticFeedback.selectionClick();
                _EventLogger.info('View all tapped');
                context.push('/thix-event/recommended');
              },
              child: Row(
                children: [
                  Text(
                    l10n.t('event_view_all'),
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: _C.accent,
                    ),
                  ),
                  const SizedBox(width: 3),
                  const Icon(Icons.arrow_forward_rounded, size: 15, color: _C.accent),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  // CARTE HAUTE (carrousel « les plus attendus »)
  // ════════════════════════════════════════════════════════════

  Widget _tallCard(AppLocalizations l10n, Event e) {
    final soldOut = _isSoldOut(e);
    final low = _isLow(e);

    return Semantics(
      button: true,
      label: '${e.title}, ${e.formattedPrice}',
      enabled: !soldOut,
      child: GestureDetector(
        onTap: soldOut ? null : () => _openEvent(e, 'Recommended card tapped'),
        child: Container(
          width: 220,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.14),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              _img(e.imageUrl, cacheWidth: 700),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.15),
                      Colors.black.withOpacity(0.88),
                    ],
                    stops: const [0.35, 0.6, 1.0],
                  ),
                ),
              ),
              if (!soldOut)
                Positioned(
                  right: 12,
                  top: 12,
                  child: _pill(e.formattedPrice, Colors.white, _C.ink),
                ),
              if (low && !soldOut)
                Positioned(
                  left: 12,
                  top: 12,
                  child: _pill(l10n.t('event_low_stock'), _C.lowStock, Colors.white),
                ),
              Positioned(
                left: 14,
                right: 14,
                bottom: 14,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      e.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        height: 1.15,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.calendar_today_rounded,
                            size: 12, color: _C.amber),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            e.shortDate,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (soldOut)
                Positioned.fill(
                  child: Container(
                    color: Colors.black.withOpacity(0.62),
                    alignment: Alignment.center,
                    child: Text(
                      l10n.t('event_sold_out'),
                      style: const TextStyle(
                        color: _C.soldOut,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  // GRANDE CARTE (liste principale)
  // ════════════════════════════════════════════════════════════

  Widget _bigCard(AppLocalizations l10n, Event e) {
    final soldOut = _isSoldOut(e);
    final low = _isLow(e);

    return Semantics(
      button: true,
      label: '${e.title}, ${e.formattedPrice}',
      enabled: !soldOut,
      child: GestureDetector(
        onTap: soldOut ? null : () => _openEvent(e, 'Event card tapped'),
        child: Container(
          decoration: BoxDecoration(
            color: _C.surface,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(
              color: soldOut ? _C.soldOut.withOpacity(0.35) : _C.line,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
                child: AspectRatio(
                  aspectRatio: 16 / 11,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _img(e.imageUrl, cacheWidth: 900),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withOpacity(0.5),
                            ],
                            stops: const [0.55, 1.0],
                          ),
                        ),
                      ),
                      if (!soldOut && low)
                        Positioned(
                          left: 12,
                          top: 12,
                          child: _pill(l10n.t('event_low_stock'), _C.lowStock, Colors.white),
                        ),
                      if (!soldOut)
                        Positioned(
                          right: 12,
                          top: 12,
                          child: Semantics(
                            button: true,
                            label: l10n.t('event_add_favorites'),
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.favorite_border_rounded,
                                size: 18,
                                color: _C.ink,
                              ),
                            ),
                          ),
                        ),
                      if (!soldOut)
                        Positioned(
                          left: 14,
                          bottom: 14,
                          child: _pill(e.formattedPrice, Colors.white, _C.ink),
                        ),
                      if (soldOut)
                        Positioned.fill(
                          child: Container(
                            color: Colors.black.withOpacity(0.6),
                            alignment: Alignment.center,
                            child: Text(
                              l10n.t('event_sold_out'),
                              style: const TextStyle(
                                color: _C.soldOut,
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      e.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: soldOut ? _C.inkSoft : _C.ink,
                        height: 1.15,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _metaRow(Icons.calendar_today_rounded, e.shortDate),
                    const SizedBox(height: 7),
                    _metaRow(Icons.location_on_rounded, e.location),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  // VIP BANNER
  // ════════════════════════════════════════════════════════════

  Widget _vipBanner(AppLocalizations l10n) {
    return Semantics(
      button: true,
      label: l10n.t('event_vip_access'),
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_C.accent, _C.accentDeep],
          ),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: _C.accent.withOpacity(0.35),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              height: 52,
              width: 52,
              decoration: const BoxDecoration(
                color: _C.amber,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.verified_rounded, color: _C.ink, size: 26),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.t('event_vip_access'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    l10n.t('event_vip_description'),
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.88),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  // BOTTOM NAV (pilule flottante claire)
  // ════════════════════════════════════════════════════════════

  Widget _bottomNav(AppLocalizations l10n) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
          child: Container(
            height: 68,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            decoration: BoxDecoration(
              color: _C.surface,
              borderRadius: BorderRadius.circular(34),
              border: Border.all(color: _C.line),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.14),
                  blurRadius: 26,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _navItem(
                  icon: Icons.home_rounded,
                  label: l10n.t('common_home'),
                  selected: true,
                  onTap: () {},
                ),
                _navItem(
                  icon: Icons.explore_outlined,
                  label: l10n.t('event_explorer'),
                  onTap: () {
                    if (!_throttle()) return;
                    HapticFeedback.selectionClick();
                    context.push('/thix-event/search');
                  },
                ),
                _navItem(
                  icon: Icons.confirmation_num_outlined,
                  label: l10n.t('event_my_tickets'),
                  onTap: () {
                    if (!_throttle()) return;
                    HapticFeedback.selectionClick();
                    context.push('/thix-event/my-tickets');
                  },
                ),
                _navItem(
                  icon: Icons.favorite_border_rounded,
                  label: l10n.t('event_favorites'),
                  onTap: () {
                    if (!_throttle()) return;
                    HapticFeedback.selectionClick();
                    context.push('/thix-event/favorites');
                  },
                ),
                _navItem(
                  icon: Icons.person_outline_rounded,
                  label: l10n.t('common_profile'),
                  onTap: () {
                    if (!_throttle()) return;
                    HapticFeedback.selectionClick();
                    context.push('/profile');
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _navItem({
    required IconData icon,
    required String label,
    bool selected = false,
    VoidCallback? onTap,
  }) {
    final color = selected ? _C.accent : _C.inkSoft;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 62,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
                decoration: BoxDecoration(
                  color: selected ? _C.accent.withOpacity(0.12) : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, size: 22, color: color),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: selected ? FontWeight.w900 : FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
