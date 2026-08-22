// lib/presentation/thix_media/user_profile_page.dart
import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../services/media_service.dart';
import '../../models/media_content.dart';
import 'video_player_page.dart';
import 'package:thix_id/core/theme/thix_design_policy.dart'; // Pour récupérer des constantes de style si besoin

// ============================================================================
// PALETTE — Charte Premium THIX / TDIA
// ============================================================================
class _ProfileColors {
  static const navyDeep = Color(0xFF0A1F44);
  static const navy = Color(0xFF123B7A);
  static const primary = Color(0xFF2D6CDF);
  static const whiteAccent = Colors.white;
  static const whiteMuted = Color(0xFFE2E8F0);
  static const cardLight = Color(0xFF16294D);
  static const border = Color(0x1AFFFFFF);
  static const textMuted = Color(0xFFAEB9D4);
  static const danger = ThixPolicy.danger;

  static const gradientWhite = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Colors.white, whiteMuted],
  );
}

class UserProfilePage extends StatefulWidget {
  final String userId;
  const UserProfilePage({super.key, required this.userId});

  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  Map<String, dynamic>? _profile;
  Map<String, int> _stats = {'followers': 0, 'following': 0, 'posts': 0};
  
  bool _isFollowing = false;
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  
  List<MediaContent> _userPosts = [];
  final ScrollController _scrollController = ScrollController();
  static const int _limit = 15;

