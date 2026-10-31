// lib/presentation/thix_event/thix_event_home.dart
//
// ThixEventHome — Production Enterprise (Corrections UI)
//
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

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
// PALETTE PREMIUM DARK NEON
// ============================================================================
class _ThixColors {
  static const bg = Color(0xFF030305);
  static const surface = Color(0xFF0F0F13);
  static const surfaceGlass = Color(0x4D1A1A23);
  static const primary = Color(0xFFFF0A54);
  static const primaryGlow = Color(0x66FF0A54);
  static const accent = Color(0xFF7C3AED);
  static const accentGlow = Color(0x667C3AED);
  static const gold = Color(0xFFFFD700);
  static const textMain = Color(0xFFFFFFFF);
  static const textSecondary = Color(0xFF9CA3AF);
  static const soldOut = Color(0xFFEF4444);
  static const lowStock = Color(0xFFF59E0B);
}

// ============================================================================
// CONSTANTS & LOGGING
// ============================================================================
const Duration _kActionThrottle = Duration(milliseconds: 500);

class _EventLogger {
  static const _tag = 'ThixEventHome';
  static void info(String m, [Map<String, dynamic>? d]) => _log('INFO', m, d);
  static void warn(String m, [Map<String, dynamic>? d]) => _log('WARN', m, d);
  static void error(String m, [Map<String, dynamic>? d]) => _log('ERROR', m, d);
  
  static void _log(String l, String m, Map<String, dynamic>? d) {
    if (!kDebugMode && l == 'INFO') return;
    final data = d != null ? ' ${d.entries.map((e) => '${e.key}=${e.value}').join(', ')}' : '';
    debugPrint('[$_tag] [$l] $m$data');
  }
}

