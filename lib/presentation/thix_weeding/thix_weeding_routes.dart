// lib/presentation/thix_weeding/thix_weeding_routes.dart
// ============================================================================
// THIX WEDDING ROUTES — v3.6 (PRODUCTION ENTERPRISE + MULTI-ACTIVITÉS)
// ✅ FIX 404 : meal-preferences déplacé DANS guest/:weddingId (weddingId hérité)
// ✅ FIX 404 : route enfant :vendorId (détail prestataire) ajoutée sous prestataires
// ✅ FIX conflit de nom : suppression du bloc "menu" staff orphelon (doublon staffMenu)
// ✅ ✅ Route 16 staff "menu" -> StaffMenuPage (staff_content_pages.dart)
//       (TraiteurMenuStaffPage retiré : import supprimé, plus référencé)
// ✅ NOUVEAU invité : menu, playlist, ma-table (plan 3D), live, annonces,
//    navette, dress-code, faq, remerciements, prestataires, meal-preferences
// ✅ NOUVEAU staff  : playlist, menu (StaffMenuPage), contenu/:kind
// ✅ 🆕 MULTI-ACTIVITÉS PRESTATAIRE (1 compte = N métiers : traiteur, salle…)
//    → routes /provider/activities[/new][/edit/:id] + imports associés
//    → _ProviderOfferFormRoute respecte selectedActivityIdProvider
// ============================================================================
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ✅ Pages menu / préférences
import 'pages/guest/meal_preferences_page.dart';

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
import 'pages/guest/guest_playlist_page.dart';
import 'pages/guest/guest_table_page.dart';
import 'pages/guest/guest_extra_pages.dart';

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
import 'pages/staff/budget/expense_form_page.dart';
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
import 'pages/staff/playlist/staff_playlist_page.dart';

// ✅ CONTENUS INVITÉS (inclut StaffMenuPage + StaffInfoPage)
import 'pages/staff/content/staff_content_pages.dart';

