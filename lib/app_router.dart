// lib/app_router.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart' as app_provider;

// === CORE, AUTH & MAIN ===
import 'package:thix_id/supabase/supabase_config.dart';
import 'package:thix_id/services/network_service.dart';
import 'package:thix_id/services/user_service.dart';
import 'package:thix_id/auth/auth_controller.dart';
import 'package:thix_id/models/account_type.dart';
import 'package:thix_id/nav.dart';
import 'package:thix_id/presentation/splash/thix_id_start_page.dart';
import 'package:thix_id/presentation/auth/scanner_activation_screen.dart'; 
import 'package:thix_id/presentation/home/home_page.dart';
import 'package:thix_id/presentation/auth/login_page.dart';
import 'package:thix_id/presentation/auth/personal_registration_page.dart';
import 'package:thix_id/presentation/auth/enterprise_registration_page.dart';
import 'package:thix_id/presentation/payment/payment_gateway_page.dart';
import 'package:thix_id/presentation/payment/activation_receipt_page.dart';
import 'package:thix_id/presentation/profile/public_profile_page.dart' as public_profile;
import 'package:thix_id/presentation/dashboard/user_dashboard_page.dart';
import 'package:thix_id/presentation/enterprise/enterprise_dashboard_page.dart';
import 'package:thix_id/presentation/enterprise/enterprise_portal_page.dart';
import 'package:thix_id/presentation/enterprise/enterprise_dashboard_shell_page.dart';
import 'package:thix_id/presentation/vault/document_vault_page.dart';
import 'package:thix_id/presentation/settings/settings_page.dart';
import 'package:thix_id/presentation/common/main_app_shell.dart';
import 'package:thix_id/presentation/certification/certification_tiers_page.dart';

// === THIX CHAT ===
import 'package:thix_id/models/chat/chat_conversation.dart';
import 'package:thix_id/presentation/chat/chat_list_page.dart';
import 'package:thix_id/presentation/chat/chat_screen.dart' as ThixChat;
import 'package:thix_id/presentation/chat/new_conversation_page.dart';
import 'package:thix_id/presentation/chat/screens/group_create_page.dart';
import 'package:thix_id/presentation/chat/screens/group_info_page.dart';
import 'package:thix_id/presentation/chat/screens/group_settings_page.dart';
import 'package:thix_id/presentation/chat/escalation/screens/escalate_conversation_page.dart';
import 'package:thix_id/presentation/chat/escalation/screens/handle_escalation_page.dart';
import 'package:thix_id/presentation/chat/escalation/screens/escalation_history_page.dart';
import 'package:thix_id/presentation/chat/escalation/screens/escalation_dashboard_page.dart';
import 'package:thix_id/presentation/chat/escalation/models/escalation_level.dart';
import 'package:thix_id/presentation/chat/escalation/screens/received_escalations_page.dart';
import 'package:thix_id/presentation/chat/call/call_page.dart';
import 'package:thix_id/presentation/chat/call/incoming_call_page.dart';
import 'package:thix_id/models/chat/call_invite.dart';
import 'package:thix_id/models/chat/call_status.dart';
import 'package:thix_id/presentation/chat/connections_page.dart';
import 'package:thix_id/presentation/chat/profile/chat_profile_page.dart';
import 'package:thix_id/presentation/chat/settings/chat_settings_page.dart';
import 'package:thix_id/presentation/chat/settings/chat_appearance_settings.dart';
import 'package:thix_id/presentation/chat/settings/chat_privacy_settings.dart';
import 'package:thix_id/presentation/chat/settings/chat_notification_settings.dart';
import 'package:thix_id/presentation/chat/settings/chat_data_settings.dart';
import 'package:thix_id/presentation/chat/call/call_history_page.dart';

// === THIX NETWORK ===
import 'package:thix_id/presentation/network/network_pro_home.dart';
import 'package:thix_id/presentation/network/search_network_page.dart';
import 'package:thix_id/presentation/network/notifications/notifications_page.dart';
import 'package:thix_id/presentation/network/messages/conversations_list.dart';
import 'package:thix_id/presentation/network/messages/chat_screen.dart' as network_chat;
import 'package:thix_id/presentation/network/connections_list_page.dart';
import 'package:thix_id/presentation/network/community_detail_page.dart';
import 'package:thix_id/presentation/network/communities_list_page.dart';
import 'package:thix_id/presentation/network/create_community_page.dart';
import 'package:thix_id/presentation/network/post_detail_page.dart';
import 'package:thix_id/presentation/network/profile_page.dart';
import 'package:thix_id/presentation/network/profile_settings_page.dart';
import 'package:thix_id/presentation/network/blocked_users_page.dart';
import 'package:thix_id/presentation/network/discover_tab.dart';
import 'package:thix_id/presentation/network/story_viewer_screen.dart';
import 'package:thix_id/presentation/network/comments_page.dart';
import 'package:thix_id/presentation/network/hashtag_page.dart';
import 'package:thix_id/presentation/network/followers_list_page.dart';
import 'package:thix_id/presentation/network/following_list_page.dart';

// === THIX MEDIA ===
import 'package:thix_id/presentation/thix_media/create_post_page.dart';
import 'package:thix_id/presentation/thix_media/user_profile_page.dart';
import 'package:thix_id/presentation/thix_media/thix_media_page.dart';
import 'package:thix_id/presentation/thix_media/video_player_page.dart';
import 'package:thix_id/presentation/thix_media/admin/thix_media_admin_page.dart';

// === THIX MARKET ===
import 'package:thix_id/presentation/thix_market/pages/market_home_page.dart';
import 'package:thix_id/presentation/thix_market/pages/search_page.dart' as marketSearch;
import 'package:thix_id/presentation/thix_market/pages/shops_page.dart';
import 'package:thix_id/presentation/thix_market/pages/buy_page.dart';
import 'package:thix_id/presentation/thix_market/pages/sell_page.dart';
import 'package:thix_id/presentation/thix_market/pages/messages_page.dart';
import 'package:thix_id/presentation/thix_market/pages/live_page.dart';
import 'package:thix_id/presentation/thix_market/pages/my_activity_page.dart';
import 'package:thix_id/presentation/thix_market/pages/market_settings_page.dart';
import 'package:thix_id/presentation/thix_market/pages/help_support_page.dart';
import 'package:thix_id/presentation/thix_market/pages/product_detail_page.dart';
import 'package:thix_id/presentation/thix_market/pages/product_comparator_page.dart';
import 'package:thix_id/presentation/thix_market/pages/price_alerts_page.dart';
import 'package:thix_id/presentation/thix_market/pages/wishlist_page.dart';
import 'package:thix_id/presentation/thix_market/cart/cart_page.dart';
import 'package:thix_id/presentation/thix_market/checkout/checkout_page.dart';
import 'package:thix_id/presentation/thix_market/delivery/delivery_tracking_page.dart' as market_delivery;
import 'package:thix_id/presentation/thix_market/pages/order_history_page.dart';
import 'package:thix_id/presentation/thix_market/pages/order_detail_page.dart';
import 'package:thix_id/presentation/thix_market/pages/create_shop_page.dart';
import 'package:thix_id/presentation/thix_market/pages/manage_shop_page.dart';
import 'package:thix_id/presentation/thix_market/pages/shop_statistics_page.dart';
import 'package:thix_id/presentation/thix_market/pages/publish_announcement_page.dart';
import 'package:thix_id/presentation/thix_market/pages/edit_announcement_page.dart';
import 'package:thix_id/presentation/thix_market/pages/live_stream_page.dart';
import 'package:thix_id/presentation/thix_market/pages/create_live_page.dart';
import 'package:thix_id/presentation/thix_market/pages/live_replay_page.dart';
import 'package:thix_id/presentation/thix_market/pages/auction_page.dart';
import 'package:thix_id/presentation/thix_market/pages/chat_page.dart';
import 'package:thix_id/presentation/thix_market/pages/dispute_detail_page.dart';
import 'package:thix_id/presentation/thix_market/pages/notification_page.dart';
import 'package:thix_id/presentation/thix_market/pages/shop_detail_page.dart';
import 'package:thix_id/presentation/thix_market/vendor/vendor_dashboard.dart';
import 'package:thix_id/presentation/thix_market/vendor/delivery_management_page.dart';
import 'package:thix_id/presentation/thix_market/vendor/vendor_orders_page.dart';

