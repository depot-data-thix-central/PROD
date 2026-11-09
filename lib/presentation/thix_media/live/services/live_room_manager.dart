// lib/presentation/thix_media/live/services/live_room_manager.dart
//
// ============================================================================
// LIVE ROOM MANAGER — singleton global (hôte ET spectateur)
// ============================================================================
// ✅ Possède le moteur Agora : réduire la page ne coupe plus le live
// ✅ Chrono basé sur session.startedAt (ne retombe jamais à zéro)
// ✅ Service de premier plan + wake lock (audio / micro en arrière-plan)
// ✅ Chat, likes (batch), invités (co-live), demandes, stats en direct
// ✅ Détection de fin de live côté spectateur
// ============================================================================

import 'dart:async';
import 'dart:math' as math;

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'package:thix_id/data/models/live/live_model.dart';
import 'package:thix_id/services/chat/call_foreground_service.dart';

import 'live_rtc_service.dart';
import 'live_service.dart';

// ============================================================================
// CONSTANTS & HELPERS
// ============================================================================
const int kLiveMaxChat = 200;
const int _kMaxMessages = 100;
const int _kMaxGuests = 4;
const Duration _kLikeBatch = Duration(milliseconds: 400);
const Duration _kStatsPoll = Duration(seconds: 5);
const Duration _kRequestExpiry = Duration(seconds: 60);
const Duration _kRequestCooldown = Duration(seconds: 30);

final RegExp _uuidRe = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
  caseSensitive: false,
);

bool liveIsUuid(String? s) => s != null && _uuidRe.hasMatch(s);

String liveClean(String? input, {int max = kLiveMaxChat}) {
  if (input == null) return '';
  var s = input;
  String prev;
  var i = 0;
  do {
    prev = s;
    s = s
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll(RegExp(r'&[a-z]+;', caseSensitive: false), '');
    i++;
  } while (s != prev && i < 5);
  s = s
      .replaceAll(RegExp(r'javascript:', caseSensitive: false), '')
      .replaceAll(RegExp(r'vbscript:', caseSensitive: false), '')
      .replaceAll(RegExp(r'on\w+\s*=', caseSensitive: false), '')
      .replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]'), '')
      .replaceAll(RegExp(r'[\u200B-\u200F\u202A-\u202E\u2060-\u206F]'), '')
      .trim();
  return s.length > max ? s.substring(0, max) : s;
}

String liveShareUrl(String id) =>
    'https://thix.id/live/${Uri.encodeComponent(id)}';

// ============================================================================
// MODELS
// ============================================================================
enum LiveRoomRole { none, host, viewer }

enum LiveRoomPhase { idle, joining, live, ending, ended, error }

enum LiveNet { excellent, good, poor, offline }

