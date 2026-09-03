// lib/presentation/thix_ia/pages/thix_ia_home_page.dart
//
// ThixIaHomePage — "Modern Sleek Light" (Production Enterprise)
//
// Design 200% refait : Thème BLANC / CLAIR éclatant.
// - Background off-white avec cartes pure white (SleekCard)
// - Ombres ultra-douces (Apple-like) et bordures subtiles
// - Orbes de fond (Primary) pour un effet IA moderne
// - Logique 100% préservée, Sanitization, i18n avec args: []
// - Zéro erreur de constante (const) avec la palette.

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
// PALETTE CLAIRE (Light Mode Premium)
// ============================================================================

class _IaLightPalette {
  _IaLightPalette._();

  static const Color background = Color(0xFFF8FAFC); // Gris/Bleu très très clair
  static const Color surface = Color(0xFFFFFFFF);    // Blanc pur pour les cartes
  static const Color border = Color(0xFFE2E8F0);     // Bordures douces

  static const Color textPrimary = Color(0xFF0F172A); // Encre très foncée
  static const Color textSecondary = Color(0xFF475569); // Gris moyen
  static const Color textMuted = Color(0xFF94A3B8);   // Gris clair
}

// ============================================================================
// CONSTANTS
// ============================================================================

const int _kMaxNameLength = 60;
const int _kMaxRoleLength = 40;
const int _kMaxCodeLength = 24;
const int _kMaxSectorLength = 40;

// ============================================================================
// LOGGING
// ============================================================================

class _IaHomeLogger {
  static const _tag = 'IaHomeLight';
  static void info(String m, [Map<String, dynamic>? d]) => _log('INFO', m, d);
  static void warn(String m, [Map<String, dynamic>? d]) => _log('WARN', m, d);
  static void error(String m, [Map<String, dynamic>? d]) => _log('ERROR', m, d);
  static void _log(String l, String m, Map<String, dynamic>? d) {
    if (!kDebugMode && l == 'INFO') return;
    final data = d != null ? ' ${d.entries.map((e) => '${e.key}=${e.value}').join(', ')}' : '';
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
// PROVIDER
// ============================================================================

final thixIaCurrentProfileProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) return null;
  try {
    final row = await Supabase.instance.client
        .from('profiles')
        .select('id, thix_id, display_name, full_name, avatar_url, photo_url, occupation, profession, city, country, role_title')
        .eq('id', user.id)
        .maybeSingle();
    if (row != null) return row;
  } catch (e) {
    _IaHomeLogger.warn('Profile fetch failed', {'error': '$e'});
  }
  return {
    'id': user.id,
    'display_name': _Sanitizer.text(
        user.userMetadata?['display_name'] ?? user.email?.split('@').first ?? 'Utilisateur',
        maxLength: _kMaxNameLength),
    'avatar_url': user.userMetadata?['avatar_url'],
  };
});

// ============================================================================
// SLEEK CARD WIDGET (Remplace le Glassmorphism)
// ============================================================================

class _SleekCard extends StatelessWidget {
  final Widget child;
  final double radius;
  final EdgeInsetsGeometry? padding;
  final double? width;
  final bool hasShadow;

