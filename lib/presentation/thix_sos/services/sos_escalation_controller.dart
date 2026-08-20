/// THIX SOS — Escalade automatique des cercles (production)
import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/sos_models.dart';
import 'sos_call_bridge.dart';
import 'sos_service.dart';

typedef SosEscalationTick = void Function(int circle, int secondsLeft);
typedef SosEscalationEvent = void Function(String message);

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

  SosEscalationTick? onTick;
  SosEscalationEvent? onEvent;

  int get currentCircle => _currentCircle;
  bool get isRunning => _timer != null || _countdown != null;

  /// Démarre après le trigger SOS (cercle 1 déjà appelé par le bridge)
  void start(String incidentId, {int startCircle = 1}) {
    stop();
    _incidentId = incidentId;
    _currentCircle = startCircle.clamp(1, 3);
    _takenOver = false;
    _stopped = false;

    onEvent?.call('Cercle $_currentCircle en cours…');
    _scheduleNext();
  }

  /// Appeler quand un secours prend en charge (Realtime / UI)
  void markTakenOver() {
    _takenOver = true;
    stop();
    onEvent?.call('SOS pris en charge — escalade arrêtée');
  }

  void stop() {
    _stopped = true;
    _timer?.cancel();
    _countdown?.cancel();
    _timer = null;
    _countdown = null;
  }

  void _scheduleNext() {
    if (_stopped || _takenOver) return;
    if (_currentCircle >= 3) {
      onEvent?.call('Cercle 3 contacté — fin d\'escalade auto');
      return;
    }

    final totalSec = delayPerCircle.inSeconds;
    var left = totalSec;
    onTick?.call(_currentCircle, left);

    _countdown?.cancel();
    _countdown = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_stopped || _takenOver) {
        t.cancel();
        return;
      }
      left--;
      onTick?.call(_currentCircle, left.clamp(0, totalSec));
      if (left <= 0) t.cancel();
    });

    _timer?.cancel();
    _timer = Timer(delayPerCircle, () => unawaited(_escalate()));
  }

  Future<void> _escalate() async {
    if (_stopped || _takenOver || _incidentId == null) return;

    final next = _currentCircle + 1;
    if (next > 3) return;

    try {
      final incident = await _sos.getIncidentById(_incidentId!);
      if (incident == null || !incident.isActive) {
        stop();
        return;
      }

      // Prise en charge serveur
      if (incident.status == SosStatus.takenOver) {
        markTakenOver();
        return;
      }

      _currentCircle = next;
      await _sos.escalateToCircle(_incidentId!, next);
      onEvent?.call('Escalade → Cercle $next');

      final contacts = await _sos.getContactsByCircle(next);

      final incidentForCall = incident.copyWith(
        status: next == 2
            ? SosStatus.callingCircle2
            : SosStatus.callingCircle3,
        activeCircle: next,
      );

      final result = await _bridge.callCircle(
        incident: incidentForCall,
        circle: next, // ← requis par SosCallBridge
        contacts: contacts,
      );

      debugPrint(
        'Escalade cercle $next: '
        '\( {result.answeredOrRinging}/ \){result.calls.length} appels',
      );

      onEvent?.call(
        'Cercle $next : ${result.answeredOrRinging} appel(s) lancé(s)',
      );

      _scheduleNext();
    } catch (e, st) {
      debugPrint('SosEscalationController._escalate: $e\n$st');
      onEvent?.call('Erreur escalade: $e');
      _scheduleNext();
    }
  }

  void dispose() => stop();
}
