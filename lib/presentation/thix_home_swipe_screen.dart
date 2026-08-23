/// Conteneur principal — swipe SOS ↔ RECHERCHE ↔ RETROUVE
import 'package:flutter/material.dart';

// ✅ POLICY THIX APPLIQUÉE
import 'package:thix_id/core/theme/thix_design_policy.dart';

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
    return Scaffold(
      backgroundColor: ThixPolicy.inkDeep,
      body: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(ThixPolicy.s16, ThixPolicy.s8, ThixPolicy.s16, 0),
              child: _SectionIndicator(
                current: _page,
                onSos: () => _goTo(0),
                onRecherche: () => _goTo(1),
                onRetrouve: () => _goTo(2),
              ),
            ),
          ),
          Expanded(
            child: PageView(
              controller: _pageController,
              onPageChanged: (i) => setState(() => _page = i),
              physics: const BouncingScrollPhysics(),
              children: const [
                _KeepAlive(child: ThixSosScreen()),
                _KeepAlive(child: ThixRechercheScreen()),
                _KeepAlive(child: ThixRetrouveScreen()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

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
    return Container(
      padding: const EdgeInsets.all(ThixPolicy.s4),
      decoration: BoxDecoration(
        color: ThixPolicy.card.withOpacity(0.08),
        borderRadius: BorderRadius.circular(ThixPolicy.rSm),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _Tab(
              label: 'SOS',
              icon: Icons.sos_rounded,
              selected: current == 0,
              selectedColor: ThixPolicy.danger,
              onTap: onSos,
            ),
          ),
          Expanded(
            child: _Tab(
              label: 'RECHERCHE',
              icon: Icons.person_search_rounded,
              selected: current == 1,
              selectedColor: ThixPolicy.primary,
              onTap: onRecherche,
            ),
          ),
          Expanded(
            child: _Tab(
              label: 'RETROUVE',
              icon: Icons.search_rounded,
              selected: current == 2,
              selectedColor: ThixPolicy.gold,
              onTap: onRetrouve,
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
  });

  final String label;
  final IconData icon;
  final bool selected;
  final Color selectedColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? selectedColor.withOpacity(0.20) : Colors.transparent,
      borderRadius: BorderRadius.circular(ThixPolicy.rXs),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(ThixPolicy.rXs),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: ThixPolicy.s12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: selected ? selectedColor : Colors.white54),
              const SizedBox(width: ThixPolicy.s6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: ThixPolicy.labelStyle.copyWith(
                    fontSize: 11.5,
                    fontWeight: selected ? ThixPolicy.bold : ThixPolicy.semiBold,
                    color: selected ? selectedColor : Colors.white54,
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
