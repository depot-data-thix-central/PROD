// lib/data/services/live/audio_space_manager.dart
//
// ============================================================================
// 🎙️ AUDIO SPACE MANAGER — singleton global (v3, style X Spaces)
// ============================================================================
// ✅ Propriétaire UNIQUE du moteur Agora (survit à la navigation)
// ✅ Chrono basé sur space.startedAt (ne retombe jamais à zéro)
// ✅ Audio en arrière-plan (service de premier plan + wake lock)
// ✅ Détection de qui parle (anneau animé)
// ✅ Rôles : hôte / co-hôte / intervenant / auditeur (rejoin automatique)
// ✅ Invité à parler → micro coupé au départ (comme X)
// ✅ Réseau faible : nouvelles tentatives audio, renouvellement du token,
//    synchronisation toutes les 6 s, détection de fin de salon
// ============================================================================

import 'dart:async';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:thix_id/data/models/live/audio_space_model.dart';
import 'package:thix_id/data/services/live/audio_space_background_service.dart';
import 'package:thix_id/data/services/live/audio_space_service.dart';
import 'package:thix_id/data/services/live/live_service.dart';

const Duration _kPollInterval = Duration(seconds: 6);
const int _kMaxAudioAttempts = 8;

// ════════════════════════════════════════════════════════════════════════
// STATE
// ════════════════════════════════════════════════════════════════════════
enum ManagerStatus { idle, joining, live, background, ending, ended, error }

class AudioSpaceManagerState {
  final ManagerStatus status;
  final AudioSpace? space;
  final DateTime? startedAt;
  final List<AudioSpaceParticipant> participants;
  final List<AudioSpaceChatMessage> messages;
  final AudioSpaceParticipant? me;
  final String? errorMessage;
  final Set<String> speakingUserIds;
  final bool reconnecting;
  final bool audioReady;
  final String? reactionEmoji;
  final int reactionTick;
  final String? notice;
  final int noticeTick;

  const AudioSpaceManagerState({
    this.status = ManagerStatus.idle,
    this.space,
    this.startedAt,
    this.participants = const [],
    this.messages = const [],
    this.me,
    this.errorMessage,
    this.speakingUserIds = const {},
    this.reconnecting = false,
    this.audioReady = false,
    this.reactionEmoji,
    this.reactionTick = 0,
    this.notice,
    this.noticeTick = 0,
  });

  String? get spaceId => space?.id;

  bool get isActive =>
      status == ManagerStatus.joining ||
      status == ManagerStatus.live ||
      status == ManagerStatus.background;

  bool get isInBackground => status == ManagerStatus.background;

  /// Durée depuis le DÉBUT RÉEL du salon (pas depuis mon entrée)
  Duration get elapsed {
    final s = startedAt;
    if (s == null) return Duration.zero;
    final d = DateTime.now().difference(s);
    return d.isNegative ? Duration.zero : d;
  }

  String get elapsedFormatted {
    final d = elapsed;
    String two(int v) => v.toString().padLeft(2, '0');
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    return h > 0 ? '$h:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
  }

  AudioSpaceManagerState copyWith({
    ManagerStatus? status,
    AudioSpace? space,
    DateTime? startedAt,
    List<AudioSpaceParticipant>? participants,
    List<AudioSpaceChatMessage>? messages,
    AudioSpaceParticipant? me,
    String? errorMessage,
    bool clearError = false,
    Set<String>? speakingUserIds,
    bool? reconnecting,
    bool? audioReady,
    String? reactionEmoji,
    int? reactionTick,
    String? notice,
    int? noticeTick,
  }) {
    return AudioSpaceManagerState(
      status: status ?? this.status,
      space: space ?? this.space,
      startedAt: startedAt ?? this.startedAt,
      participants: participants ?? this.participants,
      messages: messages ?? this.messages,
      me: me ?? this.me,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      speakingUserIds: speakingUserIds ?? this.speakingUserIds,
      reconnecting: reconnecting ?? this.reconnecting,
      audioReady: audioReady ?? this.audioReady,
      reactionEmoji: reactionEmoji ?? this.reactionEmoji,
      reactionTick: reactionTick ?? this.reactionTick,
      notice: notice ?? this.notice,
      noticeTick: noticeTick ?? this.noticeTick,
    );
  }
}

