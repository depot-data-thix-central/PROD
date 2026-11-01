// lib/presentation/thix_weeding/thix_weeding_routes.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

// HOME
import 'pages/home/thix_weeding_home_page.dart';

// GUEST
import 'pages/guest/guest_home_page.dart';
import 'pages/guest/invitation_page.dart';
import 'pages/guest/programme_page.dart';
import 'pages/guest/lieu_acces_page.dart';
import 'pages/guest/rsvp_page.dart';
import 'pages/guest/cadeaux_page.dart';
import 'pages/guest/galerie_page.dart';
import 'pages/guest/livre_or_page.dart';
import 'pages/guest/infos_page.dart';

// STAFF - CORE & SHELL
import 'pages/staff/staff_shell_page.dart';
import 'pages/staff/staff_dashboard_page.dart';
import 'pages/staff/my_weddings/my_weddings_page.dart';
import 'pages/staff/my_weddings/create_wedding_page.dart';

// STAFF MODULES
import 'pages/staff/invités/guest_list_page.dart';
import 'pages/staff/invités/add_guest_page.dart';
import 'pages/staff/invités/guest_detail_page.dart';
import 'pages/staff/prestataires/vendors_list_page.dart';
import 'pages/staff/prestataires/add_vendor_page.dart';
import 'pages/staff/messages/staff_messages_page.dart';
import 'pages/staff/messages/chat_detail_page.dart';
import 'pages/staff/budget/budget_page.dart';
import 'pages/staff/paiements/payments_page.dart';
import 'pages/staff/paiements/add_payment_page.dart';
import 'pages/staff/paiements/payment_detail_page.dart';
import 'pages/staff/checklist/checklist_page.dart';
import 'pages/staff/planning/planning_page.dart';
import 'pages/staff/planning/task_form_page.dart';
import 'pages/staff/galerie/gallery_management_page.dart';
import 'pages/staff/livre_or/guestbook_management_page.dart';
import 'pages/staff/invitation/preview_invitation_page.dart';
import 'pages/staff/parametres/settings_page.dart';
import 'pages/staff/seating/seating_3d_page.dart';
import 'pages/staff/cadeaux/gifts_management_page.dart';

class ThixWeedingRoutes {
  static const String home = '/thix-weeding';

  // --- NAMES FOR PROGRAMMATIC NAVIGATION ---
  static const String guestHome = 'guestHome';
  static const String staffShell = 'staffShell';
  static const String staffDashboard = 'staffDashboard';
  static const String staffInvites = 'staffInvites';
  static const String staffAddInvite = 'staffAddInvite';
  static const String staffEditInvite = 'staffEditInvite';
  static const String staffGuestDetail = 'staffGuestDetail';
  static const String staffPrestataires = 'staffPrestataires';
  static const String staffAddPrestataire = 'staffAddPrestataire';
  static const String staffEditPrestataire = 'staffEditPrestataire';
  static const String staffMessages = 'staffMessages';
  static const String staffChatDetail = 'staffChatDetail';
  static const String staffBudget = 'staffBudget';
  static const String staffPaiements = 'staffPaiements';
  static const String staffAddPaiement = 'staffAddPaiement';
  static const String staffPaiementDetail = 'staffPaiementDetail';
  static const String staffChecklist = 'staffChecklist';
  static const String staffAddTask = 'staffAddTask';
  static const String staffPlanning = 'staffPlanning';
  static const String staffGalerie = 'staffGalerie';
  static const String staffLivreOr = 'staffLivreOr';
  static const String staffInvitation = 'staffInvitation';
  static const String staffSettings = 'staffSettings';
  static const String staffSeating = 'staffSeating';
  static const String staffCadeaux = 'staffCadeaux';
  static const String myWeddingsList = 'myWeddingsList';

