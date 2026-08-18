// lib/presentation/mon_pays/utils/constants.dart
// Catégories, couleurs et constantes du module

import 'package:flutter/material.dart';

class MonPaysConstants {
  // Catégories des autorités
  static const List<String> authorityCategories = [
    'Tous',
    'Président de la République',
    'Présidence',
    'Gouvernement',
    'Parlement',
    'Sénat',
    'Assemblée Nationale',
    'Cour Constitutionnelle',
    'CSM',
    'CENI',
    'FARDC',
    'PNC',
    'Gouverneurs',
  ];

  // Couleurs des modules
  static const Map<String, Color> moduleColors = {
    'Autorités': Color(0xFF1A5276),
    'Figures Historiques': Color(0xFFE67E22),
    'À la Une': Color(0xFF27AE60),
    'Agences & Institutions': Color(0xFF8E44AD),
    'Vidéos Officielles': Color(0xFFE74C3C),
    'Documentaires': Color(0xFF2980B9),
    'Citoyens Exemplaires': Color(0xFF1ABC9C),
    'Valeurs & Lois': Color(0xFF2C3E50),
    'Participer': Color(0xFFF39C12),
    'Personnes recherchées': Color(0xFFE74C3C),
    'Recherche globale': Color(0xFF7F8C8D),
  };

  // Messages d'erreur
  static const String errorLoadingData = 'Erreur lors du chargement des données';
  static const String noDataFound = 'Aucune donnée trouvée';
  static const String networkError = 'Erreur de connexion réseau';
  static const String unauthorized = 'Vous n\'êtes pas autorisé à effectuer cette action';

  // Clés de stockage
  static const String favoritesKey = 'mon_pays_favorites';
  static const String cacheKey = 'mon_pays_cache';
}
