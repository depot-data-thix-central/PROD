// lib/presentation/education/screens/education_home.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/presentation/education/models/book.dart';
import '../providers/education_provider.dart' hide certificatesProvider;
import '../providers/certificate_provider.dart';
import 'package:thix_id/presentation/education/providers/book_provider.dart';
import '../widgets/common/education_category_chip.dart';
import '../models/category.dart';
import '../models/formation.dart';
import '../models/certificate.dart';

// ============================================================================
// CONSTANTES COULEURS "ENTREPRISE ÉDUCATION"
// ============================================================================
const Color _eduNavyBlue = Color(0xFF0F172A);
const Color _eduAccentBlue = Color(0xFF0284C7);
const Color _eduShelfWood = Color(0xFFD4A373);
const Color _eduShelfShadow = Color(0xFFB5835A);

// ============================================================================
// PROVIDERS
// ============================================================================
final _eduTabIndexProvider = StateProvider<int>((ref) => 0);
final _selectedCategoryProvider = StateProvider<String?>((ref) => null);
final _favoritesProvider = StateProvider<Set<String>>((ref) => <String>{});

final _unreadNotificationsProvider =
    FutureProvider.autoDispose<int>((ref) async {
  final userId = ref.watch(currentUserIdProvider).value;
  if (userId == null) return 0;
  try {
    final res = await Supabase.instance.client
        .from('notifications')
        .select('id')
        .eq('user_id', userId)
        .eq('is_read', false);
    return (res as List).length;
  } catch (_) {
    return 0;
  }
});

final _instructorRoleProvider = FutureProvider.autoDispose<bool>((ref) async {
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) return false;
  try {
    final res = await Supabase.instance.client
        .from('profiles')
        .select('role, account_type')
        .eq('id', user.id)
        .maybeSingle();
    if (res == null) return false;
    final role = (res['role'] ?? res['account_type'] ?? '')
        .toString()
        .toLowerCase()
        .trim();
    const allowed = {
      'formateur',
      'admin',
      'moderateur',
      'entreprise',
      'support',
      'instructor',
      'teacher'
    };
    return allowed.contains(role);
  } catch (_) {
    return false;
  }
});

// ============================================================================
// HELPERS GLOBAUX
// ============================================================================
int _lessonCount(Formation f) =>
    f.modules?.fold<int>(0, (sum, m) => sum + (m.lessons?.length ?? 0)) ?? 0;

String _durationLabel(Formation f) {
  final h = f.duration ~/ 60;
  final m = f.duration % 60;
  if (h <= 0) return '${m}min';
  return m <= 0 ? '${h}h' : '${h}h ${m}min';
}

IconData _categoryIcon(String name) {
  final n = name.toLowerCase();
  if (n.contains('dev') || n.contains('code') || n.contains('info')) {
    return Icons.code_rounded;
  }
  if (n.contains('lang')) return Icons.translate_rounded;
  if (n.contains('business') || n.contains('entrep') || n.contains('manage')) {
    return Icons.business_center_rounded;
  }
  if (n.contains('design') || n.contains('art')) return Icons.palette_rounded;
  if (n.contains('market')) return Icons.campaign_rounded;
  if (n.contains('santé') || n.contains('health') || n.contains('sport')) {
    return Icons.favorite_rounded;
  }
  if (n.contains('finance') || n.contains('compta')) {
    return Icons.payments_rounded;
  }
  if (n.contains('musiq') || n.contains('music')) {
    return Icons.music_note_rounded;
  }
  if (n.contains('culture')) return Icons.museum_rounded;
  return Icons.school_rounded;
}

// ============================================================================
// ANIMATIONS RÉUTILISABLES
// ============================================================================
class _FadeInUp extends StatefulWidget {
  final Widget child;
  final int delayMs;
  const _FadeInUp({required this.child, this.delayMs = 0});

  @override
  State<_FadeInUp> createState() => _FadeInUpState();
}

class _FadeInUpState extends State<_FadeInUp>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 550),
  );
  late final Animation<double> _anim =
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(milliseconds: widget.delayMs), () {
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
    return FadeTransition(
      opacity: _anim,
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero)
            .animate(_anim),
        child: widget.child,
      ),
    );
  }
}

class _Pressable extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  const _Pressable({required this.child, required this.onTap});

  @override
  State<_Pressable> createState() => _PressableState();
}

class _PressableState extends State<_Pressable> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.965 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

class _PulseBadge extends StatefulWidget {
  final int count;
  const _PulseBadge({required this.count});

  @override
  State<_PulseBadge> createState() => _PulseBadgeState();
}

class _PulseBadgeState extends State<_PulseBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: Tween<double>(begin: 1.0, end: 1.25).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
      ),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: const BoxDecoration(
          color: ThixPolicy.danger,
          shape: BoxShape.circle,
        ),
        child: Text(
          '${widget.count}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 9,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

class _ShimmerBox extends StatefulWidget {
  final double height;
  final double width;
  final double radius;
  const _ShimmerBox({
    required this.height,
    this.width = double.infinity,
    this.radius = 24,
  });

  @override
  State<_ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<_ShimmerBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.45, end: 0.9).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
      ),
      child: Container(
        height: widget.height,
        width: widget.width,
        decoration: BoxDecoration(
          color: ThixPolicy.border.withOpacity(0.5),
          borderRadius: BorderRadius.circular(widget.radius),
        ),
      ),
    );
  }
}

// ============================================================================
// PAGE PRINCIPALE (HUB E-LEARNING)
// ============================================================================
class EducationHome extends ConsumerWidget {
  const EducationHome({super.key});

