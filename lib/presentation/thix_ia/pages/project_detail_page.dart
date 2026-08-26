// lib/presentation/thix_ia/pages/project_detail_page.dart
import 'dart:typed_data';
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
import '../services/document_generation_service.dart';
import '../widgets/project_header.dart';
import '../widgets/fact_card.dart';
import '../widgets/analysis_progress_widget.dart';
import '../widgets/empty_state_widget.dart';
import '../widgets/ai_command_bar.dart';
import '../widgets/phase_switcher.dart'; 
import 'execution_dashboard.dart'; // 👈 IMPORT DE TON NOUVEAU DASHBOARD SAAS

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
  bool _isExecutionMode = false;

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

    final isMarket = lower.contains('marché') || lower.contains('market') || lower.contains('etude') || lower.contains('étude');
    final isLegal = lower.contains('réglement') || lower.contains('reglement') || lower.contains('legal') || lower.contains('loi') || lower.contains('fiscal');
    final isCompetitor = lower.contains('concurrent') || lower.contains('compétiteur') || lower.contains('competitor');
    final isBusinessPlan = lower.contains('business plan') || lower.contains('businessplan') || lower.contains('dossier final') || lower.contains('génère le business') || lower.contains('genere le business');

    if (isMarket) {
      await _startMarket();
      return;
    }
    if (isLegal) {
      await _startLegal();
      return;
    }
    if (isCompetitor) {
      try {
        final p = ref.read(activeProjectProvider).value;
        if (p != null) {
          await ref.read(analysesProvider.notifier).startCompetitorAnalysis(
                country: p.country,
                sector: p.sector,
                ideaDescription: _buildIdeaContext(p),
              );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Analyse concurrentielle lancée'), behavior: SnackBarBehavior.floating),
            );
            _tabController.animateTo(1);
          }
        }
      } catch (_) {
        await _sendToChat(text);
      }
      return;
    }
    if (isBusinessPlan) {
      _tabController.animateTo(2);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Va dans Mémoire → Générer le Business Plan final'), behavior: SnackBarBehavior.floating),
      );
      return;
    }

    await _sendToChat(text);
  }

  Future<void> _sendToChat(String text) async {
    setState(() => _isSending = true);
    try {
      await ref.read(chatProvider.notifier).sendMessage(text);
      if (mounted) {
        context.push(ThixIARoutes.chatPath(widget.projectCode));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur chat: $e'), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating),
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
        content: Text('Le projet ${widget.projectCode} sera définitivement supprimé.\nCette action est irréversible.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), style: TextButton.styleFrom(foregroundColor: Colors.red), child: const Text('Supprimer')),
        ],
      ),
    );

    if (confirm == true && mounted) {
      try {
        await ref.read(projectServiceProvider).deleteProject(widget.projectCode);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Projet supprimé'), behavior: SnackBarBehavior.floating),
          );
          context.go(ThixIARoutes.projects);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur suppression: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeAsync = ref.watch(activeProjectProvider);

    return activeAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator(color: ThixPolicy.primary))),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: Text(widget.projectCode), leading: IconButton(icon: const Icon(Icons.arrow_back_rounded, size: 22), onPressed: () => context.go(ThixIARoutes.projects))),
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
                FilledButton(onPressed: () => ref.read(activeProjectProvider.notifier).setActive(widget.projectCode), child: const Text('Réessayer')),
                TextButton(onPressed: () => context.go(ThixIARoutes.projects), child: const Text('Retour aux projets')),
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
                  TextButton(onPressed: () => context.go(ThixIARoutes.projects), child: const Text('Mes projets')),
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
              style: ThixPolicy.bodyStyle.copyWith(fontFamily: 'monospace', fontWeight: FontWeight.w600, fontSize: 14),
            ),
            actions: [
              IconButton(tooltip: 'Documents', onPressed: () => context.push(ThixIARoutes.documentsPath(widget.projectCode)), icon: const Icon(Icons.folder_outlined, size: 20, color: ThixPolicy.textSecondary)),
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
                  const PopupMenuItem(value: 'market', height: 40, child: Row(children: [Icon(Icons.insights_outlined, size: 18), SizedBox(width: 10), Text('Lancer étude de marché', style: TextStyle(fontSize: 13))])),
                  const PopupMenuItem(value: 'legal', height: 40, child: Row(children: [Icon(Icons.balance_outlined, size: 18), SizedBox(width: 10), Text('Vérifier réglementation', style: TextStyle(fontSize: 13))])),
                  const PopupMenuItem(value: 'competitor', height: 40, child: Row(children: [Icon(Icons.groups_outlined, size: 18), SizedBox(width: 10), Text('Analyse concurrentielle', style: TextStyle(fontSize: 13))])),
                  const PopupMenuItem(value: 'finance', height: 40, child: Row(children: [Icon(Icons.calculate_outlined, size: 18), SizedBox(width: 10), Text('Modèle financier', style: TextStyle(fontSize: 13))])),
                  const PopupMenuItem(value: 'business_plan', height: 40, child: Row(children: [Icon(Icons.description_outlined, size: 18), SizedBox(width: 10), Text('Business plan', style: TextStyle(fontSize: 13))])),
                  const PopupMenuDivider(),
                  const PopupMenuItem(value: 'delete', height: 40, child: Row(children: [Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red), SizedBox(width: 10), Text('Supprimer le projet', style: TextStyle(fontSize: 13, color: Colors.red))])),
                ],
              ),
            ],
            bottom: PreferredSize(
              preferredSize: Size.fromHeight(_isExecutionMode ? 64 : 112),
              child: Container(
                color: Colors.white,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    PhaseSwitcher(
                      isExecutionMode: _isExecutionMode,
                      onModeChanged: (val) {
                        setState(() {
                          _isExecutionMode = val;
                        });
                      },
                    ),
                    if (!_isExecutionMode)
                      TabBar(
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
                  ],
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: _isExecutionMode
                ? const SizedBox.shrink()
                : ProjectHeader(
                    project: activeProject,
                    progress: activeProject.progress,
                  ),
          ),
        ],
        // 👇 DASHBOARD SAAS CONNECTÉ ICI AVEC LE VRAI NOM DU PROJET 👇
        body: _isExecutionMode
            ? ExecutionDashboardFinal(
                projectCode: widget.projectCode,
                projectName: activeProject.name, // <- IMPORTANT: passe le vrai nom
              )
            : TabBarView(
                controller: _tabController,
                children: [
                  _OverviewTab(project: activeProject),
                  _AnalysesTab(projectCode: widget.projectCode),
                  _MemoryTab(projectCode: widget.projectCode),
                  _DocsTab(projectCode: widget.projectCode),
                ],
              ),
      ),
      bottomNavigationBar: _isExecutionMode
          ? null
          : AiCommandBar(
              onSubmit: _handleAiCommand,
              hintText: 'Demandez à THIX IA sur ${widget.projectCode}...',
              isLoading: _isSending,
            ),
    );
  }
}

