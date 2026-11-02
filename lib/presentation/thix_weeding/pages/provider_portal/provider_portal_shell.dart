// lib/presentation/thix_weeding/pages/provider_portal/provider_portal_shell.dart
// ============================================================================
// THIX WEDDING PROVIDER PORTAL SHELL (PRODUCTION ENTERPRISE)
// ✅ Navigation par onglets (Dashboard, Galerie, Réservations, Tâches, Profil)
// ✅ Design glassmorphism blanc/rose premium
// ✅ Support deep-link via initialTab
// ✅ FIX : Gestion correcte des comptes sans auth (inscription libre)
// ============================================================================
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/provider_models.dart';
import '../../providers/provider_providers.dart';
import 'provider_dashboard_page.dart';
import 'provider_media_pages.dart';
import 'provider_business_pages.dart';

// ═══════════════════════════════════════════════════════════════════════════
// PALETTE GLASSMORPHISM
// ═══════════════════════════════════════════════════════════════════════════
class _P {
  static const Color bg = Color(0xFFFAFAFA);
  static const Color surface = Colors.white;
  static const Color glass = Color(0xFFF5F5F5);
  static const Color rose = Color(0xFFFF4D6D);
  static const Color roseLight = Color(0xFFFF85A1);
  static const Color roseSoft = Color(0xFFFFF0F3);
  static const Color ink = Color(0xFF1A1A2E);
  static const Color inkSoft = Color(0xFF6B7280);
  static const Color line = Color(0xFFE5E7EB);
  static const Color green = Color(0xFF10B981);
  static const Color amber = Color(0xFFF59E0B);
  static const Color red = Color(0xFFEF4444);
}

// ═══════════════════════════════════════════════════════════════════════════
// SHELL PRINCIPAL
// ═══════════════════════════════════════════════════════════════════════════
class ProviderPortalShell extends ConsumerStatefulWidget {
  /// Permet d'ouvrir directement un onglet via deep-link
  /// 0 = Dashboard, 1 = Galerie, 2 = Réservations, 3 = Tâches, 4 = Profil
  final int initialTab;

  const ProviderPortalShell({super.key, this.initialTab = 0});

  @override
  ConsumerState<ProviderPortalShell> createState() => _ProviderPortalShellState();
}

