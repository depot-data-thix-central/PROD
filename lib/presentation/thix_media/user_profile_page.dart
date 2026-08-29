import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'widgets/profile_header_widget.dart';
import 'widgets/profile_videos_grid.dart';
import 'providers/user_profile_providers.dart';

class UserProfilePage extends ConsumerStatefulWidget {
  final String userId;
  const UserProfilePage({super.key, required this.userId});

  @override
  ConsumerState<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends ConsumerState<UserProfilePage> {
  Future<void> _refresh() async {
    final profileAsync = ref.read(userProfileDataProvider(widget.userId));
    if (profileAsync is AsyncData) {
      // Invalider le cache pour forcer un rechargement
      ref.invalidate(userProfileDataProvider(widget.userId));
    }
    await ref.read(userPostsProvider(widget.userId).notifier).refresh();
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(userProfileDataProvider(widget.userId));

    return Scaffold(
      backgroundColor: const Color(0xFF0A1F44),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A1F44),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: profileAsync.whenOrNull(
          data: (bundle) => Text(
            _getTitle(bundle),
            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800),
          ),
        ) ?? const Text('Profil', style: TextStyle(color: Colors.white)),
        centerTitle: true,
      ),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: Colors.white)),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 64),
                const SizedBox(height: 16),
                Text(
                  e.toString(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => ref.invalidate(userProfileDataProvider(widget.userId)),
                  child: const Text('Réessayer'),
                ),
              ],
            ),
          ),
        ),
        data: (bundle) {
          if (bundle.hasError || bundle.profile == null) {
            return _buildNotFoundState(bundle.error ?? 'Profil introuvable');
          }
          return _buildProfileContent(bundle);
        },
      ),
    );
  }

  String _getTitle(UserProfileBundle bundle) {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    if (currentUserId == widget.userId) return 'Mon Profil';
    
    final fname = bundle.profile?['full_name'] as String?;
    final uname = bundle.profile?['username'] as String?;
    if (fname != null && fname.trim().isNotEmpty) return fname.trim();
    if (uname != null && uname.trim().isNotEmpty) return uname.trim();
    return 'Profil';
  }

  Widget _buildNotFoundState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.person_off_rounded, color: Colors.white54, size: 64),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Retour'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileContent(UserProfileBundle bundle) {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    final isMe = currentUserId == widget.userId;

    return RefreshIndicator(
      onRefresh: _refresh,
      color: Colors.white,
      backgroundColor: const Color(0xFF0A1F44),
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        slivers: [
          SliverToBoxAdapter(
            child: ProfileHeaderWidget(
              profile: bundle.profile!,
              stats: bundle.stats,
              isFollowing: bundle.isFollowing,
              isMe: isMe,
              onEditProfile: () {
                // TODO: Naviguer vers la page d'édition du profil
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Édition du profil bientôt disponible')),
                );
              },
            ),
          ),

          // Séparateur + titre
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.1), width: 1.5)),
              ),
              child: const Row(
                children: [
                  Padding(
                    padding: EdgeInsets.only(bottom: 12, right: 16),
                    child: Row(
                      children: [
                        Icon(Icons.grid_view_rounded, color: Colors.white, size: 18),
                        SizedBox(width: 8),
                        Text(
                          'Publications',
                          style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 16)),

          ProfileVideosGrid(userId: widget.userId),

          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }
}
