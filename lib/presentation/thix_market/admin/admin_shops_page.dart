import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'admin_provider.dart';

class AdminShopsPage extends StatefulWidget {
  const AdminShopsPage({super.key});

  @override
  State<AdminShopsPage> createState() => _AdminShopsPageState();
}

class _AdminShopsPageState extends State<AdminShopsPage> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedStatus = 'all';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminProvider>().loadShops();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Gestion des boutiques'),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => context.read<AdminProvider>().loadShops(refresh: true),
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
                      hintText: 'Rechercher une boutique...',
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
                    DropdownMenuItem(value: 'active', child: Text('Actives')),
                    DropdownMenuItem(value: 'pending', child: Text('En attente')),
                    DropdownMenuItem(value: 'suspended', child: Text('Suspendues')),
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
                if (provider.isLoading && provider.shops.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (provider.shops.isEmpty) {
                  return const Center(child: Text('Aucune boutique'));
                }
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: provider.shops.length,
                  itemBuilder: (context, index) {
                    final shop = provider.shops[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundImage: shop['logo_url'] != null ? CachedNetworkImageProvider(shop['logo_url']) : null,
                          child: shop['logo_url'] == null ? const Icon(Icons.store) : null,
                        ),
                        title: Text(shop['name']),
                        subtitle: Text(shop['owner']?['email'] ?? 'Propriétaire inconnu'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (shop['status'] == 'pending')
                              ElevatedButton(
                                onPressed: () => provider.updateShopStatus(shop['id'], 'active'),
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                                child: const Text('Valider'),
                              ),
                            if (shop['status'] == 'active')
                              OutlinedButton(
                                onPressed: () => provider.updateShopStatus(shop['id'], 'suspended'),
                                style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                                child: const Text('Suspendre'),
                              ),
                            if (shop['status'] == 'suspended')
                              OutlinedButton(
                                onPressed: () => provider.updateShopStatus(shop['id'], 'active'),
                                child: const Text('Réactiver'),
                              ),
                          ],
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
