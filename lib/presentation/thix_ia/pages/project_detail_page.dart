// lib/presentation/thix_ia/pages/project_detail_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/thix_design_policy.dart';
import '../providers/thix_ia_provider.dart';
import '../providers/analysis_provider.dart';
import '../providers/project_memory_provider.dart';
import '../providers/document_provider.dart';
import '../widgets/project_header.dart';
import '../widgets/fact_card.dart';
import '../widgets/analysis_progress_widget.dart';
import '../widgets/empty_state_widget.dart';
import '../widgets/ai_command_bar.dart';
import '../core/constants/thix_ia_routes.dart';
import '../models/thix_project.dart';

class ProjectDetailPage extends ConsumerStatefulWidget {
  const ProjectDetailPage({super.key, required this.projectCode});
  final String projectCode;

  @override
  ConsumerState<ProjectDetailPage> createState() => _ProjectDetailPageState();
}

class _ProjectDetailPageState extends ConsumerState<ProjectDetailPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    Future.microtask(() async {
      try {
        await ref.read(activeProjectProvider.notifier).setActive(widget.projectCode);
        ref.read(analysesProvider.notifier).refresh();
        ref.read(projectMemoryProvider.notifier).refresh();
        ref.read(documentsProvider.notifier).refresh();
      } catch (e) {
        debugPrint('ProjectDetail setActive error: $e');
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeAsync = ref.watch(activeProjectProvider);

    return activeAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator(color: ThixPolicy.primary)),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(
          title: Text(widget.projectCode),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go(ThixIARoutes.projects),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 48),
                const SizedBox(height: 12),
                Text('Impossible de charger le projet', style: ThixPolicy.h3Style),
                const SizedBox(height: 8),
                Text('$e', textAlign: TextAlign.center, style: ThixPolicy.bodySmallStyle),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () =>
                      ref.read(activeProjectProvider.notifier).setActive(widget.projectCode),
                  child: const Text('Réessayer'),
                ),
                TextButton(
                  onPressed: () => context.go(ThixIARoutes.projects),
                  child: const Text('Retour aux projets'),
                ),
              ],
            ),
          ),
        ),
      ),
      data: (activeProject) {
        if (activeProject == null) {
          return Scaffold(
            appBar: AppBar(title: Text(widget.projectCode)),
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Projet introuvable'),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => context.go(ThixIARoutes.projects),
                    child: const Text('Mes projets'),
                  ),
                ],
              ),
            ),
          );
        }
        return _buildContent(context, activeProject);
      },
    );
  }

  Widget _buildContent(BuildContext context, ThixProject activeProject) {
    return Scaffold(
      backgroundColor: ThixPolicy.surface,
      body: NestedScrollView(
        headerSliverBuilder: (_, __) => [
          SliverAppBar(
            pinned: true,
            backgroundColor: Colors.white,
            title: Text(
              activeProject.projectCode,
              style: ThixPolicy.bodyStyle.copyWith(
                fontFamily: 'monospace',
                fontWeight: ThixPolicy.semiBold,
              ),
            ),
            actions: [
              IconButton(
                onPressed: () => context.push(ThixIARoutes.documentsPath(widget.projectCode)),
                icon: const Icon(Icons.folder_rounded, color: ThixPolicy.textSecondary),
              ),
            ],
            bottom: TabBar(
              controller: _tabController,
              labelColor: ThixPolicy.primary,
              unselectedLabelColor: ThixPolicy.textMuted,
              indicatorColor: ThixPolicy.primary,
              tabs: const [
                Tab(text: 'Vue d\'ensemble'),
                Tab(text: 'Analyses'),
                Tab(text: 'Mémoire'),
                Tab(text: 'Documents'),
              ],
            ),
          ),
          lowiverToBoxAdapter(
            child: ProjectHeader(project: activeProject, progress: activeProject.progress),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            _OverviewTab(project: activeProject),
            _AnalysesTab(projectCode: widget.projectCode),
            _MemoryTab(projectCode: widget.projectCode),
            _DocsTab(projectCode: widget.projectCode),
          ],
        ),
      ),
      bottomNavigationBar: AiCommandBar(
        onSubmit: (text) => _handleAiCommand(text),
        hintText: 'Demandez à THIX IA sur ${widget.projectCode}...',
      ),
    );
  }

  void _handleAiCommand(String text) {
    // Chat route non enregistrée pour l'instant → ouvrir analyse
    context.push(ThixIARoutes.analysisPath(widget.projectCode));
  }
}

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({required this.project});
  final ThixProject project;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        Text(project.name, style: ThixPolicy.h2Style),
        const SizedBox(height: 8),
        Text(
          '${project.sector} • \( {project.country} \){project.city != null ? ' • ${project.city}' : ''}',
          style: ThixPolicy.bodySmallStyle.copyWith(color: ThixPolicy.textSecondary),
        ),
        if (project.summary != null && project.summary!.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('Résumé', style: ThixPolicy.labelStyle),
          const SizedBox(height: 6),
          Text(project.summary!, style: ThixPolicy.bodyStyle),
        ],
        const SizedBox(height: 16),
        Text(
          'Progression : ${(project.progress * 100).toInt()}%',
          style: ThixPolicy.labelStyle,
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: project.progress.clamp(0.0, 1.0),
          backgroundColor: ThixPolicy.surfaceStrong,
          valueColor: const AlwaysStoppedAnimation(ThixPolicy.primary),
        ),
        const SizedBox(height: 8),
        Text(
          'Analyses : ${project.analysesCount}  •  Documents : ${project.documentsCount}',
          style: ThixPolicy.captionStyle,
        ),
      ],
    );
  }
}

class _AnalysesTab extends ConsumerWidget {
  const _AnalysesTab({required this.projectCode});
  final String projectCode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analyses = ref.watch(analysesProvider).value ?? [];
    if (analyses.isEmpty) {
      return EmptyAnalyses(
        onStart: () => context.push(ThixIARoutes.analysisPath(projectCode)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 100),
      itemCount: analyses.length,
      itemBuilder: (_, i) => AnalysisProgressWidget(analysis: analyses[i]),
    );
  }
}

class _MemoryTab extends ConsumerWidget {
  const _MemoryTab({required this.projectCode});
  final String projectCode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final memory = ref.watch(projectMemoryProvider).value;
    if (memory == null) {
      return const Center(child: CircularProgressIndicator(color: ThixPolicy.primary));
    }
    if (memory.facts.isEmpty) return const EmptyFacts();
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 100),
      itemCount: memory.facts.length,
      itemBuilder: (_, i) => FactCard(fact: memory.facts[i]),
    );
  }
}

class _DocsTab extends ConsumerWidget {
  const _DocsTab({required this.projectCode});
  final String projectCode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final docs = ref.watch(documentsProvider).value ?? [];
    if (docs.isEmpty) {
      return EmptyStateWidget(
        icon: Icons.folder_outlined,
        title: 'Aucun document',
        subtitle: 'Importez votre pitch, business plan ou études.',
        actionLabel: 'Importer',
        onAction: () => context.push(ThixIARoutes.documentsPath(projectCode)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 100),
      itemCount: docs.length,
      itemBuilder: (_, i) => ListTile(
        title: Text(docs[i].fileName),
        subtitle: Text(docs[i].status.name),
      ),
    );
  }
}
