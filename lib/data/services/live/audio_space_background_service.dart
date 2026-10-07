// lib/data/services/live/audio_space_background_service.dart
//
// ============================================================================
// 🔊 AUDIO SPACE BACKGROUND SERVICE
// ============================================================================
// Gère la persistance audio en arrière-plan :
//   ✅ Agora continue quand l'app est en background
//   ✅ Wake lock (empêche la veille de l'écran)
//   ✅ Détection appels entrants → pause auto
//   ✅ Audio session iOS (mix avec autres apps)
//   ✅ Émet stream lifecycle pour le manager
//   ⚠️ Notification persistante DÉSACTIVÉE (crash Drawable resource ID = 0)
// ============================================================================

import 'dart:async';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:thix_id/data/services/live/live_service.dart';
import 'package:thix_id/data/models/live/audio_space_model.dart';
import 'package:thix_id/data/services/live/audio_space_service.dart';
import 'package:audio_service/audio_service.dart';
/// Statut du service de fond
enum BackgroundServiceStatus {
  idle,
  preparing,
  active,
  background,
  pausedByCall,
  error,
}

class AudioSpaceBackgroundService with WidgetsBindingObserver {
  AudioSpaceBackgroundService._internal();
  static final AudioSpaceBackgroundService instance =
      AudioSpaceBackgroundService._internal();

  factory AudioSpaceBackgroundService() => instance;

  // ─────────────────────────────────────────────────────────────
  // ÉTAT
  // ─────────────────────────────────────────────────────────────
  BackgroundServiceStatus _status = BackgroundServiceStatus.idle;
  BackgroundServiceStatus get status => _status;

  AudioSpace? _currentSpace;
  AudioSpaceParticipant? _currentMe;
  RtcEngine? _engine;
  bool _isMuted = false;
  bool _isHost = false;

  // Stream lifecycle (true = background, false = foreground)
  final StreamController<bool> _lifecycleController =
      StreamController<bool>.broadcast();
  Stream<bool> get onAppLifecycleChanged => _lifecycleController.stream;

  // ─────────────────────────────────────────────────────────────
  // INITIALISATION
  // ─────────────────────────────────────────────────────────────
  Future<void> _ensureInitialized() async {
    WidgetsBinding.instance.addObserver(this);
    debugPrint('[BGService] ✓ Initialisé (notifications désactivées)');
  }

