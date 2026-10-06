// lib/presentation/chat/call/call_page.dart
//
// ============================================================================
// CALL PAGE — Production Enterprise v2.0
// ============================================================================
//
// Design moderne aligné avec THIX Chat UI
// ============================================================================

import 'dart:async';
import 'dart:math';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/l10n/app_localizations.dart';
import 'package:thix_id/models/chat/call_status.dart';
import 'package:thix_id/presentation/chat/call/providers/call_provider.dart';
import 'package:thix_id/services/chat/call_service.dart';

// ============================================================================
// CONSTANTS
// ============================================================================
const double _kAvatarRadius = 64.0;
const double _kPipWidth = 100.0;
const double _kPipHeight = 150.0;
const double _kButtonSize = 60.0;
const double _kLargeButtonSize = 72.0;
const Duration _kAutoCloseDelay = Duration(seconds: 4);

// ============================================================================
// CALL PAGE
// ============================================================================

class CallPage extends ConsumerStatefulWidget {
  const CallPage({super.key});

  @override
  ConsumerState<CallPage> createState() => _CallPageState();
}

class _CallPageState extends ConsumerState<CallPage>
    with SingleTickerProviderStateMixin {
  late final CallMediaService _media;
  Timer? _autoCloseTimer;
  bool _isHangingUp = false;
  bool _showOptions = false;
  
  // Position du PiP (draggable)
  Offset _pipPosition = const Offset(16, 100);
  
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _media = ref.read(callMediaServiceProvider);
    ref.listen<CallState>(callProvider, _handleStateChange);
    
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    
    _animationController.forward();
    debugPrint('[CallPage]  Initialized');
  }

  @override
  void dispose() {
    _autoCloseTimer?.cancel();
    _animationController.dispose();
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
      if (mounted) {
        Navigator.of(context).pop();
      }
    });
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    final h = d.inHours;
    if (h > 0) return '$h:$m:$s';
    return '$m:$s';
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
      final notifier = ref.read(callProvider.notifier);
      await notifier.hangUp();
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

  void _toggleOptions() {
    setState(() => _showOptions = !_showOptions);
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
              // Background vidéo/avatar
              _buildBackground(state, engine, showRemote, showLocalFull, l10n),
              
              // Overlay gradient pour meilleure lisibilité
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.3),
                        Colors.transparent,
                        Colors.black.withOpacity(0.5),
                      ],
                      stops: const [0.0, 0.4, 1.0],
                    ),
                  ),
                ),
              ),

              // Header avec informations
              _buildHeader(remoteName, statusLabel, state),

              // PiP draggable
              if (showRemote && !state.videoOff && engineReady)
                _buildDraggablePip(engine),

              // Indicateurs de statut (mute, speaker)
              _buildStatusIndicators(state),

              // Contrôles principaux
              _buildMainControls(state, l10n),

              // Options avancées (bottom sheet)
              if (_showOptions) _buildOptionsSheet(l10n, state),
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
          // Avatar avec badge de statut
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
          
          // Nom
          Text(
            remoteName,
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          
          // Statut
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _getStatusLabel(state, l10n),
              style: TextStyle(
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
          // Bouton retour
          Material(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: () => Navigator.pop(context),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          
          // Informations
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  remoteName,
                  style: TextStyle(
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
          
          // Badge vidéo/audio
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
                  style: TextStyle(
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
                // Indicateur "Vous"
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
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainControls(CallState state, AppLocalizations l10n) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 40,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Rangée principale de contrôles
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildControlButton(
                icon: state.muted ? Icons.mic_off_rounded : Icons.mic_rounded,
                label: state.muted ? l10n.t('call_unmute') : l10n.t('call_mute'),
                onTap: _isHangingUp ? null : _toggleMute,
                isActive: state.muted,
                color: state.muted ? Colors.orange : Colors.white,
              ),
              
              if (state.isVideo)
                _buildControlButton(
                  icon: state.videoOff 
                      ? Icons.videocam_off_rounded 
                      : Icons.videocam_rounded,
                  label: state.videoOff 
                      ? l10n.t('call_camera') 
                      : l10n.t('call_camera'),
                  onTap: _isHangingUp ? null : _toggleVideo,
                  isActive: state.videoOff,
                  color: state.videoOff ? Colors.red : Colors.white,
                ),
              
              // Bouton raccrocher (plus grand)
              _buildHangUpButton(),
              
              if (state.isVideo)
                _buildControlButton(
                  icon: Icons.cameraswitch_rounded,
                  label: l10n.t('call_flip_camera'),
                  onTap: _isHangingUp ? null : _switchCamera,
                  isActive: false,
                  color: Colors.white,
                ),
              
              _buildControlButton(
                icon: state.speakerOn 
                    ? Icons.volume_up_rounded 
                    : Icons.volume_off_rounded,
                label: l10n.t('call_speaker'),
                onTap: _isHangingUp ? null : _toggleSpeaker,
                isActive: state.speakerOn,
                color: state.speakerOn ? Colors.blue : Colors.white,
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Bouton options additionnelles
          TextButton.icon(
            onPressed: _toggleOptions,
            icon: Icon(
              _showOptions 
                  ? Icons.keyboard_arrow_up_rounded 
                  : Icons.keyboard_arrow_down_rounded,
              color: Colors.white.withOpacity(0.8),
            ),
            label: Text(
              _showOptions ? 'Masquer options' : 'Plus d\'options',
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
    required bool isActive,
    required Color color,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: isActive ? color.withOpacity(0.3) : Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(_kButtonSize / 2),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(_kButtonSize / 2),
            child: Container(
              width: _kButtonSize,
              height: _kButtonSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isActive ? color : Colors.white.withOpacity(0.5),
                  width: 2,
                ),
              ),
              child: Icon(
                icon,
                color: isActive ? color : Colors.white,
                size: 28,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
          maxLines: 1,
        ),
      ],
    );
  }

  Widget _buildHangUpButton() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: ThixPolicy.danger,
          elevation: 8,
          shadowColor: ThixPolicy.danger.withOpacity(0.4),
          borderRadius: BorderRadius.circular(_kLargeButtonSize / 2),
          child: InkWell(
            onTap: _isHangingUp ? null : _hangUp,
            borderRadius: BorderRadius.circular(_kLargeButtonSize / 2),
            child: Container(
              width: _kLargeButtonSize,
              height: _kLargeButtonSize,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Colors.redAccent, Colors.red],
                ),
              ),
              child: Icon(
                Icons.call_end_rounded,
                color: Colors.white,
                size: 36,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Raccrocher',
          style: TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildOptionsSheet(AppLocalizations l10n, CallState state) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              
              // Options grid
              Wrap(
                spacing: 16,
                runSpacing: 16,
                alignment: WrapAlignment.center,
                children: [
                  _buildOptionItem(
                    icon: Icons.bluetooth_rounded,
                    label: 'Bluetooth',
                    onTap: () {
                      // TODO: Implement Bluetooth selection
                    },
                  ),
                  _buildOptionItem(
                    icon: Icons.record_voice_over_rounded,
                    label: 'Voix uniquement',
                    onTap: () {
                      // TODO: Implement voice mode
                    },
                  ),
                  _buildOptionItem(
                    icon: Icons.settings_rounded,
                    label: 'Paramètres',
                    onTap: () {
                      // TODO: Open call settings
                    },
                  ),
                  _buildOptionItem(
                    icon: Icons.report_problem_rounded,
                    label: 'Signaler',
                    onTap: () {
                      // TODO: Report call issue
                    },
                    color: Colors.orange,
                  ),
                ],
              ),
              
              const SizedBox(height: 24),
              
              // Qualité réseau
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.signal_cellular_alt_rounded,
                      color: Colors.green,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Qualité de l\'appel',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            'Excellente - 45 ms',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOptionItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 80,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: (color ?? ThixPolicy.primary).withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: color ?? ThixPolicy.primary,
              size: 28,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: color ?? ThixPolicy.primary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
