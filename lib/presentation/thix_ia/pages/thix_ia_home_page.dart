// lib/presentation/thix_ia/pages/thix_ia_home_page.dart
//
// ThixIaHomePage — "PRISM RICH v4" (Production Enterprise)
//
// Corrections & Améliorations :
//   • i18n FR/EN inline (fin des clés brutes "ia_biz_spotlight_title")
//   • Refonte 100% du design : Glassmorphism, ombres douces, gradients riches
//   • Spotlight Business : carte vedette avec effet premium
//   • Bento Grid : cartes avec gradients et icônes plus grandes
//   • FAB redesigné pour ne pas chevaucher les pilules
//   • Animations natives optimisées

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

import '../core/constants/thix_ia_routes.dart';
import '../models/thix_project.dart';
import '../providers/thix_ia_provider.dart';
import '../providers/analysis_provider.dart';

// ─── i18n minimaliste FR/EN ─────────────────────────────────────────────────
String _lang(BuildContext c) =>
    Localizations.localeOf(c).languageCode.toLowerCase();

String _s(BuildContext c, String fr, String en) =>
    _lang(c) == 'fr' ? fr : en;
// ────────────────────────────────────────────────────────────────────────────

// ============================================================================
// ROUTES BUSINESS
// ============================================================================

const String _kRouteBusinessCreate = '/business/create';
const String _kRouteBusinessMine = '/business/mine';

// ============================================================================
// PALETTE « PRISM RICH »
// ============================================================================

class _Prism {
  _Prism._();

  static const Color bg = Color(0xFFF8F9FD); // Fond légèrement plus clair
  static const Color surface = Color(0xFFFFFFFF);
  static const Color border = Color(0xFFE2E8F0); // Bordure plus douce

  static const Color ink = Color(0xFF0F172A); // Bleu nuit profond
  static const Color inkSoft = Color(0xFF475569);
  static const Color inkMuted = Color(0xFF94A3B8);

  static const Color violet = Color(0xFF8B5CF6);
  static const Color cyan = Color(0xFF06B6D4);
  static const Color amber = Color(0xFFF59E0B);

