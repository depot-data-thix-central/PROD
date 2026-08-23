// lib/presentation/thix_ia/pages/thix_ia_home_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/thix_design_policy.dart';
import '../providers/thix_ia_provider.dart';
import '../providers/active_project_provider.dart';
import '../providers/analysis_provider.dart';
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
    final projectsAsync = ref.watch(projectsProvider);
    final activeProject = ref.watch(activeProjectProvider).value;
    final analysesAsync = ref.watch(analysesProvider);
    final intelligenceAsync = ref.watch(projectIntelligenceProvider);

    return Scaffold(
      backgroundColor: ThixPolicy.surface,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text('THIX IA', style: ThixPolicy.h2Style),
        actions: [
          IconButton(onPressed: () => context.push(ThixIARoutes.createProject), icon: Icon(Icons.add_rounded, color: ThixPolicy.primary)),
        ],
        bottom: PreferredSize(preferredSize: const Size.fromHeight(1), child: Container(height: 1, color: ThixPolicy.border)),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(projectsProvider.notifier).refresh();
          if (activeProject!= null) await ref.read(projectIntelligenceProvider.notifier).refresh();
        },
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: ActiveProjectSelector(onTap: () => context.push(ThixIARoutes.projects))),
            if (intelligenceAsync.value!= null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: ThixPolicy.s8),
                      Text('Prochaines étapes', style: ThixPolicy.labelStyle),
                      const SizedBox(height: ThixPolicy.s8),
                      Wrap(
                        spacing: 8,
                        children: intelligenceAsync.value!.nextActions.map((a) => Chip(label: Text(a, style: ThixPolicy.captionStyle), backgroundColor: ThixPolicy.primary.withOpacity(0.08))).toList(),
                      ),
                    ],
                  ),
                ),
              ),
            if (analysesAsync.value!= null && analysesAsync.value!.any((a) => a.isRunning))
              SliverList(
                delegate: SliverChildBuilderDelegate((_, i) {
                  final running = analysesAsync.value!.where((a) => a.isRunning).toList()[i];
                  return AnalysisProgressWidget(analysis: running);
                }, childCount: analysesAsync.value!.where((a) => a.isRunning).length),
              ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(ThixPolicy.s16, ThixPolicy.s20, ThixPolicy.s16, ThixPolicy.s8),
                child: Row(
                  children: [
                    Text('Projets récents', style: ThixPolicy.h3Style),
                    const Spacer(),
                    TextButton(onPressed: () => context.push(ThixIARoutes.projects), child: Text('Voir tout', style: ThixPolicy.bodySmallStyle.copyWith(color: ThixPolicy.primary))),
                  ],
                ),
              ),
            ),
            projectsAsync.when(
              loading: () => SliverToBoxAdapter(child: Padding(padding: EdgeInsets.all(ThixPolicy.s24), child: Center(child: CircularProgressIndicator(color: ThixPolicy.primary)))),
              error: (e, _) => SliverToBoxAdapter(child: Padding(padding: EdgeInsets.all(ThixPolicy.s24), child: Text('Erreur: $e'))),
              data: (projects) {
                if (projects.isEmpty) {
                  return SliverToBoxAdapter(child: EmptyProjects(onCreate: () => context.push(ThixIARoutes.createProject)));
                }
                return SliverList(
                  delegate: SliverChildBuilderDelegate((_, i) {
                    final p = projects.take(5).toList()[i];
                    return ProjectCard(
                      project: p,
                      isActive: p.projectCode == activeProject?.projectCode,
                      onTap: () => context.push('${ThixIARoutes.home}/project/${p.projectCode}'),
                    );
                  }, childCount: projects.take(5).length),
                );
              },
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(ThixIARoutes.createProject),
        backgroundColor: ThixPolicy.primary,
        icon: const Icon(Icons.auto_awesome_rounded, color: Colors.white),
        label: Text('Nouvelle idée', style: ThixPolicy.bodyStyle.copyWith(color: Colors.white, fontWeight: ThixPolicy.semiBold)),
      ),
    );
  }
}
