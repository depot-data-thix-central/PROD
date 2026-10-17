// lib/services/chat/call_handled_registry.dart
//
// Registre partagé entre PushNotificationService (CallKit) et GlobalCallListener
// (écran d'appel dans l'app). Il évite :
//  - le double écran d'appel (CallKit + page dans l'app)
//  - le rejet automatique d'un appel déjà accepté depuis CallKit
//  - les sonneries fantômes d'un appel déjà terminé
//  - un refus CallKit jamais transmis à l'appelant
import 'dart:async';

class CallHandledRegistry {
  CallHandledRegistry._();

  static const int _maxEntries = 50;

  static final List<String> _accepted = <String>[];
  static final List<String> _shownInApp = <String>[];
  static final List<String> _ended = <String>[];

  static final StreamController<String> _acceptedCtrl =
      StreamController<String>.broadcast();
  static final StreamController<String> _declinedCtrl =
      StreamController<String>.broadcast();

  /// true = première fois, false = doublon déjà traité.
  static bool _add(List<String> list, String id) {
    if (id.isEmpty) return true;
    if (list.contains(id)) return false;
    list.add(id);
    if (list.length > _maxEntries) list.removeAt(0);
    return true;
  }

  // ── Accepté (CallKit) ────────────────────────────────────────
  /// true = première acceptation (à traiter), false = doublon.
  static bool markAccepted(String id) {
    final first = _add(_accepted, id);
    if (first && id.isNotEmpty) _acceptedCtrl.add(id);
    return first;
  }

  static bool isAccepted(String id) => id.isNotEmpty && _accepted.contains(id);

  // ── Affiché dans l'app (IncomingCallPage) ────────────────────
  static void markShownInApp(String id) {
    _add(_shownInApp, id);
  }

  static bool isShownInApp(String id) =>
      id.isNotEmpty && _shownInApp.contains(id);

  // ── Terminé / refusé / raccroché ─────────────────────────────
  static void markEnded(String id) {
    _add(_ended, id);
  }

  static bool isEnded(String id) => id.isNotEmpty && _ended.contains(id);

  /// Refus depuis CallKit : l'app doit prévenir le serveur.
  static void emitDeclined(String id) {
    markEnded(id);
    if (id.isNotEmpty) _declinedCtrl.add(id);
  }

  static Stream<String> get acceptedStream => _acceptedCtrl.stream;
  static Stream<String> get declinedStream => _declinedCtrl.stream;
}
