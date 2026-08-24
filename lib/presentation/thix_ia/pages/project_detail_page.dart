// lib/presentation/thix_ia/pages/project_detail_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/thix_design_policy.dart';
import '../core/constants/thix_ia_routes.dart';
import '../models/thix_project.dart';
import '../models/project_analysis.dart';
import '../providers/thix_ia_provider.dart';
import '../providers/analysis_provider.dart';
import '../providers/project_memory_provider.dart';
import '../providers/document_provider.dart';
import '../providers/chat_provider.dart';
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
  bool _isSending = false;

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
        await Future.wait([
          ref.read(analysesProvider.notifier).refresh(),
          ref.read(projectMemoryProvider.notifier).refresh(),
          ref.read(documentsProvider.notifier).refresh(),
        ]);
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

  // ====================== HELPERS ======================

  String _buildIdeaContext(ThixProject p) {
    return [
      p.name,
      if (p.summary != null && p.summary!.trim().isNotEmpty) p.summary!,
    ].where((e) => e.trim().isNotEmpty).join('\n');
  }

  void _onAnalysisStarted(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
    _tabController.animateTo(1);
  }

  void _showError(Object e) {
    if (!mounted) return;
    final msg = e.toString().replaceFirst('Exception: ', '');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: msg.contains('existe déjà') ? Colors.orange : Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
    if (msg.contains('existe déjà')) {
      _tabController.animateTo(1);
    }
  }

  // ====================== LANCEMENT DES CARTES ======================

  Future<void> _startMarket() async {
    final p = ref.read(activeProjectProvider).value;
    if (p == null) return;

    try {
      await ref.read(analysesProvider.notifier).startMarketAnalysis(
            country: p.country,
            sector: p.sector,
            ideaDescription: _buildIdeaContext(p),
          );
      _onAnalysisStarted('Étude de marché lancée');
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _startLegal() async {
    final p = ref.read(activeProjectProvider).value;
    if (p == null) return;

    try {
      await ref.read(analysesProvider.notifier).startLegalAnalysis(
            jurisdiction: p.country,
            sector: p.sector,
            ideaDescription: _buildIdeaContext(p),
          );
      _onAnalysisStarted('Analyse réglementaire lancée');
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _startCompetitor() async {
    final p = ref.read(activeProjectProvider).value;
    if (p == null) return;

    try {
      await ref.read(analysesProvider.notifier).startCompetitorAnalysis(
            country: p.country,
            sector: p.sector,
            ideaDescription: _buildIdeaContext(p),
          );
      _onAnalysisStarted('Analyse concurrentielle lancée');
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _startFinance() async {
    final p = ref.read(activeProjectProvider).value;
    if (p == null) return;

    try {
      await ref.read(analysesProvider.notifier).startFinanceAnalysis(
            ideaDescription: _buildIdeaContext(p),
          );
      _onAnalysisStarted('Modèle financier lancé');
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _startBusinessPlan() async {
    final p = ref.read(activeProjectProvider).value;
    if (p == null) return;

    try {
      await ref.read(analysesProvider.notifier).startBusinessPlanAnalysis(
            ideaDescription: _buildIdeaContext(p),
          );
      _onAnalysisStarted('Business plan lancé');
    } catch (e) {
      _showError(e);
    }
  }

  // ====================== COMMANDE IA ======================

  Future<void> _handleAiCommand(String text) async {
    final lower = text.toLowerCase().trim();
    if (lower.isEmpty) return;

    if (lower.contains('marché') || lower.contains('market') || lower.contains('etude')) {
      await _startMarket();
      return;
    }
    if (lower.contains('réglement') || lower.contains('legal') || lower.contains('loi')) {
      await _startLegal();
      return;
    }
    if (lower.contains('concurrent') || lower.contains('competitor')) {
      await _startCompetitor();
      return;
    }
    if (lower.contains('financier') ||
        lower.contains('finance') ||
        lower.contains('modèle') ||
        lower.contains('modele')) {
      await _startFinance();
      return;
    }
    if (lower.contains('business plan') ||
        lower.contains('businessplan') ||
        lower.contains('plan d\'affaires') ||
        lower.contains('plan daffaires')) {
      await _startBusinessPlan();
      return;
    }

    // Sinon → chat libre
    setState(() => _isSending = true);
    try {
      await ref.read(chatProvider.notifier).sendMessage(text);
      if (mounted) {
        context.push(ThixIARoutes.chatPath(widget.projectCode));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur chat: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _confirmDeleteProject() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer le projet ?'),
        content: Text(
          'Le projet ${widget.projectCode} sera définitivement supprimé.\nCette action est irréversible.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      try {
        await ref.read(projectServiceProvider).deleteProject(widget.projectCode);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Projet supprimé'),
              behavior: SnackBarBehavior.floating,
            ),
          );
          context.go(ThixIARoutes.projects);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur suppression: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
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
            icon: const Icon(Icons.arrow_back_rounded, size: 22),
            onPressed: () => context.go(ThixIARoutes.projects),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline_rounded, color: Colors.red, size: 40),
                const SizedBox(height: 12),
                Text('Impossible de charger le projet', style: ThixPolicy.h3Style),
                const SizedBox(height: 8),
                Text('$e', textAlign: TextAlign.center, style: ThixPolicy.bodySmallStyle),
                const SizedBox(height: 20),
                FilledButton(
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
        headerSliverBuilder: (context, _) => [
          SliverAppBar(
            pinned: true,
            backgroundColor: Colors.white,
            elevation: 0,
            titleSpacing: 0,
            title: Text(
              activeProject.projectCode,
              style: ThixPolicy.bodyStyle.copyWith(
                fontFamily: 'monospace',
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            actions: [
              IconButton(
                tooltip: 'Documents',
                onPressed: () => context.push(ThixIARoutes.documentsPath(widget.projectCode)),
                icon: const Icon(Icons.folder_outlined, size: 20, color: ThixPolicy.textSecondary),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded, size: 20),
                padding: EdgeInsets.zero,
                onSelected: (value) async {
                  if (value == 'market') await _startMarket();
                  if (value == 'legal') await _startLegal();
                  if (value == 'competitor') await _startCompetitor();
                  if (value == 'finance') await _startFinance();
                  if (value == 'business_plan') await _startBusinessPlan();
                  if (value == 'delete') await _confirmDeleteProject();
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'market',
                    height: 40,
                    child: Row(
                      children: [
                        Icon(Icons.insights_outlined, size: 18),
                        SizedBox(width: 10),
                        Text('Lancer étude de marché', style: TextStyle(fontSize: 13)),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'legal',
                    height: 40,
                    child: Row(
                      children: [
                        Icon(Icons.balance_outlined, size: 18),
                        SizedBox(width: 10),
                        Text('Vérifier réglementation', style: TextStyle(fontSize: 13)),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'competitor',
                    height: 40,
                    child: Row(
                      children: [
                        Icon(Icons.groups_outlined, size: 18),
                        SizedBox(width: 10),
                        Text('Analyse concurrentielle', style: TextStyle(fontSize: 13)),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'finance',
                    height: 40,
                    child: Row(
                      children: [
                        Icon(Icons.calculate_outlined, size: 18),
                        SizedBox(width: 10),
                        Text('Modèle financier', style: TextStyle(fontSize: 13)),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'business_plan',
                    height: 40,
                    child: Row(
                      children: [
                        Icon(Icons.description_outlined, size: 18),
                        SizedBox(width: 10),
                        Text('Business plan', style: TextStyle(fontSize: 13)),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(),
                  const PopupMenuItem(
                    value: 'delete',
                    height: 40,
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red),
                        SizedBox(width: 10),
                        Text('Supprimer le projet', style: TextStyle(fontSize: 13, color: Colors.red)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(40),
              child: TabBar(
                controller: _tabController,
                labelColor: ThixPolicy.primary,
                unselectedLabelColor: ThixPolicy.textMuted,
                indicatorColor: ThixPolicy.primary,
                indicatorWeight: 2.5,
                labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                unselectedLabelStyle: const TextStyle(fontSize: 13),
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                tabs: const [
                  Tab(text: "Vue d'ensemble", height: 36),
                  Tab(text: 'Analyses', height: 36),
                  Tab(text: 'Mémoire', height: 36),
                  Tab(text: 'Documents', height: 36),
                ],
              ),
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
      bottomNavigationBar: AiCommandBar(
        onSubmit: _handleAiCommand,
        hintText: 'Demandez à THIX IA sur ${widget.projectCode}...',
        isLoading: _isSending,
      ),
    );
  }
}

// ============================================================
// TABS (gardés tels quels – tu peux coller tes versions existantes)
// ============================================================

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({required this.project});
  final ThixProject project;

  @override
  Widget build(BuildContext context) {
    final cityPart = project.city != null ? ' • ${project.city}' : '';

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      children: [
        Text(project.name, style: ThixPolicy.h2Style.copyWith(fontSize: 20)),
        const SizedBox(height: 4),
        Text(
          '${project.sector} • ${project.country}$cityPart',
          style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.textSecondary),
        ),
        if (project.summary != null && project.summary!.isNotEmpty) ...[
          const SizedBox(height: 14),
          Text('Résumé', style: ThixPolicy.labelStyle.copyWith(fontSize: 12)),
          const SizedBox(height: 4),
          Text(project.summary!, style: ThixPolicy.bodySmallStyle),
        ],
        const SizedBox(height: 16),
        Row(
          children: [
            Text(
              'Progression  ${(project.progress * 100).toInt()}%',
              style: ThixPolicy.labelStyle.copyWith(fontSize: 12),
            ),
            const Spacer(),
            Text(
              '${project.analysesCount} analyses  •  ${project.documentsCount} docs',
              style: ThixPolicy.microStyle,
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: project.progress.clamp(0.0, 1.0),
            minHeight: 5,
            backgroundColor: ThixPolicy.surfaceStrong,
            valueColor: const AlwaysStoppedAnimation(ThixPolicy.primary),
          ),
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
          child: CircularProgressIndicator(color: ThixPolicy.primary, strokeWidth: 2.5),
        ),
      ),
      error: (e, _) => ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Icon(Icons.error_outline_rounded, color: Colors.red, size: 36),
          const SizedBox(height: 10),
          Text('Erreur analyses', style: ThixPolicy.h3Style),
          const SizedBox(height: 6),
          Text('$e', style: ThixPolicy.bodySmallStyle),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: () => ref.read(analysesProvider.notifier).refresh(),
            child: const Text('Réessayer'),
          ),
        ],
      ),
      data: (analyses) {
        if (analyses.isEmpty) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 100),
            children: [
              EmptyAnalyses(
                onStart: () => context.push(ThixIARoutes.analysisPath(projectCode)),
              ),
            ],
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
          itemCount: analyses.length,
          itemBuilder: (context, index) {
            final a = analyses[index];
            return AnalysisProgressWidget(analysis: a);
          },
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
    return const Center(child: Text('Mémoire projet'));
  }
}

class _DocsTab extends ConsumerWidget {
  const _DocsTab({required this.projectCode});
  final String projectCode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const Center(child: Text('Documents'));
  }
}
