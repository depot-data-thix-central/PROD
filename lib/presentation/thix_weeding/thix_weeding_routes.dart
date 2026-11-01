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
import 'pages/staff/prestataires/vendors_list_page.dart';
import 'pages/staff/prestataires/add_vendor_page.dart';
import 'pages/staff/messages/staff_messages_page.dart';
import 'pages/staff/messages/chat_detail_page.dart';
import 'pages/staff/budget/budget_page.dart';
import 'pages/staff/paiements/payments_page.dart';
import 'pages/staff/paiements/add_payment_page.dart';
import 'pages/staff/paiements/payment_detail_page.dart';
import 'pages/staff/checklist/checklist_page.dart';
import 'pages/staff/planning/task_form_page.dart';
import 'pages/staff/galerie/gallery_management_page.dart';
import 'pages/staff/livre_or/guestbook_management_page.dart';
import 'pages/staff/invitation/preview_invitation_page.dart';
import 'pages/staff/parametres/settings_page.dart';

class ThixWeedingRoutes {
  static const String home = '/thix-weeding';
  
  // --- NAMES FOR PROGRAMMATIC NAVIGATION ---
  static const String guestHome = 'guestHome';
  static const String staffShell = 'staffShell';
  static const String staffDashboard = 'staffDashboard';
  static const String staffInvites = 'staffInvites';
  static const String staffAddInvite = 'staffAddInvite';
  static const String staffEditInvite = 'staffEditInvite';
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
  static const String staffGalerie = 'staffGalerie';
  static const String staffLivreOr = 'staffLivreOr';
  static const String staffInvitation = 'staffInvitation';
  static const String staffSettings = 'staffSettings';
  static const String myWeddingsList = 'myWeddingsList'; // Nouvelle constante explicite

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

            // ================= LISTE DES MARIAGES UTILISATEUR =================
            // ⚠️ IMPORTANT : Définir cette route STATIQUE AVANT la route DYNAMIQUE
            // pour éviter que "my-weddings" ne soit capturé par ":weddingId"
            GoRoute(
              path: 'staff/my-weddings', 
              name: myWeddingsList,
              builder: (c, s) => const MyWeddingsPage(),
            ),

