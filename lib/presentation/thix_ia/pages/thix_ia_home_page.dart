// lib/presentation/thix_ia/pages/thix_ia_home_page.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart'; // ✅ Localizations

import '../../../../core/theme/thix_design_policy.dart';
import '../core/constants/thix_ia_routes.dart';
import '../models/thix_project.dart';
import '../providers/thix_ia_provider.dart';
import '../providers/analysis_provider.dart';

enum ThixQuickAction { idea, market, businessPlan, legal }

// ✅ Provider optimisé avec gestion d'erreur explicite pour la production
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
    debugPrint('⚠️ Erreur chargement profil THIX IA: $e');
  }
  // Fallback sécurisé
  return {
    'id': user.id,
    'display_name': user.userMetadata?['display_name'] ?? user.email?.split('@').first ?? 'Utilisateur',
    'avatar_url': user.userMetadata?['avatar_url'],
  };
});

class ThixIaHomePage extends ConsumerStatefulWidget {
  const ThixIaHomePage({super.key});

  @override
  ConsumerState<ThixIaHomePage> createState() => _ThixIaHomePageState();
}

class _ThixIaHomePageState extends ConsumerState<ThixIaHomePage> {
  @override
  void initState() {
    super.initState();
    // ✅ Refresh sécurisé via microtask pour éviter les conflits de build
    Future.microtask(() {
      if (mounted) ref.read(projectsProvider.notifier).refresh();
    });
  }

