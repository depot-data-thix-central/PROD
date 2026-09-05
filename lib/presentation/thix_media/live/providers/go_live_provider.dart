// lib/presentation/thix_media/live/providers/go_live_provider.dart
//
// GoLiveProvider — Production Enterprise
//
// Features :
// - Mapping complet des LiveException vers GoLiveErrorCode
// - Retry intelligent avec mémorisation du dernier essai
// - Throttling anti-double-tap (800ms)
// - Détection "already active" + reprise automatique
// - Logging structuré
// - Timeout global pour éviter les blocages UI
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/live_service.dart';

// ============================================================================
// CONSTANTS
// ============================================================================

const Duration _kStartTimeout = Duration(seconds: 25);
const Duration _kThrottle = Duration(milliseconds: 800);
const int _kMaxRetries = 2;

// ============================================================================
// LOGGING
// ============================================================================

class _GoLiveLogger {
  static const _tag = 'GoLiveProvider';
  static void info(String m, [Map<String, dynamic>? d]) => _log('INFO', m, d);
  static void warn(String m, [Map<String, dynamic>? d]) => _log('WARN', m, d);
  static void error(String m, [Map<String, dynamic>? d]) => _log('ERROR', m, d);
  static void _log(String l, String m, Map<String, dynamic>? d) {
    if (!kDebugMode && l == 'INFO') return;
    final data = d != null
        ? ' ${d.entries.map((e) => '${e.key}=${e.value}').join(', ')}'
        : '';
    debugPrint('[$_tag] [$l] $m$data');
  }
}

// ============================================================================
// PROVIDER
// ============================================================================

final liveServiceProvider = Provider<LiveService>((ref) => LiveService());

// ============================================================================
// ERROR CODES (pour i18n côté UI)
// ============================================================================

enum GoLiveErrorCode {
  notAuthenticated,   // → live_error_not_authenticated
  alreadyActive,      // → live_error_already_active (+ offer resume)
  invalidTitle,       // → live_error_invalid_title
  tokenError,         // → live_error_token
  network,            // → error_network
  timeout,            // → error_timeout
  permissionDenied,   // → error_permission_denied
  serverError,        // → error_server
  cancelled,          // (pas d'affichage, state → idle)
  unknown,            // → error_generic
}

// ============================================================================
// STATES
// ============================================================================

sealed class GoLiveState {
  const GoLiveState();
}

class GoLiveIdle extends GoLiveState {
  const GoLiveIdle();
}

class GoLiveLoading extends GoLiveState {
  /// 0.0 → 1.0 (pour progress indicator)
  final double progress;
  final String stage; // 'preparing' | 'creating' | 'fetching_token'
  const GoLiveLoading({this.progress = 0.0, this.stage = 'preparing'});

  GoLiveLoading copyWith({double? progress, String? stage}) =>
      GoLiveLoading(progress: progress ?? this.progress, stage: stage ?? this.stage);
}

class GoLiveReady extends GoLiveState {
  final LiveSession session;
  final AgoraCredentials creds;
  const GoLiveReady(this.session, this.creds);
}

class GoLiveError extends GoLiveState {
  final GoLiveErrorCode code;
  final String rawMessage;

  /// Si `alreadyActiveSession` est non-null, proposer "Reprendre le live".
  final LiveSession? alreadyActiveSession;

  const GoLiveError({
    required this.code,
    required this.rawMessage,
    this.alreadyActiveSession,
  });

  /// Clé i18n associée au code (à utiliser avec AppLocalizations).
  String get i18nKey {
    switch (code) {
      case GoLiveErrorCode.notAuthenticated:
        return 'live_error_not_authenticated';
      case GoLiveErrorCode.alreadyActive:
        return 'live_error_already_active';
      case GoLiveErrorCode.invalidTitle:
        return 'live_error_invalid_title';
      case GoLiveErrorCode.tokenError:
        return 'live_error_token';
      case GoLiveErrorCode.network:
        return 'error_network';
      case GoLiveErrorCode.timeout:
        return 'error_timeout';
      case GoLiveErrorCode.permissionDenied:
        return 'error_permission_denied';
      case GoLiveErrorCode.serverError:
        return 'error_server';
      case GoLiveErrorCode.cancelled:
        return 'common_cancel';
      case GoLiveErrorCode.unknown:
        return 'error_generic';
    }
  }

