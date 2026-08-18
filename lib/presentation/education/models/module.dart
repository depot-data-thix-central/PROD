// models/module.dart
import 'lesson.dart';

class Module {
  final String id;
  final String formationId;
  final String title;
  final String? description;
  final int order;
  final DateTime? createdAt;

  // Relation
  List<Lesson>? lessons;

  Module({
    required this.id,
    required this.formationId,
    required this.title,
    this.description,
    this.order = 0,
    this.createdAt,
    this.lessons,
  });

  factory Module.fromJson(Map<String, dynamic> json) => Module(
        // 🌟 FIX : Sécurisation des types avec des valeurs de secours
        id: json['id'] as String? ?? '',
        formationId: json['formation_id'] as String? ?? '',
        title: json['title'] as String? ?? 'Module sans titre',
        description: json['description'] as String?,
        order: json['order'] as int? ?? 0,
        createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
        lessons: json['lessons'] != null
            ? (json['lessons'] as List).map((l) => Lesson.fromJson(l)).toList()
            : null,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'formation_id': formationId,
        'title': title,
        'description': description,
        'order': order,
        'created_at': createdAt?.toIso8601String(),
      };

  Module copyWith({
    String? title,
    String? description,
    int? order,
    List<Lesson>? lessons,
  }) =>
      Module(
        id: id,
        formationId: formationId,
        title: title ?? this.title,
        description: description ?? this.description,
        order: order ?? this.order,
        createdAt: createdAt,
        lessons: lessons ?? this.lessons,
      );
}
