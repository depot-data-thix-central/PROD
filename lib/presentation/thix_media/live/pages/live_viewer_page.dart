// lib/presentation/thix_media/live/pages/live_viewer_page.dart
//
// LiveViewerPage — Viewer Live Production Enterprise (niveau TikTok/IG Live)
//
// Features production :
// - Vidéo host Agora avec fallback placeholder
// - Chat realtime avec sanitization XSS + throttling + auto-scroll
// - Likes avec animations flottantes + double-tap
// - Réactions emoji (❤️🔥👏)
// - Indicateur qualité réseau
// - Profil host (tap sur titre)
// - Partage du live
// - Confirmation avant sortie
// - Semantics complet + haptics
// - Logging structuré
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
const List<String> _kReactions = ['❤️', '🔥', '👏', '', ''];

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
// LIVE VIEWER PAGE
// ============================================================================

class LiveViewerPage extends ConsumerStatefulWidget {
  final String liveId;

  /// Optionnel : si tu as déjà session + creds (évite double fetch)
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

  RealtimeChannel? _msgChannel;
  Timer? _statsTimer;
  Timer? _netTimer;
  StreamSubscription<int?>? _remoteSub;
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
    _remoteSub?.cancel();
    _netSub?.cancel();
    _msgChannel?.unsubscribe();
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

      // Si le host est déjà là
      if (_rtc.remoteHostUid != null) {
        _hostUid = _rtc.remoteHostUid;
      }

      _subscribeChat();
      _startStatsPolling();
      _startNetworkMonitor();

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
    _LiveViewerLogger.info('Chat channel subscribed');
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

  // ════════════════════════════════════════════════════════════
  // ACTIONS
  // ════════════════════════════════════════════════════════════

  Future<void> _sendChat() async {
    if (!_throttleChat() || _chatSending || _session == null) return;
    final text = _LiveSanitizer.chat(_chatCtrl.text);
    if (text.isEmpty) return;

    if (mounted) setState(() => _chatSending = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      final name = user?.userMetadata?['username']?.toString() ??
          user?.email?.split('@').first ??
          'Viewer';
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

  Future<void> _sendLike() async {
    if (!_throttleLike()) return;
    HapticFeedback.lightImpact();
    _spawnFloatingLike();

    // Optimistic UI
    if (mounted) setState(() => _likeCount += 1);

    try {
      final liveId = _session?.id ?? widget.liveId;
      await Supabase.instance.client
          .rpc(
            'increment_live_likes',
            params: {'p_live_id': liveId},
          )
          .timeout(const Duration(seconds: 5));
    } catch (_) {
      // Fallback update non atomique si RPC absente
      try {
        await Supabase.instance.client
            .from('lives')
            .update({'like_count': _likeCount}).eq(
          'id',
          _session?.id ?? widget.liveId,
        );
      } catch (e) {
        _LiveViewerLogger.warn('Like fallback failed', {'error': '$e'});
      }
    }
  }

  Future<void> _sendReaction(String emoji) async {
    if (!_throttleChat() || _session == null) return;
    HapticFeedback.lightImpact();
    final user = Supabase.instance.client.auth.currentUser;
    final name = user?.userMetadata?['username']?.toString() ??
        user?.email?.split('@').first ??
        'Viewer';
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
    final dx = 40.0 + Random().nextDouble() * 80;
    if (mounted) {
      setState(() {
        _floatingLikes.add(_FloatingLike(id: id, dx: dx));
      });
    }
    Future.delayed(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      setState(() {
        _floatingLikes.removeWhere((e) => e.id == id);
      });
    });
  }

  void _shareLive(AppLocalizations l10n) {
    if (!_throttleAction()) return;
    HapticFeedback.lightImpact();
    final link = 'https://thix.id/live/${widget.liveId}';
    Clipboard.setData(ClipboardData(text: link));
    _snack(l10n.t('live_link_copied'));
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
            // ── Vidéo host ────────────────────────────────────
            GestureDetector(
              onDoubleTap: _sendLike,
              child: _ready && engine != null && _hostUid != null
                  ? AgoraVideoView(
                      controller: VideoViewController.remote(
                        rtcEngine: engine,
                        canvas: VideoCanvas(uid: _hostUid),
                        connection: RtcConnection(
                          channelId: _creds!.channelName,
                        ),
                      ),
                    )
                  : Container(
                      color: Colors.black,
                      child: Center(
                        child: _joining
                            ? const CircularProgressIndicator(
                                color: Colors.white)
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
                                    l10n.t('live_waiting_host'),
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.5),
                                    ),
                                  ),
                                ],
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
                  duration: const Duration(milliseconds: 900),
                  builder: (_, t, child) => Opacity(
                    opacity: 1 - t,
                    child: Transform.translate(
                      offset: Offset(0, -80 * t),
                      child: child,
                    ),
                  ),
                  child: const Icon(
                    Icons.favorite,
                    color: Color(0xFFE11D48),
                    size: 28,
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
                      height: 150,
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
                    const SizedBox(height: 10),
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
  _FloatingLike({required this.id, required this.dx});
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
