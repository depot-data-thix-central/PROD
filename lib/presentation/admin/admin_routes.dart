import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:thix_id/presentation/admin/admin_page.dart'; // ✅ Import unique de AdminModule

class AdminRoutes {
  static const String base = '/admin';
  
  // Génère le chemin complet pour un module
  static String modulePath(AdminModule module) {
    return '$base/${module.slug}';
  }
  
  // Génère le chemin à partir d'un slug
  static String modulePathFromSlug(String slug) {
    return '$base/$slug';
  }
  
  // Vérifie si une route est dans l'admin
  static bool isAdminRoute(String location) {
    return location.startsWith(base);
  }
  
  // Extrait le module depuis une route
  static AdminModule? extractModule(String location) {
    if (!location.startsWith(base)) return null;
    final parts = location.split('/');
    if (parts.length < 2) return null;
    final slug = parts[2];
    return AdminModuleX.fromSlug(slug);
  }
}

// ⚠️ NE PAS définir AdminModule ou AdminModuleX ici !
// Ils sont déjà définis dans admin_page.dart
