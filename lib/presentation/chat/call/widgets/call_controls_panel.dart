// lib/presentation/chat/call/widgets/call_controls_panel.dart
//
// ============================================================================
// CALL CONTROLS PANEL — v2.1
// ============================================================================
// FIX v2.1 : textes de secours si une clé l10n est absente (plus de
//            « call_mute » affiché à l'écran)
// FIX v2.1 : libellés à largeur fixe (plus de débordement à 5 boutons)
// FIX v2.1 : carte « Qualité de la connexion » fictive retirée
// FIX v2.1 : options sans action → message « Bientôt disponible »
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/l10n/app_localizations.dart';
import 'package:thix_id/presentation/chat/call/providers/call_provider.dart';

// ============================================================================
// CONSTANTS
// ============================================================================
const double _kButtonSize = 60.0;
const double _kLargeButtonSize = 72.0;
const double _kLabelWidth = 68.0;

/// Traduction avec texte de secours si la clé est absente du fichier l10n.
String _t(AppLocalizations l10n, String key, String fallback) {
  try {
    final v = l10n.t(key);
    if (v.trim().isEmpty || v == key) return fallback;
    return v;
  } catch (_) {
    return fallback;
  }
}

// ============================================================================
// CALL CONTROLS PANEL
// ============================================================================

class CallControlsPanel extends StatefulWidget {
  final CallState state;
  final AppLocalizations l10n;
  final VoidCallback onToggleMute;
  final VoidCallback onToggleVideo;
  final VoidCallback onSwitchCamera;
  final VoidCallback onToggleSpeaker;
  final VoidCallback onHangUp;
  final bool isHangingUp;

  const CallControlsPanel({
    super.key,
    required this.state,
    required this.l10n,
    required this.onToggleMute,
    required this.onToggleVideo,
    required this.onSwitchCamera,
    required this.onToggleSpeaker,
    required this.onHangUp,
    required this.isHangingUp,
  });

  @override
  State<CallControlsPanel> createState() => _CallControlsPanelState();
}

