// lib/presentation/thix_weeding/pages/provider_portal/provider_portal_shell.dart
// ============================================================================
// THIX WEDDING PROVIDER PORTAL SHELL (PRODUCTION v4 — MULTI-ACTIVITÉS)
// ✅ LOGIQUE IDENTIQUE À my_weddings_page.dart (1 session = Supabase.currentUser)
// ✅ 1 compte (owner_id) = PLUSIEURS activités/métiers (traiteur, salle, DJ…)
//    → barre de sélection d'activité affichée UNIQUEMENT si >= 2 activités
//    → mono-activité = comportement v3 strictement inchangé (zéro casse)
// ✅ L'activité courante est dérivée de myActivitiesProvider + selectedActivityIdProvider
//    (même source que myProviderProvider) -> les pages reçoivent le bon provider
// ✅ ZÉRO SharedPreferences — fini les sessions parallèles
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
import 'provider_offers_page.dart';

class _P {
  static const Color bg = Color(0xFFFAFAFA);
  static const Color surface = Colors.white;
  static const Color rose = Color(0xFFFF4D6D);
  static const Color roseLight = Color(0xFFFF85A1);
  static const Color ink = Color(0xFF1A1A2E);
  static const Color inkSoft = Color(0xFF6B7280);
  static const Color line = Color(0xFFE5E7EB);
  static const Color green = Color(0xFF10B981);
  static const Color amber = Color(0xFFF59E0B);
  static const Color red = Color(0xFFEF4444);
  static const Color blue = Color(0xFF0B3B8F);
}

// ═══════════════════════════════════════════════════════════════════════════
// SHELL — ConsumerStatefulWidget (comme MyWeddingsPage)
// ═══════════════════════════════════════════════════════════════════════════
class ProviderPortalShell extends ConsumerStatefulWidget {
  final int initialTab;
  const ProviderPortalShell({super.key, this.initialTab = 0});

  @override
  ConsumerState<ProviderPortalShell> createState() => _ProviderPortalShellState();
}

