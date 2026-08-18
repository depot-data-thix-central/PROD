// lib/presentation/mon_pays/utils/helpers.dart
// Fonctions utilitaires du module

import 'package:flutter/material.dart';

class MonPaysHelpers {
  // Formater une date
  static String formatDate(DateTime? date) {
    if (date == null) return '';
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 365) {
      return '${(difference.inDays / 365).floor()} ans';
    } else if (difference.inDays > 30) {
      return '${(difference.inDays / 30).floor()} mois';
    } else if (difference.inDays > 7) {
      return '${(difference.inDays / 7).floor()} semaines';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} jours';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} heures';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minutes';
    } else {
      return 'À l\'instant';
    }
  }

  // Tronquer un texte avec ...
  static String truncateText(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}...';
  }

  // Valider une URL
  static bool isValidUrl(String url) {
    final pattern = RegExp(
      r'^(http|https)://[a-zA-Z0-9\-\.]+\.[a-zA-Z]{2,}(/\S*)?$',
    );
    return pattern.hasMatch(url);
  }

  // Générer une couleur à partir d'un nom
  static Color getColorFromName(String name) {
    final colors = [
      Colors.red,
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.pink,
      Colors.indigo,
    ];
    final index = name.hashCode.abs() % colors.length;
    return colors[index];
  }

  // Obtenir les initiales d'un nom
  static String getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '';
  }
}
