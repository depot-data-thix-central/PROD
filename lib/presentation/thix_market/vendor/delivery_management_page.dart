// lib/presentation/thix_market/vendor/delivery_management_page.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DeliveryManagementPage extends StatefulWidget {
  const DeliveryManagementPage({super.key});

  @override
  State<DeliveryManagementPage> createState() => _DeliveryManagementPageState();
}

class _DeliveryManagementPageState extends State<DeliveryManagementPage> {
  List<Map<String, dynamic>> _deliveries = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDeliveries();
  }

  Future<void> _loadDeliveries() async {
    setState(() => _isLoading = true);
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;
      // Récupérer les commandes avec statut de livraison (selon votre schéma)
      final response = await Supabase.instance.client
          .from('orders')
          .select('id, total, status, delivery_status, created_at')
          .eq('shop_id', userId) // à adapter si la colonne est 'seller_id' ou autre
          .neq('delivery_status', 'delivered')
          .order('created_at', ascending: false);
      setState(() {
        _deliveries = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading deliveries: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateDeliveryStatus(String orderId, String newStatus) async {
    try {
      await Supabase.instance.client
          .from('orders')
          .update({'delivery_status': newStatus})
          .eq('id', orderId);
      await _loadDeliveries();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Statut de livraison mis à jour')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur : $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestion des livraisons'),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDeliveries,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _deliveries.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.local_shipping, size: 80, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      const Text('Aucune livraison en cours'),
                      const SizedBox(height: 8),
                      Text('Les livraisons apparaîtront ici',
                          style: TextStyle(color: Colors.grey[600])),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _deliveries.length,
                  itemBuilder: (context, index) {
                    final delivery = _deliveries[index];
                    final statusOptions = ['pending', 'shipped', 'in_transit', 'delivered'];
                    final labels = {
                      'pending': 'En attente',
                      'shipped': 'Expédiée',
                      'in_transit': 'En transit',
                      'delivered': 'Livrée',
                    };
                    final currentStatus = delivery['delivery_status'] ?? 'pending';

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: Icon(
                          currentStatus == 'pending' ? Icons.pending :
                          currentStatus == 'shipped' ? Icons.local_shipping :
                          currentStatus == 'in_transit' ? Icons.directions_car :
                          Icons.check_circle,
                          color: currentStatus == 'delivered' ? Colors.green : Colors.orange,
                        ),
                        title: Text('Commande #${delivery['id']}'),
                        subtitle: Text('${delivery['total']?.toInt() ?? 0} FCFA - ${delivery['created_at'] ?? ''}'),
                        trailing: DropdownButton<String>(
                          value: currentStatus,
                          items: statusOptions.map((status) {
                            return DropdownMenuItem(
                              value: status,
                              child: Text(labels[status] ?? status),
                            );
                          }).toList(),
                          onChanged: (newStatus) {
                            if (newStatus != null) {
                              _updateDeliveryStatus(delivery['id'], newStatus);
                            }
                          },
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
