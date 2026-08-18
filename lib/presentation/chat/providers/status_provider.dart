// lib/presentation/chat/providers/status_provider.dart
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:thix_id/models/chat/user_status_story.dart';
import 'package:thix_id/presentation/chat/providers/chat_providers.dart';

class StatusState {
  final List<UserStatusStory> items;
  final bool isLoading;
  final String? error;

  const StatusState({
    this.items = const [],
    this.isLoading = true,
    this.error,
  });

  StatusState copyWith({
    List<UserStatusStory>? items,
    bool? isLoading,
    String? error,
  }) {
    return StatusState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  /// Groupé par user pour l’UI (pastilles)
  Map<String, List<UserStatusStory>> get byUser {
    final map = <String, List<UserStatusStory>>{};
    for (final s in items) {
      map.putIfAbsent(s.userId, () => []).add(s);
    }
    return map;
  }

  /// Users ordonnés : moi d’abord, puis non vus, puis vus
  List<String> get orderedUserIds {
    final map = byUser;
    final mine = <String>[];
    final unseen = <String>[];
    final seen = <String>[];

    for (final entry in map.entries) {
      final list = entry.value;
      final isMine = list.any((s) => s.isMine);
      final allViewed = list.every((s) => s.hasViewed || s.isMine);

      if (isMine) {
        mine.add(entry.key);
      } else if (allViewed) {
        seen.add(entry.key);
      } else {
        unseen.add(entry.key);
      }
    }
    return [...mine, ...unseen, ...seen];
  }
}

class StatusNotifier extends StateNotifier<StatusState> {
  final Ref _ref;

  StatusNotifier(this._ref) : super(const StatusState()) {
    load();
  }

  Future<void> load() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final items =
          await _ref.read(statusServiceProvider).getVisibleStatuses();
      state = state.copyWith(items: items, isLoading: false);
    } catch (e) {
      debugPrint('❌ StatusNotifier.load: $e');
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> refresh() => load();

  Future<bool> createText(String content, {String background = '#1D4ED8'}) async {
    final id = await _ref.read(statusServiceProvider).createTextStatus(
          content: content,
          background: background,
        );
    if (id != null) {
      await load();
      return true;
    }
    return false;
  }

  Future<void> markViewed(String statusId) async {
    await _ref.read(statusServiceProvider).markViewed(statusId);
    // Optimistic
    state = state.copyWith(
      items: state.items
          .map((s) => s.statusId == statusId
              ? UserStatusStory(
                  statusId: s.statusId,
                  userId: s.userId,
                  displayName: s.displayName,
                  avatarUrl: s.avatarUrl,
                  content: s.content,
                  mediaUrl: s.mediaUrl,
                  mediaType: s.mediaType,
                  background: s.background,
                  createdAt: s.createdAt,
                  expiresAt: s.expiresAt,
                  isMine: s.isMine,
                  hasViewed: true,
                )
              : s)
          .toList(),
    );
  }
}

final statusProvider =
    StateNotifierProvider<StatusNotifier, StatusState>((ref) {
  return StatusNotifier(ref);
});