class _ProviderPortalShellState extends ConsumerState<ProviderPortalShell> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialTab.clamp(0, 4);
  }

  @override
  void didUpdateWidget(covariant ProviderPortalShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialTab != widget.initialTab) {
      setState(() => _currentIndex = widget.initialTab.clamp(0, 4));
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;

    // ✅ CAS 1 : Pas de user auth → afficher écran de connexion
    if (user == null) {
      return const _NoUserScreen();
    }

    // ✅ CAS 2 : User auth existant → charger le profil prestataire
    final providerAsync = ref.watch(currentProviderProvider(user.id));

    return providerAsync.when(
      data: (provider) {
        // ✅ CAS 2a : Profil prestataire trouvé → afficher le shell complet
        if (provider != null) {
          return Scaffold(
            backgroundColor: _P.bg,
            body: IndexedStack(
              index: _currentIndex,
              children: [
                ProviderDashboardPage(provider: provider),
                ProviderGalleryPage(provider: provider),
                ProviderReservationsPage(provider: provider),
                ProviderTasksPage(provider: provider),
                _ProfileTab(provider: provider),
              ],
            ),
            bottomNavigationBar: _BottomNavBar(
              currentIndex: _currentIndex,
              onTap: (index) {
                HapticFeedback.selectionClick();
                setState(() => _currentIndex = index);
              },
            ),
          );
        }

        // ✅ CAS 2b : User auth mais pas de profil prestataire
        return const _NoProviderScreen();
      },
      loading: () => const _LoadingScreen(),
      error: (error, stack) => _ErrorScreen(
        error: error,
        onRetry: () => ref.invalidate(currentProviderProvider(user.id)),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// BOTTOM NAVIGATION BAR
// ═══════════════════════════════════════════════════════════════════════════
class _BottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _BottomNavBar({required this.currentIndex, required this.onTap});

  static const _items = <_NavItemConfig>[
    _NavItemConfig(icon: Icons.dashboard_outlined, activeIcon: Icons.dashboard, label: 'Dashboard'),
    _NavItemConfig(icon: Icons.photo_library_outlined, activeIcon: Icons.photo_library, label: 'Galerie'),
    _NavItemConfig(icon: Icons.event_outlined, activeIcon: Icons.event, label: 'Réservations'),
    _NavItemConfig(icon: Icons.task_outlined, activeIcon: Icons.task, label: 'Tâches'),
    _NavItemConfig(icon: Icons.person_outline, activeIcon: Icons.person, label: 'Profil'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, -4))],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              for (int i = 0; i < _items.length; i++)
                _NavItem(config: _items[i], isActive: currentIndex == i, onTap: () => onTap(i)),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItemConfig {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const _NavItemConfig({required this.icon, required this.activeIcon, required this.label});
}

class _NavItem extends StatelessWidget {
  final _NavItemConfig config;
  final bool isActive;
  final VoidCallback onTap;

  const _NavItem({required this.config, required this.isActive, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                padding: EdgeInsets.all(isActive ? 8 : 6),
                decoration: BoxDecoration(
                  color: isActive ? _P.roseSoft : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(isActive ? config.activeIcon : config.icon, size: isActive ? 22 : 20, color: isActive ? _P.rose : _P.inkSoft),
              ),
              const SizedBox(height: 4),
              Text(config.label, style: GoogleFonts.inter(fontSize: 10, fontWeight: isActive ? FontWeight.w800 : FontWeight.w500, color: isActive ? _P.rose : _P.inkSoft)),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// PROFIL TAB
// ═══════════════════════════════════════════════════════════════════════════
class _ProfileTab extends ConsumerWidget {
  final ThixProviderModel provider;
  const _ProfileTab({required this.provider});

  Future<void> _logout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Déconnexion', style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: _P.ink)),
        content: Text('Voulez-vous vraiment vous déconnecter ?', style: GoogleFonts.inter(color: _P.inkSoft)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Annuler', style: GoogleFonts.inter(color: _P.inkSoft))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: _P.red, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: Text('Déconnexion', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await Supabase.instance.client.auth.signOut();
      if (context.mounted) context.go('/thix-weeding');
    }
  }

  void _copyCode(BuildContext context) {
    Clipboard.setData(ClipboardData(text: provider.uniqueCode));
    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Code ${provider.uniqueCode} copié', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600)),
        backgroundColor: _P.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topPad = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: _P.bg,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Container(
              padding: EdgeInsets.fromLTRB(20, topPad + 30, 20, 30),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [_P.rose, _P.roseLight], begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(32), bottomRight: Radius.circular(32)),
              ),
              child: Column(
                children: [
                  Container(
                    width: 90, height: 90,
                    decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 4), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 12, offset: const Offset(0, 4))]),
                    child: CircleAvatar(radius: 41, backgroundColor: Colors.white, child: Text(provider.businessName.isNotEmpty ? provider.businessName[0].toUpperCase() : 'P', style: GoogleFonts.inter(fontSize: 36, fontWeight: FontWeight.w900, color: _P.rose))),
                  ),
                  const SizedBox(height: 16),
                  Text(provider.businessName, style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.5)),
                  const SizedBox(height: 6),
                  Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(12)), child: Text(provider.category.displayName, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white))),
                  const SizedBox(height: 20),
                  GestureDetector(
                    onTap: () => _copyCode(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 12, offset: const Offset(0, 4))]),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.qr_code_2, color: _P.rose, size: 22),
                        const SizedBox(width: 10),
                        Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                          Text('Votre code Thix', style: GoogleFonts.inter(fontSize: 10, color: _P.inkSoft, fontWeight: FontWeight.w600)),
                          Text(provider.uniqueCode, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w900, color: _P.ink, letterSpacing: 1)),
                        ]),
                        const SizedBox(width: 10),
                        const Icon(Icons.copy_rounded, color: _P.inkSoft, size: 18),
                      ]),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.all(16), child: _VerificationStatusCard(status: provider.verificationStatus, level: provider.level))),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(children: [
                Expanded(child: _QuickStatCard(title: 'Note', value: provider.rating.toStringAsFixed(1), icon: Icons.star_rounded, color: Colors.amber)),
                const SizedBox(width: 12),
                Expanded(child: _QuickStatCard(title: 'Avis', value: '${provider.reviewCount}', icon: Icons.rate_review_outlined, color: _P.rose)),
              ]),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _MenuItem(icon: Icons.edit_outlined, label: 'Modifier mes informations', onTap: () { HapticFeedback.selectionClick(); }),
                _MenuItem(icon: Icons.document_scanner_outlined, label: 'Mes documents de validation', badge: provider.verificationStatus == ProviderVerificationStatus.pending ? 'En attente' : null, onTap: () { HapticFeedback.selectionClick(); }),
                _MenuItem(icon: Icons.payments_outlined, label: 'Mes revenus', onTap: () {}),
                _MenuItem(icon: Icons.notifications_outlined, label: 'Préférences de notifications', onTap: () {}),
                _MenuItem(icon: Icons.help_outline, label: 'Aide & Support', onTap: () {}),
                const SizedBox(height: 8),
                _MenuItem(icon: Icons.logout, label: 'Se déconnecter', color: _P.red, onTap: () => _logout(context)),
                const SizedBox(height: 24),
                Center(child: Text('Thix Wedding v5.0', style: GoogleFonts.inter(fontSize: 11, color: _P.inkSoft, fontWeight: FontWeight.w500))),
                const SizedBox(height: 40),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _VerificationStatusCard extends StatelessWidget {
  final ProviderVerificationStatus status;
  final TrackingLevel level;
  const _VerificationStatusCard({required this.status, required this.level});

  @override
  Widget build(BuildContext context) {
    Color bgColor; Color iconColor; IconData iconData; String title; String subtitle;
    switch (status) {
      case ProviderVerificationStatus.pending:
        bgColor = const Color(0xFFFFFBEB); iconColor = const Color(0xFFD97706); iconData = Icons.hourglass_empty; title = 'Validation en cours'; subtitle = 'Notre équipe examine votre dossier (24-48h)'; break;
      case ProviderVerificationStatus.verified:
        bgColor = const Color(0xFFECFDF5); iconColor = const Color(0xFF059669); iconData = Icons.verified; title = 'Compte ${level.displayName}'; subtitle = 'Votre profil est vérifié et visible'; break;
      case ProviderVerificationStatus.rejected:
        bgColor = const Color(0xFFFEF2F2); iconColor = const Color(0xFFDC2626); iconData = Icons.error_outline; title = 'Dossier rejeté'; subtitle = 'Veuillez mettre à jour vos documents'; break;
    }
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(20), border: Border.all(color: iconColor.withOpacity(0.2))),
      child: Row(children: [
        Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: iconColor.withOpacity(0.15), borderRadius: BorderRadius.circular(12)), child: Icon(iconData, color: iconColor, size: 22)),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: iconColor)), const SizedBox(height: 2), Text(subtitle, style: GoogleFonts.inter(fontSize: 12, color: iconColor.withOpacity(0.8)))])),
      ]),
    );
  }
}

