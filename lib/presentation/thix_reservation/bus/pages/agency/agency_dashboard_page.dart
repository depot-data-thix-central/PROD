import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/core/extensions/context_ext.dart';
import 'package:thix_id/core/utils/currency_formatter.dart';
import 'package:thix_id/core/providers/currency_provider.dart';

import '../../data/models/bus_trip_model.dart';
import '../../data/models/booking_model.dart';
import '../../providers/agency_dashboard_provider.dart';

/// ============================================================================
/// AgencyDashboardPage
/// ============================================================================
///
/// Dashboard professionnel pour les agences de bus.
///
/// Features :
/// - 4 KPI cards avec sparklines animés + % change
/// - Date range selector (Aujourd'hui, 7j, 30j, Tout)
/// - Graphique revenus 7 derniers jours (fl_chart)
/// - Graphique réservations par statut (donut)
/// - 4 actions rapides avec icônes colorées
/// - Liste trajets à venir avec filtres
/// - Liste réservations récentes avec statuts
/// - Multi-devises global (currencyProvider)
/// - Skeleton loader pendant le chargement
/// - Empty states élégants pour chaque section
/// - Pull-to-refresh
/// - Haptic feedback
/// - Accessibilité complète (Semantics)
/// - i18n (FR/EN/LN)
/// - Design system ThixPolicy
/// - Export placeholder (PDF/CSV)
///
/// ============================================================================
class AgencyDashboardPage extends ConsumerStatefulWidget {
  const AgencyDashboardPage({super.key});

  @override
  ConsumerState<AgencyDashboardPage> createState() =>
      _AgencyDashboardPageState();
}

class _AgencyDashboardPageState extends ConsumerState<AgencyDashboardPage> {
  _DateRange _selectedRange = _DateRange.today;
  _TripFilter _tripFilter = _TripFilter.all;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(agencyDashboardProvider.notifier).init();
    });
  }

  Future<void> _refresh() async {
    await ref.read(agencyDashboardProvider.notifier).init();
  }

  void _showExportOptions() {
    final l10n = context.l10n;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _ExportSheet(
        onExport: (format) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.agencyDashboardExportComingSoon),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(ThixPolicy.rSm),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = ref.watch(agencyDashboardProvider);
    final domainColor = ThixPolicy.domainReservation;

    if (state.isLoading && state.myAgency == null) {
      return Scaffold(
        backgroundColor: ThixPolicy.surface,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          title: Text(
            l10n.agencyDashboardTitle,
            style: ThixPolicy.titleStyle.copyWith(
              fontWeight: ThixPolicy.bold,
            ),
          ),
        ),
        body: const _DashboardSkeleton(),
      );
    }

    if (!state.hasAgency) {
      return _NoAgencyView(domainColor: domainColor);
    }

    return Scaffold(
      backgroundColor: ThixPolicy.surface,
      appBar: _buildAppBar(state, domainColor),
      floatingActionButton: _TripFab(domainColor: domainColor),
      body: RefreshIndicator(
        color: domainColor,
        backgroundColor: Colors.white,
        onRefresh: _refresh,
        child: _buildBody(state, domainColor),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(
    AgencyDashboardState state,
    Color domainColor,
  ) {
    final l10n = context.l10n;
    final agency = state.myAgency!;

    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0.5,
      toolbarHeight: 72,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded, color: ThixPolicy.textMain),
        onPressed: () => context.pop(),
        tooltip: l10n.commonBack,
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            agency.name,
            style: ThixPolicy.titleStyle.copyWith(
              fontWeight: ThixPolicy.bold,
              fontSize: 16,
              color: ThixPolicy.textMain,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: ThixPolicy.s2),
          Row(
            children: [
              Text(
                agency.countryCode.toUpperCase(),
                style: ThixPolicy.microStyle.copyWith(
                  color: ThixPolicy.textSecondary,
                  fontFamily: 'monospace',
                  fontWeight: ThixPolicy.bold,
                ),
              ),
              SizedBox(width: ThixPolicy.s6),
              Text('•', style: TextStyle(color: ThixPolicy.textMuted)),
              SizedBox(width: ThixPolicy.s6),
              _StatusBadge(status: agency.status ?? 'active'),
            ],
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: Icon(Icons.download_rounded, color: ThixPolicy.textMain),
          tooltip: l10n.agencyDashboardExport,
          onPressed: _showExportOptions,
        ),
        IconButton(
          icon: Container(
            padding: EdgeInsets.all(ThixPolicy.s6),
            decoration: BoxDecoration(
              color: domainColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(ThixPolicy.rSm),
            ),
            child: Icon(Icons.qr_code_scanner_rounded, color: domainColor, size: 18),
          ),
          tooltip: l10n.agencyDashboardScanTicket,
          onPressed: () => context.push('/agency/scan'),
        ),
        SizedBox(width: ThixPolicy.s4),
      ],
    );
  }

  Widget _buildBody(AgencyDashboardState state, Color domainColor) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      padding: EdgeInsets.fromLTRB(
        ThixPolicy.s16,
        ThixPolicy.s12,
        ThixPolicy.s16,
        ThixPolicy.s120,
      ),
      children: [
        // Currency + Date Range selector
        _DashboardControls(
          selectedRange: _selectedRange,
          onRangeChanged: (r) {
            HapticFeedback.selectionClick();
            setState(() => _selectedRange = r);
          },
          domainColor: domainColor,
        ),
        SizedBox(height: ThixPolicy.s16),

        // KPI Grid (4 cards)
        _KpiGrid(
          state: state,
          domainColor: domainColor,
        ),
        SizedBox(height: ThixPolicy.s20),

        // Revenue chart (7 days)
        _RevenueChartSection(
          state: state,
          domainColor: domainColor,
        ),
        SizedBox(height: ThixPolicy.s20),

        // Bookings distribution (donut)
        _BookingsDistributionSection(
          state: state,
          domainColor: domainColor,
        ),
        SizedBox(height: ThixPolicy.s24),

        // Quick actions
        _QuickActionsSection(
          state: state,
          domainColor: domainColor,
        ),
        SizedBox(height: ThixPolicy.s24),

        // Upcoming trips with filter
        _UpcomingTripsSection(
          state: state,
          filter: _tripFilter,
          onFilterChanged: (f) {
            HapticFeedback.selectionClick();
            setState(() => _tripFilter = f);
          },
          domainColor: domainColor,
        ),
        SizedBox(height: ThixPolicy.s24),

        // Recent bookings
        _RecentBookingsSection(
          state: state,
          domainColor: domainColor,
        ),
      ],
    );
  }
}

