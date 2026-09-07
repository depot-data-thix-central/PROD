// lib/presentation/education/screens/education_home.dart
//
// EducationHome — Production Enterprise (i18n + A11y + Security + Perf)
//
import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ── IMPORTS ABSOLUS SÉCURISÉS ──
import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/l10n/app_localizations.dart';
import 'package:thix_id/presentation/education/models/book.dart';
import 'package:thix_id/presentation/education/models/category.dart';
import 'package:thix_id/presentation/education/models/certificate.dart';
import 'package:thix_id/presentation/education/models/formation.dart';
import 'package:thix_id/presentation/education/providers/book_provider.dart';

// Imports locaux (à migrer vers des absolus si possible)
import '../providers/certificate_provider.dart';
import '../providers/education_provider.dart' hide certificatesProvider;
import '../widgets/common/education_category_chip.dart';
import '../widgets/common/formation_card.dart';

// ============================================================================
// CONSTANTES & THEME LOCAL
// ============================================================================
class _EduTheme {
  static const Color navyBlue = Color(0xFF0F172A);
  static const Color accentBlue = Color(0xFF0284C7);
  static const Color shelfWood = Color(0xFFD4A373);
  static const Color shelfShadow = Color(0xFFB5835A);
}

// ============================================================================
// LOGGING & SECURITY UTILS
// ============================================================================
class _EduLogger {
  static const _tag = 'EducationHub';
  static void info(String m, [Map<String, dynamic>? d]) => _log('INFO', m, d);
  static void error(String m, [Map<String, dynamic>? d]) => _log('ERROR', m, d);
  static void _log(String l, String m, Map<String, dynamic>? d) {
    if (!kDebugMode && l == 'INFO') return;
    final data = d != null ? ' ${d.entries.map((e) => '${e.key}=${e.value}').join(', ')}' : '';
    debugPrint('[$_tag] [$l] $m$data');
  }
}

class _SecurityUtils {
  static String sanitize(String? input) {
    if (input == null) return '';
    return input.replaceAll(RegExp(r'<[^>]*>|&[^;]+;'), '').trim();
  }
}

class _Debouncer {
  final int milliseconds;
  Timer? _timer;
  _Debouncer({required this.milliseconds});
  void run(VoidCallback action) {
    _timer?.cancel();
    _timer = Timer(Duration(milliseconds: milliseconds), action);
  }
  void dispose() => _timer?.cancel();
}

// ============================================================================
// PROVIDERS MIGRÉS VERS RIVERPOD 2.X (Notifier)
// ============================================================================
final eduTabIndexProvider = StateProvider<int>((ref) => 0);
final eduSelectedCategoryProvider = StateProvider<String?>((ref) => null);

