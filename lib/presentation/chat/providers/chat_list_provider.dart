// lib/presentation/chat/providers/chat_list_provider.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:thix_id/services/chat/status_service.dart';
import 'package:thix_id/services/chat/chat_service.dart';
import 'package:thix_id/services/chat/presence_service.dart';
import 'package:thix_id/models/chat/chat_conversation.dart';
import 'package:thix_id/presentation/chat/providers/chat_providers.dart';

// ============================================================
// STATE
// ============================================================

class ChatListState {
  final List<ChatConversation> all;
  final List<ChatConversation> filtered;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final int totalUnread;
  final int pendingEscalations;
  final int filterIndex;
  final String searchQuery;

  const ChatListState({
    this.all = const [],
    this.filtered = const [],
    this.isLoading = true,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.totalUnread = 0,
    this.pendingEscalations = 0,
    this.filterIndex = 0,
    this.searchQuery = '',
  });

  ChatListState copyWith({
    List<ChatConversation>? all,
    List<ChatConversation>? filtered,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    int? totalUnread,
    int? pendingEscalations,
    int? filterIndex,
    String? searchQuery,
  }) {
    return ChatListState(
      all: all ?? this.all,
      filtered: filtered ?? this.filtered,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      totalUnread: totalUnread ?? this.totalUnread,
      pendingEscalations: pendingEscalations ?? this.pendingEscalations,
      filterIndex: filterIndex ?? this.filterIndex,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }

  bool get isEmpty => filtered.isEmpty && !isLoading;
}

// ============================================================
// NOTIFIER
// ============================================================

class ChatListNotifier extends StateNotifier<ChatListState> {
  final ChatService _chatService;
  final PresenceService _presenceService;

  static const int _limit = 20;

  Timer? _debounce;
  Timer? _refreshDebounce; // ✅ NOUVEAU : Debounce pour les refresh temps réel
  RealtimeChannel? _channel;
  bool _isDisposed = false;

  ChatListNotifier(this._chatService, this._presenceService)
      : super(const ChatListState()) {
    _presenceService.initPresence();
    _subscribeRealtime();
    loadInitial();
  }

  void _subscribeRealtime() {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;

    _channel = Supabase.instance.client
        .channel('thix_chat_list_$uid')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          callback: (payload) async {
            if (_isDisposed) return;

            try {
              final raw = payload.newRecord;
              if (raw != null) {
                final senderId = raw['sender_id']?.toString();
                final msgId = raw['id']?.toString();
                final me = uid;

                if (senderId != null &&
                    senderId != me &&
                    msgId != null &&
                    msgId.isNotEmpty) {
                  unawaited(
                    Supabase.instance.client
                        .from('messages')
                        .update({'is_delivered': true})
                        .eq('id', msgId)
                        .eq('is_delivered', false),
                  );
                }
              }
            } catch (e) {
              debugPrint('⚠️ mark delivered from list: $e');
            }

            // ✅ OPTIMISATION : Debounce le refresh pour éviter les refreshs multiples
            _scheduleRefresh();
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'messages',
          callback: (_) {
            if (!_isDisposed) {
              _refreshCounts();
              _scheduleRefresh();
            }
          },
        )
        .subscribe();
  }

  // ✅ NOUVEAU : Debounce pour éviter les refreshs multiples en cascade
  void _scheduleRefresh() {
    _refreshDebounce?.cancel();
    _refreshDebounce = Timer(const Duration(milliseconds: 500), () {
      if (!_isDisposed) {
        loadInitial(silent: true);
      }
    });
  }

