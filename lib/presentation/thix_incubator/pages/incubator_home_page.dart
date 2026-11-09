// ============================================================================
// FICHIER : lib/presentation/thix_incubator/pages/incubator_home_page.dart
// Module  : thix_incubator
// Route   : /incubator
//
// Homepage INCUBATOR — design inspiré de la maquette fournie.
// Toutes les données métier proviennent d'IncubatorProvider / Supabase.
// Aucun compteur, programme, projet ou statut métier n'est simulé.
//
// Dépendances attendues (déjà utilisées dans le projet initial) :
// - IncubatorProvider
// - IncubatorProgram, IncubatorProject, IncubatorActivity
// - AppRoutes
// - provider, go_router, shimmer
// ============================================================================

import 'dart:async';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';

import '../../../nav.dart';
import '../../../providers/incubator_provider.dart';
import '../../../models/incubator_program.dart';
import '../../../models/incubator_project.dart';
import '../../../models/incubator_activity.dart';

// ============================================================================
// COULEURS
// ============================================================================
@immutable
class IncubatorColors {
  const IncubatorColors._();

  static const Color institutionalBlue = Color(0xFF092C78);
  static const Color nightBlue = Color(0xFF061B4D);
  static const Color electricBlue = Color(0xFF1455D9);
  static const Color premiumGold = Color(0xFFFFC107);
  static const Color validationGreen = Color(0xFF16A34A);

  static const Color lightSurface = Color(0xFFF1F5FD);
  static const Color lightBackground = Color(0xFFFFFFFF);
  static const Color darkSurface = Color(0xFF111C30);
  static const Color darkBackground = Color(0xFF07101F);

  static const Color textPrimaryLight = Color(0xFF10234D);
  static const Color textSecondaryLight = Color(0xFF64748B);
  static const Color textPrimaryDark = Color(0xFFEAF2FF);
  static const Color textSecondaryDark = Color(0xFFA5B4CC);

  static const Color danger = Color(0xFFDC2626);
  static const Color warning = Color(0xFFF59E0B);
  static const Color info = Color(0xFF0EA5E9);
  static const Color purple = Color(0xFF9333EA);

  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color surface(BuildContext context) =>
      isDark(context) ? darkSurface : lightSurface;

  static Color background(BuildContext context) =>
      isDark(context) ? darkBackground : lightBackground;

  static Color card(BuildContext context) =>
      isDark(context) ? const Color(0xFF142139) : Colors.white;

  static Color textPrimary(BuildContext context) =>
      isDark(context) ? textPrimaryDark : textPrimaryLight;

  static Color textSecondary(BuildContext context) =>
      isDark(context) ? textSecondaryDark : textSecondaryLight;

  static Color border(BuildContext context) =>
      isDark(context) ? const Color(0xFF263650) : const Color(0xFFDCE5F3);
}

// ============================================================================
// PAGE
// ============================================================================
class IncubatorHomePage extends StatefulWidget {
  const IncubatorHomePage({super.key});

  @override
  State<IncubatorHomePage> createState() => _IncubatorHomePageState();
}

class _IncubatorHomePageState extends State<IncubatorHomePage>
    with SingleTickerProviderStateMixin {
  StreamSubscription<void>? _realtimeSub;
  late final AnimationController _refreshController;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _refreshController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = context.read<IncubatorProvider>();

      if (provider.state == IncubatorState.idle) {
        provider.loadAll();
      }

      _realtimeSub = provider.realtimeUpdates().listen((_) {
        if (mounted) setState(() {});
      });
    });
  }

  @override
  void dispose() {
    _realtimeSub?.cancel();
    _refreshController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    if (_isRefreshing) return;
    _isRefreshing = true;
    _refreshController.repeat();

    try {
      await context.read<IncubatorProvider>().loadAll(forceRefresh: true);
    } finally {
      if (mounted) {
        _refreshController
          ..stop()
          ..reset();
        _isRefreshing = false;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: IncubatorColors.background(context),
      body: SafeArea(
        bottom: false,
        child: Consumer<IncubatorProvider>(
          builder: (context, provider, _) {
            if (provider.state == IncubatorState.loading &&
                provider.isFirstLoad) {
              return const _SkeletonBody();
            }

            if (provider.state == IncubatorState.error &&
                provider.isEmpty) {
              return _ErrorState(
                message: provider.error ?? 'Erreur de connexion',
                onRetry: provider.loadAll,
              );
            }

            // Le tableau de bord reste visible même si l'utilisateur
            // n'a encore aucun projet ou aucune candidature.
            return RefreshIndicator(
              color: IncubatorColors.electricBlue,
              onRefresh: _refresh,
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                slivers: [
                  _HeaderSliver(refreshController: _refreshController),
                  const _HeroSliver(),
                  const _ProgressSliver(),
                  const _ProgramsSliver(),
                  const _QuickAccessSliver(),
                  const _ApplicationsSliver(),
                  const _ProjectsSliver(),
                  const _ActivitySliver(),
                  const _JourneySliver(),
                  const _ClosingBannerSliver(),
                  const SliverToBoxAdapter(
                    child: SizedBox(height: 105),
                  ),
                ],
              ),
            );
          },
        ),
      ),
      bottomNavigationBar: const _IncubatorBottomNavigation(currentIndex: 0),
    );
  }
}

