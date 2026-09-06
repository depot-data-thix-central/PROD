// lib/presentation/thix_event/admin/pages/analytics/analytics_page.dart
//
// AnalyticsPage — Production Enterprise (i18n + Robustesse + Design System)
//
// LOGIQUE PRÉSERVÉE :
// - analyticsProvider (RPC get_dashboard_stats + get_revenue_chart_data)
// - 4 KPI cards + LineChart 7 jours (fl_chart)
// - RefreshIndicator + bouton refresh
//
// AMÉLIORATIONS :
// - RPC parallélisés + timeout 10s
// - Parsing sécurisé (tryParse, skip items invalides)
// - Garde fl_chart (maxX >= 1)
// - i18n 8 langues + locale utilisateur pour les dates
// - EventTheme/ThixPolicy, Semantics, logging
import 'dart:ui';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../../core/theme/thix_design_policy.dart';
import '../../../../../l10n/app_localizations.dart';

// ============================================================================
// EVENT THEME (adapté depuis ThixPolicy)
// ============================================================================
class EventTheme {
  static const Color bg = ThixPolicy.inkDeep;
  static const Color surface = Color(0xFF101B30);
  static const Color surfaceAlt = Color(0xFF14213A);
  static const Color border = Color(0xFF243451);
  static const Color primary = ThixPolicy.domainEvents;
  static const Color accent = ThixPolicy.gold;
  static const Color textMain = ThixPolicy.textOnDark;
  static const Color textSecondary = Color(0xFFA8B6CC);
  static const Color textMuted = Color(0xFF64748B);
  static const Color success = ThixPolicy.success;
  static const Color danger = ThixPolicy.danger;
}

// ============================================================================
// CONSTANTS + LOGGING
// ============================================================================
const Duration _kRpcTimeout = Duration(seconds: 10);

class _AnalyticsLogger {
  static const _tag = 'Analytics';
  static void info(String m, [Map<String, dynamic>? d]) => _log('INFO', m, d);
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
// PROVIDER (RPC parallélisés + timeout)
// ============================================================================
final analyticsProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final sb = Supabase.instance.client;
  _AnalyticsLogger.info('Loading analytics');

  final results = await Future.wait<dynamic>([
    sb.rpc('get_dashboard_stats').timeout(_kRpcTimeout),
    sb
        .rpc('get_revenue_chart_data', params: {'days': 7})
        .timeout(_kRpcTimeout),
  ]);

  _AnalyticsLogger.info('Analytics loaded');
  return {'stats': results[0], 'chart': results[1]};
});

// ============================================================================
// HELPERS
// ============================================================================
double _num(dynamic v) {
  if (v is num) return v.toDouble();
  return double.tryParse(v?.toString() ?? '') ?? 0.0;
}

String _fmt(double a) {
  if (a >= 1000000) return '${(a / 1000000).toStringAsFixed(1)}M';
  if (a >= 1000) return '${(a / 1000).toStringAsFixed(1)}k FC';
  return '${a.toStringAsFixed(0)} FC';
}

// ============================================================================
// PAGE
// ============================================================================
class AnalyticsPage extends ConsumerWidget {
  const AnalyticsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final async = ref.watch(analyticsProvider);

