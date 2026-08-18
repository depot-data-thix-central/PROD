import 'dart:convert';

class OpportunityApplication {
  final String id;
  final String opportunityId;
  final String applicantThixId;
  final String? message;
  final DateTime createdAt;
  final DateTime updatedAt;

  const OpportunityApplication({
    required this.id,
    required this.opportunityId,
    required this.applicantThixId,
    required this.message,
    required this.createdAt,
    required this.updatedAt,
  });

  OpportunityApplication copyWith({
    String? id,
    String? opportunityId,
    String? applicantThixId,
    String? message,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return OpportunityApplication(
      id: id ?? this.id,
      opportunityId: opportunityId ?? this.opportunityId,
      applicantThixId: applicantThixId ?? this.applicantThixId,
      message: message ?? this.message,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'opportunity_id': opportunityId,
      'applicant_thix_id': applicantThixId,
      'message': message,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  static OpportunityApplication fromJson(Map<String, dynamic> json) {
    DateTime parseDate(Object? v) {
      if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
      return DateTime.now();
    }

    return OpportunityApplication(
      id: (json['id'] ?? '').toString(),
      opportunityId: (json['opportunity_id'] ?? '').toString(),
      applicantThixId: (json['applicant_thix_id'] ?? '').toString(),
      message: (json['message'] ?? '').toString().trim().isEmpty ? null : (json['message'] ?? '').toString(),
      createdAt: parseDate(json['created_at']),
      updatedAt: parseDate(json['updated_at']),
    );
  }

  static String encodeList(List<OpportunityApplication> items) => jsonEncode(items.map((e) => e.toJson()).toList(growable: false));

  static List<OpportunityApplication> decodeList(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const [];
    return decoded.whereType<Map>().map((m) => OpportunityApplication.fromJson(m.cast<String, dynamic>())).toList(growable: false);
  }
}
