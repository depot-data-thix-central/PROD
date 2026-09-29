// lib/presentation/home/widgets/home_services_constellation.dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:thix_id/l10n/app_localizations.dart';
import 'package:thix_id/services/notification_counters_service.dart';
import 'package:thix_id/core/theme/thix_design_policy.dart';

// ============================================================================
// CONSTANTS
// ============================================================================
const double _kBarCollapsedWidth = 58.0;
const double _kBarExpandedWidth = 150.0;
const double _kHubRadius = 32.0;

// ============================================================================
// DATA MODEL
// ============================================================================
class _ServiceNodeData {
  final String key;
  final IconData icon;
  final String title;
  final int? badge;
  final Color color;

  const _ServiceNodeData({
    required this.key,
    required this.icon,
    required this.title,
    required this.color,
    this.badge,
  });
}

// ============================================================================
// MAIN WIDGET
// ============================================================================
class HomeServicesConstellation extends StatefulWidget {
  final SectionBadgeCounts counts;
  final void Function(String key) onServiceTap;
  final VoidCallback onHomeTap;
  final VoidCallback onMiniAppsTap;
  final VoidCallback onDocumentsTap;
  final VoidCallback onProfileTap;
  final VoidCallback onScanTap;
  final String? avatarUrl;

  const HomeServicesConstellation({
    super.key,
    required this.counts,
    required this.onServiceTap,
    required this.onHomeTap,
    required this.onMiniAppsTap,
    required this.onDocumentsTap,
    required this.onProfileTap,
    required this.onScanTap,
    this.avatarUrl,
  });

  @override
  State<HomeServicesConstellation> createState() =>
      _HomeServicesConstellationState();
}

class _HomeServicesConstellationState extends State<HomeServicesConstellation> {
  static const Color _colorCorporate = ThixPolicy.primaryDeep;
  static const Color _colorPrimary = ThixPolicy.primary;
  static const Color _colorMoney = ThixPolicy.gold;
  static const Color _colorHealth = ThixPolicy.danger;
  static const Color _colorMarket = ThixPolicy.domainMarket;
  static const Color _colorNetwork = ThixPolicy.domainNetwork;
  static const Color _colorLearning = ThixPolicy.domainLearning;
  static const Color _colorEvent = ThixPolicy.warning;

  bool _isLeftExpanded = false;
  bool _isRightExpanded = false;

  @override
  void initState() {
    super.initState();
    debugPrint('[ServicesBar] 🌐 Initialized');
  }

  List<_ServiceNodeData> _getLeftNodes(AppLocalizations l10n) {
    final c = widget.counts;
    return [
      _ServiceNodeData(
        key: 'thixMoney',
        icon: Icons.account_balance_wallet_rounded,
        title: 'Thix ${l10n.t('svc_money')}',
        badge: c.money,
        color: _colorMoney,
      ),
      _ServiceNodeData(
        key: 'thixMedia',
        icon: Icons.video_collection_rounded,
        title: 'Thix ${l10n.t('svc_media')}',
        badge: c.media,
        color: _colorNetwork,
      ),
      _ServiceNodeData(
        key: 'monPays',
        icon: Icons.flag_rounded,
        title: 'Thix ${l10n.t('svc_country')}',
        badge: c.monPays,
        color: _colorCorporate,
      ),
      _ServiceNodeData(
        key: 'thixInfo',
        icon: Icons.newspaper_rounded,
        title: 'Thix ${l10n.t('svc_news')}',
        badge: c.info,
        color: _colorPrimary,
      ),
      _ServiceNodeData(
        key: 'evenements',
        icon: Icons.event_rounded,
        title: 'Thix ${l10n.t('svc_event')}',
        badge: c.events,
        color: _colorEvent,
      ),
      _ServiceNodeData(
        key: 'thixMarket',
        icon: Icons.storefront_rounded,
        title: 'Thix ${l10n.t('svc_market')}',
        badge: c.market,
        color: _colorMarket,
      ),
    ];
  }

  List<_ServiceNodeData> _getRightNodes(AppLocalizations l10n) {
    final c = widget.counts;
    return [
      _ServiceNodeData(
        key: 'reservation',
        icon: Icons.confirmation_number_rounded,
        title: 'Thix ${l10n.t('svc_booking')}',
        badge: c.reservation,
        color: _colorPrimary,
      ),
      _ServiceNodeData(
        key: 'emplois',
        icon: Icons.work_rounded,
        title: 'Thix ${l10n.t('svc_jobs')}',
        badge: c.jobs,
        color: _colorCorporate,
      ),
      _ServiceNodeData(
        key: 'formations',
        icon: Icons.school_rounded,
        title: 'Thix ${l10n.t('svc_learning')}',
        badge: c.formations,
        color: _colorLearning,
      ),
      _ServiceNodeData(
        key: 'opportunites',
        icon: Icons.lightbulb_rounded,
        title: 'Thix ${l10n.t('svc_opps')}',
        badge: c.opportunities,
        color: _colorMoney,
      ),
      _ServiceNodeData(
        key: 'reseauPro',
        icon: Icons.groups_rounded,
        title: 'Thix ${l10n.t('svc_pro')}',
        badge: c.network,
        color: _colorNetwork,
      ),
      _ServiceNodeData(
        key: 'thixSante',
        icon: Icons.local_hospital_rounded,
        title: 'Thix ${l10n.t('svc_health')}',
        badge: c.health,
        color: _colorHealth,
      ),
    ];
  }

