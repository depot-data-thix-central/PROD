// lib/presentation/home/widgets/home_quick_actions.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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

  /// Si true : à l'ouverture, le badge repasse à ZÉRO (immédiatement en local
  /// + sections marquées comme vues côté serveur).
  final bool autoMarkRead;

  const _ActionConfig({
    required this.icon,
    required this.label,
    required this.accent,
    required this.semanticsLabel,
    required this.sections,
    this.pulseBadge = false,
    this.isDanger = false,
    this.autoMarkRead = true,
  });

  int count(SectionBadgeCounts c) {
    var total = 0;
    for (final s in sections) {
      total += c.forSection(s);
    }
    return total;
  }
}

// Sona : pas de remise à zéro automatique
const _kSonaAction = _ActionConfig(
  icon: Icons.auto_awesome_rounded,
  label: 'Sona',
  accent: ThixPolicy.primaryDeep,
  semanticsLabel: 'Sona — Assistant IA',
  sections: [ThixSection.info],
  autoMarkRead: false,
);

// Thix doc : pas de remise à zéro (les badges Formations/Opportunités restent)
const _kDocAction = _ActionConfig(
  icon: Icons.folder_shared_rounded,
  label: 'Thix doc',
  accent: ThixPolicy.domainLearning,
  semanticsLabel: 'Thix doc — Coffre-fort documents',
  sections: [ThixSection.formations, ThixSection.opportunities],
  autoMarkRead: false,
);

// ✅ Thix chat : le compteur retombe à zéro à l'ouverture du chat
const _kChatAction = _ActionConfig(
  icon: Icons.forum_rounded,
  label: 'Thix chat',
  accent: ThixPolicy.domainNetwork,
  semanticsLabel: 'Thix chat — Messagerie',
  sections: [ThixSection.messages, ThixSection.network],
  pulseBadge: true,
  autoMarkRead: true,
);

const _kSosAction = _ActionConfig(
  icon: Icons.emergency_rounded,
  label: 'Thix sos',
  accent: ThixPolicy.danger,
  semanticsLabel: 'Thix sos — Urgence',
  sections: [ThixSection.health],
  pulseBadge: true,
  isDanger: true,
  autoMarkRead: false,
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
class HomeQuickActions extends StatefulWidget {
  final VoidCallback onScanTap;
  final VoidCallback onDocumentTap;
  final VoidCallback onChatTap;
  final VoidCallback onSecurityTap;

  final Stream<SectionBadgeCounts>? badgeCountsStream;

  /// Optionnel : si absent, un service est créé automatiquement.
  final NotificationCountersService? notificationService;

  const HomeQuickActions({
    super.key,
    required this.onScanTap,
    required this.onDocumentTap,
    required this.onChatTap,
    required this.onSecurityTap,
    this.badgeCountsStream,
    this.notificationService,
  });

  @override
  State<HomeQuickActions> createState() => _HomeQuickActionsState();
}

class _HomeQuickActionsState extends State<HomeQuickActions> {
  /// Compteur affiché = compteur réel − base. La base est fixée au moment où
  /// l'utilisateur ouvre l'action (remise à zéro instantanée, sans attendre le serveur).
  final Map<int, int> _baseline = <int, int>{};
  SectionBadgeCounts _lastCounts = SectionBadgeCounts.zero;
  NotificationCountersService? _svc;

  NotificationCountersService get _service =>
      _svc ??= (widget.notificationService ?? NotificationCountersService());

  void _dispatch(int index) {
    HapticFeedback.selectionClick();
    final config = _kActions[index];

    if (config.autoMarkRead) {
      _clearBadge(index, config);
    }

    switch (index) {
      case 0:
        debugPrint('[QuickActions] 🤖 Sona tap');
        widget.onScanTap();
        break;
      case 1:
        debugPrint('[QuickActions] 📁 Documents tap');
        widget.onDocumentTap();
        break;
      case 2:
        debugPrint('[QuickActions] 💬 Chat tap → compteur remis à zéro');
        widget.onChatTap();
        break;
      case 3:
        HapticFeedback.mediumImpact();
        debugPrint('[QuickActions] 🚨 SOS tap');
        widget.onSecurityTap();
        break;
    }
  }

  /// Remise à zéro : locale (instantanée) + serveur (persistante).
  void _clearBadge(int index, _ActionConfig config) {
    final current = config.count(_lastCounts);
    if (mounted) setState(() => _baseline[index] = current);
    _markSectionsSeen(config.sections);
  }

  void _markSectionsSeen(List<ThixSection> sections) {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    final svc = _service;

    for (final section in sections) {
      Future.sync(() => svc.markSectionSeen(uid: userId, section: section)).then(
        (_) {},
        onError: (Object e) => debugPrint('[QuickActions] ⚠️ markSectionSeen(${section.name}): $e'),
      );
      Future.sync(() => svc.markSectionRead(uid: userId, section: section)).then(
        (_) {},
        onError: (Object e) => debugPrint('[QuickActions] ⚠️ markSectionRead(${section.name}): $e'),
      );
      debugPrint('[QuickActions] ✓ Section marquée comme lue: ${section.name}');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.badgeCountsStream == null) {
      return _buildRow(counts: SectionBadgeCounts.zero);
    }

    return StreamBuilder<SectionBadgeCounts>(
      stream: widget.badgeCountsStream,
      initialData: SectionBadgeCounts.zero,
      builder: (context, snap) {
        final c = snap.data ?? SectionBadgeCounts.zero;
        return _buildRow(counts: c);
      },
    );
  }

  /// Badge affiché pour l'action [i] (réel − base ; la base suit les baisses).
  int _displayBadge(int i, SectionBadgeCounts counts) {
    final raw = _safeBadge(_kActions[i].count(counts));
    var base = _baseline[i] ?? 0;
    if (raw < base) {
      base = raw; // le serveur a baissé : les prochains arrivages s'affichent
      _baseline[i] = raw;
    }
    return raw - base;
  }

  Widget _buildRow({required SectionBadgeCounts counts}) {
    _lastCounts = counts;
    return RepaintBoundary(
      child: Row(
        children: [
          for (int i = 0; i < _kActions.length; i++)
            Expanded(
              child: _QuickActionItem(
                config: _kActions[i],
                badge: _displayBadge(i, counts),
                onTap: () => _dispatch(i),
              ),
            ),
        ],
      ),
    );
  }

  int _safeBadge(int value) {
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
  late final AnimationController _pulseCtrl =
      AnimationController(vsync: this, duration: _kPulseDuration);

  @override
  void initState() {
    super.initState();
    if (widget.pulse) _pulseCtrl.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant _BadgeWidget old) {
    super.didUpdateWidget(old);
    if (widget.pulse && !_pulseCtrl.isAnimating) {
      _pulseCtrl.repeat(reverse: true);
    } else if (!widget.pulse && _pulseCtrl.isAnimating) {
      _pulseCtrl.stop();
      _pulseCtrl.value = 0;
    }
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final badge = Container(
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

    if (!widget.pulse) return badge;

    return AnimatedBuilder(
      animation: _pulseCtrl,
      builder: (_, child) => Transform.scale(
        scale: 1.0 + 0.18 * _kPulseCurve.transform(_pulseCtrl.value),
        child: child,
      ),
      child: badge,
    );
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