// ============================================================================
// HEADER — double bandeau inspiré de la capture
// ============================================================================
class _HeaderSliver extends StatelessWidget {
  const _HeaderSliver({required this.refreshController});

  final AnimationController refreshController;

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 9, 12, 11),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  IncubatorColors.nightBlue,
                  IncubatorColors.institutionalBlue,
                ],
              ),
            ),
            child: Consumer<IncubatorProvider>(
              builder: (context, provider, _) {
                return Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: .18),
                        ),
                      ),
                      child: const Icon(
                        Icons.rocket_launch_rounded,
                        color: IncubatorColors.premiumGold,
                        size: 23,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'INCUBATOR',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              letterSpacing: .5,
                            ),
                          ),
                          Text(
                            'Innover • Entreprendre • Grandir',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (refreshController.isAnimating)
                      RotationTransition(
                        turns: refreshController,
                        child: const Icon(
                          Icons.refresh_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    _HeaderAction(
                      icon: Icons.search_rounded,
                      onTap: () => context.go('${AppRoutes.incubator}/search'),
                    ),
                    _HeaderAction(
                      icon: Icons.notifications_none_rounded,
                      badge: provider.unreadNotifications,
                      onTap: () =>
                          context.go(AppRoutes.networkNotifications),
                    ),
                    InkWell(
                      onTap: () => context.go(AppRoutes.profile),
                      borderRadius: BorderRadius.circular(30),
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: CircleAvatar(
                          radius: 17,
                          backgroundColor: Colors.white,
                          child: Icon(
                            Icons.person_rounded,
                            color: IncubatorColors.institutionalBlue,
                            size: 21,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          Container(
            height: 59,
            padding: const EdgeInsets.symmetric(horizontal: 15),
            decoration: BoxDecoration(
              color: IncubatorColors.card(context),
              border: Border(
                bottom: BorderSide(color: IncubatorColors.border(context)),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.menu_rounded,
                  color: IncubatorColors.textPrimary(context),
                  size: 25,
                ),
                const SizedBox(width: 15),
                Container(
                  width: 1,
                  height: 30,
                  color: IncubatorColors.border(context),
                ),
                const SizedBox(width: 13),
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: IncubatorColors.premiumGold.withValues(alpha: .15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.emoji_events_rounded,
                    color: IncubatorColors.institutionalBlue,
                    size: 23,
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'INCUBATOR',
                        style: TextStyle(
                          color: IncubatorColors.textPrimary(context),
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        'by SONATHIX GROUP',
                        style: TextStyle(
                          color: IncubatorColors.textSecondary(context),
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: IncubatorColors.validationGreen.withValues(
                      alpha: .10,
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.verified_user_rounded,
                        color: IncubatorColors.validationGreen,
                        size: 15,
                      ),
                      SizedBox(width: 5),
                      Text(
                        'Espace Entrepreneur',
                        style: TextStyle(
                          color: IncubatorColors.validationGreen,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 7),
                Icon(
                  Icons.more_vert_rounded,
                  color: IncubatorColors.textPrimary(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderAction extends StatelessWidget {
  const _HeaderAction({
    required this.icon,
    required this.onTap,
    this.badge = 0,
  });

  final IconData icon;
  final VoidCallback onTap;
  final int badge;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          onPressed: onTap,
          visualDensity: VisualDensity.compact,
          icon: Icon(icon, color: Colors.white, size: 23),
        ),
        if (badge > 0)
          Positioned(
            right: 3,
            top: 2,
            child: Container(
              constraints: const BoxConstraints(
                minWidth: 16,
                minHeight: 16,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: IncubatorColors.danger,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white, width: 1),
              ),
              child: Text(
                badge > 99 ? '99+' : '$badge',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ============================================================================
// HERO — visuel réel du programme si disponible, sinon fond graphique
// ============================================================================
class _HeroSliver extends StatelessWidget {
  const _HeroSliver();

  @override
  Widget build(BuildContext context) {
    return Consumer<IncubatorProvider>(
      builder: (context, provider, _) {
        final programs = provider.openPrograms;
        final String? cover =
            programs.isNotEmpty ? programs.first.coverUrl : null;

        return SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(0, 0, 0, 16),
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(23),
              ),
              child: SizedBox(
                height: 310,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (cover != null && cover.trim().isNotEmpty)
                      Image.network(
                        cover,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            const _HeroFallbackBackground(),
                      )
                    else
                      const _HeroFallbackBackground(),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            IncubatorColors.nightBlue.withValues(alpha: .98),
                            IncubatorColors.institutionalBlue.withValues(
                              alpha: .83,
                            ),
                            IncubatorColors.institutionalBlue.withValues(
                              alpha: .12,
                            ),
                          ],
                          stops: const [0, .65, 1],
                        ),
                      ),
                    ),
                    Positioned(
                      right: -20,
                      bottom: -30,
                      child: Icon(
                        Icons.rocket_launch_rounded,
                        size: 190,
                        color: Colors.white.withValues(alpha: .08),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(23, 24, 22, 23),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: IncubatorColors.premiumGold.withValues(
                                alpha: .15,
                              ),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: IncubatorColors.premiumGold.withValues(
                                  alpha: .65,
                                ),
                              ),
                            ),
                            child: const Text(
                              "L’INNOVATION POUR L’AFRIQUE",
                              style: TextStyle(
                                color: IncubatorColors.premiumGold,
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                letterSpacing: .7,
                              ),
                            ),
                          ),
                          const SizedBox(height: 17),
                          const Text(
                            'Transformez\nvotre idée en',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 27,
                              height: 1.12,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const Text(
                            'entreprise.',
                            style: TextStyle(
                              color: IncubatorColors.premiumGold,
                              fontSize: 30,
                              fontWeight: FontWeight.w900,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 10),
                          const SizedBox(
                            width: 275,
                            child: Text(
                              'Découvrez les programmes, développez '
                              'vos projets et accédez aux opportunités '
                              'qui feront grandir votre ambition.',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                height: 1.45,
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          ElevatedButton.icon(
                            onPressed: () => context.go(
                              AppRoutes.incubatorExplore,
                            ),
                            icon: const Icon(
                              Icons.rocket_launch_rounded,
                              size: 16,
                            ),
                            label: const Text(
                              'Explorer les programmes',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: IncubatorColors.premiumGold,
                              foregroundColor: IncubatorColors.nightBlue,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 13,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
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
    );
  }
}

class _HeroFallbackBackground extends StatelessWidget {
  const _HeroFallbackBackground();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            IncubatorColors.nightBlue,
            IncubatorColors.institutionalBlue,
            IncubatorColors.electricBlue,
          ],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.rocket_launch_rounded,
          size: 145,
          color: Color(0x22FFFFFF),
        ),
      ),
    );
  }
}

// ============================================================================
// SECTION HEADER
// ============================================================================
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 21,
            decoration: BoxDecoration(
              color: IncubatorColors.electricBlue,
              borderRadius: BorderRadius.circular(5),
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: IncubatorColors.textPrimary(context),
                fontSize: 16,
                fontWeight: FontWeight.w900,
                letterSpacing: -.25,
              ),
            ),
          ),
          if (actionLabel != null && onAction != null)
            InkWell(
              onTap: onAction,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 4,
                  vertical: 6,
                ),
                child: Row(
                  children: [
                    Text(
                      actionLabel!,
                      style: const TextStyle(
                        color: IncubatorColors.electricBlue,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 3),
                    const Icon(
                      Icons.arrow_forward_rounded,
                      size: 16,
                      color: IncubatorColors.electricBlue,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ============================================================================
// PROGRESSION — données réelles du provider
// ============================================================================
class _ProgressSliver extends StatelessWidget {
  const _ProgressSliver();

  @override
  Widget build(BuildContext context) {
    return Consumer<IncubatorProvider>(
      builder: (context, provider, _) {
        return SliverToBoxAdapter(
          child: Container(
            margin: const EdgeInsets.fromLTRB(14, 0, 14, 22),
            padding: const EdgeInsets.fromLTRB(10, 14, 10, 14),
            decoration: BoxDecoration(
              color: IncubatorColors.surface(context),
              borderRadius: BorderRadius.circular(19),
              border: Border.all(color: IncubatorColors.border(context)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 5),
                  child: Text(
                    'Mon espace de progression',
                    style: TextStyle(
                      color: IncubatorColors.textPrimary(context),
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(height: 17),
                Row(
                  children: [
                    Expanded(
                      child: _ProgressMetric(
                        icon: Icons.folder_rounded,
                        value: '${provider.myProjectsCount}',
                        label: 'Mes projets',
                        color: IncubatorColors.electricBlue,
                      ),
                    ),
                    _MetricDivider(),
                    Expanded(
                      child: _ProgressMetric(
                        icon: Icons.assignment_turned_in_rounded,
                        value: '${provider.myApplicationsCount}',
                        label: 'Candidatures',
                        color: IncubatorColors.validationGreen,
                      ),
                    ),
                    _MetricDivider(),
                    Expanded(
                      child: _ProgressMetric(
                        icon: Icons.mic_rounded,
                        // Le modèle/provider initial ne fournit pas encore
                        // de compteur de pitchs : ne pas afficher de faux 0.
                        value: '—',
                        label: 'Pitchs',
                        color: IncubatorColors.purple,
                      ),
                    ),
                    _MetricDivider(),
                    Expanded(
                      child: _ProgressMetric(
                        icon: Icons.trending_up_rounded,
                        value: '${provider.averageProgressPercent}%',
                        label: 'Progression',
                        color: const Color(0xFFE5A000),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MetricDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 66,
      color: IncubatorColors.border(context),
    );
  }
}

class _ProgressMetric extends StatelessWidget {
  const _ProgressMetric({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Column(
        children: [
          Icon(icon, color: color, size: 25),
          const SizedBox(height: 7),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                color: IncubatorColors.textPrimary(context),
                fontSize: 21,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            style: TextStyle(
              color: IncubatorColors.textSecondary(context),
              fontSize: 9,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// PROGRAMMES — cartes horizontales alimentées par provider.openPrograms
// ============================================================================
class _ProgramsSliver extends StatelessWidget {
  const _ProgramsSliver();

  @override
  Widget build(BuildContext context) {
    return Consumer<IncubatorProvider>(
      builder: (context, provider, _) {
        final programs = provider.openPrograms;

        return SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 22),
            child: Column(
              children: [
                _SectionHeader(
                  title: 'Programmes disponibles',
                  actionLabel: 'Voir tous',
                  onAction: () =>
                      context.go(AppRoutes.incubatorExplore),
                ),
                const SizedBox(height: 11),
                if (programs.isEmpty)
                  const _EmptyInline(
                    icon: Icons.school_outlined,
                    title: 'Aucun programme ouvert',
                    subtitle:
                        'Les nouveaux appels à candidatures apparaîtront ici.',
                  )
                else
                  SizedBox(
                    height: 188,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      scrollDirection: Axis.horizontal,
                      itemCount: programs.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(width: 11),
                      itemBuilder: (context, index) {
                        final program = programs[index];
                        return _ProgramCard(
                          program: program,
                          onTap: () => context.push(
                            AppRoutes.incubatorProgram(program.id),
                          ),
                        );
                      },
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

class _ProgramCard extends StatelessWidget {
  const _ProgramCard({
    required this.program,
    required this.onTap,
  });

  final IncubatorProgram program;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: IncubatorColors.card(context),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          width: 335,
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: IncubatorColors.border(context)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: .035),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              SizedBox(
                width: 132,
                height: double.infinity,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(13),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (program.coverUrl != null &&
                          program.coverUrl!.trim().isNotEmpty)
                        Image.network(
                          program.coverUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              const _ProgramCoverFallback(),
                        )
                      else
                        const _ProgramCoverFallback(),
                      Positioned(
                        left: 6,
                        top: 6,
                        child: _ProgramStatusBadge(
                          status: program.status,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        program.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: IncubatorColors.textPrimary(context),
                          fontSize: 14,
                          height: 1.15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        program.organizer,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: IncubatorColors.textSecondary(context),
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 9),
                      Row(
                        children: [
                          const Icon(
                            Icons.calendar_month_rounded,
                            size: 13,
                            color: IncubatorColors.institutionalBlue,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              program.deadlineLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: IncubatorColors.textSecondary(context),
                                fontSize: 9,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.groups_rounded,
                            size: 13,
                            color: IncubatorColors.institutionalBlue,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              '${program.seatsRemaining} places disponibles',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: IncubatorColors.textSecondary(context),
                                fontSize: 9,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: IncubatorColors.institutionalBlue,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Voir le programme',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            SizedBox(width: 5),
                            Icon(
                              Icons.arrow_forward_rounded,
                              color: Colors.white,
                              size: 13,
                            ),
                          ],
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
    );
  }
}

class _ProgramCoverFallback extends StatelessWidget {
  const _ProgramCoverFallback();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            IncubatorColors.institutionalBlue,
            IncubatorColors.electricBlue,
          ],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.school_rounded,
          color: Colors.white,
          size: 38,
        ),
      ),
    );
  }
}

class _ProgramStatusBadge extends StatelessWidget {
  const _ProgramStatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final normalized = status.toLowerCase();
    final (label, color) = switch (normalized) {
      'open' => ('Candidatures ouvertes', IncubatorColors.validationGreen),
      'upcoming' => ('Bientôt', IncubatorColors.premiumGold),
      'closed' => ('Fermé', IncubatorColors.danger),
      _ => (status, IncubatorColors.institutionalBlue),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: normalized == 'upcoming'
              ? IncubatorColors.nightBlue
              : Colors.white,
          fontSize: 8,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

// ============================================================================
// ACCÈS RAPIDES
// ============================================================================
class _QuickAccessSliver extends StatelessWidget {
  const _QuickAccessSliver();

  static const List<({
    IconData icon,
    String label,
    String route,
    Color color,
  })> _items = [
    (
      icon: Icons.rocket_launch_rounded,
      label: 'Programmes',
      route: AppRoutes.incubatorExplore,
      color: IncubatorColors.electricBlue,
    ),
    (
      icon: Icons.assignment_rounded,
      label: 'Candidatures',
      route: '${AppRoutes.incubator}/applications',
      color: IncubatorColors.purple,
    ),
    (
      icon: Icons.folder_rounded,
      label: 'Mes projets',
      route: '${AppRoutes.incubator}/projects',
      color: Color(0xFFE99B18),
    ),
    (
      icon: Icons.mic_rounded,
      label: 'Pitch Room',
      route: '${AppRoutes.incubator}/pitch',
      color: IncubatorColors.info,
    ),
    (
      icon: Icons.groups_rounded,
      label: 'Mentors',
      route: '${AppRoutes.incubator}/mentors',
      color: IncubatorColors.validationGreen,
    ),
    (
      icon: Icons.menu_book_rounded,
      label: 'Formations',
      route: '${AppRoutes.incubator}/trainings',
      color: IncubatorColors.purple,
    ),
    (
      icon: Icons.people_alt_rounded,
      label: 'Communauté',
      route: AppRoutes.network,
      color: IncubatorColors.institutionalBlue,
    ),
    (
      icon: Icons.article_rounded,
      label: 'Ressources',
      route: '${AppRoutes.incubator}/resources',
      color: IncubatorColors.warning,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 22),
        child: Column(
          children: [
            const _SectionHeader(title: 'Accès rapides'),
            const SizedBox(height: 11),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth < 360 ? 3 : 4;
                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _items.length,
                    gridDelegate:
                        SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      crossAxisSpacing: 9,
                      mainAxisSpacing: 9,
                      childAspectRatio: .94,
                    ),
                    itemBuilder: (context, index) {
                      return _QuickAccessTile(item: _items[index]);
                    },
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

class _QuickAccessTile extends StatelessWidget {
  const _QuickAccessTile({required this.item});

  final ({
    IconData icon,
    String label,
    String route,
    Color color,
  }) item;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: IncubatorColors.card(context),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: () => context.go(item.route),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: IncubatorColors.border(context)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: item.color.withValues(alpha: .12),
                  shape: BoxShape.circle,
                ),
                child: Icon(item.icon, color: item.color, size: 21),
              ),
              const SizedBox(height: 7),
              Text(
                item.label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: IncubatorColors.textPrimary(context),
                  fontSize: 10,
                  height: 1.15,
                  fontWeight: FontWeight.w700,
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
// CANDIDATURES — données réelles
// ============================================================================
class _ApplicationsSliver extends StatelessWidget {
  const _ApplicationsSliver();

  @override
  Widget build(BuildContext context) {
    return Consumer<IncubatorProvider>(
      builder: (context, provider, _) {
        final applications = provider.recentApplications;

        return SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 22),
            child: Column(
              children: [
                _SectionHeader(
                  title: 'Mes candidatures',
                  actionLabel: 'Voir tout',
                  onAction: () =>
                      context.go('${AppRoutes.incubator}/applications'),
                ),
                const SizedBox(height: 10),
                if (applications.isEmpty)
                  const _EmptyInline(
                    icon: Icons.assignment_outlined,
                    title: 'Aucune candidature',
                    subtitle:
                        'Postulez à un programme pour suivre son évolution ici.',
                  )
                else
                  ...applications.take(3).map(
                        (application) =>
                            _ApplicationTile(application: application),
                      ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ApplicationTile extends StatelessWidget {
  const _ApplicationTile({required this.application});

  final dynamic application;

  @override
  Widget build(BuildContext context) {
    final String status = application.status as String;
    final (label, color) = switch (status.toLowerCase()) {
      'pending' => ('En attente', IncubatorColors.warning),
      'review' => ('En étude', IncubatorColors.info),
      'accepted' => ('Acceptée', IncubatorColors.validationGreen),
      'rejected' => ('Refusée', IncubatorColors.danger),
      _ => (status, IncubatorColors.textSecondary(context)),
    };

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 9),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: IncubatorColors.card(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: IncubatorColors.border(context)),
      ),
      child: Row(
        children: [
          Container(
            width: 39,
            height: 39,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(
              Icons.assignment_turned_in_rounded,
              color: color,
              size: 20,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  application.programTitle as String,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: IncubatorColors.textPrimary(context),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  application.submittedAtLabel as String,
                  style: TextStyle(
                    color: IncubatorColors.textSecondary(context),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 7),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 9,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              color: color.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 9,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// PROJETS — progression réelle
// ============================================================================
class _ProjectsSliver extends StatelessWidget {
  const _ProjectsSliver();

  @override
  Widget build(BuildContext context) {
    return Consumer<IncubatorProvider>(
      builder: (context, provider, _) {
        final projects = provider.recentProjects;

        return SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 22),
            child: Column(
              children: [
                _SectionHeader(
                  title: 'Mes projets',
                  actionLabel: 'Voir tout',
                  onAction: () =>
                      context.go('${AppRoutes.incubator}/projects'),
                ),
                const SizedBox(height: 10),
                if (projects.isEmpty)
                  const _EmptyInline(
                    icon: Icons.lightbulb_outline_rounded,
                    title: 'Votre premier projet vous attend',
                    subtitle:
                        'Soumettez votre idée et commencez votre parcours.',
                  )
                else
                  ...projects.take(3).map(
                        (project) => _ProjectTile(project: project),
                      ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ProjectTile extends StatelessWidget {
  const _ProjectTile({required this.project});

  final IncubatorProject project;

  @override
  Widget build(BuildContext context) {
    final progress = project.progress.clamp(0, 100);

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 9),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: IncubatorColors.card(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: IncubatorColors.border(context)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: IncubatorColors.electricBlue.withValues(alpha: .11),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(
                  Icons.lightbulb_rounded,
                  color: IncubatorColors.electricBlue,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      project.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: IncubatorColors.textPrimary(context),
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Étape : ${project.currentStageLabel}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: IncubatorColors.textSecondary(context),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '$progress%',
                style: const TextStyle(
                  color: IncubatorColors.electricBlue,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress / 100,
              minHeight: 6,
              backgroundColor: IncubatorColors.border(context),
              valueColor: const AlwaysStoppedAnimation<Color>(
                IncubatorColors.electricBlue,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// ACTIVITÉ RÉCENTE
// ============================================================================
class _ActivitySliver extends StatelessWidget {
  const _ActivitySliver();

  @override
  Widget build(BuildContext context) {
    return Consumer<IncubatorProvider>(
      builder: (context, provider, _) {
        final activities = provider.recentActivities;

        return SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 22),
            child: Column(
              children: [
                const _SectionHeader(title: 'Activité récente'),
                const SizedBox(height: 10),
                if (activities.isEmpty)
                  const _EmptyInline(
                    icon: Icons.history_rounded,
                    title: 'Aucune activité récente',
                    subtitle:
                        'Les mises à jour de vos projets apparaîtront ici.',
                  )
                else
                  ...activities.take(4).map(
                        (activity) => _ActivityTile(activity: activity),
                      ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ActivityTile extends StatelessWidget {
  const _ActivityTile({required this.activity});

  final IncubatorActivity activity;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: IncubatorColors.surface(context),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: const BoxDecoration(
              color: Color(0x1A16A34A),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_rounded,
              color: IncubatorColors.validationGreen,
              size: 21,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity.title,
                  style: TextStyle(
                    color: IncubatorColors.textPrimary(context),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  activity.timeLabel,
                  style: TextStyle(
                    color: IncubatorColors.textSecondary(context),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// PARCOURS D'INCUBATION — étapes de référence du parcours
// Note : les étapes affichées sont le parcours général, pas un statut individuel.
// ============================================================================
class _JourneySliver extends StatelessWidget {
  const _JourneySliver();

  static const List<({String title, IconData icon})> _steps = [
    (title: 'Soumission du projet', icon: Icons.send_rounded),
    (title: 'Évaluation du dossier', icon: Icons.fact_check_rounded),
    (title: 'Sélection', icon: Icons.verified_rounded),
    (title: 'Incubation et mentorat', icon: Icons.school_rounded),
    (title: 'Pitch & Demo Day', icon: Icons.mic_rounded),
    (title: 'Post-incubation', icon: Icons.rocket_launch_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 22),
        child: Column(
          children: [
            const _SectionHeader(title: 'Parcours de votre projet'),
            const SizedBox(height: 10),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 14),
              padding: const EdgeInsets.fromLTRB(15, 16, 15, 12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    IncubatorColors.nightBlue,
                    IncubatorColors.institutionalBlue,
                  ],
                ),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.emoji_events_rounded,
                        color: IncubatorColors.premiumGold,
                        size: 22,
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Votre parcours entrepreneurial',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.arrow_forward_rounded,
                        color: IncubatorColors.premiumGold,
                        size: 18,
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    height: 112,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _steps.length,
                      separatorBuilder: (_, __) => SizedBox(
                        width: 23,
                        child: Center(
                          child: Container(
                            width: 22,
                            height: 2,
                            color: Colors.white.withValues(alpha: .5),
                          ),
                        ),
                      ),
                      itemBuilder: (context, index) {
                        final step = _steps[index];
                        return SizedBox(
                          width: 72,
                          child: Column(
                            children: [
                              Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: index == 0
                                      ? IncubatorColors.validationGreen
                                      : index == 2
                                          ? IncubatorColors.premiumGold
                                          : Colors.white.withValues(
                                              alpha: .16,
                                            ),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: .7),
                                  ),
                                ),
                                child: Icon(
                                  step.icon,
                                  color: index == 2
                                      ? IncubatorColors.nightBlue
                                      : Colors.white,
                                  size: 17,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                step.title,
                                textAlign: TextAlign.center,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  height: 1.2,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
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
}

// ============================================================================
// BANNIÈRE DE FIN
// ============================================================================
class _ClosingBannerSliver extends StatelessWidget {
  const _ClosingBannerSliver();

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.fromLTRB(14, 0, 14, 12),
        padding: const EdgeInsets.all(17),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [
              IncubatorColors.institutionalBlue,
              IncubatorColors.nightBlue,
            ],
          ),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.emoji_events_rounded,
              color: IncubatorColors.premiumGold,
              size: 43,
            ),
            const SizedBox(width: 13),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ensemble, construisons\nl’innovation en Afrique.',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      height: 1.25,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'INCUBATOR by SONATHIX GROUP',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.rocket_launch_rounded,
              color: IncubatorColors.premiumGold,
              size: 34,
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// EMPTY INLINE
// ============================================================================
class _EmptyInline extends StatelessWidget {
  const _EmptyInline({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
      width: double.infinity,
      decoration: BoxDecoration(
        color: IncubatorColors.surface(context),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: IncubatorColors.border(context)),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: IncubatorColors.electricBlue,
            size: 29,
          ),
          const SizedBox(height: 8),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: IncubatorColors.textPrimary(context),
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: IncubatorColors.textSecondary(context),
              fontSize: 10,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// SKELETON
// ============================================================================
class _SkeletonBody extends StatelessWidget {
  const _SkeletonBody();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: IncubatorColors.border(context),
      highlightColor: IncubatorColors.card(context),
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            const SizedBox(height: 12),
            _skeletonBox(height: 58, radius: 13),
            const SizedBox(height: 12),
            _skeletonBox(height: 300, radius: 22),
            const SizedBox(height: 14),
            _skeletonBox(height: 112, radius: 18),
            const SizedBox(height: 22),
            _skeletonBox(height: 185, radius: 18),
            const SizedBox(height: 22),
            _skeletonBox(height: 150, radius: 18),
          ],
        ),
      ),
    );
  }

  Widget _skeletonBox({required double height, required double radius}) {
    return Container(
      width: double.infinity,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

// ============================================================================
// ERROR STATE
// ============================================================================
class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              size: 55,
              color: IncubatorColors.danger,
            ),
            const SizedBox(height: 18),
            Text(
              'Connexion impossible',
              style: TextStyle(
                color: IncubatorColors.textPrimary(context),
                fontSize: 19,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            if (kDebugMode)
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: IncubatorColors.textSecondary(context),
                  fontSize: 11,
                ),
              )
            else
              Text(
                'Vérifiez votre connexion puis réessayez.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: IncubatorColors.textSecondary(context),
                  fontSize: 12,
                ),
              ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Réessayer'),
              style: ElevatedButton.styleFrom(
                backgroundColor: IncubatorColors.electricBlue,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// BOTTOM NAVIGATION — routes de l'espace INCUBATOR
// ============================================================================
class _IncubatorBottomNavigation extends StatelessWidget {
  const _IncubatorBottomNavigation({required this.currentIndex});

  final int currentIndex;

  static const _items = [
    (icon: Icons.home_rounded, label: 'Accueil'),
    (icon: Icons.explore_rounded, label: 'Explorer'),
    (icon: Icons.work_outline_rounded, label: 'Mes projets'),
    (icon: Icons.mic_none_rounded, label: 'Pitch'),
    (icon: Icons.person_outline_rounded, label: 'Profil'),
  ];

  static const _routes = [
    AppRoutes.incubator,
    AppRoutes.incubatorExplore,
    '${AppRoutes.incubator}/projects',
    '${AppRoutes.incubator}/pitch',
    AppRoutes.profile,
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: IncubatorColors.card(context),
        border: Border(
          top: BorderSide(color: IncubatorColors.border(context)),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .045),
            blurRadius: 12,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 65,
          child: Row(
            children: List.generate(_items.length, (index) {
              final item = _items[index];
              final selected = index == currentIndex;

              return Expanded(
                child: InkWell(
                  onTap: () => context.go(_routes[index]),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        item.icon,
                        size: 23,
                        color: selected
                            ? IncubatorColors.electricBlue
                            : IncubatorColors.textSecondary(context),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: selected
                              ? IncubatorColors.electricBlue
                              : IncubatorColors.textSecondary(context),
                          fontSize: 9,
                          fontWeight:
                              selected ? FontWeight.w900 : FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 3),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: selected ? 24 : 0,
                        height: 3,
                        decoration: BoxDecoration(
                          color: IncubatorColors.electricBlue,
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                    ],
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
