// lib/presentation/thix_weeding/widgets/home/category_grid_widget.dart
import 'package:flutter/material.dart';

class CategoryGridWidget extends StatelessWidget {
  final void Function(String label)? onTapCategory;
  const CategoryGridWidget({super.key, this.onTapCategory});

  @override
  Widget build(BuildContext context) {
    final items = [
      (Icons.home_outlined, 'Salles de fête'),
      (Icons.restaurant_outlined, 'Traiteurs'),
      (Icons.mic_none_outlined, 'Maîtres de cérémonie'),
      (Icons.park_outlined, 'Décoration'),
      (Icons.camera_alt_outlined, 'Photographes'),
      (Icons.checkroom_outlined, 'Robes & Costumes'),
      (Icons.cake_outlined, 'Gâteaux'),
      (Icons.music_note_outlined, 'DJ & Son'),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, childAspectRatio: 0.85, mainAxisSpacing: 12, crossAxisSpacing: 12),
      itemCount: items.length,
      itemBuilder: (context, i) {
        final item = items[i];
        return InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => onTapCategory?.call(item.$2),
          child: Column(
            children: [
              CircleAvatar(radius: 26, backgroundColor: Colors.pink.shade50, child: Icon(item.$1, color: Colors.pink.shade400)),
              const SizedBox(height: 6),
              Text(item.$2, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
            ],
          ),
        );
      },
    );
  }
}
