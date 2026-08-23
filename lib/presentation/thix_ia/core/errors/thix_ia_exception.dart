// lib/presentation/thix_ia/core/errors/thix_ia_exception.dart
import 'package:equatable/equatable.dart';

/// ============================================================================
/// THIX IA EXCEPTIONS - Hiérarchie d'erreurs métier
/// ============================================================================

abstract class ThixIAException extends Equatable implements Exception {
  const ThixIAException({
    required this.message,
    required this.code,
    this.details,
    this.stackTrace,
  });

  final String message;
  final String code;
  final Map<String, dynamic>? details;
  final StackTrace? stackTrace;

  @override
  List<Object?> get props => [message, code, details];

  @override
  String toString() => '[$code] $message ${details ?? ''}';
}

// ────────────────────────────────────────────────────────────────────────────
// NETWORK
// ────────────────────────────────────────────────────────────────────────────
class ThixIANetworkException extends ThixIAException {
  const ThixIANetworkException({
    required super.message,
    super.code = 'NETWORK_ERROR',
    super.details,
    super.stackTrace,
    this.statusCode,
  });

  final int? statusCode;

  factory ThixIANetworkException.noInternet() => const ThixIANetworkException(
        message: 'Pas de connexion internet. Vérifiez votre réseau.',
        code: 'NO_INTERNET',
      );

  factory ThixIANetworkException.timeout() => const ThixIANetworkException(
        message: 'Le serveur met trop de temps à répondre.',
        code: 'TIMEOUT',
      );

  factory ThixIANetworkException.unauthorized() => const ThixIANetworkException(
        message: 'Session expirée. Veuillez vous reconnecter.',
        code: 'UNAUTHORIZED',
        statusCode: 401,
      );
}

class ThixIAServerException extends ThixIAException {
  const ThixIAServerException({
    required super.message,
    super.code = 'SERVER_ERROR',
    super.details,
    super.stackTrace,
    this.statusCode,
  });

  final int? statusCode;
}

// ────────────────────────────────────────────────────────────────────────────
// PROJECT DOMAIN
// ────────────────────────────────────────────────────────────────────────────
class ThixIAProjectNotFoundException extends ThixIAException {
  const ThixIAProjectNotFoundException(String projectCode)
      : super(
          message: 'Projet $projectCode introuvable.',
          code: 'PROJECT_NOT_FOUND',
          details: const {},
        );
}

class ThixIAValidationException extends ThixIAException {
  const ThixIAValidationException({
    required super.message,
    super.code = 'VALIDATION_ERROR',
    super.details,
  });
}

class ThixIAConflictException extends ThixIAException {
  const ThixIAConflictException({
    required super.message,
    super.code = 'CONFLICT',
    super.details,
  });
}

// ────────────────────────────────────────────────────────────────────────────
// CACHE / LOCAL
// ────────────────────────────────────────────────────────────────────────────
class ThixIACacheException extends ThixIAException {
  const ThixIACacheException({
    required super.message,
    super.code = 'CACHE_ERROR',
    super.details,
  });
}

class ThixIADocumentException extends ThixIAException {
  const ThixIADocumentException({
    required super.message,
    super.code = 'DOCUMENT_ERROR',
    super.details,
  });
}