// === THIX SANTE ===
import 'package:thix_id/presentation/thix_sante/patient/patient_dashboard_page.dart';
import 'package:thix_id/presentation/thix_sante/patient/screens/mon_medecin_traitant_page.dart';
import 'package:thix_id/presentation/thix_sante/patient/screens/dossier_famille_page.dart';
import 'package:thix_id/presentation/thix_sante/patient/screens/second_avis_page.dart';
import 'package:thix_id/presentation/thix_sante/patient/screens/consulter_medecin_page.dart';
import 'package:thix_id/presentation/thix_sante/patient/screens/dossier_medical_page.dart';
import 'package:thix_id/presentation/thix_sante/patient/screens/resultats_examens_page.dart';
import 'package:thix_id/presentation/thix_sante/patient/screens/mes_ordonnances_page.dart';
import 'package:thix_id/presentation/thix_sante/patient/screens/trouver_hopital_page.dart';
import 'package:thix_id/presentation/thix_sante/patient/screens/trouver_medicament_page.dart';
import 'package:thix_id/presentation/thix_sante/patient/screens/pharmacies_proches_page.dart';
import 'package:thix_id/presentation/thix_sante/patient/screens/urgences_proches_page.dart';
import 'package:thix_id/presentation/thix_sante/patient/screens/prendre_rdv_page.dart';
import 'package:thix_id/presentation/thix_sante/patient/screens/teleconsultation_page.dart';
import 'package:thix_id/presentation/thix_sante/patient/screens/assistant_ia_page.dart';
import 'package:thix_id/presentation/thix_sante/patient/screens/dossier_partage_page.dart';
import 'package:thix_id/presentation/thix_sante/patient/screens/epidemies_page.dart';
import 'package:thix_id/presentation/thix_sante/patient/screens/don_sang_page.dart';
import 'package:thix_id/presentation/thix_sante/patient/screens/nutrition_page.dart';
import 'package:thix_id/presentation/thix_sante/patient/screens/activite_physique_page.dart';
import 'package:thix_id/presentation/thix_sante/patient/screens/gestion_stress_page.dart';
import 'package:thix_id/presentation/thix_sante/patient/screens/assurance_sante_page.dart';
import 'package:thix_id/presentation/thix_sante/patient/screens/plus_services_page.dart';
import 'package:thix_id/presentation/thix_sante/patient/screens/analyse_predictive_page.dart';
import 'package:thix_id/presentation/thix_sante/patient/screens/bien_etre_mental_page.dart';
import 'package:thix_id/presentation/thix_sante/patient/screens/sante_enfants_page.dart';
import 'package:thix_id/presentation/thix_sante/patient/screens/carnet_vaccination_page.dart';
import 'package:thix_id/presentation/thix_sante/patient/screens/suivi_grossesse_page.dart';

// === THIX RESERVATION (BUS) ===
import 'package:thix_id/presentation/thix_reservation/thix_reservation_home_page.dart';
import 'package:thix_id/presentation/thix_reservation/bus/pages/client/bus_home_page.dart';
import 'package:thix_id/presentation/thix_reservation/bus/pages/client/bus_search_result_page.dart';
import 'package:thix_id/presentation/thix_reservation/bus/pages/client/bus_trip_detail_page.dart';
import 'package:thix_id/presentation/thix_reservation/bus/pages/client/bus_seat_selection_page.dart';
import 'package:thix_id/presentation/thix_reservation/bus/pages/client/bus_payment_page.dart';
import 'package:thix_id/presentation/thix_reservation/bus/pages/client/bus_ticket_page.dart';
import 'package:thix_id/presentation/thix_reservation/bus/pages/agency/agency_onboarding_page.dart';
import 'package:thix_id/presentation/thix_reservation/bus/pages/agency/agency_dashboard_page.dart';
import 'package:thix_id/presentation/thix_reservation/bus/pages/agency/agency_create_trip_page.dart';
import 'package:thix_id/presentation/thix_reservation/bus/pages/agency/agency_qr_scan_page.dart';
import 'package:thix_id/presentation/thix_reservation/bus/pages/agency/agency_seats_page.dart';
import 'package:thix_id/presentation/thix_reservation/bus/data/models/bus_trip_model.dart';
import 'package:thix_id/presentation/thix_reservation/bus/data/models/booking_model.dart';
// === THIX RESERVATION (DELIVERY) ===
import 'package:thix_id/presentation/thix_reservation/delivery/pages/client/delivery_home_page.dart';
import 'package:thix_id/presentation/thix_reservation/delivery/pages/client/delivery_checkout_page.dart';
import 'package:thix_id/presentation/thix_reservation/delivery/pages/client/delivery_tracking_page.dart' as delivery_tracking;
import 'package:thix_id/presentation/thix_reservation/delivery/pages/client/delivery_history_page.dart';
import 'package:thix_id/presentation/thix_reservation/delivery/pages/admin/delivery_admin_dashboard_page.dart';
import 'package:thix_id/presentation/thix_reservation/delivery/pages/admin/delivery_admin_routes_page.dart';
import 'package:thix_id/presentation/thix_reservation/delivery/pages/admin/delivery_admin_shipments_page.dart';
import 'package:thix_id/presentation/thix_reservation/delivery/pages/admin/delivery_admin_scan_page.dart';
import 'package:thix_id/presentation/thix_reservation/delivery/providers/delivery_client_provider.dart';
import 'package:thix_id/presentation/thix_reservation/delivery/providers/delivery_admin_provider.dart';

// === THIX EVENT ===
import 'package:thix_id/presentation/thix_event/thix_event_home.dart';
import 'package:thix_id/presentation/thix_event/event_detail_page.dart';
import 'package:thix_id/presentation/thix_event/event_search_page.dart';
import 'package:thix_id/presentation/thix_event/event_category_page.dart';
import 'package:thix_id/presentation/thix_event/event_reservation_page.dart';
import 'package:thix_id/presentation/thix_event/my_tickets_page.dart';
import 'package:thix_id/presentation/thix_event/favorite_events_page.dart';
import 'package:thix_id/presentation/thix_event/seat_selection_page.dart';
import 'package:thix_id/presentation/thix_event/waiting_queue_page.dart';
import 'package:thix_id/presentation/thix_event/admin/admin_dashboard.dart';
import 'package:thix_id/presentation/thix_event/admin/pages/events/event_list_admin_page.dart';
import 'package:thix_id/presentation/thix_event/admin/pages/events/event_create_edit_page.dart';
import 'package:thix_id/presentation/thix_event/admin/pages/seats/seat_map_admin_page.dart';
import 'package:thix_id/presentation/thix_event/admin/pages/bookings/booking_management_page.dart';
import 'package:thix_id/presentation/thix_event/admin/pages/bookings/waiting_queue_page.dart' as admin_queue;
import 'package:thix_id/presentation/thix_event/admin/pages/limits/booking_limits_page.dart';
import 'package:thix_id/presentation/thix_event/admin/pages/analytics/analytics_page.dart';
import 'package:thix_id/presentation/thix_event/event_payment_page.dart';
import 'package:thix_id/presentation/thix_event/event_ticket_page.dart';
import 'package:thix_id/models/event_model.dart'; 

// === THIX INFO ===
import 'package:thix_id/presentation/thix_info/thix_info_home.dart';
import 'package:thix_id/presentation/thix_info/article_detail_page.dart' as thixInfoArticle;
import 'package:thix_id/presentation/thix_info/search_page.dart' as infoSearch;
import 'package:thix_id/presentation/thix_info/category_articles_page.dart';
import 'package:thix_id/presentation/thix_info/saved_articles_page.dart';
import 'package:thix_id/presentation/thix_info/breaking_news_page.dart';

// === JOBS & OPPORTUNITIES ===
import 'package:thix_id/presentation/jobs/jobs_page.dart';
import 'package:thix_id/presentation/jobs/job_apply_page.dart';
import 'package:thix_id/presentation/jobs/job_details_page.dart';
import 'package:thix_id/presentation/jobs/job_dashboard_page.dart';
import 'package:thix_id/presentation/recruiter/recruiter_portal_page.dart';
import 'package:thix_id/presentation/opportunities/opportunities_page.dart';
import 'package:thix_id/presentation/opportunities/opportunity_apply_page.dart';
import 'package:thix_id/presentation/opportunities/opportunity_details_page.dart';
import 'package:thix_id/presentation/opportunities/opportunity_admin_dashboard.dart';
import 'package:thix_id/presentation/opportunities/opportunity_admin_page.dart';

