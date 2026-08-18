import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class DeliveryCard extends StatelessWidget {
  final Map<String, dynamic> delivery;
  final VoidCallback? onTap;
  final VoidCallback? onTrack;

  const DeliveryCard({
    super.key,
    required this.delivery,
    this.onTap,
    this.onTrack,
  });

  String _formatDate(String? dateStr) {
    if (dateStr == null) return 'Date inconnue';
    final date = DateTime.parse(dateStr);
    return DateFormat('dd MMM yyyy, HH:mm').format(date);
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'preparing':
        return Colors.orange;
      case 'picked_up':
        return Colors.blue;
      case 'in_transit':
        return Colors.purple;
      case 'out_for_delivery':
        return Colors.teal;
      case 'delivered':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'preparing':
        return 'En préparation';
      case 'picked_up':
        return 'Récupéré';
      case 'in_transit':
        return 'En transit';
      case 'out_for_delivery':
        return 'En livraison';
      case 'delivered':
        return 'Livré';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = delivery['status'] ?? 'preparing';
    final statusColor = _statusColor(status);
    final orderId = delivery['order_id'];
    final trackingNumber = delivery['tracking_number'];

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Commande #$orderId',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _statusLabel(status),
                      style: TextStyle(color: statusColor, fontSize: 12),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (trackingNumber != null)
                Text(
                  'N° suivi: $trackingNumber',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              const SizedBox(height: 4),
              Text(
                'Commandé le ${_formatDate(delivery['created_at'])}',
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
              const Divider(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onTrack,
                      icon: const Icon(Icons.map, size: 16),
                      label: const Text('Suivre'),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: const Color(0xFFE5592F)),
                        foregroundColor: const Color(0xFFE5592F),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