/// ============================================================================
/// Enums & Helpers
/// ============================================================================
enum _DateRange { today, week, month, all }

enum _TripFilter { all, scheduled, departed, cancelled }

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final color = _getStatusColor(status);
    final label = _translateStatus(l10n, status);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: ThixPolicy.s6,
        vertical: ThixPolicy.s2,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(ThixPolicy.rXs),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: ThixPolicy.s4),
          Text(
            label,
            style: ThixPolicy.microStyle.copyWith(
              color: color,
              fontWeight: ThixPolicy.bold,
              fontSize: 9.5,
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
      case 'approved':
        return ThixPolicy.success;
      case 'pending':
      case 'review':
        return ThixPolicy.warning;
      case 'rejected':
      case 'suspended':
        return ThixPolicy.danger;
      default:
        return ThixPolicy.textMuted;
    }
  }

  String _translateStatus(dynamic l10n, String status) {
    try {
      switch (status.toLowerCase()) {
        case 'active':
        case 'approved':
          return l10n.agencyStatusActive;
        case 'pending':
        case 'review':
          return l10n.agencyStatusPending;
        case 'rejected':
          return l10n.agencyStatusRejected;
        case 'suspended':
          return l10n.agencyStatusSuspended;
        default:
          return status;
      }
    } catch (_) {
      return status;
    }
  }
}

/// ============================================================================
/// _DashboardControls — Currency toggle + Date range
/// ============================================================================
class _DashboardControls extends ConsumerWidget {
  final _DateRange selectedRange;
  final ValueChanged<_DateRange> onRangeChanged;
  final Color domainColor;