// ════════════════════════════════════════════════════════════════════════
// MANAGER
// ════════════════════════════════════════════════════════════════════════
class AudioSpaceManager {
  AudioSpaceManager._();
  static final AudioSpaceManager instance = AudioSpaceManager._();

  late final AudioSpaceService _service = AudioSpaceService(LiveService());
  final AudioSpaceBackgroundService _bg = AudioSpaceBackgroundService.instance;
  SupabaseClient get _db => Supabase.instance.client;

  // ── État publié ──
  final StreamController<AudioSpaceManagerState> _ctrl =
      StreamController<AudioSpaceManagerState>.broadcast();
  AudioSpaceManagerState _state = const AudioSpaceManagerState();
  AudioSpaceManagerState get state => _state;
  Stream<AudioSpaceManagerState> get stream => _ctrl.stream;

  /// true quand l'écran du salon est ouvert (la barre réduite se masque)
  final ValueNotifier<bool> roomOpen = ValueNotifier<bool>(false);

  // ── Interne ──
  RtcEngine? _engine;
  RealtimeChannel? _rt;
  RealtimeChannel? _pg;
  Timer? _poll;
  Timer? _speakClear;
  StreamSubscription<bool>? _lifeSub;

  Map<int, String> _uidToUser = {};
  bool _joining = false;
  bool _leaving = false;
  bool _audioStarting = false;
  bool _switching = false;
  bool _muteBusy = false;
  bool _talkingNow = false;
  bool _localMuted = true;
  int _audioAttempts = 0;
  int _tick = 0;
  DateTime _lastHand = DateTime.fromMillisecondsSinceEpoch(0);

  String get myId => _service.currentUserId;

  bool get isHost =>
      _state.me?.role == AudioSpaceRole.host ||
      _state.space?.hostId == myId;

  bool get canModerate =>
      isHost || _state.me?.role == AudioSpaceRole.cohost;

  void _emit(AudioSpaceManagerState s) {
    _state = s;
    if (!_ctrl.isClosed) _ctrl.add(s);
  }

  void _notice(String text) {
    _emit(_state.copyWith(notice: text, noticeTick: _state.noticeTick + 1));
  }

  String _clean(Object e) =>
      e.toString().replaceFirst('Exception: ', '').replaceFirst('StateError: ', '');

  /// Remet l'état à zéro (après une erreur / fin de salon affichée)
  void reset() {
    if (_state.isActive || _leaving) return;
    _emit(const AudioSpaceManagerState());
  }

  // ══════════════════════════════════════════════════════════════════
  // JOIN
  // ══════════════════════════════════════════════════════════════════
  Future<void> join({
    required AudioSpace space,
    required String displayName,
    String? avatarUrl,
    bool isVerified = false,
  }) async {
    if (_joining || _state.isActive || space.id.isEmpty) return;
    _joining = true;
    _leaving = false;
    _audioAttempts = 0;

    _emit(AudioSpaceManagerState(
      status: ManagerStatus.joining,
      space: space,
      startedAt: space.startedAt ?? DateTime.now(),
    ));

    try {
      if (space.isEnded || space.isCancelled) {
        throw Exception('Ce salon est terminé.');
      }

      final amHost = space.hostId == myId;
      final meRow = await _service.joinSpace(
        space,
        displayName: displayName,
        avatarUrl: avatarUrl,
        role: amHost ? AudioSpaceRole.host : AudioSpaceRole.listener,
        isMuted: !amHost,
        isVerified: isVerified,
      );
      _emit(_state.copyWith(me: meRow));

      await _refreshRoster();
      await _loadChat();
      _openRealtime(space);
      _listenChatTable(space);
      _startPoll();
      _bindBackground();
      await _bg.start(title: space.title);

      _emit(_state.copyWith(status: ManagerStatus.live, clearError: true));

      // L'audio ne bloque pas l'affichage : nouvelles tentatives en cas d'échec
      unawaited(_ensureAudio());
    } catch (e) {
      debugPrint('[SpaceManager] join failed: $e');
      final d = _detach();
      await _disposeEngine();
      try {
        await _bg.stop();
      } catch (_) {}
      _emit(_state.copyWith(
        status: ManagerStatus.error,
        errorMessage: _clean(e),
      ));
      unawaited(_closeChannels(d.rt, d.pg));
    } finally {
      _joining = false;
    }
  }

