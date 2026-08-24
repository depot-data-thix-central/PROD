// lib/presentation/thix_ia/thix_ia_routes.dart
import 'package:go_router/go_router.dart';
import 'core/constants/thix_ia_routes.dart';
import 'pages/thix_ia_home_page.dart';
import 'pages/projects_page.dart';
import 'pages/create_project_page.dart';
import 'pages/project_detail_page.dart';
import 'pages/analysis_page.dart';
import 'pages/research_page.dart';
import 'pages/market_page.dart';
import 'pages/legal_page.dart';
import 'pages/finance_page.dart';
import 'pages/business_page.dart';
import 'pages/strategy_page.dart';
import 'pages/design_page.dart';
import 'pages/documents_page.dart';
import 'pages/reports_page.dart';
import 'pages/chat_page.dart'; // L'import de ta page de chat

class ThixIaRouter {
  static List<RouteBase> get routes => [
        // Home
        GoRoute(
          path: ThixIARoutes.home, // /thix-ia/home
          name: 'thix-ia-home',
          builder: (context, state) => const ThixIaHomePage(),
        ),
        // Alias racine /thix-ia → home
        GoRoute(
          path: ThixIARoutes.root, // /thix-ia
          name: 'thix-ia-root',
          builder: (context, state) => const ThixIaHomePage(),
        ),

        // Liste projets
        GoRoute(
          path: ThixIARoutes.projects, // /thix-ia/projects
          name: 'thix-ia-projects',
          builder: (context, state) => const ProjectsPage(),
        ),

        // Création (AVANT le :projectCode)
        GoRoute(
          path: ThixIARoutes.createProject, // /thix-ia/projects/create
          name: 'thix-ia-create-project',
          builder: (context, state) => const CreateProjectPage(),
        ),

        // Détail + sous-routes
        GoRoute(
          path: ThixIARoutes.projectDetail, // /thix-ia/projects/:projectCode
          name: 'thix-ia-project-detail',
          builder: (context, state) {
            final code = state.pathParameters['projectCode']!;
            return ProjectDetailPage(projectCode: code);
          },
          routes: [
            // 👇 LA ROUTE CHAT AVEC GESTION DU MESSAGE INITIAL 👇
            GoRoute(
              path: 'chat',
              name: 'thix-ia-chat',
              builder: (context, state) {
                final code = state.pathParameters['projectCode']!;
                
                // On récupère le message envoyé par les boutons rapides
                final extraMessage = state.extra as String?; 
                
                return ChatPage(
                  projectCode: code,
                  initialMessage: extraMessage, 
                );
              },
            ),
            // ----------------------------------------------------
            GoRoute(
              path: 'analysis',
              name: 'thix-ia-analysis',
              builder: (context, state) {
                final code = state.pathParameters['projectCode']!;
                return AnalysisPage(projectCode: code);
              },
            ),
            GoRoute(
              path: 'research',
              name: 'thix-ia-research',
              builder: (context, state) {
                final code = state.pathParameters['projectCode']!;
                return ResearchPage(projectCode: code);
              },
            ),
            GoRoute(
              path: 'market',
              name: 'thix-ia-market',
              builder: (context, state) {
                final code = state.pathParameters['projectCode']!;
                return MarketPage(projectCode: code);
              },
            ),
            GoRoute(
              path: 'legal',
              name: 'thix-ia-legal',
              builder: (context, state) {
                final code = state.pathParameters['projectCode']!;
                return LegalPage(projectCode: code);
              },
            ),
            GoRoute(
              path: 'finance',
              name: 'thix-ia-finance',
              builder: (context, state) {
                final code = state.pathParameters['projectCode']!;
                return FinancePage(projectCode: code);
              },
            ),
            GoRoute(
              path: 'business',
              name: 'thix-ia-business',
              builder: (context, state) {
                final code = state.pathParameters['projectCode']!;
                return BusinessPage(projectCode: code);
              },
            ),
            GoRoute(
              path: 'strategy',
              name: 'thix-ia-strategy',
              builder: (context, state) {
                final code = state.pathParameters['projectCode']!;
                return StrategyPage(projectCode: code);
              },
            ),
            GoRoute(
              path: 'design',
              name: 'thix-ia-design',
              builder: (context, state) {
                final code = state.pathParameters['projectCode']!;
                return DesignPage(projectCode: code);
              },
            ),
            GoRoute(
              path: 'documents',
              name: 'thix-ia-documents',
              builder: (context, state) {
                final code = state.pathParameters['projectCode']!;
                return DocumentsPage(projectCode: code);
              },
            ),
            GoRoute(
              path: 'reports',
              name: 'thix-ia-reports',
              builder: (context, state) {
                final code = state.pathParameters['projectCode']!;
                return ReportsPage(projectCode: code);
              },
            ),
          ],
        ),
      ];
}
