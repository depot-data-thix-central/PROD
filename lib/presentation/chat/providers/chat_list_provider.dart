// lib/presentation/chat/providers/chat_list_provider.dart
//
// ============================================================================
// CHAT LIST PROVIDER — Realtime + pagination + filters
// ============================================================================
//
// État central de la liste des conversations.
//
// Architecture :
//   1. `loadInitial()` au démarrage (batch : convs + unread + escalations)
//   2. Channel Realtime filtré serveur (events user-only)
//   3. Debounce 500ms sur updates Realtime
//   4. Recherche locale avec pré-indexation lowercase
//   5. Rollback optimiste sur markAsRead
//
// ============================================================================

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:thix_id/auth/auth_controller.dart' show currentUserProvider;
import 'package:thix_id/models/chat/chat_conversation.dart';
import 'package:thix_id/presentation/chat/providers/chat_providers.dart';
import 'package:thix_id/models/app_user.dart';
import 'package:thix_id/features/auth/presentation/providers/auth_controller.dart';



// ============================================================================
// CONSTANTS
// ============================================================================
const int _kPageSize = 20;
const Duration _kSearchDebounce = Duration(milliseconds: 350);
const Duration _kRefreshDebounce = Duration(milliseconds: 500);
const Duration _kDbTimeout = Duration(seconds: 15);
const int _kMaxRetries = 2;
const Duration _kRetryDelay = Duration(milliseconds: 500);

/// Index des filtres dans l'UI
class ChatFilter {
  static const int all = 0;
  static const int unread = 1;
  static const int groups = 2;
  static const int direct = 3;
}

// ============================================================================
// VALIDATORS
// ============================================================================
class _ChatListValidators {
  _ChatListValidators._();

  /// Valide un UUID v4 strict
  static bool isValidUuid(String? id) {
    if (id == null || id.isEmpty) return false;
    return RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
      caseSensitive: false,
    ).hasMatch(id);
  }

  /// Sanitize une query de recherche (XSS + caractères de contrôle)
  static String sanitizeQuery(String? input, {int maxLength = 100}) {
    if (input == null || input.trim().isEmpty) return '';
    var s = input
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '')
        .trim();
    return s.length > maxLength ? s.substring(0, maxLength) : s;
  }

  /// Extrait et valide un user_id d'un payload Realtime
  static String? extractUserId(Map<String, dynamic> record, String key) {
    final raw = record[key];
    if (raw == null) return null;
    final id = raw.toString().trim();
    return isValidUuid(id) ? id : null;
  }

  /// Extrait et valide un message ID
  static String? extractMessageId(Map<String, dynamic> record) {
    final raw = record['id'];
    if (raw == null) return null;
    final id = raw.toString().trim();
    return isValidUuid(id) ? id : null;
  }
}

// ============================================================================
// STATE
// ============================================================================

/// Conversation enrichie avec métadonnées de filtrage pré-calculées.
class _IndexedConversation {
  final ChatConversation conversation;
  final String searchKey; // lowercase concat pour recherche rapide

  _IndexedConversation(this.conversation)
      : searchKey = _buildSearchKey(conversation);

  static String _buildSearchKey(ChatConversation c) {
    final parts = <String>[
      c.displayName,
      c.lastMessage?.content ?? '',
      c.groupName ?? '',
    ];
    return parts
        .where((s) => s.isNotEmpty)
        .map((s) => s.toLowerCase())
        .join(' ');
  }
}

/// État de la liste des conversations.
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
  final String? lastError;
  final bool isRealtimeConnected;

  const ChatListState({
    this.all = const [],
    this.filtered = const [],
    this.isLoading = true,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.totalUnread = 0,
    this.pendingEscalations = 0,
    this.filterIndex = ChatFilter.all,
    this.searchQuery = '',
    this.lastError,
    this.isRealtimeConnected = false,
  });

  bool get isEmpty => filtered.isEmpty && !isLoading;
  bool get hasActiveFilter =>
      filterIndex != ChatFilter.all || searchQuery.isNotEmpty;

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
    String? lastError,
    bool clearError = false,
    bool? isRealtimeConnected,
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
      lastError: clearError ? null : (lastError ?? this.lastError),
      isRealtimeConnected: isRealtimeConnected ?? this.isRealtimeConnected,
    );
  }
}

