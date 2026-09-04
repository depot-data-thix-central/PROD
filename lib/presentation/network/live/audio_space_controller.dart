import 'dart:async';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:thix_id/data/models/live/audio_space_model.dart';
import 'package:thix_id/data/services/live/audio_space_service.dart';

class AudioSpaceController extends StateNotifier<AudioSpaceState> {
  AudioSpaceController(this._service, this._space)
      : super(AudioSpaceState(space: _space));

  final AudioSpaceService _service;
  final AudioSpace _space;

  RtcEngine? _engine;
  RealtimeChannel? _rt;
  RealtimeChannel? _pg;
  Timer? _rosterTick;
  DateTime _lastHand = DateTime.fromMillisecondsSinceEpoch(0);

  String get me => _service.currentUserId;
  bool get isHost => state.me?.role == AudioSpaceRole.host || _space.hostId == me;

  Future<void> bootstrap({
    required String displayName,
    String? avatarUrl,
    bool isVerified = false,
  }) async {
    state = state.copyWith(loading: true, error: null);
    try {
      final meRow = await _service.joinSpace(
        _space,
        displayName: displayName,
        avatarUrl: avatarUrl,
        role: _space.hostId == me ? AudioSpaceRole.host : AudioSpaceRole.listener,
        isMuted: _space.hostId != me,
        isVerified: isVerified,
      );

      await _loadRoster();
      await _loadChat();
      await _startAgora(meRow);
      _listenRealtime();
      _listenChatTable();
      _rosterTick = Timer.periodic(const Duration(seconds: 8), (_) => _loadRoster());

      state = state.copyWith(loading: false, me: meRow, connected: true);
    } catch (e) {
      debugPrint('[AudioSpace] bootstrap: ' + e.toString());
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  Future<void> _startAgora(AudioSpaceParticipant meRow) async {
    final creds = await _service.fetchCredentials(_space.channelName);
    _engine = createAgoraRtcEngine();
    await _engine!.initialize(RtcEngineContext(
      appId: creds.appId,
      channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
    ));
    await _engine!.enableAudio();
    await _engine!.disableVideo();
    await _engine!.setEnableSpeakerphone(true);

    final canTalk = meRow.role == AudioSpaceRole.host ||
        meRow.role == AudioSpaceRole.cohost ||
        meRow.role == AudioSpaceRole.speaker;

    await _engine!.setClientRole(
      role: canTalk
          ? ClientRoleType.clientRoleBroadcaster
          : ClientRoleType.clientRoleAudience,
    );
    await _engine!.muteLocalAudioStream(!canTalk || meRow.isMuted);

    await _engine!.joinChannel(
      token: creds.token,
      channelId: _space.channelName,
      uid: 0,
      options: const ChannelMediaOptions(
        publishMicrophoneTrack: true,
        autoSubscribeAudio: true,
        autoSubscribeVideo: false,
      ),
    );
  }

  Future<void> _loadRoster() async {
    final list = await _service.listActiveParticipants(_space.id);
    AudioSpaceParticipant? mine;
    for (final p in list) {
      if (p.userId == me) mine = p;
    }
    state = state.copyWith(participants: list, me: mine ?? state.me);
  }

  Future<void> _loadChat() async {
    final rows = await Supabase.instance.client
        .from('audio_space_messages')
        .select()
        .eq('space_id', _space.id)
        .order('created_at', ascending: true)
        .limit(80);
    final msgs = (rows as List).map((e) {
      final m = Map<String, dynamic>.from(e as Map);
      return AudioSpaceChatMessage(
        userId: m['user_id']?.toString() ?? '',
        displayName: m['display_name']?.toString() ?? 'Membre',
        body: m['body']?.toString() ?? '',
        sentAt: DateTime.tryParse(m['created_at']?.toString() ?? '') ?? DateTime.now(),
      );
    }).toList();
    state = state.copyWith(messages: msgs);
  }

  void _listenChatTable() {
    _pg = Supabase.instance.client
        .channel('audio_space_msgs_' + _space.id)
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'audio_space_messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'space_id',
            value: _space.id,
          ),
          callback: (payload) {
            final m = payload.newRecord;
            final body = AudioSpaceSanitizer.sanitize(m['body']?.toString(), maxLength: 300);
            if (body.isEmpty) return;
            final msg = AudioSpaceChatMessage(
              userId: m['user_id']?.toString() ?? '',
              displayName: m['display_name']?.toString() ?? 'Membre',
              body: body,
              sentAt: DateTime.tryParse(m['created_at']?.toString() ?? '') ?? DateTime.now(),
            );
            final exists = state.messages.any((x) =>
                x.userId == msg.userId &&
                x.body == msg.body &&
                (x.sentAt.difference(msg.sentAt).inSeconds).abs() < 2);
            if (exists) return;
            state = state.copyWith(messages: [...state.messages, msg]);
          },
        )
        .subscribe();
  }

