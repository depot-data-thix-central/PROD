import 'dart:math';
import '../constants/thix_ia_execution_constants.dart';

class ExecutionUtils {
  static double calculateRunway({required double treasury, required double burnRate}) {
    if(burnRate <= 0) return double.infinity;
    return treasury / burnRate;
  }
  static double calculateBurnRate(List<Map<String,dynamic>> last3MonthsExpenses) {
    if(last3MonthsExpenses.isEmpty) return 0;
    final total = last3MonthsExpenses.fold<double>(0, (s,e)=> s + (e['amount'] as num).toDouble());
    return total / last3MonthsExpenses.length;
  }
  static double calculateProgress({required num current, required num target}) {
    if(target == 0) return 0;
    return (current / target * 100).clamp(0, 100).toDouble();
  }
  static int calculateHealthScore(Map<String,double> dimensions) {
    double score = 0;
    ThixExecutionConstants.healthWeights.forEach((k,w){
      score += (dimensions[k]?? 0) * w;
    });
    return score.round().clamp(0, 100);
  }
  static String generateTaskId(String projectCode) {
    return '${projectCode}_TASK_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(9999)}';
  }
  static String formatCurrency(double amount, {String currency='\$'}) {
    return '$currency ${amount.toStringAsFixed(2).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m)=> '${m[1]},')}';
  }
  static Map<String,dynamic> buildNextBestAction({required double healthScore, required List tasksLate, required List goalsAtRisk, required double runway}) {
    if(runway < 3) return {'title':'Sécuriser la trésorerie','reason':'Runway < 3 mois','priority':'critical'};
    if(tasksLate.length > 3) return {'title':'Rattraper ${tasksLate.length} tâches en retard','reason':'Risque d\'échéance','priority':'high'};
    if(goalsAtRisk.isNotEmpty) return {'title':'Valider ${goalsAtRisk.first}','reason':'Objectif à risque','priority':'high'};
    if(healthScore < 60) return {'title':'Améliorer la conformité','reason':'Health $healthScore%','priority':'medium'};
    return {'title':'Valider la demande auprès de 20 clients','reason':'Hypothèse commerciale non validée','priority':'medium'};
  }
}
