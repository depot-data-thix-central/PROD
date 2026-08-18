// lib/presentation/thix_weeding/widgets/home/promo_banner_widget.dart
import 'package:flutter/material.dart';

class PromoBannerWidget extends StatelessWidget {
  final List<Map<String, String>> promos;
  const PromoBannerWidget({super.key, required this.promos});

  @override
  Widget build(BuildContext context) {
    if (promos.isEmpty) return const SizedBox();
    return SizedBox(
      height: 140,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        itemCount: promos.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final p = promos[index];
          return Container(
            width: 220,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), color: Colors.white, border: Border.all(color: Colors.grey.shade200)),
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p['title']!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 4),
                const Text('Jusqu’à', style: TextStyle(fontSize: 11, color: Colors.grey)),
                Text(p['discount']!, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFFE25A6A))),
                const Spacer(),
                Text(p['subtitle']!, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          );
        },
      ),
    );
  }
}
