import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

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

class CategoryChip extends StatelessWidget {
  final String label;
  final String slug;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const CategoryChip({
    super.key,
    required this.label,
    required this.slug,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          color: isSelected ? _ThixColors.primary.withOpacity(0.14) : _ThixColors.surface,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: isSelected ? _ThixColors.primary : _ThixColors.cardBorderStrong,
            width: isSelected ? 1.2 : 1,
          ),
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: _ThixColors.primary.withOpacity(0.18),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: isSelected ? _ThixColors.primary : _ThixColors.textSecondary),
            const SizedBox(width: 7),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? Colors.white : _ThixColors.textSecondary,
                letterSpacing: -0.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CategoryChipsList extends StatelessWidget {
  final String? selectedSlug;
  final Function(String slug)? onCategorySelected;

  const CategoryChipsList({super.key, this.selectedSlug, this.onCategorySelected});

  static const List<Map<String, dynamic>> _categories = [
    {'slug': 'musique', 'label': 'Musique', 'icon': Icons.music_note_rounded},
    {'slug': 'conference', 'label': 'Conferences', 'icon': Icons.mic_rounded},
    {'slug': 'culture', 'label': 'Culture', 'icon': Icons.palette_rounded},
    {'slug': 'sport', 'label': 'Sport', 'icon': Icons.sports_soccer_rounded},
    {'slug': 'festival', 'label': 'Festivals', 'icon': Icons.celebration_rounded},
    {'slug': 'spectacle', 'label': 'Spectacles', 'icon': Icons.theater_comedy_rounded},
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: _categories.map((cat) {
          final slug = cat['slug'] as String;
          final label = cat['label'] as String;
          final icon = cat['icon'] as IconData;
          return CategoryChip(
            label: label,
            slug: slug,
            icon: icon,
            isSelected: selectedSlug == slug,
            onTap: () {
              if (onCategorySelected != null) {
                onCategorySelected!(slug);
              } else {
                context.push('/thix-event/category/$slug');
              }
            },
          );
        }).toList(),
      ),
    );
  }
}
