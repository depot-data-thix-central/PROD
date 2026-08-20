// lib/nav.dart
import 'package:flutter/material.dart';

/// Navigator root partagé (GoRouter + GlobalCallListener)
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

class AppRoutes {
  static const String start = '/start';
  static const String home = '/';
  static const String login = '/login';
  static const String personalReg = '/personal-reg';
  static const String enterpriseReg = '/enterprise-reg';
  static const String enterprise = '/enterprise';
  static const String payment = '/payment';
  static const String activationReceipt = '/activation-receipt';
  static const String publicProfile = '/public-profile';
  static const String userDashboard = '/dashboard';
  static const String enterpriseDashboard = '/enterprise-dashboard';
  static const String enterprisePortalBasePath = '/company';
static const String certification = '/certification';
  
  static const String vault = '/vault';
  static const String settings = '/settings';
  static const String network = '/network';
  static const String networkSearch = '/network/search';
  static const String networkNotifications = '/network/notifications';
  static const String networkMessages = '/network/messages';
  static const String networkConnections = '/network/connections';
  static const String networkProfileSettings = '/network/profile-settings';
  static const String networkBlockedUsers = '/network/blocked';
  static const String networkChatBasePath = '/network/chat';
  static const String networkPostBasePath = '/network/post';
  static const String networkCommunityBasePath = '/network/community';
  static const String networkProfileBasePath = '/network/profile';
  static const String profile = '/profile';
  static const String jobs = '/jobs';
  static const String jobDashboard = '/jobs/dashboard';
  static const String recruiter = '/recruiter';
  static const String opportunities = '/opportunities';
  static const String admin = '/admin';
  static const String thixMarket = '/market';

  // Éducation
  static const String education = '/education';
  static const String trainingHome = '/education';
  static const String trainingDetailsBasePath = '/education';
  static const String instructorDashboard = '/';
  static const String instructorCourses = '/instructor/courses';
  static const String thixMediaVideo = '/thix-media-video';
  static const String adminMedia = '/admin-media';
  static const String thixMedia = '/thix-media';

  // ═══════════════════════════════════════════════════════════════
  // THIX MONEY - FULL PRODUCTION - VÉRIFIE THIX_ID EN BASE
  // ═══════════════════════════════════════════════════════════════
  static const String thixMoney = '/thix-money';
  static const String thixMoneyDashboard = '/thix-money';
  static const String thixMoneySend = '/thix-money/send';
  static const String thixMoneyRecharge = '/thix-money/recharge';
  static const String thixMoneyRetrait = '/thix-money/retrait';
  static const String thixMoneyScanner = '/thix-money/scanner';
  static const String thixMoneyHistory = '/thix-money/history';
  static const String thixMoneySavings = '/thix-money/savings';
  static const String thixMoneyInvestments = '/thix-money/investments';
  static const String thixMoneyLoans = '/thix-money/loans';
  static const String thixMoneyTontines = '/thix-money/tontines';
  static const String thixMoneyProfile = '/thix-money/profile';

  static const String reservation = '/reservation';

  // THIX INFO
  static const String thixInfo = '/thix-info';
  static const String thixInfoArticle = '/thix-info/article/:articleId';
  static const String thixInfoSearch = '/thix-info/search';
  static const String thixInfoCategory = '/thix-info/category/:category';
  static const String thixInfoSaved = '/thix-info/saved';
  static const String thixInfoBreaking = '/thix-info/breaking';
  static const String thixInfoAdmin = '/thix-info/admin';
  static const String thixInfoCreate = '/thix-info/admin/create';
  static const String thixInfoEdit = '/thix-info/admin/edit/:articleId';

  // THIX CHAT
  static const String chat = '/chat';
  static const String chatNew = '/chat/new';
  static const String chatConversation = '/chat/:conversationId';
  static String chatDetail(String conversationId) => '/chat/$conversationId';
  static const String chatEscalate = '/chat/escalate/:conversationId';
  static const String chatEscalationHandle = '/chat/escalation/handle/:escalationId';
  static const String chatEscalationHistory = '/chat/escalation/history/:conversationId';
  static const String chatEscalationDashboard = '/chat/escalation/dashboard';
  static const String chatEscalationReceived = '/chat/escalation/received';
  static const String groupCreate = '/chat/group/create';
  static const String groupInfo = '/chat/group/:groupId/info';
  static const String groupSettings = '/chat/group/:groupId/settings';
  static const String groupMembers = '/chat/group/:groupId/members';
  static const String groupAddMembers = '/chat/group/:groupId/add-members';
  static String groupInfoPath(String groupId) => '/chat/group/$groupId/info';
  static String groupSettingsPath(String groupId) => '/chat/group/$groupId/settings';
  static String groupMembersPath(String groupId) => '/chat/group/$groupId/members';
  static String groupAddMembersPath(String groupId) => '/chat/group/$groupId/add-members';

