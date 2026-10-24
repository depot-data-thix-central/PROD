// lib/presentation/chat/chat_screen.dart
// ============================================================================
// THIX CHAT — ÉCRAN DE CONVERSATION (PRODUCTION ENTREPRISE) — v3.0
// ----------------------------------------------------------------------------
//  ✅ Fichier principal allégé : widgets dans /chat/widgets
//     - chat_input_bar.dart      (saisie, audio, fichiers, stickers)
//     - chat_message_bubble.dart (bulles, séparateurs, lecteur audio…)
//     - chat_common.dart         (validateurs, couleurs, snackbars, cache)
//  ✅ v3.0 : alerte capture d'écran, désactivation des appels (2 côtés),
//     sélection multiple + suppression, envoi optimiste façon WhatsApp,
//     fonds d'écran (8 + photo), nom/avatar, bulles grises/blanches,
//     séparateurs de date, bouton « descendre » + compteur, liens cliquables,
//     gros emojis, vitesse audio, réactions rapides, performances (cache,
//     index O(1), saisie sans rebuild global).
// ============================================================================
import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:screenshot_callback/screenshot_callback.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
import 'package:thix_id/presentation/chat/widgets/chat_common.dart';
import 'package:thix_id/presentation/chat/widgets/chat_input_bar.dart';
import 'package:thix_id/presentation/chat/widgets/chat_message_bubble.dart';
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
const int _kTypingDebounceMs = 2000;
const int _kMarkReadDebounceMs = 1000;
const int _kPresenceCheckThrottleSeconds = 30;
const int _kMaxForward = 5;
const int _kSearchDebounceMs = 350;
const int _kEditWindowMinutes = 15;
const int _kDeleteForAllWindowMinutes = 60;
const int _kSendThrottleMs = 250;
const int _kExpirySweepSeconds = 1;
const int _kDraftSaveDebounceMs = 500;
const int _kScreenshotThrottleSeconds = 8;
const double _kSwipeTrigger = 60;
const double _kSwipeMax = 84;
const String _kDraftPrefix = 'thix_chat_draft_v1_';
const String _kWallpaperPrefix = 'thix_chat_wallpaper_v1_';
const String _kWallpaperPhotoPrefix = 'thix_chat_wallpaper_photo_v1_';

String _tr(AppLocalizations l10n, String key, String fallback) => chatTr(l10n, key, fallback);

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
        chatLog('[Chat] ❌ $label: timeout after $attempt attempts');
        throw TimeoutException('$label: délai dépassé');
      }
      await Future.delayed(_kRetryDelay);
    } catch (e) {
      chatLog('[Chat] ❌ $label error: $e');
      rethrow;
    }
  }
}

Future<void> _fireAndForget(Future<dynamic> Function() fn) async {
  try {
    await fn();
  } catch (e) {
    chatLog('[Chat] ⚠️ background op: $e');
  }
}

// ============================================================================
// FONDS D'ÉCRAN
// ============================================================================
class _Wallpaper {
  final String id;
  final String label;
  final Color? color;
  final List<Color>? gradient;
  final bool pattern;
  const _Wallpaper(this.id, this.label, {this.color, this.gradient, this.pattern = false});
}

const List<_Wallpaper> _kWallpapers = [
  _Wallpaper('default', 'THIX', pattern: true),
  _Wallpaper('cream', 'Crème', color: Color(0xFFF6F1E7)),
  _Wallpaper('mint', 'Menthe', color: Color(0xFFE6F2EA)),
  _Wallpaper('rose', 'Rose', color: Color(0xFFF8E9EC)),
  _Wallpaper('sand', 'Sable', gradient: [Color(0xFFF3E6CF), Color(0xFFE8D3B0)]),
  _Wallpaper('sunset', 'Coucher', gradient: [Color(0xFFFFE0C2), Color(0xFFF5B7B1)]),
  _Wallpaper('forest', 'Forêt', gradient: [Color(0xFFCFE8D5), Color(0xFF8FBF9F)]),
  _Wallpaper('night', 'Nuit', gradient: [Color(0xFF1F2430), Color(0xFF2E3447)]),
];

// ============================================================================
// PROVIDER MESSAGES
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

  List<Map<String, dynamic>> _cacheable(List<ChatMessage> msgs) =>
      msgs.where((m) => !m.isViewOnce && !m.isExpired).map((m) => m.toJson()).toList();

  Future<void> _persist() async {
    final uid = svc.currentUserId;
    if (uid.isEmpty) return;
    unawaited(ChatOfflineCache.instance.saveMessages(uid, convId, _cacheable(state)));
  }

  Future<void> loadInitial() async {
    page = 0;
    final uid = svc.currentUserId;
    try {
      final msgs = await _chatRetry(() => svc.getMessages(convId, limit: pageSize, offset: 0), label: 'loadInitial');
      if (!mounted) return;
      hasMore = msgs.length >= pageSize;
      final live = msgs.where((m) => !m.isExpired).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      state = live;
      if (uid.isNotEmpty) unawaited(ChatOfflineCache.instance.saveMessages(uid, convId, _cacheable(live)));
    } catch (e) {
      chatLog('[ChatMsg] ❌ Load initial error: $e');
      if (!mounted) return;
      if (uid.isNotEmpty) {
        final cached = ChatOfflineCache.instance.readMessages(uid, convId);
        if (cached.isNotEmpty) {
          state = cached.map(ChatMessage.fromJson).where((m) => m.id.isNotEmpty && !m.isViewOnce && !m.isExpired).toList()
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
      final msgs = await _chatRetry(() => svc.getMessages(convId, limit: pageSize, offset: page * pageSize), label: 'loadMore');
      if (!mounted) return;
      hasMore = msgs.length >= pageSize;
      var current = [...state, ...msgs.where((m) => !m.isExpired)];
      final seen = <String>{};
      current = current.where((m) => seen.add(m.id)).toList();
      current.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      state = current;
    } catch (e) {
      chatLog('[ChatMsg] ❌ Load more error: $e');
    } finally {
      loadingMore = false;
    }
  }

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
    if (updated.isEmpty || !mounted) return;
    var current = [...state];
    var changed = false;
    for (final msg in updated) {
      final idx = current.indexWhere((m) => m.id == msg.id);
      final gone = msg.isExpired || (msg.isEphemeral && msg.isDeleted);
      if (gone) {
        if (idx != -1) {
          current.removeAt(idx);
          changed = true;
        }
        continue;
      }
      if (idx != -1) {
        current[idx] = msg;
        changed = true;
      } else if (!msg.isDeleted && !msg.isDeletedForAll) {
        current.insert(0, msg);
        changed = true;
      }
    }
    if (changed) {
      current.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      final seen = <String>{};
      current = current.where((m) => seen.add(m.id)).toList();
      state = current;
      unawaited(_persist());
    }
  }

  void purgeExpired() {
    if (!mounted) return;
    final keep = state.where((m) => !m.isExpired).toList();
    if (keep.length != state.length) {
      state = keep;
      unawaited(_persist());
    }
  }

  void removeLocal(String id) {
    if (!mounted) return;
    state = state.where((m) => m.id != id).toList();
    unawaited(_persist());
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
    final isImg = m.mediaType == 'image' && (m.mediaUrl?.isNotEmpty ?? false) && !m.isViewOnce;
    if (isImg) {
      final group = <ChatMessage>[m];
      int j = i + 1;
      while (j < messages.length) {
        final next = messages[j];
        final sameSender = next.senderId == m.senderId;
        final alsoImg = next.mediaType == 'image' && (next.mediaUrl?.isNotEmpty ?? false) && !next.isViewOnce;
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
// SWIPE : droite = répondre, gauche = menu
// ============================================================================
class _SwipeActions extends StatefulWidget {
  final Widget child;
  final VoidCallback onReply;
  final VoidCallback onMore;
  const _SwipeActions({super.key, required this.child, required this.onReply, required this.onMore});
  @override
  State<_SwipeActions> createState() => _SwipeActionsState();
}

class _SwipeActionsState extends State<_SwipeActions> {
  double _dx = 0;
  bool _dragging = false;
  bool _armed = false;

  void _onUpdate(DragUpdateDetails d) {
    final next = (_dx + d.delta.dx * 0.8).clamp(-_kSwipeMax, _kSwipeMax).toDouble();
    final nowArmed = next.abs() >= _kSwipeTrigger;
    if (nowArmed && !_armed) HapticFeedback.selectionClick();
    _armed = nowArmed;
    setState(() {
      _dx = next;
      _dragging = true;
    });
  }

  void _onEnd([DragEndDetails? _]) {
    final dx = _dx;
    setState(() {
      _dx = 0;
      _dragging = false;
    });
    _armed = false;
    if (dx >= _kSwipeTrigger) {
      widget.onReply();
    } else if (dx <= -_kSwipeTrigger) {
      widget.onMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = (_dx.abs() / _kSwipeTrigger).clamp(0.0, 1.0).toDouble();
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragUpdate: _onUpdate,
      onHorizontalDragEnd: _onEnd,
      onHorizontalDragCancel: _onEnd,
      child: Stack(children: [
        if (_dx != 0)
          Positioned.fill(
            child: Align(
              alignment: _dx >= 0 ? Alignment.centerLeft : Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Opacity(
                  opacity: progress,
                  child: Transform.scale(
                    scale: 0.7 + 0.3 * progress,
                    child: _dx >= 0
                        ? const Icon(Icons.reply_rounded, color: ThixPolicy.inkDeep, size: 24)
                        : const Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.notifications_active_outlined, color: ThixPolicy.gold, size: 20),
                            SizedBox(width: 6),
                            Icon(Icons.more_horiz_rounded, color: ThixPolicy.inkDeep, size: 20),
                          ]),
                  ),
                ),
              ),
            ),
          ),
        AnimatedContainer(
          duration: _dragging ? Duration.zero : const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          transform: Matrix4.translationValues(_dx, 0, 0),
          child: widget.child,
        ),
      ]),
    );
  }
}

class _SelectableRow extends StatelessWidget {
  final bool selected;
  final VoidCallback onTap;
  final Widget child;
  const _SelectableRow({required this.selected, required this.onTap, required this.child});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        color: selected ? ThixPolicy.inkDeep.withOpacity(0.08) : Colors.transparent,
        child: Row(children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, right: 6),
            child: Icon(selected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                size: 22, color: selected ? ThixPolicy.inkDeep : ThixPolicy.textMuted),
          ),
          Expanded(child: AbsorbPointer(child: child)),
        ]),
      ),
    );
  }
}

// ============================================================================
// SCREEN
// ============================================================================
class ChatScreen extends ConsumerStatefulWidget {
  final String conversationId;
  final ChatConversation conversation;

  /// EXCEPTION THIX MARKET : lève la règle « être connectés » (acheteur ↔ vendeur).
  final bool isMarketChat;

