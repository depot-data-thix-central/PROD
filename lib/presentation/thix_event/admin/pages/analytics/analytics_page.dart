import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

class _ThixColors {
  static const bg = Color(0xFF050508);
  static const surface = Color(0xFF0C0C12);
  static const surfaceAlt = Color(0xFF111118);
  static const cardBorder = Color(0x14FFFFFF);
  static const primary = Color(0xFFFF0A54);
  static const textSecondary = Color(0x99FFFFFF);
  static const textMuted = Color(0x66FFFFFF);
}

final analyticsProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final sb = Supabase.instance.client;
  final stats = await sb.rpc('get_dashboard_stats');
  final chart = await sb.rpc('get_revenue_chart_data', params: {'days': 7});
  return {'stats': stats, 'chart': chart};
});

class AnalyticsPage extends ConsumerWidget {
  const AnalyticsPage({super.key});

  String _fmt(double a) {
    if (a >= 1000000) return '${(a / 1000000).toStringAsFixed(1)}M';
    if (a >= 1000) return '${(a / 1000).toStringAsFixed(1)}k FC';
    return '${a.toStringAsFixed(0)} FC';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(analyticsProvider);

    return Scaffold(
      backgroundColor: _ThixColors.bg,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(56),
        child: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: AppBar(
              backgroundColor: _ThixColors.bg.withOpacity(0.85),
              elevation: 0,
              leading: IconButton(icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 18), onPressed: () => Navigator.of(context).pop()),
              title: const Text('Analytics • Performance', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800)),
              actions: [IconButton(icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 18), onPressed: () => ref.invalidate(analyticsProvider))],
            ),
          ),
        ),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator(color: _ThixColors.primary, strokeWidth: 2)),
        error: (e, _) => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.error_outline_rounded, color: Colors.red, size: 40), const SizedBox(height: 12), Text(e.toString(), style: const TextStyle(color: _ThixColors.textMuted, fontSize: 11)), const SizedBox(height: 12), ElevatedButton(onPressed: () => ref.invalidate(analyticsProvider), style: ElevatedButton.styleFrom(backgroundColor: _ThixColors.surface), child: const Text('Reessayer'))])),
        data: (data) {
          final stats = data['stats'] as Map<String, dynamic>?;
          final chart = data['chart'] as List? ?? [];

          final fillRate = (stats?['fill_rate'] ?? 0.0).toDouble();
          final avgCart = (stats?['avg_cart'] ?? 0.0).toDouble();
          final noShow = (stats?['no_show_rate'] ?? 0.0).toDouble();
          final revPerEvent = (stats?['revenue_per_event'] ?? 0.0).toDouble();

          List<FlSpot> spots = [];
          List<String> labels = [];
          double maxY = 0;
          for (int i = 0; i < chart.length; i++) {
            final item = chart[i] as Map;
            final d = DateTime.parse(item['date_day'].toString());
            final rev = (item['daily_revenue'] ?? 0).toDouble();
            if (rev > maxY) maxY = rev;
            labels.add(DateFormat('dd MMM', 'fr').format(d));
            spots.add(FlSpot(i.toDouble(), rev));
          }
          maxY = maxY > 0 ? maxY * 1.3 : 100;

          return RefreshIndicator(
            color: Colors.white,
            backgroundColor: _ThixColors.surface,
            onRefresh: () async => ref.invalidate(analyticsProvider),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
              padding: const EdgeInsets.all(16),
              children: [
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.5,
                  children: [
                    _StatCard(label: 'Remplissage', value: '${fillRate.toStringAsFixed(1)}%', icon: Icons.pie_chart_rounded),
                    _StatCard(label: 'Panier moyen', value: _fmt(avgCart), icon: Icons.shopping_cart_rounded),
                    _StatCard(label: 'No-show', value: '${noShow.toStringAsFixed(1)}%', icon: Icons.person_off_rounded),
                    _StatCard(label: 'Revenu / Event', value: _fmt(revPerEvent), icon: Icons.trending_up_rounded),
                  ],
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(color: _ThixColors.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: _ThixColors.cardBorder)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Row(children: [Icon(Icons.bar_chart_rounded, color: Colors.white, size: 16), SizedBox(width: 8), Text('Revenus 7j', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800))]),
                    const SizedBox(height: 24),
                    SizedBox(
                      height: 220,
                      child: spots.isEmpty
                          ? const Center(child: Text('Aucune donnee', style: TextStyle(color: _ThixColors.textMuted, fontSize: 11)))
                          : LineChart(LineChartData(
                              gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: maxY / 4, getDrawingHorizontalLine: (_) => FlLine(color: _ThixColors.cardBorder, strokeWidth: 1)),
                              titlesData: FlTitlesData(
                                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 28, interval: 1, getTitlesWidget: (v, _) { final i = v.toInt(); if (i >= 0 && i < labels.length) return Padding(padding: const EdgeInsets.only(top: 8), child: Text(labels[i], style: const TextStyle(color: _ThixColors.textMuted, fontSize: 9))); return const SizedBox(); })),
                                leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 42, interval: maxY / 4, getTitlesWidget: (v, _) { if (v == 0) return const SizedBox(); return Text(_fmt(v), style: const TextStyle(color: _ThixColors.textMuted, fontSize: 8)); })),
                              ),
                              borderData: FlBorderData(show: false),
                              minX: 0,
                              maxX: (labels.length - 1).toDouble().clamp(0, 100),
                              minY: 0,
                              maxY: maxY,
                              lineBarsData: [LineChartBarData(spots: spots, isCurved: true, color: _ThixColors.primary, barWidth: 2.5, isStrokeCapRound: true, dotData: const FlDotData(show: false), belowBarData: BarAreaData(show: true, color: _ThixColors.primary.withOpacity(0.12)))],
                              lineTouchData: LineTouchData(touchTooltipData: LineTouchTooltipData(getTooltipColor: (_) => _ThixColors.surfaceAlt, getTooltipItems: (ts) => ts.map((t) => LineTooltipItem('${labels[t.x.toInt()]}\n', const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700), children: [TextSpan(text: _fmt(t.y), style: const TextStyle(color: _ThixColors.primary, fontWeight: FontWeight.w900))])).toList())),
                            )),
                    ),
                  ]),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  const _StatCard({required this.label, required this.value, required this.icon});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: _ThixColors.surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: _ThixColors.cardBorder)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 16, color: Colors.white),
        const Spacer(),
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: _ThixColors.textMuted, fontSize: 10, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}
