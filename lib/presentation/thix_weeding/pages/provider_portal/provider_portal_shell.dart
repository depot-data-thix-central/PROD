// lib/presentation/thix_weeding/pages/provider_portal/provider_portal_shell.dart
// ============================================================================
// THIX WEDDING PROVIDER PORTAL SHELL (PRODUCTION ENTERPRISE)
// ✅ Gestion intelligente des sessions (Auth Supabase OU Inscription Libre Locale)
// ✅ Navigation par onglets complète (Dashboard, Galerie, Réservations, Tâches, Profil)
// ============================================================================
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart'; // ⬅️ IMPORT CLÉ

import '../../models/provider_models.dart';
import '../../providers/provider_providers.dart';
import 'provider_dashboard_page.dart';
import 'provider_media_pages.dart';
import 'provider_business_pages.dart';

class _P {
  static const Color bg = Color(0xFFFAFAFA);
  static const Color surface = Colors.white;
  static const Color rose = Color(0xFFFF4D6D);
  static const Color ink = Color(0xFF1A1A2E);
  static const Color inkSoft = Color(0xFF6B7280);
  static const Color line = Color(0xFFE5E7EB);
  static const Color green = Color(0xFF10B981);
  static const Color amber = Color(0xFFF59E0B);
  static const Color red = Color(0xFFEF4444);
}

class ProviderPortalShell extends ConsumerStatefulWidget {
  final int initialTab;
  const ProviderPortalShell({super.key, this.initialTab = 0});

  @override
  ConsumerState<ProviderPortalShell> createState() => _ProviderPortalShellState();
}

class _ProviderPortalShellState extends ConsumerState<ProviderPortalShell> {
  late int _currentIndex;
  String? _localProviderId;
  
  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialTab.clamp(0, 4);
    _loadLocalProviderId();
  }

  Future<void> _loadLocalProviderId() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString('thix_current_provider_id');
    if (mounted) setState(() => _localProviderId = id);
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;

    // ═══════════════════════════════════════════════════════════════════════
    // CAS 1 : L'utilisateur est connecté via Supabase Auth
    // ═══════════════════════════════════════════════════════════════════════
    if (user != null) {
      final providerAsync = ref.watch(currentProviderProvider(user.id));
      return providerAsync.when(
        data: (provider) => provider != null ? _buildDashboard(provider) : const _NoProviderScreen(),
        loading: () => const _LoadingScreen(),
        error: (error, stack) => _ErrorScreen(error: error, onRetry: () => ref.invalidate(currentProviderProvider(user.id))),
      );
    }

    // ═══════════════════════════════════════════════════════════════════════
    // CAS 2 : PAS DE CONNEXION AUTH MAIS ON A UN ID LOCAL (INSCRIPTION LIBRE)
    // C'est ICI qu'on résout ton problème !
    // ═══════════════════════════════════════════════════════════════════════
    if (_localProviderId != null && _localProviderId!.isNotEmpty) {
      final providerAsync = ref.watch(providerByIdProvider(_localProviderId!));
      return providerAsync.when(
        data: (provider) {
          if (provider != null) return _buildDashboard(provider);
          _clearLocalProviderId(); 
          return const _NoUserScreen();
        },
        loading: () => const _LoadingScreen(),
        error: (error, stack) => _ErrorScreen(error: error, onRetry: () => ref.invalidate(providerByIdProvider(_localProviderId!))),
      );
    }

    // ═══════════════════════════════════════════════════════════════════════
    // CAS 3 : Ni Auth, ni ID Local → Proposer la connexion ou l'inscription
    // ═══════════════════════════════════════════════════════════════════════
    return const _NoUserScreen();
  }

  Widget _buildDashboard(ThixProviderModel provider) {
    return Scaffold(
      backgroundColor: _P.bg,
      body: IndexedStack(index: _currentIndex, children: [
        ProviderDashboardPage(provider: provider),
        ProviderGalleryPage(provider: provider),
        ProviderReservationsPage(provider: provider),
        ProviderTasksPage(provider: provider),
        _ProfileTab(provider: provider),
      ]),
      bottomNavigationBar: _BottomNavBar(currentIndex: _currentIndex, onTap: (index) { HapticFeedback.selectionClick(); setState(() => _currentIndex = index); }),
    );
  }

  Future<void> _clearLocalProviderId() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('thix_current_provider_id');
    if (mounted) setState(() => _localProviderId = null);
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// BOTTOM NAVIGATION BAR
// ═══════════════════════════════════════════════════════════════════════════
class _BottomNavBar extends StatelessWidget {
  final int currentIndex; final ValueChanged<int> onTap;
  const _BottomNavBar({required this.currentIndex, required this.onTap});

