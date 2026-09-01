// lib/presentation/chat/call/providers/call_provider.dart
//
// ============================================================================
// CALL PROVIDER — Production Enterprise
// ============================================================================
//
// Contrôleur global des appels VoIP (Agora RTC + Supabase Realtime).
//
// Architecture :
//   - Services injectés via Riverpod (testables)
//   - Accès DB via supabaseClientProvider
//   - StateNotifier pour état réactif
//
// Sécurité :
//   - Validation UUID stricte sur tous les user IDs
//   - Sanitization XSS sur les noms
//   - Pas d'exposition de stack traces
//   - Timeouts sur tous les appels réseau
//
// Robustesse :
//   - Retry sur appels signal
//   - Mounted checks sur callbacks async
//   - Cleanup garanti des timers/subscriptions
// ============================================================================

import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:thix_id/models/chat/call_invite.dart';
import 'package:thix_id/models/chat/call_status.dart';
import 'package:thix_id/presentation/chat/providers/chat_providers.dart';
import 'package:thix_id/services/chat/call_service.dart';  
import 'package:thix_id/services/chat/call_service.dart';
import 'package:thix_id/services/chat/call_signaling_service.dart';

// ============================================================================
// CONSTANTS
// ============================================================================
const Duration _kRingTimeout = Duration(seconds: 45);
const Duration _kBusyDelay = Duration(seconds: 3);
const Duration _kFailDelay = Duration(seconds: 2);
const Duration _kUserLeftDelay = Duration(seconds: 1);
const Duration _kNetworkTimeout = Duration(seconds: 15);
const int _kMaxRetries = 2;
const Duration _kRetryDelay = Duration(milliseconds: 500);
const int _kMaxNameLength = 100;
const int _kMaxChannelLength = 100;

// ============================================================================
// VALIDATORS
// ============================================================================
class _CallValidators {
  _CallValidators._();

  /// Valide un UUID v4 strict
  static bool isValidUuid(String? id) {
    if (id == null || id.isEmpty) return false;
    return RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
      caseSensitive: false,
    ).hasMatch(id);
  }

  /// Sanitize un nom (XSS + caractères de contrôle)
  static String sanitizeName(String? input, {int maxLength = _kMaxNameLength}) {
    if (input == null || input.trim().isEmpty) return '';
    var s = input
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '')
        .trim();
    return s.length > maxLength ? s.substring(0, maxLength) : s;
  }

  /// Sanitize un channel name
  static String sanitizeChannel(String? input) {
    if (input == null || input.trim().isEmpty) return '';
    var s = input
        .replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '')
        .trim();
    return s.length > _kMaxChannelLength ? s.substring(0, _kMaxChannelLength) : s;
  }

  /// Détermine un UID numérique stable à partir de l'UUID
  static int uidFromUuid(String userId) {
    var hash = 0x811c9dc5;
    for (final c in userId.codeUnits) {
      hash ^= c;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    final uid = hash & 0x7fffffff;
    return uid == 0 ? 1 : uid;
  }
}

// ============================================================================
// STATE
// ============================================================================

/// État global d'un appel (en cours, en sonnerie, terminé, etc.)
class CallState {
  final CallStatus status;
  final CallType type;
  final String? inviteId;
  final String? channelName;
  final String? remoteUserId;
  final String? remoteName;
  final String? remoteAvatar;
  final int? remoteUid;
  final bool muted;
  final bool videoOff;
  final bool speakerOn;
  final bool isFrontCam;
  final bool isCaller;
  final Duration duration;
  final String? error;
  final String? conversationId;

  const CallState({
    this.status = CallStatus.idle,
    this.type = CallType.audio,
    this.inviteId,
    this.channelName,
    this.remoteUserId,
    this.remoteName,
    this.remoteAvatar,
    this.remoteUid,
    this.muted = false,
    this.videoOff = false,
    this.speakerOn = true,
    this.isFrontCam = true,
    this.isCaller = true,
    this.duration = Duration.zero,
    this.error,
    this.conversationId,
  });