  // ══════════════════════════════════════════════════════════════════
  // AGORA
  // ══════════════════════════════════════════════════════════════════
  Future<void> _ensureAudio() async {
    if (!_state.isActive ||
        _engine != null ||
        _audioStarting ||
        _leaving ||
        _audioAttempts >= _kMaxAudioAttempts) {
      return;
    }
    final me = _state.me;
    if (me == null) return;

    _audioAttempts++;
    try {
      await _startAgora(me);
      _audioAttempts = 0;
    } catch (e) {
      debugPrint('[SpaceManager] audio attempt $_audioAttempts: $e');
      if (_audioAttempts == 1) _notice('Connexion audio en cours…');
    }
  }

  Future<void> _startAgora(
    AudioSpaceParticipant meRow, {
    bool forceMuted = false,
  }) async {
    final sp = _state.space;
    if (sp == null) return;

    var waited = 0;
    while (_audioStarting && waited < 75) {
      await Future<void>.delayed(const Duration(milliseconds: 200));
      waited++;
    }
    if (_audioStarting) return;
    _audioStarting = true;

    try {
      final talk = meRow.role.canSpeak;

      if (talk && !kIsWeb) {
        try {
          final st = await Permission.microphone.request();
          if (!st.isGranted) _notice('Autorisez le micro pour pouvoir parler.');
        } catch (_) {}
      }

      final uid = generateAgoraUid(myId);
      final creds = await _service.fetchCredentials(
        sp.channelName,
        uid: uid,
        isPublisher: talk,
      );
      if (creds.appId.isEmpty || creds.token.isEmpty) {
        throw Exception('Token Agora incomplet');
      }

      await _disposeEngine();
      if (!_state.isActive || _leaving) return;

      final engine = createAgoraRtcEngine();
      await engine.initialize(RtcEngineContext(
        appId: creds.appId,
        channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
      ));

      engine.registerEventHandler(RtcEngineEventHandler(
        onJoinChannelSuccess: (connection, elapsed) {
          debugPrint('[SpaceAgora] Joined ${connection.channelId}');
          _emit(_state.copyWith(reconnecting: false, audioReady: true));
        },
        onConnectionStateChanged: (connection, st, reason) {
          final rec = st == ConnectionStateType.connectionStateReconnecting;
          if (rec != _state.reconnecting) {
            _emit(_state.copyWith(reconnecting: rec));
          }
        },
        onAudioVolumeIndication: (connection, speakers, n, total) {
          _onVolume(speakers);
        },
        onTokenPrivilegeWillExpire: (connection, token) {
          unawaited(_renewToken());
        },
        onRequestToken: (connection) {
          unawaited(_renewToken());
        },
        onError: (err, msg) {
          debugPrint('[SpaceAgora] ERROR $err : $msg');
        },
      ));

      await engine.enableAudio();

      try {
        await engine.setAudioProfile(
          profile: AudioProfileType.audioProfileSpeechStandard,
          scenario: AudioScenarioType.audioScenarioChatroom,
        );
      } catch (_) {}
      try {
        await engine.enableAudioVolumeIndication(
          interval: 300,
          smooth: 3,
          reportVad: true,
        );
      } catch (_) {}
      if (!kIsWeb) {
        try {
          await engine.disableVideo();
        } catch (_) {}
        try {
          await engine.setEnableSpeakerphone(true);
        } catch (_) {}
      }

      final role = talk
          ? ClientRoleType.clientRoleBroadcaster
          : ClientRoleType.clientRoleAudience;
      await engine.setClientRole(role: role);

      _localMuted = forceMuted ? true : meRow.isMuted;
      await engine.muteLocalAudioStream(!talk || _localMuted);

      _engine = engine;
      _talkingNow = talk;

      try {
        await engine.joinChannel(
          token: creds.token,
          channelId: sp.channelName,
          uid: uid,
          options: ChannelMediaOptions(
            channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
            clientRoleType: role,
            publishMicrophoneTrack: talk,
            autoSubscribeAudio: true,
            autoSubscribeVideo: false,
          ),
        );
      } catch (e) {
        await _disposeEngine();
        rethrow;
      }
    } finally {
      _audioStarting = false;
    }
  }

  Future<void> _disposeEngine() async {
    final e = _engine;
    _engine = null;
    _talkingNow = false;
    if (e == null) return;
    try {
      await e.leaveChannel();
    } catch (_) {}
    try {
      await e.release();
    } catch (_) {}
  }

