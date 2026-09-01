/// THIX SOS — Chambre de crise (victime) — Production Enterprise (audité)
/// ✅ SÉCURISÉ : validation URL, permissions, timeouts, retry, i18n, semantics
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:thix_id/nav.dart';
import 'package:thix_id/models/chat/chat_conversation.dart';
import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/l10n/app_localizations.dart';
import 'package:thix_id/presentation/chat/providers/chat_providers.dart'
    show chatServiceProvider;
import '../services/sos_crisis_media_service.dart';
import '../services/sos_remote_capture_service.dart';
import '../services/sos_victim_capture_daemon.dart';
import '../models/sos_models.dart';
import '../providers/sos_providers.dart';
import 'sos_pin_page.dart';

// ============================================================================
// CONSTANTS
// ============================================================================
const Duration _kActionTimeout = Duration(seconds: 15);
const Duration _kMediaTimeout = Duration(seconds: 30);
const int _kMaxRetries = 1;
const Duration _kRetryDelay = Duration(milliseconds: 600);
const Duration _kQuickCooldown = Duration(seconds: 30);
const int _kMaxEvents = 30;

// ============================================================================
// VALIDATORS
// ============================================================================
class _CrisisValidators {
  _CrisisValidators._();

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

  static String safeInitial(String? name, {String fallback = '?'}) {
    if (name == null || name.trim().isEmpty) return fallback;
    return name.trim()[0].toUpperCase();
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
    return l10n.t('sos_error_generic');
  }
}

// ============================================================================
// HELPERS
// ============================================================================
Future<T> _crisisRetry<T>(
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
        debugPrint('[ChambreCrise] ❌ $label: timeout after $attempt');
        rethrow;
      }
      debugPrint('[ChambreCrise] ⏱️ $label timeout — retry $attempt/$maxRetries');
      await Future.delayed(_kRetryDelay);
    } catch (e) {
      attempt++;
      if (attempt > maxRetries) {
        debugPrint('[ChambreCrise] ❌ $label: $e');
        rethrow;
      }
      await Future.delayed(_kRetryDelay);
    }
  }
}

// ============================================================================
// PAGE
// ============================================================================
class ChambreCrisePage extends ConsumerStatefulWidget {
  const ChambreCrisePage({
    super.key,
    required this.incidentId,
    this.conversationId,
  });

  final String incidentId;
  final String? conversationId;

  @override
  ConsumerState<ChambreCrisePage> createState() => _ChambreCrisePageState();
}