  static const LinearGradient brand = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [ThixPolicy.primary, Color(0xFF4F46E5), _Prism.violet],
  );

  static const LinearGradient business = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0284C7), Color(0xFF2563EB), Color(0xFF4338CA)],
  );

  static List<BoxShadow> soft([double a = 0.06, double b = 20, double y = 8]) =>
      [
        BoxShadow(
          color: Colors.black.withValues(alpha: a),
          blurRadius: b,
          offset: Offset(0, y),
        ),
      ];

  static List<BoxShadow> glow(Color color) => [
        BoxShadow(
          color: color.withValues(alpha: 0.35),
          blurRadius: 24,
          offset: const Offset(0, 10),
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
    _IaHomeLogger.info('Home initialized (Prism Rich v4)');
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

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
    final projects = ref.read(projectsProvider).value ?? [];

    if (projects.isEmpty) {
      if (!mounted) return;
      final go = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: _Prism.surface,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text(
              _s(context, 'Aucun projet actif', 'No active project'),
              style: const TextStyle(
                  color: _Prism.ink, fontWeight: FontWeight.w800)),
          content: Text(
              _s(context,
                  'Vous devez créer un projet avant de lancer une analyse.',
                  'You need to create a project before starting an analysis.'),
              style: const TextStyle(color: _Prism.inkSoft)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(_s(context, 'Annuler', 'Cancel'),
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
              child: Text(_s(context, 'Créer un projet', 'Create a project')),
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
        title: _actionTitle(action, context),
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
          content: Text(_s(
              context,
              "Analyse démarrée pour ${_Sanitizer.text(selected.projectCode, maxLength: _kMaxCodeLength)}",
              "Analysis started for ${_Sanitizer.text(selected.projectCode, maxLength: _kMaxCodeLength)}")),
          backgroundColor: ThixPolicy.success,
          behavior: SnackBarBehavior.floating,
        ));
        context.push(ThixIARoutes.projectDetailPath(selected.projectCode));
      }
    } catch (e) {
      if (mounted) Navigator.of(context).pop();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_s(context,
              "Erreur : ${_Sanitizer.errorMessage(e)}",
              "Error: ${_Sanitizer.errorMessage(e)}")),
          backgroundColor: ThixPolicy.danger,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  String _actionTitle(ThixQuickAction a, BuildContext ctx) {
    switch (a) {
      case ThixQuickAction.idea:
        return _s(ctx, 'Idée de projet', 'Project idea');
      case ThixQuickAction.market:
        return _s(ctx, 'Analyse de marché', 'Market analysis');
      case ThixQuickAction.businessPlan:
        return _s(ctx, 'Business Plan', 'Business Plan');
      case ThixQuickAction.legal:
        return _s(ctx, 'Analyse juridique', 'Legal analysis');
    }
  }

  @override
  Widget build(BuildContext context) {
    final projectsAsync = ref.watch(projectsProvider);
    final profileAsync = ref.watch(thixIaCurrentProfileProvider);

    return Scaffold(
      backgroundColor: _Prism.bg,
      body: Stack(
        children: [
          // Halos d'ambiance
          Positioned(
              top: -120,
              right: -70,
              child: _halo(260, ThixPolicy.primary.withValues(alpha: 0.12))),
          Positioned(
              top: 240,
              left: -110,
              child: _halo(300, _Prism.violet.withValues(alpha: 0.08))),
          Positioned(
              bottom: -80,
              right: -60,
              child: _halo(220, _Prism.cyan.withValues(alpha: 0.06))),

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
                  const SliverToBoxAdapter(child: SizedBox(height: 20)),

                  // AURORA HERO
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
                  const SliverToBoxAdapter(child: SizedBox(height: 18)),

                  // SPOTLIGHT BUSINESS
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
                        .animate(delay: 100.ms)
                        .fadeIn(duration: 500.ms)
                        .slideY(
                            begin: 0.08,
                            duration: 500.ms,
                            curve: Curves.easeOutCubic),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 28)),

                  SliverToBoxAdapter(
                      child: _SectionTitle(
                          _s(context, 'Que voulez-vous accomplir ?',
                              'What do you want to achieve?'))),
                  const SliverToBoxAdapter(child: SizedBox(height: 14)),
                  SliverToBoxAdapter(
                      child: _BentoActions(onAction: _onQuickAction)),
                  const SliverToBoxAdapter(child: SizedBox(height: 28)),

                  SliverToBoxAdapter(
                      child: _SectionTitle(
                          _s(context, 'Moteurs IA spécialisés',
                              'Specialized AI Engines'),
                          seeAll: true,
                          onSeeAll: () {
                            HapticFeedback.selectionClick();
                            context.push(ThixIARoutes.projects);
                          })),
                  const SliverToBoxAdapter(child: SizedBox(height: 14)),
                  const SliverToBoxAdapter(
                      child: RepaintBoundary(child: _MotorsRow())),
                  const SliverToBoxAdapter(child: SizedBox(height: 28)),

                  SliverToBoxAdapter(
                      child: _SectionTitle(
                          _s(context, 'Analyses récentes', 'Recent analyses'),
                          seeAll: true,
                          onSeeAll: () {
                            HapticFeedback.selectionClick();
                            context.push(ThixIARoutes.projects);
                          })),
                  const SliverToBoxAdapter(child: SizedBox(height: 14)),
                  SliverToBoxAdapter(
                      child: RepaintBoundary(
                          child: _RecentAnalyses(
                        projectsAsync: projectsAsync,
                        onOpen: (c) =>
                            context.push(ThixIARoutes.projectDetailPath(c)),
                        onCreate: () =>
                            context.push(ThixIARoutes.createProject),
                      ))),
                  const SliverToBoxAdapter(child: SizedBox(height: 28)),

                  SliverToBoxAdapter(
                      child: _SectionTitle(
                          _s(context, 'Statistiques', 'Statistics'))),
                  const SliverToBoxAdapter(child: SizedBox(height: 14)),
                  SliverToBoxAdapter(
                      child: RepaintBoundary(
                          child: _QuickStats(projectsAsync: projectsAsync))),
                  const SliverToBoxAdapter(child: SizedBox(height: 110)),
                ],
              ),
            ),
          ),

          // FAB BUSINESS
          Positioned(
            right: 20,
            bottom: 24,
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
    final p = profileAsync.valueOrNull;
    final city = (p?['city'] as String?)?.trim();
    final country = (p?['country'] as String?)?.trim();
    final loc = [
      if (city != null && city.isNotEmpty) city,
      if (country != null && country.isNotEmpty) country
    ].join(', ');

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      margin: EdgeInsets.fromLTRB(16, 10, 16, dense ? 10 : 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _Prism.surface.withValues(alpha: dense ? 0.95 : 0.75),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _Prism.surface.withValues(alpha: 0.5)),
        boxShadow: dense ? _Prism.soft(0.08, 20, 10) : [],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(Icons.location_on_rounded,
                        size: 16, color: _Prism.inkMuted),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        _Sanitizer.text(loc.isNotEmpty ? loc : '—',
                            maxLength: 40),
                        style: const TextStyle(
                            fontSize: 12.5,
                            color: _Prism.inkSoft,
                            fontWeight: FontWeight.w700),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ShaderMask(
                    shaderCallback: (r) => _Prism.brand.createShader(r),
                    child: const Icon(Icons.auto_awesome_rounded,
                        size: 18, color: Colors.white),
                  ),
                  const SizedBox(width: 6),
                  const Text('THIX IA',
                      style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          color: _Prism.ink,
                          letterSpacing: -0.5)),
                ],
              ),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: _Prism.bg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _Prism.border),
                      ),
                      child: Text(
                          _s(context, 'FR', 'EN'), // Dynamique
                          style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: _Prism.ink)),
                    ),
                    const SizedBox(width: 12),
                    Semantics(
                      button: true,
                      label: _s(context, 'Notifications', 'Notifications'),
                      child: const Icon(Icons.notifications_none_rounded,
                          size: 24, color: _Prism.ink),
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
// USER HEADER
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
    return profileAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: SizedBox(
            width: 44,
            height: 44,
            child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (_, __) => _body(
          _s(context, 'Utilisateur', 'User'), null, null, context),
      data: (p) => _body(
        _Sanitizer.text(
            _pick(p, ['display_name', 'full_name']) ??
                _s(context, 'Utilisateur', 'User'),
            maxLength: _kMaxNameLength),
        _pick(p, ['avatar_url', 'photo_url']),
        _Sanitizer.text(_pick(p, ['role_title', 'occupation', 'profession']),
            maxLength: _kMaxRoleLength),
        context,
      ),
    );
  }

  Widget _body(String name, String? photo, String? role, BuildContext context) {
    final h = DateTime.now().hour;
    final greet = h < 12
        ? _s(context, 'Bonjour', 'Good morning')
        : h < 18
            ? _s(context, 'Bon après-midi', 'Good afternoon')
            : _s(context, 'Bonsoir', 'Good evening');

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: _Prism.brand,
              boxShadow: _Prism.glow(ThixPolicy.primary),
            ),
            child: CircleAvatar(
              radius: 28,
              backgroundColor: _Prism.surface,
              backgroundImage: (photo != null && photo.isNotEmpty)
                  ? CachedNetworkImageProvider(photo)
                  : null,
              child: (photo == null || photo.isEmpty)
                  ? Text(
                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: const TextStyle(
                          color: _Prism.ink,
                          fontWeight: FontWeight.w900,
                          fontSize: 20),
                    )
                  : null,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$greet,',
                    style: const TextStyle(
                        fontSize: 13,
                        color: _Prism.inkSoft,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 22,
                        color: _Prism.ink,
                        letterSpacing: -0.5),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                if (role != null && role.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: ThixPolicy.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(role,
                          style: const TextStyle(
                              color: ThixPolicy.primary,
                              fontWeight: FontWeight.w800,
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
// HERO AURORA (Design Premium)
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
    duration: const Duration(seconds: 10),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        final t = _c.value;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            height: 180,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(32),
              gradient: LinearGradient(
                begin:
                    Alignment.lerp(Alignment.topLeft, Alignment.bottomLeft, t)!,
                end: Alignment.lerp(
                    Alignment.bottomRight, Alignment.topRight, t)!,
                colors: const [
                  ThixPolicy.primary,
                  Color(0xFF4F46E5),
                  _Prism.violet,
                ],
              ),
              boxShadow: _Prism.glow(ThixPolicy.primary),
            ),
            child: Stack(
              children: [
                // Cercles lumineux
                Positioned(
                  right: -30,
                  top: -30,
                  child: Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                ),
                Positioned(
                  left: -20,
                  bottom: -40,
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.05),
                    ),
                  ),
                ),
                // Étoiles animées
                for (var i = 0; i < 3; i++)
                  Positioned(
                    right: 40 + i * 40.0,
                    top: 30 + math.sin((t + i * 0.33) * math.pi * 2) * 15,
                    child: Icon(
                      Icons.star_rounded,
                      size: 16 - i * 3.0,
                      color: Colors.white.withValues(alpha: 0.4 - i * 0.1),
                    ),
                  ),
                child!,
              ],
            ),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                _s(context, 'Analysez votre idée en un instant',
                    'Analyze your idea instantly'),
                style: const TextStyle(
                    color: Colors.white,
                    height: 1.15,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5)),
            const SizedBox(height: 8),
            Text(
                _s(context, 'Des analyses rapides, précises et actionnables.',
                    'Fast, accurate and actionable insights.'),
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 13,
                    fontWeight: FontWeight.w500)),
            const Spacer(),
            Semantics(
              button: true,
              label: _s(context, 'Générer une idée', 'Generate an idea'),
              child: ElevatedButton.icon(
                onPressed: widget.onAnalyze,
                icon: const Icon(Icons.bolt_rounded, size: 20),
                label: Text(_s(context, 'Générer une idée', 'Generate an idea'),
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 14)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: ThixPolicy.primary,
                  elevation: 4,
                  shadowColor: Colors.black26,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
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
// ⭐ SPOTLIGHT BUSINESS (Le chef-d'œuvre)
// ============================================================================

class _BusinessSpotlight extends StatelessWidget {
  const _BusinessSpotlight({required this.onCreate, required this.onMine});
  final VoidCallback onCreate;
  final VoidCallback onMine;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          gradient: _Prism.business,
          boxShadow: _Prism.glow(const Color(0xFF2563EB)),
        ),
        child: Stack(
          children: [
            // Effet visuel en arrière-plan
            Positioned(
              right: -20,
              top: -20,
              child: Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
            ),
            Positioned(
              right: 10,
              top: 10,
              child: Icon(Icons.storefront_rounded,
                  size: 100, color: Colors.white.withValues(alpha: 0.15)),
            ),
            Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.20),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.verified_rounded,
                            size: 14, color: Colors.white),
                        const SizedBox(width: 6),
                        Text('THIX PORTFOLIO',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.0)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    _s(
                        context,
                        'Votre entreprise mérite un site pro',
                        'Your business deserves a pro website'),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        height: 1.15,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.4),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _s(
                        context,
                        'Créez votre portfolio animé, partagez votre THIX ID.',
                        'Create your animated portfolio, share your THIX ID.'),
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 13,
                        fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: onCreate,
                          icon: const Icon(Icons.add_business_rounded,
                              size: 18),
                          label: Text(
                              _s(context, 'Créer mon site', 'Create my site'),
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800, fontSize: 13)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: ThixPolicy.primary,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: onMine,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: BorderSide(
                                color: Colors.white.withValues(alpha: 0.6),
                                width: 1.5),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                          ),
                          child: Text(_s(context, 'Mes sites', 'My sites'),
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800, fontSize: 13)),
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
    );
  }
}

