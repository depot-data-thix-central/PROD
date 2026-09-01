/// THIX SOS — Bouton SOS long-press 2 secondes (Production Enterprise)
/// ✅ SÉCURISÉ : throttling, mounted checks, lifecycle, timeout, validation
/// ✅ ACCESSIBLE : Semantics, haptic différencié, i18n, ThixPolicy
/// ✅ PERFORMANCE : RepaintBoundary, animation pause en background
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';
import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/l10n/app_localizations.dart';

// ============================================================================
// CONSTANTS
// ============================================================================
const Duration _kHoldDuration = Duration(milliseconds: 2000);
const Duration _kCallbackTimeout = Duration(seconds: 30);
const Duration _kThrottleDelay = Duration(seconds: 2);
const double _kMinSize = 80.0;
const double _kMaxSize = 240.0;

// ============================================================================
// TYPES
// ============================================================================
typedef SosTriggerCallback = Future<void> Function();

// ============================================================================
// VALIDATORS
// ============================================================================
class _ButtonValidators {
  _ButtonValidators._();

  static double clampSize(double size) {
    return size.clamp(_kMinSize, _kMaxSize);
  }
}

// ============================================================================
// WIDGET
// ============================================================================
class SosButton extends StatefulWidget {
  const SosButton({
    super.key,
    required this.onTriggered,
    this.size = 160,
    this.enabled = true,
    this.isLoading = false,
  });

  final SosTriggerCallback onTriggered;
  final double size;
  final bool enabled;
  final bool isLoading;

  @override
  State<SosButton> createState() => _SosButtonState();
}

