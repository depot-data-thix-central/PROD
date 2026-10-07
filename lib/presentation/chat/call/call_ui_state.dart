// lib/presentation/chat/call/call_ui_state.dart
//
// État d'affichage de l'écran d'appel : sert à savoir si la page d'appel est
// ouverte, pour n'afficher la barre « Appel en cours » que lorsqu'elle est réduite.

import 'dart:async';

import 'package:flutter/foundation.dart';

/// Nombre de pages d'appel actuellement ouvertes (0 = page réduite ou fermée).
final ValueNotifier<int> callPageOpenCount = ValueNotifier<int>(0);

/// À appeler dans initState de CallPage.
/// Différé en microtâche : on ne modifie jamais un notifier pendant la construction de l'arbre.
void markCallPageOpened() {
  scheduleMicrotask(() => callPageOpenCount.value = callPageOpenCount.value + 1);
}

/// À appeler dans dispose de CallPage.
void markCallPageClosed() {
  scheduleMicrotask(() {
    final next = callPageOpenCount.value - 1;
    callPageOpenCount.value = next < 0 ? 0 : next;
  });
}
