// lib/presentation/thix_ia/pages/project_detail_page.dart
//
// ProjectDetailPage — "Monochrome Glass" (Production Enterprise)
//
// Design : 2 couleurs uniquement (blanc #FFF + encre #0B1220)
// Glassmorphism pur, logique 100% préservée.
//
// CHANGEMENTS :
// - Barre de chat supprimée (AiCommandBar)
// - Design monochrome glass cohérent
// - i18n complet (FR/EN/SW/LN)
// - Semantics + HapticFeedback + logs structurés
// - Throttling sur toutes les actions
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
import '../widgets/project_header.dart';
import '../widgets/fact_card.dart';
import '../widgets/analysis_progress_widget.dart';
import '../widgets/empty_state_widget.dart';
import '../widgets/phase_switcher.dart';
import '../widgets/business_plan_preflight_sheet.dart';
import 'execution/execution_dashboard_final.dart';
import 'bp_document_editor_page.dart';

// ============================================================================
// PALETTE MONOCHROME
// ============================================================================

class _IaPalette {
  _IaPalette._();

  static const Color ink = Color(0xFF0B1220);
  static const Color white = Color(0xFFFFFFFF);

  static Color get glassStrong => white.withValues(alpha: 0.14);
  static Color get glass => white.withValues(alpha: 0.08);
  static Color get glassSoft => white.withValues(alpha: 0.05);
  static Color get glassBorder => white.withValues(alpha: 0.16);
  static Color get glassBorderSoft => white.withValues(alpha: 0.10);

  static Color get textPrimary => white;
  static Color get textSecondary => white.withValues(alpha: 0.62);
  static Color get textMuted => white.withValues(alpha: 0.40);
}

// ============================================================================
// CONSTANTS
// ============================================================================

const double _kGlassBlur = kIsWeb ? 8 : 14;
const double _kOrbBlur = kIsWeb ? 40 : 70;
const Duration _kTapThrottle = Duration(milliseconds: 400);

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
    final data = d != null
        ? ' ${d.entries.map((e) => '${e.key}=${e.value}').join(', ')}'
        : '';
    debugPrint('[$_tag] [$l] $m$data');
  }
}

// ============================================================================
// GLASS SURFACE
// ============================================================================

class _Glass extends StatelessWidget {
  final Widget child;
  final double radius;
  final double alpha;
  final double blur;
  final EdgeInsetsGeometry? padding;
  final bool bordered;

  const _Glass({
    required this.child,
    this.radius = 24,
    this.alpha = 0.08,
    this.blur = _kGlassBlur,
    this.padding,
    this.bordered = true,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: _IaPalette.white.withValues(alpha: alpha),
            borderRadius: BorderRadius.circular(radius),
            border: bordered
                ? Border.all(color: _IaPalette.glassBorderSoft, width: 1)
                : null,
          ),
          child: child,
        ),
      ),
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