// === MON PAYS ===
import 'package:thix_id/presentation/mon_pays/mon_pays_page.dart';
import 'package:thix_id/presentation/mon_pays/pages/authorities/authorities_page.dart';
import 'package:thix_id/presentation/mon_pays/pages/authorities/authority_profile_page.dart';
import 'package:thix_id/presentation/mon_pays/admin/admin_dashboard_page.dart';
import 'package:thix_id/presentation/mon_pays/admin/admin_authorities_page.dart';
import 'package:thix_id/presentation/mon_pays/admin/admin_authority_form_page.dart';
import 'package:thix_id/presentation/mon_pays/admin/admin_articles_page.dart' as monpays_articles;
import 'package:thix_id/presentation/mon_pays/admin/admin_article_form_page.dart' as monpays_form;
import 'package:thix_id/presentation/mon_pays/pages/laws/laws_page.dart';
import 'package:thix_id/presentation/mon_pays/pages/laws/article_type_page.dart';
import 'package:thix_id/presentation/mon_pays/pages/laws/article_detail_page.dart' as monPaysArticle;
import 'package:thix_id/presentation/mon_pays/models/article.dart';
import 'package:thix_id/presentation/mon_pays/pages/provinces/provinces_page.dart';
import 'package:thix_id/presentation/mon_pays/pages/provinces/province_detail_page.dart';
import 'package:thix_id/presentation/mon_pays/admin/admin_provinces_page.dart';
import 'package:thix_id/presentation/mon_pays/admin/admin_province_form_page.dart';
import 'package:thix_id/presentation/mon_pays/admin/admin_government_form_page.dart';
import 'package:thix_id/presentation/mon_pays/admin/admin_economic_form_page.dart';
import 'package:thix_id/presentation/mon_pays/admin/admin_budget_form_page.dart';
import 'package:thix_id/presentation/mon_pays/admin/admin_tourism_form_page.dart';
import 'package:thix_id/presentation/mon_pays/admin/admin_emergency_form_page.dart';
import 'package:thix_id/presentation/mon_pays/admin/admin_administrative_form_page.dart';
import 'package:thix_id/presentation/mon_pays/admin/admin_achievement_form_page.dart';
import 'package:thix_id/presentation/mon_pays/admin/admin_media_form_page.dart';
import 'package:thix_id/presentation/mon_pays/models/province.dart';

// === THIX RETROUVE & IA ===
import 'package:thix_id/presentation/thix_retrouve/thix_retrouve_screen.dart';
import 'package:thix_id/presentation/thix_retrouve/pages/object_detail_page.dart';
import 'package:thix_id/presentation/thix_retrouve/pages/ai_match_page.dart';
import 'package:thix_id/presentation/thix_retrouve/pages/mes_recherches_page.dart';
import 'package:thix_id/presentation/thix_retrouve/pages/declarer_objet_page.dart';
import 'package:thix_id/presentation/thix_retrouve/pages/carte_signalements_page.dart';
import 'package:thix_id/presentation/thix_retrouve/models/objet_model.dart';
import 'package:thix_id/presentation/thix_ia/pages/thix_ia_home_page.dart';
import 'package:thix_id/presentation/thix_sos/thix_sos_screen.dart';
import 'package:thix_id/presentation/thix_sos/pages/sos_actif_page.dart';
import 'package:thix_id/presentation/thix_sos/pages/mes_secours_page.dart';
import 'package:thix_id/presentation/thix_sos/pages/ajouter_secours_page.dart';
import 'package:thix_id/presentation/thix_sos/pages/mes_incidents_page.dart';
import 'package:thix_id/presentation/thix_sos/pages/sos_pin_page.dart';
import 'package:thix_id/presentation/thix_sos/pages/chambre_crise_page.dart';
import 'package:thix_id/presentation/thix_recherche/thix_recherche_screen.dart';
import 'package:thix_id/presentation/thix_recherche/pages/detail_personne_page.dart';
import 'package:thix_id/presentation/thix_recherche/pages/signaler_page.dart';
import 'package:thix_id/presentation/thix_recherche/pages/creer_alerte_page.dart';
import 'package:thix_id/presentation/thix_recherche/pages/mes_alertes_page.dart';
import 'package:thix_id/presentation/thix_sos/pages/chambre_crise_secours_page.dart';
// === ADMIN SYSTEM GLOBAL ===
import 'package:thix_id/presentation/admin/admin_page.dart';
import 'package:thix_id/presentation/admin/admin_routes.dart';
import 'package:thix_id/presentation/admin/pages/admin_media_page.dart';
import 'package:thix_id/presentation/admin/admin_home_page.dart' as thix_admin;
import 'package:thix_id/presentation/admin/admin_articles_list_page.dart' as thix_admin_list;
import 'package:thix_id/presentation/admin/admin_article_form_page.dart' as thix_admin_form;

// === OTHER MODULES ===
import 'package:thix_id/presentation/education/education_routes.dart';
import 'package:thix_id/presentation/thix_money/thix_money_router.dart';
import 'package:thix_id/presentation/thix_weeding/thix_weeding_routes.dart';
import 'package:thix_id/presentation/thix_home_swipe_screen.dart';

// === THIX IA NEW MODULE - 15 PAGES + 21 WIDGETS - FULL PROD ===
import 'package:thix_id/presentation/thix_ia/thix_ia_routes.dart'; // <-- AJOUT THIX IA

class NoTransitionPage<T> extends Page<T> {
  final Widget child;
  const NoTransitionPage({required this.child, super.key});
  @override
  Route<T> createRoute(BuildContext context) => PageRouteBuilder<T>(
        settings: this,
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
        pageBuilder: (c, a, s) => child,
        transitionsBuilder: (c, a, s, ch) => ch,
      );
}

