import 'package:flutter/material.dart';

class DeliveryStatusTimeline extends StatelessWidget {
  final String currentStatus;
  final List<Map<String, dynamic>>? customStatuses;

  const DeliveryStatusTimeline({
    super.key,
    required this.currentStatus,
    this.customStatuses,
  });

  static const List<Map<String, dynamic>> _defaultStatuses = [
    {'key': 'preparing', 'label': 'Préparation', 'icon': Icons.inventory},
    {'key': 'picked_up', 'label': 'Récupéré', 'icon': Icons.check_circle},
    {'key': 'in_transit', 'label': 'En transit', 'icon': Icons.local_shipping},
    {'key': 'out_for_delivery', 'label': 'En livraison', 'icon': Icons.delivery_dining},
    {'key': 'delivered', 'label': 'Livré', 'icon': Icons.home},
  ];

  List<Map<String, dynamic>> get _statuses => customStatuses ?? _defaultStatuses;

  bool _isStatusCompleted(String statusKey) {
    final order = _statuses.map((e) => e['key'] as String).toList();
    final currentIndex = order.indexOf(currentStatus);
    final statusIndex = order.indexOf(statusKey);
    return statusIndex < currentIndex;
  }

  bool _isCurrentStatus(String statusKey) => currentStatus == statusKey;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Statut de la livraison',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _statuses.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final status = _statuses[index];
            final isCompleted = _isStatusCompleted(status['key']);
            final isCurrent = _isCurrentStatus(status['key']);
            return Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isCompleted
                        ? Colors.green.withOpacity(0.1)
                        : isCurrent
                            ? const Color(0xFFE5592F).withOpacity(0.1)
                            : Colors.grey[200],
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    status['icon'],
                    color: isCompleted
                        ? Colors.green
                        : isCurrent
                            ? const Color(0xFFE5592F)
                            : Colors.grey,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        status['label'],
                        style: TextStyle(
                          fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                          color: isCompleted
                              ? Colors.green
                              : isCurrent
                                  ? const Color(0xFFE5592F)
                                  : Colors.grey[700],
                        ),
                      ),
                      if (isCurrent)
                        const SizedBox(height: 4),
                      if (isCurrent)
                        Text(
                          'En cours de traitement',
                          style: TextStyle(
                            fontSize: 12,
                            color: const Color(0xFFE5592F).withOpacity(0.7),
                          ),
                        ),
                    ],
                  ),
                ),
                if (isCompleted)
                  const Icon(Icons.check_circle, color: Colors.green, size: 18),
              ],
            );
          },
        ),
      ],
    );
  }
}
