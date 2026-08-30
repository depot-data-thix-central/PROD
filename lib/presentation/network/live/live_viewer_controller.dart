// lib/presentation/network/live/live_viewer_controller.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:html/parser.dart' as html_parser;

import 'package:thix_id/data/models/live/live_model.dart';
import 'package:thix_id/data/services/live/live_service.dart';

// ============================================================================
// CONSTANTES
// ============================================================================
const Duration _kCredentialsTimeout = Duration(seconds: 12);
const Duration _kJoinTimeout = Duration(seconds: 10);
const Duration _kCleanupTimeout = Duration(seconds: 5);
const Duration _kViewerDebounce = Duration(milliseconds: 500);
const Duration _kHeartRateLimit = Duration(milliseconds: 100);
const int _kMaxCommentsInMemory = 200;
const int _kMaxCommentLength = 300;

// ============================================================================
// VALIDATEURS
// ============================================================================
class _ViewerValidators {
  _ViewerValidators._();

  static String sanitize(String? input, {int maxLength = _kMaxCommentLength}) {
    if (input == null || input.trim().isEmpty) return '';
    final doc = html_parser.parse(input);
    var sanitized = doc.body?.text ?? input;
    sanitized = sanitized
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll(RegExp(r'javascript:', caseSensitive: false), '')
        .replaceAll(RegExp(r'on\w+\s*=', caseSensitive: false), '')
        .replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '')
        .trim();
    return sanitized.length > maxLength ? sanitized.substring(0, maxLength) : sanitized;
  }

  static String parseErrorMessage(dynamic e) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('timeout')) return 'Délai dépassé. Vérifiez votre connexion.';
    if (msg.contains('network') || msg.contains('socket')) return 'Erreur réseau. Réessayez.';
    if (msg.contains('invalidtoken') || msg.contains('tokenexpired')) return 'Token expiré. Rejoignez à nouveau le direct.';
    if (msg.contains('invalidappid')) return 'Configuration serveur invalide.';
    if (msg.contains('invalidchannel')) return 'Ce direct n\'existe plus.';
    if (msg.contains('rejected')) return 'Accès refusé au direct.';
    return e.toString().replaceFirst('Exception: ', '').split('\n').first;
  }
}

// ============================================================================
// ÉTAT
// ============================================================================
enum ViewerStatus { loading, ready, hostOffline, error }

class LiveViewerState {
  final ViewerStatus status;
  final String? errorMessage;
  final int? hostUid;
  final bool isHostVideoOff;
  final List<LiveComment> comments;
  final int viewerCount;

  const LiveViewerState({
    this.status = ViewerStatus.loading,
    this.errorMessage,
    this.hostUid,
    this.isHostVideoOff = false,
    this.comments = const [],
    this.viewerCount = 0,
  });

  LiveViewerState copyWith({
    ViewerStatus? status,
    String? errorMessage,
    int? hostUid,
    bool? isHostVideoOff,
    List<LiveComment>? comments,
    int? viewerCount,
    bool clearHostUid = false,
  }) {
    return LiveViewerState(
      status: status ?? this.status,
      errorMessage: errorMessage,
      hostUid: clearHostUid ? null : (hostUid ?? this.hostUid),
      isHostVideoOff: isHostVideoOff ?? this.isHostVideoOff,
      comments: comments ?? this.comments,
      viewerCount: viewerCount ?? this.viewerCount,
    );
  }
}

// ============================================================================
// PROVIDER
// ============================================================================
final liveViewerControllerProvider = StateNotifierProvider.autoDispose
    .family<LiveViewerController, LiveViewerState, LiveSession>(
  (ref, session) => LiveViewerController(session, ref),
);

// ============================================================================
// CONTRÔLEUR
// ============================================================================
class LiveViewerController extends StateNotifier<LiveViewerState> {
  final LiveSession session;
  final AutoDisposeStateNotifierProviderRef ref;

  RtcEngine? _engine;
  RealtimeChannel? _realtimeChannel;
  Completer<void>? _joinCompleter;
  Timer? _viewerDebounceTimer;
  DateTime? _lastHeartTime;

  bool _isDisposed = false;
  bool _isBootstrapping = false;
  bool _isLeaving = false;
  bool _realtimeConnected = false;
  String? _viewerDisplayName;

