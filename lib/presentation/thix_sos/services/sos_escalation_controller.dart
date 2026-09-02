/// THIX SOS — Escalade automatique des cercles (Production Enterprise)
/// ✅ SÉCURISÉ : timeouts, retry, max attempts, disposed checks, validation
/// ✅ ROBUSTE : race-condition protection, logs structurés, syntax fix
import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/sos_models.dart';
import 'sos_call_bridge.dart';
import 'sos_service.dart';

// ============================================================================
// CONSTANTS
// ============================================================================
const Duration _kOperationTimeout = Duration(seconds: 20);
const Duration _kRetryDelay = Duration(milliseconds: 600);
const int _kMaxRetries = 1;
const int _kMaxEscalationAttempts = 3;
const int _kMinCircle = 1;
const int _kMaxCircle = 3;

// ============================================================================
// TYPES
// ============================================================================
typedef SosEscalationTick = void Function(int circle, int secondsLeft);
typedef SosEscalationEvent = void Function(String message);

// ============================================================================
// VALIDATORS
// ============================================================================
class _EscalationValidators {
  _EscalationValidators._();

  static bool isValidId(String? id) {
    if (id == null) return false;
    final trimmed = id.trim();
    return trimmed.isNotEmpty && trimmed.length <= 64;
  }

  static int clampCircle(int circle) {
    return circle.clamp(_kMinCircle, _kMaxCircle);
  }
}

// ============================================================================
// HELPERS
// ============================================================================
Future<T> _escalationRetry<T>(
  Future<T> Function() fn, {
  required String label,
  Duration timeout = _kOperationTimeout,
  int maxRetries = _kMaxRetries,
}) async {
  int attempt = 0;
  while (true) {
    try {
      return await fn().timeout(timeout);
    } on TimeoutException {
      attempt++;
      if (attempt > maxRetries) {
        debugPrint('[SosEscalation] ❌ $label: timeout after $attempt');
        rethrow;
      }
      debugPrint('[SosEscalation] ⏱️ $label timeout — retry $attempt/$maxRetries');
      await Future.delayed(_kRetryDelay);
    } catch (e) {
      attempt++;
      if (attempt > maxRetries) {
        debugPrint('[SosEscalation] ❌ $label: $e');
        rethrow;
      }
      await Future.delayed(_kRetryDelay);
    }
  }
}

// ============================================================================
// CONTROLLER
// ============================================================================
class SosEscalationController {
  SosEscalationController({
    SosService? sos,
    SosCallBridge? bridge,
    this.delayPerCircle = const Duration(seconds: 15),
  })  : _sos = sos ?? SosService(),
        _bridge = bridge ?? SosCallBridge();

  final SosService _sos;
  final SosCallBridge _bridge;

  /// Délai avant passage au cercle suivant
  final Duration delayPerCircle;

  Timer? _timer;
  Timer? _countdown;
  String? _incidentId;
  int _currentCircle = 1;
  bool _takenOver = false;
  bool _stopped = false;
  bool _isStarting = false;       // ✅ anti-race start
  bool _isEscalating = false;     // ✅ anti-race escalate
  bool _isDisposed = false;       // ✅ disposed guard
  int _escalationAttempts = 0;    // ✅ max attempts guard

  SosEscalationTick? onTick;
  SosEscalationEvent? onEvent;

  int get currentCircle => _currentCircle;
  bool get isRunning => _timer != null || _countdown != null;

  // ========================================================================
  // START
  // ========================================================================
  /// Démarre après le trigger SOS (cercle 1 déjà appelé par le bridge)
  void start(String incidentId, {int startCircle = 1}) {
    // ✅ FIX P0 : validation + anti-race
    if (_isDisposed) {
      debugPrint('[SosEscalation] ⚠️ start() called on disposed controller');
      return;
    }
    if (!_EscalationValidators.isValidId(incidentId)) {
      debugPrint('[SosEscalation] ⚠️ Invalid incidentId: $incidentId');
      return;
    }
    if (_isStarting || isRunning) {
      debugPrint('[SosEscalation] ⚠️ Already starting/running');
      return;
    }
    _isStarting = true;

    try {
      stop();
      _incidentId = incidentId;
      _currentCircle = _EscalationValidators.clampCircle(startCircle);
      _takenOver = false;
      _stopped = false;
      _escalationAttempts = 0;

      _emitEvent('Cercle $_currentCircle en cours…');
      debugPrint('[SosEscalation] 🚀 Started on circle $_currentCircle for $incidentId');
      _scheduleNext();
    } finally {
      _isStarting = false;
    }
  }

  /// Appeler quand un secours prend en charge (Realtime / UI)
  void markTakenOver() {
    if (_isDisposed) return;
    if (_takenOver) return;
    _takenOver = true;
    stop();
    _emitEvent('SOS pris en charge — escalade arrêtée');
    debugPrint('[SosEscalation] ✓ Taken over — stopped');
  }

  void stop() {
    _stopped = true;
    _timer?.cancel();
    _countdown?.cancel();
    _timer = null;
    _countdown = null;
  }