  static const _items = <_NavItemConfig>[
    _NavItemConfig(icon: Icons.dashboard_outlined, activeIcon: Icons.dashboard, label: 'Dashboard'),
    _NavItemConfig(icon: Icons.photo_library_outlined, activeIcon: Icons.photo_library, label: 'Galerie'),
    _NavItemConfig(icon: Icons.event_outlined, activeIcon: Icons.event, label: 'Résa.'),
    _NavItemConfig(icon: Icons.task_outlined, activeIcon: Icons.task, label: 'Tâches'),
    _NavItemConfig(icon: Icons.person_outline, activeIcon: Icons.person, label: 'Profil'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, -4))]),
      child: SafeArea(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8), child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [for (int i = 0; i < _items.length; i++) _NavItem(config: _items[i], isActive: currentIndex == i, onTap: () => onTap(i))]))),
    );
  }
}

class _NavItemConfig { final IconData icon; final IconData activeIcon; final String label; const _NavItemConfig({required this.icon, required this.activeIcon, required this.label}); }
class _NavItem extends StatelessWidget {
  final _NavItemConfig config; final bool isActive; final VoidCallback onTap;
  const _NavItem({required this.config, required this.isActive, required this.onTap});
  @override
  Widget build(BuildContext context) => Expanded(child: GestureDetector(onTap: onTap, behavior: HitTestBehavior.opaque, child: AnimatedContainer(duration: const Duration(milliseconds: 220), curve: Curves.easeOut, padding: const EdgeInsets.symmetric(vertical: 8), child: Column(mainAxisSize: MainAxisSize.min, children: [AnimatedContainer(duration: const Duration(milliseconds: 220), padding: EdgeInsets.all(isActive ? 8 : 6), decoration: BoxDecoration(color: isActive ? _P.rose.withOpacity(0.1) : Colors.transparent, borderRadius: BorderRadius.circular(12)), child: Icon(isActive ? config.activeIcon : config.icon, size: isActive ? 22 : 20, color: isActive ? _P.rose : _P.inkSoft)), const SizedBox(height: 4), Text(config.label, style: GoogleFonts.inter(fontSize: 10, fontWeight: isActive ? FontWeight.w800 : FontWeight.w500, color: isActive ? _P.rose : _P.inkSoft))]))));
}

