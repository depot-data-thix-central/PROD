// lib/presentation/thix_sos/pages/chambre_crise_secours_page.dart
import 'dart:async';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/models/chat/call_status.dart';
import 'package:thix_id/presentation/chat/widgets/image_viewer.dart';
import 'package:thix_id/services/chat/call_signaling_service.dart';

import '../models/sos_models.dart';
import '../providers/sos_providers.dart';
import '../services/sos_crisis_media_service.dart';
import '../services/sos_remote_capture_service.dart';

/// SALLE DE PILOTAGE SECOURS — niveau entreprise.
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
  Timer? _clock;

  Set<int> _remotes = {};
  final List<_EvidenceItem> _evidence = [];
  final List<_JournalRow> _journal = [];

  bool _joining = true;
  String? _error;
  bool _muted = false;
  bool _busy = false;
  bool _audioArmed = false;
  bool _surveillance = false;
  String? _conversationId;
  Duration _elapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    _uidsSub = _media.remoteUidsStream.listen((s) {
      if (mounted) setState(() => _remotes = s);
    });
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final inc =
          ref.read(sosIncidentProvider(widget.incidentId)).valueOrNull;
      if (inc != null) {
        var d = DateTime.now().difference(inc.startedAt.toLocal());
        if (d.isNegative) d = Duration.zero;
        setState(() => _elapsed = d);
      }
    });
    _subscribeEvents();
    _connect();
  }

  @override
  void dispose() {
    _clock?.cancel();
    _uidsSub?.cancel();
    _eventsCh?.unsubscribe();
    _media.leave();
    super.dispose();
  }

  void _subscribeEvents() {
    _eventsCh = Supabase.instance.client
        .channel('sos-room-${widget.incidentId}')
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
            if (!mounted) return;
            final rec = payload.newRecord;
            final type = (rec['type'] ?? '').toString();
            final meta =
                Map<String, dynamic>.from((rec['payload'] as Map?) ?? {});
            setState(() {
              _journal.insert(0, _JournalRow(type: type, at: DateTime.now()));
              if (type.startsWith('EVIDENCE_')) {
                _evidence.insert(
                  0,
                  _EvidenceItem(
                    type: type,
                    url: meta['url']?.toString(),
                    posted: meta['posted_to_chat'] == true,
                    error: meta['error']?.toString(),
                    at: DateTime.now(),
                  ),
                );
              }
            });
            if (type == 'EVIDENCE_PHOTO') _toast('📥 Photo victime reçue');
            if (type == 'EVIDENCE_VIDEO') _toast('📥 Vidéo victime reçue');
            if (type == 'EVIDENCE_AUDIO') _toast('📥 Audio victime reçu');
            if (type == 'EVIDENCE_FAILED')
              _toast('⚠️ Échec capture côté victime');
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
      try {
        await _media.joinAsResponder(widget.incidentId);
      } catch (e) {
        debugPrint('Live Agora optionnel indisponible: $e');
      }
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
      _toast('📸 Commande photo → téléphone victime');
    } catch (e) {
      _toast('$e');
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _video() async {
    setState(() => _busy = true);
    try {
      await _remote.requestVideo(widget.incidentId);
      _toast('🎥 Commande vidéo 30s → téléphone victime');
    } catch (e) {
      _toast('$e');
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _toggleAudio() async {
    setState(() => _busy = true);
    try {
      if (_audioArmed) {
        await _remote.requestAudioStop(widget.incidentId);
        _audioArmed = false;
        _toast('⏹ Stop audio → téléphone victime');
      } else {
        await _remote.requestAudioStart(widget.incidentId);
        _audioArmed = true;
        _toast('🎤 Enregistrement audio victime en cours…');
      }
    } catch (e) {
      _toast('$e');
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _toggleSurveillance() async {
    try {
      if (_surveillance) {
        await _remote.requestSurveillanceOff(widget.incidentId);
        _surveillance = false;
        _toast('⏹ Surveillance arrêtée');
      } else {
        await _remote.requestSurveillanceOn(widget.incidentId);
        _surveillance = true;
        _toast('🛰️ Surveillance activée : photo toutes les 10 s');
      }
    } catch (e) {
      _toast('$e');
    }
    if (mounted) setState(() {});
  }

  Future<void> _callVictim() async {
    final victimId = widget.victimUserId;
    if (victimId == null || victimId.isEmpty) {
      _toast('Victime inconnue — appel impossible');
      return;
    }
    try {
      await CallSignalingService()
          .startCall(calleeId: victimId, type: CallType.audio);
      _toast(' Appel audio lancé');
    } catch (e) {
      _toast('Appel: $e');
    }
  }

  void _openInstructions() {
    final ctrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF121826),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('📢 Instruction à la victime',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 15)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                        'Restez calme, les secours arrivent',
                        'Parlez-moi, décrivez votre situation',
                        'Montrez la pièce avec la caméra',
                        'Ne raccrochez pas'
                      ]
                  .map((t) => ActionChip(
                        label: Text(t,
                            style: const TextStyle(
                                fontSize: 12, color: Colors.white70)),
                        backgroundColor: const Color(0xFF1E293B),
                        onPressed: () async {
                          Navigator.pop(ctx);
                          await _remote
                              .requestInstruct(widget.incidentId, t);
                          _toast('📢 Instruction envoyée');
                        },
                      ))
                  .toList(),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Message personnalisé…',
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: const Color(0xFF1E293B),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: ThixPolicy.danger),
              onPressed: () async {
                final t = ctrl.text.trim();
                if (t.isEmpty) return;
                Navigator.pop(ctx);
                await _remote.requestInstruct(widget.incidentId, t);
                _toast('📢 Instruction envoyée');
              },
              child: const Text('ENVOYER'),
            ),
          ],
        ),
      ),
    );
  }

  void _toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(m),
      backgroundColor: ThixPolicy.inkDeep,
      duration: const Duration(seconds: 2),
    ));
  }

  String _fmtDuration(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  String? get _latestPhotoUrl {
    for (final e in _evidence) {
      if (e.type == 'EVIDENCE_PHOTO' && e.url != null) return e.url;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final incident =
        ref.watch(sosIncidentProvider(widget.incidentId)).valueOrNull;
    final engine = _media.engine;
    final channel = _media.channel;
    final remoteUid = _remotes.isEmpty ? null : _remotes.first;
    final hasLive = !_joining &&
        _error == null &&
        engine != null &&
        channel != null &&
        remoteUid != null;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFF070B14),
        appBar: AppBar(
          backgroundColor: const Color(0xFF3B0D0D),
          title: Column(
            children: [
              Text(
                incident?.publicId ?? 'CHAMBRE SECOURS',
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w800),
              ),
              Text(
                '⏱ ${_fmtDuration(_elapsed)}  •  CERCLE ${incident?.activeCircle ?? 1}',
                style: const TextStyle(fontSize: 10, color: Colors.white70),
              ),
            ],
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
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.32,
              child: Container(
                margin: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(16),
                  border:
                      Border.all(color: Colors.red.withValues(alpha: 0.4)),
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (hasLive)
                      AgoraVideoView(
                        controller: VideoViewController.remote(
                          rtcEngine: engine!,
                          canvas: VideoCanvas(uid: remoteUid!),
                          connection: RtcConnection(channelId: channel!),
                        ),
                      )
                    else if (_latestPhotoUrl != null)
                      Image.network(
                        _latestPhotoUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Center(
                            child: Icon(Icons.broken_image,
                                color: Colors.white24, size: 40)),
                      )
                    else
                      Center(
                        child: _joining
                            ? const CircularProgressIndicator(
                                color: Colors.red)
                            : const Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.satellite_alt,
                                      color: Colors.white24, size: 44),
                                  SizedBox(height: 8),
                                  Text(
                                    'Activez « Surveillance 10s »\nou attendez la caméra victime…',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: Colors.white54),
                                  ),
                                ],
                              ),
                      ),
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: hasLive
                              ? Colors.red
                              : _latestPhotoUrl != null
                                  ? Colors.orange
                                  : Colors.grey.shade700,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          hasLive
                              ? '● LIVE'
                              : _latestPhotoUrl != null
                                  ? '● DERNIÈRE IMAGE'
                                  : '○ EN ATTENTE',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                    if (_surveillance)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.green.shade700,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text('🛰 10s',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800)),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            if (incident != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    _StatusChip(
                      icon: Icons.location_on,
                      label: incident.hasLocation
                          ? '${incident.lastLat!.toStringAsFixed(4)}, ${incident.lastLng!.toStringAsFixed(4)}'
                          : 'Position ?',
                      color: Colors.green,
                      onTap: () async {
                        if (incident.hasLocation) {
                          await launchUrl(Uri.parse(
                              'https://www.google.com/maps?q=${incident.lastLat},${incident.lastLng}'));
                        }
                      },
                    ),
                    const SizedBox(width: 8),
                    const _StatusChip(
                        icon: Icons.favorite,
                        label: 'Heartbeat',
                        color: Colors.green),
                    const SizedBox(width: 8),
                    _StatusChip(
                      icon: Icons.battery_std,
                      label: incident.batteryPct != null
                          ? '${incident.batteryPct}%'
                          : 'Batt ?',
                      color: (incident.batteryPct ?? 100) < 20
                          ? Colors.red
                          : Colors.green,
                    ),
                  ],
                ),
              ),

            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _ControlChip(
                      icon: Icons.photo_camera,
                      label: 'Photo',
                      onTap: _busy ? null : _photo),
                  _ControlChip(
                      icon: Icons.videocam,
                      label: 'Vidéo 30s',
                      onTap: _busy ? null : _video),
                  _ControlChip(
                    icon: _audioArmed ? Icons.stop_circle : Icons.mic_none,
                    label: _audioArmed ? 'STOP AUDIO' : 'Enreg. audio',
                    danger: _audioArmed,
                    onTap: _busy ? null : _toggleAudio,
                  ),
                  _ControlChip(
                    icon: _surveillance
                        ? Icons.visibility_off
                        : Icons.visibility,
                    label: _surveillance
                        ? 'Stop surveillance'
                        : 'Surveillance 10s',
                    danger: _surveillance,
                    onTap: _toggleSurveillance,
                  ),
                  _ControlChip(
                      icon: Icons.campaign,
                      label: 'Instruction',
                      onTap: _openInstructions),
                  _ControlChip(
                      icon: Icons.call,
                      label: 'Appel audio',
                      onTap: _callVictim),
                ],
              ),
            ),

            const TabBar(
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white38,
              indicatorColor: Colors.red,
              tabs: [Tab(text: 'PREUVES'), Tab(text: 'JOURNAL')],
            ),
            Expanded(
              child: TabBarView(
                children: [_buildEvidenceTab(), _buildJournalTab()],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEvidenceTab() {
    if (_evidence.isEmpty) {
      return const Center(
        child: Text('Aucune preuve reçue pour l\'instant',
            style: TextStyle(color: Colors.white38, fontSize: 12)),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 0.85,
      ),
      itemCount: _evidence.length,
      itemBuilder: (_, i) {
        final e = _evidence[i];
        return GestureDetector(
          onTap: () async {
            if (e.url == null) return;
            if (e.type == 'EVIDENCE_PHOTO') {
              showFullscreenImageViewer(context, url: e.url!);
            } else {
              await launchUrl(Uri.parse(e.url!),
                  mode: LaunchMode.externalApplication);
            }
          },
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF121826),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: e.type == 'EVIDENCE_FAILED'
                    ? Colors.red.withValues(alpha: 0.5)
                    : Colors.white.withValues(alpha: 0.08),
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (e.type == 'EVIDENCE_PHOTO' && e.url != null)
                  Image.network(e.url!, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(
                          Icons.broken_image, color: Colors.white38))
                else
                  Center(
                    child: Icon(
                      e.type == 'EVIDENCE_VIDEO'
                          ? Icons.videocam_rounded
                          : e.type == 'EVIDENCE_AUDIO'
                              ? Icons.mic_rounded
                              : Icons.warning_amber_rounded,
                      color: e.type == 'EVIDENCE_FAILED'
                          ? Colors.redAccent
                          : Colors.white70,
                      size: 26,
                    ),
                  ),
                Positioned(
                  bottom: 4,
                  left: 4,
                  right: 4,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        e.type.replaceFirst('EVIDENCE_', ''),
                        style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 9,
                            fontWeight: FontWeight.w700),
                      ),
                      if (e.posted)
                        const Icon(Icons.check_circle,
                            color: Colors.green, size: 11),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildJournalTab() {
    if (_journal.isEmpty) {
      return const Center(
        child: Text('Journal vide',
            style: TextStyle(color: Colors.white38)),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: _journal.length,
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (_, i) {
        final j = _journal[i];
        return Row(
          children: [
            Text(
              '${j.at.hour.toString().padLeft(2, '0')}:${j.at.minute.toString().padLeft(2, '0')}:${j.at.second.toString().padLeft(2, '0')}',
              style: const TextStyle(color: Colors.white38, fontSize: 11),
            ),
            const SizedBox(width: 8),
            Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                    color: Colors.redAccent, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                j.type,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────
// CLASSES HELPER (niveau supérieur du fichier — en dehors de State)
// ─────────────────────────────────────────────────────────────

class _EvidenceItem {
  final String type;
  final String? url;
  final bool posted;
  final String? error;
  final DateTime at;
  const _EvidenceItem({
    required this.type,
    this.url,
    this.posted = false,
    this.error,
    required this.at,
  });
}

class _JournalRow {
  final String type;
  final DateTime at;
  const _JournalRow({required this.type, required this.at});
}

class _StatusChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;
  const _StatusChip({
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF121826),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 10,
                      fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ControlChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool danger;
  final VoidCallback? onTap;
  const _ControlChip({
    required this.icon,
    required this.label,
    this.onTap,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: danger ? const Color(0xFF7F1D1D) : const Color(0xFF1E293B),
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  size: 18,
                  color: danger ? Colors.redAccent : Colors.white),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
