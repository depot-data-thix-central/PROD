// lib/presentation/chat/providers/chat_list_provider.dart
//
// Provider Riverpod pour la liste des conversations avec fonctionnalités enterprise :
// - Épingler/Désépingler (max 3)
// - Archiver/Désarchiver
// - Sourdine (8h, 1 semaine, Toujours)
// - Verrouillage biométrique
// - Brouillons
// - Marquer comme non lu
// - Sélection multiple (bulk actions)
// - Tri intelligent : épinglés → récents → archivés masqués

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:thix_id/models/chat/chat_conversation.dart';
import 'package:thix_id/presentation/chat/providers/chat_providers.dart';
import 'package:thix_id/services/chat/chat_service.dart';
import 'package:thix_id/services/chat/presence_service.dart';
import 'package:thix_id/data/offline/chat_offline_cache.dart';

// ============================================================================
// CONSTANTS
// ============================================================================
const int _kPageSize = 20;
const int _kMaxPinned = 3;
const Duration _kSearchDebounce = Duration(milliseconds: 350);
const Duration _kRefreshDebounce = Duration(milliseconds: 500);
const Duration _kDraftDebounce = Duration(milliseconds: 800);
const Duration _kDbTimeout = Duration(seconds: 15);
const int _kMaxRetries = 2;
const Duration _kRetryDelay = Duration(milliseconds: 500);

/// Index des filtres dans l'UI
class ChatFilter {
  static const int all = 0;
  static const int unread = 1;
  static const int groups = 2;
  static const int direct = 3;
  static const int pinned = 4;      // ✅ NOUVEAU : Épinglés uniquement
  static const int archived = 5;    // ✅ NOUVEAU : Archivés
}

// ============================================================================
// VALIDATORS
// ============================================================================
class _ChatListValidators {
  _ChatListValidators._();

  static bool isValidUuid(String? id) {
    if (id == null || id.isEmpty) return false;
    return RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
      caseSensitive: false,
    ).hasMatch(id);
  }

  static String sanitizeQuery(String? input, {int maxLength = 100}) {
    if (input == null || input.trim().isEmpty) return '';
    var s = input
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '')
        .trim();
    return s.length > maxLength ? s.substring(0, maxLength) : s;
  }

  static String? extractUserId(Map<String, dynamic> record, String key) {
    final raw = record[key];
    if (raw == null) return null;
    final id = raw.toString().trim();
    return isValidUuid(id) ? id : null;
  }

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
  final String searchKey;

  _IndexedConversation(this.conversation)
      : searchKey = _buildSearchKey(conversation);

  static String _buildSearchKey(ChatConversation c) {
    final parts = <String>[
      c.displayName,
      c.lastMessage?.content ?? '',
      c.groupName ?? '',
      c.draft ?? '',  // ✅ Brouillons aussi recherchables
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
  
  // ✅ NOUVEAUTÉS P0/P1
  final Set<String> selectedIds;        // Sélection multiple
  final bool isSelectionMode;           // Mode sélection actif
  final int pinnedCount;                // Nombre d'épinglés (max 3)
  final int archivedCount;              // Nombre d'archivés

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
    this.selectedIds = const {},
    this.isSelectionMode = false,
    this.pinnedCount = 0,
    this.archivedCount = 0,
  });

  bool get isEmpty => filtered.isEmpty && !isLoading;
  bool get hasActiveFilter =>
      filterIndex != ChatFilter.all || searchQuery.isNotEmpty;
  bool get hasSelection => selectedIds.isNotEmpty;
  bool get canPin => pinnedCount < _kMaxPinned;

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
    Set<String>? selectedIds,
    bool? isSelectionMode,
    int? pinnedCount,
    int? archivedCount,
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
      selectedIds: selectedIds ?? this.selectedIds,
      isSelectionMode: isSelectionMode ?? this.isSelectionMode,
      pinnedCount: pinnedCount ?? this.pinnedCount,
      archivedCount: archivedCount ?? this.archivedCount,
    );
  }
}

// ============================================================================
// NOTIFIER
// ============================================================================

class ChatListNotifier extends StateNotifier<ChatListState> {
  final Ref _ref;
  final ChatService _chatService;
  final PresenceService _presenceService;