  static List<RouteBase> get routes => [
        GoRoute(
          path: home,
          name: 'thixWeedingHome',
          builder: (context, state) => const ThixWeedingHomePage(),
          routes: [
            // ================= CRÉATION MARIAGE =================
            GoRoute(
              path: 'create',
              name: 'createWedding',
              builder: (c, s) => const CreateWeddingPage(),
            ),

            // ================= LISTE DES MARIAGES (AVANT :weddingId) =================
            GoRoute(
              path: 'staff/my-weddings',
              name: myWeddingsList,
              builder: (c, s) => const MyWeddingsPage(),
            ),

            // ================= ESPACE INVITÉ =================
            GoRoute(
              path: 'guest/:weddingId',
              name: guestHome,
              redirect: (context, state) {
                final id = state.pathParameters['weddingId'] ?? '';
                if (id.trim().length < 4) return home;
                return null;
              },
              builder: (context, state) {
                final weddingId = state.pathParameters['weddingId']!;
                return GuestHomePage(weddingId: weddingId);
              },
              routes: [
                GoRoute(
                  path: 'invitation',
                  builder: (c, s) =>
                      InvitationPage(weddingId: s.pathParameters['weddingId']!),
                ),
                GoRoute(
                  path: 'programme',
                  builder: (c, s) =>
                      ProgrammePage(weddingId: s.pathParameters['weddingId']!),
                ),
                GoRoute(
                  path: 'lieu',
                  builder: (c, s) =>
                      LieuAccesPage(weddingId: s.pathParameters['weddingId']!),
                ),
                GoRoute(
                  path: 'rsvp',
                  builder: (c, s) =>
                      RsvpPage(weddingId: s.pathParameters['weddingId']!),
                ),
                GoRoute(
                  path: 'cadeaux',
                  builder: (c, s) =>
                      CadeauxPage(weddingId: s.pathParameters['weddingId']!),
                ),
                GoRoute(
                  path: 'galerie',
                  builder: (c, s) =>
                      GaleriePage(weddingId: s.pathParameters['weddingId']!),
                ),
                GoRoute(
                  path: 'livre-or',
                  builder: (c, s) =>
                      LivreOrPage(weddingId: s.pathParameters['weddingId']!),
                ),
                GoRoute(
                  path: 'infos',
                  builder: (c, s) =>
                      InfosPage(weddingId: s.pathParameters['weddingId']!),
                ),
              ],
            ),

            // ================= DASHBOARD STAFF =================
            GoRoute(
              path: 'staff/:weddingId',
              name: staffShell,
              redirect: (context, state) {
                final id = state.pathParameters['weddingId'] ?? '';
                if (id == 'my-weddings') {
                  return '$home/staff/my-weddings';
                }
                if (id.trim().length < 4) return home;
                return null;
              },
              builder: (context, state) {
                final weddingId = state.pathParameters['weddingId']!;
                return StaffShellPage(weddingId: weddingId);
              },
              routes: [
                // 1. TABLEAU DE BORD
                GoRoute(
                  path: '.',
                  name: staffDashboard,
                  builder: (c, s) => StaffDashboardPage(
                      weddingId: s.pathParameters['weddingId']!),
                ),

                // 2. INVITÉS
                GoRoute(
                  path: 'invites',
                  name: staffInvites,
                  builder: (c, s) => GuestListPage(
                      weddingId: s.pathParameters['weddingId']!),
                  routes: [
                    GoRoute(
                      path: 'add',
                      name: staffAddInvite,
                      builder: (c, s) => AddGuestPage(
                          weddingId: s.pathParameters['weddingId']!),
                    ),
                    // Détail invité (URL: .../invites/:guestId)
                    GoRoute(
                      path: ':guestId',
                      name: staffGuestDetail,
                      builder: (c, s) => GuestDetailPage(
                        weddingId: s.pathParameters['weddingId']!,
                        guestId: s.pathParameters['guestId']!,
                      ),
                      routes: [
                        GoRoute(
                          path: 'edit',
                          name: staffEditInvite,
                          builder: (c, s) => AddGuestPage(
                            weddingId: s.pathParameters['weddingId']!,
                            editGuestId: s.pathParameters['guestId'],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                // 3. PRESTATAIRES
                GoRoute(
                  path: 'prestataires',
                  name: staffPrestataires,
                  builder: (c, s) => VendorsListPage(
                      weddingId: s.pathParameters['weddingId']!),
                  routes: [
                    GoRoute(
                      path: 'add',
                      name: staffAddPrestataire,
                      builder: (c, s) => AddVendorPage(
                          weddingId: s.pathParameters['weddingId']!),
                    ),
                    GoRoute(
                      path: ':vendorId/edit',
                      name: staffEditPrestataire,
                      builder: (c, s) => AddVendorPage(
                        weddingId: s.pathParameters['weddingId']!,
                        editVendorId: s.pathParameters['vendorId'],
                      ),
                    ),
                  ],
                ),

                // 4. MESSAGES
                GoRoute(
                  path: 'messages',
                  name: staffMessages,
                  builder: (c, s) => StaffMessagesPage(
                      weddingId: s.pathParameters['weddingId']!),
                  routes: [
                    GoRoute(
                      path: ':guestId',
                      name: staffChatDetail,
                      builder: (c, s) => ChatDetailPage(
                        weddingId: s.pathParameters['weddingId']!,
                        guestIdOrName: s.pathParameters['guestId']!,
                      ),
                    ),
                  ],
                ),

                // 5. BUDGET
                GoRoute(
                  path: 'budget',
                  name: staffBudget,
                  builder: (c, s) =>
                      BudgetPage(weddingId: s.pathParameters['weddingId']!),
                ),

                // 6. PAIEMENTS
                GoRoute(
                  path: 'paiements',
                  name: staffPaiements,
                  builder: (c, s) =>
                      PaymentsPage(weddingId: s.pathParameters['weddingId']!),
                  routes: [
                    GoRoute(
                      path: 'add',
                      name: staffAddPaiement,
                      builder: (c, s) => AddPaymentPage(
                          weddingId: s.pathParameters['weddingId']!),
                    ),
                    GoRoute(
                      path: ':paymentId',
                      name: staffPaiementDetail,
                      builder: (c, s) => PaymentDetailPage(
                        weddingId: s.pathParameters['weddingId']!,
                        paymentId: s.pathParameters['paymentId']!,
                      ),
                    ),
                  ],
                ),

                // 7. CHECKLIST
                GoRoute(
                  path: 'checklist',
                  name: staffChecklist,
                  builder: (c, s) => ChecklistPage(
                      weddingId: s.pathParameters['weddingId']!),
                  routes: [
                    GoRoute(
                      path: 'add',
                      name: staffAddTask,
                      builder: (c, s) => TaskFormPage(
                          weddingId: s.pathParameters['weddingId']!),
                    ),
                  ],
                ),

                // 8. PLANNING (manquait → 404)
                GoRoute(
                  path: 'planning',
                  name: staffPlanning,
                  builder: (c, s) => PlanningPage(
                      weddingId: s.pathParameters['weddingId']!),
                ),

                // 9. GALERIE
                GoRoute(
                  path: 'galerie',
                  name: staffGalerie,
                  builder: (c, s) => GalleryManagementPage(
                      weddingId: s.pathParameters['weddingId']!),
                ),

                // 10. LIVRE D'OR
                GoRoute(
                  path: 'livre-or',
                  name: staffLivreOr,
                  builder: (c, s) => GuestbookManagementPage(
                      weddingId: s.pathParameters['weddingId']!),
                ),

                // 11. INVITATION STUDIO
                GoRoute(
                  path: 'invitation',
                  name: staffInvitation,
                  builder: (c, s) => PreviewInvitationPage(
                      weddingId: s.pathParameters['weddingId']!),
                ),

                // 12. PLAN DE TABLE 3D
                GoRoute(
                  path: 'seating',
                  name: staffSeating,
                  builder: (c, s) => Seating3dPage(
                      weddingId: s.pathParameters['weddingId']!),
                ),

                // 13. CADEAUX (staff)
                GoRoute(
                  path: 'cadeaux',
                  name: staffCadeaux,
                  builder: (c, s) => GiftsManagementPage(
                      weddingId: s.pathParameters['weddingId']!),
                ),

                // 14. PARAMÈTRES
                GoRoute(
                  path: 'parametres',
                  name: staffSettings,
                  builder: (c, s) => SettingsPage(
                      weddingId: s.pathParameters['weddingId']!),
                ),
              ],
            ),
          ],
        ),
      ];
}
