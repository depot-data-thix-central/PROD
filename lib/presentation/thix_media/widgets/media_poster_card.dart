import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/models/media_content.dart';
import '../utils/media_constants.dart';

class MediaPosterCard extends StatelessWidget {
  final MediaContent item;
  final VoidCallback onTap;
  final bool compact;

  const MediaPosterCard({
    super.key,
    required this.item,
    required this.onTap,
    this.compact = false,
  });

  bool get _isSeries => item.episodesUrls.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _buildCover(),
                  _buildGradient(),
                  if (item.isPaid) _buildPaidBadge(),
                  if (_isSeries) _buildSeriesBadge(),
                  _buildViewsOverlay(),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            item.title,
            maxLines: compact ? 1 : 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w800,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCover() {
    if (item.coverUrl.trim().isEmpty) {
      return Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [MediaColors.cardLight, MediaColors.card],
          ),
        ),
        child: const Center(
          child: Icon(Icons.play_circle_outline_rounded, color: Colors.white24, size: 40),
        ),
      );
    }
    return CachedNetworkImage(
      imageUrl: item.coverUrl,
      fit: BoxFit.cover,
      memCacheWidth: 400,
      memCacheHeight: 600,
      placeholder: (_, __) => Container(color: MediaColors.card),
      errorWidget: (_, __, ___) => Container(
        color: MediaColors.card,
        child: const Icon(Icons.broken_image_rounded, color: Colors.white24, size: 30),
      ),
    );
  }

  Widget _buildGradient() {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black87],
          stops: [0.4, 1],
        ),
      ),
    );
  }

  Widget _buildPaidBadge() {
    return Positioned(
      top: 8,
      right: 8,
      child: Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.6),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.lock_rounded, size: 12, color: ThixPolicy.gold),
      ),
    );
  }

  Widget _buildSeriesBadge() {
    return Positioned(
      top: 8,
      left: 8,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: MediaColors.primary.withOpacity(0.85),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          '${item.episodesUrls.length + 1} parties',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 9,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  Widget _buildViewsOverlay() {
    return Positioned(
      left: 8,
      right: 8,
      bottom: 8,
      child: Row(
        children: [
          const Icon(Icons.play_circle_fill_rounded, color: Colors.white70, size: 14),
          const SizedBox(width: 4),
          Text(
            formatMediaNumber(item.viewCount),
            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
