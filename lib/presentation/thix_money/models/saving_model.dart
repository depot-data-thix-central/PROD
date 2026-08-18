// lib/presentation/thix_money/models/saving_model.dart
class SavingModel {
  final String id;
  final String thixId; // lié au THIX ID
  final String title;
  final int amount;
  final int goal;
  final String devise; // CDF / USD
  final DateTime createdAt;

  SavingModel({
    required this.id,
    required this.thixId,
    required this.title,
    required this.amount,
    required this.goal,
    required this.devise,
    required this.createdAt,
  });

  factory SavingModel.fromJson(Map<String, dynamic> j) => SavingModel(
    id: j['id'],
    thixId: j['thix_id'],
    title: j['title'],
    amount: (j['amount'] as num).toInt(),
    goal: (j['goal'] as num).toInt(),
    devise: j['devise'] ?? 'CDF',
    createdAt: DateTime.parse(j['created_at']),
  );

  double get progress => goal == 0 ? 0 : amount / goal;
}