class _QuickStatCard extends StatelessWidget {
  final String title; final String value; final IconData icon; final Color color;
  const _QuickStatCard({required this.title, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: _P.line), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 3))]),
      child: Row(children: [
        Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: color, size: 18)),
        const SizedBox(width: 12),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(value, style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w900, color: _P.ink, letterSpacing: -0.5)), Text(title, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: _P.inkSoft))]),
      ]),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon; final String label; final Color color; final VoidCallback onTap; final String? badge;
  const _MenuItem({required this.icon, required this.label, required this.onTap, this.color = _P.ink, this.badge});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(color: Colors.white, borderRadius: BorderRadius.circular(16), child: InkWell(
        onTap: onTap, borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: _P.line)),
          child: Row(children: [
            Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: color, size: 20)),
            const SizedBox(width: 14),
            Expanded(child: Text(label, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: color))),
            if (badge != null) Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), margin: const EdgeInsets.only(right: 8), decoration: BoxDecoration(color: _P.amber.withOpacity(0.15), borderRadius: BorderRadius.circular(8)), child: Text(badge!, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: _P.amber))),
            Icon(Icons.chevron_right, color: _P.inkSoft, size: 20),
          ]),
        ),
      )),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ÉCRANS D'ÉTAT
// ═══════════════════════════════════════════════════════════════════════════
class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();
  @override
  Widget build(BuildContext context) {
    return Scaffold(backgroundColor: _P.bg, body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(width: 80, height: 80, decoration: BoxDecoration(gradient: const LinearGradient(colors: [_P.rose, _P.roseLight]), borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: _P.rose.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10))]), child: const Icon(Icons.favorite_rounded, color: Colors.white, size: 36)),
      const SizedBox(height: 24),
      Text('Chargement de votre espace...', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: _P.inkSoft)),
      const SizedBox(height: 20),
      const SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 2.5, color: _P.rose)),
    ])));
  }
}

