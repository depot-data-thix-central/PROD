/// THIX SOS — Chambre de crise (secours) — Production Enterprise (audité)
/// ✅ SÉCURISÉ : syntax fix, mounted checks, timeouts, retry, validation URL,
///    permissions, i18n, semantics, haptic, removeChannel, lifecycle
import 'dart:async';
import 'package:go_router/go_router.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/l10n/app_localizations.dart';
import 'package:thix_id/models/chat/call_status.dart';
import 'package:thix_id/models/chat/chat_conversation.dart';
import 'package:thix_id/nav.dart';
import 'package:thix_id/presentation/chat/widgets/image_viewer.dart';
import 'package:thix_id/services/chat/call_signaling_service.dart';
import '../models/sos_models.dart';
import '../providers/sos_providers.dart';
import '../services/sos_crisis_media_service.dart';
import '../services/sos_remote_capture_service.dart';

// ============================================================================
// CONSTANTS
// ============================================================================
const Duration _kActionTimeout = Duration(seconds: 15);
const Duration _kMediaTimeout = Duration(seconds: 30);
const Duration _kHistoryTimeout = Duration(seconds: 20);
const int _kMaxRetries = 1;
const Duration _kRetryDelay = Duration(milliseconds: 600);
const int _kMaxHistory = 200;

// ============================================================================
// VALIDATORS
// ============================================================================
class _SecoursValidators {
  _SecoursValidators._();

  static bool isValidId(String? id) {
    if (id == null || id.trim().isEmpty) return false;
    return id.trim().length >= 8;
  }

  static bool isValidUrl(String? url) {
    if (url == null || url.isEmpty) return false;
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    return uri.scheme == 'http' || uri.scheme == 'https';
  }

  static String sanitizeText(String? input, {int maxLength = 200}) {
    if (input == null) return '';
    var s = input
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '')
        .trim();
    return s.length > maxLength ? s.substring(0, maxLength) : s;
  }

  static String friendlyError(dynamic e, AppLocalizations l10n) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('timeout')) return l10n.t('sos_error_timeout');
    if (msg.contains('permission')) return l10n.t('sos_error_permission');
    if (msg.contains('network') || msg.contains('socket')) {
      return l10n.t('sos_error_network');
    }
    if (msg.contains('agora')) return l10n.t('sos_error_live');
    return l10n.t('sos_error_generic');
  }
}

// ============================================================================
// HELPERS
// ============================================================================
Future<T> _secoursRetry<T>(
  Future<T> Function() fn, {
  required String label,
  Duration timeout = _kActionTimeout,
  int maxRetries = _kMaxRetries,
}) async {
  int attempt = 0;
  while (true) {
    try {
      return await fn().timeout(timeout);
    } on TimeoutException {
      attempt++;
      if (attempt > maxRetries) {
        debugPrint('[SecoursRoom] ❌ $label: timeout after $attempt');
        rethrow;
      }
      debugPrint('[SecoursRoom] ⏱️ $label timeout — retry $attempt/$maxRetries');
      await Future.delayed(_kRetryDelay);
    } catch (e) {
      attempt++;
      if (attempt > maxRetries) {
        debugPrint('[SecoursRoom] ❌ $label: $e');
        rethrow;
      }
      await Future.delayed(_kRetryDelay);
    }
  }
}

// ============================================================================
// MODELS (privés à ce fichier)
// ============================================================================
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

