import 'package:flutter/material.dart';

class CreatePostColors {
  CreatePostColors._();

  static const navyDeep = Color(0xFF0A1F44);
  static const navy = Color(0xFF123B7A);
  static const primary = Color(0xFF2D6CDF);
  static const whiteAccent = Colors.white;
  static const whiteMuted = Color(0xFFE2E8F0);
  static const cardLight = Color(0xFF16294D);
  static const border = Color(0x1AFFFFFF);
  static const textMuted = Color(0xFFAEB9D4);
  static const danger = Color(0xFFE0453C);
  static const success = Color(0xFF10B981);

  static const gradientWhite = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Colors.white, whiteMuted],
  );
}

class CreatePostConstants {
  CreatePostConstants._();

  static const List<String> contentTypes = [
    'Fil',
    'Série',
    'NOVA Originals',
    'Musique',
    'Gaming',
    'Formation',
  ];

  static const List<String> filters = [
    'Normal',
    'Cinématique',
    'Éclat',
    'Vintage',
    'Cyberpunk',
    'Beauté Douce',
  ];
}
