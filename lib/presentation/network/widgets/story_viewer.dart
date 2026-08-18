// lib/presentation/network/widgets/story_viewer.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../models/network_story.dart';

// ✅ CERTIFICATION & SYNCHRO PROFIL
import 'package:thix_id/models/certification_tier.dart';
import 'package:thix_id/presentation/certification/widgets/certification_name_badge.dart';
import 'package:thix_id/features/network/presentation/providers/user_profile_providers.dart';

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

class _StoryViewerState extends State<StoryViewer> {
  late PageController _controller;
  late int _currentIndex;
  Timer? _timer;
  double _progress = 0;
  bool _paused = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, widget.stories.length - 1);
    _controller = PageController(initialPage: _currentIndex);
    _markViewed(widget.stories[_currentIndex]);
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  String _mediaUrl(NetworkStory s) {
    // imageUrl est le champ canonique du modèle
    final u = s.imageUrl.trim();
    if (u.isNotEmpty) return u;
    return '';
  }

  void _startTimer() {
    _timer?.cancel();
    _progress = 0;

    // Stories texte seules : un peu plus long
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
      _controller.nextPage(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    } else if (mounted) {
      Navigator.of(context).maybePop();
    }
  }

  void _goPrev() {
    if (_currentIndex > 0) {
      _controller.previousPage(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _markViewed(NetworkStory s) async {
    try {
      final uid = Supabase.instance.client.auth.currentUser?.id;
      if (uid == null || uid == s.userId) return;
      await Supabase.instance.client.from('story_views').upsert(
        {'story_id': s.id, 'user_id': uid},
        onConflict: 'story_id,user_id',
        ignoreDuplicates: true,
      );
    } catch (_) {}
  }

  Future<void> _deleteStory(String storyId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Supprimer la story ?'),
        content: const Text('Cette action est irréversible.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Supprimer',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await Supabase.instance.client
          .from('stories')
          .delete()
          .eq('id', storyId);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Story supprimée'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.stories.isEmpty) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Text('Aucune story', style: TextStyle(color: Colors.white)),
        ),
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
            final text = (s.textContent ?? '').trim();
            final isMyStory = s.userId == currentUserId;

            return Stack(
              fit: StackFit.expand,
              children: [
                // MÉDIA
                if (url.isNotEmpty)
                  Image.network(
                    url,
                    // ✅ MODIFICATION ICI : contain au lieu de cover pour éviter le "zoom/crop"
                    fit: BoxFit.contain, 
                    loadingBuilder: (_, child, progress) {
                      if (progress == null) return child;
                      return Container(
                        color: const Color(0xFF0B1B3D),
                        child: const Center(
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        ),
                      );
                    },
                    errorBuilder: (_, __, ___) => Container(
                      color: const Color(0xFF0B1B3D),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.broken_image,
                              color: Colors.white54, size: 48),
                          const SizedBox(height: 12),
                          if (text.isNotEmpty)
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 24),
                              child: Text(
                                text,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  )
                else
                  // Texte seul / pas de média
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF1B3B7A), Color(0xFF0B1B3D)],
                      ),
                    ),
                    child: text.isNotEmpty
                        ? Center(
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 28),
                              child: Text(
                                text,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 26,
                                  fontWeight: FontWeight.w700,
                                  height: 1.3,
                                ),
                              ),
                            ),
                          )
                        : const Center(
                            child: Text(
                              'Story sans contenu',
                              style: TextStyle(color: Colors.white54),
                            ),
                          ),
                  ),

                // Texte overlay si image + texte
                if (url.isNotEmpty && text.isNotEmpty)
                  Positioned(
                    left: 20,
                    right: 20,
                    bottom: 80,
                    child: Text(
                      text,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        shadows: [
                          Shadow(color: Colors.black54, blurRadius: 8),
                        ],
                      ),
                    ),
                  ),

                // Barres de progression
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
                              margin:
                                  const EdgeInsets.symmetric(horizontal: 2),
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

                // Header avec Certification
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
                          backgroundImage: s.userAvatar != null &&
                                  s.userAvatar!.isNotEmpty
                              ? NetworkImage(s.userAvatar!)
                              : null,
                          child: s.userAvatar == null ||
                                  s.userAvatar!.isEmpty
                              ? const Icon(Icons.person,
                                  color: Colors.white, size: 18)
                              : null,
                        ),
                        const SizedBox(width: 10),
                        
                        // ✅ Consumer ajouté pour interroger le provider et afficher la certification
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
                                isCertified = status == CertificationStatus.approved || status == CertificationStatus.generated;
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
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.black45,
                            ),
                            icon: const Icon(Icons.delete_outline,
                                color: Colors.white),
                            onPressed: () => _deleteStory(s.id),
                          ),
                        IconButton(
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.black45,
                          ),
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: () =>
                              Navigator.of(context).maybePop(),
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
