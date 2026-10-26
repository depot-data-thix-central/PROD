// lib/presentation/thix_market/pages/vendor_products_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'package:thix_id/core/theme/thix_design_policy.dart';

import '../core/local_sectors.dart';
import '../providers/local_moderation_providers.dart';

class VendorProductsPage extends ConsumerStatefulWidget {
  const VendorProductsPage({
    super.key,
    this.shopId,
    this.localOnly = false,
  });

  final String? shopId;
  final bool localOnly;

  @override
  ConsumerState<VendorProductsPage> createState() => _VendorProductsPageState();
}

class _VendorProductsPageState extends ConsumerState<VendorProductsPage> {
  List<Map<String, dynamic>> _products = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final client = Supabase.instance.client;
      final uid = client.auth.currentUser?.id;

      if (uid == null) {
        setState(() {
          _error = 'Utilisateur non authentifié';
          _loading = false;
        });
        return;
      }

      List<String> shopIds = [];

      // Cas 1 : un shopId précis a été passé
      if (widget.shopId != null && widget.shopId!.isNotEmpty) {
        shopIds = [widget.shopId!];
      } else {
        // Cas 2 : charger TOUS les shops de l'utilisateur
        final shopsRes = await client
            .from('shops')
            .select('id')
            .eq('owner_id', uid);

        shopIds = (shopsRes as List)
            .map((s) => (s as Map)['id']?.toString())
            .whereType<String>()
            .toList();
      }

      if (shopIds.isEmpty) {
        setState(() {
          _error = 'Aucune boutique trouvée';
          _loading = false;
        });
        return;
      }

      var query = client
          .from('products')
          .select('*')
          .inFilter('shop_id', shopIds);

      if (widget.localOnly) {
        query = query.eq('is_local', true);
      }

      final res = await query.order('created_at', ascending: false);

      setState(() {
        _products = List<Map<String, dynamic>>.from(res as List);
        _loading = false;
      });
    } catch (e) {
      debugPrint('[VendorProducts] ❌ Load error: $e');
      setState(() {
        _error = 'Erreur de chargement: $e';
        _loading = false;
      });
    }
  }

  Future<void> _deleteProduct(String productId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer ce produit ?'),
        content: const Text('Cette action est irréversible.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await Supabase.instance.client
          .from('products')
          .delete()
          .eq('id', productId);

      _loadProducts();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Produit supprimé ✅'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _t(String fr, String en) {
    final lang = Localizations.localeOf(context).languageCode;
    return lang == 'fr' ? fr : en;
  }

  @override
  Widget build(BuildContext context) {
    // ✅ FIX: Interpolation Dart correcte
    final productCountText = _products.length > 1
        ? '${_products.length} produits'
        : '${_products.length} produit';

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.localOnly
                  ? _t('Produits locaux', 'Local products')
                  : _t('Tous les produits', 'All products'),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
            ),
            Text(
              productCountText,
              style: const TextStyle(fontSize: 11, color: Colors.white70),
            ),
          ],
        ),
        backgroundColor: widget.localOnly ? kLocalGreen : ThixPolicy.primary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadProducts,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          if (widget.localOnly) {
            context.push('/market/local/create');
          } else {
            context.push('/market/product/create');
          }
        },
        backgroundColor: widget.localOnly ? kLocalGreen : ThixPolicy.primary,
        icon: const Icon(Icons.add),
        label: Text(
          widget.localOnly
              ? _t('Produit local', 'Local product')
              : _t('Produit', 'Product'),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: Colors.red),
                      const SizedBox(height: 16),
                      Text(_error!, style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadProducts,
                        child: const Text('Réessayer'),
                      ),
                    ],
                  ),
                )
              : _products.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            widget.localOnly ? Icons.agriculture : Icons.inventory_2,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            widget.localOnly
                                ? _t('Aucun produit local', 'No local products')
                                : _t('Aucun produit', 'No products'),
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _t('Créez votre premier produit', 'Create your first product'),
                            style: TextStyle(color: Colors.grey[500]),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadProducts,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _products.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final product = _products[index];
                          return _ProductCard(
                            product: product,
                            isLocal: widget.localOnly,
                            onEdit: () {
                              final id = product['id']?.toString();
                              if (id != null) {
                                context.push('/market/product/$id/edit');
                              }
                            },
                            onDelete: () => _deleteProduct(product['id']?.toString() ?? ''),
                          );
                        },
                      ),
                    ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final Map<String, dynamic> product;
  final bool isLocal;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ProductCard({
    required this.product,
    required this.isLocal,
    required this.onEdit,
    required this.onDelete,
  });

  String _t(BuildContext context, String fr, String en) {
    final lang = Localizations.localeOf(context).languageCode;
    return lang == 'fr' ? fr : en;
  }

  @override
  Widget build(BuildContext context) {
    final title = product['title']?.toString() ?? 'Sans titre';
    final price = product['price']?.toDouble() ?? 0;
    final stock = product['stock']?.toInt() ?? 0;
    final status = product['status']?.toString() ?? 'draft';
    final imageUrl = product['image_url']?.toString();
    final sectorId = product['local_sector']?.toString() ?? product['category']?.toString();
    final sector = localSectorById(sectorId);

    Color statusColor;
    String statusLabel;

    switch (status) {
      case 'active':
        statusColor = Colors.green;
        statusLabel = _t(context, 'Actif', 'Active');
        break;
      case 'pending':
        statusColor = Colors.orange;
        statusLabel = _t(context, 'En attente', 'Pending');
        break;
      case 'rejected':
        statusColor = Colors.red;
        statusLabel = _t(context, 'Refusé', 'Rejected');
        break;
      default:
        statusColor = Colors.grey;
        statusLabel = _t(context, 'Brouillon', 'Draft');
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                child: Container(
                  height: 120,
                  width: double.infinity,
                  color: Colors.grey[200],
                  child: imageUrl != null && imageUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: imageUrl,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => const Icon(Icons.image, size: 40),
                        )
                      : const Icon(Icons.image, size: 40),
                ),
              ),
              if (isLocal)
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: kLocalGreen,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'LOCAL',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    statusLabel,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 6),
                if (sector != null)
                  Text(
                    sector.label('fr'),
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[600],
                    ),
                  ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${price.toStringAsFixed(2)} FC',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: isLocal ? kLocalGreen : ThixPolicy.primary,
                      ),
                    ),
                    Text(
                      _t(context, 'Stock: $stock', 'Stock: $stock'),
                      style: TextStyle(
                        fontSize: 12,
                        color: stock > 0 ? Colors.green[700] : Colors.red[700],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onEdit,
                        icon: const Icon(Icons.edit, size: 16),
                        label: Text(_t(context, 'Modifier', 'Edit')),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: ThixPolicy.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: onDelete,
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      tooltip: _t(context, 'Supprimer', 'Delete'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
