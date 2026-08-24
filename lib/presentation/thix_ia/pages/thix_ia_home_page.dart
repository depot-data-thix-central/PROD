// lib/presentation/thix_ia/pages/thix_ia_home_page.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/thix_design_policy.dart';
import '../providers/thix_ia_provider.dart';
import '../core/constants/thix_ia_routes.dart';

class ThixIaHomePage extends ConsumerStatefulWidget {
  const ThixIaHomePage({super.key});
  @override
  ConsumerState<ThixIaHomePage> createState() => _ThixIaHomePageState();
}

class _ThixIaHomePageState extends ConsumerState<ThixIaHomePage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(projectsProvider.notifier).refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final projectsAsync = ref.watch(projectsProvider);

    return Scaffold(
      backgroundColor: ThixPolicy.surfaceSoft,
      body: Stack(
        children: [
          // Effets de lumière en fond pour le côté "Glassflou"
          Positioned(
            top: -50,
            right: -50,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: ThixPolicy.primary.withOpacity(0.15),
              ),
            ),
          ),
          Positioned(
            top: 200,
            left: -100,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: ThixPolicy.domainMedia.withOpacity(0.08),
              ),
            ),
          ),
          // Contenu principal avec flou
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
            child: SafeArea(
              child: RefreshIndicator(
                color: ThixPolicy.primary,
                onRefresh: () => ref.read(projectsProvider.notifier).refresh(),
                child: ListView(
                  padding: const EdgeInsets.only(bottom: 100),
                  children: [
                    _buildTopBar(),
                    const SizedBox(height: ThixPolicy.s16),
                    _buildUserHeader(),
                    const SizedBox(height: ThixPolicy.s20),
                    _buildHeroBanner(context),
                    const SizedBox(height: ThixPolicy.s24),
                    _buildSectionTitle('Que souhaitez-vous faire aujourd\'hui ?'),
                    const SizedBox(height: ThixPolicy.s12),
                    _buildMainActions(context),
                    const SizedBox(height: ThixPolicy.s24),
                    _buildSectionTitle('Les Moteurs THIX IA', hasSeeAll: true),
                    const SizedBox(height: ThixPolicy.s12),
                    _buildMotors(),
                    const SizedBox(height: ThixPolicy.s24),
                    _buildSectionTitle('Mes dernières analyses', hasSeeAll: true, onSeeAll: () => context.push(ThixIARoutes.projects)),
                    const SizedBox(height: ThixPolicy.s12),
                    _buildRecentProjects(projectsAsync, context),
                    const SizedBox(height: ThixPolicy.s24),
                    _buildSectionTitle('Aperçu rapide'),
                    const SizedBox(height: ThixPolicy.s12),
                    _buildQuickStats(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s20, vertical: ThixPolicy.s8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.location_on_rounded, size: 16, color: ThixPolicy.textMain),
              const SizedBox(width: 4),
              Text('Kinshasa, RDC', style: ThixPolicy.labelStyle),
              const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: ThixPolicy.textSecondary),
            ],
          ),
          Row(
            children: [
              Text('THIX IA', style: ThixPolicy.h3Style.copyWith(color: ThixPolicy.primaryDeep, fontWeight: ThixPolicy.bold, letterSpacing: -0.5)),
            ],
          ),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  border: Border.all(color: ThixPolicy.border),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.language_rounded, size: 14, color: ThixPolicy.textMain),
                    const SizedBox(width: 4),
                    Text('FR', style: ThixPolicy.labelStyle.copyWith(fontSize: 12)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              const Icon(Icons.notifications_none_rounded, color: ThixPolicy.textMain),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUserHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s20),
      child: Row(
        children: [
          Stack(
            children: [
              const CircleAvatar(
                radius: 28,
                backgroundImage: NetworkImage('https://i.pravatar.cc/150?img=11'), // Placeholder image
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(color: ThixPolicy.success, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
                  child: const Icon(Icons.check, size: 10, color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Bonjour, Ambassador', style: ThixPolicy.bodySmallStyle),
              Text('Nathan Lumina', style: ThixPolicy.h2Style),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: ThixPolicy.gold.withOpacity(0.15), borderRadius: BorderRadius.circular(ThixPolicy.rXs)),
                child: Row(
                  children: [
                    const Icon(Icons.workspace_premium_rounded, size: 12, color: ThixPolicy.premiumAccent),
                    const SizedBox(width: 4),
                    Text('Entrepreneur Visionnaire', style: ThixPolicy.microStyle.copyWith(color: ThixPolicy.premiumAccent, fontWeight: ThixPolicy.bold)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeroBanner(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s20),
      child: Container(
        padding: const EdgeInsets.all(ThixPolicy.s24),
        decoration: BoxDecoration(
          gradient: ThixPolicy.heroGradient,
          borderRadius: BorderRadius.circular(ThixPolicy.rLg),
          boxShadow: ThixPolicy.shadowCard(opacity: 0.2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Transformez\nvos idées en succès.', style: ThixPolicy.h1Style.copyWith(color: Colors.white, height: 1.2)),
            const SizedBox(height: ThixPolicy.s12),
            Text('THIX IA analyse, construit et sécurise\nvos projets pour des décisions\néclairées en Afrique.', style: ThixPolicy.bodySmallStyle.copyWith(color: Colors.white.withOpacity(0.85))),
            const SizedBox(height: ThixPolicy.s24),
            ElevatedButton.icon(
              onPressed: () => context.push(ThixIARoutes.createProject),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: ThixPolicy.primaryDeep,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rMd)),
                padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s20, vertical: 14),
              ),
              icon: const Icon(Icons.auto_awesome_rounded, size: 18),
              label: Text('Analyser mon idée', style: ThixPolicy.labelStyle.copyWith(color: ThixPolicy.primaryDeep)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, {bool hasSeeAll = false, VoidCallback? onSeeAll}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: ThixPolicy.h3Style),
          if (hasSeeAll)
            GestureDetector(
              onTap: onSeeAll,
              child: Row(
                children: [
                  Text('Voir tous', style: ThixPolicy.bodySmallStyle.copyWith(color: ThixPolicy.primary, fontWeight: ThixPolicy.semiBold)),
                  const Icon(Icons.arrow_forward_rounded, size: 14, color: ThixPolicy.primary),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMainActions(BuildContext context) {
    final actions = [
      {'title': 'Analyser\nmon idée', 'subtitle': 'Étude complète\nde faisabilité', 'icon': Icons.lightbulb_rounded, 'color': ThixPolicy.primary},
      {'title': 'Étudier\nun marché', 'subtitle': 'Données, tendances\net opportunités', 'icon': Icons.bar_chart_rounded, 'color': ThixPolicy.domainJobs},
      {'title': 'Créer un\nBusiness Plan', 'subtitle': 'Plan stratégique\ncomplet', 'icon': Icons.description_rounded, 'color': ThixPolicy.domainNetwork},
      {'title': 'Vérifier\nréglementation', 'subtitle': 'Lois, licences,\nautorisations', 'icon': Icons.balance_rounded, 'color': ThixPolicy.domainOpportunity},
    ];

    return SizedBox(
      height: 170,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s20),
        scrollDirection: Axis.horizontal,
        itemCount: actions.length,
        separatorBuilder: (_, __) => const SizedBox(width: ThixPolicy.s12),
        itemBuilder: (context, index) {
          final action = actions[index];
          return Container(
            width: 140,
            padding: const EdgeInsets.all(ThixPolicy.s16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.9), // Glassflou effect
              borderRadius: BorderRadius.circular(ThixPolicy.rLg),
              border: Border.all(color: Colors.white, width: 1.5),
              boxShadow: ThixPolicy.shadowSoft(),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: (action['color'] as Color).withOpacity(0.15), shape: BoxShape.circle),
                  child: Icon(action['icon'] as IconData, color: action['color'] as Color, size: 24),
                ),
                const Spacer(),
                Text(action['title'] as String, style: ThixPolicy.labelStyle.copyWith(height: 1.2)),
                const SizedBox(height: 4),
                Text(action['subtitle'] as String, style: ThixPolicy.microStyle.copyWith(height: 1.1)),
                const SizedBox(height: 8),
                Align(alignment: Alignment.centerRight, child: Icon(Icons.arrow_forward_rounded, size: 16, color: ThixPolicy.textMuted)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildMotors() {
    final motors = [
      {'title': 'Research', 'sub': 'Données & Sources', 'icon': Icons.search_rounded, 'color': ThixPolicy.primary},
      {'title': 'Market', 'sub': 'Intelligence Marché', 'icon': Icons.trending_up_rounded, 'color': ThixPolicy.domainJobs},
      {'title': 'Business', 'sub': 'Stratégie & Plan', 'icon': Icons.work_rounded, 'color': ThixPolicy.domainNetwork},
      {'title': 'Finance', 'sub': 'Modélisation', 'icon': Icons.monetization_on_rounded, 'color': ThixPolicy.domainOpportunity},
      {'title': 'Legal', 'sub': 'Droit & Règle', 'icon': Icons.balance_rounded, 'color': ThixPolicy.danger},
    ];

    return SizedBox(
      height: 100,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s20),
        scrollDirection: Axis.horizontal,
        itemCount: motors.length,
        separatorBuilder: (_, __) => const SizedBox(width: ThixPolicy.s12),
        itemBuilder: (context, index) {
          final m = motors[index];
          return Column(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(ThixPolicy.rMd), boxShadow: ThixPolicy.shadowSoft()),
                child: Icon(m['icon'] as IconData, color: m['color'] as Color, size: 24),
              ),
              const SizedBox(height: 8),
              Text(m['title'] as String, style: ThixPolicy.labelStyle.copyWith(fontSize: 12)),
              Text(m['sub'] as String, style: ThixPolicy.microStyle.copyWith(fontSize: 9)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildRecentProjects(AsyncValue projectsAsync, BuildContext context) {
    return projectsAsync.when(
      loading: () => const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(color: ThixPolicy.primary))),
      error: (e, _) => Center(child: Text('Erreur : $e')),
      data: (projects) {
        if (projects.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s20),
            child: Container(
              padding: const EdgeInsets.all(ThixPolicy.s20),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(ThixPolicy.rLg), border: Border.all(color: ThixPolicy.border)),
              child: const Center(child: Text('Aucun projet récent.', style: TextStyle(color: ThixPolicy.textSecondary))),
            ),
          );
        }

        final recent = projects.take(3).toList();
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s20),
          child: Column(
            children: recent.map<Widget>((p) {
              return GestureDetector(
                // ✅ LA SOLUTION DU 404 EST ICI : on utilise la fonction constante qui inclut "/projects/"
                onTap: () => context.push(ThixIARoutes.projectDetailPath(p.projectCode)),
                child: Container(
                  margin: const EdgeInsets.only(bottom: ThixPolicy.s12),
                  padding: const EdgeInsets.all(ThixPolicy.s16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(ThixPolicy.rLg),
                    boxShadow: ThixPolicy.shadowSoft(),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: ThixPolicy.primary.withOpacity(0.1), shape: BoxShape.circle),
                        child: const Icon(Icons.insert_chart_rounded, color: ThixPolicy.primary, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(p.name, style: ThixPolicy.labelStyle, maxLines: 1, overflow: TextOverflow.ellipsis),
                            Text(p.sector ?? 'Analyse en cours', style: ThixPolicy.microStyle),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('${p.progress ?? 0}%', style: ThixPolicy.labelStyle.copyWith(color: ThixPolicy.success)),
                          Container(
                            margin: const EdgeInsets.only(top: 4),
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(color: ThixPolicy.border, borderRadius: BorderRadius.circular(2)),
                            child: FractionallySizedBox(
                              alignment: Alignment.centerLeft,
                              widthFactor: (p.progress ?? 0) / 100,
                              child: Container(decoration: BoxDecoration(color: ThixPolicy.success, borderRadius: BorderRadius.circular(2))),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 12),
                      const Icon(Icons.more_vert_rounded, color: ThixPolicy.textMuted),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Widget _buildQuickStats() {
    final stats = [
      {'val': '12', 'title': 'Analyses réalisées', 'sub': '+2 cette semaine', 'icon': Icons.insights_rounded, 'color': ThixPolicy.domainMedia},
      {'val': '8', 'title': 'Projets en cours', 'sub': '+3 cette semaine', 'icon': Icons.track_changes_rounded, 'color': ThixPolicy.domainJobs},
      {'val': '5', 'title': 'Pays analysés', 'sub': 'RDC, KE, TZ, RW, GH', 'icon': Icons.language_rounded, 'color': ThixPolicy.domainOpportunity},
    ];

    return SizedBox(
      height: 90,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s20),
        scrollDirection: Axis.horizontal,
        itemCount: stats.length,
        separatorBuilder: (_, __) => const SizedBox(width: ThixPolicy.s12),
        itemBuilder: (context, index) {
          final s = stats[index];
          return Container(
            width: 220,
            padding: const EdgeInsets.all(ThixPolicy.s12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.9), // Glassflou touch
              borderRadius: BorderRadius.circular(ThixPolicy.rLg),
              border: Border.all(color: Colors.white),
              boxShadow: ThixPolicy.shadowSoft(),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: (s['color'] as Color).withOpacity(0.15), shape: BoxShape.circle),
                  child: Icon(s['icon'] as IconData, color: s['color'] as Color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(s['val'] as String, style: ThixPolicy.h2Style),
                          const SizedBox(width: 4),
                          Expanded(child: Text(s['title'] as String, style: ThixPolicy.microStyle.copyWith(color: ThixPolicy.textMain, fontWeight: ThixPolicy.bold), maxLines: 1, overflow: TextOverflow.ellipsis)),
                        ],
                      ),
                      Text(s['sub'] as String, style: ThixPolicy.microStyle.copyWith(color: s['color'] as Color)),
                    ],
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
