// lib/presentation/thix_sos/pages/chambre_crise_secours_page.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/models/chat/call_status.dart';
import 'package:thix_id/services/chat/call_signaling_service.dart';

import '../models/sos_models.dart';
import '../providers/sos_providers.dart';
import '../services/sos_crisis_media_service.dart';
import '../services/sos_remote_capture_service.dart';

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
  final _remote = SosRemoteCaptureService.instance;

  StreamSubscription<Set<int>>? _uidsSub;
  RealtimeChannel? _eventsCh;
  Set<int> _remotes = {};
  final List<_FeedItem> _items = [];

  bool _joining = true;
  String? _error;
  bool _muted = false;
  bool _busy = false;
  String? _conversationId;
  bool _audioArmed = false;

  @override
  void initState() {
    super.initState();
    _uidsSub = _media.remoteUidsStream.listen((s) {
      if (mounted) setState(() => _remotes = s);
    });
    _subscribeEvidence();
    _connect();
  }

  @override
  void dispose() {
    _uidsSub?.cancel();
    _eventsCh?.unsubscribe();
    _media.leave();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────
  // Flux temps réel des preuves (URLs storage, pas fichiers locaux)
  // ─────────────────────────────────────────────────────────────
  void _subscribeEvidence() {
    _eventsCh = Supabase.instance.client
        .channel('sos-evidence-${widget.incidentId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'thix_sos_events',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'incident_id',
            value: widget.incidentId,
          ),
          callback: (payload) {
            final rec = payload.newRecord;
            final type = (rec['type'] ?? '').toString();
            if (!type.startsWith('EVIDENCE_')) return;
            final meta = Map<String, dynamic>.from((rec['payload'] as Map?) ?? {});
            final url = meta['url']?.toString();
            final createdAt = rec['created_at'] != null
                ? DateTime.tryParse(rec['created_at'].toString()) ?? DateTime.now()
                : DateTime.now();
            if (!mounted) return;
            setState(() {
              _items.insert(
                0,
                _FeedItem(type: type, url: url, at: createdAt),
              );
            });
            _toast('📥 Preuve reçue : ${type.replaceFirst('EVIDENCE_', '').toLowerCase()}');
          },
        )
        .subscribe();
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

  Future<void> _photo() async {
    setState(() => _busy = true);
    try {
      await _remote.requestPhoto(widget.incidentId);
      _toast('Commande photo envoyée au téléphone victime');
    } catch (err) {
      _toast('$err');
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _video() async {
    setState(() => _busy = true);
    try {
      await _remote.requestVideo(widget.incidentId);
      _toast('Commande vidéo envoyée au téléphone victime');
    } catch (err) {
      _toast('$err');
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _toggleAudioRec() async {
    setState(() => _busy = true);
    try {
      if (_audioArmed) {
        await _remote.requestAudioStop(widget.incidentId);
        _audioArmed = false;
        _toast('Stop audio envoyé au téléphone victime');
      } else {
        await _remote.requestAudioStart(widget.incidentId);
        _audioArmed = true;
        _toast('Start audio envoyé au téléphone victime');
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
          // ─── Live caméra victime (Agora — indépendant des preuves) ───
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

          // ─── Commandes capture à distance (pilote le tél. VICTIME) ───
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
                  icon: _audioArmed ? Icons.stop_circle : Icons.mic_none,
                  label: _audioArmed ? 'Stop audio' : 'Enreg. audio',
                  danger: _audioArmed,
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

          // ─── Feed preuves reçues en temps réel (URLs storage) ───
          SizedBox(
            height: 96,
            child: _items.isEmpty
                ? const Center(
                    child: Text(
                      'Aucune preuve reçue pour l\'instant',
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
                      return GestureDetector(
                        onTap: () async {
                          if (e.url == null) return;
                          await launchUrl(
                            Uri.parse(e.url!),
                            mode: LaunchMode.externalApplication,
                          );
                        },
                        child: Container(
                          width: 96,
                          decoration: BoxDecoration(
                            color: const Color(0xFF121826),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.08),
                            ),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: e.type == 'EVIDENCE_PHOTO' && e.url != null
                              ? Image.network(
                                  e.url!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      const Center(
                                        child: Icon(Icons.broken_image,
                                            color: Colors.white38, size: 28),
                                      ),
                                )
                              : Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        e.type == 'EVIDENCE_VIDEO'
                                            ? Icons.videocam_rounded
                                            : Icons.mic_rounded,
                                        color: e.type == 'EVIDENCE_VIDEO'
                                            ? Colors.blueAccent
                                            : Colors.orangeAccent,
                                        size: 28,
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        e.type.replaceFirst('EVIDENCE_', ''),
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
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

// ─────────────────────────────────────────────────────────────
class _FeedItem {
  final String type; // EVIDENCE_PHOTO | EVIDENCE_VIDEO | EVIDENCE_AUDIO
  final String? url;
  final DateTime at;
  const _FeedItem({required this.type, this.url, required this.at});
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
