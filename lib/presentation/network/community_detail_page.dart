// lib/presentation/network/community_detail_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'package:thix_id/core/theme/thix_design_policy.dart'; // ✅ Import de la charte graphique
import 'package:thix_id/models/network_community.dart';
import 'package:thix_id/models/network_post.dart';
import 'package:thix_id/features/auth/presentation/providers/auth_controller.dart';
import 'package:thix_id/presentation/network/widgets/post_card.dart';
import 'package:thix_id/features/network/presentation/providers/community_detail_provider.dart'; 

class CommunityDetailPage extends ConsumerStatefulWidget {
  final String communityId;
  const CommunityDetailPage({super.key, required this.communityId});

  @override
  ConsumerState<CommunityDetailPage> createState() => _CommunityDetailPageState();
}

class _CommunityDetailPageState extends ConsumerState<CommunityDetailPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ScrollController _postsScroll = ScrollController();
  
  bool _isJoiningProcess = false;
  String _memberSearchQuery = ''; // Pour la nouvelle fonctionnalité de recherche

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _postsScroll.addListener(() {
      if (_postsScroll.position.pixels >= _postsScroll.position.maxScrollExtent - 400) {
        ref.read(communityDetailProvider(widget.communityId).notifier).loadMorePosts();
      }
    });
  }

  @override
  void dispose() { 
    _tabController.dispose(); 
    _postsScroll.dispose(); 
    super.dispose(); 
  }

  Future<void> _handleToggleJoin(bool currentlyMember) async {
    if (_isJoiningProcess) return;
    setState(() => _isJoiningProcess = true);
    
    try {
      await ref.read(communityDetailProvider(widget.communityId).notifier).toggleJoin();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(currentlyMember ? 'Vous avez quitté la communauté' : 'Bienvenue dans la communauté !'), 
          backgroundColor: currentlyMember ? ThixPolicy.textSecondary : ThixPolicy.primary
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Erreur réseau'), backgroundColor: ThixPolicy.danger));
      }
    } finally {
      if (mounted) setState(() => _isJoiningProcess = false);
    }
  }

  void _shareCommunity(NetworkCommunity? community) {
    if (community != null) {
      Share.share('Rejoins "${community.name}" sur THIX PRO! https://thix.app/community/${community.id}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncState = ref.watch(communityDetailProvider(widget.communityId));
    final currentUserId = ref.watch(authControllerProvider).value?.id ?? '';

    return Scaffold(
      backgroundColor: ThixPolicy.surface, // ✅ Utilisation de ThixPolicy
      appBar: AppBar(
        backgroundColor: ThixPolicy.card, 
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          asyncState.valueOrNull?.community.name ?? 'Communauté', 
          style: const TextStyle(color: ThixPolicy.inkDeep, fontWeight: FontWeight.w800, fontSize: 18)
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: ThixPolicy.inkDeep, size: 22), 
          onPressed: () => Navigator.pop(context)
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined, color: ThixPolicy.inkDeep, size: 22), 
            onPressed: () => _shareCommunity(asyncState.valueOrNull?.community)
          ),
          if (asyncState.valueOrNull != null) 
            Padding(
              padding: const EdgeInsets.only(right: 12, top: 10, bottom: 10), 
              child: ElevatedButton(
                onPressed: _isJoiningProcess ? null : () => _handleToggleJoin(asyncState.valueOrNull!.isMember), 
                style: ElevatedButton.styleFrom(
                  backgroundColor: asyncState.valueOrNull!.isMember ? ThixPolicy.surface : ThixPolicy.primary, 
                  foregroundColor: asyncState.valueOrNull!.isMember ? ThixPolicy.textMain : Colors.white, 
                  elevation: 0,
                  side: asyncState.valueOrNull!.isMember ? BorderSide(color: ThixPolicy.borderStrong) : null, 
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rFull)), 
                  padding: const EdgeInsets.symmetric(horizontal: 16)
                ), 
                child: _isJoiningProcess 
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: ThixPolicy.textSecondary)) 
                  : Text(
                      asyncState.valueOrNull!.isMember ? 'Quitter' : 'Rejoindre',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                    )
              )
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: ThixPolicy.border, width: 1))
            ),
            child: TabBar(
              controller: _tabController, 
              labelColor: ThixPolicy.primary, 
              unselectedLabelColor: ThixPolicy.textSecondary, 
              indicatorColor: ThixPolicy.primary, 
              indicatorWeight: 3,
              labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5), 
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
              tabs: const [
                Tab(text: 'À propos'), 
                Tab(text: 'Membres'),
                Tab(text: 'Discussion'),
              ]
            ),
          ),
        ),
      ),
      body: asyncState.when(
        loading: () => const Center(child: CircularProgressIndicator(color: ThixPolicy.primary)),
        error: (e, _) => _buildErrorState(e.toString()),
        data: (state) => TabBarView(
          controller: _tabController, 
          children: [
            _buildAboutTab(state, currentUserId), 
            _buildMembersTab(state.members),
            _buildDiscussionTab(state, currentUserId),
          ]
        ),
      ),
    );
  }

  Widget _buildErrorState(String error) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32), 
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center, 
        children: [
          Icon(Icons.error_outline_rounded, size: 56, color: ThixPolicy.danger), 
          const SizedBox(height: 16), 
          const Text('Erreur de chargement', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: ThixPolicy.textMain)), 
          const SizedBox(height: 8), 
          Text(error, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, color: ThixPolicy.textSecondary)), 
          const SizedBox(height: 24), 
          ElevatedButton.icon(
            onPressed: () => ref.invalidate(communityDetailProvider(widget.communityId)), 
            icon: const Icon(Icons.refresh_rounded, color: Colors.white), 
            label: const Text('Réessayer', style: TextStyle(color: Colors.white)), 
            style: ElevatedButton.styleFrom(
              backgroundColor: ThixPolicy.primary, 
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rFull))
            )
          )
        ]
      )
    )
  );

  Widget _buildAboutTab(CommunityDetailState state, String currentUserId) {
    final community = state.community;
    final posts = state.posts;

    return RefreshIndicator(
      color: ThixPolicy.primary,
      backgroundColor: ThixPolicy.card,
      onRefresh: () async => ref.invalidate(communityDetailProvider(widget.communityId)), 
      child: SingleChildScrollView(
        controller: _postsScroll, 
        physics: const AlwaysScrollableScrollPhysics(), 
        padding: const EdgeInsets.all(16), 
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, 
          children: [
            Container(
              height: 180, 
              width: double.infinity, 
              decoration: BoxDecoration(
                color: ThixPolicy.inkDeep, 
                borderRadius: BorderRadius.circular(ThixPolicy.rMd), 
                image: community.bannerUrl != null && community.bannerUrl!.isNotEmpty 
                  ? DecorationImage(image: CachedNetworkImageProvider(community.bannerUrl!), fit: BoxFit.cover) 
                  : null
              ), 
              child: community.bannerUrl == null || community.bannerUrl!.isEmpty 
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center, 
                      children: [
                        Icon(Icons.groups_rounded, size: 56, color: Colors.white.withOpacity(0.3)), 
                        const SizedBox(height: 8), 
                        Text(community.name, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold))
                      ]
                    )
                  ) 
                : null
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(
                    community.name, 
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: ThixPolicy.inkDeep)
                  )
                ), 
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), 
                  decoration: BoxDecoration(color: ThixPolicy.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(ThixPolicy.rFull)), 
                  child: Text(
                    community.privacy ?? 'Public', 
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: ThixPolicy.primary)
                  )
                )
              ]
            ),
            if (community.description != null && community.description!.isNotEmpty) ...[
              const SizedBox(height: 12), 
              Text(community.description!, style: const TextStyle(fontSize: 14.5, color: ThixPolicy.textSecondary, height: 1.5))
            ],
            const SizedBox(height: 20), 
            Row(
              children: [
                _buildStatItem('${community.membersCount}', 'Membres', Icons.people_alt_rounded), 
                Container(width: 1, height: 30, color: ThixPolicy.border, margin: const EdgeInsets.symmetric(horizontal: 24)), 
                _buildStatItem('${posts.length}', 'Publications', Icons.article_rounded)
              ]
            ),
            const SizedBox(height: 32), 
            const Text('Dernières publications', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: ThixPolicy.textMain)), 
            const SizedBox(height: 12),
            
            if (posts.isEmpty) 
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40), 
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: ThixPolicy.border)),
                        child: const Icon(Icons.feed_outlined, size: 32, color: ThixPolicy.textMuted)
                      ), 
                      const SizedBox(height: 12), 
                      const Text('Aucune publication pour le moment', style: TextStyle(color: ThixPolicy.textSecondary, fontWeight: FontWeight.w500))
                    ]
                  )
                )
              )
            else 
              Column(
                children: posts.map((post) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: PostCard(
                    post: post, 
                    currentProfileId: currentUserId, 
                    onLike: () => ref.read(communityDetailProvider(widget.communityId).notifier).toggleLike(post.id), 
                    onComment: () => context.push('/network/comments/${post.id}'), 
                    onTap: () => context.push('/network/post/${post.id}'), 
                    onShare: () => Share.share('Découvrez cette publication sur THIX PRO'), 
                    onRefresh: () => ref.invalidate(communityDetailProvider(widget.communityId))
                  ),
                )).toList()
              ),
            
            if (state.hasMorePosts && posts.isNotEmpty)
              const Padding(padding: EdgeInsets.symmetric(vertical: 24), child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: ThixPolicy.primary))),
              
            const SizedBox(height: 80),
          ]
        )
      )
    );
  }

  Widget _buildStatItem(String value, String label, IconData icon) => Row(
    children: [
      Icon(icon, size: 20, color: ThixPolicy.textSecondary), 
      const SizedBox(width: 10), 
      Column(
        crossAxisAlignment: CrossAxisAlignment.start, 
        children: [
          Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: ThixPolicy.inkDeep)), 
          Text(label, style: const TextStyle(fontSize: 11.5, color: ThixPolicy.textSecondary, fontWeight: FontWeight.w500))
        ]
      )
    ]
  );
  
  Widget _buildMembersTab(List<Map<String, dynamic>> members) {
    // Filtrage local pour la barre de recherche
    final filteredMembers = members.where((m) {
      final name = (m['display_name'] ?? '').toString().toLowerCase();
      return name.contains(_memberSearchQuery.toLowerCase());
    }).toList();

    return Column(
      children: [
        // 🆕 Fonctionnalité : Barre de recherche
        Container(
          color: ThixPolicy.card,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: TextField(
            onChanged: (val) => setState(() => _memberSearchQuery = val),
            decoration: InputDecoration(
              hintText: 'Rechercher un membre...',
              hintStyle: const TextStyle(color: ThixPolicy.textMuted, fontSize: 14),
              prefixIcon: const Icon(Icons.search_rounded, color: ThixPolicy.textSecondary, size: 20),
              filled: true,
              fillColor: ThixPolicy.surface,
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(ThixPolicy.rFull), borderSide: BorderSide.none),
            ),
          ),
        ),
        Expanded(
          child: members.isEmpty 
            ? const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.people_outline, size: 48, color: ThixPolicy.textMuted), SizedBox(height: 12), Text('Aucun membre pour le moment', style: TextStyle(color: ThixPolicy.textSecondary, fontWeight: FontWeight.w500))])) 
            : RefreshIndicator(
                color: ThixPolicy.primary, 
                backgroundColor: ThixPolicy.card,
                onRefresh: () async => ref.invalidate(communityDetailProvider(widget.communityId)), 
                child: ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(), 
                  padding: const EdgeInsets.all(16), 
                  itemCount: filteredMembers.length, 
                  itemBuilder: (context, i) => _buildMemberTile(filteredMembers[i])
                )
              ),
        ),
      ],
    );
  }
  
  Widget _buildMemberTile(Map<String, dynamic> member) => Container(
    margin: const EdgeInsets.only(bottom: 12), 
    decoration: BoxDecoration(
      color: ThixPolicy.card, 
      borderRadius: BorderRadius.circular(ThixPolicy.rMd), 
      border: Border.all(color: ThixPolicy.border)
    ), 
    child: ListTile(
      leading: CircleAvatar(
        radius: 22, 
        backgroundColor: ThixPolicy.surface,
        backgroundImage: member['photo_url'] != null && member['photo_url'].isNotEmpty ? CachedNetworkImageProvider(member['photo_url']) : null, 
        child: member['photo_url'] == null || member['photo_url'].isEmpty 
          ? Text((member['display_name'] ?? 'U')[0].toUpperCase(), style: const TextStyle(color: ThixPolicy.textSecondary, fontWeight: FontWeight.bold)) 
          : null
      ), 
      title: Text(member['display_name'] ?? 'Utilisateur', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: ThixPolicy.textMain)), 
      subtitle: member['profession'] != null 
        ? Text(member['profession'], maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, color: ThixPolicy.textSecondary)) 
        : null, 
      trailing: OutlinedButton(
        onPressed: () => context.push('/network/profile/${member['id']}'),
        style: OutlinedButton.styleFrom(
          foregroundColor: ThixPolicy.inkDeep,
          side: BorderSide(color: ThixPolicy.border),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
          minimumSize: const Size(60, 30),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rMd))
        ),
        child: const Text('Profil', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
      ),
      onTap: () => context.push('/network/profile/${member['id']}')
    )
  );

  Widget _buildDiscussionTab(CommunityDetailState state, String currentUserId) {
    if (!state.isMember) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(shape: BoxShape.circle, color: ThixPolicy.card, border: Border.all(color: ThixPolicy.border)),
                child: const Icon(Icons.lock_outline_rounded, size: 48, color: ThixPolicy.textMuted),
              ),
              const SizedBox(height: 20),
              const Text('Espace privé', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: ThixPolicy.inkDeep)),
              const SizedBox(height: 8),
              const Text('Rejoignez la communauté pour accéder à l\'espace de discussion en temps réel.', textAlign: TextAlign.center, style: TextStyle(fontSize: 13.5, color: ThixPolicy.textSecondary, height: 1.4)),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => _handleToggleJoin(false),
                style: ElevatedButton.styleFrom(
                  backgroundColor: ThixPolicy.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rFull)),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)
                ),
                child: const Text('Rejoindre le groupe', style: TextStyle(fontWeight: FontWeight.w700)),
              )
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: ThixPolicy.card, shape: BoxShape.circle, border: Border.all(color: ThixPolicy.border)),
                  child: const Icon(Icons.forum_outlined, size: 36, color: ThixPolicy.textMuted),
                ),
                const SizedBox(height: 16),
                const Text('Aucun message', style: TextStyle(fontWeight: FontWeight.w700, color: ThixPolicy.textMain)),
                const SizedBox(height: 4),
                const Text('Soyez le premier à écrire !', style: TextStyle(fontSize: 13, color: ThixPolicy.textSecondary)),
              ],
            ),
          ),
        ),
        
        // 🆕 Fonctionnalité : Input Chat enrichi
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: ThixPolicy.card,
            border: Border(top: BorderSide(color: ThixPolicy.border)),
          ),
          child: SafeArea(
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.add_circle_outline_rounded, color: ThixPolicy.textSecondary, size: 24),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Joindre un fichier : Fonctionnalité à venir')));
                  },
                ),
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Écrire un message...',
                      hintStyle: const TextStyle(color: ThixPolicy.textMuted, fontSize: 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(ThixPolicy.rFull),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: ThixPolicy.surface,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: ThixPolicy.primary,
                  radius: 20,
                  child: IconButton(
                    icon: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Le chat est en cours de configuration !'))
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
