// models/enrollment.dart
import 'formation.dart';

class Enrollment {
  final String id;
  final String formationId;
  final String userId;
  final DateTime enrolledAt;
  String status; // 'active', 'completed', 'cancelled'
  double progress;
  double amountPaid;
  final String? paymentId;
  DateTime? completedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Formation? formation;

  Enrollment({
    required this.id,
    required this.formationId,
    required this.userId,
    required this.enrolledAt,
    this.status = 'active',
    this.progress = 0.0,
    this.amountPaid = 0.0,
    this.paymentId,
    this.completedAt,
    this.createdAt,
    this.updatedAt,
    this.formation,
  });

  factory Enrollment.fromJson(Map<String, dynamic> json) => Enrollment(
        id: json['id'],
        formationId: json['formation_id'],
        userId: json['user_id'],
        enrolledAt: DateTime.parse(json['enrolled_at']),
        status: json['status'] ?? 'active',
        progress: (json['progress'] as num?)?.toDouble() ?? 0.0,
        amountPaid: (json['amount_paid'] as num?)?.toDouble() ?? 0.0,
        paymentId: json['payment_id'],
        completedAt: json['completed_at'] != null
            ? DateTime.parse(json['completed_at'])
            : null,
        createdAt: json['created_at'] != null
            ? DateTime.parse(json['created_at'])
            : null,
        updatedAt: json['updated_at'] != null
            ? DateTime.parse(json['updated_at'])
            : null,
        formation: json['formation'] != null
            ? Formation.fromJson(json['formation'])
            : null,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'formation_id': formationId,
        'user_id': userId,
        'enrolled_at': enrolledAt.toIso8601String(),
        'status': status,
        'progress': progress,
        'amount_paid': amountPaid,
        'payment_id': paymentId,
        'completed_at': completedAt?.toIso8601String(),
        'created_at': createdAt?.toIso8601String(),
        'updated_at': updatedAt?.toIso8601String(),
      };

  Enrollment copyWith({
    String? status,
    double? progress,
    double? amountPaid,
    DateTime? completedAt,
    Formation? formation,
  }) =>
      Enrollment(
        id: id,
        formationId: formationId,
        userId: userId,
        enrolledAt: enrolledAt,
        status: status ?? this.status,
        progress: progress ?? this.progress,
        amountPaid: amountPaid ?? this.amountPaid,
        paymentId: paymentId,
        completedAt: completedAt ?? this.completedAt,
        createdAt: createdAt,
        updatedAt: updatedAt,
        formation: formation ?? this.formation,
      );
}
