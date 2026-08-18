// lib/presentation/thix_market/supermarket/widgets/aisle_chips.dart
// Chips catégories vertes comme capture milieu - actif vert, inactif gris clair

import 'package:flutter/material.dart';

class AisleChips extends StatelessWidget {
  final List<Map<String, dynamic>> aisles;
  final String selected;
  final Function(String) onSelect;

  const AisleChips({
    super.key,
    required this.aisles,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 76,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: aisles.length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (_, i) {
          final a = aisles[i];
          final name = (a['name']?? '') as String;
          final active = selected == name;

          // Icon mapping prod
          IconData icon = Icons.category_rounded;
          final l = name.toLowerCase();
          if (l.contains('tous') || l.contains('all')) icon = Icons.apps_rounded;
          else if (l.contains('frais') || l.contains('fresh') || l.contains('fruit')) icon = Icons.eco_rounded;
          else if (l.contains('fruit')) icon = Icons.apple_rounded;
          else if (l.contains('snack')) icon = Icons.cookie_rounded;
          else if (l.contains('grocery') || l.contains('épic')) icon = Icons.shopping_basket_rounded;
          else if (l.contains('boisson') || l.contains('drink')) icon = Icons.local_drink_rounded;
          else if (l.contains('lait') || l.contains('oil') || l.contains('oil')) icon = Icons.water_drop_rounded;

          return GestureDetector(
            onTap: () => onSelect(name),
            behavior: HitTestBehavior.opaque,
            child: Column(
              children: [
                // Cercle
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: active? const Color(0xFF4AA85F) : const Color(0xFFF1F5F0),
                    shape: BoxShape.circle,
                    border: Border.all(color: active? const Color(0xFF4AA85F) : Colors.transparent, width: 1.5),
                    boxShadow: active? [BoxShadow(color: const Color(0xFF4AA85F).withOpacity(.25), blurRadius: 8, offset: const Offset(0, 3))] : [],
                  ),
                  child: Icon(icon, color: active? Colors.white : const Color(0xFF6B8A6E), size: 22),
                ),
                const SizedBox(height: 6),
                // Label
                Text(
                  name,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: active? FontWeight.w800 : FontWeight.w600,
                    color: active? const Color(0xFF2E7D32) : const Color(0xFF4A4A4A),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
