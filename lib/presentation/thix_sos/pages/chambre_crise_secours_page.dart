import 'dart:async';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/models/chat/call_status.dart';
import 'package:thix_id/models/chat/chat_conversation.dart';
import 'package:thix_id/nav.dart';
import 'package:thix_id/presentation/chat/widgets/image_viewer.dart';
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

class _JournalRow {
  final String type;
  final DateTime at;
  final Map<String, dynamic> payload;
  _JournalRow({required this.type, required this.at, this.payload = const {}});
}

class _EvidenceItem {
  final String type;
  final String? url;
  final bool posted;
  final String? error;
  final DateTime at;
  _EvidenceItem({
    required this.type,
    this.url,
    this.posted = false,
    this.error,
    required this.at,
  });
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
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await _loadHistory();
    _subscribeEvents();
    await _connect();
  }

  Future<void> _loadHistory() async {
    try {
      final rows = await Supabase.instance.client
          .from('thix_sos_events')
          .select()
          .eq('incident_id', widget.incidentId)
          .order('created_at', ascending: false)
          .limit(200);
      for (final rec in (rows as List).reversed) {
        _ingest(Map<String, dynamic>.from(rec as Map), fromHistory: true);
      }
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('history events: $e');
    }
    try {
      final evs = await Supabase.instance.client
          .from('thix_sos_evidence')
          .select()
          .eq('incident_id', widget.incidentId)
          .order('created_at', ascending: false);
      for (final rec in evs as List) {
        final m = Map<String, dynamic>.from(rec as Map);
        final type = 'EVIDENCE_${(m['type'] ?? '').toString().toUpperCase()}';
        if (_evidence.any((e) => e.url != null && e.url == m['url'])) continue;
        _evidence.add(_EvidenceItem(
          type: type,
          url: m['url']?.toString(),
          posted: m['posted_to_chat'] == true,
          at: DateTime.tryParse('${m['created_at']}') ?? DateTime.now(),
        ));
      }
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('history evidence: $e');
    }
  }

  void _ingest(Map<String, dynamic> rec, {bool fromHistory = false}) {
    final type = (rec['type'] ?? rec['event_type'] ?? '').toString();
    if (type.isEmpty) return;
    final meta = Map<String, dynamic>.from((rec['payload'] as Map?) ?? {});
    final at = DateTime.tryParse('${rec['created_at']}') ?? DateTime.now();
    _journal.insert(0, _JournalRow(type: type, at: at, payload: meta));
    if (type.startsWith('EVIDENCE_')) {
      _evidence.insert(
        0,
        _EvidenceItem(
          type: type,
          url: meta['url']?.toString(),
          posted: meta['posted_to_chat'] == true,
          error: meta['error']?.toString(),
          at: at,
        ),
      );
    }
    if (!fromHistory && mounted) {
      if (type == 'EVIDENCE_PHOTO') _toast('📥 Photo victime reçue');
      if (type == 'EVIDENCE_VIDEO') _toast('📥 Vidéo victime reçue');
      if (type == 'EVIDENCE_AUDIO') _toast('📥 Audio victime reçu');
      if (type == 'EVIDENCE_FAILED') _toast('⚠️ Échec capture victime');
    }
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
            setState(() => _ingest(Map<String, dynamic>.from(payload.newRecord)));
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
        debugPrint('Live Agora optionnel: $e');
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

  Future<void> _video(int seconds) async {
    setState(() => _busy = true);
    try {
      await _remote.requestVideo(widget.incidentId, seconds: seconds);
      _toast('🎥 Commande vidéo ${seconds}s → téléphone victime');
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
        _toast('🎤 Audio victime en cours…');
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
        _toast('🛰️ Surveillance : photo toutes les 10 s + envoi groupe');
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
      _toast('Appel audio lancé');
    } catch (e) {
      _toast('Appel: $e');
    }
  }

  void _openChat(SosIncident? incident) {
    final id = _conversationId ?? incident?.chatConversationId;
    if (id == null || id.isEmpty) {
      _toast('Groupe SOS pas encore créé');
      return;
    }
    final conversation = ChatConversation(
      id: id,
      isGroup: true,
      groupName: 'THIX CHAT ${incident?.publicId ?? ''}',
      participantIds: const [],
      updatedAt: DateTime.now(),
    );
    Navigator.of(context).maybePop();
    try {
      // ignore: use_build_context_synchronously
    } catch (_) {}
    // Navigation projet
    // context.push(AppRoutes.chatDetail(id), extra: conversation);
    _toast('Ouvrir le groupe $id');
  }

  void _openInstructions() {
    final ctrl = TextEditingController();
    const presets = [
      'Restez calme, les secours arrivent',
      'Parlez-moi, décrivez votre situation',
      'Montrez la pièce avec la caméra',
      'Lancez un clip 10 secondes',
      'Ne raccrochez pas',
    ];
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF121826),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: 16 + MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('📢 Instruction réelle → victime + groupe SOS',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 15)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: presets
                  .map((t) => ActionChip(
                        label: Text(t,
                            style: const TextStyle(
                                fontSize: 12, color: Colors.white70)),
                        backgroundColor: const Color(0xFF1E293B),
                        onPressed: () async {
                          Navigator.pop(ctx);
                          await _remote.requestInstruct(widget.incidentId, t);
                          _toast('📢 Instruction dans le groupe SOS');
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
              style: ElevatedButton.styleFrom(backgroundColor: ThixPolicy.danger),
              onPressed: () async {
                final t = ctrl.text.trim();
                if (t.isEmpty) return;
                Navigator.pop(ctx);
                await _remote.requestInstruct(widget.incidentId, t);
                _toast('📢 Instruction dans le groupe SOS');
              },
              child: const Text('ENVOYER AU GROUPE'),
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

  String _fmtClock(DateTime at) {
    final l = at.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '\( {two(l.hour)}: \){two(l.minute)}:${two(l.second)}';
  }

  String _journalLabel(_JournalRow r) {
    switch (r.type) {
      case 'CMD_INSTRUCT':
        return 'Instruction : ${r.payload['text'] ?? '—'}';
      case 'CMD_CAPTURE_PHOTO':
        return 'Commande photo → victime';
      case 'CMD_CAPTURE_VIDEO':
        return 'Commande vidéo ${r.payload['seconds'] ?? 10}s → victime';
      case 'CMD_CAPTURE_CLIP_10':
        return 'Commande clip 10s';
      case 'CMD_CAPTURE_AUDIO_START':
        return 'Micro victime ON';
      case 'CMD_CAPTURE_AUDIO_STOP':
        return 'Micro victime OFF';
      case 'CMD_SURVEILLANCE_ON':
        return 'Surveillance 10s ON';
      case 'CMD_SURVEILLANCE_OFF':
        return 'Surveillance OFF';
      case 'EVIDENCE_PHOTO':
        return r.payload['posted_to_chat'] == true
            ? 'Photo reçue et poussée dans le groupe'
            : 'Photo reçue';
      case 'EVIDENCE_VIDEO':
        return 'Vidéo reçue';
      case 'EVIDENCE_AUDIO':
        return 'Audio reçu';
      case 'EVIDENCE_FAILED':
        return 'Échec capture : ${r.payload['error'] ?? ''}';
      case 'RESCUE_JOINED_CRISIS_ROOM':
        return 'Secours a rejoint la salle';
      case 'SOS_STARTED':
        return 'SOS démarré';
      case 'SOS_CREATED':
        return 'Incident créé';
      case 'QUICK_MESSAGE':
        return 'Victime : ${r.payload['text'] ?? ''}';
      default:
        return r.type;
    }
  }

  String? get _latestPhotoUrl {
    for (final e in _evidence) {
      if (e.type == 'EVIDENCE_PHOTO' && e.url != null && e.url!.isNotEmpty) {
        return e.url;
      }
    }
    return null;
  }

  @override
  void dispose() {
    _clock?.cancel();
    _uidsSub?.cancel();
    _eventsCh?.unsubscribe();
    _media.leave();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final incident =
        ref.watch(sosIncidentProvider(widget.incidentId)).valueOrNull;
    final engine = _media.engine;
    final channel = _media.channel;
    final remoteUid = _remotes.isEmpty ? null : _remotes.first;
    final hasLive = !_joining &&
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
                incident?.publicId ?? 'CENTRE DE PILOTAGE',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
              ),
              Text(
                '⏱ ${_fmtDuration(_elapsed)}  •  CERCLE ${incident?.activeCircle ?? 1}',
                style: const TextStyle(fontSize: 10, color: Colors.white70),
              ),
            ],
          ),
          actions: [
            IconButton(
              tooltip: 'Groupe SOS',
              onPressed: () => _openChat(incident),
              icon: const Icon(Icons.forum),
            ),
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
                  border: Border.all(color: Colors.red.withValues(alpha: 0.4)),
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
                            ? const CircularProgressIndicator(color: Colors.red)
                            : const Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.satellite_alt,
                                      color: Colors.white24, size: 44),
                                  SizedBox(height: 8),
                                  Text(
                                    'Pas de live Agora.\nLancez Photo / Clip 10s / Surveillance.',
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
                                  ? '● DERNIÈRE PREUVE'
                                  : '○ HORS LIGNE — COMMANDES ACTIVES',
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
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
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
                              'https://www.google.com/maps?q=\( {incident.lastLat}, \){incident.lastLng}'));
                        }
                      },
                    ),
                    const _StatusChip(
                        icon: Icons.favorite,
                        label: 'Heartbeat',
                        color: Colors.green),
                    _StatusChip(
                      icon: Icons.battery_std,
                      label: incident.batteryPct != null
                          ? '${incident.batteryPct}%'
                          : 'Batt ?',
                      color: (incident.batteryPct ?? 100) < 20
                          ? Colors.red
                          : Colors.green,
                    ),
                    _StatusChip(
                      icon: Icons.forum,
                      label: _conversationId != null ? 'Groupe OK' : 'Groupe ?',
                      color: _conversationId != null ? Colors.green : Colors.orange,
                      onTap: () => _openChat(incident),
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
                      label: 'Clip 10s',
                      onTap: _busy ? null : () => _video(10)),
                  _ControlChip(
                      icon: Icons.videocam_outlined,
                      label: 'Vidéo 30s',
                      onTap: _busy ? null : () => _video(30)),
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
        child: Text('Aucune preuve — lancez Photo / Clip 10s / Surveillance',
            textAlign: TextAlign.center,
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
        final isPhoto = e.type == 'EVIDENCE_PHOTO';
        return GestureDetector(
          onTap: () async {
            if (e.url == null) return;
            if (isPhoto) {
              showFullscreenImageViewer(context, url: e.url!);
            } else {
              await launchUrl(Uri.parse(e.url!),
                  mode: LaunchMode.externalApplication);
            }
          },
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF111827),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white12),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                Expanded(
                  child: isPhoto && e.url != null
                      ? Image.network(e.url!,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          errorBuilder: (_, __, ___) =>
                              const Icon(Icons.image, color: Colors.white24))
                      : Icon(
                          e.type == 'EVIDENCE_VIDEO'
                              ? Icons.videocam
                              : e.type == 'EVIDENCE_AUDIO'
                                  ? Icons.audiotrack
                                  : Icons.insert_drive_file,
                          color: Colors.white38,
                          size: 28,
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.all(4),
                  child: Text(
                    e.posted ? '✓ groupe' : e.error ?? e.type.replaceAll('EVIDENCE_', ''),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: e.posted ? Colors.greenAccent : Colors.white54,
                      fontSize: 9,
                    ),
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
            style: TextStyle(color: Colors.white38, fontSize: 12)),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: _journal.length,
      separatorBuilder: (_, __) => const Divider(color: Colors.white10, height: 1),
      itemBuilder: (_, i) {
        final r = _journal[i];
        return ListTile(
          dense: true,
          leading: Text(_fmtClock(r.at),
              style: const TextStyle(color: Colors.white54, fontSize: 11)),
          title: Text(_journalLabel(r),
              style: const TextStyle(color: Colors.white, fontSize: 13)),
        );
      },
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
  });
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(color: color, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

class _ControlChip extends StatelessWidget {
  const _ControlChip({
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
    return ActionChip(
      onPressed: onTap,
      avatar: Icon(icon, size: 16, color: Colors.white),
      label: Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
      backgroundColor: danger ? const Color(0xFF7F1D1D) : const Color(0xFF1E293B),
    );
  }
}