class _SosButtonState extends State<SosButton>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _pulseController;
  late final AnimationController _holdController;

  bool _holding = false;
  bool _triggered = false;
  DateTime? _lastTrigger;
  bool _isAppActive = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );

    _holdController = AnimationController(
      vsync: this,
      duration: _kHoldDuration,
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed && _holding && !_triggered) {
          _onHoldComplete();
        }
      });

    // ✅ FIX P0 : animation pulse démarre seulement si enabled + app active
    _updatePulseAnimation();
    debugPrint('[SosButton] 🚀 Initialized — size: ${widget.size}');
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _isAppActive = state == AppLifecycleState.resumed;
    _updatePulseAnimation();
    debugPrint('[SosButton] 🔄 lifecycle: ${state.name}');
  }

  @override
  void didUpdateWidget(SosButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enabled != widget.enabled ||
        oldWidget.isLoading != widget.isLoading) {
      _updatePulseAnimation();
    }
  }

  // ✅ FIX P0 : pause animation quand disabled/loading/background
  void _updatePulseAnimation() {
    if (widget.enabled && !widget.isLoading && _isAppActive && !_holding) {
      if (!_pulseController.isAnimating) {
        _pulseController.repeat(reverse: true);
      }
    } else {
      _pulseController.stop();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pulseController.dispose();
    _holdController.dispose();
    debugPrint('[SosButton] 👋 Disposed');
    super.dispose();
  }

  void _onPointerDown(PointerDownEvent _) {
    if (!widget.enabled || widget.isLoading || _triggered) {
      HapticFeedback.lightImpact();
      return;
    }
    HapticFeedback.lightImpact();
    setState(() => _holding = true);
    _pulseController.stop(); // ✅ Pause pulse pendant hold
    _holdController.forward(from: 0);
    debugPrint('[SosButton] 👆 Hold started');
  }

  void _onPointerUp(PointerUpEvent _) {
    if (!_holding) return;
    if (!_triggered) {
      _holdController.reverse();
      _updatePulseAnimation(); // ✅ Resume pulse si annulé
    }
    setState(() => _holding = false);
    debugPrint('[SosButton] 👆 Hold released (not triggered)');
  }

  void _onPointerCancel(PointerCancelEvent _) {
    if (!_holding) return;
    _holdController.reverse();
    _updatePulseAnimation();
    setState(() => _holding = false);
    debugPrint('[SosButton] ⚠️ Hold cancelled');
  }

  // ✅ FIX P0 : throttling + mounted check + timeout + logs
  Future<void> _onHoldComplete() async {
    if (_triggered) return;

    // Throttling : empêche double-trigger si callback lent
    final now = DateTime.now();
    if (_lastTrigger != null &&
        now.difference(_lastTrigger!) < _kThrottleDelay) {
      debugPrint('[SosButton] ⚠️ Trigger throttled');
      _holdController.reset();
      _updatePulseAnimation();
      return;
    }
    _lastTrigger = now;

    setState(() {
      _triggered = true;
      _holding = false;
    });
    HapticFeedback.heavyImpact();
    debugPrint('[SosButton] 🚨 Triggering SOS...');

    try {
      await widget.onTriggered().timeout(_kCallbackTimeout);
      debugPrint('[SosButton] ✓ Trigger completed');
    } on TimeoutException {
      debugPrint('[SosButton] ❌ Callback timeout after ${_kCallbackTimeout.inSeconds}s');
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.t('sos_trigger_timeout')),
            backgroundColor: ThixPolicy.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint('[SosButton] ❌ Trigger error: $e');
    } finally {
      // ✅ FIX P0 : mounted check robuste
      if (mounted) {
        setState(() {
          _triggered = false;
          _holdController.reset();
        });
        _updatePulseAnimation();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final size = _ButtonValidators.clampSize(widget.size);

    return Semantics(
      button: true,
      enabled: widget.enabled && !widget.isLoading,
      label: l10n.t('sos_button_label'),
      hint: l10n.t('sos_button_hint'),
      child: Tooltip(
        message: l10n.t('sos_button_tooltip'),
        child: RepaintBoundary(
          child: Listener(
            onPointerDown: _onPointerDown,
            onPointerUp: _onPointerUp,
            onPointerCancel: _onPointerCancel,
            child: AnimatedBuilder(
              animation: Listenable.merge([_pulseController, _holdController]),
              builder: (context, child) {
                final pulse = 1.0 + (_pulseController.value * 0.035);
                final hold = _holdController.value;
                final scale = _holding ? 0.96 : (_triggered ? 0.92 : pulse);

                return Transform.scale(
                  scale: scale,
                  child: SizedBox(
                    width: size + 40,
                    height: size + 40,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // ✅ FIX : ExcludeSemantics sur éléments décoratifs
                        if (!_holding && !widget.isLoading)
                          ExcludeSemantics(
                            child: Container(
                              width: size + 36,
                              height: size + 36,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: ThixPolicy.danger.withValues(
                                    alpha: 0.12 + _pulseController.value * 0.1,
                                  ),
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                        if (!_holding && !widget.isLoading)
                          ExcludeSemantics(
                            child: Container(
                              width: size + 18,
                              height: size + 18,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: ThixPolicy.danger.withValues(
                                    alpha: 0.2 + _pulseController.value * 0.12,
                                  ),
                                  width: 2,
                                ),
                              ),
                            ),
                          ),

                        // Progress hold
                        if (_holding || hold > 0)
                          ExcludeSemantics(
                            child: SizedBox(
                              width: size + 12,
                              height: size + 12,
                              child: CircularProgressIndicator(
                                value: hold,
                                strokeWidth: 5,
                                backgroundColor: Colors.white12,
                                valueColor: AlwaysStoppedAnimation(
                                  ThixPolicy.danger.withValues(alpha: 0.3),
                                ),
                              ),
                            ),
                          ),

                        // Bouton central
                        Container(
                          width: size,
                          height: size,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: widget.enabled
                                  ? [ThixPolicy.danger, ThixPolicy.danger]
                                  : [ThixPolicy.textMuted, ThixPolicy.border],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: ThixPolicy.danger.withValues(
                                  alpha: widget.enabled ? 0.45 : 0.15,
                                ),
                                blurRadius: 28,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: widget.isLoading || _triggered
                              ? const Center(
                                  child: SizedBox(
                                    width: 36,
                                    height: 36,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 3,
                                    ),
                                  ),
                                )
                              : Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      l10n.t('sos_button_text'),
                                      style: GoogleFonts.inter(
                                        fontSize: size * 0.22,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.white,
                                        letterSpacing: 2,
                                        height: 1,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      l10n.t('sos_button_instruction'),
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.inter(
                                        fontSize: size * 0.055,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white70,
                                        height: 1.25,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
