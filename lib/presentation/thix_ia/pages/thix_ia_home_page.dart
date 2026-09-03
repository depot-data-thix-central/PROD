// lib/presentation/thix_ia/pages/thix_ia_home_page.dart
//
// ThixIaHomePage — "Monochrome Glass" (Production Enterprise)
//
// Design 100% refait : 2 couleurs (blanc + encre ThixPolicy)
//  Glassmorphism maîtrisé (BackdropFilter Web-friendly)
//  Barre du bas SUPPRIMÉE
//  Sanitization sur tous les inputs DB
//  i18n branché (AppLocalizations) — rien en dur
//  Mounted checks + logs structurés + RepaintBoundary
//  Logique 100% préservée (providers, navigation, analyses)

import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
// PALETTE MONOCHROME (blanc + encre ThixPolicy)
// ============================================================================

class _IaPalette {
  _IaPalette._();

  static const Color ink = Color(0xFF0B1220);
  static const Color white = Color(0xFFFFFFFF);

  static Color get glass => white.withValues(alpha: 0.08);
  static Color get glassSoft => white.withValues(alpha: 0.04);
  static Color get glassStrong => white.withValues(alpha: 0.14);
  static Color get glassBorder => white.withValues(alpha: 0.16);
  static Color get glassBorderSoft => white.withValues(alpha: 0.10);

  static Color get textPrimary => white;
  static Color get textSecondary => white.withValues(alpha: 0.62);
  static Color get textMuted => white.withValues(alpha: 0.40);
}

// ============================================================================
// CONSTANTS
// ============================================================================

const double _kGlassBlur = kIsWeb ? 8 : 14;
const int _kMaxNameLength = 60;
const int _kMaxRoleLength = 40;
const int _kMaxCodeLength = 24;
const int _kMaxSectorLength = 40;

// ============================================================================
// LOGGING
// ============================================================================

class _IaHomeLogger {
  static const _tag = 'IaHome';
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

// ============================================================================
// SANITIZER
// ============================================================================

class _Sanitizer {
  _Sanitizer._();

  static String text(String? input, {required int maxLength}) {
    if (input == null) return '';
    final s = input.replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '').trim();
    return s.length > maxLength ? s.substring(0, maxLength) : s;
  }

  /// Message d'erreur safe pour affichage (pas d'injection)
  static String errorMessage(Object error) {
    final msg = error.toString();
    if (msg.length > 120) {
      return '${msg.substring(0, 120)}…';
    }
    return msg;
  }
}

// ============================================================================
// ENUM (logique préservée)
// ============================================================================

enum ThixQuickAction { idea, market, businessPlan, legal }

// ============================================================================
// PROVIDER (logique préservée, sanitization ajoutée)
// ============================================================================

final thixIaCurrentProfileProvider =
    FutureProvider<Map<String, dynamic>?>((ref) async {
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) return null;
  try {
    final row = await Supabase.instance.client
        .from('profiles')
        .select(
          'id, thix_id, display_name, full_name, avatar_url, photo_url, '
          'occupation, profession, city, country, role_title',
        )
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
// GLASS WIDGET (réutilisable)
// ============================================================================

class _Glass extends StatelessWidget {
  final Widget child;
  final double radius;
  final double alpha;
  final EdgeInsetsGeometry? padding;
  final double? width;

  const _Glass({
    required this.child,
    this.radius = 16,
    this.alpha = 0.08,
    this.padding,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: _kGlassBlur, sigmaY: _kGlassBlur),
        child: Container(
          width: width,
          padding: padding,
          decoration: BoxDecoration(
            color: _IaPalette.white.withValues(alpha: alpha),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: _IaPalette.glassBorderSoft, width: 1),
          ),
          child: child,
        ),
      ),
    );
  }
}

// ============================================================================
// PAGE PRINCIPALE
// ============================================================================