  LiveViewerController(this.session, this.ref) : super(const LiveViewerState()) {
    debugPrint('[LiveViewer] 👁️ Controller created for session ${session.id}');

    ref.onDispose(() {
      _isDisposed = true;
      _cleanup();
      debugPrint('[LiveViewer] 👋 Controller disposed for session ${session.id}');
    });

    Future.microtask(() => bootstrap());
  }

  // ─── GETTERS PUBLICS ───
  RtcEngine? get engine => _engine;
  bool get isReady => state.status == ViewerStatus.ready;
  bool get isHostOffline => state.status == ViewerStatus.hostOffline;
  bool get isLeaving => _isLeaving;
  bool get canRetry =>
      state.status == ViewerStatus.error ||
      state.status == ViewerStatus.hostOffline;

  LiveService get _service => ref.read(liveServiceProvider);

  // ─── BOOTSTRAP ───
  Future<void> bootstrap() async {
    if (_isDisposed) {
      debugPrint('[LiveViewer] ⚠️ bootstrap called on disposed controller');
      return;
    }
    if (_isBootstrapping) {
      debugPrint('[LiveViewer] ⚠️ bootstrap already in progress — ignored');
      return;
    }

    _isBootstrapping = true;
    _cancelAllTimers();

    state = state.copyWith(status: ViewerStatus.loading, errorMessage: null);

    try {
      // 1. Charger le nom de l'utilisateur connecté
      await _loadViewerName();

      // 2. Credentials Agora (pas de rôle, juste token pour audience)
      AgoraCredentials credentials;
      try {
        debugPrint('[LiveViewer] 🎟️ Fetching credentials for ${session.channelName}');
        credentials = await _service
            .fetchAgoraCredentials(session.channelName)
            .timeout(_kCredentialsTimeout);
      } on TimeoutException {
        _fail("Délai dépassé lors de la connexion au direct.");
        return;
      } catch (e) {
        _fail(_ViewerValidators.parseErrorMessage(e));
        return;
      }

      if (credentials.appId.isEmpty || credentials.token.isEmpty) {
        _fail("Configuration Agora invalide côté serveur.");
        return;
      }
      debugPrint('[LiveViewer] ✓ Credentials received');

      // 3. Moteur Agora (audience uniquement)
      try {
        await _ensureEngineClean();
        final engine = createAgoraRtcEngine();

        await engine.initialize(RtcEngineContext(
          appId: credentials.appId,
          channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
        ));

        // Rôle AUDIENCE : ne publie rien, reçoit uniquement.
        // Important pour App Store / Play Store (Guideline 5.1.1)
        await engine.setClientRole(role: ClientRoleType.clientRoleAudience);

        _joinCompleter = Completer<void>();
        _registerEngineHandlers(engine);

        await engine.joinChannel(
          token: credentials.token,
          channelId: session.channelName,
          uid: 0,
          options: const ChannelMediaOptions(
            clientRoleType: ClientRoleType.clientRoleAudience,
            autoSubscribeVideo: true,
            autoSubscribeAudio: true,
            publishCameraTrack: false,
            publishMicrophoneTrack: false,
          ),
        );

        _engine = engine;

        await _joinCompleter!.future.timeout(_kJoinTimeout, onTimeout: () {
          throw TimeoutException("Connexion au direct impossible (délai dépassé).");
        });

        if (_isDisposed) {
          debugPrint('[LiveViewer] ⚠️ Disposed during join — cleanup');
          await _ensureEngineClean();
          return;
        }

        state = state.copyWith(status: ViewerStatus.ready);
        debugPrint('[LiveViewer] ✓ Channel joined as audience');

        _initRealtime();
      } catch (e) {
        debugPrint('[LiveViewer] ❌ Agora error: $e');
        await _ensureEngineClean();
        _fail(_ViewerValidators.parseErrorMessage(e));
      }
    } finally {
      _isBootstrapping = false;
    }
  }

  Future<void> _loadViewerName() async {
    try {
      final uid = Supabase.instance.client.auth.currentUser?.id;
      if (uid == null) {
        _viewerDisplayName = 'Spectateur';
        return;
      }

      final profile = await Supabase.instance.client
          .from('profiles')
          .select('display_name')
          .eq('id', uid)
          .maybeSingle()
          .timeout(const Duration(seconds: 5));

      final name = (profile?['display_name']?.toString().trim().isNotEmpty ?? false)
          ? profile!['display_name'] as String
          : 'Spectateur';
      _viewerDisplayName = _ViewerValidators.sanitize(name, maxLength: 50);
    } catch (e) {
      debugPrint('[LiveViewer] ⚠️ Load viewer name error: $e');
      _viewerDisplayName = 'Spectateur';
    }
  }