final unreadNotificationsProvider = FutureProvider.autoDispose<int>((ref) async {
  final userId = ref.watch(currentUserIdProvider).value;
  if (userId == null) return 0;
  try {
    final res = await Supabase.instance.client
        .from('notifications')
        .select('id')
        .eq('user_id', userId)
        .eq('is_read', false);
    return (res as List).length;
  } catch (e) {
    _EduLogger.error('Notification fetch failed', {'error': '$e'});
    return 0;
  }
});

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
    _ProfilePage(),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedIndex = ref.watch(eduTabIndexProvider);

    return Scaffold(
      backgroundColor: ThixPolicy.surfaceSoft,
      body: Stack(
        children: [
          IndexedStack(
            index: selectedIndex,
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
// BOTTOM NAVIGATION
// ============================================================================
class _FloatingBottomNav extends ConsumerWidget {
  final int selectedIndex;
  const _FloatingBottomNav({required this.selectedIndex});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final items = [
      (Icons.home_rounded, l10n.t('edu_nav_home') ?? 'Accueil'),
      (Icons.play_circle_outline_rounded, l10n.t('edu_nav_learning') ?? 'My Learning'),
      (Icons.local_library_rounded, l10n.t('edu_nav_library') ?? 'Bibliothèque'),
      (Icons.workspace_premium_rounded, l10n.t('edu_nav_certs') ?? 'Certificats'),
      (Icons.person_rounded, l10n.t('edu_nav_profile') ?? 'Profil'),
    ];

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(ThixPolicy.s12, 0, ThixPolicy.s12, ThixPolicy.s12),
        child: Container(
          height: 64,
          decoration: BoxDecoration(
            color: ThixPolicy.card,
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: ThixPolicy.border.withOpacity(0.5)),
            boxShadow: [
              BoxShadow(
                color: _EduTheme.navyBlue.withOpacity(0.08),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(items.length, (i) {
              final isSelected = selectedIndex == i;
              final item = items[i];
              return Semantics(
                button: true,
                selected: isSelected,
                label: item.$2,
                child: InkWell(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    ref.read(eduTabIndexProvider.notifier).state = i;
                  },
                  borderRadius: BorderRadius.circular(24),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          item.$1,
                          color: isSelected ? _EduTheme.accentBlue : ThixPolicy.textSecondary,
                          size: isSelected ? 24 : 22,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.$2,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                            color: isSelected ? _EduTheme.accentBlue : ThixPolicy.textSecondary,
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
    final l10n = AppLocalizations.of(context);
    final userId = ref.watch(currentUserIdProvider).value;

    if (userId == null) {
      return Center(child: Text(l10n.t('edu_auth_required') ?? 'Connectez-vous pour voir vos cours'));
    }

    final enrollAsync = ref.watch(myEnrollmentsProvider(userId));

    return Scaffold(
      backgroundColor: ThixPolicy.surfaceSoft,
      appBar: AppBar(
        backgroundColor: ThixPolicy.card,
        elevation: 0,
        title: Text(
          l10n.t('edu_nav_learning') ?? 'My Learning',
          style: const TextStyle(color: _EduTheme.navyBlue, fontWeight: FontWeight.w900, fontSize: 20),
        ),
      ),
      body: enrollAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: _EduTheme.accentBlue)),
        error: (e, _) => Center(child: Text('${l10n.t('common_error')}: $e')),
        data: (list) {
          if (list.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.school_outlined, size: 64, color: Colors.grey.withOpacity(0.5)),
                  const SizedBox(height: 16),
                  Text(
                    l10n.t('edu_learning_empty_title') ?? 'Aucun cours en cours',
                    style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.grey, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.t('edu_learning_empty_desc') ?? 'Inscrivez-vous à une formation pour commencer.',
                    style: const TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                  const SizedBox(height: 24),
                  Semantics(
                    button: true,
                    child: ElevatedButton(
                      onPressed: () => ref.read(eduTabIndexProvider.notifier).state = 0,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _EduTheme.accentBlue,
                        foregroundColor: Colors.white,
                      ),
                      child: Text(l10n.t('edu_explore_btn') ?? 'Explorer les formations'),
                    ),
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
              final safeTitle = _SecurityUtils.sanitize(f.title);

              return Semantics(
                button: true,
                label: 'Reprendre $safeTitle, $pct % terminé',
                child: InkWell(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    context.push('/education/formation/${f.id}');
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: f.imageUrl != null && f.imageUrl!.isNotEmpty
                              ? Image.network(f.imageUrl!, width: 64, height: 64, fit: BoxFit.cover)
                              : Container(
                                  width: 64, height: 64,
                                  color: _EduTheme.navyBlue,
                                  child: const Icon(Icons.school, color: Colors.white),
                                ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                safeTitle,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: _EduTheme.navyBlue),
                              ),
                              const SizedBox(height: 8),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: e.progress ?? 0,
                                  minHeight: 6,
                                  backgroundColor: Colors.grey.shade200,
                                  color: _EduTheme.accentBlue,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '$pct % ${l10n.t('edu_completed') ?? 'terminé'}',
                                style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded, color: Colors.grey),
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

class _HomePageState extends ConsumerState<_HomePage> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels > _scrollController.position.maxScrollExtent - 300) {
        ref.read(formationsProvider.notifier).loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final user = Supabase.instance.client.auth.currentUser; // Idéalement à migrer vers currentUserProvider
    final unreadAsync = ref.watch(unreadNotificationsProvider);
    final formationsAsync = ref.watch(formationsProvider);
    final categoriesAsync = ref.watch(categoriesProvider);

    final safeName = _SecurityUtils.sanitize(user?.userMetadata?['full_name']?.split(' ')[0] ?? l10n.t('edu_learner') ?? 'Apprenant');

    return RefreshIndicator(
      color: _EduTheme.accentBlue,
      backgroundColor: ThixPolicy.card,
      onRefresh: () async {
        ref.invalidate(formationsProvider);
        ref.invalidate(categoriesProvider);
        if (user != null) ref.invalidate(myEnrollmentsProvider(user.id));
      },
      child: CustomScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        slivers: [
          SliverToBoxAdapter(
            child: Container(
              padding: EdgeInsets.only(
                top: MediaQuery.paddingOf(context).top + ThixPolicy.s12,
                bottom: ThixPolicy.s16,
              ),
              decoration: const BoxDecoration(
                color: ThixPolicy.card,
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(ThixPolicy.rLg)),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s16),
                    child: Row(
                      children: [
                        Semantics(
                          label: l10n.t('edu_user_avatar') ?? 'Avatar utilisateur',
                          child: CircleAvatar(
                            radius: 22,
                            backgroundColor: _EduTheme.navyBlue.withOpacity(0.05),
                            backgroundImage: user?.userMetadata?['avatar_url'] != null
                                ? NetworkImage(user!.userMetadata!['avatar_url'].toString())
                                : null,
                            child: user?.userMetadata?['avatar_url'] == null
                                ? const Icon(Icons.person, color: _EduTheme.navyBlue, size: 22)
                                : null,
                          ),
                        ),
                        const SizedBox(width: ThixPolicy.s12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${l10n.t('common_hello') ?? 'Bonjour'}, $safeName',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _EduTheme.navyBlue),
                              ),
                              Text(
                                l10n.t('edu_ready_to_learn') ?? 'Prêt à développer vos compétences ?',
                                style: const TextStyle(fontSize: 12, color: ThixPolicy.textSecondary, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ),
                        Semantics(
                          button: true,
                          label: l10n.t('edu_notifications') ?? 'Notifications',
                          child: GestureDetector(
                            onTap: () => context.push('/notifications'),
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: ThixPolicy.border)),
                                  child: const Icon(Icons.notifications_none_rounded, color: _EduTheme.navyBlue, size: 20),
                                ),
                                unreadAsync.maybeWhen(
                                  data: (count) => count > 0
                                      ? Positioned(
                                          right: -2, top: -2,
                                          child: Container(
                                            padding: const EdgeInsets.all(4),
                                            decoration: const BoxDecoration(color: ThixPolicy.danger, shape: BoxShape.circle),
                                            child: Text(
                                              '$count',
                                              style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                        )
                                      : const SizedBox.shrink(),
                                  orElse: () => const SizedBox.shrink(),
                                )
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: ThixPolicy.s16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s16),
                    child: Semantics(
                      button: true,
                      label: l10n.t('edu_search_hint') ?? 'Rechercher un programme',
                      child: GestureDetector(
                        onTap: () => context.push('/education/search'),
                        child: Container(
                          height: 48,
                          padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s16),
                          decoration: BoxDecoration(
                            color: ThixPolicy.surface,
                            borderRadius: BorderRadius.circular(ThixPolicy.inputRadius),
                            border: Border.all(color: ThixPolicy.border),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.search_rounded, color: ThixPolicy.textSecondary, size: 22),
                              const SizedBox(width: ThixPolicy.s10),
                              Expanded(
                                child: Text(
                                  l10n.t('edu_search_hint') ?? 'Rechercher un programme, une certification...',
                                  style: const TextStyle(color: ThixPolicy.textSecondary, fontSize: 13, fontWeight: FontWeight.w500),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: ThixPolicy.s16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s16),
                    child: Row(
                      children: [
                        Expanded(
                          child: _QuickIcon(
                            icon: Icons.grid_view_rounded,
                            label: l10n.t('edu_browse') ?? 'Parcourir',
                            onTap: () => ref.read(eduTabIndexProvider.notifier).state = 1,
                          ),
                        ),
                        Expanded(
                          child: _QuickIcon(
                            icon: Icons.local_library_rounded,
                            label: l10n.t('edu_library') ?? 'Bibliothèque',
                            onTap: () => ref.read(eduTabIndexProvider.notifier).state = 2,
                          ),
                        ),
                        Expanded(
                          child: _QuickIcon(
                            icon: Icons.workspace_premium_rounded,
                            label: l10n.t('edu_certs') ?? 'Certificats',
                            onTap: () => ref.read(eduTabIndexProvider.notifier).state = 3,
                          ),
                        ),
                        Expanded(
                          child: _QuickIcon(
                            icon: Icons.co_present_rounded,
                            label: l10n.t('edu_instructor') ?? 'Formateur',
                            onTap: () => context.push('/instructor/dashboard'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: ThixPolicy.s20)),
          
          formationsAsync.when(
            loading: () => const SliverToBoxAdapter(
              child: Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator(color: _EduTheme.accentBlue))),
            ),
            error: (e, __) => SliverToBoxAdapter(
              child: Center(child: Text('${l10n.t('common_error')}: $e')),
            ),
            data: (paginated) {
              final formations = paginated.items;
              final recentFormations = formations.take(5).toList();
              
              // Pré-calcul sécurisé pour les performances
              final topFormations = List.of(formations)..sort((a, b) => b.rating.compareTo(a.rating));
              final awaitedFormations = formations.reversed.take(4).toList();

              return SliverList(
                delegate: SliverChildListDelegate([
                  if (user != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s16),
                      child: _ContinueLearningCard(userId: user.id),
                    ),
                  const SizedBox(height: ThixPolicy.s20),
                  
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s16),
                    child: _HeroCarousel(recentFormations: recentFormations),
                  ),
                  const SizedBox(height: ThixPolicy.s24),

                  // TOP FORMATIONS
                  if (topFormations.isNotEmpty) ...[
                    _SectionHeader(
                      title: l10n.t('edu_top_formations') ?? 'Top des formations',
                      onSeeAll: () => context.push('/education/explore'),
                    ),
                    const SizedBox(height: ThixPolicy.s12),
                    SizedBox(
                      height: 260,
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s16),
                        scrollDirection: Axis.horizontal,
                        itemCount: topFormations.length > 6 ? 6 : topFormations.length,
                        separatorBuilder: (_, __) => const SizedBox(width: ThixPolicy.s16),
                        itemBuilder: (_, i) {
                          final f = topFormations[i];
                          return SizedBox(
                            width: 200,
                            child: FormationCard(
                              formation: f,
                              onTap: () => context.push('/education/formation/${f.id}'),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: ThixPolicy.s24),
                  ],

                  // AWAITED FORMATIONS
                  if (awaitedFormations.isNotEmpty) ...[
                    _SectionHeader(
                      title: l10n.t('edu_awaited_formations') ?? 'Les plus attendus',
                      onSeeAll: () => context.push('/education/explore'),
                    ),
                    const SizedBox(height: ThixPolicy.s12),
                    SizedBox(
                      height: 250,
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s16),
                        scrollDirection: Axis.horizontal,
                        itemCount: awaitedFormations.length > 4 ? 4 : awaitedFormations.length,
                        separatorBuilder: (_, __) => const SizedBox(width: ThixPolicy.s16),
                        itemBuilder: (_, i) {
                          final f = awaitedFormations[i];
                          return SizedBox(width: 220, child: _AwaitedFormationCard(formation: f));
                        },
                      ),
                    ),
                    const SizedBox(height: ThixPolicy.s24),
                  ],

                  // CATEGORIES
                  categoriesAsync.when(
                    data: (dbCats) {
                      final customCats = [
                        Category(id: 'cat-langues', name: 'Langues'),
                        Category(id: 'cat-entrepreneuriat', name: 'Entrepreneuriat'),
                        Category(id: 'cat-dev', name: 'Développement personnel'),
                        Category(id: 'cat-culture', name: 'Culture'),
                      ];

                      final List<Category> allCats = List.from(dbCats);
                      for (var custom in customCats) {
                        if (!allCats.any((c) => c.name.toLowerCase() == custom.name.toLowerCase())) {
                          allCats.add(custom);
                        }
                      }

                      return Column(
                        children: allCats.map((cat) {
                          final catFormations = formations.where((f) {
                            try {
                              if ((f as dynamic).categoryId == cat.id) return true;
                              final fCatName = (f as dynamic).category?.name;
                              if (fCatName != null && fCatName.toLowerCase() == cat.name.toLowerCase()) return true;
                            } catch (_) {}
                            return false;
                          }).toList();

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _SectionHeader(
                                title: cat.name,
                                onSeeAll: () => context.push('/education/explore?category=${cat.id}'),
                              ),
                              const SizedBox(height: ThixPolicy.s12),
                              
                              if (catFormations.isEmpty)
                                Container(
                                  margin: const EdgeInsets.symmetric(horizontal: ThixPolicy.s16),
                                  height: 90,
                                  decoration: BoxDecoration(
                                    color: ThixPolicy.surface,
                                    borderRadius: BorderRadius.circular(ThixPolicy.rLg),
                                    border: Border.all(color: ThixPolicy.border),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    l10n.t('edu_coming_soon_cat') ?? 'Bientôt de nouveaux cours ici',
                                    style: const TextStyle(color: ThixPolicy.textSecondary, fontWeight: FontWeight.w600),
                                  ),
                                )
                              else
                                SizedBox(
                                  height: 260,
                                  child: ListView.separated(
                                    padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s16),
                                    scrollDirection: Axis.horizontal,
                                    itemCount: catFormations.length,
                                    separatorBuilder: (_, __) => const SizedBox(width: ThixPolicy.s16),
                                    itemBuilder: (_, i) {
                                      final f = catFormations[i];
                                      return SizedBox(
                                        width: 200,
                                        child: FormationCard(
                                          formation: f,
                                          onTap: () => context.push('/education/formation/${f.id}'),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              const SizedBox(height: ThixPolicy.s24),
                            ],
                          );
                        }).toList(),
                      );
                    },
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
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

// ----------------------------------------------------------------------------
// WIDGETS
// ----------------------------------------------------------------------------
class _AwaitedFormationCard extends StatelessWidget {
  final dynamic formation; 
  const _AwaitedFormationCard({required this.formation});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final safeTitle = _SecurityUtils.sanitize(formation.title);
    final safeInstructor = _SecurityUtils.sanitize(formation.instructorName ?? 'THIX Academy');

    return Semantics(
      button: true,
      label: 'Cours à venir: $safeTitle par $safeInstructor',
      child: GestureDetector(
        onTap: () {
          HapticFeedback.heavyImpact();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.lock_clock, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.t('edu_locked_course') ?? 'Bientôt disponible ! (Ouverture prévue prochainement)',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              backgroundColor: ThixPolicy.primaryDeep,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
              BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(ThixPolicy.rLg)),
                  child: formation.imageUrl != null && formation.imageUrl!.isNotEmpty
                      ? Image.network(formation.imageUrl!, fit: BoxFit.cover, width: double.infinity)
                      : Container(
                          width: double.infinity,
                          color: _EduTheme.navyBlue,
                          child: const Icon(Icons.school, color: Colors.white30, size: 40),
                        ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(ThixPolicy.s12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      decoration: BoxDecoration(
                        color: ThixPolicy.gold.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        l10n.t('edu_coming_soon_badge') ?? 'OUVERTURE PROCHAINE',
                        style: const TextStyle(color: ThixPolicy.premiumAccent, fontSize: 9, fontWeight: FontWeight.w900),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      safeTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: _EduTheme.navyBlue),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      safeInstructor,
                      style: const TextStyle(color: ThixPolicy.textSecondary, fontSize: 11, fontWeight: FontWeight.w700),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(Icons.calendar_today_rounded, size: 14, color: _EduTheme.accentBlue),
                        const SizedBox(width: 6),
                        Text(
                          l10n.t('edu_scheduled_soon') ?? 'Prévu pour : Bientôt',
                          style: const TextStyle(fontSize: 12, color: _EduTheme.accentBlue, fontWeight: FontWeight.w700),
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
    );
  }
}

class _QuickIcon extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _QuickIcon({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            children: [
              Container(
                width: 46, height: 46,
                decoration: BoxDecoration(color: _EduTheme.accentBlue.withOpacity(0.08), borderRadius: BorderRadius.circular(16)),
                child: Icon(icon, color: _EduTheme.accentBlue, size: 22),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _EduTheme.navyBlue),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onSeeAll;
  const _SectionHeader({required this.title, this.onSeeAll});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _EduTheme.navyBlue, letterSpacing: -0.3)),
          if (onSeeAll != null)
            Semantics(
              button: true,
              label: 'Voir tout pour $title',
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  onSeeAll!();
                },
                child: Text(
                  l10n.t('edu_see_all') ?? 'Voir le catalogue',
                  style: const TextStyle(color: _EduTheme.accentBlue, fontWeight: FontWeight.w700, fontSize: 13),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ContinueLearningCard extends ConsumerWidget {
  final String userId;
  const _ContinueLearningCard({required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final enrollAsync = ref.watch(myEnrollmentsProvider(userId));
    
    return enrollAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (list) {
        final inProgress = list.where((e) => e.formation != null && (e.progress ?? 0) > 0 && (e.progress ?? 0) < 1).toList();
        if (inProgress.isEmpty) return const SizedBox.shrink();

        final current = inProgress.first;
        final f = current.formation!;
        final pct = ((current.progress ?? 0) * 100).round();
        final safeTitle = _SecurityUtils.sanitize(f.title);

        return Semantics(
          button: true,
          label: 'Reprendre le cours $safeTitle',
          child: GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              context.push('/education/formation/${f.id}');
            },
            child: Container(
              padding: const EdgeInsets.all(ThixPolicy.s16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [_EduTheme.navyBlue, Color(0xFF1E293B)]),
                borderRadius: BorderRadius.circular(ThixPolicy.rLg),
                boxShadow: [BoxShadow(color: _EduTheme.navyBlue.withOpacity(0.2), blurRadius: 12, offset: const Offset(0, 6))],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.t('edu_resume_learning') ?? 'REPRENDRE L\'APPRENTISSAGE',
                          style: const TextStyle(color: ThixPolicy.gold, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.8),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          safeTitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold, height: 1.3),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: LinearProgressIndicator(
                                  value: current.progress,
                                  minHeight: 6,
                                  backgroundColor: Colors.white.withOpacity(0.15),
                                  color: ThixPolicy.gold,
                                ),
                              ),
                            ),
                            const SizedBox(width: ThixPolicy.s12),
                            Text('$pct%', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: ThixPolicy.s16),
                  Container(
                    width: 48, height: 48,
                    decoration: const BoxDecoration(color: ThixPolicy.gold, shape: BoxShape.circle),
                    child: const Icon(Icons.play_arrow_rounded, color: _EduTheme.navyBlue, size: 28),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _HeroCarousel extends StatefulWidget {
  final List<Formation> recentFormations;
  const _HeroCarousel({required this.recentFormations});

  @override
  State<_HeroCarousel> createState() => _HeroCarouselState();
}

class _HeroCarouselState extends State<_HeroCarousel> {
  final PageController _controller = PageController();
  int _page = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (widget.recentFormations.length > 1) {
      _timer = Timer.periodic(const Duration(seconds: 4), (Timer timer) {
        if (!mounted) return;
        _page = _page < widget.recentFormations.length - 1 ? _page + 1 : 0;
        if (_controller.hasClients) {
          _controller.animateToPage(_page, duration: const Duration(milliseconds: 600), curve: Curves.fastOutSlowIn);
        }
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
    final l10n = AppLocalizations.of(context);
    if (widget.recentFormations.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        SizedBox(
          height: 180,
          child: PageView.builder(
            controller: _controller,
            itemCount: widget.recentFormations.length,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (_, i) {
              final f = widget.recentFormations[i];
              final safeTitle = _SecurityUtils.sanitize(f.title);
              final safeInstructor = _SecurityUtils.sanitize(f.instructorName ?? 'THIX Academy');

              return Semantics(
                button: true,
                label: 'Ouvrir $safeTitle',
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    context.push('/education/formation/${f.id}');
                  },
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(ThixPolicy.rLg),
                      gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [_EduTheme.navyBlue, _EduTheme.accentBlue]),
                      image: f.imageUrl != null
                          ? DecorationImage(
                              image: NetworkImage(f.imageUrl!),
                              fit: BoxFit.cover,
                              colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.5), BlendMode.darken),
                            )
                          : null,
                      boxShadow: [BoxShadow(color: _EduTheme.navyBlue.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 5))],
                    ),
                    padding: const EdgeInsets.all(ThixPolicy.s24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.white30),
                          ),
                          child: Text(
                            l10n.t('edu_new_program') ?? 'NOUVEAU PROGRAMME',
                            style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.8),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          safeTitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900, height: 1.2, letterSpacing: -0.5),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          safeInstructor,
                          style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ],
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
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: _page == i ? 18 : 8,
                height: 8,
                decoration: BoxDecoration(color: _page == i ? _EduTheme.accentBlue : ThixPolicy.border, borderRadius: BorderRadius.circular(4)),
              ),
            ),
          ),
      ],
    );
  }
}

// ============================================================================
// ONGLET CACHÉ : DÉCOUVRIR (ExplorePage gardé propre)
// ============================================================================
class _ExplorePage extends ConsumerWidget {
  const _ExplorePage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final formationsAsync = ref.watch(formationsProvider);
    final categoriesAsync = ref.watch(categoriesProvider);
    final selectedCategory = ref.watch(eduSelectedCategoryProvider);

    return Scaffold(
      backgroundColor: ThixPolicy.surfaceSoft,
      appBar: AppBar(
        backgroundColor: ThixPolicy.card,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          l10n.t('edu_catalog') ?? 'Catalogue',
          style: const TextStyle(color: _EduTheme.navyBlue, fontWeight: FontWeight.w900, fontSize: 20, letterSpacing: -0.5),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: _EduTheme.navyBlue),
            onPressed: () => context.push('/education/search'),
          )
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
                  padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s16),
                  scrollDirection: Axis.horizontal,
                  itemCount: cats.length + 1,
                  separatorBuilder: (_, __) => const SizedBox(width: ThixPolicy.s8),
                  itemBuilder: (_, i) {
                    if (i == 0) {
                      return EducationCategoryChip(
                        label: l10n.t('common_all') ?? 'Tous',
                        isSelected: selectedCategory == null,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          ref.read(eduSelectedCategoryProvider.notifier).state = null;
                          ref.read(formationsProvider.notifier).filterByCategory(null);
                        },
                      );
                    }
                    final cat = cats[i - 1];
                    return EducationCategoryChip(
                      label: cat.name,
                      isSelected: selectedCategory == cat.id,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        ref.read(eduSelectedCategoryProvider.notifier).state = cat.id;
                        ref.read(formationsProvider.notifier).filterByCategory(cat.id);
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
              loading: () => const Center(child: CircularProgressIndicator(color: _EduTheme.accentBlue)),
              error: (_, __) => Center(child: Text(l10n.t('common_error') ?? 'Erreur de chargement')),
              data: (paginated) {
                if (paginated.items.isEmpty) {
                  return Center(
                    child: Text(
                      l10n.t('edu_no_formations_cat') ?? 'Aucune formation dans cette catégorie',
                      style: const TextStyle(color: ThixPolicy.textSecondary, fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                  );
                }
                return GridView.builder(
                  padding: const EdgeInsets.fromLTRB(ThixPolicy.s16, ThixPolicy.s16, ThixPolicy.s16, 120),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2, childAspectRatio: 0.68, crossAxisSpacing: ThixPolicy.s16, mainAxisSpacing: ThixPolicy.s16,
                  ),
                  itemCount: paginated.items.length,
                  itemBuilder: (_, i) {
                    final f = paginated.items[i];
                    return FormationCard(
                      formation: f,
                      onTap: () => context.push('/education/formation/${f.id}'),
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
// ONGLET 3 : BIBLIOTHÈQUE (Intègre Debouncer)
// ============================================================================
class _LibraryPage extends ConsumerStatefulWidget {
  const _LibraryPage();
  @override
  ConsumerState<_LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends ConsumerState<_LibraryPage> {
  String _searchQuery = '';
  String? _selectedCategory;
  late _Debouncer _debouncer;

  @override
  void initState() {
    super.initState();
    _debouncer = _Debouncer(milliseconds: 400);
  }

  @override
  void dispose() {
    _debouncer.dispose();
    super.dispose();
  }

  void _onSearch(String val) {
    _debouncer.run(() {
      setState(() => _searchQuery = _SecurityUtils.sanitize(val).toLowerCase());
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final userId = ref.watch(currentUserIdProvider).value;
    if (userId == null) return Center(child: Text(l10n.t('edu_auth_required') ?? 'Non connecté'));

    final booksAsync = ref.watch(myBooksProvider(userId));

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        backgroundColor: _EduTheme.navyBlue,
        elevation: 0,
        title: Text(
          l10n.t('edu_my_library') ?? 'Ma Bibliothèque',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 20, letterSpacing: -0.5),
        ),
      ),
      body: Column(
        children: [
          Container(
            color: _EduTheme.navyBlue,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Container(
              height: 46,
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
              child: Semantics(
                textField: true,
                label: l10n.t('edu_search_book_hint') ?? 'Rechercher un livre',
                child: TextField(
                  onChanged: _onSearch,
                  decoration: InputDecoration(
                    hintText: l10n.t('edu_search_book_hint') ?? 'Rechercher par titre ou auteur...',
                    hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
                    prefixIcon: const Icon(Icons.search_rounded, color: Colors.grey),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: booksAsync.when(
              loading: () => const Center(child: CircularProgressIndicator(color: _EduTheme.accentBlue)),
              error: (e, _) => Center(child: Text('${l10n.t('common_error')}: $e')),
              data: (List<Book> allBooks) {
                var books = allBooks.where((b) {
                  return b.title.toLowerCase().contains(_searchQuery) || b.author.toLowerCase().contains(_searchQuery);
                }).toList();

                if (_selectedCategory != null) {
                  books = books.where((b) => (b.category ?? '') == _selectedCategory).toList();
                }

                if (books.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.menu_book_rounded, size: 64, color: Colors.grey.withOpacity(0.5)),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isEmpty
                              ? (l10n.t('edu_library_empty') ?? 'Vos étagères sont vides.')
                              : (l10n.t('edu_no_result') ?? 'Aucun résultat'),
                          style: const TextStyle(color: Colors.grey, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  );
                }

                final Map<String, List<Book>> byAuthor = {};
                for (final b in books) {
                  byAuthor.putIfAbsent(b.author, () => []).add(b);
                }

                final categories = allBooks.map((b) => b.category).whereType<String>().where((c) => c.isNotEmpty).toSet().toList()..sort();

                return Column(
                  children: [
                    if (categories.isNotEmpty)
                      Container(
                        height: 48,
                        color: Colors.white,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          children: [
                            _CatChip(
                              label: l10n.t('common_all') ?? 'Toutes',
                              selected: _selectedCategory == null,
                              onTap: () {
                                HapticFeedback.selectionClick();
                                setState(() => _selectedCategory = null);
                              },
                            ),
                            ...categories.map((c) => _CatChip(
                                  label: c,
                                  selected: _selectedCategory == c,
                                  onTap: () {
                                    HapticFeedback.selectionClick();
                                    setState(() => _selectedCategory = c);
                                  },
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
                          final shelfCode = authorBooks.first.shelfCode ?? _generateShelfCode(author);
                          return _AuthorShelf(author: author, shelfCode: shelfCode, books: authorBooks);
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
    final short = hash.length >= 4 ? hash.substring(0, 4) : hash.padLeft(4, '0');
    return 'THIX-B-$short';
  }
}

class _CatChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _CatChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label, style: const TextStyle(fontSize: 12)),
        selected: selected,
        onSelected: (_) => onTap(),
        selectedColor: _EduTheme.accentBlue.withOpacity(0.2),
        labelStyle: TextStyle(color: selected ? _EduTheme.accentBlue : Colors.black87, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _AuthorShelf extends StatelessWidget {
  final String author;
  final String shelfCode;
  final List<Book> books;
  const _AuthorShelf({required this.author, required this.shelfCode, required this.books});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
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
                      _SecurityUtils.sanitize(author),
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: _EduTheme.navyBlue),
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${l10n.t('edu_shelf') ?? 'Étagère'} $shelfCode · ${books.length} ${l10n.t('edu_books') ?? 'livres'}',
                      style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              Semantics(
                button: true,
                label: 'Voir tous les livres de $author',
                child: TextButton(
                  onPressed: () => context.push('/education/library/author', extra: {'author': author, 'shelfCode': shelfCode, 'books': books}),
                  child: Text(l10n.t('edu_see_all') ?? 'Voir tout', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: _EduTheme.accentBlue)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(3, (i) {
              if (i < visible.length) return Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: _BookSpineCard(book: visible[i])));
              return const Expanded(child: SizedBox.shrink());
            }),
          ),
          Container(
            height: 16,
            decoration: BoxDecoration(
              color: _EduTheme.shelfWood,
              borderRadius: BorderRadius.circular(4),
              boxShadow: [BoxShadow(color: _EduTheme.shelfShadow.withOpacity(0.8), offset: const Offset(0, 4), blurRadius: 4)],
              border: const Border(bottom: BorderSide(color: Color(0xFF8A5A35), width: 3), top: BorderSide(color: Color(0xFFF3D2B3), width: 1)),
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
    final l10n = AppLocalizations.of(context);
    final isFree = book.price == 0.0;
    final isDeleting = book.scheduledDeletionAt != null && book.scheduledDeletionAt!.isAfter(DateTime.now());

    String countdown = '';
    if (isDeleting) {
      final r = book.scheduledDeletionAt!.difference(DateTime.now());
      final d = r.inDays;
      final h = r.inHours % 24;
      countdown = d > 0 ? '${d}j ${h}h' : '${h}h';
    }

    final safeTitle = _SecurityUtils.sanitize(book.title);

    return Semantics(
      button: true,
      label: 'Livre: $safeTitle',
      child: GestureDetector(
        onTap: () {
          if (!_SecurityUtils.isValidUUID(book.id)) {
            _EduLogger.error('Invalid Book ID formatting', {'id': book.id});
            return;
          }
          HapticFeedback.lightImpact();
          context.push('/education/book/${book.id}');
        },
        child: Container(
          height: 170,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 6, offset: const Offset(-4, 2))],
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
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                      child: book.imageUrl != null && book.imageUrl!.isNotEmpty
                          ? Image.network(book.imageUrl!, fit: BoxFit.cover)
                          : Container(color: _EduTheme.navyBlue, child: const Center(child: Icon(Icons.auto_stories, color: Colors.white, size: 36))),
                    ),
                    Positioned(
                      top: 6, right: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        decoration: BoxDecoration(color: isFree ? Colors.green.shade600 : _EduTheme.accentBlue, borderRadius: BorderRadius.circular(4)),
                        child: Text(
                          isFree ? (l10n.t('common_free') ?? 'Gratuit') : '${book.price.toStringAsFixed(0)} ${book.currency}',
                          style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900),
                        ),
                      ),
                    ),
                    if (isDeleting)
                      Positioned(
                        left: 4, right: 4, bottom: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                          decoration: BoxDecoration(color: const Color(0xFFDC2626), borderRadius: BorderRadius.circular(4)),
                          child: Text(
                            '${l10n.t('edu_deleted_in') ?? 'Supprimé dans'} $countdown',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                flex: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: const BoxDecoration(color: Colors.white, border: Border(left: BorderSide(color: Colors.black12, width: 3))),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(safeTitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11, color: _EduTheme.navyBlue, height: 1.1)),
                      const SizedBox(height: 2),
                      Text(_SecurityUtils.sanitize(book.author), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 9, color: Colors.grey)),
                    ],
                  ),
                ),
              ),
            ],
          ),
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
    final l10n = AppLocalizations.of(context);
    final userId = ref.watch(currentUserIdProvider).value;
    if (userId == null) return Center(child: Text(l10n.t('edu_auth_required') ?? 'Non connecté'));

    final certsAsync = ref.watch(certificatesProvider(userId));

    return Scaffold(
      backgroundColor: ThixPolicy.surfaceSoft,
      appBar: AppBar(
        backgroundColor: ThixPolicy.card,
        elevation: 0,
        title: Text(l10n.t('edu_certifications') ?? 'Certifications', style: const TextStyle(color: _EduTheme.navyBlue, fontWeight: FontWeight.w900, fontSize: 20, letterSpacing: -0.5)),
      ),
      body: certsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: _EduTheme.accentBlue)),
        error: (_, __) => Center(child: Text(l10n.t('common_error') ?? 'Erreur')),
        data: (certs) {
          if (certs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.workspace_premium_rounded, size: 64, color: ThixPolicy.borderStrong),
                  const SizedBox(height: ThixPolicy.s16),
                  Text(l10n.t('edu_no_certs') ?? 'Aucune certification obtenue', style: const TextStyle(color: ThixPolicy.textSecondary, fontSize: 16, fontWeight: FontWeight.w600)),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(ThixPolicy.s16, ThixPolicy.s16, ThixPolicy.s16, 120),
            itemCount: certs.length,
            itemBuilder: (_, i) {
              final cert = certs[i];
              return Container(
                margin: const EdgeInsets.only(bottom: ThixPolicy.s16),
                padding: const EdgeInsets.all(ThixPolicy.s20),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(ThixPolicy.rLg),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))]
                ),
                child: Row(
                  children: [
                    Container(
                      width: 56, height: 56,
                      decoration: BoxDecoration(gradient: ThixPolicy.goldGradient, borderRadius: BorderRadius.circular(16)),
                      child: const Icon(Icons.workspace_premium_rounded, color: ThixPolicy.inkDeep, size: 30),
                    ),
                    const SizedBox(width: ThixPolicy.s16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l10n.t('edu_cert_expert') ?? 'Certificat d\'Expertise', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: _EduTheme.navyBlue)),
                          const SizedBox(height: 4),
                          Text('${l10n.t('edu_cert_issued') ?? 'Délivré le'} ${cert.issuedAt.day}/${cert.issuedAt.month}/${cert.issuedAt.year}', style: const TextStyle(fontSize: 12, color: ThixPolicy.textSecondary, fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                    Semantics(
                      button: true,
                      label: 'Télécharger le certificat',
                      child: IconButton(
                        icon: const Icon(Icons.download_rounded, color: _EduTheme.accentBlue, size: 28),
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          context.push('/education/certificate/${cert.id}', extra: cert);
                        }
                      ),
                    ),
                  ],
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
// ONGLET 5 : PROFIL
// ============================================================================
class _ProfilePage extends ConsumerWidget {
  const _ProfilePage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final user = Supabase.instance.client.auth.currentUser;
    final safeName = _SecurityUtils.sanitize(user?.userMetadata?['full_name'] ?? l10n.t('edu_learner') ?? 'Apprenant');

    return Scaffold(
      backgroundColor: ThixPolicy.surfaceSoft,
      appBar: AppBar(
        backgroundColor: ThixPolicy.card,
        elevation: 0,
        title: Text(l10n.t('edu_pro_account') ?? 'Compte Professionnel', style: const TextStyle(color: _EduTheme.navyBlue, fontWeight: FontWeight.w900, fontSize: 20, letterSpacing: -0.5)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(ThixPolicy.s16, ThixPolicy.s16, ThixPolicy.s16, 120),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(ThixPolicy.s20),
              decoration: BoxDecoration(
                color: _EduTheme.navyBlue,
                borderRadius: BorderRadius.circular(ThixPolicy.rLg),
                boxShadow: [BoxShadow(color: _EduTheme.navyBlue.withOpacity(0.2), blurRadius: 15, offset: const Offset(0, 8))]
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 36,
                    backgroundColor: Colors.white24,
                    backgroundImage: user?.userMetadata?['avatar_url'] != null
                        ? NetworkImage(user!.userMetadata!['avatar_url'].toString())
                        : null,
                    child: user?.userMetadata?['avatar_url'] == null
                        ? const Icon(Icons.person, size: 36, color: Colors.white)
                        : null,
                  ),
                  const SizedBox(width: ThixPolicy.s16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(safeName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white)),
                        const SizedBox(height: 4),
                        Text(user?.email ?? '', style: const TextStyle(fontSize: 13, color: Colors.white70)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: ThixPolicy.s24),
            Semantics(
              button: true,
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton.icon(
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    context.push('/instructor/dashboard');
                  },
                  icon: const Icon(Icons.business_center_rounded, size: 22),
                  label: Text(l10n.t('edu_instructor_space') ?? 'Espace Formateur', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _EduTheme.accentBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rMd)),
                    elevation: 0,
                  ),
                ),
              ),
            ),
            const SizedBox(height: ThixPolicy.s32),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(l10n.t('edu_tools') ?? 'Outils Institutionnels', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: _EduTheme.navyBlue.withOpacity(0.7)))
            ),
            const SizedBox(height: ThixPolicy.s12),
            Container(
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(ThixPolicy.rMd), border: Border.all(color: const Color(0xFFE2E8F0))),
              child: Column(
                children: [
                  _ProfileMenuTile(icon: Icons.auto_stories_rounded, label: l10n.t('edu_free_resources') ?? 'Ressources ouvertes', color: Colors.green[600]!, onTap: () => context.push('/education/free-courses')),
                  const Divider(height: 1, color: Color(0xFFE2E8F0), indent: 64),
                  _ProfileMenuTile(icon: Icons.ondemand_video_rounded, label: l10n.t('edu_masterclass') ?? 'Masterclasses', color: Colors.purple[600]!, onTap: () => context.push('/education/webinars')),
                  const Divider(height: 1, color: Color(0xFFE2E8F0), indent: 64),
                  _ProfileMenuTile(icon: Icons.handshake_rounded, label: l10n.t('edu_network') ?? 'Réseau & Mentorat', color: Colors.orange[600]!, onTap: () => context.push('/education/mentorat')),
                  const Divider(height: 1, color: Color(0xFFE2E8F0), indent: 64),
                  _ProfileMenuTile(icon: Icons.event_available_rounded, label: l10n.t('edu_events_agenda') ?? 'Agenda des événements', color: _EduTheme.accentBlue, onTap: () => context.push('/education/events')),
                ],
              ),
            ),
            const SizedBox(height: ThixPolicy.s24),
            Container(
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(ThixPolicy.rMd), border: Border.all(color: const Color(0xFFE2E8F0))),
              child: _ProfileMenuTile(icon: Icons.help_center_rounded, label: l10n.t('edu_support') ?? 'Support Technique', color: Colors.grey[700]!, onTap: () => context.push('/education/help')),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileMenuTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ProfileMenuTile({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: ListTile(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        contentPadding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s20, vertical: 6),
        leading: Container(
          width: 42, height: 42,
          decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: color, size: 22),
        ),
        title: Text(label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: _EduTheme.navyBlue)),
        trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey, size: 24),
      ),
    );
  }
}
