import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:thix_id/models/media_content.dart';
import 'package:thix_id/presentation/thix_media/media_routes.dart';
import 'package:thix_id/presentation/thix_media/providers/thix_media_providers.dart';

/// Carte vidéo individuelle pour la grille de profil.
/// 
/// ✅ SANS Stream.periodic (utilise le provider existant)
/// ✅ Navigation type-safe via MediaRoutes
class ProfileVideoCard extends ConsumerWidget {
  final MediaContent post;

  const ProfileVideoCard({super.key, required this.post});

  String _format(int num) {
    if (num >= 1000000) return '${(num / 1000000).toStringAsFixed(1)}M';
    if (num >= 1000) return '${(num / 1000).toStringAsFixed(1)}K';
    return num.toString();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ✅ Utilise le stream provider partagé (auto-dispose + cleanup automatique)
    final liveStats = ref.watch(mediaCountsStreamProvider(post.id));
    final views = liveStats.valueOrNull?.viewCount ?? post.viewCount;

    return GestureDetector(
      onTap: () {
        // ✅ Navigation type-safe (remplace Navigator.push)
        MediaRoutes.goToVideoPlayer(
          context,
          videoUrl: post.videoUrl,
          title: post.title,
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Stack(
          fit: StackFit.expand,
          children: [
            _buildCover(),
            _buildGradient(),
            if (post.isPaid) _buildPaidBadge(),
            _buildViewsOverlay(views),
          ],
        ),
      ),
    );
  }

  Widget _buildCover() {
    if (post.coverUrl.trim().isEmpty) {
      return Container(
        color: const Color(0xFF16294D),
        child: const Icon(Icons.play_circle_outline, color: Colors.white24),
      );
    }
    return CachedNetworkImage(
      imageUrl: post.coverUrl,
      fit: BoxFit.cover,
      memCacheWidth: 200, // ✅ Limite mémoire
      memCacheHeight: 300,
      placeholder: (_, __) => Container(color: const Color(0xFF16294D)),
      errorWidget: (_, __, ___) => Container(
        color: const Color(0xFF16294D),
        child: const Icon(Icons.play_circle_outline, color: Colors.white24),
      ),
    );
  }

  Widget _buildGradient() {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Colors.black.withOpacity(0.1),
            Colors.black.withOpacity(0.8),
          ],
          stops: const [0.5, 0.7, 1.0],
        ),
      ),
    );
  }

  Widget _buildPaidBadge() {
    return Positioned(
      top: 6,
      right: 6,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
        child: const Icon(Icons.lock_rounded, size: 10, color: Color(0xFF0A1F44)),
      ),
    );
  }

  Widget _buildViewsOverlay(int views) {
    return Positioned(
      bottom: 6,
      left: 6,
      child: Row(
        children: [
          const Icon(Icons.play_arrow_outlined, color: Colors.white, size: 16),
          const SizedBox(width: 2),
          Text(
            _format(views),
            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
