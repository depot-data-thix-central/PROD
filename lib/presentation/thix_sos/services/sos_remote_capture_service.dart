// lib/presentation/thix_sos/services/sos_remote_capture_service.dart
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'sos_crisis_media_service.dart';
import 'sos_evidence_service.dart';
import 'sos_service.dart';

/// Pilotage distant : le SECOURS commande, le téléphone VICTIME capte.
/// 100% Supabase (Storage + Realtime) — Agora NON requis pour les captures.
class SosRemoteCaptureService {
  SosRemoteCaptureService._({SosService? sos, SosEvidenceService? evidence})
      : _sos = sos ?? SosService(),
        _evidence = evidence ?? SosEvidenceService();

  static final SosRemoteCaptureService instance = SosRemoteCaptureService._();
  factory SosRemoteCaptureService() => instance;

  final SosService _sos;
  final SosEvidenceService _evidence;

  RealtimeChannel? _ch;
  Timer? _survTimer;
  String? _incidentId;
  String? _conversationId;
  bool _busy = false;

  static const cmdPhoto = 'CMD_CAPTURE_PHOTO';
  static const cmdVideo = 'CMD_CAPTURE_VIDEO';
  static const cmdAudioStart = 'CMD_CAPTURE_AUDIO_START';
  static const cmdAudioStop = 'CMD_CAPTURE_AUDIO_STOP';
  static const cmdInstruct = 'CMD_INSTRUCT';
  static const cmdSurveillanceOn = 'CMD_SURVEILLANCE_ON';
  static const cmdSurveillanceOff = 'CMD_SURVEILLANCE_OFF';

  bool get isBusy => _busy;
  bool get isRecordingAudio => _evidence.isRecordingAudio;
  bool get isSurveillanceOn => _survTimer != null;

  // ─────────────────────────────────────────────────────────────
  // Côté SECOURS : publier une commande (n'ouvre rien en local)
  // ─────────────────────────────────────────────────────────────
  Future<void> requestPhoto(String incidentId) =>
      _sos.logEventPublic(incidentId, cmdPhoto, {'by': 'secours'});

  Future<void> requestVideo(String incidentId) =>
      _sos.logEventPublic(incidentId, cmdVideo, {'by': 'secours'});

  Future<void> requestAudioStart(String incidentId) =>
      _sos.logEventPublic(incidentId, cmdAudioStart, {'by': 'secours'});

  Future<void> requestAudioStop(String incidentId) =>
      _sos.logEventPublic(incidentId, cmdAudioStop, {'by': 'secours'});

  Future<void> requestInstruct(String incidentId, String text) =>
      _sos.logEventPublic(
          incidentId, cmdInstruct, {'by': 'secours', 'text': text});

  Future<void> requestSurveillanceOn(String incidentId) =>
      _sos.logEventPublic(incidentId, cmdSurveillanceOn, {'by': 'secours'});

  Future<void> requestSurveillanceOff(String incidentId) =>
      _sos.logEventPublic(incidentId, cmdSurveillanceOff, {'by': 'secours'});

