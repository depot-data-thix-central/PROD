// lib/presentation/home/home_page.dart
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart'; 

import 'package:thix_id/auth/auth_controller.dart';
import 'package:thix_id/models/thix_profile.dart';
import 'package:thix_id/nav.dart';
import 'package:thix_id/presentation/common/full_screen_message.dart';
import 'package:thix_id/presentation/common/thix_identity_sheets.dart';
import 'package:thix_id/services/profile_service.dart';
import 'package:thix_id/services/notification_counters_service.dart';
import 'package:thix_id/services/thix_id_service.dart';
import 'package:thix_id/l10n/app_localizations.dart';

import 'package:thix_id/core/theme/thix_design_policy.dart';

import 'widgets/home_header_delegate.dart';
import 'widgets/home_search.dart';
import 'widgets/home_headlines_carousel.dart';
import 'widgets/home_quick_actions.dart';
import 'widgets/home_services_constellation.dart'; // Garde le même nom d'import, mais on va changer son contenu
import 'widgets/home_premium_card.dart';
import 'widgets/home_personalised.dart';
import 'widgets/account_request_sheet.dart';

class HomePagePremium extends StatefulWidget {
  const HomePagePremium({super.key});

  @override
  State<HomePagePremium> createState() => _HomePagePremiumState();
}

class _HomePagePremiumState extends State<HomePagePremium> {
  final TextEditingController _searchController = TextEditingController();
  final PageController _headlinesController = PageController();
  final NotificationCountersService _counters = NotificationCountersService();
  final ProfileService _profileService = ProfileService();

  static final RegExp _uidLikeRegex = RegExp(r'^[A-Za-z0-9-]{20,}$');
  bool _searching = false;

  bool _isAdmin = false;
  bool _uploadingBanner = false;

  @override
  void initState() {
    super.initState();
    _checkAdminRole();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _headlinesController.dispose();
    super.dispose();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // LOGIQUE ADMIN (Inchangée)
  // ══════════════════════════════════════════════════════════════════════════
  Future<void> _checkAdminRole() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    try {
      final data = await Supabase.instance.client.from('profiles').select('role, account_type').eq('id', user.id).maybeSingle();
      if (data != null && mounted) {
        final role = (data['role'] ?? data['account_type'] ?? '').toString().toLowerCase();
        if (role == 'admin' || role == 'entreprise' || role == 'support') setState(() => _isAdmin = true);
      }
    } catch (_) {}
  }

  Future<void> _showAddBannerDialog() async {
    // ... [Ton code de modale inchangé] ...
  }

  Future<void> _pickAndUploadBanner(String title, String type) async {
    // ... [Ton code d'upload inchangé] ...
  }

  // ══════════════════════════════════════════════════════════════════════════
  // LOGIQUE MÉTIER & RECHERCHE (Inchangée)
  // ══════════════════════════════════════════════════════════════════════════
  Future<void> _handleHomeSearchVerify() async {
    // ... [Ton code de recherche inchangé] ...
  }

