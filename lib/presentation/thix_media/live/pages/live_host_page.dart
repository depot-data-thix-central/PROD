// lib/presentation/thix_media/live/pages/live_host_page.dart
//
// LiveHostPage — Host Live Production Enterprise (niveau TikTok/IG Live)
// Version 2.0 avec :
// - Like ultra-rapide style TikTok (animation overlay + batching)
// - Multi-guest / Co-hosting (faire monter les spectateurs)
// - Détection des requêtes "request_join" avec bouton Inviter
// - Panneau de gestion des guests (inviter / retirer)
// - Split screen avec noms et avatars des guests
// - Chat temps réel avec sanitization XSS renforcée
// - Gestion mémoire optimisée
//
import 'dart:async';
import 'dart:math';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/l10n/app_localizations.dart';

import '../services/live_rtc_service.dart';
import '../services/live_service.dart';
import '../providers/go_live_provider.dart';

// ============================================================================
// CONSTANTS
// ============================================================================

const int _kMaxChatLength = 200;
const int _kMaxMessagesInMemory = 80;
const Duration _kStatsPolling = Duration(seconds: 3);
const Duration _kChatThrottle = Duration(milliseconds: 600);
const Duration _kActionThrottle = Duration(milliseconds: 400);
const Duration _kLikeBatchInterval = Duration(milliseconds: 500);
const Duration _kGuestsPolling = Duration(seconds: 5);
const List<String> _kReactions = ['❤️', '🔥', '👏', '😂', '😮'];

// ============================================================================
// LOGGING
// ============================================================================

class _LiveHostLogger {
  static const _tag = 'LiveHost';
  static void info(String m, [Map<String, dynamic>? d]) => _log('INFO', m, d);
  static void warn(String m, [Map<String, dynamic>? d]) => _log('WARN', m, d);
  static void error(String m, [Map<String, dynamic>? d]) => _log('ERROR', m, d);
  static void _log(String l, String m, Map<String, dynamic>? d) {
    if (!kDebugMode && l == 'INFO') return;
    final data = d != null
        ? ' ${d.entries.map((e) => '${e.key}=${e.value}').join(', ')}'
        : '';
    debugPrint('[$_tag] [$l] $m$data');
  }
}

// ============================================================================
// SANITIZER (anti-XSS + anti-spoofing)
// ============================================================================

class _LiveSanitizer {
  _LiveSanitizer._();

  static const int _kMaxUsernameLength = 24;
  static const List<String> _kAllowedTypes = [
    'chat', 'reaction', 'gift', 'invite', 'request_join', 'promote', 'demote'
  ];

  static String chat(String? input) {
    if (input == null) return '';
    var s = input;

    String prev;
    do {
      prev = s;
      s = s.replaceAll(RegExp(r'<[^>]*>'), '');
    } while (s != prev);

    s = s
        .replaceAll(RegExp(r'javascript:', caseSensitive: false), '')
        .replaceAll(RegExp(r'data:text/html', caseSensitive: false), '')
        .replaceAll(RegExp(r'on\w+\s*=', caseSensitive: false), '')
        .replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]'), '')
        .replaceAll(
            RegExp(r'[\u200B-\u200F\u202A-\u202E\u2060-\u206F]'), '')
        .trim();

    if (s.length > _kMaxChatLength) s = s.substring(0, _kMaxChatLength);
    return s;
  }

  static String username(String? input) {
    final cleaned = chat(input);
    if (cleaned.isEmpty) return 'User';
    return cleaned.length > _kMaxUsernameLength
        ? '${cleaned.substring(0, _kMaxUsernameLength)}…'
        : cleaned;
  }

  static String messageType(String? input) {
    final t = (input ?? 'chat').trim().toLowerCase();
    return _kAllowedTypes.contains(t) ? t : 'chat';
  }

  static String shareUrl(String sessionId) {
    return 'https://thix.id/live/${Uri.encodeComponent(sessionId)}';
  }
}

// ============================================================================
// NETWORK QUALITY
// ============================================================================

enum _NetQ { excellent, good, poor, offline }

extension _NetQX on _NetQ {
  Color color() {
    switch (this) {
      case _NetQ.excellent:
        return const Color(0xFF22C55E);
      case _NetQ.good:
        return const Color(0xFFEAB308);
      case _NetQ.poor:
        return const Color(0xFFF97316);
      case _NetQ.offline:
        return const Color(0xFFEF4444);
    }
  }

  String label(AppLocalizations l10n) {
    switch (this) {
      case _NetQ.excellent:
        return l10n.t('live_network_excellent');
      case _NetQ.good:
        return l10n.t('live_network_good');
      case _NetQ.poor:
        return l10n.t('live_network_poor');
      case _NetQ.offline:
        return l10n.t('live_network_offline');
    }
  }
}

// ============================================================================
// JOIN REQUEST
// ============================================================================

class _JoinRequest {
  final String userId;
  final String username;
  final String text;
  final DateTime receivedAt;

  _JoinRequest({
    required this.userId,
    required this.username,
    required this.text,
    required this.receivedAt,
  });
}

// ============================================================================
// LIVE HOST PAGE
// ============================================================================

class LiveHostPage extends ConsumerStatefulWidget {
  final LiveSession session;
  final AgoraCredentials creds;

  const LiveHostPage({
    super.key,
    required this.session,
    required this.creds,
  });

  @override
  ConsumerState<LiveHostPage> createState() => _LiveHostPageState();
}

