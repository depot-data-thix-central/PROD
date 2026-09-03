// lib/presentation/thix_ia/pages/analysis_page.dart
//
// AnalysisPage — "Monochrome Glass" (Production Enterprise)
//
// Design : 2 couleurs uniquement (blanc #FFF + encre #0B1220)
// Glassmorphism pur, logique 100% préservée.
//
// ANTI-ERREURS APPLIQUÉES :
// - Pas de `const` sur widgets utilisant _IaPalette (getters non-const)
// - `<String, String>{...}` sur tous args: de l10n.t()
// - Pas de strings FR hardcodés
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/l10n/app_localizations.dart';

import '../providers/analysis_provider.dart';
import '../widgets/analysis_progress_widget.dart';
import '../widgets/empty_state_widget.dart';

// ============================================================================
// PALETTE MONOCHROME
// ============================================================================

class _IaPalette {
  _IaPalette._();

  static const Color ink = Color(0xFF0B1220);
  static const Color white = Color(0xFFFFFFFF);

  // Couleurs const acceptées par dart2js (pas de .withValues)
  static const int _whiteARGB = 0xFFFFFFFF;

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

class _AnalysisLogger {
  static const _tag = 'Analysis';
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
// GLASS SURFACE (réutilisable)
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

class AnalysisPage extends ConsumerStatefulWidget {
  const AnalysisPage({super.key, required this.projectCode});
  final String projectCode;

  @override
  ConsumerState<AnalysisPage> createState() => _AnalysisPageState();
}

class _AnalysisPageState extends ConsumerState<AnalysisPage> {
  DateTime? _lastTap;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(analysesProvider.notifier).refresh());
    _AnalysisLogger.info('Page initialized',
        {'projectCode': widget.projectCode});
  }

  bool _throttle() {
    final now = DateTime.now();
    if (_lastTap != null && now.difference(_lastTap!) < _kTapThrottle) {
      _AnalysisLogger.warn('Tap throttled');
      return false;
    }
    _lastTap = now;
    return true;
  }

