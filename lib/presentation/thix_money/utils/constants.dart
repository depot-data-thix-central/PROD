// lib/presentation/thix_money/utils/constants.dart
import 'package:flutter/material.dart';

class ThixConstants {
  // Couleurs THIX MONEY
  static const primary = Color(0xFF1A3FFF);
  static const darkBlue = Color(0xFF0A2A8A);
  static const bg = Color(0xFFF6F8FF);
  static const gold = Color(0xFFFFC107);

  // Devises supportées - Franc Congolais et Dollar
  static const supportedDevises = ['CDF', 'USD'];
  
  // Limites sécurisées
  static const minCdf = 1000;
  static const maxCdf = 10000000; // 10M CDF
  static const minUsd = 1;
  static const maxUsd = 5000;

  // Pagination pour millions d'utilisateurs
  static const pageSize = 20;
  static const initialPage = 0;

  // Fonctions Supabase Edge
  static const wonyaFunctionInit = 'wonya-init';
  static const wonyaFunctionStatus = 'wonya-status';

  // Regex RDC
  static const phonePattern = r'^(0)(8|9|7)\d{8}$';
}