class _CallControlsPanelState extends State<CallControlsPanel>
    with SingleTickerProviderStateMixin {
  bool _showOptions = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggleOptions() {
    HapticFeedback.selectionClick();
    setState(() {
      _showOptions = !_showOptions;
      if (_showOptions) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  void _closeOptions() {
    if (!_showOptions) return;
    HapticFeedback.selectionClick();
    setState(() {
      _showOptions = false;
      _animationController.reverse();
    });
  }

  void _comingSoon() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Bientôt disponible'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Barrière pour fermer le panneau en touchant à côté
        if (_showOptions)
          Positioned.fill(
            child: GestureDetector(
              onTap: _closeOptions,
              behavior: HitTestBehavior.translucent,
              child: Container(color: Colors.black.withOpacity(0.3)),
            ),
          ),

        // Contrôles principaux
        Positioned(
          left: 0,
          right: 0,
          bottom: _showOptions ? -100 : 40,
          child: IgnorePointer(
            ignoring: _showOptions,
            child: AnimatedOpacity(
              opacity: _showOptions ? 0.0 : 1.0,
              duration: const Duration(milliseconds: 200),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildControlButton(
                        icon: widget.state.muted
                            ? Icons.mic_off_rounded
                            : Icons.mic_rounded,
                        label: widget.state.muted
                            ? _t(l10n, 'call_unmute', 'Activer')
                            : _t(l10n, 'call_mute', 'Muet'),
                        onTap: widget.isHangingUp ? null : widget.onToggleMute,
                        isActive: widget.state.muted,
                        activeColor: Colors.orange,
                      ),
                      if (widget.state.isVideo)
                        _buildControlButton(
                          icon: widget.state.videoOff
                              ? Icons.videocam_off_rounded
                              : Icons.videocam_rounded,
                          label: _t(l10n, 'call_camera', 'Caméra'),
                          onTap:
                              widget.isHangingUp ? null : widget.onToggleVideo,
                          isActive: widget.state.videoOff,
                          activeColor: Colors.red,
                        ),

                      // Bouton raccrocher (central et plus grand)
                      _buildHangUpButton(),

                      if (widget.state.isVideo)
                        _buildControlButton(
                          icon: Icons.cameraswitch_rounded,
                          label: _t(l10n, 'call_flip_camera', 'Retourner'),
                          onTap: widget.isHangingUp
                              ? null
                              : widget.onSwitchCamera,
                          isActive: false,
                          activeColor: Colors.white,
                        ),

                      _buildControlButton(
                        icon: widget.state.speakerOn
                            ? Icons.volume_up_rounded
                            : Icons.volume_off_rounded,
                        label: _t(l10n, 'call_speaker', 'Haut-parleur'),
                        onTap:
                            widget.isHangingUp ? null : widget.onToggleSpeaker,
                        isActive: widget.state.speakerOn,
                        activeColor: Colors.blue,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Toggle options
                  TextButton.icon(
                    onPressed: _toggleOptions,
                    icon: Icon(
                      _showOptions
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      color: Colors.white.withOpacity(0.8),
                      size: 24,
                    ),
                    label: Text(
                      _showOptions ? 'Masquer options' : 'Plus d\'options',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      backgroundColor: Colors.white.withOpacity(0.1),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Panneau d'options avancées
        if (_showOptions)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SlideTransition(
              position: _slideAnimation,
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: _buildOptionsSheet(),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
    required bool isActive,
    required Color activeColor,
  }) {
    final isEnabled = onTap != null;

    return Semantics(
      label: label,
      button: true,
      enabled: isEnabled,
      child: SizedBox(
        width: _kLabelWidth,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Material(
              color: isActive
                  ? activeColor.withOpacity(0.25)
                  : Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(_kButtonSize / 2),
              child: InkWell(
                onTap: isEnabled
                    ? () {
                        HapticFeedback.selectionClick();
                        onTap();
                      }
                    : null,
                borderRadius: BorderRadius.circular(_kButtonSize / 2),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: _kButtonSize,
                  height: _kButtonSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isActive
                          ? activeColor
                          : Colors.white.withOpacity(0.4),
                      width: isActive ? 2.5 : 1.5,
                    ),
                  ),
                  child: Icon(
                    icon,
                    color: isActive ? activeColor : Colors.white,
                    size: 28,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withOpacity(isEnabled ? 0.9 : 0.5),
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHangUpButton() {
    final hangUpLabel = _t(widget.l10n, 'call_hang_up', 'Raccrocher');

    return Semantics(
      label: hangUpLabel,
      button: true,
      child: SizedBox(
        width: _kLargeButtonSize + 16,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Material(
              color: Colors.transparent,
              elevation: widget.isHangingUp ? 0 : 12,
              shadowColor: ThixPolicy.danger.withOpacity(0.5),
              borderRadius: BorderRadius.circular(_kLargeButtonSize / 2),
              child: InkWell(
                onTap: widget.isHangingUp
                    ? null
                    : () {
                        HapticFeedback.heavyImpact();
                        widget.onHangUp();
                      },
                borderRadius: BorderRadius.circular(_kLargeButtonSize / 2),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: _kLargeButtonSize,
                  height: _kLargeButtonSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: widget.isHangingUp
                        ? const LinearGradient(
                            colors: [Colors.grey, Colors.grey])
                        : const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFFFF5252), Color(0xFFD32F2F)],
                          ),
                    boxShadow: widget.isHangingUp
                        ? []
                        : [
                            BoxShadow(
                              color: ThixPolicy.danger.withOpacity(0.4),
                              blurRadius: 16,
                              offset: const Offset(0, 8),
                            ),
                          ],
                  ),
                  child: const Icon(
                    Icons.call_end_rounded,
                    color: Colors.white,
                    size: 36,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              hangUpLabel,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionsSheet() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      decoration: BoxDecoration(
        color: ThixPolicy.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 24,
            offset: const Offset(0, -8),
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
              color: Colors.grey[400],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          Wrap(
            spacing: 16,
            runSpacing: 16,
            alignment: WrapAlignment.center,
            children: [
              _buildOptionItem(
                icon: Icons.bluetooth_rounded,
                label: 'Bluetooth',
                onTap: _comingSoon,
              ),
              _buildOptionItem(
                icon: Icons.record_voice_over_rounded,
                label: 'Audio seul',
                onTap: () {
                  if (widget.state.isVideo && !widget.state.videoOff) {
                    widget.onToggleVideo();
                  }
                  _closeOptions();
                },
              ),
              _buildOptionItem(
                icon: Icons.settings_rounded,
                label: 'Paramètres',
                onTap: _comingSoon,
              ),
              _buildOptionItem(
                icon: Icons.report_problem_rounded,
                label: 'Signaler',
                onTap: _comingSoon,
                color: Colors.orange,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOptionItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    final themeColor = color ?? ThixPolicy.primary;

    return Semantics(
      label: label,
      button: true,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 85,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          decoration: BoxDecoration(
            color: themeColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: themeColor.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: themeColor, size: 28),
              const SizedBox(height: 10),
              Text(
                label,
                style: TextStyle(
                  color: themeColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
