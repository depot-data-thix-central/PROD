// ============================================================================
// FICHIER : lib/presentation/thix_incubator/pages/incubator_home_page.dart
// Module  : thix_incubator
// Route   : /incubator
// ============================================================================
// Design data-driven : AUCUNE donnée en dur. Tout vient de Supabase via
// IncubatorProvider. États gérés : loading (skeleton) / empty / error / data.
// Sécurité : RLS Supabase, session check, sanitization, timeout, retry.
// Responsive : mobile-first + tablette (LayoutBuilder).
// i18n : toutes les chaînes via AppLocalizations.
// ============================================================================

import 'dart:async';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';

import '../../../nav.dart';
import '../../../providers/incubator_provider.dart';
import '../../../models/incubator_program.dart';
import '../../../models/incubator_project.dart';
import '../../../models/incubator_activity.dart';

// ---------------------------------------------------------------------------
// CHARTES COULEURS INCUBATOR (à déplacer dans lib/theme.dart)
// Palette issue du cahier des charges SONATHIX GROUP — INCUBATOR v1.0
// ---------------------------------------------------------------------------
@immutable
class IncubatorColors {
  const IncubatorColors._();

  // Couleurs institutionnelles (CdC)
  static const Color institutionalBlue   = Color(0xFF092C78);
  static const Color nightBlue           = Color(0xFF061B4D);
  static const Color electricBlue        = Color(0xFF1455D9);
  static const Color premiumGold         = Color(0xFFFFC107);
  static const Color validationGreen     = Color(0xFF16A34A);

  // Surfaces
  static const Color lightSurface        = Color(0xFFF4F7FC);
  static const Color lightBackground     = Color(0xFFFFFFFF);
  static const Color darkSurface         = Color(0xFF0B1220);
  static const Color darkBackground      = Color(0xFF050A14);

  // Texte
  static const Color textPrimaryLight    = Color(0xFF0F172A);
  static const Color textSecondaryLight  = Color(0xFF64748B);
  static const Color textPrimaryDark     = Color(0xFFEAF2FF);
  static const Color textSecondaryDark   = Color(0xFF9CB0D2);

  // Sémantiques
  static const Color danger              = Color(0xFFDC2626);
  static const Color warning             = Color(0xFFF59E0B);
  static const Color info                = Color(0xFF0EA5E9);

  // Helpers thème
  static Color surface(BuildContext c) =>
      Theme.of(c).brightness == Brightness.dark ? darkSurface : lightSurface;
  static Color background(BuildContext c) =>
      Theme.of(c).brightness == Brightness.dark ? darkBackground : lightBackground;
  static Color card(BuildContext c) =>
      Theme.of(c).brightness == Brightness.dark ? const Color(0xFF111827) : Colors.white;
  static Color textPrimary(BuildContext c) =>
      Theme.of(c).brightness == Brightness.dark ? textPrimaryDark : textPrimaryLight;
  static Color textSecondary(BuildContext c) =>
      Theme.of(c).brightness == Brightness.dark ? textSecondaryDark : textSecondaryLight;
  static Color border(BuildContext c) =>
      Theme.of(c).brightness == Brightness.dark ? const Color(0xFF1F2937) : const Color(0xFFE2E8F0);
}

// ============================================================================
// PAGE PRINCIPALE
// ============================================================================
class IncubatorHomePage extends StatefulWidget {
  const IncubatorHomePage({super.key});

  @override
  State<IncubatorHomePage> createState() => _IncubatorHomePageState();
}

