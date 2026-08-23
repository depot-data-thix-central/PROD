// lib/presentation/thix_ia/core/constants/thix_ia_config.dart
import 'package:flutter/foundation.dart';

/// ============================================================================
/// THIX IA CONFIG - Configuration par environnement
/// ============================================================================

enum ThixEnvironment { dev, staging, prod }

class ThixIAConfig {
  const ThixIAConfig._({
    required this.environment,
    required this.baseUrl,
    required this.wsUrl,
    required this.enableLogging,
    required this.enableMockData,
  });

  final ThixEnvironment environment;
  final String baseUrl;
  final String wsUrl;
  final bool enableLogging;
  final bool enableMockData;

  // Factory par environnement
  static const dev = ThixIAConfig._(
    environment: ThixEnvironment.dev,
    baseUrl: 'https://api-dev.thix.africa',
    wsUrl: 'wss://api-dev.thix.africa/ws',
    enableLogging: true,
    enableMockData: true,
  );

  static const staging = ThixIAConfig._(
    environment: ThixEnvironment.staging,
    baseUrl: 'https://api-staging.thix.africa',
    wsUrl: 'wss://api-staging.thix.africa/ws',
    enableLogging: true,
    enableMockData: false,
  );

  static const prod = ThixIAConfig._(
    environment: ThixEnvironment.prod,
    baseUrl: 'https://api.thix.africa',
    wsUrl: 'wss://api.thix.africa/ws',
    enableLogging: false,
    enableMockData: false,
  );

  static ThixIAConfig get current {
    if (kReleaseMode) return prod;
    // Tu peux switch via --dart-define=ENV=staging
    const env = String.fromEnvironment('ENV', defaultValue: 'dev');
    switch (env) {
      case 'prod':
        return prod;
      case 'staging':
        return staging;
      default:
        return dev;
    }
  }

  bool get isDev => environment == ThixEnvironment.dev;
  bool get isProd => environment == ThixEnvironment.prod;

  // Feature Flags
  static const bool enableRAG = true;
  static const bool enableFactChecker = true;
  static const bool enableDesignEngine = true;
  static const bool enableOfflineCache = true;
  static const Duration cacheTTL = Duration(minutes: 30);
}
