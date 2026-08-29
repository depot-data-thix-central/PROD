import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:thix_id/models/media_content.dart';
import 'profile_video_card.dart';
import '../providers/user_profile_providers.dart';

/// Grille de vidéos avec pagination infinite scroll + debounce
class ProfileVideosGrid extends ConsumerStatefulWidget {
  final String userId;

  const ProfileVideosGrid({super.key, required this.userId});

  @override
  ConsumerState<ProfileVideosGrid> createState() => _ProfileVideosGridState();
}

class _ProfileVideosGridState extends ConsumerState<ProfileVideosGrid> {
  final ScrollController _scrollController = ScrollController();
  Timer? _scrollDebounce;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _scrollDebounce?.cancel();
    super.dispose();
  }

  /// ✅ Debounce 200ms pour éviter déclenchements multiples
  void _onScroll() {
    _scrollDebounce?.cancel();
    _scrollDebounce = Timer(const Duration(milliseconds: 200), () {
      if (!_scrollController.hasClients) return;
      final pos = _scrollController.position;
      if (pos.pixels >= pos.maxScrollExtent - 200) {
        ref.read(userPostsProvider(widget.userId).notifier).loadMore();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final postsAsync = ref.watch(userPostsProvider(widget.userId));

    return postsAsync.when(
      loading: () => SliverToBoxAdapter(
        child: _buildEmptyState(loading: true),
      ),
      error: (e, _) => SliverToBoxAdapter(
        child: _buildErrorState(e),
      ),
      data: (state) {
        if (state.posts.isEmpty) {
          return SliverToBoxAdapter(child: _buildEmptyState());
        }

        final itemCount = state.posts.length + (state.hasMore ? 1 : 0);

        return SliverPadding(
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
                if (index == state.posts.length) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    ),
                  );
                }
                return ProfileVideoCard(post: state.posts[index]);
              },
              childCount: itemCount,
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState({bool loading = false}) {
    return Padding(
      padding: const EdgeInsets.only(top: 60),
      child: Center(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.05),
              ),
              child: loading
                  ? const SizedBox(
                      width: 48,
                      height: 48,
                      child: CircularProgressIndicator(color: Colors.white54, strokeWidth: 2),
                    )
                  : const Icon(Icons.video_library_rounded, size: 48, color: Colors.white24),
            ),
            const SizedBox(height: 16),
            Text(
              loading ? 'Chargement...' : 'Aucune publication',
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            if (!loading) ...[
              const SizedBox(height: 8),
              const Text(
                "Ce créateur n'a pas encore\npartagé de vidéo.",
                style: TextStyle(color: Color(0xFFAEB9D4), fontSize: 13, height: 1.4),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(Object error) {
    return Padding(
      padding: const EdgeInsets.only(top: 60),
      child: Center(
        child: Column(
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 48),
            const SizedBox(height: 16),
            const Text(
              'Erreur de chargement',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                error.toString(),
                style: const TextStyle(color: Color(0xFFAEB9D4), fontSize: 12, height: 1.4),
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => ref.read(userPostsProvider(widget.userId).notifier).refresh(),
              child: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }
}