// ============================================================================
// BENTO GRID DES ACTIONS (Design Riche)
// ============================================================================

class _BentoActions extends StatelessWidget {
  const _BentoActions({required this.onAction});
  final void Function(ThixQuickAction) onAction;

  @override
  Widget build(BuildContext context) {
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
                  title: _s(context, 'Idée', 'Idea'),
                  tag: _s(context, 'Brainstorming', 'Brainstorming'),
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
                      title: _s(context, 'Marché', 'Market'),
                      tag: _s(context, 'Tendances & Data', 'Trends & Data'),
                      onTap: () {
                        HapticFeedback.selectionClick();
                        onAction(ThixQuickAction.market);
                      },
                    ),
                    const SizedBox(height: 12),
                    _BentoTile(
                      icon: Icons.description_rounded,
                      tint: _Prism.cyan,
                      title: _s(context, 'Business', 'Business'),
                      tag: _s(context, 'Plan financier', 'Financial plan'),
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
            title: _s(context, 'Juridique', 'Legal'),
            tag: _s(context, 'Lois & Normes', 'Laws & Norms'),
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
          height: tall ? 172 : 80,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _Prism.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _Prism.border),
            boxShadow: _Prism.soft(0.04, 12, 5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          tint.withValues(alpha: 0.15),
                          tint.withValues(alpha: 0.05),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(icon, color: tint, size: 22),
                  ),
                  const Spacer(),
                  Icon(Icons.arrow_outward_rounded,
                      size: 16, color: _Prism.inkMuted),
                ],
              ),
              const Spacer(),
              Text(title,
                  style: const TextStyle(
                      fontSize: 15,
                      height: 1.15,
                      fontWeight: FontWeight.w900,
                      color: _Prism.ink)),
              const SizedBox(height: 4),
              Text(tag,
                  maxLines: tall ? 2 : 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 11,
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Container(
            width: 5,
            height: 20,
            decoration: BoxDecoration(
              gradient: _Prism.brand,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(title,
                style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: _Prism.ink,
                    letterSpacing: -0.3)),
          ),
          if (seeAll && onSeeAll != null)
            Semantics(
              button: true,
              label: _s(context, 'Voir tout', 'See all'),
              child: GestureDetector(
                onTap: onSeeAll,
                child: Row(
                  children: [
                    Text(_s(context, 'Voir tout', 'See all'),
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
// MOTORS ROW
// ============================================================================

class _MotorsRow extends StatelessWidget {
  const _MotorsRow();

  @override
  Widget build(BuildContext context) {
    final motors = [
      (
        _s(context, 'Recherche', 'Research'),
        Icons.search_rounded,
        ThixPolicy.primary
      ),
      (_s(context, 'Marché', 'Market'), Icons.trending_up_rounded, _Prism.violet),
      (_s(context, 'Business', 'Business'), Icons.work_rounded, _Prism.cyan),
      (
        _s(context, 'Finance', 'Finance'),
        Icons.attach_money_rounded,
        _Prism.amber
      ),
      (
        _s(context, 'Juridique', 'Legal'),
        Icons.balance_rounded,
        _Prism.inkSoft
      ),
      (_s(context, 'Design', 'Design'), Icons.edit_rounded, ThixPolicy.primary),
    ];

    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: motors.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          if (i == 0) {
            return Semantics(
              button: true,
              label: _s(context, 'Business', 'Business'),
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.mediumImpact();
                  context.push(_kRouteBusinessCreate);
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: _Prism.business,
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: _Prism.glow(ThixPolicy.primary),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.storefront_rounded,
                          color: Colors.white, size: 18),
                      SizedBox(width: 8),
                      Text('BUSINESS',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 0.5)),
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
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: _Prism.surface,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: _Prism.border),
                boxShadow: _Prism.soft(0.03, 6, 2),
              ),
              child: Row(
                children: [
                  Icon(m.$2, color: m.$3, size: 16),
                  const SizedBox(width: 8),
                  Text(m.$1,
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
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
// RECENT ANALYSES
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
                      _s(context, 'Erreur : ${_Sanitizer.errorMessage(e)}',
                          'Error: ${_Sanitizer.errorMessage(e)}'),
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
                  Text(
                      _s(context, 'Aucune analyse récente',
                          'No recent analyses'),
                      style: const TextStyle(
                          color: _Prism.inkSoft, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: onCreate,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: _Prism.ink,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14))),
                    child: Text(
                        _s(context, 'Créer un projet', 'Create a project')),
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
                            width: 48,
                            height: 48,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                CircularProgressIndicator(
                                  value: pct / 100,
                                  strokeWidth: 5,
                                  strokeCap: StrokeCap.round,
                                  backgroundColor: _Prism.border,
                                  valueColor: const AlwaysStoppedAnimation(
                                      ThixPolicy.primary),
                                ),
                                Center(
                                  child: Text('$pct%',
                                      style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w900,
                                          color: _Prism.ink)),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(name,
                                    style: const TextStyle(
                                        fontSize: 15,
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
                              color: _Prism.inkMuted, size: 24),
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
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: _Prism.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: _Prism.border),
          boxShadow: _Prism.soft(0.04, 14, 6),
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
          (
            '$analyses',
            _s(context, 'Analyses', 'Analyses'),
            Icons.insights_rounded,
            ThixPolicy.primary
          ),
          (
            '$active',
            _s(context, 'Actifs', 'Active'),
            Icons.track_changes_rounded,
            _Prism.violet
          ),
          (
            '${countries.length}',
            _s(context, 'Pays', 'Countries'),
            Icons.public_rounded,
            _Prism.cyan
          ),
          (
            '$avg%',
            _s(context, 'Progression', 'Progress'),
            Icons.verified_rounded,
            _Prism.amber
          ),
        ];

        return SizedBox(
          height: 90,
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
                  width: 155,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: _Prism.surface,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: _Prism.border),
                    boxShadow: _Prism.soft(0.04, 10, 4),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
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
                        child: Icon(s.$3, color: s.$4, size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(s.$1,
                                style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                    color: _Prism.ink,
                                    letterSpacing: -0.5)),
                            Text(s.$2,
                                style: const TextStyle(
                                    fontSize: 11,
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
// ⭐ FAB BUSINESS — SCROLL-REACTIVE (Redesigné)
// ============================================================================

class _BusinessFab extends StatelessWidget {
  const _BusinessFab({required this.visible, required this.onTap});
  final bool visible;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        child: AnimatedSlide(
          offset: visible ? Offset.zero : const Offset(0, 1.5),
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutBack,
          child: Semantics(
            button: true,
            label: _s(context, 'Business', 'Business'),
            child: GestureDetector(
              onTap: onTap,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: _Prism.business,
                  shape: BoxShape.circle, // Changé en cercle pour un look plus FAB
                  boxShadow: _Prism.glow(ThixPolicy.primary),
                  border: Border.all(
                      color: Colors.white.withValues(alpha: 0.2), width: 1.5),
                ),
                child: const Icon(Icons.storefront_rounded,
                        color: Colors.white, size: 26)
                    .animate(onPlay: (c) => c.repeat())
                    .scale(
                      begin: const Offset(1, 1),
                      end: const Offset(1.1, 1.1),
                      duration: 1200.ms,
                      curve: Curves.easeInOut,
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
// LOADING DIALOG & SHEET
// ============================================================================

class _LoadingDialog extends StatelessWidget {
  const _LoadingDialog();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: _Prism.surface,
          borderRadius: BorderRadius.circular(28),
          boxShadow: _Prism.soft(0.15, 40, 20),
        ),
        child: const SizedBox(
          width: 44,
          height: 44,
          child: CircularProgressIndicator(
              strokeWidth: 3.5, color: ThixPolicy.primary),
        ),
      ),
    );
  }
}

class _ProjectPickerSheet extends StatelessWidget {
  const _ProjectPickerSheet({required this.projects, required this.title});
  final List<ThixProject> projects;
  final String title;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.35,
      maxChildSize: 0.85,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: _Prism.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
                width: 48,
                height: 6,
                decoration: BoxDecoration(
                    color: _Prism.border,
                    borderRadius: BorderRadius.circular(3))),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 12, 12),
              child: Row(
                children: [
                  Expanded(
                      child: Text(title,
                          style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: _Prism.ink))),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      context.push(ThixIARoutes.createProject);
                    },
                    style: TextButton.styleFrom(
                        foregroundColor: ThixPolicy.primary),
                    child: Text(_s(context, 'Nouveau', 'New'),
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 14)),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: _Prism.border),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                    _s(context, 'Sélectionnez un projet pour continuer',
                        'Select a project to continue'),
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
                        horizontal: 20, vertical: 6),
                    leading: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                          color: ThixPolicy.primary.withValues(alpha: 0.08),
                          shape: BoxShape.circle),
                      child: const Icon(Icons.folder_rounded,
                          color: ThixPolicy.primary, size: 22),
                    ),
                    title: Text(name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: _Prism.ink)),
                    subtitle: Text('$code • $pct%',
                        style: const TextStyle(
                            fontSize: 13,
                            color: _Prism.inkSoft,
                            fontWeight: FontWeight.w600)),
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