  void _handleProfileTap() {
    if (!mounted) return;
    HapticFeedback.lightImpact();
    debugPrint('[ServicesBar] 👤 Profile tap');
    widget.onProfileTap();
  }

  void _handleServiceTap(String key) {
    if (!mounted) return;
    HapticFeedback.selectionClick();
    debugPrint('[ServicesBar] 🔷 Service tap: $key');
    widget.onServiceTap(key);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final leftNodes = _getLeftNodes(l10n);
    final rightNodes = _getRightNodes(l10n);

    return RepaintBoundary(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: ThixPolicy.s16,
          vertical: ThixPolicy.s8,
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // BARRES LATÉRALES GAUCHE ET DROITE
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Barre Gauche
                _SideServiceBar(
                  nodes: leftNodes,
                  isExpanded: _isLeftExpanded,
                  accentColor: ThixPolicy.gold,
                  onToggleExpand: () {
                    HapticFeedback.lightImpact();
                    setState(() => _isLeftExpanded = !_isLeftExpanded);
                  },
                  onServiceTap: _handleServiceTap,
                ),

                // Barre Droite
                _SideServiceBar(
                  nodes: rightNodes,
                  isExpanded: _isRightExpanded,
                  accentColor: ThixPolicy.gold,
                  onToggleExpand: () {
                    HapticFeedback.lightImpact();
                    setState(() => _isRightExpanded = !_isRightExpanded);
                  },
                  onServiceTap: _handleServiceTap,
                ),
              ],
            ),

            // HUB CENTRAL (Profil)
            _HubButton(
              radius: _kHubRadius,
              avatarUrl: widget.avatarUrl,
              onTap: _handleProfileTap,
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// SIDE BAR WIDGET (Rétractable)
// ============================================================================
class _SideServiceBar extends StatelessWidget {
  final List<_ServiceNodeData> nodes;
  final bool isExpanded;
  final Color accentColor;
  final VoidCallback onToggleExpand;
  final void Function(String key) onServiceTap;

  const _SideServiceBar({
    required this.nodes,
    required this.isExpanded,
    required this.accentColor,
    required this.onToggleExpand,
    required this.onServiceTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 280),
      curve: Curves.fastOutSlowIn,
      width: isExpanded ? _kBarExpandedWidth : _kBarCollapsedWidth,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: ThixPolicy.border.withOpacity(0.8),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // En-tête cliquable pour étendre / réduire la barre
          GestureDetector(
            onTap: onToggleExpand,
            child: Container(
              height: 32,
              decoration: BoxDecoration(
                color: accentColor,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(18),
                ),
              ),
              child: Center(
                child: Icon(
                  isExpanded
                      ? Icons.unfold_less_rounded
                      : Icons.unfold_more_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ),
          ),

          // Liste des icônes de service
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (int i = 0; i < nodes.length; i++) ...[
                  if (i > 0)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: Divider(
                        height: 6,
                        thickness: 0.8,
                        color: ThixPolicy.border.withOpacity(0.4),
                      ),
                    ),
                  _BarItemTile(
                    node: nodes[i],
                    isExpanded: isExpanded,
                    onTap: () => onServiceTap(nodes[i].key),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// TILE ITEM (Bouton individuel)
// ============================================================================
class _BarItemTile extends StatelessWidget {
  final _ServiceNodeData node;
  final bool isExpanded;
  final VoidCallback onTap;

  const _BarItemTile({
    required this.node,
    required this.isExpanded,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        child: Row(
          mainAxisAlignment:
              isExpanded ? MainAxisAlignment.start : MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: ThixPolicy.border.withOpacity(0.6),
                      width: 1.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Icon(node.icon, color: node.color, size: 20),
                ),
                if (node.badge != null && node.badge! > 0)
                  Positioned(
                    top: -2,
                    right: -2,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        color: ThixPolicy.danger,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 14,
                        minHeight: 14,
                      ),
                      child: Center(
                        child: Text(
                          '${node.badge}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 7.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            if (isExpanded) ...[
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  node.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: ThixPolicy.textMain,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// HUB BUTTON (Profil Central)
// ============================================================================
class _HubButton extends StatelessWidget {
  final double radius;
  final String? avatarUrl;
  final VoidCallback onTap;

  const _HubButton({
    required this.radius,
    required this.avatarUrl,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Profil utilisateur',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: radius * 2,
          height: radius * 2,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: ThixPolicy.gold,
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.12),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(3),
          child: ClipOval(
            child: (avatarUrl != null && avatarUrl!.trim().isNotEmpty)
                ? CachedNetworkImage(
                    imageUrl: avatarUrl!.trim(),
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      color: Colors.white24,
                      child: const Center(
                        child: SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: Colors.white24,
                      child: const Icon(
                        Icons.person_rounded,
                        color: Colors.white,
                        size: 26,
                      ),
                    ),
                  )
                : Container(
                    color: Colors.white24,
                    child: const Icon(
                      Icons.person_rounded,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