  Future<void> loadInitial({bool silent = false}) async {
    if (!silent) {
      state = state.copyWith(isLoading: true);
    }

    try {
      final convs = await _chatService.getConversations(
        limit: _limit,
        offset: 0,
      );
      final unread = await _chatService.getTotalUnreadCount();
      final escalations = await _getPendingEscalations();

      if (_isDisposed) return;

      state = state.copyWith(
        all: convs,
        totalUnread: unread,
        pendingEscalations: escalations,
        hasMore: convs.length == _limit,
        isLoading: false,
      );

      _applyFilter();
    } catch (e) {
      debugPrint('❌ loadInitial error: $e');
      if (!_isDisposed) {
        state = state.copyWith(isLoading: false);
      }
    }
  }

  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasMore || state.isLoading) return;

    state = state.copyWith(isLoadingMore: true);

    try {
      final newConvs = await _chatService.getConversations(
        limit: _limit,
        offset: state.all.length,
      );

      if (_isDisposed) return;

      final merged = <ChatConversation>[...state.all, ...newConvs];
      final seen = <String>{};
      final deduped = merged.where((c) => seen.add(c.id)).toList();

      state = state.copyWith(
        all: deduped,
        hasMore: newConvs.length == _limit,
        isLoadingMore: false,
      );

      _applyFilter();
    } catch (e) {
      debugPrint('❌ loadMore error: $e');
      if (!_isDisposed) {
        state = state.copyWith(isLoadingMore: false);
      }
    }
  }

  Future<void> refresh({bool silent = false}) => loadInitial(silent: silent);

  Future<void> _refreshCounts() async {
    try {
      final unread = await _chatService.getTotalUnreadCount();
      if (!_isDisposed) {
        state = state.copyWith(totalUnread: unread);
      }
    } catch (_) {}
  }

  Future<int> _getPendingEscalations() async {
    final u = Supabase.instance.client.auth.currentUser;
    if (u == null) return 0;

    try {
      final r = await Supabase.instance.client
          .from('escalation_steps')
          .select('id')
          .eq('to_agent_id', u.id)
          .eq('status', 0)
          .count();

      return (r.count as int?) ?? 0;
    } catch (_) {
      return 0;
    }
  }

  void search(String raw) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (_isDisposed) return;
      state = state.copyWith(searchQuery: raw.trim().toLowerCase());
      _applyFilter();
    });
  }

  void setFilter(int idx) {
    state = state.copyWith(filterIndex: idx);
    _applyFilter();
  }

  void _applyFilter() {
    List<ChatConversation> base = List<ChatConversation>.from(state.all);

    if (state.searchQuery.isNotEmpty) {
      final q = state.searchQuery;
      base = base.where((c) {
        return c.displayName.toLowerCase().contains(q) ||
            (c.lastMessage?.content ?? '').toLowerCase().contains(q);
      }).toList();
    }

    switch (state.filterIndex) {
      case 1:
        base = base.where((c) => c.unreadCount > 0).toList();
        break;
      case 2:
        base = base.where((c) => c.isGroup).toList();
        break;
      case 3:
        base = base.where((c) => !c.isGroup).toList();
        break;
      default:
        break;
    }

    state = state.copyWith(filtered: base);
  }

  Future<void> markAsRead(String convId) async {
    final updated = state.all.map((c) {
      if (c.id == convId) return c.copyWith(unreadCount: 0);
      return c;
    }).toList();

    state = state.copyWith(all: updated);
    _applyFilter();

    try {
      await _chatService.markConversationAsRead(convId);
      await _refreshCounts();
    } catch (e) {
      debugPrint('❌ markAsRead error: $e');
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _debounce?.cancel();
    _refreshDebounce?.cancel();
    _channel?.unsubscribe();
    super.dispose();
  }
}

// ============================================================
// PROVIDERS
// ============================================================

final statusServiceProvider = Provider<StatusService>((ref) {
  return StatusService(Supabase.instance.client);
});

final chatListProvider =
    StateNotifierProvider<ChatListNotifier, ChatListState>((ref) {
  final chatService = ref.watch(chatServiceProvider);
  final presenceService = ref.watch(presenceServiceProvider);
  return ChatListNotifier(chatService, presenceService);
});
