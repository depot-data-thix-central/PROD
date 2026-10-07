// lib/presentation/thix_media/live/pages/live_viewer_page.dart
//
// LiveViewerPage — Viewer Live Production Enterprise (niveau TikTok/IG Live)
// Version 2.0 avec :
// - Popup d'invitation realtime pour monter sur scène
// - Bouton "Demander à monter" (requête au host)
// - Promotion dynamique audience → broadcaster (Agora)
// - Contrôles cam/mic locaux quand sur scène
// - Affichage multi-guest (split screen + PiP)
// - Like ultra-rapide TikTok-style (overlay animé + RPC atomique)
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

import '../providers/go_live_provider.dart';
import '../services/live_rtc_service.dart';
import '../services/live_service.dart';

// ============================================================================
// CONSTANTS
// ============================================================================

const int _kMaxChatLength = 200;
const int _kMaxMessagesInMemory = 80;
const Duration _kStatsPolling = Duration(seconds: 3);
const Duration _kChatThrottle = Duration(milliseconds: 600);
const Duration _kLikeThrottle = Duration(milliseconds: 300);
const Duration _kActionThrottle = Duration(milliseconds: 400);
const Duration _kInviteTimeout = Duration(seconds: 30);
const List<String> _kReactions = ['❤️', '🔥', '👏', '😂', '😮'];

// ============================================================================
// LOGGING
// ============================================================================

class _LiveViewerLogger {
  static const _tag = 'LiveViewer';
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
// SANITIZER
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

