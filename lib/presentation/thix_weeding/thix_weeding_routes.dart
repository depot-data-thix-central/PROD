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

// STAFF - CORE
import 'pages/staff/staff_shell_page.dart';
import 'pages/staff/staff_dashboard_page.dart';
import 'pages/staff/my_weddings/my_weddings_page.dart';
import 'pages/staff/my_weddings/create_wedding_page.dart';
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
  static const String guestHome = 'guestHome';
  static const String invitation = 'invitation';
  static const String programme = 'programme';
  static const String lieu = 'lieu';
  static const String rsvp = 'rsvp';
  static const String cadeaux = 'cadeaux';
  static const String galerie = 'galerie';
  static const String livreOr = 'livre-or';
  static const String infos = 'infos';

  // STAFF NAMES
  static const String staffMyWeddings = 'staffMyWeddings';
  static const String createWedding = 'createWedding';
  static const String staffDashboard = 'staffDashboard';
  static const String staffInvites = 'staffInvites';
  static const String staffAddInvite = 'staffAddInvite';
  static const String staffPrestataires = 'staffPrestataires';
  static const String staffAddPrestataire = 'staffAddPrestataire';
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
  static const String staffRsvp = 'staffRsvp';
  static const String staffSettings = 'staffSettings';

  static List<RouteBase> get routes => [
        GoRoute(
          path: home,
          name: 'thixWeedingHome',
          pageBuilder: (context, state) => CustomTransitionPage(
            key: state.pageKey,
            child: const ThixWeedingHomePage(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) =>
                FadeTransition(opacity: animation, child: child),
          ),
          routes: [
            // ================= CRÉATION =================
            GoRoute(
              path: 'create',
              name: createWedding,
              builder: (c, s) => const CreateWeddingPage(),
            ),

            // ================= GUEST =================
            GoRoute(
              path: 'guest/:weddingId',
              name: guestHome,
              redirect: (context, state) {
                final id = state.pathParameters['weddingId'] ?? '';
                if (id.trim().length < 4) return home;
                return null;
              },
              pageBuilder: (context, state) {
                final weddingId = state.pathParameters['weddingId']!;
                return CustomTransitionPage(
                  key: state.pageKey,
                  child: GuestHomePage(weddingId: weddingId),
                  transitionsBuilder:
                      (context, animation, secondaryAnimation, child) =>
                          SlideTransition(
                    position: Tween(begin: const Offset(1, 0), end: Offset.zero)
                        .animate(animation),
                    child: child,
                  ),
                );
              },
              routes: [
                GoRoute(
                  path: 'invitation',
                  name: invitation,
                  builder: (c, s) =>
                      InvitationPage(weddingId: s.pathParameters['weddingId']!),
                ),
                GoRoute(
                  path: 'programme',
                  name: programme,
                  builder: (c, s) =>
                      ProgrammePage(weddingId: s.pathParameters['weddingId']!),
                ),
                GoRoute(
                  path: 'lieu',
                  name: lieu,
                  builder: (c, s) =>
                      LieuAccesPage(weddingId: s.pathParameters['weddingId']!),
                ),
                GoRoute(
                  path: 'rsvp',
                  name: rsvp,
                  builder: (c, s) =>
                      RsvpPage(weddingId: s.pathParameters['weddingId']!),
                ),
                GoRoute(
                  path: 'cadeaux',
                  name: cadeaux,
                  builder: (c, s) =>
                      CadeauxPage(weddingId: s.pathParameters['weddingId']!),
                ),
                GoRoute(
                  path: 'galerie',
                  name: galerie,
                  builder: (c, s) =>
                      GaleriePage(weddingId: s.pathParameters['weddingId']!),
                ),
                GoRoute(
                  path: 'livre-or',
                  name: livreOr,
                  builder: (c, s) =>
                      LivreOrPage(weddingId: s.pathParameters['weddingId']!),
                ),
                GoRoute(
                  path: 'infos',
                  name: infos,
                  builder: (c, s) =>
                      InfosPage(weddingId: s.pathParameters['weddingId']!),
                ),
              ],
            ),

            // ================= STAFF =================
            GoRoute(
              path: 'staff/my-weddings',
              name: staffMyWeddings,
              builder: (c, s) => const MyWeddingsPage(),
            ),
            // 👇 ROUTE D'ÉDITION AJOUTÉE ICI
            GoRoute(
              path: 'edit/:weddingId',
              builder: (c, s) => CreateWeddingPage(
                // Si votre CreateWeddingPage gère l'édition via un ID, passez-le ici
              ),
            ),
            GoRoute(
              path: 'staff/:weddingId',
              name: staffDashboard,
              builder: (c, s) => StaffShellPage(
                weddingId: s.pathParameters['weddingId']!,
              ),
              routes: [
                GoRoute(
                  path: 'invites',
                  name: staffInvites,
                  builder: (c, s) => GuestListPage(
                    weddingId: s.pathParameters['weddingId']!,
                  ),
                ),
                GoRoute(
                  path: 'invites/add',
                  name: staffAddInvite,
                  builder: (c, s) => AddGuestPage(
                    weddingId: s.pathParameters['weddingId']!,
                  ),
                ),
                GoRoute(
                  path: 'invites/:guestId/edit',
                  builder: (c, s) => AddGuestPage(
                    weddingId: s.pathParameters['weddingId']!,
                    editGuestId: s.pathParameters['guestId'],
                  ),
                ),
                GoRoute(
                  path: 'prestataires',
                  name: staffPrestataires,
                  builder: (c, s) => VendorsListPage(
                    weddingId: s.pathParameters['weddingId']!,
                  ),
                ),
                GoRoute(
                  path: 'prestataires/add',
                  name: staffAddPrestataire,
                  builder: (c, s) => AddVendorPage(
                    weddingId: s.pathParameters['weddingId']!,
                  ),
                ),
                GoRoute(
                  path: 'prestataires/:vendorId/edit',
                  builder: (c, s) => AddVendorPage(
                    weddingId: s.pathParameters['weddingId']!,
                    editVendorId: s.pathParameters['vendorId'],
                  ),
                ),
                GoRoute(
                  path: 'messages',
                  name: staffMessages,
                  builder: (c, s) => StaffMessagesPage(
                    weddingId: s.pathParameters['weddingId']!,
                  ),
                ),
                GoRoute(
                  path: 'messages/:guestId',
                  name: staffChatDetail,
                  builder: (c, s) => ChatDetailPage(
                    weddingId: s.pathParameters['weddingId']!,
                    guestIdOrName: s.pathParameters['guestId']!,
                  ),
                ),
                GoRoute(
                  path: 'budget',
                  name: staffBudget,
                  builder: (c, s) => BudgetPage(
                    weddingId: s.pathParameters['weddingId']!,
                  ),
                ),
                GoRoute(
                  path: 'paiements',
                  name: staffPaiements,
                  builder: (c, s) => PaymentsPage(
                    weddingId: s.pathParameters['weddingId']!,
                  ),
                ),
                GoRoute(
                  path: 'paiements/add',
                  name: staffAddPaiement,
                  builder: (c, s) => AddPaymentPage(
                    weddingId: s.pathParameters['weddingId']!,
                  ),
                ),
                GoRoute(
                  path: 'paiements/:paymentId',
                  name: staffPaiementDetail,
                  builder: (c, s) => PaymentDetailPage(
                    weddingId: s.pathParameters['weddingId']!,
                    paymentId: s.pathParameters['paymentId']!,
                  ),
                ),
                GoRoute(
                  path: 'checklist',
                  name: staffChecklist,
                  builder: (c, s) => ChecklistPage(
                    weddingId: s.pathParameters['weddingId']!,
                  ),
                ),
                GoRoute(
                  path: 'checklist/add',
                  name: staffAddTask,
                  builder: (c, s) => TaskFormPage(
                    weddingId: s.pathParameters['weddingId']!,
                  ),
                ),
                GoRoute(
                  path: 'galerie',
                  name: staffGalerie,
                  builder: (c, s) => GalleryManagementPage(
                    weddingId: s.pathParameters['weddingId']!,
                  ),
                ),
                GoRoute(
                  path: 'livre-or',
                  name: staffLivreOr,
                  builder: (c, s) => GuestbookManagementPage(
                    weddingId: s.pathParameters['weddingId']!,
                  ),
                ),
                GoRoute(
                  path: 'invitation',
                  name: staffInvitation,
                  builder: (c, s) => PreviewInvitationPage(
                    weddingId: s.pathParameters['weddingId']!,
                  ),
                ),
                GoRoute(
                  path: 'rsvp',
                  name: staffRsvp,
                  builder: (c, s) => GuestListPage(
                    weddingId: s.pathParameters['weddingId']!,
                  ),
                ),
                GoRoute(
                  path: 'parametres',
                  name: staffSettings,
                  builder: (c, s) => SettingsPage(
                    weddingId: s.pathParameters['weddingId']!,
                  ),
                ),
              ],
            ),
          ],
        ),
      ];
}