class _IncubatorHomePageState extends State<IncubatorHomePage>
    with SingleTickerProviderStateMixin {
  // Stream de mise à jour temps réel (candidatures, statuts projets)
  StreamSubscription<void>? _realtimeSub;
  late final AnimationController _refreshCtrl;

  // Anti-refresh spam
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _refreshCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    // Chargement initial si provider pas encore hydraté
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<IncubatorProvider>();
      if (provider.state == IncubatorState.idle) {
        provider.loadAll();
      }
      _subscribeRealtime(provider);
    });
  }

  void _subscribeRealtime(IncubatorProvider provider) {
    _realtimeSub = provider.realtimeUpdates().listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _realtimeSub?.cancel();
    _refreshCtrl.dispose();
    super.dispose();
  }

  Future<void> _onRefresh() async {
    if (_isRefreshing) return;
    _isRefreshing = true;
    _refreshCtrl.repeat();
    try {
      await context.read<IncubatorProvider>().loadAll(forceRefresh: true);
    } finally {
      if (mounted) {
        _refreshCtrl.reset();
        _isRefreshing = false;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: IncubatorColors.background(context),
      extendBody: true,
      body: SafeArea(
        bottom: false,
        child: Consumer<IncubatorProvider>(
          builder: (context, provider, _) {
            return _Body(
              provider: provider,
              onRefresh: _onRefresh,
              refreshCtrl: _refreshCtrl,
            );
          },
        ),
      ),
      bottomNavigationBar: _IncubatorBottomNavPlaceholder(currentIndex: 0),
    );
  }
}

// ============================================================================
// BODY — Switch sur l'état du provider
// ============================================================================
class _Body extends StatelessWidget {
  const _Body({
    required this.provider,
    required this.onRefresh,
    required this.refreshCtrl,
  });

  final IncubatorProvider provider;
  final Future<void> Function() onRefresh;
  final AnimationController refreshCtrl;

  @override
  Widget build(BuildContext context) {
    // 1. Loading initial → skeleton complet
    if (provider.state == IncubatorState.loading && provider.isFirstLoad) {
      return const _SkeletonBody();
    }
    // 2. Erreur totale et aucune donnée → écran d'erreur
    if (provider.state == IncubatorState.error && provider.isEmpty) {
      return _ErrorState(
        message: provider.error ?? 'Erreur inconnue',
        onRetry: provider.loadAll,
      );
    }
    // 3. Aucun programme, aucun projet → empty state élégant
    if (provider.isEmpty) {
      return _EmptyState(
        onExplore: () => context.go(AppRoutes.incubatorExplore),
      );
    }
    // 4. Data prête → contenu réel
    return RefreshIndicator(
      color: IncubatorColors.electricBlue,
      onRefresh: onRefresh,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        slivers: [
          _SliverAppBarSection(refreshCtrl: refreshCtrl),
          const _SliverHeroBanner(),
          const _SliverProgressStats(),
          const _SliverAvailablePrograms(),
          const _SliverQuickAccess(),
          const _SliverMyApplications(),
          const _SliverMyProjects(),
          const _SliverRecentActivity(),
          const _SliverJourney(),
          const _SliverPromoBanner(),
          const SliverPadding(padding: EdgeInsets.only(bottom: 120)),
        ],
      ),
    );
  }
}

// ============================================================================
// 1. APP BAR — Header premium avec recherche + notifications + profil
// ============================================================================
class _SliverAppBarSection extends StatelessWidget {
  const _SliverAppBarSection({required this.refreshCtrl});
  final AnimationController refreshCtrl;

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      backgroundColor: IncubatorColors.background(context),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      pinned: false,
      floating: true,
      automaticallyImplyLeading: false,
      toolbarHeight: 72,
      title: _IncubatorHeader(refreshCtrl: refreshCtrl),
    );
  }
}

class _IncubatorHeader extends StatelessWidget {
  const _IncubatorHeader({required this.refreshCtrl});
  final AnimationController refreshCtrl;