  Future<void> _renewToken() async {
    final sp = _state.space;
    if (sp == null || _engine == null) return;
    try {
      final creds = await _service.fetchCredentials(
        sp.channelName,
        uid: generateAgoraUid(myId),
        isPublisher: _talkingNow,
      );
      await _engine?.renewToken(creds.token);
      debugPrint('[SpaceManager] 🔑 Token renouvelé');
    } catch (e) {
      debugPrint('[SpaceManager] ⚠️ renewToken: $e');
    }
  }

  void _onVolume(List<AudioVolumeInfo> list) {
    final next = <String>{};
    for (final s in list) {
      if ((s.volume ?? 0) < 25) continue;
      final uid = s.uid ?? 0;
      final userId = uid == 0 ? myId : _uidToUser[uid];
      if (userId == null) continue;
      if (userId == myId && _localMuted) continue;
      next.add(userId);
    }
    if (!setEquals(next, _state.speakingUserIds)) {
      _emit(_state.copyWith(speakingUserIds: next));
    }
    _speakClear?.cancel();
    _speakClear = Timer(const Duration(milliseconds: 1300), () {
      if (_state.speakingUserIds.isNotEmpty) {
        _emit(_state.copyWith(speakingUserIds: <String>{}));
      }
    });
  }

  /// Mon rôle a changé (promu / rétrogradé) → on rejoint avec le bon token
  Future<void> _switchRole() async {
    if (_switching || _engine == null) return;
    final me = _state.me;
    final sp = _state.space;
    if (me == null || sp == null) return;

    _switching = true;
    try {
      final promoted = me.role.canSpeak && !_talkingNow;
      await _startAgora(me, forceMuted: promoted);

      if (promoted) {
        try {
          await _service.setMuted(
              spaceId: sp.id, targetUserId: myId, muted: true);
        } catch (_) {}
        _patchMe((p) => p.copyWith(isMuted: true));
        _notice('Vous pouvez maintenant parler. Appuyez sur le micro.');
        await _bc('roster', {});
      } else if (!me.role.canSpeak) {
        _notice('Vous êtes de nouveau auditeur.');
      }
    } catch (e) {
      debugPrint('[SpaceManager] switchRole: $e');
    } finally {
      _switching = false;
    }
  }