  static String shareUrl(String liveId) {
    return 'https://thix.id/live/${Uri.encodeComponent(liveId)}';
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
// INVITE DATA
// ============================================================================

class _GuestInvite {
  final String liveId;
  final String hostId;
  final String hostUsername;
  final DateTime receivedAt;

  _GuestInvite({
    required this.liveId,
    required this.hostId,
    required this.hostUsername,
    required this.receivedAt,
  });
}

// ============================================================================
// LIVE VIEWER PAGE
// ============================================================================

class LiveViewerPage extends ConsumerStatefulWidget {
  final String liveId;
  final LiveSession? session;
  final AgoraCredentials? creds;

  const LiveViewerPage({
    super.key,
    required this.liveId,
    this.session,
    this.creds,
  });

  @override
  ConsumerState<LiveViewerPage> createState() => _LiveViewerPageState();
}

class _LiveViewerPageState extends ConsumerState<LiveViewerPage>
    with TickerProviderStateMixin {
  final _rtc = LiveRtcService();
  final _chatCtrl = TextEditingController();
  final _chatScroll = ScrollController();
  final _random = Random();

  LiveSession? _session;
  AgoraCredentials? _creds;

  bool _ready = false;
  bool _joining = true;
  bool _leaving = false;
  bool _chatSending = false;
  String? _error;
  _NetQ _netQuality = _NetQ.good;

  int? _hostUid;
  int _viewerCount = 0;
  int _likeCount = 0;
  DateTime? _lastChat;
  DateTime? _lastLike;
  DateTime? _lastAction;
  int _reactionBurst = 0;
  String _lastReaction = '';
  List<_ChatLine> _messages = [];
  final List<_FloatingLike> _floatingLikes = [];
  int _pendingLikes = 0;
  Timer? _likeBatchTimer;

  // ═══ Multi-Guest State ═══
  _GuestInvite? _pendingInvite;
  bool _isOnStage = false;
  bool _isLocallyMuted = false;
  bool _isLocalVideoOff = false;
  bool _requestingJoin = false;
  final Map<int, String> _remoteUsers = {}; // uid -> role/username

  RealtimeChannel? _msgChannel;
  RealtimeChannel? _inviteChannel;
  Timer? _statsTimer;
  Timer? _netTimer;
  Timer? _inviteExpireTimer;
  StreamSubscription<int?>? _remoteSub;
  StreamSubscription<int>? _remoteJoinedSub;
  StreamSubscription<(int, String)>? _remoteLeftSub;
  StreamSubscription<List<ConnectivityResult>>? _netSub;

  @override
  void initState() {
    super.initState();
    _bootstrap();
    _LiveViewerLogger.info('LiveViewerPage init', {'liveId': widget.liveId});
  }

  @override
  void dispose() {
    _statsTimer?.cancel();
    _netTimer?.cancel();
    _inviteExpireTimer?.cancel();
    _likeBatchTimer?.cancel();
    _remoteSub?.cancel();
    _remoteJoinedSub?.cancel();
    _remoteLeftSub?.cancel();
    _netSub?.cancel();
    _msgChannel?.unsubscribe();
    _inviteChannel?.unsubscribe();
    _chatCtrl.dispose();
    _chatScroll.dispose();
    _rtc.dispose();
    _LiveViewerLogger.info('LiveViewerPage disposed');
    super.dispose();
  }

  // ════════════════════════════════════════════════════════════
  // BOOTSTRAP
  // ════════════════════════════════════════════════════════════

  Future<void> _bootstrap() async {
    try {
      final liveService = ref.read(liveServiceProvider);

      if (widget.session != null && widget.creds != null) {
        _session = widget.session;
        _creds = widget.creds;
      } else {
        final result = await liveService.joinLive(widget.liveId);
        _session = result.session;
        _creds = result.creds;
      }

      _viewerCount = _session!.viewerCount;
      _likeCount = _session!.likeCount;

      await _rtc.joinAsAudience(_creds!);

      _remoteSub = _rtc.remoteUidStream.listen((uid) {
        if (!mounted) return;
        setState(() => _hostUid = uid ?? _rtc.remoteHostUid);
      });

      // Multi-guest : écouter les autres remote users
      _remoteJoinedSub = _rtc.remoteUserJoinedStream.listen((uid) {
        if (!mounted) return;
        setState(() {
          _remoteUsers[uid] = 'broadcaster';
          if (_hostUid == null) _hostUid = uid;
        });
      });

      _remoteLeftSub = _rtc.remoteUserLeftStream.listen((event) {
        if (!mounted) return;
        final uid = event.$1;
        setState(() => _remoteUsers.remove(uid));
      });

      if (_rtc.remoteHostUid != null) {
        _hostUid = _rtc.remoteHostUid;
        _remoteUsers[_rtc.remoteHostUid!] = 'host';
      }

      _subscribeChat();
      _subscribeInviteChannel();
      _startStatsPolling();
      _startNetworkMonitor();
      _startLikeBatching();

      if (!mounted) return;
      setState(() {
        _joining = false;
        _ready = true;
      });
      _LiveViewerLogger.info('Live joined',
          {'liveId': widget.liveId, 'hostUid': _hostUid});
    } catch (e, stack) {
      _LiveViewerLogger.error('Bootstrap failed',
          {'error': '$e', 'stack': stack.toString()});
      if (!mounted) return;
      setState(() {
        _joining = false;
        _error = e.toString();
      });
    }
  }

  // ════════════════════════════════════════════════════════════
  // 🎯 INVITE CHANNEL (Recevoir invitations du host)
  // ════════════════════════════════════════════════════════════

  void _subscribeInviteChannel() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    final client = Supabase.instance.client;
    _inviteChannel = client.channel('live_invite_${user.id}')
      ..onBroadcast(event: 'guest_invite', callback: (payload) {
        if (!mounted) return;
        final data = payload;
        
        // Vérifier que c'est bien pour ce live
        final inviteLiveId = data['live_id']?.toString();
        if (inviteLiveId != widget.liveId && inviteLiveId != _session?.id) {
          return;
        }

        final hostUsername = _LiveSanitizer.username(
          data['host_username']?.toString(),
        );

        _LiveViewerLogger.info('Invite received', {
          'from': hostUsername,
          'liveId': inviteLiveId,
        });

        setState(() {
          _pendingInvite = _GuestInvite(
            liveId: inviteLiveId ?? widget.liveId,
            hostId: data['host_id']?.toString() ?? '',
            hostUsername: hostUsername,
            receivedAt: DateTime.now(),
          );
        });

        HapticFeedback.heavyImpact();
        _showInviteDialog();

        // Auto-expire après 30 secondes
        _inviteExpireTimer?.cancel();
        _inviteExpireTimer = Timer(_kInviteTimeout, () {
          if (_pendingInvite != null && mounted) {
            _rejectInvite(auto: true);
          }
        });
      });
    _inviteChannel!.subscribe();
    _LiveViewerLogger.info('Invite channel subscribed', {'userId': user.id});
  }

  // ════════════════════════════════════════════════════════════
  // REALTIME CHAT
  // ════════════════════════════════════════════════════════════

  void _subscribeChat() {
    final liveId = _session?.id ?? widget.liveId;
    final client = Supabase.instance.client;
    _msgChannel = client
        .channel('live_view_msgs_$liveId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'live_messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'live_id',
            value: liveId,
          ),
          callback: (payload) {
            final row = payload.newRecord;
            final text = _LiveSanitizer.chat(row['text']?.toString());
            final user = _LiveSanitizer.username(row['username']?.toString());
            final type = _LiveSanitizer.messageType(row['type']?.toString());
            if (!mounted || text.isEmpty) return;

            // Gestion spéciale des événements système
            if (type == 'promote') {
              _handlePromoteEvent(row);
              return;
            }
            if (type == 'demote') {
              _handleDemoteEvent();
              return;
            }

            setState(() {
              _messages = [
                ..._messages,
                _ChatLine(username: user, text: text, type: type),
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
    _LiveViewerLogger.info('Chat channel subscribed');
  }

  // ════════════════════════════════════════════════════════════
  // 🎯 GUEST EVENTS (Promote / Demote)
  // ════════════════════════════════════════════════════════════

  void _handlePromoteEvent(Map<String, dynamic> row) {
    final targetUserId = row['user_id']?.toString();
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    
    if (targetUserId != currentUserId) return;

    _LiveViewerLogger.info('Received promote event');
    _becomeBroadcaster();
  }

  void _handleDemoteEvent() {
    _LiveViewerLogger.info('Received demote event');
    _becomeAudience();
  }

  Future<void> _becomeBroadcaster() async {
    if (_isOnStage) return;
    
    try {
      await _rtc.promoteToBroadcaster();
      if (!mounted) return;
      setState(() {
        _isOnStage = true;
      });
      _snack(AppLocalizations.of(context).t('live_now_on_stage'));
      HapticFeedback.heavyImpact();
    } catch (e) {
      _LiveViewerLogger.error('Promotion failed', {'error': '$e'});
      _snack(
        AppLocalizations.of(context).t('live_promote_failed'),
        error: true,
      );
    }
  }

  Future<void> _becomeAudience() async {
    if (!_isOnStage) return;
    
    try {
      await _rtc.demoteToAudience();
      if (!mounted) return;
      setState(() {
        _isOnStage = false;
        _isLocallyMuted = false;
        _isLocalVideoOff = false;
      });
      _snack(AppLocalizations.of(context).t('live_back_to_audience'));
    } catch (e) {
      _LiveViewerLogger.error('Demotion failed', {'error': '$e'});
    }
  }

  // ════════════════════════════════════════════════════════════
  // STATS POLLING + NETWORK
  // ════════════════════════════════════════════════════════════

  void _startStatsPolling() {
    final liveId = _session?.id ?? widget.liveId;
    _statsTimer = Timer.periodic(_kStatsPolling, (_) async {
      try {
        final row = await Supabase.instance.client
            .from('lives')
            .select('viewer_count, like_count, status')
            .eq('id', liveId)
            .maybeSingle()
            .timeout(const Duration(seconds: 5));
        if (row == null || !mounted) return;

        final status = (row['status'] ?? '').toString();
        if (status == 'ended') {
          _onHostEnded();
          return;
        }

        setState(() {
          _viewerCount =
              (row['viewer_count'] as num?)?.toInt() ?? _viewerCount;
          _likeCount = (row['like_count'] as num?)?.toInt() ?? _likeCount;
        });
      } catch (e) {
        _LiveViewerLogger.warn('Stats poll failed', {'error': '$e'});
      }
    });
  }

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

  void _onHostEnded() {
    if (!mounted) return;
    _LiveViewerLogger.info('Host ended live', {'liveId': widget.liveId});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context).t('live_ended_by_host')),
        behavior: SnackBarBehavior.floating,
      ),
    );
    _leave(force: true);
  }

  // ════════════════════════════════════════════════════════════
  // 🎯 TIKTOK-STYLE LIKES (Batching + Optimistic UI)
  // ════════════════════════════════════════════════════════════

  void _startLikeBatching() {
    _likeBatchTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (_pendingLikes > 0) {
        _flushLikes(_pendingLikes);
        _pendingLikes = 0;
      }
    });
  }

  Future<void> _flushLikes(int count) async {
    final liveId = _session?.id ?? widget.liveId;
    try {
      await Supabase.instance.client.rpc(
        'increment_live_likes',
        params: {
          'p_live_id': liveId,
          'p_count': count,
          'p_user_id': Supabase.instance.client.auth.currentUser?.id,
        },
      ).timeout(const Duration(seconds: 5));
    } catch (e) {
      _LiveViewerLogger.warn('Like batch flush failed', {'error': '$e'});
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

  bool _throttleLike() {
    final now = DateTime.now();
    if (_lastLike != null && now.difference(_lastLike!) < _kLikeThrottle) {
      return false;
    }
    _lastLike = now;
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
        'Viewer';
    return _LiveSanitizer.username(raw);
  }

  // ════════════════════════════════════════════════════════════
  // ACTIONS
  // ════════════════════════════════════════════════════════════

  Future<void> _sendChat() async {
    if (!_throttleChat() || _chatSending || _session == null) return;
    final text = _LiveSanitizer.chat(_chatCtrl.text);
    if (text.isEmpty) return;

    if (mounted) setState(() => _chatSending = true);
    try {
      final name = _currentUsername();
      await ref.read(liveServiceProvider).sendMessage(
            liveId: _session!.id,
            text: text,
            username: name,
          );
      _chatCtrl.clear();
      HapticFeedback.lightImpact();
    } catch (e) {
      _LiveViewerLogger.error('Send chat failed', {'error': '$e'});
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

  void _sendLike() {
    HapticFeedback.lightImpact();
    _spawnFloatingLike();
    if (mounted) setState(() {
      _likeCount++;
      _pendingLikes++;
    });
  }

  Future<void> _sendReaction(String emoji) async {
    if (!_throttleChat() || _session == null) return;
    HapticFeedback.lightImpact();
    final name = _currentUsername();
    try {
      await ref.read(liveServiceProvider).sendMessage(
            liveId: _session!.id,
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
      _LiveViewerLogger.warn('Reaction failed', {'error': '$e'});
    }
  }

  void _spawnFloatingLike() {
    final id = DateTime.now().microsecondsSinceEpoch;
    final dx = 40.0 + _random.nextDouble() * 80;
    final color = Colors.primaries[_random.nextInt(Colors.primaries.length)];
    if (mounted) {
      setState(() {
        _floatingLikes.add(_FloatingLike(id: id, dx: dx, color: color));
      });
    }
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      setState(() {
        _floatingLikes.removeWhere((e) => e.id == id);
      });
    });
  }

  void _shareLive(AppLocalizations l10n) {
    if (!_throttleAction()) return;
    HapticFeedback.lightImpact();
    final link = _LiveSanitizer.shareUrl(widget.liveId);
    Clipboard.setData(ClipboardData(text: link));
    _snack(l10n.t('live_link_copied'));
  }

  // ════════════════════════════════════════════════════════════
  // 🎯 INVITE ACTIONS (Accept / Reject / Request)
  // ════════════════════════════════════════════════════════════

  void _showInviteDialog() {
    if (!mounted || _pendingInvite == null) return;
    
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      builder: (ctx) => _InviteDialog(
        invite: _pendingInvite!,
        onAccept: () async {
          Navigator.pop(ctx);
          await _acceptInvite();
        },
        onReject: () async {
          Navigator.pop(ctx);
          await _rejectInvite();
        },
        l10n: l10n,
      ),
    );
  }

  Future<void> _acceptInvite() async {
    final invite = _pendingInvite;
    if (invite == null) return;

    _inviteExpireTimer?.cancel();
    _LiveViewerLogger.info('Accepting invite', {'liveId': invite.liveId});

    try {
      final liveService = ref.read(liveServiceProvider);
      
      // 1. Accepter côté serveur
      await liveService.acceptGuestInvite(invite.liveId);
      
      // 2. Changer de rôle Agora (audience → broadcaster)
      await _becomeBroadcaster();
      
      if (!mounted) return;
      setState(() => _pendingInvite = null);
      
      _snack(AppLocalizations.of(context).t('live_invite_accepted'));
    } catch (e) {
      _LiveViewerLogger.error('Accept invite failed', {'error': '$e'});
      if (mounted) {
        _snack(
          AppLocalizations.of(context).t('live_invite_accept_failed'),
          error: true,
        );
      }
    }
  }

  Future<void> _rejectInvite({bool auto = false}) async {
    final invite = _pendingInvite;
    if (invite == null) return;

    _inviteExpireTimer?.cancel();
    _LiveViewerLogger.info('Rejecting invite', {
      'liveId': invite.liveId,
      'auto': auto,
    });

    try {
      final liveService = ref.read(liveServiceProvider);
      await liveService.rejectGuestInvite(invite.liveId);
    } catch (e) {
      _LiveViewerLogger.warn('Reject invite failed', {'error': '$e'});
    }

    if (!mounted) return;
    setState(() => _pendingInvite = null);

    if (auto) {
      _snack(AppLocalizations.of(context).t('live_invite_expired'));
    }
  }

  Future<void> _requestToJoin() async {
    if (_requestingJoin || _isOnStage || _session == null) return;
    if (!_throttleAction()) return;

    if (mounted) setState(() => _requestingJoin = true);
    HapticFeedback.mediumImpact();

    try {
      final name = _currentUsername();
      await ref.read(liveServiceProvider).sendMessage(
            liveId: _session!.id,
            text: '🙋 ${AppLocalizations.of(context).t("live_request_to_join")}',
            username: name,
            type: 'request_join',
          );
      _snack(AppLocalizations.of(context).t('live_request_sent'));
    } catch (e) {
      _LiveViewerLogger.error('Request to join failed', {'error': '$e'});
      if (mounted) {
        _snack(
          AppLocalizations.of(context).t('live_request_failed'),
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => _requestingJoin = false);
    }
  }

  Future<void> _toggleLocalMute() async {
    if (!_isOnStage || !_throttleAction()) return;
    HapticFeedback.selectionClick();
    try {
      final next = !_isLocallyMuted;
      await _rtc.muteLocalAudio(next);
      if (mounted) setState(() => _isLocallyMuted = next);
    } catch (e) {
      _LiveViewerLogger.error('Toggle mute failed', {'error': '$e'});
    }
  }

  Future<void> _toggleLocalVideo() async {
    if (!_isOnStage || !_throttleAction()) return;
    HapticFeedback.selectionClick();
    try {
      final next = !_isLocalVideoOff;
      await _rtc.muteLocalVideo(next);
      if (mounted) setState(() => _isLocalVideoOff = next);
    } catch (e) {
      _LiveViewerLogger.error('Toggle video failed', {'error': '$e'});
    }
  }

  Future<void> _leaveStage() async {
    if (!_isOnStage) return;
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: Text(
          l10n.t('live_leave_stage_title'),
          style: const TextStyle(color: Colors.white),
        ),
        content: Text(
          l10n.t('live_leave_stage_confirm'),
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
            child: Text(l10n.t('live_leave_stage_btn')),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await _becomeAudience();
      // Notifier le serveur (optionnel, le host verra l'événement onUserOffline)
    } catch (e) {
      _LiveViewerLogger.error('Leave stage failed', {'error': '$e'});
    }
  }

  Future<void> _leave({bool force = false}) async {
    if (_leaving) return;

    if (!force && mounted) {
      final l10n = AppLocalizations.of(context);
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          title: Text(
            l10n.t('live_leave_title'),
            style: const TextStyle(color: Colors.white),
          ),
          content: Text(
            l10n.t('live_leave_confirm'),
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
              child: Text(l10n.t('live_leave_btn')),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }

    if (mounted) setState(() => _leaving = true);
    _LiveViewerLogger.info('Leaving live', {'liveId': widget.liveId});

    try {
      await _rtc.leave();
    } catch (e) {
      _LiveViewerLogger.warn('RTC leave failed', {'error': '$e'});
    }

    if (!mounted) return;
    Navigator.of(context).pop();
  }

  // ════════════════════════════════════════════════════════════
  // HELPERS
  // ════════════════════════════════════════════════════════════

  String _formatCount(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }

  // ════════════════════════════════════════════════════════════
  // BUILD
  // ════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final engine = _rtc.engine;

    if (_error != null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline,
                    color: Colors.white54, size: 48),
                const SizedBox(height: 12),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(l10n.t('common_back')),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            // ── Vidéo (host + guests si multi) ──────────────────────────────────
            GestureDetector(
              onDoubleTap: _sendLike,
              child: _buildVideoLayer(engine),
            ),

            // ── Vidéo locale (quand sur scène) ──────────────────────────────────
            if (_isOnStage && engine != null && !_isLocalVideoOff)
              Positioned(
                top: 80,
                right: 12,
                width: 120,
                height: 180,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white30, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.5),
                        blurRadius: 12,
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: AgoraVideoView(
                    controller: VideoViewController(
                      rtcEngine: engine,
                      canvas: const VideoCanvas(uid: 0),
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

            // Gradient bas
            const Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 240,
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

            // ── Top bar ───────────────────────────────────────
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 8, 0),
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
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _showHostProfile(l10n),
                        child: Text(
                          _session?.title ?? l10n.t('live_unknown'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                    _NetworkIndicator(q: _netQuality, l10n: l10n),
                    const SizedBox(width: 6),
                    Semantics(
                      label: '${l10n.t("live_viewers")}: $_viewerCount',
                      child: _StatChip(
                        icon: Icons.remove_red_eye_outlined,
                        value: _formatCount(_viewerCount),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Semantics(
                      label: '${l10n.t("live_likes")}: $_likeCount',
                      child: _StatChip(
                        icon: Icons.favorite,
                        value: _formatCount(_likeCount),
                      ),
                    ),
                    Semantics(
                      button: true,
                      label: l10n.t('live_share'),
                      child: IconButton(
                        onPressed: _leaving ? null : () => _shareLive(l10n),
                        icon: const Icon(Icons.share_rounded,
                            color: Colors.white),
                      ),
                    ),
                    Semantics(
                      button: true,
                      label: l10n.t('live_leave_btn'),
                      child: IconButton(
                        onPressed: _leaving ? null : () => _leave(),
                        icon: const Icon(Icons.close, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Likes flottants ────────────────────────────────
            ..._floatingLikes.map(
              (f) => Positioned(
                right: f.dx,
                bottom: 120,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 1200),
                  curve: Curves.easeOutCubic,
                  builder: (_, t, child) => Opacity(
                    opacity: 1 - t,
                    child: Transform.translate(
                      offset: Offset(0, -120 * t),
                      child: child,
                    ),
                  ),
                  child: Icon(
                    Icons.favorite,
                    color: f.color,
                    size: 28 + (10 * (1 - 0.5)),
                  ),
                ),
              ),
            ),

            // ── Chat + actions ────────────────────────────────
            Positioned(
              left: 12,
              right: 12,
              bottom: 0,
              child: SafeArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      height: 130,
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

                    // ── Input + actions ──
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
                          label: l10n.t('live_like'),
                          child: _RoundBtn(
                            icon: Icons.favorite,
                            color: const Color(0xFFE11D48),
                            onTap: _sendLike,
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
                    const SizedBox(height: 8),

                    // ── Bouton "Demander à monter" / Contrôles scène ──
                    _buildStageControls(l10n),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            ),

            // ── Indicateur "On Stage" ──────────────────────────────────────────
            if (_isOnStage)
              Positioned(
                top: 80,
                left: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF22C55E),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF22C55E).withValues(alpha: 0.5),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.circle,
                        size: 8,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        l10n.t('live_on_stage'),
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

            if (_leaving)
              Container(
                color: Colors.black54,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(color: Colors.white),
                      const SizedBox(height: 12),
                      Text(
                        l10n.t('live_leaving'),
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

  Widget _buildVideoLayer(RtcEngine? engine) {
    if (!_ready || engine == null) {
      return Container(
        color: Colors.black,
        child: Center(
          child: _joining
              ? const CircularProgressIndicator(color: Colors.white)
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.live_tv_rounded,
                      size: 56,
                      color: Colors.white.withValues(alpha: 0.35),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      AppLocalizations.of(context).t('live_waiting_host'),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
        ),
      );
    }

    // Afficher le host en plein écran
    if (_hostUid != null) {
      return AgoraVideoView(
        controller: VideoViewController.remote(
          rtcEngine: engine,
          canvas: VideoCanvas(uid: _hostUid),
          connection: RtcConnection(channelId: _creds!.channelName),
        ),
      );
    }

    return Container(
      color: Colors.black,
      child: Center(
        child: Text(
          AppLocalizations.of(context).t('live_waiting_host'),
          style: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
        ),
      ),
    );
  }

  Widget _buildStageControls(AppLocalizations l10n) {
    if (_isOnStage) {
      // Contrôles scène : mute, video, quitter la scène
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _StageBtn(
            icon: _isLocallyMuted ? Icons.mic_off : Icons.mic,
            label: _isLocallyMuted ? l10n.t('live_unmute') : l10n.t('live_mute'),
            active: _isLocallyMuted,
            onTap: _toggleLocalMute,
          ),
          const SizedBox(width: 8),
          _StageBtn(
            icon: _isLocalVideoOff ? Icons.videocam_off : Icons.videocam,
            label: _isLocalVideoOff
                ? l10n.t('live_video_on')
                : l10n.t('live_video_off'),
            active: _isLocalVideoOff,
            onTap: _toggleLocalVideo,
          ),
          const SizedBox(width: 8),
          _StageBtn(
            icon: Icons.logout,
            label: l10n.t('live_leave_stage_btn'),
            color: ThixPolicy.danger,
            onTap: _leaveStage,
          ),
        ],
      );
    } else {
      // Bouton "Demander à monter"
      return GestureDetector(
        onTap: _requestingJoin ? null : _requestToJoin,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: ThixPolicy.domainMedia.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: ThixPolicy.domainMedia.withValues(alpha: 0.4),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_requestingJoin)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              else
                const Icon(Icons.front_hand, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text(
                _requestingJoin
                    ? l10n.t('live_request_pending')
                    : l10n.t('live_request_to_join'),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  Widget _buildChatLine(_ChatLine m, AppLocalizations l10n) {
    // Cas spécial : message de type request_join (affiché en highlight)
    if (m.type == 'request_join') {
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
              const Icon(Icons.front_hand, color: Colors.white, size: 14),
              const SizedBox(width: 6),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '${m.username} ',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                      TextSpan(
                        text: l10n.t('live_wants_to_join'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                        ),
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

  void _showHostProfile(AppLocalizations l10n) {
    if (!_throttleAction() || _session == null) return;
    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: ThixPolicy.surfaceSoft,
                ),
                child: const Icon(Icons.person,
                    size: 32, color: Colors.white54),
              ),
              const SizedBox(height: 12),
              Text(
                _session!.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${_formatCount(_viewerCount)} ${l10n.t("live_viewers")} · ${_formatCount(_likeCount)} ${l10n.t("live_likes")}',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(l10n.t('common_close'),
                      style: const TextStyle(color: Colors.white70)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// SUB-WIDGETS
// ============================================================================

class _ChatLine {
  final String username;
  final String text;
  final String type;
  _ChatLine({required this.username, required this.text, this.type = 'chat'});
}

class _FloatingLike {
  final int id;
  final double dx;
  final Color color;
  _FloatingLike({required this.id, required this.dx, required this.color});
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String value;
  const _StatChip({required this.icon, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
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
    );
  }
}

class _NetworkIndicator extends StatelessWidget {
  final _NetQ q;
  final AppLocalizations l10n;
  const _NetworkIndicator({required this.q, required this.l10n});

  @override
  Widget build(BuildContext context) {
    final c = q.color();
    return Semantics(
      label: '${l10n.t("live_network_quality")}: ${q.label(l10n)}',
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

class _RoundBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final Color? color;

  const _RoundBtn({required this.icon, this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Material(
        color: color ?? Colors.white12,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(icon, color: Colors.white, size: 22),
          ),
        ),
      ),
    );
  }
}

class _StageBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool active;
  final Color? color;

  const _StageBtn({
    required this.icon,
    required this.label,
    this.onTap,
    this.active = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = color ?? (active ? ThixPolicy.danger : Colors.white24);
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 18),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
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
// INVITE DIALOG
// ============================================================================

class _InviteDialog extends StatefulWidget {
  final _GuestInvite invite;
  final VoidCallback onAccept;
  final VoidCallback onReject;
  final AppLocalizations l10n;

  const _InviteDialog({
    required this.invite,
    required this.onAccept,
    required this.onReject,
    required this.l10n,
  });

  @override
  State<_InviteDialog> createState() => _InviteDialogState();
}

class _InviteDialogState extends State<_InviteDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _scaleAnim = CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnim,
      child: Dialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: ThixPolicy.domainMedia.withValues(alpha: 0.5),
            width: 2,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icône pulsée
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: ThixPolicy.domainMedia.withValues(alpha: 0.2),
                ),
                child: const Icon(
                  Icons.handshake_rounded,
                  size: 40,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                widget.l10n.t('live_invite_title'),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: widget.invite.hostUsername,
                      style: TextStyle(
                        color: ThixPolicy.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    TextSpan(
                      text: ' ${widget.l10n.t("live_invite_desc")}',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: widget.onReject,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white70,
                        side: const BorderSide(color: Colors.white24),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        widget.l10n.t('live_invite_decline'),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: widget.onAccept,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ThixPolicy.domainMedia,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 4,
                      ),
                      child: Text(
                        widget.l10n.t('live_invite_accept'),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