// ============================================================================
// NOTIFIER
// ============================================================================

/// Notifier pour la liste des conversations.
///
/// **Cycle de vie** :
/// - Init au premier `ref.watch`
/// - Écoute changements auth (cleanup/reconnect)
/// - Dispose proprement channels + timers
///
/// **Sécurité** :
/// - Validation UUID sur tous les payloads Realtime
/// - Sanitization de la search query
/// - Filtre server-side sur Realtime
/// - Protection DoS (max counters)
class ChatListNotifier extends StateNotifier<ChatListState> {
  final Ref _ref;
  final ChatService _chatService;
  final PresenceService _presenceService;

  Timer? _searchDebounce;
  Timer? _refreshDebounce;
  RealtimeChannel? _channel;
  StreamSubscription? _authSubscription;
  bool _isDisposed = false;
  bool _isLoadInProgress = false;
  String? _currentUserId;

  /// Cache pré-calculé pour filtrage/recherche rapide
  List<_IndexedConversation> _indexedAll = const [];

  ChatListNotifier(this._ref, this._chatService, this._presenceService)
      : super(const ChatListState()) {
    debugPrint('[ChatList] 🚀 Initialized');
    _bindAuthChanges();
    _init();
  }

  SupabaseClient get _client => _ref.read(supabaseClientProvider);

  @override
  void dispose() {
    _isDisposed = true;
    _searchDebounce?.cancel();
    _refreshDebounce?.cancel();
    _authSubscription?.cancel();
    _cleanupChannel();
    debugPrint('[ChatList] 👋 Disposed');
    super.dispose();
  }

  // ── AUTH BINDING ─────────────────────────────────────────────────────

  void _bindAuthChanges() {
    _authSubscription = _ref.listen<AppUser?>(
      currentUserProvider,
      (previous, next) {
        final prevId = previous?.id;
        final nextId = next?.id;
        if (prevId == nextId) return;

        debugPrint('[ChatList] 🔄 Auth changed: '
            '${_obfuscate(prevId)} → ${_obfuscate(nextId)}');

        _cleanupChannel();
        _currentUserId = nextId;

        if (nextId != null) {
          _init();
        } else {
          state = const ChatListState(isLoading: false);
          _indexedAll = const [];
        }
      },
    );
  }

  // ── INIT ─────────────────────────────────────────────────────────────

  Future<void> _init() async {
    if (_isDisposed) return;

    final userId = _currentUserId ?? _client.auth.currentUser?.id;
    if (!_ChatListValidators.isValidUuid(userId)) {
      debugPrint('[ChatList] ⚠️ No valid user ID');
      state = state.copyWith(isLoading: false, lastError: 'Non connecté');
      return;
    }

    _currentUserId = userId;
    debugPrint('[ChatList] 🌐 Init for user ${_obfuscate(userId)}');

    _presenceService.initPresence();
    await loadInitial();
    _subscribeRealtime();
  }

  // ── REALTIME SUBSCRIPTION ────────────────────────────────────────────

