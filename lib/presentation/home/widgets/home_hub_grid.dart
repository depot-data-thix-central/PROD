// lib/presentation/home/widgets/home_hub_grid.dart
//
// Grille THIX HUB : 3 + 3 + 2 — SANS cadre, juste l'icône + le libellé.
// Halo dans la couleur du voile pour rester lisible sur la photo.
// ✅ Taille d'icône conservée du code d'origine (22) : modifie _kTileIconSize
//    si tu veux la changer.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:thix_id/l10n/app_localizations.dart';
import 'package:thix_id/services/notification_counters_service.dart';

import 'home_hub_more_sheet.dart';
import 'home_hub_settings.dart';
import 'home_theme.dart';

const double _kTileIconSize = 22.0; // ← taille d'icône du code existant
const double _kTileLabelSize = 10.5;
const double _kTileHeight = 70.0;
const double _kGap = 14.0;
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
  final HubSettings settings;

  /// Clés : thidia, chat, pro, sos, market, events, sona
  final ValueChanged<String> onTap;

  /// Actions du panneau « More… » (sos, vault, scanQr, thixWed, formations…)
  final ValueChanged<String> onMoreAction;

  const HomeHubGrid({
    super.key,
    required this.counts,
    required this.settings,
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
      // ✅ Modifié : Social -> Thidia (icône vidéo)
      _TileData('thidia', Icons.video_library_rounded, 'Thidia', counts.media),
      _TileData('chat', Icons.chat_bubble_rounded, 'THIX Chat', counts.messages),
      // ✅ Modifié : Icône différente pour Pro (business_center)
      _TileData('pro', Icons.business_center_rounded, 'THIX Pro', counts.network),
      // ✅ Modifié : Business -> SOS
      _TileData('sos', Icons.emergency_rounded, 'THIX SOS', 0),
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
                settings: settings,
                onTap: () {
                  HapticFeedback.selectionClick();
                  if (items[i].key == 'more') {
                    HubMoreSheet.show(
                      context,
                      counts: counts,
                      primary: settings.primary,
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
              Row(children: [tile(0), tile(1), tile(2)]
                  .expand((w) => [w, const SizedBox(width: _kGap)])
                  .toList()
                ..removeLast()),
              const SizedBox(height: _kGap),
              Row(children: [tile(3), tile(4), tile(5)]
                  .expand((w) => [w, const SizedBox(width: _kGap)])
                  .toList()
                ..removeLast()),
              const SizedBox(height: _kGap),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [tile(6), const SizedBox(width: _kGap), tile(7)],
              ),
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
  final HubSettings settings;
  final VoidCallback onTap;

  const _HubTile({
    required this.width,
    required this.data,
    required this.settings,
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
    final s = widget.settings;
    final badgeText = d.badge > _kMaxBadge ? '$_kMaxBadge+' : '${d.badge}';

    // Halo dans la couleur du voile → lisibilité sur n'importe quelle photo.
    final halo = <Shadow>[
      Shadow(color: s.veilColor.withOpacity(0.95), blurRadius: 6),
      Shadow(color: s.veilColor.withOpacity(0.75), blurRadius: 14),
    ];

    return Semantics(
      button: true,
      label: d.badge > 0 ? '${d.label}, ${d.badge}' : d.label,
      child: GestureDetector(
        onTap: widget.onTap,
        onTapDown: (_) => _setPressed(true),
        onTapUp: (_) => _setPressed(false),
        onTapCancel: () => _setPressed(false),
        behavior: HitTestBehavior.opaque,
        child: AnimatedScale(
          scale: _pressed ? 0.92 : 1.0,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          child: SizedBox(
            width: widget.width,
            height: _kTileHeight,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(
                      d.icon,
                      size: _kTileIconSize,
                      color: s.primary,
                      shadows: halo,
                    ),
                    if (d.badge > 0)
                      Positioned(
                        top: -7,
                        right: -11,
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
                Text(
                  d.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: s.textColor,
                    fontSize: _kTileLabelSize,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                    shadows: halo,
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
