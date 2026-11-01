// lib/presentation/thix_weeding/pages/provider_portal/provider_portal_shell.dart
// ============================================================================
// THIX WEDDING PROVIDER PORTAL SHELL (PRODUCTION ENTERPRISE)
// ✅ Navigation par onglets (Dashboard, Galerie, Réservations, Tâches, Profil)
// ✅ Design glassmorphism blanc/rose
// ✅ Bottom navigation bar premium
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/provider_models.dart';
import '../../providers/provider_providers.dart';

// ═══════════════════════════════════════════════════════════════════════════
// PALETTE GLASSMORPHISM
// ═══════════════════════════════════════════════════════════════════════════
class _P {
  static const Color bg = Color(0xFFFAFAFA);
  static const Color surface = Colors.white;
  static const Color rose = Color(0xFFFF4D6D);
  static const Color roseLight = Color(0xFFFF85A1);
  static const Color ink = Color(0xFF1A1A2E);
  static const Color inkSoft = Color(0xFF6B7280);
  static const Color line = Color(0xFFE5E7EB);
}

// ═══════════════════════════════════════════════════════════════════════════
// SHELL PRINCIPAL
// ═══════════════════════════════════════════════════════════════════════════
class ProviderPortalShell extends ConsumerStatefulWidget {
  const ProviderPortalShell({super.key});

  @override
  ConsumerState<ProviderPortalShell> createState() => _ProviderPortalShellState();
}

class _ProviderPortalShellState extends ConsumerState<ProviderPortalShell> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    
    if (user == null) {
      return const _NoUserScreen();
    }

    final providerAsync = ref.watch(currentProviderProvider(user.id));

    return providerAsync.when(
      data: (provider) {
        if (provider == null) {
          return const _NoProviderScreen();
        }

        return Scaffold(
          backgroundColor: _P.bg,
          body: IndexedStack(
            index: _currentIndex,
            children: [
              _DashboardTab(provider: provider),
              _GalleryTab(provider: provider),
              _ReservationsTab(provider: provider),
              _TasksTab(provider: provider),
              _ProfileTab(provider: provider),
            ],
          ),
          bottomNavigationBar: _BottomNavBar(
            currentIndex: _currentIndex,
            onTap: (index) => setState(() => _currentIndex = index),
          ),
        );
      },
      loading: () => const Scaffold(
        backgroundColor: _P.bg,
        body: Center(
          child: CircularProgressIndicator(color: _P.rose),
        ),
      ),
      error: (error, stack) => Scaffold(
        backgroundColor: _P.bg,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: _P.rose),
              const SizedBox(height: 16),
              Text(
                'Erreur de chargement',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: _P.ink,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                error.toString(),
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: _P.inkSoft,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => ref.invalidate(currentProviderProvider(user.id)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _P.rose,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Réessayer'),
              ),
            ],
          ),
        ),
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

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(
                icon: Icons.dashboard_outlined,
                activeIcon: Icons.dashboard,
                label: 'Dashboard',
                isActive: currentIndex == 0,
                onTap: () => onTap(0),
              ),
              _NavItem(
                icon: Icons.photo_library_outlined,
                activeIcon: Icons.photo_library,
                label: 'Galerie',
                isActive: currentIndex == 1,
                onTap: () => onTap(1),
              ),
              _NavItem(
                icon: Icons.event_outlined,
                activeIcon: Icons.event,
                label: 'Réservations',
                isActive: currentIndex == 2,
                onTap: () => onTap(2),
              ),
              _NavItem(
                icon: Icons.task_outlined,
                activeIcon: Icons.task,
                label: 'Tâches',
                isActive: currentIndex == 3,
                onTap: () => onTap(3),
              ),
              _NavItem(
                icon: Icons.person_outline,
                activeIcon: Icons.person,
                label: 'Profil',
                isActive: currentIndex == 4,
                onTap: () => onTap(4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 64,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isActive ? activeIcon : icon,
              size: 24,
              color: isActive ? _P.rose : _P.inkSoft,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                color: isActive ? _P.rose : _P.inkSoft,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// TABS (Stubs — à implémenter dans les fichiers suivants)
// ═══════════════════════════════════════════════════════════════════════════

class _DashboardTab extends StatelessWidget {
  final ThixProviderModel provider;
  const _DashboardTab({required this.provider});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'Dashboard: ${provider.businessName}',
        style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _GalleryTab extends StatelessWidget {
  final ThixProviderModel provider;
  const _GalleryTab({required this.provider});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'Galerie: ${provider.galleryUrls.length} photos',
        style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _ReservationsTab extends StatelessWidget {
  final ThixProviderModel provider;
  const _ReservationsTab({required this.provider});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'Réservations',
        style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _TasksTab extends StatelessWidget {
  final ThixProviderModel provider;
  const _TasksTab({required this.provider});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'Tâches',
        style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _ProfileTab extends StatelessWidget {
  final ThixProviderModel provider;
  const _ProfileTab({required this.provider});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'Profil: ${provider.uniqueCode}',
        style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ÉCRANS D'ERREUR
// ═══════════════════════════════════════════════════════════════════════════

class _NoUserScreen extends StatelessWidget {
  const _NoUserScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _P.bg,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_off, size: 64, color: _P.rose),
            const SizedBox(height: 16),
            Text(
              'Connexion requise',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: _P.ink,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.push('/thix-weeding/provider/auth'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _P.rose,
                foregroundColor: Colors.white,
              ),
              child: const Text('Se connecter'),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoProviderScreen extends StatelessWidget {
  const _NoProviderScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _P.bg,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.store, size: 64, color: _P.rose),
            const SizedBox(height: 16),
            Text(
              'Devenez prestataire',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: _P.ink,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Créez votre compte pour accéder à l\'espace',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: _P.inkSoft,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.push('/thix-weeding/provider/register'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _P.rose,
                foregroundColor: Colors.white,
              ),
              child: const Text('Créer mon compte'),
            ),
          ],
        ),
      ),
    );
  }
}