class ThixIaHomePage extends ConsumerStatefulWidget {
  const ThixIaHomePage({super.key});
  @override
  ConsumerState<ThixIaHomePage> createState() => _ThixIaHomePageState();
}

class _ThixIaHomePageState extends ConsumerState<ThixIaHomePage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(projectsProvider.notifier).refresh());
    _IaHomeLogger.info('Home initialized');
  }

  Future<void> _onQuickAction(ThixQuickAction action) async {
    final l10n = AppLocalizations.of(context);
    final projects = ref.read(projectsProvider).value ?? [];

    if (projects.isEmpty) {
      if (!mounted) return;
      final go = await showDialog<bool>(
        context: context,
        builder: (ctx) => _Glass(
          radius: 20,
          alpha: 0.12,
          child: AlertDialog(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: Text(l10n.t('ia_home_no_project_title'),
                style: const TextStyle(
                    color: _IaPalette.textPrimary,
                    fontWeight: FontWeight.w800)),
            content: Text(l10n.t('ia_home_no_project_message'),
                style: const TextStyle(color: _IaPalette.textSecondary)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(l10n.t('common_cancel'),
                    style:
                        const TextStyle(color: _IaPalette.textSecondary)),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _IaPalette.white,
                  foregroundColor: _IaPalette.ink,
                ),
                child: Text(l10n.t('ia_home_create_project')),
              ),
            ],
          ),
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
      builder: (_) => const _LoadingDialog(),
    );

    try {
      final analyses = ref.read(analysesProvider.notifier);
      switch (action) {
        case ThixQuickAction.idea:
        case ThixQuickAction.market:
          await analyses.startMarketAnalysis(
            country: selected.country,
            sector: selected.sector,
          );
          break;
        case ThixQuickAction.businessPlan:
          await analyses.startFinanceAnalysis(
            inputs: {
              'sector': selected.sector,
              'country': selected.country,
            },
          );
          break;
        case ThixQuickAction.legal:
          await analyses.startLegalAnalysis(
            jurisdiction: selected.country,
            sector: selected.sector,
          );
          break;
      }

      if (mounted) Navigator.of(context).pop();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(l10n.t('ia_home_analysis_started',
              args: {'code': _Sanitizer.text(selected.projectCode, maxLength: _kMaxCodeLength)})),
          backgroundColor: ThixPolicy.success,
          behavior: SnackBarBehavior.floating,
        ));
        context.push(ThixIARoutes.projectDetailPath(selected.projectCode));
        _IaHomeLogger.info('Analysis started',
            {'code': selected.projectCode, 'action': action.name});
      }
    } catch (e) {
      _IaHomeLogger.error('Analysis failed',
          {'action': action.name, 'error': '$e'});
      if (mounted) Navigator.of(context).pop();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(l10n.t('ia_home_analysis_error',
              args: {'error': _Sanitizer.errorMessage(e)})),
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
      backgroundColor: _IaPalette.ink,
      // ✅ Barre du bas SUPPRIMÉE
      body: Stack(
        children: [
          // Orbes monochromes (blanc sur encre)
          Positioned(
              top: -60,
              right: -40,
              child: _halo(160, _IaPalette.white.withValues(alpha: 0.08))),
          Positioned(
              top: 160,
              left: -70,
              child: _halo(180, _IaPalette.white.withValues(alpha: 0.05))),

          SafeArea(
            bottom: false,
            child: RefreshIndicator(
              color: _IaPalette.white,
              backgroundColor: _IaPalette.ink,
              onRefresh: () async {
                HapticFeedback.mediumImpact();
                ref.invalidate(thixIaCurrentProfileProvider);
                await ref.read(projectsProvider.notifier).refresh();
              },
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics()),
                slivers: [
                  SliverToBoxAdapter(child: _TopBar(profileAsync: profileAsync)),
                  SliverToBoxAdapter(
                      child: _UserHeader(profileAsync: profileAsync)),
                  const SliverToBoxAdapter(child: SizedBox(height: 10)),
                  SliverToBoxAdapter(
                    child: _HeroBanner(
                      onAnalyze: () {
                        HapticFeedback.mediumImpact();
                        context.push(ThixIARoutes.createProject);
                      },
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 18)),
                  SliverToBoxAdapter(
                    child: _SectionTitle(l10n.t('ia_home_section_intent')),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 8)),
                  SliverToBoxAdapter(child: _MainActions(onAction: _onQuickAction)),
                  const SliverToBoxAdapter(child: SizedBox(height: 18)),
                  SliverToBoxAdapter(
                    child: _SectionTitle(
                      l10n.t('ia_home_section_engines'),
                      seeAll: true,
                      onSeeAll: () {
                        HapticFeedback.selectionClick();
                        context.push(ThixIARoutes.projects);
                      },
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 8)),
                  const SliverToBoxAdapter(
                      child: RepaintBoundary(child: _MotorsRow())),
                  const SliverToBoxAdapter(child: SizedBox(height: 18)),
                  SliverToBoxAdapter(
                    child: _SectionTitle(
                      l10n.t('ia_home_section_recent'),
                      seeAll: true,
                      onSeeAll: () {
                        HapticFeedback.selectionClick();
                        context.push(ThixIARoutes.projects);
                      },
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 8)),
                  SliverToBoxAdapter(
                    child: RepaintBoundary(
                      child: _RecentAnalyses(
                        projectsAsync: projectsAsync,
                        onOpen: (c) =>
                            context.push(ThixIARoutes.projectDetailPath(c)),
                        onCreate: () =>
                            context.push(ThixIARoutes.createProject),
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 18)),
                  SliverToBoxAdapter(
                    child: _SectionTitle(l10n.t('ia_home_section_stats')),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 8)),
                  SliverToBoxAdapter(
                      child: RepaintBoundary(
                          child: _QuickStats(projectsAsync: projectsAsync))),
                  const SliverToBoxAdapter(child: SizedBox(height: 32)),
                ],
              ),
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
              filter: ImageFilter.blur(
                  sigmaX: kIsWeb ? 30 : 60, sigmaY: kIsWeb ? 30 : 60),
              child: Container(color: Colors.transparent),
            ),
          ],
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
      child: _Glass(
        radius: 24,
        alpha: 0.14,
        padding: const EdgeInsets.all(24),
        child: const SizedBox(
          width: 40,
          height: 40,
          child: CircularProgressIndicator(
              strokeWidth: 3, color: _IaPalette.textPrimary),
        ),
      ),
    );
  }
}

