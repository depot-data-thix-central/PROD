/// THIX SOS — Bouton SOS long-press 2 secondes (production)
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

typedef SosTriggerCallback = Future<void> Function();

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
    with TickerProviderStateMixin {
  static const _holdDuration = Duration(milliseconds: 2000);

  late final AnimationController _pulseController;
  late final AnimationController _holdController;

  bool _holding = false;
  bool _triggered = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);

    _holdController = AnimationController(
      vsync: this,
      duration: _holdDuration,
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed && _holding && !_triggered) {
          _onHoldComplete();
        }
      });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _holdController.dispose();
    super.dispose();
  }

  void _onPointerDown(PointerDownEvent _) {
    if (!widget.enabled || widget.isLoading || _triggered) return;
    HapticFeedback.lightImpact();
    setState(() => _holding = true);
    _holdController.forward(from: 0);
  }

  void _onPointerUp(PointerUpEvent _) {
    if (!_holding) return;
    if (!_triggered) {
      _holdController.reverse();
    }
    setState(() => _holding = false);
  }

  void _onPointerCancel(PointerCancelEvent _) {
    if (!_holding) return;
    _holdController.reverse();
    setState(() => _holding = false);
  }

  Future<void> _onHoldComplete() async {
    if (_triggered) return;
    setState(() {
      _triggered = true;
      _holding = false;
    });
    HapticFeedback.heavyImpact();
    try {
      await widget.onTriggered();
    } finally {
      if (mounted) {
        setState(() => _triggered = false);
        _holdController.reset();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;

    return Listener(
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
                  // Anneau externe pulse
                  if (!_holding && !widget.isLoading)
                    Container(
                      width: size + 36,
                      height: size + 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFFEF4444)
                              .withOpacity(0.12 + _pulseController.value * 0.1),
                          width: 2,
                        ),
                      ),
                    ),
                  if (!_holding && !widget.isLoading)
                    Container(
                      width: size + 18,
                      height: size + 18,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFFEF4444)
                              .withOpacity(0.2 + _pulseController.value * 0.12),
                          width: 2,
                        ),
                      ),
                    ),

                  // Progress hold
                  if (_holding || hold > 0)
                    SizedBox(
                      width: size + 12,
                      height: size + 12,
                      child: CircularProgressIndicator(
                        value: hold,
                        strokeWidth: 5,
                        backgroundColor: Colors.white12,
                        valueColor: const AlwaysStoppedAnimation(Color(0xFFFEE2E2)),
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
                            ? const [Color(0xFFEF4444), Color(0xFFB91C1C)]
                            : const [Color(0xFF6B7280), Color(0xFF374151)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFEF4444)
                              .withOpacity(widget.enabled ? 0.45 : 0.15),
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
                                'SOS',
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
                                'APPUYER ET MAINTENIR\n2 SECONDES',
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
    );
  }
}
