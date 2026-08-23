// lib/presentation/thix_ia/core/errors/thix_ia_error_mapper.dart
import 'dart:io';
import 'package:dio/dio.dart';
import 'thix_ia_exception.dart';

/// ============================================================================
/// THIX IA ERROR MAPPER - Centralise la traduction Dio -> Domaine
/// ============================================================================

class ThixIAErrorMapper {
  ThixIAErrorMapper._();

  static ThixIAException map(Object error, StackTrace stack) {
    // Dio
    if (error is DioException) {
      return _mapDio(error, stack);
    }

    // Socket / IO
    if (error is SocketException) {
      return ThixIANetworkException.noInternet();
    }

    // Déjà une exception métier
    if (error is ThixIAException) {
      return error;
    }

    // Fallback
    return ThixIAServerException(
      message: 'Erreur inattendue: ${error.toString()}',
      code: 'UNKNOWN',
      details: {'original': error.toString()},
      statusCode: null,
    );
  }

  static ThixIAException _mapDio(DioException e, StackTrace stack) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return ThixIANetworkException.timeout();

      case DioExceptionType.connectionError:
        return ThixIANetworkException.noInternet();

      case DioExceptionType.badResponse:
        final status = e.response?.statusCode;
        final data = e.response?.data;

        if (status == 401) return ThixIANetworkException.unauthorized();
        if (status == 404) {
          return ThixIAProjectNotFoundException(
            data?['project_code']?.toString()?? 'unknown',
          );
        }
        if (status == 409) {
          return ThixIAConflictException(
            message: data?['message']?? 'Conflit de données',
            details: data is Map? Map<String, dynamic>.from(data) : null,
          );
        }
        if (status!= null && status >= 400 && status < 500) {
          return ThixIAValidationException(
            message: data?['message']?? 'Données invalides',
            details: data is Map? Map<String, dynamic>.from(data) : null,
          );
        }

        return ThixIAServerException(
          message: data?['message']?? 'Erreur serveur',
          code: 'SERVER_${status?? 500}',
          details: data is Map? Map<String, dynamic>.from(data) : null,
          statusCode: status,
        );

      default:
        return ThixIANetworkException(
          message: e.message?? 'Erreur réseau',
          details: {'type': e.type.name},
          stackTrace: stack,
        );
    }
  }

  static String userMessage(ThixIAException e) {
    // Message safe à afficher à l'utilisateur
    if (e is ThixIANetworkException) return e.message;
    if (e is ThixIAValidationException) return e.message;
    if (e is ThixIAProjectNotFoundException) return e.message;
    // On ne leak jamais les détails serveur en prod
    return 'Une erreur est survenue. Veuillez réessayer.';
  }
}
