/// THIX SOS — Saisie PIN sécurité (Production Enterprise)
/// ✅ SÉCURISÉ : brute-force protection, timeout, throttling, mounted checks
/// ✅ UX PREMIUM : keyboard support, animations, haptic différencié, i18n
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/l10n/app_localizations.dart';

import '../providers/sos_providers.dart';
import '../thix_sos_screen.dart';

// ============================================================================
// CONSTANTS
// ============================================================================
const int _kPinLength = 4;
const int _kMaxAttempts = 5;
const Duration _kCooldownAfterFail = Duration(seconds: 15);
const Duration _kOperationTimeout = Duration(seconds: 20);
const int _kMaxRetries = 1;

// ============================================================================
// MODE
// ============================================================================
enum SosPinMode { cancel, resolve }

// ============================================================================
// VALIDATORS
// ============================================================================
class _PinValidators {
  _PinValidators._();

  static bool isValidPin(String pin) {
    return RegExp(r'^\d{4,6}$').hasMatch(pin);
  }

  static String friendlyError(dynamic e, AppLocalizations l10n) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('timeout')) return l10n.t('sos_error_timeout');
    if (msg.contains('network')) return l10n.t('sos_error_network');
    if (msg.contains('permission')) return l10n.t('sos_error_permission');
    if (msg.contains('not found')) return l10n.t('sos_incident_not_found');
    return l10n.t('sos_error_generic');
  }
}

// ============================================================================
// HELPERS
// ============================================================================
Future<bool> _pinRetry(
  Future<bool> Function() fn, {
  required String label,
  int maxRetries = _kMaxRetries,
}) async {
  int attempt = 0;
  while (true) {
    try {
      return await fn().timeout(_kOperationTimeout);
    } on TimeoutException {
      attempt++;
      if (attempt > maxRetries) {
        debugPrint('[SosPin] ❌ $label: timeout');
        rethrow;
      }
      debugPrint('[SosPin] ⏱️ $label timeout — retry $attempt/$maxRetries');
      await Future.delayed(const Duration(milliseconds: 600));
    } catch (e) {
      attempt++;
      if (attempt > maxRetries) {
        debugPrint('[SosPin] ❌ $label: $e');
        rethrow;
      }
      await Future.delayed(const Duration(milliseconds: 600));
    }
  }
}

// ============================================================================
// PAGE
// ============================================================================
class SosPinPage extends ConsumerStatefulWidget {
  const SosPinPage({
    super.key,
    required this.incidentId,
    this.mode = SosPinMode.cancel,
  });

  final String incidentId;
  final SosPinMode mode;

  @override
  ConsumerState<SosPinPage> createState() => _SosPinPageState();
}

