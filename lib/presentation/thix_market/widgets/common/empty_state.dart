import 'package:flutter/material.dart';

class EmptyState extends StatelessWidget {
  final String title;
  final String message;
  final IconData icon;
  final String? buttonText;
  final VoidCallback? onButtonPressed;
  final double iconSize;

  const EmptyState({
    super.key,
    required this.title,
    required this.message,
    required this.icon,
    this.buttonText,
    this.onButtonPressed,
    this.iconSize = 64,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: iconSize, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: TextStyle(color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            if (buttonText != null && onButtonPressed != null) ...[
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: onButtonPressed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE5592F),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                ),
                child: Text(buttonText!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// Empty cart
class EmptyCart extends StatelessWidget {
  const EmptyCart({super.key});

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      title: 'Votre panier est vide',
      message: 'Ajoutez des produits à votre panier pour continuer',
      icon: Icons.shopping_cart_outlined,
      buttonText: 'Découvrir les produits',
      onButtonPressed: () => Navigator.pushNamed(context, '/buy'),
    );
  }
}

// Empty orders
class EmptyOrders extends StatelessWidget {
  final bool isPurchase;
  const EmptyOrders({super.key, this.isPurchase = true});

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      title: isPurchase ? 'Aucune commande' : 'Aucune vente',
      message: isPurchase 
          ? 'Vous n\'avez pas encore passé de commande'
          : 'Vous n\'avez pas encore reçu de commande',
      icon: Icons.shopping_bag_outlined,
      buttonText: isPurchase ? 'Acheter maintenant' : 'Publier une annonce',
      onButtonPressed: () => isPurchase 
          ? Navigator.pushNamed(context, '/buy')
          : Navigator.pushNamed(context, '/sell'),
    );
  }
}

// Empty search
class EmptySearch extends StatelessWidget {
  final String query;
  final VoidCallback onClear;

  const EmptySearch({super.key, required this.query, required this.onClear});

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      title: 'Aucun résultat',
      message: 'Aucun produit trouvé pour "$query"',
      icon: Icons.search_off,
      buttonText: 'Effacer la recherche',
      onButtonPressed: onClear,
    );
  }
}