class _ChambreCrisePageState extends ConsumerState<ChambreCrisePage>
    with WidgetsBindingObserver {
  Timer? _uiTimer;
  Duration _elapsed = Duration.zero;
  String? _resolvedConversationId;

  final Map<String, DateTime> _quickSentAt = {};
  bool _camOn = false;
  bool _camBusy = false;
  bool _clipBusy = false;
  final _remoteCapture = SosRemoteCaptureService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _resolvedConversationId = widget.conversationId;

    if (!_CrisisValidators.isValidId(widget.incidentId)) {
      debugPrint('[ChambreCrise] ⚠️ incidentId invalide');
      return;
    }

    _uiTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final incident =
          ref.read(sosIncidentProvider(widget.incidentId)).valueOrNull;
      if (incident != null) {
        var d = DateTime.now().difference(incident.startedAt.toLocal());
        if (d.isNegative) d = Duration.zero;
        setState(() => _elapsed = d);
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref
          .read(sosHeartbeatControllerProvider.notifier)
          .start(widget.incidentId);
      _loadConversationId();
      _startCamera();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    debugPrint('[ChambreCrise] 🔄 lifecycle: ${state.name}');
    if (state == AppLifecycleState.resumed && _camOn && mounted) {
      // Vérifie que le broadcast est toujours actif après retour foreground
      _startCamera();
    }
  }

  @override
  void dispose() {
    _uiTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _remoteCapture.stop();
    SosVictimCaptureDaemon.instance.stop();
    SosCrisisMediaService.instance.leave();
    super.dispose();
  }

  // ✅ FIX P0 : permission caméra + garde kIsWeb + retry + timeout
  Future<bool> _ensureCameraPermission() async {
    if (kIsWeb) return true;
    try {
      final status = await Permission.camera.status;
      if (status.isGranted) return true;
      final res = await Permission.camera.request();
      return res.isGranted;
    } catch (e) {
      debugPrint('[ChambreCrise] ⚠️ permission caméra: $e');
      return false;
    }
  }

  Future<void> _startCamera() async {
    if (_camOn || _camBusy) return;
    setState(() => _camBusy = true);
    try {
      final hasPerm = await _ensureCameraPermission();
      if (!hasPerm) {
        if (mounted) _snack(AppLocalizations.of(context).t('sos_error_permission'));
        return;
      }
      await _crisisRetry(
        () => SosCrisisMediaService.instance
            .startVictimBroadcast(widget.incidentId),
        label: 'startCamera',
        timeout: _kMediaTimeout,
      );
      if (mounted) setState(() => _camOn = true);
      debugPrint('[ChambreCrise] ✓ caméra LIVE');
    } catch (e) {
      debugPrint('[ChambreCrise] ❌ caméra: $e');
      if (mounted) {
        _snack(AppLocalizations.of(context).t('sos_error_camera'));
      }
    } finally {
      if (mounted) setState(() => _camBusy = false);
    }
  }

  Future<void> _toggleCamera() async {
    if (_camBusy) return;
    HapticFeedback.mediumImpact();
    setState(() => _camBusy = true);
    try {
      if (_camOn) {
        await _crisisRetry(
          () => SosCrisisMediaService.instance.leave(),
          label: 'stopCamera',
          timeout: _kMediaTimeout,
        );
        if (mounted) setState(() => _camOn = false);
      } else {
        await _startCamera();
      }
    } catch (e) {
      if (!mounted) return;
      _snack(_CrisisValidators.friendlyError(e, AppLocalizations.of(context)));
    } finally {
      if (mounted) setState(() => _camBusy = false);
    }
  }

  // ✅ FIX P1 : timeout + log structuré (plus de catch silencieux)
  Future<void> _loadConversationId() async {
    try {
      if (_resolvedConversationId == null) {
        final incident = await _crisisRetry(
          () => ref
              .read(sosServiceProvider)
              .getIncidentById(widget.incidentId),
          label: 'getIncident',
        );
        _resolvedConversationId = incident?.chatConversationId;
      }
    } catch (e) {
      debugPrint('[ChambreCrise] ❌ loadConversationId: $e');
    }

    if (!mounted) return;
    _remoteCapture.listenAsVictim(
      incidentId: widget.incidentId,
      conversationId: _resolvedConversationId,
      onInfo: _snack,
      onError: (e) {
        if (!mounted) return;
        _snack(_CrisisValidators.friendlyError(e, AppLocalizations.of(context)));
      },
    );

    SosVictimCaptureDaemon.instance.start(
      incidentId: widget.incidentId,
      conversationId: _resolvedConversationId,
      onInfo: _snack,
    );
  }

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          m,
          style: ThixPolicy.bodyStyle.copyWith(color: ThixPolicy.onBrand),
        ),
        backgroundColor: ThixPolicy.inkDeep,
      ),
    );
  }

  Future<void> _launchClip10(SosIncident incident) async {
    if (_clipBusy) return;
    HapticFeedback.mediumImpact();
    setState(() => _clipBusy = true);
    final l10n = AppLocalizations.of(context);
    try {
      final conv = incident.chatConversationId ?? _resolvedConversationId;
      final e = await _crisisRetry(
        () => SosRemoteCaptureService.instance.runVictimClip10(
          incidentId: incident.id,
          conversationId: conv,
        ),
        label: 'clip10',
        timeout: _kMediaTimeout,
      );
      if (!mounted) return;
      _snack(
        e == null
            ? l10n.t('sos_clip_unavailable')
            : e.postedToChat
                ? l10n.t('sos_clip_sent')
                : l10n.t('sos_clip_pending'),
      );
    } catch (e) {
      if (!mounted) return;
      _snack(_CrisisValidators.friendlyError(e, l10n));
    } finally {
      if (mounted) setState(() => _clipBusy = false);
    }
  }

  String get _elapsedLabel {
    final h = _elapsed.inHours.toString().padLeft(2, '0');
    final m = (_elapsed.inMinutes % 60).toString().padLeft(2, '0');
    final s = (_elapsed.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  // ✅ FIX P1 : DI via provider (plus d'instanciation inline)
  Future<void> _openChat(SosIncident incident) async {
    final l10n = AppLocalizations.of(context);
    final convId = incident.chatConversationId ?? _resolvedConversationId;
    if (convId == null || convId.isEmpty) {
      _snack(l10n.t('sos_chat_not_ready'));
      return;
    }

    ChatConversation? conversation;
    try {
      conversation = await _crisisRetry(
        () => ref.read(chatServiceProvider).getConversation(convId),
        label: 'getConversation',
      );
    } catch (e) {
      debugPrint('[ChambreCrise] ⚠️ getConversation: $e');
    }

    conversation ??= ChatConversation(
      id: convId,
      isGroup: true,
      groupName: 'THIX CHAT ${incident.publicId}',
      participantIds: const [],
      updatedAt: DateTime.now(),
    );

    if (!mounted) return;
    context.push(
      AppRoutes.chatDetail(convId),
      extra: conversation,
    );
  }

  Future<void> _callContact(SosContact contact) async {
    final l10n = AppLocalizations.of(context);
    HapticFeedback.mediumImpact();
    final userId =
        await ref.read(sosServiceProvider).resolveContactUserId(contact);
    if (!mounted) return;
    if (userId == null) {
      _snack(l10n.t('sos_no_thix_account'));
      return;
    }
    _snack(l10n.t('sos_calling'));
  }

  // ✅ FIX P1 : cooldown temporel au lieu de blocage définitif
  Future<void> _sendQuickMessage(SosIncident incident, String text) async {
    final lastSent = _quickSentAt[text];
    if (lastSent != null &&
        DateTime.now().difference(lastSent) < _kQuickCooldown) {
      return;
    }
    setState(() => _quickSentAt[text] = DateTime.now());
    HapticFeedback.lightImpact();

    final convId = incident.chatConversationId ?? _resolvedConversationId;

    try {
      await ref.read(sosServiceProvider).logEventPublic(
            incident.id,
            'QUICK_MESSAGE',
            {'text': text},
          );
    } catch (e) {
      debugPrint('[ChambreCrise] ❌ logEvent: $e');
    }

    if (convId != null && convId.isNotEmpty) {
      try {
        await _crisisRetry(
          () => ref.read(chatServiceProvider).sendMessage(
                conversationId: convId,
                content: text,
              ),
          label: 'quickMsg',
        );
      } catch (e) {
        debugPrint('[ChambreCrise] ❌ quickMsg chat: $e');
      }
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text,
            style: ThixPolicy.bodyStyle.copyWith(color: ThixPolicy.onBrand)),
        backgroundColor: ThixPolicy.inkDeep,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _endSos() {
    HapticFeedback.mediumImpact();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SosPinPage(
          incidentId: widget.incidentId,
          mode: SosPinMode.resolve,
        ),
      ),
    );
  }

  void _cancelSos() {
    HapticFeedback.mediumImpact();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SosPinPage(
          incidentId: widget.incidentId,
          mode: SosPinMode.cancel,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final incidentAsync = ref.watch(sosIncidentProvider(widget.incidentId));
    final eventsAsync = ref.watch(sosEventsProvider(widget.incidentId));
    final contactsAsync = ref.watch(sosContactsProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: incidentAsync.when(
          loading: () => const _SkeletonLoader(),
          error: (e, _) => _ErrorState(
            message: _CrisisValidators.friendlyError(e, l10n),
            onRetry: () =>
                ref.invalidate(sosIncidentProvider(widget.incidentId)),
          ),
          data: (incident) {
            if (incident == null) {
              return _ErrorState(
                message: l10n.t('sos_incident_not_found'),
                onRetry: () =>
                    ref.invalidate(sosIncidentProvider(widget.incidentId)),
              );
            }

            final circleContacts = contactsAsync.maybeWhen(
              data: (all) => all
                  .where((c) => c.circle == incident.activeCircle)
                  .toList(),
              orElse: () => <SosContact>[],
            );

            return Column(
              children: [
                _Header(
                  publicId: incident.publicId,
                  elapsed: _elapsedLabel,
                  status: incident.status,
                  onBack: () => Navigator.pop(context),
                  onEnd: _endSos,
                  camOn: _camOn,
                  onToggleCam: _toggleCamera,
                ),
                Expanded(
                  child: RefreshIndicator(
                    color: ThixPolicy.danger,
                    backgroundColor: Theme.of(context).cardColor,
                    onRefresh: () async {
                      ref.invalidate(sosIncidentProvider(widget.incidentId));
                      ref.invalidate(sosEventsProvider(widget.incidentId));
                      ref.invalidate(sosContactsProvider);
                    },
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(
                          ThixPolicy.s16,
                          ThixPolicy.s12,
                          ThixPolicy.s16,
                          ThixPolicy.s32),
                      children: [
                        _StatusStrip(incident: incident, camOn: _camOn),
                        const SizedBox(height: ThixPolicy.s16),
                        _section(l10n.t('sos_section_location')),
                        const SizedBox(height: ThixPolicy.s8),
                        _LiveMapCard(incident: incident),
                        const SizedBox(height: ThixPolicy.s20),
                        _section(
                            '${l10n.t('sos_section_rescuers')} — ${l10n.t('sos_circle')} ${incident.activeCircle}'),
                        const SizedBox(height: ThixPolicy.s8),
                        if (circleContacts.isEmpty)
                          _EmptyBox(l10n.t('sos_no_rescuers_circle'))
                        else
                          ...circleContacts.map(
                            (c) => _ResponderTile(
                              contact: c,
                              onCall: () => _callContact(c),
                            ),
                          ),
                        const SizedBox(height: ThixPolicy.s20),
                        _section(l10n.t('sos_section_communication')),
                        const SizedBox(height: ThixPolicy.s8),
                        Row(
                          children: [
                            Expanded(
                              child: _ComButton(
                                icon: Icons.chat_bubble_outline,
                                label: l10n.t('sos_chat'),
                                color: ThixPolicy.primary,
                                onTap: () => _openChat(incident),
                              ),
                            ),
                            const SizedBox(width: ThixPolicy.s10),
                            Expanded(
                              child: _ComButton(
                                icon: Icons.videocam,
                                label: _clipBusy
                                    ? l10n.t('sos_clip_busy')
                                    : l10n.t('sos_clip'),
                                color: ThixPolicy.warning,
                                onTap: _clipBusy
                                    ? () {}
                                    : () => _launchClip10(incident),
                              ),
                            ),
                            const SizedBox(width: ThixPolicy.s10),
                            Expanded(
                              child: _ComButton(
                                icon: Icons.phone_in_talk,
                                label: l10n.t('sos_recall'),
                                color: ThixPolicy.success,
                                onTap: () {
                                  if (circleContacts.isNotEmpty) {
                                    _callContact(circleContacts.first);
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                        if (_clipBusy) ...[
                          const SizedBox(height: ThixPolicy.s8),
                          Text(
                            l10n.t('sos_clip_recording'),
                            style: ThixPolicy.captionStyle,
                          ),
                        ],
                        const SizedBox(height: ThixPolicy.s20),
                        _section(l10n.t('sos_section_quick')),
                        const SizedBox(height: ThixPolicy.s8),
                        Wrap(
                          spacing: ThixPolicy.s8,
                          runSpacing: ThixPolicy.s8,
                          children: [
                            for (final msg in _quickMessages(l10n))
                              _QuickMsg(
                                label: msg,
                                sent: _quickSentAt[msg] != null &&
                                    DateTime.now().difference(_quickSentAt[msg]!) <
                                        _kQuickCooldown,
                                onTap: () => _sendQuickMessage(incident, msg),
                              ),
                          ],
                        ),
                        const SizedBox(height: ThixPolicy.s20),
                        _section(l10n.t('sos_section_system')),
                        const SizedBox(height: ThixPolicy.s8),
                        _SystemRow(incident: incident),
                        const SizedBox(height: ThixPolicy.s20),
                        _section(l10n.t('sos_section_events')),
                        const SizedBox(height: ThixPolicy.s8),
                        eventsAsync.when(
                          loading: () => const _SkeletonLoader(compact: true),
                          error: (_, __) =>
                              _EmptyBox(l10n.t('sos_events_error')),
                          data: (events) {
                            if (events.isEmpty) {
                              return _EmptyBox(l10n.t('sos_no_events'));
                            }
                            return Column(
                              children: events
                                  .take(_kMaxEvents)
                                  .map((e) => _EventTile(event: e))
                                  .toList(),
                            );
                          },
                        ),
                        const SizedBox(height: ThixPolicy.s24),
                        Semantics(
                          button: true,
                          label: l10n.t('sos_cancel_sos'),
                          child: Material(
                            color: Theme.of(context).cardColor,
                            borderRadius:
                                BorderRadius.circular(ThixPolicy.rMd),
                            child: InkWell(
                              onTap: _cancelSos,
                              borderRadius:
                                  BorderRadius.circular(ThixPolicy.rMd),
                              child: Container(
                                width: double.infinity,
                                padding: ThixPolicy.cardPadding,
                                decoration: BoxDecoration(
                                  borderRadius:
                                      BorderRadius.circular(ThixPolicy.rMd),
                                  border: Border.all(
                                    color: ThixPolicy.danger
                                        .withValues(alpha: 0.35),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.lock_outline,
                                      color: ThixPolicy.danger,
                                    ),
                                    const SizedBox(width: ThixPolicy.s12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            l10n.t('sos_cancel_sos'),
                                            style: ThixPolicy.bodyStyle
                                                .copyWith(
                                              fontWeight: ThixPolicy.bold,
                                              color: ThixPolicy.danger,
                                            ),
                                          ),
                                          Text(
                                            l10n.t('sos_pin_required'),
                                            style: ThixPolicy.captionStyle,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  List<String> _quickMessages(AppLocalizations l10n) => [
        l10n.t('sos_qm_help'),
        l10n.t('sos_qm_silent'),
        l10n.t('sos_qm_here'),
        l10n.t('sos_qm_injured'),
        l10n.t('sos_qm_followed'),
        l10n.t('sos_qm_locked'),
        l10n.t('sos_qm_call'),
        l10n.t('sos_qm_ok'),
      ];

  Widget _section(String title) {
    return Text(
      title,
      style: ThixPolicy.labelStyle.copyWith(
        fontWeight: ThixPolicy.bold,
        color: ThixPolicy.textSecondary,
        letterSpacing: 0.5,
      ),
    );
  }
}

// ============================================================================
// HEADER
// ============================================================================
class _Header extends StatelessWidget {
  const _Header({
    required this.publicId,
    required this.elapsed,
    required this.status,
    required this.onBack,
    required this.onEnd,
    this.camOn = false,
    this.onToggleCam,
  });

  final String publicId;
  final String elapsed;
  final SosStatus status;
  final VoidCallback onBack;
  final VoidCallback onEnd;
  final bool camOn;
  final VoidCallback? onToggleCam;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(4, 4, 8, 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            ThixPolicy.danger,
            ThixPolicy.danger.withValues(alpha: 0.6),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Semantics(
                button: true,
                label: l10n.t('common_back'),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white70),
                  onPressed: onBack,
                ),
              ),
              Expanded(
                child: Text(
                  l10n.t('sos_crisis_room'),
                  textAlign: TextAlign.center,
                  style: ThixPolicy.titleStyle.copyWith(
                    fontWeight: ThixPolicy.bold,
                    color: ThixPolicy.onBrand,
                  ),
                ),
              ),
              Semantics(
                button: true,
                label: l10n.t('sos_end'),
                child: TextButton(
                  onPressed: onEnd,
                  child: Text(
                    l10n.t('sos_end'),
                    style: ThixPolicy.bodyMediumStyle.copyWith(
                      color: Colors.white.withOpacity(0.8),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                publicId,
                style: ThixPolicy.bodyStyle.copyWith(
                  fontWeight: ThixPolicy.semiBold,
                  color: Colors.white70,
                ),
              ),
              const SizedBox(width: ThixPolicy.s16),
              const Icon(Icons.timer_outlined, size: 16, color: Colors.white54),
              const SizedBox(width: 4),
              Text(
                elapsed,
                style: ThixPolicy.bodyStyle.copyWith(
                  fontWeight: ThixPolicy.bold,
                  color: ThixPolicy.onBrand,
                ),
              ),
              const SizedBox(width: ThixPolicy.s12),
              Semantics(
                button: true,
                label: camOn ? l10n.t('sos_cam_off') : l10n.t('sos_cam_on'),
                child: InkWell(
                  onTap: onToggleCam,
                  child: Row(
                    children: [
                      Icon(
                        camOn ? Icons.videocam : Icons.videocam_off,
                        size: 16,
                        color: camOn ? Colors.white : Colors.white54,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        camOn ? 'LIVE' : 'CAM',
                        style: ThixPolicy.captionStyle.copyWith(
                          fontWeight: ThixPolicy.bold,
                          color: camOn ? Colors.white : Colors.white54,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            status.labelFr.toUpperCase(),
            style: ThixPolicy.captionStyle.copyWith(
              fontWeight: ThixPolicy.bold,
              color: Colors.white.withOpacity(0.8),
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// STATUS STRIP
// ============================================================================
class _StatusStrip extends StatelessWidget {
  const _StatusStrip({required this.incident, this.camOn = false});
  final SosIncident incident;
  final bool camOn;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      children: [
        _chip(
          context,
          Icons.location_on,
          l10n.t('sos_status_location'),
          incident.hasLocation
              ? l10n.t('sos_status_active')
              : l10n.t('sos_status_waiting'),
          incident.hasLocation,
        ),
        const SizedBox(width: ThixPolicy.s8),
        _chip(context, Icons.favorite, 'Heartbeat',
            l10n.t('sos_status_active'), true),
        const SizedBox(width: ThixPolicy.s8),
        _chip(
          context,
          Icons.videocam,
          l10n.t('sos_status_camera'),
          camOn ? 'LIVE' : 'OFF',
          camOn,
        ),
      ],
    );
  }

  Widget _chip(
      BuildContext context, IconData icon, String label, String value, bool on) {
    final color = on ? ThixPolicy.success : ThixPolicy.textMuted;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(ThixPolicy.rXs),
          border: Border.all(color: ThixPolicy.border),
        ),
        child: Column(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(height: 4),
            Text(label, style: ThixPolicy.microStyle),
            Text(
              value,
              style: ThixPolicy.microStyle.copyWith(
                fontWeight: ThixPolicy.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// LIVE MAP CARD
// ============================================================================
class _LiveMapCard extends StatelessWidget {
  const _LiveMapCard({required this.incident});
  final SosIncident incident;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final hasPos = incident.hasLocation &&
        incident.lastLat != null &&
        incident.lastLng != null;

    final lat = incident.lastLat ?? -6.80381;
    final lng = incident.lastLng ?? 39.26000;

    return Container(
      height: 220,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? ThixPolicy.border.withValues(alpha: 0.3)
            : ThixPolicy.surfaceStrong,
        borderRadius: BorderRadius.circular(ThixPolicy.rMd),
        border: Border.all(color: ThixPolicy.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.location_off, color: ThixPolicy.textMuted, size: 48),
                const SizedBox(height: ThixPolicy.s8),
                Text(
                  l10n.t('sos_map_disabled'),
                  textAlign: TextAlign.center,
                  style: ThixPolicy.captionStyle,
                ),
              ],
            ),
          ),
          if (hasPos)
            Positioned(
              left: 12,
              top: 12,
              right: 12,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(ThixPolicy.rXs),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.t('sos_current_position'),
                      style: ThixPolicy.captionStyle.copyWith(
                        fontWeight: ThixPolicy.semiBold,
                        color: Colors.white70,
                      ),
                    ),
                    Text(
                      '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}',
                      style: ThixPolicy.labelStyle.copyWith(
                        color: ThixPolicy.onBrand,
                      ),
                    ),
                    if (incident.lastLocationAt != null)
                      Text(
                        'MAJ ${_fmt(incident.lastLocationAt!)}',
                        style: ThixPolicy.microStyle.copyWith(
                          color: Colors.white54,
                        ),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _fmt(DateTime d) {
    final l = d.toLocal();
    return '${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}:${l.second.toString().padLeft(2, '0')}';
  }
}

// ============================================================================
// RESPONDER TILE — ✅ URL validée + initiale safe
// ============================================================================
class _ResponderTile extends StatelessWidget {
  const _ResponderTile({required this.contact, required this.onCall});
  final SosContact contact;
  final VoidCallback onCall;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final validPhoto = _CrisisValidators.isValidUrl(contact.photoUrl);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(ThixPolicy.rSm),
        border: Border.all(color: ThixPolicy.border),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: ThixPolicy.border,
            backgroundImage: validPhoto ? NetworkImage(contact.photoUrl!) : null,
            child: !validPhoto
                ? Text(
                    _CrisisValidators.safeInitial(contact.name),
                    style: ThixPolicy.bodyStyle.copyWith(
                        color: Theme.of(context).colorScheme.onSurface),
                  )
                : null,
          ),
          const SizedBox(width: ThixPolicy.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _CrisisValidators.sanitizeText(contact.name, maxLength: 60),
                  style: ThixPolicy.bodyStyle
                      .copyWith(fontWeight: ThixPolicy.semiBold),
                ),
                Text(
                  contact.thixId ??
                      (contact.available
                          ? l10n.t('sos_available')
                          : l10n.t('sos_unavailable')),
                  style: ThixPolicy.captionStyle
                      .copyWith(color: ThixPolicy.success),
                ),
              ],
            ),
          ),
          Semantics(
            button: true,
            label: '${l10n.t('sos_call')} ${contact.name}',
            child: IconButton(
              onPressed: onCall,
              icon: const Icon(Icons.phone, color: ThixPolicy.success),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// COM BUTTON
// ============================================================================
class _ComButton extends StatelessWidget {
  const _ComButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(ThixPolicy.rSm),
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            onTap();
          },
          borderRadius: BorderRadius.circular(ThixPolicy.rSm),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(ThixPolicy.rSm),
              border: Border.all(color: ThixPolicy.border),
            ),
            child: Column(
              children: [
                Icon(icon, color: color, size: 22),
                const SizedBox(height: 6),
                Text(
                  label,
                  style: ThixPolicy.captionStyle
                      .copyWith(fontWeight: ThixPolicy.semiBold),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// QUICK MSG
// ============================================================================
class _QuickMsg extends StatelessWidget {
  const _QuickMsg({
    required this.label,
    required this.onTap,
    this.sent = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool sent;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      enabled: !sent,
      child: Material(
        color: sent
            ? ThixPolicy.success.withValues(alpha: 0.15)
            : Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(ThixPolicy.rLg),
        child: InkWell(
          onTap: sent ? null : onTap,
          borderRadius: BorderRadius.circular(ThixPolicy.rLg),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(ThixPolicy.rLg),
              border: Border.all(
                color: sent
                    ? ThixPolicy.success.withValues(alpha: 0.4)
                    : ThixPolicy.border,
              ),
            ),
            child: Text(
              label,
              style: ThixPolicy.captionStyle.copyWith(
                fontWeight: ThixPolicy.semiBold,
                color: sent
                    ? ThixPolicy.success
                    : Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// SYSTEM ROW
// ============================================================================
class _SystemRow extends StatelessWidget {
  const _SystemRow({required this.incident});
  final SosIncident incident;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(ThixPolicy.rSm),
        border: Border.all(color: ThixPolicy.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.favorite, color: ThixPolicy.danger, size: 18),
          const SizedBox(width: ThixPolicy.s8),
          Text(
            'HEARTBEAT',
            style: ThixPolicy.labelStyle.copyWith(fontWeight: ThixPolicy.bold),
          ),
          const Spacer(),
          if (incident.batteryPct != null) ...[
            Icon(
              Icons.battery_std,
              size: 16,
              color: incident.batteryPct! < 20
                  ? ThixPolicy.danger
                  : ThixPolicy.success,
            ),
            const SizedBox(width: 4),
            Text(
              '${incident.batteryPct}%',
              style: ThixPolicy.bodyStyle,
            ),
          ] else
            Text(
              '${l10n.t('sos_circle')} ${incident.activeCircle}',
              style: ThixPolicy.bodySmallStyle,
            ),
        ],
      ),
    );
  }
}

// ============================================================================
// EVENT TILE — ✅ payloads sanitizés
// ============================================================================
class _EventTile extends StatelessWidget {
  const _EventTile({required this.event});
  final SosEvent event;

  String _label(AppLocalizations l10n) {
    final p = event.payload;
    final text = _CrisisValidators.sanitizeText(p?['text']?.toString());
    switch (event.type) {
      case 'CMD_INSTRUCT':
        return '📢 ${l10n.t('sos_ev_instruct')}: ${text.isNotEmpty ? text : l10n.t('sos_ev_instruction')}';
      case 'CMD_CAPTURE_PHOTO':
        return '📸 ${l10n.t('sos_ev_photo_requested')}';
      case 'CMD_CAPTURE_VIDEO':
        return '🎥 ${l10n.t('sos_ev_video_requested')} ${p?['seconds'] ?? 10}s';
      case 'CMD_CAPTURE_CLIP_10':
        return '🎥 ${l10n.t('sos_ev_clip_requested')}';
      case 'CMD_CAPTURE_AUDIO_START':
        return '🎤 ${l10n.t('sos_ev_mic_on')}';
      case 'CMD_CAPTURE_AUDIO_STOP':
        return '🎤 ${l10n.t('sos_ev_mic_off')}';
      case 'CMD_SURVEILLANCE_ON':
        return '🛰️ ${l10n.t('sos_ev_surveillance_on')}';
      case 'CMD_SURVEILLANCE_OFF':
        return '🛰️ ${l10n.t('sos_ev_surveillance_off')}';
      case 'EVIDENCE_PHOTO':
        return p?['posted_to_chat'] == true
            ? '📸 ${l10n.t('sos_ev_photo_sent')}'
            : '📸 ${l10n.t('sos_ev_photo_captured')}';
      case 'EVIDENCE_VIDEO':
        return p?['posted_to_chat'] == true
            ? '🎥 ${l10n.t('sos_ev_video_sent')}'
            : '🎥 ${l10n.t('sos_ev_video_captured')}';
      case 'EVIDENCE_AUDIO':
        return p?['posted_to_chat'] == true
            ? '🎤 ${l10n.t('sos_ev_audio_sent')}'
            : '🎤 ${l10n.t('sos_ev_audio_captured')}';
      case 'EVIDENCE_FAILED':
        return '⚠️ ${l10n.t('sos_ev_capture_failed')}';
      case 'QUICK_MESSAGE':
        return text.isNotEmpty ? text : event.type;
      case 'RESCUE_JOINED_CRISIS_ROOM':
        return '🛟 ${l10n.t('sos_ev_rescue_joined')}';
      case 'SOS_CREATED':
        return l10n.t('sos_ev_created');
      case 'SOS_STARTED':
        return l10n.t('sos_ev_started');
      default:
        return _CrisisValidators.sanitizeText(event.type, maxLength: 60);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final t = event.createdAt.toLocal();
    final time =
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:${t.second.toString().padLeft(2, '0')}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 52,
            child: Text(time, style: ThixPolicy.captionStyle),
          ),
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(top: 4, right: 10),
            decoration: const BoxDecoration(
              color: ThixPolicy.danger,
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: Text(
              _label(l10n),
              style: ThixPolicy.labelStyle
                  .copyWith(fontWeight: ThixPolicy.semiBold),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// EMPTY BOX
// ============================================================================
class _EmptyBox extends StatelessWidget {
  const _EmptyBox(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: ThixPolicy.cardPadding,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(ThixPolicy.rSm),
        border: Border.all(color: ThixPolicy.border),
      ),
      child: Text(text, style: ThixPolicy.bodySmallStyle),
    );
  }
}

// ============================================================================
// SKELETON LOADER — ✅ FIX P1
// ============================================================================
class _SkeletonLoader extends StatefulWidget {
  const _SkeletonLoader({this.compact = false});
  final bool compact;

  @override
  State<_SkeletonLoader> createState() => _SkeletonLoaderState();
}

class _SkeletonLoaderState extends State<_SkeletonLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Widget _box(double h, [double w = double.infinity]) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Opacity(
        opacity: 0.35 + 0.3 * _ctrl.value,
        child: Container(
          height: h,
          width: w,
          decoration: BoxDecoration(
            color: ThixPolicy.border,
            borderRadius: BorderRadius.circular(ThixPolicy.rSm),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.compact) {
      return Padding(
        padding: const EdgeInsets.all(ThixPolicy.s16),
        child: Column(
          children: [_box(16), const SizedBox(height: 8), _box(16)],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.all(ThixPolicy.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _box(64),
          const SizedBox(height: 16),
          _box(24, 140),
          const SizedBox(height: 12),
          _box(120),
          const SizedBox(height: 16),
          _box(24, 180),
          const SizedBox(height: 12),
          _box(56),
        ],
      ),
    );
  }
}

// ============================================================================
// ERROR STATE — ✅ FIX P0 : friendly + retry (pas de fuite d'info)
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
            const Icon(Icons.error_outline, color: ThixPolicy.danger, size: 40),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: ThixPolicy.bodyStyle,
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
                  backgroundColor: ThixPolicy.danger,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
