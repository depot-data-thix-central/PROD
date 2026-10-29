// lib/presentation/education/pages/education_my_learning.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/presentation/education/providers/education_provider.dart';
import 'package:thix_id/presentation/education/widgets/formation_detail/formation_module_list.dart';
import '../widgets/common/education_empty_state.dart';
import '../widgets/common/education_loading_shimmer.dart';
import '../models/formation.dart';

// ============================================================================
// CONSTANTES (cohérentes avec le reste du module)
// ============================================================================
const Color _myLearningNavy = Color(0xFF0F172A);
const Color _myLearningAccent = Color(0xFF2D6CDF);
const Color _myLearningGreen = Color(0xFF10B981);
const Color _myLearningOrange = Color(0xFFF59E0B);

enum _LearningFilter { all, inProgress, completed }

// ============================================================================
// PROVIDER LOCAL : Filtre + Recherche
// ============================================================================
final _learningFilterProvider =
    StateProvider<_LearningFilter>((_) => _LearningFilter.all);
final _learningSearchProvider = StateProvider<String>((_) => '');

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
    duration: const Duration(milliseconds: 500),
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
        position: Tween<Offset>(begin: const Offset(0, 0.12), end: Offset.zero)
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
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 130),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

// ============================================================================
// PAGE PRINCIPALE
// ============================================================================
class EducationMyLearning extends ConsumerStatefulWidget {
  const EducationMyLearning({super.key});

  @override
  ConsumerState<EducationMyLearning> createState() =>
      _EducationMyLearningState();
}

