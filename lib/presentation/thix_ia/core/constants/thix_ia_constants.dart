// lib/presentation/thix_ia/core/constants/thix_ia_constants.dart
import 'package:flutter/foundation.dart';

/// ============================================================================
/// THIX IA CONSTANTS - Source unique des constantes métier
/// ============================================================================

class ThixIAConstants {
  ThixIAConstants._();

  // ────────────────────────────────────────────────────────────────────────
  // API & VERSIONING
  // ────────────────────────────────────────────────────────────────────────
  static const String apiVersion = 'v1';
  static const String apiPrefix = '/api/$apiVersion';
  static const Duration apiTimeout = Duration(seconds: 30);
  static const Duration apiLongTimeout = Duration(seconds: 120); // pour analyses

  // ────────────────────────────────────────────────────────────────────────
  // PROJECT INTELLIGENCE™
  // ────────────────────────────────────────────────────────────────────────
  static const String projectCodePrefix = 'THX-BIZ';
  static const String projectCodePattern = r'^THX-BIZ-\d{4}-\d{6}$';
  static const int projectCodeYearLength = 4;
  static const int projectCodeSeqLength = 6;

  static const List<String> projectStatuses = [
    'draft',
    'active',
    'analyzing',
    'paused',
    'archived',
  ];

  static const List<String> analysisTypes = [
    'idea',
    'market',
    'competitor',
    'legal',
    'tax',
    'finance',
    'business_plan',
    'strategy',
    'design',
  ];

  // ────────────────────────────────────────────────────────────────────────
  // PAGINATION & SCALABILITY (millions users)
  // ────────────────────────────────────────────────────────────────────────
  static const int defaultPageSize = 20;
  static const int maxPageSize = 100;
  static const int defaultInitialPage = 1;
  static const int cacheMaxProjects = 100;
  static const int cacheMaxAnalyses = 200;
  static const int searchDebounceMs = 400;
  static const int chatDebounceMs = 300;

  // ────────────────────────────────────────────────────────────────────────
  // STORAGE KEYS
  // ────────────────────────────────────────────────────────────────────────
  static const String keyActiveProjectCode = 'thix_active_project_code';
  static const String keyActiveProjectJson = 'thix_active_project_json';
  static const String keyUserProjectsBox = 'thix_projects_box';
  static const String keyProjectMemoryBox = 'thix_project_memory_box';
  static const String keyAnalysesBox = 'thix_analyses_box';
  static const String keyLastSync = 'thix_last_sync';

  // ────────────────────────────────────────────────────────────────────────
  // LIMITS & QUOTAS
  // ────────────────────────────────────────────────────────────────────────
  static const int maxDocumentSizeMb = 25;
  static const int maxDocumentsPerProject = 50;
  static const int maxIdeasPerProject = 100;
  static const int maxChatHistory = 100;
  static const int maxFileNameLength = 120;

  // ────────────────────────────────────────────────────────────────────────
  // ENGINES
  // ────────────────────────────────────────────────────────────────────────
  static const List<String> thixEngines = [
    'research',
    'market',
    'business',
    'finance',
    'legal',
    'design',
  ];

  // ────────────────────────────────────────────────────────────────────────
  // CONFIDENCE & PROVENANCE
  // ────────────────────────────────────────────────────────────────────────
  static const double confidenceHighThreshold = 0.85;
  static const double confidenceMediumThreshold = 0.6;

  // ────────────────────────────────────────────────────────────────────────
  // UI
  // ────────────────────────────────────────────────────────────────────────
  static const int analysisProgressMin = 0;
  static const int analysisProgressMax = 100;
  static const Duration animationFast = Duration(milliseconds: 200);
  static const Duration animationNormal = Duration(milliseconds: 350);
  static const Duration animationSlow = Duration(milliseconds: 600);

  static const String dateFormatDisplay = 'dd MMM yyyy';
  static const String dateFormatApi = 'yyyy-MM-ddTHH:mm:ssZ';
}
