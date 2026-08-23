// lib/presentation/thix_ia/core/constants/thix_ia_routes.dart

/// ============================================================================
/// THIX IA ROUTE NAMES - Constantes de routing module
/// ============================================================================

class ThixIARoutes {
  ThixIARoutes._();

  // Base
  static const String root = '/thix-ia';
  
  // Home
  static const String home = '$root/home';
  
  // Projects
  static const String projects = '$root/projects';
  static const String createProject = '$root/projects/create';
  static const String projectDetail = '$root/projects/:projectCode';
  static String projectDetailPath(String code) => '$root/projects/$code';

  // Engines / Analyses
  static const String analysis = '$root/projects/:projectCode/analysis';
  static const String research = '$root/projects/:projectCode/research';
  static const String market = '$root/projects/:projectCode/market';
  static const String legal = '$root/projects/:projectCode/legal';
  static const String finance = '$root/projects/:projectCode/finance';
  static const String business = '$root/projects/:projectCode/business';
  static const String strategy = '$root/projects/:projectCode/strategy';
  static const String design = '$root/projects/:projectCode/design';
  
  static String analysisPath(String code) => '$root/projects/$code/analysis';
  static String researchPath(String code) => '$root/projects/$code/research';
  static String marketPath(String code) => '$root/projects/$code/market';
  static String legalPath(String code) => '$root/projects/$code/legal';
  static String financePath(String code) => '$root/projects/$code/finance';
  static String businessPath(String code) => '$root/projects/$code/business';

  // Docs & Reports
  static const String documents = '$root/projects/:projectCode/documents';
  static const String reports = '$root/projects/:projectCode/reports';
  static String documentsPath(String code) => '$root/projects/$code/documents';
  static String reportsPath(String code) => '$root/projects/$code/reports';

  // Chat
  static const String chat = '$root/projects/:projectCode/chat';
  static String chatPath(String code) => '$root/projects/$code/chat';

  // Helpers
  static String withCode(String route, String code) {
    return route.replaceAll(':projectCode', code);
  }
}