  static const _pages = [
    _HomePage(),
    _MyLearningPage(),
    _LibraryPage(),
    _CertificatesPage(),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedIndex = ref.watch(_eduTabIndexProvider);

    return Scaffold(
      backgroundColor: ThixPolicy.surfaceSoft,
      body: Stack(
        children: [
          IndexedStack(
            index: selectedIndex.clamp(0, _pages.length - 1),
            children: _pages,
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _FloatingBottomNav(selectedIndex: selectedIndex),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// BOTTOM NAVIGATION FLOTTANTE
// ============================================================================
class _FloatingBottomNav extends ConsumerWidget {
  final int selectedIndex;
  const _FloatingBottomNav({required this.selectedIndex});

  static const _items = [
    (Icons.home_rounded, 'Accueil'),
    (Icons.play_circle_outline_rounded, 'My Learning'),
    (Icons.local_library_rounded, 'Bibliothèque'),
    (Icons.workspace_premium_rounded, 'Certificats'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
            ThixPolicy.s12, 0, ThixPolicy.s12, ThixPolicy.s12),
        child: Container(
          height: 68,
          decoration: BoxDecoration(
            color: ThixPolicy.card,
            borderRadius: BorderRadius.circular(34),
            border: Border.all(color: ThixPolicy.border.withOpacity(0.5)),
            boxShadow: [
              BoxShadow(
                color: _eduNavyBlue.withOpacity(0.10),
                blurRadius: 28,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(_items.length, (i) {
              final isSelected = selectedIndex == i;
              final item = _items[i];
              return Expanded(
                child: InkWell(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    ref.read(_eduTabIndexProvider.notifier).state = i;
                  },
                  borderRadius: BorderRadius.circular(24),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOut,
                    margin: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? _eduAccentBlue.withOpacity(0.10)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 250),
                          transitionBuilder: (child, anim) =>
                              ScaleTransition(scale: anim, child: child),
                          child: Icon(
                            item.$1,
                            key: ValueKey(isSelected),
                            color: isSelected
                                ? _eduAccentBlue
                                : ThixPolicy.textSecondary,
                            size: isSelected ? 25 : 22,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          item.$2,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: isSelected
                                ? FontWeight.w800
                                : FontWeight.w600,
                            color: isSelected
                                ? _eduAccentBlue
                                : ThixPolicy.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// ONGLET MY LEARNING
// ============================================================================
class _MyLearningPage extends ConsumerWidget {
  const _MyLearningPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = ref.watch(currentUserIdProvider).value;
    if (userId == null) {
      return const Center(child: Text('Connectez-vous pour voir vos cours'));
    }

    final enrollAsync = ref.watch(myEnrollmentsProvider(userId));

    return Scaffold(
      backgroundColor: ThixPolicy.surfaceSoft,
      appBar: AppBar(
        backgroundColor: ThixPolicy.card,
        elevation: 0,
        title: const Text(
          'My Learning',
          style: TextStyle(
            color: _eduNavyBlue,
            fontWeight: FontWeight.w900,
            fontSize: 20,
          ),
        ),
      ),
      body: enrollAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(color: _eduAccentBlue)),
        error: (e, _) => Center(child: Text('Erreur : $e')),
        data: (list) {
          if (list.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.school_outlined,
                      size: 64, color: Colors.grey.withOpacity(0.5)),
                  const SizedBox(height: 16),
                  const Text(
                    'Aucun cours en cours',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Colors.grey,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Inscrivez-vous à une formation pour commencer.',
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () =>
                        ref.read(_eduTabIndexProvider.notifier).state = 0,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _eduAccentBlue,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Explorer les formations'),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, i) {
              final e = list[i];
              final f = e.formation;
              if (f == null) return const SizedBox.shrink();
              final pct = ((e.progress ?? 0) * 100).round();
              final done = pct >= 100;

              return _FadeInUp(
                delayMs: i * 60,
                child: _Pressable(
                  onTap: () => context.push('/education/formation/${f.id}'),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: f.imageUrl != null &&
                                      f.imageUrl!.isNotEmpty
                                  ? Image.network(
                                      f.imageUrl!,
                                      width: 64,
                                      height: 64,
                                      fit: BoxFit.cover,
                                    )
                                  : Container(
                                      width: 64,
                                      height: 64,
                                      color: _eduNavyBlue,
                                      child: const Icon(Icons.school,
                                          color: Colors.white),
                                    ),
                            ),
                            if (done)
                              Positioned(
                                right: -4,
                                bottom: -4,
                                child: Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: const BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.verified_rounded,
                                    color: Color(0xFF10B981),
                                    size: 18,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                f.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                  color: _eduNavyBlue,
                                ),
                              ),
                              const SizedBox(height: 8),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: e.progress ?? 0,
                                  minHeight: 6,
                                  backgroundColor: Colors.grey.shade200,
                                  color: done
                                      ? const Color(0xFF10B981)
                                      : _eduAccentBlue,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                done ? 'Terminé 🎉' : '$pct % terminé',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: done
                                      ? const Color(0xFF10B981)
                                      : Colors.grey,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded,
                            color: Colors.grey),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// ============================================================================
// ONGLET 1 : ACCUEIL
// ============================================================================
class _HomePage extends ConsumerStatefulWidget {
  const _HomePage();
  @override
  ConsumerState<_HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<_HomePage>
    with AutomaticKeepAliveClientMixin {
  final _scrollController = ScrollController();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >
          _scrollController.position.maxScrollExtent - 300) {
        ref.read(formationsProvider.notifier).loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // ✅ MÉTHODES CATÉGORIES (bien DANS la classe _HomePageState)
  List<Category> _mergeCategories(List<Category> dbCats) {
    // ✅ PAS de 'const' ici : le constructeur de Category n'est pas const
    final customCats = <Category>[
      Category(id: 'cat-langues', name: 'Langues'),
      Category(id: 'cat-entrepreneuriat', name: 'Entrepreneuriat'),
      Category(id: 'cat-dev', name: 'Développement personnel'),
      Category(id: 'cat-culture', name: 'Culture'),
    ];
    final List<Category> allCats = List.from(dbCats);
    for (var custom in customCats) {
      if (!allCats
          .any((c) => c.name.toLowerCase() == custom.name.toLowerCase())) {
        allCats.add(custom);
      }
    }
    return allCats;
  }

  bool _matchesCategory(Formation f, Category cat) {
    try {
      final fCatId = f.categoryId;
      if (fCatId == cat.id) return true;
      final fCatName = f.category?.name;
      if (fCatName != null &&
          fCatName.toLowerCase() == cat.name.toLowerCase()) {
        return true;
      }
    } catch (_) {}
    return false;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final user = Supabase.instance.client.auth.currentUser;
    final unreadAsync = ref.watch(_unreadNotificationsProvider);
    final formationsAsync = ref.watch(formationsProvider);
    final categoriesAsync = ref.watch(categoriesProvider);
    final isInstructorAsync = ref.watch(_instructorRoleProvider);

    return RefreshIndicator(
      color: _eduAccentBlue,
      backgroundColor: ThixPolicy.card,
      onRefresh: () async {
        ref.invalidate(formationsProvider);
        ref.invalidate(categoriesProvider);
        ref.invalidate(_instructorRoleProvider);
        if (user != null) ref.invalidate(myEnrollmentsProvider(user.id));
      },
      child: CustomScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics()),
        slivers: [
          SliverToBoxAdapter(
            child: Container(
              padding: EdgeInsets.only(
                  top: MediaQuery.paddingOf(context).top + ThixPolicy.s12,
                  bottom: ThixPolicy.s16),
              decoration: const BoxDecoration(
                color: ThixPolicy.card,
                borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(ThixPolicy.rLg)),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: ThixPolicy.s16),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 22,
                          backgroundColor: _eduNavyBlue.withOpacity(0.05),
                          backgroundImage:
                              user?.userMetadata?['avatar_url'] != null
                                  ? NetworkImage(
                                      user!.userMetadata!['avatar_url'])
                                  : null,
                          child: user?.userMetadata?['avatar_url'] == null
                              ? const Icon(Icons.person,
                                  color: _eduNavyBlue, size: 22)
                              : null,
                        ),
                        const SizedBox(width: ThixPolicy.s12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                  'Bonjour, ${user?.userMetadata?['full_name']?.split(' ')[0] ?? 'Apprenant'} 👋',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color: _eduNavyBlue)),
                              const Text('Prêt à développer vos compétences ?',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: ThixPolicy.textSecondary,
                                      fontWeight: FontWeight.w500)),
                            ],
                          ),
                        ),
                        _Pressable(
                          onTap: () => context.push('/notifications'),
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border:
                                        Border.all(color: ThixPolicy.border)),
                                child: const Icon(
                                    Icons.notifications_none_rounded,
                                    color: _eduNavyBlue,
                                    size: 20),
                              ),
                              unreadAsync.maybeWhen(
                                data: (count) => count > 0
                                    ? Positioned(
                                        right: -4,
                                        top: -4,
                                        child: _PulseBadge(count: count),
                                      )
                                    : const SizedBox.shrink(),
                                orElse: () => const SizedBox.shrink(),
                              )
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: ThixPolicy.s16),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: ThixPolicy.s16),
                    child: _Pressable(
                      onTap: () => context.push('/education/search'),
                      child: Container(
                        height: 48,
                        padding: const EdgeInsets.symmetric(
                            horizontal: ThixPolicy.s16),
                        decoration: BoxDecoration(
                            color: ThixPolicy.surface,
                            borderRadius: BorderRadius.circular(
                                ThixPolicy.inputRadius),
                            border: Border.all(color: ThixPolicy.border)),
                        child: const Row(
                          children: [
                            Icon(Icons.search_rounded,
                                color: ThixPolicy.textSecondary, size: 22),
                            SizedBox(width: ThixPolicy.s10),
                            Expanded(
                              child: Text(
                                  'Rechercher un programme, une certification...',
                                  style: TextStyle(
                                      color: ThixPolicy.textSecondary,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500)),
                            ),
                            Icon(Icons.tune_rounded,
                                color: ThixPolicy.textSecondary, size: 20),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: ThixPolicy.s16),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: ThixPolicy.s16),
                    child: isInstructorAsync.when(
                      loading: () => const _QuickIconsSkeleton(),
                      error: (_, __) =>
                          const _QuickIconsRow(showInstructor: false),
                      data: (isInstructor) =>
                          _QuickIconsRow(showInstructor: isInstructor),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: ThixPolicy.s20)),
          formationsAsync.when(
            loading: () => const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: ThixPolicy.s16),
                child: Column(
                  children: [
                    _ShimmerBox(height: 380),
                    SizedBox(height: 24),
                    _ShimmerBox(height: 110, radius: 20),
                    SizedBox(height: 24),
                    _ShimmerBox(height: 260, radius: 20),
                  ],
                ),
              ),
            ),
            error: (_, __) => SliverToBoxAdapter(
              child: Center(
                child: Column(
                  children: [
                    const SizedBox(height: 60),
                    const Icon(Icons.cloud_off_rounded,
                        size: 56, color: ThixPolicy.textSecondary),
                    const SizedBox(height: 12),
                    const Text('Erreur de chargement.',
                        style: TextStyle(
                            color: ThixPolicy.textSecondary,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () => ref.invalidate(formationsProvider),
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('Réessayer'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _eduAccentBlue,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            data: (paginated) {
              final formations = paginated.items;
              final recentFormations = formations.take(6).toList();

              final topFormations = [...formations]
                ..sort((a, b) => b.rating.compareTo(a.rating));
              final awaitedFormations = formations.reversed.take(4).toList();

              return SliverList(
                delegate: SliverChildListDelegate([
                  _FadeInUp(
                    child: _HeroCarousel(recentFormations: recentFormations),
                  ),
                  const SizedBox(height: ThixPolicy.s24),

                  if (user != null)
                    _FadeInUp(
                      delayMs: 80,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: ThixPolicy.s16),
                        child: _ContinueLearningCard(userId: user.id),
                      ),
                    ),
                  const SizedBox(height: ThixPolicy.s24),

                  if (topFormations.isNotEmpty) ...[
                    _FadeInUp(
                      delayMs: 120,
                      child: _SectionHeader(
                        title: 'Top des formations',
                        icon: Icons.star_rounded,
                        onSeeAll: () => context.push('/education/explore'),
                      ),
                    ),
                    const SizedBox(height: ThixPolicy.s12),
                    SizedBox(
                      height: 300,
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(
                            horizontal: ThixPolicy.s16),
                        scrollDirection: Axis.horizontal,
                        itemCount: topFormations.length > 6
                            ? 6
                            : topFormations.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(width: ThixPolicy.s16),
                        itemBuilder: (_, i) {
                          final f = topFormations[i];
                          return SizedBox(
                            width: 210,
                            child: _ProFormationCard(
                              formation: f,
                              onTap: () => context.push(
                                  '/education/formation/${f.id}'),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: ThixPolicy.s28),
                  ],

                  categoriesAsync.maybeWhen(
                    data: (dbCats) {
                      final allCats = _mergeCategories(dbCats);
                      if (allCats.isEmpty) return const SizedBox.shrink();
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _FadeInUp(
                            child: _SectionHeader(
                              title: 'Parcourir par catégorie',
                              icon: Icons.category_rounded,
                              onSeeAll: () =>
                                  context.push('/education/explore'),
                              seeAllLabel: 'Tout voir',
                            ),
                          ),
                          const SizedBox(height: ThixPolicy.s12),
                          SizedBox(
                            height: 108,
                            child: ListView.separated(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: ThixPolicy.s16),
                              scrollDirection: Axis.horizontal,
                              itemCount: allCats.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(width: ThixPolicy.s12),
                              itemBuilder: (_, i) {
                                final cat = allCats[i];
                                final count = formations
                                    .where((f) => _matchesCategory(f, cat))
                                    .length;
                                return _CategoryTile(
                                  category: cat,
                                  count: count,
                                  index: i,
                                  onTap: () => context.push(
                                      '/education/explore?category=${cat.id}'),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: ThixPolicy.s28),
                        ],
                      );
                    },
                    orElse: () => const SizedBox.shrink(),
                  ),

                  categoriesAsync.maybeWhen(
                    data: (dbCats) {
                      final allCats = _mergeCategories(dbCats);
                      return Column(
                        children: allCats.map((cat) {
                          final catFormations = formations
                              .where((f) => _matchesCategory(f, cat))
                              .toList();

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _SectionHeader(
                                title: cat.name,
                                icon: _categoryIcon(cat.name),
                                onSeeAll: () => context.push(
                                    '/education/explore?category=${cat.id}'),
                                seeAllLabel: 'Voir tout',
                              ),
                              const SizedBox(height: ThixPolicy.s12),
                              if (catFormations.isEmpty)
                                Container(
                                  margin: const EdgeInsets.symmetric(
                                      horizontal: ThixPolicy.s16),
                                  height: 90,
                                  decoration: BoxDecoration(
                                    color: ThixPolicy.surface,
                                    borderRadius:
                                        BorderRadius.circular(ThixPolicy.rLg),
                                    border: Border.all(
                                        color: ThixPolicy.border,
                                        style: BorderStyle.solid),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                      'Bientôt de nouveaux cours en ${cat.name}',
                                      style: const TextStyle(
                                          color: ThixPolicy.textSecondary,
                                          fontWeight: FontWeight.w600)),
                                )
                              else
                                SizedBox(
                                  height: 300,
                                  child: ListView.separated(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: ThixPolicy.s16),
                                    scrollDirection: Axis.horizontal,
                                    itemCount: catFormations.length,
                                    separatorBuilder: (_, __) =>
                                        const SizedBox(width: ThixPolicy.s16),
                                    itemBuilder: (_, i) {
                                      final f = catFormations[i];
                                      return SizedBox(
                                        width: 210,
                                        child: _ProFormationCard(
                                          formation: f,
                                          onTap: () => context.push(
                                              '/education/formation/${f.id}'),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              const SizedBox(height: ThixPolicy.s28),
                            ],
                          );
                        }).toList(),
                      );
                    },
                    orElse: () => const SizedBox.shrink(),
                  ),

                  if (awaitedFormations.isNotEmpty) ...[
                    _SectionHeader(
                      title: 'Les plus attendus',
                      icon: Icons.local_fire_department_rounded,
                      onSeeAll: () => context.push('/education/explore'),
                    ),
                    const SizedBox(height: ThixPolicy.s12),
                    SizedBox(
                      height: 260,
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(
                            horizontal: ThixPolicy.s16),
                        scrollDirection: Axis.horizontal,
                        itemCount: awaitedFormations.length > 4
                            ? 4
                            : awaitedFormations.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(width: ThixPolicy.s16),
                        itemBuilder: (_, i) {
                          final f = awaitedFormations[i];
                          return SizedBox(
                            width: 220,
                            child: _AwaitedFormationCard(formation: f),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: ThixPolicy.s28),
                  ],

                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: ThixPolicy.s16),
                    child: _Pressable(
                      onTap: () => context.push('/education/explore'),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [_eduNavyBlue, Color(0xFF1E293B)],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: _eduNavyBlue.withOpacity(0.25),
                              blurRadius: 16,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.grid_view_rounded,
                                color: ThixPolicy.gold, size: 20),
                            SizedBox(width: 10),
                            Text(
                              'Explorer tout le catalogue',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 15,
                                letterSpacing: 0.2,
                              ),
                            ),
                            SizedBox(width: 8),
                            Icon(Icons.arrow_forward_rounded,
                                color: ThixPolicy.gold, size: 18),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 120),
                ]),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// HERO CAROUSEL IMMERSIF
// ============================================================================
class _HeroCarousel extends StatefulWidget {
  final List<Formation> recentFormations;
  const _HeroCarousel({required this.recentFormations});

  @override
  State<_HeroCarousel> createState() => _HeroCarouselState();
}

class _HeroCarouselState extends State<_HeroCarousel> {
  final PageController _controller = PageController(viewportFraction: 0.92);
  double _pageOffset = 0;
  int _page = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      if (mounted) setState(() => _pageOffset = _controller.page ?? 0);
    });
    _restartTimer();
  }

  void _restartTimer() {
    _timer?.cancel();
    if (widget.recentFormations.length > 1) {
      _timer = Timer.periodic(const Duration(seconds: 5), (_) {
        if (!mounted || !_controller.hasClients) return;
        final next = (_page + 1) % widget.recentFormations.length;
        _controller.animateToPage(
          next,
          duration: const Duration(milliseconds: 650),
          curve: Curves.easeInOutCubic,
        );
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.recentFormations.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        SizedBox(
          height: 400,
          child: PageView.builder(
            controller: _controller,
            itemCount: widget.recentFormations.length,
            onPageChanged: (i) {
              setState(() => _page = i);
              _restartTimer();
            },
            itemBuilder: (_, i) {
              final f = widget.recentFormations[i];
              final delta = (i - _pageOffset).abs().clamp(0.0, 1.0);
              final scale = 1.0 - (delta * 0.06);
              final lessons = _lessonCount(f);

              return Transform.scale(
                scale: scale,
                child: _Pressable(
                  onTap: () => context.push('/education/formation/${f.id}'),
                  child: Container(
                    margin:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      color: _eduNavyBlue,
                      boxShadow: [
                        BoxShadow(
                          color: _eduNavyBlue.withOpacity(0.30),
                          blurRadius: 24,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(28),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (f.imageUrl != null && f.imageUrl!.isNotEmpty)
                            Image.network(
                              f.imageUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  const _HeroPlaceholder(),
                            )
                          else
                            const _HeroPlaceholder(),

                          Positioned.fill(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.black.withOpacity(0.25 + delta * 0.3),
                                    Colors.transparent,
                                    Colors.black.withOpacity(0.85),
                                  ],
                                  stops: const [0.0, 0.45, 1.0],
                                ),
                              ),
                            ),
                          ),

                          Positioned(
                            top: 16,
                            left: 16,
                            right: 16,
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 7),
                                  decoration: BoxDecoration(
                                    color: _eduAccentBlue,
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: [
                                      BoxShadow(
                                        color:
                                            _eduAccentBlue.withOpacity(0.45),
                                        blurRadius: 12,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.auto_awesome_rounded,
                                          color: Colors.white, size: 12),
                                      SizedBox(width: 6),
                                      Text('NOUVEAU',
                                          style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 10,
                                              fontWeight: FontWeight.w900,
                                              letterSpacing: 0.8)),
                                    ],
                                  ),
                                ),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.black45,
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.star_rounded,
                                          color: ThixPolicy.gold, size: 14),
                                      const SizedBox(width: 4),
                                      Text(
                                        f.rating.toStringAsFixed(1),
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w800),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          Positioned(
                            left: 20,
                            right: 20,
                            bottom: 22,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (f.category?.name != null)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.18),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.white24),
                                    ),
                                    child: Text(
                                      f.category!.name.toUpperCase(),
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 9,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 1.0),
                                    ),
                                  ),
                                const SizedBox(height: 10),
                                Text(
                                  f.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 26,
                                    fontWeight: FontWeight.w900,
                                    height: 1.15,
                                    letterSpacing: -0.6,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 12,
                                      backgroundColor:
                                          Colors.white.withOpacity(0.2),
                                      child: const Icon(Icons.person,
                                          size: 13, color: Colors.white),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        f.instructorName ?? 'THIX Academy',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    GestureDetector(
                                      onTap: () => context.push(
                                          '/education/formation/${f.id}'),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 18, vertical: 12),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius:
                                              BorderRadius.circular(28),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black
                                                  .withOpacity(0.25),
                                              blurRadius: 12,
                                              offset: const Offset(0, 5),
                                            ),
                                          ],
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.menu_book_rounded,
                                                color: _eduNavyBlue, size: 18),
                                            SizedBox(width: 8),
                                            Text('Découvrir',
                                                style: TextStyle(
                                                    color: _eduNavyBlue,
                                                    fontSize: 14,
                                                    fontWeight:
                                                        FontWeight.w900)),
                                            SizedBox(width: 8),
                                            Icon(Icons.arrow_forward_rounded,
                                                color: _eduNavyBlue, size: 16),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const Spacer(),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.16),
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                              Icons.video_library_rounded,
                                              color: Colors.white,
                                              size: 15),
                                          const SizedBox(width: 6),
                                          Text('$lessons leçons',
                                              style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 11,
                                                  fontWeight:
                                                      FontWeight.w700)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: ThixPolicy.s12),
        if (widget.recentFormations.length > 1)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              widget.recentFormations.length,
              (i) => AnimatedContainer(
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeOutCubic,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: _page == i ? 24 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: _page == i ? _eduAccentBlue : ThixPolicy.border,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _HeroPlaceholder extends StatelessWidget {
  const _HeroPlaceholder();
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_eduNavyBlue, _eduAccentBlue],
        ),
      ),
      child: const Center(
        child: Icon(Icons.school_rounded, size: 90, color: Colors.white24),
      ),
    );
  }
}

// ============================================================================
// CARTE PRO FORMATION
// ============================================================================
class _ProFormationCard extends ConsumerWidget {
  final Formation formation;
  final VoidCallback onTap;
  const _ProFormationCard({required this.formation, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favs = ref.watch(_favoritesProvider);
    final isFav = favs.contains(formation.id);
    final lessons = _lessonCount(formation);
    final isTop = formation.rating >= 4.5;

    return _Pressable(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: ThixPolicy.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 5,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(20)),
                    child: formation.imageUrl != null &&
                            formation.imageUrl!.isNotEmpty
                        ? Image.network(formation.imageUrl!,
                            fit: BoxFit.cover)
                        : Container(
                            color: _eduNavyBlue,
                            child: const Icon(Icons.school,
                                color: Colors.white30, size: 44),
                          ),
                  ),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withOpacity(0.35),
                            Colors.transparent,
                            Colors.black.withOpacity(0.45),
                          ],
                          stops: const [0.0, 0.4, 1.0],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 5),
                      decoration: BoxDecoration(
                        color: isTop ? ThixPolicy.gold : _eduAccentBlue,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        isTop ? 'TOP' : 'NOUVEAU',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.6),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: () {
                        final next = Set<String>.from(favs);
                        if (isFav) {
                          next.remove(formation.id);
                        } else {
                          next.add(formation.id);
                        }
                        ref.read(_favoritesProvider.notifier).state = next;
                        HapticFeedback.lightImpact();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(isFav
                                ? 'Retiré des favoris'
                                : 'Ajouté aux favoris ❤️'),
                            duration: const Duration(seconds: 1),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(7),
                          
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.15),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 250),
                          transitionBuilder: (child, anim) =>
                              ScaleTransition(scale: anim, child: child),
                          child: Icon(
                            isFav
                                ? Icons.bookmark_rounded
                                : Icons.bookmark_border_rounded,
                            key: ValueKey(isFav),
                            color: isFav ? _eduAccentBlue : Colors.grey,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.star_rounded,
                              color: ThixPolicy.gold, size: 13),
                          const SizedBox(width: 3),
                          Text(
                            formation.rating.toStringAsFixed(1),
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 4,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      height: 36,
                      child: Text(
                        formation.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: _eduNavyBlue,
                          height: 1.25,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      formation.instructorName ?? 'THIX Academy',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: ThixPolicy.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.video_library_rounded,
                            size: 13, color: _eduAccentBlue),
                        const SizedBox(width: 4),
                        Text('$lessons',
                            style: const TextStyle(
                                fontSize: 11,
                                color: ThixPolicy.textSecondary,
                                fontWeight: FontWeight.w700)),
                        const SizedBox(width: 10),
                        const Icon(Icons.timer_rounded,
                            size: 13, color: _eduAccentBlue),
                        const SizedBox(width: 4),
                        Text(_durationLabel(formation),
                            style: const TextStyle(
                                fontSize: 11,
                                color: ThixPolicy.textSecondary,
                                fontWeight: FontWeight.w700)),
                      ],
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        formation.price > 0
                            ? Text(
                                '${formation.price.toInt()} ${formation.currency}',
                                style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w900,
                                    color: _eduAccentBlue),
                              )
                            : const Text('Gratuit',
                                style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF10B981))),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: _eduAccentBlue.withOpacity(0.10),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.arrow_forward_rounded,
                              color: _eduAccentBlue, size: 14),
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
}

// ============================================================================
// TUILE CATÉGORIE
// ============================================================================
class _CategoryTile extends StatelessWidget {
  final Category category;
  final int count;
  final int index;
  final VoidCallback onTap;
  const _CategoryTile({
    required this.category,
    required this.count,
    required this.index,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final gradients = index.isEven
        ? const [_eduNavyBlue, Color(0xFF1E3A5F)]
        : const [_eduAccentBlue, Color(0xFF0EA5E9)];

    return _FadeInUp(
      delayMs: index * 50,
      child: _Pressable(
        onTap: onTap,
        child: Container(
          width: 160,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: gradients,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: _eduNavyBlue.withOpacity(0.20),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(_categoryIcon(category.name),
                    color: ThixPolicy.gold, size: 20),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    category.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    count <= 0
                        ? 'Bientôt disponible'
                        : '$count cours disponible${count > 1 ? 's' : ''}',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// QUICK ICONS
// ============================================================================
class _QuickIconsRow extends StatelessWidget {
  final bool showInstructor;
  const _QuickIconsRow({required this.showInstructor});

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[
      Expanded(
          child: _QuickIcon(
              icon: Icons.grid_view_rounded,
              label: 'Parcourir',
              onTap: () => ProviderScope.containerOf(context)
                  .read(_eduTabIndexProvider.notifier)
                  .state = 1)),
      Expanded(
          child: _QuickIcon(
              icon: Icons.local_library_rounded,
              label: 'Bibliothèque',
              onTap: () => ProviderScope.containerOf(context)
                  .read(_eduTabIndexProvider.notifier)
                  .state = 2)),
      Expanded(
          child: _QuickIcon(
              icon: Icons.workspace_premium_rounded,
              label: 'Certificats',
              onTap: () => ProviderScope.containerOf(context)
                  .read(_eduTabIndexProvider.notifier)
                  .state = 3)),
    ];

    if (showInstructor) {
      items.add(
        Expanded(
            child: _QuickIcon(
                icon: Icons.co_present_rounded,
                label: 'Formateur',
                gold: true,
                onTap: () => context.push('/instructor/dashboard'))),
      );
    }

    return Row(children: items);
  }
}

class _QuickIconsSkeleton extends StatelessWidget {
  const _QuickIconsSkeleton();
  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(
        4,
        (_) => Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            child: Column(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: ThixPolicy.surface,
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  width: 40,
                  height: 10,
                  decoration: BoxDecoration(
                    color: ThixPolicy.surface,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QuickIcon extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool gold;
  const _QuickIcon({
    required this.icon,
    required this.label,
    required this.onTap,
    this.gold = false,
  });

  @override
  Widget build(BuildContext context) {
    final tint = gold ? ThixPolicy.premiumAccent : _eduAccentBlue;
    return _Pressable(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    tint.withOpacity(0.14),
                    tint.withOpacity(0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: tint.withOpacity(0.15)),
              ),
              child: Icon(icon, color: tint, size: 22),
            ),
            const SizedBox(height: 6),
            Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: _eduNavyBlue)),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// SECTION HEADER
// ============================================================================
class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback? onSeeAll;
  final String? seeAllLabel;
  const _SectionHeader({
    required this.title,
    required this.icon,
    this.onSeeAll,
    this.seeAllLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s16),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 22,
            decoration: BoxDecoration(
              color: _eduAccentBlue,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Icon(icon, size: 19, color: ThixPolicy.gold),
          const SizedBox(width: 6),
          Expanded(
            child: Text(title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: _eduNavyBlue,
                    letterSpacing: -0.3)),
          ),
          if (onSeeAll != null)
            GestureDetector(
              onTap: onSeeAll,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(seeAllLabel ?? 'Voir le catalogue',
                      style: const TextStyle(
                          color: _eduAccentBlue,
                          fontWeight: FontWeight.w700,
                          fontSize: 12)),
                  const Icon(Icons.chevron_right_rounded,
                      color: _eduAccentBlue, size: 16),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ============================================================================
// CARTE REPRENDRE L'APPRENTISSAGE
// ============================================================================
class _ContinueLearningCard extends ConsumerWidget {
  final String userId;
  const _ContinueLearningCard({required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enrollAsync = ref.watch(myEnrollmentsProvider(userId));
    return enrollAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (list) {
        final inProgress = list
            .where((e) =>
                e.formation != null &&
                (e.progress ?? 0) > 0 &&
                (e.progress ?? 0) < 1)
            .toList();
        if (inProgress.isEmpty) return const SizedBox.shrink();

        final current = inProgress.first;
        final f = current.formation!;
        final pct = ((current.progress ?? 0) * 100).round();

        return _Pressable(
          onTap: () => context.push('/education/formation/${f.id}'),
          child: Container(
            padding: const EdgeInsets.all(ThixPolicy.s16),
            decoration: BoxDecoration(
              gradient:
                  const LinearGradient(colors: [_eduNavyBlue, Color(0xFF1E293B)]),
              borderRadius: BorderRadius.circular(ThixPolicy.rLg),
              boxShadow: [
                BoxShadow(
                    color: _eduNavyBlue.withOpacity(0.25),
                    blurRadius: 16,
                    offset: const Offset(0, 8))
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('REPRENDRE L\'APPRENTISSAGE',
                          style: TextStyle(
                              color: ThixPolicy.gold,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.8)),
                      const SizedBox(height: 8),
                      Text(f.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              height: 1.3)),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: LinearProgressIndicator(
                                  value: current.progress,
                                  minHeight: 6,
                                  backgroundColor:
                                      Colors.white.withOpacity(0.15),
                                  color: ThixPolicy.gold),
                            ),
                          ),
                          const SizedBox(width: ThixPolicy.s12),
                          Text('$pct%',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: ThixPolicy.s16),
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                      color: ThixPolicy.gold,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                            color: ThixPolicy.gold.withOpacity(0.4),
                            blurRadius: 12,
                            offset: const Offset(0, 4))
                      ]),
                  child: const Icon(Icons.play_arrow_rounded,
                      color: _eduNavyBlue, size: 30),
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
// CARTE "LES PLUS ATTENDUS"
// ============================================================================
class _AwaitedFormationCard extends StatelessWidget {
  final dynamic formation;
  const _AwaitedFormationCard({required this.formation});

  @override
  Widget build(BuildContext context) {
    return _Pressable(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.lock_clock, color: Colors.white),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Bientôt disponible ! (Ouverture prévue prochainement)',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            backgroundColor: ThixPolicy.primaryDeep,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            duration: const Duration(seconds: 3),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(ThixPolicy.rLg),
          border: Border.all(color: ThixPolicy.border),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 4))
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 5,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(ThixPolicy.rLg)),
                    child: formation.imageUrl != null &&
                            formation.imageUrl!.isNotEmpty
                        ? Image.network(formation.imageUrl!,
                            fit: BoxFit.cover, width: double.infinity)
                        : Container(
                            width: double.infinity,
                            color: _eduNavyBlue,
                            child: const Icon(Icons.school,
                                color: Colors.white30, size: 40),
                          ),
                  ),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withOpacity(0.35),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 5),
                      decoration: BoxDecoration(
                        color: ThixPolicy.gold.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text('OUVERTURE PROCHAINE',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5)),
                    ),
                  ),
                  Positioned(
                    bottom: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.all(7),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.lock_rounded,
                          color: _eduNavyBlue, size: 15),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 4,
              child: Padding(
                padding: const EdgeInsets.all(ThixPolicy.s12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      formation.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: _eduNavyBlue),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      formation.instructorName ?? 'THIX Academy',
                      style: const TextStyle(
                          color: ThixPolicy.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w700),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    const Row(
                      children: [
                        Icon(Icons.calendar_today_rounded,
                            size: 13, color: _eduAccentBlue),
                        SizedBox(width: 6),
                        Text('Prévu pour : Bientôt',
                            style: TextStyle(
                                fontSize: 11,
                                color: _eduAccentBlue,
                                fontWeight: FontWeight.w700)),
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
}

// ============================================================================
// ONGLET CACHÉ : CATALOGUE
// ============================================================================
class _ExplorePage extends ConsumerWidget {
  const _ExplorePage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final formationsAsync = ref.watch(formationsProvider);
    final categoriesAsync = ref.watch(categoriesProvider);
    final selectedCategory = ref.watch(_selectedCategoryProvider);

    return Scaffold(
      backgroundColor: ThixPolicy.surfaceSoft,
      appBar: AppBar(
        backgroundColor: ThixPolicy.card,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text('Catalogue',
            style: TextStyle(
                color: _eduNavyBlue,
                fontWeight: FontWeight.w900,
                fontSize: 20,
                letterSpacing: -0.5)),
        actions: [
          IconButton(
              icon: const Icon(Icons.search, color: _eduNavyBlue),
              onPressed: () => context.push('/education/search'))
        ],
      ),
      body: Column(
        children: [
          categoriesAsync.when(
            data: (cats) => Container(
              color: ThixPolicy.card,
              padding: const EdgeInsets.only(bottom: ThixPolicy.s16),
              child: SizedBox(
                height: 40,
                child: ListView.separated(
                  padding:
                      const EdgeInsets.symmetric(horizontal: ThixPolicy.s16),
                  scrollDirection: Axis.horizontal,
                  itemCount: cats.length + 1,
                  separatorBuilder: (_, __) =>
                      const SizedBox(width: ThixPolicy.s8),
                  itemBuilder: (_, i) {
                    if (i == 0) {
                      return EducationCategoryChip(
                        label: 'Tous',
                        isSelected: selectedCategory == null,
                        onTap: () {
                          ref.read(_selectedCategoryProvider.notifier).state =
                              null;
                          ref
                              .read(formationsProvider.notifier)
                              .filterByCategory(null);
                        },
                      );
                    }
                    final cat = cats[i - 1];
                    return EducationCategoryChip(
                      label: cat.name,
                      isSelected: selectedCategory == cat.id,
                      onTap: () {
                        ref.read(_selectedCategoryProvider.notifier).state =
                            cat.id;
                        ref
                            .read(formationsProvider.notifier)
                            .filterByCategory(cat.id);
                      },
                    );
                  },
                ),
              ),
            ),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
          Expanded(
            child: formationsAsync.when(
              loading: () => const Center(
                  child: CircularProgressIndicator(color: _eduAccentBlue)),
              error: (_, __) =>
                  const Center(child: Text('Erreur de chargement')),
              data: (paginated) {
                if (paginated.items.isEmpty) {
                  return const Center(
                    child: Text('Aucune formation dans cette catégorie',
                        style: TextStyle(
                            color: ThixPolicy.textSecondary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600)),
                  );
                }
                return GridView.builder(
                  padding: const EdgeInsets.fromLTRB(
                      ThixPolicy.s16, ThixPolicy.s16, ThixPolicy.s16, 120),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.62,
                      crossAxisSpacing: ThixPolicy.s16,
                      mainAxisSpacing: ThixPolicy.s16),
                  itemCount: paginated.items.length,
                  itemBuilder: (_, i) {
                    final f = paginated.items[i];
                    return _FadeInUp(
                      delayMs: (i % 6) * 60,
                      child: _ProFormationCard(
                        formation: f,
                        onTap: () =>
                            context.push('/education/formation/${f.id}'),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// ONGLET 3 : BIBLIOTHÈQUE
// ============================================================================
class _LibraryPage extends ConsumerStatefulWidget {
  const _LibraryPage();

  @override
  ConsumerState<_LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends ConsumerState<_LibraryPage> {
  String _searchQuery = '';
  String? _selectedCategory;

  @override
  Widget build(BuildContext context) {
    final userId = ref.watch(currentUserIdProvider).value;
    if (userId == null) return const Center(child: Text('Non connecté'));

    final booksAsync = ref.watch(myBooksProvider(userId));

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        backgroundColor: _eduNavyBlue,
        elevation: 0,
        title: const Text(
          'Ma Bibliothèque',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 20,
            letterSpacing: -0.5,
          ),
        ),
      ),
      body: Column(
        children: [
          Container(
            color: _eduNavyBlue,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Container(
              height: 46,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: TextField(
                onChanged: (v) => setState(() => _searchQuery = v),
                decoration: const InputDecoration(
                  hintText: 'Rechercher par titre ou auteur...',
                  hintStyle: TextStyle(color: Colors.grey, fontSize: 14),
                  prefixIcon: Icon(Icons.search_rounded, color: Colors.grey),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),
          Expanded(
            child: booksAsync.when(
              loading: () => const Center(
                  child: CircularProgressIndicator(color: _eduAccentBlue)),
              error: (e, _) => Center(child: Text('Erreur: $e')),
              data: (List<Book> allBooks) {
                var books = allBooks.where((b) {
                  final q = _searchQuery.toLowerCase();
                  return b.title.toLowerCase().contains(q) ||
                      b.author.toLowerCase().contains(q);
                }).toList();

                if (_selectedCategory != null) {
                  books = books
                      .where((b) => (b.category ?? '') == _selectedCategory)
                      .toList();
                }

                if (books.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.menu_book_rounded,
                            size: 64, color: Colors.grey.withOpacity(0.5)),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isEmpty
                              ? 'Vos étagères sont vides.'
                              : 'Aucun résultat pour "$_searchQuery"',
                          style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 16,
                              fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  );
                }

                final Map<String, List<Book>> byAuthor = {};
                for (final b in books) {
                  byAuthor.putIfAbsent(b.author, () => []).add(b);
                }

                final categories = allBooks
                    .map((b) => b.category)
                    .whereType<String>()
                    .where((c) => c.isNotEmpty)
                    .toSet()
                    .toList()
                  ..sort();

                return Column(
                  children: [
                    if (categories.isNotEmpty)
                      Container(
                        height: 48,
                        color: Colors.white,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          children: [
                            _CatChip(
                              label: 'Toutes',
                              selected: _selectedCategory == null,
                              onTap: () =>
                                  setState(() => _selectedCategory = null),
                            ),
                            ...categories.map((c) => _CatChip(
                                  label: c,
                                  selected: _selectedCategory == c,
                                  onTap: () =>
                                      setState(() => _selectedCategory = c),
                                )),
                          ],
                        ),
                      ),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.only(bottom: 120, top: 8),
                        itemCount: byAuthor.length,
                        itemBuilder: (context, index) {
                          final author = byAuthor.keys.elementAt(index);
                          final authorBooks = byAuthor[author]!;
                          final shelfCode = authorBooks.first.shelfCode ??
                              _generateShelfCode(author);

                          return _AuthorShelf(
                            author: author,
                            shelfCode: shelfCode,
                            books: authorBooks,
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _generateShelfCode(String author) {
    final hash = author.hashCode.abs().toRadixString(16).toUpperCase();
    final short =
        hash.length >= 4 ? hash.substring(0, 4) : hash.padLeft(4, '0');
    return 'THIX-B-$short';
  }
}

class _CatChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _CatChip(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label, style: const TextStyle(fontSize: 12)),
        selected: selected,
        onSelected: (_) => onTap(),
        selectedColor: _eduAccentBlue.withOpacity(0.2),
        labelStyle: TextStyle(
          color: selected ? _eduAccentBlue : Colors.black87,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _AuthorShelf extends StatelessWidget {
  final String author;
  final String shelfCode;
  final List<Book> books;

  const _AuthorShelf({
    required this.author,
    required this.shelfCode,
    required this.books,
  });

  @override
  Widget build(BuildContext context) {
    final visible = books.take(3).toList();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      author,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                        color: _eduNavyBlue,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Étagère $shelfCode · ${books.length} livre${books.length > 1 ? 's' : ''}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.grey,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () {
                  context.push(
                    '/education/library/author',
                    extra: {
                      'author': author,
                      'shelfCode': shelfCode,
                      'books': books,
                    },
                  );
                },
                child: const Text(
                  'Voir tout',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                    color: _eduAccentBlue,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(3, (i) {
              if (i < visible.length) {
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: _BookSpineCard(book: visible[i]),
                  ),
                );
              }
              return const Expanded(child: SizedBox.shrink());
            }),
          ),
          Container(
            height: 16,
            decoration: BoxDecoration(
              color: _eduShelfWood,
              borderRadius: BorderRadius.circular(4),
              boxShadow: [
                BoxShadow(
                  color: _eduShelfShadow.withOpacity(0.8),
                  offset: const Offset(0, 4),
                  blurRadius: 4,
                ),
              ],
              border: const Border(
                bottom: BorderSide(color: Color(0xFF8A5A35), width: 3),
                top: BorderSide(color: Color(0xFFF3D2B3), width: 1),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BookSpineCard extends StatelessWidget {
  final Book book;
  const _BookSpineCard({required this.book});

  @override
  Widget build(BuildContext context) {
    final isFree = book.price == 0.0;
    final isDeleting = book.scheduledDeletionAt != null &&
        book.scheduledDeletionAt!.isAfter(DateTime.now());

    String countdown = '';
    if (isDeleting) {
      final r = book.scheduledDeletionAt!.difference(DateTime.now());
      final d = r.inDays;
      final h = r.inHours % 24;
      countdown = d > 0 ? '${d}j ${h}h' : '${h}h';
    }

    return _Pressable(
      onTap: () => context.push('/education/book/${book.id}'),
      child: Container(
        height: 170,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(6),
            topRight: Radius.circular(6),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 6,
              offset: const Offset(-4, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 5,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(6),
                      topRight: Radius.circular(6),
                    ),
                    child: book.imageUrl != null && book.imageUrl!.isNotEmpty
                        ? Image.network(book.imageUrl!, fit: BoxFit.cover)
                        : Container(
                            color: _eduNavyBlue,
                            child: const Center(
                              child: Icon(Icons.auto_stories,
                                  color: Colors.white, size: 36),
                            ),
                          ),
                  ),
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 4),
                      decoration: BoxDecoration(
                        color: isFree ? Colors.green.shade600 : _eduAccentBlue,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        isFree
                            ? 'Gratuit'
                            : '${book.price.toStringAsFixed(0)} ${book.currency}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                  if (isDeleting)
                    Positioned(
                      left: 4,
                      right: 4,
                      bottom: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDC2626),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Plus accessible dans $countdown',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              flex: 4,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(
                      left: BorderSide(color: Colors.black12, width: 3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      book.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 11,
                        color: _eduNavyBlue,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      book.author,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 9,
                        color: Colors.grey,
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
}

// ============================================================================
// ONGLET 4 : CERTIFICATS
// ============================================================================
class _CertificatesPage extends ConsumerWidget {
  const _CertificatesPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = ref.watch(currentUserIdProvider).value;
    if (userId == null) return const Center(child: Text('Non connecté'));

    final certsAsync = ref.watch(certificatesProvider(userId));

    return Scaffold(
      backgroundColor: ThixPolicy.surfaceSoft,
      appBar: AppBar(
        backgroundColor: ThixPolicy.card,
        elevation: 0,
        title: const Text('Certifications',
            style: TextStyle(
                color: _eduNavyBlue,
                fontWeight: FontWeight.w900,
                fontSize: 20,
                letterSpacing: -0.5)),
      ),
      body: certsAsync.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: _eduAccentBlue)),
        error: (_, __) => const Center(child: Text('Erreur')),
        data: (certs) {
          if (certs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.workspace_premium_rounded,
                      size: 64, color: ThixPolicy.borderStrong),
                  const SizedBox(height: ThixPolicy.s16),
                  const Text('Aucune certification obtenue',
                      style: TextStyle(
                          color: ThixPolicy.textSecondary,
                          fontSize: 16,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(
                ThixPolicy.s16, ThixPolicy.s16, ThixPolicy.s16, 120),
            itemCount: certs.length,
            itemBuilder: (_, i) {
              final cert = certs[i];
              return _FadeInUp(
                delayMs: i * 70,
                child: Container(
                  margin: const EdgeInsets.only(bottom: ThixPolicy.s16),
                  padding: const EdgeInsets.all(ThixPolicy.s20),
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(ThixPolicy.rLg),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withOpacity(0.03),
                            blurRadius: 10,
                            offset: const Offset(0, 4))
                      ]),
                  child: Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                            gradient: ThixPolicy.goldGradient,
                            borderRadius: BorderRadius.circular(16)),
                        child: const Icon(Icons.workspace_premium_rounded,
                            color: ThixPolicy.inkDeep, size: 30),
                      ),
                      const SizedBox(width: ThixPolicy.s16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Certificat d\'Expertise',
                                style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 15,
                                    color: _eduNavyBlue)),
                            const SizedBox(height: 4),
                            Text(
                                'Délivré le ${cert.issuedAt.day}/${cert.issuedAt.month}/${cert.issuedAt.year}',
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: ThixPolicy.textSecondary,
                                    fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ),
                      IconButton(
                          icon: const Icon(Icons.download_rounded,
                              color: _eduAccentBlue, size: 28),
                          onPressed: () => context.push(
                              '/education/certificate/${cert.id}',
                              extra: cert)),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
