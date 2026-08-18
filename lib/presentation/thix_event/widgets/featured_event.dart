import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../models/event_model.dart';

class _ThixColors {
  static const surface = Color(0xFF0C0C12);
  static const surfaceAlt = Color(0xFF111118);
  static const cardBorder = Color(0x14FFFFFF);
  static const primary = Color(0xFFFF0A54);
  static const textSecondary = Color(0x99FFFFFF);
  static const textMuted = Color(0x66FFFFFF);
}

class FeaturedEventWidget extends StatelessWidget {
  final Event event;
  const FeaturedEventWidget({super.key, required this.event});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/thix-event/event/${event.id}'),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: _ThixColors.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: _ThixColors.cardBorder),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Stack(children: [
            if (event.imageUrl != null && event.imageUrl!.isNotEmpty)
              Image.network(event.imageUrl!, height: 180, width: double.infinity, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(height: 180, color: _ThixColors.surfaceAlt))
            else
              Container(height: 180, color: _ThixColors.surfaceAlt),
            Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black.withOpacity(0.55)])))),
            Positioned(
              top: 12, left: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: _ThixColors.primary.withOpacity(0.18), borderRadius: BorderRadius.circular(20), border: Border.all(color: _ThixColors.primary.withOpacity(0.3))),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.star_rounded, size: 12, color: _ThixColors.primary), SizedBox(width: 4), Text('A LA UNE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: _ThixColors.primary))]),
              ),
            ),
          ]),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(event.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900, height: 1.2)),
              const SizedBox(height: 6),
              Text(event.description, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _ThixColors.textSecondary, fontSize: 12, height: 1.4)),
              const SizedBox(height: 14),
              Row(children: [
                const Icon(Icons.calendar_today_rounded, size: 12, color: _ThixColors.textMuted),
                const SizedBox(width: 6),
                Text(DateFormat('dd MMM - HH:mm', 'fr').format(event.startDate), style: const TextStyle(color: _ThixColors.textMuted, fontSize: 11, fontWeight: FontWeight.w600)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [Text('Decouvrir', style: TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.w800)), SizedBox(width: 4), Icon(Icons.arrow_outward_rounded, size: 12, color: Colors.black)]),
                ),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}
