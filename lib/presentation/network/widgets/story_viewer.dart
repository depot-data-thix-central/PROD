// lib/presentation/network/widgets/story_viewer.dart
// ============================================================================
// STORY VIEWER — Plein écran avec Like ❤️ + Vu par 👁️ + Audio + Suppression
// • Like animé (cœur pop) + persistance DB (story_likes)
// • Vu par (sheet liste viewers, uniquement pour le créateur)
// • Support audio (lecteur inline play/pause)
// • Support fond coloré (bg_color)
// • Suppression de la story (avec confirmation)
// • Certification badge sur le nom de l'auteur
// ============================================================================
import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../models/network_story.dart';

import 'package:thix_id/models/certification_tier.dart';
import 'package:thix_id/presentation/certification/widgets/certification_name_badge.dart';
import 'package:thix_id/features/network/presentation/providers/user_profile_providers.dart';
import 'package:thix_id/core/theme/thix_design_policy.dart';

class StoryViewer extends StatefulWidget {
  final List<NetworkStory> stories;
  final int initialIndex;

  const StoryViewer({
    super.key,
    required this.stories,
    required this.initialIndex,
  });

  @override
  State<StoryViewer> createState() => _StoryViewerState();
}

class _StoryViewerState extends State<StoryViewer> with TickerProviderStateMixin {
  late PageController _controller;
  late int _currentIndex;
  Timer? _timer;
  double _progress = 0;
  bool _paused = false;