// ═══════════════════════════════════════════════════════════════════════════
// PROFIL TAB (AVEC DÉCONNEXION NETTOYANT LE CACHE LOCAL)
// ═══════════════════════════════════════════════════════════════════════════
class _ProfileTab extends ConsumerWidget {
  final ThixProviderModel provider;
  const _ProfileTab({required this.provider});

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), title: Text('Déconnexion', style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: _P.ink)), content: Text('Voulez-vous vraiment vous déconnecter ?', style: GoogleFonts.inter(color: _P.inkSoft)), actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Annuler', style: GoogleFonts.inter(color: _P.inkSoft))), ElevatedButton(onPressed: () => Navigator.pop(ctx, true), style: ElevatedButton.styleFrom(backgroundColor: _P.red, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))), child: Text('Déconnexion', style: GoogleFonts.inter(fontWeight: FontWeight.w700)))]));
    
    if (confirmed == true) {
      await Supabase.instance.client.auth.signOut();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('thix_current_provider_id');
      ref.invalidate(providerByIdProvider(provider.id));
      ref.invalidate(providersListProvider);
      if (context.mounted) context.go('/thix-weeding');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topPad = MediaQuery.of(context).padding.top;
    return Scaffold(backgroundColor: _P.bg, body: CustomScrollView(physics: const BouncingScrollPhysics(), slivers: [
      SliverToBoxAdapter(child: Container(padding: EdgeInsets.fromLTRB(20, topPad + 30, 20, 30), decoration: BoxDecoration(gradient: const LinearGradient(colors: [_P.rose, Color(0xFFFF85A1)], begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(32), bottomRight: Radius.circular(32))), child: Column(children: [
        Container(width: 90, height: 90, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 4), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 12, offset: const Offset(0, 4))]), child: CircleAvatar(radius: 41, backgroundColor: Colors.white, child: Text(provider.businessName.isNotEmpty ? provider.businessName[0].toUpperCase() : 'P', style: GoogleFonts.inter(fontSize: 36, fontWeight: FontWeight.w900, color: _P.rose)))),
        const SizedBox(height: 16),
        Text(provider.businessName, style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.5)),
        const SizedBox(height: 6),
        Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(12)), child: Text(provider.category.displayName, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white))),
        const SizedBox(height: 20),
        GestureDetector(onTap: () { Clipboard.setData(ClipboardData(text: provider.uniqueCode)); HapticFeedback.mediumImpact(); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Code copié', style: GoogleFonts.inter(color: Colors.white)), backgroundColor: _P.green, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)))); }, child: Container(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 12, offset: const Offset(0, 4))]), child: Row(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.qr_code_2, color: _P.rose, size: 22), const SizedBox(width: 10), Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [Text('Votre code Thix', style: GoogleFonts.inter(fontSize: 10, color: _P.inkSoft, fontWeight: FontWeight.w600)), Text(provider.uniqueCode, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w900, color: _P.ink, letterSpacing: 1))]), const SizedBox(width: 10), const Icon(Icons.copy_rounded, color: _P.inkSoft, size: 18)]))),
      ]))),
      SliverPadding(padding: const EdgeInsets.all(16), sliver: SliverList(delegate: SliverChildListDelegate([
        _MenuItem(icon: Icons.edit_outlined, label: 'Modifier mes informations', onTap: () {}),
        _MenuItem(icon: Icons.document_scanner_outlined, label: 'Mes documents de validation', badge: provider.verificationStatus == ProviderVerificationStatus.pending ? 'En attente' : null, onTap: () {}),
        _MenuItem(icon: Icons.payments_outlined, label: 'Mes revenus', onTap: () {}),
        _MenuItem(icon: Icons.notifications_outlined, label: 'Préférences de notifications', onTap: () {}),
        _MenuItem(icon: Icons.help_outline, label: 'Aide & Support', onTap: () {}),
        const SizedBox(height: 8),
        _MenuItem(icon: Icons.logout, label: 'Se déconnecter', color: _P.red, onTap: () => _logout(context, ref)),
        const SizedBox(height: 24),
        Center(child: Text('Thix Wedding v5.0', style: GoogleFonts.inter(fontSize: 11, color: _P.inkSoft, fontWeight: FontWeight.w500))),
        const SizedBox(height: 40),
      ]))),
    ]));
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon; final String label; final Color color; final VoidCallback onTap; final String? badge;
  const _MenuItem({required this.icon, required this.label, required this.onTap, this.color = _P.ink, this.badge});
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Material(color: Colors.white, borderRadius: BorderRadius.circular(16), child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(16), child: Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14), decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: _P.line)), child: Row(children: [Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: color, size: 20)), const SizedBox(width: 14), Expanded(child: Text(label, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: color))), if (badge != null) Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), margin: const EdgeInsets.only(right: 8), decoration: BoxDecoration(color: _P.amber.withOpacity(0.15), borderRadius: BorderRadius.circular(8)), child: Text(badge!, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: _P.amber))), const Icon(Icons.chevron_right, color: _P.inkSoft, size: 20)]))));
}

