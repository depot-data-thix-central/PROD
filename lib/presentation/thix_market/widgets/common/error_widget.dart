import 'package:flutter/material.dart';

class ThixErrorWidget extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  final String? buttonText;

  const ThixErrorWidget({
    super.key,
    required this.message,
    this.onRetry,
    this.buttonText,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text(
              'Oups ! Une erreur est survenue',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: TextStyle(color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: Text(buttonText ?? 'Réessayer'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE5592F),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// Network error
class NetworkErrorWidget extends StatelessWidget {
  final VoidCallback onRetry;

  const NetworkErrorWidget({super.key, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return ThixErrorWidget(
      message: 'Vérifiez votre connexion internet et réessayez',
      onRetry: onRetry,
      buttonText: 'Réessayer',
    );
  }
}

// Server error
class ServerErrorWidget extends StatelessWidget {
  final VoidCallback onRetry;

  const ServerErrorWidget({super.key, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return ThixErrorWidget(
      message: 'Le serveur rencontre des problèmes. Veuillez réessayer plus tard.',
      onRetry: onRetry,
      buttonText: 'Réessayer',
    );
  }
}

// NotFound error
class NotFoundErrorWidget extends StatelessWidget {
  final String itemName;

  const NotFoundErrorWidget({super.key, required this.itemName});

  @override
  Widget build(BuildContext context) {
    return ThixErrorWidget(
      message: '$itemName est introuvable',
      onRetry: () => Navigator.pop(context),
      buttonText: 'Retour',
    );
  }
}
