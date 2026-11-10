// ============================================================================
// FICHIER : lib/presentation/thix_incubator/pages/incubator_home_page.dart
// Module  : thix_incubator — Route : /incubator
// Stack   : Riverpod moderne — 100% data-driven (Supabase)
// Design  : conforme maquette SONATHIX v1.0 (disposition + icônes + couleurs)
// ============================================================================

import 'dart:async';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';

import '../../../nav.dart';
import '../../../providers/incubator_provider.dart';
import '../../../models/incubator_activity.dart';
import '../../../models/incubator_application.dart';
import '../../../models/incubator_program.dart';
import '../../../models/incubator_project.dart';

// ============================================================================
// CHARTE COULEURS INCUBATOR (CdC SONATHIX GROUP)
// ============================================================================
@immutable
class IncubatorColors {
  const IncubatorColors._();

  static const Color institutionalBlue = Color(0xFF092C78);
  static const Color nightBlue         = Color(0xFF061B4D);
  static const Color electricBlue      = Color(0xFF1455D9);
  static const Color premiumGold       = Color(0xFFFFC107);
  static const Color goldDeep          = Color(0xFFF5A800);
  static const Color validationGreen   = Color(0xFF16A34A);
  static const Color greenSoft         = Color(0xFFE7F6EC);
  static const Color purple            = Color(0xFF8B5CF6);
  static const Color orange            = Color(0xFFF59E0B);

  static const Color surfaceLight      = Color(0xFFF4F7FC);
  static const Color cardLight         = Color(0xFFFFFFFF);
  static const Color borderLight       = Color(0xFFE3E9F2);
  static const Color statsBg           = Color(0xFFEDF2FA);

  static const Color darkSurface       = Color(0xFF0B1220);
  static const Color darkBackground    = Color(0xFF050A14);
  static const Color darkCard          = Color(0xFF111827);
  static const Color darkBorder        = Color(0xFF1F2937);

  static const Color textPrimaryLight  = Color(0xFF0E1B2E);
  static const Color textSecondaryLight = Color(0xFF5A6B84);
  static const Color textPrimaryDark   = Color(0xFFEAF2FF);
  static const Color textSecondaryDark = Color(0xFF9CB0D2);

  static const Color danger            = Color(0xFFDC2626);
  static const Color warning           = Color(0xFFF59E0B);

  static bool _dark(BuildContext c) =>
      Theme.of(c).brightness == Brightness.dark;
  static Color background(BuildContext c) =>
      _dark(c) ? darkBackground : surfaceLight;
  static Color card(BuildContext c) => _dark(c) ? darkCard : cardLight;
  static Color border(BuildContext c) => _dark(c) ? darkBorder : borderLight;
  static Color textPrimary(BuildContext c) =>
      _dark(c) ? textPrimaryDark : textPrimaryLight;
  static Color textSecondary(BuildContext c) =>
      _dark(c) ? textSecondaryDark : textSecondaryLight;
}

// ============================================================================
// PAGE PRINCIPALE
// ============================================================================
class IncubatorHomePage extends ConsumerStatefulWidget {
  const IncubatorHomePage({super.key});

  @override
  ConsumerState<IncubatorHomePage> createState() => _IncubatorHomePageState();
}

