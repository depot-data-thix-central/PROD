// lib/presentation/mon_pays/utils/validators.dart
// Validation des formulaires pour l'administration

import 'package:flutter/material.dart';

class MonPaysValidators {
  static String? validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Le nom est requis';
    }
    if (value.length < 2) {
      return 'Le nom doit contenir au moins 2 caractères';
    }
    return null;
  }

  static String? validateTitle(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Le titre est requis';
    }
    return null;
  }

  static String? validateUrl(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null; // Optionnel
    }
    final urlPattern = RegExp(
      r'^(http|https)://[a-zA-Z0-9\-\.]+\.[a-zA-Z]{2,}(/\S*)?$',
    );
    if (!urlPattern.hasMatch(value.trim())) {
      return 'URL invalide';
    }
    return null;
  }

  static String? validateDate(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null; // Optionnel
    }
    final datePattern = RegExp(r'^\d{4}-\d{2}-\d{2}$');
    if (!datePattern.hasMatch(value.trim())) {
      return 'Format invalide (AAAA-MM-JJ)';
    }
    return null;
  }

  static String? validatePhone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null; // Optionnel
    }
    final phonePattern = RegExp(r'^\+?[0-9]{8,15}$');
    if (!phonePattern.hasMatch(value.trim())) {
      return 'Numéro de téléphone invalide';
    }
    return null;
  }

  static String? validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null; // Optionnel
    }
    final emailPattern = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
    if (!emailPattern.hasMatch(value.trim())) {
      return 'Email invalide';
    }
    return null;
  }

  static String? validateNotEmpty(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName est requis';
    }
    return null;
  }
}
