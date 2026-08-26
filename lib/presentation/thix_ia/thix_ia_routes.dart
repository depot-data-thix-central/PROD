// lib/presentation/thix_ia/thix_ia_routes.dart
import 'package:go_router/go_router.dart';
import 'core/constants/thix_ia_routes.dart';

// ── Core THIX IA ──────────────────────────────────────────────
import 'pages/thix_ia_home_page.dart';
import 'pages/projects_page.dart';
import 'pages/create_project_page.dart';
import 'pages/project_detail_page.dart';
import 'pages/analysis_page.dart';
import 'pages/research_page.dart';
import 'pages/market_page.dart';
import 'pages/legal_page.dart';
import 'pages/finance_page.dart'; // Finance analyse (ancien module)
import 'pages/business_page.dart';
import 'pages/strategy_page.dart';
import 'pages/design_page.dart';
import 'pages/documents_page.dart';
import 'pages/reports_page.dart';
import 'pages/chat_page.dart';

// ── EXECUTION MODULE (SaaS pilotage) ──────────────────────────
import 'pages/execution/execution_dashboard_final.dart';
import 'pages/execution/finance_page.dart' as exec_finance;
import 'pages/execution/tasks_page.dart' as exec_tasks;
import 'pages/execution/roadmap_page.dart' as exec_roadmap;
import 'pages/execution/suppliers_page.dart' as exec_suppliers;
import 'pages/execution/risk_page.dart' as exec_risk;
import 'pages/execution/experiment_page.dart' as exec_experiment;
import 'pages/execution/reports_page.dart' as exec_reports;
import 'pages/execution/market_radar_page.dart' as exec_market_radar;

// Optionnels — décommente si les fichiers existent dans le repo :
// import 'pages/execution/team_page.dart' as exec_team;
// import 'pages/execution/coaching_page.dart' as exec_coaching;
// import 'pages/execution/opportunity_page.dart' as exec_opportunity;
// import 'pages/execution/previsionnel_12m_page.dart' as exec_previsionnel;
// import 'pages/execution/investors_crm_page.dart' as exec_investors;
// import 'pages/bp_document_editor_page.dart';

