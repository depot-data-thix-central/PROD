// lib/auth/auth_controller.dart
//
// Point d'entrée UNIQUE de l'authentification.
// Avant : deux classes AuthController distinctes (ici et dans
// features/auth/presentation/providers/auth_controller.dart), chacune avec son
// propre SupabaseAuthManager → deux gestionnaires parallèles sur la même
// session. Désormais tout passe par la classe de features/.
export 'package:thix_id/features/auth/presentation/providers/auth_controller.dart';
