// lib/presentation/chat/chat_screen.dart
// THIX Chat — conversation complète style WhatsApp + entreprise.
// ✅ Zéro appel Supabase direct : TOUT passe par ChatService.
// ✅ Zéro syntaxe Dart 3 (pas de records / patterns / switch-expression) → analyzer 3.4.0 OK.
// ✅ Features : swipe-reply (2 directions), edit 15 min + badge, delete for all/me,
//    forward (max 5), pin/unpin (max 3) + barre épinglés, favoris ⭐ + sheet, recherche
//    in-chat + navigation, jump to first unread + séparateur, View Once, mentions @,
//    rappels 🔔, auto-destruct visuel (bubble), mot de passe robuste, appels
//    entrant/sortant/manqué, export agent, info message.
import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:audioplayers/audioplayers.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/features/network/presentation/providers/user_profile_providers.dart';
import 'package:thix_id/l10n/app_localizations.dart';
import 'package:thix_id/models/certification_tier.dart';
import 'package:thix_id/models/chat/call_status.dart';
import 'package:thix_id/models/chat/chat_conversation.dart';
import 'package:thix_id/models/chat/chat_message.dart';
import 'package:thix_id/models/chat/group_info.dart';
import 'package:thix_id/models/chat/user_status.dart';
import 'package:thix_id/presentation/certification/widgets/certification_name_badge.dart';
import 'package:thix_id/presentation/chat/call/call_page.dart';
import 'package:thix_id/presentation/chat/call/providers/call_provider.dart';
import 'package:thix_id/presentation/chat/encryption_service.dart';
import 'package:thix_id/presentation/chat/providers/chat_list_provider.dart';
import 'package:thix_id/presentation/chat/providers/chat_providers.dart';
import 'package:thix_id/presentation/chat/widgets/chat_message_bubble.dart';
import 'package:thix_id/presentation/chat/widgets/image_viewer.dart';
import 'package:thix_id/services/chat/chat_service.dart';
import 'package:thix_id/services/chat/connection_service.dart';
import 'package:thix_id/data/offline/chat_offline_cache.dart';

// ============================================================================
// CONSTANTES
// ============================================================================
const Duration _kRequestTimeout = Duration(seconds: 15);
const Duration _kUploadTimeout = Duration(seconds: 60);
const Duration _kRetryDelay = Duration(milliseconds: 400);
const int _kMaxRetries = 1;
const int _kPageSize = 30;
const int _kLoadMoreThresholdPx = 200;
const int _kLoadMoreThrottleMs = 500;
const int _kMaxMessageLength = 5000;
const int _kMaxFileSizeBytes = 25 * 1024 * 1024;
const int _kMaxAudioDurationSeconds = 300;
const int _kTypingDebounceMs = 2000;
const int _kMarkReadDebounceMs = 1000;
const int _kPresenceCheckThrottleSeconds = 30;
const int _kMaxForward = 5;
const int _kSearchDebounceMs = 350;
const int _kEditWindowMinutes = 15;

// ============================================================================
// VALIDATEURS
// ============================================================================
class _ChatValidators {
  _ChatValidators._();

  static String sanitize(String? input, {int maxLength = 5000}) {
    if (input == null || input.trim().isEmpty) return '';
    final doc = html_parser.parse(input);
    var s = doc.body?.text ?? input;
    s = s
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll(RegExp(r'javascript:', caseSensitive: false), '')
        .replaceAll(RegExp(r'on\w+\s*=', caseSensitive: false), '')
        .replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '')
        .trim();
    return s.length > maxLength ? s.substring(0, maxLength) : s;
  }

  static String? sanitizeUrl(String? url) {
    if (url == null || url.trim().isEmpty) return null;
    final t = url.trim();
    if (!t.startsWith('http://') && !t.startsWith('https://')) return null;
    return t.replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '');
  }

  static String friendlyError(dynamic e) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('timeout')) return 'Délai dépassé. Vérifiez votre connexion.';
    if (msg.contains('network') || msg.contains('socket')) return 'Erreur réseau. Réessayez.';
    if (msg.contains('permission') || msg.contains('policy')) return 'Accès non autorisé.';
    if (msg.contains('not found')) return 'Ressource introuvable.';
    if (msg.contains('too large') || msg.contains('size')) return 'Fichier trop volumineux.';
    if (msg.contains('maximum') || msg.contains('atteint')) return 'Limite atteinte.';
    return 'Une erreur est survenue. Réessayez.';
  }

  static bool isValidFileSize(int bytes) => bytes > 0 && bytes <= _kMaxFileSizeBytes;

  static String getMediaType(String ext) {
    const img = {'jpg', 'jpeg', 'png', 'gif', 'webp'};
    const vid = {'mp4', 'mov', 'avi', 'mkv'};
    const aud = {'mp3', 'wav', 'm4a'};
    final e = ext.toLowerCase();
    if (img.contains(e)) return 'image';
    if (vid.contains(e)) return 'video';
    if (aud.contains(e)) return 'audio';
    return 'file';
  }

  /// Score de robustesse mot de passe : 0..5 (>= 3 exigé)
  static int passwordScore(String pwd) {
    int score = 0;
    if (pwd.length >= 8) score++;
    if (pwd.length >= 12) score++;
    if (pwd.contains(RegExp(r'[a-z]')) && pwd.contains(RegExp(r'[A-Z]'))) score++;
    if (pwd.contains(RegExp(r'[0-9]'))) score++;
    if (pwd.contains(RegExp(r'[^\w\s]'))) score++;
    return score;
  }
}

/// l10n avec repli FR si la clé n'existe pas encore dans app_localizations.
String _tr(AppLocalizations l10n, String key, String fallback) {
  final s = l10n.t(key);
  return s == key ? fallback : s;
}

Future<T> _chatRetry<T>(
  Future<T> Function() fn, {
  required String label,
  int maxRetries = _kMaxRetries,
  Duration timeout = _kRequestTimeout,
}) async {
  int attempt = 0;
  while (true) {
    try {
      return await fn().timeout(timeout);
    } on TimeoutException {
      attempt++;
      if (attempt > maxRetries) {
        debugPrint('[Chat] ❌ $label: timeout after $attempt attempts');
        throw TimeoutException('$label: délai dépassé');
      }
      await Future.delayed(_kRetryDelay);
    } catch (e) {
      debugPrint('[Chat] ❌ $label error: $e');
      rethrow;
    }
  }
}

// ============================================================================
// PROVIDER MESSAGES (aucun Supabase direct : svc.currentUserId)
// ============================================================================
final chatMessagesProvider =
    StateNotifierProvider.family<ChatMsgNotifier, List<ChatMessage>, String>((ref, conversationId) {
  return ChatMsgNotifier(ref.read(chatServiceProvider), conversationId);
});

class ChatMsgNotifier extends StateNotifier<List<ChatMessage>> {
  final ChatService svc;
  final String convId;
  int page = 0;
  static const pageSize = _kPageSize;
  bool hasMore = true;
  bool loadingMore = false;

  ChatMsgNotifier(this.svc, this.convId) : super([]) {
    loadInitial();
  }

  Future<void> loadInitial() async {
    page = 0;
    final uid = svc.currentUserId;
    try {
      final msgs = await _chatRetry(
        () => svc.getMessages(convId, limit: pageSize, offset: 0),
        label: 'loadInitial[$convId]',
      );
      hasMore = msgs.length >= pageSize;
      msgs.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      state = msgs;
      if (uid.isNotEmpty) {
        unawaited(ChatOfflineCache.instance.saveMessages(
          uid, convId, msgs.map((m) => m.toJson()).toList(),
        ));
      }
    } catch (e) {
      debugPrint('[ChatMsg] ❌ Load initial error: $e');
      if (uid.isNotEmpty) {
        final cached = ChatOfflineCache.instance.readMessages(uid, convId);
        if (cached.isNotEmpty) {
          state = cached.map(ChatMessage.fromJson).where((m) => m.id.isNotEmpty).toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
          hasMore = false;
          return;
        }
      }
      state = [];
    }
  }

  Future<void> loadMore() async {
    if (loadingMore || !hasMore) return;
    loadingMore = true;
    page++;
    try {
      final msgs = await _chatRetry(
        () => svc.getMessages(convId, limit: pageSize, offset: page * pageSize),
        label: 'loadMore[$convId]',
      );
      hasMore = msgs.length >= pageSize;
      var current = [...state, ...msgs];
      final seen = <String>{};
      current = current.where((m) => seen.add(m.id)).toList();
      current.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      state = current;
    } catch (e) {
      debugPrint('[ChatMsg] ❌ Load more error: $e');
    } finally {
      loadingMore = false;
    }
  }

  /// Cherche un message en paginant (recherche / jump) — max [maxPages] pages.
  Future<bool> ensureLoaded(String messageId, {int maxPages = 6}) async {
    int guard = 0;
    while (guard < maxPages) {
      if (state.any((m) => m.id == messageId)) return true;
      if (!hasMore) return false;
      await loadMore();
      guard++;
    }
    return state.any((m) => m.id == messageId);
  }

  void upsertRealtime(List<ChatMessage> updated) {
    if (updated.isEmpty) return;
    var current = [...state];
    var changed = false;
    for (final msg in updated) {
      final idx = current.indexWhere((m) => m.id == msg.id);
      if (idx != -1) {
        current[idx] = msg;
        changed = true;
      } else if (!msg.isDeleted) {
        current.insert(0, msg);
        changed = true;
      }
    }
    if (changed) {
      current.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      final seen = <String>{};
      current = current.where((m) => seen.add(m.id)).toList();
      state = current;
      final uid = svc.currentUserId;
      if (uid.isNotEmpty) {
        unawaited(ChatOfflineCache.instance.saveMessages(
          uid, convId, state.map((m) => m.toJson()).toList(),
        ));
      }
    }
  }

  void removeLocal(String id) {
    state = state.where((m) => m.id != id).toList();
  }
}

// ============================================================================
// GROUPEMENT D'IMAGES
// ============================================================================
class _ChatListItem {
  final List<ChatMessage> messages;
  _ChatListItem.single(ChatMessage m) : messages = [m];
  _ChatListItem.group(this.messages);
}

List<_ChatListItem> _buildChatDisplayItems(List<ChatMessage> messages) {
  final items = <_ChatListItem>[];
  int i = 0;
  while (i < messages.length) {
    final m = messages[i];
    final isImg = m.mediaType == 'image' &&
        (m.mediaUrl?.isNotEmpty ?? false) &&
        !m.isViewOnce;
    if (isImg) {
      final group = <ChatMessage>[m];
      int j = i + 1;
      while (j < messages.length) {
        final next = messages[j];
        final sameSender = next.senderId == m.senderId;
        final alsoImg = next.mediaType == 'image' &&
            (next.mediaUrl?.isNotEmpty ?? false) &&
            !next.isViewOnce;
        final closeInTime = m.createdAt.difference(next.createdAt).inSeconds.abs() < 120;
        if (sameSender && alsoImg && closeInTime) {
          group.add(next);
          j++;
        } else {
          break;
        }
      }
      if (group.length > 1) {
        items.add(_ChatListItem.group(group));
        i = j;
        continue;
      }
    }
    items.add(_ChatListItem.single(m));
    i++;
  }
  return items;
}

// ============================================================================
// SCREEN
// ============================================================================
class ChatScreen extends ConsumerStatefulWidget {
  final String conversationId;
  final ChatConversation conversation;

