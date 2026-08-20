/// Conteneur principal — swipe SOS ↔ RECHERCHE ↔ RETROUVE
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'thix_sos/thix_sos_screen.dart';
import 'thix_recherche/thix_recherche_screen.dart';
import 'thix_retrouve/thix_retrouve_screen.dart';

class ThixHomeSwipeScreen extends StatefulWidget {
  const ThixHomeSwipeScreen({super.key, this.initialPage = 0});

  /// 0 = SOS, 1 = RECHERCHE, 2 = RETROUVE
  final int initialPage;

  @override
  State<ThixHomeSwipeScreen> createState() => _ThixHomeSwipeScreenState();
}

class _ThixHomeSwipeScreenState extends State<ThixHomeSwipeScreen> {
  late final PageController _pageController;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _page = widget.initialPage.clamp(0, 2);
    _pageController = PageController(initialPage: _page);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goTo(int index) {
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Fond sombre pour SOS, clair pour RECHERCHE & RETROUVE
    final bgColor = _page == 0
        ? const Color(0xFF0A0A0F)
        : const Color(0xFFF8F9FC);

    return Scaffold(
      backgroundColor: bgColor,
      body: Column(
        children: [
          // Indicateur de section (sous la status bar)
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: _SectionIndicator(
                current: _page,
                onSos: () => _goTo(0),
                onRecherche: () => _goTo(1),
                onRetrouve: () => _goTo(2),
              ),
            ),
          ),

          // Pages
          Expanded(
            child: PageView(
              controller: _pageController,
              onPageChanged: (i) => setState(() => _page = i),
              physics: const BouncingScrollPhysics(),
              children: const [
                // Page 0 — THIX SOS
                _KeepAlive(child: ThixSosScreen()),
                // Page 1 — THIX RECHERCHE (milieu)
                _KeepAlive(child: ThixRechercheScreen()),
                // Page 2 — THIX RETROUVE
                _KeepAlive(child: ThixRetrouveScreen()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Garde l’état de chaque page (évite rebuild total au swipe)
class _KeepAlive extends StatefulWidget {
  const _KeepAlive({required this.child});
  final Widget child;

  @override
  State<_KeepAlive> createState() => _KeepAliveState();
}

class _KeepAliveState extends State<_KeepAlive>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

class _SectionIndicator extends StatelessWidget {
  const _SectionIndicator({
    required this.current,
    required this.onSos,
    required this.onRecherche,
    required this.onRetrouve,
  });

  final int current;
  final VoidCallback onSos;
  final VoidCallback onRecherche;
  final VoidCallback onRetrouve;

  @override
  Widget build(BuildContext context) {
    final isDark = current == 0; // SOS = thème sombre

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? Colors.white10 : Colors.black.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          // ——— SOS ———
          Expanded(
            child: _Tab(
              label: 'SOS',
              icon: Icons.sos,
              selected: current == 0,
              selectedColor: const Color(0xFFEF4444),
              onTap: onSos,
              dark: isDark,
            ),
          ),
          // ——— RECHERCHE (milieu) ———
          Expanded(
            child: _Tab(
              label: 'RECHERCHE',
              icon: Icons.person_search,
              selected: current == 1,
              selectedColor: const Color(0xFF2563EB),
              onTap: onRecherche,
              dark: isDark,
            ),
          ),
          // ——— RETROUVE ———
          Expanded(
            child: _Tab(
              label: 'RETROUVE',
              icon: Icons.search,
              selected: current == 2,
              selectedColor: const Color(0xFFF59E0B),
              onTap: onRetrouve,
              dark: isDark,
            ),
          ),
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({
    required this.label,
    required this.icon,
    required this.selected,
    required this.selectedColor,
    required this.onTap,
    required this.dark,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final Color selectedColor;
  final VoidCallback onTap;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? selectedColor.withOpacity(dark ? 0.25 : 0.15)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 15,
                color: selected
                    ? selectedColor
                    : (dark ? Colors.white38 : Colors.black38),
              ),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight:
                        selected ? FontWeight.w800 : FontWeight.w600,
                    color: selected
                        ? selectedColor
                        : (dark ? Colors.white38 : Colors.black38),
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