class _ProjectDetailPageState extends ConsumerState<ProjectDetailPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isExecutionMode = false;
  DateTime? _lastTap;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    Future.microtask(() async {
      try {
        await ref
            .read(activeProjectProvider.notifier)
            .setActive(widget.projectCode);
        ref.invalidate(analysesProvider);
        ref.invalidate(projectMemoryProvider);
        ref.invalidate(documentsProvider);
        await Future.wait([
          ref.read(analysesProvider.notifier).refresh(),
          ref.read(projectMemoryProvider.notifier).refresh(),
          ref.read(documentsProvider.notifier).refresh(),
        ]);
        _ProjectDetailLogger.info('Project loaded',
            {'projectCode': widget.projectCode});
      } catch (e) {
        _ProjectDetailLogger.error('Init failed', {'error': '$e'});
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _ProjectDetailLogger.info('Page disposed');
    super.dispose();
  }

  bool _throttle() {
    final now = DateTime.now();
    if (_lastTap != null && now.difference(_lastTap!) < _kTapThrottle) {
      _ProjectDetailLogger.warn('Tap throttled');
      return false;
    }
    _lastTap = now;
    return true;
  }

  // ════════════════════════════════════════════════════════════════════
  // HELPERS
  // ════════════════════════════════════════════════════════════════════

  String _buildIdeaContext(ThixProject p) {
    return [
      p.name,
      if (p.summary != null && p.summary!.trim().isNotEmpty) p.summary!,
    ].where((e) => e.trim().isNotEmpty).join('\n');
  }

  void _onAnalysisStarted(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: _IaPalette.white,
      behavior: SnackBarBehavior.floating,
    ));
    _tabController.animateTo(1);
  }

  void _showError(Object e) {
    if (!mounted) return;
    final msg = e.toString().replaceFirst('Exception: ', '');
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(color: _IaPalette.white)),
      backgroundColor: _IaPalette.ink,
      behavior: SnackBarBehavior.floating,
    ));
    if (msg.contains('existe déjà')) {
      _tabController.animateTo(1);
    }
  }

  // ════════════════════════════════════════════════════════════════════
  // LANCEMENT DES ANALYSES
  // ════════════════════════════════════════════════════════════════════

  Future<void> _startMarket() async {
    if (!_throttle()) return;
    HapticFeedback.selectionClick();
    final p = ref.read(activeProjectProvider).value;
    if (p == null) return;
    _ProjectDetailLogger.info('Market analysis started');
    try {
      await ref.read(analysesProvider.notifier).startMarketAnalysis(
            country: p.country,
            sector: p.sector,
            ideaDescription: _buildIdeaContext(p),
          );
      final l10n = AppLocalizations.of(context);
      _onAnalysisStarted(l10n.t('project_analysis_market_started'));
    } catch (e) {
      _ProjectDetailLogger.error('Market analysis failed', {'error': '$e'});
      _showError(e);
    }
  }

  Future<void> _startLegal() async {
    if (!_throttle()) return;
    HapticFeedback.selectionClick();
    final p = ref.read(activeProjectProvider).value;
    if (p == null) return;
    _ProjectDetailLogger.info('Legal analysis started');
    try {
      await ref.read(analysesProvider.notifier).startLegalAnalysis(
            jurisdiction: p.country,
            sector: p.sector,
            ideaDescription: _buildIdeaContext(p),
          );
      final l10n = AppLocalizations.of(context);
      _onAnalysisStarted(l10n.t('project_analysis_legal_started'));
    } catch (e) {
      _ProjectDetailLogger.error('Legal analysis failed', {'error': '$e'});
      _showError(e);
    }
  }

  Future<void> _startCompetitor() async {
    if (!_throttle()) return;
    HapticFeedback.selectionClick();
    final p = ref.read(activeProjectProvider).value;
    if (p == null) return;
    _ProjectDetailLogger.info('Competitor analysis started');
    try {
      await ref.read(analysesProvider.notifier).startCompetitorAnalysis(
            country: p.country,
            sector: p.sector,
            ideaDescription: _buildIdeaContext(p),
          );
      final l10n = AppLocalizations.of(context);
      _onAnalysisStarted(l10n.t('project_analysis_competitor_started'));
    } catch (e) {
      _ProjectDetailLogger.error('Competitor analysis failed',
          {'error': '$e'});
      _showError(e);
    }
  }

  Future<void> _startFinance() async {
    if (!_throttle()) return;
    HapticFeedback.selectionClick();
    final p = ref.read(activeProjectProvider).value;
    if (p == null) return;
    _ProjectDetailLogger.info('Finance analysis started');
    try {
      await ref.read(analysesProvider.notifier).startFinanceAnalysis(
            ideaDescription: _buildIdeaContext(p),
          );
      final l10n = AppLocalizations.of(context);
      _onAnalysisStarted(l10n.t('project_analysis_finance_started'));
    } catch (e) {
      _ProjectDetailLogger.error('Finance analysis failed', {'error': '$e'});
      _showError(e);
    }
  }

  Future<void> _startBusinessPlan() async {
    if (!_throttle()) return;
    HapticFeedback.mediumImpact();
    final p = ref.read(activeProjectProvider).value;
    if (p == null) return;

    final config = await showBusinessPlanPreflightSheet(
      context,
      projectCode: widget.projectCode,
    );
    if (config == null || !mounted) return;

    _ProjectDetailLogger.info('Business plan started');
    try {
      await ref.read(analysesProvider.notifier).startBusinessPlanAnalysis(
            ideaDescription: _buildIdeaContext(p),
          );
      final l10n = AppLocalizations.of(context);
      _onAnalysisStarted(l10n.t('project_analysis_bp_started'));
    } catch (e) {
      _ProjectDetailLogger.error('Business plan failed', {'error': '$e'});
      _showError(e);
    }
  }

  Future<void> _confirmDeleteProject() async {
    if (!_throttle()) return;
    final l10n = AppLocalizations.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _IaPalette.ink,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: _IaPalette.glassBorder),
        ),
        title: Text(l10n.t('project_delete_confirm_title'),
            style: TextStyle(
                color: _IaPalette.textPrimary, fontWeight: FontWeight.w800)),
        content: Text(
          l10n.t('project_delete_confirm_message',
              args: [widget.projectCode]), // CORRECTION APPLIQUÉE ICI
          style: TextStyle(color: _IaPalette.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.t('common_cancel'),
                style: TextStyle(color: _IaPalette.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.t('common_delete'),
                style: TextStyle(color: _IaPalette.textPrimary)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      _ProjectDetailLogger.info('Project deleted',
          {'projectCode': widget.projectCode});
      try {
        await ref.read(projectServiceProvider).deleteProject(widget.projectCode);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(l10n.t('project_deleted')),
            backgroundColor: _IaPalette.white,
            behavior: SnackBarBehavior.floating,
          ));
          context.go(ThixIARoutes.projects);
        }
      } catch (e) {
        _ProjectDetailLogger.error('Delete failed', {'error': '$e'});
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(l10n.t('project_delete_error',
                args: ['$e'])), // CORRECTION APPLIQUÉE ICI
            backgroundColor: _IaPalette.ink,
            behavior: SnackBarBehavior.floating,
          ));
        }
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

    return Scaffold(
      backgroundColor: _IaPalette.ink,
      body: Stack(
        children: [
          // Orbes monochromes
          Positioned(
              top: -60,
              right: -110,
              child: _buildOrb(_IaPalette.white.withValues(alpha: 0.10), 340)),
          Positioned(
              bottom: 180,
              left: -120,
              child: _buildOrb(_IaPalette.white.withValues(alpha: 0.07), 300)),

          activeAsync.when(
            loading: () => _LoadingState(),
            error: (e, _) => _ErrorState(
              projectCode: widget.projectCode,
              error: '$e',
              onRetry: () => ref
                  .read(activeProjectProvider.notifier)
                  .setActive(widget.projectCode),
              onBack: () => context.go(ThixIARoutes.projects),
            ),
            data: (activeProject) {
              if (activeProject == null) {
                return _ProjectNotFoundState(
                  projectCode: widget.projectCode,
                  onBack: () => context.go(ThixIARoutes.projects),
                );
              }
              return _buildContent(context, l10n, activeProject);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildOrb(Color color, double size) {
    return RepaintBoundary(
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          children: [
            Container(
              decoration: BoxDecoration(shape: BoxShape.circle, color: color),
            ),
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: _kOrbBlur, sigmaY: _kOrbBlur),
              child: Container(color: Colors.transparent),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(
      BuildContext context, AppLocalizations l10n, ThixProject activeProject) {
    return NestedScrollView(
      headerSliverBuilder: (context, _) => [
        SliverAppBar(
          pinned: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          titleSpacing: 0,
          flexibleSpace: ClipRRect(
            child: BackdropFilter(
              filter:
                  ImageFilter.blur(sigmaX: _kGlassBlur, sigmaY: _kGlassBlur),
              child: Container(
                color: _IaPalette.ink.withValues(alpha: 0.55),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: _IaPalette.glassBorderSoft),
                  ),
                ),
              ),
            ),
          ),
          leading: Semantics(
            button: true,
            label: l10n.t('common_back'),
            child: IconButton(
              icon: Icon(Icons.arrow_back_ios_rounded,
                  color: _IaPalette.textPrimary),
              onPressed: () {
                HapticFeedback.selectionClick();
                context.go(ThixIARoutes.projects);
              },
            ),
          ),
          title: Text(
            activeProject.projectCode,
            style: TextStyle(
              color: _IaPalette.textPrimary,
              fontFamily: 'monospace',
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          actions: [
            Semantics(
              button: true,
              label: l10n.t('project_documents'),
              child: IconButton(
                tooltip: l10n.t('project_documents'),
                onPressed: () {
                  HapticFeedback.selectionClick();
                  context.push(ThixIARoutes.documentsPath(widget.projectCode));
                },
                icon: Icon(Icons.folder_outlined,
                    size: 20, color: _IaPalette.textSecondary),
              ),
            ),
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert_rounded,
                  size: 20, color: _IaPalette.textPrimary),
              padding: EdgeInsets.zero,
              color: _IaPalette.ink,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: _IaPalette.glassBorder),
              ),
              onSelected: (value) async {
                if (!_throttle()) return;
                if (value == 'market') await _startMarket();
                if (value == 'legal') await _startLegal();
                if (value == 'competitor') await _startCompetitor();
                if (value == 'finance') await _startFinance();
                if (value == 'business_plan') await _startBusinessPlan();
                if (value == 'delete') await _confirmDeleteProject();
              },
              itemBuilder: (context) => [
                _popupItem(
                    'market',
                    Icons.insights_outlined,
                    l10n.t('project_menu_market')),
                _popupItem(
                    'legal',
                    Icons.balance_outlined,
                    l10n.t('project_menu_legal')),
                _popupItem(
                    'competitor',
                    Icons.groups_outlined,
                    l10n.t('project_menu_competitor')),
                _popupItem(
                    'finance',
                    Icons.calculate_outlined,
                    l10n.t('project_menu_finance')),
                _popupItem(
                    'business_plan',
                    Icons.description_outlined,
                    l10n.t('project_menu_bp')),
                const PopupMenuDivider(),
                _popupItem(
                    'delete',
                    Icons.delete_outline_rounded,
                    l10n.t('project_menu_delete'),
                    isDestructive: true),
              ],
            ),
            const SizedBox(width: 8),
          ],
          bottom: PreferredSize(
            preferredSize: Size.fromHeight(_isExecutionMode ? 64 : 112),
            child: _Glass(
              radius: 0,
              alpha: 0.05,
              blur: _kGlassBlur,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PhaseSwitcher(
                    isExecutionMode: _isExecutionMode,
                    onModeChanged: (val) {
                      HapticFeedback.lightImpact();
                      setState(() => _isExecutionMode = val);
                      _ProjectDetailLogger.info('Mode changed',
                          {'execution': val});
                    },
                  ),
                  if (!_isExecutionMode) _buildTabBar(l10n),
                ],
              ),
            ),
          ),
        ),
        if (!_isExecutionMode)
          SliverToBoxAdapter(
            child: ProjectHeader(
              project: activeProject,
              progress: activeProject.progress,
            ),
          )
        else
          const SliverToBoxAdapter(child: SizedBox.shrink()),
      ],
      body: _isExecutionMode
          ? ExecutionDashboardFinal(
              projectCode: widget.projectCode,
              projectName: activeProject.name,
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
    );
  }

  Widget _buildTabBar(AppLocalizations l10n) {
    return TabBar(
      controller: _tabController,
      labelColor: _IaPalette.textPrimary,
      unselectedLabelColor: _IaPalette.textMuted,
      indicatorColor: _IaPalette.textPrimary,
      indicatorWeight: 2.5,
      labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      unselectedLabelStyle: const TextStyle(fontSize: 13),
      isScrollable: true,
      tabAlignment: TabAlignment.start,
      tabs: [
        Tab(text: l10n.t('project_tab_overview'), height: 36),
        Tab(text: l10n.t('project_tab_analyses'), height: 36),
        Tab(text: l10n.t('project_tab_memory'), height: 36),
        Tab(text: l10n.t('project_tab_docs'), height: 36),
      ],
    );
  }

  PopupMenuItem<String> _popupItem(
      String value, IconData icon, String label,
      {bool isDestructive = false}) {
    return PopupMenuItem<String>(
      value: value,
      height: 40,
      child: Row(
        children: [
          Icon(icon,
              size: 18,
              color:
                  isDestructive ? _IaPalette.textSecondary : _IaPalette.textPrimary),
          const SizedBox(width: 10),
          Text(label,
              style: TextStyle(
                  fontSize: 13,
                  color: isDestructive
                      ? _IaPalette.textSecondary
                      : _IaPalette.textPrimary)),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
// STATES
// ════════════════════════════════════════════════════════════════════

class _LoadingState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: _IaPalette.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            Text(l10n.t('project_loading'),
                style: TextStyle(
                    color: _IaPalette.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String projectCode;
  final String error;
  final VoidCallback onRetry;
  final VoidCallback onBack;

  const _ErrorState({
    required this.projectCode,
    required this.error,
    required this.onRetry,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(projectCode,
            style: TextStyle(
                color: _IaPalette.textPrimary,
                fontFamily: 'monospace',
                fontWeight: FontWeight.w600)),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded,
              size: 22, color: _IaPalette.textPrimary),
          onPressed: onBack,
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: _Glass(
            radius: 20,
            alpha: 0.10,
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _IaPalette.white.withValues(alpha: 0.12),
                  ),
                  child: Icon(Icons.error_outline_rounded,
                      color: _IaPalette.textPrimary, size: 28),
                ),
                const SizedBox(height: 16),
                Text(l10n.t('project_load_error'),
                    style: TextStyle(
                        color: _IaPalette.textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 15)),
                const SizedBox(height: 8),
                Text(error,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: _IaPalette.textSecondary, fontSize: 12)),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _GlassButton(
                      label: l10n.t('common_retry'),
                      onTap: onRetry,
                    ),
                    const SizedBox(width: 12),
                    _GlassButton(
                      label: l10n.t('project_back_to_list'),
                      onTap: onBack,
                      isSecondary: true,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProjectNotFoundState extends StatelessWidget {
  final String projectCode;
  final VoidCallback onBack;

  const _ProjectNotFoundState({
    required this.projectCode,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(projectCode,
            style: TextStyle(
                color: _IaPalette.textPrimary,
                fontFamily: 'monospace',
                fontWeight: FontWeight.w600)),
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off_rounded,
                color: _IaPalette.textSecondary, size: 48),
            const SizedBox(height: 16),
            Text(l10n.t('project_not_found'),
                style: TextStyle(
                    color: _IaPalette.textPrimary,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            _GlassButton(
              label: l10n.t('project_my_projects'),
              onTap: onBack,
            ),
          ],
        ),
      ),
    );
  }
}

class _GlassButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool isSecondary;

  const _GlassButton({
    required this.label,
    required this.onTap,
    this.isSecondary = false,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: isSecondary
                ? _IaPalette.white.withValues(alpha: 0.08)
                : _IaPalette.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _IaPalette.glassBorder),
          ),
          child: Text(label,
              style: TextStyle(
                  color: isSecondary
                      ? _IaPalette.textPrimary
                      : _IaPalette.ink,
                  fontWeight: FontWeight.w700,
                  fontSize: 13)),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
// TABS
// ════════════════════════════════════════════════════════════════════

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({required this.project});
  final ThixProject project;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cityPart = project.city != null ? ' • ${project.city}' : '';

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        Text(project.name,
            style: TextStyle(
                color: _IaPalette.textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 20)),
        const SizedBox(height: 4),
        Text(
          '${project.sector} • ${project.country}$cityPart',
          style: TextStyle(color: _IaPalette.textSecondary, fontSize: 12),
        ),
        if (project.summary != null && project.summary!.isNotEmpty) ...[
          const SizedBox(height: 14),
          Text(l10n.t('project_summary'),
              style: TextStyle(
                  color: _IaPalette.textSecondary,
                  fontWeight: FontWeight.w700,
                  fontSize: 12)),
          const SizedBox(height: 4),
          Text(project.summary!,
              style: TextStyle(color: _IaPalette.textPrimary, fontSize: 13)),
        ],
        const SizedBox(height: 16),
        Row(
          children: [
            Text(
              '${l10n.t("project_progress")}  ${(project.progress * 100).toInt()}%',
              style: TextStyle(
                  color: _IaPalette.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 12),
            ),
            const Spacer(),
            Text(
              '${project.analysesCount} ${l10n.t("project_analyses")}  •  ${project.documentsCount} ${l10n.t("project_docs")}',
              style: TextStyle(color: _IaPalette.textSecondary, fontSize: 11),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: project.progress.clamp(0.0, 1.0),
            minHeight: 5,
            backgroundColor: _IaPalette.white.withValues(alpha: 0.1),
            valueColor: AlwaysStoppedAnimation(_IaPalette.white),
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
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(analysesProvider);

    return async.when(
      loading: () => _LoadingState(),
      error: (e, _) => _TabErrorState(
        error: '$e',
        onRetry: () => ref.read(analysesProvider.notifier).refresh(),
      ),
      data: (analyses) {
        if (analyses.isEmpty) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
            children: [
              EmptyAnalyses(
                onStart: () =>
                    context.push(ThixIARoutes.analysisPath(projectCode)),
              ),
            ],
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          itemCount: analyses.length,
          itemBuilder: (context, index) {
            final a = analyses[index];
            return RepaintBoundary(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: AnalysisProgressWidget(analysis: a),
              ),
            );
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
  DateTime? _lastTap;

  bool _throttle() {
    final now = DateTime.now();
    if (_lastTap != null && now.difference(_lastTap!) < _kTapThrottle) {
      return false;
    }
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

    final config = await showBusinessPlanPreflightSheet(
      context,
      projectCode: widget.projectCode,
    );
    if (config == null || !mounted) return;

    setState(() => _isGenerating = true);

    try {
      await ref.read(analysesProvider.notifier).startBusinessPlanAnalysis(
            ideaDescription: [
              project.name,
              if (project.summary != null) project.summary!,
            ].join('\n'),
          );

      if (!mounted) return;
      _showSnack(l10n.t('project_bp_started'));
    } catch (e) {
      _showSnack(l10n.t('project_bp_error',
          args: ['$e']), // CORRECTION APPLIQUÉE ICI
          isError: true);
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg,
          style: TextStyle(
              color: isError ? _IaPalette.white : _IaPalette.ink)),
      backgroundColor: isError ? _IaPalette.ink : _IaPalette.white,
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
      loading: () => _LoadingState(),
      error: (e, _) => _TabErrorState(
        error: '$e',
        onRetry: () => ref.read(projectMemoryProvider.notifier).refresh(),
      ),
      data: (memory) {
        final facts = memory?.facts ?? [];

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            _Glass(
              radius: 20,
              alpha: 0.10,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _IaPalette.white.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.auto_awesome,
                            color: _IaPalette.textPrimary, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(l10n.t('project_final_dossier'),
                                style: TextStyle(
                                    color: _IaPalette.textPrimary,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14)),
                            const SizedBox(height: 2),
                            Text(
                              '$completedCount ${l10n.t("project_analyses")} • ${facts.length} ${l10n.t("project_facts")}',
                              style: TextStyle(
                                  color: _IaPalette.textSecondary,
                                  fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Semantics(
                    button: true,
                    label: l10n.t('project_generate_bp'),
                    child: GestureDetector(
                      onTap: _isGenerating ? null : _generateFinalDossier,
                      child: Container(
                        width: double.infinity,
                        height: 48,
                        decoration: BoxDecoration(
                          color: _isGenerating
                              ? _IaPalette.white.withValues(alpha: 0.5)
                              : _IaPalette.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: _isGenerating
                              ? SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: _IaPalette.ink,
                                  ),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.rocket_launch_rounded,
                                        size: 20, color: _IaPalette.ink),
                                    const SizedBox(width: 8),
                                    Text(l10n.t('project_generate_bp'),
                                        style: TextStyle(
                                            color: _IaPalette.ink,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13)),
                                  ],
                                ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(l10n.t('project_bp_preflight_hint'),
                      style: TextStyle(
                          color: _IaPalette.textMuted, fontSize: 11)),
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (facts.isEmpty)
              const EmptyFacts()
            else ...[
              Text(
                '${l10n.t("project_facts_in_memory")} (${facts.length})',
                style: TextStyle(
                    color: _IaPalette.textSecondary,
                    fontWeight: FontWeight.w700,
                    fontSize: 13),
              ),
              const SizedBox(height: 8),
              ...facts.map((f) => RepaintBoundary(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: FactCard(fact: f),
                    ),
                  )),
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
      loading: () => _LoadingState(),
      error: (e, _) => _TabErrorState(
        error: '$e',
        onRetry: () => ref.read(documentsProvider.notifier).refresh(),
      ),
      data: (docs) {
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            _Glass(
              radius: 16,
              alpha: 0.10,
              padding: const EdgeInsets.all(16),
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) =>
                        BpDocumentEditorPage(projectCode: projectCode),
                  ));
                },
                child: Row(
                  children: [
                    Icon(Icons.menu_book_outlined,
                        color: _IaPalette.textPrimary, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l10n.t('project_bp_document'),
                              style: TextStyle(
                                  color: _IaPalette.textPrimary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14)),
                          const SizedBox(height: 2),
                          Text(l10n.t('project_bp_document_hint'),
                              style: TextStyle(
                                  color: _IaPalette.textSecondary,
                                  fontSize: 11)),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded,
                        color: _IaPalette.textPrimary, size: 20),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (docs.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Text(l10n.t('project_no_other_docs'),
                      style: TextStyle(color: _IaPalette.textMuted)),
                ),
              )
            else
              ...docs.map((doc) {
                final index = docs.indexOf(doc);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _Glass(
                    radius: 12,
                    alpha: 0.08,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        Icon(Icons.description_outlined,
                            color: _IaPalette.textPrimary, size: 20),
                        const SizedBox(width: 12),
                        Text('${l10n.t("project_document")} ${index + 1}',
                            style: TextStyle(
                                color: _IaPalette.textPrimary,
                                fontWeight: FontWeight.w600,
                                fontSize: 13)),
                      ],
                    ),
                  ),
                );
              }),
          ],
        );
      },
    );
  }
}

class _TabErrorState extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;

  const _TabErrorState({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Center(
          child: _Glass(
            radius: 20,
            alpha: 0.10,
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _IaPalette.white.withValues(alpha: 0.12),
                  ),
                  child: Icon(Icons.error_outline_rounded,
                      color: _IaPalette.textPrimary, size: 28),
                ),
                const SizedBox(height: 16),
                Text(l10n.t('project_load_error'),
                    style: TextStyle(
                        color: _IaPalette.textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 15)),
                const SizedBox(height: 8),
                Text(error,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: _IaPalette.textSecondary, fontSize: 12)),
                const SizedBox(height: 14),
                _GlassButton(
                  label: l10n.t('common_retry'),
                  onTap: onRetry,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