  void _onProfileTap() {
    HapticFeedback.mediumImpact();
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) { context.push(AppRoutes.login); } else { context.go(AppRoutes.userDashboard); }
  }

  Future<void> _openThixAi() async {
    final auth = context.read<AuthController>();
    if (auth.isAuthenticated) { context.push('/thix-ia'); return; }
    context.push(AppRoutes.login);
  }

  Future<void> _openThixChat() async {
    final auth = context.read<AuthController>();
    if (auth.isAuthenticated) { context.go(AppRoutes.chat); } else { context.push(AppRoutes.login); }
  }

  Future<void> _openEmergency() async {
    final auth = context.read<AuthController>();
    if (auth.isAuthenticated) { context.push('/home-swipe'); return; }
    if (!mounted) return;
    context.push(AppRoutes.login);
  }

  void _openDocumentVault() {
    final auth = context.read<AuthController>();
    if (auth.isAuthenticated) { context.push(AppRoutes.vault); } else { context.push(AppRoutes.login); }
  }

  void _openScanQr() => ThixIdentitySheets.showQrScanSheet(context);

  void _openMiniApps() {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).t('home_mini_apps_coming_soon'))));
  }

  Future<void> _handleRequestAccount() async {
    // ... [Ton code de requête de compte inchangé] ...
  }

  void _handleServiceTap(String serviceKey) {
    // ... [Ton code de navigation inchangé] ...
    final uid = context.read<AuthController>().currentUser?.id;
    if (uid != null) {
      final counters = NotificationCountersService();
      ThixSection? section;
      switch (serviceKey) {
        case 'thixMedia': section = ThixSection.media; break;
        case 'thixMarket': section = ThixSection.market; break;
        case 'formations': section = ThixSection.formations; break;
        case 'emplois': section = ThixSection.jobs; break;
        case 'thixInfo': section = ThixSection.info; break;
        case 'opportunites': section = ThixSection.opportunities; break;
        case 'evenements': section = ThixSection.events; break;
        case 'reseauPro': section = ThixSection.network; break;
        case 'thixSante': section = ThixSection.health; break;
        case 'thixMoney': section = ThixSection.money; break;
        case 'monPays': section = ThixSection.monPays; break;
        case 'reservation': section = ThixSection.reservation; break;
      }
      if (section != null) counters.markSectionSeen(uid: uid, section: section);
    }

    switch (serviceKey) {
      case 'thixMedia': context.push(AppRoutes.thixMedia); break;
      case 'thixMarket': context.push(AppRoutes.thixMarket); break;
      case 'formations': context.push(AppRoutes.trainingHome); break;
      case 'emplois': context.push(AppRoutes.jobs); break;
      case 'thixInfo': context.push(AppRoutes.thixInfo); break;
      case 'opportunites': context.push(AppRoutes.opportunities); break;
      case 'evenements': context.push('/thix-event'); break;
      case 'reseauPro': context.go(AppRoutes.network); break;
      case 'thixSante': context.push(AppRoutes.thixSante); break;
      case 'thixMoney': context.push(AppRoutes.thixMoney); break;
      case 'monPays': context.push(AppRoutes.monPays); break;
      case 'reservation': context.push(AppRoutes.reservation); break;
      case 'thixRetrouve': context.push('/home-swipe'); break;
      default: break;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // UI ORCHESTRATION (DESIGN PREMIUM CLAIR)
  // ══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final safeTop = MediaQuery.paddingOf(context).top;

    final displayName = (auth.currentUser?.displayName.trim().isNotEmpty ?? false)
        ? auth.currentUser!.displayName.trim()
        : (auth.currentUser?.email.trim().isNotEmpty ?? false)
            ? auth.currentUser!.email.trim()
            : 'Bonjour';

    final photoUrl = auth.currentUser?.photoUrl;
    final badgeCountsStream = auth.currentUser == null
        ? Stream.value(SectionBadgeCounts.zero)
        : _counters.streamCounts(auth.currentUser!.id);

    return Scaffold(
      // 🌟 FOND CLAIR PREMIUM (Slate 50) - Fini le jaune/bleu moche
      backgroundColor: const Color(0xFFF8FAFC), 
      body: Stack(
        children: [
          // Très légère lueur bleue en haut pour ancrer le header, sans salir le reste
          Positioned(
            top: -150, left: -50, right: -50,
            child: Container(
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [ThixPolicy.primary.withOpacity(0.08), Colors.transparent],
                  stops: const [0.2, 1.0],
                )
              ),
            ),
          ),

          CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            slivers: [
              SliverPersistentHeader(
                pinned: true,
                delegate: HomeHeaderDelegate(
                  safeTop: safeTop,
                  displayName: displayName,
                  photoUrl: photoUrl,
                  isAuthenticated: auth.isAuthenticated,
                  badgeCountsStream: badgeCountsStream,
                  onProfileTap: _onProfileTap,
                  onAccountRequest: _handleRequestAccount,
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 16)),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: HomeSearch(
                    controller: _searchController,
                    isSearching: _searching,
                    onVerify: _handleHomeSearchVerify,
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 24)),

              // CARROUSEL BANNIÈRES
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      HomeHeadlinesCarousel(
                        controller: _headlinesController,
                        uid: auth.currentUser?.id,
                        onThixInfoTap: () => context.push(AppRoutes.thixInfo),
                        onOpportunityTap: () => context.push(AppRoutes.opportunities),
                      ),
                      if (_isAdmin)
                        Positioned(
                          top: 10, right: 10,
                          child: GestureDetector(
                            onTap: _uploadingBanner ? null : _showAddBannerDialog,
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(color: Colors.white.withOpacity(0.9), shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 4))]),
                              child: _uploadingBanner
                                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: ThixPolicy.primary))
                                  : const Icon(Icons.add_a_photo_rounded, size: 20, color: ThixPolicy.primaryDeep),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 24)),

              // ACTIONS RAPIDES (Refaites au design clair)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: HomeQuickActions(
                    onScanTap: _openThixAi,
                    onDocumentTap: _openDocumentVault,
                    onChatTap: _openThixChat,
                    onSecurityTap: _openEmergency,
                    badgeCountsStream: badgeCountsStream,
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 32)),

              // TITRE DE SECTION POUR L'ÉCOSYSTÈME
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24),
                  child: Text('Écosystème THIX', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF0F172A), letterSpacing: -0.5)),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 16)),

              // 🌟 LA NOUVELLE GRILLE (Fini le cercle brouillon)
              SliverToBoxAdapter(
                child: StreamBuilder<SectionBadgeCounts>(
                  stream: badgeCountsStream,
                  builder: (context, snap) {
                    final counts = snap.data ?? SectionBadgeCounts.zero;
                    return HomeServicesConstellation( // Le nom reste le même pour ne pas casser tes imports
                      counts: counts,
                      avatarUrl: photoUrl,
                      onServiceTap: _handleServiceTap,
                      onHomeTap: _onProfileTap, 
                      onMiniAppsTap: _openMiniApps,
                      onDocumentsTap: _openDocumentVault,
                      onProfileTap: _onProfileTap,
                      onScanTap: _openScanQr,
                    );
                  },
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 24)),

              const SliverToBoxAdapter(
                child: Padding(padding: EdgeInsets.symmetric(horizontal: 20), child: HomePremiumCard()),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 24)),

              const SliverToBoxAdapter(
                child: Padding(padding: EdgeInsets.symmetric(horizontal: 20), child: HomePersonalised()),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),

          if (_searching)
            Positioned.fill(
              child: ClipRRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                  child: Container(color: Colors.white.withOpacity(0.7), child: const Center(child: CircularProgressIndicator(color: ThixPolicy.primary))),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
