// lib/presentation/thix_media/live/pages/live_room_view.dart
//
// ============================================================================
// LIVE ROOM VIEW — interface TikTok Live (hôte ET spectateur)
// ============================================================================
// ✅ Pilule hôte (avatar, nom, sceau, Suivre) + chrono + J'aime + spectateurs
// ✅ Réduire (chevron / retour) : le live continue, barre « Live en cours »
// ✅ Rail d'actions à droite (J'aime maintenu, commentaires, partage, co-live)
// ✅ Chat en overlay avec fondu, saisie en bas, réactions flottantes
// ✅ Multi-invités (grille 1 → 5), panneau invités / demandes (hôte)
// ✅ Double tap = J'aime, mode épuré, son du live coupable
// ============================================================================

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show FontFeature;

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/data/models/live/live_model.dart';
import 'package:thix_id/l10n/app_localizations.dart';
import 'package:thix_id/presentation/thix_media/providers/thix_media_provider.dart';
import 'package:thix_id/presentation/thix_media/widgets/media_cert_badge.dart';
import 'package:thix_id/services/media_service.dart';

import '../services/live_room_manager.dart';

const Color _kLiveRed = Color(0xFFE11D48);
const Duration _kChatThrottle = Duration(milliseconds: 80);
const Duration _kActionThrottle = Duration(milliseconds: 250);
const Duration _kLikeRepeat = Duration(milliseconds: 110);
const List<String> _kReactions = ['❤️', '🔥', '👏', '😂', '😮', '🎉'];

String _t(AppLocalizations l, String k, String fb) {
  final v = l.t(k);
  return (v.isEmpty || v == k) ? fb : v;
}

String _fmt(Duration d) {
  String two(int v) => v.toString().padLeft(2, '0');
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  final s = d.inSeconds.remainder(60);
  return h > 0 ? '$h:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
}

String _cnt(int n) {
  if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
  if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
  return '$n';
}

class LiveRoomView extends ConsumerStatefulWidget {
  final bool isHost;
  final String? liveId;
  final LiveSession? session;
  final AgoraCredentials? creds;

  const LiveRoomView({
    super.key,
    required this.isHost,
    this.liveId,
    this.session,
    this.creds,
  });

  @override
  ConsumerState<LiveRoomView> createState() => _LiveRoomViewState();
}

class _Heart {
  final int id;
  final String emoji;
  final double dx;
  _Heart(this.id, this.emoji, this.dx);
}

class _LiveRoomViewState extends ConsumerState<LiveRoomView> {
  final LiveRoomManager _m = LiveRoomManager.instance;
  final _chatCtrl = TextEditingController();
  final _random = math.Random();
  final List<_Heart> _hearts = [];
  int _heartSeq = 0;

  StreamSubscription<String>? _fxSub;
  Timer? _tick;
  Timer? _likeHold;
  DateTime? _lastChat;
  DateTime? _lastAction;

  bool _showReactions = false;
  bool _hideUi = false;
  bool _chatSending = false;
  bool _closing = false;
  bool _inviteShown = false;
  final Set<String> _followed = {};

