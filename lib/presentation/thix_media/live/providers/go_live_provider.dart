// lib/presentation/thix_media/live/providers/go_live_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/live_service.dart';

final liveServiceProvider = Provider<LiveService>((ref) => LiveService());

/// État du démarrage Go Live
sealed class GoLiveState {
  const GoLiveState();
}

class GoLiveIdle extends GoLiveState {
  const GoLiveIdle();
}

class GoLiveLoading extends GoLiveState {
  const GoLiveLoading();
}

class GoLiveReady extends GoLiveState {
  final LiveSession session;
  final AgoraCredentials creds;
  const GoLiveReady(this.session, this.creds);
}

class GoLiveError extends GoLiveState {
  final String message;
  const GoLiveError(this.message);
}

class GoLiveNotifier extends StateNotifier<GoLiveState> {
  GoLiveNotifier(this._liveService) : super(const GoLiveIdle());

  final LiveService _liveService;

  Future<void> start({
    required String title,
    String category = 'Général',
  }) async {
    state = const GoLiveLoading();
    try {
      final result = await _liveService.startLive(
        title: title,
        category: category,
      );
      state = GoLiveReady(result.session, result.creds);
    } catch (e) {
      state = GoLiveError(e.toString());
    }
  }

  void reset() => state = const GoLiveIdle();
}

final goLiveNotifierProvider =
    StateNotifierProvider.autoDispose<GoLiveNotifier, GoLiveState>((ref) {
  return GoLiveNotifier(ref.watch(liveServiceProvider));
});
