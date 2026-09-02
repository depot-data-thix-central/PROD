// lib/presentation/education/models/recommendation.dart
import 'formation.dart';

class Recommendation {
  final String id;
  final String userId;
  final String formationId;
  final double score;
  final String? reason;
  final DateTime? createdAt;

  // Relation
  Formation? formation;

  Recommendation({
    required this.id,
    required this.userId,
    required this.formationId,
    this.score = 0.0,
    this.reason,
    this.createdAt,
    this.formation,
  });

  // ✅ Ajout de fromMap pour satisfaire le RecommendationProvider
  factory Recommendation.fromMap(Map<String, dynamic> map) => Recommendation(
        id: map['id'],
        userId: map['user_id'],
        formationId: map['formation_id'],
        score: (map['score'] as num?)?.toDouble() ?? 0.0,
        reason: map['reason'],
        createdAt: map['created_at'] != null ? DateTime.parse(map['created_at']) : null,
        // Assure-toi que Formation possède bien fromJson, sinon remplace par fromMap ici aussi
        formation: map['formation'] != null ? Formation.fromJson(map['formation']) : null, 
      );

  // Gardé pour la rétrocompatibilité avec le reste du code
  factory Recommendation.fromJson(Map<String, dynamic> json) => Recommendation.fromMap(json);

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'formation_id': formationId,
        'score': score,
        'reason': reason,
        'created_at': createdAt?.toIso8601String(),
      };

  Recommendation copyWith({
        double? score,
        String? reason,
        Formation? formation,
      }) =>
      Recommendation(
        id: id,
        userId: userId,
        formationId: formationId,
        score: score ?? this.score,
        reason: reason ?? this.reason,
        createdAt: createdAt,
        formation: formation ?? this.formation,
      );
}