class _SosPinPageState extends ConsumerState<SosPinPage>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  final List<String> _digits = [];
  final FocusNode _focusNode = FocusNode();

  bool _loading = false;
  bool _isSubmitting = false;
  String? _error;
  int _failedAttempts = 0;
  DateTime? _cooldownUntil;

  late final AnimationController _shakeCtrl;
  late final Animation<double> _shakeAnim;
  late final AnimationController _dotCtrl;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _shakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _shakeAnim = Tween<double>(begin: 0, end: 12).animate(
      CurvedAnimation(parent: _shakeCtrl, curve: Curves.elasticIn),
    );

    _dotCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );

    // Auto-focus pour capturer clavier physique
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });

    debugPrint('[SosPin] 🚀 Opened — mode: ${widget.mode.name}');
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    debugPrint('[SosPin] 🔄 lifecycle: ${state.name}');
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _shakeCtrl.dispose();
    _dotCtrl.dispose();
    _focusNode.dispose();
    debugPrint('[SosPin] 👋 Disposed');
    super.dispose();
  }

  // ✅ Support clavier physique
  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    final key = event.logicalKey;

    // Chiffres 0-9
    if (key.keyLabel.isNotEmpty &&
        RegExp(r'^[0-9]$').hasMatch(key.keyLabel)) {
      _onKey(key.keyLabel);
      return KeyEventResult.handled;
    }

    // Backspace
    if (key == LogicalKeyboardKey.backspace ||
        key == LogicalKeyboardKey.delete) {
      _onKey('del');
      return KeyEventResult.handled;
    }

    // Escape
    if (key == LogicalKeyboardKey.escape) {
      if (!_loading) Navigator.pop(context);
      return KeyEventResult.handled;
    }

    // Enter
    if (key == LogicalKeyboardKey.enter &&
        _digits.length == _kPinLength &&
        !_loading) {
      _submit();
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  // ✅ FIX : throttle + cooldown brute-force
  bool _canSubmit() {
    if (_isSubmitting || _loading) return false;
    if (_cooldownUntil != null &&
        DateTime.now().isBefore(_cooldownUntil!)) {
      return false;
    }
    return true;
  }

  void _onKey(String value) {
    if (!_canSubmit()) {
      HapticFeedback.lightImpact();
      return;
    }

    if (value == 'del') {
      if (_digits.isNotEmpty) {
        HapticFeedback.selectionClick();
        setState(() {
          _digits.removeLast();
          _error = null;
        });
      } else {
        HapticFeedback.lightImpact();
      }
      return;
    }

    if (_digits.length >= _kPinLength) {
      HapticFeedback.lightImpact();
      return;
    }

    HapticFeedback.selectionClick();
    setState(() {
      _digits.add(value);
      _error = null;
    });

    if (_digits.length == _kPinLength) {
      // Petit délai pour UX
      Future.delayed(const Duration(milliseconds: 150), () {
        if (mounted && _digits.length == _kPinLength) _submit();
      });
    }
  }

  Future<void> _submit() async {
    if (!_canSubmit()) return;
    final l10n = AppLocalizations.of(context);
    final pin = _digits.join();

    if (!_PinValidators.isValidPin(pin)) {
      setState(() {
        _error = l10n.t('sos_pin_invalid');
        _digits.clear();
      });
      _triggerShake();
      HapticFeedback.heavyImpact();
      return;
    }

    setState(() {
      _loading = true;
      _isSubmitting = true;
      _error = null;
    });

    debugPrint('[SosPin] 🔐 Submit attempt ${_failedAttempts + 1}/$_kMaxAttempts'
        ' (${widget.mode.name})');

    try {
      final notifier = ref.read(sosResolveProvider.notifier);
      final ok = await _pinRetry(
        () async {
          return widget.mode == SosPinMode.cancel
              ? await notifier.cancel(widget.incidentId)
              : await notifier.resolve(widget.incidentId);
        },
        label: widget.mode == SosPinMode.cancel ? 'cancel' : 'resolve',
      );

      if (!mounted) return;

      if (ok) {
        HapticFeedback.heavyImpact();
        debugPrint('[SosPin] ✓ ${widget.mode.name} success');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.mode == SosPinMode.cancel
                  ? l10n.t('sos_cancelled')
                  : l10n.t('sos_resolved'),
              style: const TextStyle(color: Colors.white),
            ),
            backgroundColor: ThixPolicy.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const ThixSosScreen()),
          (_) => false,
        );
      } else {
        _handleFailedAttempt(l10n);
      }
    } catch (e) {
      debugPrint('[SosPin] ❌ Submit error: $e');
      if (!mounted) return;
      setState(() {
        _error = _PinValidators.friendlyError(e, l10n);
        _digits.clear();
        _loading = false;
        _isSubmitting = false;
      });
      _triggerShake();
      HapticFeedback.heavyImpact();
    }
  }

  // ✅ FIX : brute-force protection avec cooldown
  void _handleFailedAttempt(AppLocalizations l10n) {
    _failedAttempts++;
    final remaining = _kMaxAttempts - _failedAttempts;

    if (remaining <= 0) {
      _cooldownUntil = DateTime.now().add(_kCooldownAfterFail);
      setState(() {
        _error = l10n.t('sos_pin_locked');
        _digits.clear();
        _loading = false;
        _isSubmitting = false;
      });
      HapticFeedback.heavyImpact();
      _triggerShake();
      debugPrint('[SosPin] 🔒 Max attempts reached — cooldown');
      return;
    }

    setState(() {
      _error = '${l10n.t('sos_pin_wrong')} ($remaining ${l10n.t('sos_remaining')})';
      _digits.clear();
      _loading = false;
      _isSubmitting = false;
    });
    _triggerShake();
    HapticFeedback.heavyImpact();
  }

  void _triggerShake() {
    _shakeCtrl.forward(from: 0);
  }

  String _cooldownLabel(AppLocalizations l10n) {
    if (_cooldownUntil == null) return '';
    final secs = _cooldownUntil!.difference(DateTime.now()).inSeconds;
    if (secs <= 0) {
      _cooldownUntil = null;
      _failedAttempts = 0;
      return '';
    }
    return '${l10n.t('sos_pin_locked_for')} ${secs}s';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isCancel = widget.mode == SosPinMode.cancel;
    final accentColor = isCancel ? ThixPolicy.danger : ThixPolicy.success;
    final cooldownLabel = _cooldownLabel(l10n);
    final isLocked = cooldownLabel.isNotEmpty;

    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: PopScope(
        canPop: !_loading && !_isSubmitting,
        child: Scaffold(
          backgroundColor: ThixPolicy.inkDeep,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: Semantics(
              button: true,
              label: l10n.t('common_close'),
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white70),
                onPressed: _loading || _isSubmitting
                    ? null
                    : () => Navigator.pop(context),
              ),
            ),
          ),
          body: SafeArea(
            child: Column(
              children: [
                const Spacer(flex: 1),
                AnimatedBuilder(
                  animation: _shakeAnim,
                  builder: (context, child) {
                    return Transform.translate(
                      offset: Offset(
                        _shakeAnim.value *
                            (_shakeCtrl.status == AnimationStatus.forward ? 1 : -1),
                        0,
                      ),
                      child: child,
                    );
                  },
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: accentColor.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.lock_outline,
                          size: 40,
                          color: accentColor,
                        ),
                      ),
                      const SizedBox(height: ThixPolicy.s16),
                      Semantics(
                        header: true,
                        child: Text(
                          isCancel
                              ? l10n.t('sos_cancel_sos')
                              : l10n.t('sos_end_sos'),
                          style: GoogleFonts.inter(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: ThixPolicy.s8),
                      Padding(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          l10n.t('sos_pin_enter', args: ['$_kPinLength']),
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: ThixPolicy.textMuted,
                            height: 1.4,
                          ),
                        ),
                      ),
                      const SizedBox(height: ThixPolicy.s32),

                      // Dots avec animation
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(_kPinLength, (i) {
                          final filled = i < _digits.length;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            curve: Curves.easeOutBack,
                            margin: const EdgeInsets.symmetric(horizontal: 8),
                            width: filled ? 20 : 16,
                            height: filled ? 20 : 16,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: filled ? accentColor : Colors.transparent,
                              border: Border.all(
                                color: filled
                                    ? accentColor
                                    : ThixPolicy.textMuted,
                                width: 2,
                              ),
                              boxShadow: filled
                                  ? [
                                      BoxShadow(
                                        color: accentColor
                                            .withValues(alpha: 0.4),
                                        blurRadius: 8,
                                      ),
                                    ]
                                  : null,
                            ),
                          );
                        }),
                      ),

                      if (_error != null) ...[
                        const SizedBox(height: ThixPolicy.s16),
                        Semantics(
                          liveRegion: true,
                          child: Text(
                            _error!,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: ThixPolicy.danger,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],

                      if (isLocked) ...[
                        const SizedBox(height: ThixPolicy.s8),
                        Text(
                          cooldownLabel,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: ThixPolicy.warning,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],

                      if (_loading) ...[
                        const SizedBox(height: ThixPolicy.s24),
                        SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(
                            color: accentColor,
                            strokeWidth: 2.5,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                const Spacer(flex: 1),

                // Keypad (scrollable sur petits écrans)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final row in [
                        ['1', '2', '3'],
                        ['4', '5', '6'],
                        ['7', '8', '9'],
                        ['', '0', 'del'],
                      ])
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: row.map((key) {
                              if (key.isEmpty) {
                                return const SizedBox(width: 72, height: 72);
                              }
                              final isDel = key == 'del';
                              final disabled = isLocked ||
                                  _loading ||
                                  _isSubmitting ||
                                  (isDel && _digits.isEmpty);

                              return _Key(
                                label: isDel ? null : key,
                                icon: isDel
                                    ? Icons.backspace_outlined
                                    : null,
                                disabled: disabled,
                                onTap: () => _onKey(key),
                              );
                            }).toList(),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: ThixPolicy.s24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// KEY — ✅ Semantics + disabled state + haptic
// ============================================================================
class _Key extends StatefulWidget {
  const _Key({
    this.label,
    this.icon,
    required this.onTap,
    this.disabled = false,
  });

  final String? label;
  final IconData? icon;
  final VoidCallback onTap;
  final bool disabled;

  @override
  State<_Key> createState() => _KeyState();
}

class _KeyState extends State<_Key> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final label = widget.label ?? (widget.icon != null ? 'delete' : '');
    return Semantics(
      button: true,
      enabled: !widget.disabled,
      label: widget.label ?? 'delete',
      child: AnimatedScale(
        scale: _pressed ? 0.92 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Material(
          color: widget.disabled
              ? ThixPolicy.card.withValues(alpha: 0.3)
              : ThixPolicy.card,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: widget.disabled
                ? null
                : () {
                    setState(() => _pressed = true);
                    Future.delayed(const Duration(milliseconds: 100), () {
                      if (mounted) setState(() => _pressed = false);
                    });
                    widget.onTap();
                  },
            child: SizedBox(
              width: 72,
              height: 72,
              child: Center(
                child: widget.icon != null
                    ? Icon(
                        widget.icon,
                        color: widget.disabled
                            ? Colors.white24
                            : Colors.white70,
                        size: 24,
                      )
                    : Text(
                        widget.label!,
                        style: GoogleFonts.inter(
                          fontSize: 26,
                          fontWeight: FontWeight.w600,
                          color: widget.disabled
                              ? Colors.white24
                              : Colors.white,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
