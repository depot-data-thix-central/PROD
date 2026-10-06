// lib/data/services/live/audio_space_manager.dart
//
// ============================================================================
// 🧠 AUDIO SPACE MANAGER — Singleton global (Production)
// ============================================================================
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:thix_id/data/models/live/audio_space_model.dart';
import 'package:thix_id/data/services/live/audio_space_service.dart';
import 'package:thix_id/data/services/live/audio_space_background_service.dart';
import 'package:thix_id/data/services/live/live_service.dart';

enum ManagerStatus {
  idle,
  joining,
  live,
  background,
  ending,
  error,
}

class AudioSpaceManagerState {
  final ManagerStatus status;
  final AudioSpace? space;
  final AudioSpaceParticipant? me;
  final List<AudioSpaceParticipant> participants;
  final List<AudioSpaceChatMessage> messages;
  final bool isInBackground;
  final DateTime? startedAt;
  final String? errorMessage;

  const AudioSpaceManagerState({
    this.status = ManagerStatus.idle,
    this.space,
    this.me,
    this.participants = const [],
    this.messages = const [],
    this.isInBackground = false,
    this.startedAt,
    this.errorMessage,
  });

  bool get isActive =>
      status == ManagerStatus.live || status == ManagerStatus.background;
  bool get isHost =>
      me?.role == AudioSpaceRole.host || space?.hostId == me?.userId;
  String? get spaceId => space?.id;
  Duration get elapsed => startedAt == null
      ? Duration.zero
      : DateTime.now().difference(startedAt!);

  String get elapsedFormatted {
    if (startedAt == null) return '00:00';
    final d = DateTime.now().difference(startedAt!);
    String two(int v) => v.toString().padLeft(2, '0');
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    return h > 0 ? '$h:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
  }