  const ChatScreen({
    super.key,
    required this.conversationId,
    required this.conversation,
  });

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> with WidgetsBindingObserver {
  late final ChatService _chatService;
  late final ConnectionService _connectionService;
  final _scrollController = ScrollController();
  final _inputController = TextEditingController();
  final _inputFocus = FocusNode();
  final _searchCtrl = TextEditingController();

  UserStatus? _otherParticipant;
  List<GroupMember> _groupMembers = [];
  String _replyToId = '';

  bool _isEphemeral = false;
  int? _ephemeralDuration;
  bool _isTyping = false;
  bool _otherUserTyping = false;
  bool _isSending = false;
  bool _isConnectionValid = true;

  final AudioRecorder _audioRecorder = AudioRecorder();
  Timer? _recordTimer;
  int _recordDuration = 0;
  bool _isRecording = false;
  Uint8List? _audioBytes;
  String? _localAudioPath;
  bool _sendViewOnce = false;

  List<PlatformFile> _selectedFiles = [];

  Timer? _typingTimer;
  Timer? _markReadTimer;
  Timer? _searchDebounce;
  DateTime? _lastConnCheck;
  DateTime? _lastLoadMore;
  bool _isAgent = false;
  bool _isInternalNoteMode = false;
  StreamSubscription<List<ChatMessage>>? _messageSub;
  StreamSubscription<List<UserStatus>>? _presenceSub;

  bool _showStickers = false;

  // ── Édition ──
  String _editingMessageId = '';
  // ── Recherche in-chat ──
  bool _searchActive = false;
  List<String> _searchMatches = <String>[];
  int _searchPos = -1;
  // ── Épinglés ──
  List<ChatMessage> _pinnedMessages = <ChatMessage>[];
  int _pinnedCursor = 0;
  bool _pinnedBarClosed = false;
  // ── Favoris ──
  final Set<String> _starredIds = <String>{};
  // ── View once ──
  final Set<String> _viewedOnceIds = <String>{};
  // ── Jump to first unread ──
  int _initialUnread = 0;
  String _firstUnreadId = '';
  bool _showJumpUnread = false;
  bool _unreadAnchorDone = false;
  // ── Mentions @ ──
  List<GroupMember> _mentionSuggestions = <GroupMember>[];
  final List<String> _mentionedUserIds = <String>[];
  // ── Rappels 🔔 ──
  final Map<String, Timer> _reminderTimers = <String, Timer>{};
  final Set<String> _reminderScheduled = <String>{};
  // ── Scroll vers message ──
  final Map<String, GlobalKey> _msgKeys = <String, GlobalKey>{};

  static const List<String> _quickReactions = ['👍', '❤️', '😂', '😮', '😢', '🙏', '🔥', '🎉'];

  static const List<String> _emojis = [
    '😀','😃','😄','😁','😆','😅','🤣','😂','🙂','🙃',
    '😉','😊','😇','🥰','','🤩','😘','😗','😚','😙',
    '🥲','😋','😛','😜','🤪','😝','','🤗','','🤫',
    '🤔','🤐','🤨','😐','😑','😶','😏','😒','🙄','😬',
    '😮‍💨','','😦','😧','😮','😕','😟','🙁','☹️','😣',
    '😖','😫','😩','🥺','😢','😭','😤','😠','😡','🤬',
    '🤯','😳','🥵','🥶','😱','😨','😰','😥','😓','🤒',
    '🤕','🤢','🤮','🤧','😷','','😴','🤤','😪','😮‍💨',
    '🥳','🥸','😎','🤓','🧐','😕','😞','😔','😟','😬',
    '🫡','🫢','🫣','🫠','','','💀','☠️','👽','🤖',
  ];

  static const List<String> _reactions = [
    '👍','👎','','🤌','','✌️','','','🤟','',
    '','👈','','👆','','☝️','','🤚','️','🖖',
    '👋','🤝','🙏','️','💪','🦾','🫶','❤️','🧡','💛',
    '💚','💙','💜','🖤','','🤎','💔','❣️','💕','💞',
    '💓','💗','💖','💘','💝','❤️‍','❤️🩹','💯','💢','💥',
    '💫','💦','💨','🕳️','💣','💬','👁️‍🗨️','🗨️','🗯️','💭',
    '💤','🔥','⭐','🌟','✨','⚡','☄️','🌈','☀️','🌙',
    '✅','❌','','❗','❓','‼️','⁉️','🔔','','📌',
  ];

  static const List<String> _objects = [
    '📱','💻','🖥️','⌨️','️','','💾','💿','📀','🎥',
    '📷','📸','📹','📼','🔍','','💡','🔦','🕯️','💰',
    '💳','💎','⚖️','🧰','','🔨','⚙️','','🔒','🔓',
    '🔑','🗝️','📦','','📮','📝','📄','📑','📊','📈',
    '📉','🗓️','📅','','','⏳','🕐','','🔌','🧭',
  ];

  static const List<String> _flags = [
    '🏁','🚩','','🏴','️','🏳️‍🌈','🏴‍☠️',
    '🇫🇷','🇧🇪','🇨🇭','🇦','🇺🇸','🇬🇧','🇩🇪','🇸','🇮🇹',
    '🇵🇹','🇳🇱','🇱🇺','🇲🇦','🇩🇿','🇹🇳','🇳','🇨🇮','🇨🇲',
    '🇨🇩','🇨🇬','🇬🇦','🇱','🇧🇫','🇪','🇹🇩','🇳','🇧🇯',
    '🇹🇬','🇼','🇧🇮','🇩🇯','🇰🇲','🇲🇬','🇺','🇸🇨','🇦','🇧🇷',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _chatService = ref.read(chatServiceProvider);
    _connectionService = ConnectionService();
    _chatService.startPresenceHeartbeat();

    // Capturer le nombre de non-lus AVANT markAsRead (jump-to-unread)
    try {
      final convs = ref.read(chatListProvider).all;
      for (final c in convs) {
        if (c.id == widget.conversationId) {
          _initialUnread = c.unreadCount;
          break;
        }
      }
    } catch (e) {
      debugPrint('[Chat] ⚠️ unread capture: $e');
    }

    _inputController.addListener(() {
      setState(() {});
      _onTypingChanged(_inputController.text);
      _onMentionQueryChanged(_inputController.text);
    });
    _searchCtrl.addListener(_onSearchChanged);

    _checkConnectionSecurity();
    _loadUserRole();
    _getParticipantInfo();
    _loadGroupMembers();
    _loadPinned();
    _loadStarred();
    _markAsRead();

    try {
      _subscribeToPresence();
      _subscribeToRealtime();
      _subscribeToTyping();
    } catch (e) {
      debugPrint('[Chat] ⚠️ Failed to subscribe to realtime: $e');
    }

    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _chatService.stopPresenceHeartbeat();
    try {
      _chatService.stopTypingListener(widget.conversationId);
    } catch (e) {
      debugPrint('[Chat] ⚠️ stopTypingListener: $e');
    }
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.dispose();
    _inputController.dispose();
    _inputFocus.dispose();
    _searchCtrl.dispose();
    _typingTimer?.cancel();
    _markReadTimer?.cancel();
    _searchDebounce?.cancel();
    _messageSub?.cancel();
    _presenceSub?.cancel();
    for (final t in _reminderTimers.values) {
      t.cancel();
    }
    _reminderTimers.clear();
    _recordTimer?.cancel();
    _audioRecorder.dispose();
    super.dispose();
  }

  // ==========================================================================
  // CYCLE DE VIE / SÉCURITÉ
  // ==========================================================================
  Future<void> _checkConnectionSecurity() async {
    if (widget.conversation.isGroup || _isAgent) return;
    final now = DateTime.now();
    if (_lastConnCheck != null && now.difference(_lastConnCheck!).inSeconds < _kPresenceCheckThrottleSeconds) {
      return;
    }
    _lastConnCheck = now;
    final myId = _chatService.currentUserId;
    final otherId = widget.conversation.participantIds.firstWhere((id) => id != myId, orElse: () => '');
    if (otherId.isEmpty) return;
    try {
      final isConnected = await _chatRetry(
        () => _connectionService.checkConnection(myId, otherId),
        label: 'checkConnection',
      );
      if (mounted) setState(() => _isConnectionValid = isConnected);
    } catch (e) {
      debugPrint('[Chat] ⚠️ Connection check failed: $e');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _chatService.startPresenceHeartbeat();
        _checkConnectionSecurity();
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        _chatService.stopPresenceHeartbeat();
        break;
    }
  }

  Future<void> _loadUserRole() async {
    try {
      final uid = _chatService.currentUserId;
      if (uid.isEmpty) return;
      final role = await _chatRetry(
        () => _chatService.getUserRole(uid),
        label: 'loadUserRole',
      );
      if (mounted && role.isNotEmpty) {
        setState(() {
          _isAgent = role == 'agent' || role == 'admin' || role == 'support' || role == 'enterprise';
        });
      }
    } catch (e) {
      debugPrint('[Chat] ⚠️ Load user role failed: $e');
    }
  }

  Future<void> _loadGroupMembers() async {
    try {
      final members = await _chatRetry(
        () => _chatService.getGroupMembers(widget.conversationId),
        label: 'loadGroupMembers',
      );
      if (mounted) setState(() => _groupMembers = members);
    } catch (e) {
      debugPrint('[Chat] ⚠️ Load group members error: $e');
    }
  }

  Future<void> _loadPinned() async {
    try {
      final pinned = await _chatRetry(
        () => _chatService.getPinnedMessages(widget.conversationId),
        label: 'getPinnedMessages',
      );
      if (mounted) setState(() => _pinnedMessages = pinned);
    } catch (e) {
      debugPrint('[Chat] ⚠️ Load pinned error: $e');
    }
  }

  Future<void> _loadStarred() async {
    try {
      final starred = await _chatRetry(
        () => _chatService.getStarredMessages(limit: 100),
        label: 'getStarredMessages',
      );
      if (!mounted) return;
      setState(() {
        _starredIds.clear();
        for (final m in starred) {
          if (m.conversationId == widget.conversationId) _starredIds.add(m.id);
        }
      });
      _syncStarFlags();
    } catch (e) {
      debugPrint('[Chat] ⚠️ Load starred error: $e');
    }
  }

  /// Aligne le badge ⭐ des messages chargés sur l'état serveur.
  void _syncStarFlags() {
    if (_starredIds.isEmpty) return;
    final msgs = ref.read(chatMessagesProvider(widget.conversationId));
    final toFix = msgs.where((m) => _starredIds.contains(m.id) && !m.isStarred).toList();
    if (toFix.isEmpty) return;
    ref.read(chatMessagesProvider(widget.conversationId).notifier).upsertRealtime(
          toFix.map((m) => _overrideMsg(m, const {'is_starred': true})).toList(),
        );
  }

  // ==========================================================================
  // REALTIME
  // ==========================================================================
  void _subscribeToRealtime() {
    _messageSub = _chatService.subscribeToMessages(widget.conversationId).listen(
      (updated) {
        ref.read(chatMessagesProvider(widget.conversationId).notifier).upsertRealtime(updated);

        final me = _chatService.currentUserId;
        final idsToDeliver = updated
            .where((m) => m.senderId != me && !m.isDelivered && !m.isDeleted)
            .map((m) => m.id)
            .toList();
        if (idsToDeliver.isNotEmpty) {
          unawaited(_chatService.markMessagesDelivered(idsToDeliver));
        }

        // Rafraîchit la barre des épinglés si un pin a changé
        for (final m in updated) {
          if (m.isPinned && !_pinnedMessages.any((p) => p.id == m.id)) {
            _loadPinned();
            break;
          }
        }
        _scheduleRemindersFor(updated);
        _scheduleMarkAsRead();
      },
      onError: (e) => debugPrint('[Chat] ⚠️ Realtime subscription error: $e'),
    );
  }

  void _subscribeToTyping() {
    final cur = _chatService.currentUserId;
    if (cur.isEmpty) return;
    _chatService.startTypingListener(widget.conversationId, (sid, typing) {
      if (sid != cur && mounted) setState(() => _otherUserTyping = typing);
    });
  }

  void _subscribeToPresence() {
    if (widget.conversation.isGroup) return;
    final otherId = widget.conversation.participantIds.firstWhere((id) => id != _chatService.currentUserId, orElse: () => '');
    if (otherId.isEmpty) return;
    _presenceSub = _chatService.subscribeToPresence([otherId]).listen(
      (list) {
        if (mounted && list.isNotEmpty) setState(() => _otherParticipant = list.first);
      },
      onError: (e) => debugPrint('[Chat] ⚠️ Presence subscription error: $e'),
    );
  }

  void _sendTypingStatus(bool t) {
    if (!_isConnectionValid) return;
    if (_chatService.currentUserId.isEmpty) return;
    unawaited(_chatService.sendTypingStatus(widget.conversationId, isTyping: t));
  }

  void _onTypingChanged(String t) {
    if (t.isNotEmpty && !_isTyping) {
      _isTyping = true;
      _sendTypingStatus(true);
    } else if (t.isEmpty && _isTyping) {
      _isTyping = false;
      _sendTypingStatus(false);
    }
    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(milliseconds: _kTypingDebounceMs), () {
      if (_isTyping) {
        _isTyping = false;
        _sendTypingStatus(false);
      }
    });
  }

  // ==========================================================================
  // HELPERS GÉNÉRIQUES
  // ==========================================================================
  ChatMessage _overrideMsg(ChatMessage m, Map<String, dynamic> patch) {
    try {
      final json = Map<String, dynamic>.from(m.toJson());
      json.addAll(patch);
      return ChatMessage.fromJson(json);
    } catch (e) {
      debugPrint('[Chat] ⚠️ overrideMsg: $e');
      return m;
    }
  }

  GlobalKey _keyFor(String id) {
    if (_msgKeys.length > 600) _msgKeys.clear();
    GlobalKey? k = _msgKeys[id];
    if (k == null) {
      k = GlobalKey();
      _msgKeys[id] = k;
    }
    return k;
  }

