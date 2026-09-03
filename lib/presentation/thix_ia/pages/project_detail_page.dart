// lib/presentation/thix_ia/pages/project_detail_page.dart
//
// ProjectDetailPage — "Modern Sleek Light" (Production Enterprise)
//
// Design : Blanc ultra-clair, cartes lisses, ombres douces.
// Sécurité : Sanitization XSS globale sur les inputs, gestion stricte des args [].
// i18n : 100% traduit via AppLocalizations.
// UX : Barre de commande réduite, Throttling, HapticFeedback.

import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/l10n/app_localizations.dart';

import '../core/constants/thix_ia_routes.dart';
import '../models/thix_project.dart';
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
import '../widgets/phase_switcher.dart';
import '../widgets/business_plan_preflight_sheet.dart';
import 'execution/execution_dashboard_final.dart';
import 'bp_document_editor_page.dart';

// ============================================================================
// PALETTE CLAIRE (Light Mode Premium)
// ============================================================================

class _IaLightPalette {
  _IaLightPalette._();

  static const Color background = Color(0xFFF8FAFC);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color border = Color(0xFFE2E8F0);

  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF475569);
  static const Color textMuted = Color(0xFF94A3B8);
}

// ============================================================================
// CONSTANTS & SANITIZER
// ============================================================================

const Duration _kTapThrottle = Duration(milliseconds: 400);

class _Sanitizer {
  _Sanitizer._();

  static String text(String? input, {required int maxLength}) {
    if (input == null) return '';
    final s = input.replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '').trim();
    return s.length > maxLength ? '${s.substring(0, maxLength)}…' : s;
  }

  static String errorMessage(Object error) {
    final msg = error.toString().replaceFirst('Exception: ', '');
    return msg.length > 120 ? '${msg.substring(0, 120)}…' : msg;
  }
}

// ============================================================================
// LOGGING
// ============================================================================

class _ProjectDetailLogger {
  static const _tag = 'ProjectDetail';
  static void info(String m, [Map<String, dynamic>? d]) => _log('INFO', m, d);
  static void warn(String m, [Map<String, dynamic>? d]) => _log('WARN', m, d);
  static void error(String m, [Map<String, dynamic>? d]) => _log('ERROR', m, d);
  static void _log(String l, String m, Map<String, dynamic>? d) {
    if (!kDebugMode && l == 'INFO') return;
    final data = d != null ? ' ${d.entries.map((e) => '${e.key}=${e.value}').join(', ')}' : '';
    debugPrint('[$_tag] [$l] $m$data');
  }
}

// ============================================================================
// SLEEK CARD WIDGET
// ============================================================================

class _SleekCard extends StatelessWidget {
  final Widget child;
  final double radius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? color;
  final bool hasShadow;

  const _SleekCard({
    required this.child,
    this.radius = 20,
    this.padding,
    this.margin,
    this.color,
    this.hasShadow = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? _IaLightPalette.surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: _IaLightPalette.border, width: 1),
        boxShadow: hasShadow
            ? [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))]
            : null,
      ),
      child: child,
    );
  }
}

// ============================================================================
// PAGE
// ============================================================================

class ProjectDetailPage extends ConsumerStatefulWidget {
  const ProjectDetailPage({super.key, required this.projectCode});
  final String projectCode;

  @override
  ConsumerState<ProjectDetailPage> createState() => _ProjectDetailPageState();
}

