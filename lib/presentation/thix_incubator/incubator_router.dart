// ============================================================================
// FICHIER : lib/presentation/thix_incubator/incubator_router.dart
// Module  : thix_incubator
// ============================================================================
// Sous-router GoRouter pour le module INCUBATOR.
// Pattern identique à ThixIaRouter (spread operator dans app_router.dart).
// ============================================================================

import 'package:go_router/go_router.dart';

import '../../nav.dart';
import 'pages/incubator_home_page.dart';
import 'pages/program_details_page.dart';

class IncubatorRouter {
  static List<GoRoute> get routes => [
    GoRoute(
      path: AppRoutes.incubator,
      name: 'incubator',
      pageBuilder: (_, __) => const NoTransitionPage(child: IncubatorHomePage()),
    ),
    GoRoute(
      path: AppRoutes.incubatorProgram(':programId'),
      name: 'incubatorProgram',
      pageBuilder: (_, state) => NoTransitionPage(
        child: ProgramDetailsPage(
          programId: state.pathParameters['programId'] ?? '',
        ),
      ),
    ),
    // Routes supplémentaires à ajouter au fur et à mesure :
    // - /incubator/explore
    // - /incubator/projects
    // - /incubator/applications
    // - /incubator/mentors
    // - /incubator/pitch
  ];
}
