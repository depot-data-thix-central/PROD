// lib/presentation/thix_weeding/pages/staff/playlist/playlist_audio_controller.dart
// ============================================================================
// THIX WEDDING — LECTEUR AUDIO COMMUN (staff + invités)
// ✅ Un lecteur NEUF par titre (évite LateInitializationError sur le web)
// ✅ Erreurs de chargement gérées (fichier introuvable, format, délai 25 s)
// ✅ Lecture / pause / arrêt / déplacement dans le titre, état partagé
// ============================================================================
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

class PlaylistAudioController extends ChangeNotifier {
  AudioPlayer? _p;
  final List<StreamSubscription> _subs = [];
  bool _disposed = false;

  String? currentId;
  bool playing = false;
  bool loading = false;
  Duration position = Duration.zero;
  Duration duration = Duration.zero;

  /// Dernier message d'erreur (à afficher puis effacer avec [clearError]).
  String? error;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void clearError() => error = null;

  Future<void> _release() async {
    for (final s in _subs) {
      try {
        await s.cancel();
      } catch (_) {}
    }
    _subs.clear();
    final p = _p;
    _p = null;
    if (p != null) {
      try {
        await p.stop();
      } catch (_) {}
      try {
        await p.dispose();
      } catch (_) {}
    }
  }

  /// Lit le titre, ou fait pause / reprise si c'est déjà le titre en cours.
  Future<void> toggle(String id, String? url) async {
    if (url == null || url.trim().isEmpty) {
      error = 'Aucun fichier audio pour ce titre';
      _notify();
      return;
    }

    // Même titre : pause / reprise
    if (currentId == id && _p != null && !loading) {
      try {
        if (playing) {
          await _p!.pause();
        } else {
          unawaited(_p!.play());
        }
      } catch (_) {}
      return;
    }

    await _release();
    currentId = id;
    loading = true;
    playing = false;
    position = Duration.zero;
    duration = Duration.zero;
    error = null;
    _notify();

    final player = AudioPlayer();
    _p = player;

    try {
      _subs.add(player.playerStateStream.listen((st) {
        if (_p != player) return;
        playing = st.playing && st.processingState != ProcessingState.completed;
        if (st.processingState == ProcessingState.completed) {
          // fin du titre : on revient à l'état « arrêté »
          unawaited(stop());
          return;
        }
        _notify();
      }, onError: (_) {}));
      _subs.add(player.positionStream.listen((d) {
        if (_p != player) return;
        position = d;
        _notify();
      }, onError: (_) {}));
      _subs.add(player.durationStream.listen((d) {
        if (_p != player) return;
        duration = d ?? Duration.zero;
        _notify();
      }, onError: (_) {}));

      await player
          .setAudioSource(AudioSource.uri(Uri.parse(url)))
          .timeout(const Duration(seconds: 25));

      if (_p != player) return; // un autre titre a été lancé entre-temps
      loading = false;
      _notify();
      unawaited(player.play().catchError((_) {}));
    } on TimeoutException {
      await _fail(player, 'Chargement trop long — vérifiez la connexion');
    } catch (e) {
      await _fail(player, 'Lecture impossible : fichier introuvable ou format non pris en charge');
    }
  }

  Future<void> _fail(AudioPlayer player, String msg) async {
    if (_p != player) return;
    await _release();
    currentId = null;
    playing = false;
    loading = false;
    position = Duration.zero;
    duration = Duration.zero;
    error = msg;
    _notify();
  }

  Future<void> seek(Duration d) async {
    try {
      await _p?.seek(d);
    } catch (_) {}
  }

  Future<void> stop() async {
    await _release();
    currentId = null;
    playing = false;
    loading = false;
    position = Duration.zero;
    duration = Duration.zero;
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_release());
    super.dispose();
  }
}