  @override
  void initState() {
    super.initState();
    _m.addListener(_onManager);
    _fxSub = _m.fx.listen((e) => _spawn(e));
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _m.roomOpen.value = true;
    });
    Future.microtask(_start);
  }

  @override
  void dispose() {
    _m.removeListener(_onManager);
    _fxSub?.cancel();
    _tick?.cancel();
    _likeHold?.cancel();
    _chatCtrl.dispose();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _m.roomOpen.value = false;
    });
    super.dispose();
  }

  // ════════════════════════════════════════════════════════════
  // DÉMARRAGE / ÉVÉNEMENTS
  // ════════════════════════════════════════════════════════════
  Future<void> _start() async {
    if (!mounted) return;
    if (widget.isHost) {
      if (_m.isActive && _m.isHost) return; // reprise depuis la barre
      final s = widget.session;
      final c = widget.creds;
      if (s != null && c != null) {
        await _m.startHost(s, c);
      } else if (mounted) {
        Navigator.of(context).maybePop();
      }
      return;
    }

    final id = widget.liveId ?? widget.session?.id;
    if (id == null) {
      if (mounted) Navigator.of(context).maybePop();
      return;
    }
    if (_m.isActive && _m.isHost) {
      _snack('Terminez d\'abord votre live en cours.', error: true);
      if (mounted) Navigator.of(context).maybePop();
      return;
    }
    await _m.joinViewer(id, session: widget.session, creds: widget.creds);
  }

  void _onManager() {
    if (!mounted) return;
    setState(() {});

    if (_m.phase == LiveRoomPhase.ended && !_closing) {
      _closing = true;
      Future.delayed(const Duration(milliseconds: 2200), () {
        _m.acknowledge();
        if (mounted) Navigator.of(context).maybePop();
      });
    }

    if (_m.invite != null && !_inviteShown && !_m.isOnStage) {
      _inviteShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _showInvite());
    }
    if (_m.invite == null) _inviteShown = false;
  }

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
    if (_lastAction != null && now.difference(_lastAction!) < _kActionThrottle) {
      return false;
    }
    _lastAction = now;
    return true;
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? ThixPolicy.danger : ThixPolicy.domainMedia,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 2),
    ));
  }

  void _spawn(String emoji) {
    if (!mounted) return;
    final id = ++_heartSeq;
    setState(() {
      _hearts.add(_Heart(id, emoji, _random.nextDouble() * 70));
      if (_hearts.length > 30) _hearts.removeAt(0);
    });
  }

  void _removeHeart(int id) {
    if (!mounted) return;
    setState(() => _hearts.removeWhere((h) => h.id == id));
  }

  // ════════════════════════════════════════════════════════════
  // ACTIONS
  // ════════════════════════════════════════════════════════════
  void _like() {
    HapticFeedback.lightImpact();
    _m.like();
    _spawn('❤️');
  }

  Future<void> _send() async {
    if (!_throttleChat() || _chatSending) return;
    final text = _chatCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _chatSending = true);
    HapticFeedback.lightImpact();
    _chatCtrl.clear();
    final ok = await _m.sendChat(text);
    if (!ok && mounted) _snack('Message non envoyé.', error: true);
    if (mounted) setState(() => _chatSending = false);
  }

  void _share() {
    final id = _m.session?.id;
    if (id == null || !_throttleAction()) return;
    Clipboard.setData(ClipboardData(text: liveShareUrl(id)));
    _snack('Lien copié');
  }

  void _minimize() {
    HapticFeedback.selectionClick();
    Navigator.of(context).maybePop();
  }

  Future<void> _onBack() async {
    if (_m.isHost && _m.phase == LiveRoomPhase.live) {
      final a = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          title: const Text('Que souhaitez-vous faire ?',
              style: TextStyle(color: Colors.white)),
          content: const Text(
            'Vous pouvez réduire le live (il continue) ou le terminer pour tout le monde.',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, 'cancel'),
                child: const Text('Annuler')),
            TextButton(
                onPressed: () => Navigator.pop(ctx, 'min'),
                child: const Text('Réduire')),
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'end'),
              child: const Text('Terminer',
                  style: TextStyle(color: ThixPolicy.danger)),
            ),
          ],
        ),
      );
      if (a == 'min') _minimize();
      if (a == 'end') await _endLive();
      return;
    }
    _minimize();
  }

  Future<void> _closeButton() async {
    if (_m.isHost) {
      await _endLive(confirm: true);
    } else {
      await _leaveRoom();
    }
  }

  Future<void> _endLive({bool confirm = false}) async {
    if (confirm) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          title: const Text('Terminer le live ?',
              style: TextStyle(color: Colors.white)),
          content: const Text('Tous les spectateurs seront déconnectés.',
              style: TextStyle(color: Colors.white70)),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Annuler')),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Terminer',
                  style: TextStyle(color: ThixPolicy.danger)),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }
    HapticFeedback.heavyImpact();
    _closing = true;
    final err = await _m.endLive();
    if (err != null) {
      _closing = false;
      _snack(err, error: true);
      return;
    }
    if (mounted) Navigator.of(context).maybePop();
  }

  Future<void> _leaveRoom() async {
    if (_m.isOnStage) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          title: const Text('Quitter le live ?',
              style: TextStyle(color: Colors.white)),
          content: const Text('Vous êtes actuellement sur scène.',
              style: TextStyle(color: Colors.white70)),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Annuler')),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Quitter',
                  style: TextStyle(color: ThixPolicy.danger)),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }
    _closing = true;
    await _m.leave();
    if (mounted) Navigator.of(context).maybePop();
  }

  Future<void> _requestJoin() async {
    if (!_throttleAction()) return;
    HapticFeedback.mediumImpact();
    final err = await _m.requestToJoin();
    if (!mounted) return;
    if (err == null) {
      _snack('Demande envoyée à l\'hôte');
    } else if (err == 'cooldown') {
      _snack('Patientez avant une nouvelle demande.', error: true);
    } else {
      _snack('Demande impossible.', error: true);
    }
  }

  Future<void> _follow(String hostId) async {
    HapticFeedback.selectionClick();
    setState(() => _followed.add(hostId));
    try {
      await MediaService().toggleFollow(hostId);
      ref.invalidate(mediaIsFollowingProvider(hostId));
    } catch (_) {}
  }

  // ════════════════════════════════════════════════════════════
  // SHEETS / DIALOGS
  // ════════════════════════════════════════════════════════════
  void _showInvite() {
    final inv = _m.invite;
    if (!mounted || inv == null) return;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _InviteDialog(
        hostName: inv.hostUsername,
        onAccept: () {
          Navigator.pop(ctx);
          _m.acceptInvite();
        },
        onReject: () {
          Navigator.pop(ctx);
          _m.rejectInvite();
        },
      ),
    );
  }

  void _openChatSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ChatSheet(manager: _m),
    );
  }

  void _openGuestsPanel() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _GuestsPanel(
        manager: _m,
        onError: (e) => _snack(e, error: true),
      ),
    );
  }

  void _openMore() {
    final host = _m.isHost;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            _moreTile(ctx, Icons.link_rounded, 'Copier le lien', _share),
            _moreTile(ctx, Icons.visibility_off_rounded, 'Mode épuré',
                () => setState(() => _hideUi = true)),
            if (!host)
              _moreTile(
                ctx,
                _m.listenMuted
                    ? Icons.volume_up_rounded
                    : Icons.volume_off_rounded,
                _m.listenMuted ? 'Remettre le son' : 'Couper le son du live',
                _m.toggleListen,
              ),
            if (host)
              _moreTile(ctx, Icons.stop_circle_rounded, 'Terminer le live',
                  () => _endLive(confirm: true),
                  color: ThixPolicy.danger),
            if (!host)
              _moreTile(ctx, Icons.logout_rounded, 'Quitter le live',
                  _leaveRoom,
                  color: ThixPolicy.danger),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _moreTile(BuildContext ctx, IconData icon, String label,
      VoidCallback onTap,
      {Color color = Colors.white}) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(label, style: TextStyle(color: color)),
      onTap: () {
        Navigator.pop(ctx);
        onTap();
      },
    );
  }

  // ════════════════════════════════════════════════════════════
  // BUILD
  // ════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    Widget body;

    switch (_m.phase) {
      case LiveRoomPhase.idle:
      case LiveRoomPhase.joining:
        body = _loading();
        break;
      case LiveRoomPhase.error:
        body = _statusPane(
          _m.error ?? _t(l10n, 'live_error_generic', 'Impossible de charger le live.'),
          Icons.error_outline,
          back: true,
        );
        break;
      case LiveRoomPhase.ended:
        body = _statusPane('Ce live est terminé.', Icons.sensors_off_rounded);
        break;
      case LiveRoomPhase.live:
      case LiveRoomPhase.ending:
        body = _room(l10n);
        break;
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _onBack();
      },
      child: Scaffold(backgroundColor: Colors.black, body: body),
    );
  }

  Widget _loading() {
    return Stack(
      fit: StackFit.expand,
      children: [
        const Center(child: CircularProgressIndicator(color: Colors.white)),
        SafeArea(
          child: Align(
            alignment: Alignment.topRight,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () async {
                _closing = true;
                await _m.leave();
                if (mounted) Navigator.of(context).maybePop();
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _statusPane(String text, IconData icon, {bool back = false}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white54, size: 52),
            const SizedBox(height: 14),
            Text(text,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 15)),
            const SizedBox(height: 18),
            if (back)
              ElevatedButton(
                onPressed: () {
                  _closing = true;
                  _m.acknowledge();
                  Navigator.of(context).maybePop();
                },
                child: const Text('Retour'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _room(AppLocalizations l10n) {
    final tiles = _tiles();

    return Stack(
      fit: StackFit.expand,
      children: [
        GestureDetector(
          onDoubleTap: widget.isHost ? null : _like,
          onTap: _hideUi ? () => setState(() => _hideUi = false) : null,
          child: _stage(tiles),
        ),
        if (!_hideUi) ...[
          const Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: 150,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.black54, Colors.transparent],
                  ),
                ),
              ),
            ),
          ),
          const Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 320,
            child: IgnorePointer(
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
          ),
        ],

        // Cœurs / réactions flottantes
        Positioned.fill(
          child: IgnorePointer(
            child: Stack(
              children: [
                for (final h in _hearts)
                  _FloatingEmoji(
                    key: ValueKey(h.id),
                    emoji: h.emoji,
                    dx: h.dx,
                    onDone: () => _removeHeart(h.id),
                  ),
              ],
            ),
          ),
        ),

        if (!_hideUi) ...[
          SafeArea(child: _topArea(l10n)),
          if (!widget.isHost && _m.isOnStage) _localPip(),
          Positioned(
            right: 10,
            bottom: 96,
            child: SafeArea(child: _rail(l10n)),
          ),
          Positioned(
            left: 12,
            right: 84,
            bottom: 0,
            child: SafeArea(child: _bottomArea(l10n)),
          ),
          if (_showReactions)
            Positioned(
              left: 12,
              right: 84,
              bottom: 82,
              child: SafeArea(child: _reactionPicker()),
            ),
        ],

        if (_m.reconnecting)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Container(
                margin: const EdgeInsets.only(top: 110),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                alignment: Alignment.center,
                color: Colors.orange.withValues(alpha: 0.85),
                child: const Text('Reconnexion…',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w800)),
              ),
            ),
          ),

        if (_m.phase == LiveRoomPhase.ending)
          Container(
            color: Colors.black54,
            child: const Center(
                child: CircularProgressIndicator(color: Colors.white)),
          ),
      ],
    );
  }

  // ════════════════════════════════════════════════════════════
  // VIDEO
  // ════════════════════════════════════════════════════════════
  List<Widget> _tiles() {
    final tiles = <Widget>[];
    final multi = _m.broadcasters.length + (widget.isHost ? 1 : 0) > 1;

    if (widget.isHost) {
      tiles.add(_tile(
        _localVideo(),
        label: _m.session?.hostUsername ?? _m.myName,
        host: true,
        audioOn: !_m.muted,
        showLabel: multi,
      ));
      for (final g in _m.broadcasters) {
        tiles.add(_tile(
          _remoteVideo(g),
          label: g.username,
          audioOn: g.audioEnabled,
          showLabel: true,
          onRemove: g.userId != null ? () => _removeGuest(g) : null,
        ));
      }
    } else {
      for (final b in _m.broadcasters) {
        tiles.add(_tile(
          _remoteVideo(b),
          label: b.username,
          host: b.isHost,
          audioOn: b.audioEnabled,
          showLabel: multi,
        ));
      }
    }
    return tiles;
  }

  Widget _stage(List<Widget> tiles) {
    if (tiles.isEmpty) {
      final s = _m.session;
      return Container(
        color: Colors.black,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _avatar(s?.hostAvatarUrl, s?.hostUsername ?? '?', 40),
              const SizedBox(height: 14),
              const Text('En attente de l\'hôte…',
                  style: TextStyle(color: Colors.white54)),
            ],
          ),
        ),
      );
    }
    final rows = <Widget>[];
    for (var i = 0; i < tiles.length; i += 2) {
      final pair = tiles.sublist(i, math.min(i + 2, tiles.length));
      rows.add(Expanded(
        child: Row(children: [for (final p in pair) Expanded(child: p)]),
      ));
    }
    return Column(children: rows);
  }

  Widget _tile(
    Widget video, {
    required String label,
    bool host = false,
    bool audioOn = true,
    bool showLabel = true,
    VoidCallback? onRemove,
  }) {
    return Stack(
      fit: StackFit.expand,
      children: [
        video,
        if (showLabel && !_hideUi)
          Positioned(
            left: 8,
            bottom: widget.isHost ? 8 : 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: host ? _kLiveRed : Colors.black54,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (host)
                    const Padding(
                      padding: EdgeInsets.only(right: 4),
                      child: Text('HOST',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w900)),
                    ),
                  if (!audioOn)
                    const Padding(
                      padding: EdgeInsets.only(right: 4),
                      child: Icon(Icons.mic_off, color: Colors.red, size: 12),
                    ),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 110),
                    child: Text(label,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
          ),
        if (onRemove != null && !_hideUi)
          Positioned(
            top: 120,
            right: 8,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                    color: Colors.black54, shape: BoxShape.circle),
                child: const Icon(Icons.close, color: Colors.white, size: 16),
              ),
            ),
          ),
      ],
    );
  }

  Widget _localVideo() {
    final engine = _m.engine;
    if (engine != null && !_m.videoOff) {
      return AgoraVideoView(
        controller: VideoViewController(
          rtcEngine: engine,
          canvas: const VideoCanvas(uid: 0),
        ),
      );
    }
    return Container(
      color: Colors.black,
      child: Center(
        child: Icon(Icons.videocam_off_rounded,
            size: 64, color: Colors.white.withValues(alpha: 0.3)),
      ),
    );
  }

  Widget _remoteVideo(LiveBroadcaster b) {
    final engine = _m.engine;
    final channel = _m.creds?.channelName;
    if (engine == null || channel == null || !b.videoEnabled) {
      return Container(
        color: Colors.black87,
        child: Center(child: _avatar(b.avatarUrl, b.username, 36)),
      );
    }
    return AgoraVideoView(
      controller: VideoViewController.remote(
        rtcEngine: engine,
        canvas: VideoCanvas(uid: b.uid),
        connection: RtcConnection(channelId: channel),
      ),
    );
  }

  Widget _localPip() {
    final engine = _m.engine;
    return Positioned(
      top: 150,
      right: 12,
      width: 96,
      height: 144,
      child: SafeArea(
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white30, width: 2),
          ),
          clipBehavior: Clip.antiAlias,
          child: (engine == null || _m.videoOff)
              ? Container(
                  color: Colors.black87,
                  child: const Center(
                      child: Icon(Icons.videocam_off,
                          color: Colors.white54, size: 24)),
                )
              : AgoraVideoView(
                  controller: VideoViewController(
                    rtcEngine: engine,
                    canvas: const VideoCanvas(uid: 0),
                  ),
                ),
        ),
      ),
    );
  }

  Widget _avatar(String? url, String name, double radius) {
    final has = url != null && url.isNotEmpty;
    return CircleAvatar(
      radius: radius,
      backgroundColor: Colors.white24,
      backgroundImage: has ? CachedNetworkImageProvider(url) : null,
      child: has
          ? null
          : Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: radius * 0.8,
                  fontWeight: FontWeight.w800)),
    );
  }

  // ════════════════════════════════════════════════════════════
  // TOP
  // ════════════════════════════════════════════════════════════
  Widget _topArea(AppLocalizations l10n) {
    final s = _m.session;
    final hostId = s?.hostId ?? '';
    final following = hostId.isEmpty
        ? true
        : (ref.watch(mediaIsFollowingProvider(hostId)).valueOrNull ?? true);
    final showFollow = !widget.isHost &&
        hostId.isNotEmpty &&
        hostId != _m.myId &&
        !following &&
        !_followed.contains(hostId);

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 6, 4, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: Container(
                  padding: const EdgeInsets.fromLTRB(4, 4, 8, 4),
                  decoration: BoxDecoration(
                    color: Colors.black45,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _avatar(s?.hostAvatarUrl, s?.hostUsername ?? '?', 18),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: Text(
                                    s?.hostUsername ?? '',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 13),
                                  ),
                                ),
                                if (hostId.isNotEmpty)
                                  MediaCertBadge(
                                    userId: hostId,
                                    official: false,
                                    iconSize: 13,
                                    padding: const EdgeInsets.only(left: 4),
                                  ),
                              ],
                            ),
                            Text(
                              '${_cnt(_m.likeCount)} ${_t(l10n, 'live_likes', 'J\'aime')}',
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 10.5),
                            ),
                          ],
                        ),
                      ),
                      if (showFollow) ...[
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => _follow(hostId),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: _kLiveRed,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Text('Suivre',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800)),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),
              _chip(Icons.remove_red_eye_outlined, _cnt(_m.viewerCount)),
              IconButton(
                tooltip: 'Réduire',
                icon: const Icon(Icons.keyboard_arrow_down_rounded,
                    color: Colors.white, size: 30),
                onPressed: _minimize,
              ),
              IconButton(
                tooltip: 'Fermer',
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: _closeButton,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                    color: _kLiveRed, borderRadius: BorderRadius.circular(5)),
                child: const Text('LIVE',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 11,
                        letterSpacing: 0.5)),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                    color: Colors.black45,
                    borderRadius: BorderRadius.circular(10)),
                child: Text(_fmt(_m.elapsed),
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                        fontFeatures: [FontFeature.tabularFigures()])),
              ),
              const SizedBox(width: 8),
              _netDot(),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  s?.title ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 12),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip(IconData icon, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
          color: Colors.black45, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.white),
          const SizedBox(width: 4),
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                  fontFeatures: [FontFeature.tabularFigures()])),
        ],
      ),
    );
  }

  Widget _netDot() {
    final Color c;
    switch (_m.net) {
      case LiveNet.excellent:
        c = const Color(0xFF22C55E);
        break;
      case LiveNet.good:
        c = const Color(0xFFEAB308);
        break;
      case LiveNet.poor:
        c = const Color(0xFFF97316);
        break;
      case LiveNet.offline:
        c = const Color(0xFFEF4444);
        break;
    }
    return Container(
      width: 9,
      height: 9,
      decoration: BoxDecoration(shape: BoxShape.circle, color: c),
    );
  }

  // ════════════════════════════════════════════════════════════
  // RAIL (droite)
  // ════════════════════════════════════════════════════════════
  Widget _rail(AppLocalizations l10n) {
    final pending = _m.requests.length;

    if (widget.isHost) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _RailBtn(
            icon: Icons.group_add_rounded,
            label: '${_m.broadcasters.length}',
            badge: pending,
            onTap: _openGuestsPanel,
          ),
          const SizedBox(height: 14),
          _RailBtn(
            icon: _m.muted ? Icons.mic_off : Icons.mic,
            label: _m.muted ? 'Muet' : 'Micro',
            active: _m.muted,
            onTap: () {
              if (_throttleAction()) _m.toggleMute();
            },
          ),
          const SizedBox(height: 14),
          _RailBtn(
            icon: _m.videoOff ? Icons.videocam_off : Icons.videocam,
            label: _m.videoOff ? 'Off' : 'Vidéo',
            active: _m.videoOff,
            onTap: () {
              if (_throttleAction()) _m.toggleVideo();
            },
          ),
          const SizedBox(height: 14),
          _RailBtn(
            icon: Icons.cameraswitch_rounded,
            label: 'Flip',
            onTap: () {
              if (_throttleAction()) _m.flipCamera();
            },
          ),
          const SizedBox(height: 14),
          _RailBtn(icon: Icons.ios_share_rounded, label: '', onTap: _share),
          const SizedBox(height: 14),
          _RailBtn(icon: Icons.more_horiz_rounded, label: '', onTap: _openMore),
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_m.isOnStage) ...[
          _RailBtn(
            icon: _m.muted ? Icons.mic_off : Icons.mic,
            label: _m.muted ? 'Muet' : 'Micro',
            active: _m.muted,
            onTap: () {
              if (_throttleAction()) _m.toggleMute();
            },
          ),
          const SizedBox(height: 14),
          _RailBtn(
            icon: _m.videoOff ? Icons.videocam_off : Icons.videocam,
            label: _m.videoOff ? 'Off' : 'Vidéo',
            active: _m.videoOff,
            onTap: () {
              if (_throttleAction()) _m.toggleVideo();
            },
          ),
          const SizedBox(height: 14),
          _RailBtn(
            icon: Icons.cameraswitch_rounded,
            label: 'Flip',
            onTap: () {
              if (_throttleAction()) _m.flipCamera();
            },
          ),
          const SizedBox(height: 14),
          _RailBtn(
            icon: Icons.call_end_rounded,
            label: 'Sortir',
            danger: true,
            onTap: () async {
              await _m.becomeAudience();
            },
          ),
        ] else
          _RailBtn(
            icon: _m.requestingJoin
                ? Icons.hourglass_top_rounded
                : Icons.video_call_rounded,
            label: 'Co-live',
            onTap: _requestJoin,
          ),
        const SizedBox(height: 14),
        _RailBtn(
          icon: Icons.chat_bubble_outline_rounded,
          label: _cnt(_m.messages.length),
          onTap: _openChatSheet,
        ),
        const SizedBox(height: 14),
        _RailBtn(icon: Icons.ios_share_rounded, label: '', onTap: _share),
        const SizedBox(height: 14),
        _RailBtn(icon: Icons.more_horiz_rounded, label: '', onTap: _openMore),
        const SizedBox(height: 18),
        GestureDetector(
          onTap: _like,
          onLongPressStart: (_) {
            _likeHold?.cancel();
            _likeHold = Timer.periodic(_kLikeRepeat, (_) => _like());
          },
          onLongPressEnd: (_) => _likeHold?.cancel(),
          onLongPressCancel: () => _likeHold?.cancel(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _kLiveRed,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: _kLiveRed.withValues(alpha: 0.5),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child:
                    const Icon(Icons.favorite, color: Colors.white, size: 30),
              ),
              const SizedBox(height: 4),
              Text(_cnt(_m.likeCount),
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 12)),
            ],
          ),
        ),
      ],
    );
  }

  // ════════════════════════════════════════════════════════════
  // BAS : chat + saisie
  // ════════════════════════════════════════════════════════════
  Widget _bottomArea(AppLocalizations l10n) {
    final pending = _m.requests.length;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.isHost && pending > 0) ...[
          GestureDetector(
            onTap: _openGuestsPanel,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                    colors: [ThixPolicy.domainMedia, _kLiveRed]),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.front_hand, color: Colors.white, size: 15),
                  const SizedBox(width: 8),
                  Text(
                    pending == 1
                        ? '1 demande pour rejoindre'
                        : '$pending demandes pour rejoindre',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 12.5),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
        _chatOverlay(),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _chatCtrl,
                maxLength: kLiveMaxChat,
                style: const TextStyle(color: Colors.white),
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(),
                decoration: InputDecoration(
                  counterText: '',
                  hintText: _t(l10n, 'live_chat_hint', 'Dites quelque chose…'),
                  hintStyle: const TextStyle(color: Colors.white54),
                  filled: true,
                  fillColor: Colors.black38,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(26),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            _circle(Icons.emoji_emotions_outlined,
                () => setState(() => _showReactions = !_showReactions)),
            const SizedBox(width: 6),
            _circle(Icons.send_rounded, _send, filled: true),
          ],
        ),
        const SizedBox(height: 10),
      ],
    );
  }

  Widget _circle(IconData icon, VoidCallback onTap, {bool filled = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: filled ? ThixPolicy.domainMedia : Colors.black38,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }

  Widget _chatOverlay() {
    final msgs = _m.messages.where((x) => x.type != 'reaction').toList();
    final show = msgs.length > 40 ? msgs.sublist(msgs.length - 40) : msgs;
    return SizedBox(
      height: 190,
      child: ShaderMask(
        shaderCallback: (rect) => const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.white],
          stops: [0.0, 0.3],
        ).createShader(rect),
        blendMode: BlendMode.dstIn,
        child: ListView.builder(
          reverse: true,
          padding: EdgeInsets.zero,
          itemCount: show.length,
          itemBuilder: (_, i) => _line(show[show.length - 1 - i]),
        ),
      ),
    );
  }

  Widget _line(LiveChatLine m) {
    final system = const ['system', 'kick', 'join', 'demote'].contains(m.type);
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: system ? Colors.white12 : Colors.black.withValues(alpha: 0.32),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text.rich(
          TextSpan(children: [
            TextSpan(
              text: system ? '⚡ ${m.username} ' : '${m.username}  ',
              style: TextStyle(
                color: system ? Colors.amber : const Color(0xFFFFD1DC),
                fontWeight: FontWeight.w800,
                fontSize: 12.5,
              ),
            ),
            TextSpan(
              text: m.text,
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ]),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Widget _reactionPicker() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(26),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          for (final e in _kReactions)
            GestureDetector(
              onTap: () {
                if (!_throttleChat()) return;
                HapticFeedback.lightImpact();
                _m.sendReaction(e);
              },
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Text(e, style: const TextStyle(fontSize: 24)),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _removeGuest(LiveBroadcaster g) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Retirer l\'invité ?',
            style: TextStyle(color: Colors.white)),
        content: Text('Retirer ${g.username} de la scène ?',
            style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Retirer',
                style: TextStyle(color: ThixPolicy.danger)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final err = await _m.removeGuest(g);
    if (err != null && mounted) _snack('Action impossible.', error: true);
  }
}

// ============================================================================
// WIDGETS
// ============================================================================
class _RailBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;
  final bool danger;
  final int badge;

  const _RailBtn({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
    this.danger = false,
    this.badge = 0,
  });

  @override
  Widget build(BuildContext context) {
    final bg = danger
        ? const Color(0xFFEF4444)
        : active
            ? _kLiveRed
            : Colors.black45;
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
                child: Icon(icon, color: Colors.white, size: 24),
              ),
              if (label.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(label,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 11)),
              ],
            ],
          ),
          if (badge > 0)
            Positioned(
              right: -4,
              top: -4,
              child: Container(
                padding: const EdgeInsets.all(4),
                constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                decoration: const BoxDecoration(
                    color: Color(0xFFEF4444), shape: BoxShape.circle),
                child: Text(badge > 9 ? '9+' : '$badge',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w900)),
              ),
            ),
        ],
      ),
    );
  }
}

