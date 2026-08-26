// lib/presentation/thix_ia/models/previsionnel_12m.dart
import 'package:flutter/foundation.dart';

@immutable
class MonthlyForecast {
  const MonthlyForecast({
    required this.monthIndex, // 0 = M+1 ... 11 = M+12
    required this.label,      // "Sep 2026"
    required this.revenue,
    required this.cogs,
    required this.opex,
    required this.capex,
    required this.otherIn,
    required this.otherOut,
    required this.openingCash,
    required this.closingCash,
    required this.netCash,
  });

  final int monthIndex;
  final String label;
  final double revenue;
  final double cogs;
  final double opex;
  final double capex;
  final double otherIn;
  final double otherOut;
  final double openingCash;
  final double closingCash;
  final double netCash;

  double get grossMargin => revenue - cogs;
  double get operatingCash => revenue + otherIn - cogs - opex - otherOut;
  double get freeCashFlow => operatingCash - capex;

  Map<String, dynamic> toJson() => {
        'month_index': monthIndex,
        'label': label,
        'revenue': revenue,
        'cogs': cogs,
        'opex': opex,
        'capex': capex,
        'other_in': otherIn,
        'other_out': otherOut,
        'opening_cash': openingCash,
        'closing_cash': closingCash,
        'net_cash': netCash,
      };

  factory MonthlyForecast.fromJson(Map<String, dynamic> j) => MonthlyForecast(
        monthIndex: j['month_index'] as int,
        label: j['label'] as String,
        revenue: (j['revenue'] as num).toDouble(),
        cogs: (j['cogs'] as num).toDouble(),
        opex: (j['opex'] as num).toDouble(),
        capex: (j['capex'] as num).toDouble(),
        otherIn: (j['other_in'] as num).toDouble(),
        otherOut: (j['other_out'] as num).toDouble(),
        openingCash: (j['opening_cash'] as num).toDouble(),
        closingCash: (j['closing_cash'] as num).toDouble(),
        netCash: (j['net_cash'] as num).toDouble(),
      );
}

@immutable
class PrevisionnelAssumptions {
  const PrevisionnelAssumptions({
    required this.startingCash,
    required this.baseMonthlyRevenue,
    required this.revenueGrowthRate, // % mensuel
    required this.cogsPercent,        // % du CA
    required this.fixedOpex,
    required this.variableOpexPercent,
    required this.monthlyCapex,
    required this.scenarioMultiplier, // 0.7 = prudent, 1.0 = base, 1.4 = optimiste
    this.seasonality = const [1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0],
  });

  final double startingCash;
  final double baseMonthlyRevenue;
  final double revenueGrowthRate;
  final double cogsPercent;
  final double fixedOpex;
  final double variableOpexPercent;
  final double monthlyCapex;
  final double scenarioMultiplier;
  final List<double> seasonality; // 12 coefficients

  PrevisionnelAssumptions copyWith({
    double? startingCash,
    double? baseMonthlyRevenue,
    double? revenueGrowthRate,
    double? cogsPercent,
    double? fixedOpex,
    double? variableOpexPercent,
    double? monthlyCapex,
    double? scenarioMultiplier,
    List<double>? seasonality,
  }) =>
      PrevisionnelAssumptions(
        startingCash: startingCash ?? this.startingCash,
        baseMonthlyRevenue: baseMonthlyRevenue ?? this.baseMonthlyRevenue,
        revenueGrowthRate: revenueGrowthRate ?? this.revenueGrowthRate,
        cogsPercent: cogsPercent ?? this.cogsPercent,
        fixedOpex: fixedOpex ?? this.fixedOpex,
        variableOpexPercent: variableOpexPercent ?? this.variableOpexPercent,
        monthlyCapex: monthlyCapex ?? this.monthlyCapex,
        scenarioMultiplier: scenarioMultiplier ?? this.scenarioMultiplier,
        seasonality: seasonality ?? this.seasonality,
      );

