// lib/presentation/admin/admin_colors.dart
import 'package:flutter/material.dart';

/// Couleurs unifiées pour l'espace Administrateur THIX
class AdminColors {
  // ============================================================
  // COULEURS PRINCIPALES - Thème Cyber/Glassmorphism
  // ============================================================
  
  // Fond principal
  static const Color black = Color(0xFF0A0E1A);
  static const Color background = Color(0xFF0F1420);
  
  // Panel et surfaces
  static const Color panel = Color(0xCC1A1F2E);
  static const Color panelHi = Color(0xE6222A3E);
  static const Color stroke = Color(0x33FFFFFF);
  
  // Texte
  static const Color text = Color(0xFFF0F3FA);
  static const Color textDim = Color(0xFF8E98B0);
  static const Color textLight = Colors.white;
  
  // ============================================================
  // COULEURS NÉON/ACCENT
  // ============================================================
  static const Color neonCyan = Color(0xFF00E5FF);
  static const Color electricBlue = Color(0xFF2962FF);
  static const Color neonViolet = Color(0xFFB388FF);
  static const Color neonPink = Color(0xFFFF4081);
  static const Color neonGreen = Color(0xFF00E676);
  static const Color neonOrange = Color(0xFFFF9100);
  
  // ============================================================
  // COULEURS THIX (Doré)
  // ============================================================
  static const Color thixGold = Color(0xFFD4AF37);
  static const Color thixGoldDark = Color(0xFFB8941E);
  static const Color thixGoldLight = Color(0xFFE8C96C);
  
  // ============================================================
  // COULEURS DE STATUT
  // ============================================================
  static const Color success = Color(0xFF00E676);
  static const Color warning = Color(0xFFFF9100);
  static const Color error = Color(0xFFFF1744);
  static const Color info = Color(0xFF00B0FF);
  
  // ============================================================
  // DÉGRADÉS
  // ============================================================
  static LinearGradient primaryGradient() {
    return const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [electricBlue, neonCyan],
    );
  }
  
  static LinearGradient secondaryGradient() {
    return const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [neonViolet, neonPink],
    );
  }
  
  static LinearGradient thixGradient() {
    return const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [thixGold, thixGoldLight],
    );
  }
  
  static LinearGradient glowViolet() {
    return const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [neonViolet, electricBlue],
    );
  }
  
  static LinearGradient successGradient() {
    return const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [success, neonGreen],
    );
  }
  
  static LinearGradient warningGradient() {
    return const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [warning, neonOrange],
    );
  }
  
  static LinearGradient errorGradient() {
    return const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [error, neonPink],
    );
  }
}

/// Gestionnaire de couleurs par module (utilise AdminModule de admin_page.dart)
class AdminModuleColors {
  static Color getColor(dynamic module) {
    final moduleStr = module.toString().split('.').last;
    
    switch (moduleStr) {
      case 'overview':
        return AdminColors.electricBlue;
      case 'accessRequests':
        return AdminColors.warning;
      case 'users':
        return AdminColors.info;
      case 'verification':
        return AdminColors.success;
      case 'events':
        return AdminColors.neonCyan;
      case 'trainings':
        return AdminColors.thixGold;
      case 'uid':
        return AdminColors.electricBlue;
      case 'jobs':
        return AdminColors.success;
      case 'news':
        return AdminColors.thixGold;
      case 'chat':
        return AdminColors.neonCyan;
      case 'sos':
        return AdminColors.error;
      case 'institutions':
        return AdminColors.electricBlue;
      case 'analytics':
        return AdminColors.info;
      case 'cybersecurity':
        return AdminColors.error;
      case 'api':
        return AdminColors.electricBlue;
      case 'settings':
        return AdminColors.warning;
      case 'audit':
        return AdminColors.textDim;
      case 'media':
        return AdminColors.neonPink;
      default:
        return AdminColors.textDim;
    }
  }
  
  static IconData getIcon(dynamic module) {
    final moduleStr = module.toString().split('.').last;
    
    switch (moduleStr) {
      case 'overview':
        return Icons.dashboard_rounded;
      case 'accessRequests':
        return Icons.admin_panel_settings_rounded;
      case 'users':
        return Icons.people_alt_rounded;
      case 'verification':
        return Icons.verified_user_rounded;
      case 'events':
        return Icons.event_available_rounded;
      case 'trainings':
        return Icons.school_rounded;
      case 'uid':
        return Icons.badge_rounded;
      case 'jobs':
        return Icons.work_rounded;
      case 'news':
        return Icons.campaign_rounded;
      case 'media':
        return Icons.movie_rounded;
      case 'chat':
        return Icons.forum_rounded;
      case 'sos':
        return Icons.sos_rounded;
      case 'institutions':
        return Icons.account_balance_rounded;
      case 'analytics':
        return Icons.query_stats_rounded;
      case 'cybersecurity':
        return Icons.shield_rounded;
      case 'api':
        return Icons.api_rounded;
      case 'settings':
        return Icons.tune_rounded;
      case 'audit':
        return Icons.manage_history_rounded;
      default:
        return Icons.help_outline_rounded;
    }
  }
  
  static String getLabel(dynamic module) {
    final moduleStr = module.toString().split('.').last;
    
    switch (moduleStr) {
      case 'overview':
        return 'Global Overview';
      case 'accessRequests':
        return 'Account Access Requests';
      case 'users':
        return 'User Management';
      case 'verification':
        return 'Verification Center';
      case 'events':
        return 'Events';
      case 'trainings':
        return 'Trainings';
      case 'uid':
        return 'THIX UID';
      case 'jobs':
        return 'Jobs & Opportunities';
      case 'news':
        return 'Info / News';
      case 'media':
        return 'THIX Media';
      case 'chat':
        return 'THIX Chat Admin';
      case 'sos':
        return 'SOS Emergency';
      case 'institutions':
        return 'Institutions';
      case 'analytics':
        return 'Analytics';
      case 'cybersecurity':
        return 'Cybersecurity';
      case 'api':
        return 'API & Integrations';
      case 'settings':
        return 'Settings';
      case 'audit':
        return 'Audit & Activity';
      default:
        return moduleStr;
    }
  }
}
