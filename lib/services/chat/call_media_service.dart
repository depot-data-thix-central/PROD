// lib/services/chat/call_media_service.dart
//
// ============================================================================
// CALL MEDIA SERVICE — Re-export
// ============================================================================
//
// Re-export de CallMediaService depuis call_service.dart pour compatibilité.
//
// Historique :
//   - Initialement, CallMediaService était dans son propre fichier
//   - Après refactor, il a été consolidé dans call_service.dart
//   - Ce fichier maintient la compatibilité avec les imports existants
//
// Usage :
//   import 'package:thix_id/services/chat/call_media_service.dart';
//   final service = CallMediaService();
// ============================================================================

export 'call_service.dart' show CallMediaService, PermissionDeniedException;
