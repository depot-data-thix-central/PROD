// lib/presentation/thix_weeding/pages/home/thix_weeding_home_page.dart
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:thix_id/presentation/thix_weeding/pages/staff/providers/thix_weeding_providers.dart';

// ═══════════════════════════════════════════════════════════════════════════
// PALETTE v5.0 — TRUE DEEP ROSE & GLASS
// ═══════════════════════════════════════════════════════════════════════════
class _W {
  static const Color bg = Color(0xFFFDFBFC); // Blanc cassé très propre
  static const Color surface = Colors.white;
  static const Color tile = Color(0xFFF9F0F3); // Fond doux rose très pâle
  
  static const Color ink = Color(0xFF1A1A1A);
  static const Color inkSoft = Color(0xFF6B6B6B);
  static const Color line = Color(0xFFEBE1E4);
  
  static const Color roseDark = Color(0xFFC2185B); // Rose foncé élégant
  static const Color rose = Color(0xFFD81B60);     // Rose vif principal
  static const Color roseLight = Color(0xFFF48FB1); // Rose pastel
  static const Color gold = Color(0xFFD4A574);
}

final homeCategoriesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return [
    {'label': 'Salles', 'icon': Icons.villa_outlined, 'key': 'salle'},
    {'label': 'Traiteurs', 'icon': Icons.restaurant_outlined, 'key': 'traiteur'},
    {'label': 'Cérémonie', 'icon': Icons.mic_none_outlined, 'key': 'mc'},
    {'label': 'Décor', 'icon': Icons.local_florist_outlined, 'key': 'decor'},
    {'label': 'Photos', 'icon': Icons.camera_alt_outlined, 'key': 'photo'},
    {'label': 'Vidéos', 'icon': Icons.videocam_outlined, 'key': 'video'},
    {'label': 'DJ & Son', 'icon': Icons.music_note_outlined, 'key': 'dj'},
    {'label': 'Robes', 'icon': Icons.checkroom_outlined, 'key': 'robe'},
    {'label': 'Costumes', 'icon': Icons.checkroom_outlined, 'key': 'costume'},
    {'label': 'Plus', 'icon': Icons.grid_view_rounded, 'key': 'autre'},
  ];
});

class ThixWeedingHomePage extends ConsumerStatefulWidget {
  const ThixWeedingHomePage({super.key});

  @override
  ConsumerState<ThixWeedingHomePage> createState() => _ThixWeedingHomePageState();
}

