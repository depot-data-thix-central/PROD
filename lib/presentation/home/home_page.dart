// lib/presentation/home/home_page.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart'; // ✅ Nécessaire pour choisir la photo

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
      builder: (ctx) => AlertDialog(
        backgroundColor: ThixPolicy.surface,
        title: const Text('Nouvelle annonce', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleCtrl,
              decoration: const InputDecoration(labelText: 'Titre de l\'annonce', border: OutlineInputBorder())
            ),
            const SizedBox(height: 12),
            TextField(
              controller: typeCtrl,
              decoration: const InputDecoration(labelText: 'Tag (ex: Opportunité, Info)', border: OutlineInputBorder())
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler', style: TextStyle(color: ThixPolicy.textSecondary))
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: ThixPolicy.primary),
            onPressed: () {
              Navigator.pop(ctx);
              _pickAndUploadBanner(titleCtrl.text.trim(), typeCtrl.text.trim());
            },
            child: const Text('Choisir une photo', style: TextStyle(color: Colors.white)),
          )
        ],
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

      // 1. Upload sur le Storage (Assure-toi d'avoir un bucket public nommé 'banners')
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
      context.push('/thix_ia');
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
    context.push('/home-swipe'); // sélecteur SOS ↔ RETROUVE
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
        case 'thixMedia':
          section = ThixSection.media;
          break;
        case 'thixMarket':
          section = ThixSection.market;
          break;
        case 'formations':
          section = ThixSection.formations;
          break;
        case 'emplois':
          section = ThixSection.jobs;
          break;
        case 'thixInfo':
          section = ThixSection.info;
          break;
        case 'opportunites':
          section = ThixSection.opportunities;
          break;
        case 'evenements':
          section = ThixSection.events;
          break;
        case 'reseauPro':
          section = ThixSection.network;
          break;
        case 'thixSante':
          section = ThixSection.health;
          break;
        case 'thixMoney':
          section = ThixSection.money;
          break;
        case 'monPays':
          section = ThixSection.monPays;
          break;
        case 'reservation':
          section = ThixSection.reservation;
          break;
      }
      if (section != null) {
        counters.markSectionSeen(uid: uid, section: section);
      }
    }

    switch (serviceKey) {
      case 'thixMedia':
        context.push(AppRoutes.thixMedia);
        break;
      case 'thixMarket':
        context.push(AppRoutes.thixMarket);
        break;
      case 'formations':
        context.push(AppRoutes.trainingHome);
        break;
      case 'emplois':
        context.push(AppRoutes.jobs);
        break;
      case 'thixInfo':
        context.push(AppRoutes.thixInfo);
        break;
      case 'opportunites':
        context.push(AppRoutes.opportunities);
        break;
      case 'evenements':
        context.push('/thix-event');
        break;
      case 'reseauPro':
        context.go(AppRoutes.network);
        break;
      case 'thixSante':
        context.push(AppRoutes.thixSante);
        break;
      case 'thixMoney':
        context.push(AppRoutes.thixMoney);
        break;
      case 'monPays':
        context.push(AppRoutes.monPays);
        break;
      case 'reservation':
        context.push(AppRoutes.reservation);
        break;
      case 'thixRetrouve':
        // Sélecteur SOS ↔ RETROUVE
        context.push('/home-swipe');
        break;
      default:
        break;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // UI ORCHESTRATION
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
      backgroundColor: ThixPolicy.surface,
      body: Stack(
        children: [
          const HomeSoftBackground(),

          CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
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

              // ✅ CARROUSEL AVEC BOUTON ADMIN SUPERPOSÉ
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

                      // Affichage du bouton de configuration uniquement pour les admins
                      if (_isAdmin)
                        Positioned(
                          top: 10,
                          right: 10,
                          child: GestureDetector(
                            onTap: _uploadingBanner ? null : _showAddBannerDialog,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.15),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: _uploadingBanner
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: ThixPolicy.primary)
                                    )
                                  : const Icon(Icons.add_a_photo_rounded, size: 20, color: ThixPolicy.primary),
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

              const SliverToBoxAdapter(child: SizedBox(height: ThixPolicy.s8)),

              SliverToBoxAdapter(
                child: StreamBuilder<SectionBadgeCounts>(
                  stream: badgeCountsStream,
                  builder: (context, snap) {
                    final counts = snap.data ?? SectionBadgeCounts.zero;
                    return HomeServicesConstellation(
                      counts: counts,
                      avatarUrl: photoUrl,
                      onServiceTap: _handleServiceTap,
                      onHomeTap: () => context.go(AppRoutes.home),
                      onMiniAppsTap: _openMiniApps,
                      onDocumentsTap: _openDocumentVault,
                      onProfileTap: _onProfileTap,
                      onScanTap: _openScanQr,
                    );
                  },
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: ThixPolicy.s8)),

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
              child: Container(
                color: Colors.black.withValues(alpha: 0.4),
                child: const Center(
                  child: CircularProgressIndicator(color: ThixPolicy.primary),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