class _IncubatorHomePageState extends ConsumerState<IncubatorHomePage> {
  final PageController _heroCtrl = PageController();
  int _heroIndex = 0;
  Timer? _heroTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (ref.read(incubatorProvider).status == IncubatorStatus.idle) {
        ref.read(incubatorProvider.notifier).loadAll();
      }
    });
  }

  void _startHeroAuto(int count) {
    if (count <= 1 || _heroTimer != null) return;
    _heroTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || !_heroCtrl.hasClients) return;
      _heroIndex = (_heroIndex + 1) % count;
      _heroCtrl.animateToPage(_heroIndex,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeOutCubic);
      setState(() {});
    });
  }

  @override
  void dispose() {
    _heroTimer?.cancel();
    _heroCtrl.dispose();
    super.dispose();
  }

  Future<void> _onRefresh() async {
    await ref.read(incubatorProvider.notifier).loadAll(forceRefresh: true);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(incubatorProvider);

    return Scaffold(
      backgroundColor: IncubatorColors.background(context),
      body: SafeArea(
        bottom: false,
        child: _buildBody(state),
      ),
      bottomNavigationBar: const _BottomNav(currentIndex: 0),
    );
  }

  Widget _buildBody(IncubatorState state) {
    if (state.status == IncubatorStatus.loading && state.isFirstLoad) {
      return const _Skeleton();
    }
    if (state.status == IncubatorStatus.error && state.isEmpty) {
      return _ErrorState(
        message: state.error ?? '',
        onRetry: () => ref.read(incubatorProvider.notifier).loadAll(),
      );
    }
    return RefreshIndicator(
      color: IncubatorColors.electricBlue,
      onRefresh: _onRefresh,
      child: ListView(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        padding: EdgeInsets.zero,
        children: [
          const _TopHeader(),
          const _BrandBar(),
          _HeroBanner(state: state, ctrl: _heroCtrl, onIndexChanged: (i) {
            _heroIndex = i;
            setState(() {});
          }, heroIndex: _heroIndex, onReady: _startHeroAuto),
          _ProgressStats(state: state),
          _ProgramsSection(state: state),
          const _QuickAccessRail(),
          _ActivitySection(state: state),
          _JourneyCard(state: state),
          const _PromoBanner(),
          const SizedBox(height: 110),
        ],
      ),
    );
  }
}

// ============================================================================
// 1. HEADER NAVY — logo fusée + titre + recherche / notif / avatar
// ============================================================================
class _TopHeader extends ConsumerWidget {
  const _TopHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notif = ref.watch(incubatorProvider).unreadNotifications;
    return Container(
      color: IncubatorColors.institutionalBlue,
      padding: const EdgeInsets.fromLTRB(16, 10, 12, 14),
      child: Row(
        children: [
          const Icon(Icons.rocket_launch_rounded,
              color: IncubatorColors.premiumGold, size: 34),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('INCUBATOR',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5)),
                Text('Innover • Entreprendre • Grandir',
                    style: TextStyle(color: Colors.white70, fontSize: 10)),
              ],
            ),
          ),
          _HeaderIcon(icon: Icons.search_rounded, onTap: () {}),
          _HeaderIcon(
            icon: Icons.notifications_rounded,
            badge: notif > 0 ? notif : null,
            onTap: () => context.go(AppRoutes.networkNotifications),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: () => context.go(AppRoutes.profile),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                color: IncubatorColors.electricBlue,
              ),
              child: const Icon(Icons.person_rounded,
                  color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}
class _HeaderIcon extends StatelessWidget {
  const _HeaderIcon({required this.icon, required this.onTap, this.badge});
  final IconData icon;
  final VoidCallback onTap;
  final int? badge;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          onPressed: onTap,
          icon: Icon(icon, color: Colors.white, size: 22),
        ),
        if (badge != null)
          Positioned(
            right: 6,
            top: 6,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1),
              ),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              child: Text('$badge',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.w800)),
            ),
          ),
      ],
    );
  }
}

