// ============================================================================
// FICHIER : lib/presentation/thix_incubator/pages/incubator_home_page.dart
// Module  : thix_incubator
// Route   : /incubator
//
// Homepage INCUBATOR — design ultra-professionnel, fidèle à la maquette.
// Aucune image mockup : utilisation exclusive des données réelles du Provider.
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
// COULEURS INSTITUTIONNELLES (Fidèles à la maquette)
// ============================================================================
@immutable
class IncubatorColors {
  const IncubatorColors._();

  static const Color institutionalBlue = Color(0xFF092C78);
  static const Color nightBlue = Color(0xFF061B4D);
  static const Color electricBlue = Color(0xFF1455D9);
  static const Color premiumGold = Color(0xFFFFC107);
  static const Color validationGreen = Color(0xFF16A34A);

  static const Color lightSurface = Color(0xFFF5F7FA);
  static const Color lightBackground = Color(0xFFFFFFFF);
  static const Color darkSurface = Color(0xFF111C30);
  static const Color darkBackground = Color(0xFF07101F);

  static const Color textPrimaryLight = Color(0xFF0F172A);
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
      isDark(context) ? const Color(0xFF263650) : const Color(0xFFE2E8F0);
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
                  const _ActivitySliver(),
                  const _JourneySliver(),
                  const _ClosingBannerSliver(),
                  const SliverToBoxAdapter(child: SizedBox(height: 30)),
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
// HEADER (Double bandeau : Bleu Nuit + Blanc)
// ============================================================================
class _HeaderSliver extends StatelessWidget {
  const _HeaderSliver({required this.refreshController});

