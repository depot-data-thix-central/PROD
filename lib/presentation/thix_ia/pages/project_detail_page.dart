// lib/presentation/thix_ia/pages/project_detail_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/thix_design_policy.dart';

// <-- LA CORRECTION EST ICI : on utilise thix_ia_provider.dart
import '../providers/thix_ia_provider.dart'; 
import '../providers/analysis_provider.dart';
import '../providers/project_memory_provider.dart';
import '../providers/document_provider.dart';
// Note : Assure-toi que projectIntelligenceProvider est bien défini dans l'un de ces fichiers !

import '../widgets/project_header.dart';
import '../widgets/fact_card.dart';
import '../widgets/analysis_progress_widget.dart';
import '../widgets/empty_state_widget.dart';
import '../widgets/ai_command_bar.dart';
import '../core/constants/thix_ia_routes.dart';

class ProjectDetailPage extends ConsumerStatefulWidget {
  const ProjectDetailPage({super.key, required this.projectCode});
  final String projectCode;

  @override
  ConsumerState<ProjectDetailPage> createState() => _ProjectDetailPageState();
}

class _ProjectDetailPageState extends ConsumerState<ProjectDetailPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    Future.microtask(() async {
      await ref.read(activeProjectProvider.notifier).setActive(widget.projectCode);
      // S'il y a une erreur sur la ligne ci-dessous, mets-la en commentaire pour le moment
      // ref.read(projectIntelligenceProvider.notifier).refresh(); 
      ref.read(analysesProvider.notifier).refresh();
      ref.read(projectMemoryProvider.notifier).refresh();
      ref.read(documentsProvider.notifier).refresh();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // S'il y a une erreur sur la ligne ci-dessous, commente-la et gère un affichage par défaut
    // final intelligenceAsync = ref.watch(projectIntelligenceProvider); 
    final activeProject = ref.watch(activeProjectProvider).value;

    if (activeProject == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: ThixPolicy.primary)));
    }

    return Scaffold(
      backgroundColor: ThixPolicy.surface,
      body: NestedScrollView(
        headerSliverBuilder: (_, __) => [
          SliverAppBar(
            pinned: true,
            backgroundColor: Colors.white,
            title: Text(activeProject.projectCode, style: ThixPolicy.bodyStyle.copyWith(fontFamily: 'monospace', fontWeight: ThixPolicy.semiBold)),
            actions: [
              IconButton(onPressed: () => context.push('${ThixIARoutes.home}/project/${widget.projectCode}/chat'), icon: const Icon(Icons.chat_bubble_rounded, color: ThixPolicy.primary)),
              IconButton(onPressed: () => context.push('${ThixIARoutes.home}/project/${widget.projectCode}/documents'), icon: const Icon(Icons.folder_rounded, color: ThixPolicy.textSecondary)),
            ],
            bottom: TabBar(
              controller: _tabController,
              labelColor: ThixPolicy.primary,
              unselectedLabelColor: ThixPolicy.textMuted,
              indicatorColor: ThixPolicy.primary,
              tabs: const [Tab(text: 'Vue d\'ensemble'), Tab(text: 'Analyses'), Tab(text: 'Mémoire'), Tab(text: 'Documents')],
            ),
          ),
          SliverToBoxAdapter(
            child: ProjectHeader(project: activeProject, progress: activeProject.progress),
            // J'ai simplifié le header temporairement pour assurer que la page compile même si intelligenceProvider a bougé.
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            _OverviewTab(projectCode: widget.projectCode),
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

  void _handleAction(String action) {
    if (action.contains('marché')) context.push('${ThixIARoutes.home}/project/${widget.projectCode}/analysis');
    if (action.contains('réglementation')) ref.read(analysesProvider.notifier).startLegalAnalysis(jurisdiction: 'RDC', sector: 'General');
  }

  void _handleAiCommand(String text) {
    context.push('${ThixIARoutes.home}/project/${widget.projectCode}/chat', extra: text);
  }
}

class _OverviewTab extends ConsumerWidget {
  const _OverviewTab({required this.projectCode});
  final String projectCode;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Version simplifiée pour garantir la compilation
    return ListView(
      padding: const EdgeInsets.only(bottom: 100),
      children: [
        const Padding(padding: EdgeInsets.all(16), child: Text('Vue d\'ensemble', style: ThixPolicy.h3Style)),
        // Le contenu dynamique reviendra ici
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
    if (analyses.isEmpty) return EmptyAnalyses(onStart: () => context.push('/thix-ia/project/$projectCode/analysis'));
    return ListView.builder(padding: const EdgeInsets.only(bottom: 100), itemCount: analyses.length, itemBuilder: (_, i) => AnalysisProgressWidget(analysis: analyses[i]));
  }
}

class _MemoryTab extends ConsumerWidget {
  const _MemoryTab({required this.projectCode});
  final String projectCode;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final memory = ref.watch(projectMemoryProvider).value;
    if (memory == null) return const Center(child: CircularProgressIndicator());
    if (memory.facts.isEmpty) return const EmptyFacts();
    return ListView.builder(padding: const EdgeInsets.only(bottom: 100), itemCount: memory.facts.length, itemBuilder: (_, i) => FactCard(fact: memory.facts[i]));
  }
}

class _DocsTab extends ConsumerWidget {
  const _DocsTab({required this.projectCode});
  final String projectCode;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final docs = ref.watch(documentsProvider).value ?? [];
    if (docs.isEmpty) return EmptyStateWidget(icon: Icons.folder_outlined, title: 'Aucun document', subtitle: 'Importez votre pitch, business plan ou études.', actionLabel: 'Importer', onAction: () => context.push('/thix-ia/project/$projectCode/documents'));
    return ListView.builder(padding: const EdgeInsets.only(bottom: 100), itemCount: docs.length, itemBuilder: (_, i) => ListTile(title: Text(docs[i].fileName), subtitle: Text(docs[i].status.name)));
  }
}
