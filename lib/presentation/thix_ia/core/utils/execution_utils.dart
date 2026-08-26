import 'dart:math';
import '../constants/thix_ia_execution_constants.dart';
import '../../models/execution_finance.dart'; 

class ExecutionUtils {
  static double calculateRunway({
    required double treasury,
    required double burnRate,
  }) {
    if (burnRate <= 0) return 0;
    return treasury / burnRate;
  }

  static double calculateBurnRate(
      List<Map<String, dynamic>> last3MonthsExpenses) {
    if (last3MonthsExpenses.isEmpty) return 0;
    final total = last3MonthsExpenses.fold<double>(
      0,
      (s, e) => s + (e['amount'] as num).toDouble(),
    );
    return total / last3MonthsExpenses.length;
  }

  /// Calcule trésorerie, burn, runway, mrr à partir des transactions réelles
  static Map<String, double> computeFinanceFromTransactions(
    List<FinanceTransaction> transactions,
  ) {
    double treasury = 0;
    double totalIncome = 0;
    double totalExpense = 0;
    double capital = 0;

    final now = DateTime.now();
    final thirtyDaysAgo = now.subtract(const Duration(days: 30));

    double expenseLast30 = 0;
    double incomeLast30 = 0;

    for (final tx in transactions) {
      final amount = tx.amount;
      final date = tx.date ?? tx.createdAt ?? now;

      switch (tx.type) {
        case FinanceTransactionType.income:
          treasury += amount;
          totalIncome += amount;
          if (date.isAfter(thirtyDaysAgo)) {
            incomeLast30 += amount;
          }
          break;
        case FinanceTransactionType.capital:
          treasury += amount;
          capital += amount;
          break;
        case FinanceTransactionType.expense:
          treasury -= amount;
          totalExpense += amount;
          if (date.isAfter(thirtyDaysAgo)) {
            expenseLast30 += amount;
          }
          break;
      }
    }

    final burn = expenseLast30 > 0
        ? expenseLast30
        : (totalExpense > 0 ? totalExpense : 0.0);

    final mrr = incomeLast30 > 0 ? incomeLast30 : totalIncome;

    final runway = burn > 0
        ? (treasury / burn)
        : (treasury > 0 ? 99.0 : 0.0);

    return {
      'treasury': treasury,
      'burnRate': burn,
      'runwayMonths': runway.clamp(0, 999),
      'mrr': mrr,
      'revenueMonthly': mrr,
      'expensesMonthly': burn,
      'capital': capital,
    };
  }

  static double calculateProgress({
    required num current,
    required num target,
  }) {
    if (target == 0) return 0;
    return (current / target * 100).clamp(0, 100).toDouble();
  }

  static int calculateHealthScore(Map<String, double> dimensions) {
    double score = 0;
    ThixExecutionConstants.healthWeights.forEach((k, w) {
      score += (dimensions[k] ?? 0) * w;
    });
    return score.round().clamp(0, 100);
  }

  static String generateTaskId(String projectCode) {
    final ts = DateTime.now().millisecondsSinceEpoch;
    final rnd = Random().nextInt(9999);
    return '\( {projectCode}_TASK_ \){ts}_$rnd';
  }

  static String formatCurrency(double amount, {String currency = r'$'}) {
    final formatted = amount.toStringAsFixed(2).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
    return '$currency $formatted';
  }

  static Map<String, dynamic> buildNextBestAction({
    required double healthScore,
    required List tasksLate,
    required List goalsAtRisk,
    required double runway,
  }) {
    if (runway < 3 && runway > 0) {
      return {
        'title': 'Sécuriser la trésorerie',
        'reason': 'Runway < 3 mois',
        'priority': 'critical',
      };
    }
    if (tasksLate.length > 3) {
      return {
        'title': 'Rattraper ${tasksLate.length} tâches en retard',
        'reason': 'Risque d échéance',
        'priority': 'high',
      };
    }
    if (goalsAtRisk.isNotEmpty) {
      return {
        'title': 'Valider ${goalsAtRisk.first}',
        'reason': 'Objectif à risque',
        'priority': 'high',
      };
    }
    if (healthScore < 60) {
      return {
        'title': 'Améliorer la conformité',
        'reason': 'Health $healthScore%',
        'priority': 'medium',
      };
    }
    return {
      'title': 'Valider la demande auprès de 20 clients',
      'reason': 'Hypothèse commerciale non validée',
      'priority': 'medium',
    };
  }
}