  // ── Like state (storyId -> {liked, count}) ──
  final Map<String, Map<String, dynamic>> _likeState = {};
  // ── Animation cœur pop (storyId -> AnimationController) ──
  final Map<String, AnimationController> _heartAnims = {};

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, widget.stories.length - 1);
    _controller = PageController(initialPage: _currentIndex);
    _markViewed(widget.stories[_currentIndex]);
    _startTimer();
    _loadLikes();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    for (final c in _heartAnims.values) {
      c.dispose();
    }
    super.dispose();
  }

  // ════════════════════════════════════════════════════════════════════════
  // HELPERS — lecture sûre des champs additionnels du modèle
  // ════════════════════════════════════════════════════════════════════════
  String _mediaUrl(NetworkStory s) => s.imageUrl.trim();
  String _textContent(NetworkStory s) => (s.textContent ?? '').trim();

  String? _bgColor(NetworkStory s) {
    try {
      return (s as dynamic).bgColor as String?;
    } catch (_) {
      return null;
    }
  }

  String? _mediaType(NetworkStory s) {
    try {
      return (s as dynamic).mediaType as String?;
    } catch (_) {
      // Fallback : déduction depuis le contenu
      final url = _mediaUrl(s);
      if (url.isEmpty) return 'text';
      final lower = url.toLowerCase();
      if (lower.endsWith('.m4a') || lower.endsWith('.mp3') || lower.endsWith('.aac')) return 'audio';
      return 'image';
    }
  }

  Color? _parseHex(String? hex) {
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

  // ════════════════════════════════════════════════════════════════════════
  // TIMER & NAVIGATION
  // ════════════════════════════════════════════════════════════════════════
  void _startTimer() {
    _timer?.cancel();
    _progress = 0;
    final s = widget.stories[_currentIndex];
    final hasMedia = _mediaUrl(s).isNotEmpty;
    final durationMs = hasMedia ? 5000 : 4000;

    const tick = Duration(milliseconds: 50);
    _timer = Timer.periodic(tick, (t) {
      if (_paused || !mounted) return;
      setState(() {
        _progress += tick.inMilliseconds / durationMs;
        if (_progress >= 1) {
          _progress = 0;
          _goNext();
        }
      });
    });
  }

  void _goNext() {
    if (_currentIndex < widget.stories.length - 1) {
      _controller.nextPage(duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    } else if (mounted) {
      Navigator.of(context).maybePop();
    }
  }

  void _goPrev() {
    if (_currentIndex > 0) {
      _controller.previousPage(duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
    }
  }

  // ════════════════════════════════════════════════════════════════════════
  // VIEWS + LIKES
  // ════════════════════════════════════════════════════════════════════════
  Future<void> _markViewed(NetworkStory s) async {
    try {
      final uid = Supabase.instance.client.auth.currentUser?.id;
      if (uid == null || uid == s.userId) return;
      await Supabase.instance.client.from('story_views').upsert(
        {
          'story_id': s.id,
          'viewer_id': uid,
          'viewed_at': DateTime.now().toUtc().toIso8601String(),
        },
        onConflict: 'story_id,viewer_id',
        ignoreDuplicates: true,
      );
    } catch (_) {}
  }

  Future<void> _loadLikes() async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;

    final ids = widget.stories.map((s) => s.id).toList();
    if (ids.isEmpty) return;

    try {
      final supa = Supabase.instance.client;

      // Comptages
      final counts = await supa.from('story_likes').select('story_id').inFilter('story_id', ids);
      final countMap = <String, int>{};
      for (final row in counts as List) {
        final id = (row as Map)['story_id']?.toString();
        if (id != null) countMap[id] = (countMap[id] ?? 0) + 1;
      }

      // Mes likes
      final myLikes = await supa.from('story_likes').select('story_id').eq('user_id', uid).inFilter('story_id', ids);
      final likedSet = <String>{};
      for (final row in myLikes as List) {
        final id = (row as Map)['story_id']?.toString();
        if (id != null) likedSet.add(id);
      }

      if (mounted) {
        setState(() {
          for (final id in ids) {
            _likeState[id] = {'liked': likedSet.contains(id), 'count': countMap[id] ?? 0};
          }
        });
      }
    } catch (e) {
      debugPrint('[Story] loadLikes: $e');
    }
  }

  Future<void> _toggleLike() async {
    final s = widget.stories[_currentIndex];
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;

    final state = _likeState[s.id] ?? {'liked': false, 'count': 0};
    final wasLiked = state['liked'] as bool;
    final count = (state['count'] as int) + (wasLiked ? -1 : 1);

    setState(() {
      _likeState[s.id] = {'liked': !wasLiked, 'count': count.clamp(0, 999999)};
    });

    HapticFeedback.mediumImpact();
    if (!wasLiked) _playHeartPop(s.id);

    try {
      final supa = Supabase.instance.client;
      if (wasLiked) {
        await supa.from('story_likes').delete().eq('story_id', s.id).eq('user_id', uid);
      } else {
        await supa.from('story_likes').upsert(
          {'story_id': s.id, 'user_id': uid, 'created_at': DateTime.now().toUtc().toIso8601String()},
          onConflict: 'story_id,user_id',
        );
      }
    } catch (e) {
      debugPrint('[Story] toggleLike: $e');
      // Rollback
      setState(() {
        _likeState[s.id] = {'liked': wasLiked, 'count': state['count'] as int};
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

    try {
      await Supabase.instance.client.from('stories').delete().eq('id', storyId);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Story supprimée'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // ════════════════════════════════════════════════════════════════════════
  // VU PAR (sheet)
  // ════════════════════════════════════════════════════════════════════════
  Future<void> _openViewersSheet(String storyId) async {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _ViewersSheet(storyId: storyId),
    );
  }

  // ════════════════════════════════════════════════════════════════════════
  // BUILD
  // ════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    if (widget.stories.isEmpty) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: Text('Aucune story', style: TextStyle(color: Colors.white))),
      );
    }

    final currentUserId = Supabase.instance.client.auth.currentUser?.id;

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTapDown: (details) {
          final dx = details.globalPosition.dx;
          final w = MediaQuery.of(context).size.width;
          if (dx < w * 0.3) {
            _goPrev();
          } else if (dx > w * 0.7) {
            _goNext();
          } else {
            _toggleLike(); // Tap central = like
          }
        },
        onLongPressStart: (_) => setState(() => _paused = true),
        onLongPressEnd: (_) => setState(() => _paused = false),
        child: PageView.builder(
          controller: _controller,
          itemCount: widget.stories.length,
          onPageChanged: (i) {
            setState(() {
              _currentIndex = i;
              _progress = 0;
            });
            _markViewed(widget.stories[i]);
            _startTimer();
          },
          itemBuilder: (context, index) {
            final s = widget.stories[index];
            final url = _mediaUrl(s);
            final text = _textContent(s);
            final isMyStory = s.userId == currentUserId;
            final bgColor = _parseHex(_bgColor(s));
            final mediaType = _mediaType(s) ?? 'image';
            final likeState = _likeState[s.id] ?? {'liked': false, 'count': 0};
            final liked = likeState['liked'] as bool;
            final likeCount = likeState['count'] as int;
            final heartAnim = _heartAnims[s.id];

            return Stack(
              fit: StackFit.expand,
              children: [
                // ── MÉDIA ──
                _buildMediaContent(url, text, bgColor, mediaType),

                // ── CŒUR POP ANIMÉ ──
                if (heartAnim != null)
                  Center(child: _AnimatedHeartPop(progress: heartAnim.value)),

                // ── TEXTE OVERLAY si image + texte ──
                if (url.isNotEmpty && text.isNotEmpty && mediaType != 'audio')
                  Positioned(
                    left: 20,
                    right: 20,
                    bottom: 110,
                    child: Text(
                      text,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        shadows: [Shadow(color: Colors.black54, blurRadius: 8)],
                      ),
                    ),
                  ),

                // ── BARRES DE PROGRESSION ──
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                      child: Row(
                        children: List.generate(widget.stories.length, (i) {
                          return Expanded(
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 2),
                              height: 3,
                              decoration: BoxDecoration(
                                color: Colors.white24,
                                borderRadius: BorderRadius.circular(2),
                              ),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: FractionallySizedBox(
                                  widthFactor: i == _currentIndex
                                      ? _progress.clamp(0.0, 1.0)
                                      : (i < _currentIndex ? 1.0 : 0.0),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                  ),
                ),

                // ── HEADER (avatar + nom + certification + boutons) ──
                Positioned(
                  top: 18,
                  left: 12,
                  right: 12,
                  child: SafeArea(
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: Colors.white24,
                          backgroundImage: s.userAvatar != null && s.userAvatar!.isNotEmpty
                              ? NetworkImage(s.userAvatar!)
                              : null,
                          child: s.userAvatar == null || s.userAvatar!.isEmpty
                              ? const Icon(Icons.person, color: Colors.white, size: 18)
                              : null,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Consumer(
                            builder: (context, ref, _) {
                              final authorProfile = ref.watch(userProfileProvider(s.userId)).valueOrNull;
                              CertificationTier? tier;
                              CertificationStatus? status;
                              bool isCertified = false;
                              bool isLegacyVerified = false;
                              if (authorProfile != null) {
                                tier = CertificationTierX.parse(authorProfile['certification_tier']);
                                status = CertificationStatusX.parse(authorProfile['certification_status']);
                                isCertified = status == CertificationStatus.approved ||
                                    status == CertificationStatus.generated;
                                isLegacyVerified = authorProfile['is_verified'] == true;
                              }
                              return Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      s.userName,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (isCertified)
                                    CertificationNameBadge(
                                      tier: tier,
                                      status: status,
                                      showLabel: false,
                                      iconSize: 14,
                                      padding: const EdgeInsets.only(left: 4),
                                    )
                                  else if (isLegacyVerified)
                                    const Padding(
                                      padding: EdgeInsets.only(left: 4),
                                      child: Icon(Icons.verified_rounded, color: Color(0xFFE3B23C), size: 14),
                                    ),
                                ],
                              );
                            },
                          ),
                        ),
                        if (isMyStory)
                          IconButton(
                            style: IconButton.styleFrom(backgroundColor: Colors.black45),
                            icon: const Icon(Icons.visibility_rounded, color: Colors.white),
                            onPressed: () => _openViewersSheet(s.id),
                          ),
                        if (isMyStory)
                          IconButton(
                            style: IconButton.styleFrom(backgroundColor: Colors.black45),
                            icon: const Icon(Icons.delete_outline, color: Colors.white),
                            onPressed: () => _deleteStory(s.id),
                          ),
                        IconButton(
                          style: IconButton.styleFrom(backgroundColor: Colors.black45),
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: () => Navigator.of(context).maybePop(),
                        ),
                      ],
                    ),
                  ),
                ),

                // ── PAUSE INDICATOR ──
                if (_paused)
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: Colors.black.withOpacity(0.5), shape: BoxShape.circle),
                      child: const Icon(Icons.pause_rounded, color: Colors.white, size: 48),
                    ),
                  ),

                // ── BOTTOM BAR (like + répondre) ──
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: _BottomBar(
                    liked: liked,
                    likeCount: likeCount,
                    onLike: _toggleLike,
                    onReply: () {
                      HapticFeedback.selectionClick();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Messages privés bientôt disponibles'),
                          backgroundColor: Colors.black87,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // ── CONTENU MÉDIA (image / audio / texte) ──
  Widget _buildMediaContent(String url, String text, Color? bgColor, String mediaType) {
    final hasText = text.isNotEmpty;
    final hasBg = bgColor != null;
    final isAudio = mediaType == 'audio' ||
        url.toLowerCase().endsWith('.m4a') ||
        url.toLowerCase().endsWith('.mp3');

    // ── DEBUG : vérifie que bgColor est bien passé ──
    debugPrint('[StoryView] id=${widget.stories[_currentIndex].id} '
        'mediaType=$mediaType url=${url.isEmpty ? "<empty>" : "ok"} '
        'bgColor=${bgColor?.toARGB32().toRadixString(16)} text="${text.substring(0, text.length.clamp(0, 30))}"');

    // ── CAS 1 : AUDIO — fond dégradé + lecteur ──
    if (isAudio) {
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
              const Text('Message vocal',
                  style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800)),
              if (hasText) ...[
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(text,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600, height: 1.4)),
                ),
              ],
              if (url.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 24),
                  child: _InlineStoryAudio(url: url),
                ),
            ],
          ),
        ),
      );
    }

    // ── CAS 2 : IMAGE (avec ou sans texte) ──
    if (url.isNotEmpty) {
      return Stack(
        fit: StackFit.expand,
        children: [
          // Fond coloré en dessous (visible si image transparente / chargement)
          Container(color: bgColor ?? const Color(0xFF0B1B3D)),
          // Image par-dessus
          Image.network(
            url,
            fit: BoxFit.contain,
            loadingBuilder: (_, child, progress) {
              if (progress == null) return child;
              return const Center(
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2));
            },
            errorBuilder: (_, __, ___) => _textFallback(text, bgColor),
          ),
          // Texte overlay en bas
          if (hasText)
            Positioned(
              left: 20,
              right: 20,
              bottom: 110,
              child: Text(
                text,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  shadows: [Shadow(color: Colors.black54, blurRadius: 8)],
                ),
              ),
            ),
        ],
      );
    }

    // ── CAS 3 : TEXTE SEUL — fond coloré OU dégradé ──
    return _textFallback(text, bgColor);
  }

  Widget _textFallback(String text, Color? bgColor) {
    final hasText = text.isNotEmpty;
    return Container(
      // ✅ Fond coloré en priorité, sinon dégradé
      color: bgColor,
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
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Text(
                  text,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                    // Ombre plus forte sur fond clair (jaune, or) pour lisibilité
                    shadows: [
                      Shadow(blurRadius: 10, color: Colors.black.withOpacity(0.7), offset: const Offset(0, 2)),
                    ],
                  ),
                ),
              ),
            )
          : const Center(
              child: Text('Story sans contenu', style: TextStyle(color: Colors.white54)),
            ),
    );
  }
}

