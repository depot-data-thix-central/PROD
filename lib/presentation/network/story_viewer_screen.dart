// lib/presentation/network/story_viewer_screen.dart
// ============================================================================
// STORY VIEWER — Plein écran avec Like ❤️ + Vu par 👁️ + Audio + Fond coloré + Suppression
// ============================================================================
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:audioplayers/audioplayers.dart';

import 'package:thix_id/core/theme/thix_design_policy.dart';

// ============================================================================
// VALIDATEURS
// ============================================================================
class _StoryValidators {
  _StoryValidators._();

  static String sanitize(String? input, {int maxLength = 1000}) {
    if (input == null || input.trim().isEmpty) return '';
    final doc = html_parser.parse(input);
    var sanitized = doc.body?.text ?? input;
    sanitized = sanitized
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll(RegExp(r'javascript:', caseSensitive: false), '')
        .replaceAll(RegExp(r'on\w+\s*=', caseSensitive: false), '')
        .replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '')
        .trim();
    return sanitized.length > maxLength ? sanitized.substring(0, maxLength) : sanitized;
  }

  static String? sanitizeUrl(String? url) {
    if (url == null || url.trim().isEmpty) return null;
    final trimmed = url.trim();
    if (!trimmed.startsWith('http://') && !trimmed.startsWith('https://')) return null;
    return trimmed.replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '');
  }

  static Color? parseHexColor(String? hex) {
    if (hex == null || hex.isEmpty) return null;
    final s = hex.replaceFirst('#', '');
    if (s.length != 6 && s.length != 8) return null;
    try {
      final v = int.parse(s.length == 6 ? 'FF$s' : s, radix: 16);
      return Color(v);
    } catch (_) {
      return null;
    }
  }

  static String fmtDuration(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

// ============================================================================
// COMPOSANT PRINCIPAL
// ============================================================================
class StoryViewerScreen extends StatefulWidget {
  final String storyId;
  final String? userId;

  const StoryViewerScreen({super.key, required this.storyId, this.userId});

  @override
  State<StoryViewerScreen> createState() => _StoryViewerScreenState();
}

class _StoryViewerScreenState extends State<StoryViewerScreen> with TickerProviderStateMixin {
  List<Map<String, dynamic>> _stories = [];
  int _current = 0;
  Timer? _timer;
  double _progress = 0;
  bool _loading = true;
  bool _isPaused = false;
  bool _isDragging = false;

  late AnimationController _dragController;
  double _dragOffset = 0;

  // Like state (storyId -> {liked: bool, count: int})
  final Map<String, Map<String, dynamic>> _likeState = {};
  // Animation cœur pop
  final Map<String, AnimationController> _heartAnims = {};

  final Map<String, ImageProvider> _imageCache = {};

  static const Duration _storyDuration = Duration(seconds: 5);
  static const Duration _requestTimeout = Duration(seconds: 10);
  static const int _timerIntervalMs = 50;

  String? get _viewerId => Supabase.instance.client.auth.currentUser?.id;
  bool get _isCreator {
    if (_stories.isEmpty) return false;
    return _stories[_current]['user_id']?.toString() == _viewerId;
  }

  @override
  void initState() {
    super.initState();
    _dragController = AnimationController(vsync: this, duration: const Duration(milliseconds: 200));
    _load();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _dragController.dispose();
    for (final c in _heartAnims.values) {
      c.dispose();
    }
    super.dispose();
  }

  // ════════════════════════════════════════════════════════════════════════
  // LOAD
  // ════════════════════════════════════════════════════════════════════════
  Future<void> _load() async {
    final supa = Supabase.instance.client;
    try {
      final first = await supa
          .from('stories')
          .select('*, profiles(display_name, photo_url, avatar_url)')
          .eq('id', widget.storyId)
          .single()
          .timeout(_requestTimeout);

      final uid = widget.userId ?? first['user_id'];

      final all = await supa
          .from('stories')
          .select('*, profiles(display_name, photo_url, avatar_url)')
          .eq('user_id', uid)
          .eq('is_active', true)
          .gt('expires_at', DateTime.now().toUtc().toIso8601String())
          .order('created_at')
          .timeout(_requestTimeout);

      final list = (all as List).cast<Map<String, dynamic>>();

      if (!mounted) return;

      setState(() {
        _stories = list;
        _current = list.indexWhere((s) => s['id'] == widget.storyId);
        if (_current == -1) _current = 0;
        _loading = false;
      });

      _startTimer();
      _markViewed();
      _preloadNext();
      _loadLikeState();
    } catch (e) {
      debugPrint('[Story] Load error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  // ════════════════════════════════════════════════════════════════════════
  // TIMER
  // ════════════════════════════════════════════════════════════════════════
  void _startTimer() {
    _timer?.cancel();
    _progress = 0;
    _isPaused = false;

    final steps = _storyDuration.inMilliseconds ~/ _timerIntervalMs;
    final increment = 1.0 / steps;

    _timer = Timer.periodic(const Duration(milliseconds: _timerIntervalMs), (t) {
      if (!mounted || _isPaused || _isDragging) return;
      setState(() => _progress += increment);
      if (_progress >= 1.0) _next();
    });
  }

  void _pauseTimer() {
    if (!_isPaused) {
      setState(() => _isPaused = true);
      HapticFeedback.selectionClick();
    }
  }

  void _resumeTimer() {
    if (_isPaused) setState(() => _isPaused = false);
  }

  void _preloadNext() {
    if (_current < _stories.length - 1) {
      final next = _stories[_current + 1];
      final mediaUrl = _StoryValidators.sanitizeUrl(next['media_url']?.toString());
      if (mediaUrl != null && !_imageCache.containsKey(mediaUrl)) {
        _imageCache[mediaUrl] = CachedNetworkImageProvider(mediaUrl);
        precacheImage(_imageCache[mediaUrl]!, context);
      }
    }
  }

  // ════════════════════════════════════════════════════════════════════════
  // VIEWED + LIKES
  // ════════════════════════════════════════════════════════════════════════
  Future<void> _markViewed() async {
    if (_stories.isEmpty || _current >= _stories.length) return;
    final story = _stories[_current];
    final storyId = story['id']?.toString();
    if (storyId == null) return;
    final viewerId = _viewerId;
    if (viewerId == null) return;
    // ✅ Ne pas compter le créateur dans ses propres vues
    if (story['user_id']?.toString() == viewerId) return;

    try {
      await Supabase.instance.client
          .from('stories')
          .update({'is_viewed': true})
          .eq('id', storyId)
          .timeout(_requestTimeout);

      await Supabase.instance.client.from('story_views').upsert(
        {
          'story_id': storyId,
          'viewer_id': viewerId,
          'viewed_at': DateTime.now().toUtc().toIso8601String(),
        },
        onConflict: 'story_id,viewer_id',
      ).timeout(_requestTimeout);
    } catch (e) {
      debugPrint('[Story] Mark viewed error: $e');
    }
  }

  Future<void> _loadLikeState() async {
    final viewerId = _viewerId;
    if (viewerId == null || _stories.isEmpty) return;

    final ids = _stories.map((s) => s['id']?.toString()).whereType<String>().toList();
    if (ids.isEmpty) return;

    try {
      final supa = Supabase.instance.client;

      final counts = await supa.from('story_likes').select('story_id').inFilter('story_id', ids).timeout(_requestTimeout);
      final countMap = <String, int>{};
      for (final row in counts as List) {
        final id = (row as Map)['story_id']?.toString();
        if (id != null) countMap[id] = (countMap[id] ?? 0) + 1;
      }

      final myLikes = await supa.from('story_likes').select('story_id').eq('user_id', viewerId).inFilter('story_id', ids).timeout(_requestTimeout);
      final likedSet = <String>{};
      for (final row in myLikes as List) {
        final id = (row as Map)['story_id']?.toString();
        if (id != null) likedSet.add(id);
      }

      if (!mounted) return;
      setState(() {
        for (final id in ids) {
          _likeState[id] = {'liked': likedSet.contains(id), 'count': countMap[id] ?? 0};
        }
      });
    } catch (e) {
      debugPrint('[Story] Load like state: $e');
    }
  }

  Future<void> _toggleLike() async {
    if (_stories.isEmpty || _current >= _stories.length) return;
    final storyId = _stories[_current]['id']?.toString();
    final viewerId = _viewerId;
    if (storyId == null || viewerId == null) return;

    final state = _likeState[storyId] ?? {'liked': false, 'count': 0};
    final wasLiked = state['liked'] as bool;
    final count = (state['count'] as int) + (wasLiked ? -1 : 1);

    setState(() {
      _likeState[storyId] = {'liked': !wasLiked, 'count': count.clamp(0, 999999)};
    });

    HapticFeedback.mediumImpact();
    if (!wasLiked) _playHeartPop(storyId);

    try {
      final supa = Supabase.instance.client;
      if (wasLiked) {
        await supa.from('story_likes').delete().eq('story_id', storyId).eq('user_id', viewerId);
      } else {
        await supa.from('story_likes').upsert(
          {'story_id': storyId, 'user_id': viewerId, 'created_at': DateTime.now().toUtc().toIso8601String()},
          onConflict: 'story_id,user_id',
        );
      }
    } catch (e) {
      debugPrint('[Story] Toggle like error: $e');
      setState(() {
        _likeState[storyId] = {'liked': wasLiked, 'count': state['count'] as int};
      });
    }
  }

  void _playHeartPop(String storyId) {
    final ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _heartAnims[storyId] = ctrl;
    ctrl.addListener(() { if (mounted) setState(() {}); });
    ctrl.forward().then((_) {
      ctrl.dispose();
      _heartAnims.remove(storyId);
    });
  }

  // ════════════════════════════════════════════════════════════════════════
  // SUPPRESSION
  // ════════════════════════════════════════════════════════════════════════
  Future<void> _deleteStory(String storyId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Supprimer la story ?'),
        content: const Text('Cette action est irréversible.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    final supa = Supabase.instance.client;
    final uid = supa.auth.currentUser?.id;

    try {
      // ✅ 1) Via RPC serveur (sécurisée, contourne RLS)
      try {
        await supa
            .rpc('delete_story', params: {'p_story_id': storyId})
            .timeout(_requestTimeout);
      } catch (rpcError) {
        debugPrint('[Story] RPC delete failed, fallback direct: $rpcError');
        // ✅ 2) Fallback : suppression directe
        try { await supa.from('story_views').delete().eq('story_id', storyId).timeout(_requestTimeout); } catch (_) {}
        try { await supa.from('story_likes').delete().eq('story_id', storyId).timeout(_requestTimeout); } catch (_) {}
        await supa
            .from('stories')
            .delete()
            .eq('id', storyId)
            .eq('user_id', uid ?? '')
            .timeout(_requestTimeout);
      }

      if (!mounted) return;

      // 3) Liste locale + navigation
      setState(() {
        _stories.removeWhere((s) => s['id']?.toString() == storyId);
        if (_current >= _stories.length) _current = math.max(0, _stories.length - 1);
      });

      if (_stories.isEmpty) {
        Navigator.pop(context);
      } else {
        _startTimer();
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Story supprimée'), backgroundColor: ThixPolicy.success),
      );
    } catch (e) {
      debugPrint('[Story] delete error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Suppression impossible : ${e.toString().split('\n').first}'),
            backgroundColor: ThixPolicy.danger,
          ),
        );
      }
    }
  }

  // ════════════════════════════════════════════════════════════════════════
  // NAVIGATION
  // ════════════════════════════════════════════════════════════════════════
  void _next() {
    if (_current < _stories.length - 1) {
      HapticFeedback.lightImpact();
      setState(() => _current++);
      _startTimer();
      _markViewed();
      _preloadNext();
    } else if (mounted) {
      Navigator.pop(context);
    }
  }

  void _prev() {
    if (_current > 0) {
      HapticFeedback.lightImpact();
      setState(() => _current--);
      _startTimer();
      _markViewed();
    } else {
      setState(() => _progress = 0);
    }
  }

  void _onTapDown(TapDownDetails details) {
    final width = MediaQuery.of(context).size.width;
    final x = details.globalPosition.dx;
    if (x < width / 3) {
      _prev();
    } else if (x > width * 2 / 3) {
      _next();
    } else {
      _toggleLike();
    }
  }

  void _onVerticalDragUpdate(DragUpdateDetails details) {
    setState(() {
      _isDragging = true;
      _dragOffset += details.delta.dy;
    });
  }

  void _onVerticalDragEnd(DragEndDetails details) {
    setState(() => _isDragging = false);
    if (_dragOffset > 100) {
      Navigator.pop(context);
    } else {
      setState(() => _dragOffset = 0);
    }
  }

  String _getTimeAgo(DateTime createdAt) {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inMinutes < 1) return 'À l\'instant';
    if (diff.inMinutes < 60) return '${diff.inMinutes}min';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}j';
  }

  // ════════════════════════════════════════════════════════════════════════
  // VU PAR (sheet)
  // ════════════════════════════════════════════════════════════════════════
  Future<void> _openViewersSheet() async {
    if (!_isCreator || _stories.isEmpty) return;
    final storyId = _stories[_current]['id']?.toString();
    if (storyId == null) return;

    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _ViewersSheet(storyId: storyId),
    );
  }

  // ════════════════════════════════════════════════════════════════════════
  // BUILD
  // ════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    if (_loading) return _buildLoadingScreen();
    if (_stories.isEmpty) return _buildExpiredScreen();

    final story = _stories[_current];
    final profile = story['profiles'] as Map?;
    final name = _StoryValidators.sanitize(profile?['display_name']?.toString() ?? 'Utilisateur', maxLength: 100);
    final avatar = _StoryValidators.sanitizeUrl(profile?['photo_url']?.toString() ?? profile?['avatar_url']?.toString());
    final mediaUrl = _StoryValidators.sanitizeUrl(story['media_url']?.toString());
    final text = _StoryValidators.sanitize(
      story['text']?.toString() ?? story['text_content']?.toString() ?? '',
      maxLength: 500,
    );
    final bgColor = _StoryValidators.parseHexColor(story['bg_color']?.toString());
    final mediaType = (story['media_type']?.toString() ?? story['type']?.toString() ?? '').toLowerCase();

    DateTime? createdAt;
    try {
      final s = story['created_at']?.toString();
      if (s != null && s.isNotEmpty) createdAt = DateTime.parse(s);
    } catch (e) {
      debugPrint('[Story] Parse date error: $e');
    }

    final storyId = story['id']?.toString() ?? '';
    final likeState = _likeState[storyId] ?? {'liked': false, 'count': 0};
    final liked = likeState['liked'] as bool;
    final likeCount = likeState['count'] as int;
    final heartAnim = _heartAnims[storyId];

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTapDown: _onTapDown,
        onLongPressStart: (_) => _pauseTimer(),
        onLongPressEnd: (_) => _resumeTimer(),
        onVerticalDragUpdate: _onVerticalDragUpdate,
        onVerticalDragEnd: _onVerticalDragEnd,
        child: Transform.translate(
          offset: Offset(0, _dragOffset),
          child: Stack(
            children: [
              // ── MEDIA ──
              Positioned.fill(child: _buildMediaContent(mediaUrl, text, bgColor, mediaType)),

              // ── CŒUR POP ──
              if (heartAnim != null)
                Positioned.fill(child: Center(child: _AnimatedHeartPop(progress: heartAnim.value))),

              // ── PROGRESS + HEADER ──
              SafeArea(
                child: Column(
                  children: [
                    _buildProgressBars(),
                    const SizedBox(height: 12),
                    _buildHeader(name, avatar, createdAt),
                  ],
                ),
              ),

              // ── TEXTE OVERLAY (si média + texte) ──
              if (text.isNotEmpty && mediaUrl != null && mediaType != 'audio')
                Positioned(
                  bottom: 100,
                  left: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      text,
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500, height: 1.4),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),

              // ── BOTTOM BAR (like + vu par + reply) ──
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: _buildBottomBar(liked, likeCount),
              ),

              // ── PAUSE ──
              if (_isPaused)
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.black.withOpacity(0.5), shape: BoxShape.circle),
                    child: const Icon(Icons.pause_rounded, color: Colors.white, size: 48),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════
  // BUILDERS (tous définis ci-dessous)
  // ════════════════════════════════════════════════════════════════════════

  // ── CONTENU MÉDIA (image / audio / texte) ──
  Widget _buildMediaContent(String? mediaUrl, String text, Color? bgColor, String mediaType) {
    final hasImage = mediaType != 'audio' && mediaUrl != null && mediaUrl.isNotEmpty;
    final hasText = text.isNotEmpty;
    final hasBg = bgColor != null;
    final bool isLightBg = hasBg && bgColor.computeLuminance() > 0.5;

    // ── IMAGE ──
    if (hasImage) {
      return InteractiveViewer(
        minScale: 1.0,
        maxScale: 3.0,
        child: CachedNetworkImage(
          imageUrl: mediaUrl!,
          fit: BoxFit.contain,
          placeholder: (context, url) => Container(
            color: bgColor ?? Colors.black,
            child: const Center(child: SizedBox(width: 40, height: 40, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))),
          ),
          errorWidget: (context, url, error) => _buildTextFallback(text, bgColor),
        ),
      );
    }

    // ── AUDIO ──
    if (mediaType == 'audio') {
      return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: hasBg
                ? [bgColor!, bgColor.withOpacity(0.6)]
                : const [Color(0xFF1A1F2E), Color(0xFF0A0E1A)],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(26),
                decoration: BoxDecoration(
                  color: ThixPolicy.gold.withOpacity(0.2),
                  shape: BoxShape.circle,
                  border: Border.all(color: ThixPolicy.gold.withOpacity(0.5), width: 2),
                ),
                child: const Icon(Icons.headphones_rounded, color: ThixPolicy.gold, size: 54),
              ),
              const SizedBox(height: 16),
              Text(
                'Message vocal',
                style: TextStyle(
                  color: isLightBg ? Colors.black : Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (hasText) ...[
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    text,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: isLightBg ? Colors.black87 : Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      height: 1.4,
                      shadows: [
                        Shadow(
                          blurRadius: isLightBg ? 4 : 10,
                          color: isLightBg ? Colors.white24 : Colors.black54,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              if (mediaUrl != null && mediaUrl.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 24),
                  child: _InlineStoryAudio(url: mediaUrl, isLightBg: isLightBg),
                ),
            ],
          ),
        ),
      );
    }

    // ── TEXTE SEUL ──
    return _buildTextFallback(text, bgColor);
  }

  // ── FALLBACK TEXTE ──
  Widget _buildTextFallback(String text, Color? bgColor) {
    final hasText = text.isNotEmpty;
    final hasBg = bgColor != null;
    final bool isLightBg = hasBg && bgColor.computeLuminance() > 0.5;
    final Color textColor = isLightBg ? Colors.black : Colors.white;
    final Color shadowColor = isLightBg ? Colors.black12 : Colors.black;

    return Container(
      color: bgColor ?? Colors.black,
      decoration: bgColor == null
          ? const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF1B3B7A), Color(0xFF0B1B3D)],
              ),
            )
          : null,
      child: hasText
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  text,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    height: 1.4,
                    shadows: [
                      Shadow(blurRadius: isLightBg ? 4 : 10, color: shadowColor, offset: const Offset(0, 2)),
                    ],
                  ),
                ),
              ),
            )
          : Center(
              child: Icon(
                Icons.image_not_supported_outlined,
                color: isLightBg ? Colors.black45 : Colors.white54,
                size: 60,
              ),
            ),
    );
  }

  // ── PROGRESS BARS ──
  Widget _buildProgressBars() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: List.generate(_stories.length, (i) {
          return Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              height: 3,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.3),
                borderRadius: BorderRadius.circular(3),
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: i < _current ? 1.0 : i == _current ? _progress : 0.0,
                  child: Container(
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(3)),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ── HEADER (avec bouton poubelle pour créateur) ──
  Widget _buildHeader(String name, String? avatar, DateTime? createdAt) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: Colors.grey.shade800,
            child: ClipOval(
              child: avatar != null
                  ? CachedNetworkImage(
                      imageUrl: avatar,
                      width: 36,
                      height: 36,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => const Icon(Icons.person, size: 18, color: Colors.white),
                    )
                  : const Icon(Icons.person, size: 18, color: Colors.white),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (createdAt != null)
                  Text(_getTimeAgo(createdAt), style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 11)),
              ],
            ),
          ),
          // ✅ Bouton poubelle (créateur uniquement)
          if (_isCreator)
            IconButton(
              style: IconButton.styleFrom(backgroundColor: Colors.black45),
              icon: const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 22),
              onPressed: () => _deleteStory(_stories[_current]['id'].toString()),
            ),
          IconButton(
            icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  // ── BOTTOM BAR (Like + Reply + Vu par) ──
  Widget _buildBottomBar(bool liked, int likeCount) {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 10, 16, MediaQuery.of(context).padding.bottom + 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black.withOpacity(0.85)],
        ),
      ),
      child: Row(
        children: [
          // ❤️ LIKE
          GestureDetector(
            onTap: _toggleLike,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                  color: liked ? ThixPolicy.danger : Colors.white,
                  size: 28,
                ),
                if (likeCount > 0) ...[
                  const SizedBox(width: 4),
                  Text(
                    '$likeCount',
                    style: TextStyle(color: liked ? ThixPolicy.danger : Colors.white, fontSize: 14, fontWeight: FontWeight.w800),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 16),
          // 💬 REPLY
          GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Messages privés bientôt disponibles'),
                  backgroundColor: Colors.black87,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: const Icon(Icons.send_rounded, color: Colors.white, size: 26),
          ),
          const Spacer(),
          // 👁️ VU PAR (créateur uniquement)
          if (_isCreator)
            GestureDetector(
              onTap: _openViewersSheet,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.visibility_rounded, color: Colors.white, size: 26),
                  const SizedBox(width: 4),
                  Text(
                    _getViewCount().toString(),
                    style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  int _getViewCount() {
    if (_stories.isEmpty) return 0;
    final views = _stories[_current]['views_count'];
    if (views is num) return views.toInt();
    if (views is int) return views;
    return 0;
  }

  // ── LOADING ──
  Widget _buildLoadingScreen() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [ThixPolicy.gold, Color(0xFFFFA500)]),
                shape: BoxShape.circle,
              ),
              child: const Center(child: SizedBox(width: 30, height: 30, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))),
            ),
            const SizedBox(height: 16),
            const Text('Chargement de la story...', style: TextStyle(color: Colors.white70, fontSize: 14)),
          ],
        ),
      ),
    );
  }

  // ── EXPIRÉE ──
  Widget _buildExpiredScreen() {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.close_rounded, color: Colors.white), onPressed: () => Navigator.pop(context)),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), shape: BoxShape.circle),
              child: const Icon(Icons.hourglass_empty_rounded, color: Colors.white54, size: 64),
            ),
            const SizedBox(height: 24),
            const Text('Story expirée', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Cette story n\'est plus disponible', style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 14)),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// CŒUR POP ANIMATION