  // ─────────────────────────────────────────────────────────────
  // CYCLE DE VIE APP (observer)
  // ─────────────────────────────────────────────────────────────
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    debugPrint('[BGService] Lifecycle → $state');

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      _lifecycleController.add(true); // background
    } else if (state == AppLifecycleState.resumed) {
      _lifecycleController.add(false); // foreground
      _recoverFromBackground();
    }
  }

  Future<void> _recoverFromBackground() async {
    if (_status != BackgroundServiceStatus.background) return;
    _status = BackgroundServiceStatus.active;
    debugPrint('[BGService] ✓ Retour au premier plan');
  }

  // ─────────────────────────────────────────────────────────────
  // PERMISSIONS
  // ─────────────────────────────────────────────────────────────
  Future<bool> _requestPermissions() async {
    try {
      final mic = await Permission.microphone.request();
      if (!mic.isGranted) {
        debugPrint('[BGService] ✗ Micro refusé');
        return false;
      }

      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        final phone = await Permission.phone.request();
        debugPrint('[BGService] Permissions → phone: ${phone.isGranted}');
      }

      return true;
    } catch (e) {
      debugPrint('[BGService] Permission error: $e');
      return false;
    }
  }

  // ─────────────────────────────────────────────────────────────
  // DÉMARRER AGORA
  // ─────────────────────────────────────────────────────────────
  Future<void> startAgora({
    required AudioSpace space,
    required AudioSpaceParticipant me,
    required bool isHost,
  }) async {
    if (_status == BackgroundServiceStatus.active ||
        _status == BackgroundServiceStatus.background) {
      debugPrint('[BGService] ⚠️ Déjà actif');
      return;
    }

    _status = BackgroundServiceStatus.preparing;
    _currentSpace = space;
    _currentMe = me;
    _isHost = isHost;
    _isMuted = me.isMuted;

    await _ensureInitialized();

    // 1. Permissions
    if (!await _requestPermissions()) {
      _status = BackgroundServiceStatus.error;
      throw Exception('Permission micro refusée');
    }

    // 2. Wake lock (empêche la veille)
    try {
      await WakelockPlus.enable();
      debugPrint('[BGService] ✓ Wake lock activé');
    } catch (e) {
      debugPrint('[BGService] ⚠️ Wake lock: $e');
    }

    // 3. Audio session iOS
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      try {
        await SystemChannels.platform.invokeMethod(
          'setAudioSessionCategory',
          'playAndRecord',
        );
      } catch (e) {
        debugPrint('[BGService] ⚠️ iOS audio session: $e');
      }
    }

    // 4. Créer l'engine Agora
    try {
      await _initAgoraEngine(space, me, isHost);
    } catch (e, st) {
      debugPrint('[BGService] ✗ Agora init: $e\n$st');
      _status = BackgroundServiceStatus.error;
      rethrow;
    }

    // 5. Notification persistante → DÉSACTIVÉE
    // Le plugin flutter_local_notifications crash avec
    // "Drawable resource ID must not be 0" car les icônes
    // @mipmap/ic_launcher et @drawable/ic_close n'existent pas
    // dans res/drawable/. L'audio fonctionne sans notification.
    debugPrint('[BGService] ℹ️ Notification persistante désactivée');

    _status = BackgroundServiceStatus.active;
    debugPrint('[BGService] ✓ Agora démarré pour ${space.title}');
  }

  Future<void> _initAgoraEngine(
    AudioSpace space,
    AudioSpaceParticipant me,
    bool isHost,
  ) async {
    final service = AudioSpaceService(LiveService());
    final canSpeak = me.role == AudioSpaceRole.host ||
        me.role == AudioSpaceRole.cohost ||
        me.role == AudioSpaceRole.speaker;

    // Générer UID stable (même logique que le manager)
    final uid = _stableUid(me.userId);

    // Récupérer token
    final creds = await service.fetchCredentials(
      space.channelName,
      uid: uid,
      isPublisher: canSpeak,
    );

    if (creds.appId.isEmpty || creds.token.isEmpty) {
      throw Exception('Token Agora incomplet');
    }

    // Nettoyer l'ancien engine si existant
    if (_engine != null) {
      try {
        await _engine!.leaveChannel();
        await _engine!.release();
      } catch (_) {}
      _engine = null;
    }

    _engine = createAgoraRtcEngine();
    await _engine!.initialize(RtcEngineContext(
      appId: creds.appId,
      channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
    ));

    _engine!.registerEventHandler(RtcEngineEventHandler(
      onJoinChannelSuccess: (c, elapsed) {
        debugPrint('[BGService] ✓ Agora joined → channel=${c.channelId}');
      },
      onUserJoined: (c, remoteUid, elapsed) {
        debugPrint('[BGService] User joined → $remoteUid');
      },
      onUserOffline: (c, remoteUid, reason) {
        debugPrint('[BGService] User offline → $remoteUid');
      },
      onError: (err, msg) {
        debugPrint('[BGService] Agora ERROR $err: $msg');
      },
      onAudioPublishStateChanged: (c, oldState, newState, elapsed) {
        debugPrint('[BGService] Audio publish: $oldState → $newState');
      },
    ));

    await _engine!.enableAudio();

    if (!kIsWeb) {
      try {
        await _engine!.disableVideo();
      } catch (_) {}
      try {
        await _engine!.setEnableSpeakerphone(true);
      } catch (_) {}
    }

    final role = canSpeak
        ? ClientRoleType.clientRoleBroadcaster
        : ClientRoleType.clientRoleAudience;

    await _engine!.setClientRole(role: role);
    await _engine!.muteLocalAudioStream(!canSpeak || me.isMuted);

    await _engine!.joinChannel(
      token: creds.token,
      channelId: space.channelName,
      uid: uid,
      options: ChannelMediaOptions(
        channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
        clientRoleType: role,
        publishMicrophoneTrack: canSpeak,
        autoSubscribeAudio: true,
        autoSubscribeVideo: false,
      ),
    );
  }

  int _stableUid(String userId) {
    final clean = userId.replaceAll('-', '');
    return int.parse(clean.substring(0, 8), radix: 16) & 0x7FFFFFFF;
  }

  // ─────────────────────────────────────────────────────────────
  // ARRÊTER AGORA
  // ─────────────────────────────────────────────────────────────
  Future<void> stopAgora() async {
    debugPrint('[BGService] Arrêt Agora...');

    try {
      await WakelockPlus.disable();
    } catch (_) {}

    try {
      await _engine?.leaveChannel();
      await _engine?.release();
    } catch (e) {
      debugPrint('[BGService] ⚠️ Agora cleanup: $e');
    }
    _engine = null;

    _currentSpace = null;
    _currentMe = null;
    _isHost = false;
    _status = BackgroundServiceStatus.idle;

    debugPrint('[BGService] ✓ Arrêt complet');
  }

  // ─────────────────────────────────────────────────────────────
  // MUTE / UNMUTE
  // ─────────────────────────────────────────────────────────────
  Future<void> setMuted(bool muted) async {
    _isMuted = muted;
    try {
      await _engine?.muteLocalAudioStream(muted);
      debugPrint('[BGService] ${muted ? "🔇 Muted" : "🎙️ Unmuted"}');
    } catch (e) {
      debugPrint('[BGService] ⚠️ setMuted: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────
  // CHANGEMENT DE RÔLE (promote/demote)
  // ─────────────────────────────────────────────────────────────
  Future<void> onMyRoleChanged({
    required String newRole,
    required AudioSpace space,
    required AudioSpaceParticipant me,
  }) async {
    debugPrint('[BGService] Changement de rôle détecté → $newRole');
    _currentMe = me;

    // Rejoindre à nouveau avec le bon token (publisher/subscriber)
    try {
      await _initAgoraEngine(space, me, _isHost);
      debugPrint('[BGService] ✓ Agora rejoin avec nouveau rôle');
    } catch (e) {
      debugPrint('[BGService] ✗ Rejoin failed: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────
  // MODE BACKGROUND
  // ─────────────────────────────────────────────────────────────
  Future<void> prepareBackgroundMode() async {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      try {
        await SystemChannels.platform.invokeMethod(
          'setAudioSessionCategory',
          'playAndRecord',
        );
      } catch (_) {}
    }
  }

  Future<void> enterBackgroundMode({
    required String spaceId,
    required String spaceTitle,
    required bool isHost,
  }) async {
    if (_status != BackgroundServiceStatus.active) return;

    _status = BackgroundServiceStatus.background;
    debugPrint('[BGService] 🔽 Entrée en mode background');
  }

  Future<void> exitBackgroundMode() async {
    if (_status != BackgroundServiceStatus.background) return;

    _status = BackgroundServiceStatus.active;
    debugPrint('[BGService] 🔼 Sortie du mode background');
  }

  // ─────────────────────────────────────────────────────────────
  // NOTIFICATION PERSISTANTE → DÉSACTIVÉE
  // ─────────────────────────────────────────────────────────────
  // Les méthodes ci-dessous sont conservées comme no-op pour
  // éviter les erreurs d'appel depuis le manager.
  // Pour réactiver les notifications plus tard :
  //   1. Créer res/drawable/notification_icon.png (blanc + alpha)
  //   2. Remplacer icon: '@mipmap/ic_launcher' par 'notification_icon'
  //   3. Supprimer les actions Android (ic_close, ic_mic_off manquants)
  //   4. Changer channelId en 'thix_audio_space_v2'

  Future<void> _showPersistentNotification() async {
    // No-op : notification désactivée
  }

  Future<void> _updateNotification({String? subtitle}) async {
    // No-op : notification désactivée
  }

  Future<void> _cancelNotification() async {
    // No-op : notification désactivée
  }

  // ─────────────────────────────────────────────────────────────
  // DÉTECTION APPELS ENTRANTS (pause auto)
  // ─────────────────────────────────────────────────────────────
  void onIncomingPhoneCall() {
    if (_status != BackgroundServiceStatus.active &&
        _status != BackgroundServiceStatus.background) {
      return;
    }

    debugPrint('[BGService] 📞 Appel entrant → pause audio');
    _status = BackgroundServiceStatus.pausedByCall;

    _engine?.muteLocalAudioStream(true).catchError((_) {});
    _engine?.adjustPlaybackSignalVolume(0).catchError((_) {});
  }

  void onPhoneCallEnded() {
    if (_status != BackgroundServiceStatus.pausedByCall) return;

    debugPrint('[BGService] 📞 Appel terminé → reprise audio');
    _status = BackgroundServiceStatus.active;

    _engine?.muteLocalAudioStream(_isMuted).catchError((_) {});
    _engine?.adjustPlaybackSignalVolume(100).catchError((_) {});
  }

  // ─────────────────────────────────────────────────────────────
  // DISPOSE
  // ─────────────────────────────────────────────────────────────
  Future<void> dispose() async {
    WidgetsBinding.instance.removeObserver(this);
    await stopAgora();
    await _lifecycleController.close();
  }
}

// ─────────────────────────────────────────────────────────────
// AUDIO HANDLER (pour audio_service)
// ─────────────────────────────────────────────────────────────
class ThixAudioHandler extends BaseAudioHandler {
  @override
  Future<void> stop() async {
    await AudioSpaceBackgroundService.instance.stopAgora();
  }

  @override
  Future<void> pause() async {
    await AudioSpaceBackgroundService.instance.setMuted(true);
  }

  @override
  Future<void> play() async {
    await AudioSpaceBackgroundService.instance.setMuted(false);
  }
}