class _LiveHostPageState extends ConsumerState<LiveHostPage>
    with TickerProviderStateMixin {
  final _rtc = LiveRtcService();
  final _chatCtrl = TextEditingController();
  final _chatScroll = ScrollController();
  final _random = Random();

  // ═══ State ═══
  bool _ready = false;
  bool _ending = false;
  bool _muted = false;
  bool _videoOff = false;
  bool _chatSending = false;
  _NetQ _netQuality = _NetQ.good;

  int _viewerCount = 0;
  int _likeCount = 0;
  int _reactionBurst = 0;
  String _lastReaction = '';
  DateTime? _lastChat;
  DateTime? _lastAction;
  DateTime? _liveStart;
  Duration _liveDuration = Duration.zero;

  // Multi-guest : uid -> GuestInfo (username + status)
  final Map<int, _GuestState> _remoteUids = {};
  
  // Requêtes "request_join" en attente (non traitées)
  final Map<String, _JoinRequest> _pendingRequests = {}; // userId -> request
  final Set<String> _invitingUsers = {}; // userId en cours d'invitation (anti-spam)

  // TikTok-style likes
  final List<_FlyingHeart> _hearts = [];
  int _pendingLikes = 0;
  Timer? _likeBatchTimer;

  List<_ChatLine> _messages = [];
  RealtimeChannel? _msgChannel;
  Timer? _statsTimer;
  Timer? _durationTimer;
  Timer? _netTimer;
  Timer? _guestsTimer;
  StreamSubscription? _netSub;

  @override
  void initState() {
    super.initState();
    _viewerCount = widget.session.viewerCount;
    _likeCount = widget.session.likeCount;
    _liveStart = DateTime.now();
    _bootstrap();
    _LiveHostLogger.info('LiveHostPage init', {'sessionId': widget.session.id});
  }

  @override
  void dispose() {
    _statsTimer?.cancel();
    _durationTimer?.cancel();
    _netTimer?.cancel();
    _guestsTimer?.cancel();
    _netSub?.cancel();
    _likeBatchTimer?.cancel();
    _msgChannel?.unsubscribe();
    _chatCtrl.dispose();
    _chatScroll.dispose();
    _rtc.dispose();
    _LiveHostLogger.info('LiveHostPage disposed');
    super.dispose();
  }

  // ════════════════════════════════════════════════════════════
  // BOOTSTRAP
  // ════════════════════════════════════════════════════════════

  Future<void> _bootstrap() async {
    try {
      await _rtc.startAsHost(widget.creds);
      
      // Register Agora event handlers for multi-guest
      _rtc.engine?.registerEventHandler(RtcEngineEventHandler(
        onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
          _LiveHostLogger.info('Guest joined', {'uid': remoteUid});
          if (mounted) {
            setState(() {
              _remoteUids.putIfAbsent(
                remoteUid,
                () => _GuestState(uid: remoteUid, username: 'Guest'),
              );
            });
            // Refresh guests depuis la DB pour obtenir le vrai username
            _refreshGuestsFromDb();
          }
        },
        onUserOffline: (RtcConnection connection, int remoteUid, UserOfflineReasonType reason) {
          _LiveHostLogger.info('Guest left', {'uid': remoteUid, 'reason': reason});
          if (mounted) {
            setState(() => _remoteUids.remove(remoteUid));
          }
        },
        onRemoteVideoStateChanged: (RtcConnection connection, int remoteUid, 
            RemoteVideoState state, RemoteVideoStateReason reason, int elapsed) {
          _LiveHostLogger.info('Remote video state', {
            'uid': remoteUid, 
            'state': state,
            'reason': reason
          });
          if (mounted && _remoteUids.containsKey(remoteUid)) {
            setState(() {
              _remoteUids[remoteUid]!.videoEnabled = 
                  state == RemoteVideoState.remoteVideoStateDecoding;
            });
          }
        },
        onRemoteAudioStateChanged: (RtcConnection connection, int remoteUid,
            RemoteAudioState state, RemoteAudioStateReason reason, int elapsed) {
          if (mounted && _remoteUids.containsKey(remoteUid)) {
            setState(() {
              _remoteUids[remoteUid]!.audioEnabled = 
                  state == RemoteAudioState.remoteAudioStateDecoding;
            });
          }
        },
      ));
      
      if (!mounted) return;
      setState(() => _ready = true);
      _subscribeChat();
      _startStatsPolling();
      _startDurationTimer();
      _startNetworkMonitor();
      _startLikeBatching();
      _startGuestsPolling();
      _LiveHostLogger.info('Live started', {'id': widget.session.id});
    } catch (e, stack) {
      _LiveHostLogger.error('Bootstrap failed',
          {'error': '$e', 'stack': stack.toString()});
      if (!mounted) return;

      _snack(AppLocalizations.of(context).t('live_error_generic'), error: true);
      Navigator.of(context).pop();
    }
  }

  // ════════════════════════════════════════════════════════════
  // GUESTS POLLING (sync noms réels depuis DB)
  // ════════════════════════════════════════════════════════════

  void _startGuestsPolling() {
    // Polling initial + périodique pour obtenir les usernames
    _refreshGuestsFromDb();
    _guestsTimer = Timer.periodic(_kGuestsPolling, (_) {
      _refreshGuestsFromDb();
    });
  }

  Future<void> _refreshGuestsFromDb() async {
    try {
      final guests = await ref
          .read(liveServiceProvider)
          .getLiveGuests(widget.session.id);
      if (!mounted) return;

      setState(() {
        // Mettre à jour les usernames des guests connectés
        for (final guest in guests) {
          if (guest.isOnStage && guest.agoraUid != null) {
            final uid = guest.agoraUid!;
            if (_remoteUids.containsKey(uid)) {
              _remoteUids[uid]!.username = guest.username;
              _remoteUids[uid]!.userId = guest.userId;
            }
          }
        }
      });
    } catch (e) {
      _LiveHostLogger.warn('Refresh guests failed', {'error': '$e'});
    }
  }

  // ════════════════════════════════════════════════════════════
  // TIKTOK-STYLE LIKES (Batching + Optimistic UI)
  // ════════════════════════════════════════════════════════════

  void _startLikeBatching() {
    _likeBatchTimer = Timer.periodic(_kLikeBatchInterval, (_) {
      if (_pendingLikes > 0) {
        _sendLikeBatch(_pendingLikes);
        _pendingLikes = 0;
      }
    });
  }

  Future<void> _sendLikeBatch(int count) async {
    try {
      await ref.read(liveServiceProvider).sendLikeBatch(
            liveId: widget.session.id,
            count: count,
            username: _currentUsername(),
          );
      _LiveHostLogger.info('Like batch sent', {'count': count});
    } catch (e) {
      _LiveHostLogger.warn('Like batch failed', {'error': '$e'});
    }
  }

  void _spawnTikTokLike() {
    HapticFeedback.lightImpact();
    
    final id = UniqueKey();
    final color = Colors.primaries[_random.nextInt(Colors.primaries.length)];
    final offsetX = _random.nextDouble() * 60 - 30;
    
    setState(() {
      _hearts.add(_FlyingHeart(
        id: id,
        color: color,
        offsetX: offsetX,
      ));
      _pendingLikes++;
      _likeCount++;
    });

    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        setState(() => _hearts.removeWhere((h) => h.id == id));
      }
    });
  }

  // ════════════════════════════════════════════════════════════
  // REALTIME CHAT (Supabase)
  // ════════════════════════════════════════════════════════════

  void _subscribeChat() {
    final client = Supabase.instance.client;
    _msgChannel = client
        .channel('live_msgs_${widget.session.id}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'live_messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'live_id',
            value: widget.session.id,
          ),
          callback: (payload) {
            final row = payload.newRecord;
            final text = _LiveSanitizer.chat(row['text']?.toString());
            final user = _LiveSanitizer.username(row['username']?.toString());
            final type = _LiveSanitizer.messageType(row['type']?.toString());
            final userId = row['user_id']?.toString();
            if (!mounted || text.isEmpty || userId == null) return;

            // 🔥 Gestion spéciale des requêtes "request_join"
            if (type == 'request_join') {
              _LiveHostLogger.info('Join request received', {
                'from': user,
                'userId': userId,
              });
              setState(() {
                _pendingRequests[userId] = _JoinRequest(
                  userId: userId,
                  username: user,
                  text: text,
                  receivedAt: DateTime.now(),
                );
              });
              HapticFeedback.mediumImpact();
              // Ajouter quand même au chat (sera affiché en highlight)
            }

            setState(() {
              _messages = [
                ..._messages,
                _ChatLine(
                  username: user,
                  text: text,
                  type: type,
                  userId: userId,
                ),
              ];
              if (_messages.length > _kMaxMessagesInMemory) {
                _messages = _messages.sublist(
                    _messages.length - _kMaxMessagesInMemory);
              }
            });

            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (_chatScroll.hasClients) {
                _chatScroll.animateTo(
                  0,
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                );
              }
            });
          },
        )
        .subscribe();
    _LiveHostLogger.info('Chat channel subscribed');
  }

  // ════════════════════════════════════════════════════════════
  // STATS POLLING
  // ════════════════════════════════════════════════════════════

  void _startStatsPolling() {
    _statsTimer = Timer.periodic(_kStatsPolling, (_) async {
      try {
        final row = await Supabase.instance.client
            .from('lives')
            .select('viewer_count, like_count')
            .eq('id', widget.session.id)
            .maybeSingle()
            .timeout(const Duration(seconds: 5));
        if (row != null && mounted) {
          setState(() {
            _viewerCount =
                (row['viewer_count'] as num?)?.toInt() ?? _viewerCount;
            _likeCount = (row['like_count'] as num?)?.toInt() ?? _likeCount;
          });
        }
      } catch (e) {
        _LiveHostLogger.warn('Stats poll failed', {'error': '$e'});
      }
    });
  }

  void _startDurationTimer() {
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_liveStart == null || !mounted) return;
      setState(() => _liveDuration = DateTime.now().difference(_liveStart!));
    });
  }

  // ════════════════════════════════════════════════════════════
  // NETWORK MONITOR
  // ════════════════════════════════════════════════════════════

  void _startNetworkMonitor() {
    _checkNetwork();
    _netSub = Connectivity().onConnectivityChanged.listen((r) {
      _evaluateNetwork(r);
    });
    _netTimer = Timer.periodic(
        const Duration(seconds: 10), (_) => _checkNetwork());
  }

  Future<void> _checkNetwork() async {
    try {
      final r = await Connectivity().checkConnectivity();
      _evaluateNetwork(r);
    } catch (_) {}
  }

  void _evaluateNetwork(List<ConnectivityResult> r) {
    _NetQ q;
    if (r.contains(ConnectivityResult.none)) {
      q = _NetQ.offline;
    } else if (r.contains(ConnectivityResult.wifi) ||
        r.contains(ConnectivityResult.ethernet)) {
      q = _NetQ.excellent;
    } else if (r.contains(ConnectivityResult.mobile)) {
      q = _NetQ.good;
    } else {
      q = _NetQ.poor;
    }
    if (mounted && _netQuality != q) {
      setState(() => _netQuality = q);
    }
  }

  // ════════════════════════════════════════════════════════════
  // THROTTLE
  // ════════════════════════════════════════════════════════════

  bool _throttleChat() {
    final now = DateTime.now();
    if (_lastChat != null && now.difference(_lastChat!) < _kChatThrottle) {
      return false;
    }
    _lastChat = now;
    return true;
  }

  bool _throttleAction() {
    final now = DateTime.now();
    if (_lastAction != null &&
        now.difference(_lastAction!) < _kActionThrottle) {
      return false;
    }
    _lastAction = now;
    return true;
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor:
          error ? ThixPolicy.danger : ThixPolicy.domainMedia,
      behavior: SnackBarBehavior.floating,
    ));
  }

  String _currentUsername() {
    final user = Supabase.instance.client.auth.currentUser;
    final raw = user?.userMetadata?['username']?.toString() ??
        user?.email?.split('@').first ??
        'Host';
    return _LiveSanitizer.username(raw);
  }

  // ════════════════════════════════════════════════════════════
  // ACTIONS
  // ════════════════════════════════════════════════════════════

  Future<void> _toggleMute() async {
    if (!_throttleAction()) return;
    HapticFeedback.selectionClick();
    final next = !_muted;
    try {
      await _rtc.muteLocalAudio(next);
      if (mounted) setState(() => _muted = next);
      _LiveHostLogger.info('Mute toggled', {'muted': next});
    } catch (e) {
      _LiveHostLogger.error('Mute toggle failed', {'error': '$e'});
    }
  }

  Future<void> _toggleVideo() async {
    if (!_throttleAction()) return;
    HapticFeedback.selectionClick();
    final next = !_videoOff;
    try {
      await _rtc.muteLocalVideo(next);
      if (mounted) setState(() => _videoOff = next);
      _LiveHostLogger.info('Video toggled', {'off': next});
    } catch (e) {
      _LiveHostLogger.error('Video toggle failed', {'error': '$e'});
    }
  }

  Future<void> _flipCamera() async {
    if (!_throttleAction()) return;
    HapticFeedback.selectionClick();
    try {
      await _rtc.switchCamera();
      _LiveHostLogger.info('Camera flipped');
    } catch (e) {
      _LiveHostLogger.error('Flip failed', {'error': '$e'});
    }
  }

  Future<void> _sendChat() async {
    if (!_throttleChat() || _chatSending) return;
    final text = _LiveSanitizer.chat(_chatCtrl.text);
    if (text.isEmpty) return;

    if (mounted) setState(() => _chatSending = true);
    try {
      final name = _currentUsername();
      await ref.read(liveServiceProvider).sendMessage(
            liveId: widget.session.id,
            text: text,
            username: name,
          );
      _chatCtrl.clear();
      HapticFeedback.lightImpact();
    } catch (e) {
      _LiveHostLogger.error('Send chat failed', {'error': '$e'});
      if (mounted) {
        _snack(
          AppLocalizations.of(context).t('live_chat_send_error'),
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => _chatSending = false);
    }
  }

  Future<void> _sendReaction(String emoji) async {
    if (!_throttleChat()) return;
    HapticFeedback.lightImpact();
    final name = _currentUsername();
    try {
      await ref.read(liveServiceProvider).sendMessage(
            liveId: widget.session.id,
            text: emoji,
            username: name,
            type: 'reaction',
          );
      if (mounted) {
        setState(() {
          _lastReaction = emoji;
          _reactionBurst++;
        });
      }
    } catch (e) {
      _LiveHostLogger.warn('Reaction failed', {'error': '$e'});
    }
  }

  void _shareLive(AppLocalizations l10n) {
    if (!_throttleAction()) return;
    HapticFeedback.lightImpact();
    final link = _LiveSanitizer.shareUrl(widget.session.id);
    Clipboard.setData(ClipboardData(text: link));
    _snack(l10n.t('live_link_copied'));
  }

  // ════════════════════════════════════════════════════════════
  // 🎯 INVITE GUEST ACTIONS
  // ════════════════════════════════════════════════════════════

  Future<void> _inviteUser(String userId, String username) async {
    if (_invitingUsers.contains(userId)) return;
    if (!_throttleAction()) return;

    setState(() => _invitingUsers.add(userId));
    HapticFeedback.mediumImpact();
    _LiveHostLogger.info('Inviting user', {'userId': userId, 'username': username});

    try {
      await ref.read(liveServiceProvider).sendGuestInvite(
            liveId: widget.session.id,
            guestUserId: userId,
            guestUsername: username,
          );
      if (mounted) {
        _snack(AppLocalizations.of(context).t('live_invite_sent'));
        // Retirer de la liste des requests en attente
        setState(() => _pendingRequests.remove(userId));
      }
    } catch (e) {
      _LiveHostLogger.error('Invite failed', {'error': '$e', 'userId': userId});
      if (mounted) {
        String errorMsg;
        if (e is LiveGuestLimitException) {
          errorMsg = AppLocalizations.of(context).t('live_guest_limit_reached');
        } else if (e is LiveGuestAlreadyOnStageException) {
          errorMsg = AppLocalizations.of(context).t('live_guest_already_on_stage');
        } else {
          errorMsg = AppLocalizations.of(context).t('live_invite_failed');
        }
        _snack(errorMsg, error: true);
      }
    } finally {
      if (mounted) {
        setState(() => _invitingUsers.remove(userId));
      }
    }
  }

  Future<void> _removeGuest(int uid, String userId, String username) async {
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: Text(
          l10n.t('live_remove_guest_title'),
          style: const TextStyle(color: Colors.white),
        ),
        content: Text(
          l10n.t('live_remove_guest_confirm').replaceAll('{name}', username),
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              l10n.t('common_cancel'),
              style: const TextStyle(color: Colors.white70),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: ThixPolicy.danger),
            child: Text(l10n.t('live_remove_guest_btn')),
          ),
        ],
      ),
    );
    if (ok != true) return;

    HapticFeedback.mediumImpact();
    try {
      await ref.read(liveServiceProvider).removeGuest(
            widget.session.id,
            userId,
          );
      _LiveHostLogger.info('Guest removed', {'uid': uid, 'userId': userId});
    } catch (e) {
      _LiveHostLogger.error('Remove guest failed', {'error': '$e'});
      if (mounted) {
        _snack(
          AppLocalizations.of(context).t('live_remove_guest_failed'),
          error: true,
        );
      }
    }
  }

  void _dismissRequest(String userId) {
    if (!mounted) return;
    setState(() => _pendingRequests.remove(userId));
  }

  void _showGuestsPanel(AppLocalizations l10n) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _GuestsPanel(
        requests: _pendingRequests.values.toList(),
        guests: _remoteUids.values.toList(),
        invitingUsers: _invitingUsers,
        onInvite: (req) {
          Navigator.pop(ctx);
          _inviteUser(req.userId, req.username);
        },
        onDismissRequest: (req) {
          Navigator.pop(ctx);
          _dismissRequest(req.userId);
        },
        onRemoveGuest: (g) {
          Navigator.pop(ctx);
          if (g.userId != null) {
            _removeGuest(g.uid, g.userId!, g.username);
          }
        },
        l10n: l10n,
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  // END LIVE
  // ════════════════════════════════════════════════════════════

  Future<void> _confirmEnd() async {
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: Text(
          l10n.t('live_end_title'),
          style: const TextStyle(color: Colors.white),
        ),
        content: Text(
          l10n.t('live_end_confirm'),
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              l10n.t('common_cancel'),
              style: const TextStyle(color: Colors.white70),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: ThixPolicy.danger),
            child: Text(l10n.t('live_end_btn')),
          ),
        ],
      ),
    );
    if (ok == true) await _endLive();
  }

  Future<void> _endLive() async {
    if (_ending) return;
    if (mounted) setState(() => _ending = true);
    HapticFeedback.heavyImpact();
    _LiveHostLogger.info('Ending live', {'id': widget.session.id});

    try {
      await ref.read(liveServiceProvider).endLive(widget.session.id);
    } catch (e) {
      _LiveHostLogger.warn('End live API failed', {'error': '$e'});
    }
    try {
      await _rtc.leave();
    } catch (e) {
      _LiveHostLogger.warn('RTC leave failed', {'error': '$e'});
    }

    if (!mounted) return;
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  // ════════════════════════════════════════════════════════════
  // HELPERS
  // ════════════════════════════════════════════════════════════

  String _formatDuration(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return d.inHours > 0 ? '$h:$m:$s' : '$m:$s';
  }

  String _formatCount(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }

  Widget _buildLocalVideo() {
    final engine = _rtc.engine;
    if (_ready && engine != null && !_videoOff) {
      return AgoraVideoView(
        controller: VideoViewController(
          rtcEngine: engine,
          canvas: const VideoCanvas(uid: 0),
        ),
      );
    } else {
      return Container(
        color: Colors.black,
        child: Center(
          child: _ready
              ? Icon(
                  Icons.videocam_off_rounded,
                  size: 64,
                  color: Colors.white.withValues(alpha: 0.3),
                )
              : const CircularProgressIndicator(color: Colors.white),
        ),
      );
    }
  }

  Widget _buildSplitScreenVideo() {
    final guests = _remoteUids.values.toList();
    final totalStreams = 1 + guests.length; // host + guests
    
    // Layout adaptatif selon le nombre de guests
    if (totalStreams == 2) {
      // 2 streams : split vertical
      return Row(
        children: [
          Expanded(child: _buildStreamWithLabel(_buildLocalVideo(), _currentUsername(), isHost: true)),
          Expanded(child: _buildStreamWithLabel(
            _buildRemoteVideo(guests[0]),
            guests[0].username,
            isHost: false,
            videoEnabled: guests[0].videoEnabled,
            audioEnabled: guests[0].audioEnabled,
            onRemove: () => guests[0].userId != null 
                ? _removeGuest(guests[0].uid, guests[0].userId!, guests[0].username)
                : null,
          )),
        ],
      );
    } else {
      // 3+ streams : grille 2x2
      return Column(
        children: [
          Expanded(
            child: Row(
              children: [
                Expanded(child: _buildStreamWithLabel(_buildLocalVideo(), _currentUsername(), isHost: true)),
                if (guests.isNotEmpty)
                  Expanded(child: _buildStreamWithLabel(
                    _buildRemoteVideo(guests[0]),
                    guests[0].username,
                    isHost: false,
                    videoEnabled: guests[0].videoEnabled,
                    audioEnabled: guests[0].audioEnabled,
                    onRemove: () => guests[0].userId != null
                        ? _removeGuest(guests[0].uid, guests[0].userId!, guests[0].username)
                        : null,
                  )),
              ],
            ),
          ),
          if (guests.length > 1)
            Expanded(
              child: Row(
                children: [
                  Expanded(child: _buildStreamWithLabel(
                    _buildRemoteVideo(guests[1]),
                    guests[1].username,
                    isHost: false,
                    videoEnabled: guests[1].videoEnabled,
                    audioEnabled: guests[1].audioEnabled,
                    onRemove: () => guests[1].userId != null
                        ? _removeGuest(guests[1].uid, guests[1].userId!, guests[1].username)
                        : null,
                  )),
                  if (guests.length > 2)
                    Expanded(child: _buildStreamWithLabel(
                      _buildRemoteVideo(guests[2]),
                      guests[2].username,
                      isHost: false,
                      videoEnabled: guests[2].videoEnabled,
                      audioEnabled: guests[2].audioEnabled,
                      onRemove: () => guests[2].userId != null
                          ? _removeGuest(guests[2].uid, guests[2].userId!, guests[2].username)
                          : null,
                    ))
                  else
                    const Expanded(child: SizedBox()),
                ],
              ),
            ),
        ],
      );
    }
  }

  Widget _buildRemoteVideo(_GuestState guest) {
    final engine = _rtc.engine;
    if (engine == null || !guest.videoEnabled) {
      return Container(
        color: Colors.black87,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 32,
                backgroundColor: Colors.white24,
                child: Text(
                  guest.username.isNotEmpty ? guest.username[0].toUpperCase() : '?',
                  style: const TextStyle(color: Colors.white, fontSize: 24),
                ),
              ),
              const SizedBox(height: 8),
              Icon(Icons.videocam_off, color: Colors.white54, size: 20),
            ],
          ),
        ),
      );
    }
    return AgoraVideoView(
      controller: VideoViewController(
        rtcEngine: engine,
        canvas: VideoCanvas(uid: guest.uid),
      ),
    );
  }

  Widget _buildStreamWithLabel(
    Widget video,
    String label, {
    required bool isHost,
    bool videoEnabled = true,
    bool audioEnabled = true,
    VoidCallback? onRemove,
  }) {
    return Stack(
      fit: StackFit.expand,
      children: [
        video,
        // Badge en haut à gauche
        Positioned(
          top: 8,
          left: 8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isHost ? const Color(0xFFE11D48) : Colors.black54,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isHost) ...[
                  const Text(
                    'HOST',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(width: 4),
                ],
                if (!audioEnabled)
                  const Padding(
                    padding: EdgeInsets.only(right: 4),
                    child: Icon(Icons.mic_off, color: Colors.red, size: 12),
                  ),
                Flexible(
                  child: Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
        // Bouton retirer (uniquement pour les guests, pas le host)
        if (!isHost && onRemove != null)
          Positioned(
            top: 8,
            right: 8,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),
          ),
      ],
    );
  }

  // ════════════════════════════════════════════════════════════
  // BUILD
  // ════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final pendingRequestsCount = _pendingRequests.length;
    final guestsCount = _remoteUids.length;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmEnd();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            // ── Vidéo (locale ou split screen) ──────────────────────────────────
            if (_ready && _rtc.engine != null)
              _remoteUids.isEmpty 
                ? _buildLocalVideo()
                : _buildSplitScreenVideo()
            else
              Container(
                color: Colors.black,
                child: const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
              ),

            // ── TikTok-style flying hearts overlay ───────────────────────────────
            ..._hearts.map((h) => Positioned(
              bottom: 150,
              right: 60,
              child: h,
            )),

            // ── Gradient bas ──────────────────────────────────
            const Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 220,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black87],
                  ),
                ),
              ),
            ),

            // ── Réactions burst ───────────────────────────────
            if (_reactionBurst > 0)
              Positioned(
                right: 24,
                bottom: 280,
                child: _ReactionBurst(
                  key: ValueKey(_reactionBurst),
                  emoji: _lastReaction,
                ),
              ),

            // ── Top bar ───────────────────────────────────────
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE11D48),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'LIVE',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.black45,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _formatDuration(_liveDuration),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        widget.session.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    _NetworkIndicator(q: _netQuality, l10n: l10n),
                    const SizedBox(width: 6),
                    // 🔥 Nouveau : Panneau de gestion des guests
                    Semantics(
                      button: true,
                      label: l10n.t('live_manage_guests'),
                      child: _GuestsButton(
                        requestsCount: pendingRequestsCount,
                        guestsCount: guestsCount,
                        onTap: () => _showGuestsPanel(l10n),
                      ),
                    ),
                    const SizedBox(width: 6),
                    _StatChip(
                      icon: Icons.remove_red_eye_outlined,
                      value: _formatCount(_viewerCount),
                      label: l10n.t('live_viewers'),
                    ),
                    const SizedBox(width: 6),
                    _StatChip(
                      icon: Icons.favorite_border,
                      value: _formatCount(_likeCount),
                      label: l10n.t('live_likes'),
                    ),
                    const SizedBox(width: 4),
                    Semantics(
                      button: true,
                      label: l10n.t('live_share'),
                      child: IconButton(
                        onPressed: _ending ? null : () => _shareLive(l10n),
                        icon: const Icon(Icons.share_rounded,
                            color: Colors.white),
                      ),
                    ),
                    Semantics(
                      button: true,
                      label: l10n.t('live_end_btn'),
                      child: IconButton(
                        onPressed: _ending ? null : _confirmEnd,
                        icon: const Icon(Icons.close, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── TikTok-style Like Button (Right side) ───────────────────────
            Positioned(
              right: 16,
              bottom: 180,
              child: GestureDetector(
                onTap: _spawnTikTokLike,
                onDoubleTap: () {
                  _spawnTikTokLike();
                  _spawnTikTokLike();
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.black45,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.favorite,
                        color: Colors.white,
                        size: 36,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatCount(_likeCount),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Chat + input ─────────────────────────────────
            Positioned(
              left: 12,
              right: 80,
              bottom: 0,
              child: SafeArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 🔥 Bandeau "X personnes veulent monter" si des requests en attente
                    if (pendingRequestsCount > 0)
                      _RequestsBanner(
                        count: pendingRequestsCount,
                        onTap: () => _showGuestsPanel(l10n),
                        l10n: l10n,
                      ),
                    if (pendingRequestsCount > 0) const SizedBox(height: 6),
                    
                    SizedBox(
                      height: pendingRequestsCount > 0 ? 110 : 140,
                      child: _messages.isEmpty
                          ? Center(
                              child: Text(
                                l10n.t('live_chat_empty'),
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.4),
                                  fontSize: 12,
                                ),
                              ),
                            )
                          : ListView.builder(
                              controller: _chatScroll,
                              reverse: true,
                              padding: EdgeInsets.zero,
                              itemCount: _messages.length,
                              itemBuilder: (context, i) {
                                final m =
                                    _messages[_messages.length - 1 - i];
                                return _buildChatLine(m, l10n);
                              },
                            ),
                    ),
                    const SizedBox(height: 8),

                    // ── Réactions emoji row ──
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        for (final e in _kReactions)
                          Semantics(
                            button: true,
                            label: e,
                            child: GestureDetector(
                              onTap: () => _sendReaction(e),
                              child: Container(
                                width: 40,
                                height: 32,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: Colors.white12,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Text(e,
                                    style: const TextStyle(fontSize: 16)),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // ── Input + contrôles ──
                    Row(
                      children: [
                        Expanded(
                          child: Semantics(
                            textField: true,
                            label: l10n.t('live_chat_hint'),
                            child: TextField(
                              controller: _chatCtrl,
                              maxLength: _kMaxChatLength,
                              style: const TextStyle(color: Colors.white),
                              textInputAction: TextInputAction.send,
                              onSubmitted: (_) => _sendChat(),
                              decoration: InputDecoration(
                                counterText: '',
                                hintText: l10n.t('live_chat_hint'),
                                hintStyle:
                                    const TextStyle(color: Colors.white38),
                                filled: true,
                                fillColor:
                                    Colors.white.withValues(alpha: 0.12),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 10,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(24),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Semantics(
                          button: true,
                          label: _muted
                              ? l10n.t('live_unmute')
                              : l10n.t('live_mute'),
                          child: _RoundBtn(
                            icon: _muted ? Icons.mic_off : Icons.mic,
                            onTap: _toggleMute,
                            active: _muted,
                          ),
                        ),
                        Semantics(
                          button: true,
                          label: _videoOff
                              ? l10n.t('live_video_on')
                              : l10n.t('live_video_off'),
                          child: _RoundBtn(
                            icon: _videoOff
                                ? Icons.videocam_off
                                : Icons.videocam,
                            onTap: _toggleVideo,
                            active: _videoOff,
                          ),
                        ),
                        Semantics(
                          button: true,
                          label: l10n.t('live_flip_camera'),
                          child: _RoundBtn(
                            icon: Icons.cameraswitch_rounded,
                            onTap: _flipCamera,
                          ),
                        ),
                        Semantics(
                          button: true,
                          label: l10n.t('live_send'),
                          child: _RoundBtn(
                            icon: Icons.send_rounded,
                            onTap: _chatSending ? null : _sendChat,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            ),

            if (_ending)
              Container(
                color: Colors.black54,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(color: Colors.white),
                      const SizedBox(height: 12),
                      Text(
                        l10n.t('live_ending'),
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatLine(_ChatLine m, AppLocalizations l10n) {
    // Cas spécial : message request_join (affiché en highlight avec bouton)
    if (m.type == 'request_join' && m.userId != null) {
      final hasPendingRequest = _pendingRequests.containsKey(m.userId);
      final isInviting = _invitingUsers.contains(m.userId);
      
      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: ThixPolicy.domainMedia.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: ThixPolicy.domainMedia.withValues(alpha: 0.5),
            ),
          ),
          child: Row(
            children: [
              const Icon(Icons.hand_raised, color: Colors.white, size: 14),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${m.username} ${l10n.t("live_wants_to_join")}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              if (hasPendingRequest)
                GestureDetector(
                  onTap: isInviting ? null : () => _inviteUser(m.userId!, m.username),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isInviting ? Colors.grey : const Color(0xFF22C55E),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: isInviting
                        ? const SizedBox(
                            width: 10,
                            height: 10,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.5,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            l10n.t('live_invite_btn'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                )
              else
                Icon(Icons.check_circle, color: Colors.white54, size: 14),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '${m.username} ',
              style: TextStyle(
                color: m.type == 'gift'
                    ? Colors.amber
                    : m.type == 'reaction'
                        ? Colors.white
                        : ThixPolicy.primary,
                fontWeight: FontWeight.w800,
                fontSize: m.type == 'reaction' ? 16 : 13,
              ),
            ),
            TextSpan(
              text: m.text,
              style: TextStyle(
                color: Colors.white,
                fontSize: m.type == 'reaction' ? 18 : 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

// ============================================================================
// CHAT LINE
// ============================================================================

class _ChatLine {
  final String username;
  final String text;
  final String type;
  final String? userId;
  _ChatLine({
    required this.username,
    required this.text,
    this.type = 'chat',
    this.userId,
  });
}

// ============================================================================
// GUEST STATE (tracker local d'un guest)
// ============================================================================

class _GuestState {
  final int uid;
  String username;
  String? userId;
  bool videoEnabled;
  bool audioEnabled;

  _GuestState({
    required this.uid,
    required this.username,
    this.userId,
    this.videoEnabled = true,
    this.audioEnabled = true,
  });
}

// ============================================================================
// GUESTS BUTTON (top bar)
// ============================================================================

class _GuestsButton extends StatelessWidget {
  final int requestsCount;
  final int guestsCount;
  final VoidCallback onTap;

  const _GuestsButton({
    required this.requestsCount,
    required this.guestsCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.black45,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.group, size: 14, color: Colors.white),
                const SizedBox(width: 4),
                Text(
                  '$guestsCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
        // Badge rouge si des requêtes en attente
        if (requestsCount > 0)
          Positioned(
            right: -4,
            top: -4,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Color(0xFFEF4444),
                shape: BoxShape.circle,
              ),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              child: Text(
                requestsCount > 9 ? '9+' : '$requestsCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}

// ============================================================================
// REQUESTS BANNER (au-dessus du chat)
// ============================================================================

class _RequestsBanner extends StatelessWidget {
  final int count;
  final VoidCallback onTap;
  final AppLocalizations l10n;

  const _RequestsBanner({
    required this.count,
    required this.onTap,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              ThixPolicy.domainMedia,
              const Color(0xFFE11D48),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: ThixPolicy.domainMedia.withValues(alpha: 0.4),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(Icons.hand_raised, color: Colors.white, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                count == 1
                    ? l10n.t('live_one_request')
                    : l10n.t('live_multiple_requests').replaceAll('{count}', '$count'),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 12),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// GUESTS PANEL (BottomSheet)
// ============================================================================

class _GuestsPanel extends StatelessWidget {
  final List<_JoinRequest> requests;
  final List<_GuestState> guests;
  final Set<String> invitingUsers;
  final void Function(_JoinRequest req) onInvite;
  final void Function(_JoinRequest req) onDismissRequest;
  final void Function(_GuestState guest) onRemoveGuest;
  final AppLocalizations l10n;

  const _GuestsPanel({
    required this.requests,
    required this.guests,
    required this.invitingUsers,
    required this.onInvite,
    required this.onDismissRequest,
    required this.onRemoveGuest,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF1A1A1A),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.all(16),
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Titre
              Text(
                l10n.t('live_manage_guests'),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 20),

              // Section "En direct maintenant" (guests actuels)
              if (guests.isNotEmpty) ...[
                Text(
                  l10n.t('live_on_stage_now'),
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                ...guests.map((g) => _GuestTile(
                      username: g.username,
                      isOnStage: true,
                      onRemove: () => onRemoveGuest(g),
                    )),
                const SizedBox(height: 20),
              ],

              // Section "Demandes en attente"
              Text(
                l10n.t('live_pending_requests'),
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              if (requests.isEmpty)
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.how_to_reg, color: Colors.white38, size: 32),
                        const SizedBox(height: 8),
                        Text(
                          l10n.t('live_no_requests'),
                          style: const TextStyle(color: Colors.white54, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ...requests.map((req) => _RequestTile(
                      request: req,
                      isInviting: invitingUsers.contains(req.userId),
                      onInvite: () => onInvite(req),
                      onDismiss: () => onDismissRequest(req),
                      l10n: l10n,
                    )),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }
}

class _GuestTile extends StatelessWidget {
  final String username;
  final bool isOnStage;
  final VoidCallback? onRemove;

  const _GuestTile({
    required this.username,
    required this.isOnStage,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: const Color(0xFF22C55E),
            child: Text(
              username.isNotEmpty ? username[0].toUpperCase() : '?',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  username,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Color(0xFF22C55E),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'En direct',
                      style: TextStyle(color: Color(0xFF22C55E), fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (onRemove != null)
            GestureDetector(
              onTap: onRemove,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.close, color: Color(0xFFEF4444), size: 16),
              ),
            ),
        ],
      ),
    );
  }
}

class _RequestTile extends StatelessWidget {
  final _JoinRequest request;
  final bool isInviting;
  final VoidCallback onInvite;
  final VoidCallback onDismiss;
  final AppLocalizations l10n;

  const _RequestTile({
    required this.request,
    required this.isInviting,
    required this.onInvite,
    required this.onDismiss,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ThixPolicy.domainMedia.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: ThixPolicy.domainMedia.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: ThixPolicy.domainMedia,
            child: Text(
              request.username.isNotEmpty ? request.username[0].toUpperCase() : '?',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  request.username,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  l10n.t('live_wants_to_join'),
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: onDismiss,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.close, color: Colors.white70, size: 16),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: isInviting ? null : onInvite,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isInviting ? Colors.grey : const Color(0xFF22C55E),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: isInviting
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.handshake, color: Colors.white, size: 14),
                            const SizedBox(width: 4),
                            Text(
                              l10n.t('live_invite_btn'),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// STAT CHIP
// ============================================================================

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String value;
  final String? label;
  const _StatChip({required this.icon, required this.value, this.label});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label != null ? '$label: $value' : value,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.black45,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: Colors.white),
            const SizedBox(width: 4),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 12,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// NETWORK INDICATOR
// ============================================================================

class _NetworkIndicator extends StatelessWidget {
  final _NetQ q;
  final AppLocalizations l10n;
  const _NetworkIndicator({required this.q, required this.l10n});

  @override
  Widget build(BuildContext context) {
    final c = q.color();
    return Semantics(
      label: '${l10n.t('live_network_quality')}: ${q.label(l10n)}',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: c.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: c.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(shape: BoxShape.circle, color: c),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// ROUND BUTTON
// ============================================================================

class _RoundBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final bool active;

  const _RoundBtn({
    required this.icon,
    this.onTap,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Material(
        color: active ? const Color(0xFFE11D48) : Colors.white12,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 42,
            height: 42,
            child: Icon(icon, color: Colors.white, size: 20),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// REACTION BURST (animé)
// ============================================================================

class _ReactionBurst extends StatefulWidget {
  final String emoji;
  const _ReactionBurst({super.key, required this.emoji});

  @override
  State<_ReactionBurst> createState() => _ReactionBurstState();
}

class _ReactionBurstState extends State<_ReactionBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 1, end: 0).animate(_ctrl),
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.4), end: Offset.zero)
            .animate(_ctrl),
        child: Text(widget.emoji, style: const TextStyle(fontSize: 32)),
      ),
    );
  }
}

// ============================================================================
// FLYING HEART (TikTok-style)
// ============================================================================

class _FlyingHeart extends StatelessWidget {
  final Key id;
  final Color color;
  final double offsetX;
  
  const _FlyingHeart({
    required this.id,
    required this.color,
    required this.offsetX,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 1500),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(offsetX * value, -300 * value),
          child: Opacity(
            opacity: 1.0 - value,
            child: Icon(
              Icons.favorite,
              color: color,
              size: 30 + (20 * value),
            ),
          ),
        );
      },
    );
  }
}
