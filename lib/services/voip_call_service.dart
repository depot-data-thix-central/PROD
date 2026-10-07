import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_callkit_incoming/entities/call_event.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:vibration/vibration.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:thix_id/services/local_notification_service.dart';

/// Gère les appels entrants comme WhatsApp :
/// - Réveille l'app même si fermée (CallKit iOS / Telecom Android)
/// - Sonnerie + vibration natives
/// - Écran d'appel natif (pas juste une notif)
class VoipCallService {
  VoipCallService._();
  static final VoipCallService instance = VoipCallService._();

  static const String _ringtoneAndroid = 'ringtone'; // assets/sounds/ringtone.mp3
  final FlutterRingtonePlayer _ringtone = FlutterRingtonePlayer();
  bool _isRinging = false;

  /// À appeler dans main.dart AVANT runApp
  Future<void> initialize() async {
    final params = CallKitParams(
      handle: 'THIX Hub',
      nameCaller: 'THIX Hub',
      appName: 'THIX Hub',
      avatar: 'https://i.pravatar.cc/300',
      duration: 60000,
      textAccept: 'Accepter',
      textDecline: 'Refuser',
      textMissedCall: 'Appel manqué',
      textCallback: 'Rappeler',
      extra: <String, dynamic>{'userId': 'thix'},
      headers: <String, dynamic>{'apiKey': 'thix-api-key'},
      android: const AndroidParams(
        isCustomNotification: true,
        isShowLogo: true,
        ringtonePath: 'ringtone.mp3',
        backgroundColor: '#0A2F5C',
        actionColor: '#4CAF50',
        isShowMissedCallNotification: true,
      ),
      ios: const IOSParams(
        iconName: 'AppIcon',
        handleType: 'generic',
        supportsVideo: true,
        maximumCallGroups: 2,
        maximumCallsPerCallGroup: 1,
        audioSessionMode: AVAudioSessionMode.defaultMode,
        audioSessionActive: true,
        audioSessionPreferredSampleRate: 44100.0,
        audioSessionPreferredIOBufferDuration: 0.005,
        supportsDTMF: true,
        supportsHolding: true,
        supportsGrouping: false,
        supportsUngrouping: false,
        ringtonePath: 'ringtone.caf',
      ),
    );

    await FlutterCallkitIncoming.init(params);

    // Écoute les événements d'appels
    FlutterCallkitIncoming.onEvent.listen(_onCallEvent);
  }

  /// Affiche l'écran d'appel entrant NATIF (iOS/Android)
  Future<void> showIncomingCall({
    required String inviteId,
    required String callerName,
    required String callerAvatar,
    required String channelName,
    bool isVideo = false,
  }) async {
    debugPrint('[VOIP] 🔔 Appel entrant: $callerName');

    final params = CallKitParams(
      id: inviteId,
      nameCaller: callerName,
      appName: 'THIX Hub',
      avatar: callerAvatar,
      handle: callerName,
      type: isVideo ? 1 : 0,
      duration: 60000,
      extra: <String, dynamic>{
        'invite_id': inviteId,
        'channel_name': channelName,
        'caller_name': callerName,
      },
      android: const AndroidParams(
        isCustomNotification: true,
        isShowLogo: true,
        ringtonePath: 'ringtone.mp3',
        backgroundColor: '#0A2F5C',
        actionColor: '#4CAF50',
      ),
      ios: IOSParams(
        iconName: 'AppIcon',
        handleType: 'generic',
        supportsVideo: isVideo,
        ringtonePath: 'ringtone.caf',
      ),
    );

    await FlutterCallkitIncoming.showCallkitIncoming(params);

    // 🔊 Sonnerie + vibration natives (fonctionnent même app fermée)
    await _startRinging(isVideo: isVideo);
  }

  /// Démarre sonnerie + vibration persistantes
  Future<void> _startRinging({required bool isVideo}) async {
    if (_isRinging) return;
    _isRinging = true;

    try {
      // Vibration en pattern (comme WhatsApp)
      if (Platform.isAndroid) {
        final hasVibrator = await Vibration.hasVibrator() ?? false;
        if (hasVibrator) {
          await Vibration.vibrate(pattern: [0, 1000, 500, 1000], repeat: 0);
        }
      }

      // Sonnerie (boucle)
      await _ringtone.play(
        android: AndroidSounds.ringtone,
        ios: IosSounds.alert,
        looping: true,
        volume: 1.0,
      );
    } catch (e) {
      debugPrint('[VOIP] ❌ Ringtone error: $e');
    }
  }

  /// Arrête sonnerie + vibration
  Future<void> stopRinging() async {
    if (!_isRinging) return;
    _isRinging = false;
    try {
      await _ringtone.stop();
      if (Platform.isAndroid) await Vibration.cancel();
    } catch (e) {
      debugPrint('[VOIP] ❌ Stop ringing: $e');
    }
  }

  /// Termine l'appel (écran d'appel natif)
  Future<void> endCall(String inviteId) async {
    await FlutterCallkitIncoming.endCall(inviteId);
    await stopRinging();
  }

  /// Handler des événements CallKit
  void _onCallEvent(CallEvent? event) {
    if (event == null) return;
    debugPrint('[VOIP] Event: ${event.event}');

    switch (event.event) {
      case Event.actionCallAccept:
        stopRinging();
        // Naviguer vers la page d'appel
        _navigateToCall(event.body?['extra']);
        break;
      case Event.actionCallDecline:
      case Event.actionCallEnd:
      case Event.actionCallTimeout:
      case Event.actionCallCallback:
        stopRinging();
        FlutterCallkitIncoming.endAllCalls();
        break;
      default:
        break;
    }
  }

  void _navigateToCall(Map<String, dynamic>? extra) {
    // À connecter avec votre GoRouter
    // ex: rootNavigatorKey.currentContext?.push('/call/${extra?['invite_id']}');
  }
}
