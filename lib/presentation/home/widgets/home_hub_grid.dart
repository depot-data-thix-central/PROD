// lib/presentation/home/widgets/home_hub_grid.dart
//
// Grille THIX HUB : 3 + 3 + 2 tuiles glass blanches (comme la maquette).
// ✅ Tailles d'icônes conservées du code d'origine : icône 22, étiquette 10.5.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:thix_id/l10n/app_localizations.dart';
import 'package:thix_id/services/notification_counters_service.dart';

import 'home_hub_more_sheet.dart';
import 'home_hub_settings.dart';
import 'home_theme.dart';

const double _kTileIconSize = 22.0; // ← taille d'icône du code existant
const double _kTileCircle = 40.0;
const double _kTileLabelSize = 10.5;
const double _kTileHeight = 88.0;
const double _kGap = 12.0;
const int _kMaxBadge = 99;

class _TileData {
  final String key;
  final IconData icon;
  final String label;
  final int badge;
  const _TileData(this.key, this.icon, this.label, this.badge);
}

class HomeHubGrid extends StatelessWidget {
  final SectionBadgeCounts counts;
  final Color primary;
  final Color accent;

  /// Clés : social, chat, pro, business, market, events, sona
  final ValueChanged<String> onTap;

  /// Actions du panneau « More… » (sos, vault, scanQr, thixWed, formations…)
  final ValueChanged<String> onMoreAction;

  const HomeHubGrid({
    super.key,
    required this.counts,
    required this.primary,
    required this.accent,
    required this.onTap,
    required this.onMoreAction,
  });

  int get _moreBadge =>
      counts.formations +
      counts.opportunities +
      counts.jobs +
      counts.info +
      counts.health +
      counts.money +
      counts.monPays +
      counts.reservation;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    final items = <_TileData>[
      _TileData('social', Icons.groups_rounded, 'THIX Social', counts.media),
      _TileData('chat', Icons.chat_bubble_rounded, 'THIX Chat', counts.messages),
      _TileData('pro', Icons.work_rounded, 'THIX Pro', counts.network),
      _TileData('business', Icons.trending_up_rounded, 'THIX Business', 0),
      _TileData('market', Icons.shopping_cart_rounded, 'THIX Market', counts.market),
      _TileData('events', Icons.calendar_month_rounded, 'THIX Events', counts.events),
      const _TileData('sona', Icons.memory_rounded, 'SONA AI', 0),
      _TileData('more', Icons.more_horiz_rounded,
          hubTr(l10n, 'home_more', 'More…'), _moreBadge),
    ];

    return LayoutBuilder(
      builder: (context, c) {
        final w = (c.maxWidth - _kGap * 2) / 3;

        Widget tile(int i) => _Reveal(
              index: i,
              child: _HubTile(
                width: w,
                data: items[i],
                primary: primary,
                accent: accent,
                onTap: () {
                  HapticFeedback.selectionClick();
                  if (items[i].key == 'more') {
                    HubMoreSheet.show(
                      context,
                      counts: counts,
                      primary: primary,
                      onAction: onMoreAction,
                    );
                  } else {
                    onTap(items[i].key);
                  }
                },
              ),
            );

        return RepaintBoundary(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(children: [
                tile(0),
                const SizedBox(width: _kGap),
                tile(1),
                const SizedBox(width: _kGap),
                tile(2),
              ]),
              const SizedBox(height: _kGap),
              Row(children: [
                tile(3),
                const SizedBox(width: _kGap),
                tile(4),
                const SizedBox(width: _kGap),
                tile(5),
              ]),
              const SizedBox(height: _kGap),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                tile(6),
                const SizedBox(width: _kGap),
                tile(7),
              ]),
            ],
          ),
        );
      },
    );
  }
}

class _Reveal extends StatelessWidget {
  final int index;
  final Widget child;
  const _Reveal({required this.index, required this.child});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: Duration(milliseconds: 420 + index * 70),
      curve: Curves.easeOutCubic,
      builder: (_, v, c) => Opacity(
        opacity: v,
        child: Transform.translate(offset: Offset(0, (1 - v) * 18), child: c),
      ),
      child: child,
    );
  }
}

class _HubTile extends StatefulWidget {
  final double width;
  final _TileData data;
  final Color primary;
  final Color accent;
  final VoidCallback onTap;

  const _HubTile({
    required this.width,
    required this.data,
    required this.primary,
    required this.accent,
    required this.onTap,
  });

  @override
  State<_HubTile> createState() => _HubTileState();
}

class _HubTileState extends State<_HubTile> {
  bool _pressed = false;

  void _setPressed(bool v) {
    if (!mounted || _pressed == v) return;
    setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    final p = widget.primary;
    final badgeText = d.badge > _kMaxBadge ? '$_kMaxBadge+' : '${d.badge}';

    return Semantics(
      button: true,
      label: d.badge > 0 ? '${d.label}, ${d.badge}' : d.label,
      child: GestureDetector(
        onTap: widget.onTap,
        onTapDown: (_) => _setPressed(true),
        onTapUp: (_) => _setPressed(false),
        onTapCancel: () => _setPressed(false),
        child: AnimatedScale(
          scale: _pressed ? 0.95 : 1.0,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          child: Container(
            width: widget.width,
            height: _kTileHeight,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.94),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.white, width: 1.4),
              boxShadow: [
                BoxShadow(
                  color: p.withOpacity(0.12),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: _kTileCircle,
                      height: _kTileCircle,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [p.withOpacity(0.07), p.withOpacity(0.15)],
                        ),
                        border: Border.all(color: p.withOpacity(0.14), width: 1),
                      ),
                      alignment: Alignment.center,
                      child: Icon(d.icon, size: _kTileIconSize, color: p),
                    ),
                    if (d.badge > 0)
                      Positioned(
                        top: -4,
                        right: -7,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 1.5),
                          constraints:
                              const BoxConstraints(minWidth: 16, minHeight: 16),
                          decoration: BoxDecoration(
                            color: HomeTheme.alert,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.white, width: 1.4),
                          ),
                          child: Text(
                            badgeText,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    d.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: HomeTheme.ink,
                      fontSize: _kTileLabelSize,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
