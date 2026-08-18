// lib/presentation/mon_pays/models/province_budget.dart

class ProvinceBudgetPriority {
  final String id;
  final String provinceId;
  final int year;
  final String title;
  final String? description;
  final double? allocatedAmount;
  final String? pdfUrl;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  ProvinceBudgetPriority({
    required this.id,
    required this.provinceId,
    required this.year,
    required this.title,
    this.description,
    this.allocatedAmount,
    this.pdfUrl,
    this.createdAt,
    this.updatedAt,
  });

  factory ProvinceBudgetPriority.fromJson(Map<String, dynamic> json) {
    return ProvinceBudgetPriority(
      id: json['id'] as String,
      provinceId: json['province_id'] as String,
      year: json['year'] as int,
      title: json['title'] as String,
      description: json['description'] as String?,
      allocatedAmount: json['allocated_amount'] != null ? (json['allocated_amount'] as num).toDouble() : null,
      pdfUrl: json['pdf_url'] as String?,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'province_id': provinceId,
    'year': year,
    'title': title,
    'description': description,
    'allocated_amount': allocatedAmount,
    'pdf_url': pdfUrl,
  };
}
