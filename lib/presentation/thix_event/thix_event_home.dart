// lib/presentation/thix_event/thix_event_home.dart
import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../providers/event_provider.dart';
import '../../models/event_model.dart';

class _ThixColors {
  static const bg = Color(0xFF050508);
  static const surface = Color(0xFF0C0C12);
  static const surfaceAlt = Color(0xFF111118);
  static const cardBorder = Color(0x14FFFFFF);
  static const cardBorderStrong = Color(0x26FFFFFF);
  static const primary = Color(0xFFFF0A54);
  static const primaryLight = Color(0xFFFF8FB0);
  static const gradientEnd = Color(0xFFFF8A00);
  static const textSecondary = Color(0x99FFFFFF);
  static const textMuted = Color(0x66FFFFFF);
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
      body: RefreshIndicator(
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
              child: SizedBox(height: MediaQuery.of(context).padding.top + 52),
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
                const SizedBox(height: 14),
                _dateFilters(),
                const SizedBox(height: 26),
                _headerSection('Les Plus Attendus', isPremium: true),
                const SizedBox(height: 14),
                if (recommended.isNotEmpty)
                  SizedBox(
                    height: 260,
                    child: ListView.separated(
                      controller: _recScrollController,
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      itemCount: recommended.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 14),
                      itemBuilder: (_, i) => SizedBox(width: 200, child: _card(recommended[i])),
                    ),
                  ),
                const SizedBox(height: 26),
                Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: _vipBanner()),
                const SizedBox(height: 30),
                _headerSection("À l'affiche"),
                const SizedBox(height: 14),
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
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 14,
                  childAspectRatio: 0.68,
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 120)),
          ],
        ),
      ),
      bottomNavigationBar: _bottomNav(),
    );
  }

  PreferredSizeWidget _appBar() {
    final isAdmin = ref.watch(isEventAdminProvider).valueOrNull ?? false;

    return PreferredSize(
      preferredSize: const Size.fromHeight(52),
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: AppBar(
            backgroundColor: _ThixColors.bg.withOpacity(0.85),
            elevation: 0,
            systemOverlayStyle: SystemUiOverlayStyle.light,
            titleSpacing: 16,
            toolbarHeight: 52,
            title: Row(
              children: [
                Container(
                  height: 30,
                  width: 30,
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(9)),
                  child: const Icon(Icons.confirmation_num_rounded, color: Colors.black, size: 15),
                ),
                const SizedBox(width: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: const [
                    Text('THIX', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.5)),
                    SizedBox(width: 3),
                    Text('TICKETS', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w300, color: _ThixColors.textSecondary)),
                  ],
                ),
                const Spacer(),
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: const Icon(Icons.search_rounded, color: Colors.white, size: 20),
                  onPressed: () => context.push('/thix-event/search'),
                ),
                const SizedBox(width: 6),
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: const Icon(Icons.notifications_none_rounded, color: Colors.white, size: 20),
                      onPressed: () {},
                    ),
                    Positioned(
                      right: 2,
                      top: 2,
                      child: Container(
                        height: 7,
                        width: 7,
                        decoration: const BoxDecoration(color: _ThixColors.primary, shape: BoxShape.circle),
                      ),
                    ),
                  ],
                ),
                if (isAdmin) ...[
                  const SizedBox(width: 10),
                  InkWell(
                    onTap: () => context.push('/thix-event/admin'),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      height: 30,
                      width: 30,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [_ThixColors.primary, _ThixColors.gradientEnd]),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withOpacity(0.15)),
                      ),
                      alignment: Alignment.center,
                      child: const Text('AN', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white)),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _hero(List<Event> list) {
    if (list.isEmpty) return const SizedBox(height: 320);
    return SizedBox(
      height: 460,
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
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: _ThixColors.cardBorderStrong),
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
                          colors: [Colors.black.withOpacity(0.75), Colors.transparent, Colors.black.withOpacity(0.9)],
                        ),
                      ),
                    ),
                    Positioned(
                      left: 16,
                      top: 14,
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                            decoration: BoxDecoration(color: _ThixColors.primary, borderRadius: BorderRadius.circular(20)),
                            child: const Text('BEST-SELLER', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 0.5)),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.white.withOpacity(0.2)),
                            ),
                            child: const Text('À VENIR', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white)),
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      bottom: 20,
                      left: 20,
                      right: 20,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            e.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: -0.5, height: 1.05),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  height: 46,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.08),
                                    border: Border.all(color: Colors.white.withOpacity(0.12)),
                                    borderRadius: BorderRadius.circular(23),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(e.formattedPrice, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800)),
                                ),
                              ),
                              const SizedBox(width: 10),
                              GestureDetector(
                                onTap: () => context.push('/thix-event/event/${e.id}'),
                                child: Container(
                                  height: 46,
                                  padding: const EdgeInsets.symmetric(horizontal: 22),
                                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(23)),
                                  alignment: Alignment.center,
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text('Réserver', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w800, fontSize: 14)),
                                      SizedBox(width: 6),
                                      Icon(Icons.arrow_outward_rounded, color: Colors.black, size: 16),
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
          width: _heroPage == i ? 18 : 6,
          decoration: BoxDecoration(
            color: _heroPage == i ? _ThixColors.primary : Colors.white.withOpacity(0.3),
            borderRadius: BorderRadius.circular(3),
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
      height: 86,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final f = filters[i];
          final isSel = selected == f['value'];
          return InkWell(
            onTap: () => ref.read(eventCategoryProvider.notifier).state = f['value'] as String,
            borderRadius: BorderRadius.circular(18),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: isSel ? _ThixColors.primary : _ThixColors.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: isSel ? _ThixColors.primary : _ThixColors.cardBorder),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(f['icon'] as IconData, color: isSel ? Colors.white : _ThixColors.textSecondary, size: 22),
                  const SizedBox(height: 6),
                  Text(
                    f['label'] as String,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: isSel ? FontWeight.w800 : FontWeight.w600,
                      color: isSel ? Colors.white : _ThixColors.textSecondary,
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
      {'value': 'all', 'label': 'Toutes'},
      {'value': 'today', 'label': "Aujourd'hui"},
      {'value': 'week', 'label': 'Cette semaine'},
      {'value': 'month', 'label': 'Ce mois-ci'},
    ];
    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final f = filters[i];
          final isSel = selected == f['value'];
          return InkWell(
            onTap: () => ref.read(eventDateFilterProvider.notifier).state = f['value']!,
            borderRadius: BorderRadius.circular(17),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: isSel ? _ThixColors.primary.withOpacity(0.15) : Colors.white.withOpacity(0.04),
                borderRadius: BorderRadius.circular(17),
                border: Border.all(color: isSel ? _ThixColors.primary.withOpacity(0.4) : _ThixColors.cardBorder),
              ),
              alignment: Alignment.center,
              child: Text(
                f['label']!,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: isSel ? FontWeight.w800 : FontWeight.w600,
                  color: isSel ? _ThixColors.primaryLight : _ThixColors.textSecondary,
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
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [_ThixColors.primary, _ThixColors.gradientEnd]),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text('PREMIUM', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 0.6)),
                  ),
                Text(t, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.3)),
              ],
            ),
            GestureDetector(
              onTap: () => context.push('/thix-event/recommended'),
              child: const Row(
                children: [
                  Text('Tout voir', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _ThixColors.textSecondary)),
                  SizedBox(width: 4),
                  Icon(Icons.arrow_outward_rounded, size: 13, color: _ThixColors.textSecondary),
                ],
              ),
            ),
          ],
        ),
      );

  // 🟢 CORRECTION: Le texte et l'icône de la date et du lieu sont maintenant blancs
  Widget _card(Event event) => GestureDetector(
        onTap: () => context.push('/thix-event/event/${event.id}'),
        child: Container(
          decoration: BoxDecoration(
            color: _ThixColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _ThixColors.cardBorder),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  AspectRatio(
                    aspectRatio: 1.3,
                    child: Image.network(event.imageUrl ?? '', fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: _ThixColors.surfaceAlt)),
                  ),
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: Colors.black.withOpacity(0.6), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.white.withOpacity(0.1))),
                      child: Text(event.formattedPrice, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)),
                    ),
                  ),
                  Positioned(
                    right: 8,
                    bottom: 8,
                    child: Container(
                      height: 28,
                      width: 28,
                      decoration: BoxDecoration(color: Colors.black.withOpacity(0.6), shape: BoxShape.circle, border: Border.all(color: Colors.white.withOpacity(0.1))),
                      child: const Icon(Icons.favorite_border_rounded, color: Colors.white, size: 14),
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
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Colors.white, height: 1.2),
                      ),
                      Column(
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.calendar_today_rounded, size: 10, color: Colors.white),
                              const SizedBox(width: 4),
                              Expanded(child: Text(event.shortDate, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600))),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.location_on_rounded, size: 10, color: Colors.white),
                              const SizedBox(width: 4),
                              Expanded(child: Text(event.location, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600))),
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
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [_ThixColors.primary, _ThixColors.gradientEnd]),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          children: [
            Container(
              height: 40,
              width: 40,
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.verified_rounded, color: Colors.white),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Billets infalsifiables, QR dynamique et coupe-file garanti.',
                style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      );

  Widget _bottomNav() => Container(
        margin: const EdgeInsets.only(left: 20, right: 20, bottom: 18),
        height: 58,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: _ThixColors.surfaceAlt.withOpacity(0.92),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: _ThixColors.cardBorderStrong),
        ),
        child: SafeArea(
          top: false,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _navItem(icon: Icons.home_rounded, label: 'Accueil', selected: true, onTap: () {}),
              _navItem(icon: Icons.explore_outlined, label: 'Explorer', onTap: () => context.push('/thix-event/search')),
              _navItem(icon: Icons.confirmation_num_outlined, label: 'Billets', onTap: () => context.push('/thix-event/my-tickets')),
              _navItem(icon: Icons.favorite_border_rounded, label: 'Favoris', onTap: () => context.push('/thix-event/favorites')),
              _navItem(icon: Icons.person_outline_rounded, label: 'Profil', onTap: () => context.push('/profile')),
            ],
          ),
        ),
      );

  Widget _navItem({required IconData icon, required String label, bool selected = false, VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        height: 46,
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: selected ? Colors.black : Colors.white.withOpacity(0.5)),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: selected ? Colors.black : Colors.white.withOpacity(0.5)),
            ),
          ],
        ),
      ),
    );
  }
}
