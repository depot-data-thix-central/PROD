// lib/presentation/home/widgets/home_quick_actions.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:thix_id/services/notification_counters_service.dart';
import 'package:thix_id/core/theme/thix_design_policy.dart';

// ============================================================================
// CONSTANTS
// ============================================================================
const double _kItemWidth = 58.0;
const double _kCircleSize = 42.0;
const double _kIconSize = 18.0;
const double _kLabelFontSize = 8.5;
const int _kMaxLabelLength = 12;
const int _kMaxBadgeDisplay = 99;

const Duration _kPulseDuration = Duration(milliseconds: 900);
const Curve _kPulseCurve = Curves.easeInOut;

// ============================================================================
// CONFIGURATION DES 4 BOUTONS
// ============================================================================
class _ActionConfig {
  final IconData icon;
  final String label;
  final Color accent;
  final String semanticsLabel;
  final List<ThixSection> sections;
  final bool pulseBadge;
  final bool isDanger;
  /// Si true, marque les sections comme lues quand l'action est tapée
  final bool autoMarkRead;

  const _ActionConfig({
    required this.icon,
    required this.label,
    required this.accent,
    required this.semanticsLabel,
    required this.sections,
    this.pulseBadge = false,
    this.isDanger = false,
    this.autoMarkRead = true, // ✅ Par défaut, on marque comme lu à l'ouverture
  });

  int count(SectionBadgeCounts c) {
    var total = 0;
    for (final s in sections) {
      total += c.forSection(s);
    }
    return total;
  }
}

const _kSonaAction = _ActionConfig(
  icon: Icons.auto_awesome_rounded,
  label: 'Sona',
  accent: ThixPolicy.primaryDeep,
  semanticsLabel: 'Sona — Assistant IA',
  sections: [ThixSection.info],
);

const _kDocAction = _ActionConfig(
  icon: Icons.folder_shared_rounded,
  label: 'Thix doc',
  accent: ThixPolicy.domainLearning,
  semanticsLabel: 'Thix doc — Coffre-fort documents',
  sections: [ThixSection.formations, ThixSection.opportunities],
);

const _kChatAction = _ActionConfig(
  icon: Icons.forum_rounded,
  label: 'Thix chat',
  accent: ThixPolicy.domainNetwork,
  semanticsLabel: 'Thix chat — Messagerie',
  sections: [ThixSection.messages, ThixSection.network],
  pulseBadge: true,
);

const _kSosAction = _ActionConfig(
  icon: Icons.emergency_rounded,
  label: 'Thix sos',
  accent: ThixPolicy.danger,
  semanticsLabel: 'Thix sos — Urgence',
  sections: [ThixSection.health],
  pulseBadge: true,
  isDanger: true,
  autoMarkRead: false, // ❌ SOS ne se "lit" pas, on garde le badge
);

const List<_ActionConfig> _kActions = [
  _kSonaAction,
  _kDocAction,
  _kChatAction,
  _kSosAction,
];

// ============================================================================
// WIDGET PRINCIPAL
// ============================================================================
class HomeQuickActions extends StatelessWidget {
  final VoidCallback onScanTap;
  final VoidCallback onDocumentTap;
  final VoidCallback onChatTap;
  final VoidCallback onSecurityTap;

  final Stream<SectionBadgeCounts>? badgeCountsStream;

  /// ✅ Service injecté pour marquer les sections comme lues à l'ouverture.
  /// Si null, le reset automatique est désactivé (compatibilité ascendante).
  final NotificationCountersService? notificationService;

  const HomeQuickActions({
    super.key,
    required this.onScanTap,
    required this.onDocumentTap,
    required this.onChatTap,
    required this.onSecurityTap,
    this.badgeCountsStream,
    this.notificationService, // ✅ Nouveau paramètre
  });

  /// Dispatch central avec reset automatique des badges
  void _dispatch(int index) {
    HapticFeedback.selectionClick();
    final config = _kActions[index];

    // ✅ Marquer les sections comme lues AVANT d'appeler le callback
    // pour que le stream émette 0 immédiatement → le badge disparaît
    if (config.autoMarkRead && notificationService != null) {
      _markSectionsRead(config.sections);
    }

    switch (index) {
      case 0:
        debugPrint('[QuickActions] 🤖 Sona tap');
        onScanTap();
        break;
      case 1:
        debugPrint('[QuickActions] 📁 Documents tap');
        onDocumentTap();
        break;
      case 2:
        debugPrint('[QuickActions] 💬 Chat tap → reset messages+network');
        onChatTap();
        break;
      case 3:
        HapticFeedback.mediumImpact();
        debugPrint('[QuickActions] 🚨 SOS tap');
        onSecurityTap();
        break;
    }
  }