class _ProviderPortalShellState extends ConsumerState<ProviderPortalShell> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialTab.clamp(0, 5);
  }

  @override
  Widget build(BuildContext context) {
    // ═══════════════════════════════════════════════════════════════════
    // GARDE : pas de session → login GÉNÉRAL (comme my_weddings_page)
    // ═══════════════════════════════════════════════════════════════════
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      return const _AuthRequiredView();
    }

    // ═══════════════════════════════════════════════════════════════════
    // ✅ MULTI-ACTIVITÉS : on watch la LISTE des activités du compte
    //    (1 owner_id = N métiers). C'est LA source de vérité du shell.
    // ═══════════════════════════════════════════════════════════════════
    final activitiesAsync = ref.watch(myActivitiesProvider(user.id));

    return activitiesAsync.when(
      loading: () => const _LoadingScreen(),
      error: (e, _) => _ErrorView(
        message: e.toString(),
        onRetry: () {
          ref.invalidate(myActivitiesProvider(user.id));
          ref.invalidate(myProviderProvider(user.id));
        },
      ),
      data: (activities) {
        if (activities.isEmpty) {
          // Connecté mais aucune activité → "Devenez prestataire"
          return const _NoProviderScreen();
        }

        // Activité courante = sélectionnée (sinon 1ère / principale)
        final selectedId = ref.watch(selectedActivityIdProvider);
        final active = activities.firstWhere(
          (a) => a.id == selectedId,
          orElse: () => activities.first,
        );

        return _buildDashboard(
          userId: user.id,
          provider: active,
          activities: activities,
        );
      },
    );
  }

  Widget _buildDashboard({
    required String userId,
    required ThixProviderModel provider,
    required List<ThixProviderModel> activities,
  }) {
    final showPicker = activities.length >= 2; // mono-activité => aucune barre (v3)

    return Scaffold(
      backgroundColor: _P.bg,
      body: Column(
        children: [
          if (showPicker)
            _ActivityPickerBar(
              activities: activities,
              currentId: provider.id,
              onTap: () => _openActivityPicker(userId, activities, provider.id),
            ),
          Expanded(
            child: IndexedStack(
              index: _currentIndex,
              children: [
                ProviderDashboardPage(provider: provider),
                ProviderOfferFormPage(provider: provider),
                ProviderGalleryPage(provider: provider),
                ProviderReservationsPage(provider: provider),
                ProviderTasksPage(provider: provider),
                _ProfileTab(provider: provider, activitiesCount: activities.length),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _BottomNavBar(
        currentIndex: _currentIndex,
        onTap: (i) {
          HapticFeedback.selectionClick();
          setState(() => _currentIndex = i);
        },
      ),
    );
  }

  // ── Feuille de sélection d'activité (bottom sheet) ──
  void _openActivityPicker(
    String userId,
    List<ThixProviderModel> activities,
    String currentId,
  ) {
    HapticFeedback.selectionClick();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _ActivityPickerSheet(
        activities: activities,
        currentId: currentId,
        onPick: (id) {
          Navigator.pop(ctx);
          ref.read(selectedActivityIdProvider.notifier).state = id;
          setState(() => _currentIndex = 0); // revient au dashboard, activité changée
        },
        onManage: () {
          Navigator.pop(ctx);
          context.push('/thix-weeding/provider/activities');
        },
        onAdd: () {
          Navigator.pop(ctx);
          context.push('/thix-weeding/provider/activities/new');
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ✅ BARRE DE SÉLECTION D'ACTIVITÉ (visible seulement si >= 2 activités)
// ═══════════════════════════════════════════════════════════════════════════
class _ActivityPickerBar extends StatelessWidget {
  final List<ThixProviderModel> activities;
  final String currentId;
  final VoidCallback onTap;
  const _ActivityPickerBar({
    required this.activities,
    required this.currentId,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final current = activities.firstWhere(
      (a) => a.id == currentId,
      orElse: () => activities.first,
    );
    return SafeArea(
      top: true,
      bottom: false,
      child: Material(
        color: Colors.white,
        child: InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: _P.line)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [_P.rose, _P.roseLight]),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.workspaces_rounded, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      current.businessName.isEmpty ? 'Mon activité' : current.businessName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w800, color: _P.ink),
                    ),
                    const SizedBox(height: 1),
                    Row(children: [
                      Text(
                        current.category.displayName,
                        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: _P.rose),
                      ),
                      const SizedBox(width: 6),
                      Text('· ${activities.length} activités',
                          style: GoogleFonts.inter(fontSize: 10.5, color: _P.inkSoft)),
                    ]),
                  ],
                ),
              ),
              const Icon(Icons.swap_vert_rounded, color: _P.inkSoft, size: 22),
              const SizedBox(width: 4),
              const Icon(Icons.keyboard_arrow_down_rounded, color: _P.rose, size: 22),
            ]),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ✅ FEUILLE DE SÉLECTION (dumb widget — pas de riverpod interne)
// ═══════════════════════════════════════════════════════════════════════════
class _ActivityPickerSheet extends StatelessWidget {
  final List<ThixProviderModel> activities;
  final String currentId;
  final ValueChanged<String> onPick;
  final VoidCallback onManage;
  final VoidCallback onAdd;
  const _ActivityPickerSheet({
    required this.activities,
    required this.currentId,
    required this.onPick,
    required this.onManage,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(color: _P.line, borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
            child: Row(children: [
              const Icon(Icons.workspaces_rounded, color: _P.rose, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text('Choisir une activité',
                    style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w900, color: _P.ink)),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Basculez entre vos métiers (traiteur, salle, DJ…)',
                  style: GoogleFonts.inter(fontSize: 12, color: _P.inkSoft)),
            ),
          ),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              itemCount: activities.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final a = activities[i];
                final sel = a.id == currentId;
                return Material(
                  color: sel ? _P.rose.withOpacity(0.06) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      HapticFeedback.selectionClick();
                      onPick(a.id);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: sel ? _P.rose : _P.line, width: sel ? 2 : 1),
                      ),
                      child: Row(children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            gradient: sel
                                ? const LinearGradient(colors: [_P.rose, _P.roseLight])
                                : LinearGradient(colors: [_P.inkSoft.withOpacity(0.12), _P.inkSoft.withOpacity(0.06)]),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.storefront_outlined,
                            color: sel ? Colors.white : _P.inkSoft,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                a.businessName.isEmpty ? 'Activité' : a.businessName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: _P.ink),
                              ),
                              const SizedBox(height: 2),
                              Text(a.category.displayName,
                                  style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w700, color: _P.rose)),
                            ],
                          ),
                        ),
                        if (sel)
                          const Icon(Icons.check_circle_rounded, color: _P.rose, size: 24)
                        else
                          const Icon(Icons.radio_button_unchecked_rounded, color: _P.line, size: 24),
                      ]),
                    ),
                  ),
                );
              },
            ),
          ),
          const Divider(height: 1, color: _P.line),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            child: Row(children: [
              Expanded(
                child: _SheetBtn(
                  icon: Icons.settings_outlined,
                  label: 'Gérer',
                  color: _P.blue,
                  onTap: onManage,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _SheetBtn(
                  icon: Icons.add_rounded,
                  label: 'Ajouter une activité',
                  color: _P.rose,
                  filled: true,
                  onTap: onAdd,
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}

class _SheetBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool filled;
  final VoidCallback onTap;
  const _SheetBtn({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: filled ? color : Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: filled ? Colors.transparent : color.withOpacity(0.4), width: 1.5),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: filled ? Colors.white : color),
              const SizedBox(width: 8),
              Flexible(
                child: Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800, color: filled ? Colors.white : color)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// _AuthRequiredView — IDENTIQUE à my_weddings_page
// ═══════════════════════════════════════════════════════════════════════════
class _AuthRequiredView extends StatelessWidget {
  const _AuthRequiredView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _P.bg,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [_P.rose.withOpacity(0.15), _P.blue.withOpacity(0.1)]),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.lock_outline, size: 48, color: _P.rose),
              ),
              const SizedBox(height: 16),
              Text('Connexion requise', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: _P.ink)),
              const SizedBox(height: 8),
              Text(
                'Connectez-vous à votre compte THIX pour accéder à l\'espace prestataire',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 13, color: _P.inkSoft, height: 1.4),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: () => context.push('/thix-weeding/auth/login'),
                  icon: const Icon(Icons.login, size: 18),
                  label: Text('Se connecter', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _P.rose,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () => context.push('/thix-weeding/auth/register'),
                child: Text('Créer un compte THIX', style: GoogleFonts.inter(color: _P.rose, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// _NoProviderScreen — connecté mais pas encore d'activité
// ═══════════════════════════════════════════════════════════════════════════
class _NoProviderScreen extends StatelessWidget {
  const _NoProviderScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _P.bg,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [_P.rose.withOpacity(0.15), _P.blue.withOpacity(0.1)]),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.storefront_rounded, size: 56, color: _P.rose),
              ),
              const SizedBox(height: 20),
              Text('Devenez prestataire', style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w900, color: _P.ink, letterSpacing: -0.5)),
              const SizedBox(height: 8),
              Text(
                'Créez votre 1ère activité (traiteur, salle, DJ, photographe…). Vous pourrez ensuite ajouter plusieurs métiers sur le même compte.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 13, color: _P.inkSoft, height: 1.5),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: () => context.push('/thix-weeding/provider/register'),
                  icon: const Icon(Icons.add_business, size: 18),
                  label: Text('Créer mon profil prestataire', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _P.rose,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () => context.push('/thix-weeding/provider/activities/new'),
                child: Text('Ou ajouter directement une activité', style: GoogleFonts.inter(color: _P.inkSoft, fontWeight: FontWeight.w600)),
              ),
              TextButton(
                onPressed: () => context.go('/thix-weeding'),
                child: Text('Retour à l\'accueil', style: GoogleFonts.inter(color: _P.inkSoft, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// BOTTOM NAVIGATION (inchangé)
// ═══════════════════════════════════════════════════════════════════════════
class _BottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  const _BottomNavBar({required this.currentIndex, required this.onTap});

  static const _items = <_NavItemConfig>[
    _NavItemConfig(icon: Icons.dashboard_outlined, activeIcon: Icons.dashboard, label: 'Dashboard'),
    _NavItemConfig(icon: Icons.local_offer_outlined, activeIcon: Icons.local_offer, label: 'Offres'),
    _NavItemConfig(icon: Icons.photo_library_outlined, activeIcon: Icons.photo_library, label: 'Galerie'),
    _NavItemConfig(icon: Icons.event_outlined, activeIcon: Icons.event, label: 'Résa.'),
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
                  color: isActive ? _P.rose.withOpacity(0.1) : Colors.transparent,
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
// PROFILE TAB (avec déconnexion = Supabase.signOut global)
// ✅ + entrée "Mes activités (N)" pour gérer le multi-métiers
// ═══════════════════════════════════════════════════════════════════════════
class _ProfileTab extends ConsumerWidget {
  final ThixProviderModel provider;
  final int activitiesCount;
  const _ProfileTab({required this.provider, required this.activitiesCount});

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Déconnexion', style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: _P.ink)),
        content: Text('Vous serez déconnecté de votre compte THIX.', style: GoogleFonts.inter(color: _P.inkSoft)),
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
    if (confirmed != true) return;

    await Supabase.instance.client.auth.signOut();
    ref.invalidate(myProviderProvider(provider.ownerId ?? ''));
    ref.invalidate(myActivitiesProvider(provider.ownerId ?? ''));
    ref.read(selectedActivityIdProvider.notifier).state = null;
    if (context.mounted) context.go('/thix-weeding');
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
                gradient: const LinearGradient(colors: [_P.rose, Color(0xFFFF85A1)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(32), bottomRight: Radius.circular(32)),
              ),
              child: Column(children: [
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
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: provider.uniqueCode));
                    HapticFeedback.mediumImpact();
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Code copié', style: GoogleFonts.inter(color: Colors.white)), backgroundColor: _P.green, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 12, offset: const Offset(0, 4))]),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.qr_code_2, color: _P.rose, size: 22),
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
              ]),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // ✅ NOUVEAU : gestion multi-activités
                _MenuItem(
                  icon: Icons.workspaces_rounded,
                  label: 'Mes activités',
                  badge: '$activitiesCount',
                  onTap: () => context.push('/thix-weeding/provider/activities'),
                ),
                _MenuItem(icon: Icons.edit_outlined, label: 'Modifier mes informations', onTap: () {}),
                _MenuItem(icon: Icons.document_scanner_outlined, label: 'Mes documents de validation', badge: provider.verificationStatus == ProviderVerificationStatus.pending ? 'En attente' : null, onTap: () {}),
                _MenuItem(icon: Icons.payments_outlined, label: 'Mes revenus', onTap: () {}),
                _MenuItem(icon: Icons.notifications_outlined, label: 'Préférences de notifications', onTap: () {}),
                _MenuItem(icon: Icons.help_outline, label: 'Aide & Support', onTap: () {}),
                const SizedBox(height: 8),
                _MenuItem(icon: Icons.logout, label: 'Se déconnecter', color: _P.red, onTap: () => _logout(context, ref)),
                const SizedBox(height: 24),
                Center(child: Text('Thix Wedding v5.1', style: GoogleFonts.inter(fontSize: 11, color: _P.inkSoft, fontWeight: FontWeight.w500))),
                const SizedBox(height: 40),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final String? badge;
  const _MenuItem({required this.icon, required this.label, required this.onTap, this.color = _P.ink, this.badge});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: _P.line)),
            child: Row(children: [
              Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: color, size: 20)),
              const SizedBox(width: 14),
              Expanded(child: Text(label, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: color))),
              if (badge != null) Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), margin: const EdgeInsets.only(right: 8), decoration: BoxDecoration(color: _P.rose.withOpacity(0.12), borderRadius: BorderRadius.circular(8)), child: Text(badge!, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: _P.rose))),
              const Icon(Icons.chevron_right, color: _P.inkSoft, size: 20),
            ]),
          ),
        ),
      ),
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
    return Scaffold(
      backgroundColor: _P.bg,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(width: 80, height: 80, decoration: BoxDecoration(gradient: const LinearGradient(colors: [_P.rose, Color(0xFFFF85A1)]), borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: _P.rose.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10))]), child: const Icon(Icons.favorite_rounded, color: Colors.white, size: 36)),
            const SizedBox(height: 24),
            Text('Chargement de votre espace...', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: _P.inkSoft)),
            const SizedBox(height: 20),
            const SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 2.5, color: _P.rose)),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _P.bg,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: _P.red.withOpacity(0.1), shape: BoxShape.circle), child: const Icon(Icons.error_outline, size: 56, color: _P.red)),
              const SizedBox(height: 24),
              Text('Une erreur est survenue', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: _P.ink)),
              const SizedBox(height: 8),
              Text(message, textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 13, color: _P.inkSoft), maxLines: 3, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 28),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Réessayer'),
                style: ElevatedButton.styleFrom(backgroundColor: _P.rose, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