  final AnimationController refreshController;

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Column(
        children: [
          // --- Bandeau Bleu Nuit ---
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [IncubatorColors.nightBlue, IncubatorColors.institutionalBlue],
              ),
            ),
            child: Consumer<IncubatorProvider>(
              builder: (context, provider, _) {
                return Row(
                  children: [
                    const Icon(
                      Icons.rocket_launch_rounded,
                      color: IncubatorColors.premiumGold,
                      size: 28,
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'INCUBATOR',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                          Text(
                            'Innover • Entreprendre • Grandir',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => context.go('${AppRoutes.incubator}/search'),
                      icon: const Icon(Icons.search_rounded, color: Colors.white, size: 24),
                    ),
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        IconButton(
                          onPressed: () => context.go(AppRoutes.networkNotifications),
                          icon: const Icon(Icons.notifications_none_rounded, color: Colors.white, size: 24),
                        ),
                        if (provider.unreadNotifications > 0)
                          Positioned(
                            right: 6,
                            top: 6,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: IncubatorColors.danger,
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                '${provider.unreadNotifications}',
                                style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                      ],
                    ),
                    InkWell(
                      onTap: () => context.go(AppRoutes.profile),
                      borderRadius: BorderRadius.circular(30),
                      child: const Padding(
                        padding: EdgeInsets.only(left: 8),
                        child: CircleAvatar(
                          radius: 16,
                          backgroundColor: Colors.white,
                          child: Icon(Icons.person_rounded, color: IncubatorColors.institutionalBlue, size: 20),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          
          // --- Bandeau Blanc ---
          Container(
            height: 58,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: IncubatorColors.card(context),
              border: Border(bottom: BorderSide(color: IncubatorColors.border(context))),
            ),
            child: Row(
              children: [
                Icon(Icons.menu_rounded, color: IncubatorColors.textPrimary(context), size: 26),
                const SizedBox(width: 14),
                Container(width: 1, height: 28, color: IncubatorColors.border(context)),
                const SizedBox(width: 14),
                const Icon(Icons.emoji_events_rounded, color: IncubatorColors.institutionalBlue, size: 26),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'INCUBATOR',
                        style: TextStyle(
                          color: IncubatorColors.textPrimary(context),
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                        ),
                      ),
                      Text(
                        'by SONATHIX GROUP',
                        style: TextStyle(
                          color: IncubatorColors.textSecondary(context),
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: IncubatorColors.validationGreen.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.verified_user_rounded, color: IncubatorColors.validationGreen, size: 14),
                      SizedBox(width: 4),
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
                const SizedBox(width: 8),
                Icon(Icons.more_vert_rounded, color: IncubatorColors.textPrimary(context), size: 22),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// HERO SECTION (Fidèle à la maquette, sans image de mockup)
// ============================================================================
class _HeroSliver extends StatelessWidget {
  const _HeroSliver();

  @override
  Widget build(BuildContext context) {
    return Consumer<IncubatorProvider>(
      builder: (context, provider, _) {
        final programs = provider.openPrograms;
        final String? cover = programs.isNotEmpty ? programs.first.coverUrl : null;

        return SliverToBoxAdapter(
          child: Container(
            margin: const EdgeInsets.all(16),
            height: 260, // Hauteur ajustée selon la maquette
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [IncubatorColors.nightBlue, IncubatorColors.institutionalBlue],
              ),
            ),
            child: Stack(
              children: [
                // Image de fond si disponible, sinon motif
                if (cover != null && cover.trim().isNotEmpty)
                  Positioned.fill(
                    child: Image.network(
                      cover,
                      fit: BoxFit.cover,
                      color: Colors.black.withValues(alpha: 0.3),
                      colorBlendMode: BlendMode.darken,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  ),
                Positioned(
                  right: -20,
                  bottom: -10,
                  child: Icon(
                    Icons.rocket_launch_rounded,
                    size: 180,
                    color: Colors.white.withValues(alpha: 0.05),
                  ),
                ),
                // Contenu textuel
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Transformez\nvotre idée en',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          height: 1.1,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const Text(
                        'entreprise.',
                        style: TextStyle(
                          color: IncubatorColors.premiumGold,
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Découvrez les programmes, développez\nvos projets et accédez aux opportunités.',
                        style: TextStyle(color: Colors.white, fontSize: 11, height: 1.4),
                      ),
                      const Spacer(),
                      ElevatedButton.icon(
                        onPressed: () => context.go(AppRoutes.incubatorExplore),
                        icon: const Icon(Icons.rocket_launch_rounded, size: 16),
                        label: const Text('Explorer les programmes'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: IncubatorColors.premiumGold,
                          foregroundColor: IncubatorColors.nightBlue,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
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
// MON ESPACE DE PROGRESSION
// ============================================================================
class _ProgressSliver extends StatelessWidget {
  const _ProgressSliver();

  @override
  Widget build(BuildContext context) {
    return Consumer<IncubatorProvider>(
      builder: (context, provider, _) {
        return SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(width: 4, height: 18, decoration: BoxDecoration(color: IncubatorColors.electricBlue, borderRadius: BorderRadius.circular(2))),
                    const SizedBox(width: 8),
                    Text(
                      'Mon espace de progression',
                      style: TextStyle(color: IncubatorColors.textPrimary(context), fontSize: 16, fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: IncubatorColors.card(context),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: IncubatorColors.border(context)),
                  ),
                  child: Row(
                    children: [
                      Expanded(child: _MetricItem(icon: Icons.folder_rounded, color: IncubatorColors.electricBlue, value: '${provider.myProjectsCount}', label: 'Mes projets')),
                      _VerticalDivider(),
                      Expanded(child: _MetricItem(icon: Icons.assignment_turned_in_rounded, color: IncubatorColors.validationGreen, value: '${provider.myApplicationsCount}', label: 'Candidatures')),
                      _VerticalDivider(),
                      Expanded(child: _MetricItem(icon: Icons.mic_rounded, color: IncubatorColors.purple, value: '01', label: 'Pitchs préparés')),
                      _VerticalDivider(),
                      Expanded(child: _MetricItem(icon: Icons.show_chart_rounded, color: IncubatorColors.premiumGold, value: '${provider.averageProgressPercent}%', label: 'Progression globale')),
                    ],
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

class _VerticalDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 40, color: IncubatorColors.border(context));
  }
}

class _MetricItem extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String value;
  final String label;

  const _MetricItem({required this.icon, required this.color, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 26),
        const SizedBox(height: 6),
        Text(value, style: TextStyle(color: IncubatorColors.textPrimary(context), fontSize: 18, fontWeight: FontWeight.w900)),
        Text(label, textAlign: TextAlign.center, maxLines: 2, style: TextStyle(color: IncubatorColors.textSecondary(context), fontSize: 9, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

// ============================================================================
// PROGRAMMES DISPONIBLES
// ============================================================================
class _ProgramsSliver extends StatelessWidget {
  const _ProgramsSliver();

  @override
  Widget build(BuildContext context) {
    return Consumer<IncubatorProvider>(
      builder: (context, provider, _) {
        final programs = provider.openPrograms;
        if (programs.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());

        return SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(top: 24, bottom: 16),
            child: Column(
              children: [
                _SectionTitle(title: 'Programmes disponibles', actionLabel: 'Voir tous', onAction: () => context.go(AppRoutes.incubatorExplore)),
                const SizedBox(height: 12),
                SizedBox(
                  height: 160,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    scrollDirection: Axis.horizontal,
                    itemCount: programs.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (context, index) {
                      final program = programs[index];
                      return _ProgramCard(program: program);
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
  final IncubatorProgram program;
  const _ProgramCard({required this.program});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: IncubatorColors.card(context),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () => context.push(AppRoutes.incubatorProgram(program.id)),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 320,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: IncubatorColors.border(context)),
          ),
          child: Row(
            children: [
              // Image de gauche
              SizedBox(
                width: 110,
                height: double.infinity,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (program.coverUrl != null && program.coverUrl!.isNotEmpty)
                        Image.network(program.coverUrl!, fit: BoxFit.cover)
                      else
                        Container(color: IncubatorColors.institutionalBlue, child: const Icon(Icons.school_rounded, color: Colors.white, size: 40)),
                      // Badge vert
                      Positioned(
                        top: 6, left: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(color: IncubatorColors.validationGreen, borderRadius: BorderRadius.circular(6)),
                          child: const Text('Candidatures\nouvertes', style: TextStyle(color: Colors.white, fontSize: 7, fontWeight: FontWeight.w900, height: 1.1)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Texte de droite
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      program.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: IncubatorColors.textPrimary(context), fontSize: 14, fontWeight: FontWeight.w900, height: 1.1),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Accompagnement, mentorat et développement commercial.',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: IncubatorColors.textSecondary(context), fontSize: 9, height: 1.2),
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        Icon(Icons.calendar_month_rounded, size: 12, color: IncubatorColors.textSecondary(context)),
                        const SizedBox(width: 4),
                        Text('Durée : 12 semaines', style: TextStyle(color: IncubatorColors.textSecondary(context), fontSize: 9, fontWeight: FontWeight.w600)),
                        const SizedBox(width: 10),
                        Icon(Icons.groups_rounded, size: 12, color: IncubatorColors.textSecondary(context)),
                        const SizedBox(width: 4),
                        Text('Places limitées', style: TextStyle(color: IncubatorColors.textSecondary(context), fontSize: 9, fontWeight: FontWeight.w600)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(color: IncubatorColors.nightBlue, borderRadius: BorderRadius.circular(8)),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('Voir le programme', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)),
                          SizedBox(width: 4),
                          Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 12),
                        ],
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
// ACCÈS RAPIDES
// ============================================================================
class _QuickAccessSliver extends StatelessWidget {
  const _QuickAccessSliver();

  static const _items = [
    (icon: Icons.rocket_launch_rounded, label: 'Programmes', route: AppRoutes.incubatorExplore, color: IncubatorColors.electricBlue),
    (icon: Icons.assignment_rounded, label: 'Mes candidatures', route: '${AppRoutes.incubator}/applications', color: IncubatorColors.purple),
    (icon: Icons.folder_rounded, label: 'Mes projets', route: '${AppRoutes.incubator}/projects', color: IncubatorColors.premiumGold),
    (icon: Icons.mic_rounded, label: 'Pitch Room', route: '${AppRoutes.incubator}/pitch', color: IncubatorColors.info),
    (icon: Icons.groups_rounded, label: 'Mentorat', route: '${AppRoutes.incubator}/mentors', color: IncubatorColors.validationGreen),
    (icon: Icons.forum_rounded, label: 'Communauté', route: AppRoutes.network, color: IncubatorColors.purple),
    (icon: Icons.bar_chart_rounded, label: 'Tableau\nde bord', route: '${AppRoutes.incubator}/dashboard', color: IncubatorColors.electricBlue),
  ];

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          children: [
            const _SectionTitle(title: 'Accès rapides'),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _items.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 0.85,
                ),
                itemBuilder: (context, index) {
                  final item = _items[index];
                  return Container(
                    decoration: BoxDecoration(
                      color: IncubatorColors.card(context),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: IncubatorColors.border(context)),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: item.color.withValues(alpha: 0.1), shape: BoxShape.circle),
                          child: Icon(item.icon, color: item.color, size: 22),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          item.label,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: IncubatorColors.textPrimary(context), fontSize: 9, fontWeight: FontWeight.w700, height: 1.1),
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
        if (activities.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());

        return SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              children: [
                _SectionTitle(title: 'Activité récente', actionLabel: 'Voir tout', onAction: () {}),
                const SizedBox(height: 10),
                ...activities.take(2).map((activity) => _ActivityItem(activity: activity)),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ActivityItem extends StatelessWidget {
  final IncubatorActivity activity;
  const _ActivityItem({required this.activity});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: IncubatorColors.card(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: IncubatorColors.border(context)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: const BoxDecoration(color: IncubatorColors.validationGreen, shape: BoxShape.circle),
            child: const Icon(Icons.check_rounded, color: Colors.white, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(activity.title, style: TextStyle(color: IncubatorColors.textPrimary(context), fontSize: 12, fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text('Votre dossier est en cours d\'examen par notre équipe.', style: TextStyle(color: IncubatorColors.textSecondary(context), fontSize: 10)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: IncubatorColors.premiumGold.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(6)),
                child: const Row(
                  children: [
                    Icon(Icons.access_time_rounded, size: 10, color: IncubatorColors.warning),
                    SizedBox(width: 4),
                    Text('En attente', style: TextStyle(color: IncubatorColors.warning, fontSize: 9, fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Text(activity.timeLabel, style: TextStyle(color: IncubatorColors.textSecondary(context), fontSize: 9)),
            ],
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// PARCOURS (TIMELINE)
// ============================================================================
class _JourneySliver extends StatelessWidget {
  const _JourneySliver();

  @override
  Widget build(BuildContext context) {
    final steps = [
      'Soumission\ndu projet',
      'Évaluation',
      'Sélection',
      'Incubation',
      'Pitch &\nDemo Day',
      'Post-incubation',
    ];

    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: IncubatorColors.nightBlue,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.emoji_events_rounded, color: IncubatorColors.premiumGold, size: 20),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text('Parcours de votre projet', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(border: Border.all(color: IncubatorColors.premiumGold), borderRadius: BorderRadius.circular(20)),
                  child: const Row(
                    children: [
                      Text('Voir le détail', style: TextStyle(color: IncubatorColors.premiumGold, fontSize: 9, fontWeight: FontWeight.w700)),
                      SizedBox(width: 4),
                      Icon(Icons.arrow_forward_rounded, color: IncubatorColors.premiumGold, size: 10),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 60,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: steps.length,
                separatorBuilder: (_, __) => Container(
                  width: 20,
                  height: 2,
                  margin: const EdgeInsets.only(top: 14),
                  color: Colors.white.withValues(alpha: 0.3),
                ),
                itemBuilder: (context, index) {
                  Color circleColor = Colors.white.withValues(alpha: 0.2);
                  Color textColor = Colors.white70;
                  
                  if (index == 0) { circleColor = IncubatorColors.validationGreen; textColor = Colors.white; }
                  if (index == 1) { circleColor = IncubatorColors.electricBlue; textColor = Colors.white; }
                  if (index == 2) { circleColor = IncubatorColors.warning; textColor = Colors.white; }

                  return Column(
                    children: [
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(color: circleColor, shape: BoxShape.circle, border: Border.all(color: Colors.white.withValues(alpha: 0.5))),
                        child: Center(
                          child: Text('${index + 1}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        steps[index],
                        textAlign: TextAlign.center,
                        style: TextStyle(color: textColor, fontSize: 9, height: 1.1, fontWeight: FontWeight.w600),
                      ),
                    ],
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
// BANNIÈRE DE FIN (Avec courbe dorée)
// ============================================================================
class _ClosingBannerSliver extends StatelessWidget {
  const _ClosingBannerSliver();

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        height: 90,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(colors: [IncubatorColors.nightBlue, IncubatorColors.institutionalBlue]),
        ),
        child: Stack(
          children: [
            // Courbe dorée à droite
            Positioned(
              right: -20,
              top: 0,
              bottom: 0,
              width: 140,
              child: ClipPath(
                clipper: _CurveClipper(),
                child: Container(color: IncubatorColors.premiumGold),
              ),
            ),
            // Logo à droite
            Positioned(
              right: 20,
              top: 0,
              bottom: 0,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.rocket_launch_rounded, color: IncubatorColors.nightBlue, size: 26),
                  Text('INCUBATOR', style: TextStyle(color: IncubatorColors.nightBlue, fontSize: 9, fontWeight: FontWeight.w900)),
                  Text('Innover. Entreprendre. Grandir.', style: TextStyle(color: IncubatorColors.nightBlue.withValues(alpha: 0.7), fontSize: 5, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            // Texte principal
            Positioned(
              left: 16,
              top: 0,
              bottom: 0,
              right: 140,
              child: Row(
                children: [
                  const Icon(Icons.emoji_events_rounded, color: IncubatorColors.premiumGold, size: 36),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Ensemble, construisons\nl\'innovation en Afrique.',
                      style: TextStyle(color: Colors.white, fontSize: 13, height: 1.2, fontWeight: FontWeight.w900),
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

class _CurveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    var path = Path();
    path.lineTo(size.width * 0.4, 0);
    path.quadraticBezierTo(size.width * 0.1, size.height / 2, size.width * 0.4, size.height);
    path.lineTo(size.width, size.height);
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

// ============================================================================
// WIDGETS UTILITAIRES
// ============================================================================
class _SectionTitle extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _SectionTitle({required this.title, this.actionLabel, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Container(width: 4, height: 18, decoration: BoxDecoration(color: IncubatorColors.electricBlue, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 8),
          Expanded(
            child: Text(title, style: TextStyle(color: IncubatorColors.textPrimary(context), fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: -0.3)),
          ),
          if (actionLabel != null && onAction != null)
            GestureDetector(
              onTap: onAction,
              child: Row(
                children: [
                  Text(actionLabel!, style: const TextStyle(color: IncubatorColors.institutionalBlue, fontSize: 11, fontWeight: FontWeight.w800)),
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_forward_rounded, color: IncubatorColors.institutionalBlue, size: 14),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ============================================================================
// BOTTOM NAVIGATION
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
        border: Border(top: BorderSide(color: IncubatorColors.border(context))),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 60,
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
                      Icon(item.icon, size: 22, color: selected ? IncubatorColors.electricBlue : IncubatorColors.textSecondary(context)),
                      const SizedBox(height: 4),
                      Text(
                        item.label,
                        style: TextStyle(
                          color: selected ? IncubatorColors.electricBlue : IncubatorColors.textSecondary(context),
                          fontSize: 9,
                          fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Container(
                        width: selected ? 20 : 0,
                        height: 3,
                        decoration: BoxDecoration(color: IncubatorColors.electricBlue, borderRadius: BorderRadius.circular(2)),
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

// ============================================================================
// SQUELETTE ET ERREURS
// ============================================================================
class _SkeletonBody extends StatelessWidget {
  const _SkeletonBody();
  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: IncubatorColors.border(context),
      highlightColor: IncubatorColors.card(context),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(height: 260, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20))),
            const SizedBox(height: 20),
            Container(height: 100, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16))),
            const SizedBox(height: 20),
            Container(height: 160, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16))),
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
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 50, color: IncubatorColors.danger),
            const SizedBox(height: 16),
            Text('Connexion impossible', style: TextStyle(color: IncubatorColors.textPrimary(context), fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Text('Vérifiez votre connexion puis réessayez.', textAlign: TextAlign.center, style: TextStyle(color: IncubatorColors.textSecondary(context), fontSize: 12)),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Réessayer'),
              style: ElevatedButton.styleFrom(backgroundColor: IncubatorColors.electricBlue, foregroundColor: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}