  Timer? _searchDebounce;
  Timer? _refreshDebounce;
  Timer? _draftDebounce;
  RealtimeChannel? _channel;
  ProviderSubscription<String?>? _authSubscription;
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
    _draftDebounce?.cancel();
    _authSubscription?.close();
    _cleanupChannel();
    debugPrint('[ChatList] 👋 Disposed');
    super.dispose();
  }

  // ── AUTH BINDING ─────────────────────────────────────────────────────

  void _bindAuthChanges() {
    _authSubscription = _ref.listen<String?>(
      supabaseUserIdProvider,
      (previous, next) {
        final prevId = previous;
        final nextId = next;
        if (prevId == nextId) return;

        debugPrint('[ChatList] 🔄 Auth changed: ${_obfuscate(prevId)} → ${_obfuscate(nextId)}');

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

    try {
      _presenceService.initPresence();
    } catch (e) {
      debugPrint('[ChatList] ⚠️ initPresence failed (likely offline): $e');
    }

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
      final convsFuture = _chatService.getConversations(limit: _kPageSize, offset: 0);
      final unreadFuture = _chatService.getTotalUnreadCount();
      final escalationsFuture = _getPendingEscalations();

      final results = await Future.wait<dynamic>([
        convsFuture,
        unreadFuture,
        escalationsFuture,
      ]).timeout(_kDbTimeout);

      if (_isDisposed) return;

      final convs = (results[0] as List).cast<ChatConversation>();
      final unread = results[1] as int;
      final escalations = results[2] as int;

      _indexedAll = convs.map((c) => _IndexedConversation(c)).toList();

      // ✅ Calculer les compteurs
      final pinnedCount = convs.where((c) => c.isPinned).length;
      final archivedCount = convs.where((c) => c.isArchived).length;

      state = state.copyWith(
        all: convs,
        totalUnread: unread,
        pendingEscalations: escalations,
        hasMore: convs.length == _kPageSize,
        isLoading: false,
        clearError: true,
        pinnedCount: pinnedCount,
        archivedCount: archivedCount,
      );

      _applyFilter();
      debugPrint('[ChatList] ✓ Loaded ${convs.length} conversations (pinned=$pinnedCount, archived=$archivedCount)');

      unawaited(ChatOfflineCache.instance.saveConversations(
        _currentUserId!,
        convs.map(_convToCache).toList(),
      ));
    } catch (e) {
      debugPrint('[ChatList] ❌ loadInitial error: $e');
      if (_isDisposed) return;

      final cached = ChatOfflineCache.instance.readConversations(_currentUserId!);
      if (cached.isNotEmpty) {
        final convs = cached.map(_convFromCache).whereType<ChatConversation>().toList();
        _indexedAll = convs.map((c) => _IndexedConversation(c)).toList();
        final pinnedCount = convs.where((c) => c.isPinned).length;
        final archivedCount = convs.where((c) => c.isArchived).length;
        
        state = state.copyWith(
          all: convs,
          hasMore: false,
          isLoading: false,
          lastError: 'Hors ligne',
          pinnedCount: pinnedCount,
          archivedCount: archivedCount,
        );
        _applyFilter();
        debugPrint('[ChatList] 📴 Restored ${convs.length} cached conversations');
        return;
      }

      state = state.copyWith(
        isLoading: false,
        lastError: 'Échec du chargement des conversations',
      );
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

      final seenIds = state.all.map((c) => c.id).toSet();
      final uniqueNew = newConvs.where((c) => !seenIds.contains(c.id)).toList();

      final merged = <ChatConversation>[...state.all, ...uniqueNew];
      _indexedAll = merged.map((c) => _IndexedConversation(c)).toList();

      final pinnedCount = merged.where((c) => c.isPinned).length;
      final archivedCount = merged.where((c) => c.isArchived).length;

      state = state.copyWith(
        all: merged,
        hasMore: newConvs.length == _kPageSize,
        isLoadingMore: false,
        pinnedCount: pinnedCount,
        archivedCount: archivedCount,
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
      final unread = await _chatService.getTotalUnreadCount().timeout(_kDbTimeout);
      if (!_isDisposed) {
        state = state.copyWith(totalUnread: unread);
      }
    } catch (e) {
      debugPrint('[ChatList] ⚠️ refreshCounts error: $e');
    }
  }

  Future<int> _getPendingEscalations() async {
    final userId = _currentUserId;
    if (userId == null) return 0;

    int attempt = 0;
    while (true) {
      try {
        final res = await _client
            .from('escalation_steps')
            .select('id')
            .eq('to_agent_id', userId)
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
        filtered = base.where((idx) => idx.conversation.unreadCount > 0 && !idx.conversation.isArchived);
        break;
      case ChatFilter.groups:
        filtered = base.where((idx) => idx.conversation.isGroup && !idx.conversation.isArchived);
        break;
      case ChatFilter.direct:
        filtered = base.where((idx) => !idx.conversation.isGroup && !idx.conversation.isArchived);
        break;
      case ChatFilter.pinned:
        filtered = base.where((idx) => idx.conversation.isPinned);
        break;
      case ChatFilter.archived:
        filtered = base.where((idx) => idx.conversation.isArchived);
        break;
      case ChatFilter.all:
      default:
        // Par défaut : masquer les archivés
        filtered = base.where((idx) => !idx.conversation.isArchived);
        break;
    }

    // ✅ Tri intelligent : épinglés d'abord (par pinnedAt DESC), puis updatedAt DESC
    final sorted = filtered.toList()
      ..sort((a, b) {
        // 1. Épinglés en premier
        if (a.conversation.isPinned && !b.conversation.isPinned) return -1;
        if (!a.conversation.isPinned && b.conversation.isPinned) return 1;
        
        // 2. Si les deux sont épinglés, trier par pinnedAt DESC
        if (a.conversation.isPinned && b.conversation.isPinned) {
          final aTime = a.conversation.pinnedAt ?? DateTime(1970);
          final bTime = b.conversation.pinnedAt ?? DateTime(1970);
          return bTime.compareTo(aTime);
        }
        
        // 3. Sinon, trier par updatedAt DESC
        return b.conversation.updatedAt.compareTo(a.conversation.updatedAt);
      });

    state = state.copyWith(filtered: sorted.map((idx) => idx.conversation).toList());
  }

  // ── MARK AS READ (avec rollback) ─────────────────────────────────────

  Future<void> markAsRead(String convId) async {
    if (_isDisposed || !_ChatListValidators.isValidUuid(convId)) return;

    final previousConvs = List<ChatConversation>.from(state.all);
    final previousTotal = state.totalUnread;

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

  // ── PIN / UNPIN ──────────────────────────────────────────────────────

  Future<void> togglePin(String convId) async {
    if (_isDisposed || !_ChatListValidators.isValidUuid(convId)) return;

    final conv = state.all.firstWhere((c) => c.id == convId, orElse: () => throw StateError('Conversation not found'));
    final wasPinned = conv.isPinned;

    // Vérifier max 3 épinglés
    if (!wasPinned && !state.canPin) {
      debugPrint('[ChatList] ⚠️ Cannot pin: max $_kMaxPinned reached');
      return;
    }

    final previousConvs = List<ChatConversation>.from(state.all);
    final previousPinnedCount = state.pinnedCount;

    // Mise à jour optimiste
    final updated = state.all.map((c) {
      if (c.id == convId) {
        return c.copyWith(
          isPinned: !wasPinned,
          pinnedAt: wasPinned ? null : DateTime.now().toUtc(),
        );
      }
      return c;
    }).toList();

    state = state.copyWith(
      all: updated,
      pinnedCount: wasPinned ? state.pinnedCount - 1 : state.pinnedCount + 1,
    );
    _indexedAll = updated.map((c) => _IndexedConversation(c)).toList();
    _applyFilter();

    debugPrint('[ChatList] 📌 ${wasPinned ? "Unpinning" : "Pinning"}: ${_obfuscate(convId)}');

    try {
      await _chatService.togglePinned(convId, !wasPinned);
      debugPrint('[ChatList] ✓ Pin toggled');
    } catch (e) {
      debugPrint('[ChatList] ❌ togglePin failed, rollback: $e');
      if (!_isDisposed) {
        state = state.copyWith(
          all: previousConvs,
          pinnedCount: previousPinnedCount,
          lastError: 'Échec de l\'épinglage',
        );
        _indexedAll = previousConvs.map((c) => _IndexedConversation(c)).toList();
        _applyFilter();
      }
    }
  }

  // ── ARCHIVE / UNARCHIVE ──────────────────────────────────────────────

  Future<void> toggleArchive(String convId) async {
    if (_isDisposed || !_ChatListValidators.isValidUuid(convId)) return;

    final conv = state.all.firstWhere((c) => c.id == convId, orElse: () => throw StateError('Conversation not found'));
    final wasArchived = conv.isArchived;

    final previousConvs = List<ChatConversation>.from(state.all);
    final previousArchivedCount = state.archivedCount;

    // Mise à jour optimiste
    final updated = state.all.map((c) {
      if (c.id == convId) return c.copyWith(isArchived: !wasArchived);
      return c;
    }).toList();

    state = state.copyWith(
      all: updated,
      archivedCount: wasArchived ? state.archivedCount - 1 : state.archivedCount + 1,
    );
    _indexedAll = updated.map((c) => _IndexedConversation(c)).toList();
    _applyFilter();

    debugPrint('[ChatList] 📁 ${wasArchived ? "Unarchiving" : "Archiving"}: ${_obfuscate(convId)}');

    try {
      if (wasArchived) {
        await _chatService.unarchiveConversation(convId);
      } else {
        await _chatService.archiveConversation(convId);
      }
      debugPrint('[ChatList] ✓ Archive toggled');
    } catch (e) {
      debugPrint('[ChatList] ❌ toggleArchive failed, rollback: $e');
      if (!_isDisposed) {
        state = state.copyWith(
          all: previousConvs,
          archivedCount: previousArchivedCount,
          lastError: 'Échec de l\'archivage',
        );
        _indexedAll = previousConvs.map((c) => _IndexedConversation(c)).toList();
        _applyFilter();
      }
    }
  }

  // ── MUTE / UNMUTE ────────────────────────────────────────────────────

  Future<void> toggleMute(String convId, {Duration? duration}) async {
    if (_isDisposed || !_ChatListValidators.isValidUuid(convId)) return;

    final conv = state.all.firstWhere((c) => c.id == convId, orElse: () => throw StateError('Conversation not found'));
    final wasMuted = conv.isCurrentlyMuted;

    final previousConvs = List<ChatConversation>.from(state.all);

    // Mise à jour optimiste
    final updated = state.all.map((c) {
      if (c.id == convId) {
        return c.copyWith(
          isMuted: duration != null,
          muteUntil: duration != null ? DateTime.now().add(duration) : null,
        );
      }
      return c;
    }).toList();

    state = state.copyWith(all: updated);
    _indexedAll = updated.map((c) => _IndexedConversation(c)).toList();
    _applyFilter();

    debugPrint('[ChatList] 🔇 ${wasMuted ? "Unmuting" : "Muting"}: ${_obfuscate(convId)} (duration=${duration?.inHours}h)');

    try {
      await _chatService.muteConversationWithDuration(convId, duration);
      debugPrint('[ChatList] ✓ Mute toggled');
    } catch (e) {
      debugPrint('[ChatList] ❌ toggleMute failed, rollback: $e');
      if (!_isDisposed) {
        state = state.copyWith(
          all: previousConvs,
          lastError: 'Échec de la sourdine',
        );
        _indexedAll = previousConvs.map((c) => _IndexedConversation(c)).toList();
        _applyFilter();
      }
    }
  }

  // ── LOCK / UNLOCK ────────────────────────────────────────────────────

  Future<void> toggleLock(String convId) async {
    if (_isDisposed || !_ChatListValidators.isValidUuid(convId)) return;

    final conv = state.all.firstWhere((c) => c.id == convId, orElse: () => throw StateError('Conversation not found'));
    final wasLocked = conv.isLocked;

    final previousConvs = List<ChatConversation>.from(state.all);

    // Mise à jour optimiste
    final updated = state.all.map((c) {
      if (c.id == convId) return c.copyWith(isLocked: !wasLocked);
      return c;
    }).toList();

    state = state.copyWith(all: updated);
    _indexedAll = updated.map((c) => _IndexedConversation(c)).toList();
    _applyFilter();

    debugPrint('[ChatList] 🔒 ${wasLocked ? "Unlocking" : "Locking"}: ${_obfuscate(convId)}');

    try {
      await _chatService.toggleLockConversation(convId);
      debugPrint('[ChatList] ✓ Lock toggled');
    } catch (e) {
      debugPrint('[ChatList] ❌ toggleLock failed, rollback: $e');
      if (!_isDisposed) {
        state = state.copyWith(
          all: previousConvs,
          lastError: 'Échec du verrouillage',
        );
        _indexedAll = previousConvs.map((c) => _IndexedConversation(c)).toList();
        _applyFilter();
      }
    }
  }

  // ── MARK AS UNREAD ───────────────────────────────────────────────────

  Future<void> markAsUnread(String convId) async {
    if (_isDisposed || !_ChatListValidators.isValidUuid(convId)) return;

    final previousConvs = List<ChatConversation>.from(state.all);
    final previousTotal = state.totalUnread;

    // Mise à jour optimiste
    final updated = state.all.map((c) {
      if (c.id == convId) return c.copyWith(unreadCount: 1);
      return c;
    }).toList();

    state = state.copyWith(
      all: updated,
      totalUnread: state.totalUnread + 1,
    );
    _indexedAll = updated.map((c) => _IndexedConversation(c)).toList();
    _applyFilter();

    debugPrint('[ChatList] 📬 Marking unread: ${_obfuscate(convId)}');

    try {
      await _chatService.markAsUnread(convId);
      debugPrint('[ChatList] ✓ Marked unread');
    } catch (e) {
      debugPrint('[ChatList] ❌ markAsUnread failed, rollback: $e');
      if (!_isDisposed) {
        state = state.copyWith(
          all: previousConvs,
          totalUnread: previousTotal,
          lastError: 'Échec du marquage comme non lu',
        );
        _indexedAll = previousConvs.map((c) => _IndexedConversation(c)).toList();
        _applyFilter();
      }
    }
  }

  // ── BULK DELETE via Provider (pas Supabase direct) ──────────
  Future<void> bulkDelete() async {
    if (_isDisposed || state.selectedIds.isEmpty) return;

    final idsToDelete = state.selectedIds.toList();
    debugPrint('[ChatList] 🗑️ Bulk deleting ${idsToDelete.length} conversations');

    final previousAll = List<ChatConversation>.from(state.all);
    
    // Optimistic update : retirer immédiatement de la liste
    final filtered = state.all.where((c) => !state.selectedIds.contains(c.id)).toList();
    state = state.copyWith(
      all: filtered,
      selectedIds: {},
      isSelectionMode: false,
    );
    _indexedAll = filtered.map((c) => _IndexedConversation(c)).toList();
    _applyFilter();

    int successCount = 0;
    for (final id in idsToDelete) {
      try {
        await _client
            .from('conversation_participants')
            .delete()
            .eq('conversation_id', id)
            .eq('user_id', _currentUserId!)
            .timeout(_kDbTimeout);
        successCount++;
      } catch (e) {
        debugPrint('[ChatList] ❌ Delete ${_obfuscate(id)}: $e');
      }
    }

    if (successCount < idsToDelete.length) {
      debugPrint('[ChatList] ⚠️ Some deletions failed, reloading');
      await loadInitial(silent: true);
    }
  }

  /// Récupère le nom d'une conversation par ID (pour les confirmations)
  String? getConversationName(String convId) {
    try {
      return state.all.firstWhere((c) => c.id == convId).displayName;
    } catch (_) {
      return null;
    }
  }

  // ── DRAFT ────────────────────────────────────────────────────────────

  void saveDraft(String convId, String? draft) {
    if (_isDisposed || !_ChatListValidators.isValidUuid(convId)) return;

    _draftDebounce?.cancel();
    _draftDebounce = Timer(_kDraftDebounce, () async {
      if (_isDisposed) return;

      // Mise à jour optimiste locale
      final updated = state.all.map((c) {
        if (c.id == convId) return c.copyWith(draft: draft);
        return c;
      }).toList();

      state = state.copyWith(all: updated);
      _indexedAll = updated.map((c) => _IndexedConversation(c)).toList();
      _applyFilter();

      try {
        await _chatService.saveDraft(convId, draft);
        debugPrint('[ChatList] ✓ Draft saved: ${_obfuscate(convId)}');
      } catch (e) {
        debugPrint('[ChatList] ⚠️ saveDraft failed: $e');
      }
    });
  }

  // ── SELECTION MODE (Bulk Actions) ────────────────────────────────────

  void enterSelectionMode() {
    if (_isDisposed) return;
    state = state.copyWith(isSelectionMode: true, selectedIds: {});
    debugPrint('[ChatList] 🔘 Selection mode entered');
  }

  void exitSelectionMode() {
    if (_isDisposed) return;
    state = state.copyWith(isSelectionMode: false, selectedIds: {});
    debugPrint('[ChatList] 🔘 Selection mode exited');
  }

  void toggleSelection(String convId) {
    if (_isDisposed) return;
    final newSelected = Set<String>.from(state.selectedIds);
    if (newSelected.contains(convId)) {
      newSelected.remove(convId);
    } else {
      newSelected.add(convId);
    }
    state = state.copyWith(selectedIds: newSelected);
  }

  void selectAll() {
    if (_isDisposed) return;
    final allIds = state.filtered.map((c) => c.id).toSet();
    state = state.copyWith(selectedIds: allIds);
  }

  void clearSelection() {
    if (_isDisposed) return;
    state = state.copyWith(selectedIds: {});
  }

  

  Future<void> bulkArchive() async {
    if (_isDisposed || state.selectedIds.isEmpty) return;

    final idsToArchive = state.selectedIds.toList();
    debugPrint('[ChatList] 📁 Bulk archiving ${idsToArchive.length} conversations');

    for (final id in idsToArchive) {
      try {
        await _chatService.archiveConversation(id);
      } catch (e) {
        debugPrint('[ChatList] ❌ Bulk archive error for ${_obfuscate(id)}: $e');
      }
    }

    await loadInitial(silent: true);
    exitSelectionMode();
  }

  Future<void> bulkMarkAsRead() async {
    if (_isDisposed || state.selectedIds.isEmpty) return;

    final idsToMark = state.selectedIds.toList();
    debugPrint('[ChatList] 📖 Bulk marking ${idsToMark.length} as read');

    for (final id in idsToMark) {
      try {
        await _chatService.markConversationAsRead(id);
      } catch (e) {
        debugPrint('[ChatList] ❌ Bulk mark read error for ${_obfuscate(id)}: $e');
      }
    }

    await loadInitial(silent: true);
    exitSelectionMode();
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

  Map<String, dynamic> _convToCache(ChatConversation c) {
    return {
      'id': c.id,
      'title': c.displayName,
      'last_message': c.lastMessage?.content,
      'updated_at': c.lastMessage?.createdAt.toIso8601String() ?? '',
      'unread_count': c.unreadCount,
      'is_group': c.isGroup,
      'group_name': c.groupName,
      'is_pinned': c.isPinned,
      'pinned_at': c.pinnedAt?.toIso8601String(),
      'is_archived': c.isArchived,
      'is_muted': c.isMuted,
      'mute_until': c.muteUntil?.toIso8601String(),
      'is_locked': c.isLocked,
      'draft': c.draft,
    };
  }

  ChatConversation? _convFromCache(Map<String, dynamic> m) {
    try {
      return ChatConversation.fromJson(m);
    } catch (e) {
      debugPrint('[ChatList] ⚠️ Impossible de parser la conversation depuis le cache: $e');
    }
    return null;
  }

  String _obfuscate(String? s) {
    if (s == null || s.length <= 8) return '***';
    return '${s.substring(0, 4)}...${s.substring(s.length - 4)}';
  }
}

// ============================================================================
// PROVIDERS
// ============================================================================

final chatListProvider = StateNotifierProvider<ChatListNotifier, ChatListState>((ref) {
  final chatService = ref.watch(chatServiceProvider);
  final presenceService = ref.watch(presenceServiceProvider);
  return ChatListNotifier(ref, chatService, presenceService);
});

// ── DERIVED PROVIDERS ─────────────────────────────────────────────────

final chatListFilteredProvider = Provider<List<ChatConversation>>((ref) {
  return ref.watch(chatListProvider).filtered;
});

final chatListIsEmptyProvider = Provider<bool>((ref) {
  return ref.watch(chatListProvider).isEmpty;
});

final chatListTotalUnreadProvider = Provider<int>((ref) {
  return ref.watch(chatListProvider).totalUnread;
});

final chatListPendingEscalationsProvider = Provider<int>((ref) {
  return ref.watch(chatListProvider).pendingEscalations;
});

final chatListIsLoadingProvider = Provider<bool>((ref) {
  return ref.watch(chatListProvider).isLoading;
});

final chatListIsLoadingMoreProvider = Provider<bool>((ref) {
  return ref.watch(chatListProvider).isLoadingMore;
});

final chatListRealtimeConnectedProvider = Provider<bool>((ref) {
  return ref.watch(chatListProvider).isRealtimeConnected;
});

final chatListErrorProvider = Provider<String?>((ref) {
  return ref.watch(chatListProvider).lastError;
});

final chatListSelectionModeProvider = Provider<bool>((ref) {
  return ref.watch(chatListProvider).isSelectionMode;
});

final chatListSelectedIdsProvider = Provider<Set<String>>((ref) {
  return ref.watch(chatListProvider).selectedIds;
});

final chatListPinnedCountProvider = Provider<int>((ref) {
  return ref.watch(chatListProvider).pinnedCount;
});

final chatListArchivedCountProvider = Provider<int>((ref) {
  return ref.watch(chatListProvider).archivedCount;
});
