/// Chambre de crise — côté SECOURS
/// Appel = audio uniquement. Ici : live caméra victime + preuves.
import 'dart:async';
import 'dart:io';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/models/chat/call_status.dart';
import 'package:thix_id/services/chat/call_signaling_service.dart';

import '../models/sos_models.dart';
import '../providers/sos_providers.dart';
import '../services/sos_crisis_media_service.dart';
import '../services/sos_evidence_service.dart';
import '../services/sos_service.dart';

class ChambreCriseSecoursPage extends ConsumerStatefulWidget {
  const ChambreCriseSecoursPage({
    super.key,
    required this.incidentId,
    this.victimUserId,
  });

  final String incidentId;
  final String? victimUserId;

  @override
  ConsumerState<ChambreCriseSecoursPage> createState() =>
      _ChambreCriseSecoursPageState();
}

class _ChambreCriseSecoursPageState
    extends ConsumerState<ChambreCriseSecoursPage> {
  final _media = SosCrisisMediaService.instance;
  final _evidence = SosEvidenceService();
  StreamSubscription<Set<int>>? _uidsSub;
  Set<int> _remotes = {};
  final List<SosEvidence> _items = [];
  bool _joining = true;
  String? _error;
  bool _muted = false;
  bool _busy = false;
  String? _conversationId;

  @override
  void initState() {
    super.initState();
    _uidsSub = _media.remoteUidsStream.listen((s) {
      if (mounted) setState(() => _remotes = s);
    });
    _connect();
  }

  Future<void> _connect() async {
    setState(() {
      _joining = true;
      _error = null;
    });
    try {
      await _media.joinAsResponder(widget.incidentId);
      final incident = await ref
          .read(sosServiceProvider)
          .getIncidentForRescue(widget.incidentId);
      _conversationId = incident?.chatConversationId;
      await ref.read(sosServiceProvider).logEventPublic(
        widget.incidentId,
        'RESCUE_JOINED_CRISIS_ROOM',
        {'role': 'secours', 'conversation_id': _conversationId},
      );
    } catch (e) {
      _error = '$e';
    }
    if (mounted) setState(() => _joining = false);
  }

  @override
  void dispose() {
    _uidsSub?.cancel();
    _media.leave();
    super.dispose();
  }

  Future<void> _photo() async {
    setState(() => _busy = true);
    try {
      final e = await _evidence.takePhoto(widget.incidentId, conversationId: _conversationId);
      if (e != null && mounted) {
        setState(() => _items.insert(0, e));
        _toast(e.postedToChat
            ? 'Photo envoyée dans le groupe SOS'
            : 'Photo prise (groupe indisponible)');
      }
    } catch (err) {
      _toast('$err');
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _video() async {
    setState(() => _busy = true);
    try {
      final e = await _evidence.recordVideo(widget.incidentId, conversationId: _conversationId);
      if (e != null && mounted) {
        setState(() => _items.insert(0, e));
        _toast(e.postedToChat
            ? 'Vidéo envoyée dans le groupe SOS'
            : 'Vidéo prise (groupe indisponible)');
      }
    } catch (err) {
      _toast('$err');
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _toggleAudioRec() async {
    setState(() => _busy = true);
    try {
      if (_evidence.isRecordingAudio) {
        final e = await _evidence.stopAudio(widget.incidentId, conversationId: _conversationId);
        if (e != null && mounted) setState(() => _items.insert(0, e));
        _toast(e?.postedToChat == true ? 'Audio envoyé dans le groupe SOS' : 'Audio enregistré');

      } else {
        await _evidence.startAudio();
        _toast('Enregistrement audio démarré');
      }
    } catch (err) {
      _toast('$err');
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _callVictimAudio() async {
    final victimId = widget.victimUserId;
    if (victimId == null || victimId.isEmpty) {
      _toast('Victime inconnue — appel audio impossible');
      return;
    }
    try {
      await CallSignalingService().startCall(
        calleeId: victimId,
        type: CallType.audio,
      );
      _toast('Appel audio lancé');
    } catch (e) {
      _toast('Appel audio: $e');
    }
  }

  void _toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(m),
        backgroundColor: ThixPolicy.inkDeep,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final incidentAsync = ref.watch(sosIncidentProvider(widget.incidentId));
    final incident = incidentAsync.valueOrNull;
    final engine = _media.engine;
    final channel = _media.channel;
    final remoteUid = _remotes.isEmpty ? null : _remotes.first;

    return Scaffold(
      backgroundColor: const Color(0xFF070B14),
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(
          incident?.publicId ?? 'CHAMBRE SECOURS',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            tooltip: _muted ? 'Micro on' : 'Muet',
            onPressed: () async {
              await _media.setMuted(!_muted);
              setState(() => _muted = !_muted);
            },
            icon: Icon(_muted ? Icons.mic_off : Icons.mic),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            flex: 5,
            child: Container(
              margin: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.red.withValues(alpha: 0.4)),
              ),
              clipBehavior: Clip.antiAlias,
              child: _joining
                  ? const Center(child: CircularProgressIndicator(color: Colors.red))
                  : _error != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              'Caméra indisponible\n$_error',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.white70),
                            ),
                          ),
                        )
                      : engine != null &&
                              channel != null &&
                              remoteUid != null
                          ? AgoraVideoView(
                              controller: VideoViewController.remote(
                                rtcEngine: engine,
                                canvas: VideoCanvas(uid: remoteUid),
                                connection: RtcConnection(channelId: channel),
                              ),
                            )
                          : const Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.videocam, color: Colors.white24, size: 48),
                                  SizedBox(height: 8),
                                  Text(
                                    'En attente de la caméra victime…',
                                    style: TextStyle(color: Colors.white54),
                                  ),
                                ],
                              ),
                            ),
            ),
          ),
          if (incident != null) _VictimMeta(incident: incident),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _ActionChip(
                  icon: Icons.photo_camera,
                  label: 'Photo',
                  onTap: _busy ? null : _photo,
                ),
                _ActionChip(
                  icon: Icons.videocam,
                  label: 'Vidéo 30s',
                  onTap: _busy ? null : _video,
                ),
                _ActionChip(
                  icon: _evidence.isRecordingAudio
                      ? Icons.stop_circle
                      : Icons.mic_none,
                  label: _evidence.isRecordingAudio
                      ? 'Stop audio'
                      : 'Enreg. audio',
                  danger: _evidence.isRecordingAudio,
                  onTap: _busy ? null : _toggleAudioRec,
                ),
                _ActionChip(
                  icon: Icons.call,
                  label: 'Appel audio',
                  onTap: _callVictimAudio,
                ),
              ],
            ),
          ),
          SizedBox(
            height: 88,
            child: _items.isEmpty
                ? const Center(
                    child: Text(
                      'Aucune preuve pour l’instant',
                      style: TextStyle(color: Colors.white38, fontSize: 12),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    scrollDirection: Axis.horizontal,
                    itemCount: _items.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (_, i) {
                      final e = _items[i];
                      return Container(
                        width: 88,
                        decoration: BoxDecoration(
                          color: const Color(0xFF121826),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: e.type == 'photo'
                            ? Image.file(File(e.localPath), fit: BoxFit.cover)
                            : Center(
                                child: Text(
                                  e.type.toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _VictimMeta extends StatelessWidget {
  const _VictimMeta({required this.incident});
  final SosIncident incident;

  @override
  Widget build(BuildContext context) {
    final loc = incident.hasLocation
        ? '${incident.lastLat!.toStringAsFixed(5)}, ${incident.lastLng!.toStringAsFixed(5)}'
        : 'Position inconnue';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.location_on, color: Colors.redAccent, size: 16),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              loc,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
          if (incident.batteryPct != null)
            Text(
              'Bat ${incident.batteryPct}%',
              style: const TextStyle(color: Colors.white38, fontSize: 11),
            ),
        ],
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({
    required this.icon,
    required this.label,
    this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: danger ? const Color(0xFF7F1D1D) : const Color(0xFF1E293B),
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: Colors.white),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