// ============================================================================
// 2. BARRE BLANCHE FLOTTANTE — menu | trophée + marque | pill verte | dots
// ============================================================================
class _BrandBar extends StatelessWidget {
  const _BrandBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: IncubatorColors.card(context),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.menu_rounded,
              color: IncubatorColors.textPrimaryLight, size: 22),
          const SizedBox(width: 10),
          Container(width: 1, height: 26, color: IncubatorColors.borderLight),
          const SizedBox(width: 10),
          const Icon(Icons.emoji_events_rounded,
              color: IncubatorColors.premiumGold, size: 26),
          const SizedBox(width: 8),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('INCUBATOR',
                    style: TextStyle(
                        color: IncubatorColors.institutionalBlue,
                        fontSize: 13,
                        fontWeight: FontWeight.w800)),
                Text('by SONATHIX GROUP',
                    style: TextStyle(
                        color: IncubatorColors.institutionalBlue,
                        fontSize: 8,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: IncubatorColors.greenSoft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.verified_user_rounded,
                    color: IncubatorColors.validationGreen, size: 14),
                SizedBox(width: 6),
                Text('Espace Entrepreneur',
                    style: TextStyle(
                        color: IncubatorColors.validationGreen,
                        fontSize: 11,
                        fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.more_vert_rounded,
              color: IncubatorColors.textSecondaryLight, size: 20),
        ],
      ),
    );
  }
}

// ============================================================================
// 3. HERO BANNER — texte + CTA or | image + dots carousel
// ============================================================================
class _HeroBanner extends StatefulWidget {
  const _HeroBanner({
    required this.state,
    required this.ctrl,
    required this.onIndexChanged,
    required this.heroIndex,
    required this.onReady,
  });
  final IncubatorState state;
  final PageController ctrl;
  final ValueChanged<int> onIndexChanged;
  final int heroIndex;
  final ValueChanged<int> onReady;

  @override
  State<_HeroBanner> createState() => _HeroBannerState();
}

