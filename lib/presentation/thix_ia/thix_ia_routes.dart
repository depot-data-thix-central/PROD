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

class ThixIaRouter {
  static List<RouteBase> get routes => [
    GoRoute(
      path: ThixIARoutes.home, 
      name: 'thix-ia-home',
      builder: (context, state) => const ThixIaHomePage(),
    ),
    GoRoute(
      path: ThixIARoutes.projects,
      name: 'thix-ia-projects',
      builder: (context, state) => const ProjectsPage(),
    ),
    GoRoute(
      path: ThixIARoutes.createProject,
      name: 'thix-ia-create-project',
      builder: (context, state) => const CreateProjectPage(),
    ),
    // DETAIL + SUB-ROUTES DYNAMIQUES
    GoRoute(
      path: ThixIARoutes.projectDetail,
      name: 'thix-ia-project-detail',
      builder: (context, state) {
        final code = state.pathParameters['code']!;
        return ProjectDetailPage(projectCode: code);
      },
      routes: [
        GoRoute(
          path: 'analysis',
          name: 'thix-ia-analysis',
          builder: (context, state) {
            final code = state.pathParameters['code']!;
            return AnalysisPage(projectCode: code);
          },
        ),
        GoRoute(
          path: 'research',
          name: 'thix-ia-research',
          builder: (context, state) {
            final code = state.pathParameters['code']!;
            return ResearchPage(projectCode: code);
          },
        ),
        GoRoute(
          path: 'market',
          name: 'thix-ia-market',
          builder: (context, state) {
            final code = state.pathParameters['code']!;
            return MarketPage(projectCode: code);
          },
        ),
        GoRoute(
          path: 'legal',
          name: 'thix-ia-legal',
          builder: (context, state) {
            final code = state.pathParameters['code']!;
            return LegalPage(projectCode: code);
          },
        ),
        GoRoute(
          path: 'finance',
          name: 'thix-ia-finance',
          builder: (context, state) {
            final code = state.pathParameters['code']!;
            return FinancePage(projectCode: code);
          },
        ),
        GoRoute(
          path: 'business',
          name: 'thix-ia-business',
          builder: (context, state) {
            final code = state.pathParameters['code']!;
            return BusinessPage(projectCode: code);
          },
        ),
        GoRoute(
          path: 'strategy',
          name: 'thix-ia-strategy',
          builder: (context, state) {
            final code = state.pathParameters['code']!;
            return StrategyPage(projectCode: code);
          },
        ),
        GoRoute(
          path: 'design',
          name: 'thix-ia-design',
          builder: (context, state) {
            final code = state.pathParameters['code']!;
            return DesignPage(projectCode: code);
          },
        ),
        GoRoute(
          path: 'documents',
          name: 'thix-ia-documents',
          builder: (context, state) {
            final code = state.pathParameters['code']!;
            return DocumentsPage(projectCode: code);
          },
        ),
        GoRoute(
          path: 'reports',
          name: 'thix-ia-reports',
          builder: (context, state) {
            final code = state.pathParameters['code']!;
            return ReportsPage(projectCode: code);
          },
        ),
      ],
    ),
  ];
}
