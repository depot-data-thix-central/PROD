// lib/presentation/thix_weeding/pages/provider_portal/provider_cover.dart
// ============================================================================
// Visuel d'un prestataire : vraies photos si elles existent,
// sinon un visuel de sa catégorie (plus de fausse photo de salle).
// ============================================================================
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/provider_models.dart';

IconData providerCategoryIcon(ProviderCategory c) => switch (c) {
      ProviderCategory.salle => Icons.meeting_room_rounded,
      ProviderCategory.traiteur => Icons.restaurant_rounded,
      ProviderCategory.photographe => Icons.camera_alt_rounded,
      ProviderCategory.videaste => Icons.videocam_rounded,
      ProviderCategory.decorateur => Icons.palette_rounded,
      ProviderCategory.dj => Icons.music_note_rounded,
      ProviderCategory.mc => Icons.mic_rounded,
      ProviderCategory.maquilleur => Icons.face_rounded,
      ProviderCategory.patissier => Icons.cake_rounded,
      ProviderCategory.fleuriste => Icons.local_florist_rounded,
    };

List<String> providerRealPhotos(ThixProviderModel p) =>
    p.galleryUrls.map((u) => u.trim()).where((u) => u.isNotEmpty).toList();

class ProviderCoverPlaceholder extends StatelessWidget {
  final ThixProviderModel provider;
  const ProviderCoverPlaceholder({super.key, required this.provider});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFFF4D6D), Color(0xFFFF85A1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(providerCategoryIcon(provider.category), size: 38, color: Colors.white.withOpacity(0.9)),
            const SizedBox(height: 6),
            Text(
              provider.category.displayName,
              style: GoogleFonts.inter(
                  fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white.withOpacity(0.9)),
            ),
          ],
        ),
      ),
    );
  }
}

class ProviderPhotos extends StatelessWidget {
  final ThixProviderModel provider;
  const ProviderPhotos({super.key, required this.provider});

  @override
  Widget build(BuildContext context) {
    final photos = providerRealPhotos(provider);
    if (photos.isEmpty) return ProviderCoverPlaceholder(provider: provider);
    Widget img(String u) => Image.network(
          u,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => ProviderCoverPlaceholder(provider: provider),
        );
    if (photos.length == 1) return img(photos.first);
    return PageView.builder(itemCount: photos.length, itemBuilder: (_, i) => img(photos[i]));
  }
}