class _HeroBannerState extends State<_HeroBanner> {
  @override
  void didUpdateWidget(covariant _HeroBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    final count = widget.state.openPrograms.length;
    if (count > 0) widget.onReady(count);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final count = widget.state.openPrograms.length;
      if (count > 0) widget.onReady(count);
    });
  }

  @override
  Widget build(BuildContext context) {
    final programs = widget.state.openPrograms;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 16),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            IncubatorColors.nightBlue,
            IncubatorColors.institutionalBlue,
            Color(0xFF0D3B9E),
          ],
        ),
      ),
      child: SizedBox(
        height: 300,
        child: Stack(
          children: [
            // ── Image droite (carousel des covers programmes) ──
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              width: 165,
              child: programs.isEmpty
                  ? const _HeroFallbackArt()
                  : PageView.builder(
                      controller: widget.ctrl,
                      itemCount: programs.length,
                      onPageChanged: widget.onIndexChanged,
                      itemBuilder: (_, i) => _HeroImage(program: programs[i]),
                    ),
            ),
            // Dégradé de fusion
            Positioned(
              right: 100,
              top: 0,
              bottom: 0,
              width: 90,
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        IncubatorColors.institutionalBlue,
                        IncubatorColors.institutionalBlue.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // ── Contenu gauche ──
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 30, 180, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text.rich(
                    TextSpan(children: [
                      TextSpan(
                        text: 'Transformez\nvotre idée en\n',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            height: 1.15),
                      ),
                      TextSpan(
                        text: 'entreprise.',
                        style: TextStyle(
                            color: IncubatorColors.premiumGold,
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            height: 1.15),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Découvrez les programmes, développez vos projets et accédez aux opportunités qui feront grandir votre ambition.',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 11.5,
                        height: 1.45),
                  ),
                  const SizedBox(height: 18),
                  GestureDetector(
                    onTap: () => context.go(AppRoutes.incubatorExplore),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 12),
                      decoration: BoxDecoration(
                        color: IncubatorColors.premiumGold,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.rocket_launch_rounded,
                              color: IncubatorColors.nightBlue, size: 16),
                          SizedBox(width: 8),
                          Text('Explorer les programmes',
                              style: TextStyle(
                                  color: IncubatorColors.nightBlue,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800)),
                          SizedBox(width: 6),
                          Icon(Icons.arrow_forward_rounded,
                              color: IncubatorColors.nightBlue, size: 14),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // ── Dots carousel ──
            if (programs.length > 1)
              Positioned(
                right: 14,
                bottom: 12,
                child: Row(
                  children: List.generate(programs.length, (i) {
                    final sel = i == widget.heroIndex;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: sel ? 8 : 7,
                      height: sel ? 8 : 7,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: sel
                            ? IncubatorColors.premiumGold
                            : Colors.white.withValues(alpha: 0.6),
                      ),
                    );
                  }),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _HeroImage extends StatelessWidget {
  const _HeroImage({required this.program});
  final IncubatorProgram program;

  @override
  Widget build(BuildContext context) {
    if (program.coverUrl == null || program.coverUrl!.isEmpty) {
      return const _HeroFallbackArt();
    }
    return Image.network(
      program.coverUrl!,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => const _HeroFallbackArt(),
      loadingBuilder: (_, child, progress) =>
          progress == null ? child : const _HeroFallbackArt(),
    );
  }
}

class _HeroFallbackArt extends StatelessWidget {
  const _HeroFallbackArt();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            IncubatorColors.electricBlue,
            IncubatorColors.institutionalBlue,
          ],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            top: 30,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: IncubatorColors.institutionalBlue,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Column(
                children: [
                  Icon(Icons.rocket_launch_rounded,
                      color: IncubatorColors.premiumGold, size: 30),
                  SizedBox(height: 6),
                  Text('INCUBATOR',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w800)),
                  Text('Innovation\npour l\'Afrique',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70, fontSize: 8)),
                ],
              ),
            ),
          ),
          const Positioned(
            left: 20,
            bottom: 40,
            child: Icon(Icons.person_rounded,
                color: Colors.white24, size: 110),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// 4. TITRE DE SECTION (barre bleue + titre + lien optionnel)
// ============================================================================
// ✅ VERSION CORRIGÉE (sans const sur le Container problématique)
class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, this.linkLabel, this.onLink});
  final String title;
  final String? linkLabel;
  final VoidCallback? onLink;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 10),
      child: Row(
        children: [
          // ✅ PAS DE CONST ICI — BorderRadius.circular(2) n'est pas const-constructible
          Container(
            width: 4,
            height: 18,
            decoration: BoxDecoration(
              color: IncubatorColors.electricBlue,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(title,
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: IncubatorColors.textPrimary(context))),
          ),
          if (linkLabel != null && onLink != null)
            GestureDetector(
              onTap: onLink,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(linkLabel!,
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: IncubatorColors.electricBlue)),
                  const SizedBox(width: 2),
                  const Icon(Icons.arrow_forward_rounded,
                      size: 14, color: IncubatorColors.electricBlue),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ============================================================================
// 5. MON ESPACE DE PROGRESSION — 4 stats avec séparateurs verticaux
// ============================================================================
class _ProgressStats extends StatelessWidget {
  const _ProgressStats({required this.state});
  final IncubatorState state;

  @override
  Widget build(BuildContext context) {
    final pitches = state.projects
        .where((p) => p.stage == IncubatorStage.pitching)
        .length;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 4),
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? IncubatorColors.darkCard
            : IncubatorColors.statsBg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 18,
                  decoration: BoxDecoration(
                    color: IncubatorColors.electricBlue,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                SizedBox(width: 8),
                Text('Mon espace de progression',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: IncubatorColors.textPrimaryLight)),
              ],
            ),
          ),
          Row(
            children: [
              _StatCell(
                icon: Icons.folder_rounded,
                color: IncubatorColors.electricBlue,
                value: state.myProjectsCount.toString().padLeft(2, '0'),
                label: 'Mes projets',
              ),
              _divider(context),
              _StatCell(
                icon: Icons.assignment_turned_in_rounded,
                color: IncubatorColors.validationGreen,
                value: state.myApplicationsCount.toString().padLeft(2, '0'),
                label: 'Candidatures',
              ),
              _divider(context),
              _StatCell(
                icon: Icons.insert_chart_rounded,
                color: IncubatorColors.purple,
                value: pitches.toString().padLeft(2, '0'),
                label: 'Pitchs préparés',
              ),
              _divider(context),
              _StatCell(
                icon: Icons.trending_up_rounded,
                color: IncubatorColors.premiumGold,
                value: '${state.averageProgressPercent}%',
                label: 'Progression globale',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _divider(BuildContext context) => Container(
        width: 1,
        height: 46,
        color: Theme.of(context).brightness == Brightness.dark
            ? IncubatorColors.darkBorder
            : const Color(0xFFD7DEE9),
      );
}

class _StatCell extends StatelessWidget {
  const _StatCell({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
  });
  final IconData icon;
  final Color color;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: color, size: 30),
          const SizedBox(height: 6),
          Text(value,
              style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: IncubatorColors.textPrimary(context))),
          const SizedBox(height: 2),
          Text(label,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 10,
                  color: IncubatorColors.textSecondary(context))),
        ],
      ),
    );
  }
}