  Map<String, dynamic> toJson() => {
        'starting_cash': startingCash,
        'base_monthly_revenue': baseMonthlyRevenue,
        'revenue_growth_rate': revenueGrowthRate,
        'cogs_percent': cogsPercent,
        'fixed_opex': fixedOpex,
        'variable_opex_percent': variableOpexPercent,
        'monthly_capex': monthlyCapex,
        'scenario_multiplier': scenarioMultiplier,
        'seasonality': seasonality,
      };

  factory PrevisionnelAssumptions.fromJson(Map<String, dynamic> j) =>
      PrevisionnelAssumptions(
        startingCash: (j['starting_cash'] as num).toDouble(),
        baseMonthlyRevenue: (j['base_monthly_revenue'] as num).toDouble(),
        revenueGrowthRate: (j['revenue_growth_rate'] as num).toDouble(),
        cogsPercent: (j['cogs_percent'] as num).toDouble(),
        fixedOpex: (j['fixed_opex'] as num).toDouble(),
        variableOpexPercent: (j['variable_opex_percent'] as num).toDouble(),
        monthlyCapex: (j['monthly_capex'] as num).toDouble(),
        scenarioMultiplier: (j['scenario_multiplier'] as num).toDouble(),
        seasonality: (j['seasonality'] as List<dynamic>?)
                ?.map((e) => (e as num).toDouble())
                .toList() ??
            List.filled(12, 1.0),
      );
}

@immutable
class Previsionnel12M {
  const Previsionnel12M({
    required this.projectCode,
    required this.assumptions,
    required this.months,
    required this.scenarioName,
    this.updatedAt,
  });

  final String projectCode;
  final PrevisionnelAssumptions assumptions;
  final List<MonthlyForecast> months; // toujours 12
  final String scenarioName; // "Base" | "Prudent" | "Optimiste"
  final DateTime? updatedAt;

  double get totalRevenue => months.fold(0.0, (s, m) => s + m.revenue);
  double get totalNetCash => months.last.closingCash - assumptions.startingCash;
  double get minCash => months.map((m) => m.closingCash).reduce((a, b) => a < b ? a : b);
  double get maxBurn => months.map((m) => m.netCash).where((n) => n < 0).fold(0.0, (s, n) => s + n.abs());

  factory Previsionnel12M.generate({
    required String projectCode,
    required PrevisionnelAssumptions assumptions,
    required String scenarioName,
    DateTime? startDate,
  }) {
    final start = startDate ?? DateTime.now();
    final months = <MonthlyForecast>[];
    double cash = assumptions.startingCash;

    for (int i = 0; i < 12; i++) {
      final date = DateTime(start.year, start.month + i + 1, 1);
      final label = '${_monthAbbr(date.month)} ${date.year}';
      final growthFactor = pow(1 + assumptions.revenueGrowthRate / 100, i);
      final season = assumptions.seasonality[i % 12];
      final revenue = assumptions.baseMonthlyRevenue *
          growthFactor *
          season *
          assumptions.scenarioMultiplier;

      final cogs = revenue * (assumptions.cogsPercent / 100);
      final opex = assumptions.fixedOpex +
          (revenue * (assumptions.variableOpexPercent / 100));
      final capex = assumptions.monthlyCapex;
      final otherIn = 0.0;
      final otherOut = 0.0;

      final net = revenue + otherIn - cogs - opex - capex - otherOut;
      final closing = cash + net;

      months.add(MonthlyForecast(
        monthIndex: i,
        label: label,
        revenue: revenue,
        cogs: cogs,
        opex: opex,
        capex: capex,
        otherIn: otherIn,
        otherOut: otherOut,
        openingCash: cash,
        closingCash: closing,
        netCash: net,
      ));
      cash = closing;
    }

    return Previsionnel12M(
      projectCode: projectCode,
      assumptions: assumptions,
      months: months,
      scenarioName: scenarioName,
      updatedAt: DateTime.now(),
    );
  }

  static String _monthAbbr(int m) {
    const names = ['Jan', 'Fév', 'Mar', 'Avr', 'Mai', 'Juin', 'Juil', 'Aoû', 'Sep', 'Oct', 'Nov', 'Déc'];
    return names[m - 1];
  }
}

double pow(num x, num exponent) {
  // simple power for growth
  var r = 1.0;
  for (var i = 0; i < exponent; i++) r *= x;
  return r;
}