  CallState copyWith({
    CallStatus? status,
    CallType? type,
    String? inviteId,
    String? channelName,
    String? remoteUserId,
    String? remoteName,
    String? remoteAvatar,
    int? remoteUid,
    bool? muted,
    bool? videoOff,
    bool? speakerOn,
    bool? isFrontCam,
    bool? isCaller,
    Duration? duration,
    String? error,
    bool clearError = false,
    String? conversationId,
  }) {
    return CallState(
      status: status ?? this.status,
      type: type ?? this.type,
      inviteId: inviteId ?? this.inviteId,
      channelName: channelName ?? this.channelName,
      remoteUserId: remoteUserId ?? this.remoteUserId,
      remoteName: remoteName ?? this.remoteName,
      remoteAvatar: remoteAvatar ?? this.remoteAvatar,
      remoteUid: remoteUid ?? this.remoteUid,
      muted: muted ?? this.muted,
      videoOff: videoOff ?? this.videoOff,
      speakerOn: speakerOn ?? this.speakerOn,
      isFrontCam: isFrontCam ?? this.isFrontCam,
      isCaller: isCaller ?? this.isCaller,
      duration: duration ?? this.duration,
      error: clearError ? null : (error ?? this.error),
      conversationId: conversationId ?? this.conversationId,
    );
  }

  bool get isVideo => type == CallType.video;
  bool get isActive =>
      status == CallStatus.ringing ||
      status == CallStatus.accepted ||
      status == CallStatus.ongoing;
}

// ============================================================================
// NOTIFIER
// ============================================================================

/// Contrôleur global de l'appel (Riverpod StateNotifier).
///
/// Gère :
/// - L'initialisation / acceptation / rejet des appels
/// - La préview caméra locale pendant la sonnerie
/// - La signalisation Supabase Realtime
/// - L'historique des appels dans la conversation
class CallNotifier extends StateNotifier<CallState> {
  final Ref _ref;
  final CallMediaService _media;
  final CallSignalingService _signal;
  final AudioPlayer _ringPlayer = AudioPlayer();

  Timer? _timer;
  Timer? _ringTimeout;
  StreamSubscription? _statusSub;
  bool _isDisposed = false;

  CallNotifier(this._ref, this._media, this._signal)
      : super(const CallState()) {
    debugPrint('[CallProvider] 🚀 Initialized');
  }

  SupabaseClient get _db => _ref.read(supabaseClientProvider);

  // ==================================================================
  // SONS
  // ==================================================================

  Future<void> _playRingtone() async {
    try {
      await _ringPlayer.setReleaseMode(ReleaseMode.loop);
      await _ringPlayer.play(AssetSource('sounds/ringtone.mp3'));
      debugPrint('[CallProvider] 🔊 Ringtone started');
    } catch (e) {
      debugPrint('[CallProvider] ⚠️ Ringtone error: $e');
    }
  }

  Future<void> _playOfflineTone() async {
    try {
      await _ringPlayer.setReleaseMode(ReleaseMode.release);
      await _ringPlayer.play(AssetSource('sounds/offline.mp3'));
      debugPrint('[CallProvider] 🔊 Offline tone played');
    } catch (e) {
      debugPrint('[CallProvider] ⚠️ Offline tone error: $e');
    }
  }

  Future<void> _stopRingtone() async {
    try {
      await _ringPlayer.stop();
    } catch (_) {}
  }

  // ==================================================================
  // HELPERS
  // ==================================================================