class _FloatingEmoji extends StatefulWidget {
  final String emoji;
  final double dx;
  final VoidCallback onDone;
  const _FloatingEmoji({
    super.key,
    required this.emoji,
    required this.dx,
    required this.onDone,
  });

  @override
  State<_FloatingEmoji> createState() => _FloatingEmojiState();
}

class _FloatingEmojiState extends State<_FloatingEmoji>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2000))
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed) widget.onDone();
      })
      ..forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        final t = Curves.easeOut.transform(_ctrl.value);
        return Positioned(
          right: 24 + widget.dx,
          bottom: 130 + t * 300,
          child: Opacity(
            opacity: (1 - _ctrl.value).clamp(0.0, 1.0),
            child: Transform.scale(
              scale: 0.8 + 0.5 * t,
              child: Text(widget.emoji, style: const TextStyle(fontSize: 30)),
            ),
          ),
        );
      },
    );
  }
}

// ============================================================================
// INVITE DIALOG (30 s)
// ============================================================================
class _InviteDialog extends StatefulWidget {
  final String hostName;
  final VoidCallback onAccept;
  final VoidCallback onReject;
  const _InviteDialog({
    required this.hostName,
    required this.onAccept,
    required this.onReject,
  });

  @override
  State<_InviteDialog> createState() => _InviteDialogState();
}

