// lib/presentation/thix_event/thix_event_home.dart
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../providers/event_provider.dart';
import '../../models/event_model.dart';

// ================= COULEURS SPÉCIFIQUES EVENT (DARK & NEON) =================
class _ThixColors {
  static const bg = Color(0xFF050508); // Noir très profond
  static const surface = Color(0xFF111118);
  static const primary = Color(0xFFFF0A54); // Rose Néon
  static const primaryLight = Color(0xFFFF8FB0);
  static const gradientEnd = Color(0xFFFF8A00); // Orange Néon
  static const accentPurple = Color(0xFF7C3AED); // Violet Néon
  static const textSecondary = Color(0x99FFFFFF);
}

// PROVIDER POUR VÉRIFIER LE RÔLE ADMIN
final isEventAdminProvider = FutureProvider.autoDispose<bool>((ref) async {
  final uid = Supabase.instance.client.auth.currentUser?.id;
  if (uid == null) return false;
  try {
    final res = await Supabase.instance.client
        .from('profiles')
        .select('role')
        .eq('id', uid)
        .maybeSingle();
    return res != null && (res['role'] == 'admin' || res['role'] == 'superadmin');
  } catch (_) {
    return false;
  }
});

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

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels > _scrollController.position.maxScrollExtent - 300) {
        ref.read(eventListProvider.notifier).loadMore();
      }
    });
    _startHero();
    _startRec();
  }

  void _startHero() {
    _heroTimer?.cancel();
    _heroTimer = Timer.periodic(const Duration(seconds: 6), (_) {
      if (!_heroController.hasClients) return;
      final count = ref.read(featuredEventsProvider).valueOrNull?.length ?? 0;
      if (count <= 1) return;
      _heroPage = (_heroPage + 1) % count;
      if (mounted) {
        setState(() {});
        _heroController.animateToPage(_heroPage, duration: const Duration(milliseconds: 700), curve: Curves.easeOutCubic);
      }
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
          _recScrollController.animateTo(cur + 268, duration: const Duration(milliseconds: 800), curve: Curves.easeOutCubic);
        }
      } else {
        if (cur <= 20) {
          _recForward = true;
        } else {
          _recScrollController.animateTo(cur - 268, duration: const Duration(milliseconds: 800), curve: Curves.easeOutCubic);
        }
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
    final featuredAsync = ref.watch(featuredEventsProvider);
    final eventsState = ref.watch(eventListProvider);
    final recommended = ref.watch(recommendedEventsProvider);
    final upcoming = ref.watch(upcomingEventsProvider);

    ref.listen<AsyncValue<List<Event>>>(featuredEventsProvider, (prev, next) {
      if (next.valueOrNull != null && next.valueOrNull!.length > 1) {
        _startHero();
      }
    });

    return Scaffold(
      backgroundColor: _ThixColors.bg,
      extendBodyBehindAppBar: true,
      extendBody: true,
      appBar: _appBar(),
      body: Stack(
        children: [
          // 🌟 FOND PROpre (Zéro voile blanc)
          const Positioned.fill(child: _EventAmbientBackground()),

          RefreshIndicator(
            backgroundColor: _ThixColors.surface,
            color: _ThixColors.primary,
            onRefresh: () async {
              await Future.wait([
                ref.read(eventListProvider.notifier).refreshList(),
                ref.read(featuredEventsProvider.notifier).refresh(),
              ]);
            },
            child: CustomScrollView(
              controller: _scrollController,
              physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
              slivers: [
                SliverToBoxAdapter(
                  child: SizedBox(height: MediaQuery.of(context).padding.top + 56),
                ),
                SliverToBoxAdapter(
                  child: featuredAsync.when(
                    loading: () => const SizedBox(height: 460, child: Center(child: CircularProgressIndicator(color: _ThixColors.primary))),
                    error: (e, _) => SizedBox(height: 460, child: Center(child: Text('Erreur: $e', style: const TextStyle(color: Colors.white70)))),
                    data: (list) => _hero(list),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const SizedBox(height: 24),
                    _quickFilters(),
                    const SizedBox(height: 16),
                    _dateFilters(),
                    const SizedBox(height: 32),
                    _headerSection('Les Plus Attendus', isPremium: true),
                    const SizedBox(height: 16),
                    if (recommended.isNotEmpty)
                      SizedBox(
                        height: 270,
                        child: ListView.separated(
                          controller: _recScrollController,
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          itemCount: recommended.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 16),
                          itemBuilder: (_, i) => SizedBox(width: 210, child: _card(recommended[i])),
                        ),
                      ),
                    const SizedBox(height: 32),
                    Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: _vipBanner()),
                    const SizedBox(height: 36),
                    _headerSection("À l'affiche"),
                    const SizedBox(height: 16),
                  ]),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverGrid(
                    delegate: SliverChildBuilderDelegate(
                      (_, i) {
                        final ev = upcoming.isNotEmpty ? upcoming[i] : (eventsState.valueOrNull?.items[i]);
                        if (ev == null) return const SizedBox();
                        return _card(ev);
                      },
                      childCount: upcoming.isNotEmpty ? upcoming.length : (eventsState.valueOrNull?.items.length ?? 0).clamp(0, 6),
                    ),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      childAspectRatio: 0.68,
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 140)),
              ],
            ),
          ),
          
          // 🌟 NAVBAR FLOTTANTE NETTE
          _bottomNav(),
        ],
      ),
    );
  }

  PreferredSizeWidget _appBar() {
    final isAdmin = ref.watch(isEventAdminProvider).valueOrNull ?? false;

    return PreferredSize(
      preferredSize: const Size.fromHeight(60),
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            color: _ThixColors.bg.withOpacity(0.8),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.1), width: 1))),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    Container(
                      height: 32,
                      width: 32,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [_ThixColors.primary, _ThixColors.gradientEnd]), 
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [BoxShadow(color: _ThixColors.primary.withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 2))],
                      ),
                      child: const Icon(Icons.confirmation_num_rounded, color: Colors.white, size: 16),
                    ),
                    const SizedBox(width: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: const [
                        Text('THIX', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.5)),
                        SizedBox(width: 3),
                        Text('TICKETS', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w300, color: _ThixColors.textSecondary)),
                      ],
                    ),
                    const Spacer(),
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: const Icon(Icons.search_rounded, color: Colors.white, size: 22),
                      onPressed: () => context.push('/thix-event/search'),
                    ),
                    const SizedBox(width: 16),
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: const Icon(Icons.notifications_none_rounded, color: Colors.white, size: 22),
                          onPressed: () {},
                        ),
                        Positioned(
                          right: 2,
                          top: 2,
                          child: Container(
                            height: 8,
                            width: 8,
                            decoration: const BoxDecoration(color: _ThixColors.primary, shape: BoxShape.circle),
                          ),
                        ),
                      ],
                    ),
                    if (isAdmin) ...[
                      const SizedBox(width: 12),
                      InkWell(
                        onTap: () => context.push('/thix-event/admin'),
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          height: 32,
                          width: 32,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [_ThixColors.primary, _ThixColors.gradientEnd]),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white.withOpacity(0.2)),
                          ),
                          alignment: Alignment.center,
                          child: const Text('AN', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.white)),
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

  Widget _hero(List<Event> list) {
    if (list.isEmpty) return const SizedBox(height: 320);
    return SizedBox(
      height: 480,
      child: Stack(
        children: [
          PageView.builder(
            controller: _heroController,
            itemCount: list.length,
            onPageChanged: (i) {
              setState(() => _heroPage = i);
            },
            itemBuilder: (_, idx) {
              final e = list[idx];
              return Container(
                margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: Colors.white.withOpacity(0.15)),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.6), blurRadius: 20, offset: const Offset(0, 10))],
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.network(e.imageUrl ?? '', fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: _ThixColors.surface)),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.black.withOpacity(0.4), Colors.transparent, Colors.black.withOpacity(0.95)],
                          stops: const [0.0, 0.4, 1.0],
                        ),
                      ),
                    ),
                    Positioned(
                      left: 16,
                      top: 16,
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(color: _ThixColors.primary, borderRadius: BorderRadius.circular(20)),
                            child: const Text('BEST-SELLER', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 0.5)),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.4),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.white.withOpacity(0.2)),
                            ),
                            child: const Text('À VENIR', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white)),
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      bottom: 24,
                      left: 20,
                      right: 20,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            e.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: -0.5, height: 1.1),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.15),
                                    border: Border.all(color: Colors.white.withOpacity(0.25)),
                                    borderRadius: BorderRadius.circular(24),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(e.formattedPrice, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900)),
                                ),
                              ),
                              const SizedBox(width: 12),
                              GestureDetector(
                                onTap: () { HapticFeedback.mediumImpact(); context.push('/thix-event/event/${e.id}'); },
                                child: Container(
                                  height: 48,
                                  padding: const EdgeInsets.symmetric(horizontal: 24),
                                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Colors.white.withOpacity(0.2), blurRadius: 10)]),
                                  alignment: Alignment.center,
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text('Réserver', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 15)),
                                      SizedBox(width: 6),
                                      Icon(Icons.arrow_forward_rounded, color: Colors.black, size: 18),
                                    ],
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
            },
          ),
          Positioned(
            bottom: 12,
            left: 0,
            right: 0,
            child: _heroDots(list.length),
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
          width: _heroPage == i ? 20 : 6,
          decoration: BoxDecoration(
            color: _heroPage == i ? _ThixColors.primary : Colors.white.withOpacity(0.3),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
    );
  }

  Widget _quickFilters() {
    final selected = ref.watch(eventCategoryProvider);
    final filters = const [
      {'value': 'all', 'label': 'Tous', 'icon': Icons.auto_awesome_rounded},
      {'value': 'concert', 'label': 'Concerts', 'icon': Icons.music_note_rounded},
      {'value': 'festival', 'label': 'Festivals', 'icon': Icons.confirmation_num_rounded},
      {'value': 'business', 'label': 'Business', 'icon': Icons.work_outline_rounded},
      {'value': 'sport', 'label': 'Sport', 'icon': Icons.emoji_events_rounded},
      {'value': 'culture', 'label': 'Culture', 'icon': Icons.palette_outlined},
    ];
    return SizedBox(
      height: 90,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, i) {
          final f = filters[i];
          final isSel = selected == f['value'];
          return InkWell(
            onTap: () { HapticFeedback.lightImpact(); ref.read(eventCategoryProvider.notifier).state = f['value'] as String; },
            borderRadius: BorderRadius.circular(20),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: isSel ? _ThixColors.primary : _ThixColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: isSel ? _ThixColors.primaryLight : Colors.white.withOpacity(0.1)),
                boxShadow: isSel ? [BoxShadow(color: _ThixColors.primary.withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 4))] : [],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(f['icon'] as IconData, color: isSel ? Colors.white : Colors.white70, size: 24),
                  const SizedBox(height: 8),
                  Text(
                    f['label'] as String,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: isSel ? FontWeight.w900 : FontWeight.w600,
                      color: isSel ? Colors.white : Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _dateFilters() {
    final selected = ref.watch(eventDateFilterProvider);
    final filters = const [
      {'value': 'all', 'label': 'Toutes dates'},
      {'value': 'today', 'label': "Aujourd'hui"},
      {'value': 'week', 'label': 'Cette semaine'},
      {'value': 'month', 'label': 'Ce mois-ci'},
    ];
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final f = filters[i];
          final isSel = selected == f['value'];
          return InkWell(
            onTap: () { HapticFeedback.lightImpact(); ref.read(eventDateFilterProvider.notifier).state = f['value']!; },
            borderRadius: BorderRadius.circular(20),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              decoration: BoxDecoration(
                color: isSel ? Colors.white : _ThixColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: isSel ? Colors.white : Colors.white.withOpacity(0.15)),
                boxShadow: isSel ? [BoxShadow(color: Colors.white.withOpacity(0.2), blurRadius: 8)] : [],
              ),
              alignment: Alignment.center,
              child: Text(
                f['label']!,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSel ? FontWeight.w900 : FontWeight.w700,
                  color: isSel ? Colors.black : Colors.white70,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _headerSection(String t, {bool isPremium = false}) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                if (isPremium)
                  Container(
                    margin: const EdgeInsets.only(right: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [_ThixColors.primary, _ThixColors.gradientEnd]),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('PREMIUM', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 0.5)),
                  ),
                Text(t, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.5)),
              ],
            ),
            GestureDetector(
              onTap: () => context.push('/thix-event/recommended'),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                child: const Row(
                  children: [
                    Text('Tout voir', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white)),
                    SizedBox(width: 4),
                    Icon(Icons.arrow_forward_ios_rounded, size: 12, color: Colors.white),
                  ],
                ),
              ),
            ),
          ],
        ),
      );

  Widget _card(Event event) => GestureDetector(
        onTap: () { HapticFeedback.selectionClick(); context.push('/thix-event/event/${event.id}'); },
        child: Container(
          decoration: BoxDecoration(
            color: _ThixColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))],
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
                  Positioned(
                    right: 10,
                    top: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                      decoration: BoxDecoration(color: Colors.black.withOpacity(0.6), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withOpacity(0.2))),
                      child: Text(event.formattedPrice, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900)),
                    ),
                  ),
                  Positioned(
                    right: 10,
                    bottom: 10,
                    child: Container(
                      height: 32,
                      width: 32,
                      decoration: BoxDecoration(color: Colors.black.withOpacity(0.6), shape: BoxShape.circle, border: Border.all(color: Colors.white.withOpacity(0.2))),
                      child: const Icon(Icons.favorite_border_rounded, color: Colors.white, size: 16),
                    ),
                  ),
                ],
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        event.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Colors.white, height: 1.2, letterSpacing: -0.2),
                      ),
                      Column(
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.calendar_today_rounded, size: 12, color: _ThixColors.primaryLight),
                              const SizedBox(width: 6),
                              Expanded(child: Text(event.shortDate, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700))),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(Icons.location_on_rounded, size: 12, color: _ThixColors.primaryLight),
                              const SizedBox(width: 6),
                              Expanded(child: Text(event.location, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700))),
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

  Widget _vipBanner() => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [_ThixColors.primary.withOpacity(0.85), _ThixColors.gradientEnd.withOpacity(0.85)]),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withOpacity(0.3)),
          boxShadow: [BoxShadow(color: _ThixColors.primary.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 5))],
        ),
        child: Row(
          children: [
            Container(
              height: 46,
              width: 46,
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white.withOpacity(0.5))),
              child: const Icon(Icons.verified_rounded, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('THIX VIP ACCESS', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                  SizedBox(height: 2),
                  Text('Billets infalsifiables, QR dynamique et coupe-file garanti.', style: TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w600, height: 1.3)),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _bottomNav() => Positioned(
    left: 0, right: 0, bottom: 0,
    child: Container(
      color: Colors.transparent,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Container(
            height: 64,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: _ThixColors.surface,
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: Colors.white.withOpacity(0.15), width: 1.2),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 30, offset: const Offset(0, 10))],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _navItem(icon: Icons.home_rounded, label: 'Accueil', selected: true, onTap: () {}),
                _navItem(icon: Icons.explore_outlined, label: 'Explorer', onTap: () { HapticFeedback.selectionClick(); context.push('/thix-event/search'); }),
                _navItem(icon: Icons.confirmation_num_outlined, label: 'Billets', onTap: () { HapticFeedback.selectionClick(); context.push('/thix-event/my-tickets'); }),
                _navItem(icon: Icons.favorite_border_rounded, label: 'Favoris', onTap: () { HapticFeedback.selectionClick(); context.push('/thix-event/favorites'); }),
                _navItem(icon: Icons.person_outline_rounded, label: 'Profil', onTap: () { HapticFeedback.selectionClick(); context.push('/profile'); }),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  Widget _navItem({required IconData icon, required String label, bool selected = false, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 60,
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 24, color: selected ? _ThixColors.primaryLight : Colors.white.withOpacity(0.5)),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(fontSize: 10, fontWeight: selected ? FontWeight.w900 : FontWeight.w600, color: selected ? _ThixColors.primaryLight : Colors.white.withOpacity(0.5)),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// WIDGET : BACKGROUND CONCERT ANIMÉ (OPTIMISÉ HAUTE PERFORMANCE)
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
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 12))..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _buildPerformanceLight(double left, double top, double size, Color color) {
    return Positioned(
      left: left - (size / 2),
      top: top - (size / 2),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color, 
              color.withOpacity(0.0) 
            ],
            stops: const [0.0, 1.0], 
          ),
        ),
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
            final p2Y = size.height * 0.5 + math.cos(t * 0.8) * 200.0;

            final p3X = size.width * 0.5 + math.cos(t * 0.7) * 250.0;
            final p3Y = size.height * 0.8 + math.sin(t * 1.1) * 100.0;

            return Stack(
              children: [
                Positioned.fill(child: Container(color: _ThixColors.bg)),
                
                _buildPerformanceLight(p1X, p1Y, 700, _ThixColors.primary.withOpacity(0.22)),
                _buildPerformanceLight(p2X, p2Y, 800, _ThixColors.gradientEnd.withOpacity(0.16)),
                _buildPerformanceLight(p3X, p3Y, 900, _ThixColors.accentPurple.withOpacity(0.18)),

                Positioned.fill(
                  child: CustomPaint(painter: _EventGridPainter()),
                )
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
    final dotPaint = Paint()
      ..color = Colors.white.withOpacity(0.04)
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.round;

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
