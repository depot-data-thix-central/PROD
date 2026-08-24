// lib/presentation/thix_ia/pages/thix_ia_home_page.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/thix_design_policy.dart';
import '../providers/thix_ia_provider.dart';
import '../providers/active_project_provider.dart';
import '../providers/analysis_provider.dart';

// Tes vrais widgets connectés à Supabase
import '../widgets/active_project_selector.dart';
import '../widgets/project_card.dart';
import '../widgets/empty_state_widget.dart';
import '../widgets/analysis_progress_widget.dart';
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
    // Écoute de Supabase en temps réel
    final projectsAsync = ref.watch(projectsProvider);
    final activeProject = ref.watch(activeProjectProvider).value;
    final analysesAsync = ref.watch(analysesProvider);
    final intelligenceAsync = ref.watch(projectIntelligenceProvider);

    return Scaffold(
      backgroundColor: ThixPolicy.surfaceSoft,
      // Ton vrai bouton d'action
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(ThixIARoutes.createProject),
        backgroundColor: ThixPolicy.primary,
        icon: const Icon(Icons.auto_awesome_rounded, color: Colors.white),
        label: Text('Nouvelle idée', style: ThixPolicy.bodyStyle.copyWith(color: Colors.white, fontWeight: ThixPolicy.semiBold)),
      ),
      body: Stack(
        children: [
          // Effets de lumière en fond (Le seul ajout design)
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
            top: 300,
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
          
          // Filtre de flou pour englober tout le contenu
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
            child: SafeArea(
              child: RefreshIndicator(
                color: ThixPolicy.primary,
                onRefresh: () async {
                  await ref.read(projectsProvider.notifier).refresh();
                  // S'il existe une méthode refresh pour intelligenceProvider dans ton provider
                  // await ref.read(projectIntelligenceProvider.notifier).refresh();
                },
                child: CustomScrollView(
                  slivers: [
                    SliverAppBar(
                      backgroundColor: Colors.transparent,
                      elevation: 0,
                      title: Text('THIX IA', style: ThixPolicy.h2Style),
                      actions: [
                        IconButton(
                          onPressed: () => context.push(ThixIARoutes.createProject), 
                          icon: const Icon(Icons.add_rounded, color: ThixPolicy.primary)
                        ),
                      ],
                    ),
                    
                    // La bannière design (Statique)
                    SliverToBoxAdapter(
                      child: _buildHeroBanner(context),
                    ),

                    // Ton vrai composant de sélection de projet actif
                    const SliverToBoxAdapter(child: SizedBox(height: ThixPolicy.s16)),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s16),
                        child: ActiveProjectSelector(onTap: () => context.push(ThixIARoutes.projects)),
                      ),
                    ),

                    // Tes VRAIES prochaines étapes générées par Supabase
                    if (intelligenceAsync.value != null && intelligenceAsync.value!.nextActions.isNotEmpty)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s16, vertical: ThixPolicy.s12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Prochaines étapes', style: ThixPolicy.labelStyle),
                              const SizedBox(height: ThixPolicy.s8),
                              Wrap(
                                spacing: 8,
                                children: intelligenceAsync.value!.nextActions.map((a) => Chip(
                                  label: Text(a, style: ThixPolicy.captionStyle), 
                                  backgroundColor: ThixPolicy.primary.withOpacity(0.08)
                                )).toList(),
                              ),
                            ],
                          ),
                        ),
                      ),

                    // Tes VRAIES analyses en cours
                    if (analysesAsync.value != null && analysesAsync.value!.any((a) => a.isRunning))
                      SliverList(
                        delegate: SliverChildBuilderDelegate((_, i) {
                          final running = analysesAsync.value!.where((a) => a.isRunning).toList()[i];
                          return AnalysisProgressWidget(analysis: running);
                        }, childCount: analysesAsync.value!.where((a) => a.isRunning).length),
                      ),

                    // Actions rapides liées au projet ACTIF
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s16, vertical: ThixPolicy.s12),
                        child: Text('Actions rapides', style: ThixPolicy.h3Style),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: _buildMainActions(context, activeProject?.projectCode),
                    ),

                    // Tes VRAIS projets récents sortis de Supabase
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(ThixPolicy.s16, ThixPolicy.s24, ThixPolicy.s16, ThixPolicy.s8),
                        child: Row(
                          children: [
                            Text('Projets récents', style: ThixPolicy.h3Style),
                            const Spacer(),
                            TextButton(
                              onPressed: () => context.push(ThixIARoutes.projects), 
                              child: Text('Voir tout', style: ThixPolicy.bodySmallStyle.copyWith(color: ThixPolicy.primary))
                            ),
                          ],
                        ),
                      ),
                    ),

                    projectsAsync.when(
                      loading: () => const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.all(ThixPolicy.s24), child: Center(child: CircularProgressIndicator(color: ThixPolicy.primary)))),
                      error: (e, _) => SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.all(ThixPolicy.s24), child: Text('Erreur: $e'))),
                      data: (projects) {
                        if (projects.isEmpty) {
                          // Ton vrai EmptyState
                          return SliverToBoxAdapter(child: EmptyProjects(onCreate: () => context.push(ThixIARoutes.createProject)));
                        }
                        return SliverList(
                          delegate: SliverChildBuilderDelegate((_, i) {
                            final p = projects.take(5).toList()[i];
                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s16, vertical: 6),
                              child: ProjectCard(
                                project: p,
                                isActive: p.projectCode == activeProject?.projectCode,
                                onTap: () => context.push(ThixIARoutes.projectDetailPath(p.projectCode)),
                              ),
                            );
                          }, childCount: projects.take(5).length),
                        );
                      },
                    ),

                    const SliverToBoxAdapter(child: SizedBox(height: 100)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- WIDGETS UI ---

  Widget _buildHeroBanner(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s16),
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
            const SizedBox(height: ThixPolicy.s20),
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

  Widget _buildMainActions(BuildContext context, String? activeCode) {
    final actions = [
      {'title': 'Étudier\nun marché', 'icon': Icons.bar_chart_rounded, 'color': ThixPolicy.domainJobs, 'route': ThixIARoutes.market},
      {'title': 'Créer un\nBusiness Plan', 'icon': Icons.description_rounded, 'color': ThixPolicy.domainNetwork, 'route': ThixIARoutes.business},
      {'title': 'Vérifier\nréglementation', 'icon': Icons.balance_rounded, 'color': ThixPolicy.domainOpportunity, 'route': ThixIARoutes.legal},
    ];

    return SizedBox(
      height: 120,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s16),
        scrollDirection: Axis.horizontal,
        itemCount: actions.length,
        separatorBuilder: (_, __) => const SizedBox(width: ThixPolicy.s12),
        itemBuilder: (context, index) {
          final action = actions[index];
          return GestureDetector(
            onTap: () {
              if (activeCode != null) {
                // S'il y a un projet actif, on génère la vraie route dynamiquement
                context.push(ThixIARoutes.withCode(action['route'] as String, activeCode));
              } else {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Veuillez d\'abord sélectionner ou créer un projet actif.')));
              }
            },
            child: Container(
              width: 130,
              padding: const EdgeInsets.all(ThixPolicy.s12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9), 
                borderRadius: BorderRadius.circular(ThixPolicy.rLg),
                border: Border.all(color: Colors.white, width: 1.5),
                boxShadow: ThixPolicy.shadowSoft(),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: (action['color'] as Color).withOpacity(0.15), shape: BoxShape.circle),
                    child: Icon(action['icon'] as IconData, color: action['color'] as Color, size: 20),
                  ),
                  const Spacer(),
                  Text(action['title'] as String, style: ThixPolicy.labelStyle.copyWith(height: 1.2)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