  void _registerEngineHandlers(RtcEngine engine) {
    engine.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (connection, elapsed) {
          debugPrint('[LiveViewer] ✓ Joined as audience uid=${connection.localUid} elapsed=${elapsed}ms');
          if (_joinCompleter != null && !_joinCompleter!.isCompleted) {
            _joinCompleter!.complete();
          }
        },
        onUserJoined: (connection, remoteUid, elapsed) {
          debugPrint('[LiveViewer] 👤 User joined: uid=$remoteUid');
          if (state.hostUid == null) {
            state = state.copyWith(hostUid: remoteUid);
          }
        },
        onUserOffline: (connection, remoteUid, reason) {
          debugPrint('[LiveViewer] 👋 User offline: uid=$remoteUid reason=$reason');
          if (state.hostUid == remoteUid) {
            state = state.copyWith(
              status: ViewerStatus.hostOffline,
              clearHostUid: true,
            );
          }
        },
        onRemoteVideoStateChanged: (connection, remoteUid, videoState, reason, elapsed) {
          if (remoteUid == state.hostUid) {
            final isOff = videoState == RemoteVideoState.remoteVideoStateStopped;
            if (state.isHostVideoOff != isOff) {
              state = state.copyWith(isHostVideoOff: isOff);
              debugPrint('[LiveViewer] 📹 Host video: ${isOff ? "OFF" : "ON"}');
            }
          }
        },
        onError: (err, msg) {
          debugPrint('[LiveViewer] ❌ onError: $err - $msg');
          if (_joinCompleter != null && !_joinCompleter!.isCompleted) {
            _joinCompleter!.completeError(Exception("Erreur Agora ($err) : $msg"));
          } else if (state.status == ViewerStatus.ready) {
            debugPrint('[LiveViewer] ⚠️ Non-blocking error during viewing');
          }
        },
        onConnectionStateChanged: (connection, connState, reason) {
          debugPrint('[LiveViewer] 📡 Connection state: $connState / $reason');
          if (connState == ConnectionStateType.connectionStateFailed) {
            if (_joinCompleter != null && !_joinCompleter!.isCompleted) {
              _joinCompleter!.completeError(Exception("Échec de connexion au direct ($reason)."));
            }
          }
        },
      ),
    );
  }

  // ─── NETTOYAGE ───
  Future<void> _ensureEngineClean() async {
    try {
      if (_engine != null) {
        try {
          await _engine!.leaveChannel().timeout(_kCleanupTimeout, onTimeout: () {});
        } catch (e) {
          debugPrint('[LiveViewer] Cleanup leaveChannel error: $e');
        }
        try {
          await _engine!.release();
        } catch (e) {
          debugPrint('[LiveViewer] Cleanup release error: $e');
        }
        _engine = null;
      }
    } catch (e) {
      debugPrint('[LiveViewer] Cleanup engine error: $e');
    }

    if (_joinCompleter != null && !_joinCompleter!.isCompleted) {
      _joinCompleter!.completeError(Exception('Cleanup'));
    }
    _joinCompleter = null;
  }

  void _cancelAllTimers() {
    _viewerDebounceTimer?.cancel();
    _viewerDebounceTimer = null;
  }

  void _cleanup() {
    _cancelAllTimers();
    try {
      _realtimeChannel?.unsubscribe();
    } catch (e) {
      debugPrint('[LiveViewer] Cleanup realtime error: $e');
    }
    _realtimeChannel = null;
    _realtimeConnected = false;

    // Cleanup synchrone (dispose ne doit pas await)
    try {
      _engine?.leaveChannel();
    } catch (_) {}
    try {
      _engine?.release();
    } catch (_) {}
    _engine = null;
  }

  void _fail(String message) {
    debugPrint('[LiveViewer] ❌ _fail: $message');
    _cancelAllTimers();
    _ensureEngineClean();
    state = state.copyWith(status: ViewerStatus.error, errorMessage: message);
  }

  // ─── REALTIME ───
  void _initRealtime() {
    try {
      debugPrint('[LiveViewer] Initializing Realtime channel for ${session.id}');
      _realtimeChannel = _service.openRealtimeChannel(
        liveId: session.id,
        onChat: (comment) {
          final sanitized = LiveComment(
            userId: comment.userId,
            userName: _ViewerValidators.sanitize(comment.userName, maxLength: 50),
            text: _ViewerValidators.sanitize(comment.text, maxLength: _kMaxCommentLength),
          );
          _addComment(sanitized);
        },
        onHeart: () {
          // Le viewer reçoit les cœurs — gérés par la view via le stream du service si besoin
        },
        onCoHostRequest: (userId, userName) {
          // Sans objet côté spectateur
        },
        onPresenceSync: (count) => _updateViewerCount(count),
      );
      _realtimeConnected = true;
      debugPrint('[LiveViewer] ✓ Realtime channel initialized');
    } catch (e) {
      debugPrint('[LiveViewer] ⚠️ Realtime init error (non-blocking): $e');
    }
  }

  void _addComment(LiveComment comment) {
    final updated = [...state.comments, comment];
    final trimmed = updated.length > _kMaxCommentsInMemory
        ? updated.sublist(updated.length - _kMaxCommentsInMemory)
        : updated;
    state = state.copyWith(comments: trimmed);
  }

  void _updateViewerCount(int count) {
    _viewerDebounceTimer?.cancel();
    _viewerDebounceTimer = Timer(_kViewerDebounce, () {
      if (!_isDisposed && state.viewerCount != count) {
        state = state.copyWith(viewerCount: count);
      }
    });
  }

  // ─── COMMENTAIRES ───
  void sendComment(String text) {
    if (_isDisposed) return;

    final sanitized = _ViewerValidators.sanitize(text, maxLength: _kMaxCommentLength);
    if (sanitized.isEmpty || _realtimeChannel == null) {
      debugPrint('[LiveViewer] ⚠️ sendComment rejected (empty or no channel)');
      return;
    }

    final comment = LiveComment(
      userId: _service.currentUserId,
      userName: _viewerDisplayName ?? 'Spectateur',
      text: sanitized,
    );

    try {
      _service.sendChatMessage(_realtimeChannel!, comment);
      _addComment(comment);
      debugPrint('[LiveViewer] 💬 Comment sent');
    } catch (e) {
      debugPrint('[LiveViewer] ❌ sendComment error: $e');
    }
  }

  // ─── HEARTS (rate-limited) ───
  void triggerHeart() {
    if (_isDisposed) return;

    final now = DateTime.now();
    if (_lastHeartTime != null && now.difference(_lastHeartTime!) < _kHeartRateLimit) {
      return; // Max 10 cœurs/seconde
    }
    _lastHeartTime = now;

    try {
      _service.sendHeart(_realtimeChannel!);
      debugPrint('[LiveViewer] ❤️ Heart sent');
    } catch (e) {
      debugPrint('[LiveViewer] ❌ sendHeart error: $e');
    }
  }

  // ─── QUITTER ───
  Future<void> leaveLive() async {
    if (_isLeaving || _isDisposed) return;
    _isLeaving = true;

    debugPrint('[LiveViewer] 🚪 Leaving live for session ${session.id}');

    // 1. Realtime unsubscribe
    try {
      await _realtimeChannel?.unsubscribe().timeout(_kCleanupTimeout, onTimeout: () {});
      _realtimeChannel = null;
      _realtimeConnected = false;
      debugPrint('[LiveViewer] ✓ Realtime unsubscribed');
    } catch (e) {
      debugPrint('[LiveViewer] ⚠️ unsubscribe error: $e');
    }

    // 2. Agora cleanup
    try {
      await _ensureEngineClean();
      debugPrint('[LiveViewer] ✓ Agora engine cleaned');
    } catch (e) {
      debugPrint('[LiveViewer] ⚠️ engine cleanup error: $e');
    }

    _isLeaving = false;
  }

  // ─── RETRY ───
  Future<void> retry() async {
    if (!canRetry || _isBootstrapping || _isDisposed) return;
    debugPrint('[LiveViewer] 🔄 Retrying connection');
    await _ensureEngineClean();
    await bootstrap();
  }
}