  void _listenRealtime() {
    _rt = _service.openChannel(
      spaceId: _space.id,
      onChat: (_) {},
      onEnded: () => state = state.copyWith(ended: true),
      onRosterChanged: _loadRoster,
      onForceMute: (target, muted) async {
        if (target != me) return;
        await _engine?.muteLocalAudioStream(muted);
        await _loadRoster();
      },
      onRoleChanged: (target, role) async {
        if (target != me) {
          await _loadRoster();
          return;
        }
        final talk = role == 'host' || role == 'cohost' || role == 'speaker';
        await _engine?.setClientRole(
          role: talk
              ? ClientRoleType.clientRoleBroadcaster
              : ClientRoleType.clientRoleAudience,
        );
        await _engine?.muteLocalAudioStream(!talk);
        await _loadRoster();
      },
      onBanned: (target) {
        if (target == me) state = state.copyWith(ended: true, error: 'Vous avez été exclu.');
      },
    );
  }

  Future<void> sendChat(String raw) async {
    final body = AudioSpaceSanitizer.sanitize(raw, maxLength: 300);
    if (body.isEmpty || state.me == null) return;
    await _service.persistChat(
      spaceId: _space.id,
      displayName: state.me!.displayName,
      body: body,
    );
  }

  Future<void> toggleMute() async {
    final mine = state.me;
    if (mine == null || !mine.canSpeak) return;
    final next = !mine.isMuted;
    await _service.setMuted(spaceId: _space.id, targetUserId: me, muted: next);
    await _engine?.muteLocalAudioStream(next);
    await _rtBroadcast('roster', {});
    await _loadRoster();
  }

  Future<void> raiseHand() async {
    if (DateTime.now().difference(_lastHand).inSeconds < 8) return;
    _lastHand = DateTime.now();
    await _service.setHandRaised(_space.id, !(state.me?.handRaised ?? false));
    await _rtBroadcast('roster', {});
    await _loadRoster();
  }

  Future<void> hostMute(String userId, bool muted) async {
    if (!isHost) return;
    await _service.setMuted(spaceId: _space.id, targetUserId: userId, muted: muted);
    await _rtBroadcast('force_mute', {'targetUserId': userId, 'muted': muted});
    await _loadRoster();
  }

  Future<void> hostMuteAll() async {
    if (!isHost) return;
    for (final p in state.speakers) {
      if (p.userId == me) continue;
      await hostMute(p.userId, true);
    }
  }

  Future<void> approveSpeaker(AudioSpaceParticipant p) async {
    if (!isHost) return;
    await _service.promoteToSpeaker(
      space: state.space,
      targetUserId: p.userId,
      targetVerified: p.isVerified,
    );
    await _rtBroadcast('role', {'targetUserId': p.userId, 'role': 'speaker'});
    await _loadRoster();
  }

  Future<void> demote(String userId) async {
    if (!isHost) return;
    await _service.demoteToListener(spaceId: _space.id, targetUserId: userId);
    await _rtBroadcast('role', {'targetUserId': userId, 'role': 'listener'});
    await _loadRoster();
  }

  Future<void> kick(String userId) async {
    if (!isHost || userId == me) return;
    await _service.banUser(spaceId: _space.id, targetUserId: userId);
    await _rtBroadcast('banned', {'targetUserId': userId});
    await _loadRoster();
  }

  Future<void> endSpace() async {
    if (!isHost) return;
    await _service.endSpace(_space.id);
    await _rtBroadcast('ended', {});
    state = state.copyWith(ended: true);
  }

  Future<void> leave() async {
    await _service.leaveSpace(_space.id);
    await _rtBroadcast('roster', {});
    await disposeEngine();
  }

  Future<void> _rtBroadcast(String event, Map<String, dynamic> payload) async {
    final ch = _rt;
    if (ch == null) return;
    await _service.broadcast(ch, event, payload);
  }

  Future<void> disposeEngine() async {
    _rosterTick?.cancel();
    try {
      await _pg?.unsubscribe();
    } catch (_) {}
    try {
      await _rt?.unsubscribe();
    } catch (_) {}
    try {
      await _engine?.leaveChannel();
      await _engine?.release();
    } catch (_) {}
    _engine = null;
  }

  @override
  void dispose() {
    disposeEngine();
    super.dispose();
  }
}

final audioSpaceControllerProvider = StateNotifierProvider.autoDispose
    .family<AudioSpaceController, AudioSpaceState, AudioSpace>((ref, space) {
  final c = AudioSpaceController(ref.read(audioSpaceServiceProvider), space);
  ref.onDispose(c.disposeEngine);
  return c;
});
