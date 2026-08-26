import 'package:flutter/foundation.dart';

enum FinanceTransactionType { income, expense, capital }
enum FinanceSector { saas, commerce, agriculture, industry, service, fintech }

@immutable
class FinanceTransaction {
  const FinanceTransaction({
    required this.id,
    required this.projectCode,
    required this.type,
    required this.category,
    required this.amount,
    required this.currency,
    this.description,
    this.date,
    this.createdAt,
  });
  final String id;
  final String projectCode;
  final FinanceTransactionType type;
  final String category; // Marketing, Salaries, Equipment, Sales...
  final double amount;
  final String currency;
  final String? description;
  final DateTime? date;
  final DateTime? createdAt;

  factory FinanceTransaction.fromJson(Map<String,dynamic> j) => FinanceTransaction(
    id: j['id'].toString(),
    projectCode: j['project_code'].toString(),
    type: FinanceTransactionType.values.firstWhere((e)=> e.name == j['type'], orElse: ()=> FinanceTransactionType.expense),
    category: j['category'].toString(),
    amount: (j['amount'] as num).toDouble(),
    currency: j['currency']?.toString() ?? 'USD',
    description: j['description'] as String?,
    date: j['date'] != null ? DateTime.tryParse(j['date'].toString()) : null,
    createdAt: j['created_at'] != null ? DateTime.tryParse(j['created_at'].toString()) : null,
  );
  Map<String,dynamic> toJson() => {
    'project_code': projectCode, 'type': type.name, 'category': category,
    'amount': amount, 'currency': currency, 'description': description,
    'date': (date ?? DateTime.now()).toIso8601String(),
  };
}

@immutable
class FinancialSnapshot {
  const FinancialSnapshot({
    required this.projectCode,
    required this.treasury,
    required this.burnRate,
    required this.runwayMonths,
    required this.mrr,
    required this.arr,
    required this.revenueMonthly,
    required this.expensesMonthly,
    required this.sector,
    this.cac, this.ltv, this.churnRate, this.grossMargin,
    this.stockValue, this.averageBasket,
  });
  final String projectCode;
  final double treasury; final double burnRate; final double runwayMonths;
  final double mrr; final double arr; final double revenueMonthly; final double expensesMonthly;
  final FinanceSector sector;
  final double? cac; final double? ltv; final double? churnRate; final double? grossMargin;
  final double? stockValue; final double? averageBasket;

  factory FinancialSnapshot.fromJson(Map<String,dynamic> j) => FinancialSnapshot(
    projectCode: j['project_code'].toString(),
    treasury: (j['treasury'] as num).toDouble(),
    burnRate: (j['burn_rate'] as num).toDouble(),
    runwayMonths: (j['runway_months'] as num).toDouble(),
    mrr: (j['mrr'] as num?)?.toDouble() ?? 0,
    arr: (j['arr'] as num?)?.toDouble() ?? 0,
    revenueMonthly: (j['revenue_monthly'] as num?)?.toDouble() ?? 0,
    expensesMonthly: (j['expenses_monthly'] as num?)?.toDouble() ?? 0,
    sector: FinanceSector.values.firstWhere((e)=> e.name == j['sector'], orElse: ()=> FinanceSector.service),
    cac: (j['cac'] as num?)?.toDouble(), ltv: (j['ltv'] as num?)?.toDouble(),
    churnRate: (j['churn_rate'] as num?)?.toDouble(), grossMargin: (j['gross_margin'] as num?)?.toDouble(),
    stockValue: (j['stock_value'] as num?)?.toDouble(), averageBasket: (j['average_basket'] as num?)?.toDouble(),
  );

  Map<String,dynamic> sectorKpis() {
    switch(sector) {
      case FinanceSector.saas: case FinanceSector.fintech:
        return {'MRR': mrr, 'ARR': arr, 'CAC': cac??0, 'LTV': ltv??0, 'Churn': '${churnRate??0}%', 'Burn': burnRate};
      case FinanceSector.commerce:
        return {'CA': revenueMonthly, 'Marge': '${grossMargin??0}%', 'Panier': averageBasket??0, 'Stock': stockValue??0, 'Burn': burnRate};
      case FinanceSector.agriculture:
        return {'Production': revenueMonthly, 'Coût/unité': cac??0, 'Marge': '${grossMargin??0}%', 'Rendement': ltv??0};
      case FinanceSector.industry:
        return {'Capacité': '${grossMargin??0}%', 'Coût matière': cac??0, 'Marge': '${grossMargin??0}%', 'Production': revenueMonthly};
      default:
        return {'Revenus': revenueMonthly, 'Dépenses': expensesMonthly, 'Marge': '${grossMargin??0}%', 'Burn': burnRate};
    }
  }
}

@immutable
class FinancialScenario {
  const FinancialScenario({required this.name, required this.ca, required this.marginPercent, required this.runwayMonths, required this.burnRate});
  final String name; final double ca; final double marginPercent; final double runwayMonths; final double burnRate;
  factory FinancialScenario.prudent(double baseCa, double baseBurn, double treasury) => FinancialScenario(name:'Prudent', ca: baseCa*0.6, marginPercent: 18, runwayMonths: treasury / (baseBurn*1.2), burnRate: baseBurn*1.2);
  factory FinancialScenario.normal(double baseCa, double baseBurn, double treasury) => FinancialScenario(name:'Normal', ca: baseCa, marginPercent: 27, runwayMonths: treasury / baseBurn, burnRate: baseBurn);
  factory FinancialScenario.optimiste(double baseCa, double baseBurn, double treasury) => FinancialScenario(name:'Optimiste', ca: baseCa*1.6, marginPercent: 34, runwayMonths: treasury / (baseBurn*0.8), burnRate: baseBurn*0.8);
}