class _ThixWeedingHomePageState extends ConsumerState<ThixWeedingHomePage> {
  late final TextEditingController _idController;
  late final FocusNode _focusNode;
  final ScrollController _scrollController = ScrollController();
  final ValueNotifier<double> _scrollY = ValueNotifier<double>(0);
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _idController = TextEditingController();
    _focusNode = FocusNode();
    _scrollController.addListener(() => _scrollY.value = _scrollController.position.pixels);
  }

  @override
  void dispose() {
    _idController.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    _scrollY.dispose();
    super.dispose();
  }

  // ───────────────────────── NAVIGATION PRESTATAIRE ─────────────────────────
  Future<void> _onProviderAccess() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      _snack('Connectez-vous pour accéder à l\'espace prestataire');
      context.push('/thix-weeding/auth/login?redirect=/thix-weeding/provider/dashboard');
      return;
    }
    // Vérifier si le prestataire existe déjà
    final res = await Supabase.instance.client
        .from('thix_weeding_providers')
        .select('id')
        .eq('owner_id', user.id)
        .maybeSingle();

    if (res == null) {
      context.push('/thix-weeding/provider/register');
    } else {
      context.push('/thix-weeding/provider/dashboard');
    }
  }

  void _onSearch() async {
    HapticFeedback.mediumImpact();
    final code = _idController.text.trim().toUpperCase();
    if (code.isEmpty) {
      _focusNode.requestFocus();
      return;
    }
    setState(() => _isSearching = true);
    FocusScope.of(context).unfocus();
    
    try {
      // Sécurité XSS : On échappe les caractères spéciaux avant requête
      final safeCode = _sanitizeInput(code);
      
      final res = await Supabase.instance.client
          .from('thix_weeding_weddings')
          .select('id, unique_code, invitation_published')
          .eq('unique_code', safeCode)
          .maybeSingle();
          
      if (!mounted) return;
      if (res == null) {
        _snack('Code "$safeCode" introuvable.', error: true);
        return;
      }
      if (res['invitation_published'] != true) {
        _snack('Cette invitation n\'est pas encore publiée.', error: true);
        return;
      }
      context.push('/thix-weeding/guest/${res['id']}');
    } catch (e) {
      if (!mounted) return;
      _snack('Erreur de connexion.', error: true);
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  // Sécurité : empêche l'injection de code
  String _sanitizeInput(String input) {
    return input.replaceAll(RegExp(r'[<>]'), '').trim();
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: error ? _W.roseDark : _W.ink,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        content: Text(msg, style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600)),
      ));
  }

  @override
  Widget build(BuildContext context) {
    final catsAsync = ref.watch(homeCategoriesProvider);

    return Scaffold(
      backgroundColor: _W.bg,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // 1. HERO SECTION (Design épuré, verre dépoli)
          _buildHeroSection(),
          
          // 2. SCROLL CONTENT (Catégories + Prestataires)
          CustomScrollView(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
            slivers: [
              // Spacer pour passer sous le Hero
              SliverToBoxAdapter(child: SizedBox(height: MediaQuery.of(context).size.height * 0.55)),
              
              // Catégories
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: catsAsync.when(
                    data: (cats) => _CategoryGrid(categories: cats, onTap: (key) {
                      context.push('/thix-weeding/providers/$key');
                    }),
                    loading: () => const SizedBox(height: 120),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 24)),

              // Bannière Prestataire (Le fameux bouton d'accès)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _ProviderBanner(onTap: _onProviderAccess),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 40)),
            ],
          ),

          // 3. APP BAR GLASSMORPHISM
          _GlassAppBar(topPad: MediaQuery.paddingOf(context).top, scrollY: _scrollY),
        ],
      ),
    );
  }

  Widget _buildHeroSection() {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.55,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Image de fond (Salle de mariage élégante)
          Image.network(
            'https://images.unsplash.com/photo-1519225421980-715cb0215aed?w=1200&q=80',
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(color: _W.tile),
          ),
          // Overlay sombre/rosé pour la lisibilité
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.4),
                  Colors.transparent,
                  _W.bg, // Transition fluide vers le fond de la page
                ],
                stops: const [0.0, 0.6, 1.0],
              ),
            ),
          ),
          // Join Bar (Recherche de code)
          Positioned(
            left: 20,
            right: 20,
            bottom: 40,
            child: _JoinBar(
              controller: _idController,
              focusNode: _focusNode,
              isLoading: _isSearching,
              onSearch: _onSearch,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// WIDGETS DU HOME PAGE
// ═══════════════════════════════════════════════════════════════════════════

class _GlassAppBar extends StatelessWidget {
  final double topPad;
  final ValueNotifier<double> scrollY;

  const _GlassAppBar({required this.topPad, required this.scrollY});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0, left: 0, right: 0,
      child: ValueListenableBuilder<double>(
        valueListenable: scrollY,
        builder: (_, y, __) {
          final t = (y / 200).clamp(0.0, 1.0);
          return ClipRRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10 * t, sigmaY: 10 * t),
              child: Container(
                padding: EdgeInsets.fromLTRB(20, topPad + 10, 20, 16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.85 * t),
                  border: Border(bottom: BorderSide(color: _W.line.withOpacity(t))),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36, height: 36,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(colors: [_W.roseDark, _W.rose]),
                        shape: BoxShape.circle,
                      ),
                      child: const Center(child: Icon(Icons.favorite_rounded, color: Colors.white, size: 18)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'THIX WEDDING',
                        style: GoogleFonts.inter(
                          fontSize: 16, fontWeight: FontWeight.w900,
                          color: Color.lerp(Colors.white, _W.ink, t),
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CategoryGrid extends StatelessWidget {
  final List<Map<String, dynamic>> categories;
  final void Function(String key) onTap;

  const _CategoryGrid({required this.categories, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      alignment: WrapAlignment.center,
      children: categories.map((c) {
        return GestureDetector(
          onTap: () => onTap(c['key']),
          child: SizedBox(
            width: 64,
            child: Column(
              children: [
                Container(
                  width: 56, height: 56,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: _W.rose.withOpacity(0.1), blurRadius: 15, offset: const Offset(0, 5))],
                  ),
                  child: Icon(c['icon'] as IconData, color: _W.roseDark, size: 24),
                ),
                const SizedBox(height: 8),
                Text(
                  c['label'],
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: _W.ink),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _ProviderBanner extends StatelessWidget {
  final VoidCallback onTap;
  const _ProviderBanner({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [_W.roseDark, _W.rose],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: _W.roseDark.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 8))],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Vous êtes un professionnel ?', style: GoogleFonts.inter(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text('Espace Prestataire', style: GoogleFonts.playfairDisplay(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Text('Gérez vos services, réservations et tâches.', style: GoogleFonts.inter(color: Colors.white.withOpacity(0.9), fontSize: 11)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
              child: const Icon(Icons.arrow_forward_rounded, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}

class _JoinBar extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isLoading;
  final VoidCallback onSearch;

  const _JoinBar({required this.controller, required this.focusNode, required this.isLoading, required this.onSearch});

  @override
  State<_JoinBar> createState() => _JoinBarState();
}

class _JoinBarState extends State<_JoinBar> {
  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.85),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white, width: 1.5),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Rejoindre un mariage', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w900, color: _W.ink)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 50,
                      decoration: BoxDecoration(
                        color: _W.bg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: _W.line),
                      ),
                      child: TextField(
                        controller: widget.controller,
                        focusNode: widget.focusNode,
                        textCapitalization: TextCapitalization.characters,
                        style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: _W.ink),
                        decoration: InputDecoration(
                          hintText: 'THIX-W-XXXX-XXXX',
                          hintStyle: GoogleFonts.inter(fontSize: 12, color: _W.inkSoft),
                          prefixIcon: const Icon(Icons.search, color: _W.roseDark, size: 20),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onSubmitted: (_) => widget.onSearch(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: widget.isLoading ? null : widget.onSearch,
                    child: Container(
                      width: 50, height: 50,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [_W.roseDark, _W.rose]),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: widget.isLoading
                          ? const Center(child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.arrow_forward_rounded, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
