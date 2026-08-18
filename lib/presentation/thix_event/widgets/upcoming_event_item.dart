// lib/presentation/thix_event/widgets/upcoming_event_item.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../models/event_model.dart';

class _ThixColors {
  static const Color primary = Color(0xFF6B3CE2);
  static const Color darkText = Color(0xFF1E1B4B);
  static const Color mutedText = Color(0xFF8B8BA7);
  static const Color cardBorder = Color(0xFFEEE9FF);
}

class UpcomingEventItem extends StatelessWidget {
  final Event event;
  final VoidCallback onTap;

  const UpcomingEventItem({
    super.key,
    required this.event,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _ThixColors.cardBorder, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: _ThixColors.primary.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // 🟢 Bloc de la Date (Violet THIX au lieu du jaune)
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: _ThixColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    DateFormat('dd').format(event.startDate),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: _ThixColors.primary),
                  ),
                  Text(
                    DateFormat('MMM').format(event.startDate).toUpperCase(),
                    style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: _ThixColors.primary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            
            // 🟢 Infos de l'événement (Titre, Catégorie, Heure, Lieu)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _ThixColors.primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _getCategoryLabel(event.category),
                      style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: _ThixColors.primary),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    event.title,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _ThixColors.darkText),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.access_time_rounded, size: 12, color: _ThixColors.mutedText),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '${DateFormat('HH:mm').format(event.startDate)} • ${event.location}',
                          style: const TextStyle(fontSize: 11, color: _ThixColors.mutedText, fontWeight: FontWeight.w500),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),

            // 🟢 Badge du Prix
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _ThixColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                event.formattedPrice,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: _ThixColors.primary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getCategoryLabel(String slug) {
    const labels = {
      'musique': '🎵 MUSIQUE',
      'conference': '🎤 CONFÉRENCE',
      'culture': '🎨 CULTURE',
      'sport': '⚽ SPORT',
      'festival': '🎪 FESTIVAL',
      'spectacle': '🎭 SPECTACLE',
      'exposition': '🖼️ EXPOSITION',
    };
    return labels[slug.toLowerCase()]?.toUpperCase() ?? slug.toUpperCase();
  }
}
