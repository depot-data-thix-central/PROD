// lib/presentation/thix_media/live/pages/live_host_page.dart
//
// LiveHostPage — Host Live Production Enterprise (niveau TikTok/IG Live)
//
// Features production :
// - Preview locale Agora avec mute/flip/video-off
// - Chat realtime avec sanitization XSS + throttling
// - Durée live chronométrée + stats (viewers/likes)
// - Réactions emoji animées (burst flottant)
// - Monitoring qualité réseau
// - Partage du live (copie lien)
// - Semantics complet + haptics
// - Logging structuré
import 'dart:async';

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
const List<String> _kReactions = ['❤️', '🔥', '👏', '', ''];

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
// SANITIZER (anti-XSS)
// ============================================================================

class _LiveSanitizer {
  _LiveSanitizer._();
  static String chat(String? input) {
    if (input == null) return '';
    var s = input
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll(RegExp(r'javascript:', caseSensitive: false), '')
        .replaceAll(RegExp(r'on\w+\s*=', caseSensitive: false), '')
        .replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]'), '')
        .trim();
    if (s.length > _kMaxChatLength) s = s.substring(0, _kMaxChatLength);
    return s;
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

  List<_ChatLine> _messages = [];
  RealtimeChannel? _msgChannel;
  Timer? _statsTimer;
  Timer? _durationTimer;
  Timer? _netTimer;
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
    _netSub?.cancel();
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
      if (!mounted) return;
      setState(() => _ready = true);
      _subscribeChat();
      _startStatsPolling();
      _startDurationTimer();
      _startNetworkMonitor();
      _LiveHostLogger.info('Live started', {'id': widget.session.id});
    } catch (e, stack) {
      _LiveHostLogger.error('Bootstrap failed',
          {'error': '$e', 'stack': stack.toString()});
      if (!mounted) return;
      
      // ✅ La ligne est maintenant propre et sans restes de code en dessous
      _snack(AppLocalizations.of(context).t('live_error_generic'), error: true);
      
      Navigator.of(context).pop();
    }
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
            final user = (row['username'] ?? 'User').toString();
            final type = (row['type'] ?? 'chat').toString();
            if (!mounted || text.isEmpty) return;

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

            // Auto-scroll vers le bas (plus récent en haut car reverse)
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
      final user = Supabase.instance.client.auth.currentUser;
      final name = user?.userMetadata?['username']?.toString() ??
          user?.email?.split('@').first ??
          'Host';
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
    final user = Supabase.instance.client.auth.currentUser;
    final name = user?.userMetadata?['username']?.toString() ??
        user?.email?.split('@').first ??
        'Host';
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
    final link = 'https://thix.id/live/${widget.session.id}';
    Clipboard.setData(ClipboardData(text: link));
    _snack(l10n.t('live_link_copied'));
  }

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
    Navigator.of(context).popUntil((r) => r.isFirst || r.settings.name != null);
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

  // ════════════════════════════════════════════════════════════
  // BUILD
  // ════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final engine = _rtc.engine;

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
            // ── Vidéo locale ──────────────────────────────────
            if (_ready && engine != null && !_videoOff)
              AgoraVideoView(
                controller: VideoViewController(
                  rtcEngine: engine,
                  canvas: const VideoCanvas(uid: 0),
                ),
              )
            else
              Container(
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
              ),

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

            // ── Chat + input ─────────────────────────────────
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
                      height: 140,
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
                                            fontSize: m.type == 'reaction'
                                                ? 16
                                                : 13,
                                          ),
                                        ),
                                        TextSpan(
                                          text: m.text,
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: m.type == 'reaction'
                                                ? 18
                                                : 13,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
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
}

// ============================================================================
// CHAT LINE
// ============================================================================

class _ChatLine {
  final String username;
  final String text;
  final String type;
  _ChatLine({
    required this.username,
    required this.text,
    this.type = 'chat',
  });
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
