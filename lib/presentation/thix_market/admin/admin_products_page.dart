import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'admin_provider.dart';

class AdminProductsPage extends StatefulWidget {
  const AdminProductsPage({super.key});

  @override
  State<AdminProductsPage> createState() => _AdminProductsPageState();
}

class _AdminProductsPageState extends State<AdminProductsPage> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedStatus = 'all';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminProvider>().loadProducts();
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
        title: const Text('Gestion des produits'),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => context.read<AdminProvider>().loadProducts(refresh: true),
          ),
        ],
      ),
      body: Column(
        children: [
          // Barre de recherche et filtres
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Rechercher un produit...',
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
                    DropdownMenuItem(value: 'active', child: Text('Actifs')),
                    DropdownMenuItem(value: 'pending', child: Text('En attente')),
                    DropdownMenuItem(value: 'inactive', child: Text('Inactifs')),
                  ],
                  onChanged: (value) {
                    setState(() => _selectedStatus = value!);
                    context.read<AdminProvider>().setStatusFilter(value!);
                  },
                ),
              ],
            ),
          ),
          // Tableau des produits
          Expanded(
            child: Consumer<AdminProvider>(
              builder: (context, provider, _) {
                if (provider.isLoading && provider.products.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (provider.products.isEmpty) {
                  return const Center(child: Text('Aucun produit'));
                }
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: provider.products.length,
                  itemBuilder: (context, index) {
                    final product = provider.products[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: CachedNetworkImage(
                                imageUrl: (product['images'] is List && (product['images'] as List).isNotEmpty)
                                    ? (product['images'] as List).first
                                    : '',
                                width: 60, height: 60, fit: BoxFit.cover,
                                errorWidget: (_, __, ___) => Container(width: 60, height: 60, color: Colors.grey[200]),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(product['title'], style: const TextStyle(fontWeight: FontWeight.bold)),
                                  Text(product['shop']?['name'] ?? 'Boutique', style: const TextStyle(fontSize: 12)),
                                  Text('${product['price']?.toInt()} FCFA', style: const TextStyle(color: Color(0xFFE5592F))),
                                ],
                              ),
                            ),
                            DropdownButton<String>(
                              value: product['status'],
                              items: const [
                                DropdownMenuItem(value: 'active', child: Text('Actif')),
                                DropdownMenuItem(value: 'inactive', child: Text('Inactif')),
                                DropdownMenuItem(value: 'pending', child: Text('En attente')),
                              ],
                              onChanged: (value) => provider.updateProductStatus(product['id'], value!),
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
          // Pagination
          Consumer<AdminProvider>(
            builder: (context, provider, _) {
              final totalPages = (provider.totalProducts / 20).ceil();
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(onPressed: provider.previousPage, icon: const Icon(Icons.chevron_left)),
                    Text('Page ${provider.currentPage + 1} / $totalPages'), // ✅ correction ici
                    IconButton(onPressed: provider.nextPage, icon: const Icon(Icons.chevron_right)),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
