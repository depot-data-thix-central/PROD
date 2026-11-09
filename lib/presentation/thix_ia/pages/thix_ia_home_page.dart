// lib/presentation/thix_ia/pages/thix_ia_home_page.dart
//
// ThixIaHomePage — "PRISM LIGHT v3" (Production Enterprise) — CORRIGÉ CI
//
// Corrections appliquées :
//   • Parenthèses équilibrées sur les slivers animés
//   • .animate() déplacé DANS le child du SliverToBoxAdapter
//     (un Sliver ne peut JAMAIS être wrappé par un widget non-sliver)
//
// Design « Prism Light » :
//   • Header glass flottant (blur + pill) qui se densifie au scroll
//   • Hero AURORA : dégradé animé en boucle + particules flottantes
//   • SPOTLIGHT BUSINESS : carte gradient ultra-visible
//   • Bento grid des actions (hiérarchie visuelle Idée > autres)
//   • Moteurs : puces v2 + puce BUSINESS gradient en première position
//   • Analyses récentes : anneaux de progression
//   • Stats : tuiles icônes gradient + nombres forts
//   • FAB BUSINESS scroll-reactive : apparaît quand l'utilisateur glisse
//
// Logique 100 % préservée : providers, sanitizer, logger, i18n (args: []),
// haptics, semantics, routes ThixIARoutes, ThixPolicy.

import 'dart:math' as math;
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/l10n/app_localizations.dart';

import '../core/constants/thix_ia_routes.dart';
import '../models/thix_project.dart';
import '../providers/thix_ia_provider.dart';
import '../providers/analysis_provider.dart';

// ============================================================================
// ROUTES BUSINESS (module thix_portfolio)
// ============================================================================

const String _kRouteBusinessCreate = '/business/create';
const String _kRouteBusinessMine = '/business/mine';

// ============================================================================
// PALETTE « PRISM LIGHT »
// ============================================================================

class _Prism {
  _Prism._();

  static const Color bg = Color(0xFFF6F7FB);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color border = Color(0xFFE6E9F2);

  static const Color ink = Color(0xFF0B1220);
  static const Color inkSoft = Color(0xFF3E4C63);
  static const Color inkMuted = Color(0xFF8A94A6);

  static const Color violet = Color(0xFF7C3AED);
  static const Color cyan = Color(0xFF06B6D4);
  static const Color amber = Color(0xFFF59E0B);

  static const LinearGradient brand = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [ThixPolicy.primary, Color(0xFF4338CA), _Prism.violet],
  );

  static const LinearGradient business = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0EA5E9), ThixPolicy.primary, Color(0xFF4338CA)],
  );

  static List<BoxShadow> soft([double a = 0.05, double b = 14, double y = 6]) =>
      [
        BoxShadow(
          color: Colors.black.withValues(alpha: a),
          blurRadius: b,
          offset: Offset(0, y),
        ),
      ];
}

// ============================================================================
// CONSTANTS / LOGGING / SANITIZER
// ============================================================================

const int _kMaxNameLength = 60;
const int _kMaxRoleLength = 40;
const int _kMaxCodeLength = 24;
const int _kMaxSectorLength = 40;

class _IaHomeLogger {
  static const _tag = 'IaHomePrism';
  static void info(String m, [Map<String, dynamic>? d]) => _log('INFO', m, d);
  static void warn(String m, [Map<String, dynamic>? d]) => _log('WARN', m, d);
  static void error(String m, [Map<String, dynamic>? d]) => _log('ERROR', m, d);
  static void _log(String l, String m, Map<String, dynamic>? d) {
    if (!kDebugMode && l == 'INFO') return;
    final data = d != null
        ? ' ${d.entries.map((e) => '${e.key}=${e.value}').join(', ')}'
        : '';
    debugPrint('[$_tag] [$l] $m$data');
  }
}

class _Sanitizer {
  _Sanitizer._();

  static String text(String? input, {required int maxLength}) {
    if (input == null) return '';
    final s = input.replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '').trim();
    return s.length > maxLength ? s.substring(0, maxLength) : s;
  }

  static String errorMessage(Object error) {
    final msg = error.toString();
    if (msg.length > 120) return '${msg.substring(0, 120)}…';
    return msg;
  }
}

// ============================================================================
// ENUM / PROVIDER
// ============================================================================

enum ThixQuickAction { idea, market, businessPlan, legal }

final thixIaCurrentProfileProvider =
    FutureProvider<Map<String, dynamic>?>((ref) async {
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) return null;
  try {
    final row = await Supabase.instance.client
        .from('profiles')
        .select('id, thix_id, display_name, full_name, avatar_url, photo_url, '
            'occupation, profession, city, country, role_title')
        .eq('id', user.id)
        .maybeSingle();
    if (row != null) return row;
  } catch (e) {
    _IaHomeLogger.warn('Profile fetch failed', {'error': '$e'});
  }
  return {
    'id': user.id,
    'display_name': _Sanitizer.text(
        user.userMetadata?['display_name'] ??
            user.email?.split('@').first ??
            'Utilisateur',
        maxLength: _kMaxNameLength),
    'avatar_url': user.userMetadata?['avatar_url'],
  };
});