            // ================= ESPACE INVITÉ (GUEST) =================
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
                GoRoute(path: 'invitation', builder: (c, s) => InvitationPage(weddingId: s.pathParameters['weddingId']!)),
                GoRoute(path: 'programme', builder: (c, s) => ProgrammePage(weddingId: s.pathParameters['weddingId']!)),
                GoRoute(path: 'lieu', builder: (c, s) => LieuAccesPage(weddingId: s.pathParameters['weddingId']!)),
                GoRoute(path: 'rsvp', builder: (c, s) => RsvpPage(weddingId: s.pathParameters['weddingId']!)),
                GoRoute(path: 'cadeaux', builder: (c, s) => CadeauxPage(weddingId: s.pathParameters['weddingId']!)),
                GoRoute(path: 'galerie', builder: (c, s) => GaleriePage(weddingId: s.pathParameters['weddingId']!)),
                GoRoute(path: 'livre-or', builder: (c, s) => LivreOrPage(weddingId: s.pathParameters['weddingId']!)),
                GoRoute(path: 'infos', builder: (c, s) => InfosPage(weddingId: s.pathParameters['weddingId']!)),
              ],
            ),

            // ================= DASHBOARD STAFF SPÉCIFIQUE =================
            GoRoute(
              path: 'staff/:weddingId',
              name: staffShell,
              redirect: (context, state) {
                final id = state.pathParameters['weddingId'] ?? '';
                
                // Sécurité supplémentaire si quelqu'un force l'URL /staff/my-weddings
                // Bien que la route statique ci-dessus devrait déjà capter ce cas.
                if (id == 'my-weddings') {
                   return '/$home/staff/my-weddings'; 
                }
                
                if (id.trim().length < 4) return home;
                return null;
              },
              builder: (context, state) {
                final weddingId = state.pathParameters['weddingId']!;
                return StaffShellPage(weddingId: weddingId);
              },
              routes: [
                
                // --- 1. TABLEAU DE BORD PAR DÉFAUT ---
                GoRoute(
                  path: '.', 
                  name: staffDashboard,
                  builder: (c, s) => StaffDashboardPage(weddingId: s.pathParameters['weddingId']!),
                ),

                // --- 2. INVITÉS ---
                GoRoute(
                  path: 'invites',
                  name: staffInvites,
                  builder: (c, s) => GuestListPage(weddingId: s.pathParameters['weddingId']!),
                  routes: [
                    GoRoute(
                      path: 'add',
                      name: staffAddInvite,
                      builder: (c, s) => AddGuestPage(weddingId: s.pathParameters['weddingId']!),
                    ),
                    GoRoute(
                      path: ':guestId/edit',
                      name: staffEditInvite,
                      builder: (c, s) => AddGuestPage(
                        weddingId: s.pathParameters['weddingId']!,
                        editGuestId: s.pathParameters['guestId'],
                      ),
                    ),
                  ],
                ),

                // --- 3. PRESTATAIRES ---
                GoRoute(
                  path: 'prestataires',
                  name: staffPrestataires,
                  builder: (c, s) => VendorsListPage(weddingId: s.pathParameters['weddingId']!),
                  routes: [
                    GoRoute(
                      path: 'add',
                      name: staffAddPrestataire,
                      builder: (c, s) => AddVendorPage(weddingId: s.pathParameters['weddingId']!),
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

                // --- 4. MESSAGES / CHAT ---
                GoRoute(
                  path: 'messages',
                  name: staffMessages,
                  builder: (c, s) => StaffMessagesPage(weddingId: s.pathParameters['weddingId']!),
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

                // --- 5. BUDGET ---
                GoRoute(
                  path: 'budget',
                  name: staffBudget,
                  builder: (c, s) => BudgetPage(weddingId: s.pathParameters['weddingId']!),
                ),

                // --- 6. PAIEMENTS ---
                GoRoute(
                  path: 'paiements',
                  name: staffPaiements,
                  builder: (c, s) => PaymentsPage(weddingId: s.pathParameters['weddingId']!),
                  routes: [
                    GoRoute(
                      path: 'add',
                      name: staffAddPaiement,
                      builder: (c, s) => AddPaymentPage(weddingId: s.pathParameters['weddingId']!),
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

                // --- 7. CHECKLIST / PLANNING ---
                GoRoute(
                  path: 'checklist',
                  name: staffChecklist,
                  builder: (c, s) => ChecklistPage(weddingId: s.pathParameters['weddingId']!),
                  routes: [
                    GoRoute(
                      path: 'add',
                      name: staffAddTask,
                      builder: (c, s) => TaskFormPage(weddingId: s.pathParameters['weddingId']!),
                    ),
                  ],
                ),

                // --- 8. GALERIE ---
                GoRoute(
                  path: 'galerie',
                  name: staffGalerie,
                  builder: (c, s) => GalleryManagementPage(weddingId: s.pathParameters['weddingId']!),
                ),

                // --- 9. LIVRE D'OR ---
                GoRoute(
                  path: 'livre-or',
                  name: staffLivreOr,
                  builder: (c, s) => GuestbookManagementPage(weddingId: s.pathParameters['weddingId']!),
                ),

                // --- 10. INVITATION NUMÉRIQUE (PREVIEW/EDITOR) ---
                GoRoute(
                  path: 'invitation',
                  name: staffInvitation,
                  builder: (c, s) => PreviewInvitationPage(weddingId: s.pathParameters['weddingId']!),
                ),

                // --- 11. PARAMÈTRES (SETTINGS) ---
                GoRoute(
                  path: 'parametres',
                  name: staffSettings,
                  builder: (c, s) => SettingsPage(weddingId: s.pathParameters['weddingId']!),
                ),
              ],
            ),
          ],
        ),
      ];
}
