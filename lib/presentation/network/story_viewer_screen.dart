// lib/presentation/network/story_viewer_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:html/parser.dart' as html_parser;

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
    if (!trimmed.startsWith('http://') && !trimmed.startsWith('https://')) {
      return null;
    }
    return trimmed.replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '');
  }
}

// ============================================================================
// COMPOSANT PRINCIPAL
// ============================================================================
class StoryViewerScreen extends StatefulWidget {
  final String storyId;
  final String? userId;
  
  const StoryViewerScreen({
    super.key,
    required this.storyId,
    this.userId,
  });
  
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
  
  // Animation pour swipe vertical
  late AnimationController _dragController;
  double _dragOffset = 0;
  
  // Préchargement
  final Map<String, ImageProvider> _imageCache = {};
  
  static const Duration _storyDuration = Duration(seconds: 5);
  static const Duration _requestTimeout = Duration(seconds: 10);
  static const int _timerIntervalMs = 50;

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
    super.dispose();
  }

  Future<void> _load() async {
    final supa = Supabase.instance.client;
    
    try {
      // Charger la story initiale
      final first = await supa
          .from('stories')
          .select('*, profiles(display_name, photo_url, avatar_url)')
          .eq('id', widget.storyId)
          .single()
          .timeout(_requestTimeout);
      
      final uid = widget.userId ?? first['user_id'];
      
      // Charger toutes les stories actives de l'utilisateur
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
    } catch (e) {
      debugPrint('[Story] Load error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _progress = 0;
    _isPaused = false;
    
    final steps = _storyDuration.inMilliseconds ~/ _timerIntervalMs;
    final increment = 1.0 / steps;
    
    _timer = Timer.periodic(const Duration(milliseconds: _timerIntervalMs), (t) {
      if (!mounted || _isPaused || _isDragging) return;
      
      setState(() => _progress += increment);
      
      if (_progress >= 1.0) {
        _next();
      }
    });
  }

  void _pauseTimer() {
    _isPaused = true;
    HapticFeedback.selectionClick();
  }

  void _resumeTimer() {
    _isPaused = false;
    HapticFeedback.selectionClick();
  }

  void _preloadNext() {
    if (_current < _stories.length - 1) {
      final nextStory = _stories[_current + 1];
      final mediaUrl = _StoryValidators.sanitizeUrl(nextStory['media_url']?.toString());
      
      if (mediaUrl != null && !_imageCache.containsKey(mediaUrl)) {
        _imageCache[mediaUrl] = CachedNetworkImageProvider(mediaUrl);
        // Préchargement automatique
        precacheImage(_imageCache[mediaUrl]!, context);
      }
    }
  }

  Future<void> _markViewed() async {
    if (_stories.isEmpty || _current >= _stories.length) return;
    
    final storyId = _stories[_current]['id']?.toString();
    if (storyId == null) return;
    
    final viewerId = Supabase.instance.client.auth.currentUser?.id;
    if (viewerId == null) return;
    
    try {
      // Marquer comme vue dans la table stories
      await Supabase.instance.client
          .from('stories')
          .update({'is_viewed': true})
          .eq('id', storyId)
          .timeout(_requestTimeout);
      
      // Insérer dans story_views (compteur)
      await Supabase.instance.client
          .from('story_views')
          .upsert({
            'story_id': storyId,
            'viewer_id': viewerId,
            'viewed_at': DateTime.now().toUtc().toIso8601String(),
          }, onConflict: 'story_id,viewer_id')
          .timeout(_requestTimeout);
    } catch (e) {
      debugPrint('[Story] Mark viewed error: $e');
    }
  }

  void _next() {
    if (_current < _stories.length - 1) {
      HapticFeedback.lightImpact();
      setState(() => _current++);
      _startTimer();
      _markViewed();
      _preloadNext();
    } else {
      if (mounted) Navigator.pop(context);
    }
  }

  void _prev() {
    if (_current > 0) {
      HapticFeedback.lightImpact();
      setState(() => _current--);
      _startTimer();
      _markViewed();
    }
  }

  void _onTapDown(TapDownDetails details) {
    final width = MediaQuery.of(context).size.width;
    final x = details.globalPosition.dx;
    
    if (x < width / 3) {
      _prev();
    } else if (x > width * 2 / 3) {
      _next();
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
      // Swipe down = fermer
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

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return _buildLoadingScreen();
    }
    
    if (_stories.isEmpty) {
      return _buildExpiredScreen();
    }
    
    final story = _stories[_current];
    final profile = story['profiles'] as Map?;
    final name = _StoryValidators.sanitize(profile?['display_name']?.toString() ?? 'Utilisateur', maxLength: 100);
    final avatar = _StoryValidators.sanitizeUrl(profile?['photo_url']?.toString() ?? profile?['avatar_url']?.toString());
    final mediaUrl = _StoryValidators.sanitizeUrl(story['media_url']?.toString());
    final text = _StoryValidators.sanitize(
      story['text']?.toString() ?? story['text_content']?.toString() ?? '',
      maxLength: 500,
    );
    
    DateTime? createdAt;
    try {
      final createdAtStr = story['created_at']?.toString();
      if (createdAtStr != null && createdAtStr.isNotEmpty) {
        createdAt = DateTime.parse(createdAtStr);
      }
    } catch (e) {
      debugPrint('[Story] Parse date error: $e');
    }

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
              // MEDIA
              Positioned.fill(
                child: _buildMediaContent(mediaUrl, text),
              ),
              
              // PROGRESS BARS + HEADER
              SafeArea(
                child: Column(
                  children: [
                    _buildProgressBars(),
                    const SizedBox(height: 12),
                    _buildHeader(name, avatar, createdAt),
                  ],
                ),
              ),
              
              // TEXTE SUPERPOSÉ (si média + texte)
              if (text.isNotEmpty && mediaUrl != null)
                Positioned(
                  bottom: 40,
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
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              
              // INDICATEUR PAUSE
              if (_isPaused)
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.pause_rounded, color: Colors.white, size: 48),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMediaContent(String? mediaUrl, String text) {
    if (mediaUrl != null && mediaUrl.isNotEmpty) {
      return InteractiveViewer(
        minScale: 1.0,
        maxScale: 3.0,
        child: CachedNetworkImage(
          imageUrl: mediaUrl,
          fit: BoxFit.contain,
          placeholder: (context, url) => Container(
            color: Colors.black,
            child: const Center(
              child: SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
              ),
            ),
          ),
          errorWidget: (context, url, error) => Container(
            color: Colors.black,
            child: const Center(
              child: Icon(Icons.broken_image_outlined, color: Colors.white, size: 60),
            ),
          ),
        ),
      );
    } else if (text.isNotEmpty) {
      return Container(
        color: Colors.black,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
                height: 1.4,
                shadows: [
                  Shadow(blurRadius: 8, color: Colors.black, offset: Offset(0, 2)),
                ],
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    } else {
      return Container(
        color: Colors.black,
        child: const Center(
          child: Icon(Icons.image_not_supported_outlined, color: Colors.white54, size: 60),
        ),
      );
    }
  }

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
                  widthFactor: i < _current
                      ? 1.0
                      : i == _current
                          ? _progress
                          : 0.0,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

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
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (createdAt != null)
                  Text(
                    _getTimeAgo(createdAt),
                    style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 11),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

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
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [ThixPolicy.gold, Color(0xFFFFA500)]),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: SizedBox(
                  width: 30,
                  height: 30,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Chargement de la story...',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpiredScreen() {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.hourglass_empty_rounded, color: Colors.white54, size: 64),
            ),
            const SizedBox(height: 24),
            const Text(
              'Story expirée',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Cette story n\'est plus disponible',
              style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