class _ErrorScreen extends StatelessWidget {
  final Object error; final VoidCallback onRetry;
  const _ErrorScreen({required this.error, required this.onRetry});
  @override
  Widget build(BuildContext context) {
    return Scaffold(backgroundColor: _P.bg, body: Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: _P.red.withOpacity(0.1), shape: BoxShape.circle), child: const Icon(Icons.error_outline, size: 56, color: _P.red)),
      const SizedBox(height: 24),
      Text('Une erreur est survenue', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: _P.ink)),
      const SizedBox(height: 8),
      Text(error.toString(), textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 13, color: _P.inkSoft), maxLines: 3, overflow: TextOverflow.ellipsis),
      const SizedBox(height: 28),
      ElevatedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text('Réessayer'), style: ElevatedButton.styleFrom(backgroundColor: _P.rose, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)))),
    ]))));
  }
}

class _NoUserScreen extends StatelessWidget {
  const _NoUserScreen();
  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    return Scaffold(backgroundColor: _P.bg, body: Stack(children: [
      Positioned(top: topPad + 8, left: 8, child: IconButton(icon: const Icon(Icons.close, color: _P.ink), onPressed: () => context.go('/thix-weeding'))),
      Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(width: 90, height: 90, decoration: BoxDecoration(gradient: const LinearGradient(colors: [_P.rose, _P.roseLight]), borderRadius: BorderRadius.circular(28), boxShadow: [BoxShadow(color: _P.rose.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10))]), child: const Icon(Icons.storefront_rounded, color: Colors.white, size: 44)),
        const SizedBox(height: 28),
        Text('Espace Prestataire', style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w900, color: _P.ink, letterSpacing: -0.5)),
        const SizedBox(height: 8),
        Text('Connectez-vous pour accéder à votre espace professionnel', textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 14, color: _P.inkSoft)),
        const SizedBox(height: 32),
        SizedBox(width: double.infinity, height: 56, child: ElevatedButton(onPressed: () => context.push('/thix-weeding/provider/auth'), style: ElevatedButton.styleFrom(backgroundColor: _P.rose, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 0), child: Text('Se connecter', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800)))),
        const SizedBox(height: 12),
        TextButton(onPressed: () => context.push('/thix-weeding/provider/register'), child: Text('Créer un compte prestataire', style: GoogleFonts.inter(color: _P.rose, fontWeight: FontWeight.w700))),
      ]))),
    ]));
  }
}

class _NoProviderScreen extends StatelessWidget {
  const _NoProviderScreen();
  @override
  Widget build(BuildContext context) {
    return Scaffold(backgroundColor: _P.bg, body: Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: _P.rose.withOpacity(0.1), shape: BoxShape.circle), child: const Icon(Icons.person_add_outlined, size: 64, color: _P.rose)),
      const SizedBox(height: 24),
      Text('Devenez prestataire', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w900, color: _P.ink, letterSpacing: -0.3)),
      const SizedBox(height: 8),
      Text('Vous n\'avez pas encore créé votre profil prestataire.\nInscrivez-vous pour accéder à votre dashboard.', textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 14, color: _P.inkSoft, height: 1.4)),
      const SizedBox(height: 32),
      SizedBox(width: double.infinity, height: 56, child: ElevatedButton.icon(onPressed: () => context.push('/thix-weeding/provider/register'), icon: const Icon(Icons.add_business), label: const Text('Créer mon compte'), style: ElevatedButton.styleFrom(backgroundColor: _P.rose, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))))),
      const SizedBox(height: 12),
      TextButton(onPressed: () async { await Supabase.instance.client.auth.signOut(); if (context.mounted) context.go('/thix-weeding'); }, child: Text('Se déconnecter', style: GoogleFonts.inter(color: _P.inkSoft, fontWeight: FontWeight.w600))),
    ]))));
  }
}