  const ChatScreen({
    super.key,
    required this.conversationId,
    required this.conversation,
    this.isMarketChat = false,
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
  Map<String, GroupMember> _groupById = <String, GroupMember>{};
  String _replyToId = '';
  bool _isEphemeral = false;
  int? _ephemeralDuration;
  bool _isTyping = false;
  bool _otherUserTyping = false;
  bool _isConnectionValid = true;
  DateTime? _lastSendAt;

  Timer? _typingTimer;
  Timer? _markReadTimer;
  Timer? _searchDebounce;
  Timer? _expiryTimer;
  Timer? _draftTimer;
  DateTime? _lastConnCheck;
  DateTime? _lastLoadMore;
  bool _isAgent = false;
  bool _isInternalNoteMode = false;
  StreamSubscription<List<ChatMessage>>? _messageSub;
  StreamSubscription<List<UserStatus>>? _presenceSub;
  bool _showScrollDown = false;
  int _newWhileScrolled = 0;

  // ── Envoi optimiste ──
  final List<PendingMessage> _pending = <PendingMessage>[];
  Future<void> _queue = Future<void>.value();

  // ── Édition / Brouillon ──
  String _editingMessageId = '';
  String _draftBeforeEdit = '';
  bool _restoringDraft = false;
  // ── Recherche ──
  bool _searchActive = false;
  List<String> _searchMatches = <String>[];
  int _searchPos = -1;
  // ── Épinglés ──
  List<ChatMessage> _pinnedMessages = <ChatMessage>[];
  int _pinnedCursor = 0;
  bool _pinnedBarClosed = false;
  // ── Favoris / View once ──
  final Set<String> _starredIds = <String>{};
  final Set<String> _viewedOnceIds = <String>{};
  // ── Jump unread ──
  int _initialUnread = 0;
  String _firstUnreadId = '';
  bool _showJumpUnread = false;
  bool _unreadAnchorDone = false;
  // ── Mentions ──
  List<GroupMember> _mentionSuggestions = <GroupMember>[];
  final List<String> _mentionedUserIds = <String>[];
  // ── Rappels ──
  final Map<String, Timer> _reminderTimers = <String, Timer>{};
  final Set<String> _reminderScheduled = <String>{};
  // ── Ancres ──
  final Map<String, GlobalKey> _msgKeys = <String, GlobalKey>{};
  List<String> _displayIds = <String>[];
  // ── Sélection multiple ──
  bool _selectionMode = false;
  final Set<String> _selectedIds = <String>{};
  // ── Fond d'écran ──
  String _wallpaperId = 'default';
  String? _wallpaperPhoto;
  // ── Appels ──
  bool? _myCallsOverride;
  // ── Capture d'écran ──
  ScreenshotCallback? _screenshotCb;
  DateTime? _lastShotAt;

  bool _marketByContent = false;
  bool get _isMarketConversation => widget.isMarketChat || _marketByContent;
  bool get _canWrite => _isConnectionValid || _isMarketConversation;

  String get _otherId =>
      widget.conversation.participantIds.firstWhere((id) => id != _chatService.currentUserId, orElse: () => '');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _chatService = ref.read(chatServiceProvider);
    _connectionService = ConnectionService();
    _chatService.startPresenceHeartbeat();

    try {
      final convs = ref.read(chatListProvider).all;
      for (final c in convs) {
        if (c.id == widget.conversationId) {
          _initialUnread = c.unreadCount;
          break;
        }
      }
    } catch (e) {
      chatLog('[Chat] ⚠️ unread capture: $e');
    }

    // ⚡ Plus de setState à chaque frappe : la barre de saisie gère son propre état.
    _inputController.addListener(() {
      if (!mounted || _restoringDraft) return;
      if (_editingMessageId.isEmpty) {
        _onTypingChanged(_inputController.text);
        _scheduleDraftSave();
      }
      _onMentionQueryChanged(_inputController.text);
    });

    _searchCtrl.addListener(_onSearchChanged);
    _checkConnectionSecurity();
    _loadUserRole();
    _getParticipantInfo();
    _loadGroupMembers();
    _loadPinned();
    _loadStarred();
    _restoreDraft();
    _loadWallpaper();
    _markAsRead();
    _initScreenshotGuard();

    try {
      _subscribeToPresence();
      _subscribeToRealtime();
      _subscribeToTyping();
    } catch (e) {
      chatLog('[Chat] ⚠️ realtime subscribe: $e');
    }

    _expiryTimer = Timer.periodic(const Duration(seconds: _kExpirySweepSeconds), (_) {
      if (!mounted) return;
      ref.read(chatMessagesProvider(widget.conversationId).notifier).purgeExpired();
    });

    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _flushDraft();
    _chatService.stopPresenceHeartbeat();
    try {
      _chatService.stopTypingListener(widget.conversationId);
    } catch (e) {
      chatLog('[Chat] ⚠️ stopTypingListener: $e');
    }
    try {
      _screenshotCb?.dispose();
    } catch (_) {}
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.dispose();
    _inputController.dispose();
    _inputFocus.dispose();
    _searchCtrl.dispose();
    _typingTimer?.cancel();
    _markReadTimer?.cancel();
    _searchDebounce?.cancel();
    _expiryTimer?.cancel();
    _draftTimer?.cancel();
    _messageSub?.cancel();
    _presenceSub?.cancel();
    for (final t in _reminderTimers.values) {
      t.cancel();
    }
    _reminderTimers.clear();
    super.dispose();
  }

  // ==========================================================================
  // CAPTURE D'ÉCRAN → alerte envoyée à l'autre
  // ==========================================================================
  void _initScreenshotGuard() {
    if (kIsWeb) return;
    try {
      _screenshotCb = ScreenshotCallback();
      _screenshotCb!.addListener(_onScreenshotTaken);
    } catch (e) {
      chatLog('[Chat] ⚠️ screenshot guard: $e');
    }
  }

  void _onScreenshotTaken() {
    if (!mounted) return;
    final now = DateTime.now();
    if (_lastShotAt != null && now.difference(_lastShotAt!).inSeconds < _kScreenshotThrottleSeconds) return;
    _lastShotAt = now;
    final l10n = AppLocalizations.of(context);
    chatSnack(context, _tr(l10n, 'chat_screenshot_warn', 'Capture détectée : l’autre participant est prévenu.'), ChatSnackKind.warning);
    unawaited(_fireAndForget(() async {
      final msg = await _chatService.sendMessage(
        conversationId: widget.conversationId,
        content: '📸 ${_tr(l10n, 'chat_screenshot_taken', 'Capture d’écran effectuée')}',
        mediaType: 'system_screenshot',
      );
      if (mounted) ref.read(chatMessagesProvider(widget.conversationId).notifier).upsertRealtime([msg]);
    }));
  }

  // ==========================================================================
  // APPELS : activer / désactiver
  // ==========================================================================
  Future<void> _toggleMyCalls(bool allow) async {
    final l10n = AppLocalizations.of(context);
    final myId = _chatService.currentUserId;
    if (myId.isEmpty) return;
    HapticFeedback.selectionClick();
    setState(() => _myCallsOverride = allow);
    try {
      await Supabase.instance.client.from('profiles').update({'calls_enabled': allow}).eq('id', myId);
      ref.invalidate(userProfileProvider(myId));
      if (mounted) {
        chatSnack(
          context,
          allow ? _tr(l10n, 'chat_calls_on', 'Appels activés') : _tr(l10n, 'chat_calls_off', 'Appels désactivés : le bouton disparaît aussi chez vos contacts'),
          ChatSnackKind.success,
        );
      }
    } catch (e) {
      chatLog('[Chat] ❌ toggle calls: $e');
      if (mounted) {
        setState(() => _myCallsOverride = !allow);
        chatSnack(context, ChatValidators.friendlyError(e), ChatSnackKind.error);
      }
    }
  }

  // ==========================================================================
  // FOND D'ÉCRAN
  // ==========================================================================
  Future<void> _loadWallpaper() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final id = prefs.getString('$_kWallpaperPrefix${widget.conversationId}') ?? 'default';
      final photo = prefs.getString('$_kWallpaperPhotoPrefix${widget.conversationId}');
      if (!mounted) return;
      setState(() {
        _wallpaperId = id;
        _wallpaperPhoto = photo;
        if (id == 'photo' && (photo == null || !File(photo).existsSync())) _wallpaperId = 'default';
      });
    } catch (e) {
      chatLog('[Chat] ⚠️ loadWallpaper: $e');
    }
  }

  Future<void> _setWallpaper(String id, {String? photoPath}) async {
    setState(() {
      _wallpaperId = id;
      if (photoPath != null) _wallpaperPhoto = photoPath;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('$_kWallpaperPrefix${widget.conversationId}', id);
      if (photoPath != null) await prefs.setString('$_kWallpaperPhotoPrefix${widget.conversationId}', photoPath);
    } catch (e) {
      chatLog('[Chat] ⚠️ setWallpaper: $e');
    }
  }

  Future<void> _pickWallpaperPhoto() async {
    final l10n = AppLocalizations.of(context);
    try {
      final x = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 80, maxWidth: 1600);
      if (x == null) return;
      final dir = await getApplicationDocumentsDirectory();
      final target = p.join(dir.path, 'chat_wallpaper_${widget.conversationId}_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await File(x.path).copy(target);
      final old = _wallpaperPhoto;
      await _setWallpaper('photo', photoPath: target);
      if (old != null && old != target) {
        try {
          await File(old).delete();
        } catch (_) {}
      }
    } catch (e) {
      if (mounted) chatSnack(context, _tr(l10n, 'chat_wallpaper_error', 'Impossible de charger la photo'), ChatSnackKind.error);
    }
  }

  void _showWallpaperSheet() {
    final l10n = AppLocalizations.of(context);
    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      backgroundColor: ThixPolicy.card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: ThixPolicy.border, borderRadius: BorderRadius.circular(4))),
            const SizedBox(height: 14),
            Text(_tr(l10n, 'chat_wallpaper_title', 'Fond d’écran de la conversation'), style: ThixPolicy.titleStyle.copyWith(fontWeight: ThixPolicy.bold, fontSize: 16)),
            const SizedBox(height: 14),
            Wrap(
              spacing: 12,
              runSpacing: 14,
              alignment: WrapAlignment.center,
              children: [
                ..._kWallpapers.map((w) => _wallpaperSwatch(
                      label: w.label,
                      selected: _wallpaperId == w.id,
                      onTap: () {
                        Navigator.pop(ctx);
                        _setWallpaper(w.id);
                      },
                      child: _wallpaperPreview(w),
                    )),
                if (!kIsWeb)
                  _wallpaperSwatch(
                    label: _tr(l10n, 'chat_wallpaper_photo', 'Ma photo'),
                    selected: _wallpaperId == 'photo',
                    onTap: () {
                      Navigator.pop(ctx);
                      _pickWallpaperPhoto();
                    },
                    child: Container(color: ThixPolicy.surfaceSoft, child: const Icon(Icons.add_photo_alternate_outlined, color: ThixPolicy.inkDeep)),
                  ),
              ],
            ),
          ]),
        ),
      ),
    );
  }

  Widget _wallpaperPreview(_Wallpaper w) {
    if (w.gradient != null) {
      return Container(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: w.gradient!)));
    }
    if (w.pattern) {
      return Container(color: ThixPolicy.surfaceSoft, child: const Center(child: Text('THIX', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Color(0x33000000)))));
    }
    return Container(color: w.color);
  }

  Widget _wallpaperSwatch({required String label, required bool selected, required VoidCallback onTap, required Widget child}) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 72,
        child: Column(children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: selected ? ThixPolicy.inkDeep : ThixPolicy.border, width: selected ? 2.5 : 1)),
            clipBehavior: Clip.antiAlias,
            child: Stack(fit: StackFit.expand, children: [
              child,
              if (selected) Container(color: Colors.black.withOpacity(0.18), child: const Icon(Icons.check_rounded, color: Colors.white)),
            ]),
          ),
          const SizedBox(height: 4),
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: ThixPolicy.textSecondary)),
        ]),
      ),
    );
  }

  Widget _buildWallpaper() {
    if (_wallpaperId == 'photo' && _wallpaperPhoto != null && !kIsWeb) {
      return Stack(fit: StackFit.expand, children: [
        Image.file(File(_wallpaperPhoto!), fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: ThixPolicy.surfaceSoft)),
        Container(color: Colors.black.withOpacity(0.12)),
      ]);
    }
    final w = _kWallpapers.firstWhere((e) => e.id == _wallpaperId, orElse: () => _kWallpapers.first);
    if (w.gradient != null) {
      return Container(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: w.gradient!)));
    }
    if (w.pattern) return CustomPaint(painter: _ThixChatBackgroundPainter());
    return ColoredBox(color: w.color ?? ThixPolicy.surfaceSoft);
  }

  // ==========================================================================
  // BROUILLONS
  // ==========================================================================
  String get _draftKey => '$_kDraftPrefix${_chatService.currentUserId}_${widget.conversationId}';

  Future<void> _restoreDraft() async {
    if (_chatService.currentUserId.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final d = ChatValidators.sanitize(prefs.getString(_draftKey));
      if (!mounted || d.isEmpty || _inputController.text.isNotEmpty || _editingMessageId.isNotEmpty) return;
      _restoringDraft = true;
      _inputController.text = d;
      _inputController.selection = TextSelection.fromPosition(TextPosition(offset: d.length));
      _restoringDraft = false;
    } catch (e) {
      _restoringDraft = false;
      chatLog('[Chat] ⚠️ restoreDraft: $e');
    }
  }

  void _scheduleDraftSave() {
    _draftTimer?.cancel();
    final text = _inputController.text;
    _draftTimer = Timer(const Duration(milliseconds: _kDraftSaveDebounceMs), () => unawaited(_persistDraft(text)));
  }

  void _flushDraft() {
    _draftTimer?.cancel();
    final pending = _editingMessageId.isNotEmpty ? _draftBeforeEdit : _inputController.text;
    unawaited(_persistDraft(pending));
  }

  Future<void> _persistDraft(String raw) async {
    if (_chatService.currentUserId.isEmpty) return;
    final key = _draftKey;
    try {
      final prefs = await SharedPreferences.getInstance();
      final clean = ChatValidators.sanitize(raw);
      if (clean.isEmpty) {
        await prefs.remove(key);
      } else {
        await prefs.setString(key, clean);
      }
    } catch (e) {
      chatLog('[Chat] ⚠️ persistDraft: $e');
    }
  }

  // ==========================================================================
  // CYCLE DE VIE / SÉCURITÉ CONNEXION
  // ==========================================================================
  Future<void> _checkConnectionSecurity() async {
    if (widget.conversation.isGroup || _isAgent) return;
    if (_isMarketConversation) {
      if (!_isConnectionValid) setState(() => _isConnectionValid = true);
      return;
    }
    final now = DateTime.now();
    if (_lastConnCheck != null && now.difference(_lastConnCheck!).inSeconds < _kPresenceCheckThrottleSeconds) return;
    _lastConnCheck = now;
    final myId = _chatService.currentUserId;
    final otherId = _otherId;
    if (otherId.isEmpty) return;
    try {
      final isConnected = await _chatRetry(() => _connectionService.checkConnection(myId, otherId), label: 'checkConnection');
      if (mounted) setState(() => _isConnectionValid = isConnected);
    } catch (e) {
      chatLog('[Chat] ⚠️ Connection check failed: $e');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _chatService.startPresenceHeartbeat();
        _checkConnectionSecurity();
        ref.read(chatMessagesProvider(widget.conversationId).notifier).purgeExpired();
        final o = _otherId;
        if (o.isNotEmpty) ref.invalidate(userProfileProvider(o));
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        _flushDraft();
        _chatService.stopPresenceHeartbeat();
        break;
    }
  }

  Future<void> _loadUserRole() async {
    try {
      final uid = _chatService.currentUserId;
      if (uid.isEmpty) return;
      final role = await _chatRetry(() => _chatService.getUserRole(uid), label: 'loadUserRole');
      if (mounted && role.isNotEmpty) {
        setState(() => _isAgent = role == 'agent' || role == 'admin' || role == 'support' || role == 'enterprise');
      }
    } catch (e) {
      chatLog('[Chat] ⚠️ Load user role failure: $e');
    }
  }

  Future<void> _loadGroupMembers() async {
    try {
      final members = await _chatRetry(() => _chatService.getGroupMembers(widget.conversationId), label: 'loadGroupMembers');
      if (mounted) {
        setState(() {
          _groupMembers = members;
          _groupById = {for (final m in members) m.userId: m};
        });
      }
    } catch (e) {
      chatLog('[Chat] ⚠️ Load group members error: $e');
    }
  }

  Future<void> _loadPinned() async {
    try {
      final pinned = await _chatRetry(() => _chatService.getPinnedMessages(widget.conversationId), label: 'getPinnedMessages');
      if (mounted) setState(() => _pinnedMessages = pinned);
    } catch (e) {
      chatLog('[Chat] ⚠️ Load pinned error: $e');
    }
  }

  Future<void> _loadStarred() async {
    try {
      final starred = await _chatRetry(() => _chatService.getStarredMessages(limit: 100), label: 'getStarredMessages');
      if (!mounted) return;
      setState(() {
        _starredIds.clear();
        for (final m in starred) {
          if (m.conversationId == widget.conversationId) _starredIds.add(m.id);
        }
      });
      _syncStarFlags();
    } catch (e) {
      chatLog('[Chat] ⚠️ Load starred error: $e');
    }
  }

  void _syncStarFlags() {
    if (_starredIds.isEmpty) return;
    final msgs = ref.read(chatMessagesProvider(widget.conversationId));
    final toFix = msgs.where((m) => _starredIds.contains(m.id) && !m.isStarred).toList();
    if (toFix.isEmpty) return;
    ref.read(chatMessagesProvider(widget.conversationId).notifier).upsertRealtime(toFix.map((m) => _overrideMsg(m, const {'is_starred': true})).toList());
  }

  // ==========================================================================
  // REALTIME
  // ==========================================================================
  void _subscribeToRealtime() {
    _messageSub = _chatService.subscribeToMessages(widget.conversationId).listen(
      (updated) {
        final me = _chatService.currentUserId;
        if (_showScrollDown) {
          final known = ref.read(chatMessagesProvider(widget.conversationId)).map((m) => m.id).toSet();
          final fresh = updated.where((m) => m.senderId != me && !known.contains(m.id) && !m.isDeleted).length;
          if (fresh > 0 && mounted) setState(() => _newWhileScrolled += fresh);
        }
        ref.read(chatMessagesProvider(widget.conversationId).notifier).upsertRealtime(updated);
        final idsToDeliver = updated.where((m) => m.senderId != me && !m.isDelivered && !m.isDeleted).map((m) => m.id).toList();
        if (idsToDeliver.isNotEmpty) unawaited(_fireAndForget(() => _chatService.markMessagesDelivered(idsToDeliver)));
        for (final m in updated) {
          if (m.isPinned && !_pinnedMessages.any((p) => p.id == m.id)) {
            _loadPinned();
            break;
          }
        }
        _scheduleRemindersFor(updated);
        _scheduleMarkAsRead();
      },
      onError: (e) => chatLog('[Chat] ⚠️ Realtime subscription error: $e'),
    );
  }

  void _subscribeToTyping() {
    final cur = _chatService.currentUserId;
    if (cur.isEmpty) return;
    _chatService.startTypingListener(widget.conversationId, (sid, typing) {
      if (sid != cur && mounted && _otherUserTyping != typing) setState(() => _otherUserTyping = typing);
    });
  }

  void _subscribeToPresence() {
    if (widget.conversation.isGroup) return;
    final otherId = _otherId;
    if (otherId.isEmpty) return;
    _presenceSub = _chatService.subscribeToPresence([otherId]).listen(
      (list) {
        if (mounted && list.isNotEmpty) setState(() => _otherParticipant = list.first);
      },
      onError: (e) => chatLog('[Chat] ⚠️ Presence subscription error: $e'),
    );
  }

  void _sendTypingStatus(bool t) {
    if (!_canWrite) return;
    if (_chatService.currentUserId.isEmpty) return;
    unawaited(_fireAndForget(() => _chatService.sendTypingStatus(widget.conversationId, isTyping: t)));
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
  // HELPERS
  // ==========================================================================
  ChatMessage _overrideMsg(ChatMessage m, Map<String, dynamic> patch) {
    try {
      final json = Map<String, dynamic>.from(m.toJson());
      json.addAll(patch);
      return ChatMessage.fromJson(json);
    } catch (e) {
      chatLog('[Chat] ⚠️ overrideMsg: $e');
      return m;
    }
  }

  GlobalKey _keyFor(String id) {
    if (_msgKeys.length > 600) _msgKeys.clear();
    return _msgKeys.putIfAbsent(id, () => GlobalKey());
  }

  void _scrollToMessage(String id, {bool retry = true}) {
    final ctx = _msgKeys[id]?.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(ctx, alignment: 0.3, duration: const Duration(milliseconds: 300));
      return;
    }
    if (!retry || !_scrollController.hasClients) return;
    final idx = _displayIds.indexOf(id);
    if (idx < 0) return;
    final target = ((idx + _pending.length) * 88.0).clamp(0.0, _scrollController.position.maxScrollExtent).toDouble();
    _scrollController.animateTo(target, duration: const Duration(milliseconds: 300), curve: Curves.easeOut).then((_) {
      if (mounted) WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToMessage(id, retry: false));
    });
  }

  void _markAsRead() {
    try {
      ref.read(chatListProvider.notifier).markAsRead(widget.conversationId);
    } catch (e) {
      chatLog('[Chat] ⚠️ Mark as read error: $e');
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
    if (_newWhileScrolled != 0 && mounted) setState(() => _newWhileScrolled = 0);
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - _kLoadMoreThresholdPx) {
      final now = DateTime.now();
      if (_lastLoadMore != null && now.difference(_lastLoadMore!).inMilliseconds < _kLoadMoreThrottleMs) return;
      _lastLoadMore = now;
      ref.read(chatMessagesProvider(widget.conversationId).notifier).loadMore();
    }
    if (_showJumpUnread && pos.pixels < 60) setState(() => _showJumpUnread = false);
    final show = pos.pixels > 240;
    if (show != _showScrollDown) {
      setState(() {
        _showScrollDown = show;
        if (!show) _newWhileScrolled = 0;
      });
    }
  }

  void _setReply(ChatMessage msg) {
    if (msg.isDeleted || msg.isDeletedForAll) return;
    HapticFeedback.selectionClick();
    if (_editingMessageId.isNotEmpty) _cancelEdit();
    setState(() => _replyToId = msg.id);
    _inputFocus.requestFocus();
  }

  bool _canEdit(ChatMessage m) {
    if (m.senderId != _chatService.currentUserId) return false;
    if (m.isDeleted || m.isDeletedForAll || m.isViewOnce || m.hasMedia) return false;
    final t = '${m.mediaType ?? ''}';
    if (t.startsWith('call_') || t.startsWith('system_')) return false;
    if (isProductRefMessage(m)) return false;
    return DateTime.now().difference(m.createdAt.toLocal()).inMinutes < _kEditWindowMinutes;
  }

  // ==========================================================================
  // RAPPELS
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
        chatSnack(context, '🔔 ${_tr(AppLocalizations.of(context), 'chat_reminder_due', 'Rappel')} : ${chatPreviewOf(m)}', ChatSnackKind.info);
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
        decoration: BoxDecoration(color: ThixPolicy.card, borderRadius: const BorderRadius.vertical(top: Radius.circular(22))),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: ThixPolicy.border, borderRadius: BorderRadius.circular(4))),
          const SizedBox(height: 14),
          Text(_tr(l10n, 'chat_remind_title', 'Me rappeler ce message'), style: ThixPolicy.titleStyle.copyWith(fontWeight: ThixPolicy.bold)),
          const SizedBox(height: 8),
          ...options.map((o) => ListTile(
                leading: const Icon(Icons.notifications_active_outlined, color: ThixPolicy.gold),
                title: Text(o['label'] as String),
                onTap: () async {
                  Navigator.pop(ctx);
                  final at = o['at'] as DateTime;
                  try {
                    await _chatRetry(() => _chatService.setMessageReminder(msg.id, at), label: 'setMessageReminder');
                    final patched = _overrideMsg(msg, {'reminder_at': at.toUtc().toIso8601String()});
                    ref.read(chatMessagesProvider(widget.conversationId).notifier).upsertRealtime([patched]);
                    _scheduleRemindersFor([patched]);
                    _showSuccess(_tr(l10n, 'chat_remind_set', 'Rappel programmé'));
                  } catch (e) {
                    _showError(ChatValidators.friendlyError(e));
                  }
                },
              )),
        ]),
      ),
    );
  }

  // ==========================================================================
  // ÉDITION
  // ==========================================================================
  void _startEdit(ChatMessage msg) {
    final l10n = AppLocalizations.of(context);
    if (!_canEdit(msg)) {
      _showWarning(_tr(l10n, 'chat_edit_window', 'Modification possible pendant $_kEditWindowMinutes min, texte uniquement.'));
      return;
    }
    HapticFeedback.selectionClick();
    if (_editingMessageId.isEmpty) _draftBeforeEdit = _inputController.text;
    _restoringDraft = true;
    _inputController.text = msg.content;
    _inputController.selection = TextSelection.fromPosition(TextPosition(offset: msg.content.length));
    _restoringDraft = false;
    setState(() {
      _editingMessageId = msg.id;
      _replyToId = '';
    });
    _inputFocus.requestFocus();
  }

  Future<void> _applyEdit(ChatMessage msg, String newContent) async {
    final l10n = AppLocalizations.of(context);
    if (!_canEdit(msg)) {
      _showWarning(_tr(l10n, 'chat_edit_window', 'Modification possible pendant $_kEditWindowMinutes min, texte uniquement.'));
      if (_editingMessageId.isNotEmpty) _cancelEdit();
      return;
    }
    final clean = ChatValidators.sanitize(newContent, maxLength: kChatMaxMessageLength);
    if (clean.isEmpty || clean == msg.content) {
      _cancelEdit();
      return;
    }
    try {
      final updated = await _chatRetry(() => _chatService.editMessage(msg.id, clean), label: 'editMessage');
      final notifier = ref.read(chatMessagesProvider(widget.conversationId).notifier);
      if (updated != null) {
        notifier.upsertRealtime([updated]);
      } else {
        notifier.upsertRealtime([
          _overrideMsg(msg, {'content': clean, 'is_edited': true, 'updated_at': DateTime.now().toUtc().toIso8601String()}),
        ]);
      }
      _showSuccess(_tr(l10n, 'chat_edit_done', 'Message modifié'));
    } catch (e) {
      _showError(ChatValidators.friendlyError(e));
    } finally {
      if (mounted && _editingMessageId.isNotEmpty) _cancelEdit();
    }
  }

  void _cancelEdit() {
    final restore = _draftBeforeEdit;
    _draftBeforeEdit = '';
    _restoringDraft = true;
    _inputController.text = restore;
    _inputController.selection = TextSelection.fromPosition(TextPosition(offset: restore.length));
    _restoringDraft = false;
    if (mounted) setState(() => _editingMessageId = '');
  }

  // ==========================================================================
  // SUPPRESSIONS
  // ==========================================================================
  void _showDeleteOptions(ChatMessage msg) {
    if (msg.isExpired || msg.isEphemeral) {
      unawaited(_deleteEphemeral(msg));
      return;
    }
    final l10n = AppLocalizations.of(context);
    final canAll = msg.canBeDeletedForAll(_chatService.currentUserId);
    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      backgroundColor: ThixPolicy.card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 10),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: ThixPolicy.border, borderRadius: BorderRadius.circular(4))),
          const SizedBox(height: 12),
          Text(_tr(l10n, 'chat_delete_title', 'Supprimer le message ?'), style: ThixPolicy.titleStyle.copyWith(fontWeight: ThixPolicy.bold, fontSize: 16)),
          const SizedBox(height: 6),
          ListTile(
            leading: const Icon(Icons.person_outline_rounded, color: ThixPolicy.textMain),
            title: Text(_tr(l10n, 'chat_delete_for_me', 'Supprimer pour moi')),
            subtitle: Text(_tr(l10n, 'chat_delete_for_me_body', 'Les autres participants le verront toujours.')),
            onTap: () {
              Navigator.pop(ctx);
              _deleteForMe(msg);
            },
          ),
          ListTile(
            enabled: canAll,
            leading: Icon(Icons.delete_forever_rounded, color: canAll ? ThixPolicy.danger : ThixPolicy.textMuted),
            title: Text(_tr(l10n, 'chat_delete_for_all', 'Supprimer pour tous'), style: TextStyle(color: canAll ? ThixPolicy.danger : ThixPolicy.textMuted, fontWeight: FontWeight.w600)),
            subtitle: Text(canAll
                ? _tr(l10n, 'chat_delete_for_all_body', 'Le message sera remplacé par « Message supprimé » chez tous.')
                : _tr(l10n, 'chat_delete_for_all_unavailable', 'Réservé à vos messages, pendant $_kDeleteForAllWindowMinutes min après envoi.')),
            onTap: canAll
                ? () {
                    Navigator.pop(ctx);
                    _deleteForAll(msg);
                  }
                : null,
          ),
          ListTile(leading: const Icon(Icons.close_rounded, color: ThixPolicy.textSecondary), title: Text(_tr(l10n, 'common_cancel', 'Annuler')), onTap: () => Navigator.pop(ctx)),
          const SizedBox(height: 6),
        ]),
      ),
    );
  }

  Future<void> _deleteEphemeral(ChatMessage msg) async {
    final notifier = ref.read(chatMessagesProvider(widget.conversationId).notifier);
    notifier.removeLocal(msg.id);
    if (msg.isExpired) return;
    final me = _chatService.currentUserId;
    try {
      if (msg.senderId == me) {
        await _chatRetry(() => _chatService.deleteMessageForAll(msg.id), label: 'deleteEphemeralAll');
      } else {
        await _chatRetry(() => _chatService.deleteMessage(msg.id), label: 'deleteEphemeralMe');
      }
    } catch (e) {
      chatLog('[Chat] ⚠️ deleteEphemeral: $e');
      await _fireAndForget(() => _chatService.deleteMessage(msg.id));
    }
  }

  Future<void> _deleteForMe(ChatMessage msg) async {
    final l10n = AppLocalizations.of(context);
    try {
      await _chatRetry(() => _chatService.deleteMessage(msg.id), label: 'deleteMessage');
      ref.read(chatMessagesProvider(widget.conversationId).notifier).removeLocal(msg.id);
      _showSuccess(_tr(l10n, 'chat_deleted_me', 'Message supprimé pour vous'));
    } catch (e) {
      _showError(ChatValidators.friendlyError(e));
    }
  }

  Future<void> _deleteForAll(ChatMessage msg) async {
    final l10n = AppLocalizations.of(context);
    if (!msg.canBeDeletedForAll(_chatService.currentUserId)) {
      _showWarning(_tr(l10n, 'chat_delete_window', 'Suppression pour tous possible pendant $_kDeleteForAllWindowMinutes min après envoi.'));
      return;
    }
    try {
      await _chatRetry(() => _chatService.deleteMessageForAll(msg.id), label: 'deleteMessageForAll');
      ref.read(chatMessagesProvider(widget.conversationId).notifier).upsertRealtime([
        _overrideMsg(msg, {'is_deleted_for_all': true, 'is_deleted': true, 'content': '', 'media_url': null}),
      ]);
      _showSuccess(_tr(l10n, 'chat_deleted_all', 'Message supprimé pour tous'));
    } catch (e) {
      _showError(ChatValidators.friendlyError(e));
    }
  }

  // ==========================================================================
  // SÉLECTION MULTIPLE
  // ==========================================================================
  void _enterSelection(String firstId) {
    HapticFeedback.mediumImpact();
    FocusScope.of(context).unfocus();
    setState(() {
      _selectionMode = true;
      _selectedIds
        ..clear()
        ..add(firstId);
    });
  }

  void _exitSelection() {
    if (!mounted) return;
    setState(() {
      _selectionMode = false;
      _selectedIds.clear();
    });
  }

  void _toggleSelection(List<String> ids) {
    HapticFeedback.selectionClick();
    setState(() {
      final allIn = ids.every(_selectedIds.contains);
      if (allIn) {
        _selectedIds.removeAll(ids);
      } else {
        _selectedIds.addAll(ids);
      }
      if (_selectedIds.isEmpty) _selectionMode = false;
    });
  }

  List<ChatMessage> _selectedMessages() {
    final msgs = ref.read(chatMessagesProvider(widget.conversationId));
    return msgs.where((m) => _selectedIds.contains(m.id)).toList();
  }

  void _selectAll() {
    final msgs = ref.read(chatMessagesProvider(widget.conversationId));
    setState(() => _selectedIds.addAll(msgs.where((m) => !m.isExpired).map((m) => m.id)));
  }

  void _copySelected() {
    final l10n = AppLocalizations.of(context);
    final msgs = _selectedMessages()..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final text = msgs.map((m) => chatPlainTextOf(m).trim()).where((t) => t.isNotEmpty).join('\n');
    if (text.isNotEmpty) {
      Clipboard.setData(ClipboardData(text: text));
      _showSuccess(_tr(l10n, 'chat_copied', 'Copié'));
    }
    _exitSelection();
  }

  void _showBulkDeleteSheet() {
    final l10n = AppLocalizations.of(context);
    final msgs = _selectedMessages();
    if (msgs.isEmpty) return;
    final me = _chatService.currentUserId;
    final allDeletable = msgs.every((m) => m.canBeDeletedForAll(me));
    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      backgroundColor: ThixPolicy.card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 10),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: ThixPolicy.border, borderRadius: BorderRadius.circular(4))),
          const SizedBox(height: 12),
          Text('${_tr(l10n, 'chat_delete_n', 'Supprimer')} ${msgs.length} ${_tr(l10n, 'chat_messages_word', 'message(s) ?')}', style: ThixPolicy.titleStyle.copyWith(fontWeight: ThixPolicy.bold, fontSize: 16)),
          const SizedBox(height: 6),
          ListTile(
            leading: const Icon(Icons.person_outline_rounded, color: ThixPolicy.textMain),
            title: Text(_tr(l10n, 'chat_delete_for_me', 'Supprimer pour moi')),
            onTap: () {
              Navigator.pop(ctx);
              _bulkDelete(forAll: false);
            },
          ),
          ListTile(
            enabled: allDeletable,
            leading: Icon(Icons.delete_forever_rounded, color: allDeletable ? ThixPolicy.danger : ThixPolicy.textMuted),
            title: Text(_tr(l10n, 'chat_delete_for_all', 'Supprimer pour tous'), style: TextStyle(color: allDeletable ? ThixPolicy.danger : ThixPolicy.textMuted, fontWeight: FontWeight.w600)),
            subtitle: allDeletable ? null : Text(_tr(l10n, 'chat_bulk_unavailable', 'Disponible si tous les messages sont à vous et récents.')),
            onTap: allDeletable
                ? () {
                    Navigator.pop(ctx);
                    _bulkDelete(forAll: true);
                  }
                : null,
          ),
          ListTile(leading: const Icon(Icons.close_rounded, color: ThixPolicy.textSecondary), title: Text(_tr(l10n, 'common_cancel', 'Annuler')), onTap: () => Navigator.pop(ctx)),
          const SizedBox(height: 6),
        ]),
      ),
    );
  }

  Future<void> _bulkDelete({required bool forAll}) async {
    final l10n = AppLocalizations.of(context);
    final msgs = _selectedMessages();
    final notifier = ref.read(chatMessagesProvider(widget.conversationId).notifier);
    _exitSelection();
    int failed = 0;
    await Future.wait(msgs.map((m) async {
      try {
        if (forAll) {
          await _chatRetry(() => _chatService.deleteMessageForAll(m.id), label: 'bulkDeleteAll');
          notifier.upsertRealtime([_overrideMsg(m, {'is_deleted_for_all': true, 'is_deleted': true, 'content': '', 'media_url': null})]);
        } else {
          await _chatRetry(() => _chatService.deleteMessage(m.id), label: 'bulkDeleteMe');
          notifier.removeLocal(m.id);
        }
      } catch (_) {
        failed++;
      }
    }));
    if (!mounted) return;
    if (failed == 0) {
      _showSuccess(forAll ? _tr(l10n, 'chat_deleted_all', 'Message supprimé pour tous') : _tr(l10n, 'chat_deleted_me', 'Message supprimé pour vous'));
    } else {
      _showWarning('${_tr(l10n, 'chat_bulk_failed', 'Échec pour')} $failed ${_tr(l10n, 'chat_messages_short', 'message(s)')}');
    }
  }

  // ==========================================================================
  // FORWARD
  // ==========================================================================
  void _showForwardSheet(ChatMessage msg) {
    final l10n = AppLocalizations.of(context);
    HapticFeedback.selectionClick();
    final conversations = ref.read(chatListProvider).all.where((c) => c.id != widget.conversationId).toList();
    final selected = <String>{};
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          height: MediaQuery.of(ctx).size.height * 0.65,
          decoration: BoxDecoration(color: ThixPolicy.card, borderRadius: const BorderRadius.vertical(top: Radius.circular(22))),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: ThixPolicy.border, borderRadius: BorderRadius.circular(4))),
            const SizedBox(height: 12),
            Row(children: [
              const Icon(Icons.forward_rounded, color: ThixPolicy.inkDeep),
              const SizedBox(width: 8),
              Expanded(child: Text('${_tr(l10n, 'chat_forward_title', 'Transférer')} (${selected.length}/$_kMaxForward)', style: ThixPolicy.titleStyle.copyWith(fontWeight: ThixPolicy.bold))),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: selected.isEmpty ? ThixPolicy.border : ThixPolicy.inkDeep,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: selected.isEmpty
                    ? null
                    : () async {
                        Navigator.pop(ctx);
                        try {
                          final sent = await _chatRetry(
                            () => _chatService.forwardMessage(originalMessageId: msg.id, targetConversationIds: selected.toList()),
                            label: 'forwardMessage',
                            timeout: _kUploadTimeout,
                          );
                          _showSuccess(_tr(l10n, 'chat_forward_done', 'Transféré à {n} conversation(s)').replaceAll('{n}', '${sent.length}'));
                        } catch (e) {
                          _showError(ChatValidators.friendlyError(e));
                        }
                      },
                child: Text(_tr(l10n, 'chat_send', 'Envoyer')),
              ),
            ]),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: conversations.length,
                itemBuilder: (ctx, i) {
                  final c = conversations[i];
                  final checked = selected.contains(c.id);
                  final avatar = ChatValidators.sanitizeUrl(c.displayAvatar);
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: ThixPolicy.tint,
                      backgroundImage: avatar != null ? CachedNetworkImageProvider(avatar) : null,
                      child: avatar == null ? const Icon(Icons.person, color: ThixPolicy.textSecondary) : null,
                    ),
                    title: Text(ChatValidators.sanitize(c.displayName, maxLength: 60), style: ThixPolicy.labelStyle.copyWith(fontWeight: ThixPolicy.bold)),
                    trailing: Icon(checked ? Icons.check_circle : Icons.radio_button_unchecked, color: checked ? ThixPolicy.inkDeep : ThixPolicy.textMuted),
                    onTap: () => setSheetState(() {
                      if (checked) {
                        selected.remove(c.id);
                      } else if (selected.length < _kMaxForward) {
                        selected.add(c.id);
                      } else {
                        chatSnack(context, _tr(l10n, 'chat_forward_max', 'Maximum 5 destinataires'), ChatSnackKind.warning);
                      }
                    }),
                  );
                },
              ),
            ),
          ]),
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
      final notifier = ref.read(chatMessagesProvider(widget.conversationId).notifier);
      if (msg.isPinned) {
        await _chatRetry(() => _chatService.unpinMessage(msg.id), label: 'unpinMessage');
        notifier.upsertRealtime([_overrideMsg(msg, const {'is_pinned': false})]);
        _showInfo(_tr(l10n, 'chat_unpinned', 'Message désépinglé'));
      } else {
        await _chatRetry(() => _chatService.pinMessage(msg.id, widget.conversationId), label: 'pinMessage');
        notifier.upsertRealtime([_overrideMsg(msg, const {'is_pinned': true})]);
        _showInfo(_tr(l10n, 'chat_pinned', 'Message épinglé'));
      }
      await _loadPinned();
    } catch (e) {
      _showError(ChatValidators.friendlyError(e));
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
    final notifier = ref.read(chatMessagesProvider(widget.conversationId).notifier);
    notifier.upsertRealtime([_overrideMsg(msg, {'is_starred': nowStarred})]);
    try {
      await _chatService.toggleStarMessage(msg.id);
    } catch (e) {
      chatLog('[Chat] ⚠️ toggleStar: $e');
      if (!mounted) return;
      setState(() {
        if (nowStarred) {
          _starredIds.remove(msg.id);
        } else {
          _starredIds.add(msg.id);
        }
      });
      notifier.upsertRealtime([_overrideMsg(msg, {'is_starred': !nowStarred})]);
      _showError(ChatValidators.friendlyError(e));
    }
  }

  void _showStarredSheet() {
    final l10n = AppLocalizations.of(context);
    final msgs = ref.read(chatMessagesProvider(widget.conversationId)).where((m) => _starredIds.contains(m.id)).toList();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        height: MediaQuery.of(ctx).size.height * 0.6,
        decoration: BoxDecoration(color: ThixPolicy.card, borderRadius: const BorderRadius.vertical(top: Radius.circular(22))),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: ThixPolicy.border, borderRadius: BorderRadius.circular(4))),
          const SizedBox(height: 12),
          Row(children: [
            const Icon(Icons.star_rounded, color: ThixPolicy.gold),
            const SizedBox(width: 8),
            Text(_tr(l10n, 'chat_starred_title', 'Messages favoris'), style: ThixPolicy.titleStyle.copyWith(fontWeight: ThixPolicy.bold)),
          ]),
          const SizedBox(height: 8),
          Expanded(
            child: msgs.isEmpty
                ? Center(child: Text(_tr(l10n, 'chat_starred_empty', 'Aucun message favori'), style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.textSecondary)))
                : ListView.builder(
                    itemCount: msgs.length,
                    itemBuilder: (ctx, i) {
                      final m = msgs[i];
                      return ListTile(
                        leading: const Icon(Icons.star_rounded, color: ThixPolicy.gold, size: 18),
                        title: Text(chatPreviewOf(m), maxLines: 2, overflow: TextOverflow.ellipsis),
                        subtitle: Text(DateFormat('dd/MM/yyyy HH:mm').format(m.createdAt.toLocal()), style: ThixPolicy.microStyle.copyWith(color: ThixPolicy.textMuted)),
                        onTap: () {
                          Navigator.pop(ctx);
                          _scrollToMessage(m.id);
                        },
                      );
                    },
                  ),
          ),
        ]),
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
              .where((m) => chatSearchableText(m).toLowerCase().contains(q) || (m.mediaName ?? '').toLowerCase().contains(q))
              .map((m) => m.id)
              .toList();
          _searchPos = _searchMatches.isEmpty ? -1 : 0;
        }
      });
    });
  }

  String get _searchHighlightId => (_searchPos >= 0 && _searchPos < _searchMatches.length) ? _searchMatches[_searchPos] : '';

  void _searchMove(int delta) {
    if (_searchMatches.isEmpty) return;
    setState(() {
      _searchPos = (_searchPos + delta) % _searchMatches.length;
      if (_searchPos < 0) _searchPos = _searchMatches.length - 1;
    });
    _scrollToMessage(_searchHighlightId);
  }

  Future<void> _searchRemote() async {
    final q = _searchCtrl.text.trim();
    if (q.length < 3) return;
    final l10n = AppLocalizations.of(context);
    try {
      final results = await _chatRetry(() => _chatService.searchInConversation(widget.conversationId, q, limit: 30), label: 'searchInConversation');
      if (!mounted) return;
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (ctx) => Container(
          height: MediaQuery.of(ctx).size.height * 0.6,
          decoration: BoxDecoration(color: ThixPolicy.card, borderRadius: const BorderRadius.vertical(top: Radius.circular(22))),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: ThixPolicy.border, borderRadius: BorderRadius.circular(4))),
            const SizedBox(height: 12),
            Text('${_tr(l10n, 'chat_search_results', 'Résultats')} : ${results.length}', style: ThixPolicy.titleStyle.copyWith(fontWeight: ThixPolicy.bold)),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: results.length,
                itemBuilder: (ctx, i) {
                  final m = results[i];
                  return ListTile(
                    title: Text(chatPreviewOf(m), maxLines: 2, overflow: TextOverflow.ellipsis),
                    subtitle: Text(DateFormat('dd/MM/yyyy HH:mm').format(m.createdAt.toLocal()), style: ThixPolicy.microStyle.copyWith(color: ThixPolicy.textMuted)),
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
          ]),
        ),
      );
    } catch (e) {
      _showError(ChatValidators.friendlyError(e));
    }
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
  static final RegExp _mentionRe = RegExp(r'@([A-Za-zÀ-ÖØ-öø-ÿ0-9_.]{0,20})$');

  void _onMentionQueryChanged(String text) {
    final match = _mentionRe.firstMatch(text);
    if (match == null || _groupMembers.isEmpty) {
      if (_mentionSuggestions.isNotEmpty) setState(() => _mentionSuggestions = <GroupMember>[]);
      return;
    }
    final q = (match.group(1) ?? '').toLowerCase();
    final me = _chatService.currentUserId;
    final sugg = _groupMembers.where((m) => m.userId != me && m.displayName.toLowerCase().contains(q)).take(4).toList();
    setState(() => _mentionSuggestions = sugg);
  }

  void _insertMention(GroupMember member) {
    HapticFeedback.selectionClick();
    final text = _inputController.text;
    final match = _mentionRe.firstMatch(text);
    if (match == null) return;
    final prefix = text.substring(0, match.start);
    _inputController.text = '$prefix@${member.displayName} ';
    _inputController.selection = TextSelection.fromPosition(TextPosition(offset: _inputController.text.length));
    if (!_mentionedUserIds.contains(member.userId)) _mentionedUserIds.add(member.userId);
    setState(() => _mentionSuggestions = <GroupMember>[]);
  }

  // ==========================================================================
  // VIEW ONCE / INFO / EXPORT
  // ==========================================================================
  void _onViewOnceOpened(ChatMessage msg) {
    if (_viewedOnceIds.contains(msg.id)) return;
    setState(() => _viewedOnceIds.add(msg.id));
    unawaited(_fireAndForget(() => _chatService.markViewOnceAsSeen(msg.id)));
    ref.read(chatMessagesProvider(widget.conversationId).notifier).upsertRealtime([_overrideMsg(msg, const {'has_been_viewed': true})]);
  }

  void _showMessageInfo(ChatMessage msg) {
    final l10n = AppLocalizations.of(context);
    final fwd = ChatValidators.sanitize(msg.forwardedFromSenderName, maxLength: 60);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ThixPolicy.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(_tr(l10n, 'chat_info_title', 'Informations du message'), style: ThixPolicy.h3Style.copyWith(fontWeight: ThixPolicy.bold, fontSize: 16)),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          _infoRow(_tr(l10n, 'chat_info_sender', 'Expéditeur'), ChatValidators.sanitize(msg.senderName, maxLength: 60)),
          _infoRow(_tr(l10n, 'chat_info_date', 'Date'), DateFormat('dd/MM/yyyy HH:mm:ss').format(msg.createdAt.toLocal())),
          if (msg.senderId == _chatService.currentUserId)
            _infoRow(_tr(l10n, 'chat_info_status', 'Statut'),
                msg.isRead ? _tr(l10n, 'chat_info_read', 'Lu') : (msg.isDelivered ? _tr(l10n, 'chat_info_delivered', 'Distribué') : _tr(l10n, 'chat_info_sent', 'Envoyé'))),
          if (msg.hasMedia) _infoRow(_tr(l10n, 'chat_info_media', 'Média'), '${ChatValidators.sanitize(msg.mediaName, maxLength: 40)} (${(msg.mediaSize ?? 0) ~/ 1024} Ko)'),
          if (msg.isForwarded) _infoRow(_tr(l10n, 'chat_info_forwarded', 'Transféré depuis'), fwd.isEmpty ? '-' : fwd),
          if (msg.isEphemeral) _infoRow(_tr(l10n, 'chat_info_ephemeral', 'Éphémère'), '${msg.ephemeralDuration ?? 0}s'),
          if (msg.isViewOnce) _infoRow('View once', msg.hasBeenViewed ? _tr(l10n, 'chat_info_opened', 'Ouvert') : _tr(l10n, 'chat_info_pending', 'En attente')),
          if (msg.reminderAt != null) _infoRow(_tr(l10n, 'chat_info_reminder', 'Rappel'), DateFormat('dd/MM HH:mm').format(msg.reminderAt!.toLocal())),
          _infoRow('ID', msg.id.length > 12 ? '${msg.id.substring(0, 8)}…' : msg.id),
        ]),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(_tr(l10n, 'common_close', 'Fermer')))],
      ),
    );
  }

  Widget _infoRow(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 90, child: Text(label, style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.textMuted))),
          Expanded(child: Text(value, style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.textMain, fontWeight: FontWeight.w600))),
        ]),
      );

  String _csvCell(String raw) {
    var s = raw.replaceAll(';', ',').replaceAll('\n', ' ').replaceAll('\r', ' ');
    if (s.isNotEmpty && '=+-@'.contains(s[0])) s = "'$s";
    return s;
  }

  Future<void> _exportConversation() async {
    if (!_isAgent) return;
    final l10n = AppLocalizations.of(context);
    final msgs = ref.read(chatMessagesProvider(widget.conversationId));
    final sb = StringBuffer('date;expediteur;contenu\n');
    for (final m in msgs.reversed) {
      if (m.isViewOnce || m.isExpired) continue;
      sb.writeln('${DateFormat('yyyy-MM-dd HH:mm').format(m.createdAt.toLocal())};${_csvCell(m.senderName)};${_csvCell(isProductRefMessage(m) ? chatPreviewOf(m) : m.content)}');
    }
    await Clipboard.setData(ClipboardData(text: sb.toString()));
    _showSuccess(_tr(l10n, 'chat_export_done', 'Conversation copiée (CSV)'));
  }

  // ==========================================================================
  // APPELS
  // ==========================================================================
  Future<void> _startCall(CallType type) async {
    final l10n = AppLocalizations.of(context);
    if (!_canWrite) {
      _showError(_tr(l10n, 'chat_call_inactive', 'Connexion inactive avec ce contact'));
      return;
    }
    final other = ref.read(userProfileProvider(_otherId)).valueOrNull;
    final otherAllows = other == null || other['calls_enabled'] != false;
    final me = ref.read(userProfileProvider(_chatService.currentUserId)).valueOrNull;
    final myAllows = _myCallsOverride ?? (me == null || me['calls_enabled'] != false);
    if (!otherAllows || !myAllows) {
      _showWarning(_tr(l10n, 'chat_calls_disabled', 'Les appels sont désactivés pour cette conversation'));
      return;
    }
    HapticFeedback.mediumImpact();
    final hasMic = await chatCheckPermission(context, Permission.microphone, _tr(l10n, 'chat_mic_call_disclosure', 'Le micro est nécessaire pour les appels.'));
    if (!hasMic || !mounted) return;
    if (type == CallType.video) {
      final hasCam = await chatCheckPermission(context, Permission.camera, _tr(l10n, 'chat_cam_call_disclosure', 'La caméra est nécessaire pour les appels vidéo.'));
      if (!hasCam || !mounted) return;
    }
    final myId = _chatService.currentUserId;
    final otherId = _otherId;
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

  void _showPhotoPager(List<ChatMessage> imgs, int start) {
    Navigator.of(context).push(MaterialPageRoute(fullscreenDialog: true, builder: (_) => PhotoPager(images: imgs, initialIndex: start)));
  }

  // ==========================================================================
  // ENVOI OPTIMISTE (file d'attente ordonnée)
  // ==========================================================================
  void _enqueue(PendingMessage pm) {
    if (!mounted) return;
    setState(() => _pending.add(pm));
    _scrollToBottom();
    _queue = _queue.then((_) => _runPending(pm));
  }

  Future<void> _runPending(PendingMessage pm) async {
    if (!mounted) return;
    if (pm.failed) setState(() => pm.failed = false);
    try {
      final msg = await pm.job();
      if (!mounted) return;
      if (msg != null) ref.read(chatMessagesProvider(widget.conversationId).notifier).upsertRealtime([msg]);
      setState(() => _pending.removeWhere((e) => e.localId == pm.localId));
    } catch (e) {
      chatLog('[Chat] ❌ send failed: $e');
      if (!mounted) return;
      setState(() => pm.failed = true);
      HapticFeedback.lightImpact();
    }
  }

  void _retryPending(PendingMessage pm) {
    if (!pm.failed) return;
    HapticFeedback.selectionClick();
    setState(() => pm.failed = false);
    _queue = _queue.then((_) => _runPending(pm));
  }

  void _cancelPending(PendingMessage pm) {
    HapticFeedback.selectionClick();
    setState(() => _pending.removeWhere((e) => e.localId == pm.localId));
  }

  Future<Uint8List?> _bytesOf(PlatformFile f) async {
    if (f.bytes != null) return Uint8List.fromList(f.bytes!);
    if (f.path != null && !kIsWeb) return File(f.path!).readAsBytes();
    return null;
  }

  void _onSubmit(ChatInputPayload payload) {
    final l10n = AppLocalizations.of(context);
    if (!_canWrite) {
      _showError(_tr(l10n, 'chat_send_inactive', 'Connexion inactive : envoi impossible'));
      return;
    }

    if (_editingMessageId.isNotEmpty) {
      final msgs = ref.read(chatMessagesProvider(widget.conversationId));
      final target = msgs.where((m) => m.id == _editingMessageId).toList();
      if (target.isNotEmpty) {
        _applyEdit(target.first, payload.text);
        return;
      }
      _cancelEdit();
    }

    final text = ChatValidators.sanitize(payload.text, maxLength: kChatMaxMessageLength);
    final hasAudio = payload.audioBytes != null;
    if (text.isEmpty && payload.files.isEmpty && !hasAudio) return;

    final now = DateTime.now();
    if (_lastSendAt != null && now.difference(_lastSendAt!).inMilliseconds < _kSendThrottleMs) return;
    _lastSendAt = now;

    _isTyping = false;
    _sendTypingStatus(false);
    HapticFeedback.mediumImpact();

    final convId = widget.conversationId;
    final replyId = _replyToId.isEmpty ? null : _replyToId;
    final mentions = List<String>.from(_mentionedUserIds);
    final eph = _isEphemeral;
    final ephDur = _ephemeralDuration;

    // ⚡ UI libérée immédiatement (comme WhatsApp)
    _draftTimer?.cancel();
    _restoringDraft = true;
    _inputController.clear();
    _restoringDraft = false;
    unawaited(_persistDraft(''));
    setState(() {
      _replyToId = '';
      _mentionedUserIds.clear();
      _isInternalNoteMode = false;
      _isEphemeral = false;
      _ephemeralDuration = null;
    });

    if (hasAudio) {
      final audio = payload.audioBytes!;
      final ext = payload.audioExt.isEmpty ? (kIsWeb ? 'webm' : 'm4a') : payload.audioExt;
      final dur = payload.audioDuration;
      _enqueue(PendingMessage(
        kind: 'audio',
        label: '🎤 ${_tr(l10n, 'chat_voice_message', 'Message vocal')} (${dur}s)',
        job: () async {
          if (kIsWeb) {
            final url = await _chatRetry(() => _chatService.uploadFileWithUniqueName('chat-media', 'messages/$convId', audio, ext), label: 'uploadAudio', timeout: _kUploadTimeout);
            if (url == null) throw StateError('Upload audio échoué');
            return _chatRetry(
              () => _chatService.sendMessage(
                conversationId: convId,
                content: '🎤 Message audio (${dur}s)',
                mediaUrl: url,
                mediaType: 'audio',
                mediaName: 'audio_${DateTime.now().millisecondsSinceEpoch}.$ext',
                mediaSize: audio.length,
                isEphemeral: eph,
                ephemeralDuration: ephDur,
                replyToId: replyId,
              ),
              label: 'sendAudioWeb',
            );
          }
          return _chatRetry(
            () => _chatService.sendAudioMessage(
              conversationId: convId,
              audioData: audio,
              duration: dur,
              isEphemeral: eph,
              ephemeralDuration: ephDur,
              replyToId: replyId,
            ),
            label: 'sendAudio',
            timeout: _kUploadTimeout,
          );
        },
      ));
      return;
    }

    if (payload.files.isNotEmpty) {
      var first = true;
      for (final f in payload.files) {
        if (!ChatValidators.isValidFileSize(f.size) || !ChatValidators.isAllowedExtension(f.extension)) {
          _showError('${_tr(l10n, 'chat_file_rejected', 'Fichier refusé (taille ou type) :')} ${ChatValidators.sanitize(f.name, maxLength: 40)}');
          continue;
        }
        _queueFile(
          f,
          caption: first ? text : '',
          replyId: first ? replyId : null,
          mentions: mentions,
          eph: eph,
          ephDur: ephDur,
          viewOnce: payload.viewOnce,
        );
        first = false;
      }
      if (first && text.isNotEmpty) _queueText(text, replyId, mentions, eph, ephDur);
      return;
    }

    _queueText(text, replyId, mentions, eph, ephDur);
  }

  void _queueText(String text, String? replyId, List<String> mentions, bool eph, int? ephDur) {
    final convId = widget.conversationId;
    _enqueue(PendingMessage(
      kind: 'text',
      label: text,
      job: () => _chatRetry(
        () => _chatService.sendMessage(
          conversationId: convId,
          content: text,
          replyToId: replyId,
          isEphemeral: eph,
          ephemeralDuration: eph ? ephDur : null,
          mentionedUserIds: mentions,
        ),
        label: 'sendText',
      ),
    ));
  }

  void _queueFile(
    PlatformFile f, {
    required String caption,
    required String? replyId,
    required List<String> mentions,
    required bool eph,
    required int? ephDur,
    required bool viewOnce,
  }) {
    final convId = widget.conversationId;
    final ext = (f.extension ?? '').toLowerCase();
    final mediaType = ChatValidators.getMediaType(ext);
    final isImg = mediaType == 'image';
    final upExt = ext.isEmpty ? (isImg ? 'jpg' : 'bin') : ext;
    _enqueue(PendingMessage(
      kind: mediaType,
      label: ChatValidators.sanitize(f.name, maxLength: 50),
      previewBytes: isImg && f.bytes != null ? Uint8List.fromList(f.bytes!) : null,
      job: () async {
        final bytes = await _bytesOf(f);
        if (bytes == null) throw StateError('Fichier illisible');
        final url = await _chatRetry(() => _chatService.uploadFileWithUniqueName('chat-media', 'messages/$convId', bytes, upExt), label: 'uploadFile', timeout: _kUploadTimeout);
        if (url == null) throw StateError('Upload échoué');
        return _chatRetry(
          () => _chatService.sendMessage(
            conversationId: convId,
            content: caption.isNotEmpty ? caption : f.name,
            mediaUrl: url,
            mediaType: mediaType,
            mediaName: f.name,
            mediaSize: f.size,
            isEphemeral: eph,
            ephemeralDuration: ephDur,
            isViewOnce: isImg && viewOnce,
            mentionedUserIds: mentions,
            replyToId: replyId,
          ),
          label: 'sendFile',
        );
      },
    ));
  }

  Future<void> _sendSticker(Uint8List bytes) async {
    final convId = widget.conversationId;
    final ext = ChatValidators.extFromBytes(bytes, 'png');
    _enqueue(PendingMessage(
      kind: 'sticker',
      label: 'Sticker',
      previewBytes: bytes,
      job: () async {
        final url = await _chatRetry(() => _chatService.uploadFileWithUniqueName('chat-media', 'stickers/$convId', bytes, ext), label: 'uploadSticker', timeout: _kUploadTimeout);
        if (url == null) throw StateError('Upload sticker échoué');
        return _chatRetry(
          () => _chatService.sendMessage(conversationId: convId, content: '', mediaUrl: url, mediaType: 'sticker', mediaName: 'sticker.$ext', mediaSize: bytes.length),
          label: 'sendSticker',
        );
      },
    ));
  }

  // ==========================================================================
  // DIVERS
  // ==========================================================================
  void _escalateConversation() {
    HapticFeedback.mediumImpact();
    context.pushNamed('chatEscalate', pathParameters: {'conversationId': widget.conversationId}, queryParameters: {'agentId': _chatService.currentUserId, 'agentName': 'Agent'});
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

  void _showSuccess(String m) => chatSnack(context, m, ChatSnackKind.success);
  void _showError(String m) {
    HapticFeedback.lightImpact();
    chatSnack(context, m, ChatSnackKind.error);
  }

  void _showWarning(String m) => chatSnack(context, m, ChatSnackKind.warning);
  void _showInfo(String m) => chatSnack(context, m, ChatSnackKind.info);

  // ==========================================================================
  // PRÉSENCE
  // ==========================================================================
  Future<void> _getParticipantInfo() async {
    if (widget.conversation.isGroup) return;
    final otherId = _otherId;
    if (otherId.isEmpty) return;
    try {
      final pr = await _chatRetry(() => _chatService.getUserPresence(otherId), label: 'getUserPresence');
      if (mounted) setState(() => _otherParticipant = pr);
    } catch (e) {
      chatLog('[Chat] ⚠️ Get participant info error: $e');
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
    return '${_tr(l10n, 'chat_seen', 'Vu')} ${_formatLastSeen(lastSeen.toLocal())}';
  }

  bool get _isOnline {
    final pr = _otherParticipant;
    if (pr == null || pr.status != 'online') return false;
    final lastSeen = pr.lastSeenAt;
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

  String _replyPreview(List<ChatMessage> messages, Map<String, int> idIndex) {
    final i = idIndex[_replyToId];
    if (i == null) return '';
    return ChatValidators.sanitize(chatPreviewOf(messages[i]), maxLength: 100);
  }

  // ==========================================================================
  // BUILD
  // ==========================================================================
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final messages = ref.watch(chatMessagesProvider(widget.conversationId));
    final msgNotifier = ref.read(chatMessagesProvider(widget.conversationId).notifier);
    final visible = messages.where((m) => !m.isExpired).toList();
    final displayItems = _buildChatDisplayItems(visible);
    _displayIds = displayItems.map((e) => e.messages.first.id).toList();
    final idIndex = <String, int>{for (var i = 0; i < visible.length; i++) visible[i].id: i};
    final currentUid = _chatService.currentUserId;

    final bool marketByContent = visible.any(isProductRefMessage);
    if (marketByContent != _marketByContent) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _marketByContent = marketByContent);
      });
    }

    if (!_unreadAnchorDone && messages.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _anchorFirstUnread(messages));
      _scheduleRemindersFor(messages);
    }

    // Appels : visibles seulement si MOI et L'AUTRE les autorisent
    bool myCalls = true;
    bool otherCalls = true;
    if (!widget.conversation.isGroup) {
      final myProfile = currentUid.isEmpty ? null : ref.watch(userProfileProvider(currentUid)).valueOrNull;
      myCalls = _myCallsOverride ?? (myProfile == null || myProfile['calls_enabled'] != false);
      final oid = _otherId;
      final otherProfile = oid.isEmpty ? null : ref.watch(userProfileProvider(oid)).valueOrNull;
      otherCalls = otherProfile == null || otherProfile['calls_enabled'] != false;
    }
    final callsVisible = !widget.conversation.isGroup && myCalls && otherCalls;

    final int firstUnreadIdx = _firstUnreadId.isEmpty ? -1 : displayItems.indexWhere((it) => it.messages.first.id == _firstUnreadId);
    final pendingCount = _pending.length;
    final loading = msgNotifier.loadingMore;

    return PopScope(
      canPop: !_selectionMode,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _selectionMode) _exitSelection();
      },
      child: Scaffold(
        backgroundColor: ThixPolicy.surfaceSoft,
        appBar: _selectionMode ? _buildSelectionAppBar(l10n) : _buildAppBar(l10n, callsVisible, myCalls),
        body: Stack(children: [
          Positioned.fill(child: RepaintBoundary(child: _buildWallpaper())),
          Column(children: [
            if (_pinnedMessages.isNotEmpty && !_pinnedBarClosed && !_selectionMode) _buildPinnedBar(l10n),
            if (_searchActive && !_selectionMode) _buildSearchBar(l10n),
            Expanded(
              child: Stack(children: [
                ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  cacheExtent: 900,
                  addAutomaticKeepAlives: false,
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                  itemCount: pendingCount + displayItems.length + (loading ? 1 : 0),
                  itemBuilder: (ctx, i) {
                    if (i < pendingCount) {
                      final pm = _pending[pendingCount - 1 - i];
                      return PendingBubble(key: ValueKey(pm.localId), message: pm, onRetry: () => _retryPending(pm), onCancel: () => _cancelPending(pm));
                    }
                    final di = i - pendingCount;
                    if (di == displayItems.length) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: ThixPolicy.inkDeep)),
                        ),
                      );
                    }
                    return _buildListItem(di, displayItems, visible, idIndex, currentUid, firstUnreadIdx, l10n);
                  },
                ),
                if (_otherUserTyping) Positioned(bottom: 10, left: 16, child: TypingPill(l10n: l10n)),
                if (_showScrollDown && !_selectionMode)
                  Positioned(right: 12, bottom: 12, child: ChatScrollDownButton(count: _newWhileScrolled, onTap: _scrollToBottom)),
                if (_showJumpUnread && _firstUnreadId.isNotEmpty)
                  Positioned(
                    top: 8,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Material(
                        color: ThixPolicy.inkDeep,
                        borderRadius: BorderRadius.circular(20),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: () {
                            setState(() => _showJumpUnread = false);
                            _scrollToMessage(_firstUnreadId);
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              const Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 14),
                              const SizedBox(width: 6),
                              Text(_tr(l10n, 'chat_jump_unread', 'Premiers messages non lus'), style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                            ]),
                          ),
                        ),
                      ),
                    ),
                  ),
              ]),
            ),
            if (_editingMessageId.isNotEmpty && !_selectionMode) _buildEditBanner(l10n),
            if (_replyToId.isNotEmpty && !_selectionMode)
              ReplyBanner(
                text: _replyPreview(visible, idIndex),
                onClose: () {
                  HapticFeedback.selectionClick();
                  setState(() => _replyToId = '');
                },
              ),
            if (_mentionSuggestions.isNotEmpty && !_selectionMode) _buildMentionSuggestions(),
            if (_selectionMode)
              const SizedBox.shrink()
            else if (_canWrite)
              ChatInputBar(
                controller: _inputController,
                focusNode: _inputFocus,
                isEditing: _editingMessageId.isNotEmpty,
                isAgent: _isAgent,
                isInternalNoteMode: _isInternalNoteMode,
                isEphemeral: _isEphemeral,
                onSubmit: _onSubmit,
                onSendSticker: _sendSticker,
                onCancelEdit: _cancelEdit,
                onEphemeralTap: _showEphemeralTimerDialog,
                onProtectedTap: _showPasswordProtectDialog,
                onToggleInternalNote: _toggleInternalNoteMode,
              )
            else
              _buildBlockedBanner(l10n),
          ]),
        ]),
      ),
    );
  }

  // ==========================================================================
  // ITEM DE LISTE
  // ==========================================================================
  Widget _buildListItem(
    int di,
    List<_ChatListItem> displayItems,
    List<ChatMessage> visible,
    Map<String, int> idIndex,
    String currentUid,
    int firstUnreadIdx,
    AppLocalizations l10n,
  ) {
    final item = displayItems[di];
    final firstMsg = item.messages.first;
    final isOwn = firstMsg.senderId == currentUid;
    final type = '${firstMsg.mediaType ?? ''}';
    final ids = item.messages.map((e) => e.id).toList();

    Widget content;
    if (item.messages.length > 1) {
      content = ImageGroupBubble(images: item.messages, isOwn: isOwn, onOpenGallery: (list, idx) => _showPhotoPager(list, idx));
    } else if (type == 'call_audio' || type == 'call_video') {
      content = CallBubble(message: firstMsg, isOwn: isOwn, onCallback: () => _startCall(type == 'call_video' ? CallType.video : CallType.audio));
    } else if (type == 'system_screenshot') {
      final who = isOwn ? _tr(l10n, 'chat_you', 'Vous avez') : '${ChatValidators.sanitize(firstMsg.senderName, maxLength: 30)} ${_tr(l10n, 'chat_has', 'a')}';
      content = SystemBubble(text: '$who ${_tr(l10n, 'chat_screenshot_system', 'fait une capture d’écran')}');
    } else if (firstMsg.isViewOnce && (firstMsg.hasBeenViewed || _viewedOnceIds.contains(firstMsg.id))) {
      content = ViewOnceOpenedBubble(isOwn: isOwn, isSender: isOwn);
    } else {
      content = _buildSingleBubble(firstMsg, isOwn, visible, idIndex);
    }

    final reminder = firstMsg.reminderAt;
    if (reminder != null && reminder.isAfter(DateTime.now())) {
      content = Column(
        crossAxisAlignment: isOwn ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Container(
            margin: EdgeInsets.only(left: isOwn ? 40 : 40, right: isOwn ? 8 : 40, bottom: 2),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: ThixPolicy.gold.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.notifications_active_rounded, size: 11, color: ThixPolicy.gold),
              const SizedBox(width: 4),
              Text(DateFormat('dd/MM HH:mm').format(reminder.toLocal()), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: ThixPolicy.gold)),
            ]),
          ),
          content,
        ],
      );
    }

    if (_searchHighlightId.isNotEmpty && firstMsg.id == _searchHighlightId) {
      content = Container(
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), boxShadow: [BoxShadow(color: ThixPolicy.gold.withOpacity(0.55), blurRadius: 10, spreadRadius: 1)]),
        child: content,
      );
    }

    if (_selectionMode) {
      content = _SelectableRow(selected: ids.every(_selectedIds.contains), onTap: () => _toggleSelection(ids), child: content);
    } else {
      if (type != 'system_screenshot') {
        content = _SwipeActions(
          onReply: () => _setReply(firstMsg),
          onMore: () => _showMessageMenu(firstMsg, l10n),
          child: content,
        );
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: content,
    );
  }

