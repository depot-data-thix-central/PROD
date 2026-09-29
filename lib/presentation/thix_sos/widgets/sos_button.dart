/// THIX SOS — Bouton SOS long-press 2 secondes + RATE LIMIT 30 min
/// ✅ Rate limit backend + frontend (double couche)
/// ✅ UI bloquée avec countdown visible
/// ✅ Throttling + mounted + lifecycle + validation
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';
import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/l10n/app_localizations.dart';
import 'package:thix_id/services/sos_rate_limit_service.dart';

const Duration _kHoldDuration = Duration(milliseconds: 2000);
const Duration _kCallbackTimeout = Duration(seconds: 30);
const Duration _kThrottleDelay = Duration(seconds: 2);
const double _kMinSize = 80.0;
const double _kMaxSize = 240.0;

typedef SosTriggerCallback = Future<void> Function();

class _ButtonValidators {
  _ButtonValidators._();
  static double clampSize(double size) => size.clamp(_kMinSize, _kMaxSize);
}

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
  Timer? _cooldownTimer;

  bool _holding = false;
  bool _triggered = false;
  DateTime? _lastTrigger;
  bool _isAppActive = true;

  // ── Rate limit state ──
  bool _rateLimited = false;
  String _cooldownLabel = '';
  DateTime? _retryAt;

  final _rateLimit = SosRateLimitService.instance;

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

    _checkInitialCooldown();
    _updatePulseAnimation();
    debugPrint('[SosButton] 🚀 Initialized');
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cooldownTimer?.cancel();
    _pulseController.dispose();
    _holdController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _isAppActive = state == AppLifecycleState.resumed;
    _updatePulseAnimation();
    // Recheck cooldown au retour (pour attraper l'expiration pendant background)
    if (_isAppActive) _checkInitialCooldown();
  }

  @override
  void didUpdateWidget(SosButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enabled != widget.enabled ||
        oldWidget.isLoading != widget.isLoading) {
      _updatePulseAnimation();
    }
  }

  // ── Rate limit : vérification initiale + timer countdown ──
  Future<void> _checkInitialCooldown() async {
    final remaining = await _rateLimit.remainingCooldown();
    if (!mounted) return;

    if (remaining == Duration.zero) {
      if (_rateLimited) {
        setState(() {
          _rateLimited = false;
          _cooldownLabel = '';
          _retryAt = null;
        });
        _cooldownTimer?.cancel();
        _cooldownTimer = null;
      }
      return;
    }

    setState(() {
      _rateLimited = true;
      _retryAt = DateTime.now().add(remaining);
      _cooldownLabel = _formatDuration(remaining);
    });

    // Tick toutes les secondes pour le countdown
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final now = DateTime.now();
      if (_retryAt == null || now.isAfter(_retryAt!)) {
        _cooldownTimer?.cancel();
        _cooldownTimer = null;
        setState(() {
          _rateLimited = false;
          _cooldownLabel = '';
          _retryAt = null;
        });
        HapticFeedback.mediumImpact();
        debugPrint('[SosButton] ✓ Cooldown expired');
      } else {
        setState(() {
          _cooldownLabel = _formatDuration(_retryAt!.difference(now));
        });
      }
    });
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  void _updatePulseAnimation() {
    final canPulse = widget.enabled &&
        !widget.isLoading &&
        _isAppActive &&
        !_holding &&
        !_rateLimited;
    if (canPulse) {
      if (!_pulseController.isAnimating) _pulseController.repeat(reverse: true);
    } else {
      _pulseController.stop();
    }
  }

  void _onPointerDown(PointerDownEvent _) {
    // ✅ BLOCAGE RATE LIMIT : feedback immédiat si cooldown actif
    if (_rateLimited) {
      HapticFeedback.heavyImpact();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.timer_rounded, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'SOS bloqué. Réessayez dans $_cooldownLabel',
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            backgroundColor: ThixPolicy.warning,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    if (!widget.enabled || widget.isLoading || _triggered) {
      HapticFeedback.lightImpact();
      return;
    }
    HapticFeedback.lightImpact();
    setState(() => _holding = true);
    _pulseController.stop();
    _holdController.forward(from: 0);
  }

  void _onPointerUp(PointerUpEvent _) {
    if (!_holding) return;
    if (!_triggered) {
      _holdController.reverse();
      _updatePulseAnimation();
    }
    setState(() => _holding = false);
  }

  void _onPointerCancel(PointerCancelEvent _) {
    if (!_holding) return;
    _holdController.reverse();
    _updatePulseAnimation();
    setState(() => _holding = false);
  }

  Future<void> _onHoldComplete() async {
    if (_triggered || _rateLimited) return;

    // 1) Throttling local (2s)
    final now = DateTime.now();
    if (_lastTrigger != null &&
        now.difference(_lastTrigger!) < _kThrottleDelay) {
      _holdController.reset();
      _updatePulseAnimation();
      return;
    }

    // 2) ✅ VÉRIFICATION BACKEND (source de vérité)
    final rateCheck = await _rateLimit.checkWithBackend();
    if (!mounted) return;

    if (!rateCheck.allowed) {
      // Backend refuse → on met à jour l'UI avec l'heure serveur
      _holdController.reset();
      setState(() {
        _rateLimited = true;
        _retryAt = rateCheck.retryAt;
        _cooldownLabel = rateCheck.formattedRemaining();
      });
      _startCooldownTimer();
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.shield_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Un SOS a été lancé récemment. Prochain possible dans ${rateCheck.formattedRemaining()}',
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          backgroundColor: ThixPolicy.warning,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
      _updatePulseAnimation();
      return;
    }

    // 3) Rate limit OK → on déclenche
    _lastTrigger = now;
    setState(() {
      _triggered = true;
      _holding = false;
    });
    HapticFeedback.heavyImpact();

    try {
      await widget.onTriggered().timeout(_kCallbackTimeout);

      // 4) ✅ SUCCESS : on enregistre côté cache local + backend
      await _rateLimit.recordLocalTrigger();
      await _rateLimit.recordBackendTrigger();

      // 5) On active le cooldown UI
      if (mounted) {
        setState(() {
          _rateLimited = true;
          _retryAt = DateTime.now().add(const Duration(minutes: 30));
          _cooldownLabel = '30:00';
        });
        _startCooldownTimer();
      }
    } on TimeoutException {
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
      if (mounted) {
        setState(() {
          _triggered = false;
          _holdController.reset();
        });
        _updatePulseAnimation();
      }
    }
  }

  void _startCooldownTimer() {
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final now = DateTime.now();
      if (_retryAt == null || now.isAfter(_retryAt!)) {
        _cooldownTimer?.cancel();
        _cooldownTimer = null;
        setState(() {
          _rateLimited = false;
          _cooldownLabel = '';
          _retryAt = null;
        });
        HapticFeedback.mediumImpact();
        _updatePulseAnimation();
      } else {
        setState(() {
          _cooldownLabel = _formatDuration(_retryAt!.difference(now));
        });
      }
    });
    _updatePulseAnimation();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final size = _ButtonValidators.clampSize(widget.size);
    final blocked = _rateLimited || !widget.enabled || widget.isLoading;

    return Semantics(
      button: true,
      enabled: !blocked,
      label: _rateLimited
          ? 'SOS bloqué, réessayez dans $_cooldownLabel'
          : l10n.t('sos_button_label'),
      hint: l10n.t('sos_button_hint'),
      child: Tooltip(
        message: _rateLimited
            ? 'Cooldown: $_cooldownLabel'
            : l10n.t('sos_button_tooltip'),
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
                        // Anneaux décoratifs (désactivés en cooldown)
                        if (!_holding && !widget.isLoading && !_rateLimited) ...[
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
                        ],

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

                        // ✅ COOLDOWN RING : anneau orange + countdown
                        if (_rateLimited)
                          ExcludeSemantics(
                            child: SizedBox(
                              width: size + 12,
                              height: size + 12,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  SizedBox(
                                    width: size + 12,
                                    height: size + 12,
                                    child: CircularProgressIndicator(
                                      value: _retryAt == null
                                          ? 0
                                          : 1 - (_retryAt!.difference(DateTime.now()).inSeconds /
                                                  const Duration(minutes: 30).inSeconds)
                                              .clamp(0.0, 1.0),
                                      strokeWidth: 4,
                                      backgroundColor: Colors.white12,
                                      valueColor: const AlwaysStoppedAnimation(
                                        ThixPolicy.warning,
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    top: 4,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: ThixPolicy.warning,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        _cooldownLabel,
                                        style: GoogleFonts.inter(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
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
                              colors: blocked
                                  ? [
                                      ThixPolicy.textMuted.withValues(alpha: 0.6),
                                      ThixPolicy.border,
                                    ]
                                  : [ThixPolicy.danger, ThixPolicy.danger],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: _rateLimited
                                    ? ThixPolicy.warning.withValues(alpha: 0.3)
                                    : ThixPolicy.danger.withValues(
                                        alpha: blocked ? 0.15 : 0.45,
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
                              : _rateLimited
                                  ? Center(
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          const Icon(Icons.timer_rounded,
                                              color: Colors.white, size: 32),
                                          const SizedBox(height: 4),
                                          Text(
                                            _cooldownLabel,
                                            style: GoogleFonts.inter(
                                              fontSize: size * 0.14,
                                              fontWeight: FontWeight.w900,
                                              color: Colors.white,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'COOLDOWN',
                                            style: GoogleFonts.inter(
                                              fontSize: size * 0.055,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.white70,
                                              letterSpacing: 1.5,
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                  : Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
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
