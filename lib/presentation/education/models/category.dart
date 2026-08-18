// models/category.dart
import 'formation.dart';

class Category {
  final String id;
  final String name;
  final String? icon;
  final DateTime? createdAt;

  // Relation
  List<Formation>? formations;

  Category({
    required this.id,
    required this.name,
    this.icon,
    this.createdAt,
    this.formations,
  });

  factory Category.fromJson(Map<String, dynamic> json) => Category(
        id: json['id'],
        name: json['name'],
        icon: json['icon'],
        createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
        formations: json['formations'] != null
            ? (json['formations'] as List).map((f) => Formation.fromJson(f)).toList()
            : null,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'icon': icon,
        'created_at': createdAt?.toIso8601String(),
      };

  Category copyWith({
    String? name,
    String? icon,
    List<Formation>? formations,
  }) =>
      Category(
        id: id,
        name: name ?? this.name,
        icon: icon ?? this.icon,
        createdAt: createdAt,
        formations: formations ?? this.formations,
      );
}