// ==========================================================================
// BULLE UNIQUE
// ==========================================================================
Widget _buildSingleBubble(ChatMessage msg, bool isOwn, List<ChatMessage> visible, Map<String, int> idIndex) {
  // Récupère le message de réponse complet (pas juste le texte)
  final replyMsg = _replyToId.isEmpty
      ? null
      : (idIndex.containsKey(_replyToId) ? visible[idIndex[_replyToId]!] : null);

  return ChatMessageBubble(
    key: _keyFor(msg.id),
    message: msg,
    isOwn: isOwn,
    replyToMessage: replyMsg,
    onViewOnceOpened: () => _onViewOnceOpened(msg),
    showSender: !isOwn,
    senderName: msg.senderName,
    senderAvatarUrl: _groupById[msg.senderId]?.avatarUrl ?? msg.senderAvatarUrl,
    // Le swipe (reply/more) est géré par _SwipeActions dans _buildListItem
    // La galerie est gérée par ImageGroupBubble pour les groupes d'images
  );
}

  // ==========================================================================
  // MENU CONTEXTUEL D'UN MESSAGE
  // ==========================================================================
  void _showMessageMenu(ChatMessage msg, AppLocalizations l10n) {
    final me = _chatService.currentUserId;
    final isOwn = msg.senderId == me;
    final canEdit = _canEdit(msg);
    final canDeleteAll = msg.canBeDeletedForAll(me);
    final canReply = !msg.isDeleted && !msg.isDeletedForAll;
    final canForward = !msg.isDeleted && !msg.isDeletedForAll && !msg.isViewOnce;

    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      backgroundColor: ThixPolicy.card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: ThixPolicy.border, borderRadius: BorderRadius.circular(4))),
            const SizedBox(height: 10),
            if (canReply)
              ListTile(
                leading: const Icon(Icons.reply_rounded, color: ThixPolicy.inkDeep),
                title: Text(_tr(l10n, 'chat_reply', 'Répondre')),
                onTap: () {
                  Navigator.pop(ctx);
                  _setReply(msg);
                },
              ),
            if (canForward)
              ListTile(
                leading: const Icon(Icons.forward_rounded, color: ThixPolicy.inkDeep),
                title: Text(_tr(l10n, 'chat_forward', 'Transférer')),
                onTap: () {
                  Navigator.pop(ctx);
                  _showForwardSheet(msg);
                },
              ),
            if (!msg.isDeleted && !msg.isDeletedForAll && !msg.isViewOnce)
              ListTile(
                leading: Icon(_starredIds.contains(msg.id) ? Icons.star_rounded : Icons.star_outline_rounded, color: ThixPolicy.gold),
                title: Text(_starredIds.contains(msg.id) ? _tr(l10n, 'chat_unstar', 'Retirer des favoris') : _tr(l10n, 'chat_star', 'Ajouter aux favoris')),
                onTap: () {
                  Navigator.pop(ctx);
                  _toggleStar(msg);
                },
              ),
            if (!msg.isDeleted && !msg.isDeletedForAll && !msg.isViewOnce)
              ListTile(
                leading: Icon(msg.isPinned ? Icons.push_pin_rounded : Icons.push_pin_outlined, color: ThixPolicy.inkDeep),
                title: Text(msg.isPinned ? _tr(l10n, 'chat_unpin', 'Désépingler') : _tr(l10n, 'chat_pin', 'Épingler')),
                onTap: () {
                  Navigator.pop(ctx);
                  _togglePin(msg);
                },
              ),
            if (!msg.isDeleted && !msg.isDeletedForAll)
              ListTile(
                leading: const Icon(Icons.notifications_active_outlined, color: ThixPolicy.gold),
                title: Text(_tr(l10n, 'chat_remind', 'Me rappeler')),
                onTap: () {
                  Navigator.pop(ctx);
                  _showRemindSheet(msg);
                },
              ),
            if (canEdit)
              ListTile(
                leading: const Icon(Icons.edit_rounded, color: ThixPolicy.inkDeep),
                title: Text(_tr(l10n, 'chat_edit', 'Modifier')),
                onTap: () {
                  Navigator.pop(ctx);
                  _startEdit(msg);
                },
              ),
            if (canForward)
              ListTile(
                leading: const Icon(Icons.copy_rounded, color: ThixPolicy.inkDeep),
                title: Text(_tr(l10n, 'chat_copy', 'Copier')),
                onTap: () {
                  Navigator.pop(ctx);
                  final text = chatPlainTextOf(msg).trim();
                  if (text.isNotEmpty) {
                    Clipboard.setData(ClipboardData(text: text));
                    _showSuccess(_tr(l10n, 'chat_copied', 'Copié'));
                  }
                },
              ),
            if (!msg.isExpired)
              ListTile(
                leading: const Icon(Icons.info_outline_rounded, color: ThixPolicy.textSecondary),
                title: Text(_tr(l10n, 'chat_info', 'Infos du message')),
                onTap: () {
                  Navigator.pop(ctx);
                  _showMessageInfo(msg);
                },
              ),
            if (!msg.isExpired)
              ListTile(
                leading: Icon(Icons.delete_outline_rounded, color: ThixPolicy.danger),
                title: Text(_tr(l10n, 'chat_delete', 'Supprimer')),
                onTap: () {
                  Navigator.pop(ctx);
                  _showDeleteOptions(msg);
                },
              ),
          ]),
        ),
      ),
    );
  }

  // ==========================================================================
  // BARRE ÉPINGLÉS
  // ==========================================================================
  Widget _buildPinnedBar(AppLocalizations l10n) {
    if (_pinnedMessages.isEmpty) return const SizedBox.shrink();
    final msg = _pinnedMessages[_pinnedCursor % _pinnedMessages.length];
    return GestureDetector(
      onTap: () => _scrollToMessage(msg.id),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(color: ThixPolicy.card, border: Border(bottom: BorderSide(color: ThixPolicy.border))),
        child: Row(children: [
          const Icon(Icons.push_pin_rounded, size: 18, color: ThixPolicy.inkDeep),
          const SizedBox(width: 8),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                ChatValidators.sanitize(msg.senderName, maxLength: 40),
                style: ThixPolicy.captionStyle.copyWith(fontWeight: FontWeight.w700, color: ThixPolicy.textMain, fontSize: 11),
              ),
              Text(
                chatPreviewOf(msg),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.textSecondary, fontSize: 12),
              ),
            ]),
          ),
          if (_pinnedMessages.length > 1)
            Row(mainAxisSize: MainAxisSize.min, children: [
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.keyboard_arrow_up_rounded, size: 18),
                onPressed: () => setState(() => _pinnedCursor = (_pinnedCursor - 1 + _pinnedMessages.length) % _pinnedMessages.length),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
                onPressed: () => setState(() => _pinnedCursor = (_pinnedCursor + 1) % _pinnedMessages.length),
              ),
            ]),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.close_rounded, size: 18),
            onPressed: () => setState(() => _pinnedBarClosed = true),
          ),
        ]),
      ),
    );
  }

  // ==========================================================================
  // BARRES UI
  // ==========================================================================
  Widget _buildSearchBar(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(color: ThixPolicy.card, border: Border(bottom: BorderSide(color: ThixPolicy.border))),
      child: Row(children: [
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
          icon: const Icon(Icons.keyboard_arrow_up_rounded, color: ThixPolicy.inkDeep),
          onPressed: () => _searchMove(-1),
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: ThixPolicy.inkDeep),
          onPressed: () => _searchMove(1),
        ),
      ]),
    );
  }

  Widget _buildEditBanner(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(color: ThixPolicy.tint, border: Border(top: BorderSide(color: ThixPolicy.inkDeep.withOpacity(0.2)))),
      child: Row(children: [
        const Icon(Icons.edit_rounded, size: 16, color: ThixPolicy.inkDeep),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            _tr(l10n, 'chat_editing', 'Modification du message (fenêtre $_kEditWindowMinutes min)'),
            style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.inkDeep, fontWeight: FontWeight.w700),
          ),
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.close_rounded, size: 18, color: ThixPolicy.textSecondary),
          onPressed: _cancelEdit,
        ),
      ]),
    );
  }

  Widget _buildMentionSuggestions() {
    return Container(
      color: ThixPolicy.card,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: _mentionSuggestions.map((m) {
          final av = ChatValidators.sanitizeUrl(m.avatarUrl);
          return ListTile(
            dense: true,
            leading: CircleAvatar(
              radius: 14,
              backgroundColor: ThixPolicy.tint,
              backgroundImage: av != null ? CachedNetworkImageProvider(av) : null,
              child: av == null ? const Icon(Icons.person, size: 14, color: ThixPolicy.textSecondary) : null,
            ),
            title: Text('@${ChatValidators.sanitize(m.displayName, maxLength: 40)}',
                style: ThixPolicy.labelStyle.copyWith(fontWeight: ThixPolicy.bold, fontSize: 13)),
            onTap: () => _insertMention(m),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildBlockedBanner(AppLocalizations l10n) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(color: ThixPolicy.card, border: Border(top: BorderSide(color: ThixPolicy.border))),
      child: SafeArea(
        top: false,
        child: Column(children: [
          const Icon(Icons.person_off_rounded, color: ThixPolicy.textSecondary, size: 32),
          const SizedBox(height: 12),
          Text(_tr(l10n, 'chat_cannot_reply', 'Vous ne pouvez pas répondre'),
              style: ThixPolicy.labelStyle.copyWith(color: ThixPolicy.textMain, fontWeight: ThixPolicy.bold, fontSize: 14),
              textAlign: TextAlign.center),
          const SizedBox(height: 4),
          Text(_tr(l10n, 'chat_connection_interrupted', 'Connexion interrompue avec ce contact'),
              style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.textSecondary, fontSize: 13), textAlign: TextAlign.center),
        ]),
      ),
    );
  }

  // ==========================================================================
  // APP BARS
  // ==========================================================================
  PreferredSizeWidget _buildSelectionAppBar(AppLocalizations l10n) {
    return AppBar(
      backgroundColor: ThixPolicy.card,
      elevation: 0,
      scrolledUnderElevation: 2,
      leading: IconButton(
        icon: const Icon(Icons.close_rounded, color: ThixPolicy.textMain),
        onPressed: _exitSelection,
      ),
      title: Text('${_selectedIds.length} ${_tr(l10n, 'chat_selected', 'sélectionné(s)')}',
          style: ThixPolicy.labelStyle.copyWith(fontSize: 16, fontWeight: ThixPolicy.bold, color: ThixPolicy.textMain)),
      actions: [
        IconButton(
          tooltip: _tr(l10n, 'chat_select_all', 'Tout sélectionner'),
          icon: const Icon(Icons.select_all_rounded, color: ThixPolicy.textMain),
          onPressed: _selectAll,
        ),
        IconButton(
          tooltip: _tr(l10n, 'chat_copy', 'Copier'),
          icon: const Icon(Icons.copy_rounded, color: ThixPolicy.textMain),
          onPressed: _selectedIds.isEmpty ? null : _copySelected,
        ),
        IconButton(
          tooltip: _tr(l10n, 'chat_delete', 'Supprimer'),
          icon: Icon(Icons.delete_outline_rounded, color: _selectedIds.isEmpty ? ThixPolicy.textMuted : ThixPolicy.danger),
          onPressed: _selectedIds.isEmpty ? null : _showBulkDeleteSheet,
        ),
      ],
    );
  }

  PreferredSizeWidget _buildAppBar(AppLocalizations l10n, bool callsVisible, bool myCalls) {
    final safeAvatar = ChatValidators.sanitizeUrl(widget.conversation.displayAvatar);
    return AppBar(
      backgroundColor: ThixPolicy.card,
      elevation: 0,
      scrolledUnderElevation: 2,
      leading: Semantics(
        button: true,
        label: _tr(l10n, 'common_back', 'Retour'),
        child: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: ThixPolicy.textMain),
          onPressed: () {
            HapticFeedback.selectionClick();
            _flushDraft();
            _markAsRead();
            context.pop();
          },
        ),
      ),
      titleSpacing: 0,
      title: Row(children: [
        Stack(children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: ThixPolicy.border, width: 1.5),
              boxShadow: ThixPolicy.shadowSoft(opacity: 0.05),
            ),
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
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(color: ThixPolicy.success, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
              ),
            ),
        ]),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Consumer(builder: (context, ref, _) {
              CertificationTier? tier;
              CertificationStatus? status;
              bool isCertified = false;
              bool isLegacyVerified = false;
              if (!widget.conversation.isGroup) {
                final otherId = _otherId;
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
              final safeName = ChatValidators.sanitize(widget.conversation.displayName, maxLength: 80);
              return Row(children: [
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
              ]);
            }),
            if (!widget.conversation.isGroup && _otherParticipant != null)
              Text(
                _getPresenceText(_otherParticipant!),
                style: ThixPolicy.captionStyle.copyWith(
                  fontSize: 12,
                  color: _isOnline ? ThixPolicy.success : ThixPolicy.textSecondary,
                  fontWeight: _isOnline ? FontWeight.w600 : FontWeight.w400,
                ),
              )
            else if (widget.conversation.isGroup)
              Text('${_groupMembers.length} ${_tr(l10n, 'chat_members', 'membres')}',
                  style: ThixPolicy.captionStyle.copyWith(fontSize: 12, color: ThixPolicy.textSecondary)),
          ]),
        ),
      ]),
      actions: [
        if (callsVisible) ...[
          Semantics(
            button: true,
            label: _tr(l10n, 'chat_video_call', 'Appel vidéo'),
            child: IconButton(
              icon: const Icon(Icons.videocam_outlined, color: ThixPolicy.inkDeep, size: 26),
              onPressed: () => _startCall(CallType.video),
            ),
          ),
          Semantics(
            button: true,
            label: _tr(l10n, 'chat_audio_call', 'Appel audio'),
            child: IconButton(
              icon: const Icon(Icons.call_outlined, color: ThixPolicy.inkDeep, size: 24),
              onPressed: () => _startCall(CallType.audio),
            ),
          ),
        ],
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert_rounded, color: ThixPolicy.textMain),
          color: ThixPolicy.card,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          onSelected: (v) {
            HapticFeedback.selectionClick();
            switch (v) {
              case 'search':
                setState(() => _searchActive = !_searchActive);
                break;
              case 'starred':
                _showStarredSheet();
                break;
              case 'wallpaper':
                _showWallpaperSheet();
                break;
              case 'calls':
                _toggleMyCalls(!myCalls);
                break;
              case 'select':
                final msgs = ref.read(chatMessagesProvider(widget.conversationId));
                if (msgs.isNotEmpty) _enterSelection(msgs.first.id);
                break;
              case 'escalate':
                _escalateConversation();
                break;
              case 'history':
                _viewEscalationHistory();
                break;
              case 'group':
                GoRouter.of(context).go('/chat/group/${widget.conversationId}/info');
                break;
              case 'export':
                _exportConversation();
                break;
            }
          },
          itemBuilder: (_) => [
            _menuItem('search', Icons.search_rounded, ThixPolicy.inkDeep, _tr(l10n, 'chat_search', 'Rechercher')),
            _menuItem('starred', Icons.star_outline_rounded, ThixPolicy.gold, _tr(l10n, 'chat_starred', 'Favoris')),
            _menuItem('select', Icons.checklist_rounded, ThixPolicy.inkDeep, _tr(l10n, 'chat_select', 'Sélectionner')),
            _menuItem('wallpaper', Icons.wallpaper_rounded, ThixPolicy.inkDeep, _tr(l10n, 'chat_wallpaper', 'Fond d’écran')),
            if (!widget.conversation.isGroup)
              _menuItem(
                'calls',
                myCalls ? Icons.phone_disabled_rounded : Icons.phone_enabled_rounded,
                myCalls ? ThixPolicy.danger : ThixPolicy.success,
                myCalls ? _tr(l10n, 'chat_calls_disable', 'Désactiver les appels') : _tr(l10n, 'chat_calls_enable', 'Activer les appels'),
              ),
            _menuItem('escalate', Icons.arrow_upward, ThixPolicy.warning, _tr(l10n, 'chat_escalate', 'Escalader')),
            _menuItem('history', Icons.history, ThixPolicy.inkDeep, _tr(l10n, 'chat_history', 'Historique')),
            if (_isAgent) _menuItem('export', Icons.download_rounded, ThixPolicy.textSecondary, _tr(l10n, 'chat_export', 'Exporter (CSV)')),
            if (widget.conversation.isGroup)
              _menuItem('group', Icons.info_outline, ThixPolicy.textSecondary, _tr(l10n, 'chat_group_info', 'Infos du groupe')),
          ],
        ),
      ],
    );
  }

  PopupMenuItem<String> _menuItem(String value, IconData icon, Color color, String label) {
    return PopupMenuItem<String>(
      value: value,
      child: Row(children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 10),
        Flexible(child: Text(label)),
      ]),
    );
  }

  // ==========================================================================
  // DIALOGUES ÉPHÉMÈRE + MOT DE PASSE
  // ==========================================================================
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
            decoration: BoxDecoration(
              color: ThixPolicy.card,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
              border: Border(top: BorderSide(color: ThixPolicy.border)),
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
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
                    trailing: selected ? const Icon(Icons.check_circle, color: ThixPolicy.inkDeep) : null,
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
                  title: Text(_tr(l10n, 'chat_custom_time', 'Durée personnalisée'), style: const TextStyle(color: ThixPolicy.inkDeep, fontWeight: FontWeight.w600)),
                  leading: const Icon(Icons.timer_outlined, color: ThixPolicy.inkDeep),
                  onTap: () => setModalState(() => showCustomInput = true),
                ),
              ] else ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(children: [
                    Expanded(
                      child: TextField(
                        controller: customTimeCtrl,
                        keyboardType: TextInputType.number,
                        autofocus: true,
                        decoration: InputDecoration(
                          labelText: _tr(l10n, 'chat_duration_seconds', 'Durée (secondes)'),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ThixPolicy.inkDeep,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                      ),
                      onPressed: () {
                        final val = int.tryParse(customTimeCtrl.text.trim());
                        if (val != null && val > 0 && val <= 86400) {
                          setState(() {
                            _ephemeralDuration = val;
                            _isEphemeral = true;
                          });
                          Navigator.pop(ctx);
                        } else {
                          _showWarning(_tr(l10n, 'chat_invalid_number', 'Nombre invalide (1 - 86400)'));
                        }
                      },
                      child: Text(_tr(l10n, 'chat_validate', 'Valider'), style: const TextStyle(color: Colors.white)),
                    ),
                  ]),
                ),
                TextButton(onPressed: () => setModalState(() => showCustomInput = false), child: Text(_tr(l10n, 'common_back', 'Retour'))),
              ],
            ]),
          ),
        ),
      ),
    ).whenComplete(customTimeCtrl.dispose);
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
          final score = ChatValidators.passwordScore(passCtrl.text);
          final colors = <Color>[ThixPolicy.danger, ThixPolicy.danger, ThixPolicy.warning, ThixPolicy.success, ThixPolicy.success, ThixPolicy.success];
          return AlertDialog(
            backgroundColor: ThixPolicy.card,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: ThixPolicy.border)),
            title: Text(_tr(l10n, 'chat_secure_message', 'Message protégé par mot de passe'),
                style: ThixPolicy.h3Style.copyWith(fontWeight: ThixPolicy.bold, fontSize: 16)),
            content: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextField(controller: msgCtrl, decoration: InputDecoration(labelText: _tr(l10n, 'chat_message', 'Message')), maxLines: 3),
                const SizedBox(height: 12),
                TextField(
                  controller: passCtrl,
                  decoration: InputDecoration(labelText: _tr(l10n, 'chat_password', 'Mot de passe')),
                  obscureText: true,
                  onChanged: (_) => setDlgState(() {}),
                ),
                const SizedBox(height: 6),
                Row(
                  children: List.generate(
                    5,
                    (i) => Expanded(
                      child: Container(
                        height: 4,
                        margin: const EdgeInsets.only(right: 3),
                        decoration: BoxDecoration(color: i < score ? colors[score] : ThixPolicy.border, borderRadius: BorderRadius.circular(2)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    score >= 4
                        ? _tr(l10n, 'chat_pwd_strong', 'Robuste')
                        : (score >= 3 ? _tr(l10n, 'chat_pwd_ok', 'Correct') : _tr(l10n, 'chat_pwd_weak', 'Trop faible (8+ car., maj., min., chiffre, symbole)')),
                    style: TextStyle(fontSize: 11, color: score >= 3 ? ThixPolicy.success : ThixPolicy.danger, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: confirmCtrl,
                  decoration: InputDecoration(labelText: _tr(l10n, 'chat_password_confirm', 'Confirmer le mot de passe')),
                  obscureText: true,
                ),
              ]),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: Text(_tr(l10n, 'common_cancel', 'Annuler'))),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: ThixPolicy.inkDeep),
                onPressed: () {
                  if (msgCtrl.text.isEmpty || passCtrl.text.isEmpty) return;
                  if (ChatValidators.passwordScore(passCtrl.text) < 3) {
                    _showWarning(_tr(l10n, 'chat_pwd_weak', 'Mot de passe trop faible'));
                    return;
                  }
                  if (passCtrl.text != confirmCtrl.text) {
                    _showWarning(_tr(l10n, 'chat_pwd_mismatch', 'Les mots de passe ne correspondent pas'));
                    return;
                  }
                  final sanitizedMsg = ChatValidators.sanitize(msgCtrl.text, maxLength: kChatMaxMessageLength);
                  final enc = EncryptionService.encryptMessage(sanitizedMsg, passCtrl.text);
                  Navigator.pop(ctx);

                  final convId = widget.conversationId;
                  final replyId = _replyToId.isEmpty ? null : _replyToId;
                  final eph = _isEphemeral;
                  final ephDur = _ephemeralDuration;
                  setState(() => _replyToId = '');
                  _enqueue(PendingMessage(
                    kind: 'text',
                    label: '🔒 ${_tr(l10n, 'chat_protected', 'Message protégé')}',
                    job: () => _chatRetry(
                      () => _chatService.sendMessage(
                        conversationId: convId,
                        content: enc,
                        replyToId: replyId,
                        isEphemeral: eph,
                        ephemeralDuration: ephDur,
                      ),
                      label: 'sendEncrypted',
                    ),
                  ));
                },
                child: Text(_tr(l10n, 'chat_send', 'Envoyer'), style: const TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      ),
    ).whenComplete(() {
      msgCtrl.dispose();
      passCtrl.dispose();
      confirmCtrl.dispose();
    });
  }
}

// ============================================================================
// FOND « THIX CHAT » (motif par défaut)
// ============================================================================
class _ThixChatBackgroundPainter extends CustomPainter {
  static TextPainter? _cached;

  static TextPainter _painter() {
    final existing = _cached;
    if (existing != null) return existing;
    const textStyle = TextStyle(
      color: Color(0x1AD3C7B5),
      fontSize: 18,
      fontWeight: FontWeight.w900,
      letterSpacing: 2.0,
    );
    final tp = TextPainter(text: const TextSpan(text: 'THIX CHAT', style: textStyle), textDirection: ui.TextDirection.ltr)..layout();
    _cached = tp;
    return tp;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final textPainter = _painter();
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