// ═══════════════════════════════════════════════════════════════════════════
// ÉCRANS D'ÉTAT
// ═══════════════════════════════════════════════════════════════════════════
class _LoadingScreen extends StatelessWidget { const _LoadingScreen(); @override Widget build(BuildContext context) => Scaffold(backgroundColor: _P.bg, body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Container(width: 80, height: 80, decoration: BoxDecoration(gradient: const LinearGradient(colors: [_P.rose, Color(0xFFFF85A1)]), borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: _P.rose.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10))]), child: const Icon(Icons.favorite_rounded, color: Colors.white, size: 36)), const SizedBox(height: 24), Text('Chargement...', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: _P.inkSoft)), const SizedBox(height: 20), const SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 2.5, color: _P.rose))]))); } }
class _ErrorScreen extends StatelessWidget { final Object error; final VoidCallback onRetry; const _ErrorScreen({required this.error, required this.onRetry}); @override Widget build(BuildContext context) => Scaffold(backgroundColor: _P.bg, body: Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: _P.red.withOpacity(0.1), shape: BoxShape.circle), child: const Icon(Icons.error_outline, size: 56, color: _P.red)), const SizedBox(height: 24), Text('Une erreur est survenue', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: _P.ink)), const SizedBox(height: 8), Text(error.toString(), textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 13, color: _P.inkSoft), maxLines: 3, overflow: TextOverflow.ellipsis), const SizedBox(height: 28), ElevatedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text('Réessayer'), style: ElevatedButton.styleFrom(backgroundColor: _P.rose, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))))])))); } }
class _NoUserScreen extends StatelessWidget { const _NoUserScreen(); @override Widget build(BuildContext context) => Scaffold(backgroundColor: _P.bg, body: Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Container(width: 90, height: 90, decoration: BoxDecoration(gradient: const LinearGradient(colors: [_P.rose, Color(0xFFFF85A1)]), borderRadius: BorderRadius.circular(28), boxShadow: [BoxShadow(color: _P.rose.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10))]), child: const Icon(Icons.storefront_rounded, color: Colors.white, size: 44)), const SizedBox(height: 28), Text('Espace Prestataire', style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w900, color: _P.ink, letterSpacing: -0.5)), const SizedBox(height: 8), Text('Connectez-vous ou créez un compte gratuit.', textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 14, color: _P.inkSoft)), const SizedBox(height: 32), SizedBox(width: double.infinity, height: 56, child: ElevatedButton(onPressed: () => context.push('/thix-weeding/provider/register'), style: ElevatedButton.styleFrom(backgroundColor: _P.rose, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 0), child: Text('Créer mon compte', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800)))), const SizedBox(height: 12), TextButton(onPressed: () => context.push('/thix-weeding/provider/auth'), child: Text('J\'ai déjà un compte', style: GoogleFonts.inter(color: _P.rose, fontWeight: FontWeight.w700)))])))); } }
class _NoProviderScreen extends StatelessWidget { const _NoProviderScreen(); @override Widget build(BuildContext context) => Scaffold(backgroundColor: _P.bg, body: Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Container(padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: _P.rose.withOpacity(0.1), shape: BoxShape.circle), child: const Icon(Icons.person_add_outlined, size: 64, color: _P.rose)), const SizedBox(height: 24), Text('Devenez prestataire', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w900, color: _P.ink, letterSpacing: -0.3)), const SizedBox(height: 8), Text('Vous n\'avez pas encore créé votre profil.\nInscrivez-vous pour accéder à votre dashboard.', textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 14, color: _P.inkSoft, height: 1.4)), const SizedBox(height: 32), SizedBox(width: double.infinity, height: 56, child: ElevatedButton.icon(onPressed: () => context.push('/thix-weeding/provider/register'), icon: const Icon(Icons.add_business), label: const Text('Créer mon compte'), style: ElevatedButton.styleFrom(backgroundColor: _P.rose, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))))), const SizedBox(height: 12), TextButton(onPressed: () async { await Supabase.instance.client.auth.signOut(); if (context.mounted) context.go('/thix-weeding'); }, child: Text('Se déconnecter', style: GoogleFonts.inter(color: _P.inkSoft, fontWeight: FontWeight.w600)))])))); } }