  const _SleekCard({
    required this.child,
    this.radius = 20,
    this.padding,
    this.width,
    this.hasShadow = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: padding,
      decoration: BoxDecoration(
        color: _IaLightPalette.surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: _IaLightPalette.border, width: 1),
        boxShadow: hasShadow
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ]
            : null,
      ),
      child: child,
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
    _IaHomeLogger.info('Home initialized (Light Mode)');
  }

  Future<void> _onQuickAction(ThixQuickAction action) async {
    final l10n = AppLocalizations.of(context);
    final projects = ref.read(projectsProvider).value ?? [];

    if (projects.isEmpty) {
      if (!mounted) return;
      final go = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: _IaLightPalette.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(l10n.t('ia_home_no_project_title'),
              style: const TextStyle(color: _IaLightPalette.textPrimary, fontWeight: FontWeight.w800)),
          content: Text(l10n.t('ia_home_no_project_message'),
              style: const TextStyle(color: _IaLightPalette.textSecondary)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.t('common_cancel'), style: const TextStyle(color: _IaLightPalette.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: ThixPolicy.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

    await ref.read(activeProjectProvider.notifier).setActive(selected.projectCode);

    if (!mounted) return;
    showDialog(context: context, barrierDismissible: false, builder: (_) => const _LoadingDialog());

    try {
      final analyses = ref.read(analysesProvider.notifier);
      switch (action) {
        case ThixQuickAction.idea:
        case ThixQuickAction.market:
          await analyses.startMarketAnalysis(country: selected.country, sector: selected.sector);
          break;
        case ThixQuickAction.businessPlan:
          await analyses.startFinanceAnalysis(inputs: {'sector': selected.sector, 'country': selected.country});
          break;
        case ThixQuickAction.legal:
          await analyses.startLegalAnalysis(jurisdiction: selected.country, sector: selected.sector);
          break;
      }

      if (mounted) Navigator.of(context).pop();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(l10n.t('ia_home_analysis_started', args: [_Sanitizer.text(selected.projectCode, maxLength: _kMaxCodeLength)])),
          backgroundColor: ThixPolicy.success,
          behavior: SnackBarBehavior.floating,
        ));
        context.push(ThixIARoutes.projectDetailPath(selected.projectCode));
      }
    } catch (e) {
      if (mounted) Navigator.of(context).pop();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(l10n.t('ia_home_analysis_error', args: [_Sanitizer.errorMessage(e)])),
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
      backgroundColor: _IaLightPalette.background,
      body: Stack(
        children: [
          // Orbes d'ambiance douces en arrière-plan (Style IA Moderne)
          Positioned(top: -100, right: -50, child: _halo(250, ThixPolicy.primary.withValues(alpha: 0.15))),
          Positioned(top: 200, left: -100, child: _halo(300, const Color(0xFF8B5CF6).withValues(alpha: 0.10))), // Touche violette

          SafeArea(
            bottom: false,
            child: RefreshIndicator(
              color: ThixPolicy.primary,
              backgroundColor: _IaLightPalette.surface,
              onRefresh: () async {
                HapticFeedback.mediumImpact();
                ref.invalidate(thixIaCurrentProfileProvider);
                await ref.read(projectsProvider.notifier).refresh();
              },
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                slivers: [
                  SliverToBoxAdapter(child: _TopBar(profileAsync: profileAsync)),
                  SliverToBoxAdapter(child: _UserHeader(profileAsync: profileAsync)),
                  const SliverToBoxAdapter(child: SizedBox(height: 16)),
                  SliverToBoxAdapter(child: _HeroBanner(onAnalyze: () {
                    HapticFeedback.mediumImpact();
                    context.push(ThixIARoutes.createProject);
                  })),
                  const SliverToBoxAdapter(child: SizedBox(height: 24)),
                  SliverToBoxAdapter(child: _SectionTitle(l10n.t('ia_home_section_intent'))),
                  const SliverToBoxAdapter(child: SizedBox(height: 12)),
                  SliverToBoxAdapter(child: _MainActions(onAction: _onQuickAction)),
                  const SliverToBoxAdapter(child: SizedBox(height: 24)),
                  SliverToBoxAdapter(child: _SectionTitle(l10n.t('ia_home_section_engines'), seeAll: true, onSeeAll: () {
                    HapticFeedback.selectionClick();
                    context.push(ThixIARoutes.projects);
                  })),
                  const SliverToBoxAdapter(child: SizedBox(height: 12)),
                  const SliverToBoxAdapter(child: RepaintBoundary(child: _MotorsRow())),
                  const SliverToBoxAdapter(child: SizedBox(height: 24)),
                  SliverToBoxAdapter(child: _SectionTitle(l10n.t('ia_home_section_recent'), seeAll: true, onSeeAll: () {
                    HapticFeedback.selectionClick();
                    context.push(ThixIARoutes.projects);
                  })),
                  const SliverToBoxAdapter(child: SizedBox(height: 12)),
                  SliverToBoxAdapter(child: RepaintBoundary(child: _RecentAnalyses(
                    projectsAsync: projectsAsync,
                    onOpen: (c) => context.push(ThixIARoutes.projectDetailPath(c)),
                    onCreate: () => context.push(ThixIARoutes.createProject),
                  ))),
                  const SliverToBoxAdapter(child: SizedBox(height: 24)),
                  SliverToBoxAdapter(child: _SectionTitle(l10n.t('ia_home_section_stats'))),
                  const SliverToBoxAdapter(child: SizedBox(height: 12)),
                  SliverToBoxAdapter(child: RepaintBoundary(child: _QuickStats(projectsAsync: projectsAsync))),
                  const SliverToBoxAdapter(child: SizedBox(height: 40)),
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
            Container(decoration: BoxDecoration(shape: BoxShape.circle, color: c)),
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
// LOADING DIALOG
// ============================================================================

class _LoadingDialog extends StatelessWidget {
  const _LoadingDialog();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: _SleekCard(
        radius: 24,
        padding: const EdgeInsets.all(24),
        child: const SizedBox(
          width: 40,
          height: 40,
          child: CircularProgressIndicator(strokeWidth: 3, color: ThixPolicy.primary),
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
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 4),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                const Icon(Icons.location_on_rounded, size: 16, color: _IaLightPalette.textSecondary),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    _Sanitizer.text(loc.isNotEmpty ? loc : '—', maxLength: 40),
                    style: const TextStyle(fontSize: 12, color: _IaLightPalette.textSecondary, fontWeight: FontWeight.w600),
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
                  const Icon(Icons.auto_awesome_rounded, size: 16, color: ThixPolicy.primary),
                  const SizedBox(width: 4),
                  Text('THIX IA', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: _IaLightPalette.textPrimary, letterSpacing: -0.5)),
                ],
              ),
              Text(l10n.t('ia_home_brand_tagline'), style: const TextStyle(fontSize: 9, color: _IaLightPalette.textMuted, fontWeight: FontWeight.w600)),
            ],
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: _IaLightPalette.border, borderRadius: BorderRadius.circular(12)),
                  child: const Text('FR', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _IaLightPalette.textPrimary)),
                ),
                const SizedBox(width: 12),
                Semantics(
                  button: true,
                  label: l10n.t('network_notifications'),
                  child: const Icon(Icons.notifications_none_rounded, size: 24, color: _IaLightPalette.textPrimary),
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
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: SizedBox(width: 44, height: 44, child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (_, __) => _body(l10n.t('ia_home_user_default'), null, null, l10n),
      data: (p) => _body(
        _Sanitizer.text(_pick(p, ['display_name', 'full_name']) ?? l10n.t('ia_home_user_default'), maxLength: _kMaxNameLength),
        _pick(p, ['avatar_url', 'photo_url']),
        _Sanitizer.text(_pick(p, ['role_title', 'occupation', 'profession']), maxLength: _kMaxRoleLength),
        l10n,
      ),
    );
  }

  Widget _body(String name, String? photo, String? role, AppLocalizations l10n) {
    final h = DateTime.now().hour;
    final greet = h < 12 ? l10n.t('ia_greeting_morning') : h < 18 ? l10n.t('ia_greeting_afternoon') : l10n.t('ia_greeting_evening');

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: _IaLightPalette.surface, width: 2),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))],
            ),
            child: CircleAvatar(
              radius: 26,
              backgroundColor: _IaLightPalette.border,
              backgroundImage: (photo != null && photo.isNotEmpty) ? CachedNetworkImageProvider(photo) : null,
              child: (photo == null || photo.isEmpty) ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?', style: const TextStyle(color: _IaLightPalette.textPrimary, fontWeight: FontWeight.bold)) : null,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$greet,', style: const TextStyle(fontSize: 13, color: _IaLightPalette.textSecondary, fontWeight: FontWeight.w600)),
                Text(name, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: _IaLightPalette.textPrimary, letterSpacing: -0.3), maxLines: 1, overflow: TextOverflow.ellipsis),
                if (role != null && role.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(role, style: const TextStyle(color: ThixPolicy.primary, fontWeight: FontWeight.w700, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
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
// HERO BANNER (Vibrant & Clean)
// ============================================================================

class _HeroBanner extends StatelessWidget {
  const _HeroBanner({required this.onAnalyze});
  final VoidCallback onAnalyze;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        height: 160,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [ThixPolicy.primary, ThixPolicy.primaryDeep],
          ),
          boxShadow: [
            BoxShadow(color: ThixPolicy.primary.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 8)),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              right: -20,
              top: -20,
              child: Icon(Icons.auto_awesome_rounded, size: 140, color: Colors.white.withValues(alpha: 0.1)),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.t('ia_home_hero_title'), style: const TextStyle(color: Colors.white, height: 1.1, fontSize: 22, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 8),
                  Text(l10n.t('ia_home_hero_subtitle'), style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12, fontWeight: FontWeight.w500)),
                  const Spacer(),
                  Semantics(
                    button: true,
                    label: l10n.t('ia_action_idea'),
                    child: ElevatedButton.icon(
                      onPressed: onAnalyze,
                      icon: const Icon(Icons.bolt_rounded, size: 18),
                      label: Text(l10n.t('ia_action_idea'), style: const TextStyle(fontWeight: FontWeight.w800)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: ThixPolicy.primary,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
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
          Expanded(
            child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: _IaLightPalette.textPrimary, letterSpacing: -0.3)),
          ),
          if (seeAll && onSeeAll != null)
            Semantics(
              button: true,
              label: l10n.t('common_see_all'),
              child: GestureDetector(
                onTap: onSeeAll,
                child: Row(
                  children: [
                    Text(l10n.t('common_see_all'), style: const TextStyle(color: ThixPolicy.primary, fontWeight: FontWeight.w700, fontSize: 13)),
                    const SizedBox(width: 4),
                    const Icon(Icons.arrow_forward_rounded, size: 14, color: ThixPolicy.primary),
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
// MAIN ACTIONS
// ============================================================================

class _MainActions extends StatelessWidget {
  const _MainActions({required this.onAction});
  final void Function(ThixQuickAction) onAction;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final items = [
      (ThixQuickAction.idea, l10n.t('ia_action_idea_short'), l10n.t('ia_action_idea_tag'), Icons.lightbulb_rounded),
      (ThixQuickAction.market, l10n.t('ia_action_market_short'), l10n.t('ia_action_market_tag'), Icons.bar_chart_rounded),
      (ThixQuickAction.businessPlan, l10n.t('ia_action_bp_short'), l10n.t('ia_action_bp_tag'), Icons.description_rounded),
      (ThixQuickAction.legal, l10n.t('ia_action_legal_short'), l10n.t('ia_action_legal_tag'), Icons.balance_rounded),
    ];

    return SizedBox(
      height: 130,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
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
              child: _SleekCard(
                width: 120,
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: ThixPolicy.primary.withValues(alpha: 0.1), shape: BoxShape.circle),
                      child: Icon(it.$4, color: ThixPolicy.primary, size: 20),
                    ),
                    const Spacer(),
                    Text(it.$2, style: const TextStyle(fontSize: 13, height: 1.2, fontWeight: FontWeight.w800, color: _IaLightPalette.textPrimary)),
                    const SizedBox(height: 4),
                    Text(it.$3, style: const TextStyle(fontSize: 10, color: _IaLightPalette.textSecondary, fontWeight: FontWeight.w600)),
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
// MOTORS ROW
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
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: motors.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final m = motors[i];
          return Semantics(
            button: true,
            label: m.$1,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: _IaLightPalette.surface,
                borderRadius: BorderRadius.circular(20), // Pilules très arrondies
                border: Border.all(color: _IaLightPalette.border),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4, offset: const Offset(0, 2))],
              ),
              child: Row(
                children: [
                  Icon(m.$2, color: ThixPolicy.primary, size: 16),
                  const SizedBox(width: 6),
                  Text(m.$1, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _IaLightPalette.textPrimary)),
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
  const _RecentAnalyses({required this.projectsAsync, required this.onOpen, required this.onCreate});
  final AsyncValue projectsAsync;
  final void Function(String) onOpen;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return projectsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(20),
        child: Center(child: SizedBox(width: 30, height: 30, child: CircularProgressIndicator(strokeWidth: 3, color: ThixPolicy.primary))),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: _SleekCard(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.error_outline_rounded, color: ThixPolicy.danger, size: 24),
              const SizedBox(width: 12),
              Expanded(child: Text(l10n.t('ia_home_error_generic', args: [_Sanitizer.errorMessage(e)]), style: const TextStyle(color: _IaLightPalette.textSecondary))),
            ],
          ),
        ),
      ),
      data: (projects) {
        final list = projects is List<ThixProject> ? projects : <ThixProject>[];
        if (list.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _SleekCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Icon(Icons.folder_open_rounded, size: 40, color: _IaLightPalette.textMuted),
                  const SizedBox(height: 12),
                  Text(l10n.t('ia_home_no_analyses'), style: const TextStyle(color: _IaLightPalette.textSecondary, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: onCreate,
                    style: ElevatedButton.styleFrom(backgroundColor: _IaLightPalette.textPrimary, foregroundColor: Colors.white, elevation: 0),
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
              final code = _Sanitizer.text(p.projectCode, maxLength: _kMaxCodeLength);
              final sector = _Sanitizer.text(p.sector, maxLength: _kMaxSectorLength);

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
                    child: _SleekCard(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(color: ThixPolicy.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                            child: const Icon(Icons.insert_chart_rounded, color: ThixPolicy.primary, size: 22),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _IaLightPalette.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
                                const SizedBox(height: 4),
                                Text('$code • $sector', style: const TextStyle(fontSize: 12, color: _IaLightPalette.textSecondary, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('$pct%', style: const TextStyle(color: ThixPolicy.success, fontWeight: FontWeight.w900, fontSize: 14)),
                              const SizedBox(height: 6),
                              SizedBox(
                                width: 48,
                                height: 4,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(2),
                                  child: LinearProgressIndicator(value: pct / 100, backgroundColor: _IaLightPalette.border, valueColor: const AlwaysStoppedAnimation(ThixPolicy.success)),
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
        final active = list.where((p) => p.isActive || p.status == 'draft').length;
        final analyses = list.fold<int>(0, (s, p) => s + p.analysesCount);
        final countries = list.map((p) => p.country).where((c) => c.trim().isNotEmpty).toSet();
        final avg = list.isEmpty ? 0 : (list.fold<double>(0, (s, p) => s + p.progress) / list.length * 100).round();

        final stats = [
          ('$analyses', l10n.t('ia_stat_analyses'), Icons.insights_rounded),
          ('$active', l10n.t('ia_stat_active'), Icons.track_changes_rounded),
          ('${countries.length}', l10n.t('ia_stat_countries'), Icons.public_rounded),
          ('$avg%', l10n.t('ia_stat_progress'), Icons.verified_rounded),
        ];

        return SizedBox(
          height: 80,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: stats.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, i) {
              final s = stats[i];
              return Semantics(
                label: '${s.$1} ${s.$2}',
                child: _SleekCard(
                  width: 140,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: _IaLightPalette.border.withValues(alpha: 0.5), shape: BoxShape.circle),
                        child: Icon(s.$3, color: _IaLightPalette.textPrimary, size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(s.$1, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: _IaLightPalette.textPrimary)),
                            Text(s.$2, style: const TextStyle(fontSize: 10, color: _IaLightPalette.textSecondary, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
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
          color: _IaLightPalette.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 5, decoration: BoxDecoration(color: _IaLightPalette.border, borderRadius: BorderRadius.circular(3))),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
              child: Row(
                children: [
                  Expanded(child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: _IaLightPalette.textPrimary))),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      context.push(ThixIARoutes.createProject);
                    },
                    style: TextButton.styleFrom(foregroundColor: ThixPolicy.primary),
                    child: Text(l10n.t('ia_home_new_project'), style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: _IaLightPalette.border),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(l10n.t('ia_home_pick_hint'), style: const TextStyle(color: _IaLightPalette.textSecondary, fontWeight: FontWeight.w600, fontSize: 13)),
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: controller,
                itemCount: projects.length,
                itemBuilder: (_, i) {
                  final p = projects[i];
                  final pct = (p.progress * 100).toInt();
                  final name = _Sanitizer.text(p.name, maxLength: _kMaxNameLength);
                  final code = _Sanitizer.text(p.projectCode, maxLength: _kMaxCodeLength);
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                    leading: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(color: _IaLightPalette.border.withValues(alpha: 0.5), shape: BoxShape.circle),
                      child: const Icon(Icons.folder_rounded, color: _IaLightPalette.textPrimary, size: 20),
                    ),
                    title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _IaLightPalette.textPrimary)),
                    subtitle: Text('$code • $pct%', style: const TextStyle(fontSize: 12, color: _IaLightPalette.textSecondary, fontWeight: FontWeight.w500)),
                    trailing: const Icon(Icons.chevron_right_rounded, color: _IaLightPalette.textMuted, size: 24),
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
