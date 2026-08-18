// lib/presentation/dashboard/user_dashboard_page.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:thix_id/auth/auth_controller.dart';
import 'package:thix_id/models/app_user.dart';
import 'package:thix_id/models/thix_profile.dart';
import 'package:thix_id/services/document_service.dart';
import 'package:thix_id/services/profile_service.dart';
import 'package:thix_id/services/user_service.dart';
import 'package:thix_id/presentation/common/thix_identity_sheets.dart';
import '../../nav.dart';
import '../../theme.dart';
import 'dashboard_ui.dart';
import 'dashboard_tabs.dart';
import 'dashboard_editors.dart';

// ✅ IMPORT DU BADGE DE CERTIFICATION
import 'package:thix_id/presentation/certification/widgets/certification_name_badge.dart';

// ✅ IMPORT PANEL ADMIN — accès réservé role = 'admin'
import 'package:thix_id/presentation/admin/admin_enterprise_certifications_page.dart';

// =============================================================================
// STATE MANAGEMENT
// =============================================================================

class DashboardCache {
  static final DashboardCache _i = DashboardCache._();
  DashboardCache._();
  factory DashboardCache() => _i;

  ThixProfile? lastProfile;
  DateTime? lastFetch;

  bool get isStale =>
      lastFetch == null || DateTime.now().difference(lastFetch!).inMinutes > 5;
}

class UserDashboardCtrl extends ChangeNotifier {
  final ProfileService profileService;
  final UserService userService;
  final DocumentService docsService;

  bool loading = true;
  String? error;
  ThixProfile? profile;
  AppUser? mergedUser;
  int score = 0;

  // ✅ Rôle admin — vérifié côté serveur, jamais déduit côté client
  bool isAdmin = false;

  UserDashboardCtrl({
    required this.profileService,
    required this.userService,
    required this.docsService,
  });