  // THIX ÉVÉNEMENT
  static const String thixEvent = '/thix-event';
  static const String thixEventDetail = '/thix-event/event/:eventId';
  static const String thixEventSearch = '/thix-event/search';
  static const String thixEventCategory = '/thix-event/category/:category';
  static const String thixEventReservation = '/thix-event/reservation/:eventId';
  static const String thixEventMyTickets = '/thix-event/my-tickets';
  static const String thixEventFavorites = '/thix-event/favorites';
  static const String thixEventSeatSelection = '/thix-event/seat-selection/:eventId';
  static const String thixEventWaitingQueue = '/thix-event/waiting-queue/:eventId';
  static const String thixEventAdmin = '/thix-event/admin';
  static const String thixEventAdminEvents = '/thix-event/admin/events';
  static const String thixEventAdminCreate = '/thix-event/admin/events/create';
  static const String thixEventAdminSeats = '/thix-event/admin/seats';
  static const String thixEventAdminBookings = '/thix-event/admin/bookings';
  static const String thixEventAdminQueue = '/thix-event/admin/queue';
  static const String thixEventAdminLimits = '/thix-event/admin/limits';
  static const String thixEventAdminAnalytics = '/thix-event/admin/analytics';

  // CHAT SETTINGS
  static const String chatProfile = '/chat/profile/:userId';
  static const String chatSettings = '/chat/settings';
  static const String chatAppearance = '/chat/settings/appearance';
  static const String chatPrivacy = '/chat/settings/privacy';
  static const String chatNotifications = '/chat/settings/notifications';
  static const String chatData = '/chat/settings/data';

  // MON PAYS
  static const String monPays = '/mon-pays';
  static const String monPaysAuthorities = '/mon-pays/authorities';
  static const String monPaysAuthorityProfile = '/mon-pays/authority/:id';
  static String monPaysAuthorityProfilePath(String id) => '/mon-pays/authority/$id';
  static const String monPaysProvinces = '/mon-pays/provinces';
  static const String monPaysProvinceDetail = '/mon-pays/provinces/:id';
  static const String monPaysAdminProvinces = '/mon-pays/admin/provinces';
  static const String monPaysAdminProvinceForm = '/mon-pays/admin/provinces/form';
  static const String monPaysAdminGovernmentForm = '/mon-pays/admin/provinces/government/:provinceId';
  static const String monPaysAdminEconomicForm = '/mon-pays/admin/provinces/economic/:provinceId';
  static const String monPaysAdminBudgetForm = '/mon-pays/admin/provinces/budget/:provinceId';
  static const String monPaysAdminTourismForm = '/mon-pays/admin/provinces/tourism/:provinceId';
  static const String monPaysAdminEmergencyForm = '/mon-pays/admin/provinces/emergency/:provinceId';
  static const String monPaysAdminAdministrativeForm = '/mon-pays/admin/provinces/administrative/:provinceId';
  static const String monPaysAdminAchievementForm = '/mon-pays/admin/provinces/achievement/:provinceId';
  static const String monPaysAdminMediaForm = '/mon-pays/admin/provinces/media/:provinceId';
  static String monPaysProvinceDetailPath(String id) => '/mon-pays/provinces/$id';
  static String monPaysAdminProvinceFormPath({dynamic province}) =>
      '/mon-pays/admin/provinces/form';
  static String monPaysAdminGovernmentFormPath(String provinceId) =>
      '/mon-pays/admin/provinces/government/$provinceId';
  static String monPaysAdminEconomicFormPath(String provinceId) =>
      '/mon-pays/admin/provinces/economic/$provinceId';
  static String monPaysAdminBudgetFormPath(String provinceId) =>
      '/mon-pays/admin/provinces/budget/$provinceId';
  static String monPaysAdminTourismFormPath(String provinceId) =>
      '/mon-pays/admin/provinces/tourism/$provinceId';
  static String monPaysAdminEmergencyFormPath(String provinceId) =>
      '/mon-pays/admin/provinces/emergency/$provinceId';
  static String monPaysAdminAdministrativeFormPath(String provinceId) =>
      '/mon-pays/admin/provinces/administrative/$provinceId';
  static String monPaysAdminAchievementFormPath(String provinceId) =>
      '/mon-pays/admin/provinces/achievement/$provinceId';
  static String monPaysAdminMediaFormPath(String provinceId) =>
      '/mon-pays/admin/provinces/media/$provinceId';
  static const String monPaysLaws = '/mon-pays/laws';
  static const String monPaysArticleType = '/mon-pays/laws/:type';
  static const String monPaysArticleDetail = '/mon-pays/laws/article/:id';
  static String monPaysArticleTypePath(String type) => '/mon-pays/laws/$type';
  static String monPaysArticleDetailPath(String id) => '/mon-pays/laws/article/$id';
  static const String monPaysAdmin = '/mon-pays/admin';
  static const String monPaysAdminAuthorities = '/mon-pays/admin/authorities';
  static const String monPaysAdminForm = '/mon-pays/admin/form';
  static const String monPaysAdminArticles = '/mon-pays/admin/articles';
  static const String monPaysAdminArticleForm = '/mon-pays/admin/articles/form';
  static String monPaysAdminFormPath({dynamic authority}) => '/mon-pays/admin/form';
  static String monPaysAdminArticleFormPath({dynamic article}) =>
      '/mon-pays/admin/articles/form';

