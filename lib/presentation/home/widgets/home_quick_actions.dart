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
          child: _QuickActionItem(
            icon: Icons.auto_awesome_rounded,
            label: 'THIX IA',
            accent: ThixPolicy.primaryDeep,
            onTap: onScanTap,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _QuickActionItem(
            icon: Icons.folder_shared_rounded,
            label: 'THIX DOC',
            accent: ThixPolicy.primary,
            onTap: onDocumentTap,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _QuickActionItem(
            icon: Icons.chat_bubble_rounded,
            label: 'THIX CHAT',
            accent: ThixPolicy.gold,
            onTap: onChatTap,
            badge: chatBadge,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _QuickActionItem(
            icon: Icons.emergency_rounded,
            label: 'THIX SOS',
            accent: ThixPolicy.danger,
            onTap: onSecurityTap,
            badge: sosBadge,
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
    final isAlert = accent == ThixPolicy.danger;

    return _PressableScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
        decoration: BoxDecoration(
          color: Colors.white, // Fond propre Enterprise
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isAlert ? ThixPolicy.danger.withOpacity(0.3) : Colors.grey.shade200,
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                // Container de l'icône teinté
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: accent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, size: 24, color: accent),
                ),
                if (badge > 0)
                  Positioned(
                    top: -6,
                    right: -6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                      decoration: BoxDecoration(
                        color: ThixPolicy.danger,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: ThixPolicy.danger.withOpacity(0.3),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          )
                        ],
                      ),
                      child: Text(
                        badge > 9 ? '9+' : '$badge',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
                color: isAlert ? ThixPolicy.danger : const Color(0xFF0F172A), // Slate 900
                letterSpacing: -0.2,
              ),
              textAlign: TextAlign.center,
            )
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// WIDGET : ANIMATION DE CLIC (Scale Down)
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
    if (_pressed == v) return;
    setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
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