// ============================================================================
class _AnimatedHeartPop extends StatelessWidget {
  final double progress;
  const _AnimatedHeartPop({required this.progress});

  @override
  Widget build(BuildContext context) {
    double scale;
    double opacity;
    if (progress < 0.3) {
      scale = 0.5 + (progress / 0.3) * 0.9;
      opacity = progress / 0.3;
    } else {
      scale = 1.4 - ((progress - 0.3) / 0.7) * 0.3;
      opacity = 1.0 - ((progress - 0.3) / 0.7);
    }
    return Transform.scale(
      scale: scale,
      child: Opacity(
        opacity: opacity.clamp(0.0, 1.0),
        child: const Icon(Icons.favorite_rounded, color: ThixPolicy.danger, size: 140, shadows: [Shadow(color: Colors.black54, blurRadius: 12)]),
      ),
    );
  }
}

// ============================================================================
// LECTEUR AUDIO INLINE
// ============================================================================
class _InlineStoryAudio extends StatefulWidget {
  final String url;
  final bool isLightBg;
  const _InlineStoryAudio({required this.url, required this.isLightBg});
  @override
  State<_InlineStoryAudio> createState() => _InlineStoryAudioState();
}

class _InlineStoryAudioState extends State<_InlineStoryAudio> {
  final AudioPlayer _player = AudioPlayer();
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      await _player.setSourceUrl(widget.url);
      _player.onPlayerStateChanged.listen((s) {
        if (mounted) setState(() => _isPlaying = s == PlayerState.playing);
      });
      _player.onPositionChanged.listen((p) {
        if (mounted) setState(() => _position = p);
      });
      _player.onDurationChanged.listen((d) {
        if (mounted) setState(() => _duration = d);
      });
    } catch (e) {
      debugPrint('[StoryAudio] init: $e');
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  String _fmt(Duration d) =>
      '${d.inMinutes.toString().padLeft(2, '0')}:${d.inSeconds.remainder(60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final bgColor = widget.isLightBg ? Colors.black.withOpacity(0.15) : Colors.white12;
    final fgColor = widget.isLightBg ? Colors.black87 : Colors.white;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(24)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: () async {
              if (_isPlaying) {
                await _player.pause();
              } else {
                await _player.resume();
              }
            },
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: const BoxDecoration(color: ThixPolicy.gold, shape: BoxShape.circle),
              child: Icon(_isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, color: Colors.black, size: 20),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '${_fmt(_position)} / ${_fmt(_duration)}',
            style: TextStyle(color: fgColor, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// SHEET "VU PAR" (agnostique au schéma)
// ============================================================================
class _ViewersSheet extends StatefulWidget {
  final String storyId;
  const _ViewersSheet({required this.storyId});
  @override
  State<_ViewersSheet> createState() => _ViewersSheetState();
}

class _ViewersSheetState extends State<_ViewersSheet> {
  List<Map<String, dynamic>> _viewers = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadViewers();
  }

  /// ✅ Agnostique au schéma : charge viewer_id + viewed_at, puis profils séparément
  Future<void> _loadViewers() async {
    try {
      final supa = Supabase.instance.client;

      // 1) Récupère les vues (colonne viewer_id uniquement)
      final res = await supa
          .from('story_views')
          .select('viewer_id, viewed_at')
          .eq('story_id', widget.storyId)
          .order('viewed_at', ascending: false)
          .timeout(const Duration(seconds: 10));

      final rows = (res as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();

      // 2) Extraction des viewer_ids uniques
      final ids = <String>{};
      for (final r in rows) {
        final vid = r['viewer_id']?.toString();
        if (vid != null && vid.isNotEmpty) ids.add(vid);
      }

      // 3) Chargement des profils
      final profiles = <String, Map<String, dynamic>>{};
      if (ids.isNotEmpty) {
        final pres = await supa
            .from('profiles')
            .select('id, display_name, username, avatar_url, photo_url')
            .inFilter('id', ids.toList())
            .timeout(const Duration(seconds: 10));
        for (final p in pres as List) {
          final m = Map<String, dynamic>.from(p as Map);
          profiles[m['id'].toString()] = m;
        }
      }

      // 4) Assemblage
      if (mounted) {
        setState(() {
          _viewers = rows
              .where((r) => r['viewer_id'] != null)
              .map((r) => {
                    'viewer_id': r['viewer_id'],
                    'viewed_at': r['viewed_at'],
                    'viewer': profiles[r['viewer_id'].toString()],
                  })
              .toList();
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('[Viewers] load: $e');
      if (mounted) setState(() { _loading = false; _error = 'Erreur de chargement'; });
    }
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'À l\'instant';
    if (diff.inMinutes < 60) return 'il y a ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'il y a ${diff.inHours} h';
    return 'il y a ${diff.inDays} j';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
      decoration: const BoxDecoration(
        color: Color(0xFF141821),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Center(
              child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.visibility_rounded, color: ThixPolicy.primary, size: 22),
                const SizedBox(width: 10),
                Text('Vu par (${_viewers.length})',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
              ],
            ),
          ),
          const Divider(height: 1, color: Colors.white12),
          Flexible(
            child: _loading
                ? const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator(color: ThixPolicy.primary)))
                : _error != null
                    ? Padding(padding: const EdgeInsets.all(24), child: Text(_error!, style: const TextStyle(color: ThixPolicy.danger)))
                    : _viewers.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.all(32),
                            child: Column(mainAxisSize: MainAxisSize.min, children: [
                              Icon(Icons.visibility_off_rounded, size: 40, color: Colors.white38),
                              SizedBox(height: 8),
                              Text('Personne n\'a vu cette story', style: TextStyle(color: Colors.white54)),
                            ]),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            itemCount: _viewers.length,
                            itemBuilder: (context, i) {
                              final v = _viewers[i];
                              final viewer = v['viewer'] as Map?;
                              final name = (viewer?['display_name'] ?? viewer?['username'] ?? 'Utilisateur').toString();
                              final avatar = viewer?['photo_url']?.toString() ?? viewer?['avatar_url']?.toString();
                              DateTime? viewedAt;
                              try { viewedAt = DateTime.parse(v['viewed_at'].toString()); } catch (_) {}

                              return ListTile(
                                leading: CircleAvatar(
                                  radius: 22,
                                  backgroundColor: Colors.white12,
                                  backgroundImage: (avatar != null && avatar.isNotEmpty) ? CachedNetworkImageProvider(avatar) : null,
                                  child: avatar == null || avatar.isEmpty
                                      ? const Icon(Icons.person, size: 18, color: Colors.white54)
                                      : null,
                                ),
                                title: Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                                subtitle: viewedAt != null
                                    ? Text(_timeAgo(viewedAt), style: const TextStyle(color: Colors.white54, fontSize: 12))
                                    : null,
                              );
                            },
                          ),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
        ],
      ),
    );
  }
}
