// lib/presentation/chat/call/call_page.dart
//
// ============================================================================
// CALL PAGE — v3 (fusionnée + corrigée)
// ✅ Grille vidéo multi-participants (remoteUids + peers)
// ✅ Modale « Ajouter à l'appel » : type d'appel dynamique, exclusions,
//    connexions acceptées uniquement, sync invitedUserIds (noms affichés)
// ============================================================================
import 'dart:async';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/l10n/app_localizations.dart';
import 'package:thix_id/models/chat/call_status.dart';
import 'package:thix_id/presentation/chat/call/call_ui_state.dart';
import 'package:thix_id/presentation/chat/call/providers/call_provider.dart';
import 'package:thix_id/presentation/chat/call/widgets/call_controls_panel.dart';
import 'package:thix_id/services/chat/call_service.dart';
import 'package:thix_id/presentation/chat/providers/chat_providers.dart'
    show supabaseClientProvider, supabaseUserIdProvider;

const double _kAvatarRadius = 64.0;
const double _kPipWidth = 100.0;
const double _kPipHeight = 150.0;
const Duration _kAutoCloseDelay = Duration(seconds: 4);

class CallPage extends ConsumerStatefulWidget {
  const CallPage({super.key});

  @override
  ConsumerState<CallPage> createState() => _CallPageState();
}

class _CallPageState extends ConsumerState<CallPage> {
  late final CallMediaService _media;
  Timer? _autoCloseTimer;
  bool _isHangingUp = false;
  bool _closed = false;
  bool _errorShown = false;
  Offset _pipPosition = const Offset(16, 100);

