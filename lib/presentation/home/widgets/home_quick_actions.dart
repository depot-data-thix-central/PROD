// lib/presentation/home/widgets/home_quick_actions.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:thix_id/l10n/app_localizations.dart';
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
const int _kMaxBadgeDisplay = 9; // Au-delà, affiche "9+"

// ============================================================================
// WIDGET PRINCIPAL
// ============================================================================
class HomeQuickActions extends StatelessWidget {
  final VoidCallback onScanTap;
  final VoidCallback onDocumentTap;
  final VoidCallback onChatTap;
  final VoidCallback onSecurityTap;

  /// Flux optionnel des compteurs de notifications par section.
  /// Quand null, désactive les badges sans casser les appels existants.
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
      initialData: SectionBadgeCounts.zero,
      builder: (context, snap) {
        final c = snap.data ?? SectionBadgeCounts.zero;
        return _buildRow(
          l10n,
          chatBadge: _safeBadge(c.messages),
          sosBadge: _safeBadge(c.alerts),
        );
      },
    );
  }

  /// Validation stricte du badge (≥ 0, entier)
  int _safeBadge(int value) {
    if (value.isNaN || value.isInfinite) return 0;
    return value < 0 ? 0 : value;
  }

  Widget _buildRow(
    AppLocalizations l10n, {
    required int chatBadge,
    required int sosBadge,
  }) {
    return RepaintBoundary(
      child: Row(
        children: [
          Expanded(
            child: _QuickActionItem(
              icon: Icons.auto_awesome_rounded,
              label: l10n.t('quickSona'),
              accent: ThixPolicy.primaryDeep,
              semanticsLabel: l10n.t('quickSona_semantics'),
              onTap: () {
                HapticFeedback.selectionClick();
                debugPrint('[QuickActions] 🤖 Sona tap');
                onScanTap();
              },
            ),
          ),
          Expanded(
            child: _QuickActionItem(
              icon: Icons.folder_shared_rounded,
              label: l10n.t('quickDoc'),
              accent: ThixPolicy.domainLearning,
              semanticsLabel: l10n.t('quickDoc_semantics'),
              onTap: () {
                HapticFeedback.selectionClick();
                debugPrint('[QuickActions] 📁 Documents tap');
                onDocumentTap();
              },
            ),
          ),
          Expanded(
            child: _QuickActionItem(
              icon: Icons.forum_rounded,
              label: l10n.t('quickChat'),
              accent: ThixPolicy.domainNetwork,
              semanticsLabel: l10n.t('quickChat_semantics'),
              onTap: () {
                HapticFeedback.selectionClick();
                debugPrint('[QuickActions] 💬 Chat tap');
                onChatTap();
              },
              badge: chatBadge,
            ),
          ),
          Expanded(
            child: _QuickActionItem(
              icon: Icons.emergency_rounded,
              label: l10n.t('quickSos'),
              accent: ThixPolicy.danger,
              semanticsLabel: l10n.t('quickSos_semantics'),
              onTap: () {
                HapticFeedback.mediumImpact();
                debugPrint('[QuickActions] 🚨 SOS tap');
                onSecurityTap();
              },
              badge: sosBadge,
              isDanger: true,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// QUICK ACTION ITEM
// ============================================================================
class _QuickActionItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color accent;
  final String semanticsLabel;
  final VoidCallback onTap;
  final int badge;
  final bool isDanger;

  const _QuickActionItem({
    required this.icon,
    required this.label,
    required this.accent,
    required this.semanticsLabel,
    required this.onTap,
    this.badge = 0,
    this.isDanger = false,
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
    final safeLabel = _sanitizeLabel(label);
    final displayBadge = badge > _kMaxBadgeDisplay ? '$_kMaxBadgeDisplay+' : '$badge';
    final hasBadge = badge > 0;

    final labelColor = isDanger ? ThixPolicy.danger : ThixPolicy.textMain;

    return RepaintBoundary(
      child: Semantics(
        button: true,
        label: hasBadge ? '$semanticsLabel, $badge' : semanticsLabel,
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
                    // Cercle solide (pas de BackdropFilter = 10x plus rapide)
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
                      child: Icon(icon, size: _kIconSize, color: accent),
                    ),

                    // Badge notification
                    if (hasBadge)
                      Positioned(
                        top: -2,
                        right: -2,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 1.5,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 15,
                            minHeight: 15,
                          ),
                          decoration: BoxDecoration(
                            color: ThixPolicy.danger,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.white, width: 1.2),
                            boxShadow: [
                              BoxShadow(
                                color: ThixPolicy.danger.withOpacity(0.3),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Text(
                            displayBadge,
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
// PRESSABLE SCALE (Feedback tactile au tap)
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
