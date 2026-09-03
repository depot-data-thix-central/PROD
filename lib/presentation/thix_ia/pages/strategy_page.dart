// lib/presentation/thix_ia/pages/strategy_page.dart
//
// StrategyPage — "Monochrome Glass" (Production Enterprise)
//
// Design : 2 couleurs uniquement (blanc #FFF + encre #0B1220)
// Glassmorphism pur, logique 100% préservée.
//
// ANTI-ERREURS APPLIQUÉES :
// - Jamais args: {} dans l10n.t() (remplacement manuel si besoin)
// - Pas de const sur widgets utilisant _IaPalette (getters non-const)
// - Pas de strings FR hardcodés
// - Throttling + logs + Semantics + HapticFeedback
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/l10n/app_localizations.dart';

import '../providers/analysis_provider.dart';
import '../widgets/opportunity_card.dart';
import '../widgets/risk_card.dart';
import '../widgets/insight_card.dart';

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

class _StrategyLogger {
  static const _tag = 'Strategy';
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

class StrategyPage extends ConsumerStatefulWidget {
  const StrategyPage({super.key, required this.projectCode});
  final String projectCode;

  @override
  ConsumerState<StrategyPage> createState() => _StrategyPageState();
}

class _StrategyPageState extends ConsumerState<StrategyPage> {
  DateTime? _lastTap;
  bool _isGenerating = false;

  @override
  void initState() {
    super.initState();
    _StrategyLogger.info('Page initialized',
        {'projectCode': widget.projectCode});
  }

  bool _throttle() {
    final now = DateTime.now();
    if (_lastTap != null && now.difference(_lastTap!) < _kTapThrottle) {
      _StrategyLogger.warn('Tap throttled');
      return false;
    }
    _lastTap = now;
    return true;
  }

  // ════════════════════════════════════════════════════════════════════
  // LANCER STRATÉGIE (logique préservée)
  // ════════════════════════════════════════════════════════════════════

  Future<void> _startStrategy() async {
    if (!_throttle()) return;
    if (_isGenerating) return;

    HapticFeedback.mediumImpact();
    _StrategyLogger.info('Strategy analysis started');

    setState(() => _isGenerating = true);

    try {
      await ref.read(analysesProvider.notifier).startFinanceAnalysis(
            inputs: <String, dynamic>{
              'type': 'strategy',
              'framework': 'SWOT + Porter + Lean Canvas',
            },
          );

      if (mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(l10n.t('strategy_started')),
          backgroundColor: _IaPalette.white,
          behavior: SnackBarBehavior.floating,
        ));
      }
      _StrategyLogger.info('Strategy analysis launched successfully');
    } catch (e) {
      _StrategyLogger.error('Strategy analysis failed', {'error': '$e'});
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        final errorMsg =
            l10n.t('strategy_error_generic').replaceAll('{error}', '$e');
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(errorMsg,
              style: const TextStyle(color: _IaPalette.white)),
          backgroundColor: _IaPalette.ink,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  // ════════════════════════════════════════════════════════════════════
  // BUILD
  // ════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final strategy = ref.watch(analysesByTypeProvider('strategy'));

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
        title: Text(l10n.t('strategy_page_title'),
            style: TextStyle(
                fontWeight: FontWeight.w900,
                color: _IaPalette.textPrimary,
                fontSize: 16,
                letterSpacing: -0.5)),
      ),
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

          SafeArea(
            child: ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                // ══ HERO : STRATÉGIE COMPLÈTE ══
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: _Glass(
                    radius: 20,
                    alpha: 0.10,
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
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
                            Text(l10n.t('strategy_complete'),
                                style: TextStyle(
                                    color: _IaPalette.textPrimary,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(l10n.t('strategy_complete_desc'),
                            style: TextStyle(
                                color: _IaPalette.textSecondary,
                                fontSize: 12,
                                height: 1.4)),
                        const SizedBox(height: 16),
                        Semantics(
                          button: true,
                          label: l10n.t('strategy_generate'),
                          child: GestureDetector(
                            onTap: _isGenerating ? null : _startStrategy,
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
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.rocket_launch_rounded,
                                              color: _IaPalette.ink, size: 18),
                                          const SizedBox(width: 8),
                                          Text(l10n.t('strategy_generate'),
                                              style: TextStyle(
                                                  color: _IaPalette.ink,
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 13)),
                                        ],
                                      ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // ══ CONTENU ══
                if (strategy.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: _Glass(
                      radius: 16,
                      alpha: 0.08,
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          Icon(Icons.lightbulb_outline_rounded,
                              color: _IaPalette.textSecondary, size: 32),
                          const SizedBox(height: 12),
                          Text(l10n.t('strategy_empty'),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: _IaPalette.textSecondary,
                                  fontSize: 12,
                                  height: 1.4)),
                        ],
                      ),
                    ),
                  )
                else ...[
                  // ── ANALYSES STRATÉGIQUES ──
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                    child: _SectionHeader(
                        title: l10n.t('strategy_analyses_section')),
                  ),
                  ...strategy.map((a) => Padding(
                        padding:
                            const EdgeInsets.fromLTRB(16, 0, 16, 8),
                        child: RepaintBoundary(
                          child: InsightCard(
                            title: a.title ?? l10n.t('strategy_default_title'),
                            content: a.summary ?? '',
                            confidence: a.confidence,
                            type: 'strategy',
                          ),
                        ),
                      )),

                  // ── OPPORTUNITÉS ──
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child:
                        _SectionHeader(title: l10n.t('strategy_opportunities')),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: RepaintBoundary(
                      child: OpportunityCard(
                        title: l10n.t('strategy_opp_title'),
                        description: l10n.t('strategy_opp_desc'),
                        impact: 'high',
                        source: l10n.t('strategy_opp_source'),
                      ),
                    ),
                  ),

                  // ── RISQUES ──
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: _SectionHeader(title: l10n.t('strategy_risks')),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: RepaintBoundary(
                      child: RiskCard(
                        title: l10n.t('strategy_risk_title'),
                        content: l10n.t('strategy_risk_content'),
                        level: 'high',
                        source: l10n.t('strategy_risk_source'),
                      ),
                    ),
                  ),
                ],
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
// SECTION HEADER (réutilisable)
// ============================================================================

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 12,
          decoration: BoxDecoration(
            color: _IaPalette.white.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(title,
            style: TextStyle(
                color: _IaPalette.textSecondary,
                fontWeight: FontWeight.w700,
                fontSize: 12,
                letterSpacing: 0.3)),
      ],
    );
  }
}
