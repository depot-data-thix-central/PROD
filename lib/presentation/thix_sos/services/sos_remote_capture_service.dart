import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'sos_crisis_media_service.dart';
import 'sos_evidence_service.dart';
import 'sos_service.dart';

/// Pilotage distant production.
/// Commandes Realtime Supabase. Agora JAMAIS requis pour photo/vidéo/audio.
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
  static const cmdClip10 = 'CMD_CAPTURE_CLIP_10';
  static const cmdAudioStart = 'CMD_CAPTURE_AUDIO_START';
  static const cmdAudioStop = 'CMD_CAPTURE_AUDIO_STOP';
  static const cmdInstruct = 'CMD_INSTRUCT';
  static const cmdSurveillanceOn = 'CMD_SURVEILLANCE_ON';
  static const cmdSurveillanceOff = 'CMD_SURVEILLANCE_OFF';

  bool get isBusy => _busy;
  bool get isRecordingAudio => _evidence.isRecordingAudio;
  bool get isSurveillanceOn => _survTimer != null;

  Future<void> requestPhoto(String incidentId) =>
      _sos.logEventPublic(incidentId, cmdPhoto, {'by': 'secours'});

  Future<void> requestVideo(String incidentId, {int seconds = 10}) =>
      _sos.logEventPublic(incidentId, cmdVideo, {
        'by': 'secours',
        'seconds': seconds,
      });

  Future<void> requestClip10(String incidentId) =>
      _sos.logEventPublic(incidentId, cmdClip10, {'by': 'secours', 'seconds': 10});

  Future<void> requestAudioStart(String incidentId) =>
      _sos.logEventPublic(incidentId, cmdAudioStart, {'by': 'secours'});

  Future<void> requestAudioStop(String incidentId) =>
      _sos.logEventPublic(incidentId, cmdAudioStop, {'by': 'secours'});

  Future<void> requestInstruct(String incidentId, String text) async {
    await _sos.logEventPublic(
      incidentId,
      cmdInstruct,
      {'by': 'secours', 'text': text},
    );
    await _evidence.postInstructionToGroup(
      incidentId: incidentId,
      text: text,
      conversationId: _conversationId,
    );
  }

  Future<void> requestSurveillanceOn(String incidentId) =>
      _sos.logEventPublic(incidentId, cmdSurveillanceOn, {'by': 'secours'});

  Future<void> requestSurveillanceOff(String incidentId) =>
      _sos.logEventPublic(incidentId, cmdSurveillanceOff, {'by': 'secours'});

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
            final type = (rec['type'] ?? rec['event_type'] ?? '').toString();
            final meta =
                Map<String, dynamic>.from((rec['payload'] as Map?) ?? {});
            unawaited(_handle(type, meta, onInfo: onInfo, onError: onError));
          },
        )
        .subscribe();
  }

  Future<SosEvidence?> runVictimClip10({
    required String incidentId,
    String? conversationId,
  }) async {
    _conversationId = conversationId ?? _conversationId;
    return SosCrisisMediaService.instance.withCameraReleased(
      () => _evidence.recordVideo(
        incidentId,
        conversationId: _conversationId,
        duration: const Duration(seconds: 10),
        source: 'victim',
      ),
    );
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

    final seconds = (meta['seconds'] is int)
        ? meta['seconds'] as int
        : int.tryParse('${meta['seconds'] ?? ''}') ?? 10;

    try {
      switch (type) {
        case cmdPhoto:
          _busy = true;
          onInfo?.call('📸 Photo demandée par le secours…');
          final e = await SosCrisisMediaService.instance.withCameraReleased(
            () => _evidence.takePhoto(
              id,
              conversationId: _conversationId,
              source: 'rescue',
            ),
          );
          await _reportCapture(id, type, e, onInfo, label: 'Photo');
          break;

        case cmdVideo:
        case cmdClip10:
          _busy = true;
          onInfo?.call('🎥 Clip ${seconds}s demandé…');
          final e = await SosCrisisMediaService.instance.withCameraReleased(
            () => _evidence.recordVideo(
              id,
              conversationId: _conversationId,
              duration: Duration(seconds: seconds),
              source: type == cmdClip10 ? 'victim' : 'rescue',
            ),
          );
          await _reportCapture(id, type, e, onInfo, label: 'Vidéo ${seconds}s');
          break;

        case cmdAudioStart:
          if (_evidence.isRecordingAudio) return;
          await _evidence.startAudio();
          onInfo?.call('🎤 Enregistrement audio démarré');
          break;

        case cmdAudioStop:
          if (!_evidence.isRecordingAudio) return;
          final e = await _evidence.stopAudio(
            id,
            conversationId: _conversationId,
            source: 'rescue',
          );
          await _reportCapture(id, type, e, onInfo, label: 'Audio');
          break;

        case cmdInstruct:
          final text = (meta['text'] ?? '').toString();
          if (text.isNotEmpty) onInfo?.call('📢 SECOURS : $text');
          break;

        case cmdSurveillanceOn:
          _startSurveillance(id);
          onInfo?.call('🛰️ Surveillance 10s activée');
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
            id, 'EVIDENCE_FAILED', {'cmd': type, 'error': '$e'});
      } catch (_) {}
      onError?.call(e);
    } finally {
      _busy = false;
    }
  }

  Future<void> _reportCapture(
    String id,
    String cmd,
    SosEvidence? e,
    void Function(String msg)? onInfo, {
    required String label,
  }) async {
    if (e == null) {
      await _sos.logEventPublic(
          id, 'EVIDENCE_FAILED', {'cmd': cmd, 'error': 'capture indisponible'});
      onInfo?.call('⚠️ $label impossible sur ce téléphone');
      return;
    }
    onInfo?.call(e.postedToChat
        ? '✅ $label envoyé dans le groupe SOS'
        : '✅ $label capturé (envoi groupe en attente)');
  }

  void _startSurveillance(String incidentId) {
    _survTimer?.cancel();
    Future(() async {
      if (_busy) return;
      _busy = true;
      try {
        await SosCrisisMediaService.instance.withCameraReleased(
          () => _evidence.takePhoto(
            incidentId,
            conversationId: _conversationId,
            source: 'rescue',
          ),
        );
      } catch (e) {
        debugPrint('surveillance first: $e');
      } finally {
        _busy = false;
      }
    });
    _survTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
      if (_busy) return;
      _busy = true;
      try {
        await SosCrisisMediaService.instance.withCameraReleased(
          () => _evidence.takePhoto(
            incidentId,
            conversationId: _conversationId,
            source: 'rescue',
          ),
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
