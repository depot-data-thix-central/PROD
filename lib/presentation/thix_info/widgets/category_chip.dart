// lib/presentation/thix_info/widgets/category_chip.dart
import 'package:flutter/material.dart';

class CategoryChip extends StatelessWidget {
  final String label;
  final String value;
  final IconData? icon;
  final bool isSelected;
  final VoidCallback onTap;

  const CategoryChip({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFD4AF37).withOpacity(0.15) : Colors.white,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: isSelected ? const Color(0xFFD4AF37) : Colors.grey[300]!,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 16,
                color: isSelected ? const Color(0xFFD4AF37) : Colors.grey[600],
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected ? const Color(0xFFD4AF37) : Colors.grey[700],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CategoryChipsList extends StatelessWidget {
  final String selectedCategory;
  final Function(String) onCategorySelected;

  const CategoryChipsList({
    super.key,
    required this.selectedCategory,
    required this.onCategorySelected,
  });

  @override
  Widget build(BuildContext context) {
    final categories = [
      {'slug': 'featured', 'name': 'À la une', 'icon': Icons.local_fire_department},
      {'slug': 'politique', 'name': 'Politique', 'icon': Icons.account_balance},
      {'slug': 'economie', 'name': 'Économie', 'icon': Icons.trending_up},
      {'slug': 'societe', 'name': 'Société', 'icon': Icons.people},
      {'slug': 'tech', 'name': 'Tech', 'icon': Icons.computer},
      {'slug': 'sport', 'name': 'Sport', 'icon': Icons.sports_soccer},
      {'slug': 'culture', 'name': 'Culture', 'icon': Icons.museum},
      {'slug': 'international', 'name': 'International', 'icon': Icons.public},
    ];

    return SizedBox(
      height: 48,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final cat = categories[index];
          return CategoryChip(
            label: cat['name'] as String,
            value: cat['slug'] as String,
            icon: cat['icon'] as IconData,
            isSelected: selectedCategory == cat['slug'],
            onTap: () => onCategorySelected(cat['slug'] as String),
          );
        },
      ),
    );
  }
}
