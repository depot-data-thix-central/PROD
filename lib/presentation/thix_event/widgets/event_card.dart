// lib/presentation/thix_event/widgets/event_card.dart
import 'package:flutter/material.dart';
import '../../../models/event_model.dart';

class _ThixColors {
  static const bg = Color(0xFF050508);
  static const surface = Color(0xFF0C0C12);
  static const surfaceAlt = Color(0xFF111118);
  static const cardBorder = Color(0x14FFFFFF);
  static const cardBorderStrong = Color(0x26FFFFFF);
  static const primary = Color(0xFFFF0A54);
  static const textSecondary = Color(0x99FFFFFF);
  static const textMuted = Color(0x66FFFFFF);
}

class EventCard extends StatelessWidget {
  final Event event;
  final VoidCallback onTap;
  final bool isCompact;
  final VoidCallback? onShare;
  final VoidCallback? onFavoriteTap;

  const EventCard({
    super.key,
    required this.event,
    required this.onTap,
    this.isCompact = false,
    this.onShare,
    this.onFavoriteTap,
  });

  Color get _accent {
    final c = event.category.toLowerCase();
    if (c == 'musique' || c == 'concert') return const Color(0xFF6B3BFF);
    if (c == 'sport' || c == 'match') return const Color(0xFF10B981);
    if (c == 'festival') return const Color(0xFFEC4899);
    if (c == 'culture') return const Color(0xFF3B82F6);
    return _ThixColors.primary;
  }

  @override
  Widget build(BuildContext context) => isCompact ? _compact(context) : _grid(context);

  Widget _grid(BuildContext context) {
    final accent = _accent;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: _ThixColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _ThixColors.cardBorder),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, 
          children: [
            Stack(
              children: [
                AspectRatio(
                  aspectRatio: 1.25,
                  child: event.imageUrl != null && event.imageUrl!.isNotEmpty
                      ? Image.network(
                          event.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(color: _ThixColors.surfaceAlt),
                        )
                      : Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [accent.withOpacity(0.8), accent]),
                          ),
                          child: const Icon(Icons.event_rounded, color: Colors.white54),
                        ),
                ),
                Positioned(
                  top: 10, left: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: accent.withOpacity(0.9), borderRadius: BorderRadius.circular(8)),
                    child: Text(_label(event.category), style: const TextStyle(color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.w800)),
                  ),
                ),
                Positioned(
                  top: 10, right: 10,
                  child: GestureDetector(
                    onTap: onFavoriteTap,
                    child: Container(
                      width: 30, height: 30,
                      decoration: BoxDecoration(color: Colors.black.withOpacity(0.45), shape: BoxShape.circle, border: Border.all(color: Colors.white.withOpacity(0.12))),
                      child: Icon(event.isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded, size: 14, color: event.isLiked ? _ThixColors.primary : Colors.white),
                    ),
                  ),
                ),
                if (event.isFree)
                  Positioned(
                    bottom: 10, left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(color: const Color(0xFF10B981), borderRadius: BorderRadius.circular(6)),
                      child: const Text('GRATUIT', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w800)),
                    ),
                  ),
                Positioned(
                  bottom: 10, right: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: Colors.black.withOpacity(0.45), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withOpacity(0.12))),
                    child: Text(event.formattedPrice, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)),
                  ),
                ),
              ]
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, 
                children: [
                  Text(event.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w800, height: 1.2)),
                  const SizedBox(height: 6),
                  Row(children: [const Icon(Icons.calendar_today_rounded, size: 10, color: _ThixColors.textMuted), const SizedBox(width: 4), Text(event.shortDate, style: const TextStyle(color: _ThixColors.textMuted, fontSize: 10, fontWeight: FontWeight.w600))]),
                  const SizedBox(height: 4),
                  Row(children: [const Icon(Icons.location_on_rounded, size: 10, color: _ThixColors.textMuted), const SizedBox(width: 4), Expanded(child: Text(event.location, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _ThixColors.textMuted, fontSize: 10)))]),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity, height: 36,
                    child: ElevatedButton(
                      onPressed: onTap,
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
                      child: const Text('Réserver', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                    ),
                  ),
                ]
              ),
            ),
          ]
        ),
      ),
    );
  }

  Widget _compact(BuildContext context) {
    final accent = _accent;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: _ThixColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: _ThixColors.cardBorder)),
        child: Row(children: [
          Stack(children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: event.imageUrl != null && event.imageUrl!.isNotEmpty
                  ? Image.network(event.imageUrl!, width: 64, height: 64, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(width: 64, height: 64, color: _ThixColors.surfaceAlt))
                  : Container(width: 64, height: 64, decoration: BoxDecoration(color: accent.withOpacity(0.2)), child: Icon(Icons.event_rounded, color: accent)),
            ),
            if (onFavoriteTap != null)
              Positioned(top: 4, right: 4, child: GestureDetector(onTap: onFavoriteTap, child: Container(width: 20, height: 20, decoration: BoxDecoration(color: Colors.black.withOpacity(0.45), shape: BoxShape.circle), child: Icon(event.isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded, size: 10, color: event.isLiked ? _ThixColors.primary : Colors.white)))),
          ]),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: accent.withOpacity(0.15), borderRadius: BorderRadius.circular(6), border: Border.all(color: accent.withOpacity(0.25))), child: Text(_label(event.category), style: TextStyle(color: accent, fontSize: 8, fontWeight: FontWeight.w800))),
            const SizedBox(height: 4),
            Text(event.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Row(children: [const Icon(Icons.calendar_today_rounded, size: 9, color: _ThixColors.textMuted), const SizedBox(width: 3), Text(event.shortDate, style: const TextStyle(color: _ThixColors.textMuted, fontSize: 9))]),
          ])),
          const SizedBox(width: 8),
          Text(event.formattedPrice, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
        ]),
      ),
    );
  }

  String _label(String slug) {
    const m = {'musique': 'MUSIQUE', 'concert': 'CONCERT', 'conference': 'CONFERENCE', 'culture': 'CULTURE', 'sport': 'SPORT', 'match': 'MATCH', 'festival': 'FESTIVAL', 'spectacle': 'SPECTACLE'};
    return m[slug.toLowerCase()] ?? slug.toUpperCase();
  }
}
