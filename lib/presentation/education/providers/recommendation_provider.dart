// lib/providers/recommendation_provider.dart
import 'package:flutter/material.dart';
import '../services/education_service.dart';
import '../models/recommendation.dart';

class RecommendationProvider extends ChangeNotifier {
  final EducationService _service;

  List<Recommendation> _recommendations = [];
  bool _isLoading = false;
  String? _error;

  // Getters
  List<Recommendation> get recommendations => _recommendations;
  bool get isLoading => _isLoading;
  String? get error => _error;

  RecommendationProvider(this._service);

  // ─── CHARGEMENT ──────────────────────────────────────────────────

  Future<void> loadRecommendations(String userId) async {
    _setLoading(true);
    try {
      _recommendations = await _service.getRecommendations(userId);
      _error = null;
    } catch (e) {
      _error = e.toString();
      debugPrint('Error loading recommendations: $e');
    } finally {
      _setLoading(false);
    }
  }

  // ─── UTILITAIRES ──────────────────────────────────────────────────

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void reset() {
    _recommendations = [];
    _error = null;
    _isLoading = false;
    notifyListeners();
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }
}