// ============================================================================
// PROVIDER ADMIN
// ============================================================================
final isEventAdminProvider = FutureProvider.autoDispose<bool>((ref) async {
  final uid = Supabase.instance.client.auth.currentUser?.id;
  if (uid == null) return false;
  try {
    final res = await Supabase.instance.client
        .from('profiles')
        .select('role')
        .eq('id', uid)
        .maybeSingle()
        .timeout(const Duration(seconds: 10));
    return res != null && (res['role'] == 'admin' || res['role'] == 'superadmin');
  } catch (e) {
    _EventLogger.error('Admin check failed', {'error': '$e'});
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
  final PageController _heroController = PageController(viewportFraction: 1.0);
  final ScrollController _recScrollController = ScrollController();
  
  Timer? _heroTimer;
  Timer? _recTimer;
  int _heroPage = 0;
  bool _recForward = true;
  DateTime? _lastAction;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _startHero();
    _startRec();
  }

  void _onScroll() {
    if (_scrollController.position.pixels > _scrollController.position.maxScrollExtent - 300) {
      ref.read(eventListProvider.notifier).loadMore();
    }
  }

  bool _throttle() {
    final now = DateTime.now();
    if (_lastAction != null && now.difference(_lastAction!) < _kActionThrottle) return false;
    _lastAction = now;
    return true;
  }

  void _startHero() {
    _heroTimer?.cancel();
    _heroTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!_heroController.hasClients) return;
      final count = ref.read(featuredEventsProvider).valueOrNull?.length ?? 0;
      if (count <= 1) return;
      _heroPage = (_heroPage + 1) % count;
      if (mounted) {
        setState(() {});
        _heroController.animateToPage(_heroPage, duration: const Duration(milliseconds: 800), curve: Curves.easeOutCubic);
      }
    });
  }

  void _startRec() {
    _recTimer?.cancel();
    _recTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!_recScrollController.hasClients) return;
      final max = _recScrollController.position.maxScrollExtent;
      final cur = _recScrollController.position.pixels;
      if (_recForward) {
        if (cur >= max - 20) { _recForward = false; } 
        else { _recScrollController.animateTo(cur + 240, duration: const Duration(milliseconds: 800), curve: Curves.easeOutCubic); }
      } else {
        if (cur <= 20) { _recForward = true; } 
        else { _recScrollController.animateTo(cur - 240, duration: const Duration(milliseconds: 800), curve: Curves.easeOutCubic); }
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _heroController.dispose();
    _recScrollController.dispose();
    _heroTimer?.cancel();
    _recTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final featuredAsync = ref.watch(featuredEventsProvider);
    final eventsState = ref.watch(eventListProvider);
    final recommended = ref.watch(recommendedEventsProvider);
    final upcoming = ref.watch(upcomingEventsProvider);

    return Scaffold(
      backgroundColor: _ThixColors.bg,
      extendBodyBehindAppBar: true,
      extendBody: true,
      appBar: _appBar(l10n),
      body: Stack(
        children: [
          const Positioned.fill(child: _EventAmbientBackground()),
          RefreshIndicator(
            backgroundColor: _ThixColors.surface,
            color: _ThixColors.primary,
            onRefresh: () async {
              if (!_throttle()) return;
              HapticFeedback.mediumImpact();
              await Future.wait([
                ref.read(eventListProvider.notifier).refreshList(),
                ref.read(featuredEventsProvider.notifier).refresh(),
              ]);
            },
            child: CustomScrollView(
              controller: _scrollController,
              physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
              slivers: [
                // 1. HERO GÉANT IMMERSIF (Hauteur augmentée)
                SliverToBoxAdapter(
                  child: featuredAsync.when(
                    loading: () => const SizedBox(height: 550, child: Center(child: CircularProgressIndicator(color: _ThixColors.primary))),
                    error: (e, _) => _ErrorWidget(message: l10n.t('error_generic'), onRetry: () => ref.read(featuredEventsProvider.notifier).refresh(), retryLabel: l10n.t('common_retry')),
                    data: (list) => _immersiveHero(l10n, list),
                  ),
                ),
                
                // 2. ESPACEMENT avant les filtres
                const SliverToBoxAdapter(child: SizedBox(height: 24)),
                
                // 3. FILTRES PREMIUM (Espacés du hero)
                SliverToBoxAdapter(child: _quickFilters(l10n)),
                SliverToBoxAdapter(child: SizedBox(height: 12)),
                SliverToBoxAdapter(child: _dateFilters(l10n)),
                
                const SliverToBoxAdapter(child: SizedBox(height: 24)),

                // 4. SECTION: MOST ANTICIPATED (Horizontal)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                    child: _headerSection(l10n, l10n.t('event_most_anticipated'), isPremium: true),
                  ),
                ),
                if (recommended.isNotEmpty)
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 280,
                      child: ListView.separated(
                        controller: _recScrollController,
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: recommended.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 16),
                        itemBuilder: (_, i) => SizedBox(width: 220, child: _card(l10n, recommended[i])),
                      ),
                    ),
                  ),
                
                const SliverToBoxAdapter(child: SizedBox(height: 32)),

                // 5. SECTION: FEATURED / UPCOMING (Grid)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                    child: _headerSection(l10n, l10n.t('event_featured')),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverGrid(
                    delegate: SliverChildBuilderDelegate(
                      (_, i) {
                        final ev = upcoming.isNotEmpty ? upcoming[i] : (eventsState.valueOrNull?.items[i]);
                        if (ev == null) return const SizedBox();
                        return _card(l10n, ev);
                      },
                      childCount: upcoming.isNotEmpty ? upcoming.length : (eventsState.valueOrNull?.items.length ?? 0).clamp(0, 6),
                    ),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 20,
                      crossAxisSpacing: 16,
                      childAspectRatio: 0.65,
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 100)), // Espace pour la bottom nav réduite
              ],
            ),
          ),
          _bottomNav(l10n),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  // APP BAR TRANSPARENT & GLASS
  // ═══════════════════════════════════════════════════════════
  PreferredSizeWidget _appBar(AppLocalizations l10n) {
    final isAdmin = ref.watch(isEventAdminProvider).valueOrNull ?? false;
    return PreferredSize(
      preferredSize: const Size.fromHeight(70),
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            color: _ThixColors.bg.withOpacity(0.4),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [_ThixColors.primary, _ThixColors.accent]),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [BoxShadow(color: _ThixColors.primaryGlow, blurRadius: 12, offset: const Offset(0, 4))],
                      ),
                      child: const Icon(Icons.confirmation_num_rounded, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('THIX', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.5)),
                        Text(l10n.t('event_tickets'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: _ThixColors.textSecondary, letterSpacing: 0.5)),
                      ],
                    ),
                    const Spacer(),
                    _glassIconButton(Icons.search_rounded, () {
                      if (!_throttle()) return;
                      context.push('/thix-event/search');
                    }),
                    const SizedBox(width: 12),
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        _glassIconButton(Icons.notifications_none_rounded, () {}),
                        Positioned(right: 4, top: 4, child: Container(width: 8, height: 8, decoration: const BoxDecoration(color: _ThixColors.primary, shape: BoxShape.circle),)),
                      ],
                    ),
                    if (isAdmin) ...[
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: () { if (!_throttle()) return; context.push('/thix-event/admin'); },
                        child: Container(
                          width: 36, height: 36,
                          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: _ThixColors.primary, width: 1.5)),
                          child: const Icon(Icons.admin_panel_settings_rounded, color: _ThixColors.primary, size: 20),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _glassIconButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          color: _ThixColors.surfaceGlass,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  // HERO IMMERSIF GÉANT (VISIBLE)
  // ════════════════════════════════════════════════════════════
  Widget _immersiveHero(AppLocalizations l10n, List<Event> list) {
    if (list.isEmpty) return const SizedBox(height: 500);
    
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.65, // ~65% de l'écran pour meilleure visibilité
      child: Stack(
        children: [
          PageView.builder(
            controller: _heroController,
            itemCount: list.length,
            onPageChanged: (i) => setState(() => _heroPage = i),
            itemBuilder: (_, idx) {
              final e = list[idx];
              final int tickets = e.remainingTickets ?? 0;
              final isSoldOut = tickets == 0;
              final isLowStock = !isSoldOut && tickets < 10;

              return Stack(
                fit: StackFit.expand,
                children: [
                  // Image plein écran avec meilleur fit
                  Image.network(
                    e.imageUrl ?? '', 
                    fit: BoxFit.cover, 
                    errorBuilder: (_, __, ___) => Container(color: _ThixColors.surface),
                  ),
                  
                  // Dégradé dramatique
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          _ThixColors.bg.withOpacity(0.3),
                          _ThixColors.bg.withOpacity(0.1),
                          _ThixColors.bg.withOpacity(0.8),
                          _ThixColors.bg,
                        ],
                        stops: const [0.0, 0.4, 0.8, 1.0],
                      ),
                    ),
                  ),
                  
                  // Contenu flottant en bas
                  Positioned(
                    bottom: 0, left: 0, right: 0,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Badges
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: _ThixColors.primary,
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [BoxShadow(color: _ThixColors.primaryGlow, blurRadius: 8)],
                                ),
                                child: Text(l10n.t('event_best_seller'), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 0.5)),
                              ),
                              const SizedBox(width: 8),
                              if (isSoldOut)
                                Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: _ThixColors.soldOut, borderRadius: BorderRadius.circular(20)), child: Text(l10n.t('event_sold_out'), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white)))
                              else if (isLowStock)
                                Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: _ThixColors.lowStock, borderRadius: BorderRadius.circular(20)), child: Text(l10n.t('event_low_stock'), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.black)))
                            ],
                          ),
                          const SizedBox(height: 16),
                          
                          // Titre massif
                          Text(e.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: -1, height: 1.1)),
                          const SizedBox(height: 24),
                          
                          // Action Row
                          Row(
                            children: [
                              // Prix Glass
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                                decoration: BoxDecoration(
                                  color: _ThixColors.surfaceGlass,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.white.withOpacity(0.15)),
                                ),
                                child: Text(e.formattedPrice, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
                              ),
                              const SizedBox(width: 16),
                              // Bouton Réserver
                              Expanded(
                                child: GestureDetector(
                                  onTap: isSoldOut ? null : () {
                                    if (!_throttle()) return;
                                    HapticFeedback.mediumImpact();
                                    context.push('/thix-event/event/${e.id}');
                                  },
                                  child: Container(
                                    height: 52,
                                    decoration: BoxDecoration(
                                      gradient: isSoldOut ? null : const LinearGradient(colors: [_ThixColors.primary, _ThixColors.accent]),
                                      color: isSoldOut ? Colors.grey.shade800 : null,
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: isSoldOut ? null : [BoxShadow(color: _ThixColors.primaryGlow, blurRadius: 16, offset: const Offset(0, 8))],
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(isSoldOut ? l10n.t('event_sold_out') : l10n.t('event_book_now'), style: TextStyle(color: isSoldOut ? Colors.white54 : Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
                                        if (!isSoldOut) ...[const SizedBox(width: 8), const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 20)],
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
                  ),
                ],
              );
            },
          ),
          // Indicateurs de page minimalistes
          Positioned(
            bottom: 16, left: 0, right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(list.length, (i) => AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                height: 4,
                width: _heroPage == i ? 24 : 4,
                decoration: BoxDecoration(
                  color: _heroPage == i ? _ThixColors.primary : Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: _heroPage == i ? [BoxShadow(color: _ThixColors.primaryGlow, blurRadius: 6)] : [],
                ),
              )),
            ),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  // FILTRES GLASSMORPHIQUES
  // ═══════════════════════════════════════════════════════════
  Widget _quickFilters(AppLocalizations l10n) {
    final selected = ref.watch(eventCategoryProvider);
    final filters = [
      {'value': 'all', 'label': l10n.t('event_filter_all'), 'icon': Icons.auto_awesome_rounded},
      {'value': 'concert', 'label': l10n.t('event_filter_concerts'), 'icon': Icons.music_note_rounded},
      {'value': 'festival', 'label': l10n.t('event_filter_festivals'), 'icon': Icons.confirmation_num_rounded},
      {'value': 'business', 'label': l10n.t('event_filter_business'), 'icon': Icons.work_outline_rounded},
      {'value': 'sport', 'label': l10n.t('event_filter_sport'), 'icon': Icons.emoji_events_rounded},
    ];
    
    return SizedBox(
      height: 84,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, i) {
          final f = filters[i];
          final isSel = selected == f['value'];
          return GestureDetector(
            onTap: () {
              if (!_throttle()) return;
              HapticFeedback.lightImpact();
              ref.read(eventCategoryProvider.notifier).state = f['value'] as String;
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 76,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              decoration: BoxDecoration(
                color: isSel ? _ThixColors.primary.withOpacity(0.15) : _ThixColors.surfaceGlass,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: isSel ? _ThixColors.primary : Colors.white.withOpacity(0.08), width: isSel ? 1.5 : 1),
                boxShadow: isSel ? [BoxShadow(color: _ThixColors.primaryGlow, blurRadius: 12, offset: const Offset(0, 4))] : [],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(f['icon'] as IconData, color: isSel ? _ThixColors.primary : _ThixColors.textSecondary, size: 24),
                  const SizedBox(height: 8),
                  Text(f['label'] as String, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10, fontWeight: isSel ? FontWeight.w900 : FontWeight.w600, color: isSel ? _ThixColors.primary : _ThixColors.textSecondary)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _dateFilters(AppLocalizations l10n) {
    final selected = ref.watch(eventDateFilterProvider);
    final filters = [
      {'value': 'all', 'label': l10n.t('event_date_all')},
      {'value': 'today', 'label': l10n.t('event_date_today')},
      {'value': 'week', 'label': l10n.t('event_date_week')},
      {'value': 'month', 'label': l10n.t('event_date_month')},
    ];
    
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final f = filters[i];
          final isSel = selected == f['value'];
          return GestureDetector(
            onTap: () {
              if (!_throttle()) return;
              ref.read(eventDateFilterProvider.notifier).state = f['value'] as String;
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isSel ? Colors.white : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: isSel ? Colors.white : Colors.white.withOpacity(0.15)),
              ),
              alignment: Alignment.center,
              child: Text(f['label'] as String, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: isSel ? Colors.black : _ThixColors.textSecondary)),
            ),
          );
        },
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  // HEADER SECTION AVEC ACCENT
  // ════════════════════════════════════════════════════════════
  Widget _headerSection(AppLocalizations l10n, String title, {bool isPremium = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            if (isPremium) Container(width: 4, height: 18, margin: const EdgeInsets.only(right: 10), decoration: BoxDecoration(gradient: const LinearGradient(colors: [_ThixColors.primary, _ThixColors.accent]), borderRadius: BorderRadius.circular(4))),
            Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.5)),
          ],
        ),
        GestureDetector(
          onTap: () { if (!_throttle()) return; context.push('/thix-event/recommended'); },
          child: Row(
            children: [
              Text(l10n.t('event_view_all'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _ThixColors.primary)),
              const SizedBox(width: 4),
              const Icon(Icons.arrow_forward_ios_rounded, size: 10, color: _ThixColors.primary),
            ],
          ),
        ),
      ],
    );
  }

  // ════════════════════════════════════════════════════════════
  // EVENT CARD
  // ════════════════════════════════════════════════════════════
  Widget _card(AppLocalizations l10n, Event event) {
    final int tickets = event.remainingTickets ?? 0;
    final isSoldOut = tickets == 0;
    final isLowStock = !isSoldOut && tickets < 10;

    return GestureDetector(
      onTap: isSoldOut ? null : () {
        if (!_throttle()) return;
        HapticFeedback.selectionClick();
        context.push('/thix-event/event/${event.id}');
      },
      child: Container(
        decoration: BoxDecoration(
          color: _ThixColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSoldOut ? _ThixColors.soldOut.withOpacity(0.3) : Colors.white.withOpacity(0.08)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 6))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                AspectRatio(
                  aspectRatio: 1.25,
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(19)),
                    child: Image.network(event.imageUrl ?? '', fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: _ThixColors.surface)),
                  ),
                ),
                if (isSoldOut)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(color: Colors.black.withOpacity(0.7), borderRadius: const BorderRadius.vertical(top: Radius.circular(19))),
                      child: const Center(child: Text('SOLD OUT', style: TextStyle(color: _ThixColors.soldOut, fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 1))),
                    ),
                  )
                else ...[
                  Positioned(
                    right: 10, top: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                      decoration: BoxDecoration(color: Colors.black.withOpacity(0.6), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.white.withOpacity(0.2))),
                      child: Text(event.formattedPrice, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900)),
                    ),
                  ),
                  if (isLowStock)
                    Positioned(
                      left: 10, top: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                        decoration: BoxDecoration(color: _ThixColors.lowStock, borderRadius: BorderRadius.circular(10)),
                        child: Text(l10n.t('event_low_stock'), style: const TextStyle(color: Colors.black, fontSize: 9, fontWeight: FontWeight.w900)),
                      ),
                    ),
                ],
              ],
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(event.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: isSoldOut ? Colors.white54 : Colors.white, height: 1.2, letterSpacing: -0.2)),
                    Column(
                      children: [
                        Row(
                          children: [
                            Icon(Icons.calendar_today_rounded, size: 12, color: isSoldOut ? Colors.white38 : _ThixColors.primary),
                            const SizedBox(width: 6),
                            Expanded(child: Text(event.shortDate, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: isSoldOut ? Colors.white38 : _ThixColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w600))),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(Icons.location_on_rounded, size: 12, color: isSoldOut ? Colors.white38 : _ThixColors.primary),
                            const SizedBox(width: 6),
                            Expanded(child: Text(event.location, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: isSoldOut ? Colors.white38 : _ThixColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w600))),
                          ],
                        ),
                      ],
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

  // ════════════════════════════════════════════════════════════
  // BOTTOM NAV FLOTTANTE GLASS (RÉDUITE)
  // ════════════════════════════════════════════════════════════
  Widget _bottomNav(AppLocalizations l10n) {
    return Positioned(
      left: 16, right: 16, bottom: 16, // Position ajustée
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28), // Rayon réduit
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            height: 60, // Hauteur réduite de 68 à 60
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: _ThixColors.surface.withOpacity(0.85),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: Colors.white.withOpacity(0.12), width: 1.2),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 30, offset: const Offset(0, 15))],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _navItem(Icons.home_rounded, l10n.t('common_home'), true, () {}),
                _navItem(Icons.explore_outlined, l10n.t('event_explorer'), false, () => context.push('/thix-event/search')),
                _navItem(Icons.confirmation_num_outlined, l10n.t('event_my_tickets'), false, () => context.push('/thix-event/my-tickets')),
                _navItem(Icons.favorite_border_rounded, l10n.t('event_favorites'), false, () => context.push('/thix-event/favorites')),
                _navItem(Icons.person_outline_rounded, l10n.t('common_profile'), false, () => context.push('/profile')),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _navItem(IconData icon, String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: () { if (!_throttle()) return; HapticFeedback.selectionClick(); onTap(); },
      child: Container(
        width: 52, // Largeur légèrement réduite
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 22, color: selected ? _ThixColors.primary : _ThixColors.textSecondary), // Icônes réduites
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 9, fontWeight: selected ? FontWeight.w900 : FontWeight.w600, color: selected ? _ThixColors.primary : _ThixColors.textSecondary, letterSpacing: 0.2)),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// ERROR WIDGET
// ============================================================================
class _ErrorWidget extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final String retryLabel;
  const _ErrorWidget({required this.message, required this.onRetry, required this.retryLabel});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 400,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: _ThixColors.soldOut.withOpacity(0.1), shape: BoxShape.circle), child: const Icon(Icons.error_outline, color: _ThixColors.soldOut, size: 40)),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(color: _ThixColors.textSecondary, fontSize: 16)),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: onRetry, style: ElevatedButton.styleFrom(backgroundColor: _ThixColors.primary, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: Text(retryLabel, style: const TextStyle(fontWeight: FontWeight.w800))),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// BACKGROUND ANIMÉ (OPTIMISÉ)