  Future<void> init(AppUser authUser) async {
    unawaited(userService
        .logSecurityEvent(
          uid: authUser.id,
          type: 'dashboard_open',
          label: 'Ouverture dashboard',
        )
        .catchError((_) {}));
    unawaited(
      profileService.ensureProfileExists(user: authUser).catchError((_) {}),
    );
    unawaited(_loadAdminStatus(authUser.id));

    if (!DashboardCache().isStale && DashboardCache().lastProfile != null) {
      profile = DashboardCache().lastProfile;
      _mergeAndCompute(authUser);
      loading = false;
      notifyListeners();
      unawaited(refreshSilently(authUser));
      return;
    }

    loading = true;
    error = null;
    notifyListeners();

    try {
      profile = await profileService.fetchPublicProfileByUserId(authUser.id);
      profile ??= ThixProfile.fallback(
        userId: authUser.id,
        thixId: authUser.thixId,
        displayName: authUser.displayName,
      );

      DashboardCache().lastProfile = profile;
      DashboardCache().lastFetch = DateTime.now();

      _mergeAndCompute(authUser);
    } catch (e) {
      error = 'Impossible de charger les données du profil.';
      debugPrint('UserDashboardCtrl init error: $e');
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  /// Lecture directe du rôle en base — jamais mise en cache localement,
  /// pour éviter qu'un ancien statut admin persiste après révocation.
  Future<void> _loadAdminStatus(String uid) async {
    try {
      final row = await Supabase.instance.client
          .from('profiles')
          .select('role')
          .eq('id', uid)
          .maybeSingle();
      final role = row?['role']?.toString();
      isAdmin = role == 'admin';
      notifyListeners();
    } catch (e) {
      debugPrint('Admin status check error: $e');
      isAdmin = false;
    }
  }

  Future<void> refreshSilently(AppUser authUser) async {
    try {
      final freshProfile =
          await profileService.fetchPublicProfileByUserId(authUser.id);
      if (freshProfile != null) {
        profile = freshProfile;
        DashboardCache().lastProfile = freshProfile;
        DashboardCache().lastFetch = DateTime.now();
        _mergeAndCompute(authUser);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Silent refresh error: $e');
    }
  }

  void _mergeAndCompute(AppUser authUser) {
    if (profile == null) return;

    // Priorité au vrai thix_id du profil Supabase
    final profileThix = profile!.thixId.trim();
    final resolvedThixId = (profileThix.isNotEmpty &&
            !profileThix.toUpperCase().startsWith('THIX-PENDING'))
        ? profileThix
        : authUser.thixId;

    mergedUser = authUser.copyWith(
      thixId: resolvedThixId,
      displayName: profile!.displayName,
      photoUrl: profile!.photoUrl,
      bio: profile!.bio,
      countryOrOrigin: profile!.countryOrOrigin,
      occupation: profile!.occupation,
      profession: profile!.profession,
      thixChat: profile!.thixChat,
      languages: profile!.languages,
    );

    score = authUser.thixScore ?? _computeScore(authUser, profile!);
  }

  int _computeScore(AppUser u, ThixProfile p) {
    var pts = 0;
    if (u.displayName.trim().isNotEmpty) pts += 10;
    if ((p.bio ?? '').trim().length > 40) pts += 15;
    if ((p.occupation ?? '').trim().isNotEmpty) pts += 10;
    if (p.education.isNotEmpty) pts += 20;
    if (p.experience.isNotEmpty) pts += 20;
    if (p.skills.isNotEmpty) pts += 15;
    if (p.languages.isNotEmpty) pts += 10;
    return pts.clamp(0, 100);
  }
}

// =============================================================================
// PAGE DASHBOARD
// =============================================================================

class ThixUserDashboardPage extends StatefulWidget {
  const ThixUserDashboardPage({super.key});
  @override
  State<ThixUserDashboardPage> createState() => _ThixUserDashboardPageState();
}

class _ThixUserDashboardPageState extends State<ThixUserDashboardPage> {
  late final ProfileService _profileService;
  late final UserService _userService;
  late final DocumentService _docsService;
  late final UserDashboardCtrl _ctrl;

  final _docFilter = ValueNotifier<String>('Tous');

  @override
  void initState() {
    super.initState();
    _profileService = ProfileService();
    _userService = UserService(Supabase.instance.client);
    _docsService = DocumentService();

    _ctrl = UserDashboardCtrl(
      profileService: _profileService,
      userService: _userService,
      docsService: _docsService,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final me = context.read<AuthController>().currentUser;
      if (me != null) _ctrl.init(me);
    });
  }

  @override
  void dispose() {
    _docFilter.dispose();
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _logout() async {
    await context.read<AuthController>().signOut();
    if (mounted) context.go(AppRoutes.home);
  }

  void _openAdminPanel() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const AdminEnterpriseCertificationsPage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final me = context.watch<AuthController>().currentUser;
    if (me == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF0D2CC1)),
        ),
      );
    }

    return ChangeNotifierProvider.value(
      value: _ctrl,
      // CORRECTION : Passage de length à 5 onglets
      child: DefaultTabController(
        length: 5, 
        child: Scaffold(
          backgroundColor: const Color(0xFFF5F6FB),
          body: Consumer<UserDashboardCtrl>(
            builder: (context, ctrl, _) {
              if (ctrl.loading && ctrl.profile == null) {
                return const Center(
                  child: CircularProgressIndicator(color: Color(0xFF0D2CC1)),
                );
              }

              if (ctrl.error != null && ctrl.profile == null) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(ctrl.error!, style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: () => ctrl.init(me),
                        child: const Text('Réessayer'),
                      ),
                    ],
                  ),
                );
              }

              final profile = ctrl.profile!;
              final mergedUser = ctrl.mergedUser!;
              final score = ctrl.score;

              // CORRECTION : On utilise profile.photoUrl pour coverUrl puisqu'il n'y a pas de coverUrl dans ThixProfile
              final coverUrl = (profile.photoUrl ?? '')
                  .toString()
                  .trim();
              final avatarUrl = (mergedUser.photoUrl ?? '').toString().trim();

              return SafeArea(
                top: false,
                child: RefreshIndicator(
                  color: const Color(0xFF0D2CC1),
                  onRefresh: () => ctrl.refreshSilently(me),
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      // ── HEADER COMPACT + PHOTO DE COUVERTURE ──
                      SliverToBoxAdapter(
                        child: _CompactCoverHeader(
                          coverUrl: coverUrl,
                          avatarUrl: avatarUrl,
                          displayName: mergedUser.displayName,
                          thixId: mergedUser.thixId,
                          bio: (mergedUser.bio ?? '').toString(),
                          country: (mergedUser.countryOrOrigin ?? '').toString(),
                          profession: (mergedUser.occupation ??
                                  mergedUser.profession ??
                                  '')
                              .toString(),
                          score: score,
                          isAdmin: ctrl.isAdmin,
                          onBack: () => context.go(AppRoutes.home),
                          onSettings: () => context.push(AppRoutes.settings),
                          onLogout: _logout,
                          onAdminPanel: _openAdminPanel,
                          onEditProfile: () async {
                            await ProfileEditorSheet.show(
                              context,
                              profile: profile,
                              profileService: _profileService,
                              authUser: me,
                            );
                            if (context.mounted) ctrl.refreshSilently(me);
                          },
                        ),
                      ),

                      // ── TABS ──
                      const SliverToBoxAdapter(
                        child: DashboardTabsHeader(), // Assurez-vous que le DashboardTabsHeader définit bien 5 Tab()
                      ),

                      // ── CONTENU ONGLET (hauteur réduite) ──
                      SliverFillRemaining(
                        hasScrollBody: true,
                        // CORRECTION : Seulement 5 KeepAliveWrapper pour correspondre au DefaultTabController(length: 5)
                        child: TabBarView(
                          children: [
                            KeepAliveWrapper(
                              child: ProfileTab(
                                authUser: me,
                                profile: profile,
                                score: score,
                                profileService: _profileService,
                                userService: _userService,
                              ),
                            ),
                            KeepAliveWrapper(
                              child: ValueListenableBuilder(
                                valueListenable: _docFilter,
                                builder: (_, filter, __) => DocumentsTab(
                                  uid: me.id,
                                  docs: _docsService,
                                  userService: _userService,
                                  filter: filter,
                                  onChangeFilter: (v) =>
                                      _docFilter.value = v,
                                ),
                              ),
                            ),
                            KeepAliveWrapper(
                              child: ExperienceSkillsTab(
                                profile: profile,
                                profileService: _profileService,
                              ),
                            ),
                            KeepAliveWrapper(
                              child: PaymentsTab(
                                uid: me.id,
                                userService: _userService,
                                user: me,
                              ),
                            ),
                            KeepAliveWrapper(
                              child: SecurityTab(
                                uid: me.id,
                                user: me,
                                userService: _userService,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => ThixIdentitySheets.showQrScanSheet(context),
            icon: const Icon(Icons.qr_code_scanner_rounded, color: Colors.white, size: 18),
            label: const Text(
              'Scanner ID',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 13,
              ),
            ),
            backgroundColor: const Color(0xFF0D2CC1),
            elevation: 4,
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// HEADER COMPACT AVEC PHOTO DE COUVERTURE RÉELLE
// =============================================================================

class _CompactCoverHeader extends StatelessWidget {
  final String coverUrl;
  final String avatarUrl;
  final String displayName;
  final String thixId;
  final String bio;
  final String country;
  final String profession;
  final int score;
  final bool isAdmin;
  final VoidCallback onBack;
  final VoidCallback onSettings;
  final Future<void> Function() onLogout;
  final VoidCallback onEditProfile;
  final VoidCallback onAdminPanel;

  const _CompactCoverHeader({
    required this.coverUrl,
    required this.avatarUrl,
    required this.displayName,
    required this.thixId,
    required this.bio,
    required this.country,
    required this.profession,
    required this.score,
    required this.isAdmin,
    required this.onBack,
    required this.onSettings,
    required this.onLogout,
    required this.onEditProfile,
    required this.onAdminPanel,
  });

  bool get _hasCover => coverUrl.isNotEmpty;
  bool get _hasAvatar => avatarUrl.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;

    return Column(
      children: [
        // ── ZONE COUVERTURE (hauteur réduite \~140px + safe area) ──
        SizedBox(
          height: topPad + 130,
          width: double.infinity,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Photo de couverture RÉELLE (pas mock-up)
              if (_hasCover)
                Image.network(
                  coverUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _fallbackCover(),
                )
              else
                _fallbackCover(),

              // Overlay sombre léger pour lisibilité des boutons
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.35),
                      Colors.black.withOpacity(0.05),
                    ],
                  ),
                ),
              ),

              // Boutons : retour | [admin] | déconnexion | settings
              Positioned(
                top: topPad + 8,
                left: 12,
                right: 12,
                child: Row(
                  children: [
                    _RoundIconBtn(
                      icon: Icons.arrow_back_ios_new_rounded,
                      onTap: onBack,
                    ),
                    const Spacer(),
                    // ✅ Visible uniquement si role = 'admin' (vérifié côté serveur)
                    if (isAdmin) ...[
                      _RoundIconBtn(
                        icon: Icons.admin_panel_settings_rounded,
                        onTap: onAdminPanel,
                      ),
                      const SizedBox(width: 8),
                    ],
                    // ❌ Chat retiré → Déconnexion
                    _RoundIconBtn(
                      icon: Icons.logout_rounded,
                      onTap: () => onLogout(),
                    ),
                    const SizedBox(width: 8),
                    _RoundIconBtn(
                      icon: Icons.settings_rounded,
                      onTap: onSettings,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // ── CARTE PROFIL COMPACTE (chevauche la couverture) ──
        Transform.translate(
          offset: const Offset(0, -36),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Column(
              children: [
                // Avatar centré + badge score
                Stack(
                  alignment: Alignment.bottomCenter,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.12),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: CircleAvatar(
                        radius: 36,
                        backgroundColor: const Color(0xFFEFF4FF),
                        backgroundImage:
                            _hasAvatar ? NetworkImage(avatarUrl) : null,
                        child: !_hasAvatar
                            ? const Icon(
                                Icons.person,
                                size: 36,
                                color: Colors.grey,
                              )
                            : null,
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0D2CC1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                        child: Text(
                          '$score pts',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                // ✅ NOM DE L'UTILISATEUR + BADGE CERTIFICATION THIX
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        displayName.isEmpty ? 'Utilisateur' : displayName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 18, // Légèrement agrandi pour le dashboard
                          color: Color(0xFF0A1E8A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    ),
                    // Sceau de certification (récupère automatiquement via Riverpod pour l'utilisateur courant)
                    const CertificationNameBadge(
                      showLabel: false, // Sceau seul
                      iconSize: 20, // Plus grand sur le propre profil
                      padding: EdgeInsets.only(left: 6),
                    ),
                  ],
                ),

                const SizedBox(height: 2),

                // THIX ID (compact)
                Text(
                  thixId,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.black54,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 4),

                // Bio courte
                if (bio.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      bio,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: Colors.black87,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  )
                else
                  const Text(
                    'Complétez votre biographie…',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: Colors.black45,
                      fontStyle: FontStyle.italic,
                    ),
                  ),

                const SizedBox(height: 6),

                // Localisation + Profession
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (country.isNotEmpty) ...[
                      const Icon(Icons.location_on_outlined,
                          size: 13, color: Colors.black45),
                      const SizedBox(width: 2),
                      Flexible(
                        child: Text(
                          country,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.black54,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                    if (country.isNotEmpty && profession.isNotEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 6),
                        child: Text('•',
                            style: TextStyle(color: Colors.black38)),
                      ),
                    if (profession.isNotEmpty) ...[
                      const Icon(Icons.work_outline_rounded,
                          size: 13, color: Colors.black45),
                      const SizedBox(width: 2),
                      Flexible(
                        child: Text(
                          profession,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.black54,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),

                const SizedBox(height: 10),

                // Bouton Modifier (compact)
                SizedBox(
                  height: 34,
                  child: OutlinedButton.icon(
                    onPressed: onEditProfile,
                    icon: const Icon(Icons.edit_rounded, size: 14),
                    label: const Text(
                      'Modifier le profil',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF0D2CC1),
                      side: BorderSide(
                        color: const Color(0xFF0D2CC1).withOpacity(0.3),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 4),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _fallbackCover() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0D2CC1), Color(0xFF0A1E8A)],
        ),
      ),
    );
  }
}

class _RoundIconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _RoundIconBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withOpacity(0.92),
      shape: const CircleBorder(),
      elevation: 2,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 36,
          height: 36,
          child: Icon(icon, size: 16, color: const Color(0xFF0A1E8A)),
        ),
      ),
    );
  }
}

// =============================================================================
// KEEP ALIVE
// =============================================================================

class KeepAliveWrapper extends StatefulWidget {
  final Widget child;
  const KeepAliveWrapper({super.key, required this.child});
  @override
  State<KeepAliveWrapper> createState() => _KeepAliveWrapperState();
}

class _KeepAliveWrapperState extends State<KeepAliveWrapper>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