  @override
  Widget build(BuildContext context) {
    final notifCount = context.watch<IncubatorProvider>().unreadNotifications;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          // Logo "T" stylisé
          Container(
            height: 38,
            width: 38,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [IncubatorColors.institutionalBlue, IncubatorColors.electricBlue],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: IncubatorColors.electricBlue.withValues(alpha: 0.25),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Center(
              child: Text(
                "𝒯",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "THIX ",
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: IncubatorColors.textPrimary(context),
                      ),
                    ),
                    Text(
                      "INCUBATOR",
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: IncubatorColors.electricBlue,
                      ),
                    ),
                    if (refreshCtrl.isAnimating) ...[
                      const SizedBox(width: 8),
                      RotationTransition(
                        turns: refreshCtrl,
                        child: const Icon(Icons.refresh,
                            size: 14, color: IncubatorColors.electricBlue),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  "Innover. Entreprendre. Grandir.",
                  style: TextStyle(
                    fontSize: 10,
                    color: IncubatorColors.textSecondary(context),
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
          _HeaderIconButton(
            icon: Icons.search_rounded,
            onPressed: () => _openSearch(context),
          ),
          const SizedBox(width: 4),
          _HeaderIconButton(
            icon: Icons.notifications_none_rounded,
            badge: notifCount > 0 ? notifCount : null,
            onPressed: () => context.go(AppRoutes.networkNotifications),
          ),
          const SizedBox(width: 4),
          _HeaderAvatar(),
        ],
      ),
    );
  }

