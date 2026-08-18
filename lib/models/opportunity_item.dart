import 'dart:convert';

class OpportunityItem {
  final String id;
  final String title;
  final String organizer;
  final String location;
  final String category;
  final String rewardLabel;
  final String deadlineLabel;
  final DateTime deadline;
  final String description;
  final List<String> eligibility;
  /// External link where the user completes the application.
  /// Example: https://example.com/apply
  final String? applyUrl;
  final String? imageAssetPath;
  final DateTime createdAt;
  final DateTime updatedAt;

  const OpportunityItem({
    required this.id,
    required this.title,
    required this.organizer,
    required this.location,
    required this.category,
    required this.rewardLabel,
    required this.deadlineLabel,
    required this.deadline,
    required this.description,
    required this.eligibility,
    required this.applyUrl,
    required this.imageAssetPath,
    required this.createdAt,
    required this.updatedAt,
  });

  OpportunityItem copyWith({
    String? id,
    String? title,
    String? organizer,
    String? location,
    String? category,
    String? rewardLabel,
    String? deadlineLabel,
    DateTime? deadline,
    String? description,
    List<String>? eligibility,
    String? applyUrl,
    String? imageAssetPath,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return OpportunityItem(
      id: id ?? this.id,
      title: title ?? this.title,
      organizer: organizer ?? this.organizer,
      location: location ?? this.location,
      category: category ?? this.category,
      rewardLabel: rewardLabel ?? this.rewardLabel,
      deadlineLabel: deadlineLabel ?? this.deadlineLabel,
      deadline: deadline ?? this.deadline,
      description: description ?? this.description,
      eligibility: eligibility ?? this.eligibility,
      applyUrl: applyUrl ?? this.applyUrl,
      imageAssetPath: imageAssetPath ?? this.imageAssetPath,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'organizer': organizer,
      'location': location,
      'category': category,
      'reward_label': rewardLabel,
      'deadline_label': deadlineLabel,
      'deadline': deadline.toIso8601String(),
      'description': description,
      'eligibility': eligibility,
      'apply_url': applyUrl,
      'image_asset_path': imageAssetPath,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  static OpportunityItem fromJson(Map<String, dynamic> json) {
    DateTime parseDate(Object? v) {
      if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
      return DateTime.now();
    }

    return OpportunityItem(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      organizer: (json['organizer'] ?? '').toString(),
      location: (json['location'] ?? '').toString(),
      category: (json['category'] ?? '').toString(),
      rewardLabel: (json['reward_label'] ?? '').toString(),
      deadlineLabel: (json['deadline_label'] ?? '').toString(),
      deadline: parseDate(json['deadline']),
      description: (json['description'] ?? '').toString(),
      eligibility: (json['eligibility'] is List)
          ? (json['eligibility'] as List).map((e) => e.toString()).toList(growable: false)
          : const <String>[],
      applyUrl: (json['apply_url'] ?? '').toString().trim().isEmpty ? null : (json['apply_url'] ?? '').toString(),
      imageAssetPath: (json['image_asset_path'] ?? '').toString().trim().isEmpty ? null : (json['image_asset_path'] ?? '').toString(),
      createdAt: parseDate(json['created_at']),
      updatedAt: parseDate(json['updated_at']),
    );
  }

  static String encodeList(List<OpportunityItem> items) => jsonEncode(items.map((e) => e.toJson()).toList(growable: false));

  static List<OpportunityItem> decodeList(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const [];
    return decoded.whereType<Map>().map((m) => OpportunityItem.fromJson(m.cast<String, dynamic>())).toList(growable: false);
  }
}
