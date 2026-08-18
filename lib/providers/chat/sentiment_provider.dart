// 📁 lib/providers/chat/sentiment_provider.dart

import 'package:flutter/material.dart';
import '../../models/chat/sentiment.dart';
import '../../services/chat/sentiment_service.dart';

class SentimentProvider extends ChangeNotifier {
  final SentimentService _service = SentimentService();

  SentimentResult? _lastResult;
  bool _isAnalyzing = false;
  String? _error;

  // ─── GETTERS ────────────────────────────────────────────────

  SentimentResult? get lastResult => _lastResult;
  bool get isAnalyzing => _isAnalyzing;
  String? get error => _error;

  // ─── ANALYSER UN MESSAGE ──────────────────────────────────

  Future<SentimentResult?> analyzeMessage(String text) async {
    if (text.trim().isEmpty) return null;

    _setLoading(true);
    try {
      final result = await _service.analyze(text);
      _lastResult = result;
      _setLoading(false);
      return result;
    } catch (e) {
      _error = e.toString();
      _setLoading(false);
      return null;
    }
  }

  // ─── ANALYSER UNE CONVERSATION ─────────────────────────────

  Future<Map<String, dynamic>?> analyzeConversation(List<String> messages) async {
    if (messages.isEmpty) return null;

    _setLoading(true);
    try {
      final result = await _service.analyzeConversation(messages);
      _setLoading(false);
      return result;
    } catch (e) {
      _error = e.toString();
      _setLoading(false);
      return null;
    }
  }

  void _setLoading(bool loading) {
    _isAnalyzing = loading;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