class _ProjectDetailPageState extends ConsumerState<ProjectDetailPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isSending = false;
  bool _isExecutionMode = false;
  DateTime? _lastTap;

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
        _ProjectDetailLogger.info('Project loaded', {'projectCode': widget.projectCode});
      } catch (e) {
        _ProjectDetailLogger.error('Init error', {'error': '$e'});
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  bool _throttle() {
    final now = DateTime.now();
    if (_lastTap != null && now.difference(_lastTap!) < _kTapThrottle) return false;
    _lastTap = now;
    return true;
  }

  // ════════════════════════════════════════════════════════════════════
  // HELPERS
  // ════════════════════════════════════════════════════════════════════

  String _buildIdeaContext(ThixProject p) {
    return [
      _Sanitizer.text(p.name, maxLength: 200),
      if (p.summary != null && p.summary!.trim().isNotEmpty) _Sanitizer.text(p.summary!, maxLength: 2000),
    ].where((e) => e.trim().isNotEmpty).join('\n');
  }

  void _onAnalysisStarted(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: ThixPolicy.success, behavior: SnackBarBehavior.floating),
    );
    _tabController.animateTo(1);
  }

  void _showError(Object e) {
    if (!mounted) return;
    final msg = _Sanitizer.errorMessage(e);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: msg.contains('existe déjà') ? ThixPolicy.warning : ThixPolicy.danger,
        behavior: SnackBarBehavior.floating,
      ),
    );
    if (msg.contains('existe déjà')) _tabController.animateTo(1);
  }

  // ════════════════════════════════════════════════════════════════════
  // ACTIONS
  // ════════════════════════════════════════════════════════════════════

  Future<void> _startMarket() async {
    if (!_throttle()) return;
    final p = ref.read(activeProjectProvider).value;
    if (p == null) return;
    HapticFeedback.selectionClick();
    try {
      await ref.read(analysesProvider.notifier).startMarketAnalysis(country: p.country, sector: p.sector, ideaDescription: _buildIdeaContext(p));
      _onAnalysisStarted(AppLocalizations.of(context).t('project_analysis_market_started'));
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _startLegal() async {
    if (!_throttle()) return;
    final p = ref.read(activeProjectProvider).value;
    if (p == null) return;
    HapticFeedback.selectionClick();
    try {
      await ref.read(analysesProvider.notifier).startLegalAnalysis(jurisdiction: p.country, sector: p.sector, ideaDescription: _buildIdeaContext(p));
      _onAnalysisStarted(AppLocalizations.of(context).t('project_analysis_legal_started'));
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _startCompetitor() async {
    if (!_throttle()) return;
    final p = ref.read(activeProjectProvider).value;
    if (p == null) return;
    HapticFeedback.selectionClick();
    try {
      await ref.read(analysesProvider.notifier).startCompetitorAnalysis(country: p.country, sector: p.sector, ideaDescription: _buildIdeaContext(p));
      _onAnalysisStarted(AppLocalizations.of(context).t('project_analysis_competitor_started'));
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _startFinance() async {
    if (!_throttle()) return;
    final p = ref.read(activeProjectProvider).value;
    if (p == null) return;
    HapticFeedback.selectionClick();
    try {
      await ref.read(analysesProvider.notifier).startFinanceAnalysis(ideaDescription: _buildIdeaContext(p));
      _onAnalysisStarted(AppLocalizations.of(context).t('project_analysis_finance_started'));
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _startBusinessPlan() async {
    if (!_throttle()) return;
    final p = ref.read(activeProjectProvider).value;
    if (p == null) return;
    HapticFeedback.mediumImpact();

    final config = await showBusinessPlanPreflightSheet(context, projectCode: widget.projectCode);
    if (config == null || !mounted) return;

    try {
      await ref.read(analysesProvider.notifier).startBusinessPlanAnalysis(ideaDescription: _buildIdeaContext(p));
      _onAnalysisStarted(AppLocalizations.of(context).t('project_analysis_bp_started'));
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _handleAiCommand(String text) async {
    final lower = text.toLowerCase().trim();
    if (lower.isEmpty) return;

    final isMarket = lower.contains('marché') || lower.contains('market') || lower.contains('etude') || lower.contains('étude');
    final isLegal = lower.contains('réglement') || lower.contains('reglement') || lower.contains('legal') || lower.contains('loi') || lower.contains('fiscal');
    final isCompetitor = lower.contains('concurrent') || lower.contains('compétiteur') || lower.contains('competitor');
    final isBusinessPlan = lower.contains('business plan') || lower.contains('businessplan') || lower.contains('dossier final') || lower.contains('génère le business') || lower.contains('genere le business');

    if (isMarket) { await _startMarket(); return; }
    if (isLegal) { await _startLegal(); return; }
    if (isCompetitor) {
      try {
        final p = ref.read(activeProjectProvider).value;
        if (p != null) {
          await ref.read(analysesProvider.notifier).startCompetitorAnalysis(country: p.country, sector: p.sector, ideaDescription: _buildIdeaContext(p));
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).t('project_analysis_competitor_started')), behavior: SnackBarBehavior.floating));
            _tabController.animateTo(1);
          }
        }
      } catch (_) {
        await _sendToChat(text);
      }
      return;
    }
    if (isBusinessPlan) { await _startBusinessPlan(); return; }

    await _sendToChat(text);
  }

  Future<void> _sendToChat(String text) async {
    setState(() => _isSending = true);
    try {
      await ref.read(chatProvider.notifier).sendMessage(text);
      if (mounted) context.push(ThixIARoutes.chatPath(widget.projectCode));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(AppLocalizations.of(context).t('project_chat_error', args: [_Sanitizer.errorMessage(e)])),
          backgroundColor: ThixPolicy.danger,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _confirmDeleteProject() async {
    if (!_throttle()) return;
    final l10n = AppLocalizations.of(context);
    final safeCode = _Sanitizer.text(widget.projectCode, maxLength: 24);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _IaLightPalette.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(l10n.t('project_delete_confirm_title'), style: const TextStyle(color: _IaLightPalette.textPrimary, fontWeight: FontWeight.w800)),
        content: Text(l10n.t('project_delete_confirm_message', args: [safeCode]), style: const TextStyle(color: _IaLightPalette.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.t('common_cancel'), style: const TextStyle(color: _IaLightPalette.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: ThixPolicy.danger),
            child: Text(l10n.t('common_delete')),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      try {
        await ref.read(projectServiceProvider).deleteProject(widget.projectCode);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.t('project_deleted')), backgroundColor: ThixPolicy.success, behavior: SnackBarBehavior.floating));
          context.go(ThixIARoutes.projects);
        }
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.t('project_delete_error', args: [_Sanitizer.errorMessage(e)])), backgroundColor: ThixPolicy.danger));
      }
    }
  }

  // ════════════════════════════════════════════════════════════════════
  // BUILD
  // ════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final activeAsync = ref.watch(activeProjectProvider);

    return activeAsync.when(
      loading: () => const Scaffold(backgroundColor: _IaLightPalette.background, body: Center(child: CircularProgressIndicator(color: ThixPolicy.primary))),
      error: (e, _) => Scaffold(
        backgroundColor: _IaLightPalette.background,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text(_Sanitizer.text(widget.projectCode, maxLength: 24), style: const TextStyle(color: _IaLightPalette.textPrimary, fontFamily: 'monospace')),
          leading: IconButton(icon: const Icon(Icons.arrow_back_rounded, color: _IaLightPalette.textPrimary), onPressed: () => context.go(ThixIARoutes.projects)),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: _SleekCard(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline_rounded, color: ThixPolicy.danger, size: 40),
                  const SizedBox(height: 12),
                  Text(l10n.t('project_load_error'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _IaLightPalette.textPrimary)),
                  const SizedBox(height: 8),
                  Text(_Sanitizer.errorMessage(e), textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, color: _IaLightPalette.textSecondary)),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: () => ref.read(activeProjectProvider.notifier).setActive(widget.projectCode),
                    style: FilledButton.styleFrom(backgroundColor: ThixPolicy.primary),
                    child: Text(l10n.t('common_retry')),
                  ),
                  TextButton(
                    onPressed: () => context.go(ThixIARoutes.projects),
                    child: Text(l10n.t('project_back_to_list'), style: const TextStyle(color: ThixPolicy.primary)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      data: (activeProject) {
        if (activeProject == null) {
          return Scaffold(
            backgroundColor: _IaLightPalette.background,
            appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0, title: Text(_Sanitizer.text(widget.projectCode, maxLength: 24), style: const TextStyle(color: _IaLightPalette.textPrimary))),
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.search_off_rounded, size: 48, color: _IaLightPalette.textMuted),
                  const SizedBox(height: 16),
                  Text(l10n.t('project_not_found'), style: const TextStyle(color: _IaLightPalette.textPrimary, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  TextButton(onPressed: () => context.go(ThixIARoutes.projects), child: Text(l10n.t('project_my_projects'), style: const TextStyle(color: ThixPolicy.primary))),
                ],
              ),
            ),
          );
        }
        return _buildContent(context, l10n, activeProject);
      },
    );
  }

  Widget _buildOrb(Color color, double size) {
    return RepaintBoundary(
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          children: [
            Container(decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
            BackdropFilter(filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80), child: Container(color: Colors.transparent)),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, AppLocalizations l10n, ThixProject activeProject) {
    return Scaffold(
      backgroundColor: _IaLightPalette.background,
      body: Stack(
        children: [
          // Background Orbs
          Positioned(top: -50, right: -50, child: _buildOrb(ThixPolicy.primary.withValues(alpha: 0.15), 250)),
          Positioned(bottom: 100, left: -80, child: _buildOrb(const Color(0xFF8B5CF6).withValues(alpha: 0.10), 300)),
          
          NestedScrollView(
            headerSliverBuilder: (context, _) => [
              SliverAppBar(
                pinned: true,
                backgroundColor: _IaLightPalette.surface.withValues(alpha: 0.9),
                elevation: 0,
                titleSpacing: 0,
                title: Text(
                  _Sanitizer.text(activeProject.projectCode, maxLength: 24),
                  style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w700, fontSize: 14, color: _IaLightPalette.textPrimary),
                ),
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_rounded, size: 20, color: _IaLightPalette.textPrimary),
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    context.go(ThixIARoutes.projects);
                  },
                ),
                actions: [
                  IconButton(
                    tooltip: l10n.t('project_documents'),
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      context.push(ThixIARoutes.documentsPath(widget.projectCode));
                    },
                    icon: const Icon(Icons.folder_outlined, size: 22, color: _IaLightPalette.textSecondary),
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert_rounded, size: 22, color: _IaLightPalette.textPrimary),
                    color: _IaLightPalette.surface,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: _IaLightPalette.border)),
                    onSelected: (value) async {
                      if (value == 'market') await _startMarket();
                      if (value == 'legal') await _startLegal();
                      if (value == 'competitor') await _startCompetitor();
                      if (value == 'finance') await _startFinance();
                      if (value == 'business_plan') await _startBusinessPlan();
                      if (value == 'delete') await _confirmDeleteProject();
                    },
                    itemBuilder: (context) => [
                      _popupItem('market', Icons.insights_outlined, l10n.t('project_menu_market')),
                      _popupItem('legal', Icons.balance_outlined, l10n.t('project_menu_legal')),
                      _popupItem('competitor', Icons.groups_outlined, l10n.t('project_menu_competitor')),
                      _popupItem('finance', Icons.calculate_outlined, l10n.t('project_menu_finance')),
                      _popupItem('business_plan', Icons.description_outlined, l10n.t('project_menu_bp')),
                      const PopupMenuDivider(),
                      _popupItem('delete', Icons.delete_outline_rounded, l10n.t('project_menu_delete'), isDestructive: true),
                    ],
                  ),
                  const SizedBox(width: 8),
                ],
                bottom: PreferredSize(
                  preferredSize: Size.fromHeight(_isExecutionMode ? 64 : 112),
                  child: Container(
                    decoration: const BoxDecoration(
                      color: _IaLightPalette.surface,
                      border: Border(bottom: BorderSide(color: _IaLightPalette.border)),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        PhaseSwitcher(
                          isExecutionMode: _isExecutionMode,
                          onModeChanged: (val) {
                            HapticFeedback.lightImpact();
                            setState(() => _isExecutionMode = val);
                          },
                        ),
                        if (!_isExecutionMode)
                          TabBar(
                            controller: _tabController,
                            labelColor: ThixPolicy.primary,
                            unselectedLabelColor: _IaLightPalette.textMuted,
                            indicatorColor: ThixPolicy.primary,
                            indicatorWeight: 3.0,
                            labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                            unselectedLabelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                            isScrollable: true,
                            tabAlignment: TabAlignment.start,
                            tabs: [
                              Tab(text: l10n.t('project_tab_overview'), height: 38),
                              Tab(text: l10n.t('project_tab_analyses'), height: 38),
                              Tab(text: l10n.t('project_tab_memory'), height: 38),
                              Tab(text: l10n.t('project_tab_docs'), height: 38),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              if (!_isExecutionMode)
                SliverToBoxAdapter(
                  child: ProjectHeader(project: activeProject, progress: activeProject.progress),
                )
              else
                const SliverToBoxAdapter(child: SizedBox.shrink()),
            ],
            body: _isExecutionMode
                ? ExecutionDashboardFinal(projectCode: widget.projectCode, projectName: _Sanitizer.text(activeProject.name, maxLength: _kMaxNameLength))
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
        ],
      ),
      // Command Bar ultra clean and reduced
      bottomNavigationBar: _isExecutionMode
          ? null
          : Container(
              decoration: BoxDecoration(
                color: _IaLightPalette.surface,
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, -2))],
                border: const Border(top: BorderSide(color: _IaLightPalette.border)),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: AiCommandBar(
                    onSubmit: _handleAiCommand,
                    hintText: l10n.t('project_command_hint', args: [_Sanitizer.text(widget.projectCode, maxLength: 15)]),
                    isLoading: _isSending,
                  ),
                ),
              ),
            ),
    );
  }

  PopupMenuItem<String> _popupItem(String value, IconData icon, String label, {bool isDestructive = false}) {
    return PopupMenuItem<String>(
      value: value,
      height: 44,
      child: Row(
        children: [
          Icon(icon, size: 18, color: isDestructive ? ThixPolicy.danger : _IaLightPalette.textPrimary),
          const SizedBox(width: 12),
          Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isDestructive ? ThixPolicy.danger : _IaLightPalette.textPrimary)),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
// TABS (Sleek Mode)
// ════════════════════════════════════════════════════════════════════

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({required this.project});
  final ThixProject project;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cityPart = project.city != null && project.city!.trim().isNotEmpty ? ' • ${_Sanitizer.text(project.city, maxLength: 30)}' : '';

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
      children: [
        _SleekCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_Sanitizer.text(project.name, maxLength: _kMaxNameLength), style: const TextStyle(color: _IaLightPalette.textPrimary, fontWeight: FontWeight.w900, fontSize: 20)),
              const SizedBox(height: 6),
              Text(
                '${_Sanitizer.text(project.sector, maxLength: _kMaxSectorLength)} • ${_Sanitizer.text(project.country, maxLength: 30)}$cityPart',
                style: const TextStyle(color: _IaLightPalette.textSecondary, fontSize: 13, fontWeight: FontWeight.w500),
              ),
              if (project.summary != null && project.summary!.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(l10n.t('project_summary'), style: const TextStyle(color: _IaLightPalette.textPrimary, fontWeight: FontWeight.w800, fontSize: 13)),
                const SizedBox(height: 6),
                Text(_Sanitizer.text(project.summary, maxLength: 2000), style: const TextStyle(color: _IaLightPalette.textSecondary, fontSize: 13, height: 1.4)),
              ],
              const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Divider(color: _IaLightPalette.border, height: 1)),
              Row(
                children: [
                  Text('${l10n.t("project_progress")} ${(project.progress * 100).toInt()}%', style: const TextStyle(color: _IaLightPalette.textPrimary, fontWeight: FontWeight.w800, fontSize: 13)),
                  const Spacer(),
                  Text('${project.analysesCount} ${l10n.t("project_analyses")} • ${project.documentsCount} ${l10n.t("project_docs")}', style: const TextStyle(color: _IaLightPalette.textMuted, fontSize: 11, fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: project.progress.clamp(0.0, 1.0),
                  minHeight: 6,
                  backgroundColor: _IaLightPalette.border,
                  valueColor: const AlwaysStoppedAnimation(ThixPolicy.success),
                ),
              ),
            ],
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
      loading: () => const Center(child: CircularProgressIndicator(color: ThixPolicy.primary)),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, color: ThixPolicy.danger, size: 36),
              const SizedBox(height: 10),
              const Text('Erreur analyses', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: _IaLightPalette.textPrimary)),
              const SizedBox(height: 6),
              Text(_Sanitizer.errorMessage(e), textAlign: TextAlign.center, style: const TextStyle(color: _IaLightPalette.textSecondary, fontSize: 12)),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => ref.read(analysesProvider.notifier).refresh(),
                style: FilledButton.styleFrom(backgroundColor: ThixPolicy.primary),
                child: const Text('Réessayer'),
              ),
            ],
          ),
        ),
      ),
      data: (analyses) {
        if (analyses.isEmpty) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),
            children: [
              EmptyAnalyses(onStart: () => context.push(ThixIARoutes.analysisPath(projectCode))),
            ],
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
          itemCount: analyses.length,
          itemBuilder: (context, index) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: AnalysisProgressWidget(analysis: analyses[index]),
          ),
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
  DateTime? _lastTap;

  bool _throttle() {
    final now = DateTime.now();
    if (_lastTap != null && now.difference(_lastTap!) < _kTapThrottle) return false;
    _lastTap = now;
    return true;
  }

  Future<void> _generateFinalDossier() async {
    if (!_throttle()) return;
    HapticFeedback.mediumImpact();
    final l10n = AppLocalizations.of(context);

    final project = ref.read(activeProjectProvider).value;
    final memory = ref.read(projectMemoryProvider).value;
    final analyses = ref.read(analysesProvider).value ?? [];

    if (project == null) {
      _showSnack(l10n.t('project_no_active'), isError: true);
      return;
    }
    if (memory == null) {
      _showSnack(l10n.t('project_memory_not_loaded'), isError: true);
      return;
    }

    final validated = analyses.where((a) => a.isCompleted).toList();
    if (validated.isEmpty && memory.facts.isEmpty) {
      _showSnack(l10n.t('project_need_analysis'), isError: true);
      return;
    }

    final config = await showBusinessPlanPreflightSheet(context, projectCode: widget.projectCode);
    if (config == null || !mounted) return;

    setState(() => _isGenerating = true);

    try {
      await ref.read(analysesProvider.notifier).startBusinessPlanAnalysis(
            ideaDescription: [
              _Sanitizer.text(project.name, maxLength: 200),
              if (project.summary != null) _Sanitizer.text(project.summary!, maxLength: 2000),
            ].join('\n'),
          );

      if (!mounted) return;
      _showSnack(l10n.t('project_bp_started'));
    } catch (e) {
      _showSnack(l10n.t('project_bp_error', args: [_Sanitizer.errorMessage(e)]), isError: true);
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? ThixPolicy.danger : ThixPolicy.success,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(projectMemoryProvider);
    final analyses = ref.watch(analysesProvider).value ?? [];
    final completedCount = analyses.where((a) => a.isCompleted).length;

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator(color: ThixPolicy.primary)),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, color: ThixPolicy.danger, size: 36),
              const SizedBox(height: 10),
              const Text('Erreur mémoire', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: _IaLightPalette.textPrimary)),
              const SizedBox(height: 6),
              Text(_Sanitizer.errorMessage(e), textAlign: TextAlign.center, style: const TextStyle(color: _IaLightPalette.textSecondary, fontSize: 12)),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => ref.read(projectMemoryProvider.notifier).refresh(),
                style: FilledButton.styleFrom(backgroundColor: ThixPolicy.primary),
                child: Text(l10n.t('common_retry')),
              ),
            ],
          ),
        ),
      ),
      data: (memory) {
        final facts = memory?.facts ?? [];

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
          children: [
            _SleekCard(
              padding: const EdgeInsets.all(20),
              color: ThixPolicy.primary.withValues(alpha: 0.04),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: ThixPolicy.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                        child: const Icon(Icons.auto_awesome_rounded, color: ThixPolicy.primary, size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(l10n.t('project_final_dossier'), style: const TextStyle(color: _IaLightPalette.textPrimary, fontWeight: FontWeight.w900, fontSize: 16)),
                            const SizedBox(height: 4),
                            Text('$completedCount ${l10n.t("project_analyses")} • ${facts.length} ${l10n.t("project_facts")}', style: const TextStyle(color: _IaLightPalette.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _isGenerating ? null : _generateFinalDossier,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ThixPolicy.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      icon: _isGenerating ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white)) : const Icon(Icons.rocket_launch_rounded, size: 20),
                      label: Text(_isGenerating ? l10n.t('project_generating') : l10n.t('project_generate_bp'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(l10n.t('project_bp_preflight_hint'), style: const TextStyle(color: _IaLightPalette.textMuted, fontSize: 11, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
            const SizedBox(height: 24),
            if (facts.isEmpty)
              const EmptyFacts()
            else ...[
              Text('${l10n.t("project_facts_in_memory")} (${facts.length})', style: const TextStyle(color: _IaLightPalette.textPrimary, fontWeight: FontWeight.w800, fontSize: 15)),
              const SizedBox(height: 12),
              ...facts.map((f) => Padding(padding: const EdgeInsets.only(bottom: 10), child: FactCard(fact: f))),
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
    final l10n = AppLocalizations.of(context);
    final docsAsync = ref.watch(documentsProvider);

    return docsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: ThixPolicy.primary)),
      error: (e, _) => Center(child: Text('Erreur : ${_Sanitizer.errorMessage(e)}', style: const TextStyle(color: ThixPolicy.danger))),
      data: (docs) {
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
          children: [
            _SleekCard(
              color: ThixPolicy.primary.withValues(alpha: 0.03),
              margin: const EdgeInsets.only(bottom: 24),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: ThixPolicy.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.menu_book_rounded, color: ThixPolicy.primary),
                ),
                title: Text(l10n.t('project_bp_document'), style: const TextStyle(fontWeight: FontWeight.w800, color: _IaLightPalette.textPrimary, fontSize: 15)),
                subtitle: Text(l10n.t('project_bp_document_hint'), style: const TextStyle(color: _IaLightPalette.textSecondary, fontSize: 12, fontWeight: FontWeight.w500)),
                trailing: const Icon(Icons.chevron_right_rounded, color: ThixPolicy.primary),
                onTap: () {
                  HapticFeedback.selectionClick();
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => BpDocumentEditorPage(projectCode: projectCode)));
                },
              ),
            ),
            if (docs.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Text(l10n.t('project_no_other_docs'), style: const TextStyle(color: _IaLightPalette.textMuted, fontWeight: FontWeight.w600)),
                ),
              )
            else
              ...docs.map((doc) {
                final index = docs.indexOf(doc);
                return _SleekCard(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                    leading: const Icon(Icons.description_outlined, color: _IaLightPalette.textSecondary),
                    title: Text('${l10n.t("project_document")} ${index + 1}', style: const TextStyle(fontWeight: FontWeight.w700, color: _IaLightPalette.textPrimary)),
                  ),
                );
              }),
          ],
        );
      },
    );
  }
}