  @override
  void initState() {
    super.initState();
    _media = ref.read(callMediaServiceProvider);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final s = ref.read(callProvider);
      if (s.status == CallStatus.failed) _handleCallError(s.error);
    });
  }

  @override
  void dispose() {
    _autoCloseTimer?.cancel();
    super.dispose();
  }

  void _closePage() {
    if (_closed || !mounted) return;
    _closed = true;
    _autoCloseTimer?.cancel();

    final route = ModalRoute.of(context);
    if (route == null || !route.isActive) return;
    final nav = Navigator.of(context);
    if (route.isCurrent) {
      nav.pop();
    } else {
      nav.removeRoute(route);
    }
  }

  void _handleCallError(String? error) {
    if (_errorShown || !mounted) return;
    _errorShown = true;

    final l10n = AppLocalizations.of(context);
    final message = error ?? l10n.t('call_error_generic');
    HapticFeedback.heavyImpact();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          const Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
          const SizedBox(width: 12),
          Expanded(child: Text(message, style: const TextStyle(fontSize: 14))),
        ]),
        backgroundColor: ThixPolicy.danger,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );

    _autoCloseTimer?.cancel();
    _autoCloseTimer = Timer(_kAutoCloseDelay, _closePage);
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    final h = d.inHours;
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  String _getStatusLabel(CallState state, AppLocalizations l10n) {
    switch (state.status) {
      case CallStatus.idle:
      case CallStatus.ringing:
        return state.isCaller ? l10n.t('call_status_calling') : l10n.t('call_status_connecting');
      case CallStatus.accepted:
        return l10n.t('call_status_connecting');
      case CallStatus.ongoing:
        final count = state.remoteUids.length + 1;
        final time = _formatDuration(state.duration);
        return count > 2 ? '$count participants · $time' : time;
      case CallStatus.busy:
        return l10n.t('call_status_busy');
      case CallStatus.failed:
        return l10n.t('call_status_failed');
      default:
        return state.status.label;
    }
  }

  Future<void> _hangUp() async {
    if (_isHangingUp) return;
    setState(() => _isHangingUp = true);
    HapticFeedback.mediumImpact();

    try {
      await ref.read(callProvider.notifier).hangUp();
    } catch (_) {}
    _closePage();
  }

  void _toggleMute() => ref.read(callProvider.notifier).toggleMute();
  void _toggleVideo() => ref.read(callProvider.notifier).toggleVideo();
  void _switchCamera() => ref.read(callProvider.notifier).switchCamera();
  void _toggleSpeaker() => ref.read(callProvider.notifier).toggleSpeaker();
  void _minimize() => Navigator.maybePop(context);

  // ✅ Modale d'invitation : transmet le type d'appel + les IDs à exclure
  void _inviteParticipant() {
    HapticFeedback.selectionClick();
    final s = ref.read(callProvider);
    if (s.channelName == null || s.channelName!.isEmpty) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _InviteParticipantSheet(
        channelName: s.channelName!,
        callType: s.type,
        excludeIds: {
          ...s.invitedUserIds,
          if (s.remoteUserId != null) s.remoteUserId!,
        },
        onInvited: (name) {
          Navigator.pop(ctx);
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$name a été invité à rejoindre l\'appel.'),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    ref.listen<CallState>(callProvider, (prev, next) {
      if (!mounted) return;
      if (next.status == CallStatus.failed && prev?.status != CallStatus.failed) {
        _handleCallError(next.error);
      } else if (next.status == CallStatus.idle && prev != null && prev.status != CallStatus.idle) {
        _closePage();
      }
    });

    final state = ref.watch(callProvider);
    final engine = _media.engine;
    final engineReady = engine != null;

    final participantCount = state.remoteUids.length;

    final isSingleRemoteVideo = state.isVideo && participantCount == 1 && engineReady && !state.videoOff;
    final showLocalFull = state.isVideo && participantCount == 0 && !state.videoOff && engineReady;
    final showGrid = participantCount > 1;

    final statusLabel = _getStatusLabel(state, l10n);
    final displayName = showGrid
        ? 'Appel de groupe'
        : (state.remoteName ?? l10n.t('call_unknown_contact'));

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              ThixPolicy.primaryDeep,
              ThixPolicy.primary.withOpacity(0.8),
              ThixPolicy.surface,
            ],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              _buildMainArea(state, engine, showGrid, isSingleRemoteVideo, showLocalFull, l10n),

              Positioned.fill(
                child: IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.3),
                          Colors.transparent,
                          Colors.black.withOpacity(0.6),
                        ],
                        stops: const [0.0, 0.4, 1.0],
                      ),
                    ),
                  ),
                ),
              ),

              _buildHeader(displayName, statusLabel, state),

              // Bouton d'ajout de participant (visible seulement appel actif)
              if (state.status == CallStatus.ongoing || state.status == CallStatus.accepted)
                Positioned(
                  top: 80,
                  right: 16,
                  child: FloatingActionButton.small(
                    heroTag: 'add_participant',
                    backgroundColor: Colors.white.withOpacity(0.2),
                    elevation: 0,
                    onPressed: _inviteParticipant,
                    child: const Icon(Icons.person_add_alt_1, color: Colors.white, size: 20),
                  ),
                ),

              if (state.isVideo && !state.videoOff && engineReady && !showLocalFull)
                _buildDraggablePip(engine),

              _buildStatusIndicators(state),

              CallControlsPanel(
                state: state,
                l10n: l10n,
                onToggleMute: _toggleMute,
                onToggleVideo: _toggleVideo,
                onSwitchCamera: _switchCamera,
                onToggleSpeaker: _toggleSpeaker,
                onHangUp: _hangUp,
                isHangingUp: _isHangingUp,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMainArea(
    CallState state,
    RtcEngine? engine,
    bool showGrid,
    bool isSingleRemoteVideo,
    bool showLocalFull,
    AppLocalizations l10n,
  ) {
    if (showGrid) {
      return Positioned.fill(
        child: Padding(
          padding: const EdgeInsets.only(top: 130, bottom: 180, left: 16, right: 16),
          child: GridView.builder(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: state.remoteUids.length > 4 ? 3 : 2,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 0.75,
            ),
            itemCount: state.remoteUids.length,
            itemBuilder: (context, index) {
              final uid = state.remoteUids[index];
              final peer = state.peers[uid];

              if (state.isVideo && engine != null) {
                return ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      AgoraVideoView(
                        key: ValueKey('remote_grid_$uid'),
                        controller: VideoViewController.remote(
                          rtcEngine: engine,
                          canvas: VideoCanvas(uid: uid),
                          connection: RtcConnection(channelId: state.channelName!),
                        ),
                      ),
                      Positioned(
                        bottom: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            peer?.name ?? 'Participant',
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ),
                      )
                    ],
                  ),
                );
              } else {
                return Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: Colors.white.withOpacity(0.2),
                        backgroundImage: peer?.avatarUrl != null ? NetworkImage(peer!.avatarUrl!) : null,
                        child: peer?.avatarUrl == null ? const Icon(Icons.person, size: 40, color: Colors.white) : null,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        peer?.name ?? 'Participant',
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                );
              }
            },
          ),
        ),
      );
    }

    if (showLocalFull && engine != null) {
      return Positioned.fill(
        child: RepaintBoundary(
          child: AgoraVideoView(
            key: const ValueKey('local_full'),
            controller: VideoViewController(
              rtcEngine: engine,
              canvas: const VideoCanvas(uid: 0),
            ),
          ),
        ),
      );
    }

    if (isSingleRemoteVideo && engine != null) {
      return Positioned.fill(
        child: RepaintBoundary(
          child: AgoraVideoView(
            key: ValueKey('remote_single_${state.remoteUids.first}'),
            controller: VideoViewController.remote(
              rtcEngine: engine,
              canvas: VideoCanvas(uid: state.remoteUids.first),
              connection: RtcConnection(channelId: state.channelName!),
            ),
          ),
        ),
      );
    }

    return _buildAvatarFallback(state, l10n);
  }

  Widget _buildAvatarFallback(CallState state, AppLocalizations l10n) {
    final remoteName = state.remoteName ?? l10n.t('call_unknown_contact');

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 20, spreadRadius: 5),
              ],
            ),
            child: CircleAvatar(
              radius: _kAvatarRadius,
              backgroundColor: Colors.white,
              backgroundImage: state.remoteAvatar != null ? NetworkImage(state.remoteAvatar!) : null,
              child: state.remoteAvatar == null
                  ? Icon(Icons.person, size: _kAvatarRadius * 0.8, color: ThixPolicy.primary)
                  : null,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            remoteName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _getStatusLabel(state, l10n),
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(String displayName, String statusLabel, CallState state) {
    return Positioned(
      top: 16,
      left: 16,
      right: 16,
      child: Row(
        children: [
          Material(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: _minimize,
              borderRadius: BorderRadius.circular(12),
              child: const Padding(
                padding: EdgeInsets.all(8),
                child: Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white, size: 28),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    shadows: [Shadow(color: Colors.black26, blurRadius: 4)],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  statusLabel,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: state.isVideo ? Colors.blue.withOpacity(0.8) : Colors.green.withOpacity(0.8),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(state.isVideo ? Icons.videocam_rounded : Icons.phone_rounded,
                    color: Colors.white, size: 16),
                const SizedBox(width: 4),
                Text(
                  state.isVideo ? 'Vidéo' : 'Audio',
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDraggablePip(RtcEngine engine) {
    return Positioned(
      left: _pipPosition.dx,
      top: _pipPosition.dy,
      child: GestureDetector(
        onPanUpdate: (details) {
          final size = MediaQuery.of(context).size;
          final maxX = (size.width - _kPipWidth).clamp(0.0, double.infinity).toDouble();
          final maxY = (size.height - _kPipHeight - 140).clamp(0.0, double.infinity).toDouble();
          setState(() {
            _pipPosition = Offset(
              (_pipPosition.dx + details.delta.dx).clamp(0.0, maxX).toDouble(),
              (_pipPosition.dy + details.delta.dy).clamp(0.0, maxY).toDouble(),
            );
          });
        },
        child: Container(
          width: _kPipWidth,
          height: _kPipHeight,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 12, spreadRadius: 2),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              fit: StackFit.expand,
              children: [
                RepaintBoundary(
                  child: AgoraVideoView(
                    key: const ValueKey('local_pip'),
                    controller: VideoViewController(
                      rtcEngine: engine,
                      canvas: const VideoCanvas(uid: 0),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 4,
                  left: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'Vous',
                      style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w500),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusIndicators(CallState state) {
    return Positioned(
      top: 100,
      left: 16,
      child: Column(
        children: [
          if (state.muted) _buildStatusBadge(Icons.mic_off_rounded, 'Muet', Colors.orange),
          if (state.videoOff) _buildStatusBadge(Icons.videocam_off_rounded, 'Vidéo OFF', Colors.red),
          if (state.speakerOn) _buildStatusBadge(Icons.volume_up_rounded, 'Haut-parleur', Colors.blue),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(IconData icon, String label, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.9),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8)],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// MODALE D'INVITATION (v3 — corrigée & équilibrée)
// ============================================================================

class _InviteParticipantSheet extends ConsumerStatefulWidget {
  final String channelName;
  final CallType callType;
  final Set<String> excludeIds; // déjà invités / déjà dans l'appel
  final void Function(String name) onInvited;

  const _InviteParticipantSheet({
    required this.channelName,
    required this.callType,
    required this.excludeIds,
    required this.onInvited,
  });

  @override
  ConsumerState<_InviteParticipantSheet> createState() => _InviteParticipantSheetState();
}

class _InviteParticipantSheetState extends ConsumerState<_InviteParticipantSheet> {
  final _ctrl = TextEditingController();
  List<Map<String, dynamic>> _results = [];
  bool _loading = false;
  Timer? _searchDebounce;
  String? _invitingId;

  @override
  void initState() {
    super.initState();
    _search('');
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  SupabaseClient get _db => ref.read(supabaseClientProvider);
  String? get _myId => ref.read(supabaseUserIdProvider);

  Future<void> _search(String q) async {
    final query = q.trim().toLowerCase();
    final myId = _myId;
    if (myId == null || myId.isEmpty) return;

    setState(() => _loading = true);

    try {
      // ✅ Connexions de l'utilisateur (tous statuts, filtrés côté client)
      final rows = await _db
          .from('connections')
          .select('user1_id, user2_id, status')
          .or('user1_id.eq.$myId,user2_id.eq.$myId');

      final peerIds = <String>{};
      for (final r in (rows as List)) {
        final m = Map<String, dynamic>.from(r as Map);
        // ✅ Ignorer les connexions non acceptées / rejetées
        final st = '${m['status'] ?? ''}'.toLowerCase();
        if (st == 'pending' || st == 'rejected' || st == 'cancelled' || st == 'canceled' || st == 'blocked') {
          continue;
        }
        final u1 = '${m['user1_id']}';
        final u2 = '${m['user2_id']}';
        if (u1 == myId && u2.isNotEmpty) peerIds.add(u2);
        if (u2 == myId && u1.isNotEmpty) peerIds.add(u1);
      }

      // ✅ Retirer les personnes déjà invitées / déjà dans l'appel
      peerIds.removeAll(widget.excludeIds);

      if (peerIds.isEmpty) {
        if (mounted) setState(() { _results = []; _loading = false; });
        return;
      }

      final profiles = await _db
          .from('profiles')
          .select('id, display_name, full_name, avatar_url')
          .inFilter('id', peerIds.toList());

      var list = (profiles as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();

      if (query.isNotEmpty) {
        list = list.where((p) {
          final name = '${p['display_name'] ?? p['full_name'] ?? ''}'.toLowerCase();
          return name.contains(query);
        }).toList();
      }

      if (mounted) {
        setState(() {
          _results = list;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('[InviteSheet] ❌ Search failed: $e');
      if (mounted) setState(() { _results = []; _loading = false; });
    }
  }

  void _debouncedSearch(String q) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () => _search(q));
  }

  // ✅ CORRIGÉ : type dynamique + myId sûr + sync invitedUserIds
  Future<void> _sendInvite(String userId, String name) async {
    if (_invitingId != null) return;
    final myId = _myId;
    if (myId == null || myId.isEmpty || userId.isEmpty || userId == myId) return;

    setState(() => _invitingId = userId);

    try {
      await _db.from('call_invites').insert({
        'channel_name': widget.channelName,
        'caller_id': myId,
        'callee_id': userId,
        'status': 'ringing',
        'call_type': widget.callType == CallType.video ? 'video' : 'audio', // ✅ dynamique
        'is_group': true,
      });

      // ✅ Le provider connaît l'invité → son nom s'affichera dans la grille
      ref.read(callProvider.notifier).addInvitedUser(userId);

      widget.onInvited(name);
    } catch (e) {
      debugPrint('[InviteSheet] ❌ Invite failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erreur lors de l\'invitation')),
        );
      }
    } finally {
      if (mounted) setState(() => _invitingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: ThixPolicy.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Padding(
        padding: EdgeInsets.only(bottom: bottom),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: ThixPolicy.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
              child: Text(
                'Ajouter à l\'appel',
                style: ThixPolicy.titleStyle.copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: 20,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: TextField(
                controller: _ctrl,
                autofocus: true,
                onChanged: _debouncedSearch,
                decoration: InputDecoration(
                  hintText: 'Rechercher un contact...',
                  prefixIcon: Icon(Icons.search_rounded, color: ThixPolicy.textMuted),
                  filled: true,
                  fillColor: ThixPolicy.surfaceSoft,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            if (_loading) const LinearProgressIndicator(),
            Expanded(
              child: _results.isEmpty && !_loading
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.people_outline_rounded, size: 64, color: ThixPolicy.textMuted.withOpacity(0.4)),
                          const SizedBox(height: 16),
                          Text(
                            'Aucun contact à inviter',
                            style: ThixPolicy.bodyStyle.copyWith(
                              color: ThixPolicy.textMuted,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      itemCount: _results.length,
                      separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
                      itemBuilder: (context, i) {
                        final p = _results[i];
                        final id = '${p['id'] ?? ''}';
                        final name = '${p['display_name'] ?? p['full_name'] ?? 'Contact'}';
                        final avatar = p['avatar_url']?.toString();
                        final isInviting = _invitingId == id;

                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: ThixPolicy.surfaceSoft,
                            backgroundImage: avatar != null && avatar.isNotEmpty
                                ? NetworkImage(avatar)
                                : null,
                            child: avatar == null || avatar.isEmpty
                                ? Text(name.isEmpty ? '?' : name[0].toUpperCase(),
                                    style: const TextStyle(fontWeight: FontWeight.bold))
                                : null,
                          ),
                          title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
                          trailing: isInviting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : IconButton(
                                  icon: const Icon(Icons.person_add_alt_1, color: ThixPolicy.primary),
                                  onPressed: () => _sendInvite(id, name),
                                  tooltip: 'Inviter',
                                ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
