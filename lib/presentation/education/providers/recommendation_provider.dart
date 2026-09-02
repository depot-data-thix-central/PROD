// lib/presentation/education/providers/recommendation_provider.dart
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:thix_id/presentation/education/models/recommendation.dart';

/// État des recommandations (immutable)
class RecommendationsState {
  final List<Recommendation> recommendations;
  final bool isLoading;
  final String? error;
  final bool isInitialized;

  const RecommendationsState({
    this.recommendations = const [],
    this.isLoading = false,
    this.error,
    this.isInitialized = false,
  });

  RecommendationsState copyWith({
    List<Recommendation>? recommendations,
    bool? isLoading,
    String? error,
    bool? isInitialized,
  }) {
    return RecommendationsState(
      recommendations: recommendations ?? this.recommendations,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      isInitialized: isInitialized ?? this.isInitialized,
    );
  }
}

/// Notifier Riverpod pour gérer les recommandations
class RecommendationNotifier extends StateNotifier<RecommendationsState> {
  final SupabaseClient _client;

  RecommendationNotifier({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client,
        super(const RecommendationsState());

  /// Charge les recommandations depuis Supabase
  Future<void> loadRecommendations(String userId) async {
    if (state.isLoading) {
      debugPrint('[Recommendations] ⏳ Already loading, skipping');
      return;
    }

    debugPrint('[Recommendations] 🚀 Loading for user '
        '${userId.substring(0, 8)}...');

    state = state.copyWith(isLoading: true, error: null);

    try {
      final response = await _client
          .from('recommendations')
          .select('''
            id,
            user_id,
            formation_id,
            reason,
            score,
            created_at,
            formations!inner (
              id,
              title,
              description,
              duration,
              level,
              thumbnail_url
            )
          ''')
          .eq('user_id', userId)
          .order('score', ascending: false)
          .limit(50);

      // ✅ CORRECTION ICI : Cast explicite pour éviter l'erreur List<dynamic>
      final recommendations = (response as List<dynamic>)
          .map<Recommendation>((row) => Recommendation.fromMap(row as Map<String, dynamic>))
          .toList();

      state = state.copyWith(
        recommendations: recommendations,
        isLoading: false,
        isInitialized: true,
      );

      debugPrint('[Recommendations] ✓ Loaded ${recommendations.length} items');
    } catch (e, stackTrace) {
      debugPrint('[Recommendations] ❌ Load failed: $e');
      if (kDebugMode) {
        debugPrint('[Recommendations] Stack: '
            '${stackTrace.toString().split('\n').first}');
      }
      state = state.copyWith(
        isLoading: false,
        error: 'Impossible de charger les recommandations',
        isInitialized: true,
      );
    }
  }

  /// Rafraîchit les recommandations
  Future<void> refresh() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      debugPrint('[Recommendations] ⚠️ No user logged in');
      return;
    }
    await loadRecommendations(userId);
  }

  /// Réinitialise l'état (logout)
  void reset() {
    state = const RecommendationsState();
  }
}

/// Provider Riverpod principal
final recommendationProvider =
    StateNotifierProvider<RecommendationNotifier, RecommendationsState>(
  (ref) => RecommendationNotifier(),
);
