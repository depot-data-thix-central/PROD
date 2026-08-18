// lib/utils/ephemeral_manager.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart'; // 🌟 CORRECTION 1 : Import indispensable pour StatefulWidget et State

/// Gestionnaire des timers pour les messages éphémères
class EphemeralManager {
  final Map<String, Timer> _timers = {};
  final Map<String, VoidCallback> _callbacks = {};

  /// Démarre un timer pour un message
  /// [messageId] : identifiant unique du message
  /// [duration] : durée en secondes avant expiration
  /// [onExpired] : callback appelé lorsque le timer expire
  void startTimer(String messageId, int duration, VoidCallback onExpired) {
    // Annuler un éventuel timer existant
    cancelTimer(messageId);

    _callbacks[messageId] = onExpired;

    final timer = Timer(Duration(seconds: duration), () {
      // Appeler le callback
      if (_callbacks.containsKey(messageId)) {
        _callbacks[messageId]!();
        // Nettoyer après appel
        _callbacks.remove(messageId);
        _timers.remove(messageId);
      }
    });

    _timers[messageId] = timer;
    if (kDebugMode) {
      print('⏳ Timer démarré pour message $messageId (${duration}s)');
    }
  }

  /// Annule un timer pour un message
  void cancelTimer(String messageId) {
    if (_timers.containsKey(messageId)) {
      _timers[messageId]!.cancel();
      _timers.remove(messageId);
      _callbacks.remove(messageId);
      if (kDebugMode) {
        print('⏹️ Timer annulé pour message $messageId');
      }
    }
  }

  /// Vérifie si un timer est actif pour un message
  bool isTimerActive(String messageId) {
    return _timers.containsKey(messageId);
  }

  /// Annule tous les timers (à appeler en fin de session)
  void cancelAll() {
    for (var timer in _timers.values) {
      timer.cancel();
    }
    _timers.clear();
    _callbacks.clear();
    if (kDebugMode) {
      print('⏹️ Tous les timers ont été annulés');
    }
  }

  /// Met à jour un timer existant avec une nouvelle durée
  void updateTimer(String messageId, int newDuration, VoidCallback onExpired) {
    cancelTimer(messageId);
    startTimer(messageId, newDuration, onExpired);
  }

  /// Obtient le temps restant pour un message (en secondes)
  /// Retourne -1 si aucun timer n'est actif
  int getRemainingTime(String messageId) {
    if (!_timers.containsKey(messageId)) return -1;
    
    // 🌟 CORRECTION 2 : Suppression de la variable "timer" non utilisée 
    // qui causait le warning dans GitHub Actions
    
    // On ne peut pas obtenir directement le temps restant avec Timer,
    // donc on retourne -1 (l'UI devra stocker le temps restant séparément)
    return -1;
  }

  /// Nettoyage complet
  void dispose() {
    cancelAll();
  }
}

/// Mixin pour intégrer facilement le gestionnaire dans un StatefulWidget
mixin EphemeralMixin<T extends StatefulWidget> on State<T> {
  final EphemeralManager ephemeralManager = EphemeralManager();

  @override
  void dispose() {
    ephemeralManager.dispose();
    super.dispose();
  }
}
