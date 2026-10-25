// lib/providers/podcast_player_provider.dart
import 'package:audio_service/audio_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

import '../models/news_article.dart';

// ═══════════════════════════════════════════════════════════════
// 🎧 LECTEUR PODCAST GLOBAL (Audio & Vidéo)
// - Survit à la navigation (provider global)
// - Continue hors application (just_audio_background)
// - ExoPlayer/AVPlayer extrait la piste audio des fichiers vidéo
// ═══════════════════════════════════════════════════════════════

bool isVideoPodcast(NewsArticle a) =>
    (a.videoUrl ?? '').isNotEmpty || a.title.toLowerCase().contains('vidéo');

class PodcastPlayerState {
  final NewsArticle? article;
  final bool isPlaying;
  final bool isLoading;
  final Duration position;
  final Duration duration;
  final String? error;

  const PodcastPlayerState({
    this.article,
    this.isPlaying = false,
    this.isLoading = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.error,
  });

  PodcastPlayerState copyWith({
    NewsArticle? article,
    bool? isPlaying,
    bool? isLoading,
    Duration? position,
    Duration? duration,
    String? error,
  }) =>
      PodcastPlayerState(
        article: article ?? this.article,
        isPlaying: isPlaying ?? this.isPlaying,
        isLoading: isLoading ?? this.isLoading,
        position: position ?? this.position,
        duration: duration ?? this.duration,
        error: error ?? this.error,
      );
}

class PodcastPlayerNotifier extends StateNotifier<PodcastPlayerState> {
  final AudioPlayer _player = AudioPlayer();

  PodcastPlayerNotifier() : super(const PodcastPlayerState()) {
    _player.playerStateStream.listen((ps) {
      if (!mounted) return;
      final loading = ps.processingState == ProcessingState.loading ||
          ps.processingState == ProcessingState.buffering;
      state = state.copyWith(isPlaying: ps.playing, isLoading: loading);
      if (ps.processingState == ProcessingState.completed) {
        _player.seek(Duration.zero);
        _player.pause();
      }
    });
    _player.positionStream.listen((p) {
      if (mounted) state = state.copyWith(position: p);
    });
    _player.durationStream.listen((d) {
      if (mounted) state = state.copyWith(duration: d ?? Duration.zero);
    });
  }

  String? mediaUrl(NewsArticle a) {
    final v = a.videoUrl;
    if (v != null && v.isNotEmpty) return v;
    final au = a.audioUrl;
    if (au != null && au.isNotEmpty) return au;
    return null;
  }

  /// Lance un épisode, ou play/pause si c'est déjà l'épisode actif.
  Future<void> playArticle(NewsArticle a) async {
    final url = mediaUrl(a);
    if (url == null) {
      state = state.copyWith(
          article: a, error: 'Aucun fichier média associé à cet épisode.');
      return;
    }

    if (state.article?.id == a.id) return toggle();

    // Nouvel épisode → reset complet (efface aussi l'erreur précédente)
    state = PodcastPlayerState(article: a, isLoading: true);
    try {
      await _player.setAudioSource(
        AudioSource.uri(
          Uri.parse(url),
          tag: MediaItem(
            id: a.id,
            title: a.title,
            album: 'THIX Info',
            artist: isVideoPodcast(a) ? 'THIX Podcast Vidéo' : 'THIX Podcast Audio',
            artUri: a.imageUrl != null ? Uri.parse(a.imageUrl!) : null,
            displayDescription: a.summary,
          ),
        ),
      );
      await _player.play();
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Lecture impossible : $e');
    }
  }

  Future<void> toggle() async {
    if (state.article == null) return;
    if (_player.playing) {
      await _player.pause();
    } else {
      await _player.play();
    }
  }

  Future<void> seek(Duration d) => _player.seek(d);

  Future<void> skipBy(int seconds) =>
      _player.seek(state.position + Duration(seconds: seconds));

  /// Stoppe tout et retire le mini-player.
  Future<void> stop() async {
    await _player.stop();
    state = const PodcastPlayerState();
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }
}

final podcastPlayerProvider =
    StateNotifierProvider<PodcastPlayerNotifier, PodcastPlayerState>(
        (ref) => PodcastPlayerNotifier());