// ============================================================================
// 6. PROGRAMMES DISPONIBLES — carte horizontale image + badge + CTA
// ============================================================================
class _ProgramsSection extends StatelessWidget {
  const _ProgramsSection({required this.state});
  final IncubatorState state;

  @override
  Widget build(BuildContext context) {
    final programs = state.openPrograms;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(
          title: 'Programmes disponibles',
          linkLabel: 'Voir tous',
          onLink: () => context.go(AppRoutes.incubatorExplore),
        ),
        if (programs.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: IncubatorColors.card(context),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: IncubatorColors.border(context)),
              ),
              child: Text(
                'Aucun programme ouvert pour le moment.',
                style: TextStyle(
                    fontSize: 12,
                    color: IncubatorColors.textSecondary(context)),
              ),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: _ProgramCard(program: programs.first),
          ),
      ],
    );
  }
}

class _ProgramCard extends StatelessWidget {
  const _ProgramCard({required this.program});
  final IncubatorProgram program;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: IncubatorColors.card(context),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Image gauche + badge ──
            SizedBox(
              width: 165,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (program.coverUrl != null && program.coverUrl!.isNotEmpty)
                    Image.network(program.coverUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const _CoverFallback())
                  else
                    const _CoverFallback(),
                  Positioned(
                    top: 10,
                    left: 10,
                    right: 10,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: IncubatorColors.validationGreen,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_rounded,
                                color: Colors.white, size: 13),
                            SizedBox(width: 5),
                            Text('Candidatures ouvertes',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // ── Contenu droit ──
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(program.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            height: 1.2,
                            color: IncubatorColors.institutionalBlue)),
                    const SizedBox(height: 6),
                    Text(
                      program.description.isEmpty
                          ? program.organizer
                          : program.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 11.5,
                          height: 1.35,
                          color: IncubatorColors.textSecondary(context)),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.calendar_today_rounded,
                            size: 12,
                            color: IncubatorColors.institutionalBlue),
                        const SizedBox(width: 4),
                        Text('Durée : ${program.durationWeeks} semaines',
                            style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: IncubatorColors.textPrimaryLight)),
                        const SizedBox(width: 8),
                        const Text('•',
                            style: TextStyle(
                                color: IncubatorColors.textSecondaryLight)),
                        const SizedBox(width: 8),
                        const Icon(Icons.group_rounded,
                            size: 13,
                            color: IncubatorColors.institutionalBlue),
                        const SizedBox(width: 4),
                        Text(
                            program.seatsRemaining < program.totalSeats
                                ? 'Places limitées'
                                : '${program.seatsRemaining} places',
                            style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: IncubatorColors.textPrimaryLight)),
                      ],
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => context
                          .push(AppRoutes.incubatorProgram(program.id)),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        decoration: BoxDecoration(
                          color: IncubatorColors.institutionalBlue,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('Voir le programme',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700)),
                            SizedBox(width: 6),
                            Icon(Icons.arrow_forward_rounded,
                                color: Colors.white, size: 14),
                          ],
                        ),
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

