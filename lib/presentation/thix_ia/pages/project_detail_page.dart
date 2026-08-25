// lib/presentation/thix_ia/pages/project_detail_page.dart
import 'dart:typed_data';

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
import '../providers/chat_provider.dart';
import '../services/document_generation_service.dart';
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
          const SnackBar(
            content: Text('Étude de marché lancée'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        _tabController.animateTo(1);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
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
          const SnackBar(
            content: Text('Analyse réglementaire lancée'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        _tabController.animateTo(1);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _handleAiCommand(String text) async {
    final lower = text.toLowerCase().trim();
    if (lower.isEmpty) return;

    if (lower.contains('marché') ||
        lower.contains('market') ||
        lower.contains('etude')) {
      await _startMarket();
      return;
    }
    if (lower.contains('réglement') ||
        lower.contains('legal') ||
        lower.contains('loi')) {
      await _startLegal();
      return;
    }

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
        body: Center(
          child: CircularProgressIndicator(color: ThixPolicy.primary),
        ),
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
                onPressed: () =>
                    context.push(ThixIARoutes.documentsPath(widget.projectCode)),
                icon: const Icon(
                  Icons.folder_outlined,
                  size: 20,
                  color: ThixPolicy.textSecondary,
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded, size: 20),
                padding: EdgeInsets.zero,
                onSelected: (value) async {
                  if (value == 'market') await _startMarket();
                  if (value == 'legal') await _startLegal();
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
                  const PopupMenuDivider(),
                  const PopupMenuItem(
                    value: 'delete',
                    height: 40,
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red),
                        SizedBox(width: 10),
                        Text(
                          'Supprimer le projet',
                          style: TextStyle(fontSize: 13, color: Colors.red),
                        ),
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
            _MemoryTab(
              projectCode: widget.projectCode,
              onGoToDocuments: () => _tabController.animateTo(3),
            ),
            _DocsTab(projectCode: widget.projectCode),
          ],
        ),
      ),
      bottomNavigationBar: AiCommandBar(
        onSubmit: _handleAiCommand,
        hintText: 'Demandez à THIX IA sur ${widget.projectCode}...',
        isLoading: _isSending,
        showSuggestions: true,
      ),
    );
  }
}

// ============================================================
// TABS
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
          child: CircularProgressIndicator(
            color: ThixPolicy.primary,
            strokeWidth: 2.5,
          ),
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
          padding: const EdgeInsets.only(bottom: 100),
          itemCount: analyses.length,
          itemBuilder: (_, i) => AnalysisProgressWidget(analysis: analyses[i]),
        );
      },
    );
  }
}

class _MemoryTab extends ConsumerStatefulWidget {
  const _MemoryTab({
    required this.projectCode,
    this.onGoToDocuments,
  });

  final String projectCode;
  final VoidCallback? onGoToDocuments;

  @override
  ConsumerState<_MemoryTab> createState() => _MemoryTabState();
}

class _MemoryTabState extends ConsumerState<_MemoryTab> {
  bool _isGenerating = false;