class _EducationMyLearningState extends ConsumerState<EducationMyLearning> {
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >
        _scrollController.position.maxScrollExtent - 300) {
      final userId = ref.read(currentUserIdProvider).value;
      if (userId != null) {
        ref.read(myEnrollmentsProvider(userId).notifier).loadMore();
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userId = ref.watch(currentUserIdProvider).value;

    if (userId == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF7FAFF),
        appBar: AppBar(
          title: const Text('Mon apprentissage',
              style: TextStyle(fontWeight: FontWeight.w800)),
          backgroundColor: Colors.white,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: _myLearningAccent.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.login_rounded,
                    color: _myLearningAccent, size: 40),
              ),
              const SizedBox(height: 16),
              const Text(
                'Connectez-vous',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: _myLearningNavy,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'pour accéder à vos formations',
                style: TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final enrollmentsAsync = ref.watch(myEnrollmentsProvider(userId));
    final filter = ref.watch(_learningFilterProvider);
    final searchQuery = ref.watch(_learningSearchProvider).toLowerCase();

    return Scaffold(
      backgroundColor: const Color(0xFFF7FAFF),
      body: enrollmentsAsync.when(
        loading: () => const _MyLearningSkeleton(),
        error: (e, _) => _ErrorState(error: e.toString()),
        data: (enrollments) {
          if (enrollments.isEmpty) {
            return _EmptyLearningState(
              onExplore: () => context.go('/education'),
            );
          }

          // Calcul des stats
          int totalInProgress = 0;
          int totalCompleted = 0;
          int totalLessons = 0;
          int completedLessons = 0;

          for (var enrollment in enrollments) {
            final formation = enrollment.formation;
            if (formation == null) continue;

            final progress = enrollment.progress ?? 0.0;
            if (progress >= 1.0) {
              totalCompleted++;
            } else {
              totalInProgress++;
            }

            if (formation.modules != null) {
              for (var module in formation.modules!) {
                if (module.lessons != null) {
                  totalLessons += module.lessons!.length;
                  completedLessons +=
                      (module.lessons!.length * progress).round();
                }
              }
            }
          }

          // Filtrage
          var filtered = enrollments.where((e) {
            final formation = e.formation;
            if (formation == null) return false;

            // Filtre par recherche
            if (searchQuery.isNotEmpty) {
              final title = formation.title.toLowerCase();
              final instructor =
                  (formation.instructorName ?? '').toLowerCase();
              if (!title.contains(searchQuery) &&
                  !instructor.contains(searchQuery)) {
                return false;
              }
            }

            // Filtre par statut
            final progress = e.progress ?? 0.0;
            if (filter == _LearningFilter.inProgress && progress >= 1.0) {
              return false;
            }
            if (filter == _LearningFilter.completed && progress < 1.0) {
              return false;
            }

            return true;
          }).toList();

          // Tri : en cours d'abord, puis terminés
          filtered.sort((a, b) {
            final pa = a.progress ?? 0.0;
            final pb = b.progress ?? 0.0;
            if (pa >= 1.0 && pb < 1.0) return 1;
            if (pa < 1.0 && pb >= 1.0) return -1;
            return pb.compareTo(pa);
          });

          return RefreshIndicator(
            onRefresh: () async {
              HapticFeedback.mediumImpact();
              ref.invalidate(myEnrollmentsProvider(userId));
              ref.invalidate(completedLessonsProvider);
            },
            color: _myLearningAccent,
            child: CustomScrollView(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              slivers: [
                // ============ HEADER ============
                SliverToBoxAdapter(
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [_myLearningNavy, Color(0xFF1E293B)],
                      ),
                    ),
                    child: SafeArea(
                      bottom: false,
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          20,
                          16,
                          20,
                          24,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Barre du haut
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(Icons.arrow_back_rounded,
                                      color: Colors.white, size: 20),
                                ).onTap(() => Navigator.pop(context)),
                                const SizedBox(width: 16),
                                const Expanded(
                                  child: Text(
                                    'Mon apprentissage',
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                      letterSpacing: -0.3,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                      Icons.tune_rounded,
                                      color: Colors.white,
                                      size: 20),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),

                            // Titre de bienvenue
                            const Text(
                              'Vos formations 📚',
                              style: TextStyle(
                                fontSize: 15,
                                color: Colors.white70,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Stats cards
                            Row(
                              children: [
                                Expanded(
                                  child: _StatCard(
                                    icon: Icons.play_circle_fill_rounded,
                                    value: '$totalInProgress',
                                    label: 'En cours',
                                    color: _myLearningAccent,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _StatCard(
                                    icon: Icons.verified_rounded,
                                    value: '$totalCompleted',
                                    label: 'Terminées',
                                    color: _myLearningGreen,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _StatCard(
                                    icon: Icons.menu_book_rounded,
                                    value: '$completedLessons',
                                    label: 'Leçons',
                                    color: _myLearningOrange,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // ============ RECHERCHE ============
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                    child: Container(
                      height: 52,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.03),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _searchController,
                        onChanged: (v) =>
                            ref.read(_learningSearchProvider.notifier).state = v,
                        decoration: const InputDecoration(
                          hintText: 'Rechercher une formation...',
                          hintStyle: TextStyle(
                              color: Color(0xFF94A3B8), fontSize: 14),
                          prefixIcon: Icon(Icons.search_rounded,
                              color: Color(0xFF94A3B8)),
                          suffixIcon: Icon(Icons.tune_rounded,
                              color: Color(0xFF94A3B8)),
                          border: InputBorder.none,
                          contentPadding:
                              EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ),
                ),

                // ============ FILTRES ============
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 44,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: [
                        _FilterChip(
                          label: 'Tous',
                          count: enrollments.length,
                          selected: filter == _LearningFilter.all,
                          onTap: () => ref
                              .read(_learningFilterProvider.notifier)
                              .state = _LearningFilter.all,
                        ),
                        const SizedBox(width: 8),
                        _FilterChip(
                          label: 'En cours',
                          count: totalInProgress,
                          selected: filter == _LearningFilter.inProgress,
                          onTap: () => ref
                              .read(_learningFilterProvider.notifier)
                              .state = _LearningFilter.inProgress,
                        ),
                        const SizedBox(width: 8),
                        _FilterChip(
                          label: 'Terminés',
                          count: totalCompleted,
                          selected: filter == _LearningFilter.completed,
                          onTap: () => ref
                              .read(_learningFilterProvider.notifier)
                              .state = _LearningFilter.completed,
                        ),
                      ],
                    ),
                  ),
                ),

                // ============ COMPTEUR DE RÉSULTATS ============
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                    child: Row(
                      children: [
                        Text(
                          '${filtered.length} formation${filtered.length > 1 ? 's' : ''}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        const Spacer(),
                        const Icon(Icons.sort_rounded,
                            size: 16, color: Color(0xFF94A3B8)),
                        const SizedBox(width: 4),
                        const Text(
                          'Plus récentes',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF94A3B8),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // ============ LISTE DES FORMATIONS ============
                if (filtered.isEmpty)
                  SliverToBoxAdapter(
                    child: _NoResultsState(
                      filter: filter,
                      searchQuery: searchQuery,
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          if (index >= filtered.length) {
                            final hasMore = ref
                                .read(myEnrollmentsProvider(userId).notifier)
                                .hasMore;
                            return hasMore
                                ? const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 20),
                                    child: Center(
                                      child: SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                          color: _myLearningAccent,
                                          strokeWidth: 2.5,
                                        ),
                                      ),
                                    ),
                                  )
                                : const SizedBox(height: 32);
                          }

                          final enrollment = filtered[index];
                          final formation = enrollment.formation;
                          if (formation == null) return const SizedBox.shrink();

                          return _FadeInUp(
                            delayMs: index * 60,
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 14),
                              child: _ProEnrollmentCard(
                                formation: formation,
                                fallbackProgress:
                                    enrollment.progress?.toDouble(),
                                onTap: () => context.push(
                                    '/education/formation/${formation.id}'),
                              ),
                            ),
                          );
                        },
                        childCount: filtered.length + 1,
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// Extension pour onTap sur Widget
extension _WidgetTapExtension on Widget {
  Widget onTap(VoidCallback onTap) {
    return GestureDetector(onTap: onTap, child: this);
  }
}

// ============================================================================
// CARTE STATISTIQUE (header)
// ============================================================================
class _StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.white.withOpacity(0.6),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// CHIP DE FILTRE
// ============================================================================
class _FilterChip extends StatelessWidget {
  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _Pressable(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? _myLearningAccent : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: selected ? _myLearningAccent : const Color(0xFFE2E8F0),
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: _myLearningAccent.withOpacity(0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : const Color(0xFF475569),
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: selected
                    ? Colors.white.withOpacity(0.2)
                    : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: selected ? Colors.white : const Color(0xFF64748B),
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
// CARTE PRO ENROLLMENT (niveau THIX Market)
// ============================================================================
class _ProEnrollmentCard extends ConsumerWidget {
  final Formation formation;
  final double? fallbackProgress;
  final VoidCallback onTap;

  const _ProEnrollmentCard({
    required this.formation,
    required this.fallbackProgress,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final completedLessonsAsync = ref.watch(completedLessonsProvider);

    double calculatedProgress = fallbackProgress ?? 0.0;
    int totalLessons = 0;
    int completedCount = 0;

    completedLessonsAsync.whenData((completedIds) {
      if (formation.modules != null) {
        for (var module in formation.modules!) {
          if (module.lessons != null) {
            for (var lesson in module.lessons!) {
              totalLessons++;
              if (completedIds.contains(lesson.id)) {
                completedCount++;
              }
            }
          }
        }
      }

      if (totalLessons > 0) {
        calculatedProgress = completedCount / totalLessons;
      }
    });

    final p = calculatedProgress.clamp(0.0, 1.0);
    final percentage = (p * 100).toInt();
    final isCompleted = p >= 1.0;
    final remaining = totalLessons - completedCount;

    // Calcul de la durée totale
    final totalMinutes = formation.modules?.fold<int>(
          0,
          (sum, m) =>
              sum +
              (m.lessons?.fold<int>(
                      0, (s, l) => s + (l.durationMinutes ?? 0)) ??
                  0),
        ) ??
        0;
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;
    final durationLabel = hours > 0 ? '${hours}h ${minutes}min' : '${minutes}min';

    return _Pressable(
      onTap: onTap,
      child: Container(
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ========== IMAGE + OVERLAYS ==========
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20)),
              child: Stack(
                children: [
                  // Image
                  formation.imageUrl != null &&
                          formation.imageUrl!.isNotEmpty
                      ? Image.network(
                          formation.imageUrl!,
                          width: double.infinity,
                          height: 140,
                          fit: BoxFit.cover,
                        )
                      : Container(
                          width: double.infinity,
                          height: 140,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                _myLearningNavy,
                                _myLearningAccent.withOpacity(0.7),
                              ],
                            ),
                          ),
                          child: const Icon(Icons.school_rounded,
                              color: Colors.white, size: 48),
                        ),

                  // Gradient overlay
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withOpacity(0.6),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Badge statut (haut gauche)
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: isCompleted
                            ? _myLearningGreen
                            : _myLearningAccent,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: (isCompleted
                                    ? _myLearningGreen
                                    : _myLearningAccent)
                                .withOpacity(0.4),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isCompleted
                                ? Icons.verified_rounded
                                : Icons.play_circle_fill_rounded,
                            color: Colors.white,
                            size: 13,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isCompleted ? 'Terminé' : 'En cours',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Durée (haut droit)
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.black45,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.timer_rounded,
                              color: Colors.white, size: 12),
                          const SizedBox(width: 4),
                          Text(
                            durationLabel,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Titre + instructeur (bas)
                  Positioned(
                    left: 14,
                    right: 14,
                    bottom: 12,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          formation.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            height: 1.2,
                            letterSpacing: -0.2,
                          ),
                        ),
                        if (formation.instructorName != null) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 10,
                                backgroundColor:
                                    Colors.white.withOpacity(0.2),
                                child: const Icon(Icons.person,
                                    size: 11, color: Colors.white),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  formation.instructorName!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.white70,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ========== BARRE DE PROGRESSION ==========
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            isCompleted
                                ? Icons.celebration_rounded
                                : Icons.school_rounded,
                            size: 14,
                            color: isCompleted
                                ? _myLearningGreen
                                : const Color(0xFF64748B),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            isCompleted
                                ? 'Formation complétée'
                                : '$completedCount / $totalLessons leçons',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: isCompleted
                                  ? _myLearningGreen
                                  : const Color(0xFF475569),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        '$percentage%',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: isCompleted
                              ? _myLearningGreen
                              : _myLearningAccent,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: p,
                      backgroundColor: const Color(0xFFF1F5F9),
                      color: isCompleted
                          ? _myLearningGreen
                          : _myLearningAccent,
                      minHeight: 8,
                    ),
                  ),
                ],
              ),
            ),

            // ========== BOUTON D'ACTION ==========
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton.icon(
                  onPressed: onTap,
                  icon: Icon(
                    isCompleted
                        ? Icons.replay_rounded
                        : Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                  label: Text(
                    isCompleted ? 'Revoir la formation' : 'Continuer',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        isCompleted ? _myLearningGreen : _myLearningAccent,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
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
// ÉTAT VIDE : AUCUNE FORMATION
// ============================================================================
class _EmptyLearningState extends StatelessWidget {
  final VoidCallback onExplore;
  const _EmptyLearningState({required this.onExplore});

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [_myLearningNavy, Color(0xFF1E293B)],
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.arrow_back_rounded,
                          color: Colors.white, size: 20),
                    ).onTap(() => Navigator.pop(context)),
                  ],
                ),
              ),
            ),
          ),
        ),
        SliverFillRemaining(
          hasScrollBody: false,
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: _myLearningAccent.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.school_outlined,
                      size: 64, color: _myLearningAccent),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Commencez votre parcours',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: _myLearningNavy,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Inscrivez-vous à votre première formation pour commencer à apprendre et obtenir des certifications.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF64748B),
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                _Pressable(
                  onTap: onExplore,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 28, vertical: 16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [_myLearningNavy, Color(0xFF1E293B)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: _myLearningNavy.withOpacity(0.3),
                          blurRadius: 16,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.explore_rounded,
                            color: Colors.white, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Explorer les formations',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// ÉTAT : AUCUN RÉSULTAT (filtre ou recherche)
// ============================================================================
class _NoResultsState extends StatelessWidget {
  final _LearningFilter filter;
  final String searchQuery;

  const _NoResultsState({
    required this.filter,
    required this.searchQuery,
  });

  @override
  Widget build(BuildContext context) {
    final hasSearch = searchQuery.isNotEmpty;
    final isCompleted = filter == _LearningFilter.completed;
    final isInProgress = filter == _LearningFilter.inProgress;

    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 48, 32, 120),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: (isCompleted ? _myLearningGreen : _myLearningAccent)
                  .withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              hasSearch
                  ? Icons.search_off_rounded
                  : isCompleted
                      ? Icons.celebration_rounded
                      : isInProgress
                          ? Icons.play_circle_outline_rounded
                          : Icons.school_outlined,
              size: 48,
              color: isCompleted ? _myLearningGreen : _myLearningAccent,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            hasSearch
                ? 'Aucun résultat'
                : isCompleted
                    ? 'Aucune formation terminée'
                    : isInProgress
                        ? 'Aucune formation en cours'
                        : 'Aucune formation',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: _myLearningNavy,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            hasSearch
                ? 'Aucune formation ne correspond à "$searchQuery"'
                : isCompleted
                    ? 'Terminez une formation pour la voir ici.'
                    : isInProgress
                        ? 'Commencez une formation pour la voir ici.'
                        : 'Inscrivez-vous à une formation.',
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF64748B),
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// ÉTAT D'ERREUR
// ============================================================================
class _ErrorState extends StatelessWidget {
  final String error;
  const _ErrorState({required this.error});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.cloud_off_rounded,
                  size: 48, color: Color(0xFFEF4444)),
            ),
            const SizedBox(height: 20),
            const Text(
              'Erreur de chargement',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: _myLearningNavy,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF64748B),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Réessayer'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _myLearningAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
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
// SKELETON LOADING
// ============================================================================
class _MyLearningSkeleton extends StatelessWidget {
  const _MyLearningSkeleton();

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      physics: const NeverScrollableScrollPhysics(),
      slivers: [
        // Header skeleton
        SliverToBoxAdapter(
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [_myLearningNavy, Color(0xFF1E293B)],
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _SkeletonBox(width: 40, height: 40, radius: 12),
                    const SizedBox(height: 24),
                    const _SkeletonBox(width: 150, height: 18),
                    const SizedBox(height: 16),
                    Row(
                      children: List.generate(
                        3,
                        (_) => const Expanded(
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 6),
                            child: _SkeletonBox(height: 90, radius: 14),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        // Search skeleton
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: _SkeletonBox(height: 52, radius: 16),
          ),
        ),
        // Filter chips skeleton
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: List.generate(
                3,
                (_) => const Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: _SkeletonBox(width: 100, height: 36, radius: 18),
                ),
              ),
            ),
          ),
        ),
        // Cards skeleton
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => const Padding(
                padding: EdgeInsets.only(bottom: 14),
                child: _SkeletonBox(height: 280, radius: 20),
              ),
              childCount: 3,
            ),
          ),
        ),
      ],
    );
  }
}

class _SkeletonBox extends StatefulWidget {
  final double width;
  final double height;
  final double radius;
  const _SkeletonBox({
    this.width = double.infinity,
    required this.height,
    this.radius = 8,
  });

  @override
  State<_SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<_SkeletonBox>
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
      opacity: Tween<double>(begin: 0.5, end: 1.0).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
      ),
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(widget.radius),
        ),
      ),
    );
  }
}