  Future<void> _onQuickAction(ThixQuickAction action) async {
    final l10n = AppLocalizations.of(context)!;
    final projects = ref.read(projectsProvider).value ?? [];

    if (projects.isEmpty) {
      final go = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l10n.noProjectTitle),
          content: Text(l10n.noProjectDesc),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: ThixPolicy.primaryDeep),
              child: Text(l10n.createProject),
            ),
          ],
        ),
      );
      if (go == true && mounted) context.push(ThixIARoutes.createProject);
      return;
    }

    final selected = await showModalBottomSheet<ThixProject>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ProjectPickerSheet(projects: projects, title: _actionTitle(action, l10n)),
    );
    
    if (selected == null || !mounted) return;

    await ref.read(activeProjectProvider.notifier).setActive(selected.projectCode);

    try {
      showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator(color: ThixPolicy.primaryDeep)));

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

      if (mounted) Navigator.of(context).pop(); // Fermer le loader
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${l10n.analysisLaunched} ${selected.projectCode}'),
            backgroundColor: ThixPolicy.primaryDeep,
            behavior: SnackBarBehavior.floating,
          ),
        );
        context.push(ThixIARoutes.projectDetailPath(selected.projectCode));
      }
    } catch (e) {
      if (mounted) Navigator.of(context).pop();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.error}: $e'), backgroundColor: ThixPolicy.danger, behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  String _actionTitle(ThixQuickAction a, AppLocalizations l10n) {
    switch (a) {
      case ThixQuickAction.idea: return l10n.analyzeIdea;
      case ThixQuickAction.market: return l10n.studyMarket;
      case ThixQuickAction.businessPlan: return l10n.createBusinessPlan;
      case ThixQuickAction.legal: return l10n.checkRegulations;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final projectsAsync = ref.watch(projectsProvider);
    final profileAsync = ref.watch(thixIaCurrentProfileProvider);

    return Scaffold(
      backgroundColor: ThixPolicy.surfaceSoft,
      // ✅ BARRE DU BAS SUPPRIMÉE CONFORMÉMENT À LA DEMANDE
      body: Stack(
        children: [
          // ✅ Orbes de fond optimisés avec ClipRRect pour éviter les fuites de rendu
          Positioned(top: -60, right: -40, child: _halo(160, ThixPolicy.primary.withOpacity(0.08))),
          Positioned(top: 160, left: -70, child: _halo(180, ThixPolicy.primaryDeep.withOpacity(0.06))),
          
          SafeArea(
            bottom: false,
            child: RefreshIndicator(
              color: ThixPolicy.primaryDeep,
              onRefresh: () async {
                ref.invalidate(thixIaCurrentProfileProvider);
                await ref.read(projectsProvider.notifier).refresh();
              },
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                slivers: [
                  SliverToBoxAdapter(child: _TopBar(profileAsync: profileAsync, l10n: l10n)),
                  SliverToBoxAdapter(child: _UserHeader(profileAsync: profileAsync, l10n: l10n)),
                  const SliverToBoxAdapter(child: SizedBox(height: 10)),
                  SliverToBoxAdapter(child: _HeroBanner(onAnalyze: () => context.push(ThixIARoutes.createProject), l10n: l10n)),
                  const SliverToBoxAdapter(child: SizedBox(height: 18)),
                  SliverToBoxAdapter(child: _SectionTitle(l10n.quickActionsTitle, l10n: l10n)),
                  const SliverToBoxAdapter(child: SizedBox(height: 8)),
                  SliverToBoxAdapter(child: _MainActions(onAction: _onQuickAction, l10n: l10n)),
                  const SliverToBoxAdapter(child: SizedBox(height: 18)),
                  SliverToBoxAdapter(
                    child: _SectionTitle(
                      l10n.thixMotorsTitle,
                      seeAll: true,
                      onSeeAll: () => context.push(ThixIARoutes.projects),
                      l10n: l10n,
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 8)),
                  const SliverToBoxAdapter(child: _MotorsRow()),
                  const SliverToBoxAdapter(child: SizedBox(height: 18)),
                  SliverToBoxAdapter(
                    child: _SectionTitle(
                      l10n.recentAnalysesTitle,
                      seeAll: true,
                      onSeeAll: () => context.push(ThixIARoutes.projects),
                      l10n: l10n,
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 8)),
                  SliverToBoxAdapter(
                    child: _RecentAnalyses(
                      projectsAsync: projectsAsync,
                      onOpen: (c) => context.push(ThixIARoutes.projectDetailPath(c)),
                      onCreate: () => context.push(ThixIARoutes.createProject),
                      l10n: l10n,
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 18)),
                  SliverToBoxAdapter(child: _SectionTitle(l10n.quickOverviewTitle, l10n: l10n)),
                  const SliverToBoxAdapter(child: SizedBox(height: 8)),
                  SliverToBoxAdapter(child: _QuickStats(projectsAsync: projectsAsync, l10n: l10n)),
                  // ✅ Espacement dynamique pour compenser la suppression de la bottom nav
                  SliverToBoxAdapter(child: SizedBox(height: MediaQuery.paddingOf(context).bottom + 24)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ✅ Halo sécurisé avec ClipRRect
  Widget _halo(double s, Color c) => ClipRRect(
    borderRadius: BorderRadius.circular(s / 2),
    child: Container(width: s, height: s, decoration: BoxDecoration(shape: BoxShape.circle, color: c)),
  );
}

// ─── TOP BAR ───────────────────────────────────────────────────────────────
class _TopBar extends StatelessWidget {
  const _TopBar({required this.profileAsync, required this.l10n});
  final AsyncValue<Map<String, dynamic>?> profileAsync;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final p = profileAsync.valueOrNull;
    final city = (p?['city'] as String?)?.trim();
    final country = (p?['country'] as String?)?.trim();
    final loc = [if (city != null && city.isNotEmpty) city, if (country != null && country.isNotEmpty) country].join(', ');

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 2),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                const Icon(Icons.location_on_rounded, size: 14, color: ThixPolicy.textMain),
                const SizedBox(width: 2),
                Flexible(
                  child: Text(loc.isNotEmpty ? loc : '—', style: ThixPolicy.labelStyle.copyWith(fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
          ),
          Column(
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.auto_awesome, size: 14, color: ThixPolicy.primaryDeep),
                  const SizedBox(width: 3),
                  Text('THIX IA', style: ThixPolicy.h3Style.copyWith(fontSize: 15, fontWeight: FontWeight.w800, color: ThixPolicy.primaryDeep)),
                ],
              ),
              Text(l10n.businessIntelligenceAfrica, style: ThixPolicy.microStyle.copyWith(fontSize: 8, color: ThixPolicy.textMuted)),
            ],
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _glass(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.language_rounded, size: 12, color: ThixPolicy.textMain),
                      const SizedBox(width: 3),
                      Text('FR', style: ThixPolicy.labelStyle.copyWith(fontSize: 11)),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.notifications_none_rounded, size: 20, color: ThixPolicy.textMain),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── USER HEADER ───────────────────────────────────────────────────────────
class _UserHeader extends StatelessWidget {
  const _UserHeader({required this.profileAsync, required this.l10n});
  final AsyncValue<Map<String, dynamic>?> profileAsync;
  final AppLocalizations l10n;

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
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        child: Row(children: [
          CircleAvatar(radius: 22, backgroundColor: ThixPolicy.surfaceStrong),
          SizedBox(width: 10),
          SizedBox(width: 100, height: 14, child: ColoredBox(color: ThixPolicy.surfaceStrong)),
        ]),
      ),
      error: (_, __) => _body(l10n.defaultPartnerName, null, null, l10n),
      data: (p) => _body(
        _pick(p, ['display_name', 'full_name']) ?? l10n.defaultPartnerName,
        _pick(p, ['avatar_url', 'photo_url']),
        _pick(p, ['role_title', 'occupation', 'profession']),
        l10n,
      ),
    );
  }

  Widget _body(String name, String? photo, String? role, AppLocalizations l10n) {
    final h = DateTime.now().hour;
    final greet = h < 12 ? l10n.goodMorning : h < 18 ? l10n.goodAfternoon : l10n.goodEvening;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
      child: Row(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: ThixPolicy.primaryDeep.withOpacity(0.12),
                backgroundImage: (photo != null && photo.isNotEmpty) ? NetworkImage(photo) : null,
                child: (photo == null || photo.isEmpty) ? Text(name[0].toUpperCase(), style: ThixPolicy.h3Style.copyWith(color: ThixPolicy.primaryDeep)) : null,
              ),
              Positioned(
                bottom: 0, right: 0,
                child: Container(
                  width: 12, height: 12,
                  decoration: BoxDecoration(color: ThixPolicy.success, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 1.5)),
                ),
              ),
            ],
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$greet,', style: ThixPolicy.microStyle),
                Text(name, style: ThixPolicy.h3Style.copyWith(fontWeight: FontWeight.w800, fontSize: 16), maxLines: 1, overflow: TextOverflow.ellipsis),
                if (role != null)
                  Container(
                    margin: const EdgeInsets.only(top: 3),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: ThixPolicy.primaryDeep.withOpacity(0.08), // ✅ Remplacement du Gold par primaryDeep pour respecter la règle 2 couleurs
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(role, style: ThixPolicy.microStyle.copyWith(color: ThixPolicy.primaryDeep, fontWeight: FontWeight.w700, fontSize: 10), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── HERO BANNER ───────────────────────────────────────────────────────────
class _HeroBanner extends StatelessWidget {
  const _HeroBanner({required this.onAnalyze, required this.l10n});
  final VoidCallback onAnalyze;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(ThixPolicy.rLg),
        child: Container(
          height: 148,
          decoration: const BoxDecoration(
            // ✅ Gradient strictement monochromatique THIX (Deep -> Primary)
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [ThixPolicy.primaryDeep, Color(0xFF1A4A9C)],
            ),
          ),
          child: Stack(
            children: [
              Positioned(right: -10, top: 8, bottom: 8, width: 120, child: CustomPaint(painter: _DotsPainter())),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.transformIdeas, style: ThixPolicy.h2Style.copyWith(color: Colors.white, height: 1.15, fontSize: 18, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 6),
                    Text(l10n.thixAnalyzes, style: ThixPolicy.microStyle.copyWith(color: Colors.white.withOpacity(0.85), fontSize: 11)),
                    const Spacer(),
                    Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(ThixPolicy.rFull),
                      child: InkWell(
                        onTap: onAnalyze,
                        borderRadius: BorderRadius.circular(ThixPolicy.rFull),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.auto_awesome_rounded, size: 14, color: ThixPolicy.primaryDeep),
                              const SizedBox(width: 6),
                              Text(l10n.analyzeIdea, style: ThixPolicy.labelStyle.copyWith(color: ThixPolicy.primaryDeep, fontWeight: FontWeight.w700, fontSize: 12)),
                            ],
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
    final dot = Paint()..color = Colors.white.withOpacity(0.22);
    final line = Paint()..color = Colors.white.withOpacity(0.10)..strokeWidth = 1;
    final pts = [
      Offset(size.width * 0.3, size.height * 0.2),
      Offset(size.width * 0.55, size.height * 0.28),
      Offset(size.width * 0.4, size.height * 0.5),
      Offset(size.width * 0.7, size.height * 0.45),
      Offset(size.width * 0.5, size.height * 0.72),
      Offset(size.width * 0.75, size.height * 0.68),
    ];
    for (var i = 0; i < pts.length - 1; i++) canvas.drawLine(pts[i], pts[i + 1], line);
    for (final p in pts) canvas.drawCircle(p, 2.8, dot);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─── SECTION TITLE ─────────────────────────────────────────────────────────
class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title, {this.seeAll = false, this.onSeeAll, required this.l10n});
  final String title;
  final bool seeAll;
  final VoidCallback? onSeeAll;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          Expanded(child: Text(title, style: ThixPolicy.h3Style.copyWith(fontSize: 14, fontWeight: FontWeight.w800))),
          if (seeAll)
            GestureDetector(
              onTap: onSeeAll,
              child: Row(
                children: [
                  Text(l10n.seeAll, style: ThixPolicy.microStyle.copyWith(color: ThixPolicy.primaryDeep, fontWeight: FontWeight.w600)),
                  const Icon(Icons.arrow_forward_rounded, size: 12, color: ThixPolicy.primaryDeep),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ─── MAIN ACTIONS ──────────────────────────────────────────────────────────
class _MainActions extends StatelessWidget {
  const _MainActions({required this.onAction, required this.l10n});
  final void Function(ThixQuickAction) onAction;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    // ✅ Couleurs unifiées en primaryDeep/primary pour respecter la règle "2 couleurs"
    final items = [
      (ThixQuickAction.idea, l10n.analyzeIdeaShort, l10n.feasibility, Icons.lightbulb_rounded, ThixPolicy.primaryDeep),
      (ThixQuickAction.market, l10n.studyMarketShort, l10n.trends, Icons.bar_chart_rounded, ThixPolicy.primary),
      (ThixQuickAction.businessPlan, l10n.businessPlanShort, l10n.strategy, Icons.description_rounded, ThixPolicy.primaryDeep),
      (ThixQuickAction.legal, l10n.checkRulesShort, l10n.licenses, Icons.balance_rounded, ThixPolicy.primary),
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
          return GestureDetector(
            onTap: () => onAction(it.$1),
            child: _glass(
              width: 112,
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(color: it.$5.withOpacity(0.12), shape: BoxShape.circle),
                    child: Icon(it.$4, color: it.$5, size: 16),
                  ),
                  const Spacer(),
                  Text(it.$2, style: ThixPolicy.labelStyle.copyWith(fontSize: 11, height: 1.15, fontWeight: FontWeight.w700)),
                  Text(it.$3, style: ThixPolicy.microStyle.copyWith(fontSize: 9, color: ThixPolicy.textSecondary)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─── MOTORS ROW ────────────────────────────────────────────────────────────
class _MotorsRow extends StatelessWidget {
  const _MotorsRow();

  @override
  Widget build(BuildContext context) {
    // ✅ Couleurs strictement limitées à primary / primaryDeep
    final motors = [
      ('Research', Icons.search_rounded, ThixPolicy.primaryDeep),
      ('Market', Icons.trending_up_rounded, ThixPolicy.primary),
      ('Business', Icons.work_rounded, ThixPolicy.primaryDeep),
      ('Finance', Icons.attach_money_rounded, ThixPolicy.primary),
      ('Legal', Icons.balance_rounded, ThixPolicy.primaryDeep),
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
          return Column(
            children: [
              _glass(
                padding: const EdgeInsets.all(10),
                child: Icon(m.$2, color: m.$3, size: 18),
              ),
              const SizedBox(height: 4),
              Text(m.$1, style: ThixPolicy.microStyle.copyWith(fontSize: 10, fontWeight: FontWeight.w700)),
            ],
          );
        },
      ),
    );
  }
}

// ─── RECENT ANALYSES ───────────────────────────────────────────────────────
class _RecentAnalyses extends StatelessWidget {
  const _RecentAnalyses({required this.projectsAsync, required this.onOpen, required this.onCreate, required this.l10n});
  final AsyncValue projectsAsync;
  final void Function(String) onOpen;
  final VoidCallback onCreate;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return projectsAsync.when(
      loading: () => const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator(color: ThixPolicy.primaryDeep))),
      error: (e, _) => Padding(padding: const EdgeInsets.symmetric(horizontal: 14), child: Text('${l10n.error}: $e')),
      data: (projects) {
        final list = projects is List<ThixProject> ? projects : <ThixProject>[];
        if (list.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: _glass(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  Text(l10n.noAnalysis, style: ThixPolicy.bodySmallStyle.copyWith(color: ThixPolicy.textSecondary)),
                  TextButton(onPressed: onCreate, child: Text(l10n.createProject)),
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
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: GestureDetector(
                  onTap: () => onOpen(p.projectCode),
                  child: _glass(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    child: Row(
                      children: [
                        Container(
                          width: 34, height: 34,
                          decoration: BoxDecoration(color: ThixPolicy.primaryDeep.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                          child: const Icon(Icons.insert_chart_rounded, color: ThixPolicy.primaryDeep, size: 16),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(p.name, style: ThixPolicy.labelStyle.copyWith(fontSize: 12, fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
                              Text('${p.projectCode} • ${p.sector}', style: ThixPolicy.microStyle.copyWith(fontSize: 10), maxLines: 1, overflow: TextOverflow.ellipsis),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('$pct%', style: ThixPolicy.microStyle.copyWith(color: ThixPolicy.primaryDeep, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 3),
                            SizedBox(
                              width: 40, height: 3,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(2),
                                child: LinearProgressIndicator(
                                  value: pct / 100,
                                  backgroundColor: ThixPolicy.surfaceStrong,
                                  valueColor: const AlwaysStoppedAnimation(ThixPolicy.primaryDeep),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
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

// ─── QUICK STATS ───────────────────────────────────────────────────────────
class _QuickStats extends StatelessWidget {
  const _QuickStats({required this.projectsAsync, required this.l10n});
  final AsyncValue projectsAsync;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return projectsAsync.when(
      loading: () => const SizedBox(height: 70, child: Center(child: CircularProgressIndicator(color: ThixPolicy.primaryDeep))),
      error: (_, __) => const SizedBox.shrink(),
      data: (projects) {
        final list = projects is List<ThixProject> ? projects : <ThixProject>[];
        final total = list.length;
        final active = list.where((p) => p.isActive || p.status == 'draft').length;
        final analyses = list.fold<int>(0, (s, p) => s + p.analysesCount);
        final countries = list.map((p) => p.country).where((c) => c.trim().isNotEmpty).toSet();
        final avg = list.isEmpty ? 0 : (list.fold<double>(0, (s, p) => s + p.progress) / list.length * 100).round();

        // ✅ Couleurs unifiées
        final stats = [
          ('$analyses', l10n.statAnalyses, Icons.insights_rounded, ThixPolicy.primaryDeep),
          ('$active', l10n.statOngoing, Icons.track_changes_rounded, ThixPolicy.primary),
          ('${countries.length}', l10n.statCountries, Icons.public_rounded, ThixPolicy.primaryDeep),
          ('$avg%', l10n.statProgress, Icons.verified_rounded, ThixPolicy.primary),
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
              return _glass(
                width: 120,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(color: s.$4.withOpacity(0.12), shape: BoxShape.circle),
                      child: Icon(s.$3, color: s.$4, size: 16),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(s.$1, style: ThixPolicy.h3Style.copyWith(fontSize: 15, fontWeight: FontWeight.w800)),
                          Text(s.$2, style: ThixPolicy.microStyle.copyWith(fontSize: 9, color: s.$4), maxLines: 1, overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}

// ─── PROJECT PICKER SHEET ──────────────────────────────────────────────────
class _ProjectPickerSheet extends StatelessWidget {
  const _ProjectPickerSheet({required this.projects, required this.title});
  final List<ThixProject> projects;
  final String title;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.35,
      maxChildSize: 0.85,
      builder: (_, controller) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.85), // ✅ Glassmorphism pur
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              border: Border(top: BorderSide(color: Colors.white.withOpacity(0.9), width: 1.5)),
            ),
            child: Column(
              children: [
                const SizedBox(height: 8),
                Container(width: 36, height: 4, decoration: BoxDecoration(color: ThixPolicy.textMuted.withOpacity(0.3), borderRadius: BorderRadius.circular(2))),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 8, 8),
                  child: Row(
                    children: [
                      Expanded(child: Text(title, style: ThixPolicy.h3Style.copyWith(fontSize: 15, fontWeight: FontWeight.w800))),
                      TextButton(
                        onPressed: () { Navigator.pop(context); context.push(ThixIARoutes.createProject); },
                        child: Text('+ ${l10n.newProject}', style: const TextStyle(color: ThixPolicy.primaryDeep, fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: ThixPolicy.border),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
                  child: Align(alignment: Alignment.centerLeft, child: Text(l10n.chooseOngoingProject, style: ThixPolicy.microStyle.copyWith(color: ThixPolicy.textSecondary))),
                ),
                Expanded(
                  child: ListView.builder(
                    controller: controller,
                    itemCount: projects.length,
                    itemBuilder: (_, i) {
                      final p = projects[i];
                      final pct = (p.progress * 100).toInt();
                      return ListTile(
                        dense: true,
                        leading: CircleAvatar(
                          radius: 18,
                          backgroundColor: ThixPolicy.primaryDeep.withOpacity(0.12),
                          child: const Icon(Icons.folder_rounded, color: ThixPolicy.primaryDeep, size: 16),
                        ),
                        title: Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        subtitle: Text('${p.projectCode} • $pct%', style: const TextStyle(fontSize: 11)),
                        trailing: const Icon(Icons.play_arrow_rounded, color: ThixPolicy.primaryDeep, size: 22),
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

// ─── GLASS HELPER (Strict 2-Color Policy: White + PrimaryDeep) ─────────────
Widget _glass({double? width, required EdgeInsets padding, required Widget child}) {
  return ClipRRect(
    borderRadius: BorderRadius.circular(ThixPolicy.rMd),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
      child: Container(
        width: width,
        padding: padding,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.65),
          borderRadius: BorderRadius.circular(ThixPolicy.rMd),
          border: Border.all(color: Colors.white.withOpacity(0.85)),
          boxShadow: [BoxShadow(color: ThixPolicy.primaryDeep.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: child,
      ),
    ),
  );
}