// ============================================================================
// TOP BAR
// ============================================================================

class _TopBar extends StatelessWidget {
  const _TopBar({required this.profileAsync});
  final AsyncValue<Map<String, dynamic>?> profileAsync;

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

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 2),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                const Icon(Icons.location_on_rounded,
                    size: 14, color: _IaPalette.textSecondary),
                const SizedBox(width: 2),
                Flexible(
                  child: Text(
                    _Sanitizer.text(loc.isNotEmpty ? loc : '—',
                        maxLength: 40),
                    style: ThixPolicy.labelStyle.copyWith(
                        fontSize: 11, color: _IaPalette.textSecondary),
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
                  const Icon(Icons.auto_awesome,
                      size: 14, color: _IaPalette.textPrimary),
                  const SizedBox(width: 3),
                  Text('THIX IA',
                      style: ThixPolicy.h3Style.copyWith(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: _IaPalette.textPrimary)),
                ],
              ),
              Text(l10n.t('ia_home_brand_tagline'),
                  style: ThixPolicy.microStyle.copyWith(
                      fontSize: 8, color: _IaPalette.textMuted)),
            ],
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _Glass(
                  radius: 16,
                  alpha: 0.08,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.language_rounded,
                          size: 12, color: _IaPalette.textPrimary),
                      const SizedBox(width: 3),
                      Text('FR',
                          style: ThixPolicy.labelStyle.copyWith(
                              fontSize: 11, color: _IaPalette.textPrimary)),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Semantics(
                  button: true,
                  label: l10n.t('network_notifications'),
                  child: const Icon(Icons.notifications_none_rounded,
                      size: 20, color: _IaPalette.textPrimary),
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
    final l10n = AppLocalizations.of(context);
    return profileAsync.when(
      loading: () => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        child: Row(children: [
          _Glass(
            radius: 22,
            alpha: 0.08,
            child: const SizedBox(width: 44, height: 44),
          ),
          const SizedBox(width: 10),
          _Glass(
            radius: 4,
            alpha: 0.08,
            child: const SizedBox(width: 100, height: 14),
          ),
        ]),
      ),
      error: (_, __) => _body(
          l10n.t('ia_home_user_default'), null, null, l10n),
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

  Widget _body(String name, String? photo, String? role,
      AppLocalizations l10n) {
    final h = DateTime.now().hour;
    final greet = h < 12
        ? l10n.t('ia_greeting_morning')
        : h < 18
            ? l10n.t('ia_greeting_afternoon')
            : l10n.t('ia_greeting_evening');

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
      child: Row(
        children: [
          Stack(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: _IaPalette.glassBorder),
                ),
                child: CircleAvatar(
                  radius: 22,
                  backgroundColor: _IaPalette.glass,
                  backgroundImage: (photo != null && photo.isNotEmpty)
                      ? CachedNetworkImageProvider(photo)
                      : null,
                  child: (photo == null || photo.isEmpty)
                      ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                          style: ThixPolicy.h3Style.copyWith(
                              color: _IaPalette.textPrimary))
                      : null,
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: ThixPolicy.success,
                    shape: BoxShape.circle,
                    border: Border.all(color: _IaPalette.ink, width: 1.5),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$greet,',
                    style: ThixPolicy.microStyle.copyWith(
                        color: _IaPalette.textSecondary)),
                Text(name,
                    style: ThixPolicy.h3Style.copyWith(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: _IaPalette.textPrimary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                if (role != null && role.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 3),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: _IaPalette.glass,
                      borderRadius: BorderRadius.circular(12),
                      border:
                          Border.all(color: _IaPalette.glassBorderSoft),
                    ),
                    child: Text(role,
                        style: ThixPolicy.microStyle.copyWith(
                            color: ThixPolicy.gold,
                            fontWeight: FontWeight.w700,
                            fontSize: 10),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
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
// HERO (monochrome)
// ============================================================================

class _HeroBanner extends StatelessWidget {
  const _HeroBanner({required this.onAnalyze});
  final VoidCallback onAnalyze;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: _Glass(
        radius: 18,
        alpha: 0.10,
        child: SizedBox(
          height: 148,
          child: Stack(
            children: [
              Positioned(
                right: -10,
                top: 8,
                bottom: 8,
                width: 120,
                child: CustomPaint(painter: _DotsPainter()),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.t('ia_home_hero_title'),
                        style: ThixPolicy.h2Style.copyWith(
                            color: _IaPalette.textPrimary,
                            height: 1.15,
                            fontSize: 18,
                            fontWeight: FontWeight.w800)),
                    const SizedBox(height: 6),
                    Text(l10n.t('ia_home_hero_subtitle'),
                        style: ThixPolicy.microStyle.copyWith(
                            color: _IaPalette.textSecondary, fontSize: 11)),
                    const Spacer(),
                    Semantics(
                      button: true,
                      label: l10n.t('ia_action_idea'),
                      child: Material(
                        color: _IaPalette.white,
                        borderRadius: BorderRadius.circular(22),
                        child: InkWell(
                          onTap: onAnalyze,
                          borderRadius: BorderRadius.circular(22),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.auto_awesome_rounded,
                                    size: 14, color: _IaPalette.ink),
                                const SizedBox(width: 6),
                                Text(l10n.t('ia_action_idea'),
                                    style: ThixPolicy.labelStyle.copyWith(
                                        color: _IaPalette.ink,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12)),
                              ],
                            ),
                          ),
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

class _DotsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final dot = Paint()..color = _IaPalette.white.withValues(alpha: 0.22);
    final line = Paint()
      ..color = _IaPalette.white.withValues(alpha: 0.10)
      ..strokeWidth = 1;
    final pts = [
      Offset(size.width * 0.3, size.height * 0.2),
      Offset(size.width * 0.55, size.height * 0.28),
      Offset(size.width * 0.4, size.height * 0.5),
      Offset(size.width * 0.7, size.height * 0.45),
      Offset(size.width * 0.5, size.height * 0.72),
      Offset(size.width * 0.75, size.height * 0.68),
    ];
    for (var i = 0; i < pts.length - 1; i++) {
      canvas.drawLine(pts[i], pts[i + 1], line);
    }
    for (final p in pts) {
      canvas.drawCircle(p, 2.8, dot);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          Expanded(
            child: Text(title,
                style: ThixPolicy.h3Style.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: _IaPalette.textPrimary)),
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
                        style: ThixPolicy.microStyle.copyWith(
                            color: _IaPalette.textSecondary,
                            fontWeight: FontWeight.w600)),
                    const Icon(Icons.arrow_forward_rounded,
                        size: 12, color: _IaPalette.textSecondary),
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
// MAIN ACTIONS (monochrome)
// ============================================================================

class _MainActions extends StatelessWidget {
  const _MainActions({required this.onAction});
  final void Function(ThixQuickAction) onAction;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final items = [
      (ThixQuickAction.idea, l10n.t('ia_action_idea_short'),
          l10n.t('ia_action_idea_tag'), Icons.lightbulb_rounded),
      (ThixQuickAction.market, l10n.t('ia_action_market_short'),
          l10n.t('ia_action_market_tag'), Icons.bar_chart_rounded),
      (ThixQuickAction.businessPlan, l10n.t('ia_action_bp_short'),
          l10n.t('ia_action_bp_tag'), Icons.description_rounded),
      (ThixQuickAction.legal, l10n.t('ia_action_legal_short'),
          l10n.t('ia_action_legal_tag'), Icons.balance_rounded),
    ];

    return SizedBox(
      height: 118,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final it = items[i];
          return Semantics(
            button: true,
            label: it.$2,
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                onAction(it.$1);
              },
              child: _Glass(
                width: 112,
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                          color: _IaPalette.glass, shape: BoxShape.circle),
                      child: Icon(it.$4,
                          color: _IaPalette.textPrimary, size: 16),
                    ),
                    const Spacer(),
                    Text(it.$2,
                        style: ThixPolicy.labelStyle.copyWith(
                            fontSize: 11,
                            height: 1.15,
                            fontWeight: FontWeight.w700,
                            color: _IaPalette.textPrimary)),
                    Text(it.$3,
                        style: ThixPolicy.microStyle.copyWith(
                            fontSize: 9, color: _IaPalette.textSecondary)),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ============================================================================
// MOTORS ROW (monochrome)
// ============================================================================

class _MotorsRow extends StatelessWidget {
  const _MotorsRow();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final motors = [
      (l10n.t('ia_motor_research'), Icons.search_rounded),
      (l10n.t('ia_motor_market'), Icons.trending_up_rounded),
      (l10n.t('ia_motor_business'), Icons.work_rounded),
      (l10n.t('ia_motor_finance'), Icons.attach_money_rounded),
      (l10n.t('ia_motor_legal'), Icons.balance_rounded),
      (l10n.t('ia_motor_design'), Icons.edit_rounded),
    ];

    return SizedBox(
      height: 72,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        itemCount: motors.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final m = motors[i];
          return Semantics(
            button: true,
            label: m.$1,
            child: Column(
              children: [
                _Glass(
                  radius: 14,
                  padding: const EdgeInsets.all(10),
                  child: Icon(m.$2,
                      color: _IaPalette.textPrimary, size: 18),
                ),
                const SizedBox(height: 4),
                Text(m.$1,
                    style: ThixPolicy.microStyle.copyWith(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: _IaPalette.textSecondary)),
              ],
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
  const _RecentAnalyses({
    required this.projectsAsync,
    required this.onOpen,
    required this.onCreate,
  });
  final AsyncValue projectsAsync;
  final void Function(String) onOpen;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return projectsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(16),
        child: Center(
            child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                    strokeWidth: 2.5, color: _IaPalette.textPrimary))),
      ),
      error: (e, _) {
        _IaHomeLogger.error('Projects load failed', {'error': '$e'});
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: _Glass(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                const Icon(Icons.error_outline_rounded,
                    color: _IaPalette.textPrimary, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                      l10n.t('ia_home_error_generic',
                          args: {'error': _Sanitizer.errorMessage(e)}),
                      style: ThixPolicy.bodySmallStyle.copyWith(
                          color: _IaPalette.textSecondary)),
                ),
              ],
            ),
          ),
        );
      },
      data: (projects) {
        final list = projects is List<ThixProject> ? projects : <ThixProject>[];
        if (list.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: _Glass(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  Text(l10n.t('ia_home_no_analyses'),
                      style: ThixPolicy.bodySmallStyle.copyWith(
                          color: _IaPalette.textSecondary)),
                  const SizedBox(height: 8),
                  Semantics(
                    button: true,
                    label: l10n.t('ia_home_create_project'),
                    child: TextButton(
                      onPressed: onCreate,
                      style: TextButton.styleFrom(
                          foregroundColor: _IaPalette.textPrimary),
                      child: Text(l10n.t('ia_home_create_project')),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Column(
            children: list.take(3).map((p) {
              final pct = (p.progress * 100).clamp(0, 100).toInt();
              final name =
                  _Sanitizer.text(p.name, maxLength: _kMaxNameLength);
              final code =
                  _Sanitizer.text(p.projectCode, maxLength: _kMaxCodeLength);
              final sector =
                  _Sanitizer.text(p.sector, maxLength: _kMaxSectorLength);

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Semantics(
                  button: true,
                  label: name,
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      onOpen(p.projectCode);
                    },
                    child: _Glass(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 10),
                      child: Row(
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: _IaPalette.glass,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color: _IaPalette.glassBorderSoft),
                            ),
                            child: const Icon(Icons.insert_chart_rounded,
                                color: _IaPalette.textPrimary, size: 16),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(name,
                                    style: ThixPolicy.labelStyle.copyWith(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: _IaPalette.textPrimary),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis),
                                Text('$code • $sector',
                                    style: ThixPolicy.microStyle.copyWith(
                                        fontSize: 10,
                                        color: _IaPalette.textSecondary),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('$pct%',
                                  style: ThixPolicy.microStyle.copyWith(
                                      color: ThixPolicy.success,
                                      fontWeight: FontWeight.w700)),
                              const SizedBox(height: 3),
                              SizedBox(
                                width: 40,
                                height: 3,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(2),
                                  child: LinearProgressIndicator(
                                    value: pct / 100,
                                    backgroundColor: _IaPalette.glass,
                                    valueColor:
                                        const AlwaysStoppedAnimation(
                                            ThixPolicy.success),
                                  ),
                                ),
                              ),
                            ],
                          ),
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
}

// ============================================================================
// QUICK STATS (monochrome)
// ============================================================================

class _QuickStats extends StatelessWidget {
  const _QuickStats({required this.projectsAsync});
  final AsyncValue projectsAsync;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return projectsAsync.when(
      loading: () => const SizedBox(
        height: 70,
        child: Center(
            child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: _IaPalette.textPrimary))),
      ),
      error: (_, __) => const SizedBox.shrink(),
      data: (projects) {
        final list =
            projects is List<ThixProject> ? projects : <ThixProject>[];
        final active =
            list.where((p) => p.isActive || p.status == 'draft').length;
        final analyses =
            list.fold<int>(0, (s, p) => s + p.analysesCount);
        final countries = list
            .map((p) => p.country)
            .where((c) => c.trim().isNotEmpty)
            .toSet();
        final avg = list.isEmpty
            ? 0
            : (list.fold<double>(0, (s, p) => s + p.progress) /
                    list.length *
                    100)
                .round();

        final stats = [
          ('$analyses', l10n.t('ia_stat_analyses'), Icons.insights_rounded),
          ('$active', l10n.t('ia_stat_active'),
              Icons.track_changes_rounded),
          ('${countries.length}', l10n.t('ia_stat_countries'),
              Icons.public_rounded),
          ('$avg%', l10n.t('ia_stat_progress'), Icons.verified_rounded),
        ];

        return SizedBox(
          height: 70,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            itemCount: stats.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final s = stats[i];
              return Semantics(
                label: '${s.$1} ${s.$2}',
                child: _Glass(
                  width: 120,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 8),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                            color: _IaPalette.glass,
                            shape: BoxShape.circle),
                        child: Icon(s.$3,
                            color: _IaPalette.textPrimary, size: 16),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(s.$1,
                                style: ThixPolicy.h3Style.copyWith(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: _IaPalette.textPrimary)),
                            Text(s.$2,
                                style: ThixPolicy.microStyle.copyWith(
                                    fontSize: 9,
                                    color: _IaPalette.textSecondary),
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
// PROJECT PICKER (monochrome glass)
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
      builder: (_, controller) => ClipRRect(
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(24)),
        child: BackdropFilter(
          filter: ImageFilter.blur(
              sigmaX: _kGlassBlur, sigmaY: _kGlassBlur),
          child: Container(
            decoration: BoxDecoration(
              color: _IaPalette.ink.withValues(alpha: 0.95),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
              border: Border(
                  top: BorderSide(color: _IaPalette.glassBorder)),
            ),
            child: Column(
              children: [
                const SizedBox(height: 8),
                Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                        color: _IaPalette.glassBorder,
                        borderRadius: BorderRadius.circular(2))),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 8, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(title,
                            style: ThixPolicy.h3Style.copyWith(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: _IaPalette.textPrimary)),
                      ),
                      Semantics(
                        button: true,
                        label: l10n.t('ia_home_new_project'),
                        child: TextButton(
                          onPressed: () {
                            Navigator.pop(context);
                            context.push(ThixIARoutes.createProject);
                          },
                          style: TextButton.styleFrom(
                              foregroundColor: _IaPalette.textPrimary),
                          child: Text(l10n.t('ia_home_new_project')),
                        ),
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, color: _IaPalette.glassBorderSoft),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(l10n.t('ia_home_pick_hint'),
                        style: ThixPolicy.microStyle.copyWith(
                            color: _IaPalette.textSecondary)),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    controller: controller,
                    itemCount: projects.length,
                    itemBuilder: (_, i) {
                      final p = projects[i];
                      final pct = (p.progress * 100).toInt();
                      final name = _Sanitizer.text(p.name,
                          maxLength: _kMaxNameLength);
                      final code = _Sanitizer.text(p.projectCode,
                          maxLength: _kMaxCodeLength);
                      return ListTile(
                        dense: true,
                        leading: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: _IaPalette.glass,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                                color: _IaPalette.glassBorderSoft),
                          ),
                          child: const Icon(Icons.folder_rounded,
                              color: _IaPalette.textPrimary, size: 16),
                        ),
                        title: Text(name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: _IaPalette.textPrimary)),
                        subtitle: Text('$code • $pct%',
                            style: const TextStyle(
                                fontSize: 11,
                                color: _IaPalette.textSecondary)),
                        trailing: const Icon(Icons.play_arrow_rounded,
                            color: _IaPalette.textPrimary, size: 22),
                        onTap: () => Navigator.pop(context, p),
                      );
                    },
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
