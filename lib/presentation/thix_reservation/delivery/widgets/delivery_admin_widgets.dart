// ================================================================
// CHEMIN: lib/presentation/thix_reservation/delivery/widgets/delivery_admin_widgets.dart
// ROLE: Widgets ADMIN seulement - 4 pages admin utilisent ça
//       Cards pour routes avec prix + stats + shipments
// SCALABLE: Dismissible pour delete + const
// ================================================================

import 'package:flutter/material.dart';
import '../data/delivery_models.dart';

const _primary = Color(0xFF6D28D9);

// --------------------------------------------------------------
// ADMIN WIDGET 1: Route Card avec prix éditable
// Affichée dans dashboard admin
// --------------------------------------------------------------
class AdminRouteCard extends StatelessWidget {
  final DeliveryRoute route;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const AdminRouteCard({super.key, required this.route, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
      child: Row(
        children: [
          // Icône trajet
          Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: _primary.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.route, color: _primary)),
          const SizedBox(width: 12),
          // Infos trajet
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text("${route.fromCity} → ${route.toCity}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 2),
              Text("${route.distanceKm}km • ${route.standardDays}", style: const TextStyle(fontSize: 10, color: Colors.grey)),
              const SizedBox(height: 4),
              Row(children: [
                _PriceChip(label: "Base", price: route.basePrice),
                const SizedBox(width: 6),
                _PriceChip(label: "Express", price: route.expressPrice, isExpress: true),
              ])
            ]),
          ),
          // Boutons edit/delete
          IconButton(onPressed: onEdit, icon: const Icon(Icons.edit, size: 18, color: _primary)),
          IconButton(onPressed: onDelete, icon: const Icon(Icons.delete, size: 18, color: Colors.red)),
        ],
      ),
    );
  }
}

class _PriceChip extends StatelessWidget {
  final String label;
  final int price;
  final bool isExpress;
  const _PriceChip({required this.label, required this.price, this.isExpress = false});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: isExpress ? Colors.orange.withOpacity(0.1) : Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
      child: Text("$label: $price F", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isExpress ? Colors.orange : Colors.green)),
    );
  }
}

// --------------------------------------------------------------
// ADMIN WIDGET 2: Stat Card pour dashboard
// --------------------------------------------------------------
class AdminStatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  const AdminStatCard({super.key, required this.title, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Icon(icon, color: color, size: 20), Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold))]),
        const SizedBox(height: 6),
        Text(title, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ]),
    );
  }
}
