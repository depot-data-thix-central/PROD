// lib/presentation/thix_money/models/loan_model.dart
class LoanModel {
  final String id;
  final String thixId; // lié au THIX ID
  final int amount;
  final int remaining;
  final String statut; // en_cours, paye, en_retard
  final String devise;
  final double interestRate;
  final DateTime createdAt;

  LoanModel({
    required this.id,
    required this.thixId,
    required this.amount,
    required this.remaining,
    required this.statut,
    required this.devise,
    required this.interestRate,
    required this.createdAt,
  });

  factory LoanModel.fromJson(Map<String, dynamic> j) => LoanModel(
    id: j['id'],
    thixId: j['thix_id'],
    amount: (j['amount'] as num).toInt(),
    remaining: (j['remaining'] as num).toInt(),
    statut: j['statut'],
    devise: j['devise'] ?? 'CDF',
    interestRate: (j['interest_rate'] as num).toDouble(),
    createdAt: DateTime.parse(j['created_at']),
  );

  double get progress => amount == 0 ? 0 : 1 - (remaining / amount);
}
