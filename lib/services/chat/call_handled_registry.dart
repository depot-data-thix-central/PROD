// lib/services/chat/call_handled_registry.dart
//
// Registre partagé entre PushNotificationService (CallKit) et GlobalCallListener
// (écran d'appel dans l'app).
//
// CHANGELOG v2.5 :
//   ✅ markShownCallkit ne marque plus _shownInApp (les deux sources sont
//      distinctes ; chaque consommateur teste isShownCallkit lui-même)
//   ✅ markDeclineSent / isDeclineSent : un refus n'est envoyé qu'une fois
//
// CHANGELOG v2.4 :
//   ✅ markShownCallkit / isShownCallkit
// ============================================================================
import 'dart:async';

class CallHandledRegistry {
  CallHandledRegistry._();

  static const int _maxEntries = 50;

  static final List<String> _accepted = <String>[];
  static final List<String> _shownInApp = <String>[];
  static final List<String> _shownCallkit = <String>[];
  static final List<String> _ended = <String>[];
  static final List<String> _declineSent = <String>[];

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

  // ── Affiché via CallKit (UI système) ─────────────────────────
  static void markShownCallkit(String id) {
    _add(_shownCallkit, id);
  }

  static bool isShownCallkit(String id) =>
      id.isNotEmpty && _shownCallkit.contains(id);

  // ── Terminé / refusé / raccroché ─────────────────────────────
  static void markEnded(String id) {
    _add(_ended, id);
  }

  static bool isEnded(String id) => id.isNotEmpty && _ended.contains(id);

  // ── Refus transmis au serveur ────────────────────────────────
  /// true = première fois (à envoyer), false = déjà envoyé / en cours.
  static bool markDeclineSent(String id) => _add(_declineSent, id);

  static bool isDeclineSent(String id) =>
      id.isNotEmpty && _declineSent.contains(id);

  /// Annule la marque (échec d'envoi : permet une nouvelle tentative).
  static void clearDeclineSent(String id) => _declineSent.remove(id);

  /// Refus depuis CallKit : l'app doit prévenir le serveur.
  static void emitDeclined(String id) {
    markEnded(id);
    if (id.isNotEmpty) _declinedCtrl.add(id);
  }

  static Stream<String> get acceptedStream => _acceptedCtrl.stream;
  static Stream<String> get declinedStream => _declinedCtrl.stream;

  static Map<String, dynamic> debugSnapshot(String id) => {
        'accepted': isAccepted(id),
        'shownInApp': isShownInApp(id),
        'shownCallkit': isShownCallkit(id),
        'ended': isEnded(id),
        'declineSent': isDeclineSent(id),
      };
}
