import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/media_service.dart';
import '../../models/media_content.dart';
import 'video_player_page.dart';

// --- PALETTE DE COULEURS THIX CENTRAL ---
const Color kBg = Color(0xFF050507);
const Color kSurface = Color(0xFF121214);
const Color kSurfaceLight = Color(0xFF1E1E28);
const Color kRed = Color(0xFFFF1A1A);
const Color kTextWhite = Color(0xFFFFFFFF);
const Color kTextGrey = Color(0xFF9CA3AF);
const Color kBorderLight = Color(0x14FFFFFF);
const Color kTdiaBlue = Color(0xFF2D6CDF); // AJOUT DE LA COULEUR MANQUANTE ICI

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
      
      // Chargement en parallèle pour la performance
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
    // UI Optimiste
    final wasFollowing = _isFollowing;
    setState(() {
      _isFollowing = !_isFollowing;
      _stats['followers'] = (_stats['followers'] ?? 0) + (_isFollowing ? 1 : -1);
    });

    try {
      await MediaService().toggleFollow(widget.userId);
    } catch (_) {
      // Revert en cas d'erreur réseau
      if (mounted) {
        setState(() {
          _isFollowing = wasFollowing;
          _stats['followers'] = (_stats['followers'] ?? 0) + (_isFollowing ? 1 : -1);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erreur réseau'), backgroundColor: kSurface),
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
        backgroundColor: kBg, 
        body: Center(child: CircularProgressIndicator(color: kRed))
      );
    }

    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    final isMe = currentUserId == widget.userId;

    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ==========================================
            // COLONNE GAUCHE : INFOS & ACTIONS (35%)
            // ==========================================
            Container(
              width: MediaQuery.of(context).size.width * 0.35,
              decoration: const BoxDecoration(
                color: kSurface,
                border: Border(right: BorderSide(color: kBorderLight)),
              ),
              child: Column(
                children: [
                  // Header avec bouton retour
                  Align(
                    alignment: Alignment.topLeft,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const SizedBox(height: 10),
                          
                          // Avatar avec effet Glowing
                          Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [kRed.withOpacity(0.8), kTdiaBlue.withOpacity(0.8)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                            child: CircleAvatar(
                              radius: 40,
                              backgroundColor: kBg,
                              backgroundImage: _profile?['avatar_url'] != null && _profile!['avatar_url'].toString().isNotEmpty
                                  ? NetworkImage(_profile!['avatar_url'])
                                  : null,
                              child: _profile?['avatar_url'] == null || _profile!['avatar_url'].toString().isEmpty
                                  ? const Icon(Icons.person, size: 40, color: kTextGrey)
                                  : null,
                            ),
                          ),
                          
                          const SizedBox(height: 16),
                          
                          // Noms
                          Text(
                            _getDisplayName(),
                            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          
                          if (_profile?['full_name'] != null && _profile!['full_name'].toString().trim().isNotEmpty && _profile?['username'] != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                '@${_profile!['username']}',
                                style: const TextStyle(color: kTextGrey, fontSize: 12),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),

                          const SizedBox(height: 24),

                          // Bouton d'Abonnement (Si ce n'est pas moi)
                          if (!isMe)
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _handleFollowToggle,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _isFollowing ? Colors.transparent : kRed,
                                  elevation: 0,
                                  side: BorderSide(color: _isFollowing ? kBorderLight : kRed),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                                child: Text(
                                  _isFollowing ? 'Abonné' : 'Suivre',
                                  style: TextStyle(
                                    color: _isFollowing ? Colors.white : Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13
                                  ),
                                ),
                              ),
                            ),
                          
                          const SizedBox(height: 30),

                          // Statistiques verticales
                          _buildVerticalStat('Publications', _stats['posts'] ?? 0),
                          const Divider(color: kBorderLight, height: 30),
                          _buildVerticalStat('Abonnés', _stats['followers'] ?? 0),
                          const Divider(color: kBorderLight, height: 30),
                          _buildVerticalStat('Abonnements', _stats['following'] ?? 0),
                          
                          const SizedBox(height: 30),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ==========================================
            // COLONNE DROITE : LE FLUX VIDÉO (65%)
            // ==========================================
            Expanded(
              child: _userPosts.isEmpty
                  ? _buildEmptyState()
                  : RefreshIndicator(
                      color: kRed,
                      backgroundColor: kSurface,
                      onRefresh: _loadProfileData,
                      child: ListView.separated(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        physics: const AlwaysScrollableScrollPhysics(),
                        itemCount: _userPosts.length + (_hasMore ? 1 : 0),
                        separatorBuilder: (_, __) => const SizedBox(height: 16),
                        itemBuilder: (context, index) {
                          if (index == _userPosts.length) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 20),
                              child: Center(child: CircularProgressIndicator(color: kRed)),
                            );
                          }
                          return _ProfileVideoCard(post: _userPosts[index]);
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVerticalStat(String label, int count) {
    String format(int num) {
      if (num >= 1000000) return '${(num / 1000000).toStringAsFixed(1)}M';
      if (num >= 1000) return '${(num / 1000).toStringAsFixed(1)}K';
      return num.toString();
    }

    return Column(
      children: [
        Text(
          format(count),
          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(color: kTextGrey, fontSize: 11, fontWeight: FontWeight.w500),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.video_library_rounded, size: 64, color: kBorderLight),
          SizedBox(height: 16),
          Text(
            "Aucune publication",
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text(
            "Cet utilisateur n'a pas encore\nposté de vidéo.",
            style: TextStyle(color: kTextGrey, fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ==========================================================
// COMPOSANT : CARTE VIDÉO AUTONOME (Avec Stats Temps Réel)
// ==========================================================
class _ProfileVideoCard extends StatefulWidget {
  final MediaContent post;
  const _ProfileVideoCard({required this.post});

  @override
  State<_ProfileVideoCard> createState() => _ProfileVideoCardState();
}

class _ProfileVideoCardState extends State<_ProfileVideoCard> {
  int _likes = 0;
  int _views = 0;
  int _comments = 0;
  StreamSubscription? _statsSub;

  @override
  void initState() {
    super.initState();
    _likes = widget.post.likeCount;
    _views = widget.post.viewCount;
    _comments = widget.post.commentCount;
    _listenToStats();
  }

  void _listenToStats() {
    _statsSub = Stream.periodic(const Duration(seconds: 15)).asyncMap((_) async {
      final r = await Supabase.instance.client
          .from('media_stats')
          .select('like_count, view_count, comment_count')
          .eq('media_id', widget.post.id)
          .maybeSingle();
      return r;
    }).listen((data) {
      if (data != null && mounted) {
        setState(() {
          _likes = (data['like_count'] as num?)?.toInt() ?? _likes;
          _views = (data['view_count'] as num?)?.toInt() ?? _views;
          _comments = (data['comment_count'] as num?)?.toInt() ?? _comments;
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
      child: Container(
        height: 200,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: kSurface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ]
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 1. Couverture Image
              Image.network(
                widget.post.coverUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image, color: kTextGrey)),
              ),
              
              // 2. Dégradé de lisibilité
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.4),
                      Colors.black.withOpacity(0.9),
                    ],
                    stops: const [0.0, 0.5, 1.0],
                  ),
                ),
              ),

              // 3. Bouton Play Central
              Center(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.4),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white24)
                  ),
                  child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 32),
                ),
              ),

              // 4. Infos & Statistiques en bas
              Positioned(
                bottom: 12,
                left: 12,
                right: 12,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Titre
                    Text(
                      widget.post.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        shadows: [Shadow(color: Colors.black, blurRadius: 4)]
                      ),
                    ),
                    const SizedBox(height: 10),
                    
                    // Ligne de statistiques
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildStatIcon(Icons.remove_red_eye_rounded, _format(_views)),
                        _buildStatIcon(Icons.favorite_rounded, _format(_likes), color: kRed),
                        _buildStatIcon(Icons.chat_bubble_rounded, _format(_comments)),
                        
                        // Badge de la catégorie
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: kTdiaBlue.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: kTdiaBlue.withOpacity(0.5))
                          ),
                          child: Text(
                            widget.post.type,
                            style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                          ),
                        )
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatIcon(IconData icon, String value, {Color? color}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color ?? Colors.white70, size: 14),
        const SizedBox(width: 4),
        Text(
          value,
          style: TextStyle(color: color ?? Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
