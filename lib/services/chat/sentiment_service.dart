import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/chat/sentiment.dart';

class SentimentService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // ─── ANALYSE D'UN MESSAGE ──────────────────────────────────

  Future<SentimentResult> analyze(String text) async {
    final cleanText = _cleanText(text);
    if (cleanText.isEmpty) {
      return SentimentResult(
        sentiment: SentimentType.neutral,
        score: 0.0,
        confidence: 0.0,
        label: 'Texte vide',
      );
    }

    try {
      final response = await _supabase.functions.invoke(
        'analyze-sentiment',
        body: {
          'text': cleanText,
          'messageId': null,
        },
      );

      final data = response.data as Map<String, dynamic>?;
      if (data == null) {
        throw Exception('Réponse vide');
      }

      if (data['error'] != null) {
        throw Exception(data['error'] as String);
      }

      if (data['result'] == null) {
        throw Exception('Aucun résultat');
      }

      final result = data['result'] as Map<String, dynamic>;

      return SentimentResult(
        sentiment: _mapSentiment(result['sentiment']),
        score: (result['score'] as num).toDouble(),
        confidence: (result['confidence'] as num).toDouble(),
        label: '${result['provider'] ?? 'IA'}',
      );
    } catch (e) {
      print('❌ Erreur analyse sentiment: $e');
      return _analyzeWithRules(cleanText);
    }
  }

  // ─── ANALYSE + MISE À JOUR DIRECTE ──────────────────────────

  Future<void> analyzeAndUpdateMessage(String messageId, String text) async {
    try {
      await _supabase.functions.invoke(
        'analyze-sentiment',
        body: {
          'text': text,
          'messageId': messageId,
        },
      );
    } catch (e) {
      print('❌ Erreur analyse et mise à jour: $e');
    }
  }

  // ─── ANALYSE DE BATCH ───────────────────────────────────────

  Future<List<SentimentResult>> analyzeBatch(List<String> texts) async {
    final results = <SentimentResult>[];
    for (var text in texts) {
      final result = await analyze(text);
      results.add(result);
    }
    return results;
  }

  // ─── ANALYSE DE CONVERSATION ───────────────────────────────

  Future<Map<String, dynamic>> analyzeConversation(List<String> messages) async {
    if (messages.isEmpty) {
      return {
        'overall': SentimentType.neutral,
        'averageScore': 0.0,
        'total': 0,
        'positive': 0,
        'neutral': 0,
        'negative': 0,
        'veryNegative': 0,
      };
    }

    final results = await analyzeBatch(messages);
    final stats = {
      'total': results.length,
      'positive': results.where((r) => r.sentiment == SentimentType.positive).length,
      'neutral': results.where((r) => r.sentiment == SentimentType.neutral).length,
      'negative': results.where((r) => r.sentiment == SentimentType.negative).length,
      'veryNegative': results.where((r) => r.sentiment == SentimentType.veryNegative).length,
    };

    final avgScore = results.fold<double>(0, (sum, r) => sum + r.score) / results.length;
    final overall = _getOverallSentiment(avgScore);

    return {
      'overall': overall,
      'averageScore': avgScore,
      ...stats,
    };
  }

  // ─── RÈGLES (FALLBACK LOCAL) ────────────────────────────────

  SentimentResult _analyzeWithRules(String text) {
    final lower = text.toLowerCase();
    int score = 0;

    const positive = ['merci', 'super', 'génial', 'parfait', 'excellent', 'content', 'satisfait', 'heureux', 'bon', 'bien', 'top'];
    const negative = ['problème', 'erreur', 'bug', 'déçu', 'frustré', 'insatisfait', 'mauvais', 'nul', 'horrible', 'énervé', 'urgent'];
    const veryNegative = ['inadmissible', 'catastrophe', 'désastreux', 'incompétence', 'arnaque'];

    for (var w in positive) if (lower.contains(w)) score += 1;
    for (var w in negative) if (lower.contains(w)) score -= 1;
    for (var w in veryNegative) if (lower.contains(w)) score -= 2;

    double normalized = (score / 5).clamp(-1.0, 1.0);
    SentimentType type;
    if (normalized >= 0.3) type = SentimentType.positive;
    else if (normalized >= -0.1) type = SentimentType.neutral;
    else if (normalized >= -0.5) type = SentimentType.negative;
    else type = SentimentType.veryNegative;

    return SentimentResult(
      sentiment: type,
      score: normalized,
      confidence: 0.5,
      label: 'Règle',
    );
  }

  SentimentType _mapSentiment(String str) {
    switch (str) {
      case 'positive':
        return SentimentType.positive;
      case 'negative':
        return SentimentType.negative;
      case 'very_negative':
        return SentimentType.veryNegative;
      default:
        return SentimentType.neutral;
    }
  }

  SentimentType _getOverallSentiment(double avgScore) {
    if (avgScore >= 0.3) return SentimentType.positive;
    if (avgScore >= -0.1) return SentimentType.neutral;
    if (avgScore >= -0.5) return SentimentType.negative;
    return SentimentType.veryNegative;
  }

  String _cleanText(String text) {
    text = text.replaceAll(RegExp(r'https?://\S+'), '');
    text = text.replaceAll(RegExp(r'@\w+'), '');
    text = text.replaceAll(RegExp(r'#\w+'), '');
    text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    return text;
  }
}