    return Scaffold(
      backgroundColor: EventTheme.bg,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(56),
        child: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: AppBar(
              backgroundColor: EventTheme.bg.withOpacity(0.85),
              elevation: 0,
              leading: Semantics(
                button: true,
                label: l10n.t('common_back'),
                child: IconButton(
                  icon: const Icon(
                    Icons.arrow_back_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                  onPressed: () => context.pop(),
                ),
              ),
              title: Text(
                l10n.t('admin_analytics_title'),
                style: ThixPolicy.labelStyle.copyWith(
                  color: EventTheme.textMain,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              actions: [
                Semantics(
                  button: true,
                  label: l10n.t('common_refresh'),
                  child: IconButton(
                    icon: const Icon(
                      Icons.refresh_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                    onPressed: () {
                      _AnalyticsLogger.info('Manual refresh');
                      ref.invalidate(analyticsProvider);
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: async.when(
        loading: () => const Center(
          child: CircularProgressIndicator(
            color: EventTheme.primary,
            strokeWidth: 2,
          ),
        ),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                color: EventTheme.danger,
                size: 40,
              ),
              const SizedBox(height: 12),
              Text(
                l10n.t('admin_analytics_error'),
                style: ThixPolicy.bodySmallStyle.copyWith(
                  color: EventTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                e.toString(),
                style: ThixPolicy.microStyle.copyWith(
                  color: EventTheme.textMuted,
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => ref.invalidate(analyticsProvider),
                style: ElevatedButton.styleFrom(
                  backgroundColor: EventTheme.surface,
                  foregroundColor: EventTheme.textMain,
                ),
                child: Text(l10n.t('common_retry')),
              ),
            ],
          ),
        ),
        data: (data) {
          final stats = data['stats'] is Map
              ? Map<String, dynamic>.from(data['stats'] as Map)
              : null;
          final rawChart = data['chart'] is List ? data['chart'] as List : [];

          final fillRate = _num(stats?['fill_rate']);
          final avgCart = _num(stats?['avg_cart']);
          final noShow = _num(stats?['no_show_rate']);
          final revPerEvent = _num(stats?['revenue_per_event']);

          // ── Parsing sécurisé du chart ──
          final List<FlSpot> spots = [];
          final List<String> labels = [];
          double maxY = 0;
          final dateFmt = DateFormat('dd MMM', locale);

          for (final raw in rawChart) {
            if (raw is! Map) continue;
            final d = DateTime.tryParse(raw['date_day']?.toString() ?? '');
            if (d == null) continue;
            final rev = _num(raw['daily_revenue']);
            if (rev > maxY) maxY = rev;
            labels.add(dateFmt.format(d));
            spots.add(FlSpot((labels.length - 1).toDouble(), rev));
          }
          maxY = maxY > 0 ? maxY * 1.3 : 100;

          final totalRev =
              spots.fold<double>(0, (sum, s) => sum + s.y);

          return RefreshIndicator(
            color: Colors.white,
            backgroundColor: EventTheme.surface,
            onRefresh: () async => ref.invalidate(analyticsProvider),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              padding: const EdgeInsets.all(ThixPolicy.s16),
              children: [
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  crossAxisSpacing: ThixPolicy.s12,
                  mainAxisSpacing: ThixPolicy.s12,
                  childAspectRatio: 1.5,
                  children: [
                    _StatCard(
                      label: l10n.t('admin_analytics_fill_rate'),
                      value: '${fillRate.toStringAsFixed(1)}%',
                      icon: Icons.pie_chart_rounded,
                    ),
                    _StatCard(
                      label: l10n.t('admin_analytics_avg_cart'),
                      value: _fmt(avgCart),
                      icon: Icons.shopping_cart_rounded,
                    ),
                    _StatCard(
                      label: l10n.t('admin_analytics_no_show'),
                      value: '${noShow.toStringAsFixed(1)}%',
                      icon: Icons.person_off_rounded,
                    ),
                    _StatCard(
                      label: l10n.t('admin_analytics_rev_per_event'),
                      value: _fmt(revPerEvent),
                      icon: Icons.trending_up_rounded,
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: EventTheme.surface,
                    borderRadius: BorderRadius.circular(ThixPolicy.rLg),
                    border: Border.all(color: EventTheme.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.bar_chart_rounded,
                            color: EventTheme.primary,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            l10n.t('admin_analytics_revenue_7d'),
                            style: ThixPolicy.labelStyle.copyWith(
                              color: EventTheme.textMain,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Semantics(
                        label:
                            '${l10n.t('admin_analytics_revenue_7d')}: ${_fmt(totalRev)}',
                        child: SizedBox(
                          height: 220,
                          child: spots.isEmpty
                              ? Center(
                                  child: Text(
                                    l10n.t('admin_analytics_no_data'),
                                    style: ThixPolicy.bodySmallStyle.copyWith(
                                      color: EventTheme.textMuted,
                                    ),
                                  ),
                                )
                              : LineChart(
                                  LineChartData(
                                    gridData: FlGridData(
                                      show: true,
                                      drawVerticalLine: false,
                                      horizontalInterval: maxY / 4,
                                      getDrawingHorizontalLine: (_) => FlLine(
                                        color: EventTheme.border,
                                        strokeWidth: 1,
                                      ),
                                    ),
                                    titlesData: FlTitlesData(
                                      rightTitles: const AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: false,
                                        ),
                                      ),
                                      topTitles: const AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: false,
                                        ),
                                      ),
                                      bottomTitles: AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: true,
                                          reservedSize: 28,
                                          interval: 1,
                                          getTitlesWidget: (v, _) {
                                            final i = v.toInt();
                                            if (i >= 0 && i < labels.length) {
                                              return Padding(
                                                padding:
                                                    const EdgeInsets.only(
                                                  top: 8,
                                                ),
                                                child: Text(
                                                  labels[i],
                                                  style: TextStyle(
                                                    color:
                                                        EventTheme.textMuted,
                                                    fontSize: 9,
                                                  ),
                                                ),
                                              );
                                            }
                                            return const SizedBox();
                                          },
                                        ),
                                      ),
                                      leftTitles: AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: true,
                                          reservedSize: 42,
                                          interval: maxY / 4,
                                          getTitlesWidget: (v, _) {
                                            if (v == 0) {
                                              return const SizedBox();
                                            }
                                            return Text(
                                              _fmt(v),
                                              style: TextStyle(
                                                color: EventTheme.textMuted,
                                                fontSize: 8,
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                    borderData: FlBorderData(show: false),
                                    minX: 0,
                                    // Garde anti-crash fl_chart (maxX > minX)
                                    maxX: spots.length > 1
                                        ? (spots.length - 1).toDouble()
                                        : 1,
                                    minY: 0,
                                    maxY: maxY,
                                    lineBarsData: [
                                      LineChartBarData(
                                        spots: spots,
                                        isCurved: true,
                                        color: EventTheme.primary,
                                        barWidth: 2.5,
                                        isStrokeCapRound: true,
                                        dotData: const FlDotData(show: false),
                                        belowBarData: BarAreaData(
                                          show: true,
                                          color: EventTheme.primary
                                              .withOpacity(0.12),
                                        ),
                                      ),
                                    ],
                                    lineTouchData: LineTouchData(
                                      touchTooltipData: LineTouchTooltipData(
                                        getTooltipColor: (_) =>
                                            EventTheme.surfaceAlt,
                                        getTooltipItems: (ts) => ts
                                            .map(
                                              (t) => LineTooltipItem(
                                                '${labels[t.x.toInt()]}\n',
                                                const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                                children: [
                                                  TextSpan(
                                                    text: _fmt(t.y),
                                                    style: TextStyle(
                                                      color:
                                                          EventTheme.primary,
                                                      fontWeight:
                                                          FontWeight.w900,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            )
                                            .toList(),
                                      ),
                                    ),
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ============================================================================
// STAT CARD (avec Semantics)
// ============================================================================
class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label: $value',
      child: Container(
        padding: const EdgeInsets.all(ThixPolicy.s14),
        decoration: BoxDecoration(
          color: EventTheme.surface,
          borderRadius: BorderRadius.circular(ThixPolicy.rMd),
          border: Border.all(color: EventTheme.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 16, color: EventTheme.primary),
            const Spacer(),
            Text(
              value,
              style: ThixPolicy.titleStyle.copyWith(
                color: EventTheme.textMain,
                fontWeight: FontWeight.w900,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: ThixPolicy.microStyle.copyWith(
                color: EventTheme.textMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