  /// Récupère ou crée une conversation 1-to-1 entre deux utilisateurs.
  Future<String?> _getOrCreateConversationId(
    String currentUserId,
    String otherUserId,
  ) async {
    try {
      final res = await _db
          .from('conversations')
          .select('id')
          .contains('participant_ids', [currentUserId, otherUserId])
          .eq('is_group', false)
          .maybeSingle()
          .timeout(_kNetworkTimeout);

      if (res != null) return res['id'] as String;

      final newConv = await _db
          .from('conversations')
          .insert({
            'participant_ids': [currentUserId, otherUserId],
            'is_group': false,
          })
          .select('id')
          .single()
          .timeout(_kNetworkTimeout);

      return newConv['id'] as String;
    } catch (e) {
      debugPrint('[CallProvider] ⚠️ getOrCreateConversation failed: $e');
      return null;
    }
  }

  /// Enregistre un échec avec message user-friendly (pas de stack trace).
  void _fail(String where, Object e) {
    final msg = _friendlyError(e);
    debugPrint('[CallProvider] ❌ FAIL [$where]: $msg');
    if (!_isDisposed) {
      state = state.copyWith(status: CallStatus.failed, error: msg);
    }
  }

  /// Retourne un message d'erreur user-friendly.
  String _friendlyError(Object e) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('timeout')) return 'Délai d\'attente dépassé';
    if (msg.contains('network')) return 'Erreur de connexion réseau';
    if (msg.contains('permission')) return 'Permission refusée';
    if (msg.contains('busy')) return 'Destinataire occupé';
    if (msg.contains('not found')) return 'Ressource introuvable';
    return 'Une erreur est survenue';
  }

  /// Retry helper pour appels réseau.
  Future<T> _retry<T>(
    Future<T> Function() fn, {
    required String label,
    int maxRetries = _kMaxRetries,
  }) async {
    int attempt = 0;
    while (true) {
      try {
        return await fn().timeout(_kNetworkTimeout);
      } on TimeoutException {
        attempt++;
        if (attempt > maxRetries) {
          debugPrint('[CallProvider] ❌ $label: timeout after $attempt attempts');
          rethrow;
        }
        debugPrint('[CallProvider] ⏱️ $label timeout — retry $attempt/$maxRetries');
        await Future.delayed(_kRetryDelay);
      } catch (e) {
        attempt++;
        if (attempt > maxRetries) {
          debugPrint('[CallProvider] ❌ $label failed after $attempt attempts: $e');
          rethrow;
        }
        debugPrint('[CallProvider] ⚠️ $label error — retry $attempt: $e');
        await Future.delayed(_kRetryDelay);
      }
    }
  }

  // ==================================================================
  // PRÉVIEW CAMÉRA LOCALE
  // ==================================================================

  /// Démarre la préview caméra locale avant l'acceptation (appels vidéo).
  Future<void> prepareLocalPreview(String myUserId) async {
    if (_isDisposed) return;

    final channel = _CallValidators.sanitizeChannel(state.channelName);
    if (channel.isEmpty) {
      debugPrint('[CallProvider] ⚠️ prepareLocalPreview: empty channel');
      return;
    }

    if (!_CallValidators.isValidUuid(myUserId)) {
      debugPrint('[CallProvider] ⚠️ prepareLocalPreview: invalid userId');
      return;
    }

    try {
      await _media.prepareLocalPreview(
        channel: channel,
        uid: _CallValidators.uidFromUuid(myUserId),
      );
      debugPrint('[CallProvider] ✓ Local preview prepared');
      if (!_isDisposed) {
        state = state.copyWith(); // Trigger rebuild
      }
    } catch (e) {
      debugPrint('[CallProvider] ⚠️ Local preview failed: $e');
    }
  }

  // ==================================================================
  // START CALL (appelant)
  // ==================================================================

  Future<void> start({
    required String myUserId,
    required String calleeId,
    required String calleeName,
    String? calleeAvatar,
    required CallType type,
    String? conversationId,
  }) async {
    if (_isDisposed) return;

    // Validation des inputs
    if (!_CallValidators.isValidUuid(myUserId)) {
      debugPrint('[CallProvider] ⚠️ start: invalid myUserId');
      _fail('start', 'Identifiant utilisateur invalide');
      return;
    }
    if (!_CallValidators.isValidUuid(calleeId)) {
      debugPrint('[CallProvider] ⚠️ start: invalid calleeId');
      _fail('start', 'Identifiant destinataire invalide');
      return;
    }

    // Protection contre les appels multiples
    if (state.isActive) {
      debugPrint('[CallProvider] ⚠️ start ignored: call already active');
      return;
    }

    final sanitizedName = _CallValidators.sanitizeName(calleeName);
    debugPrint('[CallProvider] 📞 Starting call to ${_obfuscate(calleeId)} '
        '(type=${type.name})');

    try {
      final convId = conversationId ??
          await _getOrCreateConversationId(myUserId, calleeId);

      if (_isDisposed) return;

      state = state.copyWith(
        status: CallStatus.ringing,
        type: type,
        isCaller: true,
        remoteUserId: calleeId,
        remoteName: sanitizedName,
        remoteAvatar: calleeAvatar,
        conversationId: convId,
        clearError: true,
      );

      final invite = await _retry(
        () => _signal.startCall(calleeId: calleeId, type: type),
        label: 'startCall',
      );

      if (_isDisposed) return;

      if (invite.status == CallStatus.busy) {
        debugPrint('[CallProvider] ⚠️ Callee busy');
        state = state.copyWith(
          status: CallStatus.busy,
          error: 'Destinataire occupé',
        );
        _playOfflineTone();
        Future.delayed(_kBusyDelay, () {
          if (!_isDisposed) hangUp(skipSignal: true);
        });
        return;
      }

      final channelName = _CallValidators.sanitizeChannel(invite.channelName);
      if (channelName.isEmpty) {
        _fail('start', 'Nom de canal vide');
        _playOfflineTone();
        Future.delayed(_kFailDelay, () {
          if (!_isDisposed) hangUp(skipSignal: true);
        });
        return;
      }

      state = state.copyWith(
        inviteId: invite.id,
        channelName: channelName,
      );

      _playRingtone();

      // Préview caméra locale côté appelant (appels vidéo uniquement)
      if (type == CallType.video) {
        unawaited(prepareLocalPreview(myUserId).catchError((e) {
          debugPrint('[CallProvider] ⚠️ prepareLocalPreview async error: $e');
        }));
      }

      _ringTimeout?.cancel();
      _ringTimeout = Timer(_kRingTimeout, () async {
        if (_isDisposed) return;
        if (state.status == CallStatus.ringing && state.inviteId != null) {
          debugPrint('[CallProvider] ⏱️ Ring timeout');
          try {
            await _signal.markMissed(state.inviteId!);
          } catch (_) {}
          await hangUp();
        }
      });

      _statusSub?.cancel();
      _statusSub = _signal.watchInviteStatus(invite.id).listen((s) async {
        if (_isDisposed) return;

        if (s == CallStatus.accepted || s == CallStatus.ongoing) {
          debugPrint('[CallProvider] ✓ Call accepted/ongoing');
          _ringTimeout?.cancel();
          _stopRingtone();
          await _joinAgora(myUserId);
        } else if (s == CallStatus.rejected || s == CallStatus.canceled) {
          debugPrint('[CallProvider] ⚠️ Call rejected/canceled');
          _stopRingtone();
          _playOfflineTone();
          Future.delayed(_kFailDelay, () {
            if (!_isDisposed) hangUp(skipSignal: true);
          });
        } else if (s.isFinished) {
          debugPrint('[CallProvider] 🔚 Call finished');
          await hangUp(skipSignal: true);
        }
      });
    } catch (e) {
      debugPrint('[CallProvider] ❌ start failed: $e');
      _fail('start', e);
      _playOfflineTone();
      Future.delayed(_kFailDelay, () {
        if (!_isDisposed) hangUp(skipSignal: true);
      });
    }
  }

  // ==================================================================
  // ACCEPT CALL (appelé)
  // ==================================================================

  Future<void> acceptIncoming({
    required CallInvite invite,
    required String myUserId,
    String? callerName,
    String? callerAvatar,
  }) async {
    if (_isDisposed) return;

    // Validation
    if (!_CallValidators.isValidUuid(myUserId)) {
      debugPrint('[CallProvider] ⚠️ acceptIncoming: invalid myUserId');
      _fail('acceptIncoming', 'Identifiant utilisateur invalide');
      return;
    }
    if (!_CallValidators.isValidUuid(invite.callerId)) {
      debugPrint('[CallProvider] ⚠️ acceptIncoming: invalid callerId');
      _fail('acceptIncoming', 'Identifiant appelant invalide');
      return;
    }

    // Protection contre les appels multiples
    if (state.isActive) {
      debugPrint('[CallProvider] ⚠️ acceptIncoming ignored: call already active');
      return;
    }

    final channelName = _CallValidators.sanitizeChannel(invite.channelName);
    if (channelName.isEmpty) {
      _fail('acceptIncoming', 'Nom de canal manquant');
      return;
    }

    final sanitizedName = _CallValidators.sanitizeName(
      callerName ?? invite.callerName,
    );

    debugPrint('[CallProvider] 📞 Accepting call ${invite.id} '
        'channel=$channelName');

    try {
      final convId = await _getOrCreateConversationId(myUserId, invite.callerId);

      if (_isDisposed) return;

      state = state.copyWith(
        status: CallStatus.accepted,
        type: invite.callType,
        isCaller: false,
        inviteId: invite.id,
        channelName: channelName,
        remoteUserId: invite.callerId,
        remoteName: sanitizedName,
        remoteAvatar: callerAvatar ?? invite.callerAvatar,
        conversationId: convId,
        clearError: true,
      );

      _stopRingtone();

      await _retry(
        () => _signal.accept(invite.id),
        label: 'accept',
      );

      if (_isDisposed) return;

      await _joinAgora(myUserId);
    } catch (e) {
      debugPrint('[CallProvider] ❌ acceptIncoming failed: $e');
      _fail('acceptIncoming', e);
    }
  }

  Future<void> rejectIncoming(String inviteId) async {
    if (_isDisposed) return;

    if (!_CallValidators.isValidUuid(inviteId)) {
      debugPrint('[CallProvider] ⚠️ rejectIncoming: invalid inviteId');
      return;
    }

    debugPrint('[CallProvider] 📞 Rejecting call ${_obfuscate(inviteId)}');
    _stopRingtone();

    try {
      await _retry(
        () => _signal.reject(inviteId),
        label: 'reject',
      );
    } catch (e) {
      debugPrint('[CallProvider] ⚠️ rejectIncoming error: $e');
    }

    if (!_isDisposed) {
      state = const CallState();
    }
  }

  // ==================================================================
  // JOIN AGORA
  // ==================================================================

  Future<void> _joinAgora(String myUserId) async {
    if (_isDisposed) return;

    final channel = _CallValidators.sanitizeChannel(state.channelName);
    final inviteId = state.inviteId;

    if (channel.isEmpty) {
      _fail('_joinAgora', 'Nom de canal vide');
      return;
    }

    if (!_CallValidators.isValidUuid(myUserId)) {
      _fail('_joinAgora', 'Identifiant utilisateur invalide');
      return;
    }

    final uid = _CallValidators.uidFromUuid(myUserId);
    debugPrint('[CallProvider] 📞 Joining Agora channel=$channel uid=$uid '
        'type=${state.type.name}');

    try {
      await _media.join(
        channel: channel,
        type: state.type,
        uid: uid,
        onUserJoined: (remoteUid) async {
          if (_isDisposed) return;
          debugPrint('[CallProvider] 👤 Remote user joined: $remoteUid');
          state = state.copyWith(
            remoteUid: remoteUid,
            status: CallStatus.ongoing,
          );
          if (inviteId != null) {
            try {
              await _retry(
                () => _signal.markOngoing(inviteId),
                label: 'markOngoing',
                maxRetries: 1,
              );
            } catch (e) {
              debugPrint('[CallProvider] ⚠️ markOngoing error: $e');
            }
          }
          _startTimer();
        },
        onUserLeft: (_) async {
          if (_isDisposed) return;
          debugPrint('[CallProvider] 👋 Remote user left');
          _playOfflineTone();
          Future.delayed(_kUserLeftDelay, () {
            if (!_isDisposed) hangUp();
          });
        },
        onError: (err) {
          if (_isDisposed) return;
          debugPrint('[CallProvider] ❌ media onError: $err');
          state = state.copyWith(
            status: CallStatus.failed,
            error: _friendlyError(err),
          );
        },
      );

      if (!_isDisposed && state.status == CallStatus.accepted) {
        state = state.copyWith(status: CallStatus.ongoing);
        _startTimer();
      }
    } catch (e) {
      debugPrint('[CallProvider] ❌ _joinAgora failed: $e');
      _fail('_joinAgora', e);
    }
  }

  // ==================================================================
  // TIMER D'APPEL
  // ==================================================================

  void _startTimer() {
    if (_isDisposed) return;

    _timer?.cancel();
    final start = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_isDisposed) {
        _timer?.cancel();
        return;
      }
      state = state.copyWith(duration: DateTime.now().difference(start));
    });
    debugPrint('[CallProvider] ⏱️ Timer started');
  }

  // ==================================================================
  // CONTRÔLES MÉDIA
  // ==================================================================

  Future<void> toggleMute() async {
    if (_isDisposed) return;
    final next = !state.muted;
    try {
      await _media.setMuted(next);
      if (!_isDisposed) state = state.copyWith(muted: next);
      debugPrint('[CallProvider] 🎤 Mute: $next');
    } catch (e) {
      debugPrint('[CallProvider] ❌ toggleMute error: $e');
    }
  }

  Future<void> toggleVideo() async {
    if (_isDisposed) return;
    final next = !state.videoOff;
    try {
      await _media.setVideoOff(next);
      if (!_isDisposed) state = state.copyWith(videoOff: next);
      debugPrint('[CallProvider] 📹 Video off: $next');
    } catch (e) {
      debugPrint('[CallProvider] ❌ toggleVideo error: $e');
    }
  }

  Future<void> switchCamera() async {
    if (_isDisposed) return;
    try {
      await _media.switchCamera();
      if (!_isDisposed) state = state.copyWith(isFrontCam: !state.isFrontCam);
      debugPrint('[CallProvider] 🔄 Camera switched');
    } catch (e) {
      debugPrint('[CallProvider] ❌ switchCamera error: $e');
    }
  }

  Future<void> toggleSpeaker() async {
    if (_isDisposed) return;
    final next = !state.speakerOn;
    try {
      await _media.setSpeaker(next);
      if (!_isDisposed) state = state.copyWith(speakerOn: next);
      debugPrint('[CallProvider] 🔊 Speaker: $next');
    } catch (e) {
      debugPrint('[CallProvider] ❌ toggleSpeaker error: $e');
    }
  }

  // ==================================================================
  // RACCROCHER
  // ==================================================================

  Future<void> hangUp({bool skipSignal = false}) async {
    if (_isDisposed) return;

    debugPrint('[CallProvider] 📞 Hanging up (skipSignal=$skipSignal)');

    _stopRingtone();

    final inviteId = state.inviteId;
    final secs = state.duration.inSeconds;
    final wasCaller = state.isCaller;
    final wasRinging = state.status == CallStatus.ringing;
    final convId = state.conversationId;
    final isVideoCall = state.isVideo;
    final duration = state.duration;

    _timer?.cancel();
    _timer = null;
    _ringTimeout?.cancel();
    _ringTimeout = null;
    _statusSub?.cancel();
    _statusSub = null;

    // leave() quitte le channel et stoppe la préview sans détruire le moteur
    try {
      await _media.leave();
    } catch (e) {
      debugPrint('[CallProvider] ⚠️ media.leave error: $e');
    }

    if (!skipSignal && inviteId != null && _CallValidators.isValidUuid(inviteId)) {
      try {
        if (wasRinging && wasCaller) {
          await _retry(
            () => _signal.cancel(inviteId),
            label: 'cancel',
            maxRetries: 1,
          );
        } else {
          await _retry(
            () => _signal.end(inviteId, durationSec: secs),
            label: 'end',
            maxRetries: 1,
          );
        }
      } catch (e) {
        debugPrint('[CallProvider] ⚠️ Signal error: $e');
      }
    }

    // Historique dans la conversation (uniquement côté appelant)
    if (convId != null && convId.isNotEmpty && wasCaller) {
      try {
        final chatSvc = _ref.read(chatServiceProvider);
        final isMissed = duration.inSeconds == 0;
        final mediaTypeStr = isVideoCall ? 'call_video' : 'call_audio';

        // Formatage de la durée
        final m = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
        final s = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
        final h = duration.inHours;
        final timeStr = h > 0 ? '$h:$m:$s' : '$m:$s';

        // TODO: i18n — utiliser les clés de traduction
        final textType = isVideoCall ? 'Appel vidéo' : 'Appel audio';
        final content = isMissed ? '$textType manqué' : '$textType ($timeStr)';

        await chatSvc.sendMessage(
          conversationId: convId,
          content: content,
          mediaType: mediaTypeStr,
        );
        debugPrint('[CallProvider] ✓ Call history saved');
      } catch (e) {
        debugPrint('[CallProvider] ⚠️ Call history error: $e');
      }
    }

    if (!_isDisposed) {
      state = const CallState();
    }
  }

  // ==================================================================
  // DISPOSE
  // ==================================================================

  @override
  void dispose() {
    _isDisposed = true;
    debugPrint('[CallProvider] 👋 Disposed');

    _stopRingtone();
    _ringPlayer.dispose();
    _timer?.cancel();
    _timer = null;
    _ringTimeout?.cancel();
    _ringTimeout = null;
    _statusSub?.cancel();
    _statusSub = null;

    // disposeEngine() libère le moteur RTC
    _media.disposeEngine();
    _signal.dispose();
    super.dispose();
  }

  // ==================================================================
  // HELPERS
  // ==================================================================

  String _obfuscate(String? s) {
    if (s == null || s.length <= 8) return '***';
    return '${s.substring(0, 4)}...${s.substring(s.length - 4)}';
  }
}

// ============================================================================
// PROVIDERS
// ============================================================================

/// Provider pour CallMediaService (singleton).
final callMediaServiceProvider = Provider<CallMediaService>((ref) {
  final service = CallMediaService();
  debugPrint('[callMediaServiceProvider] 🚀 Created');
  ref.onDispose(() {
    debugPrint('[callMediaServiceProvider] 👋 Disposed');
  });
  return service;
});

/// Provider pour CallSignalingService (singleton).
final callSignalingServiceProvider = Provider<CallSignalingService>((ref) {
  final service = CallSignalingService();
  debugPrint('[callSignalingServiceProvider] 🚀 Created');
  ref.onDispose(() {
    debugPrint('[callSignalingServiceProvider] 👋 Disposed');
  });
  return service;
});

/// Provider principal pour le contrôleur d'appel.
final callProvider =
    StateNotifierProvider<CallNotifier, CallState>((ref) {
  final media = ref.watch(callMediaServiceProvider);
  final signal = ref.watch(callSignalingServiceProvider);
  return CallNotifier(ref, media, signal);
});