// ============================================================================
// PAGE PRINCIPALE
// ============================================================================

class ThixIaHomePage extends ConsumerStatefulWidget {
  const ThixIaHomePage({super.key});
  @override
  ConsumerState<ThixIaHomePage> createState() => _ThixIaHomePageState();
}

class _ThixIaHomePageState extends ConsumerState<ThixIaHomePage> {
  final ScrollController _scrollController = ScrollController();
  bool _showBizFab = false;
  bool _headerDense = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    Future.microtask(() => ref.read(projectsProvider.notifier).refresh());
    _IaHomeLogger.info('Home initialized (Prism Light v3)');
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  /// FAB Business : visible dès que l'utilisateur GLISSE (> 220 px).
  void _onScroll() {
    final o = _scrollController.offset;
    final show = o > 220;
    final dense = o > 40;
    if (show != _showBizFab || dense != _headerDense) {
      setState(() {
        _showBizFab = show;
        _headerDense = dense;
      });
    }
  }

  Future<void> _onQuickAction(ThixQuickAction action) async {
    final l10n = AppLocalizations.of(context);
    final projects = ref.read(projectsProvider).value ?? [];

    if (projects.isEmpty) {
      if (!mounted) return;
      final go = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: _Prism.surface,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text(l10n.t('ia_home_no_project_title'),
              style: const TextStyle(
                  color: _Prism.ink, fontWeight: FontWeight.w800)),
          content: Text(l10n.t('ia_home_no_project_message'),
              style: const TextStyle(color: _Prism.inkSoft)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.t('common_cancel'),
                  style: const TextStyle(color: _Prism.inkSoft)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: ThixPolicy.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: Text(l10n.t('ia_home_create_project')),
            ),
          ],
        ),
      );
      if (go == true && mounted) {
        HapticFeedback.mediumImpact();
        context.push(ThixIARoutes.createProject);
      }
      return;
    }

    if (!mounted) return;
    final selected = await showModalBottomSheet<ThixProject>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ProjectPickerSheet(
        projects: projects,
        title: _actionTitle(action, l10n),
      ),
    );
    if (selected == null || !mounted) return;

    await ref
        .read(activeProjectProvider.notifier)
        .setActive(selected.projectCode);

    if (!mounted) return;
    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const _LoadingDialog());

    try {
      final analyses = ref.read(analysesProvider.notifier);
      switch (action) {
        case ThixQuickAction.idea:
        case ThixQuickAction.market:
          await analyses.startMarketAnalysis(
              country: selected.country, sector: selected.sector);
          break;
        case ThixQuickAction.businessPlan:
          await analyses.startFinanceAnalysis(inputs: {
            'sector': selected.sector,
            'country': selected.country
          });
          break;
        case ThixQuickAction.legal:
          await analyses.startLegalAnalysis(
              jurisdiction: selected.country, sector: selected.sector);
          break;
      }

      if (mounted) Navigator.of(context).pop();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(l10n.t('ia_home_analysis_started',
              args: [
                _Sanitizer.text(selected.projectCode,
                    maxLength: _kMaxCodeLength)
              ])),
          backgroundColor: ThixPolicy.success,
          behavior: SnackBarBehavior.floating,
        ));
        context.push(ThixIARoutes.projectDetailPath(selected.projectCode));
      }
    } catch (e) {
      if (mounted) Navigator.of(context).pop();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(l10n.t('ia_home_analysis_error',
              args: [_Sanitizer.errorMessage(e)])),
          backgroundColor: ThixPolicy.danger,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  String _actionTitle(ThixQuickAction a, AppLocalizations l10n) {
    switch (a) {
      case ThixQuickAction.idea:
        return l10n.t('ia_action_idea');
      case ThixQuickAction.market:
        return l10n.t('ia_action_market');
      case ThixQuickAction.businessPlan:
        return l10n.t('ia_action_business_plan');
      case ThixQuickAction.legal:
        return l10n.t('ia_action_legal');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final projectsAsync = ref.watch(projectsProvider);
    final profileAsync = ref.watch(thixIaCurrentProfileProvider);

    return Scaffold(
      backgroundColor: _Prism.bg,
      body: Stack(
        children: [
          // Halos d'ambiance (repaint isolés)
          Positioned(
              top: -120,
              right: -70,
              child: _halo(260, ThixPolicy.primary.withValues(alpha: 0.14))),
          Positioned(
              top: 240,
              left: -110,
              child: _halo(300, _Prism.violet.withValues(alpha: 0.10))),
          Positioned(
              bottom: -80,
              right: -60,
              child: _halo(220, _Prism.cyan.withValues(alpha: 0.08))),

          SafeArea(
            bottom: false,
            child: RefreshIndicator(
              color: ThixPolicy.primary,
              backgroundColor: _Prism.surface,
              onRefresh: () async {
                HapticFeedback.mediumImpact();
                ref.invalidate(thixIaCurrentProfileProvider);
                await ref.read(projectsProvider.notifier).refresh();
              },
              child: CustomScrollView(
                controller: _scrollController,
                physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics()),
                slivers: [
                  SliverToBoxAdapter(
                      child: _GlassHeader(
                          profileAsync: profileAsync, dense: _headerDense)),
                  SliverToBoxAdapter(
                      child: _UserHeader(profileAsync: profileAsync)),
                  const SliverToBoxAdapter(child: SizedBox(height: 18)),

                  // ✅ FIX CI : .animate() DANS le child du sliver
                  SliverToBoxAdapter(
                    child: _AuroraHero(onAnalyze: () {
                      HapticFeedback.mediumImpact();
                      context.push(ThixIARoutes.createProject);
                    })
                        .animate()
                        .fadeIn(duration: 500.ms)
                        .slideY(
                            begin: 0.06,
                            duration: 500.ms,
                            curve: Curves.easeOutCubic),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 16)),

                  // ⭐ SPOTLIGHT BUSINESS — ✅ FIX CI : idem
                  SliverToBoxAdapter(
                    child: _BusinessSpotlight(
                      onCreate: () {
                        HapticFeedback.mediumImpact();
                        context.push(_kRouteBusinessCreate);
                      },
                      onMine: () {
                        HapticFeedback.selectionClick();
                        context.push(_kRouteBusinessMine);
                      },
                    )
                        .animate(delay: 80.ms)
                        .fadeIn(duration: 500.ms)
                        .slideY(
                            begin: 0.08,
                            duration: 500.ms,
                            curve: Curves.easeOutCubic),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 26)),

                  SliverToBoxAdapter(
                      child: _SectionTitle(l10n.t('ia_home_section_intent'))),
                  const SliverToBoxAdapter(child: SizedBox(height: 12)),
                  SliverToBoxAdapter(
                      child: _BentoActions(onAction: _onQuickAction)),
                  const SliverToBoxAdapter(child: SizedBox(height: 26)),

                  SliverToBoxAdapter(
                      child: _SectionTitle(
                          l10n.t('ia_home_section_engines'),
                          seeAll: true,
                          onSeeAll: () {
                            HapticFeedback.selectionClick();
                            context.push(ThixIARoutes.projects);
                          })),
                  const SliverToBoxAdapter(child: SizedBox(height: 12)),
                  const SliverToBoxAdapter(
                      child: RepaintBoundary(child: _MotorsRow())),
                  const SliverToBoxAdapter(child: SizedBox(height: 26)),

                  SliverToBoxAdapter(
                      child: _SectionTitle(
                          l10n.t('ia_home_section_recent'),
                          seeAll: true,
                          onSeeAll: () {
                            HapticFeedback.selectionClick();
                            context.push(ThixIARoutes.projects);
                          })),
                  const SliverToBoxAdapter(child: SizedBox(height: 12)),
                  SliverToBoxAdapter(
                      child: RepaintBoundary(
                          child: _RecentAnalyses(
                        projectsAsync: projectsAsync,
                        onOpen: (c) =>
                            context.push(ThixIARoutes.projectDetailPath(c)),
                        onCreate: () =>
                            context.push(ThixIARoutes.createProject),
                      ))),
                  const SliverToBoxAdapter(child: SizedBox(height: 26)),

                  SliverToBoxAdapter(
                      child: _SectionTitle(l10n.t('ia_home_section_stats'))),
                  const SliverToBoxAdapter(child: SizedBox(height: 12)),
                  SliverToBoxAdapter(
                      child: RepaintBoundary(
                          child: _QuickStats(projectsAsync: projectsAsync))),
                  const SliverToBoxAdapter(child: SizedBox(height: 96)),
                ],
              ),
            ),
          ),

          // ⭐ FAB BUSINESS — apparaît quand on glisse
          Positioned(
            right: 20,
            bottom: 28,
            child: _BusinessFab(
              visible: _showBizFab,
              onTap: () {
                HapticFeedback.mediumImpact();
                context.push(_kRouteBusinessCreate);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _halo(double s, Color c) {
    return RepaintBoundary(
      child: SizedBox(
        width: s,
        height: s,
        child: Stack(
          children: [
            Container(
                decoration: BoxDecoration(shape: BoxShape.circle, color: c)),
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
              child: Container(color: Colors.transparent),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// HEADER GLASS FLOTTANT
// ============================================================================

class _GlassHeader extends StatelessWidget {
  const _GlassHeader({required this.profileAsync, required this.dense});
  final AsyncValue<Map<String, dynamic>?> profileAsync;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final p = profileAsync.valueOrNull;
    final city = (p?['city'] as String?)?.trim();
    final country = (p?['country'] as String?)?.trim();
    final loc = [
      if (city != null && city.isNotEmpty) city,
      if (country != null && country.isNotEmpty) country
    ].join(', ');

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      margin: EdgeInsets.fromLTRB(16, 10, 16, dense ? 10 : 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _Prism.surface.withValues(alpha: dense ? 0.92 : 0.72),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _Prism.border),
        boxShadow: dense ? _Prism.soft(0.06, 16, 8) : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(Icons.location_on_rounded,
                        size: 15, color: _Prism.inkSoft),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        _Sanitizer.text(loc.isNotEmpty ? loc : '—',
                            maxLength: 40),
                        style: const TextStyle(
                            fontSize: 12,
                            color: _Prism.inkSoft,
                            fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ShaderMask(
                        shaderCallback: (r) => _Prism.brand.createShader(r),
                        child: const Icon(Icons.auto_awesome_rounded,
                            size: 16, color: Colors.white),
                      ),
                      const SizedBox(width: 5),
                      const Text('THIX IA',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: _Prism.ink,
                              letterSpacing: -0.5)),
                    ],
                  ),
                  Text(l10n.t('ia_home_brand_tagline'),
                      style: const TextStyle(
                          fontSize: 9,
                          color: _Prism.inkMuted,
                          fontWeight: FontWeight.w600)),
                ],
              ),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _Prism.border.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text('FR',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: _Prism.ink)),
                    ),
                    const SizedBox(width: 10),
                    Semantics(
                      button: true,
                      label: l10n.t('network_notifications'),
                      child: const Icon(Icons.notifications_none_rounded,
                          size: 23, color: _Prism.ink),
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
// USER HEADER (anneau gradient autour de l'avatar)
// ============================================================================

class _UserHeader extends StatelessWidget {
  const _UserHeader({required this.profileAsync});
  final AsyncValue<Map<String, dynamic>?> profileAsync;

  String? _pick(Map<String, dynamic>? p, List<String> keys) {
    if (p == null) return null;
    for (final k in keys) {
      final v = (p[k] as String?)?.trim();
      if (v != null && v.isNotEmpty) return v;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return profileAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: SizedBox(
            width: 44,
            height: 44,
            child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (_, __) =>
          _body(l10n.t('ia_home_user_default'), null, null, l10n),
      data: (p) => _body(
        _Sanitizer.text(
            _pick(p, ['display_name', 'full_name']) ??
                l10n.t('ia_home_user_default'),
            maxLength: _kMaxNameLength),
        _pick(p, ['avatar_url', 'photo_url']),
        _Sanitizer.text(_pick(p, ['role_title', 'occupation', 'profession']),
            maxLength: _kMaxRoleLength),
        l10n,
      ),
    );
  }

  Widget _body(
      String name, String? photo, String? role, AppLocalizations l10n) {
    final h = DateTime.now().hour;
    final greet = h < 12
        ? l10n.t('ia_greeting_morning')
        : h < 18
            ? l10n.t('ia_greeting_afternoon')
            : l10n.t('ia_greeting_evening');

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Row(
        children: [
          
          Container(
            padding: const EdgeInsets.all(2.5),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: _Prism.brand,
              boxShadow: [
                BoxShadow(
                    color: Color.fromRGBO(
                        (ThixPolicy.primary.r * 255).round(),
                        (ThixPolicy.primary.g * 255).round(),
                        (ThixPolicy.primary.b * 255).round(),
                        0.25),
                    blurRadius: 12,
                    offset: const Offset(0, 4)),
              ],
            ),
            child: CircleAvatar(
              radius: 26,
              backgroundColor: _Prism.surface,
              backgroundImage: (photo != null && photo.isNotEmpty)
                  ? CachedNetworkImageProvider(photo)
                  : null,
              child: (photo == null || photo.isEmpty)
                  ? Text(
                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: const TextStyle(
                          color: _Prism.ink, fontWeight: FontWeight.w800),
                    )
                  : null,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$greet,',
                    style: const TextStyle(
                        fontSize: 13,
                        color: _Prism.inkSoft,
                        fontWeight: FontWeight.w600)),
                Text(name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 21,
                        color: _Prism.ink,
                        letterSpacing: -0.4),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                if (role != null && role.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: ThixPolicy.primary.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(role,
                          style: const TextStyle(
                              color: ThixPolicy.primary,
                              fontWeight: FontWeight.w700,
                              fontSize: 11),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
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
// HERO AURORA (dégradé animé + particules)
// ============================================================================

class _AuroraHero extends StatefulWidget {
  const _AuroraHero({required this.onAnalyze});
  final VoidCallback onAnalyze;

  @override
  State<_AuroraHero> createState() => _AuroraHeroState();
}

class _AuroraHeroState extends State<_AuroraHero>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 9),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        final t = _c.value;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            height: 172,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: LinearGradient(
                begin:
                    Alignment.lerp(Alignment.topLeft, Alignment.bottomLeft, t)!,
                end: Alignment.lerp(
                    Alignment.bottomRight, Alignment.topRight, t)!,
                colors: const [
                  ThixPolicy.primary,
                  Color(0xFF4338CA),
                  _Prism.violet,
                ],
              ),
              boxShadow: [
                BoxShadow(
                    color: ThixPolicy.primary.withValues(alpha: 0.32),
                    blurRadius: 24,
                    offset: const Offset(0, 10)),
              ],
            ),
            child: Stack(
              children: [
                for (var i = 0; i < 3; i++)
                  Positioned(
                    right: 18 + i * 34.0,
                    top: 20 + math.sin((t + i * 0.33) * math.pi * 2) * 14,
                    child: Container(
                      width: 10 - i * 2.0,
                      height: 10 - i * 2.0,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color:
                            Colors.white.withValues(alpha: 0.22 - i * 0.05),
                      ),
                    ),
                  ),
                Positioned(
                  right: -24,
                  bottom: -30,
                  child: Icon(Icons.auto_awesome_rounded,
                      size: 150, color: Colors.white.withValues(alpha: 0.10)),
                ),
                child!,
              ],
            ),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.t('ia_home_hero_title'),
                style: const TextStyle(
                    color: Colors.white,
                    height: 1.12,
                    fontSize: 23,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.4)),
            const SizedBox(height: 8),
            Text(l10n.t('ia_home_hero_subtitle'),
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.82),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500)),
            const Spacer(),
            Semantics(
              button: true,
              label: l10n.t('ia_action_idea'),
              child: ElevatedButton.icon(
                onPressed: widget.onAnalyze,
                icon: const Icon(Icons.bolt_rounded, size: 18),
                label: Text(l10n.t('ia_action_idea'),
                    style: const TextStyle(fontWeight: FontWeight.w800)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: ThixPolicy.primary,
                  elevation: 0,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
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
// ⭐ SPOTLIGHT BUSINESS
// ============================================================================

class _BusinessSpotlight extends StatelessWidget {
  const _BusinessSpotlight({required this.onCreate, required this.onMine});
  final VoidCallback onCreate;
  final VoidCallback onMine;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: _Prism.business,
          boxShadow: [
            BoxShadow(
                color: const Color(0xFF0EA5E9).withValues(alpha: 0.30),
                blurRadius: 22,
                offset: const Offset(0, 9)),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              right: -10,
              top: -18,
              child: Icon(Icons.storefront_rounded,
                  size: 130, color: Colors.white.withValues(alpha: 0.10)),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.verified_rounded,
                                  size: 13, color: Colors.white),
                              SizedBox(width: 4),
                              Text('THIX PORTFOLIO',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.6)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(l10n.t('ia_biz_spotlight_title'),
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                height: 1.15,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.3)),
                        const SizedBox(height: 6),
                        Text(l10n.t('ia_biz_spotlight_subtitle'),
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.85),
                                fontSize: 12,
                                fontWeight: FontWeight.w500)),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: onCreate,
                                icon: const Icon(Icons.add_business_rounded,
                                    size: 17),
                                label: Text(l10n.t('ia_biz_spotlight_create'),
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 12.5)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: ThixPolicy.primary,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 11),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton(
                                onPressed: onMine,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  side: BorderSide(
                                      color: Colors.white
                                          .withValues(alpha: 0.65)),
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 11),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14)),
                                ),
                                child: Text(l10n.t('ia_biz_spotlight_mine'),
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 12.5)),
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
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// BENTO GRID DES ACTIONS
// ============================================================================

class _BentoActions extends StatelessWidget {
  const _BentoActions({required this.onAction});
  final void Function(ThixQuickAction) onAction;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                flex: 6,
                child: _BentoTile(
                  tall: true,
                  icon: Icons.lightbulb_rounded,
                  tint: ThixPolicy.primary,
                  title: l10n.t('ia_action_idea_short'),
                  tag: l10n.t('ia_action_idea_tag'),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onAction(ThixQuickAction.idea);
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 5,
                child: Column(
                  children: [
                    _BentoTile(
                      icon: Icons.bar_chart_rounded,
                      tint: _Prism.violet,
                      title: l10n.t('ia_action_market_short'),
                      tag: l10n.t('ia_action_market_tag'),
                      onTap: () {
                        HapticFeedback.selectionClick();
                        onAction(ThixQuickAction.market);
                      },
                    ),
                    const SizedBox(height: 12),
                    _BentoTile(
                      icon: Icons.description_rounded,
                      tint: _Prism.cyan,
                      title: l10n.t('ia_action_bp_short'),
                      tag: l10n.t('ia_action_bp_tag'),
                      onTap: () {
                        HapticFeedback.selectionClick();
                        onAction(ThixQuickAction.businessPlan);
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _BentoTile(
            icon: Icons.balance_rounded,
            tint: _Prism.amber,
            title: l10n.t('ia_action_legal_short'),
            tag: l10n.t('ia_action_legal_tag'),
            onTap: () {
              HapticFeedback.selectionClick();
              onAction(ThixQuickAction.legal);
            },
          ),
        ],
      ),
    );
  }
}

class _BentoTile extends StatelessWidget {
  const _BentoTile({
    required this.icon,
    required this.tint,
    required this.title,
    required this.tag,
    required this.onTap,
    this.tall = false,
  });

  final IconData icon;
  final Color tint;
  final String title;
  final String tag;
  final VoidCallback onTap;
  final bool tall;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: title,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: tall ? 168 : 78,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _Prism.surface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: _Prism.border),
            boxShadow: _Prism.soft(0.04, 12, 5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          tint.withValues(alpha: 0.16),
                          tint.withValues(alpha: 0.06),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: tint, size: 19),
                  ),
                  const Spacer(),
                  Icon(Icons.arrow_outward_rounded,
                      size: 15, color: _Prism.inkMuted),
                ],
              ),
              const Spacer(),
              Text(title,
                  style: const TextStyle(
                      fontSize: 14,
                      height: 1.15,
                      fontWeight: FontWeight.w800,
                      color: _Prism.ink)),
              const SizedBox(height: 3),
              Text(tag,
                  maxLines: tall ? 2 : 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 10.5,
                      color: _Prism.inkSoft,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// SECTION TITLE
// ============================================================================

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title, {this.seeAll = false, this.onSeeAll});
  final String title;
  final bool seeAll;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 18,
            decoration: BoxDecoration(
              gradient: _Prism.brand,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(title,
                style: const TextStyle(
                    fontSize: 16.5,
                    fontWeight: FontWeight.w900,
                    color: _Prism.ink,
                    letterSpacing: -0.3)),
          ),
          if (seeAll && onSeeAll != null)
            Semantics(
              button: true,
              label: l10n.t('common_see_all'),
              child: GestureDetector(
                onTap: onSeeAll,
                child: Row(
                  children: [
                    Text(l10n.t('common_see_all'),
                        style: const TextStyle(
                            color: ThixPolicy.primary,
                            fontWeight: FontWeight.w700,
                            fontSize: 13)),
                    const SizedBox(width: 4),
                    const Icon(Icons.arrow_forward_rounded,
                        size: 14, color: ThixPolicy.primary),
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
// MOTORS ROW (puce BUSINESS gradient en tête)
// ============================================================================

class _MotorsRow extends StatelessWidget {
  const _MotorsRow();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final motors = [
      (l10n.t('ia_motor_research'), Icons.search_rounded, ThixPolicy.primary),
      (l10n.t('ia_motor_market'), Icons.trending_up_rounded, _Prism.violet),
      (l10n.t('ia_motor_business'), Icons.work_rounded, _Prism.cyan),
      (l10n.t('ia_motor_finance'), Icons.attach_money_rounded, _Prism.amber),
      (l10n.t('ia_motor_legal'), Icons.balance_rounded, _Prism.inkSoft),
      (l10n.t('ia_motor_design'), Icons.edit_rounded, ThixPolicy.primary),
    ];

    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: motors.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          if (i == 0) {
            return Semantics(
              button: true,
              label: l10n.t('ia_biz_fab_label'),
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.mediumImpact();
                  context.push(_kRouteBusinessCreate);
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                  decoration: BoxDecoration(
                    gradient: _Prism.business,
                    borderRadius: BorderRadius.circular(21),
                    boxShadow: [
                      BoxShadow(
                          color: ThixPolicy.primary.withValues(alpha: 0.30),
                          blurRadius: 10,
                          offset: const Offset(0, 4)),
                    ],
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.storefront_rounded,
                          color: Colors.white, size: 16),
                      SizedBox(width: 6),
                      Text('BUSINESS',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 0.4)),
                    ],
                  ),
                ),
              ),
            );
          }
          final m = motors[i - 1];
          return Semantics(
            button: true,
            label: m.$1,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 9),
              decoration: BoxDecoration(
                color: _Prism.surface,
                borderRadius: BorderRadius.circular(21),
                border: Border.all(color: _Prism.border),
                boxShadow: _Prism.soft(0.03, 6, 2),
              ),
              child: Row(
                children: [
                  Icon(m.$2, color: m.$3, size: 15),
                  const SizedBox(width: 6),
                  Text(m.$1,
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: _Prism.ink)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ============================================================================
// RECENT ANALYSES (anneaux de progression)
// ============================================================================

class _RecentAnalyses extends StatelessWidget {
  const _RecentAnalyses(
      {required this.projectsAsync,
      required this.onOpen,
      required this.onCreate});
  final AsyncValue projectsAsync;
  final void Function(String) onOpen;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return projectsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(20),
        child: Center(
            child: SizedBox(
                width: 30,
                height: 30,
                child: CircularProgressIndicator(
                    strokeWidth: 3, color: ThixPolicy.primary))),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: _card(
          child: Row(
            children: [
              const Icon(Icons.error_outline_rounded,
                  color: ThixPolicy.danger, size: 24),
              const SizedBox(width: 12),
              Expanded(
                  child: Text(
                      l10n.t('ia_home_error_generic',
                          args: [_Sanitizer.errorMessage(e)]),
                      style: const TextStyle(color: _Prism.inkSoft))),
            ],
          ),
        ),
      ),
      data: (projects) {
        final list = projects is List<ThixProject> ? projects : <ThixProject>[];
        if (list.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _card(
              child: Column(
                children: [
                  const Icon(Icons.folder_open_rounded,
                      size: 40, color: _Prism.inkMuted),
                  const SizedBox(height: 12),
                  Text(l10n.t('ia_home_no_analyses'),
                      style: const TextStyle(
                          color: _Prism.inkSoft, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: onCreate,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: _Prism.ink,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14))),
                    child: Text(l10n.t('ia_home_create_project')),
                  ),
                ],
              ),
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: list.take(3).map((p) {
              final pct = (p.progress * 100).clamp(0, 100).toInt();
              final name = _Sanitizer.text(p.name, maxLength: _kMaxNameLength);
              final code =
                  _Sanitizer.text(p.projectCode, maxLength: _kMaxCodeLength);
              final sector =
                  _Sanitizer.text(p.sector, maxLength: _kMaxSectorLength);

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Semantics(
                  button: true,
                  label: name,
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      onOpen(p.projectCode);
                    },
                    child: _card(
                      child: Row(
                        children: [
                          SizedBox(
                            width: 46,
                            height: 46,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                CircularProgressIndicator(
                                  value: pct / 100,
                                  strokeWidth: 4.5,
                                  strokeCap: StrokeCap.round,
                                  backgroundColor: _Prism.border,
                                  valueColor: const AlwaysStoppedAnimation(
                                      ThixPolicy.primary),
                                ),
                                Center(
                                  child: Text('$pct%',
                                      style: const TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w900,
                                          color: _Prism.ink)),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(name,
                                    style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                        color: _Prism.ink),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis),
                                const SizedBox(height: 4),
                                Text('$code • $sector',
                                    style: const TextStyle(
                                        fontSize: 12,
                                        color: _Prism.inkSoft,
                                        fontWeight: FontWeight.w500),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right_rounded,
                              color: _Prism.inkMuted, size: 22),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Widget _card({required Widget child}) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _Prism.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: _Prism.border),
          boxShadow: _Prism.soft(0.04, 12, 5),
        ),
        child: child,
      );
}

// ============================================================================
// QUICK STATS
// ============================================================================

class _QuickStats extends StatelessWidget {
  const _QuickStats({required this.projectsAsync});
  final AsyncValue projectsAsync;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return projectsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (projects) {
        final list = projects is List<ThixProject> ? projects : <ThixProject>[];
        final active =
            list.where((p) => p.isActive || p.status == 'draft').length;
        final analyses = list.fold<int>(0, (s, p) => s + p.analysesCount);
        final countries = list
            .map((p) => p.country)
            .where((c) => c.trim().isNotEmpty)
            .toSet();
        final avg = list.isEmpty
            ? 0
            : (list.fold<double>(0, (s, p) => s + p.progress) / list.length *
                    100)
                .round();

        final stats = [
          ('$analyses', l10n.t('ia_stat_analyses'), Icons.insights_rounded,
              ThixPolicy.primary),
          ('$active', l10n.t('ia_stat_active'), Icons.track_changes_rounded,
              _Prism.violet),
          ('${countries.length}', l10n.t('ia_stat_countries'),
              Icons.public_rounded, _Prism.cyan),
          ('$avg%', l10n.t('ia_stat_progress'), Icons.verified_rounded,
              _Prism.amber),
        ];

        return SizedBox(
          height: 86,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: stats.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, i) {
              final s = stats[i];
              return Semantics(
                label: '${s.$1} ${s.$2}',
                child: Container(
                  width: 148,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: _Prism.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _Prism.border),
                    boxShadow: _Prism.soft(0.04, 10, 4),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(9),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              s.$4.withValues(alpha: 0.18),
                              s.$4.withValues(alpha: 0.06),
                            ],
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(s.$3, color: s.$4, size: 17),
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(s.$1,
                                style: const TextStyle(
                                    fontSize: 19,
                                    fontWeight: FontWeight.w900,
                                    color: _Prism.ink,
                                    letterSpacing: -0.4)),
                            Text(s.$2,
                                style: const TextStyle(
                                    fontSize: 10,
                                    color: _Prism.inkSoft,
                                    fontWeight: FontWeight.w600),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

// ============================================================================
// ⭐ FAB BUSINESS — SCROLL-REACTIVE
// ============================================================================

class _BusinessFab extends StatelessWidget {
  const _BusinessFab({required this.visible, required this.onTap});
  final bool visible;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
        child: AnimatedSlide(
          offset: visible ? Offset.zero : const Offset(0, 1.4),
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          child: Semantics(
            button: true,
            label: l10n.t('ia_biz_fab_label'),
            child: GestureDetector(
              onTap: onTap,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                decoration: BoxDecoration(
                  gradient: _Prism.business,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                        color: ThixPolicy.primary.withValues(alpha: 0.40),
                        blurRadius: 18,
                        offset: const Offset(0, 8)),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.storefront_rounded,
                            color: Colors.white, size: 20)
                        .animate(onPlay: (c) => c.repeat())
                        .scale(
                          begin: const Offset(1, 1),
                          end: const Offset(1.15, 1.15),
                          duration: 900.ms,
                          curve: Curves.easeInOut,
                        ),
                    const SizedBox(width: 9),
                    Text(l10n.t('ia_biz_fab_label'),
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14.5,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.2)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// LOADING DIALOG
// ============================================================================

class _LoadingDialog extends StatelessWidget {
  const _LoadingDialog();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: _Prism.surface,
          borderRadius: BorderRadius.circular(24),
          boxShadow: _Prism.soft(0.10, 30, 12),
        ),
        child: const SizedBox(
          width: 40,
          height: 40,
          child: CircularProgressIndicator(
              strokeWidth: 3, color: ThixPolicy.primary),
        ),
      ),
    );
  }
}

// ============================================================================
// PROJECT PICKER SHEET
// ============================================================================

class _ProjectPickerSheet extends StatelessWidget {
  const _ProjectPickerSheet({required this.projects, required this.title});
  final List<ThixProject> projects;
  final String title;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.35,
      maxChildSize: 0.85,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: _Prism.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
                width: 42,
                height: 5,
                decoration: BoxDecoration(
                    color: _Prism.border,
                    borderRadius: BorderRadius.circular(3))),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
              child: Row(
                children: [
                  Expanded(
                      child: Text(title,
                          style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: _Prism.ink))),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      context.push(ThixIARoutes.createProject);
                    },
                    style: TextButton.styleFrom(
                        foregroundColor: ThixPolicy.primary),
                    child: Text(l10n.t('ia_home_new_project'),
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: _Prism.border),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(l10n.t('ia_home_pick_hint'),
                    style: const TextStyle(
                        color: _Prism.inkSoft,
                        fontWeight: FontWeight.w600,
                        fontSize: 13)),
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: controller,
                itemCount: projects.length,
                itemBuilder: (_, i) {
                  final p = projects[i];
                  final pct = (p.progress * 100).toInt();
                  final name =
                      _Sanitizer.text(p.name, maxLength: _kMaxNameLength);
                  final code = _Sanitizer.text(p.projectCode,
                      maxLength: _kMaxCodeLength);
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 4),
                    leading: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                          color: _Prism.border.withValues(alpha: 0.5),
                          shape: BoxShape.circle),
                      child: const Icon(Icons.folder_rounded,
                          color: _Prism.ink, size: 20),
                    ),
                    title: Text(name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: _Prism.ink)),
                    subtitle: Text('$code • $pct%',
                        style: const TextStyle(
                            fontSize: 12,
                            color: _Prism.inkSoft,
                            fontWeight: FontWeight.w500)),
                    trailing: const Icon(Icons.chevron_right_rounded,
                        color: _Prism.inkMuted, size: 24),
                    onTap: () => Navigator.pop(context, p),
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
// CLÉS l10n À AJOUTER (app_fr.arb / app_en.arb)
// ============================================================================
//
// FR :
//   "ia_biz_spotlight_title":   "Votre entreprise mérite un site pro",
//   "ia_biz_spotlight_subtitle":"Créez votre portfolio animé, partagez votre THIX ID.",
//   "ia_biz_spotlight_create":  "Créer mon site",
//   "ia_biz_spotlight_mine":    "Mes sites",
//   "ia_biz_fab_label":         "Business",
//
// EN :
//   "ia_biz_spotlight_title":   "Your business deserves a pro website",
//   "ia_biz_spotlight_subtitle":"Create your animated portfolio, share your THIX ID.",
//   "ia_biz_spotlight_create":  "Create my site",
//   "ia_biz_spotlight_mine":    "My sites",
//   "ia_biz_fab_label":         "Business",
// ============================================================================
