// lib/presentation/thix_sante/patient/widgets/quick_service_grid.dart
// =============================================================================
// Widget: QuickServiceGrid
// Role: Grille reutilisable 6 colonnes medicale, badge NEW, UID LINK
// Utilise dans dashboard pour Services rapides et Services sante
// =============================================================================

import 'package:flutter/material.dart';
import '../../core/thix_id_validator.dart';
import '../../core/thix_sante_colors.dart';
class QuickServiceItem {
  final String label;
  final String icon;
  final Color color;
  final bool isNew;
  final bool hasUidLink;
  final Widget? destination;
  final VoidCallback? onTap;

  const QuickServiceItem({
    required this.label,
    required this.icon,
    required this.color,
    this.isNew = false,
    this.hasUidLink = false,
    this.destination,
    this.onTap,
  });
}

class QuickServiceGrid extends StatelessWidget {
  final List<QuickServiceItem> items;
  final int crossAxisCount;

  const QuickServiceGrid({
    super.key,
    required this.items,
    this.crossAxisCount = 6,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: 0.78,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final QuickServiceItem item = items[index];
        return _buildCard(context, item);
      },
    );
  }

  Widget _buildCard(BuildContext context, QuickServiceItem item) {
    return InkWell(
      onTap: () {
        if (item.destination!= null) {
          Navigator.push(context, MaterialPageRoute(builder: (_) => item.destination!));
        } else if (item.onTap!= null) {
          item.onTap!.call();
        }
      },
      borderRadius: BorderRadius.circular(14),
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              color: ThixSanteColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: ThixSanteColors.borderLight),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: item.color,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(item.icon, style: const TextStyle(fontSize: 19)),
                  ),
                ),
                const SizedBox(height: 7),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    item.label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 9.2,
                      fontWeight: FontWeight.w600,
                      height: 1.15,
                      color: ThixSanteColors.ink,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (item.isNew)
            Positioned(
              top: 5,
              right: 5,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: ThixSanteColors.success,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'NEW',
                  style: TextStyle(color: Colors.white, fontSize: 7, fontWeight: FontWeight.w900, letterSpacing: 0.3),
                ),
              ),
            ),
          if (item.hasUidLink)
            Positioned(
              bottom: 5,
              right: 5,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(
                  color: ThixSanteColors.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.link_rounded, size: 9, color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }
}