  AudioSpaceManagerState copyWith({
    ManagerStatus? status,
    AudioSpace? space,
    AudioSpaceParticipant? me,
    List<AudioSpaceParticipant>? participants,
    List<AudioSpaceChatMessage>? messages,
    bool? isInBackground,
    DateTime? startedAt,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AudioSpaceManagerState(
      status: status ?? this.status,
      space: space ?? this.space,
      me: me ?? this.me,
      participants: participants ?? this.participants,
      messages: messages ?? this.messages,
      isInBackground: isInBackground ?? this.isInBackground,
      startedAt: startedAt ?? this.startedAt,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  static const AudioSpaceManagerState initial = AudioSpaceManagerState();
}

class AudioSpaceManager {
  AudioSpaceManager._internal() {
    _init();
  }

  static final AudioSpaceManager instance = AudioSpaceManager._internal();

  late final LiveService _liveService;
  late final AudioSpaceService _service;
  late final AudioSpaceBackgroundService _backgroundService;

  final StreamController<AudioSpaceManagerState> _controller =
      StreamController<AudioSpaceManagerState>.broadcast();

  AudioSpaceManagerState _state = AudioSpaceManagerState.initial;
  AudioSpaceManagerState get state => _state;
  Stream<AudioSpaceManagerState> get stream => _controller.stream;

  RealtimeChannel? _rtChannel;
  RealtimeChannel? _pgChannel;
  Timer? _rosterTick;
  Timer? _elapsedTick;
  DateTime _lastHandRaise = DateTime.fromMillisecondsSinceEpoch(0);

  // ─────────────────────────────────────────────────────────────
  // INITIALISATION
  // ─────────────────────────────────────────────────────────────
  void _init() {
    _liveService = LiveService();
    _service = AudioSpaceService(_liveService);
    _backgroundService = AudioSpaceBackgroundService();
    _backgroundService.onAppLifecycleChanged.listen(_onAppLifecycleChanged);
  }

  void _emit() {
    if (!_controller.isClosed) {
      _controller.add(_state);
    }
  }

  // ─────────────────────────────────────────────────────────────
  // CYCLE DE VIE APP
  // ─────────────────────────────────────────────────────────────
  void _onAppLifecycleChanged(bool isInBackground) {
    if (!_state.isActive) return;

    _state = _state.copyWith(isInBackground: isInBackground);

    if (isInBackground) {
      _state = _state.copyWith(status: ManagerStatus.background);
      _backgroundService.enterBackgroundMode(
        spaceId: _state.spaceId!,
        spaceTitle: _state.space?.title ?? 'Space audio',
        isHost: _state.isHost,
      );
    } else {
      _state = _state.copyWith(status: ManagerStatus.live);
      _backgroundService.exitBackgroundMode();
      _recoverSupabaseSession();
      _loadRoster();
    }
    _emit();
  }

  Future<void> _recoverSupabaseSession() async {
    try {
      final session = Supabase.instance.client.auth.currentSession;
      if (session == null || session.isExpired) {
        await Supabase.instance.client.auth.refreshSession();
        debugPrint('[AudioSpaceManager] ✓ Session Supabase rafraîchie');
      }
    } catch (e) {
      debugPrint('[AudioSpaceManager] ⚠️ refreshSession: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────
  // REJOINDRE UN SPACE
  // ─────────────────────────────────────────────────────────────
  Future<void> join({
    required AudioSpace space,
    required String displayName,
    String? avatarUrl,
    bool isVerified = false,
  }) async {
    if (_state.isActive) {
      debugPrint('[AudioSpaceManager] ⚠️ Déjà dans un space');
      return;
    }

    _state = _state.copyWith(
      status: ManagerStatus.joining,
      space: space,
      clearError: true,
    );
    _emit();

    try {
      final isHost = space.hostId == _service.currentUserId;
      final meRow = await _service.joinSpace(
        space,
        displayName: displayName,
        avatarUrl: avatarUrl,
        role: isHost ? AudioSpaceRole.host : AudioSpaceRole.listener,
        isMuted: !isHost,
        isVerified: isVerified,
      );

      _state = _state.copyWith(me: meRow, startedAt: DateTime.now());

      await Future.wait([_loadRoster(), _loadChat()]);
      _listenRealtime();
      _listenChatTable();

      _rosterTick?.cancel();
      _rosterTick = Timer.periodic(
        const Duration(seconds: 10),
        (_) => _loadRoster(),
      );
      _elapsedTick?.cancel();
      _elapsedTick = Timer.periodic(
        const Duration(seconds: 1),
        (_) => _emit(),
      );

      await _backgroundService.startAgora(
        space: space,
        me: meRow,
        isHost: isHost,
      );
      await _backgroundService.prepareBackgroundMode();

      _state = _state.copyWith(status: ManagerStatus.live);
      _emit();

      debugPrint(
          '[AudioSpaceManager] ✓ Rejoint ${space.title} (${isHost ? "hôte" : "participant"})');
    } catch (e, st) {
      debugPrint('[AudioSpaceManager] ✗ join failed: $e\n$st');
      _state = _state.copyWith(
        status: ManagerStatus.error,
        errorMessage: e.toString(),
        space: null,
        me: null,
      );
      _emit();
    }
  }

  // ─────────────────────────────────────────────────────────────
  // QUITTER / TERMINER
  // ─────────────────────────────────────────────────────────────
  Future<void> leave() async {
    if (!_state.isActive) return;
    final spaceId = _state.spaceId;
    if (spaceId == null) return;

    try {
      await _service.leaveSpace(spaceId);
    } catch (e) {
      debugPrint('[AudioSpaceManager] leaveSpace error: $e');
    }
    await _broadcastRosterChange();
    await _cleanup();
  }

  Future<void> endSpace() async {
    if (!_state.isActive || !_state.isHost) return;
    final spaceId = _state.spaceId;
    final channelName = _state.space?.channelName;

    if (spaceId == null) {
      await _cleanup();
      return;
    }

    _state = _state.copyWith(status: ManagerStatus.ending);
    _emit();

    try {
      // ✅ Appel RPC SQL pour fermer le salon côté serveur
      if (channelName != null && channelName.isNotEmpty) {
        await Supabase.instance.client
            .rpc('end_audio_space', params: {'p_channel_name': channelName})
            .timeout(const Duration(seconds: 10));
        debugPrint(
            '[AudioSpaceManager] ✓ Salon fermé via RPC: $channelName');
      }

      // Fallback via service standard
      await _service.endSpace(spaceId);
      await _broadcast('ended', {});
    } catch (e) {
      debugPrint('[AudioSpaceManager] ❌ endSpace error: $e');
    } finally {
      await _cleanup();
    }
  }

  // ─────────────────────────────────────────────────────────────
  // CLEANUP (Unique définition)
  // ─────────────────────────────────────────────────────────────
  Future<void> _cleanup() async {
    _rosterTick?.cancel();
    _rosterTick = null;
    _elapsedTick?.cancel();
    _elapsedTick = null;

    try {
      await _rtChannel?.unsubscribe();
    } catch (_) {}
    try {
      await _pgChannel?.unsubscribe();
    } catch (_) {}
    _rtChannel = null;
    _pgChannel = null;

    await _backgroundService.stopAgora();
    _backgroundService.exitBackgroundMode();

    _state = AudioSpaceManagerState.initial;
    _emit();

    debugPrint('[AudioSpaceManager] ✓ Cleanup completed');
  }

  // ─────────────────────────────────────────────────────────────
  // ROSTER & CHAT
  // ─────────────────────────────────────────────────────────────
  Future<void> _loadRoster() async {
    final spaceId = _state.spaceId;
    if (spaceId == null) return;

    try {
      final list = await _service.listActiveParticipants(spaceId);
      AudioSpaceParticipant? mine;
      for (final p in list) {
        if (p.userId == _service.currentUserId) {
          mine = p;
          break;
        }
      }
      _state = _state.copyWith(participants: list, me: mine ?? _state.me);
      _emit();
    } catch (e) {
      debugPrint('[AudioSpaceManager] _loadRoster error: $e');
    }
  }

  Future<void> _loadChat() async {
    final spaceId = _state.spaceId;
    if (spaceId == null) return;

    try {
      final rows = await Supabase.instance.client
          .from('audio_space_messages')
          .select()
          .eq('space_id', spaceId)
          .order('created_at', ascending: true)
          .limit(80);

      final msgs = (rows as List).map((e) {
        final m = Map<String, dynamic>.from(e as Map);
        return AudioSpaceChatMessage(
          userId: m['user_id']?.toString() ?? '',
          displayName: m['display_name']?.toString() ?? 'Membre',
          body: m['body']?.toString() ?? '',
          sentAt:
              DateTime.tryParse(m['created_at']?.toString() ?? '') ?? DateTime.now(),
        );
      }).toList();

      _state = _state.copyWith(messages: msgs);
      _emit();
    } catch (e) {
      debugPrint('[AudioSpaceManager] _loadChat error: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────
  // ACTIONS PUBLIQUES
  // ─────────────────────────────────────────────────────────────
  Future<void> sendChat(String raw) async {
    final spaceId = _state.spaceId;
    if (spaceId == null) return;
    final body = AudioSpaceSanitizer.sanitize(raw, maxLength: 300);
    if (body.isEmpty) return;
    final name = _state.me?.displayName ?? 'Membre';
    await _service.persistChat(spaceId: spaceId, displayName: name, body: body);
  }

  Future<void> sendReaction(String emoji) async {
    await _broadcast('reaction', {'emoji': emoji, 'userId': _service.currentUserId});
  }

  Future<void> toggleMute() async {
    final me = _state.me;
    if (me == null) return;
    final canSpeak = me.role == AudioSpaceRole.host ||
        me.role == AudioSpaceRole.cohost ||
        me.role == AudioSpaceRole.speaker;
    if (!canSpeak && !_state.isHost) return;

    final next = !me.isMuted;
    await _service.setMuted(
      spaceId: _state.spaceId!,
      targetUserId: me.userId,
      muted: next,
    );
    await _backgroundService.setMuted(next);
    await _broadcastRosterChange();
    await _loadRoster();
  }

  Future<void> toggleHandRaise() async {
    if (DateTime.now().difference(_lastHandRaise).inSeconds < 8) return;
    _lastHandRaise = DateTime.now();
    final me = _state.me;
    if (me == null) return;

    await _service.setHandRaised(_state.spaceId!, !me.handRaised);
    await _broadcastRosterChange();
    await _loadRoster();
  }

  Future<void> promoteToSpeaker(AudioSpaceParticipant p) async {
    if (!_state.isHost) return;
    await _service.promoteToSpeaker(
      space: _state.space!,
      targetUserId: p.userId,
      targetVerified: p.isVerified,
    );
    await _broadcast('role', {'targetUserId': p.userId, 'role': 'speaker'});
    await _loadRoster();
  }

  Future<void> demoteToListener(dynamic target) async {
    if (!_state.isHost) return;
    final userId =
        target is AudioSpaceParticipant ? target.userId : target.toString();
    await _service.demoteToListener(
      spaceId: _state.spaceId!,
      targetUserId: userId,
    );
    await _broadcast('role', {'targetUserId': userId, 'role': 'listener'});
    await _loadRoster();
  }

  Future<void> kick(dynamic target) async {
    if (!_state.isHost) return;
    final userId =
        target is AudioSpaceParticipant ? target.userId : target.toString();
    if (userId == _service.currentUserId) return;

    await _service.banUser(spaceId: _state.spaceId!, targetUserId: userId);
    await _broadcast('banned', {'targetUserId': userId});
    await _loadRoster();
  }

  Future<void> hostMute(String userId, bool muted) async {
    if (!_state.isHost) return;
    await _service.setMuted(
      spaceId: _state.spaceId!,
      targetUserId: userId,
      muted: muted,
    );
    await _broadcast('force_mute', {'targetUserId': userId, 'muted': muted});
    await _loadRoster();
  }

  Future<void> hostMuteAll() async {
    if (!_state.isHost) return;
    for (final p in _state.participants) {
      if (p.userId == _service.currentUserId) continue;
      if (p.role == AudioSpaceRole.listener) continue;
      await hostMute(p.userId, true);
    }
  }

  Future<void> acceptHandRaise(AudioSpaceParticipant p) => promoteToSpeaker(p);

  // ─────────────────────────────────────────────────────────────
  // REALTIME
  // ─────────────────────────────────────────────────────────────
  void _listenRealtime() {
    final spaceId = _state.spaceId;
    if (spaceId == null) return;

    _rtChannel = _service.openChannel(
      spaceId: spaceId,
      onChat: (_) {},
      onReaction: (userId, emoji) {
        if (userId == _service.currentUserId) return;
        _emit();
      },
      onEnded: () async {
        _state = _state.copyWith(
          status: ManagerStatus.error,
          errorMessage: 'Salon terminé par l\'hôte.',
        );
        _emit();
        await _cleanup();
      },
      onRosterChanged: _loadRoster,
      onForceMute: (target, muted) async {
        if (target != _service.currentUserId) return;
        await _backgroundService.setMuted(muted);
        await _loadRoster();
      },
      onRoleChanged: (target, role) async {
        if (target == _service.currentUserId) {
          await _loadRoster();
          await _backgroundService.onMyRoleChanged(
            newRole: role,
            space: _state.space!,
            me: _state.me!,
          );
        } else {
          await _loadRoster();
        }
      },
      onBanned: (target) async {
        if (target != _service.currentUserId) return;
        _state = _state.copyWith(
          status: ManagerStatus.error,
          errorMessage: 'Vous avez été exclu du salon.',
        );
        _emit();
        await _cleanup();
      },
    );
  }

  void _listenChatTable() {
    final spaceId = _state.spaceId;
    if (spaceId == null) return;

    _pgChannel = Supabase.instance.client
        .channel('audio_space_msgs_$spaceId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'audio_space_messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'space_id',
            value: spaceId,
          ),
          callback: (payload) {
            final m = payload.newRecord;
            final body = AudioSpaceSanitizer.sanitize(
              m['body']?.toString(),
              maxLength: 300,
            );
            if (body.isEmpty) return;
            final msg = AudioSpaceChatMessage(
              userId: m['user_id']?.toString() ?? '',
              displayName: m['display_name']?.toString() ?? 'Membre',
              body: body,
              sentAt: DateTime.tryParse(m['created_at']?.toString() ?? '') ??
                  DateTime.now(),
            );
            final exists = _state.messages.any((x) =>
                x.userId == msg.userId &&
                x.body == msg.body &&
                x.sentAt.difference(msg.sentAt).inSeconds.abs() < 2);
            if (exists) return;

            _state = _state.copyWith(messages: [..._state.messages, msg]);
            _emit();
          },
        )
        .subscribe();
  }

  Future<void> _broadcastRosterChange() => _broadcast('roster', {});

  Future<void> _broadcast(String event, Map<String, dynamic> payload) async {
    final ch = _rtChannel;
    if (ch == null) return;
    try {
      await _service.broadcast(ch, event, payload);
    } catch (e) {
      debugPrint('[AudioSpaceManager] broadcast error: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────
  // DISPOSE
  // ─────────────────────────────────────────────────────────────
  Future<void> dispose() async {
    await _cleanup();
    await _controller.close();
  }
}
