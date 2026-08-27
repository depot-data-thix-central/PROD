/// Pilotage distant : le SECOURS commande, le téléphone VICTIME capte.
/// Canal = thix_sos_events (Realtime). Fichiers → groupe SOS. Pas Agora.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'sos_evidence_service.dart';
import 'sos_service.dart';

class SosRemoteCaptureService {
  SosRemoteCaptureService({
    SosService? sos,
    SosEvidenceService? evidence,
  })  : _sos = sos ?? SosService(),
        _evidence = evidence ?? SosEvidenceService();

  final SosService _sos;
  final SosEvidenceService _evidence;
  RealtimeChannel? _ch;
  String? _incidentId;
  String? _conversationId;
  bool _busy = false;

  static const cmdPhoto = 'CMD_CAPTURE_PHOTO';
  static const cmdVideo = 'CMD_CAPTURE_VIDEO';
  static const cmdAudioStart = 'CMD_CAPTURE_AUDIO_START';
  static const cmdAudioStop = 'CMD_CAPTURE_AUDIO_STOP';

  bool get isBusy => _busy;
  bool get isRecordingAudio => _evidence.isRecordingAudio;

  /// Côté SECOURS : publie une commande. N'ouvre PAS la caméra locale.
  Future<void> requestPhoto(String incidentId) =>
      _sos.logEventPublic(incidentId, cmdPhoto, {'by': 'secours'});

  Future<void> requestVideo(String incidentId) =>
      _sos.logEventPublic(incidentId, cmdVideo, {'by': 'secours'});

  Future<void> requestAudioStart(String incidentId) =>
      _sos.logEventPublic(incidentId, cmdAudioStart, {'by': 'secours'});

  Future<void> requestAudioStop(String incidentId) =>
      _sos.logEventPublic(incidentId, cmdAudioStop, {'by': 'secours'});

  /// Côté VICTIME : écoute et exécute sur CE téléphone.
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
            unawaited(_handle(type, onInfo: onInfo, onError: onError));
          },
        )
        .subscribe();
  }

  Future<void> _handle(
    String type, {
    void Function(String msg)? onInfo,
    void Function(Object err)? onError,
  }) async {
    final id = _incidentId;
    if (id == null) return;
    if (_busy && type != cmdAudioStop) return;

    try {
      switch (type) {
        case cmdPhoto:
          _busy = true;
          onInfo?.call('Photo demandée par le secours…');
          final e = await _evidence.takePhoto(
            id,
            conversationId: _conversationId,
          );
          onInfo?.call(e?.postedToChat == true
              ? 'Photo envoyée dans le groupe SOS'
              : 'Photo prise');
          break;
        case cmdVideo:
          _busy = true;
          onInfo?.call('Vidéo demandée par le secours…');
          final e = await _evidence.recordVideo(
            id,
            conversationId: _conversationId,
          );
          onInfo?.call(e?.postedToChat == true
              ? 'Vidéo envoyée dans le groupe SOS'
              : 'Vidéo prise');
          break;
        case cmdAudioStart:
          if (_evidence.isRecordingAudio) return;
          await _evidence.startAudio();
          onInfo?.call('Enregistrement audio victime démarré');
          break;
        case cmdAudioStop:
          if (!_evidence.isRecordingAudio) return;
          final e = await _evidence.stopAudio(
            id,
            conversationId: _conversationId,
          );
          onInfo?.call(e?.postedToChat == true
              ? 'Audio envoyé dans le groupe SOS'
              : 'Audio enregistré');
          break;
        default:
          return;
      }
    } catch (e) {
      debugPrint('SosRemoteCapture $type: $e');
      onError?.call(e);
    } finally {
      _busy = false;
    }
  }

  void stop() {
    final ch = _ch;
    _ch = null;
    if (ch != null) {
      unawaited(Supabase.instance.client.removeChannel(ch));
    }
  }
}
