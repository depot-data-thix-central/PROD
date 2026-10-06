// lib/presentation/chat/call/call_page.dart
//
// ============================================================================
// CALL PAGE — Production Enterprise v2.0
// ============================================================================
//
// Écran d'appel en cours avec contrôles audio/vidéo.
// Utilise CallControlsPanel pour une architecture modulaire.
// ============================================================================

import 'dart:async';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/l10n/app_localizations.dart';
import 'package:thix_id/models/chat/call_status.dart';
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

// ============================================================================
// CALL PAGE
// ============================================================================

class CallPage extends ConsumerStatefulWidget {
  const CallPage({super.key});

  @override
  ConsumerState<CallPage> createState() => _CallPageState();
}

class _CallPageState extends ConsumerState<CallPage> {
  late final CallMediaService _media;
  Timer? _autoCloseTimer;
  bool _isHangingUp = false;
  Offset _pipPosition = const Offset(16, 100);

  @override
  void initState() {
    super.initState();
    _media = ref.read(callMediaServiceProvider);
    ref.listen<CallState>(callProvider, _handleStateChange);
    debugPrint('[CallPage] 🚀 Initialized');
  }

  @override
  void dispose() {
    _autoCloseTimer?.cancel();
    debugPrint('[CallPage] 👋 Disposed');
    super.dispose();
  }

  void _handleStateChange(CallState? previous, CallState next) {
    if (!mounted) return;
    if (next.status == CallStatus.failed && previous?.status != CallStatus.failed) {
      _handleCallError(next.error);
    }
    if (next.status == CallStatus.ongoing) {
      _autoCloseTimer?.cancel();
    }
  }

  void _handleCallError(String? error) {
    final l10n = AppLocalizations.of(context);
    final message = error ?? l10n.t('call_error_generic');
    debugPrint('[CallPage] ❌ Call failed: $message');
    HapticFeedback.heavyImpact();

    if (mounted) {
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
    }

    _autoCloseTimer?.cancel();
    _autoCloseTimer = Timer(_kAutoCloseDelay, () {
      if (mounted) Navigator.of(context).pop();
    });
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    final h = d.inHours;
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  String _getStatusLabel(CallState state, AppLocalizations l10n) {
    return switch (state.status) {
      CallStatus.ringing => state.isCaller 
          ? l10n.t('call_status_calling') 
          : l10n.t('call_status_connecting'),
      CallStatus.accepted => l10n.t('call_status_connecting'),
      CallStatus.ongoing => _formatDuration(state.duration),
      CallStatus.busy => l10n.t('call_status_busy'),
      CallStatus.failed => l10n.t('call_status_failed'),
      _ => state.status.label,
    };
  }

  Future<void> _hangUp() async {
    if (_isHangingUp) return;
    setState(() => _isHangingUp = true);
    HapticFeedback.mediumImpact();
    
    try {
      await ref.read(callProvider.notifier).hangUp();
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _isHangingUp = false);
        Navigator.pop(context);
      }
    }
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(callProvider);
    final engine = _media.engine;
    final engineReady = engine != null;
    final channelId = state.channelName;
    final hasChannel = channelId != null && channelId.isNotEmpty;

    final showRemote = state.isVideo &&
        state.remoteUid != null &&
        engineReady &&
        hasChannel;

    final showLocalFull = state.isVideo && !state.videoOff && engineReady && !showRemote;
    final statusLabel = _getStatusLabel(state, l10n);
    final remoteName = state.remoteName ?? l10n.t('call_unknown_contact');

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
              _buildBackground(state, engine, showRemote, showLocalFull, l10n),
              
              Positioned.fill(
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

              _buildHeader(remoteName, statusLabel, state),

              if (showRemote && !state.videoOff && engineReady)
                _buildDraggablePip(engine),

              _buildStatusIndicators(state),

              // ✅ Widget modulaire pour les contrôles
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

  Widget _buildBackground(
    CallState state,
    RtcEngine? engine,
    bool showRemote,
    bool showLocalFull,
    AppLocalizations l10n,
  ) {
    if (showRemote && engine != null) {
      return Positioned.fill(
        child: RepaintBoundary(
          child: AgoraVideoView(
            controller: VideoViewController.remote(
              rtcEngine: engine,
              canvas: VideoCanvas(uid: state.remoteUid),
              connection: RtcConnection(channelId: state.channelName!),
            ),
          ),
        ),
      );
    }

    if (showLocalFull && engine != null) {
      return Positioned.fill(
        child: RepaintBoundary(
          child: AgoraVideoView(
            controller: VideoViewController(
              rtcEngine: engine,
              canvas: const VideoCanvas(uid: 0),
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
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: CircleAvatar(
              radius: _kAvatarRadius,
              backgroundColor: Colors.white,
              backgroundImage: state.remoteAvatar != null
                  ? NetworkImage(state.remoteAvatar!)
                  : null,
              child: state.remoteAvatar == null
                  ? Icon(
                      Icons.person,
                      size: _kAvatarRadius * 0.8,
                      color: ThixPolicy.primary,
                    )
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
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(String remoteName, String statusLabel, CallState state) {
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
              onTap: () => Navigator.pop(context),
              borderRadius: BorderRadius.circular(12),
              child: const Padding(
                padding: EdgeInsets.all(8),
                child: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: Colors.white,
                  size: 28,
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
                  remoteName,
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
              color: state.isVideo 
                  ? Colors.blue.withOpacity(0.8) 
                  : Colors.green.withOpacity(0.8),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  state.isVideo ? Icons.videocam_rounded : Icons.phone_rounded,
                  color: Colors.white,
                  size: 16,
                ),
                const SizedBox(width: 4),
                Text(
                  state.isVideo ? 'Vidéo' : 'Audio',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
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
          setState(() {
            _pipPosition = Offset(
              _pipPosition.dx + details.delta.dx,
              _pipPosition.dy + details.delta.dy,
            );
          });
        },
        child: Container(
          width: _kPipWidth,
          height: _kPipHeight,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.4),
                blurRadius: 12,
                spreadRadius: 2,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              fit: StackFit.expand,
              children: [
                RepaintBoundary(
                  child: AgoraVideoView(
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
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
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
      right: 16,
      child: Column(
        children: [
          if (state.muted)
            _buildStatusBadge(Icons.mic_off_rounded, 'Muet', Colors.orange),
          if (state.videoOff)
            _buildStatusBadge(Icons.videocam_off_rounded, 'Vidéo OFF', Colors.red),
          if (state.speakerOn)
            _buildStatusBadge(Icons.volume_up_rounded, 'Haut-parleur', Colors.blue),
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
        boxShadow: [
          BoxShadow(color: Colors.black26, blurRadius: 8),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
