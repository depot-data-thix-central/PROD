// lib/presentation/thix_market/supermarket/supermarket_detail.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/supermarket_provider.dart';

class SupermarketDetail extends StatefulWidget {
  final String shopId;
  const SupermarketDetail({super.key, required this.shopId});
  @override State<SupermarketDetail> createState() => _SupermarketDetailState();
}

class _SupermarketDetailState extends State<SupermarketDetail> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) return;
      context.read<SupermarketProvider>().loadShopDetail(widget.shopId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<SupermarketProvider>();
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F6),
      appBar: AppBar(
        backgroundColor: const Color(0xFF4AA85F),
        title: Text(prov.shops.isNotEmpty? prov.shops.firstWhere((s) => s['id'] == widget.shopId, orElse: () => {'name': 'Freshia'})['name'] : 'Freshia'),
      ),
      body: prov.isLoadingDetail
         ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: prov.filteredProducts.length,
              itemBuilder: (_, i) {
                final p = prov.filteredProducts[i];
                return Card(
                  child: ListTile(
                    title: Text(p['title']?? 'Produit'),
                    subtitle: Text('${p['price']?? 0}'),
                    trailing: IconButton(icon: const Icon(Icons.add), onPressed: () => prov.add(p['id'], 1)),
                  ),
                );
              },
            ),
    );
  }
}