  /// ✅ Marque toutes les sections associées comme lues (compteur → 0)
  void _markSectionsRead(List<ThixSection> sections) {
    if (notificationService == null) return;
    for (final section in sections) {
      try {
        notificationService!.markSectionRead(section);
        debugPrint('[QuickActions] ✓ Section marquée comme lue: ${section.name}');
      } catch (e) {
        debugPrint('[QuickActions] ⚠️ Erreur markSectionRead($section): $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (badgeCountsStream == null) {
      return _buildRow(counts: SectionBadgeCounts.zero);
    }

    return StreamBuilder<SectionBadgeCounts>(
      stream: badgeCountsStream,
      initialData: SectionBadgeCounts.zero,
      builder: (context, snap) {
        final c = snap.data ?? SectionBadgeCounts.zero;
        return _buildRow(counts: c);
      },
    );
  }

  Widget _buildRow({required SectionBadgeCounts counts}) {
    return RepaintBoundary(
      child: Row(
        children: [
          for (int i = 0; i < _kActions.length; i++)
            Expanded(
              child: _QuickActionItem(
                config: _kActions[i],
                badge: _safeBadge(_kActions[i].count(counts)),
                onTap: () => _dispatch(i),
              ),
            ),
        ],
      ),
    );
  }

  int _safeBadge(int value) {
    if (value.isNaN || value.isInfinite) return 0;
    return value < 0 ? 0 : value;
  }
}

// ============================================================================
// QUICK ACTION ITEM
// ============================================================================
class _QuickActionItem extends StatelessWidget {
  final _ActionConfig config;
  final int badge;
  final VoidCallback onTap;

  const _QuickActionItem({
    required this.config,
    required this.badge,
    required this.onTap,
  });

  String _sanitizeLabel(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return '—';
    if (trimmed.length > _kMaxLabelLength) {
      return trimmed.substring(0, _kMaxLabelLength);
    }
    return trimmed;
  }

  @override
  Widget build(BuildContext context) {
    final safeLabel = _sanitizeLabel(config.label);
    final displayBadge = badge > _kMaxBadgeDisplay ? '$_kMaxBadgeDisplay+' : '$badge';
    final hasBadge = badge > 0;

    final labelColor = config.isDanger ? ThixPolicy.danger : ThixPolicy.textMain;

    return RepaintBoundary(
      child: Semantics(
        button: true,
        label: hasBadge
            ? '${config.semanticsLabel}, $badge notifications'
            : config.semanticsLabel,
        child: _PressableScale(
          onTap: onTap,
          child: SizedBox(
            width: _kItemWidth,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: _kCircleSize,
                      height: _kCircleSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        border: Border.all(
                          color: ThixPolicy.border.withOpacity(0.8),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Icon(config.icon, size: _kIconSize, color: config.accent),
                    ),
                    if (hasBadge)
                      Positioned(
                        top: -2,
                        right: -2,
                        child: _BadgeWidget(
                          displayText: displayBadge,
                          color: config.isDanger ? ThixPolicy.danger : ThixPolicy.primary,
                          pulse: config.pulseBadge,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  safeLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: _kLabelFontSize,
                    fontWeight: FontWeight.w700,
                    color: labelColor,
                    height: 1.1,
                    letterSpacing: -0.2,
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

// ============================================================================
// BADGE WIDGET
// ============================================================================
class _BadgeWidget extends StatefulWidget {
  final String displayText;
  final Color color;
  final bool pulse;

  const _BadgeWidget({
    required this.displayText,
    required this.color,
    this.pulse = false,
  });

  @override
  State<_BadgeWidget> createState() => _BadgeWidgetState();
}

class _BadgeWidgetState extends State<_BadgeWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController? _pulseCtrl;
  late Animation<double>? _pulseAnim;

  @override
  void initState() {
    super.initState();
    if (widget.pulse) {
      _pulseCtrl = AnimationController(
        vsync: this,
        duration: _kPulseDuration,
      )..repeat(reverse: true);
      _pulseAnim = Tween<double>(begin: 1.0, end: 1.18)
          .animate(CurvedAnimation(parent: _pulseCtrl!, curve: _kPulseCurve));
    } else {
      _pulseCtrl = null;
      _pulseAnim = null;
    }
  }

  @override
  void dispose() {
    _pulseCtrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
      constraints: const BoxConstraints(minWidth: 15, minHeight: 15),
      decoration: BoxDecoration(
        color: widget.color,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: widget.color.withOpacity(0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        widget.displayText,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 8,
          fontWeight: FontWeight.w900,
        ),
      ),
    );

    if (widget.pulse && _pulseAnim != null) {
      return AnimatedBuilder(
        animation: _pulseAnim!,
        builder: (_, __) => Transform.scale(
          scale: _pulseAnim!.value,
          child: badge,
        ),
      );
    }

    return badge;
  }
}

// ============================================================================
// PRESSABLE SCALE
// ============================================================================
class _PressableScale extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;

  const _PressableScale({
    required this.child,
    required this.onTap,
  });

  @override
  State<_PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<_PressableScale> {
  bool _pressed = false;

  void _setPressed(bool v) {
    if (!mounted || _pressed == v) return;
    setState(() => _pressed = v);
  }

  void _handleTap() {
    if (!mounted) return;
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleTap,
      onTapDown: (_) => _setPressed(true),
      onTapCancel: () => _setPressed(false),
      onTapUp: (_) => _setPressed(false),
      child: AnimatedScale(
        scale: _pressed ? 0.94 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: AnimatedOpacity(
          opacity: _pressed ? 0.85 : 1.0,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          child: widget.child,
        ),
      ),
    );
  }
}