  // ========================================================================
  // SCHEDULING
  // ========================================================================
  void _scheduleNext() {
    if (_isDisposed || _stopped || _takenOver) return;
    if (_currentCircle >= _kMaxCircle) {
      _emitEvent('Cercle $_kMaxCircle contacté — fin d\'escalade auto');
      debugPrint('[SosEscalation] ✓ Reached max circle $_kMaxCircle — stopping');
      stop();
      return;
    }

    // ✅ FIX : max attempts guard
    if (_escalationAttempts >= _kMaxEscalationAttempts) {
      _emitEvent('Trop de tentatives d\'escalade — arrêt');
      debugPrint('[SosEscalation] ⚠️ Max attempts reached ($_escalationAttempts)');
      stop();
      return;
    }

    final totalSec = delayPerCircle.inSeconds;
    var left = totalSec;
    _emitTick(_currentCircle, left);

    _countdown?.cancel();
    _countdown = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_isDisposed || _stopped || _takenOver) {
        t.cancel();
        return;
      }
      left--;
      // ✅ FIX : clamp strict
      _emitTick(_currentCircle, left.clamp(0, totalSec));
      if (left <= 0) t.cancel();
    });

    _timer?.cancel();
    _timer = Timer(delayPerCircle, () {
      if (_isDisposed || _stopped || _takenOver) return;
      unawaited(_escalate());
    });
  }

  // ========================================================================
  // ESCALATE — ✅ FIX syntax + timeouts + retry + validation
  // ========================================================================
  Future<void> _escalate() async {
    if (_isDisposed || _stopped || _takenOver) return;
    if (_isEscalating) {
      debugPrint('[SosEscalation] ⚠️ Escalate already in progress');
      return;
    }
    if (!_EscalationValidators.isValidId(_incidentId)) {
      debugPrint('[SosEscalation] ⚠️ Invalid incidentId, stopping');
      stop();
      return;
    }

    _isEscalating = true;
    _escalationAttempts++;

    final next = _currentCircle + 1;
    if (next > _kMaxCircle) {
      stop();
      _isEscalating = false;
      return;
    }

    try {
      debugPrint('[SosEscalation] 📈 Escalating to circle $next (attempt $_escalationAttempts)');

      // ✅ FIX : timeout + retry sur getIncidentById
      final incident = await _escalationRetry(
        () => _sos.getIncidentById(_incidentId!),
        label: 'getIncidentById[$_incidentId]',
      );

      // Re-check disposed/stopped après async
      if (_isDisposed || _stopped || _takenOver) return;

      if (incident == null || !incident.isActive) {
        debugPrint('[SosEscalation] ⏭️ Incident inactive — stopping');
        stop();
        _emitEvent('Incident inactif — escalade arrêtée');
        return;
      }

      // Prise en charge serveur
      if (incident.status == SosStatus.takenOver) {
        markTakenOver();
        return;
      }

      // Status terminaux — arrêt
      if (incident.status == SosStatus.resolved ||
          incident.status == SosStatus.cancelled ||
          incident.status == SosStatus.archived) {
        debugPrint('[SosEscalation] ⏭️ Incident status ${incident.status.name} — stopping');
        stop();
        _emitEvent('Incident ${incident.status.name} — escalade arrêtée');
        return;
      }

      // ✅ FIX : timeout + retry sur escalateToCircle
      _currentCircle = next;
      await _escalationRetry(
        () => _sos.escalateToCircle(_incidentId!, next),
        label: 'escalateToCircle[$next]',
      );

      if (_isDisposed || _stopped) return;
      _emitEvent('Escalade → Cercle $next');

      final contacts = await _escalationRetry(
        () => _sos.getContactsByCircle(next),
        label: 'getContactsByCircle[$next]',
      );

      if (_isDisposed || _stopped) return;

      final incidentForCall = incident.copyWith(
        status: next == 2
            ? SosStatus.callingCircle2
            : SosStatus.callingCircle3,
        activeCircle: next,
      );

      // ✅ FIX : timeout sur callCircle
      final result = await _escalationRetry(
        () => _bridge.callCircle(
          incident: incidentForCall,
          circle: next,
          contacts: contacts,
        ),
        label: 'callCircle[$next]',
      );

      if (_isDisposed || _stopped) return;

      // ✅ FIX : syntax error corrigée (interpolation Dart valide)
      debugPrint(
        '[SosEscalation] ✓ Circle $next: ${result.answeredOrRinging}/${result.calls.length} calls',
      );

      _emitEvent(
        'Cercle $next : ${result.answeredOrRinging} appel(s) lancé(s)',
      );

      _scheduleNext();
    } catch (e) {
      if (_isDisposed || _stopped) return;
      // ✅ FIX : log structuré sans stack trace
      final msg = e.toString();
      final shortMsg = msg.length > 120 ? '${msg.substring(0, 120)}…' : msg;
      debugPrint('[SosEscalation] ❌ _escalate failed: $shortMsg');
      _emitEvent('Erreur escalade (cercle $next)');

      // Continue la séquence (best-effort) — mais avec max attempts
      _scheduleNext();
    } finally {
      _isEscalating = false;
    }
  }

  // ========================================================================
  // SAFE EMITTERS — ✅ disposed checks
  // ========================================================================
  void _emitTick(int circle, int secondsLeft) {
    if (_isDisposed) return;
    try {
      onTick?.call(circle, secondsLeft);
    } catch (e) {
      debugPrint('[SosEscalation] ⚠️ onTick callback error: $e');
    }
  }

  void _emitEvent(String message) {
    if (_isDisposed) return;
    try {
      onEvent?.call(message);
    } catch (e) {
      debugPrint('[SosEscalation] ⚠️ onEvent callback error: $e');
    }
  }

  // ========================================================================
  // DISPOSE
  // ========================================================================
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    debugPrint('[SosEscalation] 👋 Disposed');
    stop();
    onTick = null;
    onEvent = null;
  }
}