// ✅ ESPACE PRESTATAIRE
import 'pages/provider_portal/provider_portal_shell.dart';
import 'pages/provider_portal/provider_auth_pages.dart';
import 'pages/provider_portal/provider_catalog_pages.dart';
import 'pages/provider_portal/provider_register_simple.dart';
import 'pages/provider_portal/provider_detail_page.dart';
import 'pages/provider_portal/provider_offers_page.dart';
// ✅ NOUVEAU : Multi-activités prestataire (1 compte = N métiers)
import 'pages/provider_portal/my_activities_page.dart';
import 'pages/provider_portal/create_activity_page.dart';
import 'providers/provider_providers.dart';

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
  static const String staffVendorDetail = 'staffVendorDetail';
  static const String staffMessages = 'staffMessages';
  static const String staffChatDetail = 'staffChatDetail';
  static const String staffBudget = 'staffBudget';
  static const String staffBudgetAdd = 'staffBudgetAdd';
  static const String staffBudgetEdit = 'staffBudgetEdit';
  static const String staffPaiements = 'staffPaiements';
  static const String staffAddPaiement = 'staffAddPaiement';
  static const String staffPaiementDetail = 'staffPaiementDetail';
  static const String staffChecklist = 'staffChecklist';
  static const String staffAddTask = 'staffAddTask';
  static const String staffPlanning = 'staffPlanning';
  static const String staffPlanningAdd = 'staffPlanningAdd';
  static const String staffGalerie = 'staffGalerie';
  static const String staffLivreOr = 'staffLivreOr';
  static const String staffInvitation = 'staffInvitation';
  static const String staffInvitationPreview = 'staffInvitationPreview';
  static const String staffSettings = 'staffSettings';
  static const String staffSeating = 'staffSeating';
  static const String staffCadeaux = 'staffCadeaux';
  static const String staffPlaylist = 'staffPlaylist';
  static const String staffMenu = 'staffMenu';
  static const String staffContent = 'staffContent';
  static const String myWeddingsList = 'myWeddingsList';

  // --- NAMES INVITÉ (nouveaux) ---
  static const String guestMenu = 'guestMenu';
  static const String guestMealPreferences = 'guestMealPreferences';
  static const String guestPlaylist = 'guestPlaylist';
  static const String guestTable = 'guestTable';
  static const String guestLive = 'guestLive';
  static const String guestAnnonces = 'guestAnnonces';
  static const String guestNavette = 'guestNavette';
  static const String guestDressCode = 'guestDressCode';
  static const String guestFaq = 'guestFaq';
  static const String guestThanks = 'guestThanks';
  static const String guestPrestataires = 'guestPrestataires';

  // --- NAMES ESPACE PRESTATAIRE ---
  static const String providerAuth = 'providerAuth';
  static const String providerRegister = 'providerRegister';
  static const String providerCatalog = 'providerCatalog';
  static const String providerDetail = 'providerDetail';
  static const String providerDashboard = 'providerDashboard';
  static const String providerOffers = 'providerOffers';
  static const String providerNewOffer = 'providerNewOffer';
  static const String providerEditOffer = 'providerEditOffer';
  static const String providerGallery = 'providerGallery';
  static const String providerReservations = 'providerReservations';
  static const String providerTasks = 'providerTasks';
  static const String providerProfile = 'providerProfile';
  // ✅ NOUVEAU : Multi-activités
  static const String providerActivities = 'providerActivities';
  static const String providerNewActivity = 'providerNewActivity';
  static const String providerEditActivity = 'providerEditActivity';

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

            // ================= LISTE DES MARIAGES =================
            GoRoute(
              path: 'staff/my-weddings',
              name: myWeddingsList,
              builder: (c, s) => const MyWeddingsPage(),
            ),

            // ================================================================
            // ✅ ESPACE PRESTATAIRE (B2B) — SANS AUTH OBLIGATOIRE
            // ================================================================
            GoRoute(
              path: 'provider/auth',
              name: providerAuth,
              builder: (c, s) => const ProviderLoginPage(),
            ),
            GoRoute(
              path: 'provider/register',
              name: providerRegister,
              builder: (c, s) => const ProviderRegisterSimplePage(),
            ),
            GoRoute(
              path: 'provider/catalog',
              name: providerCatalog,
              builder: (c, s) => ProviderCatalogPage(
                initialCategory: s.uri.queryParameters['category'],
              ),
            ),
            GoRoute(
              path: 'provider/detail/:providerId',
              name: providerDetail,
              builder: (c, s) => ProviderDetailPage(
                providerId: s.pathParameters['providerId']!,
              ),
            ),

            // ✅ SHELL + ONGLETS NICHÉS (indices corrigés : Offres=1)
            GoRoute(
              path: 'provider/dashboard',
              name: providerDashboard,
              builder: (c, s) => const ProviderPortalShell(initialTab: 0),
              routes: [
                GoRoute(path: 'offres', name: providerOffers, builder: (c, s) => const ProviderPortalShell(initialTab: 1)),
                GoRoute(path: 'galerie', name: providerGallery, builder: (c, s) => const ProviderPortalShell(initialTab: 2)),
                GoRoute(path: 'reservations', name: providerReservations, builder: (c, s) => const ProviderPortalShell(initialTab: 3)),
                GoRoute(path: 'taches', name: providerTasks, builder: (c, s) => const ProviderPortalShell(initialTab: 4)),
                GoRoute(path: 'profil', name: providerProfile, builder: (c, s) => const ProviderPortalShell(initialTab: 5)),
              ],
            ),

            // ✅ ALIAS PLATS (utilisés par les boutons du dashboard)
            GoRoute(path: 'provider/offers', builder: (c, s) => const ProviderPortalShell(initialTab: 1)),
            GoRoute(path: 'provider/gallery', builder: (c, s) => const ProviderPortalShell(initialTab: 2)),
            GoRoute(path: 'provider/reservations', builder: (c, s) => const ProviderPortalShell(initialTab: 3)),
            GoRoute(path: 'provider/tasks', builder: (c, s) => const ProviderPortalShell(initialTab: 4)),
            GoRoute(path: 'provider/profile', builder: (c, s) => const ProviderPortalShell(initialTab: 5)),

            // ✅ FORMULAIRE DE CRÉATION / ÉDITION D'OFFRE
            GoRoute(
              path: 'provider/offers/new',
              name: providerNewOffer,
              builder: (c, s) => const _ProviderOfferFormRoute(editId: null),
            ),
            GoRoute(
              path: 'provider/offers/edit/:offerId',
              name: providerEditOffer,
              builder: (c, s) => _ProviderOfferFormRoute(editId: s.pathParameters['offerId']),
            ),

            // ═══════════════════════════════════════════════════════════════
            // ✅ NOUVEAU : MULTI-ACTIVITÉS PRESTATAIRE
            //    1 compte (owner_id) = plusieurs métiers (traiteur, salle, DJ…)
            //    → calqué sur /staff/my-weddings + /create
            // ═══════════════════════════════════════════════════════════════
            GoRoute(
              path: 'provider/activities',
              name: providerActivities,
              builder: (c, s) => const MyActivitiesPage(),
            ),
            GoRoute(
              path: 'provider/activities/new',
              name: providerNewActivity,
              builder: (c, s) => const CreateActivityPage(),
            ),
            GoRoute(
              path: 'provider/activities/edit/:activityId',
              name: providerEditActivity,
              builder: (c, s) => CreateActivityPage(
                editId: s.pathParameters['activityId'],
              ),
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
                // ✅ guestId : lien direct vers l'invitation d'un invité (?guest=<id>)
                GoRoute(
                  path: 'invitation',
                  builder: (c, s) => InvitationPage(
                    weddingId: s.pathParameters['weddingId']!,
                    guestId: s.uri.queryParameters['guest'],
                  ),
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

                // ✅ NOUVEAU : rubriques du menu d'accueil invité
                GoRoute(
                  path: 'menu',
                  name: guestMenu,
                  builder: (c, s) =>
                      GuestMenuPage(weddingId: s.pathParameters['weddingId']!),
                ),
                // ✅ FIX 404 : préférences repas (choix des plats) — ICI, enfant de guest/:weddingId
                GoRoute(
                  path: 'meal-preferences',
                  name: guestMealPreferences,
                  builder: (c, s) => MealPreferencesPage(
                    weddingId: s.pathParameters['weddingId']!,
                  ),
                ),
                GoRoute(
                  path: 'playlist',
                  name: guestPlaylist,
                  builder: (c, s) =>
                      GuestPlaylistPage(weddingId: s.pathParameters['weddingId']!),
                ),
                GoRoute(
                  path: 'ma-table',
                  name: guestTable,
                  builder: (c, s) =>
                      GuestTablePage(weddingId: s.pathParameters['weddingId']!),
                ),
                GoRoute(
                  path: 'live',
                  name: guestLive,
                  builder: (c, s) => GuestInfoPage(
                      weddingId: s.pathParameters['weddingId']!, kind: 'live'),
                ),
                GoRoute(
                  path: 'annonces',
                  name: guestAnnonces,
                  builder: (c, s) => GuestAnnoncesPage(
                      weddingId: s.pathParameters['weddingId']!),
                ),
                GoRoute(
                  path: 'navette',
                  name: guestNavette,
                  builder: (c, s) => GuestInfoPage(
                      weddingId: s.pathParameters['weddingId']!, kind: 'navette'),
                ),
                GoRoute(
                  path: 'dress-code',
                  name: guestDressCode,
                  builder: (c, s) => GuestInfoPage(
                      weddingId: s.pathParameters['weddingId']!, kind: 'dress_code'),
                ),
                GoRoute(
                  path: 'faq',
                  name: guestFaq,
                  builder: (c, s) => GuestInfoPage(
                      weddingId: s.pathParameters['weddingId']!, kind: 'faq'),
                ),
                GoRoute(
                  path: 'remerciements',
                  name: guestThanks,
                  builder: (c, s) => GuestInfoPage(
                      weddingId: s.pathParameters['weddingId']!, kind: 'thanks'),
                ),
                GoRoute(
                  path: 'prestataires',
                  name: guestPrestataires,
                  builder: (c, s) => GuestPrestatairesPage(
                      weddingId: s.pathParameters['weddingId']!),
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
                    // ✅ FIX : /invites/add?edit=<guestId> → mode modification
                    GoRoute(
                      path: 'add',
                      name: staffAddInvite,
                      builder: (c, s) => AddGuestPage(
                        weddingId: s.pathParameters['weddingId']!,
                        editGuestId: s.uri.queryParameters['edit'],
                      ),
                    ),
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

                // 3. PRESTATAIRES (staff)
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
                    // ✅ FIX 404 : détail prestataire /staff/{id}/prestataires/{vendorId}
                    //    -> fallback formulaire pré-rempli (seul écran importé)
                    GoRoute(
                      path: ':vendorId',
                      name: staffVendorDetail,
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
                    // ✅ FIX : le nom passé en extra arrive dans le chat
                    GoRoute(
                      path: ':guestId',
                      name: staffChatDetail,
                      builder: (c, s) => ChatDetailPage(
                        weddingId: s.pathParameters['weddingId']!,
                        guestIdOrName: s.pathParameters['guestId']!,
                        guestName: s.extra is String ? s.extra as String : null,
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
                  routes: [
                    GoRoute(
                      path: 'add',
                      name: staffBudgetAdd,
                      builder: (c, s) => ExpenseFormPage(
                          weddingId: s.pathParameters['weddingId']!),
                    ),
                    GoRoute(
                      path: ':expenseId/edit',
                      name: staffBudgetEdit,
                      builder: (c, s) => ExpenseFormPage(
                        weddingId: s.pathParameters['weddingId']!,
                        editExpenseId: s.pathParameters['expenseId'],
                      ),
                    ),
                  ],
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

                // 8. PLANNING
                GoRoute(
                  path: 'planning',
                  name: staffPlanning,
                  builder: (c, s) => PlanningPage(
                      weddingId: s.pathParameters['weddingId']!),
                  routes: [
                    GoRoute(
                      path: 'add',
                      name: staffPlanningAdd,
                      builder: (c, s) => TaskFormPage(
                          weddingId: s.pathParameters['weddingId']!),
                    ),
                  ],
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
                  routes: [
                    GoRoute(
                      path: 'preview',
                      name: staffInvitationPreview,
                      builder: (c, s) => PreviewInvitationPage(
                          weddingId: s.pathParameters['weddingId']!),
                    ),
                  ],
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

                // ✅ 15. PLAYLIST (staff)
                GoRoute(
                  path: 'playlist',
                  name: staffPlaylist,
                  builder: (c, s) => StaffPlaylistPage(
                      weddingId: s.pathParameters['weddingId']!),
                ),

                // ✅ 16. MENU / VALIDATION PLATS (staff)
                //    ✅ Utilise StaffMenuPage (staff_content_pages.dart)
                //    → 3 onglets : Menu | Suggestions | Résultats
                //    (remplace l'ancien TraiteurMenuStaffPage retiré)
                GoRoute(
                  path: 'menu',
                  name: staffMenu,
                  builder: (c, s) => StaffMenuPage(
                      weddingId: s.pathParameters['weddingId']!),
                ),

                // ✅ 17. CONTENUS INVITÉS : navette, dress_code, faq, thanks, live
                GoRoute(
                  path: 'contenu/:kind',
                  name: staffContent,
                  builder: (c, s) => StaffInfoPage(
                    weddingId: s.pathParameters['weddingId']!,
                    kind: s.pathParameters['kind']!,
                  ),
                ),
              ],
            ),
          ],
        ),
      ];
}

// ═══════════════════════════════════════════════════════════════════════════
// WIDGET ROUTE POUR LE FORMULAIRE D'OFFRE (résolution dynamique du provider)
// ✅ RESPECTE selectedActivityIdProvider (multi-activités)
// ═══════════════════════════════════════════════════════════════════════════
class _ProviderOfferFormRoute extends ConsumerWidget {
  final String? editId;
  const _ProviderOfferFormRoute({this.editId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = Supabase.instance.client.auth.currentUser;

    if (user == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFFAFAFA),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline, size: 48, color: Colors.grey),
              const SizedBox(height: 16),
              const Text('Connexion requise', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => context.push('/thix-weeding/auth/login'),
                child: const Text('Se connecter'),
              ),
            ],
          ),
        ),
      );
    }

    // ✅ myProviderProvider(ownerId) renvoie DÉJÀ l'activité sélectionnée
    //    (fallback principale) grâce à selectedActivityIdProvider interne.
    final providerAsync = ref.watch(myProviderProvider(user.id));

    return providerAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        body: Center(child: Text('Erreur: $e')),
      ),
      data: (provider) {
        if (provider == null) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.storefront_outlined, size: 48, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('Aucun profil prestataire', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () => context.go('/thix-weeding/provider/register'),
                    child: const Text('Créer mon profil'),
                  ),
                ],
              ),
            ),
          );
        }

        // Mode édition : charger l'offre existante si nécessaire
        if (editId != null) {
          final offersAsync = ref.watch(providerOffersProvider(provider.id));
          return offersAsync.when(
            loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
            error: (e, _) => Scaffold(body: Center(child: Text('Erreur chargement offre: $e'))),
            data: (offers) {
              final existing = offers.where((o) => o.id == editId).firstOrNull;
              return ProviderOfferFormPage(provider: provider, existing: existing);
            },
          );
        }

        // Mode création
        return ProviderOfferFormPage(provider: provider);
      },
    );
  }
}
