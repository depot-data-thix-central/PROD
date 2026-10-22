// lib/presentation/chat/call/call_page.dart
//
// ============================================================================
// CALL PAGE — v3.0 (Support Appels de Groupe)
// ============================================================================
// Nouveau : Gestion de plusieurs participants (remoteUids).
//           Affichage en grille si > 1 participant.
//           Bouton pour inviter un participant.
// ============================================================================

import 'dart:async';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/l10n/app_localizations.dart';
import 'package:thix_id/models/chat/call_status.dart';
import 'package:thix_id/presentation/chat/call/call_ui_state.dart';
import 'package:thix_id/presentation/chat/call/providers/call_provider.dart';
import 'package:thix_id/presentation/chat/call/widgets/call_controls_panel.dart';
import 'package:thix_id/services/chat/call_service.dart';

// ============================================================================
// CONSTANTS
// ============================================================================
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
    markCallPageOpened();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final s = ref.read(callProvider);
      if (s.status == CallStatus.failed) _handleCallError(s.error);
    });
  }

  @override
  void dispose() {
    _autoCloseTimer?.cancel();
    markCallPageClosed();
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
        final count = state.remoteUids.length + 1; // +1 pour soi-même
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

  void _toggleMute() {
    HapticFeedback.selectionClick();
    ref.read(callProvider.notifier).toggleMute();
  }

  void _toggleVideo() {
    HapticFeedback.selectionClick();
    ref.read(callProvider.notifier).toggleVideo();
  }

  void _switchCamera() {
    HapticFeedback.selectionClick();
    ref.read(callProvider.notifier).switchCamera();
  }

  void _toggleSpeaker() {
    HapticFeedback.selectionClick();
    ref.read(callProvider.notifier).toggleSpeaker();
  }

  void _minimize() {
    HapticFeedback.selectionClick();
    Navigator.maybePop(context);
  }

  // ✅ NOUVEAU : Bouton pour ajouter un participant
  void _inviteParticipant() {
    HapticFeedback.selectionClick();
    // TODO: Ouvrir une modale pour choisir un contact
    // et faire un insert dans Supabase (table call_invites) avec is_group = true
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Fonctionnalité : Choisir un contact à inviter')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    ref.listen<CallState>(callProvider, (prev, next) {
      if (!mounted) return;
      if (next.status == CallStatus.failed && prev?.status != CallStatus.failed) {
        _handleCallError(next.error);
      } else if (next.status == CallStatus.idle &&
          prev != null &&
          prev.status != CallStatus.idle) {
        _closePage();
      }
    });

    final state = ref.watch(callProvider);
    final engine = _media.engine;
    final engineReady = engine != null;
    final channelId = state.channelName;
    final hasChannel = channelId != null && channelId.isNotEmpty;

    final participantCount = state.remoteUids.length;
    
    // Logique d'affichage
    final isSingleRemoteVideo = state.isVideo && participantCount == 1 && engineReady && !state.videoOff;
    final showLocalFull = state.isVideo && participantCount == 0 && !state.videoOff && engineReady;
    final showGrid = participantCount > 1; // Si plusieurs personnes, on affiche la grille

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
              // 1. Affichage principal
              _buildMainArea(state, engine, showGrid, isSingleRemoteVideo, showLocalFull, l10n),
              
              // 2. Overlay sombre pour lisibilité
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
              
              // 3. Header
              _buildHeader(displayName, statusLabel, state),
              
              // 4. Bouton "Ajouter un participant" (en haut à droite)
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

              // 5. PIP Local (si vidéo et pas déjà en plein écran)
              if (state.isVideo && !state.videoOff && engineReady && !showLocalFull) 
                _buildDraggablePip(engine),

              // 6. Indicateurs (Muet, etc.)
              _buildStatusIndicators(state),
              
              // 7. Contrôles
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

  // ==========================================================================
  // UI BUILDERS
  // ==========================================================================

  Widget _buildMainArea(
    CallState state, 
    RtcEngine? engine, 
    bool showGrid, 
    bool isSingleRemoteVideo, 
    bool showLocalFull,
    AppLocalizations l10n,
  ) {
    if (showGrid) {
      // ✅ Affichage en Grille (Appel de groupe)
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
              if (state.isVideo && engine != null) {
                return ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: AgoraVideoView(
                    key: ValueKey('remote_grid_$uid'),
                    controller: VideoViewController.remote(
                      rtcEngine: engine,
                      canvas: VideoCanvas(uid: uid),
                      connection: RtcConnection(channelId: state.channelName!),
                    ),
                  ),
                );
              } else {
                return Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1), 
                    borderRadius: BorderRadius.circular(16)
                  ),
                  child: const Center(
                    child: Icon(Icons.person, size: 50, color: Colors.white54)
                  ),
                );
              }
            },
          ),
        ),
      );
    }

    if (showLocalFull && engine != null) {
      // On est seul, on affiche notre vidéo en grand
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
      // 1 seul interlocuteur en vidéo, plein écran
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

    // Fallback Avatar (Appel audio 1-1)
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
          Semantics(
            button: true,
            label: 'Réduire l’appel',
            child: Material(
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