  const _DashboardControls({
    required this.selectedRange,
    required this.onRangeChanged,
    required this.domainColor,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final currency = ref.watch(currencyProvider).currency;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Currency indicator
        Row(
          children: [
            Icon(Icons.payments_rounded, size: 14, color: ThixPolicy.textSecondary),
            SizedBox(width: ThixPolicy.s6),
            Text(
              l10n.agencyDashboardCurrencyLabel,
              style: ThixPolicy.microStyle.copyWith(
                color: ThixPolicy.textSecondary,
                fontWeight: ThixPolicy.semiBold,
              ),
            ),
            SizedBox(width: ThixPolicy.s6),
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: ThixPolicy.s8,
                vertical: ThixPolicy.s2,
              ),
              decoration: BoxDecoration(
                color: domainColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(ThixPolicy.rXs),
              ),
              child: Text(
                '${currency.symbol} ${currency.code}',
                style: ThixPolicy.labelStyle.copyWith(
                  color: domainColor,
                  fontWeight: ThixPolicy.bold,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: ThixPolicy.s12),

        // Date range selector
        Container(
          padding: EdgeInsets.all(ThixPolicy.s4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(ThixPolicy.rMd),
            border: Border.all(color: ThixPolicy.border),
          ),
          child: Row(
            children: _DateRange.values.map((range) {
              final isSelected = range == selectedRange;
              return Expanded(
                child: _DateRangeChip(
                  label: _rangeLabel(l10n, range),
                  isSelected: isSelected,
                  domainColor: domainColor,
                  onTap: () => onRangeChanged(range),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  String _rangeLabel(dynamic l10n, _DateRange range) {
    try {
      switch (range) {
        case _DateRange.today:
          return l10n.agencyDashboardRangeToday;
        case _DateRange.week:
          return l10n.agencyDashboardRangeWeek;
        case _DateRange.month:
          return l10n.agencyDashboardRangeMonth;
        case _DateRange.all:
          return l10n.agencyDashboardRangeAll;
      }
    } catch (_) {
      return range.name;
    }
  }
}

class _DateRangeChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final Color domainColor;
  final VoidCallback onTap;

  const _DateRangeChip({
    required this.label,
    required this.isSelected,
    required this.domainColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(ThixPolicy.rSm),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.symmetric(vertical: ThixPolicy.s10),
          decoration: BoxDecoration(
            color: isSelected ? domainColor : Colors.transparent,
            borderRadius: BorderRadius.circular(ThixPolicy.rSm),
          ),
          child: Center(
            child: Text(
              label,
              style: ThixPolicy.labelStyle.copyWith(
                color: isSelected ? Colors.white : ThixPolicy.textMain,
                fontWeight: isSelected ? ThixPolicy.bold : ThixPolicy.medium,
                fontSize: 12,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// ============================================================================
/// _KpiGrid — Grille de 4 KPIs avec sparklines
/// ============================================================================
class _KpiGrid extends ConsumerWidget {
  final AgencyDashboardState state;
  final Color domainColor;

  const _KpiGrid({required this.state, required this.domainColor});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final currencyState = ref.watch(currencyProvider);

    final revenueDisplay = currencyState.convert(
      state.todayRevenue,
      fromCurrency: 'CDF',
    );
    final formattedRevenue = CurrencyFormatter.format(
      revenueDisplay,
      currency: currencyState.currency.code,
      compact: true,
    );

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _KpiCard(
                label: l10n.agencyDashboardKpiBookings,
                value: '${state.todayBookingsCount}',
                change: 12.5, // Mock : à remplacer par calcul réel
                icon: Icons.receipt_long_rounded,
                color: domainColor,
                sparkData: const [3, 5, 4, 7, 6, 8, 9],
              ),
            ),
            SizedBox(width: ThixPolicy.s10),
            Expanded(
              child: _KpiCard(
                label: l10n.agencyDashboardKpiRevenue,
                value: formattedRevenue,
                change: 8.2,
                icon: Icons.payments_rounded,
                color: ThixPolicy.success,
                sparkData: const [4, 6, 5, 8, 7, 9, 11],
              ),
            ),
          ],
        ),
        SizedBox(height: ThixPolicy.s10),
        Row(
          children: [
            Expanded(
              child: _KpiCard(
                label: l10n.agencyDashboardKpiTrips,
                value: '${state.myTrips.length}',
                change: 0,
                icon: Icons.directions_bus_rounded,
                color: ThixPolicy.primaryDeep,
                sparkData: const [5, 5, 6, 5, 6, 6, 7],
              ),
            ),
            SizedBox(width: ThixPolicy.s10),
            Expanded(
              child: _KpiCard(
                label: l10n.agencyDashboardKpiUpcoming,
                value: '${state.pendingDepartures}',
                change: -3.1,
                icon: Icons.schedule_rounded,
                color: ThixPolicy.warning,
                sparkData: const [8, 7, 6, 7, 5, 4, 5],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String label;
  final String value;
  final double change;
  final IconData icon;
  final Color color;
  final List<int> sparkData;

  const _KpiCard({
    required this.label,
    required this.value,
    required this.change,
    required this.icon,
    required this.color,
    required this.sparkData,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isPositive = change > 0;
    final isNeutral = change == 0;

    return Semantics(
      label: '$label: $value',
      child: Container(
        padding: EdgeInsets.all(ThixPolicy.s14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(ThixPolicy.rMd),
          border: Border.all(color: ThixPolicy.border),
          boxShadow: ThixPolicy.shadowSoft(),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(ThixPolicy.s6),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(ThixPolicy.rXs),
                  ),
                  child: Icon(icon, color: color, size: 16),
                ),
                const Spacer(),
                // Sparkline
                SizedBox(
                  width: 50,
                  height: 24,
                  child: _MiniSparkline(data: sparkData, color: color),
                ),
              ],
            ),
            SizedBox(height: ThixPolicy.s10),
            Text(
              value,
              style: ThixPolicy.h2Style.copyWith(
                fontWeight: ThixPolicy.bold,
                fontSize: 20,
                color: ThixPolicy.textMain,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: ThixPolicy.s2),
            Text(
              label,
              style: ThixPolicy.microStyle.copyWith(
                color: ThixPolicy.textSecondary,
                fontWeight: ThixPolicy.medium,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: ThixPolicy.s6),
            if (!isNeutral)
              Row(
                children: [
                  Icon(
                    isPositive
                        ? Icons.trending_up_rounded
                        : Icons.trending_down_rounded,
                    size: 12,
                    color: isPositive ? ThixPolicy.success : ThixPolicy.danger,
                  ),
                  SizedBox(width: ThixPolicy.s2),
                  Text(
                    '${isPositive ? "+" : ""}${change.toStringAsFixed(1)}%',
                    style: ThixPolicy.microStyle.copyWith(
                      color: isPositive ? ThixPolicy.success : ThixPolicy.danger,
                      fontWeight: ThixPolicy.bold,
                    ),
                  ),
                  SizedBox(width: ThixPolicy.s4),
                  Text(
                    l10n.agencyDashboardVsLastPeriod,
                    style: ThixPolicy.microStyle.copyWith(
                      color: ThixPolicy.textMuted,
                    ),
                  ),
                ],
              )
            else
              Text(
                l10n.agencyDashboardNoChange,
                style: ThixPolicy.microStyle.copyWith(
                  color: ThixPolicy.textMuted,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// ============================================================================
/// _MiniSparkline — Mini graphique de tendance
/// ============================================================================
class _MiniSparkline extends StatelessWidget {
  final List<int> data;
  final Color color;

  const _MiniSparkline({required this.data, required this.color});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const SizedBox.shrink();

    final spots = <FlSpot>[];
    final max = data.reduce(math.max).toDouble();
    final min = data.reduce(math.min).toDouble();
    final range = max - min == 0 ? 1.0 : max - min;

    for (var i = 0; i < data.length; i++) {
      spots.add(FlSpot(
        i.toDouble(),
        ((data[i] - min) / range) * 20,
      ));
    }

    return LineChart(
      LineChartData(
        lineTouchData: const LineTouchData(enabled: false),
        gridData: const FlGridData(show: false),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        minY: 0,
        maxY: 22,
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.3,
            color: color,
            barWidth: 2,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: color.withValues(alpha: 0.15),
            ),
          ),
        ],
      ),
      duration: const Duration(milliseconds: 400),
    );
  }
}

/// ============================================================================
/// _RevenueChartSection — Graphique des revenus
/// ============================================================================
class _RevenueChartSection extends ConsumerWidget {
  final AgencyDashboardState state;
  final Color domainColor;

  const _RevenueChartSection({required this.state, required this.domainColor});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final currencyState = ref.watch(currencyProvider);

    // Mock data : 7 derniers jours
    final mockData = [125000, 180000, 145000, 220000, 195000, 260000, 310000];
    final days = _getLast7Days(context);

    final spots = <BarChartGroupData>[];
    final maxVal = mockData.reduce(math.max).toDouble();

    for (var i = 0; i < mockData.length; i++) {
      final converted = currencyState.convert(
        mockData[i],
        fromCurrency: 'CDF',
      );
      spots.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: converted.toDouble(),
              color: i == mockData.length - 1 ? domainColor : domainColor.withValues(alpha: 0.4),
              width: 16,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: EdgeInsets.all(ThixPolicy.s16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ThixPolicy.rLg),
        border: Border.all(color: ThixPolicy.border),
        boxShadow: ThixPolicy.shadowSoft(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(ThixPolicy.s6),
                decoration: BoxDecoration(
                  color: domainColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(ThixPolicy.rXs),
                ),
                child: Icon(Icons.bar_chart_rounded, size: 14, color: domainColor),
              ),
              SizedBox(width: ThixPolicy.s8),
              Expanded(
                child: Text(
                  l10n.agencyDashboardRevenueChart,
                  style: ThixPolicy.titleStyle.copyWith(
                    fontWeight: ThixPolicy.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: ThixPolicy.s8,
                  vertical: ThixPolicy.s2,
                ),
                decoration: BoxDecoration(
                  color: ThixPolicy.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(ThixPolicy.rXs),
                ),
                child: Text(
                  '+24.5%',
                  style: ThixPolicy.microStyle.copyWith(
                    color: ThixPolicy.success,
                    fontWeight: ThixPolicy.bold,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: ThixPolicy.s16),
          SizedBox(
            height: 180,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxVal * 1.15,
                barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => ThixPolicy.inkDeep,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final val = rod.toY.toInt();
                      final formatted = CurrencyFormatter.format(
                        val,
                        currency: currencyState.currency.code,
                        compact: true,
                      );
                      return BarTooltipItem(
                        formatted,
                        TextStyle(
                          color: Colors.white,
                          fontWeight: ThixPolicy.bold,
                          fontSize: 11,
                        ),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx < 0 || idx >= days.length) return const SizedBox.shrink();
                        return Padding(
                          padding: EdgeInsets.only(top: ThixPolicy.s6),
                          child: Text(
                            days[idx],
                            style: ThixPolicy.microStyle.copyWith(
                              color: ThixPolicy.textSecondary,
                              fontSize: 9.5,
                            ),
                          ),
                        );
                      },
                      reservedSize: 24,
                    ),
                  ),
                ),
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                barGroups: spots,
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<String> _getLast7Days(BuildContext context) {
    final locale = Localizations.localeOf(context).toString();
    final fmt = DateFormat('EEE', locale);
    final now = DateTime.now();
    return List.generate(7, (i) {
      final d = now.subtract(Duration(days: 6 - i));
      return fmt.format(d);
    });
  }
}

/// ============================================================================
/// _BookingsDistributionSection — Donut chart des réservations par statut
/// ============================================================================
class _BookingsDistributionSection extends StatelessWidget {
  final AgencyDashboardState state;
  final Color domainColor;

  const _BookingsDistributionSection({
    required this.state,
    required this.domainColor,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    // Calcul des stats par statut
    int confirmed = 0, pending = 0, cancelled = 0, completed = 0;
    for (final b in state.agencyBookings) {
      switch (b.status.toLowerCase()) {
        case 'confirmed':
          confirmed++;
          break;
        case 'pending':
          pending++;
          break;
        case 'cancelled':
          cancelled++;
          break;
        case 'completed':
          completed++;
          break;
      }
    }

    final total = confirmed + pending + cancelled + completed;
    if (total == 0) {
      return _EmptySection(
        icon: Icons.pie_chart_outline_rounded,
        title: l10n.agencyDashboardNoBookings,
        subtitle: l10n.agencyDashboardNoBookingsHint,
        domainColor: domainColor,
      );
    }

    final data = [
      _DonutSegment(
        label: l10n.agencyDashboardStatusConfirmed,
        value: confirmed.toDouble(),
        color: ThixPolicy.success,
      ),
      _DonutSegment(
        label: l10n.agencyDashboardStatusPending,
        value: pending.toDouble(),
        color: ThixPolicy.warning,
      ),
      _DonutSegment(
        label: l10n.agencyDashboardStatusCompleted,
        value: completed.toDouble(),
        color: domainColor,
      ),
      _DonutSegment(
        label: l10n.agencyDashboardStatusCancelled,
        value: cancelled.toDouble(),
        color: ThixPolicy.danger,
      ),
    ].where((s) => s.value > 0).toList();

    return Container(
      padding: EdgeInsets.all(ThixPolicy.s16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ThixPolicy.rLg),
        border: Border.all(color: ThixPolicy.border),
        boxShadow: ThixPolicy.shadowSoft(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(ThixPolicy.s6),
                decoration: BoxDecoration(
                  color: domainColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(ThixPolicy.rXs),
                ),
                child: Icon(Icons.pie_chart_rounded, size: 14, color: domainColor),
              ),
              SizedBox(width: ThixPolicy.s8),
              Text(
                l10n.agencyDashboardBookingDistribution,
                style: ThixPolicy.titleStyle.copyWith(
                  fontWeight: ThixPolicy.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          SizedBox(height: ThixPolicy.s16),
          Row(
            children: [
              SizedBox(
                width: 120,
                height: 120,
                child: PieChart(
                  PieChartData(
                    sections: data.map((s) {
                      return PieChartSectionData(
                        value: s.value,
                        color: s.color,
                        radius: 25,
                        showTitle: false,
                      );
                    }).toList(),
                    centerSpaceRadius: 35,
                    sectionsSpace: 2,
                  ),
                  duration: const Duration(milliseconds: 400),
                ),
              ),
              SizedBox(width: ThixPolicy.s16),
              Expanded(
                child: Column(
                  children: data.map((s) {
                    final percent = ((s.value / total) * 100).toStringAsFixed(0);
                    return Padding(
                      padding: EdgeInsets.only(bottom: ThixPolicy.s8),
                      child: Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: s.color,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                          SizedBox(width: ThixPolicy.s8),
                          Expanded(
                            child: Text(
                              s.label,
                              style: ThixPolicy.bodySmallStyle.copyWith(
                                color: ThixPolicy.textMain,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            '${s.value.toInt()} ($percent%)',
                            style: ThixPolicy.bodySmallStyle.copyWith(
                              fontWeight: ThixPolicy.bold,
                              color: ThixPolicy.textMain,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DonutSegment {
  final String label;
  final double value;
  final Color color;

  const _DonutSegment({
    required this.label,
    required this.value,
    required this.color,
  });
}

/// ============================================================================
/// _QuickActionsSection — Actions rapides (grid)
/// ============================================================================
class _QuickActionsSection extends StatelessWidget {
  final AgencyDashboardState state;
  final Color domainColor;

  const _QuickActionsSection({required this.state, required this.domainColor});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    final actions = [
      _QuickAction(
        label: l10n.agencyDashboardActionNewTrip,
        icon: Icons.add_road_rounded,
        color: domainColor,
        route: '/agency/trip/create',
      ),
      _QuickAction(
        label: l10n.agencyDashboardActionScan,
        icon: Icons.qr_code_scanner_rounded,
        color: ThixPolicy.domainJobs,
        route: '/agency/scan',
      ),
      _QuickAction(
        label: l10n.agencyDashboardActionSeats,
        icon: Icons.event_seat_rounded,
        color: ThixPolicy.domainOpportunity,
        route: state.myTrips.isNotEmpty
            ? '/agency/seats/${state.myTrips.first.id}'
            : null,
      ),
      _QuickAction(
        label: l10n.agencyDashboardActionSettings,
        icon: Icons.settings_rounded,
        color: ThixPolicy.textSecondary,
        route: '/agency/onboarding',
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: EdgeInsets.all(ThixPolicy.s6),
              decoration: BoxDecoration(
                color: domainColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(ThixPolicy.rXs),
              ),
              child: Icon(Icons.bolt_rounded, size: 14, color: domainColor),
            ),
            SizedBox(width: ThixPolicy.s8),
            Text(
              l10n.agencyDashboardQuickActions,
              style: ThixPolicy.titleStyle.copyWith(
                fontWeight: ThixPolicy.bold,
                fontSize: 15,
              ),
            ),
          ],
        ),
        SizedBox(height: ThixPolicy.s12),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 4,
          crossAxisSpacing: ThixPolicy.s8,
          mainAxisSpacing: ThixPolicy.s8,
          childAspectRatio: 0.9,
          children: actions
              .map((a) => _QuickActionTile(action: a))
              .toList(),
        ),
      ],
    );
  }
}

class _QuickAction {
  final String label;
  final IconData icon;
  final Color color;
  final String? route;

  const _QuickAction({
    required this.label,
    required this.icon,
    required this.color,
    required this.route,
  });
}

class _QuickActionTile extends StatelessWidget {
  final _QuickAction action;

  const _QuickActionTile({required this.action});

  @override
  Widget build(BuildContext context) {
    final isEnabled = action.route != null;

    return Semantics(
      button: true,
      enabled: isEnabled,
      label: action.label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isEnabled
              ? () {
                  HapticFeedback.lightImpact();
                  context.push(action.route!);
                }
              : null,
          borderRadius: BorderRadius.circular(ThixPolicy.rMd),
          child: Container(
            padding: EdgeInsets.all(ThixPolicy.s10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(ThixPolicy.rMd),
              border: Border.all(color: ThixPolicy.border),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: EdgeInsets.all(ThixPolicy.s8),
                  decoration: BoxDecoration(
                    color: action.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(ThixPolicy.rSm),
                  ),
                  child: Icon(
                    action.icon,
                    size: 20,
                    color: isEnabled ? action.color : ThixPolicy.textMuted,
                  ),
                ),
                SizedBox(height: ThixPolicy.s6),
                Text(
                  action.label,
                  style: ThixPolicy.microStyle.copyWith(
                    color: isEnabled ? ThixPolicy.textMain : ThixPolicy.textMuted,
                    fontWeight: ThixPolicy.semiBold,
                    fontSize: 10,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// ============================================================================
/// _UpcomingTripsSection — Trajets à venir avec filtres
/// ============================================================================
class _UpcomingTripsSection extends StatelessWidget {
  final AgencyDashboardState state;
  final _TripFilter filter;
  final ValueChanged<_TripFilter> onFilterChanged;
  final Color domainColor;

  const _UpcomingTripsSection({
    required this.state,
    required this.filter,
    required this.onFilterChanged,
    required this.domainColor,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    final filtered = state.myTrips.where((t) {
      switch (filter) {
        case _TripFilter.all:
          return true;
        case _TripFilter.scheduled:
          return t.status == 'scheduled';
        case _TripFilter.departed:
          return t.status == 'departed';
        case _TripFilter.cancelled:
          return t.status == 'cancelled';
      }
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: EdgeInsets.all(ThixPolicy.s6),
              decoration: BoxDecoration(
                color: domainColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(ThixPolicy.rXs),
              ),
              child: Icon(Icons.directions_bus_rounded, size: 14, color: domainColor),
            ),
            SizedBox(width: ThixPolicy.s8),
            Text(
              l10n.agencyDashboardUpcomingTrips,
              style: ThixPolicy.titleStyle.copyWith(
                fontWeight: ThixPolicy.bold,
                fontSize: 15,
              ),
            ),
            const Spacer(),
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: ThixPolicy.s8,
                vertical: ThixPolicy.s2,
              ),
              decoration: BoxDecoration(
                color: domainColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(ThixPolicy.rFull),
              ),
              child: Text(
                '${filtered.length}',
                style: ThixPolicy.labelStyle.copyWith(
                  color: domainColor,
                  fontWeight: ThixPolicy.bold,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: ThixPolicy.s12),

        // Filter chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: _TripFilter.values.map((f) {
              return Padding(
                padding: EdgeInsets.only(right: ThixPolicy.s6),
                child: _FilterChip(
                  label: _filterLabel(l10n, f),
                  isSelected: f == filter,
                  domainColor: domainColor,
                  onTap: () => onFilterChanged(f),
                ),
              );
            }).toList(),
          ),
        ),
        SizedBox(height: ThixPolicy.s12),

        if (filtered.isEmpty)
          _EmptySection(
            icon: Icons.directions_bus_outlined,
            title: l10n.agencyDashboardNoTrips,
            subtitle: l10n.agencyDashboardNoTripsHint,
            domainColor: domainColor,
          )
        else
          ...filtered.take(5).map((t) => Padding(
                padding: EdgeInsets.only(bottom: ThixPolicy.s8),
                child: _TripCard(
                  trip: t,
                  onTap: () => context.push('/agency/seats/${t.id}'),
                  domainColor: domainColor,
                ),
              )),

        if (filtered.length > 5)
          Padding(
            padding: EdgeInsets.only(top: ThixPolicy.s8),
            child: Center(
              child: TextButton(
                onPressed: () {
                  // TODO: naviguer vers page complète des trajets
                },
                child: Text(
                  l10n.agencyDashboardSeeAllTrips(filtered.length),
                  style: ThixPolicy.labelStyle.copyWith(
                    color: domainColor,
                    fontWeight: ThixPolicy.bold,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  String _filterLabel(dynamic l10n, _TripFilter f) {
    try {
      switch (f) {
        case _TripFilter.all:
          return l10n.agencyDashboardFilterAll;
        case _TripFilter.scheduled:
          return l10n.agencyDashboardFilterScheduled;
        case _TripFilter.departed:
          return l10n.agencyDashboardFilterDeparted;
        case _TripFilter.cancelled:
          return l10n.agencyDashboardFilterCancelled;
      }
    } catch (_) {
      return f.name;
    }
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final Color domainColor;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.domainColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(ThixPolicy.rFull),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: EdgeInsets.symmetric(
            horizontal: ThixPolicy.s12,
            vertical: ThixPolicy.s6,
          ),
          decoration: BoxDecoration(
            color: isSelected ? domainColor : Colors.white,
            borderRadius: BorderRadius.circular(ThixPolicy.rFull),
            border: Border.all(
              color: isSelected ? domainColor : ThixPolicy.border,
            ),
          ),
          child: Text(
            label,
            style: ThixPolicy.labelStyle.copyWith(
              color: isSelected ? Colors.white : ThixPolicy.textMain,
              fontWeight: isSelected ? ThixPolicy.bold : ThixPolicy.medium,
              fontSize: 11.5,
            ),
          ),
        ),
      ),
    );
  }
}

class _TripCard extends ConsumerWidget {
  final BusTripModel trip;
  final VoidCallback onTap;
  final Color domainColor;

  const _TripCard({
    required this.trip,
    required this.onTap,
    required this.domainColor,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currencyState = ref.watch(currencyProvider);
    final l10n = context.l10n;

    final displayPrice = currencyState.convert(
      trip.priceFcfa,
      fromCurrency: 'CDF',
    );
    final formattedPrice = CurrencyFormatter.format(
      displayPrice,
      currency: currencyState.currency.code,
      compact: true,
    );

    final statusColor = _getTripStatusColor(trip.status);
    final locale = Localizations.localeOf(context).toString();
    final dateStr = DateFormat('d MMM • HH:mm', locale).format(trip.departureTime);

    final occupancyRate = trip.totalSeats > 0
        ? ((trip.totalSeats - trip.availableSeats) / trip.totalSeats * 100)
        : 0.0;

    return Semantics(
      button: true,
      label: '${trip.departureCity} vers ${trip.arrivalCity}, $formattedPrice',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(ThixPolicy.rMd),
          child: Container(
            padding: EdgeInsets.all(ThixPolicy.s14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(ThixPolicy.rMd),
              border: Border.all(color: ThixPolicy.border),
              boxShadow: ThixPolicy.shadowSoft(),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(ThixPolicy.s8),
                      decoration: BoxDecoration(
                        color: domainColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(ThixPolicy.rSm),
                      ),
                      child: Icon(
                        Icons.directions_bus_rounded,
                        color: domainColor,
                        size: 18,
                      ),
                    ),
                    SizedBox(width: ThixPolicy.s12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${trip.departureCity} → ${trip.arrivalCity}',
                            style: ThixPolicy.bodyStyle.copyWith(
                              fontWeight: ThixPolicy.bold,
                              color: ThixPolicy.textMain,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: ThixPolicy.s2),
                          Row(
                            children: [
                              Icon(
                                Icons.access_time_rounded,
                                size: 11,
                                color: ThixPolicy.textSecondary,
                              ),
                              SizedBox(width: ThixPolicy.s2),
                              Text(
                                dateStr,
                                style: ThixPolicy.microStyle.copyWith(
                                  color: ThixPolicy.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          formattedPrice,
                          style: ThixPolicy.bodySmallStyle.copyWith(
                            fontWeight: ThixPolicy.bold,
                            color: domainColor,
                          ),
                        ),
                        SizedBox(height: ThixPolicy.s2),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: ThixPolicy.s6,
                            vertical: ThixPolicy.s2,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(ThixPolicy.rXs),
                          ),
                          child: Text(
                            trip.status.toUpperCase(),
                            style: ThixPolicy.microStyle.copyWith(
                              color: statusColor,
                              fontWeight: ThixPolicy.bold,
                              fontSize: 9,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                SizedBox(height: ThixPolicy.s10),

                // Progress bar (remplissage)
                Row(
                  children: [
                    Icon(
                      Icons.event_seat_rounded,
                      size: 12,
                      color: ThixPolicy.textSecondary,
                    ),
                    SizedBox(width: ThixPolicy.s4),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(ThixPolicy.rXs),
                        child: LinearProgressIndicator(
                          value: occupancyRate / 100,
                          backgroundColor: ThixPolicy.surfaceStrong,
                          valueColor: AlwaysStoppedAnimation(
                            occupancyRate > 80
                                ? ThixPolicy.warning
                                : domainColor,
                          ),
                          minHeight: 6,
                        ),
                      ),
                    ),
                    SizedBox(width: ThixPolicy.s8),
                    Text(
                      l10n.agencyDashboardSeatsInfo(
                        trip.totalSeats - trip.availableSeats,
                        trip.totalSeats,
                      ),
                      style: ThixPolicy.microStyle.copyWith(
                        color: ThixPolicy.textSecondary,
                        fontWeight: ThixPolicy.semiBold,
                      ),
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

  Color _getTripStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'scheduled':
        return ThixPolicy.success;
      case 'departed':
        return ThixPolicy.info;
      case 'cancelled':
        return ThixPolicy.danger;
      default:
        return ThixPolicy.textMuted;
    }
  }
}

/// ============================================================================
/// _RecentBookingsSection — Réservations récentes
/// ============================================================================
class _RecentBookingsSection extends StatelessWidget {
  final AgencyDashboardState state;
  final Color domainColor;

  const _RecentBookingsSection({required this.state, required this.domainColor});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: EdgeInsets.all(ThixPolicy.s6),
              decoration: BoxDecoration(
                color: domainColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(ThixPolicy.rXs),
              ),
              child: Icon(Icons.receipt_long_rounded, size: 14, color: domainColor),
            ),
            SizedBox(width: ThixPolicy.s8),
            Text(
              l10n.agencyDashboardRecentBookings,
              style: ThixPolicy.titleStyle.copyWith(
                fontWeight: ThixPolicy.bold,
                fontSize: 15,
              ),
            ),
            const Spacer(),
            if (state.agencyBookings.isNotEmpty)
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: ThixPolicy.s8,
                  vertical: ThixPolicy.s2,
                ),
                decoration: BoxDecoration(
                  color: domainColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(ThixPolicy.rFull),
                ),
                child: Text(
                  '${state.agencyBookings.length}',
                  style: ThixPolicy.labelStyle.copyWith(
                    color: domainColor,
                    fontWeight: ThixPolicy.bold,
                    fontSize: 11,
                  ),
                ),
              ),
          ],
        ),
        SizedBox(height: ThixPolicy.s12),

        if (state.agencyBookings.isEmpty)
          _EmptySection(
            icon: Icons.confirmation_number_outlined,
            title: l10n.agencyDashboardNoBookings,
            subtitle: l10n.agencyDashboardNoBookingsRecentHint,
            domainColor: domainColor,
          )
        else
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(ThixPolicy.rMd),
              border: Border.all(color: ThixPolicy.border),
            ),
            child: Column(
              children: state.agencyBookings.take(5).map((b) {
                return _BookingTile(
                  booking: b,
                  domainColor: domainColor,
                );
              }).toList(),
            ),
          ),
      ],
    );
  }
}

class _BookingTile extends ConsumerWidget {
  final BookingModel booking;
  final Color domainColor;

  const _BookingTile({required this.booking, required this.domainColor});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currencyState = ref.watch(currencyProvider);

    final displayPrice = currencyState.convert(
      booking.totalPriceFcfa,
      fromCurrency: 'CDF',
    );
    final formattedPrice = CurrencyFormatter.format(
      displayPrice,
      currency: currencyState.currency.code,
      compact: true,
    );

    final statusInfo = _getBookingStatusInfo(booking.status);

    return Container(
      padding: EdgeInsets.all(ThixPolicy.s12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: ThixPolicy.border)),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(ThixPolicy.s8),
            decoration: BoxDecoration(
              color: statusInfo.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(ThixPolicy.rSm),
            ),
            child: Icon(
              statusInfo.icon,
              size: 16,
              color: statusInfo.color,
            ),
          ),
          SizedBox(width: ThixPolicy.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  booking.passengerName ?? 'Passager',
                  style: ThixPolicy.bodySmallStyle.copyWith(
                    fontWeight: ThixPolicy.bold,
                    color: ThixPolicy.textMain,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: ThixPolicy.s2),
                Text(
                  '${booking.seats.join(", ")} • ID ${booking.id.substring(0, 8).toUpperCase()}',
                  style: ThixPolicy.microStyle.copyWith(
                    color: ThixPolicy.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formattedPrice,
                style: ThixPolicy.bodySmallStyle.copyWith(
                  fontWeight: ThixPolicy.bold,
                  color: domainColor,
                ),
              ),
              SizedBox(height: ThixPolicy.s2),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: ThixPolicy.s6,
                  vertical: ThixPolicy.s2,
                ),
                decoration: BoxDecoration(
                  color: statusInfo.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(ThixPolicy.rXs),
                ),
                child: Text(
                  statusInfo.label,
                  style: ThixPolicy.microStyle.copyWith(
                    color: statusInfo.color,
                    fontWeight: ThixPolicy.bold,
                    fontSize: 9,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  _BookingStatusInfo _getBookingStatusInfo(String status) {
    switch (status.toLowerCase()) {
      case 'confirmed':
        return _BookingStatusInfo(
          icon: Icons.check_circle_rounded,
          color: ThixPolicy.success,
          label: 'CONFIRMÉ',
        );
      case 'pending':
        return _BookingStatusInfo(
          icon: Icons.schedule_rounded,
          color: ThixPolicy.warning,
          label: 'EN ATTENTE',
        );
      case 'completed':
        return _BookingStatusInfo(
          icon: Icons.history_rounded,
          color: ThixPolicy.textSecondary,
          label: 'UTILISÉ',
        );
      case 'cancelled':
        return _BookingStatusInfo(
          icon: Icons.cancel_rounded,
          color: ThixPolicy.danger,
          label: 'ANNULÉ',
        );
      default:
        return _BookingStatusInfo(
          icon: Icons.help_outline_rounded,
          color: ThixPolicy.textMuted,
          label: status.toUpperCase(),
        );
    }
  }
}

class _BookingStatusInfo {
  final IconData icon;
  final Color color;
  final String label;

  const _BookingStatusInfo({
    required this.icon,
    required this.color,
    required this.label,
  });
}

/// ============================================================================
/// _EmptySection — Vue vide réutilisable
/// ============================================================================
class _EmptySection extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color domainColor;

  const _EmptySection({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.domainColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(ThixPolicy.s24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ThixPolicy.rMd),
        border: Border.all(color: ThixPolicy.border),
      ),
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: domainColor.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 28, color: domainColor),
          ),
          SizedBox(height: ThixPolicy.s12),
          Text(
            title,
            style: ThixPolicy.bodySmallStyle.copyWith(
              fontWeight: ThixPolicy.bold,
              color: ThixPolicy.textMain,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: ThixPolicy.s4),
          Text(
            subtitle,
            style: ThixPolicy.microStyle.copyWith(
              color: ThixPolicy.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// ============================================================================
/// _TripFab — Floating Action Button
/// ============================================================================
class _TripFab extends StatelessWidget {
  final Color domainColor;
  const _TripFab({required this.domainColor});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return FloatingActionButton.extended(
      backgroundColor: domainColor,
      onPressed: () {
        HapticFeedback.mediumImpact();
        context.push('/agency/trip/create');
      },
      icon: const Icon(Icons.add_road_rounded, color: Colors.white, size: 18),
      label: Text(
        l10n.agencyDashboardNewTrip,
        style: ThixPolicy.labelStyle.copyWith(
          color: Colors.white,
          fontWeight: ThixPolicy.bold,
        ),
      ),
      elevation: 4,
    );
  }
}

/// ============================================================================
/// _NoAgencyView — Vue si pas d'agence
/// ============================================================================
class _NoAgencyView extends StatelessWidget {
  final Color domainColor;
  const _NoAgencyView({required this.domainColor});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      backgroundColor: ThixPolicy.surface,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          l10n.agencyDashboardTitle,
          style: ThixPolicy.titleStyle.copyWith(fontWeight: ThixPolicy.bold),
        ),
      ),
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(ThixPolicy.s24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: domainColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.storefront_rounded,
                  size: 48,
                  color: domainColor,
                ),
              ),
              SizedBox(height: ThixPolicy.s20),
              Text(
                l10n.agencyDashboardNoAgencyTitle,
                style: ThixPolicy.h3Style.copyWith(
                  fontWeight: ThixPolicy.bold,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: ThixPolicy.s8),
              Text(
                l10n.agencyDashboardNoAgencyMessage,
                style: ThixPolicy.bodySmallStyle.copyWith(
                  color: ThixPolicy.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: ThixPolicy.s28),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: () => context.go('/agency/onboarding'),
                  icon: const Icon(Icons.add_business_rounded),
                  label: Text(l10n.agencyDashboardCreateAgency),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: domainColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(ThixPolicy.rMd),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ============================================================================
/// _DashboardSkeleton — Skeleton loader complet
/// ============================================================================
class _DashboardSkeleton extends StatefulWidget {
  const _DashboardSkeleton();

  @override
  State<_DashboardSkeleton> createState() => _DashboardSkeletonState();
}

class _DashboardSkeletonState extends State<_DashboardSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (ctx, _) {
        final alpha = (0.5 + (_ctrl.value * 0.3)).clamp(0.0, 1.0);
        final color = ThixPolicy.surfaceStrong.withValues(alpha: alpha);

        return ListView(
          padding: EdgeInsets.all(ThixPolicy.s16),
          children: [
            _SkeletonBox(height: 48, color: color),
            SizedBox(height: ThixPolicy.s16),
            Row(
              children: [
                Expanded(child: _SkeletonBox(height: 120, color: color)),
                SizedBox(width: ThixPolicy.s10),
                Expanded(child: _SkeletonBox(height: 120, color: color)),
              ],
            ),
            SizedBox(height: ThixPolicy.s10),
            Row(
              children: [
                Expanded(child: _SkeletonBox(height: 120, color: color)),
                SizedBox(width: ThixPolicy.s10),
                Expanded(child: _SkeletonBox(height: 120, color: color)),
              ],
            ),
            SizedBox(height: ThixPolicy.s20),
            _SkeletonBox(height: 220, color: color),
            SizedBox(height: ThixPolicy.s20),
            _SkeletonBox(height: 180, color: color),
          ],
        );
      },
    );
  }
}

class _SkeletonBox extends StatelessWidget {
  final double height;
  final Color color;
  const _SkeletonBox({required this.height, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(ThixPolicy.rMd),
      ),
    );
  }
}

/// ============================================================================
/// _ExportSheet — Sheet d'export
/// ============================================================================
class _ExportSheet extends StatelessWidget {
  final void Function(String format) onExport;

  const _ExportSheet({required this.onExport});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Container(
      padding: EdgeInsets.fromLTRB(
        ThixPolicy.s20,
        ThixPolicy.s16,
        ThixPolicy.s20,
        MediaQuery.of(context).viewInsets.bottom + ThixPolicy.s20,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(ThixPolicy.r2Xl),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: ThixPolicy.border,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          SizedBox(height: ThixPolicy.s20),
          Text(
            l10n.agencyDashboardExportTitle,
            style: ThixPolicy.titleStyle.copyWith(
              fontWeight: ThixPolicy.bold,
              fontSize: 16,
            ),
          ),
          SizedBox(height: ThixPolicy.s20),
          _ExportOption(
            icon: Icons.picture_as_pdf_rounded,
            label: l10n.agencyDashboardExportPdf,
            subtitle: l10n.agencyDashboardExportPdfDesc,
            color: ThixPolicy.danger,
            onTap: () => onExport('pdf'),
          ),
          SizedBox(height: ThixPolicy.s8),
          _ExportOption(
            icon: Icons.table_chart_rounded,
            label: l10n.agencyDashboardExportCsv,
            subtitle: l10n.agencyDashboardExportCsvDesc,
            color: ThixPolicy.success,
            onTap: () => onExport('csv'),
          ),
        ],
      ),
    );
  }
}

class _ExportOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ExportOption({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(ThixPolicy.rMd),
        child: Container(
          padding: EdgeInsets.all(ThixPolicy.s14),
          decoration: BoxDecoration(
            color: ThixPolicy.surfaceSoft,
            borderRadius: BorderRadius.circular(ThixPolicy.rMd),
            border: Border.all(color: ThixPolicy.border),
          ),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(ThixPolicy.s10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(ThixPolicy.rSm),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              SizedBox(width: ThixPolicy.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: ThixPolicy.bodySmallStyle.copyWith(
                        fontWeight: ThixPolicy.bold,
                      ),
                    ),
                    SizedBox(height: ThixPolicy.s2),
                    Text(
                      subtitle,
                      style: ThixPolicy.microStyle.copyWith(
                        color: ThixPolicy.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: ThixPolicy.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ============================================================================
/// AnimatedBuilder — Polyfill
/// ============================================================================
class AnimatedBuilder extends AnimatedWidget {
  final Widget Function(BuildContext, Widget?) builder;
  final Widget? child;

  const AnimatedBuilder({
    super.key,
    required super.listenable,
    required this.builder,
    this.child,
  });

  @override
  Widget build(BuildContext context) => builder(context, child);
}