// ============================================================================
class _EventAmbientBackground extends StatefulWidget {
  const _EventAmbientBackground();
  @override
  State<_EventAmbientBackground> createState() => _EventAmbientBackgroundState();
}

class _EventAmbientBackgroundState extends State<_EventAmbientBackground> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 15))..repeat();
  }

  @override
  void dispose() { _controller.dispose(); super.dispose(); }

  Widget _buildPerformanceLight(double left, double top, double size, Color color) {
    return Positioned(
      left: left - (size / 2), top: top - (size / 2),
      child: Container(
        width: size, height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [color, color.withOpacity(0.0)], stops: const [0.0, 1.0])),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return IgnorePointer(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final t = _controller.value * 2 * math.pi;
            final p1X = size.width * 0.3 + math.cos(t) * 200.0;
            final p1Y = size.height * 0.2 + math.sin(t * 1.5) * 150.0;
            final p2X = size.width * 0.7 + math.sin(t * 1.2) * 180.0;
            final p2Y = size.height * 0.6 + math.cos(t * 0.8) * 200.0;

            return Stack(
              children: [
                Positioned.fill(child: Container(color: _ThixColors.bg)),
                _buildPerformanceLight(p1X, p1Y, 600, _ThixColors.primary.withOpacity(0.15)),
                _buildPerformanceLight(p2X, p2Y, 700, _ThixColors.accent.withOpacity(0.12)),
                Positioned.fill(child: CustomPaint(painter: _EventGridPainter())),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _EventGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final dotPaint = Paint()..color = Colors.white.withOpacity(0.03)..strokeWidth = 1.0..strokeCap = StrokeCap.round;
    final points = <Offset>[];
    const double spacing = 40.0;
    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        points.add(Offset(x, y));
      }
    }
    canvas.drawPoints(PointMode.points, points, dotPaint);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