  Future<void> _startMarket() async {
    if (!_throttle()) return;
    HapticFeedback.selectionClick();
    _AnalysisLogger.info('Market analysis started');
    try {
      await ref.read(analysesProvider.notifier).startMarketAnalysis(
            country: 'RDC',
            sector: 'AgriTech',
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(_successSnack(
            AppLocalizations.of(context).t('analysis_started_market')));
      }
    } catch (e) {
      _AnalysisLogger.error('Market analysis failed', {'error': '$e'});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(_errorSnack(
            AppLocalizations.of(context).t('analysis_error_generic',
                args: <String, String>{'error': '$e'})));
      }
    }
  }

  Future<void> _startLegal() async {
    if (!_throttle()) return;
    HapticFeedback.selectionClick();
    _AnalysisLogger.info('Legal analysis started');
    try {
      await ref.read(analysesProvider.notifier).startLegalAnalysis(
            jurisdiction: 'RDC',
            sector: 'AgriTech',
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(_successSnack(
            AppLocalizations.of(context).t('analysis_started_legal')));
      }
    } catch (e) {
      _AnalysisLogger.error('Legal analysis failed', {'error': '$e'});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(_errorSnack(
            AppLocalizations.of(context).t('analysis_error_generic',
                args: <String, String>{'error': '$e'})));
      }
    }
  }

  Future<void> _startFinance() async {
    if (!_throttle()) return;
    HapticFeedback.selectionClick();
    _AnalysisLogger.info('Finance analysis started');
    try {
      await ref.read(analysesProvider.notifier).startFinanceAnalysis(
            inputs: <String, dynamic>{
              'initial_investment': 50000,
              'monthly_revenue': 10000,
            },
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(_successSnack(
            AppLocalizations.of(context).t('analysis_started_finance')));
      }
    } catch (e) {
      _AnalysisLogger.error('Finance analysis failed', {'error': '$e'});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(_errorSnack(
            AppLocalizations.of(context).t('analysis_error_generic',
                args: <String, String>{'error': '$e'})));
      }
    }
  }

  Future<void> _startCompetitor() async {
    if (!_throttle()) return;
    HapticFeedback.selectionClick();
    _AnalysisLogger.info('Competitor analysis started');
    try {
      await ref.read(analysesProvider.notifier).startCompetitorAnalysis(
            country: 'RDC',
            sector: 'Général',
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(_successSnack(
            AppLocalizations.of(context).t('analysis_started_competitor')));
      }
    } catch (e) {
      _AnalysisLogger.error('Competitor analysis failed', {'error': '$e'});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(_errorSnack(
            AppLocalizations.of(context).t('analysis_error_generic',
                args: <String, String>{'error': '$e'})));
      }
    }
  }

  SnackBar _successSnack(String text) => SnackBar(
        content: Text(text),
        backgroundColor: _IaPalette.white,
        behavior: SnackBarBehavior.floating,
      );

  SnackBar _errorSnack(String text) => SnackBar(
        content: Text(text,
            style: const TextStyle(color: _IaPalette.white)),
        backgroundColor: _IaPalette.ink,
        behavior: SnackBarBehavior.floating,
      );

  // ════════════════════════════════════════════════════════════════════
  // BUILD
  // ════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final analysesAsync = ref.watch(analysesProvider);

    return Scaffold(
      backgroundColor: _IaPalette.ink,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: Semantics(
          button: true,
          label: l10n.t('common_back'),
          child: IconButton(
            icon: Icon(Icons.arrow_back_ios_rounded,
                color: _IaPalette.textPrimary),
            onPressed: () {
              HapticFeedback.selectionClick();
              Navigator.of(context).maybePop();
            },
          ),
        ),
        flexibleSpace: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: _kGlassBlur, sigmaY: _kGlassBlur),
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
        title: Text(l10n.t('analysis_page_title'),
            style: TextStyle(
                fontWeight: FontWeight.w900,
                color: _IaPalette.textPrimary,
                fontSize: 16,
                letterSpacing: -0.5)),
      ),
      body: Stack(
        children: [
          // Orbes monochromes (glass)
          Positioned(
              top: -60,
              right: -110,
              child: _buildOrb(_IaPalette.white.withValues(alpha: 0.10), 340)),
          Positioned(
              bottom: 180,
              left: -120,
              child: _buildOrb(_IaPalette.white.withValues(alpha: 0.07), 300)),

          SafeArea(
            child: Column(
              children: [
                // ══ HEADER ACTIONS ══
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: _ActionsPanel(
                    onStartMarket: _startMarket,
                    onStartLegal: _startLegal,
                    onStartFinance: _startFinance,
                    onStartCompetitor: _startCompetitor,
                  ),
                ),

                // ══ LISTE DES ANALYSES ══
                Expanded(
                  child: analysesAsync.when(
                    loading: () => _LoadingState(),
                    error: (e, _) => _ErrorState(error: '$e'),
                    data: (analyses) {
                      if (analyses.isEmpty) {
                        return EmptyAnalyses(onStart: _startMarket);
                      }
                      return RefreshIndicator(
                        color: _IaPalette.white,
                        backgroundColor: _IaPalette.ink,
                        onRefresh: () async {
                          HapticFeedback.mediumImpact();
                          await ref
                              .read(analysesProvider.notifier)
                              .refresh();
                        },
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                          itemCount: analyses.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
                          itemBuilder: (_, i) => RepaintBoundary(
                            child: AnalysisProgressWidget(
                              analysis: analyses[i],
                              onRetry: _startMarket,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
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
}

// ============================================================================
// PANEL ACTIONS (glass monochrome)
// ============================================================================

class _ActionsPanel extends StatelessWidget {
  final VoidCallback onStartMarket;
  final VoidCallback onStartLegal;
  final VoidCallback onStartFinance;
  final VoidCallback onStartCompetitor;

  const _ActionsPanel({
    required this.onStartMarket,
    required this.onStartLegal,
    required this.onStartFinance,
    required this.onStartCompetitor,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return _Glass(
      radius: 20,
      alpha: 0.08,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Titre section
          Row(
            children: [
              Container(
                width: 3,
                height: 14,
                decoration: BoxDecoration(
                  color: _IaPalette.white,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              Text(l10n.t('analysis_launch_section'),
                  style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: _IaPalette.textPrimary,
                      letterSpacing: 0.3)),
            ],
          ),
          const SizedBox(height: 14),

          // Grid 2x2 d'actions
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 2.4,
            children: [
              _ActionGlassBtn(
                icon: Icons.trending_up_rounded,
                label: l10n.t('analysis_action_market'),
                onTap: onStartMarket,
              ),
              _ActionGlassBtn(
                icon: Icons.gavel_rounded,
                label: l10n.t('analysis_action_legal'),
                onTap: onStartLegal,
              ),
              _ActionGlassBtn(
                icon: Icons.calculate_rounded,
                label: l10n.t('analysis_action_finance'),
                onTap: onStartFinance,
              ),
              _ActionGlassBtn(
                icon: Icons.people_rounded,
                label: l10n.t('analysis_action_competitor'),
                onTap: onStartCompetitor,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionGlassBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionGlassBtn({
    required this.icon,
    required this.label,
    required this.onTap,
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
          decoration: BoxDecoration(
            color: _IaPalette.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _IaPalette.glassBorderSoft),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Icon(icon, size: 18, color: _IaPalette.textPrimary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: _IaPalette.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 12.5)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// LOADING STATE (monochrome)
// ============================================================================

class _LoadingState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
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
          Text(l10n.t('analysis_loading'),
              style: TextStyle(
                  color: _IaPalette.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ============================================================================
// ERROR STATE (monochrome)
// ============================================================================

class _ErrorState extends StatelessWidget {
  final String error;
  const _ErrorState({required this.error});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
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
              Text(l10n.t('analysis_error_title'),
                  style: TextStyle(
                      color: _IaPalette.textPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 15)),
              const SizedBox(height: 8),
              Text(error,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: _IaPalette.textSecondary, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}
