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
import 'pages/chat_page.dart';

// EXECUTION MODULE - IMPORTS
import 'pages/execution/execution_dashboard_final.dart';
import 'pages/execution/finance_page.dart' as exec_finance;
import 'pages/execution/tasks_page.dart' as exec_tasks;
import 'pages/execution/roadmap_page.dart' as exec_roadmap;
import 'pages/execution/suppliers_page.dart' as exec_suppliers;
import 'pages/execution/risk_page.dart' as exec_risk;
import 'pages/execution/experiment_page.dart' as exec_experiment;
import 'pages/execution/team_page.dart' as exec_team;
import 'pages/execution/reports_page.dart' as exec_reports;
import 'pages/execution/coaching_page.dart' as exec_coaching;
import 'pages/execution/market_radar_page.dart' as exec_market_radar;
import 'pages/execution/opportunity_page.dart' as exec_opportunity;

class ThixIaRouter {
  static List<RouteBase> get routes => [
        // Home
        GoRoute(
          path: ThixIARoutes.home,
          name: 'thix-ia-home',
          builder: (context, state) => const ThixIaHomePage(),
        ),
        // Alias racine /thix-ia → home
        GoRoute(
          path: ThixIARoutes.root,
          name: 'thix-ia-root',
          builder: (context, state) => const ThixIaHomePage(),
        ),

        // Liste projets
        GoRoute(
          path: ThixIARoutes.projects,
          name: 'thix-ia-projects',
          builder: (context, state) => const ProjectsPage(),
        ),

        // Création (AVANT le :projectCode)
        GoRoute(
          path: ThixIARoutes.createProject,
          name: 'thix-ia-create-project',
          builder: (context, state) => const CreateProjectPage(),
        ),

        // Détail + sous-routes
        GoRoute(
          path: ThixIARoutes.projectDetail,
          name: 'thix-ia-project-detail',
          builder: (context, state) {
            final code = state.pathParameters['projectCode']!;
            return ProjectDetailPage(projectCode: code);
          },
          routes: [
            GoRoute(
              path: 'chat',
              name: 'thix-ia-chat',
              builder: (context, state) {
                final code = state.pathParameters['projectCode']!;
                final extraMessage = state.extra as String?;
                return ChatPage(
                  projectCode: code,
                  initialMessage: extraMessage,
                );
              },
            ),
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

            // ===== EXECUTION MODULE - NOUVELLES ROUTES =====
            // Dashboard principal Execution (ton screenshot)
            GoRoute(
              path: 'execution',
              name: 'thix-ia-execution',
              builder: (context, state) {
                final code = state.pathParameters['projectCode']!;
                final name = state.uri.queryParameters['name'] ?? 'EcoPlastic Pro';
                return ExecutionDashboardFinal(projectCode: code, projectName: name);
              },
              routes: [
                GoRoute(
                  path: 'finance-engine',
                  name: 'thix-ia-execution-finance',
                  builder: (context, state) {
                    final code = state.pathParameters['projectCode']!;
                    return exec_finance.FinancePage(projectCode: code);
                  },
                ),
                GoRoute(
                  path: 'tasks',
                  name: 'thix-ia-execution-tasks',
                  builder: (context, state) {
                    final code = state.pathParameters['projectCode']!;
                    return exec_tasks.TasksPage(projectCode: code);
                  },
                ),
                GoRoute(
                  path: 'roadmap',
                  name: 'thix-ia-execution-roadmap',
                  builder: (context, state) {
                    final code = state.pathParameters['projectCode']!;
                    return exec_roadmap.RoadmapPage(projectCode: code);
                  },
                ),
                GoRoute(
                  path: 'suppliers',
                  name: 'thix-ia-execution-suppliers',
                  builder: (context, state) {
                    final code = state.pathParameters['projectCode']!;
                    return exec_suppliers.SuppliersPage(projectCode: code);
                  },
                ),
                GoRoute(
                  path: 'risks',
                  name: 'thix-ia-execution-risks',
                  builder: (context, state) {
                    final code = state.pathParameters['projectCode']!;
                    return exec_risk.RiskPage(projectCode: code);
                  },
                ),
                GoRoute(
                  path: 'experiments',
                  name: 'thix-ia-execution-experiments',
                  builder: (context, state) {
                    final code = state.pathParameters['projectCode']!;
                    return exec_experiment.ExperimentPage(projectCode: code);
                  },
                ),
                GoRoute(
                  path: 'team',
                  name: 'thix-ia-execution-team',
                  builder: (context, state) {
                    final code = state.pathParameters['projectCode']!;
                    return exec_team.TeamPage(projectCode: code);
                  },
                ),
                GoRoute(
                  path: 'reports-auto',
                  name: 'thix-ia-execution-reports-auto',
                  builder: (context, state) {
                    final code = state.pathParameters['projectCode']!;
                    return exec_reports.ReportsPage(projectCode: code);
                  },
                ),
                GoRoute(
                  path: 'coaching',
                  name: 'thix-ia-execution-coaching',
                  builder: (context, state) {
                    final code = state.pathParameters['projectCode']!;
                    return exec_coaching.CoachingPage(projectCode: code);
                  },
                ),
                GoRoute(
                  path: 'market-radar',
                  name: 'thix-ia-execution-market-radar',
                  builder: (context, state) {
                    final code = state.pathParameters['projectCode']!;
                    return exec_market_radar.MarketRadarPage(projectCode: code);
                  },
                ),
                GoRoute(
                  path: 'opportunities',
                  name: 'thix-ia-execution-opportunities',
                  builder: (context, state) {
                    final code = state.pathParameters['projectCode']!;
                    return exec_opportunity.OpportunityPage(projectCode: code);
                  },
                ),
              ],
            ),
          ],
        ),
      ];
}

// Extensions navigation - Utilise les dans tes pages
extension ThixExecutionNavigation on GoRouter {
  void goToExecution(String code, {String? name}) => go('/thix-ia/projects/$code/execution?name=${name ?? code}');
}

extension ThixExecutionBuildContext on dynamic {
  void goToExecution(String code) {}
}