  void _scrollToMessage(String id) {
    final k = _msgKeys[id];
    final ctx = k?.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(ctx, alignment: 0.3, duration: const Duration(milliseconds: 300));
    }
  }

  void _markAsRead() {
    try {
      ref.read(chatListProvider.notifier).markAsRead(widget.conversationId);
    } catch (e) {
      debugPrint('[Chat] ⚠️ Mark as read error: $e');
    }
  }

  void _scheduleMarkAsRead() {
    _markReadTimer?.cancel();
    _markReadTimer = Timer(const Duration(milliseconds: _kMarkReadDebounceMs), () {
      if (mounted) _markAsRead();
    });
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(0, duration: const Duration(milliseconds: 280), curve: Curves.easeOut);
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - _kLoadMoreThresholdPx) {
      final now = DateTime.now();
      if (_lastLoadMore != null && now.difference(_lastLoadMore!).inMilliseconds < _kLoadMoreThrottleMs) return;
      _lastLoadMore = now;
      ref.read(chatMessagesProvider(widget.conversationId).notifier).loadMore();
    }
    if (_showJumpUnread && _scrollController.position.pixels < 60) {
      setState(() => _showJumpUnread = false);
    }
  }

  // ==========================================================================
  // RAPPELS 🔔
  // ==========================================================================
  void _scheduleRemindersFor(List<ChatMessage> msgs) {
    final now = DateTime.now();
    for (final m in msgs) {
      final at = m.reminderAt;
      if (at == null || _reminderScheduled.contains(m.id)) continue;
      _reminderScheduled.add(m.id);
      final diff = at.toLocal().difference(now);
      if (diff.isNegative || diff > const Duration(hours: 12)) continue;
      _reminderTimers[m.id] = Timer(diff, () {
        if (!mounted) return;
        HapticFeedback.mediumImpact();
        _showInfo('🔔 ${_tr(AppLocalizations.of(context), 'chat_reminder_due', 'Rappel')} : ${m.previewText}');
      });
    }
  }

  void _showRemindSheet(ChatMessage msg) {
    final l10n = AppLocalizations.of(context);
    HapticFeedback.selectionClick();
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1, 9, 0);
    final options = <Map<String, dynamic>>[
      {'label': _tr(l10n, 'chat_remind_1h', 'Dans 1 heure'), 'at': now.add(const Duration(hours: 1))},
      {'label': _tr(l10n, 'chat_remind_3h', 'Dans 3 heures'), 'at': now.add(const Duration(hours: 3))},
      {'label': _tr(l10n, 'chat_remind_tomorrow', 'Demain 09:00'), 'at': tomorrow},
      {'label': _tr(l10n, 'chat_remind_week', 'Dans 1 semaine'), 'at': now.add(const Duration(days: 7))},
    ];
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        decoration: BoxDecoration(
          color: ThixPolicy.card,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: ThixPolicy.border, borderRadius: BorderRadius.circular(4))),
            const SizedBox(height: 14),
            Text(_tr(l10n, 'chat_remind_title', 'Me rappeler ce message'),
                style: ThixPolicy.titleStyle.copyWith(fontWeight: ThixPolicy.bold)),
            const SizedBox(height: 8),
            ...options.map((o) => ListTile(
                  leading: const Icon(Icons.notifications_active_outlined, color: ThixPolicy.primary),
                  title: Text(o['label'] as String),
                  onTap: () async {
                    Navigator.pop(ctx);
                    final at = o['at'] as DateTime;
                    try {
                      await _chatRetry(
                        () => _chatService.setMessageReminder(msg.id, at),
                        label: 'setMessageReminder',
                      );
                      ref.read(chatMessagesProvider(widget.conversationId).notifier).upsertRealtime([
                        _overrideMsg(msg, {'reminder_at': at.toUtc().toIso8601String()}),
                      ]);
                      _scheduleRemindersFor([_overrideMsg(msg, {'reminder_at': at.toUtc().toIso8601String()})]);
                      _showSuccess(_tr(l10n, 'chat_remind_set', 'Rappel programmé'));
                    } catch (e) {
                      _showError(_ChatValidators.friendlyError(e));
                    }
                  },
                )),
          ],
        ),
      ),
    );
  }

  // ==========================================================================
  // ÉDITION (15 min) + badge "Modifié"
  // ==========================================================================
  void _startEdit(ChatMessage msg) {
    HapticFeedback.selectionClick();
    setState(() {
      _editingMessageId = msg.id;
      _replyToId = '';
      _showStickers = false;
      _inputController.text = msg.content;
      _inputController.selection = TextSelection.fromPosition(TextPosition(offset: msg.content.length));
    });
    _inputFocus.requestFocus();
  }

  Future<void> _applyEdit(ChatMessage msg, String newContent) async {
    final clean = _ChatValidators.sanitize(newContent, maxLength: _kMaxMessageLength);
    if (clean.isEmpty || clean == msg.content) {
      _cancelEdit();
      return;
    }
    final l10n = AppLocalizations.of(context);
    try {
      final updated = await _chatRetry(
        () => _chatService.editMessage(msg.id, clean),
        label: 'editMessage',
      );
      if (updated != null) {
        ref.read(chatMessagesProvider(widget.conversationId).notifier).upsertRealtime([updated]);
      } else {
        ref.read(chatMessagesProvider(widget.conversationId).notifier).upsertRealtime([
          _overrideMsg(msg, {
            'content': clean,
            'is_edited': true,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          }),
        ]);
      }
      _showSuccess(_tr(l10n, 'chat_edit_done', 'Message modifié'));
    } catch (e) {
      _showError(_ChatValidators.friendlyError(e));
    } finally {
      _cancelEdit();
    }
  }

  void _cancelEdit() {
    setState(() {
      _editingMessageId = '';
      _inputController.clear();
    });
  }

  // ==========================================================================
  // SUPPRESSIONS
  // ==========================================================================
  Future<void> _deleteForMe(ChatMessage msg) async {
    final l10n = AppLocalizations.of(context);
    final ok = await _confirmDialog(
      title: _tr(l10n, 'chat_delete_title', 'Supprimer le message ?'),
      body: _tr(l10n, 'chat_delete_for_me_body', 'Suppression uniquement pour vous.'),
      danger: true,
    );
    if (ok != true) return;
    try {
      await _chatRetry(() => _chatService.deleteMessage(msg.id), label: 'deleteMessage');
      ref.read(chatMessagesProvider(widget.conversationId).notifier).removeLocal(msg.id);
      _showSuccess(_tr(l10n, 'chat_deleted_me', 'Message supprimé pour vous'));
    } catch (e) {
      _showError(_ChatValidators.friendlyError(e));
    }
  }

  Future<void> _deleteForAll(ChatMessage msg) async {
    final l10n = AppLocalizations.of(context);
    final ok = await _confirmDialog(
      title: _tr(l10n, 'chat_delete_for_all_title', 'Supprimer pour tous ?'),
      body: _tr(l10n, 'chat_delete_for_all_body', 'Le message sera remplacé par « Message supprimé » chez tous les participants.'),
      danger: true,
    );
    if (ok != true) return;
    try {
      await _chatRetry(() => _chatService.deleteMessageForAll(msg.id), label: 'deleteMessageForAll');
      ref.read(chatMessagesProvider(widget.conversationId).notifier).upsertRealtime([
        _overrideMsg(msg, {
          'is_deleted_for_all': true,
          'is_deleted': true,
          'content': '',
          'media_url': null,
        }),
      ]);
      _showSuccess(_tr(l10n, 'chat_deleted_all', 'Message supprimé pour tous'));
    } catch (e) {
      _showError(_ChatValidators.friendlyError(e));
    }
  }

  Future<bool?> _confirmDialog({required String title, required String body, bool danger = false}) {
    final l10n = AppLocalizations.of(context);
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ThixPolicy.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rLg)),
        title: Text(title, style: ThixPolicy.h3Style.copyWith(fontWeight: ThixPolicy.bold, fontSize: 16)),
        content: Text(body, style: ThixPolicy.bodyStyle),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(_tr(l10n, 'common_cancel', 'Annuler'))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: danger ? ThixPolicy.danger : ThixPolicy.primary,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(_tr(l10n, 'common_confirm', 'Confirmer')),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // FORWARD (max 5)
  // ==========================================================================
  void _showForwardSheet(ChatMessage msg) {
    final l10n = AppLocalizations.of(context);
    HapticFeedback.selectionClick();
    final conversations = ref.read(chatListProvider).all
        .where((c) => c.id != widget.conversationId)
        .toList();
    final selected = <String>{};

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          height: MediaQuery.of(ctx).size.height * 0.65,
          decoration: BoxDecoration(
            color: ThixPolicy.card,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
          ),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: ThixPolicy.border, borderRadius: BorderRadius.circular(4))),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.forward_rounded, color: ThixPolicy.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${_tr(l10n, 'chat_forward_title', 'Transférer')} (${selected.length}/$_kMaxForward)',
                      style: ThixPolicy.titleStyle.copyWith(fontWeight: ThixPolicy.bold),
                    ),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: selected.isEmpty ? ThixPolicy.border : ThixPolicy.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: selected.isEmpty
                        ? null
                        : () async {
                            Navigator.pop(ctx);
                            try {
                              final sent = await _chatRetry(
                                () => _chatService.forwardMessage(
                                  originalMessageId: msg.id,
                                  targetConversationIds: selected.toList(),
                                ),
                                label: 'forwardMessage',
                                timeout: _kUploadTimeout,
                              );
                              _showSuccess(_tr(l10n, 'chat_forward_done', 'Transféré à {n} conversation(s)')
                                  .replaceAll('{n}', '${sent.length}'));
                            } catch (e) {
                              _showError(_ChatValidators.friendlyError(e));
                            }
                          },
                    child: Text(_tr(l10n, 'chat_send', 'Envoyer')),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  itemCount: conversations.length,
                  itemBuilder: (ctx, i) {
                    final c = conversations[i];
                    final checked = selected.contains(c.id);
                    final avatar = _ChatValidators.sanitizeUrl(c.displayAvatar);
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: ThixPolicy.tint,
                        backgroundImage: avatar != null ? CachedNetworkImageProvider(avatar) : null,
                        child: avatar == null ? const Icon(Icons.person, color: ThixPolicy.textSecondary) : null,
                      ),
                      title: Text(_ChatValidators.sanitize(c.displayName, maxLength: 60),
                          style: ThixPolicy.labelStyle.copyWith(fontWeight: ThixPolicy.bold)),
                      trailing: Icon(checked ? Icons.check_circle : Icons.radio_button_unchecked,
                          color: checked ? ThixPolicy.primary : ThixPolicy.textMuted),
                      onTap: () {
                        setSheetState(() {
                          if (checked) {
                            selected.remove(c.id);
                          } else if (selected.length < _kMaxForward) {
                            selected.add(c.id);
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text(_tr(l10n, 'chat_forward_max', 'Maximum 5 destinataires')),
                              backgroundColor: ThixPolicy.warning,
                              behavior: SnackBarBehavior.floating,
                              duration: const Duration(milliseconds: 900),
                            ));
                          }
                        });
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================================================
  // PIN / STAR
  // ==========================================================================
  Future<void> _togglePin(ChatMessage msg) async {
    final l10n = AppLocalizations.of(context);
    HapticFeedback.selectionClick();
    try {
      if (msg.isPinned) {
        await _chatRetry(() => _chatService.unpinMessage(msg.id), label: 'unpinMessage');
        ref.read(chatMessagesProvider(widget.conversationId).notifier)
            .upsertRealtime([_overrideMsg(msg, const {'is_pinned': false})]);
        _showInfo(_tr(l10n, 'chat_unpinned', 'Message désépinglé'));
      } else {
        await _chatRetry(
          () => _chatService.pinMessage(msg.id, widget.conversationId),
          label: 'pinMessage',
        );
        ref.read(chatMessagesProvider(widget.conversationId).notifier)
            .upsertRealtime([_overrideMsg(msg, const {'is_pinned': true})]);
        _showInfo(_tr(l10n, 'chat_pinned', 'Message épinglé'));
      }
      await _loadPinned();
    } catch (e) {
      _showError(_ChatValidators.friendlyError(e));
    }
  }

  Future<void> _toggleStar(ChatMessage msg) async {
    HapticFeedback.lightImpact();
    final nowStarred = !_starredIds.contains(msg.id);
    setState(() {
      if (nowStarred) {
        _starredIds.add(msg.id);
      } else {
        _starredIds.remove(msg.id);
      }
    });
    ref.read(chatMessagesProvider(widget.conversationId).notifier)
        .upsertRealtime([_overrideMsg(msg, {'is_starred': nowStarred})]);
    unawaited(_chatService.toggleStarMessage(msg.id));
  }

  void _showStarredSheet() {
    final l10n = AppLocalizations.of(context);
    final msgs = ref.read(chatMessagesProvider(widget.conversationId))
        .where((m) => _starredIds.contains(m.id))
        .toList();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        height: MediaQuery.of(ctx).size.height * 0.6,
        decoration: BoxDecoration(
          color: ThixPolicy.card,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: ThixPolicy.border, borderRadius: BorderRadius.circular(4))),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.star_rounded, color: ThixPolicy.gold),
                const SizedBox(width: 8),
                Text(_tr(l10n, 'chat_starred_title', 'Messages favoris'),
                    style: ThixPolicy.titleStyle.copyWith(fontWeight: ThixPolicy.bold)),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: msgs.isEmpty
                  ? Center(
                      child: Text(_tr(l10n, 'chat_starred_empty', 'Aucun message favori'),
                          style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.textSecondary)))
                  : ListView.builder(
                      itemCount: msgs.length,
                      itemBuilder: (ctx, i) {
                        final m = msgs[i];
                        return ListTile(
                          leading: const Icon(Icons.star_rounded, color: ThixPolicy.gold, size: 18),
                          title: Text(m.previewText, maxLines: 2, overflow: TextOverflow.ellipsis),
                          subtitle: Text(DateFormat('dd/MM/yyyy HH:mm').format(m.createdAt.toLocal()),
                              style: ThixPolicy.microStyle.copyWith(color: ThixPolicy.textMuted)),
                          onTap: () {
                            Navigator.pop(ctx);
                            _scrollToMessage(m.id);
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================================
  // RECHERCHE IN-CHAT + JUMP
  // ==========================================================================
  void _onSearchChanged() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: _kSearchDebounceMs), () {
      if (!mounted) return;
      final q = _searchCtrl.text.trim().toLowerCase();
      final msgs = ref.read(chatMessagesProvider(widget.conversationId));
      setState(() {
        if (q.isEmpty) {
          _searchMatches = <String>[];
          _searchPos = -1;
        } else {
          _searchMatches = msgs
              .where((m) =>
                  m.content.toLowerCase().contains(q) ||
                  (m.mediaName ?? '').toLowerCase().contains(q))
              .map((m) => m.id)
              .toList();
          _searchPos = _searchMatches.isEmpty ? -1 : 0;
        }
      });
    });
  }

  String get _searchHighlightId =>
      (_searchPos >= 0 && _searchPos < _searchMatches.length) ? _searchMatches[_searchPos] : '';

  void _searchMove(int delta) {
    if (_searchMatches.isEmpty) return;
    setState(() {
      _searchPos = (_searchPos + delta) % _searchMatches.length;
      if (_searchPos < 0) _searchPos = _searchMatches.length - 1;
    });
    _scrollToMessage(_searchHighlightId);
  }

  /// Recherche serveur (messages plus anciens) : sheet de résultats + jump paginé.
  Future<void> _searchRemote() async {
    final q = _searchCtrl.text.trim();
    if (q.length < 3) return;
    final l10n = AppLocalizations.of(context);
    final results = await _chatRetry(
      () => _chatService.searchInConversation(widget.conversationId, q, limit: 30),
      label: 'searchInConversation',
    );
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        height: MediaQuery.of(ctx).size.height * 0.6,
        decoration: BoxDecoration(
          color: ThixPolicy.card,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: ThixPolicy.border, borderRadius: BorderRadius.circular(4))),
            const SizedBox(height: 12),
            Text('${_tr(l10n, 'chat_search_results', 'Résultats')} : ${results.length}',
                style: ThixPolicy.titleStyle.copyWith(fontWeight: ThixPolicy.bold)),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: results.length,
                itemBuilder: (ctx, i) {
                  final m = results[i];
                  return ListTile(
                    title: Text(m.previewText, maxLines: 2, overflow: TextOverflow.ellipsis),
                    subtitle: Text(DateFormat('dd/MM/yyyy HH:mm').format(m.createdAt.toLocal()),
                        style: ThixPolicy.microStyle.copyWith(color: ThixPolicy.textMuted)),
                    onTap: () async {
                      Navigator.pop(ctx);
                      setState(() => _searchActive = false);
                      final notifier = ref.read(chatMessagesProvider(widget.conversationId).notifier);
                      final found = await notifier.ensureLoaded(m.id);
                      if (mounted && found) {
                        setState(() {});
                        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToMessage(m.id));
                      } else if (mounted) {
                        _showInfo(_tr(l10n, 'chat_search_notfound', 'Message hors de portée'));
                      }
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _anchorFirstUnread(List<ChatMessage> messages) {
    if (_unreadAnchorDone || _initialUnread <= 0 || messages.isEmpty) return;
    _unreadAnchorDone = true;
    final idx = (_initialUnread - 1).clamp(0, messages.length - 1);
    final id = messages[idx].id;
    setState(() {
      _firstUnreadId = id;
      _showJumpUnread = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToMessage(id));
  }

  // ==========================================================================
  // MENTIONS @
  // ==========================================================================
  void _onMentionQueryChanged(String text) {
    final match = RegExp(r'@([A-Za-zÀ-ÖØ-öø-ÿ0-9_.]{0,20})$').firstMatch(text);
    if (match == null || _groupMembers.isEmpty) {
      if (_mentionSuggestions.isNotEmpty) setState(() => _mentionSuggestions = <GroupMember>[]);
      return;
    }
    final q = (match.group(1) ?? '').toLowerCase();
    final me = _chatService.currentUserId;
    final sugg = _groupMembers
        .where((m) => m.userId != me && m.displayName.toLowerCase().contains(q))
        .take(4)
        .toList();
    setState(() => _mentionSuggestions = sugg);
  }

  void _insertMention(GroupMember member) {
    HapticFeedback.selectionClick();
    final text = _inputController.text;
    final match = RegExp(r'@([A-Za-zÀ-ÖØ-öø-ÿ0-9_.]{0,20})$').firstMatch(text);
    if (match == null) return;
    final prefix = text.substring(0, match.start);
    final inserted = '@${member.displayName} ';
    _inputController.text = prefix + inserted;
    _inputController.selection = TextSelection.fromPosition(TextPosition(offset: _inputController.text.length));
    if (!_mentionedUserIds.contains(member.userId)) _mentionedUserIds.add(member.userId);
    setState(() => _mentionSuggestions = <GroupMember>[]);
  }

  // ==========================================================================
  // VIEW ONCE
  // ==========================================================================
  void _onViewOnceOpened(ChatMessage msg) {
    if (_viewedOnceIds.contains(msg.id)) return;
    setState(() => _viewedOnceIds.add(msg.id));
    unawaited(_chatService.markViewOnceAsSeen(msg.id));
    ref.read(chatMessagesProvider(widget.conversationId).notifier)
        .upsertRealtime([_overrideMsg(msg, const {'has_been_viewed': true})]);
  }

  // ==========================================================================
  // INFO MESSAGE + EXPORT (entreprise)
  // ==========================================================================
  void _showMessageInfo(ChatMessage msg) {
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ThixPolicy.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(_tr(l10n, 'chat_info_title', 'Informations du message'),
            style: ThixPolicy.h3Style.copyWith(fontWeight: ThixPolicy.bold, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _infoRow(_tr(l10n, 'chat_info_sender', 'Expéditeur'), msg.senderName),
            _infoRow(_tr(l10n, 'chat_info_date', 'Date'), DateFormat('dd/MM/yyyy HH:mm:ss').format(msg.createdAt.toLocal())),
            if (msg.senderId == _chatService.currentUserId)
              _infoRow(_tr(l10n, 'chat_info_status', 'Statut'),
                  msg.isRead ? _tr(l10n, 'chat_info_read', 'Lu') : (msg.isDelivered ? _tr(l10n, 'chat_info_delivered', 'Distribué') : _tr(l10n, 'chat_info_sent', 'Envoyé'))),
            if (msg.hasMedia) _infoRow(_tr(l10n, 'chat_info_media', 'Média'), '${msg.mediaName ?? '-'} (${(msg.mediaSize ?? 0) ~/ 1024} Ko)'),
            if (msg.isForwarded) _infoRow(_tr(l10n, 'chat_info_forwarded', 'Transféré depuis'), msg.forwardedFromSenderName ?? '-'),
            if (msg.isEphemeral) _infoRow(_tr(l10n, 'chat_info_ephemeral', 'Éphémère'), '${msg.ephemeralDuration ?? 0}s'),
            if (msg.isViewOnce) _infoRow('View once', msg.hasBeenViewed ? _tr(l10n, 'chat_info_opened', 'Ouvert') : _tr(l10n, 'chat_info_pending', 'En attente')),
            if (msg.reminderAt != null) _infoRow(_tr(l10n, 'chat_info_reminder', 'Rappel'), DateFormat('dd/MM HH:mm').format(msg.reminderAt!.toLocal())),
            _infoRow('ID', msg.id.length > 12 ? '${msg.id.substring(0, 8)}…' : msg.id),
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(_tr(l10n, 'common_close', 'Fermer')))],
      ),
    );
  }

  Widget _infoRow(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 90, child: Text(label, style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.textMuted))),
            Expanded(child: Text(value, style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.textMain, fontWeight: FontWeight.w600))),
          ],
        ),
      );

  Future<void> _exportConversation() async {
    final l10n = AppLocalizations.of(context);
    final msgs = ref.read(chatMessagesProvider(widget.conversationId));
    final sb = StringBuffer('date;expediteur;contenu\n');
    for (final m in msgs.reversed) {
      sb.writeln('${DateFormat('yyyy-MM-dd HH:mm').format(m.createdAt.toLocal())};'
          '${m.senderName.replaceAll(';', ',')};'
          '${m.content.replaceAll(';', ',').replaceAll('\n', ' ')}');
    }
    await Clipboard.setData(ClipboardData(text: sb.toString()));
    _showSuccess(_tr(l10n, 'chat_export_done', 'Conversation copiée (CSV)'));
  }

  // ==========================================================================
  // APPELS / PERMISSIONS / ENREGISTREMENT AUDIO
  // ==========================================================================
  Future<bool> _checkPermissionWithDisclosure(Permission permission, String explanation) async {
    if (kIsWeb) return true;
    var status = await permission.status;
    if (status.isGranted) return true;
    if (!mounted) return false;
    final l10n = AppLocalizations.of(context);
    bool? userAgreed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: ThixPolicy.card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: ThixPolicy.border)),
        title: Row(children: [
          const Icon(Icons.privacy_tip_outlined, color: ThixPolicy.textMain, size: 28),
          const SizedBox(width: 10),
          Expanded(child: Text(_tr(l10n, 'chat_auth_required', 'Autorisation requise'),
              style: ThixPolicy.h3Style.copyWith(color: ThixPolicy.textMain, fontWeight: ThixPolicy.bold))),
        ]),
        content: Text(explanation, style: ThixPolicy.bodyStyle.copyWith(color: ThixPolicy.textSecondary, fontSize: 16, height: 1.4)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(_tr(l10n, 'common_cancel', 'Annuler'))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: ThixPolicy.primary, foregroundColor: Colors.white, elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () => Navigator.pop(context, true),
            child: Text(_tr(l10n, 'chat_understood', 'J’ai compris'), style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (userAgreed != true) return false;
    var newStatus = await permission.request();
    return newStatus.isGranted;
  }

  Future<void> _startCall(CallType type) async {
    final l10n = AppLocalizations.of(context);
    if (!_isConnectionValid) {
      _showError(_tr(l10n, 'chat_call_inactive', 'Connexion inactive avec ce contact'));
      return;
    }
    HapticFeedback.mediumImpact();
    final hasMic = await _checkPermissionWithDisclosure(Permission.microphone, _tr(l10n, 'chat_mic_call_disclosure', 'Le micro est nécessaire pour les appels.'));
    if (!hasMic) return;
    if (type == CallType.video) {
      final hasCam = await _checkPermissionWithDisclosure(Permission.camera, _tr(l10n, 'chat_cam_call_disclosure', 'La caméra est nécessaire pour les appels vidéo.'));
      if (!hasCam) return;
    }
    final myId = _chatService.currentUserId;
    final otherId = widget.conversation.participantIds.firstWhere((id) => id != myId, orElse: () => '');
    if (otherId.isEmpty) return;
    ref.read(callProvider.notifier).start(
          myUserId: myId,
          calleeId: otherId,
          calleeName: widget.conversation.displayName,
          calleeAvatar: widget.conversation.displayAvatar,
          type: type,
        );
    Navigator.push(context, MaterialPageRoute(builder: (_) => const CallPage()));
  }

  Future<void> _startRecording() async {
    final l10n = AppLocalizations.of(context);
    if (!_isConnectionValid || _isRecording) return;
    HapticFeedback.mediumImpact();
    final hasPerm = await _checkPermissionWithDisclosure(Permission.microphone, _tr(l10n, 'chat_mic_disclosure', 'Le micro est nécessaire pour les messages vocaux.'));
    if (!hasPerm) return;
    try {
      String recordPath;
      if (kIsWeb) {
        recordPath = 'audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
      } else {
        final dir = await getTemporaryDirectory();
        recordPath = p.join(dir.path, 'audio_${DateTime.now().millisecondsSinceEpoch}.m4a');
      }
      await _audioRecorder.start(const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 128000), path: recordPath);
      if (!mounted) return;
      setState(() {
        _isRecording = true;
        _recordDuration = 0;
        _audioBytes = null;
        _localAudioPath = null;
        _showStickers = false;
      });
      _recordTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) return;
        setState(() => _recordDuration++);
        if (_recordDuration >= _kMaxAudioDurationSeconds) _stopRecording();
      });
    } catch (e) {
      debugPrint('[Chat] ❌ Start recording error: $e');
      if (mounted) _showError(_tr(l10n, 'chat_recording_error', 'Erreur d’enregistrement'));
    }
  }

  Future<void> _stopRecording() async {
    _recordTimer?.cancel();
    try {
      final path = await _audioRecorder.stop();
      if (mounted) setState(() => _isRecording = false);
      if (path != null) {
        Uint8List bytes;
        if (kIsWeb) {
          final response = await _chatRetry(() => http_get(Uri.parse(path)), label: 'downloadAudio');
          bytes = response;
        } else {
          bytes = await File(path).readAsBytes();
        }
        if (mounted) {
          setState(() {
            _audioBytes = bytes;
            _localAudioPath = path;
          });
        }
      }
    } catch (e) {
      debugPrint('[Chat] ❌ Stop recording error: $e');
      if (mounted) _showError(_tr(AppLocalizations.of(context), 'chat_recording_error', 'Erreur d’enregistrement'));
    }
  }

  // ============================================================================
  // ENVOI
  // ============================================================================
  Future<void> _sendMessage() async {
    final l10n = AppLocalizations.of(context);
    if (!_isConnectionValid) {
      _showError(_tr(l10n, 'chat_send_inactive', 'Connexion inactive : envoi impossible'));
      return;
    }

    // Mode édition → update au lieu d'insert
    if (_editingMessageId.isNotEmpty) {
      final msgs = ref.read(chatMessagesProvider(widget.conversationId));
      final target = msgs.where((m) => m.id == _editingMessageId).toList();
      if (target.isNotEmpty) {
        await _applyEdit(target.first, _inputController.text);
        return;
      }
      _cancelEdit();
    }

    final text = _ChatValidators.sanitize(_inputController.text.trim(), maxLength: _kMaxMessageLength);
    if (text.isEmpty && _selectedFiles.isEmpty && _audioBytes == null) return;
    if (_isSending) return;

    _isTyping = false;
    _sendTypingStatus(false);
    setState(() => _isSending = true);
    HapticFeedback.mediumImpact();

    final mentions = List<String>.from(_mentionedUserIds);
    final viewOnce = _sendViewOnce;

    try {
      if (_audioBytes != null) {
        final msg = await _chatRetry(
          () => _chatService.sendAudioMessage(
            conversationId: widget.conversationId,
            audioData: _audioBytes!,
            duration: _recordDuration > 0 ? _recordDuration : 1,
            isEphemeral: _isEphemeral,
            ephemeralDuration: _ephemeralDuration,
            replyToId: _replyToId.isEmpty ? null : _replyToId,
          ),
          label: 'sendAudio',
          timeout: _kUploadTimeout,
        );
        ref.read(chatMessagesProvider(widget.conversationId).notifier).upsertRealtime([msg]);
      } else if (_selectedFiles.isNotEmpty) {
        final filesToSend = List<PlatformFile>.from(_selectedFiles);
        setState(() => _selectedFiles.clear());

        final imageFiles = <PlatformFile>[];
        final otherFiles = <PlatformFile>[];
        for (final f in filesToSend) {
          if (!_ChatValidators.isValidFileSize(f.size)) {
            _showError('${_tr(l10n, 'chat_file_too_big', 'Fichier trop volumineux :')} ${f.name}');
            continue;
          }
          final ext = (f.extension ?? '').toLowerCase();
          if (['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(ext)) {
            imageFiles.add(f);
          } else {
            otherFiles.add(f);
          }
        }

        if (imageFiles.isNotEmpty) {
          final urls = <String>[];
          for (final f in imageFiles) {
            final bytes = f.bytes ?? (f.path != null ? await File(f.path!).readAsBytes() : null);
            if (bytes == null) continue;
            final ext = f.extension ?? 'jpg';
            final url = await _chatRetry(
              () => _chatService.uploadFileWithUniqueName('chat-media', 'messages/${widget.conversationId}', Uint8List.fromList(bytes), ext),
              label: 'uploadImage',
              timeout: _kUploadTimeout,
            );
            if (url != null) urls.add(url);
          }
          if (urls.isNotEmpty) {
            for (var i = 0; i < urls.length; i++) {
              final msg = await _chatRetry(
                () => _chatService.sendMessage(
                  conversationId: widget.conversationId,
                  content: text.isNotEmpty && i == 0 ? text : imageFiles[i].name,
                  mediaUrl: urls[i],
                  mediaType: 'image',
                  mediaName: imageFiles[i].name,
                  mediaSize: imageFiles[i].size,
                  isEphemeral: _isEphemeral,
                  ephemeralDuration: _ephemeralDuration,
                  isViewOnce: viewOnce,
                  mentionedUserIds: mentions,
                  replyToId: i == 0 && _replyToId.isNotEmpty ? _replyToId : null,
                ),
                label: 'sendImage[$i]',
              );
              ref.read(chatMessagesProvider(widget.conversationId).notifier).upsertRealtime([msg]);
            }
          }
        }

        for (final f in otherFiles) {
          final bytes = f.bytes ?? (f.path != null ? await File(f.path!).readAsBytes() : null);
          if (bytes == null) continue;
          final ext = f.extension ?? 'bin';
          final url = await _chatRetry(
            () => _chatService.uploadFileWithUniqueName('chat-media', 'messages/${widget.conversationId}', Uint8List.fromList(bytes), ext),
            label: 'uploadFile',
            timeout: _kUploadTimeout,
          );
          if (url != null) {
            final msg = await _chatRetry(
              () => _chatService.sendMessage(
                conversationId: widget.conversationId,
                content: text.isNotEmpty ? text : f.name,
                mediaUrl: url,
                mediaType: _ChatValidators.getMediaType(ext),
                mediaName: f.name,
                mediaSize: f.size,
                isEphemeral: _isEphemeral,
                ephemeralDuration: _ephemeralDuration,
                mentionedUserIds: mentions,
                replyToId: _replyToId.isEmpty ? null : _replyToId,
              ),
              label: 'sendFile',
            );
            ref.read(chatMessagesProvider(widget.conversationId).notifier).upsertRealtime([msg]);
          }
        }
      } else if (text.isNotEmpty) {
        final msg = await _chatRetry(
          () => _chatService.sendMessage(
            conversationId: widget.conversationId,
            content: text,
            replyToId: _replyToId.isEmpty ? null : _replyToId,
            isEphemeral: _isEphemeral,
            ephemeralDuration: _isEphemeral ? _ephemeralDuration : null,
            mentionedUserIds: mentions,
          ),
          label: 'sendText',
        );
        ref.read(chatMessagesProvider(widget.conversationId).notifier).upsertRealtime([msg]);
      }

      if (mounted) {
        setState(() {
          _inputController.clear();
          _replyToId = '';
          _audioBytes = null;
          _localAudioPath = null;
          _sendViewOnce = false;
          _mentionedUserIds.clear();
          if (_isInternalNoteMode) _isInternalNoteMode = false;
          _isEphemeral = false;
          _ephemeralDuration = null;
        });
      }
      _scrollToBottom();
    } catch (e) {
      debugPrint('[Chat] ❌ Send message error: $e');
      if (mounted) _showError(_ChatValidators.friendlyError(e));
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  // ============================================================================
  // PIÈCES JOINTES / DIVERS
  // ============================================================================
  Future<void> _pickFile() async {
    HapticFeedback.selectionClick();
    try {
      final result = await FilePicker.platform.pickFiles(allowMultiple: true, withData: true);
      if (result != null && result.files.isNotEmpty) {
        final validFiles = result.files.where((f) => _ChatValidators.isValidFileSize(f.size)).toList();
        if (validFiles.length < result.files.length) {
          _showWarning('${_tr(AppLocalizations.of(context), 'chat_file_too_big', 'Fichier trop volumineux :')} ${result.files.length - validFiles.length} ignoré(s)');
        }
        if (validFiles.isNotEmpty && mounted) setState(() => _selectedFiles.addAll(validFiles));
      }
    } catch (e) {
      if (mounted) _showError(_ChatValidators.friendlyError(e));
    }
  }

  void _removeFile(int index) {
    HapticFeedback.lightImpact();
    setState(() => _selectedFiles.removeAt(index));
  }

  void _escalateConversation() {
    HapticFeedback.mediumImpact();
    context.pushNamed(
      'chatEscalate',
      pathParameters: {'conversationId': widget.conversationId},
      queryParameters: {'agentId': _chatService.currentUserId, 'agentName': 'Agent'},
    );
  }

  void _viewEscalationHistory() {
    HapticFeedback.selectionClick();
    context.pushNamed('chatEscalationHistory', pathParameters: {'conversationId': widget.conversationId});
  }

  void _toggleInternalNoteMode() {
    HapticFeedback.selectionClick();
    setState(() => _isInternalNoteMode = !_isInternalNoteMode);
    final l10n = AppLocalizations.of(context);
    _showInfo(_isInternalNoteMode ? _tr(l10n, 'chat_internal_note_on', 'Note interne activée') : _tr(l10n, 'chat_internal_note_off', 'Note interne désactivée'));
  }

  // ============================================================================
  // SNACKBARS
  // ============================================================================
  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(message)),
      ]),
      backgroundColor: ThixPolicy.success,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(milliseconds: 1400),
    ));
  }

  void _showError(String message) {
    if (!mounted) return;
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.error_outline_rounded, color: Colors.white, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(message)),
      ]),
      backgroundColor: ThixPolicy.danger,
      behavior: SnackBarBehavior.floating,
    ));
  }

  void _showWarning(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.warning_rounded, color: Colors.white, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(message)),
      ]),
      backgroundColor: ThixPolicy.warning,
      behavior: SnackBarBehavior.floating,
    ));
  }

  void _showInfo(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: ThixPolicy.primary,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 2),
    ));
  }

  // ============================================================================
  // PRÉSENCE
  // ============================================================================
  Future<void> _getParticipantInfo() async {
    if (widget.conversation.isGroup) return;
    final otherId = widget.conversation.participantIds.firstWhere((id) => id != _chatService.currentUserId, orElse: () => '');
    if (otherId.isEmpty) return;
    try {
      final p = await _chatRetry(() => _chatService.getUserPresence(otherId), label: 'getUserPresence');
      if (mounted) setState(() => _otherParticipant = p);
    } catch (e) {
      debugPrint('[Chat] ⚠️ Get participant info error: $e');
    }
  }

  String _getPresenceText(UserStatus status) {
    final l10n = AppLocalizations.of(context);
    final lastSeen = status.lastSeenAt;
    if (status.status == 'online') {
      if (lastSeen == null) return _tr(l10n, 'chat_online', 'En ligne');
      if (DateTime.now().difference(lastSeen.toLocal()).inMinutes <= 2) return _tr(l10n, 'chat_online', 'En ligne');
    }
    if (lastSeen == null) return _tr(l10n, 'chat_online', 'En ligne');
    return '${_tr(l10n, 'chat_seen_at', 'Vu à')} ${_formatLastSeen(lastSeen.toLocal())}';
  }

  bool get _isOnline {
    if (_otherParticipant == null) return false;
    final p = _otherParticipant!;
    if (p.status != 'online') return false;
    final lastSeen = p.lastSeenAt;
    if (lastSeen == null) return true;
    return DateTime.now().difference(lastSeen.toLocal()).inMinutes <= 2;
  }

  String _formatLastSeen(DateTime localDate) {
    final l10n = AppLocalizations.of(context);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(localDate.year, localDate.month, localDate.day);
    if (day == today) return '${_tr(l10n, 'chat_at', 'à')} ${DateFormat('HH:mm').format(localDate)}';
    if (day == today.subtract(const Duration(days: 1))) return '${_tr(l10n, 'chat_yesterday_at', 'hier à')} ${DateFormat('HH:mm').format(localDate)}';
    return '${_tr(l10n, 'chat_on', 'le')} ${DateFormat('dd/MM/yyyy').format(localDate)}';
  }

  // ============================================================================
  // BUILD
  // ============================================================================
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final messages = ref.watch(chatMessagesProvider(widget.conversationId));
    final msgNotifier = ref.watch(chatMessagesProvider(widget.conversationId).notifier);
    final displayItems = _buildChatDisplayItems(messages);
    final currentUid = _chatService.currentUserId;

    if (!_unreadAnchorDone && messages.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _anchorFirstUnread(messages));
      _scheduleRemindersFor(messages);
    }

    final int firstUnreadIdx = _firstUnreadId.isEmpty
        ? -1
        : displayItems.indexWhere((it) => it.messages.first.id == _firstUnreadId);

    return Scaffold(
      backgroundColor: ThixPolicy.surfaceSoft,
      appBar: _buildAppBar(l10n),
      body: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: _ThixChatBackgroundPainter())),
          Column(
            children: [
              if (_pinnedMessages.isNotEmpty && !_pinnedBarClosed) _buildPinnedBar(l10n),
              if (_searchActive) _buildSearchBar(l10n),
              Expanded(
                child: Stack(
                  children: [
                    RepaintBoundary(
                      child: ListView.builder(
                        controller: _scrollController,
                        reverse: true,
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                        itemCount: displayItems.length + (msgNotifier.loadingMore ? 1 : 0),
                        itemBuilder: (ctx, i) {
                          if (i == displayItems.length) {
                            return const Center(
                              child: Padding(
                                padding: EdgeInsets.all(16),
                                child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: ThixPolicy.primary)),
                              ),
                            );
                          }
                          final item = displayItems[i];
                          final firstMsg = item.messages.first;
                          final isOwn = firstMsg.senderId == currentUid;

                          Widget content;
                          if (item.messages.length > 1) {
                            content = _ImageGroupBubble(images: item.messages, isOwn: isOwn);
                          } else if (firstMsg.mediaType == 'call_audio' || firstMsg.mediaType == 'call_video') {
                            content = _CallBubble(
                              message: firstMsg,
                              isOwn: isOwn,
                              onCallback: () => _startCall(firstMsg.mediaType == 'call_video' ? CallType.video : CallType.audio),
                            );
                          } else if (firstMsg.isViewOnce && (firstMsg.hasBeenViewed || _viewedOnceIds.contains(firstMsg.id))) {
                            content = _ViewOnceOpenedBubble(isOwn: isOwn, isSender: isOwn);
                          } else {
                            content = _buildSingleBubble(firstMsg, isOwn, messages);
                          }

                          // Chip rappel 🔔
                          final reminder = firstMsg.reminderAt;
                          if (reminder != null && reminder.isAfter(DateTime.now())) {
                            content = Column(
                              crossAxisAlignment: isOwn ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                              children: [
                                Container(
                                  margin: EdgeInsets.only(left: isOwn ? 40 : 8, right: isOwn ? 8 : 40, bottom: 2),
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(color: ThixPolicy.gold.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.notifications_active_rounded, size: 11, color: ThixPolicy.gold),
                                      const SizedBox(width: 4),
                                      Text(DateFormat('dd/MM HH:mm').format(reminder.toLocal()),
                                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: ThixPolicy.gold)),
                                    ],
                                  ),
                                ),
                                content,
                              ],
                            );
                          }

                          // Surbrillance recherche
                          if (_searchHighlightId.isNotEmpty && firstMsg.id == _searchHighlightId) {
                            content = Container(
                              decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), boxShadow: [
                                BoxShadow(color: ThixPolicy.gold.withOpacity(0.55), blurRadius: 10, spreadRadius: 1),
                              ]),
                              child: content,
                            );
                          }

                          // ✅ Swipe-to-reply natif pour MES messages (les autres : géré par la bubble)
                          if (isOwn) {
                            content = Dismissible(
                              key: ValueKey('swipe_reply_${firstMsg.id}'),
                              direction: DismissDirection.startToEnd,
                              confirmDismiss: (_) async {
                                HapticFeedback.selectionClick();
                                setState(() => _replyToId = firstMsg.id);
                                return false;
                              },
                              background: Container(
                                alignment: Alignment.centerLeft,
                                padding: const EdgeInsets.only(left: 24),
                                child: const Icon(Icons.reply_rounded, color: ThixPolicy.primary),
                              ),
                              child: content,
                            );
                          }

                          // ✅ Swipe gauche = menu extra (rappel, info, copier, transférer)
                          content = Dismissible(
                            key: ValueKey('swipe_extra_${firstMsg.id}'),
                            direction: DismissDirection.endToStart,
                            confirmDismiss: (_) async {
                              _showExtraSheet(firstMsg);
                              return false;
                            },
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 24),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.notifications_active_outlined, color: ThixPolicy.gold, size: 18),
                                  SizedBox(width: 6),
                                  Icon(Icons.info_outline_rounded, color: ThixPolicy.primary, size: 18),
                                ],
                              ),
                            ),
                            child: content,
                          );

                          final keyed = KeyedSubtree(key: _keyFor(firstMsg.id), child: content);

                          if (i == firstUnreadIdx) {
                            return Column(children: [_UnreadDivider(l10n: l10n), keyed]);
                          }
                          return keyed;
                        },
                      ),
                    ),
                    if (_otherUserTyping) Positioned(bottom: 10, left: 16, child: _TypingPill(l10n: l10n)),
                    if (_showJumpUnread && _firstUnreadId.isNotEmpty)
                      Positioned(
                        top: 8,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: Material(
                            color: ThixPolicy.primary,
                            borderRadius: BorderRadius.circular(20),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(20),
                              onTap: () {
                                setState(() => _showJumpUnread = false);
                                _scrollToMessage(_firstUnreadId);
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.arrow_downward_rounded, color: Colors.white, size: 14),
                                    const SizedBox(width: 6),
                                    Text(
                                      _tr(l10n, 'chat_jump_unread', 'Premiers messages non lus')
                                          .replaceAll('{n}', '$_initialUnread'),
                                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (_editingMessageId.isNotEmpty) _buildEditBanner(l10n),
              if (_replyToId.isNotEmpty)
                _ReplyBanner(
                  text: _ChatValidators.sanitize(
                    messages.where((m) => m.id == _replyToId).isEmpty
                        ? ''
                        : messages.firstWhere((m) => m.id == _replyToId).content,
                    maxLength: 100,
                  ),
                  onClose: () {
                    HapticFeedback.selectionClick();
                    setState(() => _replyToId = '');
                  },
                ),
              if (_mentionSuggestions.isNotEmpty) _buildMentionSuggestions(),
              if (_isConnectionValid) _buildInputBar(l10n) else _buildBlockedBanner(l10n),
              if (_showStickers) _buildStickerPicker(l10n),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // BUBBLE UNIQUE + CALLBACKS COMPLETS
  // ============================================================================
  Widget _buildSingleBubble(ChatMessage msg, bool isOwn, List<ChatMessage> messages) {
    final idx = messages.indexWhere((m) => m.id == msg.id);
    final prev = idx > 0 ? messages[idx - 1] : null;
    final next = idx < messages.length - 1 ? messages[idx + 1] : null;
    final firstInGroup = prev == null || prev.senderId != msg.senderId;
    final lastInGroup = next == null || next.senderId != msg.senderId;

    ChatMessage? replyTo;
    if (msg.replyToId != null) {
      final found = messages.where((m) => m.id == msg.replyToId).toList();
      replyTo = found.isEmpty ? null : found.first;
    }

    return ChatMessageBubble(
      message: msg,
      isOwn: isOwn,
      onReply: () {
        HapticFeedback.selectionClick();
        setState(() => _replyToId = msg.id);
      },
      onReaction: (r) {
        HapticFeedback.lightImpact();
        unawaited(_chatService.toggleReaction(msg.id, r));
      },
      onDelete: () => _deleteForMe(msg),
      onDeleteForAll: () => _deleteForAll(msg),
      onEdit: (newContent) => _applyEdit(msg, newContent),
      onForward: () => _showForwardSheet(msg),
      onPin: () => _togglePin(msg),
      onStar: () => _toggleStar(msg),
      onViewOnceOpened: () => _onViewOnceOpened(msg),
      replyToMessage: replyTo,
      isEphemeralActive: msg.isEphemeral && !msg.isExpired,
      isInternalNote: msg.isInternalNote,
      isAgentView: _isAgent,
      isFirstInGroup: firstInGroup,
      isLastInGroup: lastInGroup,
    );
  }

  /// Menu "swipe gauche" : rappels + infos + copier + transférer.
  void _showExtraSheet(ChatMessage msg) {
    final l10n = AppLocalizations.of(context);
    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      backgroundColor: ThixPolicy.card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: ThixPolicy.border, borderRadius: BorderRadius.circular(4))),
            ListTile(
              leading: const Icon(Icons.notifications_active_outlined, color: ThixPolicy.gold),
              title: Text(_tr(l10n, 'chat_remind', 'Me rappeler')),
              onTap: () {
                Navigator.pop(ctx);
                _showRemindSheet(msg);
              },
            ),
            ListTile(
              leading: const Icon(Icons.forward_rounded, color: ThixPolicy.textMain),
              title: Text(_tr(l10n, 'chat_forward', 'Transférer')),
              onTap: () {
                Navigator.pop(ctx);
                _showForwardSheet(msg);
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy_rounded, color: ThixPolicy.textMuted),
              title: Text(_tr(l10n, 'chat_copy', 'Copier')),
              onTap: () {
                Navigator.pop(ctx);
                Clipboard.setData(ClipboardData(text: _ChatValidators.sanitize(msg.content, maxLength: _kMaxMessageLength)));
                _showSuccess(_tr(l10n, 'chat_copied', 'Copié'));
              },
            ),
            ListTile(
              leading: const Icon(Icons.info_outline_rounded, color: ThixPolicy.primary),
              title: Text(_tr(l10n, 'chat_info', 'Informations du message')),
              onTap: () {
                Navigator.pop(ctx);
                _showMessageInfo(msg);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ============================================================================
  // BARRES UI
  // ============================================================================
  Widget _buildPinnedBar(AppLocalizations l10n) {
    final msg = _pinnedMessages[_pinnedCursor % _pinnedMessages.length];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: ThixPolicy.gold.withOpacity(0.10), border: Border(bottom: BorderSide(color: ThixPolicy.gold.withOpacity(0.3)))),
      child: Row(
        children: [
          const Icon(Icons.push_pin_rounded, size: 16, color: ThixPolicy.gold),
          const SizedBox(width: 8),
          Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() => _pinnedCursor = (_pinnedCursor + 1) % _pinnedMessages.length);
                _scrollToMessage(msg.id);
              },
              child: Text(
                '${msg.senderName}: ${msg.previewText}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.textMain, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          if (_pinnedMessages.length > 1)
            Text('${(_pinnedCursor % _pinnedMessages.length) + 1}/${_pinnedMessages.length}',
                style: ThixPolicy.microStyle.copyWith(color: ThixPolicy.textMuted)),
          IconButton(
  visualDensity: VisualDensity.compact,
  icon: const Icon(Icons.push_pin_outlined, size: 16, color: ThixPolicy.textSecondary),
  onPressed: () => _togglePin(msg),
  tooltip: _tr(l10n, 'chat_unpin', 'Désépingler'),
),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.close_rounded, size: 16, color: ThixPolicy.textSecondary),
            onPressed: () => setState(() => _pinnedBarClosed = true),
            tooltip: _tr(l10n, 'common_close', 'Fermer'),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(color: ThixPolicy.card, border: Border(bottom: BorderSide(color: ThixPolicy.border))),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded, size: 20, color: ThixPolicy.textMain),
            onPressed: () => setState(() {
              _searchActive = false;
              _searchCtrl.clear();
              _searchMatches = <String>[];
              _searchPos = -1;
            }),
          ),
          Expanded(
            child: TextField(
              controller: _searchCtrl,
              autofocus: true,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _searchRemote(),
              decoration: InputDecoration(
                isDense: true,
                hintText: _tr(l10n, 'chat_search_hint', 'Rechercher dans la conversation'),
                hintStyle: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.textSecondary),
                border: InputBorder.none,
              ),
              style: ThixPolicy.labelStyle.copyWith(color: ThixPolicy.textMain),
            ),
          ),
          if (_searchMatches.isNotEmpty)
            Text('${_searchPos + 1}/${_searchMatches.length}', style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.textSecondary)),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.keyboard_arrow_up_rounded, color: ThixPolicy.primary),
            onPressed: () => _searchMove(-1),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.keyboard_arrow_down_rounded, color: ThixPolicy.primary),
            onPressed: () => _searchMove(1),
          ),
        ],
      ),
    );
  }

  Widget _buildEditBanner(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(color: ThixPolicy.tint, border: Border(top: BorderSide(color: ThixPolicy.primary.withOpacity(0.3)))),
      child: Row(
        children: [
          const Icon(Icons.edit_rounded, size: 16, color: ThixPolicy.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _tr(l10n, 'chat_editing', 'Modification du message (fenêtre $_kEditWindowMinutes min)'),
              style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.primary, fontWeight: FontWeight.w700),
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.close_rounded, size: 18, color: ThixPolicy.textSecondary),
            onPressed: _cancelEdit,
          ),
        ],
      ),
    );
  }

  Widget _buildMentionSuggestions() {
    return Container(
      color: ThixPolicy.card,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: _mentionSuggestions
            .map((m) => ListTile(
                  dense: true,
                  leading: CircleAvatar(
                    radius: 14,
                    backgroundColor: ThixPolicy.tint,
                    backgroundImage: m.avatarUrl != null ? CachedNetworkImageProvider(m.avatarUrl!) : null,
                    child: m.avatarUrl == null ? const Icon(Icons.person, size: 14, color: ThixPolicy.textSecondary) : null,
                  ),
                  title: Text('@${m.displayName}', style: ThixPolicy.labelStyle.copyWith(fontWeight: ThixPolicy.bold, fontSize: 13)),
                  onTap: () => _insertMention(m),
                ))
            .toList(),
      ),
    );
  }

  Widget _buildBlockedBanner(AppLocalizations l10n) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(color: ThixPolicy.card, border: Border(top: BorderSide(color: ThixPolicy.border))),
      child: Column(
        children: [
          const Icon(Icons.person_off_rounded, color: ThixPolicy.textSecondary, size: 32),
          const SizedBox(height: 12),
          Text(_tr(l10n, 'chat_cannot_reply', 'Vous ne pouvez pas répondre'), style: ThixPolicy.labelStyle.copyWith(color: ThixPolicy.textMain, fontWeight: ThixPolicy.bold, fontSize: 14), textAlign: TextAlign.center),
          const SizedBox(height: 4),
          Text(_tr(l10n, 'chat_connection_interrupted', 'Connexion interrompue avec ce contact'), style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.textSecondary, fontSize: 13), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(AppLocalizations l10n) {
    final safeAvatar = _ChatValidators.sanitizeUrl(widget.conversation.displayAvatar);
    return AppBar(
      backgroundColor: ThixPolicy.card,
      elevation: 0,
      scrolledUnderElevation: 2,
      leading: Semantics(
        button: true,
        label: _tr(l10n, 'common_back', 'Retour'),
        child: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: ThixPolicy.textMain),
          onPressed: () {
            HapticFeedback.selectionClick();
            _markAsRead();
            context.pop();
          },
        ),
      ),
      titleSpacing: 0,
      title: Row(
        children: [
          Stack(
            children: [
              Container(
                decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: ThixPolicy.border, width: 1.5), boxShadow: ThixPolicy.shadowSoft(opacity: 0.05)),
                child: CircleAvatar(
                  radius: 20,
                  backgroundColor: ThixPolicy.tint,
                  backgroundImage: safeAvatar != null ? CachedNetworkImageProvider(safeAvatar) : null,
                  child: widget.conversation.isGroup
                      ? const Icon(Icons.groups_rounded, color: ThixPolicy.textSecondary)
                      : safeAvatar == null
                          ? const Icon(Icons.person, color: ThixPolicy.textSecondary)
                          : null,
                ),
              ),
              if (!widget.conversation.isGroup && _isOnline)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(width: 12, height: 12, decoration: BoxDecoration(color: ThixPolicy.success, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2))),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Consumer(
                  builder: (context, ref, _) {
                    CertificationTier? tier;
                    CertificationStatus? status;
                    bool isCertified = false;
                    bool isLegacyVerified = false;
                    if (!widget.conversation.isGroup) {
                      final myId = _chatService.currentUserId;
                      final otherId = widget.conversation.participantIds.firstWhere((id) => id != myId, orElse: () => '');
                      if (otherId.isNotEmpty) {
                        final profileData = ref.watch(userProfileProvider(otherId)).valueOrNull;
                        if (profileData != null) {
                          tier = CertificationTierX.parse(profileData['certification_tier']);
                          status = CertificationStatusX.parse(profileData['certification_status']);
                          isCertified = status == CertificationStatus.approved || status == CertificationStatus.generated;
                          isLegacyVerified = profileData['is_verified'] == true;
                        }
                      }
                    }
                    final safeName = _ChatValidators.sanitize(widget.conversation.displayName, maxLength: 80);
                    return Row(
                      children: [
                        Flexible(
                          child: Text(
                            safeName.isEmpty ? _tr(l10n, 'chat_unknown_user', 'Utilisateur') : safeName,
                            style: ThixPolicy.labelStyle.copyWith(fontSize: 16, fontWeight: ThixPolicy.bold, color: ThixPolicy.textMain),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isCertified)
                          CertificationNameBadge(tier: tier, status: status, showLabel: false, iconSize: 15, padding: const EdgeInsets.only(left: 4))
                        else if (isLegacyVerified)
                          const Padding(padding: EdgeInsets.only(left: 4), child: Icon(Icons.verified_rounded, color: ThixPolicy.gold, size: 15)),
                      ],
                    );
                  },
                ),
                if (!widget.conversation.isGroup && _otherParticipant != null)
                  Text(
                    _getPresenceText(_otherParticipant!),
                    style: ThixPolicy.captionStyle.copyWith(fontSize: 12, color: _isOnline ? ThixPolicy.success : ThixPolicy.textSecondary, fontWeight: _isOnline ? FontWeight.w600 : FontWeight.w400),
                  )
                else if (widget.conversation.isGroup)
                  Text('${_groupMembers.length} ${_tr(l10n, 'chat_members', 'membres')}', style: ThixPolicy.captionStyle.copyWith(fontSize: 12, color: ThixPolicy.textSecondary)),
              ],
            ),
          ),
        ],
      ),
      actions: [
        Semantics(
          button: true,
          label: _tr(l10n, 'chat_search', 'Rechercher'),
          child: IconButton(
            icon: Icon(_searchActive ? Icons.search_off_rounded : Icons.search_rounded, color: ThixPolicy.primary, size: 22),
            onPressed: () => setState(() => _searchActive = !_searchActive),
          ),
        ),
        Semantics(
          button: true,
          label: _tr(l10n, 'chat_video_call', 'Appel vidéo'),
          child: IconButton(icon: const Icon(Icons.videocam_outlined, color: ThixPolicy.primary, size: 26), onPressed: () => _startCall(CallType.video)),
        ),
        Semantics(
          button: true,
          label: _tr(l10n, 'chat_audio_call', 'Appel audio'),
          child: IconButton(icon: const Icon(Icons.call_outlined, color: ThixPolicy.primary, size: 24), onPressed: () => _startCall(CallType.audio)),
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert_rounded, color: ThixPolicy.textMain),
          color: ThixPolicy.card,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          onSelected: (v) {
            HapticFeedback.selectionClick();
            if (v == 'escalate') {
              _escalateConversation();
            } else if (v == 'history') {
              _viewEscalationHistory();
            } else if (v == 'group') {
              GoRouter.of(context).go('/chat/group/${widget.conversationId}/info');
            } else if (v == 'starred') {
              _showStarredSheet();
            } else if (v == 'export') {
              _exportConversation();
            }
          },
          itemBuilder: (_) => [
            PopupMenuItem(value: 'starred', child: Row(children: [const Icon(Icons.star_outline_rounded, color: ThixPolicy.gold, size: 20), const SizedBox(width: 10), Text(_tr(l10n, 'chat_starred', 'Favoris'))])),
            PopupMenuItem(value: 'escalate', child: Row(children: [const Icon(Icons.arrow_upward, color: ThixPolicy.warning, size: 20), const SizedBox(width: 10), Text(_tr(l10n, 'chat_escalate', 'Escalader'))])),
            PopupMenuItem(value: 'history', child: Row(children: [const Icon(Icons.history, color: ThixPolicy.primary, size: 20), const SizedBox(width: 10), Text(_tr(l10n, 'chat_history', 'Historique'))])),
            if (_isAgent)
              PopupMenuItem(value: 'export', child: Row(children: [const Icon(Icons.download_rounded, color: ThixPolicy.textSecondary, size: 20), const SizedBox(width: 10), Text(_tr(l10n, 'chat_export', 'Exporter (CSV)'))])),
            if (widget.conversation.isGroup)
              PopupMenuItem(value: 'group', child: Row(children: [const Icon(Icons.info_outline, color: ThixPolicy.textSecondary, size: 20), const SizedBox(width: 10), Text(_tr(l10n, 'chat_group_info', 'Infos du groupe'))])),
          ],
        ),
      ],
    );
  }

  // ============================================================================
  // BARRE DE SAISIE
  // ============================================================================
  Widget _buildInputBar(AppLocalizations l10n) {
    final hasTextOrImage = _inputController.text.trim().isNotEmpty || _selectedFiles.isNotEmpty;
    final hasViewOnceCandidate = _selectedFiles.any((f) => ['jpg', 'jpeg', 'png', 'gif', 'webp'].contains((f.extension ?? '').toLowerCase()));

    return Container(
      decoration: BoxDecoration(color: ThixPolicy.card, border: Border(top: BorderSide(color: ThixPolicy.border, width: 1.2)), boxShadow: ThixPolicy.shadowSoft(opacity: 0.03)),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: ThixPolicy.border.withOpacity(0.5)))),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    _optionButton(l10n, Icons.attach_file_rounded, _tr(l10n, 'chat_file', 'Fichier'), _pickFile),
                    _optionButton(l10n, Icons.sentiment_satisfied_alt_rounded, _tr(l10n, 'chat_sticker', 'Stickers'), () {
                      FocusScope.of(context).unfocus();
                      setState(() => _showStickers = !_showStickers);
                    }, isActive: _showStickers),
                    _optionButton(l10n, Icons.timer_outlined, _tr(l10n, 'chat_ephemeral', 'Éphémère'), _showEphemeralTimerDialog, isActive: _isEphemeral),
                    _optionButton(l10n, Icons.lock_outline_rounded, _tr(l10n, 'chat_protected', 'Protégé'), _showPasswordProtectDialog),
                    if (_isAgent)
                      _optionButton(l10n, Icons.note_alt_outlined, _tr(l10n, 'chat_internal_note', 'Note interne'), _toggleInternalNoteMode, isActive: _isInternalNoteMode),
                  ],
                ),
              ),
            ),
            if (_selectedFiles.isNotEmpty) _FilesPreview(files: _selectedFiles, onRemove: _removeFile),
            if (hasViewOnceCandidate)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _sendViewOnce = !_sendViewOnce);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: _sendViewOnce ? ThixPolicy.primary : Colors.transparent,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: _sendViewOnce ? ThixPolicy.primary : ThixPolicy.border),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.visibility_off_rounded, size: 14, color: _sendViewOnce ? Colors.white : ThixPolicy.textSecondary),
                            const SizedBox(width: 6),
                            Text(
                              _tr(l10n, 'chat_view_once', 'View once'),
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _sendViewOnce ? Colors.white : ThixPolicy.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(_tr(l10n, 'chat_view_once_hint', 'Le média s’efface après ouverture'),
                          style: ThixPolicy.microStyle.copyWith(color: ThixPolicy.textMuted)),
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: _localAudioPath != null && !_isRecording
                  ? Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(color: ThixPolicy.inkDeep, borderRadius: BorderRadius.circular(24)),
                      child: Row(
                        children: [
                          Expanded(child: _ChatWaveformAudioPlayer(audioUrl: _localAudioPath!, isLocal: true)),
                          IconButton(icon: const Icon(Icons.delete_outline_rounded, color: Colors.white70), onPressed: () => setState(() { _audioBytes = null; _localAudioPath = null; })),
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: ThixPolicy.primary,
                            child: IconButton(
                              icon: _isSending
                                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                  : const Icon(Icons.send_rounded, color: Colors.white, size: 14),
                              onPressed: _isSending ? null : () => _sendMessage(),
                            ),
                          ),
                        ],
                      ),
                    )
                  : _isRecording
                      ? Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(color: ThixPolicy.danger.withOpacity(0.1), borderRadius: BorderRadius.circular(24), border: Border.all(color: ThixPolicy.danger.withOpacity(0.2))),
                          child: Row(
                            children: [
                              const Icon(Icons.mic, color: ThixPolicy.danger),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  '${_tr(l10n, 'chat_recording', 'Enregistrement')} ${(_recordDuration ~/ 60).toString().padLeft(2, '0')}:${(_recordDuration % 60).toString().padLeft(2, '0')}',
                                  style: ThixPolicy.labelStyle.copyWith(color: ThixPolicy.danger, fontWeight: ThixPolicy.bold),
                                ),
                              ),
                              GestureDetector(onTap: _stopRecording, child: const Icon(Icons.stop_circle_rounded, color: ThixPolicy.danger, size: 30)),
                            ],
                          ),
                        )
                      : Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(color: ThixPolicy.surfaceSoft, borderRadius: BorderRadius.circular(24), border: Border.all(color: ThixPolicy.border)),
                                child: TextField(
                                  controller: _inputController,
                                  focusNode: _inputFocus,
                                  maxLines: 5,
                                  minLines: 1,
                                  maxLength: _kMaxMessageLength,
                                  textCapitalization: TextCapitalization.sentences,
                                  onTap: () {
                                    if (_showStickers) setState(() => _showStickers = false);
                                  },
                                  decoration: InputDecoration(
                                    counterText: '',
                                    hintText: _tr(l10n, 'chat_write_message', 'Écrire un message… (@ pour mentionner)'),
                                    hintStyle: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.textSecondary),
                                    border: InputBorder.none,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            GestureDetector(
                              onTap: () {
                                if (_isSending) return;
                                HapticFeedback.mediumImpact();
                                if (hasTextOrImage) {
                                  _sendMessage();
                                } else {
                                  _startRecording();
                                }
                              },
                              child: CircleAvatar(
                                radius: 22,
                                backgroundColor: hasTextOrImage ? ThixPolicy.primary : ThixPolicy.gold,
                                child: _isSending
                                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                    : Icon(hasTextOrImage ? Icons.send_rounded : Icons.mic_rounded, color: hasTextOrImage ? Colors.white : ThixPolicy.inkDeep, size: 22),
                              ),
                            ),
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _optionButton(AppLocalizations l10n, IconData icon, String label, VoidCallback onTap, {bool isActive = false}) {
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isActive ? ThixPolicy.primary.withOpacity(0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: isActive ? ThixPolicy.primary.withOpacity(0.2) : Colors.transparent),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: isActive ? ThixPolicy.primary : ThixPolicy.textSecondary),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(fontSize: 13, fontWeight: isActive ? FontWeight.w700 : FontWeight.w600, color: isActive ? ThixPolicy.primary : ThixPolicy.textSecondary)),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================================
  // DIALOGUES ÉPHÉMÈRE + MOT DE PASSE ROBUSTE
  // ============================================================================
  void _showEphemeralTimerDialog() {
    final l10n = AppLocalizations.of(context);
    bool showCustomInput = false;
    final customTimeCtrl = TextEditingController();
    HapticFeedback.selectionClick();
    final List<Map<String, dynamic>> durationOptions = [
      {'label': _tr(l10n, 'chat_disabled', 'Désactivé'), 'value': null},
      {'label': _tr(l10n, 'chat_seconds_10', '10 secondes'), 'value': 10},
      {'label': _tr(l10n, 'chat_minute_1', '1 minute'), 'value': 60},
      {'label': _tr(l10n, 'chat_hour_1', '1 heure'), 'value': 3600},
      {'label': _tr(l10n, 'chat_hours_24', '24 heures'), 'value': 86400},
    ];
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            decoration: BoxDecoration(color: ThixPolicy.card, borderRadius: const BorderRadius.vertical(top: Radius.circular(22)), border: Border(top: BorderSide(color: ThixPolicy.border))),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 40, height: 4, decoration: BoxDecoration(color: ThixPolicy.border, borderRadius: BorderRadius.circular(4))),
                const SizedBox(height: 16),
                Text(_tr(l10n, 'chat_ephemeral_message', 'Message éphémère'), style: ThixPolicy.titleStyle.copyWith(fontWeight: ThixPolicy.bold, fontSize: 16)),
                const SizedBox(height: 12),
                if (!showCustomInput) ...[
                  ...durationOptions.map((e) {
                    final String label = e['label'] as String;
                    final int? value = e['value'] as int?;
                    final selected = _ephemeralDuration == value;
                    return ListTile(
                      title: Text(label),
                      trailing: selected ? const Icon(Icons.check_circle, color: ThixPolicy.primary) : null,
                      onTap: () {
                        setState(() {
                          _ephemeralDuration = value;
                          _isEphemeral = value != null;
                        });
                        Navigator.pop(ctx);
                      },
                    );
                  }),
                  ListTile(
                    title: Text(_tr(l10n, 'chat_custom_time', 'Durée personnalisée'), style: TextStyle(color: ThixPolicy.primary, fontWeight: FontWeight.w600)),
                    leading: const Icon(Icons.timer_outlined, color: ThixPolicy.primary),
                    onTap: () => setModalState(() => showCustomInput = true),
                  ),
                ] else ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: customTimeCtrl,
                            keyboardType: TextInputType.number,
                            autofocus: true,
                            decoration: InputDecoration(labelText: _tr(l10n, 'chat_duration_seconds', 'Durée (secondes)'), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), contentPadding: const EdgeInsets.symmetric(horizontal: 16)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: ThixPolicy.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16)),
                          onPressed: () {
                            final val = int.tryParse(customTimeCtrl.text.trim());
                            if (val != null && val > 0) {
                              setState(() {
                                _ephemeralDuration = val;
                                _isEphemeral = true;
                              });
                              Navigator.pop(ctx);
                            } else {
                              _showWarning(_tr(l10n, 'chat_invalid_number', 'Nombre invalide'));
                            }
                          },
                          child: Text(_tr(l10n, 'chat_validate', 'Valider'), style: const TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  ),
                  TextButton(onPressed: () => setModalState(() => showCustomInput = false), child: Text(_tr(l10n, 'common_back', 'Retour'))),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showPasswordProtectDialog() {
    final l10n = AppLocalizations.of(context);
    final msgCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    HapticFeedback.selectionClick();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) {
          final score = _ChatValidators.passwordScore(passCtrl.text);
          final colors = <Color>[ThixPolicy.danger, ThixPolicy.danger, ThixPolicy.warning, ThixPolicy.success, ThixPolicy.success, ThixPolicy.success];
          return AlertDialog(
            backgroundColor: ThixPolicy.card,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: ThixPolicy.border)),
            title: Text(_tr(l10n, 'chat_secure_message', 'Message protégé par mot de passe'), style: ThixPolicy.h3Style.copyWith(fontWeight: ThixPolicy.bold, fontSize: 16)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: msgCtrl, decoration: InputDecoration(labelText: _tr(l10n, 'chat_message', 'Message')), maxLines: 3),
                const SizedBox(height: 12),
                TextField(controller: passCtrl, decoration: InputDecoration(labelText: _tr(l10n, 'chat_password', 'Mot de passe')), obscureText: true, onChanged: (_) => setDlgState(() {})),
                const SizedBox(height: 6),
                Row(
                  children: List.generate(5, (i) => Expanded(
                        child: Container(
                          height: 4,
                          margin: const EdgeInsets.only(right: 3),
                          decoration: BoxDecoration(color: i < score ? colors[score] : ThixPolicy.border, borderRadius: BorderRadius.circular(2)),
                        ),
                      )),
                ),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    score >= 4 ? _tr(l10n, 'chat_pwd_strong', 'Robuste') : (score >= 3 ? _tr(l10n, 'chat_pwd_ok', 'Correct') : _tr(l10n, 'chat_pwd_weak', 'Trop faible (8+ car., maj., min., chiffre, symbole)')),
                    style: TextStyle(fontSize: 11, color: score >= 3 ? ThixPolicy.success : ThixPolicy.danger, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(controller: confirmCtrl, decoration: InputDecoration(labelText: _tr(l10n, 'chat_password_confirm', 'Confirmer le mot de passe')), obscureText: true),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: Text(_tr(l10n, 'common_cancel', 'Annuler'))),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: ThixPolicy.primary),
                onPressed: () async {
                  if (msgCtrl.text.isEmpty || passCtrl.text.isEmpty) return;
                  if (_ChatValidators.passwordScore(passCtrl.text) < 3) {
                    _showWarning(_tr(l10n, 'chat_pwd_weak', 'Mot de passe trop faible'));
                    return;
                  }
                  if (passCtrl.text != confirmCtrl.text) {
                    _showWarning(_tr(l10n, 'chat_pwd_mismatch', 'Les mots de passe ne correspondent pas'));
                    return;
                  }
                  final sanitizedMsg = _ChatValidators.sanitize(msgCtrl.text, maxLength: _kMaxMessageLength);
                  final enc = EncryptionService.encryptMessage(sanitizedMsg, passCtrl.text);
                  Navigator.pop(ctx);
                  try {
                    final msg = await _chatRetry(
                      () => _chatService.sendMessage(
                        conversationId: widget.conversationId,
                        content: enc,
                        replyToId: _replyToId.isEmpty ? null : _replyToId,
                        isEphemeral: _isEphemeral,
                        ephemeralDuration: _ephemeralDuration,
                      ),
                      label: 'sendEncrypted',
                    );
                    ref.read(chatMessagesProvider(widget.conversationId).notifier).upsertRealtime([msg]);
                    if (mounted) setState(() => _replyToId = '');
                    _scrollToBottom();
                  } catch (e) {
                    if (mounted) _showError(_ChatValidators.friendlyError(e));
                  }
                },
                child: Text(_tr(l10n, 'chat_send', 'Envoyer'), style: const TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      ),
    );
  }

  // ============================================================================
  // STICKERS (5 catégories)
  // ============================================================================
  Widget _buildStickerPicker(AppLocalizations l10n) {
    return SizedBox(
      height: 260,
      child: DefaultTabController(
        length: 4,
        child: Column(
          children: [
            TabBar(
              labelColor: ThixPolicy.primary,
              indicatorColor: ThixPolicy.primary,
              isScrollable: true,
              tabs: [
                Tab(text: _tr(l10n, 'chat_emojis', 'Emojis')),
                Tab(text: _tr(l10n, 'chat_reactions', 'Réactions')),
                Tab(text: _tr(l10n, 'chat_objects', 'Objets')),
                Tab(text: _tr(l10n, 'chat_flags', 'Drapeaux')),
              ],
            ),
            Expanded(
              child: TabBarView(children: [
                _buildStickerGrid(_emojis),
                _buildStickerGrid(_reactions),
                _buildStickerGrid(_objects),
                _buildStickerGrid(_flags),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStickerGrid(List<String> items) {
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 8, mainAxisSpacing: 8, crossAxisSpacing: 8),
      itemCount: items.length,
      itemBuilder: (context, index) => Semantics(
        button: true,
        label: 'Emoji ${items[index]}',
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            _inputController.text += items[index];
            _inputController.selection = TextSelection.fromPosition(TextPosition(offset: _inputController.text.length));
          },
          child: Center(child: Text(items[index], style: const TextStyle(fontSize: 24))),
        ),
      ),
    );
  }
}

// ============================================================================
// WIDGETS ANNEXES
// ============================================================================
class _UnreadDivider extends StatelessWidget {
  final AppLocalizations l10n;
  const _UnreadDivider({required this.l10n});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(child: Container(height: 1, color: ThixPolicy.primary.withOpacity(0.35))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(_tr(l10n, 'chat_new_messages', 'Nouveaux messages'),
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: ThixPolicy.primary)),
          ),
          Expanded(child: Container(height: 1, color: ThixPolicy.primary.withOpacity(0.35))),
        ],
      ),
    );
  }
}