// ============================================================
// TABS (ANALYSE)
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
            Text('Progression  ${(project.progress * 100).toInt()}%', style: ThixPolicy.labelStyle.copyWith(fontSize: 12)),
            const Spacer(),
            Text('${project.analysesCount} analyses  •  ${project.documentsCount} docs', style: ThixPolicy.microStyle),
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
      loading: () => const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator(color: ThixPolicy.primary, strokeWidth: 2.5))),
      error: (e, _) => ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Icon(Icons.error_outline_rounded, color: Colors.red, size: 36),
          const SizedBox(height: 10),
          Text('Erreur analyses', style: ThixPolicy.h3Style),
          const SizedBox(height: 6),
          Text('$e', style: ThixPolicy.bodySmallStyle),
          const SizedBox(height: 14),
          FilledButton(onPressed: () => ref.read(analysesProvider.notifier).refresh(), child: const Text('Réessayer')),
        ],
      ),
      data: (analyses) {
        if (analyses.isEmpty) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 100),
            children: [
              EmptyAnalyses(onStart: () => context.push(ThixIARoutes.analysisPath(projectCode))),
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

class _MemoryTab extends ConsumerStatefulWidget {
  const _MemoryTab({required this.projectCode});
  final String projectCode;

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
      _showSnack('Lance d\'abord au moins une analyse (marché, réglementation…)', isError: true);
      return;
    }

    setState(() => _isGenerating = true);

    try {
      final service = ref.read(documentGenerationServiceProvider);

      final pdfBytes = await service.generate(
        type: DocumentType.businessPlan,
        project: project,
        memory: memory,
        validatedAnalyses: validated,
      );

      if (!mounted) return;

      await _showPdfPreview(pdfBytes, project.projectCode);
      _showSnack('Business Plan généré avec succès');
    } catch (e) {
      _showSnack('Erreur génération : $e', isError: true);
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  Future<void> _showPdfPreview(Uint8List bytes, String projectCode) async {
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: ThixPolicy.border, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),
              const Icon(Icons.check_circle_rounded, color: ThixPolicy.success, size: 48),
              const SizedBox(height: 12),
              Text('Dossier final prêt', style: ThixPolicy.h3Style),
              const SizedBox(height: 8),
              Text('Business Plan généré à partir de ${ref.read(analysesProvider).value?.where((a) => a.isCompleted).length ?? 0} analyses + mémoire projet.', textAlign: TextAlign.center, style: ThixPolicy.bodySmallStyle),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _showSnack('Fonction téléchargement à brancher (share_plus / printing)');
                  },
                  icon: const Icon(Icons.download_rounded, size: 20),
                  label: const Text('Télécharger le PDF'),
                ),
              ),
              const SizedBox(height: 10),
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fermer')),
            ],
          ),
        );
      },
    );
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: isError ? Colors.red : null, behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(projectMemoryProvider);
    final analyses = ref.watch(analysesProvider).value ?? [];
    final completedCount = analyses.where((a) => a.isCompleted).length;

    return async.when(
      loading: () => const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator(color: ThixPolicy.primary, strokeWidth: 2.5))),
      error: (e, _) => ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Icon(Icons.error_outline_rounded, color: Colors.red, size: 36),
          const SizedBox(height: 10),
          Text('Erreur mémoire', style: ThixPolicy.h3Style),
          const SizedBox(height: 6),
          Text('$e', style: ThixPolicy.bodySmallStyle),
          const SizedBox(height: 14),
          FilledButton(onPressed: () => ref.read(projectMemoryProvider.notifier).refresh(), child: const Text('Réessayer')),
        ],
      ),
      data: (memory) {
        final facts = memory?.facts ?? [];

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [ThixPolicy.primary.withOpacity(0.08), ThixPolicy.primary.withOpacity(0.03)]),
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
                        decoration: BoxDecoration(color: ThixPolicy.primary.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                        child: const Icon(Icons.auto_awesome, color: ThixPolicy.primary, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Dossier final investisseur', style: ThixPolicy.bodyStyle.copyWith(fontWeight: FontWeight.w700)),
                            const SizedBox(height: 2),
                            Text('$completedCount analyses • ${facts.length} faits validés', style: ThixPolicy.captionStyle),
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
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.rocket_launch_rounded, size: 20),
                      label: Text(_isGenerating ? 'Génération en cours…' : 'Générer le Business Plan final', style: const TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('Collecte automatique de toutes les analyses + mémoire pour produire le vrai dossier final.', style: ThixPolicy.microStyle.copyWith(color: ThixPolicy.textMuted)),
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (facts.isEmpty)
              const EmptyFacts()
            else ...[
              Text('Faits en mémoire (${facts.length})', style: ThixPolicy.labelStyle.copyWith(fontSize: 13)),
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
    final docsAsync = ref.watch(documentsProvider);

    return docsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: ThixPolicy.primary)),
      error: (e, _) => Center(child: Text('Erreur : $e', style: const TextStyle(color: Colors.red))),
      data: (docs) {
        if (docs.isEmpty) return const Center(child: Text('Aucun document pour le moment.'));

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            return Card(child: ListTile(leading: const Icon(Icons.description_outlined), title: Text('Document ${index + 1}')));
          },
        );
      },
    );
  }
}
