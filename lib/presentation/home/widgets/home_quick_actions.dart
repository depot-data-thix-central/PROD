// lib/presentation/home/widgets/home_quick_actions.dart
import 'package:flutter/material.dart';
import 'package:thix_id/l10n/app_localizations.dart';
import 'package:thix_id/services/notification_counters_service.dart';
import 'package:thix_id/core/theme/thix_design_policy.dart';

class HomeQuickActions extends StatelessWidget {
  final VoidCallback onScanTap;
  final VoidCallback onDocumentTap;
  final VoidCallback onChatTap;
  final VoidCallback onSecurityTap;

  /// Flux optionnel des compteurs de notifications par section. Quand
  /// fourni, affiche un badge rouge sur THIX CHAT (messages non lus) et
  /// THIX SOS (alertes non lues). Laisser null désactive les badges
  /// sans casser les appels existants.
  final Stream<SectionBadgeCounts>? badgeCountsStream;

  const HomeQuickActions({
    super.key,
    required this.onScanTap,
    required this.onDocumentTap,
    required this.onChatTap,
    required this.onSecurityTap,
    this.badgeCountsStream,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    if (badgeCountsStream == null) {
      return _buildRow(l10n, chatBadge: 0, sosBadge: 0);
    }

    return StreamBuilder<SectionBadgeCounts>(
      stream: badgeCountsStream,
      builder: (context, snap) {
        final c = snap.data ?? SectionBadgeCounts.zero;
        return _buildRow(l10n, chatBadge: c.messages, sosBadge: 0);
      },
    );
  }

  Widget _buildRow(AppLocalizations l10n, {required int chatBadge, required int sosBadge}) {
    return Row(
      children: [
        Expanded(
          child: Center(
            child: _QuickActionItem(
              icon: Icons.smart_toy_rounded,
              label: l10n.t('quickThixIA'),
              accent: ThixPolicy.primaryDeep,
              onTap: onScanTap,
            ),
          ),
        ),
        Expanded(
          child: Center(
            child: _QuickActionItem(
              icon: Icons.folder_shared_rounded,
              label: 'THIX DOC',
              accent: ThixPolicy.domainLearning,
              onTap: onDocumentTap,
            ),
          ),
        ),
        Expanded(
          child: Center(
            child: _QuickActionItem(
              icon: Icons.forum_rounded,
              label: l10n.t('quickChat'),
              accent: ThixPolicy.domainNetwork,
              onTap: onChatTap,
              badge: chatBadge,
            ),
          ),
        ),
        Expanded(
          child: Center(
            child: _QuickActionItem(
              icon: Icons.emergency_rounded,
              label: 'THIX SOS',
              accent: ThixPolicy.danger,
              onTap: onSecurityTap,
              badge: sosBadge,
            ),
          ),
        ),
      ],
    );
  }
}

class _QuickActionItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color accent;
  final VoidCallback onTap;
  final int badge;

  const _QuickActionItem({
    required this.icon,
    required this.label,
    required this.accent,
    required this.onTap,
    this.badge = 0,
  });

  @override
  Widget build(BuildContext context) {
    return _PressableScale(
      onTap: onTap,
      child: SizedBox(
        width: 64,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: ThixPolicy.card, // Remplacé Colors.white par le Design System
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: accent.withValues(alpha: 0.35),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: accent.withValues(alpha: 0.22),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      )
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Icon(icon, size: 20, color: accent),
                ),
                if (badge > 0)
                  Positioned(
                    top: -4,
                    right: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                      decoration: BoxDecoration(
                        color: ThixPolicy.danger,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white, width: 1.2),
                      ),
                      child: Text(
                        badge > 9 ? '9+' : '$badge',
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
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 8.5,
                fontWeight: FontWeight.w700,
                color: accent == ThixPolicy.danger
                    ? ThixPolicy.danger
                    : ThixPolicy.textMain,
                height: 1.1,
              ),
              textAlign: TextAlign.center,
            )
          ],
        ),
      ),
    );
  }
}

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
    if (_pressed == v) return;
    setState(() => _pressed = v); // Correction ici : c'est bien _pressed et non pressed
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => _setPressed(true),
      onTapCancel: () => _setPressed(false),
      onTapUp: (_) => _setPressed(false),
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: AnimatedOpacity(
          opacity: _pressed ? 0.92 : 1.0,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          child: widget.child,
        ),
      ),
    );
  }
}