  Future<void> _generateFinalDossier() async {
    final project = ref.read(activeProjectProvider).value;
    final memory = ref.read(projectMemoryProvider).value;
    final analyses = ref.read(analysesProvider).value ?? [];

    if (project == null) {
      _showSnack('Aucun projet actif', isError: true);
      return;
    }
    if (memory == null) {
      _showSnack('Mémoire non chargée', isError: true);
      return;
    }

    final validated = analyses.where((a) => a.isCompleted).toList();

    if (validated.isEmpty && memory.facts.isEmpty) {
      _showSnack(
        'Lance d\'abord au moins une analyse (marché, réglementation…)',
        isError: true,
      );
      return;
    }

    setState(() => _isGenerating = true);

    try {
      // 1. Générer le PDF
      final service = ref.read(documentGenerationServiceProvider);
      final pdfBytes = await service.generate(
        type: DocumentType.businessPlan,
        project: project,
        memory: memory,
        validatedAnalyses: validated,
      );

      // 2. Enregistrer dans Documents (CORRECTION SYNTAXE ICI)
      final fileName =
          'BusinessPlan_${project.projectCode}_${DateTime.now().millisecondsSinceEpoch}.pdf';

      await ref.read(documentsProvider.notifier).upload(
            fileName: fileName,
            bytes: pdfBytes,
            mimeType: 'application/pdf',
          );

      // 3. Rafraîchir Documents
      await ref.read(documentsProvider.notifier).refresh();

      if (!mounted) return;

      _showSnack('Business Plan généré et ajouté aux Documents');

      // 4. Aller automatiquement à l’onglet Documents
      widget.onGoToDocuments?.call();
    } catch (e) {
      _showSnack('Erreur génération : $e', isError: true);
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red : null,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(projectMemoryProvider);
    final analyses = ref.watch(analysesProvider).value ?? [];
    final completedCount = analyses.where((a) => a.isCompleted).length;

    return async.when(
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(
            color: ThixPolicy.primary,
            strokeWidth: 2.5,
          ),
        ),
      ),
      error: (e, _) => ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Icon(Icons.error_outline_rounded, color: Colors.red, size: 36),
          const SizedBox(height: 10),
          Text('Erreur mémoire', style: ThixPolicy.h3Style),
          const SizedBox(height: 6),
          Text('$e', style: ThixPolicy.bodySmallStyle),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: () => ref.read(projectMemoryProvider.notifier).refresh(),
            child: const Text('Réessayer'),
          ),
        ],
      ),
      data: (memory) {
        final facts = memory?.facts ?? [];

        return ListView(
          // 👇 MODIFICATION ICI: Padding horizontal réduit à 8 pour élargir les cartes
          padding: const EdgeInsets.fromLTRB(8, 12, 8, 120),
          children: [
            // ========== BOUTON DOSSIER FINAL ==========
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.symmetric(horizontal: 8), // Marge pour aligner avec les cartes
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    ThixPolicy.primary.withOpacity(0.08),
                    ThixPolicy.primary.withOpacity(0.03),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: ThixPolicy.primary.withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: ThixPolicy.primary.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.auto_awesome,
                          color: ThixPolicy.primary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Dossier final investisseur',
                              style: ThixPolicy.bodyStyle
                                  .copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '$completedCount analyses • ${facts.length} faits validés',
                              style: ThixPolicy.captionStyle,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton.icon(
                      onPressed: _isGenerating ? null : _generateFinalDossier,
                      icon: _isGenerating
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.rocket_launch_rounded, size: 20),
                      label: Text(
                        _isGenerating
                            ? 'Génération en cours…'
                            : 'Générer le Business Plan final',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Collecte automatique de toutes les analyses + mémoire. Le PDF est enregistré dans Documents.',
                    style: ThixPolicy.microStyle
                        .copyWith(color: ThixPolicy.textMuted),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            if (facts.isEmpty)
              const EmptyFacts()
            else ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  'Faits en mémoire (${facts.length})',
                  style: ThixPolicy.labelStyle.copyWith(fontSize: 13),
                ),
              ),
              const SizedBox(height: 8),
              ...facts.map((f) => FactCard(fact: f)),
            ],
          ],
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
    final async = ref.watch(documentsProvider);

    return async.when(
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(
            color: ThixPolicy.primary,
            strokeWidth: 2.5,
          ),
        ),
      ),
      error: (e, _) => ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Icon(Icons.error_outline_rounded, color: Colors.red, size: 36),
          const SizedBox(height: 10),
          Text('Erreur documents', style: ThixPolicy.h3Style),
          const SizedBox(height: 6),
          Text('$e', style: ThixPolicy.bodySmallStyle),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: () => ref.read(documentsProvider.notifier).refresh(),
            child: const Text('Réessayer'),
          ),
        ],
      ),
      data: (docs) {
        if (docs.isEmpty) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 100),
            children: [
              EmptyStateWidget(
                icon: Icons.folder_outlined,
                title: 'Aucun document',
                subtitle:
                    'Génère un Business Plan depuis l’onglet Mémoire ou importe un fichier.',
                actionLabel: 'Aller à Mémoire',
                onAction: () {},
              ),
            ],
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 100),
          itemCount: docs.length,
          itemBuilder: (_, i) {
            final d = docs[i];
            // CORRECTION SYNTAXE ICI
            final dateStr = d.createdAt == null
                ? ''
                : '${d.createdAt!.day.toString().padLeft(2, '0')}/${d.createdAt!.month.toString().padLeft(2, '0')}';

            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: ThixPolicy.border),
              ),
              child: ListTile(
                dense: true,
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: ThixPolicy.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.picture_as_pdf_rounded,
                    color: ThixPolicy.primary,
                    size: 20,
                  ),
                ),
                title: Text(
                  d.fileName,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  d.status.name,
                  style: ThixPolicy.microStyle,
                ),
                trailing: Text(
                  dateStr,
                  style: ThixPolicy.microStyle,
                ),
              ),
            );
          },
        );
      },
    );
  }
}
