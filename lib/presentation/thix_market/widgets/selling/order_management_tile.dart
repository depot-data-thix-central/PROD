// lib/presentation/thix_market/vendor/widgets/order_management_tile.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';

class OrderManagementTile extends StatefulWidget {
  final Map<String, dynamic> order;
  final Function(Map<String, dynamic>)? onStatusChanged;

  const OrderManagementTile({
    super.key,
    required this.order,
    this.onStatusChanged,
  });

  @override
  State<OrderManagementTile> createState() => _OrderManagementTileState();
}

class _OrderManagementTileState extends State<OrderManagementTile> {
  bool _isUpdating = false;
  String _currentStatus = '';

  @override
  void initState() {
    super.initState();
    _currentStatus = widget.order['status'] ?? 'pending';
  }

  Future<void> _updateStatus(String newStatus) async {
    setState(() => _isUpdating = true);
    
    try {
      await Supabase.instance.client
          .from('orders')
          .update({
            'status': newStatus,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', widget.order['id']);
      
      setState(() {
        _currentStatus = newStatus;
        _isUpdating = false;
      });
      
      widget.onStatusChanged?.call({...widget.order, 'status': newStatus});
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Commande mise à jour: ${_getStatusLabel(newStatus)}')),
        );
      }
    } catch (e) {
      debugPrint('Error updating status: $e');
      setState(() => _isUpdating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: ${e.toString()}')),
      );
    }
  }

  void _showStatusDialog() {
    final statuses = [
      {'value': 'pending', 'label': 'En attente', 'color': Colors.orange},
      {'value': 'confirmed', 'label': 'Confirmée', 'color': Colors.blue},
      {'value': 'preparing', 'label': 'En préparation', 'color': Colors.purple},
      {'value': 'shipped', 'label': 'Expédiée', 'color': Colors.indigo},
      {'value': 'delivered', 'label': 'Livrée', 'color': Colors.green},
      {'value': 'cancelled', 'label': 'Annulée', 'color': Colors.red},
    ];
    
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Changer le statut', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ...statuses.map((status) => ListTile(
              leading: Icon(Icons.circle, color: status['color'] as Color, size: 16),
              title: Text(status['label'] as String),
              trailing: _currentStatus == status['value'] ? const Icon(Icons.check, color: Colors.green) : null,
              onTap: () {
                Navigator.pop(context);
                _updateStatus(status['value'] as String);
              },
            )),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.order['items'] as List? ?? [];
    final total = widget.order['total'] ?? 0;
    final createdAt = widget.order['created_at'] != null
        ? DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(widget.order['created_at']))
        : '';
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Commande #${widget.order['id']}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getStatusColor(_currentStatus).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _getStatusLabel(_currentStatus),
                    style: TextStyle(color: _getStatusColor(_currentStatus), fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            
            // Client info
            Row(
              children: [
                const Icon(Icons.person, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Text(widget.order['customer_name'] ?? 'Client', style: const TextStyle(fontSize: 12)),
                const SizedBox(width: 12),
                const Icon(Icons.phone, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Text(widget.order['customer_phone'] ?? '', style: const TextStyle(fontSize: 12)),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.location_on, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    widget.order['shipping_address'] ?? '',
                    style: const TextStyle(fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(createdAt, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
            const Divider(height: 16),
            
            // Products
            ...items.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: CachedNetworkImage(
                      imageUrl: item['image_url'] ?? '',
                      width: 40,
                      height: 40,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => Container(
                        width: 40,
                        height: 40,
                        color: Colors.grey[200],
                        child: const Icon(Icons.image, size: 20),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item['name'] ?? 'Produit', style: const TextStyle(fontSize: 13), maxLines: 1),
                        Text('x${item['quantity']}', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                      ],
                    ),
                  ),
                  Text('${((item['price'] ?? 0) * (item['quantity'] ?? 1)).toInt()} FCFA', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                ],
              ),
            )),
            
            const Divider(height: 16),
            
            // Total
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total', style: TextStyle(fontWeight: FontWeight.bold)),
                Text('${total.toInt()} FCFA', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFE5592F))),
              ],
            ),
            const SizedBox(height: 12),
            
            // Actions
            Row(
              children: [
                if (_currentStatus != 'cancelled' && _currentStatus != 'delivered')
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isUpdating ? null : _showStatusDialog,
                      icon: _isUpdating
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.sync),
                      label: const Text('Changer statut'),
                      style: OutlinedButton.styleFrom(side: BorderSide(color: Colors.grey[300]!)),
                    ),
                  ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _viewOrderDetail,
                    icon: const Icon(Icons.visibility),
                    label: const Text('Détails'),
                    style: OutlinedButton.styleFrom(side: BorderSide(color: Colors.grey[300]!)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending': return Colors.orange;
      case 'confirmed': return Colors.blue;
      case 'preparing': return Colors.purple;
      case 'shipped': return Colors.indigo;
      case 'delivered': return Colors.green;
      case 'cancelled': return Colors.red;
      default: return Colors.grey;
    }
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'pending': return 'En attente';
      case 'confirmed': return 'Confirmée';
      case 'preparing': return 'En préparation';
      case 'shipped': return 'Expédiée';
      case 'delivered': return 'Livrée';
      case 'cancelled': return 'Annulée';
      default: return status;
    }
  }

  // 👇 SÉCURISÉ : Utilisation de pushNamed avec les bons paramètres dynamiques
  void _viewOrderDetail() {
    context.pushNamed(
      'marketOrderDetail', 
      pathParameters: {'orderId': widget.order['id'].toString()},
    );
  }
}