class _CoverFallback extends StatelessWidget {
  const _CoverFallback();
  @override
  Widget build(BuildContext context) => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              IncubatorColors.institutionalBlue,
              IncubatorColors.electricBlue,
            ],
          ),
        ),
        child: const Center(
          child: Icon(Icons.groups_rounded, color: Colors.white38, size: 54),
        ),
      );
}

// ============================================================================
// 7. ACCÈS RAPIDES — rail horizontal 7 tuiles
// ============================================================================
class _QuickAccessRail extends StatelessWidget {
  const _QuickAccessRail();

  static const List<({IconData icon, String label, String route, Color color})>
      _items = [
    (icon: Icons.rocket_launch_rounded, label: 'Programmes',       route: AppRoutes.incubatorExplore,      color: IncubatorColors.electricBlue),
    (icon: Icons.description_rounded,   label: 'Mes candidatures', route: '/incubator/applications',       color: IncubatorColors.purple),
    (icon: Icons.folder_rounded,        label: 'Mes projets',      route: '/incubator/projects',           color: IncubatorColors.premiumGold),
    (icon: Icons.mic_rounded,           label: 'Pitch Room',       route: '/incubator/pitch',              color: IncubatorColors.electricBlue),
    (icon: Icons.group_rounded,         label: 'Mentorat',         route: '/incubator/mentors',            color: IncubatorColors.validationGreen),
    (icon: Icons.forum_rounded,         label: 'Communauté',       route: AppRoutes.network,               color: IncubatorColors.purple),
    (icon: Icons.bar_chart_rounded,     label: 'Tableau de bord',  route: '/incubator/dashboard',          color: IncubatorColors.electricBlue),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle(title: 'Accès rapides'),
        SizedBox(
          height: 92,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: _items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, i) {
              final it = _items[i];
              return GestureDetector(
                onTap: () => context.go(it.route),
                child: Container(
                  width: 82,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: IncubatorColors.card(context),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: IncubatorColors.border(context)),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(it.icon, color: it.color, size: 26),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text(it.label,
                            maxLines: 2,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w600,
                                color: IncubatorColors.textPrimary(context))),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// 8. ACTIVITÉ RÉCENTE — ligne icône verte + pill or + horodatage
// ============================================================================
class _ActivitySection extends StatelessWidget {
  const _ActivitySection({required this.state});
  final IncubatorState state;

  @override
  Widget build(BuildContext context) {
    final acts = state.recentActivities;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(
          title: 'Activité récente',
          linkLabel: 'Voir tout',
          onLink: () => context.go('${AppRoutes.incubator}/activities'),
        ),
        if (acts.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text('Aucune activité pour le moment.',
                style: TextStyle(
                    fontSize: 12,
                    color: IncubatorColors.textSecondary(context))),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Column(
              children: acts.map((a) => _ActivityRow(activity: a)).toList(),
            ),
          ),
      ],
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.activity});
  final IncubatorActivity activity;

  @override
  Widget build(BuildContext context) {
    final (pillLabel, pillColor, pillIcon) = switch (activity.type) {
      'application_submitted' => ('En attente', IncubatorColors.premiumGold, Icons.schedule_rounded),
      'stage_changed'         => ('En cours', IncubatorColors.electricBlue, Icons.refresh_rounded),
      'mentor_assigned'       => ('Mentorat', IncubatorColors.validationGreen, Icons.group_rounded),
      'pitch_scheduled'       => ('Pitch', IncubatorColors.purple, Icons.mic_rounded),
      _                       => ('En attente', IncubatorColors.premiumGold, Icons.schedule_rounded),
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? IncubatorColors.darkCard
            : IncubatorColors.statsBg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: IncubatorColors.validationGreen,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_rounded, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(activity.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: IncubatorColors.textPrimary(context))),
                const SizedBox(height: 3),
                Text(
                    activity.subtitle ??
                        'Votre dossier est en cours d\'examen par notre équipe.',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 11,
                        color: IncubatorColors.textSecondary(context))),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: pillColor,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(pillIcon, color: Colors.white, size: 12),
                    const SizedBox(width: 4),
                    Text(pillLabel,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Text(activity.timeLabel,
                  style: TextStyle(
                      fontSize: 10,
                      color: IncubatorColors.textSecondary(context))),
            ],
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// 9. PARCOURS DE VOTRE PROJET — carte navy + stepper 6 étapes
// ============================================================================
class _JourneyCard extends StatelessWidget {
  const _JourneyCard({required this.state});
  final IncubatorState state;

  static const List<String> _labels = [
    'Soumission\ndu projet',
    'Évaluation',
    'Sélection',
    'Incubation',
    'Pitch &\nDemo Day',
    'Post-incubation',
  ];

  int _currentStep(IncubatorState state) {
    if (state.projects.isEmpty) return 1;
    final maxIdx = state.projects
        .map((p) => p.stage.index + 1)
        .reduce((a, b) => a > b ? a : b);
    return maxIdx.clamp(1, 6);
  }

  @override
  Widget build(BuildContext context) {
    final current = _currentStep(state);
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
      decoration: BoxDecoration(
        color: IncubatorColors.nightBlue,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.emoji_events_rounded,
                  color: IncubatorColors.premiumGold, size: 24),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('Parcours de votre projet',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w800)),
              ),
              GestureDetector(
                onTap: () => context.go('${AppRoutes.incubator}/projects'),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: IncubatorColors.premiumGold, width: 1.2),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Voir le détail',
                          style: TextStyle(
                              color: IncubatorColors.premiumGold,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700)),
                      SizedBox(width: 4),
                      Icon(Icons.arrow_forward_rounded,
                          color: IncubatorColors.premiumGold, size: 12),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: List.generate(6, (i) {
              final step = i + 1;
              return Expanded(
                child: Column(
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: i == 0
                                  ? const SizedBox.shrink()
                                  : Container(
                                      height: 2,
                                      color: step <= current
                                          ? IncubatorColors.validationGreen
                                          : Colors.white24),
                            ),
                            const SizedBox(width: 26),
                            Expanded(
                              child: i == 5
                                  ? const SizedBox.shrink()
                                  : Container(
                                      height: 2,
                                      color: step < current
                                          ? IncubatorColors.validationGreen
                                          : Colors.white24),
                            ),
                          ],
                        ),
                        Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            color: _stepColor(step, current),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text('$step',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(_labels[i],
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 9,
                            height: 1.25,
                            fontWeight: FontWeight.w600,
                            color: step <= current
                                ? Colors.white
                                : Colors.white54)),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Color _stepColor(int step, int current) {
    if (step < current) return IncubatorColors.validationGreen;
    if (step == current) return IncubatorColors.electricBlue;
    if (step == current + 1) return IncubatorColors.orange;
    return const Color(0xFF8A94A6);
  }
}

// ============================================================================
// 10. BANNIÈRE PROMO — bleu / or en diagonale + trophée
// ============================================================================
class _PromoBanner extends StatelessWidget {
  const _PromoBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      height: 110,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          colors: [IncubatorColors.nightBlue, IncubatorColors.institutionalBlue],
        ),
      ),
      child: Stack(
        children: [
          // Zone or diagonale à droite
          Positioned.fill(
            child: CustomPaint(painter: _GoldDiagonalPainter()),
          ),
          // Contenu droite (sur or)
          Positioned(
            right: 18,
            top: 0,
            bottom: 0,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.rocket_launch_rounded,
                      color: IncubatorColors.nightBlue, size: 26),
                  const SizedBox(height: 4),
                  const Text('INCUBATOR',
                      style: TextStyle(
                          color: IncubatorColors.nightBlue,
                          fontSize: 11,
                          fontWeight: FontWeight.w800)),
                  Text('Innover. Entreprendre. Grandir.',
                      style: TextStyle(
                          color: IncubatorColors.nightBlue.withValues(alpha: 0.75),
                          fontSize: 6.5,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
          // Contenu gauche (sur bleu)
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 130, 0),
            child: Row(
              children: [
                const Icon(Icons.emoji_events_rounded,
                    color: IncubatorColors.premiumGold, size: 52),
                const SizedBox(width: 14),
                const Expanded(
                  child: Text.rich(
                    TextSpan(children: [
                      TextSpan(
                        text: 'Ensemble, construisons\nl\'innovation ',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                            height: 1.3),
                      ),
                      TextSpan(
                        text: 'en Afrique.',
                        style: TextStyle(
                            color: IncubatorColors.premiumGold,
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                            height: 1.3),
                      ),
                    ]),
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

class _GoldDiagonalPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = IncubatorColors.premiumGold;
    final path = Path()
      ..moveTo(size.width * 0.66, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(size.width * 0.58, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ============================================================================
// 11. BOTTOM NAV — 5 onglets, actif bleu + underline
// ============================================================================
class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.currentIndex});
  final int currentIndex;

  static const List<({IconData icon, IconData activeIcon, String label, String? route})>
      _tabs = [
    (icon: Icons.home_outlined,     activeIcon: Icons.home_rounded,     label: 'Accueil',     route: null),
    (icon: Icons.explore_outlined,  activeIcon: Icons.explore_rounded,  label: 'Explorer',    route: AppRoutes.incubatorExplore),
    (icon: Icons.work_outline_rounded, activeIcon: Icons.work_rounded,  label: 'Mes projets', route: '/incubator/projects'),
    (icon: Icons.insert_chart_outlined, activeIcon: Icons.insert_chart_rounded, label: 'Pitch', route: '/incubator/pitch'),
    (icon: Icons.person_outline_rounded, activeIcon: Icons.person_rounded, label: 'Profil',   route: AppRoutes.profile),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: IncubatorColors.card(context),
        border: Border(
          top: BorderSide(color: IncubatorColors.border(context)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 62,
          child: Row(
            children: List.generate(_tabs.length, (i) {
              final t = _tabs[i];
              final active = i == currentIndex;
              return Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: t.route == null ? null : () => context.go(t.route!),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        active ? t.activeIcon : t.icon,
                        color: active
                            ? IncubatorColors.electricBlue
                            : IncubatorColors.textSecondary(context),
                        size: 22,
                      ),
                      const SizedBox(height: 3),
                      Text(t.label,
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight:
                                  active ? FontWeight.w800 : FontWeight.w500,
                              color: active
                                  ? IncubatorColors.electricBlue
                                  : IncubatorColors.textSecondary(context))),
                      Container(
                        margin: const EdgeInsets.only(top: 3),
                        width: 26,
                        height: 2.5,
                        decoration: BoxDecoration(
                          color: active
                              ? IncubatorColors.electricBlue
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(2),
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

// ============================================================================
// ÉTATS : SKELETON / ERROR
// ============================================================================
class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: IncubatorColors.border(context),
      highlightColor: IncubatorColors.card(context),
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Container(height: 54, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14))),
          const SizedBox(height: 12),
          Container(height: 260, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22))),
          const SizedBox(height: 12),
          Container(height: 110, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16))),
          const SizedBox(height: 12),
          Container(height: 170, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16))),
          const SizedBox(height: 12),
          Container(height: 92, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14))),
          const SizedBox(height: 12),
          Container(height: 130, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18))),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off_rounded,
                size: 52, color: IncubatorColors.danger),
            const SizedBox(height: 16),
            Text('Connexion impossible',
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: IncubatorColors.textPrimary(context))),
            if (kDebugMode) ...[
              const SizedBox(height: 8),
              Text(message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 10, fontFamily: 'monospace')),
            ],
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Réessayer'),
              style: ElevatedButton.styleFrom(
                backgroundColor: IncubatorColors.electricBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