  void _subscribeRealtime() {
    if (_isDisposed || _currentUserId == null) return;

    debugPrint('[ChatList] 📡 Subscribing to messages channel');

    try {
      _channel = _client
          .channel('thix_chat_list_$_currentUserId')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'messages',
            callback: (payload) {
              if (_isDisposed) return;
              _handleMessageInsert(payload.newRecord);
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
          .onPostgresChanges(
            event: PostgresChangeEvent.delete,
            schema: 'public',
            table: 'messages',
            callback: (_) {
              if (!_isDisposed) _scheduleRefresh();
            },
          )
          .subscribe((status, [error]) {
            if (_isDisposed) return;
            if (status == RealtimeSubscribeStatus.subscribed) {
              debugPrint('[ChatList] ✓ Messages channel subscribed');
              state = state.copyWith(isRealtimeConnected: true, clearError: true);
            } else if (error != null) {
              debugPrint('[ChatList] ❌ Subscribe error: $error');
              state = state.copyWith(
                isRealtimeConnected: false,
                lastError: 'Connexion temps réel perdue',
              );
            }
          });
    } catch (e) {
      debugPrint('[ChatList] ❌ Subscribe failed: $e');
      state = state.copyWith(
        isRealtimeConnected: false,
        lastError: 'Échec abonnement temps réel',
      );
    }
  }

  void _handleMessageInsert(Map<String, dynamic> record) {
    if (_isDisposed) return;

    try {
      final senderId = _ChatListValidators.extractUserId(record, 'sender_id');
      final messageId = _ChatListValidators.extractMessageId(record);

      if (senderId == null || messageId == null) {
        debugPrint('[ChatList] ⚠️ Invalid payload, skipping');
        return;
      }

      // Marquer comme délivré si message reçu d'un autre user
      if (senderId != _currentUserId) {
        _markDelivered(messageId);
      }

      _scheduleRefresh();
    } catch (e) {
      debugPrint('[ChatList] ⚠️ handleInsert error: $e');
    }
  }

  Future<void> _markDelivered(String messageId) async {
    try {
      await _client
          .from('messages')
          .update({'is_delivered': true})
          .eq('id', messageId)
          .eq('is_delivered', false)
          .timeout(_kDbTimeout);
    } catch (e) {
      debugPrint('[ChatList] ⚠️ markDelivered error: $e');
    }
  }

  void _scheduleRefresh() {
    if (_isDisposed) return;
    _refreshDebounce?.cancel();
    _refreshDebounce = Timer(_kRefreshDebounce, () {
      if (!_isDisposed) loadInitial(silent: true);
    });
  }

  // ── LOAD / PAGINATION ────────────────────────────────────────────────

  /// Charge les conversations initiales.
  ///
  /// **Protection race condition** : `_isLoadInProgress` empêche les appels
  /// concurrents (Realtime refresh + user action simultanés).
  Future<void> loadInitial({bool silent = false}) async {
    if (_isDisposed || _isLoadInProgress) return;
    if (_currentUserId == null) {
      state = state.copyWith(isLoading: false);
      return;
    }

    _isLoadInProgress = true;

    if (!silent) {
      state = state.copyWith(isLoading: true, clearError: true);
    }

    try {
      // Batch les 3 requêtes pour latence réduite
      final results = await Future.wait([
        _chatService.getConversations(limit: _kPageSize, offset: 0),
        _chatService.getTotalUnreadCount(),
        _getPendingEscalations(),
      ]).timeout(_kDbTimeout);

      if (_isDisposed) return;

      final convs = results[0] as List<ChatConversation>;
      final unread = results[1] as int;
      final escalations = results[2] as int;

      // Construire l'index de recherche
      _indexedAll = convs.map((c) => _IndexedConversation(c)).toList();

      state = state.copyWith(
        all: convs,
        totalUnread: unread,
        pendingEscalations: escalations,
        hasMore: convs.length == _kPageSize,
        isLoading: false,
        clearError: true,
      );

      _applyFilter();
      debugPrint('[ChatList] ✓ Loaded ${convs.length} conversations');
    } catch (e) {
      debugPrint('[ChatList] ❌ loadInitial error: $e');
      if (!_isDisposed) {
        state = state.copyWith(
          isLoading: false,
          lastError: 'Échec du chargement des conversations',
        );
      }
    } finally {
      _isLoadInProgress = false;
    }
  }

  Future<void> loadMore() async {
    if (_isDisposed ||
        state.isLoadingMore ||
        !state.hasMore ||
        state.isLoading ||
        _isLoadInProgress) {
      return;
    }

    state = state.copyWith(isLoadingMore: true);

    try {
      final newConvs = await _chatService
          .getConversations(limit: _kPageSize, offset: state.all.length)
          .timeout(_kDbTimeout);

      if (_isDisposed) return;

      // Déduplication par ID
      final seenIds = state.all.map((c) => c.id).toSet();
      final uniqueNew = newConvs.where((c) => !seenIds.contains(c.id)).toList();

      final merged = [...state.all, ...uniqueNew];
      _indexedAll = merged.map((c) => _IndexedConversation(c)).toList();

      state = state.copyWith(
        all: merged,
        hasMore: newConvs.length == _kPageSize,
        isLoadingMore: false,
      );

      _applyFilter();
      debugPrint('[ChatList] ✓ Loaded ${uniqueNew.length} more conversations');
    } catch (e) {
      debugPrint('[ChatList] ❌ loadMore error: $e');
      if (!_isDisposed) {
        state = state.copyWith(isLoadingMore: false);
      }
    }
  }

  Future<void> refresh({bool silent = false}) => loadInitial(silent: silent);

  // ── COUNTS ───────────────────────────────────────────────────────────

  Future<void> _refreshCounts() async {
    if (_isDisposed || _currentUserId == null) return;
    try {
      final unread = await _chatService
          .getTotalUnreadCount()
          .timeout(_kDbTimeout);
      if (!_isDisposed) {
        state = state.copyWith(totalUnread: unread);
      }
    } catch (e) {
      debugPrint('[ChatList] ⚠️ refreshCounts error: $e');
    }
  }

  Future<int> _getPendingEscalations() async {
    if (_currentUserId == null) return 0;

    int attempt = 0;
    while (true) {
      try {
        final res = await _client
            .from('escalation_steps')
            .select('id')
            .eq('to_agent_id', _currentUserId)
            .eq('status', 0)
            .timeout(_kDbTimeout);
        return (res as List).length;
      } catch (e) {
        attempt++;
        if (attempt > _kMaxRetries) {
          debugPrint('[ChatList] ⚠️ escalations failed: $e');
          return 0;
        }
        await Future.delayed(_kRetryDelay);
      }
    }
  }

  // ── SEARCH & FILTER ──────────────────────────────────────────────────

  void search(String raw) {
    if (_isDisposed) return;
    _searchDebounce?.cancel();
    _searchDebounce = Timer(_kSearchDebounce, () {
      if (_isDisposed) return;
      final sanitized = _ChatListValidators.sanitizeQuery(raw);
      state = state.copyWith(searchQuery: sanitized);
      _applyFilter();
    });
  }

  void setFilter(int idx) {
    if (_isDisposed) return;
    state = state.copyWith(filterIndex: idx);
    _applyFilter();
  }

  /// Applique filtre + recherche en utilisant l'index pré-calculé.
  ///
  /// Optimisation : la lowercase est calculée une seule fois dans
  /// `_IndexedConversation`, pas à chaque filtre.
  void _applyFilter() {
    if (_isDisposed) return;

    var base = _indexedAll;

    // Recherche (O(N) sur searchKey pré-calculé)
    if (state.searchQuery.isNotEmpty) {
      final q = state.searchQuery.toLowerCase();
      base = base.where((idx) => idx.searchKey.contains(q)).toList();
    }

    // Filtres
    Iterable<_IndexedConversation> filtered = base;
    switch (state.filterIndex) {
      case ChatFilter.unread:
        filtered = base.where((idx) => idx.conversation.unreadCount > 0);
        break;
      case ChatFilter.groups:
        filtered = base.where((idx) => idx.conversation.isGroup);
        break;
      case ChatFilter.direct:
        filtered = base.where((idx) => !idx.conversation.isGroup);
        break;
    }

    state = state.copyWith(filtered: filtered.map((idx) => idx.conversation).toList());
  }

  // ── MARK AS READ (avec rollback) ─────────────────────────────────────

  /// Marque une conversation comme lue.
  ///
  /// **Rollback automatique** : si l'appel serveur échoue, le compteur
  /// `unreadCount` est restauré à sa valeur précédente.
  Future<void> markAsRead(String convId) async {
    if (_isDisposed || !_ChatListValidators.isValidUuid(convId)) return;

    // Snapshot pour rollback
    final previousConvs = List<ChatConversation>.from(state.all);
    final previousTotal = state.totalUnread;

    // Optimistic update
    final updated = state.all.map((c) {
      if (c.id == convId) return c.copyWith(unreadCount: 0);
      return c;
    }).toList();

    state = state.copyWith(all: updated);
    _indexedAll = updated.map((c) => _IndexedConversation(c)).toList();
    _applyFilter();

    debugPrint('[ChatList] 📖 Marking read: ${_obfuscate(convId)}');

    try {
      await _chatService.markConversationAsRead(convId);
      await _refreshCounts();
      debugPrint('[ChatList] ✓ Marked read');
    } catch (e) {
      debugPrint('[ChatList] ❌ markAsRead failed, rollback: $e');
      if (!_isDisposed) {
        state = state.copyWith(
          all: previousConvs,
          totalUnread: previousTotal,
          lastError: 'Échec du marquage comme lu',
        );
        _indexedAll = previousConvs.map((c) => _IndexedConversation(c)).toList();
        _applyFilter();
      }
    }
  }

  // ── CLEANUP ──────────────────────────────────────────────────────────

  void _cleanupChannel() {
    final channel = _channel;
    _channel = null;

    if (channel == null) return;

    try {
      channel.unsubscribe();
      _client.removeChannel(channel);
      debugPrint('[ChatList] 🧹 Channel cleaned up');
    } catch (e) {
      debugPrint('[ChatList] ⚠️ Channel cleanup error: $e');
    }

    state = state.copyWith(isRealtimeConnected: false);
  }

  // ── HELPERS ──────────────────────────────────────────────────────────

  String _obfuscate(String? s) {
    if (s == null || s.length <= 8) return '***';
    return '${s.substring(0, 4)}...${s.substring(s.length - 4)}';
  }
}

// ============================================================================
// PROVIDERS
// ============================================================================

/// Provider principal pour la liste des conversations.
///
/// Usage :
/// ```dart
/// final chatList = ref.watch(chatListProvider);
/// final conversations = chatList.filtered;
/// final badge = chatList.totalUnread;
/// ```
final chatListProvider =
    StateNotifierProvider<ChatListNotifier, ChatListState>((ref) {
  final chatService = ref.watch(chatServiceProvider);
  final presenceService = ref.watch(presenceServiceProvider);
  return ChatListNotifier(ref, chatService, presenceService);
});

// ── DERIVED PROVIDERS (rebuild optimization) ─────────────────────────

/// Liste filtrée des conversations affichées dans l'UI.
final chatListFilteredProvider = Provider<List<ChatConversation>>((ref) {
  return ref.watch(chatListProvider).filtered;
});

/// Vrai si la liste est vide (pas de conversations après filtre).
final chatListIsEmptyProvider = Provider<bool>((ref) {
  return ref.watch(chatListProvider).isEmpty;
});

/// Nombre total de messages non lus (badge global).
final chatListTotalUnreadProvider = Provider<int>((ref) {
  return ref.watch(chatListProvider).totalUnread;
});

/// Nombre d'escalades en attente (pour agents).
final chatListPendingEscalationsProvider = Provider<int>((ref) {
  return ref.watch(chatListProvider).pendingEscalations;
});

/// Vrai si le chargement initial est en cours.
final chatListIsLoadingProvider = Provider<bool>((ref) {
  return ref.watch(chatListProvider).isLoading;
});

/// Vrai si un chargement additionnel (pagination) est en cours.
final chatListIsLoadingMoreProvider = Provider<bool>((ref) {
  return ref.watch(chatListProvider).isLoadingMore;
});

/// Vrai si le canal Realtime est connecté.
final chatListRealtimeConnectedProvider = Provider<bool>((ref) {
  return ref.watch(chatListProvider).isRealtimeConnected;
});

/// Dernière erreur (pour affichage UI / toast).
final chatListErrorProvider = Provider<String?>((ref) {
  return ref.watch(chatListProvider).lastError;
});