  // ✅ NOUVEAU : Override de toString pour faciliter le debug
  @override
  String toString() => 'GoLiveError($code): $rawMessage';
}

class GoLiveCancelling extends GoLiveState {
  const GoLiveCancelling();
}

// ============================================================================
// NOTIFIER
// ============================================================================

class GoLiveNotifier extends StateNotifier<GoLiveState> {
  GoLiveNotifier(this._liveService) : super(const GoLiveIdle());

  final LiveService _liveService;

  DateTime? _lastStartAt;
  _LastAttempt? _lastAttempt;
  int _retryCount = 0;

  /// Retourne true si une action est en cours (pour désactiver UI).
  bool get isBusy =>
      state is GoLiveLoading || state is GoLiveCancelling;

  /// Retourne true si on peut retry (après une erreur non-fatale).
  bool get canRetry => state is GoLiveError && _lastAttempt != null;

  // ════════════════════════════════════════════════════════════
  // START LIVE
  // ════════════════════════════════════════════════════════════

  Future<void> start({
    required String title,
    String category = 'general',
  }) async {
    // Throttle anti-double-tap
    final now = DateTime.now();
    if (_lastStartAt != null &&
        now.difference(_lastStartAt!) < _kThrottle) {
      _GoLiveLogger.warn('Start throttled');
      return;
    }
    _lastStartAt = now;

    if (isBusy) {
      _GoLiveLogger.warn('Start ignored: already busy');
      return;
    }

    _lastAttempt = _LastAttempt(title: title, category: category);
    _retryCount = 0;

    await _performStart(title, category);
  }

  Future<void> _performStart(String title, String category) async {
    state = const GoLiveLoading(progress: 0.1, stage: 'preparing');
    _GoLiveLogger.info('Starting live attempt',
        {'title': title, 'category': category, 'retry': _retryCount});

    try {
      state = const GoLiveLoading(progress: 0.3, stage: 'creating');

      final result = await _liveService
          .startLive(title: title, category: category)
          .timeout(_kStartTimeout, onTimeout: () {
        throw TimeoutException('Start live timed out');
      });

      if (!mounted) return;

      state = const GoLiveLoading(progress: 0.9, stage: 'fetching_token');

      // Petit délai UX pour voir le "presque fini"
      await Future.delayed(const Duration(milliseconds: 150));

      if (!mounted) return;

      _GoLiveLogger.info('Live ready',
          {'sessionId': result.session.id, 'channel': result.session.channelName});

      state = GoLiveReady(result.session, result.creds);
    } on LiveAlreadyActiveException {
      _handleAlreadyActive();
    } on LiveNotAuthenticatedException {
      _fail(GoLiveErrorCode.notAuthenticated, 'User not authenticated');
    } on LiveTokenException catch (e) {
      _fail(GoLiveErrorCode.tokenError, e.message);
    } on LiveException catch (e) {
      _mapLiveException(e);
    } on TimeoutException {
      _fail(GoLiveErrorCode.timeout, 'Start live timed out',
          autoRetry: true);
    } catch (e) {
      final msg = e.toString();
      // Heuristiques pour classifier l'erreur inconnue
      if (msg.contains('SocketException') ||
          msg.contains('Network') ||
          msg.contains('Failed host')) {
        _fail(GoLiveErrorCode.network, msg, autoRetry: true);
      } else if (msg.contains('permission') || msg.contains('Permission')) {
        _fail(GoLiveErrorCode.permissionDenied, msg);
      } else if (msg.contains('500') || msg.contains('502') || msg.contains('503')) {
        _fail(GoLiveErrorCode.serverError, msg, autoRetry: true);
      } else {
        _fail(GoLiveErrorCode.unknown, msg);
      }
    }
  }

  // ════════════════════════════════════════════════════════════
  // ALREADY ACTIVE : récupérer le live existant
  // ════════════════════════════════════════════════════════════

