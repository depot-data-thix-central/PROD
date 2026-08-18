// 📁 lib/models/chat/sentiment.dart
import 'package:flutter/material.dart';

enum SentimentType {
  positive,
  neutral,
  negative,
  veryNegative,
}

class SentimentResult {
  final SentimentType sentiment;
  final double score; // -1.0 à +1.0
  final double confidence;
  final String? label;
  final Map<String, double>? probabilities;

  SentimentResult({
    required this.sentiment,
    required this.score,
    required this.confidence,
    this.label,
    this.probabilities,
  });

  factory SentimentResult.fromJson(Map<String, dynamic> json) {
    final score = (json['score'] ?? 0.0).toDouble();
    SentimentType type;
    if (score >= 0.3) type = SentimentType.positive;
    else if (score >= -0.1) type = SentimentType.neutral;
    else if (score >= -0.5) type = SentimentType.negative;
    else type = SentimentType.veryNegative;

    return SentimentResult(
      sentiment: type,
      score: score,
      confidence: (json['confidence'] ?? 0.0).toDouble(),
      label: json['label'],
      probabilities: json['probabilities']?.map(
        (k, v) => MapEntry(k, (v as num).toDouble()),
      ),
    );
  }

  Color get color {
    switch (sentiment) {
      case SentimentType.positive:
        return Colors.green;
      case SentimentType.neutral:
        return Colors.grey;
      case SentimentType.negative:
        return Colors.orange;
      case SentimentType.veryNegative:
        return Colors.red;
    }
  }

  IconData get icon {
    switch (sentiment) {
      case SentimentType.positive:
        return Icons.sentiment_very_satisfied;
      case SentimentType.neutral:
        return Icons.sentiment_neutral;
      case SentimentType.negative:
        return Icons.sentiment_dissatisfied;
      case SentimentType.veryNegative:
        return Icons.sentiment_very_dissatisfied;
    }
  }

  String get labelFr {
    switch (sentiment) {
      case SentimentType.positive:
        return 'Positif 😊';
      case SentimentType.neutral:
        return 'Neutre 😐';
      case SentimentType.negative:
        return 'Négatif 😟';
      case SentimentType.veryNegative:
        return 'Très négatif 😡';
    }
  }
}
