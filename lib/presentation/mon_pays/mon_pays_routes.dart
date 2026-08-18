// lib/presentation/mon_pays/mon_pays_routes.dart
// Définition des routes internes du module (référence pour go_router)

class MonPaysRoutes {
  // === Routes statiques ===
  static const String home = '/mon-pays';
  static const String authorities = '/mon-pays/authorities';
  static const String authorityProfile = '/mon-pays/authority/:id';
  static const String adminAuthorities = '/mon-pays/admin';
  static const String adminAuthorityForm = '/mon-pays/admin/form';

  // === Helpers pour les routes dynamiques ===
  static String authorityProfilePath(String id) => '/mon-pays/authority/$id';
  static String adminFormPath({dynamic authority}) => '/mon-pays/admin/form';

  // === Noms des routes pour go_router (utilisés avec context.goNamed()) ===
  static const String homeName = 'monPays';
  static const String authoritiesName = 'monPaysAuthorities';
  static const String authorityProfileName = 'monPaysAuthorityProfile';
  static const String adminName = 'monPaysAdmin';
  static const String adminFormName = 'monPaysAdminForm';
}
