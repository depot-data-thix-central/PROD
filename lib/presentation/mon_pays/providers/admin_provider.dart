// lib/presentation/mon_pays/providers/admin_provider.dart
// État global pour l'administration

import 'package:flutter_riverpod/flutter_riverpod.dart';

// État de chargement global pour l'admin
final adminLoadingProvider = StateProvider<bool>((ref) => false);

// Message d'erreur global pour l'admin
final adminErrorProvider = StateProvider<String?>((ref) => null);

// État d'édition (pour savoir si on est en mode création ou modification)
final adminEditModeProvider = StateProvider<bool>((ref) => false);

// Provider pour la notification de succès
final adminSuccessMessageProvider = StateProvider<String?>((ref) => null);

// Action pour réinitialiser tous les états admin
final resetAdminStateProvider = Provider((ref) => () {
  ref.read(adminLoadingProvider.notifier).state = false;
  ref.read(adminErrorProvider.notifier).state = null;
  ref.read(adminSuccessMessageProvider.notifier).state = null;
});

// Provider pour vérifier si l'utilisateur est admin
// (À connecter avec votre système d'authentification)
final isAdminProvider = Provider<bool>((ref) {
  // TODO: Connecter avec votre système d'authentification
  // return ref.watch(authProvider).user?.role == 'admin';
  return true; // Temporaire pour le développement
});