class LiveChatLine {
  final String username;
  final String text;
  final String type;
  final String? userId;
  final DateTime timestamp;
  LiveChatLine({
    required this.username,
    required this.text,
    this.type = 'chat',
    this.userId,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

class LiveBroadcaster {
  final int uid;
  String username;
  String? userId;
  String? avatarUrl;
  bool isHost;
  bool isCoHost;
  bool videoEnabled;
  bool audioEnabled;
  LiveBroadcaster({
    required this.uid,
    required this.username,
    this.userId,
    this.avatarUrl,
    this.isHost = false,
    this.isCoHost = false,
    this.videoEnabled = true,
    this.audioEnabled = true,
  });
}

class LiveJoinRequest {
  final String userId;
  final String username;
  final String? avatarUrl;
  final DateTime receivedAt;
  LiveJoinRequest({
    required this.userId,
    required this.username,
    this.avatarUrl,
    required this.receivedAt,
  });
  bool get isExpired => DateTime.now().difference(receivedAt) > _kRequestExpiry;
}

class LiveGuestInvite {
  final String liveId;
  final String hostId;
  final String hostUsername;
  final DateTime receivedAt;
  LiveGuestInvite({
    required this.liveId,
    required this.hostId,
    required this.hostUsername,
    required this.receivedAt,
  });
}

// ============================================================================
// MANAGER
// ============================================================================
class LiveRoomManager extends ChangeNotifier with WidgetsBindingObserver {
  LiveRoomManager._();
  static final LiveRoomManager instance = LiveRoomManager._();

  /// true quand l'écran du live est ouvert (la barre réduite se masque)
  final ValueNotifier<bool> roomOpen = ValueNotifier<bool>(false);

  final StreamController<String> _fx = StreamController<String>.broadcast();

  /// Emojis à faire flotter (réactions + likes des autres)
  Stream<String> get fx => _fx.stream;

  final LiveService _svc = LiveService();
  SupabaseClient get _db => Supabase.instance.client;

  // ── État ──
  LiveRoomRole _role = LiveRoomRole.none;
  LiveRoomPhase _phase = LiveRoomPhase.idle;
  LiveSession? _session;
  AgoraCredentials? _creds;
  LiveRtcService? _rtc;
  String? _error;
  DateTime? _startedAt;
  int _viewerCount = 0;
  int _likeCount = 0;
  int _pendingLikes = 0;
  bool _muted = false;
  bool _videoOff = false;
  bool _isOnStage = false;
  bool _listenMuted = false;
  bool _reconnecting = false;
  bool _requestingJoin = false;
  DateTime? _lastRequestTime;
  LiveNet _net = LiveNet.good;

  List<LiveChatLine> _messages = [];
  final Map<int, LiveBroadcaster> _bc = {};
  final Map<String, LiveJoinRequest> _requests = {};
  final Set<String> _inviting = {};
  LiveGuestInvite? _invite;

  // ── Ressources ──
  RealtimeChannel? _msgCh;
  RealtimeChannel? _inviteCh;
  Timer? _likeTimer;
  Timer? _statsTimer;
  Timer? _cleanupTimer;
  StreamSubscription<List<ConnectivityResult>>? _netSub;
  bool _observing = false;
  bool _polling = false;

  // ── Getters ──
  LiveRoomRole get role => _role;
  LiveRoomPhase get phase => _phase;
  bool get isHost => _role == LiveRoomRole.host;
  bool get isActive =>
      _phase == LiveRoomPhase.joining || _phase == LiveRoomPhase.live;
  LiveSession? get session => _session;
  AgoraCredentials? get creds => _creds;
  RtcEngine? get engine => _rtc?.engine;
  String? get error => _error;
  int get viewerCount => _viewerCount;
  int get likeCount => _likeCount;
  bool get muted => _muted;
  bool get videoOff => _videoOff;
  bool get isOnStage => _isOnStage;
  bool get listenMuted => _listenMuted;
  bool get reconnecting => _reconnecting;
  bool get requestingJoin => _requestingJoin;
  LiveNet get net => _net;
  List<LiveChatLine> get messages => _messages;
  List<LiveBroadcaster> get broadcasters => _bc.values.toList();
  List<LiveJoinRequest> get requests =>
      _requests.values.where((r) => !r.isExpired).toList();
  Set<String> get inviting => _inviting;
  LiveGuestInvite? get invite => _invite;
  String? get myId => _db.auth.currentUser?.id;

  Duration get elapsed {
    final s = _startedAt;
    if (s == null) return Duration.zero;
    final d = DateTime.now().difference(s);
    return d.isNegative ? Duration.zero : d;
  }

  bool get canRequestToJoin =>
      _lastRequestTime == null ||
      DateTime.now().difference(_lastRequestTime!) >= _kRequestCooldown;

  String get myName {
    final u = _db.auth.currentUser;
    final raw = u?.userMetadata?['username']?.toString() ??
        u?.userMetadata?['full_name']?.toString() ??
        u?.email?.split('@').first ??
        'User';
    final c = liveClean(raw, max: 24);
    return c.isEmpty ? 'User' : c;
  }

  void _log(String m) {
    if (kDebugMode) debugPrint('[LiveRoom] $m');
  }

  // ══════════════════════════════════════════════════════════════════
  // DÉMARRAGE
  // ══════════════════════════════════════════════════════════════════
  void _begin(LiveRoomRole role, LiveSession? s, AgoraCredentials? c) {
    _role = role;
    _phase = LiveRoomPhase.joining;
    _session = s;
    _creds = c;
    _error = null;
    _startedAt = s?.startedAt;
    _viewerCount = s?.viewerCount ?? 0;
    _likeCount = s?.likeCount ?? 0;
    _pendingLikes = 0;
    _muted = false;
    _videoOff = false;
    _isOnStage = false;
    _listenMuted = false;
    _reconnecting = false;
    _requestingJoin = false;
    _messages = [];
    _bc.clear();
    _requests.clear();
    _inviting.clear();
    _invite = null;
    notifyListeners();
  }

  Future<void> startHost(LiveSession session, AgoraCredentials creds) async {
    if (isActive) {
      if (_session?.id == session.id) return;
      await leave();
    }
    _begin(LiveRoomRole.host, session, creds);
    try {
      final rtc = LiveRtcService();
      _rtc = rtc;
      await rtc.startAsHost(creds);
      _registerRtcHandlers();
      await _afterConnect();
    } catch (e) {
      await _fail(e);
    }
  }

  Future<void> joinViewer(
    String liveId, {
    LiveSession? session,
    AgoraCredentials? creds,
  }) async {
    if (isActive) {
      if (_session?.id == liveId) return;
      if (isHost) return; // l'hôte doit d'abord terminer son live
      await leave();
    }
    _begin(LiveRoomRole.viewer, session, creds);
    try {
      var s = session;
      var c = creds;
      if (s == null || c == null) {
        final r = await _svc.joinLive(liveId);
        s = r.session;
        c = r.creds;
      }
      _session = s;
      _creds = c;
      _startedAt = s.startedAt;
      _viewerCount = s.viewerCount;
      _likeCount = s.likeCount;

      final rtc = LiveRtcService();
      _rtc = rtc;
      await rtc.joinAsAudience(c);
      _registerRtcHandlers();
      await _afterConnect();
    } catch (e) {
      await _fail(e);
    }
  }

  Future<void> _afterConnect() async {
    _phase = LiveRoomPhase.live;
    notifyListeners();
    _subscribe();
    _startTimers();
    _startNetwork();
    await _startBackground();
    unawaited(_refreshGuests());
  }

  Future<void> _fail(Object e) async {
    _log('fail: $e');
    await _teardown();
    _phase = LiveRoomPhase.error;
    _error = e.toString().replaceFirst('Exception: ', '');
    notifyListeners();
  }

  /// Remet à zéro après affichage d'une erreur / fin de live
  void acknowledge() {
    if (isActive || _phase == LiveRoomPhase.ending) return;
    _role = LiveRoomRole.none;
    _phase = LiveRoomPhase.idle;
    _session = null;
    _creds = null;
    _error = null;
    _bc.clear();
    notifyListeners();
  }

  // ══════════════════════════════════════════════════════════════════
  // AGORA
  // ══════════════════════════════════════════════════════════════════
  void _registerRtcHandlers() {
    _rtc?.engine?.registerEventHandler(RtcEngineEventHandler(
      onUserJoined: (conn, uid, elapsed) {
        _bc.putIfAbsent(
          uid,
          () => LiveBroadcaster(
            uid: uid,
            username: isHost ? 'Guest' : 'Broadcaster',
          ),
        );
        notifyListeners();
        unawaited(_refreshGuests());
      },
      onUserOffline: (conn, uid, reason) {
        _bc.remove(uid);
        notifyListeners();
      },
      onRemoteVideoStateChanged: (conn, uid, state, reason, elapsed) {
        final b = _bc[uid];
        if (b == null) return;
        b.videoEnabled = state == RemoteVideoState.remoteVideoStateDecoding;
        notifyListeners();
      },
      onRemoteAudioStateChanged: (conn, uid, state, reason, elapsed) {
        final b = _bc[uid];
        if (b == null) return;
        b.audioEnabled = state == RemoteAudioState.remoteAudioStateDecoding;
        notifyListeners();
      },
      onConnectionStateChanged: (conn, st, reason) {
        final rec = st == ConnectionStateType.connectionStateReconnecting;
        if (rec != _reconnecting) {
          _reconnecting = rec;
          notifyListeners();
        }
      },
    ));
  }

  Future<void> _refreshGuests() async {
    final s = _session;
    if (s == null || !isActive) return;
    try {
      final guests = await _svc.getLiveGuests(s.id);
      final onStage =
          guests.where((g) => g.isOnStage && g.agoraUid != null).toList();
      final byUid = {for (final g in onStage) g.agoraUid!: g};

      if (isHost) {
        for (final g in onStage) {
          final uid = g.agoraUid!;
          final b = _bc.putIfAbsent(
            uid,
            () => LiveBroadcaster(uid: uid, username: g.username),
          );
          b.username = g.username;
          b.userId = g.userId;
          b.avatarUrl = g.avatarUrl;
          b.isCoHost = g.role == LiveRole.coHost;
        }
      } else {
        for (final b in _bc.values) {
          final g = byUid[b.uid];
          if (g != null) {
            b.username = g.username;
            b.userId = g.userId;
            b.avatarUrl = g.avatarUrl;
            b.isHost = false;
          } else {
            b.username = s.hostUsername;
            b.avatarUrl = s.hostAvatarUrl;
            b.isHost = true;
          }
        }
      }
      notifyListeners();
    } catch (e) {
      _log('refreshGuests: $e');
    }
  }

  // ══════════════════════════════════════════════════════════════════
  // REALTIME
  // ══════════════════════════════════════════════════════════════════
  void _subscribe() {
    final s = _session;
    if (s == null) return;
    final id = s.id;

    PostgresChangeFilter eq(String col) => PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: col,
          value: id,
        );

    _msgCh = _db
        .channel('live_room_$id')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'live_messages',
          filter: eq('live_id'),
          callback: (p) => _onMessage(p.newRecord),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'live_guests',
          filter: eq('live_id'),
          callback: (_) => unawaited(_refreshGuests()),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'lives',
          filter: eq('id'),
          callback: (p) => _applyLiveRow(Map<String, dynamic>.from(p.newRecord)),
        )
        .subscribe();

    final me = myId;
    if (!isHost && me != null) {
      _inviteCh = _db.channel('live_invite_$me')
        ..onBroadcast(
          event: 'guest_invite',
          callback: (payload) {
            final liveId = payload['live_id']?.toString();
            if (liveId != id) return;
            final hostId = payload['host_id']?.toString() ?? '';
            if (!liveIsUuid(hostId) || _isOnStage) return;
            _invite = LiveGuestInvite(
              liveId: id,
              hostId: hostId,
              hostUsername: liveClean(payload['host_username']?.toString(),
                  max: 24),
              receivedAt: DateTime.now(),
            );
            notifyListeners();
          },
        )
        ..subscribe();
    }
  }

  void _onMessage(Map<String, dynamic> row) {
    final senderId = row['user_id']?.toString();
    if (!liveIsUuid(senderId)) return;
    final text = liveClean(row['text']?.toString());
    final name = liveClean(row['username']?.toString(), max: 24);
    final type = (row['type']?.toString() ?? 'chat').toLowerCase();
    final targetId = row['target_user_id']?.toString();
    final me = myId;

    // Ciblé sur moi (spectateur)
    if (targetId != null && targetId == me && !isHost) {
      if (type == 'promote') {
        unawaited(becomeBroadcaster());
        return;
      }
      if (type == 'demote' || type == 'kick') {
        unawaited(becomeAudience());
        return;
      }
      if (type == 'invite') return;
    }

    // Demande de montée (hôte)
    if (type == 'request_join') {
      if (isHost && senderId != null) {
        _requests[senderId] = LiveJoinRequest(
          userId: senderId,
          username: name.isEmpty ? 'User' : name,
          avatarUrl: row['avatar_url']?.toString(),
          receivedAt: DateTime.now(),
        );
        notifyListeners();
      }
      return;
    }

    if (senderId == me && (type == 'chat' || type == 'reaction')) return;

    if (type == 'reaction') {
      if (text.isNotEmpty) _fx.add(text);
      return;
    }
    if (text.isEmpty || type == 'invite' || type == 'promote') return;

    _addLine(LiveChatLine(
      username: name.isEmpty ? 'User' : name,
      text: text,
      type: type,
      userId: senderId,
    ));
  }

  void _addLine(LiveChatLine l) {
    var list = [..._messages, l];
    if (list.length > _kMaxMessages) {
      list = list.sublist(list.length - _kMaxMessages);
    }
    _messages = list;
    notifyListeners();
  }

  void _applyLiveRow(Map<String, dynamic> m) {
    final status = m['status']?.toString();
    if (status != null && status != 'live' && !isHost && isActive) {
      unawaited(_remoteEnded());
      return;
    }
    var changed = false;
    final vc = (m['viewer_count'] as num?)?.toInt();
    if (vc != null && vc != _viewerCount) {
      _viewerCount = vc;
      changed = true;
    }
    final lc = (m['like_count'] as num?)?.toInt();
    if (lc != null && lc > _likeCount) {
      final burst = math.min(lc - _likeCount, 6);
      for (var i = 0; i < burst; i++) {
        _fx.add('❤️');
      }
      _likeCount = lc;
      changed = true;
    }
    if (changed) notifyListeners();
  }

  Future<void> _pollStats() async {
    final s = _session;
    if (s == null || !isActive || _polling) return;
    _polling = true;
    try {
      final row =
          await _db.from('lives').select().eq('id', s.id).maybeSingle();
      if (row != null) _applyLiveRow(Map<String, dynamic>.from(row));
    } catch (_) {
    } finally {
      _polling = false;
    }
  }

  Future<void> _remoteEnded() async {
    if (_phase == LiveRoomPhase.ended) return;
    await _teardown();
    _phase = LiveRoomPhase.ended;
    notifyListeners();
  }

  // ══════════════════════════════════════════════════════════════════
  // TIMERS / RÉSEAU / ARRIÈRE-PLAN
  // ══════════════════════════════════════════════════════════════════
  void _startTimers() {
    _likeTimer?.cancel();
    _likeTimer = Timer.periodic(_kLikeBatch, (_) => _flushLikes());

    _statsTimer?.cancel();
    _statsTimer = Timer.periodic(_kStatsPoll, (_) {
      unawaited(_pollStats());
      unawaited(_refreshGuests());
    });

    _cleanupTimer?.cancel();
    _cleanupTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      final before = _requests.length;
      _requests.removeWhere((_, r) => r.isExpired);
      if (_requests.length != before) notifyListeners();
    });
  }

  void _flushLikes() {
    final n = _pendingLikes;
    final s = _session;
    if (n <= 0 || s == null) return;
    _pendingLikes = 0;
    unawaited(_svc
        .sendLikeBatch(liveId: s.id, count: n, username: myName)
        .catchError((_) {}));
  }

  void _startNetwork() {
    unawaited(_checkNet());
    _netSub?.cancel();
    _netSub = Connectivity().onConnectivityChanged.listen(_evalNet);
  }

  Future<void> _checkNet() async {
    try {
      _evalNet(await Connectivity().checkConnectivity());
    } catch (_) {}
  }

  void _evalNet(List<ConnectivityResult> r) {
    LiveNet q;
    if (r.contains(ConnectivityResult.none)) {
      q = LiveNet.offline;
    } else if (r.contains(ConnectivityResult.wifi) ||
        r.contains(ConnectivityResult.ethernet)) {
      q = LiveNet.excellent;
    } else if (r.contains(ConnectivityResult.mobile)) {
      q = LiveNet.good;
    } else {
      q = LiveNet.poor;
    }
    if (q != _net) {
      _net = q;
      notifyListeners();
    }
  }

  Future<void> _startBackground() async {
    if (!_observing) {
      WidgetsBinding.instance.addObserver(this);
      _observing = true;
    }
    try {
      await WakelockPlus.enable();
    } catch (_) {}
    try {
      await CallForegroundService.start(video: isHost);
    } catch (e) {
      _log('foreground: $e');
    }
  }

  Future<void> _stopBackground() async {
    try {
      await WakelockPlus.disable();
    } catch (_) {}
    try {
      await CallForegroundService.stop();
    } catch (_) {}
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && isActive) {
      unawaited(_pollStats());
      unawaited(_refreshGuests());
      unawaited(_checkNet());
    }
  }

  // ══════════════════════════════════════════════════════════════════
  // ACTIONS COMMUNES
  // ══════════════════════════════════════════════════════════════════
  Future<bool> sendChat(String raw) async {
    final s = _session;
    final text = liveClean(raw);
    if (s == null || text.isEmpty) return false;
    _addLine(LiveChatLine(username: myName, text: text, userId: myId));
    try {
      await _svc.sendMessage(liveId: s.id, text: text, username: myName);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> sendReaction(String emoji) async {
    final s = _session;
    if (s == null) return;
    _fx.add(emoji);
    try {
      await _svc.sendMessage(
        liveId: s.id,
        text: emoji,
        username: myName,
        type: 'reaction',
      );
    } catch (_) {}
  }

  void like() {
    _likeCount++;
    _pendingLikes++;
    notifyListeners();
  }

  Future<void> toggleMute() async {
    final next = !_muted;
    try {
      await _rtc?.muteLocalAudio(next);
      _muted = next;
      notifyListeners();
    } catch (_) {}
  }

  Future<void> toggleVideo() async {
    final next = !_videoOff;
    try {
      await _rtc?.muteLocalVideo(next);
      _videoOff = next;
      notifyListeners();
    } catch (_) {}
  }

  Future<void> flipCamera() async {
    try {
      await _rtc?.switchCamera();
    } catch (_) {}
  }

  /// Couper / remettre le son du live (spectateur)
  Future<void> toggleListen() async {
    final next = !_listenMuted;
    try {
      await engine?.muteAllRemoteAudioStreams(next);
      _listenMuted = next;
      notifyListeners();
    } catch (_) {}
  }

  // ══════════════════════════════════════════════════════════════════
  // CO-LIVE — spectateur
  // ══════════════════════════════════════════════════════════════════
  Future<String?> requestToJoin() async {
    final s = _session;
    if (s == null || _requestingJoin || _isOnStage) return null;
    if (!canRequestToJoin) return 'cooldown';
    _requestingJoin = true;
    notifyListeners();
    try {
      await _svc.sendMessage(
        liveId: s.id,
        text: '🙋 $myName',
        username: myName,
        type: 'request_join',
      );
      _lastRequestTime = DateTime.now();
      return null;
    } catch (e) {
      return 'failed';
    } finally {
      _requestingJoin = false;
      notifyListeners();
    }
  }

  Future<void> becomeBroadcaster() async {
    if (_isOnStage) return;
    try {
      await _rtc?.promoteToBroadcaster();
      _isOnStage = true;
      _invite = null;
      notifyListeners();
    } catch (e) {
      _log('promote failed: $e');
    }
  }

  Future<void> becomeAudience() async {
    if (!_isOnStage) return;
    try {
      await _rtc?.demoteToAudience();
    } catch (_) {}
    _isOnStage = false;
    _muted = false;
    _videoOff = false;
    notifyListeners();
  }

  Future<void> acceptInvite() async {
    final inv = _invite;
    if (inv == null) return;
    try {
      await _svc.acceptGuestInvite(inv.liveId);
      await becomeBroadcaster();
    } catch (e) {
      _log('accept failed: $e');
    }
    _invite = null;
    notifyListeners();
  }

  Future<void> rejectInvite() async {
    final inv = _invite;
    if (inv == null) return;
    _invite = null;
    notifyListeners();
    try {
      await _svc.rejectGuestInvite(inv.liveId);
    } catch (_) {}
  }

  // ══════════════════════════════════════════════════════════════════
  // CO-LIVE — hôte
  // ══════════════════════════════════════════════════════════════════
  Future<String?> inviteUser(String userId, String username) async {
    final s = _session;
    if (s == null || !isHost || _inviting.contains(userId)) return null;
    if (!liveIsUuid(userId)) return 'invalid';
    if (_bc.length >= _kMaxGuests) return 'limit';
    _inviting.add(userId);
    notifyListeners();
    try {
      await _svc.promoteToGuest(liveId: s.id, guestUserId: userId);
      await _svc.sendMessage(
        liveId: s.id,
        text: username,
        username: myName,
        type: 'invite',
        targetUserId: userId,
      );
      _requests.remove(userId);
      unawaited(_refreshGuests());
      return null;
    } catch (e) {
      return 'failed';
    } finally {
      _inviting.remove(userId);
      notifyListeners();
    }
  }

  Future<String?> removeGuest(LiveBroadcaster g) async {
    final s = _session;
    final uid = g.userId;
    if (s == null || uid == null || !liveIsUuid(uid)) return 'invalid';
    try {
      await _svc.demoteToViewer(s.id, uid);
      await _svc.sendMessage(
        liveId: s.id,
        text: g.username,
        username: myName,
        type: 'kick',
        targetUserId: uid,
      );
      _bc.remove(g.uid);
      notifyListeners();
      return null;
    } catch (_) {
      return 'failed';
    }
  }

  void dismissRequest(String userId) {
    _requests.remove(userId);
    notifyListeners();
  }

  // ══════════════════════════════════════════════════════════════════
  // QUITTER / TERMINER
  // ══════════════════════════════════════════════════════════════════
  Future<void> leave() async {
    if (_phase == LiveRoomPhase.idle) return;
    _phase = LiveRoomPhase.ending;
    notifyListeners();
    await _teardown();
    _role = LiveRoomRole.none;
    _phase = LiveRoomPhase.idle;
    _session = null;
    _creds = null;
    _bc.clear();
    notifyListeners();
  }

  /// Termine le live (hôte). Retourne un message d'erreur ou null.
  Future<String?> endLive() async {
    final id = _session?.id;
    if (id == null) return null;
    _phase = LiveRoomPhase.ending;
    notifyListeners();
    try {
      await _svc.endLive(id);
    } catch (_) {
      try {
        await Future<void>.delayed(const Duration(seconds: 1));
        await _svc.endLive(id);
      } catch (e2) {
        _phase = LiveRoomPhase.live;
        notifyListeners();
        return e2.toString().replaceFirst('Exception: ', '');
      }
    }
    await _teardown();
    _role = LiveRoomRole.none;
    _phase = LiveRoomPhase.idle;
    _session = null;
    _creds = null;
    _bc.clear();
    notifyListeners();
    return null;
  }

  Future<void> _teardown() async {
    _flushLikes();
    _likeTimer?.cancel();
    _statsTimer?.cancel();
    _cleanupTimer?.cancel();
    _netSub?.cancel();
    _likeTimer = null;
    _statsTimer = null;
    _cleanupTimer = null;
    _netSub = null;

    final m = _msgCh;
    final i = _inviteCh;
    _msgCh = null;
    _inviteCh = null;
    try {
      if (m != null) await _db.removeChannel(m);
    } catch (_) {}
    try {
      if (i != null) await _db.removeChannel(i);
    } catch (_) {}

    final rtc = _rtc;
    _rtc = null;
    if (rtc != null) {
      try {
        await rtc.leave();
      } catch (_) {}
      try {
        rtc.dispose();
      } catch (_) {}
    }
    await _stopBackground();
  }
}