  // THIX SANTÉ
  static const String thixSante = '/thix-sante';
  static const String thixSanteDashboard = '/thix-sante/dashboard';
  static const String santeConsulterMedecin = '/thix-sante/consulter-medecin';
  static const String santeDossierMedical = '/thix-sante/dossier-medical';
  static const String santeResultatsExamens = '/thix-sante/resultats-examens';
  static const String santeOrdonnances = '/thix-sante/ordonnances';
  static const String santeTrouverHopital = '/thix-sante/trouver-hopital';
  static const String santeTrouverMedicament = '/thix-sante/trouver-medicament';
  static const String santePharmaciesProches = '/thix-sante/pharmacies-proches';
  static const String santeUrgencesProches = '/thix-sante/urgences-proches';
  static const String santePrendreRdv = '/thix-sante/prendre-rdv';
  static const String santeTeleconsultation = '/thix-sante/teleconsultation';
  static const String santeAssistantIA = '/thix-sante/assistant-ia';
  static const String santeDossierPartage = '/thix-sante/dossier-partage';
  static const String santeEpidemies = '/thix-sante/epidemies';
  static const String santeDonSang = '/thix-sante/don-sang';
  static const String santeMonMedecinTraitant = '/thix-sante/mon-medecin-traitant';
  static const String santeDossierFamille = '/thix-sante/dossier-famille';
  static const String santeSecondAvis = '/thix-sante/second-avis';
  static const String santeRappelsVaccin = '/thix-sante/rappels-vaccin';
  static const String santeCertificatMedical = '/thix-sante/certificat-medical';
  static const String santeAssurance = '/thix-sante/assurance';
  static const String santeEnfants = '/thix-sante/sante-enfants';
  static const String santeCarnetVaccination = '/thix-sante/carnet-vaccination';
  static const String santeSuiviGrossesse = '/thix-sante/suivi-grossesse';
  static const String santeAnalysePredictive = '/thix-sante/analyse-predictive';
  static const String santeBienEtreMental = '/thix-sante/bien-etre-mental';
  static const String santeNutrition = '/thix-sante/nutrition';
  static const String santeActivitePhysique = '/thix-sante/activite-physique';
  static const String santeGestionStress = '/thix-sante/gestion-stress';
  static const String santeAssuranceSanteDetail = '/thix-sante/assurance-sante';
  static const String santePlusServices = '/thix-sante/plus-services';
  static String santeOrdonnanceDetail(String id) => '/thix-sante/ordonnances/$id';
  static String santeDossierDetail(String recordId) =>
      '/thix-sante/dossier-medical/$recordId';
  static String santeTeleconsultationRoom(String roomId) =>
      '/thix-sante/teleconsultation/$roomId';
  static String santeHopitalDetail(String hopitalId) =>
      '/thix-sante/trouver-hopital/$hopitalId';
  static String santePharmacieDetail(String pharmacieId) =>
      '/thix-sante/pharmacies-proches/$pharmacieId';

