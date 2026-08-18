import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'admin_provider.dart';

class AdminOrdersPage extends StatefulWidget {
  const AdminOrdersPage({super.key});

  @override
  State<AdminOrdersPage> createState() => _AdminOrdersPageState();
}

class _AdminOrdersPageState extends State<AdminOrdersPage> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedStatus = 'all';
  String _sortBy = 'created_at';
  bool _sortAscending = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminProvider>().loadOrders();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Gestion des commandes'),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => context.read<AdminProvider>().loadOrders(refresh: true),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Rechercher une commande...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    onChanged: (value) => context.read<AdminProvider>().setSearchQuery(value),
                  ),
                ),
                const SizedBox(width: 12),
                DropdownButton<String>(
                  value: _selectedStatus,
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('Tous')),
                    DropdownMenuItem(value: 'pending', child: Text('En attente')),
                    DropdownMenuItem(value: 'processing', child: Text('Traitement')),
                    DropdownMenuItem(value: 'shipped', child: Text('Expédiée')),
                    DropdownMenuItem(value: 'delivered', child: Text('Livrée')),
                    DropdownMenuItem(value: 'cancelled', child: Text('Annulée')),
                  ],
                  onChanged: (value) {
                    setState(() => _selectedStatus = value!);
                    context.read<AdminProvider>().setStatusFilter(value!);
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: Consumer<AdminProvider>(
              builder: (context, provider, _) {
                if (provider.isLoading && provider.orders.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (provider.orders.isEmpty) {
                  return const Center(child: Text('Aucune commande'));
                }
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: provider.orders.length,
                  itemBuilder: (context, index) {
                    final order = provider.orders[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: const Icon(Icons.receipt),
                        title: Text('Commande #${order['id']}'),
                        subtitle: Text('${order['user']?['name']} - ${order['total']?.toInt()} FCFA'),
                        trailing: DropdownButton<String>(
                          value: order['status'],
                          items: const [
                            DropdownMenuItem(value: 'pending', child: Text('En attente')),
                            DropdownMenuItem(value: 'processing', child: Text('Traitement')),
                            DropdownMenuItem(value: 'shipped', child: Text('Expédiée')),
                            DropdownMenuItem(value: 'delivered', child: Text('Livrée')),
                            DropdownMenuItem(value: 'cancelled', child: Text('Annulée')),
                          ],
                          onChanged: (value) async {
                            await provider.updateOrderStatus(order['id'], value!);
                          },
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