  @override
  void initState() {
    super.initState();
    _loadProfileData();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      _loadMorePosts();
    }
  }

  Future<void> _loadProfileData() async {
    try {
      final service = MediaService();
      
      final results = await Future.wait([
        service.fetchProfile(widget.userId),
        service.fetchUserStats(widget.userId),
        service.isFollowing(widget.userId),
        Supabase.instance.client
            .from('media_content')
            .select('*')
            .eq('user_id', widget.userId)
            .order('created_at', ascending: false)
            .limit(_limit)
      ]);

      if (mounted) {
        setState(() {
          _profile = results[0] as Map<String, dynamic>?;
          _stats = Map<String, int>.from(results[1] as Map);
          _isFollowing = results[2] as bool;
          
          final postsData = results[3] as List<dynamic>;
          _userPosts = postsData.map((e) => MediaContent.fromJson(e as Map<String, dynamic>)).toList();
          _hasMore = postsData.length == _limit;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Erreur chargement profil: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMorePosts() async {
    if (_loadingMore || !_hasMore || _userPosts.isEmpty) return;
    setState(() => _loadingMore = true);

    try {
      final lastPost = _userPosts.last;
      final postsData = await Supabase.instance.client
          .from('media_content')
          .select('*')
          .eq('user_id', widget.userId)
          .lt('created_at', lastPost.createdAt.toIso8601String())
          .order('created_at', ascending: false)
          .limit(_limit);

      final newPosts = (postsData as List).map((e) => MediaContent.fromJson(e as Map<String, dynamic>)).toList();

      if (mounted) {
        setState(() {
          _userPosts.addAll(newPosts);
          _hasMore = newPosts.length == _limit;
          _loadingMore = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _handleFollowToggle() async {
    HapticFeedback.mediumImpact();
    final wasFollowing = _isFollowing;
    setState(() {
      _isFollowing = !_isFollowing;
      _stats['followers'] = (_stats['followers'] ?? 0) + (_isFollowing ? 1 : -1);
    });

    try {
      await MediaService().toggleFollow(widget.userId);
    } catch (_) {
      if (mounted) {
        setState(() {
          _isFollowing = wasFollowing;
          _stats['followers'] = (_stats['followers'] ?? 0) + (_isFollowing ? 1 : -1);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erreur réseau. Impossible de modifier l\'abonnement.'), backgroundColor: _ProfileColors.danger),
        );
      }
    }
  }

  String _getDisplayName() {
    final uname = _profile?['username'] as String?;
    final fname = _profile?['full_name'] as String?;
    if (uname != null && uname.trim().isNotEmpty) return uname.trim();
    if (fname != null && fname.trim().isNotEmpty) return fname.trim();
    return 'Utilisateur';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: _ProfileColors.navyDeep, 
        body: Center(child: CircularProgressIndicator(color: Colors.white))
      );
    }

    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    final isMe = currentUserId == widget.userId;

    return Scaffold(
      backgroundColor: _ProfileColors.navyDeep,
      appBar: AppBar(
        backgroundColor: _ProfileColors.navyDeep,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          isMe ? 'Mon Profil' : _getDisplayName(),
          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800),
        ),
        centerTitle: true,
      ),
      body: CustomScrollView(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        slivers: [
          // ==========================================
          // EN-TÊTE DU PROFIL (Informations & Stats)
          // ==========================================
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
              child: Column(
                children: [
                  Row(
                    children: [
                      // Avatar
                      Container(
                        width: 86, height: 86,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white.withValues(alpha: 0.15), width: 2),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 15, offset: const Offset(0, 8)),
                          ],
                          image: _profile?['avatar_url'] != null && _profile!['avatar_url'].toString().isNotEmpty
                              ? DecorationImage(
                                  image: CachedNetworkImageProvider(_profile!['avatar_url']),
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        child: _profile?['avatar_url'] == null || _profile!['avatar_url'].toString().isEmpty
                            ? const Icon(Icons.person_rounded, size: 40, color: Colors.white54)
                            : null,
                      ),
                      
                      const SizedBox(width: 24),
                      
                      // Statistiques (Abonnements, Abonnés, Posts)
                      Expanded(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildTopStat('Publications', _stats['posts'] ?? 0),
                            Container(width: 1, height: 30, color: Colors.white.withValues(alpha: 0.1)),
                            _buildTopStat('Abonnés', _stats['followers'] ?? 0),
                            Container(width: 1, height: 30, color: Colors.white.withValues(alpha: 0.1)),
                            _buildTopStat('Suivis', _stats['following'] ?? 0),
                          ],
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Nom Complet et Bio
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _profile?['full_name'] ?? _getDisplayName(),
                          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: -0.3),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '@${_profile?['username'] ?? 'utilisateur'}',
                          style: const TextStyle(color: _ProfileColors.textMuted, fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                        // Si une bio existe dans la table profiles, on l'affiche ici. (Exemple générique pour l'instant)
                        if (_profile?['bio'] != null && _profile!['bio'].toString().trim().isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Text(
                            _profile!['bio'],
                            style: const TextStyle(color: Colors.white70, fontSize: 13.5, height: 1.4),
                          ),
                        ]
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Bouton d'Action Primaire (Suivre ou Modifier)
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton(
                      onPressed: isMe ? () { /* Naviguer vers l'édition du profil */ } : _handleFollowToggle,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isMe 
                            ? Colors.white.withValues(alpha: 0.1) 
                            : (_isFollowing ? Colors.white.withValues(alpha: 0.1) : Colors.white),
                        foregroundColor: isMe 
                            ? Colors.white 
                            : (_isFollowing ? Colors.white : _ProfileColors.navyDeep),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        side: isMe || _isFollowing 
                            ? BorderSide(color: Colors.white.withValues(alpha: 0.15)) 
                            : BorderSide.none,
                      ),
                      child: Text(
                        isMe ? 'Modifier le profil' : (_isFollowing ? 'Abonné' : 'Suivre'),
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // ==========================================
          // SÉPARATEUR & TITRE GRILLE
          // ==========================================
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.1), width: 1.5)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.only(bottom: 12, right: 16),
                    decoration: const BoxDecoration(
                      border: Border(bottom: BorderSide(color: Colors.white, width: 2.5)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.grid_view_rounded, color: Colors.white, size: 18),
                        SizedBox(width: 8),
                        Text('Publications', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          const SliverToBoxAdapter(child: SizedBox(height: 16)),

          // ==========================================
          // GRILLE DE VIDÉOS
          // ==========================================
          if (_userPosts.isEmpty)
            SliverToBoxAdapter(child: _buildEmptyState())
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3, 
                  crossAxisSpacing: 8, 
                  mainAxisSpacing: 8, 
                  childAspectRatio: 0.65,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    if (index == _userPosts.length) {
                      return const Center(child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2));
                    }
                    return _ProfileVideoCard(post: _userPosts[index]);
                  },
                  childCount: _userPosts.length + (_hasMore ? 1 : 0),
                ),
              ),
            ),
            
          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }

  Widget _buildTopStat(String label, int count) {
    String format(int num) {
      if (num >= 1000000) return '${(num / 1000000).toStringAsFixed(1)}M';
      if (num >= 1000) return '${(num / 1000).toStringAsFixed(1)}K';
      return num.toString();
    }

    return Column(
      children: [
        Text(
          format(count),
          style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(color: _ProfileColors.textMuted, fontSize: 11, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.only(top: 60),
      child: Center(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.05),
              ),
              child: const Icon(Icons.video_library_rounded, size: 48, color: Colors.white24),
            ),
            const SizedBox(height: 16),
            const Text(
              "Aucune publication",
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              "Ce créateur n'a pas encore\npartagé de vidéo.",
              style: TextStyle(color: _ProfileColors.textMuted, fontSize: 13, height: 1.4),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================================
// COMPOSANT : CARTE VIDÉO (Adaptée au mode Grille 3 colonnes)
// ==========================================================
class _ProfileVideoCard extends StatefulWidget {
  final MediaContent post;
  const _ProfileVideoCard({required this.post});

  @override
  State<_ProfileVideoCard> createState() => _ProfileVideoCardState();
}

class _ProfileVideoCardState extends State<_ProfileVideoCard> {
  int _views = 0;
  StreamSubscription? _statsSub;

  @override
  void initState() {
    super.initState();
    _views = widget.post.viewCount;
    _listenToStats();
  }

  void _listenToStats() {
    _statsSub = Stream.periodic(const Duration(seconds: 20)).asyncMap((_) async {
      final r = await Supabase.instance.client
          .from('media_stats')
          .select('view_count')
          .eq('media_id', widget.post.id)
          .maybeSingle();
      return r;
    }).listen((data) {
      if (data != null && mounted) {
        setState(() {
          _views = (data['view_count'] as num?)?.toInt() ?? _views;
        });
      }
    });
  }

  @override
  void dispose() {
    _statsSub?.cancel();
    super.dispose();
  }

  String _format(int num) {
    if (num >= 1000000) return '${(num / 1000000).toStringAsFixed(1)}M';
    if (num >= 1000) return '${(num / 1000).toStringAsFixed(1)}K';
    return num.toString();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // Idéalement, cela devrait ouvrir la vidéo dans un PageView de type Fil TikTok 
        // ou la page de détail TDIA. Pour l'instant, on garde votre navigation existante.
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => VideoPlayerPage(
              title: widget.post.title,
              videoUrl: widget.post.videoUrl,
            )
          )
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Couverture Image
            Container(
              color: _ProfileColors.cardLight,
              child: widget.post.coverUrl.trim().isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: widget.post.coverUrl,
                      fit: BoxFit.cover,
                      placeholder: (c, url) => const SizedBox(),
                      errorWidget: (c, e, s) => const Icon(Icons.play_circle_outline, color: Colors.white24),
                    )
                  : const Icon(Icons.play_circle_outline, color: Colors.white24),
            ),
            
            // Dégradé de lisibilité en bas
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.1),
                    Colors.black.withValues(alpha: 0.8),
                  ],
                  stops: const [0.5, 0.7, 1.0],
                ),
              ),
            ),
            
            // Verrouillage (Si Premium)
            if (widget.post.isPaid)
              Positioned(
                top: 6, right: 6,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                  child: const Icon(Icons.lock_rounded, size: 10, color: _ProfileColors.navyDeep),
                ),
              ),

            // Compteur de vues en bas à gauche
            Positioned(
              bottom: 6,
              left: 6,
              child: Row(
                children: [
                  const Icon(Icons.play_arrow_outlined, color: Colors.white, size: 16),
                  const SizedBox(width: 2),
                  Text(
                    _format(_views),
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