  static const String deliveryHome = '/thix-reservation/delivery';
  static const String deliveryCheckout = '/thix-reservation/delivery/checkout';
  static const String deliveryTracking = '/thix-reservation/delivery/tracking';
  static const String deliveryHistory = '/thix-reservation/delivery/history';
  static const String deliveryAdminDashboard = '/thix-reservation/delivery/admin';
  static const String deliveryAdminRoutes = '/thix-reservation/delivery/admin/routes';
  static const String deliveryAdminShipments =
      '/thix-reservation/delivery/admin/shipments';
  static const String deliveryAdminScan = '/thix-reservation/delivery/admin/scan';
  
  // ── THIX SOS + RETROUVE ──────────────────────────────────────
static const String homeSwipe = '/home-swipe';
static const String thixSos = '/thix-sos';
static const String thixRetrouve = '/thix-retrouve';

// RETROUVE sous-routes
static const String thixRetrouveDetail = '/thix-retrouve/detail';
static const String thixRetrouveMesRecherches = '/thix-retrouve/mes-recherches';
static const String thixRetrouveCarte = '/thix-retrouve/carte';
static const String thixRetrouveDeclarerPerdu = '/thix-retrouve/declarer-perdu';
static const String thixRetrouveDeclarerTrouve = '/thix-retrouve/declarer-trouve';
static const String thixRetrouveAiMatch = '/thix-retrouve/ai-match';

// SOS sous-routes
static const String thixSosActif = '/thix-sos/actif';
static const String thixSosChambre = '/thix-sos/chambre';
static const String thixSosPin = '/thix-sos/pin';
static const String thixSosSecours = '/thix-sos/secours';
static const String thixSosAjouterSecours = '/thix-sos/secours/ajouter';
static const String thixSosIncidents = '/thix-sos/incidents';

  static const String call = '/call';
  static const String callIncoming = '/call/incoming';
  static const String callOutgoing = '/call/outgoing';
  static const String callOngoing = '/call/ongoing';
  static const String callHistory = '/call/history';
  static const String callIncomingName = 'callIncoming';
  static const String callOutgoingName = 'callOutgoing';
  static const String callOngoingName = 'callOngoing';
  static const String callHistoryName = 'callHistory';
  static String callWithUser(String userId) => '/call/$userId';

  static const String marketHome = '/market/home';
  static const String marketSearch = '/market/search';
  static const String marketCart = '/market/cart';
  static const String marketOrders = '/market/orders';
  static const String marketWishlist = '/market/wishlist';
  static const String marketCheckout = '/market/checkout';
  static const String marketDeliveryTracking = '/market/tracking/:orderId';

  static const String agoraAppIdKey = 'AGORA_APP_ID';
  static const int agoraTokenExpireSec = 3600;
  static const int callTimeoutSec = 45;
  static const int callRingingTimeoutSec = 30;
  static const String callChannelPrefix = 'thix_';
  static const String tableCallInvites = 'call_invites';
  static const String funcAgoraToken = 'agora-token';
  static const String thixUrgentGardiens = '/thix-urgent/config/gardiens';
  static String callChannelId(String conversationId) =>
      '$callChannelPrefix$conversationId';
  static Map<String, dynamic> callOngoingExtra({
    required String channel,
    required String name,
    required String type,
    String? inviteId,
    bool isCaller = true,
    String? avatarUrl,
    String? calleeId,
  }) =>
      {
        'channel': channel,
        'name': name,
        'type': type,
        'inviteId': inviteId,
        'isCaller': isCaller,
        'avatarUrl': avatarUrl,
        'calleeId': calleeId,
      };
  static String enterprisePortalBase(String slug) =>
      '$enterprisePortalBasePath/$slug';
  static String enterprisePortalDashboard(String slug, String section) =>
      '/company/$slug/dashboard/$section';
  static String networkChat(String userId) => '$networkChatBasePath/$userId';
  static String networkPost(String postId) => '$networkPostBasePath/$postId';
  static String networkCommunity(String communityId) =>
      '$networkCommunityBasePath/$communityId';
  static String networkProfile(String userId) =>
      '$networkProfileBasePath/$userId';
}