// ============================================================================
// BOTTOM BAR (Like + Répondre)
// ============================================================================
class _BottomBar extends StatelessWidget {
  final bool liked;
  final int likeCount;
  final VoidCallback onLike;
  final VoidCallback onReply;

  const _BottomBar({
    required this.liked,
    required this.likeCount,
    required this.onLike,
    required this.onReply,
  });

  @override
  Widget build(BuildContext context) {
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
          GestureDetector(
            onTap: onLike,
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
                  Text('$likeCount',
                      style: TextStyle(
                          color: liked ? ThixPolicy.danger : Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w800)),
                ],
              ],
            ),
          ),
          const SizedBox(width: 20),
          GestureDetector(
            onTap: onReply,
            child: const Icon(Icons.send_rounded, color: Colors.white, size: 26),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// CŒUR POP ANIMATION (double-tap style)
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
        child: const Icon(Icons.favorite_rounded, color: ThixPolicy.danger, size: 140,
            shadows: [Shadow(color: Colors.black54, blurRadius: 12)]),
      ),
    );
  }
}

// ============================================================================
// LECTEUR AUDIO INLINE (pour stories audio)
// ============================================================================
class _InlineStoryAudio extends StatefulWidget {
  final String url;
  const _InlineStoryAudio({required this.url});
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(24)),
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
              child: Icon(_isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: Colors.black, size: 20),
            ),
          ),
          const SizedBox(width: 12),
          Text('${_fmt(_position)} / ${_fmt(_duration)}',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

// ============================================================================
// SHEET "VU PAR" (liste viewers)
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

  Future<void> _loadViewers() async {
    try {
      final supa = Supabase.instance.client;
      final res = await supa
          .from('story_views')
          .select('viewed_at, viewer:viewer_id(display_name, photo_url, avatar_url, username)')
          .eq('story_id', widget.storyId)
          .order('viewed_at', ascending: false)
          .timeout(const Duration(seconds: 10));

      final list = (res as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      if (mounted) setState(() { _viewers = list; _loading = false; });
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
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
              ),
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
                ? const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator(color: ThixPolicy.primary)),
                  )
                : _error != null
                    ? Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(_error!, style: const TextStyle(color: ThixPolicy.danger)),
                      )
                    : _viewers.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.all(32),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.visibility_off_rounded, size: 40, color: Colors.white38),
                                SizedBox(height: 8),
                                Text('Personne n\'a vu cette story',
                                    style: TextStyle(color: Colors.white54)),
                              ],
                            ),
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
                                  backgroundImage: (avatar != null && avatar.isNotEmpty) ? NetworkImage(avatar) : null,
                                  child: avatar == null || avatar.isEmpty
                                      ? const Icon(Icons.person, size: 18, color: Colors.white54)
                                      : null,
                                ),
                                title: Text(name,
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                                subtitle: viewedAt != null
                                    ? Text(_timeAgo(viewedAt),
                                        style: const TextStyle(color: Colors.white54, fontSize: 12))
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