  // ══════════════════════════════════════════════════════════════════
  // ROSTER / SYNCHRO
  // ══════════════════════════════════════════════════════════════════
  Future<void> _refreshRoster() async {
    final sp = _state.space;
    if (sp == null) return;
    try {
      final list = await _service.listActiveParticipants(sp.id);

      AudioSpaceParticipant? mine;
      for (final p in list) {
        if (p.userId == myId) mine = p;
      }

      _uidToUser = {
        for (final p in list) generateAgoraUid(p.userId): p.userId,
      };

      _emit(_state.copyWith(participants: list, me: mine ?? _state.me));

      if (mine == null) {
        if (_state.me != null && !_leaving) await _checkBanned(sp.id);
        return;
      }

      // Changement de rôle détecté (broadcast OU synchro périodique)
      if (_engine != null &&
          !_audioStarting &&
          !_switching &&
          mine.role.canSpeak != _talkingNow) {
        unawaited(_switchRole());
      }

      // Micro coupé de force par l'hôte
      if (_engine != null &&
          _talkingNow &&
          !_muteBusy &&
          mine.isMuted != _localMuted) {
        _localMuted = mine.isMuted;
        try {
          await _engine?.muteLocalAudioStream(mine.isMuted);
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('[SpaceManager] roster: $e');
    }
  }

  Future<void> _checkBanned(String spaceId) async {
    try {
      final row = await _db
          .from('audio_space_participants')
          .select('is_banned')
          .eq('space_id', spaceId)
          .eq('user_id', myId)
          .maybeSingle();
      if (row != null && row['is_banned'] == true) {
        await _finish(ManagerStatus.error, 'Vous avez été exclu du salon.');
      }
    } catch (_) {}
  }

  Future<void> _checkEnded() async {
    final sp = _state.space;
    if (sp == null) return;
    final fresh = await _service.getSpaceById(sp.id);
    if (fresh != null && (fresh.isEnded || fresh.isCancelled)) {
      await _finish(ManagerStatus.ended, 'Salon terminé.');
    }
  }

  void _startPoll() {
    _poll?.cancel();
    _tick = 0;
    _poll = Timer.periodic(_kPollInterval, (_) async {
      if (!_state.isActive || _leaving) return;
      _tick++;
      await _refreshRoster();
      if (_tick % 3 == 0) await _checkEnded();
      await _ensureAudio();
    });
  }

  void _bindBackground() {
    _bg.onStopRequested = () => unawaited(leave());
    _bg.onMuteRequested = (m) {
      final me = _state.me;
      if (me != null && me.role.canSpeak && me.isMuted != m) {
        unawaited(toggleMute());
      }
    };
    _lifeSub?.cancel();
    _lifeSub = _bg.onAppLifecycleChanged.listen((inBackground) {
      if (!_state.isActive) return;
      _emit(_state.copyWith(
        status: inBackground ? ManagerStatus.background : ManagerStatus.live,
      ));
      if (!inBackground) {
        unawaited(_refreshRoster());
        unawaited(_loadChat());
        unawaited(_ensureAudio());
      }
    });
  }

  // ══════════════════════════════════════════════════════════════════
  // CHAT
  // ══════════════════════════════════════════════════════════════════
  Future<void> _loadChat() async {
    final sp = _state.space;
    if (sp == null) return;
    try {
      final rows = await _db
          .from('audio_space_messages')
          .select()
          .eq('space_id', sp.id)
          .order('created_at', ascending: true)
          .limit(100);
      final msgs = (rows as List)
          .map((e) =>
              AudioSpaceChatMessage.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList();
      _emit(_state.copyWith(messages: msgs));
    } catch (e) {
      debugPrint('[SpaceManager] loadChat: $e');
    }
  }

  void _listenChatTable(AudioSpace sp) {
    _pg = _db
        .channel('audio_space_msgs_${sp.id}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'audio_space_messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'space_id',
            value: sp.id,
          ),
          callback: (payload) {
            final m = Map<String, dynamic>.from(payload.newRecord);
            final body =
                AudioSpaceSanitizer.sanitize(m['body']?.toString(), maxLength: 300);
            if (body.isEmpty) return;
            final msg = AudioSpaceChatMessage(
              id: m['id']?.toString() ?? '',
              userId: m['user_id']?.toString() ?? '',
              displayName: m['display_name']?.toString() ?? 'Membre',
              body: body,
              sentAt: DateTime.tryParse(m['created_at']?.toString() ?? '') ??
                  DateTime.now(),
            );
            _appendMessage(msg);
          },
        )
        .subscribe();
  }

  void _appendMessage(AudioSpaceChatMessage msg) {
    final exists = _state.messages.any((x) =>
        (msg.id.isNotEmpty && x.id == msg.id) ||
        (x.userId == msg.userId &&
            x.body == msg.body &&
            x.sentAt.difference(msg.sentAt).inSeconds.abs() < 10));
    if (exists) return;
    var list = [..._state.messages, msg];
    if (list.length > 200) list = list.sublist(list.length - 200);
    _emit(_state.copyWith(messages: list));
  }

  Future<void> sendChat(String raw) async {
    final sp = _state.space;
    if (sp == null) return;
    final body = AudioSpaceSanitizer.sanitize(raw, maxLength: 300);
    if (body.isEmpty) return;
    final name = _state.me?.displayName ?? 'Membre';

    // Affichage immédiat (le temps réel ne renvoie pas toujours à temps)
    _appendMessage(AudioSpaceChatMessage(
      userId: myId,
      displayName: name,
      body: body,
      sentAt: DateTime.now(),
    ));
    try {
      await _service.persistChat(
        spaceId: sp.id,
        displayName: name,
        body: body,
      );
    } catch (e) {
      _notice('Message non envoyé. Vérifiez votre connexion.');
    }
  }

  // ══════════════════════════════════════════════════════════════════
  // REALTIME
  // ══════════════════════════════════════════════════════════════════
  void _openRealtime(AudioSpace sp) {
    _rt = _service.openChannel(
      spaceId: sp.id,
      onChat: (_) {},
      onReaction: (userId, emoji) {
        if (userId == myId) return;
        _emit(_state.copyWith(
          reactionEmoji: emoji,
          reactionTick: _state.reactionTick + 1,
        ));
      },
      onEnded: () => unawaited(_finish(ManagerStatus.ended, 'Salon terminé.')),
      onRosterChanged: () => unawaited(_refreshRoster()),
      onForceMute: (target, muted) async {
        if (target != myId) return;
        _localMuted = muted;
        try {
          await _engine?.muteLocalAudioStream(muted);
        } catch (_) {}
        await _refreshRoster();
      },
      onRoleChanged: (target, role) => unawaited(_refreshRoster()),
      onBanned: (target) {
        if (target == myId) {
          unawaited(_finish(ManagerStatus.error, 'Vous avez été exclu du salon.'));
        } else {
          unawaited(_refreshRoster());
        }
      },
    );
  }

  Future<void> _bc(String event, Map<String, dynamic> payload) async {
    final ch = _rt;
    if (ch == null) return;
    try {
      await _service.broadcast(ch, event, payload);
    } catch (e) {
      debugPrint('[SpaceManager] broadcast $event: $e');
    }
  }

  // ══════════════════════════════════════════════════════════════════
  // ACTIONS PARTICIPANT
  // ══════════════════════════════════════════════════════════════════
  void _patchMe(AudioSpaceParticipant Function(AudioSpaceParticipant) f) {
    final me = _state.me;
    if (me == null) return;
    final updated = f(me);
    _emit(_state.copyWith(
      me: updated,
      participants: _state.participants
          .map((p) => p.userId == myId ? updated : p)
          .toList(),
    ));
  }

  Future<void> toggleMute() async {
    final sp = _state.space;
    final me = _state.me;
    if (sp == null || me == null || !me.role.canSpeak) return;

    final next = !me.isMuted;
    _muteBusy = true;
    _localMuted = next;
    _patchMe((p) => p.copyWith(isMuted: next));
    try {
      await _engine?.muteLocalAudioStream(next);
    } catch (_) {}
    try {
      await _service.setMuted(spaceId: sp.id, targetUserId: myId, muted: next);
    } catch (e) {
      debugPrint('[SpaceManager] setMuted: $e');
    }
    await _bc('roster', {});
    _muteBusy = false;
  }

  Future<void> toggleHandRaise() async {
    final sp = _state.space;
    final me = _state.me;
    if (sp == null || me == null || me.role.canSpeak) return;
    if (DateTime.now().difference(_lastHand).inSeconds < 2) return;
    _lastHand = DateTime.now();

    final next = !me.handRaised;
    _patchMe((p) => p.copyWith(handRaised: next));
    try {
      await _service.setHandRaised(sp.id, next);
    } catch (e) {
      _notice('Demande non envoyée. Réessayez.');
    }
    await _bc('roster', {});
  }

  Future<void> sendReaction(String emoji) async {
    if (emoji.isEmpty) return;
    await _bc('reaction', {
      'emoji': emoji,
      'userId': myId,
      'timestamp': DateTime.now().toUtc().toIso8601String(),
    });
  }

  // ══════════════════════════════════════════════════════════════════
  // MODÉRATION (hôte / co-hôte)
  // ══════════════════════════════════════════════════════════════════
  Future<void> promoteToSpeaker(AudioSpaceParticipant p) async {
    final sp = _state.space;
    if (sp == null || !canModerate) return;
    try {
      await _service.promoteToSpeaker(
        space: sp,
        targetUserId: p.userId,
        targetVerified: p.isVerified,
      );
      await _bc('role', {'targetUserId': p.userId, 'role': 'speaker'});
      await _refreshRoster();
      _notice('${p.displayName} est invité à parler.');
    } catch (e) {
      _notice(_clean(e));
    }
  }

  Future<void> promoteToCohost(AudioSpaceParticipant p) async {
    final sp = _state.space;
    if (sp == null || !isHost) return;
    try {
      await _db
          .from('audio_space_participants')
          .update({'role': 'cohost', 'is_muted': true, 'hand_raised': false})
          .eq('space_id', sp.id)
          .eq('user_id', p.userId);
      await _bc('role', {'targetUserId': p.userId, 'role': 'cohost'});
      await _refreshRoster();
      _notice('${p.displayName} est maintenant co-hôte.');
    } catch (e) {
      _notice(_clean(e));
    }
  }

  Future<void> demoteToListener(AudioSpaceParticipant p) async {
    final sp = _state.space;
    if (sp == null || !canModerate || p.role == AudioSpaceRole.host) return;
    try {
      await _service.demoteToListener(spaceId: sp.id, targetUserId: p.userId);
      await _bc('role', {'targetUserId': p.userId, 'role': 'listener'});
      await _refreshRoster();
    } catch (e) {
      _notice(_clean(e));
    }
  }

  Future<void> kick(AudioSpaceParticipant p) async {
    final sp = _state.space;
    if (sp == null || !canModerate) return;
    if (p.userId == myId || p.role == AudioSpaceRole.host) return;
    try {
      await _service.banUser(spaceId: sp.id, targetUserId: p.userId);
      await _bc('banned', {'targetUserId': p.userId});
      await _refreshRoster();
    } catch (e) {
      _notice(_clean(e));
    }
  }

  Future<void> hostMute(String userId, bool muted) async {
    final sp = _state.space;
    if (sp == null || !canModerate) return;
    try {
      await _service.setMuted(
          spaceId: sp.id, targetUserId: userId, muted: muted);
      await _bc('force_mute', {'targetUserId': userId, 'muted': muted});
      await _refreshRoster();
    } catch (e) {
      _notice(_clean(e));
    }
  }

  Future<void> hostMuteAll() async {
    if (!canModerate) return;
    for (final p in _state.participants) {
      if (p.userId == myId || p.role == AudioSpaceRole.listener) continue;
      if (p.role == AudioSpaceRole.host) continue;
      await hostMute(p.userId, true);
    }
    _notice('Micros des intervenants coupés.');
  }

  // ══════════════════════════════════════════════════════════════════
  // QUITTER / TERMINER
  // ══════════════════════════════════════════════════════════════════
  /// Quitter : l'audio s'arrête tout de suite, le réseau se termine ensuite.
  Future<void> leave() async {
    final sp = _state.space;
    if (_leaving || sp == null || !_state.isActive) return;
    _leaving = true;

    final d = _detach();
    await _disposeEngine();
    try {
      await _bg.stop();
    } catch (_) {}
    _emit(const AudioSpaceManagerState());

    for (var i = 0; i < 3; i++) {
      try {
        await _service.leaveSpace(sp.id);
        break;
      } catch (_) {
        await Future<void>.delayed(Duration(seconds: i + 1));
      }
    }
    try {
      if (d.rt != null) await _service.broadcast(d.rt!, 'roster', {});
    } catch (_) {}
    await _closeChannels(d.rt, d.pg);
    _leaving = false;
  }

  /// Terminer pour tous (hôte). Lève une exception si le salon reste actif.
  Future<void> endSpace() async {
    final sp = _state.space;
    if (sp == null || !isHost || _leaving) return;
    _leaving = true;

    try {
      await _service.endSpace(sp.id);
      final check = await _service.getSpaceById(sp.id);
      if (check != null && check.isLive) {
        throw Exception('Le salon n\'a pas pu être terminé. Réessayez.');
      }
    } catch (e) {
      _leaving = false;
      rethrow;
    }

    await _bc('ended', {});
    final d = _detach();
    await _disposeEngine();
    try {
      await _bg.stop();
    } catch (_) {}
    _emit(const AudioSpaceManagerState());
    await _closeChannels(d.rt, d.pg);
    _leaving = false;
  }

  /// Fin imposée de l'extérieur (salon terminé, expulsion)
  Future<void> _finish(ManagerStatus status, String message) async {
    if (_leaving || !_state.isActive) return;
    _leaving = true;
    final d = _detach();
    await _disposeEngine();
    try {
      await _bg.stop();
    } catch (_) {}
    _emit(_state.copyWith(
      status: status,
      errorMessage: message,
      speakingUserIds: <String>{},
      reconnecting: false,
      audioReady: false,
    ));
    await _closeChannels(d.rt, d.pg);
    _leaving = false;
  }

  // ══════════════════════════════════════════════════════════════════
  // NETTOYAGE
  // ══════════════════════════════════════════════════════════════════
  ({RealtimeChannel? rt, RealtimeChannel? pg}) _detach() {
    _poll?.cancel();
    _poll = null;
    _speakClear?.cancel();
    _lifeSub?.cancel();
    _lifeSub = null;
    _bg.onStopRequested = null;
    _bg.onMuteRequested = null;
    final r = (rt: _rt, pg: _pg);
    _rt = null;
    _pg = null;
    return r;
  }

  Future<void> _closeChannels(RealtimeChannel? rt, RealtimeChannel? pg) async {
    try {
      if (pg != null) await _db.removeChannel(pg);
    } catch (_) {}
    try {
      await _service.closeChannel(rt);
    } catch (_) {}
  }
}
