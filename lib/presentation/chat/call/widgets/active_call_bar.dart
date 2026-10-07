// lib/presentation/chat/call/widgets/active_call_bar.dart
//
// ============================================================================
// ACTIVE CALL BAR — barre « Appel en cours » (comme WhatsApp)
// ============================================================================
// ✅ Verte pendant la conversation (avec le chronomètre), bleue pendant la sonnerie
// ✅ Appui sur la barre = retour à l'écran d'appel
// ✅ Bouton rouge = raccrocher directement
// ✅ Protégée contre le double appui

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/l10n/app_localizations.dart';
import 'package:thix_id/models/chat/call_status.dart';
import 'package:thix_id/presentation/chat/call/providers/call_provider.dart';

class ActiveCallBar extends ConsumerStatefulWidget {
  /// Ouvre l'écran d'appel.
  final VoidCallback onReturn;

  const ActiveCallBar({super.key, required this.onReturn});

  @override
  ConsumerState<ActiveCallBar> createState() => _ActiveCallBarState();
}

class _ActiveCallBarState extends ConsumerState<ActiveCallBar> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  bool _busy = false;
  bool _hangingUp = false;

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  String _tr(AppLocalizations l10n, String key, String fb) {
    final s = l10n.t(key);
    return (s.isEmpty || s == key) ? fb : s;
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return d.inHours > 0 ? '${d.inHours}:$m:$s' : '$m:$s';
  }

  String _statusLabel(CallState s, AppLocalizations l10n) {
    switch (s.status) {
      case CallStatus.ongoing:
        return _fmt(s.duration);
      case CallStatus.ringing:
        return s.isCaller ? l10n.t('call_status_calling') : l10n.t('call_status_connecting');
      default:
        return l10n.t('call_status_connecting');
    }
  }

  void _return() {
    if (_busy) return;
    _busy = true;
    HapticFeedback.selectionClick();
    widget.onReturn();
    Future.delayed(const Duration(milliseconds: 700), () => _busy = false);
  }

  Future<void> _hangUp() async {
    if (_hangingUp) return;
    setState(() => _hangingUp = true);
    HapticFeedback.mediumImpact();
    try {
      await ref.read(callProvider.notifier).hangUp();
    } catch (_) {}
    if (mounted) setState(() => _hangingUp = false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final s = ref.watch(callProvider);
    if (!s.isActive) return const SizedBox.shrink();

    final ongoing = s.status == CallStatus.ongoing;
    final color = ongoing ? ThixPolicy.success : ThixPolicy.primary;
    final name = (s.remoteName == null || s.remoteName!.trim().isEmpty)
        ? l10n.t('call_unknown_contact')
        : s.remoteName!.trim();
    final status = _statusLabel(s, l10n);
    final hint = _tr(l10n, 'call_bar_tap_to_return', 'Appuyez pour revenir à l’appel');

    return Semantics(
      button: true,
      label: '$name, $status. $hint',
      child: Material(
        color: color,
        child: InkWell(
          onTap: _return,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
              child: Row(
                children: [
                  FadeTransition(
                    opacity: Tween<double>(begin: 1, end: 0.35).animate(_pulse),
                    child: Icon(
                      s.isVideo ? Icons.videocam_rounded : Icons.call_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            decoration: TextDecoration.none,
                          ),
                        ),
                        Text(
                          '$status · $hint',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.85),
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Semantics(
                    button: true,
                    label: l10n.t('call_hang_up'),
                    child: Material(
                      color: ThixPolicy.danger,
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: _hangingUp ? null : _hangUp,
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: _hangingUp
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.call_end_rounded, color: Colors.white, size: 18),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
