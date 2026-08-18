import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../widgets/shops/manage_shop_widget.dart';

class ManageShopPage extends StatefulWidget {
  final String shopId;

  const ManageShopPage({super.key, required this.shopId});

  @override
  State<ManageShopPage> createState() => _ManageShopPageState();
}

class _ManageShopPageState extends State<ManageShopPage> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // Simuler un chargement minimal pour l'UI (le widget gère déjà le sien)
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) setState(() => _isLoading = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Gérer la boutique',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline, color: Colors.black),
            onPressed: () {
              // Ouvrir l'aide pour la gestion de boutique
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Aide pour la gestion de boutique'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ManageShopWidget(
              shopId: widget.shopId,
              onUpdate: (updatedShop) {
                // Notifier l'écran précédent si nécessaire
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Boutique mise à jour'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                }
              },
            ),
    );
  }
}
