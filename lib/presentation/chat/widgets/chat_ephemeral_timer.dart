// lib/presentation/chat/widgets/chat_ephemeral_timer.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/l10n/app_localizations.dart';

// ============================================================================
// CONSTANTS
// ============================================================================
const double _kIconSize = 12.0;
const double _kIconSpacing = 4.0;
const double _kFontSize = 10.0;
const int _kSecondsInMinute = 60;
const int _kSecondsInHour = 3600;

// ============================================================================
// EPHEMERAL TIMER
// ============================================================================

/// Widget qui affiche un compte à rebours pour les messages éphémères.
///
/// Affiche le temps restant avec formatage intelligent :
/// - < 60s : `45s`
/// - < 1h  : `12m 30s`
/// - >= 1h : `3h 00m`
///
/// Appelle [onExpired] une seule fois quand le timer atteint 0.
class ChatEphemeralTimer extends StatefulWidget {
  /// Durée restante en secondes (doit être > 0)
  final int duration;

  /// Callback appelé **une seule fois** à l'expiration
  final VoidCallback onExpired;

  const ChatEphemeralTimer({
    super.key,
    required this.duration,
    required this.onExpired,
  }) : assert(duration >= 0, 'duration must be >= 0');

  @override
  State<ChatEphemeralTimer> createState() => _ChatEphemeralTimerState();
}

class _ChatEphemeralTimerState extends State<ChatEphemeralTimer> {
  late int _remaining;
  Timer? _timer;
  bool _hasExpired = false;

  @override
  void initState() {
    super.initState();
    _remaining = widget.duration;
    _startTimerIfNeeded();
    debugPrint('[EphemeralTimer] 🚀 Started with ${widget.duration}s');
  }

  @override
  void didUpdateWidget(covariant ChatEphemeralTimer oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Si la duration change, redémarrer le timer
    if (oldWidget.duration != widget.duration) {
      debugPrint('[EphemeralTimer] 🔄 Duration updated: ${oldWidget.duration}s → ${widget.duration}s');
      _timer?.cancel();
      _hasExpired = false;
      _remaining = widget.duration;
      _startTimerIfNeeded();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    debugPrint('[EphemeralTimer] 👋 Disposed (remaining: ${_remaining}s)');
    super.dispose();
  }

  /// Démarre le timer seulement si duration > 0
  void _startTimerIfNeeded() {
    if (_remaining <= 0) {
      _triggerExpiration();
      return;
    }

    _timer = Timer.periodic(const Duration(seconds: 1), _onTick);
  }

  /// Callback appelé chaque seconde
  void _onTick(Timer timer) {
    if (!mounted) {
      timer.cancel();
      return;
    }

    if (_remaining > 0) {
      setState(() => _remaining--);

      // Déclencher expiration quand on atteint 0
      if (_remaining == 0) {
        timer.cancel();
        _triggerExpiration();
      }
    } else {
      timer.cancel();
    }
  }

  /// Déclenche l'expiration une seule fois (protection double-callback)
  void _triggerExpiration() {
    if (_hasExpired) {
      debugPrint('[EphemeralTimer] ⚠️ Expiration already triggered, skipping');
      return;
    }

    _hasExpired = true;
    debugPrint('[EphemeralTimer] ⏰ Timer expired');
    HapticFeedback.lightImpact();

    if (!mounted) {
      debugPrint('[EphemeralTimer] ⚠️ Widget unmounted, skipping callback');
      return;
    }

    widget.onExpired();
  }

  /// Formatage intelligent du temps restant (i18n)
  String _formatTime(AppLocalizations l10n) {
    if (_remaining <= 0) return '0${l10n.t('timer_suffix_s')}';

    // < 1 minute : secondes uniquement
    if (_remaining < _kSecondsInMinute) {
      return '$_remaining${l10n.t('timer_suffix_s')}';
    }

    // < 1 heure : minutes + secondes
    if (_remaining < _kSecondsInHour) {
      final m = _remaining ~/ _kSecondsInMinute;
      final s = _remaining % _kSecondsInMinute;
      if (s == 0) return '$m${l10n.t('timer_suffix_m')}';
      return '$m${l10n.t('timer_suffix_m')} $s${l10n.t('timer_suffix_s')}';
    }

    // >= 1 heure : heures + minutes
    final h = _remaining ~/ _kSecondsInHour;
    final m = (_remaining % _kSecondsInHour) ~/ _kSecondsInMinute;
    if (m == 0) return '$h${l10n.t('timer_suffix_h')}';
    return '$h${l10n.t('timer_suffix_h')} ${m.toString().padLeft(2, '0')}${l10n.t('timer_suffix_m')}';
  }

  /// Label accessible décrivant le temps restant
  String _buildSemanticsLabel(AppLocalizations l10n) {
    if (_remaining <= 0) return l10n.t('timer_expired');

    if (_remaining < _kSecondsInMinute) {
      return "${l10n.t('timer_remaining_seconds')} $_remaining";
    }

    if (_remaining < _kSecondsInHour) {
      final m = _remaining ~/ _kSecondsInMinute;
      return "${l10n.t('timer_remaining_minutes')} $m";
    }

    final h = _remaining ~/ _kSecondsInHour;
    return "${l10n.t('timer_remaining_hours')} $h";
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final formattedTime = _formatTime(l10n);
    final semanticsLabel = _buildSemanticsLabel(l10n);

    return Semantics(
      label: semanticsLabel,
      liveRegion: true, // Annonce les changements aux lecteurs d'écran
      child: RepaintBoundary(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.timer_outlined,
              size: _kIconSize,
              color: ThixPolicy.gold,
            ),
            const SizedBox(width: _kIconSpacing),
            Text(
              formattedTime,
              style: ThixPolicy.microStyle.copyWith(
                fontSize: _kFontSize,
                fontWeight: ThixPolicy.bold,
                color: ThixPolicy.gold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