class _ViewOnceOpenedBubble extends StatelessWidget {
  final bool isOwn;
  final bool isSender;
  const _ViewOnceOpenedBubble({required this.isOwn, required this.isSender});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Align(
        alignment: isOwn ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: EdgeInsets.only(left: isOwn ? 40 : 4, right: isOwn ? 4 : 40),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(color: ThixPolicy.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: ThixPolicy.border.withOpacity(0.6))),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.visibility_off_rounded, size: 14, color: ThixPolicy.textMuted),
              const SizedBox(width: 6),
              Text(
                isSender ? _tr(l10n, 'chat_viewonce_opened_sender', 'Média ouvert par le destinataire') : _tr(l10n, 'chat_viewonce_opened', 'Média à usage unique ouvert'),
                style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.textMuted, fontStyle: FontStyle.italic),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ImageGroupBubble extends StatelessWidget {
  final List<ChatMessage> images;
  final bool isOwn;
  const _ImageGroupBubble({required this.images, required this.isOwn});

  @override
  Widget build(BuildContext context) {
    final shown = images.take(4).toList();
    final extra = images.length - shown.length;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Align(
        alignment: isOwn ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: EdgeInsets.only(left: isOwn ? 40 : 4, right: isOwn ? 4 : 40),
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(color: isOwn ? ThixPolicy.primary : ThixPolicy.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: ThixPolicy.border.withOpacity(0.6)), boxShadow: ThixPolicy.shadowSoft(opacity: 0.04)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(11),
                  child: GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: shown.length,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 3, crossAxisSpacing: 3, childAspectRatio: 1),
                    itemBuilder: (context, idx) {
                      final msg = shown[idx];
                      final showMore = extra > 0 && idx == shown.length - 1;
                      final tag = 'img_group_${msg.id}';
                      final safeUrl = _ChatValidators.sanitizeUrl(msg.mediaUrl);
                      return GestureDetector(
                        onTap: safeUrl != null
                            ? () => showFullscreenImageViewer(context, url: safeUrl, heroTag: tag, fileName: msg.mediaName ?? 'thix_${msg.id}.jpg')
                            : null,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Hero(
                              tag: tag,
                              child: safeUrl != null
                                  ? CachedNetworkImage(
                                      imageUrl: safeUrl,
                                      fit: BoxFit.cover,
                                      placeholder: (_, __) => Container(color: ThixPolicy.tint, child: const Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: ThixPolicy.primary)))),
                                      errorWidget: (_, __, ___) => const Center(child: Icon(Icons.broken_image_outlined, color: ThixPolicy.textSecondary)),
                                    )
                                  : const Center(child: Icon(Icons.broken_image_outlined, color: ThixPolicy.textSecondary)),
                            ),
                            if (showMore)
                              Container(color: Colors.black.withOpacity(0.55), alignment: Alignment.center, child: Text('+ $extra', style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800))),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 2, right: 6, bottom: 1),
                child: Text(DateFormat('HH:mm').format(images.first.createdAt.toLocal()), style: TextStyle(fontSize: 10, color: isOwn ? Colors.white70 : ThixPolicy.textSecondary)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CallBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isOwn;
  final VoidCallback onCallback;
  const _CallBubble({required this.message, required this.isOwn, required this.onCallback});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isVideo = message.mediaType == 'call_video';
    final lower = message.content.toLowerCase();
    final isMissed = lower.contains('manqué') || lower.contains('missed') || lower.contains('sans réponse');
    final Color dirColor = isMissed ? ThixPolicy.danger : (isOwn ? ThixPolicy.success : ThixPolicy.primary);
    final IconData dirIcon = isMissed ? Icons.call_missed_rounded : (isOwn ? Icons.call_made_rounded : Icons.call_received_rounded);
    final String dirLabel = isMissed
        ? _tr(l10n, 'chat_call_missed', 'Appel manqué')
        : (isOwn ? _tr(l10n, 'chat_call_outgoing', 'Appel sortant') : _tr(l10n, 'chat_call_incoming', 'Appel entrant'));

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Align(
        alignment: isOwn ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: EdgeInsets.only(left: isOwn ? 50 : 0, right: isOwn ? 0 : 50),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: ThixPolicy.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: isMissed ? ThixPolicy.danger.withOpacity(0.3) : ThixPolicy.border), boxShadow: ThixPolicy.shadowSoft(opacity: 0.03)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: isMissed ? ThixPolicy.danger.withOpacity(0.1) : ThixPolicy.tint.withOpacity(0.6), shape: BoxShape.circle),
                child: Icon(isVideo ? Icons.videocam_rounded : Icons.call_rounded, color: dirColor, size: 18),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(dirIcon, size: 14, color: dirColor),
                      const SizedBox(width: 4),
                      Text(dirLabel, style: ThixPolicy.labelStyle.copyWith(fontWeight: ThixPolicy.bold, fontSize: 14, color: isMissed ? ThixPolicy.danger : ThixPolicy.textMain)),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(DateFormat('HH:mm').format(message.createdAt.toLocal()), style: ThixPolicy.captionStyle.copyWith(fontSize: 11, color: ThixPolicy.textSecondary, fontWeight: FontWeight.w500)),
                ],
              ),
              const SizedBox(width: 16),
              Semantics(
                button: true,
                label: _tr(l10n, 'chat_callback', 'Rappeler'),
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    onCallback();
                  },
                  child: Container(padding: const EdgeInsets.all(8), decoration: const BoxDecoration(color: ThixPolicy.surfaceSoft, shape: BoxShape.circle), child: const Icon(Icons.refresh_rounded, size: 20, color: ThixPolicy.primary)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TypingPill extends StatelessWidget {
  final AppLocalizations l10n;
  const _TypingPill({required this.l10n});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(color: ThixPolicy.card, borderRadius: BorderRadius.circular(20), border: Border.all(color: ThixPolicy.border), boxShadow: ThixPolicy.shadowSoft(opacity: 0.03)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _Dot(),
          const SizedBox(width: 3),
          const _Dot(delay: 120),
          const SizedBox(width: 3),
          const _Dot(delay: 240),
          const SizedBox(width: 8),
          Text(_tr(l10n, 'chat_typing', 'écrit…'), style: ThixPolicy.captionStyle.copyWith(fontSize: 12, color: ThixPolicy.primary, fontStyle: FontStyle.italic, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class _Dot extends StatefulWidget {
  final int delay;
  const _Dot({this.delay = 0});

  @override
  State<_Dot> createState() => _DotState();
}

class _DotState extends State<_Dot> with SingleTickerProviderStateMixin {
  late AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 600))..repeat(reverse: true);
    if (widget.delay > 0) {
      Future.delayed(Duration(milliseconds: widget.delay), () {
        if (mounted) _c.forward();
      });
    } else {
      _c.forward();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: _c,
        child: Container(width: 5, height: 5, decoration: const BoxDecoration(color: ThixPolicy.primary, shape: BoxShape.circle)),
      );
}

class _ReplyBanner extends StatelessWidget {
  final String text;
  final VoidCallback onClose;
  const _ReplyBanner({required this.text, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(color: ThixPolicy.card, border: Border(top: BorderSide(color: ThixPolicy.border))),
      child: Row(
        children: [
          Container(width: 4, height: 36, decoration: BoxDecoration(color: ThixPolicy.primary, borderRadius: BorderRadius.circular(4))),
          const SizedBox(width: 12),
          Expanded(child: Text(text.isEmpty ? '—' : text, maxLines: 1, overflow: TextOverflow.ellipsis, style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.textSecondary, fontSize: 13))),
          IconButton(icon: const Icon(Icons.close_rounded, size: 20, color: ThixPolicy.textSecondary), onPressed: onClose, tooltip: _tr(l10n, 'common_close', 'Fermer')),
        ],
      ),
    );
  }
}

class _FilesPreview extends StatelessWidget {
  final List<PlatformFile> files;
  final void Function(int) onRemove;
  const _FilesPreview({required this.files, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      height: 70,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: files.length,
        itemBuilder: (ctx, i) {
          final f = files[i];
          final isImg = ['jpg', 'jpeg', 'png', 'webp'].contains(f.extension?.toLowerCase() ?? '');
          final safeName = _ChatValidators.sanitize(f.name, maxLength: 50);
          return Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 60,
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(color: ThixPolicy.surfaceSoft, borderRadius: BorderRadius.circular(10), border: Border.all(color: ThixPolicy.border)),
                clipBehavior: Clip.hardEdge,
                child: isImg && f.bytes != null
                    ? Image.memory(f.bytes!, fit: BoxFit.cover)
                    : const Center(child: Icon(Icons.insert_drive_file_rounded, color: ThixPolicy.primary, size: 24)),
              ),
              Positioned(
                top: -4,
                right: 4,
                child: GestureDetector(
                  onTap: () => onRemove(i),
                  child: const CircleAvatar(radius: 10, backgroundColor: Colors.black87, child: Icon(Icons.close, size: 12, color: Colors.white)),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ChatWaveformAudioPlayer extends StatefulWidget {
  final String audioUrl;
  final bool isLocal;
  const _ChatWaveformAudioPlayer({required this.audioUrl, this.isLocal = false});

  @override
  State<_ChatWaveformAudioPlayer> createState() => _ChatWaveformAudioPlayerState();
}

class _ChatWaveformAudioPlayerState extends State<_ChatWaveformAudioPlayer> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  final List<double> _wavePattern = [0.4, 0.7, 0.5, 0.9, 0.6, 0.4, 0.8, 1.0, 0.5, 0.3, 0.7, 0.8, 0.4, 0.6];

  @override
  void initState() {
    super.initState();
    if (widget.isLocal && !kIsWeb) {
      _audioPlayer.setSourceDeviceFile(widget.audioUrl);
    } else {
      _audioPlayer.setSourceUrl(widget.audioUrl);
    }
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) setState(() => _isPlaying = state == PlayerState.playing);
    });
    _audioPlayer.onDurationChanged.listen((d) {
      if (mounted) setState(() => _duration = d);
    });
    _audioPlayer.onPositionChanged.listen((p) {
      if (mounted) setState(() => _position = p);
    });
  }

  @override
  void dispose() {
    _audioPlayer.stop();
    _audioPlayer.dispose();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final progress = _duration.inMilliseconds > 0 ? _position.inMilliseconds / _duration.inMilliseconds : 0.0;
    return Row(
      children: [
        GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            if (_isPlaying) {
              _audioPlayer.pause();
            } else {
              _audioPlayer.resume();
            }
          },
          child: Container(width: 32, height: 32, decoration: const BoxDecoration(color: ThixPolicy.gold, shape: BoxShape.circle), child: Icon(_isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, color: ThixPolicy.inkDeep, size: 20)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              const barWidth = 3.0;
              const spacing = 2.0;
              final barCount = (constraints.maxWidth / (barWidth + spacing)).floor();
              return GestureDetector(
                onTapDown: (details) {
                  if (_duration.inMilliseconds > 0) {
                    _audioPlayer.seek(Duration(milliseconds: (_duration.inMilliseconds * (details.localPosition.dx / constraints.maxWidth).clamp(0.0, 1.0)).round()));
                  }
                },
                child: Container(
                  height: 24,
                  color: Colors.transparent,
                  child: Row(
                    children: List.generate(barCount, (index) {
                      final isPlayed = (index / barCount) <= progress;
                      return Container(
                        width: barWidth,
                        height: 24 * _wavePattern[index % _wavePattern.length],
                        margin: const EdgeInsets.only(right: spacing),
                        decoration: BoxDecoration(color: isPlayed ? ThixPolicy.gold : Colors.white30, borderRadius: BorderRadius.circular(2)),
                      );
                    }),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(width: 10),
        Text(_formatDuration(_duration.inSeconds > 0 && !_isPlaying && _position.inSeconds == 0 ? _duration : _position), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white)),
      ],
    );
  }
}

class _ThixChatBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final textStyle = TextStyle(color: const Color(0xFFD3C7B5).withOpacity(0.10), fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 2.0);
    final textPainter = TextPainter(text: TextSpan(text: 'THIX CHAT', style: textStyle), textDirection: ui.TextDirection.ltr);
    textPainter.layout();
    const double stepX = 180.0;
    const double stepY = 140.0;
    for (double y = -stepY; y < size.height + stepY; y += stepY) {
      for (double x = -stepX; x < size.width + stepX; x += stepX) {
        canvas.save();
        final offsetX = x + ((y / stepY).floor() % 2 == 0 ? 0 : stepX / 2);
        canvas.translate(offsetX, y);
        canvas.rotate(-math.pi / 6);
        textPainter.paint(canvas, Offset(-textPainter.width / 2, -textPainter.height / 2));
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ============================================================================
// HELPER WEB (remplace http.get direct pour l'audio web via service si dispo)
// ============================================================================
Future<Uint8List> http_get(Uri uri) async {
  final resp = await _chatRetry(() => _httpGet(uri), label: 'httpGetAudio');
  return resp;
}

Future<Uint8List> _httpGet(Uri uri) async {
  final client = HttpClient();
  try {
    final req = await client.getUrl(uri);
    final resp = await req.close();
    final bytes = <int>[];
    await resp.forEach((chunk) => bytes.addAll(chunk));
    return Uint8List.fromList(bytes);
  } finally {
    client.close();
  }
}