  Future<void> _handleAlreadyActive() async {
    _GoLiveLogger.warn('User already has an active live — fetching it');
    try {
      final actives = await _liveService.listActiveLives(limit: 5);
      final userId = Supabase.instance.client.auth.currentUser?.id;
      final myActive = actives.firstWhere(
        (s) => s.hostId == userId,
        orElse: () => actives.first,
      );

      if (!mounted) return;

      // Tenter de récupérer un token pour ce live existant
      final creds = await _liveService
          .fetchAgoraToken(
            channelName: myActive.channelName,
            role: 'host',
          )
          .timeout(_kStartTimeout);

      if (!mounted) return;

      _GoLiveLogger.info('Resuming existing live',
          {'sessionId': myActive.id});

      state = GoLiveError(
        code: GoLiveErrorCode.alreadyActive,
        rawMessage: 'You already have an active live',
        alreadyActiveSession: myActive,
      );
    } catch (e) {
      _fail(GoLiveErrorCode.alreadyActive,
          'Already active but failed to resume: $e');
    }
  }

  /// Reprise directe du live actif (appelé par l'UI après dialog).
  Future<void> resumeActive(LiveSession session) async {
    if (isBusy) return;
    state = const GoLiveLoading(progress: 0.5, stage: 'fetching_token');
    _GoLiveLogger.info('Resuming active live', {'sessionId': session.id});

    try {
      final creds = await _liveService
          .fetchAgoraToken(
            channelName: session.channelName,
            role: 'host',
          )
          .timeout(_kStartTimeout);

      if (!mounted) return;
      state = GoLiveReady(session, creds);
    } catch (e) {
      _fail(GoLiveErrorCode.tokenError, 'Resume failed: $e');
    }
  }

  // ════════════════════════════════════════════════════════════
  // RETRY
  // ════════════════════════════════════════════════════════════

  Future<void> retry() async {
    final attempt = _lastAttempt;
    if (attempt == null) {
      _GoLiveLogger.warn('Retry ignored: no last attempt');
      return;
    }
    if (isBusy) return;

    _retryCount++;
    if (_retryCount > _kMaxRetries) {
      _GoLiveLogger.warn('Max retries reached');
      return;
    }

    _GoLiveLogger.info('Retry attempt',
        {'count': _retryCount, 'title': attempt.title});

    await _performStart(attempt.title, attempt.category);
  }

  // ════════════════════════════════════════════════════════════
  // CANCEL / RESET
  // ════════════════════════════════════════════════════════════

  void cancel() {
    if (state is! GoLiveLoading) return;
    _GoLiveLogger.info('User cancelled start');
    state = const GoLiveCancelling();
    Future.delayed(const Duration(milliseconds: 120), () {
      if (mounted) state = const GoLiveIdle();
    });
  }

  void reset() {
    _GoLiveLogger.info('State reset');
    _lastAttempt = null;
    _retryCount = 0;
    state = const GoLiveIdle();
  }

  // ════════════════════════════════════════════════════════════
  // ERROR MAPPING
  // ════════════════════════════════════════════════════════════

  void _mapLiveException(LiveException e) {
    switch (e.code) {
      case 'invalid_title':
        _fail(GoLiveErrorCode.invalidTitle, e.message);
        break;
      case 'not_authenticated':
        _fail(GoLiveErrorCode.notAuthenticated, e.message);
        break;
      case 'already_active':
        _handleAlreadyActive();
        break;
      case 'token_error':
        _fail(GoLiveErrorCode.tokenError, e.message, autoRetry: true);
        break;
      case 'timeout':
        _fail(GoLiveErrorCode.timeout, e.message, autoRetry: true);
        break;
      default:
        _fail(GoLiveErrorCode.unknown, e.message);
    }
  }

  void _fail(
    GoLiveErrorCode code,
    String rawMessage, {
    bool autoRetry = false,
  }) {
    _GoLiveLogger.error('Start failed',
        {'code': code.name, 'message': rawMessage, 'autoRetry': autoRetry});

    if (!mounted) return;
    state = GoLiveError(code: code, rawMessage: rawMessage);

    if (autoRetry && _retryCount < _kMaxRetries) {
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted && state is GoLiveError) {
          _GoLiveLogger.info('Auto-retrying after transient error');
          retry();
        }
      });
    }
  }
}

class _LastAttempt {
  final String title;
  final String category;
  _LastAttempt({required this.title, required this.category});
}

// ============================================================================
// PROVIDER DECLARATION
// ============================================================================

final goLiveNotifierProvider =
    StateNotifierProvider.autoDispose<GoLiveNotifier, GoLiveState>((ref) {
  return GoLiveNotifier(ref.watch(liveServiceProvider));
});
