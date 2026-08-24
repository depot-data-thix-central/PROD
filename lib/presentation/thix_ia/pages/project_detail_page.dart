// lib/presentation/thix_ia/pages/project_detail_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/thix_design_policy.dart';
import '../core/constants/thix_ia_routes.dart';
import '../models/thix_project.dart';
import '../providers/thix_ia_provider.dart';
import '../providers/analysis_provider.dart';
import '../providers/project_memory_provider.dart';
import '../providers/document_provider.dart';
import '../widgets/project_header.dart';
import '../widgets/fact_card.dart';
import '../widgets/analysis_progress_widget.dart';
import '../widgets/empty_state_widget.dart';
import '../widgets/ai_command_bar.dart';

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
        ref.invalidate(analysesProvider);
        ref.invalidate(projectMemoryProvider);
        ref.invalidate(documentsProvider);
        await ref.read(analysesProvider.notifier).refresh();
        await ref.read(projectMemoryProvider.notifier).refresh();
        await ref.read(documentsProvider.notifier).refresh();
      } catch (e) {
        debugPrint('ProjectDetail init error: $e');
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _startMarket() async {
    final p = ref.read(activeProjectProvider).value;
    if (p == null) return;
    try {
      await ref.read(analysesProvider.notifier).startMarketAnalysis(
            country: p.country,
            sector: p.sector,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Analyse marche lancee')),
        );
        _tabController.animateTo(1);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _startLegal() async {
    final p = ref.read(activeProjectProvider).value;
    if (p == null) return;
    try {
      await ref.read(analysesProvider.notifier).startLegalAnalysis(
            jurisdiction: p.country,
            sector: p.sector,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Analyse legale lancee')),
        );
        _tabController.animateTo(1);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _handleAiCommand(String text) {
    final lower = text.toLowerCase();
    if (lower.contains('marche') || lower.contains('market')) {
      _startMarket();
    } else if (lower.contains('reglement') || lower.contains('legal')) {
      _startLegal();
    } else {
      context.push(ThixIARoutes.analysisPath(widget.projectCode));
    }
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
                  child: const Text('Reessayer'),
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
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
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
                onPressed: () =>
                    context.push(ThixIARoutes.documentsPath(widget.projectCode)),
                icon: const Icon(Icons.folder_rounded, color: ThixPolicy.textSecondary),
              ),
            ],
            bottom: TabBar(
              controller: _tabController,
              labelColor: ThixPolicy.primary,
              unselectedLabelColor: ThixPolicy.textMuted,
              indicatorColor: ThixPolicy.primary,
              isScrollable: true,
              tabs: const [
                Tab(text: "Vue d'ensemble"),
                Tab(text: 'Analyses'),
                Tab(text: 'Memoire'),
                Tab(text: 'Documents'),
              ],
            ),
          ),
          SliverToBoxAdapter(
            child: ProjectHeader(
              project: activeProject,
              progress: activeProject.progress,
            ),
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
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _startMarket,
                    icon: const Icon(Icons.auto_awesome, size: 16),
                    label: const Text('Analyse marche', style: TextStyle(fontSize: 12)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _startLegal,
                    icon: const Icon(Icons.balance, size: 16),
                    label: const Text('Reglementation', style: TextStyle(fontSize: 12)),
                  ),
                ),
              ],
            ),
          ),
          AiCommandBar(
            onSubmit: _handleAiCommand,
            hintText: 'Demandez a THIX IA sur ${widget.projectCode}...',
          ),
        ],
      ),
    );
  }
}

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({required this.project});
  final ThixProject project;

  @override
  Widget build(BuildContext context) {
    final cityPart = project.city != null ? ' • ${project.city}' : '';
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
      children: [
        Text(project.name, style: ThixPolicy.h2Style),
        const SizedBox(height: 8),
        Text(
          '${project.sector} • ${project.country}$cityPart',
          style: ThixPolicy.bodySmallStyle.copyWith(color: ThixPolicy.textSecondary),
        ),
        if (project.summary != null && project.summary!.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('Resume', style: ThixPolicy.labelStyle),
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
    final async = ref.watch(analysesProvider);

    return async.when(
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(color: ThixPolicy.primary),
        ),
      ),
      error: (e, _) => ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 40),
          const SizedBox(height: 12),
          Text('Erreur analyses', style: ThixPolicy.h3Style),
          const SizedBox(height: 8),
          Text('$e', style: ThixPolicy.bodySmallStyle),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => ref.read(analysesProvider.notifier).refresh(),
            child: const Text('Reessayer'),
          ),
        ],
      ),
      data: (analyses) {
        if (analyses.isEmpty) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 120),
            children: [
              EmptyAnalyses(
                onStart: () => context.push(ThixIARoutes.analysisPath(projectCode)),
              ),
            ],
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 120),
          itemCount: analyses.length,
          itemBuilder: (_, i) => AnalysisProgressWidget(analysis: analyses[i]),
        );
      },
    );
  }
}

class _MemoryTab extends ConsumerWidget {
  const _MemoryTab({required this.projectCode});
  final String projectCode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(projectMemoryProvider);

    return async.when(
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(color: ThixPolicy.primary),
        ),
      ),
      error: (e, _) => ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 40),
          const SizedBox(height: 12),
          Text('Erreur memoire', style: ThixPolicy.h3Style),
          const SizedBox(height: 8),
          Text('$e', style: ThixPolicy.bodySmallStyle),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => ref.read(projectMemoryProvider.notifier).refresh(),
            child: const Text('Reessayer'),
          ),
        ],
      ),
      data: (memory) {
        final facts = memory?.facts ?? [];
        if (facts.isEmpty) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 120),
            children: const [EmptyFacts()],
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 120),
          itemCount: facts.length,
          itemBuilder: (_, i) => FactCard(fact: facts[i]),
        );
      },
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
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 120),
        children: [
          EmptyStateWidget(
            icon: Icons.folder_outlined,
            title: 'Aucun document',
            subtitle: 'Importez votre pitch, business plan ou etudes.',
            actionLabel: 'Importer',
            onAction: () => context.push(ThixIARoutes.documentsPath(projectCode)),
          ),
        ],
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 120),
      itemCount: docs.length,
      itemBuilder: (_, i) => ListTile(
        title: Text(docs[i].fileName),
        subtitle: Text(docs[i].status.name),
      ),
    );
  }
}