class ThixIaRouter {
  static List<RouteBase> get routes => [
        // ── Home / Root ───────────────────────────────────────
        GoRoute(
          path: ThixIARoutes.home,
          name: 'thix-ia-home',
          builder: (context, state) => const ThixIaHomePage(),
        ),
        GoRoute(
          path: ThixIARoutes.root,
          name: 'thix-ia-root',
          builder: (context, state) => const ThixIaHomePage(),
        ),

        // ── Projects list / create ────────────────────────────
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

        // ── Project detail + children ─────────────────────────
        GoRoute(
          path: ThixIARoutes.projectDetail,
          name: 'thix-ia-project-detail',
          builder: (context, state) {
            final code = state.pathParameters['projectCode']!;
            return ProjectDetailPage(projectCode: code);
          },
          routes: [
            // Chat
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

            // ── Modules analyse (existants) ───────────────────
            GoRoute(
              path: 'analysis',
              name: 'thix-ia-analysis',
              builder: (c, s) => AnalysisPage(
                  projectCode: s.pathParameters['projectCode']!),
            ),
            GoRoute(
              path: 'research',
              name: 'thix-ia-research',
              builder: (c, s) => ResearchPage(
                  projectCode: s.pathParameters['projectCode']!),
            ),
            GoRoute(
              path: 'market',
              name: 'thix-ia-market',
              builder: (c, s) => MarketPage(
                  projectCode: s.pathParameters['projectCode']!),
            ),
            GoRoute(
              path: 'legal',
              name: 'thix-ia-legal',
              builder: (c, s) => LegalPage(
                  projectCode: s.pathParameters['projectCode']!),
            ),
            GoRoute(
              path: 'finance',
              name: 'thix-ia-finance',
              builder: (c, s) => FinancePage(
                  projectCode: s.pathParameters['projectCode']!),
            ),
            GoRoute(
              path: 'business',
              name: 'thix-ia-business',
              builder: (c, s) => BusinessPage(
                  projectCode: s.pathParameters['projectCode']!),
            ),
            GoRoute(
              path: 'strategy',
              name: 'thix-ia-strategy',
              builder: (c, s) => StrategyPage(
                  projectCode: s.pathParameters['projectCode']!),
            ),
            GoRoute(
              path: 'design',
              name: 'thix-ia-design',
              builder: (c, s) => DesignPage(
                  projectCode: s.pathParameters['projectCode']!),
            ),
            GoRoute(
              path: 'documents',
              name: 'thix-ia-documents',
              builder: (c, s) => DocumentsPage(
                  projectCode: s.pathParameters['projectCode']!),
            ),
            GoRoute(
              path: 'reports',
              name: 'thix-ia-reports',
              builder: (c, s) => ReportsPage(
                  projectCode: s.pathParameters['projectCode']!),
            ),

            // ── EXECUTION MODULE ──────────────────────────────
            GoRoute(
              path: 'execution',
              name: 'thix-ia-execution',
              builder: (context, state) {
                final code = state.pathParameters['projectCode']!;
                final name =
                    state.uri.queryParameters['name'] ?? code;
                return ExecutionDashboardFinal(
                  projectCode: code,
                  projectName: name,
                );
              },
              routes: [
                // Financial Engine
                GoRoute(
                  path: 'finance-engine',
                  name: 'thix-ia-exec-finance',
                  builder: (c, s) => exec_finance.FinancePage(
                      projectCode: s.pathParameters['projectCode']!),
                ),
                // Auto-Kanban
                GoRoute(
                  path: 'tasks',
                  name: 'thix-ia-exec-tasks',
                  builder: (c, s) => exec_tasks.TasksPage(
                      projectCode: s.pathParameters['projectCode']!),
                ),
                // Roadmap
                GoRoute(
                  path: 'roadmap',
                  name: 'thix-ia-exec-roadmap',
                  builder: (c, s) => exec_roadmap.RoadmapPage(
                      projectCode: s.pathParameters['projectCode']!),
                ),
                // Fournisseurs
                GoRoute(
                  path: 'suppliers',
                  name: 'thix-ia-exec-suppliers',
                  builder: (c, s) => exec_suppliers.SuppliersPage(
                      projectCode: s.pathParameters['projectCode']!),
                ),
                // Risques & conformité
                GoRoute(
                  path: 'risks',
                  name: 'thix-ia-exec-risks',
                  builder: (c, s) => exec_risk.RiskPage(
                      projectCode: s.pathParameters['projectCode']!),
                ),
                // Experiment Center
                GoRoute(
                  path: 'experiments',
                  name: 'thix-ia-exec-experiments',
                  builder: (c, s) => exec_experiment.ExperimentPage(
                      projectCode: s.pathParameters['projectCode']!),
                ),
                // Reporting Auto
                GoRoute(
                  path: 'reports-auto',
                  name: 'thix-ia-exec-reports',
                  builder: (c, s) => exec_reports.ReportsPage(
                      projectCode: s.pathParameters['projectCode']!),
                ),
                // Market Radar
                GoRoute(
                  path: 'market-radar',
                  name: 'thix-ia-exec-market-radar',
                  builder: (c, s) =>
                      exec_market_radar.MarketRadarPage(
                          projectCode:
                              s.pathParameters['projectCode']!),
                ),

                // ── Optionnels (décommente + import si fichiers OK) ──
                // GoRoute(
                //   path: 'team',
                //   name: 'thix-ia-exec-team',
                //   builder: (c, s) => exec_team.TeamPage(
                //       projectCode: s.pathParameters['projectCode']!),
                // ),
                // GoRoute(
                //   path: 'coaching',
                //   name: 'thix-ia-exec-coaching',
                //   builder: (c, s) => exec_coaching.CoachingPage(
                //       projectCode: s.pathParameters['projectCode']!),
                // ),
                // GoRoute(
                //   path: 'opportunities',
                //   name: 'thix-ia-exec-opportunities',
                //   builder: (c, s) => exec_opportunity.OpportunityPage(
                //       projectCode: s.pathParameters['projectCode']!),
                // ),
                // GoRoute(
                //   path: 'previsionnel',
                //   name: 'thix-ia-exec-previsionnel',
                //   builder: (c, s) => exec_previsionnel.Previsionnel12mPage(
                //       projectCode: s.pathParameters['projectCode']!),
                // ),
                // GoRoute(
                //   path: 'investors',
                //   name: 'thix-ia-exec-investors',
                //   builder: (c, s) => exec_investors.InvestorsCrmPage(
                //       projectCode: s.pathParameters['projectCode']!),
                // ),
              ],
            ),
          ],
        ),
      ];
}
