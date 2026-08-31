import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:thix_id/features/auth/presentation/providers/auth_controller.dart';
import 'package:thix_id/nav.dart';
import 'package:thix_id/presentation/admin/admin_page.dart';
import 'package:thix_id/presentation/admin/admin_routes.dart';
import 'package:thix_id/services/admin_rbac_service.dart';
import 'package:thix_id/theme.dart';

class _AdminColors {
  static const Color black = Color(0xFF0A0E1A);
  static const Color background = Color(0xFF0F1420);
  static const Color panel = Color(0xCC1A1F2E);
  static const Color panelHi = Color(0xE6222A3E);
  static const Color stroke = Color(0x33FFFFFF);
  static const Color text = Color(0xFFF0F3FA);
  static const Color textDim = Color(0xFF8E98B0);
  static const Color neonCyan = Color(0xFF00E5FF);
  static const Color electricBlue = Color(0xFF2962FF);
  static const Color neonViolet = Color(0xFFB388FF);
  static const Color neonPink = Color(0xFFFF4081);
  static const Color thixGold = Color(0xFFD4AF37);
  static const Color success = Color(0xFF00E676);
  static const Color warning = Color(0xFFFF9100);
  static const Color error = Color(0xFFFF1744);
  static const Color info = Color(0xFF00B0FF);
  static LinearGradient glowViolet() => const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [neonViolet, electricBlue]);
  static LinearGradient thixGradient() => const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [thixGold, Color(0xFFE8C96C)]);
}

class AdminShell extends ConsumerStatefulWidget {
  final AdminModule module;
  final Widget child;
  final String? role;
  const AdminShell({super.key, required this.module, required this.child, required this.role});
  @override
  ConsumerState<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends ConsumerState<AdminShell> {
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();
  @override
  void dispose() { _searchController.dispose(); _searchFocus.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = width >= 1000;
    final isTablet = width >= 720;
    return Theme(
      data: Theme.of(context).copyWith(scaffoldBackgroundColor: _AdminColors.black),
      child: Scaffold(
        drawer: (!isTablet)? Drawer(child: _AdminDrawer(module: widget.module, role: widget.role)) : null,
        body: Stack(children: [
          const _AdminBackground(),
          SafeArea(child: Row(children: [
            if (isTablet) _AdminSidebarRail(module: widget.module, role: widget.role),
            Expanded(child: Column(children: [
              AdminTopBar(isDesktop: isDesktop, role: widget.role, searchController: _searchController, searchFocus: _searchFocus),
              Expanded(child: Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 16), child: widget.child)),
            ])),
          ])),
        ]),
      ),
    );
  }
}

class _AdminBackground extends StatelessWidget { const _AdminBackground(); @override Widget build(BuildContext context) => const SizedBox(); }
class _GlowBlob extends StatelessWidget { final Color color; final double size; const _GlowBlob({required this.color, required this.size}); @override Widget build(BuildContext context) => Container(width: size, height: size, decoration: BoxDecoration(shape: BoxShape.circle, color: color.withOpacity(0.2))); }

class AdminTopBar extends ConsumerWidget {
  final bool isDesktop;
  final String? role;
  final TextEditingController searchController;
  final FocusNode searchFocus;

  const AdminTopBar({
    super.key,
    required this.isDesktop,
    required this.role,
    required this.searchController,
    required this.searchFocus,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ✅ NOUVELLE API : accès direct à AuthControllerState
    final authState = ref.watch(authControllerProvider);
    final user = authState.currentUser;
    final isSigningOut = authState.isLoading;

    Future<void> handleSignOut() async {
      if (isSigningOut) return;
      HapticFeedback.mediumImpact();
      debugPrint('[AdminTopBar] 👋 Sign out requested');
      try {
        await ref.read(authControllerProvider.notifier).signOut();
        if (!context.mounted) return;
        context.go(AppRoutes.home);
      } catch (e) {
        debugPrint('[AdminTopBar] ❌ Sign out error: $e');
      }
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          if (!isDesktop)
            Builder(
              builder: (context) => _GlassIconButton(
                icon: Icons.menu_rounded,
                tooltip: 'Menu',
                onTap: () => Scaffold.of(context).openDrawer(),
              ),
            ),
          if (!isDesktop) const SizedBox(width: 8),
          Expanded(
            child: _GlassSearchField(
              controller: searchController,
              focusNode: searchFocus,
            ),
          ),
          const SizedBox(width: 8),
          _GlassPill(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  user?.displayName ?? 'Admin',
                  style: const TextStyle(color: _AdminColors.text),
                ),
                const SizedBox(width: 10),
                Semantics(
                  button: true,
                  label: 'Déconnexion',
                  enabled: !isSigningOut,
                  child: _GlassIconButton(
                    icon: isSigningOut
                        ? Icons.hourglass_empty_rounded
                        : Icons.logout_rounded,
                    tooltip: 'Déconnexion',
                    onTap: handleSignOut,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GlassSearchField extends StatelessWidget { final TextEditingController controller; final FocusNode focusNode; const _GlassSearchField({required this.controller, required this.focusNode}); @override Widget build(BuildContext context) => const SizedBox(); }
class _AdminSidebarRail extends StatelessWidget { final AdminModule module; final String? role; const _AdminSidebarRail({required this.module, required this.role}); @override Widget build(BuildContext context) => _AdminNavList(module: module, role: role, isDrawer: false); }
class _AdminDrawer extends StatelessWidget { final AdminModule module; final String? role; const _AdminDrawer({required this.module, required this.role}); @override Widget build(BuildContext context) => _AdminNavList(module: module, role: role, isDrawer: true); }
class _AdminNavList extends StatelessWidget { final AdminModule module; final String? role; final bool isDrawer; const _AdminNavList({required this.module, required this.role, required this.isDrawer}); @override Widget build(BuildContext context) => ListView(children: [TextButton(onPressed: ()=> context.go('/admin/overview'), child: const Text('Overview'))]); }
class _GlassSurface extends StatelessWidget { final Widget child; final EdgeInsets padding; const _GlassSurface({required this.child, required this.padding}); @override Widget build(BuildContext context) => child; }
class _GlassPill extends StatelessWidget { final Widget child; const _GlassPill({required this.child}); @override Widget build(BuildContext context) => child; }
class _GlassIconButton extends StatelessWidget { final IconData icon; final String tooltip; final VoidCallback onTap; const _GlassIconButton({required this.icon, required this.tooltip, required this.onTap}); @override Widget build(BuildContext context) => IconButton(icon: Icon(icon), tooltip: tooltip, onPressed: onTap); }
