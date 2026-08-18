// lib/presentation/thix_weeding/models/program_item_model.dart
import 'package:flutter/foundation.dart';

@immutable
class ProgramItem {
  final String id;
  final String title;
  final String time;
  final String description;
  final String iconName;
  final bool isDone;

  const ProgramItem({
    required this.id,
    required this.title,
    required this.time,
    required this.description,
    required this.iconName,
    this.isDone = false,
  });

  factory ProgramItem.fromJson(Map<String, dynamic> json) {
    return ProgramItem(
      id: json['id'] as String,
      title: json['title'] as String,
      time: json['time'] as String,
      description: json['description'] as String? ?? '',
      iconName: json['icon'] as String? ?? 'event',
      isDone: json['is_done'] as bool? ?? false,
    );
  }
}
