import 'dart:convert';

/// 📋 Modèle d'opportunité (bourse, emploi, subvention, concours…)
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

  /// URL de l'image/logo de l'opportunité (Supabase Storage).
  /// Le nom du champ Dart est `imageAssetPath` pour compatibilité avec le code
  /// existant, mais la clé JSON/DB est bien `image_url`.
  final String? imageAssetPath;

  /// Statut de publication : 'published' | 'countdown' | 'draft' | 'archived'
  final String status;

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
    this.status = 'published', // ⬅️ VALEUR PAR DÉFAUT
    required this.createdAt,
    required this.updatedAt,
  });

  // ─── GETTERS ───
  bool get isPublished => status == 'published' || status == 'countdown';
  bool get isDraft => status == 'draft';
  bool get isArchived => status == 'archived';

  // ─── COPYWITH ───
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
    String? status,
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
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // ─── SÉRIALISATION ───
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
      'image_url': imageAssetPath, // ⬅️ CLÉ JSON = 'image_url' (aligné DB)
      'status': status, // ⬅️ AJOUT
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  static OpportunityItem fromJson(Map<String, dynamic> json) {
    DateTime parseDate(Object? v) {
      if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
      if (v is DateTime) return v;
      return DateTime.now();
    }

    String str(Object? v) => (v ?? '').toString();

    // ⬅️ Lecture image : priorité à image_url (DB), fallback image_asset_path (ancien cache)
    final rawImg = json['image_url'] ?? json['image_asset_path'];
    final img = (rawImg ?? '').toString().trim();

    return OpportunityItem(
      id: str(json['id']),
      title: str(json['title']),
      organizer: str(json['organizer']),
      location: str(json['location']),
      category: str(json['category']),
      rewardLabel: str(json['reward_label']),
      deadlineLabel: str(json['deadline_label']),
      deadline: parseDate(json['deadline']),
      description: str(json['description']),
      eligibility: (json['eligibility'] is List)
          ? (json['eligibility'] as List)
              .map((e) => e.toString())
              .toList(growable: false)
          : const <String>[],
      applyUrl: str(json['apply_url']).isEmpty ? null : str(json['apply_url']),
      imageAssetPath: img.isEmpty ? null : img,
      status: str(json['status']).isEmpty ? 'published' : str(json['status']), // ⬅️ AJOUT
      createdAt: parseDate(json['created_at']),
      updatedAt: parseDate(json['updated_at']),
    );
  }

  static String encodeList(List<OpportunityItem> items) =>
      jsonEncode(items.map((e) => e.toJson()).toList(growable: false));

  static List<OpportunityItem> decodeList(String raw) {
    if (raw.trim().isEmpty) return const [];
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const [];
    return decoded
        .whereType<Map>()
        .map((m) => OpportunityItem.fromJson(m.cast<String, dynamic>()))
        .toList(growable: false);
  }
}
