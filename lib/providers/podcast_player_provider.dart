// lib/providers/podcast_player_provider.dart
import 'package:flutter/foundation.dart'; // Pour debugPrint
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

import '../models/news_article.dart';

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
    bool clearError = false, // ✅ Permet d'effacer l'erreur
  }) =>
      PodcastPlayerState(
        article: article ?? this.article,
        isPlaying: isPlaying ?? this.isPlaying,
        isLoading: isLoading ?? this.isLoading,
        position: position ?? this.position,
        duration: duration ?? this.duration,
        error: clearError ? null : (error ?? this.error),
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
    // Priorité à l'audio pour les podcasts
    final au = a.audioUrl;
    if (au != null && au.isNotEmpty) return au;
    final v = a.videoUrl;
    if (v != null && v.isNotEmpty) return v;
    return null;
  }

  Future<void> playArticle(NewsArticle a) async {
    final url = mediaUrl(a);
    if (url == null) {
      state = state.copyWith(
          article: a, error: 'Aucun fichier média associé à cet épisode.');
      return;
    }

    if (state.article?.id == a.id) return toggle();

    state = PodcastPlayerState(article: a, isLoading: true);
    
    try {
      debugPrint('🎧 [Podcast] Tentative de lecture: $url');
      
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
      debugPrint('❌ [Podcast] Erreur lecture: $e');
      state = state.copyWith(
        isLoading: false, 
        error: 'Lecture impossible : $e',
      );
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