  // ─────────────────────────────────────────────────────────────
  // Côté VICTIME : écouter et exécuter sur CE téléphone
  // ─────────────────────────────────────────────────────────────
  void listenAsVictim({
    required String incidentId,
    String? conversationId,
    void Function(String msg)? onInfo,
    void Function(Object err)? onError,
  }) {
    stop();
    _incidentId = incidentId;
    _conversationId = conversationId;
    _ch = Supabase.instance.client
        .channel('sos-capture-$incidentId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'thix_sos_events',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'incident_id',
            value: incidentId,
          ),
          callback: (payload) {
            final rec = payload.newRecord;
            if (rec == null) return;
            final type = (rec['type'] ?? rec['event_type'] ?? '').toString();
            final meta =
                Map<String, dynamic>.from((rec['payload'] as Map?) ?? {});
            unawaited(_handle(type, meta, onInfo: onInfo, onError: onError));
          },
        )
        .subscribe();
  }

  Future<void> _handle(
    String type,
    Map<String, dynamic> meta, {
    void Function(String msg)? onInfo,
    void Function(Object err)? onError,
  }) async {
    final id = _incidentId;
    if (id == null) return;
    if (_busy && type != cmdAudioStop && type != cmdInstruct) return;

    try {
      switch (type) {
        case cmdPhoto:
          _busy = true;
          onInfo?.call('📸 Photo demandée par le secours…');
          final e = await SosCrisisMediaService.instance.withCameraReleased(
            () => _evidence.takePhoto(id, conversationId: _conversationId),
          );
          if (e == null) {
            await _sos.logEventPublic(id, 'EVIDENCE_FAILED',
                {'cmd': type, 'error': 'capture indisponible'});
            onInfo?.call('⚠️ Photo impossible sur ce téléphone');
          } else {
            onInfo?.call(e.postedToChat
                ? '📸 Photo envoyée dans le groupe SOS'
                : '📸 Photo capturée');
          }
          break;

        case cmdVideo:
          _busy = true;
          onInfo?.call('🎥 Vidéo 30s demandée…');
          final e = await SosCrisisMediaService.instance.withCameraReleased(
            () => _evidence.recordVideo(id, conversationId: _conversationId),
          );
          if (e == null) {
            await _sos.logEventPublic(id, 'EVIDENCE_FAILED',
                {'cmd': type, 'error': 'capture indisponible'});
            onInfo?.call('⚠️ Vidéo impossible sur ce téléphone');
          } else {
            onInfo?.call(e.postedToChat
                ? '🎥 Vidéo envoyée dans le groupe SOS'
                : '🎥 Vidéo capturée');
          }
          break;

        case cmdAudioStart:
          if (_evidence.isRecordingAudio) return;
          await _evidence.startAudio();
          onInfo?.call('🎤 Enregistrement audio démarré');
          break;

        case cmdAudioStop:
          if (!_evidence.isRecordingAudio) return;
          final e =
              await _evidence.stopAudio(id, conversationId: _conversationId);
          if (e == null) {
            await _sos.logEventPublic(
                id, 'EVIDENCE_FAILED', {'cmd': type, 'error': 'aucun audio'});
          } else {
            onInfo?.call(e.postedToChat
                ? '🎤 Audio envoyé dans le groupe SOS'
                : '🎤 Audio enregistré');
          }
          break;

        case cmdInstruct:
          final text = (meta['text'] ?? '').toString();
          if (text.isNotEmpty) onInfo?.call('📢 SECOURS : $text');
          break;

        case cmdSurveillanceOn:
          _startSurveillance(id);
          onInfo?.call('🛰️ Mode surveillance activé (photo / 10 s)');
          break;

        case cmdSurveillanceOff:
          _stopSurveillance();
          onInfo?.call('⏹ Surveillance arrêtée');
          break;

        default:
          return;
      }
    } catch (e) {
      debugPrint('SosRemoteCapture $type: $e');
      try {
        await _sos.logEventPublic(
            id!, 'EVIDENCE_FAILED', {'cmd': type, 'error': '$e'});
      } catch (_) {}
      onError?.call(e);
    } finally {
      _busy = false;
    }
  }

  /// ✅ 100% SUPABASE : photo silencieuse toutes les 10 s
  /// → Storage → Realtime → groupe SOS → salle de pilotage.
  void _startSurveillance(String incidentId) {
    _survTimer?.cancel();
    _survTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
      if (_busy) return;
      _busy = true;
      try {
        await SosCrisisMediaService.instance.withCameraReleased(
          () => _evidence.takePhoto(incidentId,
              conversationId: _conversationId),
        );
      } catch (e) {
        debugPrint('surveillance: $e');
      } finally {
        _busy = false;
      }
    });
  }

  void _stopSurveillance() {
    _survTimer?.cancel();
    _survTimer = null;
  }

  void stop() {
    _stopSurveillance();
    final ch = _ch;
    _ch = null;
    if (ch != null) {
      unawaited(Supabase.instance.client.removeChannel(ch));
    }
  }
}