class AppRouter {
  static GoRouter create(
    AuthController auth, {
    Listenable? extraRefreshListenable,
    GlobalKey<NavigatorState>? navigatorKey,
  }) {
    final refresh = extraRefreshListenable ?? auth;
    return GoRouter(
      navigatorKey: navigatorKey,
      initialLocation: AppRoutes.home,
      refreshListenable: refresh,
      errorBuilder: (context, state) => Scaffold(
        backgroundColor: const Color(0xFF0B3D91),
        body: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('THIX ID CENTRAL', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 20)),
          const SizedBox(height: 8),
          Text('Route non trouvée: ${state.matchedLocation}', style: const TextStyle(color: Colors.white70)),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: () => context.go(AppRoutes.home), child: const Text('Accueil')),
        ])),
      ),
                              redirect: (context, state) async {
  try {
    final loc = state.matchedLocation;
    final isLoginPage = loc == AppRoutes.login;
    final isStartPage = loc == AppRoutes.start;
    final isRegPage = loc == AppRoutes.personalReg || loc == AppRoutes.enterpriseReg;

    final isPublic = isStartPage ||
                    isLoginPage ||
                    isRegPage ||
                    loc == AppRoutes.publicProfile ||
                    loc == AppRoutes.jobs ||
                    loc == AppRoutes.opportunities ||
                    loc == AppRoutes.education ||
                    loc == AppRoutes.trainingHome ||
                    loc.startsWith('${AppRoutes.trainingDetailsBasePath}/') ||
                    loc == AppRoutes.monPays ||
                    loc.startsWith('${AppRoutes.monPays}/') ||
                    loc.startsWith('/thix-event') ||
                    loc.startsWith('/thix-retrouve') ||
                    loc.startsWith('/thix-weeding') ||
                    loc.startsWith('/thix-reservation/delivery');

    final logged = auth.isAuthenticated;
    final currentUser = auth.currentUser;
    final status = currentUser?.registrationStatus?.toLowerCase() ?? '';

    // ✅ RÈGLE STRICTE : Le compte est actif UNIQUEMENT si le statut exact est 'active'
    final isAccountActive = currentUser != null && (status == 'active' || status == 'completed');

    // Cas 1 : Non connecté
    if (!logged) {
      return isPublic ? null : AppRoutes.login;
    }

    // ✅ NOUVEAU Cas 2 : Connecté et se trouve sur la page Login ou Start
    if (logged && (isLoginPage || isStartPage)) {
      if (isAccountActive) return AppRoutes.userDashboard;
      return null;
    }

    // Cas 3 : Connecté sur page d'inscription avec compte ACTIVÉ
    if (logged && isRegPage && isAccountActive) {
      if (state.uri.queryParameters['step'] == '3') return null;
      return AppRoutes.userDashboard;
    }

    // ✅ Cas 4 CORRIGÉ : Connecté mais compte NON ACTIVÉ
    if (logged && !isRegPage && !isLoginPage && !isStartPage && !isAccountActive && currentUser?.registrationStatus != null) {
      // Si l'utilisateur est déjà en train de compléter son inscription
      // dans CETTE session (venant d'une page interne), on le renvoie à l'étape.
      // Mais si c'est un lancement à froid de l'app (home au démarrage),
      // on déconnecte la session périmée au lieu de forcer l'inscription en boucle.
      if (loc == AppRoutes.home) {
        await auth.signOut();
        return AppRoutes.login;
      }

      if (status == 'draft_step1') {
        return '${AppRoutes.personalReg}?step=1';
      } else {
        return '${AppRoutes.personalReg}?step=2';
      }
    }

    // Cas par défaut (Navigation normale dans l'app)
    return null;
  } catch (e) {
    debugPrint('GoRouter redirect error: $e');
    return null;
  }
},



          

      routes: [
        // === CORE, AUTH & MAIN ===
        GoRoute(path: AppRoutes.start, name: 'start', pageBuilder: (_, __) => const NoTransitionPage(child: ThixIdStartPage())),
        GoRoute(path: AppRoutes.login, name: 'login', pageBuilder: (_, __) => const NoTransitionPage(child: LoginPage())),
        GoRoute(path: AppRoutes.personalReg, name: 'personalReg', pageBuilder: (_, state) => NoTransitionPage(child: PersonalRegistrationPage(initialStep: int.tryParse(state.uri.queryParameters['step'] ?? '') ?? 1))),
        GoRoute(path: AppRoutes.enterpriseReg, name: 'enterpriseReg', pageBuilder: (_, __) => const NoTransitionPage(child: EnterpriseRegistrationPage())),
        GoRoute(path: AppRoutes.payment, name: 'payment', pageBuilder: (_, state) => NoTransitionPage(child: PaymentGatewayPage(returnTo: state.uri.queryParameters['returnTo']))),
        GoRoute(path: AppRoutes.activationReceipt, name: 'activationReceipt', pageBuilder: (_, state) => NoTransitionPage(child: ActivationReceiptPage(txRef: state.uri.queryParameters['txRef'], method: state.uri.queryParameters['method'], amount: state.uri.queryParameters['amount'], currency: state.uri.queryParameters['currency'], paidAt: DateTime.tryParse(state.uri.queryParameters['paidAt'] ?? '')))),
        GoRoute(path: AppRoutes.publicProfile, name: 'publicProfile', pageBuilder: (_, state) => NoTransitionPage(child: public_profile.PublicProfilePage(initialThixId: state.uri.queryParameters['thixId']))),
        GoRoute(path: '/user/dashboard', redirect: (_, __) => AppRoutes.userDashboard),
        GoRoute(path: '/user-dashboard', redirect: (_, __) => AppRoutes.userDashboard),
        GoRoute(path: '/scanner_activation', builder: (context, state) => const ScannerActivationScreen()),
        GoRoute(path: '/connections', name: 'connections', pageBuilder: (context, state) => const NoTransitionPage(child: ConnectionsPage())),
        GoRoute(path: AppRoutes.vault, name: 'document-vault', pageBuilder: (_, __) => const NoTransitionPage(child: DocumentVaultPage())),
        GoRoute(path: AppRoutes.settings, name: 'settings', pageBuilder: (_, __) => const NoTransitionPage(child: SettingsPage())),
        GoRoute(path: AppRoutes.profile, name: 'profile', pageBuilder: (_, __) => const NoTransitionPage(child: ProfilePage())),

        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) => MainAppShell(navigationShell: navigationShell),
          branches: [
            StatefulShellBranch(routes: [
              GoRoute(path: AppRoutes.home, name: 'home', pageBuilder: (_, __) => const NoTransitionPage(child: HomePagePremium())),
            ]),
            // === THIX NETWORK ===
            StatefulShellBranch(routes: [
              GoRoute(
                path: AppRoutes.network, 
                name: 'network', 
                pageBuilder: (_, __) => const NoTransitionPage(child: NetworkProHome()), 
                routes: [
                  GoRoute(path: 'search', name: 'networkSearch', pageBuilder: (_, __) => const NoTransitionPage(child: SearchNetworkPage())),
                  GoRoute(path: 'notifications', name: 'networkNotifications', pageBuilder: (_, __) => const NoTransitionPage(child: NotificationsPage())),
                  GoRoute(path: 'messages', name: 'networkMessages', pageBuilder: (_, __) => const NoTransitionPage(child: ConversationsList())),
                  GoRoute(path: 'chat/:userId', name: 'networkChat', pageBuilder: (_, state) => NoTransitionPage(child: network_chat.ChatScreen(userId: state.pathParameters['userId']!, userName: state.extra is String ? state.extra as String : (state.extra is Map ? (state.extra as Map)['userName'] ?? 'Discussion' : 'Discussion'), userAvatar: state.extra is Map ? (state.extra as Map)['userAvatar'] : null))),
                  GoRoute(path: 'connections', name: 'networkConnections', pageBuilder: (_, __) => const NoTransitionPage(child: ConnectionsListPage())),
                  GoRoute(path: 'profile-settings', name: 'networkProfileSettings', pageBuilder: (_, __) => const NoTransitionPage(child: ProfileSettingsPage())),
                  GoRoute(path: 'blocked', name: 'networkBlockedUsers', pageBuilder: (_, __) => const NoTransitionPage(child: BlockedUsersPage())),
                  GoRoute(path: 'discover', name: 'networkDiscover', pageBuilder: (_, __) => const NoTransitionPage(child: DiscoverTab())),
                  GoRoute(path: 'communities', name: 'networkCommunities', pageBuilder: (_, __) => const NoTransitionPage(child: CommunitiesListPage())),
                  GoRoute(path: 'community/create', name: 'networkCommunityCreate', pageBuilder: (_, __) => const NoTransitionPage(child: CreateCommunityPage())),
                  GoRoute(path: 'community/:communityId', name: 'networkCommunityDetail', pageBuilder: (_, state) => NoTransitionPage(child: CommunityDetailPage(communityId: state.pathParameters['communityId']!))),
                  GoRoute(path: 'story/:storyId', name: 'networkStoryViewer', pageBuilder: (_, state) => NoTransitionPage(child: StoryViewerScreen(storyId: state.pathParameters['storyId']!))),
                  GoRoute(path: 'comments/:postId', name: 'networkComments', pageBuilder: (_, state) => NoTransitionPage(child: CommentsPage(postId: state.pathParameters['postId']!, currentProfileId: Supabase.instance.client.auth.currentUser?.id ?? ''))),
                  GoRoute(path: 'hashtag/:tag', name: 'networkHashtag', pageBuilder: (_, state) => NoTransitionPage(child: HashtagPage(tag: state.pathParameters['tag']!))),
                  GoRoute(path: 'post/:postId', name: 'networkPostDetail', pageBuilder: (_, state) => NoTransitionPage(child: PostDetailPage(postId: state.pathParameters['postId']!, currentProfileId: auth.currentUser?.id ?? ''))),
                  GoRoute(path: 'profile/:userId', name: 'networkProfile', pageBuilder: (_, state) => NoTransitionPage(child: ProfilePage(userId: state.pathParameters['userId']!))),
                  GoRoute(path: 'followers/:uid', name: 'networkFollowers', pageBuilder: (_, state) => NoTransitionPage(child: FollowersListPage(userId: state.pathParameters['uid']!))),
                  GoRoute(path: 'following/:uid', name: 'networkFollowing', pageBuilder: (_, state) => NoTransitionPage(child: FollowingListPage(userId: state.pathParameters['uid']!))),
                ]
              ),
            ]),
            // === THIX CHAT ===
            StatefulShellBranch(routes: [
              GoRoute(path: AppRoutes.chat, name: 'chat', pageBuilder: (_, __) => const NoTransitionPage(child: ChatListPage()), routes: [
                GoRoute(path: 'new', name: 'chat_new', pageBuilder: (_, __) => const NoTransitionPage(child: NewConversationPage())),
                GoRoute(path: 'group/create', name: 'group_create', pageBuilder: (_, __) => const NoTransitionPage(child: GroupCreatePage())),
                GoRoute(path: 'group/:groupId/info', name: 'group_info', pageBuilder: (_, state) => NoTransitionPage(child: GroupInfoPage(groupId: state.pathParameters['groupId']!))),
                GoRoute(path: 'group/:groupId/settings', name: 'group_settings', pageBuilder: (_, state) => NoTransitionPage(child: GroupSettingsPage(groupId: state.pathParameters['groupId']!))),
                GoRoute(path: 'profile/:userId', name: 'chatProfile', pageBuilder: (_, state) => NoTransitionPage(child: ChatProfilePage(userId: state.pathParameters['userId']!))),
                GoRoute(path: 'settings', name: 'chatSettings', pageBuilder: (_, __) => const NoTransitionPage(child: ChatSettingsPage()), routes: [
                  GoRoute(path: 'appearance', name: 'chatAppearance', pageBuilder: (_, __) => const NoTransitionPage(child: ChatAppearanceSettings())),
                  GoRoute(path: 'privacy', name: 'chatPrivacy', pageBuilder: (_, __) => const NoTransitionPage(child: ChatPrivacySettings())),
                  GoRoute(path: 'notifications', name: 'chatNotifications', pageBuilder: (_, __) => const NoTransitionPage(child: ChatNotificationSettings())),
                  GoRoute(path: 'data', name: 'chatData', pageBuilder: (_, __) => const NoTransitionPage(child: ChatDataSettings())),
                ]),
                GoRoute(path: 'escalate/:conversationId', name: 'chatEscalate', pageBuilder: (_, state) => NoTransitionPage(child: EscalateConversationPage(conversationId: state.pathParameters['conversationId']!, fromAgentId: state.uri.queryParameters['agentId'] ?? '', fromAgentName: state.uri.queryParameters['agentName']))),
                GoRoute(path: 'escalation/handle/:escalationId', name: 'chatEscalationHandle', pageBuilder: (_, state) => NoTransitionPage(child: HandleEscalationPage(escalationId: state.pathParameters['escalationId']!, agentId: state.uri.queryParameters['agentId'] ?? ''))),
                GoRoute(path: 'escalation/history/:conversationId', name: 'chatEscalationHistory', pageBuilder: (_, state) => NoTransitionPage(child: EscalationHistoryPage(conversationId: state.pathParameters['conversationId']!))),
                GoRoute(path: 'escalation/dashboard', name: 'chatEscalationDashboard', pageBuilder: (_, state) => NoTransitionPage(child: EscalationDashboardPage(agentId: state.uri.queryParameters['agentId'] ?? '', agentLevel: EscalationLevel.values[(int.tryParse(state.uri.queryParameters['level'] ?? '0') ?? 0).clamp(0, EscalationLevel.values.length - 1)]))),
                GoRoute(path: 'escalation/received', name: 'chatEscalationReceived', pageBuilder: (_, __) => const NoTransitionPage(child: ReceivedEscalationsPage())),
                GoRoute(path: ':conversationId', name: 'chat_conversation', pageBuilder: (_, state) => NoTransitionPage(child: ThixChat.ChatScreen(conversationId: state.pathParameters['conversationId']!, conversation: (state.extra as ChatConversation?) ?? ChatConversation(id: state.pathParameters['conversationId']!, isGroup: false, participantIds: [], updatedAt: DateTime.now())))),
              ]),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(path: AppRoutes.userDashboard, name: 'userDashboard', pageBuilder: (_, __) => const NoTransitionPage(child: ThixUserDashboardPage())),
            ]),
          ],
        ),

        // === THIX CHAT (Extra) ===
        GoRoute(path: AppRoutes.callIncoming, name: AppRoutes.callIncomingName, builder: (c, s) => IncomingCallPage(invite: s.extra as CallInvite)),
        GoRoute(path: AppRoutes.callOngoing, name: AppRoutes.callOngoingName, builder: (c, s) => const CallPage()),
        GoRoute(path: AppRoutes.callHistory, name: AppRoutes.callHistoryName, builder: (c, s) => const CallHistoryPage()),

        // === JOBS & OPPORTUNITIES ===
        GoRoute(path: '/opportunities/admin', builder: (context, state) => const OpportunityAdminDashboard()),
        GoRoute(path: '/opportunities/admin/create', builder: (context, state) => const OpportunityAdminPage()),
        GoRoute(path: AppRoutes.jobs, name: 'jobs', pageBuilder: (_, __) => const NoTransitionPage(child: JobsPage())),
        GoRoute(path: AppRoutes.jobDashboard, name: 'jobDashboard', pageBuilder: (_, __) => const NoTransitionPage(child: JobDashboardPage())),
        GoRoute(path: AppRoutes.recruiter, name: 'recruiter', pageBuilder: (_, __) => const NoTransitionPage(child: RecruiterPortalPage())),
        GoRoute(path: AppRoutes.opportunities, name: 'opportunities', pageBuilder: (_, __) => const NoTransitionPage(child: OpportunitiesPage())),
        GoRoute(path: '/opportunities/:opportunityId', name: 'opportunityDetails', pageBuilder: (_, state) => NoTransitionPage(child: OpportunityDetailsPage(opportunityId: state.pathParameters['opportunityId'] ?? '', applied: (state.uri.queryParameters['applied'] ?? '') == '1'))),
        GoRoute(path: '/opportunities/:opportunityId/apply', name: 'opportunityApply', pageBuilder: (_, state) => NoTransitionPage(child: OpportunityApplyPage(opportunityId: state.pathParameters['opportunityId'] ?? ''))),
        GoRoute(path: '/jobs/:jobId', name: 'jobDetails', pageBuilder: (_, state) => NoTransitionPage(child: JobDetailsPage(jobId: state.pathParameters['jobId'] ?? '', applied: (state.uri.queryParameters['applied'] ?? '') == '1'))),
        GoRoute(path: '/jobs/:jobId/apply', name: 'jobApply', pageBuilder: (_, state) => NoTransitionPage(child: JobApplyPage(jobId: state.pathParameters['jobId'] ?? ''))),

        // === THIX SOS + RETROUVE ===
        GoRoute(path: '/home-swipe', name: 'homeSwipe', builder: (context, state) => const ThixHomeSwipeScreen(initialPage: 0)),
        GoRoute(path: '/thix-sos', name: 'thixSos', builder: (context, state) => const ThixHomeSwipeScreen(initialPage: 0), routes: [
          GoRoute(path: 'actif/:id', name: 'thixSosActif', builder: (context, state) => SosActifPage(incidentId: state.pathParameters['id']!)),
          GoRoute(path: 'chambre/:id', name: 'thixSosChambre', builder: (context, state) => ChambreCrisePage(incidentId: state.pathParameters['id']!)),
          GoRoute(path: 'pin/:id', name: 'thixSosPin', builder: (context, state) {
            final mode = state.uri.queryParameters['mode'] == 'resolve' ? SosPinMode.resolve : SosPinMode.cancel;
            return SosPinPage(incidentId: state.pathParameters['id']!, mode: mode);
          }),
          GoRoute(path: 'secours', name: 'thixSosSecours', builder: (context, state) => const MesSecoursPage(), routes: [
            GoRoute(path: 'ajouter', name: 'thixSosAjouterSecours', builder: (context, state) {
              final circle = int.tryParse(state.uri.queryParameters['circle'] ?? '1') ?? 1;
              return AjouterSecoursPage(initialCircle: circle);
            }),
          ]),
          GoRoute(path: 'incidents', name: 'thixSosIncidents', builder: (context, state) => const MesIncidentsPage()),
        ]),

        GoRoute(
  path: 'chambre-secours/:id',
  name: 'thixSosChambreSecours',
  builder: (context, state) => ChambreCriseSecoursPage(
    incidentId: state.pathParameters['id']!,
    victimUserId: state.uri.queryParameters['victim'],
  ),
),
        GoRoute(path: '/thix-retrouve', name: 'thixRetrouve', builder: (context, state) => const ThixHomeSwipeScreen(initialPage: 1), routes: [
  GoRoute(
    path: 'detail', 
    name: 'thixRetrouveDetail', 
    
    pageBuilder: (_, __) => const NoTransitionPage(child: ObjectDetailPage(title: 'Détail de l\'objet'))
  ),
  GoRoute(path: 'ai-match', name: 'thixRetrouveAiMatch', pageBuilder: (_, __) => const NoTransitionPage(child: AiMatchPage())),
  GoRoute(path: 'mes-recherches', name: 'thixRetrouveMesRecherches', pageBuilder: (_, __) => const NoTransitionPage(child: MesRecherchesPage())),
  GoRoute(path: 'declarer-perdu', name: 'thixRetrouveDeclarerPerdu', pageBuilder: (_, __) => const NoTransitionPage(child: DeclarerObjetPage(type: StatutObjet.perdu))),
  GoRoute(path: 'declarer-trouve', name: 'thixRetrouveDeclarerTrouve', pageBuilder: (_, __) => const NoTransitionPage(child: DeclarerObjetPage(type: StatutObjet.trouve))),
  GoRoute(path: 'carte', name: 'thixRetrouveCarte', pageBuilder: (_, __) => const NoTransitionPage(child: CarteSignalementsPage())),
]),

        GoRoute(path: '/thix-recherche', name: 'thixRecherche', builder: (context, state) => const ThixHomeSwipeScreen(initialPage: 1), routes: [
          GoRoute(path: 'detail/:id', name: 'thixRechercheDetail', builder: (context, state) => DetailPersonnePage(personneId: state.pathParameters['id']!)),
          GoRoute(path: 'signaler/:id', name: 'thixRechercheSignaler', builder: (context, state) => SignalerPage(personneId: state.pathParameters['id']!)),
          GoRoute(path: 'creer', name: 'thixRechercheCreer', builder: (context, state) => const CreerAlertePage()),
          GoRoute(path: 'mes-alertes', name: 'thixRechercheMesAlertes', builder: (context, state) => const MesAlertesPage()),
        ]),

        // === THIX SANTE ===
        GoRoute(path: AppRoutes.thixSante, redirect: (_, __) => AppRoutes.thixSanteDashboard),
        GoRoute(path: AppRoutes.thixSanteDashboard, builder: (c, s) => const PatientDashboardPage()),
        GoRoute(path: AppRoutes.santeMonMedecinTraitant, builder: (c, s) => const MonMedecinTraitantPage()),
        GoRoute(path: AppRoutes.santeDossierFamille, builder: (c, s) => const DossierFamillePage()),
        GoRoute(path: AppRoutes.santeSecondAvis, builder: (c, s) => const SecondAvisPage()),
        GoRoute(path: AppRoutes.santeDossierMedical, builder: (c, s) => const DossierMedicalPage()),
        GoRoute(path: AppRoutes.santeOrdonnances, builder: (c, s) => const MesOrdonnancesPage()),
        GoRoute(path: AppRoutes.santeResultatsExamens, builder: (c, s) => const ResultatsExamensPage()),
        GoRoute(path: AppRoutes.santePrendreRdv, builder: (c, s) => const PrendreRdvPage()),
        GoRoute(path: AppRoutes.santeTeleconsultation, builder: (c, s) => const TeleconsultationPage()),
        GoRoute(path: AppRoutes.santeTrouverHopital, builder: (c, s) => const TrouverHopitalPage()),
        GoRoute(path: AppRoutes.santeTrouverMedicament, builder: (c, s) => const TrouverMedicamentPage()),
        GoRoute(path: AppRoutes.santePharmaciesProches, builder: (c, s) => const PharmaciesProchesPage()),
        GoRoute(path: AppRoutes.santeUrgencesProches, builder: (c, s) => const UrgencesProchesPage()),
        GoRoute(path: AppRoutes.santeEpidemies, builder: (c, s) => const EpidemiesPage()),
        GoRoute(path: AppRoutes.santeDonSang, builder: (c, s) => const DonSangPage()),
        GoRoute(path: AppRoutes.santeEnfants, builder: (c, s) => const SanteEnfantsPage()),
        GoRoute(path: AppRoutes.santeCarnetVaccination, builder: (c, s) => const CarnetVaccinationPage()),
        GoRoute(path: AppRoutes.santeSuiviGrossesse, builder: (c, s) => const SuiviGrossessePage()),
        GoRoute(path: AppRoutes.santeAnalysePredictive, builder: (c, s) => const AnalysePredictivePage()),
        GoRoute(path: AppRoutes.santeBienEtreMental, builder: (c, s) => const BienEtreMentalPage()),
        GoRoute(path: AppRoutes.santeNutrition, builder: (c, s) => const NutritionPage()),
        GoRoute(path: AppRoutes.santeActivitePhysique, builder: (c, s) => const ActivitePhysiquePage()),
        GoRoute(path: AppRoutes.santeGestionStress, builder: (c, s) => const GestionStressPage()),
        GoRoute(path: AppRoutes.santeAssuranceSanteDetail, builder: (c, s) => const AssuranceSantePage()),
        GoRoute(path: AppRoutes.santePlusServices, builder: (c, s) => const PlusServicesPage()),

        // === THIX MEDIA ===
        GoRoute(path: '/create-post', name: 'createPost', pageBuilder: (_, __) => const NoTransitionPage(child: CreatePostPage())),
        GoRoute(path: '/profile/:userId', name: 'userProfileRoute', pageBuilder: (_, state) => NoTransitionPage(child: UserProfilePage(userId: state.pathParameters['userId']!))),
        GoRoute(path: 'followers/:uid', builder: (context, state) => FollowersListPage(userId: state.pathParameters['uid']!)),
        GoRoute(path: 'following/:uid', builder: (context, state) => FollowingListPage(userId: state.pathParameters['uid']!)),
        GoRoute(path: AppRoutes.thixMedia, name: 'thixMedia', pageBuilder: (_, __) => const NoTransitionPage(child: ThixMediaPage()), routes: [GoRoute(path: 'admin', name: 'thixMediaAdmin', pageBuilder: (_, __) => const NoTransitionPage(child: ThixMediaAdminPage()))]),
        GoRoute(path: AppRoutes.thixMediaVideo, name: 'thixMediaVideo', pageBuilder: (_, state) => NoTransitionPage(child: VideoPlayerPage(title: (state.uri.queryParameters['title'] ?? '').trim().isEmpty ? 'Lecture vidéo' : (state.uri.queryParameters['title'] ?? ''), videoUrl: (state.uri.queryParameters['url'] ?? '').trim()))),

        // === THIX INFO ===
        GoRoute(path: AppRoutes.thixInfo, name: 'thixInfo', pageBuilder: (_, __) => const NoTransitionPage(child: ThixInfoHome())),
        GoRoute(path: AppRoutes.thixInfoArticle, name: 'thixInfoArticle', pageBuilder: (_, state) => NoTransitionPage(child: thixInfoArticle.ArticleDetailPage(articleId: state.pathParameters['articleId']!))),
        GoRoute(path: AppRoutes.thixInfoSearch, name: 'thixInfoSearch', pageBuilder: (_, __) => const NoTransitionPage(child: infoSearch.SearchPage())),
        GoRoute(path: AppRoutes.thixInfoCategory, name: 'thixInfoCategory', pageBuilder: (_, state) => NoTransitionPage(child: CategoryArticlesPage(category: state.pathParameters['category']!))),
        GoRoute(path: AppRoutes.thixInfoSaved, name: 'thixInfoSaved', pageBuilder: (_, __) => const NoTransitionPage(child: SavedArticlesPage())),
        GoRoute(path: AppRoutes.thixInfoBreaking, name: 'thixInfoBreaking', pageBuilder: (_, __) => const NoTransitionPage(child: BreakingNewsPage())),

        // === THIX EVENT ===
        GoRoute(path: AppRoutes.thixEvent, name: 'thixEvent', pageBuilder: (_, __) => const NoTransitionPage(child: ThixEventHome())),
        GoRoute(path: AppRoutes.thixEventDetail, name: 'thixEventDetail', pageBuilder: (_, state) => NoTransitionPage(child: EventDetailPage(eventId: state.pathParameters['eventId']!))),
        GoRoute(path: AppRoutes.thixEventSearch, name: 'thixEventSearch', pageBuilder: (_, __) => const NoTransitionPage(child: EventSearchPage())),
        GoRoute(path: AppRoutes.thixEventCategory, name: 'thixEventCategory', pageBuilder: (_, state) => NoTransitionPage(child: EventCategoryPage(category: state.pathParameters['category']!))),
        GoRoute(path: AppRoutes.thixEventReservation, name: 'thixEventReservation', pageBuilder: (_, state) => NoTransitionPage(child: EventReservationPage(eventId: state.pathParameters['eventId']!, quantity: int.tryParse(state.uri.queryParameters['quantity'] ?? '1') ?? 1))),
        GoRoute(path: AppRoutes.thixEventMyTickets, name: 'thixEventMyTickets', pageBuilder: (_, __) => const NoTransitionPage(child: MyTicketsPage())),
        GoRoute(path: AppRoutes.thixEventFavorites, name: 'thixEventFavorites', pageBuilder: (_, __) => const NoTransitionPage(child: FavoriteEventsPage())),
        GoRoute(path: AppRoutes.thixEventSeatSelection, name: 'thixEventSeatSelection', pageBuilder: (_, state) => NoTransitionPage(child: SeatSelectionPage(eventId: state.pathParameters['eventId']!))),
        GoRoute(path: AppRoutes.thixEventWaitingQueue, name: 'thixEventWaitingQueue', pageBuilder: (_, state) => NoTransitionPage(child: WaitingQueuePage(eventId: state.pathParameters['eventId']!, requestedQuantity: int.tryParse(state.uri.queryParameters['quantity'] ?? '1') ?? 1))),
        GoRoute(path: '/thix-event/admin', name: 'thixEventAdmin', pageBuilder: (_, __) => const NoTransitionPage(child: AdminDashboard())),
        GoRoute(path: '/thix-event/admin/events', name: 'thixEventAdminEvents', pageBuilder: (_, __) => const NoTransitionPage(child: EventListAdminPage())),
        GoRoute(path: '/thix-event/admin/events/create', name: 'thixEventAdminCreate', pageBuilder: (context, state) => NoTransitionPage(child: EventCreateEditPage(eventToEdit: state.extra is Event ? state.extra as Event : null))),
        GoRoute(path: '/thix-event/admin/seats', name: 'thixEventAdminSeats', pageBuilder: (_, __) => const NoTransitionPage(child: SeatMapAdminPage())),
        GoRoute(path: '/thix-event/admin/bookings', name: 'thixEventAdminBookings', pageBuilder: (_, __) => const NoTransitionPage(child: BookingManagementPage())),
        GoRoute(path: '/thix-event/admin/queue', name: 'thixEventAdminQueue', pageBuilder: (_, __) => const NoTransitionPage(child: admin_queue.WaitingQueuePage())),
        GoRoute(path: '/thix-event/admin/limits', name: 'thixEventAdminLimits', pageBuilder: (_, __) => const NoTransitionPage(child: BookingLimitsPage())),
        GoRoute(path: '/thix-event/admin/analytics', name: 'thixEventAdminAnalytics', pageBuilder: (_, __) => const NoTransitionPage(child: AnalyticsPage())),
        GoRoute(path: '/thix-event/payment', builder: (context, state) => EventPaymentPage(bookingId: ((state.extra as Map<String, dynamic>?) ?? {})['bookingId'] as String? ?? '', amount: ((state.extra as Map<String, dynamic>?) ?? {})['amount'] as double? ?? 0.0, currency: ((state.extra as Map<String, dynamic>?) ?? {})['currency'] as String? ?? 'USD')),
        GoRoute(path: '/thix-event/ticket/:id', builder: (context, state) => EventTicketPage(bookingId: state.pathParameters['id']!)),

        // === THIX RESERVATION (BUS & GENERAL) ===
        GoRoute(
          path: AppRoutes.reservation,
          name: 'thixreservation',
          pageBuilder: (_, __) => const NoTransitionPage(child: ThixReservationHomePage()),
        ),
        GoRoute(
          path: '/thix-reservation/bus',
          name: 'bus-home',
          pageBuilder: (_, __) => const NoTransitionPage(child: BusHomePage()),
        ),
        GoRoute(
          path: '/thix-reservation/bus/search',
          name: 'bus-search',
          pageBuilder: (_, __) => const NoTransitionPage(child: BusSearchResultPage()),
        ),
        GoRoute(
          path: '/thix-reservation/bus/detail',
          name: 'bus-detail',
          pageBuilder: (_, state) {
            final extra = state.extra;
            if (extra is BusTripModel) {
              return NoTransitionPage(child: BusTripDetailPage(trip: extra));
            }
            return const NoTransitionPage(child: BusTripDetailPage());
          },
        ),
        GoRoute(
          path: '/thix-reservation/bus/trip/:tripId',
          name: 'bus-trip-by-id',
          pageBuilder: (_, state) {
            final extra = state.extra;
            if (extra is BusTripModel) {
              return NoTransitionPage(child: BusTripDetailPage(trip: extra));
            }
            return NoTransitionPage(
              child: BusTripDetailPage(tripId: state.pathParameters['tripId']),
            );
          },
        ),
        GoRoute(
          path: '/thix-reservation/bus/seats',
          name: 'bus-seats',
          pageBuilder: (_, state) {
            final extra = state.extra;
            if (extra is BusTripModel) {
              return NoTransitionPage(child: BusSeatSelectionPage(trip: extra));
            }
            return const NoTransitionPage(child: BusSeatSelectionPage());
          },
        ),
        GoRoute(
          path: '/thix-reservation/bus/payment',
          name: 'bus-payment',
          pageBuilder: (_, state) {
            final extra = state.extra;
            if (extra is Map) {
              return NoTransitionPage(
                child: BusPaymentPage(
                  trip: extra['trip'] as BusTripModel,
                  seats: (extra['seats'] as List).cast<String>(),
                ),
              );
            }
            if (extra is BusTripModel) {
              return NoTransitionPage(child: BusPaymentPage(trip: extra, seats: const []));
            }
            return const NoTransitionPage(child: BusHomePage());
          },
        ),
        GoRoute(
          path: '/thix-reservation/bus/ticket/:id',
          name: 'bus-ticket',
          pageBuilder: (_, state) {
            final extra = state.extra;
            if (extra is BookingModel) {
              return NoTransitionPage(child: BusTicketPage(booking: extra));
            }
            return NoTransitionPage(
              child: BusTicketPage(bookingId: state.pathParameters['id']),
            );
          },
        ),
        GoRoute(
          path: '/agency/onboarding',
          name: 'agency-onboarding',
          pageBuilder: (_, __) => const NoTransitionPage(child: AgencyOnboardingPage()),
        ),
        GoRoute(
          path: '/agency/dashboard',
          name: 'agency-dashboard',
          pageBuilder: (_, __) => const NoTransitionPage(child: AgencyDashboardPage()),
        ),
        GoRoute(
          path: '/agency/trip/create',
          name: 'agency-create-trip',
          pageBuilder: (_, __) => const NoTransitionPage(child: AgencyCreateTripPage()),
        ),
        GoRoute(
          path: '/agency/scan',
          name: 'agency-scan',
          pageBuilder: (_, __) => const NoTransitionPage(child: AgencyQrScanPage()),
        ),
        GoRoute(
          path: '/agency/seats',
          name: 'agency-seats',
          pageBuilder: (context, state) {
            final tripId = state.uri.queryParameters['tripId'] ?? '';
            return NoTransitionPage(child: AgencySeatsPage(tripId: tripId));
          },
        ),
        GoRoute(
  path: '/thix-ia',
  name: 'thix-ia-home',
  builder: (context, state) => const ThixIaHomePage(), // 
),

        // === THIX RESERVATION (DELIVERY) ===
        GoRoute(path: AppRoutes.deliveryHome, name: 'delivery-home', pageBuilder: (_, __) => NoTransitionPage(child: app_provider.ChangeNotifierProvider(create: (_) => DeliveryClientProvider()..init(), child: const DeliveryHomePage()))),
        GoRoute(path: AppRoutes.deliveryCheckout, name: 'delivery-checkout', pageBuilder: (_, __) => NoTransitionPage(child: app_provider.ChangeNotifierProvider(create: (_) => DeliveryClientProvider(), child: const DeliveryCheckoutPage()))),
        GoRoute(path: AppRoutes.deliveryTracking, name: 'delivery-tracking', pageBuilder: (_, __) => NoTransitionPage(child: app_provider.ChangeNotifierProvider(create: (_) => DeliveryClientProvider(), child: const delivery_tracking.DeliveryTrackingPage()))),
        GoRoute(path: AppRoutes.deliveryHistory, name: 'delivery-history', pageBuilder: (_, __) => NoTransitionPage(child: app_provider.ChangeNotifierProvider(create: (_) => DeliveryClientProvider()..loadMyShipments(refresh: true), child: const DeliveryHistoryPage()))),
        GoRoute(path: AppRoutes.deliveryAdminDashboard, name: 'delivery-admin-dashboard', pageBuilder: (_, __) => NoTransitionPage(child: app_provider.ChangeNotifierProvider(create: (_) => DeliveryAdminProvider()..init(), child: const DeliveryAdminDashboardPage()))),
        GoRoute(path: AppRoutes.deliveryAdminRoutes, name: 'delivery-admin-routes', pageBuilder: (_, __) => NoTransitionPage(child: app_provider.ChangeNotifierProvider(create: (_) => DeliveryAdminProvider()..loadRoutes(force: true), child: const DeliveryAdminRoutesPage()))),
        GoRoute(path: AppRoutes.deliveryAdminShipments, name: 'delivery-admin-shipments', pageBuilder: (_, __) => NoTransitionPage(child: app_provider.ChangeNotifierProvider(create: (_) => DeliveryAdminProvider()..loadAllShipments(), child: const DeliveryAdminShipmentsPage()))),
        GoRoute(path: AppRoutes.deliveryAdminScan, name: 'delivery-admin-scan', pageBuilder: (_, __) => NoTransitionPage(child: app_provider.ChangeNotifierProvider(create: (_) => DeliveryAdminProvider(), child: const DeliveryAdminScanPage()))),

        // === THIX MARKET ===
        GoRoute(path: AppRoutes.thixMarket, name: 'thixMarket', pageBuilder: (_, __) => const NoTransitionPage(child: MarketHomePage()), routes: [
          GoRoute(path: 'home', name: 'marketHome', pageBuilder: (_, __) => const NoTransitionPage(child: MarketHomePage())),
          GoRoute(path: 'search', name: 'marketSearch', pageBuilder: (_, __) => const NoTransitionPage(child: marketSearch.SearchPage())),
          GoRoute(path: 'shops', name: 'marketShops', pageBuilder: (_, __) => const NoTransitionPage(child: ShopsPage())),
          GoRoute(path: 'buy', name: 'marketBuy', pageBuilder: (_, __) => const NoTransitionPage(child: BuyPage())),
          GoRoute(path: 'sell', name: 'marketSell', pageBuilder: (_, __) => const NoTransitionPage(child: SellPage())),
          GoRoute(path: 'compare', name: 'marketProductComparator', pageBuilder: (_, __) => const NoTransitionPage(child: ProductComparatorPage())),
          GoRoute(path: 'price-alerts', name: 'marketPriceAlerts', pageBuilder: (_, __) => const NoTransitionPage(child: PriceAlertsPage())),
          GoRoute(path: 'wishlist', name: 'marketWishlist', pageBuilder: (_, __) => const NoTransitionPage(child: WishlistPage())),
          GoRoute(path: 'cart', name: 'marketCart', pageBuilder: (_, __) => const NoTransitionPage(child: CartPage())),
          GoRoute(path: 'orders', name: 'marketOrders', pageBuilder: (_, __) => const NoTransitionPage(child: OrderHistoryPage())),
          GoRoute(path: 'checkout', name: 'marketCheckout', pageBuilder: (_, __) => const NoTransitionPage(child: CheckoutPage())),
          GoRoute(path: 'tracking/:orderId', name: 'marketDeliveryTracking', pageBuilder: (_, state) => NoTransitionPage(child: market_delivery.DeliveryTrackingPage(orderId: state.pathParameters['orderId']!))),
          GoRoute(path: 'shop/create', name: 'marketCreateShop', pageBuilder: (_, __) => const NoTransitionPage(child: CreateShopPage())),
          GoRoute(path: 'announcement/publish', name: 'marketPublishAnnouncement', pageBuilder: (_, __) => const NoTransitionPage(child: PublishAnnouncementPage())),
          GoRoute(path: 'live/create', name: 'marketCreateLive', pageBuilder: (_, __) => const NoTransitionPage(child: CreateLivePage())),
          GoRoute(path: 'live', name: 'marketLive', pageBuilder: (_, __) => const NoTransitionPage(child: LivePage())),
          GoRoute(path: 'messages', name: 'marketMessages', pageBuilder: (_, __) => const NoTransitionPage(child: MessagesPage())),
          GoRoute(path: 'notifications', name: 'marketNotifications', pageBuilder: (_, __) => const NoTransitionPage(child: NotificationPage())),
          GoRoute(path: 'activity', name: 'marketActivity', pageBuilder: (_, __) => const NoTransitionPage(child: MyActivityPage())),
          GoRoute(path: 'settings', name: 'marketSettings', pageBuilder: (_, __) => const NoTransitionPage(child: MarketSettingsPage())),
          GoRoute(path: 'help', name: 'marketHelp', pageBuilder: (_, __) => const NoTransitionPage(child: HelpSupportPage())),
          GoRoute(path: 'vendor/dashboard', name: 'vendorDashboard', pageBuilder: (_, __) => const NoTransitionPage(child: VendorDashboard())),
          GoRoute(path: 'vendor/orders', name: 'vendorOrders', pageBuilder: (_, __) => const NoTransitionPage(child: VendorOrdersPage())),
          GoRoute(path: 'deliveries', name: 'deliveryManagement', pageBuilder: (_, __) => const NoTransitionPage(child: DeliveryManagementPage())),
          GoRoute(path: 'shop/:shopId/manage', name: 'marketManageShop', pageBuilder: (_, state) => NoTransitionPage(child: ManageShopPage(shopId: state.pathParameters['shopId']!))),
          GoRoute(path: 'shop/:shopId/stats', name: 'marketShopStats', pageBuilder: (_, state) => NoTransitionPage(child: ShopStatisticsPage(shopId: state.pathParameters['shopId']!))),
          GoRoute(path: 'shop/:shopId', name: 'marketShopDetail', pageBuilder: (_, state) => NoTransitionPage(child: ShopDetailPage(shopId: state.pathParameters['shopId']!))),
          GoRoute(path: 'product/:productId', name: 'marketProductDetail', pageBuilder: (_, state) => NoTransitionPage(child: ProductDetailPage(productId: state.pathParameters['productId']!))),
          GoRoute(path: 'order/:orderId', name: 'marketOrderDetail', pageBuilder: (_, state) => NoTransitionPage(child: OrderDetailPage(orderId: state.pathParameters['orderId']!))),
          GoRoute(path: 'auction/:auctionId', name: 'marketAuction', pageBuilder: (_, state) => NoTransitionPage(child: AuctionPage(auctionId: state.pathParameters['auctionId']!))),
          GoRoute(path: 'dispute/:disputeId', name: 'marketDispute', pageBuilder: (_, state) => NoTransitionPage(child: DisputeDetailPage(disputeId: state.pathParameters['disputeId']!))),
          GoRoute(path: 'announcement/:announcementId/edit', name: 'marketEditAnnouncement', pageBuilder: (_, state) => NoTransitionPage(child: EditAnnouncementPage(announcementId: state.pathParameters['announcementId']!))),
          GoRoute(path: 'live/:liveId/replay', name: 'marketLiveReplay', pageBuilder: (_, state) => NoTransitionPage(child: LiveReplayPage(liveId: state.pathParameters['liveId']!))),
          GoRoute(path: 'live/:liveId', name: 'marketLiveStream', pageBuilder: (_, state) => NoTransitionPage(child: LiveStreamPage(liveId: state.pathParameters['liveId']!))),
          GoRoute(path: 'chat/:conversationId', name: 'marketChat', pageBuilder: (_, state) => NoTransitionPage(child: ChatPage(conversationId: state.pathParameters['conversationId']!))),
        ]),

        // === ADMIN SYSTEM GLOBAL ===
        GoRoute(path: '/admin', builder: (context, state) => const thix_admin.AdminHomePage()),
        GoRoute(path: '/admin/articles', builder: (context, state) => const thix_admin_list.AdminArticlesListPage()),
        GoRoute(path: '/admin/articles/new', builder: (context, state) => const thix_admin_form.AdminArticleFormPage()),
        GoRoute(path: '/admin/articles/:id/edit', builder: (context, state) => thix_admin_form.AdminArticleFormPage(articleId: state.pathParameters['id'])),
        GoRoute(path: '${AppRoutes.admin}/:module', name: 'admin', pageBuilder: (_, state) => NoTransitionPage(child: AdminPage(module: AdminModuleX.fromSlug(state.pathParameters['module'])))),
        GoRoute(path: AppRoutes.admin, name: 'adminRoot', redirect: (_, __) => '${AppRoutes.admin}/${AdminModule.overview.slug}'),

        // === MON PAYS ===
        GoRoute(path: AppRoutes.monPays, name: 'monPays', pageBuilder: (_, __) => const NoTransitionPage(child: MonPaysPage()), routes: [
          GoRoute(path: 'authorities', name: 'monPaysAuthorities', pageBuilder: (_, __) => const NoTransitionPage(child: AuthoritiesPage())),
          GoRoute(path: 'authorities/:id', name: 'monPaysAuthorityProfile', pageBuilder: (_, state) => NoTransitionPage(child: AuthorityProfilePage(authorityId: state.pathParameters['id']!))),
          GoRoute(path: 'laws', name: 'monPaysLaws', pageBuilder: (_, __) => const NoTransitionPage(child: LawsPage())),
          GoRoute(path: 'laws/:type', name: 'monPaysArticleType', pageBuilder: (_, state) => NoTransitionPage(child: ArticleTypePage(type: ArticleType.fromString(state.pathParameters['type']!), title: ArticleType.fromString(state.pathParameters['type']!).label))),
          GoRoute(path: 'laws/article/:id', name: 'monPaysArticleDetail', pageBuilder: (_, state) => NoTransitionPage(child: monPaysArticle.ArticleDetailPage(articleId: state.pathParameters['id']!))),
          GoRoute(path: 'provinces', name: 'monPaysProvinces', pageBuilder: (_, __) => const NoTransitionPage(child: ProvincesPage())),
          GoRoute(path: 'provinces/:id', name: 'monPaysProvinceDetail', pageBuilder: (_, state) => NoTransitionPage(child: ProvinceDetailPage(provinceId: state.pathParameters['id']!))),
          GoRoute(path: 'admin', name: 'monPaysAdmin', pageBuilder: (_, __) => const NoTransitionPage(child: AdminDashboardPage())),
          GoRoute(path: 'admin/authorities', name: 'monPaysAdminAuthorities', pageBuilder: (_, __) => const NoTransitionPage(child: AdminAuthoritiesPage())),
          GoRoute(path: 'admin/form', name: 'monPaysAdminForm', pageBuilder: (_, state) => NoTransitionPage(child: AdminAuthorityFormPage(authority: state.extra as dynamic))),
          GoRoute(path: 'admin/articles', name: 'monPaysAdminArticles', pageBuilder: (_, __) => const NoTransitionPage(child: monpays_articles.AdminArticlesPage())),
          GoRoute(path: 'admin/articles/form', name: 'monPaysAdminArticleForm', pageBuilder: (_, state) => NoTransitionPage(child: monpays_form.AdminArticleFormPage(article: state.extra as Article?))),
          GoRoute(path: 'admin/provinces', name: 'monPaysAdminProvinces', pageBuilder: (_, __) => const NoTransitionPage(child: AdminProvincesPage())),
          GoRoute(path: 'admin/provinces/form', name: 'monPaysAdminProvinceForm', pageBuilder: (_, state) => NoTransitionPage(child: AdminProvinceFormPage(province: state.extra as Province?))),
        ]),

        // ============================================================
        // === THIX IA NEW MODULE - 15 PAGES - FULL PROD ENTERPRISE ===
        // ============================================================
        ...ThixIaRouter.routes,

        // === OTHER SPREAD ROUTES (Education, Money, Weeding) ===
        GoRoute(path: AppRoutes.certification, name: 'certification', pageBuilder: (_, __) => const NoTransitionPage(child: CertificationTiersPage())),
        ...educationRoutes,
        ...instructorRoutes,
        ...ThixMoneyRouter.routes,
        ...ThixWeedingRoutes.routes,
      ],
    );
  }
}

extension GoRouterBackHelpers on BuildContext {
  void popOrGo(String fallbackLocation) {
    final router = GoRouter.of(this);
    if (router.canPop()) { 
      pop(); 
      return; 
    }
    go(fallbackLocation);
  }
}