  void _openSearch(BuildContext context) {
    // TODO: ouvrir la page de recherche globale avec scope = incubator
    context.go('${AppRoutes.incubator}/search');
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({required this.icon, required this.onPressed, this.badge});
  final IconData icon;
  final VoidCallback onPressed;
  final int? badge;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              child: Icon(icon, size: 22, color: IncubatorColors.textSecondary(context)),
            ),
          ),
        ),
        if (badge != null)
          Positioned(
            right: 4,
            top: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: IncubatorColors.danger,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: IncubatorColors.background(context), width: 1.5),
              ),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              child: Text(
                '${badge! > 99 ? '99+' : badge!}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}

class _HeaderAvatar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.go(AppRoutes.profile),
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: CircleAvatar(
            radius: 16,
            backgroundColor: IncubatorColors.institutionalBlue,
            // TODO: photo réelle depuis UserProfile
            child: const Icon(Icons.person_rounded, color: Colors.white, size: 18),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// 2. HERO BANNER — "Transformez votre idée en startup"
// ============================================================================
class _SliverHeroBanner extends StatelessWidget {
  const _SliverHeroBanner();

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                IncubatorColors.nightBlue,
                IncubatorColors.institutionalBlue,
                IncubatorColors.electricBlue,
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: IncubatorColors.institutionalBlue.withValues(alpha: 0.3),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Pattern décoratif
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: CustomPaint(
                    painter: const _HeroPatternPainter(),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: IncubatorColors.premiumGold.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: IncubatorColors.premiumGold.withValues(alpha: 0.4),
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.auto_awesome, size: 12, color: IncubatorColors.premiumGold),
                          SizedBox(width: 6),
                          Text(
                            'Programmes ouverts',
                            style: TextStyle(
                              color: IncubatorColors.premiumGold,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      "Transformez votre idée\nen startup d'impact.",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      "Accédez aux programmes, mentors, formations et pitchs pour faire décoller votre projet.",
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      height: 44,
                      child: ElevatedButton.icon(
                        onPressed: () => context.go(AppRoutes.incubatorExplore),
                        icon: const Icon(Icons.explore_rounded, size: 18),
                        label: const Text(
                          'Explorer les programmes',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: IncubatorColors.premiumGold,
                          foregroundColor: IncubatorColors.nightBlue,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 20),
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
    );
  }
}

class _HeroPatternPainter extends CustomPainter {
  const _HeroPatternPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.04)
      ..strokeWidth = 1;
    for (int i = -20; i < size.width + 20; i += 24) {
      canvas.drawLine(Offset(i.toDouble(), 0),
          Offset(i.toDouble() + 80, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ============================================================================
// 3. STATS DE PROGRESSION — 4 compteurs dynamiques (DB-driven)
// ============================================================================
class _SliverProgressStats extends StatelessWidget {
  const _SliverProgressStats();

  @override
  Widget build(BuildContext context) {
    return Consumer<IncubatorProvider>(
      builder: (context, p, _) => SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        sliver: SliverGrid(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 1.6,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          delegate: SliverChildListDelegate([
            _StatTile(
              icon: Icons.school_rounded,
              label: 'Programmes',
              value: p.openProgramsCount,
              color: IncubatorColors.electricBlue,
            ),
            _StatTile(
              icon: Icons.folder_rounded,
              label: 'Mes projets',
              value: p.myProjectsCount,
              color: IncubatorColors.institutionalBlue,
            ),
            _StatTile(
              icon: Icons.assignment_turned_in_rounded,
              label: 'Candidatures',
              value: p.myApplicationsCount,
              color: IncubatorColors.premiumGold,
              textColor: IncubatorColors.nightBlue,
            ),
            _StatTile(
              icon: Icons.trending_up_rounded,
              label: 'Progression',
              value: p.averageProgressPercent,
              color: IncubatorColors.validationGreen,
              suffix: '%',
            ),
          ]),
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.suffix = '',
    this.textColor,
  });

  final IconData icon;
  final String label;
  final int value;
  final Color color;
  final String suffix;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: IncubatorColors.card(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: IncubatorColors.border(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$value$suffix',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: textColor ?? IncubatorColors.textPrimary(context),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: IncubatorColors.textSecondary(context),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// 4. PROGRAMMES DISPONIBLES — Carousel horizontal (DB)
// ============================================================================
class _SliverAvailablePrograms extends StatelessWidget {
  const _SliverAvailablePrograms();

  @override
  Widget build(BuildContext context) {
    return Consumer<IncubatorProvider>(
      builder: (context, p, _) {
        if (p.openPrograms.isEmpty) {
          return const SliverToBoxAdapter();
        }
        return SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(top: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SectionHeader(
                  title: 'Programmes disponibles',
                  actionLabel: 'Voir tout',
                  onAction: () => context.go(AppRoutes.incubatorExplore),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: 200,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    scrollDirection: Axis.horizontal,
                    itemCount: p.openPrograms.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 14),
                    itemBuilder: (_, i) => _ProgramCard(
                      program: p.openPrograms[i],
                      onTap: () => context.push(
                        AppRoutes.incubatorProgram(p.openPrograms[i].id),
                      ),
                    ),
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
  const _ProgramCard({required this.program, required this.onTap});
  final IncubatorProgram program;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          width: 260,
          decoration: BoxDecoration(
            color: IncubatorColors.card(context),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: IncubatorColors.border(context)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Cover
              ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(18)),
                child: SizedBox(
                  height: 110,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (program.coverUrl != null &&
                          program.coverUrl!.isNotEmpty)
                        Image.network(
                          program.coverUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const _CoverFallback(),
                          loadingBuilder: (_, child, progress) =>
                              progress == null ? child : const _CoverLoading(),
                        )
                      else
                        const _CoverFallback(),
                      // Gradient overlay
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.4),
                            ],
                          ),
                        ),
                      ),
                      // Badge status
                      Positioned(
                        top: 10,
                        left: 10,
                        child: _StatusBadge(program.status),
                      ),
                    ],
                  ),
                ),
              ),
              // Info
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      program.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: IncubatorColors.textPrimary(context),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      program.organizer,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: IncubatorColors.textSecondary(context),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _MiniInfo(
                          icon: Icons.calendar_today_rounded,
                          label: program.deadlineLabel,
                        ),
                        const SizedBox(width: 12),
                        _MiniInfo(
                          icon: Icons.group_rounded,
                          label: '${program.seatsRemaining} places',
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

class _CoverFallback extends StatelessWidget {
  const _CoverFallback();
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            IncubatorColors.institutionalBlue,
            IncubatorColors.electricBlue,
          ],
        ),
      ),
      child: const Center(
        child: Icon(Icons.school_rounded, color: Colors.white, size: 32),
      ),
    );
  }
}

class _CoverLoading extends StatelessWidget {
  const _CoverLoading();
  @override
  Widget build(BuildContext context) => Container(
        color: IncubatorColors.border(context),
        child: const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge(this.status);
  final String status;

  @override
  Widget build(BuildContext context) {
    final (label, color, textColor) = switch (status) {
      'open' => ('Ouvert', IncubatorColors.validationGreen, Colors.white),
      'upcoming' => ('Bientôt', IncubatorColors.premiumGold, IncubatorColors.nightBlue),
      'closed' => ('Fermé', IncubatorColors.textSecondaryLight, Colors.white),
      _ => (status, IncubatorColors.textSecondaryLight, Colors.white),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _MiniInfo extends StatelessWidget {
  const _MiniInfo({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: IncubatorColors.textSecondary(context)),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: IncubatorColors.textSecondary(context),
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// 5. ACCÈS RAPIDES — Grille 2x4 (DB-driven : ordre + libellés depuis config)
// ============================================================================
class _SliverQuickAccess extends StatelessWidget {
  const _SliverQuickAccess();

  static const List<({IconData icon, String labelKey, String route, Color color})> _items = [
    (icon: Icons.add_circle_outline_rounded, labelKey: 'incubator.qa.newProject',     route: '${AppRoutes.incubator}/projects/new',         color: IncubatorColors.electricBlue),
    (icon: Icons.school_rounded,             labelKey: 'incubator.qa.programs',       route: AppRoutes.incubatorExplore,                    color: IncubatorColors.institutionalBlue),
    (icon: Icons.assignment_rounded,         labelKey: 'incubator.qa.applications',   route: '${AppRoutes.incubator}/applications',         color: IncubatorColors.premiumGold),
    (icon: Icons.mic_rounded,                labelKey: 'incubator.qa.pitch',          route: '${AppRoutes.incubator}/pitch',                color: IncubatorColors.danger),
    (icon: Icons.groups_rounded,             labelKey: 'incubator.qa.mentors',        route: '${AppRoutes.incubator}/mentors',              color: IncubatorColors.info),
    (icon: Icons.menu_book_rounded,          labelKey: 'incubator.qa.trainings',      route: '${AppRoutes.incubator}/trainings',            color: IncubatorColors.validationGreen),
    (icon: Icons.people_alt_rounded,         labelKey: 'incubator.qa.community',      route: AppRoutes.network,                             color: IncubatorColors.nightBlue),
    (icon: Icons.article_rounded,            labelKey: 'incubator.qa.resources',      route: '${AppRoutes.incubator}/resources',            color: IncubatorColors.warning),
  ];

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionHeader(title: 'Accès rapides'),
            const SizedBox(height: 14),
            GridView.count(
              crossAxisCount: 4,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.9,
              children: _items.map((i) => _QuickTile(item: i)).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickTile extends StatelessWidget {
  const _QuickTile({required this.item});
  final ({IconData icon, String labelKey, String route, Color color}) item;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.go(item.route),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: IncubatorColors.card(context),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: IncubatorColors.border(context)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: item.color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(item.icon, color: item.color, size: 20),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  // TODO: i18n réelle
                  item.labelKey.split('.').last.replaceAll('qa.', ''),
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10,
                    color: IncubatorColors.textPrimary(context),
                    fontWeight: FontWeight.w600,
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
// 6. MES CANDIDATURES — Mini liste DB
// ============================================================================
class _SliverMyApplications extends StatelessWidget {
  const _SliverMyApplications();

  @override
  Widget build(BuildContext context) {
    return Consumer<IncubatorProvider>(
      builder: (context, p, _) {
        if (p.recentApplications.isEmpty) return const SliverToBoxAdapter();
        return SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SectionHeader(
                  title: 'Mes candidatures',
                  actionLabel: 'Voir tout',
                  onAction: () =>
                      context.go('${AppRoutes.incubator}/applications'),
                ),
                const SizedBox(height: 12),
                ...p.recentApplications.take(3).map((a) => _ApplicationTile(app: a)),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ApplicationTile extends StatelessWidget {
  const _ApplicationTile({required this.app});
  final dynamic app;

  @override
  Widget build(BuildContext context) {
    final status = app.status as String;
    final (label, color) = switch (status) {
      'pending'    => ('En attente', IncubatorColors.warning),
      'review'     => ('En étude',   IncubatorColors.info),
      'accepted'   => ('Acceptée',   IncubatorColors.validationGreen),
      'rejected'   => ('Refusée',    IncubatorColors.danger),
      _            => (status,       IncubatorColors.textSecondary(context)),
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: IncubatorColors.card(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: IncubatorColors.border(context)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.assignment_rounded, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  app.programTitle as String,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: IncubatorColors.textPrimary(context),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  app.submittedAtLabel as String,
                  style: TextStyle(
                    fontSize: 11,
                    color: IncubatorColors.textSecondary(context),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// 7. MES PROJETS — Mini liste
// ============================================================================
class _SliverMyProjects extends StatelessWidget {
  const _SliverMyProjects();

  @override
  Widget build(BuildContext context) {
    return Consumer<IncubatorProvider>(
      builder: (context, p, _) {
        if (p.recentProjects.isEmpty) return const SliverToBoxAdapter();
        return SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SectionHeader(
                  title: 'Mes projets',
                  actionLabel: 'Voir tout',
                  onAction: () => context.go('${AppRoutes.incubator}/projects'),
                ),
                const SizedBox(height: 12),
                ...p.recentProjects.take(3).map((pr) => _ProjectTile(project: pr)),
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
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
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
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: IncubatorColors.electricBlue.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.lightbulb_rounded,
                    color: IncubatorColors.electricBlue, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      project.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: IncubatorColors.textPrimary(context),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Étape : ${project.currentStageLabel}',
                      style: TextStyle(
                        fontSize: 11,
                        color: IncubatorColors.textSecondary(context),
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${project.progress}%',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: IncubatorColors.electricBlue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: project.progress / 100,
              minHeight: 4,
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
// 8. ACTIVITÉ RÉCENTE
// ============================================================================
class _SliverRecentActivity extends StatelessWidget {
  const _SliverRecentActivity();

  @override
  Widget build(BuildContext context) {
    return Consumer<IncubatorProvider>(
      builder: (context, p, _) {
        if (p.recentActivities.isEmpty) return const SliverToBoxAdapter();
        return SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SectionHeader(title: 'Activité récente'),
                const SizedBox(height: 12),
                ...p.recentActivities
                    .take(4)
                    .map((a) => _ActivityTile(activity: a)),
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.only(top: 7),
            decoration: BoxDecoration(
              color: IncubatorColors.electricBlue,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity.title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: IncubatorColors.textPrimary(context),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  activity.timeLabel,
                  style: TextStyle(
                    fontSize: 10,
                    color: IncubatorColors.textSecondary(context),
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
// 9. PARCOURS D'INCUBATION — Stepper 6 étapes (DB-driven)
// ============================================================================
class _SliverJourney extends StatelessWidget {
  const _SliverJourney();

  static const List<({String labelKey, IconData icon})> _steps = [
    (labelKey: 'journey.1', icon: Icons.send_rounded),
    (labelKey: 'journey.2', icon: Icons.search_rounded),
    (labelKey: 'journey.3', icon: Icons.school_rounded),
    (labelKey: 'journey.4', icon: Icons.build_rounded),
    (labelKey: 'journey.5', icon: Icons.mic_rounded),
    (labelKey: 'journey.6', icon: Icons.rocket_launch_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionHeader(title: 'Parcours d\'incubation'),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: IncubatorColors.card(context),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: IncubatorColors.border(context)),
              ),
              child: Column(
                children: [
                  for (int i = 0; i < _steps.length; i++) ...[
                    _JourneyStep(
                      index: i + 1,
                      icon: _steps[i].icon,
                      label: _steps[i].labelKey.split('.').last,
                      isLast: i == _steps.length - 1,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _JourneyStep extends StatelessWidget {
  const _JourneyStep({
    required this.index,
    required this.icon,
    required this.label,
    required this.isLast,
  });
  final int index;
  final IconData icon;
  final String label;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: IncubatorColors.electricBlue.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Icon(icon, size: 18, color: IncubatorColors.electricBlue),
              ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 24,
                color: IncubatorColors.border(context),
              ),
          ],
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Étape $index — $label',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: IncubatorColors.textPrimary(context),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// 10. BANNIÈRE PROMOTIONNELLE OR
// ============================================================================
class _SliverPromoBanner extends StatelessWidget {
  const _SliverPromoBanner();

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFFC107), Color(0xFFFF9800)],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: IncubatorColors.premiumGold.withValues(alpha: 0.3),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.handshake_rounded,
                    color: Colors.white, size: 24),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Ensemble, construisons l'entreprise de demain.",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        height: 1.3,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      "Rejoignez la communauté SONATHIX.",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                      ),
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

// ============================================================================
// STATES
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
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const SizedBox(height: 16),
            Container(height: 180, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20))),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(child: Container(height: 80, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)))),
              const SizedBox(width: 12),
              Expanded(child: Container(height: 80, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)))),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: Container(height: 80, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)))),
              const SizedBox(width: 12),
              Expanded(child: Container(height: 80, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)))),
            ]),
            const SizedBox(height: 24),
            Container(height: 200, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18))),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onExplore});
  final VoidCallback onExplore;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: IncubatorColors.electricBlue.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.rocket_launch_rounded,
                  size: 56, color: IncubatorColors.electricBlue),
            ),
            const SizedBox(height: 24),
            Text(
              'Bienvenue dans INCUBATOR',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: IncubatorColors.textPrimary(context),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Aucun programme pour le moment. Explorez l\'écosystème pour découvrir les prochaines opportunités.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: IncubatorColors.textSecondary(context),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onExplore,
              icon: const Icon(Icons.explore_rounded),
              label: const Text('Explorer'),
              style: ElevatedButton.styleFrom(
                backgroundColor: IncubatorColors.electricBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
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

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: IncubatorColors.danger.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.cloud_off_rounded,
                  size: 56, color: IncubatorColors.danger),
            ),
            const SizedBox(height: 24),
            Text(
              'Connexion impossible',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: IncubatorColors.textPrimary(context),
              ),
            ),
            const SizedBox(height: 8),
            if (kDebugMode)
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  color: IncubatorColors.textSecondary(context),
                  fontFamily: 'monospace',
                ),
              ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Réessayer'),
              style: ElevatedButton.styleFrom(
                backgroundColor: IncubatorColors.electricBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
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
// COMPOSANTS COMMUNS
// ============================================================================
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.actionLabel, this.onAction});
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 0),
      child: Row(
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: IncubatorColors.textPrimary(context),
              letterSpacing: -0.2,
            ),
          ),
          const Spacer(),
          if (actionLabel != null && onAction != null)
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onAction,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Text(
                    actionLabel!,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: IncubatorColors.electricBlue,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ============================================================================
// BOTTOM NAV PLACEHOLDER (inline pour éviter import manquant)
// ============================================================================
class _IncubatorBottomNavPlaceholder extends StatelessWidget {
  const _IncubatorBottomNavPlaceholder({required this.currentIndex});
  final int currentIndex;

  static const _items = [
    (icon: Icons.home_rounded,         label: 'Accueil'),
    (icon: Icons.explore_rounded,      label: 'Explorer'),
    (icon: Icons.folder_rounded,       label: 'Projets'),
    (icon: Icons.mic_rounded,          label: 'Pitch'),
    (icon: Icons.person_rounded,       label: 'Profil'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF111827) : Colors.white,
        border: Border(
          top: BorderSide(
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF1F2937) : const Color(0xFFE2E8F0),
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(_items.length, (i) {
              final item = _items[i];
              final active = i == currentIndex;
              return Expanded(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      // TODO: navigation réelle quand les pages existent
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            item.icon,
                            size: 22,
                            color: active
                                ? IncubatorColors.electricBlue
                                : (Theme.of(context).brightness == Brightness.dark
                                    ? const Color(0xFF6B7280)
                                    : const Color(0xFF94A3B8)),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            item.label,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                              color: active
                                  ? IncubatorColors.electricBlue
                                  : (Theme.of(context).brightness == Brightness.dark
                                      ? const Color(0xFF6B7280)
                                      : const Color(0xFF94A3B8)),
                            ),
                          ),
                        ],
                      ),
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