class _InviteDialogState extends State<_InviteDialog> {
  int _left = 30;
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => _left--);
      if (_left <= 0) {
        t.cancel();
        widget.onReject();
      }
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1A1A1A),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: ThixPolicy.domainMedia.withValues(alpha: 0.5)),
      ),
      title: const Text('Invitation sur scène',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
      content: Text(
        '${widget.hostName} vous invite à rejoindre le live. ($_left s)',
        style: const TextStyle(color: Colors.white70),
      ),
      actions: [
        TextButton(
            onPressed: widget.onReject, child: const Text('Refuser')),
        ElevatedButton(
          onPressed: widget.onAccept,
          style: ElevatedButton.styleFrom(
              backgroundColor: ThixPolicy.domainMedia,
              foregroundColor: Colors.white),
          child: const Text('Accepter'),
        ),
      ],
    );
  }
}

// ============================================================================
// CHAT SHEET
// ============================================================================
class _ChatSheet extends StatefulWidget {
  final LiveRoomManager manager;
  const _ChatSheet({required this.manager});

  @override
  State<_ChatSheet> createState() => _ChatSheetState();
}

class _ChatSheetState extends State<_ChatSheet> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  DateTime? _last;

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _send() {
    final now = DateTime.now();
    if (_last != null && now.difference(_last!) < _kChatThrottle) return;
    _last = now;
    final text = _input.text.trim();
    if (text.isEmpty) return;
    HapticFeedback.lightImpact();
    widget.manager.sendChat(text);
    _input.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.65,
        decoration: const BoxDecoration(
          color: Color(0xFF1A1A1A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: ListenableBuilder(
          listenable: widget.manager,
          builder: (context, _) {
            final msgs = widget.manager.messages
                .where((m) => m.type != 'reaction')
                .toList();
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (_scroll.hasClients) {
                _scroll.jumpTo(_scroll.position.maxScrollExtent);
              }
            });
            return Column(
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2)),
                ),
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Text('Commentaires (${msgs.length})',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800)),
                ),
                const Divider(height: 1, color: Colors.white12),
                Expanded(
                  child: msgs.isEmpty
                      ? const Center(
                          child: Text('Aucun commentaire pour le moment.',
                              style: TextStyle(color: Colors.white54)))
                      : ListView.builder(
                          controller: _scroll,
                          padding: const EdgeInsets.all(14),
                          itemCount: msgs.length,
                          itemBuilder: (_, i) {
                            final m = msgs[i];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CircleAvatar(
                                    radius: 14,
                                    backgroundColor: Colors.white24,
                                    child: Text(
                                      m.username.isNotEmpty
                                          ? m.username[0].toUpperCase()
                                          : '?',
                                      style: const TextStyle(
                                          color: Colors.white, fontSize: 12),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(m.username,
                                            style: const TextStyle(
                                                color: Colors.white70,
                                                fontWeight: FontWeight.w800,
                                                fontSize: 12.5)),
                                        Text(m.text,
                                            style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 14)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _input,
                            maxLength: kLiveMaxChat,
                            style: const TextStyle(color: Colors.white),
                            onSubmitted: (_) => _send(),
                            decoration: InputDecoration(
                              counterText: '',
                              hintText: 'Ajouter un commentaire…',
                              hintStyle:
                                  const TextStyle(color: Colors.white38),
                              filled: true,
                              fillColor: Colors.white12,
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: _send,
                          icon: const Icon(Icons.send_rounded,
                              color: ThixPolicy.domainMedia),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ============================================================================
// GUESTS PANEL (hôte)
// ============================================================================
class _GuestsPanel extends StatelessWidget {
  final LiveRoomManager manager;
  final void Function(String) onError;
  const _GuestsPanel({required this.manager, required this.onError});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A1A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: ListenableBuilder(
        listenable: manager,
        builder: (context, _) {
          final guests = manager.broadcasters;
          final reqs = manager.requests;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 14),
              const Text('Gérer les invités',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 18),
              const Text('Sur scène',
                  style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              if (guests.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: Text('Aucun invité pour le moment.',
                      style: TextStyle(color: Colors.white38)),
                ),
              for (final g in guests)
                _tile(
                  name: g.username,
                  avatar: g.avatarUrl,
                  subtitle: g.isCoHost ? 'Co-host' : 'En direct',
                  trailing: g.userId == null
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close,
                              color: Color(0xFFEF4444)),
                          onPressed: () async {
                            final e = await manager.removeGuest(g);
                            if (e != null) onError('Action impossible.');
                          },
                        ),
                ),
              const SizedBox(height: 18),
              const Text('Demandes',
                  style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              if (reqs.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: Text('Aucune demande.',
                      style: TextStyle(color: Colors.white38)),
                ),
              for (final r in reqs)
                _tile(
                  name: r.username,
                  avatar: r.avatarUrl,
                  subtitle: 'souhaite rejoindre le live',
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon:
                            const Icon(Icons.close, color: Colors.white54),
                        onPressed: () => manager.dismissRequest(r.userId),
                      ),
                      manager.inviting.contains(r.userId)
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : ElevatedButton(
                              onPressed: () async {
                                final e = await manager.inviteUser(
                                    r.userId, r.username);
                                if (e == 'limit') {
                                  onError('Nombre maximum d\'invités atteint.');
                                } else if (e != null) {
                                  onError('Invitation impossible.');
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF22C55E),
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Inviter'),
                            ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _tile({
    required String name,
    String? avatar,
    required String subtitle,
    Widget? trailing,
  }) {
    final has = avatar != null && avatar.isNotEmpty;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: Colors.white24,
            backgroundImage: has ? CachedNetworkImageProvider(avatar) : null,
            child: has
                ? null
                : Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: const TextStyle(color: Colors.white)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14)),
                Text(subtitle,
                    style: const TextStyle(
                        color: Colors.white54, fontSize: 11.5)),
              ],
            ),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }
}
