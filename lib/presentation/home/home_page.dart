// lib/presentation/home/home_page.dart
import 'dart:io';
import 'dart:ui'; // ✅ Nécessaire pour ImageFilter (Glassmorphism)
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

// THIX DESIGN SYSTEM v1
import 'package:thix_id/core/theme/thix_design_policy.dart';

// WIDGETS
import 'widgets/home_background.dart';
import 'widgets/home_header_delegate.dart';
import 'widgets/home_search.dart';
import 'widgets/home_headlines_carousel.dart';
import 'widgets/home_quick_actions.dart';
import 'widgets/home_services_constellation.dart';
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

  // ✅ Variables pour la gestion Admin
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
  // LOGIQUE ADMIN (Bannières)
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _checkAdminRole() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    try {
      final data = await Supabase.instance.client
          .from('profiles')
          .select('role, account_type')
          .eq('id', user.id)
          .maybeSingle();

      if (data != null && mounted) {
        final role = (data['role'] ?? data['account_type'] ?? '').toString().toLowerCase();
        if (role == 'admin' || role == 'entreprise' || role == 'support') {
          setState(() => _isAdmin = true);
        }
      }
    } catch (_) {
      // Ignorer silencieusement si erreur
    }
  }

  Future<void> _showAddBannerDialog() async {
    final titleCtrl = TextEditingController();
    final typeCtrl = TextEditingController(text: 'À la une');

    await showDialog(
      context: context,
      builder: (ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: AlertDialog(
          backgroundColor: Colors.white.withOpacity(0.95),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: Colors.white.withOpacity(0.8)),
          ),
          title: const Text('Nouvelle annonce', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: ThixPolicy.textMain)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                decoration: InputDecoration(
                  labelText: 'Titre de l\'annonce', 
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.5),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                )
              ),
              const SizedBox(height: 12),
              TextField(
                controller: typeCtrl,
                decoration: InputDecoration(
                  labelText: 'Tag (ex: Opportunité, Info)', 
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.5),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                )
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler', style: TextStyle(color: ThixPolicy.textSecondary))
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: ThixPolicy.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              onPressed: () {
                Navigator.pop(ctx);
                _pickAndUploadBanner(titleCtrl.text.trim(), typeCtrl.text.trim());
              },
              child: const Text('Choisir une photo', style: TextStyle(color: Colors.white)),
            )
          ],
        ),
      )
    );
  }

  Future<void> _pickAndUploadBanner(String title, String type) async {
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.image);
      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      final bytes = file.bytes ?? (file.path != null ? await File(file.path!).readAsBytes() : null);
      if (bytes == null) return;

      setState(() => _uploadingBanner = true);

      final ext = file.extension ?? 'jpg';
      final fileName = 'banner_${DateTime.now().millisecondsSinceEpoch}.$ext';
      final storagePath = 'annonces/$fileName';

      // 1. Upload sur le Storage
      await Supabase.instance.client.storage
          .from('banners')
          .uploadBinary(storagePath, bytes);

      final publicUrl = Supabase.instance.client.storage
          .from('banners')
          .getPublicUrl(storagePath);

      // 2. Insertion dans la table 'banners'
      await Supabase.instance.client.from('banners').insert({
        'image_url': publicUrl,
        'title': title.isEmpty ? 'Nouvelle annonce' : title,
        'tag': type.isEmpty ? 'À la une' : type,
        'is_active': true,
        'created_at': DateTime.now().toIso8601String(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bannière ajoutée avec succès ! Rafraîchissement requis.'), backgroundColor: ThixPolicy.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de l\'upload : $e'), backgroundColor: ThixPolicy.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingBanner = false);
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // LOGIQUE MÉTIER & RECHERCHE
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _handleHomeSearchVerify() async {
    final l10n = AppLocalizations.of(context);
    final raw = _searchController.text.trim();

    if (raw.isEmpty) {
      await FullScreenMessage.showError(context, title: l10n.t('home_required_id_title'), message: l10n.t('home_required_id_msg'));
      return;
    }

    final normalized = ThixIdService.normalize(raw);
    final isThix = normalized.startsWith('THIX-');
    final isUid = _uidLikeRegex.hasMatch(raw);

    if (!isThix && !isUid) {
      await FullScreenMessage.showError(context, title: l10n.t('home_invalid_id_title'), message: l10n.t('home_invalid_id_msg'));
      return;
    }

    setState(() => _searching = true);

    try {
      ThixProfile? profile;
      if (isThix) {
        profile = await _profileService.fetchPublicProfileByThixId(normalized);
      } else {
        profile = await _profileService.fetchPublicProfileByUserId(raw);
      }

      if (!mounted) return;
      if (profile == null) {
        await FullScreenMessage.showError(context, title: l10n.t('home_profile_not_found_title'), message: l10n.t('home_profile_not_found_msg'));
        return;
      }

      final thix = profile.thixId.trim().toUpperCase();
      if (thix.isNotEmpty) {
        context.push('${AppRoutes.publicProfile}?thixId=$thix');
      } else {
        await ThixIdentitySheets.showVerifySheet(context, initialUidOrThixId: profile.userId);
      }
    } catch (e) {
      if (!mounted) return;
      await FullScreenMessage.showError(context, title: l10n.t('home_verify_error_title'), message: l10n.t('home_verify_error_msg'));
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // NAVIGATION & ACTIONS
  // ══════════════════════════════════════════════════════════════════════════

  void _onProfileTap() {
    HapticFeedback.mediumImpact();
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      context.push(AppRoutes.login);
    } else {
      context.go(AppRoutes.userDashboard);
    }
  }

  Future<void> _openThixAi() async {
    final auth = context.read<AuthController>();
    if (auth.isAuthenticated) {
      context.push('/thix-ia');
      return;
    }
    context.push(AppRoutes.login);
  }

  Future<void> _openThixChat() async {
    final auth = context.read<AuthController>();
    if (auth.isAuthenticated) {
      context.go(AppRoutes.chat);
    } else {
      context.push(AppRoutes.login);
    }
  }

  Future<void> _openEmergency() async {
    final auth = context.read<AuthController>();
    if (auth.isAuthenticated) {
      context.push('/home-swipe'); 
      return;
    }
    if (!mounted) return;
    context.push(AppRoutes.login);
  }

  void _openDocumentVault() {
    final auth = context.read<AuthController>();
    if (auth.isAuthenticated) {
      context.push(AppRoutes.vault);
    } else {
      context.push(AppRoutes.login);
    }
  }

  void _openScanQr() => ThixIdentitySheets.showQrScanSheet(context);

  void _openMiniApps() {
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.t('home_mini_apps_coming_soon')))
    );
  }

  Future<void> _handleRequestAccount() async {
    final auth = context.read<AuthController>();
    final res = await showModalBottomSheet<AccountRequestChoice>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => const AccountRequestSheet()
    );

    switch (res) {
      case AccountRequestChoice.personal:
        if (auth.isAuthenticated) { await auth.signOut(); }
        if (mounted) { context.push(AppRoutes.personalReg); }
        return;
      case null:
        return;
    }
  }

  void _handleServiceTap(String serviceKey) {
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
      if (section != null) {
        counters.markSectionSeen(uid: uid, section: section);
      }
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
  // UI ORCHESTRATION
  // ══════════════════════════════════════════════════════════════════════════

  // Assistant pour les orbes de fond (Premium Corporate)
  Widget _buildBlurOrb(Color color, double size) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 60, sigmaY: 60), 
        child: Container(color: Colors.transparent)
      ),
    );
  }

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
      backgroundColor: const Color(0xFFF7F8FA), // Fond ultra clean, légèrement gris bleuté (Corporate)
      body: Stack(
        children: [
          // Orbes décoratifs en arrière-plan pour l'effet Premium discret
          Positioned(top: -100, right: -50, child: _buildBlurOrb(ThixPolicy.primary.withOpacity(0.04), 300)),
          Positioned(bottom: 200, left: -100, child: _buildBlurOrb(ThixPolicy.primaryDeep.withOpacity(0.03), 350)),

          const HomeSoftBackground(), // Conservé pour d'éventuelles vagues de fond très douces

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

              const SliverToBoxAdapter(child: SizedBox(height: ThixPolicy.s12)),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s20),
                  child: HomeSearch(
                    controller: _searchController,
                    isSearching: _searching,
                    onVerify: _handleHomeSearchVerify,
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: ThixPolicy.s12)),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s20),
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
                          top: 10,
                          right: 10,
                          child: GestureDetector(
                            onTap: _uploadingBanner ? null : _showAddBannerDialog,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                                child: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.7),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white.withOpacity(0.9), width: 1.5),
                                    boxShadow: [
                                      BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 8, offset: const Offset(0, 4)),
                                    ],
                                  ),
                                  child: _uploadingBanner
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(strokeWidth: 2, color: ThixPolicy.primary)
                                        )
                                      : const Icon(Icons.add_a_photo_rounded, size: 20, color: ThixPolicy.primaryDeep),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: ThixPolicy.s12)),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s20),
                  child: HomeQuickActions(
                    onScanTap: _openThixAi,
                    onDocumentTap: _openDocumentVault,
                    onChatTap: _openThixChat,
                    onSecurityTap: _openEmergency,
                    badgeCountsStream: badgeCountsStream,
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: ThixPolicy.s12)), // Un peu plus d'espace

              SliverToBoxAdapter(
                child: StreamBuilder<SectionBadgeCounts>(
                  stream: badgeCountsStream,
                  builder: (context, snap) {
                    final counts = snap.data ?? SectionBadgeCounts.zero;
                    return HomeServicesConstellation(
                      counts: counts,
                      avatarUrl: photoUrl,
                      onServiceTap: _handleServiceTap,
                      // ✅ Le tap sur le centre ouvre directement le profil (on passe la même fonction)
                      onHomeTap: _onProfileTap, 
                      onMiniAppsTap: _openMiniApps,
                      onDocumentsTap: _openDocumentVault,
                      onProfileTap: _onProfileTap,
                      onScanTap: _openScanQr,
                    );
                  },
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: ThixPolicy.s12)),

              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: ThixPolicy.s20),
                  child: HomePremiumCard(),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: ThixPolicy.s12)),

              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: ThixPolicy.s20),
                  child: HomePersonalised(),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),

          if (_searching)
            Positioned.fill(
              child: ClipRRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    color: Colors.white.withOpacity(0.6), // Overlay premium
                    child: const Center(
                      child: CircularProgressIndicator(color: ThixPolicy.primary),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