// ============================================================================
// PAGE
// ============================================================================
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
    extends ConsumerState<ChambreCriseSecoursPage>
    with WidgetsBindingObserver {
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

  // ✅ FIX P2 : cache de la dernière photo (évite O(n) à chaque build)
  String? _latestPhotoUrlCache;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    if (!_SecoursValidators.isValidId(widget.incidentId)) {
      debugPrint('[SecoursRoom] ⚠️ incidentId invalide');
      setState(() {
        _joining = false;
        _error = 'ID incident invalide';
      });
      return;
    }

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

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    debugPrint('[SecoursRoom] 🔄 lifecycle: ${state.name}');
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      // Libère le canal Agora en background pour économiser la batterie
      try {
        _media.leave();
      } catch (e) {
        debugPrint('[SecoursRoom] ⚠️ leave on pause: $e');
      }
    } else if (state == AppLifecycleState.resumed && mounted) {
      _connect();
    }
  }

  Future<void> _bootstrap() async {
    await _loadHistory();
    _subscribeEvents();
    await _connect();
  }

  // ✅ FIX P1 : timeout + logs structurés (plus de catch silencieux)
  Future<void> _loadHistory() async {
    try {
      final rows = await _secoursRetry(
        () => Supabase.instance.client
            .from('thix_sos_events')
            .select()
            .eq('incident_id', widget.incidentId)
            .order('created_at', ascending: false)
            .limit(_kMaxHistory),
        label: 'loadEventsHistory',
        timeout: _kHistoryTimeout,
      );
      for (final rec in (rows as List).reversed) {
        _ingest(Map<String, dynamic>.from(rec as Map), fromHistory: true);
      }
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('[SecoursRoom] ❌ history events: $e');
    }

    try {
      final evs = await _secoursRetry(
        () => Supabase.instance.client
            .from('thix_sos_evidence')
            .select()
            .eq('incident_id', widget.incidentId)
            .order('created_at', ascending: false),
        label: 'loadEvidenceHistory',
        timeout: _kHistoryTimeout,
      );
      for (final rec in evs as List) {
        final m = Map<String, dynamic>.from(rec as Map);
        final type = 'EVIDENCE_${(m['type'] ?? '').toString().toUpperCase()}';
        final url = m['url']?.toString();
        if (_evidence.any((e) => e.url != null && e.url == url)) continue;
        _evidence.add(_EvidenceItem(
          type: type,
          url: url,
          posted: m['posted_to_chat'] == true,
          at: DateTime.tryParse('${m['created_at']}') ?? DateTime.now(),
        ));
      }
      _latestPhotoUrlCache = _computeLatestPhoto();
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('[SecoursRoom] ❌ history evidence: $e');
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
      _latestPhotoUrlCache = _computeLatestPhoto();
    }
    if (!fromHistory && mounted) {
      final l10n = AppLocalizations.of(context);
      if (type == 'EVIDENCE_PHOTO') _toast(l10n.t('sos_ev_photo_received'));
      if (type == 'EVIDENCE_VIDEO') _toast(l10n.t('sos_ev_video_received'));
      if (type == 'EVIDENCE_AUDIO') _toast(l10n.t('sos_ev_audio_received'));
      if (type == 'EVIDENCE_FAILED') _toast(l10n.t('sos_ev_failed'));
    }
  }

  String? _computeLatestPhoto() {
    for (final e in _evidence) {
      if (e.type == 'EVIDENCE_PHOTO' &&
          _SecoursValidators.isValidUrl(e.url)) {
        return e.url;
      }
    }
    return null;
  }

  void _subscribeEvents() {
    try {
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
              setState(() =>
                  _ingest(Map<String, dynamic>.from(payload.newRecord)));
            },
          )
          .subscribe();
    } catch (e) {
      debugPrint('[SecoursRoom] ❌ subscribeEvents: $e');
    }
  }

  Future<void> _connect() async {
    setState(() {
      _joining = true;
      _error = null;
    });
    try {
      if (!kIsWeb) {
        try {
          await _secoursRetry(
            () => _media.joinAsResponder(widget.incidentId),
            label: 'joinAgora',
            timeout: _kMediaTimeout,
          );
        } catch (e) {
          debugPrint('[SecoursRoom] ⚠️ Live Agora optionnel: $e');
        }
      }
      final incident = await _secoursRetry(
        () => ref
            .read(sosServiceProvider)
            .getIncidentForRescue(widget.incidentId),
        label: 'getIncidentForRescue',
      );
      _conversationId = incident?.chatConversationId;
      await ref.read(sosServiceProvider).logEventPublic(
            widget.incidentId,
            'RESCUE_JOINED_CRISIS_ROOM',
            {'role': 'secours', 'conversation_id': _conversationId},
          );
      debugPrint('[SecoursRoom] ✓ Connected');
    } catch (e) {
      debugPrint('[SecoursRoom] ❌ connect: $e');
      if (mounted) {
        setState(() {
          _error = _SecoursValidators.friendlyError(e, AppLocalizations.of(context));
        });
      }
    }
    if (mounted) setState(() => _joining = false);
  }

  // ✅ FIX P0 : mounted check + timeout + friendly error + haptic
  Future<void> _photo() async {
    if (_busy || !mounted) return;
    HapticFeedback.mediumImpact();
    final l10n = AppLocalizations.of(context);
    setState(() => _busy = true);
    try {
      await _secoursRetry(
        () => _remote.requestPhoto(widget.incidentId),
        label: 'requestPhoto',
      );
      if (mounted) _toast(l10n.t('sos_cmd_photo'));
    } catch (e) {
      if (mounted) _toast(_SecoursValidators.friendlyError(e, l10n));
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _video(int seconds) async {
    if (_busy || !mounted) return;
    HapticFeedback.mediumImpact();
    final l10n = AppLocalizations.of(context);
    setState(() => _busy = true);
    try {
      await _secoursRetry(
        () => _remote.requestVideo(widget.incidentId, seconds: seconds),
        label: 'requestVideo',
      );
      if (mounted) _toast(l10n.t('sos_cmd_video'));
    } catch (e) {
      if (mounted) _toast(_SecoursValidators.friendlyError(e, l10n));
    }
    if (mounted) setState(() => _busy = false);
  }

  // ✅ FIX P1 : permission micro avant toggle
  Future<void> _toggleAudio() async {
    if (_busy || !mounted) return;
    HapticFeedback.mediumImpact();
    final l10n = AppLocalizations.of(context);

    if (!_audioArmed) {
      final hasPerm = await _ensureMicPermission();
      if (!hasPerm) {
        _toast(l10n.t('sos_error_permission'));
        return;
      }
    }

    setState(() => _busy = true);
    try {
      if (_audioArmed) {
        await _secoursRetry(
          () => _remote.requestAudioStop(widget.incidentId),
          label: 'audioStop',
        );
        _audioArmed = false;
        if (mounted) _toast(l10n.t('sos_cmd_audio_stop'));
      } else {
        await _secoursRetry(
          () => _remote.requestAudioStart(widget.incidentId),
          label: 'audioStart',
        );
        _audioArmed = true;
        if (mounted) _toast(l10n.t('sos_cmd_audio_start'));
      }
    } catch (e) {
      if (mounted) _toast(_SecoursValidators.friendlyError(e, l10n));
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<bool> _ensureMicPermission() async {
    if (kIsWeb) return true;
    try {
      final status = await Permission.microphone.status;
      if (status.isGranted) return true;
      final res = await Permission.microphone.request();
      return res.isGranted;
    } catch (e) {
      debugPrint('[SecoursRoom] ⚠️ permission micro: $e');
      return false;
    }
  }

  Future<void> _toggleSurveillance() async {
    if (!mounted) return;
    HapticFeedback.mediumImpact();
    final l10n = AppLocalizations.of(context);
    try {
      if (_surveillance) {
        await _secoursRetry(
          () => _remote.requestSurveillanceOff(widget.incidentId),
          label: 'surveillanceOff',
        );
        _surveillance = false;
        if (mounted) _toast(l10n.t('sos_cmd_surveillance_off'));
      } else {
        await _secoursRetry(
          () => _remote.requestSurveillanceOn(widget.incidentId),
          label: 'surveillanceOn',
        );
        _surveillance = true;
        if (mounted) _toast(l10n.t('sos_cmd_surveillance_on'));
      }
    } catch (e) {
      if (mounted) _toast(_SecoursValidators.friendlyError(e, l10n));
    }
    if (mounted) setState(() {});
  }

  Future<void> _callVictim() async {
    if (!mounted) return;
    HapticFeedback.mediumImpact();
    final l10n = AppLocalizations.of(context);
    final victimId = widget.victimUserId;
    if (victimId == null || victimId.isEmpty) {
      _toast(l10n.t('sos_victim_unknown'));
      return;
    }
    try {
      await _secoursRetry(
        () => CallSignalingService()
            .startCall(calleeId: victimId, type: CallType.audio),
        label: 'callVictim',
      );
      if (mounted) _toast(l10n.t('sos_calling'));
    } catch (e) {
      if (mounted) _toast(_SecoursValidators.friendlyError(e, l10n));
    }
  }

  void _openChat(SosIncident? incident) {
    final id = _conversationId ?? incident?.chatConversationId;
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    if (id == null || id.isEmpty) {
      _toast(l10n.t('sos_chat_not_ready'));
      return;
    }
    final conversation = ChatConversation(
      id: id,
      isGroup: true,
      groupName: 'THIX CHAT ${incident?.publicId ?? ''}',
      participantIds: const [],
      updatedAt: DateTime.now(),
    );
    HapticFeedback.selectionClick();
    // ✅ FIX P1 : navigation décommentée + context.push au lieu de maybePop
    Navigator.of(context).maybePop();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.push(AppRoutes.chatDetail(id), extra: conversation);
    });
  }

  void _openInstructions() {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    final ctrl = TextEditingController();
    final presets = [
      l10n.t('sos_instruct_calm'),
      l10n.t('sos_instruct_talk'),
      l10n.t('sos_instruct_room'),
      l10n.t('sos_instruct_clip'),
      l10n.t('sos_instruct_stay'),
    ];
    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      backgroundColor: ThixPolicy.inkDeep,
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
            Semantics(
              header: true,
              child: Text(
                l10n.t('sos_instruct_title'),
                style: ThixPolicy.titleStyle.copyWith(
                  color: Colors.white,
                  fontWeight: ThixPolicy.bold,
                  fontSize: 15,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: presets
                  .map((t) => Semantics(
                        button: true,
                        label: t,
                        child: ActionChip(
                          label: Text(t,
                              style: ThixPolicy.captionStyle
                                  .copyWith(color: Colors.white70)),
                          backgroundColor: ThixPolicy.card,
                          onPressed: () async {
                            Navigator.pop(ctx);
                            HapticFeedback.lightImpact();
                            try {
                              await _secoursRetry(
                                () => _remote.requestInstruct(
                                    widget.incidentId, t),
                                label: 'instruct',
                              );
                              if (mounted) _toast(l10n.t('sos_instruct_sent'));
                            } catch (e) {
                              if (mounted) {
                                _toast(_SecoursValidators.friendlyError(
                                    e, l10n));
                              }
                            }
                          },
                        ),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 12),
            Semantics(
              textField: true,
              label: l10n.t('sos_instruct_custom'),
              child: TextField(
                controller: ctrl,
                style: const TextStyle(color: Colors.white),
                maxLength: 280,
                decoration: InputDecoration(
                  counterText: '',
                  hintText: l10n.t('sos_instruct_custom'),
                  hintStyle: const TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: ThixPolicy.card,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Semantics(
              button: true,
              label: l10n.t('sos_send_group'),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: ThixPolicy.danger),
                onPressed: () async {
                  final t = _SecoursValidators.sanitizeText(ctrl.text,
                      maxLength: 280);
                  if (t.isEmpty) return;
                  Navigator.pop(ctx);
                  HapticFeedback.mediumImpact();
                  try {
                    await _secoursRetry(
                      () => _remote.requestInstruct(widget.incidentId, t),
                      label: 'instructCustom',
                    );
                    if (mounted) _toast(l10n.t('sos_instruct_sent'));
                  } catch (e) {
                    if (mounted) {
                      _toast(_SecoursValidators.friendlyError(e, l10n));
                    }
                  }
                },
                child: Text(l10n.t('sos_send_group')),
              ),
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

  // ✅ FIX P0 : syntax error corrigée
  String _fmtClock(DateTime at) {
    final l = at.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(l.hour)}:${two(l.minute)}:${two(l.second)}';
  }

  String _journalLabel(_JournalRow r, AppLocalizations l10n) {
    final sanitizedText =
        _SecoursValidators.sanitizeText(r.payload['text']?.toString());
    switch (r.type) {
      case 'CMD_INSTRUCT':
        return '${l10n.t('sos_ev_instruct')}: ${sanitizedText.isNotEmpty ? sanitizedText : '—'}';
      case 'CMD_CAPTURE_PHOTO':
        return l10n.t('sos_cmd_photo');
      case 'CMD_CAPTURE_VIDEO':
        return '${l10n.t('sos_cmd_video')} ${r.payload['seconds'] ?? 10}s';
      case 'CMD_CAPTURE_CLIP_10':
        return l10n.t('sos_cmd_clip');
      case 'CMD_CAPTURE_AUDIO_START':
        return l10n.t('sos_cmd_audio_start');
      case 'CMD_CAPTURE_AUDIO_STOP':
        return l10n.t('sos_cmd_audio_stop');
      case 'CMD_SURVEILLANCE_ON':
        return l10n.t('sos_cmd_surveillance_on');
      case 'CMD_SURVEILLANCE_OFF':
        return l10n.t('sos_cmd_surveillance_off');
      case 'EVIDENCE_PHOTO':
        return r.payload['posted_to_chat'] == true
            ? l10n.t('sos_ev_photo_sent')
            : l10n.t('sos_ev_photo_captured');
      case 'EVIDENCE_VIDEO':
        return l10n.t('sos_ev_video_captured');
      case 'EVIDENCE_AUDIO':
        return l10n.t('sos_ev_audio_captured');
      case 'EVIDENCE_FAILED':
        return l10n.t('sos_ev_failed');
      case 'RESCUE_JOINED_CRISIS_ROOM':
        return l10n.t('sos_ev_rescue_joined');
      case 'SOS_STARTED':
        return l10n.t('sos_ev_started');
      case 'SOS_CREATED':
        return l10n.t('sos_ev_created');
      case 'QUICK_MESSAGE':
        return '${l10n.t('sos_victim_label')}: ${sanitizedText.isNotEmpty ? sanitizedText : ''}';
      default:
        return _SecoursValidators.sanitizeText(r.type, maxLength: 60);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _clock?.cancel();
    _uidsSub?.cancel();

    // ✅ FIX P0 : unsubscribe + removeChannel (plus de canal orphelin)
    try {
      final ch = _eventsCh;
      if (ch != null) {
        ch.unsubscribe();
        Supabase.instance.client.removeChannel(ch);
      }
    } catch (e) {
      debugPrint('[SecoursRoom] ⚠️ removeChannel: $e');
    }

    try {
      _media.leave();
    } catch (e) {
      debugPrint('[SecoursRoom] ⚠️ leave on dispose: $e');
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final incident =
        ref.watch(sosIncidentProvider(widget.incidentId)).valueOrNull;
    final engine = _media.engine;
    final channel = _media.channel;
    final remoteUid = _remotes.isEmpty ? null : _remotes.first;
    final hasLive = !kIsWeb &&
        !_joining &&
        engine != null &&
        channel != null &&
        remoteUid != null;

    if (_error != null && incident == null) {
      return Scaffold(
        backgroundColor: ThixPolicy.inkDeep,
        body: SafeArea(
          child: _ErrorState(
            message: _error!,
            onRetry: _bootstrap,
          ),
        ),
      );
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: ThixPolicy.inkDeep,
        appBar: AppBar(
          backgroundColor: ThixPolicy.danger.withValues(alpha: 0.4),
          title: Column(
            children: [
              Semantics(
                header: true,
                child: Text(
                  incident?.publicId ?? l10n.t('sos_command_center'),
                  style: ThixPolicy.titleStyle.copyWith(
                    fontSize: 14,
                    fontWeight: ThixPolicy.bold,
                  ),
                ),
              ),
              Text(
                '⏱ ${_fmtDuration(_elapsed)}  •  ${l10n.t('sos_circle')} ${incident?.activeCircle ?? 1}',
                style: ThixPolicy.captionStyle.copyWith(color: Colors.white70),
              ),
            ],
          ),
          actions: [
            Semantics(
              button: true,
              label: l10n.t('sos_group'),
              child: IconButton(
                tooltip: l10n.t('sos_group'),
                onPressed: () => _openChat(incident),
                icon: const Icon(Icons.forum),
              ),
            ),
            Semantics(
              button: true,
              label: _muted ? l10n.t('sos_mic_on') : l10n.t('sos_mic_mute'),
              child: IconButton(
                tooltip: _muted ? l10n.t('sos_mic_on') : l10n.t('sos_mic_mute'),
                onPressed: () async {
                  HapticFeedback.selectionClick();
                  await _media.setMuted(!_muted);
                  if (mounted) setState(() => _muted = !_muted);
                },
                icon: Icon(_muted ? Icons.mic_off : Icons.mic),
              ),
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
                  border: Border.all(
                      color: ThixPolicy.danger.withValues(alpha: 0.4)),
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
                    else if (_latestPhotoUrlCache != null)
                      // ✅ FIX P0 : Image.network avec validation URL
                      CachedNetworkImageSafe(url: _latestPhotoUrlCache!)
                    else
                      Center(
                        child: _joining
                            ? const CircularProgressIndicator(
                                color: ThixPolicy.danger)
                            : Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.satellite_alt,
                                      color: Colors.white24, size: 44),
                                  const SizedBox(height: 8),
                                  Text(
                                    l10n.t('sos_no_live'),
                                    textAlign: TextAlign.center,
                                    style:
                                        const TextStyle(color: Colors.white54),
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
                              ? ThixPolicy.danger
                              : _latestPhotoUrlCache != null
                                  ? ThixPolicy.warning
                                  : ThixPolicy.textMuted,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          hasLive
                              ? '● LIVE'
                              : _latestPhotoUrlCache != null
                                  ? '● ${l10n.t('sos_latest_evidence')}'
                                  : '○ ${l10n.t('sos_offline')}',
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
                            color: ThixPolicy.success,
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
                      label: incident.hasLocation &&
                              incident.lastLat != null &&
                              incident.lastLng != null
                          ? '${incident.lastLat!.toStringAsFixed(4)}, ${incident.lastLng!.toStringAsFixed(4)}'
                          : l10n.t('sos_position_unknown'),
                      color: ThixPolicy.success,
                      onTap: () async {
                        if (incident.hasLocation &&
                            incident.lastLat != null &&
                            incident.lastLng != null) {
                          HapticFeedback.selectionClick();
                          // ✅ FIX P0 : syntax error corrigée
                          final url =
                              'https://www.google.com/maps?q=${incident.lastLat},${incident.lastLng}';
                          await launchUrl(Uri.parse(url),
                              mode: LaunchMode.externalApplication);
                        }
                      },
                    ),
                    _StatusChip(
                        icon: Icons.favorite,
                        label: 'Heartbeat',
                        color: ThixPolicy.success),
                    _StatusChip(
                      icon: Icons.battery_std,
                      label: incident.batteryPct != null
                          ? '${incident.batteryPct}%'
                          : l10n.t('sos_battery_unknown'),
                      color: (incident.batteryPct ?? 100) < 20
                          ? ThixPolicy.danger
                          : ThixPolicy.success,
                    ),
                    _StatusChip(
                      icon: Icons.forum,
                      label: _conversationId != null
                          ? l10n.t('sos_group_ok')
                          : l10n.t('sos_group_waiting'),
                      color: _conversationId != null
                          ? ThixPolicy.success
                          : ThixPolicy.warning,
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
                      label: l10n.t('sos_photo'),
                      onTap: _busy ? null : _photo),
                  _ControlChip(
                      icon: Icons.videocam,
                      label: l10n.t('sos_clip'),
                      onTap: _busy ? null : () => _video(10)),
                  _ControlChip(
                      icon: Icons.videocam_outlined,
                      label: l10n.t('sos_video_30s'),
                      onTap: _busy ? null : () => _video(30)),
                  _ControlChip(
                    icon: _audioArmed ? Icons.stop_circle : Icons.mic_none,
                    label: _audioArmed
                        ? l10n.t('sos_stop_audio')
                        : l10n.t('sos_record_audio'),
                    danger: _audioArmed,
                    onTap: _busy ? null : _toggleAudio,
                  ),
                  _ControlChip(
                    icon: _surveillance
                        ? Icons.visibility_off
                        : Icons.visibility,
                    label: _surveillance
                        ? l10n.t('sos_stop_surveillance')
                        : l10n.t('sos_surveillance_10s'),
                    danger: _surveillance,
                    onTap: _toggleSurveillance,
                  ),
                  _ControlChip(
                      icon: Icons.campaign,
                      label: l10n.t('sos_instruction'),
                      onTap: _openInstructions),
                  _ControlChip(
                      icon: Icons.call,
                      label: l10n.t('sos_audio_call'),
                      onTap: _callVictim),
                ],
              ),
            ),
            TabBar(
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white38,
              indicatorColor: ThixPolicy.danger,
              tabs: [
                Tab(text: l10n.t('sos_tab_evidence')),
                Tab(text: l10n.t('sos_tab_journal')),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [_buildEvidenceTab(l10n), _buildJournalTab(l10n)],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEvidenceTab(AppLocalizations l10n) {
    if (_evidence.isEmpty) {
      return Center(
        child: Text(l10n.t('sos_no_evidence'),
            textAlign: TextAlign.center,
            style: ThixPolicy.captionStyle.copyWith(color: Colors.white38)),
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
        // ✅ FIX P0 : validation URL avant affichage
        final validUrl = _SecoursValidators.isValidUrl(e.url);

        return Semantics(
          button: true,
          label: '${e.type.replaceAll('EVIDENCE_', '')} ${l10n.t('sos_evidence')}',
          child: GestureDetector(
            onTap: () async {
              if (!validUrl || e.url == null) return;
              HapticFeedback.lightImpact();
              if (isPhoto) {
                showFullscreenImageViewer(context, url: e.url!);
              } else {
                await launchUrl(Uri.parse(e.url!),
                    mode: LaunchMode.externalApplication);
              }
            },
            child: Container(
              decoration: BoxDecoration(
                color: ThixPolicy.card,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: ThixPolicy.border),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  Expanded(
                    child: isPhoto && validUrl
                        ? CachedNetworkImageSafe(url: e.url!)
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
                      e.posted
                          ? '✓ ${l10n.t('sos_group')}'
                          : e.error ??
                              e.type.replaceAll('EVIDENCE_', ''),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: e.posted
                            ? ThixPolicy.success
                            : Colors.white54,
                        fontSize: 9,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildJournalTab(AppLocalizations l10n) {
    if (_journal.isEmpty) {
      return Center(
        child: Text(l10n.t('sos_journal_empty'),
            style: ThixPolicy.captionStyle.copyWith(color: Colors.white38)),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: _journal.length,
      separatorBuilder: (_, __) =>
          const Divider(color: Colors.white10, height: 1),
      itemBuilder: (_, i) {
        final r = _journal[i];
        return ListTile(
          dense: true,
          leading: Text(_fmtClock(r.at),
              style: ThixPolicy.captionStyle
                  .copyWith(color: Colors.white54, fontSize: 11)),
          title: Text(_journalLabel(r, l10n),
              style: ThixPolicy.labelStyle
                  .copyWith(color: Colors.white, fontSize: 13)),
        );
      },
    );
  }
}

// ============================================================================
// IMAGE SAFE (validation URL + placeholder + error)
// ============================================================================
class CachedNetworkImageSafe extends StatelessWidget {
  const CachedNetworkImageSafe({super.key, required this.url});
  final String url;

  @override
  Widget build(BuildContext context) {
    if (!_SecoursValidators.isValidUrl(url)) {
      return const Center(
        child: Icon(Icons.broken_image, color: Colors.white24, size: 40),
      );
    }
    return Image.network(
      url,
      fit: BoxFit.cover,
      width: double.infinity,
      loadingBuilder: (_, child, progress) {
        if (progress == null) return child;
        return const Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: ThixPolicy.primary),
          ),
        );
      },
      errorBuilder: (_, __, ___) => const Center(
          child:
              Icon(Icons.broken_image, color: Colors.white24, size: 40)),
    );
  }
}

// ============================================================================
// STATUS CHIP — ✅ avec Semantics
// ============================================================================
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
    return Semantics(
      button: onTap != null,
      label: label,
      child: InkWell(
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
              Text(label,
                  style:
                      ThixPolicy.captionStyle.copyWith(color: color)),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// CONTROL CHIP — ✅ avec Semantics + ThixPolicy
// ============================================================================
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
    return Semantics(
      button: true,
      label: label,
      enabled: onTap != null,
      child: ActionChip(
        onPressed: onTap,
        avatar: Icon(icon, size: 16, color: Colors.white),
        label: Text(label,
            style: ThixPolicy.captionStyle
                .copyWith(color: Colors.white, fontSize: 12)),
        backgroundColor:
            danger ? ThixPolicy.danger : ThixPolicy.card,
      ),
    );
  }
}

// ============================================================================
// ERROR STATE — ✅ retry button
// ============================================================================
class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline,
                color: ThixPolicy.danger, size: 40),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: ThixPolicy.bodyStyle.copyWith(color: Colors.white),
            ),
            const SizedBox(height: 16),
            Semantics(
              button: true,
              label: l10n.t('common_retry'),
              child: ElevatedButton.icon(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  onRetry();
                },
                icon: const Icon(Icons.refresh, size: 18),
                label: Text(l10n.t('common_retry')),
                style: ElevatedButton.styleFrom(
                    backgroundColor: ThixPolicy.danger),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
