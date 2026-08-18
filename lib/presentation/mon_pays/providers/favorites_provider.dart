// lib/presentation/mon_pays/providers/favorites_provider.dart
// Gestion des favoris avec SharedPreferences

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';

final favoritesProvider = StateNotifierProvider<FavoritesNotifier, Set<String>>((ref) {
  return FavoritesNotifier();
});

class FavoritesNotifier extends StateNotifier<Set<String>> {
  FavoritesNotifier() : super({}) {
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(MonPaysConstants.favoritesKey) ?? [];
      state = Set.from(list);
    } catch (e) {
      state = {};
    }
  }

  Future<void> toggleFavorite(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (state.contains(id)) {
        state = state.difference({id});
      } else {
        state = {...state, id};
      }
      await prefs.setStringList(MonPaysConstants.favoritesKey, state.toList());
    } catch (e) {
      // Gérer l'erreur
    }
  }

  bool isFavorite(String id) => state.contains(id);

  Future<void> clearFavorites() async {
    try {
      state = {};
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(MonPaysConstants.favoritesKey);
    } catch (e) {
      // Gérer l'erreur
    }
  }
}
