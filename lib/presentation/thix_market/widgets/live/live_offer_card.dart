// lib/presentation/thix_market/widgets/live/live_offer_card.dart
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';

class LiveOfferCard extends StatelessWidget {
  final Map<String, dynamic> offer;
  final VoidCallback? onTap;
  final VoidCallback? onClaim;

  const LiveOfferCard({
    super.key,
    required this.offer,
    this.onTap,
    this.onClaim,
  });

  // Couleurs de l'application
  static const Color navy = Color(0xFF1B2A4A);
  static const Color gold = Color(0xFFC9962C);
  static const Color danger = Color(0xFFE53935);
  static const Color textMuted = Color(0xFF8A8FA3);
  static const Color bgApp = Color(0xFFF6F7FB);
  static const Color success = Color(0xFF4CAF50);

  @override
  Widget build(BuildContext context) {
    final timeLeft = offer['expires_at'] != null
        ? DateTime.parse(offer['expires_at']).difference(DateTime.now())
        : null;
    final isExpired = timeLeft != null && timeLeft.isNegative;

    // ✅ Devise dynamique
    final currency = offer['currency'] ?? 'CDF';
    final currencySymbol = currency == 'USD' ? '\$' : 'FC';

    // ✅ Image : image_url ou images[0]
    String imageUrl = offer['image_url'] ?? '';
    if (imageUrl.isEmpty) {
      final images = offer['images'] as List?;
      if (images != null && images.isNotEmpty) {
        imageUrl = images[0].toString();
      }
    }

    return GestureDetector(
      onTap: onTap,
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.grey[200]!),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: Stack(
                children: [
                  imageUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: imageUrl,
                          height: 140,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(
                            height: 140,
                            color: bgApp,
                            child: const Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                          errorWidget: (_, __, ___) => Container(
                            height: 140,
                            color: bgApp,
                            child: Icon(Icons.image, color: textMuted),
                          ),
                        )
                      : Container(
                          height: 140,
                          color: bgApp,
                          child: Icon(Icons.image, color: textMuted),
                        ),
                  if (offer['discount_percentage'] != null)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: danger,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '-${offer['discount_percentage'].toInt()}%',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  if (timeLeft != null && !isExpired)
                    Positioned(
                      bottom: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.timer, size: 12, color: Colors.white),
                            const SizedBox(width: 4),
                            Text(
                              _formatDuration(timeLeft),
                              style: const TextStyle(color: Colors.white, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Content
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    offer['title'] ?? 'Offre flash',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: navy,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        '${(offer['price'] as num).toInt()} $currencySymbol',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: gold,
                        ),
                      ),
                      if (offer['original_price'] != null)
                        Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: Text(
                            '${(offer['original_price'] as num).toInt()} $currencySymbol',
                            style: TextStyle(
                              decoration: TextDecoration.lineThrough,
                              fontSize: 12,
                              color: textMuted,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (offer['stock'] != null) ...[
                    LinearProgressIndicator(
                      value: ((offer['stock_initial'] - offer['stock']) / offer['stock_initial'])
                          .clamp(0.0, 1.0),
                      backgroundColor: Colors.grey[200],
                      valueColor: AlwaysStoppedAnimation<Color>(gold),
                      minHeight: 6,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Plus que ${offer['stock']} disponibles',
                        style: TextStyle(fontSize: 10, color: textMuted),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  if (onClaim != null)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: isExpired ? null : onClaim,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isExpired ? textMuted : gold,
                          foregroundColor: isExpired ? Colors.white : navy,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          elevation: 0,
                        ),
                        child: Text(
                          isExpired ? 'Expirée' : 'Profiter',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    if (duration.inSeconds <= 0) return '00:00';
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}
